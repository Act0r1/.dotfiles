import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

type Config = {
  active: boolean;
  supportedModels: string[];
};

const CONFIG_PATH = join(process.env.HOME || "", ".pi", "agent", "extensions", "openai-fast.json");
const DEFAULT_CONFIG: Config = {
  active: true,
  supportedModels: [
    "openai-codex/gpt-5.5",
    "openai-codex/gpt-5.4",
    "openai/gpt-5.5",
    "openai/gpt-5.4",
  ],
};

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function loadConfig(): Config {
  try {
    if (!existsSync(CONFIG_PATH)) return DEFAULT_CONFIG;
    const parsed = JSON.parse(readFileSync(CONFIG_PATH, "utf8")) as Partial<Config>;
    return {
      active: typeof parsed.active === "boolean" ? parsed.active : DEFAULT_CONFIG.active,
      supportedModels: Array.isArray(parsed.supportedModels)
        ? parsed.supportedModels.filter((model): model is string => typeof model === "string")
        : DEFAULT_CONFIG.supportedModels,
    };
  } catch {
    return DEFAULT_CONFIG;
  }
}

function saveConfig(config: Config) {
  mkdirSync(dirname(CONFIG_PATH), { recursive: true });
  writeFileSync(CONFIG_PATH, `${JSON.stringify(config, null, 2)}\n`, "utf8");
}

function modelKey(ctx: { model?: { provider?: string; id?: string } }): string | undefined {
  const provider = ctx.model?.provider;
  const id = ctx.model?.id;
  if (!provider || !id) return undefined;
  return `${provider}/${id}`;
}

function isEligible(ctx: { model?: { provider?: string; id?: string } }, config: Config): boolean {
  const key = modelKey(ctx);
  return key ? config.supportedModels.includes(key) : false;
}

function statusText(ctx: { model?: { provider?: string; id?: string } }, config: Config): string {
  const key = modelKey(ctx) ?? "no model";
  if (!config.active) return `Fast mode off (${key})`;
  if (!isEligible(ctx, config)) return `Fast mode on, inactive for ${key}`;
  return `Fast mode on (${key}, service_tier=priority)`;
}

export default function openaiFast(pi: ExtensionAPI) {
  let config = loadConfig();
  saveConfig(config);

  const updateStatus = (ctx: { ui?: { setStatus?: (key: string, value?: string) => void }; model?: { provider?: string; id?: string } }) => {
    ctx.ui?.setStatus?.("openai-fast", config.active && isEligible(ctx, config) ? "fast" : undefined);
  };

  pi.registerCommand("fast", {
    description: "Enable OpenAI GPT-5 fast mode via service_tier=priority",
    getArgumentCompletions: (prefix: string) => {
      const values = ["on", "off", "toggle", "status"];
      const items = values
        .filter((value) => value.startsWith(prefix.trim().toLowerCase()))
        .map((value) => ({ value, label: value }));
      return items.length > 0 ? items : null;
    },
    handler: async (args, ctx) => {
      const action = args.trim().toLowerCase();
      if (action === "" || action === "on") {
        config = { ...config, active: true };
        saveConfig(config);
      } else if (action === "off") {
        config = { ...config, active: false };
        saveConfig(config);
      } else if (action === "toggle") {
        config = { ...config, active: !config.active };
        saveConfig(config);
      } else if (action !== "status") {
        ctx.ui.notify("Usage: /fast [on|off|toggle|status]", "warning");
        return;
      }

      updateStatus(ctx);
      ctx.ui.notify(statusText(ctx, config), "info");
    },
  });

  pi.on("session_start", (_event, ctx) => {
    config = loadConfig();
    updateStatus(ctx);
  });

  pi.on("model_select", (_event, ctx) => {
    updateStatus(ctx);
  });

  pi.on("before_provider_request", (event, ctx) => {
    if (!config.active || !isEligible(ctx, config)) return undefined;
    if (!isRecord(event.payload)) return undefined;
    if ("service_tier" in event.payload) return undefined;
    if (typeof event.payload.model === "string" && event.payload.model !== ctx.model?.id) return undefined;
    return { ...event.payload, service_tier: "priority" };
  });
}
