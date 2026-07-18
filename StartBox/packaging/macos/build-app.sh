#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# StartBox macOS 打包脚本
# 把 dotnet publish 产物组装成 .app,再打成 .dmg
#
# 用法:
#   ./build-app.sh                          # 用本机架构(自动探测),默认配置
#   ./build-app.sh arm64                    # Apple Silicon
#   ./build-app.sh x64                      # Intel
#   ./build-app.sh osx-arm64 PORTABLE=1     # 自包含发布(分发给用户)
#   VERSION=1.2.3 ./build-app.sh            # 覆盖版本号
#   CODESIGN_IDENTITY="Developer ID Application: ACME (XXXXXXXXXX)" ./build-app.sh
#
# 产物:
#   packaging/macos/dist/StartBox.app
#   packaging/macos/dist/StartBox-<VERSION>-<RID>.dmg
#
# 依赖(macOS 自带):
#   - dotnet 9 SDK
#   - sips / iconutil / hdiutil
#
# 不做 Apple 公证(notarization)。
# 公网分发强烈建议配合 Developer ID 签名 + 公证。
# -----------------------------------------------------------------------------

set -euo pipefail

# ---- 路径与基础配置 ----
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

APP_NAME="StartBox"
APP_DISPLAY_NAME="StartBox"
APP_BUNDLE_ID="com.wwnnl.startbox"
VERSION="${VERSION:-1.0.0}"
PORTABLE="${PORTABLE:-}"
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:-}"   # 留空 = 不签名

# RID 解析:支持简写 (arm64 / x64) 与完整 RID (osx-arm64 / osx-x64)
ARG_RID="${1:-}"
if [ -z "${ARG_RID}" ]; then
    case "$(uname -m)" in
        arm64)  RID="osx-arm64" ;;
        x86_64) RID="osx-x64"   ;;
        *)      RID="osx-arm64" ;;
    esac
elif [[ "${ARG_RID}" == arm64 ]]; then
    RID="osx-arm64"
elif [[ "${ARG_RID}" == x64 ]]; then
    RID="osx-x64"
else
    RID="${ARG_RID}"
fi

PUBLISH_DIR="${ROOT_DIR}/bin/Release/net9.0/${RID}/publish"
DIST_DIR="${SCRIPT_DIR}/dist"
APP_BUNDLE="${DIST_DIR}/${APP_NAME}.app"
DMG_NAME="${APP_NAME}-${VERSION}-${RID}.dmg"

INFO_PLIST_SRC="${SCRIPT_DIR}/Info.plist"
INFO_PLIST_TMP="${DIST_DIR}/Info.plist.tmp"
ICON_SRC_PNG="${ROOT_DIR}/Assets/Images/StartBoxIcon1024.png"

cd "${SCRIPT_DIR}"

# ---- 1. 清理 ----
echo "==> [1/7] 清理 dist..."
rm -rf "${DIST_DIR}"
mkdir -p "${DIST_DIR}"

# ---- 2. dotnet publish ----
echo "==> [2/7] dotnet publish (${RID})..."
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

# ---- 3. 生成 Info.plist(注入 VERSION / BUNDLE_ID) ----
echo "==> [3/7] 生成 Info.plist..."
sed -e "s|{{VERSION}}|${VERSION}|g" \
    -e "s|{{BUNDLE_ID}}|${APP_BUNDLE_ID}|g" \
    -e "s|{{COPYRIGHT}}|Copyright © $(date +%Y) wwnnl. All rights reserved.|g" \
    "${INFO_PLIST_SRC}" > "${INFO_PLIST_TMP}"

# 校验关键字段都被替换
if grep -q '{{VERSION}}\|{{BUNDLE_ID}}\|{{COPYRIGHT}}' "${INFO_PLIST_TMP}"; then
    echo "ERROR: Info.plist 还有未替换的占位符" >&2
    grep '{{' "${INFO_PLIST_TMP}" >&2 || true
    exit 1
fi

# ---- 4. 生成 .icns 图标 ----
echo "==> [4/7] 生成 .icns 图标..."
ICONSET_DIR="${DIST_DIR}/StartBox.iconset"
mkdir -p "${ICONSET_DIR}"

if [ -f "${ICON_SRC_PNG}" ]; then
    # Apple iconset 命名规范:icon_<base>x<base>[@2x].png
    # 源 PNG 建议 ≥ 1024×1024 以保证最高位密度清晰。
    declare -a ICON_SPECS=(
        "16x16:16"
        "16x16@2x:32"
        "32x32:32"
        "32x32@2x:64"
        "128x128:128"
        "128x128@2x:256"
        "256x256:256"
        "256x256@2x:512"
        "512x512:512"
        "512x512@2x:1024"
    )
    for spec in "${ICON_SPECS[@]}"; do
        name="${spec%:*}"
        size="${spec##*:}"
        sips -z "${size}" "${size}" "${ICON_SRC_PNG}" \
             --out "${ICONSET_DIR}/icon_${name}.png" >/dev/null
    done
    iconutil -c icns "${ICONSET_DIR}" -o "${DIST_DIR}/StartBox.icns"
    rm -rf "${ICONSET_DIR}"
else
    echo "WARN: 找不到 ${ICON_SRC_PNG},跳过 .icns 生成(应用会显示默认图标)"
fi

# ---- 5. 组装 .app ----
echo "==> [5/7] 组装 ${APP_NAME}.app..."
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${INFO_PLIST_TMP}" "${APP_BUNDLE}/Contents/Info.plist"
[ -f "${DIST_DIR}/StartBox.icns" ] && cp "${DIST_DIR}/StartBox.icns" "${APP_BUNDLE}/Contents/Resources/StartBox.icns"

# PkgInfo:让 lsbom 等工具把它识别为合规的 application bundle
printf 'APPL????' > "${APP_BUNDLE}/Contents/PkgInfo"

# 复制 publish 全部内容到 MacOS/
cp -R "${PUBLISH_DIR}/." "${APP_BUNDLE}/Contents/MacOS/"

# 主可执行文件需要可执行权限
chmod +x "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

# ---- 6. 代码签名(可选) ----
if [ -n "${CODESIGN_IDENTITY}" ]; then
    echo "==> [6/7] 代码签名..."
    # --deep 递归签名所有 dylib / .NET runtime; --options runtime 启用 Hardened Runtime
    codesign --force --deep --options runtime \
             --sign "${CODESIGN_IDENTITY}" \
             "${APP_BUNDLE}"
    codesign --verify --deep --strict --verbose=2 "${APP_BUNDLE}"
else
    echo "==> [6/7] 跳过代码签名 (CODESIGN_IDENTITY 未设置)"
fi

# ---- 7. 验证结构 + 打包 .dmg ----
echo "==> [7/7] 验证并打包 .dmg..."
test -f "${APP_BUNDLE}/Contents/Info.plist" || { echo "ERROR: 缺少 Info.plist"; exit 1; }
test -x "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}" || { echo "ERROR: 主可执行文件不可执行"; exit 1; }

echo "    .app 结构:"
find "${APP_BUNDLE}" -maxdepth 3 -type d | sed 's|^|      |'

DMG_PATH="${DIST_DIR}/${DMG_NAME}"
TMP_DMG="${DIST_DIR}/tmp.dmg"

# 400 MB 足以容纳自包含 .NET 运行时(约 170 MB)+ Avalonia 资源。
# APFS 兼容性 macOS 10.13+,与 LSMinimumSystemVersion=11.0 一致。
hdiutil create -size 400m -fs APFS -volname "${APP_DISPLAY_NAME}" "${TMP_DMG}" >/dev/null
MOUNT_DIR=$(hdiutil attach -nobrowse "${TMP_DMG}" | awk '/\/Volumes\// {print $3; exit}')
if [ -z "${MOUNT_DIR}" ]; then
    echo "ERROR: 无法挂载临时 dmg" >&2
    rm -f "${TMP_DMG}"
    exit 1
fi
cp -R "${APP_BUNDLE}" "${MOUNT_DIR}/"
ln -s /Applications "${MOUNT_DIR}/Applications"
hdiutil detach "${MOUNT_DIR}" >/dev/null
hdiutil convert "${TMP_DMG}" -format UDZO -o "${DMG_PATH}" >/dev/null
rm -f "${TMP_DMG}"

# 生成 SHA256(方便用户校验 / CI 上传)
( cd "${DIST_DIR}" && shasum -a 256 "${DMG_NAME}" > "${DMG_NAME}.sha256" )

# ---- 完成 ----
echo ""
echo "==> 完成 ✅"
echo "    .app: ${SCRIPT_DIR}/${APP_BUNDLE}"
echo "    .dmg: ${SCRIPT_DIR}/${DMG_PATH}"
echo "    sha256: ${SCRIPT_DIR}/${DIST_DIR}/${DMG_NAME}.sha256"
echo ""
echo "提示:"
echo "  - 测试运行: open '${SCRIPT_DIR}/${APP_BUNDLE}'"
echo "  - 第一次打开可能被 Gatekeeper 拦截,右键 → 打开 即可"
echo "  - 公网分发建议先 codesign + Apple 公证,本脚本未做"