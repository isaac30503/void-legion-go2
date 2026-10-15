# Firefox

## On the desktop

labwc gives Firefox only its border ([windows](../5-desktop/3-windows-and-shortcuts.md)), so **"Barra de título"
("Title Bar") must be unchecked** (☰ → Más herramientas → Personalizar barra de herramientas… / More tools → Customize
toolbar…). It is Firefox's default (`browser.tabs.inTitlebar` = 2, automatic); only an old restored profile may have it
checked. Default browser: *Ajustes → General → Hacer predeterminado* (*Settings → General → Make Default*).

## As a game, in Game Mode

Added to Steam from its `.desktop`, in Game Mode it came out with a colored border, could be resized and could not go
back to full screen: there is no window manager in gamescope, and with "Title Bar" unchecked Firefox draws its own
frame. The wrapper **`firefox-steam`** fixes it:

```bash
install -m 755 "$B/common/steam/firefox-steam" ~/.local/bin/
```

In Steam, **with Firefox completely closed**: Firefox → ⚙ → Propiedades → Acceso directo → Destino (Properties →
Shortcut → Target) = `/home/<user>/.local/bin/firefox-steam`. It starts Firefox with
**`MOZ_GTK_TITLEBAR_DECORATION=system`** (no own frame: none at all in gamescope) and, only when
`XDG_CURRENT_DESKTOP=gamescope`, waits **event-driven** for its window (`xdotool search --sync --onlyvisible --class
firefox`) and sizes the main windows to the screen (`xdotool windowsize 100% 100%`, at 0,0). F11 still gives real full
screen. Its library art: chosen with Decky's SteamGridDB ([library art](../6-game-mode/6-library-art.md)).

**Traps:** if Firefox is already open, `firefox` only opens a window in that process (with its frame): close it
completely first. If the screen changes with Firefox open, its window keeps the old size: close and open. To fix an
already shrunk window without closing: `DISPLAY=:1 xdotool windowsize <id> 100% 100% windowmove <id> 0 0`
(`xdotool search --class firefox`).
