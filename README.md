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

## 配布

### Publish

[Release ワークフロー](.github/workflows/release.yaml) が `src/` 配下の全 Feature を GHCR の `strshp/devcontainer-features` 名前空間に公開します。公開後、`devcontainer.json` から次のように参照できます：

```
ghcr.io/strshp/devcontainer-features/<feature-id>:<version>
```

### Feature を public にする

GHCR のパッケージはデフォルトで private です。認証なしで利用可能にするには、GHCR のパッケージ設定ページから visibility を `public` に切り替えます：

```
https://github.com/users/strshp/packages/container/devcontainer-features%2F<feature-id>/settings
```

### Codespaces で private な Feature を使う

Feature を private のまま使いたい場合、GitHub Codespaces にリポジトリスコープのトークン権限を付与する必要があります。`devcontainer.json` に以下を追加してください：

```jsonc
{
    "customizations": {
        "codespaces": {
            "repositories": {
                "strshp/devcontainer-features": {
                    "permissions": {
                        "packages": "read",
                        "contents": "read"
                    }
                }
            }
        }
    }
}
```

---

このリポジトリは [`devcontainers/feature-starter`](https://github.com/devcontainers/feature-starter) テンプレートから派生しています。
