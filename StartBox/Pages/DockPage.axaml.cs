using System.Text.Json.Serialization;
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

public class NavItem
{
    public string Icon { get; set; } = string.Empty;      // 图标字符
    public string Title { get; set; } = string.Empty;     // 标签文本
    public string PageTypeName { get; set; } = string.Empty; // 页面类型全名（用于反射创建）
    
    // 运行时缓存的页面实例（不序列化）
    [JsonIgnore]
    public StoragePage? PageInstance { get; set; }
    
    // 无参构造供反序列化使用
    public NavItem() { }
    
    public NavItem(string title, string icon, string pageTypeName)
    {
        Title = title;
        Icon = icon;
        PageTypeName = pageTypeName;
    }
}

public partial class DockPage : UserControl
{
    public DockPage()
    {
        InitializeComponent();
    }
}