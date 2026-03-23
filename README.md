# claude-code-hardening-cheatsheet

**[日本語版はこちら (Japanese)](README.ja.md)**

A minimal, opinionated security hardening template for [Claude Code](https://code.claude.com/) `~/.claude/settings.json`.

Claude Code is powerful — it can run shell commands, read files, and interact with external services. These settings restrict what it's **not allowed** to do, so you can focus on what it **should** do.

## Quick Start

**Option A: Run the script**

```bash
git clone https://github.com/okdt/claude-code-hardening-cheatsheet.git
cd claude-code-hardening-cheatsheet
chmod +x hardening-claude-code-env.sh
./hardening-claude-code-env.sh
```

**Option B: Copy the template**

```bash
cp settings-template.json ~/.claude/settings.json
```

> If you already have a `settings.json`, merge the rules manually to preserve your existing configuration.

## What It Does

### Sandbox

```json
"sandbox": {
  "enabled": true,
  "autoAllowBashIfSandboxed": true,
  "filesystem": {
    "denyRead": ["~/.ssh", "~/.gnupg", "~/.aws", "~/.config/gcloud"]
  }
}
```

| Setting | Why |
|---------|-----|
| `enabled: true` | Isolates file and network access at the OS level. Claude Code can only access the current working directory and explicitly allowed paths. |
| `autoAllowBashIfSandboxed` | Reduces permission prompts for Bash commands — safe because the sandbox constrains their scope. |
| `denyRead` | Blocks access to credential stores even within the sandbox. SSH keys, GPG keys, AWS credentials, and GCP configs should never be read by an AI assistant. |

### Deny List — Destructive Git Operations

```json
"Bash(git push -f *)",
"Bash(git push --force *)",
"Bash(git reset --hard *)",
"Bash(git checkout .)",
"Bash(git clean -f *)",
"Bash(git add .)",
"Bash(git add -A)"
```

| Rule | Risk |
|------|------|
| `git push -f / --force` | Overwrites remote history. Can destroy teammates' work. |
| `git reset --hard` | Discards all uncommitted changes irreversibly. |
| `git checkout .` | Silently reverts all working tree changes. |
| `git clean -f` | Deletes untracked files permanently. |
| `git add . / -A` | Stages everything — may accidentally include `.env`, credentials, or large binaries. |

### Deny List — Remote Access

```json
"Bash(ssh *)",
"Bash(scp *)",
"Bash(rsync *)"
```

An AI assistant should not initiate remote connections. These commands can transfer files or execute commands on remote hosts. If you need Claude Code to work with remote systems, consider allowing specific targets instead of a blanket allow.

### Deny List — Package Publishing & Deployment

```json
"Bash(npm publish *)",
"Bash(yarn publish *)",
"Bash(pnpm publish *)",
"Bash(*deploy*)"
```

Publishing packages or triggering deployments should be a deliberate human action, not something an AI does autonomously. A single mistaken publish can affect every downstream consumer.

### Deny List — Infrastructure

```json
"Bash(terraform apply *)"
```

`terraform apply` creates, modifies, or destroys cloud infrastructure. This should always require explicit human approval.

### Deny List — Sensitive File Access

```json
"Read(**/.env)",
"Read(**/.env.*)"
```

`.env` files typically contain API keys, database passwords, and other secrets. Claude Code doesn't need to read them — it can reference `.env.example` or documentation instead.

### Deny List — MCP Actions

```json
"mcp__claude_ai_Slack__slack_send_message",
"mcp__claude_ai_Slack__slack_schedule_message"
```

Prevents Claude Code from sending Slack messages on your behalf. An AI assistant reading messages for context is different from it **sending** messages — the latter should require your explicit action.

## Customizing

This template is a starting point. Consider adding rules for your environment:

```json
// CI/CD tools
"Bash(kubectl apply *)",
"Bash(helm install *)",
"Bash(docker push *)",

// Database
"Bash(psql *)",
"Bash(mysql *)",
"Bash(mongosh *)",

// Other sensitive reads
"Read(**/*.pem)",
"Read(**/*.key)",
"Read(**/credentials*)"
```

### How `deny` and `allow` work together

Claude Code's permission model has three levels:

| Permission | Behavior | Where to set |
|------------|----------|--------------|
| `allow` | Always permitted, no prompt | `settings.json` or `settings.local.json` |
| _(default)_ | User is prompted each time | — |
| `deny` | Always blocked, no prompt | `settings.json` |

`deny` takes precedence over `allow`. If the same rule appears in both, it is denied.

**`deny` is for guardrails** — things that should never happen regardless of context (destructive ops, credential access, sending messages).

**`allow` is for convenience** — things you trust and don't want to be prompted for every time.

### Where to put `allow` rules

| File | Scope | Git |
|------|-------|-----|
| `~/.claude/settings.json` | All projects on this machine | N/A |
| `.claude/settings.json` | This project, all contributors | Committed |
| `.claude/settings.local.json` | This project, only you | Gitignored |

For project-specific allows, use `.claude/settings.local.json` to avoid pushing your personal preferences to teammates:

```json
{
  "permissions": {
    "allow": [
      "Bash(npm test *)",
      "Bash(npm run build *)"
    ]
  }
}
```

See [`settings-allow-examples.jsonc`](settings-allow-examples.jsonc) for more examples organized by category.

## Files

| File | Description |
|------|-------------|
| `hardening-claude-code-env.sh` | Interactive script — detects existing settings, backs up before overwriting |
| `settings-template.json` | Copy-paste template for `~/.claude/settings.json` (deny rules) |
| `settings-allow-examples.jsonc` | Allow rule examples — pick what fits your workflow (JSONC with comments) |

## References

- [Claude Code Security Best Practices](https://code.claude.com/docs/en/security)
- [Claude Code Settings Documentation](https://code.claude.com/docs/en/settings)
- [Claude Code Permissions](https://code.claude.com/docs/en/permissions)
- [Claude Codeの設定でやるべきセキュリティ対策](https://qiita.com/dai_chi/items/f6d5e907b9fee791b658) (Japanese)

## License

[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) — Free to use, share, and adapt with attribution.
