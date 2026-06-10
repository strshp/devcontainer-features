
# Claude Code Persistence (claude-code)

Claude Code の状態をコンテナ再ビルド越しに永続化する Feature です。

状態を **2 つのバケツ**に決め打ちで振り分けます。

| バケツ | 中身 | 保存先 |
|---|---|---|
| **ホスト共有**（ID＋設定） | `.credentials.json`（OAuth トークン）, `~/.claude.json`, `settings.json`, `settings.local.json`, `CLAUDE.md`, `keybindings.json`, `skills/`, `commands/`, `agents/`, `output-styles/`, `rules/`, `workflows/`, `themes/`, `plugins/` | ホストの `~/.claude`（＋ `~/.claude.json`）を bind マウントしてミラー |
| **リポジトリ単位**（実行時状態すべて） | 会話・セッション（`projects/`, `history.jsonl`, `sessions/`, `session-env/`, `todos/`, `tasks/`, `plans/`, `file-history/`, `paste-cache/`, `shell-snapshots/`）とキャッシュ（`cache/`, `statsig/`, `ide/`, `logs/` …）、その他**上のリストに無いものすべて** | プロジェクト内の `./.devcontainer/claude-store/` |

## 仕組み

`~/.claude` 自体を **リポジトリ単位ストアへの symlink** にしています。そのため Claude Code が書く実行時ファイルは（将来増える未知のファイルも含めて）デフォルトでリポジトリ単位ストアに落ちます。その上で「ホスト共有」項目だけをホストの `~/.claude` へ symlink で上書きします。`~/.claude.json` は home 直下にあるため、ホストの同ファイルへ個別に symlink します。

- ホストでログイン済みなら、全コンテナでログイン済み（`.credentials.json` 共有）。
- 設定・skills・plugins などはホストと単一ソース。ホストで編集すればコンテナにも反映。
- 会話履歴・auto-memory・キャッシュはリポジトリごとに分離。`--resume` に必要なセッション系も保持。

配線はすべて `postCreateCommand`（ランタイム）で行い、コンテナユーザーは `SUDO_USER` から判定します（ビルド時 `_REMOTE_USER` には依存しません）。

## 利用例

```jsonc
{
    "image": "mcr.microsoft.com/devcontainers/base:debian",
    "features": {
        "ghcr.io/strshp/devcontainer-features/claude-code": {}
    }
}
```

`ghcr.io/anthropics/devcontainer-features/claude-code` は `dependsOn` で自動的に取り込まれます。

## git について

Feature が以下の `.gitignore` を自動生成します（リポジトリのルート `.gitignore` は触りません）。

- `.devcontainer/claude-store/.gitignore` — 中身は `*` の 1 行。`.gitignore` 自身も含め配下すべてを git から不可視にする。
- `.devcontainer/.gitignore` — `claude-store/`, `devcontainer-lock.json`, `.gitignore` 自身を冪等に追記。

> リポジトリの `.devcontainer/claude-store/` には、ホスト設定へ向く symlink が並びます（git からは不可視）。**トークン本体はホストの `~/.claude` に残り、リポジトリに入るのは symlink だけ**なので秘密は漏れません。

## 前提・注意

- **`sudo` がパスワードなしで使えること**（標準 devcontainer イメージは満たす）。
- **ホストに `~/.claude` と `~/.claude.json` が存在すること**（一度でもホストで Claude Code を起動していれば作られます）。これらは bind マウントの source なので、無いと Docker デーモンによってはコンテナ起動に失敗します（root 所有で自動作成するデーモンの場合のみ Feature が利用ユーザーへ chown して緩和）。
- `.credentials.json` をホスト共有しているため、トークン refresh がホストと競合し得ます（通常は問題になりません）。

> 補足: per-repo ストア（`.devcontainer/claude-store`）は**独立した bind マウントにはしていません**。workspace は常にマウントされるので、その中に `postCreateCommand` でストアを作成します。これにより「マウント元が存在しないと起動失敗」（`devcontainer up`/CLI で再現）を回避しています。

## Windows ホスト

`${localEnv:HOME}` は Windows では未定義です。Windows ユーザーは WSL の利用を推奨します。

## Options

なし（全項目を決め打ち）。
