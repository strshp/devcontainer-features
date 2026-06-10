# Confluence CLI (confluence-cli)

[`kci-confluence-cli`](https://github.com/kurusugawa-computer/confluence-cli) を PyPI から [uv](https://github.com/astral-sh/uv) で導入し、コンテナ内で **`confluence` コマンド**を使えるようにする Feature です。あわせて、接続情報を `CONFLUENCE_*` 環境変数として展開できます。

## 利用例

```jsonc
{
    "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
    "features": {
        "ghcr.io/strshp/devcontainer-features/confluence-cli": {
            "base_url": "https://confluence.example.com",
            "user_name": "alice",
            "user_password": "your_password"
        }
    }
}
```

コンテナ起動後は `confluence` コマンドがそのまま使えます。

```bash
confluence --help
```

## Options

| Option          | 型     | 既定値 | 説明                                                            |
| --------------- | ------ | ------ | --------------------------------------------------------------- |
| `base_url`      | string | `""`   | `CONFLUENCE_BASE_URL` 環境変数として展開されます。              |
| `user_name`     | string | `""`   | `CONFLUENCE_USER_NAME` 環境変数として展開されます。            |
| `user_password` | string | `""`   | `CONFLUENCE_USER_PASSWORD` 環境変数として展開されます。        |

空のまま（既定値）のオプションは export されません。その場合 `confluence` は、環境に既にある `CONFLUENCE_*` 変数（ホストから引き継いだものなど）をそのまま利用します。

## 仕組み

- `uv tool install kci-confluence-cli` で、全ユーザーが読み書きできる共有領域（`/opt/uv`）にインストールし、`confluence` ランチャを `/usr/local/bin` に配置します。これにより root / 非 root のどちらのユーザーでも実行できます。
- 指定されたオプションは `/etc/profile.d/confluence-cli.sh` に `export` 文として書き出します。ログインシェルに加えて、インタラクティブな非ログインシェルでも読み込まれるよう `/etc/bash.bashrc` と `/etc/zsh/zshrc` からも source します。
- `confluence` が参照する環境変数名は `kci-confluence-cli` の仕様に準拠しています（[README](https://github.com/kurusugawa-computer/confluence-cli) 参照）。

## セキュリティ上の注意

DevContainer の Feature オプションはビルド時に解決されるため、`user_password` の値は**コンテナイメージに焼き込まれます**（純粋なランタイム注入はできません）。次の点に注意してください。

- 実際の認証情報を、共有される `devcontainer.json` にコミットしない。
- ビルドしたイメージを、他者が pull できるレジストリに push しない。
- 生成される `/etc/profile.d/confluence-cli.sh` は、他の profile スクリプトと同様にコンテナ内で誰でも読める（mode `644`）状態です。

認証情報をイメージに焼き込みたくない場合は、これらのオプションを空にして、ホストや DevContainer 側の `remoteEnv` / シークレット機構で `CONFLUENCE_*` を渡す運用も可能です。

## uv について

`uv` がコンテナに無い場合は、`install.sh` が公式インストーラで自動的に導入します（`/usr/local/bin`）。uv を提供する他の Feature を併用している場合は、それを再利用します。
