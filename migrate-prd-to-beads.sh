#!/bin/bash
# Migrate prd.json to beads format
# Usage: ./migrate-prd-to-beads.sh [prd.json]

set -e

PRD_FILE="${1:-prd.json}"

if [ ! -f "$PRD_FILE" ]; then
  echo "Error: PRD file not found: $PRD_FILE"
  exit 1
fi

# Check for bd command
if ! command -v bd &> /dev/null; then
  echo "Error: 'bd' (beads CLI) is not installed or not in PATH."
  exit 1
fi

# Check for jq command
if ! command -v jq &> /dev/null; then
  echo "Error: 'jq' is not installed or not in PATH."
  exit 1
fi

echo "Migrating $PRD_FILE to beads..."

# Extract project info
PROJECT=$(jq -r '.project // "Unknown"' "$PRD_FILE")
DESCRIPTION=$(jq -r '.description // "Migrated from prd.json"' "$PRD_FILE")
BRANCH_NAME=$(jq -r '.branchName // "ralph/migrated"' "$PRD_FILE")

# Determine base branch (use env var if set, otherwise detect from remote, fallback to main)
BASE_BRANCH="${RALPH_BASE_BRANCH:-$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo 'main')}"

echo "Project: $PROJECT"
echo "Description: $DESCRIPTION"
echo "Branch: $BRANCH_NAME"
echo "Base branch: $BASE_BRANCH"
echo ""

# Initialize beads if needed
bd init 2>/dev/null || true

# Check for existing Ralph epics
EXISTING=$(bd list --type epic --status open --json 2>/dev/null | \
  jq -r '.[] | select(.design != null and (.design | test("branchName:"))) | "\(.id): \(.title)"' || echo "")

if [ -n "$EXISTING" ]; then
  echo "Warning: Found existing Ralph epic(s):"
  echo "$EXISTING"
  echo ""
  read -p "Continue anyway? (y/N) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
  fi
fi

# Create epic
echo "Creating epic..."
EPIC_ID=$(bd create "Ralph: $PROJECT - $DESCRIPTION" \
  --type epic \
  --design "branchName: $BRANCH_NAME
baseBranch: $BASE_BRANCH" \
  --silent)

echo "Created epic: $EPIC_ID"

# Create patterns bead
echo "Creating Patterns & Memory task..."
bd create "Patterns & Memory" \
  --type task \
  --parent "$EPIC_ID" \
  --priority 0 \
  --notes "## Codebase Patterns

(Patterns discovered during implementation will be added here)

## Learnings

(Gotchas and useful context will be added here)

---
Migrated from: $PRD_FILE" \
  --silent

# Import progress.txt patterns if it exists
PROGRESS_FILE="$(dirname "$PRD_FILE")/progress.txt"
if [ -f "$PROGRESS_FILE" ]; then
  # Try to extract Codebase Patterns section
  PATTERNS=$(sed -n '/## Codebase Patterns/,/^## [^C]/p' "$PROGRESS_FILE" 2>/dev/null | head -n -1 || echo "")
  if [ -n "$PATTERNS" ]; then
    echo "Found existing patterns in progress.txt, consider copying them to the Patterns & Memory bead"
  fi
fi

# Create task beads for each user story
echo "Creating tasks..."
STORY_COUNT=$(jq '.userStories | length' "$PRD_FILE")

for i in $(seq 0 $((STORY_COUNT - 1))); do
  STORY=$(jq ".userStories[$i]" "$PRD_FILE")

  ID=$(echo "$STORY" | jq -r '.id')
  TITLE=$(echo "$STORY" | jq -r '.title')
  STORY_DESC=$(echo "$STORY" | jq -r '.description // ""')
  PRIORITY=$(echo "$STORY" | jq -r '.priority // 1')
  PASSES=$(echo "$STORY" | jq -r '.passes // false')
  NOTES=$(echo "$STORY" | jq -r '.notes // ""')

  # Build acceptance criteria string
  ACCEPTANCE=$(echo "$STORY" | jq -r '.acceptanceCriteria // [] | map("- " + .) | join("\n")')

  echo "  Creating: $ID: $TITLE (priority: $PRIORITY, passes: $PASSES)"

  # Create the task
  TASK_ID=$(bd create "$ID: $TITLE" \
    --type task \
    --parent "$EPIC_ID" \
    --priority "$PRIORITY" \
    --description "$STORY_DESC" \
    --acceptance "$ACCEPTANCE" \
    --silent)

  # If story already passed, close the task
  if [ "$PASSES" = "true" ]; then
    bd close "$TASK_ID" 2>/dev/null || true
    echo "    -> Marked as closed (was passes: true)"
  fi

  # Add notes if present
  if [ -n "$NOTES" ] && [ "$NOTES" != "" ]; then
    bd update "$TASK_ID" --notes "$NOTES" 2>/dev/null || true
  fi
done

# Sync
bd sync

echo ""
echo "Migration complete!"
echo ""
echo "Epic ID: $EPIC_ID"
echo "Tasks created: $STORY_COUNT"
echo ""
echo "View with: bd list --parent $EPIC_ID"
echo "Start Ralph: ./ralph.sh"
echo ""
echo "You can now delete $PRD_FILE and progress.txt if desired."
