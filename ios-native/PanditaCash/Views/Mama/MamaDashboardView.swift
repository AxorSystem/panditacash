import SwiftUI
import UIKit

@MainActor
final class DashboardVM: ObservableObject {
    @Published var dashboard: Dashboard?
    @Published var loading = false
    @Published var errorMsg: String?

    func load() async {
        loading = true; defer { loading = false }
        if ProcessInfo.processInfo.environment["FAKE_DATA_ONLY"] == "1" {
            dashboard = Self.mock
            return
        }
        do {
            dashboard = try await APIClient.shared.get("prestamos/dashboard")
            errorMsg = nil
        } catch {
            errorMsg = (error as? APIError)?.errorDescription ?? error.localizedDescription
            if ProcessInfo.processInfo.environment["FAKE_DATA"] == "1" {
                dashboard = Self.mock
            }
        }
    }

    static let empty = Dashboard(
        stats: Stats(totalVencidos: 0, totalHoy: 0, totalProximos7d: 0, totalPrestadoActivo: 0, clientesActivos: 0, pagosVencidos: 0),
        pagosPendientes: [], solicitudesPendientes: nil
    )

    static let mock = Dashboard(
        stats: Stats(totalVencidos: 3500, totalHoy: 1200, totalProximos7d: 8500, totalPrestadoActivo: 47500, clientesActivos: 12, pagosVencidos: 2),
        pagosPendientes: [
            .init(id: 1, prestamoId: 10, clienteId: 1, clienteNombre: "María González", clienteTelefono: "5551234567", numeroPago: 2, montoEsperado: 1500, montoPagadoCapital: nil, montoPagadoMora: nil, fechaProgramada: "2026-07-22", estado: "pendiente", diasVencido: nil, moraCalculada: nil, urgencia: nil, totalPendiente: nil),
            .init(id: 2, prestamoId: 11, clienteId: 2, clienteNombre: "Roberto Sánchez", clienteTelefono: "5559876543", numeroPago: 3, montoEsperado: 2200, montoPagadoCapital: nil, montoPagadoMora: nil, fechaProgramada: "2026-07-18", estado: "vencido", diasVencido: 3, moraCalculada: 66, urgencia: nil, totalPendiente: nil),
            .init(id: 3, prestamoId: 12, clienteId: 3, clienteNombre: "Ana López", clienteTelefono: "5552345678", numeroPago: 1, montoEsperado: 3800, montoPagadoCapital: nil, montoPagadoMora: nil, fechaProgramada: "2026-07-23", estado: "pendiente", diasVencido: nil, moraCalculada: nil, urgencia: nil, totalPendiente: nil),
        ],
        solicitudesPendientes: [
            .init(id: 5, usuarioId: 4, clienteNombre: "Carlos Ramírez", clienteTelefono: "5553456789", montoSolicitado: 8000, plazoMeses: 6, motivo: "Emergencia médica", createdAt: "2026-07-20"),
        ]
    )
}

struct MamaDashboardView: View {
    @StateObject var vm = DashboardVM()
    @EnvironmentObject var auth: AuthStore
    @State private var showNewPrestamo = false
    @State private var solicitudSel: SolicitudPendiente?
    @State private var showBusqueda = false
    @EnvironmentObject var toast: ToastCenter

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    headerBar
                        .padding(.top, 12)

                    saludoBlock

                    Button {
                        Haptics.tap(); showBusqueda = true
                    } label: {
                        searchBarFake
                    }
                    .buttonStyle(.plain)

                    kpisRow

                    if let d = vm.dashboard {
                        heroCard(d.stats)

                        pagosPendientesSection(d.pagosPendientes)
                        if let sols = d.solicitudesPendientes, !sols.isEmpty {
                            solicitudesSection(sols)
                        }
                    } else if vm.loading {
                        RoundedRectangle(cornerRadius: 32).fill(Theme.surfaceLight).frame(height: 260)
                    }

                    Spacer(minLength: 120)
                }
                .padding(.horizontal, 20)
            }
            .refreshable { await vm.load() }
            .task { await vm.load() }
            .onAppear { Task { await vm.load() } }
        }
        .sheet(isPresented: $showNewPrestamo) { NuevoPrestamoView() }
        .sheet(item: $solicitudSel) { s in SolicitudResponderView(solicitud: s) }
        .sheet(isPresented: $showBusqueda) { BusquedaGlobalView() }
        .onChange(of: showNewPrestamo) { _, isShowing in
            if !isShowing { Task { await vm.load() } }
        }
        .onChange(of: solicitudSel) { _, sel in
            if sel == nil { Task { await vm.load() } }
        }
        .onReceive(NotificationCenter.default.publisher(for: AppEvent.prestamosChanged)) { _ in
            Task { await vm.load() }
        }
        .onReceive(NotificationCenter.default.publisher(for: AppEvent.solicitudesChanged)) { _ in
            Task { await vm.load() }
        }
    }

    var headerBar: some View {
        HStack {
            // Logo
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.deepGreen)
                    .frame(width: 42, height: 42)
                Text("🐼").font(.system(size: 24))
            }
            Spacer()
            HStack(spacing: 10) {
                NavigationLink {
                    MamaKYCPendientesView()
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "shield.checkered")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Theme.deepGreen)
                            .frame(width: 42, height: 42)
                            .background(Circle().fill(Theme.surfaceLight))
                    }
                }
                Button {
                    Haptics.tap(); auth.signOut()
                } label: {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Theme.deepGreen)
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(Theme.surfaceLight))
                }
                .buttonStyle(PressableStyle())
            }
        }
    }

    var saludoBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(saludo).font(PType.body(15)).foregroundColor(Theme.inkSoft)
            }
            if case .signedIn(let u) = auth.state {
                Text(u.nombre.split(separator: " ").first.map(String.init) ?? u.nombre)
                    .font(PType.title(34))
                    .foregroundColor(Theme.ink)
                    .accessibilityIdentifier("dashboard_nombre")
                Text("Panel de control")
                    .font(PType.body(15))
                    .foregroundColor(Theme.inkSoft)
                    .accessibilityIdentifier("dashboard_subtitle")
            }
        }
    }

    var saludo: String {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 5..<12: return "Buenos días,"
        case 12..<19: return "Buenas tardes,"
        default: return "Buenas noches,"
        }
    }

    var searchBarFake: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Theme.inkMuted)
            Text("Buscar cliente…")
                .font(PType.body(14))
                .foregroundColor(Theme.inkMuted)
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(Capsule().fill(Theme.surfaceLight))
    }

    var kpisRow: some View {
        HStack(spacing: 12) {
            KpiPastel(title: "Vencidos", value: vm.dashboard?.stats.totalVencidos ?? 0, unit: "$", icon: "arrow.up.right", tint: Theme.deepGreen)
            KpiPastel(title: "Hoy", value: vm.dashboard?.stats.totalHoy ?? 0, unit: "$", icon: "arrow.up.left.and.arrow.down.right", tint: Theme.deepGreen)
        }
    }

    // MARK: Hero card (verde oscuro tipo real estate)

    func heroCard(_ s: Stats) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                HStack(spacing: 8) {
                    ZStack {
                        Hexagon().fill(Color.white.opacity(0.15)).frame(width: 34, height: 34)
                        Image(systemName: "banknote.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Prestado activo")
                            .font(PType.bodyBold(15))
                            .foregroundColor(.white)
                        Text("\(s.clientesActivos) clientes · \(s.pagosVencidos) vencidos")
                            .font(PType.caption(12))
                            .foregroundColor(.white.opacity(0.82))
                    }
                }
                Spacer()
            }

            Text(MoneyFormat.mxn(s.totalPrestadoActivo))
                .font(PType.display(42))
                .foregroundColor(.white)

            HStack(spacing: 8) {
                heroSubStat("Por 7 días", value: MoneyFormat.mxn(s.totalProximos7d))
                heroSubStat("Vencidos", value: MoneyFormat.mxn(s.totalVencidos))
            }

            Button {
                Haptics.medium()
                showNewPrestamo = true
            } label: {
                HStack {
                    Text("Nuevo préstamo").font(PType.bodyBold(15))
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(Theme.deepGreen)
                .padding(.horizontal, 22).padding(.vertical, 18)
                .background(Capsule().fill(Color.white))
            }
            .buttonStyle(PressableStyle(scale: 0.98))
            .accessibilityIdentifier("cta_nuevo_prestamo")
            .accessibilityLabel("Nuevo préstamo")
            .padding(.top, 4)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Theme.heroPrimary)
        )
    }

    private func programarTodosLosRecordatorios() {
        guard let d = vm.dashboard else { return }
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        let pagos = d.pagosPendientes.compactMap { p -> (Int, String, Double, Date)? in
            guard let f = df.date(from: String(p.fechaProgramada.prefix(10))) else { return nil }
            return (p.id, p.clienteNombre, p.montoEsperado, f)
        }
        Task {
            let n = await LocalNotifService.programarTodos(pagos: pagos)
            await MainActor.run {
                if n > 0 {
                    Haptics.success()
                    toast.show("\(n) recordatorio(s) programado(s)", kind: .success)
                } else {
                    Haptics.error()
                    toast.show("Sin permiso de notificaciones", kind: .error)
                }
            }
        }
    }

    private func recordarVencidos(_ vencidos: [PagoPendiente]) {
        // Abre WA para el primero — el user tap "enviar" y regresa; el flujo bulk se hace uno por uno.
        guard let first = vencidos.first else { return }
        let tel = (first.clienteTelefono ?? "").filter { $0.isNumber }
        let short = tel.count > 10 ? String(tel.suffix(10)) : tel
        let n = first.clienteNombre.split(separator: " ").first.map(String.init) ?? first.clienteNombre
        let d = first.diasVencido ?? 0
        let msg = "Hola \(n), un recordatorio amable: tienes un pago vencido de \(MoneyFormat.mxn(first.montoEsperado)) (\(d) día\(d == 1 ? "" : "s") atrás). ¿Cuándo puedes ponerte al corriente?"
        let enc = msg.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "https://wa.me/52\(short)?text=\(enc)") {
            UIApplication.shared.open(url)
        }
    }

    func heroSubStat(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(PType.caption(11)).foregroundColor(.white.opacity(0.78))
            Text(value).font(PType.number(15)).foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.14)))
    }

    func pagosPendientesSection(_ pagos: [PagoPendiente]) -> some View {
        let vencidos = pagos.filter { ($0.diasVencido ?? 0) > 0 }
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("Pagos pendientes")
                    .font(PType.title(20))
                    .foregroundColor(Theme.ink)
                Spacer(minLength: 0)
                if !pagos.isEmpty {
                    Button {
                        Haptics.tap(); programarTodosLosRecordatorios()
                    } label: {
                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(6)
                            .background(Circle().fill(Theme.deepGreen))
                    }
                }
                if !vencidos.isEmpty {
                    Button {
                        Haptics.medium(); recordarVencidos(vencidos)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "megaphone.fill").font(.system(size: 11, weight: .semibold))
                            Text("Recordar \(vencidos.count)").font(PType.bodyBold(12))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Capsule().fill(Theme.danger))
                    }
                }
            }
            if pagos.isEmpty {
                EmptyStatePill(text: "Todo al corriente")
            } else {
                ForEach(pagos.prefix(6)) { p in
                    NavigationLink {
                        PrestamoDetalleView(prestamoId: p.prestamoId)
                    } label: {
                        PagoPendienteRow(pago: p)
                    }
                    .buttonStyle(PressableStyle(scale: 0.98))
                }
                if pagos.count > 6 {
                    NavigationLink { CobrosHoyView() } label: {
                        HStack {
                            Text("Ver todos los \(pagos.count) pagos").font(PType.bodyBold(13))
                            Spacer()
                            Image(systemName: "arrow.right").font(.system(size: 12, weight: .bold))
                        }
                        .foregroundColor(Theme.deepGreen)
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.softPrimary))
                    }
                }
            }
        }
    }

    func solicitudesSection(_ sols: [SolicitudPendiente]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Solicitudes nuevas").font(PType.title(20)).foregroundColor(Theme.ink)
                Spacer()
                Text("\(sols.count)")
                    .font(PType.caption(12))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10).padding(.vertical, 3)
                    .background(Capsule().fill(Theme.deepGreen))
            }
            ForEach(sols.prefix(5)) { s in
                Button {
                    Haptics.medium()
                    solicitudSel = s
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle().fill(Theme.softPrimary).frame(width: 48, height: 48)
                            Image(systemName: "envelope.badge.fill").font(.system(size: 16, weight: .semibold)).foregroundColor(Theme.deepGreen)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(s.clienteNombre).font(PType.bodyBold(15)).foregroundColor(Theme.ink)
                            Text("\(MoneyFormat.mxn(s.montoSolicitado)) · \(s.plazoMeses) meses")
                                .font(PType.caption(12)).foregroundColor(Theme.inkSoft)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.inkMuted)
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.surfaceLight))
                }
                .buttonStyle(PressableStyle(scale: 0.98))
            }
        }
    }
}

// MARK: - KPI pastel (verde suave con badge)

struct KpiPastel: View {
    let title: String
    let value: Double
    let unit: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title).font(PType.body(13)).foregroundColor(Theme.inkSoft)
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(tint))
            }
            Text(unit + numberFormatted(value))
                .font(PType.display(28))
                .foregroundColor(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Theme.surfaceLight))
    }

    func numberFormatted(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = ","
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: v)) ?? "0"
    }
}

struct PagoPendienteRow: View {
    let pago: PagoPendiente

    var urgencia: (Color, String) {
        let d = pago.diasVencido ?? 0
        if d > 0 { return (Theme.danger, "Vencido \(d)d") }
        return (Theme.deepGreen, "Al día")
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Theme.softPrimary).frame(width: 48, height: 48)
                Text(String(pago.clienteNombre.prefix(1).uppercased()))
                    .font(PType.bodyBold(17))
                    .foregroundColor(Theme.deepGreen)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(pago.clienteNombre).font(PType.bodyBold(15)).foregroundColor(Theme.ink).lineLimit(1)
                Text(urgencia.1).font(PType.caption(11)).foregroundColor(urgencia.0)
            }
            Spacer(minLength: 8)
            Text(MoneyFormat.mxn(pago.montoEsperado))
                .font(PType.number(16))
                .foregroundColor(Theme.ink)
            Button {
                Haptics.tap(); abrirWA()
            } label: {
                Image(systemName: "message.badge.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Theme.deepGreen))
            }
            .buttonStyle(PressableStyle(scale: 0.9))
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.surfaceLight))
    }

    private func abrirWA() {
        let raw = (pago.clienteTelefono ?? "").filter { $0.isNumber }
        let tel = raw.count > 10 ? String(raw.suffix(10)) : raw
        let d = pago.diasVencido ?? 0
        let hola = d > 0
            ? "Hola \(pago.clienteNombre.split(separator: " ").first.map(String.init) ?? pago.clienteNombre), un recordatorio amable: tienes un pago vencido de \(MoneyFormat.mxn(pago.montoEsperado)) (\(d) día\(d == 1 ? "" : "s") atrás). ¿Cuándo puedes ponerte al corriente?"
            : "Hola \(pago.clienteNombre.split(separator: " ").first.map(String.init) ?? pago.clienteNombre), recordatorio: tu próximo pago de \(MoneyFormat.mxn(pago.montoEsperado)) vence pronto. Cualquier duda me avisas."
        let enc = hola.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "https://wa.me/52\(tel)?text=\(enc)") {
            UIApplication.shared.open(url)
        }
    }
}

struct EmptyStatePill: View {
    let text: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Theme.deepGreen)
            Text(text)
                .font(PType.bodyBold(14))
                .foregroundColor(Theme.ink)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.softPrimary))
    }
}

struct SkeletonKPIsGrid: View {
    @State private var shimmer = false
    var body: some View {
        VStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 32).fill(shimmerColor).frame(height: 200)
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 24).fill(shimmerColor).frame(height: 100)
                RoundedRectangle(cornerRadius: 24).fill(shimmerColor).frame(height: 100)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: true)) { shimmer.toggle() }
        }
    }
    var shimmerColor: Color { shimmer ? Theme.surfaceLight : Theme.softPrimary }
}

struct Hexagon: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height
        path.move(to: CGPoint(x: w * 0.5, y: 0))
        path.addLine(to: CGPoint(x: w, y: h * 0.25))
        path.addLine(to: CGPoint(x: w, y: h * 0.75))
        path.addLine(to: CGPoint(x: w * 0.5, y: h))
        path.addLine(to: CGPoint(x: 0, y: h * 0.75))
        path.addLine(to: CGPoint(x: 0, y: h * 0.25))
        path.closeSubpath()
        return path
    }
}

// Compat con vistas existentes (usadas por Movimientos)
struct MiniKPI: View {
    let title: String
    let value: String
    let tint: Color
    let icon: String
    var full: Bool = false
    var body: some View {
        KpiPastelCompat(title: title, value: value, icon: icon, tint: tint)
    }
}

struct KpiPastelCompat: View {
    let title: String
    let value: String
    let icon: String
    let tint: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title.uppercased())
                    .font(PType.caption(10))
                    .foregroundColor(Theme.inkSoft)
                    .tracking(0.6)
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(tint))
            }
            Text(value).font(PType.number(18)).foregroundColor(Theme.ink)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.surfaceLight))
    }
}

enum MoneyFormat {
    static func mxn(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "MXN"
        f.maximumFractionDigits = 0
        f.locale = Locale(identifier: "es_MX")
        return f.string(from: NSNumber(value: v)) ?? "$0"
    }
}
