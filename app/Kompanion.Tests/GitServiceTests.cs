using KompanionUI.Services;

namespace Kompanion.Tests;

public class GitServiceTests
{
    [Fact]
    public void Run_ReturnsFailure_WhenPathIsMissing()
    {
        var executor = new FakeProcessExecutor
        {
            Handler = (_, _) => new ProcessExecutionResult
            {
                Started = true,
                ExitCode = 0
            }
        };

        var service = new GitService(new Logger(), executor);

        var (success, output) = service.Run(
            GitOperation.Pull,
            Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString("N")));

        Assert.False(success);
        Assert.Contains("does not exist", output, StringComparison.OrdinalIgnoreCase);
        Assert.Equal(0, executor.CallCount);
    }

    [Fact]
    public void Run_ReturnsSuccess_WhenGitReturnsZero()
    {
        string repo = CreateTempRepo();

        try
        {
            var executor = new FakeProcessExecutor
            {
                Handler = (_, _) => new ProcessExecutionResult
                {
                    Started = true,
                    ExitCode = 0,
                    StdOut = "Already up to date."
                }
            };

            var service = new GitService(new Logger(), executor);

            var (success, output) = service.Run(GitOperation.Pull, repo);

            Assert.True(success);
            Assert.Contains("Already up to date", output, StringComparison.OrdinalIgnoreCase);
            Assert.Equal(1, executor.CallCount);
        }
        finally
        {
            Directory.Delete(repo, recursive: true);
        }
    }

    [Fact]
    public void Run_ReturnsCancelled_WhenTokenIsCancelled()
    {
        string repo = CreateTempRepo();

        try
        {
            var executor = new FakeProcessExecutor
            {
                Handler = (_, token) => new ProcessExecutionResult
                {
                    Started = true,
                    Cancelled = token.IsCancellationRequested,
                    ExitCode = token.IsCancellationRequested ? null : 0
                }
            };

            using var cts = new CancellationTokenSource();
            cts.Cancel();

            var service = new GitService(new Logger(), executor);

            var (success, output) = service.Run(GitOperation.Push, repo, cts.Token);

            Assert.False(success);
            Assert.Contains("cancelled", output, StringComparison.OrdinalIgnoreCase);
        }
        finally
        {
            Directory.Delete(repo, recursive: true);
        }
    }

    private static string CreateTempRepo()
    {
        string path = Path.Combine(Path.GetTempPath(), $"kompanion-repo-{Guid.NewGuid():N}");
        Directory.CreateDirectory(path);
        Directory.CreateDirectory(Path.Combine(path, ".git"));
        return path;
    }
}
