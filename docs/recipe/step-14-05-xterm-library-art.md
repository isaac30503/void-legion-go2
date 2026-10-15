### xterm library art (2026-10-04)

As in SteamOS (§13.7 of its recipe), with a generator now saved:
**`common/steam/art-xterm/generate.py`** (without root; it uses `rsvg-convert`, the system's `python3-Pillow`
—no venv needed here— and `fc-match` for the font). Papirus's xterm icon
(`utilities-x-terminal.svg`) rasterized at 1024 px, centered on a radial gradient + halo + scan
lines, and "XTERM" in JetBrainsMono Nerd Font Mono bold, Super Game Bro palette. It looks in
`shortcuts.vdf` for the shortcut whose `Exe` contains `xterm`, takes its **unsigned** `appid`
(`appid & 0xFFFFFFFF`: here `-178361309` → `4116605987`) and writes in
`~/.local/share/Steam/userdata/@STEAM_ACCOUNT_ID@/config/grid/`: `<appid>p.png` (600×900), `<appid>.png`
(920×430), `<appid>_hero.png` (1920×620), `<appid>_logo.png` (1200×400, transparent),
`<appid>_icon.png` (512×512) and `<appid>.json` (logo bottom left, 50 %).
**Quick menu icon:** it comes from the `icon` field of `shortcuts.vdf`, not from `grid/`: the generator
puts there `~/.local/share/icons/steam-shortcuts/xterm-color-256.png` (Papirus at 256 px), **only with
Steam closed** (otherwise Steam overwrites it on exit; it warns with `!!` and it has to be repeated), with a copy
`shortcuts.vdf.bak`.
```bash
cp "$B/common/steam/art-xterm/generate.py" ~/steam/art-xterm/
python3 "$B/common/steam/art-xterm/generate.py"      # with Steam closed (on the desktop), and then open Steam
```
Check: in the library, xterm with cover, banner and logo; in the quick menu, its icon.
**What was done here (2026-10-04):** the art, with the generator with Steam open (it shows after
restarting Steam); the **icon**, from Steam's own interface, without closing it: *xterm →
Propiedades → Acceso directo* (*Properties → Shortcut*) → click on the icon box → choose
`~/.local/share/icons/steam-shortcuts/xterm-color-256.png` (Steam saves it itself in
`shortcuts.vdf`). The generator with Steam closed is the alternative. **Verified by the user.**

