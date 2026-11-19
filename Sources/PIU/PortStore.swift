import AppKit

@MainActor
final class PortStore: ObservableObject {
    @Published private(set) var ports: [ListeningPort] = []
    @Published private(set) var isRefreshing = false
    /// PIDs being stopped, to show progress on their rows.
    @Published private(set) var stopping: Set<Int32> = []

    @Published var showAll = false

    @Published var intervalSeconds: Int {
        didSet {
            let clamped = min(max(intervalSeconds, Self.intervalRange.lowerBound), Self.intervalRange.upperBound)
            if clamped != intervalSeconds { intervalSeconds = clamped; return }
            defaults.set(intervalSeconds, forKey: Key.interval)
            schedule()
        }
    }

    @Published var autoRefreshDisabled: Bool {
        didSet {
            defaults.set(autoRefreshDisabled, forKey: Key.autoRefreshDisabled)
            schedule()
        }
    }

    static let intervalRange = 2...300

    private enum Key {
        static let interval = "intervalSeconds"
        static let autoRefreshDisabled = "autoRefreshDisabled"
    }

    private let defaults = UserDefaults.standard
    private var timer: Timer?

    var devPorts: [ListeningPort] { ports.filter(\.isDev) }
    var visiblePorts: [ListeningPort] { showAll ? ports : devPorts }

    init() {
        intervalSeconds = defaults.object(forKey: Key.interval) as? Int ?? 10
        autoRefreshDisabled = defaults.bool(forKey: Key.autoRefreshDisabled)

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, !self.autoRefreshDisabled else { return }
                self.refresh()
            }
        }

        schedule()
        refresh()
    }

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        DispatchQueue.global(qos: .utility).async {
            let ports = PortScanner.scan()
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self.ports = ports
                    self.isRefreshing = false
                }
            }
        }
    }

    /// Asks the process to quit (SIGTERM), then forces it (SIGKILL) if it is still there after 3 s.
    func stop(_ port: ListeningPort) {
        guard port.killable, !stopping.contains(port.pid) else { return }
        let pid = port.pid
        stopping.insert(pid)
        kill(pid, SIGTERM)
        DispatchQueue.global(qos: .userInitiated).async {
            let deadline = Date().addingTimeInterval(3)
            while kill(pid, 0) == 0, Date() < deadline { usleep(100_000) }
            if kill(pid, 0) == 0 { kill(pid, SIGKILL) }
            usleep(200_000)
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self.stopping.remove(pid)
                    self.refresh()
                }
            }
        }
    }

    private func schedule() {
        timer?.invalidate()
        timer = nil
        guard !autoRefreshDisabled else { return }
        timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(intervalSeconds), repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }
}
