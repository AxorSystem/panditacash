import Foundation
import UserNotifications

/// Notificaciones locales on-device (sin APNs). Mamá programa recordatorios
/// de sus pagos pendientes que se disparan aunque la app esté cerrada.
enum LocalNotifService {

    static func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    static var permissionStatus: UNAuthorizationStatus {
        get async {
            let s = await UNUserNotificationCenter.current().notificationSettings()
            return s.authorizationStatus
        }
    }

    /// Programa 3 notificaciones por pago pendiente:
    /// - 1 día antes 10:00
    /// - Día del pago 10:00
    /// - 1 día después 10:00 (si sigue vencido)
    static func programarRecordatorio(pagoId: Int, cliente: String, monto: Double, fechaProgramada: Date) async {
        cancelarRecordatorio(pagoId: pagoId)
        let ok = await requestPermission()
        guard ok else { return }
        let cal = Calendar.current
        let baseDate = cal.date(bySettingHour: 10, minute: 0, second: 0, of: fechaProgramada) ?? fechaProgramada

        struct Recordatorio { let offset: Int; let titulo: String; let cuerpo: String }
        let recs: [Recordatorio] = [
            .init(offset: -1, titulo: "Mañana vence pago", cuerpo: "\(cliente) — \(fmt(monto))"),
            .init(offset: 0, titulo: "Vence hoy", cuerpo: "\(cliente) debe pagar \(fmt(monto))"),
            .init(offset: 1, titulo: "Pago vencido", cuerpo: "\(cliente) no ha pagado \(fmt(monto)). Recuerda avisar."),
        ]

        for r in recs {
            guard let disparo = cal.date(byAdding: .day, value: r.offset, to: baseDate),
                  disparo > Date() else { continue }
            let content = UNMutableNotificationContent()
            content.title = "🐼 \(r.titulo)"
            content.body = r.cuerpo
            content.sound = .default
            content.userInfo = ["pagoId": pagoId]
            content.categoryIdentifier = "pago_pendiente"

            let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: disparo)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let req = UNNotificationRequest(
                identifier: identificador(pagoId: pagoId, offset: r.offset),
                content: content, trigger: trigger
            )
            try? await UNUserNotificationCenter.current().add(req)
        }
    }

    static func cancelarRecordatorio(pagoId: Int) {
        let ids = [-1, 0, 1].map { identificador(pagoId: pagoId, offset: $0) }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    /// Programa recordatorios para todos los pagos pendientes en batch.
    static func programarTodos(pagos: [(id: Int, cliente: String, monto: Double, fecha: Date)]) async -> Int {
        let ok = await requestPermission()
        guard ok else { return 0 }
        var count = 0
        for p in pagos where p.fecha > Date().addingTimeInterval(-86400) {
            await programarRecordatorio(pagoId: p.id, cliente: p.cliente, monto: p.monto, fechaProgramada: p.fecha)
            count += 1
        }
        return count
    }

    private static func identificador(pagoId: Int, offset: Int) -> String {
        "pago_\(pagoId)_off\(offset)"
    }

    private static func fmt(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency; f.currencyCode = "MXN"; f.maximumFractionDigits = 0
        f.locale = Locale(identifier: "es_MX")
        return f.string(from: NSNumber(value: v)) ?? "$0"
    }
}
