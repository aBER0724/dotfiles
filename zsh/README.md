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
| powerlevel10k | [romkatv/powerlevel10k](https://github.com/romkatv/powerlevel10k) | `$ZSH_CUSTOM/themes/` |
| thefuck | 包管理器(brew/apt/dnf) | —(可选) |
| nvm | [nvm-sh/nvm](https://github.com/nvm-sh/nvm) | `~/.nvm`(可选) |

## 平台自适应要点

- **syntax-highlighting / p10k**:多处路径依次探测(`$ZSH_CUSTOM` → Homebrew → `/usr/share`),找到才 source
- **thefuck**:`command -v thefuck` 存在才 eval,没装静默跳过
- **PATH**:`/opt/homebrew/bin`、libpq、antigravity、platformio、pnpm 全部 `[ -d ]` 守卫,Linux 上自动忽略 macOS 专属
- **nvm**:先找 `$HOME/.nvm` 再找 Homebrew
- `.local/bin` 用 `$HOME` 而非 `/Users/aber`,跨用户可移植

## 新设备安装

```bash
# 1. 装 oh-my-zsh(若还没有)
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# 2. 装插件/p10k 依赖(幂等,已装跳过)
bash ~/dotfiles/zsh/install-deps.sh

# 3. 链接配置(或 dotfiles link zsh)
dotfiles link zsh

# 4. 重开 shell
exec zsh
```

> 在 macOS 上只链接、不重装插件:p10k/plugins 已在,`install-deps.sh` 会显示 `ok` 跳过。