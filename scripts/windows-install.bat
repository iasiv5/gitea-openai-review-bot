@echo off
REM Gitea OpenAI Review Bot Windows 安装脚本

setlocal enabledelayedexpansion

echo === Gitea OpenAI Review Bot Windows 安装脚本 ===
echo.

REM 检查管理员权限
net session >nul 2>&1
if %errorLevel% == 0 (
    echo [INFO] 检测到管理员权限
) else (
    echo [WARN] 建议以管理员身份运行此脚本
)

REM 检查 Go 安装
echo [STEP] 检查系统依赖...
where go >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] Go 未安装，请先安装 Go 1.21 或更高版本
    echo 下载地址: https://golang.org/dl/
    pause
    exit /b 1
)

REM 检查 Git 安装
where git >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] Git 未安装，请先安装 Git
    echo 下载地址: https://git-scm.com/download/win
    pause
    exit /b 1
)

REM 显示版本信息
for /f "tokens=3" %%i in ('go version') do set GO_VERSION=%%i
echo [INFO] Go 版本: %GO_VERSION%

REM 创建安装目录
set INSTALL_DIR=%USERPROFILE%\gitea-openai-review-bot
set BIN_DIR=%USERPROFILE%\bin

echo [STEP] 创建安装目录...
if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"
if not exist "%INSTALL_DIR%\logs" mkdir "%INSTALL_DIR%\logs"
if not exist "%INSTALL_DIR%\data" mkdir "%INSTALL_DIR%\data"
if not exist "%INSTALL_DIR%\configs" mkdir "%INSTALL_DIR%\configs"

REM 构建应用
echo [STEP] 构建应用...
set BUILD_TIME=%date%_%time%
set GIT_COMMIT=unknown
for /f "tokens=*" %%i in ('git rev-parse --short HEAD 2^>nul') do set GIT_COMMIT=%%i

go build -ldflags "-X main.Version=1.0.0 -X main.BuildTime=%BUILD_TIME% -X main.GitCommit=%GIT_COMMIT% -X main.GoVersion=%GO_VERSION%" -o "%INSTALL_DIR%\gitea-openai-review-bot.exe" cmd/main.go

if %errorLevel% neq 0 (
    echo [ERROR] 构建失败
    pause
    exit /b 1
)

REM 安装配置文件
echo [STEP] 安装配置文件...
copy configs\* "%INSTALL_DIR%\configs\" >nul
copy .env.example "%INSTALL_DIR%\" >nul

if not exist "%INSTALL_DIR%\.env" (
    copy .env.example "%INSTALL_DIR%\.env"
    echo [WARN] 请编辑 %INSTALL_DIR%\.env 文件配置你的设置
)

REM 创建启动脚本
echo [STEP] 创建启动脚本...
(
echo @echo off
echo REM Gitea OpenAI Review Bot 启动脚本
echo.
echo cd /d "%INSTALL_DIR%"
echo.
echo REM 检查环境变量文件
echo if not exist ".env" (
echo     echo 错误: .env 文件不存在，请从 .env.example 复制并配置
echo     pause
echo     exit /b 1
echo ^)
echo.
echo REM 创建日志目录
echo if not exist "logs" mkdir logs
echo.
echo REM 启动应用
echo echo 启动 Gitea OpenAI Review Bot...
echo gitea-openai-review-bot.exe
echo.
echo pause
) > "%INSTALL_DIR%\start.bat"

REM 创建命令行快捷方式
echo [STEP] 创建命令行快捷方式...
if not exist "%BIN_DIR%" mkdir "%BIN_DIR%"
(
echo @echo off
echo cd /d "%INSTALL_DIR%"
echo call start.bat %%*
) > "%BIN_DIR%\gitea-review-bot.bat"

REM 添加到 PATH (可选)
echo [STEP] 添加到用户 PATH...
setx PATH "%PATH%;%BIN_DIR%" >nul 2>&1

REM 创建桌面快捷方式
echo [STEP] 创建桌面快捷方式...
set DESKTOP=%USERPROFILE%\Desktop
powershell -Command "& {$WshShell = New-Object -comObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut('%DESKTOP%\Gitea Review Bot.lnk'); $Shortcut.TargetPath = '%INSTALL_DIR%\start.bat'; $Shortcut.WorkingDirectory = '%INSTALL_DIR%'; $Shortcut.Save()}"

echo [INFO] 安装完成！
echo.
echo 安装位置: %INSTALL_DIR%
echo 可执行文件: %INSTALL_DIR%\gitea-openai-review-bot.exe
echo 桌面快捷方式: %DESKTOP%\Gitea Review Bot.lnk
echo.
echo 使用方法:
echo   1. 编辑配置文件: notepad "%INSTALL_DIR%\.env"
echo   2. 双击桌面快捷方式启动
echo   3. 或者运行: "%INSTALL_DIR%\start.bat"
echo.
echo 日志位置: %INSTALL_DIR%\logs\
echo 配置文件: %INSTALL_DIR%\.env
echo.
echo 卸载方法:
echo   1. 删除安装目录: rmdir /s "%INSTALL_DIR%"
echo   2. 删除桌面快捷方式
echo   3. 从 PATH 中移除 %BIN_DIR%
echo.
pause