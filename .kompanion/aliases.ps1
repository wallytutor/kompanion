# ---------------------------------------------------------------------------
# aliases.ps1
# ---------------------------------------------------------------------------

# Unix-like commands
Set-Alias -Name ll     -Value Get-ChildItem
Set-Alias -Name which  -Value Get-Command

# Programs
Set-Alias -Name vim    -Value nvim
Set-Alias -Name gmsh   -Value gmsh.exe

# Function wrapped
function Print-Path() { return $env:Path -split ';' }
function mj { cd $env:KOMPANION_DIR }

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