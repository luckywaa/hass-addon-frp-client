#!/bin/bash
# 后台下载指定版本frpc（由handler.sh以nohup拉起，与HTTP连接解耦）
# 用法: dl.sh <版本号如0.71.0> [镜像前缀如https://ghfast.top/，空=直连]
V="$1"
MIRROR="$2"
STATE='/tmp/frp.download.state'

fail() {
    printf 'fail\n%s\n%s\n' "${V}" "$1" > "${STATE}"
    exit 1
}

# CPU架构由代码判断：映射到Go架构名
GOARCH=''
case "$(uname -m)" in
    aarch64|arm64)    GOARCH='arm64' ;;
    x86_64|amd64)     GOARCH='amd64' ;;
    armv7l|armv6l|arm) GOARCH='arm' ;;
    i686|i386|386)    GOARCH='386' ;;
    *) fail "不支持的CPU架构 $(uname -m)" ;;
esac

URL="https://github.com/fatedier/frp/releases/download/v${V}/frp_${V}_linux_${GOARCH}.tar.gz"
printf 'running\n%s\n\n' "${V}" > "${STATE}"

TMP="$(mktemp -d /tmp/frpdl.XXXXXX)"
# 镜像失败时回退直连
if [ -n "${MIRROR}" ]; then
    curl -fSL --max-time 600 -o "${TMP}/frp.tar.gz" "${MIRROR}${URL}" \
        || curl -fSL --max-time 600 -o "${TMP}/frp.tar.gz" "${URL}" \
        || { rm -rf "${TMP}"; fail "下载失败(检查网络或镜像地址)"; }
else
    curl -fSL --max-time 600 -o "${TMP}/frp.tar.gz" "${URL}" \
        || { rm -rf "${TMP}"; fail "下载失败(可尝试勾选镜像加速)"; }
fi

tar -xzf "${TMP}/frp.tar.gz" -C "${TMP}" 2>/dev/null \
    || { rm -rf "${TMP}"; fail "解压失败(文件可能损坏)"; }
SRC="$(find "${TMP}" -type f -name frpc | head -n1)"
[ -n "${SRC}" ] || { rm -rf "${TMP}"; fail "压缩包中没有frpc"; }
"${SRC}" -v 2>/dev/null | grep -q "${V}" || { rm -rf "${TMP}"; fail "版本校验失败"; }

mkdir -p "/data/frp-versions/${V}"
mv -f "${SRC}" "/data/frp-versions/${V}/frpc" || { rm -rf "${TMP}"; fail "写入/data失败"; }
chmod a+x "/data/frp-versions/${V}/frpc"
rm -rf "${TMP}"

# 下载并使用：切换到新版本，只保留该版本，frpc在运行则发重启命令
printf '%s' "${V}" > /data/frp-version
for D in /data/frp-versions/*/; do
    [ "${D}" = "/data/frp-versions/${V}/" ] && continue
    rm -rf "${D}"
done
if [ -f /tmp/frpc.pid ] && kill -0 "$(cat /tmp/frpc.pid 2>/dev/null)" 2>/dev/null; then
    printf 'restart' > /tmp/frpc.cmd
fi
printf 'done\n%s\n\n' "${V}" > "${STATE}"
