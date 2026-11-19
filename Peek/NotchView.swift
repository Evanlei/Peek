import SwiftUI

struct NotchView: View {
    let store: AgentStore
    let state: NotchState

    private var g: NotchGeometry { state.geometry }
    private var expanded: Bool { state.isExpanded }
    private var alerting: Bool { state.isAlerting && !state.isExpanded }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var agents: [Agent] { Array(store.agents.prefix(NotchGeometry.maxAgents)) }

    private var size: CGSize {
        expanded ? g.expandedSize(style: state.style, agentCount: agents.count)
            : alerting ? g.alertSize : g.collapsedSize
    }
    /// 24 = card radius 14 + 10 inset, so the card sits concentric in the panel.
    private var bottomRadius: CGFloat { expanded || alerting ? 24 : 10 }

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: g.topInset)
            ZStack(alignment: .top) {
                background
                VStack(spacing: 0) {
                    header
                    if expanded {
                        content
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .top))
                                    .animation(.spring(duration: 0.32, bounce: 0.1).delay(0.05)),
                                removal: .opacity.animation(.easeOut(duration: 0.12))))
                    } else if alerting {
                        PendingApprovalCard(store: store)
                            .padding(.horizontal, 10)
                            .padding(.top, 6)
                            .padding(.bottom, 10)
                            .transition(.blurRise(reduce: reduceMotion))
                    }
                }
                .padding(.horizontal, g.topCornerRadius)
            }
            .frame(width: size.width, height: size.height, alignment: .top)
            .clipShape(clip)
            .background {
                // Shadow lives on a static shape so per-frame scene redraws don't re-blur it.
                if expanded || alerting {
                    clip.fill(.black).shadow(color: .black.opacity(0.45), radius: 18, y: 8)
                        .transition(.opacity)
                }
            }
            .contextMenu {
                Picker("Style", selection: Binding(get: { state.style }, set: { s in
                    withAnimation(.spring(duration: 0.35, bounce: 0.1)) { state.style = s }
                })) {
                    ForEach(SceneStyle.allCases) { Text($0.title).tag($0) }
                }
                Divider()
                Button("Quit Peek") { NSApp.terminate(nil) }
            }
            Spacer(minLength: 0)
        }
        .environment(\.colorScheme, .dark)
    }

    // MARK: Shape

    @ViewBuilder private var background: some View {
        if g.hasNotch {
            NotchShape(topRadius: g.topCornerRadius, bottomRadius: bottomRadius).fill(.black)
        } else {
            RoundedRectangle(cornerRadius: expanded || alerting ? 24 : size.height / 2, style: .continuous)
                .fill(.black)
                .overlay(RoundedRectangle(cornerRadius: expanded || alerting ? 24 : size.height / 2, style: .continuous)
                    .strokeBorder(.white.opacity(0.08)))
        }
    }

    private var clip: AnyShape {
        g.hasNotch
            ? AnyShape(NotchShape(topRadius: g.topCornerRadius, bottomRadius: bottomRadius))
            : AnyShape(RoundedRectangle(cornerRadius: expanded || alerting ? 24 : size.height / 2, style: .continuous))
    }

    // MARK: Header (lives in the wings either side of the notch)

    private var header: some View {
        HStack(spacing: 0) {
            ZStack(alignment: .leading) {
                if expanded {
                    Text(summary)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                        .transition(.opacity)
                } else {
                    critterStrip.transition(.opacity)
                }
            }
            .padding(.leading, expanded ? 16 : 8)
            Spacer(minLength: g.notchWidth + 8)
            if expanded, let usage = store.windowUsage {
                UsageRing(fraction: usage)
                    .padding(.trailing, 10)
                    .transition(.opacity)
            }
            Text(Format.cost(store.totalCost))
                .font(.system(size: 13, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
                // Changes every second or so: high-frequency → instant, no rolling digits.
                .padding(.trailing, expanded ? 16 : 10)
        }
        .frame(height: g.notchHeight)
    }

    private var summary: String {
        let n = agents.count, h = store.subagentCount
        if n == 0 { return "No active sessions" }
        let a = n == 1 ? "1 agent" : "\(n) agents"
        return h > 0 ? "\(a) · \(h) \(h == 1 ? "helper" : "helpers")" : a
    }

    /// Collapsed: tiny critters standing in fixed slots. Deliberately near-still —
    /// this sits in peripheral vision all day. Only "needs me" hops.
    private var critterStrip: some View {
        let ids = agents.map(\.id)
        return SceneCanvas(agents: agents, sim: state.sim("strip"), pixel: 1.5, wander: false,
                           showFloor: false, showSidekicks: false, compact: true,
                           lane: { agent, _ in
                               let i = CGFloat(ids.firstIndex(of: agent.id) ?? 0)
                               let x = 10 + i * NotchGeometry.slot
                               return x...x
                           },
                           // Near-still strip: only a hop needs smooth frames.
                           frameRate: agents.contains { $0.status == .needsInput } ? 12 : 4)
            .frame(width: NotchGeometry.slot * CGFloat(agents.count) + 8, height: g.notchHeight)
    }

    // MARK: Expanded content

    @ViewBuilder private var content: some View {
        switch state.style {
        case .stage: StageLayout(agents: agents, sim: state.sim("stage"))
        case .diorama: DioramaLayout(store: store, agents: agents, sim: state.sim("diorama"))
        case .lanes: LanesLayout(agents: agents, state: state)
        }
    }
}

// MARK: - A. Stage + list

/// One shared floor where everyone wanders, with a compact readout list below.
private struct StageLayout: View {
    let agents: [Agent]
    let sim: SceneSim

    var body: some View {
        VStack(spacing: 0) {
            SceneCanvas(agents: agents, sim: sim, pixel: 3, labels: .nameBelow)
                .frame(height: 88)
                .padding(.horizontal, 10)
                .padding(.bottom, 4)
            VStack(spacing: 0) {
                ForEach(agents) { agent in
                    HStack(spacing: 10) {
                        StatusDot(status: agent.status, size: 7)
                        Text(agent.displayName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 92, alignment: .leading)
                        Text(agent.action)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.55))
                            .lineLimit(1).truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        ContextBar(agent: agent, width: 46, showLabel: false)
                        Text("\(Int(agent.contextFraction * 100))%")
                            .font(.system(size: 10.5, weight: .medium).monospacedDigit())
                            .foregroundStyle(ContextBar.color(agent.contextFraction).opacity(0.9))
                            .frame(width: 30, alignment: .trailing)
                        Text(Format.cost(agent.cost))
                            .font(.system(size: 11, weight: .medium).monospacedDigit())
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(width: 40, alignment: .trailing)
                    }
                    .frame(height: 38)
                    .padding(.horizontal, 12)
                    .background(agent.status == .needsInput
                                ? AgentStatus.needsInput.color.opacity(0.1) : .clear,
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 10)
        }
    }
}

// MARK: - B. Diorama

/// The whole panel is the scene; info floats above each character.
private struct DioramaLayout: View {
    let store: AgentStore
    let agents: [Agent]
    let sim: SceneSim
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            // 30fps: plenty for pixel art, and half the per-frame cost of 60.
            SceneCanvas(agents: agents, sim: sim, pixel: 3.5, labels: .nameAndContextAbove, desks: true, frameRate: 30)
                .frame(height: 88)
                .background(alignment: .bottom) {
                    LinearGradient(colors: [.clear, .white.opacity(0.05)], startPoint: .top, endPoint: .bottom)
                        .frame(height: 40)
                }
                .padding(.horizontal, 10)
            footer
                .frame(height: 42)
                .padding(.horizontal, 10)
                .padding(.top, 6)
                .padding(.bottom, 10)
        }
    }

    /// The single most important thing: a decision you owe, else a problem, else calm.
    @ViewBuilder private var footer: some View {
        let pending = store.pendingRequests
        ZStack {
            if !pending.isEmpty {
                PendingApprovalCard(store: store)
                    .transition(.blurRise(reduce: reduceMotion))
            } else if let a = agents.first(where: { $0.status == .stuck }) {
                note(icon: "exclamationmark.triangle.fill", color: a.status.color,
                     text: "\(a.displayName) is stuck — \(a.action)")
                    .transition(.blurRise(reduce: reduceMotion))
            } else if agents.isEmpty {
                note(icon: "moon.zzz.fill", color: .white.opacity(0.5),
                     text: "No Claude Code sessions in the last 30 minutes")
                    .transition(.blurRise(reduce: reduceMotion))
            } else if let a = agents.first(where: { $0.status == .working }) {
                // Nothing needs you: show what's happening instead of a static "all clear".
                note(icon: "circle.fill", color: AgentStatus.working.color,
                     text: "\(a.displayName)  ·  \(a.action)", iconSize: 6)
                    .id("ticker")                 // update text in place; no re-entrance per action
                    .transition(.blurRise(reduce: reduceMotion))
            } else {
                note(icon: "checkmark.circle.fill", color: AgentStatus.working.color,
                     text: "All clear — nothing needs you")
                    .transition(.blurRise(reduce: reduceMotion))
            }
        }
    }

    private func note(icon: String, color: Color, text: String, iconSize: CGFloat = 11.5) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .medium))
                .frame(width: 12)
                .foregroundStyle(color)
            Text(text)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1).truncationMode(.middle)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(maxHeight: .infinity)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - C. Lanes

/// One card per session, each with its own little room to pace in.
private struct LanesLayout: View {
    let agents: [Agent]
    let state: NotchState

    var body: some View {
        VStack(spacing: 8) {
            ForEach(agents) { agent in
                HStack(spacing: 12) {
                    SceneCanvas(agents: [agent], sim: state.sim("lane-\(agent.id)"), pixel: 2.5)
                        .frame(width: 150, height: 68)
                        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(agent.displayName)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                            if !agent.subagents.isEmpty {
                                Text("+\(agent.subagents.count)")
                                    .font(.system(size: 10, weight: .semibold).monospacedDigit())
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            Spacer()
                            StatusPill(status: agent.status)
                        }
                        Text(agent.action)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1).truncationMode(.middle)
                        ContextBar(agent: agent, width: 110)
                        HStack(spacing: 12) {
                            Metric(icon: "dollarsign.circle", text: Format.cost(agent.cost))
                            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                                Metric(icon: "clock", text: Format.runtime(ctx.date.timeIntervalSince(agent.startedAt)))
                            }
                        }
                    }
                }
                .padding(8)
                .frame(height: 84)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(agent.status == .needsInput ? agent.status.color.opacity(0.45) : .white.opacity(0.05)))
            }
        }
        .padding(.top, 6)
        .padding(.horizontal, 12)
        .padding(.bottom, 14)
    }
}

// MARK: - Components

struct StatusDot: View {
    let status: AgentStatus
    var size: CGFloat = 8

    var body: some View {
        Circle()
            .fill(status.color)
            .frame(width: size, height: size)
            .shadow(color: status.color.opacity(0.7), radius: 2)
    }
}

struct StatusPill: View {
    let status: AgentStatus
    var body: some View {
        Text(status.label)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(status.color)
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(status.color.opacity(0.16), in: Capsule())
    }
}

struct Metric: View {
    let icon: String
    let text: String
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 9.5, weight: .semibold))
            Text(text).font(.system(size: 11, weight: .medium).monospacedDigit())
        }
        .foregroundStyle(.white.opacity(0.5))
    }
}

extension AgentStatus {
    var color: Color {
        switch self {
        case .working: Color(red: 0.20, green: 0.84, blue: 0.42)
        case .needsInput: Color(red: 1.00, green: 0.71, blue: 0.16)
        case .stuck: Color(red: 1.00, green: 0.30, blue: 0.28)
        case .idle: Color(white: 0.55)
        }
    }

    var label: String {
        switch self {
        case .working: "Working"
        case .needsInput: "Needs you"
        case .stuck: "Stuck"
        case .idle: "Idle"
        }
    }
}

enum Format {
    static func cost(_ v: Double) -> String { String(format: "$%.2f", v) }

    static func tokens(_ n: Int) -> String {
        n >= 1_000_000 ? String(format: "%.2fM", Double(n) / 1e6)
            : n >= 100_000 ? String(format: "%.0fk", Double(n) / 1e3)
            : n >= 1_000 ? String(format: "%.1fk", Double(n) / 1e3) : "\(n)"
    }

    static func runtime(_ s: TimeInterval) -> String {
        let t = Int(max(0, s))
        return t >= 3600 ? String(format: "%d:%02d:%02d", t / 3600, t / 60 % 60, t % 60)
            : String(format: "%d:%02d", t / 60, t % 60)
    }
}

/// The oldest pending request as an approval card; shared by the alert state and
/// the Diorama footer.
struct PendingApprovalCard: View {
    let store: AgentStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let pending = store.pendingRequests
        ZStack {
            if let first = pending.first {
                ApprovalCard(agent: first.agent, request: first.request, queued: pending.count,
                             onDeny: { decide { store.deny(first.agent.id) } },
                             onAllow: { decide { store.approve(first.agent.id) } })
                    .id(first.request.id)     // a new request is a new card
                    .transition(.blurRise(reduce: reduceMotion))
            }
        }
    }

    private func decide(_ action: () -> Void) {
        withAnimation(.spring(duration: 0.3, bounce: 0)) { action() }
    }
}
