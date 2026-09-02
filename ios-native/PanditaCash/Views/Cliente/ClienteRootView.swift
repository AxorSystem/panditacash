import SwiftUI

@MainActor
final class MiResumenVM: ObservableObject {
    @Published var resumen: MiResumen?
    @Published var loading = false

    func load() async {
        loading = true; defer { loading = false }
        resumen = try? await APIClient.shared.get("mi/resumen")
    }
}

struct ClienteRootView: View {
    @StateObject var vm = MiResumenVM()
    @StateObject var kyc = KYCService.shared
    @EnvironmentObject var auth: AuthStore
    @State private var showSolicitar = false
    @State private var showKyc = false

    var body: some View {
        NavigationStack { content }.tint(Theme.deepGreen)
    }

    var content: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    headerBar.padding(.top, 12)
                    saludoBlock

                    if let r = vm.resumen, let p = r.prestamo {
                        prestamoHero(p)
                        if let prox = r.proximoPago {
                            proximoPagoCard(prox)
                        }
                        if let pagos = r.pagos, !pagos.isEmpty {
                            listaPagos(pagos)
                        }
                    } else {
                        kycOrSolicitarBanner
                        beneficios
                    }
                    Spacer(minLength: 60)
                }
                .padding(.horizontal, 20)
            }
            .refreshable {
                await vm.load()
                await kyc.fetchStatus()
            }
            .task {
                await vm.load()
                await kyc.fetchStatus()
            }
        }
        .sheet(isPresented: $showSolicitar) {
            SolicitarView(nivelMax: kyc.status?.nivelGarantia.montoMax ?? 500)
        }
        .fullScreenCover(isPresented: $showKyc) {
            KYCFlowView {
                Task {
                    await kyc.fetchStatus()
                    await vm.load()
                }
                showKyc = false
            }
        }
        .onChange(of: showSolicitar) { _, showing in
            if !showing {
                Task {
                    await vm.load()
                    await kyc.fetchStatus()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: AppEvent.prestamosChanged)) { _ in
            Task { await vm.load() }
        }
        .onReceive(NotificationCenter.default.publisher(for: AppEvent.kycChanged)) { _ in
            Task { await kyc.fetchStatus() }
        }
    }

    var headerBar: some View {
        HStack {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.deepGreen).frame(width: 42, height: 42)
                Text("🐼").font(.system(size: 24))
            }
            Spacer()
            HStack(spacing: 10) {
                NavigationLink { MisSolicitudesView() } label: {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Theme.deepGreen)
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(Theme.surfaceLight))
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
            Text("Hola,").font(PType.body(15)).foregroundColor(Theme.inkSoft)
            if case .signedIn(let u) = auth.state {
                Text(u.nombre.split(separator: " ").first.map(String.init) ?? u.nombre)
                    .font(PType.title(34))
                    .foregroundColor(Theme.ink)
                Text("Cuánto necesitas hoy?")
                    .font(PType.body(15))
                    .foregroundColor(Theme.inkSoft)
            }
        }
    }

    // MARK: KYC + Solicitar

    enum KycState { case sinDocs, enRevision, verificado }

    var kycState: KycState {
        guard let s = kyc.status else { return .sinDocs }
        if s.kycCompleto { return .verificado }
        if s.enRevision == true { return .enRevision }
        return .sinDocs
    }

    @ViewBuilder
    var kycOrSolicitarBanner: some View {
        let s = kyc.status
        let state = kycState
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                HStack(spacing: 8) {
                    ZStack {
                        Circle().fill(Color.white.opacity(0.15)).frame(width: 34, height: 34)
                        Image(systemName: stateIcon(state))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    Text(stateLabel(state))
                        .font(PType.bodyBold(15)).foregroundColor(.white)
                }
                Spacer()
            }
            if state == .verificado, let n = s?.nivelGarantia {
                Text("Tope disponible")
                    .font(PType.caption(11)).foregroundColor(.white.opacity(0.78)).tracking(0.6)
                Text(MoneyFormat.mxn(n.montoMax))
                    .font(PType.display(42))
                    .foregroundColor(.white)
                HStack(spacing: 8) {
                    heroSub("Nivel", value: n.nivel.capitalized)
                    heroSub("Docs", value: "\(s?.documentos.count ?? 0)/4")
                }
            } else if state == .enRevision {
                Text("Documentos en revisión")
                    .font(PType.body(14)).foregroundColor(.white.opacity(0.85))
                Text("Mamá está revisando tus documentos.\nMáximo 24 horas.")
                    .font(PType.body(13)).foregroundColor(.white.opacity(0.75))
            } else {
                Text("Verifica tu identidad para desbloquear hasta $20,000")
                    .font(PType.body(14)).foregroundColor(.white.opacity(0.85))
            }
            Button {
                Haptics.medium()
                switch state {
                case .verificado: showSolicitar = true
                case .sinDocs, .enRevision: showKyc = true
                }
            } label: {
                HStack {
                    Text(ctaLabel(state))
                        .font(PType.bodyBold(15))
                    Spacer()
                    Image(systemName: "arrow.right").font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(Theme.deepGreen)
                .padding(.horizontal, 22).padding(.vertical, 18)
                .background(Capsule().fill(Color.white))
            }
            .buttonStyle(PressableStyle(scale: 0.98))
            .padding(.top, 4)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 32, style: .continuous).fill(Theme.heroPrimary))
    }

    func stateIcon(_ s: KycState) -> String {
        switch s {
        case .verificado: "checkmark.seal.fill"
        case .enRevision: "hourglass"
        case .sinDocs: "shield.lefthalf.filled"
        }
    }
    func stateLabel(_ s: KycState) -> String {
        switch s {
        case .verificado: "Verificado"
        case .enRevision: "En revisión"
        case .sinDocs: "Sin verificar"
        }
    }
    func ctaLabel(_ s: KycState) -> String {
        switch s {
        case .verificado: "Solicitar préstamo"
        case .enRevision: "Revisar mis documentos"
        case .sinDocs: "Empezar verificación"
        }
    }

    func heroSub(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(PType.caption(11)).foregroundColor(.white.opacity(0.78))
            Text(value).font(PType.bodyBold(14)).foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.14)))
    }

    var beneficios: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("¿Por qué verificarte?").font(PType.title(20)).foregroundColor(Theme.ink)
            beneficioRow(icon: "banknote.fill", title: "Más dinero, mejores tasas", subtitle: "Hasta $20,000 con mejores condiciones")
            beneficioRow(icon: "bolt.fill", title: "Aprobación instantánea", subtitle: "Recibe el dinero el mismo día")
            beneficioRow(icon: "lock.shield.fill", title: "100% privado", subtitle: "Nadie más ve tus documentos")
        }
    }

    func beneficioRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Theme.softPrimary).frame(width: 46, height: 46)
                Image(systemName: icon).font(.system(size: 16, weight: .semibold)).foregroundColor(Theme.deepGreen)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(PType.bodyBold(14)).foregroundColor(Theme.ink)
                Text(subtitle).font(PType.caption(12)).foregroundColor(Theme.inkSoft)
            }
            Spacer()
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.surfaceLight))
    }

    // MARK: Con préstamo activo

    func prestamoHero(_ p: PrestamoActivo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("MI PRÉSTAMO").tracking(1.5).font(PType.caption(10)).foregroundColor(.white.opacity(0.78))
                Spacer()
                HStack(spacing: 4) {
                    Circle().fill(.white).frame(width: 6, height: 6)
                    Text(p.estado.uppercased()).font(PType.caption(10)).foregroundColor(.white.opacity(0.85))
                }
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Capsule().fill(.white.opacity(0.15)))
            }
            Text(MoneyFormat.mxn(p.principal))
                .font(PType.display(42))
                .foregroundColor(.white)
            Text("Tasa \(String(format: "%.1f", p.tasaMensual * 100))% · \(p.plazoMeses) meses")
                .font(PType.body(13))
                .foregroundColor(.white.opacity(0.82))

            if let saldo = p.saldoTotal {
                Divider().background(.white.opacity(0.15)).padding(.vertical, 4)
                HStack {
                    Text("Saldo por pagar").font(PType.body(13)).foregroundColor(.white.opacity(0.82))
                    Spacer()
                    Text(MoneyFormat.mxn(saldo)).font(PType.bodyBold(16)).foregroundColor(.white)
                }
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 32, style: .continuous).fill(Theme.heroPrimary))
    }

    func proximoPagoCard(_ p: PagoMiResumen) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("PRÓXIMO PAGO").tracking(1.5).font(PType.caption(10)).foregroundColor(Theme.inkSoft)
                Spacer()
                Text(p.fechaProgramada).font(PType.caption(12)).foregroundColor(Theme.inkSoft)
            }
            Text(MoneyFormat.mxn(p.montoEsperado)).font(PType.number(32)).foregroundColor(Theme.ink)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.surfaceLight))
    }

    func listaPagos(_ pagos: [PagoMiResumen]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Calendario de pagos").font(PType.title(20)).foregroundColor(Theme.ink)
            ForEach(pagos.prefix(12)) { p in
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(Theme.softPrimary).frame(width: 40, height: 40)
                        Image(systemName: p.estado == "pagado" ? "checkmark.circle.fill" : "clock.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Theme.deepGreen)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Pago #\(p.numeroPago)").font(PType.bodyBold(14)).foregroundColor(Theme.ink)
                        Text(p.fechaProgramada).font(PType.caption(12)).foregroundColor(Theme.inkSoft)
                    }
                    Spacer()
                    Text(MoneyFormat.mxn(p.montoEsperado)).font(PType.number(15)).foregroundColor(Theme.ink)
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.surfaceLight))
            }
        }
    }
}
