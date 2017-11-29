# -*- Mode: m4; indent-tabs-mode: nil; tab-width: 4 -*-

dnl Process this file with autoconf to produce a configure script.

AC_INIT(slick-greeter, 1.1.3)
AC_CONFIG_MACRO_DIR(m4)
AM_INIT_AUTOMAKE([1.11 no-dist-gzip dist-xz foreign subdir-objects])
AM_PROG_CC_C_O
AM_PROG_VALAC([0.24.0])
AM_CONFIG_HEADER(config.h)
AM_MAINTAINER_MODE
m4_ifdef([AM_SILENT_RULES], [AM_SILENT_RULES(yes)])

GLIB_GSETTINGS

dnl ###########################################################################
dnl Dependencies
dnl ###########################################################################

PKG_CHECK_MODULES(SLICK_GREETER, [
    gtk+-3.0
    gdk-x11-3.0
    liblightdm-gobject-1 >= 1.12.0
    freetype2
    cairo-ft
    libcanberra
    pixman-1
    x11
    xext
])

dnl ###########################################################################
dnl Internationalization
dnl ###########################################################################

IT_PROG_INTLTOOL(0.35.0)
GETTEXT_PACKAGE=slick-greeter
AC_DEFINE_UNQUOTED(GETTEXT_PACKAGE, "$GETTEXT_PACKAGE", Gettext package)
AC_SUBST(GETTEXT_PACKAGE)

dnl ###########################################################################
dnl Check for GTK version - 3.20
dnl ###########################################################################

PKG_CHECK_MODULES(GTK_3_20_0, gtk+-3.0 >= 3.20.0 , gtk_check_pass=yes, gtk_check_pass=no)
if test x$gtk_check_pass = xyes ; then
  AM_VALAFLAGS="$AM_VALAFLAGS -D HAVE_GTK_3_20_0"
  AC_SUBST([AM_VALAFLAGS])
fi

dnl ###########################################################################
dnl Files to generate
dnl ###########################################################################

AC_CONFIG_FILES([
Makefile
data/Makefile
files/Makefile
po/Makefile.in
src/Makefile
tests/Makefile
])
AC_OUTPUT
