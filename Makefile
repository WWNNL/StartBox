# 本地开发 + 单平台打包入口。
# 跨平台批量发布请走 .github/workflows/release.yml。
#
# 通用开关:
#   VERSION=1.2.3   覆盖版本号(默认从 Directory.Build.props 读)
#   PORTABLE=1      自包含发布(含 .NET 运行时,适合分发)

ROOT_DIR := $(shell git rev-parse --show-toplevel 2>/dev/null)
ifeq ($(ROOT_DIR),)
    ROOT_DIR := $(shell pwd)
endif

PROJECT     := $(ROOT_DIR)/StartBox/StartBox.csproj
PACKAGE_DIR := $(ROOT_DIR)/StartBox/packaging

# 版本号默认从 Directory.Build.props 的 <Version> 读,
# 避免在 Makefile / 脚本 / ISCC / control 四处同步同一个数字。
# 用 sed 而非 dotnet msbuild,因为前者 1ms,后者要 SDK 评估整个项目;
# 用 sed 而非 grep -P,因为 macOS BSD grep 不支持 -P。
VERSION ?= $(shell sed -n 's:.*<Version>\([^<]*\)</Version>.*:\1:p' $(ROOT_DIR)/Directory.Build.props 2>/dev/null || echo 1.0.0)

# 自包含:只接受 1/true/yes/on
SC_FLAG := $(if $(filter 1 true yes on,$(PORTABLE)),--self-contained,)

# 抽公共 dotnet publish 命令,避免每个 target 重复写
PUB_BASE = dotnet publish $(PROJECT) -c Release -p:Version=$(VERSION) $(SC_FLAG)

UNAME_M := $(shell uname -m)
ifeq ($(UNAME_M),arm64)
    MAC_RID := osx-arm64
else ifeq ($(UNAME_M),x86_64)
    MAC_RID := osx-x64
else
    MAC_RID := osx-arm64
endif

UNAME_S := $(shell uname -s)
IS_DARWIN := $(filter Darwin,$(UNAME_S))
IS_LINUX  := $(filter Linux,$(UNAME_S))

export VERSION
export PORTABLE

.PHONY: build run clean verify help \
        publish-win publish-mac publish-mac-all publish-linux \
        package-mac package-linux package-win

build:
	dotnet build $(PROJECT) -c Debug -p:Version=$(VERSION)

run:
	dotnet run --project $(PROJECT) -c Debug -p:Version=$(VERSION)

verify:
	dotnet build $(PROJECT) -c Release -p:Version=$(VERSION) --no-restore
	@echo ""
	@echo "Release 构建通过 ✅"

clean:
	dotnet clean $(PROJECT) -c Debug
	dotnet clean $(PROJECT) -c Release
	rm -rf $(ROOT_DIR)/StartBox/bin $(ROOT_DIR)/StartBox/obj
	rm -rf $(PACKAGE_DIR)/*/dist $(PACKAGE_DIR)/*/staging
	@echo "清理完成 ✅"

publish-win:
	$(PUB_BASE) -r win-x64

publish-mac:
	$(PUB_BASE) -r $(MAC_RID)

# 两个 RID 互不依赖,串行写出来只是为人类可读;
# 用 .PHONY + .NOTPARALLEL 反模式不如直接 make -j2 publish-mac-all
publish-mac-all:
	$(PUB_BASE) -r osx-arm64 &
	$(PUB_BASE) -r osx-x64 &
	wait

publish-linux:
	$(PUB_BASE) -r linux-x64

package-mac:
	@if [ -z "$(IS_DARWIN)" ]; then echo "ERROR: macOS 打包只能在 macOS 上跑"; exit 1; fi
	cd $(PACKAGE_DIR)/macos && ./build-app.sh $(MAC_RID)

package-linux:
	@if [ -z "$(IS_LINUX)" ] && [ -z "$(IS_DARWIN)" ]; then echo "ERROR: Linux 打包需要 Linux 或 macOS (dpkg-deb)"; exit 1; fi
	@if ! command -v dpkg-deb >/dev/null 2>&1; then echo "ERROR: 找不到 dpkg-deb。macOS 上跑: brew install dpkg"; exit 1; fi
	cd $(PACKAGE_DIR)/linux && ./build-deb.sh amd64

package-win:
	@echo "Windows 安装包只能在 Windows 上跑,或 push tag 触发 .github/workflows/release.yml"
	@echo "  手动: ISCC.exe /DMyAppVersion=$(VERSION) packaging\\windows\\StartBox.iss"

help:
	@echo "  make build         - Debug 构建"
	@echo "  make run           - Debug 运行"
	@echo "  make verify        - Release 构建(提交前冒烟)"
	@echo "  make clean         - 清理 build/publish/package 输出"
	@echo ""
	@echo "  make publish-win        - Windows x64 (框架依赖)"
	@echo "  make publish-mac        - macOS 本机架构 ($(MAC_RID))"
	@echo "  make publish-mac-all    - macOS arm64 + x64 (并行)"
	@echo "  make publish-linux      - Linux x64 (框架依赖)"
	@echo ""
	@echo "  make package-mac        - macOS .app + .dmg (本机架构)"
	@echo "  make package-linux      - Linux .deb (amd64)"
	@echo "  make package-win        - 仅打印 Windows 打包步骤"
	@echo ""
	@echo "  VERSION=1.2.3    - 覆盖版本号"
	@echo "  PORTABLE=1       - 自包含发布"
	@echo ""
	@echo "  跨平台批量发布: push tag v* 触发 .github/workflows/release.yml"