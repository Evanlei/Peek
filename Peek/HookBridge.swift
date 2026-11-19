import Foundation

/// Connects Claude Code's `PermissionRequest` hook to the notch.
///
/// Flow: Claude Code runs ~/.peek/permission-hook.sh → curl POSTs the hook JSON to
/// Peek (127.0.0.1, token-checked) → the request appears as the approval card →
/// Allow/Deny is written back as the hook's JSON decision.
/// If Peek isn't running, curl fails silently and the normal terminal prompt shows.
@MainActor
final class HookBridge {
    enum Decision { case allow, deny, none }

    static let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".peek")
    static let scriptURL = dir.appendingPathComponent("permission-hook.sh")
    private static let tokenURL = dir.appendingPathComponent("token")
    /// Give the user time to notice; Claude Code's own hook timeout is set a bit longer.
    static let holdSeconds: TimeInterval = 570

    private var server: HookServer?
    private weak var store: AgentStore?

    init(store: AgentStore) { self.store = store }

    func start() {
        do {
            let token = try Self.ensureToken()
            try Self.writeHookScript()
            let server = HookServer(token: token) { [weak self] incoming in
                DispatchQueue.main.async { MainActor.assumeIsolated { self?.handle(incoming) } }
            }
            try server.start()
            self.server = server
        } catch {
            NSLog("Peek: hook bridge disabled: \(error)")
        }
    }

    private func handle(_ incoming: HookServer.Incoming) {
        switch incoming.path {
        case "/permission":
            guard let json = try? JSONSerialization.jsonObject(with: incoming.body) as? [String: Any],
                  let tool = json["tool_name"] as? String else {
                return incoming.respond(200, Data())   // no decision → normal prompt
            }
            let input = json["tool_input"] as? [String: Any] ?? [:]
            let sessionID = json["session_id"] as? String ?? UUID().uuidString
            let request = PermissionRequest(tool: tool, detail: Self.detail(tool: tool, input: input))
            var settled = false
            let finish: (Decision) -> Void = { decision in
                guard !settled else { return }
                settled = true
                incoming.respond(200, Self.body(for: decision))
            }
            store?.addHookRequest(request, sessionID: sessionID, cwd: json["cwd"] as? String, finish: finish)
            // Answered in the terminal (hook cancelled) → drop the card.
            incoming.onClientGone { [weak self] in
                DispatchQueue.main.async {
                    MainActor.assumeIsolated {
                        settled = true
                        self?.store?.removeHookRequest(request.id)
                    }
                }
            }
            // Never hold forever: hand back to the terminal prompt.
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.holdSeconds) { [weak self] in
                MainActor.assumeIsolated {
                    finish(.none)
                    self?.store?.removeHookRequest(request.id)
                }
            }
        #if DEBUG
        case "/debug/decide":
            // Test hook: resolve the oldest pending request without clicking.
            let s = String(data: incoming.body, encoding: .utf8) ?? ""
            if let first = store?.pendingRequests.first {
                if s.contains("deny") { store?.deny(first.agent.id) } else { store?.approve(first.agent.id) }
            }
            incoming.respond(200, Data("{}".utf8))
        #endif
        default:
            incoming.respond(404, Data())
        }
    }

    // MARK: - Hook protocol (code.claude.com/docs/en/hooks → PermissionRequest)

    static func body(for d: Decision) -> Data {
        let decision: [String: Any]
        switch d {
        case .none: return Data()                       // empty 2xx/stdout = no decision
        case .allow: decision = ["behavior": "allow"]
        case .deny: decision = ["behavior": "deny", "message": "Denied from Peek."]
        }
        let obj: [String: Any] = ["hookSpecificOutput": ["hookEventName": "PermissionRequest", "decision": decision]]
        return (try? JSONSerialization.data(withJSONObject: obj)) ?? Data()
    }

    static func detail(tool: String, input: [String: Any]) -> String {
        func s(_ k: String) -> String? { (input[k] as? String).flatMap { $0.isEmpty ? nil : $0 } }
        switch tool {
        case "Bash": return s("command") ?? s("description") ?? "Bash"
        case "Edit", "Write", "MultiEdit", "Read": return s("file_path").map { ($0 as NSString).abbreviatingWithTildeInPath } ?? tool
        case "NotebookEdit": return s("notebook_path") ?? tool
        case "WebFetch": return s("url") ?? tool
        case "WebSearch": return s("query") ?? tool
        default: return s("description") ?? s("command") ?? tool
        }
    }

    // MARK: - Install pieces

    private static func ensureToken() throws -> String {
        let fm = FileManager.default
        try fm.createDirectory(at: dir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        if let t = try? String(contentsOf: tokenURL, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty {
            return t
        }
        var bytes = [UInt8](repeating: 0, count: 24)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let token = bytes.map { String(format: "%02x", $0) }.joined()
        fm.createFile(atPath: tokenURL.path, contents: Data(token.utf8), attributes: [.posixPermissions: 0o600])
        return token
    }

    static let script = """
    #!/bin/sh
    # Peek: forwards Claude Code's PermissionRequest hook to the Peek notch app.
    # Prints Peek's decision JSON. If Peek isn't running it prints nothing, so
    # Claude Code falls back to its normal permission prompt.
    TOKEN_FILE="$HOME/.peek/token"
    [ -r "$TOKEN_FILE" ] || exit 0
    curl -s --max-time 590 -X POST \\
      -H "Content-Type: application/json" \\
      -H "X-Peek-Token: $(cat "$TOKEN_FILE")" \\
      --data-binary @- http://127.0.0.1:\(HookServer.port)/permission 2>/dev/null || true
    exit 0

    """

    private static func writeHookScript() throws {
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
    }
}
