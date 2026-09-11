#!/usr/bin/env bashio
CONFIG_PATH='/data/frpc.toml'
PID_PATH='/tmp/frpc.pid'
CMD_PATH='/tmp/frpc.cmd'
WWW_PORT=8080
FRPC_PID=''
WEB_PID=''
EXPECTED_RUNNING='false'

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

# 启动内置网页配置页：busybox nc监听本机回环，handler.sh处理请求（通过HA ingress访问）
nc -lk -s 127.0.0.1 -p ${WWW_PORT} -e /www/handler.sh & WEB_PID=$!
bashio::log.info "网页配置页已启动，可在HA侧边栏打开本加载项"

# 已有配置则自动启动frpc；没有则等待网页端发来的启动命令
if [ -s "${CONFIG_PATH}" ]; then
    printf 'start' > "${CMD_PATH}"
else
    bashio::log.warning "尚无配置：请通过网页配置页（HA侧边栏）粘贴frpc.toml，保存后点击启动"
fi

function start_frpc() {
    (cd /usr/src && exec ./frpc -c "${CONFIG_PATH}") & FRPC_PID=$!
    echo "${FRPC_PID}" > "${PID_PATH}"
    EXPECTED_RUNNING='true'
}

function stop_frpc() {
    if [ -n "${FRPC_PID}" ]; then
        kill "${FRPC_PID}" 2>/dev/null || true
        sleep 1
        kill -9 "${FRPC_PID}" 2>/dev/null || true
    fi
    FRPC_PID=''
    EXPECTED_RUNNING='false'
}

# 主循环：处理网页命令（start/restart），看门狗在frpc异常退出后自动拉起
while true; do
    CMD=''
    if [ -f "${CMD_PATH}" ]; then
        read -r CMD < "${CMD_PATH}" 2>/dev/null || true
        rm -f "${CMD_PATH}" 2>/dev/null || true
    fi

    ALIVE='false'
    if [ -n "${FRPC_PID}" ] && kill -0 "${FRPC_PID}" 2>/dev/null; then
        ALIVE='true'
    fi

    if [ "${CMD}" = 'restart' ] || { [ "${CMD}" = 'start' ] && [ "${ALIVE}" = 'false' ]; }; then
        if [ "${ALIVE}" = 'true' ]; then
            bashio::log.info "重启frpc"
            stop_frpc
        else
            bashio::log.info "启动frpc"
        fi
        if [ -s "${CONFIG_PATH}" ]; then
            start_frpc
        else
            bashio::log.warning "配置为空，无法启动frpc，请先在网页配置页保存配置"
        fi
    fi

    if [ "${EXPECTED_RUNNING}" = 'true' ]; then
        ALIVE='false'
        if [ -n "${FRPC_PID}" ] && kill -0 "${FRPC_PID}" 2>/dev/null; then
            ALIVE='true'
        fi
        if [ "${ALIVE}" = 'false' ]; then
            bashio::log.warning "frpc已退出，5秒后重新拉起（若反复退出请检查配置内容）"
            sleep 5
            start_frpc
        fi
    fi
    sleep 1
done
