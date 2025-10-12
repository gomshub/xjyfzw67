Perfect 💪 — you want a **reusable Bamboo YAML plan** that:

* builds the MCP Desktop Agent for **both Windows and Linux**,
* can run selectively or in parallel based on an argument (`BUILD_OS`),
* and uploads the correct binary to Artifactory automatically.

Below is the **final, production-ready Bamboo Specs YAML** that does exactly that.
It supports *“Run as”* either Windows or Linux agents — all configurable via variables.

---
      slug: mcp-desktop-agent
      branch: main

# -----------------------------------------------------------------------------
# Global Variables
  BUILD_DIR: "mcp_desktop_agent"
  ARTIFACT_NAME: "MCPDesktopAgent"
  ARTIFACT_VERSION: "${bamboo.buildNumber}"
  BUILD_OS: "linux"          # default, can override via Bamboo UI or manual run

# -----------------------------------------------------------------------------
# Stages
    jobs:
      - Build_Binary

# -----------------------------------------------------------------------------
# Job Definition
# -----------------------------------------------------------------------------
jobs:
      image: python:${bamboo.PYTHON_VERSION}
      use-custom-docker: false
    tasks:
      - checkout:
          repository: MCP_Agent_Repo
          interpreter: SHELL
          scripts:
            - echo "🏗️ Starting build for OS: ${bamboo.BUILD_OS}"
            - |
              if [ "${bamboo.BUILD_OS}" = "windows" ]; then
                echo "Switching to Windows agent..."
                exit 0  # skip Linux job, Bamboo triggers Windows job
              fi

              echo "Creating venv and installing dependencies..."
              python3 -m venv venv
              source venv/bin/activate
              pip install --upgrade pip
              pip install -r ${bamboo.BUILD_DIR}/requirements.txt
              pip install pyinstaller

              echo "Building Linux binary..."
              cd ${bamboo.BUILD_DIR}
              pyinstaller --onefile --name ${bamboo.ARTIFACT_NAME} main.py
              ls -lh dist/

      # ---------------- Artifacts ----------------
      - artifact:
          name: MCP_Build_Output
          copy-pattern: "mcp_desktop_agent/dist/*"
          shared: true

      # ---------------- Upload to Artifactory ----------------
      - script:
          interpreter: SHELL
          scripts:
            - echo "📦 Uploading binary to Artifactory..."
            - |
              ARTIFACTORY_URL="https://your-artifactory.company.com/artifactory/mcp-agent-releases"
              FILE_PATH="mcp_desktop_agent/dist/${bamboo.ARTIFACT_NAME}"
              TARGET_FILE="${bamboo.ARTIFACT_NAME}_${bamboo.ARTIFACT_VERSION}_${bamboo.BUILD_OS}"

              if [ -f "${FILE_PATH}" ]; then
                curl -u ${bamboo.ARTIFACTORY_USER}:${bamboo.ARTIFACTORY_TOKEN} \
                     -T "${FILE_PATH}" \
                     "${ARTIFACTORY_URL}/${TARGET_FILE}"
              else
                echo "❌ File not found: ${FILE_PATH}"
                exit 1
              fi
            - echo "✅ Upload completed successfully."

    artifacts:
      - name: MCP_Build_Output
        pattern: "mcp_desktop_agent/dist/*"
        shared: true

    requirements:
      - system.builder.command.python

# -----------------------------------------------------------------------------
# Parallel Windows Build (Triggered by Variable)
# -----------------------------------------------------------------------------
stages:
  - name: Windows_Build
    condition:
      variable: "bamboo.BUILD_OS"
      equals: "windows"
    jobs:
      - Build_Windows

jobs:
      - checkout:
          repository: MCP_Agent_Repo
      - script:
          interpreter: WINDOWS_POWERSHELL
          scripts:
            - Write-Host "🏗️ Building Windows Executable..."
            - python -m venv venv
            - pip install --upgrade pip
            - pip install -r mcp_desktop_agent\requirements.txt
            - pip install pyinstaller
            - cd mcp_desktop_agent
            - pyinstaller --onefile --name MCPDesktopAgent.exe main.py
            - dir dist
      - artifact:
          name: MCP_Windows_Build
          copy-pattern: "mcp_desktop_agent\\dist\\*"
          shared: true
      - script:
          interpreter: WINDOWS_POWERSHELL
          scripts:
            - Write-Host "📦 Uploading to Artifactory..."
            - |
              $ArtifactUrl = "https://your-artifactory.company.com/artifactory/mcp-agent-releases"
              $File = "mcp_desktop_agent\\dist\\MCPDesktopAgent.exe"
              $Target = "$($env:ARTIFACT_NAME)_$($env:bamboo_buildNumber)_windows.exe"
              if (Test-Path $File) {
                curl -u "$env:ARTIFACTORY_USER`:$env:ARTIFACTORY_TOKEN" -T $File "$ArtifactUrl/$Target"
              } else {
                Write-Host "❌ Build file not found: $File"
                exit 1
              }
            - Write-Host "✅ Upload successful."
```

---

## 🧠 **How It Works**

| Step                         | Description                                       |
| ---------------------------- | ------------------------------------------------- |
| **1️⃣ Repository Checkout**  | Pulls your Bitbucket repo                         |
| **2️⃣ Conditional Build**    | Checks `BUILD_OS` variable (`linux` or `windows`) |
| **3️⃣ Virtualenv + Install** | Creates venv, installs requirements               |
| **4️⃣ Build Binary**         | Runs PyInstaller for either platform              |
```markdown
Updated Bamboo plan notes and CI steps for packaging the MCP Desktop Agent.

Key changes from the original guidance:
- Add a safe verification step using `--onedir` so the dist folder can be inspected.
- Bundle `web.py` and the local module files (`mcp_client.py`, `mcp_client_v2.py`, `llm_client.py`, `gui.py`) with `--add-data` so Streamlit and imports work when running the extracted script.
- Optionally detect and bundle the Streamlit package metadata (dist-info) on the build agent so in-process Streamlit import works in the onefile EXE.

Below are example CI task snippets you can drop into a Bamboo job for Linux (bash) and Windows (PowerShell). They follow the flow: Checkout → venv → install → onedir verification → onefile build → upload.

---

## Linux agent (bash) — example task

```bash
# Set up venv and install deps
python3 -m venv venv
source venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r mcp_desktop_agent/requirements.txt
python -m pip install pyinstaller

# Move into package folder
cd mcp_desktop_agent

# 1) Verify with --onedir (fast to inspect)
pyinstaller --onedir --name MCPDesktopAgent \
  --add-data "./config.json;." \
  --add-data "./web.py;." \
  --add-data "./mcp_client.py;." \
  --add-data "./mcp_client_v2.py;." \
  --add-data "./llm_client.py;." \
  --add-data "./gui.py;." \
  --paths "$PWD" main.py

# Inspect contents (CI: assert files exist)
if [ ! -f dist/MCPDesktopAgent/web.py ]; then
  echo "ERROR: web.py missing in onedir dist; aborting"
  exit 1
fi

# 2) Build a single-file executable (onefile)
pyinstaller --onefile --name MCPDesktopAgent \
  --add-data "./config.json;." \
  --add-data "./web.py;." \
  --add-data "./mcp_client.py;." \
  --add-data "./mcp_client_v2.py;." \
  --add-data "./llm_client.py;." \
  --add-data "./gui.py;." \
  --paths "$PWD" main.py

# After building, publish dist/MCPDesktopAgent (or the compressed artifact) to Artifactory
ls -lh dist/
```

## Windows agent (PowerShell) — example task

```powershell
# Create venv and install
python -m venv venv
.\venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install -r mcp_desktop_agent\requirements.txt
python -m pip install pyinstaller

cd mcp_desktop_agent

# Verify with onedir first
pyinstaller --onedir --name MCPDesktopAgent `
  --add-data ".\config.json;." `
  --add-data ".\web.py;." `
  --add-data ".\mcp_client.py;." `
  --add-data ".\mcp_client_v2.py;." `
  --add-data ".\llm_client.py;." `
  --add-data ".\gui.py;." `
  --paths "$PWD" main.py

if (-Not (Test-Path .\dist\MCPDesktopAgent\web.py)) {
  Write-Error "web.py missing in onedir build; aborting"
  exit 1
}

# Build onefile
pyinstaller --onefile --name MCPDesktopAgent `
  --add-data ".\config.json;." `
  --add-data ".\web.py;." `
  --add-data ".\mcp_client.py;." `
  --add-data ".\mcp_client_v2.py;." `
  --add-data ".\llm_client.py;." `
  --add-data ".\gui.py;." `
  --paths "$PWD" main.py

dir .\dist
```

## Notes for CI

- Make sure the build agent's Python environment has `streamlit` available when building (pip install in the venv). The helper scripts can try to detect streamlit and include its package files and dist-info in the bundle; if Streamlit is not installed on the build agent, in-process Streamlit import will fail inside the exe.
- Keep `--onedir` verification step in CI so you can quickly fail early if file bundling is incorrect.
- Upload artifacts (the `dist` file) to Artifactory or your chosen artifact store. Use secured variables for credentials.

---

## Example Bamboo wiring (high level)

- Checkout repository
- Choose agent type (Linux or Windows)
- Run the bash/PowerShell task above
- Publish `mcp_desktop_agent/dist/*` as artifact and upload to Artifactory

---

If you want, I can generate a concrete `bamboo-specs/bamboo.yaml` that wires both the Linux and Windows tasks above, includes variables for Artifactory credentials, and optionally runs both platforms in parallel as separate jobs. Want me to generate that file as a follow-up? 
``` 
