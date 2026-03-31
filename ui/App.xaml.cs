using System.Windows;
using KompanionUI.Services;

namespace KompanionUI;

public partial class App : Application
{
    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        // Run the KOMPANION_SOURCE script at startup if it is defined.
        // A warning is shown if the env var is missing or the path does not exist,
        // but the application continues so the user can still browse repos.
        var logger = new Logger();
        var runner = new ScriptRunner(logger);
        string? error = runner.RunKompanionScript();

        if (error != null)
        {
            MessageBox.Show(
                error,
                "Kompanion – Startup Warning",
                MessageBoxButton.OK,
                MessageBoxImage.Warning);
        }
    }
}
