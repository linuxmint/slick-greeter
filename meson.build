project('slick-greeter', 'vala', 'c', version : '2.0.9', meson_version : '>= 0.49.0')

cc = meson.get_compiler('c')

i18n = import('i18n')

gettext_package = meson.project_name()

prefix = get_option('prefix')
bindir = get_option('bindir')
datadir = get_option('datadir')
localedir = get_option('localedir')
pkgdatadir = datadir / meson.project_name()
sbindir = get_option('sbindir')

cairo_dep = dependency('cairo')
gdk_x11_dep = dependency('gdk-x11-3.0')
gio_dep = dependency('gio-2.0')
gio_unix_dep = dependency('gio-unix-2.0')
gtk_dep = dependency('gtk+-3.0', version: '>= 3.20.0')
libcanberra_dep = dependency('libcanberra')
liblightdm_gobject_dep = dependency('liblightdm-gobject-1', version: '>= 1.12.0')
m_dep = cc.find_library('m')
pixman_dep = dependency('pixman-1')
posix_dep = meson.get_compiler('vala').find_library('posix')
x11_dep = dependency('x11')
xext_dep = cc.find_library('Xext')

config_data = configuration_data()
config_data.set_quoted('GETTEXT_PACKAGE', gettext_package)
config_data.set_quoted('LOCALEDIR', prefix / localedir)
config_data.set_quoted('PKGDATADIR', prefix / pkgdatadir)
config_data.set_quoted('VERSION', meson.project_version())
configure_file(
    configuration: config_data,
    output: 'config.h',
)
config_h_dir = include_directories('.')

subdir('data')
subdir('files')
subdir('po')
subdir('src')

meson.add_install_script('meson/meson-postinstall.sh')
