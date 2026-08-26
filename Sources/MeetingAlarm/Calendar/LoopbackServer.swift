import Foundation
import Network

enum LoopbackError: LocalizedError {
    case noPort
    case badRequest
    case stateMismatch

    var errorDescription: String? {
        switch self {
        case .noPort: "Could not open a local port for Google sign-in."
        case .badRequest: "The sign-in redirect was malformed."
        case .stateMismatch: "The sign-in response failed a security check (state mismatch)."
        }
    }
}

/// A one-shot loopback HTTP server that captures the OAuth redirect on `127.0.0.1`.
/// Start it to learn the port, put that port in the redirect URI, then await the code.
final class LoopbackServer: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.goanpeca.MeetingAlarm.loopback")
    private var listener: NWListener?
    private var resumed = false
    private var codeResumed = false

    /// Begin listening and resolve with the OS-assigned port.
    func start() async throws -> UInt16 {
        let listener = try NWListener(using: .tcp, on: .any)
        self.listener = listener
        return try await withCheckedThrowingContinuation { continuation in
            listener.stateUpdateHandler = { [weak self] state in
                guard let self else { return }
                queue.async {
                    switch state {
                    case .ready:
                        if let port = listener.port?.rawValue, !self.resumed {
                            self.resumed = true
                            continuation.resume(returning: port)
                        }
                    case let .failed(error):
                        if !self.resumed {
                            self.resumed = true
                            continuation.resume(throwing: error)
                        }
                    default:
                        break
                    }
                }
            }
            listener.start(queue: queue)
        }
    }

    /// Await the redirect and return the `code`, validating `state`.
    func waitForCode(expectedState: String) async throws -> String {
        codeResumed = false
        return try await withCheckedThrowingContinuation { continuation in
            listener?.newConnectionHandler = { [weak self] connection in
                guard let self else { return }
                connection.start(queue: queue)
                connection
                    .receive(minimumIncompleteLength: 1, maximumLength: 16384) { data, _, _, _ in
                        self.queue.async {
                            guard !self.codeResumed else { return }
                            self.codeResumed = true
                            let result = Self.parse(data: data, expectedState: expectedState)
                            self.respond(on: connection, ok: (try? result.get()) != nil)
                            continuation.resume(with: result)
                        }
                    }
            }
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func respond(on connection: NWConnection, ok: Bool) {
        let message = ok
            ? "Meeting Alarm is connected. You can close this window."
            : "Sign-in failed. You can close this window."
        let body = "<html><body style=\"font-family:-apple-system\">\(message)</body></html>"
        let response = """
        HTTP/1.1 200 OK\r
        Content-Type: text/html; charset=utf-8\r
        Content-Length: \(body.utf8.count)\r
        Connection: close\r
        \r
        \(body)
        """
        connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private static func parse(data: Data?, expectedState: String) -> Result<String, Error> {
        guard let data, let request = String(data: data, encoding: .utf8),
              let path = request.split(separator: " ").dropFirst().first
        else { return .failure(LoopbackError.badRequest) }
        guard let comps = URLComponents(string: "http://127.0.0.1\(path)"),
              let items = comps.queryItems,
              let code = items.first(where: { $0.name == "code" })?.value
        else { return .failure(LoopbackError.badRequest) }
        let state = items.first(where: { $0.name == "state" })?.value
        guard state == expectedState else { return .failure(LoopbackError.stateMismatch) }
        return .success(code)
    }
}
