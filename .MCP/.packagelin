#!/usr/bin/env bash
set -euo pipefail

# build.sh - Linux/macOS packaging script for MCP Desktop Agent
# Mirrors build.ps1 behavior: create venv, install deps, detect streamlit,
# include streamlit and dist-info via --add-data, and run pyinstaller.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
ROOT="$SCRIPT_DIR"
VENV_DIR="$ROOT/mcp_venv"
PYTHON=${PYTHON:-python3}

echo "[build.sh] Working directory: $ROOT"

# Create venv if missing
if [ ! -d "$VENV_DIR" ]; then
  echo "[build.sh] Creating virtualenv at $VENV_DIR"
  $PYTHON -m venv "$VENV_DIR"
else
  echo "[build.sh] Virtualenv already exists at $VENV_DIR"
fi

# Activate venv
# shellcheck disable=SC1091
source "$VENV_DIR/bin/activate"

# Upgrade pip and install requirements
echo "[build.sh] Installing requirements..."
python -m pip install --upgrade pip
if [ -f "$ROOT/requirements.txt" ]; then
  python -m pip install -r "$ROOT/requirements.txt"
else
  echo "[build.sh] WARNING: requirements.txt not found in $ROOT"
fi

# Optional: quick local test (uncomment to run)
# echo "[build.sh] Running quick local test: python main.py (Ctrl-C to stop)"
# python "$ROOT/main.py"

# Detect streamlit package path and site-packages
echo "[build.sh] Detecting Streamlit installation (if present)..."
STREAMLIT_PATH=""
SITE_PACKAGES=""
if python - <<'PY'
try:
    import streamlit, os
    p = os.path.dirname(streamlit.__file__)
    sp = os.path.dirname(os.path.dirname(streamlit.__file__))
    print(p)
    print(sp)
except Exception:
    pass
PY
then
    # capture output
    read -r STREAMLIT_PATH SITE_PACKAGES < <(python - <<'PY'
import streamlit, os
print(os.path.dirname(streamlit.__file__))
print(os.path.dirname(os.path.dirname(streamlit.__file__)))
PY
)
fi

if [ -n "$STREAMLIT_PATH" ]; then
  echo "[build.sh] Detected streamlit package at: $STREAMLIT_PATH"
  echo "[build.sh] Detected site-packages at: $SITE_PACKAGES"
else
  echo "[build.sh] Streamlit not detected in current environment. Skipping streamlit bundling." 
fi

# Find streamlit-*.dist-info directories (if site-packages found)\nDIST_INFOS=()
if [ -n "$SITE_PACKAGES" ] && [ -d "$SITE_PACKAGES" ]; then
  while IFS= read -r -d $'\0' d; do
    DIST_INFOS+=("$d")
  done < <(find "$SITE_PACKAGES" -maxdepth 1 -type d -name 'streamlit-*.dist-info' -print0 2>/dev/null || true)
  if [ ${#DIST_INFOS[@]} -gt 0 ]; then
    echo "[build.sh] Found dist-info directories:"
    for d in "${DIST_INFOS[@]}"; do echo "  $d"; done
  fi
fi

# Build PyInstaller arguments (Linux/macOS uses ':' separator for --add-data)
PY_ARGS=(
  --onefile
  --name MCPDesktopAgent
  --add-data "config.json:."
  --add-data "web.py:."
  --add-data "mcp_client.py:."
  --add-data "mcp_client_v2.py:."
  --add-data "llm_client.py:."
  --add-data "gui.py:."
)

# Include streamlit package if found
if [ -n "$STREAMLIT_PATH" ] && [ -d "$STREAMLIT_PATH" ]; then
  PY_ARGS+=( --add-data "$STREAMLIT_PATH:streamlit" )
  echo "[build.sh] Including streamlit package: $STREAMLIT_PATH"
fi

# Include dist-info directories
for d in "${DIST_INFOS[@]:-}"; do
  base=$(basename "$d")
  PY_ARGS+=( --add-data "$d:./$base" )
done

# Add paths and entrypoint
PY_ARGS+=( --paths "$ROOT" )
PY_ARGS+=( main.py )

echo "[build.sh] Running pyinstaller with args: ${PY_ARGS[*]}"

# Run pyinstaller
pyinstaller "${PY_ARGS[@]}"

echo "[build.sh] Build finished. Check $ROOT/dist for artifacts."

echo "[build.sh] Recommended: verify the onedir build first if you hit runtime issues (change --onefile to --onedir in PY_ARGS)."

# deactivate venv
deactivate || true
