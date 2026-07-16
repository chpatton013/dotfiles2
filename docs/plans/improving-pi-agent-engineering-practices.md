# Improving Pi Agent Software Engineering Practices

## Context

I'm running Pi Agent with a locally-hosted LLM inference service (vLLM with Qwen3.5 models). While the agent works, it lacks several "good software engineering practices" that I see in other AI coding assistants like Claude Code:

- **Automated git commits**: Claude Code proactively commits work; Pi does not
- **Test execution before commits**: Running tests before finalizing changes
- **Design patterns**: SOLID principles, isolated unit testing
- **Documentation**: Writing docstrings, updating docs as code changes
- **Follow-up management**: Tracking and managing follow-up tasks

## Current Plugin Ecosystem

My Pi Agent setup includes these plugins that provide some capabilities:

### Planning & Task Management

- **`@narumitw/pi-goal`**: Goal mode with `/goal` command, `goal_complete` tool, session-scoped goals
- **`@narumitw/pi-plan-mode`**: Read-only planning mode with `/plan` command
- **`@juicesharp/rpiv-todo`**: Todo list tool with persistence, dependencies, overlay UI
- **`context-mode`**: Context management with `ctx_execute`, `ctx_search`, `ctx_index` for large file processing

### Code Quality & Navigation

- **`pi-lens`**: LSP diagnostics, ast-grep/tree-sitter rules, code navigation
- **`pi-memory-stone`**: Cross-session memory for decisions, preferences, error resolutions

### Search & Discovery

- **`@ff-labs/pi-fff`**: Fast file finder and grep replacement (FFF-powered)
- **`pi-mcp-adapter`**: MCP server integration without context window bloat

### User Interaction

- **`@juicesharp/rpiv-ask-user-question`**: Structured questions with options
- **`@juicesharp/rpiv-btw`**: "By the way" notifications

### Status & Monitoring

- **`@npm-ken/pi-bar`**: Configurable status bar with git, activity, model info

## Gaps to Address

### 1. Git Integration

- No automatic commit creation
- No commit message generation
- No commit mode indicator in status bar
- Need per-project git handling

### 2. Testing & Validation

- No automatic test execution before completion
- No test result reporting
- Need integration with test frameworks

### 3. Code Design & Quality

- No automatic documentation generation (docstrings, README updates)
- No SOLID principle enforcement
- No automatic refactoring suggestions

### 4. Workflow Automation

- Follow-up task management (partially covered by todo plugin)
- Code review checklist automation
- PR description generation

## Investigation Goals

1. **Understand current plugin capabilities**: What can be achieved with existing plugins?
2. **Identify gaps**: What's missing that Claude Code provides?
3. **Design solutions**: Should gaps be filled with:
   - New plugins?
   - Skills (project-specific)?
   - Prompt templates/system instructions?
   - Config changes?
4. **Implementation plan**: Step-by-step approach to close gaps

## Next Steps

- [ ] Investigate git capabilities in current setup
- [ ] Research Claude Code's commit workflow
- [ ] Determine if git integration should be a plugin or skill
- [ ] Design commit mode status bar segment
- [ ] Plan test execution integration
- [ ] Document code interface requirements
- [ ] Create implementation roadmap
