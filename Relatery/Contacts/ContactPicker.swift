import ContactsUI
import UIKit

/// Apple's contact picker. iOS shows the address book in its own process and
/// hands the app only the contacts the user picks, so no Contacts permission
/// is needed and Relatery never sees anyone else.
///
/// It's presented from UIKit rather than wrapped as a SwiftUI view: wrapped
/// in a sheet, the picker shows up blank.
enum ContactPicker {
    /// Lets the user tick any number of contacts. Empty if they cancel.
    static func pickContacts() async -> [CNContact] {
        await present(MultipleDelegate())
    }

    /// Lets the user tap one contact. Nil if they cancel.
    static func pickContact() async -> CNContact? {
        await present(SingleDelegate()).first
    }

    /// The delegate in use. The picker only holds it weakly, so it's kept
    /// here until the picker is done with it.
    private static var activeDelegate: PickerDelegate?

    private static func present(_ delegate: PickerDelegate) async -> [CNContact] {
        guard activeDelegate == nil, let presenter = topViewController() else { return [] }
        activeDelegate = delegate
        defer { activeDelegate = nil }

        let picker = CNContactPickerViewController()
        picker.delegate = delegate
        return await withCheckedContinuation { continuation in
            delegate.continuation = continuation
            presenter.present(picker, animated: true)
        }
    }

    /// The screen currently on top, which may itself be a sheet.
    private static func topViewController() -> UIViewController? {
        let window = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first
        var top = window?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}

/// The picker allows several contacts when its delegate implements the
/// plural `didSelect contacts:`, and one when it implements the singular, so
/// each mode gets its own subclass.
private class PickerDelegate: NSObject, CNContactPickerDelegate {
    var continuation: CheckedContinuation<[CNContact], Never>?

    func finish(_ contacts: [CNContact]) {
        continuation?.resume(returning: contacts)
        continuation = nil
    }

    func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
        finish([])
    }
}

private final class MultipleDelegate: PickerDelegate {
    func contactPicker(_ picker: CNContactPickerViewController, didSelect contacts: [CNContact]) {
        finish(contacts)
    }
}

private final class SingleDelegate: PickerDelegate {
    func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
        finish([contact])
    }
}
