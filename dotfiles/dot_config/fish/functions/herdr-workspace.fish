function herdr-workspace --description "Create a Herdr workspace with the standard 7-tab layout"
    # ── The template ──────────────────────────────────────────────────────────
    # "Label:pane_count" — edit this list to change the layout. Tabs are created
    # in order; the first entry reuses the tab Herdr makes with the workspace.
    set -l tab_template \
        Research:2 \
        Implement:2 \
        Review:2 \
        nvim:1 \
        lazygit:1 \
        ollama:1 \
        shell:2

    argparse h/help -- $argv
    or return 1

    if set -q _flag_help
        echo "Usage: herdr-workspace [PATH]"
        echo ""
        echo "Creates a Herdr workspace labelled after PATH's directory name, with"
        echo "one tab per template entry, every pane rooted at PATH. PATH defaults"
        echo "to the current directory. Panes are shells — nothing is auto-started."
        echo ""
        echo "Tabs:"
        for spec in $tab_template
            set -l parts (string split ':' -- $spec)
            printf '  %-10s %s pane(s)\n' $parts[1] $parts[2]
        end
        return 0
    end

    if test (count $argv) -gt 1
        echo "❌ Too many arguments — expected at most one PATH." >&2
        return 2
    end

    # ── Preconditions ─────────────────────────────────────────────────────────
    if not command -q herdr
        echo "❌ herdr is not on PATH — run install.sh --agents." >&2
        return 1
    end

    if not command -q jq
        echo "❌ jq is not on PATH — it is mise-managed, run 'mise install'." >&2
        return 1
    end

    set -l target (pwd)
    if test (count $argv) -eq 1
        set target $argv[1]
    end

    if not test -d "$target"
        echo "❌ Not a directory: $target" >&2
        return 1
    end

    # Absolute and symlink-resolved, so the label and every pane cwd agree.
    set target (realpath "$target")
    set -l label (basename "$target")

    # Every subcommand below goes over the socket API, which needs a server.
    if not herdr workspace list >/dev/null 2>&1
        echo "❌ No Herdr server reachable — start Herdr first." >&2
        return 1
    end

    # ── Build ─────────────────────────────────────────────────────────────────
    echo "📁 Creating workspace '$label' at $target"

    set -l created (herdr workspace create --cwd "$target" --label "$label" --no-focus \
        | jq -r '.result.workspace.workspace_id, .result.tab.tab_id, .result.root_pane.pane_id')

    if test (count $created) -ne 3
        echo "❌ Failed to create workspace." >&2
        return 1
    end

    set -l workspace_id $created[1]
    set -l first_tab $created[2]
    set -l first_pane $created[3]

    set -l tab_index 0
    for spec in $tab_template
        set tab_index (math $tab_index + 1)
        set -l parts (string split ':' -- $spec)
        set -l tab_label $parts[1]
        set -l pane_count $parts[2]
        set -l pane_id

        if test $tab_index -eq 1
            # Creating the workspace already made a tab, labelled "1". Rename it
            # instead of creating an eighth tab nobody asked for.
            if not herdr tab rename $first_tab $tab_label >/dev/null
                echo "❌ Failed to label the first tab '$tab_label'." >&2
                return 1
            end
            set pane_id $first_pane
        else
            set pane_id (herdr tab create --workspace $workspace_id --cwd "$target" \
                --label $tab_label --no-focus | jq -r '.result.root_pane.pane_id')

            if test -z "$pane_id" -o "$pane_id" = null
                echo "❌ Failed to create tab '$tab_label'." >&2
                return 1
            end
        end

        # 'right' is the vertical split — the new pane sits beside its sibling.
        # Splitting the same pane each time keeps every extra pane in one row.
        for pane_number in (seq 2 $pane_count)
            if not herdr pane split --pane $pane_id --direction right \
                    --cwd "$target" --no-focus >/dev/null
                echo "❌ Failed to split a pane in '$tab_label'." >&2
                return 1
            end
        end

        printf '  ✅ %-10s %s pane(s)\n' $tab_label $pane_count
    end

    herdr workspace focus $workspace_id >/dev/null
    herdr tab focus $first_tab >/dev/null

    echo "🚀 Workspace '$label' ready."
end
