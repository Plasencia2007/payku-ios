import SwiftUI

enum PaykuColor {
    static let brand = Color(red: 0.424, green: 0.259, blue: 0.902)
    static let brandLight = Color(red: 0.541, green: 0.408, blue: 0.937)
    static let brandInk = Color(red: 0.271, green: 0.145, blue: 0.612)
    static let brandWash = Color(red: 0.937, green: 0.914, blue: 0.996)
    static let canvas = Color(red: 0.965, green: 0.980, blue: 0.973)
    static let mist = Color(red: 0.937, green: 0.945, blue: 0.941)
    static let border = Color(red: 0.925, green: 0.910, blue: 0.882)
    static let ink = Color(red: 0.102, green: 0.090, blue: 0.078)
    static let secondaryInk = Color(red: 0.420, green: 0.396, blue: 0.365)
    static let success = Color(red: 0.118, green: 0.620, blue: 0.416)
    static let successWash = Color(red: 0.890, green: 0.961, blue: 0.925)
    static let warning = Color(red: 0.878, green: 0.525, blue: 0.0)
    static let warningWash = Color(red: 1.0, green: 0.953, blue: 0.871)
    static let danger = Color(red: 0.863, green: 0.149, blue: 0.149)
    static let dangerWash = Color(red: 0.984, green: 0.914, blue: 0.914)
}

struct PaykuCardModifier: ViewModifier {
    var fill: Color = .white
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
    func paykuCard(fill: Color = .white, radius: CGFloat = 20) -> some View {
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
        let hash = name.unicodeScalars.reduce(0) { ($0 + Int($1.value)) % palette.count }
        return palette[hash]
    }

    var body: some View {
        Text(initials.isEmpty ? "?" : initials)
            .font(.system(size: size * 0.32, weight: .bold, design: .rounded))
            .foregroundStyle(PaykuColor.ink)
            .frame(width: size, height: size)
            .background(avatarColor, in: .circle)
            .accessibilityLabel(name)
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

