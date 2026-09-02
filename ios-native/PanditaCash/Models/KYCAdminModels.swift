import Foundation

struct KYCPendienteCliente: Codable, Identifiable {
    let id: Int
    let nombre: String
    let telefono: String
    let kycCompleto: Bool?
    let docsSubidos: Int
    let docsValidados: Int
    let avalesN: Int
    let ultimaSubida: String?

    enum CodingKeys: String, CodingKey {
        case id, nombre, telefono
        case kycCompleto = "kyc_completo"
        case docsSubidos = "docs_subidos"
        case docsValidados = "docs_validados"
        case avalesN = "avales_n"
        case ultimaSubida = "ultima_subida"
    }
}

struct KYCClienteDetalle: Codable {
    let usuario: UsuarioBasico
    let documentos: [DocumentoDetalle]
    let avales: [AvalDetalle]
}

struct UsuarioBasico: Codable {
    let id: Int
    let nombre: String
    let telefono: String
    let kycCompleto: Bool?
    let kycCompletedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, nombre, telefono
        case kycCompleto = "kyc_completo"
        case kycCompletedAt = "kyc_completed_at"
    }
}

struct DocumentoDetalle: Codable, Identifiable {
    let id: Int
    let tipo: String
    let mimeType: String?
    let bytes: Int?
    let validado: Bool
    let validadoPor: Int?
    let validadoAt: String?
    let notas: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, tipo, validado, notas
        case mimeType = "mime_type"
        case bytes
        case validadoPor = "validado_por"
        case validadoAt = "validado_at"
        case createdAt = "created_at"
    }

    var tipoLabel: String {
        switch tipo {
        case "ine_frente": "INE — Frente"
        case "ine_reverso": "INE — Reverso"
        case "selfie": "Selfie con INE"
        case "comprobante_dom": "Comprobante domicilio"
        default: tipo
        }
    }
}

struct AvalDetalle: Codable, Identifiable {
    let id: Int
    let nombre: String
    let telefono: String
    let relacion: String?
    let verificadoWa: Bool
    let contactadoAt: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, nombre, telefono, relacion
        case verificadoWa = "verificado_wa"
        case contactadoAt = "contactado_at"
        case createdAt = "created_at"
    }
}
