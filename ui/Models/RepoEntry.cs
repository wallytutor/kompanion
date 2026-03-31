namespace KompanionUI.Models;

/// <summary>
/// Represents a single Git repository row in the UI.
/// </summary>
public class RepoEntry
{
    /// <summary>Short display name (directory name).</summary>
    public string Name { get; init; }

    /// <summary>Full absolute path to the repository root.</summary>
    public string FullPath { get; init; }

    public RepoEntry(string name, string fullPath)
    {
        Name     = name;
        FullPath = fullPath;
    }
}
