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
chmod +x install.sh migrate-legacy.sh packages/*.sh

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

Steps:
  --all        Run all steps (base → mise → langs → dotfiles → claude → agents)
  --base       System layer: apt packages, Fish + Fisher, Git config
  --mise       mise + every tool pinned in dotfiles/dot_config/mise/config.toml
  --langs      C/C++ toolchain, Rust (rustup), SDKMan, pynvim venv
  --dotfiles   Apply dotfiles via Chezmoi
  --claude     Symlink Claude Code config into ~/.claude/
  --agents     Install Claude Code, Codex, OpenCode, Herdr, and integrations

Maintenance:
  --update     Update everything installed (not part of --all)
  -h, --help   Show help
```

Flags are composable: `bash install.sh --base --mise --langs`

---

## The Two Layers

Tooling is split deliberately:

| Layer | Owner | What |
|-------|-------|------|
| **System** | `apt` | Compilers and debuggers, Fish (it is the login shell, so it must be a real path in `/etc/shells`), git, curl, archive and system utilities |
| **Tools** | `mise` | node, go, java, bun, python, uv, neovim, and the CLI tools — bat, chezmoi, eza, fd, fzf, gh, jq, lazygit, ripgrep, starship, zoxide |

Every mise-managed version lives in one file — [`dotfiles/dot_config/mise/config.toml`](../dotfiles/dot_config/mise/config.toml)
— which is **byte-identical across every distro in this repo**. That file is the unification point:
change a version there and it lands the same way on Ubuntu WSL, Fedora WSL, Fedora and CachyOS. No
apt/dnf/paru package-name differences, no per-distro GitHub-release tarball scripts, and no
`batcat`/`fdfind` naming shims.

```bash
mise ls        # what is managed, and where it came from
mise up        # upgrade everything
mise doctor    # diagnose PATH / activation problems
```

**PATH:** Fish gets `mise activate fish` from `config.fish`. Bash gets mise's *shims* via `~/.bashrc`,
which is what makes every toolchain visible to Neovim — `:!`, `:terminal`, and LSP/Mason spawns all
go through non-interactive bash, which never reads your Fish config. One line covers every managed
tool; only cargo needs its own, because rustup stays outside mise.

---

## What Gets Installed

### `--base` (packages/base.sh)

| Tool | Source | Notes |
|------|--------|-------|
| fish | `apt`, or `ppa:fish-shell/release-4` | Shell (set as login shell). PPA only added when the distro ships Fish 3.x (24.04); 26.04+ has 4.x |
| git / gawk / zip / unzip / htop / btop | `apt` | System utilities with no version pressure |
| Fisher + fzf.fish / bass / sponge | Fisher | Fish plugins. `nvm.fish` is gone — Node is mise's now |

`--base` also verifies the login shell actually took, and tells you which of the two usual causes
is at fault if it did not (a stale WSL session, or a Windows Terminal profile with a hardcoded
command line).

### `--mise` (packages/mise.sh)

Installs mise from the [official APT repo](https://mise.jdx.dev/installing-mise.html) — not the curl
installer — so mise itself upgrades with `apt upgrade` while it manages everything else. Then it
installs every tool in the shared manifest.

| Managed | Tools |
|---------|-------|
| Runtimes | node (lts), go, bun, python, java (temurin-21) |
| Python tooling | uv |
| Editor | neovim, `npm:neovim` (the Node provider, pinned as a tool so it survives a Node version change) |
| CLI | bat, chezmoi, eza, fd, fzf, gh, jq, lazygit, ripgrep, starship, zoxide |
| Agent tooling | [beads](https://github.com/gastownhall/beads) (`bd`) — declared as `github:gastownhall/beads`, since it is not in the mise registry |

> Chezmoi normally owns `~/.config/mise/config.toml`, but chezmoi is itself a mise-managed tool.
> `mise.sh` breaks the cycle by copying the repo's manifest into place first; the later `--dotfiles`
> step writes the identical file.

### `--langs` (packages/languages.sh)

Only what does *not* belong in mise:

| Kept out of mise | Why |
|------------------|-----|
| C/C++ toolchain | System compilers and debuggers; needs system integration |
| Rust (rustup) | mise's `rust` delegates to rustup anyway, and clippy / rustfmt / rust-analyzer are per-toolchain rustup components |
| SDKMan | Kept for kotlin, scala, maven, gradle, springboot. **The JDK itself comes from mise** |
| pynvim venv | `~/.nvim-venv` for Neovim's Python provider — uv's job |

Anaconda was **dropped**. It is a competing environment manager, and having it and mise both own
PATH invites confusing breakage. Use mise's python plus uv instead.

### `--update`

The gap the pre-mise setup had: eza, lazygit, starship, chezmoi, neovim and bun were installed once
and then never touched again, because every guard was a bare `is_installed` check. `--update` runs
`apt upgrade` → `mise up` → `rustup update` → `fisher update` → `chezmoi apply` → agent CLI
self-updates.

### `--dotfiles` (../dotfiles/)

Applied via Chezmoi from the shared `dotfiles/` directory. The Alacritty config is applied but
unused under WSL — terminal appearance is a Windows Terminal setting.

### `--claude` (packages/claude.sh)

Symlinks everything in `claude-skills/dot-claude/` into `~/.claude/`.

### `--agents` (packages/agents.sh)

Installs the agentic terminal workflow with each project's official native installer:

| Tool | Source | Notes |
|------|--------|-------|
| Claude Code | `claude.ai/install.sh` | Runs as `claude`; first launch prompts for authentication |
| OpenAI Codex CLI | `chatgpt.com/codex/install.sh` | Runs as `codex`; first launch prompts for authentication |
| OpenCode | `opencode.ai/install` | Runs as `opencode`; configure a provider with `/connect` |
| Herdr | `herdr.dev/install.sh` | Persistent terminal workspaces for all three agents |

The step also installs the Herdr integrations for Claude Code, Codex, and OpenCode so their native
conversation sessions can be restored after a Herdr/WSL restart. Fish completion is generated at
`~/.config/fish/completions/herdr.fish`. Re-running `--agents` skips installed binaries and refreshes
the integrations and completion file.

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

**Tools:** `mise ls` shows everything managed and its version. `mise up` upgrades it all. If a tool
seems missing, `mise doctor` is the first thing to run.

**Java:** comes from mise (`temurin-21`). Use SDKMan for the rest of the JVM ecosystem:
```bash
sdk install kotlin
sdk install maven
```
mise's shims are prepended *after* SDKMan's candidate paths in `config.fish`, so `java` resolves to
the mise JDK even if a SDKMan JDK is also installed.

**GitHub CLI:** `gh auth login`

**Neovim:** Run `nvim` — LazyVim auto-bootstraps and installs all plugins on first launch.

**Agentic workflow:** Every interactive Fish shell starts Herdr automatically (`config.fish`), so a
new Windows Terminal tab lands straight in the persistent session — launch `claude`, `codex`, or
`opencode` in its panes. The autostart is skipped inside Herdr's own panes (it exports `HERDR_ENV`),
in non-interactive shells, and when `HERDR_AUTOSTART=0` is set; quitting Herdr drops you back to a
plain Fish prompt rather than closing the terminal.

**Workspace template:** `herdr-workspace [PATH]` (a Fish function in
`dotfiles/dot_config/fish/functions/`) creates a workspace labelled after the directory, with seven
tabs — Research, Implement, Review, nvim, lazygit, ollama, shell — every pane a shell rooted at
`PATH`, which defaults to the current directory. Research, Implement, Review and shell get two
vertically split panes; the rest get one. Nothing is auto-started: the tabs are labelled shells, so
you choose the agent per project. Edit the `tab_template` list at the top of the function to change
the layout, and run `herdr-workspace --help` to print it. Closing Windows Terminal only detaches the Herdr client; the WSL processes
keep running. Shutting down Windows stops those processes, and Herdr restores eligible integrated
agent conversations when it starts again.

---

## Repository Structure

```
setup-ubuntu-wsl/
├── install.sh              # Master orchestrator
├── migrate-legacy.sh       # Pre-mise cleanup (dry run by default)
├── lib/
│   └── utils.sh            # Shared logging & apt/PPA helpers
├── packages/
│   ├── base.sh             # System layer: apt, Fish, Fisher, Git config
│   ├── mise.sh             # mise + the shared tool manifest
│   ├── languages.sh        # C/C++, Rust (rustup), SDKMan, pynvim
│   ├── claude.sh           # Claude Code config symlinks
│   └── agents.sh           # AI agents, Herdr, integrations, Fish completion
└── tests/
    └── agents_test.sh      # Network-free agentic setup and idempotency test
```

---

## Migrating an Existing Install

If this distro was set up before the mise split, run the migration after `--mise`:

```bash
bash install.sh --base --mise      # get the replacements in place first
bash migrate-legacy.sh             # DRY RUN — prints what it would remove
bash migrate-legacy.sh --apply     # execute
```

It is safe by construction:

1. **Dry run is the default.** `--apply` is required to touch anything.
2. **It refuses to run** until mise has installed the replacements, so you always have a working
   toolchain before anything is removed.
3. **Everything removable is backed up** to `~/.dev-env-backup-<timestamp>/` first.

What it reclaims: the `nvm.fish` Fisher plugin and `~/.local/share/nvm`, `~/.bun`, the `golang-go`
apt package, the hand-installed binaries in `/usr/local/bin` and `/opt/nvim-linux-x86_64`, the
`bat`/`fd` naming shims, the standalone `uv`, the apt packages mise now provides, and `~/anaconda3`.

SDKMan is **kept** — only its role narrows, from "Java and everything else JVM" to "everything else
JVM".

**If you skip the migration entirely, nothing breaks.** `mise activate` prepends its shims to PATH,
so the mise-managed tools already win over the leftovers. The script only reclaims disk and removes
the ambiguity.

---

## Differences vs `setup-ubuntu`

| Dropped | Why |
|---------|-----|
| Alacritty | Terminal is Windows Terminal on the host |
| JetBrains Mono Nerd Font | Fonts must be installed on Windows to have any effect |
| `--apps` (Zed, VS Code, Ulauncher) | GUI apps run on Windows; use VS Code / Zed with the WSL remote extension |
| Docker CE + docker group | Docker Desktop's WSL integration provides the CLI and daemon |

Everything else is identical. The `--mise` step and the shared tool manifest are what make this
tree nearly a copy of [`../setup-fedora-wsl`](../setup-fedora-wsl/README.md) — the two differ only in
their system-package layer.
