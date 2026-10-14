# shellcheck shell=sh
# lib/i18n.sh — message translation for the shell scripts of this repository (POSIX sh: works in
# sh/dash and bash). Sourced by the scripts in the repository and installed as
# /usr/local/lib/void-legion/i18n.sh for the scripts that the installers write into the system.
#
#   t FORMAT [ARG...]   prints FORMAT (a printf format written in English) translated into the
#                       user's language, followed by a newline. Without a catalog for the language,
#                       or without an entry for FORMAT, it prints the English text.
#
# Catalogs: <locale dir>/<language>/messages.po (gettext PO format: msgid = the English text,
# msgstr = the translation). Language: LANGUAGE, LC_ALL, LC_MESSAGES or LANG; when running through
# sudo with an empty environment, the system's LANG from /etc/locale.conf (Void sets it there).
# Locale dirs, first found: $VOID_LEGION_LOCALE_DIR, the repository's locale/ (when running from a clone: it may be
# newer than the installed copies), ~/.local/share/void-legion/locale, /usr/local/share/void-legion/locale.
# How to add a language: docs/i18n.md.
#
# Rules followed by the scripts: only what a person reads is translated (progress, questions,
# summaries, windows). What programs or the documentation read back (service logs, status tokens
# such as STILL_NEEDED, lines that are grepped) is always English and never goes through t.
# Literal "%" in a FORMAT is written "%%"; paths with backslashes go as %s arguments, never in FORMAT.

_i18n_lang() {
    _l=${LANGUAGE:-${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}}
    if [ -z "$_l" ] && [ -r /etc/locale.conf ]; then
        _l=$(sed -n 's/^LANG=//p' /etc/locale.conf | tr -d '"' | head -n1)
    fi
    _l=${_l%%:*}; _l=${_l%%[_.@]*}
    case "$_l" in ""|C|POSIX|en) echo "" ;; *) echo "$_l" ;; esac
}

_i18n_catalog() {
    _lang=$(_i18n_lang)
    [ -n "$_lang" ] || return 0
    _here=""
    # The repository's locale/ when this file is sourced from a clone (I18N_REPO_DIR set by common.sh).
    [ -n "${I18N_REPO_DIR:-}" ] && _here="$I18N_REPO_DIR/locale"
    # From a clone, its own catalog first (it may be newer than the installed copies)
    for _d in "${VOID_LEGION_LOCALE_DIR:-}" "$_here" "${HOME:-/nonexistent}/.local/share/void-legion/locale" \
              /usr/local/share/void-legion/locale; do
        [ -n "$_d" ] && [ -r "$_d/$_lang/messages.po" ] && { echo "$_d/$_lang/messages.po"; return 0; }
    done
    return 0    # no catalog: English (and never a failure, for scripts with set -e)
}

# Looked up once per script run.
_I18N_CAT=${_I18N_CAT-$(_i18n_catalog)}

t() {
    _f=$1; shift
    if [ -n "$_I18N_CAT" ]; then
        _tr=$(awk -v key="$_f" '
            function unquote(s,   out, i, c) {
                s = substr(s, 2, length(s) - 2); out = ""
                for (i = 1; i <= length(s); i++) {
                    c = substr(s, i, 1)
                    if (c == "\\" && i < length(s)) { i++; c = substr(s, i, 1); if (c == "n") c = "\n"; else if (c == "t") c = "\t" }
                    out = out c
                }
                return out
            }
            /^msgid "/  { id = unquote(substr($0, 7)); next }
            /^msgstr "/ { if (id == key) { s = unquote(substr($0, 8)); if (s != "") print s; exit } }
        ' "$_I18N_CAT")
        [ -n "$_tr" ] && _f=$_tr
    fi
    # shellcheck disable=SC2059   # the format is the (translated) message itself
    printf -- "$_f\n" "$@"
}
