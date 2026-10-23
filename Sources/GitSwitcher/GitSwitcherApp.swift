import SwiftUI

@main
struct GitSwitcherApp: App {
    @StateObject private var store = AccountStore()

    var body: some Scene {
        // 菜单栏图标放在第一个，启动时只显示图标、不弹窗口
        MenuBarExtra {
            MenuContent()
                .environmentObject(store)
        } label: {
            MenuBarLabel(title: store.menuBarTitle, icon: store.menuBarIcon)
        }
        .menuBarExtraStyle(.menu)

        Window("Git 账号管理", id: "manage") {
            ManageView()
                .environmentObject(store)
        }
        .defaultSize(width: 760, height: 480)
    }
}
