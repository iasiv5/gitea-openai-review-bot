package handlers

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"code.gitea.io/sdk/gitea"

	"gitea-openai-review-bot/internal/config"
	"gitea-openai-review-bot/internal/services"
)

type WebhookHandler struct {
	reviewService *services.ReviewService
	config        *config.Config
}

func NewWebhookHandler(reviewService *services.ReviewService, config *config.Config) *WebhookHandler {
	return &WebhookHandler{
		reviewService: reviewService,
		config:        config,
	}
}

func (h *WebhookHandler) HandlePullRequest(c *gin.Context) {
	// 验证 webhook secret
	if err := h.verifyWebhookSecret(c); err != nil {
		log.Printf("Webhook signature verification failed: %v", err)
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid signature"})
		return
	}

	// 读取请求体
	body, err := io.ReadAll(c.Request.Body)
	if err != nil {
		log.Printf("Failed to read request body: %v", err)
		c.JSON(http.StatusBadRequest, gin.H{"error": "Failed to read request body"})
		return
	}

	// 解析 Gitea webhook 事件
	var event gitea.PullRequestEvent
	if err := json.Unmarshal(body, &event); err != nil {
		log.Printf("Failed to parse webhook event: %v", err)
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid webhook event"})
		return
	}

	// 只处理 PR 打开和更新事件
	if event.Action != "opened" && event.Action != "synchronize" {
		log.Printf("Ignoring action: %s", event.Action)
		c.JSON(http.StatusOK, gin.H{"message": "Event ignored"})
		return
	}

	// 异步处理 PR 审查
	go h.processPullRequest(event)

	c.JSON(http.StatusOK, gin.H{"message": "Pull request review started"})
}

func (h *WebhookHandler) verifyWebhookSecret(c *gin.Context) error {
	signature := c.GetHeader("X-Gitea-Signature")
	if signature == "" {
		return fmt.Errorf("missing signature header")
	}

	body, err := io.ReadAll(c.Request.Body)
	if err != nil {
		return fmt.Errorf("failed to read request body")
	}

	// 重新设置请求体供后续使用
	c.Request.Body = io.NopCloser(strings.NewReader(string(body)))

	expectedSignature := h.generateSignature(body)
	if !hmac.Equal([]byte(signature), []byte(expectedSignature)) {
		return fmt.Errorf("invalid signature")
	}

	return nil
}

func (h *WebhookHandler) generateSignature(body []byte) string {
	h := hmac.New(sha256.New, []byte(h.config.Gitea.WebhookSecret))
	h.Write(body)
	return "sha256=" + hex.EncodeToString(h.Sum(nil))
}

func (h *WebhookHandler) processPullRequest(event gitea.PullRequestEvent) {
	pr := event.PullRequest
	repo := event.Repository

	log.Printf("Processing PR review for %s/%s#%d",
		repo.Owner.UserName, repo.Name, pr.Index)

	// 检查文件类型是否在支持列表中
	if !h.shouldReviewPR(pr) {
		log.Printf("PR contains unsupported file types, skipping review")
		return
	}

	// 执行代码审查
	reviewResult, err := h.reviewService.ReviewPullRequest(repo, pr)
	if err != nil {
		log.Printf("Failed to review PR: %v", err)
		return
	}

	// 创建审查评论
	if err := h.createReviewComments(repo, pr, reviewResult); err != nil {
		log.Printf("Failed to create review comments: %v", err)
		return
	}

	log.Printf("PR review completed for %s/%s#%d",
		repo.Owner.UserName, repo.Name, pr.Index)
}

func (h *WebhookHandler) shouldReviewPR(pr *gitea.PullRequest) bool {
	// 这里可以添加更多的过滤逻辑
	// 例如：检查 PR 作者、文件类型、文件大小等

	// 检查是否有支持的文件类型
	// 这个逻辑需要在获取 PR 文件列表后实现
	return true
}

func (h *WebhookHandler) createReviewComments(repo *gitea.Repository, pr *gitea.PullRequest, result *services.ReviewResult) error {
	// 使用 Gitea API 创建审查评论
	client := gitea.NewClient(h.config.Gitea.URL, h.config.Gitea.BotToken)

	// 创建总览评论
	if result.Summary != "" {
		issueComment := gitea.CreateIssueCommentOption{
			Body: fmt.Sprintf("## 🤖 AI 代码审查报告\n\n%s", result.Summary),
		}

		_, err := client.CreateIssueComment(repo.Owner.UserName, repo.Name, pr.Index, issueComment)
		if err != nil {
			return fmt.Errorf("failed to create issue comment: %w", err)
		}
	}

	// 创建具体的行级评论
	for _, comment := range result.Comments {
		reviewComment := gitea.PullReviewComment{
			Path:      comment.Path,
			Body:      comment.Body,
			OldLineNum: comment.Line,
		}

		review := gitea.PullReviewRequest{
			Body:     comment.Title,
			Comments: []gitea.PullReviewComment{reviewComment},
			Event:    h.getReviewEventType(comment.Severity),
		}

		_, err := client.CreatePullReview(repo.Owner.UserName, repo.Name, pr.Index, review)
		if err != nil {
			log.Printf("Failed to create review comment: %v", err)
			continue
		}
	}

	return nil
}

func (h *WebhookHandler) getReviewEventType(severity string) gitea.ReviewEventType {
	switch severity {
	case "error":
		return gitea.ReviewEventTypeRequestChanges
	case "warning":
		return gitea.ReviewEventTypeComment
	case "info":
		return gitea.ReviewEventTypeComment
	default:
		return gitea.ReviewEventTypeComment
	}
}