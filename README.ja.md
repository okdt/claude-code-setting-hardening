# claude-code-hardening-cheatsheet

**[English version](README.md)**

[Claude Code](https://code.claude.com/) の `~/.claude/settings.json` に適用するセキュリティ強化チートシートです。

Claude Code はシェルコマンドの実行、ファイルの読み取り、外部サービスとの連携が可能です。これらの設定は、Claude Code に**やらせるべきでないこと**を明確に制限し、安心して**やらせたいこと**に集中できるようにします。

## クイックスタート

**方法A: スクリプトで適用**

```bash
git clone https://github.com/okdt/claude-code-hardening-cheatsheet.git
cd claude-code-hardening-cheatsheet
chmod +x hardening-claude-code-env.sh
./hardening-claude-code-env.sh
```

**方法B: サンプルをコピー**

```bash
# コメントを除去してコピー
grep -v '^\s*//' settings-example.jsonc > ~/.claude/settings.json
```

> 既に `settings.json` がある場合は、既存の設定を残すために手動でマージしてください。

## 設定内容の解説

### サンドボックス

Claude Code のファイル・ネットワークアクセスをOS レベルで分離する。

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
| `enabled: true` | OS レベルでファイル・ネットワークアクセスを分離。カレントディレクトリと明示的に許可されたパスのみアクセス可能になる。macOS（Seatbelt）、Linux・WSL2（bubblewrap）対応。 |
| `autoAllowBashIfSandboxed` | サンドボックスが有効な状態では Bash コマンドの許可プロンプトを省略。サンドボックスがスコープを制約するため安全。 |
| `denyRead` | サンドボックス内であっても認証情報ストアへのアクセスをブロック。SSH鍵、GPG鍵、AWS認証情報、GCP設定はAIアシスタントが読み取るべきではない。 |

### 拒否リスト — 破壊的な Git 操作

リポジトリと履歴に対する不可逆な変更を防ぐ。

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

### 拒否リスト — 破壊的ファイル操作

プロジェクトツリーを丸ごと消しかねない一括削除を防ぐ。

```json
"Bash(rm -rf *)",
"Bash(rm -r *)"
```

| ルール | リスク |
|--------|--------|
| `rm -rf` | 確認なしでディレクトリを再帰的に削除。パスを間違えるとプロジェクト全体が消える。 |
| `rm -r` | 上記と同様。設定によっては確認が入るが、無条件に許可するには危険すぎる。 |

### 拒否リスト — 危険なシステム操作

パーミッション変更やプロセス強制終了による環境の不安定化を防ぐ。

```json
"Bash(chmod 777 *)",
"Bash(chmod -R *)",
"Bash(chown -R *)",
"Bash(killall *)",
"Bash(pkill *)",
"Bash(kill -9 *)",
```

| ルール | リスク |
|--------|--------|
| `chmod 777` | ファイルを誰でも読み書き実行可能にする。セキュリティのアンチパターン。 |
| `chmod -R / chown -R` | 再帰的な権限・所有者変更はシステムディレクトリの破壊や機密ファイルの露出につながる。 |
| `killall / pkill` | 名前でプロセスを終了。無関係な重要プロセスを停止する可能性がある。 |
| `kill -9` | クリーンアップなしの強制終了。実行中アプリのデータ破損を引き起こしうる。 |

### 拒否リスト — 権限昇格

Claude Code が root 権限でコマンドを実行することを防ぐ。

```json
"Bash(sudo *)"
```

AIアシスタントが権限昇格すべきではない。`sudo` はパスワードを要求するが、そもそも試みること自体を deny で防ぐ方が確実。

### 拒否リスト — パイプ経由のリモートコード実行

信頼できないスクリプトのダウンロードと実行を一手で行うことを防ぐ。

```json
"Bash(curl *|*sh)",
"Bash(wget *|*sh)"
```

リモートスクリプトを直接シェルにパイプする（`curl ... | sh`）のはサプライチェーン攻撃の典型的な手法。Claude Code は「インストール手順」としてこれを提案することがあり、ユーザーは普通のインストールに見えるため反射的に許可しがち。

### 拒否リスト — macOS: つい許可しがちだが取り返しがつかないもの

無害に見えるが深刻な被害を引き起こしうる macOS コマンドをブロックする。これらは文脈の中では**無害に見える**ため、ユーザーが深く考えずに許可してしまいやすい。それこそが危険な理由。

```json
"Bash(open *)",
"Bash(osascript *)",
"Bash(defaults write *)"
```

| ルール | つい許可してしまう理由 | 実際のリスク |
|--------|---------------------|------------|
| `open` | 「ファイルやURLを開くだけ」 | 任意のアプリを起動、フィッシングURLを開く、ダウンロードファイルを実行する可能性。MCP ブラウザツール（Puppeteer等）は `open` を使わないので、ブラウザ自動化には影響しない。 |
| `osascript` | 「Finderの操作を自動化するだけ」 | AppleScript はメール送信、アプリ制御、キーチェーンアクセスなど、ほぼ何でも可能。 |
| `defaults write` | 「設定を変えるだけ」 | セキュリティ上重要な macOS 設定の変更、Gatekeeper の無効化、アプリ動作の改変が可能。 |

### 拒否リスト — リモートアクセス

Claude Code がリモートホストへ接続することを防ぐ。

```json
"Bash(ssh *)",
"Bash(scp *)",
"Bash(rsync *)"
```

AIアシスタントがリモート接続を開始すべきではない。これらのコマンドはリモートホストへのファイル転送やコマンド実行が可能。リモートシステムとの連携が必要な場合は、全面的に許可するのではなく、特定のターゲットだけを許可することを検討してください。

### 拒否リスト — パッケージ公開とデプロイ

意図しないパッケージ公開やデプロイを防ぐ。

```json
"Bash(npm publish *)",
"Bash(yarn publish *)",
"Bash(pnpm publish *)",
"Bash(*deploy*)"
```

パッケージの公開やデプロイのトリガーは、人間が意図的に行うべきアクション。AIが自律的に行うべきではない。誤った publish は下流のすべての利用者に影響を及ぼす。

### 拒否リスト — インフラストラクチャ

クラウドインフラへの自律的な変更を防ぐ。

```json
"Bash(terraform apply *)"
```

`terraform apply` はクラウドインフラの作成・変更・破壊を行う。常に人間の明示的な承認が必要。

### 拒否リスト — 機密ファイルへのアクセス

シークレットを含むファイルの読み取りを防ぐ。

```json
"Read(**/.env)",
"Read(**/.env.*)"
```

`.env` ファイルには通常、APIキー、データベースパスワードなどの秘密情報が含まれる。Claude Code がこれらを読む必要はなく、代わりに `.env.example` やドキュメントを参照すればよい。

### 拒否リスト — MCP アクション

Claude Code があなたの名義でメッセージを送信することを防ぐ。

```json
"mcp__claude_ai_Slack__slack_send_message",
"mcp__claude_ai_Slack__slack_schedule_message"
```

Claude Code があなたの名義で Slack メッセージを送信することを防止する。AIアシスタントがコンテキスト把握のためにメッセージを**読む**ことと、**送信する**ことは別問題 — 後者はあなたの明示的なアクションであるべき。

## カスタマイズ

上記の deny ルールは出発点です。環境に合わせてルールを追加してください：

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

### `deny` と `allow` の関係

Claude Code のパーミッションモデルには3段階あります：

| パーミッション | 動作 | 設定場所 |
|--------------|------|---------|
| `allow` | 常に許可（プロンプトなし） | `settings.json` または `settings.local.json` |
| _（デフォルト）_ | 毎回ユーザーに確認 | — |
| `deny` | 常にブロック（プロンプトなし） | `settings.json` |

`deny` は `allow` より優先されます。同じルールが両方にある場合、拒否されます。

**`deny` はガードレール** — コンテキストに関係なく絶対に起きてはならないこと（破壊的操作、認証情報へのアクセス、メッセージ送信）。

**`allow` は利便性のため** — 信頼できる操作で、毎回の確認プロンプトを省きたいもの。

### `allow` ルールの設定場所

| ファイル | スコープ | Git |
|---------|---------|-----|
| `~/.claude/settings.json` | このマシンの全プロジェクト | 対象外 |
| `.claude/settings.json` | このプロジェクト、全メンバー | コミット |
| `.claude/settings.local.json` | このプロジェクト、自分のみ | gitignore |

プロジェクト固有の allow は `.claude/settings.local.json` に書くことで、個人の設定をチームに押し付けずに済みます：

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

[`settings-example.jsonc`](settings-example.jsonc) のコメントアウトされた `allow` セクションに例があります。

## ファイル構成

| ファイル | 説明 |
|---------|------|
| `hardening-claude-code-env.sh` | 対話型スクリプト — ローカル環境保護ルール（sandbox + deny）を適用。既存設定を検出し、上書き前にバックアップを作成 |
| `settings-example.jsonc` | `~/.claude/settings.json` の全体サンプル — スクリプトが適用するルールに加え、追加ルール（リモートアクセス、パッケージ公開、デプロイ、MCP）と allow の例をコメントアウトで収録 |

## 参考資料

- [Claude Code セキュリティのベストプラクティス](https://code.claude.com/docs/ja/security)
- [Claude Code 設定ドキュメント](https://code.claude.com/docs/ja/settings)
- [Claude Code アクセス許可](https://code.claude.com/docs/ja/permissions)
- [Claude Codeの設定でやるべきセキュリティ対策](https://qiita.com/dai_chi/items/f6d5e907b9fee791b658)

## ライセンス

[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/deed.ja) — 帰属表示をすれば、自由に利用・改変・再配布できます。
