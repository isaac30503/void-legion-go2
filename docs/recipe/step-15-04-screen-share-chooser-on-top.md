### Screen-share chooser always on top (2026-10-07)

In the common `rc.xml`, at the end of `<windowRules>`:

```xml
<windowRule identifier="screen-share">
  <action name="ToggleAlwaysOnTop"/>
</windowRule>
```

The chooser (`~/.local/bin/screen-share`, step 14) sets that identifier with
`GLib.set_prgname`. With focus without raising it stayed behind Vesktop and the portal kept waiting for it.
Installed on both machines with `mv` and `kill -HUP $(pgrep -x labwc)`; on the IdeaPad it does nothing (there
is no chooser). **Verified by the user** (2026-10-07). The same rule also carries `<action
name="SetDecorations" decorations="none"/>` (no bar or buttons; the user's request, 2026-10-07).

