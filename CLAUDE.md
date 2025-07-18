# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Environment Setup

This repository contains Claude Code settings, configurations and guidances. The default setup uses GitHub Copilot as the model provider through a proxy API.

### Required Dependencies

- `copilot-api`: Install globally with `npm install -g copilot-api`
- Run `copilot-api start` to authorize GitHub Copilot account
- Use tmux for session management: `tmux new-session -d -s copilot 'copilot-api start'`

### Configuration

- `settings.json`: Contains environment variables for API configuration
- Uses `localhost:4141` as the API base URL
- Configured to use `claude-sonnet-4` as the primary model
- Telemetry and non-essential traffic are disabled

## Custom Commands

Custom commands for Claude Code are organized in the `commands/` directory by category:

### Command File Structure

All command files must include YAML frontmatter with required metadata:

```yaml
---
description: Brief description of the command
argument-hint: [expected arguments format]
allowed-tools: List of tools the command can use
---
```

**Required fields:**

- `description`: Clear, concise description of command purpose
- `argument-hint`: Format showing expected arguments (e.g., `[problem or question]`)
- `allowed-tools`: Comma-separated list of tools (e.g., `Read, Edit, Write, Bash(*)`)

### Command Documentation

- Command documentation belongs in `README.md` under the Commands section
- Use collapsible `<details>` sections with clear summaries
- Include usage examples and key features
- Never document commands within the command files themselves

### Directory Structure

```sh
commands/
├── cc/          # Claude Code commands
│   └── create-command.md
└── gh/          # GitHub commands
    └── review-pr.md
```

### Usage

Run commands using the slash syntax:

```sh
/[category:][command] [ARGUMENTS]
```

**Examples:**

- `/cc:create-command mycommand` - Create a new command
- `/gh:review-pr 123` - Review pull request #123

All available commands should be documented at README.md in Commands section.

### Prompt Engineering Principles

When creating or modifying command prompts:

- **Structure prompts systematically**: Use clear phases or sections (e.g., Analysis Phase, Execution Phase)
- **Define specific outputs**: Include explicit output formats and structures
- **Provide methodical approaches**: Break complex tasks into numbered steps or bullet points
- **Include meta-cognitive elements**: Add bias awareness, assumption checking, and uncertainty assessment
- **Balance thoroughness with conciseness**: Aim for comprehensive analysis while maintaining clarity
- **Use progressive complexity**: Start with simple concepts and build to more complex ones

### Behavioral Guidelines

- **Concise communication**: Provide direct answers without unnecessary preamble or elaboration
- **Follow existing patterns**: Always check similar commands for consistent structure and approach
- **Prefer editing over creating**: Always edit existing files rather than creating new ones unless absolutely necessary
- **Use TodoWrite for complex tasks**: Track multi-step processes and ensure completion of all requirements

## Guidances

Claude Code guidances should be put under `guidance` directory and linked at README.md.
