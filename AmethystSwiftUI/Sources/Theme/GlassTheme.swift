import SwiftUI

enum GlassTheme {
    static let bgTop = Color(red: 0.11, green: 0.13, blue: 0.18)
    static let bgMid = Color(red: 0.08, green: 0.10, blue: 0.15)
    static let bgBottom = Color(red: 0.05, green: 0.07, blue: 0.11)
    static let cardFill = Color.white.opacity(0.09)
    static let cardStroke = Color.white.opacity(0.19)
    static let selectedFill = Color(red: 0.30, green: 0.52, blue: 0.80).opacity(0.48)
    static let actionTint = Color(red: 0.33, green: 0.75, blue: 0.95)
}

struct GlassCardModifier: ViewModifier {
    let cornerRadius: CGFloat
    let intensity: Double

    func body(content: Content) -> some View {
        content
            .background(GlassTheme.cardFill.opacity(max(0.18, intensity)))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(GlassTheme.cardStroke, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.25), radius: 14, x: 0, y: 8)
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 16, intensity: Double = 0.62) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, intensity: intensity))
    }
}

struct DashboardBackgroundView: View {
    let mode: DashboardBackgroundMode
    let imagePath: String
    let blurStrength: Double

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [GlassTheme.bgTop, GlassTheme.bgMid, GlassTheme.bgBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if mode != .default,
               !imagePath.isEmpty,
               let image = UIImage(contentsOfFile: imagePath) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .opacity(0.30)
                    .blur(radius: 18 * blurStrength)
                    .ignoresSafeArea()
            }

            LinearGradient(
                colors: [Color.black.opacity(0.25), Color.black.opacity(0.55)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}
