import Network

/// Watches the network path and calls `onRecovery` each time the network
/// becomes available again after being unavailable. The first path reported
/// after `start()` only sets the baseline, so a network that is already
/// available at launch triggers nothing.
@MainActor
final class NetworkRecoveryMonitor {
    private let monitor = NWPathMonitor()
    private let onRecovery: @MainActor () -> Void
    /// Whether the last path reported was satisfied; `nil` before the first.
    private var wasSatisfied: Bool?

    init(onRecovery: @escaping @MainActor () -> Void) {
        self.onRecovery = onRecovery
    }

    /// Begin watching. Path updates are delivered on the main queue, in
    /// order, so they are handled on the main actor as they arrive.
    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            let isSatisfied = path.status == .satisfied
            MainActor.assumeIsolated { self?.pathChanged(isSatisfied: isSatisfied) }
        }
        monitor.start(queue: .main)
    }

    /// Stop watching; the monitor can't be restarted afterwards.
    func cancel() {
        monitor.cancel()
    }

    private func pathChanged(isSatisfied: Bool) {
        defer { wasSatisfied = isSatisfied }
        if isSatisfied, wasSatisfied == false { onRecovery() }
    }
}
