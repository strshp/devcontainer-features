
# Claude Code Persistence (claude-code-persist)

Persists Claude Code state across container rebuilds. Stores credentials and machine-wide settings in a shared named volume, conversation/session data in the project's .devcontainer/ directory, and bind-mounts the host's ~/.claude/skills plus settings.json/settings.local.json so they're shared with the host's Claude Code install.

## Example Usage

```json
"features": {
    "ghcr.io/strshp/devcontainer-features/claude-code-persist:1": {}
}
```





---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/strshp/devcontainer-features/blob/main/src/claude-code-persist/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
