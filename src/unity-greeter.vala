/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 4 -*-
 *
 * Copyright (C) 2011 Canonical Ltd
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by: Robert Ancell <robert.ancell@canonical.com>
 */

public const int grid_size = 40;

public class UnityGreeter
{
    public static UnityGreeter singleton;

    public signal void show_message (string text, LightDM.MessageType type);
    public signal void show_prompt (string text, LightDM.PromptType type);
    public signal void authentication_complete ();
    public signal void starting_session ();

    public bool test_mode = false;

    private string state_file;
    private KeyFile state;

    private Cairo.XlibSurface background_surface;

    private SettingsDaemon settings_daemon;

    public bool orca_needs_kick;
    private MainWindow main_window;

    private LightDM.Greeter greeter;

    private Canberra.Context canberra_context;

    private static Timer log_timer;

    private DialogDBusInterface dbus_object;

    private UnityGreeter (bool test_mode_)
    {
        singleton = this;
        test_mode = test_mode_;

        /* Prepare to set the background */
        debug ("Creating background surface");
        background_surface = create_root_surface (Gdk.Screen.get_default ());

        greeter = new LightDM.Greeter ();
        greeter.show_message.connect ((text, type) => { show_message (text, type); });
        greeter.show_prompt.connect ((text, type) => { show_prompt (text, type); });
        greeter.autologin_timer_expired.connect (() => { greeter.authenticate_autologin (); });
        greeter.authentication_complete.connect (() => { authentication_complete (); });
        var connected = false;
        try
        {
            connected = greeter.connect_to_daemon_sync ();
        }
        catch (Error e)
        {
            warning ("Failed to connect to LightDM daemon");
        }
        if (!connected && !test_mode)
            Posix.exit (Posix.EXIT_FAILURE);

        if (!test_mode)
        {
            settings_daemon = new SettingsDaemon ();
            settings_daemon.start ();
        }

        var state_dir = Path.build_filename (Environment.get_user_cache_dir (), "unity-greeter");
        DirUtils.create_with_parents (state_dir, 0775);
        
        var xdg_seat = GLib.Environment.get_variable("XDG_SEAT");
        var state_file_name = xdg_seat != null && xdg_seat != "seat0" ? xdg_seat + "-state" : "state";

        state_file = Path.build_filename (state_dir, state_file_name);
        state = new KeyFile ();
        try
        {
            state.load_from_file (state_file, KeyFileFlags.NONE);
        }
        catch (Error e)
        {
            if (!(e is FileError.NOENT))
                warning ("Failed to load state from %s: %s\n", state_file, e.message);
        }

        main_window = new MainWindow ();

        Bus.own_name (BusType.SESSION, "com.canonical.UnityGreeter", BusNameOwnerFlags.NONE);

        dbus_object = new DialogDBusInterface ();
        dbus_object.open_dialog.connect ((type) =>
        {
            ShutdownDialogType dialog_type;
            switch (type)
            {
            default:
            case 1:
                dialog_type = ShutdownDialogType.LOGOUT;
                break;
            case 2:
                dialog_type = ShutdownDialogType.RESTART;
                break;
            }
            main_window.show_shutdown_dialog (dialog_type);
        });
        dbus_object.close_dialog.connect ((type) => { main_window.close_shutdown_dialog (); });
        Bus.own_name (BusType.SESSION, "com.canonical.Unity", BusNameOwnerFlags.NONE,
                      (c) =>
                      {
                          try
                          {
                              c.register_object ("/org/gnome/SessionManager/EndSessionDialog", dbus_object);
                          }
                          catch (Error e)
                          {
                              warning ("Failed to register /org/gnome/SessionManager/EndSessionDialog: %s", e.message);
                          }
                      },
                      null,
                      () => debug ("Failed to acquire name com.canonical.Unity"));

        start_fake_wm ();
        Gdk.threads_add_idle (ready_cb);
    }

    public string? get_state (string key)
    {
        try
        {
            return state.get_value ("greeter", key);
        }
        catch (Error e)
        {
            return null;
        }
    }

    public void set_state (string key, string value)
    {
        state.set_value ("greeter", key, value);
        var data = state.to_data ();
        try
        {
            FileUtils.set_contents (state_file, data);
        }
        catch (Error e)
        {
            debug ("Failed to write state: %s", e.message);
        }
    }

    public void push_list (GreeterList widget)
    {
        main_window.push_list (widget);
    }

    public void pop_list ()
    {
        main_window.pop_list ();
    }

    public static void add_style_class (Gtk.Widget widget)
    {
        /* Add style context class lightdm-user-list */
        var ctx = widget.get_style_context ();
        ctx.add_class ("lightdm");
    }

    public bool start_session (string? session, Background bg)
    {
        /* Explicitly set the right scale before closing window */
        var screen = Gdk.Screen.get_default ();
        var scale = screen.get_monitor_scale_factor (screen.get_number ());
        background_surface.set_device_scale (scale, scale);

        /* Paint our background onto the root window before we close our own window */
        var c = new Cairo.Context (background_surface);
        bg.draw_full (c, Background.DrawFlags.NONE);
        c = null;
        refresh_background (screen, background_surface);

        if (test_mode)
        {
            debug ("Successfully logged in! Quitting...");
            Gtk.main_quit ();
            return true;
        }

        if (!session_is_valid (session))
        {
            debug ("Session %s is not available, using system default %s instead", session, greeter.default_session_hint);
            session = greeter.default_session_hint;
        }

        var result = false;
        try
        {
            result = LightDM.greeter_start_session_sync (greeter, session);
        }
        catch (Error e)
        {
            warning ("Failed to start session: %s", e.message);
        }

        if (result)
            starting_session ();

        return result;
    }

    private bool session_is_valid (string? session)
    {
        if (session == null)
            return true;

        foreach (var s in LightDM.get_sessions ())
            if (s.key == session)
                return true;

        return false;
    }

    private bool ready_cb ()
    {
        debug ("starting system-ready sound");

        /* Launch canberra */
        Canberra.Context.create (out canberra_context);

        if (UGSettings.get_boolean (UGSettings.KEY_PLAY_READY_SOUND))
            canberra_context.play (0,
                                   Canberra.PROP_CANBERRA_XDG_THEME_NAME,
                                   "ubuntu",
                                   Canberra.PROP_EVENT_ID,
                                   "system-ready");

        return false;
    }

    public void show ()
    {
        debug ("Showing main window");
        main_window.show ();
        main_window.get_window ().focus (Gdk.CURRENT_TIME);
        main_window.set_keyboard_state ();
    }

    public bool is_authenticated ()
    {
        return greeter.is_authenticated;
    }

    public void authenticate (string? userid = null)
    {
        greeter.authenticate (userid);
    }

    public void authenticate_as_guest ()
    {
        greeter.authenticate_as_guest ();
    }

    public void authenticate_remote (string? session, string? userid)
    {
        UnityGreeter.singleton.greeter.authenticate_remote (session, userid);
    }

    public void cancel_authentication ()
    {
        greeter.cancel_authentication ();
    }

    public void respond (string response)
    {
        greeter.respond (response);
    }

    public string authentication_user ()
    {
        return greeter.authentication_user;
    }

    public string default_session_hint ()
    {
        return greeter.default_session_hint;
    }

    public string select_user_hint ()
    {
        return greeter.select_user_hint;
    }

    public bool show_manual_login_hint ()
    {
        return greeter.show_manual_login_hint;
    }

    public bool show_remote_login_hint ()
    {
        return greeter.show_remote_login_hint;
    }

    public bool hide_users_hint ()
    {
        return greeter.hide_users_hint;
    }

    public bool has_guest_account_hint ()
    {
        return greeter.has_guest_account_hint;
    }

    private Gdk.FilterReturn focus_upon_map (Gdk.XEvent gxevent, Gdk.Event event)
    {
        var xevent = (X.Event*)gxevent;
        if (xevent.type == X.EventType.MapNotify)
        {
            var display = Gdk.X11.Display.lookup_for_xdisplay (xevent.xmap.display);
            var xwin = xevent.xmap.window;
            var win = new Gdk.X11.Window.foreign_for_display (display, xwin);
            if (win != null && !xevent.xmap.override_redirect)
            {
                /* Check to see if this window is our onboard window, since we don't want to focus it. */
                X.Window keyboard_xid = 0;
                if (main_window.menubar.keyboard_window != null)
                    keyboard_xid = (main_window.menubar.keyboard_window.get_window () as Gdk.X11.Window).get_xid ();

                if (xwin != keyboard_xid && win.get_type_hint() != Gdk.WindowTypeHint.NOTIFICATION)
                {
                    win.focus (Gdk.CURRENT_TIME);

                    /* Make sure to keep keyboard above */
                    if (main_window.menubar.keyboard_window != null)
                        main_window.menubar.keyboard_window.get_window ().raise ();
                }
            }
        }
        else if (xevent.type == X.EventType.UnmapNotify)
        {
            // Since we aren't keeping track of focus (for example, we don't
            // track the Z stack of windows) like a normal WM would, when we
            // decide here where to return focus after another window unmaps,
            // we don't have much to go on.  X will tell us if we should take
            // focus back.  (I could not find an obvious way to determine this,
            // but checking if the X input focus is RevertTo.None seems
            // reliable.)

            X.Window xwin;
            int revert_to;
            xevent.xunmap.display.get_input_focus (out xwin, out revert_to);

            if (revert_to == X.RevertTo.None)
            {
                main_window.get_window ().focus (Gdk.CURRENT_TIME);

                /* Make sure to keep keyboard above */
                if (main_window.menubar.keyboard_window != null)
                    main_window.menubar.keyboard_window.get_window ().raise ();
            }
        }
        return Gdk.FilterReturn.CONTINUE;
    }

    private void start_fake_wm ()
    {
        /* We want new windows (e.g. the shutdown dialog) to gain focus.
           We don't really need anything more than that (don't need alt-tab
           since any dialog should be "modal" or at least dealt with before
           continuing even if not actually marked as modal) */
        var root = Gdk.get_default_root_window ();
        root.set_events (root.get_events () | Gdk.EventMask.SUBSTRUCTURE_MASK);
        root.add_filter (focus_upon_map);
    }

    private static Cairo.XlibSurface? create_root_surface (Gdk.Screen screen)
    {
        var visual = screen.get_system_visual ();

        unowned X.Display display = (screen.get_display () as Gdk.X11.Display).get_xdisplay ();
        unowned X.Screen xscreen = (screen as Gdk.X11.Screen).get_xscreen ();

        var pixmap = X.CreatePixmap (display,
                                     (screen.get_root_window () as Gdk.X11.Window).get_xid (),
                                     xscreen.width_of_screen (),
                                     xscreen.height_of_screen (),
                                     visual.get_depth ());

        /* Convert into a Cairo surface */
        var surface = new Cairo.XlibSurface (display,
                                             pixmap,
                                             (visual as Gdk.X11.Visual).get_xvisual (),
                                             xscreen.width_of_screen (), xscreen.height_of_screen ());

        return surface;
    }

    private static void refresh_background (Gdk.Screen screen, Cairo.XlibSurface surface)
    {
        Gdk.flush ();

        unowned X.Display display = (screen.get_display () as Gdk.X11.Display).get_xdisplay ();

        /* Ensure Cairo has actually finished its drawing */
        surface.flush ();
        /* Use this pixmap for the background */
        X.SetWindowBackgroundPixmap (display,
                                     (screen.get_root_window () as Gdk.X11.Window).get_xid (),
                                     surface.get_drawable ());

        X.ClearWindow (display, (screen.get_root_window () as Gdk.X11.Window).get_xid ());
    }

    private static void log_cb (string? log_domain, LogLevelFlags log_level, string message)
    {
        string prefix;
        switch (log_level & LogLevelFlags.LEVEL_MASK)
        {
        case LogLevelFlags.LEVEL_ERROR:
            prefix = "ERROR:";
            break;
        case LogLevelFlags.LEVEL_CRITICAL:
            prefix = "CRITICAL:";
            break;
        case LogLevelFlags.LEVEL_WARNING:
            prefix = "WARNING:";
            break;
        case LogLevelFlags.LEVEL_MESSAGE:
            prefix = "MESSAGE:";
            break;
        case LogLevelFlags.LEVEL_INFO:
            prefix = "INFO:";
            break;
        case LogLevelFlags.LEVEL_DEBUG:
            prefix = "DEBUG:";
            break;
        default:
            prefix = "LOG:";
            break;
        }

        stderr.printf ("[%+.2fs] %s %s\n", log_timer.elapsed (), prefix, message);
    }

    public static int main (string[] args)
    {
        /* Protect memory from being paged to disk, as we deal with passwords */
        Posix.mlockall (Posix.MCL_CURRENT | Posix.MCL_FUTURE);

        /* Disable the stupid global menubar */
        Environment.unset_variable ("UBUNTU_MENUPROXY");

        /* Initialize i18n */
        Intl.setlocale (LocaleCategory.ALL, "");
        Intl.bindtextdomain (Config.GETTEXT_PACKAGE, Config.LOCALEDIR);
        Intl.bind_textdomain_codeset (Config.GETTEXT_PACKAGE, "UTF-8");
        Intl.textdomain (Config.GETTEXT_PACKAGE);

        /* Set up the accessibility stack, in case the user needs it for screen reading etc. */
        Environment.set_variable ("GTK_MODULES", "atk-bridge", false);

        Pid atspi_pid = 0;
        Pid upstart_pid = 0;

        try
        {
            string[] argv;

            Shell.parse_argv ("/usr/lib/at-spi2-core/at-spi-bus-launcher --launch-immediately", out argv);
            Process.spawn_async (null,
                                 argv,
                                 null,
                                 SpawnFlags.SEARCH_PATH,
                                 null,
                                 out atspi_pid);
        }
        catch (Error e)
        {
            warning ("Error starting the at-spi registry: %s", e.message);
        }

        Gtk.init (ref args);
        Ido.init ();

        log_timer = new Timer ();
        Log.set_default_handler (log_cb);

        debug ("Starting unity-greeter %s UID=%d LANG=%s", Config.VERSION, (int) Posix.getuid (), Environment.get_variable ("LANG"));

        /* Set the cursor to not be the crap default */
        debug ("Setting cursor");
        Gdk.get_default_root_window ().set_cursor (new Gdk.Cursor.for_display (Gdk.Display.get_default (), Gdk.CursorType.LEFT_PTR));

        bool do_show_version = false;
        bool do_test_mode = false;
        OptionEntry versionOption = { "version", 'v', 0, OptionArg.NONE, ref do_show_version,
                /* Help string for command line --version flag */
                N_("Show release version"), null };
        OptionEntry testOption =  { "test-mode", 0, 0, OptionArg.NONE, ref do_test_mode,
                /* Help string for command line --test-mode flag */
                N_("Run in test mode"), null };
        OptionEntry nullOption = { null };
        OptionEntry[] options = { versionOption, testOption, nullOption };

        debug ("Loading command line options");
        var c = new OptionContext (/* Arguments and description for --help text */
                                   _("- Unity Greeter"));
        c.add_main_entries (options, Config.GETTEXT_PACKAGE);
        c.add_group (Gtk.get_option_group (true));
        try
        {
            c.parse (ref args);
        }
        catch (Error e)
        {
            stderr.printf ("%s\n", e.message);
            stderr.printf (/* Text printed out when an unknown command-line argument provided */
                           _("Run '%s --help' to see a full list of available command line options."), args[0]);
            stderr.printf ("\n");
            return Posix.EXIT_FAILURE;
        }
        if (do_show_version)
        {
            /* Note, not translated so can be easily parsed */
            stderr.printf ("unity-greeter %s\n", Config.VERSION);
            return Posix.EXIT_SUCCESS;
        }

        if (do_test_mode)
            debug ("Running in test mode");

        /* Set GTK+ settings */
        debug ("Setting GTK+ settings");
        var settings = Gtk.Settings.get_default ();
        var value = UGSettings.get_string (UGSettings.KEY_THEME_NAME);
        if (value != "")
            settings.set ("gtk-theme-name", value, null);
        value = UGSettings.get_string (UGSettings.KEY_ICON_THEME_NAME);
        if (value != "")
            settings.set ("gtk-icon-theme-name", value, null);
        value = UGSettings.get_string (UGSettings.KEY_FONT_NAME);
        if (value != "")
            settings.set ("gtk-font-name", value, null);
        var double_value = UGSettings.get_double (UGSettings.KEY_XFT_DPI);
        if (double_value != 0.0)
            settings.set ("gtk-xft-dpi", (int) (1024 * double_value), null);
        var boolean_value = UGSettings.get_boolean (UGSettings.KEY_XFT_ANTIALIAS);
        settings.set ("gtk-xft-antialias", boolean_value, null);
        value = UGSettings.get_string (UGSettings.KEY_XFT_HINTSTYLE);
        if (value != "")
            settings.set ("gtk-xft-hintstyle", value, null);
        value = UGSettings.get_string (UGSettings.KEY_XFT_RGBA);
        if (value != "")
            settings.set ("gtk-xft-rgba", value, null);

        debug ("Creating Unity Greeter");
        var greeter = new UnityGreeter (do_test_mode);

        debug ("Showing greeter");
        greeter.show ();

        if (!do_test_mode)
        {
            /* Start the indicator services */
            try
            {
                string[] argv;

                Shell.parse_argv ("upstart --user --startup-event indicator-services-start", out argv);
                Process.spawn_async (null,
                                     argv,
                                     null,
                                     SpawnFlags.SEARCH_PATH,
                                     null,
                                     out upstart_pid);
            }
            catch (Error e)
            {
                warning ("Error starting Upstart for indicators: %s", e.message);
            }

            /* Make nm-applet hide items the user does not have permissions to interact with */
            Environment.set_variable ("NM_APPLET_HIDE_POLICY_ITEMS", "1", true);

            try
            {
                Process.spawn_command_line_async ("nm-applet");
            }
            catch (Error e)
            {
                warning ("Error starting nm-applet: %s", e.message);
            }
        }

        /* Setup a handler for TERM so we quit cleanly */
        GLib.Unix.signal_add(GLib.ProcessSignal.TERM, () => {
            debug("Got a SIGTERM");
            Gtk.main_quit();
            return true;
        });

        debug ("Starting main loop");
        Gtk.main ();

        debug ("Cleaning up");

        if (upstart_pid != 0)
        {
            Posix.kill (upstart_pid, Posix.SIGTERM);
            int status;
            Posix.waitpid (upstart_pid, out status, 0);
            if (Process.if_exited (status))
                debug ("Upstart exited with return value %d", Process.exit_status (status));
            else
                debug ("Upstart terminated with signal %d", Process.term_sig (status));
            upstart_pid = 0;
        }

        if (atspi_pid != 0)
        {
            Posix.kill (atspi_pid, Posix.SIGKILL);
            int status;
            Posix.waitpid (atspi_pid, out status, 0);
            if (Process.if_exited (status))
                debug ("AT-SPI exited with return value %d", Process.exit_status (status));
            else
                debug ("AT-SPI terminated with signal %d", Process.term_sig (status));
            atspi_pid = 0;
        }

        debug ("Exiting");

        return Posix.EXIT_SUCCESS;
    }
}

[DBus (name="org.gnome.SessionManager.EndSessionDialog")]
public class DialogDBusInterface : Object
{
    public signal void open_dialog (uint32 type);
    public signal void close_dialog ();

    public void open (uint32 type, uint32 timestamp, uint32 seconds_to_stay_open, ObjectPath[] inhibitor_object_paths)
    {
        open_dialog (type);
    }

    public void close ()
    {
        close_dialog ();
    }
}
