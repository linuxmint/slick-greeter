icon_files = [
    'a11y.svg',
    'active.png',
    'arrow_left.png',
    'arrow_right.png',
    'battery.svg',
    'battery_10.svg',
    'battery_25.svg',
    'battery_50.svg',
    'dialog_close.png',
    'dialog_close_highlight.png',
    'dialog_close_press.png',
    'hibernate_highlight.png',
    'hibernate.png',
    'keyboard.svg',
    'message.png',
    'remote_login_help.png',
    'restart_highlight.png',
    'restart.png',
    'shadow.png',
    'shutdown_highlight.png',
    'shutdown.png',
    'shutdown.svg',
    'suspend_highlight.png',
    'suspend.png',
    'switcher_corner.png',
    'switcher_left.png',
    'switcher_top.png',
]

install_data(
    icon_files,
    install_dir: pkgdatadir,
)

install_data(
    'x.dm.slick-greeter.gschema.xml',
    install_dir: datadir / 'glib-2.0' / 'schemas',
)

install_data(
    'slick-greeter.desktop',
    install_dir: datadir / 'xgreeters',
)

man_files = [
    'slick-greeter-set-keyboard-layout.1',
    'slick-greeter-check-hidpi.1',
    'slick-greeter-enable-tap-to-click.1',
    'slick-greeter.8',
]

install_man(man_files)
