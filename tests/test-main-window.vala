
public class TestMainWindow : MainWindow
{
    public TestMainWindow ()
    {
    }

    public Background get_background ()
    {
        return get_child() as Background;
    }

    protected override GreeterList create_user_list ()
    {
        return new TestList (get_background (), menubar);
    }
}
