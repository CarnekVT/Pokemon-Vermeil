import { mountFriendly as mount, focusEvent } from "./friendly-ui.js";
import { registerPickerCommands } from "./picker-commands.js";
import { registerPlacementTool } from "./placement.js";

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
        const detail = String(err?.stack || err?.message || err);
        try { ctx.log?.error?.("[Command Studio] Error al iniciar: " + detail); } catch (_) {}
        try { console.error("[Command Studio] Error al iniciar", err); } catch (_) {}
        host.replaceChildren();
        const heading = document.createElement("h3");
        heading.textContent = "No se pudo iniciar Command Studio";
        const explanation = document.createElement("p");
        explanation.textContent = "Copia el diagnóstico para identificar qué función falló.";
        const diagnostic = document.createElement("pre");
        diagnostic.textContent = detail.slice(0, 1800);
        diagnostic.style.cssText = "white-space:pre-wrap;overflow:auto;max-height:240px;padding:12px;";
        host.append(heading, explanation, diagnostic);
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
  registerPlacementTool(ctx);
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
  ctx.log?.info?.("Command Studio 0.9.2: búsqueda por intención, secuencias editables e inserción directa.");
}
export function deactivate() {}
