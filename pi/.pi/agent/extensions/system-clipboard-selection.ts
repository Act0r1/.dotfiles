import { copyToClipboard, type ExtensionAPI } from "@earendil-works/pi-coding-agent";
import type { TUI } from "@earendil-works/pi-tui";

const OSC52 = /^\x1b\]52;c;([A-Za-z0-9+/=]*)\x07$/;

type FullscreenTui = TUI & {
  readonly mode: "fullscreen";
  terminal: {
    write(data: string): void;
  };
  copySelectionToClipboard(): void;
  flash(message: string, durationMs?: number): void;
};

function isFullscreenTui(tui: TUI): tui is FullscreenTui {
  const candidate = tui as Partial<FullscreenTui>;
  return candidate.mode === "fullscreen"
    && typeof candidate.copySelectionToClipboard === "function"
    && typeof candidate.terminal?.write === "function";
}

export default function systemClipboardSelection(pi: ExtensionAPI) {
  pi.on("session_start", (_event, ctx) => {
    if (ctx.mode !== "tui") return;

    ctx.ui.setWidget("system-clipboard-selection", (tui) => {
      if (!isFullscreenTui(tui)) {
        return {
          render: () => [],
          invalidate: () => {},
        };
      }

      const originalCopy = tui.copySelectionToClipboard;
      const originalWrite = tui.terminal.write;

      tui.copySelectionToClipboard = () => {
        let payload: string | undefined;

        tui.terminal.write = (data: string) => {
          const match = OSC52.exec(data);
          if (match) {
            payload = match[1];
            return;
          }
          originalWrite.call(tui.terminal, data);
        };

        try {
          originalCopy.call(tui);
        } finally {
          tui.terminal.write = originalWrite;
        }

        if (payload === undefined) return;

        const text = Buffer.from(payload, "base64").toString("utf8");
        void copyToClipboard(text).catch(() => {
          originalWrite.call(tui.terminal, `\x1b]52;c;${payload}\x07`);
          tui.flash("Copy failed");
        });
      };

      return {
        render: () => [],
        invalidate: () => {},
        dispose: () => {
          tui.copySelectionToClipboard = originalCopy;
        },
      };
    });
  });
}
