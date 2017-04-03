public delegate void IdleMonitorWatchFunc (IdleMonitor monitor, uint id);

public class IdleMonitor
{
    private unowned X.Display display;
    private HashTable<uint, IdleMonitorWatch> watches;
    private HashTable<uint32, uint32> alarms;
    private int sync_event_base;
    private X.ID counter;
    private X.ID user_active_alarm;
    private int serial = 0;

    public IdleMonitor ()
    {
        watches = new HashTable<uint, IdleMonitorWatch> (null, null);
        alarms = new HashTable<uint32, uint32> (null, null);
        init_xsync ();
    }

    ~IdleMonitor ()
    {
        foreach (var watch in watches.get_values ())
            remove_watch (watch.id);
        if (user_active_alarm != X.None)
            X.Sync.DestroyAlarm (display, user_active_alarm);

        /* Note this is a bit weird, since we need to pass null as the window by Vala treats this as a method */
        Gdk.Window w = null;
        w.remove_filter (xevent_filter);
    }

    public uint add_idle_watch (uint64 interval_msec, IdleMonitorWatchFunc callback)
    {
        var watch = make_watch (xsync_alarm_set (X.Sync.TestType.PositiveTransition, interval_msec, true), callback);
        alarms.add ((uint32) watch.xalarm);
        return watch.id;
    }

    public uint add_user_active_watch (IdleMonitorWatchFunc callback)
    {
        set_alarm_enabled (display, user_active_alarm, true);
        var watch = make_watch (user_active_alarm, callback);
        return watch.id;
    }

    public void remove_watch (uint id)
    {
        var watch = watches.lookup (id);
        watches.remove (id);
        if (watch.xalarm != user_active_alarm)
            X.Sync.DestroyAlarm (display, watch.xalarm);
    }

    private void init_xsync ()
    {
        var d = Gdk.Display.get_default ();
        if (!(d is Gdk.X11.Display))
        {
            warning ("Only support idle monitor under X");
            return;
        }
        display = (d as Gdk.X11.Display).get_xdisplay ();

        int sync_error_base;
        var res = X.Sync.QueryExtension (display, out sync_event_base, out sync_error_base);
        if (res == 0)
        {
            warning ("IdleMonitor: Sync extension not present");
            return;
        }

        int major, minor;
        res = X.Sync.Initialize (display, out major, out minor);
        if (res == 0)
        {
            warning ("IdleMonitor: Unable to initialize Sync extension");
            return;
        }

        counter = find_idletime_counter ();
        /* IDLETIME counter not found? */
        if (counter == X.None)
            return;

        user_active_alarm = xsync_alarm_set (X.Sync.TestType.NegativeTransition, 1, false);

        /* Note this is a bit weird, since we need to pass null as the window by Vala treats this as a method */
        Gdk.Window w = null;
        w.add_filter (xevent_filter);
    }

    private Gdk.FilterReturn xevent_filter (Gdk.XEvent xevent, Gdk.Event event)
    {
        var ev = (X.Event*) xevent;
        if (ev.xany.type != sync_event_base + X.Sync.AlarmNotify)
            return Gdk.FilterReturn.CONTINUE;

        var alarm_event = (X.Sync.AlarmNotifyEvent*) xevent;
        handle_alarm_notify_event (alarm_event);

        return Gdk.FilterReturn.CONTINUE;
    }

    private IdleMonitorWatch make_watch (X.ID xalarm, IdleMonitorWatchFunc callback)
    {
        var watch = new IdleMonitorWatch ();
        watch.id = get_next_watch_serial ();
        watch.callback = callback;
        watch.xalarm = xalarm;

        watches.insert (watch.id, watch);

        return watch;
    }

    private X.ID xsync_alarm_set (X.Sync.TestType test_type, uint64 interval, bool want_events)
    {
        var attr = X.Sync.AlarmAttributes ();
        X.Sync.Value delta;
        X.Sync.IntToValue (out delta, 0);
        attr.trigger.counter = counter;
        attr.trigger.value_type = X.Sync.ValueType.Absolute;
        attr.delta = delta;
        attr.events = want_events;
        X.Sync.IntsToValue (out attr.trigger.wait_value, (uint) interval, (int) (interval >> 32));
        attr.trigger.test_type = test_type;

        return X.Sync.CreateAlarm (display, X.Sync.CA.Counter | X.Sync.CA.ValueType | X.Sync.CA.TestType | X.Sync.CA.Value | X.Sync.CA.Delta | X.Sync.CA.Events, attr);
    }

    private void ensure_alarm_rescheduled (X.Display dpy, X.ID alarm)
    {
        /* Some versions of Xorg have an issue where alarms aren't
         * always rescheduled. Calling X.Sync.ChangeAlarm, even
         * without any attributes, will reschedule the alarm. */
        var attr = X.Sync.AlarmAttributes ();
        X.Sync.ChangeAlarm (dpy, alarm, 0, attr);
    }

    private void set_alarm_enabled (X.Display dpy, X.ID alarm, bool enabled)
    {
        var attr = X.Sync.AlarmAttributes ();
        attr.events = enabled;
        X.Sync.ChangeAlarm (dpy, alarm, X.Sync.CA.Events, attr);
    }

    private void handle_alarm_notify_event (X.Sync.AlarmNotifyEvent* alarm_event)
    {
        if (alarm_event.state != X.Sync.AlarmState.Active)
            return;

        var alarm = alarm_event.alarm;
        var has_alarm = false;

        if (alarm == user_active_alarm)
        {
            set_alarm_enabled (display, alarm, false);
            has_alarm = true;
        }
        else if (alarms.contains ((uint32) alarm))
        {
            ensure_alarm_rescheduled (display, alarm);
            has_alarm = true;
        }

        if (has_alarm)
        {
            foreach (var watch in watches.get_values ())
                fire_watch (watch, alarm);
        }
    }

    private void fire_watch (IdleMonitorWatch watch, X.ID alarm)
    {
        if (watch.xalarm != alarm)
            return;

        if (watch.callback != null)
            watch.callback (this, watch.id);

        if (watch.xalarm == user_active_alarm)
            remove_watch (watch.id);
    }

    private X.ID find_idletime_counter ()
    {
        X.ID counter = X.None;

        int ncounters;
        var counters = X.Sync.ListSystemCounters (display, out ncounters);
        for (var i = 0; i < ncounters; i++)
        {
            if (counters[i].name != null && strcmp (counters[i].name, "IDLETIME") == 0)
            {
                counter = counters[i].counter;
                break;
            }
        }
        X.Sync.FreeSystemCounterList (counters);

        return counter;
    }

    private uint32 get_next_watch_serial ()
    {
        AtomicInt.inc (ref serial);
        return serial;
    }
}

public class IdleMonitorWatch
{
    public uint id;
    public unowned IdleMonitorWatchFunc callback;
    public X.ID xalarm;
}
