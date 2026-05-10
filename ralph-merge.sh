#!/bin/bash
# Ralph Merge - Review and merge completed feature branch to main
# Usage: ./ralph-merge.sh [--prune]

set -e

PRUNE_REMOTE=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --prune)
      PRUNE_REMOTE=true
      shift
      ;;
    *)
      echo "Usage: ./ralph-merge.sh [--prune]"
      echo "  --prune  Delete remote feature branch after merge"
      exit 1
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRD_FILE="$SCRIPT_DIR/prd.json"

# 1. Determine feature branch
if [ -f "$PRD_FILE" ]; then
  FEATURE_BRANCH=$(grep -o '"branchName"[[:space:]]*:[[:space:]]*"[^"]*"' "$PRD_FILE" 2>/dev/null | head -1 | sed 's/.*:[[:space:]]*"\([^"]*\)".*/\1/')
fi

if [ -z "$FEATURE_BRANCH" ]; then
  FEATURE_BRANCH=$(git branch --show-current 2>/dev/null || echo "")
fi

if [ -z "$FEATURE_BRANCH" ]; then
  echo "Error: Could not determine feature branch."
  echo "Make sure prd.json has 'branchName' or you are on a feature branch."
  exit 1
fi

if [ "$FEATURE_BRANCH" = "main" ] || [ "$FEATURE_BRANCH" = "master" ]; then
  echo "Error: You are on '$FEATURE_BRANCH'. Switch to a feature branch first."
  exit 1
fi

echo "Feature branch: $FEATURE_BRANCH"
echo ""

# 2. Fetch latest main
echo "Fetching origin main..."
git fetch origin main 2>/dev/null || git fetch origin master 2>/dev/null || {
  echo "Warning: Could not fetch origin main/master. Using local refs."
}

MAIN_BRANCH="main"
if ! git rev-parse --verify main >/dev/null 2>&1; then
  if git rev-parse --verify master >/dev/null 2>&1; then
    MAIN_BRANCH="master"
  else
    echo "Error: Neither 'main' nor 'master' branch found."
    exit 1
  fi
fi

# Ensure we have the latest target ref
if git rev-parse --verify "origin/$MAIN_BRANCH" >/dev/null 2>&1; then
  TARGET_REF="origin/$MAIN_BRANCH"
else
  TARGET_REF="$MAIN_BRANCH"
fi

# 3. Show change summary
echo ""
echo "========== Commits to merge =========="
git log --oneline "$TARGET_REF..HEAD" || {
  echo "No commits found. Has the branch diverged from $TARGET_REF?"
  exit 1
}
echo ""

echo "========== Files changed =========="
git diff --stat "$TARGET_REF..HEAD"
echo ""

# 4. Diff review
check_icdiff() {
  if ! command -v icdiff &>/dev/null; then
    return 1
  fi
  if ! git config --global difftool.icdiff.cmd &>/dev/null; then
    return 1
  fi
  return 0
}

if check_icdiff; then
  echo "icdiff detected. Launching interactive diff review..."
  echo ""
  echo "Review each file diff. Press 'q' to quit the diff viewer when done."
  echo ""
  # Pause briefly so user can read the prompt
  sleep 1
  git difftool --tool=icdiff "$TARGET_REF..HEAD" 2>&1 || true
  echo ""
else
  echo "icdiff not configured. To enable side-by-side diff review:"
  echo ""
  echo "  pip install icdiff"
  echo "  git config --global difftool.icdiff.cmd 'icdiff --line-numbers --no-bold \"\$LOCAL\" \"\$REMOTE\"'"
  echo "  git config --global difftool.prompt false"
  echo ""
fi

# 5. Confirmation
echo "========== Review Summary =========="
echo "Feature branch: $FEATURE_BRANCH"
echo "Target branch:  $MAIN_BRANCH"
echo "Commits:"
git log --oneline "$TARGET_REF..HEAD"
echo ""

CONFIRM=""
while [[ "$CONFIRM" != "y" && "$CONFIRM" != "n" && "$CONFIRM" != "yes" && "$CONFIRM" != "no" ]]; do
  read -r -p "Merge $FEATURE_BRANCH into $MAIN_BRANCH? [y/N] " CONFIRM || true
  CONFIRM=$(echo "$CONFIRM" | tr '[:upper:]' '[:lower:]')
  if [ -z "$CONFIRM" ]; then
    CONFIRM="n"
  fi
done

if [[ "$CONFIRM" != "y" && "$CONFIRM" != "yes" ]]; then
  echo "Merge cancelled."
  exit 0
fi

# 6. Merge
echo ""
echo "Merging $FEATURE_BRANCH into $MAIN_BRANCH..."

# Save current state in case of failure
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "$FEATURE_BRANCH" ]; then
  git checkout "$FEATURE_BRANCH" 2>/dev/null || true
fi

# Stash any uncommitted changes
STASHED=false
if ! git diff-index --quiet HEAD -- 2>/dev/null; then
  git stash push -m "ralph-merge: auto stash before merge"
  STASHED=true
  echo "Stashed uncommitted changes."
fi

# Checkout main and merge
git checkout "$MAIN_BRANCH"
git merge "$FEATURE_BRANCH" --no-ff -m "merge: $FEATURE_BRANCH

Merging Ralph-generated feature branch into $MAIN_BRANCH."

echo ""
echo "Merge successful!"

# Push main
read -r -p "Push $MAIN_BRANCH to origin? [y/N] " PUSH_CONFIRM || true
PUSH_CONFIRM=$(echo "$PUSH_CONFIRM" | tr '[:upper:]' '[:lower:]')
if [[ "$PUSH_CONFIRM" == "y" || "$PUSH_CONFIRM" == "yes" ]]; then
  git push origin "$MAIN_BRANCH"
  echo "Pushed $MAIN_BRANCH to origin."
fi

# Prune remote feature branch
if $PRUNE_REMOTE; then
  echo ""
  read -r -p "Delete remote branch origin/$FEATURE_BRANCH? [y/N] " PRUNE_CONFIRM || true
  PRUNE_CONFIRM=$(echo "$PRUNE_CONFIRM" | tr '[:upper:]' '[:lower:]')
  if [[ "$PRUNE_CONFIRM" == "y" || "$PRUNE_CONFIRM" == "yes" ]]; then
    git push origin --delete "$FEATURE_BRANCH" 2>/dev/null || echo "Warning: Could not delete remote branch."
  fi
fi

# Restore stash if needed
if $STASHED; then
  echo ""
  echo "Restoring stashed changes..."
  git stash pop 2>/dev/null || echo "Note: Stashed changes available via 'git stash list'"
fi

echo ""
echo "Merge complete. You are now on '$MAIN_BRANCH'."
