slick_greeter_sources = files(
    'config.vapi',
    'fixes.vapi',
    'xsync.vapi',
    'animate-timer.vala',
    'background.vala',
    'cached-image.vala',
    'cairo-utils.vala',
    'email-autocompleter.vala',
    'dash-box.vala',
    'dash-button.vala',
    'dash-entry.vala',
    'fadable.vala',
    'fadable-box.vala',
    'fading-label.vala',
    'flat-button.vala',
    'greeter-list.vala',
    'idle-monitor.vala',
    'list-stack.vala',
    'main-window.vala',
    'menu.vala',
    'menubar.vala',
    'prompt-box.vala',
    'session-list.vala',
    'remote-login-service.vala',
    'settings.vala',
    'shutdown-dialog.vala',
    'toggle-box.vala',
    'slick-greeter.vala',
    'user-list.vala',
    'user-prompt-box.vala',
)

logo_generator_sources = files(
    'logo-generator.vala',
)

dependencies = [
    cairo_dep,
    gdk_x11_dep,
    gio_dep,
    gio_unix_dep,
    gtk_dep,
    libcanberra_dep,
    liblightdm_gobject_dep,
    m_dep,
    pixman_dep,
    posix_dep,
    x11_dep,
    xapp_dep,
    xext_dep,
]

c_args = [
    '-w',
    '-include', 'config.h',
]

vala_args = [
    '--debug',
    '--target-glib', '2.32',
    '-D', 'HAVE_GTK_3_20_0',
]

executable(
    'slick-greeter',
    slick_greeter_sources,
    dependencies: dependencies,
    include_directories: config_h_dir,
    c_args: c_args,
    vala_args: vala_args,
    install: true,
    install_dir: sbindir,
)

executable(
    'logo-generator',
    logo_generator_sources,
    dependencies: dependencies,
    include_directories: config_h_dir,
    c_args: c_args,
    vala_args: vala_args,
)
