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

public class CachedImage : Gtk.Image
{
    private static HashTable<Gdk.Pixbuf, Cairo.Surface> surface_table;

    public static Cairo.Surface? get_cached_surface (Gdk.Pixbuf pixbuf)
    {
        if (surface_table == null)
            surface_table = new HashTable<Gdk.Pixbuf, Cairo.Surface> (direct_hash, direct_equal);

        var surface = surface_table.lookup (pixbuf);
        if (surface == null)
        {
            surface = Gdk.cairo_surface_create_from_pixbuf (pixbuf, _scale_factor, null);
            surface_table.insert (pixbuf, surface);
        }
        return surface;
    }

    private void update_image(Gdk.Pixbuf? pixbuf)
    {
        if (pixbuf != null)
        {
            surface = get_cached_surface (pixbuf);
        }
        else
        {
            surface = null;
            pixbuf = null;
        }
    }

    public CachedImage (Gdk.Pixbuf? pixbuf)
    {
        update_image (pixbuf);
    }

    public void set_pixbuf(Gdk.Pixbuf? pixbuf)
    {
        update_image (pixbuf);
    }
}
