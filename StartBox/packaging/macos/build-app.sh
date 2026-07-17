#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# StartBox macOS 打包脚本
# 把 dotnet publish 产物组装成 .app,再打成 .dmg
#
# 用法:
#   ./build-app.sh                          # 用默认配置(arm64)
#   ./build-app.sh x64                      # 打 Intel 版本
#   ./build-app.sh arm64 PORTABLE=1         # 自包含发布(分发给用户)
#
# 产物:
#   packaging/macos/dist/StartBox.app
#   packaging/macos/dist/StartBox-1.0.0-osx-arm64.dmg
#
# 依赖(macOS 自带):
#   - dotnet 9 SDK
#   - sips / iconutil (系统自带)
#   - hdiutil (系统自带)
#
# 不做 Apple 公证(notarization),仅适合本地/内部分发。
# 公网分发前需用 Apple Developer 账号 + xcrun notarytool。
# -----------------------------------------------------------------------------

set -euo pipefail

# 路径先定义(被后面配置引用)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# 配置
APP_NAME="StartBox"
APP_DISPLAY_NAME="StartBox"
APP_VERSION="1.0.0"
APP_BUNDLE_ID="com.wwnnl.startbox"
RID="${1:-osx-arm64}"   # 完整 RID: osx-arm64 | osx-x64
PORTABLE="${PORTABLE:-}"
PUBLISH_DIR="${ROOT_DIR}/bin/Release/net9.0/${RID}/publish"
DIST_DIR="dist"
APP_BUNDLE="${DIST_DIR}/${APP_NAME}.app"
DMG_NAME="${APP_NAME}-${APP_VERSION}-${RID}.dmg"

# 资源路径
INFO_PLIST="${SCRIPT_DIR}/Info.plist"
ICON_SRC_PNG="${ROOT_DIR}/Assets/Images/StartBoxIcon1024.png"

cd "${SCRIPT_DIR}"

# ---- 1. 清理 ----
rm -rf "${DIST_DIR}"
mkdir -p "${DIST_DIR}"

# ---- 2. dotnet publish ----
echo "==> [1/5] dotnet publish (${RID})..."
cd "${ROOT_DIR}"
PUBLISH_FLAGS=(-c Release -r "${RID}" -o "bin/Release/net9.0/${RID}/publish")
if [ -n "${PORTABLE}" ]; then
    PUBLISH_FLAGS+=(--self-contained)
fi
dotnet publish "${PUBLISH_FLAGS[@]}"
cd "${SCRIPT_DIR}"

# 确认 publish 成功
if [ ! -d "${PUBLISH_DIR}" ]; then
    echo "ERROR: publish 目录不存在: ${PUBLISH_DIR}" >&2
    exit 1
fi

# ---- 3. 生成 .icns 图标 ----
echo "==> [2/5] 生成 .icns 图标..."
ICONSET_DIR="${DIST_DIR}/StartBox.iconset"
mkdir -p "${ICONSET_DIR}"

if [ -f "${ICON_SRC_PNG}" ]; then
    # 用 sips 从单张 png 生成全套尺寸。
    # 源 png 必须是 1024x1024+ 才能保证所有尺寸清晰。
    for spec in "16:16" "32:32" "32:16@2x" "64:64" "128:128" "256:256" "256:128@2x" "512:512" "512:256@2x" "1024:1024" "1024:512@2x"; do
        size="${spec%:*}"
        suffix="${spec#*:}"
        if [[ "${size}" == *"@"* ]]; then
            base="${size%@*}"
            scale="${size#*@}"
            actual=$((base * scale))
        else
            actual="${size}"
        fi
        out="${ICONSET_DIR}/icon_${size}.png"
        sips -z "${actual}" "${actual}" "${ICON_SRC_PNG}" --out "${out}" >/dev/null
    done
    iconutil -c icns "${ICONSET_DIR}" -o "${DIST_DIR}/StartBox.icns"
    rm -rf "${ICONSET_DIR}"
else
    echo "WARN: 找不到 ${ICON_SRC_PNG},跳过 .icns 生成(应用会显示默认图标)"
fi

# ---- 4. 组装 .app ----
echo "==> [3/5] 组装 ${APP_NAME}.app..."
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${INFO_PLIST}" "${APP_BUNDLE}/Contents/Info.plist"
[ -f "${DIST_DIR}/StartBox.icns" ] && cp "${DIST_DIR}/StartBox.icns" "${APP_BUNDLE}/Contents/Resources/StartBox.icns"

# 复制 publish 全部内容到 MacOS/
cp -R "${PUBLISH_DIR}/." "${APP_BUNDLE}/Contents/MacOS/"

# 主可执行文件需要可执行权限
chmod +x "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

# ---- 5. 验证 ----
echo "==> [4/5] 验证 .app 结构..."
test -f "${APP_BUNDLE}/Contents/Info.plist" || { echo "ERROR: 缺少 Info.plist"; exit 1; }
test -x "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}" || { echo "ERROR: 主可执行文件不可执行"; exit 1; }

echo "    .app 结构:"
find "${APP_BUNDLE}" -maxdepth 3 -type d | sed 's|^|      |'

# ---- 6. 打包成 .dmg ----
echo "==> [5/5] 生成 .dmg..."
DMG_PATH="${DIST_DIR}/${DMG_NAME}"
TMP_DMG="${DIST_DIR}/tmp.dmg"

# 用 hdiutil (macOS 自带) 创建只读 dmg
# 步骤: 创建空 dmg -> 挂载 -> 复制 .app -> 卸载 -> 转只读
hdiutil create -size 200m -fs HFS+ -volname "${APP_DISPLAY_NAME}" "${TMP_DMG}" >/dev/null
MOUNT_DIR=$(hdiutil attach -nobrowse "${TMP_DMG}" | awk '/\/Volumes\// {print $3; exit}')
if [ -z "${MOUNT_DIR}" ]; then
    echo "ERROR: 无法挂载临时 dmg" >&2
    rm -f "${TMP_DMG}"
    exit 1
fi
cp -R "${APP_BUNDLE}" "${MOUNT_DIR}/"
# 软链接 Applications,方便用户拖拽安装
ln -s /Applications "${MOUNT_DIR}/Applications"
hdiutil detach "${MOUNT_DIR}" >/dev/null
hdiutil convert "${TMP_DMG}" -format UDZO -o "${DMG_PATH}" >/dev/null
rm -f "${TMP_DMG}"

# ---- 完成 ----
echo ""
echo "==> 完成 ✅"
echo "    .app: ${SCRIPT_DIR}/${APP_BUNDLE}"
echo "    .dmg: ${SCRIPT_DIR}/${DMG_PATH}"
echo ""
echo "提示:"
echo "  - 测试运行: open '${SCRIPT_DIR}/${APP_BUNDLE}'"
echo "  - 第一次打开可能被 Gatekeeper 拦截,右键 → 打开 即可"
echo "  - 公网分发需做 Apple 公证(notarization),本脚本未做"
