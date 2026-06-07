import Foundation

/// Reliable, universal agent bridge. Watches `~/.pixelcat/state.json` and
/// reports its `status` field. Any agent that can write a file can drive the
/// cat — a Claude Code `Stop` hook, a shell one-liner, a script, anything.
///
/// File format: `{"status":"thinking"}` | `{"status":"done"}` | `{"status":"idle"}`
///
/// Polls modification time (robust to atomic writes that replace the inode,
/// which a DispatchSource file watch would miss).
final class AgentBridge {
    enum Status: String { case thinking, done, idle }

    var onStatus: ((Status) -> Void)?

    private var timer: Timer?
    private var lastModified: Date?
    private let url: URL

    init() {
        let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".pixelcat")
        self.url = dir.appendingPathComponent("state.json")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    var stateFilePath: String { url.path }

    func start() {
        let timer = Timer(timeInterval: 0.4, repeats: true) { [weak self] _ in self?.poll() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() { timer?.invalidate(); timer = nil }

    private func poll() {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let modified = attrs[.modificationDate] as? Date else { return }
        if let last = lastModified, last == modified { return }
        lastModified = modified

        guard let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let raw = obj["status"] as? String,
              let status = Status(rawValue: raw.lowercased()) else { return }
        onStatus?(status)
    }
}
