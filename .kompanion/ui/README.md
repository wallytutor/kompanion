# KompanionUI

A self-contained WPF application for Windows that bootstraps your development environment, scans a directory for Git repositories, and lets you launch VS Code, pull, or push each one with a single click.

---

## Table of contents

1. [Concept and design decisions](#concept-and-design-decisions)
2. [Project structure](#project-structure)
3. [Tutorial – creating a similar app from scratch](#tutorial--creating-a-similar-app-from-scratch)
4. [Environment variables](#environment-variables)
5. [Building](#building)
6. [Publishing a standalone executable](#publishing-a-standalone-executable)
7. [Generating the icon](#generating-the-icon)
8. [Using the application](#using-the-application)
9. [Log file](#log-file)

---

## Concept and design decisions

| Question | Decision | Rationale |
|---|---|---|
| UI framework | WPF (.NET 9) | Richer styling and data-binding than WinForms; native Windows look |
| Architecture | Thin code-behind + service classes | Keeps UI logic separate; easy to test services in isolation |
| Startup script | Run synchronously, then import env vars | A child process cannot push env vars back to the parent; we dump `Get-ChildItem Env:` after the script and call `Environment.SetEnvironmentVariable` for each entry |
| Git operations | Background `Task.Run` with output capture | Keeps the UI responsive; full stdout+stderr is written to the log |
| VS Code launch | `UseShellExecute = true` | The child process is fully detached and outlives the launcher |
| Distribution | Single-file self-contained (`win-x64`) | No .NET runtime installation required on the target machine |
| Icon | Generated programmatically with `System.Drawing` | No external dependency; reproducible by running the included PowerShell snippet |

---

## Project structure

```
ui/
├── KompanionUI.csproj          # Project file (WPF, net9.0-windows, single-file)
├── App.xaml / App.xaml.cs      # Application entry point; runs KOMPANION_SOURCE
├── MainWindow.xaml             # Repository table with Refresh toolbar
├── MainWindow.xaml.cs          # Button event handlers; async git operations
├── Assets/
│   └── icon.ico                # App icon (teal circle + white "K", 48/32/16 px)
├── Models/
│   └── RepoEntry.cs            # Data model: Name + FullPath for one repository
└── Services/
    ├── Logger.cs               # Timestamped log → $env:KOMPANION_LOGS
    ├── ScriptRunner.cs         # Runs KOMPANION_SOURCE and imports env vars
    ├── RepoScanner.cs          # Scans KOMPANION_REPO for .git directories
    ├── VsCodeLauncher.cs       # Launches code.exe with --extensions-dir / --user-data-dir
    └── GitService.cs           # Executes git pull / git push; captures output
```

---

## Tutorial – creating a similar app from scratch

### 1. Prerequisites

- [.NET 9 SDK](https://dotnet.microsoft.com/download) for Windows
- Git in `PATH`
- VS Code (`code.exe`) in `PATH` (optional – only needed at runtime)

### 2. Create the WPF project

```powershell
# Create a new WPF application targeting Windows
dotnet new wpf -n KompanionUI -f net9.0-windows
cd KompanionUI
```

This scaffolds `App.xaml`, `App.xaml.cs`, `MainWindow.xaml`, `MainWindow.xaml.cs`,
and a `.csproj` with `<UseWPF>true</UseWPF>`.

### 3. Enable self-contained single-file publishing

Add to the `<PropertyGroup>` in the `.csproj`:

```xml
<RuntimeIdentifier>win-x64</RuntimeIdentifier>
<SelfContained>true</SelfContained>
<PublishSingleFile>true</PublishSingleFile>
<IncludeNativeLibrariesForSelfExtract>true</IncludeNativeLibrariesForSelfExtract>
```

> **Note:** WPF does not support `<PublishTrimmed>true</PublishTrimmed>` — the SDK
> will refuse to build. Omit trimming for WPF projects.

### 4. Add the icon

Generate a multi-resolution `.ico` with pure PowerShell (no third-party tools):

```powershell
Add-Type -AssemblyName System.Drawing

function New-IconBitmap {
    param([int]$Size)
    $bmp = New-Object System.Drawing.Bitmap($Size, $Size,
              [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g   = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([System.Drawing.Color]::Transparent)

    # Filled circle
    $brush = New-Object System.Drawing.SolidBrush(
                 [System.Drawing.Color]::FromArgb(255, 0, 150, 136))
    $pad = [Math]::Max(1, [int]($Size * 0.04))
    $g.FillEllipse($brush, $pad, $pad, $Size - 2*$pad - 1, $Size - 2*$pad - 1)
    $brush.Dispose()

    # Centred letter
    $font = New-Object System.Drawing.Font("Segoe UI", [float]($Size * 0.54),
                [System.Drawing.FontStyle]::Bold,
                [System.Drawing.GraphicsUnit]::Pixel)
    $sf = New-Object System.Drawing.StringFormat
    $sf.Alignment = $sf.LineAlignment = [System.Drawing.StringAlignment]::Center
    $g.DrawString("K", $font, [System.Drawing.Brushes]::White,
                  (New-Object System.Drawing.RectangleF(0,0,$Size,$Size)), $sf)
    $font.Dispose(); $g.Dispose(); $bmp
}

function Save-Ico {
    param([System.Drawing.Bitmap[]]$Bitmaps, [string]$Path)
    $pngs = $Bitmaps | ForEach-Object {
        $m = New-Object System.IO.MemoryStream
        $_.Save($m, [System.Drawing.Imaging.ImageFormat]::Png)
        ,$m.ToArray()
    }
    $fs = [System.IO.File]::Open($Path, [System.IO.FileMode]::Create)
    $w  = New-Object System.IO.BinaryWriter($fs)
    $w.Write([uint16]0); $w.Write([uint16]1); $w.Write([uint16]$Bitmaps.Length)
    $offset = [uint32](6 + 16 * $Bitmaps.Length)
    for ($i = 0; $i -lt $Bitmaps.Length; $i++) {
        $d = $Bitmaps[$i].Width
        $w.Write([byte]$(if ($d -ge 256) {0} else {$d}))
        $w.Write([byte]$(if ($d -ge 256) {0} else {$d}))
        $w.Write([byte]0); $w.Write([byte]0)
        $w.Write([uint16]1); $w.Write([uint16]32)
        $w.Write([uint32]$pngs[$i].Length); $w.Write($offset)
        $offset += [uint32]$pngs[$i].Length
    }
    $pngs | ForEach-Object { $w.Write($_) }
    $w.Close(); $fs.Close()
}

New-Item -ItemType Directory -Force Assets | Out-Null
$bitmaps = @(48, 32, 16) | ForEach-Object { New-IconBitmap -Size $_ }
Save-Ico -Bitmaps $bitmaps -Path "Assets\icon.ico"
$bitmaps | ForEach-Object { $_.Dispose() }
```

Then reference it in the `.csproj`:

```xml
<ApplicationIcon>Assets\icon.ico</ApplicationIcon>
...
<ItemGroup>
  <Resource Include="Assets\icon.ico" />
</ItemGroup>
```

And in `MainWindow.xaml`:

```xml
<Window ... Icon="Assets/icon.ico">
```

### 5. Propagate environment variables from a startup script

A child process **cannot** modify the parent's environment. The workaround is to run the
script inside a single PowerShell `-Command` block that also prints all env vars afterwards,
then parse and apply them in the .NET process:

```csharp
string psCommand =
    $"& '{scriptPath}'; " +
    "Write-Output '---ENV---'; " +
    "Get-ChildItem Env: | ForEach-Object { " +
    "    Write-Output (\"ENV:\" + $_.Name + \"=\" + $_.Value) }";

// ... start powershell.exe -Command "<psCommand>", capture stdout ...

foreach (string line in stdout.Split('\n'))
{
    if (!line.StartsWith("ENV:")) continue;
    int sep   = line.IndexOf('=', 4);
    string key   = line.Substring(4, sep - 4);
    string value = line.Substring(sep + 1);
    Environment.SetEnvironmentVariable(key, value, EnvironmentVariableTarget.Process);
}
```

### 6. Run git operations asynchronously

To keep the UI responsive while `git pull` / `git push` runs:

```csharp
SetAllEnabled(false);
Task.Run(() => _git.Run(GitOperation.Pull, path))
    .ContinueWith(t =>
    {
        var (success, output) = t.Result;
        Dispatcher.Invoke(() =>
        {
            SetAllEnabled(true);
            if (!success) ShowError($"git pull failed:\n\n{output}");
        });
    });
```

---

## Environment variables

| Variable | Required | Purpose |
|---|---|---|
| `KOMPANION_SOURCE` | Yes | Path to a PowerShell `.ps1` script run at startup |
| `KOMPANION_REPO` | Yes | Directory scanned for Git repositories |
| `KOMPANION_LOGS` | No | Directory where `kompanion-ui.log` is written |
| `VSCODE_EXTENSIONS` | No | Passed to `code.exe --extensions-dir` |
| `VSCODE_SETTINGS` | No | Passed to `code.exe --user-data-dir` |

---

## Building

```powershell
# Debug build (requires .NET 9 runtime on the machine)
dotnet build ui\KompanionUI.csproj
```

The output goes to `ui\bin\Debug\net9.0-windows\KompanionUI.exe`.

---

## Publishing a standalone executable

```powershell
# Self-contained single .exe – no .NET runtime needed on the target machine
dotnet publish ui\KompanionUI.csproj -c Release -o ui\publish
```

The output is a single `ui\publish\KompanionUI.exe` (~128 MB, all dependencies bundled).
Copy just that file to pin it to the taskbar or add it to `PATH`.

---

## Using the application

1. Set the required environment variables (typically in your `KOMPANION_SOURCE` script or
   your shell profile).
2. Run `KompanionUI.exe`.
3. The startup script is executed and its environment is imported. The repository list
   is populated automatically.
4. Use the buttons in each row:
   - **Launch** — opens VS Code at the repository root (detached, stays open if you close
     the app).
   - **Pull** — runs `git pull`; result is shown in the status bar and logged.
   - **Push** — runs `git push`; result is shown in the status bar and logged.
5. Click **Refresh** at any time to re-scan `KOMPANION_REPO`.

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
