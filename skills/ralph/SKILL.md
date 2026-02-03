---
name: ralph
description: "Convert PRDs to beads format for the Ralph autonomous agent system. Use when you have an existing PRD and need to convert it to Ralph's beads format. Triggers on: convert this prd, turn this into ralph format, create ralph beads from this, ralph json."
user-invocable: true
---

# Ralph PRD Converter

Converts existing PRDs to the beads format that Ralph uses for autonomous execution.

---

## The Job

Take a PRD (markdown file or text) and create beads (epic + tasks) for Ralph to execute.

---

## Output Structure

Ralph uses beads with this architecture:

```
Epic: "Ralph: <project> - <description>"
  ├── metadata (design field): branchName: ralph/<feature-name>
  ├── Task: "Patterns & Memory" (priority 0, stays open)
  │     └── notes: "## Codebase Patterns\n\n(Patterns discovered during implementation)"
  ├── Task: "US-001: <title>" (priority 2)
  ├── Task: "US-002: <title>" (priority 2)
  └── ...
```

---

## Priority System (IMPORTANT)

Beads priorities are **importance levels**, NOT sequential task IDs. Valid values are **0-4 only**:

| Priority | Meaning | Usage |
|----------|---------|-------|
| **0** | Reserved/Special | Used ONLY for "Patterns & Memory" bead - never auto-picked by `bd ready` |
| **1** | Critical | Blocking issues, must be done first |
| **2** | Normal (default) | Standard tasks - **use this for most stories** |
| **3** | Low | Nice-to-have, can wait |
| **4** | Backlog | Future work, lowest priority |

### Key Rules:
- **Multiple tasks can have the same priority** - this is normal and expected
- **`bd ready` handles ordering** within the same priority (by creation order, dependencies, etc.)
- **Do NOT increment priorities** for each story (1, 2, 3, 4, 5... is WRONG)
- **Priority 5+ does not exist** - it will cause an error

### Correct Usage:
```bash
# Patterns bead - priority 0 (special, never auto-picked)
bd create "Patterns & Memory" --priority 0 --parent "$EPIC_ID" ...

# All normal stories - priority 2 (or 1 if critical)
bd create "US-001: Add status field" --priority 2 --parent "$EPIC_ID" ...
bd create "US-002: Display badge" --priority 2 --parent "$EPIC_ID" ...
bd create "US-003: Add toggle" --priority 2 --parent "$EPIC_ID" ...
# ... even 20 stories can all be priority 2
```

### When to Use Different Priorities:
- Use **priority 1** for foundational work that MUST happen before anything else (schema migrations)
- Use **priority 2** for all standard feature work
- Use **priority 3** for optional enhancements or polish
- Use dependencies (`--deps`) for task ordering, NOT priority numbers

---

## Creating Beads

Use these commands to create the Ralph structure:

```bash
# Initialize beads if needed
bd init 2>/dev/null || true

# Create epic with branch metadata in design field
EPIC_ID=$(bd create "Ralph: $PROJECT - $DESCRIPTION" \
  --type epic \
  --design "branchName: ralph/$BRANCH_NAME" \
  --silent)

# Create patterns bead (priority 0 = never auto-picked by bd ready)
bd create "Patterns & Memory" \
  --type task \
  --parent "$EPIC_ID" \
  --priority 0 \
  --notes "## Codebase Patterns

(Patterns discovered during implementation will be added here)

## Learnings

(Gotchas and useful context will be added here)"

# Create task beads for each user story (use priority 2 for all normal stories)
bd create "US-001: $TITLE" \
  --type task \
  --parent "$EPIC_ID" \
  --priority 2 \
  --description "$DESCRIPTION" \
  --acceptance "- Criterion 1
- Criterion 2
- Typecheck passes"

# Sync to persist
bd sync
```

---

## Story Size: The Number One Rule

**Each story must be completable in ONE Ralph iteration (one context window).**

Ralph spawns a fresh agent instance per iteration with no memory of previous work. If a story is too big, the LLM runs out of context before finishing and produces broken code.

### Right-sized stories:
- Add a database column and migration
- Add a UI component to an existing page
- Update a server action with new logic
- Add a filter dropdown to a list

### Too big (split these):
- "Build the entire dashboard" - Split into: schema, queries, UI components, filters
- "Add authentication" - Split into: schema, middleware, login UI, session handling
- "Refactor the API" - Split into one story per endpoint or pattern

**Rule of thumb:** If you cannot describe the change in 2-3 sentences, it is too big.

---

## Story Ordering: Dependencies First

Stories execute in priority order. Earlier stories must not depend on later ones.

**Correct order:**
1. Schema/database changes (migrations)
2. Server actions / backend logic
3. UI components that use the backend
4. Dashboard/summary views that aggregate data

**Wrong order:**
1. UI component (depends on schema that does not exist yet)
2. Schema change

---

## Acceptance Criteria: Must Be Verifiable

Each criterion must be something Ralph can CHECK, not something vague.

### Good criteria (verifiable):
- "Add `status` column to tasks table with default 'pending'"
- "Filter dropdown has options: All, Active, Completed"
- "Clicking delete shows confirmation dialog"
- "Typecheck passes"
- "Tests pass"

### Bad criteria (vague):
- "Works correctly"
- "User can do X easily"
- "Good UX"
- "Handles edge cases"

### Always include as final criterion:
```
Typecheck passes
```

For stories with testable logic, also include:
```
Tests pass
```

### For stories that change UI, also include:
```
Verify in browser using dev-browser skill
```

Frontend stories are NOT complete until visually verified. Ralph will use the dev-browser skill to navigate to the page, interact with the UI, and confirm changes work.

---

## Conversion Rules

1. **Each user story becomes one task bead**
2. **IDs**: Sequential in title (US-001, US-002, etc.)
3. **Priority**: Use **priority 2** for all normal stories (NOT incrementing numbers!)
   - Exception: Use priority 1 for critical foundational work (schema migrations)
   - Use dependencies (`--deps`) to enforce ordering, not priority values
4. **branchName**: Derive from feature name, kebab-case, prefixed with `ralph/`
5. **Always add**: "Typecheck passes" to every story's acceptance criteria
6. **Always create**: A "Patterns & Memory" task with priority 0

---

## Splitting Large PRDs

If a PRD has big features, split them:

**Original:**
> "Add user notification system"

**Split into:**
1. US-001: Add notifications table to database
2. US-002: Create notification service for sending notifications
3. US-003: Add notification bell icon to header
4. US-004: Create notification dropdown panel
5. US-005: Add mark-as-read functionality
6. US-006: Add notification preferences page

Each is one focused change that can be completed and verified independently.

---

## Example

**Input PRD:**
```markdown
# Task Status Feature

Add ability to mark tasks with different statuses.

## Requirements
- Toggle between pending/in-progress/done on task list
- Filter list by status
- Show status badge on each task
- Persist status in database
```

**Output beads commands:**
```bash
bd init 2>/dev/null || true

EPIC_ID=$(bd create "Ralph: TaskApp - Task Status Feature" \
  --type epic \
  --design "branchName: ralph/task-status" \
  --silent)

bd create "Patterns & Memory" \
  --type task \
  --parent "$EPIC_ID" \
  --priority 0 \
  --notes "## Codebase Patterns

(Patterns discovered during implementation will be added here)

## Learnings

(Gotchas and useful context will be added here)"

# Schema migration is foundational - use priority 1
bd create "US-001: Add status field to tasks table" \
  --type task \
  --parent "$EPIC_ID" \
  --priority 1 \
  --description "As a developer, I need to store task status in the database." \
  --acceptance "- Add status column: 'pending' | 'in_progress' | 'done' (default 'pending')
- Generate and run migration successfully
- Typecheck passes"

# All other stories use priority 2 (NOT incrementing!)
bd create "US-002: Display status badge on task cards" \
  --type task \
  --parent "$EPIC_ID" \
  --priority 2 \
  --description "As a user, I want to see task status at a glance." \
  --acceptance "- Each task card shows colored status badge
- Badge colors: gray=pending, blue=in_progress, green=done
- Typecheck passes
- Verify in browser using dev-browser skill"

bd create "US-003: Add status toggle to task list rows" \
  --type task \
  --parent "$EPIC_ID" \
  --priority 2 \
  --description "As a user, I want to change task status directly from the list." \
  --acceptance "- Each row has status dropdown or toggle
- Changing status saves immediately
- UI updates without page refresh
- Typecheck passes
- Verify in browser using dev-browser skill"

bd create "US-004: Filter tasks by status" \
  --type task \
  --parent "$EPIC_ID" \
  --priority 2 \
  --description "As a user, I want to filter the list to see only certain statuses." \
  --acceptance "- Filter dropdown: All | Pending | In Progress | Done
- Filter persists in URL params
- Typecheck passes
- Verify in browser using dev-browser skill"

bd sync

echo "Created Ralph epic: $EPIC_ID"
echo "Run 'ralph.sh' to start execution"
```

---

## Archiving Previous Runs

**Before creating a new epic, check for existing Ralph epics:**

```bash
# Check for existing Ralph epics
EXISTING=$(bd list --type epic --status open --json | \
  jq -r '.[] | select(.design != null and (.design | test("branchName:"))) | "\(.id): \(.title)"')

if [ -n "$EXISTING" ]; then
  echo "Warning: Found existing Ralph epic(s):"
  echo "$EXISTING"
  echo ""
  echo "Consider closing them first with: bd close <epic-id>"
fi
```

**The ralph.sh script handles archiving automatically** when it detects a different epic, but you can manually archive with:

```bash
bd close <old-epic-id>
```

---

## Migration from prd.json

If you have an existing prd.json, use the migration script:

```bash
./migrate-prd-to-beads.sh prd.json
```

This will create the equivalent beads structure and mark already-passed stories as closed.

---

## Checklist Before Creating Beads

Before running the bd commands, verify:

- [ ] **Checked for existing Ralph epics** (close old ones if needed)
- [ ] Each story is completable in one iteration (small enough)
- [ ] Stories are ordered by dependency (schema → backend → UI)
- [ ] Every story has "Typecheck passes" as criterion
- [ ] UI stories have "Verify in browser using dev-browser skill" as criterion
- [ ] Acceptance criteria are verifiable (not vague)
- [ ] No story depends on a later story
- [ ] Branch name is kebab-case with `ralph/` prefix
