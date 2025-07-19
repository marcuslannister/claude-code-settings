# Claude Code Settings, Commands and Guidances

Claude Code settings and commands for vibe coding.

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
<summary> <b>/eureka</b> - Document technical breakthroughs and transform insights into reusable knowledge assets </summary>

### `/eureka` Command

Located in `commands/eureka.md`, this command captures technical breakthroughs and transforms them into structured documentation:

- Immediately documents breakthrough insights while details are fresh
- Creates structured markdown with problem, solution, and implementation details
- Includes working code examples with annotations
- Quantifies improvements and performance gains
- Extracts reusable patterns for future reference
- Integrates with project documentation (README, CHANGELOG)

**Usage:** `/eureka [breakthrough description]`

**Examples:**

- `/eureka "Solved the race condition in user sync"`
- `/eureka "Optimized database queries from 3s to 50ms using connection pooling"`

</details>

<details>
<summary> <b>/reflection</b> - Analyze and improve Claude Code instructions </summary>

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
<summary> <b>/reflection-harder</b> - Comprehensive session analysis and learning capture </summary>

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
<summary> <b>/think-harder</b> - Enhanced analytical thinking for complex problems </summary>

### `/think-harder` Command

Located in `commands/think-harder.md`, this command activates enhanced analytical thinking for complex problems requiring deep, multi-faceted analysis.

**Usage:** `/think-harder [problem or question]`

</details>

<details>
<summary> <b>/think-ultra</b> - Ultra-comprehensive analytical thinking for the most complex problems </summary>

### `/think-ultra` Command

Located in `commands/think-ultra.md`, this command activates maximum cognitive processing for ultra-comprehensive analysis of the most complex problems.

**Usage:** `/think-ultra [complex problem or question]`

</details>

### Github Commands

<details>
<summary> <b>/gh:review-pr</b> - Github PR Reviewer </summary>

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
<summary> <b>/gh:fix-issue</b> - Fix GitHub Issue </summary>

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

**Usage:** `/gh:fix-issue [issue-number]`

</details>

### Kiro Commands

<details>
<summary> <b>/kiro:spec</b> - Create complete feature specifications from requirements to implementation plan </summary>

### `/kiro:spec` Command

Located in `commands/kiro/spec.md`, this command guides you through the complete spec-driven development workflow:

- Creates comprehensive requirements documents with user stories and acceptance criteria
- Develops detailed design documents with architecture and component specifications
- Generates actionable implementation task lists for coding agents
- Follows iterative approval process for each phase
- Conducts research and incorporates findings into design
- Ensures all requirements are covered by implementation tasks

**Usage:** `/kiro:spec [feature name or rough idea]`

</details>

<details>
<summary> <b>/kiro:design</b> - Create comprehensive feature design documents with research and architecture </summary>

### `/kiro:design` Command

Located in `commands/kiro/design.md`, this command creates detailed feature design documents:

- Conducts necessary research based on feature requirements
- Creates comprehensive design documents with architecture, components, and interfaces
- Includes data models, error handling, and testing strategies
- Incorporates research findings directly into design process
- Requires explicit user approval before proceeding

**Usage:** `/kiro:design [feature name or rough idea]`

</details>

<details>
<summary> <b>/kiro:task</b> - Generate implementation task lists from approved feature designs </summary>

### `/kiro:task` Command

Located in `commands/kiro/task.md`, this command generates actionable implementation plans:

- Converts feature designs into discrete coding tasks
- Prioritizes test-driven development and incremental progress
- Creates numbered checkbox lists with clear objectives
- References specific requirements for each task
- Focuses only on code implementation activities
- Ensures tasks are actionable by coding agents

**Usage:** `/kiro:task [feature name]`

</details>

<details>
<summary> <b>/kiro:execute</b> - Execute specific tasks from Kiro specs with focused implementation </summary>

### `/kiro:execute` Command

Located in `commands/kiro/execute.md`, this command executes specific implementation tasks:

- Reads spec requirements, design, and task documents before execution
- Focuses on one task at a time with verification against requirements
- Stops after task completion for user review
- Provides task recommendations when no specific task is requested
- Handles both task execution and task-related questions

**Usage:** `/kiro:execute [task description or task number]`

</details>

<details>
<summary> <b>/kiro:vibe</b> - Quick development assistance with Kiro's laid-back, developer-focused approach </summary>

### `/kiro:vibe` Command

Located in `commands/kiro/vibe.md`, this command provides quick development assistance with Kiro's characteristic style:

- Uses Kiro's relaxed, developer-friendly communication style
- Provides direct, actionable responses without unnecessary elaboration
- Focuses on practical solutions and code examples
- Maintains warm, supportive tone while being technically precise
- Ideal for quick questions and straightforward development tasks

**Usage:** `/kiro:vibe [problem or question]`

</details>

### Claude Code Commands

<details>
<summary> <b>/cc:create-command</b> - Create Claude Code Custom Command </summary>

### `/cc:create-command` Command

Located in `commands/cc/create-command.md`, this command creates new Claude Code custom commands:

- Creates command files with proper YAML frontmatter structure
- Includes comprehensive documentation templates
- Follows best practices for command development
- Validates command syntax and functionality
- Supports both project-level and user-level commands

**Usage:** `/cc:create-command [command-name] [description]`

</details>

## Guidances

- [Claude Code with Github Copilot as Model Provider](guidances/github-copilot.md)

## LICENSE

This project is released under MIT License - See [LICENSE](LICENSE) for details.
