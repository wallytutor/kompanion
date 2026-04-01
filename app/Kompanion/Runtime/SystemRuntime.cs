using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Threading;
using Kompanion.Abstractions;

namespace Kompanion.Runtime
{
public sealed class SystemEnvironmentReader : IEnvironmentReader
{
    public string? GetVariable(string name) => Environment.GetEnvironmentVariable(name);
}

public sealed class ThreadSleeper : ISleeper
{
    public void Sleep(TimeSpan duration) => Thread.Sleep(duration);
}

public sealed class SystemProcessCatalog : IProcessCatalog
{
    public IReadOnlyList<IProcessInfo> GetProcessesByName(string processName)
    {
        var processes = Process.GetProcessesByName(processName);
        var result = new List<IProcessInfo>(processes.Length);

        foreach (Process process in processes)
        {
            try
            {
                string? path = null;

                try
                {
                    path = process.MainModule?.FileName;
                }
                catch
                {
                    path = null;
                }

                result.Add(new ProcessInfo(process.Id, path));
            }
            finally
            {
                process.Dispose();
            }
        }

        return result;
    }

    public bool IsRunning(int processId)
    {
        try
        {
            using Process process = Process.GetProcessById(processId);
            return !process.HasExited;
        }
        catch
        {
            return false;
        }
    }

    private sealed class ProcessInfo : IProcessInfo
    {
        public ProcessInfo(int id, string? path)
        {
            Id = id;
            Path = path;
        }

        public int Id { get; }

        public string? Path { get; }
    }
}

public sealed class SystemProcessLauncher : IProcessLauncher
{
    public int Start(ProcessStartSpec spec)
    {
        if (string.IsNullOrWhiteSpace(spec.FilePath))
            throw new ArgumentException("File path must be provided.", nameof(spec));

        if (!string.IsNullOrWhiteSpace(spec.StdOutPath))
            Directory.CreateDirectory(Path.GetDirectoryName(spec.StdOutPath) ?? ".");

        if (!string.IsNullOrWhiteSpace(spec.StdErrPath))
            Directory.CreateDirectory(Path.GetDirectoryName(spec.StdErrPath) ?? ".");

        string wrappedCommand = BuildCommand(spec);

        var psi = new ProcessStartInfo
        {
            FileName = "cmd.exe",
            Arguments = wrappedCommand,
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardOutput = false,
            RedirectStandardError = false
        };

        Process? process = Process.Start(psi);
        if (process == null)
            throw new InvalidOperationException("Failed to start process.");

        using (process)
        {
            return process.Id;
        }
    }

    private static string BuildCommand(ProcessStartSpec spec)
    {
        string filePath = Quote(spec.FilePath);
        string args = spec.Arguments ?? string.Empty;

        string outRedirect = string.IsNullOrWhiteSpace(spec.StdOutPath)
            ? string.Empty
            : $" 1>>{Quote(spec.StdOutPath!)}";

        string errRedirect = string.IsNullOrWhiteSpace(spec.StdErrPath)
            ? string.Empty
            : $" 2>>{Quote(spec.StdErrPath!)}";

        return $"/c \"{filePath} {args}{outRedirect}{errRedirect}\"";
    }

    private static string Quote(string value) => $"\"{value.Replace("\"", "\"\"")}\"";
}

public sealed class SystemProcessTerminator : IProcessTerminator
{
    public void StopByIds(IReadOnlyCollection<int> processIds, bool force)
    {
        foreach (int processId in processIds.Distinct())
        {
            try
            {
                using Process process = Process.GetProcessById(processId);
                process.Kill();
            }
            catch
            {
                // Best effort.
            }
        }
    }
}
}