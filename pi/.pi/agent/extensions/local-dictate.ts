import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { isKeyRelease, isKeyRepeat, matchesKey } from "@earendil-works/pi-tui";
import { spawn, type ChildProcessByStdio } from "node:child_process";
import { createWriteStream, type WriteStream } from "node:fs";
import { stat, unlink } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import type { Readable } from "node:stream";

const MODEL_PATH = join(
  process.env.HOME ?? "",
  ".local",
  "share",
  "whisper.cpp",
  "ggml-large-v3-turbo.bin",
);
const SAMPLE_RATE = "16000";
const TRANSCRIPTION_TIMEOUT_MS = 180_000;

type DictationState = "idle" | "recording" | "transcribing";
type Recorder = ChildProcessByStdio<null, Readable, Readable>;

const wait = (milliseconds: number) =>
  new Promise<void>((resolve) => setTimeout(resolve, milliseconds));

async function removeFile(path: string | undefined): Promise<void> {
  if (!path) return;
  await unlink(path).catch(() => undefined);
}

async function waitForRecorder(recorder: Recorder): Promise<void> {
  if (recorder.exitCode !== null || recorder.signalCode !== null) return;

  const exited = new Promise<void>((resolve) => recorder.once("close", () => resolve()));
  await Promise.race([exited, wait(3_000)]);

  if (recorder.exitCode === null && recorder.signalCode === null) {
    recorder.kill("SIGKILL");
    await Promise.race([exited, wait(1_000)]);
  }
}

async function waitForOutput(output: WriteStream): Promise<void> {
  if (output.writableFinished || output.closed) return;
  await Promise.race([
    new Promise<void>((resolve) => {
      output.once("finish", resolve);
      output.once("close", resolve);
      output.once("error", resolve);
    }),
    wait(1_000),
  ]);
}

export default function (pi: ExtensionAPI) {
  let state: DictationState = "idle";
  let recorder: Recorder | undefined;
  let rawOutput: WriteStream | undefined;
  let rawPath: string | undefined;
  let wavPath: string | undefined;
  let activeContext: ExtensionContext | undefined;
  let removeInputListener: (() => void) | undefined;
  let operation = 0;
  let transcriptionAbort: AbortController | undefined;

  const setStatus = (text?: string) => {
    activeContext?.ui.setStatus("local-dictate", text);
  };

  const reset = async () => {
    const oldRawPath = rawPath;
    const oldWavPath = wavPath;

    recorder = undefined;
    rawOutput = undefined;
    rawPath = undefined;
    wavPath = undefined;
    transcriptionAbort = undefined;
    state = "idle";
    setStatus();
    activeContext = undefined;

    await Promise.all([removeFile(oldRawPath), removeFile(oldWavPath)]);
  };

  const cancel = async () => {
    operation++;
    transcriptionAbort?.abort();
    recorder?.kill("SIGKILL");
    rawOutput?.destroy();
    await reset();
  };

  const start = async (context: ExtensionContext) => {
    const model = await stat(MODEL_PATH).catch(() => undefined);
    if (!model?.isFile()) {
      context.ui.notify(`Local Whisper model not found: ${MODEL_PATH}`, "error");
      return;
    }

    const currentOperation = ++operation;
    const stem = join(tmpdir(), `pi-local-dictate-${process.pid}-${Date.now()}`);
    rawPath = `${stem}.raw`;
    wavPath = `${stem}.wav`;
    activeContext = context;
    state = "recording";
    setStatus("● recording — Alt+M to stop");

    rawOutput = createWriteStream(rawPath);
    recorder = spawn(
      "parec",
      [
        "--record",
        "--device=@DEFAULT_SOURCE@",
        `--rate=${SAMPLE_RATE}`,
        "--format=s16le",
        "--channels=1",
        "--raw",
      ],
      { stdio: ["ignore", "pipe", "pipe"] },
    );

    recorder.stdout.pipe(rawOutput);
    recorder.once("error", async (error) => {
      if (currentOperation !== operation || state !== "recording") return;
      context.ui.notify(`Failed to start microphone: ${error.message}`, "error");
      await reset();
    });
    recorder.once("close", async (code, signal) => {
      if (currentOperation !== operation || state !== "recording") return;
      context.ui.notify(
        `Microphone recorder stopped unexpectedly (${signal ?? code ?? "unknown"})`,
        "error",
      );
      await reset();
    });
  };

  const stop = async () => {
    if (state !== "recording" || !recorder || !rawOutput || !rawPath || !wavPath || !activeContext) {
      return;
    }

    const currentOperation = operation;
    const currentRecorder = recorder;
    const currentOutput = rawOutput;
    const currentRawPath = rawPath;
    const currentWavPath = wavPath;
    const context = activeContext;

    state = "transcribing";
    setStatus("transcribing locally…");
    currentRecorder.kill("SIGINT");
    await waitForRecorder(currentRecorder);
    await waitForOutput(currentOutput);

    if (currentOperation !== operation) return;

    const recording = await stat(currentRawPath).catch(() => undefined);
    if (!recording || recording.size < 3_200) {
      context.ui.notify("No microphone audio was recorded", "warning");
      await reset();
      return;
    }

    const converted = await pi.exec(
      "sox",
      [
        "-t",
        "raw",
        "-r",
        SAMPLE_RATE,
        "-e",
        "signed-integer",
        "-b",
        "16",
        "-c",
        "1",
        currentRawPath,
        currentWavPath,
      ],
      { timeout: 30_000 },
    );

    if (currentOperation !== operation) return;
    if (converted.code !== 0 || converted.killed) {
      context.ui.notify(converted.stderr.trim() || "Failed to prepare recorded audio", "error");
      await reset();
      return;
    }

    transcriptionAbort = new AbortController();
    const result = await pi.exec(
      "whisper-cli",
      [
        "-m",
        MODEL_PATH,
        "-f",
        currentWavPath,
        "-l",
        "auto",
        "-nt",
        "-np",
      ],
      { signal: transcriptionAbort.signal, timeout: TRANSCRIPTION_TIMEOUT_MS },
    );

    if (currentOperation !== operation) return;
    if (result.code !== 0 || result.killed) {
      context.ui.notify(result.stderr.trim() || "Local transcription failed", "error");
      await reset();
      return;
    }

    const text = result.stdout.replace(/\s+/g, " ").trim();
    if (text) {
      const current = context.ui.getEditorText();
      const separator = current && !/\s$/.test(current) ? " " : "";
      context.ui.setEditorText(`${current}${separator}${text}`);
    } else {
      context.ui.notify("No speech detected", "warning");
    }

    await reset();
  };

  const toggle = async (context: ExtensionContext) => {
    if (state === "idle") {
      await start(context);
      return;
    }
    if (state === "recording") {
      await stop();
    }
  };

  pi.registerShortcut("alt+m", {
    description: "Start or stop local Whisper dictation",
    handler: toggle,
  });

  pi.registerShortcut("alt+n", {
    description: "Cancel local Whisper dictation",
    handler: cancel,
  });

  pi.registerCommand("dictate", {
    description: "Start or stop local Whisper dictation",
    handler: async (_args, context) => toggle(context),
  });

  pi.registerCommand("dictate-cancel", {
    description: "Cancel local Whisper dictation",
    handler: cancel,
  });

  pi.on("session_start", (_event, context) => {
    activeContext = state === "idle" ? undefined : context;
    if (context.mode !== "tui") return;

    context.ui.setWidget("local-dictate-input-listener", (tui) => {
      removeInputListener?.();
      removeInputListener = tui.addInputListener((data) => {
        if (isKeyRelease(data) || isKeyRepeat(data)) return undefined;
        if (matchesKey(data, "alt+m")) {
          void toggle(context);
          return { consume: true };
        }
        if (matchesKey(data, "alt+n")) {
          void cancel();
          return { consume: true };
        }
        return undefined;
      });
      return { render: () => [], invalidate: () => undefined };
    });
  });

  pi.on("session_shutdown", async () => {
    removeInputListener?.();
    removeInputListener = undefined;
    await cancel();
  });
}
