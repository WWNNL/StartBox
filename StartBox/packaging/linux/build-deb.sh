#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# StartBox Linux .deb 打包脚本
# 适用: Debian / Ubuntu / 银河麒麟 / UOS / 统信 / Deepin
#
# 用法:
#   ./build-deb.sh                          # 默认 amd64 框架依赖(用户机器装 .NET 9)
#   ./build-deb.sh amd64 PORTABLE=1         # amd64 自包含(分发给用户)
#   ./build-deb.sh arm64 PORTABLE=1         # arm64 自包含(给 ARM Linux / 麒麟 ARM)
#
# 产物:
#   packaging/linux/dist/startbox_1.0.0_amd64.deb
#
# 依赖:
#   - dotnet 9 SDK
#   - dpkg-deb (Debian/Ubuntu 自带,其他发行版装: sudo apt install dpkg)
# -----------------------------------------------------------------------------

set -euo pipefail

# 路径先定义
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# 配置
PKG_NAME="startbox"
APP_NAME="StartBox"
APP_VERSION="1.0.0"
ARCH="${1:-amd64}"   # amd64 | arm64
RID="linux-${ARCH}"
PORTABLE="${PORTABLE:-}"

DIST_DIR="${SCRIPT_DIR}/dist"
STAGING_DIR="${DIST_DIR}/staging"
PUBLISH_DIR="${ROOT_DIR}/bin/Release/net9.0/${RID}/publish"

cd "${SCRIPT_DIR}"

# ---- 1. 清理 ----
rm -rf "${DIST_DIR}"
mkdir -p "${DIST_DIR}"

# ---- 2. dotnet publish ----
echo "==> [1/6] dotnet publish (${RID})..."
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
echo "==> [2/6] 创建 staging 目录结构..."
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

# ---- 4. 复制 control 和 desktop ----
echo "==> [3/6] 写入 DEBIAN/control 和 .desktop..."

# control 文件(根据 ARCH 替换 Architecture 字段)
sed "s/^Architecture:.*/Architecture: ${ARCH}/" \
    "${SCRIPT_DIR}/DEBIAN/control" \
    > "${STAGING_DIR}/DEBIAN/control"

# 直接生成 .desktop(避免 BSD sed -i 跨平台坑)
cat > "${STAGING_DIR}/usr/share/applications/${PKG_NAME}.desktop" <<EOF
[Desktop Entry]
Version=1.0
Name=${APP_NAME}
GenericName=${APP_NAME}
Comment=Cross-platform desktop app built with Avalonia
Exec=/usr/bin/${PKG_NAME} %F
Icon=${PKG_NAME}
Terminal=false
Type=Application
Categories=Utility;
StartupNotify=true
StartupWMClass=${APP_NAME}
Keywords=utility;desktop;
EOF

# ---- 5. 复制图标 ----
echo "==> [4/6] 复制图标..."
ICON_PNG="${ROOT_DIR}/Assets/Images/StartBoxIcon1024.png"
ICON_SVG="${ROOT_DIR}/Assets/Images/StartBoxIcon.svg"

if [ -f "${ICON_PNG}" ]; then
    # 复制到多分辨率 + pixmaps
    cp "${ICON_PNG}" "${STAGING_DIR}/usr/share/pixmaps/${PKG_NAME}.png"
    for size in 256 128 64 48 32; do
        cp "${ICON_PNG}" "${STAGING_DIR}/usr/share/icons/hicolor/${size}x${size}/apps/${PKG_NAME}.png"
    done
fi
if [ -f "${ICON_SVG}" ]; then
    cp "${ICON_SVG}" "${STAGING_DIR}/usr/share/icons/hicolor/scalable/apps/${PKG_NAME}.svg"
fi

# ---- 6. 复制 publish 输出 + 启动脚本 ----
echo "==> [5/6] 复制应用文件..."
cp -a "${PUBLISH_DIR}/." "${STAGING_DIR}/usr/lib/${PKG_NAME}/"
chmod -R a+rX "${STAGING_DIR}/usr/lib/${PKG_NAME}/"
chmod +x "${STAGING_DIR}/usr/lib/${PKG_NAME}/${APP_NAME}"

# 启动脚本(让用户能直接命令行启动 startbox)
cat > "${STAGING_DIR}/usr/bin/${PKG_NAME}" <<EOF
#!/bin/bash
# ${APP_NAME} 启动脚本
exec /usr/lib/${PKG_NAME}/${APP_NAME} "\$@"
EOF
chmod +x "${STAGING_DIR}/usr/bin/${PKG_NAME}"

# 修正 Installed-Size(以 KB 为单位)
INSTALLED_SIZE=$(du -sk "${STAGING_DIR}" | awk '{print $1}')
perl -i -pe "s/^Installed-Size:.*/Installed-Size: ${INSTALLED_SIZE}/" \
    "${STAGING_DIR}/DEBIAN/control"

# ---- 7. 打包 ----
echo "==> [6/6] 生成 .deb..."
DEB_FILE="${DIST_DIR}/${PKG_NAME}_${APP_VERSION}_${ARCH}.deb"
dpkg-deb --root-owner-group --build "${STAGING_DIR}" "${DEB_FILE}"
rm -rf "${STAGING_DIR}"

# ---- 完成 ----
echo ""
echo "==> 完成 ✅"
echo "    .deb: ${DEB_FILE}"
echo ""
echo "安装:"
echo "    sudo apt install ${DEB_FILE}"
echo "    或者:  sudo dpkg -i ${DEB_FILE}"
echo ""
echo "卸载:"
echo "    sudo apt remove ${PKG_NAME}"
echo ""
echo "模式: $([ -n "${PORTABLE}" ] && echo "自包含(含 .NET 运行时)" || echo "框架依赖(需系统装 .NET 9)")"
