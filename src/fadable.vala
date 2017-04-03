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

public class FadeTracker : Object
{
    public signal void done ();

    public double alpha { get; set; default = 1.0; }
    public Gtk.Widget widget { get; construct; }

    public enum Mode
    {
        FADE_IN,
        FADE_OUT,
    }

    public FadeTracker (Gtk.Widget widget)
    {
        Object (widget: widget);
    }

    public void reset (Mode mode)
    {
        this.mode = mode;
        animate_cb (0.0);
        widget.show ();
        timer.reset ();
    }

    private AnimateTimer timer;
    private Mode mode;

    construct
    {
        timer = new AnimateTimer (AnimateTimer.ease_out_quint, AnimateTimer.INSTANT);
        timer.animate.connect (animate_cb);
    }

    private void animate_cb (double progress)
    {
        if (mode == Mode.FADE_IN)
        {
            alpha = progress;
            if (progress == 1.0)
            {
                done ();
            }
        }
        else
        {
            alpha = 1.0 - progress;
            if (progress == 1.0)
            {
                widget.hide (); /* finish the job */
                done ();
            }
        }

        widget.queue_draw ();
    }
}

public interface Fadable : Gtk.Widget
{
    protected abstract FadeTracker fade_tracker { get; protected set; }

    public void fade_in ()
    {
        fade_tracker.reset (FadeTracker.Mode.FADE_IN);
    }

    public void fade_out ()
    {
        fade_tracker.reset (FadeTracker.Mode.FADE_OUT);
    }

    /* In case you want to control fade manually */
    public void set_alpha (double alpha)
    {
        fade_tracker.alpha = alpha;
        queue_draw ();
    }
}
