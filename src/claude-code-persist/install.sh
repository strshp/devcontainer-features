#!/bin/sh
set -e

echo "Activating feature 'claude-code-persist'"

GLOBAL_DIR=/var/claude-code-global
PROJECTS_DIR=/var/claude-code-projects
HOST_SKILLS_DIR=/var/claude-code-host-skills
HOST_SETTINGS_FILE=/var/claude-code-host-settings.json
HOST_SETTINGS_LOCAL_FILE=/var/claude-code-host-settings.local.json

USER_NAME="${_REMOTE_USER:-root}"
USER_HOME="${_REMOTE_USER_HOME:-/root}"

# If a previous install (or the claude-code feature) left a real ~/.claude
# or ~/.claude.json in the image layer, remove it so the symlinks win.
rm -rf "$USER_HOME/.claude" "$USER_HOME/.claude.json"

# ~/.claude  -> host bind mount (materialized at runtime by postCreateCommand)
ln -sfn "$GLOBAL_DIR" "$USER_HOME/.claude"
# ~/.claude.json -> file inside the host bind mount
ln -sfn "$GLOBAL_DIR/.claude.json" "$USER_HOME/.claude.json"

# Ownership: -h so the symlinks themselves are chowned (not their targets).
chown -h "$USER_NAME:$USER_NAME" "$USER_HOME/.claude" "$USER_HOME/.claude.json" 2>/dev/null || true

# A runtime init helper for postCreateCommand.
# - Materializes the global dir structure on the host bind mount (which may be
#   empty or newly created as root by Docker on first use).
# - Materializes the per-project bind-mount subdirs.
# - Fixes ownership on every bind-mounted path.
cat > /usr/local/bin/claude-code-persist-init <<'INITSH'
#!/bin/sh
set -e
TARGET_USER="${SUDO_USER:-$(id -un)}"
WORKSPACE_FOLDER="${1:-}"

# Ensure the container hostname resolves. With network_mode: host (or a custom
# hostname) the container inherits a hostname that is not in /etc/hosts, which
# makes sudo and other tools emit "unable to resolve host" and can break later
# postCreateCommands. Running as root here, we add a loopback entry so every
# subsequent sudo call (including other features') resolves cleanly.
HN="$(hostname)"
if [ -n "$HN" ] && ! grep -qw "$HN" /etc/hosts 2>/dev/null; then
    printf '127.0.0.1\t%s\n' "$HN" >> /etc/hosts
fi

GLOBAL_DIR=/var/claude-code-global
PROJECTS_DIR=/var/claude-code-projects
HOST_SKILLS_DIR=/var/claude-code-host-skills
HOST_SETTINGS_FILE=/var/claude-code-host-settings.json
HOST_SETTINGS_LOCAL_FILE=/var/claude-code-host-settings.local.json
PROJECT_SCOPED="projects todos shell-snapshots sessions session-env tasks plans file-history paste-cache"

# --- Global dir (host bind mount) ---
# Docker creates the source directory as root when it doesn't exist yet.
# Ensure it exists and contains the expected structure.
mkdir -p "$GLOBAL_DIR"
touch "$GLOBAL_DIR/.claude.json" 2>/dev/null || true

# Project-scoped entries: point into the per-project bind mount.
for name in $PROJECT_SCOPED; do
    rm -rf "$GLOBAL_DIR/$name"
    ln -sfn "$PROJECTS_DIR/$name" "$GLOBAL_DIR/$name"
done
rm -f "$GLOBAL_DIR/history.jsonl"
ln -sfn "$PROJECTS_DIR/history.jsonl" "$GLOBAL_DIR/history.jsonl"

# Host's ~/.claude/skills shared into the container.
rm -rf "$GLOBAL_DIR/skills"
ln -sfn "$HOST_SKILLS_DIR" "$GLOBAL_DIR/skills"

# Host's ~/.claude/settings.json and settings.local.json shared into the container.
rm -f "$GLOBAL_DIR/settings.json" "$GLOBAL_DIR/settings.local.json"
ln -sfn "$HOST_SETTINGS_FILE"       "$GLOBAL_DIR/settings.json"
ln -sfn "$HOST_SETTINGS_LOCAL_FILE" "$GLOBAL_DIR/settings.local.json"

# Fix ownership of the global dir (may have been created as root by Docker).
# Use -h so symlinks themselves are chowned, not their targets.
chown -hR "$TARGET_USER" "$GLOBAL_DIR" 2>/dev/null || true

# --- Per-project bind mount ---
for s in $PROJECT_SCOPED; do
    mkdir -p "$PROJECTS_DIR/$s"
done
touch "$PROJECTS_DIR/history.jsonl"

# Keep claude-projects out of git without polluting the repo's root .gitignore.
# Just "*" excludes everything in this directory, including the .gitignore
# itself — it stays invisible to git status entirely.
if [ ! -f "$PROJECTS_DIR/.gitignore" ]; then
    printf '*\n' > "$PROJECTS_DIR/.gitignore"
fi

# Ensure devcontainer-lock.json and .gitignore itself are in .devcontainer/.gitignore.
# Including ".gitignore" means this file is also hidden from git status, so the
# feature's bookkeeping is invisible to the user's repo.
if [ -n "$WORKSPACE_FOLDER" ] && [ -d "$WORKSPACE_FOLDER/.devcontainer" ]; then
    DEVCONTAINER_GITIGN="$WORKSPACE_FOLDER/.devcontainer/.gitignore"
    if [ ! -f "$DEVCONTAINER_GITIGN" ]; then
        printf 'devcontainer-lock.json\n.gitignore\n' > "$DEVCONTAINER_GITIGN"
        chown "$TARGET_USER" "$DEVCONTAINER_GITIGN" 2>/dev/null || true
    else
        for line in 'devcontainer-lock.json' '.gitignore'; do
            grep -qFx "$line" "$DEVCONTAINER_GITIGN" || printf '%s\n' "$line" >> "$DEVCONTAINER_GITIGN"
        done
    fi
fi

chown -R "$TARGET_USER" "$PROJECTS_DIR"                                  2>/dev/null || true
chown -R "$TARGET_USER" /var/claude-code-host-skills                     2>/dev/null || true
chown    "$TARGET_USER" /var/claude-code-host-settings.json              2>/dev/null || true
chown    "$TARGET_USER" /var/claude-code-host-settings.local.json        2>/dev/null || true
INITSH
chmod 755 /usr/local/bin/claude-code-persist-init

echo "Claude Code persistence wired up for user '$USER_NAME' at '$USER_HOME'"
