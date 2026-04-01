using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using Kompanion.Abstractions;
using Kompanion.Runtime;

namespace Kompanion.Services
{

public sealed class OllamaProcessInfo
{
    public int Id { get; set; }

    public string Path { get; set; } = string.Empty;
}

public enum OllamaServeStatus
{
    Started,
    AlreadyRunning,
    NotConfigured,
    ExecutableNotFound,
    FailedToStart,
    ExitedEarly,
}

public sealed class OllamaServeResult
{
    public OllamaServeStatus Status { get; set; }

    public string Message { get; set; } = string.Empty;

    public int? ProcessId { get; set; }
}

public enum OllamaStopStatus
{
    Stopped,
    NotConfigured,
    NotRunning,
    FailedToStop,
    StillRunning,
}

public sealed class OllamaStopResult
{
    public OllamaStopStatus Status { get; set; }

    public string Message { get; set; } = string.Empty;

    public IReadOnlyList<int> ProcessIds { get; set; } = Array.Empty<int>();
}

public sealed class OllamaService
{
    private const string OllamaHomeEnv = "OLLAMA_HOME";
    private const string KompanionLogsEnv = "KOMPANION_LOGS";

    private readonly IEnvironmentReader _environment;
    private readonly IProcessCatalog _processCatalog;
    private readonly IProcessLauncher _processLauncher;
    private readonly IProcessTerminator _processTerminator;
    private readonly ISleeper _sleeper;

    public OllamaService(
        IEnvironmentReader? environment = null,
        IProcessCatalog? processCatalog = null,
        IProcessLauncher? processLauncher = null,
        IProcessTerminator? processTerminator = null,
        ISleeper? sleeper = null)
    {
        _environment = environment ?? new SystemEnvironmentReader();
        _processCatalog = processCatalog ?? new SystemProcessCatalog();
        _processLauncher = processLauncher ?? new SystemProcessLauncher();
        _processTerminator = processTerminator ?? new SystemProcessTerminator();
        _sleeper = sleeper ?? new ThreadSleeper();
    }

    public IReadOnlyList<OllamaProcessInfo> GetRunningProcesses()
    {
        if (!TryGetOllamaExecutablePath(out string ollamaExePath, out _))
            return Array.Empty<OllamaProcessInfo>();

        return GetRunningProcesses(ollamaExePath);
    }

    public IReadOnlyList<OllamaProcessInfo> GetRunningProcesses(string expectedExecutablePath)
    {
        if (string.IsNullOrWhiteSpace(expectedExecutablePath))
            return Array.Empty<OllamaProcessInfo>();

        StringComparison cmp = StringComparison.OrdinalIgnoreCase;

        return _processCatalog.GetProcessesByName("ollama")
            .Where(p => !string.IsNullOrWhiteSpace(p.Path))
            .Where(p => string.Equals(p.Path, expectedExecutablePath, cmp))
            .Select(p => new OllamaProcessInfo
            {
                Id = p.Id,
                Path = p.Path ?? string.Empty
            })
            .ToList();
    }

    public OllamaServeResult Serve()
    {
        if (!TryGetOllamaExecutablePath(out string ollamaExePath, out OllamaServeResult? error))
            return error!;

        List<OllamaProcessInfo> running = GetRunningProcesses(ollamaExePath).ToList();

        if (running.Count > 0)
        {
            string pids = string.Join(", ", running.Select(p => p.Id));
            return new OllamaServeResult
            {
                Status = OllamaServeStatus.AlreadyRunning,
                Message = $"Ollama server is already running (PID: {pids})."
            };
        }

        try
        {
            string logsDir = GetLogsDirectory();
            string logOut = Path.Combine(logsDir, "ollama.log");
            string logErr = Path.Combine(logsDir, "ollama.err");

            int processId = _processLauncher.Start(new ProcessStartSpec
            {
                FilePath = ollamaExePath,
                Arguments = "serve",
                StdOutPath = logOut,
                StdErrPath = logErr,
            });

            _sleeper.Sleep(TimeSpan.FromSeconds(1));

            if (!_processCatalog.IsRunning(processId))
            {
                return new OllamaServeResult
                {
                    Status = OllamaServeStatus.ExitedEarly,
                    ProcessId = processId,
                    Message = "Ollama process exited before it could be confirmed."
                };
            }

            return new OllamaServeResult
            {
                Status = OllamaServeStatus.Started,
                ProcessId = processId,
                Message = $"Ollama server started (PID: {processId})."
            };
        }
        catch (Exception ex)
        {
            return new OllamaServeResult
            {
                Status = OllamaServeStatus.FailedToStart,
                Message = $"Failed to start Ollama server: {ex.Message}"
            };
        }
    }

    public OllamaStopResult Stop()
    {
        if (!TryGetOllamaExecutablePath(out string ollamaExePath, out _))
        {
            return new OllamaStopResult
            {
                Status = OllamaStopStatus.NotConfigured,
                Message = "OLLAMA_HOME is not configured or points to a missing executable."
            };
        }

        List<OllamaProcessInfo> running = GetRunningProcesses(ollamaExePath).ToList();

        if (running.Count == 0)
        {
            return new OllamaStopResult
            {
                Status = OllamaStopStatus.NotRunning,
                Message = "No Ollama process is currently running for the configured executable."
            };
        }

        List<int> ids = running.Select(p => p.Id).ToList();

        try
        {
            _processTerminator.StopByIds(ids, force: true);
        }
        catch (Exception ex)
        {
            return new OllamaStopResult
            {
                Status = OllamaStopStatus.FailedToStop,
                ProcessIds = ids,
                Message = $"Failed to stop Ollama process(es): {ex.Message}"
            };
        }

        _sleeper.Sleep(TimeSpan.FromSeconds(1));

        List<int> remaining = ids.Where(_processCatalog.IsRunning).ToList();

        if (remaining.Count > 0)
        {
            return new OllamaStopResult
            {
                Status = OllamaStopStatus.StillRunning,
                ProcessIds = remaining,
                Message = $"Ollama is still running (PID: {string.Join(", ", remaining)})."
            };
        }

        return new OllamaStopResult
        {
            Status = OllamaStopStatus.Stopped,
            ProcessIds = ids,
            Message = "Ollama server stopped."
        };
    }

    private bool TryGetOllamaExecutablePath(
        out string ollamaExePath,
        out OllamaServeResult? errorResult)
    {
        string? ollamaHome = _environment.GetVariable(OllamaHomeEnv);

        if (string.IsNullOrWhiteSpace(ollamaHome))
        {
            ollamaExePath = string.Empty;
            errorResult = new OllamaServeResult
            {
                Status = OllamaServeStatus.NotConfigured,
                Message = "OLLAMA_HOME is not set."
            };
            return false;
        }

        ollamaExePath = Path.Combine(ollamaHome, "ollama.exe");

        if (!File.Exists(ollamaExePath))
        {
            errorResult = new OllamaServeResult
            {
                Status = OllamaServeStatus.ExecutableNotFound,
                Message = $"Ollama executable not found at '{ollamaExePath}'."
            };
            return false;
        }

        errorResult = null;
        return true;
    }

    private string GetLogsDirectory()
    {
        string? logs = _environment.GetVariable(KompanionLogsEnv);
        string logsDir = string.IsNullOrWhiteSpace(logs)
            ? Path.Combine(Path.GetTempPath(), "kompanion")
            : logs;

        Directory.CreateDirectory(logsDir);
        return logsDir;
    }
}
}