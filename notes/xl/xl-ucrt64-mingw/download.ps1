function Get-EscapedPkg($pkg) {
    if ($pkg.StartsWith("re:")) {
        return $pkg.Substring(3)
    } else {
        return [regex]::Escape($pkg)
    }
}

function Get-PkgHref($pkg) {
    $target = "^$(Get-EscapedPkg $pkg)-.*\.pkg\.tar\.zst$"
    return ($html.Links | Where-Object href -Match $target).href
}

function Get-Mingw64 {
    $repo = "https://repo.msys2.org/mingw/ucrt64"
    $dest = "mingw64"

    $pkgs = @(
        "re:mingw-w64-ucrt-x86_64-binutils"
        "re:mingw-w64-ucrt-x86_64-crt-(\d[\w\.]*)"
        "re:mingw-w64-ucrt-x86_64-gcc-(\d[\d\.]*)"
        "re:mingw-w64-ucrt-x86_64-headers-(\d[\w\.]*)"
        "re:mingw-w64-ucrt-x86_64-libwinpthread-git-(\d[\w\.]*)"
    )

    New-Item -ItemType Directory -Force -Path $dest | Out-Null

    # Get the HTML content of the repository page for scraping:
    $html = Invoke-WebRequest "$repo/" -UseBasicParsing

    foreach ($pkg in $pkgs) {
        # Find latest version of the package by matching/sorting:
        $file = Get-PkgHref $pkg | Sort-Object | Select-Object -Last 1

        $url = "$repo/$file"
        $tmp = "$env:TEMP\$file"

        Write-Host "Looking for $pkg`n`t> found $file`n`t> downloading $url"

        Invoke-WebRequest $url -OutFile $tmp
        tar -xf $tmp -C $dest
    }
}

Get-Mingw64

# $root = Split-Path -Parent $MyInvocation.MyCommand.Path
# $mingw = Join-Path $root "mingw64\bin"

# $env:PATH = "$mingw;$env:PATH"
# $env:CC   = "gcc"
# $env:CXX  = "g++"

# Write-Host "MSYS2 MinGW environment loaded."
