function Get-EscapedPkg($pkg) {
    if ($pkg.StartsWith("re:")) {
        return $pkg.Substring(3)
    } else {
        return [regex]::Escape($pkg)
    }
}

function Get-PkgHref($pkg) {
    $target = "^$(Get-EscapedPkg $pkg).*\.pkg\.tar\.zst$"
    return ($html.Links | Where-Object href -Match $target).href
}

function Get-MingwSystem {
    param (
        [string]$repo,
        [string[]]$pkgs
    )
    $dest = "mingw"

    # Create destination directory if it doesn't exist:
    New-Item -ItemType Directory -Force -Path $dest | Out-Null

    # Get the HTML content of the repository page for scraping:
    $html = Invoke-WebRequest "$repo/" -UseBasicParsing

    foreach ($pkg in $pkgs) {
        # Find latest version of the package by matching/sorting:
        $file = Get-PkgHref $pkg | Sort-Object | Select-Object -Last 1

        $url = "$repo/$file"
        $tmp = "$env:TEMP\$file"

        if (-not $file) {
            Write-Host "Looking for $pkg`n`t> not found"
            continue
        }

        Write-Host "Looking for $pkg`n`t> found $file`n`t> downloading $url"

        Invoke-WebRequest $url -OutFile $tmp
        tar -xf $tmp -C $dest

        # tar -I zstd -xf $tmp -C $dest
        # zstd -d $tmp -o "$tmp.tar"
        # tar -xf "$tmp.tar" -C $dest
    }
}

$rootUrl = "https://repo.msys2.org"
$repoUrl = "$rootUrl/mingw/ucrt64"
$pkgs = @(
    "re:mingw-w64-ucrt-x86_64-binutils"
    "re:mingw-w64-ucrt-x86_64-crt-(\d[\w\.]*)"
    "re:mingw-w64-ucrt-x86_64-gcc-(\d[\d\.]*)"
    "re:mingw-w64-ucrt-x86_64-headers-(\d[\w\.]*)"
    "re:mingw-w64-ucrt-x86_64-winpthreads-(\d[\w\.]*)"
    "re:mingw-w64-ucrt-x86_64-winpthreads-git-(\d[\w\.]*)"
    "re:mingw-w64-ucrt-x86_64-libwinpthread-(\d[\w\.]*)"
    "re:mingw-w64-ucrt-x86_64-libwinpthread-git-(\d[\w\.]*)"
)

Get-MingwSystem -repo $repoUrl -pkgs $pkgs
