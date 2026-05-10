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

## Architecture

Ralph has two parts that live in different places:

| What | Where | Purpose |
|------|-------|---------|
| `ralph.sh`, `prompt.md` | **Your project** at `scripts/ralph/` | The runtime engine and AI instructions |
| `/prd`, `/ralph`, `/merge`, `/init` | **Claude config** at `~/.claude/skills/` | Skills that you invoke in Claude Code |

The skills (`/prd`, `/ralph`) create `prd.json` files in `scripts/ralph/`. Then `ralph.sh` reads them and runs the AI loop in an isolated worktree. The `/merge` skill merges results back to main.

### `.gitignore` Setup

Ralph creates git worktrees under `.ralph/`. Ensure your `.gitignore` has:

```gitignore
# AI agent worktrees and config (generated at runtime)
.ralph/
.claude/
```

`prd.json` and `progress.txt` should NOT be in the root `.gitignore` — they need to be committed inside worktrees (the AI force-adds them). If you run `/init`, it handles this automatically.

## Sequential Workflow (Single Feature)

### 1. Create a PRD

```
Load the prd skill and create a PRD for [your feature description]
```

Answer the clarifying questions (choose "A. No parallel" for single-branch). The skill saves to `tasks/prd-[feature-name].md`.

### 2. Convert to JSON

```
Load the ralph skill and convert tasks/prd-[feature-name].md to prd.json
```

This creates `scripts/ralph/prd.json`.

### 3. Run Ralph

```bash
# Claude Code is the default
./scripts/ralph/ralph.sh

# Or explicitly choose your tool
./scripts/ralph/ralph.sh --tool opencode --model opencode/big-pickle
```

Ralph creates a worktree, runs iterations, and exits when all stories pass. Default: 10 max iterations.

### 4. Merge

```
Load the merge skill and merge this branch to main
```

---

## Parallel Development: Full Walkthrough

This is the complete flow for running two AI instances simultaneously on independent story tracks.

### Step 1: Create a Tracked PRD

```
Load the prd skill and create a PRD for [feature]
```

When asked about parallel development, choose **B** (backend + frontend) or **C** (custom tracks). The skill annotates each story with `[track: backend]` or `[track: frontend]`.

Output: `tasks/prd-[feature-name].md`

### Step 2: Convert to Parallel JSON Files

```
Load the ralph skill and convert tasks/prd-[feature-name].md
```

The skill detects the `[track: ...]` annotations and generates:

```
scripts/ralph/
├── prd.json              # All stories (sequential fallback)
├── prd-backend.json      # US-001, US-002 → branch: ralph/<feature>-backend
├── prd-frontend.json     # US-003, US-004 → branch: ralph/<feature>-frontend
└── ...
```

Each `prd-<track>.json` has its own `branchName` and only its track's stories.

### Step 3: Run Both in Parallel

Open two terminals in your project root:

```bash
# Terminal 1: Claude Code handles backend (claude is default)
./scripts/ralph/ralph.sh --prd prd-backend.json

# Terminal 2: OpenCode handles frontend (at the same time!)
./scripts/ralph/ralph.sh --prd prd-frontend.json --tool opencode
```

What happens internally:
1. Each `ralph.sh` reads its PRD file → extracts `branchName`
2. Creates a git worktree: `.ralph/worktrees/<feature>-backend/` and `.ralph/worktrees/<feature>-frontend/`
3. Copies `prd-<track>.json` → worktree as `prd.json` (the AI reads this)
4. Copies `prompt.md` → worktree (AI instructions)
5. AI runs in the worktree: implements stories, marks `passes: true`, commits via `git add -f`
6. Each instance is fully isolated — different branches, different directories

You can check progress anytime:

```bash
git worktree list
# Shows both active worktrees

cd .ralph/worktrees/<feature>-backend
grep -E '"id"|"passes"' prd.json
```

### Step 4: Merge (One Command)

When all tracks are done (or as they finish), just say once:

```
Load the merge skill and merge
```

The skill automatically:
1. Detects ALL pending `ralph/*` branches (e.g., `ralph/feature-backend`, `ralph/feature-frontend`)
2. Shows a combined summary of every branch
3. Determines the correct merge order (backend → frontend)
4. Asks ONE confirmation for everything
5. Merges each branch in order, resolving any conflicts
6. Offers to push and clean up all worktrees at once

No need to run it per-branch. One merge command handles everything.

### Parallel Flow Diagram

```
tasks/prd-feature.md
        │
        ▼ /ralph
  ┌─────────────────┐
  │ prd-backend.json │──────► ralph.sh ──► .ralph/worktrees/<f>-backend/ ──► AI iterations ──┐
  │ prd-frontend.json│──────► ralph.sh ──► .ralph/worktrees/<f>-frontend/ ─► AI iterations ──┤
  └─────────────────┘         (parallel)                                                      │
        │                                                                                     │
        ▼                                                                                     ▼
      /merge ──► detects ALL branches ──► merges backend first, then frontend ──► main
                                                                                    │
                                                                                    ▼
                                                                            clean up all worktrees
```

---

## Bug Fixing: Batch Workflow

Ralph handles bug fixing just like features. Process bugs in batches, running regression between batches.

### Example: 20 bugs, 3 at a time

```
Bug backlog: #101 through #120

Batch 1 (3 bugs)     Batch 2 (5 bugs)     Batch 3 (5 bugs)    ...until done
    │                     │                     │
    ▼                     ▼                     ▼
  /prd → /ralph         /prd → /ralph         /prd → /ralph
    │                     │                     │
    ▼                     ▼                     ▼
  ralph.sh × 3          ralph.sh × 5          ralph.sh × N
  (parallel)            (parallel)            (parallel)
    │                     │                     │
    ▼                     ▼                     ▼
  /merge                /merge                /merge
    │                     │                     │
    ▼                     ▼                     ▼
  main ──► regression   main ──► regression    main → done!
```

### Batch 1 Walkthrough

**1. Create bug-fix PRD:**

```
Load the prd skill and create a fix plan for bugs #101, #102, #103
```

The skill asks clarifying questions. Choose **C** (each bug independently) for parallel fixing. Output: `tasks/prd-bugfix-batch1.md`

**2. Convert to JSON:**

```
Load the ralph skill and convert tasks/prd-bugfix-batch1.md
```

Generates `prd-bug-101.json`, `prd-bug-102.json`, `prd-bug-103.json` — one per bug, each with its own branch.

**3. Run in parallel:**

```bash
./scripts/ralph/ralph.sh --prd prd-bug-101.json --tool claude &
./scripts/ralph/ralph.sh --prd prd-bug-102.json --tool claude &
./scripts/ralph/ralph.sh --prd prd-bug-103.json --tool opencode &
```

Three worktrees, three branches, three AI instances fixing bugs simultaneously.

**4. Merge all at once:**

```
Load the merge skill and merge
```

Auto-detects all 3 `ralph/bugfix-batch1-*` branches, merges them in order.

**5. Run regression:**

```bash
# User runs their test suite on main
npm test
# Or: pytest, cargo test, go test, etc.
```

**6. Next batch:** If regression passes, repeat with bugs #104-#108 (or however many remain). Each batch creates from the latest main (which now includes previous fixes).

### Key Points for Bug Fixing

- **One bug per story**: Each story describes the bug, steps to reproduce, and expected fix
- **`fix:` commit prefix**: The AI uses `fix:` instead of `feat:` for bugfixes
- **Bug verification**: AI verifies the bug no longer reproduces before committing
- **Parallel by bug ID**: For independent bugs, use `[track: bug-<id>]` annotations
- **Regression between batches**: Always run your test suite after each merge before starting the next batch

---

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

After Ralph completes, use `/merge` to review and integrate:

```
Load the merge skill and merge this branch to main
```

The skill works from any directory (main repo or worktree):
1. Detects the feature branch from `prd.json` or git context
2. Fetches latest main and shows a change summary
3. Optionally launches `icdiff` for side-by-side diff review
4. Merges to main, **resolving conflicts automatically**
5. Offers to push and clean up the worktree

After merge, manually clean up remaining worktrees:

```bash
git worktree remove .ralph/worktrees/<name>/
```

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
