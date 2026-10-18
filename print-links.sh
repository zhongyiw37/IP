#!/usr/bin/env bash
# Print all three existing node links together from the original installer's root-only result file.
set -Eeuo pipefail
umask 077
result=/root/three-nodes-info.txt
if [[ "$(id -u)" -ne 0 ]]; then
  echo "请使用 sudo/root 运行。" >&2
  exit 1
fi
if [[ ! -r "$result" ]]; then
  echo "未找到 $result。请确认原安装脚本已成功运行。" >&2
  exit 2
fi
python3 - "$result" <<'PY'
import pathlib,sys
text=pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
rows={}
keys={
    "VLESS + Reality（TCP）":"vless://",
    "Hysteria2（UDP）":"hysteria2://",
    "家宽出口（VLESS + Reality TCP）":"vless://",
}
for line in text.splitlines():
    for label,scheme in keys.items():
        prefix=label+"："
        if line.startswith(prefix):
            value=line[len(prefix):].strip()
            if value.startswith(scheme):
                rows[label]=value
for label in keys:
    if label not in rows:
        print("缺少有效链接："+label,file=sys.stderr)
        sys.exit(3)
print("\n".join(rows[label] for label in keys))
PY
