# kompanion.ps1
# Possible future packages:
# - Racket
# - MLton
# - smlnk
# - octave
# - scilab
# - gnuplot
# - graphviz

param (
    # Actions:
    [switch]$RunVsCode,
    [switch]$RebuildOnStart,

    # Build options:
    [switch]$NoPythonDeps,
    [switch]$NoJuliaDeps,
    [switch]$NoMajordome
)

. "$PSScriptRoot\konfiguration.ps1"

#region: default_config
$DEFAULT_CONFIG = [PSCustomObject]@{
    base = [PSCustomObject]@{
        vscode      = $true
        tabby       = $true
        git         = $true
        curl        = $true
        sevenzip    = $true
        zettlr      = $false
        drawio      = $false
        nvim        = $false
        lessmsi     = $false
        msys2       = $false
        pandoc      = $false
        jabref      = $false
        inkscape    = $false
        miktex      = $false
        nteract     = $false
        ffmpeg      = $false
        imagemagick = $false
        poppler     = $false
        quarto      = $false
    }
    lang = [PSCustomObject]@{
        python      = $true
        rust        = $true
        julia       = $false
        node        = $false
        erlang      = $false
        haskell     = $false
        elm         = $false
        racket      = $false
        coq         = $false
        rlang       = $false
    }
    simu = [PSCustomObject]@{
        paraview    = $false
        freecad     = $false
        blender     = $false
        meshlab     = $false
        dwsim       = $false
        opencascade = $false
        gmsh        = $false
        elmer       = $false
        prepomax    = $false
        su2         = $false
        tesseract   = $false
        radcal      = $false
        freefem     = $false
    }
}

$DEFAULT_RUST_INSTALL = [PSCustomObject]@{
    toolchain = "stable"
    triple    = "x86_64-pc-windows-gnu"
    profile   = "default"
}

$URL_VSCODE      = "https://update.code.visualstudio.com/latest/win32-x64-archive/stable"
$URL_GIT         = "https://github.com/git-for-windows/git/releases/download/v2.51.0.windows.1/PortableGit-2.51.0-64-bit.7z.exe"
$URL_SEVENZIP    = "https://github.com/commercialhaskell/stackage-content/releases/download/7z-22.01/"
$URL_LESSMSI     = "https://github.com/activescott/lessmsi/releases/download/v2.10.3/lessmsi-v2.10.3.zip"
$URL_PANDOC      = "https://github.com/jgm/pandoc/releases/download/3.8/pandoc-3.8-windows-x86_64.zip"
$URL_IMAGEMAGICK = "https://github.com/ImageMagick/ImageMagick/releases/download/7.1.2-8/ImageMagick-7.1.2-8-portable-Q16-HDRI-x64.7z"
$URL_POPPLER     = "https://github.com/oschwartz10612/poppler-windows/releases/download/v25.11.0-0/Release-25.11.0-0.zip"
$URL_QUARTO      = "https://github.com/quarto-dev/quarto-cli/releases/download/v1.8.26/quarto-1.8.26-win.zip"
$URL_NVIM        = "https://github.com/neovim/neovim/releases/download/nightly/nvim-win64.zip"
$URL_ZETTLR      = "https://github.com/Zettlr/Zettlr/releases/download/v4.2.0/Zettlr-4.2.0-x64.exe"
$URL_FFMPEG      = "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-full.7z"
$URL_INKSCAPE    = "https://inkscape.org/gallery/item/53695/inkscape-1.4_2024-10-11_86a8ad7-x64.7z"
$URL_MIKTEX      = "https://miktex.org/download/ctan/systems/win32/miktex/setup/windows-x64/miktexsetup-5.5.0+1763023-x64.zip"
# $URL_NTERACT     = "https://github.com/nteract/nteract/releases/download/v0.28.0/nteract-0.28.0-win.zip"

$URL_PYTHON      = "https://github.com/winpython/winpython/releases/download/17.2.20251012/WinPython64-3.13.8.0dotb1.zip"
$URL_RUST_GNU    = "https://static.rust-lang.org/rustup/dist/x86_64-pc-windows-gnu/rustup-init.exe"
$URL_RUST_MSVC   = "https://static.rust-lang.org/rustup/dist/x86_64-pc-windows-msvc/rustup-init.exe"
$URL_ERLANG      = "https://github.com/erlang/otp/releases/download/OTP-27.3.4.4/otp_win64_27.3.4.4.zip"
$URL_STACK       = "https://github.com/commercialhaskell/stack/releases/download/v3.7.1/stack-3.7.1-windows-x86_64.zip"
$URL_ELM         = "https://github.com/elm/compiler/releases/download/0.19.1/binary-for-windows-64-bit.gz"
$URL_RLANG       = "https://cran.asnr.fr/bin/windows/base/R-4.5.2-win.exe"
$URL_RREPOS      = "https://pbil.univ-lyon1.fr/CRAN/"
$URL_NODE        = "https://nodejs.org/dist/v24.11.0/node-v24.11.0-win-x64.zip"
$URL_COQ         = "https://github.com/rocq-prover/platform/releases/download/2025.01.0/Coq-Platform-release-2025.01.0-version.8.20.2025.01-Windows-x86_64.exe"

$URL_MESHLAB     = "https://github.com/cnr-isti-vclab/meshlab/releases/download/MeshLab-2025.07/MeshLab2025.07-windows_x86_64.zip"
$URL_DWSIM       = "https://github.com/DanWBR/dwsim/releases/download/v9.0.4/DWSIM_v904_win64_portable.7z"
$URL_FREEFEM     = "https://github.com/FreeFem/FreeFem-sources/releases/download/v4.15/FreeFem++-4.15-b-win64.exe"

$URL_OPENCASCADE = "https://github.com/Open-Cascade-SAS/OCCT/releases/download/V7_9_3/opencascade-7.9.3-vc14-64-combined.zip"
$URL_SU2         = "https://github.com/su2code/SU2/releases/download/v8.4.0/SU2-v8.4.0-win64-mpi.zip"
$URL_FIREMODELS  = "https://github.com/firemodels/fds/releases/download/FDS-6.10.1/FDS-6.10.1_SMV-6.10.1_win.exe"
$URL_RADCAL      = "https://github.com/firemodels/radcal/releases/download/v2.0/radcal_win_64.exe"
$URL_TESSERACT   = "https://github.com/tesseract-ocr/tesseract/releases/download/5.5.0/tesseract-ocr-w64-setup-5.5.0.20241111.exe"
$URL_TESSDATA    = "https://github.com/tesseract-ocr/tessdata_best.git"

$GIT_KOMPANION = "https://github.com/wallytutor/kompanion.git"
$GIT_MAJORDOME = "https://github.com/wallytutor/python-majordome.git"
#endregion: default_config

#region: kompanion
# Global list of environment variable names created by this script
$GLOBAL:KOMPANION_CREATED_ENVS = New-Object System.Collections.ArrayList

function Start-KompanionMain {
    # Fake user profile to avoid applications access:
    Set-KompanionEnvVar -Name "USERPROFILE" `
        -Value "$PSScriptRoot"
    Set-KompanionEnvVar -Name "APPDATA" `
        -Value "$PSScriptRoot\AppData"

    # Path to the root directory:
    Set-KompanionEnvVar -Name "KOMPANION_DIR" `
        -Value "$PSScriptRoot"

    # Path to store user data and configuration:
    Set-KompanionEnvVar -Name "KOMPANION_DOT" `
        -Value "$env:KOMPANION_DIR\.kompanion"

    # Path to automatic subdirectories:
    Set-KompanionEnvVar -Name "KOMPANION_BIN" `
        -Value "$env:KOMPANION_DOT\bin"
    Set-KompanionEnvVar -Name "KOMPANION_LOGS" `
        -Value "$env:KOMPANION_DOT\logs"
    Set-KompanionEnvVar -Name "KOMPANION_TEMP" `
        -Value "$env:KOMPANION_DOT\temp"
    Set-KompanionEnvVar -Name "KOMPANION_REPO" `
        -Value "$env:KOMPANION_DIR\repos"

    Write-Good "> Starting Kompanion from $env:KOMPANION_DIR"

    # Ensure important directories exist:
    Initialize-EnsureDirectory $env:KOMPANION_BIN
    Initialize-EnsureDirectory $env:KOMPANION_LOGS
    Initialize-EnsureDirectory $env:KOMPANION_TEMP
    Initialize-EnsureDirectory $env:KOMPANION_REPO

    # Just so that opening file explored doesn't generate an warning:
    Initialize-EnsureDirectory "$env:KOMPANION_DIR\Desktop"

    # Get configuration of modules:
    $config = Get-ModulesConfig

    # Configure components if needed
    Start-KompanionConfigure $config

    Write-Head "`nEnvironment"
    Write-Head "-----------"
    Write-Output "KOMPANION_DIR       $env:KOMPANION_DIR"
    Write-Output "KOMPANION_BIN       $env:KOMPANION_BIN"
    Write-Output "KOMPANION_LOGS      $env:KOMPANION_LOGS"
    Write-Output "KOMPANION_TEMP      $env:KOMPANION_TEMP"

    Save-KompanionEnvVarsToFile

    # Run Kompanion VS Code instance
    if ($RunVsCode) {
        Code.exe --extensions-dir $env:VSCODE_EXTENSIONS `
                 --user-data-dir  $env:VSCODE_SETTINGS  .
    }
}

function Start-KompanionConfigure {
    param (
        [pscustomobject]$Config
    )

    # Install components if needed
    $lockFile = "$env:KOMPANION_DOT\kompanion.lock"

    Write-Host "`nStarting Kompanion configuration..."

    # XXX: languages come first because some packages might override
    # them (especially Python that is used everywhere).

    Write-Host "- starting Kompanion base configuration..."

    # XXX: this order is important: sometimes SSL blocks downloads that
    # could succeed if done with curl, thus it comes before other tools!
    Invoke-InstallSevenZip
    Invoke-ConfigureSevenZip
    Invoke-ConfigureCurl
    Invoke-InstallVsCode
    Invoke-ConfigureVsCode
    Invoke-InstallGit
    Invoke-ConfigureGit
    Invoke-ConfigureLiteXL

    if ($Config.base.tabby)       { Invoke-ConfigureTabby }

    if ($Config.base.nvim)        { Invoke-InstallNvim }
    if ($Config.base.nvim)        { Invoke-ConfigureNvim }

    if ($Config.base.zettlr)      { Invoke-InstallZettlr }
    if ($Config.base.zettlr)      { Invoke-ConfigureZettlr }

    if ($Config.base.drawio)      { Invoke-ConfigureDrawio }

    if ($Config.base.lessmsi)     { Invoke-InstallLessMsi }
    if ($Config.base.lessmsi)     { Invoke-ConfigureLessMsi }

    if ($Config.base.msys2)       { Invoke-InstallMsys2 }
    if ($Config.base.msys2)       { Invoke-ConfigureMsys2 }

    if ($Config.base.pandoc)      { Invoke-InstallPandoc }
    if ($Config.base.pandoc)      { Invoke-ConfigurePandoc }

    if ($Config.base.jabref)      { Invoke-ConfigureJabRef }

    if ($Config.base.inkscape)    { Invoke-InstallInkscape }
    if ($Config.base.inkscape)    { Invoke-ConfigureInkscape }

    if ($Config.base.miktex)      { Invoke-InstallMikTex }
    if ($Config.base.miktex)      { Invoke-ConfigureMikTex }

    if ($Config.base.ffmpeg)      { Invoke-InstallFfmpeg }
    if ($Config.base.ffmpeg)      { Invoke-ConfigureFfmpeg }

    if ($Config.base.imagemagick) { Invoke-InstallImageMagick }
    if ($Config.base.imagemagick) { Invoke-ConfigureImageMagick }

    if ($Config.base.poppler)     { Invoke-InstallPoppler }
    if ($Config.base.poppler)     { Invoke-ConfigurePoppler }

    if ($Config.base.quarto)      { Invoke-InstallQuarto }
    if ($Config.base.quarto)      { Invoke-ConfigureQuarto }

    Write-Host "- starting Kompanion simulation tools configuration..."

    if ($Config.simu.meshlab)      { Invoke-InstallMeshLab }
    if ($Config.simu.dwsim)        { Invoke-InstallDwsim }
    if ($Config.simu.opencascade)  { Invoke-InstallOpenCascade }

    if ($Config.simu.blender)      { Invoke-ConfigureBlender }
    if ($Config.simu.elmer)        { Invoke-ConfigureElmer }
    if ($Config.simu.freecad)      { Invoke-ConfigureFreeCAD }
    if ($Config.simu.gmsh)         { Invoke-ConfigureGmsh }
    if ($Config.simu.paraview)     { Invoke-ConfigureParaView }
    if ($Config.simu.prepomax)     { Invoke-ConfigurePrePoMax }

    if ($Config.simu.su2)          { Invoke-InstallSu2 }
    if ($Config.simu.su2)          { Invoke-ConfigureSu2 }

    if ($Config.simu.tesseract)    { Invoke-InstallTesseract }
    if ($Config.simu.tesseract)    { Invoke-ConfigureTesseract }

    if ($Config.simu.radcal)       { Invoke-InstallRadcal }
    if ($Config.simu.radcal)       { Invoke-ConfigureRadcal }

    if ($Config.simu.freefem)      { Invoke-InstallFreeFem }
    if ($Config.simu.freefem)      { Invoke-ConfigureFreeFem }

    Write-Host "- starting Kompanion languages configuration..."

    Invoke-InstallPython
    Invoke-ConfigurePython


    if ($Config.lang.rust)    { Invoke-InstallRust }
    if ($Config.lang.rust)    { Invoke-ConfigureRust }

    if ($Config.lang.julia)   { Invoke-ConfigureJulia }

    if ($Config.lang.node)    { Invoke-InstallNode }
    if ($Config.lang.node)    { Invoke-ConfigureNode }

    if ($Config.lang.erlang)  { Invoke-InstallErlang }
    if ($Config.lang.erlang)  { Invoke-ConfigureErlang }

    if ($Config.lang.haskell) { Invoke-InstallHaskell }
    if ($Config.lang.haskell) { Invoke-ConfigureHaskell }

    if ($Config.lang.elm)     { Invoke-InstallElm }
    if ($Config.lang.elm)     { Invoke-ConfigureElm }

    if ($Config.lang.racket)  { Invoke-InstallRacket }
    if ($Config.lang.racket)  { Invoke-ConfigureRacket }

    if ($Config.lang.coq)     { Invoke-InstallCoq }
    if ($Config.lang.coq)     { Invoke-ConfigureCoq }

    if ($Config.lang.rlang)   { Invoke-InstallRlang }
    if ($Config.lang.rlang)   { Invoke-ConfigureRlang }

    # Create lock file to avoid reinstalling everything on
    # next start (unless -RebuildOnStart is used):
    New-Item -ItemType File -Path $lockFile -Force | Out-Null

    # Make sure this is a git repository to allow updates:
    if (-not (Test-Path -Path "$env:KOMPANION_DIR\.git")) {
        Write-Warn "Kompanion downloaded as zip, getting repository..."

        & git clone $GIT_KOMPANION "$env:KOMPANION_REPO\kompanion"

        # Steal the .git folder to make this directory a git repository:
        & Move-Item -Path "$env:KOMPANION_REPO\kompanion\.git" `
            -Destination $env:KOMPANION_DIR

        # Clean up the temporary repository:
        & Remove-Item -Path "$env:KOMPANION_REPO\kompanion" -Recurse

        # This means -> pull to this directory:
        & git pull

        & KompanionRebuild
    }

    if ($NoMajordome) {
        Write-Warn "Skipping Majordome installation as requested..."
    } else {
        if (-not (Test-Path -Path "$env:KOMPANION_REPO\majordome")) {
            & git clone $GIT_MAJORDOME "$env:KOMPANION_REPO\majordome"
        }
    }
}

function Set-KompanionEnvVar {
    param(
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)][string]$Value
    )
    # Set the process environment variable (dynamic name)
    Set-Item -Path ("env:$Name") -Value $Value

    # if (-not ($KOMPANION_CREATED_ENVS.Contains($Name))) {
    #     Write-Good "Creating `$env:$Name = '$Value'"
    # } else {
    #     $val = (Get-Item -Path ("env:$Name")).Value
    #     Write-Warn "Environment variable '$Name' is being overwritten."
    #     Write-Warn "- Previous value: '$val'"
    #     Write-Warn "- New value: '$Value'"
    # }

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

function KompanionSource {
    . "$env:KOMPANION_DIR/kompanion.ps1"
}

function KompanionRebuild {
    . "$env:KOMPANION_DIR/kompanion.ps1" -RebuildOnStart
}

function Kode {
    . "$env:KOMPANION_DIR/kompanion.ps1"

    Code.exe $env:KOMPANION_DIR $PWD.Path `
        --extensions-dir $env:VSCODE_EXTENSIONS `
        --user-data-dir  $env:VSCODE_SETTINGS
}
#endregion: kompanion

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

#region: path
function Test-InPath() {
    param (
        [string]$Directory,
        [string]$Path = $env:Path
    )

    $normalized = $Directory.TrimEnd('\')
    $filtered = ($Path -split ';' | ForEach-Object { $_.TrimEnd('\') })
    return $filtered -contains $normalized
}

function Initialize-EnsureDirectory() {
    param (
        [string]$Path
    )

    if (!(Test-Path -Path $Path)) {
        New-Item -ItemType Directory -Path $Path
    }
}

function Initialize-AddToPath() {
    param (
        [string]$Directory
    )

    if (Test-Path -Path $Directory) {
        if (!(Test-InPath $Directory)) {
            $env:Path = "$Directory;" + $env:Path
        }
    } else {
        Write-Host "Not prepeding missing path to environment: $Directory"
    }
}

function Initialize-AddToManPath() {
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
        Write-Host "Not prepeding missing path to environment: $Directory"
    }
}
#endregion: path

#region: compression
function Invoke-UncompressGzipIfNeeded() {
    param(
        [string]$Source,
        [string]$Destination
    )

    $inputf  = [IO.File]::OpenRead($Source)
    $output = [IO.File]::Create($Destination)

    $what   = [IO.Compression.CompressionMode]::Decompress
    $gzip   = New-Object IO.Compression.GzipStream($inputf, $what)

    $buffer = New-Object byte[] 4096
    while (($read = $gzip.Read($buffer, 0, $buffer.Length)) -gt 0) {
        $output.Write($buffer, 0, $read)
    }

    $gzip.Dispose()
    $output.Dispose()
    $inputf.Dispose()
}

function Invoke-UncompressMsiIfNeeded() {
    param (
        [string]$Source,
        [string]$Destination
    )

    if (!(Test-Path -Path $Destination)) {
        if (Test-Path "$env:LESSMSI_HOME\lessmsi.exe") {
            $lessMsiPath = "$env:LESSMSI_HOME\lessmsi.exe"
        } else {
            $lessMsiPath = "lessmsi.exe"
        }

        Invoke-CapturedCommand $lessMsiPath @("x", $Source , "$Destination\")
    }
}

# ($Method -eq "TAR") {
# New-Item -Path "$Destination" -ItemType Directory
# tar -xzf $Source -C $Destination

#endregion: compression

#region: python
function Check-HasPython {
    try {
        python --version | Out-Null
        return $true
    }
    catch {
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

function Piperish() {
    $PythonPath = $null
    $pipArgs = @()

    for ($i = 0; $i -lt $args.Count; $i++) {
        if ($args[$i] -eq "-PythonPath" -and ($i + 1) -lt $args.Count) {
            $PythonPath = $args[$i + 1]
            $i++  # Skip the next argument
        } else {
            $pipArgs += $args[$i]
        }
    }

    if (-not $PythonPath) {
        $PythonPath = "$env:PYTHON_HOME\python.exe"
    }

    # XXX: Keep for debugging
    # Write-Host "Using Python at: $PythonPath"

    if (-not (Test-Path $PythonPath)) {
        Write-Bad "Required Python not found: $PythonPath..."
        exit 1
    }

    $argList = @("-m", "pip", "--trusted-host", "pypi.org",
                 "--trusted-host", "files.pythonhosted.org")
    $argList += $pipArgs

    # Write-Host "Invoking: $PythonPath $($argList -join ' ')"
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
#endregion: python

#region: modules
function Get-ModulesConfig() {
    $path = "$env:KOMPANION_DOT\kompanion.json"

    if (Test-Path -Path $path) {
        Write-Host "Using user-defined configuration..."
        return Get-Content -Path $path -Raw | ConvertFrom-Json
    }

    return $DEFAULT_CONFIG
}

function Enable-Module() {
    # Change key in kompanion.json
    Write-Host "Sorry, WIP..."
}

function Show-ModuleList() {
    Write-Host "Sorry, WIP..."
}
#endregion: modules

#region: utils_other
function Invoke-DirectoryBackupNoAdmin() {
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
        Can be a single extension (e.g., "*.txt") or an array (e.g., "*.txt", "*.csv").
        If not specified, all files will be processed.

    .PARAMETER DryRun
        When specified, shows what files would be renamed without actually renaming them.
        Useful for previewing changes before executing.

    .EXAMPLE
        Rename-FilesToStandard -DryRun
        Preview what files in the current directory would be renamed.

    .EXAMPLE
        Rename-FilesToStandard -Path "C:\Data" -DryRun
        Preview what files in C:\Data would be renamed.

    .EXAMPLE
        Rename-FilesToStandard -Filter "*.txt" -DryRun
        Preview what text files would be renamed.

    .EXAMPLE
        Rename-FilesToStandard -Filter "*.txt", "*.csv" -DryRun
        Preview what text and CSV files would be renamed.

    .EXAMPLE
        Rename-FilesToStandard
        Rename all files in the current directory.

    .EXAMPLE
        Rename-FilesToStandard -Path "C:\Data"
        Rename all files in C:\Data and its subdirectories.
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

        # Normalize accented characters to ASCII equivalents
        $normalizedBaseName = $baseName.Normalize([Text.NormalizationForm]::FormD)
        $asciiBaseName = $normalizedBaseName -replace '\p{M}', ''

        # Replace non-alphanumeric characters and convert to lowercase
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
#endregion: utils_other

#region: install_configure_base
function Invoke-ConfigureVsCode {
    Write-Head "* Configuring Visual Studio Code..."

    Set-KompanionEnvVar -Name "VSCODE_HOME" `
        -Value "$env:KOMPANION_BIN\vscode"
    Set-KompanionEnvVar -Name "VSCODE_EXTENSIONS" `
        -Value "$env:KOMPANION_DIR\.vscode\extensions"
    Set-KompanionEnvVar -Name "VSCODE_SETTINGS" `
        -Value "$env:KOMPANION_DIR\.vscode\user-data"

    Initialize-AddToPath -Directory "$env:VSCODE_HOME"
}

function Invoke-InstallVsCode {
    $output = "$env:KOMPANION_TEMP\vscode.zip"
    $path   = "$env:KOMPANION_BIN\vscode"
    $url    = $URL_VSCODE

    if (Test-Path -Path $path) { return }

    Invoke-DownloadIfNeeded -URL $url -Output $output
    Invoke-UncompressZipIfNeeded -Source $output -Destination $path
    Invoke-ConfigureVsCode
}

function Invoke-ConfigureGit {
    Write-Head "* Configuring Git..."

    Set-KompanionEnvVar -Name "GIT_HOME" `
        -Value "$env:KOMPANION_BIN\git"

    Initialize-AddToPath -Directory "$env:GIT_HOME\cmd"
}

function Invoke-InstallGit {
    $output = "$env:KOMPANION_TEMP\git.exe  "
    $path   = "$env:KOMPANION_BIN\git"
    $url    = $URL_GIT

    if (Test-Path -Path $path) { return }

    Invoke-DownloadIfNeeded -URL $url -Output $output
    Invoke-CapturedCommand $output @("-y", "-o$path")
    Invoke-ConfigureGit
}

function Invoke-ConfigureSevenZip {
    Write-Head "* Configuring 7-Zip..."

    Set-KompanionEnvVar -Name "SEVENZIP_HOME" `
        -Value "$env:KOMPANION_BIN\7z"

    Initialize-AddToPath -Directory "$env:SEVENZIP_HOME"

    # Legacy: prefer the one from stack if available:
    # $stackSevenZip = "$env:STACK_ROOT\local-programs\x86_64-windows"
    #
    # if (Test-Path $stackSevenZip) {
    #     $env:SEVENZIP_HOME = $stackSevenZip
    #     Initialize-AddToPath -Directory "$env:SEVENZIP_HOME"
    # } else {
    #     $env:SEVENZIP_HOME = "$env:KOMPANION_BIN"
    #     Initialize-AddToPath -Directory "$env:SEVENZIP_HOME"
    # }
}

function Invoke-InstallSevenZip {
    # Legacy: use full 7zip (from stackage) instead of 7zr!
    # $output = "$env:KOMPANION_TEMP\7zr.exe"
    # $path   = "$env:KOMPANION_BIN\7zr.exe"
    # $url    = "https://github.com/ip7z/7zip/releases/download/25.01/7zr.exe"

    $temp   = "$env:KOMPANION_TEMP\7z"
    $path   = "$env:KOMPANION_BIN\7z"

    if (Test-Path -Path $path) { return }

    if (!(Test-Path -Path $temp)) {
        New-Item -Path $temp -ItemType Directory | Out-Null
    }

    $dl = $URL_SEVENZIP
    $files = @("7z.dll", "7z.exe", "License.txt", "readme.txt")

    foreach ($file in $files) {
        $url    = "$dl$file"
        $output = "$temp\$file"
        Invoke-DownloadIfNeeded -URL $url -Output $output
    }

    Move-Item -Path $temp -Destination $path
    Invoke-ConfigureSevenZip
}

function Invoke-ConfigureLessMsi {
    Write-Head "* Configuring lessmsi..."

    Set-KompanionEnvVar -Name "LESSMSI_HOME" `
        -Value "$env:KOMPANION_BIN\lessmsi"

    Initialize-AddToPath -Directory "$env:LESSMSI_HOME"
}

function Invoke-InstallLessMsi {
    $output = "$env:KOMPANION_TEMP\lessmsi.zip"
    $path   = "$env:KOMPANION_BIN\lessmsi"
    $url    = $URL_LESSMSI

    if (Test-Path -Path $path) { return }

    Invoke-DownloadIfNeeded -URL $url -Output $output
    Invoke-UncompressZipIfNeeded -Source $output -Destination $path
    Invoke-ConfigureLessMsi
}

function Invoke-ConfigurePandoc {
    Write-Head "* Configuring Pandoc..."

    Set-KompanionEnvVar -Name "PANDOC_HOME" `
         -Value "$env:KOMPANION_BIN\pandoc\pandoc-3.8"

    Initialize-AddToPath -Directory "$env:PANDOC_HOME"
}

function Invoke-InstallPandoc {
    $output = "$env:KOMPANION_TEMP\pandoc.zip"
    $path   = "$env:KOMPANION_BIN\pandoc"
    $url    = $URL_PANDOC

    if (Test-Path -Path $path) { return }

    Invoke-DownloadIfNeeded -URL $url -Output $output
    Invoke-UncompressZipIfNeeded -Source $output -Destination $path
    Invoke-ConfigurePandoc
}

function Invoke-ConfigurePoppler {
    Write-Head "* Configuring Poppler..."

    Set-KompanionEnvVar -Name "POPLER_HOME" `
         -Value "$env:KOMPANION_BIN\poppler\poppler-25.11.0\Library"

    Initialize-AddToPath -Directory "$env:POPLER_HOME\bin"
    Initialize-AddToManPath -Directory "$env:POPLER_HOME\share\man"
}

function Invoke-InstallPoppler {
    $output = "$env:KOMPANION_TEMP\poppler.zip"
    $path   = "$env:KOMPANION_BIN\poppler"
    $url    = $URL_POPPLER

    if (Test-Path -Path $path) { return }

    Invoke-DownloadIfNeeded -URL $url -Output $output
    Invoke-UncompressZipIfNeeded -Source $output -Destination $path
    Invoke-ConfigurePoppler
}

function Invoke-ConfigureQuarto {
    Write-Head "* Configuring Quarto..."

    Set-KompanionEnvVar -Name "QUARTO_HOME" `
        -Value "$env:KOMPANION_BIN\quarto"

    Initialize-AddToPath -Directory "$env:QUARTO_HOME\bin"
}

function Invoke-InstallQuarto {
    $output = "$env:KOMPANION_TEMP\quarto.zip"
    $path   = "$env:KOMPANION_BIN\quarto"
    $url    = $URL_QUARTO

    if (Test-Path -Path $path) { return }

    Invoke-DownloadIfNeeded -URL $url -Output $output
    Invoke-UncompressZipIfNeeded -Source $output -Destination $path
    Invoke-ConfigureQuarto

    & quarto install tinytex
}

function Invoke-ConfigureZettlr {
    Write-Head "* Configuring Zettlr..."

    Set-KompanionEnvVar -Name "ZETTLR_HOME" `
        -Value "$env:KOMPANION_BIN\zettlr"

    Set-KompanionEnvVar -Name "ZETTLR_DATA" `
        -Value "$env:KOMPANION_DIR\.zettlr"

    Initialize-AddToPath -Directory "$env:ZETTLR_HOME"
}

function Invoke-InstallZettlr {
    $output = "$env:KOMPANION_TEMP\zettlr.exe"
    $temp   = "$env:KOMPANION_TEMP\zettlr_tmp"
    $path   = "$env:KOMPANION_BIN\zettlr"
    $url    = $URL_ZETTLR

    if (Test-Path -Path $path) { return }

    Invoke-DownloadIfNeeded -URL $url -Output $output

    $app = Join-Path $temp '$PLUGINSDIR\app-64.7z'
    Invoke-Uncompress7zIfNeeded -Source $output -Destination $temp
    Invoke-Uncompress7zIfNeeded -Source $app    -Destination $path

    Remove-Item -Path $temp -Recurse -Force
    Invoke-ConfigureZettlr
}

function Invoke-ConfigureNvim {
    Write-Head "* Configuring Neovim..."

    Set-KompanionEnvVar -Name "NVIM_HOME" `
        -Value "$env:KOMPANION_BIN\nvim\nvim-win64"

    Initialize-AddToPath -Directory "$env:NVIM_HOME\bin"
}

function Invoke-InstallNvim {
    $output = "$env:KOMPANION_TEMP\nvim.zip"
    $path   = "$env:KOMPANION_BIN\nvim"
    $url    = $URL_NVIM

    if (Test-Path -Path $path) { return }

    Invoke-DownloadIfNeeded -URL $url -Output $output
    Invoke-UncompressZipIfNeeded -Source $output -Destination $path
    Invoke-ConfigureNvim
}

function Invoke-ConfigureMsys2 {
    # TODO once MSYS2 is installed!
}

function Invoke-InstallMsys2 {
    Write-Host "- installing MSYS2 (not yet implemented)..."
    # $output = Get-KompanionPath $$config.install.msys2.saveAs
    # $path   = Get-KompanionPath $$config.install.msys2.path
    # Invoke-DownloadIfNeeded -URL $$config.install.msys2.URL -Output $output

    # if (Test-Path -Path $path) {
    #     Write-Host "Skipping extraction of $output..."
    # } else {
    #     Write-Host "Expanding $output into $path"
    #     $argList = @("in", "--confirm-command", "--accept-messages"
    #                  "--root", "$path")
    #     Invoke-CapturedCommand $output $argList
    # }

    # $bash = Get-KompanionPath "bin\msys2\usr\bin\bash"
    # $argList = @("-lc", "'pacman -Syu --noconfirm'")
    # $argList = @("-lc", "'pacman -Su --noconfirm'")
    # bin\msys2\usr\bin\bash -lc "pacman -Syu --noconfirm"
    # bin\msys2\usr\bin\bash -lc "pacman -Su --noconfirm"
    # pacman-key --init && pacman-key --populate msys2
    # pacman -Syuu && pacman -S bash coreutils make gcc p7zip
    # pacman -Sy --noconfirm; pacman -S --noconfirm p7zip
    Invoke-ConfigureMsys2
}

function Invoke-ConfigureInkscape {
    Write-Head "* Configuring Inkscape..."

    Set-KompanionEnvVar -Name "INKSCAPE_HOME" `
        -Value "$env:KOMPANION_BIN\inkscape\inkscape"

    Initialize-AddToPath -Directory "$env:INKSCAPE_HOME\bin"
}

function Invoke-InstallInkscape {
    $output = "$env:KOMPANION_TEMP\inkscape.7z"
    $path   = "$env:KOMPANION_BIN\inkscape"
    $url    = $URL_INKSCAPE

    if (Test-Path -Path $path) { return }

    Invoke-DownloadIfNeeded -URL $url -Output $output
    Invoke-Uncompress7zIfNeeded -Source $output -Destination $path
    Invoke-ConfigureInkscape
}

function Invoke-ConfigureMikTex {
    Write-Head "* Configuring MikTex..."

    Set-KompanionEnvVar -Name "MIKTEX_HOME" `
         -Value "$env:KOMPANION_BIN\miktex"

    Initialize-AddToPath -Directory "$env:MIKTEX_HOME"

    $path = "$env:MIKTEX_HOME\miktex-portable.cmd"

    if (Test-Path -Path $path) {
        $isMikTexConsoleRunning = @(
            Get-Process -Name "miktex-console" -ErrorAction SilentlyContinue
        ).Count -gt 0

        $isPortableCmdRunning = @(
            Get-CimInstance Win32_Process -Filter "Name='cmd.exe'" -ErrorAction SilentlyContinue |
            Where-Object { $_.CommandLine -like "*miktex-portable.cmd*" }
        ).Count -gt 0

        if (-not ($isMikTexConsoleRunning -or $isPortableCmdRunning)) {
            Start-Process -FilePath $path -NoNewWindow
        }
    }

    Initialize-AddToPath -Directory "$env:MIKTEX_HOME\texmfs\install\miktex\bin\x64\internal"
    Initialize-AddToPath -Directory "$env:MIKTEX_HOME\texmfs\install\miktex\bin\x64"
}

function Invoke-InstallMikTex {
    $output  = "$env:KOMPANION_TEMP\miktexsetup.zip"
    $path    = "$env:KOMPANION_BIN\miktexsetup"
    $url     = $URL_MIKTEX
    $miktex  = "$env:KOMPANION_BIN\miktex"

    if ((Test-Path -Path $path) -and (Test-Path -Path $miktex)) { return }

    Invoke-DownloadIfNeeded -URL $url -Output $output
    Invoke-UncompressZipIfNeeded -Source $output -Destination $path

    $path = "$path\miktexsetup_standalone.exe"
    $pkgData = "$env:KOMPANION_DIR\.miktex"

    if (!(Test-Path -Path $pkgData)) {
        Write-Host "Downloading MikTex data to $pkgData"
        $argList = @("download", "--package-set", "basic",
                     "--local-package-repository", $pkgData)
        Invoke-CapturedCommand $path $argList
    }

    if (!(Test-Path -Path $miktex)) {
        Write-Host "Installing MikTex data to $miktex"
        $argList = @("install", "--package-set", "basic",
                    "--local-package-repository", $pkgData,
                    "--portable", $miktex)
        Invoke-CapturedCommand $path $argList
    }

    Write-Warn "Please, consider manually removing $pkgData if succeeded"
    Invoke-ConfigureMikTex
}

function Invoke-ConfigureNteract {
    Write-Head "* Configuring nteract..."

    Set-KompanionEnvVar -Name "NTERACT_HOME" `
         -Value "$env:KOMPANION_BIN\nteract"

    Initialize-AddToPath -Directory "$env:NTERACT_HOME"
}

function Invoke-InstallNteract {
    $output = "$env:KOMPANION_TEMP\nteract.zip"
    $path   = "$env:KOMPANION_BIN\nteract"
    $url    = $URL_NTERACT

    if (Test-Path -Path $path) { return }

    Invoke-DownloadIfNeeded -URL $url -Output $output
    Invoke-UncompressZipIfNeeded -Source $output -Destination $path
    Invoke-ConfigureNteract
}

function Invoke-ConfigureFfmpeg {
    Write-Head "* Configuring ffmpeg..."

    Set-KompanionEnvVar -Name "FFMPEG_HOME" `
         -Value "$env:KOMPANION_BIN\ffmpeg"

    Initialize-AddToPath -Directory "$env:FFMPEG_HOME\bin"
}

function Invoke-InstallFfmpeg {
    $output = "$env:KOMPANION_TEMP\ffmpeg.7z"
    $temp   = "$env:KOMPANION_TEMP\ffmpeg"
    $path   = "$env:KOMPANION_BIN\ffmpeg"
    $url    = $URL_FFMPEG

    if (Test-Path -Path $path) { return }

    Invoke-DownloadIfNeeded -URL $url -Output $output
    Invoke-Uncompress7zIfNeeded -Source $output -Destination $temp

    Move-Item -Path (Join-Path $temp "ffmpeg-*") -Destination $path
    Remove-Item -Path $temp -Recurse -Force
    Invoke-ConfigureFfmpeg
}

function Invoke-ConfigureImageMagick {
    Write-Head "* Configuring ImageMagick..."

    Set-KompanionEnvVar -Name "IMAGEMAGICK_HOME" `
         -Value "$env:KOMPANION_BIN\imagemagick"

    Initialize-AddToPath -Directory "$env:IMAGEMAGICK_HOME"
}

function Invoke-InstallImageMagick {
    $output = "$env:KOMPANION_TEMP\imagemagick.zip"
    $path   = "$env:KOMPANION_BIN\imagemagick"
    $url    = $URL_IMAGEMAGICK

    if (Test-Path -Path $path) { return }

    Invoke-DownloadIfNeeded -URL $url -Output $output
    Invoke-Uncompress7zIfNeeded -Source $output -Destination $path
    Invoke-ConfigureImageMagick
}
#endregion: install_configure_base

#region: install_configure_lang
function Invoke-ConfigurePython() {
    Write-Head "* Configuring Python..."

    Set-KompanionEnvVar -Name "PYTHON_HOME" `
        -Value "$env:KOMPANION_BIN\python\WPy64-31380\python"

    Initialize-AddToPath -Directory "$env:PYTHON_HOME\Scripts"
    Initialize-AddToPath -Directory "$env:PYTHON_HOME"

    # Path to IPython profiles, history, etc.:
    Set-KompanionEnvVar -Name "IPYTHONDIR" `
         -Value "$env:KOMPANION_DIR\.ipython"

    # Jupyter to be used with IJulia (if any) and data path:
    Set-KompanionEnvVar -Name "JUPYTER" `
         -Value "$env:PYTHON_HOME\Scripts\jupyter.exe"

    # Path to Jupyter kernels, etc.:
    Set-KompanionEnvVar -Name "JUPYTER_DATA_DIR" `
         -Value "$env:KOMPANION_DIR\.jupyter"

    # This is required for nteract to work:
    Set-KompanionEnvVar -Name "JUPYTER_PATH" `
         -Value "$env:JUPYTER_DATA_DIR"

    # Point quarto to the right python:
    Set-KompanionEnvVar -Name "QUARTO_PYTHON" `
         -Value "$env:PYTHON_HOME\python.exe"

    # Install minimal requirements:
    $lockFile = "$env:KOMPANION_DOT\python.lock"

    # Ignore deps if requested:
    if ($NoPythonDeps) {
        New-Item -ItemType File -Path $lockFile -Force | Out-Null
    }

    # Note: manually remove lock file if no deps installed at first:
    if (!(Test-Path $lockFile)) {
        Piperish install --upgrade pip
        Piperish install -r "$env:KOMPANION_DOT\requirements.txt"

        # This used to be majordome, do not install by default!
        # Piperish install -e "$env:KOMPANION_DIR"

        New-Item -ItemType File -Path $lockFile -Force | Out-Null
    }
}

function Invoke-InstallPython() {
    $output = "$env:KOMPANION_TEMP\python.zip"
    $path   = "$env:KOMPANION_BIN\python"
    $url    = $URL_PYTHON

    if (Test-Path -Path $path) { return }

    Invoke-DownloadIfNeeded -URL $url -Output $output
    Invoke-UncompressZipIfNeeded -Source $output -Destination $path
}

function Invoke-ConfigureRust() {
    Write-Head "* Configuring Rust..."

    Set-KompanionEnvVar -Name "CARGO_HOME" `
        -Value "$env:KOMPANION_DIR\.cargo"

    Set-KompanionEnvVar -Name "RUSTUP_HOME" `
        -Value "$env:KOMPANION_DIR\.cargo"

    Initialize-AddToPath -Directory "$env:CARGO_HOME\bin"

    # XXX: disable certificate revocation check due to possible issues
    # with certain Windows configurations (corporate networks, proxies, etc.)
    # Avoid using this in general, as it lowers security!
    Set-KompanionEnvVar -Name "CARGO_HTTP_CHECK_REVOKE" -Value "false"
}

function Invoke-InstallRust() {
    $output = "$env:KOMPANION_TEMP\rustup-init.exe"
    $path   = "$env:KOMPANION_DIR\.cargo\bin"

    # Choose one of the following URLs depending on the desired toolchain
    # notice that MSVC requires Visual Studio Build Tools to be installed
    # $url    = $URL_RUST_MSVC
    $url    = $URL_RUST_GNU

    if (Test-Path -Path $path) { return }

    Invoke-DownloadIfNeeded -URL $url -Output $output

    if (-not (Test-Path $path)) {


        $arglist = @(
            "--verbose",
            "-y",
            "--default-host",      $DEFAULT_RUST_INSTALL.triple,
            "--default-toolchain", $DEFAULT_RUST_INSTALL.toolchain,
            "--profile",           $DEFAULT_RUST_INSTALL.profile,
            "--no-modify-path"
        )

        Set-KompanionEnvVar -Name "CARGO_HOME" `
            -Value "$env:KOMPANION_DIR\.cargo"

        Set-KompanionEnvVar -Name "RUSTUP_HOME" `
            -Value "$env:KOMPANION_DIR\.cargo"

        Invoke-CapturedCommand -FilePath $output -ArgumentList $arglist -Wait
    }
}

function Invoke-ConfigureErlang() {
    Write-Head "* Configuring Erlang..."

    Set-KompanionEnvVar -Name "ERLANG_HOME" `
         -Value "$env:KOMPANION_BIN\erlang"

    Initialize-AddToPath -Directory "$env:ERLANG_HOME\bin"
}

function Invoke-InstallErlang() {
    $output = "$env:KOMPANION_TEMP\erlang.zip"
    $path   = "$env:KOMPANION_BIN\erlang"
    $url    = $URL_ERLANG

    if (Test-Path -Path $path) { return }

    Invoke-DownloadIfNeeded -URL $url -Output $output
    Invoke-UncompressZipIfNeeded -Source $output -Destination $path
}

function Invoke-ConfigureHaskell() {
    Write-Head "* Configuring Haskell..."

    Set-KompanionEnvVar -Name "STACK_HOME" `
         -Value "$env:KOMPANION_BIN\stack"

    Set-KompanionEnvVar -Name "STACK_ROOT" `
         -Value "$env:KOMPANION_DIR\.stack"

    Initialize-AddToPath -Directory "$env:KOMPANION_BIN\stack"

    # Install minimal requirements:
    $lockFile = "$env:KOMPANION_DOT\haskell.lock"

    if (!(Test-Path $lockFile)) {
        $stackPath = "$env:STACK_HOME\stack.exe"
        Invoke-CapturedCommand $stackPath @("setup")

        $content = Get-Content -Raw -Path "$env:KOMPANION_DOT\stack-config.yaml"
        $content = $content -replace '__STACK_ROOT__', $env:STACK_ROOT
        Set-Content -Path "$env:STACK_ROOT\config.yaml" -Value $content

        # TODO test if this automates install:
        # Invoke-CapturedCommand "stack ghci"
        New-Item -ItemType File -Path $lockFile -Force | Out-Null
    }
}

function Invoke-InstallHaskell() {
    $output = "$env:KOMPANION_TEMP\stack.zip"
    $path   = "$env:KOMPANION_BIN\stack"
    $url    = $URL_STACK

    if (Test-Path -Path $path) { return }

    Invoke-DownloadIfNeeded -URL $url -Output $output
    Invoke-UncompressZipIfNeeded -Source $output -Destination $path
    # You still need to run "stack ghci" to get the compiler!
}

function Invoke-ConfigureElm() {
    # Elm is at root, no special configuration needed.
}

function Invoke-InstallElm() {
    $output = "$env:KOMPANION_TEMP\elm.gz"
    $path   = "$env:KOMPANION_BIN\elm.exe"
    $url    = $URL_ELM

    if (Test-Path -Path $path) { return }

    Invoke-DownloadIfNeeded -URL $url -Output $output
    Invoke-UncompressGzipIfNeeded -Source $output -Destination $path
}

function Invoke-ConfigureRlang() {
    Write-Head "* Configuring R..."

    Set-KompanionEnvVar -Name "RLANG_HOME" `
         -Value "$env:KOMPANION_BIN\rlang"

    Initialize-AddToPath -Directory "$env:RLANG_HOME\bin\x64"

    # Path to R libraries
    Set-KompanionEnvVar -Name "R_LIBS_USER" `
         -Value "$env:KOMPANION_DIR\.rlang\4.5"

    # Install minimal requirements:
    $lockFile = "$env:KOMPANION_DOT\rlang.lock"

    if (!(Test-Path $lockFile)) {
        $rscriptPath = "$env:RLANG_HOME\bin\x64\Rscript.exe"

        $installCmd = "install.packages('tidyverse', repos='$URL_RREPOS')"
        Invoke-CapturedCommand $rscriptPath @("-e", $installCmd)

        $installCmd = "install.packages('IRkernel', repos='$URL_RREPOS')"
        Invoke-CapturedCommand $rscriptPath @("-e", $installCmd)

        # Register IRkernel
        $registerCmd = "IRkernel::installspec(user = FALSE)"
        Invoke-CapturedCommand $rscriptPath @("-e", $registerCmd)

        New-Item -ItemType File -Path $lockFile -Force | Out-Null
    }
}

function Invoke-InstallRlang() {
    $output = "$env:KOMPANION_TEMP\R-4.5.2-win.exe"
    $path   = "$env:KOMPANION_BIN\rlang"
    $url    = $URL_RLANG

    if (Test-Path -Path $path) { return }

    Invoke-DownloadIfNeeded -URL $url -Output $output

    if (-not (Test-Path $path)) {
        $arglist = @(
            "/VERYSILENT",
            "/SUPPRESSMSGBOXES",
            "/NORESTART",
            "/DIR=$path"
        )

        Start-Process -FilePath $output -ArgumentList $arglist -Wait
    }
}

function Invoke-ConfigureNode() {
    Write-Head "* Configuring Node.js..."

    Set-KompanionEnvVar -Name "NODE_HOME" `
         -Value "$env:KOMPANION_BIN\node\node-v24.11.0-win-x64"

    Initialize-AddToPath -Directory "$env:NODE_HOME"
}

function Invoke-InstallNode() {
    $output = "$env:KOMPANION_TEMP\node.zip"
    $path   = "$env:KOMPANION_BIN\node"

    if (Test-Path -Path $path) { return }

    Invoke-DownloadIfNeeded -URL $URL_NODE -Output $output
    Invoke-UncompressZipIfNeeded -Source $output -Destination $path
}

function Invoke-ConfigureRacket() {
    # $env:RACKET_HOME = "$env:KOMPANION_BIN\racket"
    # Initialize-AddToPath -Directory "$env:RACKET_HOME\bin"
    # $env:PLTUSERHOME     = "$env:KOMPANION_DIR\.racket"
    # $env:PLT_PKGDIR      = "$env:PLTUSERHOME\Racket\8.18\pkgs"
}

function Invoke-InstallRacket() {
    Write-Host "- Racket installation not yet implemented."
}

function Invoke-ConfigureCoq() {
    Write-Head "* Configuring Coq..."

    Set-KompanionEnvVar -Name "COQ_HOME" `
         -Value "$env:KOMPANION_BIN\coq"

    Initialize-AddToPath -Directory "$env:COQ_HOME\bin"
}

function Invoke-InstallCoq() {
    $output = "$env:KOMPANION_TEMP\coq.zip"
    $path   = "$env:KOMPANION_BIN\coq"

    if (Test-Path -Path $path) { return }

    Invoke-DownloadIfNeeded -URL $URL_COQ -Output $output
    Invoke-Uncompress7zIfNeeded -Source $output -Destination $path

    $target = Join-Path $path '$PLUGINSDIR'
    if (Test-Path $target) { Remove-Item $target -Recurse -Force }

    $target = Join-Path $path 'Uninstall.exe.nsis'
    if (Test-Path $target) { Remove-Item $target }
}
#endregion: install_configure_lang

#region: install_configure_sim_nonconf
function Invoke-InstallMeshLab {
    $output = "$env:KOMPANION_TEMP\meshlab.zip"
    $path   = "$env:KOMPANION_BIN\meshlab"
    $url    = $URL_MESHLAB

    if (Test-Path -Path $path) { return }

    Invoke-DownloadIfNeeded -URL $url -Output $output
    Invoke-UncompressZipIfNeeded -Source $output -Destination $path
}

function Invoke-InstallDwsim {
    $output = "$env:KOMPANION_TEMP\dwsim.zip"
    $path   = "$env:KOMPANION_BIN\dwsim"
    $url    = $URL_DWSIM

    if (Test-Path -Path $path) { return }

    Invoke-DownloadIfNeeded -URL $url -Output $output
    Invoke-Uncompress7zIfNeeded -Source $output -Destination $path
}

function Invoke-InstallOpenCascade {
    $output = "$env:KOMPANION_TEMP\opencascade.zip"
    $path   = "$env:KOMPANION_BIN\opencascade"
    $url    = $URL_OPENCASCADE

    if (Test-Path -Path $path) { return }

    Invoke-DownloadIfNeeded -URL $url -Output $output
    Invoke-UncompressZipIfNeeded -Source $output -Destination $path
}
#endregion: install_configure_sim_nonconf

#region: install_configure_sim_conf
function Invoke-ConfigureSu2 {
    Write-Head "* Configuring SU2..."

    Set-KompanionEnvVar -Name "SU2_HOME" `
         -Value "$env:KOMPANION_BIN\su2"

    Initialize-AddToPath -Directory "$env:SU2_HOME\bin"
    # TODO add to PYTHONPATH;JULIA_LOAD_PATH
}

function Invoke-InstallSu2 {
    $output = "$env:KOMPANION_TEMP\su2.zip"
    $path   = "$env:KOMPANION_TEMP\su2"
    $url    = $URL_SU2

    # XXX: there is a second file inside it! Check!
    $innerOutput = "$env:KOMPANION_TEMP\su2\win64-mpi.zip"
    $finalPath   = "$env:KOMPANION_BIN\su2"

    if (Test-Path -Path $finalPath) { return }

    Invoke-DownloadIfNeeded -URL $url -Output $output
    Invoke-UncompressZipIfNeeded -Source $output      -Destination $path
    Invoke-UncompressZipIfNeeded -Source $innerOutput -Destination $finalPath
    Remove-Item -Path $path -Recurse -Force

    Invoke-ConfigureSu2
}

function Invoke-ConfigureRadcal {
    Write-Head "* Configuring Radcal..."

    Set-KompanionEnvVar -Name "FIREMODELS_HOME" `
         -Value "$env:KOMPANION_BIN\firemodels"

    Initialize-AddToPath -Directory "$env:FIREMODELS_HOME\FDS6\bin"
    Initialize-AddToPath -Directory "$env:FIREMODELS_HOME\SMV6"
    Initialize-AddToPath -Directory "$env:FIREMODELS_HOME"
}

function Invoke-InstallRadcal {
    $output = "$env:KOMPANION_TEMP\fds_smv.exe"
    $temp   = "$env:KOMPANION_TEMP\fds_smv"
    $path   = "$env:KOMPANION_BIN\firemodels"
    $url    = $URL_FIREMODELS

    if (Test-Path -Path $path) { return }

    Invoke-DownloadIfNeeded -URL $url -Output $output
    Invoke-Uncompress7zIfNeeded -Source $output -Destination $temp

    Move-Item -Path "$temp\firemodels" -Destination $path
    Remove-Item -Path $temp -Recurse -Force

    $output = "$path\radcal.exe"
    $url    = $URL_RADCAL
    Invoke-DownloadIfNeeded -URL $url -Output $output

    Invoke-ConfigureRadcal
}

function Invoke-ConfigureTesseract {
    Write-Head "* Configuring Tesseract..."

    Set-KompanionEnvVar -Name "TESSERACT_HOME" `
         -Value "$env:KOMPANION_BIN\tesseract"

    Set-KompanionEnvVar -Name "TESSDATA_PREFIX" `
         -Value "$env:KOMPANION_BIN\tessdata"

    Initialize-AddToPath -Directory "$env:TESSERACT_HOME"
}

function Invoke-InstallTesseract {
    $output = "$env:KOMPANION_TEMP\tesseract.exe"
    $path   = "$env:KOMPANION_BIN\tesseract"
    $url    = $URL_TESSERACT

    if (Test-Path -Path $path) { return }

    Invoke-DownloadIfNeeded -URL $url -Output $output
    Invoke-Uncompress7zIfNeeded -Source $output -Destination $path

    $target = Join-Path $path '$PLUGINSDIR'
    if (Test-Path $target) { Remove-Item $target -Recurse -Force }

    $path = "$env:KOMPANION_BIN\tessdata"

    if (-not (Test-Path "$path")) {
        git clone $URL_TESSDATA "$path"
    }

    Invoke-ConfigureTesseract
}
#endregion: install_configure_sim_conf

#region: install_configure_sim_wip
function Invoke-ConfigureFreeFem {
    # $env:FREEFEM_HOME = "$env:KOMPANION_BIN\freefem"
    # Initialize-AddToPath -Directory "$env:FREEFEM_HOME"
    # # TODO add to PYTHONPATH;JULIA_LOAD_PATH
}

function Invoke-InstallFreeFem {
    $output = "$env:KOMPANION_TEMP\freefem.exe"
    $path   = "$env:KOMPANION_BIN\freefem"

    if (Test-Path -Path $path) { return }

    Invoke-DownloadIfNeeded -URL $URL_FREEFEM -Output $output
    # Invoke-UncompressZipIfNeeded -Source $output -Destination $path
    Invoke-ConfigureFreeFem
}
#endregion: install_configure_sim_wip

#region: main
Start-KompanionMain

# Source user-defined aliases at script level so they persist in terminal:
if (Test-Path -Path "$env:KOMPANION_DOT\aliases.ps1") {
    Write-Good "`n> Loading user-defined aliases"
    . "$env:KOMPANION_DOT\aliases.ps1"
}

# Get a simpler prompt:
function prompt {
    $leaf = Split-Path -Leaf (Get-Location)
    Write-Host "kompanion:$leaf" -ForegroundColor Cyan -NoNewline
    return "> "
}
#endregion: main