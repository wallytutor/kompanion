param (
    [switch]$Run,
    [switch]$Clean,
    [int]$NumberProc = 4
)

function Invoke-ForceClean($what) {
    Write-Host "Cleaning $what..." -ForegroundColor Yellow
    Remove-Item -ErrorAction SilentlyContinue -Force -Recurse -Path $what
}

function Invoke-RunManager {
    param(
        [string]$Cfg
    )
    $job = Start-Job -ScriptBlock {
        param(
            [int]$nproc,
            [string]$cfg
        )
        $p = Start-Process -FilePath "mpiexec" `
            -ArgumentList @("-n", "$nproc", "SU2_CFD.exe", $cfg) `
            -RedirectStandardOutput "log.solve-$nproc" `
            -RedirectStandardError  "log.error-$nproc" `
            -PassThru -NoNewWindow

        $p.Id
    } -ArgumentList @($NumberProc, $Cfg)

    Wait-Job -Id $job.Id -Timeout 10 | Out-Null
    $pidValue = Receive-Job -Id $job.Id
    Remove-Job -Id $job.Id -Force

    if ($null -ne $pidValue -and "$pidValue" -ne "") {
        "$pidValue" | Out-File -FilePath "log.pid" -Encoding ascii -Force
        Write-Host "Started background process PID: $pidValue"
        Write-Host "Stop simulation with the following command:`n"
        Write-Host "  Stop-Process -Id $pidValue -Force`n"
    } else {
        Write-Host "Could not retrieve PID..." -ForegroundColor Red
    }
}

if ($Clean) {
    Invoke-ForceClean "log.*"
    Invoke-ForceClean "*.log"
    Invoke-ForceClean "*.csv"
    Invoke-ForceClean "volume_*"
    Invoke-ForceClean "solution_*"
    Invoke-ForceClean "restart*"
}

if ($Run) {
    New-Item -Path "restart" -ItemType Directory `
        -ErrorAction SilentlyContinue | Out-Null

    # & SU2_CFD master.cfg 2>&1 | Tee-Object -FilePath solution.log
    Invoke-RunManager -Cfg "master.cfg"
}