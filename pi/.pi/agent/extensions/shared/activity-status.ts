import type { ExtensionContext } from "@earendil-works/pi-coding-agent";

type Theme = ExtensionContext["ui"]["theme"];

export interface ActivityCounts {
  running: number;
  done: number;
  failed: number;
}

type ActivityLabel = "subagents" | "workflows";
type UI = ExtensionContext["ui"];

const ACTIVITY_STATUS_KEY = "activity";
const SQUARE = "■";
const activities = new Map<ActivityLabel, ActivityCounts>();

export function formatActivityStatus(
  theme: Theme,
  label: "subagents" | "workflows",
  counts: ActivityCounts,
) {
  const parts: string[] = [];
  if (counts.running > 0) {
    parts.push(theme.fg("warning", `${SQUARE} ${counts.running} running`));
  }
  if (counts.done > 0) {
    parts.push(theme.fg("success", `${SQUARE} ${counts.done} done`));
  }
  if (counts.failed > 0) {
    parts.push(theme.fg("error", `${SQUARE} ${counts.failed} failed`));
  }
  parts.push(theme.fg("accent", `/${label}`) + theme.fg("dim", " to view"));

  return `${theme.fg("muted", `${label}:`)} ${parts.join(theme.fg("dim", " · "))}`;
}

export function setActivityStatus(
  ui: UI,
  label: ActivityLabel,
  counts?: ActivityCounts,
) {
  ui.setStatus(label, undefined);
  if (!counts || counts.running + counts.done + counts.failed === 0) {
    activities.delete(label);
  } else {
    activities.set(label, { ...counts });
  }

  const text = [...activities.entries()]
    .sort(([left], [right]) => left.localeCompare(right))
    .map(([name, value]) => formatActivityStatus(ui.theme, name, value))
    .join(ui.theme.fg("dim", " · "));
  ui.setStatus(ACTIVITY_STATUS_KEY, text || undefined);
}
