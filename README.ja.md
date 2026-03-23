# claude-code-setting-hardening

**[English version](README.md)**

[Claude Code](https://code.claude.com/) の `~/.claude/settings.json` に適用する、最小限のセキュリティ強化テンプレートです。

Claude Code はシェルコマンドの実行、ファイルの読み取り、外部サービスとの連携が可能です。これらの設定は、Claude Code に**やらせるべきでないこと**を明確に制限し、安心して**やらせたいこと**に集中できるようにします。

## クイックスタート

**方法A: スクリプトで適用**

```bash
git clone https://github.com/okdt/claude-code-setting-hardening.git
cd claude-code-setting-hardening
chmod +x setup-claude-code-env-hardening.sh
./setup-claude-code-env-hardening.sh
```

**方法B: テンプレートをコピー**

```bash
cp settings-template.json ~/.claude/settings.json
```

> 既に `settings.json` がある場合は、既存の設定を残すために手動でマージしてください。

## 設定内容の解説

### サンドボックス

```json
"sandbox": {
  "enabled": true,
  "autoAllowBashIfSandboxed": true,
  "filesystem": {
    "denyRead": ["~/.ssh", "~/.gnupg", "~/.aws", "~/.config/gcloud"]
  }
}
```

| 設定 | 理由 |
|------|------|
| `enabled: true` | OS レベルでファイル・ネットワークアクセスを分離。カレントディレクトリと明示的に許可されたパスのみアクセス可能になる。 |
| `autoAllowBashIfSandboxed` | サンドボックスが有効な状態では Bash コマンドの許可プロンプトを省略。サンドボックスがスコープを制約するため安全。 |
| `denyRead` | サンドボックス内であっても認証情報ストアへのアクセスをブロック。SSH鍵、GPG鍵、AWS認証情報、GCP設定はAIアシスタントが読み取るべきではない。 |

### 拒否リスト — 破壊的な Git 操作

```json
"Bash(git push -f *)",
"Bash(git push --force *)",
"Bash(git reset --hard *)",
"Bash(git checkout .)",
"Bash(git clean -f *)",
"Bash(git add .)",
"Bash(git add -A)"
```

| ルール | リスク |
|--------|--------|
| `git push -f / --force` | リモートの履歴を上書き。チームメンバーの作業を破壊する可能性がある。 |
| `git reset --hard` | コミットされていない変更をすべて不可逆的に破棄する。 |
| `git checkout .` | ワーキングツリーの変更を無言で元に戻す。 |
| `git clean -f` | 追跡されていないファイルを完全に削除する。 |
| `git add . / -A` | すべてをステージング — `.env`、認証情報、巨大なバイナリを誤って含む可能性がある。 |

### 拒否リスト — リモートアクセス

```json
"Bash(ssh *)",
"Bash(scp *)",
"Bash(rsync *)"
```

AIアシスタントがリモート接続を開始すべきではない。これらのコマンドはリモートホストへのファイル転送やコマンド実行が可能。リモートシステムとの連携が必要な場合は、全面的に許可するのではなく、特定のターゲットだけを許可することを検討してください。

### 拒否リスト — パッケージ公開とデプロイ

```json
"Bash(npm publish *)",
"Bash(yarn publish *)",
"Bash(pnpm publish *)",
"Bash(*deploy*)"
```

パッケージの公開やデプロイのトリガーは、人間が意図的に行うべきアクション。AIが自律的に行うべきではない。誤った publish は下流のすべての利用者に影響を及ぼす。

### 拒否リスト — インフラストラクチャ

```json
"Bash(terraform apply *)"
```

`terraform apply` はクラウドインフラの作成・変更・破壊を行う。常に人間の明示的な承認が必要。

### 拒否リスト — 機密ファイルへのアクセス

```json
"Read(**/.env)",
"Read(**/.env.*)"
```

`.env` ファイルには通常、APIキー、データベースパスワードなどの秘密情報が含まれる。Claude Code がこれらを読む必要はなく、代わりに `.env.example` やドキュメントを参照すればよい。

### 拒否リスト — MCP アクション

```json
"mcp__claude_ai_Slack__slack_send_message",
"mcp__claude_ai_Slack__slack_schedule_message"
```

Claude Code があなたの名義で Slack メッセージを送信することを防止する。AIアシスタントがコンテキスト把握のためにメッセージを**読む**ことと、**送信する**ことは別問題 — 後者はあなたの明示的なアクションであるべき。

## カスタマイズ

このテンプレートは出発点です。環境に合わせてルールを追加してください：

```json
// CI/CD ツール
"Bash(kubectl apply *)",
"Bash(helm install *)",
"Bash(docker push *)",

// データベース
"Bash(psql *)",
"Bash(mysql *)",
"Bash(mongosh *)",

// その他の機密ファイル
"Read(**/*.pem)",
"Read(**/*.key)",
"Read(**/credentials*)"
```

### `allow` を使うべき場面

プロジェクト固有で**より緩和した**権限が必要な場合は、`settings.local.json`（git にコミットしない）またはプロジェクトレベルの `.claude/settings.json` を使用してください：

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

## ファイル構成

| ファイル | 説明 |
|---------|------|
| `setup-claude-code-env-hardening.sh` | 対話型スクリプト — 既存設定を検出し、上書き前にバックアップを作成 |
| `settings-template.json` | `~/.claude/settings.json` にコピーして使うテンプレート |

## 参考資料

- [Claude Code セキュリティのベストプラクティス](https://code.claude.com/docs/ja/security)
- [Claude Code 設定ドキュメント](https://code.claude.com/docs/ja/settings)
- [Claude Code アクセス許可](https://code.claude.com/docs/ja/permissions)
- [Claude Codeの設定でやるべきセキュリティ対策](https://qiita.com/dai_chi/items/f6d5e907b9fee791b658)

## ライセンス

MIT
