import SwiftUI
import UIKit

enum VeilAccent: String, CaseIterable, Identifiable {
    case acid
    case cyan

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    var color: Color {
        switch self {
        case .acid:
            return Color(uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(red: 0.83, green: 0.93, blue: 0.51, alpha: 1)
                    : UIColor(red: 0.31, green: 0.43, blue: 0.07, alpha: 1)
            })
        case .cyan:
            return Color(uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(red: 0.60, green: 0.87, blue: 0.85, alpha: 1)
                    : UIColor(red: 0.10, green: 0.43, blue: 0.41, alpha: 1)
            })
        }
    }
}

enum VeilAppearance: String, CaseIterable, Identifiable {
    case dark
    case light
    case system

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    var colorScheme: ColorScheme? {
        switch self {
        case .dark: return .dark
        case .light: return .light
        case .system: return nil
        }
    }
}

@MainActor
final class AppearanceStore: ObservableObject {
    @Published var accent: VeilAccent {
        didSet { defaults.set(accent.rawValue, forKey: Keys.accent) }
    }

    @Published var appearance: VeilAppearance {
        didSet { defaults.set(appearance.rawValue, forKey: Keys.appearance) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        accent = VeilAccent(rawValue: defaults.string(forKey: Keys.accent) ?? "") ?? .acid
        appearance = VeilAppearance(rawValue: defaults.string(forKey: Keys.appearance) ?? "") ?? .dark
    }

    var accentColor: Color { accent.color }
    var colorScheme: ColorScheme? { appearance.colorScheme }

    private enum Keys {
        static let accent = "veil.appearance.accent"
        static let appearance = "veil.appearance.mode"
    }
}

extension Color {
    static let veilBackground = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.055, green: 0.071, blue: 0.063, alpha: 1)
            : UIColor(red: 0.965, green: 0.965, blue: 0.925, alpha: 1)
    })

    static let veilRaised = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.105, green: 0.125, blue: 0.11, alpha: 1)
            : UIColor(red: 0.91, green: 0.925, blue: 0.88, alpha: 1)
    })

    static let veilLine = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.18, green: 0.215, blue: 0.185, alpha: 1)
            : UIColor(red: 0.81, green: 0.84, blue: 0.77, alpha: 1)
    })

    static let veilSecondary = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.60, green: 0.64, blue: 0.59, alpha: 1)
            : UIColor(red: 0.34, green: 0.39, blue: 0.32, alpha: 1)
    })
}

extension Font {
    static func veilLabel(size: CGFloat = 10) -> Font {
        .system(size: size, weight: .medium, design: .monospaced)
    }
}

struct VeilSectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.veilLabel(size: 9))
            .tracking(1.0)
            .foregroundStyle(Color.veilSecondary)
    }
}

struct VeilDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.veilLine)
            .frame(height: 1 / UIScreen.main.scale)
            .accessibilityHidden(true)
    }
}
