using Kompanion.Abstractions;
using Kompanion.Services;

namespace Kompanion.Tests;

public sealed class OllamaServiceTests
{
    [Fact]
    public void Serve_ReturnsNotConfigured_WhenOllamaHomeIsMissing()
    {
        var service = CreateService(new Dictionary<string, string?>());

        OllamaServeResult result = service.Serve();

        Assert.Equal(OllamaServeStatus.NotConfigured, result.Status);
    }

    [Fact]
    public void Serve_ReturnsExecutableNotFound_WhenOllamaExeDoesNotExist()
    {
        string home = CreateTempDirectory();

        try
        {
            var service = CreateService(new Dictionary<string, string?>
            {
                ["OLLAMA_HOME"] = home,
            });

            OllamaServeResult result = service.Serve();

            Assert.Equal(OllamaServeStatus.ExecutableNotFound, result.Status);
        }
        finally
        {
            Directory.Delete(home, recursive: true);
        }
    }

    [Fact]
    public void Serve_ReturnsAlreadyRunning_WhenMatchingProcessExists()
    {
        string home = CreateOllamaHomeWithExe(out string exePath);

        try
        {
            var launcher = new FakeProcessLauncher();
            var processCatalog = new FakeProcessCatalog
            {
                ByName = new List<IProcessInfo>
                {
                    new FakeProcessInfo { Id = 42, Path = exePath }
                }
            };

            var service = CreateService(
                new Dictionary<string, string?> { ["OLLAMA_HOME"] = home },
                processCatalog: processCatalog,
                processLauncher: launcher);

            OllamaServeResult result = service.Serve();

            Assert.Equal(OllamaServeStatus.AlreadyRunning, result.Status);
            Assert.Equal(0, launcher.CallCount);
        }
        finally
        {
            Directory.Delete(home, recursive: true);
        }
    }

    [Fact]
    public void Serve_ReturnsStarted_WhenLaunchSucceedsAndProcessIsRunning()
    {
        string home = CreateOllamaHomeWithExe(out string exePath);
        string logsDir = CreateTempDirectory();

        try
        {
            var launcher = new FakeProcessLauncher { ProcessId = 77 };
            var processCatalog = new FakeProcessCatalog
            {
                IsRunningHandler = pid => pid == 77,
            };

            var service = CreateService(
                new Dictionary<string, string?>
                {
                    ["OLLAMA_HOME"] = home,
                    ["KOMPANION_LOGS"] = logsDir,
                },
                processCatalog: processCatalog,
                processLauncher: launcher);

            OllamaServeResult result = service.Serve();

            Assert.Equal(OllamaServeStatus.Started, result.Status);
            Assert.Equal(77, result.ProcessId);
            Assert.NotNull(launcher.LastSpec);
            Assert.Equal(exePath, launcher.LastSpec!.FilePath);
            Assert.Equal("serve", launcher.LastSpec.Arguments);
        }
        finally
        {
            Directory.Delete(logsDir, recursive: true);
            Directory.Delete(home, recursive: true);
        }
    }

    [Fact]
    public void Stop_ReturnsStopped_WhenTerminatedProcessesAreGone()
    {
        string home = CreateOllamaHomeWithExe(out string exePath);

        try
        {
            var processCatalog = new FakeProcessCatalog
            {
                ByName = new List<IProcessInfo>
                {
                    new FakeProcessInfo { Id = 10, Path = exePath },
                    new FakeProcessInfo { Id = 11, Path = exePath }
                },
                IsRunningHandler = _ => false,
            };
            var terminator = new FakeProcessTerminator();

            var service = CreateService(
                new Dictionary<string, string?> { ["OLLAMA_HOME"] = home },
                processCatalog: processCatalog,
                processTerminator: terminator);

            OllamaStopResult result = service.Stop();

            Assert.Equal(OllamaStopStatus.Stopped, result.Status);
            Assert.Equal(new[] { 10, 11 }, terminator.LastIds);
            Assert.True(terminator.LastForce);
        }
        finally
        {
            Directory.Delete(home, recursive: true);
        }
    }

    [Fact]
    public void Stop_ReturnsStillRunning_WhenAnyProcessRemains()
    {
        string home = CreateOllamaHomeWithExe(out string exePath);

        try
        {
            var processCatalog = new FakeProcessCatalog
            {
                ByName = new List<IProcessInfo>
                {
                    new FakeProcessInfo { Id = 21, Path = exePath },
                    new FakeProcessInfo { Id = 22, Path = exePath }
                },
                IsRunningHandler = pid => pid == 22,
            };

            var service = CreateService(
                new Dictionary<string, string?> { ["OLLAMA_HOME"] = home },
                processCatalog: processCatalog,
                processTerminator: new FakeProcessTerminator());

            OllamaStopResult result = service.Stop();

            Assert.Equal(OllamaStopStatus.StillRunning, result.Status);
            Assert.Equal(new[] { 22 }, result.ProcessIds);
        }
        finally
        {
            Directory.Delete(home, recursive: true);
        }
    }

    private static OllamaService CreateService(
        Dictionary<string, string?> variables,
        FakeProcessCatalog? processCatalog = null,
        FakeProcessLauncher? processLauncher = null,
        FakeProcessTerminator? processTerminator = null)
    {
        return new OllamaService(
            environment: new FakeEnvironmentReader(variables),
            processCatalog: processCatalog ?? new FakeProcessCatalog(),
            processLauncher: processLauncher ?? new FakeProcessLauncher(),
            processTerminator: processTerminator ?? new FakeProcessTerminator(),
            sleeper: new NoOpSleeper());
    }

    private static string CreateTempDirectory()
    {
        string dir = Path.Combine(Path.GetTempPath(), $"kompanion-tests-{Guid.NewGuid():N}");
        Directory.CreateDirectory(dir);
        return dir;
    }

    private static string CreateOllamaHomeWithExe(out string exePath)
    {
        string home = CreateTempDirectory();
        exePath = Path.Combine(home, "ollama.exe");
        File.WriteAllText(exePath, "test");
        return home;
    }

    private sealed class FakeEnvironmentReader(Dictionary<string, string?> variables)
        : IEnvironmentReader
    {
        public string? GetVariable(string name)
        {
            return variables.TryGetValue(name, out string? value) ? value : null;
        }
    }

    private sealed class NoOpSleeper : ISleeper
    {
        public void Sleep(TimeSpan duration)
        {
        }
    }

    private sealed class FakeProcessInfo : IProcessInfo
    {
        public int Id { get; init; }

        public string? Path { get; init; }
    }

    private sealed class FakeProcessCatalog : IProcessCatalog
    {
        public IReadOnlyList<IProcessInfo> ByName { get; init; } = Array.Empty<IProcessInfo>();

        public Func<int, bool> IsRunningHandler { get; init; } = _ => false;

        public IReadOnlyList<IProcessInfo> GetProcessesByName(string processName)
        {
            return ByName;
        }

        public bool IsRunning(int processId)
        {
            return IsRunningHandler(processId);
        }
    }

    private sealed class FakeProcessLauncher : IProcessLauncher
    {
        public int ProcessId { get; init; } = 100;

        public int CallCount { get; private set; }

        public ProcessStartSpec? LastSpec { get; private set; }

        public int Start(ProcessStartSpec spec)
        {
            CallCount++;
            LastSpec = spec;
            return ProcessId;
        }
    }

    private sealed class FakeProcessTerminator : IProcessTerminator
    {
        public IReadOnlyCollection<int> LastIds { get; private set; } = Array.Empty<int>();

        public bool LastForce { get; private set; }

        public void StopByIds(IReadOnlyCollection<int> processIds, bool force)
        {
            LastIds = processIds;
            LastForce = force;
        }
    }
}