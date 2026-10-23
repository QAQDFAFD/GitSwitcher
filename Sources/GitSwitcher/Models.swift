import Foundation

/// 一个 Git 身份：切换时写入 user.name / user.email，可选绑定一把 SSH 私钥
struct GitAccount: Identifiable, Codable, Hashable {
    static let defaultIcon = "person.crop.circle"

    var id = UUID()
    /// 列表里显示的名字，例如「公司」「个人」
    var label: String = ""
    /// 写入 user.name
    var name: String = ""
    /// 写入 user.email
    var email: String = ""
    /// 可选：SSH 私钥路径。填写后切换时会写入 core.sshCommand
    var sshKeyPath: String = ""
    /// 「测试连接」使用的主机
    var host: String = "github.com"
    /// 菜单栏和账号列表里显示的 SF Symbols 图标名
    var icon: String = GitAccount.defaultIcon

    var displayLabel: String {
        if !label.trimmed.isEmpty { return label.trimmed }
        if !name.trimmed.isEmpty { return name.trimmed }
        return "未命名账号"
    }

    func validate() throws {
        if name.trimmed.isEmpty {
            throw AppError.invalidAccount("用户名不能为空，请先填写「用户名」。")
        }
        let mail = email.trimmed
        if mail.isEmpty || !mail.contains("@") {
            throw AppError.invalidAccount("邮箱格式不正确，请检查「邮箱」。")
        }
    }
}

// MARK: - 兼容旧版本的 accounts.json

extension GitAccount {
    enum CodingKeys: String, CodingKey {
        case id, label, name, email, sshKeyPath, host, icon
    }

    /// 缺少的字段用默认值补上，旧版本保存的数据（没有 icon）才能正常读取，不会被当成损坏文件
    init(from decoder: Decoder) throws {
        self.init()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? id
        label = try container.decodeIfPresent(String.self, forKey: .label) ?? label
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? name
        email = try container.decodeIfPresent(String.self, forKey: .email) ?? email
        sshKeyPath = try container.decodeIfPresent(String.self, forKey: .sshKeyPath) ?? sshKeyPath
        host = try container.decodeIfPresent(String.self, forKey: .host) ?? host
        icon = try container.decodeIfPresent(String.self, forKey: .icon) ?? icon
    }
}

enum AppError: LocalizedError {
    case gitNotFound
    case commandFailed(String)
    case invalidAccount(String)
    case notARepository(String)
    case keyNotFound(String)

    var errorDescription: String? {
        switch self {
        case .gitNotFound:
            return "没有找到 git。请先运行 xcode-select --install 安装命令行工具，或用 Homebrew 安装 git。"
        case .commandFailed(let message), .invalidAccount(let message):
            return message
        case .notARepository(let path):
            return "\(path) 不是 Git 仓库，请选择包含 .git 的项目目录。"
        case .keyNotFound(let path):
            return "找不到私钥文件 \(path)，请检查「私钥路径」。"
        }
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
