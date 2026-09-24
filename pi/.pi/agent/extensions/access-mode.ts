import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { DynamicBorder } from "@earendil-works/pi-coding-agent";
import { Container, SelectList, type SelectItem, Text } from "@earendil-works/pi-tui";
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

type AccessMode = "read-only" | "edit-files" | "full-access";

const CONFIG_PATH = join(homedir(), ".pi", "agent", "access-mode.json");
const READ_ONLY_TOOLS = new Set(["read", "grep", "find", "ls", "ask_user"]);
const EDIT_FILES_TOOLS = new Set([...READ_ONLY_TOOLS, "edit", "write"]);
const INTERACTIVE_TOOLS = new Set(["ask_user"]);

const MODES: Array<{
  id: AccessMode;
  label: string;
  description: string;
  status: string;
}> = [
  {
    id: "read-only",
    label: "Read only",
    description: "Read, search, and list files only",
    status: "mode: read only",
  },
  {
    id: "edit-files",
    label: "Edit files",
    description: "Read and edit files without shell access",
    status: "mode: edit files",
  },
  {
    id: "full-access",
    label: "Full access",
    description: "All non-interactive tools; works autonomously without questions",
    status: "mode: full access",
  },
];

function isAccessMode(value: unknown): value is AccessMode {
  return value === "read-only" || value === "edit-files" || value === "full-access";
}

function loadMode(): AccessMode {
  if (!existsSync(CONFIG_PATH)) return "full-access";
  try {
    const saved = JSON.parse(readFileSync(CONFIG_PATH, "utf8")) as { mode?: unknown };
    return isAccessMode(saved.mode) ? saved.mode : "full-access";
  } catch {
    return "full-access";
  }
}

function saveMode(mode: AccessMode): void {
  writeFileSync(CONFIG_PATH, `${JSON.stringify({ mode }, null, 2)}\n`, "utf8");
}

export default function accessModeExtension(pi: ExtensionAPI): void {
  let currentMode = loadMode();

  const applyMode = (ctx: ExtensionContext) => {
    const allTools = pi.getAllTools();
    const allowedTools =
      currentMode === "full-access"
        ? allTools.map((tool) => tool.name).filter((name) => !INTERACTIVE_TOOLS.has(name))
        : allTools
            .map((tool) => tool.name)
            .filter((name) =>
              currentMode === "read-only" ? READ_ONLY_TOOLS.has(name) : EDIT_FILES_TOOLS.has(name),
            );

    pi.setActiveTools(allowedTools);

    const mode = MODES.find((item) => item.id === currentMode)!;
    const color =
      currentMode === "read-only" ? "success" : currentMode === "edit-files" ? "warning" : "dim";
    ctx.ui.setStatus("access-mode", ctx.ui.theme.fg(color, mode.status));
  };

  pi.registerCommand("mode", {
    description: "Select model access mode",
    handler: async (_args, ctx) => {
      if (ctx.mode !== "tui") {
        ctx.ui.notify("/mode requires TUI mode", "error");
        return;
      }

      const items: SelectItem[] = MODES.map((mode) => ({
        value: mode.id,
        label: `${mode.id === currentMode ? "✓ " : "  "}${mode.label}`,
        description: mode.description,
      }));

      const selected = await ctx.ui.custom<AccessMode | null>(
        (tui, theme, _keybindings, done) => {
          const container = new Container();
          container.addChild(new DynamicBorder((text: string) => theme.fg("borderAccent", text)));
          container.addChild(new Text(theme.fg("accent", theme.bold(" Mode")), 0, 0));

          const list = new SelectList(items, MODES.length, {
            selectedPrefix: (text) => theme.fg("accent", text),
            selectedText: (text) => theme.fg("accent", text),
            description: (text) => theme.fg("muted", text),
            scrollInfo: (text) => theme.fg("dim", text),
            noMatch: (text) => theme.fg("warning", text),
          });
          list.onSelect = (item) => done(item.value as AccessMode);
          list.onCancel = () => done(null);
          container.addChild(list);
          container.addChild(new Text(theme.fg("dim", " ↑↓ / jk navigate  •  enter select  •  esc close"), 0, 0));
          container.addChild(new DynamicBorder((text: string) => theme.fg("borderAccent", text)));

          return {
            render: (width) => container.render(width),
            invalidate: () => container.invalidate(),
            handleInput: (data) => {
              const mappedData = data === "j" ? "\u001b[B" : data === "k" ? "\u001b[A" : data;
              list.handleInput(mappedData);
              tui.requestRender();
            },
          };
        },
        {
          overlay: true,
          overlayOptions: {
            anchor: "center",
            width: 64,
            minWidth: 48,
            maxHeight: 10,
            margin: 1,
          },
        },
      );

      if (!selected) return;
      currentMode = selected;
      saveMode(currentMode);
      applyMode(ctx);
      ctx.ui.notify(`Mode: ${MODES.find((mode) => mode.id === currentMode)!.label}`, "info");
    },
  });

  pi.on("before_agent_start", (event) => {
    if (currentMode !== "full-access") return;
    return {
      systemPrompt: `${event.systemPrompt}\n\nFull access mode is autonomous: never ask the user questions or request confirmations. Make reasonable decisions yourself and complete the task end-to-end.`,
    };
  });

  pi.on("session_start", (_event, ctx) => {
    applyMode(ctx);
  });
}
