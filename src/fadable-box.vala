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
 * Authored by: Michael Terry <michael.terry@canonical.com>
 */

public class FadableBox : Gtk.EventBox, Fadable
{
    public signal void fade_done ();

    protected FadeTracker fade_tracker { get; protected set; }

    construct
    {
        visible_window = false;
        fade_tracker = new FadeTracker (this);
        fade_tracker.done.connect (() => { fade_done (); });
    }

    protected virtual void draw_full_alpha (Cairo.Context c)
    {
        base.draw (c);
    }

    public override bool draw (Cairo.Context c)
    {
        c.push_group ();
        draw_full_alpha (c);
        c.pop_group_to_source ();
        c.paint_with_alpha (fade_tracker.alpha);
        return false;
    }
}
