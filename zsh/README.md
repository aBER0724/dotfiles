# zsh

Zsh 配置(配合 oh-my-zsh + Powerlevel10k),跨设备同步(macOS / Linux 均可用)。
`.zshrc` 做了平台自适应:所有 macOS 专属路径、可选依赖都有存在性守卫,缺依赖不报错。

## 目录结构

```
zsh/
├── zshrc            # 主配置(交互 shell)
├── zshenv           # 每个 zsh 进程都会读(cargo env)
├── zprofile         # 登录 shell(macOS brew shellenv、Linux PATH 等)
├── shinit           # x-cmd 启动
├── p10k.zsh         # Powerlevel10k 主题配置(由配置向导生成)
└── install-deps.sh  # 一键安装运行时依赖(插件/p10k/zsh 可选件)
```

## 依赖运行时(install-deps.sh 帮你装)

`.zshrc` 期望但**不是配置文件**、需要单独安装的部分:

| 依赖 | 来源 | 装到哪 |
|------|------|--------|
| oh-my-zsh | [ohmyzsh/ohmyzsh](https://github.com/ohmyzsh/ohmyzsh) | `~/.oh-my-zsh` |
| zsh-autosuggestions | [zsh-users/zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) | `$ZSH_CUSTOM/plugins/` |
| zsh-syntax-highlighting | [zsh-users/zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting) | `$ZSH_CUSTOM/plugins/` |
| zsh-completions | [zsh-users/zsh-completions](https://github.com/zsh-users/zsh-completions) | `$ZSH_CUSTOM/plugins/`(fpath) |
| zsh-z | [agkozak/zsh-z](https://github.com/agkozak/zsh-z) | `$ZSH_CUSTOM/plugins/`(source) |
| powerlevel10k | [romkatv/powerlevel10k](https://github.com/romkatv/powerlevel10k) | `$ZSH_CUSTOM/themes/` |
| thefuck | 包管理器(brew/apt/dnf) | —(可选) |
| nvm | [nvm-sh/nvm](https://github.com/nvm-sh/nvm) | `~/.nvm`(可选) |

## 平台自适应要点

- **4 个插件(autosuggestions / syntax-highlighting / completions / zsh-z)**:多处路径依次探测(`$ZSH_CUSTOM` → Homebrew → `/usr/share`),找到才加载;completions 加进 `fpath`(在 compinit 前),其余 source
- **thefuck**:`command -v thefuck` 存在才 eval,没装静默跳过
- **PATH**:`/opt/homebrew/bin`、libpq、antigravity、platformio、pnpm 全部 `[ -d ]` 守卫,Linux 上自动忽略 macOS 专属
- **nvm**:先找 `$HOME/.nvm` 再找 Homebrew
- `.local/bin` 用 `$HOME` 而非 `/Users/aber`,跨用户可移植
- **鼠标模式泄漏防护**:precmd hook 每次提示符前清 `1000/1002/1003/1006`;`ssh()` 包装在会话结束后清全部 7 种模式(远程 TUI 会经 SSH 通道把鼠标模式开在本地终端上)

## 新设备安装

```bash
git clone https://github.com/aBER0724/dotfiles.git ~/dotfiles
bash ~/dotfiles/bin/dotfiles setup auto

# 重开 shell
exec zsh
```

> `setup` 会幂等安装 Oh My Zsh、p10k 和插件，已有依赖会显示 `ok` 并跳过。只需修复 Zsh 依赖时可单独运行 `bash ~/dotfiles/zsh/install-deps.sh`。