public class Main : Object
{

    private static string? file = null;
    private static string? text = null;
    private static string? result = null;
    private const OptionEntry[] options = { 
	{"logo", 0, 0, OptionArg.FILENAME, ref file, "Path to logo", "LOGO"},
	{"text", 0, 0, OptionArg.STRING, ref text, "Sublogo text", "TEXT"},
	{"output", 0, 0, OptionArg.FILENAME, ref result, "Path to rendered output", "OUTPUT"},
	{null}
    };

    public static int main(string[] args) {
	try {
	    var opt_context = new OptionContext ("- OptionContext example");
	    opt_context.set_help_enabled (true);
	    opt_context.add_main_entries (options, null);
	    opt_context.parse (ref args);
	} catch (OptionError e) {    
	    stdout.printf ("error: %s\n", e.message);
	    stdout.printf ("Run '%s --help' to see a full list of available command line options.\n", args[0]);
	    return 0;
	}
	Cairo.ImageSurface surface = new Cairo.ImageSurface (Cairo.Format.ARGB32, 245, 43);
	Cairo.Context context = new Cairo.Context (surface);
	context.translate (42, 11);
	Cairo.ImageSurface logo = new Cairo.ImageSurface.from_png (file);
	context.set_source_surface (logo, 0, 0);
	context.paint();

	context.set_source_rgba (1, 1, 1, 1);
	context.translate (logo.get_width() + 0.25*logo.get_height(), logo.get_height());

	var font_description = new Pango.FontDescription();
	font_description.set_family("Ubuntu");
	font_description.set_size((int)(0.75*logo.get_height() * Pango.SCALE));
	var layout = Pango.cairo_create_layout (context);
	layout.set_font_description (font_description);
	layout.set_text (text, -1);
	Pango.cairo_show_layout_line(context, layout.get_line(0));

	surface.write_to_png(result);
	return 0;
    }
}
