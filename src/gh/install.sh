#!/bin/sh
set -e

echo "Feature 'gh' を有効化しています"

CONFIG_DIR=/var/gh-config

# ---------------------------------------------------------------------------
# ホスト名の解決（「sudo: unable to resolve host」警告を消す）。
#
# network_mode: host（やカスタムホスト名）では、/etc/hosts に無いホスト名を
# コンテナが引き継ぐため、sudo などが「unable to resolve host <name>」を出す。
# /etc/hosts をランタイムで編集するのは、最初の sudo 呼び出し（この Feature の
# 初期化ヘルパーを実行するもの）には間に合わない。nss-myhostname を入れると
# NSS 層でローカルホスト名が解決されるので、/etc/hosts を一切触らずに、最初の
# sudo 呼び出しからすべてのツールで解決が成功する。ベストエフォート（apt が
# 無ければスキップ）。
# ---------------------------------------------------------------------------
if ! ls /usr/lib/*/libnss_myhostname.so* >/dev/null 2>&1; then
    if command -v apt-get >/dev/null 2>&1; then
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -y \
            && apt-get install -y --no-install-recommends libnss-myhostname \
            || echo "gh: libnss-myhostname をインストールできませんでした。network_mode: host 下で sudo が 'unable to resolve host' と警告する場合があります"
    fi
fi
if [ -f /etc/nsswitch.conf ] && ! grep -q '^hosts:.*myhostname' /etc/nsswitch.conf; then
    sed -i 's/^\(hosts:.*\)$/\1 myhostname/' /etc/nsswitch.conf
fi

# ---------------------------------------------------------------------------
# postCreateCommand 用のランタイム初期化ヘルパー。
#
# gh は設定を $GH_CONFIG_DIR（Feature の containerEnv で /var/gh-config に設定）
# から読む。これは専用の永続ストア（ホストの ~/.config/gh-devcontainers の bind
# マウント）。ホストの ~/.config/gh はマウントしない: ホストが keyring に
# トークンを保存しているとマウントしてもトークンが渡らないため。コンテナには
# keyring が無いので、このストアで `gh auth login` するとトークンはファイルに
# 保存され（hosts.yml）、全 DevContainer で共有・再ビルド越しに永続する。
# ここではストアが存在し、ランタイムユーザーが書き込めることだけを保証する。
#
# Docker はマウント元が無いと root 所有で作成する。その場合のみ chown する。
# ---------------------------------------------------------------------------
cat > /usr/local/bin/gh-init <<'INITSH'
#!/bin/sh
set -e
TARGET_USER="${SUDO_USER:-$(id -un)}"

CONFIG_DIR=/var/gh-config

mkdir -p "$CONFIG_DIR"

# Docker が root（uid 0）で作成した直後のときだけ chown する。
if [ "$(stat -c '%u' "$CONFIG_DIR")" = "0" ]; then
    chown "$TARGET_USER" "$CONFIG_DIR"
fi
INITSH
chmod 755 /usr/local/bin/gh-init

echo "GitHub CLI を準備しました（GH_CONFIG_DIR=$CONFIG_DIR。コンテナ内で一度 'gh auth login' を実行してください）"
