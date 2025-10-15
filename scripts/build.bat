@echo off
REM Gitea OpenAI Review Bot Windows 构建脚本

setlocal enabledelayedexpansion

echo === Gitea OpenAI Review Bot Windows 构建脚本 ===
echo.

REM 项目配置
set PROJECT_NAME=gitea-openai-review-bot
set VERSION=1.0.0
set BUILD_DIR=build
set OUTPUT_DIR=dist

REM 处理命令行参数
if "%1"=="clean" goto :clean_build
if "%1"=="test" goto :run_tests
if "%1"=="help" goto :show_help
if "%1"=="-h" goto :show_help

REM 默认构建流程
goto :main_build

:clean_build
echo [INFO] 清理旧的构建文件...
if exist "%BUILD_DIR%" rmdir /s /q "%BUILD_DIR%"
if exist "%OUTPUT_DIR%" rmdir /s /q "%OUTPUT_DIR%"
if exist "%PROJECT_NAME%.exe" del "%PROJECT_NAME%.exe"
echo [INFO] 清理完成
goto :end

:run_tests
echo [STEP] 检查构建依赖...
where go >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] Go 未安装，请先安装 Go 1.21 或更高版本
    exit /b 1
)

echo [INFO] Go 版本检查通过
echo [STEP] 运行测试...
go test ./...
if %errorLevel% neq 0 (
    echo [ERROR] 测试失败
    exit /b 1
)
echo [INFO] 测试通过
goto :end

:main_build
echo [STEP] 检查构建依赖...
where go >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] Go 未安装，请先安装 Go 1.21 或更高版本
    exit /b 1
)

REM 检查模块文件
if not exist "go.mod" (
    echo [ERROR] go.mod 文件不存在，请在项目根目录运行此脚本
    exit /b 1
)

for /f "tokens=3" %%i in ('go version') do set GO_VERSION=%%i
echo [INFO] Go 版本: %GO_VERSION%

REM 下载依赖
echo [STEP] 下载 Go 模块依赖...
go mod download
if %errorLevel% neq 0 (
    echo [ERROR] 依赖下载失败
    exit /b 1
)

go mod verify
if %errorLevel% neq 0 (
    echo [ERROR] 依赖验证失败
    exit /b 1
)

echo [INFO] 依赖下载完成

REM 构建应用
echo [STEP] 构建应用...

REM 设置构建信息
set BUILD_TIME=%date%_%time%
set GIT_COMMIT=unknown
for /f "tokens=*" %%i in ('git rev-parse --short HEAD 2^>nul') do set GIT_COMMIT=%%i

REM 构建参数
set LDFLAGS=-X main.Version=%VERSION% -X main.BuildTime=%BUILD_TIME% -X main.GitCommit=%GIT_COMMIT% -X main.GoVersion=%GO_VERSION%

REM 创建输出目录
if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"

REM 构建当前平台
echo [INFO] 构建当前平台...
go build -ldflags "%LDFLAGS%" -o "%OUTPUT_DIR%\%PROJECT_NAME%.exe" cmd/main.go

if %errorLevel% neq 0 (
    echo [ERROR] 构建失败
    exit /b 1
)

echo [INFO] 构建完成: %OUTPUT_DIR%\%PROJECT_NAME%.exe

REM 创建发布包
echo [STEP] 创建发布包...
set RELEASE_DIR=%OUTPUT_DIR%\release
if not exist "%RELEASE_DIR%" mkdir "%RELEASE_DIR%"

REM 复制必要的文件
xcopy configs "%RELEASE_DIR%\configs\" /E /I /Q >nul
xcopy scripts "%RELEASE_DIR%\scripts\" /E /I /Q >nul
copy README.md "%RELEASE_DIR%\" >nul
copy .env.example "%RELEASE_DIR%\" >nul

REM 创建启动脚本
(
echo @echo off
echo REM Gitea OpenAI Review Bot 启动脚本
echo.
echo REM 检查环境变量
echo if not exist ".env" (
echo     echo 错误: .env 文件不存在，请从 .env.example 复制并配置
echo     pause
echo     exit /b 1
echo ^)
echo.
echo REM 启动应用
echo echo 启动 Gitea OpenAI Review Bot...
echo %PROJECT_NAME%.exe
echo.
echo pause
) > "%RELEASE_DIR%\start.bat"

echo [INFO] 发布包创建完成: %RELEASE_DIR%

REM 显示构建信息
echo.
echo [INFO] 构建信息:
echo   项目名称: %PROJECT_NAME%
echo   版本: %VERSION%
echo   构建时间: %date% %time%
echo   Go 版本: %GO_VERSION%
echo   输出目录: %OUTPUT_DIR%
echo.

REM 显示文件大小
if exist "%OUTPUT_DIR%\%PROJECT_NAME%.exe" (
    for %%A in ("%OUTPUT_DIR%\%PROJECT_NAME%.exe") do (
        echo   文件大小: %%~zA bytes
    )
)

echo.
echo [INFO] 构建完成！
echo.
echo 快速启动:
echo   cd %OUTPUT_DIR%
echo   copy ..\.env.example .env
echo   REM 编辑 .env 文件
echo   %PROJECT_NAME%.exe
echo.

goto :end

:show_help
echo 用法: %0 [选项]
echo.
echo 选项:
echo   clean    清理构建文件
echo   test     运行测试
echo   help, -h 显示帮助信息
echo.
echo 默认行为: 构建当前平台
echo.

:end
pause