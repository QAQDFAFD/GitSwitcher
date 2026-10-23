import SwiftUI

// MARK: - 可选图标

enum AccountIcons {
    /// 都是 macOS 13 自带的 SF Symbols，每行 6 个
    static let choices = [
        "person.crop.circle", "person.fill", "person.2.fill", "briefcase.fill", "building.2.fill", "house.fill",
        "laptopcomputer", "desktopcomputer", "terminal.fill", "chevron.left.forwardslash.chevron.right", "hammer.fill", "wrench.and.screwdriver.fill",
        "graduationcap.fill", "book.fill", "paintbrush.fill", "gamecontroller.fill", "cup.and.saucer.fill", "music.note",
        "globe", "cloud.fill", "key.fill", "lock.fill", "flag.fill", "crown.fill",
        "star.fill", "heart.fill", "bolt.fill", "flame.fill", "leaf.fill", "moon.fill",
        "cat.fill", "dog.fill", "hare.fill", "tortoise.fill", "sun.max.fill", "sparkles",
    ]
}

// MARK: - 图标选择器

/// 显示当前图标的按钮，点开后在弹出框里选择
struct IconPicker: View {
    @Binding var selection: String
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Image(systemName: selection)
                .frame(width: 20)
        }
        .help("选择图标")
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            IconGrid(selection: $selection) { isPresented = false }
        }
    }
}

/// 弹出框里的图标网格，当前图标带高亮底色
struct IconGrid: View {
    @Binding var selection: String
    var onPick: () -> Void = {}

    private let columns = Array(repeating: GridItem(.fixed(32), spacing: 4), count: 6)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(AccountIcons.choices, id: \.self) { name in
                Button {
                    selection = name
                    onPick()
                } label: {
                    Image(systemName: name)
                        .font(.title3)
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(name == selection ? Color.accentColor.opacity(0.25) : .clear)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
    }
}
