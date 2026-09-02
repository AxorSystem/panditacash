import SwiftUI

struct NotificacionItem: Codable, Identifiable {
    let id: Int
    let tipo: String
    let canal: String?
    let mensaje: String
    let refPrestamo: Int?
    let refPago: Int?
    let enviadoAt: String
    let exito: Bool
    let telefono: String?

    enum CodingKeys: String, CodingKey {
        case id, tipo, canal, mensaje, exito, telefono
        case refPrestamo = "ref_prestamo"
        case refPago = "ref_pago"
        case enviadoAt = "enviado_at"
    }
}

@MainActor
final class NotificacionesVM: ObservableObject {
    @Published var items: [NotificacionItem] = []
    @Published var loading = false

    func load() async {
        loading = true; defer { loading = false }
        items = (try? await APIClient.shared.get("mi/notificaciones")) ?? []
    }
}

struct NotificacionesView: View {
    @StateObject var vm = NotificacionesVM()

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                LazyVStack(spacing: 10) {
                    if vm.loading && vm.items.isEmpty {
                        ProgressView().tint(Theme.deepGreen).padding(.top, 60)
                    } else if vm.items.isEmpty {
                        empty.padding(.top, 60)
                    } else {
                        ForEach(vm.items) { n in
                            NotifRow(item: n)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 100)
            }
            .refreshable { await vm.load() }
            .task { await vm.load() }
        }
        .navigationTitle("Notificaciones")
        .navigationBarTitleDisplayMode(.inline)
    }

    var empty: some View {
        VStack(spacing: 10) {
            Image(systemName: "bell.slash").font(.system(size: 44)).foregroundColor(Theme.inkMuted)
            Text("Sin notificaciones aún").font(PType.heading(15)).foregroundColor(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity)
    }
}

struct NotifRow: View {
    let item: NotificacionItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(tipoColor.opacity(0.15)).frame(width: 38, height: 38)
                Image(systemName: tipoIcon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(tipoColor)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(tipoLabel).font(PType.bodyBold(13)).foregroundColor(Theme.ink)
                Text(item.mensaje).font(PType.body(13)).foregroundColor(Theme.inkSoft).lineLimit(3)
                Text(formatDate(item.enviadoAt))
                    .font(PType.caption(11)).foregroundColor(Theme.inkMuted)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.surfaceLight))
    }

    var tipoLabel: String {
        switch item.tipo {
        case "vence_pronto": "Vence pronto"
        case "vence_hoy": "Vence hoy"
        case "vencido": "Pago vencido"
        case "nuevo_prestamo": "Nuevo préstamo"
        case "pago_registrado": "Pago registrado"
        case "solicitud_recibida": "Solicitud recibida"
        default: item.tipo.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    var tipoIcon: String {
        switch item.tipo {
        case "vencido": "exclamationmark.triangle.fill"
        case "vence_pronto", "vence_hoy": "clock.fill"
        case "pago_registrado": "checkmark.circle.fill"
        case "nuevo_prestamo": "banknote.fill"
        case "solicitud_recibida": "envelope.fill"
        default: "bell.fill"
        }
    }

    var tipoColor: Color {
        switch item.tipo {
        case "vencido": Theme.danger
        case "vence_pronto", "vence_hoy": Theme.warning
        case "pago_registrado": Theme.success
        default: Theme.deepGreen
        }
    }

    func formatDate(_ iso: String) -> String {
        let df = ISO8601DateFormatter()
        df.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let d = df.date(from: iso) ?? ISO8601DateFormatter().date(from: iso)
        guard let d else { return iso }
        let rel = RelativeDateTimeFormatter()
        rel.unitsStyle = .short
        rel.locale = Locale(identifier: "es_MX")
        return rel.localizedString(for: d, relativeTo: Date())
    }
}
