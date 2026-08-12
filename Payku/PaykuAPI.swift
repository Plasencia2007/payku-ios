import Foundation

protocol PaykuAPI: Sendable {
    func linkOwner(code: String) async throws -> DeviceSession
    func linkCashier(code: String) async throws -> DeviceSession
    func logout(role: PaykuRole, token: String) async throws
    func me(role: PaykuRole, token: String) async throws -> DeviceProfile
    func ownerPayments(since: Date, token: String) async throws -> [PaymentDTO]
    func cashierFeed(cursor: String?, token: String) async throws -> CashierPageDTO
    func setPaymentState(id: String, state: CashierPaymentState, token: String) async throws
    func heartbeat(role: PaykuRole, token: String) async throws
    func registerPush(token: String, deviceToken: String?) async throws
}

enum PaykuAPIError: Error, LocalizedError, Equatable {
    case invalidURL
    case temporal(String)
    case unauthorized
    case forbidden
    case inactiveCommerce
    case invalidLinkCode
    case client(status: Int, message: String)
    case invalidResponse
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: "La dirección del backend no es válida."
        case .temporal(let message): message
        case .unauthorized, .forbidden: "Este dispositivo fue desvinculado."
        case .inactiveCommerce: "Comercio inactivo"
        case .invalidLinkCode: "Ese código no es para esta app."
        case .client(_, let message): message
        case .invalidResponse: "El backend devolvió una respuesta inesperada."
        case .decoding: "No pudimos leer la respuesta del backend."
        }
    }
}

final class LivePaykuAPI: PaykuAPI, @unchecked Sendable {
    private let baseURL: URL
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(baseURL: URL = AppConfig.baseURL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.outputFormatting = []
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .useDefaultKeys
    }

    func linkOwner(code: String) async throws -> DeviceSession { try await link(role: .owner, code: code) }
    func linkCashier(code: String) async throws -> DeviceSession { try await link(role: .cashier, code: code) }

    func logout(role: PaykuRole, token: String) async throws {
        let path: String = role == .owner ? "/device/vincular" : "/espejo/vincular"
        _ = try await perform(path: path, method: "DELETE", token: token, body: nil) as EmptyResponse
    }

    func me(role: PaykuRole, token: String) async throws -> DeviceProfile {
        let path: String = role == .owner ? "/device/me" : "/espejo/me"
        let response: ProfileResponse = try await perform(path: path, method: "GET", token: token, body: nil)
        return response.profile
    }

    func ownerPayments(since: Date, token: String) async throws -> [PaymentDTO] {
        let milliseconds: Int64 = Int64((since.timeIntervalSince1970 * 1000).rounded())
        let path: String = "/device/pagos?desde=\(milliseconds)&limit=200"
        return try await perform(path: path, method: "GET", token: token, body: nil)
    }

    func cashierFeed(cursor: String?, token: String) async throws -> CashierPageDTO {
        var path: String = "/espejo/pagos?limit=100"
        if let cursor, !cursor.isEmpty {
            path += "&cursor=\(Self.escape(cursor))"
        }
        return try await perform(path: path, method: "GET", token: token, body: nil)
    }

    func setPaymentState(id: String, state: CashierPaymentState, token: String) async throws {
        let path: String = "/espejo/pagos/\(Self.escape(id))/estado"
        let body: [String: String] = ["estado": state.backendValue]
        let data: Data = try encoder.encode(body)
        _ = try await perform(path: path, method: "PATCH", token: token, body: data) as EmptyResponse
    }

    func heartbeat(role: PaykuRole, token: String) async throws {
        let path: String = role == .owner ? "/device/heartbeat" : "/espejo/heartbeat"
        _ = try await perform(path: path, method: "POST", token: token, body: nil) as EmptyResponse
    }

    func registerPush(token: String, deviceToken: String?) async throws {
        let path: String = "/espejo/push-token"
        if let deviceToken {
            let data: Data = try encoder.encode(["token": deviceToken])
            _ = try await perform(path: path, method: "POST", token: token, body: data) as EmptyResponse
        } else {
            _ = try await perform(path: path, method: "DELETE", token: token, body: nil) as EmptyResponse
        }
    }

    private func link(role: PaykuRole, code: String) async throws -> DeviceSession {
        let data: Data = try encoder.encode(LinkRequest(codigo: code.trimmingCharacters(in: .whitespacesAndNewlines)))
        let path: String = role == .owner ? "/device/vincular" : "/espejo/vincular"
        do {
            let response: DeviceSessionResponse = try await perform(path: path, method: "POST", token: nil, body: data)
            return DeviceSession(token: response.token, linkedAt: Date())
        } catch let error as PaykuAPIError {
            if case .client(let status, _) = error, [400, 404, 409, 422].contains(status) {
                throw PaykuAPIError.invalidLinkCode
            }
            if case .forbidden = error {
                throw PaykuAPIError.invalidLinkCode
            }
            throw error
        }
    }

    private func perform<Response: Decodable>(path: String, method: String, token: String?, body: Data?) async throws -> Response {
        guard let url = URL(string: path, relativeTo: baseURL) else { throw PaykuAPIError.invalidURL }
        var request: URLRequest = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = AppConfig.requestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        do {
            let (data, response): (Data, URLResponse) = try await session.data(for: request)
            guard let httpResponse: HTTPURLResponse = response as? HTTPURLResponse else { throw PaykuAPIError.invalidResponse }
            try Self.validate(status: httpResponse.statusCode, data: data)
            if data.isEmpty || httpResponse.statusCode == 204 {
                guard let empty = EmptyResponse() as? Response else { throw PaykuAPIError.invalidResponse }
                return empty
            }
            do {
                return try decoder.decode(Response.self, from: data)
            } catch {
                throw PaykuAPIError.decoding("response")
            }
        } catch let error as PaykuAPIError {
            throw error
        } catch let urlError as URLError where [.timedOut, .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost].contains(urlError.code) {
            throw PaykuAPIError.temporal("No hay conexión. Reintentaremos cuando vuelva la red.")
        } catch {
            throw PaykuAPIError.temporal("No pudimos conectar con Payku. Revisa tu conexión.")
        }
    }

    private static func validate(status: Int, data: Data) throws {
        switch status {
        case 200..<300: return
        case 401: throw PaykuAPIError.unauthorized
        case 403: throw PaykuAPIError.forbidden
        case 402: throw PaykuAPIError.inactiveCommerce
        case 408, 425, 429, 500...599: throw PaykuAPIError.temporal("El servidor está ocupado. Reintentaremos pronto.")
        default:
            let message: String = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "La solicitud no se pudo completar (\(status))."
            throw PaykuAPIError.client(status: status, message: message.isEmpty ? "La solicitud no se pudo completar (\(status))." : message)
        }
    }

    private static func escape(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
    }
}

private struct EmptyResponse: Decodable {
    init() {}
}

actor FakePaykuAPI: PaykuAPI {
    private var token: String?
    private var payments: [PaymentDTO] = FakePaykuAPI.sampleDTOs()

    func linkOwner(code: String) async throws -> DeviceSession {
        try await link(code: code, role: .owner)
    }

    func linkCashier(code: String) async throws -> DeviceSession {
        try await link(code: code, role: .cashier)
    }

    func logout(role: PaykuRole, token: String) async throws {
        self.token = nil
    }

    func me(role: PaykuRole, token: String) async throws -> DeviceProfile {
        guard self.token == token else { throw PaykuAPIError.unauthorized }
        return DeviceProfile(merchantName: "La Bodega Verde", branchName: "Barranco · Principal", deviceName: role == .owner ? "iPhone del dueño" : "iPhone del mostrador")
    }

    func ownerPayments(since: Date, token: String) async throws -> [PaymentDTO] {
        guard self.token == token else { throw PaykuAPIError.unauthorized }
        return payments
    }

    func cashierFeed(cursor: String?, token: String) async throws -> CashierPageDTO {
        guard self.token == token else { throw PaykuAPIError.unauthorized }
        return CashierPageDTO(pagos: payments, hayMas: false, siguienteCursor: nil)
    }

    func setPaymentState(id: String, state: CashierPaymentState, token: String) async throws {
        guard self.token == token else { throw PaykuAPIError.unauthorized }
        guard let index: Int = payments.firstIndex(where: { $0.id == id }) else { return }
        let old: PaymentDTO = payments[index]
        payments[index] = PaymentDTO(id: old.id, monto: old.monto, nombrePagador: old.nombrePagador, referencia: old.referencia, billetera: old.billetera, estado: state.backendValue, sinParsear: old.sinParsear, rawText: old.rawText, hashDedup: old.hashDedup, fechaHoraCaptura: old.fechaHoraCaptura, creadoEn: old.creadoEn)
    }

    func heartbeat(role: PaykuRole, token: String) async throws {
        guard self.token == token else { throw PaykuAPIError.unauthorized }
    }

    func registerPush(token: String, deviceToken: String?) async throws {}

    private func link(code: String, role: PaykuRole) async throws -> DeviceSession {
        let cleaned: String = code.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let isOwnerCode: Bool = cleaned == "PYK-48A2Q7" || cleaned.contains("DUEÑO") || cleaned.contains("DUENO")
        let isCashierCode: Bool = cleaned.contains("CAJERO") || cleaned.contains("CASH")
        guard (role == .owner && isOwnerCode) || (role == .cashier && isCashierCode) else {
            throw PaykuAPIError.invalidLinkCode
        }
        let newToken: String = "fake-\(role)-\(UUID().uuidString)"
        token = newToken
        return DeviceSession(token: newToken, linkedAt: Date())
    }

    private static func sampleDTOs() -> [PaymentDTO] {
        let now: Date = Date()
        func dto(_ id: String, _ amount: Double?, _ name: String?, _ reference: String?, _ wallet: String, _ status: String, _ age: TimeInterval, _ raw: String, _ unread: Bool = false) -> PaymentDTO {
            PaymentDTO(id: id, monto: amount, nombrePagador: name, referencia: reference, billetera: wallet, estado: status, sinParsear: unread, rawText: raw, hashDedup: id, fechaHoraCaptura: now.addingTimeInterval(-age), creadoEn: now.addingTimeInterval(-age))
        }
        return [
            dto("pay-82k1", 28.00, "María Quispe", "YAPE-82K1", "yape", "verificado", 8 * 60, "Yape María Quispe te envió S/ 28.00"),
            dto("pay-14f8", 15.50, "Diego Ramírez", "PLIN-14F8", "plin", "verificado", 31 * 60, "Plin Diego Ramírez te envió S/ 15.50"),
            dto("pay-7a10", 42.00, "Ana Torres", "YAPE-7A10", "yape", "verificado", 63 * 60, "Yape Ana Torres te envió S/ 42.00"),
            dto("pay-55q2", 89.90, "William Pla*", "YAPE-55Q2", "yape", "libre", 3 * 60 * 60, "Yape William Pla* te envió S/ 89.90"),
            dto("pay-unread", nil, nil, nil, "plin", "verificado", 5 * 60 * 60, "Tienes un nuevo movimiento en Plin", true),
            dto("pay-20bb", 120.00, "José Mendoza", "YAPE-20BB", "yape", "verificado", 8 * 60 * 60, "Yape José Mendoza te envió S/ 120.00"),
            dto("pay-0d21", 9.00, "Rosa Cárdenas", "YAPE-0D21", "yape", "verificado", 26 * 60 * 60, "Yape Rosa Cárdenas te envió S/ 9.00"),
            dto("pay-91lm", 65.00, "Carlos Huamán", "PLIN-91LM", "plin", "verificado", 29 * 60 * 60, "Plin Carlos Huamán te envió S/ 65.00"),
            dto("pay-42ap", 18.50, "Sofía Ruiz", "YAPE-42AP", "yape", "descartado", 52 * 60 * 60, "Yape Sofía Ruiz te envió S/ 18.50"),
            dto("pay-11c2", 35.00, "Luis Paredes", "YAPE-11C2", "yape", "verificado", 72 * 60 * 60, "Yape Luis Paredes te envió S/ 35.00")
        ]
    }
}

