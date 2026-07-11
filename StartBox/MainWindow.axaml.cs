using Avalonia.Controls;
using Avalonia.Interactivity;

namespace StartBox;

public partial class MainWindow : Window
{
    private bool _isExpanded = true;
        
    // 定义展开和收起的宽度
    private const double ExpandedWidth = 382;
    private const double CollapsedWidth = 60; 

    public MainWindow()
    {
        InitializeComponent();
    }

    private void OnToggleSideBar(object? sender, RoutedEventArgs e)
    {
        _isExpanded = !_isExpanded;

        // 1. 触发侧边栏宽度动画 (中栏的文字会随之被物理裁剪，一点点减少)
        SideBar.Width = _isExpanded ? ExpandedWidth : CollapsedWidth;

        // 2. 处理标题的淡入淡出 (可选，如果不加这一步，标题会被侧边栏边缘直接切掉)
        LblTitle.Opacity = _isExpanded ? 1.0 : 0.0;

        // 3. 隐藏/显示部分按钮 (使用 Opacity 配合 XAML 中的 Transitions 实现平滑过渡)
        var targetOpacity = _isExpanded ? 1.0 : 0.0;
        var isHitTestVisible = _isExpanded; // 隐藏时禁止点击

        if (BtnBottomAdd == null) return;
        BtnBottomAdd.Opacity = targetOpacity;
        BtnBottomAdd.IsHitTestVisible = isHitTestVisible;
    }
}