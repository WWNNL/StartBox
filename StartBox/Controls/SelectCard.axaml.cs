using Avalonia;
using Avalonia.Controls;
using Avalonia.Markup.Xaml;

namespace StartBox.Controls;

public partial class SelectCard : UserControl
{
    private static readonly StyledProperty<string> IconProperty =
        AvaloniaProperty.Register<SelectCard, string>(nameof(Icon));

    private static readonly StyledProperty<string?> TextProperty =
        AvaloniaProperty.Register<SelectCard, string?>(nameof(Text));
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
    public SelectCard()
    {
        InitializeComponent();
    }
}