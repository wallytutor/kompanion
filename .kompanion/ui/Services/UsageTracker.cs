using System.IO;
using System.Text.Json;
using KompanionUI.Models;

namespace KompanionUI.Services;

/// <summary>
/// Persists repository usage counts under $env:KOMPANION_LOGS and provides
/// sorting helpers that prioritize frequently used repositories.
/// </summary>
public class UsageTracker
{
    private const string UsageFileName = "repo-usage.json";

    private readonly Logger _logger;
    private readonly object _sync = new();
    private readonly string? _usageFilePath;

    public UsageTracker(Logger logger)
    {
        _logger = logger;

        string? logDir = Environment.GetEnvironmentVariable("KOMPANION_LOGS");

        if (string.IsNullOrWhiteSpace(logDir))
            return;

        try
        {
            Directory.CreateDirectory(logDir);
            _usageFilePath = Path.Combine(logDir, UsageFileName);
        }
        catch (Exception ex)
        {
            _logger.Log($"Usage tracking disabled because log directory is invalid: {ex.Message}");
        }
    }

    /// <summary>
    /// Increments usage count for a repository path.
    /// </summary>
    public void RecordUsage(string repoPath)
    {
        string normalized = NormalizePath(repoPath);
        if (string.IsNullOrWhiteSpace(normalized) || _usageFilePath == null)
            return;

        lock (_sync)
        {
            Dictionary<string, int> usage = LoadUnsafe();

            usage.TryGetValue(normalized, out int count);
            usage[normalized] = count + 1;

            SaveUnsafe(usage);
        }
    }

    public List<RepoEntry> SortRepos(IEnumerable<RepoEntry> repos, string? pinnedRepoPath)
    {
        List<RepoEntry> repoList = repos.ToList();

        string? pinnedNormalized = NormalizePath(pinnedRepoPath);
        Dictionary<string, int> usage;

        lock (_sync)
        {
            usage = LoadUnsafe();
        }

        RepoEntry? pinned = null;

        if (!string.IsNullOrWhiteSpace(pinnedNormalized))
        {
            pinned = repoList.FirstOrDefault(r =>
                string.Equals(NormalizePath(r.FullPath),
                              pinnedNormalized,
                              StringComparison.OrdinalIgnoreCase));

            if (pinned != null)
                repoList.Remove(pinned);
        }

        List<RepoEntry> sorted = repoList
            .OrderByDescending(r => GetUsageCount(usage, r.FullPath))
            .ThenBy(r => r.Name, StringComparer.OrdinalIgnoreCase)
            .ToList();

        if (pinned != null)
            sorted.Insert(0, pinned);

        return sorted;
    }

    private static int GetUsageCount(IReadOnlyDictionary<string, int> usage, string repoPath)
    {
        string normalized = NormalizePath(repoPath);
        if (string.IsNullOrWhiteSpace(normalized))
            return 0;

        return usage.TryGetValue(normalized, out int count) ? count : 0;
    }

    private Dictionary<string, int> LoadUnsafe()
    {
        if (_usageFilePath == null || !File.Exists(_usageFilePath))
            return new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);

        try
        {
            string json = File.ReadAllText(_usageFilePath);
            var data = JsonSerializer.Deserialize<Dictionary<string, int>>(json);

            if (data == null)
                return new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);

            return new Dictionary<string, int>(data, StringComparer.OrdinalIgnoreCase);
        }
        catch (Exception ex)
        {
            _logger.Log($"Failed to read usage tracker file '{_usageFilePath}': {ex.Message}");
            return new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
        }
    }

    private void SaveUnsafe(Dictionary<string, int> usage)
    {
        if (_usageFilePath == null)
            return;

        try
        {
            string json = JsonSerializer.Serialize(usage,
                new JsonSerializerOptions { WriteIndented = true });
            File.WriteAllText(_usageFilePath, json);
        }
        catch (Exception ex)
        {
            _logger.Log($"Failed to write usage tracker file '{_usageFilePath}': {ex.Message}");
        }
    }

    private static string NormalizePath(string? path)
    {
        if (string.IsNullOrWhiteSpace(path))
            return string.Empty;

        try
        {
            return Path.GetFullPath(path).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        }
        catch
        {
            return path.Trim();
        }
    }
}