import SwiftUI

struct ComparativaResp: Codable {
    let mesActual: MesTot
    let mesAnterior: MesTot
    let porMetodo: [MetodoTot]

    enum CodingKeys: String, CodingKey {
        case mesActual = "mes_actual"
        case mesAnterior = "mes_anterior"
        case porMetodo = "por_metodo"
    }
}

struct MesTot: Codable {
    let capital: Double; let mora: Double; let n: Int
    var total: Double { capital + mora }
}

struct MetodoTot: Codable, Identifiable {
    let metodo: String?
    let total: Double
    let n: Int
    var id: String { metodo ?? "sin" }
}

@MainActor
final class ComparativaVM: ObservableObject {
    @Published var data: ComparativaResp?
    func load() async {
        data = try? await APIClient.shared.get("analytics/comparativa")
    }
}

struct ComparativaCard: View {
    @StateObject var vm = ComparativaVM()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Este mes vs mes pasado").font(PType.heading(15)).foregroundColor(Theme.ink)
            if let d = vm.data {
                let dif = d.mesActual.total - d.mesAnterior.total
                let pct: Double = d.mesAnterior.total > 0 ? (dif / d.mesAnterior.total) * 100 : 0
                let up = dif >= 0
                HStack(alignment: .lastTextBaseline, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Este mes").font(PType.caption(10)).foregroundColor(Theme.inkSoft)
                        Text(MoneyFormat.mxn(d.mesActual.total)).font(PType.number(20)).foregroundColor(Theme.ink)
                        Text("\(d.mesActual.n) cobros").font(PType.caption(11)).foregroundColor(Theme.inkMuted)
                    }
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: up ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 12, weight: .bold))
                        Text(String(format: "%+.0f%%", pct)).font(PType.bodyBold(13))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Capsule().fill(up ? Theme.success : Theme.danger))
                }
                Divider().background(Theme.hairline)
                HStack {
                    Text("Mes pasado").font(PType.caption(11)).foregroundColor(Theme.inkSoft)
                    Spacer()
                    Text(MoneyFormat.mxn(d.mesAnterior.total))
                        .font(PType.number(13)).foregroundColor(Theme.inkSoft)
                    Text("· \(d.mesAnterior.n) cobros").font(PType.caption(11)).foregroundColor(Theme.inkMuted)
                }
            } else {
                HStack {
                    ProgressView().tint(Theme.deepGreen)
                    Text("Calculando…").font(PType.caption(12)).foregroundColor(Theme.inkMuted)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 22).fill(Theme.surfaceLight))
        .task { await vm.load() }
    }
}

struct MetodosPagoCard: View {
    @StateObject var vm = ComparativaVM()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Cobros por método (90d)").font(PType.heading(15)).foregroundColor(Theme.ink)
            if let met = vm.data?.porMetodo, !met.isEmpty {
                let totalGlobal = met.map(\.total).reduce(0, +)
                ForEach(met) { m in
                    let pct = totalGlobal > 0 ? m.total / totalGlobal : 0
                    row(m: m, pct: pct)
                }
            } else {
                Text("Sin datos aún").font(PType.body(13)).foregroundColor(Theme.inkMuted)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 22).fill(Theme.surfaceLight))
        .task { await vm.load() }
    }

    private func row(m: MetodoTot, pct: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: icono(m.metodo)).font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.deepGreen)
                    Text(nombre(m.metodo)).font(PType.bodyBold(13)).foregroundColor(Theme.ink)
                }
                Spacer()
                Text(MoneyFormat.mxn(m.total)).font(PType.number(13)).foregroundColor(Theme.ink)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.hairline).frame(height: 6)
                    Capsule().fill(Theme.deepGreen).frame(width: geo.size.width * pct, height: 6)
                }
            }
            .frame(height: 6)
            Text("\(m.n) cobros · \(Int(pct * 100))%")
                .font(PType.caption(10)).foregroundColor(Theme.inkMuted)
        }
    }

    private func nombre(_ m: String?) -> String {
        switch m {
        case "efectivo": "Efectivo"
        case "transferencia": "Transferencia"
        case "deposito": "Depósito"
        case "retencion": "Retención"
        default: "Otro"
        }
    }
    private func icono(_ m: String?) -> String {
        switch m {
        case "efectivo": "banknote.fill"
        case "transferencia": "arrow.left.arrow.right"
        case "deposito": "building.columns.fill"
        default: "circle.grid.cross"
        }
    }
}
