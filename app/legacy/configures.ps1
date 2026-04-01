# There is little you can do with this, better just stick to WinPython...
# "python":     "https://www.python.org/ftp/python/{0}/python-{0}-embed-amd64.zip",
# "python":  "3.13.12",
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