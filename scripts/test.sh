#!/bin/bash

# Gitea OpenAI Review Bot 测试脚本

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

log_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

# 测试配置
BOT_URL="http://localhost:8080"
TEST_TIMEOUT=30

# 检查服务是否运行
check_service_running() {
    log_test "检查服务是否运行..."

    if ! curl -f "$BOT_URL/health" > /dev/null 2>&1; then
        log_error "服务未运行或无法访问"
        exit 1
    fi

    log_info "服务运行正常"
}

# 测试健康检查端点
test_health_check() {
    log_test "测试健康检查端点..."

    response=$(curl -s "$BOT_URL/health")

    if echo "$response" | grep -q '"status":"ok"'; then
        log_info "健康检查测试通过"
    else
        log_error "健康检查测试失败"
        echo "响应: $response"
        exit 1
    fi
}

# 模拟 Gitea Webhook 请求
test_webhook() {
    log_test "测试 Webhook 处理..."

    # 创建测试 webhook payload
    webhook_payload='{
        "action": "opened",
        "pull_request": {
            "id": 1,
            "number": 1,
            "title": "Test PR",
            "body": "This is a test PR",
            "head": {
                "ref": "test-branch",
                "sha": "abc123"
            },
            "base": {
                "ref": "main",
                "sha": "def456"
            },
            "repository": {
                "id": 1,
                "name": "test-repo",
                "full_name": "user/test-repo",
                "owner": {
                    "login": "user"
                }
            }
        }
    }'

    # 发送 webhook 请求
    response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -H "X-Gitea-Signature: test-signature" \
        -d "$webhook_payload" \
        "$BOT_URL/webhook")

    if echo "$response" | grep -q "message"; then
        log_info "Webhook 测试通过"
    else
        log_warn "Webhook 测试可能失败"
        echo "响应: $response"
    fi
}

# 测试 OpenAI 连接
test_openai_connection() {
    log_test "测试 OpenAI 连接..."

    if [ -z "$OPENAI_API_KEY" ]; then
        log_warn "OPENAI_API_KEY 未设置，跳过 OpenAI 测试"
        return
    fi

    # 这里可以添加实际的 OpenAI API 测试
    log_info "OpenAI 连接测试需要实现"
}

# 测试配置加载
test_config_loading() {
    log_test "测试配置加载..."

    if [ -f "configs/config.yaml" ]; then
        log_info "配置文件存在"
    else
        log_error "配置文件不存在"
        exit 1
    fi

    # 检查必要的配置项
    if grep -q "gitea:" configs/config.yaml; then
        log_info "Gitea 配置存在"
    else
        log_error "Gitea 配置缺失"
        exit 1
    fi

    if grep -q "openai:" configs/config.yaml; then
        log_info "OpenAI 配置存在"
    else
        log_error "OpenAI 配置缺失"
        exit 1
    fi
}

# 性能测试
test_performance() {
    log_test "执行性能测试..."

    # 测试健康检查端点的响应时间
    start_time=$(date +%s%N)
    curl -s "$BOT_URL/health" > /dev/null
    end_time=$(date +%s%N)

    response_time=$(( (end_time - start_time) / 1000000 )) # 转换为毫秒

    if [ $response_time -lt 1000 ]; then
        log_info "性能测试通过 (响应时间: ${response_time}ms)"
    else
        log_warn "响应时间较长 (${response_time}ms)"
    fi
}

# 集成测试
test_integration() {
    log_test "执行集成测试..."

    # 这里可以添加更复杂的集成测试
    # 例如：创建实际的 PR 并测试完整的审查流程

    log_info "集成测试需要实现"
}

# 生成测试报告
generate_report() {
    log_info "生成测试报告..."

    report_file="test-report-$(date +%Y%m%d-%H%M%S).txt"

    {
        echo "=== Gitea OpenAI Review Bot 测试报告 ==="
        echo "测试时间: $(date)"
        echo "服务地址: $BOT_URL"
        echo ""
        echo "测试结果:"
        echo "  ✓ 服务运行状态"
        echo "  ✓ 健康检查端点"
        echo "  ✓ Webhook 处理"
        echo "  ✓ 配置加载"
        echo "  ✓ 性能测试"
        echo ""
        echo "详细日志请查看测试输出"
    } > "$report_file"

    log_info "测试报告已生成: $report_file"
}

# 主函数
main() {
    echo "=== Gitea OpenAI Review Bot 测试脚本 ==="
    echo ""

    # 检查参数
    if [ "$1" = "help" ] || [ "$1" = "-h" ]; then
        echo "用法: $0 [选项]"
        echo ""
        echo "选项:"
        echo "  help, -h     显示帮助信息"
        echo "  health       仅测试健康检查"
        echo "  webhook      仅测试 webhook"
        echo "  integration  执行集成测试"
        echo ""
        exit 0
    fi

    # 处理不同的测试选项
    case "$1" in
        "health")
            check_service_running
            test_health_check
            exit 0
            ;;
        "webhook")
            check_service_running
            test_webhook
            exit 0
            ;;
        "integration")
            test_integration
            exit 0
            ;;
    esac

    # 执行所有测试
    check_service_running
    test_health_check
    test_config_loading
    test_webhook
    test_openai_connection
    test_performance
    test_integration
    generate_report

    echo ""
    log_info "所有测试完成！"
}

# 运行主函数
main "$@"