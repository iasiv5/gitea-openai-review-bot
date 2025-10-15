package config

import (
	"github.com/spf13/viper"
)

type Config struct {
	Server ServerConfig `mapstructure:"server"`
	Gitea  GiteaConfig  `mapstructure:"gitea"`
	OpenAI OpenAIConfig `mapstructure:"openai"`
	Review ReviewConfig `mapstructure:"review"`
}

type ServerConfig struct {
	Port string `mapstructure:"port"`
	Host string `mapstructure:"host"`
}

type GiteaConfig struct {
	URL           string `mapstructure:"url"`
	BotToken      string `mapstructure:"bot_token"`
	WebhookSecret string `mapstructure:"webhook_secret"`
}

type OpenAIConfig struct {
	APIKey      string `mapstructure:"api_key"`
	Model       string `mapstructure:"model"`
	MaxTokens   int    `mapstructure:"max_tokens"`
	Temperature float64 `mapstructure:"temperature"`
}

type ReviewConfig struct {
	EnabledFileTypes []string `mapstructure:"enabled_file_types"`
	MaxFileSize      int      `mapstructure:"max_file_size"`
	MaxDiffSize      int      `mapstructure:"max_diff_size"`
}

func Load() (*Config, error) {
	viper.SetConfigName("config")
	viper.SetConfigType("yaml")
	viper.AddConfigPath("./configs")
	viper.AddConfigPath(".")

	// 设置环境变量前缀
	viper.SetEnvPrefix("REVIEW_BOT")
	viper.AutomaticEnv()

	// 设置默认值
	viper.SetDefault("server.port", "8080")
	viper.SetDefault("server.host", "0.0.0.0")
	viper.SetDefault("openai.model", "gpt-4")
	viper.SetDefault("openai.max_tokens", 2000)
	viper.SetDefault("openai.temperature", 0.3)
	viper.SetDefault("review.enabled_file_types", []string{".go", ".py", ".js", ".ts", ".java", ".cpp", ".c", ".rs"})
	viper.SetDefault("review.max_file_size", 1024*1024) // 1MB
	viper.SetDefault("review.max_diff_size", 100*1024)  // 100KB

	if err := viper.ReadInConfig(); err != nil {
		if _, ok := err.(viper.ConfigFileNotFoundError); ok {
			log.Println("Config file not found, using defaults")
		} else {
			return nil, err
		}
	}

	var config Config
	if err := viper.Unmarshal(&config); err != nil {
		return nil, err
	}

	return &config, nil
}