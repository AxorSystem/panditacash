import Foundation

struct User: Codable, Identifiable, Equatable {
    let id: Int
    let telefono: String?
    let nombre: String
    let esAdmin: Bool

    enum CodingKeys: String, CodingKey {
        case id, telefono, nombre
        case esAdmin = "es_admin"
    }
}

enum AuthState: Equatable {
    case booting
    case signedOut
    case signedIn(User)
}

struct AuthResponse: Codable {
    let token: String
    let user: User
}

struct Stats: Codable {
    let totalVencidos: Double
    let totalHoy: Double
    let totalProximos7d: Double
    let totalPrestadoActivo: Double
    let clientesActivos: Int
    let pagosVencidos: Int

    enum CodingKeys: String, CodingKey {
        case totalVencidos = "vencidos"
        case totalHoy = "por_cobrar_hoy"
        case totalProximos7d = "proximos_7d"
        case totalPrestadoActivo = "prestado_activo"
        case clientesActivos = "clientes_activos_n"
        case pagosVencidos = "vencidos_n"
    }
}

struct PagoPendiente: Codable, Identifiable {
    let id: Int
    let prestamoId: Int
    let clienteId: Int?
    let clienteNombre: String
    let clienteTelefono: String?
    let numeroPago: Int
    let montoEsperado: Double
    let montoPagadoCapital: Double?
    let montoPagadoMora: Double?
    let fechaProgramada: String
    let estado: String?
    let diasVencido: Int?
    let moraCalculada: Double?
    let urgencia: String?
    let totalPendiente: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case prestamoId = "prestamo_id"
        case clienteId = "usuario_id"
        case clienteNombre = "cliente_nombre"
        case clienteTelefono = "cliente_tel"
        case numeroPago = "numero_pago"
        case montoEsperado = "monto_esperado"
        case montoPagadoCapital = "monto_pagado_capital"
        case montoPagadoMora = "monto_pagado_mora"
        case fechaProgramada = "fecha_programada"
        case estado
        case diasVencido = "dias_retraso"
        case moraCalculada = "mora_calculada"
        case urgencia
        case totalPendiente = "total_pendiente"
    }
}

struct SolicitudPendiente: Codable, Identifiable, Equatable {
    let id: Int
    let usuarioId: Int?
    let clienteNombre: String
    let clienteTelefono: String?
    let montoSolicitado: Double
    let plazoMeses: Int
    let motivo: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case usuarioId = "usuario_id"
        case clienteNombre = "nombre"
        case clienteTelefono = "telefono"
        case montoSolicitado = "monto_solicitado"
        case plazoMeses = "plazo_meses"
        case motivo
        case createdAt = "created_at"
    }
}

struct Dashboard: Codable {
    let stats: Stats
    let pagosPendientes: [PagoPendiente]
    let solicitudesPendientes: [SolicitudPendiente]?

    enum CodingKeys: String, CodingKey {
        case stats
        case pagosPendientes = "pagos_pendientes"
        case solicitudesPendientes = "solicitudes_pendientes"
    }

    init(stats: Stats, pagosPendientes: [PagoPendiente], solicitudesPendientes: [SolicitudPendiente]?) {
        self.stats = stats
        self.pagosPendientes = pagosPendientes
        self.solicitudesPendientes = solicitudesPendientes
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.stats = try c.decode(Stats.self, forKey: .stats)
        self.pagosPendientes = (try? c.decode([PagoPendiente].self, forKey: .pagosPendientes)) ?? []
        self.solicitudesPendientes = try? c.decodeIfPresent([SolicitudPendiente].self, forKey: .solicitudesPendientes)
    }
}

struct Cliente: Codable, Identifiable {
    let id: Int
    let telefono: String
    let nombre: String
    let activo: Bool?
    let notas: String?
    let saldoTotal: Double?
    let prestamosActivos: Int?

    enum CodingKeys: String, CodingKey {
        case id, telefono, nombre, activo, notas
        case saldoTotal = "saldo_total"
        case prestamosActivos = "prestamos_activos"
    }
}

struct MiResumen: Codable {
    let prestamo: PrestamoActivo?
    let proximoPago: PagoMiResumen?
    let pagos: [PagoMiResumen]?
    let solicitudPendiente: SolicitudPendiente?

    enum CodingKeys: String, CodingKey {
        case prestamo = "prestamo_activo"
        case proximoPago = "proximo_pago"
        case pagos
        case solicitudPendiente = "solicitud_pendiente"
    }
}

/// Pago simple para el resumen del cliente (sin datos de cliente porque ya sabemos quién es).
struct PagoMiResumen: Codable, Identifiable {
    let id: Int
    let numeroPago: Int
    let montoEsperado: Double
    let fechaProgramada: String
    let estado: String?
    let diasVencido: Int?
    let totalPendiente: Double?
    let montoPagadoCapital: Double?
    let montoPagadoMora: Double?

    enum CodingKeys: String, CodingKey {
        case id, estado
        case numeroPago = "numero_pago"
        case montoEsperado = "monto_esperado"
        case fechaProgramada = "fecha_programada"
        case diasVencido = "dias_retraso"
        case totalPendiente = "total_pendiente"
        case montoPagadoCapital = "monto_pagado_capital"
        case montoPagadoMora = "monto_pagado_mora"
    }
}

struct PrestamoActivo: Codable {
    let id: Int
    let principal: Double
    let tasaMensual: Double
    let plazoMeses: Int
    let fechaInicio: String
    let estado: String
    let saldoCapital: Double?
    let saldoTotal: Double?
    let frecuencia: String?

    enum CodingKeys: String, CodingKey {
        case id, principal, estado, frecuencia
        case tasaMensual = "tasa_mensual"
        case plazoMeses = "plazo_meses"
        case fechaInicio = "fecha_inicio"
        case saldoCapital = "saldo_capital"
        case saldoTotal = "saldo_total"
    }
}

enum PagoEstado: String {
    case pendiente, parcial, pagado, pagadoAnticipado = "pagado_anticipado", vencido, perdonado
}
