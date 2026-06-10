# Confluence CLI (confluence-cli)

Installs the [`kci-confluence-cli`](https://github.com/kurusugawa-computer/confluence-cli)
package from PyPI via [uv](https://github.com/astral-sh/uv), making the
`confluence` command available in the container. Optionally wires the Confluence
connection settings into the standard `CONFLUENCE_*` environment variables.

## Example Usage

```jsonc
"features": {
    "ghcr.io/strshp/devcontainer-features/confluence-cli:1": {
        "base_url": "https://confluence.example.com",
        "user_name": "alice",
        "user_password": "your_password"
    }
}
```

After the container is built, run the CLI directly:

```bash
confluence --help
```

## Options

| Option          | Type   | Default | Description                                                              |
| --------------- | ------ | ------- | ------------------------------------------------------------------------ |
| `base_url`      | string | `""`    | Exposed as the `CONFLUENCE_BASE_URL` environment variable.               |
| `user_name`     | string | `""`    | Exposed as the `CONFLUENCE_USER_NAME` environment variable.              |
| `user_password` | string | `""`    | Exposed as the `CONFLUENCE_USER_PASSWORD` environment variable.          |

Any option left empty is simply not exported, so the CLI falls back to whatever
`CONFLUENCE_*` value is already present in the environment.

## How it works

- `uv tool install kci-confluence-cli` installs the package into a shared,
  world-readable location (`/opt/uv`) and places the `confluence` launcher in
  `/usr/local/bin`, so it works for the root and non-root users alike.
- The three options are written to `/etc/profile.d/confluence-cli.sh` as
  `export` statements (also sourced from `/etc/bash.bashrc` and `/etc/zsh/zshrc`
  for interactive non-login shells).

## Security note

The credential values are written into the container image at build time
(devcontainer Feature options cannot be injected purely at runtime). Treat the
built image and the `devcontainer.json` containing `user_password` as secrets:
do not commit real credentials to a shared `devcontainer.json`, and do not push
the built image to a registry others can pull. The generated
`/etc/profile.d/confluence-cli.sh` is world-readable (mode `644`) inside the
container, like other profile scripts.
