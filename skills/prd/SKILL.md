---
name: prd
description: "Generate a Product Requirements Document (PRD) for features or bug-fix plans. Use for planning features, fixing bugs in batches, or any structured development task. Triggers on: create a prd, write prd for, plan this feature, requirements for, spec out, fix bugs, bug fix plan, create fix plan, batch fix."
user-invocable: true
---

# PRD Generator

Create detailed Product Requirements Documents for features OR bug-fix plans. Each story can be a feature implementation or a bug fix — the format is the same, the intent differs.

---

## The Job

1. Receive a description from the user (feature or bug list)
2. Ask 3-5 essential clarifying questions (with lettered options)
3. Generate a structured PRD based on answers
4. Save to `tasks/prd-[name].md`

**Important:** Do NOT start implementing. Just create the PRD.

### Feature vs Bug-Fix PRDs

| Aspect | Feature PRD | Bug-Fix PRD |
|--------|------------|-------------|
| Story title | "Add priority field to database" | "Fix null pointer in login handler" |
| Description | "As a user, I want X so that Y" | "Bug: X happens when Y. Expected Z." |
| Acceptance criteria | "Button shows confirmation dialog" | "Bug no longer reproduces. Test X passes." |
| Commit prefix | `feat:` | `fix:` |
| Parallel tracks | backend / frontend | by component / file / bug ID |

Everything else (story structure, priority, passes tracking) is identical.

---

## Step 1: Clarifying Questions

Ask only critical questions where the initial prompt is ambiguous. Focus on:

- **Problem/Goal:** What problem does this solve?
- **Core Functionality:** What are the key actions?
- **Scope/Boundaries:** What should it NOT do?
- **Parallel Development:** Can stories be split into independent tracks for parallel AI execution?
- **Success Criteria:** How do we know it's done?

Always include this question when there are 3+ stories:

```
N. Can these be worked on in parallel?
   A. No, they all depend on each other (single branch)
   B. Yes, by component/module (e.g., backend + frontend for features, or by file for bugs)
   C. Yes, each story independently (one branch per story)
   D. Yes, I'll specify the grouping
```

If the user chooses B/C/D, each story gets a `track` annotation. For features, tracks are typically `backend`/`frontend`. For bugs, tracks are typically `bug-<id>` or by affected component. The `/ralph` skill will generate separate `prd-<track>.json` files.

### Format Questions Like This:

```
1. What is the primary goal of this feature?
   A. Improve user onboarding experience
   B. Increase user retention
   C. Reduce support burden
   D. Other: [please specify]

2. Who is the target user?
   A. New users only
   B. Existing users only
   C. All users
   D. Admin users only

3. What is the scope?
   A. Minimal viable version
   B. Full-featured implementation
   C. Just the backend/API
   D. Just the UI
```

This lets users respond with "1A, 2C, 3B" for quick iteration. Remember to indent the options.

---

## Step 2: PRD Structure

Generate the PRD with these sections:

### 1. Introduction/Overview
Brief description of the feature and the problem it solves.

### 2. Goals
Specific, measurable objectives (bullet list).

### 3. User Stories
Each story needs:
- **Title:** Short descriptive name
- **Track:** (if parallel) `backend`, `frontend`, or custom track name
- **Description:** "As a [user], I want [feature] so that [benefit]"
- **Acceptance Criteria:** Verifiable checklist of what "done" means

Each story should be small enough to implement in one focused session.

**Format (single track, no parallel):**
```markdown
### US-001: [Title]
**Description:** As a [user], I want [feature] so that [benefit].

**Acceptance Criteria:**
- [ ] Specific verifiable criterion
- [ ] Another criterion
- [ ] Typecheck/lint passes
- [ ] **[UI stories only]** Verify in browser using dev-browser skill
```

**Format (parallel tracks):**
```markdown
### US-001: [Title] `[track: backend]`
**Description:** As a [user], I want [feature] so that [benefit].

**Acceptance Criteria:**
- [ ] Specific verifiable criterion
- [ ] Typecheck/lint passes
```

**Important:** 
- Acceptance criteria must be verifiable, not vague. "Works correctly" is bad. "Button shows confirmation dialog before deleting" is good.
- **For any story with UI changes:** Always include "Verify in browser using dev-browser skill" as acceptance criteria. This ensures visual verification of frontend work.

### 4. Functional Requirements
Numbered list of specific functionalities:
- "FR-1: The system must allow users to..."
- "FR-2: When a user clicks X, the system must..."

Be explicit and unambiguous.

### 5. Non-Goals (Out of Scope)
What this feature will NOT include. Critical for managing scope.

### 6. Design Considerations (Optional)
- UI/UX requirements
- Link to mockups if available
- Relevant existing components to reuse

### 7. Technical Considerations (Optional)
- Known constraints or dependencies
- Integration points with existing systems
- Performance requirements

### 8. Success Metrics
How will success be measured?
- "Reduce time to complete X by 50%"
- "Increase conversion rate by 10%"

### 9. Open Questions
Remaining questions or areas needing clarification.

---

## Parallel Development Tracks

If the user chose parallel development, annotate each story with a track tag. The `/ralph` skill will generate separate `prd.json` files per track, and `ralph.sh` runs them in isolated worktrees.

### Track Rules

1. **Stories within a track MUST be sequential** (US-001 before US-002)
2. **Stories across different tracks MUST be independent** (no cross-track dependencies)
3. **Schema changes go first** within a track, then backend logic, then UI
4. **Track names** should be short: `backend`, `frontend`, `api`, `ui`, `db`, `infra`, etc.

### Example: Split by Backend/Frontend

```markdown
### US-001: Add priority field to database `[track: backend]`
...

### US-002: Create priority API endpoint `[track: backend]`
...

### US-003: Display priority badge on task cards `[track: frontend]`
...

### US-004: Add priority filter dropdown `[track: frontend]`
```

This produces:
- `prd-backend.json` → branch `ralph/task-priority-backend` (US-001, US-002)
- `prd-frontend.json` → branch `ralph/task-priority-frontend` (US-003, US-004)

The user then runs them in parallel:
```bash
./ralph.sh --prd prd-backend.json --tool claude &
./ralph.sh --prd prd-frontend.json --tool opencode &
```

### Important

- A story can only belong to ONE track
- If you can't cleanly split, it's better to use a single track than force a bad split
- Tell the user if certain stories must be merged in order (e.g., "merge backend first, then frontend")

---

## Writing for Junior Developers

The PRD reader may be a junior developer or AI agent. Therefore:

- Be explicit and unambiguous
- Avoid jargon or explain it
- Provide enough detail to understand purpose and core logic
- Number requirements for easy reference
- Use concrete examples where helpful

---

## Output

- **Format:** Markdown (`.md`)
- **Location:** `tasks/`
- **Filename:** `prd-[feature-name].md` (kebab-case)

---

## Example PRD

```markdown
# PRD: Task Priority System

## Introduction

Add priority levels to tasks so users can focus on what matters most. Tasks can be marked as high, medium, or low priority, with visual indicators and filtering to help users manage their workload effectively.

## Goals

- Allow assigning priority (high/medium/low) to any task
- Provide clear visual differentiation between priority levels
- Enable filtering and sorting by priority
- Default new tasks to medium priority

## User Stories

### US-001: Add priority field to database
**Description:** As a developer, I need to store task priority so it persists across sessions.

**Acceptance Criteria:**
- [ ] Add priority column to tasks table: 'high' | 'medium' | 'low' (default 'medium')
- [ ] Generate and run migration successfully
- [ ] Typecheck passes

### US-002: Display priority indicator on task cards
**Description:** As a user, I want to see task priority at a glance so I know what needs attention first.

**Acceptance Criteria:**
- [ ] Each task card shows colored priority badge (red=high, yellow=medium, gray=low)
- [ ] Priority visible without hovering or clicking
- [ ] Typecheck passes
- [ ] Verify in browser using dev-browser skill

### US-003: Add priority selector to task edit
**Description:** As a user, I want to change a task's priority when editing it.

**Acceptance Criteria:**
- [ ] Priority dropdown in task edit modal
- [ ] Shows current priority as selected
- [ ] Saves immediately on selection change
- [ ] Typecheck passes
- [ ] Verify in browser using dev-browser skill

### US-004: Filter tasks by priority
**Description:** As a user, I want to filter the task list to see only high-priority items when I'm focused.

**Acceptance Criteria:**
- [ ] Filter dropdown with options: All | High | Medium | Low
- [ ] Filter persists in URL params
- [ ] Empty state message when no tasks match filter
- [ ] Typecheck passes
- [ ] Verify in browser using dev-browser skill

## Functional Requirements

- FR-1: Add `priority` field to tasks table ('high' | 'medium' | 'low', default 'medium')
- FR-2: Display colored priority badge on each task card
- FR-3: Include priority selector in task edit modal
- FR-4: Add priority filter dropdown to task list header
- FR-5: Sort by priority within each status column (high to medium to low)

## Non-Goals

- No priority-based notifications or reminders
- No automatic priority assignment based on due date
- No priority inheritance for subtasks

## Technical Considerations

- Reuse existing badge component with color variants
- Filter state managed via URL search params
- Priority stored in database, not computed

## Success Metrics

- Users can change priority in under 2 clicks
- High-priority tasks immediately visible at top of lists
- No regression in task list performance

## Open Questions

- Should priority affect task ordering within a column?
- Should we add keyboard shortcuts for priority changes?
```

---

## Example: Bug-Fix PRD (Batch of 3)

```markdown
# PRD: Bugfix Batch 1 — Login & Dashboard

## Introduction

Fix 3 bugs from the backlog: null pointer on login, dashboard chart rendering, and session timeout handling.

## Goals

- Fix login crash when email field is empty (Bug #101)
- Fix dashboard chart showing wrong data on first load (Bug #102)
- Fix session not redirecting to login after timeout (Bug #103)
- All fixes pass existing tests + manual verification

## User Stories

### US-001: Fix null pointer in login handler `[track: bug-101]`
**Description:** Bug #101: Login throws NullPointerException when email field is empty. Expected: show validation error.

**Acceptance Criteria:**
- [ ] Empty email shows validation message instead of crash
- [ ] Existing login flow still works
- [ ] Typecheck passes
- [ ] Tests pass

### US-002: Fix dashboard chart initial render `[track: bug-102]`
**Description:** Bug #102: Dashboard chart shows empty data on first load. Data appears after manual refresh. Expected: data loads on initial render.

**Acceptance Criteria:**
- [ ] Chart renders with data on first load
- [ ] No manual refresh needed
- [ ] Typecheck passes
- [ ] Verify in browser using dev-browser skill

### US-003: Fix session timeout redirect `[track: bug-103]`
**Description:** Bug #103: After session timeout, API returns 401 but UI stays on page. Expected: redirect to login.

**Acceptance Criteria:**
- [ ] 401 response triggers redirect to /login
- [ ] Current page state is preserved in session storage
- [ ] Typecheck passes
- [ ] Tests pass

## Functional Requirements

- FR-1: Login form validates email before submission
- FR-2: Dashboard fetches data on component mount
- FR-3: HTTP interceptor redirects on 401

## Non-Goals

- Not refactoring the entire login module
- Not redesigning the dashboard

## Success Metrics

- All 3 bugs no longer reproduce
- No regression in existing test suite
```

**How to run (3 parallel fixes):**
```bash
/ralph → prd-bug-101.json, prd-bug-102.json, prd-bug-103.json

./ralph.sh --prd prd-bug-101.json --tool claude &
./ralph.sh --prd prd-bug-102.json --tool claude &
./ralph.sh --prd prd-bug-103.json --tool opencode &

# After all complete:
/merge  → auto-detects all 3 branches, merges in order
```

---

## Checklist

Before saving the PRD:

- [ ] Asked clarifying questions with lettered options (including parallel development)
- [ ] Incorporated user's answers
- [ ] If parallel: each story has a `[track: ...]` annotation
- [ ] If parallel: no cross-track dependencies between stories
- [ ] User stories are small and specific
- [ ] Functional requirements are numbered and unambiguous
- [ ] Non-goals section defines clear boundaries
- [ ] Saved to `tasks/prd-[feature-name].md`
