function glab --description 'GitLab CLI with directory-based 1Password profiles'
    if set -q WSL_DISTRO_NAME
        command "$HOME/.local/bin/glab-1password" --auto $argv
        return $status
    end
    if test (count $argv) -gt 0; and contains -- "$argv[1]" --graphwise --profile
        echo 'The 1Password profiles require WSL.' >&2
        return 1
    end
    command glab $argv
end
