#!/bin/sh
# install-i18n.sh — installs the translations of the scripts' messages (lib/i18n.sh,
# lib/void_legion_i18n.py and locale/; see docs/i18n.md):
#   bash install/install-i18n.sh          as the user: ~/.local/share/void-legion/{lib,locale}
#                                         (fish functions, ~/.local/bin programs, patch-still-needed)
#   sudo bash install/install-i18n.sh     for the system: /usr/local/share/void-legion and
#                                         /usr/local/lib/void-legion/i18n.sh (what the installers write
#                                         into /usr/local; they also do it themselves)
# Repeat it after pulling, if locale/ changed. Without it, every message is shown in English.
set -e
R=$(dirname "$(readlink -f "$0")"); until [ -f "$R/lib/common.sh" ] || [ "$R" = / ]; do R=$(dirname "$R"); done
. "$R/lib/common.sh"
if [ "$(id -u)" = 0 ]; then install_i18n_system; t "translations installed for the system"
else install_i18n_user; t "translations installed for %s" "$(id -un)"; fi
