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

public class ListStack : Gtk.Fixed
{
    public uint num_children
    {
        get
        {
            var children = get_children ();
            return children.length ();
        }
    }

    private int width;

    construct
    {
        width = grid_size * GreeterList.BOX_WIDTH;
    }

    public GreeterList? top ()
    {
        var children = get_children ();
        if (children == null)
            return null;
        else
            return children.last ().data as GreeterList;
    }

    public void push (GreeterList pushed)
    {
        return_if_fail (pushed != null);

        var children = get_children ();

        pushed.start_scrolling = false;
        pushed.set_size_request (width, -1);
        add (pushed);

        if (children != null)
        {
            var current = children.last ().data as GreeterList;
            /* Clear any errors so when we come back, they will be gone. */
            current.selected_entry.reset_state ();
            current.greeter_box.push (pushed);
        }
    }

    public void pop ()
    {
        var children = get_children ();

        return_if_fail (children != null);

        unowned List<Gtk.Widget> prev = children.last ().prev;
        if (prev != null)
            (prev.data as GreeterList).greeter_box.pop ();
    }

    public override void size_allocate (Gtk.Allocation allocation)
    {
        base.size_allocate (allocation);
        var children = get_children ();
        foreach (var child in children)
        {
            child.size_allocate (allocation);
        }
    }

    public override void get_preferred_width (out int min, out int nat)
    {
        min = width;
        nat = width;
    }
}
