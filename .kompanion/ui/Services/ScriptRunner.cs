using System.IO;

namespace KompanionUI.Services;

/// <summary>
/// Executes the PowerShell script pointed to by $env:KOMPANION_SOURCE and
/// imports any environment variables the script sets back into the current
/// process, so that subsequent services (e.g. RepoScanner) can read them.
/// </summary>
public class ScriptRunner
{
    private const int StartupScriptTimeoutMs = 120_000;

    private readonly Logger _logger;
    private readonly IProcessExecutor _processExecutor;

    public ScriptRunner(Logger logger, IProcessExecutor? processExecutor = null)
    {
        _logger = logger;
        _processExecutor = processExecutor ?? new SystemProcessExecutor();
    }

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

            string escapedScriptPath = scriptPath.Replace("'", "''");

            // Build the PowerShell script as plain text, then Base64-encode it
            // for -EncodedCommand. This avoids all quoting/escaping issues that
            // arise when embedding paths and operators inside -Command "...".
            //
            // The script runs KOMPANION_SOURCE, prints a sentinel, then dumps
            // every env var in NAME=VALUE form so we can import them back.
            string psScript = string.Join("\n",
                $"& '{escapedScriptPath}'",
                "Write-Output '---ENV---'",
                "Get-ChildItem Env: | ForEach-Object {",
                "    Write-Output ('ENV:' + $_.Name + '=' + $_.Value)",
                "}");

            string encodedCommand = Convert.ToBase64String(
                System.Text.Encoding.Unicode.GetBytes(psScript));

            ProcessExecutionResult result = _processExecutor.Execute(
                new ProcessExecutionRequest
                {
                    FileName = "powershell.exe",
                    Arguments = "-NonInteractive -ExecutionPolicy Bypass " +
                                $"-EncodedCommand {encodedCommand}",
                    TimeoutMs = StartupScriptTimeoutMs,
                    CreateNoWindow = true,
                    UseShellExecute = false,
                    RedirectOutput = true,
                });

            if (!result.Started)
                throw new InvalidOperationException("Failed to start powershell.exe");

            if (result.TimedOut)
            {
                string timeout = $"Startup script timed out after " +
                                 $"{StartupScriptTimeoutMs / 1000} seconds.";
                _logger.Log(timeout);
                return timeout;
            }

            string stdout = result.StdOut;
            string stderr = result.StdErr;
            int exitCode = result.ExitCode ?? -1;

            if (exitCode != 0)
            {
                string fail = $"Startup script failed with exit code {exitCode}.";

                if (!string.IsNullOrWhiteSpace(stderr))
                    fail += $"\n\n{stderr.TrimEnd()}";

                _logger.Log(fail);
                return fail;
            }

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

            if (!inEnvSection)
                _logger.Log("Startup script completed, but no environment section was found.");

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
