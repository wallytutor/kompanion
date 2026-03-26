param (
    [switch]$Run,
    [switch]$Clean
)

function Invoke-ForceClean($what) {
    Write-Host "Cleaning $what..." -ForegroundColor Yellow
    Remove-Item -ErrorAction SilentlyContinue -Force -Recurse -Path $what
}

if ($Clean) {
    Invoke-ForceClean "*.log"
    Invoke-ForceClean "*.csv"
    Invoke-ForceClean "volume_*"
    Invoke-ForceClean "solution_*"
    Invoke-ForceClean "restart*"
}

if ($Run) {
    & SU2_CFD master.cfg 2>&1 | Tee-Object -FilePath solution.log
}