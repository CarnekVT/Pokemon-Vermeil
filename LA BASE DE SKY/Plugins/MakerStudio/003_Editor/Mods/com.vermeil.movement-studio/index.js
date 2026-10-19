const PATH = "Plugins/[VERMEIL] Smooth Movement/config.ini";
const DEFAULTS = {
  directions: "4", mode: "grid", subtile_divisions: "4",
  instant_turn: "1", flow_motion: "0", camera_lookahead: "0", wall_slide: "0",
  camera_smoothing: "35",
  diagonal_facing: "keep", wall_slide_priority: "horizontal",
  camera_deadzone: "0", camera_lead_response: "120", debug_hud: "0"
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
  const lines = ["; Vermeil Movement Studio v0.5.0", "; Cambios detectados automaticamente por el runtime.", ""];
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
    ["directions", "Direcciones (solo control Moderno)", [["4", "4 cardinales"], ["8", "8 con diagonales"]]],
    ["instant_turn", "Control", [["1", "Moderno: inmediato (sin espera)"], ["0", "Clásico: Essentials original"]]],
    ["flow_motion", "Movimiento continuo (solo Moderno)", [["0", "Estándar: pasos separados"], ["1", "Fluido: encadenar pasos con tiempo sobrante"]]],
    ["camera_lookahead", "Anticipación visual de cámara", [["0", "Centrada (original)"], ["8", "8 píxeles"], ["16", "16 píxeles"], ["24", "24 píxeles"], ["32", "32 píxeles"]]],
    ["wall_slide", "Deslizar al bloquearse en diagonal", [["0", "No"], ["1", "Sí"]]],
    ["wall_slide_priority", "Eje preferente al deslizar", [["horizontal", "Horizontal (original)"], ["vertical", "Vertical"], ["facing", "Según orientación del personaje"]]],
    ["diagonal_facing", "Orientación visual en diagonales", [["keep", "Mantener dirección (original)"], ["horizontal", "Priorizar izquierda / derecha"], ["vertical", "Priorizar arriba / abajo"]]]
  ];
  const cameraFields = [
    ["camera_deadzone", "Zona muerta de cámara", [["0", "Desactivada (original)"], ["8", "8 píxeles"], ["16", "16 píxeles"], ["24", "24 píxeles"], ["32", "32 píxeles"]]],
    ["camera_lead_response", "Respuesta de anticipación visual", [["60", "Rápida (60 ms)"], ["120", "Normal (120 ms)"], ["200", "Suave (200 ms)"]]]
  ];
  const debugFields = [
    ["debug_hud", "HUD de diagnóstico (solo en Debug)", [["0", "Oculto"], ["1", "Mostrar métricas en pantalla"]]]
  ];
  const renderField = ([id, title, items]) => '<label>' + title + '</label><select data-key="' + id + '" style="' + inputStyle + '">' +
    items.map(([value, label]) => option(id, value, label)).join("") + '</select>';
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
      '<p style="color:var(--text-secondary);line-height:1.5">Movimiento inmediato: no retiene teclas ni introduce espera. Fluid Motion enlaza pasos respetando eventos, seguidores y encuentros. El modo Clásico conserva el comportamiento original de Essentials.</p>' +
      '<label>Configuración a editar</label><select data-scope style="' + inputStyle + '">' +
      option("global", "global", "Global (todos los mapas)") +
      option("map", "map", "Mapa actual: " + String(ctx.editor.activeMapId() ?? "sin mapa")) + '</select>' +
      '<div style="font-weight:600;margin:12px 0 6px">CONTROL DEL JUGADOR</div>' +
      fields.map(renderField).join("") +
      '<div data-preview style="margin:8px 0;padding:8px;border:1px solid var(--border);border-radius:4px;color:var(--text-secondary);font-size:12px"></div>' +
      '<div style="margin:10px 0 6px;font-weight:600">Perfiles rápidos (aplicar, luego guardar)</div>' +
      '<div style="display:flex;gap:6px;margin-bottom:12px"><button data-preset="classic" style="' + buttonStyle + ';flex:1">Clásico</button><button data-preset="responsive" style="' + buttonStyle + ';flex:1">Moderno</button></div>' +
      '<div style="font-weight:600;margin:12px 0 6px">CAMARA</div>' +
      cameraFields.map(renderField).join("") +
      '<label>Camara (0 = rapida, 35 = original, 100 = lenta)</label><input type="range" min="0" max="100" step="5" data-key="camera_smoothing" style="width:100%"><output data-camera-value></output>' +
      '<div style="font-weight:600;margin:12px 0 6px">DIAGNÓSTICO</div>' +
      debugFields.map(renderField).join("") +
      '<div style="display:flex;gap:6px;margin:15px 0"><button data-save style="' + buttonStyle + ';flex:1">Guardar</button>' +
      '<button data-reset style="' + buttonStyle + '">Restablecer</button></div>' +
      '<p style="color:var(--text-secondary);font-size:11px">Los cambios se recargan durante la partida. Continuidad entre casillas disponible con Control Moderno; conserva colisiones y eventos por tiles. Movimiento libre sub-tile todavia no disponible.</p></div>';
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
        updatePreview();
        const out = host.querySelector("[data-camera-value]");
        if (out) out.textContent = host.querySelector('[data-key="camera_smoothing"]').value + "%";
      });
    });
    function updatePreview() {
      const settings = { ...DEFAULTS, ...(state.config.global || {}), ...(state.config[currentKey()] || {}) };
      const classic = settings.instant_turn === "0";
      const directions = classic ? "4 direcciones" : settings.directions + " direcciones";
      const flow = !classic && settings.flow_motion === "1" ? "Flow activo" : "Flow desactivado";
      const camera = settings.camera_lookahead + "px de anticipación";
      const zone = settings.camera_deadzone + "px zona muerta";
      const hud = settings.debug_hud === "1" ? " · HUD Debug" : "";
      host.querySelector("[data-preview]").textContent =
        (classic ? "Clásico original" : "Moderno inmediato") + " · " + directions + " · " + flow + " · " + camera + " · " + zone + hud;
    }
    updatePreview();
    host.querySelector("[data-camera-value]").textContent = values.camera_smoothing + "%";
    host.querySelectorAll("[data-preset]").forEach(button => {
      button.addEventListener("click", () => {
        const key = currentKey();
        const preset = button.dataset.preset === "classic" ?
          { directions:"4", instant_turn:"0", flow_motion:"0", camera_lookahead:"0", wall_slide:"0", wall_slide_priority:"horizontal", diagonal_facing:"keep", camera_deadzone:"0", camera_lead_response:"120", camera_smoothing:"35", debug_hud:"0" } :
          { directions:"8", instant_turn:"1", flow_motion:"1", camera_lookahead:"16", wall_slide:"1", wall_slide_priority:"facing", diagonal_facing:"keep", camera_deadzone:"8", camera_lead_response:"120", camera_smoothing:"35", debug_hud:"0" };
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
