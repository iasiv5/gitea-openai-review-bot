#!/bin/bash

# Gitea OpenAI Review Bot 构建脚本

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

# 项目配置
PROJECT_NAME="gitea-openai-review-bot"
VERSION="1.0.0"
BUILD_DIR="build"
OUTPUT_DIR="dist"

# 清理旧的构建文件
clean_build() {
    log_info "清理旧的构建文件..."

    rm -rf "$BUILD_DIR"
    rm -rf "$OUTPUT_DIR"
    rm -f "$PROJECT_NAME"
    rm -f "$PROJECT_NAME.exe"

    log_info "清理完成"
}

# 检查依赖
check_dependencies() {
    log_info "检查构建依赖..."

    # 检查 Go
    if ! command -v go &> /dev/null; then
        log_error "Go 未安装，请先安装 Go 1.21 或更高版本"
        exit 1
    fi

    # 检查 Go 版本
    GO_VERSION=$(go version | awk '{print $3}' | sed 's/go//')
    log_info "Go 版本: $GO_VERSION"

    # 检查模块
    if [ ! -f "go.mod" ]; then
        log_error "go.mod 文件不存在，请在项目根目录运行此脚本"
        exit 1
    fi

    log_info "依赖检查通过"
}

# 下载依赖
download_dependencies() {
    log_info "下载 Go 模块依赖..."

    go mod download
    go mod verify

    log_info "依赖下载完成"
}

# 构建应用
build_app() {
    log_info "构建应用..."

    # 设置构建信息
    BUILD_TIME=$(date -u '+%Y-%m-%d_%H:%M:%S')
    GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    GO_VERSION=$(go version | awk '{print $3}')

    # 构建参数
    LDFLAGS="-X main.Version=$VERSION -X main.BuildTime=$BUILD_TIME -X main.GitCommit=$GIT_COMMIT -X main.GoVersion=$GO_VERSION"

    # 创建输出目录
    mkdir -p "$OUTPUT_DIR"

    # 构建当前平台
    log_info "构建当前平台..."
    go build -ldflags "$LDFLAGS" -o "$OUTPUT_DIR/$PROJECT_NAME" cmd/main.go

    log_info "构建完成: $OUTPUT_DIR/$PROJECT_NAME"
}

# 构建多平台版本
build_multi_platform() {
    log_info "构建多平台版本..."

    # 设置构建信息
    BUILD_TIME=$(date -u '+%Y-%m-%d_%H:%M:%S')
    GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    GO_VERSION=$(go version | awk '{print $3}')

    # 构建参数
    LDFLAGS="-X main.Version=$VERSION -X main.BuildTime=$BUILD_TIME -X main.GitCommit=$GIT_COMMIT -X main.GoVersion=$GO_VERSION"

    # 平台列表
    platforms=(
        "linux/amd64"
        "linux/arm64"
        "windows/amd64"
        "darwin/amd64"
        "darwin/arm64"
    )

    for platform in "${platforms[@]}"; do
        IFS='/' read -r os arch <<< "$platform"

        output_name="$PROJECT_NAME"
        if [ "$os" = "windows" ]; then
            output_name="$PROJECT_NAME.exe"
        fi

        # 创建平台特定目录
        platform_dir="$OUTPUT_DIR/$os-$arch"
        mkdir -p "$platform_dir"

        log_info "构建 $os/$arch..."
        GOOS=$os GOARCH=$arch go build -ldflags "$LDFLAGS" -o "$platform_dir/$output_name" cmd/main.go

        # 压缩二进制文件
        if command -v upx &> /dev/null; then
            log_info "压缩 $os/$arch 二进制文件..."
            upx --best "$platform_dir/$output_name" 2>/dev/null || true
        fi
    done

    log_info "多平台构建完成"
}

# 运行测试
run_tests() {
    log_info "运行测试..."

    go test -v ./...

    log_info "测试通过"
}

# 创建发布包
create_release_package() {
    log_info "创建发布包..."

    RELEASE_DIR="$OUTPUT_DIR/release"
    mkdir -p "$RELEASE_DIR"

    # 复制必要的文件
    cp -r configs "$RELEASE_DIR/"
    cp -r scripts "$RELEASE_DIR/"
    cp README.md "$RELEASE_DIR/"
    cp .env.example "$RELEASE_DIR/"

    # 创建启动脚本
    cat > "$RELEASE_DIR/start.sh" << 'EOF'
#!/bin/bash

# Gitea OpenAI Review Bot 启动脚本

# 检查环境变量
if [ ! -f ".env" ]; then
    echo "错误: .env 文件不存在，请从 .env.example 复制并配置"
    exit 1
fi

# 加载环境变量
source .env

# 启动应用
echo "启动 Gitea OpenAI Review Bot..."
./gitea-openai-review-bot
EOF

    chmod +x "$RELEASE_DIR/start.sh"

    # 创建 Windows 启动脚本
    cat > "$RELEASE_DIR/start.bat" << 'EOF'
@echo off

REM Gitea OpenAI Review Bot 启动脚本 (Windows)

REM 检查环境变量文件
if not exist ".env" (
    echo 错误: .env 文件不存在，请从 .env.example 复制并配置
    pause
    exit /b 1
)

REM 启动应用
echo 启动 Gitea OpenAI Review Bot...
gitea-openai-review-bot.exe

pause
EOF

    log_info "发布包创建完成: $RELEASE_DIR"
}

# 显示构建信息
show_build_info() {
    log_info "构建信息:"
    echo "  项目名称: $PROJECT_NAME"
    echo "  版本: $VERSION"
    echo "  构建时间: $(date)"
    echo "  Go 版本: $(go version | awk '{print $3}')"
    echo "  输出目录: $OUTPUT_DIR"
    echo ""
    echo "文件大小:"
    if [ -f "$OUTPUT_DIR/$PROJECT_NAME" ]; then
        ls -lh "$OUTPUT_DIR/$PROJECT_NAME"
    fi
    echo ""
}

# 主函数
main() {
    echo "=== Gitea OpenAI Review Bot 构建脚本 ==="
    echo ""

    # 处理命令行参数
    case "$1" in
        "clean")
            clean_build
            exit 0
            ;;
        "test")
            check_dependencies
            run_tests
            exit 0
            ;;
        "multi")
            check_dependencies
            clean_build
            download_dependencies
            build_multi_platform
            create_release_package
            show_build_info
            exit 0
            ;;
        "help"|"-h")
            echo "用法: $0 [选项]"
            echo ""
            echo "选项:"
            echo "  clean    清理构建文件"
            echo "  test     运行测试"
            echo "  multi    构建多平台版本"
            echo "  help, -h 显示帮助信息"
            echo ""
            echo "默认行为: 构建当前平台"
            exit 0
            ;;
    esac

    # 默认构建流程
    check_dependencies
    clean_build
    download_dependencies
    run_tests
    build_app
    create_release_package
    show_build_info

    log_info "构建完成！"
    echo ""
    echo "快速启动:"
    echo "  cd $OUTPUT_DIR"
    echo "  cp ../.env.example .env"
    echo "  # 编辑 .env 文件"
    echo "  ./$PROJECT_NAME"
}

# 运行主函数
main "$@"