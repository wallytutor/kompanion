using System.IO;
using KompanionUI.Models;

namespace KompanionUI.Services;

/// <summary>
/// Scans the directory given by $env:KOMPANION_REPO and returns only
/// subdirectories that contain a .git folder (i.e. Git repositories).
/// </summary>
public class RepoScanner
{
    private readonly Logger _logger;

    public RepoScanner(Logger logger) => _logger = logger;

    private const string MainRepoEnvVar = "KOMPANION_DIR";
    private const string RepoRootEnvVar = "KOMPANION_REPO";

    /// <summary>
    /// Returns a (possibly empty) list of repositories, and an optional
    /// error string when $env:KOMPANION_REPO is missing or invalid.
    /// </summary>
    public (List<RepoEntry> Repos, string? Error) Scan()
    {
        var repos = new List<RepoEntry>();
        string? repoRoot = Environment.GetEnvironmentVariable(RepoRootEnvVar);
        RepoEntry? mainRepo = GetMainRepoEntry();

        if (mainRepo != null)
            repos.Add(mainRepo);

        if (string.IsNullOrWhiteSpace(repoRoot))
        {
            string error = "$env:KOMPANION_REPO is not set. No repositories to display.";
            _logger.Log(error);
            return (repos, error);
        }

        if (!Directory.Exists(repoRoot))
        {
            string error =
                $"$env:{RepoRootEnvVar} points to a path that does not exist:\n{repoRoot}";
            _logger.Log(error);
            return (repos, error);
        }

        try
        {
            var discoveredRepos = Directory
                .EnumerateDirectories(repoRoot)
                .Where(d => Directory.Exists(Path.Combine(d, ".git")))
                .Where(d => mainRepo == null ||
                    !string.Equals(d, mainRepo.FullPath, StringComparison.OrdinalIgnoreCase))
                .OrderBy(d => d, StringComparer.OrdinalIgnoreCase)
                .Select(d => new RepoEntry(Path.GetFileName(d), d))
                .ToList();

            repos.AddRange(discoveredRepos);

            _logger.Log($"Scanned '{repoRoot}': found {repos.Count} Git repositories.");
            return (repos, null);
        }
        catch (Exception ex)
        {
            string msg = $"Error scanning '{repoRoot}': {ex.Message}";
            _logger.Log(msg);
            return (repos, msg);
        }
    }

    private RepoEntry? GetMainRepoEntry()
    {
        string? mainRepoPath = Environment.GetEnvironmentVariable(MainRepoEnvVar);

        if (string.IsNullOrWhiteSpace(mainRepoPath))
            return null;

        if (!Directory.Exists(mainRepoPath))
        {
            _logger.Log(
                $"$env:{MainRepoEnvVar} points to a path that does not exist: {mainRepoPath}");
            return null;
        }

        if (!Directory.Exists(Path.Combine(mainRepoPath, ".git")))
        {
            _logger.Log(
                $"$env:{MainRepoEnvVar} was ignored because '.git' was not found: {mainRepoPath}");
            return null;
        }

        return new RepoEntry(Path.GetFileName(mainRepoPath), mainRepoPath);
    }
}
