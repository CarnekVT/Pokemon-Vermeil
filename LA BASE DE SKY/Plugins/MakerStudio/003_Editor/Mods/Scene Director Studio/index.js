import { SceneDirectorEditor } from "./editor.js";

const PANEL_ID = "scene-director-studio.main";

export function activate(ctx) {
  ctx.log.info("Scene Director Studio v0.3.2 activated");
  ctx.ui.registerPanel({
    id: PANEL_ID,
    title: "Scene Director Studio",
    icon: "video",
    defaultPosition: "right",
    defaultSize: { width: 1500, height: 940 },
    showInMenu: false,
    render(host) {
      const editor = new SceneDirectorEditor(ctx, host);
      return () => editor.destroy();
    }
  });
  ctx.menu.registerMenuItem({
    menu: "Mods", label: "Scene Director Studio", icon: "video",
    shortcut: "Ctrl+Shift+D", handler: () => ctx.ui.openPanel(PANEL_ID)
  });
  try { ctx.commands.register("scene-director-studio.open", () => ctx.ui.openPanel(PANEL_ID)); } catch (_) {}
}
