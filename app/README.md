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
| UI framework | WPF (.NET 9) | Richer styling and data-binding than WinForms; native Windows look |
| Main layout | Three tabs: Repositories + Settings + Logs | Separates operational actions, future configuration, and observability |
| Visual design | Teal brand theme (`#009688`) | Matches the app icon for a cohesive, recognizable look |
| Architecture | Thin code-behind + service classes | Keeps UI logic separate; easy to test services in isolation |
| Process execution | Shared `IProcessExecutor` abstraction | Enables deterministic unit tests and consistent timeout/cancel behavior |
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
├── Kompanion.sln               # Solution containing the app and test projects
├── README.md                   # Build, test, publish, and usage guide
├── KompanionUI.Tests/          # Root-level test project
│   ├── KompanionUI.Tests.csproj
│   ├── ScriptRunnerTests.cs
│   ├── GitServiceTests.cs
│   ├── UsageTrackerTests.cs
│   └── FakeProcessExecutor.cs
├── prompt.md                   # Original feature brief / design prompt
└── KompanionUI/
    ├── KompanionUI.csproj      # Project file (WPF, net9.0-windows, single-file)
    ├── App.xaml / App.xaml.cs  # Application entry point; runs KOMPANION_SOURCE
    ├── MainWindow.xaml         # Three-tab UI: Repositories, Settings, and Logs
    ├── MainWindow.xaml.cs      # UI handlers; tray behavior; async/cancellable git actions
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
| `VSCODE_EXTENSIONS` | No | Passed to `code.exe --extensions-dir` |
| `VSCODE_SETTINGS` | No | Passed to `code.exe --user-data-dir` |

---

## Building

```powershell
# From the app/ directory
dotnet build .\Kompanion.sln
```

The application output goes to `KompanionUI\bin\Debug\net9.0-windows\win-x64\KompanionUI.exe`.

---

## Testing

```powershell
# From the app/ directory
dotnet test .\Kompanion.sln
```

The current test coverage verifies:

- `ScriptRunner` startup success env import and non-zero exit-code handling.
- `GitService` repository validation, successful execution, and cancellation behavior.

---

## Publishing a standalone executable

```powershell
# From the app/ directory
dotnet publish .\KompanionUI\KompanionUI.csproj -c Release -o publish
```

The single-file executable is written under
`KompanionUI\bin\Release\net9.0-windows\win-x64\publish\KompanionUI.exe`
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
5. The UI has three tabs:
    - **Repositories**: list of detected repositories and action buttons.
    - **Settings**: placeholder panel for upcoming configuration.
    - **Logs**: readable log viewer with separate timestamp and message columns.
6. Use the buttons in each repository row:
    - **Launch** — opens VS Code at the repository root (detached, maximized, stays open if you close
     the app).
   - **Pull** — runs `git pull`; result is shown in the status bar and logged.
   - **Push** — runs `git push`; result is shown in the status bar and logged.
7. While pull/push is running, use **Cancel Git** to request cancellation.
8. Click **Refresh** at any time to re-scan `KOMPANION_REPO`.
9. Repository order is usage-aware: every Launch/Pull/Push increments a counter in
    `%KOMPANION_LOGS%\repo-usage.json`, repositories are sorted by descending usage,
    and `KOMPANION_DIR` stays pinned at the top.
10. Clicking the window close button sends Kompanion to the system tray instead of
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
