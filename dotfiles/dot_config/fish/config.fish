# Fish shell configuration
# Managed by Chezmoi — edit source at dotfiles/dot_config/fish/config.fish

# ── 1Password SSH agent ───────────────────────────────────────────────────────
# Enables use of SSH keys stored in 1Password without any keys on disk
set -gx SSH_AUTH_SOCK "$HOME/.1password/agent.sock"

# ── SDKMan ────────────────────────────────────────────────────────────────────
# Java itself comes from mise (see ~/.config/mise/config.toml). SDKMan is kept
# for its other candidates — kotlin, scala, maven, gradle, springboot — which
# mise does not manage here.
#
# Ordering matters: this block runs BEFORE `mise activate` below, so mise's
# shims end up ahead of SDKMan's candidate paths and mise's JDK wins for `java`.
if test -d "$HOME/.sdkman/candidates"
    for candidate_bin in $HOME/.sdkman/candidates/*/current/bin
        if test -d "$candidate_bin"
            fish_add_path "$candidate_bin"
        end
    end
end

# `sdk` command wrapper via bass (install, use, list, etc.)
if functions -q bass; and test -s "$HOME/.sdkman/bin/sdkman-init.sh"
    function sdk
        bass source "$HOME/.sdkman/bin/sdkman-init.sh" ';' sdk $argv
    end
end

# ── PATH additions ────────────────────────────────────────────────────────────
# Go module binaries (`go install ...`). The Go toolchain itself is from mise.
fish_add_path "$HOME/go/bin"

# Rust/Cargo binaries — rustup stays outside mise (mise's `rust` delegates to
# rustup anyway, and clippy/rustfmt/rust-analyzer are per-toolchain components).
fish_add_path "$HOME/.cargo/bin"

# Local user binaries — agent CLIs (claude, codex, opencode, herdr) land here
fish_add_path "$HOME/.local/bin"
fish_add_path "$HOME/.opencode/bin"

# ── mise (tool version manager) ───────────────────────────────────────────────
# Must come after the fish_add_path calls above so mise's shims take precedence.
# Manages: node, go, java, bun, python, uv, neovim and the CLI tools.
if command -q mise
    mise activate fish | source
end

# ── Tool initialisation ───────────────────────────────────────────────────────
# EVERYTHING that shells out to a mise-managed binary must live BELOW the
# `mise activate` above. These blocks are all guarded by `command -q`, so if
# they run too early the guard is simply false and the block silently no-ops —
# no error, just a missing `z` or a default prompt. Add new tool init here, not
# at the top of the file.
if command -q zoxide
    zoxide init fish | source
end

if command -q starship
    starship init fish | source
end

# ── Editor ────────────────────────────────────────────────────────────────────
set -gx EDITOR nvim
set -gx VISUAL nvim

# ── Bat theme ─────────────────────────────────────────────────────────────────
set -gx BAT_THEME TwoDark

# ── FZF defaults ──────────────────────────────────────────────────────────────
set -gx FZF_DEFAULT_COMMAND "fd --type f --hidden --follow --exclude .git"
set -gx FZF_DEFAULT_OPTS "--height 40% --layout=reverse --border --color=bg+:#313244,spinner:#f5e0dc,hl:#f38ba8,fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc,marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8"
