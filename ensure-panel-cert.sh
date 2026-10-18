#!/usr/bin/env bash
# Request and auto-renew a publicly trusted Let's Encrypt short-lived IPv4 panel certificate.
# This script never stops third-party webservers, resets nodes, or replaces a working cert on failure.
set -Eeuo pipefail
umask 077
[[ "$(id -u)" -eq 0 ]] || { echo "需要 root/sudo。" >&2; exit 1; }
ROOT=/etc/residential-stack
VENV=/opt/residential-ip-certbot/venv
HOOK=/usr/local/sbin/residential-ip-deploy-cert
UNIT=/etc/systemd/system/residential-ip-cert-renew.service
TIMER=/etc/systemd/system/residential-ip-cert-renew.timer
[[ -f "$ROOT/settings.json" && -f "$ROOT/panel.py" ]] || {
  echo "此 VPS 尚未安装本项目独立面板，跳过证书申请。" >&2
  exit 2
}
[[ -f /etc/systemd/system/residential-panel.service ]] &&
grep -Fq 'Independent Residential Exit Management Panel' /etc/systemd/system/residential-panel.service || {
  echo "检测到非本项目管理面板，拒绝替换其证书。" >&2; exit 3;
}
IP="${1:-}"
python3 - "$IP" <<'PY'
import ipaddress,sys
try:
    value=ipaddress.ip_address(sys.argv[1])
    assert value.version==4 and value.is_global
except (ValueError,AssertionError):
    raise SystemExit("请提供公网 IPv4 地址。")
PY
if ! command -v ss >/dev/null 2>&1; then
  echo "缺少 ss 命令，请安装 iproute2。" >&2; exit 4
fi
if ss -ltnH 'sport = :80' | grep -q .; then
  echo "TCP/80 已被其他服务占用。不会强制停服，旧证书保留。" >&2; exit 5
fi
mkdir -p /opt/residential-ip-certbot
if [[ ! -x "$VENV/bin/certbot" ]]; then
  if ! python3 -m venv "$VENV"; then
    apt-get update -q
    DEBIAN_FRONTEND=noninteractive apt-get install -y python3-venv
    python3 -m venv "$VENV"
  fi
  "$VENV/bin/python" -m pip install --disable-pip-version-check --quiet 'certbot>=5.4,<8'
fi
cat > "$HOOK" <<'HOOK'
#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
ip="$1"
root=/etc/residential-stack
live="/etc/letsencrypt/live/$ip"
[[ -s "$live/fullchain.pem" && -s "$live/privkey.pem" ]] || exit 1
openssl x509 -in "$live/fullchain.pem" -noout -checkip "$ip" >/dev/null
install -m 600 "$live/fullchain.pem" "$root/.panel-cert.next"
install -m 600 "$live/privkey.pem" "$root/.panel-key.next"
certificate_pub="$(openssl x509 -in "$root/.panel-cert.next" -pubkey -noout | openssl pkey -pubin -outform DER | sha256sum | cut -d' ' -f1)"
private_pub="$(openssl pkey -in "$root/.panel-key.next" -pubout -outform DER | sha256sum | cut -d' ' -f1)"
[[ "$certificate_pub" = "$private_pub" ]] || { echo "证书与私钥不匹配" >&2; exit 2; }
cp -p "$root/panel-cert.pem" "$root/.panel-cert.back"
cp -p "$root/panel-key.pem" "$root/.panel-key.back"
mv -f "$root/.panel-cert.next" "$root/panel-cert.pem"
mv -f "$root/.panel-key.next" "$root/panel-key.pem"
if ! systemctl restart residential-panel.service; then
  mv -f "$root/.panel-cert.back" "$root/panel-cert.pem"
  mv -f "$root/.panel-key.back" "$root/panel-key.pem"
  systemctl restart residential-panel.service || true
  echo "证书部署失败，已回滚到原证书。" >&2; exit 3
fi
rm -f "$root/.panel-cert.back" "$root/.panel-key.back"
HOOK
chmod 700 "$HOOK"
if ! "$VENV/bin/certbot" certonly --standalone --non-interactive --agree-tos \
  --register-unsafely-without-email --preferred-profile shortlived \
  --ip-address "$IP" --cert-name "$IP" --keep-until-expiring; then
  echo "证书签发失败，原证书保留。检查 TCP/80 公网可达性、端口占用或 CA 限流。" >&2
  exit 6
fi
"$HOOK" "$IP"
cat > "$UNIT" <<EOF
[Unit]
Description=Auto-renew Residential IP panel short-lived certificate
After=network-online.target
[Service]
Type=oneshot
ExecStart=$VENV/bin/certbot renew --cert-name $IP --non-interactive --quiet --deploy-hook "$HOOK $IP"
EOF
cat > "$TIMER" <<'EOF'
[Unit]
Description=Check Residential IP panel certificate renewal twice daily
[Timer]
OnCalendar=*-*-* 04,16:00:00
RandomizedDelaySec=600
Persistent=true
Unit=residential-ip-cert-renew.service
[Install]
WantedBy=timers.target
EOF
chmod 644 "$UNIT" "$TIMER"
systemctl daemon-reload
systemctl enable --now residential-ip-cert-renew.timer
echo "证书申请完成；已启用自动续期定时器。请在浏览器中使用 https://$IP:面板端口/ 检查。"
