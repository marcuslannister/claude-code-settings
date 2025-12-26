# Settings

This directory contains sample Claude Code settings configurations for different setups.

All configurations include:

- Custom base URLs or API endpoints for different providers
- Authentication token placeholders
- Model specifications for each provider
- Disabled telemetry and non-essential traffic for development

## Available Settings

### [copilot-settings.json](copilot-settings.json)

Configuration for using Claude Code with GitHub Copilot proxy setup. Points to localhost:4141 for the Anthropic API base URL.

### [litellm-settings.json](litellm-settings.json)

Configuration for using Claude Code with LiteLLM gateway setup. Points to localhost:4000 for the Anthropic API base URL.

### [qwen-settings.json](qwen-settings.json)

Configuration for using Claude Code with Qwen models via Alibaba's DashScope API. Uses the Qwen3-Coder-Plus model through a claude-code-proxy.

### [siliconflow-settings.json](siliconflow-settings.json)

Configuration for using Claude Code with SiliconFlow API. Uses the Moonshot AI Kimi-K2-Instruct model.

### [vertex-settings.json](vertex-settings.json)

Configuration for using Claude Code with Google Cloud Vertex AI. Uses Claude Opus 4 model with Google Cloud project settings.

### [deepseek-settings.json](deepseek-settings.json)

Configuration for using Claude Code with DeepSeek v3.1 (via DeepSeek's official Anthropic-compatible API).

### [azure-settings.json](azure-settings.json)

Configuration for using Claude Code with Azure AI (Anthropic-compatible endpoint). Points to Azure AI services endpoint.

### [azure-foundry-settings.json](azure-foundry-settings.json)

Configuration for using Claude Code with Azure AI Foundry native mode. Uses `CLAUDE_CODE_USE_FOUNDRY` flag with Claude Opus 4.1 + Sonnet 4.5 model.

### [minimax.json](minimax.json)

Configuration for using Claude Code with MiniMax API. Uses the MiniMax-M2 model.

### [openrouter-settings.json](openrouter-settings.json)

Configuration for using Claude Code with OpenRouter API. OpenRouter provides access to many models through a unified API. Note: `ANTHROPIC_API_KEY` must be explicitly blank while `ANTHROPIC_AUTH_TOKEN` contains your OpenRouter API key. By default, Claude Code uses Anthropic model aliases (Sonnet, Opus, Haiku), which OpenRouter automatically maps. You can override with custom models using `ANTHROPIC_DEFAULT_SONNET_MODEL`, `ANTHROPIC_DEFAULT_OPUS_MODEL`, and `ANTHROPIC_DEFAULT_HAIKU_MODEL`.
