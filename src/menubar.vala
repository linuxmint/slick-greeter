/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 4 -*-
 *
 * Copyright (C) 2011,2012 Canonical Ltd
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
 * Authors: Robert Ancell <robert.ancell@canonical.com>
 *          Michael Terry <michael.terry@canonical.com>
 */

 namespace UPower {

    [DBus (name = "org.freedesktop.UPower")]
    interface Daemon: Object
    {
        // public abstract async void suspend() throws IOError;
        // public abstract async void hibernate() throws IOError;
        // public abstract bool suspend_allowed() throws IOError;
        // public abstract bool hibernate_allowed() throws IOError;
        public abstract ObjectPath[] enumerate_devices() throws IOError;

        public abstract string daemon_version { owned get; }
        // public abstract bool can_suspend { owned get; }
        // public abstract bool can_hibernate { owned get; }
        public abstract bool on_battery { owned get; }
        public abstract bool on_low_battery { owned get; }
        public abstract bool lid_is_present { owned get; }
        public abstract bool lid_is_closed { owned get; }

        public signal void device_added(ObjectPath device);
        public signal void device_removed(ObjectPath device);
        public signal void device_changed(ObjectPath device);
        public signal void changed();
        public signal void sleeping();
        public signal void resuming();
    }

    [DBus (name = "org.freedesktop.UPower.Device")]
    interface Device: Object
    {
        /* bug here with type and vala get_type() defined two times */
        public abstract uint Type { owned get; }
        public abstract bool power_supply { owned get; }
        public abstract bool online { owned get; }
        public abstract bool is_present { owned get; }
        public abstract uint state { owned get; }
        public abstract bool is_rechargeable { owned get; }
        public abstract double capacity { owned get; }
        public abstract int64 time_to_empty { owned get; }
        public abstract int64 time_to_full { owned get; }
        public abstract double energy { owned get; }
        public abstract double energy_empty { owned get; }
        public abstract double energy_full { owned get; }
        public abstract double energy_full_design { owned get; }
        public abstract double energy_rate { owned get; }
        public abstract double percentage { owned get; }
        public abstract double voltage { owned get; }
        public abstract uint technology { owned get; }
        public abstract string vendor { owned get; }
        public abstract string model { owned get; }
        public abstract string serial { owned get; }

        public signal void changed();
    }
}

public class MenuBar : Gtk.MenuBar
{
    public Background? background { get; construct; default = null; }
    public bool high_contrast { get; private set; default = false; }
    public Gtk.Window? keyboard_window { get; private set; default = null; }
    public Gtk.AccelGroup? accel_group { get; construct; }
    public MainWindow? main_window { get; construct; default = null; }

    private const int HEIGHT = 24;

    public MenuBar (Background bg, Gtk.AccelGroup ag, MainWindow mw)
    {
        Object (background: bg, accel_group: ag, main_window: mw);
    }

    public override bool draw (Cairo.Context c)
    {
        if (background != null)
        {
            int x, y;
            background.translate_coordinates (this, 0, 0, out x, out y);
            c.save ();
            c.translate (x, y);
            background.draw_full (c, Background.DrawFlags.NONE);
            c.restore ();
        }

        c.set_source_rgb (0.1, 0.1, 0.1);
        c.paint_with_alpha (0.4);

        foreach (var child in get_children ())
        {
            propagate_draw (child, c);
        }

        return false;
    }

    /* Due to LP #973922 the keyboard has to be loaded after the main window
     * is shown and given focus. Therefore we don't enable the active state
     * until now.
     */
    public void set_keyboard_state ()
    {
        onscreen_keyboard_item.set_active (UGSettings.get_boolean (UGSettings.KEY_ONSCREEN_KEYBOARD));
    }

    private string default_theme_name;
    private Gtk.CheckMenuItem high_contrast_item;
    private Pid keyboard_pid = 0;
    private Pid reader_pid = 0;
    private Gtk.CheckMenuItem onscreen_keyboard_item;
    private Gtk.Label clock_label;
    private UPower.Daemon upowerd;
    private Gtk.MenuItem power_menu_item;
    private Gtk.Label power_label;
    private Gtk.Image power_icon;


    construct
    {
        Gtk.Settings.get_default ().get ("gtk-theme-name", out default_theme_name);

        pack_direction = Gtk.PackDirection.RTL;

        var session_menu = make_session_item ();
        session_menu.right_justified = true;
        append (session_menu);

        clock_label = new Gtk.Label ("");
        var fg = clock_label.get_style_context ().get_color (Gtk.StateFlags.NORMAL);
        clock_label.override_color (Gtk.StateFlags.INSENSITIVE, fg);
        clock_label.show ();
        var item = new Gtk.MenuItem ();
        item.add (clock_label);
        item.sensitive = false;
        item.show ();
        append (item);

        update_clock ();
        Timeout.add (1000, update_clock);

        power_menu_item = new Gtk.MenuItem ();
        var hbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 3);
        hbox.show ();
        power_icon = new Gtk.Image.from_file (Path.build_filename (Config.PKGDATADIR, "battery.svg"));
        power_icon.show ();
        hbox.add (power_icon);
        hbox.set_spacing (6);
        power_label = new Gtk.Label ("");
        power_label.sensitive = false;
        fg = power_label.get_style_context ().get_color (Gtk.StateFlags.NORMAL);
        power_label.override_color (Gtk.StateFlags.INSENSITIVE, fg);
        power_label.show ();
        hbox.add (power_label);
        power_menu_item.add (hbox);
        power_menu_item.hide ();
        append (power_menu_item);

        var keyboard_menu = make_keyboard_item ();
        append (keyboard_menu);

        try {
            upowerd = Bus.get_proxy_sync(BusType.SYSTEM, "org.freedesktop.UPower", "/org/freedesktop/UPower");
            upowerd.device_added.connect(on_power_device_added);
            upowerd.device_removed.connect(on_power_device_removed);
            upowerd.device_changed.connect(on_power_device_changed);
            upowerd.changed.connect(on_changed);
            upowerd.sleeping.connect(on_sleeping);
            upowerd.resuming.connect(on_resuming);
            query_upower_daemon ();
            Timeout.add (60000, query_upower_daemon);
        } catch (IOError e) {
            warning("Could not connect to Upower: %s", e.message);
        }

        var a11y_item = make_a11y_item ();
        append (a11y_item);

        if (UGSettings.get_boolean (UGSettings.KEY_SHOW_HOSTNAME))
        {
            var label = new Gtk.Label (Posix.utsname ().nodename);
            fg = label.get_style_context ().get_color (Gtk.StateFlags.NORMAL);
            label.override_color (Gtk.StateFlags.INSENSITIVE, fg);
            label.show ();
            var hostname_item = new Gtk.MenuItem ();
            hostname_item.add (label);
            hostname_item.sensitive = false;
            hostname_item.right_justified = true;
            hostname_item.show ();
            append (hostname_item);
        }

        /* Prevent dragging the window by the menubar */
        try
        {
            var style = new Gtk.CssProvider ();
            style.load_from_data ("* {-GtkWidget-window-dragging: false;}", -1);
            get_style_context ().add_provider (style, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        }
        catch (Error e)
        {
            debug ("Internal error loading menubar style: %s", e.message);
        }

        SlickGreeter.singleton.starting_session.connect (cleanup);
    }

    void on_sleeping ()
    {
    }

    void on_resuming ()
    {
        query_upower_daemon ();
    }

    void on_changed ()
    {
        query_upower_daemon ();
    }

    void on_power_device_added(ObjectPath device)
    {
        query_upower_device.begin (device);
    }

    void on_power_device_changed(ObjectPath device)
    {
        query_upower_device.begin (device);
    }

    private bool query_upower_daemon ()
    {
        try {
            if (upowerd.on_battery == true) {
                foreach (ObjectPath o in upowerd.enumerate_devices()) {
                    query_upower_device.begin(o);
                }
            }
            else {
                power_menu_item.hide ();
            }
        }
        catch (Error e) {
            warning ("Error while querying upower daemon: %s", e.message);
        }
        return true;
    }

    async void query_upower_device(ObjectPath dev_path)
    {
        UPower.Device dev;

        /* connect to the dbus device object */
        try {
            dev = Bus.get_proxy_sync(BusType.SYSTEM, "org.freedesktop.UPower", dev_path);
        } catch (IOError io) {
            warning("Could not connect to UPower/Device: %s", io.message);
            return;
        }

        /* type of the power device */
        uint type = dev.Type;
        if(type == 1) { /* Line Power providing energy */
        } else if(type == 2 && dev.is_present == true) { /* Battery */
            update_power (dev);
        } else if(type == 3) { /* UPS */
        } else if(type == 5) { /* Mouse */
        } else if(type == 6) { /* Keyboard */
        } else if(type == 7) { /* PDA */
        } else if(type == 8) { /* Phone */
        }
    }

    void on_power_device_removed(ObjectPath device)
    {
        query_upower_daemon ();
    }

    private void update_power (UPower.Device? device)
    {
        if (device == null) {
            power_menu_item.hide ();
        }
        else {
            char[] buffer = new char[double.DTOSTR_BUF_SIZE];
            unowned string str = device.percentage.to_str (buffer);
            power_label.set_label(str.concat("%"));
            var icon = "battery.svg";
            if (device.percentage <= 50.0) {
                icon = "battery_50.svg";
            }
            if (device.percentage <= 25.0) {
                icon = "battery_25.svg";
            }
            if (device.percentage <= 10.0) {
                icon = "battery_10.svg";
            }
            power_icon.set_from_file (Path.build_filename (Config.PKGDATADIR, icon));
            power_menu_item.show ();
        }
    }

    private bool update_clock ()
    {
        var current_time = new DateTime.now_local ();
        clock_label.set_label(current_time.format ("%H:%M"));
        return true;
    }

    private void close_pid (ref Pid pid)
    {
        if (pid > 0)
        {
            Posix.kill (pid, Posix.SIGTERM);
            int status;
            Posix.waitpid (pid, out status, 0);
            pid = 0;
        }
    }

    public void cleanup ()
    {
        close_pid (ref keyboard_pid);
        close_pid (ref reader_pid);
    }

    public override void get_preferred_height (out int min, out int nat)
    {
        min = HEIGHT;
        nat = HEIGHT;
    }

    private Gtk.MenuItem make_a11y_item ()
    {
        var a11y_item = new Gtk.MenuItem ();
        var hbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 3);
        hbox.show ();
        a11y_item.add (hbox);
        var image = new Gtk.Image.from_file (Path.build_filename (Config.PKGDATADIR, "a11y.svg"));
        image.show ();
        hbox.add (image);
        a11y_item.show ();
        a11y_item.set_submenu (new Gtk.Menu () as Gtk.Widget);
        onscreen_keyboard_item = new Gtk.CheckMenuItem.with_label (_("Onscreen keyboard"));
        onscreen_keyboard_item.toggled.connect (keyboard_toggled_cb);
        onscreen_keyboard_item.show ();
        unowned Gtk.Menu submenu = a11y_item.submenu;
        submenu.append (onscreen_keyboard_item);
        high_contrast_item = new Gtk.CheckMenuItem.with_label (_("High Contrast"));
        high_contrast_item.toggled.connect (high_contrast_toggled_cb);
        high_contrast_item.add_accelerator ("activate", accel_group, Gdk.Key.h, Gdk.ModifierType.CONTROL_MASK, Gtk.AccelFlags.VISIBLE);
        high_contrast_item.show ();
        submenu.append (high_contrast_item);
        high_contrast_item.set_active (UGSettings.get_boolean (UGSettings.KEY_HIGH_CONTRAST));
        var item = new Gtk.CheckMenuItem.with_label (_("Screen Reader"));
        item.toggled.connect (screen_reader_toggled_cb);
        item.add_accelerator ("activate", accel_group, Gdk.Key.s, Gdk.ModifierType.SUPER_MASK | Gdk.ModifierType.MOD1_MASK, Gtk.AccelFlags.VISIBLE);
        item.show ();
        submenu.append (item);
        item.set_active (UGSettings.get_boolean (UGSettings.KEY_SCREEN_READER));
        return a11y_item;
    }

    private Gtk.MenuItem make_session_item ()
    {
        var item = new Gtk.MenuItem ();
        var hbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 3);
        hbox.show ();
        item.add (hbox);
        var image = new Gtk.Image.from_file (Path.build_filename (Config.PKGDATADIR, "shutdown.svg"));
        image.show ();
        hbox.add (image);
        item.show ();
        item.set_submenu (new Gtk.Menu () as Gtk.Widget);
        unowned Gtk.Menu submenu = item.submenu;

        if (LightDM.get_can_suspend ())
        {
            Gtk.MenuItem menu_item = new Gtk.MenuItem.with_label (_("Suspend"));
            menu_item.show ();
            submenu.append (menu_item);
            menu_item.activate.connect (() =>
            {
                try
                {
                    LightDM.suspend ();
                }
                catch (Error e)
                {
                    warning ("Failed to suspend: %s", e.message);
                }
            });
        }

        if (LightDM.get_can_hibernate ())
        {
            Gtk.MenuItem menu_item = new Gtk.MenuItem.with_label (_("Hibernate"));
            menu_item.show ();
            submenu.append (menu_item);
            menu_item.activate.connect (() =>
            {
                try
                {
                    LightDM.hibernate ();
                }
                catch (Error e)
                {
                    warning ("Failed to hibernate: %s", e.message);
                }
            });
        }

        Gtk.MenuItem menu_item = new Gtk.MenuItem.with_label (_("Quit..."));
        menu_item.activate.connect (shutdown_cb);
        menu_item.show ();
        submenu.append (menu_item);

        return item;
    }

    private Gtk.MenuItem make_keyboard_item ()
    {
        var item = new Gtk.MenuItem ();
        var hbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 3);
        hbox.show ();
        item.add (hbox);
        var image = new Gtk.Image.from_file (Path.build_filename (Config.PKGDATADIR, "keyboard.svg"));
        image.show ();
        hbox.add (image);
        hbox.set_spacing (6);
        var label = new Gtk.Label ("");
        label.sensitive = false;
        var current_layout = LightDM.get_layout ();
        if (current_layout != null) {
            label.set_label (current_layout.name);
        }
        var fg = label.get_style_context ().get_color (Gtk.StateFlags.NORMAL);
        label.override_color (Gtk.StateFlags.INSENSITIVE, fg);
        label.show ();
        hbox.add (label);
        item.show ();

        return item;
    }

    private void shutdown_cb (Gtk.MenuItem item)
    {
        if (main_window != null) {
            main_window.show_shutdown_dialog (ShutdownDialogType.RESTART);
        }
    }

    private void keyboard_toggled_cb (Gtk.CheckMenuItem item)
    {
        /* FIXME: The below would be sufficient if gnome-session were running
         * to notice and run a screen keyboard in /etc/xdg/autostart...  But
         * since we're not running gnome-session, we hardcode onboard here. */
        /* var settings = new Settings ("org.gnome.desktop.a11y.applications");*/
        /*settings.set_boolean ("screen-keyboard-enabled", item.active);*/

        UGSettings.set_boolean (UGSettings.KEY_ONSCREEN_KEYBOARD, item.active);

        if (keyboard_window == null)
        {
            int id = 0;

            try
            {
                string[] argv;
                int onboard_stdout_fd;

                Shell.parse_argv ("onboard --xid", out argv);
                Process.spawn_async_with_pipes (null,
                                                argv,
                                                null,
                                                SpawnFlags.SEARCH_PATH,
                                                null,
                                                out keyboard_pid,
                                                null,
                                                out onboard_stdout_fd,
                                                null);
                var f = FileStream.fdopen (onboard_stdout_fd, "r");
                var stdout_text = new char[1024];
                if (f.gets (stdout_text) != null)
                    id = int.parse ((string) stdout_text);

            }
            catch (Error e)
            {
                warning ("Error setting up keyboard: %s", e.message);
                return;
            }

            var keyboard_socket = new Gtk.Socket ();
            keyboard_socket.show ();
            keyboard_window = new Gtk.Window ();
            keyboard_window.accept_focus = false;
            keyboard_window.focus_on_map = false;
            keyboard_window.add (keyboard_socket);
            keyboard_socket.add_id (id);

            /* Put keyboard at the bottom of the screen */
            var screen = get_screen ();
            var monitor = screen.get_monitor_at_window (get_window ());
            Gdk.Rectangle geom;
            screen.get_monitor_geometry (monitor, out geom);
            keyboard_window.move (geom.x, geom.y + geom.height - 250);
            keyboard_window.resize (geom.width, 250);
        }

        keyboard_window.visible = item.active;
    }

    private void high_contrast_toggled_cb (Gtk.CheckMenuItem item)
    {
        var settings = Gtk.Settings.get_default ();
        if (item.active)
            settings.set ("gtk-theme-name", "HighContrast");
        else
            settings.set ("gtk-theme-name", default_theme_name);
        high_contrast = item.active;
        UGSettings.set_boolean (UGSettings.KEY_HIGH_CONTRAST, high_contrast);
    }

    private void screen_reader_toggled_cb (Gtk.CheckMenuItem item)
    {
        UGSettings.set_boolean (UGSettings.KEY_SCREEN_READER, item.active);

        if (item.active)
        {
            try
            {
                string[] argv;
                Shell.parse_argv ("orca --replace", out argv);
                Process.spawn_async (null,
                                     argv,
                                     null,
                                     SpawnFlags.SEARCH_PATH,
                                     null,
                                     out reader_pid);
                // This is a workaroud for bug https://launchpad.net/bugs/944159
                // The problem is that orca seems to not notice that it's in a
                // password field on startup.  We just need to kick orca in the
                // pants.  We do this two ways:  a racy way and a non-racy way.
                // We kick it after a second which is ideal if we win the race,
                // because the user gets to hear what widget they are in, and
                // the first character will be masked.  Otherwise, if we lose
                // that race, the first time the user types (see
                // DashEntry.key_press_event), we will kick orca again.  While
                // this is not racy with orca startup, it is racy with whether
                // orca will read the first character or not out loud.  Hence
                // why we do both.  Ideally this would be fixed in orca itself.
                SlickGreeter.singleton.orca_needs_kick = true;
                Timeout.add_seconds (1, () => {
                    Signal.emit_by_name ((get_toplevel () as Gtk.Window).get_focus ().get_accessible (), "focus-event", true);
                    return false;
                });
            }
            catch (Error e)
            {
                warning ("Failed to run Orca: %s", e.message);
            }
        }
        else
            close_pid (ref reader_pid);
    }

}
