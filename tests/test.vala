
public class Test
{
    private static MainWindow setup ()
    {
        GLib.Test.log_set_fatal_handler (ignore_warnings);

        TestMainWindow main_window = new TestMainWindow ();
        var list = new TestList (main_window.get_background (), main_window.menubar);
        main_window.push_list (list);
        main_window.show_all();
        // Make sure we are really shown
        process_events ();

        return main_window;
    }

    private static bool ignore_warnings (string? log_domain,
                                         GLib.LogLevelFlags log_level,
                                         string message)
    {
        return ((log_level & (GLib.LogLevelFlags.LEVEL_CRITICAL |
                              GLib.LogLevelFlags.LEVEL_ERROR)) != 0);
    }

    private static void process_events ()
    {
        while (Gtk.events_pending ())
            Gtk.main_iteration ();
    }

    private static void wait_for_scrolling_end (TestList list)
    {
        while (list.is_scrolling ())
        {
            process_events ();
            Posix.usleep (10000);
        }
    }

    // BEGIN This group of functions asume email/password for remote directory servers
    private static DashEntry remote_directory_entry_email_field (TestList list)
    {
        var fixed = list.selected_entry.get_child() as Gtk.Fixed;
        var grid = fixed.get_children().nth_data(1) as Gtk.Grid;
        return grid.get_child_at(1, 1) as DashEntry;
    }

    private static DashEntry remote_directory_entry_password_field (TestList list)
    {
        var fixed = list.selected_entry.get_child() as Gtk.Fixed;
        var grid = fixed.get_children().nth_data(1) as Gtk.Grid;
        return grid.get_child_at(1, 2) as DashEntry;
    }
    // END This group of functions asume email/password for remote directory servers

    // BEGIN This group of functions asume domain/username/password for remote login servers
    private static DashEntry remote_login_entry_domain_field (TestList list)
    {
        var fixed = list.selected_entry.get_child() as Gtk.Fixed;
        var grid = fixed.get_children().nth_data(1) as Gtk.Grid;
        return grid.get_child_at(1, 1) as DashEntry;
    }

    private static DashEntry remote_login_entry_username_field (TestList list)
    {
        var fixed = list.selected_entry.get_child() as Gtk.Fixed;
        var grid = fixed.get_children().nth_data(1) as Gtk.Grid;
        return grid.get_child_at(1, 2) as DashEntry;
    }

    private static DashEntry remote_login_entry_password_field (TestList list)
    {
        var fixed = list.selected_entry.get_child() as Gtk.Fixed;
        var grid = fixed.get_children().nth_data(1) as Gtk.Grid;
        return grid.get_child_at(1, 3) as DashEntry;
    }
    // BEGIN This group of functions asume domain/username/password for remote login servers

    private static void do_scroll (TestList list, GreeterList.ScrollTarget direction)
    {
        process_events ();
        switch (direction)
        {
            case GreeterList.ScrollTarget.START:
                inject_key (list, Gdk.Key.Page_Up);
            break;
            case GreeterList.ScrollTarget.END:
                inject_key (list, Gdk.Key.Page_Down);
            break;
            case GreeterList.ScrollTarget.UP:
                inject_key (list, Gdk.Key.Up);
            break;
            case GreeterList.ScrollTarget.DOWN:
                inject_key (list, Gdk.Key.Down);
            break;
        }
        wait_for_scrolling_end (list);
    }

    private static void scroll_to_remote_login (TestList list)
    {
        do_scroll (list, GreeterList.ScrollTarget.END);
        while (list.selected_entry.id == "*guest")
        {
            do_scroll (list, GreeterList.ScrollTarget.END);
            process_events ();
            Posix.usleep (10000);
        }
    }

    private static void inject_key (Gtk.Widget w, int keyval)
    {
        // Make sure everything is flushed
        process_events ();

        Gdk.KeymapKey[] keys;

        bool success = Gdk.Keymap.get_default ().get_entries_for_keyval (keyval, out keys);
        GLib.assert (success);
        Gdk.Event event = new Gdk.Event(Gdk.EventType.KEY_PRESS);
        event.key.window = w.get_parent_window ();
        event.key.hardware_keycode = (int16)keys[0].keycode;
        event.key.keyval = keyval;
        event.set_device(Gdk.Display.get_default ().get_device_manager ().get_client_pointer ());
        event.key.time = Gdk.CURRENT_TIME;

        Gtk.main_do_event (event);
    }

    private static void wait_for_focus (Gtk.Widget w)
    {
        while (!w.has_focus)
        {
            process_events ();
            Posix.usleep (10000);
        }
    }

    public static void simple_navigation ()
    {
        MainWindow mw = setup ();
        TestList list = mw.stack.top () as TestList;

        // Wait until remote login appears
        scroll_to_remote_login (list);

        GLib.assert (list.num_entries() > 0);

        // Make sure we are at the beginning of the list
        do_scroll (list, GreeterList.ScrollTarget.START);
        GLib.assert (list.selected_entry.id == "active");

        // Scrolling up does nothing
        do_scroll (list, GreeterList.ScrollTarget.UP);
        GLib.assert (list.selected_entry.id == "active");

        // Scrolling down works
        do_scroll (list, GreeterList.ScrollTarget.DOWN);
        GLib.assert (list.selected_entry.id == "auth-error");

        // Remote Login is at the end;
        do_scroll (list, GreeterList.ScrollTarget.END);
        GLib.assert (list.selected_entry.id == "*remote_directory*http://crazyurl.com");

        mw.hide ();
    }

    public static void remote_login ()
    {
        MainWindow mw = setup ();
        TestList list = mw.stack.top () as TestList;

        // Wait until remote login appears
        scroll_to_remote_login (list);
        GLib.assert (list.selected_entry.id == "*remote_directory*http://crazyurl.com");
        GLib.assert (!list.selected_entry.has_errors);

        // If we answer without filling in any field -> error
        list.selected_entry.respond ({});
        GLib.assert (list.selected_entry.has_errors);

        // Go to first and back to last to clear the error
        do_scroll (list, GreeterList.ScrollTarget.START);
        do_scroll (list, GreeterList.ScrollTarget.END);
        GLib.assert (!list.selected_entry.has_errors);

        // Fill in a valid email and password
        // Check there is no error and we moved to the last logged in server
        var email = remote_directory_entry_email_field (list);
        var pwd = remote_directory_entry_password_field (list);
        email.text = "a@canonical.com";
        pwd.text = "password";
        list.selected_entry.respond ({});
        GLib.assert (!list.selected_entry.has_errors);
        GLib.assert (list.selected_entry.id == "*remote_login*http://rdpdefaultusername2.com*lwola");
        wait_for_scrolling_end (list);

        // Go back to the remote_directory entry and write the same password but an invalid email
        // Check there is error and we did not move anywhere
        while (!list.selected_entry.id.has_prefix("*remote_directory*http://crazyurl.com"))
            do_scroll (list, GreeterList.ScrollTarget.UP);
        email = remote_directory_entry_email_field (list);
        pwd = remote_directory_entry_password_field (list);
        email.text = "a @ foobar";
        pwd.text = "password";
        list.selected_entry.respond ({});
        GLib.assert (list.selected_entry.has_errors);
        GLib.assert (list.selected_entry.id == "*remote_directory*http://crazyurl.com");

        mw.hide ();
    }

    public static void remote_login_servers_updated_signal ()
    {
        MainWindow mw = setup ();
        TestList list = mw.stack.top () as TestList;

        // Wait until remote login appears
        scroll_to_remote_login (list);

        var email = remote_directory_entry_email_field (list);
        var pwd = remote_directory_entry_password_field (list);
        email.text = "a@canonical.com";
        pwd.text = "delay1";
        list.selected_entry.respond ({});
        GLib.assert (!list.selected_entry.has_errors);
        GLib.assert (list.selected_entry.id == "*remote_login*http://rdpdefaultusername2.com*lwola");

        bool done = false;
        // The delay1 code triggers at 5 seconds
        Timeout.add (5250, () =>
            {
                // If the directory server where were browsing disappears the login servers are removed too
                // and we get moved to the new directory server
                wait_for_scrolling_end (list);
                GLib.assert (list.selected_entry.id == "*remote_directory*http://internalcompayserver.com");
                done = true;
                return false;
            }
        );

        while (!done)
        {
            process_events ();
            Posix.usleep (10000);
        }

        mw.hide ();
    }

    public static void remote_login_servers_updated_signal_focus_not_in_remote_server ()
    {
        MainWindow mw = setup ();
        TestList list = mw.stack.top () as TestList;

        // Wait until remote login appears
        scroll_to_remote_login (list);

        var email = remote_directory_entry_email_field (list);
        var pwd = remote_directory_entry_password_field (list);
        email.text = "a@canonical.com";
        pwd.text = "delay1";
        list.selected_entry.respond ({});
        GLib.assert (!list.selected_entry.has_errors);
        GLib.assert (list.selected_entry.id == "*remote_login*http://rdpdefaultusername2.com*lwola");
        wait_for_scrolling_end (list);

        while (list.selected_entry.id.has_prefix("*remote_"))
        {
            do_scroll (list, GreeterList.ScrollTarget.UP);
        }
        string nonRemoteEntry = list.selected_entry.id;

        bool done = false;
        // The delay1 code triggers at 5 seconds
        Timeout.add (5250, () =>
            {
                // If we were not in a remote entry we are not moved even if the directory servers change
                // Moving down we find the new directory server
                GLib.assert (list.selected_entry.id == nonRemoteEntry);
                do_scroll (list, GreeterList.ScrollTarget.DOWN);
                GLib.assert (list.selected_entry.id == "*remote_directory*http://internalcompayserver.com");
                done = true;
                return false;
            }
        );

        while (!done)
        {
            process_events ();
            Posix.usleep (10000);
        }

        mw.hide ();
    }

    public static void remote_login_login_servers_updated_signal ()
    {
        MainWindow mw = setup ();
        TestList list = mw.stack.top () as TestList;

        // Wait until remote login appears
        scroll_to_remote_login (list);

        var email = remote_directory_entry_email_field (list);
        var pwd = remote_directory_entry_password_field (list);
        email.text = "a@canonical.com";
        pwd.text = "delay2";
        list.selected_entry.respond ({});
        GLib.assert (!list.selected_entry.has_errors);
        GLib.assert (list.selected_entry.id == "*remote_login*http://rdpdefaultusername2.com*lwola");

        bool done = false;
        // The delay2 code triggers at 5 seconds
        Timeout.add (5250, () =>
            {
                // If the login server we were disappears we get moved to a different one
                wait_for_scrolling_end (list);
                GLib.assert (list.selected_entry.id == "*remote_login*http://megacoolrdpserver.com*");
                done = true;
                return false;
            }
        );

        while (!done)
        {
            process_events ();
            Posix.usleep (10000);
        }

        mw.hide ();
    }

    public static void remote_login_login_servers_updated_signal_focus_not_in_removed_server ()
    {
        MainWindow mw = setup ();
        TestList list = mw.stack.top () as TestList;

        // Wait until remote login appears
        scroll_to_remote_login (list);

        var email = remote_directory_entry_email_field (list);
        var pwd = remote_directory_entry_password_field (list);
        email.text = "a@canonical.com";
        pwd.text = "delay2";
        list.selected_entry.respond ({});
        GLib.assert (!list.selected_entry.has_errors);
        GLib.assert (list.selected_entry.id == "*remote_login*http://rdpdefaultusername2.com*lwola");

        // Move to a server that won't be removed
        while (list.selected_entry.id != "*remote_login*http://coolrdpserver.com*")
            do_scroll (list, GreeterList.ScrollTarget.UP);

        bool done = false;
        // The delay2 code triggers at 5 seconds
        Timeout.add (5250, () =>
            {
                // If the login server we were did not disappear we are still in the same one
                wait_for_scrolling_end (list);
                GLib.assert (list.selected_entry.id == "*remote_login*http://coolrdpserver.com*");
                done = true;
                return false;
            }
        );

        while (!done)
        {
            process_events ();
            Posix.usleep (10000);
        }

        mw.hide ();
    }

    public static void remote_login_remote_login_changed_signal ()
    {
        MainWindow mw = setup ();
        TestList list = mw.stack.top () as TestList;

        // Wait until remote login appears
        scroll_to_remote_login (list);

        var email = remote_directory_entry_email_field (list);
        var pwd = remote_directory_entry_password_field (list);
        email.text = "a@canonical.com";
        pwd.text = "delay3";
        list.selected_entry.respond ({});
        GLib.assert (!list.selected_entry.has_errors);
        GLib.assert (list.selected_entry.id == "*remote_login*http://rdpdefaultusername2.com*lwola");

        bool done = false;
        // The delay3 code triggers at 5 seconds
        Timeout.add (5250, () =>
            {
                // If the remote login details change while on one of its servers the login servers are removed
                // and we get moved to the directory server
                wait_for_scrolling_end (list);
                GLib.assert (list.selected_entry.id == "*remote_directory*http://crazyurl.com");

                do_scroll (list, GreeterList.ScrollTarget.DOWN); // There are no server to log in
                GLib.assert (list.selected_entry.id == "*remote_directory*http://crazyurl.com");

                done = true;
                return false;
            }
        );

        while (!done)
        {
            process_events ();
            Posix.usleep (10000);
        }

        mw.hide ();
    }

    public static void remote_login_remote_login_changed_signalfocus_not_in_changed_server ()
    {
        MainWindow mw = setup ();
        TestList list = mw.stack.top () as TestList;

        // Wait until remote login appears
        scroll_to_remote_login (list);

        var email = remote_directory_entry_email_field (list);
        var pwd = remote_directory_entry_password_field (list);
        email.text = "a@canonical.com";
        pwd.text = "delay3";
        list.selected_entry.respond ({});
        GLib.assert (!list.selected_entry.has_errors);
        GLib.assert (list.selected_entry.id == "*remote_login*http://rdpdefaultusername2.com*lwola");
        wait_for_scrolling_end (list);

        while (list.selected_entry.id.has_prefix("*remote_"))
        {
            do_scroll (list, GreeterList.ScrollTarget.UP);
        }
        string nonRemoteEntry = list.selected_entry.id;

        bool done = false;
        // The delay3 code triggers at 5 seconds
        Timeout.add (5250, () =>
            {
                // If we were not in a remote entry we are not moved when we are asked to reauthenticate
                // What happens is that the login servers of that directory server get removed
                // Moving down we find the new directory server
                GLib.assert (list.selected_entry.id == nonRemoteEntry);
                do_scroll (list, GreeterList.ScrollTarget.DOWN);
                GLib.assert (list.selected_entry.id == "*remote_directory*http://crazyurl.com");

                do_scroll (list, GreeterList.ScrollTarget.DOWN); // There are no server to log in
                GLib.assert (list.selected_entry.id == "*remote_directory*http://crazyurl.com");
                done = true;
                return false;
            }
        );

        while (!done)
        {
            process_events ();
            Posix.usleep (10000);
        }

        mw.hide ();
    }

    public static void remote_login_authentication ()
    {
        MainWindow mw = setup ();
        TestList list = mw.stack.top () as TestList;

        // Wait until remote login appears
        scroll_to_remote_login (list);
        GLib.assert (list.selected_entry.id == "*remote_directory*http://crazyurl.com");
        GLib.assert (!list.selected_entry.has_errors);

        // Fill in a valid email and password
        // Check there is no error and we moved to the last logged in server
        var email = remote_directory_entry_email_field (list);
        var pwd = remote_directory_entry_password_field (list);
        email.text = "a@canonical.com";
        pwd.text = "password";
        list.selected_entry.respond ({});
        GLib.assert (!list.selected_entry.has_errors);
        GLib.assert (list.selected_entry.id == "*remote_login*http://rdpdefaultusername2.com*lwola");
        wait_for_scrolling_end (list);

        UnityGreeter.singleton.session_started = false;
        pwd = remote_login_entry_password_field (list);
        pwd.text = "password";
        list.selected_entry.respond ({});
        GLib.assert (UnityGreeter.singleton.session_started);

        mw.hide ();
    }

    public static void remote_login_cancel_authentication ()
    {
        MainWindow mw = setup ();
        TestList list = mw.stack.top () as TestList;

        // Wait until remote login appears
        scroll_to_remote_login (list);
        GLib.assert (list.selected_entry.id == "*remote_directory*http://crazyurl.com");
        GLib.assert (!list.selected_entry.has_errors);

        // Fill in a valid email and password
        // Check there is no error and we moved to the last logged in server
        var email = remote_directory_entry_email_field (list);
        var pwd = remote_directory_entry_password_field (list);
        email.text = "a@canonical.com";
        pwd.text = "password";
        list.selected_entry.respond ({});
        GLib.assert (!list.selected_entry.has_errors);
        GLib.assert (list.selected_entry.id == "*remote_login*http://rdpdefaultusername2.com*lwola");
        wait_for_scrolling_end (list);

        UnityGreeter.singleton.session_started = false;
        pwd = remote_login_entry_password_field (list);
        pwd.text = "delay";
        pwd.activate ();
        GLib.assert (!list.sensitive); // We are not sensitive because we are waiting for servers answer
        GLib.assert (pwd.did_respond); // We are showing the spinner
        list.cancel_authentication ();
        pwd = remote_login_entry_password_field (list);
        GLib.assert (list.sensitive); // We are sensitive again because we cancelled the login
        GLib.assert (!pwd.did_respond); // We are not showing the spinner anymore

        mw.hide ();
    }

    public static void remote_login_duplicate_entries()
    {
        MainWindow mw = setup ();
        TestList list = mw.stack.top () as TestList;

        scroll_to_remote_login (list); //Wait until remote login appears.
        GLib.assert (list.selected_entry.id == "*remote_directory*http://crazyurl.com");
        GLib.assert (!list.selected_entry.has_errors);

        // If we answer without filling in any field -> error
        list.selected_entry.respond ({});
        GLib.assert (list.selected_entry.has_errors);

        // Go to first and back to last to clear the error
        do_scroll (list, GreeterList.ScrollTarget.START);
        do_scroll (list, GreeterList.ScrollTarget.END);
        GLib.assert (!list.selected_entry.has_errors);

        // Fill in a valid email and password
        // Check there is no error and we moved to the last logged in server
        var email = remote_directory_entry_email_field (list);
        var pwd = remote_directory_entry_password_field (list);
        email.text = "a@canonical.com";
        pwd.text = "duplicate";
        list.selected_entry.respond ({});
        GLib.assert (!list.selected_entry.has_errors);        
        GLib.assert (list.selected_entry.id == "*remote_login*http://rdpdefaultusername.com*alowl2");        
        
        var username = remote_login_entry_username_field(list);
        var domain = remote_login_entry_domain_field(list);
        var password = remote_login_entry_password_field(list);		
        GLib.assert (username.text == "alowl2" && domain.text == "PRINTERS" && password.text == "duplicate2");
                        
        do_scroll (list, GreeterList.ScrollTarget.DOWN);
        GLib.assert (list.selected_entry.id == "*remote_login*http://rdpdefaultusername.com*alowl1");
        username = remote_login_entry_username_field(list);
        domain = remote_login_entry_domain_field(list);
        password = remote_login_entry_password_field(list);
        GLib.assert (username.text == "alowl1" && domain.text == "SCANNERS" && password.text == "duplicate1");	
        wait_for_scrolling_end (list);
        mw.hide ();
    }

    public static void email_autocomplete ()
    {
        MainWindow mw = setup ();
        TestList list = mw.stack.top () as TestList;

        // Wait until remote login appears
        scroll_to_remote_login (list);

        var email = remote_directory_entry_email_field (list);

        wait_for_focus (email);

        GLib.assert (email.text.length == 0);

        inject_key(email, Gdk.Key.a);
        GLib.assert (email.text == "a");

        inject_key(email, Gdk.Key.at);
        GLib.assert (email.text == "a@canonical.com");

        inject_key(email, Gdk.Key.u);
        GLib.assert (email.text == "a@ubuntu.org");

        inject_key(email, Gdk.Key.r);
        GLib.assert (email.text == "a@urban.net");

        inject_key(email, Gdk.Key.BackSpace);
        GLib.assert (email.text == "a@ur");

        inject_key(email, Gdk.Key.BackSpace);
        GLib.assert (email.text == "a@u");

        inject_key(email, Gdk.Key.BackSpace);
        GLib.assert (email.text == "a@");

        inject_key(email, Gdk.Key.c);
        GLib.assert (email.text == "a@canonical.com");

        inject_key(email, Gdk.Key.a);
        GLib.assert (email.text == "a@canonical.com");

        inject_key(email, Gdk.Key.n);
        GLib.assert (email.text == "a@canonical.com");

        inject_key(email, Gdk.Key.d);
        GLib.assert (email.text == "a@candy.com");

        mw.hide ();
    }

    public static void greeter_communcation ()
    {
        MainWindow mw = setup ();
        TestList list = mw.stack.top () as TestList;

        // Wait until remote login appears
        scroll_to_remote_login (list);

        // Fill in a valid email and password
        // Check there is no error and we moved to the last logged in server
        var email = remote_directory_entry_email_field (list);
        var pwd = remote_directory_entry_password_field (list);
        email.text = "a@canonical.com";
        pwd.text = "password";
        list.selected_entry.respond ({});
        wait_for_scrolling_end (list);

        while (list.selected_entry.id != "*remote_login*http://coolrdpserver.com*")
            do_scroll (list, GreeterList.ScrollTarget.UP);

        var domain = remote_login_entry_domain_field (list);
        var username = remote_login_entry_username_field (list);
        pwd = remote_login_entry_password_field (list);
        domain.text = "foo";
        username.text = "bar";
        pwd.text = "foobar";

        UnityGreeter.singleton.show_prompt("remote login:", LightDM.PromptType.QUESTION);
        GLib.assert (UnityGreeter.singleton.last_respond_response == username.text);
        UnityGreeter.singleton.show_prompt("remote host:", LightDM.PromptType.QUESTION);
        GLib.assert (UnityGreeter.singleton.last_respond_response == "http://coolrdpserver.com");
        UnityGreeter.singleton.show_prompt("domain:", LightDM.PromptType.QUESTION);
        GLib.assert (UnityGreeter.singleton.last_respond_response == domain.text);
        UnityGreeter.singleton.show_prompt("password:", LightDM.PromptType.SECRET);
        GLib.assert (UnityGreeter.singleton.last_respond_response == pwd.text);

        mw.hide ();
    }

    public static void unsupported_server_type ()
    {
        MainWindow mw = setup ();
        TestList list = mw.stack.top () as TestList;

        // Wait until remote login appears
        scroll_to_remote_login (list);

        // Fill in a valid email and password
        // Check there is no error and we moved to the last logged in server
        var email = remote_directory_entry_email_field (list);
        var pwd = remote_directory_entry_password_field (list);
        email.text = "a@canonical.com";
        pwd.text = "password";
        list.selected_entry.respond ({});
        wait_for_scrolling_end (list);

        while (list.selected_entry.id != "*remote_login*http://notsupportedserver.com*")
            do_scroll (list, GreeterList.ScrollTarget.UP);

        GLib.assert (list.selected_entry.has_errors);
        GLib.assert (!list.selected_entry.sensitive);

        mw.hide ();
    }

    public static void remote_login_only ()
    {
        UnityGreeter.singleton.test_mode = true;
        UnityGreeter.singleton.session_started = false;

	/* this configuration should result in the list containing only the remote login entry,
	   without any fallback manual entry */
        UnityGreeter.singleton._hide_users_hint = true;
        UnityGreeter.singleton._show_remote_login_hint = true;
        UnityGreeter.singleton._has_guest_account_hint = false;
        UnityGreeter.singleton._show_manual_login_hint = false;

        MainWindow mw = setup ();
        TestList list = mw.stack.top () as TestList;

	/* don't go too fast, otherwise the lastest gdk3 will lose control... */
	Posix.sleep(1);

	/* Wait for Remote Login to appear */
	bool rl_appeared = false;
	for (int i=0; i<100 && !rl_appeared; i++)
	{
            do_scroll (list, GreeterList.ScrollTarget.END);
            process_events ();
            if (list.selected_entry.id == "*remote_directory*http://crazyurl.com")
		rl_appeared = true;
	}

	GLib.assert (rl_appeared);
        GLib.assert (list.num_entries() == 1);
        GLib.assert (list.selected_entry.id == "*remote_directory*http://crazyurl.com");

	mw.hide ();
   }

   public static void manual_login_fallback ()
   {
        UnityGreeter.singleton.test_mode = true;
        UnityGreeter.singleton.session_started = false;

	/* this configuration should result in the list containing at least a manual entry */
        UnityGreeter.singleton._hide_users_hint = true;
        UnityGreeter.singleton._show_remote_login_hint = false;
        UnityGreeter.singleton._has_guest_account_hint = false;
        UnityGreeter.singleton._show_manual_login_hint = true;

        MainWindow mw = setup ();
        TestList list = mw.stack.top () as TestList;

	/* verify if the manual entry has been added as a fallback mechanism */
        GLib.assert (list.num_entries() == 1);
        GLib.assert (list.selected_entry.id == "*other");

	mw.hide ();
   }


    static void setup_gsettings()
    {
        try
        {
            var dir = GLib.DirUtils.make_tmp ("unity-greeter-test-XXXXXX");

            var schema_dir = Path.build_filename(dir, "share", "glib-2.0", "schemas");
            DirUtils.create_with_parents(schema_dir, 0700);

            Environment.set_variable("GSETTINGS_SCHEMA_DIR", schema_dir, true);

            var top_srcdir = Environment.get_variable("top_srcdir");
            if (top_srcdir == null || top_srcdir == "")
                top_srcdir = "..";
            if (Posix.system("cp %s/data/com.canonical.unity-greeter.gschema.xml %s".printf(top_srcdir, schema_dir)) != 0)
                error("Could not copy schema to %s", schema_dir);

            if (Posix.system("glib-compile-schemas %s".printf(schema_dir)) != 0)
                error("Could not compile schemas in %s", schema_dir);

            Environment.set_variable("GSETTINGS_BACKEND", "memory", true);
        }
        catch (Error e)
        {
            error("Error setting up gsettings: %s", e.message);
        }
    }

    public static int main (string[] args)
    {
        Gtk.test_init(ref args);

        setup_gsettings ();

        UnityGreeter.singleton = new UnityGreeter();
        UnityGreeter.singleton.test_mode = true;

        GLib.Test.add_func ("/Simple Navigation", simple_navigation);
        GLib.Test.add_func ("/Remote Login", remote_login);
        GLib.Test.add_func ("/Remote Login duplicate entries", remote_login_duplicate_entries);
        GLib.Test.add_func ("/Remote Login with Servers Updated signal", remote_login_servers_updated_signal);
        GLib.Test.add_func ("/Remote Login with Servers Updated signal and not in remote server", remote_login_servers_updated_signal_focus_not_in_remote_server);
        GLib.Test.add_func ("/Remote Login with Login Servers Updated signal", remote_login_login_servers_updated_signal);
        GLib.Test.add_func ("/Remote Login with Login Servers Updated signal and not in removed server", remote_login_login_servers_updated_signal_focus_not_in_removed_server);
        GLib.Test.add_func ("/Remote Login with Remote Login Changed signal", remote_login_remote_login_changed_signal);
        GLib.Test.add_func ("/Remote Login with Remote Login Changed signal and not in changed server", remote_login_remote_login_changed_signalfocus_not_in_changed_server);
        GLib.Test.add_func ("/Remote Login authentication", remote_login_authentication);
        GLib.Test.add_func ("/Remote Login cancel authentication", remote_login_cancel_authentication);
        GLib.Test.add_func ("/Email Autocomplete", email_autocomplete);
        GLib.Test.add_func ("/Greeter Communication", greeter_communcation);
        GLib.Test.add_func ("/Unsupported server type", unsupported_server_type);
        GLib.Test.add_func ("/Remote Login Only", remote_login_only);
        GLib.Test.add_func ("/Manual Login Fallback", manual_login_fallback);

        return GLib.Test.run();
    }

}
