using Avalonia;
using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Interactivity;
using Avalonia.Markup.Xaml;
using Avalonia.Media;
using Avalonia.Threading;
using ExCSS;
using HorizontalAlignment = Avalonia.Layout.HorizontalAlignment;
using VerticalAlignment = Avalonia.Layout.VerticalAlignment;

namespace StartBox.Pages;

public partial class DockPage : UserControl
{
    private int _pageCounter = 0;
    public DockPage()
    {
        InitializeComponent();
    }
}