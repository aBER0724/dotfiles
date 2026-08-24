#!/bin/bash
# Kaku status bar stats script
# Outputs: cpu_pct mem_pct
CORES=$(sysctl -n hw.ncpu 2>/dev/null || echo 1)
CPU_SUM=$(ps -A -o %cpu 2>/dev/null | awk '{s+=$1} END {printf "%.0f", s}')
CPU_PCT=$((CPU_SUM / CORES))

MEM_TOTAL=$(sysctl -n hw.memsize 2>/dev/null || echo 1)
MEM_USED=$(ps -A -o rss 2>/dev/null | awk '{s+=$1} END {printf "%.0f", s*1024}')
if [ "$MEM_TOTAL" -gt 0 ] 2>/dev/null; then
  MEM_PCT=$((MEM_USED * 100 / MEM_TOTAL))
else
  MEM_PCT=0
fi

TMP=$(mktemp /tmp/kaku-stats.XXXXX)
echo "${CPU_PCT} ${MEM_PCT}" > "$TMP"
mv "$TMP" /tmp/kaku-stats