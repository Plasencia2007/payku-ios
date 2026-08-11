import Foundation

/// The two experiences supported by Payku.
enum PaykuRole: String, CaseIterable, Codable, Hashable, Identifiable {
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

enum PaymentState: String, CaseIterable, Codable, Hashable, Identifiable {
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

enum Wallet: String, CaseIterable, Codable, Hashable {
    case yape = "Yape"
    case plin = "Plin"
}

enum CashierPaymentState: String, CaseIterable, Codable, Hashable {
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
}

/// A payment projection used by both the owner mirror and the cashier feed.
struct Payment: Identifiable, Hashable, Codable {
    let id: UUID
    let payerName: String?
    let amountCents: Int?
    let receivedAt: Date
    let wallet: Wallet
    let operationCode: String?
    let rawText: String
    let state: PaymentState
    let cashierState: CashierPaymentState
    let attempts: Int
    let lastError: String?

    init(
        id: UUID = UUID(),
        payerName: String?,
        amountCents: Int?,
        receivedAt: Date,
        wallet: Wallet,
        operationCode: String?,
        rawText: String,
        state: PaymentState,
        cashierState: CashierPaymentState,
        attempts: Int = 1,
        lastError: String? = nil
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
        case .listen: "En Apple, los cobros llegan desde una fuente externa conectada a tu negocio. Payku los muestra sin inventar datos."
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

struct AlertItem: Identifiable, Hashable {
    enum Severity: String, Hashable {
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

struct Employee: Identifiable, Hashable {
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

