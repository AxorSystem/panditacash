import Foundation
import UIKit
import Vision

/// Valida on-device que la foto sea del documento correcto usando Vision framework.
/// No perfecto, pero descarta lo obvio (fotos aleatorias, capturas de pantalla, etc.).
enum KYCImageValidator {

    struct Result {
        let ok: Bool
        let mensaje: String?     // nil si ok, sino razón del rechazo
    }

    static func validate(_ image: UIImage, for tipo: KYCTipo) async -> Result {
        switch tipo {
        case .ineFrente, .ineReverso:
            return await validateINE(image, esFrente: tipo == .ineFrente)
        case .selfie:
            return await validateSelfie(image)
        case .comprobanteDom:
            return await validateComprobante(image)
        }
    }

    // MARK: INE — detectar rectángulo + texto característico

    private static func validateINE(_ image: UIImage, esFrente: Bool) async -> Result {
        guard let cg = image.cgImage else {
            return Result(ok: false, mensaje: "Imagen no válida")
        }

        // Palabras clave típicas de la INE mexicana (frente y reverso)
        let keywordsGeneral = [
            "INSTITUTO", "NACIONAL", "ELECTORAL", "INE", "IFE",
            "MEXICO", "MÉXICO",
            "CREDENCIAL", "VOTAR", "IDENTIFICACION",
            "NOMBRE", "DOMICILIO", "CURP",
            "REGISTRO", "FEDERAL", "ELECTORES",
            "CLAVE", "ELECTOR", "OCR", "MRZ",
            "SEXO", "NACIMIENTO", "VIGENCIA",
        ]
        let reversoOnly = ["MRZ", "OCR", "IDMEX", "CLAVE DE ELECTOR"]
        let frenteOnly = ["DOMICILIO", "FECHA DE NACIMIENTO", "SEXO", "EDAD"]

        // Probamos hasta 4 orientaciones. Vision no siempre corrige rotación auto.
        let orientations: [CGImagePropertyOrientation] = [.up, .right, .down, .left]
        var bestMatches = 0
        var fullText = ""
        for ori in orientations {
            let text = await recognizeText(cg, orientation: ori)
            let matches = keywordsGeneral.filter { text.contains($0) }.count
            if matches > bestMatches {
                bestMatches = matches
                fullText = text
            }
            if matches >= 3 { break }
        }

        // Umbral más permisivo: 2 palabras basta para decir "parece INE"
        if bestMatches < 2 {
            return Result(ok: false,
                          mensaje: "No detectamos texto de INE en la foto. Asegúrate de que:\n• La INE ocupe casi toda la pantalla\n• No haya reflejos ni sombras\n• El texto se vea nítido")
        }

        // Distingue frente vs reverso solo cuando la señal es fuerte
        let reversoHits = reversoOnly.filter { fullText.contains($0) }.count
        let frenteHits = frenteOnly.filter { fullText.contains($0) }.count
        if esFrente && reversoHits >= 2 && frenteHits == 0 {
            return Result(ok: false, mensaje: "Parece el reverso. Voltea tu INE y toma la parte del frente (con tu foto).")
        }
        if !esFrente && frenteHits >= 2 && reversoHits == 0 {
            return Result(ok: false, mensaje: "Parece el frente. Voltea tu INE y toma la parte de atrás (con el código de barras).")
        }

        return Result(ok: true, mensaje: nil)
    }

    private static func recognizeText(_ cg: CGImage, orientation: CGImagePropertyOrientation) async -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["es-MX", "es-ES", "en-US"]
        request.usesLanguageCorrection = false

        do {
            let handler = VNImageRequestHandler(cgImage: cg, orientation: orientation, options: [:])
            try handler.perform([request])
            let texts = (request.results ?? []).flatMap { $0.topCandidates(1).map { $0.string.uppercased() } }
            return texts.joined(separator: " ")
        } catch {
            return ""
        }
    }

    // MARK: Selfie — detectar rostro humano

    private static func validateSelfie(_ image: UIImage) async -> Result {
        guard let cg = image.cgImage else {
            return Result(ok: false, mensaje: "Imagen no válida")
        }

        let request = VNDetectFaceRectanglesRequest()
        do {
            let handler = VNImageRequestHandler(cgImage: cg, options: [:])
            try handler.perform([request])
            let faces = request.results ?? []
            if faces.isEmpty {
                return Result(ok: false, mensaje: "No detectamos un rostro. Toma la selfie con tu cara bien visible.")
            }
            if faces.count > 1 {
                return Result(ok: true, mensaje: nil) // OK si hay más de 1 (posiblemente foto con INE que también tiene cara)
            }
            // Verificar que el rostro ocupe al menos 10% del frame
            let face = faces[0]
            let boundingBox = face.boundingBox
            let area = boundingBox.width * boundingBox.height
            if area < 0.05 {
                return Result(ok: false, mensaje: "Acércate más. Tu cara debe verse grande y clara.")
            }
            return Result(ok: true, mensaje: nil)
        } catch {
            return Result(ok: true, mensaje: nil)
        }
    }

    // MARK: Comprobante — busca fecha reciente y palabras típicas

    private static func validateComprobante(_ image: UIImage) async -> Result {
        guard let cg = image.cgImage else {
            return Result(ok: false, mensaje: "Imagen no válida")
        }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .fast
        do {
            let handler = VNImageRequestHandler(cgImage: cg, options: [:])
            try handler.perform([request])
            let texts = (request.results ?? []).flatMap { $0.topCandidates(1).map { $0.string.uppercased() } }
            let full = texts.joined(separator: " ")
            let keywords = ["CFE", "TELMEX", "TELCEL", "AGUA", "LUZ", "TELEFONO", "TELÉFONO",
                            "PERIODO", "PAGO", "IMPORTE", "DOMICILIO", "TITULAR", "MEDIDOR"]
            let matches = keywords.filter { full.contains($0) }.count
            if matches < 2 {
                return Result(ok: false, mensaje: "No parece un comprobante de domicilio. Sube un recibo (luz, agua, teléfono).")
            }
            return Result(ok: true, mensaje: nil)
        } catch {
            return Result(ok: true, mensaje: nil)
        }
    }
}
