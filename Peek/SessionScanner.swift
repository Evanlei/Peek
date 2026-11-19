import Foundation

/// Reads live Claude Code sessions from ~/.claude/projects/**.jsonl.
///
/// - Polls every 2s on a background queue; only files touched within `window` are read.
/// - Each file is parsed incrementally (byte offset), so steady-state cost is tiny.
/// - Everything stays on this Mac: nothing is sent anywhere.
///
/// What the logs can and can't tell us:
/// - ✓ project (cwd), branch, title, model, context size, cost, current tool, subagents
/// - ✗ a pending permission prompt is never written, so "needs you" comes from hooks (step 3)
final class SessionScanner: @unchecked Sendable {
    private let root: URL
    private let window: TimeInterval
    private let queue = DispatchQueue(label: "peek.scanner", qos: .utility)
    private var timer: DispatchSourceTimer?
    private var sessions: [String: SessionState] = [:]      // keyed by file path
    private let onUpdate: @Sendable ([Agent]) -> Void

    init(root: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/projects"),
         window: TimeInterval = 30 * 60,
         onUpdate: @escaping @Sendable ([Agent]) -> Void) {
        self.root = root
        self.window = window
        self.onUpdate = onUpdate
    }

    func start() {
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now(), repeating: 2.0, leeway: .milliseconds(500))
        t.setEventHandler { [weak self] in self?.scan() }
        t.resume()
        timer = t
    }

    /// One synchronous pass (used by tests / the debug dump).
    func scanOnce() -> [Agent] { queue.sync { scanAgents() } }

    private func scan() { onUpdate(scanAgents()) }

    private func scanAgents() -> [Agent] {
        let now = Date()
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.contentModificationDateKey, .isDirectoryKey]
        var live: Set<String> = []

        guard let projectDirs = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: keys) else { return [] }
        for dir in projectDirs {
            guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: keys) else { continue }
            for file in files where file.pathExtension == "jsonl" {
                guard let mod = try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
                      now.timeIntervalSince(mod) < window else { continue }
                let path = file.path
                live.insert(path)
                let state = sessions[path] ?? SessionState(url: file)
                sessions[path] = state
                state.ingestNewBytes()
                state.refreshSubagents(now: now)
            }
        }
        sessions = sessions.filter { live.contains($0.key) }

        return sessions.values
            .compactMap { $0.agent(now: now) }
            .sorted { $0.startedAt < $1.startedAt }       // stable left-to-right order in the scene
    }
}

// MARK: - Per-session state

final class SessionState {
    let url: URL
    private var reader: JSONLReader

    private(set) var sessionId: String
    private var cwd: String?
    private var branch: String?
    private var title: String?
    private var model: String?
    private var startedAt: Date?
    private var lastActivity: Date?

    private var contextTokens = 0
    private var outputByMessage: [String: Int] = [:]
    private var outputTokens: Int { outputByMessage.values.reduce(0, +) }

    // Cost: Claude Code's own `cost-state` total when present, plus our estimate since then.
    private var costByMessage: [String: Double] = [:]
    private var estimateTotal = 0.0
    private var baselineCost: Double?
    private var estimateAtBaseline = 0.0

    // Turn state
    private var pendingTools: [String: (name: String, summary: String, at: Date)] = [:]
    private var lastWasEndTurn = false
    private var consecutiveErrors = 0
    private var interrupted = false

    // Subagents (separate files under <session>/subagents/)
    private var subagentReaders: [String: (reader: JSONLReader, state: SubagentState)] = [:]
    private var activeSubagents: [Subagent] = []

    init(url: URL) {
        self.url = url
        self.reader = JSONLReader(url: url)
        self.sessionId = url.deletingPathExtension().lastPathComponent
    }

    func ingestNewBytes() {
        reader.readNewLines { self.ingest($0) }
    }

    private func ingest(_ d: [String: Any]) {
        let type = d["type"] as? String
        if let c = d["cwd"] as? String { cwd = c }
        if let b = d["gitBranch"] as? String, !b.isEmpty, b != "HEAD" { branch = b }   // HEAD = detached; keep the real one
        if let ts = (d["timestamp"] as? String).flatMap(JSONLReader.parseDate) {
            if startedAt == nil { startedAt = ts }
            if type == "assistant" || type == "user" { lastActivity = max(lastActivity ?? ts, ts) }
        }

        switch type {
        case "ai-title":
            title = d["aiTitle"] as? String
        case "cost-state":
            if let total = d["totalCostUSD"] as? Double {
                baselineCost = total
                estimateAtBaseline = estimateTotal
            }
        case "assistant":
            guard let m = d["message"] as? [String: Any] else { return }
            if let mod = m["model"] as? String, !mod.hasPrefix("<") { model = mod }
            if let u = m["usage"] as? [String: Any] {
                let id = (m["id"] as? String) ?? (d["requestId"] as? String) ?? UUID().uuidString
                let c = Pricing.cost(model: model, usage: u)
                estimateTotal += c - (costByMessage[id] ?? 0)     // records repeat per content block
                costByMessage[id] = c
                // Context = everything the model saw on this request + what it wrote.
                contextTokens = int(u["input_tokens"]) + int(u["cache_creation_input_tokens"])
                    + int(u["cache_read_input_tokens"]) + int(u["output_tokens"])
                outputByMessage[id] = int(u["output_tokens"])
            }
            let blocks = (m["content"] as? [[String: Any]]) ?? []
            for b in blocks where (b["type"] as? String) == "tool_use" {
                if let id = b["id"] as? String, let name = b["name"] as? String {
                    pendingTools[id] = (name, ToolSummary.describe(name: name, input: b["input"] as? [String: Any] ?? [:]),
                                        lastActivity ?? Date())
                }
            }
            if let stop = m["stop_reason"] as? String { lastWasEndTurn = stop == "end_turn" }
            interrupted = false
        case "user":
            guard let m = d["message"] as? [String: Any] else { return }
            if let blocks = m["content"] as? [[String: Any]] {
                for b in blocks {
                    switch b["type"] as? String {
                    case "tool_result":
                        if let id = b["tool_use_id"] as? String { pendingTools[id] = nil }
                        consecutiveErrors = (b["is_error"] as? Bool) == true ? consecutiveErrors + 1 : 0
                    case "text":
                        let t = b["text"] as? String ?? ""
                        if t.hasPrefix("[Request interrupted") { interrupted = true; pendingTools.removeAll() }
                        else if (d["isMeta"] as? Bool) != true { lastWasEndTurn = false; consecutiveErrors = 0 }
                    default: break
                    }
                }
            } else if m["content"] is String, (d["isMeta"] as? Bool) != true {
                lastWasEndTurn = false     // a fresh prompt starts a turn
            }
        default:
            break
        }
    }

    func refreshSubagents(now: Date) {
        let dir = url.deletingPathExtension().appendingPathComponent("subagents")
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.contentModificationDateKey]) else {
            activeSubagents = []
            return
        }
        var active: [Subagent] = []
        for f in files where f.pathExtension == "jsonl" {
            let key = f.lastPathComponent
            var entry = subagentReaders[key] ?? (JSONLReader(url: f), SubagentState())
            entry.reader.readNewLines { entry.state.ingest($0) }
            subagentReaders[key] = entry
            // Subagent cost counts toward the session (baseline + delta keeps it consistent).
            let delta = entry.state.estimate - entry.state.reported
            if delta != 0 { estimateTotal += delta; entry.state.reported = entry.state.estimate; subagentReaders[key] = entry }

            let mod = (try? f.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            if now.timeIntervalSince(mod) < 45, !entry.state.finished {
                active.append(Subagent(id: StableID.uuid(key), task: entry.state.task ?? "Subagent"))
            }
        }
        activeSubagents = active.sorted { $0.id.uuidString < $1.id.uuidString }
    }

    /// Snapshot as an Agent, or nil if there's nothing meaningful to show yet.
    func agent(now: Date) -> Agent? {
        guard let cwd, let startedAt else { return nil }
        let project = Self.projectName(cwd: cwd)
        let last = lastActivity ?? startedAt
        let quiet = now.timeIntervalSince(last)

        var status: AgentStatus
        var action: String
        if let oldest = pendingTools.values.min(by: { $0.at < $1.at }) {
            let waited = now.timeIntervalSince(oldest.at)
            if waited > 300 {
                status = .stuck
                action = "No progress for \(Int(waited / 60))m — \(oldest.summary)"
            } else {
                status = .working
                action = oldest.summary
            }
        } else if interrupted || lastWasEndTurn {
            status = .idle
            action = interrupted ? "Interrupted — waiting for you" : "Done — waiting for your next prompt"
        } else if quiet > 600 {
            status = .idle
            action = "Quiet for \(Int(quiet / 60))m"
        } else {
            status = .working
            action = "Thinking…"
        }
        if consecutiveErrors >= 3, status == .working {
            status = .stuck
            action = "\(consecutiveErrors) failed tool calls in a row"
        }

        let cost = (baselineCost ?? 0) + (estimateTotal - (baselineCost == nil ? 0 : estimateAtBaseline))
        return Agent(
            id: StableID.uuid(sessionId),
            project: project,
            status: status,
            action: action,
            tokens: outputTokens,
            cost: cost,
            startedAt: startedAt,
            contextTokens: contextTokens,
            contextLimit: Pricing.contextLimit(model: model),
            subagents: status == .working ? activeSubagents : [],
            branch: branch.map(Self.shortBranch),
            firstPrompt: title
        )
    }

    /// Repo name, seeing through worktrees:
    /// `~/code/cues/.claude/worktrees/fix-x` → "cues", `~/.paradev/worktrees/cues/fix-x` → "cues".
    static func projectName(cwd: String) -> String {
        let parts = URL(fileURLWithPath: cwd).pathComponents
        if let i = parts.lastIndex(of: "worktrees") {
            if i >= 2, parts[i - 1] == ".claude" { return parts[i - 2] }
            if i + 1 < parts.count { return parts[i + 1] }
        }
        return parts.last ?? cwd
    }

    /// `claude/hallucination-issue-9e4260` → `hallucination-issue` (Claude Code worktree branches).
    static func shortBranch(_ b: String) -> String {
        var s = b
        if s.hasPrefix("claude/") { s.removeFirst("claude/".count) }
        if let r = s.range(of: #"-[0-9a-f]{6}$"#, options: .regularExpression) { s.removeSubrange(r) }
        return s
    }

    private func int(_ v: Any?) -> Int { (v as? Int) ?? (v as? NSNumber)?.intValue ?? 0 }
}

struct SubagentState {
    var task: String?
    var finished = false
    var estimate = 0.0
    var reported = 0.0
    private var costByMessage: [String: Double] = [:]
    private var model: String?

    mutating func ingest(_ d: [String: Any]) {
        guard let m = d["message"] as? [String: Any] else { return }
        switch d["type"] as? String {
        case "user":
            if task == nil, let text = (m["content"] as? String) ?? ((m["content"] as? [[String: Any]])?.first?["text"] as? String) {
                task = String(text.split(separator: "\n").first ?? "").trimmingCharacters(in: .whitespaces)
            }
        case "assistant":
            if let mod = m["model"] as? String { model = mod }
            if let u = m["usage"] as? [String: Any] {
                let id = (m["id"] as? String) ?? UUID().uuidString
                let c = Pricing.cost(model: model, usage: u)
                estimate += c - (costByMessage[id] ?? 0)
                costByMessage[id] = c
            }
            finished = (m["stop_reason"] as? String) == "end_turn"
        default: break
        }
    }
}

// MARK: - Incremental JSONL reading

struct JSONLReader {
    let url: URL
    private var offset: UInt64 = 0
    private var carry = Data()

    init(url: URL) { self.url = url }

    mutating func readNewLines(_ handle: ([String: Any]) -> Void) {
        guard let fh = try? FileHandle(forReadingFrom: url) else { return }
        defer { try? fh.close() }
        let size = (try? fh.seekToEnd()) ?? 0
        if size < offset { offset = 0; carry = Data() }           // truncated/rotated
        guard size > offset else { return }
        try? fh.seek(toOffset: offset)
        guard let chunk = try? fh.read(upToCount: Int(size - offset)) else { return }
        offset = size
        var data = carry + chunk
        // Only complete lines; keep a trailing partial line for next time.
        guard let lastNL = data.lastIndex(of: 0x0A) else { carry = data; return }
        carry = data.subdata(in: data.index(after: lastNL)..<data.endIndex)
        data = data.subdata(in: data.startIndex..<lastNL)
        for line in data.split(separator: 0x0A, omittingEmptySubsequences: true) {
            if let obj = try? JSONSerialization.jsonObject(with: line) as? [String: Any] { handle(obj) }
        }
    }

    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let isoPlain = ISO8601DateFormatter()

    static func parseDate(_ s: String) -> Date? { iso.date(from: s) ?? isoPlain.date(from: s) }
}

// MARK: - Tool → one-line description

enum ToolSummary {
    static func describe(name: String, input: [String: Any]) -> String {
        func str(_ k: String) -> String? { (input[k] as? String).flatMap { $0.isEmpty ? nil : $0 } }
        func file(_ k: String) -> String? { str(k).map { URL(fileURLWithPath: $0).lastPathComponent } }
        let detail: String?
        switch name {
        case "Bash": detail = str("description") ?? str("command").map { String($0.prefix(80)) }
        case "Read", "Edit", "Write", "MultiEdit", "NotebookEdit": detail = file("file_path") ?? file("notebook_path")
        case "Grep", "Glob": detail = str("pattern")
        case "WebFetch": detail = str("url").flatMap { URL(string: $0)?.host }
        case "WebSearch": detail = str("query")
        case "Agent", "Task": detail = str("description")
        case "Skill": detail = str("skill")
        default: detail = nil
        }
        return detail.map { "\(name): \($0)" } ?? name
    }
}

// MARK: - Pricing & context windows (per MTok; from the Claude API reference, 2026-11)

enum Pricing {
    /// (input, output, cache read). Cache writes: 1.25× input (5m TTL), 2× input (1h TTL).
    private static let table: [(prefix: String, rates: (Double, Double, Double))] = [
        ("claude-fable-5-2", (8, 40, 0.20)),
        ("claude-mythos-5-2", (8, 40, 0.20)),
        ("claude-fable-5", (10, 50, 1.0)),
        ("claude-mythos-5", (10, 50, 1.0)),
        ("claude-opus-5-5", (4, 20, 0.20)),
        ("claude-opus-5", (5, 25, 0.50)),
        ("claude-opus-4", (5, 25, 0.50)),
        ("claude-sonnet-5-5", (2, 10, 0.10)),
        ("claude-sonnet-5", (2, 10, 0.20)),
        ("claude-sonnet-4", (3, 15, 0.30)),
        ("claude-haiku-5-5", (0.10, 0.50, 0.01)),
        ("claude-haiku-4", (1, 5, 0.10)),
    ]

    static func cost(model: String?, usage u: [String: Any]) -> Double {
        let m = model ?? "claude-opus-5-5"
        let (i, o, r) = table.first { m.hasPrefix($0.prefix) }?.rates ?? (4, 20, 0.20)
        func n(_ v: Any?) -> Double { (v as? NSNumber)?.doubleValue ?? 0 }
        let cc = u["cache_creation"] as? [String: Any]
        var w5 = n(cc?["ephemeral_5m_input_tokens"]), w1 = n(cc?["ephemeral_1h_input_tokens"])
        if cc == nil { w5 = n(u["cache_creation_input_tokens"]); w1 = 0 }
        let total = n(u["input_tokens"]) * i + n(u["output_tokens"]) * o
            + n(u["cache_read_input_tokens"]) * r + w5 * i * 1.25 + w1 * i * 2
        return total / 1_000_000
    }

    static func contextLimit(model: String?) -> Int {
        guard let m = model else { return 1_000_000 }
        // Every current model has a 1M window except Haiku 4.5 (and older 200K models).
        if m.hasPrefix("claude-haiku-4") || m.hasPrefix("claude-3") || m.hasPrefix("claude-sonnet-4-5")
            || m.hasPrefix("claude-opus-4-5") || m.hasPrefix("claude-opus-4-1") { return 200_000 }
        return 1_000_000
    }
}

// MARK: - Stable IDs (so characters keep their identity across scans)

enum StableID {
    static func uuid(_ s: String) -> UUID {
        if let u = UUID(uuidString: s) { return u }
        // FNV-1a into 16 bytes.
        var h1: UInt64 = 0xcbf29ce484222325, h2: UInt64 = 0x84222325cbf29ce4
        for b in s.utf8 {
            h1 = (h1 ^ UInt64(b)) &* 0x100000001b3
            h2 = (h2 ^ UInt64(b)) &* 0x100000001b3 &+ 7
        }
        var bytes = [UInt8](repeating: 0, count: 16)
        for i in 0..<8 { bytes[i] = UInt8((h1 >> (8 * UInt64(i))) & 0xff); bytes[8 + i] = UInt8((h2 >> (8 * UInt64(i))) & 0xff) }
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                           bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }
}
