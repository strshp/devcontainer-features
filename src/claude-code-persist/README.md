
# Claude Code Persistence (claude-code-persist)

Persists Claude Code state across container rebuilds.

State is split across three mounts:

| Where on host | What it stores | Mount type |
|---|---|---|
| Docker named volume `claude-code-global` | `~/.claude.json`, credentials, settings, plugins, caches, etc. — anything **not** in the per-project list | volume (shared across all projects on this machine) |
| `./.devcontainer/claude-projects/` in the project | Conversation/session data: `projects/`, `todos/`, `shell-snapshots/`, `sessions/`, `session-env/`, `tasks/`, `plans/`, `file-history/`, `paste-cache/`, `history.jsonl` | bind |
| `~/.claude/skills/` on the host | Custom skills, shared with the host's Claude Code install | bind |

Anything not in the per-project list goes to the shared volume (whitelist approach), so new files introduced by future Claude Code updates default to the safer machine-wide side.

## Example Usage

```jsonc
{
    "image": "mcr.microsoft.com/devcontainers/base:debian",

    // Required: create the bind-mount sources on the host before the
    // container starts. Without this, Docker creates them as root-owned
    // empty directories.
    "initializeCommand": "mkdir -p ${localWorkspaceFolder}/.devcontainer/claude-projects ${localEnv:HOME}/.claude/skills",

    "features": {
        "ghcr.io/anthropics/devcontainer-features/claude-code:1.0": {},
        "ghcr.io/strshp/devcontainer-features/claude-code-persist:1": {}
    }
}
```

## Required Setup

1. **Add the `initializeCommand` shown above** to your `devcontainer.json`.
   Without it, Docker creates the bind-mount source directories as `root`
   on first run and the container user can't write to them.
2. **Add `.devcontainer/claude-projects/` to `.gitignore`.** Conversation
   logs contain code snippets, file paths, and arbitrary prompt content
   that you almost certainly do not want committed.

## Windows host

The `initializeCommand` and the third mount use `${localEnv:HOME}`, which is
not defined on Windows. Windows users should replace `HOME` with `USERPROFILE`
or use WSL.

## Options

None.
