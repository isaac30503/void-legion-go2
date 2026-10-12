# shellcheck shell=bash
# news.sh — Void's news (https://voidlinux.org/atom.xml), the equivalent of cachy-update's Arch news: before
# updating, the news published since the last update are shown (some ask for a manual step, e.g. 2026-03-10,
# "Changes to linux-firmware may require manual intervention"). The feed is read as data (python3 -I,
# xml.etree); nothing of it is run.

VU_NEWS_URL=https://voidlinux.org/atom.xml

# vu_fetch_news: "epoch<TAB>YYYY-MM-DD<TAB>title<TAB>link" per entry, newest first; 1 without network
vu_fetch_news() {
    local f; f=$(mktemp)
    if ! curl -fsSL --max-time "$check_timeout" -o "$f" "$VU_NEWS_URL" 2>/dev/null; then rm -f "$f"; return 1; fi
    python3 -I - "$f" <<'PY'
import sys, xml.etree.ElementTree as ET
from datetime import datetime
ns = {"a": "http://www.w3.org/2005/Atom"}
rows = []
for e in ET.parse(sys.argv[1]).getroot().findall("a:entry", ns):
    title = (e.findtext("a:title", "", ns) or "").strip().replace("\t", " ")
    link = e.find("a:link", ns); link = link.get("href") if link is not None else ""
    when = e.findtext("a:published", "", ns) or e.findtext("a:updated", "", ns)
    try: d = datetime.fromisoformat(when.replace("Z", "+00:00"))
    except ValueError: continue
    rows.append((int(d.timestamp()), d.strftime("%Y-%m-%d"), title, link))
for r in sorted(rows, reverse=True): print("\t".join(map(str, r)))
PY
    local rc=$?; rm -f "$f"; return $rc
}

# vu_news [N]: the latest N news (void-update --news); the ones after the last update, marked "new"
vu_news() {
    local n=${1:-$news_count} since rows ts day title link
    since=$(cat "$VU_STATE/last-update" 2>/dev/null || echo 0)
    rows=$(vu_fetch_news) || { err "Could not read Void's news (%s)" "$VU_NEWS_URL"; return 1; }
    step "Void news"
    printf '%s\n' "$rows" | head -n "$n" | while IFS=$'\t' read -r ts day title link; do
        if [ "$ts" -gt "$since" ]; then printf '  %s  %s%s%s  %s\n' "$day" "$c_bold" "$title" "$c_off" "${c_yellow}$(t "(new)")${c_off}"
        else printf '  %s  %s\n' "$day" "$title"; fi
        printf '              %s\n' "$link"
    done
}

# vu_news_before_update: in a full update, the news published since the last update (or of the last 30
# days, the first time). It only shows them: the question of the update comes right after.
vu_news_before_update() {
    [ "$news" = true ] || return 0
    local since rows new
    since=$(cat "$VU_STATE/last-update" 2>/dev/null || echo $(( $(date +%s) - 30*86400 )))
    rows=$(vu_fetch_news) || { warn "Could not read Void's news (%s)" "$VU_NEWS_URL"; return 0; }
    new=$(printf '%s\n' "$rows" | awk -F'\t' -v s="$since" '$1 > s')
    if [ -z "$new" ]; then info "No Void news since the last update"; return 0; fi
    echo
    step "Void news since the last update:"
    printf '%s\n' "$new" | while IFS=$'\t' read -r _ day title link; do
        printf '  %s  %s%s%s\n              %s\n' "$day" "$c_bold" "$title" "$c_off" "$link"
    done
    info "Some news ask for a manual step before or after updating: read them (links above) before answering"
}
