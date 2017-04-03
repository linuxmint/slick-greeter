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
 */

public class EmailAutocompleter
{
    private Gtk.Entry entry;
    private string[] domains;
    private string prevText = "";

    private void entry_changed ()
    {
        if (entry.text.length < prevText.length)
        {
            /* Do nothing on erases of text */
            prevText = entry.text;
            return;
        }

        prevText = entry.text;

        int first_at = entry.text.index_of ("@");
        if (first_at != -1)
        {
            int second_at = entry.text.index_of ("@", first_at + 1);
            if (second_at == -1)
            {
                /* We have exactly one @ */
                string text_after_at = entry.text.slice (first_at + 1, entry.text.length);

                /* Find first prefix match */
                int match = -1;
                for (int i = 0; match == -1 && i < domains.length; ++i)
                {
                    if (domains[i].has_prefix (text_after_at))
                        match = i;
                }

                if (match != -1)
                {
                    /* Calculate the suffix part we need to add */
                    var best_match = domains[match];
                    var text_to_add = best_match.slice (text_after_at.length, best_match.length);
                    if (text_to_add.length > 0)
                    {
                        entry.text = entry.text + text_to_add;
                        /* TODO This is quite ugly/hacky :-/ */
                        Timeout.add (0, () =>
                        {
                            entry.select_region (entry.text.length - text_to_add.length, entry.text.length);
                            return false;
                        });
                    }
                }
            }
        }
    }

    public EmailAutocompleter (Gtk.Entry e, string[] email_domains)
    {
        entry = e;
        domains = email_domains;
        entry.changed.connect (entry_changed);
    }
}
