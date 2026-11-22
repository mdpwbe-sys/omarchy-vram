#!/usr/bin/env bash
# One line: vram_used_mib vram_total_mib ram_used_mib ram_total_mib
set -u

ram_used=0
ram_total=0
if [[ -r /proc/meminfo ]]; then
  read -r ram_used ram_total < <(awk '/MemTotal:/ {t=$2} /MemAvailable:/ {a=$2} END {printf "%d %d\n", int((t - a) / 1024), int(t / 1024)}' /proc/meminfo)
fi

vram_used=0
vram_total=0
if command -v nvidia-smi >/dev/null 2>&1; then
  line=$(timeout 2 nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null | head -n 1 || true)
  line=${line// /}
  IFS=',' read -r vram_used vram_total <<<"$line"
fi

vram_used=${vram_used//[^0-9]/}
vram_total=${vram_total//[^0-9]/}
ram_used=${ram_used//[^0-9]/}
ram_total=${ram_total//[^0-9]/}
printf '%s %s %s %s\n' "${vram_used:-0}" "${vram_total:-0}" "${ram_used:-0}" "${ram_total:-0}"
