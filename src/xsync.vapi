namespace X
{
    [CCode (cprefix = "", cheader_filename = "X11/extensions/sync.h")]
    namespace Sync
    {
        [CCode (cname = "XSyncQueryExtension")]
        public X.Status QueryExtension (X.Display display, out int event_base, out int error_base);
        [CCode (cname = "XSyncInitialize")]
        public X.Status Initialize (X.Display display, out int major_version, out int minor_version);
        [CCode (cname = "XSyncListSystemCounters")]
        public SystemCounter* ListSystemCounters (X.Display display, out int n_counters);
        [CCode (cname = "XSyncFreeSystemCounterList")]
        public void FreeSystemCounterList (SystemCounter* counters);
        [CCode (cname = "XSyncQueryCounter")]
        public X.Status QueryCounter (X.Display display, X.ID counter, out Value value);
        [CCode (cname = "XSyncCreateAlarm")]
        public X.ID CreateAlarm (X.Display display, CA values_mask, AlarmAttributes values);
        [CCode (cname = "XSyncDestroyAlarm")]
        public X.Status DestroyAlarm (X.Display display, X.ID alarm);
        [CCode (cname = "XSyncQueryAlarm")]
        public X.Status QueryAlarm (X.Display display, X.ID alarm, out AlarmAttributes values);
        [CCode (cname = "XSyncChangeAlarm")]
        public X.Status ChangeAlarm (X.Display display, X.ID alarm, CA values_mask, AlarmAttributes values);
        [CCode (cname = "XSyncSetPriority")]
        public X.Status SetPriority (X.Display display, X.ID alarm, int priority);
        [CCode (cname = "XSyncGetPriority")]
        public X.Status GetPriority (X.Display display, X.ID alarm, out int priority);
        [CCode (cname = "XSyncIntToValue")]
        public void IntToValue (out Value value, int v);
        [CCode (cname = "XSyncIntsToValue")]
        public void IntsToValue (out Value value, uint l, int h);
        [CCode (cname = "XSyncValueGreaterThan")]
        public bool ValueGreaterThan (Value a, Value b);
        [CCode (cprefix = "XSyncCA")]
        public enum CA
        {
            Counter,
            ValueType,
            Value,
            TestType,
            Delta,
            Events
        }
        [CCode (cname = "XSyncSystemCounter", has_type_id = false)]
        public struct SystemCounter
        {
            public string name;
            public X.ID counter;
        }
        [CCode (cname = "XSyncAlarmNotify")]
        public int AlarmNotify;
        [CCode (cname = "XSyncAlarmNotifyEvent", has_type_id = false)]
        public struct AlarmNotifyEvent
        {
            public X.ID alarm;
            public AlarmState state;
        }
        [CCode (cname = "XSyncAlarmState", cprefix = "XSyncAlarm")]
        public enum AlarmState
        {
            Active,
            Inactive,
            Destroyed
        }
        [CCode (cname = "XSyncAlarmAttributes", has_type_id = false)]
        public struct AlarmAttributes
        {
            public Trigger trigger;
            public Value delta;
            public bool events;
            public AlarmState state;
        }
        [CCode (cname = "XSyncTrigger", has_type_id = false)]
        public struct Trigger
        {
            public X.ID counter;
            public ValueType value_type;
            public Value wait_value;
            public TestType test_type;
        }
        [CCode (cname = "XSyncValueType", cprefix = "XSync")]
        public enum ValueType
        {
            Absolute,
            Relative
        }
        [CCode (cname = "XSyncValue", has_type_id = false)]
        [SimpleType]
        public struct Value
        {
            public int hi;
            public uint lo;
        }
        [CCode (cname = "XSyncTestType", cprefix = "XSync")]
        public enum TestType
        {
            PositiveTransition,
            NegativeTransition,
            PositiveComparison,
            NegativeComparison
        }
    }
}
