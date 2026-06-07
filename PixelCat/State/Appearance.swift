import SwiftUI

/// Fixed set of coat colors. Each resolves to a 3-tone palette (light/base/shade)
/// that `CatSprite` uses for the body, head, ears, and tail.
enum CatColor: String, CaseIterable {
    case cream, gray, charcoal, ginger, snow, brown

    var display: String {
        switch self {
        case .cream:    return "Cream"
        case .gray:     return "Gray"
        case .charcoal: return "Charcoal"
        case .ginger:   return "Ginger"
        case .snow:     return "Snow"
        case .brown:    return "Brown"
        }
    }

    var palette: (light: Color, base: Color, shade: Color) {
        switch self {
        case .cream:
            return (Color(red: 0.97, green: 0.93, blue: 0.86),
                    Color(red: 0.93, green: 0.87, blue: 0.78),
                    Color(red: 0.85, green: 0.77, blue: 0.67))
        case .gray:
            return (Color(red: 0.82, green: 0.83, blue: 0.85),
                    Color(red: 0.68, green: 0.69, blue: 0.72),
                    Color(red: 0.52, green: 0.53, blue: 0.57))
        case .charcoal:
            return (Color(red: 0.42, green: 0.42, blue: 0.46),
                    Color(red: 0.31, green: 0.31, blue: 0.35),
                    Color(red: 0.21, green: 0.21, blue: 0.25))
        case .ginger:
            return (Color(red: 0.96, green: 0.74, blue: 0.50),
                    Color(red: 0.90, green: 0.62, blue: 0.36),
                    Color(red: 0.78, green: 0.48, blue: 0.24))
        case .snow:
            return (Color(red: 1.00, green: 0.99, blue: 0.98),
                    Color(red: 0.95, green: 0.94, blue: 0.93),
                    Color(red: 0.83, green: 0.83, blue: 0.84))
        case .brown:
            return (Color(red: 0.74, green: 0.58, blue: 0.43),
                    Color(red: 0.62, green: 0.46, blue: 0.32),
                    Color(red: 0.48, green: 0.34, blue: 0.22))
        }
    }
}

/// Fixed set of coat patterns drawn over the base color.
enum CatPattern: String, CaseIterable {
    case solid, tabby, tuxedo, calico, spots, socks

    var display: String {
        switch self {
        case .solid:  return "Solid"
        case .tabby:  return "Tabby"
        case .tuxedo: return "Tuxedo"
        case .calico: return "Calico"
        case .spots:  return "Spots"
        case .socks:  return "Socks"
        }
    }
}
