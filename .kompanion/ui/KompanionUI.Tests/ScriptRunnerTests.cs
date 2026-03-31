using KompanionUI.Services;

namespace KompanionUI.Tests;

public class ScriptRunnerTests
{
    [Fact]
    public void RunKompanionScript_ImportsEnvironmentVariables_OnSuccess()
    {
        string scriptPath = CreateTempScript();

        try
        {
            Environment.SetEnvironmentVariable("KOMPANION_SOURCE", scriptPath);
            Environment.SetEnvironmentVariable("TEST_KOMPANION_SCRIPT_VALUE", null);

            var executor = new FakeProcessExecutor
            {
                Handler = (_, _) => new ProcessExecutionResult
                {
                    Started = true,
                    ExitCode = 0,
                    StdOut = string.Join("\n", new[]
                    {
                        "setup output",
                        "---ENV---",
                        "ENV:TEST_KOMPANION_SCRIPT_VALUE=from-script"
                    })
                }
            };

            var runner = new ScriptRunner(new Logger(), executor);

            string? error = runner.RunKompanionScript();

            Assert.Null(error);
            Assert.Equal("from-script",
                Environment.GetEnvironmentVariable("TEST_KOMPANION_SCRIPT_VALUE"));
            Assert.Equal(1, executor.CallCount);
            Assert.NotNull(executor.LastRequest);
            Assert.Equal("powershell.exe", executor.LastRequest!.FileName);
        }
        finally
        {
            Environment.SetEnvironmentVariable("KOMPANION_SOURCE", null);
            Environment.SetEnvironmentVariable("TEST_KOMPANION_SCRIPT_VALUE", null);
            File.Delete(scriptPath);
        }
    }

    [Fact]
    public void RunKompanionScript_ReturnsError_OnNonZeroExitCode()
    {
        string scriptPath = CreateTempScript();

        try
        {
            Environment.SetEnvironmentVariable("KOMPANION_SOURCE", scriptPath);

            var executor = new FakeProcessExecutor
            {
                Handler = (_, _) => new ProcessExecutionResult
                {
                    Started = true,
                    ExitCode = 1,
                    StdErr = "boom"
                }
            };

            var runner = new ScriptRunner(new Logger(), executor);

            string? error = runner.RunKompanionScript();

            Assert.NotNull(error);
            Assert.Contains("exit code 1", error, StringComparison.OrdinalIgnoreCase);
            Assert.Contains("boom", error, StringComparison.OrdinalIgnoreCase);
        }
        finally
        {
            Environment.SetEnvironmentVariable("KOMPANION_SOURCE", null);
            File.Delete(scriptPath);
        }
    }

    private static string CreateTempScript()
    {
        string path = Path.Combine(Path.GetTempPath(), $"kompanion-test-{Guid.NewGuid():N}.ps1");
        File.WriteAllText(path, "Write-Output 'ok'");
        return path;
    }
}
