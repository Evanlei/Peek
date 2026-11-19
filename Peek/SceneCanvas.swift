import SwiftUI
import SpriteKit

enum SceneStyle: String, CaseIterable, Identifiable {
    case stage, diorama, lanes
    var id: String { rawValue }
    var title: String {
        switch self {
        case .stage: "Stage + list"
        case .diorama: "Diorama"
        case .lanes: "Lanes"
        }
    }
}

/// Lets offscreen renders (previews, GIF export) drive the scene clock.
private struct SceneClockKey: EnvironmentKey { static let defaultValue: Date? = nil }
extension EnvironmentValues {
    var sceneClock: Date? {
        get { self[SceneClockKey.self] }
        set { self[SceneClockKey.self] = newValue }
    }
}

/// Draws a group of critters on a floor. Layout decides each agent's lane.
struct SceneCanvas: View {
    enum Labels { case none, nameBelow, nameAndContextAbove }

    let agents: [Agent]
    let sim: SceneSim
    var pixel: CGFloat = 3
    var wander = true
    var labels: Labels = .none
    var showFloor = true
    var showSidekicks = true
    /// Tiny mode (collapsed strip): overlays sit beside the head, not above it.
    var compact = false
    /// Give each agent a desk with a monitor (diorama).
    var desks = false
    /// Lane for each agent, in the canvas's coordinate space. Defaults to the full width.
    var lane: ((Agent, CGSize) -> ClosedRange<CGFloat>)? = nil
    var frameRate: Double = 60

    @Environment(\.sceneClock) private var clock
    @Environment(\.accessibilityReduceMotion) private var envReduceMotion
    /// Snapshot of Reduce Motion taken in `body`; SpriteKit's loop can't read @Environment.
    private var motionReduced = false

    var body: some View {
        var snapshot = self
        snapshot.motionReduced = envReduceMotion
        return Group {
        if let clock {
            // Offscreen renders (previews/GIFs): plain Canvas at a fixed clock.
            Canvas { ctx, size in
                var b = CanvasBlitter(ctx: ctx)
                snapshot.render(into: &b, size: size, now: clock.timeIntervalSinceReferenceDate)
            }
        } else {
            // Live: SpriteKit draws on the GPU and runs its own frame loop, so ticks
            // never invalidate the SwiftUI window (Canvas cost ~8–13% CPU here).
            SpriteSceneView(scene: snapshot, framesPerSecond: Int(frameRate))
        }
        }
    }

    @MainActor
    func render(into b: inout some Blitter, size: CGSize, now: Double) {
            let p = pixel
            let floorY = size.height - (labels == .nameBelow ? 14 : 4)
            let margin = p * 7
            // Default: each agent owns an equal slice of the floor, so nobody piles up.
            let n = CGFloat(max(agents.count, 1))
            let slice = size.width / n
            func laneFor(_ agent: Agent) -> ClosedRange<CGFloat> {
                if let lane { return lane(agent, size) }
                let i = CGFloat(agents.firstIndex(where: { $0.id == agent.id }) ?? 0)
                let lo = i * slice + margin, hi = (i + 1) * slice - margin
                return lo...max(lo, hi)
            }
            // Desk sits in the left part of the slice; the critter types standing just left of it.
            func deskFor(_ agent: Agent) -> CGFloat? {
                guard desks else { return nil }
                return laneFor(agent).lowerBound + p * 2
            }
            sim.step(now: now, agents: agents, lane: laneFor, desk: deskFor,
                     config: .init(wander: wander, reduceMotion: motionReduced, pixel: p))

            if desks {
                for agent in agents {
                    guard let d = deskFor(agent) else { continue }
                    drawDesk(into: &b, x: d + p * 9, floorY: floorY, p: p, agent: agent, now: now)
                }
            }

            if showFloor {
                let w = size.width - 8
                let img = SpriteCache.image("floor-\(w)", size: CGSize(width: w, height: 1)) { cg in
                    cg.setFillColor(Color.white.opacity(0.09).cg)
                    for x in stride(from: CGFloat(0), to: w, by: 5) { cg.fill(CGRect(x: x, y: 0, width: 2, height: 1)) }
                }
                b.topLeft(img, at: CGPoint(x: 4, y: floorY))
            }

            // Back-to-front: sidekicks, then main characters, then overlays.
            if showSidekicks {
                for agent in agents {
                    for s in agent.subagents {
                        guard let k = sim.sidekicks[s.id] else { continue }
                        let pose = sim.sidekickPose(parent: agent, actor: k, now: now, reduceMotion: motionReduced)
                        Critter.draw(pose, into: &b, feet: CGPoint(x: k.x, y: floorY - k.hop), pixel: p * 0.6)
                    }
                }
            }
            for agent in agents {
                guard let a = sim.actors[agent.id] else { continue }
                let feet = CGPoint(x: a.x, y: floorY - a.hop)
                let pose = sim.pose(for: agent, actor: a, now: now, reduceMotion: motionReduced)
                if a.typing && pixel >= 2 && !desks {
                    Critter.drawLaptop(into: &b, feet: CGPoint(x: a.x, y: floorY), pixel: p,
                                       facing: pose.flipped ? -1 : 1, glow: Int(now * 2) % 2 == 0)
                }
                if compact && agent.status == .needsInput {
                    // No room for a bubble in the strip: a warm halo does the shouting.
                    let rad = 9 * p
                    let img = SpriteCache.image("glow-\(rad)", size: CGSize(width: rad * 2, height: rad * 2)) { cg in
                        let colors = [AgentStatus.needsInput.color.opacity(0.55).cg, Color.clear.cg] as CFArray
                        let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors, locations: [0, 1])!
                        cg.drawRadialGradient(g, startCenter: CGPoint(x: rad, y: rad), startRadius: 0,
                                              endCenter: CGPoint(x: rad, y: rad), endRadius: rad, options: [])
                    }
                    b.centered(img, at: CGPoint(x: a.x, y: floorY - 5 * p))
                }
                Critter.draw(pose, into: &b, feet: feet, pixel: p)

                let head = CGPoint(x: a.x, y: feet.y - 10 * p)
                if compact { continue }
                switch agent.status {
                case .needsInput:
                    Critter.drawAlert(into: &b, at: head, pixel: p, color: AgentStatus.needsInput.color)
                case .stuck:
                    Critter.drawCloud(into: &b, at: head, pixel: p, t: now, animate: !motionReduced)
                case .idle:
                    Critter.drawZ(into: &b, at: head, pixel: p, t: now, animate: !motionReduced)
                case .working:
                    break
                }

                // Keep labels fully inside the scene even when a character hugs the edge.
                func clampX(_ img: CGImage) -> CGFloat {
                    let half = CGFloat(img.width) / SpriteCache.scale / 2 + 4
                    return min(max(a.x, half), max(half, size.width - half))
                }
                switch labels {
                case .none: break
                case .nameBelow:
                    let name = SpriteCache.text(agent.displayName, size: 9.5, weight: .medium, color: .white.opacity(0.55))
                    b.centered(name, at: CGPoint(x: clampX(name), y: floorY + 8))
                case .nameAndContextAbove:
                    let top = head.y - (agent.status == .working ? 6 : 20)
                    let name = SpriteCache.text(agent.displayName, size: 10, weight: .semibold, color: .white.opacity(0.85))
                    let lx = clampX(name)
                    b.centered(name, at: CGPoint(x: lx, y: top - 10))
                    let w: CGFloat = 34
                    let step = Int((agent.contextFraction * 50).rounded())   // 2% steps → few cached images
                    let f = Double(step) / 50
                    let img = SpriteCache.image("ctxbar-\(step)", size: CGSize(width: w, height: 3)) { cg in
                        cg.setFillColor(Color.white.opacity(0.12).cg)
                        cg.addPath(CGPath(roundedRect: CGRect(x: 0, y: 0, width: w, height: 3), cornerWidth: 1.5, cornerHeight: 1.5, transform: nil))
                        cg.fillPath()
                        if f > 0 {
                            cg.setFillColor(ContextBar.color(f).cg)
                            cg.addPath(CGPath(roundedRect: CGRect(x: 0, y: 0, width: max(3, w * f), height: 3), cornerWidth: 1.5, cornerHeight: 1.5, transform: nil))
                            cg.fillPath()
                        }
                    }
                    b.topLeft(img, at: CGPoint(x: lx - w / 2, y: top - 3))
                }
            }
    }
}

extension SceneCanvas {
    /// Pixel desk + monitor whose screen glows with the agent's state.
    @MainActor
    func drawDesk(into b: inout some Blitter, x: CGFloat, floorY: CGFloat, p: CGFloat, agent: Agent, now: Double) {
        // Animation is quantized into a handful of frames so every variant is cached.
        let frame: Int
        switch agent.status {
        case .working: frame = motionReduced ? 0 : Int(now * 4) % 6
        case .stuck: frame = motionReduced ? 0 : Int(now * 2) % 2
        default: frame = 0
        }
        let status = agent.status
        let reduce = motionReduced
        let img = SpriteCache.image("desk-\(p)-\(status.rawValue)-\(frame)-\(reduce)",
                                    size: CGSize(width: 10 * p, height: 11 * p)) { cg in
            cg.setShouldAntialias(false)
            // Local coords: desk's left edge at c = -1 → x = 0; floor at y = 11p.
            func r(_ c: CGFloat, _ row: CGFloat, _ w: CGFloat, _ h: CGFloat, _ color: Color) {
                cg.setFillColor(color.cg)
                cg.fill(CGRect(x: (c + 1) * p, y: (11 - row) * p, width: w * p, height: h * p))
            }
            let wood = Color(white: 0.28)
            r(-1, 5, 9, 1, wood)
            r(-1, 4, 1, 4, wood.opacity(0.8))
            r(7, 4, 1, 4, wood.opacity(0.8))
            r(1, 10, 6, 4, Color(white: 0.2))
            r(3.5, 6, 1, 1, Color(white: 0.2))
            let screen: Color
            switch status {
            case .working: screen = Color(red: 0.45, green: 0.8, blue: 1).opacity(reduce ? 0.8 : 0.65 + 0.25 * sin(Double(frame) / 6 * 2 * .pi))
            case .needsInput: screen = AgentStatus.needsInput.color
            case .stuck: screen = AgentStatus.stuck.color.opacity(frame == 0 ? 0.9 : 0.5)
            case .idle: screen = Color(white: 0.12)
            }
            r(1.5, 9.5, 5, 3, screen)
            if status == .working && !reduce {   // scrolling "code" lines
                let off = frame % 3
                for i in 0..<2 {
                    let w = CGFloat([3, 2, 4][(off + i) % 3])
                    r(2, 9 - CGFloat(i) * 1.2, w * 0.8, 0.5, .white.opacity(0.55))
                }
            }
        }
        b.topLeft(img, at: CGPoint(x: x - p, y: floorY - 11 * p))
    }
}

/// Precise context-window readout: "142k / 200k" with a colored bar.
struct ContextBar: View {
    let agent: Agent
    var width: CGFloat = 84
    var showLabel = true

    static func color(_ f: Double) -> Color {
        f >= 0.9 ? Color(red: 1, green: 0.36, blue: 0.3)
            : f >= 0.8 ? Color(red: 1, green: 0.62, blue: 0.25)
            : f >= 0.6 ? Color(red: 1, green: 0.82, blue: 0.35)
            : Color(red: 0.45, green: 0.85, blue: 0.95)
    }

    var body: some View {
        HStack(spacing: 6) {
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.1))
                Capsule().fill(Self.color(agent.contextFraction))
                    .frame(width: width * agent.contextFraction)
            }
            .frame(width: width, height: 4)
            .animation(.easeOut(duration: 0.25), value: agent.contextFraction)
            if showLabel {
                Text("\(Format.tokens(agent.contextTokens)) / \(Format.tokens(agent.contextLimit))")
                    .font(.system(size: 10, weight: .medium).monospacedDigit())
                    .foregroundStyle(.white.opacity(agent.isTired ? 0.85 : 0.5))
            }
        }
    }
}

/// Hosts SwiftUI content in a separate NSHostingView so its invalidations stay local.
/// Display-only: clicks fall through to the parent (context menu, buttons).
struct IsolatedHost<Content: View>: NSViewRepresentable {
    let content: Content

    final class PassthroughHost: NSHostingView<Content> {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }

    func makeNSView(context: Context) -> PassthroughHost {
        let v = PassthroughHost(rootView: content)
        v.sizingOptions = []
        return v
    }

    func updateNSView(_ nsView: PassthroughHost, context: Context) {
        nsView.rootView = content
    }
}

// MARK: - SpriteKit host

/// Pool of sprite nodes refilled in draw order every frame.
@MainActor
final class SpritePool {
    private var nodes: [SKSpriteNode] = []
    private var used = 0
    private var textures: [ObjectIdentifier: SKTexture] = [:]
    weak var parent: SKNode?
    var height: CGFloat = 0

    func begin(height: CGFloat) { used = 0; self.height = height }

    func end() {
        for i in used..<nodes.count { nodes[i].isHidden = true }
    }

    func blit(_ img: CGImage, rect: CGRect, opacity: Double) {
        if used == nodes.count {
            let n = SKSpriteNode()
            n.anchorPoint = CGPoint(x: 0, y: 1)   // top-left, like the Canvas path
            parent?.addChild(n)
            nodes.append(n)
        }
        let n = nodes[used]
        n.zPosition = CGFloat(used)
        used += 1
        let key = ObjectIdentifier(img)          // cached images are immortal → stable identity
        let tex = textures[key] ?? {
            let t = SKTexture(cgImage: img)
            t.filteringMode = .nearest
            textures[key] = t
            return t
        }()
        if n.texture !== tex { n.texture = tex }
        n.size = rect.size
        n.position = CGPoint(x: rect.minX, y: height - rect.minY)   // flip to SpriteKit's y-up
        n.alpha = opacity
        n.isHidden = false
    }
}

struct PoolBlitter: Blitter {
    let pool: SpritePool
    mutating func blit(_ img: CGImage, rect: CGRect, opacity: Double) {
        pool.blit(img, rect: rect, opacity: opacity)
    }
}

final class PeekSKScene: SKScene {
    var content: SceneCanvas?
    private let pool = SpritePool()

    override func didMove(to view: SKView) {
        backgroundColor = .clear
        scaleMode = .resizeFill
        pool.parent = self
    }

    override func update(_ currentTime: TimeInterval) {
        MainActor.assumeIsolated {
            guard let content else { return }
            pool.begin(height: size.height)
            var b = PoolBlitter(pool: pool)
            content.render(into: &b, size: size, now: Date().timeIntervalSinceReferenceDate)
            pool.end()
        }
    }
}

/// Transparent, click-through SKView hosting a scene.
struct SpriteSceneView: NSViewRepresentable {
    let scene: SceneCanvas
    let framesPerSecond: Int

    final class PassthroughSKView: SKView {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }

    func makeNSView(context: Context) -> PassthroughSKView {
        let v = PassthroughSKView()
        v.allowsTransparency = true
        v.ignoresSiblingOrder = true      // we set zPosition explicitly
        let s = PeekSKScene(size: CGSize(width: 10, height: 10))
        s.content = scene
        v.presentScene(s)
        v.preferredFramesPerSecond = framesPerSecond
        return v
    }

    func updateNSView(_ v: PassthroughSKView, context: Context) {
        (v.scene as? PeekSKScene)?.content = scene     // fresh agent snapshot
        if v.preferredFramesPerSecond != framesPerSecond { v.preferredFramesPerSecond = framesPerSecond }
    }
}
