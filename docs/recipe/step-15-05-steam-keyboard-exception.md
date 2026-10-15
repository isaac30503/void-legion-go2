### Steam's on-screen keyboard: exception in the window rules (2026-10-04)

Steam's keyboard (RT+X) is a Steam Xwayland window (`WM_CLASS` `"steamwebhelper",
"steam"`, title "Teclado en pantalla de Steam Input" ("Steam Input On-Screen Keyboard"), **`_NET_WM_WINDOW_TYPE_UTILITY`**; the
main window is `NORMAL`; read with `xprop` on `DISPLAY=:0`) and two labwc rules fell on it:
the `llena` (full) region of `identifier="*"` and the forced border of `identifier="steam"`. It is excepted **by
type**, which does not depend on the language, with a rule at the end of `<windowRules>` that undoes them:

```xml
<windowRule identifier="steam" type="utility">
  <action name="UnSnap"/>
  <action name="SetDecorations" decorations="none"/>
</windowRule>
```

In the common `rc.xml` (`common/xfce-wayland/labwc/rc.xml`, also on the IdeaPad), installed with
`mv` and reloaded with `kill -HUP $(pgrep -x labwc)` (= `labwc --reconfigure`). It applies to the
windows that open afterwards. Applied on both machines on 2026-10-04.

