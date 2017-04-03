/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 4 -*-
 *
 * Copyright (C) 2013 Canonical Ltd
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
 * Authors: Marco Trevisan <marco.trevisan@canonical.com>
 *          Mirco "MacSlow" Mueller <mirco.mueller@canonical.com>
 */

namespace CairoUtils
{

public void rounded_rectangle (Cairo.Context c, double x, double y,
                               double width, double height, double radius)
{
    var w = width - radius * 2;
    var h = height - radius * 2;
    var kappa = 0.5522847498 * radius;
    c.move_to (x + radius, y);
    c.rel_line_to (w, 0);
    c.rel_curve_to (kappa, 0, radius, radius - kappa, radius, radius);
    c.rel_line_to (0, h);
    c.rel_curve_to (0, kappa, kappa - radius, radius, -radius, radius);
    c.rel_line_to (-w, 0);
    c.rel_curve_to (-kappa, 0, -radius, kappa - radius, -radius, -radius);
    c.rel_line_to (0, -h);
    c.rel_curve_to (0, -kappa, radius - kappa, -radius, radius, -radius);
}

class ExponentialBlur
{
    /* Exponential Blur, based on the Nux version */

    const int APREC = 16;
    const int ZPREC = 7;

    public static void surface (Cairo.ImageSurface surface, int radius)
    {
        if (radius < 1)
            return;

        // before we mess with the surface execute any pending drawing
        surface.flush ();

        unowned uchar[] pixels = surface.get_data ();
        var width  = surface.get_width ();
        var height = surface.get_height ();
        var format = surface.get_format ();

        switch (format)
        {
            case Cairo.Format.ARGB32:
                blur (pixels, width, height, 4, radius);
                break;

            case Cairo.Format.RGB24:
                blur (pixels, width, height, 3, radius);
                break;

            case Cairo.Format.A8:
                blur (pixels, width, height, 1, radius);
                break;

            default :
                // do nothing
                break;
        }

        // inform cairo we altered the surfaces contents
        surface.mark_dirty ();
    }

    static void blur (uchar[] pixels, int width, int height, int channels, int radius)
    {
        // calculate the alpha such that 90% of
        // the kernel is within the radius.
        // (Kernel extends to infinity)

        int alpha = (int) ((1 << APREC) * (1.0f - Math.expf(-2.3f / (radius + 1.0f))));

        for (int row = 0; row < height; ++row)
          blurrow (pixels, width, height, channels, row, alpha);

        for (int col = 0; col < width; ++col)
          blurcol (pixels, width, height, channels, col, alpha);
    }

    static void blurrow (uchar[] pixels, int width, int height, int channels, int line, int alpha)
    {
        var scanline = &(pixels[line * width * channels]);

        int zR = *scanline << ZPREC;
        int zG = *(scanline + 1) << ZPREC;
        int zB = *(scanline + 2) << ZPREC;
        int zA = *(scanline + 3) << ZPREC;

        for (int index = 0; index < width; ++index)
        {
          blurinner (&scanline[index * channels], alpha, ref zR, ref zG, ref zB, ref zA);
        }

        for (int index = width - 2; index >= 0; --index)
        {
          blurinner (&scanline[index * channels], alpha, ref zR, ref zG, ref zB, ref zA);
        }
    }

    static void blurcol (uchar[] pixels, int width, int height, int channels, int x, int alpha)
    {
        var ptr = &(pixels[x * channels]);

        int zR = *ptr << ZPREC;
        int zG = *(ptr + 1) << ZPREC;
        int zB = *(ptr + 2) << ZPREC;
        int zA = *(ptr + 3) << ZPREC;

        for (int index = width; index < (height - 1) * width; index += width)
        {
            blurinner (&ptr[index * channels], alpha, ref zR, ref zG, ref zB, ref zA);
        }

        for (int index = (height - 2) * width; index >= 0; index -= width)
        {
            blurinner (&ptr[index * channels], alpha, ref zR, ref zG, ref zB, ref zA);
        }
    }

    static void blurinner (uchar *pixel, int alpha, ref int zR, ref int zG, ref int zB, ref int zA)
    {
        int R;
        int G;
        int B;
        uchar A;

        R = *pixel;
        G = *(pixel + 1);
        B = *(pixel + 2);
        A = *(pixel + 3);

        zR += (alpha * ((R << ZPREC) - zR)) >> APREC;
        zG += (alpha * ((G << ZPREC) - zG)) >> APREC;
        zB += (alpha * ((B << ZPREC) - zB)) >> APREC;
        zA += (alpha * ((A << ZPREC) - zA)) >> APREC;

        *pixel = zR >> ZPREC;
        *(pixel + 1) = zG >> ZPREC;
        *(pixel + 2) = zB >> ZPREC;
        *(pixel + 3) = zA >> ZPREC;
    }
}

}
