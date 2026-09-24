import argparse
import asyncio
import base64
import json
from pathlib import Path

from crawl4ai import AsyncWebCrawler, BrowserConfig, CacheMode, CrawlerRunConfig


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("url")
    action = parser.add_mutually_exclusive_group()
    action.add_argument("--c4a-file")
    action.add_argument("--js-file")
    parser.add_argument("--before-js-file")
    parser.add_argument("--wait-for")
    parser.add_argument("--wait-timeout", type=int, default=60000)
    parser.add_argument("--scan-full-page", action="store_true")
    parser.add_argument("--profile-path")
    parser.add_argument("--headful", action="store_true")
    parser.add_argument("--screenshot")
    parser.add_argument("--format", choices=["markdown", "json"], default="markdown")
    parser.add_argument("--output", required=True)
    return parser.parse_args()


def read_optional(path):
    if not path:
        return None
    return Path(path).expanduser().read_text(encoding="utf-8")


async def run(args):
    output = Path(args.output).expanduser()
    output.parent.mkdir(parents=True, exist_ok=True)
    browser_kwargs = {"headless": not args.headful}
    if args.profile_path:
        browser_kwargs.update(
            user_data_dir=str(Path(args.profile_path).expanduser()),
            use_managed_browser=True,
        )
    config = CrawlerRunConfig(
        c4a_script=read_optional(args.c4a_file),
        js_code=read_optional(args.js_file),
        js_code_before_wait=read_optional(args.before_js_file),
        wait_for=args.wait_for,
        wait_for_timeout=args.wait_timeout,
        scan_full_page=args.scan_full_page,
        screenshot=bool(args.screenshot),
        cache_mode=CacheMode.BYPASS,
    )
    async with AsyncWebCrawler(config=BrowserConfig(**browser_kwargs)) as crawler:
        result = await crawler.arun(args.url, config=config)
    if not result.success:
        raise RuntimeError(result.error_message)
    if args.format == "json":
        output.write_text(result.model_dump_json(indent=2), encoding="utf-8")
    else:
        output.write_text(result.markdown.raw_markdown, encoding="utf-8")
    if args.screenshot and result.screenshot:
        screenshot = result.screenshot
        if isinstance(screenshot, str) and "," in screenshot and screenshot.startswith("data:"):
            screenshot = screenshot.split(",", 1)[1]
        screenshot_path = Path(args.screenshot).expanduser()
        screenshot_path.parent.mkdir(parents=True, exist_ok=True)
        screenshot_path.write_bytes(base64.b64decode(screenshot))
    print(json.dumps({"output": str(output), "screenshot": args.screenshot}, ensure_ascii=False))


if __name__ == "__main__":
    asyncio.run(run(parse_args()))
