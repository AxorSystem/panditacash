import SwiftUI

@MainActor
final class NuevoPrestamoVM: ObservableObject {
    @Published var telefono = ""
    @Published var nombre = ""
    @Published var principal: Double = 5000
    @Published var tasaMensualPct: Double = 10
    @Published var plazoMeses: Int = 3
    @Published var frecuencia: Frecuencia = .mensual
    @Published var moraDiariaPct: Double = 1
    @Published var notas = ""

    @Published var lookup: LookupResp?
    @Published var lookupLoading = false
    @Published var simulacion: SimulacionResp?
    @Published var submitLoading = false
    @Published var lookupTask: Task<Void, Never>?
    @Published var simTask: Task<Void, Never>?

    enum Frecuencia: String, CaseIterable { case mensual, quincenal
        var label: String { self == .mensual ? "Mensual" : "Quincenal" }
    }

    var canSubmit: Bool {
        telefono.count >= 10 && !nombre.isEmpty && principal > 0 && plazoMeses > 0
    }

    func lookupSoon() {
        lookupTask?.cancel()
        guard telefono.count >= 10 else { lookup = nil; return }
        lookupTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled, let self else { return }
            self.lookupLoading = true
            defer { self.lookupLoading = false }
            let r: LookupResp? = try? await APIClient.shared.get("prestamos/lookup", query: ["telefono": self.telefono])
            self.lookup = r
            if let c = r?.cliente, self.nombre.isEmpty { self.nombre = c.nombre }
        }
    }

    struct SimBody: Encodable { let principal: Double; let tasa_mensual: Double; let plazo_meses: Int; let frecuencia: String }

    func simularSoon() {
        simTask?.cancel()
        simTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled, let self else { return }
            let body = SimBody(principal: self.principal, tasa_mensual: self.tasaMensualPct / 100, plazo_meses: self.plazoMeses, frecuencia: self.frecuencia.rawValue)
            self.simulacion = try? await APIClient.shared.post("prestamos/simular", body: body)
        }
    }

    struct CrearBody: Encodable {
        let telefono: String; let nombre: String; let principal: Double
        let tasa_mensual: Double; let plazo_meses: Int; let mora_diaria: Double
        let frecuencia: String; let notas: String; let override: Bool
    }

    struct CrearResp: Codable { let id: Int; let mensaje: String? }

    func crear(override: Bool = false) async throws -> CrearResp {
        submitLoading = true; defer { submitLoading = false }
        let b = CrearBody(
            telefono: telefono, nombre: nombre, principal: principal,
            tasa_mensual: tasaMensualPct / 100, plazo_meses: plazoMeses,
            mora_diaria: moraDiariaPct / 100, frecuencia: frecuencia.rawValue,
            notas: notas, override: override
        )
        return try await APIClient.shared.post("prestamos", body: b)
    }
}

struct NuevoPrestamoView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var toast: ToastCenter
    @StateObject var vm = NuevoPrestamoVM()
    @State private var confirmBlocked = false
    @State private var blockReason: String = ""
    @State private var showCelebration = false
    @State private var celebrationAmount: Double = 0
    var plantillaPrestamoId: Int? = nil

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    header
                        .padding(.top, 8)

                    telefonoCard
                    if let l = vm.lookup, l.encontrado {
                        clienteExistenteCard(l)
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .opacity))
                        if nombreMismatch {
                            nombreMismatchWarning
                        }
                    }

                    montoCard
                    tasaCard
                    plazoCard
                    frecuenciaCard

                    if let s = vm.simulacion {
                        simulacionCard(s)
                            .transition(.opacity)
                    }

                    PandaButton(title: "Crear préstamo", icon: "checkmark.seal.fill", loading: vm.submitLoading, disabled: !vm.canSubmit) {
                        Task { await submit(override: false) }
                    }
                    .padding(.top, 8)
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
            }

            if showCelebration {
                SuccessCelebration(
                    title: "¡Préstamo creado!",
                    subtitle: "Se prestaron " + MoneyFormat.mxn(celebrationAmount)
                ) {
                    showCelebration = false
                    dismiss()
                }
                .transition(.opacity)
                .zIndex(100)
            }
        }
        .onChange(of: vm.telefono) { _, _ in vm.lookupSoon() }
        .onChange(of: vm.principal) { _, _ in vm.simularSoon() }
        .onChange(of: vm.tasaMensualPct) { _, _ in vm.simularSoon() }
        .onChange(of: vm.plazoMeses) { _, _ in vm.simularSoon() }
        .onChange(of: vm.frecuencia) { _, _ in vm.simularSoon() }
        .onAppear { vm.simularSoon() }
        .task {
            if let pid = plantillaPrestamoId { await cargarPlantilla(pid) }
        }
        .alert("Cliente bloqueado", isPresented: $confirmBlocked) {
            Button("Cancelar", role: .cancel) {}
            Button("Prestar de todas formas", role: .destructive) {
                Task { await submit(override: true) }
            }
        } message: { Text(blockReason) }
    }

    var header: some View {
        HStack {
            Text("Nuevo préstamo").font(PType.title(24)).foregroundColor(Theme.ink)
            Spacer()
            Button {
                Haptics.tap(); dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Theme.ink)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(.white.opacity(0.75)).background(.ultraThinMaterial, in: Circle()))
            }
            .buttonStyle(PressableStyle())
            .accessibilityIdentifier("close_button")
            .accessibilityLabel("Cerrar")
        }
    }

    var telefonoCard: some View {
        GlassCard {
            VStack(spacing: 14) {
                cardHeader(icon: "phone.circle.fill", title: "Cliente")
                InputField(icon: "phone.fill", placeholder: "Teléfono (10 dígitos)", text: $vm.telefono, keyboard: .phonePad)
                InputField(icon: "person.fill", placeholder: "Nombre completo", text: $vm.nombre)
            }
        }
    }

    var nombreMismatch: Bool {
        guard let cliExistente = vm.lookup?.cliente else { return false }
        let existente = cliExistente.nombre.trimmingCharacters(in: .whitespaces).lowercased()
        let escrito = vm.nombre.trimmingCharacters(in: .whitespaces).lowercased()
        return !existente.isEmpty && !escrito.isEmpty && existente != escrito
    }

    var nombreMismatchWarning: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(Theme.warning)
            VStack(alignment: .leading, spacing: 3) {
                Text("¿Es un nuevo cliente?")
                    .font(PType.bodyBold(14)).foregroundColor(Theme.ink)
                Text("Ese teléfono ya está registrado con el nombre «\(vm.lookup?.cliente?.nombre ?? "")». Si le prestas, se actualizará el nombre.")
                    .font(PType.caption(12)).foregroundColor(Theme.inkSoft)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.softWarning))
    }

    func clienteExistenteCard(_ l: LookupResp) -> some View {
        GlassCard(padding: 16, cornerRadius: 20, tint: Color(hex: 0xE5E5EA)) {
            HStack(spacing: 12) {
                if let s = l.score {
                    ScoreBadge(nivel: s.nivel)
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(Theme.ink)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(l.cliente?.nombre ?? "Cliente conocido")
                        .font(PType.bodyBold(14)).foregroundColor(Theme.ink)
                    if let s = l.score {
                        Text("Score: \(s.puntos) pts · \(s.nivel.capitalized)")
                            .font(PType.caption(12)).foregroundColor(Theme.inkSoft)
                    }
                }
                Spacer()
            }
        }
    }

    var montoCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                cardHeader(icon: "banknote.fill", title: "Monto a prestar")
                Text(MoneyFormat.mxn(vm.principal))
                    .font(PType.number(38))
                    .foregroundColor(Theme.ink)
                    .contentTransition(.numericText(value: vm.principal))
                    .animation(.spring(response: 0.35, dampingFraction: 0.85), value: vm.principal)
                Slider(value: $vm.principal, in: 500...50000, step: 500) { editing in
                    if !editing { Haptics.selection() }
                }
                .tint(Theme.deepGreen)
                HStack {
                    Text("$500").font(PType.caption(11)).foregroundColor(Theme.inkMuted)
                    Spacer()
                    Text("$50,000").font(PType.caption(11)).foregroundColor(Theme.inkMuted)
                }
            }
        }
    }

    var tasaCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                cardHeader(icon: "percent", title: "Tasa mensual")
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(String(format: "%.1f", vm.tasaMensualPct))
                        .font(PType.number(38))
                        .foregroundColor(Theme.ink)
                    Text("%").font(PType.title(24)).foregroundColor(Theme.inkSoft)
                }
                Slider(value: $vm.tasaMensualPct, in: 1...30, step: 0.5) { editing in
                    if !editing { Haptics.selection() }
                }
                .tint(Theme.deepGreen)
            }
        }
    }

    var plazoCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                cardHeader(icon: "calendar.badge.clock", title: "Plazo")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach([1,2,3,4,6,9,12], id: \.self) { m in
                            plazoChip(m)
                        }
                    }
                }
            }
        }
    }

    func plazoChip(_ m: Int) -> some View {
        let active = vm.plazoMeses == m
        return Button {
            Haptics.selection()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { vm.plazoMeses = m }
        } label: {
            VStack(spacing: 2) {
                Text("\(m)").font(PType.number(20)).foregroundColor(active ? .white : Theme.ink)
                Text(m == 1 ? "mes" : "meses").font(PType.caption(10)).foregroundColor(active ? .white.opacity(0.85) : Theme.inkSoft)
            }
            .frame(width: 60, height: 60)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(active ? AnyShapeStyle(Theme.heroPrimary) : AnyShapeStyle(Color.white.opacity(0.6)))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(active ? .clear : Theme.hairline, lineWidth: 1))
                    .shadow(color: active ? Theme.ink.opacity(0.3) : .clear, radius: 8, y: 4)
            )
        }
        .buttonStyle(PressableStyle(scale: 0.9))
    }

    var frecuenciaCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                cardHeader(icon: "arrow.triangle.2.circlepath", title: "Frecuencia de pago")
                HStack(spacing: 8) {
                    ForEach(NuevoPrestamoVM.Frecuencia.allCases, id: \.self) { f in
                        Button {
                            Haptics.selection()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { vm.frecuencia = f }
                        } label: {
                            Text(f.label)
                                .font(PType.bodyBold(14))
                                .foregroundColor(vm.frecuencia == f ? .white : Theme.ink.opacity(0.7))
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(vm.frecuencia == f ? AnyShapeStyle(Theme.heroPrimary) : AnyShapeStyle(Color.white.opacity(0.6)))
                                )
                        }
                        .buttonStyle(PressableStyle(scale: 0.97))
                    }
                }
            }
        }
    }

    func simulacionCard(_ s: SimulacionResp) -> some View {
        GlassCard(padding: 20, cornerRadius: 24, tint: Color(hex: 0xF2F2F7)) {
            VStack(spacing: 14) {
                HStack {
                    Image(systemName: "sparkles").foregroundColor(Theme.ink)
                    Text("Vista previa").font(PType.heading(15)).foregroundColor(Theme.ink)
                    Spacer()
                }
                Divider().overlay(Theme.hairline)
                simRow("Entregas al cliente", MoneyFormat.mxn(s.montoEntregado ?? 0))
                simRow("Interés mensual", MoneyFormat.mxn(s.interesMensual ?? 0))
                if let cuota = s.cuotaMensual {
                    simRow("Cuota por pago", MoneyFormat.mxn(cuota), emphasize: true)
                }
                simRow("Ganancia total", MoneyFormat.mxn(s.gananciaTotal ?? 0))
                if let total = s.totalAPagar {
                    simRow("Total a pagar", MoneyFormat.mxn(total), emphasize: true)
                }
            }
        }
    }

    func simRow(_ label: String, _ value: String, emphasize: Bool = false) -> some View {
        HStack {
            Text(label).font(PType.body(13)).foregroundColor(Theme.inkSoft)
            Spacer()
            Text(value)
                .font(emphasize ? PType.number(18) : PType.number(14))
                .foregroundColor(emphasize ? Theme.ink : Theme.ink)
        }
    }

    func cardHeader(icon: String, title: String) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(Color(hex: 0xE5E5EA)).frame(width: 32, height: 32)
                Image(systemName: icon).font(.system(size: 14, weight: .bold)).foregroundColor(Theme.ink)
            }
            Text(title).font(PType.heading(15)).foregroundColor(Theme.ink)
            Spacer()
        }
    }

    struct Plantilla: Decodable {
        let telefono: String; let nombre: String
        let principal: Double; let tasa_mensual: Double; let plazo_meses: Int
        let mora_diaria: Double; let frecuencia: String
    }

    private func cargarPlantilla(_ pid: Int) async {
        do {
            let p: Plantilla = try await APIClient.shared.get("prestamos/\(pid)/plantilla")
            await MainActor.run {
                vm.telefono = p.telefono
                vm.nombre = p.nombre
                vm.principal = p.principal
                vm.tasaMensualPct = p.tasa_mensual * 100
                vm.plazoMeses = p.plazo_meses
                vm.moraDiariaPct = p.mora_diaria * 100
                vm.frecuencia = p.frecuencia == "quincenal" ? .quincenal : .mensual
                vm.notas = "Duplicado de préstamo #\(pid)"
                vm.simularSoon()
            }
        } catch {
            // ignora, el user llena manualmente
        }
    }

    func submit(override: Bool) async {
        do {
            let _ = try await vm.crear(override: override)
            Haptics.success()
            AppEvent.post(AppEvent.prestamosChanged)
            AppEvent.post(AppEvent.clientesChanged)
            celebrationAmount = vm.principal
            withAnimation(.easeIn(duration: 0.3)) { showCelebration = true }
        } catch APIError.http(let code, let msg) where code == 409 {
            Haptics.warning()
            blockReason = msg
            confirmBlocked = true
        } catch {
            Haptics.error()
            toast.show((error as? APIError)?.errorDescription ?? "Error", kind: .error)
        }
    }
}

struct ScoreBadge: View {
    let nivel: String

    var color: Color {
        switch nivel {
        case "oro": Color(hex: 0xFFC107)
        case "plata": Color(hex: 0xC0C0C0)
        case "bronce": Color(hex: 0xCD7F32)
        case "bloqueado": Theme.danger
        default: Theme.info
        }
    }
    var icon: String {
        switch nivel {
        case "oro", "plata", "bronce": "medal.fill"
        case "bloqueado": "lock.fill"
        default: "star.fill"
        }
    }

    var body: some View {
        ZStack {
            Circle().fill(color.opacity(0.2)).frame(width: 44, height: 44)
            Image(systemName: icon).font(.system(size: 18, weight: .bold)).foregroundColor(color)
        }
    }
}
