#!/usr/bin/env bash
# Compatibility bootstrap for the existing VPS installer, with separate HTTPS and copy-all helpers.
# Original installer remains pinned to a fixed public Git commit; this repo owns its helper scripts.
set -Eeuo pipefail
umask 077
[[ "$(id -u)" -eq 0 ]] || { echo "请用 sudo/root 执行安装。" >&2; exit 1; }
command -v curl >/dev/null || { echo "需要 curl。" >&2; exit 1; }
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
old_url='https://raw.githubusercontent.com/mtgggxfc-eng/ip/f79ede4f98f86af9382eec0ff73a005de687754a/jkyj.sh'
base='https://raw.githubusercontent.com/zhongyiw37/IP/main'
echo "==> 下载已固定版本的原安装器（不覆盖其他 sing-box/x-ui 安装）"
curl -fsSL --retry 2 --connect-timeout 15 --max-time 90 "$old_url" -o "$work/original.sh"
bash "$work/original.sh"
echo
echo "==> 补充 HTTPS 证书自动配置"
if [[ -f /root/three-nodes-info.txt ]]; then
  url="$(sed -n 's/^住宅管理面板：//p' /root/three-nodes-info.txt | head -n 1)"
  host="$url"
  host="${host#https://}"
  host="${host%%:*}"
  host="${host%%/*}"
  if [[ "$host" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    if curl -fsSL --retry 2 --connect-timeout 15 --max-time 90 "$base/ensure-panel-cert.sh" -o "$work/cert.sh"; then
      bash "$work/cert.sh" "$host" || echo "注意：公网 HTTPS 未签发成功；保留原证书，需要检查 TCP/80 和云防火墙。" >&2
    else
      echo "注意：证书组件下载失败；旧证书保持不变。" >&2
    fi
  else
    echo "未识别到面板公网 IP；跳过证书签发。" >&2
  fi
else
  echo "找不到原安装记录 /root/three-nodes-info.txt，跳过证书和合并链接输出。" >&2
fi
echo
echo '========== 三条节点链接：从此处开始一次复制 =========='
if curl -fsSL --retry 2 --connect-timeout 15 --max-time 30 "$base/print-links.sh" -o "$work/links.sh"; then
  bash "$work/links.sh" || echo "节点链接尚未完整生成；请检查原安装器的输出。" >&2
fi
echo '========== 三条节点链接：结束 =========='
echo
echo "一键卸载命令："
echo "curl -fsSL $base/uninstall.sh | sudo bash"
echo "安装主流程已返回；证书最终是否受浏览器信任，请在真实 VPS 上核验。"
