# GitHub CLI (gh)

[GitHub CLI](https://cli.github.com/)（`gh`）を導入し、その**認証情報を専用の永続ストアに保存して永続化**する Feature です。コンテナ内で `gh auth login` を一度行えば、以降は再ビルド越し・すべての DevContainer で認証済みの状態が共有されます。

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

コンテナ初回起動時に一度だけログインします。

```bash
gh auth login
```

以降はトークンが専用ストアに保存され、再ビルドしても・別の DevContainer でも再ログインは不要です。

## 仕組み

- Docker 名前付きボリューム `gh-devcontainers` をコンテナの `/var/gh-config` にマウントし、`containerEnv` で `GH_CONFIG_DIR=/var/gh-config` を設定します。これが永続ストアになります。ボリュームは自動作成されるので、ホスト側の事前準備は不要です。
- コンテナには keyring（資格情報ストア）が無いため、`gh auth login` のトークンは自動的に**ファイル**（`hosts.yml`）に保存され、ボリュームに残ります。
- ボリュームは root 所有で作成されるため、`postCreateCommand`（`gh-init`）が実行ユーザーへ chown します。
- `sudo` がコンテナのホスト名を解決できず警告を出す問題（`network_mode: host` で起きやすい）を避けるため、`libnss-myhostname` を導入します。

### 共有範囲（compose 利用時の注意）

`image` / `build` ベースの DevContainer では、ボリューム名 `gh-devcontainers` はそのまま使われるため**全 DevContainer で共有**されます（ログインは一度きり）。一方、`dockerComposeFile` ベースの DevContainer では、Docker Compose がボリューム名を**プロジェクト名でプレフィックス**する（`<project>_gh-devcontainers`）ため、**プロジェクト（リポジトリ）ごとに別ストア**になり、その単位で一度ずつログインが必要です。

### なぜホストの `~/.config/gh` を共有しないのか

`gh` は既定で**トークンを OS の keyring（資格情報ストア）に保存**します。この場合トークンは `~/.config/gh/hosts.yml` には書かれず keyring の中だけにあり、keyring はコンテナから見えません。そのためホストの `~/.config/gh` をマウントしても**トークンは渡らず**、コンテナの `gh` は未認証になってしまいます。これを避けるため、ホストの設定は共有せず、コンテナ内ログインを専用ストアに永続化する方式にしています。

> ホストの既存ログインをそのまま使いたい場合は、`gh auth token` で取り出したトークンを `GH_TOKEN` 環境変数で渡す方法もあります（`devcontainer.json` の `remoteEnv` や `initializeCommand` を併用）。この Feature の既定の挙動には含めていません。

## 前提・注意

- 認証情報は Docker ボリューム `gh-devcontainers` に**平文ファイル**で保存されます。
- ホストの本来の `gh`（`~/.config/gh`）とは独立です。コンテナ側のログインはホストには影響しません。
- 共有範囲は compose 利用時に狭まります（上記「共有範囲」を参照）。

## Windows ホスト

`${localEnv:HOME}` は Windows では未定義です。Windows ユーザーは WSL の利用を推奨します。

## Options

なし。

## 依存

- `ghcr.io/devcontainers/features/github-cli`（`dependsOn` で自動導入）
