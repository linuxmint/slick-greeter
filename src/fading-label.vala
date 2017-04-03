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

public class FadingLabel : Gtk.Label
{
    private Cairo.Surface cached_surface;

    public FadingLabel (string text)
    {
        Object (label: text);
    }

    public override void get_preferred_width (out int minimum, out int natural)
    {
        base.get_preferred_width (out minimum, out natural);
        minimum = 0;
    }

    public override void get_preferred_width_for_height (int height, out int minimum, out int natural)
    {
        base.get_preferred_width_for_height (height, out minimum, out natural);
        minimum = 0;
    }

    public override void size_allocate (Gtk.Allocation allocation)
    {
        base.size_allocate (allocation);
        cached_surface = null;
    }

    private Cairo.Surface make_surface (Cairo.Context orig_c)
    {
        int w, h;
        get_layout ().get_pixel_size (out w, out h);

        var bw = get_allocated_width ();
        var bh = get_allocated_height ();

        var surface = new Cairo.Surface.similar (orig_c.get_target (), Cairo.Content.COLOR_ALPHA, bw, bh);
        var c = new Cairo.Context (surface);

        if (w > bw)
        {
            c.push_group ();
            base.draw (c);
            c.pop_group_to_source ();

            var mask = new Cairo.Pattern.linear (0, 0, bw, 0);
            mask.add_color_stop_rgba (1.0 - 27.0 / bw, 1.0, 1.0, 1.0, 1.0);
            mask.add_color_stop_rgba (1.0 - 21.6 / bw, 1.0, 1.0, 1.0, 0.5);
            mask.add_color_stop_rgba (1.0, 1.0, 1.0, 1.0, 0.0);

            c.mask (mask);
        }
        else
            base.draw (c);

        return surface;
    }

    public override bool draw (Cairo.Context c)
    {
        if (cached_surface == null)
            cached_surface = make_surface (c);
        c.set_source_surface (cached_surface, 0, 0);
        c.paint ();
        return false;
    }
}
