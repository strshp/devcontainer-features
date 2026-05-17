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

# Entries that live on the per-project bind mount (whitelist).
# Anything NOT listed here stays on the shared global volume.
PROJECT_SCOPED="projects todos shell-snapshots sessions session-env tasks plans file-history paste-cache history.jsonl"

mkdir -p "$GLOBAL_DIR"
# .claude.json is a single file at the user's home; back it with the global volume.
touch "$GLOBAL_DIR/.claude.json"

# If a previous install (or the claude-code feature) left a real ~/.claude
# or ~/.claude.json in the image layer, remove it so the symlinks win.
rm -rf "$USER_HOME/.claude" "$USER_HOME/.claude.json"

# ~/.claude  -> shared global volume
ln -sfn "$GLOBAL_DIR" "$USER_HOME/.claude"
# ~/.claude.json -> file inside the global volume
ln -sfn "$GLOBAL_DIR/.claude.json" "$USER_HOME/.claude.json"

# Project-scoped entries: symlink each one into the bind-mount path.
# The target subdirs are materialized at runtime by postCreateCommand,
# since anything we put under $PROJECTS_DIR here is hidden by the bind mount.
for name in $PROJECT_SCOPED; do
    rm -rf "$GLOBAL_DIR/$name"
    ln -sfn "$PROJECTS_DIR/$name" "$GLOBAL_DIR/$name"
done

# Host's ~/.claude/skills shared into the container.
rm -rf "$GLOBAL_DIR/skills"
ln -sfn "$HOST_SKILLS_DIR" "$GLOBAL_DIR/skills"

# Host's ~/.claude/settings.json and settings.local.json shared into the container.
rm -f "$GLOBAL_DIR/settings.json" "$GLOBAL_DIR/settings.local.json"
ln -sfn "$HOST_SETTINGS_FILE"       "$GLOBAL_DIR/settings.json"
ln -sfn "$HOST_SETTINGS_LOCAL_FILE" "$GLOBAL_DIR/settings.local.json"

# Ownership: -h so the symlinks themselves are chowned (not their targets).
chown -hR "$USER_NAME:$USER_NAME" "$GLOBAL_DIR" 2>/dev/null || true
chown -h  "$USER_NAME:$USER_NAME" "$USER_HOME/.claude" "$USER_HOME/.claude.json" 2>/dev/null || true

# A runtime init helper for postCreateCommand. Materializes the bind-mount
# subdirs and fixes ownership on every bind-mounted path so the feature
# works whether the host paths were created via initializeCommand, by hand,
# or auto-created by Docker as root.
cat > /usr/local/bin/claude-code-persist-init <<'INITSH'
#!/bin/sh
set -e
TARGET_USER="${SUDO_USER:-$(id -un)}"

PROJECTS_DIR=/var/claude-code-projects
for s in projects todos shell-snapshots sessions session-env tasks plans file-history paste-cache; do
    mkdir -p "$PROJECTS_DIR/$s"
done
touch "$PROJECTS_DIR/history.jsonl"

# Keep claude-projects out of git without polluting the repo's root .gitignore.
# Just "*" excludes everything in this directory, including the .gitignore
# itself — it stays invisible to git status entirely.
if [ ! -f "$PROJECTS_DIR/.gitignore" ]; then
    printf '*\n' > "$PROJECTS_DIR/.gitignore"
fi

chown -R "$TARGET_USER" "$PROJECTS_DIR"                                  2>/dev/null || true
chown -R "$TARGET_USER" /var/claude-code-host-skills                     2>/dev/null || true
chown    "$TARGET_USER" /var/claude-code-host-settings.json              2>/dev/null || true
chown    "$TARGET_USER" /var/claude-code-host-settings.local.json        2>/dev/null || true
INITSH
chmod 755 /usr/local/bin/claude-code-persist-init

echo "Claude Code persistence wired up for user '$USER_NAME' at '$USER_HOME'"
