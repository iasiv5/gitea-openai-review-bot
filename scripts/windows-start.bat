@echo off
REM Gitea OpenAI Review Bot Windows 启动脚本

setlocal enabledelayedexpansion

set PROJECT_NAME=gitea-openai-review-bot
set SCRIPT_DIR=%~dp0
set PROJECT_DIR=%SCRIPT_DIR%..
set PID_FILE=%PROJECT_DIR%\app.pid
set LOG_FILE=%PROJECT_DIR%\logs\app.log

REM 检查二进制文件
if exist "%PROJECT_DIR%\dist\%PROJECT_NAME%.exe" (
    set BINARY_PATH=%PROJECT_DIR%\dist\%PROJECT_NAME%.exe
) else if exist "%PROJECT_DIR%\%PROJECT_NAME%.exe" (
    set BINARY_PATH=%PROJECT_DIR%\%PROJECT_NAME%.exe
) else (
    echo [ERROR] 找不到可执行文件，请先运行构建脚本
    echo 运行: scripts\build.bat
    pause
    exit /b 1
)

echo [INFO] 使用可执行文件: %BINARY_PATH%

REM 处理命令行参数
if "%1"=="help" goto :show_help
if "%1"=="-h" goto :show_help
if "%1"=="stop" goto :stop_service
if "%1"=="restart" goto :restart_service
if "%1"=="status" goto :show_status
if "%1"=="logs" goto :show_logs
if "%1"=="" set ACTION=start
if "%1"=="start" set ACTION=start

REM 检查配置文件
if not exist "%PROJECT_DIR%\.env" (
    echo [WARN] .env 文件不存在，从模板创建...
    copy "%PROJECT_DIR%\.env.example" "%PROJECT_DIR%\.env" >nul
    echo [WARN] 请编辑 %PROJECT_DIR%\.env 文件配置你的设置
    pause
    exit /b 1
)

REM 加载环境变量
for /f "tokens=1,2 delims==" %%a in (%PROJECT_DIR%\.env) do (
    set %%a=%%b
)

REM 检查必要的环境变量
if not defined GITEA_URL (
    echo [ERROR] 环境变量 GITEA_URL 未设置
    pause
    exit /b 1
)
if not defined GITEA_BOT_TOKEN (
    echo [ERROR] 环境变量 GITEA_BOT_TOKEN 未设置
    pause
    exit /b 1
)
if not defined OPENAI_API_KEY (
    echo [ERROR] 环境变量 OPENAI_API_KEY 未设置
    pause
    exit /b 1
)

echo [INFO] 配置文件检查通过

REM 创建日志目录
if not exist "%PROJECT_DIR%\logs" mkdir "%PROJECT_DIR%\logs"

REM 执行相应的操作
if "%ACTION%"=="start" goto :start_service
goto :show_help

:start_service
echo [STEP] 启动服务...

REM 检查服务是否已运行
if exist "%PID_FILE%" (
    set /p PID=<%PID_FILE%
    tasklist /FI "PID eq !PID!" 2>nul | find "!PID!" >nul
    if !errorLevel! equ 0 (
        echo [WARN] 服务已在运行 ^(PID: !PID!^)
        goto :end
    ) else (
        echo [WARN] PID 文件存在但进程不存在，清理 PID 文件
        del "%PID_FILE%" >nul 2>&1
    )
)

REM 启动应用
cd /d "%PROJECT_DIR%"
echo [INFO] 启动 %PROJECT_NAME%...

REM 使用 start /B 启动后台进程
start /B "" "%BINARY_PATH%" > "%LOG_FILE%" 2>&1

REM 获取新进程的 PID (Windows 方法)
timeout /t 2 >nul
for /f "tokens=2" %%i in ('tasklist /FI "IMAGENAME eq %PROJECT_NAME%.exe" /FO csv ^| find "%PROJECT_NAME%.exe"') do (
    set PID=%%i
)

REM 去掉引号
set PID=!PID:"=!

REM 保存 PID
echo !PID! > "%PID_FILE%"

REM 检查是否启动成功
tasklist /FI "PID eq !PID!" 2>nul | find "!PID!" >nul
if !errorLevel! equ 0 (
    echo [INFO] 服务启动成功 ^(PID: !PID!^)
    echo [INFO] 日志文件: %LOG_FILE%

    REM 等待服务就绪
    echo [INFO] 等待服务就绪...
    for /l %%i in (1,1,30) do (
        ping -n 1 localhost >nul 2>&1
        curl -s http://localhost:8080/health >nul 2>&1
        if !errorLevel! equ 0 (
            echo [INFO] 服务已就绪
            goto :end
        )
    )
    echo [WARN] 服务启动超时，请检查日志
) else (
    echo [ERROR] 服务启动失败，请检查日志: %LOG_FILE%
    del "%PID_FILE%" >nul 2>&1
)
goto :end

:stop_service
echo [STEP] 停止服务...

if not exist "%PID_FILE%" (
    echo [WARN] 服务未运行
    goto :end
)

set /p PID=<%PID_FILE%
echo [INFO] 停止服务 ^(PID: !PID!^)...

REM 尝试正常停止
taskkill /PID !PID! /T >nul 2>&1

REM 等待进程结束
for /l %%i in (1,1,10) do (
    tasklist /FI "PID eq !PID!" 2>nul | find "!PID!" >nul
    if !errorLevel! neq 0 (
        echo [INFO] 服务已停止
        del "%PID_FILE%" >nul 2>&1
        goto :end
    )
    timeout /t 1 >nul
)

REM 强制停止
echo [WARN] 强制停止服务...
taskkill /PID !PID! /F >nul 2>&1
del "%PID_FILE%" >nul 2>&1
echo [INFO] 服务已强制停止
goto :end

:restart_service
echo [STEP] 重启服务...
call :stop_service
timeout /t 2 >nul
call :start_service
goto :end

:show_status
echo [STEP] 服务状态:

if exist "%PID_FILE%" (
    set /p PID=<%PID_FILE%
    tasklist /FI "PID eq !PID!" 2>nul | find "!PID!" >nul
    if !errorLevel! equ 0 (
        echo 状态: 运行中
        echo PID: !PID!

        REM 获取进程信息
        for /f "tokens=2,5" %%a in ('tasklist /FI "PID eq !PID!" /FO csv ^| find "!PID!"') do (
            echo 内存使用: %%b
        )

        REM 健康检查
        curl -s http://localhost:8080/health >nul 2>&1
        if !errorLevel! equ 0 (
            echo 健康检查: 通过
        ) else (
            echo 健康检查: 失败
        )
    ) else (
        echo 状态: 未运行
    )
) else (
    echo 状态: 未运行
)
goto :end

:show_logs
if exist "%LOG_FILE%" (
    echo [INFO] 显示日志文件: %LOG_FILE%
    type "%LOG_FILE%"
    pause
) else (
    echo [ERROR] 日志文件不存在: %LOG_FILE%
)
goto :end

:show_help
echo 用法: %0 [命令]
echo.
echo 命令:
echo   start    启动服务 ^(默认^)
echo   stop     停止服务
echo   restart  重启服务
echo   status   查看状态
echo   logs     查看日志
echo   help, -h 显示帮助信息
echo.
echo 默认行为: start
pause

:end
endlocal