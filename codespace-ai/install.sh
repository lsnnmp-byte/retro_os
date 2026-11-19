#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${CODESPACE_NAME:-}" ]]; then
  echo "Run this inside your GitHub Codespace terminal."
  exit 1
fi

WORKSPACE="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
APP_DIR="$HOME/.codespace-ai"
mkdir -p "$APP_DIR"
python3 -m venv "$APP_DIR/venv"
"$APP_DIR/venv/bin/pip" -q install --upgrade pip
"$APP_DIR/venv/bin/pip" -q install "mcp[cli]" uvicorn starlette

cat > "$APP_DIR/server.py" <<'PY'
import os
import secrets
import subprocess
from pathlib import Path

from starlette.types import ASGIApp, Receive, Scope, Send
from mcp.server.fastmcp import FastMCP
import uvicorn

WORKSPACE = Path(os.environ.get("CODESPACE_WORKSPACE", os.getcwd())).resolve()
TOKEN = os.environ["CODESPACE_AI_TOKEN"]
PORT = int(os.environ.get("PORT", "8000"))

mcp = FastMCP("CodeSpace AI", host="0.0.0.0", port=PORT)

def safe_path(relative: str) -> Path:
    target = (WORKSPACE / relative).resolve()
    if target != WORKSPACE and WORKSPACE not in target.parents:
        raise ValueError("Path must stay inside the Codespace workspace.")
    return target

@mcp.tool()
def workspace_info() -> dict:
    """Show the connected Codespace workspace path and current Git branch."""
    branch = subprocess.run(["git", "-C", str(WORKSPACE), "branch", "--show-current"],
                            capture_output=True, text=True).stdout.strip()
    return {"workspace": str(WORKSPACE), "branch": branch}

@mcp.tool()
def list_files(path: str = ".", limit: int = 200) -> list:
    """List files and folders inside the workspace. Hidden files are omitted."""
    folder = safe_path(path)
    if not folder.is_dir():
        raise ValueError("Not a directory.")
    items = []
    for item in sorted(folder.iterdir(), key=lambda p: (p.is_file(), p.name.lower()))[:max(1, min(limit, 500))]:
        items.append({"name": item.name, "type": "directory" if item.is_dir() else "file"})
    return items

@mcp.tool()
def read_file(path: str) -> str:
    """Read a UTF-8 text file inside the workspace (up to 1 MB)."""
    target = safe_path(path)
    if not target.is_file():
        raise ValueError("File not found.")
    if target.stat().st_size > 1_000_000:
        raise ValueError("File is larger than 1 MB.")
    return target.read_text(encoding="utf-8")

@mcp.tool()
def write_file(path: str, content: str) -> str:
    """Create or replace a UTF-8 text file inside the workspace."""
    target = safe_path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(content, encoding="utf-8")
    return f"Saved {path} ({len(content)} characters)."

@mcp.tool()
def run_terminal(command: str, timeout_seconds: int = 60) -> dict:
    """Run a terminal command in the workspace. Ask for confirmation before destructive commands."""
    if not command.strip():
        raise ValueError("Command cannot be empty.")
    timeout = max(1, min(timeout_seconds, 120))
    result = subprocess.run(command, shell=True, cwd=str(WORKSPACE),
                            capture_output=True, text=True, timeout=timeout)
    return {"exit_code": result.returncode, "stdout": result.stdout[-20000:],
            "stderr": result.stderr[-10000:]}

class BearerAuth:
    def __init__(self, app: ASGIApp, token: str):
        self.app, self.token = app, token.encode()

    async def __call__(self, scope: Scope, receive: Receive, send: Send):
        if scope["type"] == "http":
            headers = dict(scope.get("headers", []))
            auth = headers.get(b"authorization", b"")
            expected = b"Bearer " + self.token
            if not secrets.compare_digest(auth, expected):
                body = b"Unauthorized"
                await send({"type": "http.response.start", "status": 401,
                            "headers": [(b"content-type", b"text/plain"),
                                        (b"content-length", str(len(body)).encode())]})
                await send({"type": "http.response.body", "body": body})
                return
        await self.app(scope, receive, send)

if __name__ == "__main__":
    app = BearerAuth(mcp.streamable_http_app(), TOKEN)
    print(f"CodeSpace AI MCP listening on 0.0.0.0:{PORT}")
    uvicorn.run(app, host="0.0.0.0", port=PORT, log_level="info")
PY

TOKEN="$(python3 -c 'import secrets; print(secrets.token_urlsafe(32))')"
cat > "$APP_DIR/.env" <<EOF
CODESPACE_AI_TOKEN=$TOKEN
CODESPACE_WORKSPACE=$WORKSPACE
EOF
chmod 600 "$APP_DIR/.env"

echo
echo "CodeSpace AI is starting."
echo "Workspace: $WORKSPACE"
echo "MCP endpoint: https://${CODESPACE_NAME}-8000.app.github.dev/mcp"
echo "Bearer token (keep private): $TOKEN"
echo
echo "Port 8000 remains private by default. Do not make it public unless you understand the access implications."
set -a
source "$APP_DIR/.env"
set +a
exec "$APP_DIR/venv/bin/python" "$APP_DIR/server.py"
