/**
 * workflows: model-authored multi-agent orchestration.
 *
 * A `workflow` tool that runs a JavaScript orchestration script written inline
 * by the model. The script executes ordered phases, fanning work out to
 * isolated subagents:
 *
 *   export const meta = { name, description, phases: [{ title, detail? }] }
 *   phase(title)                                  // mark runtime phase progression
 *   await agent(prompt, { label?, phase?, schema?, harness?, model?, provider?, effort? })
 *   await parallel([() => agent(...), ...], { concurrency? })
 *   args                                          // parsed JSON args passed with the tool call
 *
 * `agent()` always resolves to `{ ok, output, structured?, error? }` — it
 * never throws into the script. Scripts branch on `ok` explicitly.
 *
 * Runs are blocking by default (live progress in the tool block). Pass
 * `background: true` to return immediately and get a follow-up message when
 * the run finishes. Run artifacts (script, args, statuses, result) are saved
 * under `~/.pi/agent/workflows/<runId>/` for inspection; result and bounded
 * transcripts use separate artifacts, and there is no resume.
 */

import { randomBytes } from "node:crypto";
import * as fs from "node:fs";
import * as path from "node:path";
import {
  getAgentDir,
  getMarkdownTheme,
  keyHint,
  type ExtensionAPI,
  type ExtensionContext,
} from "@earendil-works/pi-coding-agent";
import { Container, Markdown, Spacer, Text } from "@earendil-works/pi-tui";
import { Type, type Static } from "typebox";
import { setActivityStatus } from "../shared/activity-status.ts";
import { SubagentManager, type SubagentManagerShape } from "../subagents/src/manager.ts";
import type {
  BackendName,
  ReasoningEffort,
  SubagentSnapshot,
} from "../subagents/src/domain.ts";
import {
  createSubagentRuntime,
  runTool,
  type SubagentRuntime,
} from "../subagents/src/runtime.ts";
import { createWorkflowPersistence, persistWorkflowJson } from "./artifacts.ts";
import { RunController } from "./controller.ts";
import { sessionWorkflowRunIds, showWorkflowDashboard } from "./dashboard.ts";
import {
  extractMeta,
  prepareWorkflowScript,
  type WorkflowMeta,
} from "./meta.ts";
import {
  agentContext,
  aggregateUsage,
  countStates,
  emptyUsage,
  formatElapsed,
  formatUsage,
  phaseGroups,
  resultJson,
  stateSquare,
  statusColor,
  statusWord,
  SQUARE,
  type AgentRecord,
  type AgentUsage,
  type TranscriptEntry,
  type WorkflowDetails,
} from "./model.ts";
import {
  buildBackgroundWorkflowFollowUp,
  buildBackgroundWorkflowLaunchResult,
  buildWorkflowAgentPrompt,
  buildWorkflowResultMessage,
  WORKFLOW_PARAMETER_DESCRIPTIONS,
  WORKFLOW_PROMPT_GUIDELINES,
  WORKFLOW_PROMPT_SNIPPET,
  WORKFLOW_TOOL_DESCRIPTION,
} from "./prompt.ts";
import {
  createWorkflowResources,
  runAgent,
  type AgentOutcome,
  type ThinkingLevel,
  type WorkflowModel,
} from "./runner.ts";
import { runWorkflowSandbox } from "./sandbox.ts";
import {
  safeStringify,
  truncateUtf8,
  writeFileAtomic,
} from "./serialization.ts";

const PREVIEW_LENGTH = 200;
const EMIT_INTERVAL_MS = 120;

const THINKING_LEVELS = [
  "off",
  "minimal",
  "low",
  "medium",
  "high",
  "xhigh",
  "max",
] as const;

const WORKFLOW_HARNESSES = ["pi", "claude", "codex"] as const;

/** What `agent()` resolves to inside the script. */
interface ScriptAgentResult {
  ok: boolean;
  output: string;
  structured?: unknown;
  error?: string;
}

interface AgentCallOptions {
  label?: unknown;
  phase?: unknown;
  schema?: unknown;
  harness?: unknown;
  model?: unknown;
  provider?: unknown;
  effort?: unknown;
}

const WorkflowParams = Type.Object({
  script: Type.String({
    description: WORKFLOW_PARAMETER_DESCRIPTIONS.script,
  }),
  args: Type.Optional(
    Type.String({
      description: WORKFLOW_PARAMETER_DESCRIPTIONS.args,
    }),
  ),
  background: Type.Optional(
    Type.Boolean({
      description: WORKFLOW_PARAMETER_DESCRIPTIONS.background,
    }),
  ),
});

type WorkflowInput = Static<typeof WorkflowParams>;

function errorText(error: unknown): string {
  return (error instanceof Error ? error.message : String(error)).slice(
    0,
    16 * 1024,
  );
}

function harnessUsage(snapshot: SubagentSnapshot): AgentUsage {
  return {
    ...emptyUsage(),
    contextTokens: snapshot.usage.tokens,
    turns: snapshot.turns,
  };
}

function harnessTranscript(snapshot: SubagentSnapshot): TranscriptEntry[] {
  const transcript: TranscriptEntry[] = [];
  for (const item of snapshot.transcript) {
    if (item.kind === "user") {
      transcript.push({
        role: "user",
        text: truncateUtf8(item.text, 16 * 1024),
      });
      continue;
    }
    if (item.kind === "toolResult") {
      transcript.push({
        role: "toolResult",
        name: item.name,
        toolCallId: item.toolId,
        text: truncateUtf8(item.outputPreview ?? "", 16 * 1024),
        isError: item.isError,
      });
      continue;
    }
    for (const part of item.parts) {
      if (part.type === "text" && part.text.trim()) {
        transcript.push({
          role: "assistant",
          text: truncateUtf8(part.text, 16 * 1024),
        });
      } else if (part.type === "thinking" && part.text.trim()) {
        transcript.push({
          role: "thinking",
          text: truncateUtf8(part.text, 16 * 1024),
        });
      } else if (part.type === "toolCall") {
        transcript.push({
          role: "tool",
          name: part.name,
          toolCallId: part.toolId,
          text: truncateUtf8(part.argsPreview ?? "", 16 * 1024),
        });
      }
    }
  }
  return transcript.slice(-200);
}

interface HarnessAgentOptions {
  manager: SubagentManagerShape;
  runtime: SubagentRuntime;
  harness: Exclude<BackendName, "pi">;
  prompt: string;
  label: string;
  model?: string;
  effort?: ReasoningEffort;
  schema?: unknown;
  cwd: string;
  projectTrusted: boolean;
  signal?: AbortSignal;
  onProgress?: (outcome: {
    preview: string;
    usage: AgentUsage;
    model?: string;
    contextWindow?: number;
    transcript: TranscriptEntry[];
  }) => void;
}

async function runHarnessAgent(
  options: HarnessAgentOptions,
): Promise<AgentOutcome> {
  if (
    options.schema !== undefined &&
    (options.harness !== "claude" ||
      !options.schema ||
      typeof options.schema !== "object" ||
      Array.isArray(options.schema))
  ) {
    return {
      ok: false,
      output: "",
      error:
        options.harness === "claude"
          ? "Claude Code structured output requires a JSON Schema object."
          : `Structured output is not supported by the ${options.harness} workflow harness.`,
      aborted: false,
      usage: emptyUsage(),
      model: options.model,
      transcript: [],
    };
  }

  const spawned = await runTool(
    options.runtime,
    options.manager.spawn(options.harness, {
      prompt: options.prompt,
      title: options.label,
      cwd: options.cwd,
      ...(options.model ? { model: options.model } : {}),
      ...(options.effort ? { reasoningEffort: options.effort } : {}),
      ...(options.schema
        ? { outputSchema: options.schema as Record<string, unknown> }
        : {}),
      parent: {
        parentCwd: options.cwd,
        projectTrusted: options.projectTrusted,
      },
    }),
  );

  const progress = () => {
    const snapshot = options.manager.view.get(spawned.id);
    if (!snapshot) return;
    options.onProgress?.({
      preview: snapshot.liveAssistant?.text || snapshot.finalText,
      usage: harnessUsage(snapshot),
      model: snapshot.meta.modelLabel ?? options.model,
      contextWindow:
        snapshot.usage.contextWindow ?? snapshot.meta.contextWindow,
      transcript: harnessTranscript(snapshot),
    });
  };
  const unsubscribe = options.manager.view.subscribeTo(spawned.id, progress);
  progress();

  let aborted = false;
  try {
    await runTool(
      options.runtime,
      options.manager.waitFor([spawned.id]),
      {
        signal: options.signal,
        interruptMessage: "Agent was aborted",
      },
    );
  } catch (error) {
    if (!options.signal?.aborted) throw error;
    aborted = true;
    await options.runtime
      .runPromise(options.manager.cancel([spawned.id]))
      .catch(() => {});
  } finally {
    unsubscribe();
  }

  const snapshot = options.manager.view.get(spawned.id) ?? spawned;
  const output = truncateUtf8(snapshot.finalText, 64 * 1024);
  const usage = harnessUsage(snapshot);
  const transcript = harnessTranscript(snapshot);
  const model = snapshot.meta.modelLabel ?? options.model;
  const contextWindow =
    snapshot.usage.contextWindow ?? snapshot.meta.contextWindow;

  if (aborted) {
    return {
      ok: false,
      output,
      error: "Agent was aborted",
      aborted: true,
      usage,
      model,
      contextWindow,
      transcript,
    };
  }
  if (snapshot.status !== "done") {
    return {
      ok: false,
      output,
      error: snapshot.errorText ?? "Agent failed",
      aborted: false,
      usage,
      model,
      contextWindow,
      transcript,
    };
  }
  if (options.schema !== undefined && snapshot.structured === undefined) {
    return {
      ok: false,
      output,
      error:
        "Agent finished without producing structured output matching the schema.",
      aborted: false,
      usage,
      model,
      contextWindow,
      transcript,
    };
  }
  return {
    ok: true,
    output,
    ...(snapshot.structured === undefined
      ? {}
      : { structured: snapshot.structured }),
    aborted: false,
    usage,
    model,
    contextWindow,
    transcript,
  };
}

function summaryLine(details: WorkflowDetails): string {
  const { done, failed } = countStates(details);
  const settled = done + failed;
  return `workflow ${details.name ?? details.runId}: ${settled}/${details.agents.length} agents${
    details.currentPhase ? ` · ${details.currentPhase}` : ""
  }`;
}

function writeRunFile(runDir: string, name: string, content: string) {
  writeFileAtomic(path.join(runDir, name), content);
}

function compactToolDetails(details: WorkflowDetails): WorkflowDetails {
  return {
    ...details,
    ...(details.result !== undefined
      ? {
          result: JSON.parse(
            safeStringify(details.result, { maxBytes: 64 * 1024 }),
          ),
        }
      : {}),
    agents: details.agents.map((agent) => ({ ...agent, transcript: [] })),
  };
}

interface RunSummary {
  runId: string;
  name?: string;
  status: string;
  done: number;
  total: number;
  startedAt: number;
  active: boolean;
}

interface ActiveWorkflowRun {
  details: WorkflowDetails;
  controller: RunController;
  completion?: Promise<void>;
}

interface PersistentWorkflowState {
  activeRuns: Map<string, ActiveWorkflowRun>;
  completedRuns: number;
  failedRuns: number;
  pendingFollowUps: string[];
  closing: boolean;
  owner?: symbol;
  onChange?: () => void;
  deliverFollowUp?: (message: string) => void;
}

const WORKFLOW_STATES_KEY = Symbol.for("pi.extensions.workflows.state.v1");
const workflowGlobal = globalThis as typeof globalThis &
  Record<symbol, unknown>;

function workflowStates() {
  let states = workflowGlobal[WORKFLOW_STATES_KEY] as
    | Map<string, PersistentWorkflowState>
    | undefined;
  if (!states) {
    states = new Map();
    workflowGlobal[WORKFLOW_STATES_KEY] = states;
  }
  return states;
}

function persistentWorkflowState(sessionId: string) {
  let state = workflowStates().get(sessionId);
  if (!state) {
    state = {
      activeRuns: new Map(),
      completedRuns: 0,
      failedRuns: 0,
      pendingFollowUps: [],
      closing: false,
    };
    workflowStates().set(sessionId, state);
  }
  return state;
}

function signalWorkflowState(state: PersistentWorkflowState) {
  state.onChange?.();
}

function deliverWorkflowFollowUp(
  state: PersistentWorkflowState,
  message: string,
) {
  if (state.closing) return;
  if (!state.deliverFollowUp) {
    state.pendingFollowUps.push(message);
    return;
  }
  try {
    state.deliverFollowUp(message);
  } catch {
    state.pendingFollowUps.push(message);
  }
}

function listRuns(
  activeRuns: Map<string, WorkflowDetails>,
  sessionId: string,
  referencedRunIds: ReadonlySet<string>,
): RunSummary[] {
  const base = path.join(getAgentDir(), "workflows");
  let names: string[] = [];
  try {
    names = fs.readdirSync(base).filter((name) => name.startsWith("wf_"));
  } catch {
    // No runs yet.
  }
  const summaries: RunSummary[] = [];
  for (const runId of names) {
    const live = activeRuns.get(runId);
    if (live) {
      const { done, failed } = countStates(live);
      summaries.push({
        runId,
        name: live.name,
        status: live.status,
        done: done + failed,
        total: live.agents.length,
        startedAt: live.startedAt,
        active: true,
      });
      continue;
    }
    try {
      const parsed = JSON.parse(
        fs.readFileSync(path.join(base, runId, "workflow.json"), "utf8"),
      ) as Partial<WorkflowDetails>;
      if (parsed.sessionId !== sessionId && !referencedRunIds.has(runId)) {
        continue;
      }
      const agents = parsed.agents ?? [];
      summaries.push({
        runId,
        name: parsed.name,
        status:
          parsed.status === "running"
            ? "aborted"
            : (parsed.status ?? "unknown"),
        done: agents.filter((agent) => agent.state !== "running").length,
        total: agents.length,
        startedAt: parsed.startedAt ?? 0,
        active: false,
      });
    } catch {
      // Ignore unreadable artifacts because their session cannot be verified.
    }
  }
  return summaries.sort((a, b) => b.startedAt - a.startedAt);
}

function runDetailText(
  run: RunSummary,
  activeRuns: Map<string, WorkflowDetails>,
): string {
  const runDir = path.join(getAgentDir(), "workflows", run.runId);
  const live = activeRuns.get(run.runId);
  if (live) return buildWorkflowResultMessage(live, runDir);
  try {
    const parsed = JSON.parse(
      fs.readFileSync(path.join(runDir, "workflow.json"), "utf8"),
    ) as WorkflowDetails;
    return buildWorkflowResultMessage(parsed, runDir);
  } catch {
    return `Run ${run.runId} — ${run.status}`;
  }
}

export default function workflows(pi: ExtensionAPI) {
  const owner = Symbol("workflow-extension");
  let sessionId: string | undefined;
  let state: PersistentWorkflowState | undefined;
  let activeRuns = new Map<string, ActiveWorkflowRun>();
  let lastUi: ExtensionContext["ui"] | undefined;

  const activeDetails = () =>
    new Map(
      [...activeRuns].map(([runId, run]) => [runId, run.details] as const),
    );

  const updateIndicator = () => {
    const ui = lastUi;
    const current = state;
    if (!ui || !current) return;
    try {
      const running = current.activeRuns.size;
      if (
        running === 0 &&
        current.completedRuns === 0 &&
        current.failedRuns === 0
      ) {
        setActivityStatus(ui, "workflows");
        return;
      }
      setActivityStatus(ui, "workflows", {
        running,
        done: current.completedRuns,
        failed: current.failedRuns,
      });
    } catch {
      // UI may be unavailable.
    }
  };

  const recordSettledRun = (
    target: PersistentWorkflowState,
    status: WorkflowDetails["status"],
  ) => {
    if (status === "completed") target.completedRuns += 1;
    else target.failedRuns += 1;
  };

  pi.on("session_start", (_event, ctx) => {
    sessionId = ctx.sessionManager.getSessionId();
    state = persistentWorkflowState(sessionId);
    activeRuns = state.activeRuns;
    state.closing = false;
    state.owner = owner;
    state.onChange = updateIndicator;
    state.deliverFollowUp = (message) => {
      pi.sendUserMessage(message, { deliverAs: "followUp" });
    };
    if (ctx.hasUI) lastUi = ctx.ui;
    const pending = state.pendingFollowUps.splice(0);
    for (const message of pending) deliverWorkflowFollowUp(state, message);
    updateIndicator();
  });

  pi.on("session_shutdown", async (event) => {
    const closingState = state;
    if (lastUi) setActivityStatus(lastUi, "workflows");
    lastUi = undefined;
    if (!closingState) return;
    if (closingState.owner === owner) {
      closingState.owner = undefined;
      closingState.onChange = undefined;
      closingState.deliverFollowUp = undefined;
    }
    if (event.reason === "reload") return;
    closingState.closing = true;
    closingState.pendingFollowUps.length = 0;
    const runs = [...closingState.activeRuns.values()];
    for (const run of runs) run.controller.abort("Session is shutting down");
    await Promise.all(
      runs.map((run) => run.controller.settle({ abort: true })),
    );
    const completions = runs
      .map((run) => run.completion)
      .filter(
        (completion): completion is Promise<void> => completion !== undefined,
      );
    if (completions.length > 0) {
      let timer: ReturnType<typeof setTimeout> | undefined;
      const timeout = new Promise<void>((resolve) => {
        timer = setTimeout(resolve, 8_000);
        timer.unref?.();
      });
      await Promise.race([Promise.allSettled(completions), timeout]);
      if (timer) clearTimeout(timer);
    }
    if (sessionId) workflowStates().delete(sessionId);
    sessionId = undefined;
    state = undefined;
  });

  pi.registerCommand("workflows", {
    description:
      "List workflow runs (`/workflows <runId>` for one run's detail)",
    handler: async (rawArgs, ctx) => {
      const arg = rawArgs.trim();
      if (ctx.mode === "tui") {
        lastUi = ctx.ui;
        await showWorkflowDashboard(ctx, activeDetails, arg || undefined);
        // Opening the dashboard acknowledges finished runs.
        if (state) {
          state.completedRuns = 0;
          state.failedRuns = 0;
        }
        updateIndicator();
        return;
      }
      // Non-TUI fallback: plain text listing.
      const runs = listRuns(
        activeDetails(),
        ctx.sessionManager.getSessionId(),
        sessionWorkflowRunIds(ctx),
      );
      if (runs.length === 0) {
        ctx.ui.notify("No workflow runs yet.", "info");
        return;
      }
      if (arg) {
        const run = runs.find((r) => r.runId === arg || r.runId.endsWith(arg));
        ctx.ui.notify(
          run
            ? runDetailText(run, activeDetails())
            : `No workflow run matching "${arg}".`,
          run ? "info" : "warning",
        );
        return;
      }
      const labels = runs.map(
        (r) =>
          `${r.active ? "* " : "  "}${r.runId}  ${r.status}  ${r.name ?? ""}  ${r.done}/${r.total}`,
      );
      if (!ctx.hasUI) {
        ctx.ui.notify(labels.join("\n"), "info");
        return;
      }
      const choice = await ctx.ui.select("Workflow runs", labels);
      if (!choice) return;
      const run = runs[labels.indexOf(choice)];
      if (run) ctx.ui.notify(runDetailText(run, activeDetails()), "info");
    },
  });

  pi.registerTool({
    name: "workflow",
    label: "Workflow",
    description: WORKFLOW_TOOL_DESCRIPTION,
    promptSnippet: WORKFLOW_PROMPT_SNIPPET,
    promptGuidelines: WORKFLOW_PROMPT_GUIDELINES,
    parameters: WorkflowParams,

    async execute(_toolCallId, params, signal, onUpdate, ctx) {
      let prepared: ReturnType<typeof prepareWorkflowScript>;
      try {
        prepared = prepareWorkflowScript(params.script);
      } catch (error) {
        throw new Error(`Workflow script failed to parse: ${errorText(error)}`);
      }

      let args: unknown;
      if (params.args !== undefined) {
        try {
          args = JSON.parse(params.args);
        } catch {
          args = params.args;
        }
      }

      const meta = prepared.meta;
      const runId = `wf_${randomBytes(6).toString("hex")}`;
      const runDir = path.join(getAgentDir(), "workflows", runId);
      const background = (params.background ?? false) && ctx.hasUI;
      const runSessionId = ctx.sessionManager.getSessionId();
      const runState = persistentWorkflowState(runSessionId);
      const workflowCwd = ctx.cwd;
      const projectTrusted = ctx.isProjectTrusted();
      const parentModel = ctx.model;
      const modelCatalog = [...ctx.modelRegistry.getAll()];
      const defaultThinkingLevel = pi.getThinkingLevel();
      let harnessRuntime: SubagentRuntime | undefined;
      let harnessManagerPromise: Promise<SubagentManagerShape> | undefined;
      const getHarnessManager = () => {
        harnessRuntime ??= createSubagentRuntime();
        harnessManagerPromise ??= harnessRuntime.runPromise(SubagentManager);
        return harnessManagerPromise;
      };

      const details: WorkflowDetails = {
        runId,
        sessionId: runSessionId,
        name: meta.name,
        description: meta.description,
        background,
        status: "running",
        startedAt: Date.now(),
        phases: [...meta.phases],
        agents: [],
      };

      writeRunFile(runDir, "script.js", params.script);
      if (params.args !== undefined)
        writeRunFile(runDir, "args.json", params.args);
      persistWorkflowJson(runDir, details);
      const persistence = createWorkflowPersistence(runDir, details);

      // Background runs survive Esc and reload; other shutdown reasons abort
      // and settle them.
      const controller = new RunController(background ? undefined : signal);

      // Each concurrent child gets its own extension runtime. All children use
      // the parent cwd and live trust decision.
      const getResources = (structured: boolean) =>
        createWorkflowResources(
          workflowCwd,
          structured ? "structured" : "plain",
          projectTrusted,
        );

      // Throttled progress: tool-block updates when blocking. Background
      // runs are covered by the below-editor indicator and /workflows.
      let emitTimer: ReturnType<typeof setTimeout> | undefined;
      let lastEmit = Date.now();
      const flush = () => {
        emitTimer = undefined;
        lastEmit = Date.now();
        if (background) return;
        onUpdate?.({
          content: [{ type: "text", text: summaryLine(details) }],
          details: compactToolDetails(details),
        });
      };
      const emit = (checkpoint = true) => {
        if (checkpoint) persistence.checkpoint();
        if (emitTimer) return;
        emitTimer = setTimeout(
          flush,
          Math.max(0, EMIT_INTERVAL_MS - (Date.now() - lastEmit)),
        );
      };
      const flushNow = () => {
        if (emitTimer) clearTimeout(emitTimer);
        flush();
      };

      const phaseFn = (title: unknown) => {
        const text = String(title);
        details.currentPhase = text;
        if (!details.phases.some((p) => p.title === text))
          details.phases.push({ title: text });
        emit();
      };

      let agentCounter = 0;
      const agentFn = async (
        promptValue: unknown,
        optsValue: unknown = {},
        invocationSignal?: AbortSignal,
      ): Promise<ScriptAgentResult> => {
        const index = ++agentCounter;
        const opts: AgentCallOptions =
          optsValue && typeof optsValue === "object"
            ? (optsValue as AgentCallOptions)
            : {};
        const label =
          typeof opts.label === "string" && opts.label.trim()
            ? opts.label.trim().slice(0, 160)
            : `agent-${index}`;
        const requestedHarness =
          typeof opts.harness === "string" ? opts.harness : "pi";

        const record: AgentRecord = {
          index,
          label,
          phase:
            typeof opts.phase === "string"
              ? opts.phase.slice(0, 160)
              : details.currentPhase,
          state: "running",
          harness: requestedHarness,
          model:
            requestedHarness === "pi"
              ? parentModel?.id
              : typeof opts.model === "string"
                ? opts.model
                : undefined,
          contextWindow:
            requestedHarness === "pi" ? parentModel?.contextWindow : undefined,
          startedAt: Date.now(),
          preview: "",
          usage: emptyUsage(),
          transcript: [],
        };
        details.agents.push(record);
        persistence.checkpoint({ immediate: true });
        emit(false);

        const fail = (error: string): ScriptAgentResult => {
          record.state = "error";
          record.error = error;
          record.finishedAt = Date.now();
          emit();
          return { ok: false, output: "", error };
        };

        const prompt = buildWorkflowAgentPrompt(
          typeof promptValue === "string"
            ? promptValue
            : String(promptValue ?? ""),
        );
        if (!prompt.trim())
          return fail("agent() requires a non-empty prompt string");
        if (controller.signal.aborted)
          return fail("Workflow was aborted before this agent started");

        return controller
          .schedule(async (runSignal) => {
            if (
              !(WORKFLOW_HARNESSES as readonly string[]).includes(
                requestedHarness,
              )
            ) {
              return fail(
                `agent "${label}": invalid harness "${requestedHarness}" (use ${WORKFLOW_HARNESSES.join("|")})`,
              );
            }
            const harness = requestedHarness as (typeof WORKFLOW_HARNESSES)[number];
            record.harness = harness;

            let requestedEffort: ThinkingLevel | undefined;
            if (opts.effort !== undefined) {
              const effort = String(opts.effort);
              if (!(THINKING_LEVELS as readonly string[]).includes(effort)) {
                return fail(
                  `agent "${label}": invalid effort "${effort}" (use ${THINKING_LEVELS.join("|")})`,
                );
              }
              requestedEffort = effort as ThinkingLevel;
            }

            const updateProgress = (progress: {
              preview: string;
              usage: AgentUsage;
              model?: string;
              contextWindow?: number;
              transcript: TranscriptEntry[];
            }) => {
              record.preview = progress.preview.slice(0, PREVIEW_LENGTH);
              record.usage = progress.usage;
              record.model = progress.model ?? record.model;
              record.contextWindow =
                progress.contextWindow ?? record.contextWindow;
              record.transcript = progress.transcript;
              emit();
            };

            let outcome: AgentOutcome;
            if (harness === "pi") {
              let model: WorkflowModel | undefined = parentModel;
              if (opts.model !== undefined || opts.provider !== undefined) {
                const modelOpt =
                  typeof opts.model === "string" ? opts.model : undefined;
                const providerOpt =
                  typeof opts.provider === "string"
                    ? opts.provider
                    : undefined;
                if (!modelOpt) {
                  return fail(
                    `agent "${label}": \`provider\` requires \`model\` as well`,
                  );
                }
                let resolved: WorkflowModel | undefined;
                if (providerOpt) {
                  resolved = modelCatalog.find(
                    (candidate) =>
                      candidate.provider === providerOpt &&
                      candidate.id === modelOpt,
                  );
                } else {
                  const slash = modelOpt.indexOf("/");
                  if (slash > 0) {
                    const provider = modelOpt.slice(0, slash);
                    const id = modelOpt.slice(slash + 1);
                    resolved = modelCatalog.find(
                      (candidate) =>
                        candidate.provider === provider && candidate.id === id,
                    );
                  }
                  resolved ??= modelCatalog.find(
                    (candidate) => candidate.id === modelOpt,
                  );
                }
                if (!resolved) {
                  const requested = providerOpt
                    ? `${providerOpt}/${modelOpt}`
                    : modelOpt;
                  return fail(
                    `agent "${label}": unknown model "${requested}" (use provider/id)`,
                  );
                }
                model = resolved;
              }
              record.model = model?.id;
              record.contextWindow = model?.contextWindow;
              emit();

              const resources = await getResources(
                opts.schema !== undefined,
              );
              outcome = await runAgent({
                prompt,
                schema: opts.schema,
                model,
                thinkingLevel: requestedEffort ?? defaultThinkingLevel,
                cwd: workflowCwd,
                loader: resources.loader,
                settingsManager: resources.settingsManager,
                modelCatalog,
                signal: runSignal,
                onProgress: updateProgress,
              });
            } else {
              if (opts.provider !== undefined) {
                return fail(
                  `agent "${label}": \`provider\` is only valid with harness "pi"`,
                );
              }
              if (opts.model !== undefined && typeof opts.model !== "string") {
                return fail(`agent "${label}": \`model\` must be a string`);
              }
              const manager = await getHarnessManager();
              const runtime = harnessRuntime!;
              outcome = await runHarnessAgent({
                manager,
                runtime,
                harness,
                prompt,
                label,
                ...(typeof opts.model === "string"
                  ? { model: opts.model }
                  : {}),
                ...(requestedEffort
                  ? { effort: requestedEffort as ReasoningEffort }
                  : {}),
                schema: opts.schema,
                cwd: workflowCwd,
                projectTrusted,
                signal: runSignal,
                onProgress: updateProgress,
              });
            }

            record.usage = outcome.usage;
            record.model = outcome.model ?? record.model;
            record.contextWindow =
              outcome.contextWindow ?? record.contextWindow;
            record.transcript = outcome.transcript;
            record.preview = (outcome.output || record.preview).slice(
              0,
              PREVIEW_LENGTH,
            );
            record.finishedAt = Date.now();
            record.state = outcome.ok ? "done" : "error";
            if (outcome.ok) {
              delete record.error;
            } else {
              record.error = outcome.error ?? "Agent failed";
            }
            emit();

            return {
              ok: outcome.ok,
              output: outcome.output,
              ...(outcome.structured !== undefined
                ? { structured: outcome.structured }
                : {}),
              ...(outcome.error !== undefined ? { error: outcome.error } : {}),
            };
          }, invocationSignal)
          .catch((error) => fail(errorText(error)));
      };

      const runScript = async () => {
        let status: WorkflowDetails["status"] = "completed";
        try {
          details.result = await runWorkflowSandbox({
            source: prepared.source,
            args,
            cwd: workflowCwd,
            signal: controller.signal,
            onAgent: agentFn,
            onPhase: phaseFn,
          });
        } catch (error) {
          details.error = errorText(error);
          status = controller.signal.aborted ? "aborted" : "failed";
          controller.abort("Workflow script failed");
        }

        const settled = await controller.settle({
          abort: status !== "completed",
        });
        if (!settled) {
          status = "failed";
          details.error = details.error
            ? `${details.error}; agent shutdown deadline exceeded`
            : "Agent shutdown deadline exceeded";
        }
        if (harnessRuntime) {
          try {
            await harnessRuntime.dispose();
          } catch (error) {
            status = "failed";
            details.error = details.error
              ? `${details.error}; harness cleanup failed: ${errorText(error)}`
              : `Harness cleanup failed: ${errorText(error)}`;
          } finally {
            harnessRuntime = undefined;
            harnessManagerPromise = undefined;
          }
        }
        for (const record of details.agents) {
          if (record.state !== "running") continue;
          record.state = "error";
          record.error =
            record.error ?? "Agent did not settle before run cleanup";
          record.finishedAt = Date.now();
        }
        details.status = status;
        details.finishedAt = Date.now();
        try {
          persistence.flush();
        } catch (error) {
          details.status = "failed";
          details.error = `Artifact persistence failed: ${errorText(error)}`;
          throw new Error(details.error);
        } finally {
          flushNow();
        }
      };

      // Registered for /workflows visibility and shutdown cleanup; blocking
      // runs are watchable live from the dashboard too.
      const activeRun: ActiveWorkflowRun = { details, controller };
      runState.activeRuns.set(runId, activeRun);
      const completion = runScript();
      activeRun.completion = completion;
      if (ctx.hasUI) lastUi = ctx.ui;
      signalWorkflowState(runState);

      if (background) {
        void completion
          .catch((error) => {
            details.status = "failed";
            details.finishedAt = Date.now();
            details.error = details.error ?? errorText(error);
          })
          .finally(() => {
            runState.activeRuns.delete(runId);
            recordSettledRun(runState, details.status);
            signalWorkflowState(runState);
            deliverWorkflowFollowUp(
              runState,
              buildBackgroundWorkflowFollowUp({
                runId,
                status: details.status,
                result: buildWorkflowResultMessage(details, runDir),
              }),
            );
          });
        return {
          content: [
            {
              type: "text",
              text: buildBackgroundWorkflowLaunchResult({
                runId,
                name: details.name,
                runDir,
              }),
            },
          ],
          details: compactToolDetails(details),
        };
      }

      try {
        await completion;
      } finally {
        runState.activeRuns.delete(runId);
        recordSettledRun(runState, details.status);
        signalWorkflowState(runState);
      }
      if (details.status !== "completed") {
        // Pi marks tool failures only when execute throws; returning isError is
        // ignored by the extension API.
        throw new Error(buildWorkflowResultMessage(details, runDir));
      }
      return {
        content: [
          {
            type: "text",
            text: buildWorkflowResultMessage(details, runDir),
          },
        ],
        details: compactToolDetails(details),
      };
    },

    renderCall(args: Partial<WorkflowInput>, theme, context) {
      if (!context.argsComplete) {
        return new Text(
          theme.fg("toolTitle", theme.bold("workflow ")) +
            theme.fg("dim", "preparing…"),
          0,
          0,
        );
      }

      const meta =
        typeof args.script === "string"
          ? extractMeta(args.script)
          : { phases: [] };
      let text =
        theme.fg("toolTitle", theme.bold("workflow ")) +
        theme.fg("accent", (meta as WorkflowMeta).name ?? "(script)");
      if (args.background) text += theme.fg("dim", " (background)");
      const description = (meta as WorkflowMeta).description;
      if (description) text += `\n  ${theme.fg("dim", description)}`;
      for (const phase of meta.phases.slice(0, 8)) {
        text += `\n  ${theme.fg("dim", SQUARE)} ${theme.fg("accent", phase.title)}${
          phase.detail ? theme.fg("dim", ` — ${phase.detail}`) : ""
        }`;
      }
      return new Text(text, 0, 0);
    },

    renderResult(result, { expanded }, theme) {
      const details = result.details as WorkflowDetails | undefined;
      if (!details) {
        const first = result.content[0];
        return new Text(
          first?.type === "text" ? first.text : "(no output)",
          0,
          0,
        );
      }

      const { done, failed } = countStates(details);
      const settled = done + failed;
      const elapsed = formatElapsed(details.startedAt, details.finishedAt);
      let header =
        `${theme.fg(statusColor(details.status), SQUARE)} ${theme.fg("toolTitle", theme.bold("workflow "))}` +
        `${theme.fg("accent", details.name ?? details.runId)} ` +
        theme.fg(
          "dim",
          `${settled}/${details.agents.length} agents · ${elapsed} · `,
        ) +
        theme.fg(statusColor(details.status), statusWord(details.status));
      if (failed) header += theme.fg("error", ` · ${failed} failed`);
      if (details.background) header += theme.fg("dim", " (background)");
      if (details.status === "running" && details.currentPhase) {
        header += theme.fg("muted", ` · ${details.currentPhase}`);
      }
      const totals = formatUsage(aggregateUsage(details.agents));

      if (!expanded) {
        let text = header;
        for (const agent of details.agents) {
          const context = agentContext(agent);
          text += `\n  ${stateSquare(agent.state, theme)} ${theme.fg("accent", agent.label)}${
            agent.phase ? theme.fg("dim", ` (${agent.phase})`) : ""
          }${theme.fg(
            "dim",
            `${context ? ` · ${context}` : ""} · ${formatElapsed(agent.startedAt, agent.finishedAt)}`,
          )}`;
        }
        if (totals) text += `\n  ${theme.fg("dim", `Total: ${totals}`)}`;
        if (details.error)
          text += `\n  ${theme.fg("error", `Error: ${details.error}`)}`;
        text += `\n${theme.fg("muted", `(${keyHint("app.tools.expand", "to expand")})`)}`;
        return new Text(text, 0, 0);
      }

      const container = new Container();
      container.addChild(new Text(header, 0, 0));
      if (details.description) {
        container.addChild(
          new Text(theme.fg("dim", details.description), 0, 0),
        );
      }

      for (const group of phaseGroups(details)) {
        container.addChild(new Spacer(1));
        container.addChild(
          new Text(theme.fg("muted", `─── ${group.title} ───`), 0, 0),
        );
        for (const agent of group.agents) {
          const usage = formatUsage(agent.usage, agent.model);
          const context = agentContext(agent);
          let line = `${stateSquare(agent.state, theme)} ${theme.fg("accent", agent.label)} ${theme.fg(
            "dim",
            [context, formatElapsed(agent.startedAt, agent.finishedAt)]
              .filter(Boolean)
              .join(" · "),
          )}`;
          if (usage) line += ` ${theme.fg("dim", usage)}`;
          container.addChild(new Text(line, 0, 0));
          if (agent.error) {
            container.addChild(
              new Text(`  ${theme.fg("error", agent.error)}`, 0, 0),
            );
          } else if (agent.preview) {
            const preview = agent.preview.split("\n").slice(0, 2).join(" ");
            container.addChild(new Text(`  ${theme.fg("dim", preview)}`, 0, 0));
          }
        }
      }

      if (details.error) {
        container.addChild(new Spacer(1));
        container.addChild(
          new Text(theme.fg("error", `Error: ${details.error}`), 0, 0),
        );
      }

      if (details.result !== undefined) {
        container.addChild(new Spacer(1));
        container.addChild(new Text(theme.fg("muted", "─── result ───"), 0, 0));
        container.addChild(
          new Markdown(
            `\`\`\`json\n${resultJson(details.result)}\n\`\`\``,
            0,
            0,
            getMarkdownTheme(),
          ),
        );
      }

      if (totals) {
        container.addChild(new Spacer(1));
        container.addChild(new Text(theme.fg("dim", `Total: ${totals}`), 0, 0));
      }
      return container;
    },
  });
}
