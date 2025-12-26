# Claude Code with LLM Gateway (LiteLLM) as Model Provider

Guidance for how to connect [LiteLLM](https://docs.litellm.ai/) as an LLM Gateway for Claude Code.

> NOTICE: LiteLLM provides a unified interface to 100+ LLMs, including Claude models through Anthropic, Bedrock, and Vertex AI. This allows you to use Claude Code with any LLM provider supported by LiteLLM while maintaining full compatibility.

## 1) Install Claude Code and Deploy LiteLLM Proxy

```sh
npm install -g @anthropic-ai/claude-code
pip install -U 'litellm[proxy]'
```

## 2) Configure and Start LiteLLM Proxy

Create a LiteLLM config file `litellm_config.yaml` with GitHub Copilot as the examples:

```yaml
general_settings:
  master_key: sk-dummy
litellm_settings:
  drop_params: true
model_list:
- model_name: gpt-5.1-codex
  model_info:
    mode: responses
    supports_vision: true
  litellm_params:
    model: github_copilot/gpt-5.1-codex
    drop_params: true
    extra_headers:
      editor-version: "vscode/1.95.0"
      editor-plugin-version: "copilot-chat/0.26.7"
- model_name: gpt-5.1-codex-max
  model_info:
    mode: responses
    supports_vision: true
  litellm_params:
    model: github_copilot/gpt-5.1-codex-max
    drop_params: true
    extra_headers:
      editor-version: "vscode/1.95.0"
      editor-plugin-version: "copilot-chat/0.26.7"
- model_name: claude-opus-4.5
  litellm_params:
    model: github_copilot/claude-opus-4.5
    drop_params: true
    extra_headers:
      editor-version: "vscode/1.95.0"
      editor-plugin-version: "copilot-chat/0.26.7"
- model_name: "*"
  litellm_params:
    model: "github_copilot/*"
    extra_headers:
      editor-version: "vscode/1.95.0"
      editor-plugin-version: "copilot-chat/0.26.7"
```

Start the LiteLLM proxy:

```sh
litellm -c litellm_config.yaml
```

Once started, you'll see:

```sh
...
Please visit https://github.com/login/device and enter code XXXX-XXXX to authenticate.
...
```

Open the link, login and authenticate your GitHub Copilot account.

## 3) Create Claude Code configure file `~/.claude/settings.json` with the following contents

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "http://localhost:4000",
    "ANTHROPIC_AUTH_TOKEN": "sk-dummy",
    "ANTHROPIC_MODEL": "claude-sonnet-4.5",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "gpt-5-mini",
    "DISABLE_NON_ESSENTIAL_MODEL_CALLS": "1",
    "DISABLE_TELEMETRY": "1",
    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1"
  }
}
```

## 4) Run claude

Open another terminal and then run `claude` at your will. DO read its [best practices](https://www.anthropic.com/engineering/claude-code-best-practices) for fully leveraging its capabilities.

## Alternative configurations

### Using Environment Variables Directly

```sh
export ANTHROPIC_BASE_URL="http://localhost:4000"
export ANTHROPIC_AUTH_TOKEN="sk-dummy"
export ANTHROPIC_MODEL="claude-sonnet-4.5"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="gpt-5-mini"
export DISABLE_TELEMETRY="1"
export DISABLE_NON_ESSENTIAL_MODEL_CALLS="1"
export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC="1"

claude
```
