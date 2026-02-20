# Shell aliases
# Auto-sourced by Fish from conf.d/

# ── File listing (eza replaces ls) ───────────────────────────────────────────
abbr -a ls  'eza --icons --group-directories-first'
abbr -a ll  'eza -la --icons --git --group-directories-first'
abbr -a la  'eza -la --icons --git --group-directories-first'
abbr -a lt  'eza --tree --icons -L 2 --group-directories-first'
abbr -a ltt 'eza --tree --icons -L 3 --group-directories-first'

# ── File reading (bat replaces cat) ──────────────────────────────────────────
abbr -a cat 'bat --paging=never'
abbr -a less 'bat'

# ── Navigation (zoxide) ───────────────────────────────────────────────────────
abbr -a cd 'z'

# ── Editor ────────────────────────────────────────────────────────────────────
abbr -a vim  'nvim'
abbr -a vi   'nvim'
abbr -a nano 'nvim'

# ── Search (ripgrep / fd) ─────────────────────────────────────────────────────
abbr -a grep 'rg'
abbr -a find 'fd'

# ── Git shortcuts ─────────────────────────────────────────────────────────────
abbr -a g    'git'
abbr -a gs   'git status'
abbr -a ga   'git add'
abbr -a gc   'git commit'
abbr -a gcm  'git commit -m'
abbr -a gca  'git commit --amend'
abbr -a gp   'git push'
abbr -a gpl  'git pull'
abbr -a gco  'git checkout'
abbr -a gb   'git branch'
abbr -a gl   'git log --oneline --graph --decorate -20'
abbr -a gd   'git diff'
abbr -a gds  'git diff --staged'

# ── Docker shortcuts ──────────────────────────────────────────────────────────
abbr -a d    'docker'
abbr -a dc   'docker compose'
abbr -a dps  'docker ps'
abbr -a dpsa 'docker ps -a'
abbr -a di   'docker images'
abbr -a dex  'docker exec -it'

# ── System ────────────────────────────────────────────────────────────────────
abbr -a update  'paru -Syu'
abbr -a install 'paru -S'
abbr -a search  'paru -Ss'
abbr -a remove  'paru -Rns'
abbr -a cleanup 'paru -Sc'

# ── Misc ──────────────────────────────────────────────────────────────────────
abbr -a reload 'source ~/.config/fish/config.fish'
abbr -a path   'echo $PATH | tr " " "\n"'
abbr -a ip     'ip -c addr'
abbr -a ports  'ss -tlnp'
