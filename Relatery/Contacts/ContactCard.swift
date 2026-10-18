import Contacts
import Foundation

/// A snapshot of what a picked contact can bring into Relatery: names,
/// photo and dates. Taken once, at the moment of picking.
struct ContactCard: Identifiable {
    /// A date as it will become a `KeyDate`.
    struct ImportedDate: Hashable {
        var kind: KeyDateKind
        var label = ""
        var month: Int
        var day: Int
        var year: Int?

        var title: String {
            label.isEmpty ? kind.title : label
        }

        /// "Birthday, 12 October"
        var summary: String {
            "\(title), \(KeyDate.formattedDate(month: month, day: day, year: year))"
        }
    }

    /// `CNContact.identifier`.
    let id: String
    let firstName: String
    let lastName: String
    let photoData: Data?
    let dates: [ImportedDate]

    var displayName: String {
        let name = [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " ")
        return name.isEmpty ? "No Name" : name
    }

    var initials: String {
        String([firstName, lastName].compactMap(\.first)).uppercased()
    }

    init(_ contact: CNContact) {
        id = contact.identifier
        firstName = Self.string(contact, CNContactGivenNameKey) { $0.givenName }
        // A contact that's only a company has no person's name; use the company.
        let family = Self.string(contact, CNContactFamilyNameKey) { $0.familyName }
        let company = Self.string(contact, CNContactOrganizationNameKey) { $0.organizationName }
        lastName = firstName.isEmpty && family.isEmpty ? company : family

        if contact.isKeyAvailable(CNContactImageDataKey), let image = contact.imageData {
            photoData = ProfilePhoto.downscaled(image)
        } else if contact.isKeyAvailable(CNContactThumbnailImageDataKey), let image = contact.thumbnailImageData {
            photoData = image
        } else {
            photoData = nil
        }

        var dates: [ImportedDate] = []
        if contact.isKeyAvailable(CNContactBirthdayKey), let birthday = contact.birthday,
           let date = Self.date(birthday, kind: .birthday) {
            dates.append(date)
        }
        if contact.isKeyAvailable(CNContactDatesKey) {
            for labeled in contact.dates {
                // Contacts says only "anniversary", not which kind. Wedding is
                // the likelier meaning, and it can be changed afterwards.
                let isAnniversary = labeled.label == CNLabelDateAnniversary
                let label = isAnniversary ? "" : Self.labelText(labeled.label)
                guard let date = Self.date(labeled.value as DateComponents,
                                           kind: isAnniversary ? .weddingAnniversary : .custom,
                                           label: label) else { continue }
                // A relationship has at most one of each kind except custom days.
                if date.kind.allowsMultiple || !dates.contains(where: { $0.kind == date.kind }) {
                    dates.append(date)
                }
            }
        }
        self.dates = dates
    }

    // MARK: - Reading the contact

    /// The picker hands over contacts that may lack some properties; reading
    /// a missing one would crash, so each read is checked first.
    private static func string(_ contact: CNContact, _ key: String, _ value: (CNContact) -> String) -> String {
        contact.isKeyAvailable(key) ? value(contact).trimmingCharacters(in: .whitespaces) : ""
    }

    private static func date(_ components: DateComponents, kind: KeyDateKind, label: String = "") -> ImportedDate? {
        guard let month = components.month, let day = components.day,
              (1...12).contains(month), (1...31).contains(day) else { return nil }
        // Contacts stores a missing year as NSDateComponentUndefined, which
        // shows up as a very large number rather than nil.
        let year = components.year.flatMap { (1...9999).contains($0) ? $0 : nil }
        return ImportedDate(kind: kind, label: label, month: month, day: day, year: year)
    }

    /// A label the user typed, or a built-in one in the phone's language.
    /// "Other" (or no label) leaves the day as an unnamed Special Day.
    private static func labelText(_ label: String?) -> String {
        guard let label, !label.isEmpty, label != CNLabelOther else { return "" }
        return CNLabeledValue<NSDateComponents>.localizedString(forLabel: label)
    }
}
