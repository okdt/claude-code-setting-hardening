# Claude Code Hardening Cheatsheet

**[日本語版 (Japanese)](README.md)**

A cheatsheet and configuration samples for running Claude Code on the safer side.

This repository has two goals:

- Distill general hardening principles into practical, day-to-day Claude Code settings
- Provide ready-to-use configuration examples covering `sandbox` / `permissions` / `hooks`

This is not official Anthropic documentation. Always verify against the official docs and your current Claude Code version before applying to production.

## Included Files

- [Claude_Code_Hardening_Cheat_Sheet.ja.md](./Claude_Code_Hardening_Cheat_Sheet.ja.md)
  Main cheatsheet — hardening principles, recommended settings, and operational notes (Japanese)
- [Claude_Code_Hardening_Cheat_Sheet.md](./Claude_Code_Hardening_Cheat_Sheet.md)
  English companion version kept aligned with the Japanese cheatsheet
- [settings_example.jsonc](./settings_example.jsonc)
  Commented `settings.json` template — all rules with allow/ask examples in comments

## How To Use

This document is structured for progressive adoption, from beginners looking for safe defaults to advanced users fine-tuning settings for their specific needs.

- **Beginners:** Start by enabling the sandbox (Section 2). This alone makes a significant difference
- **Practitioners:** Design project-appropriate permissions with deny / ask / allow rules (Sections 3–4)
- **Advanced:** Add custom checks with Hooks (Section 5) for cases that pattern matching cannot handle

The template [`settings_example.jsonc`](settings_example.jsonc) contains all rules with commented allow/ask examples. Pick the rules you need and copy them into your `settings.json` (comment lines must be removed first).

## Scope

This repository covers:

- Claude Code sandbox configuration
- Permission policies (deny / ask / allow)
- Advanced custom checks via Hooks
- Logging denied operations

The following are out of scope:

- Security quality of generated code (that concerns what Claude Code writes, not how it behaves)
- Enterprise-specific DLP / SIEM / EDR designs
- Replacement for official Anthropic documentation
- One-size-fits-all configurations

## Notes

- Configuration keys and behavior may change across Claude Code versions
- Primarily written and tested on macOS, but most rules apply equally to Linux and Windows (WSL). Platform-specific rules are marked as such
- The deny lists are samples, not exhaustive. They are organized by risk perspective
- The cheatsheet references OWASP GenAI / Prompt Injection resources and covers secure design principles including Human-In-The-Loop, least privilege, and defense in depth

## Author

Riotaro OKADA ([okdt](https://github.com/okdt))

## License

[CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/) — Free to use, share, and adapt with attribution. Derivatives must use the same license.

## References

- [Claude Code official documentation](https://code.claude.com/docs/en)

## Related Document

- [Codex CLI Hardening Cheatsheet](https://github.com/okdt/codex-hardening-cheatsheet) — Hardening cheatsheet for OpenAI Codex CLI
