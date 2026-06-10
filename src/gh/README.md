# GitHub CLI (gh)

[GitHub CLI](https://cli.github.com/)（`gh`）を導入し、その**認証情報をホストと共有して永続化**する Feature です。`gh auth login` をホストで一度だけ行えば、すべての DevContainer で認証済みの状態になり、コンテナを再ビルドしても再ログインは不要です。

`gh` 本体は公式の [`github-cli`](https://github.com/devcontainers/features/tree/main/src/github-cli) Feature を `dependsOn` で自動的に取り込んでインストールします。

## 利用例

```jsonc
{
    "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
    "features": {
        "ghcr.io/strshp/devcontainer-features/gh": {}
    }
}
```

オプションはありません。コンテナ起動後はそのまま `gh` が使えます。

```bash
gh auth status
gh pr list
```

## 仕組み

- ホストの `~/.config/gh` をコンテナの `/var/gh-host-config` に bind マウントします。
- `containerEnv` で `GH_CONFIG_DIR=/var/gh-host-config` を設定し、`gh` の設定ディレクトリをそのマウント先へ向けます。ホームディレクトリへの symlink は作らないため、ビルド時／実行時のユーザーの違いに影響されません。
- これにより、ホストとコンテナ（および全 DevContainer）が**同一の設定・認証情報**を共有します。ホストで `gh auth login` すればコンテナにも反映され、その逆も同様です。
- マウント先がまだ存在せず Docker が root 所有で作成した場合のみ、`postCreateCommand`（`gh-init`）が実行ユーザーへ chown します。既存のホスト設定の所有権は変更しません。
- `sudo` がコンテナのホスト名を解決できず警告を出す問題（`network_mode: host` で起きやすい）を避けるため、`libnss-myhostname` を導入します。

## 前提・注意

- **ホストに `~/.config/gh` が存在すること。** ホストで一度でも `gh` を使っていれば作られます。これは bind マウントの source なので、無い場合は Docker デーモンによってはコンテナ起動に失敗します。
- ホストとコンテナで**同じ設定ファイルを共有**します。コンテナ内で `gh auth logout` などを行うとホスト側にも影響します。
- `gh` の拡張機能（`gh extension`）も共有されますが、アーキテクチャ依存のバイナリを含む拡張は、ホスト（例: macOS）とコンテナ（Linux）で食い違う場合があります。その場合はコンテナ内で再インストールしてください。

## Windows ホスト

`${localEnv:HOME}` は Windows では未定義です。Windows ユーザーは WSL の利用を推奨します。

## Options

なし。

## 依存

- `ghcr.io/devcontainers/features/github-cli`（`dependsOn` で自動導入）
