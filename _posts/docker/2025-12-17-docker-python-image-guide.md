---
title: Docker Python 镜像选择指南
date: 2025-12-17 11:00:00 +0800
categories: [Docker]
tags: [Docker, Python, FastAPI, Django, 最佳实践]
---

Python 官方 Docker 镜像的选择主要考虑体积和 wheel 包兼容性。本文帮助你根据项目需求选择合适的镜像。

> 如果你还不了解 Alpine、Debian 等基础镜像的区别，建议先阅读 [Docker 基础镜像选择指南](/posts/docker-base-images-guide/)。

## 官方镜像变体

| 变体 | 体积 | 说明 |
|------|------|------|
| `python:3.12` | ~1 GB | 完整版，含编译工具链 |
| `python:3.12-slim` | ~150 MB | 精简版，无编译工具 |
| `python:3.12-alpine` | ~50 MB | Alpine 版，musl libc |
| `python:3.12-bookworm` | ~1 GB | 显式指定 Debian 12 |
| `python:3.12-slim-bookworm` | ~150 MB | 精简版 + Debian 12 |

## 场景选择

```
数据科学/机器学习（numpy, pandas, scipy, torch）：
├── 推荐：python:3.12-slim
├── 备选：python:3.12（需要编译时）
└── 避免：alpine（wheel 不兼容，编译极慢）

Web 应用（FastAPI/Django/Flask）：
├── 推荐：python:3.12-slim
└── 备选：python:3.12-alpine（纯 Python 依赖时）

简单脚本/CLI 工具：
├── 推荐：python:3.12-alpine（无复杂依赖时）
└── 备选：python:3.12-slim

AWS Lambda / 云函数：
└── 推荐：python:3.12-slim（平衡体积和兼容性）
```

**核心原则**：
- 有 C 扩展依赖（numpy、pandas 等）→ 用 `slim`
- 纯 Python 依赖 → 可以用 `alpine`
- 不确定 → 用 `slim`（最稳妥）

## 常见坑点

### 1. Alpine 的 wheel 兼容问题

这是 Python + Alpine 最大的坑。PyPI 上的预编译 wheel 大多基于 glibc，而 Alpine 使用 musl：

```bash
# 在 slim 中安装 pandas：秒装（使用预编译 wheel）
pip install pandas  # 几秒钟

# 在 alpine 中安装 pandas：触发编译，极慢
pip install pandas  # 10+ 分钟，还可能失败
```

**解决方案**：
- 方案 1：直接用 `slim` 镜像
- 方案 2：使用 alpine 专用 wheel（如果有）
- 方案 3：多阶段构建，在完整版中编译

### 2. slim 镜像缺少编译工具

某些包需要编译 C 扩展，在 slim 中会失败：

```dockerfile
# 这样会失败（slim 没有 gcc）
FROM python:3.12-slim
RUN pip install some-package-needs-compile

# 解决方案：安装编译工具
FROM python:3.12-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    python3-dev \
    && rm -rf /var/lib/apt/lists/*
RUN pip install some-package-needs-compile
```

### 3. pip 缓存问题

pip 默认会缓存下载的包，在 Docker 中这会增加镜像体积：

```dockerfile
# 不推荐：会保留缓存
RUN pip install -r requirements.txt

# 推荐：禁用缓存
RUN pip install --no-cache-dir -r requirements.txt
```

### 4. 虚拟环境的必要性

在 Docker 中是否需要虚拟环境？

```dockerfile
# 方式 1：不用虚拟环境（简单场景推荐）
RUN pip install --no-cache-dir -r requirements.txt

# 方式 2：使用虚拟环境（复杂场景/多阶段构建推荐）
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
RUN pip install --no-cache-dir -r requirements.txt
```

虚拟环境的好处是方便在多阶段构建中复制整个依赖目录。

## Dockerfile 示例

### FastAPI 生产环境（slim + 多阶段）

```dockerfile
# 构建阶段
FROM python:3.12-slim AS builder

WORKDIR /app

# 安装编译工具（如果有需要编译的依赖）
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# 创建虚拟环境
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# 安装依赖
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 运行阶段
FROM python:3.12-slim

WORKDIR /app

# 复制虚拟环境
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# 安装运行时依赖（如 psycopg2 需要 libpq）
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    && rm -rf /var/lib/apt/lists/*

# 复制代码
COPY . .

# 非 root 用户
RUN useradd -m appuser && chown -R appuser:appuser /app
USER appuser

EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### Django 生产环境

```dockerfile
FROM python:3.12-slim

WORKDIR /app

# 安装系统依赖
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    && rm -rf /var/lib/apt/lists/*

# 安装 Python 依赖
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 复制代码
COPY . .

# 收集静态文件
RUN python manage.py collectstatic --noinput

# 非 root 用户
RUN useradd -m appuser && chown -R appuser:appuser /app
USER appuser

EXPOSE 8000
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "myproject.wsgi:application"]
```

### 纯 Python 项目（Alpine 版）

适用于没有 C 扩展依赖的项目：

```dockerfile
FROM python:3.12-alpine

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

RUN adduser -D appuser && chown -R appuser:appuser /app
USER appuser

EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### 数据科学项目

```dockerfile
FROM python:3.12-slim

WORKDIR /app

# 安装常用数据科学依赖的系统库
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

CMD ["python", "main.py"]
```

## 常用依赖的系统包

使用 `slim` 时，某些 Python 包需要安装对应的系统库：

| Python 包 | 需要安装的系统包 |
|-----------|------------------|
| psycopg2 | libpq-dev（编译）/ libpq5（运行） |
| mysqlclient | default-libmysqlclient-dev / libmariadb3 |
| Pillow | libjpeg-dev, zlib1g-dev |
| lxml | libxml2-dev, libxslt1-dev |
| numpy/scipy | libgomp1（OpenMP 支持） |

## 总结

Python 镜像选择要点：

| 场景 | 推荐镜像 | 原因 |
|------|----------|------|
| Web 应用 | `slim` | 平衡体积和兼容性 |
| 数据科学 | `slim` | wheel 兼容性好 |
| 纯 Python 项目 | `alpine` | 体积最小 |
| 需要编译 | `完整版` 或 `slim + gcc` | 有编译工具 |

核心建议：
- 默认选 `slim`，遇到问题再调整
- 避免在 Alpine 中使用有 C 扩展的包
- 使用 `--no-cache-dir` 减小镜像体积
- 多阶段构建分离编译和运行环境

---

> 需要可直接使用的 Python Dockerfile 模板？查看 [Dockerfile-template](https://github.com/liuxpng/Dockerfile-template) 仓库的 `python-with-uv` 或 `python-with-pip` 目录。
{: .prompt-tip }
