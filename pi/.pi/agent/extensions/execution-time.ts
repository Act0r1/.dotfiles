import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

function formatDuration(ms: number) {
  const totalSeconds = Math.max(0, Math.floor(ms / 1000));
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  if (minutes > 0) return `${minutes}m ${seconds}s`;
  return `${seconds}s`;
}

export default function (pi: ExtensionAPI) {
  let startedAt: number | undefined;
  let timer: NodeJS.Timeout | undefined;

  function stopTimer() {
    if (timer) clearInterval(timer);
    timer = undefined;
  }

  pi.on("agent_start", (_event, ctx) => {
    if (!ctx.hasUI) return;
    startedAt = Date.now();
    ctx.ui.setStatus("exec-time", "⏱ 0s");
    stopTimer();
    timer = setInterval(() => {
      if (startedAt) ctx.ui.setStatus("exec-time", `⏱ ${formatDuration(Date.now() - startedAt)}`);
    }, 1000);
  });

  pi.on("agent_end", (_event, ctx) => {
    if (!ctx.hasUI || !startedAt) return;
    const elapsed = formatDuration(Date.now() - startedAt);
    stopTimer();
    startedAt = undefined;
    ctx.ui.setStatus("exec-time", `⏱ ${elapsed}`);
  });

  pi.on("session_shutdown", () => {
    stopTimer();
  });
}
