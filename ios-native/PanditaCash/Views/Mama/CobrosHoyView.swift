import SwiftUI

struct CobrosHoyView: View {
    @EnvironmentObject var toast: ToastCenter
    @StateObject var vm = DashboardVM()
    @State private var checkeados: Set<Int> = Set(UserDefaults.standard.array(forKey: "cobros.hoy.checked") as? [Int] ?? [])

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    resumen
                    listaHoy
                    listaVencidos
                    Spacer(minLength: 60)
                }
                .padding(.horizontal, 20).padding(.top, 12)
            }
            .refreshable { await vm.load() }
            .task { await vm.load() }
        }
        .navigationTitle("Cobros de hoy")
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(NotificationCenter.default.publisher(for: AppEvent.prestamosChanged)) { _ in
            Task { await vm.load() }
        }
    }

    private var pagos: [PagoPendiente] { vm.dashboard?.pagosPendientes ?? [] }
    private var hoy: [PagoPendiente] { pagos.filter { ($0.diasVencido ?? 0) == 0 } }
    private var vencidos: [PagoPendiente] { pagos.filter { ($0.diasVencido ?? 0) > 0 } }

    var resumen: some View {
        let cobrados = checkeados.intersection(Set(pagos.map(\.id)))
        let total = hoy.reduce(0) { $0 + $1.montoEsperado } + vencidos.reduce(0) { $0 + $1.montoEsperado }
        return VStack(alignment: .leading, spacing: 8) {
            Text("PROGRESO HOY").tracking(1.2).font(PType.caption(10)).foregroundColor(.white.opacity(0.7))
            Text("\(cobrados.count) / \(hoy.count + vencidos.count)")
                .font(PType.display(36)).foregroundColor(.white)
            HStack(spacing: 8) {
                miniStat("Meta total", MoneyFormat.mxn(total))
                miniStat("Vencidos", "\(vencidos.count)")
            }
            .padding(.top, 4)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 24).fill(Theme.heroPrimary))
    }

    private func miniStat(_ l: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(l).font(PType.caption(10)).foregroundColor(.white.opacity(0.7))
            Text(v).font(PType.bodyBold(13)).foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder var listaHoy: some View {
        if !hoy.isEmpty {
            seccion("Vencen hoy", pagos: hoy, colorEstado: Theme.warning)
        }
    }
    @ViewBuilder var listaVencidos: some View {
        if !vencidos.isEmpty {
            seccion("Vencidos", pagos: vencidos, colorEstado: Theme.danger)
        }
    }

    private func seccion(_ titulo: String, pagos: [PagoPendiente], colorEstado: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(titulo).font(PType.title(18)).foregroundColor(Theme.ink)
                Spacer()
                Text("\(pagos.count)").font(PType.caption(11)).foregroundColor(.white)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(colorEstado))
            }
            ForEach(pagos) { p in fila(p, color: colorEstado) }
        }
    }

    private func fila(_ p: PagoPendiente, color: Color) -> some View {
        let cobrado = checkeados.contains(p.id)
        return HStack(spacing: 12) {
            Button {
                Haptics.tap()
                if cobrado { checkeados.remove(p.id) } else { checkeados.insert(p.id) }
                UserDefaults.standard.set(Array(checkeados), forKey: "cobros.hoy.checked")
            } label: {
                Image(systemName: cobrado ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(cobrado ? Theme.success : Theme.inkMuted)
            }
            NavigationLink { PrestamoDetalleView(prestamoId: p.prestamoId) } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(p.clienteNombre)
                            .font(PType.bodyBold(14))
                            .foregroundColor(cobrado ? Theme.inkMuted : Theme.ink)
                            .strikethrough(cobrado)
                        Text(subtitulo(p))
                            .font(PType.caption(11)).foregroundColor(Theme.inkSoft)
                    }
                    Spacer()
                    Text(MoneyFormat.mxn(p.montoEsperado))
                        .font(PType.number(14))
                        .foregroundColor(cobrado ? Theme.inkMuted : Theme.ink)
                        .strikethrough(cobrado)
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18).fill(Theme.surfaceLight))
    }

    private func subtitulo(_ p: PagoPendiente) -> String {
        let d = p.diasVencido ?? 0
        if d > 0 { return "Vencido \(d) día\(d == 1 ? "" : "s")" }
        return "Vence hoy"
    }
}
