---
title: Docker PHP 镜像选择指南
date: 2025-12-17 10:00:00 +0800
categories: [Docker]
tags: [Docker, PHP, Laravel, 最佳实践]
---

PHP 官方 Docker 镜像提供了丰富的变体，本文帮助你根据项目需求选择合适的镜像。

> 如果你还不了解 Alpine、Debian 等基础镜像的区别，建议先阅读 [Docker 基础镜像选择指南](/posts/docker-base-images-guide/)。

## 官方镜像变体

PHP 镜像的变体最为丰富，因为 PHP 有多种运行方式：

| 变体 | 体积 | 说明 |
|------|------|------|
| `php:8.3` | ~480 MB | 完整版，仅 CLI |
| `php:8.3-cli` | ~480 MB | 同上，显式标注 CLI |
| `php:8.3-fpm` | ~480 MB | 包含 PHP-FPM |
| `php:8.3-apache` | ~500 MB | 包含 Apache |
| `php:8.3-cli-alpine` | ~30 MB | Alpine CLI |
| `php:8.3-fpm-alpine` | ~35 MB | Alpine + FPM |

### 变体命名规则

```
php:8.3-fpm-alpine
    │   │     │
    │   │     └── 基础系统（省略则为 Debian）
    │   └── 运行方式（cli/fpm/apache）
    └── PHP 版本
```

## 场景选择

```
Web 应用（Laravel/Symfony）：
├── 推荐：php:8.3-fpm-alpine + nginx
├── 备选：php:8.3-apache（简单部署）
└── 开发：php:8.3-fpm（便于调试）

CLI 脚本/队列消费者：
├── 推荐：php:8.3-cli-alpine
└── 开发：php:8.3-cli

定时任务（Cron）：
└── 推荐：php:8.3-cli-alpine
```

**选择建议**：
- 生产环境优先选 `alpine` 变体，体积小 10+ 倍
- 需要调试时用完整版，工具更全
- Web 应用推荐 `fpm + nginx` 组合，性能更好

## 扩展安装

PHP 镜像的一大特点是需要安装各种扩展，官方提供了便捷的安装脚本。

### 内置扩展安装

```dockerfile
# 安装官方支持的扩展
RUN docker-php-ext-install pdo_mysql mysqli opcache bcmath
```

### 需要系统依赖的扩展

```dockerfile
# GD 库（Debian 版本）
RUN apt-get update && apt-get install -y \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install gd \
    && rm -rf /var/lib/apt/lists/*

# GD 库（Alpine 版本）
RUN apk add --no-cache \
    freetype-dev \
    libjpeg-turbo-dev \
    libpng-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install gd
```

### PECL 扩展安装

```dockerfile
# 通过 PECL 安装扩展
RUN pecl install redis && docker-php-ext-enable redis

# 安装指定版本
RUN pecl install redis-5.3.7 && docker-php-ext-enable redis
```

## 常见坑点

### 1. GD 库配置变化

PHP 7.4 之后 GD 库的配置方式改变了：

```dockerfile
# PHP 7.4 之前（已废弃）
docker-php-ext-configure gd --with-freetype-dir --with-jpeg-dir

# PHP 7.4+（正确方式）
docker-php-ext-configure gd --with-freetype --with-jpeg
```

### 2. Composer 安装

推荐使用官方 Composer 镜像，避免手动安装：

```dockerfile
# 推荐方式：从官方镜像复制
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# 不推荐：手动下载安装
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
```

### 3. opcache 生产配置

开发和生产环境的 opcache 配置应该不同：

```dockerfile
# 生产环境配置
RUN echo "opcache.enable=1" >> /usr/local/etc/php/conf.d/opcache.ini \
    && echo "opcache.validate_timestamps=0" >> /usr/local/etc/php/conf.d/opcache.ini \
    && echo "opcache.memory_consumption=128" >> /usr/local/etc/php/conf.d/opcache.ini \
    && echo "opcache.max_accelerated_files=10000" >> /usr/local/etc/php/conf.d/opcache.ini
```

**注意**：`validate_timestamps=0` 意味着修改代码后需要重启 PHP-FPM 才能生效，仅适合生产环境。

### 4. Alpine 版本的扩展依赖

Alpine 的包名与 Debian 不同：

| 扩展 | Debian 依赖 | Alpine 依赖 |
|------|-------------|-------------|
| gd | libpng-dev, libjpeg-dev | libpng-dev, libjpeg-turbo-dev |
| zip | libzip-dev | libzip-dev |
| intl | libicu-dev | icu-dev |
| pgsql | libpq-dev | postgresql-dev |

## Dockerfile 示例

### Laravel 生产环境（FPM + Alpine）

```dockerfile
# 构建阶段：安装 Composer 依赖
FROM composer:2 AS composer
WORKDIR /app
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-scripts --ignore-platform-reqs --prefer-dist

# 运行阶段
FROM php:8.3-fpm-alpine

# 安装扩展
RUN apk add --no-cache \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    libzip-dev \
    icu-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install gd pdo_mysql opcache zip intl bcmath

# 安装 Redis 扩展
RUN apk add --no-cache --virtual .build-deps $PHPIZE_DEPS \
    && pecl install redis \
    && docker-php-ext-enable redis \
    && apk del .build-deps

# 配置 opcache
RUN echo "opcache.enable=1" >> /usr/local/etc/php/conf.d/opcache.ini \
    && echo "opcache.validate_timestamps=0" >> /usr/local/etc/php/conf.d/opcache.ini \
    && echo "opcache.memory_consumption=128" >> /usr/local/etc/php/conf.d/opcache.ini

WORKDIR /var/www/html

# 复制代码和依赖
COPY --from=composer /app/vendor ./vendor
COPY . .

# 生成 autoload 优化
COPY --from=composer /usr/bin/composer /usr/bin/composer
RUN composer dump-autoload --optimize --no-dev && rm /usr/bin/composer

# 设置权限
RUN chown -R www-data:www-data storage bootstrap/cache

USER www-data
EXPOSE 9000
CMD ["php-fpm"]
```

### 队列消费者（CLI + Alpine）

```dockerfile
# 构建阶段：安装 Composer 依赖
FROM composer:2 AS composer
WORKDIR /app
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-scripts --ignore-platform-reqs --prefer-dist

# 运行阶段
FROM php:8.3-cli-alpine

RUN apk add --no-cache \
    libpng-dev \
    libjpeg-turbo-dev \
    && docker-php-ext-install pdo_mysql pcntl

# 安装 Redis
RUN apk add --no-cache --virtual .build-deps $PHPIZE_DEPS \
    && pecl install redis \
    && docker-php-ext-enable redis \
    && apk del .build-deps

WORKDIR /var/www/html
COPY --from=composer /app/vendor ./vendor
COPY . .

CMD ["php", "artisan", "queue:work", "--tries=3"]
```

### 开发环境（完整版 + Xdebug）

```dockerfile
FROM php:8.3-fpm

# 安装开发常用扩展
RUN apt-get update && apt-get install -y \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libzip-dev \
    unzip \
    git \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install gd pdo_mysql zip \
    && rm -rf /var/lib/apt/lists/*

# 安装 Xdebug
RUN pecl install xdebug && docker-php-ext-enable xdebug

# Xdebug 配置
RUN echo "xdebug.mode=debug" >> /usr/local/etc/php/conf.d/xdebug.ini \
    && echo "xdebug.start_with_request=yes" >> /usr/local/etc/php/conf.d/xdebug.ini \
    && echo "xdebug.client_host=host.docker.internal" >> /usr/local/etc/php/conf.d/xdebug.ini

# 安装 Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html
```

## 总结

PHP 镜像选择要点：

| 场景 | 推荐镜像 | 原因 |
|------|----------|------|
| 生产 Web | `fpm-alpine` | 体积小，配合 nginx 性能好 |
| 生产 CLI | `cli-alpine` | 体积小，适合队列/定时任务 |
| 开发环境 | `fpm` | 工具全，便于调试 |
| 简单部署 | `apache` | 一体化，配置简单 |

核心建议：
- 生产用 Alpine，开发用完整版
- 使用多阶段构建分离 Composer 安装
- 生产环境开启 opcache 并关闭 validate_timestamps

---

> 需要可直接使用的 PHP Dockerfile 模板？查看 [Dockerfile-template](https://github.com/liuxpng/Dockerfile-template) 仓库的 `php-fpm` 目录。
{: .prompt-tip }
