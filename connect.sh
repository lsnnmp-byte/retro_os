#!/usr/bin/env bash
set -euo pipefail

# Run this script on your LOCAL computer, not inside the Codespace.
if ! command -v gh >/dev/null 2>&1; then
  echo "GitHub CLI (gh) is required. Install it from https://cli.github.com/"
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "Sign in to GitHub first:"
  gh auth login
fi

echo "Your Codespaces:"
gh codespace list

read -r -p "Enter the Codespace name: " CODESPACE_NAME
if [[ -z "$CODESPACE_NAME" ]]; then
  echo "No Codespace name supplied."
  exit 1
fi

echo "Connecting to $CODESPACE_NAME over SSH..."
exec gh codespace ssh --codespace "$CODESPACE_NAME"
