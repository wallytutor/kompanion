using KompanionUI.Models;
using KompanionUI.Services;

namespace KompanionUI.Tests;

public class UsageTrackerTests
{
    [Fact]
    public void RecordUsage_WorksWhenLogDirIsSetAfterConstruction()
    {
        string logsDir = Path.Combine(Path.GetTempPath(), $"kompanion-logs-{Guid.NewGuid():N}");
        string? oldLogs = Environment.GetEnvironmentVariable("KOMPANION_LOGS");

        try
        {
            Environment.SetEnvironmentVariable("KOMPANION_LOGS", null);

            var logger = new Logger();
            var tracker = new UsageTracker(logger);

            Environment.SetEnvironmentVariable("KOMPANION_LOGS", logsDir);

            string repo = Path.Combine(logsDir, "repo-late");
            tracker.RecordUsage(repo);

            string usagePath = Path.Combine(logsDir, "repo-usage.json");
            Assert.True(File.Exists(usagePath));
        }
        finally
        {
            Environment.SetEnvironmentVariable("KOMPANION_LOGS", oldLogs);
            if (Directory.Exists(logsDir))
                Directory.Delete(logsDir, recursive: true);
        }
    }

    [Fact]
    public void RecordUsage_WritesAndIncrementsUsageFile()
    {
        string logsDir = Path.Combine(Path.GetTempPath(), $"kompanion-logs-{Guid.NewGuid():N}");
        string? oldLogs = Environment.GetEnvironmentVariable("KOMPANION_LOGS");

        try
        {
            Environment.SetEnvironmentVariable("KOMPANION_LOGS", logsDir);
            Directory.CreateDirectory(logsDir);

            var logger = new Logger();
            var tracker = new UsageTracker(logger);
            string repo = Path.Combine(logsDir, "repo-a");

            tracker.RecordUsage(repo);
            tracker.RecordUsage(repo);

            string usagePath = Path.Combine(logsDir, "repo-usage.json");
            Assert.True(File.Exists(usagePath));

            string json = File.ReadAllText(usagePath);
            Assert.Contains("repo-a", json, StringComparison.OrdinalIgnoreCase);
            Assert.Contains("2", json, StringComparison.OrdinalIgnoreCase);
        }
        finally
        {
            Environment.SetEnvironmentVariable("KOMPANION_LOGS", oldLogs);
            if (Directory.Exists(logsDir))
                Directory.Delete(logsDir, recursive: true);
        }
    }

    [Fact]
    public void SortRepos_PinsMainRepoAndSortsRemainingByUsage()
    {
        string logsDir = Path.Combine(Path.GetTempPath(), $"kompanion-logs-{Guid.NewGuid():N}");
        string? oldLogs = Environment.GetEnvironmentVariable("KOMPANION_LOGS");

        try
        {
            Environment.SetEnvironmentVariable("KOMPANION_LOGS", logsDir);
            Directory.CreateDirectory(logsDir);

            string mainPath = Path.Combine(logsDir, "kompanion-main");
            string pathA = Path.Combine(logsDir, "alpha");
            string pathB = Path.Combine(logsDir, "beta");

            var logger = new Logger();
            var tracker = new UsageTracker(logger);

            tracker.RecordUsage(pathB);
            tracker.RecordUsage(pathB);
            tracker.RecordUsage(pathA);

            var repos = new List<RepoEntry>
            {
                new("Alpha", pathA),
                new("Kompanion", mainPath),
                new("Beta", pathB)
            };

            List<RepoEntry> sorted = tracker.SortRepos(repos, mainPath);

            Assert.Equal(mainPath, sorted[0].FullPath);
            Assert.Equal(pathB, sorted[1].FullPath);
            Assert.Equal(pathA, sorted[2].FullPath);
        }
        finally
        {
            Environment.SetEnvironmentVariable("KOMPANION_LOGS", oldLogs);
            if (Directory.Exists(logsDir))
                Directory.Delete(logsDir, recursive: true);
        }
    }
}
