---
name: merge
description: "Review diff and merge a feature branch to main with AI-assisted conflict resolution. Use after Ralph completes. Works from worktree or main repo. Triggers on: merge this branch, merge to main, review and merge, merge feature, merge ralph branch."
user-invocable: true
---

# Merge Reviewer

Review changes on a feature branch, then merge it to main. If conflicts arise, resolve them intelligently. Works whether you are in a Ralph worktree or the main repository.

---

## The Job

1. Detect current context (worktree vs main repo)
2. Determine the feature branch
3. Switch to main repo and checkout main
4. Fetch latest and show change summary
5. Optionally run icdiff for side-by-side review
6. Confirm with user
7. Merge to main -- resolve any conflicts
8. Push (if user confirms)
9. Offer to clean up the worktree

---

## Step 0: Detect Context

Check where you are:

```bash
pwd
git worktree list
```

**If you are inside `.ralph/worktrees/<name>/`:**

- You are in a Ralph worktree
- Read `prd.json` from the current directory to get `branchName`
- Also read `progress.txt` to summarize what was done
- The **main repo** is the first entry in `git worktree list` (the one on `main` or `master`, or the bare repo)
- You will switch to the main repo before merging

**If you are in the main repo (not a worktree path):**

- `prd.json` may be at `scripts/ralph/prd.json` or in the current directory
- The feature branch will come from `prd.json` `branchName` or `git branch --show-current`

**Guard:** If currently on `main` or `master` branch and no `prd.json` with a different `branchName`, ask the user which feature branch to merge.

---

## Step 1: Determine Feature Branch

1. If `prd.json` is found, extract `branchName`
2. Otherwise, use `git branch --show-current` (only valid if in worktree)
3. If neither yields a feature branch, ask the user

Note the worktree path if applicable:

```bash
# Does a worktree exist for this branch?
git worktree list | grep "<feature-branch>" || true
```

---

## Step 2: Move to Main Repo

**Critical:** You cannot merge while inside a worktree that's on the feature branch. Move to the main repo first.

```bash
# Find main repo path (first worktree entry, or the git top-level)
MAIN_REPO=$(git worktree list | head -1 | awk '{print $1}')

# If there's a worktree on main/master, use that. Otherwise use the main repo.
MAIN_WORKTREE=$(git worktree list | grep -E '\[main\]|\[master\]' | head -1 | awk '{print $1}' || echo "")
if [ -n "$MAIN_WORKTREE" ]; then
  cd "$MAIN_WORKTREE"
else
  cd "$MAIN_REPO"
fi
```

---

## Step 3: Fetch and Compare

```bash
git fetch origin main 2>/dev/null || git fetch origin master 2>/dev/null || true
```

Determine target branch:

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

Show what will be merged:

```bash
git log --oneline $TARGET..<feature-branch>
```

```bash
git diff --stat $TARGET..<feature-branch>
```

If `progress.txt` was found in Step 0, show a summary of what was done.

---

## Step 4: Diff Review (Optional icdiff)

Check if icdiff is configured:

```bash
command -v icdiff && git config --global difftool.icdiff.cmd
```

**If configured:** Offer to run interactive diff review:

```bash
git difftool --tool=icdiff $TARGET..<feature-branch>
```

Tell the user: "Review each file. Press 'q' to exit the diff viewer."

**If not configured:** Tell the user how to set it up:

```
pip install icdiff
git config --global difftool.icdiff.cmd 'icdiff --line-numbers --no-bold "$LOCAL" "$REMOTE"'
git config --global difftool.prompt false
git config --global diff.tool icdiff
```

Then proceed without it.

---

## Step 5: Confirm

Present a clean summary:

- Feature branch name
- Target branch
- List of commits (one line each)
- Files changed count (+N -M)
- Worktree location (if applicable)

Ask: "Merge <feature-branch> into <target>?"

Wait for explicit confirmation before proceeding. Do NOT merge without user approval.

---

## Step 6: Merge

```bash
git checkout $TARGET
git merge <feature-branch> --no-ff
```

### If Conflicts Occur:

1. Run `git diff --name-only --diff-filter=U` to list conflicted files
2. Read each conflicted file and understand both sides
3. Resolve conflicts intelligently:
   - Prefer the feature branch's intent (it's the new code)
   - But do NOT blindly accept one side -- merge logically
   - If a conflict is genuinely ambiguous, explain the choices and ask the user
4. `git add` resolved files
5. `git commit` to complete the merge

**Important conflict resolution principles:**
- Keep both additions when they are independent (e.g., new function + new import)
- When both sides modify the same logic, prefer the feature branch but preserve any main-side refactors that don't conflict with the feature's intent
- Never silently drop code from either side

---

## Step 7: Push

Ask: "Push <target> to origin?"

If yes: `git push origin $TARGET`

Ask: "Delete remote feature branch origin/<feature-branch>?"

If yes: `git push origin --delete <feature-branch>`

---

## Step 8: Clean Up Worktree

### Check for Other Parallel Worktrees

Before cleaning up, check if other worktrees are still active for related features:

```bash
git worktree list
ls .ralph/worktrees/ 2>/dev/null || echo "No worktrees"
```

If other worktrees exist (e.g., from parallel tracks), tell the user:
```
Other active worktrees:
  .ralph/worktrees/<other-track> — branch <other-branch>

These are for parallel tracks. Don't remove them if they're still in progress.
```

### Clean Up This Worktree

If a worktree was found for the merged feature branch in Step 1:

```
The worktree for <feature-branch> is still at <path>.
Remove it? This runs: git worktree remove <path>
```

If user confirms:

```bash
# Prune the local branch first if we're done with it
git branch -d <feature-branch> 2>/dev/null || true

# Remove worktree
git worktree remove <path> --force 2>/dev/null || {
  echo "Worktree has uncommitted changes. Remove manually:"
  echo "  git worktree remove <path> --force"
}
```

If the worktree has uncommitted changes, warn the user before forcing removal.

### Multiple Parallel Tracks: Merge Order

If this was a parallel development with multiple tracks:

```
Parallel tracks detected. Recommended merge order:
  1. Merge backend/data tracks first (schema + API changes)
  2. Then merge frontend/UI tracks

If you merge in the wrong order, later merges may have more conflicts.
```

---

## Step 9: Summary

Stay on `$TARGET` after merge.

Summarize what was done:
- Merged commits (count)
- Any conflicts resolved (and how)
- Whether pushed
- Worktree status (removed or still present at path)

---

## Hard Rules

1. **Never merge without user confirmation.** Always present the summary first.
2. **Never silently drop code** during conflict resolution.
3. **Always fetch before merging** to avoid surprises.
4. **Do NOT remove worktree without asking.**
5. **If worktree has uncommitted changes, warn loudly** before force-removing.
