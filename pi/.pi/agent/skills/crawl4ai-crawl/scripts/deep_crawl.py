import argparse
import asyncio
import json
from pathlib import Path

from crawl4ai import AsyncWebCrawler, BrowserConfig, CacheMode, CrawlerRunConfig
from crawl4ai.content_scraping_strategy import LXMLWebScrapingStrategy
from crawl4ai.deep_crawling import (
    BFSDeepCrawlStrategy,
    BestFirstCrawlingStrategy,
    DFSDeepCrawlStrategy,
    FilterChain,
    KeywordRelevanceScorer,
    URLPatternFilter,
)


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("url")
    parser.add_argument("--strategy", choices=["bfs", "dfs", "best-first"], default="bfs")
    parser.add_argument("--max-depth", type=int, default=2)
    parser.add_argument("--max-pages", type=int, default=50)
    parser.add_argument("--include-pattern", action="append", default=[])
    parser.add_argument("--exclude-pattern", action="append", default=[])
    parser.add_argument("--keyword", action="append", default=[])
    parser.add_argument("--include-external", action="store_true")
    parser.add_argument("--ignore-robots", action="store_true")
    parser.add_argument("--format", choices=["markdown", "json"], default="markdown")
    parser.add_argument("--output", required=True)
    return parser.parse_args()


def build_strategy(args):
    filters = []
    if args.include_pattern:
        filters.append(URLPatternFilter(args.include_pattern))
    if args.exclude_pattern:
        filters.append(URLPatternFilter(args.exclude_pattern, reverse=True))
    kwargs = {
        "max_depth": args.max_depth,
        "max_pages": args.max_pages,
        "include_external": args.include_external,
        "filter_chain": FilterChain(filters),
    }
    if args.strategy == "dfs":
        return DFSDeepCrawlStrategy(**kwargs)
    if args.strategy == "best-first":
        if args.keyword:
            kwargs["url_scorer"] = KeywordRelevanceScorer(keywords=args.keyword)
        return BestFirstCrawlingStrategy(**kwargs)
    return BFSDeepCrawlStrategy(**kwargs)


async def run(args):
    output = Path(args.output).expanduser()
    output.parent.mkdir(parents=True, exist_ok=True)
    config = CrawlerRunConfig(
        deep_crawl_strategy=build_strategy(args),
        scraping_strategy=LXMLWebScrapingStrategy(),
        cache_mode=CacheMode.BYPASS,
        stream=False,
        check_robots_txt=not args.ignore_robots,
    )
    async with AsyncWebCrawler(config=BrowserConfig(headless=True)) as crawler:
        result_container = await crawler.arun(args.url, config=config)
    results = list(result_container)
    failed = [result for result in results if not result.success]
    if args.format == "json":
        data = [result.model_dump(mode="json") for result in results]
        output.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    else:
        sections = []
        for result in results:
            if result.success:
                sections.append(f"# {result.url}\n\n{result.markdown.raw_markdown}")
            else:
                sections.append(f"# {result.url}\n\nCrawl failed: {result.error_message}")
        output.write_text("\n\n---\n\n".join(sections), encoding="utf-8")
    print(json.dumps({"output": str(output), "pages": len(results), "failed": len(failed)}, ensure_ascii=False))


if __name__ == "__main__":
    asyncio.run(run(parse_args()))
