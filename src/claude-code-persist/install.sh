#!/bin/sh
set -e

echo "Activating feature 'claude-code-persist'"

# All wiring happens at runtime (postCreateCommand) by the init helper below,
# where SUDO_USER reliably identifies the container user and the bind mounts
# exist. We deliberately do NOT create the ~/.claude symlinks here at build
# time: that would depend on the build-time _REMOTE_USER, which is fragile when
# the runtime user/home differs.
cat > /usr/local/bin/claude-code-persist-init <<'INITSH'
#!/bin/sh
set -e

TARGET_USER="${SUDO_USER:-$(id -un)}"
WORKSPACE_FOLDER="${1:-}"
TARGET_HOME="$(getent passwd "$TARGET_USER" 2>/dev/null | cut -d: -f6)"
[ -n "$TARGET_HOME" ] || TARGET_HOME="${HOME:-/root}"

# Ensure the container hostname resolves so sudo and other tools don't emit
# "unable to resolve host" under network_mode: host or a custom hostname.
HN="$(hostname)"
if [ -n "$HN" ] && ! grep -qw "$HN" /etc/hosts 2>/dev/null; then
    printf '127.0.0.1\t%s\n' "$HN" >> /etc/hosts
fi

HOST_DIR=/var/claude-code-host                      # host's ~/.claude (config + credentials)
HOST_CLAUDE_JSON=/var/claude-code-host-claude-json  # host's ~/.claude.json (single file)

# Per-repo store lives INSIDE the already-mounted workspace, at
# .devcontainer/claude-store. We deliberately do NOT bind-mount it separately: a
# bind whose source does not exist yet fails to launch the container on many
# Docker daemons, and neither `devcontainer up` nor `features test` pre-creates
# it. The workspace is always mounted, so we just create the store inside it.
if [ -z "$WORKSPACE_FOLDER" ]; then
    echo "claude-code-persist: no workspace folder argument; cannot locate the per-repo store" >&2
    exit 1
fi
DEVC_DIR="$WORKSPACE_FOLDER/.devcontainer/claude-store"

# Items shared from the host's ~/.claude: identity + portable config.
# Everything NOT listed here lives in the per-repo store, so unknown/new files
# Claude Code creates also persist per repository by default.
#
# Split by kind because the missing-on-host case is handled differently:
#  - DIRS: created empty on the host when absent, then symlinked. This keeps the
#    link valid (no dangling) AND makes them genuinely shared — anything created
#    in a container lands in the host's ~/.claude and shows up everywhere.
#  - FILES: only linked when the host already has them. Creating an empty file
#    would be harmful (invalid JSON for settings/keybindings, a bogus empty
#    .credentials.json), so a missing file falls back to the per-repo store.
HOST_SHARED_DIRS="skills commands agents output-styles rules workflows themes plugins"
HOST_SHARED_FILES=".credentials.json settings.json settings.local.json keybindings.json CLAUDE.md"

# --- ownership ---------------------------------------------------------------
# The host mounts (~/.claude, ~/.claude.json) must already exist on the host: a
# bind whose source is missing either fails to launch (most daemons) or is
# created as root (some daemons). For the latter case only, chown to the user;
# never recursively touch the user's real, populated ~/.claude.
if [ "$(stat -c '%u' "$HOST_DIR" 2>/dev/null)" = "0" ]; then
    chown "$TARGET_USER" "$HOST_DIR" 2>/dev/null || true
fi
if [ "$(stat -c '%u' "$HOST_CLAUDE_JSON" 2>/dev/null)" = "0" ]; then
    chown "$TARGET_USER" "$HOST_CLAUDE_JSON" 2>/dev/null || true
fi

# Per-repo store: create it inside the workspace and make sure the runtime user
# owns the directory (its contents are written by that user at run time).
mkdir -p "$DEVC_DIR"
chown "$TARGET_USER" "$DEVC_DIR" 2>/dev/null || true

# --- wire up ~/.claude -------------------------------------------------------
# ~/.claude IS the per-repo store: every runtime/session/cache file (and any
# unknown new file) persists per repository by default.
rm -rf "$TARGET_HOME/.claude"
ln -sfn "$DEVC_DIR" "$TARGET_HOME/.claude"

# Override the host-shared items: point them at the host's ~/.claude.
#
# Shared DIRS: ensure the host dir exists (create empty + chown when absent) so
# the symlink is never dangling and the dir is truly shared with the host. We
# only chown a dir we just created — never recurse into the user's real,
# populated ~/.claude on the host.
for item in $HOST_SHARED_DIRS; do
    if [ ! -e "$HOST_DIR/$item" ]; then
        mkdir -p "$HOST_DIR/$item"
        chown "$TARGET_USER" "$HOST_DIR/$item" 2>/dev/null || true
    fi
    rm -rf "$DEVC_DIR/$item"
    ln -sfn "$HOST_DIR/$item" "$DEVC_DIR/$item"
    chown -h "$TARGET_USER" "$DEVC_DIR/$item" 2>/dev/null || true
done

# Shared FILES: link only when the host already has the file; otherwise leave
# the per-repo store entry in place so the path stays valid (no dangling link,
# no bogus empty file). A stale link from a previous build (host had it, then
# removed it) is cleaned up so it falls back to the store; a real per-repo entry
# with data is preserved.
for item in $HOST_SHARED_FILES; do
    if [ -e "$HOST_DIR/$item" ]; then
        rm -rf "$DEVC_DIR/$item"
        ln -sfn "$HOST_DIR/$item" "$DEVC_DIR/$item"
        chown -h "$TARGET_USER" "$DEVC_DIR/$item" 2>/dev/null || true
    elif [ -L "$DEVC_DIR/$item" ]; then
        rm -f "$DEVC_DIR/$item"
    fi
done

# ~/.claude.json lives at the home root (not inside ~/.claude) -> share from host.
rm -rf "$TARGET_HOME/.claude.json"
ln -sfn "$HOST_CLAUDE_JSON" "$TARGET_HOME/.claude.json"

chown -h "$TARGET_USER" "$TARGET_HOME/.claude" "$TARGET_HOME/.claude.json" 2>/dev/null || true

# --- gitignore bookkeeping ---------------------------------------------------
# Per-repo store: hide everything (including this .gitignore) from git.
if [ ! -f "$DEVC_DIR/.gitignore" ]; then
    printf '*\n' > "$DEVC_DIR/.gitignore"
    chown "$TARGET_USER" "$DEVC_DIR/.gitignore" 2>/dev/null || true
fi
# .devcontainer/.gitignore: keep the store, the lock file, and .gitignore
# itself out of git, idempotently.
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
chmod 755 /usr/local/bin/claude-code-persist-init

echo "Claude Code persistence wired up (config + credentials from host ~/.claude; runtime state per-repo)"
