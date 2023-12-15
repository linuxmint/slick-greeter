/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 4 -*-
 *
 * Copyright (C) 2012 Canonical Ltd
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
 * Authors: Michael Terry <michael.terry@canonical.com>
 */

public class SessionPrompt : PromptBox
{
    public string session { get; construct; }
    public string default_session { get; construct; }

    public SessionPrompt (string id, string? session, string? default_session)
    {
        Object (id: id, session: session, default_session: default_session);
    }

    private ToggleBox box;

    construct
    {
        label = _("Select desktop environment");
        name_label.vexpand = false;

        box = new ToggleBox (default_session, session);

        if (SlickGreeter.singleton.test_mode)
        {
            box.add_item ("cinnamon", "Cinnamon", SessionList.get_badge ("cinnamon"));
            box.add_item ("cinnamon-wayland", "Cinnamon on Wayland (Experimental)", SessionList.get_badge ("cinnamon"));
            box.add_item ("mate", "MATE", SessionList.get_badge ("mate"));
            box.add_item ("xfce", "Xfce", SessionList.get_badge ("xfce"));
            box.add_item ("kde", "KDE", SessionList.get_badge ("kde"));
            box.add_item ("gnome", "GNOME", SessionList.get_badge ("gnome"));
        }
        else
        {
            foreach (var session in LightDM.get_sessions ())
            {
                debug ("Adding session %s (%s)", session.key, session.name);
                box.add_item (session.key, session.name, SessionList.get_badge (session.key));
            }
        }

        box.notify["selected-key"].connect (selected_cb);
        box.show ();

        attach_item (box);
    }

    private void selected_cb ()
    {
        respond ({ box.selected_key });
    }
}

public class SessionList : GreeterList
{
    public signal void session_clicked (string session);
    public string session { get; construct; }
    public string default_session { get; construct; }

    private SessionPrompt prompt;

    public SessionList (Background bg, MenuBar mb, string? session, string? default_session)
    {
        Object (background: bg, menubar: mb, session: session, default_session: default_session);
    }

    construct
    {
        prompt = add_session_prompt ("session");
    }

    private SessionPrompt add_session_prompt (string id)
    {
        var e = new SessionPrompt (id, session, default_session);
        e.respond.connect ((responses) => { session_clicked (responses[0]); });
        add_entry (e);
        return e;
    }

    protected override void add_manual_entry () {}
    public override void show_authenticated (bool successful = true) {}

    private static HashTable<string, Gdk.Pixbuf> badges; /* cache of badges */
    public static Gdk.Pixbuf? get_badge (string session)
    {
        var name = "unknown.png";

        var extensions = new List<string>();
        extensions.append("svg");
        extensions.append("png");

        foreach (string extension in extensions)
        {
            var filename = "%s.%s".printf (session, extension);
            var path = Path.build_filename ("/usr/share/slick-greeter/badges/", filename, null);
            if (FileUtils.test (path, FileTest.EXISTS))
            {
                name = filename;
                break;
            }
        }

        if (badges == null)
            badges = new HashTable<string, Gdk.Pixbuf> (str_hash, str_equal);

        var pixbuf = badges.lookup (name);
        if (pixbuf == null)
        {
            try
            {
                pixbuf = new Gdk.Pixbuf.from_file (Path.build_filename ("/usr/share/slick-greeter/badges/", name, null));
                badges.insert (name, pixbuf);
            }
            catch (Error e)
            {
                debug ("Error loading badge %s: %s", name, e.message);
            }
        }

        return pixbuf;
    }
}
