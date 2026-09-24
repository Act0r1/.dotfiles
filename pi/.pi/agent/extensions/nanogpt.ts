import type {
  ExtensionAPI,
  ProviderModelConfig,
} from "@earendil-works/pi-coding-agent";

type NanoGPTModel = {
  id: string;
  name?: string;
  context_length?: number;
  max_output_tokens?: number;
  architecture?: {
    input_modalities?: string[];
  };
  capabilities?: {
    reasoning?: boolean;
    vision?: boolean;
  };
  reasoning_efforts?: string[];
  pricing?: {
    prompt?: number;
    completion?: number;
    cacheReadInputPer1kTokens?: number;
    cacheWriteInputPer1kTokens?: number;
  };
};

type NanoGPTCatalog = {
  data?: NanoGPTModel[];
};

const CATALOG_URL = "https://nano-gpt.com/api/v1/models?detailed=true";

function finiteNumber(value: number | undefined, fallback: number): number {
  return typeof value === "number" && Number.isFinite(value) ? value : fallback;
}

function thinkingLevelMap(
  efforts: string[] | undefined,
): ProviderModelConfig["thinkingLevelMap"] | undefined {
  if (!efforts?.length) return undefined;

  const supported = new Set(efforts);
  const value = (level: string): string | null =>
    supported.has(level) ? level : null;

  return {
    off: supported.has("none") ? "none" : value("off"),
    minimal: value("minimal"),
    low: value("low"),
    medium: value("medium"),
    high: value("high"),
    xhigh: value("xhigh"),
    max: value("max"),
  };
}

function toPiModel(model: NanoGPTModel): ProviderModelConfig {
  const supportsImages =
    model.capabilities?.vision === true ||
    model.architecture?.input_modalities?.includes("image") === true;
  const reasoning = model.capabilities?.reasoning === true;
  const levels = reasoning ? thinkingLevelMap(model.reasoning_efforts) : undefined;

  return {
    id: model.id,
    name: model.name ?? model.id,
    reasoning,
    input: supportsImages ? ["text", "image"] : ["text"],
    contextWindow: finiteNumber(model.context_length, 128_000),
    maxTokens: finiteNumber(model.max_output_tokens, 16_384),
    cost: {
      input: finiteNumber(model.pricing?.prompt, 0),
      output: finiteNumber(model.pricing?.completion, 0),
      cacheRead:
        finiteNumber(model.pricing?.cacheReadInputPer1kTokens, 0) * 1_000,
      cacheWrite:
        finiteNumber(model.pricing?.cacheWriteInputPer1kTokens, 0) * 1_000,
    },
    ...(levels ? { thinkingLevelMap: levels } : {}),
  };
}

async function fetchModels(signal: AbortSignal): Promise<ProviderModelConfig[]> {
  const response = await fetch(CATALOG_URL, { signal });
  if (!response.ok) {
    throw new Error(`NanoGPT model catalog returned HTTP ${response.status}`);
  }

  const catalog = (await response.json()) as NanoGPTCatalog;
  if (!Array.isArray(catalog.data)) {
    throw new Error("NanoGPT model catalog has an invalid response shape");
  }

  const uniqueModels = new Map<string, ProviderModelConfig>();
  for (const model of catalog.data) {
    if (typeof model.id !== "string" || model.id.length === 0) continue;
    uniqueModels.set(model.id, toPiModel(model));
  }

  return [...uniqueModels.values()].sort((left, right) =>
    left.id.localeCompare(right.id),
  );
}

export default async function (pi: ExtensionAPI): Promise<void> {
  const models = await fetchModels(AbortSignal.timeout(15_000));

  pi.registerProvider("nanogpt", {
    name: "NanoGPT",
    baseUrl: "https://nano-gpt.com/api/v1",
    api: "openai-completions",
    apiKey: "$NANOGPT_API_KEY",
    models,
    refreshModels: ({ signal }) => fetchModels(signal),
  });
}
