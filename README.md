
A slick-looking LightDM greeter

![Slick Greeter](https://www.linuxmint.com/tmp/blog/3254/thumb_slick.png)

# Configuration

- The default configuration is stored in dconf under the schema x.dm.slick-greeter.
- Distributions should set their own defaults using a glib override.
- Users can create and modify /etc/lightdm/slick-greeter.conf, settings in this files take priority and overwrite dconf settings.

A configuration tool is available at https://github.com/linuxmint/lightdm-settings

# Features

- Slick-Greeter is cross-distribution and should work pretty much anywhere.
- All panel applets are embedded. No external indicators are launched or loaded by the greeter.
- No settings daemon are launched or loaded by the greeter.
- This greeter supports HiDPI.
- Sessions are validated. If a default/chosen session isn't present on the system, the greeter scans for known sessions in /usr/share/xsessions and replaces the invalid session choice with a valid session.
- You can take a screenshot by pressing PrintScrn. The screenshot is saved in /var/lib/lightdm/Screenshot.png.

# Credit

- Slick Greeter started as a fork of Unity Greeter 16.04.2, a greeter developed for Ubuntu by Canonical, which used indicators and unity-settings-daemon.

----

Configuration file format for /etc/lightdm/slick-greeter.conf

    # LightDM GTK+ Configuration
    # Available configuration options listed below.
    #
    # background=Background file to use, either an image path or a color (e.g. #772953)
    # background-color=Background color (e.g. #772953), set before wallpaper is seen
    # draw-user-backgrounds=Whether to draw user backgrounds (true or false)
    # draw-grid=Whether to draw an overlay grid (true or false)
    # show-hostname=Whether to show the hostname in the menubar (true or false)
    # logo=Logo file to use
    # background-logo=Background logo file to use
    # theme-name=GTK+ theme to use
    # icon-theme-name=Icon theme to use
    # font-name=Font to use
    # xft-antialias=Whether to antialias Xft fonts (true or false)
    # xft-dpi=Resolution for Xft in dots per inch
    # xft-hintstyle=What degree of hinting to use (hintnone/hintslight/hintmedium/hintfull)
    # xft-rgba=Type of subpixel antialiasing (none/rgb/bgr/vrgb/vbgr)
    # onscreen-keyboard=Whether to enable the onscreen keyboard (true or false)
    # high-contrast=Whether to use a high contrast theme (true or false)
    # screen-reader=Whether to enable the screen reader (true or false)
    # play-ready-sound=A sound file to play when the greeter is ready
    # hidden-users=List of usernames that are hidden until a special key combination is hit
    # group-filter=List of groups that users must be part of to be shown (empty list shows all users)
    # idle-timeout=Number of seconds of inactivity before blanking the screen. Set to 0 to never timeout
    # enable-hidpi=Whether to enable HiDPI support (on/off/auto)
    [greeter]
