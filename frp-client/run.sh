#!/usr/bin/env bashio
WAIT_PIDS=()
CONFIG_PATH='/share/frpc.toml'

function stop_frpc() {
    bashio::log.info "Shutdown frpc client"
    kill -15 "${WAIT_PIDS[@]}"
}


# cp $DEFAULT_CONFIG_PATH $CONFIG_PATH
if [ ! -f "$CONFIG_PATH" ]; then
    # Log the message with a timestamp
    bashio::log.info "配置文件$CONFIG_PATH不存在"
else
    bashio::log.info "查看配置文件内容"

    cat $CONFIG_PATH
    bashio::log.info "尝试启动frpc，若失败，则仔细检查配置文件，并到路径$CONFIG_PATH修改配置"
    cd /usr/src
    ./frpc -c $CONFIG_PATH & WAIT_PIDS+=($!)
    
    tail -f /share/frpc.log &
    
    trap "stop_frpc" SIGTERM SIGHUP
    wait "${WAIT_PIDS[@]}"
fi


