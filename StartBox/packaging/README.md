# StartBox 多平台安装包打包指南

本目录包含 Windows / macOS / Linux 三个桌面平台的安装包打包脚本。

## 一览

| 平台 | 安装包 | 脚本 | 工具链 | 产物 |
|---|---|---|---|---|
| Windows | `.exe` 安装程序 | `windows/StartBox.iss` | Inno Setup 6.x | `StartBox-Setup-1.0.0-win-x64.exe` |
| macOS | `.app` + `.dmg` | `macos/build-app.sh` | 系统自带 `sips` + `iconutil` + `hdiutil` | `StartBox-1.0.0-osx-arm64.dmg` |
| Linux | `.deb` 包 | `linux/build-deb.sh` | `dpkg-deb` | `startbox_1.0.0_amd64.deb` |

所有脚本都通过 `Makefile` 集成,在项目根目录跑即可。

## 快速上手

```bash
# macOS: 打包 .app + .dmg(本机架构)
make package-mac

# Linux: 打包 .deb
make package-linux

# 一次性出本机可打包的所有平台
make package-all

# 分发给最终用户(自包含,体积大)
make package-all PORTABLE=1
```

## 各平台详细步骤

### macOS (`make package-mac`)

**前置条件**(macOS 自带):
- `dotnet 9 SDK`
- `sips` / `iconutil` / `hdiutil`

**脚本行为**:
1. 跑 `dotnet publish -r osx-arm64`(可选 `--self-contained`)
2. 从 `Assets/Images/StartBoxIcon1024.png` 生成 `StartBox.icns`
3. 拼装 `StartBox.app/Contents/{MacOS, Resources, Info.plist}`
4. 用 `hdiutil` 打包成只读 `.dmg`(含 `Applications` 软链接)

**未做的事**:
- ❌ Apple 公证(notarization)——需要 Apple Developer 账号 + `xcrun notarytool`
- ❌ 跨架构编译(只产本机架构;要交叉编译改 RID 参数)

**发布**:
- 第一次打开 .dmg 拖进 Applications,Gatekeeper 可能拦,**右键 → 打开** 即可
- 公网分发必须做公证,否则 Gatekeeper 强制拦截

### Linux (`make package-linux`)

**前置条件**:
- `dotnet 9 SDK`
- `dpkg-deb`(Debian/Ubuntu 自带;macOS: `brew install dpkg`)

**脚本行为**:
1. 跑 `dotnet publish -r linux-x64`(可选 `--self-contained`)
2. 拼装 Debian 标准目录结构:
   ```
   /usr/bin/startbox              # 启动脚本
   /usr/lib/startbox/             # 应用文件
   /usr/share/applications/       # .desktop 桌面快捷方式
   /usr/share/pixmaps/            # 图标
   /usr/share/icons/hicolor/.../  # 多分辨率图标
   ```
3. 用 `dpkg-deb` 打包

**安装 / 卸载**:
```bash
sudo apt install ./startbox_1.0.0_amd64.deb    # 装
sudo apt remove startbox                       # 卸
```

**未做的事**:
- ❌ AppImage(跨发行版的单文件方案)
- ❌ RPM 包(RedHat/Fedora)
- ❌ ARM64 / 其他架构(改 ARCH 参数即可)

### Windows (`make package-win`)

`make package-win` 只打印步骤说明,**实际打包需要 Windows 机器 + Inno Setup**。

**前置条件**:
- Windows 10/11
- .NET 9 SDK
- Inno Setup 6.x: <https://jrsoftware.org/isinfo.php>

**手动步骤**:
```bat
:: 1. 先跑 publish
dotnet publish StartBox\StartBox.csproj -c Release -r win-x64 --self-contained

:: 2. 编译安装程序(会自动找 ISCC.exe)
"C:\Program Files (x86)\Inno Setup 6\ISCC.exe" StartBox\packaging\windows\StartBox.iss

:: 3. 产物
:: StartBox\packaging\windows\dist\StartBox-Setup-1.0.0-win-x64.exe
```

**未做的事**:
- ❌ MSIX(微软商店格式)
- ❌ exe 图标(需要 .ico 文件,把 `packaging/windows/StartBox.iss` 里的 `SetupIconFile=StartBox.ico` 取消注释并提供 .ico)

## 自定义配置

需要改的全局变量在每个脚本的开头:
- `APP_NAME`:应用显示名(影响 .desktop / .app / Info.plist)
- `APP_VERSION`:版本号
- `APP_BUNDLE_ID`(macOS):`com.xxx.xxx` 格式
- `PKG_NAME`(Linux):deb 包名,小写无空格
- `Maintainer`(Linux DEBIAN/control):你的名字 + 邮箱
- 各种 Icon 路径

## 图标建议

| 平台 | 格式 | 推荐尺寸 |
|---|---|---|
| Windows `.ico` | `.ico` | 256×256 多分辨率 |
| macOS `.icns` | `.icns` | 1024×1024 源 png |
| Linux `.png` | `.png` | 256×256 + SVG 矢量 |

当前 `Assets/Images/StartBoxIcon1024.png` 是 **1024×1024**(高质量源图)。`StartBoxIcon64.png` 是历史遗留的小图,仅作备份。

如果以后要换图标:
1. 用 SVG(`StartBoxIcon.svg`)在任意工具导出新的 1024×1024 PNG,覆盖 `StartBoxIcon1024.png`
2. macOS 脚本自动从中生成全套尺寸
3. Windows 用同一张 PNG 转 `.ico`(ImageMagick: `magick icon.png -define icon:auto-resize=256,128,64,32,16 icon.ico`)

## 体积优化

框架依赖 vs 自包含,见根目录 `Makefile` 的 `PORTABLE` 开关:
- `make package-mac` — 框架依赖(目标机器装 .NET 9,体积 ~30 MB)
- `make package-mac PORTABLE=1` — 自包含(含 .NET 运行时,体积 ~140 MB,适合分发)

## 已知限制

- macOS 不做代码签名/公证,只适合本地/内部分发
- Windows 必须用 Windows 机器打包(没做 Wine 交叉编译)
- Linux 只支持 Debian 系(`.deb`),不覆盖 RHEL/Fedora
