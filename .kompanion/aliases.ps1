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
function Print-Path() {
    return $env:Path -split ';'
}

function mj {
    cd $env:KOMPANION_DIR
}

function vim {
    # For some reason nvim is not taking into account the override of the
    # user profile (APPDATA) and is looking for the config in the default
    # location. This is a workaround to force it to use the provided config.
    & nvim.exe -u "$env:KOMPANION_DIR\config\nvim\init.lua" @args
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
#endregion: custom functions
