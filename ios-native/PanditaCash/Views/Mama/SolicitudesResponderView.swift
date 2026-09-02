import SwiftUI

@MainActor
final class ResponderVM: ObservableObject {
    let solicitud: SolicitudPendiente
    @Published var accion: Accion = .aprobar
    @Published var tasaMensualPct: Double = 10
    @Published var moraDiariaPct: Double = 1
    @Published var frecuencia: NuevoPrestamoVM.Frecuencia = .mensual
    @Published var notas: String = ""
    @Published var submitting = false

    enum Accion: String { case aprobar, rechazar }

    init(solicitud: SolicitudPendiente) {
        self.solicitud = solicitud
    }

    struct Body: Encodable {
        let accion: String
        let tasa_mensual: Double?
        let mora_diaria: Double?
        let frecuencia: String?
        let notas: String?
    }

    func responder() async throws {
        submitting = true; defer { submitting = false }
        let b: Body
        switch accion {
        case .aprobar:
            b = Body(accion: "aprobar", tasa_mensual: tasaMensualPct / 100, mora_diaria: moraDiariaPct / 100, frecuencia: frecuencia.rawValue, notas: notas.isEmpty ? nil : notas)
        case .rechazar:
            b = Body(accion: "rechazar", tasa_mensual: nil, mora_diaria: nil, frecuencia: nil, notas: notas.isEmpty ? nil : notas)
        }
        struct R: Decodable {}
        let _: R = try await APIClient.shared.post("solicitudes/\(solicitud.id)/responder", body: b)
    }
}

struct SolicitudResponderView: View {
    @StateObject var vm: ResponderVM
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var toast: ToastCenter

    init(solicitud: SolicitudPendiente) {
        _vm = StateObject(wrappedValue: ResponderVM(solicitud: solicitud))
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    header
                    resumenCard
                    toggleAccion
                    if vm.accion == .aprobar {
                        tasaCard
                        frecuenciaCard
                    }
                    notasCard
                    PandaButton(
                        title: vm.accion == .aprobar ? "Aprobar y crear préstamo" : "Rechazar solicitud",
                        icon: vm.accion == .aprobar ? "checkmark.seal.fill" : "xmark.seal.fill",
                        loading: vm.submitting
                    ) {
                        Task {
                            do {
                                try await vm.responder()
                                Haptics.success()
                                toast.show(vm.accion == .aprobar ? "Préstamo creado" : "Solicitud rechazada", kind: .success)
                                AppEvent.post(AppEvent.solicitudesChanged)
                                AppEvent.post(AppEvent.prestamosChanged)
                                AppEvent.post(AppEvent.clientesChanged)
                                dismiss()
                            } catch {
                                Haptics.error()
                                toast.show((error as? APIError)?.errorDescription ?? "Error", kind: .error)
                            }
                        }
                    }
                    .padding(.top, 6)
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
            }
        }
        .presentationDetents([.large])
        .presentationBackground(Theme.background)
        .presentationDragIndicator(.visible)
    }

    var header: some View {
        VStack(spacing: 4) {
            Text("Responder solicitud").font(PType.title(22)).foregroundColor(Theme.ink)
            Text(vm.solicitud.clienteNombre).font(PType.body(14)).foregroundColor(Theme.inkSoft)
        }
    }

    var resumenCard: some View {
        GlassCard(padding: 18, cornerRadius: 22, tint: Color(hex: 0xF2F2F7)) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Solicita").font(PType.body(13)).foregroundColor(Theme.inkSoft)
                    Spacer()
                    Text(MoneyFormat.mxn(vm.solicitud.montoSolicitado))
                        .font(PType.number(24)).foregroundColor(Theme.ink)
                }
                HStack {
                    Text("Plazo").font(PType.body(13)).foregroundColor(Theme.inkSoft)
                    Spacer()
                    Text("\(vm.solicitud.plazoMeses) meses").font(PType.bodyBold(14)).foregroundColor(Theme.ink)
                }
                if let m = vm.solicitud.motivo, !m.isEmpty {
                    Divider().overlay(Theme.hairline)
                    Text("« \(m) »").font(PType.body(13)).foregroundColor(Theme.inkSoft).italic()
                }
            }
        }
    }

    var toggleAccion: some View {
        HStack(spacing: 4) {
            accionBtn(.aprobar, label: "Aprobar", icon: "checkmark", tint: Theme.success)
            accionBtn(.rechazar, label: "Rechazar", icon: "xmark", tint: Theme.danger)
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(0.6)).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14)))
    }

    func accionBtn(_ a: ResponderVM.Accion, label: String, icon: String, tint: Color) -> some View {
        Button {
            Haptics.selection()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { vm.accion = a }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 12, weight: .bold))
                Text(label).font(PType.bodyBold(14))
            }
            .foregroundColor(vm.accion == a ? .white : Theme.ink.opacity(0.7))
            .frame(maxWidth: .infinity).padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(vm.accion == a ? tint : .clear))
        }
        .buttonStyle(PressableStyle(scale: 0.97))
    }

    var tasaCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Tasa mensual").font(PType.heading(15)).foregroundColor(Theme.ink)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(String(format: "%.1f", vm.tasaMensualPct)).font(PType.number(30)).foregroundColor(Theme.ink)
                    Text("%").font(PType.title(18)).foregroundColor(Theme.inkSoft)
                }
                Slider(value: $vm.tasaMensualPct, in: 1...30, step: 0.5)
                    .tint(Theme.deepGreen)
            }
        }
    }

    var frecuenciaCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Frecuencia").font(PType.heading(15)).foregroundColor(Theme.ink)
                HStack(spacing: 8) {
                    ForEach(NuevoPrestamoVM.Frecuencia.allCases, id: \.self) { f in
                        Button {
                            Haptics.selection()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { vm.frecuencia = f }
                        } label: {
                            Text(f.label)
                                .font(PType.bodyBold(13))
                                .foregroundColor(vm.frecuencia == f ? .white : Theme.ink.opacity(0.7))
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(vm.frecuencia == f ? AnyShapeStyle(Theme.heroPrimary) : AnyShapeStyle(Color.white.opacity(0.6))))
                        }
                        .buttonStyle(PressableStyle(scale: 0.97))
                    }
                }
            }
        }
    }

    var notasCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(vm.accion == .aprobar ? "Notas para el cliente (opcional)" : "Motivo del rechazo (opcional)").font(PType.heading(15)).foregroundColor(Theme.ink)
                TextField("Ej: te presto pero cuidado con los pagos", text: $vm.notas, axis: .vertical)
                    .font(PType.body(14))
                    .lineLimit(2...4)
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.background).overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.hairline, lineWidth: 1)))
            }
        }
    }
}
