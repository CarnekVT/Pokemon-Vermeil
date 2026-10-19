const PATH = "Plugins/[VERMEIL] Smooth Movement/config.ini";
const DEFAULTS = {
  directions: "4", mode: "grid", subtile_divisions: "4",
  instant_turn: "1", input_buffer_ms: "0", wall_slide: "0", smooth_movement: "1",
  camera_smoothing: "35"
};
const RULES = {
  directions: ["4", "8"], mode: ["grid", "free"], subtile_divisions: ["4", "8"],
  instant_turn: ["0", "1"], input_buffer_ms: ["0", "60", "100", "150"], wall_slide: ["0", "1"], smooth_movement: ["0", "1"]
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
      if (match && Object.prototype.hasOwnProperty.call(DEFAULTS, match[1])) {
        sections[section][match[1]] = match[2];
      }
    }
  }
  return sections;
}
function serialize(sections) {
  const lines = ["; Vermeil Movement Studio v0.2.2", "; Cambios detectados automaticamente por el runtime.", ""];
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
    ["instant_turn", "Respuesta al girar", [["1", "Inmediata (giro + paso)"], ["0", "Clásica (giro y espera 75 ms)"]]],
    ["input_buffer_ms", "Anticipación de giro (solo modo inmediato)", [["0", "Desactivada (original)"], ["60", "60 ms (precisa)"], ["100", "100 ms (equilibrada)"], ["150", "150 ms (permisiva)"]]],
    ["wall_slide", "Deslizar al bloquearse en diagonal", [["0", "No"], ["1", "Sí"]]]
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
      '<p style="color:var(--text-secondary);line-height:1.5">Mantiene colisiones por casillas. El buffer recuerda una direccion pulsada cerca del final de un paso, sin adelantar eventos o encuentros. Desactivado por defecto.</p>' +
      '<label>Configuración a editar</label><select data-scope style="' + inputStyle + '">' +
      option("global", "global", "Global (todos los mapas)") +
      option("map", "map", "Mapa actual: " + String(ctx.editor.activeMapId() ?? "sin mapa")) + '</select>' +
      fields.map(([id, title, items]) => '<label>' + title + '</label><select data-key="' + id + '" style="' + inputStyle + '">' +
        items.map(([value, label]) => option(id, value, label)).join("") + '</select>').join("") +
      '<div style="margin:10px 0 6px;font-weight:600">Perfiles rápidos (aplicar y luego guardar)</div>' +
      '<div style="display:flex;gap:6px;margin-bottom:12px"><button data-preset="classic" style="' + buttonStyle + ';flex:1">Clásico</button><button data-preset="responsive" style="' + buttonStyle + ';flex:1">Ágil</button></div>' +
      '<label>Camara (0 = rapida, 35 = original, 100 = lenta)</label><input type="range" min="0" max="100" step="5" data-key="camera_smoothing" style="width:100%"><output data-camera-value></output>' +
      '<div style="display:flex;gap:6px;margin:15px 0"><button data-save style="' + buttonStyle + ';flex:1">Guardar</button>' +
      '<button data-reset style="' + buttonStyle + '">Restablecer</button></div>' +
      '<p style="color:var(--text-secondary);font-size:11px">Los cambios se recargan durante la partida. La camara aplica este ajuste al seguimiento final, con Fancy Camera (switch 59) activa o desactivada. Continuidad fisica y sub-tile real aun no implementados.</p></div>';
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
    host.querySelectorAll("[data-preset]").forEach(button => {
      button.addEventListener("click", () => {
        const key = currentKey();
        const preset = button.dataset.preset === "classic" ?
          { directions:"4", instant_turn:"0", input_buffer_ms:"0", wall_slide:"0", camera_smoothing:"35" } :
          { directions:"8", instant_turn:"1", input_buffer_ms:"100", wall_slide:"1", camera_smoothing:"35" };
        state.config[key] = { ...(state.config[key] || {}), ...preset };
        draw();
        notify("Perfil aplicado en el panel. Pulsa Guardar para llevarlo al juego.");
      });
    });
    host.querySelector("[data-save]").addEventListener("click", async () => {
      try {
        const data = serialize(state.config);
        await ctx.fs.writeProjectFile(PATH, data);
        const verified = parse(await ctx.fs.readProjectFile(PATH));
        if (JSON.stringify(verified) !== JSON.stringify(parse(data))) throw new Error("El archivo guardado no coincide con lo solicitado");
        notify("Configuración comprobada en " + PATH + ". Se aplica durante la partida.");
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
