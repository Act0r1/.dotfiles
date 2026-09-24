---
description: Create a new pi slash command prompt template from a short description
argument-hint: "</command> <description>"
---
Create a new pi slash command prompt template.

User request:
$ARGUMENTS

Expected usage:
`/add /some_command <description>`

Rules:
- This adds a pi prompt template in `/home/yeager/.pi/agent/prompts/`.
- Do not inspect, modify, or reference `.claude`, `~/.claude`, Claude commands, or Claude skills.
- Do not modify project source code.
- Parse the first argument as the command name. It may start with `/`; strip the leading slash for the filename.
- The command name must become a safe prompt filename: lowercase, no leading slash, spaces changed to `-`, and only letters, numbers, `_`, and `-`.
- Use the remaining arguments as the short description/spec for what the new command should do.
- Expand the user’s short description into a clearer, more verbose command prompt with explicit steps, constraints, and output expectations.
- If a command with that filename already exists, read it first and ask before overwriting unless the user explicitly said to replace it.
- Include frontmatter with a concise `description` and, when useful, `argument-hint`.
- After writing the file, tell the user the new command path and remind them to run `/reload` if it does not appear immediately.

Implementation format:
Create `/home/yeager/.pi/agent/prompts/<command-name>.md` containing:

```markdown
---
description: <concise command description>
argument-hint: "[optional arguments]"
---
<verbose prompt that tells the agent exactly what to do when this slash command is used>
```

Now create the requested command.
