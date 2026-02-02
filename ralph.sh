#!/bin/bash
# Ralph Wiggum - Long-running AI agent loop
# Usage: ralph [--tool amp|claude] [max_iterations]
#
# Global installation:
#   1. Copy ralph.sh to ~/bin/ralph (or anywhere in PATH)
#   2. Copy prompt.md and CLAUDE.md to ~/.config/ralph/
#   3. Run 'ralph' from any repo with a Ralph epic in beads

set -e

# Parse arguments
TOOL="claude"  # Default to Claude Code
MAX_ITERATIONS=10

while [[ $# -gt 0 ]]; do
  case $1 in
    --tool)
      TOOL="$2"
      shift 2
      ;;
    --tool=*)
      TOOL="${1#*=}"
      shift
      ;;
    *)
      # Assume it's max_iterations if it's a number
      if [[ "$1" =~ ^[0-9]+$ ]]; then
        MAX_ITERATIONS="$1"
      fi
      shift
      ;;
  esac
done

# Validate tool choice
if [[ "$TOOL" != "amp" && "$TOOL" != "claude" ]]; then
  echo "Error: Invalid tool '$TOOL'. Must be 'amp' or 'claude'."
  exit 1
fi

# Configuration locations (global install)
CONFIG_DIR="${RALPH_CONFIG_DIR:-$HOME/.config/ralph}"
PROMPT_FILE="$CONFIG_DIR/prompt.md"
CLAUDE_FILE="$CONFIG_DIR/CLAUDE.md"

# Working directory is the current repo
WORK_DIR="$(pwd)"
ARCHIVE_DIR="$WORK_DIR/.ralph-archive"
LAST_EPIC_FILE="$WORK_DIR/.ralph-epic"

# Function to get the active Ralph epic
get_ralph_epic() {
  # Find epic with branchName in design field (marks it as a Ralph epic)
  # bd list returns array of objects
  bd list --type epic --status open --json 2>/dev/null | \
    jq -r '.[] | select(.design != null and (.design | test("branchName:"))) | .id' | head -1
}

# Function to get branch name from epic
get_epic_branch() {
  local epic_id="$1"
  # bd show returns array even for single item, so use .[0]
  bd show "$epic_id" --json 2>/dev/null | \
    jq -r '(if type == "array" then .[0] else . end) | .design // ""' | \
    sed -n 's/.*branchName: *\([^ ]*\).*/\1/p'
}

# Function to archive an epic
archive_epic() {
  local epic_id="$1"
  local branch_name="$2"

  DATE=$(date +%Y-%m-%d)
  # Strip "ralph/" prefix from branch name for folder
  FOLDER_NAME=$(echo "$branch_name" | sed 's|^ralph/||')
  ARCHIVE_FOLDER="$ARCHIVE_DIR/$DATE-$FOLDER_NAME"

  echo "Archiving previous epic: $branch_name (ID: $epic_id)"
  mkdir -p "$ARCHIVE_FOLDER"

  # Export epic and tasks to JSON for archival
  bd show "$epic_id" --json > "$ARCHIVE_FOLDER/epic.json" 2>/dev/null || true
  bd list --parent "$epic_id" --json > "$ARCHIVE_FOLDER/tasks.json" 2>/dev/null || true

  # Close the old epic
  bd close "$epic_id" 2>/dev/null || true

  echo "   Archived to: $ARCHIVE_FOLDER"
}

# Check for bd command
if ! command -v bd &> /dev/null; then
  echo "Error: 'bd' (beads CLI) is not installed or not in PATH."
  echo "Install beads or ensure bd is available."
  exit 1
fi

# Check for prompt files
if [[ "$TOOL" == "amp" ]]; then
  if [ ! -f "$PROMPT_FILE" ]; then
    echo "Error: Prompt file not found: $PROMPT_FILE"
    echo ""
    echo "To set up Ralph globally:"
    echo "  mkdir -p ~/.config/ralph"
    echo "  cp /path/to/ralph/prompt.md ~/.config/ralph/"
    echo "  cp /path/to/ralph/CLAUDE.md ~/.config/ralph/"
    exit 1
  fi
else
  if [ ! -f "$CLAUDE_FILE" ]; then
    echo "Error: Claude prompt file not found: $CLAUDE_FILE"
    echo ""
    echo "To set up Ralph globally:"
    echo "  mkdir -p ~/.config/ralph"
    echo "  cp /path/to/ralph/prompt.md ~/.config/ralph/"
    echo "  cp /path/to/ralph/CLAUDE.md ~/.config/ralph/"
    exit 1
  fi
fi

# Initialize beads if not already
bd init 2>/dev/null || true

# Find active Ralph epic
EPIC_ID=$(get_ralph_epic)

if [ -z "$EPIC_ID" ]; then
  echo "Error: No active Ralph epic found in $(pwd)"
  echo ""
  echo "To start a Ralph run:"
  echo "  1. Create a PRD with /prd"
  echo "  2. Convert to beads with /ralph"
  echo ""
  exit 1
fi

# Get branch from epic metadata
BRANCH=$(get_epic_branch "$EPIC_ID")

if [ -z "$BRANCH" ]; then
  echo "Error: Epic $EPIC_ID has no branchName in design field."
  exit 1
fi

# Archive previous epic if it's different
if [ -f "$LAST_EPIC_FILE" ]; then
  LAST_EPIC=$(cat "$LAST_EPIC_FILE" 2>/dev/null || echo "")

  if [ -n "$LAST_EPIC" ] && [ "$LAST_EPIC" != "$EPIC_ID" ]; then
    # Check if old epic still exists and is open
    OLD_STATUS=$(bd show "$LAST_EPIC" --json 2>/dev/null | jq -r '(if type == "array" then .[0] else . end) | .status // "unknown"' || echo "unknown")
    if [ "$OLD_STATUS" == "open" ]; then
      OLD_BRANCH=$(get_epic_branch "$LAST_EPIC")
      archive_epic "$LAST_EPIC" "$OLD_BRANCH"
    fi
  fi
fi

# Track current epic
echo "$EPIC_ID" > "$LAST_EPIC_FILE"

# Export for agent use
export RALPH_EPIC_ID="$EPIC_ID"
export RALPH_BRANCH="$BRANCH"

# Check for multiple open epics (warn user)
EPIC_COUNT=$(bd list --type epic --status open --json 2>/dev/null | \
  jq -r '[.[] | select(.design != null and (.design | test("branchName:")))] | length')

if [ "$EPIC_COUNT" -gt 1 ]; then
  echo "Warning: Multiple Ralph epics are open. Using: $EPIC_ID ($BRANCH)"
  echo "Consider closing old epics with: bd close <epic-id>"
  echo ""
fi

echo "Starting Ralph - Tool: $TOOL - Max iterations: $MAX_ITERATIONS"
echo "Working directory: $WORK_DIR"
echo "Epic: $EPIC_ID"
echo "Branch: $BRANCH"

for i in $(seq 1 $MAX_ITERATIONS); do
  echo ""
  echo "==============================================================="
  echo "  Ralph Iteration $i of $MAX_ITERATIONS ($TOOL)"
  echo "==============================================================="

  # Run the selected tool with the ralph prompt
  if [[ "$TOOL" == "amp" ]]; then
    OUTPUT=$(RALPH_EPIC_ID="$EPIC_ID" RALPH_BRANCH="$BRANCH" cat "$PROMPT_FILE" | amp --dangerously-allow-all 2>&1 | tee /dev/stderr) || true
  else
    # Claude Code: use --dangerously-skip-permissions for autonomous operation, --print for output
    OUTPUT=$(RALPH_EPIC_ID="$EPIC_ID" RALPH_BRANCH="$BRANCH" claude --dangerously-skip-permissions --print < "$CLAUDE_FILE" 2>&1 | tee /dev/stderr) || true
  fi

  # Sync beads after each iteration
  bd sync 2>/dev/null || true

  # Check for completion signal
  if echo "$OUTPUT" | grep -q "<promise>COMPLETE</promise>"; then
    echo ""
    echo "Ralph completed all tasks!"
    echo "Completed at iteration $i of $MAX_ITERATIONS"

    # Final sync
    bd sync 2>/dev/null || true
    exit 0
  fi

  echo "Iteration $i complete. Continuing..."
  sleep 2
done

echo ""
echo "Ralph reached max iterations ($MAX_ITERATIONS) without completing all tasks."
echo "Check task status with: bd list --parent $EPIC_ID"
exit 1
