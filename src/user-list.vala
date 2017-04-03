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

int remote_server_field_sort_function (RemoteServerField? item1, RemoteServerField? item2)
{
    string[] sorted_fields = { "domain", "username", "email", "password" };
    foreach (var field in sorted_fields)
    {
        if (item1.type == field)
            return -1;
        if (item2.type == field)
            return 1;
    }

    return (item1.type < item2.type) ? -1 : 0;
}

public class UserList : GreeterList
{
    private bool _offer_guest = false;
    public bool offer_guest
    {
        get { return _offer_guest; }
        set
        {
            _offer_guest = value;
            if (value)
                add_user ("*guest", _("Guest Session"));
            else
                remove_entry ("*guest");
        }
    }

    private Gdk.Pixbuf message_pixbuf;

    private uint change_background_timeout = 0;

    private uint remote_login_service_watch;
    private RemoteLoginService remote_login_service;
    private List<RemoteServer?> remote_directory_server_list = new List<RemoteServer?> ();
    private List<RemoteServer?> remote_login_server_list = new List<RemoteServer?> ();
    private HashTable<string, Gtk.Widget> current_remote_fields;
    private string currently_browsing_server_url;
    private string currently_browsing_server_email;
    private EmailAutocompleter remote_server_email_field_autocompleter;

    /* User to authenticate against */
    private string ?authenticate_user = null;

    private bool show_hidden_users_ = false;
    public bool show_hidden_users
    {
        set
        {
            show_hidden_users_ = value;

            if (UnityGreeter.singleton.test_mode)
            {
                if (value)
                    add_user ("hidden", "Hidden User", null, false, false, null);
                else
                    remove_entry ("hidden");
                return;
            }

            var hidden_users = UGSettings.get_strv (UGSettings.KEY_HIDDEN_USERS);
            if (!value)
            {
                foreach (var username in hidden_users)
                    remove_entry (username);
                return;
            }

            var users = LightDM.UserList.get_instance ();
            foreach (var user in users.users)
            {
                foreach (var username in hidden_users)
                {
                    if (user.name == username)
                    {
                        debug ("Showing hidden user %s", username);
                        user_added_cb (user);
                    }
                }
            }
        }

        get
        {
            return show_hidden_users_;
        }
    }

    private string _default_session = "ubuntu";
    public string default_session
    {
        get
        {
            return _default_session;
        }
        set
        {
            _default_session = value;
            if (selected_entry != null)
                selected_entry.set_options_image (get_badge ());
        }
    }

    private string? _session = null;
    public string? session
    {
        get
        {
            return _session;
        }
        set
        {
            _session = value;
            if (selected_entry != null)
                selected_entry.set_options_image (get_badge ());
        }
    }

    public UserList (Background bg, MenuBar mb)
    {
        Object (background: bg, menubar: mb);
    }

    construct
    {
        menubar.notify["high-contrast"].connect (() => { change_background (); });
        entry_displayed_start.connect (() => { change_background (); });
        entry_displayed_done.connect (() => { change_background (); });

        try
        {
            message_pixbuf = new Gdk.Pixbuf.from_file (Path.build_filename (Config.PKGDATADIR, "message.png", null));
        }
        catch (Error e)
        {
            debug ("Error loading message image: %s", e.message);
        }

        fill_list ();

        entry_selected.connect (entry_selected_cb);

        connect_to_lightdm ();

        if (!UnityGreeter.singleton.test_mode &&
            UnityGreeter.singleton.show_remote_login_hint ())
            remote_login_service_watch = Bus.watch_name (BusType.SESSION,
                                            "com.canonical.RemoteLogin",
                                            BusNameWatcherFlags.AUTO_START,
                                            on_remote_login_service_appeared,
                                            on_remote_login_service_vanished);

    }

    private void remove_remote_servers ()
    {
        remote_directory_server_list = new List<RemoteServer?> ();
        remote_login_server_list = new List<RemoteServer?> ();
        remove_entries_with_prefix ("*remote");
    }

    private void remove_remote_login_servers ()
    {
        remote_login_server_list = new List<RemoteServer?> ();
        remove_entries_with_prefix ("*remote_login");

        /* If we have no entries at all, we should show manual */
        if (!always_show_manual)
            add_manual_entry ();
    }

    private async void query_directory_servers ()
    {
        try
        {
            RemoteServer[] server_list;
            yield remote_login_service.get_servers (out server_list);
            set_remote_directory_servers (server_list);
        }
        catch (IOError e)
        {
            debug ("Calling GetServers on com.canonical.RemoteLogin dbus service failed. Error: %s", e.message);
            remove_remote_servers ();
        }
    }

    private string user_list_name_for_remote_directory_server (RemoteServer remote_server)
    {
        return "*remote_directory*" + remote_server.url;
    }

    private string username_from_remote_server_fields(RemoteServer remote_server)
    {
        var username = "";
        foreach (var f in remote_server.fields)
        {
            if (f.type == "username" && f.default_value != null)
            {
                username = f.default_value.get_string ();
                break;
            }
        }
        return username;
     }

    private string user_list_name_for_remote_login_server (RemoteServer remote_server)
    {
        var username = username_from_remote_server_fields (remote_server);
        return "*remote_login*" + remote_server.url + "*" + username;
    }

    private string url_from_remote_loding_server_list_name (string remote_server_list_name)
    {
        return remote_server_list_name.split ("*")[2];
    }
    
    private string username_from_remote_loding_server_list_name (string remote_server_list_name)
    {
        return remote_server_list_name.split ("*")[3];
    }

    private void set_remote_directory_servers (RemoteServer[] server_list)
    {
        /* Add new servers */
        foreach (var remote_server in server_list)
        {
            var list_name = user_list_name_for_remote_directory_server (remote_server);
            if (find_entry (list_name) == null)
            {
                var e = new PromptBox (list_name);
                e.label = remote_server.name;
                e.respond.connect (remote_directory_respond_cb);
                e.show_options.connect (show_remote_account_dialog);
                add_entry (e);

                remote_directory_server_list.append (remote_server);
            }
        }

        /* Remove gone servers */
        unowned List<RemoteServer?> it = remote_directory_server_list;
        while (it != null)
        {
            var remote_server = it.data;
            var found = false;
            for (int i = 0; !found && i < server_list.length; i++)
            {
                found = remote_server.url == server_list[i].url;
            }
            if (!found)
            {
                if (remote_server.url == currently_browsing_server_url)
                {
                    /* The server we where "browsing" disappeared, so kill its children */
                    remove_remote_login_servers ();
                    currently_browsing_server_url = "";
                    currently_browsing_server_email = "";
                }
                remove_entry (user_list_name_for_remote_directory_server (remote_server));
                unowned List<RemoteServer?> newIt = it.next;
                remote_directory_server_list.delete_link (it);
                it = newIt;
            }
            else
            {
                it = it.next;
            }
        }

        /* Remove manual option unless specified */
        if (remote_directory_server_list.length() > 0 && !always_show_manual) {
            debug ("removing manual login since we have a remote login entry");
            remove_entry ("*other");
        }
    }

    private PromptBox create_prompt_for_login_server (RemoteServer remote_server)
    {
        var e = new PromptBox (user_list_name_for_remote_login_server (remote_server));
        e.label = remote_server.name;
        e.respond.connect (remote_login_respond_cb);
        add_entry (e);
        remote_login_server_list.append (remote_server);

        return e;
    }

    private void remote_login_servers_updated (string url, string email_address, string data_type, RemoteServer[] server_list)
    {
        if (currently_browsing_server_url == url && currently_browsing_server_email == email_address)
        {
            /* Add new servers */
            foreach (var remote_server in server_list)
            {
                var list_name = user_list_name_for_remote_login_server (remote_server);
                if (find_entry (list_name) == null)
                    create_prompt_for_login_server (remote_server);
            }

            /* Remove gone servers */
            unowned List<RemoteServer?> it = remote_login_server_list;
            while (it != null)
            {
                RemoteServer remote_server = it.data;
                var found = false;
                for (var i = 0; !found && i < server_list.length; i++)
                    found = remote_server.url == server_list[i].url;
                if (!found)
                {
                    remove_entry (user_list_name_for_remote_login_server (remote_server));
                    unowned List<RemoteServer?> newIt = it.next;
                    remote_login_server_list.delete_link (it);
                    it = newIt;
                }
                else
                {
                    it = it.next;
                }
            }
        }
    }

    private void remote_login_changed (string url, string email_address)
    {
        if (currently_browsing_server_url == url && currently_browsing_server_email == email_address)
        {
            /* Something happened and we are being asked for re-authentication by the remote-login-service */
            remove_remote_login_servers ();
            currently_browsing_server_url = "";
            currently_browsing_server_email = "";

            var directory_list_name = "*remote_directory*" + url;
            set_active_entry (directory_list_name);
        }
    }

    private void on_remote_login_service_appeared (DBusConnection conn, string name)
    {
        Bus.get_proxy.begin<RemoteLoginService> (BusType.SESSION,
            "com.canonical.RemoteLogin",
            "/com/canonical/RemoteLogin",
            0,
            null,
            (obj, res) => {
                try
                {
                    remote_login_service = Bus.get_proxy.end<RemoteLoginService> (res);
                    remote_login_service.servers_updated.connect (set_remote_directory_servers);
                    remote_login_service.login_servers_updated.connect (remote_login_servers_updated);
                    remote_login_service.login_changed.connect (remote_login_changed);
                    query_directory_servers.begin ();
                }
                catch (IOError e)
                {
                    debug ("Getting the com.canonical.RemoteLogin dbus service failed. Error: %s", e.message);
                    remove_remote_servers ();
                    remote_login_service = null;
                }
            }
        );
    }

    private void on_remote_login_service_vanished (DBusConnection conn, string name)
    {
        remove_remote_servers ();
        remote_login_service = null;

        /* provide a fallback manual login option */
        if (UnityGreeter.singleton.hide_users_hint ()) {
            add_manual_entry();
            set_active_entry ("*other");
        }
    }

    private async void remote_directory_respond_cb ()
    {
        remove_remote_login_servers ();
        currently_browsing_server_url = "";
        currently_browsing_server_email = "";

        var password_field = current_remote_fields.get ("password") as DashEntry;
        var email_field = current_remote_fields.get ("email") as Gtk.Entry;
        if (password_field == null)
        {
            debug ("Something wrong happened in remote_directory_respond_cb. There was no password field");
            return;
        }
        if (email_field == null)
        {
            debug ("Something wrong happened in remote_directory_respond_cb. There was no email field");
            return;
        }

        RemoteServer[] server_list = {};
        var email = email_field.text;
        var email_valid = false;
        try
        {
            /* Check email address is valid
             * Using the html5 definition of a valid e-mail address
             * http://www.w3.org/TR/html5/states-of-the-type-attribute.html#valid-e-mail-address */
            var re = new Regex ("[a-zA-Z0-9.!#$%&'\\*\\+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\\.[a-zA-Z0-9-]+)*");
            MatchInfo info;
            email_valid = re.match_all (email, 0, out info);
            email_valid = email_valid && info.get_match_count () > 0 && info.fetch (0) == email;
        }
        catch (RegexError e)
        {
            debug ("Calling email regex match failed. Error: %s", e.message);
        }

        selected_entry.reset_messages ();
        if (!email_valid)
        {
            will_clear = true;
            show_message (_("Please enter a complete e-mail address"), true);
            create_remote_fields_for_current_item.begin (remote_directory_server_list);
        }
        else
        {
            var login_success = false;
            try
            {
                var url = url_from_remote_loding_server_list_name (selected_entry.id);
                if (UnityGreeter.singleton.test_mode)
                {
                    if (password_field.text == "password")
                    {
                        test_fill_remote_login_servers (out server_list);
                        login_success = true;
                    }
                    else if (password_field.text == "delay1")
                    {
                        test_fill_remote_login_servers (out server_list);
                        login_success = true;
                        Timeout.add (5000, () => { test_call_set_remote_directory_servers (); return false; });
                    }
                    else if (password_field.text == "delay2")
                    {
                        test_fill_remote_login_servers (out server_list);
                        login_success = true;
                        Timeout.add (5000, () => { test_call_remote_login_servers_updated (); return false; });
                    }
                    else if (password_field.text == "delay3")
                    {
                        test_fill_remote_login_servers (out server_list);
                        login_success = true;
                        Timeout.add (5000, () => { remote_login_changed (currently_browsing_server_url, currently_browsing_server_email); return false; });
                    }
                    else if (password_field.text == "duplicate")
                    {
                        test_fill_remote_login_servers_duplicate_entries (out server_list);
                        login_success = true;                        
                    }
                }
                else
                {
                    string data_type;
                    bool allowcache = true;
                    // If we had an error and are retrying the same user and server, do not use the cache on R-L-S
                    if (selected_entry.has_errors && currently_browsing_server_email == email && currently_browsing_server_url == url)
                        allowcache = false;
                    yield remote_login_service.get_servers_for_login (url, email, password_field.text, allowcache, out login_success, out data_type, out server_list);
                }
                currently_browsing_server_url = url;
                currently_browsing_server_email = email;
            }
            catch (IOError e)
            {
                debug ("Calling get_servers in com.canonical.RemoteLogin dbus service failed. Error: %s", e.message);
            }

            if (login_success)
            {
                password_field.did_respond = false;
                if (server_list.length == 0)
                    show_remote_account_dialog ();
                else
                {
                    var last_used_server_list_name = "";
                    foreach (var remote_server in server_list)
                    {
                        var e = create_prompt_for_login_server (remote_server);
                        if (remote_server.last_used_server)
                            last_used_server_list_name = e.id;
                    }
                    if (last_used_server_list_name != "")
                        set_active_entry (last_used_server_list_name);
                    else
                        set_active_first_entry_with_prefix ("*remote_login");
                }
            }
            else
            {
                will_clear = true;
                show_message (_("Incorrect e-mail address or password"), true);
                create_remote_fields_for_current_item.begin (remote_directory_server_list);
            }
        }
    }

    private void remote_login_respond_cb ()
    {
        sensitive = false;
        will_clear = true;
        greeter_authenticating_user = selected_entry.id;
        if (UnityGreeter.singleton.test_mode)
        {
            Gtk.Entry field = current_remote_fields.get ("password") as Gtk.Entry;
            test_is_authenticated = field.text == "password";
            if (field.text == "delay")
                Timeout.add (5000, () => { authentication_complete_cb (); return false; });
            else
                authentication_complete_cb ();
        }
        else
        {
            UnityGreeter.singleton.authenticate_remote (get_lightdm_session (), null);
            remote_login_service.set_last_used_server.begin (currently_browsing_server_url, url_from_remote_loding_server_list_name (selected_entry.id));
        }
    }

    private void show_remote_account_dialog ()
    {
        var dialog = new Gtk.MessageDialog (null, 0, Gtk.MessageType.OTHER, Gtk.ButtonsType.NONE, "");
        dialog.set_position (Gtk.WindowPosition.CENTER_ALWAYS);
        dialog.secondary_text = _("If you have an account on an RDP or Citrix server, Remote Login lets you run applications from that server.");
        // For 12.10 we still don't support Citrix
        dialog.secondary_text = _("If you have an account on an RDP server, Remote Login lets you run applications from that server.");
        if (offer_guest)
        {
            dialog.add_button (_("Cancel"), 0);
            var b = dialog.add_button (_("Set Up…"), 1);
            b.grab_focus ();
            dialog.text = _("You need an Ubuntu Remote Login account to use this service. Would you like to set up an account now?");
        }
        else
        {
            dialog.add_button (_("OK"), 0);
            dialog.text = _("You need an Ubuntu Remote Login account to use this service. Visit uccs.canonical.com to set up an account.");
        }

        dialog.show_all ();
        dialog.response.connect ((id) =>
        {
            if (id == 1)
            {
                var config_session = "uccsconfigure";
                if (is_supported_remote_session (config_session))
                {
                    greeter_authenticating_user = selected_entry.id;
                    UnityGreeter.singleton.authenticate_remote (config_session, null);
                }
            }
            dialog.destroy ();
        });
        dialog.run ();
    }

    private bool change_background_timeout_cb ()
    {
        string? new_background_file = null;
        if (menubar.high_contrast || !UGSettings.get_boolean (UGSettings.KEY_DRAW_USER_BACKGROUNDS))
            new_background_file = null;
        else if (selected_entry is UserPromptBox)
            new_background_file = (selected_entry as UserPromptBox).background;

        background.current_background = new_background_file;

        change_background_timeout = 0;
        return false;
    }

    private void change_background ()
    {
        if (background.current_background != null)
        {
            if (change_background_timeout == 0)
                change_background_timeout = Idle.add (change_background_timeout_cb);
        }
        else
            change_background_timeout_cb ();
    }

    protected static int user_list_compare_entry (PromptBox a, PromptBox b)
    {
        if (a.id.has_prefix ("*remote_directory") && !b.id.has_prefix ("*remote_directory"))
            return 1;
        if (a.id.has_prefix ("*remote_login") && !b.id.has_prefix ("*remote_login"))
            return 1;

        /* Fall back to default behaviour of the GreeterList sorter */
        return GreeterList.compare_entry (a, b);
    }

    protected override void insert_entry (PromptBox entry)
    {
        entries.insert_sorted (entry, user_list_compare_entry);
    }

    protected override void setup_prompt_box (bool fade = true)
    {
        base.setup_prompt_box (fade);
        var userbox = selected_entry as UserPromptBox;
        if (userbox != null)
            selected_entry.set_is_active (userbox.is_active);
    }

    private void entry_selected_cb (string? username)
    {
        UnityGreeter.singleton.set_state ("last-user", username);
        if (selected_entry is UserPromptBox)
            session = (selected_entry as UserPromptBox).session;
        else
            session = null;
        selected_entry.clear ();

        /* Reset this variable so it can be freed */
        remote_server_email_field_autocompleter = null;

        start_authentication ();
    }

    protected override void start_authentication ()
    {
        sensitive = true;
        greeter_authenticating_user = "";
        if (selected_entry.id.has_prefix ("*remote_directory"))
        {
            prompted = true;
            create_remote_fields_for_current_item.begin (remote_directory_server_list);
        }
        else if (selected_entry.id.has_prefix ("*remote_login"))
        {
            prompted = true;
            create_remote_fields_for_current_item.begin (remote_login_server_list);
        }
        else
            base.start_authentication ();
    }

    private async void create_remote_fields_for_current_item (List<RemoteServer?> server_list)
    {
        current_remote_fields = new HashTable<string, Gtk.Widget> (str_hash, str_equal);
        var url = url_from_remote_loding_server_list_name (selected_entry.id);
        var username = username_from_remote_loding_server_list_name (selected_entry.id);
        
        foreach (var remote_server in server_list)
        {
            var remote_username = username_from_remote_server_fields (remote_server);
            if (remote_server.url == url && (username == null || username == remote_username))
            {
                if (selected_entry.id.has_prefix ("*remote_login"))
                {
                    if (!is_supported_remote_session (remote_server.type))
                    {
                        show_message (_("Server type not supported."), true);
                    }
                }

                var fields = new List<RemoteServerField?> ();
                foreach (var field in remote_server.fields)
                    fields.append (field);
                fields.sort (remote_server_field_sort_function);
                foreach (var field in fields)
                {
                    Gtk.Widget? widget = null;
                    var default_value = "";
                    if (field.default_value != null && field.default_value.is_of_type (VariantType.STRING))
                        default_value = field.default_value.get_string ();
                    if (field.type == "username")
                    {
                        var entry = add_prompt (_("Username:"));
                        entry.text = default_value;
                        widget = entry;
                    }
                    else if (field.type == "password")
                    {
                        var entry = add_prompt (_("Password:"), true);
                        entry.text = default_value;
                        widget = entry;
                    }
                    else if (field.type == "domain")
                    {
                        string[] domainsArray = {};
                        if (field.properties != null && field.properties.contains ("domains") && field.properties.get ("domains").is_of_type (VariantType.ARRAY))
                            domainsArray = field.properties.get ("domains").dup_strv ();
                        var domains = new GenericArray<string> ();
                        for (var i = 0; i < domainsArray.length; i++)
                            domains.add (domainsArray[i]);

                        var read_only = field.properties != null &&
                                        field.properties.contains ("read-only") &&
                                        field.properties.get ("read-only").is_of_type (VariantType.BOOLEAN) &&
                                        field.properties.get ("read-only").get_boolean ();
                        if (domains.length == 0 || (domains.length == 1 && (domains[0] == default_value || default_value.length == 0)))
                        {
                            var prompt = add_prompt (_("Domain:"));
                            prompt.text = domains.length == 1 ? domains[0] : default_value;
                            prompt.sensitive = !read_only;
                            widget = prompt;
                        }
                        else
                        {
                            if (default_value.length > 0)
                            {
                                /* Make sure the domain list contains the default value */
                                var found = false;
                                for (var i = 0; !found && i < domains.length; i++)
                                    found = default_value == domains[i];

                                if (!found)
                                    domains.add (default_value);
                            }

                            /* Sort domains alphabetically */
                            domains.sort (strcmp);
                            var combo = add_combo (domains, read_only);

                            if (default_value.length > 0)
                            {
                                if (read_only)
                                {
                                    for (var i = 0; i < domains.length; i++)
                                    {
                                        if (default_value == domains[i])
                                        {
                                            combo.active = i;
                                            break;
                                        }
                                    }
                                }
                                else
                                {
                                    var entry = combo.get_child () as Gtk.Entry;
                                    entry.text = default_value;
                                }
                            }

                            widget = combo;
                        }
                    }
                    else if (field.type == "email")
                    {
                        string[] email_domains;
                        try
                        {
                            if (UnityGreeter.singleton.test_mode)
                                email_domains = { "canonical.com", "ubuntu.org", "candy.com", "urban.net" };
                            else
                                yield remote_login_service.get_cached_domains_for_server (url, out email_domains);
                        }
                        catch (IOError e)
                        {
                            email_domains.resize (0);
                            debug ("Calling get_cached_domains_for_server in com.canonical.RemoteLogin dbus service failed. Error: %s", e.message);
                        }

                        var entry = add_prompt (_("Email address:"));
                        entry.text = default_value;
                        widget = entry;
                        if (email_domains.length > 0)
                            remote_server_email_field_autocompleter = new EmailAutocompleter (entry, email_domains);
                    }
                    else
                    {
                        debug ("Found field of type %s, don't know what to do with it", field.type);
                        continue;
                    }
                    current_remote_fields.insert (field.type, widget);
                }
                break;
            }
        }
    }

    public override void focus_prompt ()
    {
        if (selected_entry.id.has_prefix ("*remote_login"))
        {
            var url = url_from_remote_loding_server_list_name(selected_entry.id);
            foreach (var remote_server in remote_login_server_list)
            {
                if (remote_server.url == url)
                {
                    if (!is_supported_remote_session (remote_server.type))
                    {
                        selected_entry.sensitive = false;
                        return;
                    }
                }
            }
        }

        base.focus_prompt ();
    }

    public override void show_authenticated (bool successful = true)
    {
        if (successful)
        {
            /* 'Log In' here is the button for logging in. */
            selected_entry.add_button (_("Log In"),
                                       _("Login as %s").printf (selected_entry.label));
        }
        else
        {
            selected_entry.add_button (_("Retry"),
                                       _("Retry as %s").printf (selected_entry.label));
        }

        if (mode != Mode.SCROLLING)
            selected_entry.show_prompts ();

        focus_prompt ();
        redraw_greeter_box ();
    }

    public void add_user (string name, string label, string? background = null, bool is_active = false, bool has_messages = false, string? session = null)
    {
        var e = find_entry (name) as UserPromptBox;
        if (e == null)
        {
            e = new UserPromptBox (name);
            e.respond.connect (prompt_box_respond_cb);
            e.login.connect (prompt_box_login_cb);
            e.show_options.connect (prompt_box_show_options_cb);
            e.label = label; /* Do this before adding for sorting purposes */
            add_entry (e);
        }
        e.background = background;
        e.is_active = is_active;
        e.session = session;
        e.label = label;
        e.set_show_message_icon (has_messages);
        e.set_is_active (is_active);

        /* Remove manual option when have users */
        if (have_entries () && !always_show_manual)
            remove_entry ("*other");
    }

    protected override void add_manual_entry ()
    {
        var text = manual_name;
        if (text == null)
            text = _("Login");
        add_user ("*other", text);
    }

    protected void prompt_box_respond_cb (string[] responses)
    {
        selected_entry.sensitive = false;
        will_clear = true;
        unacknowledged_messages = false;

        foreach (var response in responses)
        {
            if (UnityGreeter.singleton.test_mode)
                test_respond (response);
            else
                UnityGreeter.singleton.respond (response);
        }
    }

    private void prompt_box_login_cb ()
    {
        debug ("Start session for %s", selected_entry.id);

        unacknowledged_messages = false;
        var is_authenticated = false;
        if (UnityGreeter.singleton.test_mode)
            is_authenticated = test_is_authenticated;
        else
            is_authenticated = UnityGreeter.singleton.is_authenticated();

        /* Finish authentication (again) or restart it */
        if (is_authenticated)
            authentication_complete_cb ();
        else
        {
            selected_entry.clear ();
            start_authentication ();
        }
    }

    private void prompt_box_show_options_cb ()
    {
        var session_chooser = new SessionList (background, menubar, session, default_session);
        session_chooser.session_clicked.connect (session_clicked_cb);
        UnityGreeter.singleton.push_list (session_chooser);
    }

    private void session_clicked_cb (string session)
    {
        this.session = session;
        UnityGreeter.singleton.pop_list ();
    }

    private bool should_show_session_badge ()
    {
        if (UnityGreeter.singleton.test_mode)
            return get_selected_id () != "no-badge";
        else
            return LightDM.get_sessions ().length () > 1;
    }

    private Gdk.Pixbuf? get_badge ()
    {
        if (selected_entry is UserPromptBox)
        {
            if (!should_show_session_badge ())
                return null;
            else if (session == null)
                return SessionList.get_badge (default_session);
            else
                return SessionList.get_badge (session);
        }
        else
        {
            if (selected_entry.id.has_prefix ("*remote_directory"))
                return SessionList.get_badge ("remote-login");
            else
                return null;
        }
    }

    private bool is_supported_remote_session (string session_internal_name)
    {
        if (UnityGreeter.singleton.test_mode)
            return session_internal_name == "rdp";

        var found = false;
        foreach (var session in LightDM.get_remote_sessions ())
        {
            if (session.key == session_internal_name)
            {
                found = true;
                break;
            }
        }
        return found;
    }

    protected override string get_lightdm_session ()
    {
        if (selected_entry.id.has_prefix ("*remote_login"))
        {
            var url = url_from_remote_loding_server_list_name (selected_entry.id);
            unowned List<RemoteServer?> it = remote_login_server_list;

            var answer = "";
            while (answer == "" && it != null)
            {
                RemoteServer remote_server = it.data;
                if (remote_server.url == url)
                    answer = remote_server.type;
                it = it.next;
            }

            if (is_supported_remote_session (answer))
                return answer;
            else
                return "";
        }
        else
            return session;
    }

    private void fill_list ()
    {
        if (UnityGreeter.singleton.test_mode)
            test_fill_list ();
        else
        {
            default_session = UnityGreeter.singleton.default_session_hint ();
            always_show_manual = UnityGreeter.singleton.show_manual_login_hint ();
            if (!UnityGreeter.singleton.hide_users_hint ())
            {
                var users = LightDM.UserList.get_instance ();
                users.user_added.connect (user_added_cb);
                users.user_changed.connect (user_added_cb);
                users.user_removed.connect (user_removed_cb);
                foreach (var user in users.users)
                    user_added_cb (user);
            }

            if (UnityGreeter.singleton.has_guest_account_hint ())
            {
                debug ("Adding guest account entry");
                offer_guest = true;
            }

            /* If we have no entries at all, we should show manual */
            if (!have_entries ())
                add_manual_entry ();

            var last_user = UnityGreeter.singleton.get_state ("last-user");
            if (UnityGreeter.singleton.select_user_hint () != null)
                set_active_entry (UnityGreeter.singleton.select_user_hint ());
            else if (last_user != null)
                set_active_entry (last_user);
        }
    }

    private void user_added_cb (LightDM.User user)
    {
        debug ("Adding/updating user %s (%s)", user.name, user.real_name);

        if (!show_hidden_users)
        {
            var hidden_users = UGSettings.get_strv (UGSettings.KEY_HIDDEN_USERS);
            foreach (var username in hidden_users)
                if (username == user.name)
                    return;
        }

        if (!filter_group (user.name))
            return;

        var label = user.real_name;
        if (user.real_name == "")
            label = user.name;

        add_user (user.name, label, user.background, user.logged_in, user.has_messages, user.session);
    }

    private bool filter_group (string user_name)
    {
        var group_filter = UGSettings.get_strv (UGSettings.KEY_GROUP_FILTER);

        /* Empty list means do not filter by group */
        if (group_filter.length == 0)
            return true;

        foreach (var group_name in group_filter)
            if (in_group (group_name, user_name))
                return true;

        return false;
    }

    private bool in_group (string group_name, string user_name)
    {
        unowned Posix.Group? group = Posix.getgrnam (group_name);
        if (group == null)
            return false;

        foreach (var name in group.gr_mem)
            if (name == user_name)
                return true;

        return false;
    }

    private void user_removed_cb (LightDM.User user)
    {
        debug ("Removing user %s", user.name);
        remove_entry (user.name);
    }

    protected override void show_prompt_cb (string text, LightDM.PromptType type)
    {
        if (selected_entry.id.has_prefix ("*remote_login"))
        {
            if (text == "remote login:")
            {
                Gtk.Entry field = current_remote_fields.get ("username") as Gtk.Entry;
                var answer = field != null ? field.text : "";
                UnityGreeter.singleton.respond (answer);
            }
            else if (text == "password:")
            {
                Gtk.Entry field = current_remote_fields.get ("password") as Gtk.Entry;
                var answer = field != null ? field.text : "";
                UnityGreeter.singleton.respond (answer);
            }
            else if (text == "remote host:")
            {
                var answer = url_from_remote_loding_server_list_name (selected_entry.id);
                UnityGreeter.singleton.respond (answer);
            }
            else if (text == "domain:")
            {
                Gtk.Entry field = current_remote_fields.get ("domain") as Gtk.Entry;
                var answer = field != null ? field.text : "";
                UnityGreeter.singleton.respond (answer);
            }
        }
        else
            base.show_prompt_cb (text, type);
    }

    /* A lot of test code below here */

    private struct TestEntry
    {
        string username;
        string real_name;
        string? background;
        bool is_active;
        bool has_messages;
        string? session;
    }

    private const TestEntry[] test_entries =
    {
        { "has-password",       "Has Password",      "*" },
        { "different-prompt",   "Different Prompt",  "*" },
        { "no-password",        "No Password",       "*" },
        { "change-password",    "Change Password",   "*" },
        { "auth-error",         "Auth Error",        "*" },
        { "two-factor",         "Two Factor",        "*" },
        { "two-prompts",        "Two Prompts",       "*" },
        { "info-prompt",        "Info Prompt",       "*" },
        { "long-info-prompt",   "Long Info Prompt",  "*" },
        { "wide-info-prompt",   "Wide Info Prompt",  "*" },
        { "multi-info-prompt",  "Multi Info Prompt", "*" },
        { "very-very-long-name",    "Long name (far far too long to fit)", "*" },
        { "long-name-and-messages", "Long name and messages (too long to fit)", "*", false, true },
        { "active",             "Active Account",    "*", true },
        { "has-messages",       "Has Messages",      "*", false, true },
        { "gnome",              "GNOME",             "*", false, false, "gnome" },
        { "locked",             "Locked Account",    "*" },
        { "color-background",   "Color Background",  "#dd4814" },
        { "white-background",   "White Background",  "#ffffff" },
        { "black-background",   "Black Background",  "#000000" },
        { "no-background",      "No Background",     null },
        { "unicode",            "가나다라마",         "*" },
        { "no-response",        "No Response",       "*" },
        { "no-badge",           "No Badge",          "*" },
        { "messages-after-login", "Messages After Login", "*" },
        { "" }
    };
    private List<string> test_backgrounds;
    private int n_test_entries = 0;
    private bool test_prompted_sso = false;
    private string test_two_prompts_first = null;
    private bool test_request_new_password = false;
    private string? test_new_password = null;

    private void test_fill_list ()
    {
        test_backgrounds = new List<string> ();
        try
        {
            var dir = Dir.open ("/usr/share/backgrounds/");
            while (true)
            {
                var bg = dir.read_name ();
                if (bg == null)
                    break;
                test_backgrounds.append ("/usr/share/backgrounds/" + bg);
            }
        }
        catch (FileError e)
        {
        }

        if (!UnityGreeter.singleton.hide_users_hint())
            while (add_test_entry ());

        /* add a manual entry if the list of entries is empty initially */
        if (n_test_entries <= 0)
        {
            add_manual_entry();
            set_active_entry ("*other");
            n_test_entries++;
        }

        offer_guest = UnityGreeter.singleton.has_guest_account_hint();
        always_show_manual = UnityGreeter.singleton.show_manual_login_hint();

        key_press_event.connect (test_key_press_cb);

        if (UnityGreeter.singleton.show_remote_login_hint())
            Timeout.add (1000, () =>
            {
                RemoteServer[] test_server_list = {};
                RemoteServer remote_server = RemoteServer ();
                remote_server.type = "uccs";
                remote_server.name = "Remote Login";
                remote_server.url = "http://crazyurl.com";
                remote_server.last_used_server = false;
                remote_server.fields = {};
                RemoteServerField field1 = RemoteServerField ();
                field1.type = "email";
                RemoteServerField field2 = RemoteServerField ();
                field2.type = "password";
                remote_server.fields = {field1, field2};
                
                test_server_list += remote_server;
                set_remote_directory_servers (test_server_list);
                
                return false;
            });

        var last_user = UnityGreeter.singleton.get_state ("last-user");
        if (last_user != null)
            set_active_entry (last_user);

    }

    private void test_call_set_remote_directory_servers ()
    {
        RemoteServer[] test_server_list = {};
        RemoteServer remote_server = RemoteServer ();
        remote_server.type = "uccs";
        remote_server.name = "Corporate Remote Login";
        remote_server.url = "http://internalcompayserver.com";
        remote_server.last_used_server = false;
        remote_server.fields = {};
        RemoteServerField field1 = RemoteServerField ();
        field1.type = "email";
        RemoteServerField field2 = RemoteServerField ();
        field2.type = "password";
        remote_server.fields = {field1, field2};

        test_server_list += remote_server;
        set_remote_directory_servers (test_server_list);
    }

    private void test_call_remote_login_servers_updated ()
    {
        RemoteServer[] server_list = {};
        RemoteServer remote_server1 = RemoteServer ();
        remote_server1.type = "rdp";
        remote_server1.name = "Cool RDP server";
        remote_server1.url = "http://coolrdpserver.com";
        remote_server1.last_used_server = false;
        remote_server1.fields = {};
        RemoteServerField field1 = RemoteServerField ();
        field1.type = "username";
        RemoteServerField field2 = RemoteServerField ();
        field2.type = "password";
        RemoteServerField field3 = RemoteServerField ();
        field3.type = "domain";
        remote_server1.fields = {field1, field2, field3};

        RemoteServer remote_server2 = RemoteServer ();
        remote_server2.type = "rdp";
        remote_server2.name = "MegaCool RDP server";
        remote_server2.url = "http://megacoolrdpserver.com";
        remote_server2.last_used_server = false;
        remote_server2.fields = {};
        RemoteServerField field21 = RemoteServerField ();
        field21.type = "username";
        RemoteServerField field22 = RemoteServerField ();
        field22.type = "password";
        remote_server2.fields = {field21, field22};

        server_list.resize (2);
        server_list[0] = remote_server1;
        server_list[1] = remote_server2;

        remote_login_servers_updated (currently_browsing_server_url, currently_browsing_server_email, "", server_list);
    }

    private void test_fill_remote_login_servers (out RemoteServer[] server_list)
    {
        string[] domains = { "SCANNERS", "PRINTERS", "ROUTERS" };

        server_list = {};
        RemoteServer remote_server1 = RemoteServer ();
        remote_server1.type = "rdp";
        remote_server1.name = "Cool RDP server";
        remote_server1.url = "http://coolrdpserver.com";
        remote_server1.last_used_server = false;
        remote_server1.fields = {};
        RemoteServerField field1 = RemoteServerField ();
        field1.type = "username";
        RemoteServerField field2 = RemoteServerField ();
        field2.type = "password";
        RemoteServerField field3 = RemoteServerField ();
        field3.type = "domain";
        remote_server1.fields = {field1, field2, field3};

        RemoteServer remote_server2 = RemoteServer ();
        remote_server2.type = "rdp";
        remote_server2.name = "RDP server with default username, and editable domain";
        remote_server2.url = "http://rdpdefaultusername.com";
        remote_server2.last_used_server = false;
        remote_server2.fields = {};
        RemoteServerField field21 = RemoteServerField ();
        field21.type = "username";
        field21.default_value = new Variant.string ("alowl");
        RemoteServerField field22 = RemoteServerField ();
        field22.type = "password";
        RemoteServerField field23 = RemoteServerField ();
        field23.type = "domain";
        field23.default_value = new Variant.string ("PRINTERS");
        field23.properties = new HashTable<string, Variant> (str_hash, str_equal);
        field23.properties["domains"] = domains;
        remote_server2.fields = {field21, field22, field23};

        RemoteServer remote_server3 = RemoteServer ();
        remote_server3.type = "rdp";
        remote_server3.name = "RDP server with default username, and non editable domain";
        remote_server3.url = "http://rdpdefaultusername2.com";
        remote_server3.last_used_server = true;
        remote_server3.fields = {};
        RemoteServerField field31 = RemoteServerField ();
        field31.type = "username";
        field31.default_value = new Variant.string ("lwola");
        RemoteServerField field32 = RemoteServerField ();
        field32.type = "password";
        RemoteServerField field33 = RemoteServerField ();
        field33.type = "domain";
        field33.default_value = new Variant.string ("PRINTERS");
        field33.properties = new HashTable<string, Variant> (str_hash, str_equal);
        field33.properties["domains"] = domains;
        field33.properties["read-only"] = true;

        remote_server3.fields = {field31, field32, field33};

        RemoteServer remote_server4 = RemoteServer ();
        remote_server4.type = "notsupported";
        remote_server4.name = "Not supported server";
        remote_server4.url = "http://notsupportedserver.com";
        remote_server4.fields = {};
        RemoteServerField field41 = RemoteServerField ();
        field41.type = "username";
        RemoteServerField field42 = RemoteServerField ();
        field42.type = "password";
        RemoteServerField field43 = RemoteServerField ();
        field43.type = "domain";

        remote_server4.fields = {field41, field42, field43};

        server_list.resize (4);
        server_list[0] = remote_server1;
        server_list[1] = remote_server2;
        server_list[2] = remote_server3;
        server_list[3] = remote_server4;
    }

    private void test_fill_remote_login_servers_duplicate_entries (out RemoteServer[] server_list)
    {
        /* Create two remote servers with same url but different username and domain. */
        server_list = {};

        RemoteServer remote_server2 = RemoteServer ();
        remote_server2.type = "rdp";
        remote_server2.name = "RDP server with default username, and editable domain";
        remote_server2.url = "http://rdpdefaultusername.com";
        remote_server2.last_used_server = false;
        remote_server2.fields = {};
        RemoteServerField field21 = RemoteServerField ();
        field21.type = "username";
        field21.default_value = new Variant.string ("alowl1");
        RemoteServerField field22 = RemoteServerField ();
        field22.type = "password";
        field22.default_value = new Variant.string ("duplicate1");
        RemoteServerField field23 = RemoteServerField ();
        field23.type = "domain";
        field23.default_value = new Variant.string ("SCANNERS");
        remote_server2.fields = {field21, field22, field23};

        RemoteServer remote_server5 = RemoteServer ();
        remote_server5.type = "rdp";
        remote_server5.name = "RDP server with default username, and editable domain";
        remote_server5.url = "http://rdpdefaultusername.com";
        remote_server5.last_used_server = false;
        remote_server5.fields = {};
        RemoteServerField field51 = RemoteServerField ();
        field51.type = "username";
        field51.default_value = new Variant.string ("alowl2");
        RemoteServerField field52 = RemoteServerField ();
        field52.type = "password";
        field52.default_value = new Variant.string ("duplicate2");
        RemoteServerField field53 = RemoteServerField ();
        field53.type = "domain";
        field53.default_value = new Variant.string ("PRINTERS");
        remote_server5.fields = {field51, field52, field53};

        server_list.resize (2);
        server_list[0] = remote_server2;
        server_list[1] = remote_server5;
    }
    
    private bool test_key_press_cb (Gdk.EventKey event)
    {
        if ((event.state & Gdk.ModifierType.CONTROL_MASK) == 0)
            return false;

        switch (event.keyval)
        {
        case Gdk.Key.plus:
            add_test_entry ();
            break;
        case Gdk.Key.minus:
            remove_test_entry ();
            break;
        case Gdk.Key.@0:
            while (remove_test_entry ());
            offer_guest = false;
            break;
        case Gdk.Key.equal:
            while (add_test_entry ());
            offer_guest = true;
            break;
        case Gdk.Key.g:
            offer_guest = false;
            break;
        case Gdk.Key.G:
            offer_guest = true;
            break;
        case Gdk.Key.m:
            always_show_manual = false;
            break;
        case Gdk.Key.M:
            always_show_manual = true;
            break;
        }

        return false;
    }

    private bool add_test_entry ()
    {
        var e = test_entries[n_test_entries];
        if (e.username == "")
            return false;

        var background = e.background;
        if (background == "*")
        {
            var background_index = 0;
            for (var i = 0; i < n_test_entries; i++)
            {
                if (test_entries[i].background == "*")
                    background_index++;
            }
            if (test_backgrounds.length () > 0)
                background = test_backgrounds.nth_data (background_index % test_backgrounds.length ());
        }
        add_user (e.username, e.real_name, background, e.is_active, e.has_messages, e.session);
        n_test_entries++;

        return true;
    }

    private bool remove_test_entry ()
    {
        if (n_test_entries == 0)
            return false;

        remove_entry (test_entries[n_test_entries - 1].username);
        n_test_entries--;

        return true;
    }

    private void test_respond (string text)
    {
        debug ("response %s", text);
        switch (get_selected_id ())
        {
        case "*other":
            if (test_username == null)
            {
                debug ("username=%s", text);
                test_username = text;
                show_prompt_cb ("Password:", LightDM.PromptType.SECRET);
            }
            else
            {
                test_is_authenticated = text == "password";
                authentication_complete_cb ();
            }
            break;
        case "two-factor":
            if (!test_prompted_sso)
            {
                if (text == "password")
                {
                    debug ("prompt otp");
                    test_prompted_sso = true;
                    show_prompt_cb ("OTP:", LightDM.PromptType.QUESTION);
                }
                else
                {
                    test_is_authenticated = false;
                    authentication_complete_cb ();
                }
            }
            else
            {
                test_is_authenticated = text == "otp";
                authentication_complete_cb ();
            }
            break;
        case "two-prompts":
            if (test_two_prompts_first == null)
                test_two_prompts_first = text;
            else
            {
                test_is_authenticated = test_two_prompts_first == "blue" && text == "password";
                authentication_complete_cb ();
            }
            break;
        case "change-password":
            if (test_new_password != null)
            {
                test_is_authenticated = text == test_new_password;
                authentication_complete_cb ();
            }
            else if (test_request_new_password)
            {
                test_new_password = text;
                show_prompt_cb ("Retype new UNIX password: ", LightDM.PromptType.SECRET);
            }
            else
            {
                if (text != "password")
                {
                    test_is_authenticated = false;
                    authentication_complete_cb ();
                }
                else
                {
                    test_request_new_password = true;
                    show_message_cb ("You are required to change your password immediately (root enforced)", LightDM.MessageType.ERROR);
                    show_prompt_cb ("Enter new UNIX password: ", LightDM.PromptType.SECRET);
                }
            }
            break;
        case "no-response":
            break;
        case "locked":
            test_is_authenticated = false;
            show_message_cb ("Account is locked", LightDM.MessageType.ERROR);
            authentication_complete_cb ();
            break;
        case "messages-after-login":
            test_is_authenticated = text == "password";
            if (test_is_authenticated)
                show_message_cb ("Congratulations on logging in!", LightDM.MessageType.INFO);
            authentication_complete_cb ();
            break;
        default:
            test_is_authenticated = text == "password";
            authentication_complete_cb ();
            break;
        }
    }

    protected override void test_start_authentication ()
    {
        test_username = null;
        test_is_authenticated = false;
        test_prompted_sso = false;
        test_two_prompts_first = null;
        test_request_new_password = false;
        test_new_password = null;

        switch (get_selected_id ())
        {
        case "*other":
            if (authenticate_user != null)
            {
                test_username = authenticate_user;
                authenticate_user = null;
                show_prompt_cb ("Password:", LightDM.PromptType.SECRET);
            }
            else
                show_prompt_cb ("Username:", LightDM.PromptType.QUESTION);
            break;
        case "*guest":
            test_is_authenticated = true;
            authentication_complete_cb ();
            break;
        case "different-prompt":
            show_prompt_cb ("Secret word", LightDM.PromptType.SECRET);
            break;
        case "no-password":
            test_is_authenticated = true;
            authentication_complete_cb ();
            break;
        case "auth-error":
            show_message_cb ("Authentication Error", LightDM.MessageType.ERROR);
            test_is_authenticated = false;
            authentication_complete_cb ();
            break;
        case "info-prompt":
            show_message_cb ("Welcome to Unity Greeter", LightDM.MessageType.INFO);
            show_prompt_cb ("Password:", LightDM.PromptType.SECRET);
            break;
        case "long-info-prompt":
            show_message_cb ("Welcome to Unity Greeter\n\nWe like to annoy you with long messages.\nLike this one\n\nThis is the last line of a multiple line message.", LightDM.MessageType.INFO);
            show_prompt_cb ("Password:", LightDM.PromptType.SECRET);
            break;
        case "wide-info-prompt":
            show_message_cb ("Welcome to Unity Greeter, the greeteriest greeter that ever did appear in these fine lands", LightDM.MessageType.INFO);
            show_prompt_cb ("Password:", LightDM.PromptType.SECRET);
            break;
        case "multi-info-prompt":
            show_message_cb ("Welcome to Unity Greeter", LightDM.MessageType.INFO);
            show_message_cb ("This is an error", LightDM.MessageType.ERROR);
            show_message_cb ("You should have seen three messages", LightDM.MessageType.INFO);
            show_prompt_cb ("Password:", LightDM.PromptType.SECRET);
            break;
        case "two-prompts":
            show_prompt_cb ("Favorite Color (blue):", LightDM.PromptType.QUESTION);
            show_prompt_cb ("Password:", LightDM.PromptType.SECRET);
            break;
        default:
            show_prompt_cb ("Password:", LightDM.PromptType.SECRET);
            break;
        }
    }
}
