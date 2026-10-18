#!/usr/bin/env bash
# Remove only this installer family's private systemd services and files.
set -Eeuo pipefail
umask 077
if [[ "$(id -u)" -ne 0 ]]; then
  echo "请使用 sudo/root。" >&2
  exit 1
fi
confirmed=0
for arg in "$@"; do
  case "$arg" in
    --yes) confirmed=1 ;;
    *) echo "未知参数：$arg" >&2; exit 2 ;;
  esac
done
unit=/etc/systemd/system
is_ours() {
  local name="$1" path="$unit/$1"
  [[ -f "$path" ]] || return 1
  case "$name" in
    residential-panel.service)
      grep -Fq 'Independent Residential Exit Management Panel' "$path" &&
      grep -Fq '/etc/residential-stack/panel.py' "$path" ;;
    residential-agent.service)
      grep -Fq '/opt/residential-stack-agent/lite_manager.py' "$path" ;;
    three-nodes.service)
      grep -Fq '/etc/sing-box/three-nodes.json' "$path" &&
      grep -Fq 'Three proxy entries' "$path" ;;
    residential-ip-cert-renew.service)
      grep -Fq '/opt/residential-ip-certbot/venv/bin/certbot' "$path" ;;
    residential-ip-cert-renew.timer)
      grep -Fq 'residential-ip-cert-renew.service' "$path" ;;
    *) return 1 ;;
  esac
}
services=(residential-panel.service residential-agent.service three-nodes.service residential-ip-cert-renew.timer residential-ip-cert-renew.service)
for name in "${services[@]}"; do
  if [[ -e "$unit/$name" ]] && ! is_ours "$name"; then
    echo "发现同名非本项目服务：$name；为了安全，取消卸载。" >&2
    exit 3
  fi
done
if (( !confirmed )); then
  echo "即将卸载本安装器的独立管理面板、Agent 和三个节点服务。"
  echo "卸载前将备份本项目配置，不修改现有其他 sing-box、3x-ui 和 OpenVPN 服务。"
  [[ -r /dev/tty ]] || { echo "无交互终端；请添加 --yes。" >&2; exit 4; }
  read -r -p "输入 UNINSTALL 以确认： " answer </dev/tty
  [[ "$answer" == UNINSTALL ]] || { echo "已取消。"; exit 0; }
fi
backup="$(mktemp -d /root/residential-ip-uninstall-XXXXXXXX)"
chmod 700 "$backup"
if [[ -d /etc/residential-stack ]]; then
  tar -C /etc -czf "$backup/residential-stack.tgz" residential-stack
  chmod 600 "$backup/residential-stack.tgz"
fi
owned_nodes=0
if is_ours three-nodes.service; then
  owned_nodes=1
  if [[ -e /etc/sing-box/three-nodes.json ]]; then
    install -m 600 /etc/sing-box/three-nodes.json "$backup/three-nodes.json"
  fi
fi
if [[ -f /root/three-nodes-info.txt ]] && grep -Fq '住宅管理面板：' /root/three-nodes-info.txt; then
  install -m 600 /root/three-nodes-info.txt "$backup/three-nodes-info.txt"
fi
for name in "${services[@]}"; do
  if is_ours "$name"; then
    systemctl disable --now "$name" >/dev/null 2>&1 || true
    rm -f "$unit/$name"
    echo "已删除服务：$name"
  fi
done
systemctl daemon-reload
if (( owned_nodes )); then
  rm -f /etc/sing-box/three-nodes.json
fi
if [[ ! -e "$unit/residential-agent.service" && ! -e "$unit/residential-panel.service" ]]; then
  rm -rf /etc/residential-stack /opt/residential-stack-agent /opt/residential-stack-bin
  rm -rf /opt/residential-ip-certbot
  rm -f /usr/local/sbin/residential-ip-deploy-cert
fi
if [[ -f "$backup/three-nodes-info.txt" ]]; then
  rm -f /root/three-nodes-info.txt
fi
echo "卸载结束，私密配置备份：$backup"
echo "注意：没有自动删除其它 sing-box、3x-ui/OpenVPN、全局 Certbot 配置或防火墙规则。"
