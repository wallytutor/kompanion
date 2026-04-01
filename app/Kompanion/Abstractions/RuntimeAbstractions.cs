using System;
using System.Collections.Generic;

namespace Kompanion.Abstractions
{
    public interface IEnvironmentReader
    {
        string? GetVariable(string name);
    }

    public interface ISleeper
    {
        void Sleep(TimeSpan duration);
    }

    public interface IProcessInfo
    {
        int Id { get; }

        string? Path { get; }
    }

    public interface IProcessCatalog
    {
        IReadOnlyList<IProcessInfo> GetProcessesByName(string processName);

        bool IsRunning(int processId);
    }

    public sealed class ProcessStartSpec
    {
        public string FilePath { get; set; } = string.Empty;

        public string Arguments { get; set; } = string.Empty;

        public string? StdOutPath { get; set; }

        public string? StdErrPath { get; set; }
    }

    public interface IProcessLauncher
    {
        int Start(ProcessStartSpec spec);
    }

    public interface IProcessTerminator
    {
        void StopByIds(IReadOnlyCollection<int> processIds, bool force);
    }
}