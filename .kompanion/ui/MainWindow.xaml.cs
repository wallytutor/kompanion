using System.ComponentModel;
using System.Collections.ObjectModel;
using System.IO;
using System.Text.RegularExpressions;
using DrawingIcon = System.Drawing.Icon;
using FormsContextMenuStrip = System.Windows.Forms.ContextMenuStrip;
using FormsNotifyIcon = System.Windows.Forms.NotifyIcon;
using FormsToolStripMenuItem = System.Windows.Forms.ToolStripMenuItem;
using FormsToolStripSeparator = System.Windows.Forms.ToolStripSeparator;
using System.Windows;
using System.Windows.Controls;
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
    private readonly FormsNotifyIcon _trayIcon;
    private readonly ObservableCollection<LogListItem> _logEntries;

    private bool _allowClose;
    private bool _trayTipShown;
    private CancellationTokenSource? _gitOperationCts;

    public MainWindow()
    {
        InitializeComponent();

        _logger  = new Logger();
        _runner  = new ScriptRunner(_logger);
        _scanner = new RepoScanner(_logger);
        _vscode  = new VsCodeLauncher(_logger);
        _git     = new GitService(_logger);
        _usage   = new UsageTracker(_logger);
        _trayIcon = CreateTrayIcon();
        _logEntries = new ObservableCollection<LogListItem>();

        LogsList.ItemsSource = _logEntries;
        ReloadLogs();

        // Run the startup script on a background thread so the window is
        // visible immediately; populate the repo list once the script finishes.
        Loaded += OnLoadedAsync;
        Closing += OnWindowClosing;
        Closed += OnWindowClosed;
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

    private void ExitMenuItem_Click(object sender, RoutedEventArgs e)
    {
        _allowClose = true;
        _logger.Log("Kompanion exit requested from File > Exit menu.");
        Close();
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
