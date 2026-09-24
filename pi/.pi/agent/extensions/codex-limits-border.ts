import {
  CustomEditor,
  UserMessageComponent,
  type ExtensionAPI,
  type KeybindingsManager,
  type Theme,
} from "@earendil-works/pi-coding-agent";
import type { Component, EditorTheme, TUI } from "@earendil-works/pi-tui";
import { Key, matchesKey, truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";
import { readFile } from "node:fs/promises";
import { join } from "node:path";

interface CodexAuth {
  tokens?: {
    access_token?: string;
    account_id?: string;
  };
}

interface RateLimitWindow {
  used_percent: number;
  limit_window_seconds?: number | null;
  reset_at?: number | null;
}

interface RateLimit {
  primary_window?: RateLimitWindow;
  secondary_window?: RateLimitWindow;
}

interface AdditionalRateLimit extends RateLimit {
  limit_name?: string;
  rate_limit?: RateLimit | null;
}

interface CodexUsageResponse {
  rate_limit?: RateLimit | null;
  additional_rate_limits?: unknown;
}

interface LimitDisplay {
  label: string;
  leftPercent: number;
  resetsAt: Date;
}

interface LimitsDisplay {
  primary?: LimitDisplay;
  weekly: LimitDisplay;
}

interface LimitSnapshot {
  label: string;
  leftPercent: number;
  resetsAtMs: number;
}

interface LimitsSnapshot {
  primary?: LimitSnapshot;
  weekly: LimitSnapshot;
}

interface StatusLimitSnapshot {
  label: string;
  leftPercent: number;
  resetsAtMs?: number;
}

interface StatusEntryData {
  rows: StatusLimitSnapshot[];
}

interface FetchedLimits {
  editor?: LimitsDisplay;
  statusRows: StatusLimitSnapshot[];
}

const CODEX_HOME = process.env.CODEX_HOME || join(process.env.HOME || "", ".codex");
const AUTH_PATH = join(CODEX_HOME, "auth.json");
const USAGE_URL = "https://chatgpt.com/backend-api/wham/usage";
const REFRESH_INTERVAL_MS = 5 * 1000;
const FETCH_TIMEOUT_MS = 10 * 1000;
const DOUBLE_INTERRUPT_INTERVAL_MS = 1200;
const DOUBLE_LEFT_INTERVAL_MS = 500;
const BAR_WIDTH = 10;
const SNAPSHOT_ENTRY_TYPE = "codex-limits-snapshot";
const STATUS_ENTRY_TYPE = "codex-status";
const USER_MESSAGE_PATCHED = Symbol.for("pi.codex-limits-border.user-message-patched");
const USER_MESSAGE_PATCH_VERSION = Symbol.for("pi.codex-limits-border.user-message-patch-version");
const USER_MESSAGE_ORIGINAL_RENDER = Symbol.for("pi.codex-limits-border.user-message-original-render");
const USER_MESSAGE_LIMIT_RENDERER = Symbol.for("pi.codex-limits-border.user-message-limit-renderer");
const USER_MESSAGE_SNAPSHOT_QUEUE = Symbol.for("pi.codex-limits-border.user-message-snapshot-queue");
const USER_MESSAGE_ASSIGNED_SNAPSHOT = Symbol.for("pi.codex-limits-border.user-message-assigned-snapshot");

function fitBorder(
  left: string,
  right: string,
  width: number,
  border: (text: string) => string,
  fill: (text: string) => string = border,
): string {
  if (width <= 0) return "";
  if (width === 1) return border("─");

  let leftText = left;
  let rightText = right;
  const fixedWidth = 2;
  const minimumGap = 3;

  while (
    fixedWidth + visibleWidth(leftText) + visibleWidth(rightText) + minimumGap > width &&
    visibleWidth(leftText) > 0
  ) {
    leftText = truncateToWidth(leftText, Math.max(0, visibleWidth(leftText) - 1), "");
  }

  while (
    fixedWidth + visibleWidth(leftText) + visibleWidth(rightText) + minimumGap > width &&
    visibleWidth(rightText) > 0
  ) {
    rightText = truncateToWidth(rightText, Math.max(0, visibleWidth(rightText) - 1), "");
  }

  const gapWidth = Math.max(0, width - fixedWidth - visibleWidth(leftText) - visibleWidth(rightText));
  return `${border("─")}${leftText}${fill("─".repeat(gapWidth))}${rightText}${border("─")}`;
}

function rightAlignIntoLine(line: string, right: string, width: number): string {
  const rightWidth = visibleWidth(right);
  if (width <= 0 || rightWidth <= 0) return line;

  const baseWidth = Math.max(0, width - rightWidth - 1);
  const base = truncateToWidth(line, baseWidth, "");
  const pad = " ".repeat(Math.max(1, width - visibleWidth(base) - rightWidth));
  return truncateToWidth(`${base}${pad}${right}`, width, "");
}

function stripAnsi(value: string): string {
  return value.replace(/\x1b\[[0-?]*[ -/]*[@-~]/g, "");
}

function findBottomBorderIndex(lines: string[]): number {
  for (let index = lines.length - 1; index >= 0; index -= 1) {
    const plain = stripAnsi(lines[index] ?? "");
    if (/^─+$/.test(plain) || /^─── ↓ \d+ more ─*$/.test(plain)) return index;
  }
  return lines.length - 1;
}

function installUserMessagePatch() {
  const proto = UserMessageComponent.prototype as typeof UserMessageComponent.prototype & {
    [USER_MESSAGE_PATCHED]?: boolean;
    [USER_MESSAGE_PATCH_VERSION]?: number;
    [USER_MESSAGE_ORIGINAL_RENDER]?: (width: number) => string[];
    [USER_MESSAGE_LIMIT_RENDERER]?: (snapshot: LimitsSnapshot, width: number) => string | undefined;
    [USER_MESSAGE_SNAPSHOT_QUEUE]?: Array<LimitsSnapshot | undefined>;
  };

  if (proto[USER_MESSAGE_PATCHED] && proto[USER_MESSAGE_PATCH_VERSION] === 2) return proto;

  proto[USER_MESSAGE_ORIGINAL_RENDER] ??= proto.render;
  proto[USER_MESSAGE_SNAPSHOT_QUEUE] = [];
  proto.render = function (width: number): string[] {
    const lines = proto[USER_MESSAGE_ORIGINAL_RENDER]!.call(this, width);
    const instance = this as typeof this & { [USER_MESSAGE_ASSIGNED_SNAPSHOT]?: LimitsSnapshot | null };
    if (instance[USER_MESSAGE_ASSIGNED_SNAPSHOT] === undefined) {
      instance[USER_MESSAGE_ASSIGNED_SNAPSHOT] = proto[USER_MESSAGE_SNAPSHOT_QUEUE]?.shift() ?? null;
    }

    const snapshot = instance[USER_MESSAGE_ASSIGNED_SNAPSHOT];
    const renderLimits = proto[USER_MESSAGE_LIMIT_RENDERER];
    const right = snapshot ? renderLimits?.(snapshot, width) : undefined;
    if (!right || lines.length === 0) return lines;

    lines[lines.length - 1] = rightAlignIntoLine(lines[lines.length - 1]!, right, width);
    return lines;
  };
  proto[USER_MESSAGE_PATCHED] = true;
  proto[USER_MESSAGE_PATCH_VERSION] = 2;
  return proto;
}

function formatWindowLabel(windowSeconds: number): string {
  if (windowSeconds >= 604800) return "weekly";
  const hours = Math.round(windowSeconds / 3600);
  return `${hours}h`;
}

function formatReset(date: Date): string {
  const now = new Date();
  const hh = date.getHours().toString().padStart(2, "0");
  const mm = date.getMinutes().toString().padStart(2, "0");
  const time = `${hh}:${mm}`;

  if (
    date.getFullYear() === now.getFullYear() &&
    date.getMonth() === now.getMonth() &&
    date.getDate() === now.getDate()
  ) {
    return time;
  }

  const day = date.getDate();
  const month = date.toLocaleString(undefined, { month: "short" });
  return `${time} ${day} ${month}`;
}

function normalizeWindow(window: RateLimitWindow | undefined, fallbackLabel: string): LimitDisplay | undefined {
  if (!window || typeof window.used_percent !== "number" || typeof window.reset_at !== "number") return undefined;

  return {
    label: typeof window.limit_window_seconds === "number" ? formatWindowLabel(window.limit_window_seconds) : fallbackLabel,
    leftPercent: Math.max(0, Math.min(100, 100 - window.used_percent)),
    resetsAt: new Date(window.reset_at * 1000),
  };
}

function weeklyWindow(rateLimit: RateLimit | null | undefined): RateLimitWindow | undefined {
  const primary = rateLimit?.primary_window;
  const secondary = rateLimit?.secondary_window;
  const weeklySeconds = 6 * 24 * 60 * 60;

  if (typeof secondary?.limit_window_seconds === "number" && secondary.limit_window_seconds >= weeklySeconds) {
    return secondary;
  }
  if (typeof primary?.limit_window_seconds === "number" && primary.limit_window_seconds >= weeklySeconds) {
    return primary;
  }
  return secondary;
}

function statusSnapshot(label: string, window: RateLimitWindow | undefined): StatusLimitSnapshot | undefined {
  if (!window || typeof window.used_percent !== "number") return undefined;
  const resetAt = window.reset_at;
  const resetsAtMs =
    typeof resetAt === "number" && Number.isFinite(resetAt) && resetAt > 0 && resetAt < 10_000_000_000
      ? resetAt * 1000
      : undefined;
  return {
    label,
    leftPercent: Math.max(0, Math.min(100, 100 - window.used_percent)),
    resetsAtMs,
  };
}

function additionalRateLimits(value: unknown): AdditionalRateLimit[] {
  if (Array.isArray(value)) {
    return value.filter((item): item is AdditionalRateLimit => Boolean(item) && typeof item === "object");
  }
  if (!value || typeof value !== "object") return [];

  return Object.entries(value).flatMap(([name, item]) => {
    if (!item || typeof item !== "object") return [];
    const additional = item as AdditionalRateLimit;
    return [{ ...additional, limit_name: additional.limit_name ?? name }];
  });
}

function isSparkLimit(name: string): boolean {
  return /(?:^|[-_\s])spark(?:$|[-_\s])/i.test(name.trim());
}

function additionalLimitLabel(name: string): string {
  const base = name.trim().replace(/\s+weekly limit:?$/i, "");
  return `${base} Weekly limit`;
}

function formatStatusPercent(leftPercent: number): string {
  return `${Math.round(leftPercent)}%`;
}

function formatStatusReset(resetsAtMs: number | undefined): string {
  if (resetsAtMs === undefined) return "reset unknown";
  const date = new Date(resetsAtMs);
  const hours = date.getHours().toString().padStart(2, "0");
  const minutes = date.getMinutes().toString().padStart(2, "0");
  const month = date.toLocaleString("en-US", { month: "short" });
  return `resets ${hours}:${minutes} on ${date.getDate()} ${month}`;
}

class CodexStatusComponent implements Component {
  constructor(
    private readonly rows: StatusLimitSnapshot[],
    private readonly theme: Theme,
  ) {}

  render(width: number): string[] {
    if (width <= 0) return [];
    if (width < 4) return [this.theme.fg("borderMuted", "─".repeat(width))];

    const innerWidth = width - 2;
    const labels = this.rows.map((row) => `${row.label}:`);
    const labelWidth = Math.min(
      Math.max(...labels.map((label) => visibleWidth(label)), 0),
      Math.max(12, Math.floor(innerWidth * 0.42)),
    );
    const tailWidth = Math.max(
      ...this.rows.map((row) => visibleWidth(`] ${formatStatusPercent(row.leftPercent)} left (${formatStatusReset(row.resetsAtMs)})`)),
      0,
    );
    const barWidth = Math.max(4, Math.min(20, innerWidth - labelWidth - tailWidth - 4));
    const border = (text: string) => this.theme.fg("borderMuted", text);
    const fitRow = (content: string): string => {
      const fitted = truncateToWidth(content, innerWidth, "");
      return `${border("│")}${fitted}${" ".repeat(Math.max(0, innerWidth - visibleWidth(fitted)))}${border("│")}`;
    };

    const lines = [border(`╭${"─".repeat(innerWidth)}╮`)];
    for (const [index, row] of this.rows.entries()) {
      const fullCells = Math.max(0, Math.min(barWidth, Math.round((row.leftPercent / 100) * barWidth)));
      const emptyCells = barWidth - fullCells;
      const label = labels[index] ?? "";
      const labelPadding = " ".repeat(Math.max(0, labelWidth - visibleWidth(label)));
      const bar = [
        this.theme.fg("text", "█".repeat(fullCells)),
        this.theme.fg("dim", "░".repeat(emptyCells)),
      ].join("");
      const content = [
        "  ",
        this.theme.fg("muted", label),
        labelPadding,
        "[",
        bar,
        `] ${formatStatusPercent(row.leftPercent)} left `,
        this.theme.fg("dim", `(${formatStatusReset(row.resetsAtMs)})`),
      ].join("");
      lines.push(fitRow(content));
    }
    lines.push(border(`╰${"─".repeat(innerWidth)}╯`));
    return lines;
  }

  invalidate(): void {}
}

function snapshotLimits(value: LimitsDisplay | undefined): LimitsSnapshot | undefined {
  if (!value) return undefined;
  return {
    ...(value.primary
      ? {
          primary: {
            label: value.primary.label,
            leftPercent: value.primary.leftPercent,
            resetsAtMs: value.primary.resetsAt.getTime(),
          },
        }
      : {}),
    weekly: {
      label: value.weekly.label,
      leftPercent: value.weekly.leftPercent,
      resetsAtMs: value.weekly.resetsAt.getTime(),
    },
  };
}

function snapshotToDisplay(value: LimitsSnapshot): LimitsDisplay {
  return {
    ...(value.primary
      ? {
          primary: {
            label: value.primary.label,
            leftPercent: value.primary.leftPercent,
            resetsAt: new Date(value.primary.resetsAtMs),
          },
        }
      : {}),
    weekly: {
      label: value.weekly.label,
      leftPercent: value.weekly.leftPercent,
      resetsAt: new Date(value.weekly.resetsAtMs),
    },
  };
}

function getUserMessageTimestamp(message: unknown): number | undefined {
  if (!message || typeof message !== "object") return undefined;
  const msg = message as { timestamp?: unknown };
  return typeof msg.timestamp === "number" ? msg.timestamp : undefined;
}

function getUserMessageText(message: unknown): string {
  if (!message || typeof message !== "object") return "";
  const content = (message as { content?: unknown }).content;
  if (typeof content === "string") return content;
  if (!Array.isArray(content)) return "";
  return content
    .filter((item): item is { type: string; text: string } => {
      return Boolean(item) && typeof item === "object" && (item as { type?: unknown }).type === "text" && typeof (item as { text?: unknown }).text === "string";
    })
    .map((item) => item.text)
    .join("");
}

function isLimitsSnapshot(value: unknown): value is LimitsSnapshot {
  if (!value || typeof value !== "object") return false;
  const snapshot = value as { primary?: Partial<LimitSnapshot>; weekly?: Partial<LimitSnapshot> };
  const validPrimary =
    snapshot.primary === undefined ||
    (typeof snapshot.primary.label === "string" &&
      typeof snapshot.primary.leftPercent === "number" &&
      typeof snapshot.primary.resetsAtMs === "number");
  return (
    validPrimary &&
    typeof snapshot.weekly?.label === "string" &&
    typeof snapshot.weekly.leftPercent === "number" &&
    typeof snapshot.weekly.resetsAtMs === "number"
  );
}

function isStatusLimitSnapshot(value: unknown): value is StatusLimitSnapshot {
  if (!value || typeof value !== "object") return false;
  const row = value as Partial<StatusLimitSnapshot>;
  return (
    typeof row.label === "string" &&
    typeof row.leftPercent === "number" &&
    (row.resetsAtMs === undefined || typeof row.resetsAtMs === "number")
  );
}

async function fetchCodexLimits(): Promise<FetchedLimits | undefined> {
  const auth = JSON.parse(await readFile(AUTH_PATH, "utf8")) as CodexAuth;
  const accessToken = auth.tokens?.access_token;
  if (!accessToken) return undefined;

  const response = await fetch(USAGE_URL, {
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
      ...(auth.tokens?.account_id ? { "ChatGPT-Account-Id": auth.tokens.account_id } : {}),
    },
    signal: AbortSignal.timeout(FETCH_TIMEOUT_MS),
  });

  if (!response.ok) return undefined;

  const usage = (await response.json()) as CodexUsageResponse;
  const weeklyRateLimitWindow = weeklyWindow(usage.rate_limit);
  const primary =
    usage.rate_limit?.primary_window === weeklyRateLimitWindow
      ? undefined
      : normalizeWindow(usage.rate_limit?.primary_window, "5h");
  const weekly = normalizeWindow(weeklyRateLimitWindow, "weekly");
  const editor = weekly ? { ...(primary ? { primary } : {}), weekly } : undefined;
  const statusRows: StatusLimitSnapshot[] = [];
  const mainWeekly = statusSnapshot("Weekly limit", weeklyWindow(usage.rate_limit));
  if (mainWeekly) statusRows.push(mainWeekly);

  for (const additional of additionalRateLimits(usage.additional_rate_limits)) {
    const name = additional.limit_name?.trim();
    if (!name || !isSparkLimit(name)) continue;
    const row = statusSnapshot(
      additionalLimitLabel(name),
      weeklyWindow(additional.rate_limit ?? additional),
    );
    if (row) statusRows.push(row);
  }

  if (!editor && statusRows.length === 0) return undefined;
  return { editor, statusRows };
}

export default function (pi: ExtensionAPI) {
  const userMessageProto = installUserMessagePatch();
  let limits: LimitsDisplay | undefined;
  let statusRows: StatusLimitSnapshot[] = [];
  let refreshTimer: ReturnType<typeof setInterval> | undefined;
  let refreshPromise: Promise<void> | undefined;
  let activeTui: TUI | undefined;
  let limitsVisible = true;
  let queuedMessageAfterInterrupt: string | undefined;

  pi.events.on("statusline:codex-limits", (value) => {
    limitsVisible = value === true;
    activeTui?.requestRender();
  });

  const stopRefreshTimer = () => {
    if (refreshTimer) clearInterval(refreshTimer);
    refreshTimer = undefined;
  };

  const refreshLimits = (): Promise<void> => {
    if (refreshPromise) return refreshPromise;
    refreshPromise = (async () => {
      try {
        const nextLimits = await fetchCodexLimits();
        if (nextLimits?.editor) limits = nextLimits.editor;
        if (nextLimits) statusRows = nextLimits.statusRows;
      } catch {
      } finally {
        activeTui?.requestRender();
      }
    })().finally(() => {
      refreshPromise = undefined;
    });
    return refreshPromise;
  };

  pi.registerEntryRenderer(STATUS_ENTRY_TYPE, (entry, _options, theme) => {
    const data = entry.data as Partial<StatusEntryData> | undefined;
    const rows = Array.isArray(data?.rows) ? data.rows.filter(isStatusLimitSnapshot) : [];
    return new CodexStatusComponent(rows, theme);
  });

  pi.registerCommand("status", {
    description: "Show Codex weekly usage limits",
    handler: async (_args, ctx) => {
      if (ctx.mode !== "tui") {
        ctx.ui.notify("/status requires TUI mode", "error");
        return;
      }

      await refreshLimits();
      if (statusRows.length === 0) {
        ctx.ui.notify("Codex usage limits are unavailable", "error");
        return;
      }

      pi.appendEntry(STATUS_ENTRY_TYPE, {
        rows: statusRows.map((row) => ({ ...row })),
      } satisfies StatusEntryData);
    },
  });

  pi.on("session_start", (_event, ctx) => {
    if (ctx.mode !== "tui") return;

    const snapshotsByTimestamp = new Map<number, LimitsSnapshot>();
    for (const entry of ctx.sessionManager.getBranch()) {
      if (entry.type !== "custom" || entry.customType !== SNAPSHOT_ENTRY_TYPE) continue;
      const data = entry.data as { messageTimestamp?: unknown; limits?: unknown } | undefined;
      if (typeof data?.messageTimestamp === "number" && isLimitsSnapshot(data.limits)) {
        snapshotsByTimestamp.set(data.messageTimestamp, data.limits);
      }
    }

    userMessageProto[USER_MESSAGE_SNAPSHOT_QUEUE] = ctx.sessionManager
      .getBranch()
      .filter((entry) => entry.type === "message" && entry.message.role === "user")
      .map((entry) => {
        const timestamp = getUserMessageTimestamp(entry.message);
        return typeof timestamp === "number" ? snapshotsByTimestamp.get(timestamp) : undefined;
      });

    void refreshLimits();
    stopRefreshTimer();
    refreshTimer = setInterval(() => void refreshLimits(), REFRESH_INTERVAL_MS);

    const renderBar = (leftPercent: number): string => {
      const fullCells = Math.max(0, Math.min(BAR_WIDTH, Math.round((leftPercent / 100) * BAR_WIDTH)));
      const emptyCells = BAR_WIDTH - fullCells;
      return `${ctx.ui.theme.fg("text", "█".repeat(fullCells))}${ctx.ui.theme.fg("dim", "░".repeat(emptyCells))}`;
    };

    const renderLimit = (limit: LimitDisplay): string => {
      const theme = ctx.ui.theme;
      return [
        theme.fg("muted", `${limit.label} [`),
        renderBar(limit.leftPercent),
        theme.fg("muted", `] ${limit.leftPercent}% left`),
        theme.fg("dim", ` ${formatReset(limit.resetsAt)}`),
      ].join("");
    };

    const renderLimits = (snapshot?: LimitsSnapshot): string => {
      if (!limitsVisible) return "";
      const theme = ctx.ui.theme;
      const display = snapshot ? snapshotToDisplay(snapshot) : limits;
      if (!display) return theme.fg("dim", " limits … ");

      const renderedLimits = [display.primary ? renderLimit(display.primary) : undefined, renderLimit(display.weekly)].filter(
        (value): value is string => value !== undefined,
      );
      return ` ${renderedLimits.join(` ${theme.fg("dim", "·")} `)} `;
    };

    userMessageProto[USER_MESSAGE_LIMIT_RENDERER] = (snapshot) => renderLimits(snapshot);

    const promptHistory = ctx.sessionManager
      .getBranch()
      .filter((entry) => entry.type === "message" && entry.message.role === "user")
      .map((entry) => getUserMessageText(entry.message))
      .filter((text) => text.trim().length > 0);

    class CodexLimitsEditor extends CustomEditor {
      private lastInterruptEscapeAt = 0;
      private lastEmptyLeftAt = 0;
      private allTextSelected = false;
      private readonly appKeybindings: KeybindingsManager;

      constructor(tui: TUI, theme: EditorTheme, keybindings: KeybindingsManager) {
        super(tui, theme, keybindings, { paddingX: 0 });
        this.appKeybindings = keybindings;
        for (const prompt of promptHistory) this.addToHistory(prompt);
        activeTui = tui;
      }

      handleInput(data: string): void {
        if (matchesKey(data, Key.ctrl("a"))) {
          this.allTextSelected = this.getText().length > 0;
          this.tui.requestRender();
          return;
        }

        if (
          this.allTextSelected &&
          (matchesKey(data, Key.backspace) || matchesKey(data, Key.delete))
        ) {
          this.setText("");
          this.tui.requestRender();
          return;
        }

        this.allTextSelected = false;

        if (
          !ctx.isIdle() &&
          !this.isShowingAutocomplete() &&
          this.appKeybindings.matches(data, "app.interrupt")
        ) {
          const now = Date.now();

          if (now - this.lastInterruptEscapeAt < DOUBLE_INTERRUPT_INTERVAL_MS) {
            this.lastInterruptEscapeAt = 0;
            ctx.ui.setStatus("double-escape-interrupt", undefined);

            if (ctx.hasPendingMessages()) {
              const currentText = this.getText();
              super.handleInput(data);

              const restoredText = this.getText();
              const currentTextSuffix = currentText.trim() ? `\n\n${currentText}` : "";
              queuedMessageAfterInterrupt =
                currentTextSuffix && restoredText.endsWith(currentTextSuffix)
                  ? restoredText.slice(0, -currentTextSuffix.length)
                  : restoredText;
              this.setText(currentText);
            } else {
              super.handleInput(data);
            }
            return;
          }

          this.lastInterruptEscapeAt = now;
          ctx.ui.setStatus(
            "double-escape-interrupt",
            ctx.ui.theme.fg(
              "warning",
              ctx.hasPendingMessages()
                ? "Нажми Esc ещё раз, чтобы отправить ожидающее сообщение"
                : "Нажми Esc ещё раз для отмены",
            ),
          );
          return;
        }

        if (
          !this.isShowingAutocomplete() &&
          this.getText().length === 0 &&
          matchesKey(data, Key.left)
        ) {
          const now = Date.now();

          if (now - this.lastEmptyLeftAt < DOUBLE_LEFT_INTERVAL_MS) {
            this.lastEmptyLeftAt = 0;
            pi.events.emit("subagents:open");
            return;
          }

          this.lastEmptyLeftAt = now;
          ctx.ui.notify("Нажми ← ещё раз, чтобы открыть subagents", "info");
          return;
        }

        this.lastInterruptEscapeAt = 0;
        this.lastEmptyLeftAt = 0;
        ctx.ui.setStatus("double-escape-interrupt", undefined);

        const editor = this as any;
        const historyIndexBefore = editor.historyIndex;
        super.handleInput(data);

        if (
          (matchesKey(data, Key.up) || matchesKey(data, Key.down)) &&
          editor.historyIndex !== historyIndexBefore
        ) {
          const lines = editor.state?.lines as string[] | undefined;
          if (lines && lines.length > 0) {
            editor.state.cursorLine = lines.length - 1;
            editor.state.cursorCol = lines[lines.length - 1].length;
            editor.preferredVisualCol = null;
            editor.snappedFromCursorCol = null;
          }
        }
      }

      render(width: number): string[] {
        const lines = super.render(width);
        if (lines.length < 2) return lines;

        const right = renderLimits();
        const borderColor = (text: string) => this.borderColor(text);

        const bottomBorderIndex = findBottomBorderIndex(lines);
        lines[0] = fitBorder("", "", width, borderColor);
        lines[bottomBorderIndex] = fitBorder("", right, width, borderColor);

        if (this.allTextSelected) {
          for (let index = 1; index < bottomBorderIndex; index += 1) {
            const line = lines[index] ?? "";
            const withoutCursor = line.replace(/\x1b\[7m(.*?)\x1b\[0m/g, "$1");
            const content = withoutCursor.trimEnd();
            const selectedLength = Math.max(1, content.length);
            lines[index] = `\x1b[7m${withoutCursor.slice(0, selectedLength)}\x1b[0m${withoutCursor.slice(selectedLength)}`;
          }
        }

        return lines;
      }
    }

    ctx.ui.setEditorComponent((tui, theme, keybindings) => new CodexLimitsEditor(tui, theme, keybindings));
  });

  pi.on("message_start", (event) => {
    if (event.message.role !== "user") return;
    const snapshot = snapshotLimits(limits);
    if (!snapshot) return;

    const timestamp = getUserMessageTimestamp(event.message);
    userMessageProto[USER_MESSAGE_SNAPSHOT_QUEUE] ??= [];
    userMessageProto[USER_MESSAGE_SNAPSHOT_QUEUE].push(snapshot);

    pi.appendEntry(SNAPSHOT_ENTRY_TYPE, {
      messageTimestamp: timestamp,
      text: getUserMessageText(event.message),
      limits: snapshot,
    });
  });

  pi.on("agent_end", (_event, ctx) => {
    ctx.ui.setStatus("double-escape-interrupt", undefined);
    void refreshLimits();
  });

  pi.on("agent_settled", (_event, ctx) => {
    const message = queuedMessageAfterInterrupt?.trim();
    if (!message) return;

    queuedMessageAfterInterrupt = undefined;
    pi.sendUserMessage(message, ctx.isIdle() ? undefined : { deliverAs: "steer" });
  });

  pi.on("session_shutdown", () => {
    stopRefreshTimer();
    activeTui = undefined;
    queuedMessageAfterInterrupt = undefined;
    userMessageProto[USER_MESSAGE_LIMIT_RENDERER] = undefined;
    userMessageProto[USER_MESSAGE_SNAPSHOT_QUEUE] = [];
  });
}
