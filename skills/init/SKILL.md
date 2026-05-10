---
name: init
description: "Initialize a git repository for an existing codebase. Analyzes all files to generate a smart .gitignore. Use when setting up version control for a project that isn't yet a git repo. Triggers on: init git, initialize repo, setup git, create git repo, start version control, git init this project."
user-invocable: true
---

# Git Repo Initializer

Initialize a git repository for an existing codebase with a smart, project-aware `.gitignore`.

---

## The Job

1. Ask user for branch name and remote preference
2. Scan every file in the project
3. Detect project type(s) and identify what should be ignored
4. Generate a tailored `.gitignore`
5. Review with user, flag uncertain files
6. Initialize repo and make initial commit

**CRITICAL:** Never ignore source code. When unsure, ASK.

---

## Step 1: Gather Information

Ask these questions (with defaults):

```
1. Default branch name? [main]

2. Remote repository?
   A. No remote (local only) ← default
   B. Yes, I'll provide the URL

3. Will you use Ralph (autonomous AI agent loop) with this project?
   A. No ← default
   B. Yes, I plan to use Ralph
   (If yes, Ralph-specific ignores will be scoped to scripts/ralph/)

4. Any files you already know should be ignored?
   (e.g., large datasets, credentials, generated files)
```

If the user chooses "Yes" for Ralph: later, after writing the main `.gitignore`, also create `scripts/ralph/.gitignore` (see Step 4).

Do NOT proceed until the user answers.

---

## Step 2: Scan and Classify Every File

Run this to see everything:

```bash
find . -maxdepth 1 -not -path './.git' -not -name '.git' | sort
find . -type f -not -path './.git/*' -not -path './node_modules/*' -not -path './.venv/*' -not -path './venv/*' | sort
```

Also check for hidden files:

```bash
ls -la
```

For every file and directory, classify its role. Read a sample of key files (first 20-30 lines) to understand what they are.

---

## Step 3: Detect Project Type(s)

Based on the files present, classify the project. A project can be multiple types.

| Clue | Project Type |
|------|-------------|
| `package.json` | Node.js / JavaScript / TypeScript |
| `tsconfig.json` | TypeScript |
| `vite.config.*` | Vite (frontend) |
| `next.config.*` | Next.js |
| `pyproject.toml`, `setup.py`, `setup.cfg` | Python |
| `requirements.txt`, `Pipfile` | Python |
| `Cargo.toml` | Rust |
| `go.mod` | Go |
| `Makefile`, `CMakeLists.txt` | C/C++ (possibly) |
| `*.c`, `*.cpp`, `*.h`, `*.hpp` | C/C++ |
| `pom.xml`, `build.gradle`, `build.gradle.kts` | Java / Kotlin |
| `*.java`, `*.kt` | Java / Kotlin |
| `Gemfile` | Ruby |
| `composer.json` | PHP |
| `Cargo.toml` | Rust |
| `Package.swift` | Swift |
| `*.ino` | Arduino / embedded |
| `*.v`, `*.vhd`, `*.sv` | FPGA / Verilog / VHDL |
| `*.kicad_pcb`, `*.kicad_sch`, `*.sch`, `*.brd` | KiCad / EDA |
| `Dockerfile`, `docker-compose.yml` | Docker support |
| `.github/workflows/` | GitHub Actions |
| `*.ipynb` | Jupyter notebooks |
| `*.tex` | LaTeX |

**If the project type is unclear:** tell the user what you found and ask.

---

## Step 4: Build the .gitignore

Start with these universal ignores, then add project-specific rules.

### Universal (always include):

```gitignore
# OS generated files
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db
desktop.ini

# Editor / IDE
.vscode/
.idea/
*.swp
*.swo
*~
\#*\#
.\#*

# AI agent worktrees and config (generated at runtime)
.ralph/
.claude/
```

### If user will use Ralph: create `scripts/ralph/.gitignore`

**CRITICAL:** Do NOT add `prd.json` or `progress.txt` to the ROOT `.gitignore`. These files must be committed inside worktrees (`.ralph/worktrees/`). Instead, scope them to `scripts/ralph/` where the templates live:

```bash
mkdir -p scripts/ralph
```

Create `scripts/ralph/.gitignore`:
```gitignore
# Ralph working files (templates — not the worktree copies)
prd.json
prd-*.json
progress.txt
.last-branch
archive/
```

Then tell the user:
```
Ralph setup:
  scripts/ralph/.gitignore — scoped ignores for Ralph template files
  .gitignore — ignores .ralph/ and .claude/ globally

The worktree copies of prd.json and progress.txt WILL be committed
to feature branches (they track story completion status).
```

### Python project adds:

```gitignore
# Bytecode
__pycache__/
*.py[cod]
*$py.class
*.so

# Distribution / packaging
dist/
build/
*.egg-info/
*.egg

# Virtual environments
.venv/
venv/
env/
.env/
ENV/

# Testing
.pytest_cache/
.coverage
htmlcov/
.tox/
.nox/

# Type checkers
.mypy_cache/
.ruff_cache/

# Jupyter
.ipynb_checkpoints/

# Environment (keep .env.example)
.env
.env.*
!.env.example
```

### Node.js / TypeScript project adds:

```gitignore
# Dependencies
node_modules/

# Build output
dist/
build/
.next/
out/
*.tsbuildinfo

# Package managers
.yarn/
.pnpm/
.npm/

# Testing
coverage/
.nyc_output/

# Environment (keep .env.example)
.env
.env.*
!.env.example
```

### Go project adds:

```gitignore
# Binaries
*.exe
*.exe~
*.dll
*.so
*.dylib
*.test
*.out

# Vendor
vendor/

# Go workspace
go.work
go.work.sum
```

### Rust project adds:

```gitignore
# Build output
target/
debug/
release/

# IDE (Rust-specific)
.rustfmt.toml  (only if generated, check first!)

*.rs.bk
*.rlib
```

### C/C++ project adds:

```gitignore
# Compiled output
*.o
*.obj
*.out
*.exe
*.a
*.lib
*.so
*.dylib
*.dll
*.lo
*.la

# Build directories
build/
cmake-build-*/
Makefile.in
aclocal.m4
autom4te.cache/
config.log
config.status
configure
```

### Java / Kotlin project adds:

```gitignore
# Build output
target/
build/
out/
*.class
*.jar
*.war
*.ear

# Gradle
.gradle/
gradle-app.setting
!gradle-wrapper.jar
!gradle-wrapper.properties

# Maven
.mvn/
```

### FPGA / Verilog / VHDL project adds:

```gitignore
# Simulation
*.vcd
*.lxt
*.lxt2
*.ghw
*.fst
*.wlf
*.wdb
transcript
vsim.wlf
modelsim.ini

# Synthesis / Implementation
*.dcp
*.bit
*.bin
*.mcs
*.prm
*.xpr
*.jou
*.log
*.rpt
*.runs/
*.sim/
*.cache/
*.hw/
*.ip/
*.bd/
xilinx/
vivado*
*.str

# Altera/Intel Quartus
*.qdf
*.qpf
*.qsf
db/
incremental_db/
output_files/
simulation/
*.summary
*.sld
PLLJ_PLLSPE_INFO.txt
```

### KiCad / EDA project adds:

```gitignore
# KiCad
*.kicad_sch-bak
*.kicad_pcb-bak
*.kicad_pro-bak
*.kicad_prl
fp-info-cache/
*.zip

# Gerbers
*.gbr
*.drl
*.gko
*.gbl
*.gbs
*.gbo
*.gto
*.gtp
*.gts

# General EDA
*.b#*
*.s#*
*.l#*
```

### Docker adds:

```gitignore
# Docker (ignore generated, keep Dockerfile)
docker-compose.override.yml
```

### LaTeX adds:

```gitignore
# LaTeX
*.aux
*.log
*.out
*.toc
*.synctex.gz
*.bbl
*.blg
*.lof
*.lot
*.fls
*.fdb_latexmk
*.xdv
*.nav
*.snm
*.vrb
```

### Always add (regardless of project type):

```gitignore
# Secrets / Credentials (CRITICAL)
*.pem
*.key
*.p12
*.pfx
*.jks
*.keystore
*.pem
*-private.pem
credentials.json
secrets.yml
secrets.yaml
service-account.json
.ssh/
id_rsa*
*.token

# Environment files (keep examples)
.env
.env.*
!.env.example
!.env.sample
!.env.template

# Logs
*.log
logs/
*.log.*

# Databases
*.db
*.sqlite
*.sqlite3
*.duckdb

# Archives (usually not source)
*.zip
*.tar.gz
*.tar
*.rar
*.7z
*.tgz

# Large data files (flag these!)
*.csv
*.parquet
*.feather
*.h5
*.hdf5
*.pkl
*.joblib
*.onnx
*.bin
*.weights
*.safetensors
```

**IMPORTANT:** If the project IS a data/ML project and these data files are the actual source, do NOT ignore them. Ask the user.

---

## Step 5: Flag Uncertain Files

Before finalizing, list files where you are unsure:

1. **Binary files** without clear source
2. **Large files** (>1MB) that might be data or might be source
3. **Files with uncommon extensions** you don't recognize
4. **Generated-looking filenames** that could be build artifacts
5. **Configuration files** that might contain secrets

For each uncertain file, tell the user what it looks like and ask: "Should this be ignored?"

Example:
```
Uncertain files found:
  - output.bin (2.3MB binary) — looks like a compiled artifact
  - data/chipscope.csv (500KB) — might be test data or source data
  - secrets/production.key — CREDENTIAL, definitely ignore

Let me know if any should be kept instead of ignored.
```

---

## Step 6: Review .gitignore

Show the complete proposed `.gitignore` to the user.

Also show what WILL be committed (first 30 files):

```bash
git status --short
```

Ask: "Does this look right? Any additions or removals?"

---

## Step 7: Initialize Repository

```bash
git init -b <branch-name>
```

Write the approved `.gitignore`.

```bash
git add .
git status
```

Show the user what's staged. Ask for final confirmation.

```bash
git commit -m "Initial commit"
```

If user provided a remote URL:

```bash
git remote add origin <url>
```

Do NOT push unless the user explicitly asks.

---

## Step 8: Summary

Report what was done:
- Branch name
- Total files tracked
- Project type(s) detected
- Key ignore rules applied
- Any files flagged for manual review
- Remote (if configured)

---

## Hard Rules

1. **NEVER ignore source code.** `.c`, `.h`, `.py`, `.js`, `.ts`, `.rs`, `.go`, `.java`, `.v`, `.vhd`, `.sv`, `.kicad_sch`, `.kicad_pcb`, `.ino`, etc. — these are ALWAYS tracked.
2. **ALWAYS ignore credentials.** Private keys, tokens, service account JSONs.
3. **When unsure, ASK.** A false positive (tracked junk) is annoying. A false negative (ignored source) is catastrophic.
4. **Look at file contents, not just names.** Read the first 20-30 lines of ambiguous files to determine their nature.
5. **`node_modules/` and similar dependency directories should NOT be scanned** — they can have tens of thousands of files and will waste context. Skip them.
6. **Large binary files:** flag them. They bloat the repo. Consider Git LFS if they must be tracked.
