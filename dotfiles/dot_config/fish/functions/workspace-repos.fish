function workspace-repos --description "Clone the workspace repos listed in linux-dev-env manifests"
    # Thin wrapper around linux-dev-env/workspace/clone.sh (also used by
    # install.sh --update), found through ghq so it works from any folder.
    switch "$argv[1]"
        case update
            set -l repo (ghq list -p -e github.com/mariopavlov/linux-dev-env)
            if test -z "$repo"
                echo "❌ linux-dev-env not found under "(ghq root) >&2
                return 1
            end
            bash $repo/workspace/clone.sh $argv[2..-1]

        case '*'
            echo "Usage: workspace-repos update [personal|graphwise|all]..."
            echo
            echo "  Clone the repos listed in the chosen manifests that are missing"
            echo "  under "(ghq root)". Existing repos are left alone. Default: personal."
            echo
            echo "  personal   workspace/repos.txt"
            echo "  graphwise  workspace/repos-graphwise.txt"
            echo "  all        every manifest"
            test "$argv[1]" = -h -o "$argv[1]" = --help
    end
end
