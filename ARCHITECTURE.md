# Idle clock → login UI — necessary code

Slick Greeter is a GTK 3 / Vala LightDM greeter (Meson build).  
Your fork already contains this work in commit `5836a38` (“Modernized UI”).  
This folder is the **complete set of files that actually change** versus upstream [linuxmint/slick-greeter](https://github.com/linuxmint/slick-greeter), plus two small fixes.

Do **not** rewrite `user-list.vala`, `greeter-list.vala`, PAM/session code, or replace Slick Greeter with a web greeter.

---

## 1. What controls the main greeter UI

| Piece | File | Role |
|---|---|---|
| Process entry, LightDM daemon, GTK theme | `src/slick-greeter.vala` | Unchanged. `SlickGreeter.show_prompt` is the PAM prompt signal. |
| Top-level window, keyboard, monitors | `src/main-window.vala` | **Modified.** Owns IDLE / LOGIN state. |
| Wallpaper | `src/background.vala` | Unchanged. `Gtk.Fixed` parent of overlay + login box. |
| Large clock + dim overlay | `src/idle-clock-overlay.vala` | **New.** |
| User list / password dash | `src/user-list.vala`, `src/greeter-list.vala`, `src/prompt-box.vala`, `src/dash-entry.vala` | Unchanged. Hidden/shown by fading `content_box`. |
| Power / a11y / network / session | `src/menubar.vala`, `src/shutdown-dialog.vala`, `src/session-list.vala` | Unchanged. Stay available. |
| Settings schema | `data/x.dm.slick-greeter.gschema.xml`, `src/settings.vala` | **Modified.** |
| Build | `src/meson.build` | **Modified** — add the new `.vala` file. |
| Existing animation helper | `src/animate-timer.vala` | Unchanged. Reused (~350 ms ease-in-out). |

Widget tree after the change:

```
MainWindow
└── Background (Gtk.Fixed)
    ├── IdleClockOverlay     # dim + large clock  (progress 0→1)
    └── login_box (Gtk.Box, full monitor)
        ├── menubar          # power / a11y / hostname — always visible
        └── content_box      # user list + password  (opacity 0 while idle)
```

---

## 2. Where keyboard input is handled

`MainWindow.key_press_event` is the single greeter-wide key handler.

Flow:

```
key press
  ├─ meaningful key while IDLE?  → enter LOGIN, start transition, focus list
  ├─ password field not ready?   → buffer the character, consume the event
  ├─ existing hidden-user / session / Escape / arrows / F10 / Power
  └─ base.key_press_event        → focused Gtk.Entry gets the key
```

Ignored as activation (no login UI): Shift, Ctrl, Alt, Super, Caps/Num/Scroll Lock, Escape, F1–F12, Print, PowerOff, and any key with Ctrl/Alt/Super.

Escape while LOGIN returns to IDLE (and still cancels authentication, same as upstream).

**First character:** if PAM has not created the `Gtk.Entry` yet, the character is stored in `pending_login_text` and flushed on the next `show_prompt` **and** on an `Idle` after activation. If the entry already has focus, the key is not buffered and GTK delivers it normally.

---

## 3. Where clock / background / login widgets are created

- Wallpaper: `new Background()` in `MainWindow.construct`, drawn in `Background.draw_full`.
- Idle clock + dim: `new IdleClockOverlay()` added to `background` **before** `login_box` so the form paints on top of the dim.
- Login form: existing `UserList` pushed onto `ListStack` inside `content_box`.
- Menubar clock: still `menubar.vala` / `show-clock`. For a single large clock, set `show-clock=false` (see `slick-greeter.conf.example`).

---

## 4. How the build system works

Meson + Vala, GTK 3, liblightdm-gobject.

```bash
meson setup build
ninja -C build
# test without replacing the system greeter:
sudo ./build/src/slick-greeter --test-mode
```

`src/meson.build` must list `idle-clock-overlay.vala` in `slick_greeter_sources`.

After install, compile schemas:

```bash
sudo glib-compile-schemas /usr/share/glib-2.0/schemas
```

Do not overwrite the distro package until `--test-mode` works. Keep a TTY recovery path.

---

## 5. Files to copy into the tree

Replace / add these paths in the slick-greeter source tree:

```
src/idle-clock-overlay.vala          NEW
src/main-window.vala                 REPLACE
src/settings.vala                    REPLACE
src/meson.build                      REPLACE
data/x.dm.slick-greeter.gschema.xml  REPLACE
```

Optional:

```
slick-greeter.conf.example  →  /etc/lightdm/slick-greeter.conf
```

No other source files need to change.

---

## 6. State machine

```
IDLE  --meaningful key-->  LOGIN_TRANSITION  -->  LOGIN
LOGIN --Escape / cancel--> IDLE_TRANSITION   -->  IDLE
```

Driven by `login_presentation_progress` in `[0, 1]`, animated with `AnimateTimer.ease_in_out`.

| | IDLE (0) | LOGIN (1) |
|---|---|---|
| Large clock | centered, opacity `idle-clock-opacity` | ~28% from top, opacity `login-clock-opacity` |
| Dim overlay | 0 | `login-background-dim-opacity` |
| `content_box` | opacity 0, insensitive | opacity 1, sensitive |
| Slide | login UI 24 px lower | in place |

---

## 7. Configuration keys

| Key | Type | Default | Meaning |
|---|---|---|---|
| `idle-clock-enabled` | bool | true | Master switch. `false` = stock Slick Greeter. |
| `idle-clock-opacity` | double 0–1 | 0.34 | Clock while idle |
| `login-clock-opacity` | double 0–1 | 0.22 | Clock after login UI appears |
| `login-background-dim-opacity` | double 0–1 | 0.36 | Wallpaper dim |
| `login-transition-duration` | int 0–1000 | 350 | Animation ms |
| `clock-format` | string | `%H:%M` | Existing key, reused |

Set them in `/etc/lightdm/slick-greeter.conf` under `[Greeter]` (overrides dconf).

---

## 8. Fixes included here vs the GitHub commit

1. First typed characters are flushed on activation, not only on the next PAM `show_prompt` (avoids a stuck buffer if the entry already exists).
2. Once a `Gtk.Entry` has focus, keys go to it instead of being re-buffered.
3. Hidden login UI is `sensitive = false` so clicks cannot hit an invisible password field.
4. Overlay uses `set_has_window (false)` so it cannot steal input.
