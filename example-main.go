package main

import (
    "context"
    "log"
    "net/http"
    "os"
    "os/signal"
    "syscall"
    "time"

    "github.com/gin-gonic/gin"
    "github.com/spf13/viper"
)

func main() {
    // 加载配置
    config := loadConfig()

    // 初始化数据库
    db := initDatabase(config.DatabaseURL)

    // 创建路由
    router := gin.Default()

    // 注册 webhook 处理器
    webhookHandler := NewWebhookHandler(db, config)
    router.POST("/webhook", webhookHandler.HandlePR)

    // 启动服务器
    srv := &http.Server{
        Addr:    ":" + config.Port,
        Handler: router,
    }

    go func() {
        if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
            log.Fatalf("Failed to start server: %v", err)
        }
    }()

    // 优雅关闭
    quit := make(chan os.Signal, 1)
    signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
    <-quit

    log.Println("Shutting down server...")
    ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
    defer cancel()

    if err := srv.Shutdown(ctx); err != nil {
        log.Fatal("Server forced to shutdown:", err)
    }

    log.Println("Server exited")
}