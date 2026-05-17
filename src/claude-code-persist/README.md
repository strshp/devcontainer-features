
# Claude Code Persistence (claude-code-persist)

Claude Code の状態をコンテナ再ビルド越しに永続化する Feature です。

状態を 3 つのマウントに分けて保存します：

| 保存先 | 中身 | マウント種別 |
|---|---|---|
| Docker named volume `claude-code-global` | `~/.claude.json`、認証情報、設定、プラグイン、キャッシュなど — プロジェクト固有リストに**含まれない**もの全て | volume（同じマシン上の全プロジェクトで共有） |
| プロジェクト内の `./.devcontainer/claude-projects/` | 会話・セッションデータ: `projects/`, `todos/`, `shell-snapshots/`, `sessions/`, `session-env/`, `tasks/`, `plans/`, `file-history/`, `paste-cache/`, `history.jsonl` | bind |
| ホストの `~/.claude/skills/` | カスタム skills | bind |
| ホストの `~/.claude/settings.json` | ユーザー設定 | bind（単一ファイル） |
| ホストの `~/.claude/settings.local.json` | ユーザー設定（ローカル上書き） | bind（単一ファイル） |

プロジェクト固有リストに含まれないものは全て共有 volume に入る（ホワイトリスト方式）ため、将来 Claude Code のアップデートで新しいファイルが追加されても、デフォルトで安全側（マシン共通側）に振り分けられます。

## 利用例

```jsonc
{
    "image": "mcr.microsoft.com/devcontainers/base:debian",
    "features": {
        "ghcr.io/anthropics/devcontainer-features/claude-code:1.0": {},
        "ghcr.io/strshp/devcontainer-features/claude-code-persist:1": {}
    }
}
```

feature を有効化するだけで、必要な初期化は `postCreateCommand` 内で自動実行されます（bind mount 配下のサブディレクトリ作成、所有権の補正）。

## 推奨設定（必須ではありません）

`.devcontainer/claude-projects/` を `.gitignore` に追加してください。会話ログにはコードスニペット、ファイルパス、任意のプロンプト入力が含まれるため、ほぼ確実にコミットしたくない内容です。

## 前提

- **`sudo` が利用可能であること**（コンテナ remoteUser がパスワードなしで sudo できる前提）。`mcr.microsoft.com/devcontainers/base:*` などの標準 devcontainer イメージはこの条件を満たします。

## Windows ホスト

`skills` / `settings.json` / `settings.local.json` のマウントは `${localEnv:HOME}` を参照していますが、これは Windows では定義されていません。Windows ユーザーは WSL の利用を推奨します。

## Options

なし。
