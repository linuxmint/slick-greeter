
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
