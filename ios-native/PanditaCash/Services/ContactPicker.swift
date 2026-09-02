import SwiftUI
import ContactsUI
import Contacts

struct ContactPicker: UIViewControllerRepresentable {
    let onPick: (String, String) -> Void  // (nombre, telefono)

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let vc = CNContactPickerViewController()
        vc.displayedPropertyKeys = [CNContactPhoneNumbersKey]
        vc.delegate = context.coordinator
        return vc
    }
    func updateUIViewController(_ vc: CNContactPickerViewController, context: Context) {}

    func makeCoordinator() -> Coord { Coord(onPick: onPick) }

    class Coord: NSObject, CNContactPickerDelegate {
        let onPick: (String, String) -> Void
        init(onPick: @escaping (String, String) -> Void) { self.onPick = onPick }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            let nombre = [contact.givenName, contact.familyName].filter { !$0.isEmpty }.joined(separator: " ")
            let tel = contact.phoneNumbers.first?.value.stringValue ?? ""
            onPick(nombre, tel.filter { $0.isNumber })
        }

        func contactPicker(_ picker: CNContactPickerViewController,
                           didSelect contactProperty: CNContactProperty) {
            let contact = contactProperty.contact
            let nombre = [contact.givenName, contact.familyName].filter { !$0.isEmpty }.joined(separator: " ")
            let tel = (contactProperty.value as? CNPhoneNumber)?.stringValue ?? ""
            onPick(nombre, tel.filter { $0.isNumber })
        }
    }
}
