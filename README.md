# Linux Development Environment

Post-install setup scripts for various platforms.

## Platforms

| Directory | OS | Package Manager |
|-----------|-----|-----------------|
| [`setup-cachy-os/`](setup-cachy-os/README.md) | CachyOS Linux | paru (AUR) |
| `setup-fedora/` | Fedora Linux | dnf *(planned)* |
| `setup-macos/` | macOS | Homebrew *(planned)* |

## Quick Start (CachyOS)

```bash
git clone https://github.com/YOUR_USER/linux-dev-env.git
cd linux-dev-env/setup-cachy-os
chmod +x install.sh packages/*.sh

# With 1Password secret injection (recommended)
op run --env-file=~/.op-env -- bash install.sh --all

# Or interactively
bash install.sh --all
```

See [`setup-cachy-os/README.md`](setup-cachy-os/README.md) for full documentation.

## Manual Tools

```bash
# Claude Code
curl -fsSL https://claude.ai/install.sh | bash
```
