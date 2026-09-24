import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import {
  stripTerminalSequences,
  visibleWidth,
  type TUI,
  type TuiInputListenerResult,
} from "@earendil-works/pi-tui";

const ICON = "󰅀";
const MARKER = "\x1b_pi:scroll-to-bottom\x07";
const MOUSE_EVENT = /^\x1b\[<(\d+);(\d+);(\d+)([Mm])$/;

type FullscreenTui = TUI & {
  readonly mode: "fullscreen";
  readonly isFollowingOutput: boolean;
  previousScreen: string[];
  selectionAnchor?: unknown;
  selectionFocus?: unknown;
  selectionPressActive: boolean;
  pressedUrl?: string;
  selectionDragged: boolean;
  handleViewportInput(data: string): TuiInputListenerResult;
  scrollToBottom(): void;
  stopSelectionAutoScroll(): void;
};

function isFullscreenTui(tui: TUI): tui is FullscreenTui {
  const candidate = tui as Partial<FullscreenTui>;
  return candidate.mode === "fullscreen"
    && typeof candidate.scrollToBottom === "function"
    && typeof candidate.handleViewportInput === "function";
}

function isButtonPress(data: string): { x: number; y: number } | undefined {
  const match = MOUSE_EVENT.exec(data);
  if (!match || match[4] === "m") return undefined;

  const button = Number.parseInt(match[1]!, 10);
  if ((button & 32) !== 0 || (button & 3) !== 0) return undefined;

  return {
    x: Number.parseInt(match[2]!, 10) - 1,
    y: Number.parseInt(match[3]!, 10) - 1,
  };
}

function buttonBounds(line: string): { start: number; end: number } | undefined {
  const markerIndex = line.indexOf(MARKER);
  if (markerIndex < 0) return undefined;

  const start = visibleWidth(stripTerminalSequences(line.slice(0, markerIndex)));
  return { start, end: start + visibleWidth(` ${ICON} `) };
}

export default function scrollToBottom(pi: ExtensionAPI) {
  pi.on("session_start", (_event, ctx) => {
    if (ctx.mode !== "tui") return;

    ctx.ui.setWidget("scroll-to-bottom", (tui, theme) => {
      if (!isFullscreenTui(tui)) {
        return {
          render: () => [],
          invalidate: () => {},
        };
      }

      const prototype = Object.getPrototypeOf(tui) as {
        handleViewportInput(data: string): TuiInputListenerResult;
      };
      const originalHandleViewportInput = prototype.handleViewportInput;
      const handleViewportInput = (data: string): TuiInputListenerResult => {
        const press = isButtonPress(data);
        if (press) {
          const line = tui.previousScreen[press.y];
          const bounds = line ? buttonBounds(line) : undefined;
          if (bounds && press.x >= bounds.start && press.x < bounds.end) {
            tui.stopSelectionAutoScroll();
            tui.selectionPressActive = false;
            tui.selectionAnchor = undefined;
            tui.selectionFocus = undefined;
            tui.pressedUrl = undefined;
            tui.selectionDragged = false;
            tui.scrollToBottom();
            return { consume: true };
          }
        }

        return originalHandleViewportInput.call(tui, data);
      };

      tui.handleViewportInput = handleViewportInput;

      return {
        render: (width: number) => {
          if (tui.isFollowingOutput) return [];

          const label = ` ${ICON} `;
          const button = theme.bg("selectedBg", theme.fg("text", label));
          const leftPadding = Math.max(0, Math.floor((width - visibleWidth(label)) / 2));
          return [`${" ".repeat(leftPadding)}${MARKER}${button}`];
        },
        invalidate: () => {},
        dispose: () => {
          if (tui.mode === "fullscreen") {
            tui.handleViewportInput = originalHandleViewportInput;
          }
        },
      };
    });
  });
}
