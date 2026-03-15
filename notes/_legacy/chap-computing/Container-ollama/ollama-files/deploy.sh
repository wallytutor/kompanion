#!/usr/bin/env bash
# -+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
# Script parameters
# -+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

set -e

# -+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
# Global configuration
# -+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

OLLAMA_MODEL_PULL="mistral-nemo:12b"
# OLLAMA_MODEL_PULL="llama3.1:8b"
# OLLAMA_MODEL_PULL="llama3.1:70b"
# OLLAMA_MODEL_PULL="llama3.1:405b"

OLLAMA_VERSION="v0.12.11"
OLLAMA_GITHUB_REL="https://github.com/ollama/ollama/releases/download/"

OLLAMA_PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OLLAMA_BIN_DIR="$OLLAMA_PROJECT_DIR/bin"
OLLAMA_TMP_DIR="$OLLAMA_PROJECT_DIR/tmp"
OLLAMA_ENV_DIR="$OLLAMA_PROJECT_DIR/.venv"

OLLAMA_EXE_URL="$OLLAMA_GITHUB_REL/$OLLAMA_VERSION/ollama-linux-amd64.tgz"
OLLAMA_EXE_TAR="$OLLAMA_TMP_DIR/ollama.tgz"

export CUDA_VISIBLE_DEVICES=0
export OLLAMA_MODELS="$OLLAMA_PROJECT_DIR/models"

# -+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
# Helper functions
# -+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

function test_in_path() {
    local directory="$1"
    case ":$PATH:" in
        *":$directory:"*) return 0 ;;
        *) return 1 ;;
    esac
}

function initialize_add_to_path() {
    local directory="$1"

    if [[ -d "$directory" ]]; then
        echo "Prepending missing path to environment: $directory"
        if ! test_in_path "$directory"; then
            export PATH="$directory:$PATH"
        fi
    else
        echo "Not prepending missing path to environment: $directory"
    fi
}

function start_ollama_server() {
    # Ollama API is served on http://localhost:11434
    if pgrep -x "ollama" > /dev/null; then
        echo "Ollama is already running..."
    else
        echo "Starting Ollama server..."
        ollama serve &
        sleep 2  # Give the server a moment to start
    fi
}

function stop_ollama_server() {
    if pgrep -x "ollama" > /dev/null; then
        echo "Stopping Ollama server..."
        kill -9 "$(pgrep -x "ollama")"
    else
        echo "Ollama server is not running..."
    fi
}

function pull_ollama_model() {
    if ollama list | grep -q "$OLLAMA_MODEL_PULL"; then
        echo "$OLLAMA_MODEL_PULL model already pulled..."
    else
        echo "Pulling model $OLLAMA_MODEL_PULL..."
        ollama pull "$OLLAMA_MODEL_PULL"
    fi
}

function run_ollama_model() {
    start_server
    ollama run $OLLAMA_MODEL_PULL
}

function activate_venv() {
    venv=$OLLAMA_ENV_DIR

    if [[ -d "$venv" ]]; then
        echo "Activating virtual environment..."
        source "$venv/bin/activate"
    else
        echo "Virtual environment does not exist. Please create it first."
        exit 1
    fi
}

function create_venv() {
    venv=$OLLAMA_ENV_DIR

    if [[ -d "$venv" ]]; then
        echo "Virtual environment already exists..."
    else
        echo "Creating virtual environment..."
        python -m venv "$venv"

        activate_venv

        $venv/bin/python -m pip install --upgrade pip
        $venv/bin/python -m pip install -r requirements.txt
        $venv/bin/python -m pip freeze > pinned.txt
    fi
}

# -+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
# Main script
# -+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

main() {
    initialize_add_to_path "$OLLAMA_BIN_DIR/bin"
    # export LD_LIBRARY_PATH="$OLLAMA_BIN_DIR/lib/ollama:$LD_LIBRARY_PATH"

    # Ensure required directories exist:
    [[ ! -d "$OLLAMA_BIN_DIR" ]] && mkdir -p "$OLLAMA_BIN_DIR"
    [[ ! -d "$OLLAMA_TMP_DIR" ]] && mkdir -p "$OLLAMA_TMP_DIR"
    [[ ! -d "$OLLAMA_MODELS"  ]] && mkdir -p "$OLLAMA_MODELS"

    # Download and extract if required:
    if [[ ! -f "$OLLAMA_EXE_TAR" ]]; then
        echo "Downloading Ollama..."
        curl -L -o "$OLLAMA_EXE_TAR" "$OLLAMA_EXE_URL"
    fi

    if [[ ! -f "$OLLAMA_BIN_DIR/bin/ollama" ]]; then
        echo "Extracting Ollama..."
        tar -xzf "$OLLAMA_EXE_TAR" -C "$OLLAMA_BIN_DIR"
        chmod +x "$OLLAMA_BIN_DIR/bin/ollama"
    fi

    # Start server if required:
    start_ollama_server

    # Pull model if required:
    pull_ollama_model

    # Create virtual environment:
    create_venv
}

main

# -+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
#
# -+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
