# macOS — Post-Install Setup

Modular, idempotent post-install scripts for **macOS** (Apple Silicon or Intel), built on Homebrew.

It gives the Mac the same environment as the Linux directories in this repo: Ghostty with the
JetBrainsMono Nerd Font, Fish + Starship, the shared mise tool manifest, LazyVim and the agent CLIs.
Only the system layer differs.

> **No secrets in this repo.** SSH keys are managed by 1Password. Git credentials and tokens are
> injected at runtime via `op run` — never stored here.

---

## Prerequisites

- macOS 13 Ventura or later
- An admin account (Homebrew, `/etc/shells` and `chsh` need `sudo`)
- Xcode Command Line Tools — `--base` opens their installer if they are missing; re-run once
  it finishes

Nothing else: the scripts run under the bash 3.2 that ships with macOS, and `--base` installs
Homebrew itself.

---

## Quick Start

```bash
git clone https://github.com/YOUR_USER/linux-dev-env.git ~/workspace/linux-dev-env
cd ~/workspace/linux-dev-env/setup-macos

# Run everything at once
bash install.sh --all
```

`op` (1Password CLI) is installed by `--base`, so secret injection works from the second run on:

```bash
op run --env-file=~/.op-env -- bash install.sh --update
```

On the very first run, `--base` prompts for your Git name and email instead.

---

## 1Password Secret Injection

Create `~/.op-env` (**not in this repo**) with references to your 1Password vault:

```bash
# ~/.op-env  (git-ignored, managed by 1Password)
GIT_USER_NAME=op://Private/Git/username
GIT_USER_EMAIL=op://Private/Git/email
```

For SSH keys: enable **1Password → Settings → Developer → Use the SSH agent**. `config.fish` points
`SSH_AUTH_SOCK` at `~/.1password/agent.sock`, the Linux path; on macOS `--base` symlinks that path to
1Password's real socket in `~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock`, as
1Password's own docs suggest, so the shared config works unchanged.

---

## Usage

```
bash install.sh [flags]

Steps:
  --all        Run all steps (base → mise → langs → apps → dotfiles → agents)
  --base       System layer: Homebrew, Ghostty, JetBrainsMono Nerd Font, Fish + Fisher,
               1Password + CLI, Docker Desktop, Git config
  --mise       mise + every tool pinned in dotfiles/dot_config/mise/config.toml
  --langs      C/C++ build tools, Rust (rustup), SDKMan, pynvim venv
  --apps       Zed, VS Code, JetBrains Toolbox
  --dotfiles   Apply dotfiles via Chezmoi
  --agents     Install Claude Code, Codex, OpenCode, Herdr, and integrations

Maintenance:
  --update     Update everything installed (not part of --all)
  --repos SET  Also clone workspace/repos-SET.txt (repeatable)
  -h, --help   Show help
```

Flags are composable: `bash install.sh --base --mise --langs`

`--claude` is currently a no-op while the skills are being rewritten.

---

## The Two Layers

| Layer | Owner | What |
|-------|-------|------|
| **System** | Homebrew | Ghostty, Fish (the login shell, so it must be a real path in `/etc/shells`), 1Password, Docker Desktop, build tools, GUI apps |
| **Tools** | `mise` | node, go, java, bun, python, erlang, elixir, uv, neovim, and the CLI tools — bat, chezmoi, eza, fd, fzf, gh, glab, jq, k9s, kind, lazygit, ripgrep, starship, zoxide |

The mise manifest — [`dotfiles/dot_config/mise/config.toml`](../dotfiles/dot_config/mise/config.toml)
— is the same file every Linux directory uses, so a version change lands identically on the Mac.

---

## What Gets Installed

### `--base` (packages/base.sh)

| Tool | Source | Notes |
|------|--------|-------|
| Homebrew | official installer | Skipped when `/opt/homebrew` or `/usr/local` already has it |
| Ghostty | cask `ghostty` | Reads `~/.config/ghostty/config`, written by `--dotfiles` |
| JetBrains Mono Nerd Font | `../fonts/` | Copied to `~/Library/Fonts` — the family the Ghostty config names |
| 1Password + `op` | casks `1password`, `1password-cli` | Plus the `~/.1password/agent.sock` symlink |
| fish | `brew` | Set as login shell with `chsh`, so Ghostty opens Fish |
| Fisher + fzf.fish / bass / sponge | Fisher | Fish plugins |
| Docker Desktop | cask `docker-desktop` | Docker engine in a Linux VM, with the `docker` CLI, compose and buildx |
| htop / btop | `brew` | System utilities |

**Docker Desktop licence:** free for personal use, education and small companies. Work use at a
company with more than 250 employees or $10M in revenue needs a paid Docker subscription.

### `--mise` (packages/mise.sh)

Installs mise from Homebrew, so mise itself upgrades with `brew upgrade`, then every tool in the
shared manifest. It also installs `autoconf` and `openssl@3` and points kerl at that OpenSSL, in
case Erlang has to compile from source.

### `--langs` (packages/languages.sh)

| Kept out of mise | Why |
|------------------|-----|
| C/C++ | clang, lldb and make come with the Xcode Command Line Tools; `brew` adds cmake, ninja, ccache, pkgconf. No gdb — it does not run on Apple Silicon |
| Rust (rustup) | Official `sh.rustup.rs` installer; clippy / rustfmt / rust-analyzer are rustup components |
| SDKMan | Kept for kotlin, scala, maven, gradle, springboot. **The JDK itself comes from mise.** Needs bash 4+, so `--langs` installs Homebrew bash and runs the SDKMan installer with it |
| pynvim venv | `~/.nvim-venv` for Neovim's Python provider — uv's job |

### `--apps` (packages/apps.sh)

| App | Source | Notes |
|-----|--------|-------|
| Zed | cask `zed` | |
| VS Code | cask `visual-studio-code` | |
| JetBrains Toolbox | cask `jetbrains-toolbox` | Installs and updates the IDEs |

Any app already in `/Applications` is skipped, whether or not Homebrew installed it. Raycast is
not part of this step; it is installed by hand.

### `--dotfiles` (../dotfiles/)

Applied via Chezmoi from the shared `dotfiles/` directory: Fish, Starship, Neovim (LazyVim),
Ghostty, mise, Herdr (and Alacritty, which is unused on the Mac). Two parts of the Fish config are
macOS-aware:

- `config.fish` puts Homebrew on PATH (`brew shellenv fish`); Fish does not read `/etc/zprofile`.
- `aliases.fish` maps `ip` and `ports` to `ifconfig` and `lsof` instead of iproute2.

### `--agents` (packages/agents.sh)

Identical to every Linux directory: Claude Code, OpenAI Codex CLI, OpenCode and Herdr from their
official native installers (all of them support macOS), plus Herdr's integrations and Fish
completion.

### `--update`

`brew update && brew upgrade` (formulae and casks) → `mise up` → `rustup update` → `fisher update` →
`chezmoi apply` → lazy.nvim sync → agent CLI self-updates → `softwareupdate --list`, with a
confirmation before installing (some macOS updates restart the machine).

---

## After Running

**Ghostty / Fish:** quit and reopen Ghostty. It starts your login shell, which is now Fish, with
Starship and the Catppuccin Mocha theme.

**1Password:** turn on the SSH agent (see above), then check with `ssh -T git@github.com`.

**Docker:** open Docker.app once to accept its terms and start the engine, then
`docker run hello-world` to check end to end.

**GitHub CLI:** `gh auth login`

**Neovim:** run `nvim` — LazyVim auto-bootstraps and installs all plugins on first launch.

---

## Repository Structure

```
setup-macos/
├── install.sh              # Master orchestrator
├── lib/
│   └── utils.sh            # Shared logging & Homebrew helpers (bash 3.2-safe)
├── packages/
│   ├── base.sh             # System layer: Homebrew, Ghostty, fonts, Fish, 1Password, Docker Desktop, Git
│   ├── mise.sh             # mise + the shared tool manifest
│   ├── languages.sh        # C/C++ build tools, Rust (rustup), SDKMan, pynvim
│   ├── apps.sh             # Zed, VS Code, JetBrains Toolbox
│   ├── claude.sh           # Claude Code config symlinks
│   └── agents.sh           # AI agents, Herdr, integrations, Fish completion
└── tests/
    └── agents_test.sh      # Network-free agentic setup and idempotency test
```

There is no `migrate-legacy.sh` and no `--gaming`: the Mac never had the pre-mise setup, and the
gaming stack is Linux-only.
