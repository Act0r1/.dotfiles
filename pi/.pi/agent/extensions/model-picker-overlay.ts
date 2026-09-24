import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import type { Api, Model } from "@earendil-works/pi-ai";
import {
  DynamicBorder,
  type ExtensionAPI,
  type ExtensionContext,
  type Theme,
} from "@earendil-works/pi-coding-agent";
import {
  Container,
  fuzzyFilter,
  Input,
  Key,
  type Focusable,
  type KeybindingsManager,
  matchesKey,
  Text,
  type TUI,
} from "@earendil-works/pi-tui";

type PickerModel = Model<Api>;
type PickerMode = "all" | "favorites";

const FAVORITES_PATH = join(homedir(), ".pi", "agent", "model-favorites.json");

function modelKey(model: PickerModel): string {
  return `${model.provider}/${model.id}`;
}

function loadFavorites(): Set<string> {
  try {
    if (!existsSync(FAVORITES_PATH)) return new Set();
    const parsed: unknown = JSON.parse(readFileSync(FAVORITES_PATH, "utf8"));
    if (!Array.isArray(parsed)) return new Set();
    return new Set(parsed.filter((value): value is string => typeof value === "string"));
  } catch {
    return new Set();
  }
}

function saveFavorites(favorites: Set<string>): void {
  try {
    mkdirSync(join(homedir(), ".pi", "agent"), { recursive: true });
    writeFileSync(FAVORITES_PATH, `${JSON.stringify([...favorites], null, 2)}\n`);
  } catch {
    // favorites persistence is best-effort
  }
}

function isSameModel(left: PickerModel | undefined, right: PickerModel): boolean {
  return left?.provider === right.provider && left.id === right.id;
}

class ModelPicker extends Container implements Focusable {
  private readonly searchInput = new Input();
  private readonly listContainer = new Container();
  private readonly details = new Text("", 1, 0);
  private readonly header: Text;
  private readonly models: PickerModel[];
  private readonly favorites: Set<string>;
  private filteredModels: PickerModel[];
  private mode: PickerMode = "all";
  private selectedIndex = 0;
  private _focused = false;

  get focused(): boolean {
    return this._focused;
  }

  set focused(value: boolean) {
    this._focused = value;
    this.searchInput.focused = value;
  }

  constructor(
    private readonly tui: TUI,
    private readonly theme: Theme,
    private readonly keybindings: KeybindingsManager,
    models: PickerModel[],
    private readonly currentModel: PickerModel | undefined,
    favorites: Set<string>,
    private readonly done: (model: PickerModel | null) => void,
  ) {
    super();
    this.favorites = favorites;
    this.models = [...models].sort((left, right) => {
      const leftCurrent = isSameModel(currentModel, left);
      const rightCurrent = isSameModel(currentModel, right);
      if (leftCurrent !== rightCurrent) return leftCurrent ? -1 : 1;
      return left.provider.localeCompare(right.provider) || left.id.localeCompare(right.id);
    });
    this.filteredModels = this.models;

    this.header = new Text(this.headerText(), 0, 0);
    this.addChild(new DynamicBorder((text: string) => theme.fg("borderAccent", text)));
    this.addChild(this.header);
    this.addChild(new Text(theme.fg("dim", " Type to search by model, provider, or name"), 0, 0));
    this.addChild(this.searchInput);
    this.addChild(this.listContainer);
    this.addChild(this.details);
    this.addChild(
      new Text(
        theme.fg(
          "dim",
          " ↑↓/ctrl+n,p navigate  •  enter select  •  tab all/★  •  ctrl+b star  •  esc close",
        ),
        0,
        0,
      ),
    );
    this.addChild(new DynamicBorder((text: string) => theme.fg("borderAccent", text)));

    this.searchInput.onSubmit = () => this.selectCurrent();
    this.updateList();
  }

  handleInput(data: string): void {
    if (this.keybindings.matches(data, "tui.select.cancel")) {
      this.done(null);
      return;
    }

    if (matchesKey(data, Key.tab)) {
      this.mode = this.mode === "all" ? "favorites" : "all";
      this.header.setText(this.headerText());
      this.refreshFiltered();
    } else if (matchesKey(data, Key.ctrl("b"))) {
      this.toggleFavorite();
    } else if (matchesKey(data, Key.ctrl("p")) || this.keybindings.matches(data, "tui.select.up")) {
      if (this.filteredModels.length > 0) {
        this.selectedIndex =
          this.selectedIndex === 0 ? this.filteredModels.length - 1 : this.selectedIndex - 1;
        this.updateList();
      }
    } else if (matchesKey(data, Key.ctrl("n")) || this.keybindings.matches(data, "tui.select.down")) {
      if (this.filteredModels.length > 0) {
        this.selectedIndex =
          this.selectedIndex === this.filteredModels.length - 1 ? 0 : this.selectedIndex + 1;
        this.updateList();
      }
    } else if (this.keybindings.matches(data, "tui.select.confirm")) {
      this.selectCurrent();
    } else {
      this.searchInput.handleInput(data);
      this.refreshFiltered();
    }

    this.tui.requestRender();
  }

  private headerText(): string {
    return this.mode === "all"
      ? this.theme.fg("accent", this.theme.bold(" Select model (all)"))
      : this.theme.fg("warning", this.theme.bold(" Select model (★ favorites)"));
  }

  private toggleFavorite(): void {
    const selected = this.filteredModels[this.selectedIndex];
    if (!selected) return;
    const key = modelKey(selected);
    if (this.favorites.has(key)) {
      this.favorites.delete(key);
    } else {
      this.favorites.add(key);
    }
    saveFavorites(this.favorites);
    this.refreshFiltered({ keepIndex: true });
  }

  private baseModels(): PickerModel[] {
    if (this.mode === "all") return this.models;
    return this.models.filter((model) => this.favorites.has(modelKey(model)));
  }

  private refreshFiltered(options?: { keepIndex?: boolean }): void {
    const query = this.searchInput.getValue().trim();
    const base = this.baseModels();
    this.filteredModels = query
      ? fuzzyFilter(base, query, (model) => `${model.id} ${model.provider} ${model.name ?? ""}`)
      : base;

    if (options?.keepIndex && this.filteredModels.length > 0) {
      this.selectedIndex = Math.min(this.selectedIndex, this.filteredModels.length - 1);
    } else {
      this.selectedIndex = 0;
    }
    this.updateList();
  }

  private selectCurrent(): void {
    const selected = this.filteredModels[this.selectedIndex];
    if (selected) this.done(selected);
  }

  private updateList(): void {
    this.listContainer.clear();
    const maxVisible = 10;
    const startIndex = Math.max(
      0,
      Math.min(
        this.selectedIndex - Math.floor(maxVisible / 2),
        this.filteredModels.length - maxVisible,
      ),
    );
    const endIndex = Math.min(startIndex + maxVisible, this.filteredModels.length);

    for (let index = startIndex; index < endIndex; index++) {
      const model = this.filteredModels[index];
      if (!model) continue;
      const selected = index === this.selectedIndex;
      const current = isSameModel(this.currentModel, model);
      const prefix = selected ? " → " : "   ";
      const modelText = selected
        ? this.theme.fg("accent", model.id)
        : this.theme.fg("text", model.id);
      const provider = this.theme.fg("muted", `[${model.provider}]`);
      const star = this.favorites.has(modelKey(model)) ? this.theme.fg("warning", " ★") : "";
      const checkmark = current ? this.theme.fg("success", " ✓") : "";
      this.listContainer.addChild(
        new Text(`${prefix}${modelText} ${provider}${star}${checkmark}`, 0, 0),
      );
    }

    if (this.filteredModels.length === 0) {
      const message =
        this.mode === "favorites"
          ? "   No favorites yet — highlight a model and press ctrl+b"
          : "   No matching models";
      this.listContainer.addChild(new Text(this.theme.fg("warning", message), 0, 0));
      this.details.setText("");
      return;
    }

    if (startIndex > 0 || endIndex < this.filteredModels.length) {
      this.listContainer.addChild(
        new Text(
          this.theme.fg("dim", `   ${this.selectedIndex + 1}/${this.filteredModels.length}`),
          0,
          0,
        ),
      );
    }

    const selected = this.filteredModels[this.selectedIndex];
    this.details.setText(
      this.theme.fg("muted", ` ${selected?.name ?? selected?.id ?? ""}`),
    );
  }
}

async function showModelPicker(pi: ExtensionAPI, ctx: ExtensionContext): Promise<void> {
  const models = ctx.modelRegistry.getAvailable();
  if (models.length === 0) {
    ctx.ui.notify("No available models", "warning");
    return;
  }

  const favorites = loadFavorites();

  const selected = await ctx.ui.custom<PickerModel | null>(
    (tui, theme, keybindings, done) =>
      new ModelPicker(tui, theme, keybindings, models, ctx.model, favorites, done),
    {
      overlay: true,
      overlayOptions: {
        anchor: "center",
        width: 76,
        minWidth: 48,
        maxHeight: 18,
        margin: 1,
      },
    },
  );

  if (!selected) return;

  try {
    const changed = await pi.setModel(selected);
    if (!changed) {
      ctx.ui.notify(`No API key for ${selected.provider}/${selected.id}`, "error");
      return;
    }
    ctx.ui.notify(`Model: ${selected.id}`, "info");
  } catch (error) {
    ctx.ui.notify(error instanceof Error ? error.message : String(error), "error");
  }
}

export default function modelPickerOverlay(pi: ExtensionAPI): void {
  let open = false;

  pi.registerShortcut(Key.ctrl("p"), {
    description: "Open centered model picker",
    handler: async (ctx) => {
      if (ctx.mode !== "tui" || open) return;
      open = true;
      try {
        await showModelPicker(pi, ctx);
      } finally {
        open = false;
      }
    },
  });
}
