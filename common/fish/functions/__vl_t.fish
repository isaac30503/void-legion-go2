# __vl_t FORMAT [ARG...] — translated message for the fish functions of this repository (same
# catalogs as lib/i18n.sh; see docs/i18n.md). Prints FORMAT (a printf format written in English)
# translated into the user's language, with a newline. Installed in ~/.config/fish/functions/.
# Only what a person reads is translated; tokens and lines read by programs stay in English.
function __vl_t --description 'Translated message (void-legion-go2 catalogs)'
    set -l fmt $argv[1]
    set -e argv[1]
    if not set -q __vl_t_catalog
        set -g __vl_t_catalog ''
        set -l l $LANGUAGE
        test -n "$l"; or set l $LC_ALL
        test -n "$l"; or set l $LC_MESSAGES
        test -n "$l"; or set l $LANG
        if test -z "$l"; and test -r /etc/locale.conf
            set l (string replace -r -f '^LANG=' '' < /etc/locale.conf | string trim -c '"')[1]
        end
        set l (string split -f1 ':' -- "$l")
        set l (string replace -r '[_.@].*' '' -- "$l")
        if test -n "$l"; and not contains -- $l C POSIX en
            for d in "$VOID_LEGION_LOCALE_DIR" ~/.local/share/void-legion/locale /usr/local/share/void-legion/locale
                if test -n "$d"; and test -r "$d/$l/messages.po"
                    set -g __vl_t_catalog "$d/$l/messages.po"
                    break
                end
            end
        end
    end
    if test -n "$__vl_t_catalog"
        set -l tr (awk -v key="$fmt" '
            function unquote(s,   out, i, c) {
                s = substr(s, 2, length(s) - 2); out = ""
                for (i = 1; i <= length(s); i++) {
                    c = substr(s, i, 1)
                    if (c == "\\\\" && i < length(s)) { i++; c = substr(s, i, 1); if (c == "n") c = "\n"; else if (c == "t") c = "\t" }
                    out = out c
                }
                return out
            }
            /^msgid "/  { id = unquote(substr($0, 7)); next }
            /^msgstr "/ { if (id == key) { s = unquote(substr($0, 8)); if (s != "") print s; exit } }
        ' $__vl_t_catalog)
        test -n "$tr"; and set fmt $tr
    end
    printf "$fmt\n" $argv   # (fish's printf takes no options: no "--")
end
