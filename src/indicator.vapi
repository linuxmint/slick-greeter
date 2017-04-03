[CCode (cprefix = "Indicator", lower_case_cprefix = "indicator_")]
namespace Indicator {
	[CCode (cheader_filename = "gtk/gtk.h,libindicator/indicator.h,libindicator/indicator-desktop-shortcuts.h,libindicator/indicator-image-helper.h,libindicator/indicator-object.h,libindicator/indicator-service.h,libindicator/indicator-service-manager.h")]
	public class DesktopShortcuts : GLib.Object {
		[CCode (has_construct_function = false)]
		public DesktopShortcuts (string file, string identity);
		public unowned string get_nicks ();
		public bool nick_exec (string nick);
		public unowned string nick_get_name (string nick);
		public string desktop_file { construct; }
		[NoAccessorMethod]
		public string identity { owned get; construct; }
	}
	[CCode (cheader_filename = "libindicator/indicator-object.h")]
	public class Object : GLib.Object {
		[CCode (has_construct_function = false)]
		protected Object ();
		public bool check_environment (string env);
		[NoWrapper]
		public virtual void entry_activate (Indicator.ObjectEntry entry, uint timestamp);
		[NoWrapper]
		public virtual void entry_close (Indicator.ObjectEntry entry, uint timestamp);
		[CCode (has_construct_function = false)]
		public Object.from_file (string file);
		[NoWrapper]
		public virtual unowned string get_accessible_desc ();
		public virtual GLib.List<unowned ObjectEntry> get_entries ();
		public unowned string[] get_environment ();
		[NoWrapper]
		public virtual unowned Gtk.Image get_image ();
		[NoWrapper]
		public virtual unowned Gtk.Label get_label ();
		public virtual uint get_location (Indicator.ObjectEntry entry);
		[NoWrapper]
		public virtual unowned Gtk.Menu get_menu ();
		[NoWrapper]
		public virtual unowned string get_name_hint ();
		public virtual bool get_show_now (Indicator.ObjectEntry entry);
		public virtual int get_position ();
		[NoWrapper]
		public virtual void reserved1 ();
		[NoWrapper]
		public virtual void reserved2 ();
		[NoWrapper]
		public virtual void reserved3 ();
		[NoWrapper]
		public virtual void reserved4 ();
		[NoWrapper]
		public virtual void reserved5 ();
		public void set_environment (string[] env);
		public virtual signal void accessible_desc_update (Indicator.ObjectEntry entry);
		public virtual signal void entry_added (Indicator.ObjectEntry entry);
		public virtual signal void entry_moved (Indicator.ObjectEntry entry, uint old_pos, uint new_pos);
		public virtual signal void entry_removed (Indicator.ObjectEntry entry);
		public virtual signal void entry_scrolled (Indicator.ObjectEntry entry, uint delta, Indicator.ScrollDirection direction);
		public virtual signal void menu_show (Indicator.ObjectEntry entry, uint timestamp);
		public virtual signal void show_now_changed (Indicator.ObjectEntry entry, bool show_now_state);
	}
	[CCode (cheader_filename = "libindicator/indicator-ng.h")]
	public class Ng : Object {
		[CCode (has_construct_function = false)]
		public Ng.for_profile (string filename, string profile) throws GLib.Error;
	}
	[Compact]
	[CCode (cheader_filename = "gtk/gtk.h,libindicator/indicator.h,libindicator/indicator-desktop-shortcuts.h,libindicator/indicator-image-helper.h,libindicator/indicator-object.h,libindicator/indicator-service.h,libindicator/indicator-service-manager.h")]
	public class ObjectEntry {
		public weak string accessible_desc;
		public weak Gtk.Image image;
		public weak Gtk.Label label;
		public weak Gtk.Menu menu;
		public weak string name_hint;
		public weak GLib.Callback reserved1;
		public weak GLib.Callback reserved2;
		public weak GLib.Callback reserved3;
		public weak GLib.Callback reserved4;
		public static void activate (Indicator.Object io, Indicator.ObjectEntry entry, uint timestamp);
		public static void close (Indicator.Object io, Indicator.ObjectEntry entry, uint timestamp);
	}
	[CCode (cheader_filename = "gtk/gtk.h,libindicator/indicator.h,libindicator/indicator-desktop-shortcuts.h,libindicator/indicator-image-helper.h,libindicator/indicator-object.h,libindicator/indicator-service.h,libindicator/indicator-service-manager.h")]
	public class Service : GLib.Object {
		[CCode (has_construct_function = false)]
		public Service (string name);
		[NoWrapper]
		public virtual void indicator_service_reserved1 ();
		[NoWrapper]
		public virtual void indicator_service_reserved2 ();
		[NoWrapper]
		public virtual void indicator_service_reserved3 ();
		[NoWrapper]
		public virtual void indicator_service_reserved4 ();
		[CCode (has_construct_function = false)]
		public Service.version (string name, uint version);
		[NoAccessorMethod]
		public string name { owned get; set; }
		public virtual signal void shutdown ();
	}
	[CCode (cheader_filename = "gtk/gtk.h,libindicator/indicator.h,libindicator/indicator-desktop-shortcuts.h,libindicator/indicator-image-helper.h,libindicator/indicator-object.h,libindicator/indicator-service.h,libindicator/indicator-service-manager.h")]
	public class ServiceManager : GLib.Object {
		[CCode (has_construct_function = false)]
		public ServiceManager (string dbus_name);
		public bool connected ();
		[NoWrapper]
		public virtual void indicator_service_manager_reserved1 ();
		[NoWrapper]
		public virtual void indicator_service_manager_reserved2 ();
		[NoWrapper]
		public virtual void indicator_service_manager_reserved3 ();
		[NoWrapper]
		public virtual void indicator_service_manager_reserved4 ();
		public void set_refresh (uint time_in_ms);
		[CCode (has_construct_function = false)]
		public ServiceManager.version (string dbus_name, uint version);
		[NoAccessorMethod]
		public string name { owned get; set; }
		public virtual signal void connection_change (bool connected);
	}
	[CCode (cprefix = "INDICATOR_OBJECT_SCROLL_", has_type_id = false, cheader_filename = "gtk/gtk.h,libindicator/indicator.h,libindicator/indicator-desktop-shortcuts.h,libindicator/indicator-image-helper.h,libindicator/indicator-object.h,libindicator/indicator-service.h,libindicator/indicator-service-manager.h")]
	public enum ScrollDirection {
		UP,
		DOWN,
		LEFT,
		RIGHT
	}
	[CCode (cheader_filename = "gtk/gtk.h,libindicator/indicator.h,libindicator/indicator-desktop-shortcuts.h,libindicator/indicator-image-helper.h,libindicator/indicator-object.h,libindicator/indicator-service.h,libindicator/indicator-service-manager.h", has_target = false)]
	public delegate GLib.Type get_type_t ();
	[CCode (cheader_filename = "gtk/gtk.h,libindicator/indicator.h,libindicator/indicator-desktop-shortcuts.h,libindicator/indicator-image-helper.h,libindicator/indicator-object.h,libindicator/indicator-service.h,libindicator/indicator-service-manager.h", has_target = false)]
	public delegate unowned string get_version_t ();
	[CCode (cheader_filename = "gtk/gtk.h,libindicator/indicator.h,libindicator/indicator-desktop-shortcuts.h,libindicator/indicator-image-helper.h,libindicator/indicator-object.h,libindicator/indicator-service.h,libindicator/indicator-service-manager.h")]
	public const string GET_TYPE_S;
	[CCode (cheader_filename = "gtk/gtk.h,libindicator/indicator.h,libindicator/indicator-desktop-shortcuts.h,libindicator/indicator-image-helper.h,libindicator/indicator-object.h,libindicator/indicator-service.h,libindicator/indicator-service-manager.h")]
	public const string GET_VERSION_S;
	[CCode (cheader_filename = "gtk/gtk.h,libindicator/indicator.h,libindicator/indicator-desktop-shortcuts.h,libindicator/indicator-image-helper.h,libindicator/indicator-object.h,libindicator/indicator-service.h,libindicator/indicator-service-manager.h")]
	public const string OBJECT_SIGNAL_ACCESSIBLE_DESC_UPDATE;
	[CCode (cheader_filename = "gtk/gtk.h,libindicator/indicator.h,libindicator/indicator-desktop-shortcuts.h,libindicator/indicator-image-helper.h,libindicator/indicator-object.h,libindicator/indicator-service.h,libindicator/indicator-service-manager.h")]
	public const string OBJECT_SIGNAL_ENTRY_ADDED;
	[CCode (cheader_filename = "gtk/gtk.h,libindicator/indicator.h,libindicator/indicator-desktop-shortcuts.h,libindicator/indicator-image-helper.h,libindicator/indicator-object.h,libindicator/indicator-service.h,libindicator/indicator-service-manager.h")]
	public const string OBJECT_SIGNAL_ENTRY_MOVED;
	[CCode (cheader_filename = "gtk/gtk.h,libindicator/indicator.h,libindicator/indicator-desktop-shortcuts.h,libindicator/indicator-image-helper.h,libindicator/indicator-object.h,libindicator/indicator-service.h,libindicator/indicator-service-manager.h")]
	public const string OBJECT_SIGNAL_ENTRY_REMOVED;
	[CCode (cheader_filename = "gtk/gtk.h,libindicator/indicator.h,libindicator/indicator-desktop-shortcuts.h,libindicator/indicator-image-helper.h,libindicator/indicator-object.h,libindicator/indicator-service.h,libindicator/indicator-service-manager.h")]
	public const string OBJECT_SIGNAL_ENTRY_SCROLLED;
	[CCode (cheader_filename = "gtk/gtk.h,libindicator/indicator.h,libindicator/indicator-desktop-shortcuts.h,libindicator/indicator-image-helper.h,libindicator/indicator-object.h,libindicator/indicator-service.h,libindicator/indicator-service-manager.h")]
	public const string OBJECT_SIGNAL_MENU_SHOW;
	[CCode (cheader_filename = "gtk/gtk.h,libindicator/indicator.h,libindicator/indicator-desktop-shortcuts.h,libindicator/indicator-image-helper.h,libindicator/indicator-object.h,libindicator/indicator-service.h,libindicator/indicator-service-manager.h")]
	public const string OBJECT_SIGNAL_SHOW_NOW_CHANGED;
	[CCode (cheader_filename = "gtk/gtk.h,libindicator/indicator.h,libindicator/indicator-desktop-shortcuts.h,libindicator/indicator-image-helper.h,libindicator/indicator-object.h,libindicator/indicator-service.h,libindicator/indicator-service-manager.h")]
	public const string SERVICE_MANAGER_SIGNAL_CONNECTION_CHANGE;
	[CCode (cheader_filename = "gtk/gtk.h,libindicator/indicator.h,libindicator/indicator-desktop-shortcuts.h,libindicator/indicator-image-helper.h,libindicator/indicator-object.h,libindicator/indicator-service.h,libindicator/indicator-service-manager.h")]
	public const string SERVICE_SIGNAL_SHUTDOWN;
	[CCode (cheader_filename = "gtk/gtk.h,libindicator/indicator.h,libindicator/indicator-desktop-shortcuts.h,libindicator/indicator-image-helper.h,libindicator/indicator-object.h,libindicator/indicator-service.h,libindicator/indicator-service-manager.h")]
	public const int SET_VERSION;
	[CCode (cheader_filename = "gtk/gtk.h,libindicator/indicator.h,libindicator/indicator-desktop-shortcuts.h,libindicator/indicator-image-helper.h,libindicator/indicator-object.h,libindicator/indicator-service.h,libindicator/indicator-service-manager.h")]
	public const string VERSION;
	[CCode (cname = "get_version", cheader_filename = "gtk/gtk.h,libindicator/indicator.h,libindicator/indicator-desktop-shortcuts.h,libindicator/indicator-image-helper.h,libindicator/indicator-object.h,libindicator/indicator-service.h,libindicator/indicator-service-manager.h")]
	public static unowned string get_version ();
	[CCode (cheader_filename = "gtk/gtk.h,libindicator/indicator.h,libindicator/indicator-desktop-shortcuts.h,libindicator/indicator-image-helper.h,libindicator/indicator-object.h,libindicator/indicator-service.h,libindicator/indicator-service-manager.h")]
	public static unowned Gtk.Image image_helper (string name);
	[CCode (cheader_filename = "gtk/gtk.h,libindicator/indicator.h,libindicator/indicator-desktop-shortcuts.h,libindicator/indicator-image-helper.h,libindicator/indicator-object.h,libindicator/indicator-service.h,libindicator/indicator-service-manager.h")]
	public static void image_helper_update (Gtk.Image image, string name);
}

[CCode (cheader_filename="libido/libido.h", lower_case_cprefix = "ido_")]
namespace Ido {
	public void init ();
}
