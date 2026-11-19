import Foundation
import Network

/// Tiny HTTP/1.1 server on 127.0.0.1 that Claude Code hooks talk to.
///
/// - Bound to loopback only; requests must carry the per-install token
///   (`X-Peek-Token`), so other local processes can't inject approvals.
/// - A permission request is held open (long-poll) until the user decides in the
///   notch or the hold expires; the decision is written back as the response body.
final class HookServer: @unchecked Sendable {
    struct Incoming {
        let path: String
        let body: Data
        let respond: @Sendable (_ status: Int, _ body: Data) -> Void
        /// Fires if the client hangs up first (e.g. you answered in the terminal and
        /// Claude Code cancelled the hook).
        let onClientGone: @Sendable (@escaping @Sendable () -> Void) -> Void
    }

    static let port: UInt16 = 47_823
    private let token: String
    private let queue = DispatchQueue(label: "peek.hooks")
    private var listener: NWListener?
    private let handler: @Sendable (Incoming) -> Void

    init(token: String, handler: @escaping @Sendable (Incoming) -> Void) {
        self.token = token
        self.handler = handler
    }

    func start() throws {
        let params = NWParameters.tcp
        params.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .init(rawValue: Self.port)!)
        params.allowLocalEndpointReuse = true
        let l = try NWListener(using: params)
        l.newConnectionHandler = { [weak self] c in self?.accept(c) }
        l.start(queue: queue)
        listener = l
    }

    private func accept(_ c: NWConnection) {
        c.start(queue: queue)
        receive(c, buffer: Data())
    }

    private func receive(_ c: NWConnection, buffer: Data) {
        c.receive(minimumIncompleteLength: 1, maximumLength: 1 << 20) { [weak self] data, _, done, err in
            guard let self else { return }
            var buf = buffer
            if let data { buf.append(data) }
            if let req = HTTPRequest.parse(buf) {
                self.dispatch(req, on: c)
            } else if done || err != nil || buf.count > 4 << 20 {
                c.cancel()
            } else {
                self.receive(c, buffer: buf)
            }
        }
    }

    private func dispatch(_ req: HTTPRequest, on c: NWConnection) {
        let reply: @Sendable (Int, Data) -> Void = { status, body in
            let head = "HTTP/1.1 \(status) \(status == 200 ? "OK" : "Error")\r\n" +
                "Content-Type: application/json\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n"
            c.send(content: Data(head.utf8) + body, completion: .contentProcessed { _ in c.cancel() })
        }
        guard req.method == "POST" else { return reply(405, Data()) }
        guard req.headers["x-peek-token"] == token else { return reply(403, Data()) }
        let gone: @Sendable (@escaping @Sendable () -> Void) -> Void = { callback in
            // Any further read completing means the peer closed (we never expect more bytes).
            c.receive(minimumIncompleteLength: 1, maximumLength: 1) { _, _, done, err in
                if done || err != nil { callback() }
            }
        }
        handler(Incoming(path: req.path, body: req.body, respond: reply, onClientGone: gone))
    }
}

private struct HTTPRequest {
    let method: String
    let path: String
    let headers: [String: String]
    let body: Data

    /// Returns nil until the full request (headers + Content-Length body) has arrived.
    static func parse(_ data: Data) -> HTTPRequest? {
        guard let sep = data.range(of: Data("\r\n\r\n".utf8)) else { return nil }
        guard let head = String(data: data[..<sep.lowerBound], encoding: .utf8) else { return nil }
        var lines = head.components(separatedBy: "\r\n")
        let start = lines.removeFirst().split(separator: " ")
        guard start.count >= 2 else { return nil }
        var headers: [String: String] = [:]
        for l in lines {
            guard let i = l.firstIndex(of: ":") else { continue }
            headers[l[..<i].lowercased()] = l[l.index(after: i)...].trimmingCharacters(in: .whitespaces)
        }
        let len = Int(headers["content-length"] ?? "0") ?? 0
        let bodyStart = sep.upperBound
        guard data.count - bodyStart >= len else { return nil }
        return HTTPRequest(method: String(start[0]), path: String(start[1]), headers: headers,
                           body: data.subdata(in: bodyStart..<(bodyStart + len)))
    }
}
