---
title: Docker 基础镜像选择指南：从 scratch 到 alpine
date: 2025-12-16 10:00:00 +0800
categories: [Docker]
tags: [Docker, 容器, DevOps, 最佳实践]
---

选择合适的基础镜像是构建 Docker 镜像的第一步，也是影响最终镜像质量的关键决策。

本文将介绍常见的 Docker 基础镜像，帮助你在不同场景下做出合适的选择。

## 为什么基础镜像的选择很重要

基础镜像的选择直接影响：

- **镜像大小**：从几 MB 到几百 MB 不等，影响拉取速度和存储成本
- **安全性**：包含的组件越多，潜在的漏洞攻击面越大
- **兼容性**：不同的 C 库（glibc vs musl）可能导致兼容性问题
- **可调试性**：是否有 shell 和常用工具，影响排查问题的难度

本文将介绍以下基础镜像（按体积从小到大排序）：

| 镜像 | 体积 | 一句话描述 |
|------|------|-----------|
| scratch | 0 MB | 空镜像，真正的从零开始 |
| alpine | ~5-7 MB | 最流行的轻量级 Linux 发行版 |
| debian/ubuntu | ~70-130 MB | 传统完整 Linux 发行版 |

---

## scratch：空镜像

### 是什么

`scratch` 是 Docker 的特殊镜像，它是一个完全空白的镜像，不包含任何文件系统、库或工具。它是所有镜像的起点，其他基础镜像都是从 scratch 构建而来的。

```dockerfile
FROM scratch
COPY myapp /myapp
ENTRYPOINT ["/myapp"]
```

### 特点

- 体积为 0，最终镜像大小就是你的应用大小
- 没有 shell（/bin/sh）
- 没有任何库文件
- 没有包管理器
- 没有用户系统（只有 root）

### 适用场景

- **静态编译的 Go 程序**：Go 可以编译成不依赖任何外部库的二进制文件
- **静态编译的 Rust 程序**：使用 musl target 编译
- **追求极致精简的场景**

```dockerfile
# Go 程序使用 scratch 的多阶段构建示例
FROM golang:1.21 AS builder
WORKDIR /app
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o myapp .

FROM scratch
COPY --from=builder /app/myapp /myapp
ENTRYPOINT ["/myapp"]
```

### 常见坑点

1. **无法使用 docker exec 进入容器调试**：没有 shell，无法执行任何命令
2. **没有 CA 证书**：如果程序需要发起 HTTPS 请求，需要手动复制证书
   ```dockerfile
   COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
   ```
3. **没有时区信息**：时间相关功能可能异常，需要复制 zoneinfo
   ```dockerfile
   COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo
   ```
4. **没有 /tmp 目录**：某些程序可能需要临时目录

---

## alpine：最流行的轻量镜像

### 是什么

Alpine Linux 是一个面向安全的轻量级 Linux 发行版，基于 musl libc 和 busybox。它是目前最流行的 Docker 基础镜像之一。

```dockerfile
FROM alpine:3.19
RUN apk add --no-cache curl
COPY myapp /myapp
CMD ["/myapp"]
```

### 特点

- 体积约 5-7 MB
- 有完整的包管理器 `apk`
- 基于 musl libc（不是 glibc）
- 安全导向：默认不包含不必要的组件
- 更新频繁，安全补丁及时

### 适用场景

- **大多数生产环境的首选**
- 需要安装额外依赖但又想保持镜像精简
- Python、Node.js、Java 等运行时的基础镜像
- 微服务架构中的标准选择

```dockerfile
# Python 应用使用 alpine 的示例
FROM python:3.12-alpine
WORKDIR /app
RUN apk add --no-cache gcc musl-dev  # 某些 Python 包需要编译
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
CMD ["python", "app.py"]
```

### 常见坑点

1. **musl vs glibc 兼容性问题**：
   - 某些预编译的二进制文件（如某些 Python wheels）可能无法运行
   - Node.js 的某些 native 模块可能有问题
   - 解决方案：安装 `gcompat` 或使用 alpine 专用包

2. **DNS 解析行为差异**：
   - musl 的 DNS 解析实现与 glibc 不同
   - 在某些 Kubernetes 环境中可能遇到问题
   - 解决方案：确保 `/etc/nsswitch.conf` 配置正确

3. **缺少常用工具**：默认不包含 bash、curl 等，需要手动安装
   ```dockerfile
   RUN apk add --no-cache bash curl
   ```

4. **时区问题**：默认使用 UTC
   ```dockerfile
   RUN apk add --no-cache tzdata && \
       cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
       echo "Asia/Shanghai" > /etc/timezone
   ```

---

## debian/ubuntu：传统完整发行版

### 是什么

Debian 和 Ubuntu 是最常见的 Linux 发行版，提供完整的系统环境和丰富的软件包。

```dockerfile
FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*
COPY myapp /myapp
CMD ["/myapp"]
```

### 特点

- 体积约 70-130 MB（slim 版本更小）
- 完整的 apt 包管理器
- 基于 glibc，兼容性最好
- 软件包丰富，几乎什么都能装
- 有 slim 变体：`debian:bookworm-slim`、`ubuntu:24.04`

### 适用场景

- **需要完整兼容性**：某些软件只在 glibc 环境下正常运行
- **开发和调试环境**：完整的工具链
- **复杂依赖场景**：需要安装很多系统包
- **企业遗留应用**：迁移成本最低

```dockerfile
# 复杂依赖的应用示例
FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    libpq-dev \
    libxml2-dev \
    libxslt1-dev \
    && rm -rf /var/lib/apt/lists/*
COPY requirements.txt .
RUN pip3 install --no-cache-dir -r requirements.txt
COPY . /app
CMD ["python3", "/app/main.py"]
```

### 常见坑点

1. **镜像体积大**：基础镜像就有 70+ MB，加上依赖很容易超过 500 MB
   - 解决方案：使用 slim 变体，清理 apt 缓存

2. **攻击面广**：包含的组件多，潜在漏洞也多
   - 解决方案：定期更新基础镜像，及时修复安全漏洞

3. **apt 缓存问题**：忘记清理会导致镜像变大
   ```dockerfile
   # 正确做法：同一 RUN 指令中清理缓存
   RUN apt-get update && apt-get install -y pkg \
       && rm -rf /var/lib/apt/lists/*
   ```

4. **版本选择**：
   - Debian：bookworm (12)、bullseye (11)
   - Ubuntu：24.04 LTS、22.04 LTS
   - 建议使用 LTS 或 stable 版本

---

## 对比总结

| 特性 | scratch | alpine | debian/ubuntu |
|------|---------|--------|---------------|
| 体积 | 0 MB | ~5-7 MB | ~70-130 MB |
| 包管理器 | 无 | apk | apt |
| Shell | 无 | sh | bash/sh |
| C 库 | 无 | musl | glibc |
| 调试便利性 | 差 | 好 | 好 |
| 安全性 | 高 | 高 | 中 |
| 兼容性 | 低 | 中 | 高 |

> 关于 apk 和 apt 包管理器的使用差异，请参考 [Docker 中 apk 与 apt 的使用差异](/posts/docker-apk-vs-apt/)。

---

## 总结

没有放之四海而皆准的最佳基础镜像，选择取决于你的具体需求：

- 追求**极致精简**：scratch
- 追求**平衡**（体积 + 功能）：alpine（大多数场景的首选）
- 追求**完整功能 + 最大兼容**：debian/ubuntu slim

建议从 alpine 开始尝试，遇到兼容性问题再考虑其他选项。在后续文章中，我们会深入探讨各个镜像的进阶使用技巧和性能对比。
