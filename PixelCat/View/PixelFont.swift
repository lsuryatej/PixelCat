import SwiftUI

/// Minimal 3×5 pixel font for the timer digits (0–9 and ":"). Each glyph draws
/// on an integer cell grid so it matches the cat's blocky aesthetic.
enum PixelFont {
    private static let digits: [Character: [String]] = [
        "0": ["111", "101", "101", "101", "111"],
        "1": ["010", "110", "010", "010", "111"],
        "2": ["111", "001", "111", "100", "111"],
        "3": ["111", "001", "111", "001", "111"],
        "4": ["101", "101", "111", "001", "001"],
        "5": ["111", "100", "111", "001", "111"],
        "6": ["111", "100", "111", "101", "111"],
        "7": ["111", "001", "010", "010", "010"],
        "8": ["111", "101", "111", "101", "111"],
        "9": ["111", "101", "111", "001", "111"],
    ]

    private static let digitGap: CGFloat = 1   // cells between glyphs
    private static let colonWidth: CGFloat = 1
    private static let digitWidth: CGFloat = 3

    /// Total width (in points) of `text` at the given cell size.
    static func width(_ text: String, cell: CGFloat) -> CGFloat {
        var cells: CGFloat = 0
        for ch in text {
            cells += (ch == ":" ? colonWidth : digitWidth) + digitGap
        }
        return (cells - digitGap) * cell   // no trailing gap
    }

    /// Draws `text` with its top-left at (x, y).
    static func draw(_ ctx: GraphicsContext, _ text: String, x: CGFloat, y: CGFloat, cell: CGFloat, color: Color) {
        var cx = x
        for ch in text {
            if ch == ":" {
                fill(ctx, cx, y + cell * 1, cell, color)
                fill(ctx, cx, y + cell * 3, cell, color)
                cx += (colonWidth + digitGap) * cell
            } else if let g = digits[ch] {
                for (r, row) in g.enumerated() {
                    for (c, ch) in row.enumerated() where ch == "1" {
                        fill(ctx, cx + CGFloat(c) * cell, y + CGFloat(r) * cell, cell, color)
                    }
                }
                cx += (digitWidth + digitGap) * cell
            }
        }
    }

    private static func fill(_ ctx: GraphicsContext, _ x: CGFloat, _ y: CGFloat, _ s: CGFloat, _ color: Color) {
        ctx.fill(Path(CGRect(x: x, y: y, width: s, height: s)), with: .color(color))
    }
}
