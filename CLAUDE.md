# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Home Assistant add-on repository (`repository.yaml` at root). The add-on is:

- **frp-client/** — the main add-on (slug `frp_client_zdy`): runs an [frp](https://github.com/fatedier/frp) client (`frpc`) inside Home Assistant. User-facing strings, logs, and descriptions are in Chinese — match that.

## No build/lint/test tooling

There are no tests or linters. The frp-client image is built by Home Assistant's builder infrastructure; verify changes locally with Docker:

```sh
docker build --build-arg BUILD_FROM=homeassistant/amd64-base:3.10 \
  --build-arg BUILD_ARCH=amd64 --build-arg FRP_VERSION=0.59.0 ./frp-client
```

## Version bumping & releasing (frp-client)

The add-on versions itself independently (`1.0.0`+ in `frp-client/config.yaml`); it does **not** track the frp version. `frp-client/build.json` → `args.FRP_VERSION` is only the *built-in default* frpc baked into the image — the web UI can download any other release at runtime.

Releases are git tags in the format `<slug>-v<version>` (e.g. `frp_client_zdy-v1.0.0`); HA's add-on store offers each such tag as a selectable install version. A tag must point at a commit whose `config.yaml` version matches the tag.

## frp-client architecture

Two-stage flow:

1. **Build time** (`bootstrap.sh`, invoked from the `Dockerfile`): downloads the `frpc` binary from frp GitHub releases into `/usr/src`. Maps HA arch names to Go arch names (aarch64→arm64, amd64→amd64, armhf/armv7→arm, i386→386).
2. **Run time** (`run.sh`, the container CMD): starts a built-in web config editor — two busybox `nc -lk -p 8080 -e /www/handler.sh` listeners, one on `127.0.0.1` and one on the `hassio` bridge gateway IP (discovered via `ip addr show hassio`, falling back to `172.30.32.1`) — exposed via HA ingress (`ingress: true` / `ingress_port: 8080` in `config.yaml`; assets in `frp-client/www/`, installed to `/www`). The base image's busybox has **no httpd applet**; `nc -e` does the job. The editor page POSTs the raw TOML text (no URL decoding needed); `handler.sh` writes `/data/frpc.toml` (the runtime config). The page has separate 保存 (save only) and 启动/重启 (save + apply) buttons; `handler.sh` communicates commands to `run.sh` via `/tmp/frpc.cmd` (`start`/`restart`). The main loop in `run.sh` consumes commands, auto-starts frpc at add-on boot when `/data/frpc.toml` exists, and a watchdog re-spawns frpc ~5s after an unexpected death. **There are no add-on options/schema at all** — everything is configured through the web editor.

3. **frp version management** (also on the web page): `handler.sh` exposes `/cgi-bin/frp/installed|available|download|select`. Downloads run detached from the HTTP connection (`nohup /www/dl.sh <ver> <mirror-prefix> &`) so page polling via `/cgi-bin/status` (reading `/tmp/frp.download.state`) tracks progress. `dl.sh` maps `uname -m` → Go arch, downloads `frp_<ver>_linux_<arch>.tar.gz` from GitHub releases (mirror = plain URL-prefix concatenation, falls back to direct if the mirror fails), validates with `frpc -v`, and stores it in `/data/frp-versions/<ver>/frpc`. **Only the currently active version is kept**: every successful switch (download-and-use, select, or switching back to built-in) deletes the other downloaded versions. The active version lives in `/data/frp-version` (missing/empty = built-in `/usr/src/frpc`, whose version `bootstrap.sh` stamps into `/usr/src/.frpc-version`); `run.sh` re-resolves it in `resolve_frpc()` on every start, so a version switch applies on restart/watchdog respawn.

**bashio gotcha:** the `homeassistant/*-base:3.10` images bundle an old bashio (~0.14.x) whose wrapper enables `set -o errexit` (plus nounset/pipefail) and whose `bashio::config()` contains a bare `read -r -d ''` that always returns 1 — calling it outside an `if` condition kills the script with exit 1. Same class of trap: **any command substitution whose pipeline can fail kills the script under errexit+pipefail** (e.g. `VAR="$(ip addr show hassio | ... )"` when the interface is absent — this killed run.sh silently). Guard with a trailing `|| true` *inside* the substitution.

Key design point: **the web editor is the direct multi-line paste** — options were removed entirely because **the HA options UI renders `str` fields as single-line inputs and silently drops newlines on paste**. The web server must listen on the hassio gateway: for `host_network` add-ons the Supervisor ingress proxy targets `docker.network.gateway` (the `hassio` bridge IP, see `supervisor/docker/app.py` `ip_address`), **not** loopback — binding `127.0.0.1` only makes ingress show "应用似乎尚未准备就绪". Never bind `0.0.0.0` though: the add-on is `host_network` and the editor is unauthenticated, so a wildcard bind would expose it to the LAN. Loopback + gateway IP only. `/data` is the only persistent directory (config + any cert files referenced in the TOML). The repo's `frp-client/frpc.toml` is only an example (installed in the image as `/frpc.toml.example`); `frps.toml` is server-side reference only and unused at runtime.

The add-on needs `host_network`, `NET_ADMIN`, and `/dev/net/tun` (see `config.yaml`) for frp tunneling.

## Git remotes

`origin` = luckywaa/hass-addon-frp-client (this fork); `upstream` = huxiaoxu2019/hass-addon-frp-client (the original project this was forked from).
