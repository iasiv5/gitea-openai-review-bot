# Gitea OpenAI Review Bot

🤖 基于 OpenAI GPT-4 的 Gitea 代码审查机器人

## 功能特性

- ✅ **智能代码审查**: 使用 GPT-4 进行深度代码分析
- ✅ **多语言支持**: 支持 Go、Python、JavaScript、TypeScript、Java、C++ 等主流语言
- ✅ **实时审查**: 通过 Webhook 实时响应 PR 事件
- ✅ **多维度分析**: 代码质量、安全性、性能、可读性
- ✅ **智能建议**: 提供具体的改进建议和代码示例
- ✅ **易于部署**: 支持本地二进制部署，跨平台兼容

## 快速开始

### 1. 准备工作

1. **系统要求**
   - Go 1.21 或更高版本
   - Git
   - Linux/macOS/Windows

2. **Gitea 环境**
   - 确保 Gitea 版本 >= 1.17
   - 创建机器人账号并生成访问令牌

3. **OpenAI API Key**
   - 注册 OpenAI 账号
   - 获取 API 密钥
   - 确保余额充足

### 2. 本地部署 (推荐)

#### 🚀 方式 1: 一键自动安装

##### Linux / macOS

```bash
# 克隆项目
git clone https://github.com/iasiv5/gitea-openai-review-bot.git
cd gitea-openai-review-bot

# 一键安装
chmod +x scripts/install.sh
./scripts/install.sh

# 配置环境变量
vim ~/.local/share/gitea-openai-review-bot/.env

# 启动服务
gitea-openai-review-bot
```

##### Windows

```cmd
REM 克隆项目
git clone https://github.com/iasiv5/gitea-openai-review-bot.git
cd gitea-openai-review-bot

REM 一键安装
scripts\windows-install.bat

REM 配置环境变量（脚本会自动打开记事本）
REM 编辑弹出的配置文件并保存

REM 启动服务（双击桌面快捷方式或运行以下命令）
scripts\windows-start.bat start
```

#### 🔧 方式 2: 手动安装

##### Linux / macOS

```bash
# 1. 构建应用
chmod +x scripts/build.sh
./scripts/build.sh

# 2. 配置环境变量
cp .env.example .env
vim .env

# 3. 启动服务
chmod +x scripts/start.sh
./scripts/start.sh start
```

##### Windows

```cmd
REM 1. 构建应用
scripts\build.bat

REM 2. 配置环境变量
copy .env.example .env
notepad .env

REM 3. 启动服务
scripts\windows-start.bat start
```

#### 💻 方式 3: 直接运行（开发者）

##### Linux / macOS

```bash
# 1. 安装依赖
go mod download

# 2. 构建应用
go build -o gitea-review-bot cmd/main.go

# 3. 配置环境变量
cp .env.example .env

# 4. 运行应用
./gitea-review-bot
```

##### Windows

```cmd
REM 1. 安装依赖
go mod download

REM 2. 构建应用
go build -o gitea-review-bot.exe cmd/main.go

REM 3. 配置环境变量
copy .env.example .env
notepad .env

REM 4. 运行应用
gitea-review-bot.exe
```

### 3. 服务管理

#### Linux / macOS

```bash
# 启动服务
./scripts/start.sh start

# 停止服务
./scripts/start.sh stop

# 重启服务
./scripts/start.sh restart

# 查看状态
./scripts/start.sh status

# 查看日志
./scripts/start.sh logs
```

#### Windows

```cmd
REM 启动服务
scripts\windows-start.bat start

REM 停止服务
scripts\windows-start.bat stop

REM 重启服务
scripts\windows-start.bat restart

REM 查看状态
scripts\windows-start.bat status

REM 查看日志
scripts\windows-start.bat logs

REM 或者双击桌面快捷方式启动服务
```

### 4. 系统服务 (可选)

如果你希望服务开机自启，可以创建系统服务：

#### Linux (systemd)

```bash
# 启用并启动服务
sudo systemctl enable gitea-review-bot
sudo systemctl start gitea-review-bot

# 查看服务状态
sudo systemctl status gitea-review-bot

# 查看日志
sudo journalctl -u gitea-review-bot -f
```

#### macOS (launchd)

```bash
# 加载并启动服务
launchctl load ~/Library/LaunchAgents/com.yourorg.gitea-review-bot.plist
launchctl start com.yourorg.gitea-review-bot
```

#### Windows (Windows Service)

```cmd
REM 使用 NSSM 创建 Windows 服务
nssm install "Gitea Review Bot" "C:\path\to\gitea-openai-review-bot.exe"

REM 启动服务
nssm start "Gitea Review Bot"
```

### 5. 配置 Gitea Webhook

1. 进入 Gitea 仓库设置
2. 添加 Webhook:
   - **URL**: `http://your-bot-url:8080/webhook`
   - **Content Type**: `application/json`
   - **Secret**: 与配置文件中的 `webhook_secret` 相同
   - **Events**: 选择 `Pull Request` 事件

## 配置说明

### 环境变量

| 变量名 | 说明 | 示例 |
|--------|------|------|
| `GITEA_URL` | Gitea 服务器地址 | `https://gitea.example.com` |
| `GITEA_BOT_TOKEN` | Gitea 机器人令牌 | `gitea_xxxxxxxxxxxx` |
| `GITEA_WEBHOOK_SECRET` | Webhook 密钥 | `your-secret-key` |
| `OPENAI_API_KEY` | OpenAI API 密钥 | `sk-xxxxxxxxxxxxxx` |

### 配置文件 (config.yaml)

```yaml
openai:
  model: "gpt-4"          # 使用的模型
  max_tokens: 2000        # 最大 token 数
  temperature: 0.3        # 温度参数

review:
  enabled_file_types:     # 支持的文件类型
    - ".go"
    - ".py"
    - ".js"
  max_file_size: 1048576  # 最大文件大小 (1MB)
  max_diff_size: 102400   # 最大差异大小 (100KB)
```

## 使用效果

### 审查报告示例

```
## 🤖 AI 代码审查报告

### 📊 整体评分
- **质量评分**: 8/10
- **代码质量**: 良好
- **可读性**: 良好
- **复杂度**: 中等

### 📝 审查总结
代码整体结构清晰，功能实现正确。建议优化异常处理和日志记录。

### 🔍 发现的问题
- **第10行**: 潜在的空指针异常 (warning)
- **第25行**: 未使用的变量 (info)

### 💡 改进建议
- **第10行**: 添加空值检查
- **第15行**: 使用更描述性的变量名
```

## 监控和日志

### 健康检查

```bash
curl http://localhost:8080/health
```

### 查看日志

#### Linux / macOS

```bash
# 使用管理脚本
./scripts/start.sh logs

# 或者直接查看日志文件
tail -f logs/app.log
```

#### Windows

```cmd
# 使用管理脚本
scripts\windows-start.bat logs

# 或者直接查看日志文件
type logs\app.log
```

### 监控指标

- PR 审查数量
- API 调用次数
- 响应时间
- 错误率

## 故障排除

### 常见问题

1. **Webhook 验证失败**
   - 检查 `webhook_secret` 配置
   - 确认 Gitea 中的 Webhook 配置正确

2. **OpenAI API 调用失败**
   - 验证 API 密钥是否正确
   - 检查 API 余额是否充足
   - 确认网络连接正常

3. **权限问题**
   - 确认机器人账号有足够的权限
   - 检查 Gitea 令牌权限设置

### 调试模式

```bash
# 启用调试日志
export LOG_LEVEL=debug
./gitea-review-bot
```

## 开发指南

### 本地开发

```bash
# 安装依赖
go mod download

# 运行测试
go test ./...

# 启动开发服务器
go run cmd/main.go
```

### 贡献代码

1. Fork 项目
2. 创建功能分支
3. 提交变更
4. 创建 Pull Request

## 成本估算

### OpenAI API 成本

- **GPT-4**: ~$0.03-0.06 per 1K tokens
- **平均每个 PR**: $0.10-0.50
- **月度估算**: $20-100 (根据 PR 数量)

### 优化建议

- 限制审查的文件大小
- 使用缓存减少重复分析
- 设置合理的并发数量

## 许可证

MIT License

## 项目链接

- 🏠 **GitHub 仓库**: https://github.com/iasiv5/gitea-openai-review-bot
- 📖 **在线文档**: https://github.com/iasiv5/gitea-openai-review-bot/blob/main/docs/local-setup-guide.md
- 🐛 **问题反馈**: https://github.com/iasiv5/gitea-openai-review-bot/issues
- 💬 **讨论交流**: https://github.com/iasiv5/gitea-openai-review-bot/discussions

## Star 历史

如果这个项目对你有帮助，请给它一个 ⭐ Star！

## 支持

- 📧 Email: support@example.com
- 💬 GitHub Issues: [创建问题](https://github.com/iasiv5/gitea-openai-review-bot/issues)
- 📖 文档: [详细文档](https://github.com/iasiv5/gitea-openai-review-bot/blob/main/docs/local-setup-guide.md)