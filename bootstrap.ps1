# 1. Add KOMPANION_ROOT to the PATH environment variable
#
# 2. Installs minimal set of tools:
# - SevenZip
# - cURL
# - Git
# - .NET SDK
#
# 3. Compiles the Kompanion executable:

function Main {
    # Source kompanion common functions:
    . "$PSScriptRoot\src\kompanion.ps1"

    #region: environment variables
    # OS overrides:
    $env:USERPROFILE   = "$PSScriptRoot\home"
    $env:APPDATA       = "$PSScriptRoot\home\AppData\Roaming"
    $env:LOCALAPPDATA  = "$PSScriptRoot\home\AppData\Local"

    # Internal variables:
    $env:KOMPANION_DOT = "$env:USERPROFILE\.kompanion"
    $env:KOMPANION_BIN = "$env:USERPROFILE\.kompanion\bin"
    $env:KOMPANION_TMP = "$env:USERPROFILE\.kompanion\tmp"

    # Ensure base folders exist before downloading/moving files.
    New-Item `
        -Path $env:KOMPANION_TMP `
        -ItemType Directory -Force | Out-Null

    New-Item `
        -Path $env:KOMPANION_BIN `
        -ItemType Directory -Force | Out-Null
    #endregion: environment variables

    #region: base setup
    $configPath = "$env:KOMPANION_DOT\config.json"
    $config = Get-Content -Path $configPath -Raw | ConvertFrom-Json

    try {
        Invoke-ConfigureSevenZip $config.bootstrap.urls.sevenzip
        Invoke-ConfigureCurl     $config.bootstrap.urls.curl
        Invoke-ConfigureGit      $config.bootstrap.urls.git
        Invoke-ConfigureDotNet   $config.bootstrap.urls.dotnet
    }
    catch {
        Write-Error "Bootstrap failed: $_"
        exit 1
    }
    #endregion: base setup
}

Main
