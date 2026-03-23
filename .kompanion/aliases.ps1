# ---------------------------------------------------------------------------
# aliases.ps1
# ---------------------------------------------------------------------------

# Unix-like commands
Set-Alias -Name ll     -Value Get-ChildItem
Set-Alias -Name which  -Value Get-Command

# Programs
Set-Alias -Name gmsh   -Value gmsh.exe

# Function wrapped
function Print-Path() { return $env:Path -split ';' }
function mj { cd $env:KOMPANION_DIR }

function vim {
    # For some reason nvim is not taking into account the override of the
    # user profile (APPDATA) and is looking for the config in the default
    # location. This is a workaround to force it to use the provided config.
    & nvim.exe -u "$env:KOMPANION_DIR\config\nvim\init.lua" @args
}

function zettlr {
    & Start-Process Zettlr.exe -ArgumentList "--data-dir=$env:ZETTLR_DATA"
}

function jlab {
    & Start-Process jupyter-lab.exe -ArgumentList "--no-browser" `
        -NoNewWindow -Wait
}

function qprev {
    & Start-Process quarto.exe -ArgumentList "preview", "--no-browser" `
        -NoNewWindow -Wait
}

# ---------------------------------------------------------------------------
# EOF
# ---------------------------------------------------------------------------