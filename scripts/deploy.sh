#!/bin/bash

# Gitea OpenAI Review Bot 部署脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# 检查必要的环境变量
check_env_vars() {
    log_info "检查环境变量..."

    required_vars=(
        "GITEA_URL"
        "GITEA_BOT_TOKEN"
        "GITEA_WEBHOOK_SECRET"
        "OPENAI_API_KEY"
    )

    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            log_error "环境变量 $var 未设置"
            exit 1
        fi
    done

    log_info "环境变量检查通过"
}

# 检查 Docker 和 Docker Compose
check_docker() {
    log_info "检查 Docker 环境..."

    if ! command -v docker &> /dev/null; then
        log_error "Docker 未安装"
        exit 1
    fi

    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose 未安装"
        exit 1
    fi

    log_info "Docker 环境检查通过"
}

# 创建必要的目录
create_directories() {
    log_info "创建必要的目录..."

    mkdir -p logs
    mkdir -p data/redis

    log_info "目录创建完成"
}

# 构建和部署
deploy() {
    log_info "开始部署..."

    # 停止现有容器
    docker-compose down 2>/dev/null || true

    # 构建镜像
    log_info "构建 Docker 镜像..."
    docker-compose build

    # 启动服务
    log_info "启动服务..."
    docker-compose up -d

    # 等待服务启动
    log_info "等待服务启动..."
    sleep 10

    # 健康检查
    if curl -f http://localhost:8080/health > /dev/null 2>&1; then
        log_info "服务启动成功！"
    else
        log_error "服务启动失败"
        docker-compose logs
        exit 1
    fi
}

# 测试部署
test_deployment() {
    log_info "测试部署..."

    # 测试健康检查端点
    if curl -f http://localhost:8080/health > /dev/null 2>&1; then
        log_info "健康检查通过"
    else
        log_error "健康检查失败"
        exit 1
    fi

    # 测试 OpenAI 连接 (可选)
    if [ -n "$OPENAI_API_KEY" ]; then
        log_info "测试 OpenAI 连接..."
        # 这里可以添加 OpenAI 连接测试
        log_info "OpenAI 连接测试跳过 (需要实现)"
    fi
}

# 显示部署信息
show_deployment_info() {
    log_info "部署完成！"
    echo ""
    echo "服务信息:"
    echo "  - URL: http://localhost:8080"
    echo "  - 健康检查: http://localhost:8080/health"
    echo ""
    echo "Webhook 配置:"
    echo "  - URL: http://your-server:8080/webhook"
    echo "  - Content-Type: application/json"
    echo "  - Secret: $GITEA_WEBHOOK_SECRET"
    echo ""
    echo "常用命令:"
    echo "  - 查看日志: docker-compose logs -f"
    echo "  - 停止服务: docker-compose down"
    echo "  - 重启服务: docker-compose restart"
    echo ""
}

# 主函数
main() {
    echo "=== Gitea OpenAI Review Bot 部署脚本 ==="
    echo ""

    # 检查参数
    if [ "$1" = "help" ] || [ "$1" = "-h" ]; then
        echo "用法: $0 [选项]"
        echo ""
        echo "选项:"
        echo "  help, -h     显示帮助信息"
        echo "  test         仅运行测试"
        echo "  stop         停止服务"
        echo "  restart      重启服务"
        echo "  logs         查看日志"
        echo ""
        exit 0
    fi

    # 处理不同的命令
    case "$1" in
        "test")
            test_deployment
            exit 0
            ;;
        "stop")
            log_info "停止服务..."
            docker-compose down
            exit 0
            ;;
        "restart")
            log_info "重启服务..."
            docker-compose restart
            exit 0
            ;;
        "logs")
            docker-compose logs -f
            exit 0
            ;;
    esac

    # 执行部署流程
    check_env_vars
    check_docker
    create_directories
    deploy
    test_deployment
    show_deployment_info
}

# 运行主函数
main "$@"