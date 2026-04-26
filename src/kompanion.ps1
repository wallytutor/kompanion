#region: utilities
# Global list of environment variable names created by this script
$GLOBAL:KOMPANION_CREATED_ENVS = New-Object System.Collections.ArrayList

function Test-InPath() {
    param (
        [Parameter(Mandatory=$true, Position=0)][string]$Directory
    )

    $normalized = $Directory.TrimEnd('\')
    $filtered = ($env:Path-split ';' | ForEach-Object { $_.TrimEnd('\') })
    return $filtered -contains $normalized
}

function Invoke-ManagedExecution {
    param (
        [Parameter(Mandatory)][scriptblock]$ScriptBlock,
        [string]$ScriptTemp = $null,
        [string]$ScriptDest = $null,
        [bool]$CreateTemp = $false
    )

    try {
        if ($CreateTemp -and $ScriptTemp) {
            if (Test-Path -Path $ScriptTemp) {
                Remove-Item -Path $ScriptTemp -Recurse -Force
            }

            Write-Host -ForegroundColor Green `
                "* Creating temporary directory for script execution: $ScriptTemp"

            New-Item -Path $ScriptTemp -ItemType Directory -Force | Out-Null
        }

        & $ScriptBlock
    }
    catch {
        if ($ScriptDest -and (Test-Path -Path $ScriptDest)) {
            Remove-Item -Path $ScriptDest -Recurse -Force
        }
        throw "failed to execute script block: $_"
    }
    finally {
        if ($ScriptTemp -and (Test-Path -Path $ScriptTemp)) {
            Remove-Item -Path $ScriptTemp -Recurse -Force
        }
    }
}

function Set-TrackedEnvironmentVariable {
    param (
        [Parameter(Mandatory=$true, Position=0)][string]$Name,
        [Parameter(Mandatory=$true, Position=1)][string]$Value
    )
    # Set the process environment variable (dynamic name)
    Set-Item -Path ("env:$Name") -Value $Value

    # Track the variable name in the global list to save it later:
    [void]$GLOBAL:KOMPANION_CREATED_ENVS.Add($Name)
}

function Set-ManagedAddToPath {
    param (
        [Parameter(Mandatory=$true, Position=0)][string]$Directory
    )

    if (Test-Path -Path $Directory) {
        if (!(Test-InPath $Directory)) {
            $env:Path = "$Directory;" + $env:Path
        }
    } else {
        Write-Host -ForegroundColor Red `
            "* Not prepending missing path: $Directory"
    }
}

function Write-CommonHeader {
    param (
        [string]$Url,
        [string]$Destination
    )

    Write-Host -ForegroundColor Green "* Downloading from $Url..."
    Write-Host -ForegroundColor Green "* Destination: $Destination"
}

function Test-DotnetToolInstalled {
    param(
        [Parameter(Mandatory)]
        [string]$PackageId
    )

    $output = dotnet tool list -g $PackageId
    return $output -match $PackageId
}
#endregion: utilities

#region: bootstrap configures
function Invoke-ConfigureSevenZip {
    param (
        [Parameter(Mandatory=$true, Position=0)][string]$url
    )

    $target = "$env:KOMPANION_BIN\7zip"

    if (-Not (Test-Path -Path $target)) {
        Write-CommonHeader -Url $url -Destination $target

        $tmp = "$env:KOMPANION_TMP\7zip"

        Invoke-ManagedExecution -ScriptBlock {
            $files = @("7z.dll", "7z.exe", "License.txt", "readme.txt")

            foreach ($file in $files) {
                Start-BitsTransfer `
                    -Source "$url/$file" `
                    -Destination "$tmp\$file" `
                    -ErrorAction Stop
            }

            Move-Item -Path $tmp -Destination $target -ErrorAction Stop
        } -ScriptTemp $tmp -ScriptDest $target -CreateTemp $true
    }

    Set-TrackedEnvironmentVariable "KOMPANION_SEVENZIP" $target
    Set-ManagedAddToPath "$target\"
}

function Invoke-ConfigureCurl {
    param (
        [Parameter(Mandatory=$true, Position=0)][string]$url
    )

    $name = [System.IO.Path]::GetFileNameWithoutExtension($url)
    $target = "$env:KOMPANION_BIN\$name"

    if (-Not (Test-Path -Path $target)) {
        Write-CommonHeader -Url $url -Destination $target

        $tmp = "$env:KOMPANION_TMP\curl"

        Invoke-ManagedExecution -ScriptBlock {
            Start-BitsTransfer `
                -Source "$url" `
                -Destination "$tmp\curl.zip" `
                -ErrorAction Stop

            Expand-Archive `
                -Path "$tmp\curl.zip" `
                -DestinationPath "$tmp" `
                -Force

            $folder = Get-ChildItem -Path $tmp -Directory | Select-Object -First 1

            Move-Item `
                -Path $folder.FullName `
                -Destination "$target" `
                -ErrorAction Stop
        } -ScriptTemp $tmp -ScriptDest $target -CreateTemp $true
    }

    Set-TrackedEnvironmentVariable "KOMPANION_CURL" "$target"
    Set-ManagedAddToPath "$target\bin"
}

function Invoke-ConfigureGit {
    param (
        [Parameter(Mandatory=$true, Position=0)][string]$url
    )

    $name = [System.IO.Path]::GetFileNameWithoutExtension($url)
    $target = "$env:KOMPANION_BIN\$name"

    if (-Not (Test-Path -Path $target)) {
        Write-CommonHeader -Url $url -Destination $target

        $tmp = "$env:KOMPANION_TMP\git"

        Invoke-ManagedExecution -ScriptBlock {
            Start-BitsTransfer `
                -Source "$url" `
                -Destination "$tmp\git.zip" `
                -ErrorAction Stop

            Expand-Archive `
                -Path "$tmp\git.zip" `
                -DestinationPath "$tmp\$name" `
                -Force


            Move-Item `
                -Path "$tmp\$name" `
                -Destination "$target" `
                -ErrorAction Stop
        } -ScriptTemp $tmp -ScriptDest $target -CreateTemp $true
    }

    Set-TrackedEnvironmentVariable "KOMPANION_GIT" "$target"
    Set-ManagedAddToPath "$target\cmd"
}

function Invoke-ConfigureDotNet {
    param (
        [Parameter(Mandatory=$true, Position=0)][string]$url
    )

    $name = [System.IO.Path]::GetFileNameWithoutExtension($url)
    $target = "$env:KOMPANION_BIN\$name"

    if (-Not (Test-Path -Path $target)) {
        Write-CommonHeader -Url $url -Destination $target

        $tmp = "$env:KOMPANION_TMP\dotnet"

        Invoke-ManagedExecution -ScriptBlock {
            Start-BitsTransfer `
                -Source "$url" `
                -Destination "$tmp\dotnet.zip" `
                -ErrorAction Stop

            Expand-Archive `
                -Path "$tmp\dotnet.zip" `
                -DestinationPath "$tmp\$name" `
                -Force

            Move-Item `
                -Path "$tmp\$name" `
                -Destination "$target" `
                -ErrorAction Stop
        } -ScriptTemp $tmp -ScriptDest $target -CreateTemp $true
    }

    Set-TrackedEnvironmentVariable "DOTNET_ROOT" "$target"

    # This points to the root of the user profile ?
    Set-TrackedEnvironmentVariable "DOTNET_CLI_HOME" `
        "$env:USERPROFILE"
    Set-TrackedEnvironmentVariable "DOTNET_TOOLS_PATH" `
        "$env:USERPROFILE\.dotnet\tools"

    Set-TrackedEnvironmentVariable "NUGET_PACKAGES" `
        "$env:USERPROFILE\.nuget\packages"
    Set-TrackedEnvironmentVariable "NUGET_HTTP_CACHE_PATH" `
        "$env:USERPROFILE\.nuget\http-cache"
    Set-TrackedEnvironmentVariable "NUGET_SCRATCH" `
        "$env:USERPROFILE\.nuget\scratch"

    Set-TrackedEnvironmentVariable `
        "DOTNET_INTERACTIVE_CLI_TELEMETRY_OPTOUT"  "1"
    Set-TrackedEnvironmentVariable `
        "DOTNET_CLI_TELEMETRY_OPTOUT" "1"


    Set-ManagedAddToPath "$env:DOTNET_ROOT"

    dotnet dev-certs https --trust

    # if (-Not (Test-DotnetToolInstalled "fsdocs-tool")) {
    #     Write-Host -ForegroundColor Green `
    #         "* Installing fsdocs-tool dotnet global tool..."
    #
    #     dotnet tool install -g fsdocs-tool
    # }

    Set-ManagedAddToPath "$env:DOTNET_TOOLS_PATH"
}
#endregion: bootstrap configures