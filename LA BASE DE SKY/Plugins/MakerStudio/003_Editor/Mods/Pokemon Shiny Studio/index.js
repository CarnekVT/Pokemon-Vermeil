import { mountPokemonShinyStudio } from "./editor.js";

const PANEL_ID = "pokemon-shiny-studio";

export function activate(ctx) {
  try {
    ctx.log?.info?.("Pokémon Shiny Studio v1.0.0 activado");
  } catch (_) {}

  ctx.ui.registerPanel({
    id: PANEL_ID,
    title: "Pokémon Shiny Studio",
    icon: "✦",
    defaultPosition: "center",
    defaultSize: { width: 1500, height: 960 },
    showInMenu: false,
    render: (host) => mountPokemonShinyStudio(ctx, host)
  });

  ctx.menu.registerMenuItem({
    menu: "Mods",
    label: "Pokémon Shiny Studio",
    icon: "✦",
    shortcut: "Ctrl+Shift+Y",
    handler: () => ctx.ui.openPanel(PANEL_ID)
  });

  ctx.commands.register("pokemon-shiny-studio.open", () => ctx.ui.openPanel(PANEL_ID));
}
