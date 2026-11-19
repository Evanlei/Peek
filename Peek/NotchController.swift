import AppKit
import SwiftUI
import Observation

@MainActor
@Observable
final class NotchState {
    var isExpanded = false
    /// Auto-peek: a permission request is waiting, so the notch shows the approval card
    /// without needing a hover (Dynamic Island style).
    var isAlerting = false
    var geometry: NotchGeometry
    var style: SceneStyle {
        didSet { UserDefaults.standard.set(style.rawValue, forKey: "sceneStyle") }
    }
    /// One motion simulation per drawing surface, kept across frames.
    @ObservationIgnored private var sims: [String: SceneSim] = [:]

    init(geometry: NotchGeometry) {
        self.geometry = geometry
        let saved = ProcessInfo.processInfo.environment["PEEK_STYLE"]
            ?? UserDefaults.standard.string(forKey: "sceneStyle")
        style = saved.flatMap(SceneStyle.init(rawValue:)) ?? .diorama
    }

    func sim(_ key: String) -> SceneSim {
        if let s = sims[key] { return s }
        let s = SceneSim()
        sims[key] = s
        return s
    }
}

/// Borderless, non-activating panel that floats above the menu bar.
final class NotchPanel: NSPanel {
    init(frame: CGRect) {
        super.init(contentRect: frame,
                   styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) + 3)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        isMovable = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class NotchController {
    private let store: AgentStore
    private let state: NotchState
    private let panel: NotchPanel
    private var hoverTimer: Timer?
    private var leftAt: Date?
    private let forcePill = ProcessInfo.processInfo.environment["PEEK_FORCE_PILL"] == "1"
    private let pinnedOpen = ProcessInfo.processInfo.environment["PEEK_EXPANDED"] == "1"
    private let pinnedClosed = ProcessInfo.processInfo.environment["PEEK_EXPANDED"] == "0"
    private let recording = ProcessInfo.processInfo.environment["PEEK_RECORD"] != nil

    init(store: AgentStore) {
        self.store = store
        let geometry = NotchGeometry.current(forcePill: forcePill)
        state = NotchState(geometry: geometry)
        panel = NotchPanel(frame: geometry.panelFrame(style: state.style))

        let host = NSHostingView(rootView: AnyView(EmptyView()))
        host.sizingOptions = []
        panel.contentView = host
        installRoot()
        observeStyle()
        panel.ignoresMouseEvents = true
        panel.orderFrontRegardless()

        if pinnedOpen { setExpanded(true) }
        observeRequests()
        #if DEBUG
        scheduleDebugSnapshot()
        scheduleDemoRecording()
        #endif

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.relayout() }
        }

        // Poll the cursor rather than relying on tracking areas: the panel never
        // becomes key and ignores mouse events while collapsed, so this is the
        // most reliable way to get hover from any app. Cost is negligible.
        hoverTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkHover() }
        }
    }

    private func installRoot() {
        let size = state.geometry.panelSize(style: state.style)
        panel.setFrame(state.geometry.panelFrame(style: state.style), display: true)
        if let host = panel.contentView as? NSHostingView<AnyView> {
            host.rootView = AnyView(NotchView(store: store, state: state)
                .frame(width: size.width, height: size.height, alignment: .top))
        }
    }

    /// Re-fit the panel whenever the style changes.
    private func observeStyle() {
        withObservationTracking { _ = state.style } onChange: { [weak self] in
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self?.installRoot()
                    self?.observeStyle()
                }
            }
        }
    }

    /// Open into the alert state when a request arrives; close when none are left.
    private func observeRequests() {
        let pending = withObservationTracking { !store.pendingRequests.isEmpty } onChange: { [weak self] in
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.observeRequests() } }
        }
        guard pending != state.isAlerting else { return }
        // Rare and important: a noticeable but short spring in; no bounce out.
        withAnimation(pending ? .spring(duration: 0.38, bounce: 0.2) : .spring(duration: 0.28, bounce: 0)) {
            state.isAlerting = pending
        }
        updateMouseHandling()
    }

    /// The panel only takes clicks while something clickable is showing.
    private func updateMouseHandling() {
        panel.ignoresMouseEvents = !(state.isExpanded || state.isAlerting)
    }

    private func relayout() {
        let geometry = NotchGeometry.current(forcePill: forcePill)
        guard geometry != state.geometry else { return }
        state.geometry = geometry
        installRoot()
    }

    private func checkHover() {
        guard !pinnedOpen, !pinnedClosed, !recording else { return }
        // While the approval card is up, don't hover-expand: expanding would move the
        // card (and its Allow button) out from under the cursor.
        guard !(state.isAlerting && !state.isExpanded) else { leftAt = nil; return }
        let g = state.geometry
        let mouse = NSEvent.mouseLocation
        let inside: Bool
        if state.isExpanded {
            inside = g.shapeRect(size: g.expandedSize(style: state.style, agentCount: store.agents.count))
                .insetBy(dx: -6, dy: -6).contains(mouse)
        } else {
            // Slightly generous so brushing the notch from below opens it.
            var r = g.shapeRect(size: g.collapsedSize).insetBy(dx: -4, dy: -6)
            r.size.height += 6 // extend above the top edge of the screen
            inside = r.contains(mouse)
        }

        if inside {
            leftAt = nil
            if !state.isExpanded { setExpanded(true) }
        } else if state.isExpanded {
            // Small grace period so the panel doesn't snap shut on a wobble.
            if let t = leftAt {
                if Date().timeIntervalSince(t) > 0.18 { setExpanded(false) }
            } else {
                leftAt = Date()
            }
        }
    }

    private func setExpanded(_ expanded: Bool) {
        // Opened tens of times a day: quick, light bounce in; no bounce out.
        withAnimation(expanded
                      ? .spring(duration: 0.38, bounce: 0.2)
                      : .spring(duration: 0.28, bounce: 0)) {
            state.isExpanded = expanded
        }
        updateMouseHandling()
    }

    #if DEBUG
    /// PEEK_SNAPSHOT=/path.png → capture our own panel (incl. the SpriteKit layer)
    /// after a moment. Own-window capture needs no Screen Recording permission.
    private func scheduleDebugSnapshot() {
        guard let path = ProcessInfo.processInfo.environment["PEEK_SNAPSHOT"] else { return }
        let delay = Double(ProcessInfo.processInfo.environment["PEEK_SNAPSHOT_DELAY"] ?? "") ?? 2.5
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [panel] in
            let id = CGWindowID(panel.windowNumber)
            guard let img = CGWindowListCreateImage(.null, .optionIncludingWindow, id, [.boundsIgnoreFraming, .bestResolution]) else {
                print("snapshot failed"); return
            }
            let rep = NSBitmapImageRep(cgImage: img)
            try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
            print("snapshot written \(img.width)x\(img.height)")
        }
    }

    /// PEEK_RECORD=/dir (with PEEK_FAKE=1) → play a scripted demo and write
    /// the panel as numbered PNG frames for the landing page video.
    /// Timeline: collapsed → hover open → close → request arrives → allowed.
    private func scheduleDemoRecording() {
        guard let dir = ProcessInfo.processInfo.environment["PEEK_RECORD"] else { return }
        store.randomStatusChanges = false
        let gateway = store.agents.firstIndex { $0.project == "api-gateway" }
        if let i = gateway {
            store.agents[i].request = nil
            store.agents[i].status = .working
            store.agents[i].action = "Edit db/migrations/0042.sql"
        }
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let fps = 30.0, length = 12.5
        let start = Date().addingTimeInterval(1.5)   // let the scene settle first
        let id = CGWindowID(panel.windowNumber)
        let writer = DispatchQueue(label: "peek.record")
        var frame = 0
        func at(_ t: Double, _ f: @escaping () -> Void) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5 + t) { MainActor.assumeIsolated(f) }
        }
        at(1.6) { self.setExpanded(true) }
        at(6.4) { self.setExpanded(false) }
        at(7.4) {
            guard let i = gateway else { return }
            self.store.agents[i].status = .needsInput
            self.store.agents[i].action = "Waiting for permission"
            self.store.agents[i].subagents = []
            self.store.agents[i].request = PermissionRequest(tool: "Bash", detail: "npm run migrate")
        }
        at(10.2) { if let i = gateway { self.store.approve(self.store.agents[i].id) } }
        Timer.scheduledTimer(withTimeInterval: 1 / fps, repeats: true) { timer in
            let t = Date().timeIntervalSince(start)
            guard t >= 0 else { return }
            guard t < length else {
                timer.invalidate()
                print("recorded \(frame) frames")
                writer.async { exit(0) }
                return
            }
            guard let img = CGWindowListCreateImage(.null, .optionIncludingWindow, id,
                                                    [.boundsIgnoreFraming, .bestResolution]) else { return }
            let name = String(format: "%@/%05d_%.4f.png", dir, frame, t)
            frame += 1
            writer.async {
                try? NSBitmapImageRep(cgImage: img).representation(using: .png, properties: [:])?
                    .write(to: URL(fileURLWithPath: name))
            }
        }
    }
    #endif
}
