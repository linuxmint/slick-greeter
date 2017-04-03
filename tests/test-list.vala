
public class TestList : UserList
{
    public TestList (Background bg, MenuBar mb)
    {
        Object (background: bg, menubar: mb);
    }

    public uint num_entries ()
    {
        return entries.length();
    }

    public bool is_scrolling ()
    {
        return mode == Mode.SCROLLING;
    }

}