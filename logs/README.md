# Logs (archived, as they were)

Real output captured on the machines while the recipe was being made. **They are kept as they were**: in
Spanish where the scripts wrote Spanish then, with their **original file names** (the recipe cites them by
those names), and only the private values replaced by `@NAME@` ([`../docs/sanitization.md`](../docs/sanitization.md)).
Today's scripts write English logs with English names (`steps-1-to-3.log`…; see [`../docs/glossary.md`](../docs/glossary.md)).

| Folder | What |
|---|---|
| `legion/` | logs of the Legion's installation (originally `fish/void/legion/registros-legion/`): `pasos-1-a-3.log` (steps 2–3), `escritorio-1-root.log` / `escritorio-2-root.log` (steps 5–12), `grub-root.log` (step 8), `como-steamos.log` (step 14, SteamOS settings), the gamescope builds of 2026-10-07 and its PipeWire crash trace, controller and gyroscope tests (`diag-giroscopio-mandos.log`, `giro-mando-derecho.log`, `probar-imu-mando.log`) and the InputPlumber CPU measurements of 2026-10-08 (`medir-inputplumber-{escritorio,modojuego,modojuego-mando}-…`: desktop, Game Mode, Game Mode with controller) |
| `legion/etc-bak/` | copies of the Legion's `/etc` files before the scripts changed them (`fstab`, `rc.conf`, `default/grub`, `grub.d/10_linux`, lightdm, avahi), the `.bak` the scripts left |
| `legion-diagnostics-2026-10-04/` | diagnostics (originally `fish/void/legion/diagnosticos-2026-10-04/`): boot `dmesg`, internal screen state black/fine (`diag-edp-negra.txt` / `diag-edp-bien.txt`), steamos-manager, controller IMU, and two traces of the wlroots screen-share portal (2026-10-06) |
| `ideapad/` | `diag-lightdm.txt`: lightdm's log on the IdeaPad when the login screen took the console from gamescope (IdeaPad recipe, step 14, *What it cost* 2) |
