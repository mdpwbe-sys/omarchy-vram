#!/usr/bin/env bash
# Ask ComfyUI and Ollama to unload models. Does not kill processes.
# Arguments are an origin (or empty) and an Ollama host:port (or empty).
set -u

notify() {
  notify-send --app-name='VRAM' --icon=video-display 'VRAM' "$1" 2>/dev/null || true
}

valid_origin() {
  local url=$1 host port
  [[ $url =~ ^https?://[A-Za-z0-9][A-Za-z0-9.-]*(:[0-9]{1,5})?$ ]] || return 1
  host=${url#*://}
  if [[ $host == *:* ]]; then
    port=${host##*:}
    ((10#$port >= 1 && 10#$port <= 65535)) || return 1
  fi
}

valid_host() {
  local host=$1 port
  [[ $host =~ ^[A-Za-z0-9][A-Za-z0-9.-]*:[0-9]{1,5}$ ]] || return 1
  port=${host##*:}
  ((10#$port >= 1 && 10#$port <= 65535))
}

local_api() {
  curl --noproxy '*' --fail --silent --connect-timeout 2 --max-time 8 "$@"
}

comfy_url=${1:-}
comfy_url=${comfy_url%/}
ollama_host=${2:-}
if [[ $# -gt 2 ]]; then
  notify 'Settings rejected'
  printf 'Settings rejected\n'
  exit 1
fi
if [[ -n $comfy_url ]] && ! valid_origin "$comfy_url"; then
  notify 'ComfyUI URL rejected'
  printf 'ComfyUI URL rejected\n'
  exit 1
fi
if [[ -n $ollama_host ]] && ! valid_host "$ollama_host"; then
  notify 'Ollama host rejected'
  printf 'Ollama host rejected\n'
  exit 1
fi

status=0
lines=()

if [[ -z $comfy_url ]]; then
  lines+=('ComfyUI · skipped')
elif local_api -H 'Content-Type: application/json' \
    --data-binary '{"unload_models":true,"free_memory":true}' \
    "$comfy_url/free" -o /dev/null; then
  lines+=('ComfyUI · unload requested')
elif curl --noproxy '*' --silent --output /dev/null --connect-timeout 2 --max-time 3 "$comfy_url/" ; then
  lines+=('ComfyUI · unload failed')
  status=1
else
  lines+=('ComfyUI · not running')
fi

unload_ollama() {
  local response models model failures=0 count=0
  if [[ -z $ollama_host ]]; then
    printf 'Ollama · skipped\n'
    return 0
  fi
  if ! response=$(local_api "http://$ollama_host/api/ps"); then
    printf 'Ollama · not running\n'
    return 0
  fi
  if ! command -v jq >/dev/null 2>&1; then
    printf 'Ollama · jq is required\n'
    return 1
  fi
  if ! models=$(jq -r '[.models[]? | select(.size_vram > 0) | (.name // .model // empty)] | unique[]' <<<"$response"); then
    printf 'Ollama · unreadable\n'
    return 1
  fi
  if [[ -z $models ]]; then
    printf 'Ollama · nothing in VRAM\n'
    return 0
  fi
  if ! command -v ollama >/dev/null 2>&1; then
    printf 'Ollama · ollama command not found\n'
    return 1
  fi
  while IFS= read -r model; do
    [[ $model =~ ^[A-Za-z0-9_.:@+/-]{1,200}$ && $model != -* ]] || { failures=$((failures + 1)); continue; }
    count=$((count + 1))
    # No leading "--": ollama treats it as the end of options and stops nothing.
    if ! OLLAMA_HOST="$ollama_host" timeout 20s ollama stop "$model" >/dev/null; then
      failures=$((failures + 1))
    fi
  done <<<"$models"
  sleep 0.4
  if ! response=$(local_api "http://$ollama_host/api/ps") ||
      ! models=$(jq -r '[.models[]? | select(.size_vram > 0) | (.name // .model // empty)] | unique[]' <<<"$response"); then
    printf 'Ollama · unreadable after stop\n'
    return 1
  fi
  if [[ -n $models ]]; then
    printf 'Ollama · still in VRAM\n'
    return 1
  fi
  if ((failures > 0)); then
    printf 'Ollama · stop refused, nothing left in VRAM\n'
    return 0
  fi
  printf 'Ollama · unloaded\n'
}

ollama_line=$(unload_ollama) || status=1
lines+=("$ollama_line")
summary=$(printf '%s\n' "${lines[@]}")
printf '%s\n' "$summary"
notify "$summary"
exit "$status"
