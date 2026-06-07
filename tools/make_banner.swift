import AppKit

// Renders the PixelCat banner.
// Run:  swift tools/make_banner.swift [icon.png] [out.png]

let iconPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "PixelCat/Assets.xcassets/AppIcon.appiconset/icon_512.png"
let outPath  = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "docs/banner.png"

func col(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    NSColor(srgbRed: r, green: g, blue: b, alpha: a).cgColor
}

// 3×5 chunky pixel font — same style as the in-cat timer digits.
let font: [Character: [String]] = [
    "P": ["110", "101", "110", "100", "100"],
    "I": ["111", "010", "010", "010", "111"],
    "X": ["101", "101", "010", "101", "101"],
    "E": ["111", "100", "110", "100", "111"],
    "L": ["100", "100", "100", "100", "111"],
    "C": ["011", "100", "100", "100", "011"],
    "A": ["010", "101", "111", "101", "101"],
    "T": ["111", "010", "010", "010", "010"],
]

let W = 1320, H = 440
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: W, pixelsHigh: H,
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
let gctx = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = gctx
let ctx = gctx.cgContext

// Background: rounded rect, peach→cream gradient.
let bg = CGRect(x: 0, y: 0, width: CGFloat(W), height: CGFloat(H))
let bgPath = CGPath(roundedRect: bg, cornerWidth: 36, cornerHeight: 36, transform: nil)
ctx.saveGState(); ctx.addPath(bgPath); ctx.clip()
let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                      colors: [col(1.0, 0.80, 0.55), col(1.0, 0.93, 0.82)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: CGFloat(H)), end: CGPoint(x: 0, y: 0), options: [])
ctx.restoreGState()

let ink    = col(0.27, 0.21, 0.19)
let shadow = col(0.80, 0.55, 0.38)
let cell: CGFloat = 24      // big cells = chunky pixel art look
let sdx: CGFloat  = 8       // shadow offset
let sdy: CGFloat  = -8

// Draw a single glyph: top-left pixel at (x, topY in CG coords where y increases upward).
func drawGlyph(_ ch: Character, atX x: CGFloat, topY: CGFloat) {
    guard let rows = font[ch] else { return }
    for (r, row) in rows.enumerated() {
        for (c, p) in row.enumerated() where p == "1" {
            ctx.fill(CGRect(x: x + CGFloat(c) * cell,
                            y: topY - CGFloat(r + 1) * cell,
                            width: cell, height: cell))
        }
    }
}

// Draw the full "PIXEL CAT" string. Space = 3-cell gap between words.
func drawText(_ text: String, startX: CGFloat, topY: CGFloat, color: CGColor, ox: CGFloat = 0, oy: CGFloat = 0) {
    ctx.setFillColor(color)
    var x = startX + ox
    for ch in text {
        if ch == " " { x += 3 * cell; continue }
        drawGlyph(ch, atX: x, topY: topY + oy)
        x += 4 * cell   // 3 wide + 1 gap
    }
}

// Cat icon, left side.
if let img = NSImage(contentsOfFile: iconPath),
   let cg  = img.cgImage(forProposedRect: nil, context: nil, hints: nil) {
    let side: CGFloat = 340
    ctx.draw(cg, in: CGRect(x: 56, y: (CGFloat(H) - side) / 2, width: side, height: side))
}

// "PIXEL CAT" centered vertically in the right portion.
// Width: (5+1+3) chars * 4 cells + 3 space cells − 1 trailing gap
//       = 8*4 + 3 − 1 = 34 cells → 34*24 = 816 px, start ~460, end ~1276
let textTop = (CGFloat(H) + 5 * cell) / 2   // vertically centres the 5-row text
let textX: CGFloat = 468

drawText("PIXEL CAT", startX: textX, topY: textTop, color: shadow, ox: sdx, oy: sdy)
drawText("PIXEL CAT", startX: textX, topY: textTop, color: ink)

NSGraphicsContext.restoreGraphicsState()

let data = rep.representation(using: .png, properties: [:])!
try! FileManager.default.createDirectory(atPath: (outPath as NSString).deletingLastPathComponent,
                                         withIntermediateDirectories: true)
try! data.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)")
