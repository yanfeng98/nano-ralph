---
name: merge
description: "Review diff and merge a feature branch to main with AI-assisted conflict resolution. Use after Ralph completes. Triggers on: merge this branch, merge to main, review and merge, merge feature, merge ralph branch."
user-invocable: true
---

# Merge Reviewer

Review changes on a feature branch, then merge it to main. If conflicts arise, resolve them intelligently.

---

## The Job

1. Determine the feature branch (from `prd.json` `branchName` or current git branch)
2. Fetch latest main
3. Show what changed (commits + file stats)
4. Optionally run `git difftool` with `icdiff` for side-by-side review
5. Confirm with user
6. Merge to main -- resolve any conflicts
7. Push (if user confirms)

---

## Step 1: Determine Feature Branch

Read `prd.json` if it exists and extract `branchName`. Otherwise use `git branch --show-current`.

Checkout the feature branch if not already on it.

**Guard:** If on `main` or `master`, abort and tell the user to switch to the feature branch first.

---

## Step 2: Fetch and Compare

```bash
git fetch origin main 2>/dev/null || git fetch origin master 2>/dev/null || true
```

Show a summary of what will be merged:

```bash
git log --oneline origin/main..HEAD 2>/dev/null || git log --oneline main..HEAD
```

```bash
git diff --stat origin/main..HEAD 2>/dev/null || git diff --stat main..HEAD
```

---

## Step 3: Diff Review (Optional icdiff)

Check if icdiff is configured:

```bash
command -v icdiff && git config --global difftool.icdiff.cmd
```

**If configured:** Offer to run interactive diff review:

```bash
git difftool --tool=icdiff origin/main..HEAD
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

## Step 4: Confirm

Present a clean summary:

- Feature branch name
- Target branch (main/master)
- List of commits (one line each)
- Files changed count

Ask: "Merge [branch] into main?"

Wait for explicit confirmation before proceeding. Do NOT merge without user approval.

---

## Step 5: Merge

```bash
git checkout main
git merge [feature-branch] --no-ff
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

## Step 6: Push

Ask: "Push main to origin?"

If yes: `git push origin main`

Ask: "Delete remote feature branch origin/[branch]?"

If yes: `git push origin --delete [branch]`

---

## Step 7: Clean Up

Stay on `main` after merge.

Summarize what was done:
- Merged commits
- Any conflicts resolved (and how)
- Whether pushed
