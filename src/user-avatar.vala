public class UserAvatar : CachedImage
{
    public const int AVATAR_SIZE = 32;
    public const int AVATAR_MARGIN = 6;

    private string? _avatar_path;
    public string? avatar_path 
    {
        get { return _avatar_path; }
        set { 
            _avatar_path = value;
            update_avatar();
        }
    }

    private bool _is_small = false;
    public bool is_small {
        get { return _is_small; }
        set {
            _is_small = value;
            update_avatar();
        }
    }

    public UserAvatar()
    {
        Object();
        setup_avatar();
    }

    private void setup_avatar()
    {
        // Keep a fixed size of 32px for display
        set_size_request(AVATAR_SIZE, AVATAR_SIZE);
        margin_right = AVATAR_MARGIN;
        halign = Gtk.Align.CENTER;
        hexpand = false;
        vexpand = false;
    }

    private void update_avatar()
    {
        if (avatar_path != null)
        {
            try
            {
                // Double the pixel size for HiDPI
                var scale_factor = get_scale_factor();
                var pixel_size = AVATAR_SIZE * (scale_factor > 1 ? 2 : 1);
                
                var pixbuf = new Gdk.Pixbuf.from_file_at_scale(
                    avatar_path,
                    pixel_size,
                    pixel_size,
                    true
                );

                // Create a circular pixbuf
                var surface = new Cairo.ImageSurface(
                    Cairo.Format.ARGB32,
                    pixel_size,
                    pixel_size
                );
                var cr = new Cairo.Context(surface);
                
                // Draw a circle
                cr.arc(
                    pixel_size / 2.0,
                    pixel_size / 2.0,
                    pixel_size / 2.0,
                    0,
                    2 * Math.PI
                );
                cr.clip();
                
                // Draw the image
                Gdk.cairo_set_source_pixbuf(cr, pixbuf, 0, 0);
                cr.paint();
                
                // Convert surface to pixbuf and set it
                var final_pixbuf = Gdk.pixbuf_get_from_surface(
                    surface,
                    0,
                    0,
                    pixel_size,
                    pixel_size
                );
                
                set_pixbuf(final_pixbuf);
                show();
            }
            catch (Error e)
            {
                warning("Failed to load avatar: %s", e.message);
                hide();
            }
        }
        else
        {
            hide();
        }
    }
}
