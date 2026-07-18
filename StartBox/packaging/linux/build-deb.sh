#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# StartBox Linux .deb 打包脚本
# 适用: Debian / Ubuntu / 银河麒麟 / UOS / 统信 / Deepin
#
# 用法:
#   ./build-deb.sh                          # 默认 amd64 框架依赖
#   ./build-deb.sh arm64                    # arm64 框架依赖
#   ./build-deb.sh amd64 PORTABLE=1         # amd64 自包含(分发给用户)
#   VERSION=1.2.3 ./build-deb.sh            # 覆盖版本号
#   MAINTAINER="Name <mail@example.com>" ./build-deb.sh
#
# 产物:
#   packaging/linux/dist/startbox_<VERSION>_<ARCH>.deb
#
# 依赖:
#   - dotnet 9 SDK
#   - dpkg-deb (Debian/Ubuntu 自带,其他发行版装: sudo apt install dpkg)
# -----------------------------------------------------------------------------

set -euo pipefail

# ---- 路径与基础配置 ----
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

PKG_NAME="startbox"
APP_NAME="StartBox"
APP_VERSION="${VERSION:-1.0.0}"
MAINTAINER="${MAINTAINER:-wwnnl <wwnnl@example.com>}"
HOMEPAGE="${HOMEPAGE:-https://github.com/yourname/startbox}"
ARCH="${1:-amd64}"
RID="linux-${ARCH}"
PORTABLE="${PORTABLE:-}"

DIST_DIR="${SCRIPT_DIR}/dist"
STAGING_DIR="${DIST_DIR}/staging"
PUBLISH_DIR="${ROOT_DIR}/bin/Release/net9.0/${RID}/publish"

cd "${SCRIPT_DIR}"

# ---- 1. 清理 ----
echo "==> [1/6] 清理 dist..."
rm -rf "${DIST_DIR}"
mkdir -p "${DIST_DIR}"

# ---- 2. dotnet publish ----
echo "==> [2/6] dotnet publish (${RID})..."
cd "${ROOT_DIR}"
PUBLISH_FLAGS=(-c Release -r "${RID}" -o "bin/Release/net9.0/${RID}/publish")
if [ -n "${PORTABLE}" ]; then
    PUBLISH_FLAGS+=(--self-contained)
fi
dotnet publish "${PUBLISH_FLAGS[@]}"
cd "${SCRIPT_DIR}"

if [ ! -d "${PUBLISH_DIR}" ]; then
    echo "ERROR: publish 目录不存在: ${PUBLISH_DIR}" >&2
    exit 1
fi

# ---- 3. 创建 staging 目录结构 ----
echo "==> [3/6] 创建 staging 目录结构..."
mkdir -p "${STAGING_DIR}/DEBIAN"
mkdir -p "${STAGING_DIR}/usr/bin"
mkdir -p "${STAGING_DIR}/usr/lib/${PKG_NAME}"
mkdir -p "${STAGING_DIR}/usr/share/applications"
mkdir -p "${STAGING_DIR}/usr/share/pixmaps"
mkdir -p "${STAGING_DIR}/usr/share/icons/hicolor/scalable/apps"
mkdir -p "${STAGING_DIR}/usr/share/icons/hicolor/256x256/apps"
mkdir -p "${STAGING_DIR}/usr/share/icons/hicolor/128x128/apps"
mkdir -p "${STAGING_DIR}/usr/share/icons/hicolor/64x64/apps"
mkdir -p "${STAGING_DIR}/usr/share/icons/hicolor/48x48/apps"
mkdir -p "${STAGING_DIR}/usr/share/icons/hicolor/32x32/apps"

# ---- 4. 渲染 control / desktop 模板 ----
echo "==> [4/6] 写入 DEBIAN/control 和 .desktop..."

# control 文件:替换占位符 + Architecture
sed -e "s|{{VERSION}}|${APP_VERSION}|g" \
    -e "s|{{MAINTAINER}}|${MAINTAINER}|g" \
    -e "s|{{HOMEPAGE}}|${HOMEPAGE}|g" \
    -e "s|^Architecture:.*|Architecture: ${ARCH}|" \
    "${SCRIPT_DIR}/DEBIAN/control" \
    > "${STAGING_DIR}/DEBIAN/control"

# .desktop:同一份源文件就是模板,避免重复定义
sed -e "s|{{APP_NAME}}|${APP_NAME}|g" \
    -e "s|{{PKG_NAME}}|${PKG_NAME}|g" \
    "${SCRIPT_DIR}/StartBox.desktop" \
    > "${STAGING_DIR}/usr/share/applications/${PKG_NAME}.desktop"

# 校验占位符已替换
for f in "${STAGING_DIR}/DEBIAN/control" "${STAGING_DIR}/usr/share/applications/${PKG_NAME}.desktop"; do
    if grep -q '{{' "$f"; then
        echo "ERROR: $f 还有未替换的占位符:" >&2
        grep '{{' "$f" >&2 || true
        exit 1
    fi
done

# ---- 5. 复制图标 + publish 产物 + 启动脚本 ----
echo "==> [5/6] 复制图标和应用文件..."
ICON_PNG="${ROOT_DIR}/Assets/Images/StartBoxIcon1024.png"
ICON_SVG="${ROOT_DIR}/Assets/Images/StartBoxIcon.svg"

if [ -f "${ICON_PNG}" ]; then
    cp "${ICON_PNG}" "${STAGING_DIR}/usr/share/pixmaps/${PKG_NAME}.png"
    for size in 256 128 64 48 32; do
        cp "${ICON_PNG}" "${STAGING_DIR}/usr/share/icons/hicolor/${size}x${size}/apps/${PKG_NAME}.png"
    done
fi
if [ -f "${ICON_SVG}" ]; then
    cp "${ICON_SVG}" "${STAGING_DIR}/usr/share/icons/hicolor/scalable/apps/${PKG_NAME}.svg"
fi

# 复制 publish 产物到 /usr/lib/startbox
cp -a "${PUBLISH_DIR}/." "${STAGING_DIR}/usr/lib/${PKG_NAME}/"
chmod -R a+rX "${STAGING_DIR}/usr/lib/${PKG_NAME}/"
chmod +x "${STAGING_DIR}/usr/lib/${PKG_NAME}/${APP_NAME}"

# 启动脚本:放在 /usr/bin/startbox,自动寻找 .NET 运行时
cat > "${STAGING_DIR}/usr/bin/${PKG_NAME}" <<'WRAPPER'
#!/bin/bash
# StartBox 启动脚本:自动探测 .NET 运行时位置,exec 主可执行文件
set -e
INSTALL_DIR="/usr/lib/startbox"

if [ -z "${DOTNET_ROOT:-}" ]; then
    for candidate in \
        "${INSTALL_DIR}" \
        /usr/share/dotnet \
        /usr/lib/dotnet \
        /opt/dotnet; do
        if [ -d "${candidate}/shared/Microsoft.NETCore.App" ]; then
            export DOTNET_ROOT="${candidate}"
            break
        fi
    done
fi

exec "${INSTALL_DIR}/StartBox" "$@"
WRAPPER
chmod +x "${STAGING_DIR}/usr/bin/${PKG_NAME}"

# 修正 Installed-Size(KB,dpkg-deb 期望字段)
INSTALLED_SIZE=$(du -sk "${STAGING_DIR}" | awk '{print $1}')
sed -i "s/^Installed-Size:.*/Installed-Size: ${INSTALLED_SIZE}/" \
    "${STAGING_DIR}/DEBIAN/control"

# ---- 6. 打包 ----
echo "==> [6/6] 生成 .deb..."
DEB_FILE="${DIST_DIR}/${PKG_NAME}_${APP_VERSION}_${ARCH}.deb"
dpkg-deb --root-owner-group --build "${STAGING_DIR}" "${DEB_FILE}"
rm -rf "${STAGING_DIR}"

# 生成 SHA256
( cd "${DIST_DIR}" && sha256sum "${DEB_FILE##*/}" > "${DEB_FILE##*/}.sha256" )

# ---- 完成 ----
echo ""
echo "==> 完成 ✅"
echo "    .deb:   ${DEB_FILE}"
echo "    sha256: ${DEB_FILE}.sha256"
echo ""
echo "安装:"
echo "    sudo apt install ${DEB_FILE}"
echo "    或者:  sudo dpkg -i ${DEB_FILE}"
echo ""
echo "卸载:"
echo "    sudo apt remove ${PKG_NAME}"
echo ""
echo "模式: $([ -n "${PORTABLE}" ] && echo "自包含(含 .NET 运行时)" || echo "框架依赖(需系统装 .NET 9)")"