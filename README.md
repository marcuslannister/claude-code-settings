# Claude Code Settings, Commands and Guidances

Claude Code settings, commands and guidances for daily work.

## How to use

```sh
# Backup original claude settings
mv ~/.claude ~/.claude.bak

# Clone the claude-code-settings
git clone https://github.com/feiskyer/claude-code-settings.git ~/.claude
```

## NOTICES

The default config uses Github Copilot as Claude Code model provider and require the Copilot API proxy [copilot-api](https://github.com/ericc-ch/copilot-api) running. You can install the copilot-api by running:

```sh
npm install -g copilot-api
```

Then run `copilot-api start` and follow the outputs to authorize your github copilot account.

After that, start a new terminal and then you can use claude at any projects.

For convenience, you can use tmux to manage terminal sessions, e.g.

```sh
# Run copilot-api in background
tmux new-session -d -s copilot 'copilot-api start'
```

## Commands

### General Commands

<details>
<summary> /eureka - Document technical breakthroughs and transform insights into reusable knowledge assets </summary>

### `/eureka` Command

Located in `commands/eureka.md`, this command captures technical breakthroughs and transforms them into structured documentation:

- Immediately documents breakthrough insights while details are fresh
- Creates structured markdown with problem, solution, and implementation details
- Includes working code examples with annotations
- Quantifies improvements and performance gains
- Extracts reusable patterns for future reference
- Integrates with project documentation (README, CHANGELOG)

**Usage:** `/eureka <breakthrough description>`

**Examples:**

- `/eureka "Solved the race condition in user sync"`
- `/eureka "Optimized database queries from 3s to 50ms using connection pooling"`

</details>

<details>
<summary> /reflection - Analyze and improve Claude Code instructions </summary>

### `/reflection` Command

Located in `commands/reflection.md`, this command provides systematic analysis and improvement of Claude Code instructions:

- Reviews chat history to identify performance issues
- Analyzes current CLAUDE.md instructions for inconsistencies
- Documents findings using TodoWrite for structured tracking
- Interactive approval process for each suggested improvement
- Implements approved changes directly to CLAUDE.md
- Includes best practices for testing and version control

**Usage:** `/reflection`

</details>

<details>
<summary> /reflection-harder - Comprehensive session analysis and learning capture </summary>

### `/reflection-harder` Command

Located in `commands/reflection-harder.md`, this command provides deep analysis of development sessions to build cumulative knowledge:

- Comprehensive review of entire conversation history
- Captures problems solved, patterns discovered, and user preferences
- Documents system relationships and architecture insights
- Identifies knowledge gaps and improvement opportunities
- Structured output covering session overview, learnings, and action items
- Builds project memory for more effective future sessions

**Usage:** `/reflection-harder`

</details>

<details>
<summary> /think-harder - Enhanced analytical thinking for complex problems </summary>

### `/think-harder` Command

Located in `commands/think-harder.md`, this command activates enhanced analytical thinking for complex problems requiring deep, multi-faceted analysis.

**Usage:** `/think-harder <problem or question>`

</details>

<details>
<summary> /think-ultra - Ultra-comprehensive analytical thinking for the most complex problems </summary>

### `/think-ultra` Command

Located in `commands/think-ultra.md`, this command activates maximum cognitive processing for ultra-comprehensive analysis of the most complex problems.

**Usage:** `/think-ultra <complex problem or question>`

</details>

### Github Commands

<details>
<summary> /gh:review-pr - Github PR Reviewer </summary>

### `/gh:review-pr` Command

Located in `commands/gh/review-pr.md`, this command provides comprehensive PR review functionality:

- Lists open PRs when no number is provided
- Analyzes PR details, diffs, and code changes
- Provides structured code review focusing on:
  - Code correctness and style
  - Performance implications
  - Security considerations
  - Test coverage
- Posts review comments directly to GitHub using `gh` CLI

**Usage:** `/gh:review-pr [PR_NUMBER]`

</details>

<details>
<summary> /gh:fix-issue - Fix GitHub Issue </summary>

### `/gh:fix-issue` Command

Located in `commands/gh/fix-issue.md`, this command provides comprehensive GitHub issue resolution workflow:

- Analyzes issue details using `gh issue view`
- Creates structured plan with prior art research
- Documents approach in scratchpads with issue links
- Creates dedicated branch for the fix
- Implements solution in manageable steps with commits
- Includes testing with puppeteer for UI changes
- Ensures full test suite passes
- Opens pull request for review

**Usage:** `/gh:fix-issue <issue-number>`

</details>

### Claude Code Commands

<details>
<summary> /cc:create-command - Create Claude Code Custom Command </summary>

### `/cc:create-command` Command

Located in `commands/cc/create-command.md`, this command creates new Claude Code custom commands:

- Creates command files with proper YAML frontmatter structure
- Includes comprehensive documentation templates
- Follows best practices for command development
- Validates command syntax and functionality
- Supports both project-level and user-level commands

**Usage:** `/cc:create-command <command-name> [description]`

</details>

## Guidances

- [Claude Code with Github Copilot as Model Provider](guidances/github-copilot.md)

## LICENSE

This project is released under MIT License - See [LICENSE](LICENSE) for details.
