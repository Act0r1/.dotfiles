import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  pi.registerCommand("rename", {
    description: "Rename the current session",
    handler: async (args, ctx) => {
      const currentName = pi.getSessionName() ?? "";
      const name = args.trim() || await ctx.ui.input("Rename session", "Session name:", currentName);

      if (!name?.trim()) {
        if (ctx.hasUI) ctx.ui.notify("Rename cancelled", "info");
        return;
      }

      pi.setSessionName(name.trim());
      if (ctx.hasUI) ctx.ui.notify(`Session renamed: ${name.trim()}`, "success");
    },
  });
}
