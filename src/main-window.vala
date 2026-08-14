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

public class MainWindow : Gtk.Window
{
    public MenuBar menubar;

    private List<Monitor> monitors;
    private Monitor? primary_monitor;
    private Monitor active_monitor;
    private string only_on_monitor;
    private bool monitor_setting_ok;
    private Background background;
    private IdleClockOverlay idle_clock_overlay;
    private Gtk.Box login_box;
    private Gtk.Box hbox;
    private Gtk.Box content_box;
    private Gtk.Button back_button;
    private ShutdownDialog? shutdown_dialog = null;
    private bool do_resize;
    private bool idle_clock_enabled;
    private bool login_presentation_active;
    private double login_presentation_progress;
    private double login_presentation_start;
    private double login_presentation_target;
    private AnimateTimer login_presentation_timer;
    private int login_transition_duration;
    private string pending_login_text = "";

    public ListStack stack;

    // Menubar is smaller, but with shadow, we reserve more space
    public const int MENUBAR_HEIGHT = 32;
    private const int LOGIN_UI_SLIDE_OFFSET = 24;

    construct
    {
        events |= Gdk.EventMask.POINTER_MOTION_MASK;

        var accel_group = new Gtk.AccelGroup ();
        add_accel_group (accel_group);

        var bg_color = Gdk.RGBA ();
        bg_color.parse (UGSettings.get_string (UGSettings.KEY_BACKGROUND_COLOR));
        override_background_color (Gtk.StateFlags.NORMAL, bg_color);
        get_accessible ().set_name (_("Login Screen"));
        has_resize_grip = false;
        SlickGreeter.add_style_class (this);

        background = new Background ();
        add (background);
        SlickGreeter.add_style_class (background);

        idle_clock_overlay = new IdleClockOverlay ();
        idle_clock_overlay.show ();
        background.add (idle_clock_overlay);

        login_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        login_box.show ();
        background.add (login_box);

        /* Box for menubar shadow */
        var menubox = new Gtk.EventBox ();
        var menualign = new Gtk.Alignment (0.0f, 0.0f, 1.0f, 0.0f);
        var shadow_path = Path.build_filename (Config.PKGDATADIR,
                                               "shadow.png", null);
        var shadow_style = "";
        if (FileUtils.test (shadow_path, FileTest.EXISTS))
        {
            shadow_style = "background-image: url('%s');background-repeat: repeat;".printf(shadow_path);
        }
        try
        {
            var style = new Gtk.CssProvider ();
            style.load_from_data ("* {background-color: transparent;%s}".printf(shadow_style), -1);
            var context = menubox.get_style_context ();
            context.add_provider (style,
                                  Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        }
        catch (Error e)
        {
            debug ("Internal error loading menubox style: %s", e.message);
        }
        menubox.set_size_request (-1, MENUBAR_HEIGHT);
        menubox.show ();
        menualign.show ();
        menubox.add (menualign);
        login_box.add (menubox);
        SlickGreeter.add_style_class (menualign);
        SlickGreeter.add_style_class (menubox);

        menubar = new MenuBar (background, accel_group, this);
        menubar.show ();
        menualign.add (menubar);
        SlickGreeter.add_style_class (menubar);

        content_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        content_box.expand = true;
        content_box.show ();
        login_box.add (content_box);

        var content_align = UGSettings.get_string(UGSettings.KEY_CONTENT_ALIGN);
        var x_align = 0.5f;

        if (content_align == "left")
        {
            x_align = 0.0f;
        }
        else if (content_align == "right")
        {
            x_align = 1.0f;
        }

        var align = new Gtk.Alignment (x_align, 0.0f, 0.0f, 1.0f);

        if (content_align == "center")
        {
            // offset for back button
            align.margin_right = grid_size;
        }

        align.show ();
        content_box.add (align);

        hbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        hbox.expand = true;
        hbox.show ();
        align.add (hbox);

        align = new Gtk.Alignment (0.5f, 0.5f, 0.0f, 0.0f);
        // Hack to avoid gtk 3.20's new allocate logic, which messes us up.
        align.resize_mode = Gtk.ResizeMode.QUEUE;
        align.set_size_request (grid_size, -1);
        align.margin_bottom = MENUBAR_HEIGHT; /* offset for menubar at top */
        align.show ();
        hbox.add (align);

        back_button = new FlatButton ();
        back_button.get_accessible ().set_name (_("Back"));
        Gtk.button_set_focus_on_click (back_button, false);
        var image = new Gtk.Image.from_file (Path.build_filename (Config.PKGDATADIR, "arrow_left.svg", null));
        image.show ();
        back_button.set_size_request (grid_size - GreeterList.BORDER * 2, grid_size - GreeterList.BORDER * 2);
        back_button.add (image);
        back_button.clicked.connect (pop_list);
        align.add (back_button);

        align = new Gtk.Alignment (0.0f, 0.5f, 0.0f, 1.0f);
        align.show ();
        hbox.add (align);

        stack = new ListStack ();
        stack.show ();
        align.add (stack);

        add_user_list ();

        idle_clock_enabled = UGSettings.get_boolean (UGSettings.KEY_IDLE_CLOCK_ENABLED);
        login_presentation_active = !idle_clock_enabled;
        login_presentation_progress = login_presentation_active ? 1.0 : 0.0;
        login_presentation_start = login_presentation_progress;
        login_presentation_target = login_presentation_progress;
        login_transition_duration = UGSettings.get_integer (UGSettings.KEY_LOGIN_TRANSITION_DURATION).clamp (0, 1000);
        login_presentation_timer = new AnimateTimer (AnimateTimer.ease_in_out, login_transition_duration);
        login_presentation_timer.animate.connect (animate_login_presentation);
        set_login_presentation_progress (login_presentation_progress);
        SlickGreeter.singleton.show_prompt.connect (() =>
        {
            Idle.add (() =>
            {
                flush_pending_login_text ();
                return false;
            });
        });

        primary_monitor = null;
        do_resize = false;

        only_on_monitor = UGSettings.get_string(UGSettings.KEY_ONLY_ON_MONITOR);
        monitor_setting_ok = only_on_monitor == "auto";

        if (SlickGreeter.singleton.test_mode)
        {
            /* Simulate an 800x600 monitor to the left of a 640x480 monitor */
            monitors = new List<Monitor> ();
            monitors.append (new Monitor (0, 0, 800, 600));
            monitors.append (new Monitor (800, 120, 640, 480));
            background.set_monitors (monitors);
            move_to_monitor (monitors.nth_data (0));
            resize (background.width, background.height);
        }
        else
        {
            var screen = get_screen ();
            screen.monitors_changed.connect (monitors_changed_cb);
            monitors_changed_cb (screen);
        }

        /* Force a call on login_box.show()...
            This fixes the following issue:
            When the greeter starts, the login box looks too small, its entry isn't visible and
            its session button isn't sensitive/clickable.
            Pressing Escape fixes the box but not the session button..
            Scrolling up/down fixes both..
        */
        if (login_box.sensitive) {
            login_box.show();
        }
    }

    public void push_list (GreeterList widget)
    {
        stack.push (widget);

        if (stack.num_children > 1)
            back_button.show ();
    }

    public void pop_list ()
    {
        if (stack.num_children <= 2)
            back_button.hide ();

        stack.pop ();
    }

    public override void size_allocate (Gtk.Allocation allocation)
    {
        base.size_allocate (allocation);

        if (content_box != null)
        {
            var content_align = UGSettings.get_string(UGSettings.KEY_CONTENT_ALIGN);
            content_box.margin_left = get_grid_offset (get_allocated_width ()) + (content_align == "left" ? grid_size : 0);
            content_box.margin_right = get_grid_offset (get_allocated_width ()) + (content_align == "right" ? grid_size : 0);
            content_box.margin_top = get_grid_offset (get_allocated_height ());
            content_box.margin_bottom = get_grid_offset (get_allocated_height ());
            apply_login_presentation ();
        }
        
        position_elements ();
    }

    private void position_elements ()
    {
        if (active_monitor == null)
            return;

        /* Idle clock centered on the monitor */
        background.move (idle_clock_overlay, active_monitor.x, active_monitor.y);
        idle_clock_overlay.set_size_request (active_monitor.width, active_monitor.height);

        /* Login UI centered on the monitor */
        var login_width = 400; // Example width
        var login_height = 300; // Example height
        var x = active_monitor.x + (active_monitor.width - login_width) / 2;
        var y = active_monitor.y + (active_monitor.height - login_height) / 2;
        background.move (login_box, x, y);
        login_box.set_size_request (login_width, login_height);
    }

    public override void realize ()
    {
        base.realize ();
        background.set_surface (Gdk.cairo_create (get_window ()).get_target ());
    }

    public void before_session_start()
    {
        debug ("Killing orca and onboard");
        menubar.cleanup();
    }

    /* Setup the size and position of the window */
    public void setup_window ()
    {
        resize (background.width, background.height);
        move (0, 0);
        move_to_monitor (primary_monitor);
    }

    private void monitors_changed_cb (Gdk.Screen screen)
    {
        Gdk.Display display = screen.get_display();
        Gdk.Monitor primary = display.get_primary_monitor();
        Gdk.Rectangle geometry;

        monitors = new List<Monitor> ();
        primary_monitor = null;

        for (var i = 0; i < display.get_n_monitors (); i++)
        {
            Gdk.Monitor monitor = display.get_monitor(i);
            geometry = monitor.get_geometry ();
            debug ("Monitor %d is %dx%d pixels at %d,%d", i, geometry.width, geometry.height, geometry.x, geometry.y);

            if (monitor_is_unique_position (display, i))
            {
                var greeter_monitor = new Monitor (geometry.x, geometry.y, geometry.width, geometry.height);
                var plug_name = monitor.get_model();
                monitors.append (greeter_monitor);

                if (plug_name == only_on_monitor)
                    monitor_setting_ok = true;

                if (plug_name == only_on_monitor || primary_monitor == null || primary == monitor)
                    primary_monitor = greeter_monitor;
            }
        }

        debug ("MainWindow is %dx%d pixels", background.width, background.height);

        background.set_monitors (monitors);

        if(do_resize)
        {
            setup_window ();
        }
        else
        {
            do_resize = true;
        }
    }

    /* Check if a monitor has a unique position */
    private bool monitor_is_unique_position (Gdk.Display display, int n)
    {
        Gdk.Rectangle g0;
        Gdk.Monitor mon0;
        mon0 = display.get_monitor(n);
        g0 = mon0.get_geometry ();

        for (var i = n + 1; i < display.get_n_monitors (); i++)
        {
            Gdk.Rectangle g1;
            Gdk.Monitor mon1;
            mon1 = display.get_monitor(i);
            g1 = mon1.get_geometry();

            if (g0.x == g1.x && g0.y == g1.y)
                return false;
        }

        return true;
    }

    public override bool motion_notify_event (Gdk.EventMotion event)
    {
        if (!monitor_setting_ok || only_on_monitor == "auto")
        {
            var x = (int) (event.x + 0.5);
            var y = (int) (event.y + 0.5);

            /* Get motion event relative to this widget */
            if (event.window != get_window ())
            {
                int w_x, w_y;
                get_window ().get_origin (out w_x, out w_y);
                x -= w_x;
                y -= w_y;
                event.window.get_origin (out w_x, out w_y);
                x += w_x;
                y += w_y;
            }

            foreach (var m in monitors)
            {
                if (x >= m.x && x <= m.x + m.width && y >= m.y && y <= m.y + m.height)
                {
                    move_to_monitor (m);
                    break;
                }
            }
        }

        return false;
    }

    private void move_to_monitor (Monitor monitor)
    {
        active_monitor = monitor;
        background.set_active_monitor (monitor);
        position_elements ();

        if (shutdown_dialog != null)
        {
            shutdown_dialog.set_active_monitor (monitor);
            background.move (shutdown_dialog, monitor.x, monitor.y);
        }
    }

    private void add_user_list ()
    {
        GreeterList greeter_list;
        greeter_list = new UserList (background, menubar);
        greeter_list.show ();
        SlickGreeter.add_style_class (greeter_list);
        
        // Connect Background to DashBox transitions for synchronized redraws
        background.connect_to_dashbox_transitions (greeter_list.greeter_box);
        
        push_list (greeter_list);
    }

    public override bool key_press_event (Gdk.EventKey event)
    {
        var top = stack.top ();
        var activated_login = false;

        if (should_activate_login_presentation (event))
        {
            set_login_presentation_active (true);
            activated_login = true;
        }

        if ((activated_login || pending_login_text != "") && buffer_login_text_if_needed (event))
            return true;

        if (stack.top () is UserList)
        {
            var user_list = stack.top () as UserList;
            var shift_mask = Gdk.ModifierType.CONTROL_MASK | Gdk.ModifierType.MOD1_MASK;
            var control_mask = Gdk.ModifierType.SHIFT_MASK | Gdk.ModifierType.MOD1_MASK;
            var alt_mask = Gdk.ModifierType.CONTROL_MASK | Gdk.ModifierType.SHIFT_MASK;
            if (((event.keyval == Gdk.Key.Shift_L || event.keyval == Gdk.Key.Shift_R) && (event.state & shift_mask) == shift_mask) ||
                ((event.keyval == Gdk.Key.Control_L || event.keyval == Gdk.Key.Control_R) && (event.state & control_mask) == control_mask) ||
                ((event.keyval == Gdk.Key.Alt_L || event.keyval == Gdk.Key.Alt_R) && (event.state & alt_mask) == alt_mask))
            {
                debug ("Hidden user key combination detected");
                user_list.show_hidden_users = ! user_list.show_hidden_users;
                return true;
            }
        }
        else if (stack.top () is SessionList) {
            // Session list is open
            switch (event.keyval) {
                case Gdk.Key.Escape:
                case Gdk.Key.Left:
                case Gdk.Key.KP_Left:
                    pop_list();
                    return true;
            }
        }

        switch (event.keyval)
        {
        case Gdk.Key.Escape:
            var had_shutdown_dialog = shutdown_dialog != null;
            if (login_box.sensitive)
                top.cancel_authentication ();
            if (shutdown_dialog != null)
                shutdown_dialog.cancel ();
            if (!had_shutdown_dialog)
                set_login_presentation_active (false);
            return true;
        case Gdk.Key.Page_Up:
        case Gdk.Key.KP_Page_Up:
            if (login_box.sensitive)
                top.scroll (GreeterList.ScrollTarget.START);
            return true;
        case Gdk.Key.Page_Down:
        case Gdk.Key.KP_Page_Down:
            if (login_box.sensitive)
                top.scroll (GreeterList.ScrollTarget.END);
            return true;
        case Gdk.Key.Up:
        case Gdk.Key.KP_Up:
            if (login_box.sensitive)
                top.scroll (GreeterList.ScrollTarget.UP);
            return true;
        case Gdk.Key.Down:
        case Gdk.Key.KP_Down:
            if (login_box.sensitive)
                top.scroll (GreeterList.ScrollTarget.DOWN);
            return true;
        case Gdk.Key.F10:
            if (login_box.sensitive)
                menubar.select_first (false);
            return true;
        case Gdk.Key.PowerOff:
            show_shutdown_dialog (ShutdownDialogType.SHUTDOWN);
            return true;
        case Gdk.Key.Print:
            debug ("Taking screenshot");
            var root = Gdk.get_default_root_window ();
            var screenshot = Gdk.pixbuf_get_from_window (root, 0, 0, root.get_width (), root.get_height ());
            try
            {
                screenshot.save ("Screenshot.png", "png", null);
            }
            catch (Error e)
            {
                warning ("Failed to save screenshot: %s", e.message);
            }
            return true;
        case Gdk.Key.z:
            if (SlickGreeter.singleton.test_mode && (event.state & Gdk.ModifierType.MOD1_MASK) != 0)
            {
                show_shutdown_dialog (ShutdownDialogType.SHUTDOWN);
                return true;
            }
            break;
        case Gdk.Key.Z:
            if (SlickGreeter.singleton.test_mode && (event.state & Gdk.ModifierType.MOD1_MASK) != 0)
            {
                show_shutdown_dialog (ShutdownDialogType.RESTART);
                return true;
            }
            break;
        }

        return base.key_press_event (event);
    }

    private void animate_login_presentation (double progress)
    {
        var current = login_presentation_start + (login_presentation_target - login_presentation_start) * progress;
        set_login_presentation_progress (current);
    }

    private void set_login_presentation_active (bool active)
    {
        if (!idle_clock_enabled)
            return;

        if (login_presentation_active == active && !login_presentation_timer.is_running)
            return;

        login_presentation_active = active;
        login_presentation_start = login_presentation_progress;
        login_presentation_target = active ? 1.0 : 0.0;

        if (!active)
            pending_login_text = "";

        if (active && stack != null && stack.top () != null)
            stack.top ().grab_focus ();

        if (login_transition_duration == 0)
            set_login_presentation_progress (login_presentation_target);
        else
            login_presentation_timer.reset (login_transition_duration);
    }

    private void set_login_presentation_progress (double progress)
    {
        login_presentation_progress = progress.clamp (0.0, 1.0);
        apply_login_presentation ();
    }

    private void apply_login_presentation ()
    {
        if (idle_clock_overlay != null)
            idle_clock_overlay.progress = idle_clock_enabled ? login_presentation_progress : 0.0;

        if (content_box != null)
        {
            content_box.opacity = idle_clock_enabled ? login_presentation_progress : 1.0;
            content_box.queue_draw ();
        }

        if (hbox != null)
        {
            hbox.margin_top = idle_clock_enabled ? (int) Math.round ((1.0 - login_presentation_progress) * LOGIN_UI_SLIDE_OFFSET) : 0;
            hbox.queue_resize ();
        }
    }

    private bool should_activate_login_presentation (Gdk.EventKey event)
    {
        if (!idle_clock_enabled || login_presentation_active || shutdown_dialog != null || !login_box.sensitive)
            return false;

        if (is_modifier_only_key (event.keyval) ||
            event.keyval == Gdk.Key.Escape ||
            event.keyval == Gdk.Key.Print ||
            event.keyval == Gdk.Key.PowerOff ||
            (event.keyval >= Gdk.Key.F1 && event.keyval <= Gdk.Key.F12))
            return false;

        if (has_command_modifier (event))
            return false;

        switch (event.keyval)
        {
        case Gdk.Key.Return:
        case Gdk.Key.KP_Enter:
        case Gdk.Key.Tab:
        case Gdk.Key.ISO_Left_Tab:
        case Gdk.Key.BackSpace:
        case Gdk.Key.Delete:
        case Gdk.Key.Up:
        case Gdk.Key.KP_Up:
        case Gdk.Key.Down:
        case Gdk.Key.KP_Down:
        case Gdk.Key.Page_Up:
        case Gdk.Key.KP_Page_Up:
        case Gdk.Key.Page_Down:
        case Gdk.Key.KP_Page_Down:
            return true;
        }

        var key_unichar = Gdk.keyval_to_unicode (event.keyval);
        return key_unichar >= 0x20 && key_unichar != 0x7f;
    }

    private bool buffer_login_text_if_needed (Gdk.EventKey event)
    {
        if (pending_login_text == "" && get_focus () is Gtk.Entry)
            return false;

        string text;
        if (!key_event_to_text (event, out text))
            return false;

        // If PAM has not produced the prompt yet, keep early password text
        // instead of letting it disappear during the idle-to-login transition.
        pending_login_text += text;
        return true;
    }

    private bool key_event_to_text (Gdk.EventKey event, out string text)
    {
        text = "";

        if (has_command_modifier (event))
            return false;

        var key_unichar = Gdk.keyval_to_unicode (event.keyval);
        if (key_unichar < 0x20 || key_unichar == 0x7f)
            return false;

        text = ((unichar) key_unichar).to_string ();
        return text != "";
    }

    private void flush_pending_login_text ()
    {
        if (pending_login_text == "")
            return;

        if (!(get_focus () is Gtk.Entry) && stack != null && stack.top () != null)
            stack.top ().grab_focus ();

        var entry = get_focus () as Gtk.Entry;
        if (entry == null)
            return;

        entry.text += pending_login_text;
        entry.set_position (-1);
        pending_login_text = "";
    }

    private bool has_command_modifier (Gdk.EventKey event)
    {
        var command_modifiers = Gdk.ModifierType.CONTROL_MASK |
                                Gdk.ModifierType.MOD1_MASK |
                                Gdk.ModifierType.SUPER_MASK |
                                Gdk.ModifierType.HYPER_MASK |
                                Gdk.ModifierType.META_MASK;
        return (event.state & command_modifiers) != 0;
    }

    private bool is_modifier_only_key (uint keyval)
    {
        switch (keyval)
        {
        case Gdk.Key.Shift_L:
        case Gdk.Key.Shift_R:
        case Gdk.Key.Control_L:
        case Gdk.Key.Control_R:
        case Gdk.Key.Alt_L:
        case Gdk.Key.Alt_R:
        case Gdk.Key.Super_L:
        case Gdk.Key.Super_R:
        case Gdk.Key.Hyper_L:
        case Gdk.Key.Hyper_R:
        case Gdk.Key.Meta_L:
        case Gdk.Key.Meta_R:
        case Gdk.Key.Caps_Lock:
        case Gdk.Key.Num_Lock:
        case Gdk.Key.Scroll_Lock:
        case Gdk.Key.ISO_Level3_Shift:
            return true;
        default:
            return false;
        }
    }

    public void set_keyboard_state ()
    {
        menubar.set_keyboard_state ();
    }

    public void show_shutdown_dialog (ShutdownDialogType type)
    {
        if (shutdown_dialog != null)
            shutdown_dialog.destroy ();

        /* Stop input to login box */
        login_box.sensitive = false;

        shutdown_dialog = new ShutdownDialog (type, background);
        shutdown_dialog.closed.connect (close_shutdown_dialog);
        background.add (shutdown_dialog);
        move_to_monitor (active_monitor);
        shutdown_dialog.visible = true;
    }

    public void close_shutdown_dialog ()
    {
        if (shutdown_dialog == null)
            return;

        shutdown_dialog.destroy ();
        shutdown_dialog = null;

        login_box.sensitive = true;
    }
}
