#!/usr/bin/env node
// nbshell chromium-controller — 让运行中的 Chromium 支持主题热重载。
//
// 原理:Chromium 的 CDP `Extensions` 域(`Extensions.loadUnpacked` 可在运行
// 中重装主题扩展并立即重画 UI)只在同时满足以下条件时可用:
//   1. 通过私有管道传输(`--remote-debugging-pipe`,fd 3/4)而非 TCP 端口
//      —— Chrome 136 起 TCP 远程调试在默认 profile 下被禁用,且管道不对
//      本地其他进程暴露,安全性更好;
//   2. 附带 `--enable-unsafe-extension-debugging` 旗标。
// 管道必须在浏览器 exec 时就交给它,因此本脚本就是浏览器的父进程:
// 以管道模式 spawn chromium,常驻并监听控制 socket。
//
// 控制 socket: $XDG_RUNTIME_DIR/nbshell-chromium.sock
//   "reload\n" → Extensions.loadUnpacked(~/.config/nbshell/chromium-theme)
//                回复 JSON 结果(theme-hook.sh 换主题后调用)
//   "ping\n"   → 回复 "pong <pid>"
//
// 若 socket 已存活(浏览器已受控),本脚本退化为普通启动 —— chromium 的
// singleton 机制会把参数转发给已运行实例并新开窗口,自身随即退出。
//
// 由 theme-hook.sh 生成的 ~/.local/share/applications/chromium.desktop
// 将 Exec 指向本脚本;终端里直接运行 `chromium` 不经过本脚本,主题仍在
// 下次启动时由 chromium-flags.conf 的 --load-extension 应用。

import { spawn } from 'node:child_process';
import { createServer, createConnection } from 'node:net';
import { existsSync, unlinkSync, appendFileSync, mkdirSync } from 'node:fs';
import { dirname } from 'node:path';

const RUNTIME = process.env.XDG_RUNTIME_DIR || `/run/user/${process.uid}`;
const SOCK = `${RUNTIME}/nbshell-chromium.sock`;
const CONFIG = process.env.XDG_CONFIG_HOME || `${process.env.HOME}/.config`;
const THEME_DIR = `${CONFIG}/nbshell/chromium-theme`;
const CHROMIUM = '/usr/bin/chromium';
const LOG = `${process.env.HOME}/.local/state/nbshell/chromium-controller.log`;

const log = (msg) => {
  try {
    mkdirSync(dirname(LOG), { recursive: true });
    appendFileSync(LOG, `${new Date().toISOString()} ${msg}\n`);
  } catch { /* 日志失败不影响主流程 */ }
};

const passthroughArgs = process.argv.slice(2);

// 已有受控实例?是则普通启动,靠 singleton 转发。
const controllerAlive = await new Promise((resolve) => {
  const probe = createConnection(SOCK);
  probe.once('connect', () => { probe.end(); resolve(true); });
  probe.once('error', () => resolve(false));
});

if (controllerAlive) {
  log('controller already active — plain launch (singleton forward)');
  const child = spawn(CHROMIUM, passthroughArgs, { stdio: 'inherit' });
  child.on('exit', (code) => process.exit(code ?? 0));
} else {
  if (existsSync(SOCK)) unlinkSync(SOCK); // 清掉残留 socket 文件

  const proc = spawn(
    CHROMIUM,
    ['--remote-debugging-pipe', '--enable-unsafe-extension-debugging', ...passthroughArgs],
    { stdio: ['ignore', 'ignore', 'ignore', 'pipe', 'pipe'] },
  );
  log(`chromium pid ${proc.pid} (pipe mode)`);

  // —— CDP over fd 3/4(消息以 \0 分隔)——
  const w = proc.stdio[3];
  const r = proc.stdio[4];
  let buf = '';
  let nextId = 0;
  const pending = new Map();

  r.on('data', (chunk) => {
    buf += chunk.toString('utf8');
    let i;
    while ((i = buf.indexOf('\0')) >= 0) {
      const msg = buf.slice(0, i);
      buf = buf.slice(i + 1);
      try {
        const parsed = JSON.parse(msg);
        const cb = pending.get(parsed.id);
        if (cb) { pending.delete(parsed.id); cb(parsed); }
      } catch { log(`unparseable message: ${msg.slice(0, 120)}`); }
    }
  });
  r.on('end', () => log('devtools pipe read end closed'));

  const call = (method, params = {}) => new Promise((resolve) => {
    const id = ++nextId;
    const timer = setTimeout(() => { pending.delete(id); resolve({ error: 'timeout' }); }, 8000);
    pending.set(id, (m) => { clearTimeout(timer); resolve(m); });
    w.write(JSON.stringify({ id, method, params }) + '\0');
  });

  // —— 控制 socket ——
  const server = createServer((conn) => {
    conn.setEncoding('utf8');
    conn.on('data', async (data) => {
      const cmd = (data || '').trim();
      if (cmd === 'reload') {
        const res = await call('Extensions.loadUnpacked', { path: THEME_DIR });
        log(`reload -> ${JSON.stringify(res).slice(0, 200)}`);
        conn.end(JSON.stringify(res.result ?? res.error ?? res));
      } else if (cmd === 'ping') {
        conn.end(`pong ${proc.pid}`);
      } else {
        conn.end('unknown command');
      }
    });
    conn.on('error', () => {});
  });
  server.listen(SOCK);

  const cleanup = () => { try { unlinkSync(SOCK); } catch { /* already gone */ } };
  proc.on('exit', (code) => { log(`chromium exited (${code})`); cleanup(); process.exit(0); });
  process.on('SIGTERM', () => proc.kill('SIGTERM'));
  process.on('SIGINT', () => proc.kill('SIGINT'));
  process.on('exit', cleanup);
}
