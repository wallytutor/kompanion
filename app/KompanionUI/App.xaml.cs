using System.Diagnostics;
using System.IO;
using System.IO.Pipes;
using System.Windows;

namespace KompanionUI;

public partial class App : System.Windows.Application
{
    private const string SingletonMutexName = @"Local\KompanionUI.Singleton";
    private const string ActivationPipeName = "KompanionUI.Activation";
    private const string ActivateCommand = "ACTIVATE";

    private Mutex? _singleInstanceMutex;
    private CancellationTokenSource? _activationListenerCts;
    private Task? _activationListenerTask;

    protected override void OnStartup(StartupEventArgs e)
    {
        bool createdNew;
        _singleInstanceMutex = new Mutex(initiallyOwned: true, SingletonMutexName,
            out createdNew);

        if (!createdNew)
        {
            SignalRunningInstance();
            Shutdown();
            return;
        }

        StartActivationListener();

        MainWindow = new MainWindow();
        MainWindow.Show();

        base.OnStartup(e);
    }

    protected override void OnExit(ExitEventArgs e)
    {
        _activationListenerCts?.Cancel();

        try
        {
            _activationListenerTask?.Wait(TimeSpan.FromSeconds(1));
        }
        catch
        {
            // Best-effort shutdown; ignore listener cancellation races.
        }

        _activationListenerCts?.Dispose();

        if (_singleInstanceMutex != null)
        {
            _singleInstanceMutex.ReleaseMutex();
            _singleInstanceMutex.Dispose();
        }

        base.OnExit(e);
    }

    private void StartActivationListener()
    {
        _activationListenerCts = new CancellationTokenSource();
        CancellationToken token = _activationListenerCts.Token;

        _activationListenerTask = Task.Run(async () =>
        {
            while (!token.IsCancellationRequested)
            {
                try
                {
                    using var server = new NamedPipeServerStream(
                        ActivationPipeName,
                        PipeDirection.In,
                        maxNumberOfServerInstances: 1,
                        PipeTransmissionMode.Byte,
                        PipeOptions.Asynchronous);

                    await server.WaitForConnectionAsync(token);

                    using var reader = new StreamReader(server);
                    string? command = await reader.ReadLineAsync(token);

                    if (string.Equals(command, ActivateCommand,
                        StringComparison.OrdinalIgnoreCase))
                    {
                        await Dispatcher.InvokeAsync(BringMainWindowToFront);
                    }
                }
                catch (OperationCanceledException)
                {
                    return;
                }
                catch (Exception ex)
                {
                    Debug.WriteLine($"Singleton activation listener error: {ex.Message}");
                }
            }
        }, token);
    }

    private static void SignalRunningInstance()
    {
        try
        {
            using var client = new NamedPipeClientStream(".", ActivationPipeName,
                PipeDirection.Out);
            client.Connect(timeout: 300);

            using var writer = new StreamWriter(client) { AutoFlush = true };
            writer.WriteLine(ActivateCommand);
        }
        catch
        {
            // Ignore failures; worst case the already-running instance is unchanged.
        }
    }

    private void BringMainWindowToFront()
    {
        if (MainWindow is MainWindow main)
        {
            main.RestoreFromExternalActivation();
            return;
        }

        if (MainWindow == null)
            return;

        MainWindow.Show();
        MainWindow.WindowState = WindowState.Normal;
        MainWindow.Activate();
    }
}
