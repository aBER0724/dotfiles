#!/usr/bin/env bash
# kitty tab bar 右侧状态: CPU / Mem / 时间
# 输出格式: "CPU 12%  Mem 4.2G/16G  02/16 16:23"
# 跨 macOS (Darwin) 和 Linux。

set -u

os=$(uname -s)

cpu_percent() {
  if [ "$os" = "Darwin" ]; then
    # top -l 2 第二次采样才准; -n 0 不列进程
    local line idle
    line=$(top -l 2 -n 0 -s 1 2>/dev/null | grep "CPU usage" | tail -1)
    # 形如: CPU usage: 15.10% user, 9.37% sys, 75.52% idle
    idle=$(echo "$line" | sed -E 's/.* ([0-9.]+)% idle.*/\1/')
    awk -v i="$idle" 'BEGIN { printf "%.0f", 100 - i }'
  else
    # Linux: 读 /proc/stat 两次, 计算 delta
    local a b
    read -r _ a < /proc/stat
    sleep 1
    read -r _ b < /proc/stat
    awk -v a="$a" -v b="$b" '
      BEGIN {
        split(a, A, " "); split(b, B, " ");
        ta = 0; tb = 0;
        for (i = 1; i <= 8; i++) { ta += A[i]; tb += B[i] }
        idleA = A[4] + A[5]; idleB = B[4] + B[5];
        busy  = (tb - ta) - (idleB - idleA);
        total = tb - ta;
        if (total > 0) printf "%.0f", busy * 100 / total;
        else           printf "0";
      }'
  fi
}

mem_usage() {
  if [ "$os" = "Darwin" ]; then
    local page_size total_bytes
    page_size=$(vm_stat | awk '/page size of/ {print $8}')
    total_bytes=$(sysctl -n hw.memsize)

    local active wired
    active=$(vm_stat | awk '/^Pages active:/     {gsub(/\./,"",$3); print $3}')
    wired=$(vm_stat  | awk '/^Pages wired down:/ {gsub(/\./,"",$4); print $4}')

    # 已用 ≈ active + wired (inactive 可被回收,不算真正"在用")
    local used_bytes=$(( (active + wired) * page_size ))
    awk -v u="$used_bytes" -v t="$total_bytes" 'BEGIN {
      printf "%.1fG/%.0fG", u/1073741824, t/1073741824
    }'
  else
    # Linux: 用 MemAvailable 反推已用
    awk '
      /^MemTotal:/     { t = $2 }
      /^MemAvailable:/ { a = $2 }
      END {
        u = t - a;
        printf "%.1fG/%.0fG", u/1048576, t/1048576
      }' /proc/meminfo
  fi
}

main() {
  local cpu mem_percent
  cpu=$(cpu_percent)
  if [ "$os" = "Darwin" ]; then
    local page_size total_bytes active wired used_bytes
    page_size=$(vm_stat | awk '/page size of/ {print $8}')
    total_bytes=$(sysctl -n hw.memsize)
    active=$(vm_stat | awk '/^Pages active:/     {gsub(/\./,"",$3); print $3}')
    wired=$(vm_stat  | awk '/^Pages wired down:/ {gsub(/\./,"",$4); print $4}')
    used_bytes=$(( (active + wired) * page_size ))
    mem_percent=$(awk -v u="$used_bytes" -v t="$total_bytes" 'BEGIN { printf "%.0f", u * 100 / t }')
  else
    mem_percent=$(awk '/^MemTotal:/ {t=$2} /^MemAvailable:/ {a=$2} END {printf "%.0f", (t-a)*100/t}' /proc/meminfo)
  fi
  printf "%s|%s" "$cpu" "$mem_percent"
}

main "$@"
