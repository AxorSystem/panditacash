import SwiftUI

struct MiSolicitud: Codable, Identifiable {
    let id: Int
    let montoSolicitado: Double
    let plazoMeses: Int
    let motivo: String?
    let estado: String
    let respuestaNotas: String?
    let respondidoAt: String?
    let createdAt: String?
    let prestamoId: Int?

    enum CodingKeys: String, CodingKey {
        case id, motivo, estado
        case montoSolicitado = "monto_solicitado"
        case plazoMeses = "plazo_meses"
        case respuestaNotas = "respuesta_notas"
        case respondidoAt = "respondido_at"
        case createdAt = "created_at"
        case prestamoId = "prestamo_id"
    }
}

@MainActor
final class MisSolicitudesVM: ObservableObject {
    @Published var solicitudes: [MiSolicitud] = []
    @Published var loading = false

    func load() async {
        loading = true; defer { loading = false }
        solicitudes = (try? await APIClient.shared.get("solicitudes/mias")) ?? []
    }
}

struct MisSolicitudesView: View {
    @StateObject var vm = MisSolicitudesVM()

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header.padding(.horizontal, 20).padding(.top, 12)

                    if vm.loading && vm.solicitudes.isEmpty {
                        ProgressView().tint(Theme.deepGreen).padding(.top, 60)
                    } else if vm.solicitudes.isEmpty {
                        empty.padding(.top, 60)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(vm.solicitudes) { s in
                                row(s)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    Spacer(minLength: 100)
                }
            }
            .refreshable { await vm.load() }
            .task { await vm.load() }
            .onReceive(NotificationCenter.default.publisher(for: AppEvent.solicitudesChanged)) { _ in
                Task { await vm.load() }
            }
        }
        .navigationTitle("Mis solicitudes")
        .navigationBarTitleDisplayMode(.inline)
    }

    var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Mis solicitudes").font(PType.title(24)).foregroundColor(Theme.ink)
            Text("Historial de peticiones a mamá").font(PType.body(13)).foregroundColor(Theme.inkSoft)
        }
    }

    var empty: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray").font(.system(size: 44, weight: .light)).foregroundColor(Theme.inkMuted)
            Text("Sin solicitudes").font(PType.heading(16)).foregroundColor(Theme.ink)
            Text("No has enviado ninguna solicitud").font(PType.body(13)).foregroundColor(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity)
    }

    func row(_ s: MiSolicitud) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(MoneyFormat.mxn(s.montoSolicitado)).font(PType.number(20)).foregroundColor(Theme.ink)
                Spacer()
                estadoChip(s.estado)
            }
            HStack(spacing: 6) {
                Image(systemName: "calendar").font(.system(size: 10)).foregroundColor(Theme.inkSoft)
                Text("\(s.plazoMeses) meses").font(PType.caption(12)).foregroundColor(Theme.inkSoft)
                if let c = s.createdAt {
                    Text("· \(String(c.prefix(10)))").font(PType.caption(12)).foregroundColor(Theme.inkSoft)
                }
            }
            if let m = s.motivo, !m.isEmpty {
                Text("« \(m) »").font(PType.body(13)).foregroundColor(Theme.inkSoft).italic()
            }
            if let notas = s.respuestaNotas, !notas.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "text.bubble.fill").font(.system(size: 11)).foregroundColor(Theme.deepGreen)
                    Text(notas).font(PType.body(12)).foregroundColor(Theme.ink)
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.softPrimary))
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(Theme.surfaceLight))
    }

    func estadoChip(_ estado: String) -> some View {
        let (color, bg, text, icon) = estadoStyle(estado)
        return HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 10, weight: .semibold))
            Text(text).font(PType.caption(11))
        }
        .foregroundColor(color)
        .padding(.horizontal, 10).padding(.vertical, 4)
        .background(Capsule().fill(bg))
    }

    func estadoStyle(_ e: String) -> (Color, Color, String, String) {
        switch e {
        case "aprobada": (Theme.success, Theme.softSuccess, "Aprobada", "checkmark.circle.fill")
        case "rechazada": (Theme.danger, Theme.softDanger, "Rechazada", "xmark.circle.fill")
        default: (Theme.warning, Theme.softWarning, "Pendiente", "hourglass")
        }
    }
}
