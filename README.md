# Slick Greeter Personalized

> A modern, minimal LightDM login experience built by extending Slick Greeter with an idle clock, keyboard-triggered login UI, smooth transitions, and background dimming.

![Slick Greeter Personalized](docs/screenshots/login-screen.png)

## Overview

**Slick Greeter Personalized** is a customized fork of [Linux Mint's Slick Greeter](https://github.com/linuxmint/slick-greeter).

The goal is simple: make the login screen feel less like a traditional login form and more like a minimal, modern lock screen.

Instead of showing the complete login interface immediately, the greeter starts with a large, subtle clock. When the user begins interacting with the keyboard, the login interface smoothly appears while the clock moves upward and the background becomes darker.

```text
                 IDLE
                   │
                   │ keyboard input
                   ▼
          ┌─────────────────┐
          │    TRANSITION   │
          │                 │
          │  Clock moves ↑  │
          │  Background ↓  │
          │  Login fades in │
          └────────┬────────┘
                   │
                   ▼
                 LOGIN
```

The underlying Slick Greeter and LightDM authentication architecture is retained rather than replaced.

---

## ✨ What Changed

### 🕐 1. Minimal Idle Clock

When the greeter starts, the login interface is visually hidden and the clock becomes the main focus.

The clock:

- is large and centered;
- uses a light font weight;
- remains intentionally subtle;
- uses Slick Greeter's existing `clock-format` setting;
- updates every second;
- remains over the existing wallpaper.

The current implementation uses a dedicated `IdleClockOverlay` GTK drawing widget.

---

### ⌨️ 2. Login Appears When You Start Typing

The user does not need to click a login field before interacting.

Meaningful keyboard input activates the login presentation.

Examples include:

```text
a
hello
123
@
Enter
Backspace
Tab
Arrow keys
```

Modifier-only keys such as:

```text
Shift
Ctrl
Alt
Super
Caps Lock
Num Lock
Scroll Lock
```

do not independently activate the login presentation.

Command-style modifier combinations are also excluded from the activation path.

---

### 🎬 3. Animated Login Transition

The transition between the idle and login states is animated.

During the transition:

```text
              IDLE

             23:31
               │
               │
               ▼

        background dims
               +
        clock moves upward
               +
        login UI fades in
               +
        login UI slides into place

               ▼

              LOGIN
```

The transition uses the existing GTK/GLib/Vala architecture and the project's `AnimateTimer` rather than introducing a separate animation framework.

The transition duration is configurable.

---

### 🌑 4. Background Dimming

The original wallpaper is not replaced.

Instead, a translucent black overlay is gradually applied as the login interface becomes visible.

Conceptually:

```text
IDLE

Wallpaper       visible
Dim overlay     0%
Clock           prominent but subtle
Login UI        hidden
```

```text
LOGIN

Wallpaper       preserved
Dim overlay     configurable
Clock           subdued
Login UI        visible
```

The background dimming and clock animation are driven by the same presentation progress value, keeping the transition synchronized.

---

### 🕰️ 5. Clock Moves Instead of Disappearing

The clock remains visible after login mode is activated.

Its position is interpolated between two presentation states:

```text
IDLE
50% vertical position
       │
       │ animation
       ▼
LOGIN
28% vertical position
```

The clock also transitions between its idle and login opacity values.

This keeps the clock visually connected to both states rather than simply removing it when the login form appears.

---

### 🔐 6. Early Keyboard Input Is Preserved

One of the important implementation details is handling keyboard input during the transition.

There is a short period where the user can type before the authentication prompt has fully appeared.

Without handling this explicitly, the first characters could be lost.

The implementation therefore buffers early keyboard text:

```text
User types
    │
    ▼
Login transition starts
    │
    ▼
Input temporarily buffered
    │
    ▼
Authentication prompt appears
    │
    ▼
Buffered text transferred to Gtk.Entry
```

This allows a user to begin typing immediately after the greeter appears without having to wait for the animation to finish.

---

## 🧩 Architecture

The customization is implemented directly inside Slick Greeter.

It does **not** introduce a new greeter framework or replace LightDM authentication.

The high-level architecture is:

```text
LightDM
   │
   ▼
SlickGreeter
   │
   ▼
MainWindow
   │
   ├── Background
   │
   ├── IdleClockOverlay
   │      ├── Clock rendering
   │      └── Background dimming
   │
   └── Login UI
          ├── User list
          ├── Prompt
          ├── Session selection
          ├── Menubar
          └── Existing Slick Greeter controls
```

### Main modified components

| File | Responsibility |
|---|---|
| `src/idle-clock-overlay.vala` | Clock rendering, clock animation and background dimming |
| `src/main-window.vala` | Login presentation state, keyboard activation, animation and input buffering |
| `src/settings.vala` | Configuration keys and `/etc/lightdm/slick-greeter.conf` integration |
| `data/x.dm.slick-greeter.gschema.xml` | GSettings schema and defaults |
| `src/idle-monitor.vala` | Existing idle/activity monitoring infrastructure |
| `src/animate-timer.vala` | Animation timing |

The repository's source tree confirms these components are part of the fork.

---

## ⚙️ Configuration

The existing Slick Greeter configuration mechanism is preserved.

Configuration can be provided through:

```text
/etc/lightdm/slick-greeter.conf
```

The configuration group is:

```ini
[Greeter]
```

### Personalized settings

| Setting | Type | Default | Description |
|---|---|---:|---|
| `idle-clock-enabled` | boolean | `true` | Enables the idle clock presentation |
| `idle-clock-opacity` | double | `0.34` | Clock opacity while idle |
| `login-clock-opacity` | double | `0.22` | Clock opacity when login UI is visible |
| `login-background-dim-opacity` | double | `0.36` | Background overlay opacity during login |
| `login-transition-duration` | integer | `350` | Transition duration in milliseconds |

These defaults come directly from the project's GSettings schema.

### Example

```ini
[Greeter]

idle-clock-enabled=true
idle-clock-opacity=0.34
login-clock-opacity=0.22
login-background-dim-opacity=0.36
login-transition-duration=350
```

---

## 🕰️ Clock Format

The existing Slick Greeter `clock-format` setting is still used by the personalized clock.

For example:

```ini
clock-format=%H:%M
```

produces:

```text
23:31
```

A 12-hour format can be used with:

```ini
clock-format=%l:%M %p
```

The default schema value is:

```text
%H:%M
```

The clock implementation reads this setting and updates the displayed time every second.

---

## 🛠️ Technology Stack

This project remains a native Slick Greeter application.

- **Vala**
- **C**
- **GTK+ 3**
- **GLib / GIO**
- **Cairo**
- **Pango**
- **LightDM**
- **X11**
- **Meson**
- **Ninja**

The current build configuration is based on Meson and requires GTK+ 3.20 or newer and `liblightdm-gobject-1` 1.12 or newer.

---

## 🔨 Building

### Clone

```bash
git clone https://github.com/AdityaSharma-dev-codes/slick-greeter-personalized.git
cd slick-greeter-personalized
```

### Configure

```bash
meson setup build
```

### Compile

```bash
meson compile -C build
```

### Test mode

Slick Greeter provides a test mode that can be used before replacing the system greeter:

```bash
./build/src/slick-greeter --test-mode
```

The project already exposes the `--test-mode` option through its main greeter executable.

> **Important:** A LightDM greeter runs as part of the system login environment. Test the custom build before replacing the distribution-provided greeter.

---

## 🧪 Expected Behaviour

### Idle

```text
┌─────────────────────────────────────────────┐
│                                             │
│                                             │
│                                             │
│                    23:31                    │
│                                             │
│                                             │
│                                             │
└─────────────────────────────────────────────┘
```

The screen remains visually minimal.

---

### Keyboard input

When the user starts typing:

```text
              23:31
                 ↑
                 │ clock moves
                 
          background dims

             login UI
          fades/slides in
```

---

### Login

The existing Slick Greeter login interface becomes fully visible and interactive.

The personalization is therefore primarily a **presentation-layer modification** rather than a rewrite of authentication.

---

## 🔄 Returning to Idle

Pressing `Escape` cancels the current authentication interaction and returns the presentation toward the idle state when the idle-clock mode is enabled.

The transition reverses:

```text
LOGIN
  │
  │ Escape
  ▼
LOGIN TRANSITION
  │
  ├── Login UI fades out
  ├── Background brightens
  └── Clock returns toward center
  │
  ▼
IDLE
```

This behaviour is implemented in `MainWindow` alongside the existing keyboard handling.

---

## 🎨 Design Goals

The project is intentionally designed around a small number of visual principles:

- **Minimal**
- **Modern**
- **Subtle**
- **Readable**
- **Low visual clutter**
- **Smooth transitions**
- **Preserve the wallpaper**
- **Keep the clock visible**
- **Reveal controls only when needed**

The goal is not to redesign every part of Slick Greeter.

Instead, the project focuses on changing the initial presentation and interaction model while keeping the underlying greeter architecture intact.

---

## 📸 Screenshots

### Idle State

![Idle clock](docs/screenshots/idle-clock.png)

Large clock, visible wallpaper, minimal UI.

### Login State

![Login state](docs/screenshots/login-state.png)

The login interface appears after keyboard interaction, with the clock moved upward and the background dimmed.

> Add the screenshots from the project under `docs/screenshots/` using the filenames above before pushing this README. Do not leave broken image links in the repository.

---

## 🔍 What This Project Demonstrates

This fork is primarily a UI/desktop-system engineering project.

It demonstrates:

- modifying an existing open-source C/Vala codebase;
- GTK widget composition;
- Cairo/Pango rendering;
- keyboard event handling;
- state-driven UI presentation;
- animation with GTK/GLib;
- GSettings configuration;
- LightDM integration;
- preserving existing authentication behaviour;
- handling asynchronous authentication prompts;
- buffering keyboard input during UI transitions;
- working with X11/multi-monitor behaviour;
- building a system-level Linux application with Meson.

---

## ⚠️ Important Notes

This is a **custom fork of Slick Greeter**, not an independent authentication system.

LightDM and the existing Slick Greeter authentication/session infrastructure remain responsible for login handling.

The project should therefore be treated as a system-level customization and tested carefully before being used as the production greeter.

For reference, upstream Slick Greeter is a LightDM greeter developed by Linux Mint and retains its existing configuration, session handling, HiDPI support, and system integration.

---

## 📋 Current Status

### Implemented

- [x] Minimal idle clock
- [x] Large centered clock
- [x] Configurable clock opacity
- [x] Keyboard-triggered login presentation
- [x] Login UI fade-in
- [x] Login UI slide transition
- [x] Clock upward movement
- [x] Background dimming
- [x] Configurable transition duration
- [x] First-character / early-input buffering
- [x] Escape-based return toward idle presentation
- [x] GSettings configuration
- [x] Existing Slick Greeter architecture retained

### Future Improvements

- [ ] Add polished repository screenshots
- [ ] Add automated tests for presentation-state transitions
- [ ] Improve visual tuning across additional display configurations
- [ ] Add optional customization for clock positioning
- [ ] Add further animation customization

---

## 🙏 Credits

This project is based on **Slick Greeter**, the LightDM greeter developed by the Linux Mint project.

Upstream project:

https://github.com/linuxmint/slick-greeter

Slick Greeter itself originated as a fork of Ubuntu's Unity Greeter.

---

## 📄 License

This project retains the **GNU General Public License v3.0** licensing of the upstream project.

See [`COPYING`](COPYING) for the full license text.

---

## 🔗 Repository

**Slick Greeter Personalized**

https://github.com/AdityaSharma-dev-codes/slick-greeter-personalized