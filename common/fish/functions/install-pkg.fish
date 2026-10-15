function install-pkg --description 'Search and install packages with xbps using fzf'
    # From Omarchy's scripts (via Homebrew), adapted to Void (docs/8-maintenance/1-void-update.md). Its texts follow the
    # system's language (__vl_t, translations in ~/.local/share/void-legion). Previous name: install-pkg (unchanged).
    functions -q __vl_t; or function __vl_t; printf "$argv[1]\n" $argv[2..-1]; end
    # xbps-query -Rs '' lists the whole repo as "[*] pkgver  description" ([*] = already installed).
    # It is turned into "name<TAB>aligned-name ✓ description": fzf shows and searches only
    # what goes after the tab (--with-nth 2), and {1} stays as the clean name for the
    # previews. The name is padded to 28 columns (it covers 99 % of the repo) because
    # a visible tab is drawn by fzf at the next multiple of 8 and misaligns the list.
    # What is already installed is marked with ✓. It uses the repodata of the last sync.
    set -l label (__vl_t 'alt-i: info, alt-f: files, alt-p: toggle, alt-j/k: scroll, tab: multi-select')
    set -l pkg_selections (xbps-query -Rs '' | awk '{
                        st = $1; pv = $2; $1 = $2 = ""; sub(/^ +/, "")
                        name = pv; sub(/-[^-]*$/, "", name)
                        printf "%s\t%-28s %s %s\n", name, name, (st == "[*]" ? "✓" : " "), $0 }' | fzf --multi \
                    --with-shell 'bash -c' \
                    --delimiter '\t' \
                    --with-nth 2 \
                    --preview 'xbps-query -R {1} 2>/dev/null' \
                    --preview-label="$label" \
                    --preview-label-pos='bottom' \
                    --preview-window 'down:65%:wrap' \
                    --bind 'alt-p:toggle-preview' \
                    --bind 'alt-d:preview-half-page-down,alt-u:preview-half-page-up' \
                    --bind 'alt-k:preview-up,alt-j:preview-down' \
                    --bind 'alt-i:change-preview:xbps-query -R {1} 2>/dev/null' \
                    --bind 'alt-f:change-preview:xbps-query -R -f {1} 2>/dev/null' \
                    --color 'pointer:green,marker:green')

    # If nothing was selected, leave
    if test -z "$pkg_selections"
        return 0
    end

    # Keep only the name (first field before the tab)
    set -l pkgs (string split -f1 \t -- $pkg_selections)

    __vl_t "📦 Installing: %s" "$pkgs"
    # -S syncs the repodata before installing, so the most recent version is downloaded
    sudo xbps-install -S $pkgs

    __vl_t "✓ Completed"
    read -l -P (__vl_t "Press Enter to continue...") _pause
end
