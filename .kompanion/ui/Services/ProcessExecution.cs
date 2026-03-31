using System.Diagnostics;

namespace KompanionUI.Services;

public sealed class ProcessExecutionRequest
{
    public required string FileName { get; init; }

    public string Arguments { get; init; } = string.Empty;

    public string? WorkingDirectory { get; init; }

    public int TimeoutMs { get; init; } = 60_000;

    public bool CreateNoWindow { get; init; } = true;

    public bool UseShellExecute { get; init; } = false;

    public bool RedirectOutput { get; init; } = true;
}

public sealed class ProcessExecutionResult
{
    public bool Started { get; init; }

    public bool TimedOut { get; init; }

    public bool Cancelled { get; init; }

    public int? ExitCode { get; init; }

    public string StdOut { get; init; } = string.Empty;

    public string StdErr { get; init; } = string.Empty;
}

public interface IProcessExecutor
{
    ProcessExecutionResult Execute(
        ProcessExecutionRequest request,
        CancellationToken cancellationToken = default);
}

public sealed class SystemProcessExecutor : IProcessExecutor
{
    private const int WaitSliceMs = 200;

    public ProcessExecutionResult Execute(
        ProcessExecutionRequest request,
        CancellationToken cancellationToken = default)
    {
        var psi = new ProcessStartInfo
        {
            FileName = request.FileName,
            Arguments = request.Arguments,
            UseShellExecute = request.UseShellExecute,
            CreateNoWindow = request.CreateNoWindow,
            RedirectStandardOutput = request.RedirectOutput,
            RedirectStandardError = request.RedirectOutput,
        };

        if (!string.IsNullOrWhiteSpace(request.WorkingDirectory))
            psi.WorkingDirectory = request.WorkingDirectory;

        using var process = new Process { StartInfo = psi };

        if (!process.Start())
            return new ProcessExecutionResult { Started = false };

        Task<string> stdoutTask = request.RedirectOutput
            ? process.StandardOutput.ReadToEndAsync()
            : Task.FromResult(string.Empty);

        Task<string> stderrTask = request.RedirectOutput
            ? process.StandardError.ReadToEndAsync()
            : Task.FromResult(string.Empty);

        var stopwatch = Stopwatch.StartNew();

        while (!process.WaitForExit(WaitSliceMs))
        {
            if (cancellationToken.IsCancellationRequested)
            {
                TryKill(process);
                return new ProcessExecutionResult
                {
                    Started = true,
                    Cancelled = true,
                    StdOut = GetTaskResultSafe(stdoutTask),
                    StdErr = GetTaskResultSafe(stderrTask),
                };
            }

            if (request.TimeoutMs > 0 && stopwatch.ElapsedMilliseconds > request.TimeoutMs)
            {
                TryKill(process);
                return new ProcessExecutionResult
                {
                    Started = true,
                    TimedOut = true,
                    StdOut = GetTaskResultSafe(stdoutTask),
                    StdErr = GetTaskResultSafe(stderrTask),
                };
            }
        }

        process.WaitForExit();

        return new ProcessExecutionResult
        {
            Started = true,
            ExitCode = process.ExitCode,
            StdOut = GetTaskResultSafe(stdoutTask),
            StdErr = GetTaskResultSafe(stderrTask),
        };
    }

    private static string GetTaskResultSafe(Task<string> task)
    {
        try
        {
            return task.GetAwaiter().GetResult();
        }
        catch
        {
            return string.Empty;
        }
    }

    private static void TryKill(Process process)
    {
        try
        {
            process.Kill(entireProcessTree: true);
            process.WaitForExit(2_000);
        }
        catch
        {
            // Best effort.
        }
    }
}