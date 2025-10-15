gitea-openai-review-bot/
├── cmd/
│   └── main.go                    # 应用入口
├── internal/
│   ├── config/
│   │   └── config.go              # 配置管理
│   ├── handlers/
│   │   └── webhook.go             # Webhook处理器
│   ├── services/
│   │   ├── openai.go              # OpenAI服务
│   │   ├── gitea.go               # Gitea API客户端
│   │   └── review.go              # 代码审查服务
│   ├── models/
│   │   └── review.go              # 数据模型
│   └── utils/
│       └── diff.go                # Git差异处理
├── pkg/
│   └── api/
│       └── openai.go              # OpenAI API客户端
├── configs/
│   └── config.yaml                # 配置文件
├── docker/
│   ├── Dockerfile                 # Docker镜像
│   └── docker-compose.yml         # 容器编排
├── scripts/
│   ├── deploy.sh                  # 部署脚本
│   └── test.sh                    # 测试脚本
├── README.md
├── go.mod
└── go.sum