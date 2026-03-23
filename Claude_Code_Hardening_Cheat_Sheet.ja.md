# Claude Code Hardening Cheatsheet

---

## 1. はじめに

Claude Code はユーザに代わってシェルコマンドの実行、ファイルの読み書き、外部サービスとの連携などを実施します。これは強力で、同時にリスクが伴います。

### リスク — なぜハードニングが必要か

- **善意のやりすぎ** — Claude Code は技術的には正しくても、あなたの意図を超えた操作をすることがあります。「整理」のためにファイルを削除したり、「修正」のために force-push したり、頼んでいないパッケージをインストールしたり。（[OWASP LLM09: Overreliance](https://genai.owasp.org/llm-top-10/)）
- **大きすぎる権限** — デフォルトでは、Claude Code はあなたのユーザーアカウントでできることは何でもできます。deny ルールがなければ、たった一度の「はい」で破壊的なコマンド、認証情報ファイル、リモートシステムへのアクセスを許してしまいます。（[OWASP LLM06: Excessive Agency](https://genai.owasp.org/llm-top-10/)）
- **間接的プロンプトインジェクション** — Claude Code が処理するコンテンツ（ソースコード、ドキュメント、Webページ）に、その動作に影響を与える隠された指示が含まれている可能性があります。攻撃者は、Claude が通常の作業中に読むファイルや依存関係に悪意あるプロンプトを埋め込むことができます。（[OWASP LLM01: Prompt Injection](https://genai.owasp.org/llm-top-10/)）
- **侵害された環境の影響範囲** — あなたのマシンが RCE、マルウェア、サプライチェーン攻撃の影響を受けた場合、Claude Code はその侵害を引き継ぎます。ハードニングはブラスト半径を制限します。 — 攻撃者が足がかりを得た後でも、Claude Code を*通じて*できることを最小限に抑えなければなりません。

これらは仮定の話ではありません。ガードレールが存在する理由です。問題が起きたとき — いずれ必ず起きますが... — 被害を封じ込めたい、そんな自分とみなさんのために書きました。
このチートシートは `~/.claude/settings.json` を通じて Claude Code 環境をハードニング（堅牢化）するための実践ガイドです。最小権限の原則や Human In the Loop（HITL）をどのように実践するかを考えるのに良い題材でしょう。

### このドキュメントについて

何をブロックし、何を許可し、何を常に確認すべきか、そして deny ルールだけでは不十分な場合にどうすべきかなどを解説します。なお、本ドキュメントの deny リストはサンプルであり、網羅的ではありません。作者（[okdt](https://github.com/okdt)）がまず抑制したいと考えた操作からスタートしています。出発点として利用し、自分の環境に合わせてカスタマイズしてください。

本チートシートは主に macOS 環境で執筆・検証していますが、ほとんどのルールは Linux や Windows（WSL）でもそのまま参考になります。プラットフォーム固有のルールにはその旨を明記しています。

---

## 2. サンドボックス

サンドボックスは Claude Code のファイル・ネットワークアクセスを OS レベルで分離します。deny ルールがバイパスされた場合でも、定義された境界外のリソースへのアクセスを防ぎます。利用可能な保護レイヤーの中で最も強力ですので、この設定は必須と考えてください。

macOS（Seatbelt）、Linux・WSL2（bubblewrap）に対応しています。この執筆時点では、WSL1 は未対応とのことですが確認してください。

### 有効化の方法

Claude Code の対話モードで `/sandbox` を実行してください。メニューからサンドボックスの有効化とモード設定ができます。`settings.json` で直接設定する場合は以下のとおりです：

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
| `enabled: true` | OS レベルでファイル・ネットワークアクセスを分離します。カレントディレクトリと明示的に許可されたパスのみアクセス可能になります。 |
| `autoAllowBashIfSandboxed` | サンドボックスが有効な状態では Bash コマンドの許可プロンプトを省略します。サンドボックスがスコープを制約するため安全です。 |
| `denyRead` | サンドボックス内であっても認証情報ストアへのアクセスをブロックします。SSH鍵、GPG鍵、AWS認証情報、GCP設定はAIアシスタントが直接読み取るべきではありません。ただし・・・catの引数に設定されたりするとバイパスできたりするので、なんともいえない実装ですよね |

### サンドボックスがあれば大半の deny は冗長

コミュニティには `rm -rf /*`、`dd if=/dev/zero`、`shutdown`、`sudo passwd`、リバースシェル、ファイアウォール操作など 100 件超の deny リストが存在します。サンドボックスが有効であれば、**これらの大半は OS レベルで既にブロックされています** — プロジェクト外への書き込みは失敗し、ネットワークは制限され、権限昇格は不可能です。

サンドボックスがあっても有効な deny ルール：

| カテゴリ | サンドボックスでカバーされない理由 |
|---------|-------------------------------|
| 破壊的 Git 操作（`push -f`、`reset --hard`） | プロジェクト内部の操作 — sandbox は git を制限しない |
| `curl \| sh` 等のパイプ実行 | ダウンロード先ドメインが許可されていれば、プロジェクト内での実行を sandbox は許可する |
| `export PATH=*`、`LD_PRELOAD=*` | sandbox 内の後続コマンドの挙動を改変できる |
| パッケージ公開（`npm publish`、`docker push`） | 許可されたレジストリへのアウトバウンド |
| インフラコマンド（`terraform`、`kubectl`） | 許可された API エンドポイントを使用 |

**判断基準：** プロジェクトディレクトリ外のリソースを対象とする、またはネットワーク / root 権限を必要とするコマンドは、sandbox が既に処理しています。deny ルールは**プロジェクト内の破壊的操作**と**許可された境界内で動作するコマンド**に集中しましょう。

### シェル履歴：守るべきはコマンドではなくファイル

Claude Code の Bash ツールは**コマンドごとに新しいシェルプロセスを起動します**。シェルの状態は呼び出し間で保持されないため、`history` ビルトインは何も返しません。`history | grep password` を deny しても Claude Code では無意味です — grep する履歴が存在しないのです。

ただし、**シェル履歴ファイル**（`~/.bash_history`、`~/.zsh_history`）はディスク上に存在し、あなた自身のターミナルセッションで入力したパスワードやトークン、機密コマンドが含まれている可能性があります。これらは `denyRead` で保護しましょう：

```json
"sandbox": {
  "filesystem": {
    "denyRead": ["~/.ssh", "~/.gnupg", "~/.aws", "~/.config/gcloud",
                  "~/.bash_history", "~/.zsh_history"]
  }
}
```

---

## 3. パーミッションシステム

Claude Code のパーミッションシステムは、コマンドなどツールが呼び出されたときの動作を指示します。ルールを設定する前に、この4段階を理解しておくことが不可欠です。

### パーミッションレベル

| パーミッション | 動作 | 設定場所 |
|--------------|------|---------|
| `allow` | 常に許可（プロンプトなし） | `settings.json` または `settings.local.json` |
| `ask` | 常に確認（「今後聞かない」で許可済みでも毎回聞く） | `settings.json` または `settings.local.json` |
| _（デフォルト）_ | 初回は確認、「今後聞かない」で以降は永続許可 | あなたの頭の中 — 急いでいると安易にYesを押しがちですし、よくわからなくてYes/Noを判断できないこともありますよね！ |
| `deny` | 常にブロック（プロンプトなし） | `settings.json` または `settings.local.json` |

`deny` は `allow` より優先されます。同じルールが両方にある場合、拒否されます。

- **`deny` はガードレール** — コンテキストに関係なく絶対に起きてはならないことです。
- **`allow` は利便性のため** — 信頼できる操作で、毎回の確認プロンプトを省きたいものです。
- **`ask` は Human-in-the-Loop** — たいてい信頼できるが、毎回確認するように明示するものです。

### ルールの設定場所

| ファイル | 誰の設定か | スコープ | Git |
|---------|----------|---------|-----|
| `~/.claude/settings.json` | 自分だけ | このマシンの全プロジェクト | どのリポジトリにも含まれない |
| `<project>/.claude/settings.json` | チーム全員 | このプロジェクトのみ | コミットされ全員に共有される |
| `<project>/.claude/settings.local.json` | 自分だけ | このプロジェクトのみ | リポジトリ内に置くが gitignore で push されないようにしましょう |

* denyはどの設定に書こうと他の設定のallowでオーバーライドすることはできません。逆に、allow は、別の設定で deny することができます。

---

## 4. Allow / Ask / Deny リスト

このセクションでは脅威カテゴリ別に具体的なルールを列挙します。各ルールには根拠を記載していますので、自分の環境に適用すべきかどうかを判断できます。

すべてのルールを1ファイルにまとめたものは [`settings_example.jsonc`](settings_example.jsonc) を参照してください。`allow` と `ask` の例や解説はコメントとして記載されています。ただし、コメントはそのまま残すとjson的にエラーになるのでお気をつけください。

### 4.1 Deny — 破壊的な Git 操作

リポジトリと履歴に対する不可逆な変更を防ぎます。

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
| `git push -f / --force` | リモートの履歴を上書きします。チームメンバーの作業を破壊する可能性があります。 |
| `git reset --hard` | コミットされていない変更をすべて不可逆的に破棄します。 |
| `git checkout .` | ワーキングツリーの変更を無言で元に戻します。 |
| `git clean -f` | 追跡されていないファイルを完全に削除します。 |
| `git add . / -A` | すべてをステージングします — `.env`、認証情報、巨大なバイナリを誤って含む可能性があります。 |

### 4.2 Deny — 破壊的ファイル操作

プロジェクトツリーを丸ごと消しかねない一括削除を防ぎます。

```json
"Bash(rm -rf *)",
"Bash(rm -r *)"
```

| ルール | リスク |
|--------|--------|
| `rm -rf` | 確認なしでディレクトリを再帰的に削除します。パスを間違えるとプロジェクト全体が消えます。 |
| `rm -r` | 上記と同様です。設定によっては確認が入りますが、無条件に許可するには危険すぎます。 |

### 4.3 Deny — 危険なシステム操作

パーミッション変更やプロセス強制終了による環境の不安定化、無防備化を防ぎます。

```json
"Bash(chmod 777 *)",
"Bash(chmod -R *)",
"Bash(chown -R *)",
"Bash(killall *)",
"Bash(pkill *)",
"Bash(kill -9 *)"
```

| ルール | リスク |
|--------|--------|
| `chmod 777` | ファイルを誰でも読み書き実行可能にします。セキュリティのアンチパターンです。 |
| `chmod -R / chown -R` | 再帰的な権限・所有者変更はシステムディレクトリの破壊や機密ファイルの露出につながります。 |
| `killall / pkill` | 名前でプロセスを終了します。無関係な重要プロセスを停止する可能性があります。 |
| `kill -9` | クリーンアップなしの強制終了です。実行中アプリのデータ破損を引き起こしえます。 |

### 4.4 Deny — 権限昇格

Claude Code が root 権限でコマンドを実行することを防ぎます。

```json
"Bash(sudo *)",
"Bash(su *)"
```

AIアシスタント自身が権限昇格すべきではありません。`sudo` はパスワードを要求しますが、そもそも試みること自体を deny で防ぐ方が確実です。

### 4.5 Deny — パイプ経由のリモートコード実行

信頼できないスクリプトのダウンロードと実行を一手で行うことを防ぎます。以下の設定はWebページアクセスには影響しません。

```json
"Bash(curl *|*sh)",
"Bash(wget *|*sh)"
```

リモートスクリプトを直接シェルにパイプする（`curl ... | sh`）のはサプライチェーン攻撃の典型的な手法です。Claude Code は「インストール手順」としてこれを提案することがあり、ユーザーは普通のインストールに見えるため反射的に許可しがちです。Claude Codeの依頼にしたがってユーザが自分で操作するほうが良いでしょう。

### 4.6 Deny — リモートアクセス

Claude Code がリモートホストへ接続することを防ぎます。

```json
"Bash(ssh *)",
"Bash(scp *)",
"Bash(rsync *)"
```

AIアシスタントにリモート接続を許可すべきではありません。これらのコマンドはリモートホストへのファイル転送やコマンド実行が可能です。リモートシステムとの連携が必要な場合は、全面的に許可するのではなく、特定のターゲットだけを許可することを検討してください。

### 4.7 Deny — macOS: つい許可しがちだが取り返しがつかないもの

無害に見えるが深刻な被害を引き起こしうる macOS コマンドがありますので、これらもブロックするという考え方です。ユーザーが深く考えずに許可してしまいやすい — それこそが危険な理由です。

```json
"Bash(open *)",
"Bash(osascript *)",
"Bash(defaults write *)"
```

| ルール | つい許可してしまう理由 | 実際のリスク |
|--------|---------------------|------------|
| `open` | 「ファイルやURLを開くだけ」 | 任意のアプリを起動、フィッシングURLを開く、ダウンロードファイルを実行する可能性があります。MCP ブラウザツール（Puppeteer等）は `open` を使わないので、ブラウザ自動化には影響しません。 |
| `osascript` | 「Finderの操作を自動化するだけ」 | AppleScript はメール送信、アプリ制御、キーチェーンアクセスなど、ほぼ何でも可能です。 |
| `defaults write` | 「設定を変えるだけ」 | セキュリティ上重要な macOS 設定の変更、Gatekeeper の無効化、アプリ動作の改変が可能です。 |

* 他のOSでは、これらのルールは不要ですが、考え方を参考に、それぞれ検討してください（情報お寄せください）

### 4.8 Deny — パッケージ公開とデプロイ

CI/CDとはいえ、意図しないソフトウェアパッケージの公開やデプロイを防ぎます。

```json
"Bash(npm publish *)",
"Bash(yarn publish *)",
"Bash(pnpm publish *)",
"Bash(*deploy*)"
```

パッケージの公開やデプロイのトリガーは、人間が意図的に行うべきアクションです。明示的に設計していない限り、AIが自律的に行うべきではありません。誤った publish は下流のすべての利用者に影響を及ぼします。

### 4.9 Deny — インフラストラクチャ

クラウドインフラへの自律的な変更を防ぎます。

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

| ルール | リスク |
|--------|--------|
| `terraform apply / destroy` | クラウドインフラの作成・変更・破壊を行います。 |
| `kubectl apply / delete` | Kubernetes クラスタ上のワークロードをデプロイまたは削除します。 |
| `helm install / upgrade` | Kubernetes パッケージのインストール・アップグレードです。クラスタ全体に影響しえます。 |
| `docker push` | コンテナイメージをレジストリに公開します。 |
| `aws --no-cli-pager` | AWS CLI をページャなしで実行します — 破壊的な出力を見逃しやすくなります。 |
| `gcloud --quiet` | GCP CLI を確認プロンプトなしで実行します。 |

### 4.10 Deny — 機密ファイルへのアクセス

シークレットを含むファイルの読み取りを防ぎます。

```json
"Read(**/.env)",
"Read(**/.env.*)"
```

`.env` ファイルには通常、APIキー、データベースパスワードなどの秘密情報が含まれます。Claude Code がこれらを読む必要はなく、代わりに `.env.example` やドキュメントを参照すればよいです。

環境に応じて追加を検討してください：

```json
"Read(**/*.pem)",
"Read(**/*.key)",
"Read(**/credentials*)"
```

### 4.11 Deny — MCP アクションによるなりすましメッセージの防止

Claude Code があなたの名義でメッセージを送信することを防ぎます。

```json
"mcp__claude_ai_Slack__slack_send_message",
"mcp__claude_ai_Slack__slack_schedule_message"
```

AIアシスタントがコンテキスト把握のためにメッセージを**読む**ことと、**送信する**ことは別問題です — 後者はあなたの明示的なアクションであるべきです。

### 4.12 Ask — Human-in-the-Loop

すべてが白か黒かではありません。便利で正当なコマンドでも、**毎回人間が確認すべき**ものがあります。それが `ask` の役割です。

一度「はい、今後は聞かない」で承認すると、そのコマンドはプロジェクト内で永続的に許可されます。`ask` ルールはこれを上書きし、以前「聞かない」にしていても**常にプロンプトを表示します**。これが Human-in-the-Loop（HITL）のチェックポイントです。

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

| ルール | なぜ `allow` でも `deny` でもなく `ask` なのか |
|--------|------------------------------------------|
| `git commit` | コミットメッセージと対象を毎回確認したいからです。 |
| `git push` | 便利ですが、ブランチとリモートを毎回確認すべきです。 |
| `npm/pip/brew install` | 依存関係の追加は脆弱性を持ち込む可能性があります。一目確認する価値があります。 |
| `psql / mysql / mongosh / sqlite3` | パターンでは `SELECT` と `DROP TABLE` を区別できません。プロンプトが唯一の確認手段です。 |

> **ポイント:** `deny` は**絶対に起きてはならない**こと。`allow` は**常に信頼できる**こと。`ask` は**たいてい信頼できるが確認したい**こと — 確認しなかった1回が問題になるかもしれないからです。

#### データベースコマンドについて

`psql`、`mysql`、`mongosh`、`sqlite3` などは破壊的な操作（`DROP TABLE`、`DELETE FROM`）が可能ですが、Claude Code の deny ルールはコマンドの引数の中身までは区別できません。`Bash(psql *)` を deny にすると、分析に必要な `SELECT` クエリも含めてすべてブロックされてしまいます。

**推奨:** データベースコマンドは `deny` ではなく `ask` にすると良いのではないかと思います。プロンプトが出たときに内容を確認するのが、読み取りクエリと破壊的操作を区別する唯一の方法です。

### 4.13 Allow — 信頼できる操作

allow ルールは信頼するコマンドの許可プロンプトを省略します。安全で頻繁に使う操作のプロンプト疲れを軽減するのに有効です。

テスト・ビルドコマンド、安全な git 操作、MCP の読み取り専用アクションなどの例は [`settings_example.jsonc`](settings_example.jsonc) のコメントアウトされた `allow` セクションを参照してください。

---

## 5. Hooks — Deny ルールだけでは不十分なとき

deny ルールは Claude Code のハーネス（CLI ツール本体）が強制するもので、AI モデルが「無視する」ことはできません。ただし、**deny ルールだけでは穴があります**。

Hooks は Claude Code のライフサイクルの特定のタイミングで実行されるカスタムシェルスクリプトです。最も重要なのは**ツール呼び出しの実行前**（`PreToolUse`）です。コマンドパターンしかマッチできない deny ルールとは異なり、Hook スクリプトはコマンド全体を JSON として受け取り、任意のロジックを適用できます — 引数の検査、ファイル内容の確認、外部システムへの問い合わせ、理由を添えた呼び出しのブロックなどです。

Hook が終了コード 2 で終了すると、ツール呼び出しはブロックされます（stderr に書いた理由は Claude にフィードバックとして表示されます）。終了コード 0 なら続行されます。glob パターンでは表現できない精密な制御が可能になります。

### 例1: データベースコマンドの破壊的SQLをブロック

**課題:** `Bash(psql *)` を deny にすると `SELECT` もブロックされてしまいます。でも `DROP TABLE` や `DELETE FROM` は実行前に止めたい。

**Hook スクリプト** — `~/.claude/hooks/block-destructive-sql.sh` として保存：

```bash
#!/bin/bash
INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command')

# 破壊的なSQLキーワードが含まれているか検査
if echo "$CMD" | grep -iqE '(DROP\s|DELETE\s+FROM|TRUNCATE\s|ALTER\s+TABLE.*DROP)'; then
  echo "Blocked: destructive SQL detected in command: $CMD" >&2
  exit 2
fi

exit 0
```

```bash
chmod +x ~/.claude/hooks/block-destructive-sql.sh
```

**設定** — `settings.json` に追加：

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

これで `psql -c "SELECT * FROM users"` は通常通り実行されますが、`psql -c "DROP TABLE users"` は理由付きでブロックされ、Claude はそのフィードバックを見ることができます。

### 例2: Bash 経由での機密ファイル読み取りをブロック

**課題:** deny リストに `Read(**/.env)` を入れても、Bash の `cat .env` はすり抜けてしまいます。

**Hook スクリプト** — `~/.claude/hooks/block-sensitive-reads.sh` として保存：

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

**設定** — 同じ構造、同じ matcher：

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

### 複数の Hook を組み合わせる

同じイベントに複数の Hook スクリプトを登録できます。すべて実行され、どれか1つでも終了コード 2 を返せば呼び出しはブロックされます：

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

### なぜ deny ルールだけでは不十分か

Hook があっても、deny ルール単体の限界を理解しておくことは重要です。

### Read の deny ≠ Bash の deny

[公式ドキュメント](https://code.claude.com/docs/ja/permissions)より：

> `Read(./.env)` の deny ルールは Read ツールをブロックしますが、Bash での `cat .env` は**防げません**。

つまり deny リストに `Read(**/.env)` を入れても、Claude は `Bash(cat .env)` や `Bash(grep password .env)` など、Bash 経由でそのファイルを読むことができます。Read と Bash の deny は**互いをカバーしない、それぞれ別々のレイヤー**です。

### リスク：Bash パターンはバイパスされうる

Bash の deny ルールは glob パターンマッチングを使うため、本質的に限界があります：

- `Bash(sudo *)` は `sudo rm -rf /` をブロックしますが、内部で `sudo` を呼ぶスクリプトは通ります
- `Bash(curl *|*sh)` は `curl url | sh` をブロックしますが、`wget -O- url | bash` は通ります
- `Bash(rm -rf *)` は `rm -rf /tmp` をブロックしますが、Makefile 内の `rm -rf` は通ります

### 3つの防御レイヤー

堅牢な保護には3つのレイヤーを併用します：

| レイヤー | 役割 | 設定場所 |
|---------|------|---------|
| **Deny ルール** | 第一防衛線です。既知の危険なコマンドやツールを実行前にブロックします。 | `settings.json` |
| **サンドボックス** | OS レベルの強制です。Bash が生成する子プロセスも含め、ファイルシステムとネットワークアクセスを制限します。AI モデルがバイパスすることはできません。 | `settings.json` |
| **Hooks (PreToolUse)** | コマンド実行前に走るカスタムスクリプトです。glob パターンでは表現できない複雑なロジックを適用できます。 | `settings.json` |

Deny ルールは明白なケースを捕捉します。サンドボックスはコマンドがすり抜けても被害を防ぎます。Hooks は環境固有のカスタムロジックを追加できます。

Hooks の詳細は [hooks でワークフローを自動化する](https://code.claude.com/docs/ja/hooks-guide)を参照してください。

---

## 参考資料

### 公式ドキュメント

- [セキュリティ](https://code.claude.com/docs/ja/security)
- [Claude Code の設定](https://code.claude.com/docs/ja/settings)
- [権限を設定する](https://code.claude.com/docs/ja/permissions)
- [サンドボックス](https://code.claude.com/docs/ja/sandboxing)
- [hooks でワークフローを自動化する](https://code.claude.com/docs/ja/hooks-guide)

### コミュニティ

- [Claude Codeの設定でやるべきセキュリティ対策](https://qiita.com/dai_chi/items/f6d5e907b9fee791b658)

## 関連チートシート・参考文献

- [OWASP AI Agent Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/AI_Agent_Security_Cheat_Sheet.html) — AIエージェントシステムの主要リスクとベストプラクティス：ツール権限の最小化、プロンプトインジェクション対策、Human-in-the-Loop など。
- [OWASP LLM Prompt Injection Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Prompt_Injection_Prevention_Cheat_Sheet.html) — プロンプトインジェクション攻撃への防御に関する技術ガイダンス。
- [OWASP Top 10 for LLM Applications](https://genai.owasp.org/llm-top-10/) — LLM アプリケーションにおける脅威の全体像。
