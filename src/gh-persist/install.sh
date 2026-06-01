#!/bin/sh
set -e

echo "Activating feature 'gh-persist'"

HOST_CONFIG_DIR=/var/gh-host-config

USER_NAME="${_REMOTE_USER:-root}"
USER_HOME="${_REMOTE_USER_HOME:-/root}"

# Remove any existing ~/.config/gh (real directory or stale symlink from image layer).
rm -rf "$USER_HOME/.config/gh"

# Ensure ~/.config exists.
mkdir -p "$USER_HOME/.config"

# ~/.config/gh -> host bind mount (materialized at runtime by postCreateCommand)
ln -sfn "$HOST_CONFIG_DIR" "$USER_HOME/.config/gh"

# Ownership: -h so the symlink itself is chowned (not the target).
chown -h "$USER_NAME:$USER_NAME" "$USER_HOME/.config/gh" 2>/dev/null || true

# A runtime init helper for postCreateCommand.
# Ensures the host directory exists with correct ownership.
# Docker creates the source directory as root if it does not exist yet —
# we only fix ownership in that case to avoid touching existing host files.
cat > /usr/local/bin/gh-persist-init <<'INITSH'
#!/bin/sh
set -e
TARGET_USER="${SUDO_USER:-$(id -un)}"

# Ensure the container hostname resolves. With network_mode: host (or a custom
# hostname) the container inherits a hostname that is not in /etc/hosts, which
# makes sudo and other tools emit "unable to resolve host" and can break later
# postCreateCommands. Running as root here, we add a loopback entry so every
# subsequent sudo call (including other features') resolves cleanly.
HN="$(hostname)"
if [ -n "$HN" ] && ! grep -qw "$HN" /etc/hosts 2>/dev/null; then
    printf '127.0.0.1\t%s\n' "$HN" >> /etc/hosts
fi

HOST_CONFIG_DIR=/var/gh-host-config

mkdir -p "$HOST_CONFIG_DIR"

# Only chown when Docker just created the directory as root (uid 0).
# If the directory already had content from the host, leave ownership as-is.
if [ "$(stat -c '%u' "$HOST_CONFIG_DIR")" = "0" ]; then
    chown "$TARGET_USER" "$HOST_CONFIG_DIR"
fi
INITSH
chmod 755 /usr/local/bin/gh-persist-init

echo "GitHub CLI credential persistence wired up for user '$USER_NAME' at '$USER_HOME'"
