import { CustomEditor, type ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { matchesKey } from "@earendil-works/pi-tui";

function findBottomBorderIndex(lines: string[]): number {
  for (let index = lines.length - 1; index >= 0; index -= 1) {
    const plain = (lines[index] ?? "").replace(/\x1b\[[0-?]*[ -/]*[@-~]/g, "");
    if (/^─+$/.test(plain) || /^─── ↓ \d+ more ─*$/.test(plain)) return index;
  }
  return lines.length - 1;
}

class ClearEditorAtEnd extends CustomEditor {
  private allTextSelected = false;

  override setText(text: string): void {
    this.allTextSelected = false;
    super.setText(text);
  }

  override handleInput(data: string): void {
    if (matchesKey(data, "ctrl+a")) {
      this.allTextSelected = this.getText().length > 0;
      this.tui.requestRender();
      return;
    }

    if (
      this.allTextSelected &&
      (matchesKey(data, "backspace") || matchesKey(data, "delete"))
    ) {
      this.setText("");
      this.tui.requestRender();
      return;
    }

    this.allTextSelected = false;

    if (matchesKey(data, "ctrl+down")) {
      const lines = this.getLines();
      const cursor = this.getCursor();
      const lastLineIndex = lines.length - 1;
      const lastLine = lines[lastLineIndex] ?? "";

      if (cursor.line === lastLineIndex && cursor.col === lastLine.length) {
        this.setText("");
        this.tui.requestRender();
        return;
      }

      super.handleInput("\x1b[B");
      return;
    }

    super.handleInput(data);
  }

  override render(width: number): string[] {
    const lines = super.render(width);
    if (!this.allTextSelected || lines.length < 2) return lines;

    const bottomBorderIndex = findBottomBorderIndex(lines);
    for (let index = 1; index < bottomBorderIndex; index += 1) {
      const line = lines[index] ?? "";
      const withoutCursor = line.replace(/\x1b\[7m(.*?)\x1b\[0m/g, "$1");
      const content = withoutCursor.trimEnd();
      const selectedLength = Math.max(1, content.length);
      lines[index] = `\x1b[7m${withoutCursor.slice(0, selectedLength)}\x1b[0m${withoutCursor.slice(selectedLength)}`;
    }

    return lines;
  }
}

export default function clearEditorAtEnd(pi: ExtensionAPI): void {
  pi.on("session_start", (_event, ctx) => {
    if (ctx.mode !== "tui") return;

    ctx.ui.setEditorComponent(
      (tui, theme, keybindings) => new ClearEditorAtEnd(tui, theme, keybindings),
    );
  });
}
