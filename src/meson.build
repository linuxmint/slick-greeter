lgen_sources = 'logo-generator.vala'

sgreeter_common = [
  'animate-timer.vala',
  'background.vala',
  'cached-image.vala',
  'cairo-utils.vala',
  'config.vapi',
  'dash-box.vala',
  'dash-button.vala',
  'dash-entry.vala',
  'email-autocompleter.vala',
  'fadable-box.vala',
  'fadable.vala',
  'fading-label.vala',
  'fixes.vapi',
  'flat-button.vala',
  'greeter-list.vala',
  'idle-monitor.vala',
  'list-stack.vala',
  'main-window.vala',
  'prompt-box.vala',
  'remote-login-service.vala',
  'session-list.vala',
  'settings.vala',
  'shutdown-dialog.vala',
  'toggle-box.vala',
  'user-list.vala',
  'user-prompt-box.vala',
  'xsync.vapi',
]

sgreeter_sources = [
  'menu.vala',
  'menubar.vala',
  'slick-greeter.vala',
  sgreeter_common
]

deps = [
 canberra,
 gdk,
 gtk,
 gio,
 giounix, # this and gio isn't required for build, but safe than sorry
 libm,
 lightdm,
 pixman,
 posix,
 x11,
 xext_novala
]

sgreeter_common_files = files(sgreeter_common)  # For tests

sgreeter = executable(
  'slick-greeter', sgreeter_sources,
  dependencies : deps,
  include_directories : rootdir,
  c_args: [
    '-DGETTEXT_PACKAGE="@0@"'.format(meson.project_name()),
    '-DLOCALEDIR="@0@"'.format(localedir),
    '-DPKGDATADIR="@0@"'.format(pkgdatadir),
    '-DVERSION="@0@"'.format(meson.project_version())
  ],
  link_args : '-lm',
  install : true
)

lgen = executable(
  'logo-generator', lgen_sources,
  dependencies : deps,
  include_directories : rootdir,
  link_args : '-lm',
  install : false
)
