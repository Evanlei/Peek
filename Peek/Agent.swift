import Foundation

enum AgentStatus: String, CaseIterable {
    case working    // green
    case needsInput // pulsing amber
    case stuck      // red
    case idle       // grey, dozing
}

/// A pending tool-permission prompt (later: delivered by a Claude Code hook).
struct PermissionRequest: Identifiable, Equatable {
    let id = UUID()
    var tool: String      // "Bash", "Edit", "Write", "WebFetch"…
    var detail: String    // the command / path / URL
    var requestedAt = Date()

    /// Reads as a sentence after the agent's name: "landing-site wants to fetch".
    var verb: String {
        switch tool {
        case "Bash": "wants to run"
        case "Edit", "Write", "MultiEdit", "NotebookEdit": "wants to edit"
        case "WebFetch": "wants to fetch"
        case "WebSearch": "wants to search"
        case "Read": "wants to read"
        default: "wants to use \(tool)"
        }
    }
}

/// A Task subagent spawned by a session — drawn as a small sidekick.
struct Subagent: Identifiable, Equatable {
    let id: UUID
    var task: String
}

struct Agent: Identifiable, Equatable {
    let id: UUID
    var project: String
    var status: AgentStatus
    var action: String
    var tokens: Int
    var cost: Double
    var startedAt: Date
    var contextTokens: Int
    var contextLimit: Int = 200_000
    var subagents: [Subagent] = []
    var request: PermissionRequest? = nil
    /// Git branch / worktree the session runs on, and its opening prompt —
    /// used only to tell apart sessions that share a project.
    var branch: String? = nil
    var firstPrompt: String? = nil
    /// What the UI shows. Set by `Agent.assignDisplayNames`.
    var displayName: String = ""

    var contextFraction: Double { min(1, Double(contextTokens) / Double(contextLimit)) }
    /// Above 80% the character visibly tires.
    var isTired: Bool { contextFraction >= 0.8 }
}

extension Agent {
    /// Plain project name when unique; "project · branch" when several sessions
    /// share a project; falls back to a snippet of the first prompt if branches collide too.
    static func assignDisplayNames(_ agents: inout [Agent]) {
        let groups = Dictionary(grouping: agents.indices, by: { agents[$0].project })
        for (project, idx) in groups {
            if idx.count == 1 {
                agents[idx[0]].displayName = project
                continue
            }
            let branches = idx.map { agents[$0].branch }
            let branchesUnique = !branches.contains(nil) && Set(branches).count == branches.count
            for (n, i) in idx.enumerated() {
                let suffix: String
                if branchesUnique, let b = agents[i].branch {
                    suffix = b
                } else if let p = agents[i].firstPrompt, !p.isEmpty {
                    suffix = p.count > 14 ? String(p.prefix(13)) + "…" : p
                } else {
                    suffix = "#\(n + 1)"
                }
                agents[i].displayName = "\(project) · \(suffix)"
            }
        }
    }
}
