#!/bin/bash
# Ralph Wiggum - Long-running AI agent loop
# Usage: ./ralph.sh [--tool opencode|claude] [--model <model>] [--prd <file>] [--no-worktree] [max_iterations]
# By default, Ralph runs in an isolated git worktree under .ralph/worktrees/

set -e

# Parse arguments
TOOL="claude"
MAX_ITERATIONS=10
MODEL=""
PRD_FILE=""
USE_WORKTREE=true

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
    --model)
      MODEL="$2"
      shift 2
      ;;
    --model=*)
      MODEL="${1#*=}"
      shift
      ;;
    --prd)
      PRD_FILE="$2"
      shift 2
      ;;
    --prd=*)
      PRD_FILE="${1#*=}"
      shift
      ;;
    --no-worktree)
      USE_WORKTREE=false
      shift
      ;;
    *)
      if [[ "$1" =~ ^[0-9]+$ ]]; then
        MAX_ITERATIONS="$1"
      fi
      shift
      ;;
  esac
done

# Validate tool choice
if [[ "$TOOL" != "opencode" && "$TOOL" != "claude" ]]; then
  echo "Error: Invalid tool '$TOOL'. Must be 'opencode' or 'claude'."
  exit 1
fi

# Set opencode permissions via environment variable
if [ "$TOOL" = "opencode" ]; then
  export OPENCODE_PERMISSION='{"*": "allow"}'
  export OPENCODE_DISABLE_AUTOCOMPACT=true
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Resolve PRD file path
if [ -z "$PRD_FILE" ]; then
  PRD_FILE="$SCRIPT_DIR/prd.json"
else
  # If relative, resolve from SCRIPT_DIR
  if [[ "$PRD_FILE" != /* ]]; then
    PRD_FILE="$SCRIPT_DIR/$PRD_FILE"
  fi
fi

# Extract branchName from PRD
if [ ! -f "$PRD_FILE" ]; then
  echo "Error: PRD file not found: $PRD_FILE"
  echo "Create one with /prd and /ralph skills, or specify with --prd <file>"
  exit 1
fi

BRANCH_NAME=$(grep -o '"branchName"[[:space:]]*:[[:space:]]*"[^"]*"' "$PRD_FILE" 2>/dev/null | head -1 | sed 's/.*:[[:space:]]*"\([^"]*\)".*/\1/')
if [ -z "$BRANCH_NAME" ]; then
  echo "Error: Could not read 'branchName' from $PRD_FILE"
  exit 1
fi

echo "PRD file:    $PRD_FILE"
echo "Branch:      $BRANCH_NAME"
echo "Tool:        $TOOL"
echo "Model:       $MODEL"
echo "Max iters:   $MAX_ITERATIONS"

# ============================================================
# Worktree Setup (default mode)
# ============================================================
if $USE_WORKTREE; then
  PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
  if [ -z "$PROJECT_ROOT" ]; then
    echo "Error: Not in a git repository. Use --no-worktree or run /init first."
    exit 1
  fi

  # Derive worktree folder name from branch (strip ralph/ prefix)
  WORKTREE_NAME=$(echo "$BRANCH_NAME" | sed 's|^ralph/||' | sed 's|/|-|g')
  WORKTREE_DIR="$PROJECT_ROOT/.ralph/worktrees/$WORKTREE_NAME"

  echo "Worktree:    $WORKTREE_DIR"

  # Check if worktree already exists
  if [ -d "$WORKTREE_DIR" ]; then
    echo ""
    echo "Worktree already exists at: $WORKTREE_DIR"
    echo "Resuming in existing worktree (preserving prd.json and progress.txt)..."
    echo "(Run 'git worktree remove $WORKTREE_DIR' to clean up)"

    # Update prompt.md (always safe — AI instructions may have changed)
    cp "$SCRIPT_DIR/prompt.md" "$WORKTREE_DIR/prompt.md"

    # Initialize progress file only if it doesn't exist (never overwrite)
    if [ ! -f "$WORKTREE_DIR/progress.txt" ]; then
      echo "# Ralph Progress Log" > "$WORKTREE_DIR/progress.txt"
      echo "Started: $(date)" >> "$WORKTREE_DIR/progress.txt"
      echo "---" >> "$WORKTREE_DIR/progress.txt"
    fi
    # NOTE: prd.json is NOT overwritten — it contains runtime state (passes: true/false)
  else
    # Determine main branch
    MAIN_BRANCH="main"
    if ! git rev-parse --verify origin/main >/dev/null 2>&1 && ! git rev-parse --verify main >/dev/null 2>&1; then
      if git rev-parse --verify origin/master >/dev/null 2>&1 || git rev-parse --verify master >/dev/null 2>&1; then
        MAIN_BRANCH="master"
      else
        echo "Error: Neither 'main' nor 'master' branch found."
        exit 1
      fi
    fi

    # Resolve the base ref (prefer origin/ over local)
    if git rev-parse --verify "origin/$MAIN_BRANCH" >/dev/null 2>&1; then
      BASE_REF="origin/$MAIN_BRANCH"
    else
      BASE_REF="$MAIN_BRANCH"
    fi

    echo "Base ref:    $BASE_REF"

    # Create branch from base ref if it doesn't exist
    if ! git rev-parse --verify "$BRANCH_NAME" >/dev/null 2>&1; then
      echo "Creating branch $BRANCH_NAME from $BASE_REF..."
      git branch "$BRANCH_NAME" "$BASE_REF"
    else
      echo "Branch $BRANCH_NAME already exists."
    fi

    # Create worktree
    echo "Creating worktree..."
    mkdir -p "$PROJECT_ROOT/.ralph/worktrees"
    git worktree add "$WORKTREE_DIR" "$BRANCH_NAME"

    # Copy ralph runtime files into new worktree
    cp "$PRD_FILE" "$WORKTREE_DIR/prd.json"
    cp "$SCRIPT_DIR/prompt.md" "$WORKTREE_DIR/prompt.md"

    # Initialize progress file
    echo "# Ralph Progress Log" > "$WORKTREE_DIR/progress.txt"
    echo "Started: $(date)" >> "$WORKTREE_DIR/progress.txt"
    echo "---" >> "$WORKTREE_DIR/progress.txt"

    echo ""
    echo "Worktree created successfully."
  fi

  # Switch context to worktree
  cd "$WORKTREE_DIR"
  SCRIPT_DIR="$WORKTREE_DIR"
  PRD_FILE="$WORKTREE_DIR/prd.json"
fi

# ============================================================
# Shared file paths (from here on, SCRIPT_DIR is the worktree)
# ============================================================
PROGRESS_FILE="$SCRIPT_DIR/progress.txt"
ARCHIVE_DIR="$SCRIPT_DIR/archive"
LAST_BRANCH_FILE="$SCRIPT_DIR/.last-branch"

# ============================================================
# Archive previous run if branch changed
# ============================================================
if [ -f "$PRD_FILE" ] && [ -f "$LAST_BRANCH_FILE" ]; then
  CURRENT_BRANCH=$(grep -o '"branchName"[[:space:]]*:[[:space:]]*"[^"]*"' "$PRD_FILE" 2>/dev/null | head -1 | sed 's/.*:[[:space:]]*"\([^"]*\)".*/\1/')
  LAST_BRANCH=$(cat "$LAST_BRANCH_FILE" 2>/dev/null || echo "")

  if [ -n "$CURRENT_BRANCH" ] && [ -n "$LAST_BRANCH" ] && [ "$CURRENT_BRANCH" != "$LAST_BRANCH" ]; then
    DATE=$(date +%Y-%m-%d)
    FOLDER_NAME=$(echo "$LAST_BRANCH" | sed 's|^ralph/||')
    ARCHIVE_FOLDER="$ARCHIVE_DIR/$DATE-$FOLDER_NAME"

    echo "Archiving previous run: $LAST_BRANCH"
    mkdir -p "$ARCHIVE_FOLDER"
    [ -f "$PRD_FILE" ] && cp "$PRD_FILE" "$ARCHIVE_FOLDER/"
    [ -f "$PROGRESS_FILE" ] && cp "$PROGRESS_FILE" "$ARCHIVE_FOLDER/"
    echo "   Archived to: $ARCHIVE_FOLDER"

    # Reset progress file
    echo "# Ralph Progress Log" > "$PROGRESS_FILE"
    echo "Started: $(date)" >> "$PROGRESS_FILE"
    echo "---" >> "$PROGRESS_FILE"
  fi
fi

# Track current branch
if [ -f "$PRD_FILE" ]; then
  CURRENT_BRANCH=$(grep -o '"branchName"[[:space:]]*:[[:space:]]*"[^"]*"' "$PRD_FILE" 2>/dev/null | head -1 | sed 's/.*:[[:space:]]*"\([^"]*\)".*/\1/')
  if [ -n "$CURRENT_BRANCH" ]; then
    echo "$CURRENT_BRANCH" > "$LAST_BRANCH_FILE"
  fi
fi

# Initialize progress file if it doesn't exist
if [ ! -f "$PROGRESS_FILE" ]; then
  echo "# Ralph Progress Log" > "$PROGRESS_FILE"
  echo "Started: $(date)" >> "$PROGRESS_FILE"
  echo "---" >> "$PROGRESS_FILE"
fi

echo ""
echo "Starting Ralph - Tool: $TOOL - Max iterations: $MAX_ITERATIONS"
echo "Working directory: $(pwd)"
echo ""

for i in $(seq 1 $MAX_ITERATIONS); do
  echo "==============================================================="
  echo "  Ralph Iteration $i of $MAX_ITERATIONS ($TOOL)"
  echo "==============================================================="
  echo ""

  # Run the selected tool with the ralph prompt
  if [[ "$TOOL" == "opencode" ]]; then
    OPENCODE_MODEL="${MODEL:-opencode/big-pickle}"
    OUTPUT=$(cat "$SCRIPT_DIR/prompt.md" | opencode run -m "$OPENCODE_MODEL" --agent build 2>&1 | tee /dev/stderr) || true
  else
    OUTPUT=$(claude --dangerously-skip-permissions --print < "$SCRIPT_DIR/prompt.md" 2>&1 | tee /dev/stderr) || true
  fi

  # Check for completion signal
  if echo "$OUTPUT" | grep -q "<promise>COMPLETE</promise>"; then
    echo ""
    echo "Ralph completed all tasks!"
    echo "Completed at iteration $i of $MAX_ITERATIONS"
    echo ""
    if $USE_WORKTREE; then
      echo "Worktree: $WORKTREE_DIR"
      echo ""
      echo "Next steps:"
      echo "  1. Review changes in the worktree"
      echo "  2. Run /merge to merge $BRANCH_NAME into main"
      echo "  3. Run: git worktree remove $WORKTREE_DIR"
    else
      echo "Run /merge to merge $BRANCH_NAME into main"
    fi
    exit 0
  fi

  echo "Iteration $i complete. Continuing..."
  echo ""
  sleep 2
done

echo ""
echo "Ralph reached max iterations ($MAX_ITERATIONS) without completing all tasks."
echo "Check $PROGRESS_FILE for status."
if $USE_WORKTREE; then
  echo ""
  echo "Worktree: $WORKTREE_DIR"
  echo "Re-run ralph.sh to resume (existing worktree will be reused)"
fi
exit 1
