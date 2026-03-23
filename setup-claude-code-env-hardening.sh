#!/bin/bash
# ============================================================
# Claude Code Setting Hardening
# ============================================================
# Apply security-focused settings to ~/.claude/settings.json:
#   - Enable sandbox (filesystem & network isolation)
#   - Deny dangerous operations (destructive git, remote access, etc.)
#   - Restrict reading sensitive files (.env, credentials)
#   - Restrict MCP actions (e.g., Slack message sending)
#
# Usage:
#   chmod +x setup-hardening.sh
#   ./setup-hardening.sh
#
# See README.md for the rationale behind each rule.
#
# Reference:
#   https://code.claude.com/docs/en/security
#   https://qiita.com/dai_chi/items/f6d5e907b9fee791b658
# ============================================================

set -euo pipefail

SETTINGS_FILE="$HOME/.claude/settings.json"

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
      "Bash(ssh *)",
      "Bash(scp *)",
      "Bash(rsync *)",
      "Bash(npm publish *)",
      "Bash(yarn publish *)",
      "Bash(pnpm publish *)",
      "Bash(*deploy*)",
      "Bash(terraform apply *)",
      "Read(**/.env)",
      "Read(**/.env.*)",
      "mcp__claude_ai_Slack__slack_send_message",
      "mcp__claude_ai_Slack__slack_schedule_message"
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
