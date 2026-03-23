param (
    [switch]$Build,
    [switch]$Restore,
    [switch]$Run,
    [switch]$Test,
    [switch]$Clean
)

function Push-Pop {
    param (
        [string]$Path,
        [scriptblock]$What
    )
    Push-Location $Path
    try { & $What } finally { Pop-Location }
}

function Clean-BinObj {
    Write-Host "Cleaning bin and obj directories in $PWD"
    Remove-Item -Force -Recurse "bin" -ErrorAction SilentlyContinue
    Remove-Item -Force -Recurse "obj" -ErrorAction SilentlyContinue
}

$console_xl = "$PSScriptRoot/console-xl"
$library_xl = "$PSScriptRoot/library-xl"
$test_library_xl = "$PSScriptRoot/test-library-xl"

if ($Restore) {
    Write-Host "Restoring dependencies..."
    dotnet restore
}

if ($Build) {
    Write-Host "Building the project..."
    dotnet build
}

if ($Run) {
    Write-Host "Running the console application..."
    Push-Pop -Path $console_xl -What { dotnet run }
}

if ($Test) {
    Write-Host "Running tests..."
    Push-Pop -Path $test_library_xl -What { dotnet test }
}

if ($Clean) {
    Write-Host "Cleaning the project..."
    dotnet clean
    Push-Pop -Path $console_xl      -What { Clean-BinObj }
    Push-Pop -Path $library_xl      -What { Clean-BinObj }
    Push-Pop -Path $test_library_xl -What { Clean-BinObj }
}
