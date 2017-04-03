# -*- Mode: Automake; indent-tabs-mode: t; tab-width: 4 -*-

sbin_PROGRAMS = unity-greeter
noinst_PROGRAMS = logo-generator

unity_greeter_SOURCES = \
	config.vapi \
	fixes.vapi \
	indicator.vapi \
	xsync.vapi \
	animate-timer.vala \
	background.vala \
	cached-image.vala \
	cairo-utils.vala \
	email-autocompleter.vala \
	dash-box.vala \
	dash-button.vala \
	dash-entry.vala \
	fadable.vala \
	fadable-box.vala \
	fading-label.vala \
	flat-button.vala \
	greeter-list.vala \
	idle-monitor.vala \
	list-stack.vala \
	main-window.vala \
	menu.vala \
	menubar.vala \
	prompt-box.vala \
	session-list.vala \
	remote-login-service.vala \
	settings.vala \
	settings-daemon.vala \
	shutdown-dialog.vala \
	toggle-box.vala \
	unity-greeter.vala \
	user-list.vala \
	user-prompt-box.vala

logo_generator_SOURCES = logo-generator.vala

unity_greeter_CFLAGS = \
	$(UNITY_GREETER_CFLAGS) \
	-w \
	-DGETTEXT_PACKAGE=\"$(GETTEXT_PACKAGE)\" \
	-DLOCALEDIR=\""$(localedir)"\" \
	-DVERSION=\"$(VERSION)\" \
	-DPKGDATADIR=\""$(pkgdatadir)"\" \
	-DINDICATORDIR=\""$(INDICATORDIR)"\"

logo_generator_CFLAGS = $(unity_greeter_CFLAGS)

unity_greeter_VALAFLAGS = \
	--pkg posix \
	--pkg gtk+-3.0 \
	--pkg gdk-x11-3.0 \
	--pkg gio-unix-2.0 \
	--pkg x11 \
	--pkg liblightdm-gobject-1 \
	--pkg libcanberra \
	--pkg gio-2.0 \
	--pkg pixman-1 \
	--target-glib 2.32

logo_generator_VALAFLAGS = $(unity_greeter_VALAFLAGS)

unity_greeter_LDADD = \
	$(UNITY_GREETER_LIBS) \
	-lm

logo_generator_LDADD = $(unity_greeter_LDADD)

unity_greeter_vala.stamp: $(top_srcdir)/config.h

DISTCLEANFILES = \
	Makefile.in
