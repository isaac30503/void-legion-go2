#!/bin/bash
# fetch-assets.sh — downloads the binaries of this repository's GitHub Release (packages built here,
# official binaries, fonts, themes; they are not in git) and puts each one where the scripts look for it,
# checking its sha256. The list, with the release tag, is install/assets.tsv.
#
#   bash install/fetch-assets.sh            downloads what is missing or does not match (without root)
#   bash install/fetch-assets.sh --check    only checks (exit 1 if something is missing or does not match)
#
# Public repository: a plain download with curl; if that fails (a private fork), the gh CLI (gh auth login) or curl and a
# token in GH_TOKEN. Repository: the "origin" remote of the clone, or VOID_LEGION_GITHUB=<owner>/<name>.
# A destination ending in "/" is a .tar.gz that is unpacked there (the 96 JetBrainsMono Nerd Font files).
# Previous location of these files: next to the scripts in "<disk>/Backups Linux/fish/void/" (Common).
set -euo pipefail
R=$(dirname "$(readlink -f "$0")"); until [ -f "$R/lib/common.sh" ] || [ "$R" = / ]; do R=$(dirname "$R"); done
. "$R/lib/common.sh"
CHECK=; [ "${1:-}" = --check ] && CHECK=1
LIST="$REPO_ROOT/install/assets.tsv"
TAG=$(sed -n 's/^# release: //p' "$LIST")
SLUG=${VOID_LEGION_GITHUB:-$(git -C "$REPO_ROOT" remote get-url origin 2>/dev/null | sed -E 's#^(https://github.com/|git@github.com:)##; s#\.git$##')}
DL=$(mktemp -d); trap 'rm -rf "$DL"' EXIT

download() {   # $1 = asset name → $DL/$1
    # A public repository: a plain download, no login (the sha256 is checked afterwards anyway)
    if curl -fsSL --retry 3 -o "$DL/$1" "https://github.com/$SLUG/releases/download/$TAG/$1" 2>/dev/null; then
        return 0
    elif command -v gh >/dev/null 2>&1; then
        # 3 attempts: GitHub sometimes answers "release not found" for a moment (seen 2026-10-13, fresh clone)
        local n; for n in 1 2 3; do
            gh release download "$TAG" -R "$SLUG" -p "$1" -D "$DL" --clobber >/dev/null && return 0
            [ $n = 3 ] || { t "   retrying %s (%s/3)" "$1" "$((n+1))"; sleep $((n*5)); }
        done
        return 1
    elif [ -n "${GH_TOKEN:-}" ]; then
        id=$(curl -fsSL -H "Authorization: Bearer $GH_TOKEN" "https://api.github.com/repos/$SLUG/releases/tags/$TAG" \
            | python3 -c 'import json,sys; n=sys.argv[1]; print(next(a["id"] for a in json.load(sys.stdin)["assets"] if a["name"]==n))' "$1")
        curl -fsSL -H "Authorization: Bearer $GH_TOKEN" -H "Accept: application/octet-stream" \
            -o "$DL/$1" "https://api.github.com/repos/$SLUG/releases/assets/$id"
    else
        t "!! neither gh (gh auth login) nor GH_TOKEN: the private release cannot be downloaded"; exit 1
    fi
}

bad=0
while IFS=$'\t' read -r name sum dest; do
    case "$name" in ''|'#'*) continue ;; esac
    if [ "${dest%/}" != "$dest" ]; then
        # unpacked: the mark keeps the sha256 of the .tar.gz it came from
        mark="$REPO_ROOT/$dest.asset-sha256"
        [ "$(cat "$mark" 2>/dev/null)" = "$sum" ] && { t "   ok        %s" "$dest"; continue; }
    else
        [ -f "$REPO_ROOT/$dest" ] && [ "$(sha256sum "$REPO_ROOT/$dest" | cut -d' ' -f1)" = "$sum" ] \
            && { t "   ok        %s" "$dest"; continue; }
    fi
    if [ -n "$CHECK" ]; then t "!! missing   %s" "$dest"; bad=1; continue; fi
    [ -n "$SLUG" ] || { t "!! unknown repository: set VOID_LEGION_GITHUB=<owner>/<name>"; exit 1; }
    download "$name"
    [ "$(sha256sum "$DL/$name" | cut -d' ' -f1)" = "$sum" ] || { t "!! wrong sha256: %s" "$name"; exit 1; }
    if [ "${dest%/}" != "$dest" ]; then
        mkdir -p "$REPO_ROOT/$dest"; tar xzf "$DL/$name" -C "$REPO_ROOT/$dest"
        echo "$sum" > "$REPO_ROOT/$dest.asset-sha256"
    else
        mkdir -p "$(dirname "$REPO_ROOT/$dest")"; mv "$DL/$name" "$REPO_ROOT/$dest"
        case "$dest" in *.so) chmod 755 "$REPO_ROOT/$dest" ;; esac
    fi
    t "   fetched   %s" "$dest"
done < "$LIST"
exit $bad
