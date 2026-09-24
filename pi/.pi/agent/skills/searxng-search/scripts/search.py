import argparse
import json
from pathlib import Path
from urllib.parse import urlencode
from urllib.request import Request, urlopen


PRIMARY_ENGINES = ["braveapi"]
FALLBACK_ENGINES = ["privacywall", "dogpile", "mwmbl", "searchmysite", "searchch", "gmx"]


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("query")
    parser.add_argument("--endpoint", default="http://127.0.0.1:8888")
    parser.add_argument("--limit", type=int, default=10)
    parser.add_argument("--category", action="append", default=[])
    parser.add_argument("--engine", action="append", default=[])
    parser.add_argument("--language", default="all")
    parser.add_argument("--time-range", choices=["day", "month", "year"])
    parser.add_argument("--safe-search", choices=[0, 1, 2], type=int, default=0)
    parser.add_argument("--format", choices=["json", "markdown", "urls"], default="json")
    parser.add_argument("--output", required=True)
    return parser.parse_args()


def normalized_result(item):
    return {
        "title": item.get("title"),
        "url": item.get("url"),
        "snippet": item.get("content"),
        "engine": item.get("engine"),
        "engines": item.get("engines"),
        "category": item.get("category"),
        "score": item.get("score"),
        "published_date": item.get("publishedDate"),
    }


def fetch(args, engines):
    params = {
        "q": args.query,
        "format": "json",
        "language": args.language,
        "safesearch": args.safe_search,
        "engines": ",".join(engines),
    }
    if args.category:
        params["categories"] = ",".join(args.category)
    if args.time_range:
        params["time_range"] = args.time_range
    url = f"{args.endpoint.rstrip('/')}/search?{urlencode(params)}"
    request = Request(url, headers={"Accept": "application/json", "User-Agent": "Pi-SearXNG/1.0"})
    with urlopen(request, timeout=60) as response:
        return json.load(response)


def run(args):
    engines = args.engine or PRIMARY_ENGINES
    payload = fetch(args, engines)
    if not args.engine and not payload.get("results"):
        engines = FALLBACK_ENGINES
        payload = fetch(args, engines)
    results = [normalized_result(item) for item in payload.get("results", [])[: args.limit]]
    output = Path(args.output).expanduser()
    output.parent.mkdir(parents=True, exist_ok=True)
    if args.format == "urls":
        output.write_text("\n".join(item["url"] for item in results if item["url"]) + ("\n" if results else ""), encoding="utf-8")
    elif args.format == "markdown":
        sections = [f"# Search: {args.query}"]
        for index, item in enumerate(results, 1):
            title = item["title"] or item["url"] or "Untitled"
            snippet = item["snippet"] or ""
            sections.append(f"## {index}. [{title}]({item['url']})\n\n{snippet}")
        output.write_text("\n\n".join(sections) + "\n", encoding="utf-8")
    else:
        data = {"query": args.query, "engines": engines, "number_of_results": payload.get("number_of_results"), "results": results}
        output.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"output": str(output), "results": len(results)}, ensure_ascii=False))


if __name__ == "__main__":
    run(parse_args())
