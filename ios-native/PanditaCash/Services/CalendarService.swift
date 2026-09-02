import Foundation
import EventKit

enum CalendarService {
    static let store = EKEventStore()

    /// Devuelve cuántos eventos se agregaron. 0 = sin permisos o sin eventos válidos.
    static func addEvents(titulo: String, fechas: [Date], notas: String? = nil) async -> Int {
        let granted = await requestAccess()
        guard granted else { return 0 }
        guard let cal = store.defaultCalendarForNewEvents else { return 0 }
        var count = 0
        for fecha in fechas {
            let ev = EKEvent(eventStore: store)
            ev.title = titulo
            ev.calendar = cal
            ev.startDate = fecha
            ev.endDate = fecha.addingTimeInterval(3600)
            ev.notes = notas
            ev.addAlarm(EKAlarm(relativeOffset: -60 * 60 * 24)) // 1 día antes
            do {
                try store.save(ev, span: .thisEvent)
                count += 1
            } catch {
                // ignora individual, sigue con siguiente
            }
        }
        return count
    }

    static func parseFecha(_ iso: String) -> Date? {
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        let d = df.date(from: String(iso.prefix(10)))
        // Ajusta a 10am hora local para que la notif se dispare a hora razonable
        guard let base = d else { return nil }
        return Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: base) ?? base
    }

    private static func requestAccess() async -> Bool {
        if #available(iOS 17.0, *) {
            return (try? await store.requestWriteOnlyAccessToEvents()) ?? false
        } else {
            return await withCheckedContinuation { cont in
                store.requestAccess(to: .event) { granted, _ in cont.resume(returning: granted) }
            }
        }
    }
}
