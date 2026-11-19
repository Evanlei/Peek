import AppKit

/// Everything the panel and views need to know about where the notch is.
struct NotchGeometry: Equatable {
    /// true when the screen has a physical camera housing.
    let hasNotch: Bool
    /// The screen we're attached to, in global screen coordinates.
    let screenFrame: CGRect
    /// Physical notch size (or a virtual one for the floating pill).
    let notchWidth: CGFloat
    let notchHeight: CGFloat
    /// Distance from the top of the screen to the top of our shape.
    /// 0 on a notched Mac (we hang off the top edge), below the menu bar otherwise.
    let topInset: CGFloat

    static let wing: CGFloat = 96          // room each side of the notch for critters / cost
    static let maxAgents = 6
    static let slot: CGFloat = 20          // collapsed-strip spacing per critter

    /// The black "ears" that flare out where the shape meets the top bezel.
    var topCornerRadius: CGFloat { hasNotch ? 8 : 0 }

    var collapsedSize: CGSize {
        CGSize(width: notchWidth + Self.wing * 2, height: notchHeight)
    }

    /// Auto-peek: the strip plus one approval card (card 42 + 6 above + 10 below).
    var alertSize: CGSize {
        CGSize(width: max(460, collapsedSize.width), height: notchHeight + 6 + 42 + 10)
    }

    func expandedSize(style: SceneStyle, agentCount: Int) -> CGSize {
        let n = CGFloat(max(1, min(agentCount, Self.maxAgents)))
        let h: CGFloat
        let w: CGFloat
        switch style {
        case .stage:
            w = 470
            h = notchHeight + 92 + n * 38 + 14
        case .diorama:
            w = 540
            h = notchHeight + 88 + 42 + 16
        case .lanes:
            w = 470
            h = notchHeight + 6 + n * 84 + (n - 1) * 8 + 14
        }
        return CGSize(width: max(w, collapsedSize.width), height: h)
    }

    /// Sized to the current style's largest state; SwiftUI draws the animated shape
    /// inside it and the rest stays transparent. Kept tight because the whole
    /// surface is re-rasterized on redraw.
    func panelSize(style: SceneStyle) -> CGSize {
        let e = expandedSize(style: style, agentCount: Self.maxAgents)
        return CGSize(width: e.width + 60, height: topInset + e.height + 40)
    }

    func panelFrame(style: SceneStyle) -> CGRect {
        let size = panelSize(style: style)
        return CGRect(x: screenFrame.midX - size.width / 2,
                      y: screenFrame.maxY - size.height,
                      width: size.width, height: size.height)
    }

    /// Rect (global coordinates) occupied by the shape at a given size.
    func shapeRect(size: CGSize) -> CGRect {
        CGRect(x: screenFrame.midX - size.width / 2,
               y: screenFrame.maxY - topInset - size.height,
               width: size.width, height: size.height)
    }

    // MARK: - Detection

    static func current(forcePill: Bool = false) -> NotchGeometry {
        let screens = NSScreen.screens
        let notched = screens.first { $0.safeAreaInsets.top > 0 }
        if !forcePill, let screen = notched,
           let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea {
            let frame = screen.frame
            let width = frame.width - left.width - right.width
            return NotchGeometry(hasNotch: true, screenFrame: frame,
                                 notchWidth: width,
                                 notchHeight: screen.safeAreaInsets.top,
                                 topInset: 0)
        }

        // Fallback: floating pill centered just under the menu bar.
        let screen = NSScreen.main ?? screens.first!
        let frame = screen.frame
        let menuBar = max(frame.maxY - screen.visibleFrame.maxY, 24)
        return NotchGeometry(hasNotch: false, screenFrame: frame,
                             notchWidth: 40, notchHeight: 32,
                             topInset: menuBar + 6)
    }
}
