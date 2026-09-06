import Foundation
import Network

/// One-shot HTTP server on 127.0.0.1 that receives an OAuth redirect.
final class CallbackServer: @unchecked Sendable {
    let port: UInt16
    private let path: String
    private let listener: NWListener
    private let queue = DispatchQueue(label: "no.enso.UsageWidget.callback")
    private let lock = NSLock()
    private var continuation: CheckedContinuation<[String: String], Error>?
    private var started = false

    private init(port: UInt16, path: String) throws {
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: port)!)
        self.port = port
        self.path = path
        self.listener = try NWListener(using: parameters)
    }

    /// Binds the first free port in `ports`.
    static func start(ports: [UInt16], path: String) async throws -> CallbackServer {
        for port in ports {
            guard let server = try? CallbackServer(port: port, path: path) else { continue }
            if (try? await server.start()) != nil { return server }
        }
        throw ServiceError.noFreePort
    }

    private func start() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            listener.stateUpdateHandler = { [self] state in
                lock.lock()
                defer { lock.unlock() }
                guard !started else { return }
                switch state {
                case .ready:
                    started = true
                    continuation.resume()
                case .failed(let error):
                    started = true
                    continuation.resume(throwing: error)
                default:
                    break
                }
            }
            listener.newConnectionHandler = { [weak self] in self?.handle($0) }
            listener.start(queue: queue)
        }
    }

    /// Resolves with the query parameters of the first request to `path`.
    func waitForCallback() async throws -> [String: String] {
        try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            self.continuation = continuation
            lock.unlock()
        }
    }

    func stop() {
        listener.cancel()
        finish(.failure(CancellationError()))
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16 * 1024) { [weak self] data, _, _, _ in
            guard let self else { return }
            let request = String(decoding: data ?? Data(), as: UTF8.self)
            let target = request.split(separator: "\r\n").first?.split(separator: " ")
            let requestPath = target.flatMap { $0.count > 1 ? String($0[1]) : nil } ?? "/"
            let components = URLComponents(string: "http://localhost" + requestPath)
            let matches = components?.path == path

            let body = matches ? Self.successPage : "Not found"
            let response = "HTTP/1.1 \(matches ? "200 OK" : "404 Not Found")\r\n"
                + "Content-Type: text/html; charset=utf-8\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n"
                + body
            connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in connection.cancel() })

            guard matches else { return }
            let query = (components?.queryItems ?? []).compactMap { item in item.value.map { (item.name, $0) } }
            finish(.success(Dictionary(query, uniquingKeysWith: { first, _ in first })))
        }
    }

    private func finish(_ result: Result<[String: String], Error>) {
        lock.lock()
        let pending = continuation
        continuation = nil
        lock.unlock()
        pending?.resume(with: result)
    }

    private static let successPage = """
        <html><body style="font-family:-apple-system,sans-serif;text-align:center;padding-top:5em">
        <h2>Signed in</h2><p>You can close this tab and return to Usage Widget.</p></body></html>
        """
}
