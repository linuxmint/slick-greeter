# -*- Mode: Automake; indent-tabs-mode: t; tab-width: 4 -*-

xgreeterdir = $(datarootdir)/xgreeters
dist_xgreeter_DATA = unity-greeter.desktop

dist_pkgdata_DATA = \
	a11y.svg \
	active.png \
	arrow_left.png \
	arrow_right.png \
	cof.png \
	dialog_close.png \
	dialog_close_highlight.png \
	dialog_close_press.png \
	gnome_badge.png \
	hibernate_highlight.png \
	hibernate.png \
	kde_badge.png \
	logo.png \
	message.png \
	recovery_console_badge.png \
	remote_login_help.png \
	restart_highlight.png \
	restart.png \
	shadow.png \
	shutdown_highlight.png \
	shutdown.png \
	suspend_highlight.png \
	suspend.png \
	switcher_corner.png \
	switcher_left.png \
	switcher_top.png \
	ubuntu_badge.png \
	unknown_badge.png

@GSETTINGS_RULES@
gsettings_SCHEMAS = com.canonical.unity-greeter.gschema.xml

dist_man1_MANS = unity-greeter.1

EXTRA_DIST = \
	$(gsettings_SCHEMAS)

DISTCLEANFILES = \
	Makefile.in
