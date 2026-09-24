---
name: firecrawl-parse
description: Use when convert local documents into markdown.
allowed-tools:
  - Bash(firecrawl *)
  - Bash(npx firecrawl *)
---

# firecrawl parse

Turn a local document into clean markdown on disk. Supports **PDF, DOCX, DOC, ODT, RTF, XLSX, XLS, HTML/HTM/XHTML**.

## When to use

- You have a file on disk (not a URL) and want its text as markdown
- User drops a PDF/DOCX and asks what it says, or to summarize it
- Use `scrape` instead when the source is a URL

## Quick start

Use `$HOME/.config/firecrawl/.firecrawl/` for all Firecrawl file outputs. Do not run `mkdir` if it already exists; only create it when missing with `[ -d "$HOME/.config/firecrawl/.firecrawl" ] || mkdir -p "$HOME/.config/firecrawl/.firecrawl"`. Never create project-local `.firecrawl/`.

Always save to `$HOME/.config/firecrawl/.firecrawl/` with `-o` — parsed docs can be hundreds of KB and blow up context if streamed to stdout. Do not add Firecrawl outputs to project `.gitignore`; keep them outside projects.

```bash
# File → markdown
firecrawl parse ./paper.pdf -o $HOME/.config/firecrawl/.firecrawl/paper.md

# AI summary
firecrawl parse ./paper.pdf -S -o $HOME/.config/firecrawl/.firecrawl/paper-summary.md

# Ask a question about the doc
firecrawl parse ./paper.pdf -Q "What are the main conclusions?" \
  -o $HOME/.config/firecrawl/.firecrawl/paper-qa.md
```

Then `head`, `grep`, `rg` etc., or incrementally read the file - don't load the whole thing at once.

## Options

| Option                 | Description                             |
| ---------------------- | --------------------------------------- |
| `-S, --summary`        | AI-generated summary                    |
| `-Q, --query <prompt>` | Ask a question about the parsed content |
| `-o, --output <path>`  | Output file path — **always use this**  |
| `-f, --format <fmt>`   | `markdown` (default), `html`, `summary` |
| `--timeout <ms>`       | Timeout for the parse job               |
| `--timing`             | Show request duration                   |

## Tips

- Quote paths with spaces: `firecrawl parse "./My Doc.pdf" -o $HOME/.config/firecrawl/.firecrawl/mydoc.md`.
- Max upload size: **50 MB** per file.
- Credits: ~1 per PDF page; HTML is 1 flat.
- Check `$HOME/.config/firecrawl/.firecrawl/` before re-parsing the same file.
- To check your credit balance (recommended for batch processing and similar workflows), use the `firecrawl credit-usage` command.

## See also

- [firecrawl-scrape](../firecrawl-scrape/SKILL.md) — same idea for URLs
