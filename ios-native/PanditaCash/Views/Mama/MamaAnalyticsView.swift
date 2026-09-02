import SwiftUI

struct AnalyticsResp: Codable {
    let totales: AnalyticsTotales?
    let porMes: [MesData]?
    let topDeuda: [TopDeudor]?

    // Aliases para código antiguo
    var totalCobrado: Double? { totales?.totalCobrado }
    var gananciaNeta: Double? { totales?.gananciaNeta }
    var gananciaPendiente: Double? { totales?.gananciaPendiente }
    var totalPrestadoActivo: Double? { totales?.prestadoActivo }
    var totalMoraCobrada: Double? { totales?.totalMora }
    var topDeudores: [TopDeudor]? { topDeuda }

    enum CodingKeys: String, CodingKey {
        case totales
        case porMes = "por_mes"
        case topDeuda = "top_deuda"
    }
}

struct AnalyticsTotales: Codable {
    let prestadoActivo: Double?
    let totalCapital: Double?
    let totalMora: Double?
    let totalCobrado: Double?
    let gananciaNeta: Double?
    let gananciaPendiente: Double?
    let clientesActivos: Int?
    let prestamosActivos: Int?

    enum CodingKeys: String, CodingKey {
        case prestadoActivo = "prestado_activo"
        case totalCapital = "total_capital"
        case totalMora = "total_mora"
        case totalCobrado = "total_cobrado"
        case gananciaNeta = "ganancia_neta"
        case gananciaPendiente = "ganancia_pendiente"
        case clientesActivos = "clientes_activos"
        case prestamosActivos = "prestamos_activos"
    }
}

struct MesData: Codable, Identifiable {
    let anio: Int?
    let mes: Int?
    let capital: Double?
    let mora: Double?
    let movimientos: Int?

    var id: String { "\(anio ?? 0)-\(mes ?? 0)" }
    var cobrado: Double { (capital ?? 0) + (mora ?? 0) }
    var mesLabel: String {
        guard let m = mes else { return "?" }
        return String(format: "%02d", m)
    }
}

struct TopDeudor: Codable, Identifiable {
    let usuarioId: Int
    let nombre: String
    let telefono: String
    let saldo: Double

    var id: Int { usuarioId }

    enum CodingKeys: String, CodingKey {
        case usuarioId = "usuario_id"
        case nombre, telefono, saldo
    }
}

@MainActor
final class AnalyticsVM: ObservableObject {
    @Published var resp: AnalyticsResp?
    @Published var loading = false
    @Published var errorMsg: String?

    func load() async {
        loading = true; defer { loading = false }
        if ProcessInfo.processInfo.environment["FAKE_DATA_ONLY"] == "1" {
            resp = Self.mock
            return
        }
        do {
            resp = try await APIClient.shared.get("analytics")
            errorMsg = nil
        } catch {
            errorMsg = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    static let mock = AnalyticsResp(
        totales: AnalyticsTotales(
            prestadoActivo: 62000, totalCapital: 22000, totalMora: 2500,
            totalCobrado: 24500, gananciaNeta: 8500, gananciaPendiente: 6800,
            clientesActivos: 12, prestamosActivos: 14
        ),
        porMes: [
            MesData(anio: 2026, mes: 5, capital: 6800, mora: 400, movimientos: 5),
            MesData(anio: 2026, mes: 6, capital: 7200, mora: 800, movimientos: 6),
            MesData(anio: 2026, mes: 7, capital: 8000, mora: 1300, movimientos: 7),
        ],
        topDeuda: [
            TopDeudor(usuarioId: 2, nombre: "abdo", telefono: "527341682051", saldo: 62000),
        ]
    )
}

struct MamaAnalyticsView: View {
    @StateObject var vm = AnalyticsVM()
    @State private var shareURL: URL?

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header.padding(.horizontal, 20).padding(.top, 12)

                    if let r = vm.resp {
                        heroCard(r).padding(.horizontal, 20)
                        kpisRow(r).padding(.horizontal, 20)
                        recuperacionRing(r).padding(.horizontal, 20)
                        ComparativaCard().padding(.horizontal, 20)
                        MetodosPagoCard().padding(.horizontal, 20)
                        if let meses = r.porMes, !meses.isEmpty {
                            chartCard(meses).padding(.horizontal, 20)
                        }
                        if let top = r.topDeudores, !top.isEmpty {
                            topDeudoresSection(top).padding(.horizontal, 20)
                        }
                    } else if vm.loading {
                        ProgressView().tint(Theme.deepGreen).padding(.top, 100)
                    }
                    Spacer(minLength: 120)
                }
            }
            .refreshable { await vm.load() }
            .task { await vm.load() }
        }
        .navigationTitle("Ganancias")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if let r = vm.resp { shareURL = exportarAnalytics(r) }
                } label: {
                    Image(systemName: "square.and.arrow.up").foregroundColor(Theme.deepGreen)
                }
                .disabled(vm.resp == nil)
            }
        }
        .sheet(item: $shareURL) { u in ShareSheet(items: [u]) }
    }

    private func exportarAnalytics(_ r: AnalyticsResp) -> URL? {
        var csv = "Sección,Métrica,Valor\n"
        if let t = r.totales {
            csv.append("Totales,Prestado activo,\(t.prestadoActivo ?? 0)\n")
            csv.append("Totales,Total cobrado,\(t.totalCobrado ?? 0)\n")
            csv.append("Totales,Ganancia neta,\(t.gananciaNeta ?? 0)\n")
            csv.append("Totales,Ganancia pendiente,\(t.gananciaPendiente ?? 0)\n")
            csv.append("Totales,Total mora cobrada,\(t.totalMora ?? 0)\n")
            csv.append("Totales,Clientes activos,\(t.clientesActivos ?? 0)\n")
            csv.append("Totales,Préstamos activos,\(t.prestamosActivos ?? 0)\n")
        }
        csv.append("\nMes,Año,Capital,Mora,Movimientos\n")
        for m in r.porMes ?? [] {
            csv.append("\(m.mes ?? 0),\(m.anio ?? 0),\(m.capital ?? 0),\(m.mora ?? 0),\(m.movimientos ?? 0)\n")
        }
        csv.append("\nTop deudores\nCliente,Teléfono,Saldo\n")
        for d in r.topDeudores ?? [] {
            let n = d.nombre.replacingOccurrences(of: ",", with: ";")
            csv.append("\(n),\(d.telefono),\(d.saldo)\n")
        }
        let name = "panditacash_analytics_\(Int(Date().timeIntervalSince1970)).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do { try csv.data(using: .utf8)?.write(to: url); return url } catch { return nil }
    }

    var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Ganancias").font(PType.title(28)).foregroundColor(Theme.ink)
            Text("Análisis de tu negocio").font(PType.body(13)).foregroundColor(Theme.inkSoft)
        }
    }

    func heroCard(_ r: AnalyticsResp) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("GANANCIA NETA").tracking(1.5).font(PType.caption(10)).foregroundColor(.white.opacity(0.78))
                Spacer()
                Text("Total").font(PType.caption(11)).foregroundColor(.white.opacity(0.78))
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Capsule().fill(Color.white.opacity(0.12)))
            }
            Text(MoneyFormat.mxn(r.gananciaNeta ?? 0)).font(PType.display(40)).foregroundColor(.white)
            HStack(spacing: 8) {
                heroSub("Total cobrado", MoneyFormat.mxn(r.totalCobrado ?? 0))
                heroSub("Pendiente", MoneyFormat.mxn(r.gananciaPendiente ?? 0))
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Theme.heroPrimary))
    }

    func heroSub(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(PType.caption(11)).foregroundColor(.white.opacity(0.78))
            Text(value).font(PType.bodyBold(14)).foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.14)))
    }

    func kpisRow(_ r: AnalyticsResp) -> some View {
        HStack(spacing: 12) {
            KpiPastel(title: "Prestado activo", value: r.totalPrestadoActivo ?? 0, unit: "$", icon: "banknote", tint: Theme.deepGreen)
            KpiPastel(title: "Mora cobrada", value: r.totalMoraCobrada ?? 0, unit: "$", icon: "clock", tint: Theme.deepGreen)
        }
    }

    func recuperacionRing(_ r: AnalyticsResp) -> some View {
        let cobrado = r.totalCobrado ?? 0
        let prestadoAct = r.totalPrestadoActivo ?? 0
        let totalCiclo = cobrado + prestadoAct
        let tasa = totalCiclo > 0 ? cobrado / totalCiclo : 0
        return HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Theme.softPrimary, lineWidth: 10)
                    .frame(width: 82, height: 82)
                Circle()
                    .trim(from: 0, to: CGFloat(min(max(tasa, 0), 1)))
                    .stroke(Theme.deepGreen, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .frame(width: 82, height: 82)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.7), value: tasa)
                Text(String(format: "%.0f%%", tasa * 100))
                    .font(PType.number(19))
                    .foregroundColor(Theme.ink)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Tasa de recuperación").font(PType.bodyBold(14)).foregroundColor(Theme.ink)
                Text("Del capital total en circulación, ya cobraste \(String(format: "%.0f%%", tasa * 100))")
                    .font(PType.caption(12))
                    .foregroundColor(Theme.inkSoft)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.surfaceLight))
    }

    func chartCard(_ meses: [MesData]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Cobros por mes").font(PType.heading(16)).foregroundColor(Theme.ink)
            let maxVal = max(meses.map(\.cobrado).max() ?? 1, 1)
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(meses) { m in
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Theme.heroPrimary)
                            .frame(height: max(20, CGFloat(m.cobrado / maxVal) * 140))
                        Text(m.mesLabel).font(PType.caption(9)).foregroundColor(Theme.inkSoft)
                    }
                }
            }
            .frame(height: 170)
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.surfaceLight))
    }

    func mesCorto(_ m: String) -> String {
        String(m.suffix(2))
    }

    // Alias para no romper el chart card que usa `m.mes` como string
    var _mesLabelCompat: Void { () }

    func topDeudoresSection(_ top: [TopDeudor]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top 5 deudores").font(PType.title(20)).foregroundColor(Theme.ink)
            ForEach(top.prefix(5)) { t in
                NavigationLink {
                    ClienteDetalleView(clienteId: t.usuarioId, nombre: t.nombre)
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle().fill(Theme.softPrimary).frame(width: 44, height: 44)
                            Text(String(t.nombre.prefix(1).uppercased()))
                                .font(PType.bodyBold(16)).foregroundColor(Theme.deepGreen)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(t.nombre).font(PType.bodyBold(15)).foregroundColor(Theme.ink)
                            Text(t.telefono).font(PType.caption(11)).foregroundColor(Theme.inkSoft)
                        }
                        Spacer()
                        Text(MoneyFormat.mxn(t.saldo)).font(PType.number(15)).foregroundColor(Theme.danger)
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 20).fill(Theme.surfaceLight))
                }
                .buttonStyle(PressableStyle(scale: 0.98))
            }
        }
    }
}
