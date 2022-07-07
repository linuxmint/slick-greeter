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

public class UserPromptBox : PromptBox
{
    /* Background for this user */
    public string background;

    /* Default session for this user */
    public string session;

    /* True if should be marked as active */
    public bool is_active;

    protected Gtk.Widget avatar;

    public UserPromptBox (string name)
    {
        Object (id: name);

        //FIXME: Avatar is overlaping clickable userbox space
        //FIXME: Avatar is not respecting animation
        //TODO: Display user picture instead of first letter
        //TODO: Make avatar easily disabled from settings
        avatar = new Hdy.Avatar(42, name, true);
        avatar.show();
        name_grid.attach(avatar, -1, 0, 1, 1);

    }
}
