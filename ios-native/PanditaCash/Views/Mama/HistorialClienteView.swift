import SwiftUI
import UIKit

struct HistorialClienteView: View {
    let clienteId: Int
    let nombre: String
    @StateObject var vm: ClienteDetalleVM
    @State private var shareURL: URL?

    init(clienteId: Int, nombre: String) {
        self.clienteId = clienteId
        self.nombre = nombre
        _vm = StateObject(wrappedValue: ClienteDetalleVM(clienteId: clienteId))
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let r = vm.resp {
                        resumenCard(r)
                        timeline(r)
                    } else if vm.loading {
                        ProgressView().tint(Theme.deepGreen).padding(.top, 100)
                    }
                    Spacer(minLength: 80)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }
            .refreshable { await vm.load() }
            .task { await vm.load() }
        }
        .navigationTitle("Historial")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if let r = vm.resp { shareURL = exportarCSV(r) }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(Theme.deepGreen)
                }
                .disabled(vm.resp == nil)
            }
        }
        .sheet(item: $shareURL) { url in
            ShareSheet(items: [url])
        }
    }

    private func resumenCard(_ r: ClienteDetalleResp) -> some View {
        let liquidados = r.prestamos.filter { $0.estado == "liquidado" }.count
        let activos = r.prestamos.filter { $0.estado == "activo" }.count
        let totalCobrado = (r.movimientos ?? []).reduce(0.0) { $0 + $1.montoCapital + $1.montoMora }
        return VStack(alignment: .leading, spacing: 10) {
            Text(nombre.uppercased()).tracking(1.2).font(PType.caption(10)).foregroundColor(.white.opacity(0.78))
            HStack {
                stat("Préstamos", "\(r.prestamos.count)")
                stat("Liquidados", "\(liquidados)")
                stat("Activos", "\(activos)")
            }
            Divider().background(Color.white.opacity(0.15))
            Text("Total cobrado histórico").font(PType.caption(11)).foregroundColor(.white.opacity(0.78))
            Text(MoneyFormat.mxn(totalCobrado)).font(PType.display(30)).foregroundColor(.white)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Theme.heroPrimary))
    }

    private func stat(_ l: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(l).font(PType.caption(10)).foregroundColor(.white.opacity(0.78))
            Text(v).font(PType.bodyBold(15)).foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func timeline(_ r: ClienteDetalleResp) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Timeline").font(PType.title(20)).foregroundColor(Theme.ink).padding(.bottom, 14)
            ForEach(Array(items(r).enumerated()), id: \.offset) { idx, item in
                timelineRow(item, isLast: idx == items(r).count - 1)
            }
        }
    }

    private func timelineRow(_ item: TimelineItem, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                ZStack {
                    Circle().fill(item.color.opacity(0.15)).frame(width: 34, height: 34)
                    Image(systemName: item.icon).font(.system(size: 12, weight: .semibold)).foregroundColor(item.color)
                }
                if !isLast {
                    Rectangle().fill(Theme.hairline).frame(width: 2).frame(maxHeight: .infinity)
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(item.titulo).font(PType.bodyBold(14)).foregroundColor(Theme.ink)
                    Spacer()
                    Text(item.monto).font(PType.number(14)).foregroundColor(item.color)
                }
                Text(item.subtitulo).font(PType.caption(11)).foregroundColor(Theme.inkSoft)
                Text(item.fecha).font(PType.caption(10)).foregroundColor(Theme.inkMuted)
            }
            .padding(.bottom, 14)
        }
    }

    struct TimelineItem {
        let icon: String; let color: Color
        let titulo: String; let subtitulo: String; let monto: String; let fecha: String
        let date: Date
    }

    private func items(_ r: ClienteDetalleResp) -> [TimelineItem] {
        var arr: [TimelineItem] = []
        let df = ISO8601DateFormatter(); df.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let df2 = ISO8601DateFormatter()
        let simple = DateFormatter(); simple.dateFormat = "yyyy-MM-dd"

        for p in r.prestamos {
            let d = df.date(from: p.fechaInicio ?? "") ?? df2.date(from: p.fechaInicio ?? "") ?? simple.date(from: p.fechaInicio ?? "") ?? Date()
            arr.append(.init(
                icon: "banknote.fill", color: Theme.deepGreen,
                titulo: "Préstamo #\(p.id)",
                subtitulo: "\(String(format: "%.1f", p.tasaMensual * 100))% · \(p.plazoMeses) meses · \(p.estado)",
                monto: MoneyFormat.mxn(p.principal),
                fecha: fechaRel(d),
                date: d
            ))
        }
        for m in r.movimientos ?? [] {
            let d = df.date(from: m.fechaPago) ?? df2.date(from: m.fechaPago) ?? simple.date(from: m.fechaPago) ?? Date()
            let tot = m.montoCapital + m.montoMora
            arr.append(.init(
                icon: "checkmark.circle.fill", color: Theme.success,
                titulo: "Pago cobrado",
                subtitulo: "Capital \(MoneyFormat.mxn(m.montoCapital))\(m.montoMora > 0 ? " · Mora \(MoneyFormat.mxn(m.montoMora))" : "") · \(m.metodo ?? "-")",
                monto: "+\(MoneyFormat.mxn(tot))",
                fecha: fechaRel(d),
                date: d
            ))
        }
        return arr.sorted { $0.date > $1.date }
    }

    private func fechaRel(_ d: Date) -> String {
        let rel = RelativeDateTimeFormatter()
        rel.unitsStyle = .full; rel.locale = Locale(identifier: "es_MX")
        return rel.localizedString(for: d, relativeTo: Date())
    }

    private func exportarCSV(_ r: ClienteDetalleResp) -> URL? {
        var csv = "Fecha,Tipo,Concepto,Monto capital,Monto mora,Método,Notas\n"
        for m in r.movimientos ?? [] {
            let row = [
                m.fechaPago,
                "Pago",
                "Cliente \(nombre)",
                String(m.montoCapital),
                String(m.montoMora),
                m.metodo ?? "",
                (m.notas ?? "").replacingOccurrences(of: ",", with: ";"),
            ].joined(separator: ",")
            csv.append(row + "\n")
        }
        for p in r.prestamos {
            let row = [
                p.fechaInicio ?? "",
                "Préstamo",
                "Préstamo #\(p.id) (\(p.estado))",
                String(-p.principal),
                "0",
                "",
                "",
            ].joined(separator: ",")
            csv.append(row + "\n")
        }
        let name = "panditacash_\(nombre.replacingOccurrences(of: " ", with: "_")).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try csv.data(using: .utf8)?.write(to: url)
            return url
        } catch { return nil }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}
