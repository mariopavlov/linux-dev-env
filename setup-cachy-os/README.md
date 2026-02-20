# CachyOS Post-Install Setup

Modular, idempotent post-install scripts for **CachyOS Linux** on Lenovo Legion / RTX 5090.

> **No secrets in this repo.** SSH keys are managed by 1Password. Git credentials and tokens are
> injected at runtime via `op run` — never stored here.

---

## Prerequisites

- CachyOS freshly installed with `paru` available (CachyOS default)
- 1Password CLI (`op`) installed if using secret injection (recommended)
- Internet connection

---

## Quick Start

```bash
# Clone this repo
git clone https://github.com/YOUR_USER/linux-dev-env.git
cd linux-dev-env/setup-cachy-os

# Make scripts executable
chmod +x install.sh packages/*.sh

# Run everything at once
bash install.sh --all

# Or with 1Password secret injection (recommended)
op run --env-file=~/.op-env -- bash install.sh --all
```

---

## 1Password Secret Injection

Create `~/.op-env` (**not in this repo**) with references to your 1Password vault:

```bash
# ~/.op-env  (git-ignored, managed by 1Password)
GIT_USER_NAME=op://Private/Git/username
GIT_USER_EMAIL=op://Private/Git/email
```

Then run any script with:
```bash
op run --env-file=~/.op-env -- bash install.sh --base
```

For SSH keys: enable the **1Password SSH agent** in 1Password Settings → Developer.
The `config.fish` dotfile sets `SSH_AUTH_SOCK` automatically.

---

## Usage

```
bash install.sh [flags]

Flags:
  --all        Run all steps (base → langs → apps → gaming → dotfiles)
  --base       Core tools: shell, terminals, fonts, Docker, Git
  --langs      Languages: C/C++, Go, Rust, SDKMan, nvm, uv, Anaconda
  --apps       GUI apps: Zed, VS Code, JetBrains Toolbox
  --gaming     Gaming: Steam, Lutris, Heroic, Wine/Proton, MangoHud
  --dotfiles   Apply dotfiles via Chezmoi
```

Flags are composable: `bash install.sh --base --langs`

---

## What Gets Installed

### `--base` (packages/base.sh)

| Tool | Source | Notes |
|------|--------|-------|
| fish | `paru` | Shell (set as default) |
| starship | `paru` | Prompt |
| ghostty | `paru extra/ghostty` | Primary terminal |
| alacritty | `paru` | Backup terminal |
| zoxide | `paru` | Smart `cd` |
| zellij | `paru` | Terminal multiplexer |
| fzf | `paru` | Fuzzy finder |
| eza / bat / ripgrep / fd | `paru` | Modern CLI replacements |
| docker + docker-compose | `paru` | Containers (user added to group) |
| github-cli | `paru` | `gh` CLI |
| chezmoi | `paru` | Dotfile manager |
| neovim | `paru` | Editor |
| JetBrains Mono Nerd Font | `paru` | `ttf-jetbrains-mono-nerd` |
| Fisher | fish | Plugin manager |
| nvm.fish | Fisher | Node version manager |
| fzf.fish | Fisher | fzf Fish integration |
| bass | Fisher | Run bash scripts in Fish |

### `--langs` (packages/languages.sh)

| Tool | Source | Notes |
|------|--------|-------|
| gcc / clang | `paru` | C/C++ compilers |
| make / ninja | `paru` | Build systems |
| cmake | `paru` | Build generator |
| gdb / lldb | `paru` | Debuggers |
| ccache | `paru` | Compiler cache |
| Go | `paru` | `go` binary |
| Rust | `paru rustup` | `rustup default stable` |
| uv | `paru` | Fast Python package manager |
| SDKMan | `curl` | Java / Kotlin / Gradle via `sdk` |
| Node (nvm.fish) | Fisher | `nvm install lts` |
| Anaconda | `paru` | Optional (prompted, ~1 GB) |

Skip Anaconda: `SKIP_ANACONDA=1 bash install.sh --langs`

### `--apps` (packages/apps.sh)

| App | AUR package |
|-----|-------------|
| Zed | `zed` |
| VS Code | `visual-studio-code-bin` |
| JetBrains Toolbox | `jetbrains-toolbox` |

### `--gaming` (packages/gaming.sh)

| Package | Notes |
|---------|-------|
| Steam | Requires multilib (auto-enabled) |
| Lutris | Wine/Proton game launcher |
| Heroic | Epic / GOG / Amazon launcher |
| wine-staging + winetricks | Windows compatibility |
| lib32-nvidia-utils | RTX 5090 32-bit libs for Steam |
| vulkan-nvidia / lib32 | Vulkan for DXVK / VKD3D |
| ProtonUp-Qt | Install Proton-GE versions |
| Gamemode | Performance governor |
| MangoHud | FPS/GPU overlay (use `MANGOHUD=1 %command%`) |

### `--dotfiles` (dotfiles/)

Applied via Chezmoi. Files:

| Source | Target |
|--------|--------|
| `dotfiles/.config/fish/config.fish` | `~/.config/fish/config.fish` |
| `dotfiles/.config/fish/conf.d/aliases.fish` | `~/.config/fish/conf.d/aliases.fish` |
| `dotfiles/.config/ghostty/config` | `~/.config/ghostty/config` |
| `dotfiles/.config/starship.toml` | `~/.config/starship.toml` |
| `dotfiles/.config/nvim/init.lua` | `~/.config/nvim/init.lua` |

To use your own dotfiles repo instead:
```bash
chezmoi init git@github.com:YOUR_USER/dotfiles.git
chezmoi apply
```

---

## After Running

**Docker:** Log out and back in (or run `newgrp docker`) for the group change to take effect.

**SDKMan:** Open a new shell, then:
```bash
sdk install java          # install latest LTS
sdk install java 21-tem   # or a specific version
```

**Node:**
```fish
nvm install lts
nvm use lts
```

**GitHub CLI:**
```bash
gh auth login
```

**Neovim:** Run `nvim` — LazyNvim auto-bootstraps and installs all plugins on first launch.

---

## Repository Structure

```
setup-cachy-os/
├── install.sh              # Master orchestrator
├── lib/
│   └── utils.sh            # Shared logging & helper functions
├── packages/
│   ├── base.sh             # Core shell tools, fonts, Docker, Git
│   ├── languages.sh        # C/C++, Go, Rust, SDKMan, nvm, uv, Anaconda
│   ├── apps.sh             # Zed, VS Code, JetBrains Toolbox
│   └── gaming.sh           # Steam, Lutris, Heroic, Wine/Proton
└── dotfiles/
    └── .config/
        ├── fish/
        │   ├── config.fish
        │   └── conf.d/aliases.fish
        ├── ghostty/config
        ├── nvim/init.lua       # LazyNvim bootstrap
        └── starship.toml
```

---

## Future Platforms

This setup is CachyOS-specific. Parallel setups planned:
- `setup-fedora/` — dnf-based, similar structure
- `setup-macos/` — Homebrew-based, Aerospace WM
