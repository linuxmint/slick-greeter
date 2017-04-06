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

public class UGSettings
{
    public const string KEY_BACKGROUND = "background";
    public const string KEY_BACKGROUND_COLOR = "background-color";
    public const string KEY_DRAW_USER_BACKGROUNDS = "draw-user-backgrounds";
    public const string KEY_DRAW_GRID = "draw-grid";
    public const string KEY_SHOW_HOSTNAME = "show-hostname";
    public const string KEY_LOGO = "logo";
    public const string KEY_BACKGROUND_LOGO = "background-logo";
    public const string KEY_THEME_NAME = "theme-name";
    public const string KEY_ICON_THEME_NAME = "icon-theme-name";
    public const string KEY_FONT_NAME = "font-name";
    public const string KEY_XFT_ANTIALIAS = "xft-antialias";
    public const string KEY_XFT_DPI = "xft-dpi";
    public const string KEY_XFT_HINTSTYLE = "xft-hintstyle";
    public const string KEY_XFT_RGBA = "xft-rgba";
    public const string KEY_ONSCREEN_KEYBOARD = "onscreen-keyboard";
    public const string KEY_HIGH_CONTRAST = "high-contrast";
    public const string KEY_SCREEN_READER = "screen-reader";
    public const string KEY_PLAY_READY_SOUND = "play-ready-sound";
    public const string KEY_HIDDEN_USERS = "hidden-users";
    public const string KEY_GROUP_FILTER = "group-filter";
    public const string KEY_IDLE_TIMEOUT = "idle-timeout";

    public static bool get_boolean (string key)
    {
        var gsettings = new Settings (SCHEMA);
        return gsettings.get_boolean (key);
    }

    /* LP: 1006497 - utility function to make sure we have the key before trying to read it (which will segfault if the key isn't there) */
    public static bool safe_get_boolean (string key, bool default)
    {
        var gsettings = new Settings (SCHEMA);
        string[] keys = gsettings.list_keys ();
        foreach (var k in keys)
            if (k == key)
                return gsettings.get_boolean (key);

        /* key not in child list */
        return default;
    }

    public static int get_integer (string key)
    {
        var gsettings = new Settings (SCHEMA);
        return gsettings.get_int (key);
    }

    public static double get_double (string key)
    {
        var gsettings = new Settings (SCHEMA);
        return gsettings.get_double (key);
    }

    public static string get_string (string key)
    {
        var gsettings = new Settings (SCHEMA);
        return gsettings.get_string (key);
    }

    public static bool set_boolean (string key, bool value)
    {
        var gsettings = new Settings (SCHEMA);
        return gsettings.set_boolean (key, value);
    }

    public static string[] get_strv (string key)
    {
        var gsettings = new Settings (SCHEMA);
        return gsettings.get_strv (key);
    }

    public static bool set_strv (string key, string[] value)
    {
        var gsettings = new Settings (SCHEMA);
        return gsettings.set_strv (key, value);
    }

    public static void apply_conf_settings ()
    {
        try {
            var path = "/etc/lightdm/slick-greeter.conf";
            if (FileUtils.test (path, FileTest.EXISTS))
            {
                var gsettings = new Settings (SCHEMA);
                var keyfile = new KeyFile ();
                keyfile.load_from_file (path, KeyFileFlags.NONE);

                if (keyfile.has_group (GROUP_NAME)) {

                    var string_keys = new List<string> ();
                    string_keys.append (KEY_BACKGROUND);
                    string_keys.append (KEY_BACKGROUND_COLOR);
                    string_keys.append (KEY_LOGO);
                    string_keys.append (KEY_BACKGROUND_LOGO);
                    string_keys.append (KEY_THEME_NAME);
                    string_keys.append (KEY_ICON_THEME_NAME);
                    string_keys.append (KEY_FONT_NAME);
                    string_keys.append (KEY_PLAY_READY_SOUND);
                    string_keys.append (KEY_XFT_HINTSTYLE);
                    string_keys.append (KEY_XFT_RGBA);

                    var bool_keys = new List<string> ();
                    bool_keys.append (KEY_DRAW_USER_BACKGROUNDS);
                    bool_keys.append (KEY_DRAW_GRID);
                    bool_keys.append (KEY_SHOW_HOSTNAME);
                    bool_keys.append (KEY_XFT_ANTIALIAS);

                    var int_keys = new List<string> ();
                    int_keys.append (KEY_IDLE_TIMEOUT);
                    int_keys.append (KEY_XFT_DPI);

                    var strv_keys = new List<string> ();
                    strv_keys.append (KEY_HIDDEN_USERS);
                    strv_keys.append (KEY_GROUP_FILTER);

                    foreach (string key in string_keys)
                    {
                        if (keyfile.has_key (GROUP_NAME, key)) {
                            try {
                                var value = keyfile.get_string (GROUP_NAME, key);
                                debug ("Overriding dconf setting for %s with %s", key, value);
                                gsettings.set_string (key, value);
                            }
                            catch (Error e) {
                                warning ("Failed to apply %s from configuration file: %s", key, e.message);
                            }
                        }
                    }

                    foreach (string key in bool_keys)
                    {
                        if (keyfile.has_key (GROUP_NAME, key)) {
                            try {
                                var value = keyfile.get_boolean (GROUP_NAME, key);
                                debug ("Overriding dconf setting for %s", key);
                                gsettings.set_boolean (key, value);
                            }
                            catch (Error e) {
                                warning ("Failed to apply %s from configuration file: %s", key, e.message);
                            }
                        }
                    }

                    foreach (string key in int_keys)
                    {
                        if (keyfile.has_key (GROUP_NAME, key)) {
                            try {
                                var value = keyfile.get_integer (GROUP_NAME, key);
                                debug ("Overriding dconf setting for %s with %d", key, value);
                                gsettings.set_int (key, value);
                            }
                            catch (Error e) {
                                warning ("Failed to apply %s from configuration file: %s", key, e.message);
                            }
                        }
                    }

                    foreach (string key in strv_keys)
                    {
                        if (keyfile.has_key (GROUP_NAME, key)) {
                            try {
                                var value = keyfile.get_string_list (GROUP_NAME, key);
                                debug ("Overriding dconf setting for %s", key);
                                gsettings.set_strv (key, value);
                            }
                            catch (Error e) {
                                warning ("Failed to apply %s from configuration file: %s", key, e.message);
                            }
                        }
                    }
                }
            }
        } catch (Error e) {
            warning ("Error in apply_conf_settings (): %s", e.message);
        }
    }

    private const string SCHEMA = "x.dm.slick-greeter";
    private const string GROUP_NAME = "Greeter";
}
