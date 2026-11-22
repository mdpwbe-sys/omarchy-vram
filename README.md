# VRAM

VRAM and RAM meters for the Omarchy bar. Click asks ComfyUI and Ollama to unload models. The plugin does not kill processes, and it does not install a service.

Meters are read locally every few seconds. ComfyUI and Ollama are contacted only on click.

## Install

Omarchy with shell plugins. `nvidia-smi` fills the VRAM meter when it is on `PATH`; RAM still shows without it. The click uses `curl`. Ollama also needs `jq` and the `ollama` command.

```sh
omarchy plugin add https://github.com/mdpwbe-sys/omarchy-vram.git --enable
```

Omit `--enable` to review the checkout first. If the meters do not appear:

```sh
omarchy restart shell
```

## Usage

| Action | Result |
| --- | --- |
| Left-click | Ask ComfyUI `POST /free`, then `ollama stop` for every model that reports VRAM |
| Idle | Two meters and a chip icon |

A model that is mid-request can stay loaded after `ollama stop` returns. The notification says so. On a vertical bar the meters hide and the icon remains.

## Configure

Settings sit on the bar layout entry.

```json
{
  "id": "io.github.mdpwbe-sys.vram",
  "comfyUrl": "http://127.0.0.1:8188",
  "ollamaHost": "127.0.0.1:11434",
  "refreshSec": 3,
  "warnPercent": 85
}
```

`comfyUrl` is an origin. `ollamaHost` is `host:port`. Leave either empty to skip that side. `refreshSec` is 2–60. `warnPercent` colors a meter from 50 to 100.

```sh
omarchy bar move io.github.mdpwbe-sys.vram --section centerEnd
```

## Remove

```sh
omarchy plugin remove io.github.mdpwbe-sys.vram
```
