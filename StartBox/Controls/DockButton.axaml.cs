using Avalonia;
using Avalonia.Controls;
using Avalonia.Markup.Xaml;

namespace StartBox.Controls;

public partial class DockButton : UserControl
{
    private static readonly StyledProperty<string> IconProperty =
        AvaloniaProperty.Register<DockButton, string>(nameof(Icon));

    private static readonly StyledProperty<string?> TextProperty =
        AvaloniaProperty.Register<DockButton, string?>(nameof(Text));
    public string Icon
    {
        get => GetValue(IconProperty);
        set => SetValue(IconProperty, value);
    }
    public string? Text
    {
        get => GetValue(TextProperty);
        set => SetValue(TextProperty, value);
    }
    public DockButton()
    {
        InitializeComponent();
    }
}