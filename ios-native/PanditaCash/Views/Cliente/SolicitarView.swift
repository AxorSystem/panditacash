import SwiftUI

@MainActor
final class SolicitarVM: ObservableObject {
    @Published var monto: Double = 5000
    @Published var plazoMeses: Int = 3
    @Published var motivo: String = ""
    @Published var loading = false

    struct Body: Encodable { let monto_solicitado: Double; let plazo_meses: Int; let motivo: String? }

    func enviar() async throws {
        loading = true; defer { loading = false }
        let b = Body(monto_solicitado: monto, plazo_meses: plazoMeses, motivo: motivo.isEmpty ? nil : motivo)
        struct R: Decodable {}
        let _: R = try await APIClient.shared.post("solicitudes", body: b)
    }
}

struct SolicitarView: View {
    @StateObject var vm = SolicitarVM()
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var toast: ToastCenter
    var nivelMax: Double = 500

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    header
                    montoCard
                    plazoCard
                    motivoCard
                    PandaButton(title: "Enviar solicitud a mamá", icon: "paperplane.fill", loading: vm.loading) {
                        Task {
                            do {
                                try await vm.enviar()
                                Haptics.success()
                                toast.show("Solicitud enviada 🐼", kind: .success)
                                AppEvent.post(AppEvent.solicitudesChanged)
                                dismiss()
                            } catch {
                                Haptics.error()
                                toast.show((error as? APIError)?.errorDescription ?? "Error", kind: .error)
                            }
                        }
                    }
                    .padding(.top, 8)
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
        VStack(spacing: 6) {
            Text("💫").font(.system(size: 44))
            Text("Solicitar préstamo").font(PType.title(24)).foregroundColor(Theme.ink)
            Text("Mamá revisará tu petición")
                .font(PType.body(14)).foregroundColor(Theme.inkSoft)
        }
    }

    var montoCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("¿Cuánto necesitas?").font(PType.heading(15)).foregroundColor(Theme.ink)
                Text(MoneyFormat.mxn(vm.monto))
                    .font(PType.number(40))
                    .foregroundColor(Theme.ink)
                    .contentTransition(.numericText(value: vm.monto))
                    .animation(.spring(response: 0.3, dampingFraction: 0.85), value: vm.monto)
                Slider(value: $vm.monto, in: 500...max(nivelMax, 1000), step: 500) { editing in
                    if !editing { Haptics.selection() }
                }
                .tint(Theme.deepGreen)
                HStack {
                    Text("$500").font(PType.caption(11)).foregroundColor(Theme.inkMuted)
                    Spacer()
                    Text("Tu tope: \(MoneyFormat.mxn(nivelMax))").font(PType.caption(11)).foregroundColor(Theme.inkSoft)
                }
            }
        }
    }

    var plazoCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("¿En cuánto tiempo pagarás?").font(PType.heading(15)).foregroundColor(Theme.ink)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach([1,2,3,4,6,9,12], id: \.self) { m in
                            Button {
                                Haptics.selection()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { vm.plazoMeses = m }
                            } label: {
                                VStack(spacing: 2) {
                                    Text("\(m)").font(PType.number(20)).foregroundColor(vm.plazoMeses == m ? .white : Theme.ink)
                                    Text(m == 1 ? "mes" : "meses").font(PType.caption(10)).foregroundColor(vm.plazoMeses == m ? .white.opacity(0.85) : Theme.inkSoft)
                                }
                                .frame(width: 60, height: 60)
                                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(vm.plazoMeses == m ? AnyShapeStyle(Theme.heroPrimary) : AnyShapeStyle(Color.white.opacity(0.6))))
                            }
                            .buttonStyle(PressableStyle(scale: 0.9))
                        }
                    }
                }
            }
        }
    }

    var motivoCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("¿Para qué? (opcional)").font(PType.heading(15)).foregroundColor(Theme.ink)
                TextField("Ej: pago de escuela, emergencia médica...", text: $vm.motivo, axis: .vertical)
                    .font(PType.body(14))
                    .lineLimit(2...4)
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.background).overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.hairline, lineWidth: 1)))
            }
        }
    }
}
