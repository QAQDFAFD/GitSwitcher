### 下载安装

1. 下载下方 Assets 里的 `GitSwitcher-<版本>-macOS.zip`，解压后把 `GitSwitcher.app` 拖进「应用程序」文件夹。
2. 应用没有经过 Apple 公证，第一次打开会被系统拦下。先点「完成」，再到「系统设置 → 隐私与安全性」，在页面下方找到 GitSwitcher，点「仍要打开」。也可以在终端执行下面这条命令后直接打开：
   ```bash
   xattr -dr com.apple.quarantine /Applications/GitSwitcher.app
   ```
3. 打开后图标只出现在菜单栏，不会出现在 Dock 里。

支持 macOS 13 及以上，Apple 芯片和 Intel 通用。
