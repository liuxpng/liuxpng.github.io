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
| busybox | ~1-5 MB | 嵌入式 Linux 的瑞士军刀 |
| alpine | ~5-7 MB | 最流行的轻量级 Linux 发行版 |
| distroless | ~20-50 MB | Google 出品的安全精简镜像 |
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

## busybox：嵌入式瑞士军刀

### 是什么

BusyBox 将许多常用 Unix 工具的精简版本集成到一个小型可执行文件中，常用于嵌入式系统。Docker 的 busybox 镜像基于此构建。

```dockerfile
FROM busybox
COPY myapp /myapp
CMD ["/myapp"]
```

### 特点

- 体积约 1-5 MB（取决于变体）
- 包含常用 Unix 工具：sh、ls、cp、cat、grep、wget 等
- 有多个变体：`busybox:glibc`、`busybox:musl`、`busybox:uclibc`
- 没有包管理器

### 适用场景

- 需要基本 shell 能力但追求小体积
- 简单的脚本任务
- 调试用的 sidecar 容器
- 作为 initContainer 执行初始化任务

```dockerfile
# 作为调试 sidecar 的示例
FROM busybox
CMD ["sh", "-c", "while true; do sleep 3600; done"]
```

### 常见坑点

1. **工具功能受限**：busybox 的工具是精简版，不支持所有 GNU 选项
   ```bash
   # 例如 busybox 的 grep 不支持 -P (Perl 正则)
   grep -P '\d+' file.txt  # 会报错
   ```
2. **没有包管理器**：无法安装额外的软件
3. **C 库差异**：不同变体使用不同的 C 库，需要注意兼容性

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

## distroless：Google 的安全之选

### 是什么

Distroless 是 Google 推出的一系列精简镜像，只包含应用程序及其运行时依赖，不包含包管理器、shell 或其他常见 Linux 工具。

```dockerfile
FROM gcr.io/distroless/static-debian12
COPY myapp /myapp
ENTRYPOINT ["/myapp"]
```

### 特点

- 体积约 20-50 MB（取决于变体）
- 没有 shell、没有包管理器
- 基于 Debian，使用 glibc
- 提供多种运行时变体：static、base、java、python、nodejs 等
- 提供 debug 变体用于调试（包含 busybox shell）

### 可用变体

| 变体 | 用途 | 体积 |
|------|------|------|
| `gcr.io/distroless/static` | 静态编译的程序 | ~2 MB |
| `gcr.io/distroless/base` | 动态链接的程序 | ~20 MB |
| `gcr.io/distroless/java` | Java 应用 | ~200 MB |
| `gcr.io/distroless/python3` | Python 应用 | ~50 MB |
| `gcr.io/distroless/nodejs` | Node.js 应用 | ~100 MB |

### 适用场景

- **安全敏感的生产环境**：减少攻击面
- **合规要求高的场景**：更少的组件意味着更少的漏洞扫描告警
- 已经在使用 glibc 的项目迁移

```dockerfile
# Java 应用使用 distroless 的示例
FROM maven:3.9-eclipse-temurin-21 AS builder
WORKDIR /app
COPY pom.xml .
COPY src ./src
RUN mvn package -DskipTests

FROM gcr.io/distroless/java21-debian12
COPY --from=builder /app/target/app.jar /app.jar
ENTRYPOINT ["java", "-jar", "/app.jar"]
```

### 常见坑点

1. **调试困难**：没有 shell，无法 exec 进入容器
   - 解决方案：使用 debug 变体 `gcr.io/distroless/base:debug`
   ```bash
   # debug 变体包含 busybox shell
   docker exec -it container /busybox/sh
   ```

2. **无法安装额外依赖**：镜像是只读的，没有包管理器
   - 解决方案：在构建阶段准备好所有依赖

3. **镜像拉取**：镜像托管在 gcr.io，国内访问可能需要代理

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

| 特性 | scratch | busybox | alpine | distroless | debian/ubuntu |
|------|---------|---------|--------|------------|---------------|
| 体积 | 0 MB | ~1-5 MB | ~5-7 MB | ~20-50 MB | ~70-130 MB |
| 包管理器 | 无 | 无 | apk | 无 | apt |
| Shell | 无 | sh | sh | 无* | bash/sh |
| C 库 | 无 | 多种 | musl | glibc | glibc |
| 调试便利性 | 差 | 中 | 好 | 差* | 好 |
| 安全性 | 高 | 中 | 高 | 高 | 中 |
| 兼容性 | 低 | 中 | 中 | 高 | 高 |

*distroless 的 debug 变体包含 shell

---

## apk vs apt：包管理器使用差异

如果你同时使用过 alpine 和 debian/ubuntu 镜像，可能会注意到一个有趣的区别：

```dockerfile
# Alpine：不需要 update
RUN apk add --no-cache curl

# Debian/Ubuntu：必须先 update
RUN apt-get update && apt-get install -y curl
```

为什么 apk 不需要 `update`，而 apt 必须先 `update`？

### 设计差异

**apt 的工作方式**：
- Debian/Ubuntu 镜像为了减小体积，**不包含软件包索引**
- `/var/lib/apt/lists/` 目录是空的
- 必须先运行 `apt-get update` 下载最新的软件包列表，才能知道有哪些包可以安装

**apk 的工作方式**：
- Alpine 镜像**内置了软件包索引**（存储在 `/var/cache/apk/` 或 `/lib/apk/db/`）
- 索引文件很小（压缩后约 1-2 MB），包含在基础镜像中
- 可以直接安装软件包，无需额外的 update 步骤

### 为什么这样设计

| 方面 | apt (Debian/Ubuntu) | apk (Alpine) |
|------|---------------------|--------------|
| 索引大小 | 较大（解压后 30+ MB） | 很小（1-2 MB） |
| 设计目标 | 通用服务器，功能完整 | 容器/嵌入式，极致精简 |
| 更新频率 | 仓库更新频繁 | 相对稳定 |
| 基础镜像策略 | 不含索引，保持镜像小 | 包含索引，简化使用 |

Alpine 的设计哲学是"开箱即用"，适合容器场景；Debian 的设计更传统，假设系统是长期运行的。

### Dockerfile 最佳实践

**Alpine (apk)**：

```dockerfile
# 推荐：使用 --no-cache 避免缓存索引文件
RUN apk add --no-cache curl vim

# 如果需要更新索引（比如刚发布的新包）
RUN apk update && apk add --no-cache curl && rm -rf /var/cache/apk/*

# 安装特定版本
RUN apk add --no-cache curl=8.5.0-r0
```

**Debian/Ubuntu (apt)**：

```dockerfile
# 推荐：update + install + 清理在同一个 RUN 指令中
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    vim \
    && rm -rf /var/lib/apt/lists/*

# 错误示范：分开写会导致缓存问题
RUN apt-get update          # 这一层会被缓存
RUN apt-get install -y curl # 可能使用过期的索引
```

### 为什么 apt 要清理 /var/lib/apt/lists/*

```dockerfile
# 不清理的后果：增加约 30-40 MB 镜像体积
RUN apt-get update && apt-get install -y curl
# 镜像大小：~150 MB

# 清理后
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*
# 镜像大小：~110 MB
```

### 常见问题

**Q: 为什么我的 apt install 报错 "Unable to locate package"？**

A: 忘记运行 `apt-get update`，或者 update 在之前的镜像层中已被缓存但索引已过期。

```dockerfile
# 解决方案：确保 update 和 install 在同一个 RUN 指令中
RUN apt-get update && apt-get install -y package-name
```

**Q: apk 需要 --no-cache 吗？**

A: 强烈推荐。虽然 apk 默认可以直接安装，但 `--no-cache` 会避免下载和存储索引缓存，保持镜像精简。

```dockerfile
# 不使用 --no-cache：可能增加 1-2 MB
RUN apk add curl

# 使用 --no-cache：更干净
RUN apk add --no-cache curl
```

---

## 最佳实践

### 1. 根据项目需求选择

```
需要极致精简 + 静态编译语言 → scratch
需要 shell + 极小体积 → busybox
需要包管理 + 小体积（大多数场景） → alpine
需要安全 + glibc 兼容 → distroless
需要完整兼容性 + 复杂依赖 → debian/ubuntu slim
```

### 2. 使用多阶段构建

无论选择哪个基础镜像，都建议使用多阶段构建来减小最终镜像体积：

```dockerfile
# 构建阶段：使用完整环境
FROM golang:1.21 AS builder
WORKDIR /app
COPY . .
RUN CGO_ENABLED=0 go build -o myapp .

# 运行阶段：使用精简镜像
FROM alpine:3.19
RUN apk add --no-cache ca-certificates tzdata
COPY --from=builder /app/myapp /myapp
ENTRYPOINT ["/myapp"]
```

### 3. 定期更新基础镜像

- 关注基础镜像的安全公告
- 使用 CI/CD 自动化重建镜像
- 使用镜像扫描工具（Trivy、Clair 等）检测漏洞

### 4. 固定版本号

```dockerfile
# 推荐：固定具体版本
FROM alpine:3.19.1

# 不推荐：使用 latest
FROM alpine:latest
```

---

## 总结

没有放之四海而皆准的最佳基础镜像，选择取决于你的具体需求：

- 追求**极致精简**：scratch 或 busybox
- 追求**平衡**（体积 + 功能）：alpine（大多数场景的首选）
- 追求**安全 + 兼容性**：distroless
- 追求**完整功能 + 最大兼容**：debian/ubuntu slim

建议从 alpine 开始尝试，遇到兼容性问题再考虑其他选项。在后续文章中，我们会深入探讨各个镜像的进阶使用技巧和性能对比。
