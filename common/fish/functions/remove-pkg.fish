function remove-pkg --description 'Search and remove installed packages with xbps using fzf'
    # From Omarchy's scripts (via Homebrew), adapted to Void (recipe, step 6). Its texts follow the
    # system's language (__vl_t). Previous name: remove-pkg (unchanged).
    functions -q __vl_t; or function __vl_t; printf "$argv[1]\n" $argv[2..-1]; end
    # Packages that cannot be removed from here: the base system, the kernel, the
    # boot loader, xbps itself, the graphical login and the desktop (xfce4 and
    # xorg-minimal are metapackages: with -R they would take the whole Xfce or the whole X11). The
    # Void installer marks them as "manually installed", so they show in the list;
    # removing one leaves the machine unable to boot or without desktop. If it is really needed,
    # xbps-remove by hand.
    set -l protected '^(base-system|linux|linux[0-9.]+|grub|grub-.*|xbps|lightdm|lightdm-.*|xfce4|xorg-minimal)$'

    # xbps-query -m: only what was installed by hand, without the dependencies it dragged
    # (equivalent to pacman -Qqe / brew leaves). The description comes from xbps-query -s '',
    # which lists what is installed as "[*] pkgver  description". The protected ones go with 🔒.
    set -l label (__vl_t 'alt-i: info, alt-f: files, alt-x: who depends, alt-j/k: scroll, tab: multi-select')
    set -l deps_title (string escape -- (__vl_t "Packages that depend on this one:"))
    set -l deps_none (string escape -- (__vl_t "(none)"))
    set -l pkg_selections (begin
            xbps-query -m | sed 's/-[^-]*$//'
            echo '--'
            xbps-query -s ''
        end | awk -v prot="$protected" '
            $0 == "--" { phase = 2; next }
            phase != 2 { manual[$0] = 1; next }
            {
                pv = $2; $1 = $2 = ""; sub(/^ +/, "")
                name = pv; sub(/-[^-]*$/, "", name)
                # Name padded to 28 columns after the tab: see install-pkg
                if (name in manual) printf "%s\t%-28s %s %s\n", name, name, (name ~ prot ? "🔒" : "  "), $0
            }' | fzf --multi \
                    --with-shell 'bash -c' \
                    --delimiter '\t' \
                    --with-nth 2 \
                    --preview 'xbps-query {1} 2>/dev/null' \
                    --preview-label="$label" \
                    --preview-label-pos='bottom' \
                    --preview-window 'down:65%:wrap' \
                    --bind 'alt-p:toggle-preview' \
                    --bind 'alt-d:preview-half-page-down,alt-u:preview-half-page-up' \
                    --bind 'alt-k:preview-up,alt-j:preview-down' \
                    --bind 'alt-i:change-preview:xbps-query {1} 2>/dev/null' \
                    --bind 'alt-f:change-preview:xbps-query -f {1} 2>/dev/null' \
                    --bind "alt-x:change-preview:echo $deps_title; xbps-query -X {1} 2>/dev/null | grep . || echo $deps_none" \
                    --color 'pointer:red,marker:red')

    # If nothing was selected, leave
    if test -z "$pkg_selections"
        return 0
    end

    set -l pkgs (string split -f1 \t -- $pkg_selections)

    # One by one: string match -r with the pattern's group would also return the capture
    set -l blocked
    set -l allowed
    for p in $pkgs
        if string match -qr -- $protected $p
            set -a blocked $p
        else
            set -a allowed $p
        end
    end
    if test -n "$blocked"
        set_color yellow
        __vl_t "🔒 Not removed from here (base system, kernel, boot, login or desktop): %s" "$blocked"
        set_color normal
        set pkgs $allowed
        if test -z "$pkgs"
            read -l -P (__vl_t "Press Enter to continue...") _pause
            return 1
        end
    end

    set_color red
    __vl_t "🗑 Packages to remove: %s" "$pkgs"
    set_color normal

    # -R also removes the dependencies nobody uses any more (like pacman -Rns). Without -y on
    # purpose: xbps shows the full list, dependencies included, and asks to confirm.
    # If another package depends on one of them, xbps refuses and says so.
    sudo xbps-remove -R $pkgs

    __vl_t "✓ Completed"
    read -l -P (__vl_t "Press Enter to continue...") _pause
end
