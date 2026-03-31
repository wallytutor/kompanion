using System.Diagnostics;
using System.IO;

namespace KompanionUI.Services;

/// <summary>
/// Launches VS Code at a given repository path using the environment-configured
/// extensions and user-data directories.
/// </summary>
public class VsCodeLauncher
{
    private readonly Logger _logger;

    public VsCodeLauncher(Logger logger) => _logger = logger;

    /// <summary>
    /// Starts Code.exe detached so it outlives this application.
    /// Returns an error string on failure, or null on success.
    /// </summary>
    public string? Launch(string repoPath)
    {
        string? extDir      = Environment.GetEnvironmentVariable("VSCODE_EXTENSIONS");
        string? settingsDir = Environment.GetEnvironmentVariable("VSCODE_SETTINGS");

        // Build the argument list; optional flags are only added when the env vars are set.
        var args = new List<string> { $"\"{repoPath}\"" };

        if (!string.IsNullOrWhiteSpace(extDir))
            args.Add($"--extensions-dir \"{extDir}\"");

        if (!string.IsNullOrWhiteSpace(settingsDir))
            args.Add($"--user-data-dir \"{settingsDir}\"");

        string arguments = string.Join(" ", args);

        try
        {
            _logger.Log($"Launching VSCode at: {repoPath}");

            var psi = new ProcessStartInfo
            {
                FileName        = "code.exe",
                Arguments       = arguments,
                UseShellExecute = true,   // ShellExecute lets the child outlive this process.
                CreateNoWindow  = false,
            };

            Process.Start(psi);
            return null;
        }
        catch (Exception ex)
        {
            string msg = $"Failed to launch VSCode at '{repoPath}': {ex.Message}";
            _logger.Log(msg);
            return msg;
        }
    }
}
