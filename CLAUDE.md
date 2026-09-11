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
2. **Run time** (`run.sh`, the container CMD): reads the `frpc_config` add-on option (free-form TOML pasted by the user into the HA add-on Configuration page; declared via `options`/`schema` in `config.yaml`), writes it to `/tmp/frpc.toml`, then starts `/usr/src/frpc -c /tmp/frpc.toml`.

**bashio gotcha:** the `homeassistant/*-base:3.10` images bundle an old bashio (~0.14.x) whose wrapper enables `set -o errexit` and whose `bashio::config()` contains a bare `read -r -d ''` that always returns 1. Calling `bashio::config` outside an `if` condition therefore kills `run.sh` with exit 1. Always guard config reads as `FRPC_CONFIG="$(bashio::config 'key' || true)"` (newer bashio versions fixed this; this add-on stays on the old base images).

Key design point: configuration happens entirely through the HA add-on options page — the user pastes their whole `frpc.toml` into the `frpc_config` field (`str?`, may be empty; `run.sh` exits with an error if it is). There is no `/share` mapping; the only persistent directory is `/data` (for cert files etc. referenced in the user's TOML). The repo's `frp-client/frpc.toml` is only an example (installed in the image as `/frpc.toml.example`); `frps.toml` is server-side reference only and unused at runtime.

The add-on needs `host_network`, `NET_ADMIN`, and `/dev/net/tun` (see `config.yaml`) for frp tunneling.

## Git remotes

`origin` = luckywaa/hass-addon-frp-client (this fork); `upstream` = huxiaoxu2019/hass-addon-frp-client (the original project this was forked from).
