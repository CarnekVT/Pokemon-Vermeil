import { mount, focusEvent } from "./smart-ui.js";
import { registerPickerCommands } from "./picker-commands.js";

const PANEL = "com.carnek.command-studio.panel";

function open(ctx) { return ctx.ui.openPanel(PANEL); }

export function activate(ctx) {
  ctx.ui.registerPanel({
    id: PANEL, title: "Command Studio", icon: "terminal",
    defaultPosition: "right", defaultSize: { width: 1580, height: 940 },
    showInMenu: !(ctx.menu && typeof ctx.menu.registerMenuItem === "function"),
    render(host) {
      try { return mount(ctx, host); }
      catch (err) {
        ctx.log?.error?.(err);
        host.textContent = "Error de Command Studio: " + String(err?.message || err);
        return () => {};
      }
    }
  });
  if (ctx.menu?.registerMenuItem) {
    ctx.menu.registerMenuItem({ menu: "Mods", label: "Command Studio", icon: "terminal",
      handler: () => open(ctx) });
    ctx.menu.registerMenuItem({ menu: "Tools", label: "Command Studio", icon: "terminal",
      handler: () => open(ctx) });
  }
  if (ctx.commands?.register)
    ctx.commands.register("com.carnek.command-studio.open", () => open(ctx));
  registerPickerCommands(ctx);
  if(ctx.ui?.registerContextMenuItem){
    ctx.ui.registerContextMenuItem({
      context: "map-event", label: "Editar con Command Studio",
      handler: info => {
        const mapId=Number(info?.mapId??ctx.editor?.activeMapId?.());
        const eventId=Number(info?.eventId??info?.id);
        if(Number.isInteger(mapId)&&Number.isInteger(eventId)&&eventId>0)focusEvent(mapId,eventId);
        open(ctx);
      }
    });
  }
  ctx.log?.info?.("Command Studio 0.4.0: búsqueda por intención, secuencias editables e inserción directa.");
}
export function deactivate() {}
