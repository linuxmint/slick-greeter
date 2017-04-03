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
 * Authors: Andrea Cimitan <andrea.cimitan@canonical.com>
 */


public class Menu : Gtk.Menu
{
    public Background? background { get; construct; default = null; }

    public Menu (Background bg)
    {
        Object (background: bg);
    }

    public override bool draw (Cairo.Context c)
    {
        if (background != null)
        {
            int x, y, bg_x, bg_y;

            background.get_window ().get_origin (out bg_x, out bg_y);
            get_window ().get_origin (out x, out y);
            c.save ();
            c.translate (bg_x - x, bg_y - y);
            background.draw_full (c, Background.DrawFlags.NONE);
            c.restore ();
        }

        base.draw (c);
        return false;
    }
}
