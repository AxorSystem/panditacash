import Foundation

struct KYCStatus: Codable {
    let kycCompleto: Bool
    let enRevision: Bool?
    let tieneIne: Bool
    let tieneSelfie: Bool
    let ineSubido: Bool?
    let selfieSubida: Bool?
    let avalesVerificados: Int
    let tarjetasActivas: Int
    let nivelGarantia: NivelGarantia
    let documentos: [DocumentoKYC]

    enum CodingKeys: String, CodingKey {
        case kycCompleto = "kyc_completo"
        case enRevision = "en_revision"
        case tieneIne = "tiene_ine"
        case tieneSelfie = "tiene_selfie"
        case ineSubido = "ine_subido"
        case selfieSubida = "selfie_subida"
        case avalesVerificados = "avales_verificados"
        case tarjetasActivas = "tarjetas_activas"
        case nivelGarantia = "nivel_garantia"
        case documentos
    }
}

struct NivelGarantia: Codable {
    let nivel: String       // "inicial","bronce","plata","oro"
    let montoMax: Double

    enum CodingKeys: String, CodingKey {
        case nivel
        case montoMax = "monto_max"
    }
}

struct DocumentoKYC: Codable, Identifiable {
    let tipo: String
    let validado: Bool
    let createdAt: String?

    var id: String { tipo }

    enum CodingKeys: String, CodingKey {
        case tipo, validado
        case createdAt = "created_at"
    }
}

enum KYCTipo: String, CaseIterable, Identifiable {
    case ineFrente = "ine_frente"
    case ineReverso = "ine_reverso"
    case selfie = "selfie"
    case comprobanteDom = "comprobante_dom"

    var id: String { rawValue }
    var titulo: String {
        switch self {
        case .ineFrente: "INE — Lado frontal"
        case .ineReverso: "INE — Lado trasero"
        case .selfie: "Selfie con tu INE"
        case .comprobanteDom: "Comprobante de domicilio"
        }
    }
    var descripcion: String {
        switch self {
        case .ineFrente: "Toma o sube una foto clara del frente de tu INE"
        case .ineReverso: "Toma o sube una foto clara del reverso"
        case .selfie: "Sostén tu INE junto a tu rostro y toma la selfie"
        case .comprobanteDom: "Recibo de luz, agua o teléfono (no mayor a 3 meses)"
        }
    }
}
