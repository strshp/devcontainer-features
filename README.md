# devcontainer-features

[![CI - Test Features](https://github.com/strshp/devcontainer-features/actions/workflows/test.yaml/badge.svg)](https://github.com/strshp/devcontainer-features/actions/workflows/test.yaml)
[![Release](https://github.com/strshp/devcontainer-features/actions/workflows/release.yaml/badge.svg)](https://github.com/strshp/devcontainer-features/actions/workflows/release.yaml)

[Dev Container Features](https://containers.dev/implementors/features/) を開発・公開しているリポジトリです。各 Feature は GitHub Container Registry (ghcr.io) で配布しており、利用者ごとの VS Code ユーザー設定（`dev.containers.defaultFeatures`）に登録することで、自分が開くすべての DevContainer に自動で適用されます。

## Features 一覧

| Feature | 概要 |
|---|---|
| [`claude-code`](./src/claude-code/) | Claude Code の状態をコンテナ再ビルド越し・DevContainer 間で永続化します。認証情報・設定（`~/.claude` 配下）はホストと共有し、会話ログなどの実行時状態はプロジェクトの `.devcontainer/` 配下にリポジトリ単位で保持します。 |
| [`gh`](./src/gh/) | GitHub CLI を導入し、認証情報を永続化します。コンテナ内で `gh auth login` を一度行えば、再ビルド越し・全 DevContainer で共有されます（初回のみホストで `mkdir -p ~/.config/gh-devcontainers`）。 |
| [`confluence-cli`](./src/confluence-cli/) | [`kci-confluence-cli`](https://github.com/kurusugawa-computer/confluence-cli)（`confluence` コマンド）を PyPI から uv で導入します。接続情報を `CONFLUENCE_BASE_URL` / `CONFLUENCE_USER_NAME` / `CONFLUENCE_USER_PASSWORD` 環境変数として展開できます。 |

各 Feature の詳しい挙動・オプション・注意点は、それぞれの `src/<feature>/README.md` を参照してください。

## 使い方

プロジェクトの `devcontainer.json` ではなく、**利用者ごとの VS Code ユーザー設定**の `dev.containers.defaultFeatures` に登録します。こうすると、リポジトリ側に何も書かなくても、自分が開くすべての DevContainer に Feature が自動で適用されます。

VS Code の設定ファイル（`settings.json`）に次を追記します（Linux では `~/.config/Code/User/settings.json`）。

```jsonc
{
    "dev.containers.defaultFeatures": {
        "ghcr.io/strshp/devcontainer-features/claude-code": {},
        "ghcr.io/strshp/devcontainer-features/gh": {},
        "ghcr.io/strshp/devcontainer-features/confluence-cli": {
            "base_url": "https://confluence.example.com",
            "user_name": "alice",
            "user_password": "your_password"
        }
    }
}
```

> 設定 UI から開く場合は「Dev > Containers: Default Features」を検索し、`settings.json` で編集します。

バージョンはタグで固定できます。メジャータグ（例: `claude-code:2`）を指定すると、その系列内の最新を追従します。完全に固定したい場合は `claude-code:2.4.1` のようにフルバージョンを指定してください。

## リポジトリ構成

```
├── src
│   └── <feature>
│       ├── devcontainer-feature.json   # Feature の定義（id・version・options・mounts など）
│       ├── install.sh                  # コンテナビルド時に実行されるインストールスクリプト
│       └── README.md                   # 各 Feature のドキュメント
└── test
    └── <feature>
        ├── test.sh                     # デフォルトシナリオのテスト
        ├── scenarios.json              # 追加シナリオの定義
        └── <scenario>.sh               # 各シナリオのテスト
```

[対応ツール](https://containers.dev/supporting#tools) が各 Feature の `devcontainer-feature.json` を読み込み、コンテナビルド時に `install.sh` を実行します。`src/<feature>` のディレクトリ名がそのまま Feature の `id`（ghcr 上のパス）になります。

---

このリポジトリは [`devcontainers/feature-starter`](https://github.com/devcontainers/feature-starter) テンプレートから派生しています。
