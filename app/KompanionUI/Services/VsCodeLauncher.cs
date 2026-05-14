using System.Diagnostics;
using System.IO;

namespace KompanionUI.Services;

public sealed class LaunchResult
{
    public bool Success { get; init; }

    public string LauncherDisplayName { get; init; } = "VS Code";

    public string? Error { get; init; }
}

/// <summary>
/// Launches VS Code at a given repository path using the environment-configured
/// extensions and user-data directories.
/// </summary>
public class VsCodeLauncher
{
    private static readonly TimeSpan ProbeCacheDuration = TimeSpan.FromMinutes(5);

    private readonly Logger _logger;
    private DateTime _lastProbeUtc;
    private bool _antigravityAvailable;
    private string? _antigravityCommandPath;
    private string? _lastProbeReason;

    public VsCodeLauncher(Logger logger) => _logger = logger;

    /// <summary>
    /// Starts Code.exe detached so it outlives this application.
    /// Optionally prefers antigravity.cmd when it exists and can be started.
    /// </summary>
    public LaunchResult Launch(string repoPath, bool preferAntigravityIfAvailable)
    {
        if (preferAntigravityIfAvailable)
        {
            if (TryGetRunnableAntigravity(out string? antigravityPath, out string? probeReason))
            {
                string? antigravityError = TryLaunchAntigravity(repoPath, antigravityPath!);
                if (antigravityError == null)
                {
                    return new LaunchResult
                    {
                        Success = true,
                        LauncherDisplayName = "Antigravity"
                    };
                }

                _logger.Log($"Antigravity launch failed, falling back to VS Code: {antigravityError}");
                InvalidateAntigravityProbe();
            }
            else
            {
                _logger.Log(
                    "Antigravity preference enabled but unavailable. " +
                    $"Falling back to VS Code. Reason: {probeReason}");
            }
        }

        string? codeError = TryLaunchVsCode(repoPath);

        return new LaunchResult
        {
            Success = codeError == null,
            LauncherDisplayName = "VS Code",
            Error = codeError
        };
    }

    private string? TryLaunchVsCode(string repoPath)
    {
        string? extDir      = Environment.GetEnvironmentVariable("VSCODE_EXTENSIONS");
        string? settingsDir = Environment.GetEnvironmentVariable("VSCODE_SETTINGS");

        // Build the argument list; optional flags are only added when the env vars are set.
        var args = new List<string> { $"\"{repoPath}\"" };

        if (!string.IsNullOrWhiteSpace(extDir))
            args.Add($"--extensions-dir \"{extDir}\"");

        if (!string.IsNullOrWhiteSpace(settingsDir))
            args.Add($"--user-data-dir \"{settingsDir}\"");

        args.Add("--maximized");

        string arguments = string.Join(" ", args);

        try
        {
            _logger.Log($"Launching VSCode at: {repoPath}");

            var psi = new ProcessStartInfo
            {
                FileName        = "code.exe",
                Arguments       = arguments,
                UseShellExecute = true,   // ShellExecute lets the child outlive this process.
                CreateNoWindow  = false,
            };

            Process.Start(psi);
            return null;
        }
        catch (Exception ex)
        {
            string msg = $"Failed to launch VSCode at '{repoPath}': {ex.Message}";
            _logger.Log(msg);
            return msg;
        }
    }

    private bool TryGetRunnableAntigravity(out string? commandPath, out string? reason)
    {
        DateTime now = DateTime.UtcNow;
        if (_lastProbeUtc != default && (now - _lastProbeUtc) <= ProbeCacheDuration)
        {
            commandPath = _antigravityCommandPath;
            reason = _lastProbeReason;
            return _antigravityAvailable;
        }

        _lastProbeUtc = now;

        if (!TryResolveAntigravityCommand(out commandPath, out reason))
        {
            _antigravityAvailable = false;
            _antigravityCommandPath = null;
            _lastProbeReason = reason;
            return false;
        }

        if (!CanStartCommand(commandPath!, out reason))
        {
            _antigravityAvailable = false;
            _antigravityCommandPath = null;
            _lastProbeReason = reason;
            return false;
        }

        _antigravityAvailable = true;
        _antigravityCommandPath = commandPath;
        _lastProbeReason = "antigravity.cmd is available.";
        reason = _lastProbeReason;
        return true;
    }

    private void InvalidateAntigravityProbe()
    {
        _lastProbeUtc = default;
        _antigravityAvailable = false;
        _antigravityCommandPath = null;
        _lastProbeReason = "Probe cache invalidated after launch failure.";
    }

    private static bool TryResolveAntigravityCommand(
        out string? resolvedPath,
        out string? reason)
    {
        resolvedPath = null;

        try
        {
            var whereInfo = new ProcessStartInfo
            {
                FileName = "where.exe",
                Arguments = "antigravity.cmd",
                UseShellExecute = false,
                CreateNoWindow = true,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
            };

            using var process = Process.Start(whereInfo);
            if (process == null)
            {
                reason = "Failed to start where.exe while probing antigravity.cmd.";
                return false;
            }

            if (!process.WaitForExit(2_000))
            {
                TryKill(process);
                reason = "Timed out while probing antigravity.cmd location.";
                return false;
            }

            string output = process.StandardOutput.ReadToEnd();
            if (process.ExitCode != 0 || string.IsNullOrWhiteSpace(output))
            {
                reason = "antigravity.cmd was not found on PATH.";
                return false;
            }

            string firstPath = output
                .Split(new[] { '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries)
                .FirstOrDefault() ?? string.Empty;

            if (string.IsNullOrWhiteSpace(firstPath) || !File.Exists(firstPath))
            {
                reason = "Resolved antigravity.cmd path does not exist.";
                return false;
            }

            resolvedPath = firstPath;
            reason = "antigravity.cmd found.";
            return true;
        }
        catch (Exception ex)
        {
            reason = $"Failed to resolve antigravity.cmd: {ex.Message}";
            return false;
        }
    }

    private static bool CanStartCommand(string commandPath, out string? reason)
    {
        try
        {
            var probeInfo = new ProcessStartInfo
            {
                FileName = "cmd.exe",
                Arguments = $"/c \"\"{commandPath}\" --help\"",
                UseShellExecute = false,
                CreateNoWindow = true,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
            };

            using var process = Process.Start(probeInfo);
            if (process == null)
            {
                reason = "Failed to start antigravity.cmd probe process.";
                return false;
            }

            if (!process.WaitForExit(3_000))
            {
                TryKill(process);
                reason = "antigravity.cmd starts successfully (probe timed out).";
                return true;
            }

            reason = $"antigravity.cmd probe exited with code {process.ExitCode}.";
            return process.ExitCode != 9009;
        }
        catch (Exception ex)
        {
            reason = $"Failed to run antigravity.cmd probe: {ex.Message}";
            return false;
        }
    }

    private string? TryLaunchAntigravity(string repoPath, string commandPath)
    {
        try
        {
            _logger.Log($"Launching Antigravity at: {repoPath}");

            var psi = new ProcessStartInfo
            {
                FileName = commandPath,
                Arguments = $"\"{repoPath}\"",
                UseShellExecute = true,
                CreateNoWindow = false,
            };

            Process.Start(psi);
            return null;
        }
        catch (Exception ex)
        {
            string msg = $"Failed to launch Antigravity at '{repoPath}': {ex.Message}";
            _logger.Log(msg);
            return msg;
        }
    }

    private static void TryKill(Process process)
    {
        try
        {
            process.Kill(entireProcessTree: true);
            process.WaitForExit(1_000);
        }
        catch
        {
            // Best effort.
        }
    }
}
