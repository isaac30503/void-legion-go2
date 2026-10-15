## 4. SSH access in both directions

**On the IdeaPad** (`~/.ssh/config`): `Host lego` → `HostName Legion-Go-Gen-2.local`, **`User
isaac`** (formerly `deck`). On reinstall, the host key changes:
`ssh-keygen -R Legion-Go-Gen-2.local`.

**On the Legion** (without root):

```bash
ssh-keygen -q -t ed25519 -N "" -C "isaac@Legion-Go-Gen-2" -f ~/.ssh/id_ed25519
cp "$B/legion/ssh-config" ~/.ssh/config && chmod 600 ~/.ssh/config   # Host ideapad, msi and deck
cat ~/.ssh/id_ed25519.pub        # add this line to the IdeaPad's ~/.ssh/authorized_keys
```

On the IdeaPad the old key `deck@Legion-Go-Gen-2` was **replaced** (its private part went away with
SteamOS) by the new `isaac@Legion-Go-Gen-2` (2026-10-03; `authorized_keys.bak` next to it).
Check from the Legion: `ssh ideapad hostname` → `ideapad-100`.

