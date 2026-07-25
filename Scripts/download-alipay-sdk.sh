#!/bin/bash
# 下载支付宝 AlipaySDK XCFramework 到 LocalPackages（需能访问支付宝 CDN）
# 官方文档：https://opendocs.alipay.com/open/54/104509
#
# 兼容性（已核对）：
# - 本工程 IPHONEOS_DEPLOYMENT_TARGET = 16.2
# - 脚本默认 AlipaySDK 15.8.40 XCFramework（含 ios-arm64 + ios-arm64_x86_64-simulator）
# - 支持 auth_v2 登录；官方基线远低于 iOS 16，可用于当前 App
# - 若与微信等三方库出现 utdid 符号冲突，改用 VARIANT=NoUtdid
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/LocalPackages/AlipaySDK/Frameworks"
# XCFramework：真机 arm64 + 模拟器 arm64/x86_64；适合本工程在 Apple Silicon / Intel 模拟器调试
ZIP_URL="https://mdn.alipayobjects.com/portal_mdssth/afts/file/A*XwdvTYbfKEYAAAAAgGAAAAgAAQAAAQ/AlipaySDK-XCFramework-15.8.40.1.zip"
# Standard（默认）| NoUtdid（与其它 SDK 的 utdid 冲突时使用）
VARIANT="${VARIANT:-Standard}"
TMP="$(mktemp -d)"

cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

mkdir -p "$DEST"
echo "Downloading AlipaySDK XCFramework (variant=${VARIANT})..."
curl -fsSL --http1.1 "$ZIP_URL" -o "$TMP/alipay.zip"
unzip -q "$TMP/alipay.zip" -d "$TMP"

FRAMEWORK=""
if [[ -d "$TMP/${VARIANT}/AlipaySDK.xcframework" ]]; then
  FRAMEWORK="$TMP/${VARIANT}/AlipaySDK.xcframework"
else
  # 回退：优先 Standard，再任意 xcframework
  FRAMEWORK="$(find "$TMP" -type d -path '*/Standard/AlipaySDK.xcframework' | head -n 1)"
  if [[ -z "$FRAMEWORK" ]]; then
    FRAMEWORK="$(find "$TMP" -type d -name 'AlipaySDK.xcframework' | head -n 1)"
  fi
fi

if [[ -z "$FRAMEWORK" ]]; then
  echo "ERROR: AlipaySDK.xcframework not found in zip." >&2
  exit 1
fi

rm -rf "$DEST/AlipaySDK.xcframework"
cp -R "$FRAMEWORK" "$DEST/AlipaySDK.xcframework"
echo "Installed: $DEST/AlipaySDK.xcframework"
echo "Slices: ios-arm64 (device), ios-arm64_x86_64-simulator"
echo "Note: AlipaySDK 为静态库，请 Link（Do Not Embed），并把 AlipaySDK.bundle 加入 Copy Bundle Resources。"
echo "Next: 确保可 #import <AlipaySDK/AlipaySDK.h>"
