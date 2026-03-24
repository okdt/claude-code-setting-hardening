# Claude Code Hardening Cheatsheet

---

## 1. Introduction

Claude Code can run shell commands, read and write files, and interact with external services on your behalf. This power comes with risk. This cheatsheet provides a practical guide to hardening your Claude Code environment through `~/.claude/settings.json` — applying the principle of least privilege and Human-in-the-Loop (HITL) controls.

### Risks — Why Hardening Is Needed

- **Well-intentioned overreach** — Claude Code may take actions that are technically correct but go beyond what you intended: deleting files to "clean up," force-pushing to "fix" a branch, or installing packages you didn't ask for. ([OWASP LLM09: Overreliance](https://genai.owasp.org/llm-top-10/))
- **Excessive permissions** — By default, Claude Code can do anything your user account can do. Without deny rules, a single "yes" can grant access to destructive commands, credential files, or remote systems. ([OWASP LLM06: Excessive Agency](https://genai.owasp.org/llm-top-10/))
- **Indirect prompt injection** — The content Claude Code processes (source code, documents, web pages) may contain hidden instructions that influence its behavior. An attacker can embed malicious prompts in files or dependencies that Claude reads during normal work. ([OWASP LLM01: Prompt Injection](https://genai.owasp.org/llm-top-10/))
- **Compromised environment** — If your machine is affected by RCE, malware, or a supply chain attack, Claude Code inherits that compromise. Hardening limits the blast radius — what an attacker can do *through* Claude Code even after gaining a foothold.

These are not hypothetical. They are the reason guardrails exist: to ensure that when things go wrong — and they will — the damage is contained.

### About This Document

It covers what to block, what to allow, what to always ask about, and what to do when deny rules aren't enough. The deny list examples are a sample of operations that the author ([okdt](https://github.com/okdt)) wanted to block first. They are not exhaustive. Use them as a starting point and customize for your own environment.

This cheatsheet is primarily written and tested on macOS, but most rules apply equally to Linux and Windows (WSL). Platform-specific rules are marked as such.

---

## 2. Sandboxing

The sandbox isolates Claude Code's file and network access at the OS level. Even if a deny rule is bypassed, the sandbox prevents access to resources outside defined boundaries. It is the strongest protection layer available — consider it essential.

Supported on macOS (Seatbelt), Linux, and WSL2 (bubblewrap). WSL1 is not supported at the time of writing — please verify for your environment.

### How to enable

Run `/sandbox` in Claude Code's interactive mode. This opens a menu where you can enable sandboxing and configure its mode. The equivalent `settings.json` configuration is:

```json
"sandbox": {
  "enabled": true,
  "autoAllowBashIfSandboxed": true,
  "filesystem": {
    "denyRead": ["~/.ssh", "~/.gnupg", "~/.aws", "~/.config/gcloud", "~/.bash_history", "~/.zsh_history"]
  }
}
```

| Setting | Why |
|---------|-----|
| `enabled: true` | Isolates file and network access at the OS level. Claude Code can only access the current working directory and explicitly allowed paths. |
| `autoAllowBashIfSandboxed` | Reduces permission prompts for Bash commands — safe because the sandbox constrains their scope. |
| `denyRead` | Blocks access to credential stores even within the sandbox. SSH keys, GPG keys, AWS credentials, and GCP configs should never be read directly by an AI assistant. Note: this can be bypassed if the path is passed as an argument to a Bash command (e.g., `cat ~/.ssh/id_rsa`) — which is why the sandbox and deny rules are complementary layers. |

---

## 3. Permission System

Claude Code's permission system determines what happens when a command or tool is invoked. Understanding these four levels is essential before configuring any rules.

### Permission levels

| Permission | Behavior | Where to set |
|------------|----------|--------------|
| `allow` | Always permitted, no prompt | `settings.json` or `settings.local.json` |
| `ask` | Always prompted, even if previously approved with "don't ask again" | `settings.json` or `settings.local.json` |
| _(default)_ | Prompted on first use; "don't ask again" makes it permanent | Your brain — which may say yes too quickly when busy, or can't tell safe from unsafe when tired |
| `deny` | Always blocked, no prompt | `settings.json` or `settings.local.json` |

`deny` takes precedence over `allow`. If the same rule appears in both, it is denied.

- **`deny` is for guardrails** — things that should never happen regardless of context.
- **`allow` is for convenience** — things you trust and don't want to be prompted for every time.
- **`ask` is your Human-in-the-Loop** — things you usually trust but want to verify each time.

### Where to put rules

| File | Who | Scope | Git |
|------|-----|-------|-----|
| `~/.claude/settings.json` | You only | All your projects on this machine | Not in any repo |
| `<project>/.claude/settings.json` | Entire team | This project only | Committed and shared with everyone |
| `<project>/.claude/settings.local.json` | You only | This project only | Lives in the repo directory but gitignored — never pushed |

For your personal preferences on a specific project, use `.claude/settings.local.json` so you don't impose them on teammates.

* A `deny` rule in any settings file cannot be overridden by `allow` in another. Conversely, an `allow` can be overridden by `deny` in another settings file.

---

## 4. Allow / Ask / Deny List

This section lists specific rules organized by threat category. Each rule includes the rationale so you can decide whether it applies to your environment.

See [`settings_example.jsonc`](settings_example.jsonc) for a single file containing all rules below, with `allow` and `ask` examples commented out.

### 4.1 Deny — Destructive Git Operations

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

### 4.2 Deny — Destructive File Operations

Prevent bulk file deletion that could wipe out project trees.

```json
"Bash(rm -rf *)",
"Bash(rm -r *)"
```

| Rule | Risk |
|------|------|
| `rm -rf` | Recursively deletes directories without confirmation. A wrong path can wipe out entire project trees. |
| `rm -r` | Same as above, but prompts in some configurations. Still too dangerous to allow unconditionally. |

### 4.3 Deny — Dangerous System Operations

Prevent permission changes and process kills that could destabilize your environment.

```json
"Bash(chmod 777 *)",
"Bash(chmod -R *)",
"Bash(chown -R *)",
"Bash(killall *)",
"Bash(pkill *)",
"Bash(kill -9 *)"
```

| Rule | Risk |
|------|------|
| `chmod 777` | Makes files world-readable/writable/executable. A common security anti-pattern. |
| `chmod -R / chown -R` | Recursive permission/ownership changes can break system directories or expose sensitive files. |
| `killall / pkill` | Terminates processes by name. Can kill unrelated critical processes. |
| `kill -9` | Force-kills without cleanup. Can cause data corruption in running applications. |

### 4.4 Deny — Privilege Escalation

Prevent Claude Code from running commands as root.

```json
"Bash(sudo *)",
"Bash(su *)"
```

An AI assistant should never escalate privileges. Even though `sudo` requires a password, denying it outright prevents Claude Code from even attempting to run commands as root. Note: with sandboxing enabled, privilege escalation is already blocked at the OS level, making these rules redundant. They are included here for environments where sandboxing is not used.

### 4.5 Deny — Remote Code Execution via Pipe

Prevent downloading and executing untrusted scripts in one step. These rules do not affect web page access.

```json
"Bash(curl *|*sh)",
"Bash(wget *|*sh)"
```

Piping remote scripts directly into a shell (`curl ... | sh`) is a classic supply chain attack vector. Claude Code may suggest this as a standard "install" step — and users tend to approve it reflexively because it *looks like* a normal installation procedure. Better to let Claude Code tell you the command and run it yourself.

### 4.6 Deny — Remote Access

Prevent Claude Code from initiating connections to remote hosts.

```json
"Bash(ssh *)",
"Bash(scp *)",
"Bash(rsync *)"
```

An AI assistant should not initiate remote connections. These commands can transfer files or execute commands on remote hosts. If you need Claude Code to work with remote systems, consider allowing specific targets instead of a blanket allow.

Note: With sandboxing enabled, network access is already blocked at the OS level, so these commands would fail even without deny rules. However, deny rules prevent Claude Code from **attempting** the command in the first place — avoiding unnecessary errors and wasted turns.

When a deny rule blocks a command, the block is visible within the session but **is not logged to a file by default**. To maintain an audit trail of denied operations, configure [OpenTelemetry](https://code.claude.com/docs/en/monitoring-usage) — the `claude_code.tool_decision` event records whether each tool call was accepted or rejected, along with the decision source.

### 4.7 Deny — macOS: Easy to Approve, Hard to Undo

Some macOS commands look harmless but can cause serious damage. Users tend to approve these without a second thought — that's exactly what makes them risky.

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

* These rules are not needed on other operating systems, but consider the same approach for your platform's equivalents (contributions welcome).

### 4.8 Deny — Package Publishing & Deployment

Prevent unintended package publishing and deployment, even in CI/CD contexts.

```json
"Bash(npm publish *)",
"Bash(yarn publish *)",
"Bash(pnpm publish *)",
"Bash(*deploy*)"
```

Publishing packages or triggering deployments should be a deliberate human action. Unless explicitly designed into your workflow, an AI should not do this autonomously. A single mistaken publish can affect every downstream consumer.

### 4.9 Deny — Infrastructure

Prevent autonomous changes to cloud infrastructure.

```json
"Bash(terraform apply *)",
"Bash(terraform destroy *)",
"Bash(kubectl apply *)",
"Bash(kubectl delete *)",
"Bash(helm install *)",
"Bash(helm upgrade *)",
"Bash(docker push *)",
"Bash(aws * --no-cli-pager)",
"Bash(gcloud * --quiet)"
```

| Rule | Risk |
|------|------|
| `terraform apply / destroy` | Creates, modifies, or destroys cloud infrastructure. |
| `kubectl apply / delete` | Deploys or removes workloads on Kubernetes clusters. |
| `helm install / upgrade` | Installs or upgrades Kubernetes packages with broad cluster impact. |
| `docker push` | Publishes container images to registries. |
| `aws --no-cli-pager` | Runs AWS CLI without paging — easy to miss destructive output. |
| `gcloud --quiet` | Runs GCP CLI without confirmation prompts. |

### 4.10 Deny — Sensitive File Access

Prevent Claude Code from reading files that contain secrets.

```json
"Read(**/.env)",
"Read(**/.env.*)"
```

`.env` files typically contain API keys, database passwords, and other secrets. Claude Code doesn't need to read them — it can reference `.env.example` or documentation instead.

Consider adding more patterns for your environment:

```json
"Read(**/*.pem)",
"Read(**/*.key)",
"Read(**/credentials*)"
```

### 4.11 Deny — MCP Actions: Preventing Impersonation Messages

Prevent Claude Code from sending messages on your behalf.

```json
"mcp__claude_ai_Slack__slack_send_message",
"mcp__claude_ai_Slack__slack_schedule_message"
```

An AI assistant reading messages for context is different from it **sending** messages — the latter should require your explicit action.

### 4.12 Ask — Human-in-the-Loop

Not everything is black or white. Some commands are useful and legitimate, but carry enough risk that **a human should review each invocation**. That's what `ask` is for.

When you approve a command with "Yes, don't ask again", it becomes permanently allowed for that project. `ask` rules override this — Claude Code will **always** prompt you, even if you previously said "don't ask again". This is your Human-in-the-Loop (HITL) checkpoint.

```json
{
  "permissions": {
    "ask": [
      "Bash(git commit *)",
      "Bash(git push *)",
      "Bash(npm install *)",
      "Bash(pip install *)",
      "Bash(brew install *)",
      "Bash(psql *)",
      "Bash(mysql *)",
      "Bash(mongosh *)",
      "Bash(sqlite3 *)"
    ]
  }
}
```

| Rule | Why `ask`, not `allow` or `deny` |
|------|----------------------------------|
| `git commit` | You want to review the commit message and what's being committed. |
| `git push` | Useful, but you should verify the branch and remote each time. |
| `npm/pip/brew install` | Adding dependencies can introduce vulnerabilities. Worth a glance. |
| `psql / mysql / mongosh / sqlite3` | Can't distinguish `SELECT` from `DROP TABLE` via patterns. The prompt is your only chance to check. |

> **The key insight:** `deny` is for things that should **never** happen. `allow` is for things you **always** trust. `ask` is for things you **usually** trust but want to verify — because the one time you don't check might be the time it matters.

#### A note on database commands

Commands like `psql`, `mysql`, `mongosh`, and `sqlite3` can be destructive (`DROP TABLE`, `DELETE FROM`), but Claude Code's deny rules match the command itself — not its arguments. Denying `Bash(psql *)` blocks all usage, including harmless `SELECT` queries needed for analysis.

**Recommendation:** Use `ask` for database commands rather than `deny`. Review each invocation when prompted — it's the only way to distinguish a read query from a destructive one.

### 4.13 Allow — Trusted Operations

Allow rules skip the permission prompt for commands you trust. Useful for reducing prompt fatigue on safe, frequently-used operations.

See the commented-out `allow` section in [`settings_example.jsonc`](settings_example.jsonc) for examples including test/build commands, safe git operations, and MCP read-only actions.

---

## 5. Hooks — When Deny Rules Aren't Enough

Deny rules are enforced by the Claude Code harness (not the AI model), so Claude cannot "choose" to ignore them. However, **deny rules alone have gaps**.

Hooks are custom shell scripts that Claude Code runs at specific lifecycle points — most importantly, **before a tool call is executed** (`PreToolUse`). Unlike deny rules that can only match command patterns, a hook script receives the full command as JSON input and can apply arbitrary logic: inspect arguments, check file contents, query external systems, or block the call with a reason that Claude sees as feedback.

If the hook exits with code 2, the tool call is blocked (the reason you write to stderr is shown to Claude as feedback). If it exits with 0, the call proceeds. This gives you fine-grained control that glob patterns cannot express.

### Example 1: Block destructive SQL in database commands

**The problem:** You can't deny `Bash(psql *)` because it blocks `SELECT` too. But you want to catch `DROP TABLE` or `DELETE FROM` before they execute.

**The hook script** — save as `~/.claude/hooks/block-destructive-sql.sh`:

```bash
#!/bin/bash
INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command')

# Check if the command contains destructive SQL keywords
if echo "$CMD" | grep -iqE '(DROP\s|DELETE\s+FROM|TRUNCATE\s|ALTER\s+TABLE.*DROP)'; then
  echo "Blocked: destructive SQL detected in command: $CMD" >&2
  exit 2
fi

exit 0
```

```bash
chmod +x ~/.claude/hooks/block-destructive-sql.sh
```

**The settings** — add to your `settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/block-destructive-sql.sh"
          }
        ]
      }
    ]
  }
}
```

Now `psql -c "SELECT * FROM users"` proceeds normally, but `psql -c "DROP TABLE users"` is blocked with a reason Claude can see.

### Example 2: Block Bash from reading sensitive files

**The problem:** `Read(**/.env)` in your deny list blocks Claude's Read tool, but `cat .env` through Bash bypasses it entirely.

**The hook script** — save as `~/.claude/hooks/block-sensitive-reads.sh`:

```bash
#!/bin/bash
INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command')

SENSITIVE_PATTERNS='\.env|\.pem|\.key|id_rsa|id_ed25519|credentials'

if echo "$CMD" | grep -iqE "(cat|less|more|head|tail|grep|awk|sed)\s.*(${SENSITIVE_PATTERNS})"; then
  echo "Blocked: reading sensitive file via Bash: $CMD" >&2
  exit 2
fi

exit 0
```

**The settings** — same structure, same matcher:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/block-sensitive-reads.sh"
          }
        ]
      }
    ]
  }
}
```

### Combining multiple hooks

You can register multiple hook scripts under the same event. They all run, and if any one exits with code 2, the call is blocked:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/block-destructive-sql.sh"
          },
          {
            "type": "command",
            "command": "~/.claude/hooks/block-sensitive-reads.sh"
          }
        ]
      }
    ]
  }
}
```

### Why deny rules still have gaps

Even with hooks, it helps to understand why deny rules alone aren't sufficient.

### Read deny ≠ Bash deny

From the [official documentation](https://code.claude.com/docs/en/permissions):

> `Read(./.env)` deny rule blocks the Read tool but does **not** prevent `cat .env` in Bash.

This means `Read(**/.env)` in your deny list stops Claude's built-in Read tool, but Claude can still run `Bash(cat .env)`, `Bash(grep password .env)`, or any other Bash command that reads the file. The deny rules for Read and Bash are **separate layers that don't cover each other**.

### Bash patterns can be bypassed

Bash deny rules use glob pattern matching, which has inherent limitations:

- `Bash(sudo *)` blocks `sudo rm -rf /` but not a script that internally calls `sudo`
- `Bash(curl *|*sh)` blocks `curl url | sh` but not `wget -O- url | bash`
- `Bash(rm -rf *)` blocks `rm -rf /tmp` but not a Makefile target that runs `rm -rf` internally

### Three layers of defense

For robust protection, use all three layers together:

| Layer | What it does | Configured in |
|-------|-------------|---------------|
| **Deny rules** | First line of defense. Blocks known dangerous commands and tools before execution. | `settings.json` |
| **Sandbox** | OS-level enforcement. Restricts filesystem and network access for all processes, including child processes spawned by Bash. Cannot be bypassed by the AI model. | `settings.json` |
| **Hooks (PreToolUse)** | Custom scripts that inspect commands before execution. Can apply complex logic that glob patterns cannot express. | `settings.json` |

Deny rules catch the obvious cases. Sandbox prevents damage even if a command slips through. Hooks let you add custom logic for your specific environment.

For more on hooks, see [Claude Code Hooks Guide](https://code.claude.com/docs/en/hooks-guide).

---

## References

### Official Documentation

- [Claude Code Security Best Practices](https://code.claude.com/docs/en/security)
- [Claude Code Settings](https://code.claude.com/docs/en/settings)
- [Claude Code Permissions](https://code.claude.com/docs/en/permissions)
- [Claude Code Sandboxing](https://code.claude.com/docs/en/sandboxing)
- [Claude Code Hooks Guide](https://code.claude.com/docs/en/hooks-guide)

### Community

- [Claude Codeの設定でやるべきセキュリティ対策](https://qiita.com/dai_chi/items/f6d5e907b9fee791b658) (Japanese)

## Related Cheat Sheets & Further Reading

- [OWASP AI Agent Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/AI_Agent_Security_Cheat_Sheet.html) — Covers key risks and best practices for AI agent systems: tool permission minimization, prompt injection prevention, human-in-the-loop controls, and more.
- [OWASP LLM Prompt Injection Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Prompt_Injection_Prevention_Cheat_Sheet.html) — Technical guidance on defending against prompt injection attacks.
- [OWASP Top 10 for LLM Applications](https://genai.owasp.org/llm-top-10/) — The broader threat landscape for LLM-powered applications.
