// Visual 2.5D Volumes - Maker Studio project mod.
// Persiste Volume ID por celda en el JSON propio de Visual 2.5D. Asi el ID
// sirve igual para capas nativas/extendidas y no toca terrain tag, priority,
// passage ni las propiedades de cada tile.

export function activate(ctx) {
  const REGISTRY_PATH = "Plugins/[VERMEIL] Visual 2.5D/volume_ids.json";
  const SIDE_LADDERS_PATH = "Plugins/[VERMEIL] Visual 2.5D/side_ladders.json";
  const PROGRESSIVE_ZOOM_PATH = "Plugins/[VERMEIL] Visual 2.5D/progressive_zoom.json";
  const TOOL_ID = "vermeil.visual-2p5d-volume.paint";
  const state = {
    selectionCount: 0,
    mapId: null,
    volumeId: "",
    zoomPoints: { start: null, middle: null, end: null },
    writeChain: Promise.resolve()
  };

  function selectedTiles() {
    const mapId = ctx.editor.activeMapId();
    if (mapId == null) return [];
    return ctx.map.selectionTiles(mapId) || [];
  }

  function selectedCount() {
    const mapId = ctx.editor.activeMapId();
    return mapId == null ? 0 : (ctx.map.selection(mapId)?.count || 0);
  }

  function showToast(message, level = "info") {
    ctx.ui.showToast({ message, level });
  }

  function cleanId(value) {
    return String(value || "").trim();
  }

  async function readJson(path) {
    const parsed = JSON.parse(await ctx.fs.readProjectFile(path));
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed) ||
        !parsed.maps || typeof parsed.maps !== "object" || Array.isArray(parsed.maps)) {
      throw new Error(`Registro invalido: ${path}`);
    }
    return parsed;
  }

  function enqueueWrite(task) {
    const operation = state.writeChain.then(task);
    state.writeChain = operation.catch(() => {});
    return operation;
  }

  async function readRegistry() {
    return readJson(REGISTRY_PATH);
  }

  async function writeRegistry(registry) {
    registry.version = 1;
    registry.maps ||= {};
    await ctx.fs.writeProjectFile(REGISTRY_PATH, `${JSON.stringify(registry, null, 2)}\n`);
  }

  async function readSideLadders() {
    return readJson(SIDE_LADDERS_PATH);
  }

  async function writeSideLadders(registry) {
    registry.version = 1;
    registry.maps ||= {};
    await ctx.fs.writeProjectFile(SIDE_LADDERS_PATH, `${JSON.stringify(registry, null, 2)}\n`);
  }

  async function readProgressiveZoom() {
    return readJson(PROGRESSIVE_ZOOM_PATH);
  }

  async function writeProgressiveZoom(registry) {
    registry.version = 1;
    registry.maps ||= {};
    await ctx.fs.writeProjectFile(PROGRESSIVE_ZOOM_PATH, `${JSON.stringify(registry, null, 2)}\n`);
  }

  function selectedCells() {
    return [...new Set(selectedTiles().map((tile) => `${tile.x},${tile.y}`))];
  }

  function selectedPoint() {
    const cells = selectedCells();
    if (cells.length !== 1) return null;
    return cells[0].split(",").map(Number);
  }

  function pointText(point) {
    return point ? `${point[0]}, ${point[1]}` : "sin definir";
  }

  function updateZoomPointStatus(host) {
    ["start", "middle", "end"].forEach((kind) => {
      const output = host.querySelector(`[data-zoom-${kind}-value]`);
      if (output) output.textContent = pointText(state.zoomPoints[kind]);
    });
  }

  function captureZoomPoint(kind, host) {
    const point = selectedPoint();
    if (!point) return showToast("Selecciona exactamente una celda", "warn");
    state.zoomPoints[kind] = point;
    updateZoomPointStatus(host);
  }

  function directionVector(direction) {
    return {
      left: [-1, 0], right: [1, 0], up: [0, -1], down: [0, 1]
    }[direction];
  }

  function pointAxis(point, vector) {
    return point[0] * vector[0] + point[1] * vector[1];
  }

  async function saveZoomProfile(rawId, direction, rawZoom) {
    const profileId = cleanId(rawId);
    const mapId = ctx.editor.activeMapId();
    const cells = selectedCells();
    const middleZoom = Number(rawZoom);
    const vector = directionVector(direction);
    const { start, middle, end } = state.zoomPoints;
    if (mapId == null) return showToast("Abre un mapa primero", "warn");
    if (!profileId) return showToast("Escribe un ID de tramo", "warn");
    if (!cells.length) return showToast("Selecciona toda la zona del tramo", "warn");
    if (!vector || !start || !middle || !end) return showToast("Define inicio, intermedio y final", "warn");
    if (!Number.isFinite(middleZoom) || middleZoom < 0.25 || middleZoom > 3) {
      return showToast("Zoom intermedio invalido (0.25 - 3.00)", "warn");
    }

    const startAxis = pointAxis(start, vector);
    const middleAxis = pointAxis(middle, vector);
    const endAxis = pointAxis(end, vector);
    if (!(startAxis < middleAxis && middleAxis < endAxis)) {
      return showToast("Los puntos no siguen la direccion elegida", "warn");
    }
    const selected = new Set(cells);
    if (![start, middle, end].every((point) => selected.has(`${point[0]},${point[1]}`))) {
      return showToast("Los tres puntos deben estar dentro de la zona seleccionada", "warn");
    }

    try {
      await enqueueWrite(async () => {
        const registry = await readProgressiveZoom();
        const map = registry.maps[String(mapId)] ||= { profiles: {} };
        map.profiles ||= {};
        for (const [otherId, profile] of Object.entries(map.profiles)) {
          if (otherId === profileId) continue;
          if ((profile.cells || []).some((cell) => selected.has(cell))) {
            return showToast(`La zona se cruza con '${otherId}'`, "warn");
          }
        }
        map.profiles[profileId] = {
          direction,
          start,
          middle,
          end,
          middleZoom,
          cells: cells.sort((a, b) => {
            const [ax, ay] = a.split(",").map(Number);
            const [bx, by] = b.split(",").map(Number);
            return ay - by || ax - bx;
          })
        };
        await writeProgressiveZoom(registry);
        showToast(`Tramo '${profileId}' guardado con ${cells.length} celda(s)`);
      });
    } catch (error) {
      ctx.log.error(error);
      showToast("No se pudo guardar progressive_zoom.json", "error");
    }
  }

  async function loadZoomProfile(rawId, controls, host) {
    const profileId = cleanId(rawId);
    const mapId = ctx.editor.activeMapId();
    if (mapId == null) return showToast("Abre un mapa primero", "warn");
    if (!profileId) return showToast("Escribe un ID de tramo", "warn");
    try {
      const registry = await readProgressiveZoom();
      const profile = registry.maps?.[String(mapId)]?.profiles?.[profileId];
      if (!profile) return showToast(`No existe el tramo '${profileId}'`, "warn");
      state.zoomPoints = {
        start: profile.start || null,
        middle: profile.middle || null,
        end: profile.end || null
      };
      controls.direction.value = profile.direction || "right";
      controls.zoom.value = profile.middleZoom ?? 0.7;
      updateZoomPointStatus(host);
      showToast(`Tramo '${profileId}' cargado (${(profile.cells || []).length} celdas)`);
    } catch (error) {
      ctx.log.error(error);
      showToast("No se pudo leer progressive_zoom.json", "error");
    }
  }

  async function removeZoomProfile(rawId) {
    const profileId = cleanId(rawId);
    const mapId = ctx.editor.activeMapId();
    if (mapId == null) return showToast("Abre un mapa primero", "warn");
    if (!profileId) return showToast("Escribe un ID de tramo", "warn");
    try {
      await enqueueWrite(async () => {
        const registry = await readProgressiveZoom();
        const map = registry.maps?.[String(mapId)];
        if (!map?.profiles?.[profileId]) return showToast(`No existe el tramo '${profileId}'`, "warn");
        delete map.profiles[profileId];
        if (!Object.keys(map.profiles).length && !Object.keys(map.zones || {}).length) {
          delete registry.maps[String(mapId)];
        }
        await writeProgressiveZoom(registry);
        showToast(`Tramo '${profileId}' quitado`);
      });
    } catch (error) {
      ctx.log.error(error);
      showToast("No se pudo guardar progressive_zoom.json", "error");
    }
  }

  async function saveZoomZone(rawId, rawZoom) {
    const zoneId = cleanId(rawId);
    const mapId = ctx.editor.activeMapId();
    const cells = selectedCells();
    const zoom = Number(rawZoom);
    if (mapId == null) return showToast("Abre un mapa primero", "warn");
    if (!zoneId) return showToast("Escribe un ID de zona", "warn");
    if (!cells.length) return showToast("Selecciona toda la zona", "warn");
    if (!Number.isFinite(zoom) || zoom < 0.25 || zoom > 3) {
      return showToast("Zoom de zona invalido (0.25 - 3.00)", "warn");
    }

    const selected = new Set(cells);
    try {
      await enqueueWrite(async () => {
        const registry = await readProgressiveZoom();
        const map = registry.maps[String(mapId)] ||= { profiles: {}, zones: {} };
        map.zones ||= {};
        for (const [otherId, zone] of Object.entries(map.zones)) {
          if (otherId === zoneId) continue;
          if ((zone.cells || []).some((cell) => selected.has(cell))) {
            return showToast(`La zona se cruza con '${otherId}'`, "warn");
          }
        }
        map.zones[zoneId] = { zoom, cells };
        await writeProgressiveZoom(registry);
        showToast(`Zona '${zoneId}' guardada con zoom ${zoom.toFixed(2)}`);
      });
    } catch (error) {
      ctx.log.error(error);
      showToast("No se pudo guardar progressive_zoom.json", "error");
    }
  }

  async function loadZoomZone(rawId, zoomInput) {
    const zoneId = cleanId(rawId);
    const mapId = ctx.editor.activeMapId();
    if (mapId == null) return showToast("Abre un mapa primero", "warn");
    if (!zoneId) return showToast("Escribe un ID de zona", "warn");
    try {
      const registry = await readProgressiveZoom();
      const zone = registry.maps?.[String(mapId)]?.zones?.[zoneId];
      if (!zone) return showToast(`No existe la zona '${zoneId}'`, "warn");
      zoomInput.value = zone.zoom ?? 1;
      showToast(`Zona '${zoneId}' cargada (${(zone.cells || []).length} celdas)`);
    } catch (error) {
      ctx.log.error(error);
      showToast("No se pudo leer progressive_zoom.json", "error");
    }
  }

  async function removeZoomZone(rawId) {
    const zoneId = cleanId(rawId);
    const mapId = ctx.editor.activeMapId();
    if (mapId == null) return showToast("Abre un mapa primero", "warn");
    if (!zoneId) return showToast("Escribe un ID de zona", "warn");
    try {
      await enqueueWrite(async () => {
        const registry = await readProgressiveZoom();
        const map = registry.maps?.[String(mapId)];
        if (!map?.zones?.[zoneId]) return showToast(`No existe la zona '${zoneId}'`, "warn");
        delete map.zones[zoneId];
        if (!Object.keys(map.zones).length && !Object.keys(map.profiles || {}).length) {
          delete registry.maps[String(mapId)];
        }
        await writeProgressiveZoom(registry);
        showToast(`Zona '${zoneId}' quitada`);
      });
    } catch (error) {
      ctx.log.error(error);
      showToast("No se pudo guardar progressive_zoom.json", "error");
    }
  }

  async function setCells(mapId, cells, volumeId) {
    return enqueueWrite(async () => {
      const registry = await readRegistry();
      const map = registry.maps[String(mapId)] ||= {};
      cells.forEach((cell) => { map[cell] = volumeId; });
      await writeRegistry(registry);
    });
  }

  async function applyToSelection(rawId) {
    const volumeId = cleanId(rawId);
    const mapId = ctx.editor.activeMapId();
    const cells = selectedCells();
    if (mapId == null) return showToast("Abre un mapa primero", "warn");
    if (!cells.length) return showToast("Selecciona las piezas del objeto", "warn");
    if (!volumeId) return showToast("Escribe un Volume ID", "warn");

    try {
      await setCells(mapId, cells, volumeId);
      showToast(`Volume ID '${volumeId}' asignado a ${cells.length} celda(s)`);
    } catch (error) {
      ctx.log.error(error);
      showToast("No se pudo guardar volume_ids.json", "error");
    }
    ctx.editor.requestRedraw?.();
  }

  async function removeFromSelection() {
    const mapId = ctx.editor.activeMapId();
    const cells = selectedCells();
    if (mapId == null) return showToast("Abre un mapa primero", "warn");
    if (!cells.length) return showToast("Selecciona las piezas del objeto", "warn");

    try {
      await enqueueWrite(async () => {
        const registry = await readRegistry();
        const map = registry.maps[String(mapId)] || {};
        cells.forEach((cell) => { delete map[cell]; });
        if (Object.keys(map).length) registry.maps[String(mapId)] = map;
        else delete registry.maps[String(mapId)];
        await writeRegistry(registry);
      });
      showToast(`Volume ID quitado de ${cells.length} celda(s)`);
    } catch (error) {
      ctx.log.error(error);
      showToast("No se pudo guardar volume_ids.json", "error");
    }
    ctx.editor.requestRedraw?.();
  }

  async function setSideLadderDirection(rawSlope) {
    const mapId = ctx.editor.activeMapId();
    const cells = selectedCells();
    const slope = Number(rawSlope);
    if (mapId == null) return showToast("Abre un mapa primero", "warn");
    if (!cells.length) return showToast("Selecciona tramos de escalera en el mapa", "warn");
    if (slope !== -1 && slope !== 1) return showToast("Direccion de escalera invalida", "warn");

    try {
      await enqueueWrite(async () => {
        const registry = await readSideLadders();
        const map = registry.maps[String(mapId)] ||= {};
        cells.forEach((cell) => { map[cell] = slope; });
        await writeSideLadders(registry);
      });
      showToast(`Direccion lateral asignada a ${cells.length} celda(s)`);
    } catch (error) {
      ctx.log.error(error);
      showToast("No se pudo guardar side_ladders.json", "error");
    }
  }

  async function clearSideLadderDirection() {
    const mapId = ctx.editor.activeMapId();
    const cells = selectedCells();
    if (mapId == null) return showToast("Abre un mapa primero", "warn");
    if (!cells.length) return showToast("Selecciona tramos de escalera en el mapa", "warn");

    try {
      await enqueueWrite(async () => {
        const registry = await readSideLadders();
        const map = registry.maps[String(mapId)] || {};
        cells.forEach((cell) => { delete map[cell]; });
        if (Object.keys(map).length) registry.maps[String(mapId)] = map;
        else delete registry.maps[String(mapId)];
        await writeSideLadders(registry);
      });
      showToast(`Direccion lateral quitada de ${cells.length} celda(s)`);
    } catch (error) {
      ctx.log.error(error);
      showToast("No se pudo guardar side_ladders.json", "error");
    }
  }

  function updateStatus(status) {
    state.mapId = ctx.editor.activeMapId();
    state.selectionCount = selectedCount();
    if (status) status.textContent = state.mapId == null
      ? "Sin mapa abierto"
      : `${state.selectionCount} tile(s) seleccionado(s). Herramienta: ${ctx.editor.activeTool()}`;
  }

  function activatePaintTool(rawId) {
    const volumeId = cleanId(rawId);
    if (!volumeId) return showToast("Escribe un Volume ID", "warn");
    state.volumeId = volumeId;
    ctx.editor.setTool(TOOL_ID);
    showToast(`Pincel Volume ID '${volumeId}' activo. Clic en cada celda del objeto.`);
  }

  ctx.tools.registerTool({
    id: TOOL_ID,
    label: "Pincel Volume ID 2.5D",
    icon: "★",
    onPointerDown(ev) {
      const volumeId = cleanId(state.volumeId);
      if (!volumeId) return showToast("Abre Visual 2.5D y escribe un Volume ID", "warn");
      const cell = `${ev.tileX},${ev.tileY}`;
      setCells(ev.mapId, [cell], volumeId).then(() => {
        ctx.editor.requestRedraw?.();
      }).catch((error) => {
        ctx.log.error(error);
        showToast("No se pudo guardar volume_ids.json", "error");
      });
    }
  });

  ctx.ui.registerPanel({
    id: "vermeil.visual-2p5d-volume",
    title: "Visual 2.5D",
    defaultPosition: "right",
    defaultSize: { width: 320, height: 800 },
    render(host) {
      host.innerHTML = `
        <div style="box-sizing:border-box;height:100%;overflow-y:auto;padding:10px;font:13px inherit;color:var(--text-primary)">
          <div style="font-weight:600;margin-bottom:8px">VOLUME ID 2.5D</div>
          <div style="color:var(--text-secondary);margin-bottom:10px">
            Mismo ID une piezas de un objeto. ID distinto separa objetos aunque
            compartan terrain tag o esten pegados.
          </div>
          <label style="display:block;margin-bottom:4px">ID del objeto</label>
          <input data-volume-id type="text" placeholder="casa_01"
            style="box-sizing:border-box;width:100%;padding:6px;background:var(--input-bg);color:var(--text-primary);border:1px solid var(--border);border-radius:4px">
          <div data-status style="margin:8px 0;color:var(--text-tertiary)"></div>
          <div style="display:flex;gap:6px">
            <button data-apply style="flex:1;padding:6px;border:0;border-radius:4px;background:var(--accent);color:var(--accent-text);cursor:pointer">Asignar</button>
            <button data-paint style="padding:6px;border:1px solid var(--border);border-radius:4px;background:var(--bg-secondary);color:var(--text-primary);cursor:pointer">Pincel ID</button>
            <button data-remove style="padding:6px;border:1px solid var(--border);border-radius:4px;background:var(--bg-secondary);color:var(--text-primary);cursor:pointer">Quitar</button>
          </div>
          <div style="margin-top:10px;color:var(--text-tertiary);font-size:12px">
            Asignar usa seleccion rectangular. Pincel ID marca una celda por clic.
          </div>
          <hr style="border:0;border-top:1px solid var(--border);margin:12px 0">
          <div style="font-weight:600;margin-bottom:8px">ESCALERA LATERAL</div>
          <div style="color:var(--text-secondary);margin-bottom:10px">
            Solo para terrain tag LaddersSide. Marca tramos de misma pendiente;
            no crea otro terrain tag ni cambia pasabilidad.
          </div>
          <select data-side-ladder
            style="box-sizing:border-box;width:100%;padding:6px;background:var(--input-bg);color:var(--text-primary);border:1px solid var(--border);border-radius:4px">
            <option value="-1">Sube a derecha (&#8599;)</option>
            <option value="1">Baja a derecha (&#8600;)</option>
          </select>
          <div style="display:flex;gap:6px;margin-top:6px">
            <button data-side-apply style="flex:1;padding:6px;border:0;border-radius:4px;background:var(--accent);color:var(--accent-text);cursor:pointer">Asignar direccion</button>
            <button data-side-remove style="padding:6px;border:1px solid var(--border);border-radius:4px;background:var(--bg-secondary);color:var(--text-primary);cursor:pointer">Usar default</button>
          </div>
          <div style="margin-top:8px;color:var(--text-tertiary);font-size:12px">
            Default: sube a derecha. Usa seleccion rectangular sobre todos los tramos inversos.
          </div>
          <hr style="border:0;border-top:1px solid var(--border);margin:12px 0">
          <div style="font-weight:600;margin-bottom:8px">ZOOM PROGRESIVO</div>
          <div style="color:var(--text-secondary);margin-bottom:10px">
            Inicio y final usan zoom base. Intermedio marca maxima cercania o lejania.
          </div>
          <label style="display:block;margin-bottom:4px">ID del tramo</label>
          <input data-zoom-id type="text" placeholder="puente_grande"
            style="box-sizing:border-box;width:100%;padding:6px;background:var(--input-bg);color:var(--text-primary);border:1px solid var(--border);border-radius:4px">
          <div style="display:flex;gap:6px;margin-top:6px">
            <select data-zoom-direction style="flex:1;padding:6px;background:var(--input-bg);color:var(--text-primary);border:1px solid var(--border);border-radius:4px">
              <option value="right">Hacia derecha</option>
              <option value="left">Hacia izquierda</option>
              <option value="down">Hacia abajo</option>
              <option value="up">Hacia arriba</option>
            </select>
            <input data-zoom-middle type="number" min="0.25" max="3" step="0.05" value="0.70"
              title="Zoom intermedio" style="box-sizing:border-box;width:82px;padding:6px;background:var(--input-bg);color:var(--text-primary);border:1px solid var(--border);border-radius:4px">
          </div>
          <div style="display:grid;grid-template-columns:auto 1fr;gap:5px 8px;margin-top:8px;align-items:center">
            <button data-zoom-start style="padding:5px;border:1px solid var(--border);border-radius:4px;background:var(--bg-secondary);color:var(--text-primary);cursor:pointer">Tomar inicio</button>
            <span data-zoom-start-value style="color:var(--text-tertiary)">sin definir</span>
            <button data-zoom-middle-point style="padding:5px;border:1px solid var(--border);border-radius:4px;background:var(--bg-secondary);color:var(--text-primary);cursor:pointer">Tomar intermedio</button>
            <span data-zoom-middle-value style="color:var(--text-tertiary)">sin definir</span>
            <button data-zoom-end style="padding:5px;border:1px solid var(--border);border-radius:4px;background:var(--bg-secondary);color:var(--text-primary);cursor:pointer">Tomar final</button>
            <span data-zoom-end-value style="color:var(--text-tertiary)">sin definir</span>
          </div>
          <div style="display:flex;gap:6px;margin-top:8px">
            <button data-zoom-save style="flex:1;padding:6px;border:0;border-radius:4px;background:var(--accent);color:var(--accent-text);cursor:pointer">Guardar zona</button>
            <button data-zoom-load style="padding:6px;border:1px solid var(--border);border-radius:4px;background:var(--bg-secondary);color:var(--text-primary);cursor:pointer">Cargar</button>
            <button data-zoom-remove style="padding:6px;border:1px solid var(--border);border-radius:4px;background:var(--bg-secondary);color:var(--text-primary);cursor:pointer">Quitar</button>
          </div>
          <div style="margin-top:8px;color:var(--text-tertiary);font-size:12px">
            Toma cada punto con una celda seleccionada. Despues selecciona todo el ancho y largo del tramo antes de Guardar zona.
          </div>
          <hr style="border:0;border-top:1px solid var(--border);margin:12px 0">
          <div style="font-weight:600;margin-bottom:8px">ZONA DE ZOOM FIJO</div>
          <div style="color:var(--text-secondary);margin-bottom:10px">
            Mantiene otro zoom mientras el jugador permanezca dentro. Un tramo progresivo superpuesto parte desde este zoom.
          </div>
          <div style="display:flex;gap:6px">
            <input data-zone-id type="text" placeholder="interior_puente"
              style="box-sizing:border-box;flex:1;min-width:0;padding:6px;background:var(--input-bg);color:var(--text-primary);border:1px solid var(--border);border-radius:4px">
            <input data-zone-zoom type="number" min="0.25" max="3" step="0.05" value="0.80"
              title="Zoom de zona" style="box-sizing:border-box;width:82px;padding:6px;background:var(--input-bg);color:var(--text-primary);border:1px solid var(--border);border-radius:4px">
          </div>
          <div style="display:flex;gap:6px;margin-top:8px">
            <button data-zone-save style="flex:1;padding:6px;border:0;border-radius:4px;background:var(--accent);color:var(--accent-text);cursor:pointer">Guardar zona</button>
            <button data-zone-load style="padding:6px;border:1px solid var(--border);border-radius:4px;background:var(--bg-secondary);color:var(--text-primary);cursor:pointer">Cargar</button>
            <button data-zone-remove style="padding:6px;border:1px solid var(--border);border-radius:4px;background:var(--bg-secondary);color:var(--text-primary);cursor:pointer">Quitar</button>
          </div>
        </div>`;

      const input = host.querySelector("[data-volume-id]");
      const status = host.querySelector("[data-status]");
      host.querySelector("[data-apply]").addEventListener("click", async () => {
        await applyToSelection(input.value);
        updateStatus(status);
      });
      host.querySelector("[data-paint]").addEventListener("click", () => {
        activatePaintTool(input.value);
        updateStatus(status);
      });
      host.querySelector("[data-remove]").addEventListener("click", async () => {
        await removeFromSelection();
        updateStatus(status);
      });
      const sideLadder = host.querySelector("[data-side-ladder]");
      host.querySelector("[data-side-apply]").addEventListener("click", async () => {
        await setSideLadderDirection(sideLadder.value);
        updateStatus(status);
      });
      host.querySelector("[data-side-remove]").addEventListener("click", async () => {
        await clearSideLadderDirection();
        updateStatus(status);
      });
      const zoomId = host.querySelector("[data-zoom-id]");
      const zoomDirection = host.querySelector("[data-zoom-direction]");
      const zoomMiddle = host.querySelector("[data-zoom-middle]");
      const zoomControls = { direction: zoomDirection, zoom: zoomMiddle };
      host.querySelector("[data-zoom-start]").addEventListener("click", () => captureZoomPoint("start", host));
      host.querySelector("[data-zoom-middle-point]").addEventListener("click", () => captureZoomPoint("middle", host));
      host.querySelector("[data-zoom-end]").addEventListener("click", () => captureZoomPoint("end", host));
      host.querySelector("[data-zoom-save]").addEventListener("click", async () => {
        await saveZoomProfile(zoomId.value, zoomDirection.value, zoomMiddle.value);
      });
      host.querySelector("[data-zoom-load]").addEventListener("click", async () => {
        await loadZoomProfile(zoomId.value, zoomControls, host);
      });
      host.querySelector("[data-zoom-remove]").addEventListener("click", async () => {
        await removeZoomProfile(zoomId.value);
      });
      const zoneId = host.querySelector("[data-zone-id]");
      const zoneZoom = host.querySelector("[data-zone-zoom]");
      host.querySelector("[data-zone-save]").addEventListener("click", async () => {
        await saveZoomZone(zoneId.value, zoneZoom.value);
      });
      host.querySelector("[data-zone-load]").addEventListener("click", async () => {
        await loadZoomZone(zoneId.value, zoneZoom);
      });
      host.querySelector("[data-zone-remove]").addEventListener("click", async () => {
        await removeZoomZone(zoneId.value);
      });
      updateStatus(status);
      updateZoomPointStatus(host);
      const listener = () => updateStatus(status);
      const unselect = ctx.bus.on("selection.changed", listener);
      const unload = ctx.bus.on("map.loaded", () => {
        state.zoomPoints = { start: null, middle: null, end: null };
        updateZoomPointStatus(host);
        updateStatus(status);
      });
      return () => { unselect.dispose(); unload.dispose(); };
    }
  });

  ctx.ui.registerContextMenuItem({
    context: "map-tile",
    label: "Visual 2.5D: asignar Volume ID…",
    handler: async (info) => {
      const value = await ctx.ui.showInputDialog({
        title: "Visual 2.5D Volume ID",
        message: "ID unico del objeto (ej. casa_01):"
      });
      const volumeId = cleanId(value);
      if (!volumeId) return;
      try {
        await setCells(info.mapId, [`${info.tileX},${info.tileY}`], volumeId);
        showToast(`Volume ID '${volumeId}' asignado`);
      } catch (error) {
        ctx.log.error(error);
        showToast("No se pudo guardar volume_ids.json", "error");
      }
    }
  });
}
