import SwiftUI

/// The app's brand gradient — violet to coral pink. Used by `AppGlyph` and the
/// login/register backgrounds. Kept as fixed RGB values (not `Color.accentColor`,
/// which follows the user's system preference) so the in-app brand mark always matches
/// the generated app icon exactly.
///
/// - Important: These values must stay in sync with the icon generator script that
///   produced `Assets.xcassets/AppIcon.appiconset` and `Assets.xcassets/Logo.imageset`.
enum BrandColor {
    static let gradientStart = Color(red: 0x7C / 255.0, green: 0x5C / 255.0, blue: 0xFC / 255.0) // #7C5CFC
    static let gradientEnd = Color(red: 0xFF / 255.0, green: 0x65 / 255.0, blue: 0x84 / 255.0)    // #FF6584

    static let gradient = LinearGradient(
        colors: [gradientStart, gradientEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
