# Claude Code Settings/Skills for Vibe Coding

A curated collection of Claude Code settings.

> For OpenAI Codex settings, configurations and custom prompts, please refer [marcuslannister/codex-settings](https://github.com/marcuslannister/codex-settings).

## Setup

**Note:**

- [~/.claude/settings.json](settings.json) is not configured via Claude Code Plugin, you'd need to configure it manually.

## Agents

The `agents/` directory contains specialized AI [subagents](https://docs.anthropic.com/en/docs/claude-code/sub-agents) that extend Claude Code's capabilities.

## Settings

[Sample Settings](settings/README.md) - pre-configured `settings.json` examples for various model providers: Vertex AI, Azure AI, Azure AI Foundry, GitHub Copilot, LiteLLM, DeepSeek, Qwen, SiliconFlow, MiniMax and OpenRouter.

## Guidances

- [Claude Code with GitHub Copilot as Model Provider](guidances/github-copilot.md).
- [Claude Code with LLM Gateway (LiteLLM) as Model Provider](guidances/llm-gateway-litellm.md).

## References

- [Claude Code official document](https://docs.anthropic.com/en/docs/claude-code/overview) - must read official document.
- [anthropics/skills](https://github.com/anthropics/skills) - official list of Claude Code skills that teach Claude how to complete specific tasks in a repeatable way
- [anthropics/claude-plugins-official](https://github.com/anthropics/claude-plugins-official) - official list of Claude Code plugins managed by Anthropic
- [hesreallyhim/awesome-claude-code](https://github.com/hesreallyhim/awesome-claude-code) - curated list of slash-commands, CLAUDE.md files, CLI tools, and other resources.
- [wshobson/agents](https://github.com/wshobson/agents) - a comprehensive collection of specialized AI subagents for Claude Code.

## LICENSE

This project is released under MIT License - See [LICENSE](LICENSE) for details.
