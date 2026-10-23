import AppKit
import SwiftUI

// MARK: - 管理窗口

@MainActor
struct ManageView: View {
    @EnvironmentObject private var store: AccountStore
    @State private var selection: GitAccount.ID?

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            if let id = selection, let binding = store.binding(for: id) {
                AccountEditor(account: binding)
                    .id(id) // 切换账号时重置编辑器内部状态
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("在左侧选择一个账号，或点击工具栏的 + 新建")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(minWidth: 680, minHeight: 440)
        .overlay(alignment: .bottom) { statusBanner }
        .animation(.easeInOut(duration: 0.2), value: store.status)
        .onAppear {
            // 管理窗口打开时显示 Dock 图标，方便切换和输入
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            store.refreshCurrent()
            if selection == nil {
                selection = store.currentAccount?.id ?? store.accounts.first?.id
            }
        }
        .onDisappear {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    private var sidebar: some View {
        List(selection: $selection) {
            ForEach(store.accounts) { account in
                AccountRow(account: account, isCurrent: account.id == store.currentAccount?.id)
            }
            .onMove { store.move(from: $0, to: $1) }
        }
        .contextMenu(forSelectionType: GitAccount.ID.self) { ids in
            if ids.count == 1, let id = ids.first,
               let account = store.accounts.first(where: { $0.id == id }) {
                Button("设为全局账号") { store.switchGlobal(to: account) }
                Divider()
            }
            if !ids.isEmpty {
                Button("删除", role: .destructive) { store.delete(ids: ids) }
            }
        }
        .onDeleteCommand {
            if let selection { store.delete(ids: [selection]) }
        }
        .navigationSplitViewColumnWidth(min: 220, ideal: 240)
        .toolbar {
            ToolbarItem {
                Button {
                    selection = store.addAccount().id
                } label: {
                    Label("新建账号", systemImage: "plus")
                }
                .help("新建账号")
            }
        }
        .safeAreaInset(edge: .bottom) { currentIdentityPanel }
    }

    private var currentIdentityPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("当前全局身份")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(store.globalSummary)
                .font(.callout)
                .lineLimit(2)
                .textSelection(.enabled)
            if !store.globalEmail.isEmpty && store.currentAccount == nil {
                Button("保存为新账号") {
                    selection = store.importCurrent()?.id
                }
                .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.bar)
    }

    @ViewBuilder
    private var statusBanner: some View {
        if let status = store.status {
            Label(status, systemImage: "checkmark.circle.fill")
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.regularMaterial, in: Capsule())
                .padding(.bottom, 16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

// MARK: - 列表行

struct AccountRow: View {
    let account: GitAccount
    let isCurrent: Bool

    var body: some View {
        HStack {
            Image(systemName: account.icon)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(account.displayLabel)
                    .fontWeight(.medium)
                Text(account.email.trimmed.isEmpty ? "未填写邮箱" : account.email)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isCurrent {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .help("当前全局账号")
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - 编辑器

@MainActor
struct AccountEditor: View {
    @EnvironmentObject private var store: AccountStore
    @Binding var account: GitAccount
    @State private var sshFeedback: SSHTester.Outcome?
    @State private var testing = false

    private var isCurrent: Bool { store.currentAccount?.id == account.id }
    private var hasKey: Bool { !account.sshKeyPath.trimmed.isEmpty }

    var body: some View {
        Form {
            Section("基本信息") {
                TextField("显示名称", text: $account.label, prompt: Text("例如：公司、个人"))
                LabeledContent("图标") {
                    IconPicker(selection: $account.icon)
                }
                TextField("用户名", text: $account.name, prompt: Text("写入 user.name"))
                TextField("邮箱", text: $account.email, prompt: Text("写入 user.email"))
            }

            Section {
                HStack {
                    TextField("私钥路径", text: $account.sshKeyPath, prompt: Text("可选，如 ~/.ssh/id_ed25519_work"))
                    Button("选择…", action: pickKey)
                }
                TextField("测试主机", text: $account.host, prompt: Text("github.com"))
                HStack {
                    Button("复制公钥", action: copyPublicKey)
                    Button(testing ? "正在测试…" : "测试连接", action: runTest)
                        .disabled(testing)
                    if testing {
                        ProgressView().controlSize(.small)
                    }
                }
                .disabled(!hasKey)

                if let sshFeedback {
                    Label(sshFeedback.message,
                          systemImage: sshFeedback.success ? "checkmark.seal.fill" : "xmark.octagon.fill")
                        .font(.callout)
                        .foregroundStyle(sshFeedback.success ? Color.green : Color.red)
                        .textSelection(.enabled)
                }
            } header: {
                Text("SSH 密钥（可选）")
            } footer: {
                Text("填写后，切换到这个账号时会同时设置 core.sshCommand，push 和 pull 都会使用这把密钥。")
                    .foregroundStyle(.secondary)
            }

            Section {
                HStack {
                    Button(isCurrent ? "重新设为全局账号" : "设为全局账号") {
                        store.switchGlobal(to: account)
                    }
                    .buttonStyle(.borderedProminent)

                    Button("应用到仓库…", action: pickRepository)
                }
            } footer: {
                Text("「应用到仓库」只写入所选仓库的 .git/config，只对该仓库生效，优先级高于全局账号。")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func pickKey() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = true
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".ssh")
        panel.message = "选择私钥文件（不带 .pub 后缀的那个）"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        var path = url.path
        if path.hasSuffix(".pub") { path = String(path.dropLast(4)) }
        account.sshKeyPath = (path as NSString).abbreviatingWithTildeInPath
        sshFeedback = nil
    }

    private func copyPublicKey() {
        let path = (account.sshKeyPath.trimmed as NSString).expandingTildeInPath + ".pub"
        guard let key = try? String(contentsOfFile: path, encoding: .utf8) else {
            sshFeedback = SSHTester.Outcome(success: false, message: "读取公钥失败：找不到 \(path)")
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(key.trimmed, forType: .string)
        sshFeedback = SSHTester.Outcome(success: true, message: "已复制公钥，可粘贴到 GitHub 的 Settings → SSH and GPG keys")
    }

    private func runTest() {
        let key = account.sshKeyPath
        let host = account.host
        testing = true
        sshFeedback = nil
        Task { @MainActor in
            sshFeedback = await SSHTester.test(keyPath: key, host: host)
            testing = false
        }
    }

    private func pickRepository() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "选择要使用「\(account.displayLabel)」的 Git 仓库目录"
        panel.prompt = "应用"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        store.apply(account, toRepository: url)
    }
}
