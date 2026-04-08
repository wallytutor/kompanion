#region: unix-like
Set-Alias -Name ll     -Value Get-ChildItem
Set-Alias -Name which  -Value Get-Command

function tail {
    param(
        [switch]$f
    )
    if ($f) {
        # This is equivalent to Linux `tail -f $Path`:
        Get-Content -Wait -Path @args
    } else {
        # Just read the whole file:
        Get-Content -Path @args
    }
}
#endregion: unix-like

#region: custom functions
function pp() {
    return $env:Path -split ';'
}

function vim {
    # For some reason nvim is not taking into account the override of the
    # user profile (APPDATA) and is looking for the config in the default
    # location. This is a workaround to force it to use the provided config.
    # Update: adding XDG_CONFIG_HOME solves the problem, but keep as is here.
    & nvim.exe -u "$env:KOMPANION_DIR\.config\nvim\init.lua" @args
}

function zettlr {
    & Zettlr.exe --data-dir="$env:ZETTLR_DATA" @args
}

function jlab {
    & jupyter-lab.exe --no-browser @args
}

function qprev {
    & quarto.exe preview --no-browser @args
}

function fsi {
    & dotnet fsi @args
}

function gmsh {
    & gmsh.exe @args
}

function kd {
    param (
        [string]$Repo
    )

    $Path = if ($Repo -eq "kompanion") {
        $env:KOMPANION_DIR
    } else {
        Join-Path $env:KOMPANION_REPO $Repo
    }

    if (-Not (Test-Path $Path)) {
        Write-Error "Repository '$Repo' does not exist at path '$Path'."
        return
    }

    Push-Location $Path

    try {
        git pull

        Code.exe $Path `
            --extensions-dir $env:VSCODE_EXTENSIONS `
            --user-data-dir  $env:VSCODE_SETTINGS
    } finally {
        Pop-Location
    }
}

function kp { kd -Repo "kompanion" }
function mj { kd -Repo "majordome" }
function xl { kd -Repo "xperimental" }

function kb { cd "$env:KOMPANION_DOT\bin" }
#endregion: custom functions
