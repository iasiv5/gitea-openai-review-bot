package services

import (
	"context"
	"fmt"
	"strings"

	"github.com/sashabaranov/go-openai"
	"gitea-openai-review-bot/internal/config"
)

type OpenAIService struct {
	client *openai.Client
	config *config.OpenAIConfig
}

func NewOpenAIService(cfg config.OpenAIConfig) *OpenAIService {
	client := openai.NewClient(cfg.APIKey)
	return &OpenAIService{
		client: client,
		config: &cfg,
	}
}

type CodeReviewRequest struct {
	FilePath    string
	DiffContent string
	Language    string
	Changes     []string
}

type CodeReviewResponse struct {
	Summary     string              `json:"summary"`
	Issues      []CodeIssue         `json:"issues"`
	Suggestions []CodeSuggestion    `json:"suggestions"`
	Overall     ReviewOverall       `json:"overall"`
}

type CodeIssue struct {
	Line        int    `json:"line"`
	Severity    string `json:"severity"` // "error", "warning", "info"
	Type        string `json:"type"`     // "security", "performance", "style", "logic"
	Message     string `json:"message"`
	Suggestion  string `json:"suggestion,omitempty"`
}

type CodeSuggestion struct {
	Line        int    `json:"line"`
	Type        string `json:"type"`
	Description string `json:"description"`
	Code        string `json:"code,omitempty"`
}

type ReviewOverall struct {
	Score       int    `json:"score"` // 1-10
	Quality     string `json:"quality"`
	Readability string `json:"readability"`
	Complexity  string `json:"complexity"`
}

func (s *OpenAIService) ReviewCode(ctx context.Context, req CodeReviewRequest) (*CodeReviewResponse, error) {
	prompt := s.buildReviewPrompt(req)

	resp, err := s.client.CreateChatCompletion(ctx, openai.ChatCompletionRequest{
		Model: s.config.Model,
		Messages: []openai.ChatCompletionMessage{
			{
				Role: openai.ChatMessageRoleSystem,
				Content: `你是一个专业的代码审查专家。请仔细审查提供的代码变更，并提供详细的反馈。

审查要点：
1. 代码质量和最佳实践
2. 潜在的安全问题
3. 性能优化建议
4. 代码可读性和维护性
5. 逻辑错误和边界情况

请以JSON格式返回结果，包含以下字段：
- summary: 审查总结
- issues: 发现的问题列表（包含行号、严重程度、类型、描述）
- suggestions: 改进建议列表
- overall: 整体评分（1-10分）和质量评估

严重程度：error（严重）、warning（警告）、info（信息）
问题类型：security（安全）、performance（性能）、style（风格）、logic（逻辑）`,
			},
			{
				Role: openai.ChatMessageRoleUser,
				Content: prompt,
			},
		},
		MaxTokens:   s.config.MaxTokens,
		Temperature: s.config.Temperature,
	})

	if err != nil {
		return nil, fmt.Errorf("failed to call OpenAI API: %w", err)
	}

	if len(resp.Choices) == 0 {
		return nil, fmt.Errorf("no response from OpenAI")
	}

	// 解析JSON响应
	return s.parseResponse(resp.Choices[0].Message.Content)
}

func (s *OpenAIService) buildReviewPrompt(req CodeReviewRequest) string {
	var prompt strings.Builder

	prompt.WriteString(fmt.Sprintf("请审查以下代码变更：\n\n"))
	prompt.WriteString(fmt.Sprintf("文件路径: %s\n", req.FilePath))
	prompt.WriteString(fmt.Sprintf("编程语言: %s\n\n", req.Language))

	if len(req.Changes) > 0 {
		prompt.WriteString("主要变更:\n")
		for _, change := range req.Changes {
			prompt.WriteString(fmt.Sprintf("- %s\n", change))
		}
		prompt.WriteString("\n")
	}

	prompt.WriteString("代码差异:\n")
	prompt.WriteString("```diff\n")
	prompt.WriteString(req.DiffContent)
	prompt.WriteString("\n```\n\n")

	prompt.WriteString("请提供详细的代码审查反馈。")

	return prompt.String()
}

func (s *OpenAIService) parseResponse(content string) (*CodeReviewResponse, error) {
	// 这里需要解析JSON响应
	// 为了简化，这里提供一个基本的解析逻辑
	// 实际应用中应该使用更robust的JSON解析

	var response CodeReviewResponse

	// TODO: 实现JSON解析逻辑
	// 这里可以返回一个基本的响应结构
	response = CodeReviewResponse{
		Summary: "代码审查完成",
		Issues: []CodeIssue{
			{
				Line:     10,
				Severity: "warning",
				Type:     "style",
				Message:  "建议使用更清晰的变量名",
			},
		},
		Suggestions: []CodeSuggestion{
			{
				Line:        10,
				Type:        "style",
				Description: "使用更描述性的变量名",
			},
		},
		Overall: ReviewOverall{
			Score:       8,
			Quality:     "良好",
			Readability: "良好",
			Complexity:  "中等",
		},
	}

	return &response, nil
}

func (s *OpenAIService) ExtractCodeChanges(diffContent string) []string {
	// 解析diff内容，提取主要变更
	var changes []string
	lines := strings.Split(diffContent, "\n")

	for _, line := range lines {
		if strings.HasPrefix(line, "+") && !strings.HasPrefix(line, "+++") {
			// 新增的行
			changes = append(changes, strings.TrimPrefix(line, "+"))
		} else if strings.HasPrefix(line, "-") && !strings.HasPrefix(line, "---") {
			// 删除的行
			changes = append(changes, "删除: "+strings.TrimPrefix(line, "-"))
		}
	}

	return changes
}

func (s *OpenAIService) DetectLanguage(filePath string) string {
	// 根据文件扩展名检测编程语言
	ext := strings.ToLower(filePath[strings.LastIndex(filePath, "."):])

	languages := map[string]string{
		".go":   "Go",
		".py":   "Python",
		".js":   "JavaScript",
		".ts":   "TypeScript",
		".java": "Java",
		".cpp":  "C++",
		".c":    "C",
		".rs":   "Rust",
		".php":  "PHP",
		".rb":   "Ruby",
		".cs":   "C#",
	}

	if lang, exists := languages[ext]; exists {
		return lang
	}

	return "Unknown"
}