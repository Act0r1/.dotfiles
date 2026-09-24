import argparse
import asyncio
import json
from pathlib import Path

from crawl4ai import DomainMapper, DomainMapperConfig


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("domain")
    parser.add_argument("--source", default="sitemap+cc+crt+probe")
    parser.add_argument("--max-urls", type=int, default=500)
    parser.add_argument("--query")
    parser.add_argument("--score-threshold", type=float)
    parser.add_argument("--no-head", action="store_true")
    parser.add_argument("--no-subdomains", action="store_true")
    parser.add_argument("--hits-per-sec", type=int, default=10)
    parser.add_argument("--concurrency", type=int, default=50)
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--format", choices=["json", "urls"], default="json")
    parser.add_argument("--output", required=True)
    return parser.parse_args()


async def run(args):
    output = Path(args.output).expanduser()
    output.parent.mkdir(parents=True, exist_ok=True)
    config = DomainMapperConfig(
        source=args.source,
        max_urls=args.max_urls,
        concurrency=args.concurrency,
        hits_per_sec=args.hits_per_sec,
        force=args.force,
        extract_head=not args.no_head or bool(args.query),
        query=args.query,
        score_threshold=args.score_threshold,
        include_subdomains=not args.no_subdomains,
    )
    async with DomainMapper() as mapper:
        results = await mapper.scan(args.domain, config)
    if args.format == "urls":
        output.write_text("\n".join(item["url"] for item in results) + ("\n" if results else ""), encoding="utf-8")
    else:
        output.write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"output": str(output), "urls": len(results)}, ensure_ascii=False))


if __name__ == "__main__":
    asyncio.run(run(parse_args()))
