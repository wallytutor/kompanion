using System.IO;

namespace KompanionUI.Services;

/// <summary>
/// Appends timestamped log entries to a file inside $env:KOMPANION_LOGS.
/// Silently swallows I/O errors so logging never crashes the UI.
/// </summary>
public class Logger
{
    private readonly object _sync = new();
    private string? _logPath;

    public string? LogPath
    {
        get
        {
            EnsureLogPath();
            return _logPath;
        }
    }

    public Logger()
    {
        // The startup script may define KOMPANION_LOGS after this service is
        // constructed, so path resolution is deferred until first use.
    }

    /// <summary>Writes a single line with an ISO-8601 timestamp prefix.</summary>
    public void Log(string message)
    {
        EnsureLogPath();
        if (_logPath == null) return;

        try
        {
            string line = $"[{DateTime.Now:yyyy-MM-dd HH:mm:ss}] {message}";
            File.AppendAllText(_logPath, line + Environment.NewLine);
        }
        catch
        {
            // Best-effort logging; ignore failures.
        }
    }

    private void EnsureLogPath()
    {
        if (!string.IsNullOrWhiteSpace(_logPath))
            return;

        lock (_sync)
        {
            if (!string.IsNullOrWhiteSpace(_logPath))
                return;

            string? dir = Environment.GetEnvironmentVariable("KOMPANION_LOGS");
            if (string.IsNullOrWhiteSpace(dir))
                return;

            try
            {
                Directory.CreateDirectory(dir);
                _logPath = Path.Combine(dir, "kompanion-ui.log");
            }
            catch
            {
                // If we cannot create the directory, logging remains disabled.
                _logPath = null;
            }
        }
    }
}
