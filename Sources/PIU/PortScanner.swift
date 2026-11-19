import Darwin
import Foundation

struct ListeningPort: Identifiable, Equatable {
    var id: String { "\(pid):\(port)" }
    let port: Int
    let pid: Int32
    let name: String
    let executable: String
    let command: String
    let directory: String?
    let user: String
    let uptime: TimeInterval?
    /// Listening on all interfaces (reachable from the local network), not only localhost.
    let exposed: Bool
    let isDev: Bool
    /// Stopping it would take down something bigger (e.g. Docker publishes container ports).
    let killable: Bool
}

/// Lists TCP ports in LISTEN state with `lsof`, then enriches them with `ps`.
enum PortScanner {
    static func scan() -> [ListeningPort] {
        let entries = listeners()
        guard !entries.isEmpty else { return [] }
        let pids = Array(Set(entries.map(\.pid))).sorted()
        let info = processInfo(pids)
        let directories = workingDirectories(pids)
        let me = NSUserName()

        return entries.compactMap { entry -> ListeningPort? in
            let process = info[entry.pid]
            let executable = executablePath(entry.pid) ?? process?.executable ?? entry.command
            // Claude Code's binary is named after its version (e.g. ".../claude/versions/2.1.326").
            let name = executable.contains("/claude/versions/") ? "claude" : (executable as NSString).lastPathComponent
            let user = process?.user ?? entry.user
            let isDocker = executable.localizedCaseInsensitiveContains("docker")
                || executable.localizedCaseInsensitiveContains("orbstack")
            return ListeningPort(
                port: entry.port,
                pid: entry.pid,
                name: isDocker ? "Docker" : name,
                executable: executable,
                command: process?.arguments ?? executable,
                directory: directories[entry.pid].flatMap { $0 == "/" ? nil : $0 },
                user: user,
                uptime: process?.uptime,
                exposed: entry.exposed,
                isDev: isDocker || isDevProcess(executable: executable, user: user, port: entry.port, me: me),
                killable: user == me && !isDocker && !systemPrefixes.contains(where: executable.hasPrefix)
            )
        }
        .sorted { ($0.port, $0.pid) < ($1.port, $1.pid) }
    }

    /// Dev servers, databases, scripts… as opposed to macOS services and installed apps.
    private static func isDevProcess(executable: String, user: String, port: Int, me: String) -> Bool {
        guard user == me, port < 49152 else { return false }
        // macOS services, and installed apps (Discord, Cursor, Warp…) that listen for their own use.
        let apps = ["/Applications/", NSHomeDirectory() + "/Applications/"]
        return !(systemPrefixes + apps).contains(where: executable.hasPrefix)
    }

    private static let systemPrefixes = ["/System/", "/usr/libexec/", "/usr/sbin/", "/sbin/"]

    /// Real executable path: `ps` shows the process title, which apps like Electron rewrite.
    private static func executablePath(_ pid: Int32) -> String? {
        var buffer = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
        guard proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0 else { return nil }
        return String(cString: buffer)
    }

    // MARK: - lsof

    private struct Entry {
        let pid: Int32
        let command: String
        let user: String
        let port: Int
        let exposed: Bool
    }

    /// `lsof -F` prints one field per line: `p` starts a process, `n` is an address like `*:8080`.
    private static func listeners() -> [Entry] {
        let output = run("/usr/sbin/lsof", ["-nP", "-iTCP", "-sTCP:LISTEN", "-F", "pcLn"])
        var entries: [String: Entry] = [:]
        var pid: Int32 = 0, command = "", user = ""
        for line in output.split(separator: "\n") {
            guard let tag = line.first else { continue }
            let value = String(line.dropFirst())
            switch tag {
            case "p": pid = Int32(value) ?? 0
            case "c": command = value
            case "L": user = value
            case "n":
                guard let colon = value.lastIndex(of: ":"), let port = Int(value[value.index(after: colon)...]) else { continue }
                let host = value[..<colon]
                let exposed = host == "*" || host == "[::]" || host == "0.0.0.0"
                let key = "\(pid):\(port)"
                // The same port often shows up twice (IPv4 and IPv6).
                let previous = entries[key]
                entries[key] = Entry(pid: pid, command: command, user: user, port: port,
                                     exposed: exposed || (previous?.exposed ?? false))
            default: break
            }
        }
        return Array(entries.values)
    }

    private static func workingDirectories(_ pids: [Int32]) -> [Int32: String] {
        let list = pids.map(String.init).joined(separator: ",")
        let output = run("/usr/sbin/lsof", ["-a", "-d", "cwd", "-F", "pn", "-p", list])
        var result: [Int32: String] = [:]
        var pid: Int32 = 0
        for line in output.split(separator: "\n") {
            if line.hasPrefix("p") { pid = Int32(line.dropFirst()) ?? 0 }
            if line.hasPrefix("n") { result[pid] = String(line.dropFirst()) }
        }
        return result
    }

    // MARK: - ps

    private struct Process {
        var user: String
        var uptime: TimeInterval?
        var executable: String
        var arguments: String
    }

    private static func processInfo(_ pids: [Int32]) -> [Int32: Process] {
        let list = pids.map(String.init).joined(separator: ",")
        var result: [Int32: Process] = [:]
        // `comm` and `args` can contain spaces, so each goes last in its own call.
        for line in run("/bin/ps", ["-o", "pid=,etime=,user=,comm=", "-p", list]).split(separator: "\n") {
            let parts = line.split(separator: " ", maxSplits: 3, omittingEmptySubsequences: true)
            guard parts.count == 4, let pid = Int32(parts[0]) else { continue }
            result[pid] = Process(user: String(parts[2]), uptime: seconds(fromElapsed: String(parts[1])),
                                  executable: String(parts[3]), arguments: "")
        }
        for line in run("/bin/ps", ["-o", "pid=,args=", "-p", list]).split(separator: "\n") {
            let parts = line.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            guard parts.count == 2, let pid = Int32(parts[0]) else { continue }
            result[pid]?.arguments = String(parts[1])
        }
        return result
    }

    /// `ps` elapsed time: `[[dd-]hh:]mm:ss`.
    static func seconds(fromElapsed value: String) -> TimeInterval? {
        let dayParts = value.split(separator: "-")
        let days = dayParts.count == 2 ? Double(dayParts[0]) ?? 0 : 0
        let clock = (dayParts.last ?? "").split(separator: ":").compactMap { Double($0) }
        guard !clock.isEmpty else { return nil }
        let hms = clock.reversed().enumerated().reduce(0.0) { $0 + $1.element * pow(60, Double($1.offset)) }
        return days * 86_400 + hms
    }

    private static func run(_ path: String, _ arguments: [String]) -> String {
        let p = Foundation.Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = arguments
        let out = Pipe()
        p.standardOutput = out
        p.standardError = FileHandle.nullDevice
        guard (try? p.run()) != nil else { return "" }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
