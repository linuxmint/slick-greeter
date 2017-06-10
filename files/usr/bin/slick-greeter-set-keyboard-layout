#!/usr/bin/python3

import sys
import os
import syslog
import subprocess

if __name__ == '__main__':

    try:

        # Exit if something is missing
        for required_file in ["/etc/default/keyboard", "/usr/bin/setxkbmap"]:
            if not os.path.exists(required_file):
                syslog.syslog("%s not found." % required_file)
                sys.exit(0)

        # Log current keyboard configuration
        output = subprocess.check_output(["setxkbmap", "-query"]).decode("UTF-8")
        syslog.syslog("Current keyboard configuration: %s" % output)

        # Parse keyboard configuration file
        XKBMODEL = ""
        XKBLAYOUT = ""
        XKBVARIANT = ""
        XKBOPTIONS = ""
        with open("/etc/default/keyboard", "r") as keyboard:
            for line in keyboard:
                line = line.strip()
                if "XKBMODEL=" in line:
                    XKBMODEL = line.split('=')[1].replace('"', '')
                if "XKBLAYOUT=" in line:
                    XKBLAYOUT = line.split('=')[1].replace('"', '')
                if "XKBVARIANT=" in line:
                    XKBVARIANT = line.split('=')[1].replace('"', '')
                if "XKBOPTIONS=" in line:
                    XKBOPTIONS = line.split('=')[1].replace('"', '')

            # Apply keyboard configuration
            command = ["setxkbmap", "-model", XKBMODEL, "-layout", XKBLAYOUT, "-variant", XKBVARIANT, "-option", XKBOPTIONS, "-v"]
            syslog.syslog("Applying keyboard configuration: %s" % command)
            output = subprocess.check_output(command).decode("UTF-8")
            syslog.syslog("Result: %s" % output)

        # Log new keyboard configuration
        output = subprocess.check_output(["setxkbmap", "-query"]).decode("UTF-8")
        syslog.syslog("New keyboard configuration: %s" % output)

    except Exception as e:
        # best effort, syslog it and bail out
        syslog.syslog("ERROR: %s" % e)

    sys.exit(0)
