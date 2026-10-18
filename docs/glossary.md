# Glossary: original (Spanish) names → this repository's names

The original lived on the external disk in `Backups Linux/` and was written in Spanish. Here everything has
English names, and only those: the old Spanish arguments and options (`--quitar`, `juego`, `izq`…) are no
longer accepted (removed on 2026-10-13, the user's decision; before, they worked as aliases). The installers
still replace the old Spanish-named pieces on a system that already has them (`install/migrate.sh`). Archived
logs (in the private repository) keep their original names.

## Files (scripts and pieces)

| Original (`Backups Linux/…`) | In this repository |
|---|---|
| `fish/void/legion/pasos-1-a-3.sh` | `legion/steps-1-to-3.sh` |
| `fish/void/legion/avahi-solo-wifi.sh` | `legion/avahi-wifi-only.sh` |
| `fish/void/legion/wifi-sin-ahorro.sh` | `legion/wifi-no-powersave.sh` |
| `fish/void/legion/udev-red.sh` | `legion/udev-net.sh` |
| `fish/void/legion/escritorio-1-root.sh` | `legion/desktop-1-root.sh` |
| `fish/void/legion/escritorio-2-root.sh` | `legion/desktop-2-root.sh` |
| `fish/void/legion/grub-root.sh` | `legion/grub-root.sh` |
| `fish/void/legion/grub-oculto.sh` | `legion/grub-hidden.sh` |
| `fish/void/legion/brillo-al-despertar.sh` | `legion/brightness-on-wake.sh` |
| `fish/void/legion/como-steamos.sh` | `legion/like-steamos.sh` |
| `fish/void/legion/gpu-overdrive.sh` | `legion/gpu-overdrive.sh` |
| `fish/void/legion/microsd-al-arrancar.sh` | `legion/microsd-at-boot.sh` |
| `fish/void/legion/instalar-inputplumber.sh` | `legion/install-inputplumber.sh` |
| `fish/void/legion/inputplumber-udevadm` | `legion/inputplumber-udevadm` |
| `fish/void/legion/tdp/instalar-tdp.sh` | `legion/tdp/install-tdp.sh` |
| `fish/void/legion/diag/diag-inputplumber-cpu.sh` | `legion/diag/diag-inputplumber-cpu.sh` |
| `fish/void/legion/diag/diag-edp.sh` | `legion/diag/diag-edp.sh` |
| `fish/void/legion/diag/diag-gamescope-pipewire.sh` | `legion/diag/diag-gamescope-pipewire.sh` |
| `fish/void/legion/diag/diag-giroscopio.sh` | `legion/diag/diag-gyro.sh` |
| `fish/void/legion/diag/diag-giroscopio-mandos.sh` | `legion/diag/diag-controller-gyros.sh` |
| `fish/void/legion/diag/diag-monitor.sh` | `legion/diag/diag-monitor.sh` |
| `fish/void/legion/diag/diag-teclado-steam.sh` | `legion/diag/diag-steam-keyboard.sh` |
| `fish/void/legion/giro-mando-derecho.sh` | `legion/diag/right-controller-gyro.sh` |
| `fish/void/legion/probar-imu-mando.sh` | `legion/diag/test-controller-imu.sh` |
| `fish/void/legion/compartir-pantalla/compartir-pantalla` | `legion/screen-share/screen-share` |
| `fish/void/legion/compartir-pantalla/instalar.sh` | `legion/screen-share/install.sh` |
| `fish/void/legion/portal-wlr-parche/compilar-portal-wlr.sh` | `legion/portal-wlr-patch/build-portal-wlr.sh` |
| `fish/void/steam/instalar-modo-juego.sh` | `common/steam/install-game-mode.sh` |
| `fish/void/steam/instalar-cambio-sin-contrasena.sh` | `common/steam/install-passwordless-switch.sh` |
| `fish/void/steam/instalar-steam.sh` | `common/steam/install-steam.sh` |
| `fish/void/steam/instalar-decky.sh` | `common/steam/install-decky.sh` |
| `fish/void/steam/probar-sesion-directa.sh` | `common/steam/install-direct-session.sh` (`test-direct-session.sh` until 2026-10-17) |
| `fish/void/steam/probar-inicio-automatico.sh` | `common/diag/test-autologin.sh` |
| `fish/void/steam/greeter-sin-atspi.sh` | `common/steam/greeter-without-atspi.sh` |
| `fish/void/steam/capturar-avisos.sh` | `common/diag/capture-syslog.sh` |
| `fish/void/steam/diag-lightdm.sh` | `common/diag/diag-lightdm.sh` |
| `fish/void/steam/firefox-steam` | `common/steam/firefox-steam` |
| `fish/void/steam/xterm-steam` | `common/steam/xterm-steam` |
| `fish/void/steam/arte-xterm/generar.py` | `common/steam/art-xterm/generate.py` |
| `fish/void/steam/arte-vesktop/generar.py` | `common/steam/art-vesktop/generate.py` |
| `fish/void/steam/steamos-manager/instalar-steamos-manager.sh` | `common/steam/steamos-manager/install-steamos-manager.sh` |
| `fish/void/steam/steamos-manager/compilar-steamos-manager.sh` | `common/steam/steamos-manager/build-steamos-manager.sh` |
| `fish/void/steam/steamos-manager/diag-steamos-manager.sh` | `common/steam/steamos-manager/diag-steamos-manager.sh` |
| `fish/void/steam/portal-gamescope/instalar-portal-gamescope.sh` | `common/steam/portal-gamescope/install-portal-gamescope.sh` |
| `fish/void/steam/portal-gamescope/xdg-desktop-portal-gamescope-void` | `common/steam/portal-gamescope/xdg-desktop-portal-gamescope-void` |
| `fish/void/steam/gamescope-parche/compilar-gamescope.sh` | `common/steam/gamescope-patch/build-gamescope.sh` |
| `fish/void/xfce-wayland/instalar-xfce-wayland.sh` | `common/xfce-wayland/install-xfce-wayland.sh` |
| `fish/void/xfce-wayland/fondo-vigilante` | `common/xfce-wayland/wallpaper-watcher` |
| `fish/void/xfce-wayland/brillo` | `common/xfce-wayland/brightness` |
| `fish/void/xfce-wayland/tema-labwc.sh` | `common/xfce-wayland/labwc-theme.sh` |
| `fish/void/xfce-wayland/labwc/autostart` | `common/xfce-wayland/labwc/autostart` |
| `fish/void/xfce-wayland/labwc/environment` | `common/xfce-wayland/labwc/environment` |
| `fish/void/xfce-wayland/xfdesktop-fondo/compilar-xfdesktop.sh` | `common/xfce-wayland/xfdesktop-wallpaper/build-xfdesktop.sh` |
| `fish/void/xfce-wayland/xfdesktop-fondo/instalar-xfdesktop-fondo.sh` | `common/xfce-wayland/xfdesktop-wallpaper/install-xfdesktop-wallpaper.sh` |
| `fish/void/xfce-wayland/thunar-fondo/compilar-thunar.sh` | `common/xfce-wayland/thunar-wallpaper/build-thunar.sh` |
| `fish/void/xfce-wayland/thunar-fondo/instalar-thunar-fondo.sh` | `common/xfce-wayland/thunar-wallpaper/install-thunar-wallpaper.sh` |
| `fish/void/xfce/ventana-acoplar` | `common/xfce/window-snap` |
| `fish/void/xfce/ventana-foco` | `common/xfce/window-focus` |
| `fish/void/xfce/ventanas-nuevas` | `common/xfce/new-windows` |
| `fish/void/xterm/Xresources` | `common/xterm/Xresources` |
| `fish/void/xterm/xdg-terminal-exec` | `common/xterm/xdg-terminal-exec` |
| `fish/void/xterm/xprofile` | `common/xterm/xprofile` |
| `fish/void/xterm/jetbrains-blocks/patch_blocks.py` | `common/xterm/jetbrains-blocks/patch_blocks.py` |
| `fish/void/xterm/jetbrains-blocks/regenerar.sh` | `common/xterm/jetbrains-blocks/regenerate.sh` |
| `fish/void/grub-tema/construir.py` | `common/grub-theme/build.py` |
| `fish/void/grub-tema/instalar-tema.sh` | `common/grub-theme/install-theme.sh` |
| `fish/void/grub-tema/leer_pf2.py` | `common/grub-theme/read_pf2.py` |
| `fish/void/grub-tema/ttf2pf2.py` | `common/grub-theme/ttf2pf2.py` |
| `fish/void/arranque/arranque-silencioso.sh` | `common/boot/silent-boot.sh` |
| `fish/void/arranque/quitar-loading.py` | `common/boot/remove-loading.py` |
| `fish/void/arranque/instalar-plymouth.sh` | `common/boot/install-plymouth.sh` |
| `fish/void/arranque/plymouth-void/generar.py` | `common/boot/plymouth-void/generate.py` |
| `arranque/plymouth-void.sh` (2026-10-16, tested outside the repository) | `common/boot/install-plymouth.sh` |
| `fish/void/bluetooth/bluetooth-al-arrancar.sh` | `common/bluetooth/bluetooth-at-boot.sh` |
| `fish/void/fastfetch/gen-config.py` | `common/fastfetch/gen-config.py` |
| `fish/void/99-exec-fish.sh` | `common/shell/99-exec-fish.sh` |
| `fish/void/bashrc-bloque.sh` | `common/shell/bashrc-block.sh` |
| `fish/void/install-pkg.fish` | `common/fish/functions/install-pkg.fish` |
| `fish/void/remove-pkg.fish` | `common/fish/functions/remove-pkg.fish` |
| `fish/arch/brew/fish_prompt.fish` | `common/fish/functions/fish_prompt.fish` |
| `fish/arch/brew/fish_greeting.fish` | `common/fish/functions/fish_greeting.fish` |
| `fish/arch/brew/disk-ops.fish` | `common/fish/functions/disk-ops.fish` |
| `fish/void/audio-ctrl.fish` | `common/fish/functions/audio-ctrl.fish` |
| `fish/void/audio-priority.fish` | `common/fish/functions/audio-priority.fish` |
| `fish/void/update-system.fish` (fish function `update-system`) | `common/void-update/` (command `void-update`, since 2026-10-11; the old name is removed) |
| `fish/void/parche-sigue-haciendo-falta.sh` | `common/patch-test/patch-still-needed.sh` |
| `fish/void/instalar-prueba-parches.sh` | `common/patch-test/install-patch-test.sh` |
| `fish/void/agente/auditar-void.sh` | `common/agent/audit-void.sh` |
| `herramientas/ssh-setup.fish` | `common/ssh-setup/ssh-setup.fish` |
| `herramientas/ssh-survey.sh` | `common/ssh-setup/ssh-survey.sh` |
| `herramientas/LEEME-ssh-setup.md` | `docs/ssh-setup.md` |
| `fish/void/legion/registros-legion/` | private repository, `archive/2026-10-14/logs/legion/` |
| `fish/void/legion/diagnosticos-2026-10-04/` | private repository, `archive/2026-10-14/logs/legion-diagnostics-2026-10-04/` |
| `fish/void/steam/diag-lightdm.txt` | private repository, `archive/2026-10-14/logs/ideapad/diag-lightdm.txt` |
| `void-legion-go2.md` | `docs/void-legion-go2.md` (the index) and the pages by layers, `docs/1-platform/` … `docs/8-maintenance/` (since 2026-10-14; old step → page: the index's last table) |
| `void-ideapad-100.md (steps 1–15 and Troubleshooting)` | its content is in the pages by layers; the English copy, in the private repository's archive |
| `CLAUDE-void-legion.md` | private repository, `claude/CLAUDE-void-legion.md` |
| `claude-agentes/mantenedor-void.md (agent `mantenedor-void`)` | private repository, `claude/agents/void-maintainer.md` (agent `void-maintainer`) |
| `claude-memoria-legion/{MEMORY,receta-explicita,responder-en-espanol}.md` | private repository, `claude/memory/{MEMORY,explicit-recipe,answer-in-spanish}.md` |
| `TRASPASO-legion-live.md` | private repository, `archive/2026-10-14/history/handover-legion-live-2026-10-03.md` |
| `fish/void/fonts/*.ttf` | `common/fonts/ (Release asset)` |
| `fish/void/legion/compartir-pantalla/` | `legion/screen-share/` |
| `fish/void/legion/portal-wlr-parche/` | `legion/portal-wlr-patch/` |
| `fish/void/steam/gamescope-parche/` | `common/steam/gamescope-patch/` |
| `fish/void/xfce-wayland/xfdesktop-fondo/` | `common/xfce-wayland/xfdesktop-wallpaper/` |
| `fish/void/xfce-wayland/thunar-fondo/` | `common/xfce-wayland/thunar-wallpaper/` |
| `fish/void/steam/arte-xterm/, arte-vesktop/` | `common/steam/art-xterm/, art-vesktop/` |
| `fish/void/legion/steam/steam-segundo-plano.desktop` | `legion/steam/steam-background.desktop` |
| `fish/void/legion/steam/disposicion-escritorio-controller_steamos_handheld.vdf` | `legion/steam/desktop-layout-controller_steamos_handheld.vdf` |
| `fish/void/legion/steam/paquetes-instalados.txt` | `legion/steam/installed-packages.txt` |
| `fish/void/legion/xfce/panel/launcher-23/salir.desktop` | `legion/xfce/panel/launcher-23/exit.desktop` |
| `steam/steamos-manager/0001-gpu-set_clocks-solo-en-manual.patch` | `common/steam/steamos-manager/0001-gpu-set_clocks-only-in-manual.patch` |
| `fish/void/xfce/ventanas-nuevas.desktop` | `common/xfce/new-windows.desktop` |

## Names installed on the system

| Original | This repository |
|---|---|
| `/usr/local/bin/steam-modo-juego` | `/usr/local/bin/steam-game-mode` |
| `/usr/local/bin/steam-cargando` | `/usr/local/bin/steam-loading` |
| `/usr/local/lib/steam-modo-juego/bin/sudo` | `/usr/local/lib/steam-game-mode/bin/sudo` |
| `~/.local/state/steam-modo-juego.log` | `~/.local/state/steam-game-mode.log` |
| `/usr/share/xsessions/steam-modo-juego.desktop` | `/usr/share/xsessions/steam-game-mode.desktop` |
| `/usr/share/wayland-sessions/steam-modo-juego-directo.desktop` | `/usr/share/wayland-sessions/steam-game-mode-direct.desktop` |
| `/usr/share/applications/modo-juego.desktop` | `/usr/share/applications/game-mode.desktop` |
| `/usr/local/bin/cambiar-modo-root juego\|escritorio\|escritorio-x11 [--puede]` | `/usr/local/bin/switch-mode-root game\|desktop\|desktop-x11 [--check]` |
| `/etc/xdg/lightdm/lightdm.conf.d/60-modo-steam.conf` | `…/60-steam-mode.conf` |
| `/etc/sudoers.d/zz-cambiar-modo` | `/etc/sudoers.d/zz-switch-mode` |
| `/etc/runit/shutdown.d/05-cerrar-steam.sh` | `/etc/runit/shutdown.d/05-close-steam.sh` |
| `/run/apagando-sistema` | `/run/system-shutting-down` |
| `/usr/local/lib/cambiar-modo/reiniciar-lightdm` | `/usr/local/lib/switch-mode/restart-lightdm` |
| service `cambio-modo` (`sv once cambio-modo`)` | service `mode-switch`` |
| `/run/cambiar-modo.log` | `/run/switch-mode.log` |
| `/usr/local/bin/lightdm-greeter-envoltorio` | `/usr/local/bin/lightdm-greeter-wrapper` |
| `~/.local/bin/fondo-vigilante (log fondo-vigilante.log)` | `~/.local/bin/wallpaper-watcher (wallpaper-watcher.log)` |
| `~/.local/bin/brillo` | `~/.local/bin/brightness` |
| `~/.local/bin/ventana-acoplar izq\|der\|arr\|abj\|llena\|inicio` | `~/.local/bin/window-snap left\|right\|up\|down\|full\|home` |
| `~/.local/bin/ventana-foco izq\|der\|arr\|abj` | `~/.local/bin/window-focus left\|right\|up\|down` |
| `~/.local/bin/ventanas-nuevas` | `~/.local/bin/new-windows` |
| labwc region `llena`` | labwc region `full`` |
| `~/.local/bin/compartir-pantalla (rule {"steam": "pantalla"})` | `~/.local/bin/screen-share (RULES {"steam": "screen"})` |
| `/usr/share/applications/escritorio-wayland.desktop, escritorio-x11.desktop` | `…/desktop-wayland.desktop, desktop-x11.desktop` |
| service `udev-red` (/var/log/udev-red)` | service `udev-net` (/var/log/udev-net)` |
| `/etc/NetworkManager/conf.d/wifi-sin-ahorro.conf` | `…/wifi-no-powersave.conf` |
| `/etc/elogind/system-sleep/brillo, /run/brillo-al-despertar.log` | `…/brightness, /run/brightness-on-wake.log` |
| `/etc/sysctl.d/30-como-steamos.conf, limits.d/91-como-steamos.conf, rc.local block como-steamos` | `30-like-steamos.conf, 91-like-steamos.conf, block like-steamos` |
| `~/.config/autostart/steam-segundo-plano.desktop` | `~/.config/autostart/steam-background.desktop` |
| service `capturar-avisos`` | service `capture-syslog`` |
| `/run/decky-avisos` | `/run/decky-events` |
| `/usr/local/share/grub-tema, hooks 60-grub-tema` | `/usr/local/share/grub-theme, hooks 60-grub-theme` |
| `~/.local/bin/parche-sigue-haciendo-falta, ~/.local/share/update-system/parches` | `~/.local/bin/patch-still-needed, ~/.local/share/void-update/patches` |
| states HACE_FALTA / YA_INCLUIDO / PARCIAL / CONFLICTO / SIN_COMPROBAR; lines PARCHE / RESULTADO` | `STILL_NEEDED / ALREADY_INCLUDED / PARTIAL / CONFLICT / UNCHECKED; PATCH / RESULT` |
| `update-system --resumen`; summary OK / REPARADO / AVISO; `~/.local/state/update-system.last` | `void-update --summary`; OK / REPAIRED / WARNING (Spanish words with the Spanish catalog); `~/.local/state/void-update/last-update` |
| `/usr/local/share/{inputplumber,steamos-manager}-void/manifiesto, paquete` | `…/manifest, package` |
| `~/.cache/arte-vesktop-anterior` | `~/.cache/art-vesktop-previous` |
| options --quitar, --parar, --dejar, --deshacer, --sin-pantalla-de-carga, --conservar` | `--remove, --stop, --keep, --undo, --no-loading-screen, --keep` |
| `steps-1-to-3.sh ending "FIN OK"` | `"DONE OK"` |

Spanish labels of Steam, Xfce and Firefox menus are quoted in the documents as they appear on a Spanish system, with the English label in parentheses.
