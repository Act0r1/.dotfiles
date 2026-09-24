import type { ExtensionAPI, Theme } from "@earendil-works/pi-coding-agent";
import { VERSION } from "@earendil-works/pi-coding-agent";

function piIcon(theme: Theme): string[] {
  const blue = (s: string) => theme.fg("accent", s);
  const dim = (s: string) => theme.fg("dim", s);
  const text = (s: string) => theme.fg("text", s);

  return [
    "",
    `        ${text("█▌")}  ${text("█▌")}`,
    `     ${blue("██████████████")}`,
    `        ${blue("██")}    ${blue("██")}`,
    `        ${blue("██")}    ${blue("██")}`,
    `        ${blue("██")}    ${blue("██")}`,
    `        ${blue("██")}    ${blue("██")}`,
    "",
    `${blue("π pi")} ${dim(`v${VERSION}`)} ${dim("· GitHub Dark")}`,
    ""
  ];
}

export default function (pi: ExtensionAPI) {
  pi.on("session_start", async (_event, ctx) => {
    if (!ctx.hasUI) return;

    ctx.ui.setHeader((_tui, theme) => ({
      render(_width: number): string[] {
        return piIcon(theme);
      },
      invalidate() {}
    }));
  });
}
