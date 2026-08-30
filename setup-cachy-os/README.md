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

For SSH keys: enable the **1Password SSH agent** in 1Password Settings → Developer.
The `config.fish` dotfile sets `SSH_AUTH_SOCK` automatically.

---

## Usage

```
bash install.sh [flags]

Steps:
  --all        Run all steps (base → mise → langs → apps → gaming → dotfiles → claude → agents)
  --base       System layer: paru packages, Ghostty/Alacritty, fonts, Fish + Fisher,
               Docker, Git config
  --mise       mise + every tool pinned in dotfiles/dot_config/mise/config.toml
  --langs      C/C++ toolchain, Rust (rustup), SDKMan, pynvim venv
  --apps       Zed, VS Code, VS Code Insiders, JetBrains Toolbox, Copilot CLI
  --gaming     Steam, Lutris, Heroic, Wine/Proton, MangoHud
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
| **System** | `paru` | Compilers and debuggers, Fish (it is the login shell, so it must be a real path in `/etc/shells`), Ghostty and Alacritty, fonts, Docker, git, curl, archive and system utilities |
| **Tools** | `mise` | node, go, java, bun, python, uv, neovim, and the CLI tools — bat, chezmoi, eza, fd, fzf, gh, jq, lazygit, ripgrep, starship, zoxide |

On a rolling distro paru's versions are already current, so this split is **not** about freshness
here. It is about this machine resolving the same tool versions, from the same manifest, as every
other machine in this repo — [`dotfiles/dot_config/mise/config.toml`](../dotfiles/dot_config/mise/config.toml),
which is byte-identical on CachyOS, Fedora, Ubuntu and both WSL trees.

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
| fish | `paru` | Shell (set as login shell) |
| ghostty + ghostty-shell-integration | `paru extra/ghostty` | Primary terminal |
| alacritty | `paru` | Backup terminal |
| docker + docker-compose | `paru` | Containers (user added to the `docker` group) |
| git / curl / wget / gawk / zip / unzip / htop / btop | `paru` | System utilities with no version pressure |
| JetBrains Mono Nerd Font | repo `fonts/` | Copied to `~/.local/share/fonts` |
| Fisher + fzf.fish / bass / sponge | Fisher | Fish plugins. `nvm.fish` is gone — Node is mise's now |

### `--mise` (packages/mise.sh)

Installs mise from Arch's `extra` repo so it upgrades with `paru -Syu` while it manages everything
else, then installs every tool in the shared manifest.

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
| Rust (rustup) | `paru rustup` — Arch ships the upstream binary; mise's `rust` delegates to rustup anyway, and clippy / rustfmt / rust-analyzer are per-toolchain rustup components |
| SDKMan | Kept for kotlin, scala, maven, gradle, springboot. **The JDK itself comes from mise** |
| pynvim venv | `~/.nvim-venv` for Neovim's Python provider — uv's job |

Anaconda was **dropped**. It is a competing environment manager, and having it and mise both own
PATH invites confusing breakage. Use mise's python plus uv instead.

### `--apps` (packages/apps.sh)

| App | Source | Notes |
|-----|--------|-------|
| Zed | `paru` | `zed` |
| VS Code | `paru` | `visual-studio-code-bin` |
| VS Code Insiders | `paru` | `visual-studio-code-insiders-bin` |
| JetBrains Toolbox | `paru` | `jetbrains-toolbox` |
| GitHub Copilot CLI | `npm` (mise's Node) | `@github/copilot` — runs as `copilot`, installed **without** sudo |

Codex moved out of this file — it is installed by `--agents` from its official native installer,
alongside Claude Code, OpenCode and Herdr.

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

### `--update`

Runs `paru -Syu` → `mise up` → `rustup update` → `fisher update` → `chezmoi apply` → agent CLI
self-updates. Not part of `--all`.

### `--dotfiles` (../dotfiles/)

Applied via Chezmoi from the shared `dotfiles/` directory: Fish, Starship, Neovim (LazyVim),
Alacritty, Ghostty, mise and Herdr.

To use your own dotfiles repo instead:
```bash
chezmoi init git@github.com:YOUR_USER/dotfiles.git
chezmoi apply
```

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
conversation sessions can be restored after a Herdr restart. Fish completion is generated at
`~/.config/fish/completions/herdr.fish`. Re-running `--agents` skips installed binaries and refreshes
the integrations and completion file.

---

## After Running

**Docker:** Log out and back in (or run `newgrp docker`) for the group change to take effect.

**Shell:** Log out and back in for Fish to become your login shell.

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
new terminal tab lands straight in the persistent session — launch `claude`, `codex`, or `opencode`
in its panes. The autostart is skipped inside Herdr's own panes (it exports `HERDR_ENV`), in
non-interactive shells, and when `HERDR_AUTOSTART=0` is set; quitting Herdr drops you back to a plain
Fish prompt rather than closing the terminal.

**Workspace template:** `herdr-workspace [PATH]` (a Fish function in
`dotfiles/dot_config/fish/functions/`) creates a workspace labelled after the directory, with seven
tabs — Research, Implement, Review, nvim, lazygit, ollama, shell — every pane a shell rooted at
`PATH`, which defaults to the current directory. Run `herdr-workspace --help` to print the layout.

---

## Repository Structure

```
setup-cachy-os/
├── install.sh              # Master orchestrator
├── migrate-legacy.sh       # Pre-mise cleanup (dry run by default)
├── lib/
│   └── utils.sh            # Shared logging & paru helpers
├── packages/
│   ├── base.sh             # System layer: paru, terminals, fonts, Fish, Docker, Git
│   ├── mise.sh             # mise + the shared tool manifest
│   ├── languages.sh        # C/C++, Rust (rustup), SDKMan, pynvim
│   ├── apps.sh             # Zed, VS Code, JetBrains Toolbox, Copilot CLI
│   ├── gaming.sh           # Steam, Lutris, Heroic, Wine/Proton
│   ├── claude.sh           # Claude Code config symlinks
│   └── agents.sh           # AI agents, Herdr, integrations, Fish completion
└── tests/
    └── agents_test.sh      # Network-free agentic setup and idempotency test
```

Dotfiles are **not** local to this directory — they live in the shared
[`../dotfiles/`](../dotfiles/) tree and are applied with Chezmoi.

---

## Migrating an Existing Install

If this machine was set up before the mise split, run the migration after `--mise`:

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

What it reclaims: the `nvm.fish` Fisher plugin and `~/.local/share/nvm`, `~/.bun`, and the pacman
packages mise now provides (go, zoxide, fzf, eza, bat, ripgrep, fd, jq, chezmoi, neovim, starship,
lazygit, github-cli, anaconda). It also *reports* — without touching — the `sudo npm install -g`
copies of Copilot CLI and Codex under `/usr/lib/node_modules`, which the old `apps.sh` created
against the system Node.

SDKMan is **kept** — only its role narrows, from "Java and everything else JVM" to "everything else
JVM".

**If you skip the migration entirely, nothing breaks.** `mise activate` prepends its shims to PATH,
so the mise-managed tools already win over the leftovers. The script only reclaims disk and removes
the ambiguity.

---

## Future Platforms

- `setup-macos/` — Homebrew-based, Aerospace WM
