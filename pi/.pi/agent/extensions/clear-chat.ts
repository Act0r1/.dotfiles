import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  pi.registerCommand("clear-chat", {
    description: "Clear the current chat by starting a fresh empty session",
    handler: async (_args, ctx) => {
      const result = await ctx.newSession({
        withSession: async (newCtx) => {
          if (newCtx.hasUI) {
            newCtx.ui.notify("Chat cleared", "success");
          }
        }
      });

      if (result.cancelled && ctx.hasUI) {
        ctx.ui.notify("Clear cancelled", "info");
      }
    }
  });
}
