#!/usr/bin/python3

import gi
gi.require_version('Gdk', '3.0')
from gi.repository import Gdk
import sys
import os
import syslog

HIDPI_LIMIT = 192

def get_window_scale():
    window_scale = 1
    try:
        display = Gdk.Display.get_default()
        monitor = display.get_primary_monitor()
        rect = monitor.get_geometry()
        width_mm = monitor.get_width_mm()
        height_mm = monitor.get_height_mm()
        monitor_scale = monitor.get_scale_factor()

        # Return 1 if the screen size isn't available (some TVs report their aspect ratio instead ... 16/9 or 16/10)
        if ((width_mm == 160 and height_mm == 90) \
            or (width_mm == 160 and height_mm == 100) \
            or (width_mm == 16 and height_mm == 9) \
            or (width_mm == 16 and height_mm == 10)):
            return 1

        if rect.height * monitor_scale < 1500:
            return 1

        if width_mm > 0 and height_mm > 0:
            witdh_inch = width_mm / 25.4
            height_inch = height_mm / 25.4
            dpi_x = rect.width * monitor_scale / witdh_inch
            dpi_y = rect.height * monitor_scale / height_inch
            if dpi_x > HIDPI_LIMIT and dpi_y > HIDPI_LIMIT:
                window_scale = 2

    except Exception as detail:
        syslog.syslog("Error while detecting hidpi mode: %s" % detail)

    return window_scale

if __name__ == '__main__':
    window_scale = get_window_scale();
    syslog.syslog("Window scale: %d" % window_scale)
    print (window_scale)
    sys.exit(0)
