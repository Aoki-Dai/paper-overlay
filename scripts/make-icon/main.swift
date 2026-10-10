// アプリアイコンを描くスクリプト
//
// 使い方（プロジェクトのルートで）：
//   swiftc -O -o /tmp/make-icon scripts/make-icon/main.swift PaperOverlay/Overlay/TextureGenerator.swift
//   /tmp/make-icon PaperOverlay/Resources/Assets.xcassets/AppIcon.appiconset
//
// 紙色の角丸の上に端を折った紙を 1 枚置き、下地に TextureGenerator の紙の質感を薄く敷く。
// 16〜1024px の icon_<px>.png を書き出す（AppIcon.appiconset/Contents.json がこのファイル名を参照している）。

import AppKit

// macOS のアイコンの決まり：1024px の画面、本体は 824px の角丸の正方形（余白 100px、角の半径 185px）
let canvas = 1024
func color(_ hex: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

func paperTile(_ style: TextureStyle) -> NSImage {
    let size = 512
    let px = TextureGenerator.pixels(size: size, style: style)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: size * 4, bitsPerPixel: 32)!
    px.withUnsafeBufferPointer { rep.bitmapData!.update(from: $0.baseAddress!, count: $0.count) }
    let image = NSImage(size: NSSize(width: size, height: size)); image.addRepresentation(rep); return image
}

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: canvas, pixelsHigh: canvas, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: canvas * 4, bitsPerPixel: 32)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

let body = NSRect(x: 100, y: 100, width: 824, height: 824)
let bodyPath = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)

// 1. 本体の影
NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow(); shadow.shadowColor = color(0x000000, 0.28); shadow.shadowOffset = NSSize(width: 0, height: -10); shadow.shadowBlurRadius = 24; shadow.set()
color(0xE9DCC4).setFill(); bodyPath.fill()
NSGraphicsContext.restoreGraphicsState()

// 2. 本体：暖かい紙色のグラデーション
NSGraphicsContext.saveGraphicsState()
bodyPath.addClip()
NSGradient(colors: [color(0xF1E3C8), color(0xD9B98C)])!.draw(in: body, angle: -90)
// 3. 本物の紙テクスチャを薄く重ねる
color(0x000000, 0).setFill()
ctx.setAlpha(0.22)
ctx.setBlendMode(.multiply)
NSColor(patternImage: paperTile(.paper)).setFill(); body.fill()
ctx.setAlpha(1); ctx.setBlendMode(.normal)
// 上からの柔らかい光
NSGradient(colors: [color(0xFFFFFF, 0.35), color(0xFFFFFF, 0)])!.draw(in: NSRect(x: 100, y: 524, width: 824, height: 400), angle: -90)
NSGraphicsContext.restoreGraphicsState()

// 4. 端を折った紙 1 枚（少し傾ける）
NSGraphicsContext.saveGraphicsState()
let transform = NSAffineTransform()
transform.translateX(by: 512, yBy: 500); transform.rotate(byDegrees: -5); transform.concat()
let w: CGFloat = 430, h: CGFloat = 540, fold: CGFloat = 112
let sheet = NSBezierPath()
sheet.move(to: NSPoint(x: -w / 2, y: -h / 2))
sheet.line(to: NSPoint(x: w / 2, y: -h / 2))
sheet.line(to: NSPoint(x: w / 2, y: h / 2 - fold))
sheet.line(to: NSPoint(x: w / 2 - fold, y: h / 2))
sheet.line(to: NSPoint(x: -w / 2, y: h / 2))
sheet.close()
NSGraphicsContext.saveGraphicsState()
let sheetShadow = NSShadow(); sheetShadow.shadowColor = color(0x5A3E1C, 0.35); sheetShadow.shadowOffset = NSSize(width: 0, height: -14); sheetShadow.shadowBlurRadius = 30; sheetShadow.set()
color(0xFFFCF5).setFill(); sheet.fill()
NSGraphicsContext.restoreGraphicsState()
// 紙そのものにも質感
NSGraphicsContext.saveGraphicsState()
sheet.addClip()
ctx.setAlpha(0.10); ctx.setBlendMode(.multiply)
NSColor(patternImage: paperTile(.paper)).setFill(); NSRect(x: -w, y: -h, width: 2 * w, height: 2 * h).fill()
ctx.setAlpha(1); ctx.setBlendMode(.normal)
NSGraphicsContext.restoreGraphicsState()
// 折り返し
let flap = NSBezierPath()
flap.move(to: NSPoint(x: w / 2 - fold, y: h / 2))
flap.line(to: NSPoint(x: w / 2 - fold, y: h / 2 - fold))
flap.line(to: NSPoint(x: w / 2, y: h / 2 - fold))
flap.close()
NSGradient(colors: [color(0xEADBC0), color(0xD7C09A)])!.draw(in: flap, angle: -45)
// 文字の行
color(0xCDB591).setStroke()
for (i, length) in [0.74, 0.62, 0.70, 0.48].enumerated() {
    let line = NSBezierPath()
    let y = h / 2 - 190 - CGFloat(i) * 78
    line.move(to: NSPoint(x: -w / 2 + 64, y: y))
    line.line(to: NSPoint(x: -w / 2 + 64 + (w - 128) * length, y: y))
    line.lineWidth = 26; line.lineCapStyle = .round; line.stroke()
}
NSGraphicsContext.restoreGraphicsState()

NSGraphicsContext.restoreGraphicsState()

// 全サイズを書き出す
let out = CommandLine.arguments[1]
let full = NSImage(size: NSSize(width: canvas, height: canvas)); full.addRepresentation(rep)
for px in [16, 32, 64, 128, 256, 512, 1024] {
    let r = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: px * 4, bitsPerPixel: 32)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: r)
    NSGraphicsContext.current!.imageInterpolation = .high
    full.draw(in: NSRect(x: 0, y: 0, width: px, height: px))
    NSGraphicsContext.restoreGraphicsState()
    try! r.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(out)/icon_\(px).png"))
}
