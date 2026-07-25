#!/bin/bash
# 下载微信 Open SDK XCFramework 到 LocalPackages（仅需运行一次，需能访问 GitHub）
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/LocalPackages/WechatOpenSDK/Frameworks"
TAG="2.0.2"
TMP="$(mktemp -d)"

cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

mkdir -p "$DEST"
echo "Downloading WechatOpenSDK ${TAG}..."
curl -fsSL --http1.1 "https://github.com/yanyin1986/WechatOpenSDK/archive/refs/tags/${TAG}.zip" -o "$TMP/wechat.zip"
unzip -q "$TMP/wechat.zip" -d "$TMP"
rm -rf "$DEST/WechatOpenSDK.xcframework"
cp -R "$TMP/WechatOpenSDK-${TAG}/Sources/WechatOpenSDK-XCFramework.xcframework" "$DEST/WechatOpenSDK.xcframework"
echo "Installed: $DEST/WechatOpenSDK.xcframework"
