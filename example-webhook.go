package main

import (
    "encoding/json"
    "fmt"
    "log"
    "net/http"

    "github.com/gin-gonic/gin"
    "code.gitea.io/sdk/gitea"
)

type WebhookHandler struct {
    db     *Database
    config *Config
}

func (h *WebhookHandler) HandlePR(c *gin.Context) {
    var event gitea.PullRequestEvent
    if err := c.ShouldBindJSON(&event); err != nil {
        c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
        return
    }

    // 只处理打开的 PR
    if event.Action != "opened" && event.Action != "synchronize" {
        c.JSON(http.StatusOK, gin.H{"message": "Ignoring non-PR events"})
        return
    }

    // 异步处理 PR Review
    go h.processPRReview(event)

    c.JSON(http.StatusOK, gin.H{"message": "PR review started"})
}

func (h *WebhookHandler) processPRReview(event gitea.PullRequestEvent) {
    pr := event.PullRequest
    repo := event.Repository

    log.Printf("Processing PR review for %s/%s#%d",
        repo.Owner.UserName, repo.Name, pr.Index)

    // 1. 获取 PR 文件变更
    files, err := h.getPRFiles(repo, pr)
    if err != nil {
        log.Printf("Failed to get PR files: %v", err)
        return
    }

    // 2. 执行代码分析
    reviews, err := h.analyzeCode(files)
    if err != nil {
        log.Printf("Failed to analyze code: %v", err)
        return
    }

    // 3. 创建 Review 评论
    if err := h.createReviewComments(repo, pr, reviews); err != nil {
        log.Printf("Failed to create review comments: %v", err)
        return
    }

    log.Printf("PR review completed for %s/%s#%d",
        repo.Owner.UserName, repo.Name, pr.Index)
}

func (h *WebhookHandler) getPRFiles(repo *gitea.Repository, pr *gitea.PullRequest) ([]*gitea.PullRequestFile, error) {
    client := gitea.NewClient(h.config.GiteaURL, h.config.BotToken)
    files, err := client.ListPullRequestFiles(repo.Owner.UserName, repo.Name, pr.Index, gitea.ListPullRequestFilesOptions{})
    return files, err
}

func (h *WebhookHandler) analyzeCode(files []*gitea.PullRequestFile) ([]ReviewComment, error) {
    var comments []ReviewComment

    for _, file := range files {
        // 静态分析
        staticComments := h.runStaticAnalysis(file)
        comments = append(comments, staticComments...)

        // 安全检查
        securityComments := h.runSecurityCheck(file)
        comments = append(comments, securityComments...)

        // AI 辅助分析 (可选)
        if h.config.AIEnabled {
            aiComments := h.runAIAnalysis(file)
            comments = append(comments, aiComments...)
        }
    }

    return comments, nil
}

func (h *WebhookHandler) createReviewComments(repo *gitea.Repository, pr *gitea.PullRequest, comments []ReviewComment) error {
    client := gitea.NewClient(h.config.GiteaURL, h.config.BotToken)

    for _, comment := range comments {
        review := gitea.PullReviewRequest{
            Body: comment.Message,
            Comments: []gitea.PullReviewComment{
                {
                    Path:      comment.FilePath,
                    Body:      comment.Message,
                    OldLineNum: comment.LineNumber,
                },
            },
            Event: gitea.ReviewEventTypeRequestChanges,
        }

        _, err := client.CreatePullReview(repo.Owner.UserName, repo.Name, pr.Index, review)
        if err != nil {
            return fmt.Errorf("failed to create review comment: %w", err)
        }
    }

    return nil
}