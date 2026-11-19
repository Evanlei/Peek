import Foundation
import Observation

/// Source of agent state. Step 1 drives it with fake data; later steps will
/// feed it from ~/.claude/projects JSONL logs and Claude Code hooks.
@MainActor
@Observable
final class AgentStore {
    /// Mutate statuses/metrics in place; use `replaceAgents` when sessions are
    /// added or removed so display names get recomputed. (A didSet here recurses
    /// under @Observable's generated accessors.)
    var agents: [Agent]

    func replaceAgents(_ new: [Agent]) {
        var named = new
        Agent.assignDisplayNames(&named)
        agents = named
    }
    @ObservationIgnored private var timer: Timer?
    /// Off while recording the scripted demo so nothing changes state at random.
    @ObservationIgnored var randomStatusChanges = true

    /// Fraction of the rolling 5-hour usage window consumed. Plan limits aren't in the
    /// JSONL logs, so live mode leaves this nil and the header hides the ring.
    var windowUsage: Double? = nil
    @ObservationIgnored private var scanner: SessionScanner?
    @ObservationIgnored private var bridge: HookBridge?

    // Live mode: the scanner's snapshot plus pending hook requests overlaid on top.
    @ObservationIgnored private var scanned: [Agent] = []
    private struct LiveRequest {
        let request: PermissionRequest
        let agentID: UUID
        let cwd: String?
        let finish: (HookBridge.Decision) -> Void
    }
    @ObservationIgnored private var liveRequests: [LiveRequest] = []

    func addHookRequest(_ r: PermissionRequest, sessionID: String, cwd: String?,
                        finish: @escaping (HookBridge.Decision) -> Void) {
        liveRequests.append(LiveRequest(request: r, agentID: StableID.uuid(sessionID), cwd: cwd, finish: finish))
        rebuildLive()
    }

    func removeHookRequest(_ id: UUID) {
        liveRequests.removeAll { $0.request.id == id }
        rebuildLive()
    }

    private func rebuildLive() {
        var list = scanned
        for lr in liveRequests {
            if let i = list.firstIndex(where: { $0.id == lr.agentID }) {
                guard list[i].request == nil else { continue }       // one card per agent; rest queue
                list[i].status = .needsInput
                list[i].request = lr.request
                list[i].action = "Waiting for permission"
                list[i].subagents = []
            } else {
                // Session the scanner hasn't picked up yet: show it anyway.
                list.append(Agent(id: lr.agentID,
                                  project: lr.cwd.map(SessionState.projectName(cwd:)) ?? "Claude Code",
                                  status: .needsInput, action: "Waiting for permission", tokens: 0, cost: 0,
                                  startedAt: lr.request.requestedAt, contextTokens: 0, request: lr.request))
            }
        }
        Agent.assignDisplayNames(&list)
        if list != agents { agents = list }
    }

    /// Resolve a live hook request for this agent, if there is one.
    private func resolveLive(_ agentID: UUID, _ decision: HookBridge.Decision) -> Bool {
        guard let i = liveRequests.firstIndex(where: { $0.agentID == agentID }) else { return false }
        let lr = liveRequests.remove(at: i)
        lr.finish(decision)
        rebuildLive()
        return true
    }

    /// Real sessions from ~/.claude/projects (default). `PEEK_FAKE=1` for the demo data.
    static func live() -> AgentStore {
        let store = AgentStore(agents: [])
        let scanner = SessionScanner { agents in
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    store.scanned = agents
                    store.rebuildLive()
                }
            }
        }
        store.scanner = scanner
        scanner.start()
        let bridge = HookBridge(store: store)
        bridge.start()
        store.bridge = bridge
        return store
    }

    var totalCost: Double { agents.reduce(0) { $0 + $1.cost } }
    /// Oldest first — the order you'll be asked.
    var pendingRequests: [(agent: Agent, request: PermissionRequest)] {
        agents.compactMap { a in a.request.map { (a, $0) } }
            .sorted { $0.request.requestedAt < $1.request.requestedAt }
    }

    func approve(_ agentID: UUID) {
        if resolveLive(agentID, .allow) { return }
        guard let i = agents.firstIndex(where: { $0.id == agentID }), let r = agents[i].request else { return }
        agents[i].request = nil
        agents[i].status = .working
        agents[i].action = "\(r.tool): \(r.detail)"
    }

    func deny(_ agentID: UUID) {
        if resolveLive(agentID, .deny) { return }
        guard let i = agents.firstIndex(where: { $0.id == agentID }) else { return }
        agents[i].request = nil
        agents[i].status = .working
        agents[i].action = "Denied — trying another approach"
    }
    var subagentCount: Int { agents.reduce(0) { $0 + $1.subagents.count } }

    init(agents: [Agent]) {
        var named = agents
        Agent.assignDisplayNames(&named)
        self.agents = named
    }

    static func fake(simulate: Bool = true) -> AgentStore {
        let now = Date()
        func sub(_ t: String) -> Subagent { Subagent(id: UUID(), task: t) }
        let store = AgentStore(agents: [
            Agent(id: UUID(), project: "peek", status: .working,
                  action: "Edit NotchView.swift", tokens: 48_210, cost: 0.61,
                  startedAt: now.addingTimeInterval(-14 * 60), contextTokens: 142_000,
                  subagents: [sub("Explore sprite rendering"), sub("Write SceneSim tests")],
                  branch: "main", firstPrompt: "Build the diorama scene"),
            Agent(id: UUID(), project: "peek", status: .working,
                  action: "Read NotchController.swift", tokens: 9_840, cost: 0.12,
                  startedAt: now.addingTimeInterval(-2 * 60 - 5), contextTokens: 22_000,
                  branch: "fix-hover", firstPrompt: "Hover closes too early"),
            Agent(id: UUID(), project: "api-gateway", status: .needsInput,
                  action: "Waiting for permission", tokens: 21_904, cost: 0.37,
                  startedAt: now.addingTimeInterval(-6 * 60 - 12), contextTokens: 88_000,
                  request: PermissionRequest(tool: "Bash", detail: "npm run migrate -- --force")),
            Agent(id: UUID(), project: "landing-site", status: .working,
                  action: "Read src/components/Hero.tsx", tokens: 12_377, cost: 0.19,
                  startedAt: now.addingTimeInterval(-3 * 60 - 40), contextTokens: 34_000,
                  subagents: [sub("Audit image sizes")]),
            Agent(id: UUID(), project: "ml-pipeline", status: .stuck,
                  action: "pytest failing: 3 errors (retry 4/4)", tokens: 30_118, cost: 0.25,
                  startedAt: now.addingTimeInterval(-27 * 60), contextTokens: 176_000),
        ])
        store.windowUsage = 0.41
        if simulate { store.startSimulation() }
        return store
    }

    // MARK: - Fake simulation

    private static let fakeActions = [
        "Read Package.swift", "Grep \"func handle\"", "Edit Sources/Router.swift",
        "Bash: swift test", "Write README.md", "Read tests/test_api.py",
        "Edit app/models/user.rb", "Bash: git diff --stat", "Glob **/*.tsx",
        "Thinking…", "Edit src/lib/cache.ts", "WebFetch docs.swift.org",
    ]
    private static let fakeTasks = [
        "Search for call sites", "Run the test suite", "Review the diff",
        "Explore auth module", "Draft migration", "Check bundle size",
    ]

    private func startSimulation() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    private func tick() {
        for i in agents.indices where agents[i].status == .working {
            let newTokens = Int.random(in: 200...2_400)
            agents[i].tokens += newTokens
            agents[i].cost += Double(newTokens) * 9 / 1_000_000
            agents[i].contextTokens += newTokens / 2
            windowUsage = windowUsage.map { min(1, $0 + Double(newTokens) / 40_000_000) }
            if agents[i].contextFraction > 0.97 {   // pretend auto-compact
                agents[i].contextTokens = agents[i].contextLimit * 3 / 10
                agents[i].action = "Compacting conversation…"
            } else if Int.random(in: 0..<4) == 0 {
                agents[i].action = Self.fakeActions.randomElement()!
            }
            // Subagents come and go.
            if Int.random(in: 0..<10) == 0, agents[i].subagents.count < 3 {
                agents[i].subagents.append(Subagent(id: UUID(), task: Self.fakeTasks.randomElement()!))
            } else if Int.random(in: 0..<12) == 0, !agents[i].subagents.isEmpty {
                agents[i].subagents.removeFirst()
            }
        }
        if randomStatusChanges, Int.random(in: 0..<14) == 0, let i = agents.indices.randomElement() {
            let next = AgentStatus.allCases.randomElement()!
            agents[i].status = next
            switch next {
            case .needsInput:
                agents[i].action = "Waiting for permission"
                agents[i].request = [
                    PermissionRequest(tool: "Bash", detail: "rm -rf build/"),
                    PermissionRequest(tool: "Edit", detail: "src/config/production.ts"),
                    PermissionRequest(tool: "WebFetch", detail: "registry.npmjs.org/left-pad"),
                ].randomElement()!
            case .stuck: agents[i].action = "No progress for 4m — same error repeating"
            case .idle: agents[i].action = "Waiting for your next prompt"
            case .working: agents[i].action = Self.fakeActions.randomElement()!
            }
            if next != .working { agents[i].subagents.removeAll() }
            if next != .needsInput { agents[i].request = nil }
        }
    }
}
