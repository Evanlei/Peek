import SwiftUI

/// Per-character motion state, advanced once per rendered frame.
/// Kept out of SwiftUI state on purpose: it's a tiny game loop, and pushing
/// 60 updates/s through observation would re-render everything.
final class CritterActor {
    var x: CGFloat
    var hop: CGFloat = 0
    var facing: CGFloat = 1
    var target: CGFloat
    var pauseUntil: Double = 0
    var moving = false
    var typing = false
    var headingToDesk = true
    let phase: Double = .random(in: 0..<100)

    init(x: CGFloat) { self.x = x; self.target = x }
}

final class SceneSim {
    private(set) var actors: [UUID: CritterActor] = [:]
    private(set) var sidekicks: [UUID: CritterActor] = [:]
    private var last: Double?

    struct Config {
        var wander: Bool      // free roaming (expanded) vs. fixed slots (collapsed strip)
        var reduceMotion: Bool
        var pixel: CGFloat
    }

    func step(now: Double, agents: [Agent], lane: (Agent) -> ClosedRange<CGFloat>,
              desk: (Agent) -> CGFloat? = { _ in nil }, config: Config) {
        let dt = min(max(now - (last ?? now), 0), 0.1)
        last = now
        let still = config.reduceMotion

        for agent in agents {
            let r = lane(agent)
            let a = actors[agent.id] ?? {
                let start = CGFloat.random(in: r)
                let new = CritterActor(x: start)
                actors[agent.id] = new
                return new
            }()
            a.x = min(max(a.x, r.lowerBound), r.upperBound)
            a.moving = false
            a.typing = false
            a.hop = 0

            switch agent.status {
            case .working where config.wander && !still:
                let deskX = desk(agent)
                if now < a.pauseUntil {
                    // With a desk, only type while sitting at it; elsewhere just look around.
                    a.typing = deskX == nil || !a.headingToDesk
                    if let d = deskX, !a.headingToDesk { a.facing = d + config.pixel * 9 > a.x ? 1 : -1 }
                } else {
                    let dx = a.target - a.x
                    if abs(dx) < 1 {
                        // Arrived. Desk → long typing stint; elsewhere → short pause.
                        let tired = agent.isTired ? 1.7 : 1.0
                        if let d = deskX {
                            let atDesk = a.headingToDesk
                            a.pauseUntil = now + (atDesk ? .random(in: 3...6) : .random(in: 0.8...2)) * tired
                            a.headingToDesk = !atDesk
                            a.target = a.headingToDesk ? d : CGFloat.random(in: r)
                        } else {
                            a.pauseUntil = now + .random(in: 1.6...4.2) * tired
                            a.target = CGFloat.random(in: r)
                        }
                    } else {
                        let speed: CGFloat = (agent.isTired ? 11 : 24) * config.pixel / 3
                        a.x += (dx > 0 ? 1 : -1) * min(abs(dx), speed * CGFloat(dt))
                        a.facing = dx > 0 ? 1 : -1
                        a.moving = true
                    }
                }
            case .working:
                a.typing = !still
            case .needsInput where !still:
                // Purposeful hop: this is the one state that should grab attention.
                let c = (now + a.phase).truncatingRemainder(dividingBy: 1.0)
                a.hop = c < 0.32 ? CGFloat(sin(c / 0.32 * .pi)) * config.pixel * 2 : 0
            default:
                break
            }

            // Sidekicks trail behind their parent, single file.
            for (j, s) in agent.subagents.enumerated() {
                let k = sidekicks[s.id] ?? {
                    let new = CritterActor(x: a.x)
                    sidekicks[s.id] = new
                    return new
                }()
                let gap = config.pixel * 7 + CGFloat(j) * config.pixel * 6
                var desired = a.x - a.facing * gap
                if desired < r.lowerBound - config.pixel * 4 || desired > r.upperBound + config.pixel * 4 {
                    desired = a.x + a.facing * gap   // no room behind — stand in front instead
                }
                let dx = desired - k.x
                if still {
                    k.x = desired
                } else {
                    k.x += dx * CGFloat(min(1, dt * 3.2))
                }
                k.moving = abs(dx) > 1.2 && !still
                if k.moving { k.facing = dx > 0 ? 1 : -1 } else { k.facing = a.facing }
                k.hop = k.moving ? CGFloat(abs(sin(now * 9 + k.phase))) * config.pixel * 0.5 : 0
            }
        }

        let alive = Set(agents.map(\.id))
        actors = actors.filter { alive.contains($0.key) }
        let aliveSubs = Set(agents.flatMap { $0.subagents.map(\.id) })
        sidekicks = sidekicks.filter { aliveSubs.contains($0.key) }
    }

    func pose(for agent: Agent, actor a: CritterActor, now: Double, reduceMotion: Bool) -> CritterPose {
        var pose = CritterPose()
        pose.flipped = a.facing < 0
        pose.sweat = agent.isTired && agent.status != .idle
        let blinking = !reduceMotion && (now + a.phase).truncatingRemainder(dividingBy: 3.7) < 0.13

        switch agent.status {
        case .working:
            if a.moving { pose.step = Int(now * 8 + a.phase) % 2 }
            if a.typing {
                pose.arms = Int(now * 7 + a.phase) % 2 == 0 ? .typeA : .typeB
                pose.eyes = .focus
            }
            if agent.isTired { pose.eyes = .tired }
            if blinking { pose.eyes = .blink }
            pose.antennaLit = reduceMotion || Int(now * 3 + a.phase) % 3 != 0
        case .needsInput:
            pose.eyes = .wide
            pose.flipped = false
            pose.arms = reduceMotion ? .waveUp : (Int(now * 4) % 2 == 0 ? .waveUp : .waveDown)
            pose.antennaLit = true
        case .stuck:
            pose.slump = true
            pose.eyes = .cross
            pose.body = Critter.stuckRed
        case .idle:
            pose.eyes = .sleep
            pose.body = Critter.orange.opacity(0.75)
        }
        return pose
    }

    func sidekickPose(parent: Agent, actor k: CritterActor, now: Double, reduceMotion: Bool) -> CritterPose {
        var pose = CritterPose()
        pose.flipped = k.facing < 0
        pose.body = Color(red: 0.93, green: 0.62, blue: 0.45)
        if k.moving { pose.step = Int(now * 10 + k.phase) % 2 }
        else if parent.status == .working && !reduceMotion {
            pose.arms = Int(now * 6 + k.phase) % 2 == 0 ? .typeA : .typeB
            pose.eyes = .focus
        }
        if !reduceMotion && (now + k.phase).truncatingRemainder(dividingBy: 4.1) < 0.12 { pose.eyes = .blink }
        pose.antennaLit = parent.status == .working
        return pose
    }
}
