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

The add-on version tracks the upstream frp release, so `frp-client/config.yaml` → `version` and `frp-client/build.json` → `args.FRP_VERSION` are normally bumped together. For add-on-only fixes, keep `FRP_VERSION` unchanged and add a `-N` suffix to the config.yaml version (e.g. `0.59.0-1`).

Releases are git tags in the format `<slug>-v<version>` (e.g. `frp_client_zdy-v0.59.0`); HA's add-on store offers each such tag as a selectable install version. A tag must point at a commit whose `config.yaml` version matches the tag.

## frp-client architecture

Two-stage flow:

1. **Build time** (`bootstrap.sh`, invoked from the `Dockerfile`): downloads the `frpc` binary from frp GitHub releases into `/usr/src`. Maps HA arch names to Go arch names (aarch64→arm64, amd64→amd64, armhf/armv7→arm, i386→386).
2. **Run time** (`run.sh`, the container CMD): starts a built-in web config editor — busybox `nc -lk -s 127.0.0.1 -p 8080 -e /www/handler.sh` (the base image's busybox has **no httpd applet**; `nc -e` does) — exposed via HA ingress (`ingress: true` / `ingress_port: 8080` in `config.yaml`; assets in `frp-client/www/`, installed to `/www`). The editor page POSTs the raw TOML text (no URL decoding needed); `handler.sh` writes `/data/frpc.toml` (the runtime config). The page has separate 保存 (save only) and 启动/重启 (save + apply) buttons; `handler.sh` communicates commands to `run.sh` via `/tmp/frpc.cmd` (`start`/`restart`). The main loop in `run.sh` consumes commands, auto-starts frpc at add-on boot when `/data/frpc.toml` exists, and a watchdog re-spawns frpc ~5s after an unexpected death. **There are no add-on options/schema at all** — everything is configured through the web editor.

**bashio gotcha:** the `homeassistant/*-base:3.10` images bundle an old bashio (~0.14.x) whose wrapper enables `set -o errexit` and whose `bashio::config()` contains a bare `read -r -d ''` that always returns 1 — calling it outside an `if` condition kills the script with exit 1 (this add-on previously hit this bug). `run.sh` no longer calls `bashio::config` (no options exist); if it is ever reintroduced, guard reads as `VALUE="$(bashio::config 'key' || true)"`.

Key design point: **the web editor is the direct multi-line paste** — options were removed entirely because **the HA options UI renders `str` fields as single-line inputs and silently drops newlines on paste**. The web server binds to loopback only — the add-on uses `host_network`, so a wildcard bind would expose the unauthenticated editor on the LAN. `/data` is the only persistent directory (config + any cert files referenced in the TOML). The repo's `frp-client/frpc.toml` is only an example (installed in the image as `/frpc.toml.example`); `frps.toml` is server-side reference only and unused at runtime.

The add-on needs `host_network`, `NET_ADMIN`, and `/dev/net/tun` (see `config.yaml`) for frp tunneling.

## Git remotes

`origin` = luckywaa/hass-addon-frp-client (this fork); `upstream` = huxiaoxu2019/hass-addon-frp-client (the original project this was forked from).
