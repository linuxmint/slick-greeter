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

class BackgroundLoader : Object
{
    public string filename { get; private set; }
    public Cairo.Surface logo { get; set; }

    public int[] widths;
    public int[] heights;
    public Cairo.Pattern[] patterns;
    public Gdk.RGBA average_color;

    private Cairo.Surface target_surface;
    private Thread<void*> thread;
    private Gdk.Pixbuf[] images;
    private bool finished;
    private uint ready_id;

    public signal void loaded ();

    public BackgroundLoader (Cairo.Surface target_surface, string filename, int[] widths, int[] heights)
    {
        this.target_surface = target_surface;
        this.filename = filename;
        this.widths = widths;
        this.heights = heights;
        patterns = new Cairo.Pattern[widths.length];
        images = new Gdk.Pixbuf[widths.length];
    }

    public bool load ()
    {
        /* Already loaded */
        if (finished)
            return true;

        /* Currently loading */
        if (thread != null)
            return false;

        /* No monitor data */
        if (widths.length == 0)
            return false;

        var text = "Making background %s at %dx%d".printf (filename, widths[0], heights[0]);
        for (var i = 1; i < widths.length; i++)
            text += ",%dx%d".printf (widths[i], heights[i]);
        debug (text);

        var color = Gdk.RGBA ();
        if (color.parse (filename))
        {
            var pattern = new Cairo.Pattern.rgba (color.red, color.green, color.blue, color.alpha);
            for (var i = 0; i < widths.length; i++)
                patterns[i] = pattern;

            average_color = color;
            finished = true;
            debug ("Render of background %s complete", filename);
            return true;
        }
        else
        {
            try
            {
                this.ref ();
                thread = new Thread<void*>.try ("background-loader", load_and_scale);
            }
            catch (Error e)
            {
                this.unref ();
                finished = true;
                return true;
            }
        }

        return false;
    }

    public Cairo.Pattern? get_pattern (int width, int height)
    {
        for (var i = 0; i < widths.length; i++)
        {
            if (widths[i] == width && heights[i] == height)
                return patterns[i];
        }
        return null;
    }

    ~BackgroundLoader ()
    {
        if (ready_id > 0)
            Source.remove (ready_id);
        ready_id = 0;
    }

    private bool ready_cb ()
    {
        ready_id = 0;

        debug ("Render of background %s complete", filename);

        thread.join ();
        thread = null;
        finished = true;

        for (var i = 0; i < widths.length; i++)
        {
            if (images[i] != null)
            {
                patterns[i] = create_pattern (images[i]);
                if (i == 0)
                    pixbuf_average_value (images[i], out average_color);
                images[i] = null;
            }
            else
            {
                debug ("images[%d] was null for %s", i, filename);
                patterns[i] = null;
            }
        }

        loaded ();

        this.unref ();
        return false;
    }

    private void* load_and_scale ()
    {
        try
        {
            var image = new Gdk.Pixbuf.from_file (filename);
            for (var i = 0; i < widths.length; i++)
                images[i] = scale (image, widths[i], heights[i]);
        }
        catch (Error e)
        {
            debug ("Error loading background: %s", e.message);
        }

        ready_id = Gdk.threads_add_idle (ready_cb);

        return null;
    }

    private Gdk.Pixbuf? scale (Gdk.Pixbuf? image, int width, int height)
    {
        var target_aspect = (double) width / height;
        var aspect = (double) image.width / image.height;
        double scale, offset_x = 0, offset_y = 0;
        if (aspect > target_aspect)
        {
            /* Fit height and trim sides */
            scale = (double) height / image.height;
            offset_x = (image.width * scale - width) / 2;
        }
        else
        {
            /* Fit width and trim top and bottom */
            scale = (double) width / image.width;
            offset_y = (image.height * scale - height) / 2;
        }

        var scaled_image = new Gdk.Pixbuf (image.colorspace, image.has_alpha, image.bits_per_sample, width, height);
        image.scale (scaled_image, 0, 0, width, height, -offset_x, -offset_y, scale, scale, Gdk.InterpType.BILINEAR);

        return scaled_image;
    }

    private Cairo.Pattern? create_pattern (Gdk.Pixbuf image)
    {
        var grid_x_offset = get_grid_offset (image.width);
        var grid_y_offset = get_grid_offset (image.height);

        /* Create background */
        var surface = new Cairo.Surface.similar (target_surface, Cairo.Content.COLOR, image.width, image.height);
        var bc = new Cairo.Context (surface);
        Gdk.cairo_set_source_pixbuf (bc, image, 0, 0);

        bc.paint ();

        /* Draw logo */
        if (logo != null)
        {
            bc.save ();
            var y = (int) (image.height / grid_size - 2) * grid_size + grid_y_offset;
            bc.translate (grid_x_offset, y);
            bc.set_source_surface (logo, 0, 0);
            bc.paint_with_alpha (1.0);
            bc.restore ();
        }

        var pattern = new Cairo.Pattern.for_surface (surface);
        pattern.set_extend (Cairo.Extend.REPEAT);

        return pattern;
    }

    /* The following color averaging algorithm was originally written for
       Unity in C++, then patched into gnome-desktop3 in C.  I've taken it
       and put it here in Vala.  It would be nice if we could get
       gnome-desktop3 to expose this for our use instead of copying the
       code... */

    const int QUAD_MAX_LEVEL_OF_RECURSION = 16;
    const int QUAD_MIN_LEVEL_OF_RECURSION = 2;
    const int QUAD_CORNER_WEIGHT_NW       = 3;
    const int QUAD_CORNER_WEIGHT_NE       = 1;
    const int QUAD_CORNER_WEIGHT_SE       = 1;
    const int QUAD_CORNER_WEIGHT_SW       = 3;
    const int QUAD_CORNER_WEIGHT_CENTER   = 2;
    const int QUAD_CORNER_WEIGHT_TOTAL    = (QUAD_CORNER_WEIGHT_NW + QUAD_CORNER_WEIGHT_NE + QUAD_CORNER_WEIGHT_SE + QUAD_CORNER_WEIGHT_SW + QUAD_CORNER_WEIGHT_CENTER);

    /* Pixbuf utilities */
    private Gdk.RGBA get_pixbuf_sample (uint8[]   pixels,
                                        int       rowstride,
                                        int       channels,
                                        int       x,
                                        int       y)
    {
	    var sample = Gdk.RGBA ();
	    double dd = 0xFF;
	    int offset = ((y * rowstride) + (x * channels));

	    sample.red = pixels[offset++] / dd;
	    sample.green = pixels[offset++] / dd;
	    sample.blue = pixels[offset++] / dd;
	    sample.alpha = 1.0f;

	    return sample;
    }

    private bool is_color_different (Gdk.RGBA color_a,
                                     Gdk.RGBA color_b)
    {
	    var diff = Gdk.RGBA ();

	    diff.red   = color_a.red   - color_b.red;
	    diff.green = color_a.green - color_b.green;
	    diff.blue  = color_a.blue  - color_b.blue;
	    diff.alpha = 1.0f;

	    if (GLib.Math.fabs (diff.red) > 0.15 ||
	        GLib.Math.fabs (diff.green) > 0.15 ||
	        GLib.Math.fabs (diff.blue) > 0.15)
		    return true;

	    return false;
    }

    private Gdk.RGBA get_quad_average (int       x,
                                       int       y,
                                       int       width,
                                       int       height,
                                       int       level_of_recursion,
                                       uint8[]   pixels,
                                       int       rowstride,
                                       int       channels)
    {
	    // samples four corners
	    // c1-----c2
	    // |       |
	    // c3-----c4

	    var average = Gdk.RGBA ();
	    var corner1 = get_pixbuf_sample (pixels, rowstride, channels, x        , y         );
	    var corner2 = get_pixbuf_sample (pixels, rowstride, channels, x + width, y         );
	    var corner3 = get_pixbuf_sample (pixels, rowstride, channels, x        , y + height);
	    var corner4 = get_pixbuf_sample (pixels, rowstride, channels, x + width, y + height);
	    var centre  = get_pixbuf_sample (pixels, rowstride, channels, x + (width / 2), y + (height / 2));

	    /* If we're over the max we want to just take the average and be happy
	       with that value */
	    if (level_of_recursion < QUAD_MAX_LEVEL_OF_RECURSION) {
		    /* Otherwise we want to look at each value and check it's distance
		       from the center color and take the average if they're far apart. */

		    /* corner 1 */
		    if (level_of_recursion < QUAD_MIN_LEVEL_OF_RECURSION ||
				    is_color_different(corner1, centre)) {
			    corner1 = get_quad_average (x, y, width/2, height/2, level_of_recursion + 1, pixels, rowstride, channels);
		    }

		    /* corner 2 */
		    if (level_of_recursion < QUAD_MIN_LEVEL_OF_RECURSION ||
				    is_color_different(corner2, centre)) {
			    corner2 = get_quad_average (x + width/2, y, width/2, height/2, level_of_recursion + 1, pixels, rowstride, channels);
		    }

		    /* corner 3 */
		    if (level_of_recursion < QUAD_MIN_LEVEL_OF_RECURSION ||
				    is_color_different(corner3, centre)) {
			    corner3 = get_quad_average (x, y + height/2, width/2, height/2, level_of_recursion + 1, pixels, rowstride, channels);
		    }

		    /* corner 4 */
		    if (level_of_recursion < QUAD_MIN_LEVEL_OF_RECURSION ||
				    is_color_different(corner4, centre)) {
			    corner4 = get_quad_average (x + width/2, y + height/2, width/2, height/2, level_of_recursion + 1, pixels, rowstride, channels);
		    }
	    }

	    average.red   = ((corner1.red * QUAD_CORNER_WEIGHT_NW)     +
	                     (corner3.red * QUAD_CORNER_WEIGHT_SW)     +
	                     (centre.red  * QUAD_CORNER_WEIGHT_CENTER) +
	                     (corner2.red * QUAD_CORNER_WEIGHT_NE)     +
	                     (corner4.red * QUAD_CORNER_WEIGHT_SE))
	                    / QUAD_CORNER_WEIGHT_TOTAL;
	    average.green = ((corner1.green * QUAD_CORNER_WEIGHT_NW)     +
	                     (corner3.green * QUAD_CORNER_WEIGHT_SW)     +
	                     (centre.green  * QUAD_CORNER_WEIGHT_CENTER) +
	                     (corner2.green * QUAD_CORNER_WEIGHT_NE)     +
	                     (corner4.green * QUAD_CORNER_WEIGHT_SE))
	                    / QUAD_CORNER_WEIGHT_TOTAL;
	    average.blue  = ((corner1.blue * QUAD_CORNER_WEIGHT_NW)     +
	                     (corner3.blue * QUAD_CORNER_WEIGHT_SW)     +
	                     (centre.blue  * QUAD_CORNER_WEIGHT_CENTER) +
	                     (corner2.blue * QUAD_CORNER_WEIGHT_NE)     +
	                     (corner4.blue * QUAD_CORNER_WEIGHT_SE))
	                    / QUAD_CORNER_WEIGHT_TOTAL;
	    average.alpha = 1.0f;

	    return average;
    }

    private void pixbuf_average_value (Gdk.Pixbuf pixbuf,
                                       out Gdk.RGBA result)
    {
	    var average = get_quad_average (0, 0,
	                                    pixbuf.get_width () - 1, pixbuf.get_height () - 1,
	                                    1,
	                                    pixbuf.get_pixels (),
	                                    pixbuf.get_rowstride (),
	                                    pixbuf.get_n_channels ());

	    result = Gdk.RGBA ();
	    result.red = average.red;
	    result.green = average.green;
	    result.blue = average.blue;
	    result.alpha = average.alpha;
    }
}

public class Monitor
{
    public int x;
    public int y;
    public int width;
    public int height;

    public Monitor (int x, int y, int width, int height)
    {
        this.x = x;
        this.y = y;
        this.width = width;
        this.height = height;
    }

    public bool equals (Monitor? other)
    {
        if (other != null)
            return (x == other.x && y == other.y && width == other.width && height == other.height);

        return false;
    }
}

public class Background : Gtk.Fixed
{
    [Flags]
    public enum DrawFlags
    {
        NONE,
        GRID,
        SPAN,
    }
    private DrawFlags flags = DrawFlags.NONE;

    /* Fallback color - shown upon first startup, until an async background loader finishes,
     * or until a user background or default background is loaded.
     */
    private string _fallback_color = null;
    public string fallback_color {
        get {
            if (_fallback_color == null)
            {
                var settings_color = UGSettings.get_string (UGSettings.KEY_BACKGROUND_COLOR);
                var color = Gdk.RGBA ();

                if (settings_color == "" || !color.parse (settings_color))
                {
                    settings_color = "#000000";
                }

                _fallback_color = settings_color;
            }

            return _fallback_color;
        }
    }

    private string _system_background;
    public string? system_background {
        get {
            if (_system_background == null)
            {
                var system_bg = UGSettings.get_string (UGSettings.KEY_BACKGROUND);

                if (system_bg == "")
                {
                    system_bg = fallback_color;
                }

                _system_background = system_bg;
            }

            return _system_background;
        }
    }

    /* Current background - whatever the background object is or should be showing right now.
     * This could be a simple color or a file name - the BackgroundLoader takes care of deciding
     * how to deal with it, we just ensure whatever we're sending is valid.
     */

    private string _current_background;
    public string? current_background {
        get {
            if (_current_background == null)
            {
                _current_background = fallback_color;
            }

            return _current_background;
            }
        set {
            if (value == null || value == "")
            {
                _current_background = system_background;
            } else
            {
                _current_background = value;
            }

            reload ();
        }
    }

    /* Width - total pixel width of the entire background canvas. This total width
     * should account for the relative geometry of all attached monitors.
     */

    private int _width = 0;
    public int width {
        get {
            return _width;
        }
    }

    /* Height - total pixel height of the entire background canvas. This total height
     * should account for the relative geometry of all attached monitors.
     */

    private int _height = 0;
    public int height {
        get {
            return _height;
        }
    }

    public double alpha { get; private set; default = 1.0; }
    public Gdk.RGBA average_color { get { return current.average_color; } }

    private Cairo.Surface target_surface;

    private List<Monitor> monitors = null;
    private Monitor? active_monitor = null;

    private AnimateTimer timer;

    private BackgroundLoader current;
    private BackgroundLoader old;

    private HashTable<string, BackgroundLoader> loaders;

    private Cairo.Surface? version_logo_surface = null;
    private int version_logo_width;
    private int version_logo_height;
    private Cairo.Surface? other_monitors_logo_surface = null;
    private int other_monitors_logo_width;
    private int other_monitors_logo_height;

    public Background ()
    {
        target_surface = null;
        timer = null;

        resize_mode = Gtk.ResizeMode.QUEUE;
        loaders = new HashTable<string?, BackgroundLoader> (str_hash, str_equal);
        if (UGSettings.get_boolean (UGSettings.KEY_DRAW_GRID))
            flags |= DrawFlags.GRID;

        var mode = UGSettings.get_string (UGSettings.KEY_BACKGROUND_MODE);
        if (mode == "spanned")
            flags |= DrawFlags.SPAN;

        show ();
    }

    public void set_surface (Cairo.Surface target_surface)
    {
        this.target_surface = target_surface;

        timer = new AnimateTimer (AnimateTimer.ease_in_out, 700);

        load_background (null);
        set_logo (UGSettings.get_string (UGSettings.KEY_LOGO), UGSettings.get_string (UGSettings.KEY_OTHER_MONITORS_LOGO));
        timer.animate.connect (animate_cb);
    }

    public void set_logo (string version_logo, string other_monitors_logo)
    {
        version_logo_surface = load_image (version_logo, out version_logo_width, out version_logo_height);
        other_monitors_logo_surface = load_image (other_monitors_logo, out other_monitors_logo_width, out other_monitors_logo_height);
    }

    private Cairo.Surface? load_image (string filename, out int width, out int height)
    {
        width = height = 0;

        try
        {
            if (filename != "") {
                var image = new Gdk.Pixbuf.from_file (filename);
                width = image.width;
                height = image.height;
                var surface = new Cairo.Surface.similar (target_surface, Cairo.Content.COLOR_ALPHA, image.width, image.height);
                var c = new Cairo.Context (surface);
                Gdk.cairo_set_source_pixbuf (c, image, 0, 0);
                c.paint ();
                return surface;
            }
        }
        catch (Error e)
        {
            debug ("Failed to load background component %s: %s", filename, e.message);
        }

        return null;
    }

    public void set_monitors (List<Monitor> monitors)
    {
        this.monitors = new List<Monitor> ();
        foreach (var m in monitors)
        {
            if (_width < m.x + m.width)
                _width = m.x + m.width;

            if (_height < m.y + m.height)
                _height = m.y + m.height;

            this.monitors.append (m);
        }
        queue_draw ();
    }

    public void set_active_monitor (Monitor? monitor)
    {
        active_monitor = monitor;
    }

    public override void size_allocate (Gtk.Allocation allocation)
    {
        if (!get_realized ())
        {
            return;
        }

        var resized = allocation.height != get_allocated_height () || allocation.width != get_allocated_width ();

        base.size_allocate (allocation);

        /* Regenerate backgrounds */
        if (resized)
        {
            debug ("Regenerating backgrounds");
            loaders.remove_all ();
            load_background (null);
            reload ();
        }
    }

    public override bool draw (Cairo.Context c)
    {
        draw_full (c, flags);
        return base.draw (c);
    }

    public void draw_full (Cairo.Context c, DrawFlags flags)
    {
        c.save ();

        /* Test whether we ran into an error loading this background */
        if (current == null || (current.load () && current.patterns[0] == null))
        {
            /* We couldn't load it, so swap it out for the default background
               and remember that choice */
            var new_background = load_background (null);
            if (current != null)
                loaders.insert (current.filename, new_background);
            if (old == current)
                old = new_background;
            current = new_background;
            publish_average_color ();
        }

        /* Fade to this background when loaded */
        if (current.load () && current != old && !timer.is_running)
        {
            alpha = 0.0;
            timer.reset ();
        }

        c.set_source_rgba (0.0, 0.0, 0.0, 0.0);
        var old_painted = false;

        /* Draw old background */
        if (old != null && old.load () && (alpha < 1.0 || !current.load ()))
        {
            draw_background (c, old, 1.0);
            old_painted = true;
        }

        /* Draw new background */
        if (current.load () && alpha > 0.0)
            draw_background (c, current, old_painted ? alpha : 1.0);

        c.restore ();

        if (DrawFlags.GRID in flags)
            overlay_grid (c);
    }

    private void draw_background (Cairo.Context c, BackgroundLoader background, double alpha)
    {
        foreach (var monitor in monitors)
        {
            Cairo.Pattern? pattern;
            var matrix = Cairo.Matrix.identity ();
            if (DrawFlags.SPAN in flags)
            {
                pattern = background.get_pattern (_width, _height);
            }
            else
            {
                pattern = background.get_pattern (monitor.width, monitor.height);
                matrix.translate (-monitor.x, -monitor.y);
            }

            if (pattern == null)
                continue;

            c.save ();
            pattern.set_matrix (matrix);
            c.set_source (pattern);
            c.rectangle (monitor.x, monitor.y, monitor.width, monitor.height);
            c.clip ();
            c.paint_with_alpha (alpha);
            c.restore ();

            if (monitor != active_monitor && other_monitors_logo_surface != null)
            {
                var width = other_monitors_logo_width;
                var height = other_monitors_logo_height;

                c.save ();
                pattern = new Cairo.Pattern.for_surface (other_monitors_logo_surface);
                matrix = Cairo.Matrix.identity ();
                var x = monitor.x + (monitor.width - width) / 2;
                var y = monitor.y + (monitor.height - height) / 2;
                matrix.translate (-x, -y);
                pattern.set_matrix (matrix);
                c.set_source (pattern);
                c.rectangle (x, y, width, height);
                c.clip ();
                c.paint_with_alpha (alpha);
                c.restore ();
            }
        }
    }

    private void animate_cb (double progress)
    {
        alpha = progress;
        queue_draw ();

        /* Stop when we get there */
        if (alpha >= 1.0)
            old = current;
    }

    private void reload ()
    {
        if (get_realized ())
        {
            var new_background = load_background (current_background);

            if (current != new_background)
            {
                old = current;
                current = new_background;
                alpha = 1.0; /* if the timer isn't going, we should always be at 1.0 */
                timer.stop ();
            }

            queue_draw ();
            publish_average_color ();
        }
    }

    private BackgroundLoader load_background (string? filename)
    {
        if (filename == null)
        {
            filename = fallback_color;
        } else
        {
    	    try
    	    {
              var file = File.new_for_path(filename);
              var fileInfo = file.query_info(FileAttribute.ACCESS_CAN_READ, FileQueryInfoFlags.NONE, null);
              if (!fileInfo.get_attribute_boolean(FileAttribute.ACCESS_CAN_READ))
              {
                  debug ("Can't read background file %s, falling back to %s", filename, system_background);
                  filename = system_background;
              }
    	    }
          catch
          {
              filename = system_background;
          }
        }

        var b = loaders.lookup (filename);
        if (b == null)
        {
            /* Load required sizes to draw background */
            var widths = new int[monitors.length ()];
            var heights = new int[monitors.length ()];
            var n_sizes = 0;
            if (DrawFlags.SPAN in flags)
            {
                widths[n_sizes] = _width;
                heights[n_sizes] = _height;
                n_sizes++;
            }
            else
            {
                foreach (var monitor in monitors)
                {
                    if (monitor_is_unique_size (monitor))
                    {
                        widths[n_sizes] = monitor.width;
                        heights[n_sizes] = monitor.height;
                        n_sizes++;
                    }
                }
            }
            widths.resize (n_sizes);
            heights.resize (n_sizes);

            b = new BackgroundLoader (target_surface, filename, widths, heights);
            b.logo = version_logo_surface;
            b.loaded.connect (() => { reload (); });
            b.load ();
            loaders.insert (filename, b);
        }

        return b;
    }

    /* Check if a monitor has a unique size */
    private bool monitor_is_unique_size (Monitor monitor)
    {
        foreach (var m in monitors)
        {
            if (m == monitor)
                break;
            else if (m.width == monitor.width && m.height == monitor.height)
                return false;
        }

        return true;
    }

    private void overlay_grid (Cairo.Context c)
    {
        var width = get_allocated_width ();
        var height = get_allocated_height ();
        var grid_x_offset = get_grid_offset (width);
        var grid_y_offset = get_grid_offset (height);

        /* Overlay grid */
        var overlay_surface = new Cairo.Surface.similar (target_surface, Cairo.Content.COLOR_ALPHA, grid_size, grid_size);
        var oc = new Cairo.Context (overlay_surface);
        oc.rectangle (0, 0, 1, 1);
        oc.rectangle (grid_size - 1, 0, 1, 1);
        oc.rectangle (0, grid_size - 1, 1, 1);
        oc.rectangle (grid_size - 1, grid_size - 1, 1, 1);
        oc.set_source_rgba (1.0, 1.0, 1.0, 0.25);
        oc.fill ();
        var overlay = new Cairo.Pattern.for_surface (overlay_surface);
        var matrix = Cairo.Matrix.identity ();
        matrix.translate (-grid_x_offset, -grid_y_offset);
        overlay.set_matrix (matrix);
        overlay.set_extend (Cairo.Extend.REPEAT);

        /* Draw overlay */
        c.save ();
        c.set_source (overlay);
        c.rectangle (0, 0, width, height);
        c.fill ();
        c.restore ();
    }

    void publish_average_color ()
    {
        notify_property ("average-color");

        if (!SlickGreeter.singleton.test_mode)
        {
            var rgba = current.average_color.to_string ();
            var root = get_screen ().get_root_window ();
            Gdk.property_change (root,
                                 Gdk.Atom.intern_static_string ("_GNOME_BACKGROUND_REPRESENTATIVE_COLORS"),
                                 Gdk.Atom.intern_static_string ("STRING"),
                                 8,
                                 Gdk.PropMode.REPLACE,
                                 rgba.data,
                                 rgba.data.length);
        }
    }
}
