import Foundation

struct ClienteList: Codable, Identifiable {
    let id: Int
    let nombre: String
    let telefono: String
    let notas: String?
    let nPrestamos: Int?
    let activos: Int?
    let deudaOriginal: Double?
    let totalPagadoCapital: Double?
    let saldoReal: Double?
    let vencidos: Int?
    let atrasosHistoricos: Int?
    let tags: [String]
    let favorito: Bool

    enum CodingKeys: String, CodingKey {
        case id, nombre, telefono, notas, activos, vencidos, tags, favorito
        case nPrestamos = "n_prestamos"
        case deudaOriginal = "deuda_original"
        case totalPagadoCapital = "total_pagado_capital"
        case saldoReal = "saldo_real"
        case atrasosHistoricos = "atrasos_historicos"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(Int.self, forKey: .id)
        // Nombre y teléfono defensivos por si el backend manda null/vacío.
        let rawNombre = (try? c.decode(String.self, forKey: .nombre)) ?? ""
        let rawTel = (try? c.decode(String.self, forKey: .telefono)) ?? ""
        self.nombre = rawNombre.trimmingCharacters(in: .whitespaces).isEmpty ? "Sin nombre" : rawNombre
        self.telefono = rawTel.isEmpty ? "—" : rawTel
        self.notas = try? c.decodeIfPresent(String.self, forKey: .notas)
        self.nPrestamos = try? c.decodeIfPresent(Int.self, forKey: .nPrestamos)
        self.activos = try? c.decodeIfPresent(Int.self, forKey: .activos)
        self.deudaOriginal = try? c.decodeIfPresent(Double.self, forKey: .deudaOriginal)
        self.totalPagadoCapital = try? c.decodeIfPresent(Double.self, forKey: .totalPagadoCapital)
        self.saldoReal = try? c.decodeIfPresent(Double.self, forKey: .saldoReal)
        self.vencidos = try? c.decodeIfPresent(Int.self, forKey: .vencidos)
        self.atrasosHistoricos = try? c.decodeIfPresent(Int.self, forKey: .atrasosHistoricos)
        let rawTags = (try? c.decodeIfPresent(String.self, forKey: .tags)) ?? ""
        self.tags = rawTags.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        // Backend puede enviar Bool o Int (BIT)
        if let b = try? c.decodeIfPresent(Bool.self, forKey: .favorito) { self.favorito = b }
        else if let i = try? c.decodeIfPresent(Int.self, forKey: .favorito) { self.favorito = i != 0 }
        else { self.favorito = false }
    }

    init(id: Int, nombre: String, telefono: String, notas: String?, nPrestamos: Int?, activos: Int?, deudaOriginal: Double?, totalPagadoCapital: Double?, saldoReal: Double?, vencidos: Int?, atrasosHistoricos: Int?, tags: [String] = [], favorito: Bool = false) {
        self.id = id
        self.nombre = nombre
        self.telefono = telefono
        self.notas = notas
        self.nPrestamos = nPrestamos
        self.activos = activos
        self.deudaOriginal = deudaOriginal
        self.totalPagadoCapital = totalPagadoCapital
        self.saldoReal = saldoReal
        self.vencidos = vencidos
        self.atrasosHistoricos = atrasosHistoricos
        self.tags = tags
        self.favorito = favorito
    }
}

struct Score: Codable {
    let nivel: String
    let puntos: Int?
    let etiqueta: String?
    let bloquear: Bool?
    let motivo: String?
    let emoji: String?
    let puntualidadPct: Double?
    let prestamosLiquidados: Int?
    let atrasosTotales: Int?
    let prestamosActivos: Int?
    let activosMaximos: Int?
    let montoMaximoSugerido: Double?

    enum CodingKeys: String, CodingKey {
        case nivel, puntos, etiqueta, bloquear, motivo, emoji
        case puntualidadPct = "puntualidad_pct"
        case prestamosLiquidados = "prestamos_liquidados"
        case atrasosTotales = "atrasos_totales"
        case prestamosActivos = "prestamos_activos"
        case activosMaximos = "activos_maximos"
        case montoMaximoSugerido = "monto_maximo_sugerido"
    }
}

struct Movimiento: Codable, Identifiable {
    let id: Int
    let prestamoId: Int?
    let clienteNombre: String?
    let clienteTelefono: String?
    let montoCapital: Double
    let montoMora: Double
    let moraPerdonada: Double?
    let metodo: String?
    let notas: String?
    let fechaPago: String
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case prestamoId = "prestamo_id"
        case clienteNombre = "cliente_nombre"
        case clienteTelefono = "cliente_tel"
        case montoCapital = "monto_capital"
        case montoMora = "monto_mora"
        case moraPerdonada = "mora_perdonada"
        case metodo, notas
        case fechaPago = "fecha_pago"
        case createdAt = "created_at"
    }
}

struct MovimientosResp: Codable {
    let stats: MovimientosStats
    let movimientos: [Movimiento]
}

struct MovimientosStats: Codable {
    let totalCapital: Double
    let totalMora: Double
    let totalPerdonado: Double?
    let nMovimientos: Int

    var totalCobrado: Double { totalCapital + totalMora }

    enum CodingKeys: String, CodingKey {
        case totalCapital = "total_capital"
        case totalMora = "total_mora"
        case totalPerdonado = "total_perdonado"
        case nMovimientos = "n_movimientos"
    }
}

struct SimulacionResp: Codable {
    let interesMensual: Double?
    let gananciaTotal: Double?
    let montoEntregado: Double?
    let totalAPagar: Double?
    let frecuencia: String?
    let pagos: [SimulacionPago]?

    // Alias para compat con views que ya lo usan
    var interesTotal: Double? { gananciaTotal }
    var cuotaMensual: Double? {
        guard let pagos, !pagos.isEmpty else { return nil }
        // asumimos cuota constante en el 2do pago intermedio
        return pagos.dropFirst().first?.monto
    }

    enum CodingKeys: String, CodingKey {
        case interesMensual = "interes_mensual"
        case gananciaTotal = "ganancia_total"
        case montoEntregado = "monto_entregado"
        case totalAPagar = "total_a_pagar"
        case frecuencia
        case pagos
    }
}

struct SimulacionPago: Codable, Identifiable {
    var id: Int { numero }
    let numero: Int
    let monto: Double
    let fecha: String

    enum CodingKeys: String, CodingKey {
        case numero = "numero_pago"
        case monto = "monto_esperado"
        case fecha = "fecha_programada"
    }
}

struct LookupResp: Codable {
    let encontrado: Bool
    let cliente: ClienteList?
    let score: Score?
}
