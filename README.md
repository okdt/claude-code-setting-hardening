# claude-code-hardening-cheatsheet

**[日本語版はこちら (Japanese)](README.ja.md)**

A security hardening cheatsheet for [Claude Code](https://code.claude.com/) `~/.claude/settings.json`.

Claude Code is powerful — it can run shell commands, read files, and interact with external services. These settings restrict what it's **not allowed** to do, so you can focus on what it **should** do.

## Quick Start

**Option A: Run the script**

```bash
git clone https://github.com/okdt/claude-code-hardening-cheatsheet.git
cd claude-code-hardening-cheatsheet
chmod +x hardening-claude-code-env.sh
./hardening-claude-code-env.sh
```

**Option B: Copy the example**

```bash
# Remove comments and copy
grep -v '^\s*//' settings-example.jsonc > ~/.claude/settings.json
```

> If you already have a `settings.json`, merge the rules manually to preserve your existing configuration.

## What It Does

### Sandbox

Isolate Claude Code's file and network access at the OS level.

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
| `enabled: true` | Isolates file and network access at the OS level. Claude Code can only access the current working directory and explicitly allowed paths. Supported on macOS (Seatbelt), Linux, and WSL2 (bubblewrap). |
| `autoAllowBashIfSandboxed` | Reduces permission prompts for Bash commands — safe because the sandbox constrains their scope. |
| `denyRead` | Blocks access to credential stores even within the sandbox. SSH keys, GPG keys, AWS credentials, and GCP configs should never be read by an AI assistant. |

### Deny List — Destructive Git Operations

Prevent irreversible changes to your repository and its history.

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

### Deny List — Destructive File Operations

Prevent bulk file deletion that could wipe out project trees.

```json
"Bash(rm -rf *)",
"Bash(rm -r *)"
```

| Rule | Risk |
|------|------|
| `rm -rf` | Recursively deletes directories without confirmation. A wrong path can wipe out entire project trees. |
| `rm -r` | Same as above, but prompts in some configurations. Still too dangerous to allow unconditionally. |

### Deny List — Dangerous System Operations

Prevent permission changes and process kills that could destabilize your environment.

```json
"Bash(chmod 777 *)",
"Bash(chmod -R *)",
"Bash(chown -R *)",
"Bash(killall *)",
"Bash(pkill *)",
"Bash(kill -9 *)",
```

| Rule | Risk |
|------|------|
| `chmod 777` | Makes files world-readable/writable/executable. A common security anti-pattern. |
| `chmod -R / chown -R` | Recursive permission/ownership changes can break system directories or expose sensitive files. |
| `killall / pkill` | Terminates processes by name. Can kill unrelated critical processes. |
| `kill -9` | Force-kills without cleanup. Can cause data corruption in running applications. |

### Deny List — Privilege Escalation

Prevent Claude Code from running commands as root.

```json
"Bash(sudo *)"
```

An AI assistant should never escalate privileges. Even though `sudo` requires a password, denying it outright prevents Claude Code from even attempting to run commands as root.

### Deny List — Remote Code Execution via Pipe

Prevent downloading and executing untrusted scripts in one step.

```json
"Bash(curl *|*sh)",
"Bash(wget *|*sh)"
```

Piping remote scripts directly into a shell (`curl ... | sh`) is a classic supply chain attack vector. Claude Code may suggest this as a standard "install" step — and users tend to approve it reflexively because it *looks like* a normal installation procedure.

### Deny List — macOS: Easy to Approve, Hard to Undo

Block macOS commands that look harmless but can cause serious damage. Users tend to approve these without a second thought — that's exactly what makes them risky.

```json
"Bash(open *)",
"Bash(osascript *)",
"Bash(defaults write *)"
```

| Rule | Why it's easy to approve | Actual risk |
|------|-------------------------|-------------|
| `open` | "Just opening a file/URL" | Can launch arbitrary applications, open phishing URLs, or execute downloaded files. MCP browser tools (Puppeteer, etc.) do **not** use `open`, so browser automation is unaffected. |
| `osascript` | "Just automating Finder" | AppleScript can send emails, control apps, access keychain, and much more. |
| `defaults write` | "Just changing a setting" | Can modify security-critical macOS preferences, disable Gatekeeper, or alter app behavior. |

### Deny List — Remote Access

Prevent Claude Code from initiating connections to remote hosts.

```json
"Bash(ssh *)",
"Bash(scp *)",
"Bash(rsync *)"
```

An AI assistant should not initiate remote connections. These commands can transfer files or execute commands on remote hosts. If you need Claude Code to work with remote systems, consider allowing specific targets instead of a blanket allow.

### Deny List — Package Publishing & Deployment

Prevent accidental or autonomous publishing and deployment.

```json
"Bash(npm publish *)",
"Bash(yarn publish *)",
"Bash(pnpm publish *)",
"Bash(*deploy*)"
```

Publishing packages or triggering deployments should be a deliberate human action, not something an AI does autonomously. A single mistaken publish can affect every downstream consumer.

### Deny List — Infrastructure

Prevent autonomous changes to cloud infrastructure.

```json
"Bash(terraform apply *)"
```

`terraform apply` creates, modifies, or destroys cloud infrastructure. This should always require explicit human approval.

### Deny List — Sensitive File Access

Prevent Claude Code from reading files that contain secrets.

```json
"Read(**/.env)",
"Read(**/.env.*)"
```

`.env` files typically contain API keys, database passwords, and other secrets. Claude Code doesn't need to read them — it can reference `.env.example` or documentation instead.

### Deny List — MCP Actions

Prevent Claude Code from sending messages on your behalf.

```json
"mcp__claude_ai_Slack__slack_send_message",
"mcp__claude_ai_Slack__slack_schedule_message"
```

Prevents Claude Code from sending Slack messages on your behalf. An AI assistant reading messages for context is different from it **sending** messages — the latter should require your explicit action.

## Customizing

The deny rules above are a starting point. Consider adding rules for your environment:

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

See the commented-out `allow` section in [`settings-example.jsonc`](settings-example.jsonc) for examples.

## Files

| File | Description |
|------|-------------|
| `hardening-claude-code-env.sh` | Interactive script — applies local protection rules (sandbox + deny). Detects existing settings, backs up before overwriting |
| `settings-example.jsonc` | Full example for `~/.claude/settings.json` — includes everything the script applies, plus additional rules (remote access, publishing, deployment, MCP) and commented-out allow examples |

## References

- [Claude Code Security Best Practices](https://code.claude.com/docs/en/security)
- [Claude Code Settings Documentation](https://code.claude.com/docs/en/settings)
- [Claude Code Permissions](https://code.claude.com/docs/en/permissions)
- [Claude Codeの設定でやるべきセキュリティ対策](https://qiita.com/dai_chi/items/f6d5e907b9fee791b658) (Japanese)

## License

[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) — Free to use, share, and adapt with attribution.
