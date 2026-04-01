using KompanionUI.Services;

namespace KompanionUI.Tests;

internal sealed class FakeProcessExecutor : IProcessExecutor
{
    public required Func<ProcessExecutionRequest, CancellationToken, ProcessExecutionResult> Handler
    {
        get;
        init;
    }

    public int CallCount { get; private set; }

    public ProcessExecutionRequest? LastRequest { get; private set; }

    public ProcessExecutionResult Execute(
        ProcessExecutionRequest request,
        CancellationToken cancellationToken = default)
    {
        CallCount++;
        LastRequest = request;
        return Handler(request, cancellationToken);
    }
}
