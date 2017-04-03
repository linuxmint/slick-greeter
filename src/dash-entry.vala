/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 4 -*-
 *
 * Copyright (C) 2012 Canonical Ltd
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
 * Authors: Michael Terry <michael.terry@canonical.com>
 */

/* Vala's vapi for gtk3 is broken for lookup_color (it forgets the out keyword) */
[CCode (cheader_filename = "gtk/gtk.h")]
extern bool gtk_style_context_lookup_color (Gtk.StyleContext ctx, string color_name, out Gdk.RGBA color);

public class DashEntry : Gtk.Entry, Fadable
{
    public static string font = "Ubuntu 14";
    public signal void respond ();

    public string constant_placeholder_text { get; set; }
    public bool can_respond { get; set; default = true; }

    private bool _did_respond;
    public bool did_respond
    {
        get
        {
            return _did_respond;
        }
        set
        {
            _did_respond = value;
            if (value)
                set_state_flags (Gtk.StateFlags.ACTIVE, false);
            else
                unset_state_flags (Gtk.StateFlags.ACTIVE);
            queue_draw ();
        }
    }

    protected FadeTracker fade_tracker { get; protected set; }
    private Gdk.Window arrow_win;
    private static Gdk.Pixbuf arrow_pixbuf;

    construct
    {
        fade_tracker = new FadeTracker (this);

        notify["can-respond"].connect (queue_draw);
        button_press_event.connect (button_press_event_cb);

        if (arrow_pixbuf == null)
        {
            var filename = Path.build_filename (Config.PKGDATADIR, "arrow_right.png");
            try
            {
                arrow_pixbuf = new Gdk.Pixbuf.from_file (filename);
            }
            catch (Error e)
            {
                debug ("Internal error loading arrow icon: %s", e.message);
            }
        }

        override_font (Pango.FontDescription.from_string (font));

        var style_ctx = get_style_context ();

        try
        {
            var padding_provider = new Gtk.CssProvider ();
            var css = "* {padding-right: %dpx;}".printf (get_arrow_size ());
            padding_provider.load_from_data (css, -1);
            style_ctx.add_provider (padding_provider,
                                    Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        }
        catch (Error e)
        {
            debug ("Internal error loading padding style: %s", e.message);
        }
    }

    public override bool draw (Cairo.Context c)
    {
        var style_ctx = get_style_context ();

        // See construct method for explanation of why we remove classes
        style_ctx.save ();
        c.save ();
        c.push_group ();
        base.draw (c);
        c.pop_group_to_source ();
        c.paint_with_alpha (fade_tracker.alpha);
        c.restore ();
        style_ctx.restore ();

        /* Now draw the prompt text */
        if (get_text_length () == 0 && constant_placeholder_text.length > 0)
            draw_prompt_text (c);

        /* Draw activity spinner if we need to */
        if (did_respond)
            draw_spinner (c);
        else if (can_respond && get_text_length () > 0)
            draw_arrow (c);

        return false;
    }

    private void draw_spinner (Cairo.Context c)
    {
        c.save ();

        var style_ctx = get_style_context ();
        var arrow_size = get_arrow_size ();
        Gtk.cairo_transform_to_window (c, this, arrow_win);
        style_ctx.render_activity (c, 0, 0, arrow_size, arrow_size);

        c.restore ();
    }

    private void draw_arrow (Cairo.Context c)
    {
        if (arrow_pixbuf == null)
            return;

        c.save ();

        var arrow_size = get_arrow_size ();
        Gtk.cairo_transform_to_window (c, this, arrow_win);
        c.translate (arrow_size - arrow_pixbuf.get_width () - 1, 0); // right align
        Gdk.cairo_set_source_pixbuf (c, arrow_pixbuf, 0, 0);

        c.paint ();
        c.restore ();
    }

    private void draw_prompt_text (Cairo.Context c)
    {
        c.save ();

        /* Position text */
        int x, y;
        get_layout_offsets (out x, out y);
        c.move_to (x, y);

        /* Set foreground color */
        var fg = Gdk.RGBA ();
        var context = get_style_context ();
        if (!gtk_style_context_lookup_color (context, "placeholder_text_color", out fg))
            fg.parse ("#888");
        c.set_source_rgba (fg.red, fg.green, fg.blue, fg.alpha);

        /* Draw text */
        var layout = create_pango_layout (constant_placeholder_text);
        layout.set_font_description (Pango.FontDescription.from_string ("Ubuntu 13"));
        Pango.cairo_show_layout (c, layout);

        c.restore ();
    }

    public override void activate ()
    {
        base.activate ();
        if (can_respond)
        {
            did_respond = true;
            respond ();
        }
        else
        {
            get_toplevel ().child_focus (Gtk.DirectionType.TAB_FORWARD);
        }
    }

    public bool button_press_event_cb (Gdk.EventButton event)
    {
        if (event.window == arrow_win && get_text_length () > 0)
        {
            activate ();
            return true;
        }
        else
            return false;
    }

    private int get_arrow_size ()
    {
        // height is larger than width for the arrow, so we measure using that
        if (arrow_pixbuf != null)
            return arrow_pixbuf.get_height ();
        else
            return 20; // Shouldn't happen
    }

    private void get_arrow_location (out int x, out int y)
    {
        var arrow_size = get_arrow_size ();

        Gtk.Allocation allocation;
        get_allocation (out allocation);

        // height is larger than width for the arrow, so we measure using that
        var margin = (allocation.height - arrow_size) / 2;

        x = allocation.x + allocation.width - margin - arrow_size;
        y = allocation.y + margin;
    }

    public override void size_allocate (Gtk.Allocation allocation)
    {
        base.size_allocate (allocation);

        if (arrow_win == null)
            return;

        int arrow_x, arrow_y;
        get_arrow_location (out arrow_x, out arrow_y);
        var arrow_size = get_arrow_size ();

        arrow_win.move_resize (arrow_x, arrow_y, arrow_size, arrow_size);
    }

    public override void realize ()
    {
        base.realize ();

        var cursor = new Gdk.Cursor.for_display (get_display (), Gdk.CursorType.LEFT_PTR);
        var attrs = Gdk.WindowAttr ();
        attrs.x = 0;
        attrs.y = 0;
        attrs.width = 1;
        attrs.height = 1;
        attrs.cursor = cursor;
        attrs.wclass = Gdk.WindowWindowClass.INPUT_ONLY;
        attrs.window_type = Gdk.WindowType.CHILD;
        attrs.event_mask = get_events () |
                           Gdk.EventMask.BUTTON_PRESS_MASK;

        arrow_win = new Gdk.Window (get_window (), attrs,
                                    Gdk.WindowAttributesType.X |
                                    Gdk.WindowAttributesType.Y |
                                    Gdk.WindowAttributesType.CURSOR);
        arrow_win.ref ();
        arrow_win.set_user_data (this);
    }

    public override void unrealize ()
    {
        if (arrow_win != null)
        {
            arrow_win.destroy ();
            arrow_win = null;
        }
        base.unrealize ();
    }

    public override void map ()
    {
        base.map ();
        if (arrow_win != null)
            arrow_win.show ();
    }

    public override void unmap ()
    {
        if (arrow_win != null)
            arrow_win.hide ();
        base.unmap ();
    }

    public override bool key_press_event (Gdk.EventKey event)
    {
        // This is a workaroud for bug https://launchpad.net/bugs/944159
        // The problem is that orca seems to not notice that it's in a password
        // field on startup.  We just need to kick orca in the pants.
        if (UnityGreeter.singleton.orca_needs_kick)
        {
            Signal.emit_by_name (get_accessible (), "focus-event", true);
            UnityGreeter.singleton.orca_needs_kick = false;
        }

        return base.key_press_event (event);
    }
}
