### Focus without raising: raise only on click (2026-10-06)

The user's request for both machines: focus follows the mouse, but the window **only comes to the front
with a click** (or with Alt+Tab, Super+arrows). In the common `rc.xml`, `<raiseOnFocus>no</raiseOnFocus>`
(before `yes`; clicks already focus and raise through the `mousebind`s of `<default/>`), and in xfwm4 (backup X11
session) `raise_on_focus` = `false` (`xfconf-query -c xfwm4 -p /general/raise_on_focus -s false`;
backed up in `legion/xfce/xfce-perchannel-xml/xfwm4.xml`). Applied live on 2026-10-06:
`rc.xml` copied with `mv` and labwc reloaded (`kill -HUP $(pgrep -x labwc)`, the same as `labwc
--reconfigure`). Detail in the IdeaPad recipe, step 13, *Foco* (*Focus*).

