import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  pi.on("before_agent_start", (event) => {
    return {
      systemPrompt:
        event.systemPrompt +
        `\n\nCode block rendering guidance:\n` +
        `- Always tag fenced code blocks with the correct language, e.g. \`\`\`bash, \`\`\`python, \`\`\`ts, \`\`\`rust, \`\`\`json.\n` +
        `- For shell examples, prefer complete commands instead of standalone flags, so terminal syntax highlighting has meaningful tokens to color. Example: use \`cargo build --features vendored_openssl\`, not only \`--features vendored_openssl\`.\n` +
        `- Use \`bash\` for POSIX shell snippets unless another shell is specifically required.\n`,
    };
  });
}
