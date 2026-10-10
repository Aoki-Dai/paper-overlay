# HANDOFF: Paper Overlay（Paperman 風 macOS アプリ）

セッション間の引き継ぎ資料。新しいセッションはまずこのファイルを読み、「次にやること」から着手する。
最終更新：2026-10-10

## ゴール

[Paperman](https://paperman.cc/) のように「画面全体に紙の質感を重ねて、光沢とコントラストを和らげる」macOS のメニューバー常駐アプリを **Swift** で作る。
製品として出すことも視野に入れ、**Paperman 本家との差別化**を狙う。

## 決定事項

| 決定 | 理由 |
|---|---|
| 言語は **Swift**、**macOS 専用** | 本家は Rust 製でクロスプラットフォーム。こちらは Mac 固有の機能（App Intents、Focus Filter、WidgetKit、SwiftUI）で勝負する |
| **サンドボックスなし**で直接配布（Hardened Runtime は有効） | 本家の App Store 版は、サンドボックスの制限で他アプリのフルスクリーン時に効かない。ここも差別化ポイント |
| **XcodeGen** で `project.yml` からプロジェクトを生成 | `.xcodeproj` は git で管理しない（`xcodegen generate` で作り直す） |
| デプロイ対象は **macOS 26.0** | macOS 27 は Xcode 26.6 に SDK がないため指定できない（SDK は 26.5 まで）。Xcode 27 が出たら上げられる |
| Bundle ID は **`com.d4ok1.PaperOverlay`** | ユーザーの指定 |
| 強さは **0〜100% の尺度**で見せ、実際の不透明度 **0〜30%** に対応させる | 保存するのは実際の不透明度。表示のときだけ換算する（`OverlaySettings.maxOpacity`） |
| **おすすめは「紙・強さ 40%（= 不透明度 12%）」** | ユーザーの指定（2026-10-10 に 50% から変更）。尺度の上限 30% は、以前のお気に入り 15% が真ん中に来るように決めた名残 |
| モニターは「**表示しない**モニター」を UUID で保存する | 新しく接続したモニターには自動で表示される |
| UI の文言は日本語 | 英語化（ローカライズ）は配布準備のときに行う |

## 現状（できていること）

環境：Xcode 26.6、Swift 6.3.3（言語モード 6、strict concurrency complete）、macOS 27.0.1（arm64）、モニター 2 台（Color LCD ＋ DELL S2722QC）

- **オーバーレイ**：画面ごとに、枠なし・透明・クリックスルーの `NSWindow`（`level = .screenSaver`、全スペース、フルスクリーン補助）。画面構成の変化に追従する
- **テクスチャ**（`TextureGenerator`）：feTurbulence（fractalNoise）風に、周期 1〜128px のバリューノイズを重ねる。Retina 解像度のタイル（512px = 256pt）で、平均の明るさは中間調
  - **紙**：暖色、粒が細かく、ゆるく曲がった短い繊維が入る（本数はタイルの面積に比例）
  - **電子ペーパー**：明るい無彩色のグレー、粒はごく弱く、ゆるやかなまだら
- **設定パネル**（`MenuBarExtra` の `.window` スタイル）：オン／オフのスイッチ、見本つきのスタイルカード、強さのスライダーとプリセット（20・40★・60・80・100%）、モニター欄（2 台以上のときだけ）、「おすすめ設定にする」ボタン、設定・終了
- **設定ウインドウ**（⌘,）
  - 「一般」タブ：ログイン時に起動（`SMAppService`）、おすすめ／プリセットの表示切り替え
  - 「モニター」タブ：モニターごとのオン／オフと、**個別の質感**（スタイル・強さ）。個別に設定していないモニターは全体の設定に従う
- **アプリアイコン**：紙色の角丸に端を折った紙。下地に `TextureGenerator` の紙の質感を使う（生成スクリプトはリポジトリ外。作り直すときは同じ方法で描いて `AppIcon.appiconset` に入れる）
- **設定の保存**（`SettingsStore`）：オン／オフ・不透明度・スタイル・除外モニター・モニターごとの質感（JSON）を UserDefaults に保存。範囲外の値や未知のスタイルは既定値に戻す
- **テスト**：Swift Testing で 17 件（テクスチャの決定性・色・明るさ・粒の細かさ、設定の保存と復元、強さの換算、モニターの除外）

### ファイル構成

```
project.yml
PaperOverlay/
  App/PaperOverlayApp.swift        @main、MenuBarExtra と Settings シーン
  Overlay/OverlayController.swift  ウインドウの管理、設定の反映と保存
  Overlay/TextureGenerator.swift   TextureStyle とタイル生成
  Overlay/Displays.swift           モニターの情報と UUID
  Settings/SettingsStore.swift     OverlaySettings と UserDefaults の読み書き
  Settings/UIPreferences.swift     パネルの見せ方の設定キー（@AppStorage）
  Settings/LoginItem.swift         ログイン時の起動
  UI/SettingsPanel.swift           メニューバーのパネル
  UI/SettingsView.swift            設定ウインドウ
PaperOverlayTests/                 Swift Testing
reference/mvp-main.swift           最初の単一ファイル版（参照用。ビルド対象外）
```

## 次にやること

完了：1. プロジェクト構成 → 2. ファイル分割と移植 → 3. 設定の保存（＋設定パネル・設定ウインドウ・モニター選択・ログイン時の起動）

4. **アプリ除外リスト**（特定のアプリが前面のときは自動で隠す）
   1. `NSWorkspace.didActivateApplicationNotification` で前面のアプリの切り替えを検知する
   2. 除外リストにあるアプリなら、一時的にウインドウを隠す（オン／オフの設定は変えない）
   3. 設定ウインドウに「除外するアプリ」タブ：アイコン付きの一覧。追加は「アプリケーション」フォルダか起動中のアプリから。削除もここで
   4. パネルのヘッダーに「一時停止中（Photoshop が前面）」のように理由を出す
   5. Bundle ID の一覧を保存し、テストを書く
5. **一時停止の仕組み**：スヌーズ（数分間だけ消す）、バッテリー駆動中は一時停止。4 の「一時的に隠す」と同じ仕組みにまとめる
6. **スケジュール**：日の出・日の入り、または時刻指定で自動でオン／オフ
7. **差別化機能の 1 つめ**：App Intents（ショートカット.app や Siri から、オン／オフ・強さ・スタイルを操作）が最も手軽で効果が大きい見込み
8. テクスチャの種類を増やす、Desk Lamp モード
9. 配布の改善：英語の UI。Apple Developer Program に登録したら Developer ID 署名と公証（今は登録しない方針）。App Store 版はサンドボックス必須なので、まずフルスクリーンの上に重なるかを実験する

## 本家 Paperman との機能差（2026-10-10 に paperman.cc で確認）

| 本家の機能 | こちら |
|---|---|
| テクスチャ 9 種（Classic Matte、Whisper Weave、Sunbaked Parchment、Saddle Linen、Painter's Press、Mulberry Veil、Vellum Mist、近日公開：Monastic Felt、Carbon Ledger） | △ 2 種（紙、電子ペーパー） |
| Desk Lamp モード（暖色の光。プリセット 6 種：Soft Candlelight、Midnight Oil、Nook Lantern、Gallery Spot、Golden Hour、Quiet Aurora） | ✕ |
| アプリ除外リスト（Photoshop や動画プレーヤーなど） | ✕ → 手順 4 |
| バッテリー駆動時の一時停止 | ✕ → 手順 5 |
| 数分間のスヌーズ | ✕ → 手順 5 |
| スケジュール（日の出・日の入り、または任意の時刻） | ✕ → 手順 6 |
| マルチモニター（全モニターに表示、表示するモニターを選べる） | ✅ |
| 強さの調整（不透明度 15〜30%） | ✅（0〜30% を 0〜100% で表示） |
| クリックスルー、フォーカスを奪わない | ✅ |
| メモリ 25MB 未満、待機時の CPU 0% | ✅ Release 版で phys_footprint 24MB、待機中の CPU 0.0%（2026-10-10、モニター 2 台） |
| 配布：App Store、直販、Setapp | △ GitHub Releases と Homebrew（自分の tap）で配布中。署名なし |

こちらにしかないもの：モニターごとの質感設定、電子ペーパー風スタイル、おすすめ設定ボタン、見本つきのスタイル選択、パネルの見せ方の設定、他アプリのフルスクリーン中にも効く（サンドボックスなし）

## 配布（2026-10-10 から）

- 公開リポジトリ：https://github.com/Aoki-Dai/paper-overlay（MIT）。「Paperman にインスパイアされた非公式プロジェクト」と README に明記
- Homebrew の tap：https://github.com/Aoki-Dai/homebrew-tap（ローカルは `~/agent-dev/homebrew-tap`）
  - インストール：`brew install --cask aoki-dai/tap/paper-overlay`
- **Apple Developer Program には登録しない方針**。アプリはアドホック署名のまま配る。初回は「システム設定 → プライバシーとセキュリティ → このまま開く」が必要（README と cask の caveats に記載）
- リリースの手順
  1. `project.yml` の `MARKETING_VERSION` を上げてコミット
  2. `scripts/release.sh --publish`（ユニバーサル版をビルド → zip → push → `gh release create v<版>`）。最後に sha256 が表示される
  3. `~/agent-dev/homebrew-tap/Casks/paper-overlay.rb` の `version` と `sha256` を書き換えて push
  4. `brew update && brew fetch --cask aoki-dai/tap/paper-overlay` でダウンロードとハッシュを確認
- cask の macOS 要件は `depends_on macos: :tahoe`（Homebrew 7 では `">= :tahoe"` の書き方は非推奨）
- **`brew style` は実行しない**：開発用の gem を `/opt/homebrew/Library/Homebrew/vendor/bundle` に入れようとして途中で失敗し、`json-3.0.2` が Homebrew の Ruby と食い違って `brew tap` や `brew info` が動かなくなった（2026-10-10）。`json-3.0.2` を退避して直した

## 計測（2026-10-10、Release ビルド、モニター 2 台）

**メモリ最適化後：24MB**（30MB → 24MB）。行ったこと：
1. テクスチャ生成の作業領域（2MB × 数枚）を `mmap` で OS から直接借りて `munmap` で返す。malloc の大きな領域は解放後も「Malloc Large (empty)」として 4MB 残っていた
2. 画素を `CGImage` の領域へ直接書き込む。`NSBitmapImageRep` 経由だと、模様にするときに CGImage へもう 1 枚コピーされ、タイルを 2 重に持っていた

比較実験：AppKit だけの最小アプリ 13MB、SwiftUI の `MenuBarExtra` だけ 17MB、最初の MVP 16MB。SwiftUI 自体の上乗せは約 4MB

以下は最適化前の記録：

- phys_footprint：**30MB**（起動 3 秒後も 15 秒後も同じ）。待機中の CPU：**0.0%**（10 秒間）、スレッド 5
- 内訳：Malloc Small 13MB、Malloc Large 4MB、__DATA_DIRTY 2.4MB、CG Image 2.1MB（タイル）、CoreAnimation 2.1MB
- ヒープで生きているオブジェクトは約 9MB。ほとんどが SwiftUI／AppKit の内部（CFString、辞書、SF Symbols の SVG など）
- `malloc_zone_pressure_relief` でテクスチャ生成後のメモリを返す実験は**効果なし**（30MB のまま）。テクスチャ生成の残りではない
- 最初の MVP（AppKit だけ、256px タイル）は 16MB。差の 14MB は主に SwiftUI の `MenuBarExtra` と設定画面の分と考えられる
- さらに減らすなら：パネルを開いたときだけ SwiftUI を作る構成（`NSStatusItem` ＋ `NSPopover`）。効果は未検証。パネルを開いた後のメモリは未計測
- 計測方法：`footprint -p <PID>`（phys_footprint）、`top -l 11 -s 1 -pid <PID> -stats pid,cpu,mem,threads`、`heap <PID>`

## ハマりどころ・メモ

- **このシェルには画面収録の権限がない。** `screencapture` は失敗する。見た目は次の方法で確認する
  - テクスチャ：`TextureGenerator.swift` を `swiftc` で小さなプログラムと一緒にビルドし、白・黒の背景に重ねた結果を PNG に書き出す
  - UI：一時的なテストで、ビューを `NSHostingView` に載せて画面外のウインドウに置き、`cacheDisplay` で PNG に書き出す。確認が終わったらテストは消す
    - `.defaultAppStorage(...)` と `OverlayController(store: SettingsStore(defaults: 使い捨ての UserDefaults))` を使えば、実際の設定を汚さない
    - モニターが複数のときの見た目は、DEBUG ビルド専用の `overrideDisplaysForPreview(_:)` で一覧を差し替えて確かめる。ただし設定を変えると実際の画面で作り直されるので、差し替えは最後にもう一度行う
    - この書き出し方法では、`Capsule` の左右の端が切れる、`TabView` のタブやスイッチの色が描かれない、という違いがある。チップは `RoundedRectangle(cornerRadius: 100)` で描いている
- オーバーレイは DEBUG ビルドだけ `sharingType = .readOnly`（スクリーンショットに写る）。リリースでは `.none`
- `pkill` の直後に `open` すると `-600` で失敗することがある。旧プロセスが終わるのを待ってから起動する
- 履歴を戻す `git checkout <ファイル>` は自動モードで拒否される。取り消すときは編集で戻す
- `UserDefaults` はこの SDK では Sendable ではない。`SettingsStore` は Sendable にしていない
- テストの実行中にログに出る `com.apple.linkd.autoShortcut` の接続エラーと `No AppIntents.framework dependency found` は無視してよい
- `level = .screenSaver` は通知やシステムダイアログより上に表示されることがある。レベルは調整が必要かもしれない
- ログイン項目は、登録したときのアプリの場所を指す。`build/` のデバッグ版で登録すると、そのパスが登録される
- テクスチャの質感が製品価値の大部分を占める。パラメータは `TextureStyle.parameters` にまとまっている

## ユーザーについて

- **応答はすべて日本語**で書く（途中経過の一言や Insight も含む）
- ターミナルコマンドを実行するときは、日本語でコマンドの解説をつける（グローバルの CLAUDE.md のルール）
- 試作アプリは `~/agent-dev/` の直下にディレクトリを作る
- 学習にも関心がある。実装を選んだ理由を簡単に説明すると喜ばれる
- 進捗は、既存の task-progress mod（`~/agent-dev/task-progress`、TaskCreate／TaskUpdate を表示）で見ている。新しく mod を作らない
- 見た目は本家に寄せつつ、モダンで UI/UX の良いものを好む
