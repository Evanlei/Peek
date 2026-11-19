import SwiftUI

/// Rasterize-once cache for everything the scene draws. Canvas re-runs every
/// frame and rasterizes on the CPU, so per-frame work must be image blits only.
@MainActor
enum SpriteCache {
    static let scale: CGFloat = 2
    private static var images: [AnyHashable: CGImage] = [:]

    /// Draw closure gets a top-left-origin context in points.
    static func image(_ key: AnyHashable, size: CGSize, draw: (CGContext) -> Void) -> CGImage {
        if let hit = images[key] { return hit }
        let w = max(1, Int((size.width * scale).rounded(.up)))
        let h = max(1, Int((size.height * scale).rounded(.up)))
        let cg = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                           space: CGColorSpace(name: CGColorSpace.sRGB)!,
                           bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        cg.translateBy(x: 0, y: CGFloat(h))
        cg.scaleBy(x: scale, y: -scale)
        draw(cg)
        let img = cg.makeImage()!
        images[key] = img
        return img
    }

    /// Text rendered once via SwiftUI (so it matches the rest of the UI).
    static func text(_ string: String, size: CGFloat, weight: Font.Weight, color: Color) -> CGImage {
        let key = AnyHashable(["text", string, "\(size)", "\(weight)", "\(color)"])
        if let hit = images[key] { return hit }
        let r = ImageRenderer(content: Text(string)
            .font(.system(size: size, weight: weight, design: .rounded))
            .foregroundStyle(color)
            .fixedSize())
        r.scale = scale
        let img = r.cgImage!
        images[key] = img
        return img
    }
}

/// Immediate-mode sink for cached images. The scene code draws through this, so the
/// same code renders into a SwiftUI Canvas (previews) or SpriteKit nodes (live, GPU).
@MainActor
protocol Blitter {
    mutating func blit(_ img: CGImage, rect: CGRect, opacity: Double)
}

extension Blitter {
    mutating func topLeft(_ img: CGImage, at p: CGPoint, opacity: Double = 1) {
        let size = CGSize(width: CGFloat(img.width) / SpriteCache.scale, height: CGFloat(img.height) / SpriteCache.scale)
        // Snap to the half-point grid so pixels stay crisp on Retina.
        blit(img, rect: CGRect(origin: CGPoint(x: (p.x * 2).rounded() / 2, y: (p.y * 2).rounded() / 2), size: size),
             opacity: opacity)
    }

    mutating func centered(_ img: CGImage, at p: CGPoint, opacity: Double = 1) {
        let w = CGFloat(img.width) / SpriteCache.scale, h = CGFloat(img.height) / SpriteCache.scale
        topLeft(img, at: CGPoint(x: p.x - w / 2, y: p.y - h / 2), opacity: opacity)
    }
}

struct CanvasBlitter: Blitter {
    var ctx: GraphicsContext
    mutating func blit(_ img: CGImage, rect: CGRect, opacity: Double) {
        var c = ctx
        c.opacity = opacity
        c.draw(Image(decorative: img, scale: SpriteCache.scale), in: rect)
    }
}

extension Color {
    var cg: CGColor { NSColor(self).cgColor }
}
