#!/bin/sh
set -e

echo "Feature 'confluence-cli' を有効化しています"

# オプション値（devcontainer CLI が環境変数として渡す: オプション id を大文字化し、
# 英数字以外を '_' に置換した名前）。
BASE_URL="${BASE_URL:-}"
USER_NAME="${USER_NAME:-}"
USER_PASSWORD="${USER_PASSWORD:-}"

# uv のツールデータを、全ユーザーが読める共有の場所に置く。これにより（非 root の）
# リモートユーザーでもインストール済み CLI を実行できる。ランチャは PATH に置く。
UV_ROOT=/opt/uv
export UV_TOOL_DIR="$UV_ROOT/tools"
export UV_PYTHON_INSTALL_DIR="$UV_ROOT/python"
export UV_TOOL_BIN_DIR=/usr/local/bin

# --- uv を用意する -----------------------------------------------------------
if ! command -v uv >/dev/null 2>&1; then
    if ! command -v curl >/dev/null 2>&1 && command -v apt-get >/dev/null 2>&1; then
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -y
        apt-get install -y --no-install-recommends curl ca-certificates
    fi
    # uv（と uvx）を PATH 上のシステム共通の場所にインストールする。インストーラに
    # シェルプロファイルを編集させない。
    export UV_INSTALL_DIR=/usr/local/bin
    export INSTALLER_NO_MODIFY_PATH=1
    curl -LsSf https://astral.sh/uv/install.sh | sh
fi

UV="$(command -v uv || echo /usr/local/bin/uv)"

# --- PyPI から CLI をインストールする ----------------------------------------
# 公開パッケージ `kci-confluence-cli` が `confluence` コマンドを提供する。
mkdir -p "$UV_ROOT"
"$UV" tool install kci-confluence-cli
# ツール環境を root 以外の全ユーザーが読める／実行できるようにする。
chmod -R a+rX "$UV_ROOT" 2>/dev/null || true

# --- オプションから環境変数を設定する ----------------------------------------
# Feature の containerEnv はオプション値を展開できないため、export をプロファイル
# スクリプト（ログインシェルが読む）に書き出し、インタラクティブな bash/zsh の rc
# からも source する。注意: これらの値はビルド時にコンテナ／イメージへ焼き込まれる。
# パスワードの扱いに注意（README 参照）。
squote() {
    # POSIX 互換の単一引用符クォート（値に単一引用符が含まれても安全）。
    printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
}

ENV_FILE=/etc/profile.d/confluence-cli.sh
if [ -n "$BASE_URL" ] || [ -n "$USER_NAME" ] || [ -n "$USER_PASSWORD" ]; then
    {
        echo '#!/bin/sh'
        echo '# confluence-cli devcontainer feature が生成。'
        if [ -n "$BASE_URL" ];      then echo "export CONFLUENCE_BASE_URL=$(squote "$BASE_URL")"; fi
        if [ -n "$USER_NAME" ];     then echo "export CONFLUENCE_USER_NAME=$(squote "$USER_NAME")"; fi
        if [ -n "$USER_PASSWORD" ]; then echo "export CONFLUENCE_USER_PASSWORD=$(squote "$USER_PASSWORD")"; fi
    } > "$ENV_FILE"
    # 全ユーザー読み取り可（通常の /etc/profile.d ファイルと同じく root 所有）。
    # ランタイムのユーザーはビルド時に確実には分からず、推測した所有者に限定すると
    # 実際のログインユーザーが異なる場合にファイルを読めず（変数が未設定になる）。
    # 値は既にユーザーのプロセスから見える環境変数で、イメージにも焼き込まれるため、
    # 644 にしても露出は広がらない。
    chmod 644 "$ENV_FILE"

    # インタラクティブな（非ログインの）bash/zsh は /etc/profile.d を読まないので、
    # それぞれのグローバル rc からも冪等に source する。
    SRC_LINE='[ -f /etc/profile.d/confluence-cli.sh ] && . /etc/profile.d/confluence-cli.sh'
    for rc in /etc/bash.bashrc /etc/zsh/zshrc; do
        if [ -f "$rc" ] && ! grep -qF 'confluence-cli.sh' "$rc"; then
            printf '\n%s\n' "$SRC_LINE" >> "$rc"
        fi
    done
fi

echo "confluence-cli を準備しました: 'confluence' を PATH に配置、CONFLUENCE_* は $ENV_FILE 経由で設定"
