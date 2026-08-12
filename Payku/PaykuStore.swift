import Foundation
import Observation

@Observable
@MainActor
final class PaykuStore {
    let role: PaykuRole
    private let api: any PaykuAPI
    private let keychain: KeychainStore
    private var session: DeviceSession?
    private var runtimeTask: Task<Void, Never>?
    private var lastRefreshAt: Date?

    var isLinked = false
    var isSetupComplete = false
    var hasSeenIntro = false
    var isShowingSplash = false
    var isOnline = true
    var sourceIsLive = false
    var isLoading = false
    var errorMessage: String?
    var commerceInactive = false
    var isInstantSyncEnabled = true
    var isAutoDeleteEnabled = false
    var retentionDays = 30
    var cashierVoiceEnabled = true
    var cashierSoundEnabled = true
    var payments: [Payment] = []
    var employees: [Employee] = [
        Employee(name: "Lucía Fernández", code: "PYK-48A2Q7"),
        Employee(name: "Marco Salazar", code: "PYK-12N9KM")
    ]
    var alerts: [AlertItem] = []
    var merchantName = "Tu comercio"
    var branchName = "Sucursal principal"
    var deviceName = "Este dispositivo"

    private var cashierCursor: String?

    init(api: (any PaykuAPI)? = nil, keychain: KeychainStore = KeychainStore()) {
        self.role = AppConfig.currentRole.paykuRole
        if let api {
            self.api = api
        } else if AppConfig.useFakeBackend {
            self.api = FakePaykuAPI()
        } else {
            self.api = LivePaykuAPI()
        }
        self.keychain = keychain
        self.hasSeenIntro = UserDefaults.standard.bool(forKey: "\(AppConfig.currentRole.rawValue)-\(AppConfig.introKey)")
        self.isSetupComplete = UserDefaults.standard.bool(forKey: "\(AppConfig.currentRole.rawValue)-\(AppConfig.setupKey)")
        do {
            self.session = try keychain.readSession()
            self.isLinked = self.session != nil
        } catch {
            self.session = nil
            self.isLinked = false
        }
        Task { await bootstrap() }
    }

    var todayPayments: [Payment] {
        payments.filter { payment in
            guard payment.isIncludedInCash, let date = payment.receivedAt else { return false }
            return PaykuFormatters.isToday(date)
        }
    }

    var sentCount: Int { payments.filter { $0.state == .sent }.count }
    var queuedCount: Int { payments.filter { $0.state == .queued || $0.state == .failed }.count }
    var unreadCount: Int { payments.filter(\.isUnread).count }
    var todayTotalCents: Int { todayPayments.compactMap(\.amountCents).reduce(0, +) }
    var todayCount: Int { todayPayments.count }
    var yesterdayTotalCents: Int {
        payments.filter { payment in
            guard payment.isIncludedInCash, let date = payment.receivedAt else { return false }
            return PaykuFormatters.isYesterday(date)
        }.compactMap(\.amountCents).reduce(0, +)
    }
    var todayVariation: Double? {
        guard yesterdayTotalCents > 0 else { return nil }
        return Double(todayTotalCents - yesterdayTotalCents) / Double(yesterdayTotalCents)
    }

    func link(code: String) {
        let normalized: String = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        commerceInactive = false
        Task { [weak self] in
            guard let self else { return }
            do {
                let linkedSession: DeviceSession = switch self.role {
                case .owner: try await self.api.linkOwner(code: normalized)
                case .cashier: try await self.api.linkCashier(code: normalized)
                }
                try self.keychain.save(linkedSession)
                self.session = linkedSession
                self.isLinked = true
                self.hasSeenIntro = true
                self.isShowingSplash = false
                self.persistIntro()
                await self.loadProfileAndRefresh()
            } catch {
                self.present(error)
            }
            self.isLoading = false
        }
    }

    func completeSetup() {
        isSetupComplete = true
        UserDefaults.standard.set(true, forKey: "\(AppConfig.currentRole.rawValue)-\(AppConfig.setupKey)")
        isShowingSplash = true
        startRuntime()
    }

    func logout() {
        guard let session else {
            clearLocalSession()
            return
        }
        isLoading = true
        Task { [weak self] in
            guard let self else { return }
            try? await self.api.logout(role: self.role, token: session.token)
            try? self.keychain.deleteSession()
            self.clearLocalSession()
            self.isLoading = false
        }
    }

    func resetSession() { logout() }

    func refresh() async {
        guard let session else { return }
        isLoading = payments.isEmpty
        do {
            switch role {
            case .owner:
                let since: Date = Date().addingTimeInterval(-AppConfig.overlapInterval)
                let incoming: [PaymentDTO] = try await api.ownerPayments(since: since, token: session.token)
                merge(incoming, owner: true)
            case .cashier:
                let page: CashierPageDTO = try await api.cashierFeed(cursor: cashierCursor, token: session.token)
                merge(page.pagos, owner: false)
                cashierCursor = page.hayMas ? page.siguienteCursor : nil
            }
            try await api.heartbeat(role: role, token: session.token)
            sourceIsLive = true
            isOnline = true
            commerceInactive = false
            errorMessage = nil
            lastRefreshAt = Date()
            updateAlerts()
        } catch {
            present(error)
        }
        isLoading = false
    }

    func startRuntime() {
        runtimeTask?.cancel()
        runtimeTask = Task { [weak self] in
            guard let self else { return }
            if self.role == .owner {
                await self.refresh()
                return
            }
            while !Task.isCancelled {
                await self.refresh()
                try? await Task.sleep(for: AppConfig.pollingInterval)
            }
        }
    }

    func stopRuntime() {
        runtimeTask?.cancel()
        runtimeTask = nil
    }

    func discard(_ payment: Payment) {
        setCashierState(payment, state: .discarded)
    }

    func restore(_ payment: Payment) {
        setCashierState(payment, state: .verified)
    }

    func addEmployee() {
        employees.append(Employee(name: "Nuevo cajero", code: "PYK-" + String(UUID().uuidString.prefix(6)).uppercased()))
    }

    func removeEmployee(_ employee: Employee) {
        employees.removeAll { $0.id == employee.id }
    }

    func clearSentPayments() {
        payments.removeAll { $0.state == .sent }
    }

    func clearOlderPayments() {
        let cutoff: Date = Date().addingTimeInterval(-Double(max(retentionDays, 1)) * 24 * 60 * 60)
        payments.removeAll { payment in
            payment.state == .sent && (payment.receivedAt ?? .distantFuture) < cutoff
        }
    }

    func csvExport() -> String {
        var rows: [String] = ["fecha,nombre,monto,billetera,estado,codigo"]
        rows.append(contentsOf: payments.map { payment in
            let date: String = payment.receivedAt.map { PaykuFormatters.isoDate($0) } ?? ""
            let amount: String = payment.amountCents.map { String(format: "%.2f", Double($0) / 100) } ?? ""
            return [date, payment.displayName, amount, payment.wallet.rawValue, payment.state.title, payment.operationCode ?? ""].map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"" }.joined(separator: ",")
        })
        return rows.joined(separator: "\n")
    }

    private func bootstrap() async {
        guard session != nil else { return }
        await loadProfileAndRefresh()
    }

    private func loadProfileAndRefresh() async {
        guard let session else { return }
        do {
            let profile: DeviceProfile = try await api.me(role: role, token: session.token)
            merchantName = profile.merchantName
            branchName = profile.branchName
            deviceName = profile.deviceName
            isLinked = true
            if isSetupComplete { startRuntime() }
            await refresh()
        } catch {
            present(error)
        }
    }

    private func setCashierState(_ payment: Payment, state: CashierPaymentState) {
        guard role == .cashier, let session else { return }
        guard let index: Int = payments.firstIndex(where: { $0.id == payment.id }) else { return }
        payments[index].cashierState = state
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.api.setPaymentState(id: payment.id, state: state, token: session.token)
            } catch {
                self.present(error)
            }
        }
    }

    private func merge(_ dtos: [PaymentDTO], owner: Bool) {
        var byID: [String: Payment] = Dictionary(uniqueKeysWithValues: payments.map { ($0.id, $0) })
        for dto in dtos {
            byID[dto.id] = dto.normalizedPayment(owner: owner)
        }
        payments = byID.values.sorted { lhs, rhs in
            (lhs.receivedAt ?? .distantPast) > (rhs.receivedAt ?? .distantPast)
        }
    }

    private func updateAlerts() {
        var next: [AlertItem] = []
        if !sourceIsLive {
            next.append(AlertItem(severity: .attention, title: "Fuente sin señal reciente", detail: "El sensor externo no reporta. Comprueba que siga conectado.", symbol: "antenna.radiowaves.left.and.right"))
        }
        if queuedCount > 0 {
            next.append(AlertItem(severity: .info, title: "Hay \(queuedCount) pagos en cola", detail: "Se reintentarán cuando vuelva la conexión.", symbol: "arrow.up.circle"))
        }
        if commerceInactive {
            next.insert(AlertItem(severity: .critical, title: "Comercio inactivo", detail: "Contacta al administrador del comercio para reactivarlo.", symbol: "exclamationmark.octagon"), at: 0)
        }
        alerts = next
    }

    private func present(_ error: Error) {
        if let apiError = error as? PaykuAPIError {
            switch apiError {
            case .unauthorized, .forbidden:
                clearLocalSession()
                errorMessage = "Este dispositivo fue desvinculado"
            case .inactiveCommerce:
                commerceInactive = true
                errorMessage = apiError.localizedDescription
            case .temporal:
                isOnline = false
                if role == .cashier { sourceIsLive = false }
                errorMessage = apiError.localizedDescription
            default:
                errorMessage = apiError.localizedDescription
            }
        } else {
            errorMessage = "No pudimos completar la operación."
        }
        updateAlerts()
    }

    private func clearLocalSession() {
        stopRuntime()
        session = nil
        isLinked = false
        isSetupComplete = false
        isShowingSplash = false
        payments = []
        cashierCursor = nil
        UserDefaults.standard.set(false, forKey: "\(AppConfig.currentRole.rawValue)-\(AppConfig.setupKey)")
    }

    private func persistIntro() {
        UserDefaults.standard.set(true, forKey: "\(AppConfig.currentRole.rawValue)-\(AppConfig.introKey)")
    }
}

