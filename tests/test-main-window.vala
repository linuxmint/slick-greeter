
public class TestMainWindow : MainWindow
{
    public TestMainWindow ()
    {
    }

    public Background get_background ()
    {
        return get_child() as Background;
    }
}
