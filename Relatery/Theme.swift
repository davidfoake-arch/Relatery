import SwiftUI
import UIKit

/// Every colour and font in the app lives here, mirroring Cairnward's
/// `Theme`. Views refer to `Theme.plum`, `Theme.Fonts.body` and so on —
/// never to a hex value, a system colour or a system font — so changing
/// the look of the app means changing only this file.
///
/// TODO: Dark mode. These are all light-mode colours, so the app is forced
/// to light appearance by the build setting
/// `INFOPLIST_KEY_UIUserInterfaceStyle = Light`. It's a build setting
/// rather than `.preferredColorScheme(.light)` because that modifier also
/// overrides the navigation bar's own dark scheme, which turns the status
/// bar black on plum.
enum Theme {

    // MARK: - Core palette

    /// Navigation bars and primary accents. Forms set it as their tint,
    /// which colours pickers and toggles.
    static let plum = Color(hex: 0x74465F)
    /// Pressed states and depth.
    static let deepPlum = Color(hex: 0x543245)
    /// Screen backgrounds; text on plum.
    static let cream = Color(hex: 0xF3ECDC)
    /// Cards, rows and list surfaces.
    static let warmWhite = Color(hex: 0xFBF8F1)
    /// Primary text.
    static let darkBrown = Color(hex: 0x3A2B22)
    /// Secondary text.
    static let mutedBrown = Color(hex: 0x6B5748)
    /// Dividers and placeholders.
    static let stone = Color(hex: 0xDFD5C3)
    /// Calls to action, and a date that is today.
    static let clay = Color(hex: 0xB5653F)
    /// Destructive actions.
    static let berry = Color(hex: 0x8C3A4A)

    // MARK: - Type scale

    /// The fonts' PostScript names, which are what `Font.custom` needs —
    /// not the file names. The files are in `Relatery/Fonts` and listed
    /// under UIAppFonts in `Relatery-Info.plist` (at the project root).
    enum FontName {
        static let frauncesSemiBold = "Fraunces72pt-SemiBold"
        static let frauncesRegular = "Fraunces72pt-Regular"
        static let karlaRegular = "Karla-Regular"
        static let karlaSemiBold = "Karla-SemiBold"

        static let all = [frauncesSemiBold, frauncesRegular, karlaRegular, karlaSemiBold]
    }

    /// Every font in the app. Each one is a base size plus the system text
    /// style it scales with (`relativeTo:`), so Dynamic Type grows them by
    /// the same proportion as the matching system style.
    enum Fonts {
        // Fraunces SemiBold — navigation titles, people's names, countdowns.
        static let navigationTitle = Font.custom(FontName.frauncesSemiBold, size: 18, relativeTo: .headline)
        static let personName = Font.custom(FontName.frauncesSemiBold, size: 17, relativeTo: .body)
        static let profileName = Font.custom(FontName.frauncesSemiBold, size: 28, relativeTo: .title)

        // Fraunces Regular — card headings and summary lines.
        static let cardHeading = Font.custom(FontName.frauncesRegular, size: 20, relativeTo: .title3)
        static let summaryLine = Font.custom(FontName.frauncesRegular, size: 15, relativeTo: .subheadline)

        // Karla Regular — body text (the app-wide default) and secondary labels.
        static let body = Font.custom(FontName.karlaRegular, size: 17, relativeTo: .body)
        static let secondary = Font.custom(FontName.karlaRegular, size: 15, relativeTo: .subheadline)
        static let footnote = Font.custom(FontName.karlaRegular, size: 13, relativeTo: .footnote)
        static let caption = Font.custom(FontName.karlaRegular, size: 12, relativeTo: .caption)

        // Karla SemiBold — emphasis, and uppercase section labels (see
        // `themedSectionLabel()`).
        static let bodyStrong = Font.custom(FontName.karlaSemiBold, size: 17, relativeTo: .body)
        static let sectionLabel = Font.custom(FontName.karlaSemiBold, size: 13, relativeTo: .footnote)

        /// Initials inside an avatar: sized to the circle, not to Dynamic Type.
        static func avatarInitials(size: CGFloat) -> Font {
            Font.custom(FontName.frauncesSemiBold, fixedSize: size)
        }
    }

    /// A wrong PostScript name, or a font missing from UIAppFonts, doesn't
    /// cause an error: iOS quietly substitutes the system font. In debug
    /// builds this stops the app at launch instead, naming the font.
    static func verifyFonts() {
        #if DEBUG
        for name in FontName.all where UIFont(name: name, size: 12) == nil {
            assertionFailure("Font \"\(name)\" isn't available. Check its PostScript name and UIAppFonts.")
        }
        #endif
    }
}

// MARK: - View helpers

extension View {
    /// Cream screen behind a List or Form, with dark brown Karla text.
    /// Lists paint their own grey background by default, so that has to be
    /// hidden first.
    ///
    /// The text colour is set here, on the content, rather than once for
    /// the whole app: an app-wide one would also reach the navigation bar
    /// and turn its title and buttons dark brown on plum.
    func themedListBackground() -> some View {
        scrollContentBackground(.hidden)
            .background(Theme.cream)
            .foregroundStyle(Theme.darkBrown)
            .font(Theme.Fonts.body)
    }

    /// Warm white rows with stone separators, for a List or Form section.
    func themedRows() -> some View {
        listRowBackground(Theme.warmWhite)
            .listRowSeparatorTint(Theme.stone)
    }

    /// Use in place of `.navigationTitle(_:)` on every screen: plum bar,
    /// cream title, light buttons. Bar colours belong to each screen, not
    /// to the NavigationStack, so a pushed screen needs this too.
    ///
    /// - The `.dark` colour scheme is what makes the buttons and the status
    ///   bar light. It would also make the title white, so the title is
    ///   drawn here as our own cream `Text` in the centre ("principal") slot.
    /// - `.navigationTitle` is still set: it's what the back button and
    ///   VoiceOver use.
    /// - The title is always inline. On iOS 26 and later, large titles are
    ///   not drawn at all once the bar has a solid background colour.
    func themedNavigationBar(title: String) -> some View {
        navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.plum, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(Theme.Fonts.navigationTitle)
                        .foregroundStyle(Theme.cream)
                }
            }
    }

    /// Small uppercase label in Karla SemiBold, muted brown — for section
    /// headers in lists.
    func themedSectionLabel() -> some View {
        font(Theme.Fonts.sectionLabel)
            .textCase(.uppercase)
            .tracking(0.8)
            .foregroundStyle(Theme.mutedBrown)
    }
}

// MARK: - Hex initialiser

private extension Color {
    /// `Color(hex: 0x74465F)`. Private to this file, so hex values can't
    /// creep into the views.
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
