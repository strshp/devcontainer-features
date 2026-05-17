# devcontainer-features

A small collection of custom [dev container Features](https://containers.dev/implementors/features/) published to GitHub Container Registry, following the [Feature distribution specification](https://containers.dev/implementors/features-distribution/).

## Features

| Feature | Description |
|---|---|
| [`claude-code-persist`](./src/claude-code-persist/) | Persists Claude Code state (credentials, settings, conversation logs) across container rebuilds via a mix of named volume, project-local bind mount, and host home bind mount. |

Each Feature has its own README in `src/<feature>/` with detailed usage instructions.

## Repo Structure

```
├── src
│   └── <feature>
│       ├── devcontainer-feature.json
│       ├── install.sh
│       └── README.md
└── test
    └── <feature>
        ├── test.sh
        ├── scenarios.json
        └── <scenario>.sh
```

An [implementing tool](https://containers.dev/supporting#tools) reads each Feature's `devcontainer-feature.json` and runs `install.sh` inside the container at build time.

## Distribution

### Publishing

The [release workflow](.github/workflows/release.yaml) publishes every Feature under `src/` to GHCR under the `strshp/devcontainer-features` namespace. After publishing, you can reference a Feature in `devcontainer.json` as:

```
ghcr.io/strshp/devcontainer-features/<feature-id>:<version>
```

### Marking Features public

GHCR packages are private by default. To make a Feature available without authentication, set its package visibility to `public` from its GHCR settings page:

```
https://github.com/users/strshp/packages/container/devcontainer-features%2F<feature-id>/settings
```

### Using private Features in Codespaces

If a Feature is left private, GitHub Codespaces needs the relevant repo-scoped token permissions. Add to your `devcontainer.json`:

```jsonc
{
    "customizations": {
        "codespaces": {
            "repositories": {
                "strshp/devcontainer-features": {
                    "permissions": {
                        "packages": "read",
                        "contents": "read"
                    }
                }
            }
        }
    }
}
```

---

This repository was bootstrapped from the [`devcontainers/feature-starter`](https://github.com/devcontainers/feature-starter) template.
