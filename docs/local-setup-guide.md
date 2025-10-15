# 本地环境搭建指南

## 系统要求

- **操作系统**: Linux, macOS, Windows 10+
- **Go 版本**: 1.21 或更高版本
- **Git**: 最新版本
- **内存**: 至少 512MB 可用内存
- **磁盘空间**: 至少 100MB 可用空间

## 快速安装

### Linux / macOS

```bash
# 1. 克隆项目
git clone https://github.com/your-org/gitea-openai-review-bot.git
cd gitea-openai-review-bot

# 2. 自动安装
chmod +x scripts/install.sh
./scripts/install.sh

# 3. 配置环境变量
vim ~/.local/share/gitea-openai-review-bot/.env

# 4. 启动服务
gitea-openai-review-bot
```

### Windows

```cmd
REM 1. 克隆项目
git clone https://github.com/your-org/gitea-openai-review-bot.git
cd gitea-openai-review-bot

REM 2. 自动安装
scripts\windows-install.bat

REM 3. 配置环境变量
notepad %USERPROFILE%\gitea-openai-review-bot\.env

REM 4. 启动服务
REM 双击桌面快捷方式或运行启动脚本
```

## 手动安装

### 1. 环境准备

#### 安装 Go

**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install golang-go
```

**CentOS/RHEL:**
```bash
sudo yum install golang
# 或者使用 EPEL
sudo yum install epel-release
sudo yum install golang
```

**macOS:**
```bash
# 使用 Homebrew
brew install go

# 或者从官网下载
# https://golang.org/dl/
```

**Windows:**
- 从官网下载安装包: https://golang.org/dl/
- 运行安装程序并按照提示操作

#### 验证 Go 安装

```bash
go version
# 应该显示类似: go version go1.21.x linux/amd64
```

### 2. 构建应用

#### Linux / macOS

```bash
# 进入项目目录
cd gitea-openai-review-bot

# 构建应用
chmod +x scripts/build.sh
./scripts/build.sh
```

#### Windows

```cmd
REM 进入项目目录
cd gitea-openai-review-bot

REM 构建应用
scripts\build.bat
```

### 3. 配置环境变量

```bash
# 复制环境变量模板
cp .env.example .env

# 编辑配置文件
vim .env  # Linux/macOS
notepad .env  # Windows
```

#### 必需配置项

```bash
# Gitea 配置
GITEA_URL=https://your-gitea.com
GITEA_BOT_TOKEN=your-gitea-bot-token
GITEA_WEBHOOK_SECRET=your-webhook-secret

# OpenAI 配置
OPENAI_API_KEY=your-openai-api-key

# 可选配置
LOG_LEVEL=info
MAX_CONCURRENT_REVIEWS=5
ENABLE_CACHE=true
```

#### 获取 Gitea Bot Token

1. 登录 Gitea
2. 进入 **设置** > **应用**
3. 创建新的 **访问令牌**
4. 选择权限: `repo:write`, `admin:repo_hook`
5. 复制生成的令牌

#### 获取 OpenAI API Key

1. 登录 OpenAI 平台: https://platform.openai.com/
2. 进入 **API Keys** 页面
3. 创建新的 API Key
4. 复制并妥善保存

### 4. 启动服务

#### Linux / macOS

```bash
# 使用启动脚本
chmod +x scripts/start.sh
./scripts/start.sh start

# 或者直接运行
./dist/gitea-openai-review-bot
```

#### Windows

```cmd
REM 使用启动脚本
scripts\windows-start.bat start

REM 或者直接运行
dist\gitea-openai-review-bot.exe

REM 或者使用桌面快捷方式
```

### 5. 验证安装

```bash
# 检查服务状态
./scripts/start.sh status  # Linux/macOS
scripts\windows-start.bat status  # Windows

# 健康检查
curl http://localhost:8080/health

# 查看日志
./scripts/start.sh logs  # Linux/macOS
scripts\windows-start.bat logs  # Windows
```

## 服务管理

### 启动服务

```bash
# Linux/macOS
./scripts/start.sh start

# Windows
scripts\windows-start.bat start
```

### 停止服务

```bash
# Linux/macOS
./scripts/start.sh stop

# Windows
scripts\windows-start.bat stop
```

### 重启服务

```bash
# Linux/macOS
./scripts/start.sh restart

# Windows
scripts\windows-start.bat restart
```

### 查看状态

```bash
# Linux/macOS
./scripts/start.sh status

# Windows
scripts\windows-start.bat status
```

### 查看日志

```bash
# Linux/macOS
./scripts/start.sh logs

# Windows
scripts\windows-start.bat logs
```

## 系统服务配置

### Linux (systemd)

```bash
# 创建服务文件
sudo vim /etc/systemd/system/gitea-review-bot.service
```

```ini
[Unit]
Description=Gitea OpenAI Review Bot
After=network.target

[Service]
Type=simple
User=your-username
WorkingDirectory=/path/to/gitea-openai-review-bot
ExecStart=/path/to/gitea-openai-review-bot
Restart=always
RestartSec=10
Environment=HOME=/home/your-username

[Install]
WantedBy=multi-user.target
```

```bash
# 启用并启动服务
sudo systemctl enable gitea-review-bot
sudo systemctl start gitea-review-bot

# 查看服务状态
sudo systemctl status gitea-review-bot
```

### macOS (launchd)

```bash
# 创建 launch agent
vim ~/Library/LaunchAgents/com.yourorg.gitea-review-bot.plist
```

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.yourorg.gitea-review-bot</string>
    <key>ProgramArguments</key>
    <array>
        <string>/path/to/gitea-openai-review-bot</string>
    </array>
    <key>WorkingDirectory</key>
    <string>/path/to/project</string>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
```

```bash
# 加载并启动服务
launchctl load ~/Library/LaunchAgents/com.yourorg.gitea-review-bot.plist
launchctl start com.yourorg.gitea-review-bot
```

### Windows (Windows Service)

使用 NSSM (Non-Sucking Service Manager) 创建 Windows 服务:

```cmd
REM 下载并安装 NSSM
REM https://nssm.cc/download

REM 安装服务
nssm install "Gitea Review Bot" "C:\path\to\gitea-openai-review-bot.exe"

REM 配置服务
nssm edit "Gitea Review Bot"

REM 启动服务
nssm start "Gitea Review Bot"
```

## 配置 Gitea Webhook

1. 进入 Gitea 仓库设置
2. 选择 **Webhooks** > **添加 Webhook**
3. 配置 Webhook:
   - **目标 URL**: `http://your-server:8080/webhook`
   - **Content Type**: `application/json`
   - **Secret**: 与环境变量 `GITEA_WEBHOOK_SECRET` 相同
   - **事件**: 选择 **Pull Request** 事件
4. 点击 **添加 Webhook**

## 故障排除

### 常见问题

#### 1. 端口被占用

```bash
# 查看端口占用
netstat -tlnp | grep :8080  # Linux
netstat -ano | findstr :8080  # Windows

# 修改配置文件中的端口
vim configs/config.yaml
```

#### 2. 权限问题

```bash
# Linux/macOS
chmod +x scripts/*.sh
chmod +x dist/gitea-openai-review-bot

# Windows
# 以管理员身份运行
```

#### 3. 环境变量问题

```bash
# 检查环境变量文件
cat .env

# 验证必要变量
echo $GITEA_URL
echo $OPENAI_API_KEY
```

#### 4. 网络连接问题

```bash
# 测试 Gitea 连接
curl -H "Authorization: token $GITEA_BOT_TOKEN" $GITEA_URL/api/v1/user

# 测试 OpenAI 连接
curl -H "Authorization: Bearer $OPENAI_API_KEY" https://api.openai.com/v1/models
```

### 日志分析

```bash
# 查看详细日志
tail -f logs/app.log

# 搜索错误
grep -i error logs/app.log

# 查看启动日志
grep -i "starting" logs/app.log
```

### 性能优化

1. **调整并发数量**
   ```yaml
   # configs/config.yaml
   advanced:
     max_concurrent_reviews: 3
   ```

2. **启用缓存**
   ```yaml
   advanced:
     enable_cache: true
     cache_ttl: 24
   ```

3. **限制文件大小**
   ```yaml
   review:
     max_file_size: 512000  # 512KB
     max_diff_size: 50000   # 50KB
   ```

## 卸载

### Linux / macOS

```bash
# 停止服务
./scripts/start.sh stop

# 如果安装了系统服务
sudo systemctl stop gitea-review-bot
sudo systemctl disable gitea-review-bot
sudo rm /etc/systemd/system/gitea-review-bot.service

# 删除文件
rm -rf ~/.local/share/gitea-openai-review-bot
rm -f ~/.local/bin/gitea-openai-review-bot
```

### Windows

```cmd
REM 停止服务
scripts\windows-start.bat stop

REM 删除安装目录
rmdir /s "%USERPROFILE%\gitea-openai-review-bot"

REM 删除桌面快捷方式
del "%USERPROFILE%\Desktop\Gitea Review Bot.lnk"
```

## 技术支持

- **文档**: [项目 README](../README.md)
- **问题反馈**: [GitHub Issues](https://github.com/your-org/gitea-openai-review-bot/issues)
- **社区讨论**: [GitHub Discussions](https://github.com/your-org/gitea-openai-review-bot/discussions)