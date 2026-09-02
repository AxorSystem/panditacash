import SwiftUI
import UIKit

@MainActor
final class ClientesVM: ObservableObject {
    @Published var clientes: [ClienteList] = []
    @Published var buscar: String = ""
    @Published var loading = false
    @Published var errorMsg: String?
    @Published var filter: Filter = .todos
    @Published var tagActivo: String? = nil

    enum Filter: String, CaseIterable { case todos = "Todos", activos = "Activos", atrasados = "Atrasados" }

    var tagsDisponibles: [String] {
        var s = Set<String>()
        for c in clientes { for t in c.tags { s.insert(t) } }
        return s.sorted()
    }

    func load() async {
        loading = true; defer { loading = false }
        if ProcessInfo.processInfo.environment["FAKE_DATA_ONLY"] == "1" {
            clientes = Self.mock
            return
        }
        do {
            let real: [ClienteList] = try await APIClient.shared.get("clientes", query: buscar.isEmpty ? [:] : ["buscar": buscar])
            clientes = real
            errorMsg = nil
        } catch {
            errorMsg = (error as? APIError)?.errorDescription ?? error.localizedDescription
            if ProcessInfo.processInfo.environment["FAKE_DATA"] == "1" {
                clientes = Self.mock
            }
        }
    }

    static let mock: [ClienteList] = [
        .init(id: 1, nombre: "María González", telefono: "5551234567", notas: nil, nPrestamos: 3, activos: 1, deudaOriginal: 5000, totalPagadoCapital: 1500, saldoReal: 3500, vencidos: 0, atrasosHistoricos: 1),
        .init(id: 2, nombre: "Roberto Sánchez", telefono: "5559876543", notas: nil, nPrestamos: 2, activos: 1, deudaOriginal: 8000, totalPagadoCapital: 800, saldoReal: 7200, vencidos: 2, atrasosHistoricos: 3),
        .init(id: 3, nombre: "Ana López", telefono: "5552345678", notas: nil, nPrestamos: 1, activos: 1, deudaOriginal: 3800, totalPagadoCapital: 0, saldoReal: 3800, vencidos: 0, atrasosHistoricos: 0),
        .init(id: 4, nombre: "Carlos Ramírez", telefono: "5553456789", notas: nil, nPrestamos: 5, activos: 0, deudaOriginal: 0, totalPagadoCapital: 12000, saldoReal: 0, vencidos: 0, atrasosHistoricos: 2),
        .init(id: 5, nombre: "Lucía Torres", telefono: "5554567890", notas: nil, nPrestamos: 2, activos: 1, deudaOriginal: 2500, totalPagadoCapital: 500, saldoReal: 2000, vencidos: 0, atrasosHistoricos: 0),
    ]

    var filtered: [ClienteList] {
        var out: [ClienteList]
        switch filter {
        case .todos: out = clientes
        case .activos: out = clientes.filter { ($0.activos ?? 0) > 0 }
        case .atrasados: out = clientes.filter { ($0.vencidos ?? 0) > 0 }
        }
        if let t = tagActivo { out = out.filter { $0.tags.contains(t) } }
        return out
    }
}

struct MamaClientesView: View {
    @StateObject var vm = ClientesVM()
    @State private var compactMode: Bool = UserDefaults.standard.bool(forKey: "clientes.compact")

    var body: some View {
        ZStack(alignment: .top) {
            Theme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Clientes")
                                .font(PType.title(28))
                                .foregroundColor(Theme.ink)
                            Text("\(vm.filtered.count) \(vm.filtered.count == 1 ? "cliente" : "clientes")")
                                .font(PType.body(13))
                                .foregroundColor(Theme.inkSoft)
                        }
                        Spacer()
                        Button {
                            Haptics.tap()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                compactMode.toggle()
                            }
                            UserDefaults.standard.set(compactMode, forKey: "clientes.compact")
                        } label: {
                            Image(systemName: compactMode ? "list.bullet.rectangle.fill" : "rectangle.grid.1x2.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Theme.deepGreen)
                                .frame(width: 38, height: 38)
                                .background(Circle().fill(Theme.softPrimary))
                        }
                    }
                    .padding(.top, 12)
                    .padding(.horizontal, 20)

                    searchBar
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    filters
                        .padding(.horizontal, 20)

                    LazyVStack(spacing: compactMode ? 4 : 10) {
                        ForEach(vm.filtered) { c in
                            NavigationLink {
                                ClienteDetalleView(clienteId: c.id, nombre: c.nombre)
                            } label: {
                                if compactMode { ClienteRowCompact(cliente: c) }
                                else { ClienteRow(cliente: c) }
                            }
                            .buttonStyle(PressableStyle(scale: 0.98))
                        }
                        if vm.filtered.isEmpty && !vm.loading {
                            EmptyClientes().padding(.top, 40)
                        }
                        if vm.loading && vm.clientes.isEmpty {
                            ProgressView().tint(Theme.deepGreen).padding(.top, 30)
                        }
                    }
                    .padding(.horizontal, 20)
                    .animation(.easeInOut(duration: 0.25), value: vm.clientes.count)

                    Spacer(minLength: 120)
                }
            }
            .refreshable { await vm.load() }
            .task(id: "clientes-load") { await vm.load() }
            .onAppear {
                Task { await vm.load() }
            }
            .onReceive(NotificationCenter.default.publisher(for: AppEvent.clientesChanged)) { _ in
                Task { await vm.load() }
            }
            .onReceive(NotificationCenter.default.publisher(for: AppEvent.prestamosChanged)) { _ in
                Task { await vm.load() }
            }
        }
    }

    var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.inkMuted)
            TextField("Buscar por nombre o teléfono", text: $vm.buscar)
                .font(PType.body(15))
                .foregroundColor(Theme.ink)
                .onSubmit { Task { await vm.load() } }
                .autocorrectionDisabled()
            if !vm.buscar.isEmpty {
                Button {
                    Haptics.tap()
                    vm.buscar = ""
                    Task { await vm.load() }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Theme.inkMuted)
                }
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 16)
        .background(Capsule().fill(Theme.surfaceLight))
    }

    var filters: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ClientesVM.Filter.allCases, id: \.self) { f in
                        FilterPill(label: f.rawValue, active: vm.filter == f) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                vm.filter = f
                            }
                        }
                    }
                }
            }
            if !vm.tagsDisponibles.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        Image(systemName: "tag.fill").font(.system(size: 10, weight: .semibold)).foregroundColor(Theme.deepGreen)
                        ForEach(vm.tagsDisponibles, id: \.self) { t in
                            let active = vm.tagActivo == t
                            Button {
                                Haptics.tap()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    vm.tagActivo = active ? nil : t
                                }
                            } label: {
                                Text(t).font(PType.bodyBold(11))
                                    .foregroundColor(active ? .white : Theme.deepGreen)
                                    .padding(.horizontal, 10).padding(.vertical, 5)
                                    .background(Capsule().fill(active ? Theme.deepGreen : Theme.softPrimary))
                            }
                        }
                    }
                }
            }
        }
    }
}

struct FilterPill: View {
    let label: String
    let active: Bool
    let onTap: () -> Void
    var body: some View {
        Button {
            Haptics.selection()
            onTap()
        } label: {
            Text(label)
                .font(PType.bodyBold(13))
                .foregroundColor(active ? .white : Theme.inkSoft)
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(active ? AnyShapeStyle(Theme.deepGreen) : AnyShapeStyle(Theme.surfaceLight))
                )
        }
        .buttonStyle(PressableStyle(scale: 0.96))
    }
}

struct ClienteRowCompact: View {
    let cliente: ClienteList

    private var iniciales: String {
        let parts = cliente.nombre.split(separator: " ").prefix(2).compactMap(\.first).map(String.init)
        let j = parts.joined().uppercased()
        return j.isEmpty ? "?" : j
    }

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill((cliente.vencidos ?? 0) > 0 ? Theme.danger : Theme.deepGreen)
                    .frame(width: 30, height: 30)
                Text(iniciales.prefix(2)).font(PType.caption(11)).foregroundColor(.white)
            }
            Text(cliente.nombre).font(PType.body(14)).foregroundColor(Theme.ink).lineLimit(1)
            Spacer(minLength: 6)
            if (cliente.vencidos ?? 0) > 0 {
                Text("\(cliente.vencidos!)")
                    .font(PType.caption(10)).foregroundColor(.white)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(Theme.danger))
            }
            Text(MoneyFormat.mxn(cliente.saldoReal ?? 0))
                .font(PType.number(13)).foregroundColor(Theme.ink)
            Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)).foregroundColor(Theme.inkMuted)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
    }
}

struct ClienteRow: View {
    let cliente: ClienteList

    var iniciales: String {
        let parts = cliente.nombre.split(separator: " ").prefix(2).compactMap(\.first).map(String.init)
        let joined = parts.joined().uppercased()
        return joined.isEmpty ? "?" : joined
    }

    var accent: Color {
        (cliente.vencidos ?? 0) > 0 ? Theme.danger :
        (cliente.activos ?? 0) > 0 ? Theme.deepGreen : Theme.inkMuted
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [accent, accent.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 48, height: 48)
                Text(iniciales).font(PType.bodyBold(15)).foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if cliente.favorito {
                        Image(systemName: "star.fill").font(.system(size: 11)).foregroundColor(Theme.warning)
                    }
                    Text(cliente.nombre).font(PType.bodyBold(15)).foregroundColor(Theme.ink).lineLimit(1)
                    ForEach(cliente.tags.prefix(2), id: \.self) { t in
                        Text(t)
                            .font(PType.caption(9)).foregroundColor(Theme.deepGreen)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Capsule().fill(Theme.softPrimary))
                    }
                }
                HStack(spacing: 6) {
                    Text(cliente.telefono).font(PType.caption(11)).foregroundColor(Theme.inkSoft)
                    if (cliente.vencidos ?? 0) > 0 {
                        Text("· \(cliente.vencidos!) vencido\(cliente.vencidos! == 1 ? "" : "s")")
                            .font(PType.caption(11)).foregroundColor(Theme.danger)
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(MoneyFormat.mxn(cliente.saldoReal ?? 0)).font(PType.number(15)).foregroundColor(Theme.ink)
                if (cliente.activos ?? 0) > 0 {
                    Text("\(cliente.activos!) activo\(cliente.activos! == 1 ? "" : "s")").font(PType.caption(10)).foregroundColor(Theme.inkMuted)
                } else {
                    Text("Sin préstamos").font(PType.caption(10)).foregroundColor(Theme.inkMuted)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white)
        )
        .shadow(color: Theme.deepGreen.opacity(0.1), radius: 12, x: 0, y: 4)
    }
}

struct SkeletonClienteRow: View {
    @State private var pulse = false
    var body: some View {
        HStack(spacing: 14) {
            Circle().fill(Theme.hairline.opacity(pulse ? 0.5 : 0.9)).frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4).fill(Theme.hairline).frame(width: 160, height: 12)
                RoundedRectangle(cornerRadius: 4).fill(Theme.hairline).frame(width: 100, height: 10)
            }
            Spacer()
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.red.opacity(0.5)))
        .onAppear {
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) { pulse.toggle() }
        }
    }
}

struct EmptyClientes: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass.circle.fill")
                .font(.system(size: 48, weight: .regular))
                .foregroundColor(Theme.inkMuted)
            Text("Sin coincidencias").font(PType.heading(16)).foregroundColor(Theme.ink)
            Text("Ajusta la búsqueda").font(PType.body(13)).foregroundColor(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity)
    }
}

@MainActor
final class ClienteDetalleVM: ObservableObject {
    let clienteId: Int
    @Published var resp: ClienteDetalleResp?
    @Published var loading = false
    @Published var errorMsg: String?

    init(clienteId: Int) { self.clienteId = clienteId }

    func load() async {
        loading = true; defer { loading = false }
        if ProcessInfo.processInfo.environment["FAKE_DATA_ONLY"] == "1" {
            resp = Self.mock
            return
        }
        do {
            resp = try await APIClient.shared.get("clientes/\(clienteId)")
            errorMsg = nil
        } catch {
            errorMsg = (error as? APIError)?.errorDescription ?? error.localizedDescription
            if ProcessInfo.processInfo.environment["FAKE_DATA"] == "1" {
                resp = Self.mock
            }
        }
    }

    static let mock = ClienteDetalleResp(
        cliente: ClienteBasico(id: 2, nombre: "liliana martinez", telefono: "527341682051", notas: nil, createdAt: "2026-07-17", lastLogin: nil),
        prestamos: [
            .init(id: 3, principal: 50000, tasaMensual: 0.10, plazoMeses: 3, montoEntregado: 45000, interesMensual: 5000, moraDiaria: 500, fechaInicio: "2026-07-22", fechaLiquidacion: nil, estado: "activo", notas: nil, aprobadoAt: nil, pagadoCapital: 0, pagadoMora: 0, saldoPendiente: 50000),
            .init(id: 2, principal: 10000, tasaMensual: 0.15, plazoMeses: 3, montoEntregado: 8500, interesMensual: 1500, moraDiaria: 100, fechaInicio: "2026-07-17", fechaLiquidacion: nil, estado: "activo", notas: nil, aprobadoAt: nil, pagadoCapital: 3300, pagadoMora: 0, saldoPendiente: 8200),
            .init(id: 1, principal: 2000, tasaMensual: 0.15, plazoMeses: 3, montoEntregado: 1700, interesMensual: 300, moraDiaria: 20, fechaInicio: "2026-07-17", fechaLiquidacion: nil, estado: "activo", notas: nil, aprobadoAt: nil, pagadoCapital: 2000, pagadoMora: 0, saldoPendiente: 600),
        ],
        movimientos: [
            .init(id: 10, prestamoId: 2, clienteNombre: nil, clienteTelefono: nil, montoCapital: 1500, montoMora: 0, moraPerdonada: nil, metodo: "efectivo", notas: nil, fechaPago: "2026-07-20", createdAt: nil),
            .init(id: 11, prestamoId: 1, clienteNombre: nil, clienteTelefono: nil, montoCapital: 2000, montoMora: 0, moraPerdonada: nil, metodo: "transferencia", notas: nil, fechaPago: "2026-07-19", createdAt: nil),
        ],
        score: Score(nivel: "plata", puntos: 720, etiqueta: nil, bloquear: false, motivo: nil, emoji: nil, puntualidadPct: nil, prestamosLiquidados: nil, atrasosTotales: nil, prestamosActivos: nil, activosMaximos: nil, montoMaximoSugerido: nil)
    )
}

struct ClienteDetalleView: View {
    let clienteId: Int
    let nombre: String
    @StateObject private var vm: ClienteDetalleVM
    @EnvironmentObject var toast: ToastCenter
    @State private var showEditNotas = false
    @State private var notasDraft: String = ""
    @State private var showEditTags = false

    init(clienteId: Int, nombre: String) {
        self.clienteId = clienteId
        self.nombre = nombre
        _vm = StateObject(wrappedValue: ClienteDetalleVM(clienteId: clienteId))
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    if let r = vm.resp {
                        heroCard(r).padding(.horizontal, 20).padding(.top, 8)
                        if let s = r.score {
                            scoreCard(s).padding(.horizontal, 20)
                        }
                        if let n = r.cliente.notas, !n.isEmpty {
                            notasCard(n).padding(.horizontal, 20)
                        }
                        prestamosSection(r.prestamos).padding(.horizontal, 20)
                        if let movs = r.movimientos, !movs.isEmpty {
                            movimientosSection(movs).padding(.horizontal, 20)
                        }
                    } else if let err = vm.errorMsg {
                        errorBanner(err).padding(.horizontal, 20).padding(.top, 12)
                    } else if vm.loading {
                        ProgressView().tint(Theme.deepGreen).padding(.top, 100)
                    }
                    Spacer(minLength: 100)
                }
            }
            .refreshable { await vm.load() }
            .task { await vm.load() }
        }
        .navigationTitle(nombre)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    NavigationLink {
                        HistorialClienteView(clienteId: clienteId, nombre: nombre)
                    } label: {
                        Label("Historial", systemImage: "clock.arrow.circlepath")
                    }
                    Button {
                        notasDraft = vm.resp?.cliente.notas ?? ""
                        showEditNotas = true
                    } label: {
                        Label("Editar cliente", systemImage: "pencil")
                    }
                    Button {
                        showEditTags = true
                    } label: {
                        Label("Etiquetas", systemImage: "tag.fill")
                    }
                    Button {
                        guardarEnContactos()
                    } label: {
                        Label("Guardar en Contactos", systemImage: "person.crop.circle.badge.plus")
                    }
                    Button {
                        Task { await toggleFavorito() }
                    } label: {
                        let esFav = vm.resp?.cliente.favorito == true
                        Label(esFav ? "Quitar favorito" : "Marcar favorito",
                              systemImage: esFav ? "star.slash" : "star.fill")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle").foregroundColor(Theme.deepGreen)
                }
            }
        }
        .sheet(isPresented: $showEditTags) {
            if let c = vm.resp?.cliente {
                EditarTagsSheet(clienteId: clienteId, nombreCliente: c.nombre, tags: c.tags) { _ in
                    Task { await vm.load() }
                }
            }
        }
        .sheet(isPresented: $showEditNotas) {
            EditarNotasClienteSheet(
                clienteId: clienteId,
                nombre: vm.resp?.cliente.nombre ?? nombre,
                notas: $notasDraft,
                telefono: vm.resp?.cliente.telefono ?? ""
            )
        }
        .onChange(of: showEditNotas) { _, showing in
            if !showing { Task { await vm.load() } }
        }
    }

    private func toggleFavorito() async {
        do {
            struct R: Decodable { let ok: Bool; let favorito: Bool }
            let _: R = try await APIClient.shared.postNoBody("clientes/\(clienteId)/favorito")
            await vm.load()
            Haptics.success()
            AppEvent.post(AppEvent.clientesChanged)
        } catch {
            toast.show((error as? APIError)?.errorDescription ?? "Error", kind: .error)
        }
    }

    private func guardarEnContactos() {
        guard let c = vm.resp?.cliente else { return }
        Task {
            let ok = await ContactSaver.guardar(nombre: c.nombre, telefono: c.telefono)
            await MainActor.run {
                if ok {
                    Haptics.success()
                    toast.show("Guardado en Contactos", kind: .success)
                } else {
                    Haptics.error()
                    toast.show("Sin permiso de contactos", kind: .error)
                }
            }
        }
    }

    func heroCard(_ r: ClienteDetalleResp) -> some View {
        let activos = r.prestamos.filter { $0.estado == "activo" }
        let saldoTotal = activos.reduce(0.0) { $0 + ($1.saldoPendiente ?? 0) }
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("SALDO ACTUAL").tracking(1.5).font(PType.caption(10)).foregroundColor(.white.opacity(0.78))
                Spacer()
                Text("\(activos.count) activo\(activos.count == 1 ? "" : "s")")
                    .font(PType.caption(11)).foregroundColor(.white)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Capsule().fill(Color.white.opacity(0.15)))
            }
            Text(MoneyFormat.mxn(saldoTotal)).font(PType.display(40)).foregroundColor(.white)
            HStack(spacing: 8) {
                heroSub("Total prestado", MoneyFormat.mxn(activos.reduce(0.0) { $0 + $1.principal }))
                heroSub("Préstamos", "\(r.prestamos.count)")
            }
            Text(r.cliente.telefono).font(PType.body(13)).foregroundColor(.white.opacity(0.82))
            HStack(spacing: 10) {
                heroAction(icon: "phone.fill", label: "Llamar") { llamar(r.cliente.telefono) }
                heroAction(icon: "message.fill", label: "WhatsApp") { abrirWhatsApp(r.cliente.telefono) }
                heroAction(icon: "envelope.fill", label: "SMS") { enviarSMS(r.cliente.telefono) }
            }
            .padding(.top, 6)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Theme.heroPrimary))
    }

    func heroAction(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap(); action()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 14, weight: .semibold))
                Text(label).font(PType.caption(10))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.14)))
        }
        .buttonStyle(PressableStyle(scale: 0.95))
    }

    private func telNormalizado(_ raw: String) -> String {
        let digits = raw.filter { $0.isNumber }
        // Si viene con 52 + 10, quítalo. Si viene con 10, quédatelo.
        if digits.hasPrefix("52") && digits.count > 10 { return String(digits.dropFirst(digits.count - 10)) }
        return digits
    }

    private func llamar(_ tel: String) {
        let d = telNormalizado(tel)
        if let url = URL(string: "tel://\(d)"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }

    private func abrirWhatsApp(_ tel: String) {
        let d = telNormalizado(tel)
        let full = "52\(d)"
        if let url = URL(string: "https://wa.me/\(full)") {
            UIApplication.shared.open(url)
        }
    }

    private func enviarSMS(_ tel: String) {
        let d = telNormalizado(tel)
        if let url = URL(string: "sms:\(d)"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
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

    func scoreCard(_ s: Score) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(scoreColor(s.nivel).opacity(0.15)).frame(width: 46, height: 46)
                Image(systemName: scoreIcon(s.nivel))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(scoreColor(s.nivel))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Nivel \(s.nivel.capitalized)").font(PType.bodyBold(15)).foregroundColor(Theme.ink)
                Text("\(s.puntos) puntos").font(PType.caption(12)).foregroundColor(Theme.inkSoft)
            }
            Spacer()
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.surfaceLight))
    }

    func scoreColor(_ nivel: String) -> Color {
        switch nivel {
        case "oro": Theme.warning
        case "plata": Theme.inkSoft
        case "bronce": Theme.coral
        case "bloqueado": Theme.danger
        default: Theme.deepGreen
        }
    }
    func scoreIcon(_ n: String) -> String {
        switch n {
        case "bloqueado": "lock.fill"
        default: "star.fill"
        }
    }

    func notasCard(_ n: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "note.text").foregroundColor(Theme.deepGreen).font(.system(size: 14, weight: .semibold))
            VStack(alignment: .leading, spacing: 4) {
                Text("NOTAS PRIVADAS").font(PType.caption(10)).tracking(1.2).foregroundColor(Theme.deepGreen)
                Text(n).font(PType.body(13)).foregroundColor(Theme.ink)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18).fill(Theme.softPrimary))
    }

    func prestamosSection(_ prestamos: [PrestamoResumen]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Préstamos").font(PType.title(20)).foregroundColor(Theme.ink)
                Spacer()
                Text("\(prestamos.count)")
                    .font(PType.caption(12)).foregroundColor(.white)
                    .padding(.horizontal, 10).padding(.vertical, 3)
                    .background(Capsule().fill(Theme.deepGreen))
            }
            if prestamos.isEmpty {
                Text("Sin préstamos aún").font(PType.body(14)).foregroundColor(Theme.inkSoft)
                    .padding(.vertical, 20).frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 20).fill(Theme.surfaceLight))
            } else {
                ForEach(prestamos) { p in
                    NavigationLink {
                        PrestamoDetalleView(prestamoId: p.id)
                    } label: {
                        prestamoRow(p)
                    }
                    .buttonStyle(PressableStyle(scale: 0.98))
                }
            }
        }
    }

    func prestamoRow(_ p: PrestamoResumen) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(estadoColor(p.estado).opacity(0.15)).frame(width: 44, height: 44)
                Image(systemName: estadoIcon(p.estado))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(estadoColor(p.estado))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(MoneyFormat.mxn(p.principal)).font(PType.bodyBold(15)).foregroundColor(Theme.ink)
                Text("\(String(format: "%.1f", p.tasaMensual * 100))% · \(p.plazoMeses) meses · \(p.estado)")
                    .font(PType.caption(11)).foregroundColor(Theme.inkSoft)
            }
            Spacer()
            if let saldo = p.saldoPendiente, saldo > 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(MoneyFormat.mxn(saldo)).font(PType.number(14)).foregroundColor(Theme.ink)
                    Text("pendiente").font(PType.caption(10)).foregroundColor(Theme.inkMuted)
                }
            }
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.inkMuted)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.surfaceLight))
    }

    func estadoColor(_ e: String) -> Color {
        switch e {
        case "activo": Theme.deepGreen
        case "liquidado": Theme.success
        case "cancelado": Theme.inkMuted
        default: Theme.warning
        }
    }
    func estadoIcon(_ e: String) -> String {
        switch e {
        case "activo": "circle.dashed"
        case "liquidado": "checkmark.seal.fill"
        case "cancelado": "xmark.circle"
        default: "clock.fill"
        }
    }

    func movimientosSection(_ mov: [Movimiento]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Últimos cobros").font(PType.title(20)).foregroundColor(Theme.ink)
            ForEach(mov.prefix(10)) { m in
                MovimientoRow(mov: m)
            }
        }
    }

    func errorBanner(_ msg: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "wifi.slash").font(.system(size: 32)).foregroundColor(Theme.warning)
            Text("Error cargando").font(PType.heading(16)).foregroundColor(Theme.ink)
            Text(msg).font(PType.caption(12)).foregroundColor(Theme.inkSoft).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(30)
        .background(RoundedRectangle(cornerRadius: 20).fill(Theme.surfaceLight))
    }
}
