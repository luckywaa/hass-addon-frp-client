#!/usr/bin/env bashio
WAIT_PIDS=()
CONFIG_PATH='/tmp/frpc.toml'

function stop_frpc() {
    bashio::log.info "Shutdown frpc client"
    kill -15 "${WAIT_PIDS[@]}"
}

# 旧版bashio的config()内部read会返回非零，触发errexit，必须用|| true保护
FRPC_CONFIG="$(bashio::config 'frpc_config' || true)"
FRPC_CONFIG_B64="$(bashio::config 'frpc_config_base64' || true)"

# 页面输入框是单行的，换行会丢失；base64粘贴零损失，作为推荐方式，填写后优先生效
if [[ -n "${FRPC_CONFIG_B64}" && "${FRPC_CONFIG_B64}" != "null" ]]; then
    FRPC_CONFIG="$(printf '%s' "${FRPC_CONFIG_B64}" | tr -d ' \t\r\n' | base64 -d 2>/dev/null || true)"
    if [[ -z "${FRPC_CONFIG}" ]]; then
        bashio::log.error "frpc_config_base64解码失败，请检查是否为完整的base64内容"
        bashio::exit.nok
    fi
fi

if [[ -z "${FRPC_CONFIG}" || "${FRPC_CONFIG}" == "null" ]]; then
    bashio::log.error "未在插件配置页面填写frpc配置(frpc_config或frpc_config_base64)，请填写后保存并重启插件"
    bashio::exit.nok
fi

# 若配置内容被前端挤成单行且只含字面\n，自动转换为真实换行
if [[ "${FRPC_CONFIG}" != *$'\n'* && "${FRPC_CONFIG}" == *'\n'* ]]; then
    bashio::log.warning "配置内容为单行，已自动将字面\\n转换为换行"
    FRPC_CONFIG="${FRPC_CONFIG//\\n/$'\n'}"
fi

printf '%s\n' "${FRPC_CONFIG}" > "${CONFIG_PATH}"

bashio::log.info "已生成配置文件${CONFIG_PATH}，共$(grep -c '' "${CONFIG_PATH}")行"
cat "${CONFIG_PATH}"

bashio::log.info "尝试启动frpc，若失败，请仔细检查配置，并到插件配置页面修改"

cd /usr/src
./frpc -c "${CONFIG_PATH}" & WAIT_PIDS+=($!)

trap "stop_frpc" SIGTERM SIGHUP
wait "${WAIT_PIDS[@]}"
