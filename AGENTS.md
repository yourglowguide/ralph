# Ralph Agent Instructions

## Overview

Ralph is an autonomous AI agent loop that runs AI coding tools (Amp or Claude Code) repeatedly until all tasks are complete. Each iteration is a fresh instance with clean context.

## Commands

```bash
# Run the flowchart dev server
cd flowchart && npm run dev

# Build the flowchart
cd flowchart && npm run build

# Run Ralph with Claude Code (default)
ralph [max_iterations]

# Run Ralph with Amp
ralph --tool amp [max_iterations]
```

## Key Files

- `ralph` - The bash loop that spawns fresh AI instances (supports `--tool amp` or `--tool claude`)
- `prompt.md` - Instructions given to each AMP instance
- `CLAUDE.md` - Instructions given to each Claude Code instance
- `migrate-prd-to-beads.sh` - Migration script for converting prd.json to beads
- `prd.json.example` - Example PRD format (legacy reference)
- `flowchart/` - Interactive React Flow diagram explaining how Ralph works

## Beads Architecture

Ralph uses beads for task tracking:

```
Epic: "Ralph: <project> - <description>"
  ├── metadata (design): branchName: ralph/<feature-name>
  ├── Task: "Patterns & Memory" (priority 0, stays open)
  │     └── notes: Codebase patterns and learnings
  ├── Task: "US-001: <title>" (priority 1)
  ├── Task: "US-002: <title>" (priority 2)
  └── ...
```

## Useful Beads Commands

```bash
# List tasks in current epic
bd list --parent $RALPH_EPIC_ID

# Get next ready task
bd ready --parent $RALPH_EPIC_ID

# View task details
bd show <task-id>

# Close a task
bd close <task-id>

# Sync changes
bd sync
```

## Flowchart

The `flowchart/` directory contains an interactive visualization built with React Flow. It's designed for presentations - click through to reveal each step with animations.

To run locally:
```bash
cd flowchart
npm install
npm run dev
```

## Patterns

- Each iteration spawns a fresh AI instance (Amp or Claude Code) with clean context
- Memory persists via git history and beads (task status + Patterns & Memory bead)
- Tasks should be small enough to complete in one context window
- Always update AGENTS.md with discovered patterns for future iterations
- The "Patterns & Memory" bead (priority 0) stores learnings between iterations

## Landing the Plane (Session Completion)

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd sync
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
