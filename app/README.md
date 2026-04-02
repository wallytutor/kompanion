# KompanionUI

A self-contained WPF application for Windows that bootstraps your development environment, scans a directory for Git repositories, and lets you launch VS Code, pull, or push each one with a single click.

---

## Table of contents

1. [Concept and design decisions](#concept-and-design-decisions)
2. [Project structure](#project-structure)
3. [Tutorial – creating a similar app from scratch](#tutorial--creating-a-similar-app-from-scratch)
4. [Environment variables](#environment-variables)
5. [Building](#building)
6. [Testing](#testing)
7. [Publishing a standalone executable](#publishing-a-standalone-executable)
8. [Generating the icon](#generating-the-icon)
9. [Using the application](#using-the-application)
10. [Log file](#log-file)

---

## Concept and design decisions

| Question | Decision | Rationale |
|---|---|---|
| UI framework | WPF (.NET 10) | Richer styling and data-binding than WinForms; native Windows look |
| Main layout | Five tabs: Repositories + Settings + Ollama + Applications + Logs | Separates operational actions, app behavior settings, observability, and external service controls |
| Screen-lock prevention | Mouse jiggling every 10 seconds (enabled by default) | Light cursor movement can keep systems from auto-locking during active sessions |
| Visual design | Teal brand theme (`#009688`) | Matches the app icon for a cohesive, recognizable look |
| Architecture | Thin code-behind + service classes | Keeps UI logic separate; easy to test services in isolation |
| Process execution | Shared `IProcessExecutor` abstraction plus `Kompanion` core services | Enables deterministic unit tests and reuse of process control logic across apps |
| Startup script | Run synchronously, then import env vars | A child process cannot push env vars back to the parent; we dump `Get-ChildItem Env:` after the script and call `Environment.SetEnvironmentVariable` for each entry |
| Git operations | Async UI handlers + background execution | Keeps the UI responsive and guarantees controls are re-enabled via `try/finally` |
| Git cancellation | UI cancel button + cancellation token | Long pull/push operations can be stopped cleanly by the user |
| Repository ordering | Usage-frequency file + pinned main repo | Most-used repositories stay near the top while Kompanion remains first |
| Log visibility | Dedicated Logs tab with timestamp + message columns | Provides readable, structured log output directly in the app |
| VS Code launch | Detached shell launch + `--maximized` | VS Code opens in full view and outlives the launcher process |
| Error handling | Validate input paths and exit codes | User gets immediate actionable feedback and logs include root-cause details |
| Distribution | Single-file self-contained (`win-x64`) | No .NET runtime installation required on the target machine |
| Icon | Generated programmatically with `System.Drawing` | No external dependency; reproducible by running the included PowerShell snippet |

---

## Project structure

```
app/
├── Kompanion.slnx              # Solution containing core, UI, and test projects
├── README.md                   # Build, test, publish, and usage guide
├── Kompanion/                  # Core library (net10.0)
│   ├── Kompanion.csproj
│   └── Services/
│       └── OllamaService.cs
├── Kompanion.Tests/            # Root-level test project
│   ├── Kompanion.Tests.csproj
│   ├── ScriptRunnerTests.cs
│   ├── GitServiceTests.cs
│   ├── OllamaServiceTests.cs
│   ├── UsageTrackerTests.cs
│   └── FakeProcessExecutor.cs
├── prompt.md                   # Original feature brief / design prompt
└── KompanionUI/
    ├── KompanionUI.csproj      # Project file (WPF, net10.0-windows, single-file)
    ├── App.xaml / App.xaml.cs  # Application entry point; runs KOMPANION_SOURCE
    ├── MainWindow.xaml         # Five-tab UI: Repositories, Settings, Ollama, Applications, Logs
    ├── MainWindow.xaml.cs      # UI handlers; tray behavior; async/cancellable git actions; mouse jiggling
    ├── Assets/
    │   └── icon.ico            # App icon (teal circle + white "K", 48/32/16 px)
    ├── Models/
    │   └── RepoEntry.cs        # Data model: Name + FullPath for one repository
    └── Services/
        ├── Logger.cs           # Timestamped log → $env:KOMPANION_LOGS
        ├── ScriptRunner.cs     # Runs KOMPANION_SOURCE, enforces timeout, imports env vars
        ├── RepoScanner.cs      # Scans KOMPANION_REPO for .git directories
        ├── UsageTracker.cs     # Persists repo usage counts and sorts by frequency
        ├── VsCodeLauncher.cs   # Launches code.exe with --extensions-dir / --user-data-dir
        ├── GitService.cs       # Executes git pull / git push; validates repo; captures output
        └── ProcessExecution.cs # IProcessExecutor + default system implementation
```

---

## Environment variables

| Variable | Required | Purpose |
|---|---|---|
| `KOMPANION_SOURCE` | Yes | Path to a PowerShell `.ps1` script run at startup |
| `KOMPANION_REPO` | Yes | Directory scanned for Git repositories |
| `KOMPANION_DIR` | No | Main repository pinned to the top of the list when it is a Git repository |
| `KOMPANION_LOGS` | No | Directory where `kompanion-ui.log` is written |
| `OLLAMA_HOME` | Required for Ollama tab | Directory containing `ollama.exe` |
| `VSCODE_EXTENSIONS` | No | Passed to `code.exe --extensions-dir` |
| `VSCODE_SETTINGS` | No | Passed to `code.exe --user-data-dir` |

---

## Building

```powershell
# From the app/ directory
dotnet build .\Kompanion.slnx
```

The application output goes to `KompanionUI\bin\Debug\net10.0-windows\win-x64\KompanionUI.exe`.

---

## Testing

```powershell
# From the app/ directory
dotnet test .\Kompanion.slnx
```

The current test coverage verifies:

- `ScriptRunner` startup success env import and non-zero exit-code handling.
- `GitService` repository validation, successful execution, and cancellation behavior.
- `OllamaService` start/stop lifecycle outcomes with mocked runtime abstractions.

---

## Publishing a standalone executable

```powershell
# From the app/ directory
dotnet publish .\KompanionUI\KompanionUI.csproj -c Release -o publish
```

The single-file executable is written under
`KompanionUI\bin\Release\net10.0-windows\win-x64\publish\KompanionUI.exe`
(~128 MB, all dependencies bundled).

---

## Using the application

1. Set the required environment variables (typically in your `KOMPANION_SOURCE` script or
   your shell profile).
2. Build the solution or publish the application from `app\`.
3. Run `KompanionUI.exe` from the build or publish output.
4. The startup script is executed and its environment is imported. The repository list
    is populated automatically. If `KOMPANION_DIR` is set to a Git repository, it is shown
    first even when it is outside `KOMPANION_REPO`.
5. The UI has five tabs:
    - **Repositories**: list of detected repositories and action buttons.
    - **Settings**: behavior controls, including the mouse jiggling toggle.
    - **Ollama**: start/stop/refresh Ollama server status using the shared core `OllamaService`.
    - **Applications**: launch external applications such as Logseq.
    - **Logs**: readable log viewer with separate timestamp and message columns.

6. Mouse jiggling (screen-lock prevention):

Mouse jiggling is enabled by default while KompanionUI is running. Every 10 seconds, the app slightly moves the cursor and returns it to the original position.

If you are not familiar with mouse jiggling: it is a small automatic cursor movement used to keep some systems from treating the session as idle. It does not click, type, or interact with applications.

To enable or disable it:

1. Open KompanionUI.
2. Select the **Settings** tab.
3. Toggle **Enable mouse jiggling every 10 seconds** on or off.

When this option is turned off, KompanionUI stops simulating cursor movement immediately.

7. Use the buttons in each repository row:
    - **Launch** — opens VS Code at the repository root (detached, maximized, stays open if you close
      the app).
    - **Pull** — runs `git pull`; result is shown in the status bar and logged.
    - **Push** — runs `git push`; result is shown in the status bar and logged.
    - **Status** — runs `git status` and shows the full output in a popup window. This lets you
      quickly inspect uncommitted changes, the current branch, and whether the branch is ahead or
      behind the remote, without opening VS Code. If you are not familiar with `git status`: it
      reports the state of the working tree — modified files, staged changes, untracked files, and
      the relationship with the remote branch. The Status button does not modify the repository in
      any way.
8. While pull/push is running, use **Cancel Git** to request cancellation.
9. Click **Refresh** at any time to re-scan `KOMPANION_REPO`.
9.1. Repository status indicators:
    - A small colored circle appears to the left of each repository name:
      - **Gray** — status has not been checked yet.
      - **Green** — repository is clean (no uncommitted changes, in sync with remote).
      - **Red** — repository has changes (uncommitted modifications, untracked files, or divergence from remote).
    Click **Check All** (next to **Refresh**) to scan all repositories at once and update the indicators.
    This is useful for quickly identifying which repositories need attention without running Git commands.
10. Repository order is usage-aware: every Launch/Pull/Push increments a counter in
    `%KOMPANION_LOGS%\repo-usage.json`, repositories are sorted by descending usage,
    and `KOMPANION_DIR` stays pinned at the top.
11. In the **Ollama** tab:
    - Use **Start Server** to launch `ollama.exe serve` from `OLLAMA_HOME`.
    - Use **Stop Server** to stop Ollama processes matching that executable path.
    - Use **Refresh** to reload running process status (PID and executable path).
12. Clicking the window close button sends Kompanion to the system tray instead of
    exiting. Use the tray icon to restore the window, choose **Exit** from the tray menu,
    or use **File > Exit** in the app window to stop the app.

---

## Log file

When `KOMPANION_LOGS` is set, every action is appended to
`%KOMPANION_LOGS%\kompanion-ui.log` with an ISO-8601 timestamp:

```
[2026-03-31 14:05:02] Running startup script: C:\kompanion\setup.ps1
[2026-03-31 14:05:03] Startup script completed. 12 environment variable(s) imported.
[2026-03-31 14:05:03] Scanned 'D:\repos': found 8 Git repositories.
[2026-03-31 14:07:11] git pull: D:\repos\my-project
[2026-03-31 14:07:13] git pull exit 0: D:\repos\my-project
[2026-03-31 14:07:13] git pull output:
Already up to date.
```

Additional log entries are emitted for startup script timeout or non-zero exit
codes, invalid repository paths, and ignored non-Git main-repo paths.

Repository usage counters are stored separately in `%KOMPANION_LOGS%\repo-usage.json`.
