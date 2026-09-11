#!/usr/bin/env bashio
CONFIG_PATH='/data/frpc.toml'
PID_PATH='/tmp/frpc.pid'
WWW_PORT=8080
FRPC_PID=''
WEB_PID=''

function stop_all() {
    bashio::log.info "Shutdown frp client"
    if [ -n "${FRPC_PID}" ]; then
        kill "${FRPC_PID}" 2>/dev/null || true
    fi
    if [ -n "${WEB_PID}" ]; then
        kill "${WEB_PID}" 2>/dev/null || true
    fi
    exit 0
}
trap stop_all SIGTERM SIGHUP

# HA会挂载/data；裸跑（如独立docker测试）时兜底创建
mkdir -p /data

# 首次启动时，把插件选项里的配置导入为初始文件（之后以网页编辑器保存的文件为准）
if [ ! -f "${CONFIG_PATH}" ]; then
    SEED="$(bashio::config 'frpc_config_base64' || true)"
    if [ -n "${SEED}" ] && [ "${SEED}" != "null" ]; then
        SEED="$(printf '%s' "${SEED}" | tr -d ' \t\r\n' | base64 -d 2>/dev/null || true)"
    else
        SEED="$(bashio::config 'frpc_config' || true)"
        # 兼容单行输入：字面\n转真实换行
        if [ -n "${SEED}" ] && [ "${SEED}" != "null" ]; then
            if [[ "${SEED}" != *$'\n'* && "${SEED}" == *'\n'* ]]; then
                SEED="${SEED//\\n/$'\n'}"
            fi
        fi
    fi
    if [ -n "${SEED}" ] && [ "${SEED}" != "null" ]; then
        printf '%s\n' "${SEED}" > "${CONFIG_PATH}"
        bashio::log.info "已从插件选项导入初始配置到${CONFIG_PATH}"
    fi
fi

# 启动内置网页配置页：busybox nc监听本机回环，handler.sh处理请求（通过HA ingress访问）
nc -lk -s 127.0.0.1 -p ${WWW_PORT} -e /www/handler.sh & WEB_PID=$!
bashio::log.info "网页配置页已启动，可在HA侧边栏打开本加载项直接粘贴配置"

# 主循环：配置文件变化时自动重启frpc；frpc异常退出后自动拉起
LAST_HASH='__init__'
while true; do
    NEW_HASH="$(md5sum "${CONFIG_PATH}" 2>/dev/null || true)"
    NEW_HASH="${NEW_HASH%% *}"

    ALIVE='false'
    if [ -n "${FRPC_PID}" ] && kill -0 "${FRPC_PID}" 2>/dev/null; then
        ALIVE='true'
    fi

    if [ "${NEW_HASH}" != "${LAST_HASH}" ]; then
        if [ "${ALIVE}" = 'true' ]; then
            bashio::log.info "配置已变化，正在重启frpc"
            kill "${FRPC_PID}" 2>/dev/null || true
            sleep 1
            kill -9 "${FRPC_PID}" 2>/dev/null || true
        fi
        if [ -n "${NEW_HASH}" ]; then
            bashio::log.info "启动frpc"
            (cd /usr/src && exec ./frpc -c "${CONFIG_PATH}") & FRPC_PID=$!
            echo "${FRPC_PID}" > "${PID_PATH}"
        else
            FRPC_PID=''
            bashio::log.warning "尚无配置：请通过网页配置页（HA侧边栏）粘贴frpc.toml并保存"
        fi
        LAST_HASH="${NEW_HASH}"
    else
        if [ "${ALIVE}" = 'false' ] && [ -n "${FRPC_PID}" ]; then
            bashio::log.warning "frpc已退出，5秒后重新拉起（若反复退出请检查配置内容）"
            sleep 5
            (cd /usr/src && exec ./frpc -c "${CONFIG_PATH}") & FRPC_PID=$!
            echo "${FRPC_PID}" > "${PID_PATH}"
        fi
    fi
    sleep 2
done
