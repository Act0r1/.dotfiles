import {
	createEditToolDefinition,
	getLanguageFromPath,
	highlightCode,
	renderDiff,
	type ExtensionAPI,
	type Theme,
} from "@earendil-works/pi-coding-agent";
import { Box, Text, type Component } from "@earendil-works/pi-tui";

type DiffPreview = { diff: string } | { error: string };
type EditCallState = { callComponent?: Component };

function renderSyntaxDiff(diff: string, filePath: string, theme: Theme): string {
	const language = getLanguageFromPath(filePath);
	if (!language) return renderDiff(diff, { filePath });

	return diff
		.split("\n")
		.map((line) => {
			const match = line.match(/^([+\- ])(\s*\d*)\s(.*)$/);
			if (!match) return theme.fg("toolDiffContext", line);

			const [, prefix, lineNumber, source] = match;
			const color = prefix === "+" ? "toolDiffAdded" : prefix === "-" ? "toolDiffRemoved" : "toolDiffContext";
			const gutter = theme.fg(color, `${prefix}${lineNumber} `);
			const highlighted = highlightCode(source.replace(/\t/g, "   "), language)[0] ?? source;
			if (prefix === "-") {
				return theme.bg("toolErrorBg", gutter + theme.strikethrough(highlighted));
			}
			return gutter + highlighted;
		})
		.join("\n");
}

function refreshDiff(component: Component | undefined, filePath: string, theme: Theme): void {
	if (!(component instanceof Box)) return;

	const box = component as unknown as { preview?: DiffPreview; children: Component[] };
	if (!box.preview || !("diff" in box.preview)) return;

	const body = box.children.at(-1);
	if (body instanceof Text) body.setText(renderSyntaxDiff(box.preview.diff, filePath, theme));
}

export default function syntaxHighlightedDiffs(pi: ExtensionAPI) {
	const edit = createEditToolDefinition(process.cwd());

	pi.registerTool({
		...edit,
		renderCall(args, theme, context) {
			const component = edit.renderCall!(args, theme, context);
			refreshDiff(component, args.path, theme);
			return component;
		},
		renderResult(result, options, theme, context) {
			const component = edit.renderResult!(result, options, theme, context);
			refreshDiff((context.state as EditCallState).callComponent, context.args.path, theme);
			return component;
		},
	});
}
