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

### [azure-settings.json](azure-settings.json)

Configuration for using Claude Code with Azure AI Foundry. Uses Claude Opus 4.1 + Sonnet 4.5 model with opusplan mode.
