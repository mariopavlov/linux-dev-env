# Linux Development Environment

Post-install setup scripts for various platforms.

## Platforms

| Directory | OS | Package Manager |
|-----------|-----|-----------------|
| [`setup-cachy-os/`](setup-cachy-os/README.md) | CachyOS Linux | paru (AUR) |
| [`setup-ubuntu/`](setup-ubuntu/README.md) | Ubuntu 24.04+ | apt (work laptop, no gaming) |
| [`setup-ubuntu-wsl/`](setup-ubuntu-wsl/README.md) | Ubuntu 24.04+ on WSL2 | apt (CLI only, no GUI/Docker Engine) |
| `setup-fedora/` | Fedora Linux | dnf |
| [`setup-fedora-wsl/`](setup-fedora-wsl/README.md) | Fedora on WSL | dnf (CLI only, no GUI/Docker Engine) |
| `setup-macos/` | macOS | Homebrew *(planned)* |

## Shared Layers

Two things are shared across every platform directory, and they are what keep the per-distro
scripts thin:

| Shared | Path | What it owns |
|--------|------|--------------|
| **Tool manifest** | [`dotfiles/dot_config/mise/config.toml`](dotfiles/dot_config/mise/config.toml) | node, go, java, bun, python, uv, neovim and the CLI tools (bat, chezmoi, eza, fd, fzf, gh, jq, lazygit, ripgrep, starship, zoxide) — plus beads (`bd`) — pinned once, identical everywhere |
| **Dotfiles** | [`dotfiles/`](dotfiles/) | Fish, Starship, Neovim (LazyVim), Alacritty, Ghostty — applied with Chezmoi |

Each `setup-*/` directory then only has to cover what genuinely differs: the system package
manager, the compilers, and the login shell.

> **Status:** `setup-ubuntu-wsl/` and `setup-fedora-wsl/` are on the mise split.
> `setup-ubuntu/`, `setup-fedora/` and `setup-cachy-os/` still install their tools per-distro and
> have not been ported yet.

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

## Planned Work

See [`TODO.md`](TODO.md).
