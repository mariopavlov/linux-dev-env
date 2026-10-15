function workspace-repos --description "Export or restore the workspace git repos via a manifest"
    set -l root (set -q GHQ_ROOT; and echo $GHQ_ROOT; or echo $HOME/workspace)

    # The manifest lives in linux-dev-env, wherever that is checked out: the
    # ghq location first, then the legacy ~/workspace/linux-dev-env.
    set -l manifest
    for candidate in \
            $root/github.com/mariopavlov/linux-dev-env/workspace/repos.txt \
            $root/linux-dev-env/workspace/repos.txt
        if test -f $candidate
            set manifest $candidate
            break
        end
    end
    set -q WORKSPACE_MANIFEST; and set manifest $WORKSPACE_MANIFEST

    switch "$argv[1]"
        case export
            if test -z "$manifest"
                echo "❌ No manifest found. Set WORKSPACE_MANIFEST to its path." >&2
                return 1
            end

            # Every repo under the root. Matching .git *directories* skips git
            # worktrees (their .git is a file); projects/ holds those anyway.
            set -l urls
            set -l kept
            for repo in (fd -H -I -t d '^\.git$' $root --prune --exclude projects | path dirname | sort)
                # Skip repos nested inside another repo (caches, vendored
                # clones); sorting puts the parent first.
                if test -n "$kept"; and string match -q -- "$kept/*" $repo
                    continue
                end
                set kept $repo
                set -l url (git -C $repo remote get-url origin 2>/dev/null)
                if test -z "$url"
                    echo "⚠️  No origin remote, skipped: $repo" >&2
                    continue
                end
                set -a urls $url
            end

            begin
                echo "# Workspace repositories — one clone URL per line."
                echo "# Restore: workspace-repos restore   (clones into \$GHQ_ROOT/<host>/<path>)"
                echo "# Export:  workspace-repos export    (rewrites this file from disk)"
                echo
                printf '%s\n' $urls | sort -u
            end >$manifest
            echo "✅ Wrote "(count (printf '%s\n' $urls | sort -u))" repos to $manifest"

        case restore
            if test -z "$manifest"
                echo "❌ No manifest found. Set WORKSPACE_MANIFEST to its path." >&2
                return 1
            end
            if not command -q ghq
                echo "❌ ghq not found — run 'mise install' first." >&2
                return 1
            end

            echo "📦 Restoring from $manifest into $root"
            # Existing repos are reported as 'exists' and left untouched.
            string match -rv '^\s*(#|$)' <$manifest | GHQ_ROOT=$root ghq get --parallel

        case '*'
            echo "Usage: workspace-repos export|restore"
            echo
            echo "  export   scan \$GHQ_ROOT for git repos and rewrite the manifest"
            echo "  restore  clone every manifest repo missing from \$GHQ_ROOT (via ghq)"
            echo
            echo "Manifest: "(test -n "$manifest"; and echo $manifest; or echo "(not found)")
            test "$argv[1]" = -h -o "$argv[1]" = --help
    end
end
