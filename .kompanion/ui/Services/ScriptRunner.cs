using System.Diagnostics;
using System.IO;

namespace KompanionUI.Services;

/// <summary>
/// Executes the PowerShell script pointed to by $env:KOMPANION_SOURCE and
/// imports any environment variables the script sets back into the current
/// process, so that subsequent services (e.g. RepoScanner) can read them.
/// </summary>
public class ScriptRunner
{
    private readonly Logger _logger;

    public ScriptRunner(Logger logger) => _logger = logger;

    /// <summary>
    /// Validates and runs the setup script synchronously.
    /// After the script finishes, all environment variables that exist in the
    /// PowerShell session are applied to <see cref="Environment"/> so that they
    /// are visible to the rest of the application.
    /// Returns an error string on failure, or null on success.
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

            // Build the PowerShell script as plain text, then Base64-encode it
            // for -EncodedCommand. This avoids all quoting/escaping issues that
            // arise when embedding paths and operators inside -Command "...".
            //
            // The script runs KOMPANION_SOURCE, prints a sentinel, then dumps
            // every env var in NAME=VALUE form so we can import them back.
            string psScript = string.Join("\n",
                $"& '{scriptPath}'",
                "Write-Output '---ENV---'",
                "Get-ChildItem Env: | ForEach-Object {",
                "    Write-Output ('ENV:' + $_.Name + '=' + $_.Value)",
                "}");

            string encodedCommand = Convert.ToBase64String(
                System.Text.Encoding.Unicode.GetBytes(psScript));

            var psi = new ProcessStartInfo
            {
                FileName               = "powershell.exe",
                Arguments              = $"-NonInteractive -ExecutionPolicy Bypass" +
                                         $" -EncodedCommand {encodedCommand}",
                UseShellExecute        = false,
                CreateNoWindow         = true,
                RedirectStandardOutput = true,
                RedirectStandardError  = true,
            };

            using var process = Process.Start(psi)
                ?? throw new InvalidOperationException("Failed to start powershell.exe");

            // Read stdout and stderr concurrently to prevent a deadlock that
            // occurs when both pipe buffers fill before either is drained.
            var stderrTask = Task.Run(() => process.StandardError.ReadToEnd());
            string stdout  = process.StandardOutput.ReadToEnd();
            string stderr  = stderrTask.Result;
            process.WaitForExit();

            if (!string.IsNullOrWhiteSpace(stderr))
                _logger.Log($"Startup script stderr:\n{stderr.TrimEnd()}");

            // Parse and apply env vars that follow the sentinel line.
            bool inEnvSection = false;
            int  imported     = 0;

            foreach (string line in stdout.Split('\n'))
            {
                string trimmed = line.TrimEnd('\r');

                if (trimmed == "---ENV---") { inEnvSection = true; continue; }
                if (!inEnvSection)          continue;
                if (!trimmed.StartsWith("ENV:", StringComparison.Ordinal)) continue;

                // Format is  ENV:NAME=VALUE  (value may itself contain '=')
                int sep = trimmed.IndexOf('=', 4);
                if (sep < 0) continue;

                string key   = trimmed.Substring(4, sep - 4);
                string value = trimmed.Substring(sep + 1);

                Environment.SetEnvironmentVariable(key, value,
                    EnvironmentVariableTarget.Process);
                imported++;
            }

            _logger.Log($"Startup script completed. {imported} environment variable(s) imported.");
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
