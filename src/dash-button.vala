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

public class DashButton : FlatButton, Fadable
{
    protected FadeTracker fade_tracker { get; protected set; }
    private Gtk.Label text_label;

    private string _text = "";
    public string text
    {
        get { return _text; }
        set
        {
            _text = value;
            text_label.set_markup ("<span font=\"Ubuntu 13\">%s</span>".printf (value));
        }
    }

    public DashButton (string text)
    {
        fade_tracker = new FadeTracker (this);

        var hbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);

        /* Add text */
        text_label = new Gtk.Label ("");
        text_label.use_markup = true;
        text_label.hexpand = true;
        text_label.halign = Gtk.Align.START;
        hbox.add (text_label);
        this.text = text;

        /* Add chevron */
        var path = Path.build_filename (Config.PKGDATADIR, "arrow_right.png", null);
        try
        {
            var pixbuf = new Gdk.Pixbuf.from_file (path);
            var image = new CachedImage (pixbuf);
            image.valign = Gtk.Align.CENTER;
            hbox.add (image);
        }
        catch (Error e)
        {
            debug ("Error loading image %s: %s", path, e.message);
        }

        hbox.show_all ();
        add (hbox);

        try
        {
            var style = new Gtk.CssProvider ();
            style.load_from_data ("* {padding: 6px 8px 6px 8px;
                                      -GtkWidget-focus-line-width: 0px;
                                     }", -1);
            this.get_style_context ().add_provider (style, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        }
        catch (Error e)
        {
            debug ("Internal error loading session chooser style: %s", e.message);
        }
    }

    public override bool draw (Cairo.Context c)
    {
        c.push_group ();
        base.draw (c);
        c.pop_group_to_source ();
        c.paint_with_alpha (fade_tracker.alpha);
        return false;
    }
}
