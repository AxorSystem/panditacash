import Foundation
import UIKit

@MainActor
final class KYCService: ObservableObject {
    static let shared = KYCService()

    @Published private(set) var status: KYCStatus?
    @Published var loading = false

    func fetchStatus() async {
        loading = true; defer { loading = false }
        if let real: KYCStatus = try? await APIClient.shared.get("kyc/status") {
            status = real
            return
        }
        if ProcessInfo.processInfo.environment["FAKE_CLIENTE"] == "1" {
            status = KYCStatus(
                kycCompleto: ProcessInfo.processInfo.environment["FAKE_KYC_OK"] == "1",
                enRevision: false,
                tieneIne: true, tieneSelfie: true,
                ineSubido: true, selfieSubida: true,
                avalesVerificados: 1, tarjetasActivas: 0,
                nivelGarantia: NivelGarantia(nivel: "plata", montoMax: 5000),
                documentos: []
            )
        }
    }

    struct UploadResp: Codable { let ok: Bool; let tipo: String? }

    func uploadDocumento(_ tipo: KYCTipo, image: UIImage) async throws -> UploadResp {
        guard let data = image.jpegData(compressionQuality: 0.82) else {
            throw APIError.http(-1, "No se pudo procesar la imagen")
        }
        let boundary = "PanditaCashBoundary-\(UUID().uuidString)"
        var body = Data()

        func appendField(_ name: String, value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append(value.data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
        }
        func appendFile(_ name: String, filename: String, mime: String, data: Data) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: \(mime)\r\n\r\n".data(using: .utf8)!)
            body.append(data)
            body.append("\r\n".data(using: .utf8)!)
        }

        appendField("tipo", value: tipo.rawValue)
        appendFile("imagen", filename: "\(tipo.rawValue).jpg", mime: "image/jpeg", data: data)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        var req = URLRequest(url: APIClient.shared.baseURL.appendingPathComponent("kyc/upload"))
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if let token = Keychain.get("auth.token") {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.timeoutInterval = 60
        req.httpBody = body

        let (respData, resp) = try await URLSession.shared.upload(for: req, from: body)
        guard let http = resp as? HTTPURLResponse else { throw APIError.http(-1, "Sin respuesta") }
        if !(200..<300).contains(http.statusCode) {
            struct Err: Decodable { let error: String? }
            let msg = (try? JSONDecoder().decode(Err.self, from: respData))?.error
                ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            throw APIError.http(http.statusCode, msg)
        }
        let parsed = try JSONDecoder().decode(UploadResp.self, from: respData)
        await fetchStatus()
        return parsed
    }

    struct AvalBody: Encodable { let nombre: String; let telefono: String; let relacion: String? }

    func agregarAval(nombre: String, telefono: String, relacion: String?) async throws {
        let body = AvalBody(nombre: nombre, telefono: telefono, relacion: relacion)
        struct R: Decodable { let ok: Bool; let aval_id: Int? }
        let _: R = try await APIClient.shared.post("kyc/aval", body: body)
        await fetchStatus()
    }

    func borrarAval(id: Int) async throws {
        struct R: Decodable { let ok: Bool }
        let _: R = try await APIClient.shared.delete("kyc/aval/\(id)")
        await fetchStatus()
    }
}
