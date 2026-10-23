# GitSwitcher：Mac 菜单栏 Git 账号切换工具

一个原生 SwiftUI 小工具，常驻菜单栏，用来保存多个 Git 身份并一键切换。

## 功能

- 菜单栏显示当前账号名称，点开即可一键切换全局账号
- 管理窗口：新建、编辑、删除、拖动排序账号
- 每个账号可选一个图标，菜单栏和账号列表里会显示，一眼区分当前身份
- 每个账号可绑定一把 SSH 私钥，切换时同时切换 push 使用的密钥
- 「测试连接」：用这把密钥执行 `ssh -T`，确认它对应 GitHub 上的哪个账号
- 「复制公钥」：方便粘贴到 GitHub 的 SSH keys 设置
- 「应用到仓库」：只给某个仓库设置身份，不影响全局
- 在终端里手动修改 `~/.gitconfig` 后，菜单栏会自动同步
- 可设置登录时自动启动

## 下载安装

1. 到 [Releases](https://github.com/QAQDFAFD/GitSwitcher/releases/latest) 下载 `GitSwitcher-<版本>-macOS.zip`，
   解压后把 `GitSwitcher.app` 拖进「应用程序」文件夹。支持 macOS 13 及以上，Apple 芯片和 Intel 都能用。
2. 应用没有经过 Apple 公证，第一次打开会被系统拦下。先点「完成」，再到「系统设置 → 隐私与安全性」，
   在页面下方找到 GitSwitcher，点「仍要打开」。也可以在终端执行下面这条命令后直接打开：

   ```bash
   xattr -dr com.apple.quarantine /Applications/GitSwitcher.app
   ```

3. 打开后图标只出现在菜单栏，不会出现在 Dock 里。

## 环境要求（自己编译时）

- macOS 13 或更高
- Xcode 15+。`build_app.sh` 要同时编译 Apple 芯片和 Intel 版本，需要完整的 Xcode；
  只用 `swift run` 调试时，命令行工具（Swift 5.9+）就够了

## 构建与运行

```bash
./build_app.sh          # 生成 build/GitSwitcher.app 和发布用的 build/GitSwitcher-<版本>-macOS.zip
open build/GitSwitcher.app
```

开发调试也可以直接 `swift run`，或用 Xcode 打开 `Package.swift`。
「登录时自动启动」只在打包成 .app 后可用。

## 发布新版本

推送到 `main` 时，GitHub Actions 会自动检查能否编译打包。发布新版本只需要推送一个 `v` 开头的标签：

```bash
git tag v1.0.1
git push origin v1.0.1
```

Actions 会用标签作为版本号打包，然后自动创建 Release 并上传 zip。Release 说明由
`.github/release-notes.md` 里的安装步骤，加上自动生成的更新记录组成。

本地运行 `build_app.sh` 时，版本号取最近的 `v*` 标签，也可以用 `VERSION=1.2.0 ./build_app.sh` 指定。

## 切换时具体改了什么

| 配置项 | 说明 |
| --- | --- |
| `user.name` | 账号的用户名 |
| `user.email` | 账号的邮箱 |
| `core.sshCommand` | 绑定了私钥时写入 `ssh -i <私钥> -o IdentitiesOnly=yes`；切到没绑私钥的账号时，只清除本工具写过的值 |

「设为全局账号」写入 `~/.gitconfig`；「应用到仓库」写入该仓库的 `.git/config`。
账号列表保存在 `~/Library/Application Support/GitSwitcher/accounts.json`。

## 注意事项

- **HTTPS 方式的凭据不受本工具管理。** HTTPS 的用户名和 Token 由钥匙串按主机保存，
  多个 GitHub 账号推荐都用 SSH 方式（`git@github.com:...`）。如果一定要用 HTTPS，
  可以配合 GitHub CLI 的 `gh auth switch`。
- **私钥带密码时**，先执行一次 `ssh-add --apple-use-keychain ~/.ssh/你的私钥`，
  否则「测试连接」会因为无法输入密码而失败。
- **仓库级配置优先于全局配置。** 某个仓库应用过账号后，全局切换不会影响它。
- 如果更习惯按目录自动区分身份，也可以在 `~/.gitconfig` 里用 `includeIf "gitdir:~/work/"`，
  与本工具可以同时使用。
