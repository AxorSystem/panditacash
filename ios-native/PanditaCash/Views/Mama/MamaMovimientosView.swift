import SwiftUI

@MainActor
final class MovimientosVM: ObservableObject {
    @Published var resp: MovimientosResp?
    @Published var loading = false
    @Published var desde: Date? = nil
    @Published var hasta: Date? = nil

    func load() async {
        loading = true; defer { loading = false }
        if ProcessInfo.processInfo.environment["FAKE_DATA_ONLY"] == "1" {
            resp = Self.mock
            return
        }
        var q: [String: String] = ["limit": "200"]
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        if let d = desde { q["desde"] = df.string(from: d) }
        if let h = hasta { q["hasta"] = df.string(from: h) }
        let real: MovimientosResp? = try? await APIClient.shared.get("movimientos", query: q)
        if let r = real {
            resp = r
        } else if ProcessInfo.processInfo.environment["FAKE_DATA"] == "1" {
            resp = Self.mock
        }
    }

    static let mock = MovimientosResp(
        stats: MovimientosStats(totalCapital: 22000, totalMora: 2500, totalPerdonado: 0, nMovimientos: 18),
        movimientos: [
            .init(id: 1, prestamoId: 10, clienteNombre: "María González", clienteTelefono: "5551234567", montoCapital: 1500, montoMora: 0, moraPerdonada: nil, metodo: "efectivo", notas: nil, fechaPago: "2026-07-21", createdAt: nil),
            .init(id: 2, prestamoId: 11, clienteNombre: "Roberto Sánchez", clienteTelefono: "5559876543", montoCapital: 2000, montoMora: 200, moraPerdonada: nil, metodo: "transferencia", notas: nil, fechaPago: "2026-07-21", createdAt: nil),
            .init(id: 3, prestamoId: 12, clienteNombre: "Ana López", clienteTelefono: "5552345678", montoCapital: 800, montoMora: 0, moraPerdonada: nil, metodo: "deposito", notas: nil, fechaPago: "2026-07-20", createdAt: nil),
            .init(id: 4, prestamoId: 10, clienteNombre: "Lucía Torres", clienteTelefono: "5554567890", montoCapital: 500, montoMora: 100, moraPerdonada: nil, metodo: "efectivo", notas: nil, fechaPago: "2026-07-20", createdAt: nil),
        ]
    )
}

struct MamaMovimientosView: View {
    @StateObject var vm = MovimientosVM()

    var body: some View {
        ZStack(alignment: .top) {
            Theme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Historial").font(PType.title(28)).foregroundColor(Theme.ink)
                        Text("Todos los cobros registrados").font(PType.body(13)).foregroundColor(Theme.inkSoft)
                    }
                    .padding(.top, 12)
                    .padding(.horizontal, 20)

                    rangoFechasBar.padding(.horizontal, 20)

                    if let s = vm.resp?.stats {
                        statsPanel(s).padding(.horizontal, 20).padding(.top, 4)
                    }

                    if let mov = vm.resp?.movimientos, !mov.isEmpty {
                        listaAgrupada(mov).padding(.horizontal, 20)
                    } else if vm.loading {
                        ForEach(0..<5, id: \.self) { _ in SkeletonClienteRow() }
                            .padding(.horizontal, 20)
                    } else {
                        VStack(spacing: 10) {
                            Image(systemName: "tray").font(.system(size: 44, weight: .light)).foregroundColor(Theme.inkMuted)
                            Text("Sin movimientos aún").font(PType.heading(16)).foregroundColor(Theme.ink)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    }
                    Spacer(minLength: 120)
                }
            }
            .refreshable { await vm.load() }
            .task { await vm.load() }
            .onAppear { Task { await vm.load() } }
            .onReceive(NotificationCenter.default.publisher(for: AppEvent.prestamosChanged)) { _ in
                Task { await vm.load() }
            }
        }
    }

    var rangoFechasBar: some View {
        HStack(spacing: 8) {
            chip(label: "Hoy") { setRango(dias: 0) }
            chip(label: "7d") { setRango(dias: 7) }
            chip(label: "30d") { setRango(dias: 30) }
            chip(label: "Mes") { setMesActual() }
            if vm.desde != nil || vm.hasta != nil {
                Button {
                    Haptics.tap(); vm.desde = nil; vm.hasta = nil
                    Task { await vm.load() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark").font(.system(size: 10, weight: .bold))
                        Text("Todo").font(PType.bodyBold(12))
                    }
                    .foregroundColor(Theme.deepGreen)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Capsule().fill(Theme.softPrimary))
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func chip(label: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap(); action()
        } label: {
            Text(label).font(PType.bodyBold(12))
                .foregroundColor(.white)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Capsule().fill(Theme.deepGreen))
        }
    }

    private func setRango(dias: Int) {
        let cal = Calendar.current
        vm.hasta = Date()
        vm.desde = cal.date(byAdding: .day, value: -dias, to: Date())
        Task { await vm.load() }
    }

    private func setMesActual() {
        let cal = Calendar.current
        let now = Date()
        let comps = cal.dateComponents([.year, .month], from: now)
        vm.desde = cal.date(from: comps)
        vm.hasta = now
        Task { await vm.load() }
    }

    func statsPanel(_ s: MovimientosStats) -> some View {
        MetallicHeroCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("TOTAL COBRADO").tracking(1.5).font(PType.caption(10)).foregroundColor(.white.opacity(0.65))
                Text(MoneyFormat.mxn(s.totalCobrado)).font(PType.display(32)).foregroundColor(.white)
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Capital").font(PType.caption(11)).foregroundColor(.white.opacity(0.6))
                        Text(MoneyFormat.mxn(s.totalCapital)).font(PType.number(16)).foregroundColor(.white)
                    }
                    Divider().frame(width: 1, height: 26).background(.white.opacity(0.15))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Mora").font(PType.caption(11)).foregroundColor(.white.opacity(0.6))
                        Text(MoneyFormat.mxn(s.totalMora)).font(PType.number(16)).foregroundColor(.white)
                    }
                    Spacer()
                    Text("\(s.nMovimientos)")
                        .font(PType.number(20))
                        .foregroundColor(.white.opacity(0.85))
                }
                .padding(.top, 4)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    func listaAgrupada(_ mov: [Movimiento]) -> some View {
        let grupos = Dictionary(grouping: mov, by: { fechaCorta($0.fechaPago) })
        let ordenados = grupos.keys.sorted(by: >)
        return VStack(alignment: .leading, spacing: 20) {
            ForEach(ordenados, id: \.self) { fecha in
                VStack(alignment: .leading, spacing: 10) {
                    Text(fechaLarga(fecha).uppercased())
                        .font(PType.caption(10))
                        .tracking(1.2)
                        .foregroundColor(Theme.deepGreen)
                    ForEach(grupos[fecha] ?? []) { m in
                        MovimientoRow(mov: m)
                    }
                }
            }
        }
    }

    func fechaCorta(_ s: String) -> String { String(s.prefix(10)) }
    func fechaLarga(_ s: String) -> String {
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"; df.locale = Locale(identifier: "es_MX")
        guard let d = df.date(from: s) else { return s }
        let out = DateFormatter(); out.dateFormat = "EEEE d 'de' MMMM"; out.locale = Locale(identifier: "es_MX")
        return out.string(from: d).capitalized
    }
}

struct MovimientoRow: View {
    let mov: Movimiento
    var onDeleted: (() -> Void)? = nil
    var total: Double { mov.montoCapital + mov.montoMora }
    @EnvironmentObject var toast: ToastCenter
    @State private var confirmDelete = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(iconTint.opacity(0.15)).frame(width: 42, height: 42)
                Image(systemName: iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(iconTint)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(mov.clienteNombre ?? "Cliente").font(PType.bodyBold(14)).foregroundColor(Theme.ink).lineLimit(1)
                HStack(spacing: 6) {
                    Text(metodoLabel).font(PType.caption(11)).foregroundColor(Theme.inkSoft)
                    if mov.montoMora > 0 {
                        Text("· mora \(MoneyFormat.mxn(mov.montoMora))")
                            .font(PType.caption(11))
                            .foregroundColor(Theme.danger)
                    }
                }
            }
            Spacer()
            Text("+" + MoneyFormat.mxn(total))
                .font(PType.number(16))
                .foregroundColor(Theme.success)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.surfaceLight))
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) { confirmDelete = true } label: {
                Label("Anular", systemImage: "trash")
            }
        }
        .contextMenu {
            Button(role: .destructive) { confirmDelete = true } label: {
                Label("Anular cobro", systemImage: "trash")
            }
        }
        .alert("¿Anular este cobro?", isPresented: $confirmDelete) {
            Button("Cancelar", role: .cancel) {}
            Button("Anular", role: .destructive) { Task { await anular() } }
        } message: {
            Text("Se revertirá el pago (\(MoneyFormat.mxn(total))) al estado 'pendiente'. Esta acción no se puede deshacer.")
        }
    }

    private func anular() async {
        do {
            struct R: Decodable {}
            let _: R = try await APIClient.shared.delete("movimientos/\(mov.id)")
            Haptics.warning()
            toast.show("Cobro anulado", kind: .info)
            AppEvent.post(AppEvent.prestamosChanged)
            onDeleted?()
        } catch {
            toast.show((error as? APIError)?.errorDescription ?? "Error", kind: .error)
        }
    }

    var metodoLabel: String {
        switch mov.metodo {
        case "efectivo": "Efectivo"
        case "transferencia": "Transferencia"
        case "deposito": "Depósito"
        case "retencion": "Retención"
        default: "Otro"
        }
    }
    var iconName: String {
        switch mov.metodo {
        case "efectivo": "banknote"
        case "transferencia": "arrow.left.arrow.right"
        case "deposito": "building.columns.fill"
        default: "circle.grid.cross"
        }
    }
    var iconTint: Color {
        switch mov.metodo {
        case "efectivo": Theme.success
        case "transferencia": Theme.info
        case "deposito": Theme.secondary
        default: Theme.inkMuted
        }
    }
}
