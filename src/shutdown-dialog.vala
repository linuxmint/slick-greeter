/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 4 -*-
 *
 * Copyright (C) 2013 Canonical Ltd
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
 *          Marco Trevisan <marco.trevisan@canonical.com>
 */

public enum ShutdownDialogType
{
    LOGOUT,
    SHUTDOWN,
    RESTART
}

public class ShutdownDialog : Gtk.Fixed
{
    public signal void closed ();

    private Cairo.ImageSurface? bg_surface = null;
    private Cairo.ImageSurface? corner_surface = null;
    private Cairo.ImageSurface? left_surface = null;
    private Cairo.ImageSurface? top_surface = null;
    private Cairo.Pattern? corner_pattern = null;
    private Cairo.Pattern? left_pattern = null;
    private Cairo.Pattern? top_pattern = null;

    private const int BORDER_SIZE = 30;
    private const int BORDER_INTERNAL_SIZE = 10;
    private const int BORDER_EXTERNAL_SIZE = BORDER_SIZE - BORDER_INTERNAL_SIZE;
    private const int CLOSE_OFFSET = 3;
    private const int BUTTON_TEXT_SPACE = 9;
    private const int BLUR_RADIUS = 8;

    private Monitor monitor;
    private weak Background background;
    private Gdk.RGBA avg_color;

    private Gtk.Box vbox;
    private DialogButton close_button;
    private Gtk.Box button_box;
    private Gtk.EventBox monitor_events;
    private Gtk.EventBox vbox_events;

    private AnimateTimer animation;
    private bool closing = false;


    public ShutdownDialog (ShutdownDialogType type, Background bg)
    {
        background = bg;
        background.notify["alpha"].connect (rebuild_background);
        background.notify["average-color"].connect (update_background_color);
        update_background_color ();

        // This event box covers the monitor size, and closes the dialog on click.
        monitor_events = new Gtk.EventBox ();
        monitor_events.visible = true;
        monitor_events.set_visible_window (false);
        monitor_events.events |= Gdk.EventMask.BUTTON_PRESS_MASK;
        monitor_events.button_press_event.connect (() => {
            close ();
            return true;
        });
        add (monitor_events);

        vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 10);
        vbox.visible = true;

        vbox.margin = BORDER_INTERNAL_SIZE;
        vbox.margin_top += 9;
        vbox.margin_left += 20;
        vbox.margin_right += 20;
        vbox.margin_bottom += 2;

        // This event box consumes the click events inside the vbox
        vbox_events = new Gtk.EventBox();
        vbox_events.visible = true;
        vbox_events.set_visible_window (false);
        vbox_events.events |= Gdk.EventMask.BUTTON_PRESS_MASK;
        vbox_events.button_press_event.connect (() => { return true; });
        vbox_events.add (vbox);
        monitor_events.add (vbox_events);

        string text;

        if (type == ShutdownDialogType.SHUTDOWN)
        {
            text = _("Goodbye. Would you like to…");
        }
        else
        {
            var title_label = new Gtk.Label (_("Shut Down"));
            title_label.visible = true;
            title_label.override_font (Pango.FontDescription.from_string ("Ubuntu Light 15"));
            title_label.override_color (Gtk.StateFlags.NORMAL, { 1.0f, 1.0f, 1.0f, 1.0f });
            title_label.set_alignment (0.0f, 0.5f);
            vbox.pack_start (title_label, false, false, 0);

            text = _("Are you sure you want to shut down the computer?");
        }

        var have_open_sessions = false;
        try
        {
            var b = Bus.get_sync (BusType.SYSTEM);
            var result = b.call_sync ("org.freedesktop.DisplayManager",
                                      "/org/freedesktop/DisplayManager",
                                      "org.freedesktop.DBus.Properties",
                                      "Get",
                                      new Variant ("(ss)", "org.freedesktop.DisplayManager", "Sessions"),
                                      new VariantType ("(v)"),
                                      DBusCallFlags.NONE,
                                      -1,
                                      null);
            Variant value;
            result.get ("(v)", out value);
            have_open_sessions = value.n_children () > 0;
        }
        catch (Error e)
        {
            warning ("Failed to check sessions from logind: %s", e.message);
        }
        if (have_open_sessions)
            text = "%s\n\n%s".printf (_("Other users are currently logged in to this computer, shutting down now will also close these other sessions."), text);

        var label = new Gtk.Label (text);
        label.set_line_wrap (true);
        label.override_font (Pango.FontDescription.from_string ("Ubuntu Light 12"));
        label.override_color (Gtk.StateFlags.NORMAL, { 1.0f, 1.0f, 1.0f, 1.0f });
        label.set_alignment (0.0f, 0.5f);
        label.visible = true;
        vbox.pack_start (label, false, false, 0);

        button_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 20);
        button_box.visible = true;
        vbox.pack_start (button_box, false, false, 0);

        if (type == ShutdownDialogType.SHUTDOWN)
        {
            if (LightDM.get_can_suspend ())
            {
                var button = add_button (_("Suspend"), Path.build_filename (Config.PKGDATADIR, "suspend.png"), Path.build_filename (Config.PKGDATADIR, "suspend_highlight.png"));
                button.clicked.connect (() =>
                {
                    try
                    {
                        LightDM.suspend ();
                        close ();
                    }
                    catch (Error e)
                    {
                        warning ("Failed to suspend: %s", e.message);
                    }
                });
            }

            if (LightDM.get_can_hibernate ())
            {
                var button = add_button (_("Hibernate"), Path.build_filename (Config.PKGDATADIR, "hibernate.png"), Path.build_filename (Config.PKGDATADIR, "hibernate_highlight.png"));
                button.clicked.connect (() =>
                {
                    try
                    {
                        LightDM.hibernate ();
                        close ();
                    }
                    catch (Error e)
                    {
                        warning ("Failed to hibernate: %s", e.message);
                    }
                });
            }
        }

        if (LightDM.get_can_restart ())
        {
            var button = add_button (_("Restart"), Path.build_filename (Config.PKGDATADIR, "restart.png"), Path.build_filename (Config.PKGDATADIR, "restart_highlight.png"));
            button.clicked.connect (() =>
            {
                try
                {
                    LightDM.restart ();
                    close ();
                }
                catch (Error e)
                {
                    warning ("Failed to restart: %s", e.message);
                }
            });
        }

        if (LightDM.get_can_shutdown ())
        {
            var button = add_button (_("Shut Down"), Path.build_filename (Config.PKGDATADIR, "shutdown.png"), Path.build_filename (Config.PKGDATADIR, "shutdown_highlight.png"));
            button.clicked.connect (() =>
            {
                try
                {
                    LightDM.shutdown ();
                    close ();
                }
                catch (Error e)
                {
                    warning ("Failed to shutdown: %s", e.message);
                }
            });

            if (type != ShutdownDialogType.SHUTDOWN)
                show.connect(() => { button.grab_focus (); });
        }

        close_button = new DialogButton (Path.build_filename (Config.PKGDATADIR, "dialog_close.png"), Path.build_filename (Config.PKGDATADIR, "dialog_close_highlight.png"), Path.build_filename (Config.PKGDATADIR, "dialog_close_press.png"));
        close_button.can_focus = false;
        close_button.clicked.connect (() => { close (); });
        close_button.visible = true;
        add (close_button);

        animation = new AnimateTimer ((x) => { return x; }, AnimateTimer.INSTANT);
        animation.animate.connect (() => { queue_draw (); });
        show.connect (() => { animation.reset(); });
    }

    public void close ()
    {
        var start_value = 1.0f - animation.progress;
        animation = new AnimateTimer ((x) => { return start_value + x; }, AnimateTimer.INSTANT);
        animation.animate.connect ((p) =>
        {
            queue_draw ();

            if (p >= 1.0f)
            {
                animation.stop ();
                closed ();
            }
        });

        closing = true;
        animation.reset();
    }

    private void rebuild_background ()
    {
        bg_surface = null;
        queue_draw ();
    }

    private void update_background_color ()
    {
        // Apply the same color corrections we do in Unity
        // For reference, see unity's unity-shared/BGHash.cpp
        double hue, saturation, value;
        const double COLOR_ALPHA = 0.72f;

        Gdk.RGBA color = background.average_color;
        Gtk.RGB.to_hsv (color.red, color.green, color.blue,
                        out hue, out saturation, out value);

        if (saturation < 0.08)
        {
            // Got a grayscale image
            avg_color = {0.18f, 0.20f, 0.21f, COLOR_ALPHA };
        }
        else
        {
            const Gdk.RGBA[] cmp_colors =
            {
                {84/255.0f, 14/255.0f, 68/255.0f, 1.0f},
                {110/255.0f, 11/255.0f, 42/255.0f, 1.0f},
                {132/255.0f, 22/255.0f, 23/255.0f, 1.0f},
                {132/255.0f, 55/255.0f, 27/255.0f, 1.0f},
                {134/255.0f, 77/255.0f, 32/255.0f, 1.0f},
                {133/255.0f, 127/255.0f, 49/255.0f, 1.0f},
                {29/255.0f, 99/255.0f, 49/255.0f, 1.0f},
                {17/255.0f, 88/255.0f, 46/255.0f, 1.0f},
                {14/255.0f, 89/255.0f, 85/255.0f, 1.0f},
                {25/255.0f, 43/255.0f, 89/255.0f, 1.0f},
                {27/255.0f, 19/255.0f, 76/255.0f, 1.0f},
                {2/255.0f, 192/255.0f, 212/255.0f, 1.0f}
            };

            avg_color = {0, 0, 0, 1};
            double closest_diff = 200.0f;

            foreach (var c in cmp_colors)
            {
                double cmp_hue, cmp_sat, cmp_value;
                Gtk.RGB.to_hsv (c.red, c.green, c.blue,
                                out cmp_hue, out cmp_sat, out cmp_value);
                double color_diff = Math.fabs (hue - cmp_hue);

                if (color_diff < closest_diff)
                {
                    avg_color = c;
                    closest_diff = color_diff;
                }
            }

            double new_hue, new_saturation, new_value;
            Gtk.RGB.to_hsv (avg_color.red, avg_color.green, avg_color.blue,
                            out new_hue, out new_saturation, out new_value);

            saturation = double.min (saturation, new_saturation);
            saturation *= (2.0f - saturation);
            value = double.min (double.min (value, new_value), 0.26f);
            Gtk.HSV.to_rgb (hue, saturation, value,
                            out avg_color.red, out avg_color.green, out avg_color.blue);
            avg_color.alpha = COLOR_ALPHA;
        }

        rebuild_background ();
    }

    public void set_active_monitor (Monitor m)
    {
        if (m == this.monitor || m.equals (this.monitor))
            return;

        monitor = m;
        rebuild_background ();
        set_size_request (monitor.width, monitor.height);
    }

    public void focus_next ()
    {
        (get_toplevel () as Gtk.Window).move_focus (Gtk.DirectionType.TAB_FORWARD);
    }

    public void focus_prev ()
    {
        (get_toplevel () as Gtk.Window).move_focus (Gtk.DirectionType.TAB_BACKWARD);
    }

    public void cancel ()
    {
        var widget = (get_toplevel () as Gtk.Window).get_focus ();
        if (widget is DialogButton)
            (get_toplevel () as Gtk.Window).set_focus (null);
        else
            close ();
    }

    public override void size_allocate (Gtk.Allocation allocation)
    {
        base.size_allocate (allocation);
        monitor_events.size_allocate (allocation);

        var content_allocation = Gtk.Allocation ();
        int minimum_width, natural_width, minimum_height, natural_height;
        vbox_events.get_preferred_width (out minimum_width, out natural_width);
        vbox_events.get_preferred_height_for_width (minimum_width, out minimum_height, out natural_height);
        content_allocation.x = allocation.x + (allocation.width - minimum_width) / 2;
        content_allocation.y = allocation.y + (allocation.height - minimum_height) / 2;
        content_allocation.width = minimum_width;
        content_allocation.height = minimum_height;
        vbox_events.size_allocate (content_allocation);

        var a = Gtk.Allocation ();
        close_button.get_preferred_width (out minimum_width, out natural_width);
        close_button.get_preferred_height (out minimum_height, out natural_height);
        a.x = content_allocation.x - BORDER_EXTERNAL_SIZE + CLOSE_OFFSET;
        a.y = content_allocation.y - BORDER_EXTERNAL_SIZE + CLOSE_OFFSET;
        a.width = minimum_width;
        a.height = minimum_height;
        close_button.size_allocate (a);
    }

    public override bool draw (Cairo.Context c)
    {
        if (corner_surface == null)
        {
            corner_surface = new Cairo.ImageSurface.from_png (Path.build_filename (Config.PKGDATADIR, "switcher_corner.png"));
            left_surface = new Cairo.ImageSurface.from_png (Path.build_filename (Config.PKGDATADIR, "switcher_left.png"));
            top_surface = new Cairo.ImageSurface.from_png (Path.build_filename (Config.PKGDATADIR, "switcher_top.png"));
            corner_pattern = new Cairo.Pattern.for_surface (corner_surface);
            left_pattern = new Cairo.Pattern.for_surface (left_surface);
            left_pattern.set_extend (Cairo.Extend.REPEAT);
            top_pattern = new Cairo.Pattern.for_surface (top_surface);
            top_pattern.set_extend (Cairo.Extend.REPEAT);
        }

        int width = vbox_events.get_allocated_width ();
        int height = vbox_events.get_allocated_height ();
        int x = (get_allocated_width () - width) / 2;
        int y = (get_allocated_height () - height) / 2;

        if (animation.is_running)
            c.push_group ();

        /* Darken background */
        c.set_source_rgba (0, 0, 0, 0.25);
        c.paint ();

        if (bg_surface == null || animation.is_running)
        {
            /* Create a new blurred surface of the current surface */
            bg_surface = new Cairo.ImageSurface (Cairo.Format.ARGB32, width, height);
            var bg_cr = new Cairo.Context (bg_surface);

            bg_cr.set_source_surface (c.get_target (), -x - monitor.x, -y - monitor.y);
            bg_cr.rectangle (0, 0, width, height);
            bg_cr.fill ();

            CairoUtils.ExponentialBlur.surface (bg_surface, BLUR_RADIUS);
        }

        /* Background */
        c.save ();
        c.translate (x, y);

        CairoUtils.rounded_rectangle (c, 0, 0, width, height, 4);
        c.set_source_surface (bg_surface, 0, 0);
        c.fill_preserve ();
        c.set_source_rgba (avg_color.red, avg_color.green, avg_color.blue, avg_color.alpha);
        c.fill ();

        c.restore();

        /* Draw borders */
        x -= BORDER_EXTERNAL_SIZE;
        y -= BORDER_EXTERNAL_SIZE;
        width += BORDER_EXTERNAL_SIZE * 2;
        height += BORDER_EXTERNAL_SIZE * 2;

        c.save ();
        c.translate (x, y);

        /* Top left */
        var m = Cairo.Matrix.identity ();
        corner_pattern.set_matrix (m);
        c.set_source (corner_pattern);
        c.rectangle (0, 0, BORDER_SIZE, BORDER_SIZE);
        c.fill ();

        /* Top right */
        m = Cairo.Matrix.identity ();
        m.translate (width, 0);
        m.scale (-1, 1);
        corner_pattern.set_matrix (m);
        c.set_source (corner_pattern);
        c.rectangle (width - BORDER_SIZE, 0, BORDER_SIZE, BORDER_SIZE);
        c.fill ();

        /* Bottom left */
        m = Cairo.Matrix.identity ();
        m.translate (0, height);
        m.scale (1, -1);
        corner_pattern.set_matrix (m);
        c.set_source (corner_pattern);
        c.rectangle (0, height - BORDER_SIZE, BORDER_SIZE, BORDER_SIZE);
        c.fill ();

        /* Bottom right */
        m = Cairo.Matrix.identity ();
        m.translate (width, height);
        m.scale (-1, -1);
        corner_pattern.set_matrix (m);
        c.set_source (corner_pattern);
        c.rectangle (width - BORDER_SIZE, height - BORDER_SIZE, BORDER_SIZE, BORDER_SIZE);
        c.fill ();

        /* Left */
        m = Cairo.Matrix.identity ();
        left_pattern.set_matrix (m);
        c.set_source (left_pattern);
        c.rectangle (0, BORDER_SIZE, BORDER_SIZE, height - BORDER_SIZE * 2);
        c.fill ();

        /* Right */
        m = Cairo.Matrix.identity ();
        m.translate (width, 0);
        m.scale (-1, 1);
        left_pattern.set_matrix (m);
        c.set_source (left_pattern);
        c.rectangle (width - BORDER_SIZE, BORDER_SIZE, BORDER_SIZE, height - BORDER_SIZE * 2);
        c.fill ();

        /* Top */
        m = Cairo.Matrix.identity ();
        top_pattern.set_matrix (m);
        c.set_source (top_pattern);
        c.rectangle (BORDER_SIZE, 0, width - BORDER_SIZE * 2, BORDER_SIZE);
        c.fill ();

        /* Bottom */
        m = Cairo.Matrix.identity ();
        m.translate (0, height);
        m.scale (1, -1);
        top_pattern.set_matrix (m);
        c.set_source (top_pattern);
        c.rectangle (BORDER_SIZE, height - BORDER_SIZE, width - BORDER_SIZE * 2, BORDER_SIZE);
        c.fill ();

        c.restore ();

        var ret = base.draw (c);

        if (animation.is_running)
        {
            c.pop_group_to_source ();
            c.paint_with_alpha (closing ? 1.0f - animation.progress : animation.progress);
        }

        return ret;
    }

    private DialogButton add_button (string text, string inactive_filename, string active_filename)
    {
        var b = new Gtk.Box (Gtk.Orientation.VERTICAL, BUTTON_TEXT_SPACE);
        b.visible = true;
        button_box.pack_start (b, false, false, 0);

        var label = new Gtk.Label (text);
        var button = new DialogButton (inactive_filename, active_filename, null, label);
        button.visible = true;

        b.pack_start (button, false, false, 0);
        b.pack_start (label, false, false, 0);

        return button;
    }
}

private class DialogButton : Gtk.Button
{
    private string inactive_filename;
    private string focused_filename;
    private string? active_filename;
    private Gtk.Image i;
    private Gtk.Label? l;

    public DialogButton (string inactive_filename, string focused_filename, string? active_filename, Gtk.Label? label = null)
    {
        this.inactive_filename = inactive_filename;
        this.focused_filename = focused_filename;
        this.active_filename = active_filename;
        relief = Gtk.ReliefStyle.NONE;
        focus_on_click = false;
        i = new Gtk.Image.from_file (inactive_filename);
        i.visible = true;
        add (i);

        l = label;

        if (l != null)
        {
            l.visible = true;
            l.override_font (Pango.FontDescription.from_string ("Ubuntu Light 12"));
            l.override_color (Gtk.StateFlags.NORMAL, { 1.0f, 1.0f, 1.0f, 0.0f });
            l.override_color (Gtk.StateFlags.FOCUSED, { 1.0f, 1.0f, 1.0f, 1.0f });
            l.override_color (Gtk.StateFlags.ACTIVE, { 1.0f, 1.0f, 1.0f, 1.0f });
            this.get_accessible ().set_name (l.get_text ());
        }

        UnityGreeter.add_style_class (this);
        try
        {
            // Remove the default GtkButton paddings and border
            var style = new Gtk.CssProvider ();
            style.load_from_data ("* {padding: 0px 0px 0px 0px; border: 0px; }", -1);
            get_style_context ().add_provider (style, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        }
        catch (Error e)
        {
            debug ("Internal error loading session chooser style: %s", e.message);
        }
    }

    public override bool enter_notify_event (Gdk.EventCrossing event)
    {
        grab_focus ();
        return base.enter_notify_event (event);
    }

    public override bool leave_notify_event (Gdk.EventCrossing event)
    {
        (get_toplevel () as Gtk.Window).set_focus (null);
        return base.leave_notify_event (event);
    }

    public override bool draw (Cairo.Context c)
    {
        i.draw (c);
        return true;
    }

    public override void state_flags_changed (Gtk.StateFlags previous_state)
    {
        var new_flags = get_state_flags ();

        if ((new_flags & Gtk.StateFlags.PRELIGHT) != 0 && !can_focus ||
            (new_flags & Gtk.StateFlags.FOCUSED) != 0)
        {
            if ((new_flags & Gtk.StateFlags.ACTIVE) != 0 && active_filename != null)
                i.set_from_file (active_filename);
            else
                i.set_from_file (focused_filename);
        }
        else
        {
            i.set_from_file (inactive_filename);
        }

        if (l != null)
            l.set_state_flags (new_flags, true);

        base.state_flags_changed (previous_state);
    }
}
