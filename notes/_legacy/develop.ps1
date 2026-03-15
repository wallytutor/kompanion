<#
.SYNOPSIS
Provides building and publishing capabilities for the Quarto project.

.DESCRIPTION
This script sets up a development environment for the Quarto project, including
creating a virtual environment, installing dependencies, and building the project.
It also supports publishing the built documentation to GitHub Pages.

.PARAMETER DumpHtml
Generates HTML output from the Quarto project.
.PARAMETER DumpPdf
Generates PDF output from the Quarto project.
.PARAMETER Render
Renders the Quarto project live preview.
.PARAMETER ReinstallMajordome
Reinstalls the Majordome package in editable mode with extras.
.PARAMETER TestQuarto
Tests for the presence of Quarto and its configuration.
.PARAMETER Pinned
Installs pinned package versions from pinned.txt.
.PARAMETER Clean
Cleans the build directories.
.PARAMETER CleanLaTeX
Cleans up auxiliary LaTeX files generated during PDF rendering.
.PARAMETER Publish
Publishes the built documentation to GitHub Pages.

.EXAMPLE
.\develop.ps1 -Build -Publish

.NOTES
Author: Walter Dal'Maz Silva
Date: November 2025
#>

# ----------------------------------------------------------------------------
# Parameters
# ----------------------------------------------------------------------------

param (
    [switch]$Initialize,
    [switch]$DumpHtml,
    [switch]$DumpPdf,
    [switch]$Render,
    [switch]$ReinstallMajordome,
    [switch]$TestQuarto,
    [switch]$Pinned,
    [switch]$Clean,
    [switch]$CleanLaTeX,
    [switch]$Publish
)

# ----------------------------------------------------------------------------
# Functions
# ----------------------------------------------------------------------------

function Rm-Rf {
    param (
        [string]$Path
    )
    Remove-Item -Recurse -Force $Path -ErrorAction SilentlyContinue
}

function CleanUp-LaTeX {
    Rm-Rf "*.aux"
    Rm-Rf "*.log"
    Rm-Rf "*.out"
    Rm-Rf "*.toc"
    Rm-Rf "*.nav"
    Rm-Rf "*.snm"
    Rm-Rf "*.synctex.gz"
    Rm-Rf "index.tex"
    Rm-Rf "index.pdf"
}

function Get-StatusMessage {
    param( [string]$Message = "" )

    if ($LASTEXITCODE -eq 0) {
        Write-Good ">>> Success!"
        if ($Message) { Write-Good $Message }
        return $true
    } else {
        Write-Bad ">>> Failed!"
        if ($Message) { Write-Bad $Message }
        return $false
    }
}

function Install-Majordome {
    param (
        [string]$PythonPath
    )

    try {
        Write-Head "`nInstalling Majordome with extras..."
        $opts = @("-m", "pip", "install", "-e", "$env:KOMPANION_DIR[extras]")
        Start-Process $PythonPath -ArgumentList $opts -NoNewWindow -Wait
    }
    catch {
        Write-Bad "Not working under Majordome."
        exit 1
    }
}

function Test-Quarto {
    Write-Head "`nChecking for Quarto..."
    $version = quarto --version 2>$null

    if ($LASTEXITCODE -eq 0) {
        $out = "Quarto found: $version"
    } else {
        $out = "Quarto not found! Please install Quarto..."
    }

    & quarto check > log.quarto 2>&1

    return Get-StatusMessage -Message $out
}

# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------

# For access with os.environ in Python:
$env:BOOK_DATA  = "$PSScriptRoot\data"
$env:BOOK_MEDIA = "$PSScriptRoot\media"

$venvRoot = $PSScriptRoot
$pythonPath = "$venvRoot\.venv\Scripts\python.exe"

Rm-Rf "log.*"

if ($Clean) {
    Write-Head "`nCleaning Quarto output..."
    Rm-Rf "_book"
    Rm-Rf ".quarto"
}

if ($Clean -or $CleanLaTeX) {
    Write-Head "`nCleaning up LaTeX auxiliary files..."
    CleanUp-LaTeX
}

if (-not (Initialize-VirtualEnvironment -VenvRoot $venvRoot)) {
    exit 1
}

if ($Pinned) {
    Write-Head "`nForcing installation of pinned packages..."
    Piperish -PythonPath $pythonPath @("-r", "requirements.pin")
}

if ($Initialize -or $ReinstallMajordome) {
    Install-Majordome -PythonPath $pythonPath
}

if ($TestQuarto -and (-not (Test-Quarto))) {
    exit 1
}

if ($DumpPdf)  { quarto render --to pdf }
if ($DumpHtml) { quarto render --to html }
if ($Render)   { quarto preview --no-browser --port 2505 }

if ($Publish)  {
    CleanUp-LaTeX
    quarto publish gh-pages --no-prompt --no-browser
}

# Alternative to quarto publish?
# $buildDir = "$PSScriptRoot\_book"
# if ((Test-Path $buildDir) -and $Publish) {
#     $options = @("-n", "-p", "-f", "$buildDir")
#     Start-Process -FilePath ghp-import -ArgumentList $options `
#         -NoNewWindow -Wait
# }

# ----------------------------------------------------------------------------
# EOF
# ----------------------------------------------------------------------------