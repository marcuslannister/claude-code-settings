# Claude Code Settings and Commands for Vibe Coding

A curated collection of Claude Code settings, custom commands and sub-agents designed for enhanced development workflows. This setup includes specialized commands and sub-agents for feature development (spec-driven workflow), code analysis, GitHub integration, and knowledge management.

> For OpenAI Codex settings, configurations and custom prompts, please refer [feiskyer/codex-settings](https://github.com/feiskyer/codex-settings).

## Setup

### Manully Setup

```sh
# Backup original claude settings
mv ~/.claude ~/.claude.bak

# Clone the claude-code-settings
git clone https://github.com/feiskyer/claude-code-settings.git ~/.claude

# Install LiteLLM proxy
pip install -U 'litellm[proxy]'

# Start litellm proxy (which would listen on http://0.0.0.0:4000)
litellm -c ~/.claude/guidances/litellm_config.yaml

# For convenience, run litellm proxy in background with tmux
# tmux new-session -d -s copilot 'litellm -c guidances/litellm_config.yaml'
```

Once started, you'll see:

```sh
...
Please visit https://github.com/login/device and enter code XXXX-XXXX to authenticate.
...
```

Open the link, login and authenticate your Github Copilot account.

**Note:**

1. The default settings is leveraging [LiteLLM Proxy Server](https://docs.litellm.ai/docs/simple_proxy) as LLM Gateway to Github Copilot. You can also use [copilot-api](https://github.com/ericc-ch/copilot-api) as the proxy as well (remember change your port to 4141).
2. Make sure the following models are available in your account; if not, replace them with your own model names:

- ANTHROPIC_DEFAULT_SONNET_MODEL: claude-sonnet-4.5
- ANTHROPIC_DEFAULT_OPUS_MODEL: claude-opus-4
- ANTHROPIC_DEFAULT_HAIKU_MODEL: gpt-5-mini

### Using Claude Code Plugin

```sh
/plugin marketplace add feiskyer/claude-code-settings
/plugin install claude-code-settings
```

**Note:**:

* [~/.claude/settings.json](settings.json) is not configured via Claude Code Plugin, you'd need to configure it manually.

## Commands

### Github Spec Kit Workflow

**Github Spec Kit** - Unified interface for Spec-Driven Development.

To use it, run the following command to initialize your project:

```sh
uvx --from git+https://github.com/github/spec-kit.git specify init <project_name>
```

Alternatively, you can also copy [.specify](.specify) to your project root directory.

Available commands:

- `/constitution` - Create or update governing principles and development guidelines.
- `/specify` - Define requirements and user stories for the desired outcome.
- `/clarify` - Resolve underspecified areas (run before `/plan` unless explicitly skipped).
- `/plan` - Generate a technical implementation plan for the chosen stack.
- `/tasks` - Produce actionable task lists for implementation.
- `/analyze` - Check consistency and coverage after `/tasks` and before `/implement`.
- `/implement` - Execute all tasks to build the feature according to the plan.

### Kiro Spec Workflow

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

## Agents

The `agents/` directory contains specialized AI [subagents](https://docs.anthropic.com/en/docs/claude-code/sub-agents) that extend Claude Code's capabilities.

<details>
<summary>Available Agents</summary>

- **pr-reviewer** - Expert code reviewer for GitHub pull requests
- **github-issue-fixer** - GitHub issue resolution specialist
- **instruction-reflector** - Analyzes and improves Claude Code instructions
- **deep-reflector** - Comprehensive session analysis and learning capture
- **insight-documenter** - Technical breakthrough documentation specialist
- **kiro-assistant** - Quick development assistance with Kiro's approach
- **kiro-feature-designer** - Creates comprehensive feature design documents
- **kiro-spec-creator** - Creates complete feature specifications
- **kiro-task-executor** - Executes specific tasks from feature specs
- **kiro-task-planner** - Generates implementation task lists
- **ui-engineer** - UI/UX development specialist
- **command-creator** - Expert at creating new Claude Code custom commands

</details>

## Settings

[Sample Settings](settings/README.md) - Pre-configured settings for various model providers and setups.

<details>
<summary>Available Settings</summary>

### [copilot-settings.json](settings/copilot-settings.json)

Using Claude Code with GitHub Copilot proxy. Points to localhost:4141 for the Anthropic API base URL.

### [litellm-settings.json](settings/litellm-settings.json)

Using Claude Code with LiteLLM gateway. Points to localhost:4000 for the Anthropic API base URL.

### [deepseek-settings.json](settings/deepseek-settings.json)

Using Claude Code with DeepSeek v3.1 (via DeepSeek's official Anthropic-compatible API).

### [qwen-settings.json](settings/qwen-settings.json)

Using Claude Code with Qwen models via Alibaba's DashScope API. Uses the Qwen3-Coder-Plus model through a claude-code-proxy.

### [siliconflow-settings.json](settings/siliconflow-settings.json)

Using Claude Code with SiliconFlow API. Uses the Moonshot AI Kimi-K2-Instruct model.

### [vertex-settings.json](settings/vertex-settings.json)

Using Claude Code with Google Cloud Vertex AI. Uses Claude Opus 4 model with Google Cloud project settings.

</details>

## Limitations

**WebSearch** tool in Claude Code is an [Anthropic specific tool](https://docs.anthropic.com/en/docs/agents-and-tools/tool-use/web-search-tool) and it is not available when you’re not using the official Anthropic API. Hence, if you need web search, you’d need to connect Claude Code with extertnal web search MCP servers, e.g. [Tavily MCP](https://docs.tavily.com/documentation/mcp), [Brave MCP](https://github.com/brave/brave-search-mcp-server), [Firecrawl MCP](https://docs.firecrawl.dev/mcp-server) or [DuckDuckGo Search MCP](https://github.com/nickclyde/duckduckgo-mcp-server).

## Use in VSCode Extension

For Claude Code 2.0+ extension in VSCode, if you’re not using Claude.ai subscription, please put the environment variables manually in your vscode settings.json:

```json
{
  "claude-code.environmentVariables": [
    {
      "name": "ANTHROPIC_BASE_URL",
      "value": "http://localhost:4000"
    },
    {
      "name": "ANTHROPIC_AUTH_TOKEN",
      "value": "sk-dummy"
    },
    {
      "name": "ANTHROPIC_MODEL",
      "value": "opusplan"
    },
    {
      "name": "ANTHROPIC_DEFAULT_SONNET_MODEL",
      "value": "claude-sonnet-4.5"
    },
    {
      "name": "ANTHROPIC_DEFAULT_OPUS_MODEL",
      "value": "claude-opus-4"
    },
    {
      "name": "ANTHROPIC_DEFAULT_HAIKU_MODEL",
      "value": "gpt-5-mini"
    },
    {
      "name": "DISABLE_NON_ESSENTIAL_MODEL_CALLS",
      "value": "1"
    },
    {
      "name": "DISABLE_TELEMETRY",
      "value": "1"
    },
    {
      "name": "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC",
      "value": "1"
    }
  ]
}
```

Note that the contents of [~/.claude/config.json](config.json) is also required to skip claude.ai login.

## Guidances

- [Claude Code with Github Copilot as Model Provider](guidances/github-copilot.md).
- [Claude Code with LLM Gateway (LiteLLM) as Model Provider](guidances/llm-gateway-litellm.md).

## References

- [Claude Code official document](https://docs.anthropic.com/en/docs/claude-code/overview) - must read official document.
- [awesome-claude-code](https://github.com/hesreallyhim/awesome-claude-code) - curated list of slash-commands, CLAUDE.md files, CLI tools, and other resources.
- [wshobson/agents](https://github.com/wshobson/agents) - comprehensive collection of specialized AI subagents for Claude Code.

## LICENSE

This project is released under MIT License - See [LICENSE](LICENSE) for details.
