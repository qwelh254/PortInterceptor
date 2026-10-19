#!/bin/bash
#
# buildIPA.sh — 在 Mac 上一键生成未签名 IPA（PortInterceptor-unsigned.ipa）
# 用法：终端进入本目录，执行  bash buildIPA.sh
#
set -e

cd "$(dirname "$0")"

echo "▶ 1/4  检查 / 安装 XcodeGen"
if ! command -v xcodegen >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    brew install xcodegen
  else
    echo "未找到 Homebrew，请先安装：https://brew.sh"
    exit 1
  fi
fi

echo "▶ 2/4  生成 Xcode 工程"
xcodegen generate

echo "▶ 3/4  编译 Release 真机包（未签名）"
xcodebuild \
  -project PortInterceptor.xcodeproj \
  -scheme PortInterceptor \
  -configuration Release \
  -sdk iphoneos \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  ONLY_ACTIVE_ARCH=NO \
  build

echo "▶ 4/4  组装 IPA"
rm -rf Payload PortInterceptor-unsigned.ipa
mkdir -p Payload
cp -r build/Build/Products/Release-iphoneos/PortInterceptor.app Payload/
zip -qr PortInterceptor-unsigned.ipa Payload
rm -rf Payload

echo ""
echo "✅ 完成：$(pwd)/PortInterceptor-unsigned.ipa"
echo "   这是未签名 IPA，用 Sideloadly 或 AltStore 用 Apple ID 免费签名后安装。"
