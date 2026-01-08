---
title: RustDesk 自建服务器：10分钟拥有私有远程桌面
date: 2025-01-07 10:00:00 +0800
categories: [HomeLab, 远程控制]
tags: [远程控制, RustDesk, Docker, 自建服务器, 远程桌面]
series: remote-control
mermaid: true
---

上一篇对比了几款主流远程控制软件。如果你选择了 RustDesk 并希望**数据完全自主可控**，本篇手把手教你部署自己的 RustDesk 服务器。

## 为什么要自建

### 数据安全

使用公共服务器时，数据流向是这样的：

```mermaid
flowchart LR
    A[你的电脑] <--> S[RustDesk 公共服务器] <--> B[远程设备]
    style S fill:#f96
```

自建服务器后：

```mermaid
flowchart LR
    A[你的电脑] <--> S[你的服务器] <--> B[远程设备]
    style S fill:#9f9
```

**核心区别**：数据只经过你自己控制的服务器，不被任何第三方监控或记录。

### 无使用限制

- 无连接时长限制
- 无画质限制
- 无同时连接数限制
- 无广告、无水印

### 成本分析

| 项目 | 成本 |
|------|------|
| VPS (1核1G) | ¥30-50/月 |
| 域名 (可选) | ¥50/年 |
| **总计** | **约 ¥50/月** |

> 与 ToDesk 专业版 ¥108/年 相比，自建成本略高，但获得完全自主权。适合注重隐私或有多人共享需求的场景。

## 准备工作

### 1. 购买 VPS

推荐配置：

| 配置项 | 最低要求 | 推荐配置 |
|--------|----------|----------|
| CPU | 1核 | 2核 |
| 内存 | 1GB | 2GB |
| 带宽 | 1Mbps | 3-5Mbps |
| 系统 | Ubuntu 20.04+ | Ubuntu 22.04 |

**国内 VPS 推荐**（延迟低）：
- 腾讯云轻量应用服务器：¥45/月起
- 阿里云轻量应用服务器：¥45/月起

**国外 VPS 推荐**（便宜、无需备案）：
- Bandwagon (搬瓦工)：$49.99/年
- Vultr：$6/月起

### 2. 开放端口

RustDesk Server 需要以下端口：

| 端口 | 协议 | 用途 |
|------|------|------|
| 21115 | TCP | NAT 类型测试 |
| 21116 | TCP + UDP | ID 注册、心跳、打洞 |
| 21117 | TCP | 中继服务 |
| 21118 | TCP | Web 客户端 (可选) |
| 21119 | TCP | Web 客户端 (可选) |

**云厂商安全组配置**：

在云服务器控制台 → 安全组 → 添加规则：

```
入方向规则：
端口范围: 21115-21119
协议: TCP
源: 0.0.0.0/0

端口范围: 21116
协议: UDP
源: 0.0.0.0/0
```

## 部署服务端

### 方式一：Docker Compose（推荐）

这是最简单的部署方式。

#### 步骤 1：安装 Docker

```bash
# 一键安装 Docker
curl -fsSL https://get.docker.com | sh

# 启动 Docker
sudo systemctl start docker
sudo systemctl enable docker

# 验证安装
docker --version
```

#### 步骤 2：创建配置文件

```bash
# 创建目录
sudo mkdir -p /opt/rustdesk
cd /opt/rustdesk

# 创建 docker-compose.yml
sudo cat > docker-compose.yml << 'EOF'
version: '3'

services:
  rustdesk-server:
    container_name: rustdesk-server
    image: rustdesk/rustdesk-server-s6:latest
    ports:
      - 21115:21115
      - 21116:21116
      - 21116:21116/udp
      - 21117:21117
      - 21118:21118
      - 21119:21119
    environment:
      - RELAY=你的服务器IP:21117
      - ENCRYPTED_ONLY=1
    volumes:
      - ./data:/data
    restart: unless-stopped
EOF
```

> 将 `你的服务器IP` 替换为你 VPS 的公网 IP 地址。

#### 步骤 3：启动服务

```bash
# 启动容器
sudo docker compose up -d

# 查看日志
sudo docker compose logs -f
```

#### 步骤 4：获取密钥

```bash
# 查看公钥（客户端配置需要）
sudo cat /opt/rustdesk/data/id_ed25519.pub
```

输出类似：
```
3vPwJzMgbwF9xYh8CUCMwLKeuNzgdBn8UqM4JlP5qCg=
```

**请妥善保存这个密钥**，客户端配置需要用到。

### 方式二：一键脚本

如果不想手动配置，可以使用官方一键脚本：

```bash
wget https://raw.githubusercontent.com/rustdesk/rustdesk-server/master/install.sh
chmod +x install.sh
sudo ./install.sh
```

脚本会自动：
1. 安装 Docker
2. 部署 RustDesk Server
3. 输出密钥

## 配置客户端

### Windows / macOS / Linux

1. 下载并安装 [RustDesk 客户端](https://rustdesk.com/)
2. 打开 **设置** → **网络**
3. 找到 **ID/中继服务器** 部分
4. 填入配置：

| 字段 | 值 |
|------|-----|
| ID 服务器 | 你的服务器IP |
| 中继服务器 | 你的服务器IP |
| Key | 上面获取的公钥 |

5. 点击 **应用** 保存

### iOS / Android

1. 下载 RustDesk 客户端（App Store / Google Play）
2. 点击右下角 **设置** 图标
3. 点击 **ID/中继服务器**
4. 填入与桌面端相同的配置
5. 保存

### 验证配置

配置完成后，检查客户端左下角的状态：

- ✅ **就绪** - 配置正确，可以使用
- ❌ **未就绪** - 配置有误或服务器不可达

## 进阶配置

### 绑定域名

使用域名代替 IP 地址，更方便记忆，也便于更换服务器。

1. **添加 DNS 记录**

在域名服务商后台添加 A 记录：

```
类型: A
主机: rustdesk
值: 你的服务器IP
```

2. **修改配置**

编辑 `docker-compose.yml`：

```yaml
environment:
  - RELAY=rustdesk.你的域名.com:21117
```

重启服务：

```bash
sudo docker compose down
sudo docker compose up -d
```

3. **客户端配置**

将服务器地址改为 `rustdesk.你的域名.com`

### 配置 HTTPS（Web 客户端）

如果需要使用 Web 客户端，建议配置 HTTPS。

1. **安装 Nginx 和 Certbot**

```bash
sudo apt install nginx certbot python3-certbot-nginx -y
```

2. **创建 Nginx 配置**

```bash
sudo cat > /etc/nginx/sites-available/rustdesk << 'EOF'
server {
    listen 80;
    server_name rustdesk.你的域名.com;

    location / {
        proxy_pass http://127.0.0.1:21118;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
    }
}
EOF

sudo ln -s /etc/nginx/sites-available/rustdesk /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

3. **获取 SSL 证书并自动配置 HTTPS**

```bash
sudo certbot --nginx -d rustdesk.你的域名.com
```

Certbot 会自动修改 Nginx 配置，添加 SSL 证书和 HTTPS 重定向。

### 系统防火墙配置（可选）

如果你的 VPS 启用了系统防火墙（ufw），需要放行端口。大多数云服务器默认未启用 ufw，可以先检查：

```bash
sudo ufw status
# 如果显示 "Status: inactive"，则无需配置，跳过此步骤
```

如果 ufw 已启用，执行以下命令放行端口：

```bash
sudo ufw allow 21115:21119/tcp
sudo ufw allow 21116/udp
```

## 常见问题排查

### 客户端显示「未就绪」

**检查清单**：

1. **端口是否开放**
   ```bash
   # 在本地电脑测试
   nc -zv 你的服务器IP 21116
   ```

2. **服务是否运行**
   ```bash
   # 在服务器上检查
   sudo docker compose ps
   ```

3. **防火墙是否放行**
   ```bash
   # 检查 ufw 状态
   sudo ufw status
   ```

4. **Key 是否正确**
   - 确保复制的是 `id_ed25519.pub` 的完整内容
   - 不要有多余的空格或换行

### 连接成功但画面卡顿

可能原因：
1. **VPS 带宽不足** - 升级带宽或更换服务商
2. **网络质量差** - 选择更近的机房
3. **编码设置** - 尝试在客户端降低画质设置

### 无法连接特定设备

1. 确认两台设备都配置了相同的服务器地址和 Key
2. 检查被控端是否正确启动了 RustDesk
3. 尝试重启 RustDesk 客户端

## 安全建议

1. **使用 `ENCRYPTED_ONLY=1`**：强制加密连接，已在配置中启用

2. **定期更新**：
   ```bash
   cd /opt/rustdesk
   sudo docker compose pull
   sudo docker compose up -d
   ```

3. **设置固定密码**：在客户端设置中，将临时密码改为固定密码

4. **备份密钥**：妥善保存 `/opt/rustdesk/data/` 目录下的密钥文件

## 小结

本文介绍了如何使用 Docker 快速部署 RustDesk 服务器：

- **准备工作**：购买 VPS、开放端口
- **部署服务**：Docker Compose 一键部署
- **配置客户端**：填入服务器地址和密钥
- **进阶配置**：域名绑定、HTTPS

部署完成后，你就拥有了一个**完全私有**的远程桌面服务，数据不经过任何第三方。

---

## 系列文章导航

1. [远程控制入门]({% post_url homelab/2025-01-06-remote-control-overview %}) - 概念和方案选择
2. [商业工具对比]({% post_url homelab/2025-01-06-remote-control-commercial-tools %}) - ToDesk/向日葵/RustDesk 实测
3. **RustDesk 自建**（本文）- 10分钟拥有私有远程桌面
4. [Tailscale 入门]({% post_url homelab/2025-01-07-remote-control-tailscale-intro %}) - 把所有设备连成局域网
5. [Headscale 自建]({% post_url homelab/2025-01-08-remote-control-headscale-setup %}) - 完全自主的 Tailscale
6. [FRP 内网穿透]({% post_url homelab/2025-01-08-remote-control-frp-setup %}) - 传统但可靠的方案
7. [安全最佳实践]({% post_url homelab/2025-01-09-remote-control-security-best %}) - 保护你的远程连接
