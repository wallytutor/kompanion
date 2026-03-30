$KOMPANION_DEBUG = $false

#region: utilities
function Read-Json {
    param (
        [Parameter(Mandatory, Position=0)]
        [string]$Path
    )

    Get-Content -Path $Path -Raw | ConvertFrom-Json
}

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

function Get-PackageVersionedUrl {
    param (
        [Parameter(Mandatory, Position=0)]
        [string]$Name
    )
    $baseUrl = $KOMPANION_SETUP.url.$Name
    $version = $KOMPANION_SETUP.version.$Name

    if ([string]::IsNullOrWhiteSpace($baseUrl)) {
        throw "Base URL for package '$Name' not found in configuration."
    }

    # TODO handle version = {major, minor} and other formats:
    $fullUrl = if ([string]::IsNullOrWhiteSpace($version)) {
        Write-Warn "* Version for package '$Name' not found in configuration."
        $baseUrl
    } else {
        $baseUrl -f $version
    }

    return $fullUrl
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

    Get-Content $logOut | Add-Content "$env:KOMPANION_LOGS\kompanion.log"
    Remove-Item $logOut -ErrorAction SilentlyContinue

    Get-Content $logErr | Add-Content "$env:KOMPANION_LOGS\kompanion.err"
    Remove-Item $logErr -ErrorAction SilentlyContinue

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

    try {
        $success = ($(Invoke-CapturedCommand "curl.exe" $opts) -eq 0)
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

    # curl.exe
    if (-not $success) {
        $success = Invoke-DownloadCurl $URL $Output
    }

    # curl.exe -insecure
    if (-not $success) {
        $success = Invoke-DownloadCurl $URL $Output -Insecure
    }

    # Start-BitsTransfer
    if (-not $success) {
        try {
            # XXX: -ErrorAction Stop is required to catch errors
            Start-BitsTransfer -Source $URL -Destination $Output -ErrorAction Stop
            $success = $true
        } catch {
            Write-Bad "Failed to download $URL as $Output (Start-BitsTransfer)"
            $success = $false
        }
    }

    # Invoke-WebRequest
    if (-not $success) {
        try {
            # XXX: -ErrorAction Stop is required to catch errors
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
            Invoke-CapturedCommand $SevenZipPath @("x", $Source , "-o$Destination")
        } catch {
            Write-Bad "Failed to expand $Source into $Destination : $_"
            return $false
        }

        return (Test-Path -Path $FinalPath)
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

    switch ($extension) {
        ".zip" { Invoke-UncompressZipIfNeeded $Source $Destination -Target $Target }
        ".7z"  { Invoke-Uncompress7zIfNeeded  $Source $Destination -Target $Target }
        default {
            Write-Bad "Unsupported archive format: $extension"
            return $false
        }
    }
}

function Invoke-HandledInstall {
    # This is a helper function to run an installation script and handle
    # errors in a consistent way. It will identify the final path of the
    # installation (if the user provided target, more below), then try to
    # run the installation script. If something goes wrong, both the source
    # installation file `Output` and the final installation path `FinalPath`
    # will be removed to avoid leaving broken files around. The user will
    # be notified of the error and the function will return $false. If
    # everything goes well, the function will return $true and the user
    # will be notified of the successful installation.
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
    Invoke-HandledInstall $path $output -InstallScript {
        if (!(Invoke-DownloadIfNeeded -URL $url -Output $output)) {
            throw "Failed to download $url as $output"
        }

        if (!(Invoke-UncompressIfNeeded $output $path -Target $target)) {
            throw "Failed to expand $output into $path with target $target"
        }
    } -Target $target
}
#endregion: utilities

#region: configuration
$KOMPANION_SETUP = Read-Json "$PSScriptRoot\konfiguration.json"

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
        # This points to the root of the user profile:
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

        # Copilot says this is required otherwise it falls back to the
        # user profile, but I am not sure if it is true... yes it
        # worked now after several failed attempts, so true, I guess.
        # Nah, it was a coincidence with something else...
        # Initialize-EnsureDirectory "$env:DOTNET_TOOLS_PATH"

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

    $target = "julia-1.12.1"
    $url    = $KOMPANION_SETUP.url.julia
    $output = "$env:KOMPANION_TEMP\julia.zip"
    $path   = "$env:KOMPANION_BIN"

    $success = Invoke-DlUnzipInstall $path $url $output -Target $target

    if ($success) {
        # XXX: check if JULIA_HOME has any special meaning, otherwise add
        # \bin directly to its definition (I think I cannot do that...).
        Set-KompanionEnvVar -Name "JULIA_HOME" `
            -Value "$env:KOMPANION_BIN\$target"

        Initialize-AddToPath -Directory "$env:JULIA_HOME\bin"

        Set-KompanionEnvVar -Name "JULIA_DEPOT_PATH" `
            -Value "$env:KOMPANION_DIR\.julia"

        Set-KompanionEnvVar -Name "JULIA_CONDAPKG_ENV" `
            -Value "$env:KOMPANION_DIR\.CondaPkg"

        # Path to local julia modules
        Set-KompanionEnvVar -Name "AUCHIMISTE_PATH" `
            -Value "$env:KOMPANION_DIR\src\auchimiste"

        # Ignore deps if requested:
        if ($NoJuliaDeps) { Set-LockedPkg "julia" }

        # Note: manually remove lock file if no deps installed at first:
        if (-not (Get-IsLockedPkg "julia")) {
            # This will invode setup.jl which may take a long time...
            Invoke-CapturedCommand "$env:JULIA_HOME\bin\julia.exe" @("-e", "exit()")
            Set-LockedPkg "julia"
        }
    } else {
        Write-Warn "Failed to install Julia, skipping configuration..."
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
            Invoke-WebRequest -Uri $KOMPANION_SETUP.url.lpm `
                -OutFile "$env:TEMP\lpm.exe"

            & "$env:TEMP\lpm.exe" install plugin_manager --assume-yes
            Remove-Item "$env:TEMP\lpm.exe"

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

    $target = "nvim-win64"
    $version = $KOMPANION_SETUP.version.neovim
    $url     = Get-PackageVersionedUrl "neovim"
    $output = "$env:KOMPANION_TEMP\neovim.zip"
    $path   = "$env:KOMPANION_BIN"

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
    $target = "node-v$version-win-x64"
    $url     = Get-PackageVersionedUrl "node"
    $output = "$env:KOMPANION_TEMP\node.zip"
    $path   = "$env:KOMPANION_BIN"

    $success = Invoke-DlUnzipInstall $path $url $output -Target $target

    if ($success) {
        Set-KompanionEnvVar -Name "NODE_HOME" `
            -Value "$env:KOMPANION_BIN\$target"

        Initialize-AddToPath -Directory "$env:NODE_HOME"
    } else {
        Write-Warn "Failed to install Node.js, skipping configuration..."
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

function Invoke-ConfigurePandoc {
    Write-Head "* Configuring Pandoc..."

    $target = "pandoc-3.8"
    $version = $KOMPANION_SETUP.version.pandoc
    $url     = Get-PackageVersionedUrl "pandoc"
    $output = "$env:KOMPANION_TEMP\pandoc.zip"
    $path   = "$env:KOMPANION_BIN"

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

function Invoke-ConfigureRust() {
    Write-Head "* Configuring Rust..."

    $url    = $KOMPANION_SETUP.url.rust
    $conf   = $KOMPANION_SETUP.config.rust
    $output = "$env:KOMPANION_TEMP\rustup-init.exe"
    $path   = "$env:KOMPANION_DIR\.cargo\bin"

    # XXX rust needs environment variables BEFORE installations!
    Set-KompanionEnvVar -Name "CARGO_HOME" `
        -Value "$env:KOMPANION_DIR\.cargo"

    Set-KompanionEnvVar -Name "RUSTUP_HOME" `
        -Value "$env:KOMPANION_DIR\.cargo"

    # XXX: disable certificate revocation check due to possible issues
    # with certain Windows configurations (corporate networks, proxies,
    # etc.). Avoid using this in general, as it lowers security!
    Set-KompanionEnvVar -Name "CARGO_HTTP_CHECK_REVOKE" -Value "false"

    $success = $false

    if (-not (Test-Path $path)) {
        try {
            Invoke-DownloadIfNeeded -URL $url -Output $output

            $arglist = @(
                "--verbose",
                "-y",
                "--default-host",      $conf.triple,
                "--default-toolchain", $conf.toolchain,
                "--profile",           $conf.profile,
                "--no-modify-path"
            )

            Invoke-CapturedCommand $output $arglist
            $success = $true
        } catch {
            Write-Bad "Failed to install Rust : $_"
            $success = $false
        }
    } else {
        if ($KOMPANION_DEBUG) {
            Write-Warn "* Installation target $path already exists..."
        }
        $success = $true
    }

    if ($success) {
        Initialize-AddToPath -Directory "$env:CARGO_HOME\bin"
    } else {
        Write-Warn "Failed to install Rust, skipping configuration..."
    }
}

function Invoke-ConfigurePython {
    Write-Head "* Configuring Python..."

    $target  = $null
    $version = $KOMPANION_SETUP.version.python
    $url     = Get-PackageVersionedUrl "python"
    $output  = "$env:KOMPANION_TEMP\python.zip"
    $path    = "$env:KOMPANION_BIN\python-$version-embed-amd64"

    $success = Invoke-DlUnzipInstall $path $url $output -Target $target

    if ($success) {
        $lockPost = "$env:KOMPANION_DOT\python-post.lock"

        if (!(Test-Path $lockPost)) {
            $python    = "$path\python.exe"
            $getpip    = "https://bootstrap.pypa.io/get-pip.py"
            $getpipOut = "$env:KOMPANION_TEMP\get-pip.py"

            # Enable user site packages (disabled by default in embedded python):
            @(
                "python313.zip"
                "."
                ""
                "import site"
            ) | Set-Content "$path\python313._pth"

            if (Invoke-DownloadIfNeeded $getpip $getpipOut) {
                & $python $getpipOut --no-warn-script-location
                New-Item -ItemType File -Path $lockPost -Force | Out-Null
            } else {
                Write-Bad "Failed to download get-pip.py and install pip..."
                Write-Warn "Pip will be not available, please retry..."
            }
        }
    } else {
        Write-Warn "Failed to install Python, skipping configuration..."
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

function Invoke-ConfigureAstralUv {
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

        # This is (was) required for nteract to work:
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

            # This used to be majordome, do not install by default!
            # Piperish install -e "$env:KOMPANION_DIR"

            New-Item -ItemType File -Path $lockFile -Force | Out-Null
        }
    } else {
        Write-Warn "Failed to install WinPython, skipping configuration..."
    }
}
#endregion: configuration

#region: ollama
function Get-OllamaProcesses {
    param (
        [Parameter(Mandatory, Position=0)]
        [string]$ExpectedPath
    )

    Get-Process -Name "ollama" -ErrorAction SilentlyContinue | Where-Object {
        try {
            $processPath = $_.Path
            -not [string]::IsNullOrWhiteSpace($processPath) `
            -and [string]::Equals($processPath, $ExpectedPath,
                                  [System.StringComparison]::OrdinalIgnoreCase)
        } catch {
            $false
        }
    }
}

function Invoke-ServeOllama {
    Write-Head "* Starting Ollama server..."

    $ollamaExe = "$env:OLLAMA_HOME\ollama.exe"

    if (!(Test-Path $ollamaExe)) {
        Write-Warn "Ollama executable not found at $ollamaExe..."
        return
    }

    $running = Get-OllamaProcesses -ExpectedPath $ollamaExe

    if ($running) {
        $runningPids = ($running | Select-Object -ExpandProperty Id) -join ", "
        Write-Warn "Ollama server is already running from $ollamaExe (PID: $runningPids)."
        return
    }

    try {
        $process = Start-Process -FilePath "$ollamaExe" -ArgumentList "serve" `
            -RedirectStandardOutput "$env:KOMPANION_LOGS\ollama.log" `
            -RedirectStandardError  "$env:KOMPANION_LOGS\ollama.err" `
            -PassThru -NoNewWindow -ErrorAction Stop
    } catch {
        Write-Bad "Failed to start Ollama server: $_"
        return
    }

    Start-Sleep -Seconds 1
    $started = Get-Process -Id $process.Id -ErrorAction SilentlyContinue

    if ($started) {
        Write-Host "Stop ollama service with the following command:`n"
        Write-Host "  Stop-Process -Id $($process.Id) -Force`n"
    } else {
        Write-Bad "Ollama process exited before it could be confirmed."
        Write-Host "Check logs under $env:KOMPANION_LOGS\ollama.*"
    }
}

function Invoke-StopOllama {
    Write-Head "* Stopping Ollama server..."

    $ollamaExe = "$env:OLLAMA_HOME\ollama.exe"

    if ([string]::IsNullOrWhiteSpace($env:OLLAMA_HOME)) {
        Write-Warn "OLLAMA_HOME is not set; refusing to stop non-target Ollama processes."
        return
    }

    $running = Get-OllamaProcesses -ExpectedPath $ollamaExe

    if (-not $running) {
        Write-Warn "Ollama server is not running from $ollamaExe."
        return
    }

    $runningPids = ($running | Select-Object -ExpandProperty Id) -join ", "

    try {
        Stop-Process -Id ($running | Select-Object -ExpandProperty Id) -Force -ErrorAction Stop
    } catch {
        Write-Bad "Failed to stop Ollama process(es) with PID(s): $runningPids"
        return
    }

    Start-Sleep -Seconds 1
    $remaining = Get-OllamaProcesses -ExpectedPath $ollamaExe

    if ($remaining) {
        $remainingPids = ($remaining | Select-Object -ExpandProperty Id) -join ", "
        Write-Bad "Ollama is still running (PID: $remainingPids)."
    } else {
        Write-Good "Ollama server stopped."
    }
}
#endregion: ollama