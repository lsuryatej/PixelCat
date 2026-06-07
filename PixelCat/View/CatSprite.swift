import SwiftUI

/// Procedural pixel-art cat. Everything is drawn on a 32×32 integer cell grid
/// scaled to fill the canvas, so edges stay crisp and blocky. Animation is
/// parametric: breathing, blink, tail flick come from `time`; gaze, mochi
/// deform, heat, hearts, paper, etc. come from `CatState`.
///
/// The cat body is drawn on a transformed copy of the context (mochi / facing /
/// stretch); overlays (hearts, steam, paper, thinking dots) are drawn afterward
/// on the untransformed context so they float in screen space, on top.
enum CatSprite {

    // MARK: Palette
    static let outline  = Color(red: 0.27, green: 0.21, blue: 0.19)
    static let furLight = Color(red: 0.97, green: 0.93, blue: 0.86)
    static let furBase  = Color(red: 0.93, green: 0.87, blue: 0.78)
    static let furShade = Color(red: 0.85, green: 0.77, blue: 0.67)
    static let pink     = Color(red: 0.96, green: 0.69, blue: 0.69)
    static let heartCol = Color(red: 0.95, green: 0.45, blue: 0.55)
    static let eyeWhite = Color(red: 0.99, green: 0.98, blue: 0.96)
    static let heatRed  = Color(red: 0.93, green: 0.42, blue: 0.36)
    static let steamCol = Color(red: 0.78, green: 0.78, blue: 0.80)
    static let paperCol = Color(red: 0.98, green: 0.97, blue: 0.93)

    static let grid: CGFloat = 32

    // MARK: Entry point

    static func draw(in ctx: inout GraphicsContext, size: CGSize, state: CatState, time t: Double) {
        let u = size.width / grid
        let footY = size.height - u * 0.5
        let yShift = footY - 31 * u

        // ---- Cat body (transformed copy) ----
        var c = ctx

        let breath = state.mood == .sleeping
            ? 1 + 0.05 * sin(t * 1.1)
            : 1 + 0.03 * sin(t * 2.3)
        let sx = state.scaleX * (1 + state.stretch * 0.40)
        let sy = state.scaleY * breath * (1 + state.stretch)

        // Kneading bob: the whole body dips in time with the paws.
        let kneadBob = state.mood == .kneading ? CGFloat(abs(sin(t * 12))) * u : 0

        let pivotX = size.width / 2
        let pivotY = footY

        c.translateBy(x: 0, y: yShift - state.lift + kneadBob)
        c.translateBy(x: pivotX, y: pivotY)
        c.rotate(by: .radians(state.wobble))
        c.scaleBy(x: sx, y: sy)
        c.scaleBy(x: state.facing, y: 1)
        c.translateBy(x: -pivotX, y: -pivotY)

        let heat = state.heat
        let body = lerp(furBase, heatRed, heat)
        let bodyLight = lerp(furLight, heatRed, heat * 0.7)
        let bodyShade = lerp(furShade, heatRed, heat)

        // Tail tip sways; an occasional flick speeds it up.
        let flick = (sin(t * 0.7) > 0.93) ? 1.0 : 0.0
        let tailSway = sin(t * (1.6 + flick * 4)) * (1.4 + flick * 1.2)

        // Kneading paws alternate up/down quickly.
        var pawL = 0, pawR = 0
        if state.mood == .kneading {
            let s = sin(t * 12)
            pawL = s > 0 ? -2 : 0
            pawR = s > 0 ? 0 : -2
        }

        drawTail(c, u: u, sway: tailSway, body: body, shade: bodyShade)
        drawBody(c, u: u, body: body, light: bodyLight, shade: bodyShade, pawL: pawL, pawR: pawR)
        drawHead(c, u: u, body: body, light: bodyLight, shade: bodyShade)
        drawEars(c, u: u, body: body, shade: bodyShade)
        drawFace(c, u: u, state: state, time: t)

        if state.mood == .happy {
            cell(c, 9, 16, u, pink); cell(c, 22, 16, u, pink)
        }

        // ---- Overlays (untransformed, on top) ----
        let headTopY = yShift + 6 * u
        drawOverlays(ctx, size: size, state: state, time: t, u: u, headTopY: headTopY, footY: footY)
    }

    // MARK: Overlays

    private static func drawOverlays(_ ctx: GraphicsContext, size: CGSize, state: CatState, time t: Double, u: CGFloat, headTopY: CGFloat, footY: CGFloat) {
        let cx = size.width / 2

        // Hearts (petting / purring) rise and fade above the head.
        if state.hearts > 0.02 {
            for i in 0..<3 {
                let phase = (t * 0.55 + Double(i) * 0.34).truncatingRemainder(dividingBy: 1.0)
                let rise = CGFloat(phase) * 34
                let hx = cx + CGFloat(sin(phase * 6 + Double(i) * 2)) * 10 - 8 + CGFloat(i - 1) * 6
                let hy = headTopY - rise
                let a = (1 - phase) * state.hearts
                drawHeart(ctx, x: hx, y: hy, s: u * 0.7, color: heartCol.opacity(a))
            }
        }

        // Steam puffs while overheated.
        if state.heat > 0.4 {
            let intensity = (state.heat - 0.4) / 0.6
            for i in 0..<3 {
                let phase = (t * 0.9 + Double(i) * 0.33).truncatingRemainder(dividingBy: 1.0)
                let rise = CGFloat(phase) * 28
                let px = cx + CGFloat(i - 1) * 9 + CGFloat(sin(phase * 7 + Double(i))) * 4
                let py = headTopY - 2 - rise
                let a = (1 - phase) * intensity * 0.8
                drawPuff(ctx, x: px, y: py, s: u * (0.7 + CGFloat(phase) * 0.5), color: steamCol.opacity(a))
            }
        }

        // Paper roll unspooling. The window sits on the floor, so there's no
        // room below — the sheet unrolls UPWARD beside the cat instead.
        if state.paper > 0.02 {
            let rollX = cx - u * 7
            let rollY = footY - u * 3
            let sheetLen = CGFloat(state.paper) * (size.height * 0.60)
            let sheetTop = max(u, rollY - sheetLen)
            let sheetH = rollY - sheetTop
            if sheetH > 0 {
                let sheet = CGRect(x: rollX + u * 0.5, y: sheetTop, width: u * 3, height: sheetH)
                ctx.fill(Path(sheet), with: .color(paperCol))
                ctx.stroke(Path(sheet), with: .color(outline.opacity(0.5)), lineWidth: 1)
                var ly = sheetTop + u * 1.2
                while ly < rollY - u * 0.5 {
                    ctx.stroke(Path { p in
                        p.move(to: CGPoint(x: rollX + u, y: ly))
                        p.addLine(to: CGPoint(x: rollX + u * 3, y: ly))
                    }, with: .color(outline.opacity(0.18)), lineWidth: 1)
                    ly += u * 1.6
                }
            }
            // the roll itself, drawn over the base of the sheet
            let roll = CGRect(x: rollX, y: rollY, width: u * 4, height: u * 2.6)
            ctx.fill(Path(roundedRect: roll, cornerRadius: u), with: .color(paperCol))
            ctx.stroke(Path(roundedRect: roll, cornerRadius: u), with: .color(outline), lineWidth: max(1, u * 0.25))
        }

        // Thinking dots in a little bubble.
        if state.mood == .thinking {
            let active = Int(t * 3) % 3
            for i in 0..<3 {
                let dx = cx - u * 2 + CGFloat(i) * u * 2
                let bob: CGFloat = (i == active) ? -u * 0.6 : 0
                let r = CGRect(x: dx, y: headTopY - u * 3 + bob, width: u * 1.1, height: u * 1.1)
                ctx.fill(Path(ellipseIn: r), with: .color(outline.opacity(0.85)))
            }
        }
    }

    private static func drawHeart(_ ctx: GraphicsContext, x: CGFloat, y: CGFloat, s: CGFloat, color: Color) {
        // 5×5 pixel heart
        let rows = [
            "01010",
            "11111",
            "11111",
            "01110",
            "00100",
        ]
        for (r, row) in rows.enumerated() {
            for (col, ch) in row.enumerated() where ch == "1" {
                let rect = CGRect(x: x + CGFloat(col) * s, y: y + CGFloat(r) * s, width: s, height: s)
                ctx.fill(Path(rect), with: .color(color))
            }
        }
    }

    private static func drawPuff(_ ctx: GraphicsContext, x: CGFloat, y: CGFloat, s: CGFloat, color: Color) {
        let rows = ["011", "111", "011"]
        for (r, row) in rows.enumerated() {
            for (col, ch) in row.enumerated() where ch == "1" {
                let rect = CGRect(x: x + CGFloat(col) * s, y: y + CGFloat(r) * s, width: s, height: s)
                ctx.fill(Path(rect), with: .color(color))
            }
        }
    }

    // MARK: Pieces

    private static func drawEars(_ ctx: GraphicsContext, u: CGFloat, body: Color, shade: Color) {
        let earRows: [(y: Int, x0: Int, x1: Int)] = [
            (5, 9, 10), (6, 8, 11), (7, 8, 11), (8, 7, 12)
        ]
        for r in earRows {
            outlineRow(ctx, y: r.y, x0: r.x0, x1: r.x1, u: u)
            outlineRow(ctx, y: r.y, x0: 31 - r.x1, x1: 31 - r.x0, u: u)
        }
        for r in earRows {
            fillRow(ctx, y: r.y, x0: r.x0, x1: r.x1, u: u, color: body)
            fillRow(ctx, y: r.y, x0: 31 - r.x1, x1: 31 - r.x0, u: u, color: body)
        }
        cell(ctx, 9, 7, u, pink); cell(ctx, 9, 8, u, pink)
        cell(ctx, 22, 7, u, pink); cell(ctx, 22, 8, u, pink)
    }

    private static func drawHead(_ ctx: GraphicsContext, u: CGFloat, body: Color, light: Color, shade: Color) {
        roundedBlock(ctx, x: 5, y: 8, w: 22, h: 12, r: 3, color: outline, u: u)
        roundedBlock(ctx, x: 6, y: 9, w: 20, h: 10, r: 3, color: body, u: u)
        fillRow(ctx, y: 9, x0: 11, x1: 20, u: u, color: light)
    }

    private static func drawBody(_ ctx: GraphicsContext, u: CGFloat, body: Color, light: Color, shade: Color, pawL: Int, pawR: Int) {
        roundedBlock(ctx, x: 8, y: 17, w: 16, h: 14, r: 3, color: outline, u: u)
        roundedBlock(ctx, x: 9, y: 18, w: 14, h: 13, r: 3, color: body, u: u)
        roundedBlock(ctx, x: 12, y: 22, w: 8, h: 8, r: 2, color: light, u: u)
        // front paws (knead offsets raise each paw)
        cell(ctx, 11, 29 + pawL, u, shade, w: 3, h: 2)
        cell(ctx, 18, 29 + pawR, u, shade, w: 3, h: 2)
    }

    private static func drawTail(_ ctx: GraphicsContext, u: CGFloat, sway: Double, body: Color, shade: Color) {
        let segs: [(x: Int, y: Int)] = [
            (22, 27), (24, 26), (25, 24), (26, 22), (26, 20)
        ]
        for (i, s) in segs.enumerated() {
            let off = Int((Double(i) / Double(segs.count) * sway).rounded())
            cell(ctx, s.x + off - 1, s.y - 1, u, outline, w: 3, h: 3)
        }
        for (i, s) in segs.enumerated() {
            let off = Int((Double(i) / Double(segs.count) * sway).rounded())
            cell(ctx, s.x + off, s.y, u, i >= segs.count - 2 ? shade : body)
        }
    }

    private static func drawFace(_ ctx: GraphicsContext, u: CGFloat, state: CatState, time t: Double) {
        let leftEye  = CGPoint(x: 10, y: 12)
        let rightEye = CGPoint(x: 18, y: 12)

        let blinkCycle = t.truncatingRemainder(dividingBy: 4.0)
        let blinking = blinkCycle < 0.14

        switch state.mood {
        case .sleeping:
            sleepyEyes(ctx, at: leftEye, u: u)
            sleepyEyes(ctx, at: rightEye, u: u)
            zChar(ctx, x: 24, y: 8, u: u, t: t)
        case .happy:
            happyEye(ctx, at: leftEye, u: u)
            happyEye(ctx, at: rightEye, u: u)
        case .thinking:
            sleepyEyes(ctx, at: leftEye, u: u)
            sleepyEyes(ctx, at: rightEye, u: u)
        case .hunting:
            // wide, focused eyes locked onto the cursor
            wideEye(ctx, at: leftEye, gaze: state.gaze, facing: state.facing, u: u)
            wideEye(ctx, at: rightEye, gaze: state.gaze, facing: state.facing, u: u)
        default:
            if blinking {
                blinkEye(ctx, at: leftEye, u: u)
                blinkEye(ctx, at: rightEye, u: u)
            } else {
                openEye(ctx, at: leftEye, gaze: state.gaze, facing: state.facing, u: u)
                openEye(ctx, at: rightEye, gaze: state.gaze, facing: state.facing, u: u)
            }
        }

        cell(ctx, 15, 16, u, pink, w: 2, h: 1)
        cell(ctx, 15, 17, u, outline, w: 2, h: 1)
        cell(ctx, 14, 18, u, outline); cell(ctx, 17, 18, u, outline)
    }

    // MARK: Eyes

    private static func openEye(_ ctx: GraphicsContext, at p: CGPoint, gaze: CGPoint, facing: Double, u: CGFloat) {
        roundedBlock(ctx, x: Int(p.x), y: Int(p.y), w: 4, h: 4, r: 1, color: outline, u: u)
        roundedBlock(ctx, x: Int(p.x), y: Int(p.y), w: 4, h: 4, r: 1, color: eyeWhite, u: u)
        let gx = max(-1, min(1, gaze.x)) * facing
        let gy = max(-1, min(1, gaze.y))
        let px = p.x + 1 + CGFloat(gx)
        let py = p.y + 1 - CGFloat(gy)
        let r = CGRect(x: px * u, y: py * u, width: 2 * u, height: 2 * u)
        ctx.fill(Path(roundedRect: r, cornerRadius: u * 0.4), with: .color(outline))
    }

    private static func wideEye(_ ctx: GraphicsContext, at p: CGPoint, gaze: CGPoint, facing: Double, u: CGFloat) {
        // slightly larger whites + smaller darting pupil
        roundedBlock(ctx, x: Int(p.x) - 1, y: Int(p.y), w: 5, h: 4, r: 1, color: outline, u: u)
        roundedBlock(ctx, x: Int(p.x) - 1, y: Int(p.y), w: 5, h: 4, r: 1, color: eyeWhite, u: u)
        let gx = max(-1, min(1, gaze.x)) * facing
        let gy = max(-1, min(1, gaze.y))
        let px = p.x + CGFloat(gx)
        let py = p.y + 1.2 - CGFloat(gy)
        let r = CGRect(x: px * u, y: py * u, width: 1.6 * u, height: 1.6 * u)
        ctx.fill(Path(ellipseIn: r), with: .color(outline))
    }

    private static func blinkEye(_ ctx: GraphicsContext, at p: CGPoint, u: CGFloat) {
        cell(ctx, Int(p.x), Int(p.y) + 2, u, outline, w: 4, h: 1)
    }

    private static func happyEye(_ ctx: GraphicsContext, at p: CGPoint, u: CGFloat) {
        cell(ctx, Int(p.x),     Int(p.y) + 2, u, outline)
        cell(ctx, Int(p.x) + 1, Int(p.y) + 1, u, outline)
        cell(ctx, Int(p.x) + 2, Int(p.y) + 1, u, outline)
        cell(ctx, Int(p.x) + 3, Int(p.y) + 2, u, outline)
    }

    private static func sleepyEyes(_ ctx: GraphicsContext, at p: CGPoint, u: CGFloat) {
        cell(ctx, Int(p.x),     Int(p.y) + 1, u, outline)
        cell(ctx, Int(p.x) + 1, Int(p.y) + 2, u, outline)
        cell(ctx, Int(p.x) + 2, Int(p.y) + 2, u, outline)
        cell(ctx, Int(p.x) + 3, Int(p.y) + 1, u, outline)
    }

    private static func zChar(_ ctx: GraphicsContext, x: Int, y: Int, u: CGFloat, t: Double) {
        let bob = Int((sin(t * 2) * 1).rounded())
        let yy = y + bob
        cell(ctx, x, yy, u, outline, w: 3, h: 1)
        cell(ctx, x + 2, yy + 1, u, outline)
        cell(ctx, x + 1, yy + 2, u, outline)
        cell(ctx, x, yy + 3, u, outline, w: 3, h: 1)
    }

    // MARK: Cell helpers

    static func cell(_ ctx: GraphicsContext, _ gx: Int, _ gy: Int, _ u: CGFloat, _ color: Color, w: Int = 1, h: Int = 1) {
        let r = CGRect(x: CGFloat(gx) * u, y: CGFloat(gy) * u, width: CGFloat(w) * u, height: CGFloat(h) * u)
        ctx.fill(Path(r), with: .color(color))
    }

    private static func fillRow(_ ctx: GraphicsContext, y: Int, x0: Int, x1: Int, u: CGFloat, color: Color) {
        cell(ctx, x0, y, u, color, w: x1 - x0 + 1, h: 1)
    }

    private static func outlineRow(_ ctx: GraphicsContext, y: Int, x0: Int, x1: Int, u: CGFloat) {
        cell(ctx, x0 - 1, y - 1, u, outline, w: x1 - x0 + 3, h: 3)
    }

    private static func roundedBlock(_ ctx: GraphicsContext, x: Int, y: Int, w: Int, h: Int, r: Int, color: Color, u: CGFloat) {
        for row in 0..<h {
            for col in 0..<w {
                let left = col, right = w - 1 - col, top = row, bot = h - 1 - row
                if (left + top) < r || (right + top) < r || (left + bot) < r || (right + bot) < r { continue }
                cell(ctx, x + col, y + row, u, color)
            }
        }
    }

    private static func lerp(_ a: Color, _ b: Color, _ t: Double) -> Color {
        guard t > 0 else { return a }
        let t = max(0, min(1, t))
        let ca = NSColor(a).usingColorSpace(.sRGB) ?? .white
        let cb = NSColor(b).usingColorSpace(.sRGB) ?? .white
        return Color(
            red:   Double(ca.redComponent)   * (1 - t) + Double(cb.redComponent)   * t,
            green: Double(ca.greenComponent) * (1 - t) + Double(cb.greenComponent) * t,
            blue:  Double(ca.blueComponent)  * (1 - t) + Double(cb.blueComponent)  * t
        )
    }
}
