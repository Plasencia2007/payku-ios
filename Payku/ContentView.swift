import AVFoundation
import AudioToolbox
import PhotosUI
import SwiftUI

struct ContentView: View {
    @Environment(PaykuStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if !store.hasSeenIntro {
                IntroView()
            } else if !store.isLinked {
                LinkingView()
            } else if !store.isSetupComplete {
                SetupView()
            } else if store.isShowingSplash {
                SplashView()
            } else if store.role == .owner {
                OwnerAppView()
            } else {
                CashierAppView()
            }
        }
        .overlay(alignment: .top) {
            if store.commerceInactive {
                CommerceInactiveBanner()
            }
        }
        .preferredColorScheme(nil)
        .task {
            if store.isLinked && store.isSetupComplete { store.startRuntime() }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                if store.isLinked && store.isSetupComplete {
                    store.startRuntime()
                }
            case .background, .inactive:
                store.stopRuntime()
            @unknown default:
                break
            }
        }
    }
}

struct IntroView: View {
    @Environment(PaykuStore.self) private var store
    @State private var page: Int = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var currentPage: IntroPage { IntroPage(rawValue: page) ?? .welcome }

    var body: some View {
        ZStack {
            PaykuBackground()

            ScrollView {
                VStack(spacing: 0) {
                    HStack {
                        PaykuLogo(compact: true)
                        Spacer()
                        Text("Para negocios que cobran en serio")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(PaykuColor.secondaryInk)
                            .multilineTextAlignment(.trailing)
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 18)

                    Spacer(minLength: 26)

                    ZStack {
                        Circle()
                            .fill(PaykuColor.brandWash)
                            .frame(width: 270, height: 270)
                            .blur(radius: 1)
                        Circle()
                            .stroke(PaykuColor.brand.opacity(0.18), lineWidth: 1)
                            .frame(width: 220, height: 220)
                        Image(systemName: currentPage.symbol)
                            .font(.system(size: 74, weight: .semibold))
                            .foregroundStyle(PaykuColor.brand)
                            .symbolEffect(.bounce, value: page)
                    }
                    .frame(height: 295)
                    .accessibilityHidden(true)

                    VStack(spacing: 14) {
                        Text(currentPage.title)
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                            .foregroundStyle(PaykuColor.ink)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.8)

                        Text(currentPage.message)
                            .font(.body)
                            .foregroundStyle(PaykuColor.secondaryInk)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .frame(maxWidth: 350)
                    }
                    .padding(.horizontal, 26)

                    HStack(spacing: 7) {
                        ForEach(IntroPage.allCases) { item in
                            Capsule()
                                .fill(item.rawValue == page ? PaykuColor.brand : PaykuColor.border)
                                .frame(width: item.rawValue == page ? 26 : 7, height: 7)
                                .animation(reduceMotion ? nil : .snappy, value: page)
                        }
                    }
                    .padding(.top, 26)

                    VStack(spacing: 12) {
                        Button {
                            if page < IntroPage.allCases.count - 1 {
                                withAnimation(reduceMotion ? nil : .spring) { page += 1 }
                            } else {
                                store.hasSeenIntro = true
                            }
                        } label: {
                            Text(page == IntroPage.allCases.count - 1 ? "Vincular mi celular" : "Continuar")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 54)
                                .background(PaykuColor.brand, in: .capsule)
                        }
                        .buttonStyle(.plain)

                        if page > 0 {
                            Button("Volver") {
                                withAnimation(reduceMotion ? nil : .snappy) { page -= 1 }
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(PaykuColor.secondaryInk)
                            .frame(minHeight: 44)
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 30)
                    .padding(.bottom, 22)
                }
            }
        }
    }
}

struct LinkingView: View {
    @Environment(PaykuStore.self) private var store
    @State private var code: String = "PYK-48A2Q7"
    @State private var showScanner = false
    @State private var photoItem: PhotosPickerItem?
    @FocusState private var codeFocused: Bool

    var body: some View {
        ZStack {
            PaykuBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    PaykuLogo()
                        .padding(.top, 20)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Vincula este celular")
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        Text("Canjea el código que te dieron desde el panel de Payku. No necesitas usuario ni contraseña.")
                            .font(.body)
                            .foregroundStyle(PaykuColor.secondaryInk)
                            .lineSpacing(3)
                    }
                    .padding(.top, 34)

                    Button {
                        showScanner = true
                    } label: {
                        HStack(spacing: 16) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 15, style: .continuous)
                                    .fill(PaykuColor.brandWash)
                                Image(systemName: "qrcode.viewfinder")
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundStyle(PaykuColor.brand)
                            }
                            .frame(width: 58, height: 58)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Escanear QR")
                                    .font(.headline)
                                    .foregroundStyle(PaykuColor.ink)
                                Text("Usa la cámara o una imagen recibida")
                                    .font(.subheadline)
                                    .foregroundStyle(PaykuColor.secondaryInk)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(PaykuColor.secondaryInk)
                        }
                        .padding(16)
                        .paykuCard()
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 24)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("O escribe el código")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(PaykuColor.secondaryInk)
                        TextField("PYK-XXXXXX", text: $code)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .font(.system(.title3, design: .monospaced, weight: .semibold))
                            .padding(.horizontal, 16)
                            .frame(minHeight: 56)
                            .background(PaykuColor.surface, in: .rect(cornerRadius: 14))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(codeFocused ? PaykuColor.brand : PaykuColor.border, lineWidth: codeFocused ? 2 : 1)
                            }
                            .focused($codeFocused)
                            .onChange(of: code) { _, newValue in
                                let clean = newValue.uppercased().filter { $0.isLetter || $0.isNumber || $0 == "-" }
                                if clean != code { code = clean }
                            }
                    }
                    .padding(.top, 26)

                    Button {
                        codeFocused = false
                        store.link(code: code)
                    } label: {
                        Text("Entrar")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 54)
                            .background(PaykuColor.brand, in: .capsule)
                    }
                    .buttonStyle(.plain)
                    .disabled(code.isEmpty || store.isLoading)
                    .opacity(code.isEmpty || store.isLoading ? 0.45 : 1)
                    .padding(.top, 28)

                    if let errorMessage = store.errorMessage {
                        Text(errorMessage)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(PaykuColor.danger)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 12)
                    }

                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(PaykuColor.brand)
                        Text("Pídele el código al dueño desde el panel de Payku. En esta versión de Apple, los cobros deben llegar desde una fuente externa conectada al negocio.")
                            .font(.caption)
                            .foregroundStyle(PaykuColor.secondaryInk)
                            .lineSpacing(3)
                    }
                    .padding(.top, 18)
                    .padding(.bottom, 22)
                }
                .padding(.horizontal, 22)
            }
        }
        .sheet(isPresented: $showScanner) {
            QRScanSheet(photoItem: $photoItem) {
                code = "PYK-48A2Q7"
                showScanner = false
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
}

struct QRScanSheet: View {
    @Binding var photoItem: PhotosPickerItem?
    let didReadCode: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(PaykuColor.ink)
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(PaykuColor.brandLight, style: StrokeStyle(lineWidth: 2, dash: [8]))
                        .padding(28)
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 64, weight: .light))
                        .foregroundStyle(.white)
                }
                .frame(height: 250)
                .padding(.horizontal, 20)

                Text("Escanea el QR de vinculación")
                    .font(.title3.weight(.bold))
                Text("Apunta al código del panel o elige una imagen que ya tengas guardada.")
                    .font(.subheadline)
                    .foregroundStyle(PaykuColor.secondaryInk)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                VStack(spacing: 10) {
                    Button {
                        didReadCode()
                    } label: {
                        Label("Usar cámara", systemImage: "camera.fill")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 50)
                            .background(PaykuColor.brand, in: .capsule)
                    }
                    .buttonStyle(.plain)

                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label("Escanear desde una foto", systemImage: "photo.on.rectangle")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(PaykuColor.brand)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 44)
                    }
                    .onChange(of: photoItem) { _, newValue in
                        if newValue != nil { didReadCode() }
                    }
                }
                .padding(.horizontal, 22)
                Spacer()
            }
            .padding(.top, 18)
            .navigationTitle("Código QR")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct SetupView: View {
    @Environment(PaykuStore.self) private var store
    @State private var page: Int = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var setupPage: SetupPage { SetupPage(rawValue: page) ?? .source }

    var body: some View {
        ZStack {
            PaykuBackground()
            ScrollView {
                VStack(spacing: 0) {
                    HStack {
                        PaykuLogo(compact: true)
                        Spacer()
                        StatusPill(title: "Vinculado", color: PaykuColor.success, fill: PaykuColor.successWash)
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 18)

                    VStack(spacing: 14) {
                        Text(setupTitle)
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(PaykuColor.ink)
                        Text(setupMessage)
                            .font(.body)
                            .foregroundStyle(PaykuColor.secondaryInk)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                            .frame(maxWidth: 350)
                    }
                    .padding(.top, 40)

                    setupContent
                        .padding(.top, 30)

                    HStack(spacing: 7) {
                        ForEach(SetupPage.allCases) { item in
                            Capsule()
                                .fill(item.rawValue == page ? PaykuColor.brand : PaykuColor.border)
                                .frame(width: item.rawValue == page ? 26 : 7, height: 7)
                        }
                    }
                    .padding(.top, 26)

                    Button {
                        if page < SetupPage.allCases.count - 1 {
                            withAnimation(reduceMotion ? nil : .snappy) { page += 1 }
                        } else {
                            store.completeSetup()
                        }
                    } label: {
                        Text(page == SetupPage.allCases.count - 1 ? "Comenzar a usar Payku" : "Continuar")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 54)
                            .background(PaykuColor.brand, in: .capsule)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 22)
                    .padding(.top, 30)
                    .padding(.bottom, 22)
                }
            }
        }
    }

    private var setupTitle: String {
        switch setupPage {
        case .source: "Conoce tu fuente"
        case .trial: "Prueba un cobro"
        case .ready: "Todo listo"
        }
    }

    private var setupMessage: String {
        switch setupPage {
        case .source: "Payku muestra los cobros que llegan desde el sensor o integración conectada a tu negocio."
        case .trial: "Haz un cobro pequeño y revisa cómo aparece en la caja."
        case .ready: "Tu espacio está preparado para revisar el negocio con claridad."
        }
    }

    @ViewBuilder
    private var setupContent: some View {
        switch setupPage {
        case .source:
            VStack(alignment: .leading, spacing: 14) {
                PermissionSetupRow(symbol: "antenna.radiowaves.left.and.right", title: "Fuente externa", detail: "Conectada desde otro dispositivo", state: "ACTIVA", tint: PaykuColor.success)
                PermissionSetupRow(symbol: "bell.badge", title: "Avisos de Payku", detail: "Te avisamos solo cuando algo necesita atención", state: "LISTO", tint: PaykuColor.success)
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(PaykuColor.warning)
                    Text("Apple no permite leer notificaciones de otras apps. Payku no simula ese permiso: necesita una fuente externa para recibir cobros reales.")
                        .font(.subheadline)
                        .foregroundStyle(PaykuColor.secondaryInk)
                        .lineSpacing(3)
                }
                .padding(16)
                .background(PaykuColor.warningWash, in: .rect(cornerRadius: 16))
            }
            .padding(.horizontal, 22)
        case .trial:
            VStack(spacing: 18) {
                HStack(spacing: 14) {
                    Image(systemName: "arrow.down.left.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(PaykuColor.success)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Nuevo cobro")
                            .font(.headline)
                        Text("Yape · S/ 0.10")
                            .font(.subheadline)
                            .foregroundStyle(PaykuColor.secondaryInk)
                    }
                    Spacer()
                    StatusPill(title: "En vivo", color: PaykuColor.success, fill: PaykuColor.successWash)
                }
                .padding(18)
                .paykuCard()
                Text("Cuando llegue, lo verás aquí con el nombre, monto y hora. También puedes saltar esta prueba y hacerlo después.")
                    .font(.subheadline)
                    .foregroundStyle(PaykuColor.secondaryInk)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 22)
                Button("Saltar por ahora") {}
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PaykuColor.brand)
                    .frame(minHeight: 44)
            }
            .padding(.horizontal, 22)
        case .ready:
            VStack(spacing: 18) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 88, weight: .medium))
                    .foregroundStyle(PaykuColor.success)
                    .symbolEffect(.bounce, value: page)
                Text(store.role == .owner ? "La caja queda lista para recibir datos del negocio." : "Tu mostrador queda listo para ver y cantar cada cobro.")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(PaykuColor.ink)
            }
            .padding(.horizontal, 22)
        }
    }
}

struct PermissionSetupRow: View {
    let symbol: String
    let title: String
    let detail: String
    let state: String
    let tint: Color

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 42, height: 42)
                .background(tint.opacity(0.12), in: .circle)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(detail).font(.caption).foregroundStyle(PaykuColor.secondaryInk)
            }
            Spacer()
            Text(state)
                .font(.caption2.weight(.bold))
                .foregroundStyle(tint)
        }
        .padding(16)
        .paykuCard()
    }
}

struct SplashView: View {
    @Environment(PaykuStore.self) private var store

    var body: some View {
        ZStack {
            PaykuColor.brand
                .ignoresSafeArea()
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.14))
                        .frame(width: 132, height: 132)
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 58, weight: .bold))
                        .foregroundStyle(.white)
                        .symbolEffect(.pulse)
                }
                VStack(spacing: 8) {
                    Text(greeting)
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                    Text(store.role == .owner ? "Tu caja vuelve a estar en vivo" : "Cada cobro, claro en el mostrador")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.78))
                }
                StatusPill(title: "Fuente conectada", color: .white, fill: .white.opacity(0.14))
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(1.25))
            store.isShowingSplash = false
        }
        .onTapGesture {
            store.isShowingSplash = false
        }
    }

    private var greeting: String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = PaykuFormatters.limaTimeZone
        let hour = calendar.component(.hour, from: Date())
        return switch hour {
        case 0...11: "Buenos días"
        case 12...17: "Buenas tardes"
        default: "Buenas noches"
        }
    }
}

struct OwnerAppView: View {
    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Inicio", systemImage: "house.fill", value: 0) {
                NavigationStack { OwnerDashboardView() }
            }
            Tab("Historial", systemImage: "clock.arrow.circlepath", value: 1) {
                NavigationStack { OwnerHistoryView() }
            }
            Tab("Ajustes", systemImage: "slider.horizontal.3", value: 2) {
                NavigationStack { OwnerSettingsView() }
            }
        }
    }
}

struct OwnerDashboardView: View {
    @Environment(PaykuStore.self) private var store
    @State private var shouldRefresh = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                OwnerHeader()

                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Text("Cobrado hoy")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.78))
                        Spacer()
                        StatusPill(title: store.sourceIsLive ? "En vivo" : "Sin señal", color: .white, fill: .white.opacity(0.15))
                    }
                    Text(formatSoles(store.todayTotalCents))
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(store.todayCount) yapes")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.86))
                        Spacer()
                        if let variation = store.todayVariation {
                            Label(variation >= 0 ? "+\(Int(variation * 100))% vs ayer" : "\(Int(variation * 100))% vs ayer", systemImage: variation >= 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white.opacity(0.86))
                        }
                    }
                }
                .padding(20)
                .background(
                    LinearGradient(colors: [PaykuColor.brand, PaykuColor.brandInk], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: .rect(cornerRadius: 24)
                )
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 92, weight: .thin))
                        .foregroundStyle(.white.opacity(0.10))
                        .padding(12)
                }

                HStack(spacing: 12) {
                    MetricTile(label: "Capturados", value: "\(store.sentCount)", detail: "Pagos del período", symbol: "checkmark.circle.fill", tint: PaykuColor.success)
                    MetricTile(label: "En cola", value: "\(store.queuedCount)", detail: store.queuedCount > 0 ? "Pendientes de enviar" : "Todo al día", symbol: "arrow.up.circle.fill", tint: store.queuedCount > 0 ? PaykuColor.warning : PaykuColor.success)
                }

                if store.queuedCount > 0 {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundStyle(PaykuColor.warning)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(store.queuedCount) cobros sin enviar")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(PaykuColor.ink)
                            Text("Toca para reintentar cuando vuelva la red")
                                .font(.caption)
                                .foregroundStyle(PaykuColor.secondaryInk)
                        }
                        Spacer()
                        Button("Reintentar") {
                            shouldRefresh.toggle()
                            Task { await store.refresh() }
                        }
                            .font(.caption.weight(.bold))
                            .foregroundStyle(PaykuColor.brand)
                    }
                    .padding(16)
                    .background(PaykuColor.warningWash, in: .rect(cornerRadius: 16))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(PaykuColor.warning.opacity(0.22), lineWidth: 1)
                    }
                }

                SectionHeader(title: "Últimos yapes", actionTitle: "Ver todo") {
                    // The history tab is always one tap away; the link is intentionally visual and quiet here.
                }

                if store.isLoading && store.payments.isEmpty {
                    PaykuLoadingState(title: "Cargando la caja…")
                        .paykuCard()
                } else if let errorMessage = store.errorMessage, store.payments.isEmpty {
                    PaykuErrorState(message: errorMessage) {
                        Task { await store.refresh() }
                    }
                    .paykuCard()
                } else if store.payments.isEmpty {
                    ContentUnavailableView("Aún no hay cobros", systemImage: "tray", description: Text("Cuando el sensor externo envíe el primer pago, aparecerá aquí."))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 34)
                        .paykuCard()
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(store.payments.prefix(5))) { payment in
                            NavigationLink(value: OwnerRoute.payment(payment)) {
                                PaymentRow(payment: payment, showsChevron: true)
                            }
                            .buttonStyle(.plain)
                            if payment.id != store.payments.prefix(5).last?.id {
                                Divider().overlay(PaykuColor.border).padding(.leading, 58)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .paykuCard()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .background(PaykuBackground())
        .navigationTitle("Inicio")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: OwnerRoute.self) { route in
            OwnerRouteDestination(route: route)
        }
        .refreshable {
            shouldRefresh.toggle()
            await store.refresh()
        }
        .sensoryFeedback(.success, trigger: shouldRefresh)
    }
}

struct OwnerHeader: View {
    @Environment(PaykuStore.self) private var store

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(name: store.merchantName, size: 46, tint: PaykuColor.brandWash)
            VStack(alignment: .leading, spacing: 2) {
                Text(store.merchantName)
                    .font(.headline)
                    .foregroundStyle(PaykuColor.ink)
                Text(store.branchName)
                    .font(.caption)
                    .foregroundStyle(PaykuColor.secondaryInk)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Text("Cuenta vinculada")
                    .font(.caption2.weight(.bold))
                    .tracking(0.7)
                    .foregroundStyle(PaykuColor.brandInk)
                HStack(spacing: 5) {
                    Circle().fill(store.sourceIsLive ? PaykuColor.success : PaykuColor.warning).frame(width: 7, height: 7)
                    Text("Fuente")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(PaykuColor.secondaryInk)
                }
            }
        }
    }
}

struct PaymentRow: View {
    let payment: Payment
    var showsChevron: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(name: payment.displayName, size: 42)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(payment.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PaykuColor.ink)
                        .lineLimit(1)
                    Text(payment.wallet.rawValue)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(PaykuColor.secondaryInk)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(PaykuColor.mist, in: .capsule)
                }
                HStack(spacing: 5) {
                    Text(PaykuFormatters.time(payment.receivedAt))
                    Text("·")
                    Text(payment.operationCode ?? "Procesando")
                }
                .font(.caption)
                .foregroundStyle(PaykuColor.secondaryInk)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 5) {
                Text(formatSoles(payment.amountCents))
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(payment.state == .discarded ? PaykuColor.secondaryInk : PaykuColor.ink)
                PaymentBadge(payment: payment)
            }
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PaykuColor.secondaryInk.opacity(0.65))
            }
        }
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

struct PaymentBadge: View {
    let payment: Payment

    var body: some View {
        let color: Color = switch payment.state {
        case .sent: PaykuColor.success
        case .queued: PaykuColor.warning
        case .failed: PaykuColor.danger
        case .discarded: PaykuColor.secondaryInk
        }
        let fill: Color = switch payment.state {
        case .sent: PaykuColor.successWash
        case .queued: PaykuColor.warningWash
        case .failed: PaykuColor.dangerWash
        case .discarded: PaykuColor.mist
        }
        Text(payment.state.title)
            .font(.caption2.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(fill, in: .capsule)
    }
}

struct OwnerHistoryView: View {
    @Environment(PaykuStore.self) private var store
    @State private var searchText = ""
    @State private var selectedFilter: HistoryFilter = .all
    @State private var selectedDateFilter: DateFilter = .all
    @State private var rangeStart: Date = Date().addingTimeInterval(-7 * 24 * 60 * 60)
    @State private var rangeEnd: Date = Date()
    @State private var showDateFilter = false

    private var filteredPayments: [Payment] {
        store.payments.filter { payment in
            let matchesSearch: Bool = {
                guard !searchText.isEmpty else { return true }
                if payment.displayName.localizedCaseInsensitiveContains(searchText) { return true }
                if let amount = parseSolesSearch(searchText), payment.amountCents == amount { return true }
                return payment.operationCode?.localizedCaseInsensitiveContains(searchText) == true
            }()
            let matchesFilter: Bool = switch selectedFilter {
            case .all: true
            case .sent: payment.state == .sent
            case .queued: payment.state == .queued
            case .failed: payment.state == .failed
            case .unread: payment.isUnread
            }
            let matchesDate: Bool = {
                guard let date = payment.receivedAt else { return selectedDateFilter == .all }
                var calendar: Calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = AppConfig.limaTimeZone
                switch selectedDateFilter {
                case .today: return calendar.isDateInToday(date)
                case .sevenDays: return date >= Date().addingTimeInterval(-7 * 24 * 60 * 60)
                case .month: return calendar.dateInterval(of: .month, for: Date())?.contains(date) == true
                case .all: return true
                case .range: return date >= rangeStart && date <= rangeEnd
                }
            }()
            return matchesSearch && matchesFilter && matchesDate
        }
    }

    private var groupedPayments: [(key: String, value: [Payment])] {
        Dictionary(grouping: filteredPayments) { PaykuFormatters.dayTitle($0.receivedAt) }
            .sorted { $0.key > $1.key }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Total recibido")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PaykuColor.secondaryInk)
                    Text(formatSoles(store.payments.filter(\.isIncludedInCash).compactMap(\.amountCents).reduce(0, +)))
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(PaykuColor.ink)
                    HStack(spacing: 10) {
                        SummaryPill(title: "Pagos", value: "\(store.payments.count)", tint: PaykuColor.brand)
                        SummaryPill(title: "Enviados", value: "\(store.sentCount)", tint: PaykuColor.success)
                        SummaryPill(title: "En cola", value: "\(store.queuedCount)", tint: PaykuColor.warning)
                    }
                }
                .padding(18)
                .paykuCard()

                HStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(PaykuColor.secondaryInk)
                        TextField("Buscar nombre, monto o código", text: $searchText)
                            .textFieldStyle(.plain)
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 48)
                    .background(PaykuColor.surface, in: .rect(cornerRadius: 14))
                    .overlay { RoundedRectangle(cornerRadius: 14).stroke(PaykuColor.border, lineWidth: 1) }
                    Button {
                        showDateFilter = true
                    } label: {
                        Image(systemName: "calendar.badge.clock")
                            .font(.headline)
                            .foregroundStyle(PaykuColor.brand)
                            .frame(width: 48, height: 48)
                            .background(PaykuColor.brandWash, in: .rect(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Filtrar por fecha")
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(HistoryFilter.allCases) { filter in
                            Button {
                                withAnimation(.snappy) { selectedFilter = filter }
                            } label: {
                                Text(filter.rawValue)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(selectedFilter == filter ? .white : PaykuColor.secondaryInk)
                                    .padding(.horizontal, 14)
                                    .frame(minHeight: 38)
                                    .background(selectedFilter == filter ? PaykuColor.brand : PaykuColor.surface, in: .capsule)
                                    .overlay {
                                        if selectedFilter != filter {
                                            Capsule().stroke(PaykuColor.border, lineWidth: 1)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .contentMargins(.horizontal, 1)

                if store.queuedCount > 0 {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundStyle(PaykuColor.warning)
                        Text("Hay pagos que se reintentarán al recuperar la conexión.")
                            .font(.caption)
                            .foregroundStyle(PaykuColor.secondaryInk)
                        Spacer()
                    }
                    .padding(12)
                    .background(PaykuColor.warningWash, in: .rect(cornerRadius: 12))
                }

                HStack {
                    Text("\(filteredPayments.count) pagos")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PaykuColor.secondaryInk)
                    Spacer()
                    ShareLink(item: store.csvExport()) {
                        Label("CSV", systemImage: "square.and.arrow.up")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(PaykuColor.brand)
                    }
                }

                if store.isLoading && store.payments.isEmpty {
                    PaykuLoadingState(title: "Cargando historial…")
                        .paykuCard()
                } else if let errorMessage = store.errorMessage, store.payments.isEmpty {
                    PaykuErrorState(message: errorMessage) {
                        Task { await store.refresh() }
                    }
                    .paykuCard()
                } else if groupedPayments.isEmpty {
                    ContentUnavailableView("No hay pagos", systemImage: "tray", description: Text("Prueba con otro nombre, monto o estado."))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                } else {
                    ForEach(groupedPayments, id: \.key) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(group.key)
                                    .font(.headline)
                                    .foregroundStyle(PaykuColor.ink)
                                Spacer()
                                Text(formatSoles(group.value.compactMap(\.amountCents).reduce(0, +)))
                                    .font(.subheadline.weight(.bold))
                                    .monospacedDigit()
                                    .foregroundStyle(PaykuColor.secondaryInk)
                            }
                            VStack(spacing: 0) {
                                ForEach(group.value) { payment in
                                    NavigationLink(value: OwnerRoute.payment(payment)) {
                                        PaymentRow(payment: payment, showsChevron: true)
                                    }
                                    .buttonStyle(.plain)
                                    if payment.id != group.value.last?.id {
                                        Divider().overlay(PaykuColor.border).padding(.leading, 58)
                                    }
                                }
                            }
                            .padding(.horizontal, 14)
                            .paykuCard()
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .background(PaykuBackground())
        .navigationTitle("Historial")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: OwnerRoute.self) { route in
            OwnerRouteDestination(route: route)
        }
        .sheet(isPresented: $showDateFilter) {
            DateFilterSheet(selected: $selectedDateFilter, rangeStart: $rangeStart, rangeEnd: $rangeEnd)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .refreshable {
            await store.refresh()
        }
    }
}

struct SummaryPill: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(tint)
            Text(title)
                .font(.caption)
                .foregroundStyle(PaykuColor.secondaryInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(tint.opacity(0.08), in: .rect(cornerRadius: 12))
    }
}

struct DateFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selected: DateFilter
    @Binding var rangeStart: Date
    @Binding var rangeEnd: Date

    var body: some View {
        NavigationStack {
            Form {
                Section("Mostrar pagos de") {
                    ForEach(DateFilter.allCases) { option in
                        Button {
                            selected = option
                        } label: {
                            HStack {
                                Text(option.rawValue).foregroundStyle(PaykuColor.ink)
                                Spacer()
                                if selected == option {
                                    Image(systemName: "checkmark").foregroundStyle(PaykuColor.brand)
                                }
                            }
                        }
                    }
                }
                if selected == .range {
                    Section("Rango personalizado") {
                        DatePicker("Desde", selection: $rangeStart, displayedComponents: .date)
                        DatePicker("Hasta", selection: $rangeEnd, displayedComponents: .date)
                    }
                }
            }
            .navigationTitle("Filtrar por fecha")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
        }
    }
}

struct OwnerSettingsView: View {
    @Environment(PaykuStore.self) private var store
    @State private var showLogout = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        AvatarView(name: store.merchantName, size: 52, tint: PaykuColor.brandWash)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(store.merchantName).font(.headline)
                            Text("Vinculado").font(.caption).foregroundStyle(PaykuColor.secondaryInk)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(PaykuColor.secondaryInk)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { }
                }
                .padding(16)
                .paykuCard()

                SettingsSection(title: "Captura y datos") {
                    SettingsLinkRow(symbol: "antenna.radiowaves.left.and.right", title: "Fuente y permisos", detail: store.sourceIsLive ? "Fuente externa activa" : "Revisar conexión", tint: store.sourceIsLive ? PaykuColor.success : PaykuColor.warning, route: .permissions)
                    SettingsLinkRow(symbol: "bell.badge", title: "Avisos", detail: store.alerts.isEmpty ? "Todo en orden" : "\(store.alerts.count) para revisar", tint: store.alerts.isEmpty ? PaykuColor.success : PaykuColor.warning, route: .alerts)
                    SettingsToggleRow(symbol: "bolt.fill", title: "Sincronización instantánea", detail: "Envía al volver la red", isOn: Binding(get: { store.isInstantSyncEnabled }, set: { store.isInstantSyncEnabled = $0 }))
                }

                SettingsSection(title: "Cuenta") {
                    SettingsLinkRow(symbol: "person.crop.circle", title: "Ver mi perfil", detail: "Datos del comercio y celular", tint: PaykuColor.brand, route: .profile)
                    SettingsLinkRow(symbol: "person.2.fill", title: "Empleados", detail: "Códigos de acceso del mostrador", tint: PaykuColor.brand, route: .employees)
                }

                SettingsSection(title: "Datos y soporte") {
                    SettingsLinkRow(symbol: "externaldrive.fill", title: "Almacenamiento", detail: "\(store.payments.count) pagos · 2.4 MB", tint: PaykuColor.secondaryInk, route: .storage)
                    SettingsLinkRow(symbol: "chart.xyaxis.line", title: "Prueba de 7 días", detail: "Continuidad de la fuente", tint: PaykuColor.secondaryInk, route: .uptime)
                    SettingsLinkRow(symbol: "questionmark.circle", title: "Centro de ayuda", detail: "Preguntas frecuentes y contacto", tint: PaykuColor.secondaryInk, route: .help)
                    SettingsLinkRow(symbol: "info.circle", title: "Acerca de Payku", detail: "Versión 1.0 · Construcción 1", tint: PaykuColor.secondaryInk, route: .about)
                }

                Button {
                    showLogout = true
                } label: {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("Cerrar sesión")
                            .font(.headline)
                        Spacer()
                    }
                    .foregroundStyle(PaykuColor.danger)
                    .frame(minHeight: 52)
                    .padding(.horizontal, 16)
                    .background(PaykuColor.dangerWash, in: .rect(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                Text("La fuente externa puede seguir activa aunque cierres esta sesión.")
                    .font(.caption)
                    .foregroundStyle(PaykuColor.secondaryInk)
                    .padding(.horizontal, 4)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 30)
        }
        .background(PaykuBackground())
        .navigationTitle("Ajustes")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: OwnerRoute.self) { route in
            OwnerRouteDestination(route: route)
        }
        .confirmationDialog("¿Cerrar sesión?", isPresented: $showLogout, titleVisibility: .visible) {
            Button("Cerrar sesión", role: .destructive) { store.resetSession() }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Tus pagos locales no se borrarán.")
        }
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(PaykuColor.secondaryInk)
                .padding(.horizontal, 4)
            VStack(spacing: 0, content: content)
                .padding(.horizontal, 14)
                .paykuCard()
        }
    }
}

struct SettingsLinkRow: View {
    let symbol: String
    let title: String
    let detail: String
    let tint: Color
    let route: OwnerRoute

    var body: some View {
        NavigationLink(value: route) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.headline)
                    .foregroundStyle(tint)
                    .frame(width: 34, height: 34)
                    .background(tint.opacity(0.11), in: .circle)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(PaykuColor.ink)
                    Text(detail).font(.caption).foregroundStyle(PaykuColor.secondaryInk)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PaykuColor.secondaryInk.opacity(0.7))
            }
            .padding(.vertical, 13)
        }
        .buttonStyle(.plain)
    }
}

struct SettingsToggleRow: View {
    let symbol: String
    let title: String
    let detail: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.headline)
                .foregroundStyle(PaykuColor.brand)
                .frame(width: 34, height: 34)
                .background(PaykuColor.brandWash, in: .circle)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(PaykuColor.ink)
                Text(detail).font(.caption).foregroundStyle(PaykuColor.secondaryInk)
            }
            Spacer()
            Toggle("", isOn: $isOn).labelsHidden()
        }
        .padding(.vertical, 10)
    }
}

struct OwnerRouteDestination: View {
    let route: OwnerRoute

    var body: some View {
        switch route {
        case .payment(let payment): PaymentDetailView(payment: payment)
        case .profile: ProfileView()
        case .alerts: AlertsView()
        case .storage: StorageView()
        case .permissions: PermissionsView()
        case .help: HelpView()
        case .about: AboutView()
        case .uptime: UptimeView()
        case .employees: EmployeesView()
        }
    }
}

struct PaymentDetailView: View {
    let payment: Payment
    @State private var copied = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(spacing: 12) {
                    AvatarView(name: payment.displayName, size: 70)
                    Text(formatSoles(payment.amountCents))
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(PaykuColor.ink)
                    Text("\(payment.displayName) te envió un pago")
                        .font(.headline)
                        .foregroundStyle(PaykuColor.secondaryInk)
                    PaymentBadge(payment: payment)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .paykuCard()

                VStack(spacing: 0) {
                    DetailDataRow(label: "Estado", value: payment.state.title, tint: payment.state == .sent ? PaykuColor.success : PaykuColor.warning)
                    DetailDataRow(label: "Billetera", value: payment.wallet.rawValue)
                    DetailDataRow(label: "Recibido", value: PaykuFormatters.fullDate(payment.receivedAt))
                    HStack {
                        Text("Cód. de seguridad").font(.subheadline).foregroundStyle(PaykuColor.secondaryInk)
                        Spacer()
                        Text(payment.operationCode ?? "No disponible")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(PaykuColor.ink)
                        Button {
                            copyToClipboard(payment.operationCode ?? "")
                            copied = true
                        } label: {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                .foregroundStyle(PaykuColor.brand)
                                .frame(width: 36, height: 36)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Copiar código")
                    }
                    .padding(.vertical, 14)
                    Divider().overlay(PaykuColor.border)
                    DetailDataRow(label: "Intentos de envío", value: "\(payment.attempts)")
                }
                .padding(.horizontal, 16)
                .paykuCard()

                if let error = payment.lastError {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(PaykuColor.warning)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("El cobro sigue protegido").font(.subheadline.weight(.bold))
                            Text(error).font(.caption).foregroundStyle(PaykuColor.secondaryInk)
                        }
                    }
                    .padding(16)
                    .background(PaykuColor.warningWash, in: .rect(cornerRadius: 16))
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Texto original")
                            .font(.headline)
                        Spacer()
                        Button {
                            copyToClipboard(payment.rawText)
                            copied = true
                        } label: {
                            Label("Copiar", systemImage: copied ? "checkmark" : "doc.on.doc")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(PaykuColor.brand)
                        }
                        .buttonStyle(.plain)
                    }
                    Text(payment.rawText)
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundStyle(PaykuColor.secondaryInk)
                        .textSelection(.enabled)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(PaykuColor.mist, in: .rect(cornerRadius: 14))
                }
                .padding(16)
                .paykuCard()
            }
            .padding(16)
            .padding(.bottom, 30)
        }
        .background(PaykuBackground())
        .navigationTitle("Detalle del pago")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DetailDataRow: View {
    let label: String
    let value: String
    var tint: Color? = nil

    var body: some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(PaykuColor.secondaryInk)
            Spacer()
            Text(value).font(.subheadline.weight(.semibold)).foregroundStyle(tint ?? PaykuColor.ink).multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 14)
    }
}

struct ProfileView: View {
    @Environment(PaykuStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                VStack(spacing: 12) {
                    AvatarView(name: store.merchantName, size: 82, tint: PaykuColor.brandWash)
                    Text(store.merchantName).font(.title2.weight(.bold))
                    StatusPill(title: "Vinculado", color: PaykuColor.success, fill: PaykuColor.successWash)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 22)
                .paykuCard()
                VStack(spacing: 0) {
                    DetailDataRow(label: "Comercio", value: store.merchantName)
                    Divider().overlay(PaykuColor.border)
                    DetailDataRow(label: "Sucursal", value: store.branchName)
                    Divider().overlay(PaykuColor.border)
                    DetailDataRow(label: "Este celular", value: store.deviceName)
                }
                .padding(.horizontal, 16)
                .paykuCard()
                Text("Para cambiar estos datos usa el panel web de Payku. Aquí solo se muestran para que sepas qué negocio está conectado.")
                    .font(.caption)
                    .foregroundStyle(PaykuColor.secondaryInk)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)
            }
            .padding(16)
        }
        .background(PaykuBackground())
        .navigationTitle("Mi perfil")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AlertsView: View {
    @Environment(PaykuStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if store.alerts.isEmpty {
                    ContentUnavailableView("Todo en orden", systemImage: "checkmark.shield", description: Text("No hay problemas que revisar."))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 50)
                } else {
                    Text("Esta bandeja muestra problemas, no pagos.")
                        .font(.subheadline)
                        .foregroundStyle(PaykuColor.secondaryInk)
                    ForEach(store.alerts) { alert in
                        AlertCard(alert: alert)
                    }
                }
            }
            .padding(16)
        }
        .background(PaykuBackground())
        .navigationTitle("Avisos")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AlertCard: View {
    let alert: AlertItem

    private var tint: Color {
        switch alert.severity {
        case .critical: PaykuColor.danger
        case .attention: PaykuColor.warning
        case .info: PaykuColor.brand
        }
    }

    private var fill: Color {
        switch alert.severity {
        case .critical: PaykuColor.dangerWash
        case .attention: PaykuColor.warningWash
        case .info: PaykuColor.brandWash
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: alert.symbol)
                .font(.headline)
                .foregroundStyle(tint)
                .frame(width: 38, height: 38)
                .background(fill, in: .circle)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(alert.title).font(.subheadline.weight(.bold)).foregroundStyle(PaykuColor.ink)
                    Spacer()
                    Text(alert.severity.rawValue).font(.caption2.weight(.bold)).foregroundStyle(tint)
                }
                Text(alert.detail).font(.caption).foregroundStyle(PaykuColor.secondaryInk).lineSpacing(3)
                Button("Revisar ahora") {}
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tint)
                    .padding(.top, 2)
            }
        }
        .padding(16)
        .background(fill, in: .rect(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18).stroke(tint.opacity(0.18), lineWidth: 1)
        }
    }
}

struct StorageView: View {
    @Environment(PaykuStore.self) private var store
    @State private var showDeleteAll = false
    @State private var showDeleteSent = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Uso local").font(.headline)
                            Text("2.4 MB · \(store.payments.count) pagos").font(.caption).foregroundStyle(PaykuColor.secondaryInk)
                        }
                        Spacer()
                        Text("12%").font(.title2.weight(.bold)).foregroundStyle(PaykuColor.brand)
                    }
                    GeometryReader { proxy in
                        HStack(spacing: 3) {
                            ForEach(0..<20, id: \.self) { index in
                                Capsule()
                                    .fill(index < 3 ? PaykuColor.brand : PaykuColor.mist)
                                    .frame(width: max(2, (proxy.size.width - 57) / 20), height: 10)
                            }
                        }
                    }
                    .frame(height: 10)
                    HStack(spacing: 12) {
                        StorageLegend(color: PaykuColor.brand, text: "Últimos 90 días")
                        StorageLegend(color: PaykuColor.mist, text: "Anteriores")
                        StorageLegend(color: PaykuColor.warning, text: "Sin enviar")
                    }
                    .font(.caption2)
                }
                .padding(16)
                .paykuCard()

                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Borrado automático").font(.headline)
                            Text("Nunca borra pagos que aún no subieron.").font(.caption).foregroundStyle(PaykuColor.secondaryInk)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(get: { store.isAutoDeleteEnabled }, set: { store.isAutoDeleteEnabled = $0 }))
                            .labelsHidden()
                    }
                    if store.isAutoDeleteEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Conservar").font(.subheadline.weight(.semibold))
                                Spacer()
                                Text("\(store.retentionDays) días").font(.subheadline.weight(.bold)).foregroundStyle(PaykuColor.brand)
                            }
                            Slider(value: Binding(get: { Double(store.retentionDays) }, set: { store.retentionDays = Int($0.rounded()) }), in: 1...90, step: 1)
                                .tint(PaykuColor.brand)
                            Text("Vista previa: se borrarían 0 pagos enviados.")
                                .font(.caption)
                                .foregroundStyle(PaykuColor.secondaryInk)
                        }
                    }
                }
                .padding(16)
                .paykuCard()

                VStack(alignment: .leading, spacing: 0) {
                    Text("Borrado manual").font(.headline).padding(.bottom, 6)
                    StorageActionRow(title: "Borrar los ya enviados", detail: "Libera espacio sin tocar pendientes") {
                        showDeleteSent = true
                    }
                    Divider().overlay(PaykuColor.border)
                    StorageActionRow(title: "Borrar anteriores a 90 días", detail: "Conserva tu operación reciente") {
                        store.clearOlderPayments()
                    }
                    Divider().overlay(PaykuColor.border)
                    StorageActionRow(title: "Borrar todo el historial", detail: "Esta acción no se puede deshacer", tint: PaykuColor.danger) {
                        showDeleteAll = true
                    }
                }
                .padding(16)
                .paykuCard()

                Text("Los pagos en cola o con error nunca se eliminan automáticamente: son dinero que todavía necesita llegar al servidor.")
                    .font(.caption)
                    .foregroundStyle(PaykuColor.secondaryInk)
                    .padding(.horizontal, 4)
            }
            .padding(16)
        }
        .background(PaykuBackground())
        .navigationTitle("Almacenamiento")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("¿Borrar pagos enviados?", isPresented: $showDeleteSent, titleVisibility: .visible) {
            Button("Borrar enviados", role: .destructive) { store.clearSentPayments() }
            Button("Cancelar", role: .cancel) {}
        }
        .confirmationDialog("¿Borrar todo el historial?", isPresented: $showDeleteAll, titleVisibility: .visible) {
            Button("Borrar todo", role: .destructive) { store.payments.removeAll() }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Los pagos locales desaparecerán de este celular.")
        }
    }
}

struct StorageLegend: View {
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(text).foregroundStyle(PaykuColor.secondaryInk)
        }
    }
}

struct StorageActionRow: View {
    let title: String
    let detail: String
    var tint: Color = PaykuColor.ink
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(tint)
                    Text(detail).font(.caption).foregroundStyle(PaykuColor.secondaryInk)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(PaykuColor.secondaryInk)
            }
            .padding(.vertical, 13)
        }
        .buttonStyle(.plain)
    }
}

struct PermissionsView: View {
    @Environment(PaykuStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(spacing: 12) {
                    Image(systemName: store.sourceIsLive ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(store.sourceIsLive ? PaykuColor.success : PaykuColor.warning)
                    Text(store.sourceIsLive ? "Todo bien por ahora" : "Falta revisar la fuente")
                        .font(.title3.weight(.bold))
                    Text(store.sourceIsLive ? "La fuente externa está reportando cobros." : "No hemos recibido señal reciente del sensor externo.")
                        .font(.subheadline)
                        .foregroundStyle(PaykuColor.secondaryInk)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .paykuCard()

                VStack(alignment: .leading, spacing: 0) {
                    PermissionRow(title: "Fuente externa", detail: "El sensor reporta actividad", state: store.sourceIsLive ? "Activa" : "Revisar", tint: store.sourceIsLive ? PaykuColor.success : PaykuColor.warning, symbol: "antenna.radiowaves.left.and.right")
                    Divider().overlay(PaykuColor.border)
                    PermissionRow(title: "Notificaciones de Payku", detail: "Avisos de problemas", state: "Activas", tint: PaykuColor.success, symbol: "bell.badge")
                    Divider().overlay(PaykuColor.border)
                    PermissionRow(title: "Actualización en segundo plano", detail: "Permitida por el sistema", state: "Disponible", tint: PaykuColor.brand, symbol: "arrow.clockwise")
                }
                .padding(.horizontal, 16)
                .paykuCard()

                VStack(alignment: .leading, spacing: 10) {
                    Text("Últimos 7 días").font(.headline)
                    HStack(alignment: .bottom, spacing: 6) {
                        ForEach([0.88, 0.96, 0.92, 1.0, 0.99, 0.84, 0.97], id: \.self) { value in
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(value < 0.9 ? PaykuColor.warning : PaykuColor.success)
                                .frame(maxWidth: .infinity)
                                .frame(height: CGFloat(value * 70))
                        }
                    }
                    .frame(height: 74, alignment: .bottom)
                    Text("94% de continuidad · 1 caída breve detectada")
                        .font(.caption)
                        .foregroundStyle(PaykuColor.secondaryInk)
                }
                .padding(16)
                .paykuCard()
            }
            .padding(16)
        }
        .background(PaykuBackground())
        .navigationTitle("Fuente y permisos")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PermissionRow: View {
    let title: String
    let detail: String
    let state: String
    let tint: Color
    let symbol: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).foregroundStyle(tint).frame(width: 34, height: 34).background(tint.opacity(0.11), in: .circle)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(PaykuColor.secondaryInk)
            }
            Spacer()
            Text(state).font(.caption.weight(.semibold)).foregroundStyle(tint)
        }
        .padding(.vertical, 13)
    }
}

struct HelpView: View {
    @State private var searchText = ""
    private let faqs = [
        ("¿Payku lee las notificaciones de Yape en iPhone?", "No. Apple no permite que una app lea notificaciones de otras apps. En iPhone, Payku recibe cobros desde una fuente externa conectada al negocio."),
        ("¿Qué significa Sin señal?", "Significa que el celular que alimenta Payku no ha reportado recientemente. No equivale a que nadie haya pagado: comprueba la fuente antes de rechazar un cobro."),
        ("¿Se pierde un cobro sin internet?", "El Dueño conserva el espejo local y la cola. Los pagos pendientes se reintentan al recuperar la conexión."),
        ("¿Cómo cambio mi comercio?", "Los datos del comercio se administran desde el panel web. En la app puedes cerrar sesión y vincular otro código."),
        ("¿Por qué aparece No leído?", "El servidor recibió el cobro pero no logró extraer el monto. El texto original queda guardado para diagnóstico."),
        ("¿Cómo contacto a soporte?", "Escríbenos por WhatsApp o correo y comparte el código de operación del pago que estés revisando.")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(PaykuColor.secondaryInk)
                    TextField("Buscar en ayuda", text: $searchText).textFieldStyle(.plain)
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 48)
                .background(PaykuColor.surface, in: .rect(cornerRadius: 14))
                .overlay { RoundedRectangle(cornerRadius: 14).stroke(PaykuColor.border, lineWidth: 1) }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(["Captura", "Pagos", "Privacidad"], id: \.self) { category in
                            Text(category)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(PaykuColor.secondaryInk)
                                .padding(.horizontal, 14)
                                .frame(minHeight: 36)
                                .background(PaykuColor.surface, in: .capsule)
                                .overlay { Capsule().stroke(PaykuColor.border, lineWidth: 1) }
                        }
                    }
                }

                VStack(spacing: 0) {
                    ForEach(faqs.filter { searchText.isEmpty || $0.0.localizedCaseInsensitiveContains(searchText) || $0.1.localizedCaseInsensitiveContains(searchText) }, id: \.0) { faq in
                        DisclosureGroup {
                            Text(faq.1)
                                .font(.subheadline)
                                .foregroundStyle(PaykuColor.secondaryInk)
                                .lineSpacing(3)
                                .padding(.top, 8)
                                .padding(.bottom, 10)
                        } label: {
                            Text(faq.0).font(.subheadline.weight(.semibold)).foregroundStyle(PaykuColor.ink).multilineTextAlignment(.leading)
                        }
                        .tint(PaykuColor.brand)
                        .padding(.vertical, 13)
                        if faq.0 != faqs.last?.0 { Divider().overlay(PaykuColor.border) }
                    }
                }
                .padding(.horizontal, 16)
                .paykuCard()

                HStack(spacing: 12) {
                    ContactCard(symbol: "message.fill", title: "WhatsApp", detail: "Escribir a soporte")
                    ContactCard(symbol: "envelope.fill", title: "Correo", detail: "hola@payku.pe")
                }
            }
            .padding(16)
        }
        .background(PaykuBackground())
        .navigationTitle("Centro de ayuda")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ContactCard: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol).foregroundStyle(PaykuColor.brand)
            Text(title).font(.subheadline.weight(.bold))
            Text(detail).font(.caption).foregroundStyle(PaykuColor.secondaryInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .paykuCard()
    }
}

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(spacing: 12) {
                    PaykuLogo()
                    Text("Payku convierte los cobros del negocio en una caja que puedes entender.")
                        .font(.body)
                        .foregroundStyle(PaykuColor.secondaryInk)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .paykuCard()

                VStack(alignment: .leading, spacing: 14) {
                    Text("Cómo funciona").font(.headline)
                    AboutStep(number: "01", title: "Conecta", detail: "Vincula este celular al comercio con un código seguro.")
                    AboutStep(number: "02", title: "Recibe", detail: "Los cobros llegan desde la fuente conectada al negocio.")
                    AboutStep(number: "03", title: "Entiende", detail: "Revisa caja, historial y alertas sin perder el contexto.")
                }
                .padding(16)
                .paykuCard()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Versión").font(.headline)
                    DetailDataRow(label: "Versión", value: "1.0.0")
                    Divider().overlay(PaykuColor.border)
                    DetailDataRow(label: "Construcción", value: "1")
                    Divider().overlay(PaykuColor.border)
                    DetailDataRow(label: "Zona del negocio", value: "America/Lima")
                }
                .padding(.horizontal, 16)
                .paykuCard()
            }
            .padding(16)
        }
        .background(PaykuBackground())
        .navigationTitle("Acerca de Payku")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AboutStep: View {
    let number: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number).font(.caption.weight(.bold)).foregroundStyle(PaykuColor.brand).frame(width: 30, height: 30).background(PaykuColor.brandWash, in: .circle)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.bold))
                Text(detail).font(.caption).foregroundStyle(PaykuColor.secondaryInk)
            }
        }
    }
}

struct UptimeView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 14) {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.title2)
                        .foregroundStyle(PaykuColor.success)
                        .frame(width: 48, height: 48)
                        .background(PaykuColor.successWash, in: .circle)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("94% de continuidad").font(.title3.weight(.bold))
                        Text("1 caída breve en los últimos 7 días").font(.caption).foregroundStyle(PaykuColor.secondaryInk)
                    }
                }
                .padding(18)
                .paykuCard()

                VStack(alignment: .leading, spacing: 0) {
                    UptimeRow(day: "Hoy", time: "10:32", status: "Sin caídas", tint: PaykuColor.success)
                    Divider().overlay(PaykuColor.border)
                    UptimeRow(day: "Ayer", time: "09:15", status: "Caída de 8 min", tint: PaykuColor.warning)
                    Divider().overlay(PaykuColor.border)
                    UptimeRow(day: "Lun 10", time: "08:04", status: "Sin caídas", tint: PaykuColor.success)
                    Divider().overlay(PaykuColor.border)
                    UptimeRow(day: "Dom 9", time: "09:00", status: "Sin caídas", tint: PaykuColor.success)
                }
                .padding(.horizontal, 16)
                .paykuCard()

                ShareLink(item: "día,comprobación,estado\nHoy,10:32,Sin caídas\nAyer,09:15,Caída de 8 min") {
                    Label("Exportar registro CSV", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 52)
                        .background(PaykuColor.brand, in: .capsule)
                }
            }
            .padding(16)
        }
        .background(PaykuBackground())
        .navigationTitle("Prueba de 7 días")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct UptimeRow: View {
    let day: String
    let time: String
    let status: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            Circle().fill(tint).frame(width: 9, height: 9)
            Text(day).font(.subheadline.weight(.semibold))
            Spacer()
            Text(time).font(.caption).foregroundStyle(PaykuColor.secondaryInk)
            Text(status).font(.caption.weight(.semibold)).foregroundStyle(tint)
        }
        .padding(.vertical, 14)
    }
}

struct EmployeesView: View {
    @Environment(PaykuStore.self) private var store
    @State private var revealedCode: UUID?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Cajeros del negocio").font(.title3.weight(.bold))
                        Text("Cada código se puede regenerar para invalidar el anterior.")
                            .font(.caption)
                            .foregroundStyle(PaykuColor.secondaryInk)
                    }
                    Spacer()
                    Button {
                        store.addEmployee()
                    } label: {
                        Image(systemName: "plus")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 42, height: 42)
                            .background(PaykuColor.brand, in: .circle)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Generar código para empleado")
                }

                VStack(spacing: 0) {
                    ForEach(store.employees) { employee in
                        HStack(spacing: 12) {
                            AvatarView(name: employee.name, size: 42)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(employee.name).font(.subheadline.weight(.semibold))
                                Text(revealedCode == employee.id ? employee.code : "Código oculto")
                                    .font(.system(.caption, design: .monospaced, weight: .semibold))
                                    .foregroundStyle(revealedCode == employee.id ? PaykuColor.brand : PaykuColor.secondaryInk)
                            }
                            Spacer()
                            Menu {
                                Button(revealedCode == employee.id ? "Ocultar código" : "Ver código") {
                                    revealedCode = revealedCode == employee.id ? nil : employee.id
                                }
                                Button("Regenerar código") {}
                                Button("Dar de baja", role: .destructive) { store.removeEmployee(employee) }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .font(.title3)
                                    .foregroundStyle(PaykuColor.secondaryInk)
                                    .frame(width: 44, height: 44)
                            }
                        }
                        .padding(.vertical, 13)
                        if employee.id != store.employees.last?.id { Divider().overlay(PaykuColor.border) }
                    }
                }
                .padding(.horizontal, 16)
                .paykuCard()

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "qrcode")
                        .foregroundStyle(PaykuColor.brand)
                    Text("Comparte el código o muéstralo como QR desde el panel del dueño. Nunca compartas tu token de dispositivo.")
                        .font(.caption)
                        .foregroundStyle(PaykuColor.secondaryInk)
                        .lineSpacing(3)
                }
                .padding(14)
                .background(PaykuColor.brandWash, in: .rect(cornerRadius: 14))
            }
            .padding(16)
        }
        .background(PaykuBackground())
        .navigationTitle("Empleados")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct CashierAppView: View {
    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("En vivo", systemImage: "dot.radiowaves.left.and.right", value: 0) {
                NavigationStack { CashierLiveView() }
            }
            Tab("Ajustes", systemImage: "slider.horizontal.3", value: 1) {
                NavigationStack { CashierSettingsView() }
            }
        }
    }
}

struct CashierLiveView: View {
    @Environment(PaykuStore.self) private var store
    @State private var selectedPayment: Payment?
    @State private var showDiscardDialog = false
    @State private var announcementCount = 0
    @State private var lastSpokenPaymentID: String?
    private let speaker = AVSpeechSynthesizer()

    private var livePayments: [Payment] { Array(store.payments.prefix(7)) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text("En vivo").font(.system(.largeTitle, design: .rounded, weight: .bold))
                        }
                        Text("\(store.merchantName) · \(store.branchName)")
                            .font(.subheadline)
                            .foregroundStyle(PaykuColor.secondaryInk)
                    }
                    Spacer()
                    StatusPill(title: store.sourceIsLive ? "En vivo" : "Sin señal", color: store.sourceIsLive ? PaykuColor.success : PaykuColor.warning, fill: store.sourceIsLive ? PaykuColor.successWash : PaykuColor.warningWash)
                }

                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Cobrado hoy").font(.subheadline.weight(.semibold)).foregroundStyle(PaykuColor.secondaryInk)
                        Text(formatSoles(store.todayTotalCents)).font(.system(.largeTitle, design: .rounded, weight: .bold)).monospacedDigit()
                        Text("\(store.todayCount) yapes recibidos").font(.caption).foregroundStyle(PaykuColor.secondaryInk)
                    }
                    Spacer()
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.title2)
                        .foregroundStyle(PaykuColor.brand)
                        .frame(width: 52, height: 52)
                        .background(PaykuColor.brandWash, in: .circle)
                }
                .padding(18)
                .paykuCard()

                if !store.sourceIsLive {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(PaykuColor.warning)
                        Text("Sin señal desde hace 16 min. No le digas a un cliente que no pagó sin comprobarlo.")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(PaykuColor.ink)
                    }
                    .padding(14)
                    .background(PaykuColor.warningWash, in: .rect(cornerRadius: 14))
                }

                HStack {
                    Text("Cobros recientes").font(.title3.weight(.bold))
                    Spacer()
                    Text("Actualizado ahora").font(.caption).foregroundStyle(PaykuColor.secondaryInk)
                }

                if store.isLoading && livePayments.isEmpty {
                    PaykuLoadingState(title: "Conectando con el espejo…")
                        .paykuCard()
                } else if let errorMessage = store.errorMessage, livePayments.isEmpty {
                    PaykuErrorState(message: errorMessage) {
                        Task { await store.refresh() }
                    }
                    .paykuCard()
                } else if livePayments.isEmpty {
                    ContentUnavailableView("Sin cobros todavía", systemImage: "dot.radiowaves.left.and.right", description: Text(store.sourceIsLive ? "Cuando llegue un pago aparecerá aquí." : "No confundas una jornada sin pagos con una fuente caída."))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 34)
                        .paykuCard()
                } else {
                    VStack(spacing: 0) {
                        ForEach(livePayments) { payment in
                            Button {
                                selectedPayment = payment
                            } label: {
                                CashierPaymentRow(payment: payment)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Descartar este cobro", role: .destructive) {
                                    selectedPayment = payment
                                    showDiscardDialog = true
                                }
                            }
                            if payment.id != livePayments.last?.id { Divider().overlay(PaykuColor.border).padding(.leading, 58) }
                        }
                    }
                    .padding(.horizontal, 14)
                    .paykuCard()
                }

                Text("Mantén presionado un cobro para descartarlo si no fue una venta.")
                    .font(.caption)
                    .foregroundStyle(PaykuColor.secondaryInk)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(16)
            .padding(.bottom, 30)
        }
        .background(PaykuBackground())
        .navigationTitle("En vivo")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await store.refresh()
        }
        .sheet(item: $selectedPayment) { payment in
            CashierPaymentDetail(payment: payment)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .confirmationDialog("¿Descartar este cobro?", isPresented: $showDiscardDialog, presenting: selectedPayment) { payment in
            Button("Descartar cobro", role: .destructive) {
                store.discard(payment)
                selectedPayment = nil
            }
            Button("Cancelar", role: .cancel) {}
        } message: { payment in
            Text("Se conservará en el historial, pero dejará de sumar a la caja.\n\n\(payment.displayName) · \(formatSoles(payment.amountCents))")
        }
        .onAppear {
            speakNewestIfNeeded()
        }
        .onChange(of: store.payments.first?.id) { _, _ in
            speakNewestIfNeeded()
        }
        .sensoryFeedback(.success, trigger: announcementCount)
    }

    private func speakNewestIfNeeded() {
        guard let payment = livePayments.first, payment.id != lastSpokenPaymentID else { return }
        lastSpokenPaymentID = payment.id
        if store.cashierVoiceEnabled {
            let amount: String = payment.amountCents.map { String(format: "%.2f", Double($0) / 100) } ?? "un monto no leído"
            let phrase: String = "\(payment.wallet.rawValue) recibido de \(payment.displayName) por \(amount) soles"
            speaker.speak(AVSpeechUtterance(string: phrase))
        }
        if store.cashierSoundEnabled {
            AudioServicesPlaySystemSound(1007)
        }
        announcementCount += 1
    }
}

struct CashierPaymentRow: View {
    let payment: Payment

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(name: payment.displayName, size: 44)
            VStack(alignment: .leading, spacing: 5) {
                Text(payment.displayName).font(.subheadline.weight(.semibold)).foregroundStyle(PaykuColor.ink).lineLimit(1)
                HStack(spacing: 5) {
                    Text(PaykuFormatters.time(payment.receivedAt))
                    Text("·")
                    Text(payment.operationCode ?? "Sin código")
                }
                .font(.caption)
                .foregroundStyle(PaykuColor.secondaryInk)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 5) {
                Text(formatSoles(payment.amountCents)).font(.system(.headline, design: .rounded, weight: .bold)).monospacedDigit().foregroundStyle(PaykuColor.ink)
                CashierStatusBadge(state: payment.cashierState)
            }
        }
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

struct CashierStatusBadge: View {
    let state: CashierPaymentState

    var body: some View {
        let tint: Color = switch state {
        case .verified: PaykuColor.success
        case .discarded: PaykuColor.secondaryInk
        case .new: PaykuColor.brand
        case .free: PaykuColor.warning
        }
        let fill: Color = switch state {
        case .verified: PaykuColor.successWash
        case .discarded: PaykuColor.mist
        case .new: PaykuColor.brandWash
        case .free: PaykuColor.warningWash
        }
        Text(state.title.uppercased())
            .font(.caption2.weight(.bold))
            .tracking(0.3)
            .foregroundStyle(tint)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(fill, in: .capsule)
    }
}

struct CashierPaymentDetail: View {
    let payment: Payment
    @Environment(PaykuStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            AvatarView(name: payment.displayName, size: 62)
            Text(formatSoles(payment.amountCents)).font(.system(.largeTitle, design: .rounded, weight: .bold)).monospacedDigit()
            Text("\(payment.displayName) · \(payment.wallet.rawValue)").font(.headline)
            Text("Recibido a las \(PaykuFormatters.time(payment.receivedAt)) · \(payment.operationCode ?? "sin código")")
                .font(.subheadline)
                .foregroundStyle(PaykuColor.secondaryInk)
                .multilineTextAlignment(.center)
            CashierStatusBadge(state: payment.cashierState)
            if payment.cashierState == .discarded {
                Button("Deshacer descarte") {
                    store.restore(payment)
                    dismiss()
                }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(PaykuColor.brand)
                .frame(minHeight: 44)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(PaykuBackground())
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Cerrar") { dismiss() }
            }
        }
    }
}

struct CashierSettingsView: View {
    @Environment(PaykuStore.self) private var store
    @State private var showTurnClose = false
    private let speaker = AVSpeechSynthesizer()

    var body: some View {
        @Bindable var store = store
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(spacing: 14) {
                    HStack(spacing: 12) {
                        AvatarView(name: "Turno de caja", size: 52, tint: PaykuColor.brandWash)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Turno de caja").font(.headline)
                            Text("\(store.merchantName) · Turno de caja").font(.caption).foregroundStyle(PaykuColor.secondaryInk)
                        }
                        Spacer()
                    }
                    HStack {
                        Text("Cobrado hoy").font(.subheadline).foregroundStyle(PaykuColor.secondaryInk)
                        Spacer()
                        Text(formatSoles(store.todayTotalCents)).font(.headline.weight(.bold)).monospacedDigit()
                    }
                }
                .padding(16)
                .paykuCard()

                SettingsSection(title: "Cómo me avisa") {
                    SettingsToggleRow(symbol: "speaker.wave.2.fill", title: "Leer en voz alta", detail: "Anuncia cada cobro nuevo", isOn: $store.cashierVoiceEnabled)
                    Divider().overlay(PaykuColor.border)
                    SettingsToggleRow(symbol: "bell.fill", title: "Sonido de alerta", detail: "Aviso breve al recibir un pago", isOn: $store.cashierSoundEnabled)
                    Divider().overlay(PaykuColor.border)
                    Button {
                        speaker.speak(AVSpeechUtterance(string: "Yape recibido de María por 28 soles"))
                    } label: {
                        HStack {
                            Image(systemName: "play.circle.fill").foregroundStyle(PaykuColor.brand)
                            Text("Probar cómo suena un yape").font(.subheadline.weight(.semibold)).foregroundStyle(PaykuColor.ink)
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(PaykuColor.secondaryInk)
                        }
                        .padding(.vertical, 13)
                    }
                    .buttonStyle(.plain)
                }

                SettingsSection(title: "Este turno") {
                    SettingsLinkRow(symbol: "checkmark.shield", title: "Permisos", detail: "Notificaciones y actualización", tint: PaykuColor.success, route: .permissions)
                }

                Button {
                    showTurnClose = true
                } label: {
                    Text("Cerrar mi turno")
                        .font(.headline)
                        .foregroundStyle(PaykuColor.danger)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 52)
                        .background(PaykuColor.dangerWash, in: .capsule)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .padding(.bottom, 30)
        }
        .background(PaykuBackground())
        .navigationTitle("Ajustes")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: OwnerRoute.self) { route in
            OwnerRouteDestination(route: route)
        }
        .confirmationDialog("¿Cerrar tu turno?", isPresented: $showTurnClose, titleVisibility: .visible) {
            Button("Cerrar turno", role: .destructive) { store.resetSession() }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("El siguiente cajero deberá vincularse con un código.")
        }
    }
}

enum PaykuFormatters {
    static let limaTimeZone: TimeZone = AppConfig.limaTimeZone

    static func time(_ date: Date?) -> String {
        guard let date else { return "Hora no disponible" }
        let formatter: DateFormatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_PE")
        formatter.timeZone = limaTimeZone
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    static func fullDate(_ date: Date?) -> String {
        guard let date else { return "Fecha no disponible" }
        let formatter: DateFormatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_PE")
        formatter.timeZone = limaTimeZone
        formatter.dateFormat = "d 'de' MMMM 'de' yyyy · HH:mm"
        return formatter.string(from: date)
    }

    static func dayTitle(_ date: Date?) -> String {
        guard let date else { return "Fecha no disponible" }
        let formatter: DateFormatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_PE")
        formatter.timeZone = limaTimeZone
        formatter.dateFormat = "EEEE d 'de' MMMM"
        return formatter.string(from: date).capitalized
    }

    static func isoDate(_ date: Date) -> String {
        ISO8601DateFormatter.payku.string(from: date)
    }

    static func isToday(_ date: Date) -> Bool {
        var calendar: Calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = limaTimeZone
        return calendar.isDateInToday(date)
    }

    static func isYesterday(_ date: Date) -> Bool {
        var calendar: Calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = limaTimeZone
        return calendar.isDateInYesterday(date)
    }
}

func formatSoles(_ cents: Int?) -> String {
    guard let cents else { return "—" }
    let formatter = NumberFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.numberStyle = .decimal
    formatter.minimumFractionDigits = 2
    formatter.maximumFractionDigits = 2
    let soles = NSNumber(value: Double(cents) / 100.0)
    return "S/ " + (formatter.string(from: soles) ?? "0.00")
}

func parseSolesSearch(_ text: String) -> Int? {
    var value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: "S/", with: "")
        .replacingOccurrences(of: " ", with: "")
    guard !value.isEmpty else { return nil }

    if value.contains(",") && value.contains(".") {
        value = value.replacingOccurrences(of: ",", with: "")
    } else if let separator = value.firstIndex(where: { $0 == "." || $0 == "," }) {
        let fraction = value[value.index(after: separator)...]
        if fraction.count <= 2 {
            value = value.replacingOccurrences(of: ",", with: ".")
        } else {
            value = value.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: "")
        }
    }

    guard let number = Double(value) else { return nil }
    return Int((number * 100).rounded())
}

func copyToClipboard(_ value: String) {
    #if canImport(UIKit)
    UIPasteboard.general.string = value
    #elseif canImport(AppKit)
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(value, forType: .string)
    #endif
}

#Preview {
    ContentView()
        .environment(PaykuStore())
}


