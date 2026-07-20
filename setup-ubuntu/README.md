# Ubuntu Post-Install Setup

Modular, idempotent post-install scripts for **Ubuntu** (24.04 "noble" and newer) —
tuned for a **work laptop** (no gaming module).

> **No secrets in this repo.** SSH keys are managed by 1Password. Git credentials and tokens are
> injected at runtime via `op run` — never stored here.

---

## Prerequisites

- Ubuntu 24.04+ (or a Debian-based distro with `apt-get` and `add-apt-repository`)
- 1Password CLI (`op`) installed if using secret injection (recommended)
- Internet connection

---

## Quick Start

```bash
# Clone this repo
git clone https://github.com/YOUR_USER/linux-dev-env.git
cd linux-dev-env/setup-ubuntu

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
  --all        Run all steps (base → langs → apps → dotfiles → claude)
  --base       Core tools: shell, terminal, fonts, Docker, Git
  --langs      Languages: C/C++, Go, Rust, SDKMan, nvm, uv, Anaconda
  --apps       GUI apps: Zed, VS Code, Ulauncher
  --dotfiles   Apply dotfiles via Chezmoi
  --claude     Symlink Claude Code config into ~/.claude/
```

Flags are composable: `bash install.sh --base --langs`

---

## What Gets Installed

### `--base` (packages/base.sh)

| Tool | Source | Notes |
|------|--------|-------|
| fish | `ppa:fish-shell/release-4` | Shell (set as default), Fish 4.x |
| alacritty | `apt` | Primary terminal (Ghostty has no apt package) |
| starship | official installer | Prompt |
| zoxide / fzf | `apt` | Smart `cd`, fuzzy finder |
| bat / ripgrep / fd | `apt` | Shipped as `batcat`/`fdfind`; shims linked into `~/.local/bin` |
| eza | GitHub release binary | Modern `ls` |
| lazygit | GitHub release binary | Git TUI |
| chezmoi | official installer | Dotfile manager (`/usr/local/bin`) |
| neovim | GitHub release tarball | `/opt/nvim-linux-x86_64` (apt's is too old for LazyVim) |
| docker-ce + compose | official Docker apt repo | Containers (user added to group) |
| github-cli | official GitHub apt repo | `gh` CLI |
| git / jq / zip / htop / btop | `apt` | Core utilities |
| JetBrains Mono Nerd Font | repo `fonts/` | Copied to `~/.local/share/fonts` |
| Fisher + nvm.fish / fzf.fish / bass / sponge | Fisher | Fish plugins |

### `--langs` (packages/languages.sh)

| Tool | Source | Notes |
|------|--------|-------|
| build-essential / clang / clangd | `apt` | C/C++ compilers + LSP |
| make / ninja / cmake / gdb / lldb / ccache | `apt` | Build & debug |
| Go | `apt` (`golang-go`) | |
| Rust | official rustup installer | `rustup default stable` + rust-analyzer/clippy/rustfmt |
| uv | official installer | Fast Python package manager |
| pynvim | uv venv `~/.nvim-venv` | Neovim Python provider |
| SDKMan | `curl` | Java / Kotlin / Gradle via `sdk` |
| Node (nvm.fish) | Fisher | `nvm install lts` |
| Anaconda | official installer | Optional (prompted, ~1 GB) |

Skip Anaconda: `SKIP_ANACONDA=1 bash install.sh --langs`

### `--apps` (packages/apps.sh)

| App | Source | Notes |
|-----|--------|-------|
| Zed | official installer | `zed` |
| VS Code | Microsoft apt repo | `code` |
| Ulauncher | `ppa:agornostal/ulauncher` | App launcher (Wayland needs a manual hotkey — see below) |

### `--dotfiles` (../dotfiles/)

Applied via Chezmoi from the shared `dotfiles/` directory (Fish, Alacritty, Ghostty,
Starship, Neovim configs).

### `--claude` (packages/claude.sh)

Symlinks everything in `claude-skills/dot-claude/` into `~/.claude/`.

---

## After Running

**Docker:** Log out and back in (or run `newgrp docker`) for the group change to take effect.

**Shell:** Log out and back in for Fish to become your login shell.

**Ulauncher on Wayland:** Ubuntu's default GNOME session is Wayland, where apps can't grab
global hotkeys. Bind it manually:
1. Ulauncher Preferences → set hotkey to something unused (e.g. `Ctrl+F23`)
2. Settings → Keyboard → View and Customize Shortcuts → Custom Shortcuts → **+**
   - Name: `Ulauncher`  ·  Command: `ulauncher-toggle`  ·  Shortcut: `Alt+Space`

On an X11 session the default `Alt+Space` hotkey works out of the box.

**SDKMan:**
```bash
sdk install java          # latest LTS
sdk install java 21-tem   # or a specific version
```

**Node:**
```fish
nvm install lts
nvm use lts
```

**GitHub CLI:** `gh auth login`

**Neovim:** Run `nvim` — LazyVim auto-bootstraps and installs all plugins on first launch.

---

## Repository Structure

```
setup-ubuntu/
├── install.sh              # Master orchestrator
├── lib/
│   └── utils.sh            # Shared logging & apt/PPA helpers
└── packages/
    ├── base.sh             # Core shell tools, fonts, Docker, Git
    ├── languages.sh        # C/C++, Go, Rust, SDKMan, nvm, uv, Anaconda
    ├── apps.sh             # Zed, VS Code, Ulauncher
    └── claude.sh           # Claude Code config symlinks
```

---

## Notes vs Other Platforms

This mirrors `setup-fedora/` (both use plain system package managers pulling from
third-party repos). Key Ubuntu-specific differences:

- **No gaming module** — this is a work-laptop setup.
- **Ghostty** is not packaged for Ubuntu; Alacritty is the primary terminal.
- **`bat`/`fd`** are `batcat`/`fdfind` on Debian/Ubuntu — shimmed into `~/.local/bin`.
- **Neovim** comes from the upstream GitHub tarball, not apt (apt's is too old for LazyVim).
