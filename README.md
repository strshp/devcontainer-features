# devcontainer-features

GitHub Container Registry に公開している、自前の [dev container Features](https://containers.dev/implementors/features/) のコレクションです。[Feature 配布仕様](https://containers.dev/implementors/features-distribution/)に準拠しています。

## Features 一覧

| Feature | 説明 |
|---|---|
| [`claude-code-persist`](./src/claude-code-persist/) | Claude Code の状態（認証情報、設定、会話ログなど）をコンテナ再ビルド越しに永続化します。マシン共通の named volume、プロジェクトローカルの bind mount、ホストの `~/.claude/skills` への bind mount を組み合わせて実現しています。 |

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
