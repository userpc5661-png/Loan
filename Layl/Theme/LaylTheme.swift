import SwiftUI

enum LaylColor {
    static let background = Color(red: 0.043, green: 0.031, blue: 0.067)
    static let backgroundDeep = Color(red: 0.020, green: 0.014, blue: 0.035)
    static let purple = Color(red: 0.49, green: 0.28, blue: 0.86)
    static let purpleDeep = Color(red: 0.24, green: 0.09, blue: 0.42)
    static let lilac = Color(red: 0.74, green: 0.60, blue: 1.0)
    static let pg = Color(red: 0.89, green: 0.16, blue: 0.29)
    static let secondary = Color(red: 0.76, green: 0.76, blue: 0.80)
    static let tertiary = Color(red: 0.56, green: 0.56, blue: 0.62)
    static let hdFill = Color(red: 0.23, green: 0.23, blue: 0.26)
    static let darkButton = Color(white: 0.15)
    static let card = Color.white.opacity(0.06)
}

enum LaylMetrics {
    static let heroRadius: CGFloat = 22
    static let thumbRadius: CGFloat = 16
    static let posterRadius: CGFloat = 14
    static let buttonRadius: CGFloat = 14
    static let buttonHeight: CGFloat = 50
}

struct LaylBackground: View {
    var body: some View {
        ZStack {
            LaylColor.backgroundDeep
            RadialGradient(
                colors: [
                    LaylColor.purple.opacity(0.50),
                    LaylColor.purpleDeep.opacity(0.22),
                    .clear
                ],
                center: UnitPoint(x: 0.55, y: 0.02),
                startRadius: 8,
                endRadius: 520
            )
            LinearGradient(
                colors: [.clear, .black.opacity(0.35)],
                startPoint: .center,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

struct LaylScreen<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            LaylBackground()
            content
        }
        .foregroundStyle(.white)
    }
}
