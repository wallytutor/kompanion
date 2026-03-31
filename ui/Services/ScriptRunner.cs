using System.Diagnostics;
using System.IO;

namespace KompanionUI.Services;

/// <summary>
/// Executes the PowerShell script pointed to by $env:KOMPANION_SOURCE.
/// </summary>
public class ScriptRunner
{
    private readonly Logger _logger;

    public ScriptRunner(Logger logger) => _logger = logger;

    /// <summary>
    /// Validates and runs the setup script.
    /// Returns an error string if the variable is unset / the path is invalid;
    /// returns null on success.
    /// </summary>
    public string? RunKompanionScript()
    {
        string? scriptPath = Environment.GetEnvironmentVariable("KOMPANION_SOURCE");

        if (string.IsNullOrWhiteSpace(scriptPath))
            return "$env:KOMPANION_SOURCE is not set. Skipping startup script.";

        if (!File.Exists(scriptPath))
            return $"$env:KOMPANION_SOURCE points to a path that does not exist:\n{scriptPath}";

        try
        {
            _logger.Log($"Running startup script: {scriptPath}");

            var psi = new ProcessStartInfo
            {
                FileName               = "powershell.exe",
                Arguments              = $"-NonInteractive -ExecutionPolicy Bypass -File \"{scriptPath}\"",
                UseShellExecute        = false,
                CreateNoWindow         = true,
                RedirectStandardOutput = false,
                RedirectStandardError  = false,
            };

            // Fire-and-forget; we don't block app startup waiting for the script.
            Process.Start(psi);
            return null;
        }
        catch (Exception ex)
        {
            string msg = $"Failed to run startup script '{scriptPath}': {ex.Message}";
            _logger.Log(msg);
            return msg;
        }
    }
}
