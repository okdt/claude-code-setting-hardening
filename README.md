# Claude Code Hardening Cheatsheet

**[English version](README.en.md)**

Claude Code を安全寄りに運用するための、日本語チートシートと設定サンプル集です。

このリポジトリの目的は次の 2 点です。

- 一般的なハードニングの考え方を、Claude Code の日常運用に落とし込んで整理する
- `sandbox` / `permissions` / `hooks` など、Claude Code で実際に効く設定例をすぐ使える形で提供する

これは Anthropic 公式ドキュメントではありません。実運用前に、利用中の Claude Code バージョンと公式情報を必ず確認してください。

## Included Files

- [Claude_Code_Hardening_Cheat_Sheet.ja.md](./Claude_Code_Hardening_Cheat_Sheet.ja.md)
  一般的なハードニングの考え方、Claude Code の推奨設定、運用上の注意点をまとめた本体
- [Claude_Code_Hardening_Cheat_Sheet.md](./Claude_Code_Hardening_Cheat_Sheet.md)
  An English companion version kept aligned with the Japanese cheatsheet
- [settings_example.jsonc](./settings_example.jsonc)
  コメント付きの `settings.json` テンプレート — 全ルールと allow/ask の例をコメントアウトで収録

## How To Use

このドキュメントは、まず安全な共通設定を知りたい初学者から、
自分の利用実態やプロジェクトの目的に合わせて設定を調整したい上級者まで、
段階的に使えるように構成しています。

- **初心者:** まずサンドボックス（セクション2）を有効化してください。これだけでも大きく変わります
- **実務者:** deny / ask / allow ルール（セクション3〜4）で、プロジェクトに合ったパーミッションを設計してください
- **上級者:** Hooks（セクション5）で、パターンマッチでは対応できないカスタムチェックを追加してください

設定テンプレート [`settings_example.jsonc`](settings_example.jsonc) には全ルールと allow/ask の例がコメント付きで収録されています。必要なルールを選んで `settings.json` に転記してください（コメント行はそのままでは使えません）。

## Scope

このリポジトリは、次のような観点を扱います。

- Claude Code のサンドボックス設定
- パーミッション（deny / ask / allow）の基本方針
- Hooks による高度なカスタムチェック
- 拒否操作のログ記録

次のものは主目的ではありません。

- 生成されるコードのセキュリティ品質（これは Claude Code が書くコードの話であり、Claude Code 自体の動作制御とは別です）
- 企業固有の DLP / SIEM / EDR 設計
- Anthropic 公式仕様の代替
- すべての環境でそのまま使える万能設定

## Notes

- 設定キーや挙動は Claude Code のバージョンによって変わる可能性があります
- 主に macOS 環境で執筆・検証していますが、ほとんどのルールは Linux や Windows（WSL）でもそのまま参考になります。プラットフォーム固有のルールにはその旨を明記しています
- deny リストはサンプルであり、コンプリートリストではありません。リスクの観点から抑制したいものを列挙しています
- チートシート本体では、OWASP の GenAI / Prompt Injection 関連資料を参照しつつ、Human-In-The-Loop、最小権限の原則、多層防御といったセキュア設計の基本原則もあわせて解説しています

## Author

Riotaro OKADA ([okdt](https://github.com/okdt))

## License

[CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/deed.ja) — 帰属表示をすれば、自由に利用・改変・再配布できます。改変物は同じライセンスで公開してください。

## References

- [Claude Code 公式ドキュメント](https://code.claude.com/docs/ja)

## Related Document

- [Codex CLI Hardening Cheatsheet](https://github.com/okdt/codex-hardening-cheatsheet) — OpenAI Codex CLI 版のハードニングチートシート
