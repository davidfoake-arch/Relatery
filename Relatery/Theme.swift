import SwiftUI
import UIKit

/// Every colour and font in the app lives here, mirroring Cairnward's
/// `Theme`. Views refer to `Theme.accent`, `Theme.Fonts.body` and so on —
/// never to a hex value, a system colour or a system font — so changing
/// the look of the app means changing only this file.
///
/// Dark mode ("Night plum", the sibling of Cairnward's "Night forest"):
/// most colours have a light and a dark value, and iOS picks between them
/// as it draws, following the phone's own setting. There's no in-app
/// switch, and never `.preferredColorScheme`: it would also override the
/// navigation bar's own dark scheme and turn the status bar black on plum.
///
/// The names describe the light look; read them as roles:
/// `cream` is the screen background, `warmWhite` a card or row,
/// `darkBrown` main text, `mutedBrown` secondary text, `stone` dividers.
/// Plum has three roles that are one colour in light mode but need
/// different ones at night: `plum` for filled shapes, `accent` for plum
/// text, icons and tints, and `navigationBar`. Anything drawn *on* a plum
/// or clay fill uses `onPlum`, which stays cream in both.
enum Theme {

    // MARK: - Core palette

    /// Filled shapes: avatars, ticked circles, swipe-action buttons. A
    /// little lighter at night so it stands out from a dark card, while
    /// cream text on it still reads.
    static let plum = adaptive(light: 0x74465F, dark: 0x9C5179)
    /// Plum as text, icons and `.tint` (links, "Add…" buttons, pickers,
    /// toggles). Pale at night so it reads on a dark card.
    static let accent = adaptive(light: 0x74465F, dark: 0xC28CA9)
    /// The navigation bar: the brand plum in both appearances.
    static let navigationBar = fixed(0x74465F)
    /// Pressed states and depth.
    static let deepPlum = adaptive(light: 0x543245, dark: 0x5C2E47)
    /// Screen backgrounds.
    static let cream = adaptive(light: 0xF3ECDC, dark: 0x1A1116)
    /// Cards, rows and list surfaces.
    static let warmWhite = adaptive(light: 0xFBF8F1, dark: 0x261A21)
    /// Primary text. The same as Cairnward in both appearances.
    static let darkBrown = adaptive(light: 0x3A2B22, dark: 0xEDE4D1)
    /// Secondary text. Plum-tinted at night (Cairnward's is a warm grey).
    static let mutedBrown = adaptive(light: 0x6B5748, dark: 0xA38E99)
    /// Dividers. Too faint for anything that has to be seen, like an empty
    /// circle: use `mutedBrown` for those.
    static let stone = adaptive(light: 0xDFD5C3, dark: 0x3B2D35)
    /// Clay as text and icons: a date that is today, a gift that's bought.
    static let clay = adaptive(light: 0xB5653F, dark: 0xC8774C)
    /// Clay as a filled button with cream text. The lighter night clay
    /// would make the text too faint, so this stays the same in both.
    static let clayFill = fixed(0xB5653F)
    /// Text and symbols on a plum or clay fill, and the navigation title.
    static let onPlum = fixed(0xF3ECDC)
    /// Destructive actions. A brick red rather than Cairnward's berry
    /// (0x8C3A4A), which was too close to plum to stand out; lifted at
    /// night, keeping its hue, so it still reads on a dark card.
    static let berry = adaptive(light: 0xB3302B, dark: 0xD85F5B)

    // MARK: - UIKit appearance

    /// The tab bar is still drawn by UIKit underneath, and SwiftUI has no
    /// modifier for its label font. UIKit's "appearance proxy" sets a default
    /// for every control created afterwards, so this is called once, when the
    /// app starts. The font is scaled for the user's text size at that point.
    static func applyUIKitAppearance() {
        let base = UIFont(name: FontName.karlaSemiBold, size: 10) ?? .systemFont(ofSize: 10)
        let tabLabel = UIFontMetrics(forTextStyle: .caption2).scaledFont(for: base)
        let tabs = UITabBarAppearance()
        tabs.configureWithDefaultBackground()
        for layout in [tabs.stackedLayoutAppearance, tabs.inlineLayoutAppearance, tabs.compactInlineLayoutAppearance] {
            layout.normal.titleTextAttributes = [.font: tabLabel]
            layout.selected.titleTextAttributes = [.font: tabLabel]
        }
        UITabBar.appearance().standardAppearance = tabs
        UITabBar.appearance().scrollEdgeAppearance = tabs
    }

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
            .toolbarBackground(Theme.navigationBar, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(Theme.Fonts.navigationTitle)
                        .foregroundStyle(Theme.onPlum)
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

// MARK: - Building colours

private extension Theme {
    /// A colour with a light and a dark value. iOS asks the closure again
    /// whenever the appearance changes; SwiftUI asks with the screen's own
    /// appearance, so the navigation bar (dark) and a card (light, say)
    /// each get the right one.
    static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }

    /// A colour that's the same in both appearances.
    static func fixed(_ hex: UInt32) -> Color {
        Color(uiColor: UIColor(hex: hex))
    }
}

private extension UIColor {
    /// `UIColor(hex: 0x74465F)`. Private to this file, so hex values can't
    /// creep into the views.
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
