import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { DynamicBorder, getSettingsListTheme } from "@earendil-works/pi-coding-agent";
import {
  Container,
  type SettingItem,
  SettingsList,
  Text,
  truncateToWidth,
  visibleWidth,
  type TUI,
} from "@earendil-works/pi-tui";
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { isAbsolute, relative, resolve, sep } from "node:path";
import { join } from "node:path";

type StatusLineOptions = {
  cwd: boolean;
  gitBranch: boolean;
  sessionName: boolean;
  inputTokens: boolean;
  outputTokens: boolean;
  cacheRead: boolean;
  cacheWrite: boolean;
  cacheHitRate: boolean;
  cost: boolean;
  contextUsage: boolean;
  provider: boolean;
  model: boolean;
  thinkingLevel: boolean;
  accessMode: boolean;
  codexLimits: boolean;
  extensionStatuses: boolean;
};

type StatusLineOptionId = keyof StatusLineOptions;

const CONFIG_PATH = join(homedir(), ".pi", "agent", "status-line.json");
const DEFAULT_OPTIONS: StatusLineOptions = {
  cwd: true,
  gitBranch: true,
  sessionName: true,
  inputTokens: false,
  outputTokens: false,
  cacheRead: false,
  cacheWrite: false,
  cacheHitRate: false,
  cost: false,
  contextUsage: false,
  provider: true,
  model: true,
  thinkingLevel: true,
  accessMode: true,
  codexLimits: true,
  extensionStatuses: true,
};

const OPTION_LABELS: Array<[StatusLineOptionId, string]> = [
  ["cwd", "Working directory"],
  ["gitBranch", "Git branch"],
  ["sessionName", "Session name"],
  ["inputTokens", "Input tokens"],
  ["outputTokens", "Output tokens"],
  ["cacheRead", "Cache read tokens"],
  ["cacheWrite", "Cache write tokens"],
  ["cacheHitRate", "Cache hit rate"],
  ["cost", "Cost"],
  ["contextUsage", "Context usage"],
  ["provider", "Provider"],
  ["model", "Model"],
  ["thinkingLevel", "Thinking level"],
  ["accessMode", "Mode"],
  ["codexLimits", "Limits"],
  ["extensionStatuses", "Other extension statuses"],
];

function loadOptions(): StatusLineOptions {
  if (!existsSync(CONFIG_PATH)) return { ...DEFAULT_OPTIONS };
  try {
    const saved = JSON.parse(readFileSync(CONFIG_PATH, "utf8")) as Partial<StatusLineOptions>;
    const options = { ...DEFAULT_OPTIONS };
    for (const [id] of OPTION_LABELS) {
      if (typeof saved[id] === "boolean") options[id] = saved[id];
    }
    return options;
  } catch {
    return { ...DEFAULT_OPTIONS };
  }
}

function saveOptions(options: StatusLineOptions): void {
  writeFileSync(CONFIG_PATH, `${JSON.stringify(options, null, 2)}\n`, "utf8");
}

function formatTokens(count: number): string {
  if (count < 1000) return count.toString();
  if (count < 10_000) return `${(count / 1000).toFixed(1)}k`;
  if (count < 1_000_000) return `${Math.round(count / 1000)}k`;
  if (count < 10_000_000) return `${(count / 1_000_000).toFixed(1)}M`;
  return `${Math.round(count / 1_000_000)}M`;
}

function formatCwd(cwd: string): string {
  const home = homedir();
  const resolvedCwd = resolve(cwd);
  const resolvedHome = resolve(home);
  const relativeToHome = relative(resolvedHome, resolvedCwd);
  const insideHome =
    relativeToHome === "" ||
    (relativeToHome !== ".." && !relativeToHome.startsWith(`..${sep}`) && !isAbsolute(relativeToHome));
  if (!insideHome) return cwd;
  return relativeToHome === "" ? "~" : `~${sep}${relativeToHome}`;
}

function sanitizeStatus(text: string): string {
  return text.replace(/[\r\n\t]/g, " ").replace(/ +/g, " ").trim();
}

function collectUsage(ctx: ExtensionContext) {
  const totals = {
    input: 0,
    output: 0,
    cacheRead: 0,
    cacheWrite: 0,
    cost: 0,
  };
  let latestCacheHitRate: number | undefined;

  const addUsage = (usage: {
    input?: number;
    output?: number;
    cacheRead?: number;
    cacheWrite?: number;
    cost?: { total?: number };
  }) => {
    totals.input += usage.input ?? 0;
    totals.output += usage.output ?? 0;
    totals.cacheRead += usage.cacheRead ?? 0;
    totals.cacheWrite += usage.cacheWrite ?? 0;
    totals.cost += usage.cost?.total ?? 0;
  };

  for (const entry of ctx.sessionManager.getEntries()) {
    if (entry.type === "message" && entry.message.role === "assistant") {
      addUsage(entry.message.usage);
      const promptTokens =
        entry.message.usage.input + entry.message.usage.cacheRead + entry.message.usage.cacheWrite;
      latestCacheHitRate =
        promptTokens > 0 ? (entry.message.usage.cacheRead / promptTokens) * 100 : undefined;
    } else if (entry.type === "message" && entry.message.role === "toolResult" && entry.message.usage) {
      addUsage(entry.message.usage);
    } else if ((entry.type === "branch_summary" || entry.type === "compaction") && entry.usage) {
      addUsage(entry.usage);
    }
  }

  return { totals, latestCacheHitRate };
}

export default function statusLineExtension(pi: ExtensionAPI): void {
  const options = loadOptions();
  let footerTui: TUI | undefined;

  const installFooter = (ctx: ExtensionContext) => {
    ctx.ui.setFooter((tui, theme, footerData) => {
      footerTui = tui;
      const unsubscribe = footerData.onBranchChange(() => tui.requestRender());

      return {
        dispose() {
          unsubscribe();
          if (footerTui === tui) footerTui = undefined;
        },
        invalidate() {},
        render(width: number): string[] {
          const lines: string[] = [];
          const locationParts: string[] = [];

          if (options.cwd) locationParts.push(formatCwd(ctx.sessionManager.getCwd()));
          if (options.gitBranch) {
            const branch = footerData.getGitBranch();
            if (branch) locationParts.push(options.cwd ? `(${branch})` : branch);
          }
          if (options.sessionName) {
            const name = ctx.sessionManager.getSessionName();
            if (name) locationParts.push(name);
          }
          if (locationParts.length > 0) {
            lines.push(
              truncateToWidth(
                theme.fg("dim", locationParts.join(" • ").replace(" • (", " (")),
                width,
                theme.fg("dim", "..."),
              ),
            );
          }

          const { totals, latestCacheHitRate } = collectUsage(ctx);
          const leftParts: string[] = [];
          if (options.inputTokens && totals.input) leftParts.push(`↑${formatTokens(totals.input)}`);
          if (options.outputTokens && totals.output) leftParts.push(`↓${formatTokens(totals.output)}`);
          if (options.cacheRead && totals.cacheRead) leftParts.push(`R${formatTokens(totals.cacheRead)}`);
          if (options.cacheWrite && totals.cacheWrite) leftParts.push(`W${formatTokens(totals.cacheWrite)}`);
          if (options.cacheHitRate && latestCacheHitRate !== undefined) {
            leftParts.push(`CH${latestCacheHitRate.toFixed(1)}%`);
          }
          if (options.cost && totals.cost) leftParts.push(`$${totals.cost.toFixed(3)}`);
          if (options.contextUsage) {
            const context = ctx.getContextUsage();
            const percent = context?.percent === null ? "?" : `${(context?.percent ?? 0).toFixed(1)}%`;
            const contextWindow = context?.contextWindow ?? ctx.model?.contextWindow ?? 0;
            const value = `${percent}/${formatTokens(contextWindow)}`;
            if ((context?.percent ?? 0) > 90) leftParts.push(theme.fg("error", value));
            else if ((context?.percent ?? 0) > 70) leftParts.push(theme.fg("warning", value));
            else leftParts.push(value);
          }

          const rightParts: string[] = [];
          if (options.provider && ctx.model && footerData.getAvailableProviderCount() > 1) {
            rightParts.push(`(${ctx.model.provider})`);
          }
          if (options.model) rightParts.push(ctx.model?.id ?? "no-model");
          if (options.thinkingLevel && ctx.model?.reasoning) {
            const thinking = pi.getThinkingLevel();
            rightParts.push(thinking === "off" ? "thinking off" : thinking);
          }

          const left = leftParts.join(" ");
          const right = rightParts.join(" • ");
          if (left || right) {
            const leftWidth = visibleWidth(left);
            const rightWidth = visibleWidth(right);
            let line: string;
            if (leftWidth + rightWidth + (left && right ? 2 : 0) <= width) {
              line = left + " ".repeat(Math.max(0, width - leftWidth - rightWidth)) + right;
            } else if (left) {
              const fittedLeft = truncateToWidth(left, width, "...");
              const available = Math.max(0, width - visibleWidth(fittedLeft) - 2);
              const fittedRight = truncateToWidth(right, available, "");
              line = fittedLeft + " ".repeat(Math.max(0, width - visibleWidth(fittedLeft) - visibleWidth(fittedRight))) + fittedRight;
            } else {
              line = " ".repeat(Math.max(0, width - Math.min(width, rightWidth))) + truncateToWidth(right, width, "");
            }
            lines.push(theme.fg("dim", line));
          }

          if (options.accessMode || options.extensionStatuses) {
            const statuses = Array.from(footerData.getExtensionStatuses().entries())
              .filter(([key]) => key === "access-mode" ? options.accessMode : options.extensionStatuses)
              .sort(([leftKey], [rightKey]) => leftKey.localeCompare(rightKey))
              .map(([, text]) => sanitizeStatus(text));
            if (statuses.length > 0) {
              lines.push(
                truncateToWidth(
                  statuses.join(theme.fg("dim", " · ")),
                  width,
                  theme.fg("dim", "..."),
                ),
              );
            }
          }

          return lines;
        },
      };
    });
  };

  pi.registerCommand("statusline", {
    description: "Configure status line",
    handler: async (_args, ctx) => {
      if (ctx.mode !== "tui") {
        ctx.ui.notify("/statusline requires TUI mode", "error");
        return;
      }

      await ctx.ui.custom<void>((tui, theme, _keybindings, done) => {
        const container = new Container();
        container.addChild(new DynamicBorder((text: string) => theme.fg("borderAccent", text)));
        container.addChild(new Text(theme.fg("accent", theme.bold(" Status line")), 0, 0));

        const items: SettingItem[] = OPTION_LABELS.map(([id, label]) => ({
          id,
          label,
          currentValue: options[id] ? "on" : "off",
          values: ["on", "off"],
        }));

        const settingsList = new SettingsList(
          items,
          Math.min(items.length, 11),
          getSettingsListTheme(),
          (id, value) => {
            options[id as StatusLineOptionId] = value === "on";
            saveOptions(options);
            if (id === "codexLimits") {
              pi.events.emit("statusline:codex-limits", options.codexLimits);
            }
            footerTui?.requestRender();
            tui.requestRender();
          },
          () => done(undefined),
          { enableSearch: true },
        );

        container.addChild(settingsList);
        container.addChild(new Text(theme.fg("dim", " ↑↓ / jk navigate  •  enter toggle  •  esc close"), 0, 0));
        container.addChild(new DynamicBorder((text: string) => theme.fg("borderAccent", text)));

        return {
          render: (width) => container.render(width),
          invalidate: () => container.invalidate(),
          handleInput: (data) => {
            const mappedData = data === "j" ? "\u001b[B" : data === "k" ? "\u001b[A" : data;
            settingsList.handleInput?.(mappedData);
            tui.requestRender();
          },
        };
      }, {
        overlay: true,
        overlayOptions: {
          anchor: "center",
          width: 58,
          minWidth: 44,
          maxHeight: 20,
          margin: 1,
        },
      });
    },
  });

  pi.on("session_start", (_event, ctx) => {
    pi.events.emit("statusline:codex-limits", options.codexLimits);
    if (ctx.mode === "tui") installFooter(ctx);
  });
}
