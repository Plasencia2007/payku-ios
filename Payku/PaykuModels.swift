import Foundation

/// The experience selected by the compiled target.
enum PaykuRole: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case owner = "DUEÑO"
    case cashier = "CAJERO"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .owner: "Dueño"
        case .cashier: "Cajero"
        }
    }

    var subtitle: String {
        switch self {
        case .owner: "Caja, historial y control"
        case .cashier: "Cobros en vivo en el mostrador"
        }
    }
}

enum PaymentState: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case sent = "ENVIADO"
    case queued = "EN_COLA"
    case failed = "FALLIDO"
    case discarded = "DESCARTADO"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sent: "Enviado"
        case .queued: "En cola"
        case .failed: "Con error"
        case .discarded: "Descartado"
        }
    }
}

enum Wallet: String, CaseIterable, Codable, Hashable, Sendable {
    case yape = "Yape"
    case plin = "Plin"
}

enum CashierPaymentState: String, CaseIterable, Codable, Hashable, Sendable {
    case verified = "VERIFICADO"
    case discarded = "DESCARTADO"
    case new = "NUEVO"
    case free = "LIBRE"

    var title: String {
        switch self {
        case .verified: "Verificado"
        case .discarded: "Descartado"
        case .new: "Nuevo"
        case .free: "Libre"
        }
    }

    var backendValue: String {
        switch self {
        case .verified, .new: "verificado"
        case .discarded: "descartado"
        case .free: "libre"
        }
    }
}

/// A payment normalized for the UI. Money is always held as integer cents.
struct Payment: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let payerName: String?
    let amountCents: Int?
    let receivedAt: Date?
    let wallet: Wallet
    let operationCode: String?
    let rawText: String
    var state: PaymentState
    var cashierState: CashierPaymentState
    var attempts: Int
    var lastError: String?
    let sinParsear: Bool

    init(
        id: String = UUID().uuidString,
        payerName: String?,
        amountCents: Int?,
        receivedAt: Date?,
        wallet: Wallet,
        operationCode: String?,
        rawText: String,
        state: PaymentState,
        cashierState: CashierPaymentState,
        attempts: Int = 1,
        lastError: String? = nil,
        sinParsear: Bool = false
    ) {
        self.id = id
        self.payerName = payerName
        self.amountCents = amountCents
        self.receivedAt = receivedAt
        self.wallet = wallet
        self.operationCode = operationCode
        self.rawText = rawText
        self.state = state
        self.cashierState = cashierState
        self.attempts = attempts
        self.lastError = lastError
        self.sinParsear = sinParsear
    }

    var displayName: String { payerName?.isEmpty == false ? payerName! : "No se pudo leer" }
    var isIncludedInCash: Bool { state != .discarded && cashierState != .discarded }
    var isUnread: Bool { state == .sent && amountCents == nil }
}

enum HistoryFilter: String, CaseIterable, Identifiable {
    case all = "Todos"
    case sent = "Enviados"
    case queued = "En cola"
    case failed = "Con error"
    case unread = "No leídos"

    var id: String { rawValue }
}

enum DateFilter: String, CaseIterable, Identifiable {
    case today = "Hoy"
    case sevenDays = "7 días"
    case month = "Mes"
    case all = "Todo"
    case range = "Rango"

    var id: String { rawValue }
}

enum OwnerRoute: Hashable {
    case payment(Payment)
    case profile
    case alerts
    case storage
    case permissions
    case help
    case about
    case uptime
    case employees
}

enum IntroPage: Int, CaseIterable, Identifiable {
    case welcome
    case easy
    case listen
    case clarity

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .welcome: "Tu caja, sin apuntar nada"
        case .easy: "Así de fácil"
        case .listen: "La fuente habla, Payku ordena"
        case .clarity: "Nada se te escapa"
        }
    }

    var message: String {
        switch self {
        case .welcome: "Payku convierte los cobros de tu negocio en una caja del día clara y lista para revisar."
        case .easy: "Vincula tu negocio, cobra por Yape como siempre y revisa cada movimiento en un solo lugar."
        case .listen: "En Apple, los cobros llegan desde una fuente externa conectada al negocio. Payku los muestra sin inventar datos."
        case .clarity: "Cada cobro conserva su hora, monto y diagnóstico para que tu caja siempre tenga contexto."
        }
    }

    var symbol: String {
        switch self {
        case .welcome: "tray.full.fill"
        case .easy: "wand.and.stars"
        case .listen: "waveform.badge.mic"
        case .clarity: "checkmark.seal.fill"
        }
    }
}

enum SetupPage: Int, CaseIterable, Identifiable {
    case source
    case trial
    case ready

    var id: Int { rawValue }
}

struct AlertItem: Identifiable, Hashable, Sendable {
    enum Severity: String, Hashable, Sendable {
        case critical = "Crítico"
        case attention = "Atención"
        case info = "Info"
    }

    let id: UUID
    let severity: Severity
    let title: String
    let detail: String
    let symbol: String

    init(id: UUID = UUID(), severity: Severity, title: String, detail: String, symbol: String) {
        self.id = id
        self.severity = severity
        self.title = title
        self.detail = detail
        self.symbol = symbol
    }
}

struct Employee: Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    var code: String
    var isActive: Bool

    init(id: UUID = UUID(), name: String, code: String, isActive: Bool = true) {
        self.id = id
        self.name = name
        self.code = code
        self.isActive = isActive
    }
}

struct DeviceProfile: Codable, Sendable, Equatable {
    let merchantName: String
    let branchName: String
    let deviceName: String
}

struct PaymentDTO: Codable, Sendable, Equatable {
    let id: String
    let monto: Double?
    let nombrePagador: String?
    let referencia: String?
    let billetera: String
    let estado: String
    let sinParsear: Bool
    let rawText: String
    let hashDedup: String
    let fechaHoraCaptura: Date?
    let creadoEn: Date?

    init(
        id: String,
        monto: Double?,
        nombrePagador: String?,
        referencia: String?,
        billetera: String,
        estado: String,
        sinParsear: Bool,
        rawText: String,
        hashDedup: String,
        fechaHoraCaptura: Date?,
        creadoEn: Date?
    ) {
        self.id = id
        self.monto = monto
        self.nombrePagador = nombrePagador
        self.referencia = referencia
        self.billetera = billetera
        self.estado = estado
        self.sinParsear = sinParsear
        self.rawText = rawText
        self.hashDedup = hashDedup
        self.fechaHoraCaptura = fechaHoraCaptura
        self.creadoEn = creadoEn
    }

    enum CodingKeys: String, CodingKey {
        case id, monto, nombrePagador, referencia, billetera, estado, sinParsear, rawText, hashDedup, fechaHoraCaptura, creadoEn
    }

    init(from decoder: Decoder) throws {
        let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        monto = try container.decodeIfPresent(Double.self, forKey: .monto)
        nombrePagador = try container.decodeIfPresent(String.self, forKey: .nombrePagador)
        referencia = try container.decodeIfPresent(String.self, forKey: .referencia)
        billetera = try container.decodeIfPresent(String.self, forKey: .billetera) ?? "yape"
        estado = try container.decodeIfPresent(String.self, forKey: .estado) ?? "verificado"
        sinParsear = try container.decodeIfPresent(Bool.self, forKey: .sinParsear) ?? false
        rawText = try container.decodeIfPresent(String.self, forKey: .rawText) ?? ""
        hashDedup = try container.decodeIfPresent(String.self, forKey: .hashDedup) ?? id
        fechaHoraCaptura = Self.decodeDate(container, key: .fechaHoraCaptura)
        creadoEn = Self.decodeDate(container, key: .creadoEn)
    }

    private static func decodeDate(_ container: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> Date? {
        guard let value: String = try? container.decode(String.self, forKey: key) else { return nil }
        return ISO8601DateFormatter.payku.date(from: value)
    }

    func normalizedPayment(owner: Bool) -> Payment {
        let cents: Int? = monto.map { Int(($0 * 100).rounded()) }
        let wallet: Wallet = billetera.lowercased() == "plin" ? .plin : .yape
        let cashierState: CashierPaymentState = switch estado.lowercased() {
        case "descartado": .discarded
        case "libre": .free
        default: .verified
        }
        let ownerState: PaymentState = switch estado.lowercased() {
        case "descartado": .discarded
        default: .sent
        }
        return Payment(
            id: id,
            payerName: nombrePagador,
            amountCents: cents,
            receivedAt: fechaHoraCaptura ?? creadoEn,
            wallet: wallet,
            operationCode: referencia,
            rawText: rawText,
            state: owner ? ownerState : .sent,
            cashierState: cashierState,
            sinParsear: sinParsear
        )
    }
}

struct CashierPageDTO: Codable, Sendable {
    let pagos: [PaymentDTO]
    let hayMas: Bool
    let siguienteCursor: String?

    enum CodingKeys: String, CodingKey { case pagos, hayMas, siguienteCursor }

    init(pagos: [PaymentDTO], hayMas: Bool, siguienteCursor: String?) {
        self.pagos = pagos
        self.hayMas = hayMas
        self.siguienteCursor = siguienteCursor
    }

    init(from decoder: Decoder) throws {
        let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)
        pagos = try container.decodeIfPresent([PaymentDTO].self, forKey: .pagos) ?? []
        hayMas = try container.decodeIfPresent(Bool.self, forKey: .hayMas) ?? false
        siguienteCursor = try container.decodeIfPresent(String.self, forKey: .siguienteCursor)
    }
}

struct LinkRequest: Encodable, Sendable {
    let codigo: String
}

struct DeviceSessionResponse: Decodable, Sendable {
    let token: String

    enum CodingKeys: String, CodingKey { case token, accessToken }

    init(from decoder: Decoder) throws {
        let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)
        if let value: String = try container.decodeIfPresent(String.self, forKey: .token) {
            token = value
        } else {
            token = try container.decode(String.self, forKey: .accessToken)
        }
    }
}

struct ProfileResponse: Decodable, Sendable {
    let merchantName: String
    let branchName: String
    let deviceName: String

    enum CodingKeys: String, CodingKey { case merchantName, comercio, branchName, sucursal, deviceName, dispositivo }

    init(from decoder: Decoder) throws {
        let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)
        merchantName = try container.decodeIfPresent(String.self, forKey: .merchantName) ?? (try container.decodeIfPresent(String.self, forKey: .comercio)) ?? "Tu comercio"
        branchName = try container.decodeIfPresent(String.self, forKey: .branchName) ?? (try container.decodeIfPresent(String.self, forKey: .sucursal)) ?? "Sucursal principal"
        deviceName = try container.decodeIfPresent(String.self, forKey: .deviceName) ?? (try container.decodeIfPresent(String.self, forKey: .dispositivo)) ?? "Este dispositivo"
    }

    var profile: DeviceProfile { DeviceProfile(merchantName: merchantName, branchName: branchName, deviceName: deviceName) }
}

extension ISO8601DateFormatter {
    static let payku: ISO8601DateFormatter = {
        let formatter: ISO8601DateFormatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

