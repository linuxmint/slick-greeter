# -*- Mode: Automake; indent-tabs-mode: t; tab-width: 4 -*-

xgreeterdir = $(datarootdir)/xgreeters
dist_xgreeter_DATA = slick-greeter.desktop

dist_pkgdata_DATA = \
	a11y.svg \
	active.png \
	arrow_left.png \
	arrow_right.png \
	battery.svg \
	battery_10.svg \
	battery_25.svg \
	battery_50.svg \
	dialog_close.png \
	dialog_close_highlight.png \
	dialog_close_press.png \
	hibernate_highlight.png \
	hibernate.png \
	keyboard.svg \
	message.png \
	remote_login_help.png \
	restart_highlight.png \
	restart.png \
	shadow.png \
	shutdown_highlight.png \
	shutdown.png \
	shutdown.svg \
	suspend_highlight.png \
	suspend.png \
	switcher_corner.png \
	switcher_left.png \
	switcher_top.png

@GSETTINGS_RULES@
gsettings_SCHEMAS = x.dm.slick-greeter.gschema.xml

dist_man1_MANS = \
	slick-greeter-set-keyboard-layout.1 \
	slick-greeter-check-hidpi.1

dist_man8_MANS = \
	slick-greeter.8

EXTRA_DIST = \
	$(gsettings_SCHEMAS)

DISTCLEANFILES = \
	Makefile.in
