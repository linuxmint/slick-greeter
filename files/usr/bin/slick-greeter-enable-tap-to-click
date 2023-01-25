#!/usr/bin/python3

import sys
import os
import syslog
import subprocess
import re

if __name__ == '__main__':

    try:
        output = subprocess.check_output(["xinput", "list"]).decode("UTF-8")
        for line in output.splitlines():
            line = line.strip().lower()
            if "pointer" in line:
                m = re.search(r'id=(\d+)', line)
                if m:
                    if len(m.groups()) > 0:
                        device_id = m.groups()[0]
                        syslog.syslog(f"Found xinput pointer: id={device_id}")
                        props = subprocess.check_output(["xinput", "list-props", device_id]).decode("UTF-8")
                        for prop in props.splitlines():
                            prop = prop.strip()
                            if "Tapping Enabled Default" in prop:
                                continue
                            if "Tapping Enabled" in prop:
                                syslog.syslog("  --> This device has a tap-to-click property")
                                m = re.search(r'Tapping Enabled \((\d+)\):', prop)
                                if m:
                                    if len(m.groups()) > 0:
                                        prop_id = m.groups()[0]
                                        syslog.syslog(f"  --> Tapping Enabled property ID: {prop_id}")
                                        syslog.syslog(f"  --> Calling 'xinput set-prop {device_id} {prop_id} 1'")
                                        subprocess.check_output(["xinput", "set-prop", device_id, prop_id, "1"])

    except Exception as e:
        # best effort, syslog it and bail out
        syslog.syslog("ERROR: %s" % e)

    sys.exit(0)
