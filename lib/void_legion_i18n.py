"""Message translation for the Python scripts of this repository (same catalogs as lib/i18n.sh).

    from void_legion_i18n import _
    print(_("Share screen"))
    print(_("opened with %s sources") % n)

Catalogs: <locale dir>/<language>/messages.po (gettext PO: msgid = English, msgstr = translation).
Language: LANGUAGE, LC_ALL, LC_MESSAGES or LANG (or LANG in /etc/locale.conf). Locale dirs, first
found: $VOID_LEGION_LOCALE_DIR, locale/ of the repository this file is in (it may be newer than the
installed copies), ~/.local/share/void-legion/locale, /usr/local/share/void-legion/locale.
The installers copy this module to ~/.local/share/void-legion/lib and /usr/local/share/void-legion/lib;
the scripts look for it there (or in the repository's lib/) and, if missing, show English.
Only what a person reads is translated; logs and tokens read by programs stay in English.
"""
import os

_CATALOG = None


def _lang():
    l = (os.environ.get("LANGUAGE") or os.environ.get("LC_ALL") or os.environ.get("LC_MESSAGES")
         or os.environ.get("LANG") or "")
    if not l:
        try:
            for line in open("/etc/locale.conf", encoding="utf-8"):
                if line.startswith("LANG="):
                    l = line.split("=", 1)[1].strip().strip('"')
        except OSError:
            pass
    l = l.split(":")[0]
    for sep in "_.@":
        l = l.split(sep)[0]
    return "" if l in ("", "C", "POSIX", "en") else l


def _unquote(s):
    s = s[1:-1]
    out, i = [], 0
    while i < len(s):
        c = s[i]
        if c == "\\" and i + 1 < len(s):
            i += 1
            c = {"n": "\n", "t": "\t"}.get(s[i], s[i])
        out.append(c)
        i += 1
    return "".join(out)


def _load():
    global _CATALOG
    _CATALOG = {}
    lang = _lang()
    if not lang:
        return
    here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    for d in (os.environ.get("VOID_LEGION_LOCALE_DIR", ""),
              os.path.join(here, "locale"),  # from a clone, its own catalog first (it may be newer)
              os.path.expanduser("~/.local/share/void-legion/locale"),
              "/usr/local/share/void-legion/locale"):
        p = os.path.join(d, lang, "messages.po") if d else ""
        if p and os.path.isfile(p):
            msgid = None
            for line in open(p, encoding="utf-8"):
                line = line.rstrip("\n")
                if line.startswith('msgid "'):
                    msgid = _unquote(line[6:])
                elif line.startswith('msgstr "') and msgid:
                    s = _unquote(line[7:])
                    if s:
                        _CATALOG[msgid] = s
            return


def _(msg):
    if _CATALOG is None:
        _load()
    return _CATALOG.get(msg, msg)
