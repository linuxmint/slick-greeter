# Tests are broken at the moment, do not use this.

sgreeter_test_sources = [
  'menubar.vala',
  'slick-greeter.vala',
  'test-list.vala',
  'test-main-window.vala',
  'test.vala',
  sgreeter_common_files
]

sgreeter_test = executable(
  'slick-greeter-test', sgreeter_test_sources,
  dependencies : deps,
  include_directories : rootdir,
  c_args : [
    '-DGETTEXT_PACKAGE="@0@"'.format(meson.project_name()),
    '-DLOCALEDIR="@0@"'.format(localedir),
    '-DPKGDATADIR="@0@"'.format(pkgdatadir),
    '-DVERSION="@0@"'.format(meson.project_version())
  ],
  link_args : '-lm'
)
test('slick-greeter-test', sgreeter_test)
