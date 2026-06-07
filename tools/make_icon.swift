import AppKit

// Generates a 1024×1024 PNG of a cute cat-face app icon using the app's palette.
// Run:  swift tools/make_icon.swift <output.png>

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"
let S: CGFloat = 1024

func col(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    NSColor(srgbRed: r, green: g, blue: b, alpha: a).cgColor
}

let ink   = col(0.27, 0.21, 0.19)
let cream = col(0.99, 0.95, 0.88)
let pink  = col(0.96, 0.69, 0.69)
let eyeDk = col(0.20, 0.16, 0.15)
let white = col(1.0, 1.0, 1.0)

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(S), pixelsHigh: Int(S),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
let gctx = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = gctx
let ctx = gctx.cgContext

// Rounded-square background with a warm peach→cream gradient.
let m: CGFloat = 0.04 * S
let bgRect = CGRect(x: m, y: m, width: S - 2 * m, height: S - 2 * m)
let bgPath = CGPath(roundedRect: bgRect, cornerWidth: 0.2 * bgRect.width, cornerHeight: 0.2 * bgRect.width, transform: nil)
ctx.saveGState()
ctx.addPath(bgPath)
ctx.clip()
let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                      colors: [col(1.0, 0.80, 0.55), col(1.0, 0.93, 0.82)] as CFArray,
                      locations: [0, 1])!
ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: S), end: CGPoint(x: 0, y: 0), options: [])
ctx.restoreGState()

let lw: CGFloat = 0.022 * S
ctx.setLineWidth(lw)
ctx.setLineJoin(.round)
ctx.setLineCap(.round)

func fillStroke(_ path: CGPath, _ fill: CGColor) {
    ctx.addPath(path); ctx.setFillColor(fill); ctx.fillPath()
    ctx.addPath(path); ctx.setStrokeColor(ink); ctx.strokePath()
}
func tri(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> CGPath {
    let p = CGMutablePath(); p.move(to: a); p.addLine(to: b); p.addLine(to: c); p.closeSubpath(); return p
}

// Ears (drawn first, behind the head).
fillStroke(tri(CGPoint(x: 0.30 * S, y: 0.62 * S), CGPoint(x: 0.34 * S, y: 0.86 * S), CGPoint(x: 0.50 * S, y: 0.68 * S)), cream)
fillStroke(tri(CGPoint(x: 0.70 * S, y: 0.62 * S), CGPoint(x: 0.66 * S, y: 0.86 * S), CGPoint(x: 0.50 * S, y: 0.68 * S)), cream)
// Inner ears
ctx.addPath(tri(CGPoint(x: 0.35 * S, y: 0.64 * S), CGPoint(x: 0.37 * S, y: 0.78 * S), CGPoint(x: 0.45 * S, y: 0.67 * S))); ctx.setFillColor(pink); ctx.fillPath()
ctx.addPath(tri(CGPoint(x: 0.65 * S, y: 0.64 * S), CGPoint(x: 0.63 * S, y: 0.78 * S), CGPoint(x: 0.55 * S, y: 0.67 * S))); ctx.setFillColor(pink); ctx.fillPath()

// Head.
let headRect = CGRect(x: 0.24 * S, y: 0.20 * S, width: 0.52 * S, height: 0.46 * S)
fillStroke(CGPath(roundedRect: headRect, cornerWidth: 0.18 * S, cornerHeight: 0.18 * S, transform: nil), cream)

// Eyes.
func eye(_ cx: CGFloat) {
    let er = CGRect(x: cx - 0.055 * S, y: 0.40 * S, width: 0.11 * S, height: 0.14 * S)
    ctx.addEllipse(in: er); ctx.setFillColor(eyeDk); ctx.fillPath()
    let hr = CGRect(x: cx - 0.005 * S, y: 0.49 * S, width: 0.035 * S, height: 0.035 * S)
    ctx.addEllipse(in: hr); ctx.setFillColor(white); ctx.fillPath()
}
eye(0.385 * S)
eye(0.615 * S)

// Blush.
for cx in [0.31 * S, 0.69 * S] {
    let br = CGRect(x: cx - 0.045 * S, y: 0.33 * S, width: 0.09 * S, height: 0.05 * S)
    ctx.addEllipse(in: br); ctx.setFillColor(pink); ctx.fillPath()
}

// Nose.
ctx.addPath(tri(CGPoint(x: 0.47 * S, y: 0.40 * S), CGPoint(x: 0.53 * S, y: 0.40 * S), CGPoint(x: 0.50 * S, y: 0.37 * S)))
ctx.setFillColor(pink); ctx.fillPath()

// Mouth (little w).
ctx.setStrokeColor(ink); ctx.setLineWidth(0.016 * S)
var mouth = CGMutablePath()
mouth.move(to: CGPoint(x: 0.50 * S, y: 0.37 * S))
mouth.addLine(to: CGPoint(x: 0.50 * S, y: 0.345 * S))
ctx.addPath(mouth); ctx.strokePath()
for dir in [-1.0, 1.0] as [CGFloat] {
    let p = CGMutablePath()
    p.move(to: CGPoint(x: 0.50 * S, y: 0.345 * S))
    p.addQuadCurve(to: CGPoint(x: 0.50 * S + dir * 0.05 * S, y: 0.345 * S),
                   control: CGPoint(x: 0.50 * S + dir * 0.025 * S, y: 0.315 * S))
    ctx.addPath(p); ctx.strokePath()
}

// Whiskers.
ctx.setLineWidth(0.012 * S)
for dir in [-1.0, 1.0] as [CGFloat] {
    for dy in [0.0, 0.035, -0.035] as [CGFloat] {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 0.50 * S + dir * 0.10 * S, y: (0.40 + dy) * S))
        p.addLine(to: CGPoint(x: 0.50 * S + dir * 0.22 * S, y: (0.41 + dy * 1.4) * S))
        ctx.addPath(p); ctx.strokePath()
    }
}

NSGraphicsContext.restoreGraphicsState()

guard let data = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("failed to encode png\n".data(using: .utf8)!); exit(1)
}
try! data.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)")
