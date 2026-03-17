import UIKit

enum GlassTheme {
    static let background = UIColor(red: 0.07, green: 0.09, blue: 0.14, alpha: 1.0)
    static let glassFill = UIColor(red: 0.16, green: 0.20, blue: 0.27, alpha: 0.62)
    static let glassStroke = UIColor(red: 0.83, green: 0.90, blue: 1.00, alpha: 0.22)
    static let selectedFill = UIColor(red: 0.34, green: 0.53, blue: 0.77, alpha: 0.55)
    static let tint = UIColor(red: 0.35, green: 0.75, blue: 0.95, alpha: 1.0)

    static let cardRadius: CGFloat = 13
    static let itemRadius: CGFloat = 11
    static let itemHeight: CGFloat = 44
    static let iconSize: CGFloat = 22
}

extension UIView {
    func applyGlassCard(cornerRadius: CGFloat = GlassTheme.cardRadius) {
        backgroundColor = GlassTheme.glassFill
        layer.cornerRadius = cornerRadius
        layer.borderWidth = 1
        layer.borderColor = GlassTheme.glassStroke.cgColor
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.12
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = 12
        layer.masksToBounds = false
    }
}
