import {
  CustomEditor,
  type ExtensionAPI,
  type ExtensionContext,
  type KeybindingsManager,
} from "@earendil-works/pi-coding-agent";
import {
  Key,
  matchesKey,
  type EditorComponent,
  type EditorTheme,
  type TUI,
} from "@earendil-works/pi-tui";

const DOUBLE_ESC_WINDOW_MS = 500;
const IDLE_POLL_MS = 50;

const OURS = Symbol("esc-interrupt-editor");
type EditorFactory = (
  tui: TUI,
  theme: EditorTheme,
  keybindings: KeybindingsManager,
) => EditorComponent;
type TaggedFactory = EditorFactory & { [OURS]?: true };

interface EscHooks {
  isInterceptable: () => boolean;
  onFirstEsc: () => void;
  onDoubleEsc: () => void;
}

class DoubleEscEditor extends CustomEditor {
  private lastEscAt = 0;

  constructor(
    tui: TUI,
    theme: EditorTheme,
    keybindings: KeybindingsManager,
    private readonly hooks: EscHooks,
  ) {
    super(tui, theme, keybindings);
  }

  handleInput(data: string): void {
    if (
      matchesKey(data, Key.escape) &&
      this.hooks.isInterceptable() &&
      !this.isShowingAutocomplete()
    ) {
      const now = Date.now();
      if (now - this.lastEscAt < DOUBLE_ESC_WINDOW_MS) {
        this.lastEscAt = 0;
        this.hooks.onDoubleEsc();
        return;
      }
      this.lastEscAt = now;
      this.hooks.onFirstEsc();
      return;
    }
    this.lastEscAt = 0;
    super.handleInput(data);
  }
}

export default function escInterrupt(pi: ExtensionAPI): void {
  let busy = false;
  let interrupting = false;
  let lastCtx: ExtensionContext | undefined;

  pi.on("agent_start", (_event, ctx) => {
    busy = true;
    lastCtx = ctx;
  });

  pi.on("agent_settled", (_event, ctx) => {
    busy = false;
    lastCtx = ctx;
  });

  pi.on("session_start", (_event, ctx) => {
    lastCtx = ctx;
    const current = ctx.ui.getEditorComponent() as TaggedFactory | undefined;
    if (current && !current[OURS]) return;
    const factory: TaggedFactory = (tui, theme, keybindings) => {
      factory[OURS] = true;
      return new DoubleEscEditor(tui, theme, keybindings, {
        isInterceptable: () => busy,
        onFirstEsc: () => {
          lastCtx?.ui.notify("Busy — press esc again to interrupt", "info");
        },
        onDoubleEsc: () => {
          void interruptAndFlush();
        },
      });
    };
    factory[OURS] = true;
    ctx.ui.setEditorComponent(factory);
  });

  const interruptAndFlush = async (): Promise<void> => {
    const ctx = lastCtx;
    if (!ctx || interrupting) return;
    interrupting = true;
    try {
      const hadQueued = ctx.hasPendingMessages();
      ctx.abort();
      const restored = ctx.ui.getEditorText();
      while (!ctx.isIdle()) {
        await new Promise<void>((resolve) => setTimeout(resolve, IDLE_POLL_MS));
      }
      if (hadQueued && restored.trim() && ctx.isIdle()) {
        await pi.sendUserMessage(restored);
        if (ctx.ui.getEditorText() === restored) {
          ctx.ui.setEditorText("");
        }
      }
    } finally {
      interrupting = false;
    }
  };
}
