
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

    // 必須: bind mount のソースをホスト側にあらかじめ作成する。
    // 作らないと Docker が root 所有の空ディレクトリを生成してしまう。
    "initializeCommand": "mkdir -p ${localWorkspaceFolder}/.devcontainer/claude-projects ${localEnv:HOME}/.claude/skills && touch ${localEnv:HOME}/.claude/settings.json ${localEnv:HOME}/.claude/settings.local.json",

    "features": {
        "ghcr.io/anthropics/devcontainer-features/claude-code:1.0": {},
        "ghcr.io/strshp/devcontainer-features/claude-code-persist:1": {}
    }
}
```

## 必要なセットアップ

1. **上記の `initializeCommand` を `devcontainer.json` に追加してください**。
   これを設定しないと、初回起動時に Docker が bind mount のソースディレクトリを
   `root` 所有で作成してしまい、コンテナユーザーから書き込めなくなります。
2. **`.devcontainer/claude-projects/` を `.gitignore` に追加してください**。
   会話ログにはコードスニペット、ファイルパス、任意のプロンプト入力が含まれるため、
   ほぼ確実にコミットしたくない内容です。

## Windows ホスト

`initializeCommand` および `skills` / `settings.json` / `settings.local.json` のマウントは
`${localEnv:HOME}` を参照していますが、これは Windows では定義されていません。
Windows ユーザーは `HOME` を `USERPROFILE` に置き換えるか、WSL を利用してください。

## Options

なし。
