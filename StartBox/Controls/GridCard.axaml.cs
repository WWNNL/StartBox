using Avalonia.Controls;
using Avalonia.Interactivity;

namespace StartBox.Controls;

public class AppCardData
{
    public string IconPath { get; set; } = string.Empty;
    public string Title { get; set; } = string.Empty;
    public string Version { get; set; } = string.Empty;
    public string About { get; set; } = string.Empty;
    public string ExecutablePath { get; set; } = string.Empty;
}

public partial class GridCard : UserControl
{
    private AppCardData _currentAppData = new AppCardData();
    
    public GridCard()
    {
        InitializeComponent();
    }
    
    private void UpdateCardUi(AppCardData data)
    {
        AppTitle.Text = data.Title;
        AppVersion.Text = data.Version;
        AppAbout.Text = data.About;
        
        // 动态加载图片（此处为简化逻辑，实际开发中注意路径处理）
        // AppIcon.Source = new Bitmap(data.IconPath);
    }

    // 3. 按钮点击事件：直接使用存储好的数据结构
    private void BtnRun_Click(object? sender, RoutedEventArgs e)
    {
        // 不用去 UI 里翻路径，直接从数据结构里拿
        string exePath = _currentAppData.ExecutablePath;
        
        // 执行运行逻辑...
        System.Diagnostics.Debug.WriteLine($"正在运行: {exePath}");
    }

    private void BtnLocate_Click(object? sender, RoutedEventArgs e)
    {
        System.Diagnostics.Debug.WriteLine($"正在定位文件...");
    }
}