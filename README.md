# Ralph

![Ralph](ralph.webp)

Ralph is an autonomous AI agent loop that runs AI coding tools ([Claude Code](https://docs.anthropic.com/en/docs/claude-code) or [Amp](https://ampcode.com)) repeatedly until all tasks are complete. Each iteration is a fresh instance with clean context. Memory persists via git history and [Beads](https://github.com/beads-project/beads) task tracking.

Based on [Geoffrey Huntley's Ralph pattern](https://ghuntley.com/ralph/).

[Read my in-depth article on how I use Ralph](https://x.com/ryancarson/status/2008548371712135632)

---

## Table of Contents

- [Quick Start](#quick-start)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Usage Tutorial](#usage-tutorial)
- [Command Reference](#command-reference)
- [How Ralph Works](#how-ralph-works)
- [Writing Good PRDs](#writing-good-prds)
- [Troubleshooting](#troubleshooting)
- [FAQ](#faq)
- [Reference](#reference)

---

## Quick Start

```bash
# 1. Install prerequisites
npm install -g @anthropic-ai/claude-code  # Claude Code
brew install jq                            # JSON processor
# Install beads CLI from https://github.com/beads-project/beads

# 2. Install Ralph globally
cp ralph.sh ~/bin/ralph && chmod +x ~/bin/ralph
mkdir -p ~/.config/ralph && cp prompt.md CLAUDE.md ~/.config/ralph/

# 3. In your project root, create tasks with Claude Code
cd ~/my-project  # Must be at repo root
claude
> /ralph   # Then describe your feature and let it create beads

# 4. Run Ralph (from repo root)
ralph
```

---

## Prerequisites

### Required

| Tool | Purpose | Installation |
|------|---------|--------------|
| **Claude Code** | AI coding tool (default) | `npm install -g @anthropic-ai/claude-code` |
| **Beads CLI** | Task tracking | [github.com/beads-project/beads](https://github.com/beads-project/beads) |
| **jq** | JSON processing | `brew install jq` (macOS) or `apt install jq` (Linux) |
| **Git** | Version control | Usually pre-installed |

### Optional

| Tool | Purpose | Installation |
|------|---------|--------------|
| **Amp CLI** | Alternative AI tool | [ampcode.com](https://ampcode.com) |

### Verify Installation

```bash
# Check all tools are available
claude --version    # Should show version
bd --version        # Should show version
jq --version        # Should show version
git --version       # Should show version
```

---

## Installation

### Global Installation (Recommended)

Install Ralph once and use it with any repository:

```bash
# 1. Clone the Ralph repository
git clone git@github.com:yourglowguide/ralph.git
cd ralph

# 2. Copy the ralph command to your PATH
cp ralph.sh ~/bin/ralph
chmod +x ~/bin/ralph

# 3. Copy prompt templates to config directory
mkdir -p ~/.config/ralph
cp prompt.md ~/.config/ralph/
cp CLAUDE.md ~/.config/ralph/

# 4. (Optional) Install skills for Claude Code
mkdir -p ~/.claude/skills
cp -r skills/prd ~/.claude/skills/
cp -r skills/ralph ~/.claude/skills/

# 5. Verify installation
ralph --help  # Should show usage (or error about no epic)
```

### Verify Your PATH

Make sure `~/bin` is in your PATH. Add to your `~/.bashrc` or `~/.zshrc`:

```bash
export PATH="$HOME/bin:$PATH"
```

Then restart your terminal or run `source ~/.bashrc`.

---

## Usage Tutorial

### Step 1: Start a New Feature

Navigate to the **root** of your project repository:

```bash
cd ~/my-project  # Must be at repo root
```

**Important:** Ralph must be run from the root of your git repository. It uses the current working directory to find beads, create commits, and manage the `.ralph-*` files.

### Step 2: Create a PRD (Product Requirements Document)

Open Claude Code and use the `/prd` skill:

```bash
claude
```

Then in Claude Code:
```
/prd

Create a PRD for adding user authentication with email/password login
```

Claude will ask clarifying questions and generate a detailed PRD saved to `tasks/prd-[feature-name].md`.

### Step 3: Convert PRD to Ralph Tasks

Use the `/ralph` skill to convert the PRD to beads:

```
/ralph

Convert tasks/prd-user-authentication.md to beads
```

This creates:
- An **epic** with the feature name and branch
- A **Patterns & Memory** task for storing learnings
- Individual **task beads** for each user story

### Step 4: Verify the Tasks

Check what was created:

```bash
# List all epics
bd list --type epic

# List tasks in the epic (get EPIC_ID from above)
bd list --parent <EPIC_ID>

# See the first ready task
bd ready --parent <EPIC_ID>
```

### Step 5: Run Ralph

Start the autonomous loop:

```bash
ralph
```

Ralph will:
1. Find the active epic
2. Check out the feature branch (or create it)
3. Pick the highest priority ready task
4. Implement it using Claude Code
5. Run quality checks (typecheck, lint, tests)
6. Commit if checks pass
7. Close the task
8. Repeat until all tasks are done

### Step 6: Monitor Progress

In another terminal, watch Ralph's progress:

```bash
# See task status
bd list --parent <EPIC_ID>

# See what Ralph learned
bd show <PATTERNS_BEAD_ID>

# Watch git commits
git log --oneline -20
```

### Step 7: Completion

When all tasks are done, Ralph outputs:
```
Ralph completed all tasks!
Completed at iteration 5 of 10
```

Review the changes, then merge your feature branch.

---

## Command Reference

### Basic Usage

```bash
cd ~/my-project   # Run from your repo root
ralph [OPTIONS] [MAX_ITERATIONS]
```

### Options

| Option | Description | Default |
|--------|-------------|---------|
| `--tool claude` | Use Claude Code | Default |
| `--tool amp` | Use Amp CLI | - |
| `[number]` | Max iterations before stopping | 10 |

### Examples

```bash
# Run with defaults (Claude Code, 10 iterations)
ralph

# Run with Amp
ralph --tool amp

# Run up to 20 iterations
ralph 20

# Run with Amp, max 5 iterations
ralph --tool amp 5
```

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `RALPH_CONFIG_DIR` | Location of prompt templates | `~/.config/ralph` |
| `RALPH_EPIC_ID` | (Set by Ralph) Current epic ID | - |
| `RALPH_BRANCH` | (Set by Ralph) Feature branch name | - |

### Beads Commands (for manual interaction)

```bash
# List open Ralph epics
bd list --type epic --status open

# List tasks in an epic
bd list --parent <EPIC_ID>

# Get the next ready task
bd ready --parent <EPIC_ID>

# View task details
bd show <TASK_ID>

# Manually close a task
bd close <TASK_ID>

# Sync beads to disk
bd sync
```

---

## How Ralph Works

### The Loop

```
┌─────────────────────────────────────────────────────────┐
│                    Ralph Loop                            │
├─────────────────────────────────────────────────────────┤
│  1. Find active Ralph epic (has branchName in metadata) │
│  2. Get highest priority ready task                      │
│  3. Spawn fresh Claude Code instance                     │
│  4. Claude reads task, implements it                     │
│  5. Claude runs quality checks                           │
│  6. Claude commits changes                               │
│  7. Claude closes the task                               │
│  8. Ralph syncs beads                                    │
│  9. Check: All tasks done? → Exit                        │
│ 10. Otherwise → Go to step 2                             │
└─────────────────────────────────────────────────────────┘
```

### Memory Between Iterations

Each iteration is a **fresh AI instance** with no memory. Context is preserved through:

| What | How | Purpose |
|------|-----|---------|
| Code changes | Git commits | Each iteration sees previous work |
| Task status | Beads | Know what's done, what's next |
| Learnings | Patterns bead | Codebase patterns, gotchas |
| Conventions | AGENTS.md files | Project-specific knowledge |

### Beads Architecture

```
Epic: "Ralph: MyApp - User Authentication"
  │
  ├── metadata.design: "branchName: ralph/user-auth"
  │
  ├── Task: "Patterns & Memory" (priority: 0)
  │   └── notes: "## Codebase Patterns\n- Uses Prisma for DB..."
  │
  ├── Task: "US-001: Add users table" (priority: 1)
  │   ├── description: "As a developer, I need..."
  │   ├── acceptance: "- Add users table\n- Typecheck passes"
  │   └── status: closed ✓
  │
  ├── Task: "US-002: Create login API" (priority: 2)
  │   └── status: open (in progress)
  │
  └── Task: "US-003: Build login UI" (priority: 3)
      └── status: open (blocked by US-002)
```

### Files Created Per Repo

| File | Purpose | Git? |
|------|---------|------|
| `.beads/` | Beads database | Optional |
| `.ralph-epic` | Current epic ID | No |
| `.ralph-archive/` | Archived epics | No |

Add to `.gitignore`:
```
.ralph-epic
.ralph-archive/
```

---

## Writing Good PRDs

### The Golden Rule

**Each task must be completable in ONE iteration (one context window).**

If a task is too big, the AI runs out of context and produces broken code.

### Right-Sized Tasks

| Good (small) | Bad (too big) |
|--------------|---------------|
| Add a database column | Build the entire dashboard |
| Create one API endpoint | Add authentication |
| Add a UI component | Refactor the API |
| Add a filter dropdown | Implement search |

**Rule of thumb:** If you can't describe it in 2-3 sentences, split it.

### Task Ordering

Tasks run in priority order. Earlier tasks must NOT depend on later ones.

```
✓ Correct Order:
1. Add database schema (no dependencies)
2. Create server actions (depends on schema)
3. Build UI components (depends on actions)
4. Add dashboard view (depends on components)

✗ Wrong Order:
1. Build UI components (schema doesn't exist!)
2. Add database schema
```

### Acceptance Criteria

Each criterion must be **verifiable**, not vague.

| Good (verifiable) | Bad (vague) |
|-------------------|-------------|
| "Add status column with default 'pending'" | "Works correctly" |
| "Filter dropdown has: All, Active, Done" | "Good UX" |
| "Clicking delete shows confirmation" | "Handles edge cases" |
| "Typecheck passes" | "Is well tested" |

**Always include:** `Typecheck passes` as the last criterion.

**For UI tasks:** `Verify in browser using dev-browser skill`

---

## Troubleshooting

### "No active Ralph epic found"

**Cause:** Either no epic exists, or you're not in the right directory.

**Solution:**
```bash
# Make sure you're at your repo root
cd ~/my-project
pwd  # Verify you're in the right place

# Check what epics exist
bd list --type epic --status open

# If no epics, create one using the /ralph skill in Claude Code
claude
> /ralph
> Convert my-prd.md to beads
```

### "Epic has no branchName in design field"

**Cause:** The epic was created manually without the required metadata.

**Solution:**
```bash
# View the epic
bd show <EPIC_ID>

# Update with branch name
bd update <EPIC_ID> --design "branchName: ralph/my-feature"
```

### "bd: command not found"

**Cause:** Beads CLI is not installed or not in PATH.

**Solution:**
```bash
# Install beads from https://github.com/beads-project/beads
# Then verify:
bd --version
```

### "Prompt file not found"

**Cause:** The prompt templates aren't in `~/.config/ralph/`.

**Solution:**
```bash
mkdir -p ~/.config/ralph
cp /path/to/ralph/prompt.md ~/.config/ralph/
cp /path/to/ralph/CLAUDE.md ~/.config/ralph/
```

### Ralph keeps failing on the same task

**Cause:** The task is too big or has unclear requirements.

**Solution:**
1. Check the task: `bd show <TASK_ID>`
2. Split it into smaller tasks
3. Add clearer acceptance criteria
4. Check if dependencies are met

### Ralph completed but code is broken

**Cause:** Missing feedback loops (no typecheck, no tests).

**Solution:**
1. Add typecheck to your project: `npm install -D typescript`
2. Add tests for critical logic
3. Ensure acceptance criteria include "Typecheck passes"

### Multiple Ralph epics warning

**Cause:** Old epics weren't closed before starting a new one.

**Solution:**
```bash
# List all Ralph epics
bd list --type epic --status open --json | jq '.[] | select(.design | test("branchName"))'

# Close old ones
bd close <OLD_EPIC_ID>
```

### Ralph runs but nothing happens

**Cause:** Claude Code might be failing silently.

**Solution:**
1. Run Claude Code manually to check for auth issues:
   ```bash
   claude --print "Hello"
   ```
2. Check if you've hit API rate limits
3. Look at the output in the terminal for errors

---

## FAQ

### General

**Q: What's the difference between Ralph and just using Claude Code directly?**

A: Claude Code has a single context window. When it fills up, it loses track of earlier work. Ralph runs multiple fresh instances, each with clean context, using beads to track what's done. This allows completing larger features that would overflow a single context.

**Q: How many tasks can Ralph handle?**

A: There's no hard limit. Ralph will run until all tasks are closed or it hits max iterations (default 10). For large features, use `ralph 50` or higher.

**Q: Can I pause and resume Ralph?**

A: Yes. Press Ctrl+C to stop. Run `ralph` again to continue - it picks up from the next incomplete task.

**Q: Does Ralph push to GitHub?**

A: No. Ralph only commits locally. You push when you're ready.

### Tasks & Beads

**Q: How do I skip a task?**

A: Close it manually:
```bash
bd close <TASK_ID>
```

**Q: How do I add a task mid-run?**

A: Create it with beads:
```bash
bd create "US-005: New task title" \
  --type task \
  --parent <EPIC_ID> \
  --priority 5 \
  --description "Description here" \
  --acceptance "- Criterion 1\n- Typecheck passes"
```

**Q: What's the Patterns & Memory bead for?**

A: It stores learnings discovered during implementation - codebase patterns, gotchas, useful context. Each iteration reads this first so it doesn't repeat mistakes.

### Customization

**Q: Can I customize what Ralph does each iteration?**

A: Yes. Edit `~/.config/ralph/CLAUDE.md` (for Claude Code) or `~/.config/ralph/prompt.md` (for Amp). Add project-specific instructions, quality checks, or conventions.

**Q: Can I use Ralph with a different AI tool?**

A: Currently Ralph supports Claude Code and Amp. Adding other tools requires modifying `ralph.sh`.

**Q: Can I run Ralph on CI?**

A: Technically yes, but it's designed for local development. You'd need to handle authentication and ensure the AI has appropriate permissions.

---

## Reference

### Key Files

| File | Location | Purpose |
|------|----------|---------|
| `ralph` | `~/bin/ralph` | Main command |
| `CLAUDE.md` | `~/.config/ralph/` | Claude Code prompt |
| `prompt.md` | `~/.config/ralph/` | Amp prompt |
| `/prd` skill | `~/.claude/skills/prd/` | PRD generation |
| `/ralph` skill | `~/.claude/skills/ralph/` | PRD → beads conversion |

### Useful Beads Commands

```bash
# Epic management
bd list --type epic                    # List all epics
bd list --type epic --status open      # List open epics
bd show <ID>                           # View epic details
bd close <ID>                          # Close an epic

# Task management
bd list --parent <EPIC_ID>             # List tasks in epic
bd ready --parent <EPIC_ID>            # Get next ready task
bd show <ID>                           # View task details
bd update <ID> --status in_progress    # Claim a task
bd close <ID>                          # Complete a task

# Sync
bd sync                                # Save to disk
```

### Flowchart

[![Ralph Flowchart](ralph-flowchart.png)](https://yourglowguide.github.io/ralph/)

**[View Interactive Flowchart](https://yourglowguide.github.io/ralph/)**

### External Links

- [Geoffrey Huntley's Ralph article](https://ghuntley.com/ralph/) - Original concept
- [Beads documentation](https://github.com/beads-project/beads) - Task tracking
- [Claude Code documentation](https://docs.anthropic.com/en/docs/claude-code) - AI coding tool
- [Amp documentation](https://ampcode.com/manual) - Alternative AI tool
