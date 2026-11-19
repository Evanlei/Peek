import SwiftUI

/// Permission prompt for the oldest pending request.
/// Deliberately sparse: one sentence, the command, two buttons. The character's "!"
/// in the scene already says "waiting", so the card carries no icon, tint or border.
/// Radii are concentric on the button side: card 14 = button 7 + inset 7.
struct ApprovalCard: View {
    let agent: Agent
    let request: PermissionRequest
    let queued: Int
    let onDeny: () -> Void
    let onAllow: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                (Text(agent.displayName).fontWeight(.semibold).foregroundStyle(.white.opacity(0.9))
                 + Text(" \(request.verb)").foregroundStyle(.white.opacity(0.45))
                 + Text(queued > 1 ? "  ·  1 of \(queued)" : "").foregroundStyle(.white.opacity(0.3)))
                    .font(.system(size: 11))
                    .lineLimit(1)
                Text(request.detail)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 2) {
                Button("Deny", action: onDeny)
                    .buttonStyle(PeekButtonStyle(kind: .secondary))
                Button("Allow", action: onAllow)
                    .buttonStyle(PeekButtonStyle(kind: .primary))
            }
        }
        .padding(.leading, 14)   // text side: optical inset matches the panel's curve
        .padding(.trailing, 7)
        .padding(.vertical, 7)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct PeekButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary }
    let kind: Kind
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(kind == .primary ? Color.black : .white.opacity(0.6))
            .padding(.horizontal, 12)
            .frame(height: 28)
            // Secondary is text-only: one filled control keeps the decision obvious.
            .background(kind == .primary ? Color.white : .clear,
                        in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
            // Press feedback: 0.96 over 150ms ease-out; disabled never scales.
            .scaleEffect(configuration.isPressed && isEnabled ? 0.96 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
            .contentShape(Rectangle())
    }
}

/// Header usage ring: share of the rolling 5-hour window.
struct UsageRing: View {
    let fraction: Double

    var body: some View {
        HStack(spacing: 5) {
            ZStack {
                Circle().stroke(.white.opacity(0.15), lineWidth: 2)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(ContextBar.color(fraction), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.25), value: fraction)
            }
            .frame(width: 12, height: 12)
            Text("5h \(Int((fraction * 100).rounded()))%")
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .foregroundStyle(.white.opacity(0.55))
        }
    }
}

/// Infrequent entrance: opacity + 4pt blur + 12pt rise, 300ms ease-out in;
/// exit shorter (150ms) and smaller. Reduced motion → cross-fade only.
struct BlurRise: ViewModifier {
    let active: Bool
    let reduce: Bool
    let rise: CGFloat
    func body(content: Content) -> some View {
        content
            .opacity(active ? 0 : 1)
            .blur(radius: active && !reduce ? 4 : 0)
            .offset(y: active && !reduce ? rise : 0)
    }
}

extension AnyTransition {
    static func blurRise(reduce: Bool) -> AnyTransition {
        .asymmetric(
            insertion: .modifier(active: BlurRise(active: true, reduce: reduce, rise: 12),
                                 identity: BlurRise(active: false, reduce: reduce, rise: 12))
                .animation(.timingCurve(0.2, 0, 0, 1, duration: 0.3)),
            removal: .modifier(active: BlurRise(active: true, reduce: reduce, rise: -12),
                               identity: BlurRise(active: false, reduce: reduce, rise: -12))
                .animation(.easeOut(duration: 0.15)))
    }
}
