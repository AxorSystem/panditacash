import SwiftUI
import UIKit

@MainActor
final class PrestamoDetalleVM: ObservableObject {
    @Published var detalle: PrestamoDetalle?
    @Published var loading = false

    let id: Int
    init(id: Int) { self.id = id }

    func load() async {
        loading = true; defer { loading = false }
        let real: PrestamoDetalle? = try? await APIClient.shared.get("prestamos/\(id)")
        if let r = real {
            detalle = r
        } else if ProcessInfo.processInfo.environment["FAKE_DATA"] == "1" {
            detalle = Self.mock
        }
    }

    static let mock = PrestamoDetalle(
        id: 10, usuarioId: 1,
        clienteNombre: "María González", clienteTel: "5551234567",
        principal: 5000, tasaMensual: 0.10, plazoMeses: 3,
        interesMensual: 500, montoEntregado: 4500,
        moraDiaria: 0.01,
        fechaInicio: "2026-05-15", fechaLiquidacion: nil,
        estado: "activo", notas: nil, frecuencia: "mensual",
        pagos: [
            .init(id: 1, numeroPago: 1, montoEsperado: 1666, fechaProgramada: "2026-06-15",
                  montoPagadoCapital: 1666, montoPagadoMora: 0, moraPerdonadaTotal: 0,
                  fechaPagada: "2026-06-14", estado: "pagado", notas: nil),
            .init(id: 2, numeroPago: 2, montoEsperado: 1666, fechaProgramada: "2026-07-15",
                  montoPagadoCapital: 500, montoPagadoMora: 0, moraPerdonadaTotal: 0,
                  fechaPagada: nil, estado: "parcial", notas: nil),
            .init(id: 3, numeroPago: 3, montoEsperado: 1668, fechaProgramada: "2026-08-15",
                  montoPagadoCapital: 0, montoPagadoMora: 0, moraPerdonadaTotal: 0,
                  fechaPagada: nil, estado: "pendiente", notas: nil),
        ],
        movimientos: nil,
        totalPagadoCapital: 2166,
        totalPagadoMora: 0,
        totalPendiente: 3334
    )

    struct CobrarBody: Encodable {
        let pago_id: Int
        let monto: Double
        let mora_perdonada: Double
        let metodo: String
        let notas: String?
    }

    func cobrar(pagoId: Int, monto: Double, moraPerdonada: Double, metodo: String, notas: String?) async throws {
        let body = CobrarBody(pago_id: pagoId, monto: monto, mora_perdonada: moraPerdonada, metodo: metodo, notas: notas?.isEmpty == false ? notas : nil)
        struct R: Decodable { let ok: Bool? }
        let _: R = try await APIClient.shared.post("prestamos/\(id)/cobrar", body: body)
        await load()
        AppEvent.post(AppEvent.prestamosChanged)
        AppEvent.post(AppEvent.clientesChanged)
    }
}

struct PrestamoDetalleView: View {
    let prestamoId: Int
    @StateObject private var vm: PrestamoDetalleVM
    @State private var pagoParaCobrar: PagoDetalle?
    @State private var showReasignar = false
    @State private var showEditarNotas = false
    @State private var showDuplicar = false
    @State private var sharePDF: URL? = nil
    @EnvironmentObject var toast: ToastCenter

    init(prestamoId: Int) {
        self.prestamoId = prestamoId
        _vm = StateObject(wrappedValue: PrestamoDetalleVM(id: prestamoId))
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                if let d = vm.detalle {
                    VStack(spacing: 18) {
                        headerCliente(d)
                        heroPrestamo(d)
                        if let t = d.totales { totalesCard(t, d: d) }
                        pagosSection(d)
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                } else if vm.loading {
                    ProgressView().tint(Theme.deepGreen).padding(.top, 100)
                } else {
                    Text("No encontrado").padding()
                }
            }
            .refreshable { await vm.load() }
            .task { await vm.load() }
        }
        .sheet(item: $pagoParaCobrar) { pago in
            if let d = vm.detalle {
                CobrarSheet(prestamo: d, pago: pago, vm: vm)
            }
        }
        .sheet(isPresented: $showReasignar) {
            if let d = vm.detalle {
                ReasignarPrestamoSheet(prestamoId: d.id, clienteActual: d.clienteNombre) {
                    Task { await vm.load() }
                }
            }
        }
        .sheet(isPresented: $showEditarNotas) {
            if let d = vm.detalle {
                EditarNotasPrestamoSheet(prestamoId: d.id, notasIniciales: d.notas ?? "") {
                    Task { await vm.load() }
                }
            }
        }
        .sheet(isPresented: $showDuplicar) {
            NuevoPrestamoView(plantillaPrestamoId: prestamoId)
        }
        .sheet(item: $sharePDF) { u in ShareSheet(items: [u]) }
        .navigationTitle("Préstamo #\(prestamoId)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showEditarNotas = true
                    } label: {
                        Label("Editar notas", systemImage: "note.text.badge.plus")
                    }
                    Button {
                        exportarPDF()
                    } label: {
                        Label("Descargar PDF del acuerdo", systemImage: "doc.fill")
                    }
                    Button {
                        showDuplicar = true
                    } label: {
                        Label("Duplicar préstamo", systemImage: "square.on.square")
                    }
                    Button {
                        agregarPagosAlCalendario()
                    } label: {
                        Label("Agregar pagos al Calendario", systemImage: "calendar.badge.plus")
                    }
                    Button {
                        showReasignar = true
                    } label: {
                        Label("Reasignar a otro cliente", systemImage: "arrow.right.arrow.left")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle").foregroundColor(Theme.deepGreen)
                }
            }
        }
    }

    private func exportarPDF() {
        guard let d = vm.detalle else { return }
        if let url = AcuerdoPDF.generar(prestamo: d) {
            Haptics.success()
            sharePDF = url
        } else {
            Haptics.error()
            toast.show("No se pudo generar el PDF", kind: .error)
        }
    }

    private func agregarPagosAlCalendario() {
        guard let d = vm.detalle else { return }
        let pendientes = d.pagos.filter { $0.estado == "pendiente" || $0.estado == "parcial" || $0.estado == "vencido" }
        let titulo = "Pago \(d.clienteNombre) — Préstamo #\(d.id)"
        Task {
            let ok = await CalendarService.addEvents(
                titulo: titulo,
                fechas: pendientes.compactMap { CalendarService.parseFecha($0.fechaProgramada) },
                notas: "Monto esperado. Mora diaria \(String(format: "%.1f%%", (d.moraDiaria) * 100))"
            )
            await MainActor.run {
                if ok > 0 {
                    Haptics.success()
                    toast.show("\(ok) pago(s) agregado(s) al calendario", kind: .success)
                } else {
                    Haptics.error()
                    toast.show("Sin permiso o sin eventos", kind: .error)
                }
            }
        }
    }

    func headerCliente(_ d: PrestamoDetalle) -> some View {
        GlassCard(padding: 16, cornerRadius: 22) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Color(hex: 0xE5E5EA)).frame(width: 48, height: 48)
                    Text(String(d.clienteNombre.prefix(1).uppercased()))
                        .font(PType.bodyBold(18))
                        .foregroundColor(Theme.ink)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(d.clienteNombre).font(PType.bodyBold(16)).foregroundColor(Theme.ink)
                    Text(d.clienteTel).font(PType.caption(12)).foregroundColor(Theme.inkSoft)
                }
                Spacer()
                Button {
                    Haptics.tap()
                    openWA(tel: d.clienteTel, mensaje: "🐼 Recordatorio de pago")
                } label: {
                    Image(systemName: "message.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Theme.success))
                        .shadow(color: Theme.success.opacity(0.35), radius: 6, y: 3)
                }
                .buttonStyle(PressableStyle())
            }
        }
    }

    func heroPrestamo(_ d: PrestamoDetalle) -> some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Theme.heroPrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(.white.opacity(0.4), lineWidth: 1)
                )
                .shadow(color: Theme.ink.opacity(0.3), radius: 20, y: 12)
            Circle().fill(.white.opacity(0.2)).frame(width: 140, height: 140).blur(radius: 30).offset(x: 30, y: -20)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("PRESTADO").tracking(1.2).font(PType.caption(11)).foregroundColor(.white.opacity(0.85))
                    Spacer()
                    Text(d.estado.uppercased())
                        .font(PType.caption(10)).foregroundColor(.white)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Capsule().fill(.white.opacity(0.22)))
                }
                Text(MoneyFormat.mxn(d.principal))
                    .font(PType.number(38))
                    .foregroundColor(.white)
                HStack(spacing: 10) {
                    Label(String(format: "%.1f%% mensual", d.tasaMensual * 100), systemImage: "percent")
                    Label("\(d.plazoMeses) meses", systemImage: "calendar")
                }
                .font(PType.caption(12)).foregroundColor(.white.opacity(0.85))
            }
            .padding(22)
        }
    }

    func totalesCard(_ t: PrestamoTotales, d: PrestamoDetalle) -> some View {
        GlassCard {
            VStack(spacing: 10) {
                totRow("Capital pagado", t.capitalPagado ?? 0, color: Theme.success)
                totRow("Mora pagada", t.moraPagada ?? 0, color: Theme.warning)
                Divider().overlay(Theme.hairline)
                totRow("Saldo capital", t.saldoCapital ?? 0, color: Theme.ink, bold: true)
                totRow("Saldo total pendiente", t.saldoTotalPendiente ?? 0, color: Theme.danger, bold: true)
            }
        }
    }

    func totRow(_ label: String, _ v: Double, color: Color, bold: Bool = false) -> some View {
        HStack {
            Text(label).font(PType.body(13)).foregroundColor(Theme.inkSoft)
            Spacer()
            Text(MoneyFormat.mxn(v))
                .font(bold ? PType.number(17) : PType.number(14))
                .foregroundColor(color)
        }
    }

    func pagosSection(_ d: PrestamoDetalle) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Pagos").font(PType.heading(18)).foregroundColor(Theme.ink)
                Spacer()
                Text("\(d.pagos.count)").font(PType.caption(11)).foregroundColor(.white)
                    .padding(.horizontal, 10).padding(.vertical, 3)
                    .background(Capsule().fill(Theme.deepGreen))
            }
            ForEach(Array(d.pagos.enumerated()), id: \.element.id) { idx, pago in
                pagoTimelineRow(pago, d: d, isLast: idx == d.pagos.count - 1)
            }
        }
    }

    func pagoTimelineRow(_ pago: PagoDetalle, d: PrestamoDetalle, isLast: Bool) -> some View {
        let (color, icon) = estadoUI(pago.estado)
        let canCobrar = pago.estado == "pendiente" || pago.estado == "parcial" || pago.estado == "vencido"
        let rel = fechaRelativa(pago.fechaProgramada)
        return HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                ZStack {
                    Circle().fill(color.opacity(0.15)).frame(width: 40, height: 40)
                    Image(systemName: icon).font(.system(size: 14, weight: .bold)).foregroundColor(color)
                }
                if !isLast {
                    Rectangle().fill(Theme.hairline).frame(width: 2).frame(maxHeight: .infinity)
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text("Pago #\(pago.numeroPago)").font(PType.bodyBold(14)).foregroundColor(Theme.ink)
                            fechaChip(rel: rel, color: color, estado: pago.estado)
                        }
                        Text(pago.fechaProgramada).font(PType.caption(11)).foregroundColor(Theme.inkMuted)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(MoneyFormat.mxn(pago.montoEsperado)).font(PType.number(15)).foregroundColor(Theme.ink)
                        if (pago.montoPagadoCapital ?? 0) > 0 {
                            Text("Cobrado \(MoneyFormat.mxn(pago.montoPagadoCapital ?? 0))")
                                .font(PType.caption(10)).foregroundColor(Theme.success)
                        }
                    }
                }
                if canCobrar {
                    HStack(spacing: 8) {
                        Button {
                            Haptics.medium(); pagoParaCobrar = pago
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "banknote.fill").font(.system(size: 12, weight: .bold))
                                Text("Cobrar").font(PType.bodyBold(12))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 9)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.heroPrimary))
                        }
                        Button {
                            Haptics.tap(); recordarWA(d, pago)
                        } label: {
                            Image(systemName: "message.badge.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 40, height: 34)
                                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.deepGreen))
                        }
                    }
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 18).fill(Theme.surfaceLight))
            .padding(.bottom, 10)
        }
    }

    private func fechaChip(rel: (String, Color), color: Color, estado: String) -> some View {
        Text(rel.0)
            .font(PType.caption(10))
            .foregroundColor(rel.1)
            .padding(.horizontal, 8).padding(.vertical, 2)
            .background(Capsule().fill(rel.1.opacity(0.15)))
    }

    private func fechaRelativa(_ iso: String) -> (String, Color) {
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        guard let d = df.date(from: String(iso.prefix(10))) else { return ("—", Theme.inkSoft) }
        let cal = Calendar.current
        let hoy = cal.startOfDay(for: Date())
        let dia = cal.startOfDay(for: d)
        let diff = cal.dateComponents([.day], from: hoy, to: dia).day ?? 0
        if diff == 0 { return ("HOY", Theme.warning) }
        if diff > 0 { return ("en \(diff) día\(diff == 1 ? "" : "s")", Theme.deepGreen) }
        return ("Vencido \(-diff)d", Theme.danger)
    }

    private func recordarWA(_ d: PrestamoDetalle, _ pago: PagoDetalle) {
        let raw = d.clienteTel.filter { $0.isNumber }
        let short = raw.count > 10 ? String(raw.suffix(10)) : raw
        let n = d.clienteNombre.split(separator: " ").first.map(String.init) ?? d.clienteNombre
        let cal = Calendar.current
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        let fecha = df.date(from: String(pago.fechaProgramada.prefix(10))) ?? Date()
        let diff = cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: fecha)).day ?? 0
        let cuerpo: String
        if diff < 0 {
            cuerpo = "Hola \(n), un recordatorio amable: tu pago #\(pago.numeroPago) de \(MoneyFormat.mxn(pago.montoEsperado)) está vencido hace \(-diff) día\(diff == -1 ? "" : "s"). ¿Cuándo puedes ponerte al corriente?"
        } else if diff == 0 {
            cuerpo = "Hola \(n), recordatorio: tu pago #\(pago.numeroPago) de \(MoneyFormat.mxn(pago.montoEsperado)) vence HOY."
        } else {
            cuerpo = "Hola \(n), recordatorio: tu pago #\(pago.numeroPago) de \(MoneyFormat.mxn(pago.montoEsperado)) vence en \(diff) día\(diff == 1 ? "" : "s")."
        }
        let enc = cuerpo.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "https://wa.me/52\(short)?text=\(enc)") {
            UIApplication.shared.open(url)
        }
    }

    func estadoUI(_ e: String) -> (Color, String) {
        switch e {
        case "pagado", "pagado_anticipado": (Theme.success, "checkmark.seal.fill")
        case "vencido": (Theme.danger, "exclamationmark.triangle.fill")
        case "parcial": (Theme.info, "circle.lefthalf.filled")
        case "perdonado": (Theme.inkMuted, "hand.raised.fill")
        default: (Theme.warning, "clock.fill")
        }
    }

    func openWA(tel: String, mensaje: String) {
        let msg = mensaje.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? mensaje
        if let url = URL(string: "https://wa.me/\(tel)?text=\(msg)") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Cobrar Sheet

struct CobrarSheet: View {
    let prestamo: PrestamoDetalle
    let pago: PagoDetalle
    @ObservedObject var vm: PrestamoDetalleVM
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var toast: ToastCenter

    @State private var monto: Double = 0
    @State private var moraPerdonada: Double = 0
    @State private var metodo: String = "efectivo"
    @State private var notas: String = ""
    @State private var submitting = false

    let metodos: [(String, String, String)] = [
        ("efectivo", "Efectivo", "banknote"),
        ("transferencia", "Transferencia", "arrow.left.arrow.right"),
        ("deposito", "Depósito", "building.columns.fill"),
        ("otro", "Otro", "circle.grid.cross"),
    ]

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    header
                    resumenPago
                    inputMonto
                    inputMora
                    seleccionMetodo
                    inputNotas
                    PandaButton(title: "Registrar cobro", icon: "checkmark.seal.fill", loading: submitting, disabled: monto <= 0) {
                        Task { await hacerCobro() }
                    }
                    .padding(.top, 4)
                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
        }
        .onAppear { monto = pago.montoEsperado - (pago.montoPagadoCapital ?? 0) - (pago.montoPagadoMora ?? 0) }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.background)
    }

    var header: some View {
        VStack(spacing: 4) {
            Text("Registrar cobro").font(PType.title(22)).foregroundColor(Theme.ink)
            Text("Pago #\(pago.numeroPago) · \(pago.fechaProgramada)")
                .font(PType.body(13)).foregroundColor(Theme.inkSoft)
        }
    }

    var resumenPago: some View {
        GlassCard(padding: 16, cornerRadius: 20, tint: Color(hex: 0xF2F2F7)) {
            HStack {
                Text("Esperado").font(PType.body(13)).foregroundColor(Theme.inkSoft)
                Spacer()
                Text(MoneyFormat.mxn(pago.montoEsperado)).font(PType.number(18)).foregroundColor(Theme.ink)
            }
        }
    }

    var inputMonto: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Monto cobrado").font(PType.heading(15)).foregroundColor(Theme.ink)
                Text(MoneyFormat.mxn(monto))
                    .font(PType.number(38))
                    .foregroundColor(Theme.ink)
                    .contentTransition(.numericText(value: monto))
                    .animation(.spring(response: 0.3, dampingFraction: 0.85), value: monto)
                Slider(value: $monto, in: 0...max(pago.montoEsperado * 1.5, 1), step: 50) { editing in
                    if !editing { Haptics.selection() }
                }
                .tint(Theme.deepGreen)
                HStack {
                    quickAmount("Mitad", value: pago.montoEsperado / 2)
                    quickAmount("Completo", value: pago.montoEsperado)
                }
            }
        }
    }

    func quickAmount(_ label: String, value: Double) -> some View {
        Button {
            Haptics.tap()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                monto = (value * 100).rounded() / 100
            }
        } label: {
            HStack(spacing: 4) {
                Text(label).font(PType.bodyBold(12))
                Text(MoneyFormat.mxn(value)).font(PType.caption(11))
            }
            .foregroundColor(Theme.ink)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Capsule().fill(Color(hex: 0xE5E5EA)))
        }
        .buttonStyle(PressableStyle())
    }

    var inputMora: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Mora perdonada (opcional)").font(PType.heading(15)).foregroundColor(Theme.ink)
                HStack {
                    Text("$").font(PType.number(20)).foregroundColor(Theme.inkSoft)
                    TextField("0", value: $moraPerdonada, format: .number)
                        .font(PType.number(20))
                        .keyboardType(.decimalPad)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.background).overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.hairline, lineWidth: 1)))
            }
        }
    }

    var seleccionMetodo: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Método").font(PType.heading(15)).foregroundColor(Theme.ink)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(metodos, id: \.0) { m in
                        Button {
                            Haptics.selection()
                            metodo = m.0
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: m.2).font(.system(size: 13, weight: .bold))
                                Text(m.1).font(PType.bodyBold(13))
                            }
                            .foregroundColor(metodo == m.0 ? .white : Theme.ink.opacity(0.75))
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(metodo == m.0 ? AnyShapeStyle(Theme.heroPrimary) : AnyShapeStyle(Color.white.opacity(0.6))))
                        }
                        .buttonStyle(PressableStyle(scale: 0.96))
                    }
                }
            }
        }
    }

    var inputNotas: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Notas (opcional)").font(PType.heading(15)).foregroundColor(Theme.ink)
                TextField("Ej: pagó con billete de 500", text: $notas, axis: .vertical)
                    .font(PType.body(14))
                    .lineLimit(2...4)
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.background).overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.hairline, lineWidth: 1)))
            }
        }
    }

    func hacerCobro() async {
        submitting = true; defer { submitting = false }
        do {
            try await vm.cobrar(pagoId: pago.id, monto: monto, moraPerdonada: moraPerdonada, metodo: metodo, notas: notas)
            Haptics.success()
            toast.show("Cobro registrado 💰", kind: .success)
            dismiss()
        } catch {
            Haptics.error()
            toast.show((error as? APIError)?.errorDescription ?? "Error", kind: .error)
        }
    }
}
