#!/usr/bin/env bashio
WAIT_PIDS=()
CONFIG_PATH='/tmp/frpc.toml'

function stop_frpc() {
    bashio::log.info "Shutdown frpc client"
    kill -15 "${WAIT_PIDS[@]}"
}

if ! bashio::config.has_value 'frpc_config'; then
    bashio::log.error "未在插件配置页面填写frpc配置(frpc_config)，请粘贴frpc.toml内容后保存并重启插件"
    bashio::exit.nok
fi

bashio::log.info "从插件配置页面读取frpc配置"
bashio::config 'frpc_config' > "$CONFIG_PATH"

bashio::log.info "查看配置文件内容"
cat "$CONFIG_PATH"

bashio::log.info "尝试启动frpc，若失败，请仔细检查配置，并到插件配置页面修改"

cd /usr/src
./frpc -c "$CONFIG_PATH" & WAIT_PIDS+=($!)

trap "stop_frpc" SIGTERM SIGHUP
wait "${WAIT_PIDS[@]}"
