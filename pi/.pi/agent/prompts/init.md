---
description: Inspect the current project and create/update AGENTS.md with project mechanisms
argument-hint: "[extra instructions]"
---
Initialize project context for future pi sessions by observing the current project and creating or updating `AGENTS.md` in the project root.

Extra instructions from the user, if any:
$ARGUMENTS

Rules:
- Work only in the current project and pi config context. Do not inspect or modify `.claude`, `~/.claude`, Claude skills, or unrelated external agent caches.
- Do not overwrite user instructions blindly. If `AGENTS.md` already exists, read it first, preserve explicit user preferences, and merge new project-specific findings.
- Keep the result concise but useful for coding agents.
- Do not run tests, builds, migrations, formatters, or services unless the user explicitly asked for verification. This command is documentation-only.
- Do not change application code.
- Do not include secrets or full secret values from `.env` files. Mention variable names only when useful.

Observation checklist:
1. Inspect repository shape with non-destructive commands (`pwd`, `ls`, `find`/`rg --files`, `git status --short`, recent git log if useful).
2. Read core project files: README/docs, package/build config, lockfiles, Docker/Compose, Makefile/justfile, CI config, env examples, source entrypoints, config modules, routing/API definitions, database models/migrations, services/jobs/clients.
3. Infer the project mechanisms:
   - Language/runtime and package manager
   - How to install/run locally
   - App entrypoint(s) and runtime services
   - Configuration/env variables and where they are loaded
   - Database/storage/queues/external services
   - API/routes/CLI/background jobs
   - Docker/deploy/CI flow
   - Code organization and naming conventions
   - Common commands that are safe to run
   - Files/directories that should not be touched or committed
4. Create/update root `AGENTS.md` with sections appropriate to the project. Prefer this structure when applicable:
   - Project Overview
   - Tech Stack
   - Repository Layout
   - Runtime / Entrypoints
   - Configuration
   - Data / External Services
   - Development Commands
   - Coding Conventions
   - Operational Notes
   - Agent Instructions
5. After writing, briefly summarize what was captured and where (`AGENTS.md`).

Write the final `AGENTS.md` for this repository now.
