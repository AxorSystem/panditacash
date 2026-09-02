import Foundation
import Contacts

enum ContactSaver {
    /// Guarda el cliente en la agenda del usuario. Devuelve true si se guardó.
    /// El label del teléfono se marca como "PanditaCash".
    static func guardar(nombre: String, telefono: String) async -> Bool {
        let store = CNContactStore()
        let auth = await requestAuth(store)
        guard auth else { return false }
        let contact = CNMutableContact()
        let parts = nombre.split(separator: " ")
        contact.givenName = parts.first.map(String.init) ?? nombre
        if parts.count > 1 {
            contact.familyName = parts.dropFirst().joined(separator: " ")
        }
        let normalized = telefono.filter { $0.isNumber }
        contact.phoneNumbers = [
            .init(label: "PanditaCash", value: CNPhoneNumber(stringValue: normalized))
        ]
        contact.organizationName = "PanditaCash"
        let saveReq = CNSaveRequest()
        saveReq.add(contact, toContainerWithIdentifier: nil)
        do {
            try store.execute(saveReq)
            return true
        } catch {
            return false
        }
    }

    private static func requestAuth(_ store: CNContactStore) async -> Bool {
        if #available(iOS 18.0, *) {
            let status = CNContactStore.authorizationStatus(for: .contacts)
            switch status {
            case .authorized, .limited:
                return true
            case .notDetermined:
                return await withCheckedContinuation { cont in
                    store.requestAccess(for: .contacts) { granted, _ in cont.resume(returning: granted) }
                }
            default:
                return false
            }
        } else {
            return await withCheckedContinuation { cont in
                store.requestAccess(for: .contacts) { granted, _ in cont.resume(returning: granted) }
            }
        }
    }
}
