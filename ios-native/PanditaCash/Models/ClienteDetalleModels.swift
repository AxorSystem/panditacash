import Foundation

struct ClienteDetalleResp: Decodable {
    let cliente: ClienteBasico
    let prestamos: [PrestamoResumen]
    let movimientos: [Movimiento]?
    let score: Score?
}

struct ClienteBasico: Decodable, Identifiable {
    let id: Int
    let nombre: String
    let telefono: String
    let notas: String?
    let createdAt: String?
    let lastLogin: String?
    let tags: [String]
    let favorito: Bool

    enum CodingKeys: String, CodingKey {
        case id, nombre, telefono, notas, favorito
        case createdAt = "created_at"
        case lastLogin = "last_login"
        case tagsRaw = "tags"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(Int.self, forKey: .id)
        self.nombre = (try? c.decode(String.self, forKey: .nombre)) ?? "Sin nombre"
        self.telefono = (try? c.decode(String.self, forKey: .telefono)) ?? ""
        self.notas = try? c.decodeIfPresent(String.self, forKey: .notas)
        self.createdAt = try? c.decodeIfPresent(String.self, forKey: .createdAt)
        self.lastLogin = try? c.decodeIfPresent(String.self, forKey: .lastLogin)
        let raw = (try? c.decodeIfPresent(String.self, forKey: .tagsRaw)) ?? ""
        self.tags = raw.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if let b = try? c.decodeIfPresent(Bool.self, forKey: .favorito) { self.favorito = b }
        else if let i = try? c.decodeIfPresent(Int.self, forKey: .favorito) { self.favorito = i != 0 }
        else { self.favorito = false }
    }

    init(id: Int, nombre: String, telefono: String, notas: String? = nil, createdAt: String? = nil, lastLogin: String? = nil, tags: [String] = [], favorito: Bool = false) {
        self.id = id; self.nombre = nombre; self.telefono = telefono
        self.notas = notas; self.createdAt = createdAt; self.lastLogin = lastLogin
        self.tags = tags; self.favorito = favorito
    }
}

struct PrestamoResumen: Codable, Identifiable {
    let id: Int
    let principal: Double
    let tasaMensual: Double
    let plazoMeses: Int
    let montoEntregado: Double?
    let interesMensual: Double?
    let moraDiaria: Double?
    let fechaInicio: String
    let fechaLiquidacion: String?
    let estado: String
    let notas: String?
    let aprobadoAt: String?
    let pagadoCapital: Double?
    let pagadoMora: Double?
    let saldoPendiente: Double?

    enum CodingKeys: String, CodingKey {
        case id, principal, estado, notas
        case tasaMensual = "tasa_mensual"
        case plazoMeses = "plazo_meses"
        case montoEntregado = "monto_entregado"
        case interesMensual = "interes_mensual"
        case moraDiaria = "mora_diaria"
        case fechaInicio = "fecha_inicio"
        case fechaLiquidacion = "fecha_liquidacion"
        case aprobadoAt = "aprobado_at"
        case pagadoCapital = "pagado_capital"
        case pagadoMora = "pagado_mora"
        case saldoPendiente = "saldo_pendiente"
    }
}
