import AppKit

// Renders a pixel-art "PIXELCAT" banner with the app icon.
// Run:  swift tools/make_banner.swift <icon.png> <out.png>

let iconPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "PixelCat/Assets.xcassets/AppIcon.appiconset/icon_512.png"
let outPath  = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "docs/banner.png"

func col(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    NSColor(srgbRed: r, green: g, blue: b, alpha: a).cgColor
}

// 5×7 pixel font for the letters we need.
let font: [Character: [String]] = [
    "P": ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
    "I": ["11111", "00100", "00100", "00100", "00100", "00100", "11111"],
    "X": ["10001", "10001", "01010", "00100", "01010", "10001", "10001"],
    "E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
    "L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
    "C": ["01111", "10000", "10000", "10000", "10000", "10000", "01111"],
    "A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
    "T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
]

let W = 1320, H = 500
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: W, pixelsHigh: H,
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
let gctx = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = gctx
let ctx = gctx.cgContext

// Rounded background with peach→cream gradient.
let bg = CGRect(x: 0, y: 0, width: CGFloat(W), height: CGFloat(H))
let bgPath = CGPath(roundedRect: bg, cornerWidth: 36, cornerHeight: 36, transform: nil)
ctx.saveGState(); ctx.addPath(bgPath); ctx.clip()
let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                      colors: [col(1.0, 0.80, 0.55), col(1.0, 0.93, 0.82)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: CGFloat(H)), end: CGPoint(x: 0, y: 0), options: [])
ctx.restoreGState()

let ink = col(0.27, 0.21, 0.19)
let shadow = col(0.80, 0.55, 0.38)

// Draw a word starting at top-left (tx, topY in CG coords where larger y = up).
func drawWord(_ word: String, tx: CGFloat, topY: CGFloat, cell: CGFloat) {
    func draw(_ color: CGColor, _ ox: CGFloat, _ oy: CGFloat) {
        var x = tx
        ctx.setFillColor(color)
        for ch in word {
            if let g = font[ch] {
                for (r, row) in g.enumerated() {
                    for (c, p) in row.enumerated() where p == "1" {
                        let rect = CGRect(x: x + CGFloat(c) * cell + ox,
                                          y: topY - CGFloat(r + 1) * cell + oy,
                                          width: cell, height: cell)
                        ctx.fill(rect)
                    }
                }
            }
            x += 6 * cell   // 5 wide + 1 gap
        }
    }
    draw(shadow, 7, -7)   // drop shadow
    draw(ink, 0, 0)
}

// Cat icon on the left.
if let img = NSImage(contentsOfFile: iconPath),
   let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) {
    let side: CGFloat = 360
    ctx.draw(cg, in: CGRect(x: 56, y: (CGFloat(H) - side) / 2, width: side, height: side))
}

// "PIXEL" over "CAT" on the right.
let cell: CGFloat = 28
let textX: CGFloat = 500
// Two lines, vertically centred: block height = 2*(7*cell) + gap.
let lineH = 7 * cell
let gap: CGFloat = 40
let topLineY = (CGFloat(H) + (2 * lineH + gap)) / 2   // top edge of PIXEL
drawWord("PIXEL", tx: textX, topY: topLineY, cell: cell)
drawWord("CAT",   tx: textX, topY: topLineY - lineH - gap, cell: cell)

NSGraphicsContext.restoreGraphicsState()

let data = rep.representation(using: .png, properties: [:])!
try! FileManager.default.createDirectory(atPath: (outPath as NSString).deletingLastPathComponent,
                                         withIntermediateDirectories: true)
try! data.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)")
