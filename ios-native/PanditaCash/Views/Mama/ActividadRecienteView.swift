import SwiftUI

struct EventoActividad: Codable, Identifiable {
    let tipo: String
    let refId: Int
    let fecha: String
    let clienteNombre: String
    let monto: Double?
    let estado: String?
    let metodo: String?
    let notas: String?

    var id: String { "\(tipo)-\(refId)" }

    enum CodingKeys: String, CodingKey {
        case tipo, fecha, monto, estado, metodo, notas
        case refId = "ref_id"
        case clienteNombre = "cliente_nombre"
    }
}

@MainActor
final class ActividadVM: ObservableObject {
    @Published var eventos: [EventoActividad] = []
    @Published var loading = false

    func load() async {
        loading = true; defer { loading = false }
        eventos = (try? await APIClient.shared.get("analytics/actividad")) ?? []
    }
}

struct ActividadRecienteView: View {
    @StateObject var vm = ActividadVM()

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header.padding(.horizontal, 20).padding(.top, 12)
                    if vm.eventos.isEmpty && vm.loading {
                        ProgressView().tint(Theme.deepGreen).padding(.top, 60)
                    } else if vm.eventos.isEmpty {
                        empty.padding(.top, 60)
                    } else {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(vm.eventos.enumerated()), id: \.element.id) { idx, e in
                                fila(e, isLast: idx == vm.eventos.count - 1)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                    }
                    Spacer(minLength: 80)
                }
            }
            .refreshable { await vm.load() }
            .task { await vm.load() }
        }
        .navigationTitle("Actividad reciente")
        .navigationBarTitleDisplayMode(.inline)
    }

    var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Todo lo que pasa")
                .font(PType.title(24)).foregroundColor(Theme.ink)
            Text("Últimos 40 eventos entre préstamos, cobros y solicitudes")
                .font(PType.body(13)).foregroundColor(Theme.inkSoft)
        }
    }

    var empty: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray").font(.system(size: 40)).foregroundColor(Theme.inkMuted)
            Text("Sin actividad aún").font(PType.heading(15)).foregroundColor(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity)
    }

    private func fila(_ e: EventoActividad, isLast: Bool) -> some View {
        let (color, icon) = estilo(e.tipo)
        return HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                ZStack {
                    Circle().fill(color.opacity(0.15)).frame(width: 36, height: 36)
                    Image(systemName: icon).font(.system(size: 13, weight: .semibold)).foregroundColor(color)
                }
                if !isLast {
                    Rectangle().fill(Theme.hairline).frame(width: 2).frame(maxHeight: .infinity)
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(labelEvento(e)).font(PType.bodyBold(13)).foregroundColor(Theme.ink)
                    Spacer()
                    if let m = e.monto {
                        Text(MoneyFormat.mxn(m)).font(PType.number(13)).foregroundColor(color)
                    }
                }
                Text(e.clienteNombre).font(PType.body(13)).foregroundColor(Theme.inkSoft)
                Text(fechaRelativa(e.fecha)).font(PType.caption(11)).foregroundColor(Theme.inkMuted)
            }
            .padding(.bottom, 14)
        }
    }

    private func labelEvento(_ e: EventoActividad) -> String {
        switch e.tipo {
        case "prestamo": return "Préstamo #\(e.refId) creado"
        case "cobro": return "Cobro registrado" + (e.metodo.map { " · \($0)" } ?? "")
        case "solicitud": return "Solicitud" + (e.estado.map { " (\($0))" } ?? "")
        default: return e.tipo.capitalized
        }
    }

    private func estilo(_ tipo: String) -> (Color, String) {
        switch tipo {
        case "prestamo": (Theme.deepGreen, "banknote.fill")
        case "cobro": (Theme.success, "checkmark.circle.fill")
        case "solicitud": (Theme.info, "envelope.fill")
        default: (Theme.inkSoft, "circle.fill")
        }
    }

    private func fechaRelativa(_ iso: String) -> String {
        let df = ISO8601DateFormatter(); df.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let d = df.date(from: iso) ?? ISO8601DateFormatter().date(from: iso) ?? Date()
        let rel = RelativeDateTimeFormatter()
        rel.unitsStyle = .short; rel.locale = Locale(identifier: "es_MX")
        return rel.localizedString(for: d, relativeTo: Date())
    }
}
