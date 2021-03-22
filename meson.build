project('slick-greeter', 'c', 'vala', version : '1.5.2')

i18n = import('i18n')

conf = configuration_data()

prefixdir = get_option('prefix')
datadir = join_paths(prefixdir, get_option('datadir'))
localedir = join_paths(prefixdir, get_option('localedir'))
pkgdatadir = join_paths(datadir, 'slick-greeter')
schemadir = join_paths(datadir, 'glib-2.0', 'schemas')
xgreeterdir = join_paths(datadir, 'xgreeters')
rootdir = include_directories('.')

canberra = dependency('libcanberra')
gdk = dependency('gdk-x11-3.0')
gio = dependency('gio-2.0')
giounix = dependency('gio-unix-2.0')
gtk = dependency('gtk+-3.0')
libm = meson.get_compiler('c').find_library('m', required : false)
lightdm = dependency('liblightdm-gobject-1', version : '>= 1.12')
pixman = dependency('pixman-1')
posix = meson.get_compiler('vala').find_library('posix')
x11 = dependency('x11')
xext = dependency('xext')

# filthy hack hardcoding the xext link flag. It's apparently impossible to use
# (or extract from) dependency() without somehow forcing the type to
# dependencies.PkgConfigDependency and at that point meson pedantically assumes
# the pkg-config library "must" come with a corresponding .vapi which is not
# the case here. Oddly this restriction is relaxed if you use lookup methods
# other than pkg-config.
#
# Thank you eschwartz!
xext_novala = declare_dependency(link_args : '-lXext')

if get_option('gtk-check-pass')
  gtk_3_20 = dependency('gtk+-3.0', version : '>= 3.20')
  conf.set('HAVE_GTK_3_20_0', 1)
endif

# Hack for vala >= 0.39, and if possible use glib 2.32
add_project_arguments('-include', 'gtk/gtkx.h', language : 'c')
add_project_arguments('--target-glib', '2.32', language : 'vala')

conf.set_quoted('DATADIR', datadir)
conf.set_quoted('GETTEXT_PACKAGE', meson.project_name())
conf.set_quoted('LOCALEDIR', localedir)
conf.set_quoted('PKGDATADIR', pkgdatadir)
conf.set_quoted('VERSION', meson.project_version())
configure_file(output : 'config.h',
               configuration : conf)

subdir('data')
subdir('files')
subdir('po')
subdir('src')
#subdir('tests')  #Tests are broken at the moment.

meson.add_install_script('meson_post_install.py')
