const PATH = "Plugins/[VERMEIL] Smooth Movement/config.ini";
const DEFAULTS = {
  directions: "4", mode: "grid", subtile_divisions: "4",
  instant_turn: "1", wall_slide: "0", smooth_movement: "1",
  camera_smoothing: "35"
};
const RULES = {
  directions: ["4", "8"], mode: ["grid", "free"], subtile_divisions: ["4", "8"],
  instant_turn: ["0", "1"], wall_slide: ["0", "1"], smooth_movement: ["0", "1"]
};
function parse(text) {
  const sections = { global: { ...DEFAULTS } };
  let section = "global";
  for (const raw of text.split(/\r?\n/)) {
    const line = raw.replace(/[;#].*$/, "").trim();
    if (/^\[(global|map:\d+)\]$/i.test(line)) {
      section = line.slice(1, -1).toLowerCase();
      sections[section] ||= {};
    } else {
      const match = /^([a-z_]+)\s*=\s*(.*?)\s*$/.exec(line);
      if (match && Object.hasOwn(DEFAULTS, match[1])) {
        sections[section][match[1]] = match[2];
      }
    }
  }
  return sections;
}
function serialize(sections) {
  const lines = ["; Vermeil Movement Studio v0.1", "; Cambios: reinicia el juego para aplicarlos.", ""];
  for (const [name, opts] of Object.entries(sections)) {
    lines.push("[" + name + "]");
    for (const [key, value] of Object.entries(opts)) lines.push(key + "=" + value);
    lines.push("");
  }
  return lines.join("\n");
}
export function activate(ctx) {
  const state = { config: { global: { ...DEFAULTS } }, loaded: false, mapId: null, host: null };
  const notify = (message, level = "info") => ctx.ui.showToast({ message, level });
  const currentKey = () => state.mapId == null ? "global" : "map:" + state.mapId;
  async function read() {
    try {
      if (await ctx.fs.projectExists(PATH)) {
        state.config = parse(await ctx.fs.readProjectFile(PATH));
      }
    } catch (error) {
      ctx.log.error(error);
      notify("No se pudo cargar config.ini", "error");
    }
    state.loaded = true;
  }
  const buttonStyle = "border:1px solid var(--border);border-radius:5px;padding:7px;background:var(--bg-secondary);color:var(--text-primary);cursor:pointer";
  const inputStyle = "display:block;width:100%;margin:4px 0 10px;padding:7px;box-sizing:border-box;background:var(--input-bg);color:var(--text-primary);border:1px solid var(--border);border-radius:5px";
  const fields = [
    ["directions", "Direcciones", [["4", "4 direcciones (clásico)"], ["8", "8 direcciones (diagonal opcional)"]]],
    ["mode", "Desplazamiento", [["grid", "Por casillas (compatible)"], ["free", "Sub-tile (reservado, sin motor activo)"]]],
    ["subtile_divisions", "Precisión futura sub-tile", [["4", "1/4"], ["8", "1/8"]]],
    ["instant_turn", "Respuesta al girar", [["1", "Inmediata"], ["0", "Retardo clásico"]]],
    ["wall_slide", "Deslizar al bloquearse en diagonal", [["0", "No"], ["1", "Sí"]]],
    ["smooth_movement", "Interpolación original", [["1", "Activada"], ["0", "Reservado; se mantiene Essentials"]]]
  ];
  function option(key, value, label) {
    return '<option value="' + value + '">' + label + '</option>';
  }
  function draw() {
    const host = state.host;
    if (!host) return;
    const key = currentKey();
    const global = state.config.global || DEFAULTS;
    const local = state.config[key] || {};
    const values = { ...global, ...local };
    host.innerHTML = '<div style="padding:12px;font-size:13px;color:var(--text-primary);height:100%;overflow:auto;box-sizing:border-box">' +
      '<h3 style="margin:0 0 8px">Vermeil Movement Studio</h3>' +
      '<p style="color:var(--text-secondary);line-height:1.5">4 direcciones por defecto. Las diagonales se activan sin alterar los eventos normales.</p>' +
      '<label>Configuración a editar</label><select data-scope style="' + inputStyle + '">' +
      option("global", "global", "Global (todos los mapas)") +
      option("map", "map", "Mapa actual: " + String(ctx.editor.activeMapId() ?? "sin mapa")) + '</select>' +
      fields.map(([id, title, items]) => '<label>' + title + '</label><select data-key="' + id + '" style="' + inputStyle + '">' +
        items.map(([value, label]) => option(id, value, label)).join("") + '</select>').join("") +
      '<label>Suavizado de Fancy Camera (0-100%)</label><input type="range" min="0" max="100" step="5" data-key="camera_smoothing" style="width:100%"><output data-camera-value></output>' +
      '<div style="display:flex;gap:6px;margin:15px 0"><button data-save style="' + buttonStyle + ';flex:1">Guardar</button>' +
      '<button data-reset style="' + buttonStyle + '">Restablecer</button></div>' +
      '<p style="color:var(--text-secondary);font-size:11px">Los cambios necesitan reiniciar el juego. El desplazamiento sub-tile todavía es experimental y queda reservado para una versión futura; no se aplica al seleccionar Free.</p></div>';
    const scope = host.querySelector("[data-scope]");
    scope.value = state.mapId === null ? "global" : "map";
    scope.addEventListener("change", () => {
      state.mapId = scope.value === "global" ? null : ctx.editor.activeMapId();
      if (scope.value === "map" && state.mapId == null) {
        notify("Abre primero un mapa", "warn");
        state.mapId = null;
      }
      draw();
    });
    host.querySelectorAll("[data-key]").forEach(el => {
      el.value = values[el.dataset.key];
      el.addEventListener("input", () => {
        const k = currentKey();
        state.config[k] ||= {};
        state.config[k][el.dataset.key] = el.value;
        const out = host.querySelector("[data-camera-value]");
        if (out) out.textContent = host.querySelector('[data-key="camera_smoothing"]').value + "%";
      });
    });
    host.querySelector("[data-camera-value]").textContent = values.camera_smoothing + "%";
    host.querySelector("[data-save]").addEventListener("click", async () => {
      try {
        await ctx.fs.writeProjectFile(PATH, serialize(state.config));
        notify("Configuración guardada; reinicia el juego.");
      } catch (error) {
        ctx.log.error(error);
        notify("No se pudo guardar config.ini", "error");
      }
    });
    host.querySelector("[data-reset]").addEventListener("click", () => {
      if (state.mapId === null) state.config.global = { ...DEFAULTS };
      else delete state.config[currentKey()];
      draw();
    });
  }
  ctx.ui.registerPanel({
    id: "vermeil.movement-studio", title: "Movement Studio",
    defaultPosition: "right", defaultSize: { width: 355, height: 650 },
    render(host) {
      state.host = host;
      if (!state.loaded) read().then(draw);
      else draw();
    }
  });
}
