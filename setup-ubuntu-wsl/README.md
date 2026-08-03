# Ubuntu on WSL — Post-Install Setup

Modular, idempotent post-install scripts for **Ubuntu running under WSL2** (24.04 "noble" and newer).

WSL variant of [`../setup-ubuntu`](../setup-ubuntu/README.md): everything graphical lives on the
Windows host, so this drops the terminal emulator, fonts, GUI apps and Docker Engine and keeps the
CLI development environment.

> **No secrets in this repo.** SSH keys are managed by 1Password. Git credentials and tokens are
> injected at runtime via `op run` — never stored here.

---

## Prerequisites

- WSL2 with an Ubuntu 24.04+ distro (`wsl --install -d Ubuntu-24.04` from Windows)
- Windows Terminal for the terminal + font (install the Nerd Font on **Windows**, not in the distro)
- Docker Desktop for Windows if you want containers (see below)
- 1Password CLI (`op`) installed inside the distro if using secret injection (recommended)

---

## Quick Start

```bash
# Clone this repo (into the Linux filesystem, not /mnt/c — much faster)
git clone https://github.com/YOUR_USER/linux-dev-env.git ~/workspace/linux-dev-env
cd ~/workspace/linux-dev-env/setup-ubuntu-wsl

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

For SSH keys: enable the **1Password SSH agent** in 1Password Settings → Developer, plus
**"Use the SSH agent with WSL"** under the same section on the Windows side.

---

## Usage

```
bash install.sh [flags]

Flags:
  --all        Run all steps (base → langs → dotfiles → claude)
  --base       Core tools: shell, CLI utilities, Git
  --langs      Languages: C/C++, Go, Rust, SDKMan, nvm, uv, Anaconda
  --dotfiles   Apply dotfiles via Chezmoi
  --claude     Symlink Claude Code config into ~/.claude/
```

Flags are composable: `bash install.sh --base --langs`

---

## What Gets Installed

### `--base` (packages/base.sh)

| Tool | Source | Notes |
|------|--------|-------|
| fish | `apt`, or `ppa:fish-shell/release-4` | Shell (set as default). PPA only added when the distro ships Fish 3.x (24.04); 26.04+ has 4.x |
| starship | official installer | Prompt |
| zoxide / fzf | `apt` | Smart `cd`, fuzzy finder |
| bat / ripgrep / fd | `apt` | Shipped as `batcat`/`fdfind`; shims linked into `~/.local/bin` |
| eza | GitHub release binary | Modern `ls` |
| lazygit | GitHub release binary | Git TUI |
| chezmoi | official installer | Dotfile manager (`/usr/local/bin`) |
| neovim | GitHub release tarball | `/opt/nvim-linux-x86_64` (apt's is too old for LazyVim) |
| github-cli | official GitHub apt repo | `gh` CLI |
| git / jq / zip / htop / btop | `apt` | Core utilities |
| Fisher + nvm.fish / fzf.fish / bass / sponge | Fisher | Fish plugins |

### `--langs` (packages/languages.sh)

Identical to `setup-ubuntu` — see that [README](../setup-ubuntu/README.md#--langs-packageslanguagessh).
build-essential/clang, Go, Rust (rustup), uv + pynvim, SDKMan, Node via nvm.fish, optional Anaconda.

Skip Anaconda: `SKIP_ANACONDA=1 bash install.sh --langs`

### `--dotfiles` (../dotfiles/)

Applied via Chezmoi from the shared `dotfiles/` directory. The Alacritty config is applied but
unused under WSL — terminal appearance is a Windows Terminal setting.

### `--claude` (packages/claude.sh)

Symlinks everything in `claude-skills/dot-claude/` into `~/.claude/`.

---

## After Running

**Shell:** Run `wsl --shutdown` from PowerShell (or just close and reopen the distro) for Fish to
become your login shell.

**Docker:** Not installed inside the distro. Install Docker Desktop on Windows, then enable this
distro under **Settings → Resources → WSL Integration**. That provides the `docker` CLI and daemon
without needing systemd or a second daemon in the distro.

**Font:** Install JetBrains Mono Nerd Font on **Windows** (from `../fonts/JetBrainsMono/`) and select
it in Windows Terminal → Settings → Profiles → Ubuntu → Appearance → Font face. Fonts installed
inside the distro have no effect.

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
setup-ubuntu-wsl/
├── install.sh              # Master orchestrator
├── lib/
│   └── utils.sh            # Shared logging & apt/PPA helpers
└── packages/
    ├── base.sh             # Core shell tools, Git config
    ├── languages.sh        # C/C++, Go, Rust, SDKMan, nvm, uv, Anaconda
    └── claude.sh           # Claude Code config symlinks
```

---

## Differences vs `setup-ubuntu`

| Dropped | Why |
|---------|-----|
| Alacritty | Terminal is Windows Terminal on the host |
| JetBrains Mono Nerd Font | Fonts must be installed on Windows to have any effect |
| `--apps` (Zed, VS Code, Ulauncher) | GUI apps run on Windows; use VS Code / Zed with the WSL remote extension |
| Docker CE + docker group | Docker Desktop's WSL integration provides the CLI and daemon |

Everything else — shell, CLI tooling, languages, dotfiles, Claude config — is identical.
