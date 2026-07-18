# StartBox 打包与发布指南

Windows / macOS / Linux 三端桌面应用打包脚本与 CI 流水线说明。

## TL;DR

| 用途 | 命令 |
|---|---|
| 本地调试运行 | `make run` |
| 本地冒烟测试 | `make verify` |
| 跨平台发布 | **push tag `v1.2.3` → GitHub Actions 自动打三个平台** |
| 本地打单个包 | `make package-mac` / `make package-linux` |
| 强制自包含 | `PORTABLE=1 make package-mac` |
| 改版本号 | `VERSION=1.2.3 make verify` |

---

## 一、发布流程（推荐走 CI）

CI 是跨平台打包的**唯一推荐路径**。本地只做开发调试。

### 自动发布

```bash
git tag v1.2.3
git push origin v1.2.3
```

GitHub Actions (`.github/workflows/release.yml`) 会：

1. 解析 tag，得到 `VERSION=1.2.3`
2. 在 `ubuntu-latest` / `macos-14` / `macos-13` / `windows-latest` 四个 runner 上并发跑：
   - Linux x64 → `startbox-1.2.3-linux-amd64.deb`
   - macOS arm64 (Apple Silicon) → `startbox-1.2.3-macos-arm64.dmg`
   - macOS x64 (Intel) → `startbox-1.2.3-macos-x64.dmg`
   - Windows x64 → `startbox-setup-1.2.3-win-x64.exe`
3. 生成 `SHA256SUMS`（每个产物 + 各自 `.sha256` 文件）
4. 上传为 **draft release**，需到 GitHub Releases 页手动 publish

### 手动触发

`Actions` → `Release` → `Run workflow` → 输入版本号。

### CI 不做的事

- ❌ **Apple 公证（notarization）**：需要 Apple Developer 账号 + `xcrun notarytool`，本仓库未配置。
- ❌ **代码签名**：macOS 上 `.app` 是未签名的，第一次打开会被 Gatekeeper 拦截（右键 → 打开 即可）。
- ❌ **Linux ARM64 / Windows ARM64**：GitHub-hosted runner 上构建没开，可按需扩 `release.yml`。

---

## 二、版本号来源

只有一个真相源：**仓库根 `Directory.Build.props`** 中的 `<Version>`。

- `dotnet build` / `dotnet publish` 通过 `-p:Version=X.Y.Z` 传入（默认走 Directory.Build.props）
- macOS 脚本读 `VERSION` 环境变量，sed 注入到 `Info.plist`
- Linux 脚本读 `VERSION` 环境变量，sed 注入到 `DEBIAN/control`
- Windows 安装器通过 `ISCC /DMyAppVersion=X.Y.Z` 传入

CI 自动从 tag 取（`v1.2.3` → `1.2.3`），本地手动用 `VERSION=1.2.3 make ...`。

---

## 三、本地开发

```bash
make build         # Debug 构建
make run           # Debug 运行
make verify        # Release 构建，提交前冒烟
make clean         # 清理所有 build/publish/package 输出
```

---

## 四、本地打包（单平台冒烟）

只在修改了打包脚本本身时需要本地跑，平时依赖 CI。

### macOS

```bash
# 仅本机架构（Apple Silicon → osx-arm64，Intel → osx-x64）
make package-mac

# 自包含（分发给最终用户）
make package-mac PORTABLE=1

# 指定架构 + 版本
make package-mac VERSION=1.2.3
# 等价于直接调:
./StartBox/packaging/macos/build-app.sh VERSION=1.2.3 PORTABLE=1

# 可选 Developer ID 签名（不公证）
CODESIGN_IDENTITY="Developer ID Application: ACME (XXXXXXXXXX)" make package-mac PORTABLE=1
```

产物：`StartBox/packaging/macos/dist/StartBox.app`、`StartBox-<VERSION>-<RID>.dmg`、`<...>.dmg.sha256`。

### Linux

```bash
make package-linux                    # amd64 框架依赖
make package-linux PORTABLE=1         # amd64 自包含
./StartBox/packaging/linux/build-deb.sh arm64 PORTABLE=1   # arm64 自包含
MAINTAINER="Your Name <you@example.com>" make package-linux
```

产物：`StartBox/packaging/linux/dist/startbox_<VERSION>_<ARCH>.deb` + `.sha256`。

依赖：Debian/Ubuntu 自带 `dpkg-deb`；macOS 上跑 Linux 打包需要 `brew install dpkg`。

### Windows

Windows 安装包只能在 Windows 上构建（Inno Setup 编译器是 Win32 PE）。两种方式：

1. **走 CI**：push tag 自动产出
2. **手动（Windows 上）**：

```bat
dotnet publish StartBox\StartBox.csproj -c Release -r win-x64 --self-contained -p:Version=1.2.3
"C:\Program Files (x86)\Inno Setup 6\ISCC.exe" /DMyAppVersion=1.2.3 StartBox\packaging\windows\StartBox.iss
```

产物：`StartBox\packaging\windows\dist\StartBox-Setup-<VERSION>-win-x64.exe`。

---

## 五、各平台脚本细节

### `macos/build-app.sh`

- 接受完整 RID（`osx-arm64`）或简写（`arm64`/`x64`）
- 自动探测本机架构作为默认值
- 从单张 1024×1024 PNG 用 `sips` 生成 Apple 标准 iconset（`16@2x`/`32@2x`/`128@2x`/...）
- dmg 用 APFS 文件系统，容量 400 MB（足够自包含 .NET 运行时）
- 写一个空的 `PkgInfo`，让 `lsbom` 等工具把它识别为合规 bundle
- 可选 `CODESIGN_IDENTITY` 环境变量触发 `codesign --deep --options runtime`

### `linux/build-deb.sh`

- 启动脚本 `/usr/bin/startbox` 会自动探测 `.NET` 运行时位置：
  - `/usr/lib/startbox`（自包含）
  - `/usr/share/dotnet`（Debian/Ubuntu 官方包）
  - `/usr/lib/dotnet`、`/opt/dotnet`
- `.desktop` 文件用 `packaging/linux/StartBox.desktop` 模板渲染，避免重复定义
- `DEBIAN/control` 用同样的 sed 占位符模式

### `windows/StartBox.iss`

- Inno Setup 6.x 脚本，通过 ISPP（preprocessor）渲染
- 默认版本 1.0.0，CI/手动用 `/DMyAppVersion=X.Y.Z` 覆盖
- `PublishDir` 默认从 `.iss` 位置往上两级算，可通过 `/DPublishDir=<绝对路径>` 覆盖
- `Modern` 安装向导 + 双语（English / 简体中文）

---

## 六、目录结构

```
.github/workflows/
  ci.yml                          # PR/main 构建检查
  release.yml                     # tag 触发的发布流水线
StartBox/packaging/
  README.md                       # 本文件
  macos/
    build-app.sh                  # macOS .app + .dmg
    Info.plist                    # 含 {{VERSION}} {{BUNDLE_ID}} {{COPYRIGHT}} 占位符
  linux/
    build-deb.sh                  # Linux .deb
    DEBIAN/control                # 含 {{VERSION}} {{MAINTAINER}} {{HOMEPAGE}}
    StartBox.desktop              # 含 {{APP_NAME}} {{PKG_NAME}}
  windows/
    StartBox.iss                  # Inno Setup 脚本
Makefile                          # 根目录:本地开发 + 单平台打包入口
Directory.Build.props             # 版本号单一真相源
```

---

## 七、常见问题

**Q: dmg 打开被 Gatekeeper 拦截？**
A: 未签名是预期的。右键 → 打开 → 确认。若要分发，建议跑 `CODESIGN_IDENTITY=... make package-mac`。

**Q: 自包含 .deb 装上后启动报错找不到运行时？**
A: 启动脚本 `/usr/bin/startbox` 会自动探测标准路径。如系统把 .NET 装到非常规位置，运行时设 `DOTNET_ROOT=/path/to/dotnet` 即可。

**Q: 想同时打 arm64 + x64 macOS dmg？**
A: 直接 `git tag v1.2.3 && git push origin v1.2.3`，CI 自动并行出两个架构。本地也可以分别跑：
```bash
./StartBox/packaging/macos/build-app.sh osx-arm64
./StartBox/packaging/macos/build-app.sh osx-x64
```

**Q: 想跑 Windows 打包但没 Windows 机器？**
A: 当前仓库不提供 Wine 包装脚本。推 tag 让 CI 跑 `windows-latest` job 即可，产物会出现在 release draft 里。

---

## 八、已知限制

- Apple 公证未接入，`.app`/`dmg` 首次打开需手动确认
- 没有自动签名/公证 pipeline
- Linux 只覆盖 Debian 系（`.deb`），没出 RPM/AppImage
- Windows Inno Setup 脚本需要 Windows runner，本地 macOS/Linux 无法直接跑