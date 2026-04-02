using System.ComponentModel;
using System.Collections.ObjectModel;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Text.RegularExpressions;
using DrawingIcon = System.Drawing.Icon;
using FormsContextMenuStrip = System.Windows.Forms.ContextMenuStrip;
using FormsNotifyIcon = System.Windows.Forms.NotifyIcon;
using FormsToolStripMenuItem = System.Windows.Forms.ToolStripMenuItem;
using FormsToolStripSeparator = System.Windows.Forms.ToolStripSeparator;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Threading;
using Kompanion.Services;
using KompanionUI.Services;

namespace KompanionUI;

public partial class MainWindow : Window
{
    private const string TrayTipText = "Kompanion is still running in the system tray.";
    private const int MaxLogEntries = 300;
    private static readonly Regex LogLinePattern =
        new(@"^\[(?<ts>[^\]]+)\]\s*(?<msg>.*)$", RegexOptions.Compiled);

    private readonly Logger         _logger;
    private readonly ScriptRunner   _runner;
    private readonly RepoScanner    _scanner;
    private readonly VsCodeLauncher _vscode;
    private readonly GitService     _git;
    private readonly UsageTracker   _usage;
    private readonly OllamaService  _ollama;
    private readonly FormsNotifyIcon _trayIcon;
    private readonly ObservableCollection<LogListItem> _logEntries;
    private readonly ObservableCollection<OllamaProcessInfo> _ollamaEntries;

    private bool _allowClose;
    private bool _trayTipShown;
    private CancellationTokenSource? _gitOperationCts;
    private readonly DispatcherTimer _mouseJiggleTimer;
    private bool _mouseJigglingEnabled = true;
    private int _jiggleOffset = 4;
    private long _jiggleInterval = 3;

    public MainWindow()
    {
        _mouseJiggleTimer = new DispatcherTimer
        {
            Interval = TimeSpan.FromSeconds(_jiggleInterval)
        };
        _mouseJiggleTimer.Tick += MouseJiggleTimer_Tick;

        InitializeComponent();

        _logger  = new Logger();
        _runner  = new ScriptRunner(_logger);
        _scanner = new RepoScanner(_logger);
        _vscode  = new VsCodeLauncher(_logger);
        _git     = new GitService(_logger);
        _usage   = new UsageTracker(_logger);
        _ollama  = new OllamaService();
        _trayIcon = CreateTrayIcon();

        _logEntries = new ObservableCollection<LogListItem>();
        _ollamaEntries = new ObservableCollection<OllamaProcessInfo>();

        LogsList.ItemsSource = _logEntries;
        OllamaProcessesList.ItemsSource = _ollamaEntries;
        ReloadLogs();
        RefreshOllamaStatus();

        // Run the startup script on a background thread so the window is
        // visible immediately; populate the repo list once the script finishes.
        Loaded += OnLoadedAsync;
        Closing += OnWindowClosing;
        Closed += OnWindowClosed;

        ApplyMouseJigglingSetting();
    }

    private async void OnLoadedAsync(object sender, RoutedEventArgs e)
    {
        SetStatus("Running startup script…");
        RefreshButton.IsEnabled = false;

        string? scriptError = await Task.Run(() => _runner.RunKompanionScript());

        RefreshButton.IsEnabled = true;

        if (scriptError != null)
            SetStatus(scriptError, isError: true);

        Refresh();
    }

    // ------------------------------------------------------------------ //
    //  Refresh
    // ------------------------------------------------------------------ //

    private void Refresh()
    {
        var (repos, error) = _scanner.Scan();
        List<Models.RepoEntry> sorted = _usage.SortRepos(
            repos,
            Environment.GetEnvironmentVariable("KOMPANION_DIR"));

        if (error != null)
        {
            SetStatus(error, isError: true);
        }
        else
        {
            SetStatus($"{repos.Count} repositor{(repos.Count == 1 ? "y" : "ies")} found.");
        }

        RepoList.ItemsSource = sorted;
    }

    private void RefreshButton_Click(object sender, RoutedEventArgs e) => Refresh();

    private async void CheckAllButton_Click(object sender, RoutedEventArgs e)
    {
        var button = (System.Windows.Controls.Button)sender;
        button.IsEnabled = false;
        SetStatus("Checking status of all repositories...");

        try
        {
            if (RepoList.ItemsSource is not
                IEnumerable<Models.RepoEntry> repos)
                return;

            // Check all repositories in parallel.
            var tasks = repos
                .Select(async repo =>
                {
                    bool isClean = await Task.Run(
                        () => _git.IsRepositoryClean(repo.FullPath));

                    // Update the UI on the dispatcher thread.
                    Dispatcher.Invoke(() =>
                    {
                        repo.StatusColor = isClean
                            ? "#FF00B050" // Green: clean
                            : "#FFFF0000"; // Red: has changes
                    });
                })
                .ToList();

            await Task.WhenAll(tasks);

            SetStatus(
                $"Status check complete for {repos.Count()} " +
                $"repositor{(repos.Count() == 1 ? "y" : "ies")}.");
        }
        finally
        {
            button.IsEnabled = true;
        }
    }

    // ------------------------------------------------------------------ //
    //  Window lifecycle
    // ------------------------------------------------------------------ //

    private void OnWindowClosing(object? sender, CancelEventArgs e)
    {
        if (_allowClose)
            return;

        e.Cancel = true;
        HideToTray();
    }

    private void OnWindowClosed(object? sender, EventArgs e)
    {
        _mouseJiggleTimer.Stop();
        _trayIcon.Visible = false;
        _trayIcon.Dispose();
    }

    // ------------------------------------------------------------------ //
    //  Launch
    // ------------------------------------------------------------------ //

    private void LaunchButton_Click(object sender, RoutedEventArgs e)
    {
        string? path = GetTagPath(sender, "Launch");
        if (path == null) return;

        _usage.RecordUsage(path);
        ResortCurrentRepos();

        string? error = _vscode.Launch(path);

        if (error != null)
            ShowError(error);
        else
            SetStatus($"Launched VSCode at: {path}");
    }

    // ------------------------------------------------------------------ //
    //  Status
    // ------------------------------------------------------------------ //

    private async void StatusButton_Click(object sender, RoutedEventArgs e)
    {
        string? path = GetTagPath(sender, "Status");
        if (path == null) return;

        SetStatus($"Running git status in: {path}");
        SetAllEnabled(false);

        try
        {
            var (success, output) = await Task.Run(() => _git.GetStatus(path));

            string repoName = System.IO.Path.GetFileName(path);
            string title = $"git status — {repoName}";

            // Show result in a scrollable popup window.
            ShowOutputPopup(title, output, success);

            SetStatus(success
                ? $"git status completed for: {repoName}"
                : $"git status failed for: {repoName}", isError: !success);
        }
        finally
        {
            SetAllEnabled(true);
        }
    }

    /// <summary>
    /// Opens a small popup window that displays pre-formatted text output (e.g. git status).
    /// </summary>
    private void ShowOutputPopup(string title, string content, bool success)
    {
        var popup = new Window
        {
            Title = title,
            Width = 600,
            Height = 420,
            MinWidth = 300,
            MinHeight = 200,
            WindowStartupLocation = WindowStartupLocation.CenterOwner,
            Owner = this,
            Background = System.Windows.Media.Brushes.White,
        };

        var textBox = new System.Windows.Controls.TextBox
        {
            Text = content,
            IsReadOnly = true,
            FontFamily = new System.Windows.Media.FontFamily("Consolas, Courier New, monospace"),
            FontSize = 12,
            Margin = new Thickness(8),
            BorderThickness = new Thickness(0),
            Background = System.Windows.Media.Brushes.White,
            Foreground = success
                ? System.Windows.Media.Brushes.Black
                : System.Windows.Media.Brushes.DarkRed,
            TextWrapping = System.Windows.TextWrapping.Wrap,
            VerticalScrollBarVisibility = System.Windows.Controls.ScrollBarVisibility.Auto,
            HorizontalScrollBarVisibility = System.Windows.Controls.ScrollBarVisibility.Auto,
            AcceptsReturn = true,
            VerticalAlignment = System.Windows.VerticalAlignment.Stretch,
            HorizontalAlignment = System.Windows.HorizontalAlignment.Stretch,
        };

        var closeButton = new System.Windows.Controls.Button
        {
            Content = "Close",
            Width = 80,
            Height = 26,
            Margin = new Thickness(0, 4, 8, 8),
            HorizontalAlignment = System.Windows.HorizontalAlignment.Right,
        };
        closeButton.Click += (_, _) => popup.Close();

        var root = new DockPanel();
        DockPanel.SetDock(closeButton, Dock.Bottom);
        root.Children.Add(closeButton);
        root.Children.Add(textBox);

        popup.Content = root;
        popup.ShowDialog();
    }

    // ------------------------------------------------------------------ //
    //  Pull
    // ------------------------------------------------------------------ //

    private async void PullButton_Click(object sender, RoutedEventArgs e)
    {
        string? path = GetTagPath(sender, "Pull");
        if (path == null) return;

        await ExecuteGitOperationAsync(GitOperation.Pull, path);
    }

    // ------------------------------------------------------------------ //
    //  Push
    // ------------------------------------------------------------------ //

    private async void PushButton_Click(object sender, RoutedEventArgs e)
    {
        string? path = GetTagPath(sender, "Push");
        if (path == null) return;

        await ExecuteGitOperationAsync(GitOperation.Push, path);
    }
    private async Task ExecuteGitOperationAsync(GitOperation operation, string path)
    {
        if (_gitOperationCts != null)
        {
            SetStatus("Another Git operation is already running.", isError: true);
            return;
        }

        string verb = operation == GitOperation.Pull ? "pull" : "push";

        _usage.RecordUsage(path);
        ResortCurrentRepos();

        SetStatus($"Running git {verb} in: {path}");
        SetAllEnabled(false);
        CancelGitButton.IsEnabled = true;
        _gitOperationCts = new CancellationTokenSource();

        try
        {
            // Keep git execution off the UI thread, then marshal results back via await.
            var (success, output) = await Task.Run(
                () => _git.Run(operation, path, _gitOperationCts.Token));

            if (!success)
            {
                bool cancelled = output.Contains(
                    "cancelled by user", StringComparison.OrdinalIgnoreCase);

                if (cancelled)
                {
                    SetStatus($"git {verb} cancelled in: {path}");
                    return;
                }

                SetStatus($"git {verb} failed in: {path}", isError: true);

                string details = string.IsNullOrWhiteSpace(output)
                    ? "No output was captured. Check the log file for details."
                    : output;
                ShowError($"git {verb} failed:\n\n{details}");
                return;
            }

            SetStatus($"git {verb} succeeded in: {path}");
        }
        catch (Exception ex)
        {
            string error = $"Unexpected git {verb} error in '{path}': {ex.Message}";
            _logger.Log(error);
            SetStatus(error, isError: true);
            ShowError(error);
        }
        finally
        {
            _gitOperationCts.Dispose();
            _gitOperationCts = null;
            CancelGitButton.IsEnabled = false;
            SetAllEnabled(true);
        }
    }

    private void CancelGitButton_Click(object sender, RoutedEventArgs e)
    {
        if (_gitOperationCts == null)
            return;

        _gitOperationCts.Cancel();
        SetStatus("Cancellation requested. Waiting for Git to stop...");
    }

    // ------------------------------------------------------------------ //
    //  Helpers
    // ------------------------------------------------------------------ //

    /// <summary>Extracts the repository path stored in a button's Tag.</summary>
    private string? GetTagPath(object sender, string actionName)
    {
        string? path = (sender as System.Windows.Controls.Button)?.Tag as string;

        if (!string.IsNullOrWhiteSpace(path))
            return path;

        string message = $"{actionName} failed because the repository path is missing.";
        _logger.Log(message);
        SetStatus(message, isError: true);
        ShowError(message);
        return null;
    }

    /// <summary>Displays a message in the status bar.</summary>
    private void SetStatus(string message, bool isError = false)
    {
        StatusText.Text       = message;
        StatusText.Foreground = isError
            ? System.Windows.Media.Brushes.Firebrick
            : System.Windows.Media.Brushes.DarkSlateGray;

        ReloadLogs();
    }

    /// <summary>Shows a modal error dialog.</summary>
    private void ShowError(string message)
        => System.Windows.MessageBox.Show(this, message, "Kompanion – Error",
                           MessageBoxButton.OK, MessageBoxImage.Error);

    /// <summary>Disables/enables the Refresh button and all row buttons.</summary>
    private void SetAllEnabled(bool enabled)
    {
        RefreshButton.IsEnabled = enabled;
        // ItemsControl items are UIElements; walk the visual tree is not trivial,
        // so we disable the overlay instead by setting opacity and hit-test visibility.
        RepoList.IsEnabled = enabled;
    }

    private void RefreshLogsButton_Click(object sender, RoutedEventArgs e)
    {
        ReloadLogs();
    }

    private void RefreshOllamaButton_Click(object sender, RoutedEventArgs e)
    {
        RefreshOllamaStatus("Ollama status refreshed.");
    }

    private void StartOllamaButton_Click(object sender, RoutedEventArgs e)
    {
        var result = _ollama.Serve();
        _logger.Log($"Ollama serve result: {result.Status} - {result.Message}");
        RefreshOllamaStatus(result.Message, isError: result.Status == OllamaServeStatus.FailedToStart ||
            result.Status == OllamaServeStatus.NotConfigured ||
            result.Status == OllamaServeStatus.ExecutableNotFound);
    }

    private void StopOllamaButton_Click(object sender, RoutedEventArgs e)
    {
        var result = _ollama.Stop();
        _logger.Log($"Ollama stop result: {result.Status} - {result.Message}");
        RefreshOllamaStatus(result.Message, isError: result.Status == OllamaStopStatus.FailedToStop ||
            result.Status == OllamaStopStatus.StillRunning);
    }

    private void ExitMenuItem_Click(object sender, RoutedEventArgs e)
    {
        _allowClose = true;
        _logger.Log("Kompanion exit requested from File > Exit menu.");
        Close();
    }

    private void LaunchLogseqButton_Click(object sender, RoutedEventArgs e)
    {
        string? logseqHome = Environment.GetEnvironmentVariable("LOGSEQ_HOME");
        if (string.IsNullOrWhiteSpace(logseqHome))
        {
            SetStatus("Applications cannot be launched: $env:LOGSEQ_HOME is not set.", isError: true);
            return;
        }

        string logseqExe = Path.Combine(logseqHome, "Logseq.exe");
        if (!File.Exists(logseqExe))
        {
            string error = $"Logseq executable not found at: {logseqExe}";
            _logger.Log(error);
            SetStatus(error, isError: true);
            return;
        }

        try
        {
            Process.Start(new ProcessStartInfo(logseqExe) { UseShellExecute = true });
            _logger.Log($"Launched Logseq from: {logseqExe}");
            SetStatus($"Launched Logseq.");
        }
        catch (Exception ex)
        {
            string error = $"Failed to launch Logseq: {ex.Message}";
            _logger.Log(error);
            SetStatus(error, isError: true);
        }
    }

    private void MouseJigglingCheckBox_Changed(object sender, RoutedEventArgs e)
    {
        ApplyMouseJigglingSetting();

        if (!IsLoaded || StatusText is null)
            return;

        SetStatus(
            _mouseJigglingEnabled
                ? "Mouse jiggling enabled."
                : "Mouse jiggling disabled.",
            false);
    }

    private void ApplyMouseJigglingSetting()
    {
        _mouseJigglingEnabled = MouseJigglingCheckBox?.IsChecked ?? true;

        if (_mouseJigglingEnabled)
        {
            if (!_mouseJiggleTimer.IsEnabled)
                _mouseJiggleTimer.Start();

            return;
        }

        _mouseJiggleTimer.Stop();
    }

    private void MouseJiggleTimer_Tick(object? sender, EventArgs e)
    {
        if (!_mouseJigglingEnabled)
            return;

        JiggleMouseCursor();
    }

    private void JiggleMouseCursor()
    {
        if (!TryGetCursorPos(out NativePoint currentPosition))
            return;

        int targetX = currentPosition.X + _jiggleOffset;
        int targetY = currentPosition.Y + _jiggleOffset;

        _jiggleOffset = -_jiggleOffset;

        SetCursorPos(targetX, targetY);
    }

    [DllImport("user32.dll")]
    private static extern bool SetCursorPos(int x, int y);

    [DllImport("user32.dll")]
    private static extern bool GetCursorPos(out NativePoint point);

    private static bool TryGetCursorPos(out NativePoint point)
        => GetCursorPos(out point);

    [StructLayout(LayoutKind.Sequential)]
    private struct NativePoint
    {
        public int X;
        public int Y;
    }

    private void ReloadLogs()
    {
        _logEntries.Clear();

        if (string.IsNullOrWhiteSpace(_logger.LogPath))
        {
            LogsHintText.Text = "Logging is disabled. Set KOMPANION_LOGS to enable log files.";
            return;
        }

        if (!File.Exists(_logger.LogPath))
        {
            LogsHintText.Text = "No log file found yet. Perform an action to create it.";
            return;
        }

        try
        {
            string[] lines = File.ReadAllLines(_logger.LogPath);
            IEnumerable<string> tail = lines
                .Where(line => !string.IsNullOrWhiteSpace(line))
                .TakeLast(MaxLogEntries)
                .Reverse();

            foreach (string line in tail)
                _logEntries.Add(ParseLogLine(line));

            string fileName = Path.GetFileName(_logger.LogPath);
            LogsHintText.Text = $"Showing {_logEntries.Count} recent entries from {fileName}.";
        }
        catch (Exception ex)
        {
            _logger.Log($"Failed to load logs tab content: {ex.Message}");
            LogsHintText.Text = "Could not load log file. Check file permissions and try again.";
        }
    }

    private void RefreshOllamaStatus(string? message = null, bool isError = false)
    {
        _ollamaEntries.Clear();

        foreach (OllamaProcessInfo process in _ollama.GetRunningProcesses())
            _ollamaEntries.Add(process);

        string status = message ?? (_ollamaEntries.Count == 0
            ? "Ollama server is not running."
            : $"Ollama server running with {_ollamaEntries.Count} process(es).");

        OllamaStatusText.Text = status;
        OllamaStatusText.Foreground = isError
            ? System.Windows.Media.Brushes.Firebrick
            : System.Windows.Media.Brushes.DarkSlateGray;
    }

    private static LogListItem ParseLogLine(string line)
    {
        Match match = LogLinePattern.Match(line);
        if (!match.Success)
        {
            return new LogListItem
            {
                Timestamp = "-",
                Message = line.Trim()
            };
        }

        string timestamp = match.Groups["ts"].Value.Trim();
        string message = match.Groups["msg"].Value.Trim();

        return new LogListItem
        {
            Timestamp = timestamp,
            Message = string.IsNullOrWhiteSpace(message) ? "(empty)" : message
        };
    }

    private void ResortCurrentRepos()
    {
        if (RepoList.ItemsSource is not IEnumerable<Models.RepoEntry> existing)
            return;

        List<Models.RepoEntry> sorted = _usage.SortRepos(
            existing.ToList(),
            Environment.GetEnvironmentVariable("KOMPANION_DIR"));

        RepoList.ItemsSource = sorted;
    }

    private void LoadLogTailIntoHistory()
    {
        // Kept for backwards compatibility with older call sites. Prefer ReloadLogs.
        ReloadLogs();
    }

    private FormsNotifyIcon CreateTrayIcon()
    {
        var contextMenu = new FormsContextMenuStrip();

        contextMenu.Items.Add(new FormsToolStripMenuItem("Open", null, (_, _) =>
            Dispatcher.Invoke(RestoreFromTray)));
        contextMenu.Items.Add(new FormsToolStripMenuItem("Refresh", null, (_, _) =>
            Dispatcher.Invoke(Refresh)));
        contextMenu.Items.Add(new FormsToolStripSeparator());
        contextMenu.Items.Add(new FormsToolStripMenuItem("Exit", null, (_, _) =>
            Dispatcher.Invoke(ExitApplication)));

        var trayIcon = new FormsNotifyIcon
        {
            Text = "Kompanion",
            Visible = true,
            ContextMenuStrip = contextMenu,
            Icon = ResolveTrayIcon()
        };

        trayIcon.DoubleClick += (_, _) => Dispatcher.Invoke(RestoreFromTray);
        return trayIcon;
    }

    private void HideToTray()
    {
        Hide();
        ShowInTaskbar = false;
        SetStatus(TrayTipText);
        _logger.Log("Main window hidden to system tray.");

        if (_trayTipShown)
            return;

        _trayIcon.ShowBalloonTip(3000, "Kompanion", TrayTipText,
            System.Windows.Forms.ToolTipIcon.Info);
        _trayTipShown = true;
    }

    private void RestoreFromTray()
    {
        Show();
        ShowInTaskbar = true;
        WindowState = WindowState.Normal;
        Activate();
        SetStatus("Kompanion restored.");
        _logger.Log("Main window restored from system tray.");
    }

    public void RestoreFromExternalActivation()
    {
        Show();
        ShowInTaskbar = true;

        if (WindowState == WindowState.Minimized)
            WindowState = WindowState.Normal;

        Activate();
        SetStatus("Kompanion brought to foreground.");
        _logger.Log("Main window activated from a secondary launch request.");
    }

    private void ExitApplication()
    {
        _allowClose = true;
        _logger.Log("Kompanion exit requested from system tray.");
        Close();
    }

    private static DrawingIcon ResolveTrayIcon()
    {
        string? processPath = Environment.ProcessPath;

        if (!string.IsNullOrWhiteSpace(processPath))
        {
            DrawingIcon? icon = DrawingIcon.ExtractAssociatedIcon(processPath);
            if (icon != null)
                return icon;
        }

        return System.Drawing.SystemIcons.Application;
    }

    private sealed class LogListItem
    {
        public string Timestamp { get; init; } = string.Empty;
        public string Message { get; init; } = string.Empty;
    }
}
