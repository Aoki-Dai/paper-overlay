#!/bin/zsh
# リリース用スクリプト
#
# 使い方：
#   scripts/release.sh            # ビルドして dist/ に zip を作るだけ
#   scripts/release.sh --publish  # さらに GitHub Releases に v<バージョン> として公開する
#
# バージョンは project.yml の MARKETING_VERSION から読む。
# 今は Developer ID がないので、署名はアドホック（"-"）のまま配る。
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION=$(sed -n 's/^ *MARKETING_VERSION: *"\(.*\)"/\1/p' project.yml)
[[ -n "$VERSION" ]] || { echo "project.yml から MARKETING_VERSION を読めませんでした" >&2; exit 1; }
TAG="v$VERSION"
ZIP="dist/PaperOverlay-$VERSION.zip"

echo "== Paper Overlay $VERSION をビルドします"
xcodegen generate --quiet
xcodebuild -project PaperOverlay.xcodeproj -scheme PaperOverlay -configuration Release \
  -destination 'generic/platform=macOS' -derivedDataPath build/release \
  ONLY_ACTIVE_ARCH=NO clean build | grep -E "error:|warning:|\*\* " || true

APP=build/release/Build/Products/Release/PaperOverlay.app
[[ -d "$APP" ]] || { echo "ビルドに失敗しました" >&2; exit 1; }

echo "== 対応 CPU: $(lipo -archs "$APP/Contents/MacOS/PaperOverlay")"
codesign --verify --deep --strict "$APP"

mkdir -p dist
rm -f "$ZIP"
# ditto はアプリの属性やシンボリックリンクを保ったまま zip にできる（Finder の「圧縮」と同じ）
ditto -c -k --keepParent "$APP" "$ZIP"
SHA=$(shasum -a 256 "$ZIP" | cut -d' ' -f1)
echo "== $ZIP"
echo "   sha256: $SHA"

if [[ "${1:-}" == "--publish" ]]; then
  git diff --quiet && git diff --cached --quiet || { echo "コミットしていない変更があります" >&2; exit 1; }
  git push origin HEAD
  gh release create "$TAG" "$ZIP" --title "Paper Overlay $VERSION" --notes-file - <<EOF
## インストール

\`\`\`bash
brew install --cask aoki-dai/tap/paper-overlay
\`\`\`

または、\`PaperOverlay-$VERSION.zip\` をダウンロードして展開し、\`PaperOverlay.app\` を「アプリケーション」フォルダに入れてください。

## 初めて開くとき

このアプリは Apple の Developer ID で署名していないため、最初は macOS に開くのを止められます。
一度開こうとしたあと、「システム設定」→「プライバシーとセキュリティ」の下のほうにある「このまま開く」を押してください。

sha256: \`$SHA\`
EOF
  echo "== 公開しました: $(gh release view "$TAG" --json url -q .url)"
  echo "   cask の version を $VERSION、sha256 を $SHA に更新してください"
fi
