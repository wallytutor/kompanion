$KOMPANION_DEBUG = $true

#region: utilities
function Read-Json {
    param (
        [Parameter(Mandatory, Position=0)]
        [string]$Path
    )

    Get-Content -Path $Path -Raw | ConvertFrom-Json
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
        -NoNewWindow -Wait

    Get-Content $logOut | Add-Content "$env:KOMPANION_LOGS\kompanion.log"
    Remove-Item $logOut -ErrorAction SilentlyContinue

    Get-Content $logErr | Add-Content "$env:KOMPANION_LOGS\kompanion.err"
    Remove-Item $logErr -ErrorAction SilentlyContinue

    return $proc.ExitCode
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
    if (!$success) {
        try {
            # XXX: -ErrorAction Stop is required to catch errors
            Start-BitsTransfer -Source $URL -Destination $Output -ErrorAction Stop
            $success = $true
        } catch {
            Write-Bad "Failed to download $URL as $Output (Start-BitsTransfer)"
        }
    }

    # curl.exe
    if (!$success) {
        try {
            # Invoke-WebRequest -Uri $URL -OutFile $Output --> TOO SLOW
            # TODO implement the captured output for curl as well, to log the process:
            # Invoke-CapturedCommand "curl.exe" @("--ssl-no-revoke", $URL, "--output", $Output)
            curl.exe --ssl-no-revoke $URL --output $Output
            $success = ($LASTEXITCODE -eq 0)
        } catch {
            Write-Bad "Failed to download $URL as $Output (curl)"
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
    $url     = $KOMPANION_SETUP.url.dotnet -f $version
    $output  = "$env:KOMPANION_TEMP\dotnet.zip"
    $path    = "$env:KOMPANION_BIN\dotnet-sdk-$version-win-x64"

    $success = Invoke-DlUnzipInstall $path $url $output -Target $target

    if ($success) {
        Set-KompanionEnvVar -Name "DOTNET_HOME" `
            -Value "$env:KOMPANION_BIN\dotnet-sdk-$version-win-x64"

        Set-KompanionEnvVar -Name "DOTNET_CLI_TELEMETRY_OPTOUT" `
            -Value "1"

        Initialize-AddToPath -Directory "$env:DOTNET_HOME"
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

        # Install minimal requirements:
        $lockFile = "$env:KOMPANION_DOT\julia.lock"

        # Ignore deps if requested:
        if ($NoJuliaDeps) {
            New-Item -ItemType File -Path $lockFile -Force | Out-Null
        }

        # Note: manually remove lock file if no deps installed at first:
        if (!(Test-Path $lockFile)) {
            # This will invode setup.jl which may take a long time...
            Invoke-CapturedCommand "$env:JULIA_HOME\bin\julia.exe" @("-e", "exit()")
            New-Item -ItemType File -Path $lockFile -Force | Out-Null
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

        # Invoke-WebRequest -Uri "https://github.com/lite-xl/lite-xl-plugin-manager/releases/download/latest/lpm.x86_64-windows.exe" -OutFile "lpm.exe"
        # lpm.exe install plugin_manager --assume-yes
        # Remove-Item lpm.exe

        # $_ = Invoke-DownloadIfNeeded $KOMPANION_SETUP.url.lpm "$env:LITEXL_HOME\lpm.exe"
        # & "$env:LITEXL_HOME\lpm.exe" install plugin_manager --assume-yes

        Initialize-AddToPath -Directory "$env:LITEXL_HOME"
    } else {
        Write-Warn "Failed to install LiteXL, skipping configuration..."
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
#endregion: configuration
