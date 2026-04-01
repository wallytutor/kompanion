#region: ollama
function Get-OllamaProcesses {
    param (
        [Parameter(Mandatory, Position=0)]
        [string]$ExpectedPath
    )

    Get-Process -Name "ollama" -ErrorAction SilentlyContinue | Where-Object {
        try {
            $processPath = $_.Path
            -not [string]::IsNullOrWhiteSpace($processPath) `
            -and [string]::Equals($processPath, $ExpectedPath,
                                  [System.StringComparison]::OrdinalIgnoreCase)
        } catch {
            $false
        }
    }
}

function Invoke-ServeOllama {
    Write-Head "* Starting Ollama server..."

    $ollamaExe = "$env:OLLAMA_HOME\ollama.exe"

    if (!(Test-Path $ollamaExe)) {
        Write-Warn "Ollama executable not found at $ollamaExe..."
        return
    }

    $running = Get-OllamaProcesses -ExpectedPath $ollamaExe

    if ($running) {
        $runningPids = ($running | Select-Object -ExpandProperty Id) -join ", "
        Write-Warn "Ollama server is already running from $ollamaExe (PID: $runningPids)."
        return
    }

    try {
        $process = Start-Process -FilePath "$ollamaExe" -ArgumentList "serve" `
            -RedirectStandardOutput "$env:KOMPANION_LOGS\ollama.log" `
            -RedirectStandardError  "$env:KOMPANION_LOGS\ollama.err" `
            -PassThru -NoNewWindow -ErrorAction Stop
    } catch {
        Write-Bad "Failed to start Ollama server: $_"
        return
    }

    Start-Sleep -Seconds 1
    $started = Get-Process -Id $process.Id -ErrorAction SilentlyContinue

    if ($started) {
        Write-Host "Stop ollama service with the following command:`n"
        Write-Host "  Stop-Process -Id $($process.Id) -Force`n"
    } else {
        Write-Bad "Ollama process exited before it could be confirmed."
        Write-Host "Check logs under $env:KOMPANION_LOGS\ollama.*"
    }
}

function Invoke-StopOllama {
    Write-Head "* Stopping Ollama server..."

    $ollamaExe = "$env:OLLAMA_HOME\ollama.exe"

    if ([string]::IsNullOrWhiteSpace($env:OLLAMA_HOME)) {
        Write-Warn "OLLAMA_HOME is not set; refusing to stop non-target Ollama processes."
        return
    }

    $running = Get-OllamaProcesses -ExpectedPath $ollamaExe

    if (-not $running) {
        Write-Warn "Ollama server is not running from $ollamaExe."
        return
    }

    $runningPids = ($running | Select-Object -ExpandProperty Id) -join ", "

    try {
        Stop-Process -Id ($running | Select-Object -ExpandProperty Id) -Force -ErrorAction Stop
    } catch {
        Write-Bad "Failed to stop Ollama process(es) with PID(s): $runningPids"
        return
    }

    Start-Sleep -Seconds 1
    $remaining = Get-OllamaProcesses -ExpectedPath $ollamaExe

    if ($remaining) {
        $remainingPids = ($remaining | Select-Object -ExpandProperty Id) -join ", "
        Write-Bad "Ollama is still running (PID: $remainingPids)."
    } else {
        Write-Good "Ollama server stopped."
    }
}
#endregion: ollama