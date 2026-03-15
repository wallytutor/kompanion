# -+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
# Script parameters
# -+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

param ()

# -+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
# Global configuration
# -+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

# $OLLAMA_MODEL_PULL  = "llama3.1:405b"
# $OLLAMA_MODEL_PULL  = "llama3.1:70b"
$OLLAMA_MODEL_PULL  = "llama3.1:8b"

$OLLAMA_VERSION     = "v0.12.11"
$OLLAMA_GITHUB_REL  = "https://github.com/ollama/ollama/releases/download/"

$OLLAMA_PROJECT_DIR = "$PsScriptRoot"
$OLLAMA_BIN_DIR     = "$OLLAMA_PROJECT_DIR\bin"
$OLLAMA_TMP_DIR     = "$OLLAMA_PROJECT_DIR\tmp"

$OLLAMA_EXE_URL     = "$OLLAMA_GITHUB_REL/$OLLAMA_VERSION/ollama-windows-amd64.zip"
$OLLAMA_EXE_ZIP     = "$OLLAMA_TMP_DIR\ollama.zip"

$env:CUDA_VISIBLE_DEVICES ="0"
$env:OLLAMA_MODELS        = "$OLLAMA_PROJECT_DIR\models"

# -+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
# Helper functions
# -+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

function Test-InPath() {
    param (
        [string]$Directory
    )

    $normalized = $Directory.TrimEnd('\')
    $filtered = ($env:Path -split ';' | ForEach-Object { $_.TrimEnd('\') })
    return $filtered -contains $normalized
}

function Initialize-AddToPath() {
    param (
        [string]$Directory
    )

    if (Test-Path -Path $Directory) {
        if (!(Test-InPath $Directory)) {
            $env:Path = "$Directory;" + $env:Path
        }
    } else {
        Write-Host "Not prepeding missing path to environment: $Directory"
    }
}

# -+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
# Main script
# -+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

function Main {
    Initialize-AddToPath "$OLLAMA_BIN_DIR"
    # Initialize-AddToPath "$OLLAMA_BIN_DIR\lib"

    & { # Ensure required directories exist:
        if (!(Test-Path -Path $OLLAMA_BIN_DIR)) {
            New-Item -ItemType Directory -Path $OLLAMA_BIN_DIR
        }

        if (!(Test-Path -Path $OLLAMA_TMP_DIR)) {
            New-Item -ItemType Directory -Path $OLLAMA_TMP_DIR
        }

        if (!(Test-Path -Path $env:OLLAMA_MODELS)) {
            New-Item -ItemType Directory -Path $env:OLLAMA_MODELS
        }
    }

    & { # Download and extract if required:
        if (!(Test-Path -Path $OLLAMA_EXE_ZIP)) {
            Start-BitsTransfer `
                -Source      $OLLAMA_EXE_URL `
                -Destination $OLLAMA_EXE_ZIP `
                -ErrorAction Stop
        }

        if (!(Test-Path -Path "$OLLAMA_BIN_DIR\ollama.exe")) {
            Expand-Archive `
                -Path            $OLLAMA_EXE_ZIP `
                -DestinationPath $OLLAMA_BIN_DIR
        }
    }

    & { # Start server if required:
        if (Get-Process -Name "ollama" -ErrorAction SilentlyContinue) {
            Write-Output "Ollama is already running..."
        } else {
            Start-Process -FilePath "ollama.exe" -ArgumentList "serve" -NoNewWindow
        }
    }

    & { # Pull model if required:
        $models = & "ollama.exe" "list"

        if ($models | Select-String "$OLLAMA_MODEL_PULL") {
            Write-Output "$OLLAMA_MODEL_PULL model already pulled..."
        } else {
            Write-Output "Model not found"
            Start-Process `
                -FilePath "ollama.exe" `
                -ArgumentList "pull", $OLLAMA_MODEL_PULL `
                -NoNewWindow -Wait
        }
    }

    # Ollama API will be served on http://localhost:11434
    # ollama run $OLLAMA_MODEL_PULL

    # TODO add virtual environment management
}

Main

# -+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
#
# -+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+