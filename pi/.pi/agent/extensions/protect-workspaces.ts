import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { isToolCallEventType } from "@earendil-works/pi-coding-agent";
import { existsSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import path from "node:path";

const PROTECTED_ROOTS = ["/home/yeager/Developer", "/home/yeager/Personal"];
const ACCESS_MODE_CONFIG_PATH = path.join(homedir(), ".pi", "agent", "access-mode.json");
const SENSITIVE_ALLOW_PHRASE = "YES U CAN";
let allowWithoutAsking = false;
let allowSensitiveOnce = false;

function isProtected(filePath: string, cwd: string) {
  const absolute = path.resolve(cwd, filePath);
  return PROTECTED_ROOTS.some((root) => absolute === root || absolute.startsWith(root + path.sep));
}

function cwdIsProtected(cwd: string) {
  return PROTECTED_ROOTS.some((root) => cwd === root || cwd.startsWith(root + path.sep));
}

function isSensitivePath(filePath: string, cwd: string) {
  const absolute = path.resolve(cwd, filePath);
  const normalized = absolute.replaceAll("\\", "/");
  const base = path.basename(normalized);

  if (base === ".env.example") return false;

  return (
    base === ".env" ||
    base.startsWith(".env.") ||
    base.endsWith(".pem") ||
    base.endsWith(".key") ||
    base === "env.php" ||
    base.startsWith("env.php") ||
    normalized.includes("/secrets/") ||
    normalized.endsWith("/secrets") ||
    normalized.includes("/credentials/") ||
    normalized.endsWith("/credentials") ||
    normalized.includes("/.aws/") ||
    normalized.endsWith("/.aws") ||
    normalized.includes("/.ssh/") ||
    normalized.endsWith("/.ssh") ||
    normalized.endsWith("/config/database.yml")
  );
}

function commandMentionsSensitivePath(command: string) {
  const withoutEnvExample = command.replace(
    /(^|[\/\s"'`=])\.env\.example(?=$|[\s"'`;,|&)<>{}\]:])/g,
    "$1",
  );

  return /(^|\s)(\.\/)?\.env(\.|\s|$)|\.pem\b|\.key\b|env\.php|\/secrets(\/|\s|$)|\/credentials(\/|\s|$)|\.aws(\/|\s|$)|\.ssh(\/|\s|$)|config\/database\.yml/.test(withoutEnvExample);
}

function consumeSensitiveAllowance() {
  if (!allowSensitiveOnce) return false;
  allowSensitiveOnce = false;
  return true;
}

function isFullAccessMode() {
  if (!existsSync(ACCESS_MODE_CONFIG_PATH)) return true;
  try {
    const saved = JSON.parse(readFileSync(ACCESS_MODE_CONFIG_PATH, "utf8")) as { mode?: unknown };
    return saved.mode === "full-access";
  } catch {
    return true;
  }
}

function blockSensitive(ctx: any, action: string, filePath: string) {
  if (consumeSensitiveAllowance()) return undefined;
  return {
    block: true,
    reason: `Blocked ${action} for sensitive file/path: ${filePath}. Access denied. Continue without this file/path. Do not ask the user for permission and do not stop this task.`,
  };
}

function bashMayChangeProtectedPath(command: string, cwd: string) {
  const mutatingPatterns = [
    /(^|[;&|()\s])(rm|rmdir|mv|cp|install|mkdir|touch|ln|chmod|chown|chgrp|truncate|tee|dd|patch|git\s+(apply|checkout|switch|restore|reset|clean|merge|rebase|pull|commit|stash)|npm\s+(install|i|update|remove|uninstall)|pnpm\s+(install|i|update|remove|uninstall)|yarn\s+(add|install|remove|upgrade)|bun\s+(add|install|remove|update)|cargo\s+(add|remove|update|fix)|go\s+(get|mod\s+tidy|fmt)|python\S*\s+-m\s+pip\s+install)\b/,
    />|>>|\d>|\d>>|\b(sed|perl)\b.*\s-i\b/,
  ];

  const mayMutate = mutatingPatterns.some((pattern) => pattern.test(command));
  if (!mayMutate) return false;

  if (cwdIsProtected(cwd)) return true;
  return PROTECTED_ROOTS.some((root) => command.includes(root) || command.includes(root.replace("/home/yeager", "~")));
}

async function confirmChange(ctx: any, action: string, filePath: string) {
  if (allowWithoutAsking || isFullAccessMode()) return undefined;

  const target = filePath.length > 140 ? `${filePath.slice(0, 137)}...` : filePath;
  const choice = await ctx.ui.select(
    `Protected workspace change: allow ${action}?\n${target}`,
    ["Yes", "Yes, and don't ask again", "No"],
  );

  if (choice === "Yes, and don't ask again") {
    allowWithoutAsking = true;
    ctx.ui.notify("Workspace changes allowed for this pi session", "info");
    return undefined;
  }

  if (choice !== "Yes") {
    ctx.abort();
    return { block: true, reason: `User denied ${action} in protected workspace: ${filePath}. Stop immediately; do not try alternatives or continue this task.` };
  }

  return undefined;
}

export default function (pi: ExtensionAPI) {
  pi.on("input", (event, ctx) => {
    if (event.text.includes(SENSITIVE_ALLOW_PHRASE)) {
      allowSensitiveOnce = true;
      if (ctx.hasUI) ctx.ui.notify("Next sensitive file access is allowed once", "info");
    }
  });

  pi.on("tool_call", async (event, ctx) => {
    if (isToolCallEventType("read", event) && isSensitivePath(event.input.path, ctx.cwd)) {
      return blockSensitive(ctx, "read", path.resolve(ctx.cwd, event.input.path));
    }

    if (isToolCallEventType("write", event) && isSensitivePath(event.input.path, ctx.cwd)) {
      return blockSensitive(ctx, "write", path.resolve(ctx.cwd, event.input.path));
    }

    if (isToolCallEventType("edit", event) && isSensitivePath(event.input.path, ctx.cwd)) {
      return blockSensitive(ctx, "edit", path.resolve(ctx.cwd, event.input.path));
    }

    if (isToolCallEventType("bash", event) && commandMentionsSensitivePath(event.input.command)) {
      return blockSensitive(ctx, "bash command", event.input.command);
    }

    if (!ctx.hasUI) return;

    if (isToolCallEventType("write", event) && isProtected(event.input.path, ctx.cwd)) {
      return confirmChange(ctx, "write", path.resolve(ctx.cwd, event.input.path));
    }

    if (isToolCallEventType("edit", event) && isProtected(event.input.path, ctx.cwd)) {
      return confirmChange(ctx, "edit", path.resolve(ctx.cwd, event.input.path));
    }

    if (isToolCallEventType("bash", event) && bashMayChangeProtectedPath(event.input.command, ctx.cwd)) {
      return confirmChange(ctx, "bash command", event.input.command);
    }
  });
}
