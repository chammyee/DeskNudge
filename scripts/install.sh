#!/bin/bash
# One-line install:
#   curl -fsSL https://raw.githubusercontent.com/chammyee/DeskNudge/main/scripts/install.sh | bash
set -euo pipefail

REPO="chammyee/DeskNudge"
APP="Notipop.app"

if [ "$(uname -m)" != "arm64" ]; then
  echo "Notipop는 Apple Silicon(M1 이상) 전용입니다." >&2
  exit 1
fi

echo "최신 버전 확인 중…"
TAG=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
      | grep -m1 '"tag_name"' | cut -d'"' -f4)
[ -n "$TAG" ] || { echo "릴리스를 찾을 수 없습니다." >&2; exit 1; }

URL="https://github.com/$REPO/releases/download/$TAG/Notipop-$TAG.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "다운로드: Notipop $TAG"
curl -fsSL "$URL" -o "$TMP/Notipop.zip"
ditto -x -k "$TMP/Notipop.zip" "$TMP"

# curl 다운로드는 quarantine가 안 붙지만, 혹시 몰라 제거
pkill -x Notipop 2>/dev/null || true
rm -rf "/Applications/$APP"
mv "$TMP/$APP" "/Applications/$APP"
xattr -dr com.apple.quarantine "/Applications/$APP" 2>/dev/null || true

open "/Applications/$APP"
echo "✓ 설치 완료 — 메뉴바에 Notipop 아이콘이 생깁니다. (설정·이미지는 유지됩니다)"
