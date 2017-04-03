# -*- Mode: m4; indent-tabs-mode: nil; tab-width: 4 -*-

dnl Process this file with autoconf to produce a configure script.

AC_INIT(unity-greeter, 16.04.2)
AC_CONFIG_MACRO_DIR(m4)
AM_INIT_AUTOMAKE([1.11 no-dist-gzip dist-xz foreign])
AM_PROG_CC_C_O
AM_PROG_VALAC([0.24.0])
AM_CONFIG_HEADER(config.h)
AM_MAINTAINER_MODE
m4_ifdef([AM_SILENT_RULES], [AM_SILENT_RULES(yes)])

GLIB_GSETTINGS

dnl ###########################################################################
dnl Dependencies
dnl ###########################################################################

PKG_CHECK_MODULES(UNITY_GREETER, [
    gtk+-3.0
    gdk-x11-3.0
    indicator3-0.4
    libido3-0.1 >= 13.10.0
    liblightdm-gobject-1 >= 1.12.0
    freetype2
    cairo-ft
    libcanberra
    pixman-1
    x11
    xext
])

AC_DEFINE_UNQUOTED([INDICATOR_FILE_DIR], ["${prefix}/share/unity/indicators"], [Indicator files are searched for in this directory])

INDICATORDIR=`$PKG_CONFIG --variable=indicatordir indicator3-0.4`
AC_SUBST(INDICATORDIR)

USD_BINARY=`$PKG_CONFIG --variable=binary unity-settings-daemon`
if test -z "$USD_BINARY"; then
    AC_MSG_ERROR([Could not find path to unity-settings-daemon binary])
fi
AC_DEFINE_UNQUOTED([USD_BINARY], ["$USD_BINARY"], [Path to g-s-d])

dnl ###########################################################################
dnl Internationalization
dnl ###########################################################################

IT_PROG_INTLTOOL(0.35.0)
GETTEXT_PACKAGE=unity-greeter
AC_DEFINE_UNQUOTED(GETTEXT_PACKAGE, "$GETTEXT_PACKAGE", Gettext package)
AC_SUBST(GETTEXT_PACKAGE)

dnl ###########################################################################
dnl Files to generate
dnl ###########################################################################

AC_CONFIG_FILES([
Makefile
data/Makefile
po/Makefile.in
src/Makefile
tests/Makefile
])
AC_OUTPUT
