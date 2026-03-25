# claude-code-hardening-cheatsheet

**[日本語版(Japanese)](README.ja.md)**

A security hardening cheatsheet for [Claude Code](https://code.claude.com/) `~/.claude/settings.json`.

Claude Code is powerful — it can run shell commands, read files, and interact with external services. These settings restrict what it's **not allowed** to do, so you can focus on what it **should** do.

This cheatsheet is primarily written and tested on macOS, but most rules apply equally to Linux and Windows (WSL). Platform-specific rules are marked as such.

## Cheatsheet

- [Claude Code Hardening Cheatsheet (English)](Claude_Code_Hardening_Cheat_Sheet.md)

## Files

| File | Description |
|------|-------------|
| [`Claude_Code_Hardening_Cheat_Sheet.md`](Claude_Code_Hardening_Cheat_Sheet.md) | Full cheatsheet — deny/allow/ask rules explained with rationale |
| [`settings_example.jsonc`](settings_example.jsonc) | Example `settings.json` with all rules and commented-out allow/ask examples |

## Author

Riotaro OKADA ([okdt](https://github.com/okdt))

## License

[CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/) — Free to use, share, and adapt with attribution. Derivatives must use the same license.
