<#
========================================================================
MCP Desktop Agent - All-in-One Setup, Test, and Build Script
========================================================================
Purpose      : Create dev folder structure, generate Python modules,
               config, READMEs, test locally, and build standalone .exe
Author       : Your Name / Team
Version      : 2.1
Created      : 2025-10-11
========================================================================
#>

# ---------------- Configuration ----------------
$ROOT = "$PWD\mcp_desktop_agent"

# ---------------- Step 1: Create folder structure ----------------
Write-Host "`n[Step 1] Creating development folder structure..."
New-Item -ItemType Directory -Path $ROOT -Force

# ---------------- Step 2: Generate Python Module Files ----------------
Write-Host "[Step 2] Generating Python module files..."

# ---------------- 2a: config.json ----------------
$CONFIG_FILE = Join-Path $ROOT "config.json"
$configContent = @'
{
  "USE_LLM_BACKEND": false,
  "USE_WEB_AGENT": false,
  "MCP_SERVER_URL": "http://onprem-mcp-server:8080",
  "LLM_MODEL_NAME": "amazon.titan-text-express-v1",
  "MCP_CLIENT_VERSION": "v1"
}

'@
$Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($CONFIG_FILE, $configContent, $Utf8NoBomEncoding)
Write-Host "config.json created as UTF-8 (no BOM) at $CONFIG_FILE"

# ---------------- 2b: mcp_client.py ----------------
Write-Host "[Step 2b] Generating mcp_client.py for basic flow..."
$mcp_clientContent  = @'
"""
MCP Client V1 for SSE communication
"""
import requests
from sseclient import SSEClient
import json

class MCPClient:
    def __init__(self, server_url: str):
        self.server_url = server_url.rstrip('/')
        self.tools = []

    def initialise(self):
        try:
            resp = requests.post(f'{self.server_url}/initialise', timeout=10)
            resp.raise_for_status()
            self.tools = resp.json().get('tools', [])
            return self.tools
        except requests.RequestException as e:
            return [f'[Error initialising MCP server: {e}]']

    def chat_stream(self, prompt: str):
        payload = {"prompt": prompt}
        try:
            sse = SSEClient(f'{self.server_url}/sse', data=json.dumps(payload))
            for msg in sse:
                if msg.data:
                    yield msg.data
        except Exception as e:
            yield f'[Error connecting to SSE: {e}]'
'@
$Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText("$ROOT\mcp_client.py", $mcp_clientContent, $Utf8NoBomEncoding)
Write-Host "mcp_client.py created as UTF-8 (no BOM) at $ROOT\mcp_client.py"


# ---------------- 2b: mcp_client_v2.py ----------------
Write-Host "[Step 2b] Generating mcp_client_v2.py for advanced SSE-first flow..."
$mcp_clientContentv2 = @'
""" 
MCP Client V2 for SSE-first communication flow.
1. Connects to /sse and gets session_id.
2. Uses session_id for POST /initialise and /notifications_initialise.
3. Keeps the SSE stream open to receive events.
"""
import requests
from sseclient import SSEClient
import json
import threading

class MCPClientAdvanced:
    def __init__(self, server_url: str):
        self.server_url = server_url.rstrip('/')
        self.session_id = None
        self.stream_thread = None
        self.active = False

    def _listen_sse(self):
        """Internal method to listen continuously to /sse stream."""
        try:
            print("🛰️ Connecting to SSE stream...")
            sse = SSEClient(f'{self.server_url}/sse')
            for msg in sse:
                if msg.data:
                    try:
                        data = json.loads(msg.data)
                        if not self.session_id and "session_id" in data:
                            self.session_id = data["session_id"]
                            print(f"✅ Session initialized: {self.session_id}")
                        yield msg.data
                    except json.JSONDecodeError:
                        yield msg.data
        except Exception as e:
            yield f"[SSE error: {e}]"

    def initialise(self):
        """Send POST /initialise once session_id is obtained."""
        if not self.session_id:
            print("⚠️ No session_id yet. SSE stream must start first.")
            return None
        try:
            payload = {"session_id": self.session_id}
            resp = requests.post(f'{self.server_url}/initialise', json=payload, timeout=10)
            resp.raise_for_status()
            return resp.json()
        except requests.RequestException as e:
            return {"error": f"Error during initialise: {e}"}

    def start_notifications(self):
        """Send POST /notifications_initialise to subscribe for updates."""
        if not self.session_id:
            print("⚠️ No session_id yet. SSE stream must start first.")
            return None
        try:
            payload = {"session_id": self.session_id, "subscribe": True}
            resp = requests.post(f'{self.server_url}/notifications_initialise', json=payload, timeout=10)
            resp.raise_for_status()
            return resp.json()
        except requests.RequestException as e:
            return {"error": f"Error during notifications_initialise: {e}"}

    def start_stream(self, on_message):
        """Start SSE stream in background thread and call on_message(msg) for each event."""
        def run_stream():
            for msg in self._listen_sse():
                on_message(msg)
        self.active = True
        self.stream_thread = threading.Thread(target=run_stream, daemon=True)
        self.stream_thread.start()

    def chat_stream(self, prompt: str):
        """Example send-prompt logic after initialization."""
        if not self.session_id:
            yield "[Error: No active session]"
            return
        try:
            payload = {"session_id": self.session_id, "prompt": prompt}
            resp = requests.post(f'{self.server_url}/chat', json=payload, timeout=15)
            resp.raise_for_status()
            yield from self._listen_sse()
        except Exception as e:
            yield f"[Error sending chat prompt: {e}]"
'@
$Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText("$ROOT\mcp_client_v2.py", $mcp_clientContentv2, $Utf8NoBomEncoding)            
Write-Host "mcp_client_v2.py created as UTF-8 (no BOM) at $ROOT\mcp_client_v2.py"

# ---------------- 2c: llm_client.py ----------------
$llm_clientContent = @'
"""
LLM Client for AWS Bedrock
"""
import boto3
import json
from botocore.exceptions import ClientError

class LLMClient:
    def __init__(self, model_id: str):
        self.model_id = model_id
        self.client = boto3.client('bedrock-runtime')

    def send_prompt(self, prompt: str):
        try:
            response = self.client.invoke_model(
                modelId=self.model_id,
                body=json.dumps({'prompt': prompt}),
                contentType='application/json',
                accept='application/json'
            )
            return response['body'].read().decode('utf-8')
        except ClientError as e:
            return f'Error invoking model: {e}'
'@
$Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText("$ROOT\llm_client.py", $llm_clientContent, $Utf8NoBomEncoding)
Write-Host "llm_client.py created as UTF-8 (no BOM) at $ROOT\llm_client.py"


# ---------------- 2d: gui.py ----------------
$GUI_PY = @"
import tkinter as tk
import threading
import pyperclip


class ChatGUI:
    def __init__(self, send_callback):
        self.send_callback = send_callback
        self.root = tk.Tk()
        self.root.title('MCP Desktop Agent')
        self.root.geometry('800x600')

        # Chat Canvas + Scrollbar
        self.chat_canvas = tk.Canvas(self.root)
        self.chat_scroll = tk.Scrollbar(self.root, orient='vertical', command=self.chat_canvas.yview)
        self.chat_frame = tk.Frame(self.chat_canvas)
        self.chat_frame.bind('<Configure>', lambda e: self.chat_canvas.configure(scrollregion=self.chat_canvas.bbox('all')))
        self.chat_canvas.create_window((0, 0), window=self.chat_frame, anchor='nw')
        self.chat_canvas.configure(yscrollcommand=self.chat_scroll.set)
        self.chat_canvas.pack(side='left', fill='both', expand=True, padx=(10, 0), pady=10)
        self.chat_scroll.pack(side='right', fill='y', pady=10)

        # Bottom controls (on root)
        self.bottom_frame = tk.Frame(self.root)
        self.bottom_frame.pack(fill='x', padx=10, pady=(0, 10))
        self.copy_all_btn = tk.Button(self.bottom_frame, text='📋 Copy Full Chat', command=self.copy_full_chat)
        self.copy_all_btn.pack(side='left', padx=(0, 5))
        self.clear_chat_btn = tk.Button(self.bottom_frame, text='🗑️ Clear Chat', command=self.clear_chat)
        self.clear_chat_btn.pack(side='left', padx=(0, 5))
        self.expand_all_btn = tk.Button(self.bottom_frame, text='🔽 Expand All', command=self.expand_all)
        self.expand_all_btn.pack(side='left', padx=(0, 5))
        self.collapse_all_btn = tk.Button(self.bottom_frame, text='🔼 Collapse All', command=self.collapse_all)
        self.collapse_all_btn.pack(side='left', padx=(0, 5))

        # Message storage and widget refs
        self.history = []
        # each entry: (container_frame, content_frame, toggle_button)
        self.message_frames = []

        # Initial bold welcome
        self.insert_initial_message(
            "MCP Desktop Agent is ready! – Ask information about data and the services available in Pamcore."
        )

        # ---------------- Input Frame (inside chat area, aligned right-to-left) ----------------
        self.input_frame = tk.Frame(self.chat_frame)
        self.input_frame.pack(fill='x', padx=5, pady=5)
        # place send button on the right, input to its left; justify right so text aligns to right edge
        self.send_btn = tk.Button(self.input_frame, text='Send', command=self.send_prompt)
        self.send_btn.pack(side='right', padx=(0, 5))
        self.input_box = tk.Entry(self.input_frame, justify='right')
        self.input_box.pack(side='right', fill='x', expand=True)
        self.input_box.bind('<Return>', self.send_prompt)

    # ---------------- Initial Message ----------------
    def insert_initial_message(self, message):
        frame = tk.Frame(self.chat_frame)
        frame.pack(fill='x', pady=2)
        lbl = tk.Label(frame, text=message, font=('TkDefaultFont', 10, 'bold'), wraplength=700, justify='left')
        lbl.pack(side='left', fill='x', expand=True)
        self.message_frames.append((frame, None, None))  # initial message not collapsible
        self.chat_canvas.update_idletasks()
        self.chat_canvas.yview_moveto(1.0)

    # ---------------- Insert Message ----------------
    def insert_message(self, sender, message, expand=True):
        container = tk.Frame(self.chat_frame, bd=1, relief='flat')
        container.pack(fill='x', padx=5, pady=2, anchor='w')

        header = tk.Frame(container)
        header.pack(fill='x')
        sender_label = tk.Label(header, text=f'{sender}:', font=('Arial', 10, 'bold'))
        sender_label.pack(side='left')

        toggle_btn = tk.Button(header, text='[-]' if expand else '[+]', width=3)
        toggle_btn.pack(side='right')

        content_frame = tk.Frame(container)
        if expand:
            content_frame.pack(fill='x')
        else:
            content_frame.pack_forget()

        msg_label = tk.Label(content_frame, text=message, wraplength=700, justify='left')
        msg_label.pack(side='left', fill='x', expand=True)

        copy_btn = tk.Button(content_frame, text='📋 Copy', command=lambda msg=message: self.copy_message(msg))
        copy_btn.pack(side='right')

        def toggle():
            if content_frame.winfo_ismapped():
                content_frame.pack_forget()
                toggle_btn.config(text='[+]')
            else:
                content_frame.pack(fill='x')
                toggle_btn.config(text='[-]')

        toggle_btn.config(command=toggle)

        # store refs
        self.message_frames.append((container, content_frame, toggle_btn))
        self.history.append((sender, message))

        # ensure most recent expanded
        self.ensure_recent_expanded()

        self.chat_canvas.update_idletasks()
        self.chat_canvas.yview_moveto(1.0)

    # ---------------- Expand / Collapse / Helpers ----------------
    def expand_all(self):
        for _, content, btn in self.message_frames[1:]:
            if content and not content.winfo_ismapped():
                content.pack(fill='x')
            if btn:
                btn.config(text='[-]')

    def collapse_all(self):
        # collapse all except the most recent
        for i, (container, content, btn) in enumerate(self.message_frames[1:], start=1):
            if i == len(self.message_frames) - 1:
                # keep latest expanded
                if content and not content.winfo_ismapped():
                    content.pack(fill='x')
                if btn:
                    btn.config(text='[-]')
            else:
                if content and content.winfo_ismapped():
                    content.pack_forget()
                if btn:
                    btn.config(text='[+]')

    def ensure_recent_expanded(self):
        if len(self.message_frames) <= 1:
            return
        # expand the latest message (skip the initial welcome at index 0)
        last_container, last_content, last_btn = self.message_frames[-1]
        if last_content and not last_content.winfo_ismapped():
            last_content.pack(fill='x')
        if last_btn:
            last_btn.config(text='[-]')

    # ---------------- Copy / Clear ----------------
    def copy_message(self, msg):
        pyperclip.copy(msg)

    def copy_full_chat(self):
        pyperclip.copy('\n\n'.join([f'{s}: {m}' for s, m in self.history]))

    def clear_chat(self):
        # destroy message widgets except initial welcome
        for container, _, _ in self.message_frames[1:]:
            container.destroy()
        self.message_frames = self.message_frames[:1]
        self.history = []

    # ---------------- Send Prompt ----------------
    def send_prompt(self, event=None):
        prompt = self.input_box.get().strip()
        if not prompt:
            return
        self.input_box.delete(0, tk.END)  # auto-clear input
        self.insert_message('You', prompt, expand=True)

        def run_stream():
            response = self.send_callback(prompt)
            resp_text = ''
            if hasattr(response, '__iter__') and not isinstance(response, str):
                for token in response:
                    resp_text += token
                    # update latest MCP message while streaming
                    # if last item is MCP, replace it, else append
                    if self.history and self.history[-1][0] == 'MCP':
                        # replace message text in place by removing and reinserting widget
                        # simple approach: append new MCP message each time for visibility
                        self.insert_message('MCP', resp_text, expand=True)
                    else:
                        self.insert_message('MCP', resp_text, expand=True)
            else:
                self.insert_message('MCP', response, expand=True)

        threading.Thread(target=run_stream, daemon=True).start()

    # ---------------- Run GUI ----------------
    def run(self):
        self.root.mainloop()
"@
[System.IO.File]::WriteAllText("$ROOT\gui.py", $GUI_PY, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "✅ gui.py updated with auto-clear, proper alignment, recent messages expanded, emojis"

# ---------------- 2e: main.py ----------------
# ---------------- Step: Generate updated main.py ----------------
# ---------------- Step: Generate main.py with GUI or Browser (Web) Agent toggle----------------
Write-Host "[Step X] Generating updated main.py with GUI or Browser (Web) Agent toggle..."

$mainContent = @'
"""
Main entry point for MCP Desktop Agent
Supports GUI or Browser (Web) Agent toggle.
Supports:
- CLI arg --config for custom config.json
- CLI arg --mode gui|browser (defaults to gui)
- Automatic bundled config for PyInstaller
"""
import os
import sys
import json
import argparse
import threading
import time
from http.server import SimpleHTTPRequestHandler, HTTPServer
import webbrowser
import subprocess

from mcp_client import MCPClient
from mcp_client_v2 import MCPClientAdvanced
from llm_client import LLMClient
from gui import ChatGUI

# ---------------- Parse CLI arguments ----------------
parser = argparse.ArgumentParser(description='MCP Desktop Agent')
parser.add_argument('--config', type=str, default=None, help='Path to custom config.json')
args = parser.parse_args()

# ---------------- Determine config file ----------------
if args.config:
    CONFIG_FILE = args.config
else:
    if getattr(sys, 'frozen', False):
        CONFIG_FILE = os.path.join(sys._MEIPASS, 'config.json')
    else:
        CONFIG_FILE = os.path.join(os.path.dirname(__file__), 'config.json')

cfg = {}
if os.path.exists(CONFIG_FILE) and os.path.getsize(CONFIG_FILE) > 0:
    try:
        with open(CONFIG_FILE, 'r', encoding='utf-8-sig') as f:
            cfg = json.load(f)
    except json.JSONDecodeError as e:
        print(f"[!] Error reading config.json: {e}")
else:
    print(f"[!] Config file missing or empty at {CONFIG_FILE}")

print(f"[i] Using config file: {CONFIG_FILE}")

# ---------------- Read config values ----------------
USE_LLM_BACKEND = cfg.get('USE_LLM_BACKEND', False)
USE_WEB_AGENT = cfg.get('USE_WEB_AGENT', False)
MCP_SERVER_URL = cfg.get('MCP_SERVER_URL', 'http://localhost:8080')
LLM_MODEL_NAME = cfg.get('LLM_MODEL_NAME', 'amazon.llm-express-v1')
mcp_client_version = cfg.get('MCP_CLIENT_VERSION', 'v1')
print(f"[i] MCP Client Version: {mcp_client_version}")

# ---------------- Backend selection ----------------
if USE_LLM_BACKEND:
    llm_client = LLMClient(LLM_MODEL_NAME)
    send_callback = lambda prompt: llm_client.send_prompt(prompt)
else:
    print(f"[i] Connecting to MCP server at {MCP_SERVER_URL}...")
    if mcp_client_version == 'v1':
         mcp_client = MCPClient(MCP_SERVER_URL)
         mcp_client.initialise()
         send_callback = mcp_client.chat_stream
    else:
        print(f"[i] Using advanced MCP Client Version: {mcp_client_version}")
        mcp_client = MCPClientAdvanced(MCP_SERVER_URL)

        # Step 1: Start SSE stream in background
        mcp_client.start_stream(lambda msg: print(f"[SSE] {msg}"))

        # Step 2: Wait for session_id and initialize
        time.sleep(2)
        init_resp = mcp_client.initialise()
        notif_resp = mcp_client.start_notifications()
        print(f"✅  MCP init: {init_resp}")
        print(f"✅  MCP notifications: {notif_resp}")

        send_callback = mcp_client.chat_stream

# ---------------- UI selection ----------------
if USE_WEB_AGENT:
    print("[🌐] Starting Browser Agent...")
    subprocess.run([
    "streamlit",
    "run",
    os.path.join(os.path.dirname(__file__), "web.py")
    ])

else:
    print("[🖥️] Launching GUI Agent...")
    gui = ChatGUI(send_callback=send_callback) 
    gui.run()
'@
$Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText("$ROOT\main.py", $mainContent, $Utf8NoBomEncoding)
Write-Host "main.py created as UTF-8 (no BOM) at $ROOT\main.py"


# ---------------- 2f: web.py ----------------
Write-Host "[Step 2f] Generating web.py for interactive browser agent..."
# ---------------- 2i: web.py ----------------
$WEB_FILE = Join-Path $ROOT "web.py"

$webContent = @'
import sys
import os
import json
import streamlit as st
import time
from mcp_client import MCPClient
from mcp_client_v2 import MCPClientAdvanced
from llm_client import LLMClient
import pyperclip

# ---------------- Load config ----------------
if getattr(sys, 'frozen', False):
    CONFIG_FILE = os.path.join(sys._MEIPASS, 'config.json')
else:
    CONFIG_FILE = os.path.join(os.path.dirname(__file__), 'config.json')

with open(CONFIG_FILE, 'r', encoding='utf-8-sig') as f:
    cfg = json.load(f)

USE_LLM_BACKEND = cfg.get('USE_LLM_BACKEND', False)
MCP_SERVER_URL = cfg.get('MCP_SERVER_URL', 'http://localhost:8080')
LLM_MODEL_NAME = cfg.get('LLM_MODEL_NAME', 'amazon.titan-text-express-v1')
mcp_client_version = cfg.get('MCP_CLIENT_VERSION', 'v1')
print(f"[i] MCP Client Version: {mcp_client_version}")
# ---------------- Initialize backend ----------------
if USE_LLM_BACKEND:
    llm_client = LLMClient(LLM_MODEL_NAME)
    send_callback = lambda prompt: llm_client.send_prompt(prompt)
else:
    print(f"[i] Connecting to MCP server at {MCP_SERVER_URL}...")
    if mcp_client_version == 'v1':
        mcp_client = MCPClient(MCP_SERVER_URL)
        mcp_client.initialise()
        send_callback = mcp_client.chat_stream 
    else:
        print(f"[i] Using advanced MCP Client Version: {mcp_client_version}")
        mcp_client = MCPClientAdvanced(MCP_SERVER_URL)

        # Step 1: Start SSE stream in background
        mcp_client.start_stream(lambda msg: print(f"[SSE] {msg}"))

        # Step 2: Wait for session_id and initialize
        time.sleep(2)
        init_resp = mcp_client.initialise()
        notif_resp = mcp_client.start_notifications()
        print(f"✅  MCP init: {init_resp}")
        print(f"✅  MCP notifications: {notif_resp}")

        send_callback = mcp_client.chat_stream

# ---------------- Streamlit UI ----------------
st.set_page_config(page_title='MCP Browser Agent', layout='wide')
st.title('MCP Browser Agent')

# ---------------- Session State ----------------
if 'history' not in st.session_state:
    st.session_state.history = []
if 'expanded' not in st.session_state:
    st.session_state.expanded = []

# ---------------- Input Form ----------------
with st.form('prompt_form', clear_on_submit=True):
    prompt = st.text_input('Ask information about data and the services available in Pamcore:', key='prompt_input')
    submitted = st.form_submit_button('Send')
    if submitted and prompt:
        st.session_state.history.append(('You', prompt))
        st.session_state.expanded.append(True)  # user message expanded

        # Stream response
        resp_text = ''
        for token in send_callback(prompt):
            resp_text += token
            if st.session_state.history and st.session_state.history[-1][0] == 'MCP':
                st.session_state.history[-1] = ('MCP', resp_text)
            else:
                st.session_state.history.append(('MCP', resp_text))
                st.session_state.expanded.append(True)

# ---------------- Bottom Buttons ----------------
def clear_history_cb():
    st.session_state.history = []
    st.session_state.expanded = []

def expand_all_cb():
    st.session_state.expanded = [True] * len(st.session_state.history)

def collapse_all_cb():
    n = len(st.session_state.history)
    if n == 0:
        st.session_state.expanded = []
    elif n == 1:
        st.session_state.expanded = [True]
    else:
        st.session_state.expanded = [False] * (n-1) + [True]

col1, col2, col3, col4 = st.columns(4)
with col1:
    st.button('🗑️ Clear Chat History', key='clear_history', on_click=clear_history_cb)
with col2:
    full_chat = '\n\n'.join([f'{s}: {m}' for s, m in st.session_state.history])
    st.download_button(
        label='📋 Copy Full Chat History',
        data=full_chat,
        file_name='full_chat_history.txt',
        mime='text/plain'
    )
with col3:
    st.button('🔽 Expand All', key='expand_all_btn', on_click=expand_all_cb)
with col4:
    st.button('🔼 Collapse All', key='collapse_all_btn', on_click=collapse_all_cb)

chat_container = st.container()
with chat_container:
    for i, (sender, msg) in enumerate(st.session_state.history):
        # ensure expanded list has entry for this index
        if i >= len(st.session_state.expanded):
            st.session_state.expanded.append(False)
        # Last conversation expanded by default
        default_expanded = True if i >= len(st.session_state.history)-2 else False
        # use explicit stored state if present, otherwise use default
        expanded = st.session_state.expanded[i] if i < len(st.session_state.expanded) else default_expanded
        # update stored expanded state to the resolved value
        st.session_state.expanded[i] = expanded
        with st.expander(f'{sender}', expanded=expanded):
            st.markdown(msg)
            # Copy to clipboard button
            if st.button(f'📋 Copy', key=f'copy_{i}'):
                pyperclip.copy(msg)

'@
# ---------------- Write web.py without BOM ----------------
$Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($WEB_FILE, $webContent, $Utf8NoBomEncoding)

Write-Host "✅ web.py generated successfully at $WEB_FILE with UTF-8 (no BOM) and emojis preserved."


# ---------------- 2f: requirements.txt ----------------
$requirementsContent = @'
requests==2.32.5
sseclient-py==1.8.0
boto3==1.40.50
botocore==1.40.50
urllib3<1.27,>=1.25.4
pyinstaller==6.16.0
altgraph==0.17.4
pywin32-ctypes==0.2.3
pyperclip==1.8.2
streamlit==1.26.1
'@
[System.IO.File]::WriteAllText((Join-Path $ROOT 'requirements.txt'), $requirementsContent, $Utf8NoBomEncoding)

# ---------------- 2g: README.md ----------------
$readmeContent = @'
# MCP Desktop Agent - Business User Guide

## Overview
Desktop GUI agent to connect to on-prem MCP server or AWS Bedrock LLM. No Python needed.

## Usage
### Windows
Double-click MCPDesktopAgent.exe after placing config.json next to it.

### Linux
Make binary executable (chmod +x) and run after placing config.json next to it.

## Notes
- Network access to MCP server required
- AWS credentials needed for LLM backend
'@
[System.IO.File]::WriteAllText((Join-Path $ROOT 'README.md'), $readmeContent, $Utf8NoBomEncoding)

# ---------------- 2h: README_DEV.md ----------------
$readmeDevContent = @'
# MCP Desktop Agent - Developer Guide

## Local Test
1. Activate Python venv
2. pip install -r requirements.txt
3. python main.py

## Build Executable
### Windows
pyinstaller --onedir --name MCPDesktopAgent --add-data "config.json;." --add-data "web.py;." --paths "$PWD" main.py

### Linux
pyinstaller --onedir --name MCPDesktopAgent --add-data "config.json:." --add-data "web.py:." --paths "$PWD" main.py

## Config
- config.json next to executable controls USE_LLM_BACKEND, MCP_SERVER_URL, LLM_MODEL_NAME
'@
[System.IO.File]::WriteAllText((Join-Path $ROOT 'README_DEV.md'), $readmeDevContent, $Utf8NoBomEncoding)

# ---------------- Step 3: Create and activate virtual environment ----------------
# ---------------- 2x: Re-encode generated files to UTF-8 (no BOM) ----------------
Write-Host "[Step 2x] Re-encoding generated files to UTF-8 (no BOM) to preserve emojis and Unicode characters..."
$filesToFix = @(
    (Join-Path $ROOT 'main.py'),
    (Join-Path $ROOT 'web.py'),
    (Join-Path $ROOT 'gui.py'),
    (Join-Path $ROOT 'mcp_client.py'),
    (Join-Path $ROOT 'mcp_client_v2.py'),
    (Join-Path $ROOT 'llm_client.py'),
    (Join-Path $ROOT 'requirements.txt'),
    (Join-Path $ROOT 'README.md'),
    (Join-Path $ROOT 'README_DEV.md')
)

foreach ($f in $filesToFix) {
    if (Test-Path $f) {
        try {
            $content = [System.IO.File]::ReadAllText($f)
            [System.IO.File]::WriteAllText($f, $content, $Utf8NoBomEncoding)
            Write-Host "Re-encoded: $f"
        } catch {
            Write-Warning "Failed to re-encode $f : $_"
        }
    } else {
        Write-Host "Skipping (not found): $f"
    }
}

# ---------------- Step 3: Create and activate virtual environment ----------------
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Definition
$VENV_PATH = Join-Path $SCRIPT_DIR "mcp_venv"

if (-Not (Test-Path $VENV_PATH)) {
    python -m venv $VENV_PATH
    Write-Host "Virtual environment created at $VENV_PATH"
} else {
    Write-Host "Virtual environment already exists at $VENV_PATH"
}
& "$VENV_PATH\Scripts\Activate.ps1"

# ---------------- Step 3.1: Install dependencies ----------------
python -m pip install --upgrade pip
python -m pip install -r "$ROOT\requirements.txt"

# ---------------- Step 4: Test Locally ----------------
Write-Host "`n[Step 4] Testing Python module locally..."
python "$ROOT\main.py"

# ---------------- Step 5: Build Executable ----------------
Write-Host "`n[Step 5] Building standalone Windows executable (onefile)..."
cd $ROOT

# Attempt to detect streamlit installation path so we can bundle streamlit runtime files
Write-Host "[Step 5a] Detecting streamlit package (to include runtime files)..."
$streamlitPath = $null
$sitePackages = $null
try {
    $pyOut = & python -c "import streamlit, os; print(os.path.dirname(streamlit.__file__)); print(os.path.dirname(os.path.dirname(streamlit.__file__)))" 2>$null
    if ($LASTEXITCODE -eq 0 -and $pyOut) {
        $lines = $pyOut -split "`n"
        if ($lines.Count -ge 2) {
            $streamlitPath = $lines[0].Trim()
            $sitePackages = $lines[1].Trim()
            Write-Host "Detected streamlit package at: $streamlitPath"
            Write-Host "Detected site-packages at: $sitePackages"
        }
    }
} catch {
    Write-Warning "Could not detect streamlit package automatically: $_"
}

# Collect dist-info directories for streamlit (if any)
$distInfos = @()
if ($sitePackages -and (Test-Path $sitePackages)) {
    try {
        $distInfos = Get-ChildItem -Path $sitePackages -Filter "streamlit-*.dist-info" -ErrorAction SilentlyContinue
        foreach ($d in $distInfos) { Write-Host "Found dist-info: $($d.FullName)" }
    } catch {
        Write-Warning "Error enumerating dist-info: $_"
    }
}

# Build pyinstaller argument list
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
    $pyArgs += '--add-data';
    $pyArgs += "${streamlitPath};streamlit"
    Write-Host "Including streamlit package in bundle: $streamlitPath"
}
foreach ($d in $distInfos) {
    $pyArgs += '--add-data'
    $pyArgs += "$($d.FullName);$($d.Name)"
}

$pyArgs += '--paths'; $pyArgs += "$PWD"; $pyArgs += 'main.py'

Write-Host "Running pyinstaller with arguments: $($pyArgs -join ' ')"
pyinstaller @pyArgs

Write-Host "`nWindows EXE built at: $ROOT\dist\MCPDesktopAgent.exe"

# ---------------- Step 6: Generate execution README in dist ----------------
$DIST_PATH = Join-Path $ROOT "dist"
if (-Not (Test-Path $DIST_PATH)) { New-Item -ItemType Directory -Path $DIST_PATH -Force | Out-Null }

$EXEC_README = @"
# MCP Desktop Agent - Execution Guide

## Windows
cd <dist folder>
.\MCPDesktopAgent.exe
Optional: .\MCPDesktopAgent.exe --config <custom config.json>

## Linux
cd <dist folder>
chmod +x MCPDesktopAgent
./MCPDesktopAgent
Optional: ./MCPDesktopAgent --config <custom config.json>
"@
[System.IO.File]::WriteAllText((Join-Path $DIST_PATH "README.md"), $EXEC_README, $Utf8NoBomEncoding)

Write-Host "`nAll steps completed successfully. Dist folder ready with binary and README."
