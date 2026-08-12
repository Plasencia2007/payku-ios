import SwiftUI
import UIKit

enum PaykuColor {
    static let brand = Color.paykuDynamic(light: UIColor(red: 0.424, green: 0.259, blue: 0.902, alpha: 1), dark: UIColor(red: 0.58, green: 0.43, blue: 1.0, alpha: 1))
    static let brandLight = Color.paykuDynamic(light: UIColor(red: 0.541, green: 0.408, blue: 0.937, alpha: 1), dark: UIColor(red: 0.70, green: 0.60, blue: 1.0, alpha: 1))
    static let brandInk = Color.paykuDynamic(light: UIColor(red: 0.271, green: 0.145, blue: 0.612, alpha: 1), dark: UIColor(red: 0.82, green: 0.75, blue: 1.0, alpha: 1))
    static let brandWash = Color.paykuDynamic(light: UIColor(red: 0.937, green: 0.914, blue: 0.996, alpha: 1), dark: UIColor(red: 0.20, green: 0.15, blue: 0.32, alpha: 1))
    static let canvas = Color.paykuDynamic(light: UIColor(red: 0.965, green: 0.980, blue: 0.973, alpha: 1), dark: UIColor(red: 0.055, green: 0.052, blue: 0.068, alpha: 1))
    static let surface = Color.paykuDynamic(light: UIColor.white, dark: UIColor(red: 0.105, green: 0.102, blue: 0.13, alpha: 1))
    static let mist = Color.paykuDynamic(light: UIColor(red: 0.937, green: 0.945, blue: 0.941, alpha: 1), dark: UIColor(red: 0.15, green: 0.145, blue: 0.18, alpha: 1))
    static let border = Color.paykuDynamic(light: UIColor(red: 0.925, green: 0.910, blue: 0.882, alpha: 1), dark: UIColor(red: 0.24, green: 0.23, blue: 0.29, alpha: 1))
    static let ink = Color.paykuDynamic(light: UIColor(red: 0.102, green: 0.090, blue: 0.078, alpha: 1), dark: UIColor(red: 0.96, green: 0.95, blue: 0.98, alpha: 1))
    static let secondaryInk = Color.paykuDynamic(light: UIColor(red: 0.420, green: 0.396, blue: 0.365, alpha: 1), dark: UIColor(red: 0.70, green: 0.68, blue: 0.74, alpha: 1))
    static let success = Color.paykuDynamic(light: UIColor(red: 0.118, green: 0.620, blue: 0.416, alpha: 1), dark: UIColor(red: 0.35, green: 0.82, blue: 0.59, alpha: 1))
    static let successWash = Color.paykuDynamic(light: UIColor(red: 0.890, green: 0.961, blue: 0.925, alpha: 1), dark: UIColor(red: 0.10, green: 0.25, blue: 0.18, alpha: 1))
    static let warning = Color.paykuDynamic(light: UIColor(red: 0.878, green: 0.525, blue: 0.0, alpha: 1), dark: UIColor(red: 1.0, green: 0.69, blue: 0.22, alpha: 1))
    static let warningWash = Color.paykuDynamic(light: UIColor(red: 1.0, green: 0.953, blue: 0.871, alpha: 1), dark: UIColor(red: 0.29, green: 0.20, blue: 0.08, alpha: 1))
    static let danger = Color.paykuDynamic(light: UIColor(red: 0.863, green: 0.149, blue: 0.149, alpha: 1), dark: UIColor(red: 1.0, green: 0.42, blue: 0.42, alpha: 1))
    static let dangerWash = Color.paykuDynamic(light: UIColor(red: 0.984, green: 0.914, blue: 0.914, alpha: 1), dark: UIColor(red: 0.30, green: 0.12, blue: 0.14, alpha: 1))
}

private extension Color {
    static func paykuDynamic(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
}

struct PaykuCardModifier: ViewModifier {
    var fill: Color = PaykuColor.surface
    var radius: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .background(fill, in: .rect(cornerRadius: radius))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(PaykuColor.border, lineWidth: 1)
            }
    }
}

extension View {
    func paykuCard(fill: Color = PaykuColor.surface, radius: CGFloat = 20) -> some View {
        modifier(PaykuCardModifier(fill: fill, radius: radius))
    }
}

struct PaykuBackground: View {
    var body: some View {
        ZStack {
            PaykuColor.canvas
            LinearGradient(
                colors: [PaykuColor.brandWash.opacity(0.42), .clear, PaykuColor.canvas],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }
}

struct PaykuLogo: View {
    var compact: Bool = false

    var body: some View {
        HStack(spacing: compact ? 8 : 10) {
            ZStack {
                RoundedRectangle(cornerRadius: compact ? 10 : 13, style: .continuous)
                    .fill(PaykuColor.brand)
                Image(systemName: "bolt.fill")
                    .font(.system(size: compact ? 15 : 19, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: compact ? 34 : 44, height: compact ? 34 : 44)

            Text("Payku")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(PaykuColor.ink)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Payku")
    }
}

struct StatusPill: View {
    let title: String
    let color: Color
    let fill: Color
    var showsDot: Bool = true

    var body: some View {
        HStack(spacing: 6) {
            if showsDot {
                Circle()
                    .fill(color)
                    .frame(width: 7, height: 7)
            }
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(0.7)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(fill, in: .capsule)
    }
}

struct AvatarView: View {
    let name: String
    var size: CGFloat = 44
    var tint: Color? = nil

    private var initials: String {
        let words = name.split(separator: " ").prefix(2)
        return words.compactMap { $0.first }.map(String.init).joined().uppercased()
    }

    private var avatarColor: Color {
        if let tint { return tint }
        let palette: [Color] = [
            Color(red: 0.83, green: 0.91, blue: 0.98),
            Color(red: 0.89, green: 0.84, blue: 0.98),
            Color(red: 0.99, green: 0.88, blue: 0.75),
            Color(red: 0.82, green: 0.95, blue: 0.86),
            Color(red: 0.98, green: 0.83, blue: 0.88),
            Color(red: 0.80, green: 0.94, blue: 0.95)
        ]
        let hash: Int = name.unicodeScalars.reduce(0) { ($0 + Int($1.value)) % palette.count }
        return palette[hash]
    }

    var body: some View {
        Text(initials.isEmpty ? "?" : initials)
            .font(.system(size: size * 0.32, weight: .bold, design: .rounded))
            .foregroundStyle(PaykuColor.ink)
            .frame(width: size, height: size)
            .background(avatarColor, in: .circle)
            .accessibilityElement()
            .accessibilityLabel("Avatar de \(name)")
    }
}

struct MetricTile: View {
    let label: String
    let value: String
    let detail: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: symbol)
                    .font(.headline)
                    .foregroundStyle(tint)
                    .frame(width: 34, height: 34)
                    .background(tint.opacity(0.12), in: .circle)
                    .accessibilityHidden(true)
                Spacer()
            }
            Text(value)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(PaykuColor.ink)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PaykuColor.ink)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(PaykuColor.secondaryInk)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .paykuCard()
    }
}

struct SectionHeader: View {
    let title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(PaykuColor.ink)
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PaykuColor.brand)
            }
        }
    }
}

struct CommerceInactiveBanner: View {
    var body: some View {
        Label("Comercio inactivo", systemImage: "exclamationmark.octagon.fill")
            .font(.subheadline.weight(.bold))
            .foregroundStyle(PaykuColor.danger)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(PaykuColor.dangerWash)
            .accessibilityLabel("Comercio inactivo. Contacta al administrador.")
    }
}

struct PaykuLoadingState: View {
    let title: String

    var body: some View {
        VStack(spacing: 12) {
            ProgressView().tint(PaykuColor.brand)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PaykuColor.secondaryInk)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 42)
    }
}

struct PaykuErrorState: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "wifi.exclamationmark")
                .font(.title2)
                .foregroundStyle(PaykuColor.warning)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(PaykuColor.secondaryInk)
                .multilineTextAlignment(.center)
            Button("Reintentar", action: retry)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(PaykuColor.brand)
                .frame(minHeight: 44)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .padding(.horizontal, 18)
    }
}

