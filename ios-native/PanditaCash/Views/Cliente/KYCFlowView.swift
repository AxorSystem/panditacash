import SwiftUI
import PhotosUI
import UIKit

@MainActor
final class KYCFlowVM: ObservableObject {
    enum Step: Int, CaseIterable {
        case bienvenida = 0
        case ineFrente
        case ineReverso
        case selfie
        case aval
        case listo

        var progreso: Double { Double(rawValue) / Double(Step.listo.rawValue) }
    }

    @Published var step: Step = .bienvenida

    /// Empieza en el step correspondiente según lo que ya subió el user.
    func resumeDesdeStatus(_ status: KYCStatus?) {
        guard let s = status, step == .bienvenida else { return }
        let docs = Set(s.documentos.map { $0.tipo })
        if !docs.contains("ine_frente") { step = .ineFrente }
        else if !docs.contains("ine_reverso") { step = .ineReverso }
        else if !docs.contains("selfie") { step = .selfie }
        else if s.avalesVerificados == 0 { step = .aval }
        else { step = .listo }
    }
    @Published var uploading = false
    @Published var errorMsg: String?

    // Fotos capturadas
    @Published var ineFrente: UIImage?
    @Published var ineReverso: UIImage?
    @Published var selfie: UIImage?

    // Aval
    @Published var avalNombre = ""
    @Published var avalTelefono = ""
    @Published var avalRelacion = "familiar"
    let relaciones = ["familiar", "amigo", "pareja", "trabajo"]

    func avanzar() {
        if let next = Step(rawValue: step.rawValue + 1) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) { step = next }
        }
    }
    func retroceder() {
        if let prev = Step(rawValue: step.rawValue - 1) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) { step = prev }
        }
    }

    func subirDocumento(_ tipo: KYCTipo, image: UIImage) async -> Bool {
        // 1) Pre-validación on-device con Vision
        let result = await KYCImageValidator.validate(image, for: tipo)
        if !result.ok {
            errorMsg = result.mensaje ?? "Imagen no aceptada"
            return false
        }

        // 2) Subida al backend
        uploading = true
        defer { uploading = false }
        do {
            let _ = try await KYCService.shared.uploadDocumento(tipo, image: image)
            errorMsg = nil
            AppEvent.post(AppEvent.kycChanged)
            return true
        } catch {
            errorMsg = (error as? APIError)?.errorDescription ?? error.localizedDescription
            return false
        }
    }

    func guardarAval() async -> Bool {
        guard !avalNombre.isEmpty, avalTelefono.count >= 10 else {
            errorMsg = "Nombre y teléfono son obligatorios"
            return false
        }
        do {
            try await KYCService.shared.agregarAval(nombre: avalNombre, telefono: avalTelefono, relacion: avalRelacion)
            errorMsg = nil
            return true
        } catch {
            errorMsg = (error as? APIError)?.errorDescription ?? error.localizedDescription
            return false
        }
    }
}

struct KYCFlowView: View {
    @StateObject var vm = KYCFlowVM()
    @StateObject var kyc = KYCService.shared
    @Environment(\.dismiss) var dismiss
    let onFinish: () -> Void

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 20) {
                headerBar

                Group {
                    switch vm.step {
                    case .bienvenida: BienvenidaKYC(vm: vm)
                    case .ineFrente: KYCPhotoStep(vm: vm, tipo: .ineFrente, image: $vm.ineFrente)
                    case .ineReverso: KYCPhotoStep(vm: vm, tipo: .ineReverso, image: $vm.ineReverso)
                    case .selfie: KYCPhotoStep(vm: vm, tipo: .selfie, image: $vm.selfie, camera: true)
                    case .aval: AvalStep(vm: vm)
                    case .listo: ListoStep(onFinish: {
                        onFinish()
                        dismiss()
                    })
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)))
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
    }

    var headerBar: some View {
        VStack(spacing: 12) {
            HStack {
                if vm.step != .bienvenida && vm.step != .listo {
                    Button {
                        Haptics.tap(); vm.retroceder()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Theme.deepGreen)
                            .frame(width: 42, height: 42)
                            .background(Circle().fill(Theme.surfaceLight))
                    }
                } else {
                    Color.clear.frame(width: 42, height: 42)
                }
                Spacer()
                Text("Verificación de identidad")
                    .font(PType.bodyBold(14))
                    .foregroundColor(Theme.inkSoft)
                Spacer()
                Button {
                    Haptics.tap(); dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.deepGreen)
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(Theme.surfaceLight))
                }
            }
            progressBar
        }
    }

    var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.softPrimary).frame(height: 6)
                Capsule().fill(Theme.deepGreen).frame(width: geo.size.width * vm.step.progreso, height: 6)
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: vm.step)
            }
        }
        .frame(height: 6)
    }
}

// MARK: - Steps

struct BienvenidaKYC: View {
    @ObservedObject var vm: KYCFlowVM

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 20)
            ZStack {
                Circle().fill(Theme.softPrimary).frame(width: 180, height: 180)
                Text("🛡️").font(.system(size: 90))
            }
            VStack(spacing: 10) {
                Text("Verifica tu identidad")
                    .font(PType.title(28))
                    .foregroundColor(Theme.ink)
                    .multilineTextAlignment(.center)
                Text("Toma 3 minutos y te permite pedir hasta $20,000. Todo se encripta y solo mamá puede verlo.")
                    .font(PType.body(15))
                    .foregroundColor(Theme.inkSoft)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            benefitsList
            Spacer()
            DuoButton(title: "Empezar", icon: "arrow.right") { vm.avanzar() }
                .padding(.bottom, 12)
        }
    }

    var benefitsList: some View {
        VStack(spacing: 10) {
            benefitRow(icon: "checkmark.circle.fill", text: "Foto de tu INE (frente + reverso)")
            benefitRow(icon: "checkmark.circle.fill", text: "Selfie con tu INE")
            benefitRow(icon: "checkmark.circle.fill", text: "1 contacto de referencia (aval)")
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.surfaceLight))
    }

    func benefitRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundColor(Theme.deepGreen).font(.system(size: 16, weight: .semibold))
            Text(text).font(PType.body(14)).foregroundColor(Theme.ink)
            Spacer()
        }
    }
}

struct KYCPhotoStep: View {
    @ObservedObject var vm: KYCFlowVM
    let tipo: KYCTipo
    @Binding var image: UIImage?
    var camera: Bool = false

    @State private var showPicker = false
    @State private var showCamera = false
    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    headerText
                    imagePreview
                    if let err = vm.errorMsg {
                        errorBanner(err)
                    }
                    actionButtons
                    Spacer(minLength: 40)
                }
                .padding(.bottom, 20)
            }

            // Botón sticky abajo
            DuoButton(
                title: image == nil ? "Selecciona una foto" : "Confirmar y continuar",
                icon: image == nil ? "camera.fill" : "arrow.right",
                loading: vm.uploading,
                disabled: image == nil
            ) {
                Task {
                    if let img = image, await vm.subirDocumento(tipo, image: img) {
                        vm.avanzar()
                    }
                }
            }
            .padding(.top, 10)
            .padding(.bottom, 12)
            .background(
                Theme.background
                    .overlay(alignment: .top) {
                        LinearGradient(colors: [Theme.background.opacity(0), Theme.background],
                                       startPoint: .top, endPoint: .bottom)
                            .frame(height: 20)
                            .offset(y: -20)
                    }
            )
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraCapture(image: $image)
        }
        .onChange(of: image) { _, _ in
            vm.errorMsg = nil
        }
    }

    func errorBanner(_ msg: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Theme.warning)
            Text(msg).font(PType.body(13)).foregroundColor(Theme.ink)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.softWarning))
    }

    var headerText: some View {
        VStack(spacing: 8) {
            Text(tipo.titulo).font(PType.title(22)).foregroundColor(Theme.ink).multilineTextAlignment(.center)
            Text(tipo.descripcion).font(PType.body(14)).foregroundColor(Theme.inkSoft).multilineTextAlignment(.center)
        }
        .padding(.horizontal, 16)
    }

    var imagePreview: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(Theme.surfaceLight)
            .aspectRatio(4/3, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .clipped()
            .overlay {
                if let img = image {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 44, weight: .light))
                            .foregroundColor(Theme.inkMuted)
                        Text("Vista previa aparecerá aquí")
                            .font(PType.body(13)).foregroundColor(Theme.inkMuted)
                    }
                }
            }
    }

    var actionButtons: some View {
        HStack(spacing: 10) {
            if !camera {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Label("Galería", systemImage: "photo.fill")
                        .font(PType.bodyBold(14))
                        .foregroundColor(Theme.deepGreen)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.surfaceLight))
                }
                .onChange(of: pickerItem) { _, new in
                    Task {
                        if let data = try? await new?.loadTransferable(type: Data.self),
                           let img = UIImage(data: data) {
                            image = img
                        }
                    }
                }
            }
            Button {
                Haptics.tap(); showCamera = true
            } label: {
                Label("Cámara", systemImage: "camera.fill")
                    .font(PType.bodyBold(14))
                    .foregroundColor(Theme.deepGreen)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.surfaceLight))
            }
            .buttonStyle(PressableStyle())
        }
    }
}

struct AvalStep: View {
    @ObservedObject var vm: KYCFlowVM
    @FocusState private var focus: Field?
    @State private var showContactos = false
    enum Field { case nombre, tel }

    var body: some View {
        VStack(spacing: 20) {
            headerBlock
            Button {
                Haptics.tap(); showContactos = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "person.crop.circle.badge.plus").font(.system(size: 14, weight: .semibold))
                    Text("Elegir desde contactos").font(PType.bodyBold(13))
                }
                .foregroundColor(Theme.deepGreen)
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Capsule().fill(Theme.softPrimary))
            }
            formCard
            infoNote
            Spacer()
            DuoButton(title: "Guardar aval", icon: "arrow.right",
                      loading: vm.uploading,
                      disabled: vm.avalNombre.isEmpty || vm.avalTelefono.count < 10) {
                Task {
                    if await vm.guardarAval() { vm.avanzar() }
                }
            }
            .padding(.bottom, 12)
        }
        .sheet(isPresented: $showContactos) {
            ContactPicker { nombre, tel in
                let short = tel.count > 10 ? String(tel.suffix(10)) : tel
                vm.avalNombre = nombre
                vm.avalTelefono = short
                showContactos = false
            }
            .ignoresSafeArea()
        }
    }

    var headerBlock: some View {
        VStack(spacing: 10) {
            Text("Agrega tu aval").font(PType.title(24)).foregroundColor(Theme.ink)
            Text("Persona de confianza a quien mamá podrá contactar si no llegas a pagar")
                .font(PType.body(14)).foregroundColor(Theme.inkSoft).multilineTextAlignment(.center).padding(.horizontal, 20)
        }
    }

    var formCard: some View {
        VStack(spacing: 12) {
            KYCInputField(icon: "person.fill", placeholder: "Nombre completo del aval", text: $vm.avalNombre)
                .focused($focus, equals: .nombre)
            KYCInputField(icon: "phone.fill", placeholder: "Teléfono (10 dígitos)", text: $vm.avalTelefono, keyboard: .phonePad)
                .focused($focus, equals: .tel)
            relacionPicker
        }
    }

    var relacionPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Relación").font(PType.caption(12)).foregroundColor(Theme.inkSoft).padding(.leading, 4)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(vm.relaciones, id: \.self) { r in
                        Button {
                            Haptics.selection(); vm.avalRelacion = r
                        } label: {
                            Text(r.capitalized)
                                .font(PType.bodyBold(13))
                                .foregroundColor(vm.avalRelacion == r ? .white : Theme.deepGreen)
                                .padding(.horizontal, 16).padding(.vertical, 10)
                                .background(Capsule().fill(vm.avalRelacion == r ? Theme.deepGreen : Theme.surfaceLight))
                        }
                    }
                }
            }
        }
    }

    var infoNote: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle.fill").foregroundColor(Theme.deepGreen)
            Text("Le mandaremos un WhatsApp preguntando si acepta ser tu aval")
                .font(PType.caption(12)).foregroundColor(Theme.inkSoft)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.softPrimary))
    }
}

struct ListoStep: View {
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle().fill(Theme.softPrimary).frame(width: 200, height: 200)
                Text("🎉").font(.system(size: 110))
            }
            VStack(spacing: 12) {
                Text("¡Todo listo!").font(PType.title(30)).foregroundColor(Theme.ink)
                Text("Mamá revisará tus documentos.\nEn máximo 24h podrás solicitar tu primer préstamo.")
                    .font(PType.body(15))
                    .foregroundColor(Theme.inkSoft)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            Spacer()
            DuoButton(title: "Ir al inicio", icon: "house.fill") { onFinish() }
                .padding(.bottom, 12)
        }
    }
}

struct KYCInputField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 14, weight: .semibold)).foregroundColor(Theme.deepGreen).frame(width: 22)
            TextField(placeholder, text: $text)
                .font(PType.bodyBold(15))
                .foregroundColor(Theme.ink)
                .keyboardType(keyboard)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 16).padding(.vertical, 16)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surfaceLight))
    }
}

// MARK: - Camera

struct CameraCapture: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let vc = UIImagePickerController()
        vc.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        vc.delegate = context.coordinator
        return vc
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraCapture
        init(_ parent: CameraCapture) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let img = info[.originalImage] as? UIImage {
                parent.image = img
            }
            parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
