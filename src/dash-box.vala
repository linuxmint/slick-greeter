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

public class DashBox : Gtk.Box
{
    public Background? background { get; construct; default = null; }

    public bool has_base { get; private set; default = false; }
    public double base_alpha { get; private set; default = 1.0; }

    public signal void transition_complete ();

    private enum Mode
    {
        NORMAL,
        PUSH_FADE_OUT,
        PUSH_FADE_IN,
        POP_FADE_OUT,
        POP_FADE_IN,
    }

    private GreeterList pushed;
    private Gtk.Widget orig = null;
    private FadeTracker orig_tracker;
    private int orig_height = -1;
    private Mode mode;

    private Cairo.ImageSurface? bg_surface = null;
    private const int BLUR_RADIUS = 8;

    public DashBox (Background bg)
    {
        Object (background: bg);
    }

    construct
    {
        mode = Mode.NORMAL;
        
        // Connect background change signals to rebuild blur effect
        if (background != null)
        {
            background.notify["alpha"].connect (rebuild_background);
            background.notify["average-color"].connect (rebuild_background);
        }
    }

    private void rebuild_background ()
    {
        bg_surface = null;
        queue_draw ();
    }

    public void cleanup ()
    {
        // Clean up blurred surface
        if (bg_surface != null)
        {
            bg_surface.finish ();
            bg_surface = null;
        }
    }

    public override void size_allocate (Gtk.Allocation allocation)
    {
        base.size_allocate (allocation);
        
        // Force reconstruction of blur effect when dimensions change
        rebuild_background ();
    }

    /* Does not actually add w to this widget, as doing so would potentially mess with w's placement. */
    public void set_base (Gtk.Widget? w)
    {
        return_if_fail (pushed == null);
        return_if_fail (mode == Mode.NORMAL);

        if (orig != null)
            orig.size_allocate.disconnect (base_size_allocate_cb);
        orig = w;

        if (orig != null)
        {
            orig.size_allocate.connect (base_size_allocate_cb);
            orig_tracker = new FadeTracker (orig);
            orig_tracker.notify["alpha"].connect (() =>
            {
                base_alpha = orig_tracker.alpha;
                queue_draw ();
            });
            orig_tracker.done.connect (fade_done_cb);
            base_alpha = orig_tracker.alpha;
            has_base = true;
        }
        else
        {
            orig_height = -1;
            get_preferred_height (null, out orig_height); /* save height */

            orig_tracker = null;
            base_alpha = 1.0;
            has_base = false;
        }

        queue_resize ();
    }

    public void push (GreeterList l)
    {
        /* This isn't designed to push more than one widget at a time yet */
        return_if_fail (pushed == null);
        return_if_fail (orig != null);
        return_if_fail (mode == Mode.NORMAL);

        get_preferred_height (null, out orig_height);
        pushed = l;
        pushed.fade_done.connect (fade_done_cb);
        mode = Mode.PUSH_FADE_OUT;
        orig_tracker.reset (FadeTracker.Mode.FADE_OUT);
        
        rebuild_background ();
        
        queue_resize ();
    }

    public void pop ()
    {
        return_if_fail (pushed != null);
        return_if_fail (orig != null);
        return_if_fail (mode == Mode.NORMAL);

        mode = Mode.POP_FADE_OUT;
        pushed.fade_out ();
        
        rebuild_background ();
    }

    private void fade_done_cb ()
    {
        switch (mode)
        {
        case Mode.PUSH_FADE_OUT:
            mode = Mode.PUSH_FADE_IN;
            orig.hide ();
            pushed.fade_in ();
            break;
        case Mode.PUSH_FADE_IN:
            mode = Mode.NORMAL;
            pushed.grab_focus ();
            // Force layout redraw after transition
            force_immediate_layout_update ();
            // Rebuild blur after transition
            rebuild_background ();
            break;
        case Mode.POP_FADE_OUT:
            mode = Mode.POP_FADE_IN;
            orig_tracker.reset (FadeTracker.Mode.FADE_IN);
            orig.show ();
            break;
        case Mode.POP_FADE_IN:
            mode = Mode.NORMAL;
            pushed.fade_done.disconnect (fade_done_cb);
            pushed.destroy ();
            pushed = null;
            queue_resize ();
            orig.grab_focus ();
            force_immediate_layout_update ();
            rebuild_background ();
            break;
        }
    }

    private void force_immediate_layout_update ()
    {
        // Force layout update during animation
        queue_resize ();
        queue_draw ();
        
        // Notify all parent containers to update layout
        // This is necessary because PromptBox widgets in GreeterList's Gtk.Fixed
        // need to be repositioned when DashBox changes size
        var widget = this as Gtk.Widget;
        while (widget != null)
        {
            widget.queue_resize ();
            widget.queue_draw ();
            widget = widget.get_parent ();
        }

        transition_complete ();
    }

    private void base_size_allocate_cb ()
    {
        queue_resize ();
    }

    public override void get_preferred_height (out int min, out int nat)
    {
        if (orig == null)
        {
            /* Return cached height if we have it. This makes transitions between two base widgets smoother. */
            if (orig_height >= 0)
            {
                min = orig_height;
                nat = orig_height;
            }
            else
            {
                min = grid_size * GreeterList.DEFAULT_BOX_HEIGHT - GreeterList.BORDER * 2;
                nat = grid_size * GreeterList.DEFAULT_BOX_HEIGHT - GreeterList.BORDER * 2;
            }
        }
        else
        {
            if (pushed == null)
                orig.get_preferred_height (out min, out nat);
            else
            {
                pushed.selected_entry.get_preferred_height (out min, out nat);
                min = int.max (orig_height, min);
                nat = int.max (orig_height, nat);
            }
        }
    }

    public override void get_preferred_width (out int min, out int nat)
    {
        min = grid_size * GreeterList.BOX_WIDTH - GreeterList.BORDER * 2;
        nat = grid_size * GreeterList.BOX_WIDTH - GreeterList.BORDER * 2;
    }

    public override bool draw (Cairo.Context c)
    {
        var width = get_allocated_width ();
        var height = get_allocated_height ();

        /* Draw darker background with a rounded border */
        var box_r = 0.3 * grid_size;
        int box_y = 0;
        int box_w;
        int box_h;
        get_preferred_width (null, out box_w);
        get_preferred_height (null, out box_h);

        if (mode == Mode.PUSH_FADE_OUT || mode == Mode.POP_FADE_IN)
        {
            var new_box_h = box_h - (int) ((box_h - orig_height) * base_alpha);
            box_h = int.max (new_box_h, 1); // Prevent negative or zero height
        }

        // Check if we need to recreate the blurred surface
        if (bg_surface == null || bg_surface.get_width () != width || bg_surface.get_height () != height)
        {
            if (width > 0 && height > 0)
            {
                try
                {
                    bg_surface = new Cairo.ImageSurface (Cairo.Format.ARGB32, width, height);
                    var bg_cr = new Cairo.Context (bg_surface);
                    // Draw background in temporary surface
                    if (background != null)
                    {
                        int x, y;
                        background.translate_coordinates (this, 0, 0, out x, out y);
                        bg_cr.save ();
                        bg_cr.translate (x, y);
                        background.draw_full (bg_cr, Background.DrawFlags.NONE);
                        bg_cr.restore ();
                    }
                    // Apply blur effect
                    CairoUtils.ExponentialBlur.surface (bg_surface, BLUR_RADIUS);
                }
                catch (Error e)
                {
                    warning ("Failed to create background surface: %s", e.message);
                    bg_surface = null;
                }
            }
        }

        // Draw blurred background with rounded corners
        if (bg_surface != null)
        {
            c.save ();
            // Apply rounded rectangle clip for blur
            CairoUtils.rounded_rectangle (c, 0, box_y, box_w, box_h, box_r);
            c.clip ();
            // Draw blurred background
            c.set_source_surface (bg_surface, 0, 0);
            c.paint ();
            c.restore ();
        }

        /* Draw darker background with a rounded border */
        c.save ();
        CairoUtils.rounded_rectangle (c, 0, box_y, box_w, box_h, box_r);
        c.set_source_rgba (0.1, 0.1, 0.1, 0.55);
        c.fill_preserve ();
        c.set_source_rgba (0.4, 0.4, 0.4, 0.4);
        c.set_line_width (1);
        c.stroke ();
        c.restore ();

        return base.draw (c);
    }
}
