#!/bin/bash

# Gitea OpenAI Review Bot 启动脚本

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
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PID_FILE="$PROJECT_DIR/app.pid"
LOG_FILE="$PROJECT_DIR/logs/app.log"

# 检查二进制文件
check_binary() {
    if [ ! -f "$PROJECT_DIR/dist/$PROJECT_NAME" ] && [ ! -f "$PROJECT_DIR/$PROJECT_NAME" ]; then
        log_error "找不到可执行文件，请先运行构建脚本"
        echo "运行: ./scripts/build.sh"
        exit 1
    fi

    # 确定可执行文件路径
    if [ -f "$PROJECT_DIR/dist/$PROJECT_NAME" ]; then
        BINARY_PATH="$PROJECT_DIR/dist/$PROJECT_NAME"
    else
        BINARY_PATH="$PROJECT_DIR/$PROJECT_NAME"
    fi

    log_info "使用可执行文件: $BINARY_PATH"
}

# 检查配置文件
check_config() {
    log_step "检查配置文件..."

    if [ ! -f "$PROJECT_DIR/.env" ]; then
        log_warn ".env 文件不存在，从模板创建..."
        cp "$PROJECT_DIR/.env.example" "$PROJECT_DIR/.env"
        log_warn "请编辑 $PROJECT_DIR/.env 文件配置你的设置"
        exit 1
    fi

    # 加载环境变量
    source "$PROJECT_DIR/.env"

    # 检查必要的环境变量
    required_vars=("GITEA_URL" "GITEA_BOT_TOKEN" "OPENAI_API_KEY")
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            log_error "环境变量 $var 未设置"
            exit 1
        fi
    done

    log_info "配置文件检查通过"
}

# 创建日志目录
create_log_dir() {
    mkdir -p "$PROJECT_DIR/logs"
}

# 检查服务状态
check_status() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if ps -p "$PID" > /dev/null 2>&1; then
            log_info "服务正在运行 (PID: $PID)"
            return 0
        else
            log_warn "PID 文件存在但进程不存在，清理 PID 文件"
            rm -f "$PID_FILE"
            return 1
        fi
    else
        log_info "服务未运行"
        return 1
    fi
}

# 启动服务
start_service() {
    log_step "启动服务..."

    if check_status; then
        log_warn "服务已在运行"
        return 0
    fi

    # 创建日志目录
    create_log_dir

    # 启动应用
    cd "$PROJECT_DIR"

    log_info "启动 $PROJECT_NAME..."

    # 使用 nohup 启动服务
    nohup "$BINARY_PATH" > "$LOG_FILE" 2>&1 &
    PID=$!

    # 保存 PID
    echo $PID > "$PID_FILE"

    # 等待启动
    sleep 2

    # 检查是否启动成功
    if ps -p "$PID" > /dev/null 2>&1; then
        log_info "服务启动成功 (PID: $PID)"
        log_info "日志文件: $LOG_FILE"

        # 等待服务就绪
        log_info "等待服务就绪..."
        for i in {1..30}; do
            if curl -s http://localhost:8080/health > /dev/null 2>&1; then
                log_info "服务已就绪"
                break
            fi
            sleep 1
        done
    else
        log_error "服务启动失败，请检查日志: $LOG_FILE"
        rm -f "$PID_FILE"
        exit 1
    fi
}

# 停止服务
stop_service() {
    log_step "停止服务..."

    if ! check_status; then
        log_warn "服务未运行"
        return 0
    fi

    PID=$(cat "$PID_FILE")
    log_info "停止服务 (PID: $PID)..."

    # 发送 TERM 信号
    kill -TERM "$PID"

    # 等待进程结束
    for i in {1..10}; do
        if ! ps -p "$PID" > /dev/null 2>&1; then
            log_info "服务已停止"
            rm -f "$PID_FILE"
            return 0
        fi
        sleep 1
    done

    # 如果进程仍在运行，强制杀死
    log_warn "强制停止服务..."
    kill -KILL "$PID" 2>/dev/null || true
    rm -f "$PID_FILE"
    log_info "服务已强制停止"
}

# 重启服务
restart_service() {
    log_step "重启服务..."
    stop_service
    sleep 2
    start_service
}

# 查看日志
show_logs() {
    if [ -f "$LOG_FILE" ]; then
        tail -f "$LOG_FILE"
    else
        log_error "日志文件不存在: $LOG_FILE"
    fi
}

# 查看状态
show_status() {
    log_step "服务状态:"

    if check_status; then
        PID=$(cat "$PID_FILE")
        echo "状态: 运行中"
        echo "PID: $PID"
        echo "启动时间: $(ps -p "$PID" -o lstart=)"
        echo "内存使用: $(ps -p "$PID" -o rss= | awk '{print $1/1024 " MB"}')"
        echo "CPU 使用: $(ps -p "$PID" -o %cpu=)%"

        # 健康检查
        if curl -s http://localhost:8080/health > /dev/null 2>&1; then
            echo "健康检查: 通过"
        else
            echo "健康检查: 失败"
        fi
    else
        echo "状态: 未运行"
    fi
}

# 主函数
main() {
    echo "=== Gitea OpenAI Review Bot 启动脚本 ==="
    echo ""

    # 处理命令行参数
    case "$1" in
        "start")
            check_binary
            check_config
            start_service
            ;;
        "stop")
            stop_service
            ;;
        "restart")
            restart_service
            ;;
        "status")
            show_status
            ;;
        "logs")
            show_logs
            ;;
        "help"|"-h")
            echo "用法: $0 [命令]"
            echo ""
            echo "命令:"
            echo "  start    启动服务"
            echo "  stop     停止服务"
            echo "  restart  重启服务"
            echo "  status   查看状态"
            echo "  logs     查看日志"
            echo "  help, -h 显示帮助信息"
            echo ""
            echo "默认行为: start"
            ;;
        "")
            # 默认启动服务
            check_binary
            check_config
            start_service
            ;;
        *)
            log_error "未知命令: $1"
            echo "使用 '$0 help' 查看帮助"
            exit 1
            ;;
    esac
}

# 运行主函数
main "$@"