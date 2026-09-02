import Foundation
import SwiftUI

@MainActor
final class AuthStore: ObservableObject {
    @Published private(set) var state: AuthState = .booting

    private let tokenKey = "auth.token"
    private let userKey = "auth.user"

    init() {
        APIClient.shared.tokenProvider = { Keychain.get("auth.token") }
        // NO auto-signout en 401: cada request maneja su propio error.
        // Solo signOut manual por el user.
        APIClient.shared.onUnauthorized = { }
    }

    var currentToken: String? { Keychain.get(tokenKey) }

    func restore() async {
        try? await Task.sleep(nanoseconds: 350_000_000)
        if ProcessInfo.processInfo.environment["FAKE_CLIENTE"] == "1" {
            state = .signedIn(User(id: 99, telefono: "5551234567", nombre: "David Cárdenas", esAdmin: false))
            return
        }
        if ProcessInfo.processInfo.environment["FAKE_ADMIN"] == "1" {
            if let tok = ProcessInfo.processInfo.environment["FAKE_TOKEN"], !tok.isEmpty {
                Keychain.set(tok, for: tokenKey)
            }
            state = .signedIn(User(id: 1, telefono: nil, nombre: "Mamá Panda", esAdmin: true))
            return
        }
        guard let _ = Keychain.get(tokenKey),
              let raw = UserDefaults.standard.data(forKey: userKey),
              let user = try? JSONDecoder().decode(User.self, from: raw)
        else {
            state = .signedOut; return
        }
        state = .signedIn(user)
    }

    // MARK: Admin

    struct MamaLoginBody: Encodable { let telefono: String; let pin: String }

    func mamaLogin(telefono: String, pin: String) async throws {
        let body = MamaLoginBody(telefono: telefono, pin: pin)
        let resp: AuthResponse = try await APIClient.shared.post("auth/mama/login", body: body)
        persist(token: resp.token, user: resp.user)
    }

    // MARK: Cliente OTP

    struct RequestOtpBody: Encodable { let telefono: String; let nombre: String? }
    struct VerifyOtpBody: Encodable { let telefono: String; let codigo: String }
    struct RequestOtpResp: Codable { let ok: Bool; let sent_via: String? }

    func requestOtp(telefono: String, nombre: String?) async throws {
        let body = RequestOtpBody(telefono: telefono, nombre: nombre)
        let _: RequestOtpResp = try await APIClient.shared.post("auth/cliente/request-otp", body: body)
    }

    func verifyOtp(telefono: String, codigo: String) async throws {
        let body = VerifyOtpBody(telefono: telefono, codigo: codigo)
        let resp: AuthResponse = try await APIClient.shared.post("auth/cliente/verify-otp", body: body)
        persist(token: resp.token, user: resp.user)
    }

    func signOut() {
        Keychain.delete(tokenKey)
        UserDefaults.standard.removeObject(forKey: userKey)
        state = .signedOut
    }

    private func persist(token: String, user: User) {
        Keychain.set(token, for: tokenKey)
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: userKey)
        }
        withAnimation(.smooth(duration: 0.5)) { state = .signedIn(user) }
    }
}
