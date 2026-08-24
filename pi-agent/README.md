# pi-agent

[pi coding agent](https://pi.dev) 配置,跨设备同步。
只同步声明式配置;密钥、缓存、会话全部留在各设备本地。

## 来源

- [pi coding agent](https://pi.dev) — 本体(核心 CLI)
- 22 个 npm 插件包 + 自研扩展,见「插件清单」

## 目录结构

```
pi-agent/
├── settings.json     # 插件列表(packages)、主题、默认 provider/model
├── models.json       # 自定义 provider 定义(new-api)— 无密钥
└── extensions/       # 自定义扩展(pi-autoresearch 白名单、herdr state 工具)
```

## 插件清单(packages,来自 settings.json)

| 包 | 用途 |
|----|------|
| `@juanibiapina/pi-extension-settings` | 扩展设置面板 |
| `@juanibiapina/pi-powerbar` | 状态栏 |
| `pi-hashline-edit-pro` | hashline 编辑 |
| `pi-slopchop` | 输出精简 |
| `@narumitw/pi-goal` | goal 追踪 |
| `@narumitw/pi-plan-mode` | 计划模式 |
| `@narumitw/pi-subagents` | 子代理编排 |
| `@juicesharp/rpiv-ask-user-question` | 结构化提问 |
| `@juicesharp/rpiv-todo` | 任务清单 |
| `@narumitw/pi-btw` | by-the-way |
| `pi-mcp-adapter` | MCP 适配 |
| `@ff-labs/pi-fff` | 文件查找(fff) |
| `pi-rtk-optimizer` | 上下文优化 |
| `pi-cache-optimizer` | 缓存优化 |
| `@narumitw/pi-lsp` | LSP 集成 |
| `pi-agent-browser-native` | 浏览器自动化 |
| `pi-add-dir` | 外部目录加载 |
| `pi-workspace-history` | 工作区历史 |
| `@narumitw/pi-caffeinate` | 防休眠 |
| `@tmustier/pi-raw-paste` | 原始粘贴 |
| `@victor-software-house/pi-curated-themes` | 主题集(flexoki-dark) |
| `pi-autoresearch` | 自动调研流水线 |

## 自定义扩展(extensions/)

| 文件 | 用途 |
|------|------|
| `pi-autoresearch.json` | autoresearch 白名单配置 |
| `herdr-agent-state.ts` | herdr 插件状态同步工具 |

## Provider(models.json)

| Provider | baseUrl | 说明 |
|----------|---------|------|
| `new-api` | `https://new-api.aberrrrrrr.space/v1` | 自托管 OpenAI 兼容网关,含 gpt-5.x / glm 等模型 |

默认 provider/model 在 `settings.json`(`defaultProvider: new-api`)。

## 为什么 settings.json 里的 packages 是唯一真源

pi 用 `packages` 数组记录**插件来源**(如 `npm:pi-subagents`),
启动时自动重装缺失包,因此 `~/.pi/agent/npm/`、`git/` 缓存**各设备独立、不同步**。

## 明确不同步的内容

| 文件/目录 | 原因 |
|-----------|------|
| `auth.json` | API 密钥,每设备各配各的 |
| `models-store.json` | provider 目录缓存,机器本地 |
| `sessions/` `state/` `fff/` | 会话/状态,机器本地 |
| `npm/` `git/` | 包安装缓存,自动重建 |

## 新设备安装

```bash
# 1. 建目录 + 链接配置(或直接 dotfiles install pi)
mkdir -p ~/.pi/agent
ln -sf ~/dotfiles/pi-agent/settings.json ~/.pi/agent/settings.json
ln -sf ~/dotfiles/pi-agent/models.json  ~/.pi/agent/models.json
ln -sf ~/dotfiles/pi-agent/extensions  ~/.pi/agent/extensions

# 2. 每设备配置一次 API key(无登录,全部 key-based;auth.json 不同步)
printf '{"new-api": {"type": "api_key", "key": "sk-..."}}' > ~/.pi/agent/auth.json
chmod 600 ~/.pi/agent/auth.json
# 或 export $NEW_API_KEY 并在 models.json 里 apiKey 引用

# 3. 启动
pi   # 首次启动自动安装全部 npm 插件
```