using System.Diagnostics;
using System.Text;

namespace KompanionUI.Services;

public enum GitOperation { Pull, Push }

/// <summary>
/// Runs git pull or git push in a given repository directory and captures output.
/// </summary>
public class GitService
{
    private readonly Logger _logger;

    public GitService(Logger logger) => _logger = logger;

    /// <summary>
    /// Executes the specified Git operation synchronously.
    /// Returns (success, output) where output contains stdout + stderr.
    /// </summary>
    public (bool Success, string Output) Run(GitOperation op, string repoPath)
    {
        string verb = op == GitOperation.Pull ? "pull" : "push";
        _logger.Log($"git {verb}: {repoPath}");

        var sb = new StringBuilder();

        try
        {
            var psi = new ProcessStartInfo
            {
                FileName               = "git",
                Arguments              = verb,
                WorkingDirectory       = repoPath,
                UseShellExecute        = false,
                CreateNoWindow         = true,
                RedirectStandardOutput = true,
                RedirectStandardError  = true,
            };

            using var process = new Process { StartInfo = psi };

            // Collect both stdout and stderr into the same buffer.
            process.OutputDataReceived += (_, e) =>
            {
                if (e.Data != null) sb.AppendLine(e.Data);
            };
            process.ErrorDataReceived += (_, e) =>
            {
                if (e.Data != null) sb.AppendLine(e.Data);
            };

            process.Start();
            process.BeginOutputReadLine();
            process.BeginErrorReadLine();

            // Wait up to 60 seconds for the operation to complete.
            bool finished = process.WaitForExit(60_000);

            if (!finished)
            {
                process.Kill(entireProcessTree: true);
                string timeout = $"git {verb} timed out after 60 seconds.";
                _logger.Log(timeout);
                return (false, timeout);
            }

            string output  = sb.ToString().TrimEnd();
            bool   success = process.ExitCode == 0;

            _logger.Log($"git {verb} exit {process.ExitCode}: {repoPath}");
            return (success, output);
        }
        catch (Exception ex)
        {
            string msg = $"git {verb} error: {ex.Message}";
            _logger.Log(msg);
            return (false, msg);
        }
    }
}
