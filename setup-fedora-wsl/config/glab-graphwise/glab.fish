function glab --description 'GitLab CLI with an optional Graphwise profile'
    if test (count $argv) -gt 0; and test "$argv[1]" = --graphwise
        if not set -q WSL_DISTRO_NAME
            echo 'The Graphwise 1Password profile requires WSL.' >&2
            return 1
        end
        command "$HOME/.local/bin/glab-1password" $argv[2..-1]
        return $status
    end
    command glab $argv
end
