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

using GLib;

public class UserPromptBox : PromptBox
{
    /* Background for this user */
    public string background;

    /* Default session for this user */
    public string session;

    /* True if should be marked as active */
    public bool is_active;

    private string _username;
    public string username 
    {
        get { return _username; }
        set 
        {
            _username = value;
            update_avatar();
        }
    }

    public UserPromptBox (string name)
    {
        Object (id: name);
        username = name;
    }

    private void update_avatar()
    {
        string? avatar_path = null;

        // Get avatar through LightDM
        var users = LightDM.UserList.get_instance();
        foreach (var user in users.users) {
            if (user.name == username) {
                avatar_path = user.image;
                break;
            }
        }

        // If no avatar is found via LightDM, try default paths
        if (avatar_path == null || !FileUtils.test(avatar_path, FileTest.EXISTS)) {
            string[] possible_paths = {
                "/var/lib/AccountsService/icons/" + username            };

            foreach (string path in possible_paths) {
                if (FileUtils.test(path, FileTest.EXISTS)) {
                    avatar_path = path;
                    break;
                }
            }
        }

        set_avatar_path(avatar_path);
    }
}
