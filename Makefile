# StartBox 多平台构建脚本
#
# 默认发布: 框架依赖 (Framework-dependent)
#   - 体积小 (~10-20 MB),目标机器需装 .NET 9 Desktop Runtime
#   - 想切到自包含 (含 .NET 运行时,~140-170 MB): 加 PORTABLE=1
#
# 用法:
#   make build                       - Debug 构建
#   make run                         - Debug 运行
#   make clean                       - 清理所有 build/publish 输出
#   make publish-win                 - 发布 Windows x64 (框架依赖)
#   make publish-mac                 - 发布 macOS(自动探测 arm64/x64)
#   make publish-linux               - 发布 Linux x64
#   make publish-all                 - 一次性发布所有桌面平台
#   make publish-all PORTABLE=1      - 自包含发布(分发给最终用户)
#
#   make package-mac                 - macOS .app + .dmg(本机架构)
#   make package-linux               - Linux .deb(本机架构)
#   make package-win                 - Windows .exe 安装程序(需 ISCC + Windows)
#   make package-all                 - 所有平台安装包
#   make package-mac PORTABLE=1      - 自包含 macOS .dmg
#   make package-linux PORTABLE=1    - 自包含 Linux .deb
#
# 从仓库根、StartBox/、StartBox/packaging/ 等任何子目录跑都能正常工作。

# 自动探测仓库根(用 git,任何子目录都能找到)
ROOT_DIR     := $(shell git rev-parse --show-toplevel 2>/dev/null)
ifeq ($(ROOT_DIR),)
    ROOT_DIR := $(shell pwd)
endif

PROJECT      := $(ROOT_DIR)/StartBox/StartBox.csproj
CONFIG       ?= Release
PUBLISH_DIR  := $(ROOT_DIR)/StartBox/bin/$(CONFIG)
PACKAGE_DIR  := $(ROOT_DIR)/StartBox/packaging

# 自包含开关:PORTABLE=1 时开启,默认关闭
SC_FLAG      := $(if $(PORTABLE),--self-contained,)

# 自动探测 macOS 架构
UNAME_M := $(shell uname -m)
ifeq ($(UNAME_M),arm64)
    MAC_RID := osx-arm64
else ifeq ($(UNAME_M),x86_64)
    MAC_RID := osx-x64
else
    MAC_RID := osx-x64
endif

# 当前 OS
UNAME_S := $(shell uname -s)
IS_DARWIN := $(filter Darwin,$(UNAME_S))
IS_LINUX  := $(filter Linux,$(UNAME_S))

.PHONY: build run clean publish-win publish-mac publish-mac-arm publish-mac-intel publish-linux publish-all \
        package-mac package-linux package-win package-all help

help:
	@echo "===== 构建 & 发布 ====="
	@echo "  make build              - Debug 构建"
	@echo "  make run                - Debug 运行"
	@echo "  make publish-win        - 发布 Windows x64 (裸 .exe)"
	@echo "  make publish-mac        - 发布 macOS(本机架构: $(MAC_RID))"
	@echo "  make publish-linux      - 发布 Linux x64 (裸二进制)"
	@echo "  make publish-all        - 发布所有桌面平台"
	@echo ""
	@echo "===== 打包安装程序 ====="
	@echo "  make package-mac        - macOS .app + .dmg (本机)"
	@echo "  make package-linux      - Linux .deb (本机)"
	@echo "  make package-win        - Windows 安装程序 (需 ISCC)"
	@echo "  make package-all        - 所有平台安装包"
	@echo ""
	@echo "分发给最终用户 (自包含):"
	@echo "  make package-all PORTABLE=1"
	@echo "  make package-mac PORTABLE=1"
	@echo "  make package-linux PORTABLE=1"
	@echo ""
	@echo "其他:"
	@echo "  make clean              - 清理输出"

build:
	dotnet build $(PROJECT) -c Debug

run:
	dotnet run --project $(PROJECT) -c Debug

clean:
	dotnet clean $(PROJECT)
	rm -rf $(ROOT_DIR)/StartBox/bin $(ROOT_DIR)/StartBox/obj
	rm -rf $(PACKAGE_DIR)/*/dist

publish-win:
	dotnet publish $(PROJECT) -c $(CONFIG) -r win-x64 $(SC_FLAG)

publish-mac-arm:
	dotnet publish $(PROJECT) -c $(CONFIG) -r osx-arm64 $(SC_FLAG)

publish-mac-intel:
	dotnet publish $(PROJECT) -c $(CONFIG) -r osx-x64 $(SC_FLAG)

publish-mac: publish-mac-arm publish-mac-intel

publish-linux:
	dotnet publish $(PROJECT) -c $(CONFIG) -r linux-x64 $(SC_FLAG)

publish-all: publish-win publish-mac publish-linux
	@echo ""
	@echo "所有桌面平台发布完成。产物在 $(PUBLISH_DIR)/<rid>/publish/"
	@echo "模式: $(if $(PORTABLE),自包含 (含 .NET 运行时),框架依赖 (目标机器需装 .NET 9))"

# ---- 打包安装程序 ----

package-mac:
	@if [ -z "$(IS_DARWIN)" ]; then echo "ERROR: macOS 打包只能在 macOS 上跑"; exit 1; fi
	cd $(PACKAGE_DIR)/macos && PORTABLE='$(PORTABLE)' ./build-app.sh $(MAC_RID)

package-linux:
	@if [ -z "$(IS_LINUX)" ] && [ -z "$(IS_DARWIN)" ]; then echo "ERROR: Linux 打包需要 Linux 或 macOS (dpkg-deb)"; exit 1; fi
	@if ! command -v dpkg-deb >/dev/null 2>&1; then echo "ERROR: 找不到 dpkg-deb。macOS 上跑: brew install dpkg"; exit 1; fi
	cd $(PACKAGE_DIR)/linux && PORTABLE='$(PORTABLE)' ./build-deb.sh amd64

package-win:
	@echo "Windows 安装包需要 Windows 机器 + Inno Setup 6。"
	@echo "步骤:"
	@echo "  1. 在 Windows 上先跑: dotnet publish StartBox\\StartBox.csproj -c Release -r win-x64 --self-contained"
	@echo "  2. 装 Inno Setup: https://jrsoftware.org/isinfo.php"
	@echo "  3. 跑: ISCC.exe StartBox\\packaging\\windows\\StartBox.iss"
	@echo "  4. 产物: StartBox\\packaging\\windows\\dist\\StartBox-Setup-1.0.0-win-x64.exe"
	@echo ""
	@echo "如果想在 macOS 上交叉编译 .exe 安装程序,先装 wine + Inno Setup Command Line,"
	@echo "然后跑: make package-win-via-wine"
	@echo "(未实现,需要你写 wine 包装脚本)"

package-all: package-mac package-linux
	@echo ""
	@echo "macOS .dmg + Linux .deb 打包完成。"
	@echo "Windows 安装程序需要在 Windows 上跑 (见 'make package-win')。"

