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
 */

/**
 * BannerDialog — shows the contents of /etc/issue (or a configurable file)
 * and requires the user to accept before logging in.
 *
 * The widget is a Gtk.Fixed overlay that sits on top of the Background widget,
 * following the same design pattern as ShutdownDialog.
 */
public class BannerDialog : Gtk.Fixed
{
    /** Emitted when the user clicks "I Accept". */
    public signal void accepted ();

    private Monitor monitor;
    private weak Background background;

    private Gtk.EventBox overlay_events;
    private Gtk.EventBox vbox_events;
    private Gtk.Box vbox;

    private const int DIALOG_WIDTH  = 640;
    private const int PADDING       = 20;

    public BannerDialog (Background bg)
    {
        background = bg;

        /* --- Full-screen transparent overlay (blocks all background clicks) --- */
        overlay_events = new Gtk.EventBox ();
        overlay_events.visible = true;
        overlay_events.set_visible_window (false);
        overlay_events.events |= Gdk.EventMask.BUTTON_PRESS_MASK;
        overlay_events.button_press_event.connect (() => { return true; });
        add (overlay_events);

        /* --- Dialog panel --- */
        vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 10);
        vbox.visible = true;
        vbox.margin = PADDING;

        vbox_events = new Gtk.EventBox ();
        vbox_events.visible = true;
        vbox_events.set_visible_window (true);
        vbox_events.events |= Gdk.EventMask.BUTTON_PRESS_MASK;
        vbox_events.button_press_event.connect (() => { return true; });
        vbox_events.add (vbox);
        overlay_events.add (vbox_events);

        /* Panel background style */
        try
        {
            var style = new Gtk.CssProvider ();
            style.load_from_data (
                "* { background-color: rgba(20, 20, 20, 0.92); " +
                "    border-radius: 4px; }", -1);
            vbox_events.get_style_context ().add_provider (
                style, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        }
        catch (Error e)
        {
            debug ("BannerDialog panel style error: %s", e.message);
        }

        /* --- Title --- */
        var title_label = new Gtk.Label (_("System Notice"));
        title_label.visible = true;
        title_label.override_font (Pango.FontDescription.from_string ("Ubuntu Light 18"));
        title_label.override_color (Gtk.StateFlags.NORMAL, { 1.0f, 1.0f, 1.0f, 1.0f });
        title_label.set_alignment (0.5f, 0.5f);
        vbox.pack_start (title_label, false, false, 0);

        /* --- Subtitle --- */
        var desc_label = new Gtk.Label (
            _("You must read and accept the following policy before logging in:"));
        desc_label.visible = true;
        desc_label.set_line_wrap (true);
        desc_label.override_font (Pango.FontDescription.from_string ("Ubuntu 10"));
        desc_label.override_color (Gtk.StateFlags.NORMAL, { 0.80f, 0.80f, 0.80f, 1.0f });
        desc_label.set_alignment (0.0f, 0.5f);
        vbox.pack_start (desc_label, false, false, 0);

        /* --- Separator --- */
        var sep = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
        sep.visible = true;
        vbox.pack_start (sep, false, false, 0);

        /* --- Text view with full banner content (no scroll) --- */
        var text_view = new Gtk.TextView ();
        text_view.visible = true;
        text_view.editable = false;
        text_view.cursor_visible = false;
        text_view.wrap_mode = Gtk.WrapMode.WORD_CHAR;
        text_view.left_margin   = 8;
        text_view.right_margin  = 8;
        text_view.top_margin    = 6;
        text_view.bottom_margin = 6;
        text_view.buffer.text = read_banner_text ();
        text_view.override_font (Pango.FontDescription.from_string ("Monospace 10"));
        text_view.override_color (Gtk.StateFlags.NORMAL, { 0.90f, 0.90f, 0.90f, 1.0f });

        try
        {
            var style = new Gtk.CssProvider ();
            style.load_from_data ("* { background-color: rgba(8, 8, 8, 0.85); }", -1);
            text_view.get_style_context ().add_provider (
                style, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        }
        catch (Error e)
        {
            debug ("BannerDialog text_view style error: %s", e.message);
        }

        vbox.pack_start (text_view, true, true, 0);

        /* --- Second separator --- */
        var sep2 = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
        sep2.visible = true;
        vbox.pack_start (sep2, false, false, 0);

        /* --- Button row --- */
        var button_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
        button_box.visible = true;
        button_box.halign = Gtk.Align.END;
        vbox.pack_start (button_box, false, false, 0);

        var accept_button = new Gtk.Button.with_label (_("I Accept"));
        accept_button.visible = true;
        accept_button.get_style_context ().add_class ("suggested-action");
        accept_button.clicked.connect (() => { accepted (); });
        button_box.pack_start (accept_button, false, false, 0);

        /* Give focus to the accept button when the widget is shown */
        show.connect (() => { accept_button.grab_focus (); });
    }

    /* ------------------------------------------------------------------ */
    /*  Helpers                                                             */
    /* ------------------------------------------------------------------ */

    /**
     * Read the banner file, strip ANSI escape sequences, and expand the
     * /etc/issue escape codes that are most commonly found in the wild.
     */
    private string read_banner_text ()
    {
        var banner_file = UGSettings.get_string (UGSettings.KEY_BANNER_FILE);
        if (banner_file == "")
            banner_file = "/etc/issue";

        string contents = "";
        try
        {
            FileUtils.get_contents (banner_file, out contents);
        }
        catch (Error e)
        {
            warning ("BannerDialog: could not read '%s': %s", banner_file, e.message);
            /* Translators: shown when the banner file cannot be read */
            return _("(Could not read the login banner file.)");
        }

        /* Strip ANSI/VT100 escape sequences: ESC [ … <letter> */
        try
        {
            var ansi_re = new Regex ("\x1b\\[[0-9;]*[a-zA-Z]");
            contents = ansi_re.replace (contents, -1, 0, "");
        }
        catch (RegexError e)
        {
            debug ("BannerDialog: ANSI regex error: %s", e.message);
        }

        /* Expand common /etc/issue escape codes */
        try
        {
            /* \n or \N → hostname */
            var hostname = GLib.Environment.get_host_name ();
            var re = new Regex ("\\\\[nN]");
            contents = re.replace (contents, -1, 0, hostname);

            /* \s → kernel/OS name */
            re = new Regex ("\\\\s");
            contents = re.replace (contents, -1, 0, "Linux");

            /* \r → kernel release */
            re = new Regex ("\\\\r");
            contents = re.replace (contents, -1, 0, "");

            /* \v → kernel version */
            re = new Regex ("\\\\v");
            contents = re.replace (contents, -1, 0, "");

            /* \m → machine arch */
            re = new Regex ("\\\\m");
            contents = re.replace (contents, -1, 0, "");

            /* \l → virtual console / tty */
            re = new Regex ("\\\\l");
            contents = re.replace (contents, -1, 0, "");

            /* \o → domain name */
            re = new Regex ("\\\\o");
            contents = re.replace (contents, -1, 0, "");

            /* \d → date, \t → time (drop them) */
            re = new Regex ("\\\\[dt]");
            contents = re.replace (contents, -1, 0, "");

            /* Drop any remaining backslash-letter sequences */
            re = new Regex ("\\\\[a-zA-Z]");
            contents = re.replace (contents, -1, 0, "");
        }
        catch (RegexError e)
        {
            debug ("BannerDialog: issue-escape regex error: %s", e.message);
        }

        return contents.strip ();
    }

    /* ------------------------------------------------------------------ */
    /*  Monitor management (mirrors ShutdownDialog)                        */
    /* ------------------------------------------------------------------ */

    public void set_active_monitor (Monitor m)
    {
        if (monitor != null && m.equals (monitor))
            return;

        monitor = m;
        set_size_request (monitor.width, monitor.height);
        queue_resize ();
    }

    public override void size_allocate (Gtk.Allocation allocation)
    {
        base.size_allocate (allocation);

        /* Overlay covers the entire monitor */
        overlay_events.size_allocate (allocation);

        /* Dialog box is centered */
        var dialog_alloc = Gtk.Allocation ();
        int min_w, nat_w, min_h, nat_h;
        vbox_events.get_preferred_width (out min_w, out nat_w);
        vbox_events.get_preferred_height_for_width (nat_w, out min_h, out nat_h);

        var dlg_w = int.min (nat_w,  allocation.width  - 80);
        var dlg_h = int.min (nat_h,  allocation.height - 120);

        dialog_alloc.x      = allocation.x + (allocation.width  - dlg_w) / 2;
        dialog_alloc.y      = allocation.y + (allocation.height - dlg_h) / 2;
        dialog_alloc.width  = dlg_w;
        dialog_alloc.height = dlg_h;

        vbox_events.size_allocate (dialog_alloc);
    }

    /* Darken the greeter background while the dialog is up */
    public override bool draw (Cairo.Context c)
    {
        c.set_source_rgba (0.0, 0.0, 0.0, 0.55);
        c.paint ();
        return base.draw (c);
    }
}
