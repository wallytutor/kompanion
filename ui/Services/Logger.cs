using System.IO;

namespace KompanionUI.Services;

/// <summary>
/// Appends timestamped log entries to a file inside $env:KOMPANION_LOGS.
/// Silently swallows I/O errors so logging never crashes the UI.
/// </summary>
public class Logger
{
    private readonly string? _logPath;

    public Logger()
    {
        string? dir = Environment.GetEnvironmentVariable("KOMPANION_LOGS");

        if (!string.IsNullOrWhiteSpace(dir))
        {
            try
            {
                Directory.CreateDirectory(dir);
                _logPath = Path.Combine(dir, "kompanion-ui.log");
            }
            catch
            {
                // If we cannot create the directory, logging is disabled.
                _logPath = null;
            }
        }
    }

    /// <summary>Writes a single line with an ISO-8601 timestamp prefix.</summary>
    public void Log(string message)
    {
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
}
