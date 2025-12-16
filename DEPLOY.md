# GitHub Pages 部署指南

## 第一步：在 GitHub 创建仓库

1. 访问 [GitHub](https://github.com/new)
2. 创建一个新仓库，**仓库名必须是**: `liuxpng.github.io`
   - ⚠️ 这是特殊的 GitHub Pages 仓库命名格式：`<username>.github.io`
   - 仓库可以设为 Public（推荐）或 Private
3. **不要**勾选 "Initialize this repository with a README"
4. 点击 "Create repository"

## 第二步：推送代码到 GitHub

在本地项目目录执行：

```bash
# 添加远程仓库
git remote add origin https://github.com/liuxpng/liuxpng.github.io.git

# 推送代码
git push -u origin main
```

如果遇到权限问题，可能需要：
- 配置 SSH 密钥：[GitHub SSH 配置教程](https://docs.github.com/zh/authentication/connecting-to-github-with-ssh)
- 或使用 Personal Access Token

## 第三步：配置 GitHub Pages

1. 进入仓库的 Settings
2. 在左侧菜单找到 "Pages"
3. 在 "Build and deployment" 部分：
   - Source: 选择 **GitHub Actions**
   - （不是 "Deploy from a branch"）

## 第四步：等待部署完成

1. 进入仓库的 "Actions" 标签页
2. 查看 "Build and Deploy" 工作流状态
3. 等待构建完成（通常需要 2-3 分钟）
4. 如果出现绿色✓，说明部署成功

## 第五步：访问网站

部署成功后，访问：

```
https://liuxpng.github.io
```

## 后续使用

### 发布新文章

1. 在 `_posts/` 目录创建新的 Markdown 文件
2. 提交并推送到 GitHub：
   ```bash
   git add .
   git commit -m "新增文章：文章标题"
   git push
   ```
3. GitHub Actions 会自动重新构建和部署

### 本地预览

使用 Docker 在本地预览：

```bash
# 启动服务器
./dev.sh start

# 或后台运行
./dev.sh start-d
```

访问 http://localhost:4000 预览。

## 常见问题

### 1. 推送失败：Permission denied

使用 SSH 方式或配置 Personal Access Token。

### 2. GitHub Actions 构建失败

- 检查 Actions 标签页的错误日志
- 确保 _config.yml 中的 url 设置正确
- 检查文章的 Front Matter 格式是否正确

### 3. 网站无法访问

- 确认 GitHub Pages 设置为 GitHub Actions
- 等待几分钟让 DNS 生效
- 检查仓库名是否为 `liuxpng.github.io`

### 4. 样式丢失或显示不正常

- 检查 _config.yml 中的 `baseurl` 是否为空（应该是 `baseurl: ""`）
- 清除浏览器缓存

## 进阶配置

### 自定义域名

1. 购买域名并添加 DNS 记录：
   ```
   CNAME  www  liuxpng.github.io.
   ```
2. 在仓库根目录创建 `CNAME` 文件：
   ```
   www.yourdomain.com
   ```
3. 在 GitHub Pages 设置中配置自定义域名

### 添加评论系统

编辑 `_config.yml`，配置 Giscus（基于 GitHub Discussions）：

```yaml
comments:
  provider: giscus
  giscus:
    repo: liuxpng/liuxpng.github.io
    repo_id: # 在 https://giscus.app 获取
    category: Announcements
    category_id: # 在 https://giscus.app 获取
    mapping: pathname
    reactions_enabled: 1
```

配置步骤：
1. 访问 [giscus.app](https://giscus.app)
2. 按照提示配置并获取所需 ID
3. 更新 _config.yml

## 相关链接

- [Chirpy 主题文档](https://github.com/cotes2020/jekyll-theme-chirpy/wiki)
- [GitHub Pages 文档](https://docs.github.com/zh/pages)
- [Jekyll 文档](https://jekyllrb.com/docs/)
