import Foundation

/// Eventos globales para refrescar vistas después de mutaciones remotas.
enum AppEvent {
    static let prestamosChanged = Notification.Name("panditacash.prestamosChanged")
    static let solicitudesChanged = Notification.Name("panditacash.solicitudesChanged")
    static let kycChanged = Notification.Name("panditacash.kycChanged")
    static let clientesChanged = Notification.Name("panditacash.clientesChanged")

    static func post(_ name: Notification.Name) {
        NotificationCenter.default.post(name: name, object: nil)
    }
}
