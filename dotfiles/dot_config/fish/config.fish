# Fish shell configuration
# Managed by Chezmoi — edit source at setup-cachy-os/dotfiles/.config/fish/config.fish

# ── 1Password SSH agent ───────────────────────────────────────────────────────
# Enables use of SSH keys stored in 1Password without any keys on disk
set -gx SSH_AUTH_SOCK "$HOME/.1password/agent.sock"

# ── Starship prompt ───────────────────────────────────────────────────────────
if command -q starship
    starship init fish | source
end

# ── Zoxide (smart cd) ─────────────────────────────────────────────────────────
if command -q zoxide
    zoxide init fish | source
end

# ── SDKMan ────────────────────────────────────────────────────────────────────
# Add all installed SDKMan candidates (java, maven, gradle, …) to PATH.
# This makes `java`, `mvn`, `gradle` etc. available without any extra step.
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
# Go binaries
fish_add_path "$HOME/go/bin"

# Rust/Cargo binaries
fish_add_path "$HOME/.cargo/bin"

# Local user binaries
fish_add_path "$HOME/.local/bin"

# Anaconda (only if installed, and NOT auto-activated)
# Uncomment if you want conda in PATH without auto-activating base env:
# fish_add_path "$HOME/anaconda3/bin"

# ── Editor ────────────────────────────────────────────────────────────────────
set -gx EDITOR nvim
set -gx VISUAL nvim

# ── Bat theme ─────────────────────────────────────────────────────────────────
# Using a built-in bat theme. For Catppuccin: install `catppuccin-bat` from AUR,
# run `bat cache --build`, then change this to "Catppuccin Mocha".
set -gx BAT_THEME TwoDark

# ── FZF defaults ──────────────────────────────────────────────────────────────
set -gx FZF_DEFAULT_COMMAND "fd --type f --hidden --follow --exclude .git"
set -gx FZF_DEFAULT_OPTS "--height 40% --layout=reverse --border --color=bg+:#313244,spinner:#f5e0dc,hl:#f38ba8,fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc,marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8"

# ── Zellij ────────────────────────────────────────────────────────────────────
# Uncomment to auto-launch Zellij on terminal open (attach or new session)
if command -q zellij; and not set -q ZELLIJ
    zellij attach --create main
end
