using Avalonia;
using Avalonia.Controls;
using Avalonia.Markup.Xaml;

namespace StartBox.Controls;

public partial class InputBox : UserControl
{
    public InputBox()
    {
        InitializeComponent();
    }

    // 暴露 Text 属性，供外部直接使用 (例如：string val = myInput.Text;)
    public string Text
    {
        get => InnerTextBox.Text ?? string.Empty;
        set => InnerTextBox.Text = value;
    }
}