# Claude Code Hardening Cheatsheet

---

## 1. Introduction

Claude Code can run shell commands, read and write files, and interact with external services on your behalf. This power comes with risk. This document is about controlling that risk. If you're a beginner, start with the "Sandboxing" section at minimum. If you're a technical lead, use this as a reference for establishing your team's baseline security policy.

### Risks — Why Hardening (Security Hardening) Is Needed

- **Well-intentioned overreach** — Claude Code may take actions that are technically correct but go beyond what you intended: deleting files to "clean up," force-pushing to "fix" a branch, or installing packages you didn't ask for. ([OWASP LLM09: Overreliance](https://genai.owasp.org/llm-top-10/))
- **Excessive permissions** — By default, Claude Code can do anything your user account can do. Without deny rules, a single "yes" can grant access to destructive commands, credential files, or remote systems. ([OWASP LLM06: Excessive Agency](https://genai.owasp.org/llm-top-10/))
- **Indirect prompt injection** — The content Claude Code processes (source code, documents, web pages) may contain hidden instructions that influence its behavior. An attacker can embed malicious prompts in files or dependencies that Claude reads during normal work. ([OWASP LLM01: Prompt Injection](https://genai.owasp.org/llm-top-10/))
- **Compromised environment** — If your machine is affected by RCE, malware, or a supply chain attack, Claude Code inherits that compromise. Hardening limits the blast radius — what an attacker can do *through* Claude Code even after gaining a foothold.

These are not hypothetical. They are the reason guardrails exist: to ensure that when things go wrong — and they will — the damage is contained.
This cheatsheet provides a practical guide to hardening your Claude Code environment through `~/.claude/settings.json` — applying the principle of least privilege and Human-in-the-Loop (HITL) controls.

### Approach

1. **Sandboxing** — OS-level process isolation that restricts Claude Code's (and its child processes') file and network access. This operates at the kernel level, so the AI cannot circumvent it. The most fundamental and strongest defense layer.
2. **Permissions (allow/deny/ask/default)** — Rules that control what happens when a tool (Bash command, file edit, etc.) is invoked from Claude Code's console: "always allow / always ask / always deny / default (not configured)." Permissions provide fine-grained access control per tool invocation. Using `ask` enables Human-in-the-Loop — systematic visual review.
3. **Hooks (hooks + PreToolUse)** — A mechanism to automatically run shell scripts before and after tool invocations. Lets you inject fine-grained pattern matching and environment-specific custom checks that permissions' allow/deny alone can't handle.
4. **Logging** — This may be needed in enterprise environments, or for debugging this hardening setup itself. We touch on it briefly.

> **Key point:** Layering multiple defenses like this is known as **defense in depth**.

### What about CLAUDE.md?

`CLAUDE.md` (at the project root or `~/.claude/CLAUDE.md`) is meant for recording the purpose, context, and outline of your environment and work. While listing permission policies like "don't push directly to main" or "don't commit until tests pass" isn't entirely meaningless, CLAUDE.md has a limited capacity (around 200 lines is recommended), and while it's fine for context, it's not well suited as a place for deny policies. On top of that, even if you do write them there, they're merely "requests" at best — and they're often forgotten.

When something should not happen, stop it by force rather than by asking — figuring out how to do that is the starting point of this document.

### About the examples

Deny rules catch obvious cases. The sandbox prevents damage even when commands slip through. Hooks add environment-specific custom logic.

This document covers what to block, what to allow, what to always ask about, and what to do when deny rules aren't enough. The deny list examples here are samples, not a complete list. They start from the perspective of what risks to suppress. This cheatsheet is primarily written and tested on macOS, but should be useful for Linux and Windows (WSL) as well.

Customize for your own environment and risk profile.

---

## 2. Sandboxing

The sandbox isolates Claude Code's file and network access at the OS level. Even if a deny rule is bypassed, the sandbox prevents access to resources outside defined boundaries. It is the strongest protection layer available — consider it essential.

Supported on macOS (Seatbelt), Linux, and WSL2 (bubblewrap). WSL1 is not supported at the time of writing — please verify for your environment.

### How to enable

- Run `/sandbox` in Claude Code's interactive mode. This opens a menu where you can enable sandboxing and configure its mode.

- Doing this manually each time is tedious and error-prone, so configure it in settings instead.

`settings.json` configuration:

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
| `denyRead` | This is a bonus / customization section. Blocks access to credential stores even within the sandbox. In this example, SSH keys, GPG keys, AWS credentials, and GCP configs are configured so the AI assistant cannot read them directly. (However... this can be bypassed if the path is passed as an argument to a Bash command like `cat`, so the implementation is admittedly imperfect.) |

> **Key point:** Designing defenses that minimize the scope of impact is known as the **principle of least privilege**.

---

## 3. Permission System

Use Claude Code's permission system to control what is allowed when a command or tool is invoked. Understand that there are four levels of rules.

### Permission levels

| Permission | Behavior | Purpose |
|------------|----------|---------|
| `deny` | Always blocked (no prompt) | Guardrails |
| `ask` | Always prompted (even if previously approved with "don't ask again") | Human-in-the-Loop — usually trusted, but create a checkpoint for review |
| `allow` | Always permitted (no prompt) | Convenience — for trusted operations where you want to skip confirmation |
| _(default / not configured)_ | Prompted on first use; "don't ask again" makes it permanent | The default judgment is in your head — you may say yes too quickly when busy, or can't tell safe from unsafe when unsure. (Everyone occasionally doubts their own reliability.) |

> **Key insight:** `deny` is for things that should **never** happen. `allow` is for things you **always** trust. `ask` is for things you **usually** trust but want to verify.

### Where to put rules

These rules can be set under your HOME directory or per project (folder/directory/repository) shared with your team.

| File | Who | Scope | Git |
|------|-----|-------|-----|
| `~/.claude/settings.json` | You only | All your projects on this machine | Not in any repo |
| `<project>/.claude/settings.json` | Entire team | This project only | Committed and shared with everyone |
| `<project>/.claude/settings.local.json` | You only | This project only | Lives in the repo directory but gitignored — never pushed |

---

## 4. Thinking About Rules: Deny / Ask / Allow

This section lists specific rules organized by threat category. Each rule includes the rationale so you can decide whether it applies to your environment.

See [`settings_example.jsonc`](settings_example.jsonc) for a single file containing all rules below, with `allow` and `ask` examples and commentary in comments. Note that comments will cause JSON errors if left in place.

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

An AI assistant should never escalate privileges. `sudo` requires a password, but it's more reliable to deny the attempt itself.

### 4.5 Deny — Remote Code Execution via Pipe

Prevent downloading and executing untrusted scripts in one step. These rules do not affect web page access.

```json
"Bash(curl *|*sh)",
"Bash(wget *|*sh)"
```

Piping remote scripts directly into a shell (`curl ... | sh`) is a classic supply chain attack vector. Claude Code may suggest this as a standard "install" step — and users tend to approve it reflexively because it *looks like* a normal installation procedure. Better to let Claude Code tell you the command and run it yourself.

### 4.6 Deny — Remote Access

Prevent Claude Code from initiating connections to remote hosts. An AI assistant should not initiate remote connections. These commands can transfer files or execute commands on remote hosts.
When sandbox mode is enabled, network access is blocked at the OS level, but Claude Code can still attempt to execute these commands — that's why they're listed here.

```json
"Bash(ssh *)",
"Bash(scp *)",
"Bash(rsync *)"
```

If you need remote access, consider allowing specific targets instead of a blanket allow.

### 4.7 Deny — Package Publishing & Deployment

Prevent unintended package publishing and deployment, even in CI/CD contexts.
Publishing packages or triggering deployments should be a deliberate human action. Unless explicitly designed into your workflow, an AI should not do this autonomously.

```json
"Bash(npm publish *)",
"Bash(yarn publish *)",
"Bash(pnpm publish *)",
"Bash(*deploy*)"
```

### 4.8 Deny — Easy to Approve, Hard to Undo (macOS)

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

`.env` files typically contain API keys, database passwords, and other secrets.

Consider adding more patterns for your environment:

```json
"Read(**/*.pem)",
"Read(**/*.key)",
"Read(**/credentials*)"
```

### 4.11 Deny — MCP Actions: Preventing Impersonation Messages

Prevent Claude Code from sending messages on your behalf (impersonation).
An AI assistant reading messages for context is different from it **sending** messages — the latter should require your explicit action.

```json
"mcp__claude_ai_Slack__slack_send_message",
"mcp__claude_ai_Slack__slack_schedule_message"
```

### 4.12 Ask — Human-in-the-Loop

It's hard to make everything black or white.
For useful, legitimate commands where **a human should still review each invocation**, use `ask`.

When you approve a command with "Yes, don't ask again", it becomes permanently allowed for that project. `ask` rules override this — Claude Code will **always** prompt you, even if you previously said "don't ask again". This is one way to implement the Human-in-the-Loop (HITL) approach.

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
| `git commit` | You want to review the commit message and what's being committed each time. |
| `git push` | Branch and remote operations should be verified each time. |
| `npm/pip/brew install` | Adding dependencies carries the risk of introducing vulnerabilities. Keep a review checkpoint. |
| `psql / mysql / mongosh / sqlite3` | Note that pattern matching can't distinguish `SELECT` from `DROP TABLE`! |

#### A note on database commands

Commands like `psql`, `mysql`, `mongosh`, and `sqlite3` can be destructive (`DROP TABLE`, `DELETE FROM`), but Claude Code's deny rules can't distinguish the content of command arguments. Denying `Bash(psql *)` blocks all usage, including harmless `SELECT` queries needed for analysis.

**Recommendation:** Use `ask` for database commands rather than `deny`.
When the prompt appears, you can distinguish read queries from destructive operations.

### 4.13 Allow — Trusted Operations

Allow rules skip the permission prompt for commands you trust.
Useful for reducing prompt fatigue on safe, frequently-used operations.

For example, test/build commands, safe git operations, MCP read-only actions, etc.

We've included samples, so see the commented-out `allow` section in [`settings_example.jsonc`](settings_example.jsonc).

---

## 5. Hooks — When Deny Rules Aren't Enough

Deny rules are enforced by the Claude Code harness (not the AI model), so Claude cannot "choose" to ignore them.
However, for operations like database commands or access to sensitive information, deny's pattern matching isn't sufficient to distinguish what command will actually be executed.

Deny rules use glob pattern matching, which has inherent limitations:

Examples:
- `Bash(sudo *)` blocks `sudo rm -rf /` but not a script that internally calls `sudo`
- `Bash(curl *|*sh)` blocks `curl url | sh` but not `wget -O- url | bash`
- `Bash(rm -rf *)` blocks `rm -rf /tmp` but not a Makefile target that runs `rm -rf` internally

This is where **Hooks** come in — custom shell scripts that run at specific points in Claude Code's lifecycle. The most important is **before a tool call is executed** (`PreToolUse`). Unlike deny rules that can only match command patterns, a hook script receives the full command as JSON input and can apply arbitrary logic: inspect arguments, check file contents, query external systems, or block the call.

### Detailed explanation

From the [official documentation](https://code.claude.com/docs/en/permissions):

> A deny rule for `Read(./.env)` blocks the Read tool but does **not** prevent `cat .env` in Bash.

This means `Read(**/.env)` in your deny list stops Claude's built-in Read tool, but Claude can still run `Bash(cat .env)`, `Bash(grep password .env)`, or any other Bash command that reads the file. The deny rules for Read and Bash are **separate layers that don't cover each other**.

### Use case 1: Block destructive SQL in database commands

**Problem:** Denying `Bash(psql *)` blocks `SELECT` too. But you want to catch `DROP TABLE` or `DELETE FROM` before they execute.

**Hook script** — save as `~/.claude/hooks/block-destructive-sql.sh`:

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

**Settings** — add to your `settings.json`:

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

Now `psql -c "SELECT * FROM users"` proceeds normally, but `psql -c "DROP TABLE users"` is blocked with a reason.

### Use case 2: Block Bash from reading sensitive files

**Problem:** `Read(**/.env)` in your deny list blocks Claude's Read tool, but `cat .env` through Bash bypasses it.

**Hook script** — save as `~/.claude/hooks/block-sensitive-reads.sh`:

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

**Settings** — same structure, same matcher:

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

### Use case 3: Block push to main/master branch

**Problem:** `git push` is useful so you've set it to `ask`, but an accidental approval can push directly to main. The deny rule `Bash(git push *)` can't distinguish branches.

**Hook script** — save as `~/.claude/hooks/block-push-to-main.sh`:

```bash
#!/bin/bash
INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command')

# Skip if not a git push command
echo "$CMD" | grep -qE '^\s*git\s+push' || exit 0

# Explicit main/master in the command
if echo "$CMD" | grep -qE '\b(main|master)\b'; then
  echo "Blocked: push to main/master is not allowed: $CMD" >&2
  exit 2
fi

# Implicit push (no args or remote only) — check current branch
if echo "$CMD" | grep -qE '^\s*git\s+push\s*$' || \
   echo "$CMD" | grep -qE '^\s*git\s+push\s+(-[a-zA-Z]+\s+)*[a-zA-Z0-9_.-]+\s*$'; then
  CURRENT=$(git branch --show-current 2>/dev/null)
  if [ "$CURRENT" = "main" ] || [ "$CURRENT" = "master" ]; then
    echo "Blocked: currently on $CURRENT — push to main/master is not allowed" >&2
    exit 2
  fi
fi

exit 0
```

```bash
chmod +x ~/.claude/hooks/block-push-to-main.sh
```

**Settings** — add to your `settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/block-push-to-main.sh"
          }
        ]
      }
    ]
  }
}
```

This blocks `git push origin main` and bare `git push` when on the main branch. Pushes to feature branches go through normally.

> **Note:** This will also match branch names that contain "main" or "master" as a substring, such as `feature/main-cleanup`. Adjust the pattern if needed.

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
          },
          {
            "type": "command",
            "command": "~/.claude/hooks/block-push-to-main.sh"
          }
        ]
      }
    ]
  }
}
```

---

## 6. How to Keep Denial Logs?

Blocked operations from deny rules are shown during the session but are not logged to a file by default.

To keep an audit trail of denied operations, you can set up OpenTelemetry. See https://code.claude.com/docs/en/monitoring-usage for details.

---

## References

### Official Documentation

- [Claude Code Security Best Practices](https://code.claude.com/docs/en/security)
- [Claude Code Settings](https://code.claude.com/docs/en/settings)
- [Claude Code Permissions](https://code.claude.com/docs/en/permissions)
- [Claude Code Sandboxing](https://code.claude.com/docs/en/sandboxing)
- [Claude Code Hooks Guide](https://code.claude.com/docs/en/hooks-guide)

## Related Cheat Sheets & Further Reading

- [OWASP AI Agent Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/AI_Agent_Security_Cheat_Sheet.html) — Covers key risks and best practices for AI agent systems: tool permission minimization, prompt injection prevention, human-in-the-loop controls, and more.
- [OWASP LLM Prompt Injection Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Prompt_Injection_Prevention_Cheat_Sheet.html) — Technical guidance on defending against prompt injection attacks.
- [OWASP Top 10 for LLM Applications](https://genai.owasp.org/llm-top-10/) — The broader threat landscape for LLM-powered applications.
