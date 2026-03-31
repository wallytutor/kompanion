using System.ComponentModel;
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

    private readonly Logger         _logger;
    private readonly ScriptRunner   _runner;
    private readonly RepoScanner    _scanner;
    private readonly VsCodeLauncher _vscode;
    private readonly GitService     _git;
    private readonly FormsNotifyIcon _trayIcon;

    private bool _allowClose;
    private bool _trayTipShown;

    public MainWindow()
    {
        InitializeComponent();

        _logger  = new Logger();
        _runner  = new ScriptRunner(_logger);
        _scanner = new RepoScanner(_logger);
        _vscode  = new VsCodeLauncher(_logger);
        _git     = new GitService(_logger);
        _trayIcon = CreateTrayIcon();

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

        if (error != null)
        {
            SetStatus(error, isError: true);
        }
        else
        {
            SetStatus($"{repos.Count} repositor{(repos.Count == 1 ? "y" : "ies")} found.");
        }

        RepoList.ItemsSource = repos;
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
        string? path = GetTagPath(sender);
        if (path == null) return;

        string? error = _vscode.Launch(path);

        if (error != null)
            ShowError(error);
        else
            SetStatus($"Launched VSCode at: {path}");
    }

    // ------------------------------------------------------------------ //
    //  Pull
    // ------------------------------------------------------------------ //

    private void PullButton_Click(object sender, RoutedEventArgs e)
    {
        string? path = GetTagPath(sender);
        if (path == null) return;

        SetStatus($"Running git pull in: {path}");
        SetAllEnabled(false);

        // Run on a background thread so the UI stays responsive.
        Task.Run(() => _git.Run(GitOperation.Pull, path))
            .ContinueWith(t =>
            {
                var (success, output) = t.Result;
                Dispatcher.Invoke(() =>
                {
                    SetAllEnabled(true);

                    if (!success)
                        ShowError($"git pull failed:\n\n{output}");
                    else
                        SetStatus($"git pull succeeded in: {path}");
                });
            });
    }

    // ------------------------------------------------------------------ //
    //  Push
    // ------------------------------------------------------------------ //

    private void PushButton_Click(object sender, RoutedEventArgs e)
    {
        string? path = GetTagPath(sender);
        if (path == null) return;

        SetStatus($"Running git push in: {path}");
        SetAllEnabled(false);

        Task.Run(() => _git.Run(GitOperation.Push, path))
            .ContinueWith(t =>
            {
                var (success, output) = t.Result;
                Dispatcher.Invoke(() =>
                {
                    SetAllEnabled(true);

                    if (!success)
                        ShowError($"git push failed:\n\n{output}");
                    else
                        SetStatus($"git push succeeded in: {path}");
                });
            });
    }

    // ------------------------------------------------------------------ //
    //  Helpers
    // ------------------------------------------------------------------ //

    /// <summary>Extracts the repository path stored in a button's Tag.</summary>
    private static string? GetTagPath(object sender)
        => (sender as System.Windows.Controls.Button)?.Tag as string;

    /// <summary>Displays a message in the status bar.</summary>
    private void SetStatus(string message, bool isError = false)
    {
        StatusText.Text       = message;
        StatusText.Foreground = isError
            ? System.Windows.Media.Brushes.Firebrick
            : System.Windows.Media.Brushes.DarkSlateGray;
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
}
