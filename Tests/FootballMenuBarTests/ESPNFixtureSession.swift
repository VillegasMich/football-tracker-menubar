import Foundation

extension URLSession {
    /// A session that answers Primary Source scoreboard requests from saved
    /// real responses instead of the network, so tests run offline.
    ///
    /// A request for `.../soccer/{slug}/scoreboard?dates={YYYYMMDD}` is served
    /// `Fixtures/ESPN/{slug}/{YYYYMMDD}.json`. A request with no matching
    /// fixture fails with HTTP 404, so a test never silently hits the network.
    static var espnFixtures: URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ESPNFixtureURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    /// Like `espnFixtures`, and also records the URL of every request it
    /// receives into `log`.
    static func espnFixtures(recordingInto log: RequestLog) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ESPNFixtureURLProtocol.self]
        configuration.httpAdditionalHeaders = [RequestLog.headerName: log.id]
        RequestLog.register(log)
        return URLSession(configuration: configuration)
    }
}

/// The URLs of the requests a stub session received, in arrival order. Safe
/// to share across the session's threads.
final class RequestLog: @unchecked Sendable {
    /// Header the stub session stamps on its requests so the stub protocol,
    /// which the system creates, can find the log to record into.
    fileprivate static let headerName = "X-Test-Request-Log"

    fileprivate let id = UUID().uuidString
    private let lock = NSLock()
    private var recorded: [URL] = []

    var urls: [URL] { lock.withLock { recorded } }

    fileprivate func record(_ url: URL) { lock.withLock { recorded.append(url) } }

    private static let registryLock = NSLock()
    nonisolated(unsafe) private static var registry: [String: RequestLog] = [:]

    fileprivate static func register(_ log: RequestLog) {
        registryLock.withLock { registry[log.id] = log }
    }

    fileprivate static func log(for request: URLRequest) -> RequestLog? {
        guard let id = request.value(forHTTPHeaderField: headerName) else { return nil }
        return registryLock.withLock { registry[id] }
    }
}

/// The local calendar day `year-month-day`, at noon so that formatting it as a
/// local `YYYYMMDD` (as the provider does) gives that same date in any time zone.
func localDay(_ year: Int, _ month: Int, _ day: Int) -> Date {
    Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
}

private final class ESPNFixtureURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        RequestLog.log(for: request)?.record(url)
        let fixture = Self.fixtureURL(for: url).flatMap { try? Data(contentsOf: $0) }
        let response = HTTPURLResponse(url: url,
                                       statusCode: fixture == nil ? 404 : 200,
                                       httpVersion: "HTTP/1.1",
                                       headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: fixture ?? Data())
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    /// `Fixtures/ESPN/{slug}/{dates}.json` for a scoreboard URL, if it exists.
    private static func fixtureURL(for url: URL) -> URL? {
        let path = url.pathComponents
        guard path.last == "scoreboard", path.count >= 2,
              let dates = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                  .queryItems?.first(where: { $0.name == "dates" })?.value
        else { return nil }
        let slug = path[path.count - 2]
        return Bundle.module.url(forResource: dates, withExtension: "json",
                                 subdirectory: "Fixtures/ESPN/\(slug)")
    }
}
