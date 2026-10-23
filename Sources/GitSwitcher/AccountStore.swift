import AppKit
import Foundation
import ServiceManagement
import SwiftUI

@MainActor
final class AccountStore: ObservableObject {
    /// 保存的账号列表，任何改动都会立即写回磁盘
    @Published var accounts: [GitAccount] = [] {
        didSet { save() }
    }
    /// 当前 ~/.gitconfig 里的身份
    @Published private(set) var globalName = ""
    @Published private(set) var globalEmail = ""
    /// 操作成功后短暂显示的提示
    @Published private(set) var status: String?
    @Published private(set) var launchAtLogin = SMAppService.mainApp.status == .enabled

    private let fileURL: URL
    private var statusToken = UUID()
    private var lastConfigStamp: Date?
    private var timer: Timer?

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = support.appendingPathComponent("GitSwitcher", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("accounts.json")

        load()
        refreshCurrent()
        // 第一次打开时，把现有的全局配置导入为第一个账号
        if accounts.isEmpty, !globalEmail.isEmpty {
            importCurrent()
        }
        startWatchingConfig()
    }

    // MARK: - 当前身份

    /// 与全局配置完全一致（用户名 + 邮箱）的账号
    var currentAccount: GitAccount? {
        guard !globalEmail.isEmpty else { return nil }
        return accounts.first {
            $0.email.trimmed.caseInsensitiveCompare(globalEmail) == .orderedSame
                && $0.name.trimmed == globalName
        }
    }

    var menuBarTitle: String { currentAccount?.displayLabel ?? "Git" }

    var menuBarIcon: String { currentAccount?.icon ?? GitAccount.defaultIcon }

    var globalSummary: String {
        if globalName.isEmpty && globalEmail.isEmpty { return "未配置" }
        return "\(globalName) <\(globalEmail)>"
    }

    func refreshCurrent() {
        globalName = GitConfig.get("user.name", scope: .global) ?? ""
        globalEmail = GitConfig.get("user.email", scope: .global) ?? ""
    }

    // MARK: - 切换

    func switchGlobal(to account: GitAccount) {
        do {
            try GitConfig.apply(account, scope: .global)
            refreshCurrent()
            flash("已设为全局账号：\(account.displayLabel)")
        } catch {
            presentError(error)
        }
    }

    func apply(_ account: GitAccount, toRepository url: URL) {
        do {
            guard GitConfig.isRepository(url) else { throw AppError.notARepository(url.path) }
            try GitConfig.apply(account, scope: .local(url))
            flash("已应用到仓库 \(url.lastPathComponent)：\(account.displayLabel)")
        } catch {
            presentError(error)
        }
    }

    // MARK: - 增删改

    @discardableResult
    func addAccount() -> GitAccount {
        let account = GitAccount(label: "新账号")
        accounts.append(account)
        return account
    }

    /// 把当前全局配置保存为一个账号
    @discardableResult
    func importCurrent() -> GitAccount? {
        guard !globalEmail.isEmpty else { return nil }
        if let existing = currentAccount { return existing }
        let account = GitAccount(label: "当前账号", name: globalName, email: globalEmail)
        accounts.append(account)
        return account
    }

    func delete(ids: Set<GitAccount.ID>) {
        accounts.removeAll { ids.contains($0.id) }
    }

    func move(from source: IndexSet, to destination: Int) {
        accounts.move(fromOffsets: source, toOffset: destination)
    }

    func binding(for id: GitAccount.ID) -> Binding<GitAccount>? {
        guard let index = accounts.firstIndex(where: { $0.id == id }) else { return nil }
        let fallback = accounts[index]
        return Binding(
            get: { self.accounts.first(where: { $0.id == id }) ?? fallback },
            set: { newValue in
                guard let i = self.accounts.firstIndex(where: { $0.id == id }) else { return }
                self.accounts[i] = newValue
            }
        )
    }

    // MARK: - 登录时启动（仅在打包成 .app 后有效）

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            presentError(error)
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    // MARK: - 监听在终端里对 ~/.gitconfig 的修改

    private func startWatchingConfig() {
        lastConfigStamp = configStamp()
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.checkConfigChanged() }
        }
    }

    private func checkConfigChanged() {
        let stamp = configStamp()
        guard stamp != lastConfigStamp else { return }
        lastConfigStamp = stamp
        refreshCurrent()
    }

    /// 只比较文件修改时间，有变化才去调用 git
    private func configStamp() -> Date? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let paths = [
            home.appendingPathComponent(".gitconfig").path,
            home.appendingPathComponent(".config/git/config").path,
        ]
        return paths
            .compactMap { (try? FileManager.default.attributesOfItem(atPath: $0))?[.modificationDate] as? Date }
            .max()
    }

    // MARK: - 持久化

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        do {
            accounts = try JSONDecoder().decode([GitAccount].self, from: data)
        } catch {
            // 文件损坏时先备份，避免被空列表覆盖
            let backup = fileURL.appendingPathExtension("bak")
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.moveItem(at: fileURL, to: backup)
        }
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(accounts) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    // MARK: - 反馈

    private func flash(_ message: String) {
        status = message
        let token = UUID()
        statusToken = token
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if self.statusToken == token { self.status = nil }
        }
    }

    private func presentError(_ error: Error) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "操作没有完成"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.runModal()
    }
}
