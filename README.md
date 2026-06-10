# devcontainer-features

GitHub Container Registry に公開している、自前の [dev container Features](https://containers.dev/implementors/features/) のコレクションです。[Feature 配布仕様](https://containers.dev/implementors/features-distribution/)に準拠しています。

## Features 一覧

| Feature | 説明 |
|---|---|
| [`claude-code`](./src/claude-code/) | Claude Code の状態をコンテナ再ビルド越し・DevContainer 間で永続化します。認証情報・設定（`~/.claude` 配下）はホストと共有し、会話ログなどの実行時状態はプロジェクトの `.devcontainer/` 配下にリポジトリ単位で保持します。 |
| [`gh`](./src/gh/) | GitHub CLI の認証情報を永続化します。ホストの `~/.config/gh` を bind マウントし、`GH_CONFIG_DIR` で gh をそこへ向けるので、`gh auth login` はホストで一度行えば全 DevContainer で共有されます。 |
| [`confluence-cli`](./src/confluence-cli/) | [`kci-confluence-cli`](https://github.com/kurusugawa-computer/confluence-cli)（`confluence` コマンド）を PyPI から uv 経由で導入します。`base_url` / `user_name` / `user_password` オプションを `CONFLUENCE_BASE_URL` / `CONFLUENCE_USER_NAME` / `CONFLUENCE_USER_PASSWORD` 環境変数として展開します。 |

各 Feature の詳しい使い方は `src/<feature>/` 配下の README を参照してください。

## リポジトリ構成

```
├── src
│   └── <feature>
│       ├── devcontainer-feature.json
│       ├── install.sh
│       └── README.md
└── test
    └── <feature>
        ├── test.sh
        ├── scenarios.json
        └── <scenario>.sh
```

[対応ツール](https://containers.dev/supporting#tools) が各 Feature の `devcontainer-feature.json` を読み込み、コンテナビルド時に `install.sh` を実行します。

---

このリポジトリは [`devcontainers/feature-starter`](https://github.com/devcontainers/feature-starter) テンプレートから派生しています。
