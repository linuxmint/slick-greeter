data = [
  'a11y.svg',
  'active.png',
  'arrow_left.png',
  'arrow_right.png',
  'battery_10.svg',
  'battery_25.svg',
  'battery_50.svg',
  'battery.svg',
  'dialog_close_highlight.png',
  'dialog_close_press.png',
  'dialog_close.png',
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
  'switcher_top.png'
]

man_1 = [
  'slick-greeter-check-hidpi.1',
  'slick-greeter-set-keyboard-layout.1'
]

gschema = 'x.dm.slick-greeter.gschema.xml'
man_8 = 'slick-greeter.8'
xgreeter = 'slick-greeter.desktop'

install_data(
  data,
  install_dir : pkgdatadir
)

install_man(man_1)
install_man(man_8)

install_data(
  gschema,
  install_dir : schemadir
)

install_data(
  xgreeter,
  install_dir : xgreeterdir
)
