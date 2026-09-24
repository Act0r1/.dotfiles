import { spawnSync } from "node:child_process";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import {
  Markdown,
  allocateImageId,
  calculateImageCellSize,
  encodeKitty,
  getCapabilities,
  getCellDimensions,
  getPngDimensions,
} from "@earendil-works/pi-tui";
import { mathjax } from "mathjax-full/js/mathjax.js";
import { TeX } from "mathjax-full/js/input/tex.js";
import { SVG } from "mathjax-full/js/output/svg.js";
import { liteAdaptor } from "mathjax-full/js/adaptors/liteAdaptor.js";
import { RegisterHTMLHandler } from "mathjax-full/js/handlers/html.js";
import { AllPackages } from "mathjax-full/js/input/tex/AllPackages.js";

const PATCH_KEY = Symbol.for("pi.latex-renderer.markdown-patch");
const INSTANCE_STATE = Symbol.for("pi.latex-renderer.instance-state");
const MAX_FORMULA_LENGTH = 8_000;
const MAX_CACHE_ENTRIES = 128;

type GraphicsMode = "direct" | null;
type FormulaImage = { base64: string; widthPx: number; heightPx: number };
type MarkdownInstance = {
  paddingX: number;
  [INSTANCE_STATE]?: Map<string, number>;
};
type RenderToken = (
  this: MarkdownInstance,
  token: { type?: string; raw?: string },
  width: number,
  nextTokenType?: string,
  styleContext?: unknown,
) => string[];
type PatchState = {
  owners: number;
  original: RenderToken;
  implementation: RenderToken;
};
type PatchablePrototype = {
  renderToken: RenderToken;
  [PATCH_KEY]?: PatchState;
};

const adaptor = liteAdaptor();
RegisterHTMLHandler(adaptor);
const tex = new TeX({ packages: AllPackages });
const svgOutput = new SVG({ fontCache: "none" });
const mathDocument = mathjax.document("", { InputJax: tex, OutputJax: svgOutput });
const imageCache = new Map<string, FormulaImage | null>();
let graphicsMode: GraphicsMode = detectGraphicsMode();
let foreground = "#e6edf3";

function detectGraphicsMode(): GraphicsMode {
  return getCapabilities().images === "kitty" ? "direct" : null;
}

function parseForeground(ansi: string): string {
  const match = ansi.match(/38;2;(\d+);(\d+);(\d+)/);
  if (!match) return "#e6edf3";
  return `#${match.slice(1).map((part) => Number(part).toString(16).padStart(2, "0")).join("")}`;
}

function extractDisplayFormula(raw: string): string | null {
  const text = raw.trim();
  let formula: string | undefined;
  if (text.startsWith("$$") && text.endsWith("$$") && text.length > 4) {
    formula = text.slice(2, -2).trim();
  } else if (text.startsWith("\\[") && text.endsWith("\\]") && text.length > 4) {
    formula = text.slice(2, -2).trim();
  }
  return formula && formula.length <= MAX_FORMULA_LENGTH ? formula : null;
}

function formulaToPng(formula: string): FormulaImage | null {
  const cacheKey = `${foreground}\0${formula}`;
  if (imageCache.has(cacheKey)) return imageCache.get(cacheKey)!;

  let result: FormulaImage | null = null;
  try {
    const node = mathDocument.convert(formula, { display: true });
    const markup = adaptor.outerHTML(node);
    const start = markup.indexOf("<svg");
    const end = markup.lastIndexOf("</svg>");
    if (start < 0 || end < 0) throw new Error("MathJax produced no SVG");

    const svg = markup
      .slice(start, end + 6)
      .replaceAll("currentColor", foreground)
      .replace("<svg ", `<svg color="${foreground}" `);
    const converted = spawnSync("rsvg-convert", ["--format", "png"], {
      input: svg,
      maxBuffer: 8 * 1024 * 1024,
      timeout: 2_000,
    });
    if (converted.status !== 0 || !converted.stdout?.length) throw new Error("SVG conversion failed");

    const base64 = converted.stdout.toString("base64");
    const dimensions = getPngDimensions(base64);
    if (!dimensions) throw new Error("Invalid PNG");
    result = { base64, ...dimensions };
  } catch {
    result = null;
  }

  if (imageCache.size >= MAX_CACHE_ENTRIES) imageCache.delete(imageCache.keys().next().value!);
  imageCache.set(cacheKey, result);
  return result;
}

function renderFormula(
  formula: string,
  availableWidth: number,
  paddingX: number,
  imageId: number,
): string[] | null {
  if (!graphicsMode) return null;
  const image = formulaToPng(formula);
  if (!image) return null;

  const cells = getCellDimensions();
  const naturalWidth = Math.max(1, Math.ceil(image.widthPx / cells.widthPx));
  const targetWidth = Math.max(1, Math.min(availableWidth, naturalWidth));
  const size = calculateImageCellSize(image, targetWidth, 18, cells);
  const sequence = encodeKitty(image.base64, {
    columns: size.columns,
    rows: size.rows,
    imageId,
    moveCursor: false,
  });

  const lines = [" ".repeat(Math.max(0, paddingX)) + sequence];
  for (let row = 1; row < size.rows; row++) lines.push("");
  return lines;
}

function renderDisplayToken(
  this: MarkdownInstance,
  token: { type?: string; raw?: string },
  width: number,
  nextTokenType?: string,
  styleContext?: unknown,
): string[] {
  const prototype = Markdown.prototype as unknown as PatchablePrototype;
  const state = prototype[PATCH_KEY]!;
  if (token.type !== "paragraph" || typeof token.raw !== "string") {
    return state.original.call(this, token, width, nextTokenType, styleContext);
  }

  const formula = extractDisplayFormula(token.raw);
  if (!formula) return state.original.call(this, token, width, nextTokenType, styleContext);

  const ids = this[INSTANCE_STATE] ?? new Map<string, number>();
  this[INSTANCE_STATE] = ids;
  let imageId = ids.get(formula);
  if (!imageId) {
    imageId = allocateImageId();
    ids.set(formula, imageId);
  }

  const lines = renderFormula(formula, width, this.paddingX, imageId);
  if (!lines) return state.original.call(this, token, width, nextTokenType, styleContext);
  if (nextTokenType && nextTokenType !== "space") lines.push("");
  return lines;
}

function installPatch(): () => void {
  const prototype = Markdown.prototype as unknown as PatchablePrototype;
  let state = prototype[PATCH_KEY];
  if (!state) {
    const original = prototype.renderToken;
    state = { owners: 0, original, implementation: renderDisplayToken };
    prototype[PATCH_KEY] = state;
    prototype.renderToken = function (...args) {
      return prototype[PATCH_KEY]!.implementation.apply(this, args);
    };
  } else {
    state.implementation = renderDisplayToken;
  }

  state.owners++;
  let released = false;
  return () => {
    if (released) return;
    released = true;
    const current = prototype[PATCH_KEY];
    if (!current) return;
    current.owners--;
    if (current.owners <= 0) {
      prototype.renderToken = current.original;
      delete prototype[PATCH_KEY];
    }
  };
}

export default function latexRenderer(pi: ExtensionAPI) {
  const uninstall = installPatch();

  pi.on("session_start", (_event, ctx) => {
    if (ctx.mode !== "tui") return;
    foreground = parseForeground(ctx.ui.theme.getFgAnsi("text"));
    graphicsMode = detectGraphicsMode();
    ctx.ui.setStatus("latex-renderer", undefined);
  });

  pi.on("before_agent_start", (event) => ({
    systemPrompt:
      event.systemPrompt
      + "\n\nTerminal math rendering:\n"
      + (graphicsMode
        ? "- Use Unicode for short inline mathematics.\n- Put complex display mathematics inside $$ delimiters so the terminal can render it.\n"
        : "- Render mathematics with readable Unicode text only, including complex formulas. Do not emit LaTeX delimiters or commands.\n")
      + "- Do not use \\[...\\] or raw LaTeX commands in prose.\n",
  }));

  pi.on("session_shutdown", () => {
    uninstall();
  });
}
