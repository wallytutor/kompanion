using System.Windows;

namespace KompanionUI;

public partial class App : System.Windows.Application
{
    // Startup script execution is handled asynchronously in MainWindow.Loaded
    // so that the window appears immediately and the UI thread is never blocked.
}
