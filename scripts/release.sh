#!/bin/zsh
# リリース用スクリプト
#
# 使い方：
#   scripts/release.sh            # ビルドして dist/ に zip と DMG を作るだけ
#   scripts/release.sh --publish  # さらに GitHub Releases に v<バージョン> として公開する
#   scripts/release.sh --attach   # ビルドし直さず、今あるビルドから DMG を作って
#                                 # 既存の v<バージョン> のリリースに追加する。
#                                 # zip は作り直さない（sha256 が変わると Homebrew の cask と合わなくなるため）
#
# バージョンは project.yml の MARKETING_VERSION から読む。
# 今は Developer ID がないので、署名はアドホック（"-"）のまま配る。
set -euo pipefail

cd "$(dirname "$0")/.."

MODE="${1:-}"
VERSION=$(sed -n 's/^ *MARKETING_VERSION: *"\(.*\)"/\1/p' project.yml)
[[ -n "$VERSION" ]] || { echo "project.yml から MARKETING_VERSION を読めませんでした" >&2; exit 1; }
TAG="v$VERSION"
APP=build/release/Build/Products/Release/PaperOverlay.app
ZIP="dist/PaperOverlay-$VERSION.zip"
DMG="dist/PaperOverlay-$VERSION.dmg"

if [[ "$MODE" != "--attach" ]]; then
  echo "== Paper Overlay $VERSION をビルドします"
  xcodegen generate --quiet
  xcodebuild -project PaperOverlay.xcodeproj -scheme PaperOverlay -configuration Release \
    -destination 'generic/platform=macOS' -derivedDataPath build/release \
    ONLY_ACTIVE_ARCH=NO clean build | grep -E "error:|warning:|\*\* " || true
fi

[[ -d "$APP" ]] || { echo "ビルドがありません: $APP" >&2; exit 1; }
BUILT=$(defaults read "$PWD/$APP/Contents/Info" CFBundleShortVersionString)
[[ "$BUILT" == "$VERSION" ]] || { echo "ビルドのバージョン（$BUILT）が project.yml（$VERSION）と違います" >&2; exit 1; }

echo "== 対応 CPU: $(lipo -archs "$APP/Contents/MacOS/PaperOverlay")"
codesign --verify --deep --strict "$APP"

mkdir -p dist

# zip：Homebrew の cask が使う。ditto はアプリの属性を保ったまま固められる（Finder の「圧縮」と同じ）
if [[ "$MODE" == "--attach" ]]; then
  [[ -f "$ZIP" ]] || { echo "公開済みの zip がありません: $ZIP" >&2; exit 1; }
else
  rm -f "$ZIP"
  ditto -c -k --keepParent "$APP" "$ZIP"
fi

# DMG：開くとアプリと「アプリケーション」フォルダへのショートカットが並び、ドラッグで入れられる
STAGING=$(mktemp -d)
trap 'rm -rf "$STAGING"' EXIT
ditto "$APP" "$STAGING/PaperOverlay.app"
ln -s /Applications "$STAGING/Applications"
rm -f "$DMG"
hdiutil create -quiet -volname "Paper Overlay" -srcfolder "$STAGING" -fs HFS+ -format UDZO -ov "$DMG"
hdiutil verify -quiet "$DMG"

ZIP_SHA=$(shasum -a 256 "$ZIP" | cut -d' ' -f1)
DMG_SHA=$(shasum -a 256 "$DMG" | cut -d' ' -f1)
echo "== $ZIP"
echo "   sha256: $ZIP_SHA"
echo "== $DMG"
echo "   sha256: $DMG_SHA"

notes() {
  cat <<EOF
## インストール

- **Homebrew**：\`brew install --cask aoki-dai/tap/paper-overlay\`
- **DMG**：\`PaperOverlay-$VERSION.dmg\` を開き、\`PaperOverlay.app\` を「Applications」フォルダへドラッグしてください
- **zip**：\`PaperOverlay-$VERSION.zip\` を展開し、\`PaperOverlay.app\` を「アプリケーション」フォルダへ入れてください

## 初めて開くとき

このアプリは Apple の Developer ID で署名していないため、最初は macOS に開くのを止められます。
一度開こうとしたあと、「システム設定」→「プライバシーとセキュリティ」の下のほうにある「このまま開く」を押してください。

## sha256

- \`PaperOverlay-$VERSION.zip\`: \`$ZIP_SHA\`
- \`PaperOverlay-$VERSION.dmg\`: \`$DMG_SHA\`
EOF
}

case "$MODE" in
  --publish)
    git diff --quiet && git diff --cached --quiet || { echo "コミットしていない変更があります" >&2; exit 1; }
    git push origin HEAD
    notes | gh release create "$TAG" "$ZIP" "$DMG" --title "Paper Overlay $VERSION" --notes-file -
    echo "== 公開しました: $(gh release view "$TAG" --json url -q .url)"
    echo "   cask の version を $VERSION、sha256 を $ZIP_SHA に更新してください"
    ;;
  --attach)
    gh release upload "$TAG" "$DMG" --clobber
    notes | gh release edit "$TAG" --notes-file -
    echo "== $TAG に追加しました: $(gh release view "$TAG" --json url -q .url)"
    ;;
esac
