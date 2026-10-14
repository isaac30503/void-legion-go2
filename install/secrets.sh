#!/bin/bash
# secrets.sh — keeps local.env (the private values, never in git as plain text) as local.env.age: encrypted with
# age and a passphrase, committed to the repository. With the passphrase and the GitHub account, the clone is
# enough to rebuild everything (docs/sanitization.md, "Encrypted copy").
#
#   bash install/secrets.sh seal      local.env → local.env.age (asks the passphrase twice; then commit it)
#   bash install/secrets.sh open      local.env.age → local.env (asks the passphrase; chmod 600)
#   bash install/secrets.sh status    whether both say the same (exit 0) or which one is newer (exit 1)
#
# The passphrase is typed on the terminal and never written anywhere: keep it in a password manager and on
# paper. A git-ignored stamp (.local.env.stamp: sha256 of both files after the last seal/open) tells which one
# changed afterwards; without it (e.g. a fresh clone that already has local.env) the state is "unknown".
# 2026-10-13, the user's decision: age with a passphrase (not sops, git-crypt or GPG keys).
set -euo pipefail
R=$(dirname "$(readlink -f "$0")"); until [ -f "$R/lib/common.sh" ] || [ "$R" = / ]; do R=$(dirname "$R"); done
. "$R/lib/common.sh"
need_user
cd "$REPO_ROOT"
ENV=local.env; AGE=local.env.age; STAMP=.local.env.stamp

hash_of() { [ -f "$1" ] && sha256sum "$1" | cut -d' ' -f1 || echo -; }
stamp()   { printf '%s %s\n' "$(hash_of $ENV)" "$(hash_of $AGE)" > $STAMP; }
need_age() {
    command -v age >/dev/null || { t "!! age is not installed: sudo xbps-install -S age"; exit 1; }
}

seal() {
    need_age
    [ -s $ENV ] || { t "!! %s is missing: nothing to encrypt" "$ENV"; exit 1; }
    t "Encrypting %s → %s. Passphrase: long (4-5 random words), the same as before if there was one; keep it in your password manager and on paper." "$ENV" "$AGE"
    umask 077
    age -p -a -o $AGE.tmp $ENV || { rm -f $AGE.tmp; t "!! not encrypted"; exit 1; }
    # Proof that the passphrase works and the copy is whole before replacing the old one
    t "Type the passphrase once more, to check the copy:"
    if age -d $AGE.tmp | cmp -s - $ENV; then
        mv -f $AGE.tmp $AGE; chmod 644 $AGE; stamp
        t "   done: %s (commit it: git add %s && git commit)" "$AGE" "$AGE"
    else
        rm -f $AGE.tmp; t "!! the check failed (another passphrase?): %s was not changed" "$AGE"; exit 1
    fi
}

open_() {
    need_age
    [ -s $AGE ] || { t "!! %s is missing: it has not been encrypted yet (bash install/secrets.sh seal)" "$AGE"; exit 1; }
    umask 077
    age -d -o $ENV.tmp $AGE || { rm -f $ENV.tmp; t "!! not decrypted (wrong passphrase?)"; exit 1; }
    if [ -f $ENV ] && ! cmp -s $ENV $ENV.tmp; then
        old=$ENV.old-$(date +%s); mv -f $ENV "$old"
        t "   the previous %s was different: kept as %s (compare them: diff %s %s)" "$ENV" "$old" "$old" "$ENV"
    fi
    mv -f $ENV.tmp $ENV; chmod 600 $ENV; stamp
    t "   done: %s" "$ENV"
}

status() {
    if [ ! -f $AGE ]; then t "!! %s does not exist yet: bash install/secrets.sh seal" "$AGE"; return 1; fi
    if [ ! -f $ENV ]; then t "!! %s is missing: bash install/secrets.sh open" "$ENV"; return 1; fi
    if [ ! -f $STAMP ]; then
        t "   unknown whether %s and %s say the same (no stamp): bash install/secrets.sh open (it keeps the current one aside if it differs)" "$ENV" "$AGE"
        return 0
    fi
    read -r s_env s_age < $STAMP
    e=$(hash_of $ENV); a=$(hash_of $AGE)
    if [ "$e" = "$s_env" ] && [ "$a" = "$s_age" ]; then t "   %s and %s say the same" "$ENV" "$AGE"; return 0; fi
    if [ "$e" != "$s_env" ] && [ "$a" = "$s_age" ]; then t "!! %s changed after the last copy: bash install/secrets.sh seal" "$ENV"; return 1; fi
    if [ "$e" = "$s_env" ]; then t "!! %s is newer (it came with git pull): bash install/secrets.sh open" "$AGE"; return 1; fi
    t "!! both changed: bash install/secrets.sh open (it keeps the current %s aside), merge by hand, then seal" "$ENV"
    return 1
}

case "${1:-}" in
    seal)   seal ;;
    open)   open_ ;;
    status) status ;;
    *)      sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
