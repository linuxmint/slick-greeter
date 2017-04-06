
A cross-distro LightDM greeter based on unity-greeter

# Configuration

- The default configuration is stored in dconf under the schema x.dm.slick-greeter.
- Distributions should set their own defaults using a glib override.
- Users can create and modify /etc/lightdm/slick-greeter.conf, settings in this files take priority and overwrite dconf settings.

A configuration tool is available at https://github.com/linuxmint/lightdm-settings 
