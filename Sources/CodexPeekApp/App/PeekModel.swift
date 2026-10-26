import AppKit
import CodexPeekCore
import Combine

@MainActor
final class PeekModel: ObservableObject {
    @Published private(set) var catalog = AccountCatalog()
    @Published private(set) var snapshots: [String: QuotaSnapshot] = [:]
    @Published private(set) var errors: [String: QuotaError] = [:]
    @Published var settings = PeekSettings.read()
    @Published private(set) var sourceNotice: String?
    @Published private(set) var refreshing: Set<String> = []
    @Published var detailsVisible = false
    @Published private(set) var displayedIDs: [String] = []
    @Published var availableHeight: Double = max(64, Double(NSScreen.main?.visibleFrame.height ?? 640) - 16)
    @Published var availableWidth: Double = max(300, Double(NSScreen.main?.visibleFrame.width ?? 1000) - 16)

    let demo: Bool
    private let client: any UsageProviding
    private var policies: [String: RefreshPolicy] = [:]
    private var requests: [String: Task<Void, Never>] = [:]
    private var loop: Task<Void, Never>?
    private var signature = ""
    private var sourceRetry = false
    private var sleeping = false
    private var observers: [NSObjectProtocol] = []

    var capsuleHeight: CGFloat {
        CGFloat(CapsuleLayout.height(accountCount: displayedIDs.count, availableHeight: availableHeight,
                                    preferredHeight: settings.windowHeight, width: Double(capsuleWidth)))
    }
    var capsuleWidth: CGFloat { CGFloat(CapsuleLayout.resolvedWidth(settings.windowWidth, availableWidth: availableWidth)) }
    var store: AccountFileStore {
        AccountFileStore(stashURL: URL(fileURLWithPath: (settings.stashPath as NSString).expandingTildeInPath),
                         authURL: URL(fileURLWithPath: (settings.authPath as NSString).expandingTildeInPath))
    }

    init(demo: Bool = false, client: any UsageProviding = UsageClient()) {
        self.demo = demo
        self.client = client
        if demo {
            loadDemo()
            return
        }
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.pause() }
        })
        observers.append(center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.resume() }
        })
        resume()
    }

    func stop() {
        pause()
        for observer in observers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        observers.removeAll()
    }

    func saveSettings() {
        if !demo { settings.save() }
        signature = ""
        if !demo { tick(force: true) }
    }

    func refresh() {
        guard !demo, !sleeping else { return }
        signature = ""
        tick(force: true)
    }

    func account(_ id: String) -> Account? { catalog.credentials.first { $0.account.id == id }?.account }
    func label(_ id: String) -> String { account(id).map { settings.label(for: $0) } ?? "账号不可用" }

    func tooltip(_ id: String) -> String {
        var lines = [label(id)]
        if let error = errors[id] { lines.append(error.localizedDescription) }
        if let snapshot = snapshots[id] {
            for (label, window) in [("5 小时", snapshot.fiveHour), ("周额度", snapshot.weekly)] {
                if let date = window?.resetsAt {
                    lines.append("\(label)：\(date.formatted(date: .abbreviated, time: .shortened)) 重置")
                }
            }
            lines.append("更新于 \(snapshot.fetchedAt.formatted(date: .omitted, time: .standard))")
        }
        return lines.joined(separator: "\n")
    }

    private func resume() {
        sleeping = false
        signature = ""
        tick(force: true)
        loop?.cancel()
        loop = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(nanoseconds: 1_000_000_000) } catch { return }
                guard let self else { return }
                self.tick()
            }
        }
    }

    private func pause() {
        sleeping = true
        loop?.cancel()
        loop = nil
        for request in requests.values { request.cancel() }
        requests.removeAll()
        for id in Array(policies.keys) { policies[id]?.cancel() }
        refreshing = []
    }

    private func fileSignature() -> String {
        [store.stashURL, store.authURL].map { url in
            let values = try? FileManager.default.attributesOfItem(atPath: url.path)
            let modified = (values?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
            let size = (values?[.size] as? NSNumber)?.uint64Value ?? 0
            let inode = (values?[.systemFileNumber] as? NSNumber)?.uint64Value ?? 0
            return "\(url.path)|\(modified)|\(size)|\(inode)"
        }.joined(separator: "\n")
    }

    private func reload() {
        let next = store.load()
        let old = Dictionary(uniqueKeysWithValues: catalog.credentials.map { ($0.account.id, $0.revision) })
        for (id, revision) in old where next.credentials.first(where: { $0.account.id == id })?.revision != revision {
            requests.removeValue(forKey: id)?.cancel()
            policies.removeValue(forKey: id)
            snapshots.removeValue(forKey: id)
            errors.removeValue(forKey: id)
            refreshing.remove(id)
        }
        catalog = next
        updateDisplayedAccounts()
        sourceNotice = next.notices.isEmpty ? nil : Array(Set(next.notices)).sorted().joined(separator: "\n")
    }

    private func updateDisplayedAccounts() {
        let ids = AccountPresentation.orderedIDs(in: catalog, errors: errors)
        if ids != displayedIDs { displayedIDs = ids }
    }

    private func tick(force: Bool = false) {
        guard !sleeping else { return }
        let currentSignature = fileSignature()
        if currentSignature != signature {
            signature = currentSignature
            reload()
            sourceRetry = sourceNotice != nil
        } else if sourceRetry {
            // Retry a partial atomic replacement once; do not parse a missing file every second.
            sourceRetry = false
            reload()
        }
        updateDisplayedAccounts()
        let visible = Set(displayedIDs)
        for id in Array(requests.keys) where !visible.contains(id) {
            requests.removeValue(forKey: id)?.cancel()
            policies[id]?.cancel()
            refreshing.remove(id)
        }
        let positions = Dictionary(uniqueKeysWithValues: displayedIDs.enumerated().map { ($0.element, $0.offset) })
        let candidates = catalog.credentials.filter { visible.contains($0.account.id) }.sorted {
            let left = policies[$0.account.id]?.nextDue ?? .distantPast
            let right = policies[$1.account.id]?.nextDue ?? .distantPast
            if left != right { return left < right }
            return (positions[$0.account.id] ?? 0) < (positions[$1.account.id] ?? 0)
        }
        for credential in candidates {
            let id = credential.account.id
            if policies[id]?.revision != credential.revision {
                policies[id] = RefreshPolicy(revision: credential.revision)
            }
            // Expired records need no network slot; valid requests are bounded and ordered fairly.
            if !credential.isExpired(), requests.count >= 3 { continue }
            guard let ticket = policies[id]?.begin(at: Date(), force: force) else { continue }
            if credential.isExpired() {
                _ = policies[id]?.finish(ticket: ticket, revision: credential.revision, error: .expired,
                                         at: Date(), interval: settings.refreshInterval)
                if errors[id] != .expired { errors[id] = .expired }
                continue
            }
            refreshing.insert(id)
            requests[id] = Task { [weak self, client] in
                var snapshot: QuotaSnapshot?
                var failure: QuotaError?
                do { snapshot = try await client.fetch(credential) }
                catch is CancellationError { return }
                catch let error as QuotaError { failure = error }
                catch { failure = .network }
                guard let self, !Task.isCancelled, self.displayedIDs.contains(id),
                      self.policies[id]?.finish(ticket: ticket, revision: credential.revision, error: failure,
                                                at: Date(), interval: self.settings.refreshInterval) == true else { return }
                self.requests.removeValue(forKey: id)
                self.refreshing.remove(id)
                self.errors[id] = failure
                if let snapshot { self.snapshots[id] = snapshot }
                self.updateDisplayedAccounts()
            }
        }
    }

    private func loadDemo() {
        let accounts = [Account(id: "demo-work", accountID: "demo-work", label: "工作", plan: "pro"),
                        Account(id: "demo-personal", accountID: "demo-personal", label: "个人", plan: "plus")]
        catalog = AccountCatalog(credentials: accounts.map { Credential(account: $0, accessToken: "demo-only", expiresAt: nil) }, currentID: accounts[0].id)
        settings = PeekSettings()
        settings.pinnedIDs = [accounts[1].id]
        settings.aliases = [accounts[0].id: "工作", accounts[1].id: "个人"]
        for (index, account) in accounts.enumerated() {
            snapshots[account.id] = QuotaSnapshot(
                fiveHour: QuotaWindow(usedPercent: index == 0 ? 28 : 9, durationSeconds: 18_000, resetsAt: Date().addingTimeInterval(8280)),
                weekly: QuotaWindow(usedPercent: index == 0 ? 62 : 84, durationSeconds: 604_800, resetsAt: Date().addingTimeInterval(180_000)), plan: account.plan)
        }
        updateDisplayedAccounts()
    }
}
