#!/bin/bash
# secrets.sh — keeps local.env (the private values, never in git as plain text) as local.env.age: encrypted with
# age and a passphrase, stored in a PRIVATE companion repository (<owner>/void-legion-go2-private), never in this
# public one (2026-10-14: the standard practice for public repositories is not to publish personal data even
# encrypted; it had been here, and was removed from the history). With the passphrase and the GitHub account,
# everything can be rebuilt (docs/sanitization.md, "Encrypted copy").
#
#   bash install/secrets.sh seal      local.env → local.env.age, uploaded to the private repository
#                                     (asks the passphrase twice, and once more to check the copy)
#   bash install/secrets.sh open      the private repository's local.env.age → local.env (asks the passphrase)
#   bash install/secrets.sh status    whether local.env and the private copy say the same (exit 0) or not (exit 1)
#
# The private repository: $VOID_LEGION_SECRETS_REPO, or this clone's origin with "-private" (gh, logged in).
# The passphrase is typed on the terminal and never written anywhere: keep it in a password manager and on
# paper. local.env.age next to local.env is only a cache (git-ignored). A git-ignored stamp (.local.env.stamp:
# sha256 of local.env and of the copy after the last seal/open) tells which one changed afterwards.
# 2026-10-13, the user's decision: age with a passphrase (not sops, git-crypt or GPG keys).
set -euo pipefail
R=$(dirname "$(readlink -f "$0")"); until [ -f "$R/lib/common.sh" ] || [ "$R" = / ]; do R=$(dirname "$R"); done
. "$R/lib/common.sh"
need_user
cd "$REPO_ROOT"
ENV=local.env; AGE=local.env.age; STAMP=.local.env.stamp
SR=${VOID_LEGION_SECRETS_REPO:-$(git remote get-url origin 2>/dev/null | sed -E 's#^(https://github.com/|git@github.com:)##; s#\.git$##')-private}
API="repos/$SR/contents/$AGE"

hash_of() { [ -f "$1" ] && sha256sum "$1" | cut -d' ' -f1 || echo -; }
stamp()   { printf '%s %s\n' "$(hash_of $ENV)" "$(hash_of $AGE)" > $STAMP; }
need_age() { command -v age >/dev/null || { t "!! age is not installed: sudo xbps-install -S age"; exit 1; }; }
need_gh()  { command -v gh >/dev/null && gh auth status >/dev/null 2>&1 || { t "!! gh is needed, logged in (gh auth login): the copy is in the private repository %s" "$SR"; exit 1; }; }
# fetch FILE: the private repository's copy into FILE (returns 1 if there is none)
fetch() { gh api "$API" --jq .content 2>/dev/null | base64 -d > "$1" 2>/dev/null && [ -s "$1" ]; }

seal() {
    need_age; need_gh
    [ -s $ENV ] || { t "!! %s is missing: nothing to encrypt" "$ENV"; exit 1; }
    t "Encrypting %s → %s. Passphrase: long (4-5 random words), the same as before if there was one; keep it in your password manager and on paper." "$ENV" "$AGE"
    umask 077
    age -p -a -o $AGE.tmp $ENV || { rm -f $AGE.tmp; t "!! not encrypted"; exit 1; }
    t "Type the passphrase once more, to check the copy:"
    age -d $AGE.tmp | cmp -s - $ENV || { rm -f $AGE.tmp; t "!! the check failed (another passphrase?): nothing was changed"; exit 1; }
    local sha
    sha=$(gh api "$API" --jq .sha 2>/dev/null || true)
    gh api -X PUT "$API" -f message="local.env.age: $(date +%F)" -f content="$(base64 -w0 $AGE.tmp)" ${sha:+-f sha="$sha"} \
        -f committer[name]="$(git config user.name)" -f committer[email]="$(git config user.email)" >/dev/null \
        || { rm -f $AGE.tmp; t "!! the upload to %s failed: nothing was changed" "$SR"; exit 1; }
    mv -f $AGE.tmp $AGE; stamp
    t "   done: %s, in the private repository %s" "$AGE" "$SR"
}

open_() {
    need_age; need_gh
    umask 077
    fetch $AGE.new || { rm -f $AGE.new; t "!! %s has no %s yet (bash install/secrets.sh seal)" "$SR" "$AGE"; exit 1; }
    mv -f $AGE.new $AGE
    age -d -o $ENV.tmp $AGE || { rm -f $ENV.tmp; t "!! not decrypted (wrong passphrase?)"; exit 1; }
    if [ -f $ENV ] && ! cmp -s $ENV $ENV.tmp; then
        old=$ENV.old-$(date +%s); mv -f $ENV "$old"
        t "   the previous %s was different: kept as %s (compare them: diff %s %s)" "$ENV" "$old" "$old" "$ENV"
    fi
    mv -f $ENV.tmp $ENV; chmod 600 $ENV; stamp
    t "   done: %s" "$ENV"
}

status() {
    if [ ! -f $ENV ]; then t "!! %s is missing: bash install/secrets.sh open" "$ENV"; return 1; fi
    if ! command -v gh >/dev/null || ! gh auth status >/dev/null 2>&1; then
        t "   unchecked: gh is not logged in (the copy is in %s)" "$SR"; return 0
    fi
    local tmp; tmp=$(mktemp); trap 'rm -f "$tmp"' RETURN
    if ! fetch "$tmp"; then t "!! %s has no %s yet: bash install/secrets.sh seal" "$SR" "$AGE"; return 1; fi
    if [ ! -f $STAMP ]; then
        t "   unknown whether %s and the copy say the same (no stamp): bash install/secrets.sh open (it keeps the current one aside if it differs)" "$ENV"
        return 0
    fi
    read -r s_env s_age < $STAMP
    e=$(hash_of $ENV); a=$(hash_of "$tmp")
    if [ "$e" = "$s_env" ] && [ "$a" = "$s_age" ]; then t "   %s and the private copy say the same" "$ENV"; return 0; fi
    if [ "$e" != "$s_env" ] && [ "$a" = "$s_age" ]; then t "!! %s changed after the last copy: bash install/secrets.sh seal" "$ENV"; return 1; fi
    if [ "$e" = "$s_env" ]; then t "!! the private copy is newer (sealed on the other machine): bash install/secrets.sh open"; return 1; fi
    t "!! both changed: bash install/secrets.sh open (it keeps the current %s aside), merge by hand, then seal" "$ENV"
    return 1
}

case "${1:-}" in
    seal)   seal ;;
    open)   open_ ;;
    status) status ;;
    *)      printf '  %-36s %s\n' "bash install/secrets.sh seal" "$(t "local.env → local.env.age, uploaded to the private repository (asks the passphrase)")" \
                    "bash install/secrets.sh open" "$(t "the private repository's local.env.age → local.env (asks the passphrase)")" \
                    "bash install/secrets.sh status" "$(t "whether local.env and the private copy say the same (exit 0) or not (exit 1)")"
            exit 1 ;;
esac
