# Neovim Keymaps 速查表

> 生成自运行中的配置 (LazyVim v16 + nvim 0.12.5)
> **`<leader>` = 空格键**
> ⭐ = 用户自定义 (`lua/config/keymaps.lua`)

---

## ⭐ 用户自定义键位

| 按键 | 模式 | 作用 |
|---|---|---|
| `<C-s>` | n/i/v/s | 保存文件 |
| `<leader>w` | n | 保存 |
| `Y` | n | 复制到行尾 (对齐 `D`/`C`) |
| `U` | n | 重做 redo (对齐 `u` 撤销) |
| `<Esc><Esc>` | t | 终端模式退出到 Normal |
| `<C-d>` | n/x | 半页下 + 居中 |
| `<C-u>` | n/x | 半页上 + 居中 |
| `n` | n | 下一个搜索 + 居中 |
| `N` | n | 上一个搜索 + 居中 |
| `<leader>w=` | n | 窗口均分 |
| `<leader>wm` | n | 最大化 / 还原当前窗口 |
| `[x` | n | quickfix 上一个 |
| `]x` | n | quickfix 下一个 |
| `<leader>sa` | n | 全选 (`ggVG`) |

---

## `<leader>f` — 文件 / 查找

| 按键 | 作用 |
|---|---|
| `<leader>ff` | 找文件 (根目录) |
| `<leader>fF` | 找文件 (当前目录 cwd) |
| `<leader>fg` | 找文件 (git 文件) |
| `<leader>fb` | 缓冲区列表 |
| `<leader>fB` | 全部缓冲区 |
| `<leader>fp` | 项目列表 |
| `<leader>fr` / `<leader>fR` | 最近文件 (root / cwd) |
| `<leader>fe` | Snacks 文件树 (root) |
| `<leader>fE` | Snacks 文件树 (cwd) |
| `<leader>fc` | 配置文件 |
| `<leader>fn` | 新建文件 |
| `<leader>ft` / `<leader>fT` | 终端 (root / cwd) |

## `<leader>s` — 搜索

| 按键 | 作用 |
|---|---|
| `<leader>sg` | Grep (根目录) |
| `<leader>sG` | Grep (cwd) |
| `<leader>sb` | 缓冲区行搜索 |
| `<leader>sB` | 打开的缓冲区搜索 |
| `<leader>sw` / `<leader>sW` | 选词搜索 (root / cwd) |
| `<leader>sr` | 搜索并替换 |
| `<leader>sd` | 诊断列表 |
| `<leader>sD` | 当前缓冲区诊断 |
| `<leader>st` | TODO 注释 |
| `<leader>sT` | TODO/FIXME 注释 |
| `<leader>sc` | 命令历史 |
| `<leader>sh` | 帮助页面 |
| `<leader>si` | 图标列表 |
| `<leader>sj` | 跳转列表 |
| `<leader>sk` | 查看键位 |
| `<leader>sl` | Location List |
| `<leader>sm` | 标记列表 |
| `<leader>sq` | Quickfix List |
| `<leader>su` | 撤销树 |
| `<leader>s"` | 寄存器 |
| `<leader>s/` | 搜索历史 |
| `<leader>sM` | Man 手册 |
| `<leader>sH` | 高亮列表 |
| `<leader>sR` | 恢复上次搜索 |

### `<leader>sn` — Noice 通知
`<leader>sna` 全部 · `<leader>snd` 关闭全部 · `<leader>snh` 历史 · `<leader>snl` 最后一条 · `<leader>snt` 通知选择器

## `<leader>g` — Git

| 按键 | 作用 |
|---|---|
| `<leader>gs` | Git 状态 |
| `<leader>gg` / `<leader>gG` | Lazygit (root / cwd) |
| `<leader>gL` | Git 日志 |
| `<leader>gf` | 当前文件历史 |
| `<leader>gb` | Blame 当前行 |
| `<leader>gd` | Diff (hunk) |
| `<leader>gD` | Diff (origin) |
| `<leader>gB` / `<leader>gY` | GitHub 打开 / 复制链接 |
| `<leader>gS` | Git Stash |
| `<leader>gi` / `<leader>gI` | GitHub Issues (open / all) |
| `<leader>gp` / `<leader>gP` | GitHub PRs (open / all) |

## `<leader>x` — 诊断 / 问题列表

| 按键 | 作用 |
|---|---|
| `<leader>xx` | 诊断 (Trouble) |
| `<leader>xX` | 当前缓冲区诊断 |
| `<leader>xq` / `<leader>xl` | Quickfix / Loclist |
| `<leader>xQ` / `<leader>xL` | Trouble 版 Quickfix / Loclist |
| `<leader>xt` | TODO (Trouble) |
| `<leader>xT` | TODO/FIXME (Trouble) |

## `<leader>c` — 代码操作

| 按键 | 作用 |
|---|---|
| `<leader>cf` | 格式化 |
| `<leader>cF` | 格式化注入语言 |
| `<leader>cd` | 当前行诊断 |
| `<leader>cs` | 符号 (Trouble symbols) |
| `<leader>cS` | LSP 引用/定义 (Trouble) |
| `<leader>cm` | Mason 工具管理 |

## `<leader>u` — UI 开关

| 按键 | 作用 |
|---|---|
| `<leader>uZ` | 缩放模式 (Zoom) |
| `<leader>uz` | 禅模式 (Zen) |
| `<leader>uT` | Treesitter 高亮 |
| `<leader>uh` | Inlay Hints |
| `<leader>ug` | 缩进线 (indent guides) |
| `<leader>uF` / `<leader>uf` | 自动格式化 (缓冲 / 全局) |
| `<leader>uG` | Git Signs |
| `<leader>ur` | 重绘 + 清高亮 + diff 更新 |
| `<leader>un` | 关闭全部通知 |
| `<leader>ux` | Illuminate 当前词高亮 |
| `<leader>uw` | 换行 |
| `<leader>ud` | 诊断显示 |
| `<leader>ub` | 深色背景 |
| `<leader>ul` / `<leader>uL` | 行号 / 相对行号 |
| `<leader>us` | 拼写检查 |
| `<leader>uc` | Conceal 级别 |
| `<leader>uD` | 窗口变暗 |
| `<leader>uA` | Tabline 显示 |
| `<leader>uC` | 配色方案列表 |
| `<leader>ua` | 动画 |
| `<leader>up` | Mini Pairs |
| `<leader>uI` | 检查 Tree-sitter 解析树 |
| `<leader>ui` | 检查光标位置 |

## `<leader>b` — 缓冲区

| 按键 | 作用 |
|---|---|
| `<leader>bb` / `` ` `` | 切换到上一个缓冲区 |
| `<leader>bd` | 删除缓冲区 |
| `<leader>bD` | 删除缓冲区 + 窗口 |
| `<leader>bi` | 删除隐藏缓冲区 |
| `<leader>bo` | 删除其它缓冲区 |
| `<leader>bp` | 固定 / 取消固定 |
| `<leader>bj` | 挑选缓冲区 |
| `<leader>bl` / `<leader>br` | 关闭左侧 / 右侧缓冲区 |
| `<leader>bP` | 关闭未固定的缓冲区 |
| Tab `[`/`]`/`d`/`f`/`l`/`o` | 标签页导航 (上一个/下一个/关闭/第一个/最后一个/只留当前) |

## `<leader>q` — 会话 / 退出

| 按键 | 作用 |
|---|---|
| `<leader>qq` | 退出全部 |
| `<leader>qs` | 恢复会话 |
| `<leader>ql` | 恢复上次会话 |
| `<leader>qd` | 不保存当前会话 |
| `<leader>qS` | 选择会话 |

## 其它 `<leader>`

| 按键 | 作用 |
|---|---|
| `<leader>e` / `<leader>E` | 文件树 (root / cwd) |
| `<leader>l` | Lazy 插件管理 |
| `<leader>n` | 通知历史 |
| `<leader>dpp` / `<leader>dps` / `<leader>dph` | 性能分析 |

---

## NORMAL 常用默认键

| 按键 | 作用 |
|---|---|
| `H` / `L` | 上一个 / 下一个缓冲区 |
| `-` / `\|` | 下方 / 右侧分屏 |
| `<C-h/j/k/l>` | 窗口间跳转 |
| `<C-Up/Down/Left/Right>` | 窗口大小 ±2 |
| `[d` / `]d` | 上一个 / 下一个诊断 |
| `[e` / `]e` | 上一个 / 下一个错误 |
| `[w` / `]w` | 上一个 / 下一个警告 |
| `[b` / `]b` | 上一个 / 下一个缓冲区 |
| `[q` / `]q` | 上一个 / 下一个 quickfix / Trouble |
| `[t` / `]t` | 上一个 / 下一个 TODO |
| `[[` / `]]` | 上一个 / 下一个 LSP 引用 |
| `[T` / `]T` `[A` / `]A` `[L` / `]L` `[Q` / `]Q` | arglist / 文件列表导航 |
| `[` / `]` | 光标上方 / 下方加空行 |
| `[i` / `]i` | 跳到作用域顶部 / 底部 |
| `grr` | LSP 引用 |
| `grn` | LSP 重命名 |
| `gri` | LSP 实现 |
| `gra` | LSP code action |
| `grt` | LSP 类型定义 |
| `grx` | LSP codelens 运行 |
| `gO` | LSP 文档符号 |
| `gcc` / `gc` / `gcO` / `gco` | 注释行 / 注释块 / 上方注释 / 下方注释 |
| `s` | Flash 快速跳转 |
| `S` | Flash Treesitter 选择 |
| `<C-Space>` | Treesitter 增量选择 |
| `gx` | 打开光标下链接 (浏览器) |

## INSERT 模式

| 按键 | 作用 |
|---|---|
| `Tab` / `S-Tab` | Snippet 前进 / 后退 |
| `M-j` / `M-k` | 当前行下移 / 上移 |
| `C-u` / `C-w` | 删到行首 / 删单词 (带撤销断点) |
| `C-b` / `C-f` | 滚动 |
| `( ) [ ] { }` 等 | MiniPairs 自动配对 |
| `Backspace` | MiniPairs 智能删除 |

## VISUAL 模式

| 按键 | 作用 |
|---|---|
| `>` / `<` | 缩进并保持选中 |
| `M-j` / `M-k` | 选中块下移 / 上移 |
| `@` / `Q` | 对选区执行宏 |
| `s` / `S` | Flash 选择 / Treesitter 选择 |

## TERMINAL 模式

| 按键 | 作用 |
|---|---|
| `<Esc><Esc>` ⭐ | 退出到 Normal |
| `<C-/>` | 打开终端 (root) |

## blink.cmp 补全键 (弹窗打开时)

| 按键 | 作用 |
|---|---|
| `<C-space>` | 主动弹出补全 |
| `Tab` | 接受候选 (或 snippet 前进) |
| `Enter` | 接受 |
| `<C-e>` | 取消并关闭弹窗 |
| `↑` / `↓` | 选择候选 (**不会写入文本**,需显式接受) |
| `S-Tab` | snippet 后退 |

> blink.cmp 配置: `auto_insert = false` — 打字时不会自动填入候选，
> 只有按 `Tab` / `Enter` / `<C-y>` 才接受 (见 `lua/plugins/blink.lua`)

---

## smart-splits (窗口调整)

| 按键 | 作用 |
|---|---|
| `M-h` | 左窗口调宽 |
| `M-j` | 下窗口调高 |
| `M-k` | 上窗口调高 |
| `M-l` | 右窗口调宽 |

---

## 提示

- 随时按 `<leader>sk` 或 `?` 在 which-key 里浏览全部键位
- 命令模式 `:map` / `:nmap` / `:imap` 可查原始定义
