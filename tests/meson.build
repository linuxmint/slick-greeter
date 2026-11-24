test_sources = files(
    'menubar.vala',
    'slick-greeter.vala',
    'test.vala',
    'test-list.vala',
    'test-main-window.vala',
)

# The real slick-greeter.vala and menubar.vala are replaced by test stand-ins
foreach f : slick_greeter_sources
    name = fs.name(f)
    if name != 'slick-greeter.vala' and name != 'menubar.vala'
        test_sources += f
    endif
endforeach

slick_greeter_test = executable(
    'slick-greeter-test',
    test_sources,
    dependencies: dependencies,
    include_directories: config_h_dir,
    c_args: c_args,
    vala_args: vala_args,
    build_by_default: false,
)

xvfb_run = find_program('xvfb-run', required: false)
if xvfb_run.found()
    test(
        'slick-greeter-test',
        xvfb_run,
        args: ['-a', slick_greeter_test, '--tap'],
        env: [
            'UBUNTU_MENUPROXY=0',
            'top_srcdir=' + meson.project_source_root(),
        ],
        protocol: 'tap',
        timeout: 120,
    )
endif
