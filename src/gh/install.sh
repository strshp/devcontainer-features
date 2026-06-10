#!/bin/sh
set -e

echo "Activating feature 'gh'"

HOST_CONFIG_DIR=/var/gh-host-config

# ---------------------------------------------------------------------------
# Hostname resolution (removes the "sudo: unable to resolve host" warning).
#
# With network_mode: host (or a custom hostname) the container inherits a
# hostname that is not present in /etc/hosts, so sudo and other tools emit
# "unable to resolve host <name>". Editing /etc/hosts at runtime is too late
# for the very first sudo call (the one that runs this feature's init helper).
# Installing nss-myhostname resolves the local hostname at the NSS layer, so
# resolution succeeds for the very first sudo call and for every tool, without
# touching /etc/hosts at all. Best-effort: skipped if apt is unavailable.
# ---------------------------------------------------------------------------
if ! ls /usr/lib/*/libnss_myhostname.so* >/dev/null 2>&1; then
    if command -v apt-get >/dev/null 2>&1; then
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -y \
            && apt-get install -y --no-install-recommends libnss-myhostname \
            || echo "gh: could not install libnss-myhostname; sudo may warn 'unable to resolve host' under network_mode: host"
    fi
fi
if [ -f /etc/nsswitch.conf ] && ! grep -q '^hosts:.*myhostname' /etc/nsswitch.conf; then
    sed -i 's/^\(hosts:.*\)$/\1 myhostname/' /etc/nsswitch.conf
fi

# ---------------------------------------------------------------------------
# Runtime init helper for postCreateCommand.
#
# gh reads its config from $GH_CONFIG_DIR (set to /var/gh-host-config via the
# feature's containerEnv), which is the host's ~/.config/gh bind mount — so no
# symlink into the user's home is needed. (The previous build-time symlink was
# fragile: it depended on the build-time user and was lost when the runtime
# home differed.) Here we only ensure the host directory exists and is writable
# by the runtime user.
#
# Docker creates the bind source as root if it does not exist yet; we chown it
# in that case only, to avoid touching pre-existing host files.
# ---------------------------------------------------------------------------
cat > /usr/local/bin/gh-init <<'INITSH'
#!/bin/sh
set -e
TARGET_USER="${SUDO_USER:-$(id -un)}"

HOST_CONFIG_DIR=/var/gh-host-config

mkdir -p "$HOST_CONFIG_DIR"

# Only chown when Docker just created the directory as root (uid 0).
# If the directory already had content from the host, leave ownership as-is.
if [ "$(stat -c '%u' "$HOST_CONFIG_DIR")" = "0" ]; then
    chown "$TARGET_USER" "$HOST_CONFIG_DIR"
fi
INITSH
chmod 755 /usr/local/bin/gh-init

echo "GitHub CLI credential persistence wired up (GH_CONFIG_DIR=$HOST_CONFIG_DIR)"
