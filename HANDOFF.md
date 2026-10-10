# HANDOFF: Paper Overlay（Paperman風 macOS アプリ）

前セッションからの引き継ぎ資料。新セッションはまずこのファイルを読み、「次にやること」から着手する。

## ゴール

[Paperman](https://paperman.cc/) のような「画面全体に紙の質感を重ねて、光沢・コントラストを和らげる」macOS メニューバー常駐アプリを **Swift** で作る。
製品として出すことも視野に入れ、**Paperman 本家との差別化**を狙う。

## これまでの決定事項

| 決定 | 理由 |
|---|---|
| 言語は **Swift**（Rust ではない） | 本家は Rust でクロスプラットフォーム。対抗するなら Mac 固有機能（App Intents / Focus Filter / WidgetKit / SwiftUI）で勝負する。これらは Swift でしか書けない |
| macOS 専用 | 同上。Windows 対応はしない |
| 非サンドボックス（直接配布）を基本にする | 本家の App Store 版は、サンドボックスの制限で他アプリのフルスクリーン時にテクスチャが効かない。ここも差別化ポイント |

比較検証の成果物（Swift / Rust 両方の MVP と比較結果）: `~/agent-dev/paper-overlay-compare/`
→ 実測では両者とも phys_footprint 16MB・待機 CPU 約 0%。性能差はなし。

## 本家 Paperman の機能（調査結果）

- 紙テクスチャ 9 種（プロシージャル生成、feTurbulence 系）、不透明度 15〜30%
- Desk Lamp モード（暖色の光、6 種のプリセット）
- アプリ除外リスト、特定アプリが前面のとき自動非表示
- 日の出・日没または任意のスケジュール
- マルチモニター、表示するモニターの選択
- バッテリー駆動時の一時停止、数分間のスヌーズ
- クリックスルー、フォーカスを奪わない
- Rust 製、メモリ 25MB 未満、CPU 0% をうたう
- Mac は買い切り（App Store / 直販 / Setapp）、Windows 版は 11.99 ドル

## 差別化の候補（優先度は未確定。ユーザーと相談して決める）

1. **App Intents** — ショートカット.app や Siri から「読書モード ON」「不透明度 25%」を操作できるようにする
2. **Focus Filter** — 集中モード（仕事・読書など）に連動してオン／オフや強さを切り替える
3. **ControlWidget / WidgetKit** — コントロールセンターやメニューから素早く切り替える
4. **コンテンツ適応** — ScreenCaptureKit で画面の明るさを見て、強さを自動調整する（画面収録の権限が必要）
5. **SwiftUI の Mac ネイティブな設定画面**
6. 他アプリのフルスクリーン時にも確実に効く（非サンドボックス版）

## 現状

- `reference/mvp-main.swift` … 比較用に作った単一ファイルの MVP（166 行、`swiftc -O` でビルドでき、動作確認済み）
  - メニューバー常駐（`.accessory`）、📄 メニュー：Enabled / Opacity 15・20・25・30% / Quit
  - 画面ごとに枠なし・透明・クリックスルーの `NSWindow`
  - `level = .screenSaver`、`collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]`、`sharingType = .none`
  - 256px のシームレスなタイルを起動時に 1 回生成（xorshift64 ＋ 8×8 バリューノイズ ＋ 粒子）し、`NSColor(patternImage:)` で敷き詰める
  - `didChangeScreenParametersNotification` で画面構成の変化に追従
- **まだ本番のプロジェクト構成になっていない。** ここから作り直す。

## 次にやること

1. **プロジェクト構成を決めて作る**
   - 推奨：**XcodeGen**（`/opt/homebrew/bin/xcodegen` がインストール済み）で `project.yml` から Xcode プロジェクトを生成する
     - App Intents や Widget Extension には `.app` バンドルと拡張ターゲットが必要。SwiftPM の単体実行ファイルでは作れない
     - `project.yml` をテキストで管理できるので、git の差分が読みやすい
   - 環境：Xcode 26.6、Swift 6.3.3、macOS 27.0.1（arm64）
   - `LSUIElement = YES`（Dock に表示しない）、Swift 6 の言語モード
2. `reference/mvp-main.swift` を、責務ごとのファイルに分けて移植する
   - 案：`TextureGenerator` / `OverlayController` / `MenuBarController`（SwiftUI の `MenuBarExtra` を検討）/ `Settings`（`@AppStorage`）
3. 設定の保存（不透明度、オン／オフ）
4. アプリ除外リスト（`NSWorkspace.didActivateApplicationNotification`）
5. 差別化機能の 1 つめ（ユーザーと相談。1 の App Intents が最も手軽で効果が大きい見込み）

## ハマりどころ・メモ

- Swift 6 では、トップレベルのコードは MainActor に分離されない。`@MainActor` なクラスを生成するときは `MainActor.assumeIsolated { ... }` で包むか、`@main` を使う
- `sharingType = .none` にしているので、**スクリーンショットにオーバーレイが写らない**。見た目の確認はユーザーに頼むか、デバッグ時だけ `.readOnly` にする
- `level = .screenSaver` は、通知やシステムダイアログより上に表示されることがある。レベルは調整が必要かもしれない
- テクスチャの質感（粒度、繊維の方向、乗算かオーバーレイかの合成方法）が製品価値の大部分を占める。ここは時間をかけて詰める
- 画面収録・アクセシビリティの権限は、コンテンツ適応（候補 4）をやらない限り不要

## ユーザーについて

- ターミナルコマンドを実行するときは、**日本語でコマンドの解説**をつける（グローバルの CLAUDE.md のルール）
- 試作アプリは `~/agent-dev/` の直下にディレクトリを作る
- 学習にも関心がある。実装を選んだ理由を簡単に説明すると喜ばれる
