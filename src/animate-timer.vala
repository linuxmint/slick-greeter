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
 * Authors: Robert Ancell <robert.ancell@canonical.com>
 *          Michael Terry <michael.terry@canonical.com>
 */

private class AnimateTimer : Object
{
    /* x and y are 0.0 to 1.0 */
    public delegate double EasingFunc (double x);

    /* The following are the same intervals that Unity uses */
    public static const int INSTANT = 150; /* Good for animations that don't convey any information */
    public static const int FAST =    250; /* Good for animations that convey duplicated information */
    public static const int NORMAL =  500;
    public static const int SLOW =   1000; /* Good for animations that convey information that is only presented in the animation */

    /* speed is in milliseconds */
    public unowned EasingFunc easing_func { get; private set; }
    public int speed { get; set; }
    public bool is_running { get { return timeout != 0; } }
    public double progress { get; private set; }

    /* progress is from 0.0 to 1.0 */
    public signal void animate (double progress);

    /* AnimateTimer requires two things: an easing function and a speed.

       The speed is just the duration of the animation in milliseconds.

       The easing function describes how fast the animation occurs at different
       parts of the duration.

       See http://hosted.zeh.com.br/tweener/docs/en-us/misc/transitions.html
       for examples of various easing functions.

       A few are provided with this class, notably ease_in_out and
       ease_out_quint.
    */
    /* speed is in milliseconds */
    public AnimateTimer (EasingFunc func, int speed)
    {
        Object (speed: speed);
        this.easing_func = func;
    }

    ~AnimateTimer ()
    {
        stop ();
    }

    /* temp_speed is in milliseconds */
    public void reset (int temp_speed = -1)
    {
        stop ();

        timeout = Timeout.add (16, animate_cb);
        progress = 0;
        start_time = 0;
        extra_time = 0;
        extra_progress = 0;

        if (temp_speed == -1)
            temp_speed = speed;

        length = temp_speed * TimeSpan.MILLISECOND;
    }

    public void stop ()
    {
        if (timeout != 0)
            Source.remove (timeout);
        timeout = 0;
    }

    private uint timeout = 0;
    private TimeSpan start_time = 0;
    private TimeSpan length = 0;
    private TimeSpan extra_time = 0;
    private double extra_progress = 0.0;

    private bool animate_cb ()
    {
        if (start_time == 0)
            start_time = GLib.get_monotonic_time ();

        var time_progress = normalize_time (GLib.get_monotonic_time ());
        progress = calculate_progress (time_progress);
        animate (progress);

        if (time_progress >= 1.0)
        {
            timeout = 0;
            return false;
        }
        else
            return true;
    }

    /* Returns 0.0 to 1.0 where 1.0 is at or past end_time */
    private double normalize_time (TimeSpan now)
    {
        if (length == 0)
            return 1.0f;

        return (((double)(now - start_time)) / length).clamp (0.0, 1.0);
    }

    /* Returns 0.0 to 1.0 where 1.0 is done.
       time is not normalized yet! */
    private double calculate_progress (double time_progress)
    {
        var y = easing_func (time_progress);
        return y.clamp (0.0, 1.0);
    }

    public static double ease_in_out (double x)
    {
        return (1 - Math.cos (Math.PI * x)) / 2;
    }

    /*public static double ease_in_quad (double x)
    {
        return Math.pow (x, 2);
    }*/
    /*public static double ease_out_quad (double x)
    {
        return -1 * Math.pow (x - 1, 2) + 1;
    }*/

    /*public static double ease_in_quint (double x)
    {
        return Math.pow (x, 5);
    }*/
    public static double ease_out_quint (double x)
    {
        return Math.pow (x - 1, 5) + 1;
    }
}

