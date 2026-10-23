import Foundation

// MARK: - 执行外部命令

struct ShellResult {
    let status: Int32
    let stdout: String
    let stderr: String
}

enum Shell {
    static func run(_ executable: String, _ arguments: [String]) throws -> ShellResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe
        process.standardInput = FileHandle.nullDevice

        try process.run()
        // 这里的输出都很短，先读完再等待退出即可
        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        return ShellResult(
            status: process.terminationStatus,
            stdout: String(decoding: outData, as: UTF8.self).trimmed,
            stderr: String(decoding: errData, as: UTF8.self).trimmed
        )
    }
}

// MARK: - git config 读写

enum ConfigScope {
    /// ~/.gitconfig
    case global
    /// 某个仓库的 .git/config
    case local(URL)

    var arguments: [String] {
        switch self {
        case .global:
            return ["config", "--global"]
        case .local(let repo):
            return ["-C", repo.path, "config", "--local"]
        }
    }
}

enum GitConfig {
    /// 从 Finder 启动的应用拿不到终端里的 PATH，所以按常见位置查找 git
    static let gitPath: String? = [
        "/opt/homebrew/bin/git",
        "/usr/local/bin/git",
        "/usr/bin/git",
    ].first { FileManager.default.isExecutableFile(atPath: $0) }

    private static func git(_ arguments: [String]) throws -> ShellResult {
        guard let gitPath else { throw AppError.gitNotFound }
        return try Shell.run(gitPath, arguments)
    }

    static func get(_ key: String, scope: ConfigScope) -> String? {
        guard let result = try? git(scope.arguments + ["--get", key]), result.status == 0 else {
            return nil
        }
        return result.stdout
    }

    static func set(_ key: String, _ value: String, scope: ConfigScope) throws {
        let result = try git(scope.arguments + [key, value])
        guard result.status == 0 else {
            throw AppError.commandFailed("写入 \(key) 失败：\(result.stderr)")
        }
    }

    static func unset(_ key: String, scope: ConfigScope) throws {
        let result = try git(scope.arguments + ["--unset", key])
        // 退出码 5 表示本来就没有这项配置，不算失败
        guard result.status == 0 || result.status == 5 else {
            throw AppError.commandFailed("删除 \(key) 失败：\(result.stderr)")
        }
    }

    static func isRepository(_ url: URL) -> Bool {
        guard let result = try? git(["-C", url.path, "rev-parse", "--is-inside-work-tree"]) else {
            return false
        }
        return result.status == 0 && result.stdout == "true"
    }

    /// 把账号写入指定作用域：user.name、user.email，以及可选的 core.sshCommand
    static func apply(_ account: GitAccount, scope: ConfigScope) throws {
        // 先把所有检查做完，避免只写进去一半
        try account.validate()

        let keyPath = account.sshKeyPath.trimmed
        let expandedKey = (keyPath as NSString).expandingTildeInPath
        if !keyPath.isEmpty, !FileManager.default.fileExists(atPath: expandedKey) {
            throw AppError.keyNotFound(expandedKey)
        }

        try set("user.name", account.name.trimmed, scope: scope)
        try set("user.email", account.email.trimmed, scope: scope)

        if !keyPath.isEmpty {
            try set("core.sshCommand", sshCommand(forKey: expandedKey), scope: scope)
        } else if let current = get("core.sshCommand", scope: scope), isManagedSSHCommand(current) {
            // 只清理本工具写入的值，不动你自己配置过的 sshCommand
            try unset("core.sshCommand", scope: scope)
        }
    }

    static func sshCommand(forKey path: String) -> String {
        let escaped = path.replacingOccurrences(of: "'", with: "'\\''")
        return "ssh -i '\(escaped)' -o IdentitiesOnly=yes"
    }

    static func isManagedSSHCommand(_ value: String) -> Bool {
        value.hasPrefix("ssh -i ") && value.hasSuffix(" -o IdentitiesOnly=yes")
    }
}

// MARK: - 测试 SSH 密钥对应哪个账号

enum SSHTester {
    struct Outcome {
        let success: Bool
        let message: String
    }

    /// 执行 ssh -T git@host，GitHub 会回复 "Hi <用户名>! You've successfully authenticated..."
    static func test(keyPath: String, host: String) async -> Outcome {
        let expanded = (keyPath.trimmed as NSString).expandingTildeInPath
        let target = host.trimmed.isEmpty ? "github.com" : host.trimmed

        return await Task.detached(priority: .userInitiated) { () -> Outcome in
            do {
                let result = try Shell.run("/usr/bin/ssh", [
                    "-T",
                    "-i", expanded,
                    "-o", "IdentitiesOnly=yes",
                    "-o", "BatchMode=yes",
                    "-o", "StrictHostKeyChecking=accept-new",
                    "-o", "ConnectTimeout=8",
                    "git@\(target)",
                ])
                let lines = (result.stdout + "\n" + result.stderr)
                    .split(separator: "\n")
                    .map { String($0).trimmed }
                    .filter { !$0.isEmpty }

                // GitHub / Gitee 回复 successfully authenticated，GitLab 回复 Welcome to GitLab
                if let line = lines.first(where: {
                    $0.contains("successfully authenticated") || $0.contains("Welcome to GitLab")
                }) {
                    return Outcome(success: true, message: line)
                }
                let detail = lines.last ?? "没有输出（退出码 \(result.status)）"
                return Outcome(success: false, message: "连接失败：\(detail)")
            } catch {
                return Outcome(success: false, message: "无法执行 ssh：\(error.localizedDescription)")
            }
        }.value
    }
}
