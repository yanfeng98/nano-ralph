---
name: merge
description: "Review diff and merge ALL completed Ralph feature branches to main with AI-assisted conflict resolution. Automatically detects parallel branches and merges them in the correct order (backend → frontend). Triggers on: merge this branch, merge to main, review and merge, merge feature, merge ralph branch, merge all, merge."
user-invocable: true
---

# Merge Reviewer

Detect all completed Ralph branches, review changes, and merge them to main in the correct order. One command merges everything.

---

## The Job

1. Detect all pending Ralph branches (may be 1 or N from parallel tracks)
2. Show a combined summary of all branches
3. Determine the correct merge order
4. Ask ONE confirmation for all
5. Merge each branch in order, resolving conflicts
6. Push (if user confirms)
7. Clean up all associated worktrees

---

## Step 0: Detect All Pending Branches

Find every Ralph branch that is ready to merge:

```bash
# All ralph branches (not yet merged to main)
git branch --list 'ralph/*' --no-merged main 2>/dev/null || git branch --list 'ralph/*'

# All active Ralph worktrees
git worktree list | grep '.ralph/worktrees/' || echo "No active worktrees"

# Parallel PRD files (confirms this was a parallel run)
ls scripts/ralph/prd-*.json 2>/dev/null || echo "No parallel PRDs"
```

Also check `scripts/ralph/prd.json` for single-track runs.

From these, build the list of branches to merge. If there are multiple related branches (same feature, different tracks like `ralph/feature-backend`, `ralph/feature-frontend`), they are parallel tracks. Merge ALL of them.

If no branches are found, tell the user and exit.

---

## Step 1: Determine Merge Order

**For a single branch:** just merge it.

**For multiple parallel branches, sort by track type:**

| Track type | Merge order | Rationale |
|------------|-------------|-----------|
| `db`, `schema`, `migration` | 1st | Database changes needed by everything |
| `backend`, `api`, `service` | 2nd | API/services needed by frontend |
| `frontend`, `ui`, `web` | 3rd | UI consumes backend APIs |
| `infra`, `ops`, `deploy` | Last | Infrastructure wraps everything |

Detect the track type from the branch name suffix: `ralph/<feature>-<track>`.

If unsure about order, ask the user.

---

## Step 2: Move to Main Repo

```bash
# Find main repo path
MAIN_REPO=$(git worktree list | head -1 | awk '{print $1}')
MAIN_WORKTREE=$(git worktree list | grep -E '\[main\]|\[master\]' | head -1 | awk '{print $1}' || echo "")
if [ -n "$MAIN_WORKTREE" ]; then
  cd "$MAIN_WORKTREE"
else
  cd "$MAIN_REPO"
fi
```

---

## Step 3: Show Combined Summary

Fetch latest:

```bash
git fetch origin main 2>/dev/null || git fetch origin master 2>/dev/null || true
```

Determine target:

```bash
if git rev-parse --verify main >/dev/null 2>&1; then
  TARGET="main"
elif git rev-parse --verify master >/dev/null 2>&1; then
  TARGET="master"
else
  echo "Error: Neither main nor master found"
  exit 1
fi
```

Present a combined summary of ALL branches:

```
=== Branches to merge (in order) ===

1. ralph/task-priority-backend
   Commits: 3    Files: +120 -5
   Stories: US-001 (DB), US-002 (API) — both passing

2. ralph/task-priority-frontend
   Commits: 4    Files: +85 -12
   Stories: US-003 (Badge), US-004 (Filter) — both passing

Target: main
Total: 7 commits across 2 branches
```

For each branch, show `git log --oneline $TARGET..<branch>` and `git diff --stat $TARGET..<branch>`.

If `progress.txt` exists in any worktree, include the story completion summary.

---

## Step 4: Diff Review (Optional icdiff)

Check if icdiff is configured:

```bash
command -v icdiff && git config --global difftool.icdiff.cmd
```

**If configured:** Offer to run diff review for each branch:

```bash
# For each branch in order
git difftool --tool=icdiff $TARGET..<branch>
```

**If not configured:** Tell the user how to set it up:

```
pip install icdiff
git config --global difftool.icdiff.cmd 'icdiff --line-numbers --no-bold "$LOCAL" "$REMOTE"'
git config --global difftool.prompt false
git config --global diff.tool icdiff
```

---

## Step 5: Confirm (Once for All)

Present a clean summary and ask ONCE:

```
Merge all N branches into <target> in this order?
  1. ralph/<feature>-backend  (2 stories, 3 commits)
  2. ralph/<feature>-frontend (2 stories, 4 commits)

This will merge backend first, then frontend.
```

Wait for a single confirmation. Do NOT ask per-branch.

---

## Step 6: Merge Each Branch in Order

For each branch in the determined order:

```bash
git checkout $TARGET
git merge <branch> --no-ff -m "merge: <branch>

Merging Ralph-generated feature branch into $TARGET."
```

After each merge, report: "Merged <branch> (N/N complete)"

### If Conflicts Occur on Any Branch:

1. Run `git diff --name-only --diff-filter=U` to list conflicted files
2. Read each conflicted file and understand both sides
3. Resolve conflicts intelligently:
   - Prefer the feature branch's intent (it's the new code)
   - But do NOT blindly accept one side — merge logically
   - If a conflict is genuinely ambiguous, explain the choices and ask the user
4. `git add` resolved files
5. `git commit` to complete the merge
6. Continue with the next branch

**Important conflict resolution principles:**
- Keep both additions when they are independent
- When both sides modify the same logic, prefer the feature branch but preserve any main-side refactors
- Never silently drop code from either side
- When merging frontend after backend: backend added the API, frontend uses it — these don't conflict

---

## Step 7: Push

After ALL branches are merged, ask once:

"Push <target> to origin?"

If yes: `git push origin $TARGET`

Ask once for all remote branches:

"Delete N remote branches: origin/<branch1>, origin/<branch2>?"

If yes, delete each: `git push origin --delete <branch>`

---

## Step 8: Clean Up All Worktrees

List all worktrees that were merged:

```
All branches merged. Active Ralph worktrees:
  .ralph/worktrees/<feature>-backend
  .ralph/worktrees/<feature>-frontend

Remove all? This runs git worktree remove for each.
```

If user confirms, remove each worktree:

```bash
# For each worktree
git worktree remove <path> --force 2>/dev/null || {
  echo "Warning: Could not remove <path> (may have uncommitted changes)"
}
```

Also prune local branches:

```bash
# Delete each merged feature branch locally
git branch -d <branch1> <branch2> ... 2>/dev/null || true
```

If any worktree has uncommitted changes, warn before force-removing.

---

## Step 9: Summary

Stay on `$TARGET` after all merges.

Summarize what was done:
- Number of branches merged
- Total commits merged
- Any conflicts resolved (and how, for each branch)
- Whether pushed
- Worktrees cleaned up

---

## Hard Rules

1. **Detect ALL branches automatically.** Don't ask "which branch?" unless nothing is found.
2. **One confirmation for all.** Never ask per-branch.
3. **Merge in dependency order.** Backend/data before frontend/UI.
4. **Never silently drop code** during conflict resolution.
5. **Clean up everything** — branches, worktrees — in one go.
6. **If a branch has uncommitted changes, warn** before force-removing its worktree.
