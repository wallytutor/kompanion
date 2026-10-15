# kompanion.ps1
# A portable setup environment for Windows without admin rights.
# Mimics a home directory by configuring paths to avoid polluting
# the host user profile.
#
# Possible future packages:
# - Racket
# - MLton
# - smlnk
# - octave
# - scilab
# - gnuplot
# - graphviz

#region: parameters
param (
    # Actions:
    [switch]$RunVsCode,
    [switch]$RebuildOnStart,

    # Build options:
    [switch]$NoPythonDeps,
    [switch]$NoJuliaDeps,

    # Execution control:
    [switch]$NoRun
)
#endregion: parameters

#region: globals
$KOMPANION_DEBUG = $true

# Track environment variable names created by Kompanion:
$GLOBAL:KOMPANION_CREATED_ENVS = New-Object System.Collections.ArrayList

# Default configuration template (used when .kompanion/kompanion.json is not present):
$DEFAULT_CONFIG = [PSCustomObject]@{
    base = [PSCustomObject]@{
        devtoys     = $false
        drawio      = $false
        ffmpeg      = $false
        imagemagick = $false
        inkscape    = $false
        jabref      = $false
        lessmsi     = $false
        logseq      = $false
        miktex      = $false
        nteract     = $false
        nvim        = $false
        pandoc      = $false
        poppler     = $false
        tabby       = $false
        zettlr      = $false
    }
    lang = [PSCustomObject]@{
        coq         = $false
        elm         = $false
        erlang      = $false
        haskell     = $false
        julia       = $false
        octave      = $false
        perl        = $false
        racket      = $false
        rlang       = $false
    }
    simu = [PSCustomObject]@{
        blender     = $false
        dwsim       = $false
        elmer       = $false
        freecad     = $false
        freefem     = $false
        gmsh        = $false
        gnuplot     = $false
        meshlab     = $false
        ollama      = $false
        opencascade = $false
        paraview    = $false
        prepomax    = $false
        radcal      = $false
        su2         = $false
        tesseract   = $false
    }
}
#endregion: globals

#region: messages
function Write-Head {
    param( [string]$Text )
    Write-Host $Text -ForegroundColor Cyan
}

function Write-Warn {
    param( [string]$Text )
    Write-Host $Text -ForegroundColor Yellow
}

function Write-Good {
    param( [string]$Text )
    Write-Host $Text -ForegroundColor Green
}

function Write-Bad {
    param( [string]$Text )
    Write-Host $Text -ForegroundColor Red
}
#endregion: messages

#region: path_and_environment
function Test-InPath {
    param (
        [string]$Directory,
        [string]$Path = $env:Path
    )

    $normalized = $Directory.TrimEnd('\')
    $filtered = ($Path -split ';' | ForEach-Object { $_.TrimEnd('\') })
    return $filtered -contains $normalized
}

function Initialize-EnsureDirectory {
    param (
        [string]$Path
    )

    if (!(Test-Path -Path $Path)) {
        New-Item -ItemType Directory -Path $Path | Out-Null
    }
}

function Initialize-AddToPath {
    param (
        [string]$Directory
    )

    if (Test-Path -Path $Directory) {
        if (!(Test-InPath $Directory)) {
            $env:Path = "$Directory;" + $env:Path
        }
    } else {
        Write-Bad "* Not prepending missing path to environment: $Directory"
    }
}

function Initialize-AddToManPath {
    param (
        [string]$Directory
    )

    # Notice that PS man is just Get-Help and this will have no effect there.
    # TODO: figure out how to get actual man working everywhere in PS.
    if (Test-Path -Path $Directory) {
        if (!(Test-InPath -Directory $Directory -Path $env:MANPATH)) {
            $env:MANPATH = "$Directory;" + $env:MANPATH
        }
    } else {
        Write-Bad "* Not prepending missing path to environment: $Directory"
    }
}

function Set-KompanionEnvVar {
    param(
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)][string]$Value
    )
    # Set the process environment variable (dynamic name)
    Set-Item -Path ("env:$Name") -Value $Value

    # Track the variable name in the global list to save it later:
    [void]$GLOBAL:KOMPANION_CREATED_ENVS.Add($Name)
}

function Save-KompanionEnvVarsToFile {
    # Create a list of custom objects with environment variables; sort by
    # value so that results will be more readable.
    $values = $GLOBAL:KOMPANION_CREATED_ENVS |
        ForEach-Object {
            [PSCustomObject]@{
                Name  = $_
                Value = (
                    Get-Item -Path ("env:$_") `
                    -ErrorAction SilentlyContinue
                ).Value
            }
        } | Sort-Object -Property Value

    # This is just for pretty output...
    $maxlen = ($values |
        ForEach-Object { $_.Name.Length } |
        Measure-Object -Maximum
    ).Maximum

    # Write variables to executable script:
    $values | ForEach-Object {
        $spaces = " " * (1 + $maxlen - $_.Name.Length)
        "`$env:$($_.Name)$spaces= '$($_.Value)'"
    } | Set-Content -Path "$env:KOMPANION_DOT\envs.ps1" -Encoding UTF8
}
#endregion: path_and_environment

#region: utilities
function Read-Json {
    param (
        [Parameter(Mandatory, Position=0)]
        [string]$Path
    )

    Get-Content -Path $Path -Raw | ConvertFrom-Json
}

$KOMPANION_ROOT = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Definition }
if (-not $KOMPANION_ROOT) { $KOMPANION_ROOT = $PWD.Path }
$KOMPANION_SETUP = Read-Json (Join-Path $KOMPANION_ROOT "kompanion.json")

function Set-LockedPkg {
    param (
        [Parameter(Mandatory, Position=0)]
        [string]$Pkg
    )
    $lockFile = "$env:KOMPANION_DOT\$Pkg.lock"
    New-Item -ItemType File -Path $lockFile -Force | Out-Null
}

function Get-IsLockedPkg {
    param (
        [Parameter(Mandatory, Position=0)]
        [string]$Pkg
    )
    $lockFile = "$env:KOMPANION_DOT\$Pkg.lock"
    return (Test-Path -Path $lockFile)
}

function Get-PackageVersion {
    <#
    .SYNOPSIS
        Returns the package version from the JSON configuration.
    .PARAMETER Name
        Name of the package to be retrieved (same case as in JSON).
    .PARAMETER Full
        Set to true to return `X.Y.Z`, otherwise `X.Y`.
    #>
    param (
        [Parameter(Mandatory, Position=0)]
        [string]$Name,
        [bool]$Full = $true
    )

    $versionEntry = $KOMPANION_SETUP.version.$Name

    if ($null -eq $versionEntry) {
        return $null
    }

    if ($versionEntry -is [string]) {
        return $versionEntry
    }

    if ($Full) {
        "{0}.{1}.{2}" -f $versionEntry
    } else {
        "{0}.{1}" -f $versionEntry
    }
}

function Get-PackageVersionedUrl {
    <#
    .SYNOPSIS
        Returns the package URL from the JSON configuration.
    .PARAMETER Name
        Name of the package to be retrieved (same case as in JSON).
    #>
    param (
        [Parameter(Mandatory, Position=0)]
        [string]$Name
    )
    $baseUrl = $KOMPANION_SETUP.url.$Name
    $version = $KOMPANION_SETUP.version.$Name

    if ([string]::IsNullOrWhiteSpace($baseUrl)) {
        throw "Base URL for package '$Name' not found in configuration."
    }

    if ($baseUrl -like "*{0}*") {
        if ($null -eq $version) {
            throw "Version for package '$Name' not found in configuration."
        }
        $baseUrl -f $version
    } else {
        $baseUrl
    }
}

function Get-TargetPath {
    param (
        [Parameter(Mandatory, Position=0)]
        [string]$Path,

        [string]$Target = $null
    )
    # If a target is specified, that means we know that the zip will
    # extract a folder, not a bunch of files. This is to avoid nesting
    # of multiple folders when the zip already contains one.
    if ([string]::IsNullOrWhiteSpace($Target)) {
        $Path
    } else {
        Join-Path -Path $Path -ChildPath $Target
    }
}

function Invoke-CapturedCommand {
    param (
        [Parameter(Mandatory, Position=0)]
        [string]$FilePath,

        [Parameter(Mandatory, Position=1)]
        [string[]]$ArgumentList
    )

    $logOut = "$env:KOMPANION_LOGS\temp-log.out"
    $logErr = "$env:KOMPANION_LOGS\temp-log.err"

    $proc = Start-Process -FilePath $FilePath -ArgumentList $ArgumentList `
        -RedirectStandardOutput $logOut `
        -RedirectStandardError  $logErr `
        -NoNewWindow -Wait -PassThru

    if (Test-Path $logOut) {
        Get-Content $logOut | Add-Content "$env:KOMPANION_LOGS\kompanion.log"
        Remove-Item $logOut -ErrorAction SilentlyContinue
    }

    if (Test-Path $logErr) {
        Get-Content $logErr | Add-Content "$env:KOMPANION_LOGS\kompanion.err"
        Remove-Item $logErr -ErrorAction SilentlyContinue
    }

    return $proc.ExitCode
}

function Invoke-DownloadCurl {
    param (
        [Parameter(Mandatory, Position=0)]
        [string]$URL,

        [Parameter(Mandatory, Position=1)]
        [string]$Output,

        [switch]$Insecure
    )
    $success = $false
    $opts = @("--ssl-no-revoke", $URL, "--output", $Output)
    if ($Insecure) { $opts += "--insecure" }

    $curlPath = if (Test-Path "$env:CURL_HOME\bin\curl.exe") {
        "$env:CURL_HOME\bin\curl.exe"
    } else {
        "curl.exe"
    }

    try {
        $code = Invoke-CapturedCommand $curlPath $opts
        $success = ($code -eq 0)
        if (-not $success) { throw "Curl got exit code $code" }
    } catch {
        Write-Bad "Failed to download $URL as $Output ($_)"
    }

    return $success
}

function Invoke-DownloadIfNeeded {
    param (
        [Parameter(Mandatory, Position=0)]
        [string]$URL,

        [Parameter(Mandatory, Position=1)]
        [string]$Output
    )

    if (Test-Path -Path $Output) {
        return $true
    }

    Write-Host "Downloading $URL as $Output"

    $success = $false

    # Start-BitsTransfer
    if (-not $success) {
        try {
            Start-BitsTransfer -Source $URL -Destination $Output -ErrorAction Stop
            $success = $true
        } catch {
            Write-Bad "Failed to download $URL as $Output (Start-BitsTransfer)"
            $success = $false
        }
    }

    # curl.exe
    if (-not $success) {
        $success = Invoke-DownloadCurl $URL $Output
    }

    # curl.exe -insecure
    if (-not $success) {
        $success = Invoke-DownloadCurl $URL $Output -Insecure
    }

    # Invoke-WebRequest
    if (-not $success) {
        try {
            Invoke-WebRequest -Uri $URL -OutFile $Output -ErrorAction Stop
            $success = $true
        } catch {
            Write-Bad "Failed to download $URL as $Output (Invoke-WebRequest)"
            $success = $false
        }
    }

    return $success
}

function Invoke-UncompressZipIfNeeded {
    param (
        [Parameter(Mandatory, Position=0)]
        [string]$Source,

        [Parameter(Mandatory, Position=1)]
        [string]$Destination,

        [string]$Target = $null
    )

    $FinalPath = Get-TargetPath $Destination -Target $Target

    if (!(Test-Path -Path $FinalPath)) {
        Write-Host "Expanding $Source into $Destination"

        try {
            Expand-Archive -Path $Source -DestinationPath $Destination
        } catch {
            Write-Bad "Failed to expand $Source into $Destination : $_"
            return $false
        }

        return (Test-Path -Path $FinalPath)
    }

    return $true
}

function Invoke-Uncompress7zIfNeeded {
    param (
        [Parameter(Mandatory, Position=0)]
        [string]$Source,

        [Parameter(Mandatory, Position=1)]
        [string]$Destination,

        [string]$Target = $null
    )

    $FinalPath = Get-TargetPath $Destination -Target $Target

    $SevenZipPath = if (Test-Path "$env:SEVENZIP_HOME\7z.exe") {
        "$env:SEVENZIP_HOME\7z.exe"
    } else {
        "7zr.exe"
    }

    if (!(Test-Path -Path $FinalPath)) {
        Write-Host "Expanding $Source into $Destination"

        try {
            Invoke-CapturedCommand $SevenZipPath @("x", $Source, "-o$Destination")
        } catch {
            Write-Bad "Failed to expand $Source into $Destination : $_"
            return $false
        }

        return (Test-Path -Path $FinalPath)
    }

    return $true
}

function Invoke-UncompressGzipIfNeeded {
    param(
        [Parameter(Mandatory, Position=0)]
        [string]$Source,

        [Parameter(Mandatory, Position=1)]
        [string]$Destination
    )

    $inputf = [IO.File]::OpenRead($Source)
    $output = [IO.File]::Create($Destination)

    $what = [IO.Compression.CompressionMode]::Decompress
    $gzip = New-Object IO.Compression.GzipStream($inputf, $what)

    $buffer = New-Object byte[] 4096
    while (($read = $gzip.Read($buffer, 0, $buffer.Length)) -gt 0) {
        $output.Write($buffer, 0, $read)
    }

    $gzip.Dispose()
    $output.Dispose()
    $inputf.Dispose()
}

function Invoke-UncompressMsiIfNeeded {
    param (
        [Parameter(Mandatory, Position=0)]
        [string]$Source,

        [Parameter(Mandatory, Position=1)]
        [string]$Destination
    )

    if (!(Test-Path -Path $Destination)) {
        $lessMsiPath = if (Test-Path "$env:LESSMSI_HOME\lessmsi.exe") {
            "$env:LESSMSI_HOME\lessmsi.exe"
        } else {
            "lessmsi.exe"
        }

        Invoke-CapturedCommand $lessMsiPath @("x", $Source, "$Destination\")
    }
}

function Invoke-UncompressIfNeeded {
    param (
        [Parameter(Mandatory, Position=0)]
        [string]$Source,

        [Parameter(Mandatory, Position=1)]
        [string]$Destination,

        [string]$Target = $null
    )

    $extension = [System.IO.Path]::GetExtension($Source).ToLower()

    try {
        switch ($extension) {
            ".zip" { Invoke-UncompressZipIfNeeded $Source $Destination -Target $Target }
            ".7z"  { Invoke-Uncompress7zIfNeeded  $Source $Destination -Target $Target }
            default {
                Write-Bad "Unsupported archive format: $extension"
                return $false
            }
        }
    } catch {
        Write-Bad "Unable to uncompress $Source into $Destination."
        return $false
    }
}

function Invoke-HandledInstall {
    param (
        [Parameter(Mandatory, Position=0)]
        [string]$Path,

        [Parameter(Mandatory, Position=1)]
        [string]$Output,

        [Parameter(Mandatory, Position=2)]
        [scriptblock]$InstallScript,

        [string]$Target = $null
    )

    $FinalPath = Get-TargetPath $Path -Target $Target

    if (Test-Path -Path $FinalPath) {
        if ($KOMPANION_DEBUG) {
            Write-Warn "* Installation target $FinalPath already exists..."
        }
        return $true
    }

    try {
        & $InstallScript

        Write-Good "Successfully installed $FinalPath."
    } catch {
        if ($KOMPANION_DEBUG) {
            Write-Bad "DEBUG: Failed to install $FinalPath : $_"
        } else {
            Write-Bad "Failed to install $FinalPath"
            Remove-Item -Path $Output    -ErrorAction SilentlyContinue
            Remove-Item -Path $FinalPath -ErrorAction SilentlyContinue -Recurse
        }

        return $false
    }

    return $true
}

function Invoke-DlUnzipInstall {
    param (
        [Parameter(Mandatory, Position=0)]
        [string]$Path,

        [Parameter(Mandatory, Position=1)]
        [string]$URL,

        [Parameter(Mandatory, Position=2)]
        [string]$Output,

        [string]$Target = $null
    )
    Invoke-HandledInstall $Path $Output -InstallScript {
        if (!(Invoke-DownloadIfNeeded -URL $URL -Output $Output)) {
            throw "Failed to download $URL as $Output"
        }

        if (!(Invoke-UncompressIfNeeded $Output $Path -Target $Target)) {
            throw "Failed to expand $Output into $Path with target $Target"
        }
    } -Target $Target
}
#endregion: utilities

#region: python_helpers
function Check-HasPython {
    try {
        python --version | Out-Null
        return $true
    } catch {
        return $false
    }
}

function Get-PythonMajorVersion {
    return python -c "import sys; print(sys.version_info.major)"
}

function Get-PythonMinorVersion {
    return python -c "import sys; print(sys.version_info.minor)"
}

function Check-HasValidPython {
    param (
        [int]$RequiredMinor = 12
    )
    if (-not (Check-HasPython)) {
        return $false
    }

    $major = Get-PythonMajorVersion
    $minor = Get-PythonMinorVersion

    if ($major -lt 3) {
        return $false
    }

    if ($major -eq 3 -and $minor -lt $RequiredMinor) {
        return $false
    }

    return $true
}

function Piperish {
    $PythonPath = $null
    $pipArgs = @()

    for ($i = 0; $i -lt $args.Count; $i++) {
        if ($args[$i] -eq "-PythonPath" -and ($i + 1) -lt $args.Count) {
            $PythonPath = $args[$i + 1]
            $i++
        } else {
            $pipArgs += $args[$i]
        }
    }

    if (-not $PythonPath) {
        $PythonPath = "$env:PYTHON_HOME\python.exe"
    }

    if (-not (Test-Path $PythonPath)) {
        Write-Bad "Required Python not found: $PythonPath..."
        exit 1
    }

    $argList = @("-m", "pip", "--trusted-host", "pypi.org",
                 "--trusted-host", "files.pythonhosted.org")
    $argList += $pipArgs

    Invoke-CapturedCommand $PythonPath $argList
}

function Initialize-VirtualEnvironment {
    param (
        [string]$VenvRoot = ".",
        [string]$VenvName = ".venv",
        [int]$RequiredMinor = 12
    )

    if (-not (Check-HasValidPython -RequiredMinor $RequiredMinor)) {
        Write-Bad "Python 3.$RequiredMinor or higher is required."
        return $false
    }

    Write-Head "Working from a virtual environment..."

    $VenvPath = Join-Path $VenvRoot $VenvName
    $VenvActivate = Join-Path $VenvPath "Scripts\Activate.ps1"
    Write-Head "Virtual environment path: $VenvPath"

    if (-not (Test-Path $VenvPath)) {
        Write-Warn "Virtual environment not found, creating one..."
        python -m venv $VenvPath

        if ($LASTEXITCODE -ne 0) {
            Write-Bad "Failed to create virtual environment!"
            return $false
        }
    }

    Write-Good "Activating virtual environment..."
    & $VenvActivate

    Write-Good "Ensuring the latest pip is installed..."
    & python -m pip install --upgrade pip 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Bad "Failed to upgrade pip!"
        return $false
    }

    $requirements = Join-Path $VenvRoot "requirements.txt"

    if (Test-Path $requirements) {
        Write-Good "Installing required packages from $requirements ..."
        & python -m pip install -r $requirements > log.pipInstall 2>&1

        if ($LASTEXITCODE -ne 0) {
            Write-Bad "Failed to install required packages!"
            return $false
        }
    } else {
        Write-Warn "No requirements.txt found at $requirements"
    }

    return $true
}
#endregion: python_helpers

#region: system_helpers
function Invoke-DirectoryBackupNoAdmin {
    param (
        [string]$Source,
        [string]$Destination,
        [switch]$TestOnly
    )

    $LogFile = "$Destination.log"

    $RoboArgs = @(
        $Source
        $Destination
        "/MIR"          # Mirror (copy + delete)
        "/R:3"          # Retry 3 times
        "/W:5"          # Wait 5 seconds between retries
        "/COPY:DAT"     # Copy file info (data, attributes, timestamps)
        "/DCOPY:DAT"    # Copy directory data, attributes, timestamps
        "/MT:16"        # Multi-threaded copy (16 threads)
        "/LOG:$LogFile" # Log output
    )

    if ($TestOnly) { $RoboArgs += @("/L") }

    robocopy @RoboArgs
}

function Rename-FilesToStandard {
    <#
    .SYNOPSIS
        Renames files to use lowercase and ASCII-safe characters.
    .DESCRIPTION
        Recursively renames files in the specified path by:
        - Normalizing accented characters to their ASCII equivalents (e.g., é → e, ñ → n)
        - Converting filenames to lowercase
        - Replacing all non-alphanumeric characters (except underscores) with underscores
        - Preserving file extensions
        This ensures filenames are ASCII-safe and follow a consistent naming convention.
    .PARAMETER Path
        The directory path to search for files. Defaults to the current directory.
    .PARAMETER Filter
        File extension filter(s) to limit which files are renamed.
    .PARAMETER DryRun
        When specified, shows what files would be renamed without actually renaming them.
    #>
    param(
        [string]$Path = ".",
        [string[]]$Filter,
        [switch]$DryRun
    )

    $files = if ($Filter) {
        Get-ChildItem -Path $Path -Recurse -File -Include $Filter
    } else {
        Get-ChildItem -Path $Path -Recurse -File
    }

    $files | ForEach-Object {
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
        $extension = $_.Extension

        $normalizedBaseName = $baseName.Normalize([Text.NormalizationForm]::FormD)
        $asciiBaseName = $normalizedBaseName -replace '\p{M}', ''

        $newBaseName = ($asciiBaseName -replace '[^a-zA-Z0-9_]', '_').ToLower()
        $newName = $newBaseName + $extension.ToLower()

        if ($_.Name -ne $newName) {
            $newPath = Join-Path -Path $_.DirectoryName -ChildPath $newName
            Write-Host "Renaming '$($_.FullName)' to '$newPath'"

            if (-not $DryRun) {
                Rename-Item -Path $_.FullName -NewName $newPath
            }
        }
    }
}
#endregion: system_helpers

#region: software_configurations
function Invoke-ConfigureBlender {
    Write-Head "* Configuring Blender..."

    $target = "blender-4.5.4-windows-x64"
    $url    = $KOMPANION_SETUP.url.blender
    $output = "$env:KOMPANION_TEMP\blender.zip"
    $path   = "$env:KOMPANION_BIN"

    $success = Invoke-DlUnzipInstall $path $url $output -Target $target

    if ($success) {
        Set-KompanionEnvVar -Name "BLENDER_HOME" `
            -Value "$env:KOMPANION_BIN\$target"
        # XXX do not add to PATH, use as GUI
    } else {
        Write-Warn "Failed to install Blender, skipping configuration..."
    }
}

function Invoke-ConfigureCoq {
    Write-Head "* Configuring Coq..."

    $path   = "$env:KOMPANION_BIN\coq"
    $url    = $KOMPANION_SETUP.url.coq
    $output = "$env:KOMPANION_TEMP\coq.exe"

    $success = Invoke-HandledInstall $path $output -InstallScript {
        if (!(Invoke-DownloadIfNeeded -URL $url -Output $output)) {
            throw "Failed to download $url as $output"
        }
        if (!(Invoke-Uncompress7zIfNeeded -Source $output -Destination $path)) {
            throw "Failed to expand $output into $path"
        }
        $pluginsDir = Join-Path $path '$PLUGINSDIR'
        if (Test-Path $pluginsDir) { Remove-Item $pluginsDir -Recurse -Force }
        $uninstallExe = Join-Path $path 'Uninstall.exe.nsis'
        if (Test-Path $uninstallExe) { Remove-Item $uninstallExe -Force }
    }

    if ($success) {
        Set-KompanionEnvVar -Name "COQ_HOME" -Value $path
        Initialize-AddToPath -Directory "$env:COQ_HOME\bin"
    } else {
        Write-Warn "Failed to install Coq, skipping configuration..."
    }
}

function Invoke-ConfigureCurl {
    Write-Head "* Configuring Curl..."

    $target = "curl-8.16.0_13-win64-mingw"
    $url    = $KOMPANION_SETUP.url.curl
    $output = "$env:KOMPANION_TEMP\curl.zip"
    $path   = "$env:KOMPANION_BIN"

    $success = Invoke-DlUnzipInstall $path $url $output -Target $target

    if ($success) {
        Set-KompanionEnvVar -Name "CURL_HOME" `
            -Value "$env:KOMPANION_BIN\$target"

        Initialize-AddToPath -Directory "$env:CURL_HOME\bin"
    } else {
        Write-Warn "Failed to install Curl, skipping configuration..."
    }
}

function Invoke-ConfigureDevToys {
    Write-Head "* Configuring DevToys..."

    $target  = $null
    $version = $KOMPANION_SETUP.version.devtoys
    $url     = Get-PackageVersionedUrl "devtoys"
    $output  = "$env:KOMPANION_TEMP\devtoys.zip"
    $path    = "$env:KOMPANION_BIN\devtoys-$version"

    $success = Invoke-DlUnzipInstall $path $url $output -Target $target

    if ($success) {
        Set-KompanionEnvVar -Name "DEVTOYS_HOME" -Value "$path"
        Initialize-AddToPath -Directory "$env:DEVTOYS_HOME"
    } else {
        Write-Warn "Failed to install DevToys, skipping configuration..."
    }
}

function Invoke-ConfigureDotNET {
    Write-Head "* Configuring .NET..."

    $target  = $null
    $version = $KOMPANION_SETUP.version.dotnet
    $url     = Get-PackageVersionedUrl "dotnet"
    $output  = "$env:KOMPANION_TEMP\dotnet.zip"
    $path    = "$env:KOMPANION_BIN\dotnet-sdk-$version-win-x64"

    $success = Invoke-DlUnzipInstall $path $url $output -Target $target

    if ($success) {
        Set-KompanionEnvVar -Name "DOTNET_ROOT" `
            -Value "$env:KOMPANION_BIN\dotnet-sdk-$version-win-x64"
        # Points to the root of the user profile:
        Set-KompanionEnvVar -Name "DOTNET_CLI_HOME" `
            -Value "$env:KOMPANION_DIR"
        Set-KompanionEnvVar -Name "DOTNET_TOOLS_PATH" `
            -Value "$env:KOMPANION_DIR\.dotnet\tools"

        Set-KompanionEnvVar -Name "DOTNET_INTERACTIVE_CLI_TELEMETRY_OPTOUT" `
            -Value "1"
        Set-KompanionEnvVar -Name "DOTNET_CLI_TELEMETRY_OPTOUT" `
            -Value "1"

        Set-KompanionEnvVar -Name "NUGET_PACKAGES" `
            -Value "$env:KOMPANION_DIR\.nuget\packages"
        Set-KompanionEnvVar -Name "NUGET_HTTP_CACHE_PATH" `
            -Value "$env:KOMPANION_DIR\.nuget\http-cache"
        Set-KompanionEnvVar -Name "NUGET_SCRATCH" `
            -Value "$env:KOMPANION_DIR\.nuget\scratch"

        Initialize-AddToPath -Directory "$env:DOTNET_ROOT"
        Initialize-AddToPath -Directory "$env:DOTNET_TOOLS_PATH"
    } else {
        Write-Warn "Failed to install .NET, skipping configuration..."
    }
}

function Invoke-ConfigureDrawio {
    Write-Head "* Configuring Draw.io..."

    $target = $null
    $url    = $KOMPANION_SETUP.url.drawio
    $output = "$env:KOMPANION_TEMP\drawio.zip"
    $path   = "$env:KOMPANION_BIN\drawio"

    $success = Invoke-DlUnzipInstall $path $url $output -Target $target

    if ($success) {
        Set-KompanionEnvVar -Name "DRAWIO_HOME" `
            -Value "$env:KOMPANION_BIN\drawio"

        Initialize-AddToPath -Directory "$env:DRAWIO_HOME"
    } else {
        Write-Warn "Failed to install Draw.io, skipping configuration..."
    }
}

function Invoke-ConfigureDwsim {
    Write-Head "* Configuring DWSIM..."

    $target = $null
    $url    = $KOMPANION_SETUP.url.dwsim
    $output = "$env:KOMPANION_TEMP\dwsim.7z"
    $path   = "$env:KOMPANION_BIN\dwsim"

    $success = Invoke-DlUnzipInstall $path $url $output -Target $target

    if ($success) {
        Set-KompanionEnvVar -Name "DWSIM_HOME" -Value $path
        Initialize-AddToPath -Directory "$env:DWSIM_HOME"
    } else {
        Write-Warn "Failed to install DWSIM, skipping configuration..."
    }
}

function Invoke-ConfigureElm {
    Write-Head "* Configuring Elm..."

    $path   = "$env:KOMPANION_BIN\elm.exe"
    $url    = $KOMPANION_SETUP.url.elm
    $output = "$env:KOMPANION_TEMP\elm.gz"

    $success = Invoke-HandledInstall $path $output -InstallScript {
        if (!(Invoke-DownloadIfNeeded -URL $url -Output $output)) {
            throw "Failed to download $url as $output"
        }
        Invoke-UncompressGzipIfNeeded -Source $output -Destination $path
    }

    if ($success) {
        Initialize-AddToPath -Directory "$env:KOMPANION_BIN"
    } else {
        Write-Warn "Failed to install Elm, skipping configuration..."
    }
}

function Invoke-ConfigureElmer {
    Write-Head "* Configuring Elmer..."

    $target = "ElmerFEM-gui-mpi-Windows-AMD64"
    $url    = $KOMPANION_SETUP.url.elmer
    $output = "$env:KOMPANION_TEMP\elmer.zip"
    $path   = "$env:KOMPANION_BIN"

    $success = Invoke-DlUnzipInstall $path $url $output -Target $target

    if ($success) {
        Set-KompanionEnvVar -Name "ELMER_HOME" `
            -Value "$env:KOMPANION_BIN\$target"

        Set-KompanionEnvVar -Name "ELMER_GUI_HOME" `
            -Value "$env:ELMER_HOME\share\ElmerGUI"

        Initialize-AddToPath -Directory "$env:ELMER_HOME\lib"
        Initialize-AddToPath -Directory "$env:ELMER_HOME\bin"
    } else {
        Write-Warn "Failed to install Elmer, skipping configuration..."
    }
}

function Invoke-ConfigureErlang {
    Write-Head "* Configuring Erlang..."

    $target  = $null
    $version = $KOMPANION_SETUP.version.erlang
    $url     = Get-PackageVersionedUrl "erlang"
    $output  = "$env:KOMPANION_TEMP\erlang.zip"
    $path    = "$env:KOMPANION_BIN\erlang-$version"

    $success = Invoke-DlUnzipInstall $path $url $output -Target $target

    if ($success) {
        Set-KompanionEnvVar -Name "ERLANG_HOME" -Value "$path"
        Initialize-AddToPath -Directory "$env:ERLANG_HOME\bin"
    } else {
        Write-Warn "Failed to install Erlang, skipping configuration..."
    }
}

function Invoke-ConfigureFfmpeg {
    Write-Head "* Configuring ffmpeg..."

    $path   = "$env:KOMPANION_BIN\ffmpeg"
    $temp   = "$env:KOMPANION_TEMP\ffmpeg"
    $output = "$env:KOMPANION_TEMP\ffmpeg.7z"
    $url    = $KOMPANION_SETUP.url.ffmpeg

    $success = Invoke-HandledInstall $path $output -InstallScript {
        if (!(Invoke-DownloadIfNeeded -URL $url -Output $output)) {
            throw "Failed to download $url as $output"
        }
        if (!(Invoke-Uncompress7zIfNeeded -Source $output -Destination $temp)) {
            throw "Failed to expand $output into $temp"
        }
        $extracted = Get-Item -Path (Join-Path $temp "ffmpeg-*") | Select-Object -First 1
        Move-Item -Path $extracted.FullName -Destination $path
        Remove-Item -Path $temp -Recurse -Force
    }

    if ($success) {
        Set-KompanionEnvVar -Name "FFMPEG_HOME" -Value $path
        Initialize-AddToPath -Directory "$env:FFMPEG_HOME\bin"
    } else {
        Write-Warn "Failed to install ffmpeg, skipping configuration..."
    }
}

function Invoke-ConfigureFreeCAD {
    Write-Head "* Configuring FreeCAD..."

    $target = "FreeCAD_1.0.2-conda-Windows-x86_64-py311"
    $url    = $KOMPANION_SETUP.url.freecad
    $output = "$env:KOMPANION_TEMP\freecad.7z"
    $path   = "$env:KOMPANION_BIN"

    $success = Invoke-DlUnzipInstall $path $url $output -Target $target

    if ($success) {
        Set-KompanionEnvVar -Name "FREECAD_HOME" `
            -Value "$env:KOMPANION_BIN\$target"

        # XXX do not add to PATH, use as GUI
    } else {
        Write-Warn "Failed to install FreeCAD, skipping configuration..."
    }
}

function Invoke-ConfigureFreeFem {
    Write-Head "* Configuring FreeFem..."

    $path   = "$env:KOMPANION_BIN\freefem"
    $url    = $KOMPANION_SETUP.url.freefem
    $output = "$env:KOMPANION_TEMP\freefem.exe"

    $success = Invoke-HandledInstall $path $output -InstallScript {
        if (!(Invoke-DownloadIfNeeded -URL $url -Output $output)) {
            throw "Failed to download $url as $output"
        }
        if (!(Invoke-Uncompress7zIfNeeded -Source $output -Destination $path)) {
            throw "Failed to expand $output into $path"
        }
    }

    if ($success) {
        Set-KompanionEnvVar -Name "FREEFEM_HOME" -Value $path
        Initialize-AddToPath -Directory "$env:FREEFEM_HOME"
    } else {
        Write-Warn "Failed to install FreeFem, skipping configuration..."
    }
}

function Invoke-ConfigureGit {
    Write-Head "* Configuring Git..."

    $target = $null
    $url    = $KOMPANION_SETUP.url.git
    $output = "$env:KOMPANION_TEMP\git.zip"
    $path   = "$env:KOMPANION_BIN\git"

    $success = Invoke-DlUnzipInstall $path $url $output -Target $target

    if ($success) {
        Set-KompanionEnvVar -Name "GIT_HOME" `
            -Value "$env:KOMPANION_BIN\git"

        Initialize-AddToPath -Directory "$env:GIT_HOME\cmd"
    } else {
        Write-Warn "Failed to install Git, skipping configuration..."
    }
}

function Invoke-ConfigureGithubCLI {
    Write-Head "* Configuring GitHub CLI..."

    $target  = $null
    $version = $KOMPANION_SETUP.version.gh
    $url     = Get-PackageVersionedUrl "gh"
    $output  = "$env:KOMPANION_TEMP\gh.zip"
    $path    = "$env:KOMPANION_BIN\gh_${version}_windows_amd64"

    $success = Invoke-DlUnzipInstall $path $url $output -Target $target

    if ($success) {
        Set-KompanionEnvVar -Name "GH_HOME" -Value "$path"
        Initialize-AddToPath -Directory "$env:GH_HOME\bin"
    } else {
        Write-Warn "Failed to install GitHub CLI, skipping configuration..."
    }
}

function Invoke-ConfigureGmsh {
    Write-Head "* Configuring Gmsh..."

    $target = "gmsh-4.14.1-Windows64-sdk"
    $url    = $KOMPANION_SETUP.url.gmsh
    $output = "$env:KOMPANION_TEMP\gmsh.zip"
    $path   = "$env:KOMPANION_BIN"

    $success = Invoke-DlUnzipInstall $path $url $output -Target $target

    if ($success) {
        Set-KompanionEnvVar -Name "GMSH_HOME" `
            -Value "$env:KOMPANION_BIN\$target"

        Initialize-AddToPath -Directory "$env:GMSH_HOME\lib"
        Initialize-AddToPath -Directory "$env:GMSH_HOME\bin"
        # TODO add to PYTHONPATH;JULIA_LOAD_PATH
    } else {
        Write-Warn "Failed to install Gmsh, skipping configuration..."
    }
}

function Invoke-ConfigureGnuplot {
    Write-Head "* Configuring Gnuplot..."

    $target = "gnuplot"
    $url    = $KOMPANION_SETUP.url.gnuplot
    $output = "$env:KOMPANION_TEMP\gnuplot.7z"
    $path   = "$env:KOMPANION_BIN"

    $success = Invoke-DlUnzipInstall $path $url $output -Target $target

    if ($success) {
        Set-KompanionEnvVar -Name "GNUPLOT_HOME" `
            -Value "$env:KOMPANION_BIN\$target"

        Initialize-AddToPath -Directory "$env:GNUPLOT_HOME\bin"
    } else {
        Write-Warn "Failed to install Gnuplot, skipping configuration..."
    }
}

function Invoke-ConfigureHaskell {
    Write-Head "* Configuring Haskell..."

    $target = $null
    $url    = $KOMPANION_SETUP.url.stack
    $output = "$env:KOMPANION_TEMP\stack.zip"
    $path   = "$env:KOMPANION_BIN\stack"

    $success = Invoke-DlUnzipInstall $path $url $output -Target $target

    if ($success) {
        Set-KompanionEnvVar -Name "STACK_HOME" -Value $path
        Set-KompanionEnvVar -Name "STACK_ROOT" -Value "$env:KOMPANION_DIR\.stack"
        Initialize-AddToPath -Directory "$env:STACK_HOME"

        if (-not (Get-IsLockedPkg "haskell")) {
            $stackExe = "$env:STACK_HOME\stack.exe"
            Invoke-CapturedCommand $stackExe @("setup")

            $stackConfigPath = "$env:KOMPANION_DOT\stack-config.yaml"
            if (Test-Path $stackConfigPath) {
                $content = Get-Content -Raw -Path $stackConfigPath
                $content = $content -replace '__STACK_ROOT__', $env:STACK_ROOT
                Set-Content -Path "$env:STACK_ROOT\config.yaml" -Value $content
            }

            Set-LockedPkg "haskell"
        }
    } else {
        Write-Warn "Failed to install Haskell, skipping configuration..."
    }
}

function Invoke-ConfigureImageMagick {
    Write-Head "* Configuring ImageMagick..."

    $target = $null
    $url    = $KOMPANION_SETUP.url.imagemagick
    $output = "$env:KOMPANION_TEMP\imagemagick.7z"
    $path   = "$env:KOMPANION_BIN\imagemagick"

    $success = Invoke-DlUnzipInstall $path $url $output -Target $target

    if ($success) {
        Set-KompanionEnvVar -Name "IMAGEMAGICK_HOME" -Value $path
        Initialize-AddToPath -Directory "$env:IMAGEMAGICK_HOME"
    } else {
        Write-Warn "Failed to install ImageMagick, skipping configuration..."
    }
}

function Invoke-ConfigureInkscape {
    Write-Head "* Configuring Inkscape..."

    $target = "inkscape"
    $url    = $KOMPANION_SETUP.url.inkscape
    $output = "$env:KOMPANION_TEMP\inkscape.7z"
    $path   = "$env:KOMPANION_BIN\inkscape"

    $success = Invoke-DlUnzipInstall $path $url $output -Target $target

    if ($success) {
        Set-KompanionEnvVar -Name "INKSCAPE_HOME" -Value "$env:KOMPANION_BIN\inkscape\inkscape"
        # Initialize-AddToPath -Directory "$env:INKSCAPE_HOME\bin"
    } else {
        Write-Warn "Failed to install Inkscape, skipping configuration..."
    }
}

function Invoke-ConfigureJabRef {
    Write-Head "* Configuring JabRef..."

    $target = "JabRef"
    $url    = $KOMPANION_SETUP.url.jabref
    $output = "$env:KOMPANION_TEMP\jabref.zip"
    $path   = "$env:KOMPANION_BIN"

    $success = Invoke-DlUnzipInstall $path $url $output -Target $target

    if ($success) {
        Set-KompanionEnvVar -Name "JABREF_HOME" `
            -Value "$env:KOMPANION_BIN\$target"

        Initialize-AddToPath -Directory "$env:JABREF_HOME"
    } else {
        Write-Warn "Failed to install JabRef, skipping configuration..."
    }
}

function Invoke-ConfigureJulia {
    Write-Head "* Configuring Julia..."

    $version = Get-PackageVersion "julia"
    $target  = "julia-$version"
    $url     = Get-PackageVersionedUrl "julia"
    $output  = "$env:KOMPANION_TEMP\julia.zip"
    $path    = "$env:KOMPANION_BIN"

    $success = Invoke-DlUnzipInstall $path $url $output -Target $target

    if ($success) {
        Set-KompanionEnvVar -Name "JULIA_HOME" `
            -Value "$env:KOMPANION_BIN\$target"

        Initialize-AddToPath -Directory "$env:JULIA_HOME\bin"

        Set-KompanionEnvVar -Name "JULIA_DEPOT_PATH" `
            -Value "$env:KOMPANION_DIR\.julia"

        Set-KompanionEnvVar -Name "JULIA_CONDAPKG_ENV" `
            -Value "$env:KOMPANION_DIR\.CondaPkg"

        Set-KompanionEnvVar -Name "AUCHIMISTE_PATH" `
            -Value "$env:KOMPANION_DIR\src\auchimiste"

        if ($NoJuliaDeps) { Set-LockedPkg "julia" }

        if (-not (Get-IsLockedPkg "julia")) {
            Invoke-CapturedCommand "$env:JULIA_HOME\bin\julia.exe" @("-e", "exit()")
            Set-LockedPkg "julia"
        }
    } else {
        Write-Warn "Failed to install Julia, skipping configuration..."
    }
}

function Invoke-ConfigureLessMsi {
    Write-Head "* Configuring lessmsi..."

    $target = $null
    $url    = $KOMPANION_SETUP.url.lessmsi
    $output = "$env:KOMPANION_TEMP\lessmsi.zip"
    $path   = "$env:KOMPANION_BIN\lessmsi"

    $success = Invoke-DlUnzipInstall $path $url $output -Target $target

    if ($success) {
        Set-KompanionEnvVar -Name "LESSMSI_HOME" -Value $path
        Initialize-AddToPath -Directory "$env:LESSMSI_HOME"
    } else {
        Write-Warn "Failed to install lessmsi, skipping configuration..."
    }
}

function Invoke-ConfigureLiteXL {
    Write-Head "* Configuring LiteXL..."

    $target = "lite-xl"
    $url    = $KOMPANION_SETUP.url.litexl
    $output = "$env:KOMPANION_TEMP\litexl.zip"
    $path   = "$env:KOMPANION_BIN"

    $success = Invoke-DlUnzipInstall $path $url $output -Target $target

    if ($success) {
        Set-KompanionEnvVar -Name "LITEXL_HOME" `
            -Value "$env:KOMPANION_BIN\$target"

        if (-not (Get-IsLockedPkg "lpm")) {
            $lpmTemp = "$env:KOMPANION_TEMP\lpm.exe"
            Invoke-DownloadIfNeeded -URL $KOMPANION_SETUP.url.lpm -Output $lpmTemp

            & $lpmTemp install plugin_manager --assume-yes
            Remove-Item $lpmTemp -ErrorAction SilentlyContinue

            Set-LockedPkg "lpm"
        }

        Initialize-AddToPath -Directory "$env:LITEXL_HOME"
    } else {
        Write-Warn "Failed to install LiteXL, skipping configuration..."
    }
}

function Invoke-ConfigureLogseq {
    Write-Head "* Configuring Logseq..."

    $target  = $null
    $version = $KOMPANION_SETUP.version.logseq
    $url     = Get-PackageVersionedUrl "logseq"
    $output  = "$env:KOMPANION_TEMP\logseq.zip"
    $path    = "$env:KOMPANION_BIN\Logseq-win-x64-$version"

    $success = Invoke-DlUnzipInstall $path $url $output -Target $target

    if ($success) {
        Set-KompanionEnvVar -Name "LOGSEQ_HOME" -Value "$path"
        Initialize-AddToPath -Directory "$env:LOGSEQ_HOME"
    } else {
        Write-Warn "Failed to install Logseq, skipping configuration..."
    }
}

function Invoke-ConfigureMeshLab {
    Write-Head "* Configuring MeshLab..."

    $target  = $null
    $version = $KOMPANION_SETUP.version.meshlab
    $url     = Get-PackageVersionedUrl "meshlab"
    $output  = "$env:KOMPANION_TEMP\meshlab.zip"
    $path    = "$env:KOMPANION_BIN\MeshLab$version-windows_x86_64"

    $success = Invoke-DlUnzipInstall $path $url $output -Target $target

    if ($success) {
        Set-KompanionEnvVar -Name "MESHLAB_HOME" -Value "$path"
        Initialize-AddToPath -Directory "$env:MESHLAB_HOME"
    } else {
        Write-Warn "Failed to install MeshLab, skipping configuration..."
    }
}

function Invoke-ConfigureMikTex {
    Write-Head "* Configuring MikTex..."

    $output   = "$env:KOMPANION_TEMP\miktexsetup.zip"
    $setupDir = "$env:KOMPANION_BIN\miktexsetup"
    $url      = $KOMPANION_SETUP.url.miktex
    $miktex   = "$env:KOMPANION_BIN\miktex"

    $success = Invoke-HandledInstall $miktex $output -InstallScript {
        if (!(Invoke-DownloadIfNeeded -URL $url -Output $output)) {
            throw "Failed to download $url as $output"
        }
        if (!(Invoke-UncompressZipIfNeeded -Source $output -Destination $setupDir)) {
            throw "Failed to expand $output into $setupDir"
        }

        $setupExe = "$setupDir\miktexsetup_standalone.exe"
        $pkgData  = "$env:KOMPANION_DIR\.miktex"

        if (!(Test-Path -Path $pkgData)) {
            Write-Host "Downloading MikTex data to $pkgData"
            $argList = @("download", "--package-set", "basic",
                         "--local-package-repository", $pkgData)
            Invoke-CapturedCommand $setupExe $argList
        }

        if (!(Test-Path -Path $miktex)) {
            Write-Host "Installing MikTex data to $miktex"
            $argList = @("install", "--package-set", "basic",
                         "--local-package-repository", $pkgData,
                         "--portable", $miktex)
            Invoke-CapturedCommand $setupExe $argList
        }

        Write-Warn "Please, consider manually removing $pkgData if succeeded"
    }

    if ($success) {
        Set-KompanionEnvVar -Name "MIKTEX_HOME" -Value $miktex
        Initialize-AddToPath -Directory "$env:MIKTEX_HOME"

        $cmdPath = "$env:MIKTEX_HOME\miktex-portable.cmd"
        if (Test-Path -Path $cmdPath) {
            $isMikTexRunning = @(Get-Process -Name "miktex-console" -ErrorAction SilentlyContinue).Count -gt 0
            if (-not $isMikTexRunning) {
                Start-Process -FilePath $cmdPath -NoNewWindow
            }
        }

        Initialize-AddToPath -Directory "$env:MIKTEX_HOME\texmfs\install\miktex\bin\x64\internal"
        Initialize-AddToPath -Directory "$env:MIKTEX_HOME\texmfs\install\miktex\bin\x64"
    } else {
        Write-Warn "Failed to install MikTex, skipping configuration..."
    }
}

function Invoke-ConfigureMingW64 {
    Write-Head "* Configuring MingW64..."

    $target = "mingw64"
    $url    = $KOMPANION_SETUP.url.mingw64
    $output = "$env:KOMPANION_TEMP\mingw64.zip"
    $path   = "$env:KOMPANION_BIN"

    $success = Invoke-DlUnzipInstall $path $url $output -Target $target

    if ($success) {
        Set-KompanionEnvVar -Name "MINGW64_HOME" `
            -Value "$env:KOMPANION_BIN\$target"

        Set-KompanionEnvVar -Name "CC" `
            -Value "$env:MINGW64_HOME\bin\gcc.exe"

        Set-KompanionEnvVar -Name "CXX" `
            -Value "$env:MINGW64_HOME\bin\g++.exe"

        Initialize-AddToPath -Directory "$env:MINGW64_HOME\bin"
    } else {
        Write-Warn "Failed to install MingW64, skipping configuration..."
    }
}

function Invoke-ConfigureNeovim {
    Write-Head "* Configuring Neovim..."

    $target  = "nvim-win64"
    $version = $KOMPANION_SETUP.version.neovim
    $url     = Get-PackageVersionedUrl "neovim"
    $output  = "$env:KOMPANION_TEMP\neovim.zip"
    $path    = "$env:KOMPANION_BIN"

    $success = Invoke-DlUnzipInstall $path $url $output -Target $target

    if ($success) {
        Set-KompanionEnvVar -Name "NEOVIM_HOME" `
            -Value "$env:KOMPANION_BIN\$target"

        Initialize-AddToPath -Directory "$env:NEOVIM_HOME\bin"
    } else {
        Write-Warn "Failed to install Neovim, skipping configuration..."
    }
}

function Invoke-ConfigureNode {
    Write-Head "* Configuring Node.js..."

    $version = $KOMPANION_SETUP.version.node
    $target  = "node-v$version-win-x64"
    $url     = Get-PackageVersionedUrl "node"
    $output  = "$env:KOMPANION_TEMP\node.zip"
    $path    = "$env:KOMPANION_BIN"

    $success = Invoke-DlUnzipInstall $path $url $output -Target $target

    if ($success) {
        Set-KompanionEnvVar -Name "NODE_HOME" `
            -Value "$env:KOMPANION_BIN\$target"

        Initialize-AddToPath -Directory "$env:NODE_HOME"
    } else {
        Write-Warn "Failed to install Node.js, skipping configuration..."
    }
}

function Invoke-ConfigureNteract {
    Write-Head "* Configuring nteract..."

    $target = $null
    $url    = $KOMPANION_SETUP.url.nteract
    $output = "$env:KOMPANION_TEMP\nteract.zip"
    $path   = "$env:KOMPANION_BIN\nteract"

    $success = Invoke-DlUnzipInstall $path $url $output -Target $target

    if ($success) {
        Set-KompanionEnvVar -Name "NTERACT_HOME" -Value $path
        Initialize-AddToPath -Directory "$env:NTERACT_HOME"
    } else {
        Write-Warn "Failed to install nteract, skipping configuration..."
    }
}

function Invoke-ConfigureOctave {
    Write-Head "* Configuring Octave..."

    $version = $KOMPANION_SETUP.version.octave
    $url     = Get-PackageVersionedUrl "octave"
    $output  = "$env:KOMPANION_TEMP\octave.zip"
    $path    = "$env:KOMPANION_BIN"
    $target  = "octave-$version-w64"

    $success = Invoke-DlUnzipInstall $path $url $output -Target $target

    if ($success) {
        Set-KompanionEnvVar -Name "OCTAVE_HOME" -Value "$path\$target"
        Initialize-AddToPath -Directory "$env:OCTAVE_HOME"
    } else {
        Write-Warn "Failed to install Octave, skipping configuration..."
    }
}

function Invoke-ConfigureOllama {
    Write-Head "* Configuring Ollama..."

    $target  = $null
    $version = $KOMPANION_SETUP.version.ollama
    $url     = Get-PackageVersionedUrl "ollama"
    $output  = "$env:KOMPANION_TEMP\ollama.zip"
    $path    = "$env:KOMPANION_BIN\ollama-win-x64-$version"

    $success = Invoke-DlUnzipInstall $path $url $output -Target $target

    if ($success) {
        Set-KompanionEnvVar -Name "OLLAMA_HOME" -Value "$path"
        Initialize-AddToPath -Directory "$env:OLLAMA_HOME"
    } else {
        Write-Warn "Failed to install Ollama, skipping configuration..."
    }
}

function Invoke-ConfigureOpenCascade {
    Write-Head "* Configuring OpenCASCADE..."

    $target = $null
    $url    = $KOMPANION_SETUP.url.opencascade
    $output = "$env:KOMPANION_TEMP\opencascade.zip"
    $path   = "$env:KOMPANION_BIN\opencascade"

    $success = Invoke-DlUnzipInstall $path $url $output -Target $target

    if ($success) {
        Set-KompanionEnvVar -Name "OPENCASCADE_HOME" -Value $path
        Initialize-AddToPath -Directory "$env:OPENCASCADE_HOME"
    } else {
        Write-Warn "Failed to install OpenCASCADE, skipping configuration..."
    }
}

function Invoke-ConfigurePandoc {
    Write-Head "* Configuring Pandoc..."

    $version = $KOMPANION_SETUP.version.pandoc
    $target  = "pandoc-$version"
    $url     = Get-PackageVersionedUrl "pandoc"
    $output  = "$env:KOMPANION_TEMP\pandoc.zip"
    $path    = "$env:KOMPANION_BIN"

    $success = Invoke-DlUnzipInstall $path $url $output -Target $target

    if ($success) {
        Set-KompanionEnvVar -Name "PANDOC_HOME" `
            -Value "$env:KOMPANION_BIN\$target"

        Initialize-AddToPath -Directory "$env:PANDOC_HOME"
    } else {
        Write-Warn "Failed to install Pandoc, skipping configuration..."
    }
}

function Invoke-ConfigureParaView {
    Write-Head "* Configuring ParaView..."

    $target = "ParaView-6.0.1-Windows-Python3.12-msvc2017-AMD64"
    $url    = $KOMPANION_SETUP.url.paraview
    $output = "$env:KOMPANION_TEMP\paraview.zip"
    $path   = "$env:KOMPANION_BIN"

    $success = Invoke-DlUnzipInstall $path $url $output -Target $target

    if ($success) {
        Set-KompanionEnvVar -Name "PARAVIEW_HOME" `
            -Value "$env:KOMPANION_BIN\$target"
        # XXX do not add to PATH, use as GUI
    } else {
        Write-Warn "Failed to install ParaView, skipping configuration..."
    }
}

function Invoke-ConfigurePerl {
    Write-Head "* Configuring Perl..."

    $target = $null
    $url    = $KOMPANION_SETUP.url.perl
    $output = "$env:KOMPANION_TEMP\perl.zip"
    $path   = "$env:KOMPANION_BIN\strawberry-perl-5.42.2.1-64bit"

    $success = Invoke-DlUnzipInstall $path $url $output -Target $target

    if ($success) {
        Set-KompanionEnvVar -Name "PERL_HOME" -Value "$path"
        # Per Strawberry Perl portable documentation:
        Initialize-AddToPath -Directory "$env:PERL_HOME\perl\site\bin"
        Initialize-AddToPath -Directory "$env:PERL_HOME\perl\bin"
        Initialize-AddToPath -Directory "$env:PERL_HOME\c\bin"
    } else {
        Write-Warn "Failed to install Perl, skipping configuration..."
    }
}

function Invoke-ConfigurePoppler {
    Write-Head "* Configuring Poppler..."

    $version = $KOMPANION_SETUP.version.poppler
    $target  = "poppler-$version"
    $url     = Get-PackageVersionedUrl "poppler"
    $output  = "$env:KOMPANION_TEMP\poppler.zip"
    $path    = "$env:KOMPANION_BIN"

    $success = Invoke-DlUnzipInstall $path $url $output -Target $target

    if ($success) {
        Set-KompanionEnvVar -Name "POPPLER_HOME" `
             -Value "$env:KOMPANION_BIN\$target\Library"

        Initialize-AddToPath -Directory "$env:POPPLER_HOME\bin"
        Initialize-AddToManPath -Directory "$env:POPPLER_HOME\share\man"
    } else {
        Write-Warn "Failed to install Poppler, skipping configuration..."
    }
}

function Invoke-ConfigurePrePoMax {
    Write-Head "* Configuring PrePoMax..."

    $target = "PrePoMax v2.5.0"
    $url    = $KOMPANION_SETUP.url.prepomax
    $output = "$env:KOMPANION_TEMP\prepomax.zip"
    $path   = "$env:KOMPANION_BIN"

    $success = Invoke-DlUnzipInstall $path $url $output -Target $target

    if ($success) {
        Set-KompanionEnvVar -Name "PREPOMAX_HOME" `
            -Value "$env:KOMPANION_BIN\$target"

        Initialize-AddToPath -Directory "$env:PREPOMAX_HOME"
    } else {
        Write-Warn "Failed to install PrePoMax, skipping configuration..."
    }
}

function Invoke-ConfigureQuarto {
    Write-Head "* Configuring Quarto..."

    $target  = $null
    $version = $KOMPANION_SETUP.version.quarto
    $url     = Get-PackageVersionedUrl "quarto"
    $output  = "$env:KOMPANION_TEMP\quarto.zip"
    $path    = "$env:KOMPANION_BIN\quarto-$version-win"

    $success = Invoke-DlUnzipInstall $path $url $output -Target $target

    if ($success) {
        Set-KompanionEnvVar -Name "QUARTO_HOME" -Value "$path"
        Initialize-AddToPath -Directory "$env:QUARTO_HOME\bin"
    } else {
        Write-Warn "Failed to install Quarto, skipping configuration..."
    }
}

function Invoke-ConfigureRacket {
    Write-Head "* Configuring Racket..."
    # Racket installation not yet implemented
    # Set-KompanionEnvVar -Name "RACKET_HOME" -Value "$env:KOMPANION_BIN\racket"
    # Initialize-AddToPath -Directory "$env:RACKET_HOME\bin"
    # Set-KompanionEnvVar -Name "PLTUSERHOME" -Value "$env:KOMPANION_DIR\.racket"
    # Set-KompanionEnvVar -Name "PLT_PKGDIR" -Value "$env:PLTUSERHOME\Racket\8.18\pkgs"
    Write-Warn "- Racket installation not yet implemented."
}

function Invoke-ConfigureRadcal {
    Write-Head "* Configuring Radcal..."

    $path      = "$env:KOMPANION_BIN\firemodels"
    $fdsUrl    = $KOMPANION_SETUP.url.firemodels
    $fdsOutput = "$env:KOMPANION_TEMP\fds_smv.exe"
    $fdsTemp   = "$env:KOMPANION_TEMP\fds_smv"
    $radUrl    = $KOMPANION_SETUP.url.radcal

    $success = Invoke-HandledInstall $path $fdsOutput -InstallScript {
        if (!(Invoke-DownloadIfNeeded -URL $fdsUrl -Output $fdsOutput)) {
            throw "Failed to download $fdsUrl as $fdsOutput"
        }
        if (!(Invoke-Uncompress7zIfNeeded -Source $fdsOutput -Destination $fdsTemp)) {
            throw "Failed to expand $fdsOutput into $fdsTemp"
        }

        Move-Item -Path "$fdsTemp\firemodels" -Destination $path
        Remove-Item -Path $fdsTemp -Recurse -Force

        $radOutput = "$path\radcal.exe"
        if (!(Invoke-DownloadIfNeeded -URL $radUrl -Output $radOutput)) {
            throw "Failed to download $radUrl as $radOutput"
        }
    }

    if ($success) {
        Set-KompanionEnvVar -Name "FIREMODELS_HOME" -Value $path
        Initialize-AddToPath -Directory "$env:FIREMODELS_HOME\FDS6\bin"
        Initialize-AddToPath -Directory "$env:FIREMODELS_HOME\SMV6"
        Initialize-AddToPath -Directory "$env:FIREMODELS_HOME"
    } else {
        Write-Warn "Failed to install Radcal, skipping configuration..."
    }
}

function Invoke-ConfigureRipgrep {
    Write-Head "* Configuring Ripgrep..."

    $version = $KOMPANION_SETUP.version.ripgrep
    $target  = "ripgrep-$version-x86_64-pc-windows-gnu"
    $url     = Get-PackageVersionedUrl "ripgrep"
    $output  = "$env:KOMPANION_TEMP\ripgrep.zip"
    $path    = "$env:KOMPANION_BIN"

    $success = Invoke-DlUnzipInstall $path $url $output -Target $target

    if ($success) {
        Set-KompanionEnvVar -Name "RIPGREP_HOME" `
            -Value "$env:KOMPANION_BIN\$target"

        Initialize-AddToPath -Directory "$env:RIPGREP_HOME"
    } else {
        Write-Warn "Failed to install Ripgrep, skipping configuration..."
    }
}

function Invoke-ConfigureRlang {
    Write-Head "* Configuring R..."

    $path   = "$env:KOMPANION_BIN\rlang"
    $url    = $KOMPANION_SETUP.url.rlang
    $output = "$env:KOMPANION_TEMP\R-4.5.2-win.exe"

    $success = Invoke-HandledInstall $path $output -InstallScript {
        if (!(Invoke-DownloadIfNeeded -URL $url -Output $output)) {
            throw "Failed to download $url as $output"
        }
        $argList = @("/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART", "/DIR=$path")
        $proc = Start-Process -FilePath $output -ArgumentList $argList -Wait -PassThru
        if ($proc.ExitCode -ne 0) {
            throw "R installation failed with exit code $($proc.ExitCode)"
        }
    }

    if ($success) {
        Set-KompanionEnvVar -Name "RLANG_HOME" -Value $path
        Initialize-AddToPath -Directory "$env:RLANG_HOME\bin\x64"

        Set-KompanionEnvVar -Name "R_LIBS_USER" -Value "$env:KOMPANION_DIR\.rlang\4.5"

        if (-not (Get-IsLockedPkg "rlang")) {
            $rscript = "$env:RLANG_HOME\bin\x64\Rscript.exe"
            $repos = if ($KOMPANION_SETUP.url.rrepos) { $KOMPANION_SETUP.url.rrepos } else { "https://pbil.univ-lyon1.fr/CRAN/" }

            $cmd1 = "install.packages('tidyverse', repos='$repos')"
            Invoke-CapturedCommand $rscript @("-e", $cmd1)

            $cmd2 = "install.packages('IRkernel', repos='$repos')"
            Invoke-CapturedCommand $rscript @("-e", $cmd2)

            $cmd3 = "IRkernel::installspec(user = FALSE)"
            Invoke-CapturedCommand $rscript @("-e", $cmd3)

            Set-LockedPkg "rlang"
        }
    } else {
        Write-Warn "Failed to install R, skipping configuration..."
    }
}

function Invoke-ConfigureRust {
    Write-Head "* Configuring Rust..."

    $url    = $KOMPANION_SETUP.url.rust
    $conf   = $KOMPANION_SETUP.config.rust
    $output = "$env:KOMPANION_TEMP\rustup-init.exe"
    $path   = "$env:KOMPANION_DIR\.cargo\bin"

    # Rust requires environment variables BEFORE installation:
    Set-KompanionEnvVar -Name "CARGO_HOME" `
        -Value "$env:KOMPANION_DIR\.cargo"

    Set-KompanionEnvVar -Name "RUSTUP_HOME" `
        -Value "$env:KOMPANION_DIR\.cargo"

    # Disable certificate revocation check due to potential issues in certain Windows environments:
    Set-KompanionEnvVar -Name "CARGO_HTTP_CHECK_REVOKE" -Value "false"

    $success = Invoke-HandledInstall $path $output -InstallScript {
        if (!(Invoke-DownloadIfNeeded -URL $url -Output $output)) {
            throw "Failed to download $url as $output"
        }

        $arglist = @(
            "--verbose",
            "-y",
            "--default-host",      $conf.triple,
            "--default-toolchain", $conf.toolchain,
            "--profile",           $conf.profile,
            "--no-modify-path"
        )

        $code = Invoke-CapturedCommand $output $arglist
        if ($code -ne 0) {
            throw "rustup-init failed with exit code $code"
        }
    }

    if ($success) {
        Initialize-AddToPath -Directory "$env:CARGO_HOME\bin"
    } else {
        Write-Warn "Failed to install Rust, skipping configuration..."
    }
}

function Invoke-ConfigureSalome {
    Write-Head "* Configuring SALOME..."
    # NOTE: this needs to be downloaded manually (form to fill).

    $pattern = "$env:KOMPANION_BIN\SALOME-*"
    $latest = Get-Item -Path $pattern -ErrorAction SilentlyContinue | `
        Where-Object { $_.PSIsContainer } | `
        Sort-Object Name | Select-Object -Last 1

    if ($latest -and (Test-Path $latest.FullName)) {
        Set-KompanionEnvVar -Name "SALOME_HOME" -Value "$($latest.FullName)"
        Initialize-AddToPath -Directory "$env:SALOME_HOME"
    } else {
        Write-Warn "SALOME directory not found, skipping configuration..."
    }
}

function Invoke-ConfigureSevenZip {
    Write-Head "* Configuring 7-Zip..."

    $path   = "$env:KOMPANION_BIN\7z"
    $temp   = "$env:KOMPANION_TEMP\7z"
    $url    = $KOMPANION_SETUP.url.sevenzip

    $success = Invoke-HandledInstall $path $temp -InstallScript {
        if (!(Test-Path -Path $temp)) {
            New-Item -Path $temp -ItemType Directory -Force | Out-Null
        }
        $files = @("7z.dll", "7z.exe", "License.txt", "readme.txt")
        foreach ($file in $files) {
            $fileUrl = "$url$file"
            $fileOut = "$temp\$file"
            if (!(Invoke-DownloadIfNeeded -URL $fileUrl -Output $fileOut)) {
                throw "Failed to download $fileUrl"
            }
        }
        Move-Item -Path $temp -Destination $path
    }

    if ($success) {
        Set-KompanionEnvVar -Name "SEVENZIP_HOME" -Value $path
        Initialize-AddToPath -Directory "$env:SEVENZIP_HOME"
    } else {
        Write-Warn "Failed to install 7-Zip, skipping configuration..."
    }
}

function Invoke-ConfigureSu2 {
    Write-Head "* Configuring SU2..."

    $path        = "$env:KOMPANION_BIN\su2"
    $url         = $KOMPANION_SETUP.url.su2
    $output      = "$env:KOMPANION_TEMP\su2.zip"
    $temp        = "$env:KOMPANION_TEMP\su2"
    $innerOutput = "$temp\win64-mpi.zip"

    $success = Invoke-HandledInstall $path $output -InstallScript {
        if (!(Invoke-DownloadIfNeeded -URL $url -Output $output)) {
            throw "Failed to download $url as $output"
        }
        if (!(Invoke-UncompressZipIfNeeded -Source $output -Destination $temp)) {
            throw "Failed to expand $output into $temp"
        }
        if (!(Invoke-UncompressZipIfNeeded -Source $innerOutput -Destination $path)) {
            throw "Failed to expand $innerOutput into $path"
        }
        Remove-Item -Path $temp -Recurse -Force
    }

    if ($success) {
        Set-KompanionEnvVar -Name "SU2_HOME" -Value $path
        Initialize-AddToPath -Directory "$env:SU2_HOME\bin"
        # TODO add to PYTHONPATH;JULIA_LOAD_PATH
    } else {
        Write-Warn "Failed to install SU2, skipping configuration..."
    }
}

function Invoke-ConfigureTabby {
    Write-Head "* Configuring Tabby..."

    $target = $null
    $url    = $KOMPANION_SETUP.url.tabby
    $output = "$env:KOMPANION_TEMP\tabby.zip"
    $path   = "$env:KOMPANION_BIN\tabby"

    $success = Invoke-DlUnzipInstall $path $url $output -Target $target

    if ($success) {
        Set-KompanionEnvVar -Name "TABBY_HOME" `
            -Value "$env:KOMPANION_BIN\tabby"

        Initialize-AddToPath -Directory "$env:TABBY_HOME"
    } else {
        Write-Warn "Failed to install Tabby, skipping configuration..."
    }
}

function Invoke-ConfigureTesseract {
    Write-Head "* Configuring Tesseract..."

    $path     = "$env:KOMPANION_BIN\tesseract"
    $tessdata = "$env:KOMPANION_BIN\tessdata"
    $url      = $KOMPANION_SETUP.url.tesseract
    $urlData  = $KOMPANION_SETUP.url.tessdata
    $output   = "$env:KOMPANION_TEMP\tesseract.exe"

    $success = Invoke-HandledInstall $path $output -InstallScript {
        if (!(Invoke-DownloadIfNeeded -URL $url -Output $output)) {
            throw "Failed to download $url as $output"
        }
        if (!(Invoke-Uncompress7zIfNeeded -Source $output -Destination $path)) {
            throw "Failed to expand $output into $path"
        }
        $pluginsDir = Join-Path $path '$PLUGINSDIR'
        if (Test-Path $pluginsDir) { Remove-Item $pluginsDir -Recurse -Force }
    }

    if ($success) {
        if (-not (Test-Path $tessdata)) {
            Write-Host "Cloning tessdata repository..."
            git clone $urlData $tessdata
        }

        Set-KompanionEnvVar -Name "TESSERACT_HOME" -Value $path
        Set-KompanionEnvVar -Name "TESSDATA_PREFIX" -Value $tessdata
        Initialize-AddToPath -Directory "$env:TESSERACT_HOME"
    } else {
        Write-Warn "Failed to install Tesseract, skipping configuration..."
    }
}

function Invoke-ConfigureTypst {
    Write-Head "* Configuring Typst..."

    $version = $KOMPANION_SETUP.version.typst
    $target  = "typst-x86_64-pc-windows-msvc"
    $url     = Get-PackageVersionedUrl "typst"
    $output  = "$env:KOMPANION_TEMP\typst.zip"
    $path    = "$env:KOMPANION_BIN"

    $success = Invoke-DlUnzipInstall $path $url $output -Target $target

    if ($success) {
        Set-KompanionEnvVar -Name "TYPST_HOME" `
            -Value "$env:KOMPANION_BIN\$target"

        Initialize-AddToPath -Directory "$env:TYPST_HOME"
    } else {
        Write-Warn "Failed to install Typst, skipping configuration..."
    }
}

function Invoke-ConfigureUv {
    Write-Head "* Configuring Astral UV..."

    $target = $null
    $url    = Get-PackageVersionedUrl "uv"
    $output = "$env:KOMPANION_TEMP\uv.zip"
    $path   = "$env:KOMPANION_BIN\uv"

    $success = Invoke-DlUnzipInstall $path $url $output -Target $target

    if ($success) {
        Set-KompanionEnvVar -Name "UV_HOME" -Value "$path"
        Initialize-AddToPath -Directory "$env:UV_HOME"
    } else {
        Write-Warn "Failed to install Astral UV, skipping configuration..."
    }
}

function Invoke-ConfigureVsCode {
    Write-Head "* Configuring Visual Studio Code..."

    $target = $null
    $url    = $KOMPANION_SETUP.url.vscode
    $output = "$env:KOMPANION_TEMP\vscode.zip"
    $path   = "$env:KOMPANION_BIN\vscode"
    $dotdir = "$env:KOMPANION_DIR\.vscode"

    $success = Invoke-DlUnzipInstall $path $url $output -Target $target

    if ($success) {
        Set-KompanionEnvVar -Name "VSCODE_HOME" -Value "$path"
        Set-KompanionEnvVar -Name "VSCODE_EXTENSIONS" -Value "$dotdir\extensions"
        Set-KompanionEnvVar -Name "VSCODE_SETTINGS" -Value "$dotdir\user-data"
        Initialize-AddToPath -Directory "$env:VSCODE_HOME"
    } else {
        Write-Warn "Failed to install Visual Studio Code, skipping configuration..."
    }
}

function Invoke-ConfigureWinPython {
    Write-Head "* Configuring WinPython..."

    $target  = "WPy64-31380"
    $url     = $KOMPANION_SETUP.url.winpython
    $output  = "$env:KOMPANION_TEMP\winpython.zip"
    $path    = "$env:KOMPANION_BIN"

    $success = Invoke-DlUnzipInstall $path $url $output -Target $target

    if ($success) {
        Set-KompanionEnvVar -Name "WINPYTHON_HOME" `
            -Value "$env:KOMPANION_BIN\$target"

        # Main path to python executable and standard library:
        Set-KompanionEnvVar -Name "PYTHON_HOME" `
            -Value "$env:WINPYTHON_HOME\python"

        # Path to IPython profiles, history, etc.:
        Set-KompanionEnvVar -Name "IPYTHONDIR" `
            -Value "$env:KOMPANION_DIR\.ipython"

        # Jupyter to be used with IJulia (if any) and data path:
        Set-KompanionEnvVar -Name "JUPYTER" `
            -Value "$env:PYTHON_HOME\Scripts\jupyter.exe"

        # Path to Jupyter kernels, etc.:
        Set-KompanionEnvVar -Name "JUPYTER_DATA_DIR" `
            -Value "$env:KOMPANION_DIR\.jupyter"

        # Required for jupyter kernels to work:
        Set-KompanionEnvVar -Name "JUPYTER_PATH" `
            -Value "$env:JUPYTER_DATA_DIR"

        # Point quarto to the right python:
        Set-KompanionEnvVar -Name "QUARTO_PYTHON" `
            -Value "$env:PYTHON_HOME\python.exe"

        Initialize-AddToPath -Directory "$env:PYTHON_HOME\Scripts"
        Initialize-AddToPath -Directory "$env:PYTHON_HOME"

        # Install minimal requirements:
        $lockFile = "$env:KOMPANION_DOT\python-pkgs.lock"

        # Ignore deps if requested:
        if ($NoPythonDeps) {
            New-Item -ItemType File -Path $lockFile -Force | Out-Null
        }

        # Note: manually remove lock file if no deps installed at first:
        if (!(Test-Path $lockFile)) {
            Piperish install --upgrade pip
            Piperish install -r "$env:KOMPANION_DOT\requirements.txt"
            New-Item -ItemType File -Path $lockFile -Force | Out-Null
        }
    } else {
        Write-Warn "Failed to install WinPython, skipping configuration..."
    }
}

function Invoke-ConfigureZettlr {
    Write-Head "* Configuring Zettlr..."

    $path   = "$env:KOMPANION_BIN\zettlr"
    $temp   = "$env:KOMPANION_TEMP\zettlr_tmp"
    $output = "$env:KOMPANION_TEMP\zettlr.exe"
    $url    = $KOMPANION_SETUP.url.zettlr

    $success = Invoke-HandledInstall $path $output -InstallScript {
        if (!(Invoke-DownloadIfNeeded -URL $url -Output $output)) {
            throw "Failed to download $url as $output"
        }
        if (!(Invoke-Uncompress7zIfNeeded -Source $output -Destination $temp)) {
            throw "Failed to expand $output into $temp"
        }
        $app = Join-Path $temp '$PLUGINSDIR\app-64.7z'
        if (!(Invoke-Uncompress7zIfNeeded -Source $app -Destination $path)) {
            throw "Failed to expand $app into $path"
        }
        Remove-Item -Path $temp -Recurse -Force
    }

    if ($success) {
        Set-KompanionEnvVar -Name "ZETTLR_HOME" -Value $path
        Set-KompanionEnvVar -Name "ZETTLR_DATA" -Value "$env:KOMPANION_DIR\.zettlr"
        Initialize-AddToPath -Directory "$env:ZETTLR_HOME"
    } else {
        Write-Warn "Failed to install Zettlr, skipping configuration..."
    }
}
#endregion: software_configurations

#region: modules_config
function Get-ModulesConfig {
    $path = "$env:KOMPANION_DOT\kompanion.json"

    if (Test-Path -Path $path) {
        Write-Head "* Using user-defined configuration..."
        return Get-Content -Path $path -Raw | ConvertFrom-Json
    }

    return $DEFAULT_CONFIG
}

function Enable-Module {
    Write-Host "Sorry, WIP..."
}

function Show-ModuleList {
    Write-Host "Sorry, WIP..."
}
#endregion: modules_config

#region: orchestration
function Start-KompanionConfigure {
    param (
        [pscustomobject]$Config
    )

    # ---
    # Languages come last because some packages might override them
    # (especially Python that is used everywhere).
    # Essential network tools (7z, curl) come before others to resolve downloads.
    # ---

    Write-Good "`n> Starting Kompanion base configuration..."

    Invoke-ConfigureSevenZip
    Invoke-ConfigureCurl
    Invoke-ConfigureRipgrep
    Invoke-ConfigureVsCode
    Invoke-ConfigureLiteXL
    Invoke-ConfigureGit
    Invoke-ConfigureGithubCLI
    Invoke-ConfigureQuarto
    Invoke-ConfigureTypst

    if ($Config.base.devtoys)     { Invoke-ConfigureDevToys }
    if ($Config.base.drawio)      { Invoke-ConfigureDrawio }
    if ($Config.base.ffmpeg)      { Invoke-ConfigureFfmpeg }
    if ($Config.base.imagemagick) { Invoke-ConfigureImageMagick }
    if ($Config.base.inkscape)    { Invoke-ConfigureInkscape }
    if ($Config.base.jabref)      { Invoke-ConfigureJabRef }
    if ($Config.base.lessmsi)     { Invoke-ConfigureLessMsi }
    if ($Config.base.logseq)      { Invoke-ConfigureLogseq }
    if ($Config.base.miktex)      { Invoke-ConfigureMikTex }
    if ($Config.base.nteract)     { Invoke-ConfigureNteract }
    if ($Config.base.nvim)        { Invoke-ConfigureNeovim }
    if ($Config.base.pandoc)      { Invoke-ConfigurePandoc }
    if ($Config.base.poppler)     { Invoke-ConfigurePoppler }
    if ($Config.base.tabby)       { Invoke-ConfigureTabby }
    if ($Config.base.zettlr)      { Invoke-ConfigureZettlr }

    Write-Good "`n> Starting Kompanion simulation tools configuration..."

    Invoke-ConfigureSalome

    if ($Config.simu.blender)     { Invoke-ConfigureBlender }
    if ($Config.simu.dwsim)       { Invoke-ConfigureDwsim }
    if ($Config.simu.elmer)       { Invoke-ConfigureElmer }
    if ($Config.simu.freecad)     { Invoke-ConfigureFreeCAD }
    if ($Config.simu.freefem)     { Invoke-ConfigureFreeFem }
    if ($Config.simu.gmsh)        { Invoke-ConfigureGmsh }
    if ($Config.simu.gnuplot)     { Invoke-ConfigureGnuplot }
    if ($Config.simu.meshlab)     { Invoke-ConfigureMeshLab }
    if ($Config.simu.ollama)      { Invoke-ConfigureOllama }
    if ($Config.simu.opencascade) { Invoke-ConfigureOpenCascade }
    if ($Config.simu.paraview)    { Invoke-ConfigureParaView }
    if ($Config.simu.prepomax)    { Invoke-ConfigurePrePoMax }
    if ($Config.simu.radcal)      { Invoke-ConfigureRadcal }
    if ($Config.simu.su2)         { Invoke-ConfigureSu2 }
    if ($Config.simu.tesseract)   { Invoke-ConfigureTesseract }

    Write-Good "`n> Starting Kompanion languages configuration..."

    Invoke-ConfigureDotNET
    Invoke-ConfigureMingW64
    Invoke-ConfigureNode
    Invoke-ConfigureRust
    Invoke-ConfigureUv
    Invoke-ConfigureWinPython

    if ($Config.lang.coq)         { Invoke-ConfigureCoq }
    if ($Config.lang.elm)         { Invoke-ConfigureElm }
    if ($Config.lang.erlang)      { Invoke-ConfigureErlang }
    if ($Config.lang.haskell)     { Invoke-ConfigureHaskell }
    if ($Config.lang.julia)       { Invoke-ConfigureJulia }
    if ($Config.lang.octave)      { Invoke-ConfigureOctave }
    if ($Config.lang.perl)        { Invoke-ConfigurePerl }
    if ($Config.lang.racket)      { Invoke-ConfigureRacket }
    if ($Config.lang.rlang)       { Invoke-ConfigureRlang }

    # Make sure this is a git repository to allow updates:
    if (-not (Test-Path -Path "$env:KOMPANION_DIR\.git")) {
        Write-Warn "Kompanion downloaded as zip, getting repository..."
        $gitUrl = if ($KOMPANION_SETUP.url.kompanion_git) { $KOMPANION_SETUP.url.kompanion_git } else { "https://github.com/wallytutor/kompanion.git" }

        & git clone $gitUrl "$env:KOMPANION_REPO\kompanion"

        & Move-Item -Path "$env:KOMPANION_REPO\kompanion\.git" `
            -Destination $env:KOMPANION_DIR

        & Remove-Item -Path "$env:KOMPANION_REPO\kompanion" -Recurse

        & git pull
        & KompanionRebuild
    }
}

function Start-KompanionMain {
    # Fake user profile to avoid applications accessing host user profile:
    Set-KompanionEnvVar -Name "USERPROFILE"     -Value "$KOMPANION_ROOT"
    Set-KompanionEnvVar -Name "APPDATA"         -Value "$KOMPANION_ROOT\AppData\Roaming"
    Set-KompanionEnvVar -Name "LOCALAPPDATA"    -Value "$KOMPANION_ROOT\AppData\Local"
    Set-KompanionEnvVar -Name "XDG_CONFIG_HOME" -Value "$KOMPANION_ROOT\.config"
    Set-KompanionEnvVar -Name "KOMPANION_DIR"   -Value "$KOMPANION_ROOT"
    Set-KompanionEnvVar -Name "KOMPANION_DOT"   -Value "$KOMPANION_ROOT\.kompanion"
    Set-KompanionEnvVar -Name "KOMPANION_REPO"  -Value "$KOMPANION_ROOT\repos"
    Set-KompanionEnvVar -Name "KOMPANION_BIN"   -Value "$KOMPANION_ROOT\.kompanion\bin"
    Set-KompanionEnvVar -Name "KOMPANION_LOGS"  -Value "$KOMPANION_ROOT\.kompanion\logs"
    Set-KompanionEnvVar -Name "KOMPANION_TEMP"  -Value "$KOMPANION_ROOT\.kompanion\temp"

    Write-Good "> Starting Kompanion from $env:KOMPANION_DIR"

    # Ensure important directories exist:
    Initialize-EnsureDirectory $env:KOMPANION_BIN
    Initialize-EnsureDirectory $env:KOMPANION_LOGS
    Initialize-EnsureDirectory $env:KOMPANION_TEMP
    Initialize-EnsureDirectory $env:KOMPANION_REPO
    Initialize-EnsureDirectory "$env:KOMPANION_DIR\Desktop"

    # Get configuration of modules:
    $config = Get-ModulesConfig

    # Configure components if needed:
    Start-KompanionConfigure $config

    Write-Head "`nEnvironment"
    Write-Head "-----------"
    Write-Output "KOMPANION_DIR       $env:KOMPANION_DIR"
    Write-Output "KOMPANION_BIN       $env:KOMPANION_BIN"
    Write-Output "KOMPANION_LOGS      $env:KOMPANION_LOGS"
    Write-Output "KOMPANION_TEMP      $env:KOMPANION_TEMP"

    Save-KompanionEnvVarsToFile

    # Run Kompanion VS Code instance if requested:
    if ($RunVsCode) {
        Code.exe --extensions-dir $env:VSCODE_EXTENSIONS `
                 --user-data-dir  $env:VSCODE_SETTINGS  .
    }
}

function KompanionSource {
    . "$env:KOMPANION_DIR\kompanion.ps1"
}

function KompanionRebuild {
    . "$env:KOMPANION_DIR\kompanion.ps1" -RebuildOnStart
}

function Kode {
    param (
        [switch]$WithKompanion
    )
    . "$env:KOMPANION_DIR\kompanion.ps1"

    $paths = if ($WithKompanion) {
        @($env:KOMPANION_DIR, $PWD.Path)
    } else {
        @($PWD.Path)
    }

    Code.exe $paths `
        --extensions-dir $env:VSCODE_EXTENSIONS `
        --user-data-dir  $env:VSCODE_SETTINGS
}

function Lite {
    . "$env:KOMPANION_DIR\kompanion.ps1"
    lite-xl.exe $PWD.Path
}
#endregion: orchestration

#region: main
if (-not $NoRun) {
    Start-KompanionMain

    # Source user-defined aliases at script level so they persist in terminal:
    if (Test-Path -Path "$env:KOMPANION_DOT\aliases.ps1") {
        Write-Good "`n> Loading user-defined aliases"
        . "$env:KOMPANION_DOT\aliases.ps1"
    }

    if (Test-Path -Path "$env:KOMPANION_DOT\psrc.ps1") {
        Write-Good "`n> Loading user-defined private aliases"
        . "$env:KOMPANION_DOT\psrc.ps1"
    }

    # Custom prompt:
    function prompt {
        $leaf = Split-Path -Leaf (Get-Location)
        Write-Host "kompanion:$leaf" -ForegroundColor Cyan -NoNewline
        return "> "
    }
}
#endregion: main
