import SwiftUI

struct SimuladorPublicoView: View {
    @Environment(\.dismiss) var dismiss
    @State private var principal: Double = 10000
    @State private var tasaMensualPct: Double = 5
    @State private var plazoMeses: Int = 6
    @State private var frecuencia: String = "mensual"

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        parametros
                        resultado
                        Text("Este es un cálculo estimado. Los términos finales los define mamá al aprobar tu solicitud.")
                            .font(PType.caption(11))
                            .foregroundColor(Theme.inkMuted)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                }
            }
            .navigationTitle("Simulador")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") { dismiss() }.foregroundColor(Theme.deepGreen)
                }
            }
        }
    }

    var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("¿Cuánto necesitas?").font(PType.title(24)).foregroundColor(Theme.ink)
            Text("Ajusta los sliders y ve cuánto pagarías")
                .font(PType.body(13)).foregroundColor(Theme.inkSoft)
        }
    }

    var parametros: some View {
        VStack(spacing: 18) {
            card(title: "Monto solicitado", value: MoneyFormat.mxn(principal)) {
                Slider(value: $principal, in: 500...20000, step: 500).tint(Theme.deepGreen)
                HStack {
                    Text("$500").font(PType.caption(10)).foregroundColor(Theme.inkMuted)
                    Spacer()
                    Text("$20,000").font(PType.caption(10)).foregroundColor(Theme.inkMuted)
                }
            }
            card(title: "Tasa mensual", value: String(format: "%.1f%%", tasaMensualPct)) {
                Slider(value: $tasaMensualPct, in: 1...15, step: 0.5).tint(Theme.deepGreen)
            }
            card(title: "Plazo", value: "\(plazoMeses) \(frecuencia == "mensual" ? "meses" : "quincenas")") {
                Stepper("", value: $plazoMeses, in: 1...24).labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .trailing)
                Picker("Frecuencia", selection: $frecuencia) {
                    Text("Mensual").tag("mensual")
                    Text("Quincenal").tag("quincenal")
                }
                .pickerStyle(.segmented)
                .padding(.top, 6)
            }
        }
    }

    var resultado: some View {
        let interesTotal = principal * (tasaMensualPct / 100) * Double(plazoMeses)
        let totalPagar = principal + interesTotal
        let numPagos = frecuencia == "mensual" ? plazoMeses : plazoMeses * 2
        let cuota = totalPagar / Double(numPagos)
        return VStack(alignment: .leading, spacing: 12) {
            Text("Tu simulación").font(PType.bodyBold(14)).foregroundColor(.white.opacity(0.85))
            Text(MoneyFormat.mxn(cuota)).font(PType.display(38)).foregroundColor(.white)
            Text("por \(frecuencia == "mensual" ? "mes" : "quincena") × \(numPagos)")
                .font(PType.body(13)).foregroundColor(.white.opacity(0.78))
            Divider().background(Color.white.opacity(0.15))
            HStack {
                miniStat("Total a pagar", MoneyFormat.mxn(totalPagar))
                miniStat("Interés total", MoneyFormat.mxn(interesTotal))
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Theme.heroPrimary))
    }

    private func card<Content: View>(title: String, value: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title).font(PType.caption(12)).foregroundColor(Theme.inkSoft)
                Spacer()
                Text(value).font(PType.bodyBold(15)).foregroundColor(Theme.ink)
            }
            content()
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(Theme.surfaceLight))
    }

    private func miniStat(_ l: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(l).font(PType.caption(10)).foregroundColor(.white.opacity(0.78))
            Text(v).font(PType.bodyBold(14)).foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
