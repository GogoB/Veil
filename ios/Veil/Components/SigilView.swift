import SwiftUI

struct SigilView: View {
    let seed: Int
    var size: CGFloat = 32
    var color: Color = .primary

    var body: some View {
        Canvas { context, canvasSize in
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            let radius = min(canvasSize.width, canvasSize.height) * 0.43
            let points = (0..<6).map { index in
                let angle = -CGFloat.pi / 2 + CGFloat(index) * CGFloat.pi / 3
                return CGPoint(
                    x: center.x + cos(angle) * radius,
                    y: center.y + sin(angle) * radius
                )
            }

            var outer = Path()
            outer.move(to: points[0])
            for point in points.dropFirst() { outer.addLine(to: point) }
            outer.closeSubpath()
            context.stroke(outer, with: .color(color), lineWidth: max(1, size / 38))

            for index in 0..<6 where (seed + index) % 3 != 0 {
                var spoke = Path()
                spoke.move(to: center)
                spoke.addLine(to: points[index])
                context.stroke(spoke, with: .color(color.opacity(0.92)), lineWidth: max(0.7, size / 48))
            }

            let innerOffset = abs(seed) % 3
            var inner = Path()
            inner.move(to: points[innerOffset])
            inner.addLine(to: points[(innerOffset + 2) % 6])
            inner.addLine(to: points[(innerOffset + 4) % 6])
            inner.closeSubpath()
            context.stroke(inner, with: .color(color.opacity(0.58)), lineWidth: max(0.6, size / 56))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct ActorBadge: View {
    let actor: ActorPresentation
    var size: CGFloat = 38

    @EnvironmentObject private var appearance: AppearanceStore

    var body: some View {
        Group {
            switch actor {
            case let .profile(_, displayName):
                Circle()
                    .fill(Color.veilSecondary.opacity(0.75))
                    .overlay {
                        Text(String(displayName.prefix(1)).lowercased() + ".")
                            .font(.system(size: size * 0.48, weight: .medium, design: .serif))
                            .italic()
                            .foregroundStyle(Color.veilBackground)
                    }
            case let .anonymous(_, seed, _):
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .fill(Color.veilRaised)
                    .overlay {
                        SigilView(seed: seed, size: size * 0.65, color: appearance.accentColor)
                    }
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct VeilWordmark: View {
    @EnvironmentObject private var appearance: AppearanceStore

    var body: some View {
        HStack(spacing: 7) {
            VeilMark()
                .fill(appearance.accentColor)
                .frame(width: 26, height: 26)
            Text("veil")
                .font(.system(size: 29, weight: .semibold, design: .rounded))
                .tracking(-1.5)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Veil")
    }
}

struct VeilMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.08))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.33, y: rect.minY + rect.height * 0.08))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.60, y: rect.maxY * 0.92))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.28, y: rect.maxY * 0.92))
        path.closeSubpath()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.67, y: rect.minY + rect.height * 0.08))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.08))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.63, y: rect.maxY * 0.72))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.48, y: rect.minY + rect.height * 0.33))
        path.closeSubpath()
        return path
    }
}

struct ArchitectureArtwork: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black
                Path { path in
                    let w = proxy.size.width
                    let h = proxy.size.height
                    path.move(to: CGPoint(x: 0, y: h))
                    path.addLine(to: CGPoint(x: w * 0.43, y: h * 0.05))
                    path.addLine(to: CGPoint(x: w * 0.60, y: h * 0.05))
                    path.addLine(to: CGPoint(x: w * 0.52, y: h))
                    path.closeSubpath()
                }
                .fill(Color(white: 0.72))
                Path { path in
                    let w = proxy.size.width
                    let h = proxy.size.height
                    path.move(to: CGPoint(x: w, y: h))
                    path.addLine(to: CGPoint(x: w * 0.60, y: h * 0.05))
                    path.addLine(to: CGPoint(x: w * 0.43, y: h * 0.05))
                    path.addLine(to: CGPoint(x: w * 0.48, y: h))
                    path.closeSubpath()
                }
                .fill(Color(white: 0.37))
                VStack(spacing: 13) {
                    ForEach(0..<6, id: \.self) { _ in
                        Rectangle().fill(Color.black.opacity(0.52)).frame(height: 2)
                    }
                }
                .rotationEffect(.degrees(-63))
                .offset(x: -95, y: 25)
                VStack(spacing: 13) {
                    ForEach(0..<6, id: \.self) { _ in
                        Rectangle().fill(Color.white.opacity(0.24)).frame(height: 2)
                    }
                }
                .rotationEffect(.degrees(63))
                .offset(x: 95, y: 25)
                LinearGradient(colors: [.white.opacity(0.18), .clear, .black.opacity(0.32)], startPoint: .top, endPoint: .bottom)
            }
        }
        .accessibilityLabel("Abstract black-and-white view of monumental concrete architecture")
    }
}
