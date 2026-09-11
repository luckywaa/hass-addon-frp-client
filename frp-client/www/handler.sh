#!/bin/bash
# 由 nc -lk -e 调用：stdin/stdout 即本次HTTP连接
CONTENT_LENGTH=0

IFS= read -r -t 10 REQUEST_LINE || exit 0
REQUEST_LINE="${REQUEST_LINE//$'\r'/}"
METHOD="${REQUEST_LINE%% *}"
ROUTE="${REQUEST_LINE#* }"
ROUTE="${ROUTE%% *}"
ROUTE="${ROUTE%%\?*}"

while IFS= read -r -t 10 LINE; do
    LINE="${LINE//$'\r'/}"
    [ -z "${LINE}" ] && break
    HEADER="${LINE%%:*}"
    case "${HEADER,,}" in
        content-length)
            CONTENT_LENGTH="${LINE#*:}"
            CONTENT_LENGTH="${CONTENT_LENGTH// /}"
            ;;
    esac
done

function read_body() {
    # 读取POST正文（页面直接发原始文本，无URL编码）
    head -c "${CONTENT_LENGTH}" 2>/dev/null
}

function respond() {
    # $1=status $2=content-type；不带Content-Length，靠关连接结束响应
    printf 'HTTP/1.1 %s\r\nContent-Type: %s\r\nConnection: close\r\nCache-Control: no-store\r\n\r\n' "$1" "$2"
}

function frpc_running() {
    [ -f /tmp/frpc.pid ] && kill -0 "$(cat /tmp/frpc.pid 2>/dev/null)" 2>/dev/null
}

function go_arch() {
    case "$(uname -m)" in
        aarch64|arm64)    printf 'arm64' ;;
        x86_64|amd64)     printf 'amd64' ;;
        armv7l|armv6l|arm) printf 'arm' ;;
        i686|i386|386)    printf '386' ;;
        *)                printf 'unknown' ;;
    esac
}

# 设置 BUILTIN / SELECTED / CURRENT 三个版本变量
function current_versions() {
    BUILTIN="$(cat /usr/src/.frpc-version 2>/dev/null || /usr/src/frpc -v 2>/dev/null || printf 'unknown')"
    SELECTED=''
    if [ -s /data/frp-version ]; then
        SELECTED="$(cat /data/frp-version 2>/dev/null)"
    fi
    CURRENT="${BUILTIN}"
    if [ -n "${SELECTED}" ] && [ -x "/data/frp-versions/${SELECTED}/frpc" ]; then
        CURRENT="${SELECTED}"
    fi
}

case "${ROUTE}" in
    "/"|"/index.html")
        respond "200 OK" "text/html; charset=utf-8"
        cat /www/index.html
        ;;
    "/cgi-bin/load")
        respond "200 OK" "application/json"
        jq -Rs '{toml: .}' /data/frpc.toml 2>/dev/null || printf '{"toml":""}'
        ;;
    "/cgi-bin/status")
        respond "200 OK" "application/json"
        RUNNING='false'
        frpc_running && RUNNING='true'
        current_versions
        DL_STATE='idle'; DL_VER=''; DL_ERR=''
        if [ -f /tmp/frp.download.state ]; then
            { read -r DL_STATE || true
              read -r DL_VER || true
              IFS= read -r DL_ERR || true; } < /tmp/frp.download.state
        fi
        printf '{"running":%s,"current":"%s","selected":"%s","builtin":"%s","arch":"%s","dl":{"state":"%s","version":"%s","error":"%s"}}' \
            "${RUNNING}" "${CURRENT}" "${SELECTED}" "${BUILTIN}" "$(go_arch)" \
            "${DL_STATE}" "${DL_VER}" "${DL_ERR}"
        ;;
    "/cgi-bin/save")
        if [ "${METHOD}" != "POST" ]; then
            respond "405 Method Not Allowed" "application/json"
            printf '{"ok":false}'
            exit 0
        fi
        TMP='/data/frpc.toml.tmp'
        if read_body | tr -d '\r' > "${TMP}" && mv -f "${TMP}" /data/frpc.toml; then
            respond "200 OK" "application/json"
            printf '{"ok":true}'
        else
            respond "500 Internal Server Error" "application/json"
            printf '{"ok":false}'
        fi
        ;;
    "/cgi-bin/start"|"/cgi-bin/restart")
        if [ "${METHOD}" != "POST" ]; then
            respond "405 Method Not Allowed" "application/json"
            printf '{"ok":false}'
            exit 0
        fi
        if [ "${ROUTE}" = "/cgi-bin/start" ]; then
            printf 'start' > /tmp/frpc.cmd
        else
            printf 'restart' > /tmp/frpc.cmd
        fi
        respond "200 OK" "application/json"
        printf '{"ok":true}'
        ;;
    "/cgi-bin/frp/installed")
        respond "200 OK" "application/json"
        current_versions
        INSTALLED='[]'
        if [ -d /data/frp-versions ]; then
            FOUND=''
            for D in /data/frp-versions/*/; do
                [ -x "${D}frpc" ] || continue
                FOUND="${FOUND}$(basename "${D}")"$'\n'
            done
            if [ -n "${FOUND}" ]; then
                INSTALLED="$(printf '%s' "${FOUND}" | jq -Rsc 'split("\n")[:-1]')"
            fi
        fi
        printf '{"builtin":"%s","installed":%s}' "${BUILTIN}" "${INSTALLED}"
        ;;
    "/cgi-bin/frp/available")
        # POST正文=镜像前缀(可空)；列表获取失败自动换源
        if [ "${METHOD}" != "POST" ]; then
            respond "405 Method Not Allowed" "application/json"
            printf '{"versions":[]}'
            exit 0
        fi
        respond "200 OK" "application/json"
        MIRROR="$(read_body | tr -d '\r')"
        API='https://api.github.com/repos/fatedier/frp/releases?per_page=30'
        fetch_list() {
            curl -fsSL --max-time 20 "${1}${API}" 2>/dev/null \
                | jq -r '.[].tag_name' 2>/dev/null | sed 's/^v//'
        }
        LIST=''
        if [ -n "${MIRROR}" ]; then
            LIST="$(fetch_list "${MIRROR}")"
            [ -z "${LIST}" ] && LIST="$(fetch_list '')"
        else
            LIST="$(fetch_list '')"
            [ -z "${LIST}" ] && LIST="$(fetch_list 'https://ghfast.top/')"
        fi
        if [ -n "${LIST}" ]; then
            printf '{"versions":%s}' "$(printf '%s\n' "${LIST}" | jq -Rsc 'split("\n")[:-1]')"
        else
            printf '{"versions":[],"error":"获取版本列表失败，请检查网络或勾选镜像加速，也可手动输入版本号"}'
        fi
        ;;
    "/cgi-bin/frp/download")
        # POST正文两行：版本号、镜像前缀(可空)；后台执行，进度经status轮询
        if [ "${METHOD}" != "POST" ]; then
            respond "405 Method Not Allowed" "application/json"
            printf '{"ok":false}'
            exit 0
        fi
        BODY="$(read_body)"
        V="$(printf '%s' "${BODY}" | head -n1 | tr -d '\r')"
        M="$(printf '%s' "${BODY}" | tail -n1 | tr -d '\r')"
        if [ -z "${V}" ] || printf '%s' "${V}" | grep -q '[^0-9.]'; then
            respond "400 Bad Request" "application/json"
            printf '{"ok":false,"error":"版本号无效"}'
            exit 0
        fi
        if [ -f /tmp/frp.download.state ] && head -n1 /tmp/frp.download.state 2>/dev/null | grep -q '^running$'; then
            respond "409 Conflict" "application/json"
            printf '{"ok":false,"error":"已有下载进行中"}'
            exit 0
        fi
        nohup /www/dl.sh "${V}" "${M}" >/tmp/frp.download.log 2>&1 &
        respond "200 OK" "application/json"
        printf '{"ok":true}'
        ;;
    "/cgi-bin/frp/select")
        # POST正文=版本号(空=用回内置版本)；已安装才允许切换
        if [ "${METHOD}" != "POST" ]; then
            respond "405 Method Not Allowed" "application/json"
            printf '{"ok":false}'
            exit 0
        fi
        V="$(read_body | tr -d '\r')"
        if [ -n "${V}" ]; then
            if ! printf '%s' "${V}" | grep -q '^[0-9][0-9.]*$'; then
                respond "400 Bad Request" "application/json"
                printf '{"ok":false,"error":"版本号无效"}'
                exit 0
            fi
            if [ ! -x "/data/frp-versions/${V}/frpc" ]; then
                respond "400 Bad Request" "application/json"
                printf '{"ok":false,"error":"该版本未安装"}'
                exit 0
            fi
            printf '%s' "${V}" > /data/frp-version
            # 只保留切换到的版本，清理其他已下载版本
            for D in /data/frp-versions/*/; do
                [ "${D}" = "/data/frp-versions/${V}/" ] && continue
                rm -rf "${D}" 2>/dev/null
            done
        else
            rm -f /data/frp-version
            # 切回内置版本：清空已下载版本
            for D in /data/frp-versions/*/; do
                rm -rf "${D}" 2>/dev/null
            done
        fi
        RESTART='false'
        if frpc_running; then
            printf 'restart' > /tmp/frpc.cmd
            RESTART='true'
        fi
        respond "200 OK" "application/json"
        printf '{"ok":true,"restarting":%s}' "${RESTART}"
        ;;
    *)
        respond "404 Not Found" "text/plain"
        printf 'not found'
        ;;
esac
exit 0
