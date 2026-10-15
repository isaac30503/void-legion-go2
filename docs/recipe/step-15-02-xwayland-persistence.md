### Xwayland always alive: `xwaylandPersistence` (2026-10-06)

In the common `rc.xml`, inside `<core>`: `<xwaylandPersistence>yes</xwaylandPersistence>`. Without it,
labwc starts Xwayland on demand and closes it after 10 s without X programs (`Xwayland … -terminate`); what
the `autostart` loads with `xrdb` (`~/.Xresources`) was lost and xterm came out without a theme. **It was seen on the
IdeaPad** (detail in its recipe, step 15); **here it was not noticed** because Steam runs in the background on the
desktop (an X program) and keeps Xwayland alive; it would only happen when closing Steam completely. Put here
too (the same `rc.xml`) on 2026-10-06; it takes effect in the next desktop session (it changes when
labwc restarts). In Game Mode it does not apply (the Xwaylands are gamescope's). Check:
`grep -c xwaylandPersistence ~/.config/xfce4/labwc/rc.xml` → 1.

