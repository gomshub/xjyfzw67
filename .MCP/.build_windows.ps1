# Navigate to project folder
cd path\to\repo

# Run PyInstaller with automatic Streamlit detection
$streamlitPath = $null
$sitePackages = $null
try {
    $pyOut = & python -c "import streamlit, os; print(os.path.dirname(streamlit.__file__)); print(os.path.dirname(os.path.dirname(streamlit.__file__)))" 2>$null
    if ($LASTEXITCODE -eq 0 -and $pyOut) {
        $lines = $pyOut -split "`n"
        if ($lines.Count -ge 2) {
            $streamlitPath = $lines[0].Trim()
            $sitePackages = $lines[1].Trim()
        }
    }
} catch {}

# Collect dist-info directories
$distInfos = @()
if ($sitePackages -and (Test-Path $sitePackages)) {
    $distInfos = Get-ChildItem -Path $sitePackages -Filter "streamlit-*.dist-info" -ErrorAction SilentlyContinue
}

# Build pyinstaller args
$pyArgs = @(
    '--onefile',
    '--name', 'MCPDesktopAgent',
    '--add-data', 'config.json;.',
    '--add-data', 'web.py;.',
    '--add-data', 'mcp_client.py;.',
    '--add-data', 'mcp_client_v2.py;.',
    '--add-data', 'llm_client.py;.',
    '--add-data', 'gui.py;.'
)

if ($streamlitPath -and (Test-Path $streamlitPath)) {
    $pyArgs += '--add-data'
    $pyArgs += "${streamlitPath};streamlit"
}
foreach ($d in $distInfos) {
    $pyArgs += '--add-data'
    $pyArgs += "$($d.FullName);$($d.Name)"
}

$pyArgs += '--paths'
$pyArgs += "$PWD"
$pyArgs += 'main.py'

# Run PyInstaller
pyinstaller @pyArgs
