#if !VALA_0_22
namespace Posix
{
    [CCode (cheader_filename = "sys/mman.h")]
    public const int MCL_CURRENT;
    [CCode (cheader_filename = "sys/mman.h")]
    public const int MCL_FUTURE;
    [CCode (cheader_filename = "sys/mman.h")]
    public int mlockall (int flags);
    [CCode (cheader_filename = "sys/mman.h")]
    public int munlockall ();
}
#endif

// See https://bugzilla.gnome.org/show_bug.cgi?id=727113
[CCode (cprefix = "", lower_case_cprefix = "", cheader_filename = "X11/Xlib.h")]
namespace X
{
    [CCode (cname = "XCreatePixmap")]
    public int CreatePixmap (X.Display display, X.Drawable d, uint width, uint height, uint depth);
    [CCode (cname = "XSetWindowBackgroundPixmap")]
    public int SetWindowBackgroundPixmap (X.Display display, X.Window w, int Pixmap);
    [CCode (cname = "XClearWindow")]
    public int ClearWindow (X.Display display, X.Window w);
    public const int RetainPermanent;
}

namespace Gtk
{
    namespace RGB
    {
        // Fixed in Vala 0.24
        public void to_hsv (double r, double g, double b, out double h, out double s, out double v);
    }
}

// Note, fixed in 1.10.0
namespace LightDM
{
    bool greeter_start_session_sync (LightDM.Greeter greeter, string session) throws GLib.Error;
}
