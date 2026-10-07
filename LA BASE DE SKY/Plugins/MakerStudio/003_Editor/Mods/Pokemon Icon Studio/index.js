import { mountPokemonIconStudio } from "./editor.js";

const PANEL_ID = "pokemon-icon-studio";

export function activate(ctx) {
  try { ctx.log.info("Pokémon Icon Studio v0.3.4 activated"); } catch (_) {}

  ctx.ui.registerPanel({
    id: PANEL_ID,
    title: "Pokémon Icon Studio",
    icon: "◫",
    defaultPosition: "right",
    defaultSize: { width: 1500, height: 960 },
    showInMenu: false,
    render: (host) => mountPokemonIconStudio(ctx, host)
  });

  ctx.menu.registerMenuItem({
    menu: "Mods",
    label: "Pokémon Icon Studio",
    icon: "◫",
    shortcut: "Ctrl+Shift+I",
    handler: () => ctx.ui.openPanel(PANEL_ID)
  });

  ctx.commands.register("pokemon-icon-studio.open", () => ctx.ui.openPanel(PANEL_ID));
}
