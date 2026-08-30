# Fedora — Post-Install Setup

Modular, idempotent post-install scripts for **bare-metal Fedora Linux**.

For Fedora running under WSL use [`../setup-fedora-wsl`](../setup-fedora-wsl/README.md) instead — it
drops the terminal emulators, fonts, GUI apps, gaming stack and Docker Engine, none of which belong
inside a WSL distro.

> **No secrets in this repo.** SSH keys are managed by 1Password. Git credentials and tokens are
> injected at runtime via `op run` — never stored here.

---

## Prerequisites

- Fedora Workstation (tested on Fedora 42/43)
- 1Password CLI (`op`) if using secret injection (recommended)

---

## Quick Start

```bash
git clone https://github.com/YOUR_USER/linux-dev-env.git ~/workspace/linux-dev-env
cd ~/workspace/linux-dev-env/setup-fedora

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

For SSH keys: enable the **1Password SSH agent** in 1Password Settings → Developer. `config.fish`
already points `SSH_AUTH_SOCK` at it.

---

## Usage

```
bash install.sh [flags]

Steps:
  --all        Run all steps (base → mise → langs → apps → gaming → dotfiles → agents)
  --base       System layer: dnf packages, Ghostty/Alacritty, fonts, Fish + Fisher,
               Docker CE, Git config
  --mise       mise + every tool pinned in dotfiles/dot_config/mise/config.toml
  --langs      C/C++ toolchain, Rust (rustup), SDKMan, pynvim venv
  --apps       Zed, VS Code, JetBrains Toolbox, Ulauncher
  --gaming     Steam, Lutris, Heroic, Wine/Proton, NVIDIA
  --dotfiles   Apply dotfiles via Chezmoi
  --agents     Install Claude Code, Codex, OpenCode, Herdr, and integrations

Maintenance:
  --update     Update everything installed (not part of --all)
  -h, --help   Show help
```

Flags are composable: `bash install.sh --base --mise --langs`

`--claude` is currently a no-op while the skills are being rewritten.

---

## The Two Layers

Tooling is split deliberately:

| Layer | Owner | What |
|-------|-------|------|
| **System** | `dnf` | Compilers and debuggers, Fish (it is the login shell, so it must be a real path in `/etc/shells`), Ghostty and Alacritty, fonts, Docker Engine, git, curl, archive and system utilities |
| **Tools** | `mise` | node, go, java, bun, python, uv, neovim, and the CLI tools — bat, chezmoi, eza, fd, fzf, gh, jq, lazygit, ripgrep, starship, zoxide |

Every mise-managed version lives in one file — [`dotfiles/dot_config/mise/config.toml`](../dotfiles/dot_config/mise/config.toml)
— which is **byte-identical across every distro in this repo**. That file is the unification point:
change a version there and it lands the same way on Fedora, CachyOS, Ubuntu and both WSL trees. No
apt/dnf/paru package-name differences, no per-distro GitHub-release tarball scripts.

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
| Ghostty | COPR `scottames/ghostty` | Installed **before** fish — see the terminfo note below |
| ncurses-term | `dnf download` + `rpm --replacefiles` | Reinstated alongside Ghostty; both ship the same `terminfo/g/ghostty` |
| alacritty | `dnf` | Backup terminal |
| fish | `dnf` | Shell (set as login shell) |
| git / curl / gawk / zip / unzip / htop / btop | `dnf` | System utilities with no version pressure |
| util-linux-user | `dnf` | Provides `chsh`/`usermod` |
| JetBrains Mono Nerd Font | `../fonts/` | Copied to `~/.local/share/fonts` |
| Docker CE | Docker's dnf repo | Service enabled, user added to the `docker` group |
| Fisher + fzf.fish / bass / sponge | Fisher | Fish plugins. `nvm.fish` is gone — Node is mise's now |

> **Ghostty before fish:** `ghostty` and `ncurses-term` both ship
> `/usr/share/terminfo/g/ghostty`, and fish hard-depends on `ncurses-term`. Installing Ghostty first
> with `--allowerasing`, then putting `ncurses-term` back with `rpm --replacefiles`, avoids fish
> being removed as collateral later.

### `--mise` (packages/mise.sh)

Installs mise from the [official DNF repo](https://mise.jdx.dev/installing-mise.html) — not the curl
installer — so mise itself upgrades with `dnf upgrade` while it manages everything else. Then it
installs every tool in the shared manifest.

This also removes the COPR dependencies this tree used to carry: `atim/starship` and `atim/lazygit`
are no longer needed, since mise provides both. `scottames/ghostty` stays — Ghostty is still a dnf
package.

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
| Rust (rustup) | Installed from `dnf` then `rustup-init`; mise's `rust` delegates to rustup anyway, and clippy / rustfmt / rust-analyzer are per-toolchain rustup components |
| SDKMan | Kept for kotlin, scala, maven, gradle, springboot. **The JDK itself comes from mise** |
| pynvim venv | `~/.nvim-venv` for Neovim's Python provider — uv's job |

Anaconda was **dropped**. It is a competing environment manager, and having it and mise both own
PATH invites confusing breakage. Use mise's python plus uv instead.

### `--apps` (packages/apps.sh)

Zed, VS Code, JetBrains Toolbox and Ulauncher.

### `--gaming` (packages/gaming.sh)

Steam, Lutris, Heroic, Wine/Proton and the NVIDIA driver stack.

### `--update`

The gap the pre-mise setup had: eza, lazygit, starship, chezmoi, neovim and bun were installed once
and then never touched again, because every guard was a bare `is_installed` check. `--update` runs
`dnf upgrade` → `mise up` → `rustup update` → `fisher update` → `chezmoi apply` → agent CLI
self-updates.

### `--dotfiles` (../dotfiles/)

Applied via Chezmoi from the shared `dotfiles/` directory: Fish, Starship, Neovim (LazyVim),
Alacritty, Ghostty, mise and Herdr.

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

**Shell:** Log out and back in for Fish to become your login shell.

**Docker:** Log out and back in (or run `newgrp docker`) for the group change to take effect.

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
`PATH`, which defaults to the current directory. Nothing is auto-started: the tabs are labelled
shells, so you choose the agent per project. Run `herdr-workspace --help` to print the layout.

---

## Repository Structure

```
setup-fedora/
├── install.sh              # Master orchestrator
├── migrate-legacy.sh       # Pre-mise cleanup (dry run by default)
├── lib/
│   └── utils.sh            # Shared logging & dnf/COPR helpers
├── packages/
│   ├── base.sh             # System layer: dnf, terminals, fonts, Fish, Docker, Git
│   ├── mise.sh             # mise + the shared tool manifest
│   ├── languages.sh        # C/C++, Rust (rustup), SDKMan, pynvim
│   ├── apps.sh             # Zed, VS Code, JetBrains Toolbox, Ulauncher
│   ├── gaming.sh           # Steam, Lutris, Heroic, Wine/Proton, NVIDIA
│   ├── claude.sh           # Claude Code config symlinks
│   └── agents.sh           # AI agents, Herdr, integrations, Fish completion
└── tests/
    └── agents_test.sh      # Network-free agentic setup and idempotency test
```

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

What it reclaims: the `nvm.fish` Fisher plugin and `~/.local/share/nvm`, `~/.bun`, the `golang` dnf
package, the hand-installed `eza` in `/usr/local/bin`, the standalone `uv`, the dnf/COPR packages
mise now provides (zoxide, fzf, bat, ripgrep, fd-find, jq, chezmoi, neovim, starship, lazygit, gh),
the now-pointless `atim/starship` and `atim/lazygit` COPRs, and `~/anaconda3`.

SDKMan is **kept** — only its role narrows, from "Java and everything else JVM" to "everything else
JVM".

**If you skip the migration entirely, nothing breaks.** `mise activate` prepends its shims to PATH,
so the mise-managed tools already win over the leftovers. The script only reclaims disk and removes
the ambiguity.

---

## Planned Work

See [`../TODO.md`](../TODO.md) — Quickshell evaluation belongs to this tree, since it needs a real
Wayland compositor.
