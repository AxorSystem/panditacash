import SwiftUI
import UIKit

@MainActor
final class KYCPendientesVM: ObservableObject {
    @Published var clientes: [KYCPendienteCliente] = []
    @Published var loading = false

    func load() async {
        loading = true; defer { loading = false }
        clientes = (try? await APIClient.shared.get("kyc/pendientes")) ?? []
    }
}

struct MamaKYCPendientesView: View {
    @StateObject var vm = KYCPendientesVM()
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header.padding(.horizontal, 20).padding(.top, 12)

                    if vm.loading && vm.clientes.isEmpty {
                        ProgressView().tint(Theme.deepGreen).padding(.top, 60)
                    } else if vm.clientes.isEmpty {
                        empty.padding(.top, 60)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(vm.clientes) { c in
                                NavigationLink {
                                    MamaKYCRevisionView(clienteId: c.id, nombre: c.nombre)
                                } label: {
                                    row(c)
                                }
                                .buttonStyle(PressableStyle(scale: 0.98))
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    Spacer(minLength: 120)
                }
            }
            .refreshable { await vm.load() }
            .task { await vm.load() }
        }
        .navigationTitle("Validaciones")
        .navigationBarTitleDisplayMode(.inline)
    }

    var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Validaciones pendientes").font(PType.title(24)).foregroundColor(Theme.ink)
            Text("Revisa los documentos que subieron los clientes")
                .font(PType.body(13)).foregroundColor(Theme.inkSoft)
        }
    }

    var empty: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 52))
                .foregroundColor(Theme.deepGreen)
            Text("Todo al día").font(PType.heading(16)).foregroundColor(Theme.ink)
            Text("Ningún cliente pendiente de validar")
                .font(PType.body(13)).foregroundColor(Theme.inkSoft).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    func row(_ c: KYCPendienteCliente) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Theme.softPrimary).frame(width: 48, height: 48)
                Text(String(c.nombre.prefix(1).uppercased()))
                    .font(PType.bodyBold(17)).foregroundColor(Theme.deepGreen)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(c.nombre).font(PType.bodyBold(15)).foregroundColor(Theme.ink)
                HStack(spacing: 6) {
                    Image(systemName: "doc.fill").font(.system(size: 10)).foregroundColor(Theme.inkSoft)
                    Text("\(c.docsValidados)/\(c.docsSubidos) validados")
                        .font(PType.caption(12)).foregroundColor(Theme.inkSoft)
                    if c.avalesN > 0 {
                        Text("· aval").font(PType.caption(12)).foregroundColor(Theme.deepGreen)
                    }
                }
            }
            Spacer()
            HStack(spacing: 4) {
                Text("Revisar").font(PType.bodyBold(12)).foregroundColor(Theme.deepGreen)
                Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold)).foregroundColor(Theme.deepGreen)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.surfaceLight))
    }
}

// MARK: - Revisión individual

@MainActor
final class KYCRevisionVM: ObservableObject {
    let clienteId: Int
    @Published var detalle: KYCClienteDetalle?
    @Published var loading = false
    @Published var updating = false

    init(clienteId: Int) { self.clienteId = clienteId }

    func load() async {
        loading = true; defer { loading = false }
        detalle = try? await APIClient.shared.get("kyc/cliente/\(clienteId)")
    }

    struct ValidarBody: Encodable { let validado: Bool; let notas: String? }

    func validar(docId: Int, aprobar: Bool, notas: String?) async throws {
        updating = true; defer { updating = false }
        struct R: Decodable {}
        let _: R = try await APIClient.shared.post("kyc/documento/\(docId)/validar",
                                                   body: ValidarBody(validado: aprobar, notas: notas))
        await load()
    }
}

struct MamaKYCRevisionView: View {
    let clienteId: Int
    let nombre: String
    @StateObject private var vm: KYCRevisionVM
    @EnvironmentObject var toast: ToastCenter

    init(clienteId: Int, nombre: String) {
        self.clienteId = clienteId
        self.nombre = nombre
        _vm = StateObject(wrappedValue: KYCRevisionVM(clienteId: clienteId))
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let d = vm.detalle {
                        clienteCard(d.usuario).padding(.horizontal, 20).padding(.top, 12)

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Documentos").font(PType.title(20)).foregroundColor(Theme.ink)
                                .padding(.horizontal, 20)
                            ForEach(d.documentos) { doc in
                                docCard(doc)
                                    .padding(.horizontal, 20)
                            }
                        }

                        if !d.avales.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Aval").font(PType.title(20)).foregroundColor(Theme.ink)
                                    .padding(.horizontal, 20)
                                ForEach(d.avales) { av in
                                    avalCard(av).padding(.horizontal, 20)
                                }
                            }
                        }
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
    }

    func clienteCard(_ u: UsuarioBasico) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(u.nombre).font(PType.bodyBold(16)).foregroundColor(.white)
                Spacer()
                if u.kycCompleto == true {
                    Text("Verificado")
                        .font(PType.caption(11)).foregroundColor(.white)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Capsule().fill(Color.white.opacity(0.15)))
                }
            }
            Text(u.telefono).font(PType.body(13)).foregroundColor(.white.opacity(0.78))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Theme.heroPrimary))
    }

    func docCard(_ doc: DocumentoDetalle) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(doc.tipoLabel).font(PType.bodyBold(14)).foregroundColor(Theme.ink)
                Spacer()
                docEstadoChip(doc)
            }
            if let notas = doc.notas, !notas.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "text.bubble.fill").foregroundColor(Theme.inkSoft).font(.system(size: 11))
                    Text(notas).font(PType.caption(12)).foregroundColor(Theme.inkSoft)
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.softWarning.opacity(0.6)))
            }
            NavigationLink {
                DocImageViewer(docId: doc.id, titulo: doc.tipoLabel)
            } label: {
                AsyncImageAuth(docId: doc.id)
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .background(Color.black.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(6)
                            .background(Circle().fill(Color.black.opacity(0.5)))
                            .padding(8)
                    }
            }
            .buttonStyle(PressableStyle(scale: 0.98))

            HStack(spacing: 10) {
                Button {
                    Task {
                        do {
                            try await vm.validar(docId: doc.id, aprobar: true, notas: nil)
                            Haptics.success()
                            toast.show("Aprobado", kind: .success)
                        } catch {
                            Haptics.error()
                            toast.show((error as? APIError)?.errorDescription ?? "Error", kind: .error)
                        }
                    }
                } label: {
                    Label("Aprobar", systemImage: "checkmark")
                        .font(PType.bodyBold(14)).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Capsule().fill(Theme.success))
                }
                .buttonStyle(PressableStyle(scale: 0.97))

                Button {
                    Task {
                        do {
                            try await vm.validar(docId: doc.id, aprobar: false, notas: "Foto no válida")
                            Haptics.warning()
                            toast.show("Rechazado", kind: .info)
                        } catch {
                            Haptics.error()
                            toast.show((error as? APIError)?.errorDescription ?? "Error", kind: .error)
                        }
                    }
                } label: {
                    Label("Rechazar", systemImage: "xmark")
                        .font(PType.bodyBold(14)).foregroundColor(Theme.danger)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Capsule().fill(Theme.softDanger))
                }
                .buttonStyle(PressableStyle(scale: 0.97))
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.surfaceLight))
    }

    func avalCard(_ av: AvalDetalle) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Theme.softPrimary).frame(width: 42, height: 42)
                    Image(systemName: "person.fill").font(.system(size: 15, weight: .semibold)).foregroundColor(Theme.deepGreen)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(av.nombre).font(PType.bodyBold(14)).foregroundColor(Theme.ink)
                    Text("\(av.telefono) · \(av.relacion ?? "-")")
                        .font(PType.caption(12)).foregroundColor(Theme.inkSoft)
                }
                Spacer()
                estadoChip(av.verificadoWa)
            }
            HStack(spacing: 8) {
                avalAction(icon: "phone.fill", label: "Llamar") { llamarAval(av) }
                avalAction(icon: "message.fill", label: "WhatsApp") { waAval(av, nombreCliente: nombre) }
                Button {
                    Task {
                        do {
                            try await KYCService.shared.borrarAval(id: av.id)
                            await vm.load()
                            toast.show("Aval eliminado", kind: .info)
                            Haptics.warning()
                        } catch {
                            toast.show((error as? APIError)?.errorDescription ?? "Error", kind: .error)
                        }
                    }
                } label: {
                    Image(systemName: "trash").font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.danger)
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.softDanger))
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.surfaceLight))
    }

    private func avalAction(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap(); action()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 11, weight: .semibold))
                Text(label).font(PType.bodyBold(12))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity).padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.deepGreen))
        }
        .buttonStyle(PressableStyle(scale: 0.96))
    }

    private func telNorm(_ raw: String) -> String {
        let d = raw.filter { $0.isNumber }
        return d.count > 10 ? String(d.suffix(10)) : d
    }
    private func llamarAval(_ av: AvalDetalle) {
        let d = telNorm(av.telefono)
        if let url = URL(string: "tel://\(d)"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
    private func waAval(_ av: AvalDetalle, nombreCliente: String) {
        let d = telNorm(av.telefono)
        let msg = "Hola \(av.nombre.split(separator: " ").first.map(String.init) ?? av.nombre), soy de PanditaCash. \(nombreCliente) te puso como aval. ¿Nos podrías confirmar?"
        let enc = msg.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "https://wa.me/52\(d)?text=\(enc)") {
            UIApplication.shared.open(url)
        }
    }

    func estadoChip(_ ok: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: ok ? "checkmark.circle.fill" : "hourglass")
                .font(.system(size: 10, weight: .semibold))
            Text(ok ? "OK" : "Pendiente").font(PType.caption(11))
        }
        .foregroundColor(ok ? Theme.success : Theme.warning)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Capsule().fill(ok ? Theme.softSuccess : Theme.softWarning))
    }
}

// Cambio de vista para mostrar el estado real del doc (aprobado/rechazado/pendiente)
// Visor pantalla completa con pinch-to-zoom y pan.
struct DocImageViewer: View {
    let docId: Int
    let titulo: String
    @State private var image: UIImage?
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { v in scale = max(0.9, min(6, lastScale * v)) }
                            .onEnded { _ in lastScale = scale }
                    )
                    .simultaneousGesture(
                        DragGesture()
                            .onChanged { v in
                                offset = CGSize(width: lastOffset.width + v.translation.width,
                                                height: lastOffset.height + v.translation.height)
                            }
                            .onEnded { _ in lastOffset = offset }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation {
                            if scale > 1 { scale = 1; lastScale = 1; offset = .zero; lastOffset = .zero }
                            else { scale = 2.5; lastScale = 2.5 }
                        }
                    }
            } else {
                ProgressView().tint(.white)
            }
        }
        .navigationTitle(titulo)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task { await load() }
    }

    private func load() async {
        var req = URLRequest(url: APIClient.shared.baseURL.appendingPathComponent("kyc/documento/\(docId)/imagen"))
        if let t = Keychain.get("auth.token") { req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization") }
        if let (data, resp) = try? await URLSession.shared.data(for: req),
           let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode),
           let img = UIImage(data: data) {
            image = img
        }
    }
}

extension DocumentoDetalle {
    var estadoLabel: (String, Color, String) {
        if validado { return ("Aprobado", Theme.success, "checkmark.seal.fill") }
        if validadoPor != nil { return ("Rechazado", Theme.danger, "xmark.seal.fill") }
        return ("Sin revisar", Theme.warning, "hourglass")
    }
}

private func docEstadoChip(_ doc: DocumentoDetalle) -> some View {
    let (text, color, icon) = doc.estadoLabel
    return HStack(spacing: 4) {
        Image(systemName: icon).font(.system(size: 11, weight: .semibold))
        Text(text).font(PType.caption(11))
    }
    .foregroundColor(color)
    .padding(.horizontal, 10).padding(.vertical, 5)
    .background(Capsule().fill(color.opacity(0.15)))
}

// MARK: - AsyncImage con auth

struct AsyncImageAuth: View {
    let docId: Int
    @State private var image: UIImage?
    @State private var loading = true

    var body: some View {
        Group {
            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else if loading {
                ProgressView().tint(Theme.deepGreen)
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "photo").font(.system(size: 32)).foregroundColor(Theme.inkMuted)
                    Text("Imagen no disponible")
                        .font(PType.caption(11))
                        .foregroundColor(Theme.inkMuted)
                }
            }
        }
        .task { await load() }
    }

    func load() async {
        loading = true; defer { loading = false }
        var req = URLRequest(url: APIClient.shared.baseURL.appendingPathComponent("kyc/documento/\(docId)/imagen"))
        if let token = Keychain.get("auth.token") {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let (data, resp) = try? await URLSession.shared.data(for: req),
           let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode),
           let img = UIImage(data: data) {
            image = img
        }
    }
}
