Hi, my name in Insaf. I love Rust, Python and AI. I love to build. I focus on building complex things as simple as possible. I love reducing complexity when solving problems.



## Coding Preferences
- Keep it simple. Channel "yagni" unless told otherwise.
- Use types where it possible
- If think that idea that I said look unrellevant say it and give me proof.
- Be careful with destructive actions that are not explicitly requested by user.
- Tests are good. Use them. Test should be focused, not slop. 
- Don't comment every line. But feel free describing what functions do and keep them up to date after changing.


## Coding Preferences(Typescript)
- Use bun, when not specified other. Also these tool default: Tailwind, Convex, Vite, SolidJS
- `any` is enemy. Don't use them at all.


## Coding Preferences(Python)
- Not use `any`, also where it is possible not use `dict[str, Any | str]`
- Try to reduce amount of case when you using `__dict__` or another dunder methods whenever it is possible.


## Questions are read-only
- A question is a request for answer, not for changes.
- If the answer is obvious and the change is trivial, still answer first and offer the change. Ask before making it 


## Workflow Preferences
- Do not create or use git worktrees unless I explicitly ask for a worktree.
- Do not add code comments unless I explicitly ask for comments or documentation.
- Keep changes direct and minimal; do the requested work without extra process.
- If a skill or workflow suggests worktrees, tests, or extra documentation, skip that part unless I explicitly requested it.

## Delegation: subagents, workflows, ask_user

You have extra tools installed. Use them proactively:

- **Subagents** (`subagent_spawn`, `subagent_wait`, `subagent_check`, `subagent_list`, `subagent_cancel`): delegate self-contained side tasks to a background subagent instead of doing everything inline. Good uses: parallel research, running a long task while you keep working, isolated exploration of an unfamiliar area. Default harness: `pi`. For the `claude` harness, choose the Claude Code model freely per task instead of forcing one default; valid examples include `claude-opus-4-8`, `claude-opus-5`, `claude-sonnet-5`, and any other model or alias supported by the installed Claude Code. Choose reasoning effort independently. Give each subagent a fully self-contained prompt (paths, constraints, expected report); it cannot see this conversation or ask me questions. After spawning, keep doing useful work; results arrive automatically.
- **Workflows** (`workflow` tool): when a task benefits from fanning out across several isolated agents in ordered phases (per-file review, research fan-out, verify-then-synthesize), or when I say "ultracode", write a JS orchestration script with `phase()`/`agent()`/`parallel()`. A workflow `agent()` may use `harness: "claude"` and freely select a Claude Code model per task, or use the default pi harness. Always check `.ok` on agent results. Use `background: true` for long runs.
- **Multichoice questions** (`ask_user` tool): whenever you need a decision from me and the likely answers can be enumerated, ask via `ask_user` — I prefer picking from options over typing. Ask one question per call; follow-ups in subsequent calls.
- `/copy-all` copies the whole chat to my clipboard when I ask for it.
