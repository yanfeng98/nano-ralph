# Ralph

![Ralph](ralph.webp)

Ralph is an autonomous AI agent loop that runs AI coding tools ([Claude Code](https://docs.anthropic.com/en/docs/claude-code)) repeatedly until all PRD items are complete. Each iteration is a fresh instance with clean context. Memory persists via git history, `progress.txt`, and `prd.json`.

## Prerequisites

- One of the following AI coding tools installed and authenticated:
  - [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (`npm install -g @anthropic-ai/claude-code`)
  - [OpenCode](https://opencode.ai/) (`npm i -g opencode-ai`)
- A git repository for your project

## Setup

### Copy to your project

Copy the ralph files into your project:

```bash
# From your project root
mkdir -p scripts/ralph
cp /path/to/ralph/ralph.sh scripts/ralph/

# Copy the prompt template for your AI tool:
cp /path/to/ralph/prompt.md scripts/ralph/prompt.md

chmod +x scripts/ralph/ralph.sh
```

### Install skills globally

Copy the skills to your Claude config for use across all projects:

For Claude Code (manual)
```bash
cp -r skills/prd ~/.claude/skills/
cp -r skills/ralph ~/.claude/skills/
cp -r skills/merge ~/.claude/skills/
cp -r skills/init ~/.claude/skills/
```

Available skills after installation:
- `/prd` - Generate Product Requirements Documents
- `/ralph` - Convert PRDs to prd.json format
- `/merge` - Review diff and merge feature branch to main
- `/init` - Initialize a git repo with smart .gitignore generation

Skills are automatically invoked when you ask Claude to:
- "create a prd", "write prd for", "plan this feature"
- "convert this prd", "turn into ralph format", "create prd.json"
- "merge this branch", "merge to main", "review and merge"
- "init git", "initialize repo", "setup git for this project"

## Workflow

### 1. Create a PRD

Use the PRD skill to generate a detailed requirements document:

```
Load the prd skill and create a PRD for [your feature description]
```

Answer the clarifying questions. The skill saves output to `tasks/prd-[feature-name].md`.

### 2. Convert PRD to Ralph format

Use the Ralph skill to convert the markdown PRD to JSON:

```
Load the ralph skill and convert tasks/prd-[feature-name].md to prd.json
```

This creates `prd.json` with user stories structured for autonomous execution.

### 3. Run Ralph

```bash
# Using Claude Code
./scripts/ralph/ralph.sh --tool claude

# Using OpenCode with specific model
./scripts/ralph/ralph.sh --tool opencode --model opencode/big-pickle

# Custom max iterations
./scripts/ralph/ralph.sh --tool claude 20

# Use specific PRD file (for parallel development)
./scripts/ralph/ralph.sh --tool claude --prd prd-backend.json
```

Default is 10 iterations.

Ralph will:
1. Create an isolated git worktree at `.ralph/worktrees/<name>/` (from PRD `branchName`)
2. Copy `prd.json` and `prompt.md` into the worktree
3. Pick the highest priority story where `passes: false`
4. Implement that single story
5. Run quality checks (typecheck, tests)
6. Commit if checks pass
7. Update `prd.json` to mark story as `passes: true`
8. Append learnings to `progress.txt`
9. Repeat until all stories pass or max iterations reached
10. Use `/merge` skill to review and merge to main

### Parallel Development (Worktrees)

Ralph uses git worktrees by default, so you can run **multiple instances in parallel**:

```bash
# Split your PRD into independent parts
# prd-backend.json contains US-001, US-002
# prd-frontend.json contains US-003, US-004

# Terminal 1: Claude Code handles backend stories
./scripts/ralph/ralph.sh --prd prd-backend.json --tool claude

# Terminal 2: OpenCode handles frontend stories (same time!)
./scripts/ralph/ralph.sh --prd prd-frontend.json --tool opencode
```

Each instance gets its own isolated worktree under `.ralph/worktrees/`. They work on different branches and never conflict.

**Run without worktree** (legacy mode, uses current directory directly):

```bash
./scripts/ralph/ralph.sh --no-worktree --tool claude
```

## Key Files

| File | Purpose |
|------|---------|
| `ralph.sh` | The bash loop that spawns fresh AI instances in isolated worktrees |
| `.ralph/worktrees/` | Git worktrees created by Ralph (one per feature branch) |
| `prompt.md` | Prompt template for Claude Code |
| `prd.json` | User stories with `passes` status (the task list) |
| `prd.json.example` | Example PRD format for reference |
| `progress.txt` | Append-only learnings for future iterations |
| `skills/prd/` | Skill for generating PRDs (works with OpenCode and Claude Code) |
| `skills/ralph/` | Skill for converting PRDs to JSON (works with OpenCode and Claude Code) |
| `skills/merge/` | Skill for reviewing diff and merging to main with conflict resolution |
| `skills/init/` | Skill for initializing git repo with smart .gitignore |
| `flowchart/` | Interactive visualization of how Ralph works |

## Flowchart

[![Ralph Flowchart](ralph-flowchart.png)](https://snarktank.github.io/ralph/)

**[View Interactive Flowchart](https://snarktank.github.io/ralph/)** - Click through to see each step with animations.

The `flowchart/` directory contains the source code. To run locally:

```bash
cd flowchart
npm install
npm run dev
```

## Critical Concepts

### Each Iteration = Fresh Context

Each iteration spawns a **new AI instance** (Claude Code) with clean context. The only memory between iterations is:
- Git history (commits from previous iterations)
- `progress.txt` (learnings and context)
- `prd.json` (which stories are done)

### Small Tasks

Each PRD item should be small enough to complete in one context window. If a task is too big, the LLM runs out of context before finishing and produces poor code.

Right-sized stories:
- Add a database column and migration
- Add a UI component to an existing page
- Update a server action with new logic
- Add a filter dropdown to a list

Too big (split these):
- "Build the entire dashboard"
- "Add authentication"
- "Refactor the API"

### AGENTS.md Updates Are Critical

After each iteration, Ralph updates the relevant `AGENTS.md` files with learnings. This is key because AI coding tools automatically read these files, so future iterations (and future human developers) benefit from discovered patterns, gotchas, and conventions.

Examples of what to add to AGENTS.md:
- Patterns discovered ("this codebase uses X for Y")
- Gotchas ("do not forget to update Z when changing W")
- Useful context ("the settings panel is in component X")

### Feedback Loops

Ralph only works if there are feedback loops:
- Typecheck catches type errors
- Tests verify behavior
- CI must stay green (broken code compounds across iterations)

### Browser Verification for UI Stories

Frontend stories must include "Verify in browser using dev-browser skill" in acceptance criteria. Ralph will use the dev-browser skill to navigate to the page, interact with the UI, and confirm changes work.

### Stop Condition

When all stories have `passes: true`, Ralph outputs `<promise>COMPLETE</promise>` and the loop exits.

## Debugging

Check current state:

```bash
# See which stories are done
grep -E '"id"|"title"|"passes"' prd.json

# See learnings from previous iterations
cat progress.txt

# Check git history
git log --oneline -10

# List active worktrees
git worktree list
```

**Worktree tips:**

- Each worktree is at `.ralph/worktrees/<feature-name>/`
- `cd .ralph/worktrees/<name>` to inspect changes manually
- `git worktree remove .ralph/worktrees/<name>` to clean up
- `git worktree list` shows all active worktrees

## Merging

After Ralph completes in a worktree, review and merge:

1. Changes are in `.ralph/worktrees/<name>/` on the feature branch
2. Use the `/merge` skill to review diff and merge to main
3. After merge, clean up: `git worktree remove .ralph/worktrees/<name>/`

```
Load the merge skill and merge this branch to main
```

```
Load the merge skill and merge this branch to main
```

The skill works from any directory (main repo or worktree) and will:
1. Determine the feature branch from `prd.json` or git
2. Fetch latest main and show a change summary
3. Optionally launch `icdiff` for side-by-side diff review
4. Merge to main -- **resolving any conflicts automatically**
5. Push to origin (with confirmation)

### Side-by-side diff with icdiff (optional)

Install `icdiff` for a colorful side-by-side diff experience during merge review:

```bash
pip install icdiff
git config --global difftool.icdiff.cmd 'icdiff --line-numbers --no-bold "$LOCAL" "$REMOTE"'
git config --global difftool.prompt false
git config --global diff.tool icdiff
```

## Customizing the Prompt

After copying `prompt.md` (for Claude Code) to your project, customize it for your project:
- Add project-specific quality check commands
- Include codebase conventions
- Add common gotchas for your stack

## Archiving

Ralph automatically archives previous runs when you start a new feature (different `branchName`). Archives are saved to `archive/YYYY-MM-DD-feature-name/`.
