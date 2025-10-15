#!/bin/bash

# Gitea OpenAI Review Bot 安装脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# 项目配置
PROJECT_NAME="gitea-openai-review-bot"
INSTALL_DIR="$HOME/.local/share/$PROJECT_NAME"
BIN_DIR="$HOME/.local/bin"
SERVICE_NAME="gitea-review-bot"

# 检查操作系统
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="linux"
        ARCH=$(uname -m)
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="darwin"
        ARCH=$(uname -m)
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        OS="windows"
        ARCH=$(uname -m)
    else
        log_error "不支持的操作系统: $OSTYPE"
        exit 1
    fi

    # 标准化架构名称
    case $ARCH in
        x86_64)
            ARCH="amd64"
            ;;
        aarch64|arm64)
            ARCH="arm64"
            ;;
        *)
            log_error "不支持的架构: $ARCH"
            exit 1
            ;;
    esac

    log_info "检测到系统: $OS/$ARCH"
}

# 检查依赖
check_dependencies() {
    log_step "检查系统依赖..."

    # 检查 Go
    if ! command -v go &> /dev/null; then
        log_error "Go 未安装，请先安装 Go 1.21 或更高版本"
        echo "安装方法:"
        echo "  Ubuntu/Debian: sudo apt install golang-go"
        echo "  CentOS/RHEL: sudo yum install golang"
        echo "  macOS: brew install go"
        echo "  Windows: 从 https://golang.org/dl/ 下载安装"
        exit 1
    fi

    # 检查 Git
    if ! command -v git &> /dev/null; then
        log_error "Git 未安装，请先安装 Git"
        exit 1
    fi

    log_info "依赖检查通过"
}

# 创建安装目录
create_directories() {
    log_step "创建安装目录..."

    mkdir -p "$INSTALL_DIR"
    mkdir -p "$BIN_DIR"
    mkdir -p "$INSTALL_DIR/configs"
    mkdir -p "$INSTALL_DIR/logs"
    mkdir -p "$INSTALL_DIR/data"

    log_info "目录创建完成"
}

# 构建应用
build_application() {
    log_step "构建应用..."

    # 设置构建信息
    VERSION="1.0.0"
    BUILD_TIME=$(date -u '+%Y-%m-%d_%H:%M:%S')
    GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    GO_VERSION=$(go version | awk '{print $3}')

    # 构建参数
    LDFLAGS="-X main.Version=$VERSION -X main.BuildTime=$BUILD_TIME -X main.GitCommit=$GIT_COMMIT -X main.GoVersion=$GO_VERSION"

    # 构建应用
    go build -ldflags "$LDFLAGS" -o "$INSTALL_DIR/$PROJECT_NAME" cmd/main.go

    log_info "应用构建完成"
}

# 安装配置文件
install_config() {
    log_step "安装配置文件..."

    # 复制配置文件
    cp -r configs/* "$INSTALL_DIR/configs/"

    # 复制环境变量模板
    cp .env.example "$INSTALL_DIR/.env.example"

    # 创建主配置文件
    if [ ! -f "$INSTALL_DIR/.env" ]; then
        cp .env.example "$INSTALL_DIR/.env"
        log_warn "请编辑 $INSTALL_DIR/.env 文件配置你的设置"
    fi

    log_info "配置文件安装完成"
}

# 创建启动脚本
create_launcher() {
    log_step "创建启动脚本..."

    # 创建启动脚本
    cat > "$INSTALL_DIR/start.sh" << EOF
#!/bin/bash

# Gitea OpenAI Review Bot 启动脚本

cd "$INSTALL_DIR"

# 检查环境变量文件
if [ ! -f ".env" ]; then
    echo "错误: .env 文件不存在，请从 .env.example 复制并配置"
    exit 1
fi

# 加载环境变量
source .env

# 创建日志目录
mkdir -p logs

# 启动应用
echo "启动 Gitea OpenAI Review Bot..."
./$PROJECT_NAME
EOF

    chmod +x "$INSTALL_DIR/start.sh"

    # 创建命令行快捷方式
    cat > "$BIN_DIR/$PROJECT_NAME" << EOF
#!/bin/bash

cd "$INSTALL_DIR"
exec ./start.sh "\$@"
EOF

    chmod +x "$BIN_DIR/$PROJECT_NAME"

    log_info "启动脚本创建完成"
}

# 创建系统服务 (可选)
create_systemd_service() {
    if [ "$OS" = "linux" ] && command -v systemctl &> /dev/null; then
        log_step "创建系统服务..."

        cat > "/tmp/$SERVICE_NAME.service" << EOF
[Unit]
Description=Gitea OpenAI Review Bot
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$INSTALL_DIR
Environment=HOME=$HOME
ExecStart=$INSTALL_DIR/$PROJECT_NAME
Restart=always
RestartSec=10

# 日志配置
StandardOutput=journal
StandardError=journal
SyslogIdentifier=$SERVICE_NAME

# 安全配置
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$INSTALL_DIR/logs $INSTALL_DIR/data

[Install]
WantedBy=multi-user.target
EOF

        # 安装服务文件
        sudo mv "/tmp/$SERVICE_NAME.service" "/etc/systemd/system/"

        # 重新加载 systemd
        sudo systemctl daemon-reload

        log_info "系统服务创建完成"
        log_info "使用以下命令管理服务:"
        echo "  启动: sudo systemctl start $SERVICE_NAME"
        echo "  停止: sudo systemctl stop $SERVICE_NAME"
        echo "  状态: sudo systemctl status $SERVICE_NAME"
        echo "  开机自启: sudo systemctl enable $SERVICE_NAME"
    else
        log_info "跳过系统服务创建 (不支持)"
    fi
}

# 设置权限
set_permissions() {
    log_step "设置文件权限..."

    chmod +x "$INSTALL_DIR/$PROJECT_NAME"
    chmod +x "$INSTALL_DIR/start.sh"
    chmod +x "$BIN_DIR/$PROJECT_NAME"

    log_info "权限设置完成"
}

# 显示安装信息
show_install_info() {
    log_info "安装完成！"
    echo ""
    echo "安装位置: $INSTALL_DIR"
    echo "可执行文件: $BIN_DIR/$PROJECT_NAME"
    echo ""
    echo "使用方法:"
    echo "  1. 编辑配置文件: vim $INSTALL_DIR/.env"
    echo "  2. 启动应用: $PROJECT_NAME"
    echo "  3. 或者: $INSTALL_DIR/start.sh"
    echo ""
    echo "日志位置: $INSTALL_DIR/logs/"
    echo "配置文件: $INSTALL_DIR/.env"
    echo ""
    echo "卸载方法:"
    echo "  1. 停止服务: sudo systemctl stop $SERVICE_NAME"
    echo "  2. 删除服务: sudo systemctl disable $SERVICE_NAME"
    echo "  3. 删除文件: rm -rf $INSTALL_DIR $BIN_DIR/$PROJECT_NAME"
}

# 卸载函数
uninstall() {
    log_step "卸载 $PROJECT_NAME..."

    # 停止并禁用服务
    if [ "$OS" = "linux" ] && command -v systemctl &> /dev/null; then
        sudo systemctl stop "$SERVICE_NAME" 2>/dev/null || true
        sudo systemctl disable "$SERVICE_NAME" 2>/dev/null || true
        sudo rm -f "/etc/systemd/system/$SERVICE_NAME.service"
        sudo systemctl daemon-reload
    fi

    # 删除文件
    rm -rf "$INSTALL_DIR"
    rm -f "$BIN_DIR/$PROJECT_NAME"

    log_info "卸载完成"
}

# 主函数
main() {
    echo "=== Gitea OpenAI Review Bot 安装脚本 ==="
    echo ""

    # 处理命令行参数
    case "$1" in
        "uninstall")
            uninstall
            exit 0
            ;;
        "help"|"-h")
            echo "用法: $0 [选项]"
            echo ""
            echo "选项:"
            echo "  uninstall  卸载应用"
            echo "  help, -h   显示帮助信息"
            echo ""
            echo "默认行为: 安装应用"
            exit 0
            ;;
    esac

    # 检查是否在项目根目录
    if [ ! -f "go.mod" ] || [ ! -d "cmd" ]; then
        log_error "请在项目根目录运行此脚本"
        exit 1
    fi

    # 执行安装流程
    detect_os
    check_dependencies
    create_directories
    build_application
    install_config
    create_launcher
    set_permissions
    create_systemd_service
    show_install_info
}

# 运行主函数
main "$@"