import Foundation
import Network

struct HTTPRequest {
    let method: String
    let path: String
    let query: [String: String]
    let body: Data

    var json: [String: Any] {
        (try? JSONSerialization.jsonObject(with: body)) as? [String: Any] ?? [:]
    }

    /// Returns nil until `data` holds the full request (headers plus Content-Length bytes of body).
    static func parse(_ data: Data) -> HTTPRequest? {
        guard let headerEnd = data.range(of: Data("\r\n\r\n".utf8)),
              let head = String(data: data[data.startIndex..<headerEnd.lowerBound], encoding: .utf8)
        else { return nil }

        let lines = head.components(separatedBy: "\r\n")
        let requestLine = lines.first?.split(separator: " ") ?? []
        guard requestLine.count >= 2 else { return nil }

        var contentLength = 0
        for line in lines.dropFirst() {
            let pair = line.split(separator: ":", maxSplits: 1)
            if pair.count == 2, pair[0].lowercased() == "content-length" {
                contentLength = Int(pair[1].trimmingCharacters(in: .whitespaces)) ?? 0
            }
        }
        let body = data[headerEnd.upperBound...]
        guard body.count >= contentLength else { return nil }

        let target = requestLine[1].split(separator: "?", maxSplits: 1)
        var query: [String: String] = [:]
        if target.count == 2 {
            for item in target[1].split(separator: "&") {
                let pair = item.split(separator: "=", maxSplits: 1)
                query[String(pair[0])] = pair.count > 1 ? (String(pair[1]).removingPercentEncoding ?? "") : ""
            }
        }
        return HTTPRequest(method: String(requestLine[0]),
                           path: String(target[0]),
                           query: query,
                           body: Data(body.prefix(contentLength)))
    }
}

struct HTTPResponse {
    var status = 200
    var contentType = "application/json"
    var body = Data()

    static func json(_ object: Any, status: Int = 200) -> HTTPResponse {
        HTTPResponse(status: status, body: (try? JSONSerialization.data(withJSONObject: object)) ?? Data())
    }

    var serialized: Data {
        var data = Data(("HTTP/1.1 \(status) \(status == 200 ? "OK" : "Error")\r\n"
            + "Content-Type: \(contentType)\r\n"
            + "Content-Length: \(body.count)\r\n"
            + "Connection: close\r\n\r\n").utf8)
        data.append(body)
        return data
    }
}

/// A minimal one-request-per-connection HTTP server. Requests are handled on the
/// main thread, where XCUITest expects to be called.
final class HTTPServer {
    private let listener: NWListener
    private let handler: (HTTPRequest) -> HTTPResponse
    private let queue = DispatchQueue(label: "live.http")

    init(port: UInt16, handler: @escaping (HTTPRequest) -> HTTPResponse) throws {
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        guard let endpointPort = NWEndpoint.Port(rawValue: port) else { throw URLError(.badURL) }
        listener = try NWListener(using: parameters, on: endpointPort)
        self.handler = handler
    }

    func start() {
        listener.newConnectionHandler = { [weak self] connection in
            guard let self else { return }
            connection.start(queue: self.queue)
            self.read(connection, buffer: Data())
        }
        listener.start(queue: queue)
    }

    func stop() {
        listener.cancel()
    }

    private func read(_ connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1 << 16) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            var buffer = buffer
            if let data { buffer.append(data) }
            if let request = HTTPRequest.parse(buffer) {
                DispatchQueue.main.async {
                    let response = self.handler(request)
                    connection.send(content: response.serialized, completion: .contentProcessed { _ in connection.cancel() })
                }
            } else if isComplete || error != nil {
                connection.cancel()
            } else {
                self.read(connection, buffer: buffer)
            }
        }
    }
}
