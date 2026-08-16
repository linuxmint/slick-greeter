/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 4 -*-
 *
 * Copyright (C) 2026
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 */

public class IdleClockOverlay : Gtk.DrawingArea
{
    private const double IDLE_CLOCK_Y = 0.50;
    private const double LOGIN_CLOCK_Y = 0.28;
    private int clock_font_size;
    private string clock_format;
    private string clock_text = "";
    private Pango.FontDescription clock_font;
    private double background_dim_opacity;
    private double idle_clock_opacity;
    private double login_clock_opacity;
    private bool show_clock = true;

    private double _progress = 0.0;
    public double progress
    {
        get { return _progress; }
        set
        {
            _progress = value.clamp (0.0, 1.0);
            queue_draw ();
        }
    }
    
    public IdleClockOverlay (int font_size = 150)
    {
        clock_font_size = font_size;
    }

    construct
    {
        app_paintable = true;

        clock_format = UGSettings.get_string (UGSettings.KEY_CLOCK_FORMAT);
        show_clock = UGSettings.get_boolean (UGSettings.KEY_IDLE_CLOCK_ENABLED);
        background_dim_opacity = UGSettings.get_double (UGSettings.KEY_LOGIN_BACKGROUND_DIM_OPACITY).clamp (0.0, 1.0);
        idle_clock_opacity = UGSettings.get_double (UGSettings.KEY_IDLE_CLOCK_OPACITY).clamp (0.0, 1.0);
        login_clock_opacity = UGSettings.get_double (UGSettings.KEY_LOGIN_CLOCK_OPACITY).clamp (0.0, 1.0);

        var configured_font = Pango.FontDescription.from_string (UGSettings.get_string (UGSettings.KEY_FONT_NAME));
        var font_family = configured_font.get_family ();
        if (font_family == null || font_family == "")
            font_family = "Sans";

        clock_font = new Pango.FontDescription ();
        clock_font.set_family (font_family);
        clock_font.set_weight (Pango.Weight.LIGHT);
        clock_font.set_size (clock_font_size * Pango.SCALE);

        update_clock ();
        Timeout.add_seconds (1, update_clock);
    }

    private bool update_clock ()
    {
        var current_time = new DateTime.now_local ();
        clock_text = current_time.format (clock_format);
        queue_draw ();
        return true;
    }

    public override bool draw (Cairo.Context c)
    {
        var width = get_allocated_width ();
        var height = get_allocated_height ();

        if (width <= 0 || height <= 0)
            return false;

        var dim_alpha = background_dim_opacity * progress;
        if (dim_alpha > 0.0)
        {
            c.save ();
            c.set_source_rgba (0.0, 0.0, 0.0, dim_alpha);
            c.rectangle (0, 0, width, height);
            c.fill ();
            c.restore ();
        }

        if (!show_clock || clock_text == "")
            return false;

        var layout = create_pango_layout (clock_text);
        layout.set_font_description (clock_font);
        layout.set_alignment (Pango.Alignment.CENTER);

        int text_width;
        int text_height;
        layout.get_pixel_size (out text_width, out text_height);

        var center_y = (IDLE_CLOCK_Y + (LOGIN_CLOCK_Y - IDLE_CLOCK_Y) * progress) * height;
        var opacity = idle_clock_opacity + (login_clock_opacity - idle_clock_opacity) * progress;

        c.save ();
        c.set_source_rgba (1.0, 1.0, 1.0, opacity);
        c.move_to ((width - text_width) / 2, center_y - text_height / 2);
        Pango.cairo_show_layout (c, layout);
        c.restore ();

        return false;
    }
}
