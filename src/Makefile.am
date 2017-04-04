# -*- Mode: Automake; indent-tabs-mode: t; tab-width: 4 -*-

sbin_PROGRAMS = slick-greeter
noinst_PROGRAMS = logo-generator

slick_greeter_SOURCES = \
	config.vapi \
	fixes.vapi \
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
	shutdown-dialog.vala \
	toggle-box.vala \
	slick-greeter.vala \
	user-list.vala \
	user-prompt-box.vala

logo_generator_SOURCES = logo-generator.vala

slick_greeter_CFLAGS = \
	$(SLICK_GREETER_CFLAGS) \
	-w \
	-DGETTEXT_PACKAGE=\"$(GETTEXT_PACKAGE)\" \
	-DLOCALEDIR=\""$(localedir)"\" \
	-DVERSION=\"$(VERSION)\" \
	-DPKGDATADIR=\""$(pkgdatadir)"\"

logo_generator_CFLAGS = $(slick_greeter_CFLAGS)

slick_greeter_VALAFLAGS = \
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

logo_generator_VALAFLAGS = $(slick_greeter_VALAFLAGS)

slick_greeter_LDADD = \
	$(SLICK_GREETER_LIBS) \
	-lm

logo_generator_LDADD = $(slick_greeter_LDADD)

slick_greeter_vala.stamp: $(top_srcdir)/config.h

DISTCLEANFILES = \
	Makefile.in
