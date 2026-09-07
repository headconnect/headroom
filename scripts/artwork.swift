// Draws the app icon and the DMG background. Run via `make artwork`.
//   swift scripts/artwork.swift <output dir>
import AppKit

let outDir = CommandLine.arguments.dropFirst().first ?? "build/artwork"
try FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

/// Renders `draw` on a `width`×`height` point canvas at `scale` and writes a PNG.
func render(_ name: String, width: CGFloat, height: CGFloat, scale: CGFloat, _ draw: (CGContext) -> Void) throws {
    let context = CGContext(data: nil, width: Int(width * scale), height: Int(height * scale), bitsPerComponent: 8,
                            bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.scaleBy(x: scale, y: scale)
    draw(context)
    let rep = NSBitmapImageRep(cgImage: context.makeImage()!)
    try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(outDir)/\(name).png"))
}

// MARK: Icon: three usage bars on a dark tile, in the popover's traffic-light colours.

func drawIcon(_ ctx: CGContext, size: CGFloat) {
    let unit = size / 1024
    ctx.scaleBy(x: unit, y: unit)
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let tilePath = CGPath(roundedRect: tile, cornerWidth: 186, cornerHeight: 186, transform: nil)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 24, color: rgb(0x000000, 0.35))
    ctx.addPath(tilePath)
    ctx.setFillColor(rgb(0x1B2540))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(tilePath)
    ctx.clip()
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                              colors: [rgb(0x2C3D66), rgb(0x141C31)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
    ctx.restoreGState()

    let bars: [(fill: CGFloat, color: UInt32)] = [(0.28, 0x34C759), (0.66, 0xFF9F0A), (0.9, 0xFF453A)]
    let barWidth: CGFloat = 520, barHeight: CGFloat = 80, gap: CGFloat = 48
    let x = (1024 - barWidth) / 2
    var y = (1024 + CGFloat(bars.count) * barHeight + CGFloat(bars.count - 1) * gap) / 2 - barHeight
    for bar in bars {
        let track = CGRect(x: x, y: y, width: barWidth, height: barHeight)
        ctx.addPath(CGPath(roundedRect: track, cornerWidth: barHeight / 2, cornerHeight: barHeight / 2, transform: nil))
        ctx.setFillColor(rgb(0xFFFFFF, 0.16))
        ctx.fillPath()
        let fill = CGRect(x: x, y: y, width: max(barHeight, barWidth * bar.fill), height: barHeight)
        ctx.addPath(CGPath(roundedRect: fill, cornerWidth: barHeight / 2, cornerHeight: barHeight / 2, transform: nil))
        ctx.setFillColor(rgb(bar.color))
        ctx.fillPath()
        y -= barHeight + gap
    }
}

for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(size)x\(size)" + (scale == 2 ? "@2x" : "")
        try render(name, width: CGFloat(size), height: CGFloat(size), scale: CGFloat(scale)) { drawIcon($0, size: CGFloat(size)) }
    }
}

// MARK: DMG background: arrow from the app to the Applications folder, with instructions.

let dmgWidth: CGFloat = 660, dmgHeight: CGFloat = 400

func drawText(_ ctx: CGContext, _ text: String, size: CGFloat, weight: NSFont.Weight, color: UInt32, centerX: CGFloat, y: CGFloat) {
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: NSColor(cgColor: rgb(color))!,
    ]
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
    let width = CTLineGetTypographicBounds(line, nil, nil, nil)
    ctx.textPosition = CGPoint(x: centerX - width / 2, y: y)
    CTLineDraw(line, ctx)
}

func drawBackground(_ ctx: CGContext) {
    ctx.setFillColor(rgb(0xF5F5F7))
    ctx.fill(CGRect(x: 0, y: 0, width: dmgWidth, height: dmgHeight))

    // Icons sit at (165, 175) and (495, 175) from the top-left, 128 pt wide.
    let y = dmgHeight - 175
    ctx.setStrokeColor(rgb(0xA0A0A8))
    ctx.setLineWidth(4)
    ctx.setLineCap(.round)
    ctx.move(to: CGPoint(x: 258, y: y))
    ctx.addLine(to: CGPoint(x: 398, y: y))
    ctx.strokePath()
    ctx.move(to: CGPoint(x: 380, y: y + 16))
    ctx.addLine(to: CGPoint(x: 402, y: y))
    ctx.addLine(to: CGPoint(x: 380, y: y - 16))
    ctx.strokePath()

    drawText(ctx, "Drag Range Anxiety into the Applications folder to install it.", size: 15, weight: .medium, color: 0x3A3A3C,
             centerX: dmgWidth / 2, y: 86)
    drawText(ctx, "Then open it from Applications or Spotlight; it lives in the menu bar.", size: 12, weight: .regular,
             color: 0x8A8A8E, centerX: dmgWidth / 2, y: 62)
}

try render("dmg-background", width: dmgWidth, height: dmgHeight, scale: 1, drawBackground)
try render("dmg-background@2x", width: dmgWidth, height: dmgHeight, scale: 2, drawBackground)
