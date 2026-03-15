#!/usr/bin/env bash
# ***
# Source this file with `source develop.sh`, do not execute directly.
# ^^^

FLAG_DEVELOP_MODE=true

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --install)
                FLAG_DEVELOP_MODE=false
                ;;
            *)
                echo "Unknown argument: $1" >&2
                exit 1
                ;;
        esac
        shift
    done
}

ensure_local_run() {
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    cd "${script_dir}" || {
        echo "Error: Cannot change to script directory: ${script_dir}" >&2
        exit 1
    }
}

enable_virtualenv() {
    if [ -n "$VIRTUAL_ENV" ]; then
        echo "In venv: $VIRTUAL_ENV"
        return 0
    fi

    if [ ! -d "venv" ]; then
        python3 -m venv "venv"
    fi

    source "venv/bin/activate"
    python -m pip install --upgrade pip
}

install_majordome() {
    local majordome=$1
    local wheel=$(ls -t ${majordome}/dist/*cp312*.whl 2>/dev/null | head -n1)

    if [ ! -f "${wheel}" ]; then
        echo "Error: Wheel file not found: ${wheel}" >&2
        exit 1
    fi

    python3 -m pip install "${wheel}"

    if [ $? -ne 0 ]; then
        echo "Error: pip install failed for ${wheel}" >&2
        exit 1
    fi
}

main() {
    ensure_local_run
    enable_virtualenv

    local majordome="$(realpath $PWD)/../python-majordome"

    if [ "${FLAG_DEVELOP_MODE}" = true ]; then
        echo "Development mode: ON"
        python3 -m pip install -e "${majordome}" --no-deps
    else
        echo "Installation mode: ON"
        install_majordome ${majordome}
        python3 -m pip install -r requirements.txt
    fi
}

main "$@"