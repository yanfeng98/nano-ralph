---
name: ralph
description: "Convert PRDs to prd.json format for the Ralph autonomous agent system. Use when you have an existing PRD and need to convert it to Ralph's JSON format. Triggers on: convert this prd, turn this into ralph format, create prd.json from this, ralph json."
user-invocable: true
---

# Ralph PRD Converter

Converts existing PRDs to the prd.json format that Ralph uses for autonomous execution.

---

## The Job

Take a PRD (markdown file or text) and convert it to `prd.json` file(s) in your ralph directory.

**If the PRD has parallel tracks** (stories annotated with `[track: ...]`), generate one `prd-<track>.json` per track, each with a distinct `branchName`. Otherwise generate a single `prd.json`.

---

## Output Format

### Single Track (no `[track: ...]` annotations)

```json
{
  "project": "[Project Name]",
  "branchName": "ralph/[feature-name-kebab-case]",
  "description": "[Feature description from PRD title/intro]",
  "userStories": [...]
}
```

Save as: `prd.json`

### Parallel Tracks (stories have `[track: ...]` annotations)

Generate one file per track:

**`prd-backend.json`:**
```json
{
  "project": "[Project Name]",
  "branchName": "ralph/[feature-name]-backend",
  "description": "[Feature description] - Backend track",
  "userStories": [
    // Only stories with [track: backend]
  ]
}
```

**`prd-frontend.json`:**
```json
{
  "project": "[Project Name]",
  "branchName": "ralph/[feature-name]-frontend",
  "description": "[Feature description] - Frontend track",
  "userStories": [
    // Only stories with [track: frontend]
  ]
}
```

**Rules for parallel PRDs:**
- Each track gets its own branch: `ralph/<feature>-<trackname>`
- Story IDs keep their original numbering (US-001, US-002, etc.)
- Priority resets to sequential within each track (1, 2, 3...)
- Each file is self-contained and can run independently
- Tell the user the run order: which tracks must merge first (e.g., "merge backend before frontend")

---

## Story Size: The Number One Rule

**Each story must be completable in ONE Ralph iteration (one context window).**

Ralph spawns a fresh Claude Code or OpenCode instance per iteration with no memory of previous work. If a story is too big, the LLM runs out of context before finishing and produces broken code.

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
"Typecheck passes"
```

For stories with testable logic, also include:
```
"Tests pass"
```

### For stories that change UI, also include:
```
"Verify in browser using dev-browser skill"
```

Frontend stories are NOT complete until visually verified. Ralph will use the dev-browser skill to navigate to the page, interact with the UI, and confirm changes work.

---

## Conversion Rules

### Single Track
1. **Each user story becomes one JSON entry**
2. **IDs**: Sequential (US-001, US-002, etc.)
3. **Priority**: Based on dependency order, then document order
4. **All stories**: `passes: false` and empty `notes`
5. **branchName**: Derive from feature name, kebab-case, prefixed with `ralph/`
6. **Always add**: "Typecheck passes" to every story's acceptance criteria

### Parallel Tracks
1. **Detect tracks**: Look for `[track: <name>]` in story titles
2. **Group stories** by track name
3. **Re-number priority** within each track (starting from 1)
4. **Keep original IDs** (US-001 stays US-001 even if it's #1 in its track)
5. **branchName**: `ralph/<feature>-<trackname>` per file
6. **One file per track**: `prd-<trackname>.json`
7. **No duplicate stories**: each story goes to exactly one track

### Single Track Output
Write to `prd.json` in the ralph directory (where `ralph.sh` lives, typically `scripts/ralph/`).

### Parallel Track Output
Write multiple files to the SAME ralph directory:
- `scripts/ralph/prd-<track1>.json`
- `scripts/ralph/prd-<track2>.json`
- ...

Also write `scripts/ralph/prd.json` (all stories, no tracks) as a sequential fallback.

The user runs each track with:
```bash
./scripts/ralph/ralph.sh --prd prd-<track>.json --tool claude
```

`ralph.sh` resolves relative `--prd` paths from its own directory, so `prd-backend.json` works from anywhere.

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

## Example: Single Track

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

**Output prd.json:**
```json
{
  "project": "TaskApp",
  "branchName": "ralph/task-status",
  "description": "Task Status Feature - Track task progress with status indicators",
  "userStories": [
    {
      "id": "US-001",
      "title": "Add status field to tasks table",
      "description": "As a developer, I need to store task status in the database.",
      "acceptanceCriteria": [
        "Add status column: 'pending' | 'in_progress' | 'done' (default 'pending')",
        "Generate and run migration successfully",
        "Typecheck passes"
      ],
      "priority": 1,
      "passes": false,
      "notes": ""
    },
    {
      "id": "US-002",
      "title": "Display status badge on task cards",
      "description": "As a user, I want to see task status at a glance.",
      "acceptanceCriteria": [
        "Each task card shows colored status badge",
        "Badge colors: gray=pending, blue=in_progress, green=done",
        "Typecheck passes",
        "Verify in browser using dev-browser skill"
      ],
      "priority": 2,
      "passes": false,
      "notes": ""
    }
  ]
}
```

## Example: Parallel Tracks

**Input PRD:**
```markdown
### US-001: Add status field to tasks table `[track: backend]`
### US-002: Create status update API `[track: backend]`
### US-003: Display status badge on task cards `[track: frontend]`
### US-004: Add status filter dropdown `[track: frontend]`
```

**Output prd-backend.json:**
```json
{
  "project": "TaskApp",
  "branchName": "ralph/task-status-backend",
  "description": "Task Status Feature - Backend track (API + database)",
  "userStories": [
    {
      "id": "US-001",
      "title": "Add status field to tasks table",
      "description": "As a developer, I need to store task status in the database.",
      "acceptanceCriteria": [
        "Add status column: 'pending' | 'in_progress' | 'done' (default 'pending')",
        "Generate and run migration successfully",
        "Typecheck passes"
      ],
      "priority": 1,
      "passes": false,
      "notes": ""
    },
    {
      "id": "US-002",
      "title": "Create status update API",
      "description": "As a developer, I need an API to update task status.",
      "acceptanceCriteria": [
        "PUT /api/tasks/:id/status accepts valid status values",
        "Returns updated task on success",
        "Typecheck passes"
      ],
      "priority": 2,
      "passes": false,
      "notes": ""
    }
  ]
}
```

**Output prd-frontend.json:**
```json
{
  "project": "TaskApp",
  "branchName": "ralph/task-status-frontend",
  "description": "Task Status Feature - Frontend track (UI components)",
  "userStories": [
    {
      "id": "US-003",
      "title": "Display status badge on task cards",
      "description": "As a user, I want to see task status at a glance.",
      "acceptanceCriteria": [
        "Each task card shows colored status badge",
        "Badge colors: gray=pending, blue=in_progress, green=done",
        "Typecheck passes",
        "Verify in browser using dev-browser skill"
      ],
      "priority": 1,
      "passes": false,
      "notes": ""
    },
    {
      "id": "US-004",
      "title": "Add status filter dropdown",
      "description": "As a user, I want to filter the list to see only certain statuses.",
      "acceptanceCriteria": [
        "Filter dropdown: All | Pending | In Progress | Done",
        "Filter persists in URL params",
        "Typecheck passes",
        "Verify in browser using dev-browser skill"
      ],
      "priority": 2,
      "passes": false,
      "notes": ""
    }
  ]
}
```

**How to run:**
```bash
# Start both in parallel
./scripts/ralph/ralph.sh --prd prd-backend.json --tool claude
./scripts/ralph/ralph.sh --prd prd-frontend.json --tool opencode

# After backend completes, merge it first (frontend may depend on API)
# Then merge frontend
```

---

## Archiving Previous Runs

Ralph now uses git worktrees (isolated directories under `.ralph/worktrees/`). Each parallel PRD gets its own worktree.

**Before writing new prd.json files, check for existing runs:**

1. Read current `prd*.json` files if they exist
2. Check `git worktree list` for active worktrees
3. If `branchName` differs from the new feature:
   - Create archive folder: `archive/YYYY-MM-DD-feature-name/`
   - Copy old `prd*.json` and `progress.txt` to archive
   - Warn user about active worktrees that need cleanup

**The ralph.sh script handles archiving automatically** when you run it.

---

## Checklist Before Saving

Before writing prd.json file(s), verify:

- [ ] **Previous run archived** (check for existing prd*.json + active worktrees)
- [ ] Each story is completable in one iteration (small enough)
- [ ] Stories are ordered by dependency (schema to backend to UI)
- [ ] Every story has "Typecheck passes" as criterion
- [ ] UI stories have "Verify in browser using dev-browser skill" as criterion
- [ ] Acceptance criteria are verifiable (not vague)
- [ ] No story depends on a later story

**If parallel tracks:**

- [ ] Each story is tagged with exactly ONE `[track: ...]` annotation
- [ ] No cross-track dependencies (track A story doesn't depend on track B)
- [ ] Each track's branchName is unique: `ralph/<feature>-<trackname>`
- [ ] One `prd-<track>.json` file per track
- [ ] User knows the merge order (which track merges first)
- [ ] Also generated a combined `prd.json` as fallback
