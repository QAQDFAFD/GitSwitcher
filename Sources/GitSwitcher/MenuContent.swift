import AppKit
import SwiftUI

@MainActor
struct MenuContent: View {
    @EnvironmentObject private var store: AccountStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text(headerText)

        Divider()

        if store.accounts.isEmpty {
            Text("还没有账号，打开「管理账号」添加")
        } else {
            ForEach(store.accounts) { account in
                // 勾选状态 = 是否为当前全局账号；点击即切换
                Toggle(isOn: Binding(
                    get: { store.currentAccount?.id == account.id },
                    set: { _ in store.switchGlobal(to: account) }
                )) {
                    Label("\(account.displayLabel)（\(account.email)）", systemImage: account.icon)
                }
            }
        }

        Divider()

        Button("管理账号…") {
            openWindow(id: "manage")
            NSApp.activate(ignoringOtherApps: true)
        }
        .keyboardShortcut(",")

        Toggle("登录时自动启动", isOn: Binding(
            get: { store.launchAtLogin },
            set: { store.setLaunchAtLogin($0) }
        ))

        Divider()

        Button("退出") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    private var headerText: String {
        if store.globalEmail.isEmpty { return "全局 Git 身份未配置" }
        let prefix = store.currentAccount == nil ? "当前（未保存）" : "当前"
        return "\(prefix)：\(store.globalName) <\(store.globalEmail)>"
    }
}

// MARK: - 菜单栏标题

/// 把图标和文字画成一张模板图片再交给菜单栏。
/// 直接用 Label 时，菜单栏会把图标和文字分开排版，两者在垂直方向上对不齐。
@MainActor
struct MenuBarLabel: View {
    let title: String
    let icon: String

    var body: some View {
        Image(nsImage: rendered)
            .accessibilityLabel(title)
    }

    private var rendered: NSImage {
        let content = HStack(spacing: 4) {
            Image(systemName: icon)
            Text(title)
        }
        .font(Font(NSFont.menuBarFont(ofSize: 0) as CTFont))
        .foregroundStyle(.black)

        let renderer = ImageRenderer(content: content)
        // 按最清晰的屏幕渲染，外接低分屏上也不会糊
        renderer.scale = NSScreen.screens.map(\.backingScaleFactor).max() ?? 2
        let image = renderer.nsImage ?? NSImage()
        // 模板图片会跟随菜单栏的深浅色和点击高亮自动变色
        image.isTemplate = true
        return image
    }
}
