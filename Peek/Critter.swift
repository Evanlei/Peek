import SwiftUI

/// An original 12×11 pixel creature, drawn procedurally so every state is
/// just a different set of pixels — no sprite assets.
struct CritterPose: Hashable {
    enum Eyes { case open, blink, focus, wide, cross, tired, sleep }
    enum Arms { case rest, typeA, typeB, waveUp, waveDown }

    var step: Int? = nil          // walk frame 0/1, nil when standing
    var eyes: Eyes = .open
    var arms: Arms = .rest
    var slump = false
    var sweat = false
    var antennaLit = false
    var flipped = false
    var body: Color = Critter.orange
}

enum Critter {
    static let cols = 12
    static let rows = 11
    static let orange = Color(red: 0.85, green: 0.47, blue: 0.34)
    static let stuckRed = Color(red: 0.86, green: 0.33, blue: 0.30)
    static let ink = Color(red: 0.16, green: 0.10, blue: 0.08)
    static let blush = Color(red: 0.97, green: 0.62, blue: 0.55)
    static let spark = Color(red: 1.0, green: 0.86, blue: 0.45)
    static let sweatBlue = Color(red: 0.55, green: 0.80, blue: 1.0)

    /// Draws with the sprite's feet resting on `feet` (bottom-center).
    /// Each distinct pose is rasterized once; per-frame cost is one image blit.
    @MainActor
    static func draw(_ pose: CritterPose, into b: inout some Blitter, feet: CGPoint, pixel p: CGFloat) {
        let img = SpriteCache.image(SpriteKey(pose: pose, pixel: p),
                                    size: CGSize(width: CGFloat(cols) * p, height: CGFloat(rows) * p)) { cg in
            rasterize(pose, pixel: p, into: cg)
        }
        b.topLeft(img, at: CGPoint(x: feet.x - CGFloat(cols) * p / 2, y: feet.y - 10 * p))
    }

    private struct SpriteKey: Hashable { let pose: CritterPose; let pixel: CGFloat }

    private static func rasterize(_ pose: CritterPose, pixel p: CGFloat, into cg: CGContext) {
        cg.setShouldAntialias(false)
        func px(_ c: Int, _ r: Int, _ color: Color) {
            let col = pose.flipped ? cols - 1 - c : c
            cg.setFillColor(color.cg)
            cg.fill(CGRect(x: CGFloat(col) * p, y: CGFloat(r) * p, width: p, height: p))
        }
        let top = pose.slump ? 3 : 2          // body's first row
        let shade = pose.body.opacity(0.78)

        // Antenna (droops when slumped)
        if pose.slump {
            px(5, 2, pose.body); px(6, 2, pose.body.opacity(0.6))
        } else {
            px(5, 1, pose.body)
            px(5, 0, pose.antennaLit ? spark : pose.body.opacity(0.7))
        }

        // Body: rounded bean
        for c in 2...9 { px(c, top, pose.body) }
        for r in (top + 1)...(top + 5) { for c in 1...10 { px(c, r, pose.body) } }
        for c in 2...9 { px(c, top + 6, shade) }

        // Feet
        let feetRow = 9
        if pose.slump {
            for c in [1, 2, 9, 10] { px(c, feetRow, shade) }
        } else {
            switch pose.step {
            case 0?:  for c in [1, 2, 7, 8] { px(c, feetRow, shade) }
            case 1?:  for c in [3, 4, 9, 10] { px(c, feetRow, shade) }
            default:  for c in [2, 3, 8, 9] { px(c, feetRow, shade) }
            }
        }

        // Arms
        let armRow = top + 4
        switch pose.arms {
        case .rest:     px(0, armRow, pose.body); px(11, armRow, pose.body)
        case .typeA:    px(0, armRow, pose.body); px(11, armRow - 1, pose.body)
        case .typeB:    px(0, armRow - 1, pose.body); px(11, armRow, pose.body)
        case .waveUp:   px(0, armRow, pose.body); px(11, top, pose.body); px(11, top - 1, pose.body)
        case .waveDown: px(0, armRow, pose.body); px(11, top + 1, pose.body); px(11, top, pose.body)
        }

        // Face
        let e = top + 2
        switch pose.eyes {
        case .open:
            for r in [e, e + 1] { px(3, r, ink); px(8, r, ink) }
        case .focus:
            for r in [e + 1, e + 2] { px(3, r, ink); px(8, r, ink) }
        case .blink, .sleep:
            for c in [2, 3, 8, 9] { px(c, e + 1, ink) }
        case .wide:
            for r in [e, e + 1] { for c in [2, 3, 8, 9] { px(c, r, ink) } }
            px(5, e + 3, ink); px(6, e + 3, ink)
        case .cross:
            for (c, r) in [(2, e), (4, e), (3, e + 1), (2, e + 2), (4, e + 2),
                           (7, e), (9, e), (8, e + 1), (7, e + 2), (9, e + 2)] { px(c, r, ink) }
        case .tired:
            for c in [2, 3, 4, 7, 8, 9] { px(c, e + 1, ink) }
            px(3, e + 2, ink); px(8, e + 2, ink)
        }
        if [.open, .focus, .wide, .blink].contains(pose.eyes) {
            px(1, e + 3, blush); px(10, e + 3, blush)
        }

        if pose.sweat {
            px(0, top, sweatBlue); px(0, top + 1, sweatBlue.opacity(0.7))
        }
    }

    /// Tiny laptop placed in front of a typing critter.
    @MainActor
    static func drawLaptop(into b: inout some Blitter, feet: CGPoint, pixel p: CGFloat, facing: CGFloat, glow: Bool) {
        let img = SpriteCache.image("laptop-\(p)-\(facing > 0)-\(glow)", size: CGSize(width: 5 * p, height: 4 * p)) { cg in
            cg.setFillColor(Color(white: 0.55).cg)
            cg.fill(CGRect(x: 0, y: 3 * p, width: 5 * p, height: p))
            let sx = facing > 0 ? 4 * p : 0
            cg.setFillColor(Color(white: 0.4).cg)
            cg.fill(CGRect(x: sx, y: 0, width: p, height: 3 * p))
            if glow {
                cg.setFillColor(Color(red: 0.5, green: 0.85, blue: 1).opacity(0.8).cg)
                cg.fill(CGRect(x: sx, y: p * 0.5, width: p, height: 2 * p))
            }
        }
        b.topLeft(img, at: CGPoint(x: feet.x + facing * 7.5 * p - 2.5 * p, y: feet.y - 4 * p))
    }

    /// Amber "!" bubble for needs-input.
    @MainActor
    static func drawAlert(into b: inout some Blitter, at head: CGPoint, pixel p: CGFloat, color: Color) {
        let w = max(9, p * 3.4), h = max(11, p * 4)
        let img = SpriteCache.image("alert-\(p)", size: CGSize(width: w, height: h)) { cg in
            cg.setFillColor(color.cg)
            cg.addPath(CGPath(roundedRect: CGRect(x: 0, y: 0, width: w, height: h),
                              cornerWidth: w / 2.5, cornerHeight: w / 2.5, transform: nil))
            cg.fillPath()
            // "!" as two blocks — reads crisply at this size and needs no text layout.
            cg.setFillColor(Color.black.opacity(0.85).cg)
            let bw = max(1.6, w * 0.2)
            cg.fill(CGRect(x: (w - bw) / 2, y: h * 0.18, width: bw, height: h * 0.42))
            cg.fill(CGRect(x: (w - bw) / 2, y: h * 0.68, width: bw, height: bw))
        }
        b.topLeft(img, at: CGPoint(x: head.x - w / 2, y: head.y - h - p))
    }

    /// Little grey cloud with flickering rain for "stuck".
    @MainActor
    static func drawCloud(into b: inout some Blitter, at head: CGPoint, pixel p: CGFloat, t: Double, animate: Bool) {
        let q = p * 0.8
        let frame = animate ? Int(t * 5) % 2 : 0
        let img = SpriteCache.image("cloud-\(p)-\(frame)", size: CGSize(width: 8 * q, height: 6 * q)) { cg in
            cg.setShouldAntialias(false)
            cg.setFillColor(Color(white: 0.62).cg)
            let shape: [(Int, Int)] = [(2, 0), (3, 0), (5, 0), (1, 1), (2, 1), (3, 1), (4, 1), (5, 1), (6, 1),
                                       (0, 2), (1, 2), (2, 2), (3, 2), (4, 2), (5, 2), (6, 2), (7, 2)]
            for (c, r) in shape { cg.fill(CGRect(x: CGFloat(c) * q, y: CGFloat(r) * q, width: q, height: q)) }
            cg.setFillColor(sweatBlue.opacity(0.8).cg)
            for c in stride(from: 1 + frame, to: 8, by: 2) {
                cg.fill(CGRect(x: CGFloat(c) * q, y: CGFloat(4 + (c + frame) % 2) * q, width: q * 0.6, height: q))
            }
        }
        b.topLeft(img, at: CGPoint(x: head.x - 4 * q, y: head.y - 5 * q))
    }

    /// Floating "z" for idle.
    @MainActor
    static func drawZ(into b: inout some Blitter, at head: CGPoint, pixel p: CGFloat, t: Double, animate: Bool) {
        let c = animate ? (t.truncatingRemainder(dividingBy: 2.4)) / 2.4 : 0.5
        let img = SpriteCache.text("z", size: max(7, p * 3), weight: .bold, color: .white.opacity(0.7))
        b.centered(img, at: CGPoint(x: head.x + p * 4 + c * p * 2, y: head.y - p - c * p * 5),
                                 opacity: 1 - c * 0.8)
    }
}
