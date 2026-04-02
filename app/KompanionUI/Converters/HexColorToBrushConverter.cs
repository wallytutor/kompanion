using System.Globalization;
using System.Windows.Data;
using System.Windows.Media;

namespace KompanionUI.Converters;

/// <summary>
/// Converts a hex color string (e.g., "#FFFF0000") to a SolidColorBrush.
/// </summary>
public class HexColorToBrushConverter : IValueConverter
{
    public object? Convert(
        object? value,
        Type targetType,
        object? parameter,
        CultureInfo? culture)
    {
        if (value is string hexColor && !string.IsNullOrWhiteSpace(hexColor))
        {
            try
            {
                // Parse hex color string: #AARRGGBB or #RRGGBB
                string hex = hexColor.TrimStart('#');
                if (hex.Length == 8)
                {
                    // #AARRGGBB format
                    byte a = byte.Parse(hex.Substring(0, 2),
                        System.Globalization.NumberStyles.HexNumber);
                    byte r = byte.Parse(hex.Substring(2, 2),
                        System.Globalization.NumberStyles.HexNumber);
                    byte g = byte.Parse(hex.Substring(4, 2),
                        System.Globalization.NumberStyles.HexNumber);
                    byte b = byte.Parse(hex.Substring(6, 2),
                        System.Globalization.NumberStyles.HexNumber);
                    return new SolidColorBrush(
                        System.Windows.Media.Color.FromArgb(a, r, g, b));
                }
            }
            catch
            {
                // Fall through to default
            }
        }

        // Default: gray
        return new SolidColorBrush(
            System.Windows.Media.Color.FromArgb(255, 204, 204, 204));
    }

    public object ConvertBack(
        object? value,
        Type targetType,
        object? parameter,
        CultureInfo? culture)
    {
        throw new NotSupportedException();
    }
}
