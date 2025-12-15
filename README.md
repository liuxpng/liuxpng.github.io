# Liu Peng's Personal Blog

个人技术博客，使用 Jekyll + Chirpy 主题搭建。

## 本地开发

### 使用 Docker（推荐）

```bash
# 启动开发服务器（前台运行，可看到日志）
./dev.sh start

# 或者后台运行
./dev.sh start-d

# 停止服务器
./dev.sh stop

# 查看日志
./dev.sh logs

# 重启服务器
./dev.sh restart

# 清理缓存
./dev.sh clean

# 进入容器 shell
./dev.sh bash

# 构建站点
./dev.sh build
```

访问 http://localhost:4000 查看博客。

### 不使用 Docker

需要先安装 Ruby 环境，然后：

```bash
bundle install
bundle exec jekyll serve
```

## 写文章

在 `_posts/` 目录下创建新的 Markdown 文件，文件名格式：

```
YYYY-MM-DD-title.md
```

示例 Front Matter：

```yaml
---
title: 文章标题
date: YYYY-MM-DD HH:MM:SS +0800
categories: [分类1, 子分类]
tags: [标签1, 标签2]
---
```

## 部署

推送到 GitHub 后，GitHub Actions 会自动构建和部署到 GitHub Pages。

## 技术栈

- 静态站点生成器：Jekyll 4.x
- 主题：[Chirpy](https://github.com/cotes2020/jekyll-theme-chirpy)
- 部署：GitHub Pages + GitHub Actions
- 本地开发：Docker + docker-compose

## License

本项目遵循主题的 MIT License。
