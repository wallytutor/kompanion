using System.IO;

namespace KompanionUI.Services;

public enum GitOperation { Pull, Push }

/// <summary>
/// Runs git pull or git push in a given repository directory and captures output.
/// </summary>
public class GitService
{
    private const int GitTimeoutMs = 60_000;

    private readonly Logger _logger;
    private readonly IProcessExecutor _processExecutor;

    public GitService(Logger logger, IProcessExecutor? processExecutor = null)
    {
        _logger = logger;
        _processExecutor = processExecutor ?? new SystemProcessExecutor();
    }

    /// <summary>
    /// Executes the specified Git operation synchronously.
    /// Returns (success, output) where output contains stdout + stderr.
    /// </summary>
    public (bool Success, string Output) Run(
        GitOperation op,
        string repoPath,
        CancellationToken cancellationToken = default)
    {
        string verb = op == GitOperation.Pull ? "pull" : "push";
        _logger.Log($"git {verb}: {repoPath}");

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
            ProcessExecutionResult result = _processExecutor.Execute(
                new ProcessExecutionRequest
                {
                    FileName = "git",
                    Arguments = verb,
                    WorkingDirectory = repoPath,
                    TimeoutMs = GitTimeoutMs,
                    CreateNoWindow = true,
                    UseShellExecute = false,
                    RedirectOutput = true,
                },
                cancellationToken);

            if (!result.Started)
            {
                string startFailed = $"git {verb} failed to start.";
                _logger.Log(startFailed);
                return (false, startFailed);
            }

            string output = CombineOutput(result.StdOut, result.StdErr);

            if (result.Cancelled)
            {
                string cancelled = $"git {verb} cancelled by user.";
                _logger.Log(cancelled);
                if (!string.IsNullOrWhiteSpace(output))
                    _logger.Log($"git {verb} output before cancellation:\n{output}");
                return (false, cancelled);
            }

            if (result.TimedOut)
            {
                string timeout = $"git {verb} timed out after {GitTimeoutMs / 1000} seconds.";
                _logger.Log(timeout);
                if (!string.IsNullOrWhiteSpace(output))
                    _logger.Log($"git {verb} output before timeout:\n{output}");
                return (false, timeout);
            }

            int exitCode = result.ExitCode ?? -1;
            bool success = exitCode == 0;

            _logger.Log($"git {verb} exit {exitCode}: {repoPath}");

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

    /// <summary>
    /// Executes <c>git status</c> in the given repository directory and returns the output.
    /// </summary>
    public (bool Success, string Output) GetStatus(string repoPath)
    {
        if (!Directory.Exists(repoPath))
        {
            string missing = $"git status failed: repository path does not exist: {repoPath}";
            _logger.Log(missing);
            return (false, missing);
        }

        bool hasGitMarker = Directory.Exists(Path.Combine(repoPath, ".git")) ||
                            File.Exists(Path.Combine(repoPath, ".git"));

        if (!hasGitMarker)
        {
            string notRepo = $"git status failed: '{repoPath}' is not a Git repository.";
            _logger.Log(notRepo);
            return (false, notRepo);
        }

        try
        {
            ProcessExecutionResult result = _processExecutor.Execute(
                new ProcessExecutionRequest
                {
                    FileName = "git",
                    Arguments = "status",
                    WorkingDirectory = repoPath,
                    TimeoutMs = GitTimeoutMs,
                    CreateNoWindow = true,
                    UseShellExecute = false,
                    RedirectOutput = true,
                });

            if (!result.Started)
            {
                string startFailed = "git status failed to start.";
                _logger.Log(startFailed);
                return (false, startFailed);
            }

            string output = CombineOutput(result.StdOut, result.StdErr);

            if (result.TimedOut)
            {
                string timeout = $"git status timed out after {GitTimeoutMs / 1000} seconds.";
                _logger.Log(timeout);
                return (false, timeout);
            }

            int exitCode = result.ExitCode ?? -1;
            bool success = exitCode == 0;
            _logger.Log($"git status exit {exitCode}: {repoPath}");

            return (success, string.IsNullOrWhiteSpace(output) ? "(no output)" : output);
        }
        catch (Exception ex)
        {
            string msg = $"git status error: {ex.Message}";
            _logger.Log(msg);
            return (false, msg);
        }
    }

    /// <summary>
    /// Checks if a repository has any uncommitted changes or divergence from remote.
    /// Returns true if repository is clean (all committed, in sync with remote),
    /// false if there are changes or any check fails.
    /// </summary>
    public bool IsRepositoryClean(string repoPath)
    {
        var (success, output) = GetStatus(repoPath);

        if (!success)
            return false;

        // If output is empty or just says nothing to commit, repo is clean.
        if (string.IsNullOrWhiteSpace(output) || output == "(no output)")
            return true;

        string lowerOutput = output.ToLowerInvariant();

        // Git status output indicates changes if it contains any of these keywords:
        // - "working tree clean" / "nothing to commit" = clean
        // - "modified" / "deleted" / "new file" = uncommitted changes
        // - "changes not staged" = uncommitted modifications
        // - "to be committed" = staged changes
        // - "ahead" = commits not yet pushed
        // - "behind" = need to pull
        // - "diverged" = both ahead and behind
        // - "Untracked files" = untracked files present

        bool isClean = lowerOutput.Contains("working tree clean")
                    || lowerOutput.Contains("nothing to commit");

        if (isClean)
            return true;

        // If output contains any indicator of changes, repo is not clean.
        if (lowerOutput.Contains("modified")
         || lowerOutput.Contains("deleted")
         || lowerOutput.Contains("new file")
         || lowerOutput.Contains("changes not staged")
         || lowerOutput.Contains("to be committed")
         || lowerOutput.Contains("untracked files")
         || lowerOutput.Contains("ahead")
         || lowerOutput.Contains("behind")
         || lowerOutput.Contains("diverged"))
        {
            return false;
        }

        // If output doesn't contain any known status, assume it's clean.
        return true;
    }

    private static string CombineOutput(string stdout, string stderr)
    {
        if (string.IsNullOrWhiteSpace(stdout))
            return stderr.TrimEnd();

        if (string.IsNullOrWhiteSpace(stderr))
            return stdout.TrimEnd();

        return $"{stdout.TrimEnd()}\n{stderr.TrimEnd()}";
    }
}
