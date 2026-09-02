import Foundation

struct PrestamoDetalle: Codable {
    let id: Int
    let usuarioId: Int
    let clienteNombre: String
    let clienteTel: String
    let principal: Double
    let tasaMensual: Double
    let plazoMeses: Int
    let interesMensual: Double?
    let montoEntregado: Double?
    let moraDiaria: Double
    let fechaInicio: String
    let fechaLiquidacion: String?
    let estado: String
    let notas: String?
    let frecuencia: String?
    let pagos: [PagoDetalle]
    let movimientos: [Movimiento]?

    // Campos top-level del backend (no wrapper)
    let totalPagadoCapital: Double?
    let totalPagadoMora: Double?
    let totalPendiente: Double?

    // Alias helper para vistas que usan `totales.capitalPagado`
    var totales: PrestamoTotales? {
        PrestamoTotales(
            capitalPagado: totalPagadoCapital,
            moraPagada: totalPagadoMora,
            saldoCapital: totalPagadoCapital.map { principal - $0 },
            saldoTotalPendiente: totalPendiente
        )
    }

    enum CodingKeys: String, CodingKey {
        case id
        case usuarioId = "usuario_id"
        case clienteNombre = "cliente_nombre"
        case clienteTel = "cliente_tel"
        case principal
        case tasaMensual = "tasa_mensual"
        case plazoMeses = "plazo_meses"
        case interesMensual = "interes_mensual"
        case montoEntregado = "monto_entregado"
        case moraDiaria = "mora_diaria"
        case fechaInicio = "fecha_inicio"
        case fechaLiquidacion = "fecha_liquidacion"
        case estado, notas, frecuencia, pagos, movimientos
        case totalPagadoCapital = "total_pagado_capital"
        case totalPagadoMora = "total_pagado_mora"
        case totalPendiente = "total_pendiente"
    }
}

struct PagoDetalle: Codable, Identifiable {
    let id: Int
    let numeroPago: Int
    let montoEsperado: Double
    let fechaProgramada: String
    let montoPagadoCapital: Double?
    let montoPagadoMora: Double?
    let moraPerdonadaTotal: Double?
    let fechaPagada: String?
    let estado: String
    let notas: String?

    enum CodingKeys: String, CodingKey {
        case id
        case numeroPago = "numero_pago"
        case montoEsperado = "monto_esperado"
        case fechaProgramada = "fecha_programada"
        case montoPagadoCapital = "monto_pagado_capital"
        case montoPagadoMora = "monto_pagado_mora"
        case moraPerdonadaTotal = "mora_perdonada_total"
        case fechaPagada = "fecha_pagada"
        case estado, notas
    }
}

struct PrestamoTotales: Codable {
    let capitalPagado: Double?
    let moraPagada: Double?
    let saldoCapital: Double?
    let saldoTotalPendiente: Double?

    enum CodingKeys: String, CodingKey {
        case capitalPagado = "capital_pagado"
        case moraPagada = "mora_pagada"
        case saldoCapital = "saldo_capital"
        case saldoTotalPendiente = "saldo_total_pendiente"
    }
}
