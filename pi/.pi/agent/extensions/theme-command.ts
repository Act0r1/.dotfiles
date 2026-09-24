import { readFileSync } from "node:fs";
import { DynamicBorder, type ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Container, SelectList, Text, type AutocompleteItem, type SelectItem } from "@earendil-works/pi-tui";

const fallbackThemes = [
	"tokyo-night",
	"catppuccin-mocha-plus",
	"gruvbox-material",
	"nord-aurora",
	"dracula-pro",
	"one-dark-pro",
	"monokai-pro",
	"rose-pine-moon",
	"kanagawa-wave",
	"everforest-dark-plus",
	"github-dark",
	"dark",
	"light",
];

type ThemeInfo = { name: string; path: string | undefined };
type ColorValue = string | number;
type ThemeJson = {
	vars?: Record<string, ColorValue>;
	colors?: Record<string, ColorValue>;
	export?: Record<string, ColorValue>;
};

const cubeValues = [0, 95, 135, 175, 215, 255];

function xtermToHex(value: number): string | undefined {
	if (value >= 16 && value <= 231) {
		const n = value - 16;
		const r = cubeValues[Math.floor(n / 36)] ?? 0;
		const g = cubeValues[Math.floor((n % 36) / 6)] ?? 0;
		const b = cubeValues[n % 6] ?? 0;
		return `#${[r, g, b].map((part) => part.toString(16).padStart(2, "0")).join("")}`;
	}
	if (value >= 232 && value <= 255) {
		const gray = 8 + (value - 232) * 10;
		const part = gray.toString(16).padStart(2, "0");
		return `#${part}${part}${part}`;
	}
	return undefined;
}

function resolveColor(value: ColorValue | undefined, json: ThemeJson, seen = new Set<string>()): string | undefined {
	if (value === undefined) return undefined;
	if (typeof value === "number") return xtermToHex(value);
	if (!value) return undefined;
	if (/^#[0-9a-fA-F]{6}$/.test(value)) return value;
	if (seen.has(value)) return undefined;
	seen.add(value);
	return resolveColor(json.vars?.[value], json, seen);
}

function firstColor(json: ThemeJson, values: Array<ColorValue | undefined>): string | undefined {
	for (const value of values) {
		const color = resolveColor(value, json);
		if (color) return color;
	}
	return undefined;
}

function getTerminalColors(themeInfo: ThemeInfo | undefined): { foreground?: string; background?: string } | undefined {
	if (!themeInfo?.path) return undefined;
	try {
		const json = JSON.parse(readFileSync(themeInfo.path, "utf8")) as ThemeJson;
		return {
			foreground: firstColor(json, [
				json.vars?.fg,
				json.vars?.foreground,
				json.vars?.text,
				json.colors?.text,
				json.colors?.userMessageText,
				json.colors?.toolOutput,
			]),
			background: firstColor(json, [
				json.export?.pageBg,
				json.vars?.bg,
				json.vars?.background,
				json.vars?.base,
				json.vars?.crust,
				json.colors?.customMessageBg,
				json.colors?.userMessageBg,
				json.colors?.toolPendingBg,
			]),
		};
	} catch {
		return undefined;
	}
}

function applyTerminalColors(themeInfo: ThemeInfo | undefined, write: (data: string) => void = (data) => process.stdout.write(data)) {
	const colors = getTerminalColors(themeInfo);
	if (!colors?.foreground && !colors?.background) {
		write("\x1b]110\x07\x1b]111\x07");
		return;
	}

	let sequence = "";
	if (colors.foreground) sequence += `\x1b]10;${colors.foreground}\x07`;
	if (colors.background) sequence += `\x1b]11;${colors.background}\x07`;
	write(sequence);
}

function displayPath(path: string | undefined): string {
	if (!path) return "built-in";
	const home = process.env.HOME;
	return home && path.startsWith(home) ? `~${path.slice(home.length)}` : path;
}

export default function themeCommand(pi: ExtensionAPI) {
	pi.registerCommand("theme", {
		description: "Select or switch theme",
		getArgumentCompletions: (prefix: string): AutocompleteItem[] | null => {
			const items = fallbackThemes
				.filter((name) => name.startsWith(prefix.trim()))
				.map((name) => ({ value: name, label: name }));
			return items.length > 0 ? items : null;
		},
		handler: async (args, ctx) => {
			const requested = args.trim();
			const allThemes = ctx.ui.getAllThemes();
			const themeByName = new Map(allThemes.map((item) => [item.name, item]));
			const names = Array.from(themeByName.keys()).sort((a, b) => a.localeCompare(b));

			if (requested) {
				const result = ctx.ui.setTheme(requested);
				if (result.success) applyTerminalColors(themeByName.get(requested));
				ctx.ui.notify(result.success ? `Theme: ${requested}` : `Failed to load theme "${requested}": ${result.error}`, result.success ? "info" : "error");
				return;
			}

			if (names.length === 0) {
				ctx.ui.notify("No themes available", "warning");
				return;
			}

			if (ctx.mode !== "tui") {
				const selected = await ctx.ui.select("Themes", names);
				if (!selected) return;
				const result = ctx.ui.setTheme(selected);
				ctx.ui.notify(result.success ? `Theme: ${selected}` : `Failed to load theme "${selected}": ${result.error}`, result.success ? "info" : "error");
				return;
			}

			const originalTheme = ctx.ui.theme.name;
			let previewedTheme = originalTheme;
			let previewChanged = false;

			const items: SelectItem[] = names.map((name) => ({
				value: name,
				label: name,
				description: displayPath(themeByName.get(name)?.path),
			}));

			const selected = await ctx.ui.custom<string | null>((tui, theme, _keybindings, done) => {
				const container = new Container();
				const title = new Text("", 1, 0);
				const footer = new Text("", 1, 0);
				const selectList = new SelectList(items, Math.min(items.length, 14), {
					selectedPrefix: (text) => theme.fg("accent", text),
					selectedText: (text) => theme.fg("accent", text),
					description: (text) => theme.fg("muted", text),
					scrollInfo: (text) => theme.fg("dim", text),
					noMatch: (text) => theme.fg("warning", text),
				});
				const currentIndex = originalTheme ? names.indexOf(originalTheme) : -1;
				if (currentIndex >= 0) selectList.setSelectedIndex(currentIndex);

				function refreshText() {
					title.setText(`${theme.fg("accent", theme.bold("Select Theme"))}${theme.fg("dim", `  preview: ${previewedTheme ?? "unknown"}`)}`);
					footer.setText(theme.fg("dim", "↑↓ preview TUI • enter apply terminal • esc cancel"));
				}

				function previewTheme(name: string) {
					if (name === previewedTheme) return;
					previewChanged = true;
					const result = ctx.ui.setTheme(name);
					if (result.success) previewedTheme = name;
					else ctx.ui.notify(`Failed to load theme "${name}": ${result.error}`, "error");
					refreshText();
				}

				selectList.onSelectionChange = (item) => previewTheme(item.value);
				selectList.onSelect = (item) => {
					if (item.value !== previewedTheme) previewTheme(item.value);
					applyTerminalColors(themeByName.get(item.value), (data) => tui.terminal.write(data));
					done(item.value);
				};
				selectList.onCancel = () => done(null);

				container.addChild(new DynamicBorder((s: string) => theme.fg("accent", s)));
				container.addChild(title);
				container.addChild(selectList);
				container.addChild(footer);
				container.addChild(new DynamicBorder((s: string) => theme.fg("accent", s)));
				refreshText();

				return {
					render(width: number) {
						refreshText();
						return container.render(width);
					},
					invalidate() {
						container.invalidate();
						refreshText();
					},
					handleInput(data: string) {
						selectList.handleInput(data);
						tui.requestRender();
					},
				};
			});

			if (!selected) {
				if (originalTheme && (previewChanged || previewedTheme !== originalTheme)) {
					ctx.ui.setTheme(originalTheme);
					applyTerminalColors(themeByName.get(originalTheme));
				}
				return;
			}

			ctx.ui.notify(`Theme: ${selected}`, "info");
		},
	});
}
