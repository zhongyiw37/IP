# IP｜VPS 三节点安装与管理

这是 `zhongyiw37` 账号下的独立仓库，便于在 Debian/Ubuntu VPS 上使用原有三节点安装程序，并追加 HTTPS 证书配置、三条链接一次复制和安全卸载。

> **当前版本说明：** `jkyj.sh` 是一个引导脚本，会下载并运行 `mtgggxfc-eng/ip` 仓库固定提交 `f79ede4f98f86af9382eec0ff73a005de687754a` 的原始安装器，然后运行本仓库的辅助脚本。本仓库不是完全独立的原安装器复制品。**住宅面板目前仍是原安装器自带的独立面板，并非 `a6216abcd/Free-Residential-IP-Proxy-Controller` 原云端面板的完整布局和功能。** 该项还需要单独移植，不能把目前状态当成已完成。

## 1. 一键安装或再次运行

以 root 或 sudo 在 VPS 的交互式 SSH 终端运行：

```bash
curl -fsSL https://raw.githubusercontent.com/zhongyiw37/IP/main/jkyj.sh | { if [ "$(id -u)" -eq 0 ]; then bash; else sudo bash; fi; }
```

本入口先运行固定版本的三节点安装器（原有运行中节点按其自身发现逻辑处理），随后尝试给面板部署受信任的公网 IP HTTPS 证书，并把三条节点链接连续显示在终端末尾。

**注意：** 安装器会以 root 权限变更服务和网络设置。在正式执行前请审阅 `jkyj.sh` 和原安装器源码。已经运行的生产节点建议先保存配置备份。

## 2. 一键卸载（测试时使用）

```bash
curl -fsSL https://raw.githubusercontent.com/zhongyiw37/IP/main/uninstall.sh | sudo bash
```

运行后输入 `UNINSTALL` 确认。它会先私密备份本项目的配置，再清理它能识别归属的 `residential-panel.service`、`residential-agent.service` 和 `three-nodes.service` 等服务及专用文件。如果未识别到本项目服务，程序会停止而不删除配置。不会删除其他 sing-box、3x-ui、OpenVPN、全局 Let's Encrypt 账户或防火墙规则。

如果确实处于无交互环境，可在仔细核对目标机器后传入 `--yes`，但默认推荐交互确认。

## 3. 三条节点链接一次复制

安装器在末尾增加连续三行纯链接，便于一次选中复制。以后需要再次获取，可在 VPS 运行：

```bash
curl -fsSL https://raw.githubusercontent.com/zhongyiw37/IP/main/print-links.sh | sudo bash
```

链接包含连接凭据，请不要将终端输出公开发布。

## 4. HTTPS 证书自动配置

脚本尝试通过 Let's Encrypt 给**公网 IP**申请受信任的短期证书，并部署续期检查。需要公网 TCP **80** 能够被证书签发机构访问，且该端口当前不能被其他服务占用。证书有效期约 160 小时，续期检查必须保持运行。

**签发失败时不会谎报成功**：旧自签名证书会保留，浏览器仍可能显示“不安全”。公网 IP 是否受信任，请在实际 VPS 安装后自行验证。

独立运行证书步骤（将 `你的公网IPv4` 替换为面板服务器的真实公网地址）：

```bash
curl -fsSL https://raw.githubusercontent.com/zhongyiw37/IP/main/ensure-panel-cert.sh -o /tmp/ensure-panel-cert.sh
sudo bash /tmp/ensure-panel-cert.sh 你的公网IPv4
```

查看续期定时器：`sudo systemctl status residential-ip-cert-renew.timer`

## 文件说明

| 文件 | 作用 |
| --- | --- |
| `jkyj.sh` | 从固定版本原仓库引导安装、配置 HTTPS 并显示三条链接 |
| `ensure-panel-cert.sh` | 申请 IP HTTPS 证书、部署面板证书、配置自动续期 |
| `print-links.sh` | 一次打印三条保存的节点链接 |
| `uninstall.sh` | 归属识别、备份及范围受限的卸载 |

## 来源与实际状态

- 原安装器：[mtgggxfc-eng/ip](https://github.com/mtgggxfc-eng/ip)
- 原住宅代理控制项目：[Free-Residential-IP-Proxy-Controller](https://github.com/a6216abcd/Free-Residential-IP-Proxy-Controller)
- 当前仓库：**已发布安装入口与辅助脚本**，但尚未在目标 VPS 上执行或验收。不能将代码提交等同于证书已签发、面板功能已复原或节点已验证。
