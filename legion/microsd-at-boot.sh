#!/bin/sh
# Legion Go 2: the microSD (Steam library from the SteamOS days) ALWAYS mounted at boot,
# also when booting straight into Game Mode (there is no desktop session there to mount it).
# Previous (Spanish) name: microsd-al-arrancar.sh.
#   sudo sh legion/microsd-at-boot.sh            # with Steam CLOSED
#   sudo sh legion/microsd-at-boot.sh --remove   # undoes it (with Steam closed)
# - /etc/fstab (leaves fstab.bak): UUID → /mnt/microsd, ext4, with "nofail": on Void, if "mount -a"
#   fails at boot, /etc/runit/core-services/03-filesystems.sh opens the emergency console;
#   with nofail, if the card is not there it boots anyway. fsck pass 0 (as when udisks mounted it).
#   x-gvfs-show: it still shows in Thunar.
# - Steam kept the library with the path the session gave it (/run/media/<user>/<UUID>): it is
#   changed to /mnt/microsd in its two libraryfolders.vdf, as the user did (Steam closed: otherwise it
#   rewrites them on exit). docs/2-base-system/3-storage.md (2026-10-05).
# The card's UUID is MICROSD_UUID in local.env.
set -e
R=$(dirname "$(readlink -f "$0")"); until [ -f "$R/lib/common.sh" ] || [ "$R" = / ]; do R=$(dirname "$R"); done
. "$R/lib/common.sh"
need_root
need_env MICROSD_UUID
UUID=$MICROSD_UUID
MOUNTPOINT=/mnt/microsd
U=$TARGET_USER
OLDPATH=/run/media/$U/$UUID
VDF="$TARGET_HOME/.local/share/Steam/config/libraryfolders.vdf $TARGET_HOME/.local/share/Steam/steamapps/libraryfolders.vdf"
FSTAB_COMMENT="# Legion microSD (Steam library), always at boot; nofail: it boots anyway without it"
FSTAB_COMMENT_OLD="# microSD de la Legion"       # the comment written by the previous (Spanish) version

if pgrep -u "$U" -x steam >/dev/null; then
    t "Steam is open: close it (Steam menu → Exit) and repeat."; exit 1
fi
change_vdf() {   # $1 → $2 in the paths of the Steam libraries
    for f in $VDF; do
        [ -f "$f" ] || continue
        sudo -u "$U" sed -i "s#\"path\"\t\t\"$1\"#\"path\"\t\t\"$2\"#" "$f"
        echo "$f:"; grep -n '"path"' "$f"
    done
}

if is_remove "${1:-}"; then
    mountpoint -q "$MOUNTPOINT" && umount "$MOUNTPOINT"
    cp /etc/fstab /etc/fstab.bak
    sed -i "/^# Legion microSD/d; /^$FSTAB_COMMENT_OLD/d; /^UUID=$UUID /d" /etc/fstab
    rmdir "$MOUNTPOINT" 2>/dev/null || true
    change_vdf "$MOUNTPOINT" "$OLDPATH"
    t "removed: the desktop session will mount it again in %s" "$OLDPATH"; cat /etc/fstab; exit 0
fi

[ "$(blkid -s TYPE -o value "/dev/disk/by-uuid/$UUID" 2>/dev/null)" = ext4 ] ||
    { t "I cannot find the microSD (%s, ext4): is it in?" "$UUID"; exit 1; }

# 1. fstab
if grep -q "^UUID=$UUID " /etc/fstab; then
    t "fstab already has it"
    # A line written by the previous (Spanish) version: its comment, in English (same line, same place)
    if grep -q "^$FSTAB_COMMENT_OLD" /etc/fstab; then
        cp /etc/fstab /etc/fstab.bak
        sed -i "s|^$FSTAB_COMMENT_OLD.*|$FSTAB_COMMENT|" /etc/fstab
        t "fstab: its comment brought to the new version"
    fi
else
    cp /etc/fstab /etc/fstab.bak
    printf '%s\n%s\n' "$FSTAB_COMMENT" \
        "UUID=$UUID $MOUNTPOINT ext4 defaults,noatime,nofail,x-gvfs-show 0 0" >> /etc/fstab
fi
cat /etc/fstab

# 2. mount it right away in its place (if the session had it mounted elsewhere, it is released)
mkdir -p "$MOUNTPOINT"
for m in $(findmnt -n -o TARGET -S "UUID=$UUID"); do
    [ "$m" = "$MOUNTPOINT" ] || { t "unmounting %s" "$m"; umount "$m"; }
done
mountpoint -q "$MOUNTPOINT" || mount "$MOUNTPOINT"
findmnt "$MOUNTPOINT"

# 3. Steam: the library, at the new path
change_vdf "$OLDPATH" "$MOUNTPOINT"
t "Done. Open Steam: Storage must show the microSD with its games."
