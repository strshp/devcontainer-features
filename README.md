# devcontainer-features

[![CI - Test Features](https://github.com/strshp/devcontainer-features/actions/workflows/test.yaml/badge.svg)](https://github.com/strshp/devcontainer-features/actions/workflows/test.yaml)
[![Release](https://github.com/strshp/devcontainer-features/actions/workflows/release.yaml/badge.svg)](https://github.com/strshp/devcontainer-features/actions/workflows/release.yaml)

[Dev Container Features](https://containers.dev/implementors/features/) を開発・公開しているリポジトリです。各 Feature は GitHub Container Registry (ghcr.io) で配布しており、`devcontainer.json` の `features` に追記するだけで利用できます。

## Features 一覧

| Feature | 概要 |
|---|---|
| [`claude-code`](./src/claude-code/) | Claude Code の状態をコンテナ再ビルド越し・DevContainer 間で永続化します。認証情報・設定（`~/.claude` 配下）はホストと共有し、会話ログなどの実行時状態はプロジェクトの `.devcontainer/` 配下にリポジトリ単位で保持します。 |
| [`gh`](./src/gh/) | GitHub CLI を導入し、認証情報を専用の永続ストアに保存します。コンテナ内で `gh auth login` を一度行えば、再ビルド越し・全 DevContainer で共有されます。 |
| [`confluence-cli`](./src/confluence-cli/) | [`kci-confluence-cli`](https://github.com/kurusugawa-computer/confluence-cli)（`confluence` コマンド）を PyPI から uv で導入します。接続情報を `CONFLUENCE_BASE_URL` / `CONFLUENCE_USER_NAME` / `CONFLUENCE_USER_PASSWORD` 環境変数として展開できます。 |

各 Feature の詳しい挙動・オプション・注意点は、それぞれの `src/<feature>/README.md` を参照してください。

## 使い方

`devcontainer.json` の `features` に、ghcr 上の Feature を参照する 1 行を追加します。

```jsonc
{
    "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
    "features": {
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
