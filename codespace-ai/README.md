# CodeSpace AI bootstrap

This branch adds a small Streamable HTTP MCP server for the current Codespace workspace.

## Start
Run the one-line command from the repository root in a GitHub Codespace:

```bash
curl -fsSL https://raw.githubusercontent.com/lsnnmp-byte/retro_os/codespace-ai/bootstrap/codespace-ai/install.sh | bash
```

The server listens on port 8000 and prints its MCP URL and a random bearer token. Keep the terminal running. The token is stored with owner-only permissions in `~/.codespace-ai/.env`.

The server exposes workspace info, directory listing, text-file read/write, and terminal execution. Terminal execution has the same permissions as the Codespace user; only connect it to a private MCP client and keep the bearer token secret. Stop it with Ctrl+C.

This is the server bootstrap, not a completed ChatGPT plugin registration. The endpoint must be reachable and registered with an MCP client before ChatGPT can call it.
