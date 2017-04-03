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

public class FlatButton : Gtk.Button
{
    private bool did_press;

    construct
    {
        UnityGreeter.add_style_class (this);
        try
        {
            var style = new Gtk.CssProvider ();
            style.load_from_data ("* {-GtkButton-child-displacement-x: 0px;
                                      -GtkButton-child-displacement-y: 0px;
                                      -GtkWidget-focus-line-width: 1px;
                                      }", -1);
            get_style_context ().add_provider (style, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        }
        catch (Error e)
        {
            debug ("Internal error loading session chooser style: %s", e.message);
        }
    }

    public override bool button_press_event (Gdk.EventButton event)
    {
        // Do nothing.  The normal handler sets priv->button_down which
        // internally causes draw() to draw a special border and background
        // that we don't want.
        did_press = true;
        return true;
    }

    public override bool button_release_event (Gdk.EventButton event)
    {
        if (did_press)
        {
            event.type = Gdk.EventType.BUTTON_PRESS;
            base.button_press_event (event); // fake an insta-click
            did_press = false;
        }

        event.type = Gdk.EventType.BUTTON_RELEASE;
        return base.button_release_event (event);
    }
}
