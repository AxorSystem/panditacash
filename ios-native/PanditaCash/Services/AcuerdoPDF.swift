import Foundation
import UIKit

enum AcuerdoPDF {
    /// Genera un PDF simple del acuerdo de préstamo y devuelve el URL local.
    static func generar(prestamo: PrestamoDetalle) -> URL? {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // Letter
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("acuerdo_\(prestamo.id).pdf")

        do {
            try renderer.writePDF(to: url) { ctx in
                ctx.beginPage()
                dibujar(prestamo, en: pageRect)
            }
            return url
        } catch {
            return nil
        }
    }

    private static func dibujar(_ p: PrestamoDetalle, en rect: CGRect) {
        let margin: CGFloat = 48
        var y: CGFloat = margin

        // Encabezado
        y = drawText("🐼 PanditaCash", x: margin, y: y, size: 22, bold: true)
        y = drawText("Acuerdo de préstamo #\(p.id)", x: margin, y: y + 4, size: 14, color: .darkGray)
        y = drawText("Fecha: \(hoyLegible())", x: margin, y: y + 2, size: 11, color: .gray)
        y += 18

        // Partes
        y = drawSection("Partes", y: y)
        y = drawKV("Prestamista", "Mamá Panda", y: y)
        y = drawKV("Prestatario", p.clienteNombre, y: y)
        y = drawKV("Teléfono", p.clienteTel, y: y)
        y += 12

        // Términos
        y = drawSection("Términos económicos", y: y)
        y = drawKV("Monto principal", mxn(p.principal), y: y)
        y = drawKV("Tasa mensual", String(format: "%.2f%%", p.tasaMensual * 100), y: y)
        y = drawKV("Plazo", "\(p.plazoMeses) \((p.frecuencia ?? "mensual") == "quincenal" ? "quincenas" : "meses")", y: y)
        y = drawKV("Frecuencia", (p.frecuencia ?? "mensual").capitalized, y: y)
        y = drawKV("Interés mensual", mxn(p.interesMensual ?? 0), y: y)
        y = drawKV("Mora diaria", String(format: "%.2f%%", (p.moraDiaria) * 100), y: y)
        y = drawKV("Monto entregado", mxn(p.montoEntregado ?? p.principal), y: y)
        y += 12

        // Calendario de pagos
        y = drawSection("Calendario de pagos", y: y)
        y = drawTableHeader(y: y)
        for pago in p.pagos.prefix(24) {
            y = drawTableRow(
                num: "\(pago.numeroPago)",
                fecha: pago.fechaProgramada,
                monto: mxn(pago.montoEsperado),
                estado: pago.estado.capitalized,
                y: y
            )
            if y > rect.maxY - margin - 60 { break }
        }
        y += 20

        // Cláusulas
        y = drawSection("Cláusulas", y: y)
        y = drawText("• El prestatario se compromete a cubrir los pagos en las fechas indicadas.", x: margin, y: y, size: 10, wrap: rect.width - margin*2)
        y = drawText("• Los pagos atrasados generarán la mora diaria pactada sobre el saldo pendiente.", x: margin, y: y + 4, size: 10, wrap: rect.width - margin*2)
        y = drawText("• El prestamista podrá anular la aprobación si detecta información falsa.", x: margin, y: y + 4, size: 10, wrap: rect.width - margin*2)
        y += 40

        // Firmas
        drawFirmas(y: y, ancho: rect.width - margin*2, margin: margin)
    }

    // MARK: helpers

    @discardableResult
    private static func drawText(_ s: String, x: CGFloat, y: CGFloat, size: CGFloat, bold: Bool = false, color: UIColor = .black, wrap: CGFloat? = nil) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: bold ? UIFont.boldSystemFont(ofSize: size) : UIFont.systemFont(ofSize: size),
            .foregroundColor: color
        ]
        if let w = wrap {
            let rect = CGRect(x: x, y: y, width: w, height: 200)
            (s as NSString).draw(with: rect, options: [.usesLineFragmentOrigin], attributes: attrs, context: nil)
            let bounding = (s as NSString).boundingRect(with: CGSize(width: w, height: 200), options: [.usesLineFragmentOrigin], attributes: attrs, context: nil)
            return y + bounding.height + 2
        } else {
            (s as NSString).draw(at: CGPoint(x: x, y: y), withAttributes: attrs)
            return y + size + 4
        }
    }

    private static func drawSection(_ t: String, y: CGFloat) -> CGFloat {
        let m: CGFloat = 48
        UIColor(white: 0.9, alpha: 1).setFill()
        UIRectFill(CGRect(x: m, y: y - 2, width: 612 - m*2, height: 20))
        return drawText(t.uppercased(), x: m + 8, y: y + 2, size: 11, bold: true, color: .darkGray) + 4
    }

    private static func drawKV(_ k: String, _ v: String, y: CGFloat) -> CGFloat {
        drawText(k, x: 60, y: y, size: 10, color: .gray)
        return drawText(v, x: 220, y: y, size: 10)
    }

    private static func drawTableHeader(y: CGFloat) -> CGFloat {
        drawText("#", x: 60, y: y, size: 9, bold: true, color: .darkGray)
        drawText("FECHA", x: 100, y: y, size: 9, bold: true, color: .darkGray)
        drawText("MONTO", x: 260, y: y, size: 9, bold: true, color: .darkGray)
        drawText("ESTADO", x: 400, y: y, size: 9, bold: true, color: .darkGray)
        return y + 14
    }

    private static func drawTableRow(num: String, fecha: String, monto: String, estado: String, y: CGFloat) -> CGFloat {
        drawText(num, x: 60, y: y, size: 10)
        drawText(String(fecha.prefix(10)), x: 100, y: y, size: 10)
        drawText(monto, x: 260, y: y, size: 10)
        drawText(estado, x: 400, y: y, size: 10, color: .darkGray)
        return y + 14
    }

    private static func drawFirmas(y: CGFloat, ancho: CGFloat, margin: CGFloat) {
        let firma1X = margin
        let firma2X = margin + ancho/2 + 20

        UIColor.black.setStroke()
        let path = UIBezierPath()
        path.move(to: CGPoint(x: firma1X, y: y))
        path.addLine(to: CGPoint(x: firma1X + 180, y: y))
        path.move(to: CGPoint(x: firma2X, y: y))
        path.addLine(to: CGPoint(x: firma2X + 180, y: y))
        path.stroke()

        _ = drawText("Prestamista", x: firma1X, y: y + 4, size: 10, color: .darkGray)
        _ = drawText("Prestatario", x: firma2X, y: y + 4, size: 10, color: .darkGray)
    }

    private static func hoyLegible() -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "es_MX")
        f.dateStyle = .long
        return f.string(from: Date())
    }

    private static func mxn(_ v: Double) -> String {
        let f = NumberFormatter(); f.numberStyle = .currency; f.currencyCode = "MXN"; f.maximumFractionDigits = 2
        f.locale = Locale(identifier: "es_MX")
        return f.string(from: NSNumber(value: v)) ?? "$0"
    }
}
