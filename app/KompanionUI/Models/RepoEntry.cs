using System.ComponentModel;
using System.Runtime.CompilerServices;

namespace KompanionUI.Models;

/// <summary>
/// Represents a single Git repository row in the UI.
/// </summary>
public class RepoEntry : INotifyPropertyChanged
{
    private string _statusColor = "#FFCCCCCC"; // Gray (initial)

    /// <summary>Short display name (directory name).</summary>
    public string Name { get; init; }

    /// <summary>Full absolute path to the repository root.</summary>
    public string FullPath { get; init; }

    /// <summary>
    /// Color indicator for repository status: #FFCCCCCC (gray, unchecked),
    /// #FF00B050 (green, clean), or #FFFF0000 (red, has changes).
    /// </summary>
    public string StatusColor
    {
        get => _statusColor;
        set
        {
            if (_statusColor != value)
            {
                _statusColor = value;
                OnPropertyChanged();
            }
        }
    }

    public RepoEntry(string name, string fullPath)
    {
        Name     = name;
        FullPath = fullPath;
    }

    public event PropertyChangedEventHandler? PropertyChanged;

    private void OnPropertyChanged([CallerMemberName] string? name = null)
    {
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
    }
}
