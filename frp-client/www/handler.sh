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

function respond() {
    # $1=status $2=content-type；不带Content-Length，靠关连接结束响应
    printf 'HTTP/1.1 %s\r\nContent-Type: %s\r\nConnection: close\r\nCache-Control: no-store\r\n\r\n' "$1" "$2"
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
        if [ -f /tmp/frpc.pid ] && kill -0 "$(cat /tmp/frpc.pid 2>/dev/null)" 2>/dev/null; then
            printf '{"running":true}'
        else
            printf '{"running":false}'
        fi
        ;;
    "/cgi-bin/save")
        # 页面直接POST原始TOML文本，无需URL解码
        if [ "${METHOD}" != "POST" ]; then
            respond "405 Method Not Allowed" "application/json"
            printf '{"ok":false}'
            exit 0
        fi
        TMP='/data/frpc.toml.tmp'
        if head -c "${CONTENT_LENGTH}" 2>/dev/null | tr -d '\r' > "${TMP}" && mv -f "${TMP}" /data/frpc.toml; then
            respond "200 OK" "application/json"
            printf '{"ok":true}'
        else
            respond "500 Internal Server Error" "application/json"
            printf '{"ok":false}'
        fi
        ;;
    *)
        respond "404 Not Found" "text/plain"
        printf 'not found'
        ;;
esac
exit 0
