# Tutorial – creating a similar app from scratch

## 1. Prerequisites

- [.NET 9 SDK](https://dotnet.microsoft.com/download) for Windows
- Git in `PATH`
- VS Code (`code.exe`) in `PATH` (optional – only needed at runtime)

## 2. Create the WPF project

```powershell
# Create a new WPF application targeting Windows
dotnet new wpf -n KompanionUI -f net9.0-windows
cd KompanionUI
```

This scaffolds `App.xaml`, `App.xaml.cs`, `MainWindow.xaml`, `MainWindow.xaml.cs`,
and a `.csproj` with `<UseWPF>true</UseWPF>`.

## 3. Enable self-contained single-file publishing

Add to the `<PropertyGroup>` in the `.csproj`:

```xml
<RuntimeIdentifier>win-x64</RuntimeIdentifier>
<SelfContained>true</SelfContained>
<PublishSingleFile>true</PublishSingleFile>
<IncludeNativeLibrariesForSelfExtract>true</IncludeNativeLibrariesForSelfExtract>
```

> **Note:** WPF does not support `<PublishTrimmed>true</PublishTrimmed>` — the SDK
> will refuse to build. Omit trimming for WPF projects.

## 4. Add the icon

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

## 5. Propagate environment variables from a startup script

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

## 6. Run git operations asynchronously

To keep the UI responsive while `git pull` / `git push` runs, execute Git on a
background thread and always restore UI state in `finally`:

```csharp
SetAllEnabled(false);
try
{
    using var cts = new CancellationTokenSource();
    var (success, output) = await Task.Run(() => _git.Run(GitOperation.Pull, path, cts.Token));
    if (!success) ShowError($"git pull failed:\n\n{output}");
}
finally
{
    SetAllEnabled(true);
}
```

When a Git action is running, the UI exposes a **Cancel Git** button that calls
`CancellationTokenSource.Cancel()` and updates the status/history panel.