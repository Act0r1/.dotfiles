---
name: crawl4ai-extract
description: Extract structured JSON from known web pages locally with Crawl4AI using reusable CSS or XPath schemas, or LLM extraction when explicitly needed.
compatibility: Requires Crawl4AI 0.9.2 installed through the global uv tool; LLM extraction additionally requires a configured provider or local Ollama.
---

# Crawl4AI structured extraction

Prefer deterministic CSS or XPath schemas. Use LLM extraction only for irregular content or when the user explicitly requests semantic extraction.

## Output policy

Store schemas, configs, and generated data in `$HOME/.config/crawl4ai/outputs/`, never in the current project unless requested.

```bash
[ -d "$HOME/.config/crawl4ai/outputs" ] || mkdir -p "$HOME/.config/crawl4ai/outputs"
```

## CSS extraction

Create an extraction config:

```yaml
type: json-css
```

Create a schema:

```json
{
  "name": "items",
  "baseSelector": ".item",
  "fields": [
    {"name": "title", "selector": "h2", "type": "text"},
    {"name": "url", "selector": "a", "type": "attribute", "attribute": "href"}
  ]
}
```

Run extraction:

```bash
crwl crawl "https://example.com" \
  -e "$HOME/.config/crawl4ai/outputs/extract.yml" \
  -s "$HOME/.config/crawl4ai/outputs/schema.json" \
  -o json \
  -O "$HOME/.config/crawl4ai/outputs/items.json"
```

For XPath, set `type: json-xpath` and use `baseXPath`/`xpath` fields in the schema.

## LLM extraction

This can send page content to the configured model provider:

```bash
crwl crawl "https://example.com" \
  -j "Extract product names, prices, currencies, and availability" \
  -s "$HOME/.config/crawl4ai/outputs/product-schema.json" \
  -o json \
  -O "$HOME/.config/crawl4ai/outputs/products.json"
```

The first LLM invocation may prompt for provider configuration. Do not start it silently when credentials or data-sharing consent are unclear.

## Guidance

- Inspect page HTML before creating selectors.
- Generate a schema once and reuse it across pages with the same layout.
- Use `crawl4ai-interact` first if data appears only after clicks or scrolling.
- Validate extracted fields for missing or malformed values before relying on them.
