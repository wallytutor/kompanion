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

    /// <summary>
    /// Returns a (possibly empty) list of repositories, and an optional
    /// error string when $env:KOMPANION_REPO is missing or invalid.
    /// </summary>
    public (List<RepoEntry> Repos, string? Error) Scan()
    {
        string? repoRoot = Environment.GetEnvironmentVariable("KOMPANION_REPO");

        if (string.IsNullOrWhiteSpace(repoRoot))
            return ([], "$env:KOMPANION_REPO is not set. No repositories to display.");

        if (!Directory.Exists(repoRoot))
            return ([], $"$env:KOMPANION_REPO points to a path that does not exist:\n{repoRoot}");

        try
        {
            var repos = Directory
                .EnumerateDirectories(repoRoot)
                .Where(d => Directory.Exists(Path.Combine(d, ".git")))
                .OrderBy(d => d, StringComparer.OrdinalIgnoreCase)
                .Select(d => new RepoEntry(Path.GetFileName(d), d))
                .ToList();

            _logger.Log($"Scanned '{repoRoot}': found {repos.Count} Git repositories.");
            return (repos, null);
        }
        catch (Exception ex)
        {
            string msg = $"Error scanning '{repoRoot}': {ex.Message}";
            _logger.Log(msg);
            return ([], msg);
        }
    }
}
