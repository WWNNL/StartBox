using Avalonia.Controls;
using Avalonia.Interactivity;

namespace StartBox.Controls;

public partial class SearchBox : UserControl
{
    public SearchBox()
    {
        InitializeComponent();
    }

    // 暴露 Text 属性，供外部直接使用 (例如：string val = myInput.Text;)
    public string Text
    {
        get => InnerTextBox.Text ?? string.Empty;
        set => InnerTextBox.Text = value;
    }

    // 右侧小叉清除文本的功能
    private void ClearButton_Click(object? sender, RoutedEventArgs e)
    {
        InnerTextBox.Text = string.Empty;
        InnerTextBox.Focus();
    }
}