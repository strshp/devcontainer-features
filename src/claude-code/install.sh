#!/bin/sh
set -e

echo "Feature 'claude-code' を有効化しています"

# 配線はすべてランタイム（postCreateCommand）で、下記の初期化ヘルパーが行います。
# その時点なら SUDO_USER でコンテナユーザーを確実に判定でき、bind マウントも
# 存在しているためです。ビルド時にここで ~/.claude の symlink を作ることは
# あえてしません。ビルド時の _REMOTE_USER に依存することになり、ランタイムの
# ユーザー／ホームが異なる場合に壊れやすいからです。
cat > /usr/local/bin/claude-code-init <<'INITSH'
#!/bin/sh
set -e

TARGET_USER="${SUDO_USER:-$(id -un)}"
WORKSPACE_FOLDER="${1:-}"
TARGET_HOME="$(getent passwd "$TARGET_USER" 2>/dev/null | cut -d: -f6)"
[ -n "$TARGET_HOME" ] || TARGET_HOME="${HOME:-/root}"

# コンテナのホスト名を解決できるようにする。network_mode: host やカスタム
# ホスト名のとき、sudo などが「unable to resolve host」を出すのを防ぐ。
HN="$(hostname)"
if [ -n "$HN" ] && ! grep -qw "$HN" /etc/hosts 2>/dev/null; then
    printf '127.0.0.1\t%s\n' "$HN" >> /etc/hosts
fi

HOST_DIR=/var/claude-code-host                      # ホストの ~/.claude（設定＋認証情報）
HOST_CLAUDE_JSON=/var/claude-code-host-claude-json  # ホストの ~/.claude.json（単一ファイル）

# リポジトリ単位ストアは、既にマウント済みの workspace の中
# （.devcontainer/claude-store）に置く。あえて個別の bind マウントにはしない。
# source が存在しない bind は、多くの Docker デーモンでコンテナ起動に失敗し、
# `devcontainer up` も `features test` も事前作成してくれないため。workspace は
# 常にマウントされているので、その中にストアを作成する。
if [ -z "$WORKSPACE_FOLDER" ]; then
    echo "claude-code: workspace フォルダ引数がありません。リポジトリ単位ストアの場所を特定できません" >&2
    exit 1
fi
DEVC_DIR="$WORKSPACE_FOLDER/.devcontainer/claude-store"

# ホストの ~/.claude から共有する項目（認証情報＋持ち運び可能な設定）。
# ここに無いものはリポジトリ単位ストアに入るので、Claude Code が作る未知の／
# 新しいファイルも既定でリポジトリごとに永続化される。
HOST_SHARED=".credentials.json settings.json settings.local.json keybindings.json CLAUDE.md skills commands agents output-styles rules workflows themes plugins"

# --- 所有権 ------------------------------------------------------------------
# ホスト側のマウント（~/.claude, ~/.claude.json）は、ホストに存在している
# 必要がある。source が無い bind は、起動失敗（多くのデーモン）か root 所有での
# 自動作成（一部のデーモン）になる。後者のときだけユーザーへ chown する。
# ユーザーの実体のある ~/.claude を再帰的に触ることは決してしない。
if [ "$(stat -c '%u' "$HOST_DIR" 2>/dev/null)" = "0" ]; then
    chown "$TARGET_USER" "$HOST_DIR" 2>/dev/null || true
fi
if [ "$(stat -c '%u' "$HOST_CLAUDE_JSON" 2>/dev/null)" = "0" ]; then
    chown "$TARGET_USER" "$HOST_CLAUDE_JSON" 2>/dev/null || true
fi

# リポジトリ単位ストア: workspace の中に作成し、ランタイムユーザーが所有者になる
# ようにする（中身はそのユーザーが実行時に書き込む）。
mkdir -p "$DEVC_DIR"
chown "$TARGET_USER" "$DEVC_DIR" 2>/dev/null || true

# --- ~/.claude の配線 --------------------------------------------------------
# ~/.claude 自体をリポジトリ単位ストアにする。実行時／セッション／キャッシュの
# 各ファイル（未知の新規ファイルも含む）が既定でリポジトリごとに永続化される。
rm -rf "$TARGET_HOME/.claude"
ln -sfn "$DEVC_DIR" "$TARGET_HOME/.claude"

# ホスト共有項目を上書きし、ホストの ~/.claude を指すようにする。symlink は
# 無条件に作成し、Feature がホスト側に何かを作ることはない。ホストに項目が
# 無ければ、ホストがそれを持つまで symlink はリンク切れになる（設計上の許容。
# これらはユーザーグローバルな設定パスで、ホストの ~/.claude に現れた時点で
# 解決される）。
for item in $HOST_SHARED; do
    rm -rf "$DEVC_DIR/$item"
    ln -sfn "$HOST_DIR/$item" "$DEVC_DIR/$item"
    chown -h "$TARGET_USER" "$DEVC_DIR/$item" 2>/dev/null || true
done

# ~/.claude.json は ~/.claude の中ではなくホーム直下にあるので、ホストの同
# ファイルを個別に共有する。
rm -rf "$TARGET_HOME/.claude.json"
ln -sfn "$HOST_CLAUDE_JSON" "$TARGET_HOME/.claude.json"

chown -h "$TARGET_USER" "$TARGET_HOME/.claude" "$TARGET_HOME/.claude.json" 2>/dev/null || true

# --- .gitignore の整備 -------------------------------------------------------
# リポジトリ単位ストア: この .gitignore 自身も含め、配下すべてを git から隠す。
if [ ! -f "$DEVC_DIR/.gitignore" ]; then
    printf '*\n' > "$DEVC_DIR/.gitignore"
    chown "$TARGET_USER" "$DEVC_DIR/.gitignore" 2>/dev/null || true
fi
# .devcontainer/.gitignore: ストア・ロックファイル・.gitignore 自身を、冪等に
# git の対象外へ追加する。
if [ -n "$WORKSPACE_FOLDER" ] && [ -d "$WORKSPACE_FOLDER/.devcontainer" ]; then
    GI="$WORKSPACE_FOLDER/.devcontainer/.gitignore"
    if [ ! -f "$GI" ]; then
        printf 'claude-store/\ndevcontainer-lock.json\n.gitignore\n' > "$GI"
        chown "$TARGET_USER" "$GI" 2>/dev/null || true
    else
        for line in 'claude-store/' 'devcontainer-lock.json' '.gitignore'; do
            grep -qFx "$line" "$GI" || printf '%s\n' "$line" >> "$GI"
        done
    fi
fi
INITSH
chmod 755 /usr/local/bin/claude-code-init

echo "Claude Code の永続化を設定しました（設定・認証情報はホストの ~/.claude から、実行時状態はリポジトリ単位）"
