# Claude Code Settings and Commands for Vibe Coding

A curated collection of Claude Code configurations and custom commands designed for enhanced development workflows. This setup includes specialized commands for feature development (Kiro workflow), code analysis, GitHub integration, and knowledge management.

## Setup

```sh
# Backup original claude settings
mv ~/.claude ~/.claude.bak

# Clone the claude-code-settings
git clone https://github.com/feiskyer/claude-code-settings.git ~/.claude

# Install the GitHub Copilot API proxy
npm install -g copilot-api

# Authorize your GitHub Copilot account
copilot-api auth

# For convenience, run copilot-api in background with tmux
tmux new-session -d -s copilot 'copilot-api start'
```

> **Note:** This configuration uses GitHub Copilot as the Claude Code model provider through the [copilot-api](https://github.com/ericc-ch/copilot-api) proxy.

## Commands

### Development Workflow

**Kiro Workflow** - Complete feature development from spec to execution. The Kiro commands provide a structured workflow for feature development:

1. `/kiro:spec [feature]` - Create requirements and acceptance criteria
2. `/kiro:design [feature]` - Develop architecture and component design
3. `/kiro:task [feature]` - Generate implementation task lists
4. `/kiro:execute [task]` - Execute specific implementation tasks
5. `/kiro:vibe [question]` - Quick development assistance

### Analysis & Reflection

- `/think-harder [problem]` - Enhanced analytical thinking
- `/think-ultra [complex problem]` - Ultra-comprehensive analysis
- `/reflection` - Analyze and improve Claude Code instructions
- `/reflection-harder` - Comprehensive session analysis and learning
- `/eureka [breakthrough]` - Document technical breakthroughs

### GitHub Integration

- `/gh:review-pr [PR_NUMBER]` - Comprehensive PR review and comments
- `/gh:fix-issue [issue-number]` - Complete issue resolution workflow

### Documentation & Knowledge

- `/cc:create-command [name] [description]` - Create new Claude Code commands

## Settings

[Sample Settings](settings/README.md) - Pre-configured settings for various model providers and setups.

<details>
<summary>Available Settings</summary>

#### [copilot-settings.json](settings/copilot-settings.json)

Using Claude Code with GitHub Copilot proxy. Points to localhost:4141 for the Anthropic API base URL.

#### [litellm-settings.json](settings/litellm-settings.json)

Using Claude Code with LiteLLM gateway. Points to localhost:4000 for the Anthropic API base URL.

#### [qwen-settings.json](settings/qwen-settings.json)

Using Claude Code with Qwen models via Alibaba's DashScope API. Uses the Qwen3-Coder-Plus model through a claude-code-proxy.

#### [siliconflow-settings.json](settings/siliconflow-settings.json)

Using Claude Code with SiliconFlow API. Uses the Moonshot AI Kimi-K2-Instruct model.

#### [vertex-settings.json](settings/vertex-settings.json)

Using Claude Code with Google Cloud Vertex AI. Uses Claude Opus 4 model with Google Cloud project settings.

</details>

## Guidances

- [Claude Code with Github Copilot as Model Provider](guidances/github-copilot.md).
- [Claude Code with LLM Gateway (LiteLLM) as Model Provider](guidances/llm-gateway-litellm.md).

## References

- [Claude Code official document](https://docs.anthropic.com/en/docs/claude-code/overview) - must read official document.
- [awesome-claude-code](https://github.com/hesreallyhim/awesome-claude-code) - curated list of slash-commands, CLAUDE.md files, CLI tools, and other resources.
- [wshobson/agents](https://github.com/wshobson/agents) - comprehensive collection of specialized AI subagents for Claude Code.

## LICENSE

This project is released under MIT License - See [LICENSE](LICENSE) for details.
