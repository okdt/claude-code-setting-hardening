#!/bin/bash
# ============================================================
# Claude Code Setting Hardening
# ============================================================
# Apply security settings to ~/.claude/settings.json:
#   - Enable sandbox (filesystem & network isolation)
#   - Deny destructive operations (git, file deletion, permissions)
#   - Deny privilege escalation and remote code execution
#   - Deny macOS commands that look harmless but aren't (open, osascript)
#   - Restrict reading sensitive files (.env, credentials)
#
# This script protects your local environment from hallucination,
# runaway behavior, and malicious prompts. For additional rules
# (remote access, publishing, deployment, MCP, etc.),
# see settings-example.jsonc.
#
# Usage:
#   chmod +x hardening-claude-code-env.sh
#   ./hardening-claude-code-env.sh
#
# See README.md for the rationale behind each rule.
#
# Reference:
#   https://code.claude.com/docs/en/security
#   https://qiita.com/dai_chi/items/f6d5e907b9fee791b658
# ============================================================

set -euo pipefail

SETTINGS_FILE="$HOME/.claude/settings.json"

# Note: The deny list below is a sample of destructive operations
# that the author (okdt) wanted to block first. It is not exhaustive.
# After running this script, review settings-example.jsonc and
# adjust ~/.claude/settings.json to fit your own environment.
#
# Platform notes:
#   Sandbox — macOS (Seatbelt), Linux/WSL2 (bubblewrap). WSL1 not supported.
#   open, osascript, defaults write — macOS-specific commands (remove on Linux)

DESIRED_SETTINGS='{
  "sandbox": {
    "enabled": true,
    "autoAllowBashIfSandboxed": true,
    "filesystem": {
      "denyRead": ["~/.ssh", "~/.gnupg", "~/.aws", "~/.config/gcloud"]
    }
  },
  "permissions": {
    "deny": [
      "Bash(git push -f *)",
      "Bash(git push --force *)",
      "Bash(git reset --hard *)",
      "Bash(git checkout .)",
      "Bash(git clean -f *)",
      "Bash(git add .)",
      "Bash(git add -A)",
      "Bash(rm -rf *)",
      "Bash(rm -r *)",
      "Bash(chmod 777 *)",
      "Bash(chmod -R *)",
      "Bash(chown -R *)",
      "Bash(killall *)",
      "Bash(pkill *)",
      "Bash(kill -9 *)",
      "Bash(sudo *)",
      "Bash(curl *|*sh)",
      "Bash(wget *|*sh)",
      "Bash(ssh *)",
      "Bash(scp *)",
      "Bash(rsync *)",
      "Bash(open *)",
      "Bash(osascript *)",
      "Bash(defaults write *)",
      "Read(**/.env)",
      "Read(**/.env.*)"
    ]
  }
}'

echo "Claude Code Setting Hardening"
echo "--------------------------------------------"

mkdir -p "$HOME/.claude"

if [ -f "${SETTINGS_FILE}" ]; then
  has_sandbox=false
  has_deny=false
  grep -q '"sandbox"' "${SETTINGS_FILE}" 2>/dev/null && has_sandbox=true
  grep -q '"deny"' "${SETTINGS_FILE}" 2>/dev/null && has_deny=true

  if $has_sandbox && $has_deny; then
    echo "[OK] Already hardened (sandbox + deny list in place)"
    exit 0
  fi

  existing="$(cat "${SETTINGS_FILE}" | tr -d '[:space:]')"
  if [ "${existing}" = "{}" ]; then
    echo "${DESIRED_SETTINGS}" > "${SETTINGS_FILE}"
    echo "[Done] Applied hardening settings"
    exit 0
  fi

  if ! $has_sandbox || ! $has_deny; then
    echo "[Warning] Existing settings.json has partial configuration:"
    echo "  Sandbox:   $($has_sandbox && echo 'configured' || echo 'missing')"
    echo "  Deny list: $($has_deny && echo 'configured' || echo 'missing')"
    echo ""
    echo "Overwrite with hardened settings? (y/N)"
    read -r response
    if [ "${response}" = "y" ] || [ "${response}" = "Y" ]; then
      cp "${SETTINGS_FILE}" "${SETTINGS_FILE}.bak"
      echo "  Backup saved to ${SETTINGS_FILE}.bak"
      echo "${DESIRED_SETTINGS}" > "${SETTINGS_FILE}"
      echo "[Done] Applied hardening settings"
      exit 0
    else
      echo "[Skipped] Apply manually:"
      echo "${DESIRED_SETTINGS}"
      exit 1
    fi
  fi
fi

echo "${DESIRED_SETTINGS}" > "${SETTINGS_FILE}"
echo "[Done] Created hardened settings.json"
