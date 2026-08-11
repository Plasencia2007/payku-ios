import Foundation
import Observation

@Observable
@MainActor
final class PaykuStore {
    var role: PaykuRole?
    var isLinked = false
    var isSetupComplete = false
    var hasSeenIntro = false
    var isShowingSplash = false
    var isOnline = true
    var sourceIsLive = true
    var isInstantSyncEnabled = true
    var isAutoDeleteEnabled = false
    var retentionDays = 30
    var cashierVoiceEnabled = true
    var cashierSoundEnabled = true
    var payments: [Payment] = PaykuStore.samplePayments()
    var employees: [Employee] = [
        Employee(name: "Lucía Fernández", code: "PYK-48A2Q7"),
        Employee(name: "Marco Salazar", code: "PYK-12N9KM")
    ]
    var alerts: [AlertItem] = [
        AlertItem(
            severity: .attention,
            title: "Fuente sin señal reciente",
            detail: "El sensor externo no reporta desde hace 16 minutos. Revisa que siga conectado.",
            symbol: "antenna.radiowaves.left.and.right"
        ),
        AlertItem(
            severity: .info,
            title: "Hay 2 pagos en cola",
            detail: "Se enviarán automáticamente cuando vuelva la conexión.",
            symbol: "arrow.up.circle"
        )
    ]

    var merchantName: String = "La Bodega Verde"
    var branchName: String = "Barranco · Principal"
    var deviceName: String = "Sensor Android del local"

    var todayPayments: [Payment] {
        payments.filter { $0.isIncludedInCash }
    }

    var sentCount: Int { payments.filter { $0.state == .sent }.count }
    var queuedCount: Int { payments.filter { $0.state == .queued || $0.state == .failed }.count }
    var unreadCount: Int { payments.filter(\.isUnread).count }
    var todayTotalCents: Int { todayPayments.compactMap(\.amountCents).reduce(0, +) }
    var todayCount: Int { todayPayments.count }
    var yesterdayTotalCents: Int { 248_930 }
    var todayVariation: Double? {
        guard yesterdayTotalCents > 0 else { return nil }
        return Double(todayTotalCents - yesterdayTotalCents) / Double(yesterdayTotalCents)
    }

    func link(code: String, role: PaykuRole) {
        self.role = role
        isLinked = true
        hasSeenIntro = true
    }

    func completeSetup() {
        isSetupComplete = true
    }

    func resetSession() {
        role = nil
        isLinked = false
        isSetupComplete = false
        sourceIsLive = true
    }

    func discard(_ payment: Payment) {
        guard let index = payments.firstIndex(where: { $0.id == payment.id }) else { return }
        let old = payments[index]
        payments[index] = Payment(
            id: old.id,
            payerName: old.payerName,
            amountCents: old.amountCents,
            receivedAt: old.receivedAt,
            wallet: old.wallet,
            operationCode: old.operationCode,
            rawText: old.rawText,
            state: .discarded,
            cashierState: .discarded,
            attempts: old.attempts,
            lastError: old.lastError
        )
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
        let cutoff = Date().addingTimeInterval(-90 * 24 * 60 * 60)
        payments.removeAll { $0.receivedAt < cutoff && $0.state == .sent }
    }

    func csvExport() -> String {
        var rows = ["fecha,nombre,monto,billetera,estado,codigo"]
        rows.append(contentsOf: payments.map { payment in
            let date = payment.receivedAt.formatted(.iso8601.year().month().day().dateSeparator(.dash))
            let amount = payment.amountCents.map { String(format: "%.2f", Double($0) / 100) } ?? ""
            return [date, payment.displayName, amount, payment.wallet.rawValue, payment.state.title, payment.operationCode ?? ""].map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"" }.joined(separator: ",")
        })
        return rows.joined(separator: "\n")
    }

    nonisolated private static func samplePayments() -> [Payment] {
        let now = Date()
        return [
            Payment(payerName: "María Quispe", amountCents: 28_00, receivedAt: now.addingTimeInterval(-8 * 60), wallet: .yape, operationCode: "YAPE-82K1", rawText: "Yape María Quispe te envió S/ 28.00", state: .sent, cashierState: .verified),
            Payment(payerName: "Diego Ramírez", amountCents: 15_50, receivedAt: now.addingTimeInterval(-31 * 60), wallet: .plin, operationCode: "PLIN-14F8", rawText: "Plin Diego Ramírez te envió S/ 15.50", state: .sent, cashierState: .verified),
            Payment(payerName: "Ana Torres", amountCents: 42_00, receivedAt: now.addingTimeInterval(-63 * 60), wallet: .yape, operationCode: "YAPE-7A10", rawText: "Yape Ana Torres te envió S/ 42.00", state: .sent, cashierState: .verified),
            Payment(payerName: "William Pla*", amountCents: 89_90, receivedAt: now.addingTimeInterval(-3 * 60 * 60), wallet: .yape, operationCode: "YAPE-55Q2", rawText: "Yape William Pla* te envió S/ 89.90", state: .sent, cashierState: .free),
            Payment(payerName: nil, amountCents: nil, receivedAt: now.addingTimeInterval(-5 * 60 * 60), wallet: .plin, operationCode: nil, rawText: "Tienes un nuevo movimiento en Plin", state: .sent, cashierState: .new),
            Payment(payerName: "José Mendoza", amountCents: 120_00, receivedAt: now.addingTimeInterval(-8 * 60 * 60), wallet: .yape, operationCode: "YAPE-20BB", rawText: "Yape José Mendoza te envió S/ 120.00", state: .queued, cashierState: .new, attempts: 3, lastError: "Sin conexión con el servidor"),
            Payment(payerName: "Rosa Cárdenas", amountCents: 9_00, receivedAt: now.addingTimeInterval(-26 * 60 * 60), wallet: .yape, operationCode: "YAPE-0D21", rawText: "Yape Rosa Cárdenas te envió S/ 9.00", state: .sent, cashierState: .verified),
            Payment(payerName: "Carlos Huamán", amountCents: 65_00, receivedAt: now.addingTimeInterval(-29 * 60 * 60), wallet: .plin, operationCode: "PLIN-91LM", rawText: "Plin Carlos Huamán te envió S/ 65.00", state: .sent, cashierState: .verified),
            Payment(payerName: "Sofía Ruiz", amountCents: 18_50, receivedAt: now.addingTimeInterval(-52 * 60 * 60), wallet: .yape, operationCode: "YAPE-42AP", rawText: "Yape Sofía Ruiz te envió S/ 18.50", state: .sent, cashierState: .discarded),
            Payment(payerName: "Luis Paredes", amountCents: 35_00, receivedAt: now.addingTimeInterval(-72 * 60 * 60), wallet: .yape, operationCode: "YAPE-11C2", rawText: "Yape Luis Paredes te envió S/ 35.00", state: .failed, cashierState: .new, attempts: 4, lastError: "El servidor no respondió")
        ]
    }
}

