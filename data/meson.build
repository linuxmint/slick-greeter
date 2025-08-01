icon_files = [
    'a11y.svg',
    'active.png',
    'arrow_left.svg',
    'arrow_right.svg',
    'battery.svg',
    'battery_10.svg',
    'battery_25.svg',
    'battery_50.svg',
    'dialog_close.svg',
    'dialog_close_highlight.svg',
    'dialog_close_press.svg',
    'hibernate_highlight.svg',
    'hibernate.svg',
    'keyboard.svg',
    'message.png',
    'remote_login_help.png',
    'restart_highlight.svg',
    'restart.svg',
    'shadow.png',
    'shutdown_highlight.svg',
    'shutdown_dialog.svg',
    'shutdown.svg',
    'suspend_highlight.svg',
    'suspend.svg',
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
