using System.Diagnostics;
using System.IO;
using System.Text;

namespace KompanionUI.Services;

public enum GitOperation { Pull, Push }

/// <summary>
/// Runs git pull or git push in a given repository directory and captures output.
/// </summary>
public class GitService
{
    private const int GitTimeoutMs = 60_000;

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

        if (!Directory.Exists(repoPath))
        {
            string missing = $"git {verb} failed: repository path does not exist: {repoPath}";
            _logger.Log(missing);
            return (false, missing);
        }

        bool hasGitMarker = Directory.Exists(Path.Combine(repoPath, ".git")) ||
                            File.Exists(Path.Combine(repoPath, ".git"));

        if (!hasGitMarker)
        {
            string notRepo = $"git {verb} failed: '{repoPath}' is not a Git repository.";
            _logger.Log(notRepo);
            return (false, notRepo);
        }

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
            bool finished = process.WaitForExit(GitTimeoutMs);

            if (!finished)
            {
                process.Kill(entireProcessTree: true);
                string timeout = $"git {verb} timed out after {GitTimeoutMs / 1000} seconds.";
                _logger.Log(timeout);
                return (false, timeout);
            }

            // Ensure async output events flush into the buffer before reading result.
            process.WaitForExit();

            string output  = sb.ToString().TrimEnd();
            bool   success = process.ExitCode == 0;

            _logger.Log($"git {verb} exit {process.ExitCode}: {repoPath}");

            // Always log the captured output so failures are traceable without
            // needing to re-run the command manually.
            if (!string.IsNullOrWhiteSpace(output))
                _logger.Log($"git {verb} output:\n{output}");

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
