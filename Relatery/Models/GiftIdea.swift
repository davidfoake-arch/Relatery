import Foundation
import SwiftData

enum GiftStatus: String, Codable, CaseIterable, Identifiable {
    case idea
    case bought
    case given

    var id: String { rawValue }

    var title: String {
        switch self {
        case .idea: "Idea"
        case .bought: "Bought"
        case .given: "Given"
        }
    }

    var symbolName: String {
        switch self {
        case .idea: "lightbulb"
        case .bought: "bag.fill"
        case .given: "gift.fill"
        }
    }
}

/// A gift for one relationship: thought of, bought, or already given.
/// Given gifts stay as a history, so the same thing isn't given twice.
@Model
final class GiftIdea {
    var title: String = ""
    var price: Decimal?
    /// A web address for the item, as typed.
    var link: String = ""
    var status: GiftStatus = GiftStatus.idea
    /// The date it's for (a birthday, say). Nil for "whenever".
    var occasion: KeyDate?
    /// When it was marked as given; set automatically.
    var givenOn: Date?
    var createdAt: Date = Date.now
    var person: Person?

    init(title: String, price: Decimal? = nil, link: String = "", status: GiftStatus = .idea) {
        self.title = title
        self.price = price
        self.link = link
        self.status = status
    }

    /// The link as a URL, adding "https://" when it was typed without one.
    var url: URL? {
        let trimmed = link.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let withScheme = trimmed.contains("://") ? trimmed : "https://" + trimmed
        guard let url = URL(string: withScheme), url.host() != nil else { return nil }
        return url
    }

    /// "£40" in the phone's currency.
    var formattedPrice: String? {
        price.map { $0.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD").precision(.fractionLength(0...2))) }
    }

    /// "Birthday", "Given Oct 2026 · Birthday" — the line under the title.
    var detailLine: String {
        var parts: [String] = []
        if status == .given, let givenOn {
            parts.append("Given \(givenOn.formatted(.dateTime.month(.abbreviated).year()))")
        }
        if let occasion {
            parts.append(occasion.title)
        }
        if let price = formattedPrice {
            parts.append(price)
        }
        return parts.joined(separator: " · ")
    }
}
