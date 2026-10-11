export function activate(ctx) {
  // ── Estado ──
  const S = {
    mapId: null,
    activeTab: "hitbox",
    preview: {
      hitbox: null, float: null, pokemon: null,
      offset: null, custom: null, doppelganger: null
    },
    existingCommands: [],
    selectedEventPos: null,
    statusEl: null,
    previewEl: null
  };

  // ── Generadores de comando ──
  const cmd = {
    hitbox() {
      const h = S.preview.hitbox;
      if (!h) return "";
      if (h.type === "rect") {
        const t = h.rotate ? "_true" : "";
        return `s:Hitbox${t}/${h.x},${h.y}`;
      }
      const t = h.rotate ? "_true" : "";
      const ry = h.ry != null ? `,${h.ry}` : "";
      return `s:Hitbox_radius${t}/${h.rx}${ry}`;
    },
    float() { return S.preview.float?.enabled ? "s:Float" : ""; },
    pokemon() {
      const p = S.preview.pokemon;
      if (!p?.species) return "";
      const shiny = p.shiny ? "_shiny" : "";
      const dir = p.dir && p.dir !== "none" ? `_${p.dir}` : "";
      return `s:pokemon_event${shiny}${dir}/${p.species}`;
    },
    offset() {
      const o = S.preview.offset;
      if (!o) return "";
      const parts = [];
      if (o.x || o.y) parts.push(`s:Offset/${o.x || 0},${o.y || 0}`);
      if (o.shadowX || o.shadowY) parts.push(`s:Offset_shadow/${o.shadowX || 0},${o.shadowY || 0}`);
      return parts.join("\n");
    },
    custom() {
      const c = S.preview.custom;
      if (!c?.path) return "";
      if (c.variant === "spritesheet") {
        const f = c.frames || 4;
        const s = c.speed != null ? `_${c.speed}` : "";
        return `s:Spritesheet_${f}${s}/${c.path}`;
      }
      return `s:Custom${c.variant === "full" ? "_full" : ""}/${c.path}`;
    },
    doppelganger() {
      const d = S.preview.doppelganger;
      if (!d) return "";
      const dir = d.dir && d.dir !== "none" ? `_${d.dir}` : "";
      return `s:doppelganger${dir}`;
    },
    all() {
      return [this.hitbox(), this.float(), this.pokemon(), this.offset(), this.custom(), this.doppelganger()]
        .filter(Boolean).join("\n");
    }
  };

  function copy(text) {
    if (!text) { ctx.ui.showToast({ message: "No hay comando que copiar", level: "warn" }); return; }
    ctx.clipboard.write(text);
    ctx.ui.showToast({ message: "Comando(s) copiado(s) al portapapeles", level: "info" });
  }

  function parseEventComments(event) {
    const cmds = [];
    if (!event?.pages) return cmds;
    for (const page of event.pages) {
      if (!page?.list) continue;
      const text = page.list
        .filter(c => c.code === 108 || c.code === 408)
        .map(c => String(c.parameters?.[0] ?? ""))
        .join("");
      let m = text.match(/s:Hitbox(_true)?\/(\d+),(\d+)/i);
      if (m) cmds.push({ type: "hitbox", sub: "rect", rotate: !!m[1], x: +m[2], y: +m[3] });
      m = text.match(/s:Hitbox_radius(_true)?\/(\d+)(?:,(\d+))?/i);
      if (m) cmds.push({ type: "hitbox", sub: "radius", rotate: !!m[1], rx: +m[2], ry: m[3] ? +m[3] : null });
      if (/s:Float/i.test(text)) cmds.push({ type: "float" });
    }
    return cmds;
  }

  // ── Leer evento del mapa ──
  async function readEvent(mapId, eventId) {
    try {
      let ev = null;
      if (typeof ctx.events?.getEvent === "function") ev = await ctx.events.getEvent(mapId, eventId);
      if (!ev && typeof ctx.events?.getEvents === "function") {
        const list = await ctx.events.getEvents(mapId);
        if (Array.isArray(list)) ev = list.find(e => e.id === eventId);
      }
      if (!ev && ctx.projectData?.getMap) {
        const md = ctx.projectData.getMap(mapId);
        ev = md?.events?.[eventId];
      }
      if (ev && ev.x != null) {
        S.selectedEventPos = { x: ev.x, y: ev.y };
        S.existingCommands = parseEventComments(ev);
      }
    } catch (_) { /* API no disponible */ }
  }

  function tryReadSelected() {
    if (typeof ctx.events?.getSelected === "function") {
      ctx.events.getSelected().then(ev => {
        if (ev && ev.x != null) {
          S.selectedEventPos = { x: ev.x, y: ev.y };
          S.existingCommands = parseEventComments(ev);
        }
      }).catch(() => {});
    }
  }

  function updateStatus() {
    if (!S.statusEl) return;
    if (S.selectedEventPos) {
      const n = S.existingCommands.length;
      S.statusEl.textContent = `Evento (${S.selectedEventPos.x},${S.selectedEventPos.y}) | ${n} comando(s)`;
    } else {
      S.statusEl.textContent = "Selecciona un evento en el mapa";
    }
  }

  // ── Overlay: gizmo de hitbox ──
  ctx.ui.registerOverlay({
    id: "zik.hitbox-gizmo",
    zOrder: 50,
    render(c, info) {
      const ts = info.tileSize || 32;
      const z = info.zoom || 1;
      const vx = info.viewportX || 0;
      const vy = info.viewportY || 0;

      const gizmos = [];
      if (S.preview.hitbox && S.selectedEventPos) {
        const h = S.preview.hitbox;
        gizmos.push({
          sub: h.type, pos: S.selectedEventPos, rotate: h.rotate,
          x: h.x, y: h.y, rx: h.rx, ry: h.ry, preview: true
        });
      }
      for (const ec of S.existingCommands) {
        if (ec.type === "hitbox" && S.selectedEventPos) {
          gizmos.push({ ...ec, pos: S.selectedEventPos, preview: false });
        }
      }

      for (const g of gizmos) {
        const ex = (g.pos.x * ts - vx) * z;
        const ey = (g.pos.y * ts - vy) * z;
        const cx = ex + (ts * z) / 2;
        const cy = ey + (ts * z) / 2 + (16 * z);

        if (g.sub === "rect") {
          const w = (g.x || 32) * z;
          const h = (g.y || 32) * z;
          c.fillStyle = g.preview ? "rgba(255, 200, 0, 0.12)" : "rgba(0, 255, 100, 0.12)";
          c.strokeStyle = g.rotate ? "rgba(100, 200, 255, 0.85)" : g.preview ? "rgba(255, 200, 0, 0.85)" : "rgba(0, 255, 100, 0.85)";
          c.lineWidth = Math.max(1, 2 * z);
          c.fillRect(cx - w / 2, cy - h / 2, w, h);
          c.strokeRect(cx - w / 2, cy - h / 2, w, h);
          const label = `s:Hitbox${g.rotate ? "_true" : ""}/${g.x},${g.y}${g.preview ? " ⚡" : ""}`;
          c.fillStyle = "rgba(255,255,255,0.85)";
          c.font = `${Math.max(9, 11 * z)}px monospace`;
          c.fillText(label, cx - w / 2, cy - h / 2 - 4);
        } else {
          const rx = (g.rx || 16) * z;
          const ry = (g.ry || g.rx || 16) * z;
          c.fillStyle = g.preview ? "rgba(255, 200, 0, 0.12)" : "rgba(0, 255, 100, 0.12)";
          c.strokeStyle = g.rotate ? "rgba(100, 200, 255, 0.85)" : g.preview ? "rgba(255, 200, 0, 0.85)" : "rgba(0, 255, 100, 0.85)";
          c.lineWidth = Math.max(1, 2 * z);
          c.beginPath();
          c.ellipse(cx, cy, rx, ry, 0, 0, Math.PI * 2);
          c.fill();
          c.stroke();
          const label = `s:Hitbox_radius${g.rotate ? "_true" : ""}/${g.rx}${g.ry ? `,${g.ry}` : ""}${g.preview ? " ⚡" : ""}`;
          c.fillStyle = "rgba(255,255,255,0.85)";
          c.font = `${Math.max(9, 11 * z)}px monospace`;
          c.fillText(label, cx - rx, cy - ry - 4);
        }

        // crosshair
        c.strokeStyle = "rgba(255,255,255,0.3)";
        c.lineWidth = Math.max(0.5, 1 * z);
        c.beginPath();
        c.moveTo(cx - 4 * z, cy); c.lineTo(cx + 4 * z, cy);
        c.moveTo(cx, cy - 4 * z); c.lineTo(cx, cy + 4 * z);
        c.stroke();
      }
    }
  });

  // ── Panel ──
  ctx.ui.registerPanel({
    id: "zik.event-utils",
    title: "Event Utils",
    defaultPosition: "right",
    render(host) {
      S.statusEl = document.createElement("div");
      S.statusEl.style.cssText = "font-size:11px;color:var(--text-secondary);padding:4px 8px;border-bottom:1px solid var(--border);";
      S.statusEl.textContent = "Selecciona un evento en el mapa";
      host.appendChild(S.statusEl);

      const tabs = ["hitbox","float","pokemon","offset","custom","doppelganger"];
      const tabNames = ["Hitbox","Float","Pokémon","Offset","Custom","Dop."];

      const tabBar = document.createElement("div");
      tabBar.style.cssText = "display:flex;flex-wrap:wrap;gap:4px;padding:8px;border-bottom:1px solid var(--border);";
      host.appendChild(tabBar);

      const tabBtns = {};
      for (let i = 0; i < tabs.length; i++) {
        const btn = document.createElement("button");
        btn.textContent = tabNames[i];
        const id = tabs[i];
        btn.dataset.tab = id;
        btn.style.cssText = "padding:4px 10px;border:1px solid var(--border);background:var(--bg-secondary);color:var(--text-primary);cursor:pointer;border-radius:3px;font-size:12px;";
        tabBar.appendChild(btn);
        tabBtns[id] = btn;
      }

      const content = document.createElement("div");
      content.style.cssText = "padding:8px;overflow-y:auto;flex:1;";
      host.appendChild(content);

      function makeField(label, inner) {
        const div = document.createElement("div");
        div.style.cssText = "margin-bottom:6px;";
        const l = document.createElement("label");
        l.style.cssText = "display:block;font-size:11px;color:var(--text-secondary);margin-bottom:2px;";
        l.textContent = label;
        div.appendChild(l);
        if (typeof inner === "string") {
          div.insertAdjacentHTML("beforeend", inner);
        } else {
          div.appendChild(inner);
        }
        return div;
      }

      function makeInput(attrs = {}) {
        const el = document.createElement("input");
        for (const [k, v] of Object.entries(attrs)) el[k] = v;
        el.style.cssText = "width:100%;padding:4px 6px;border:1px solid var(--border);background:var(--bg-primary);color:var(--text-primary);border-radius:3px;font-size:12px;box-sizing:border-box;";
        return el;
      }

      function makeSelect(opts) {
        const el = document.createElement("select");
        el.style.cssText = "width:100%;padding:4px 6px;border:1px solid var(--border);background:var(--bg-primary);color:var(--text-primary);border-radius:3px;font-size:12px;box-sizing:border-box;";
        for (const o of opts) {
          const opt = document.createElement("option");
          opt.value = o.value; opt.textContent = o.label;
          el.appendChild(opt);
        }
        return el;
      }

      function makeRow(children) {
        const div = document.createElement("div");
        div.style.cssText = "display:flex;gap:6px;";
        for (const c of children) {
          const wrap = document.createElement("div");
          wrap.style.cssText = "flex:1;";
          wrap.appendChild(c);
          div.appendChild(wrap);
        }
        return div;
      }

      // ── Build sections ──
      const sections = {};

      // Hitbox
      (() => {
        const s = document.createElement("div");
        s.style.display = "none";

        const typeSel = makeSelect([{value:"rect",label:"Rectangular"},{value:"radius",label:"Radio (circular)"}]);

        const w = makeInput({type:"number",value:"32",min:1});
        const h = makeInput({type:"number",value:"32",min:1});
        const rx = makeInput({type:"number",value:"16",min:1});
        const ry = makeInput({type:"number",value:"16",min:1});

        const rectFields = makeRow([makeField("Ancho (px)", w), makeField("Alto (px)", h)]);
        const radiusFields = makeRow([makeField("Radio X", rx), makeField("Radio Y", ry)]);
        radiusFields.style.display = "none";

        typeSel.addEventListener("change", () => {
          const isR = typeSel.value === "radius";
          rectFields.style.display = isR ? "none" : "";
          radiusFields.style.display = isR ? "" : "none";
        });

        const rotChk = document.createElement("input");
        rotChk.type = "checkbox";
        const rotLbl = makeField("", makeRow([rotChk, document.createTextNode(" Rotar (_true)")]));

        s.appendChild(makeField("Tipo", typeSel));
        s.appendChild(rectFields);
        s.appendChild(radiusFields);
        s.appendChild(rotLbl);
        content.appendChild(s);
        sections.hitbox = {
          el: s, refs: { typeSel, w, h, rx, ry, rotChk },
          read: () => ({
            type: typeSel.value,
            x: parseInt(w.value) || 32,
            y: parseInt(h.value) || 32,
            rx: parseInt(rx.value) || 16,
            ry: parseInt(ry.value) || null,
            rotate: rotChk.checked
          })
        };
      })();

      // Float
      (() => {
        const s = document.createElement("div");
        s.style.display = "none";
        const chk = document.createElement("input");
        chk.type = "checkbox";
        s.appendChild(makeField("", makeRow([chk, document.createTextNode(" Activar Float")])));
        content.appendChild(s);
        sections.float = { el: s, read: () => ({ enabled: chk.checked }) };
      })();

      // Pokémon
      (() => {
        const s = document.createElement("div");
        s.style.display = "none";
        const species = makeInput({type:"text",placeholder:"PIKACHU"});
        const shiny = document.createElement("input"); shiny.type = "checkbox";
        const dir = makeSelect([{value:"none",label:"(ninguna)"},{value:"up",label:"Arriba"},{value:"down",label:"Abajo"},{value:"left",label:"Izquierda"},{value:"right",label:"Derecha"}]);
        s.appendChild(makeField("Especie (inglés)", species));
        s.appendChild(makeField("", makeRow([shiny, document.createTextNode(" Shiny")])));
        s.appendChild(makeField("Dirección", dir));
        content.appendChild(s);
        sections.pokemon = { el: s, read: () => ({
          species: species.value.trim().toUpperCase() || null,
          shiny: shiny.checked,
          dir: dir.value
        }) };
      })();

      // Offset
      (() => {
        const s = document.createElement("div");
        s.style.display = "none";
        const ox = makeInput({type:"number",value:"0"});
        const oy = makeInput({type:"number",value:"0"});
        const sx = makeInput({type:"number",value:"0"});
        const sy = makeInput({type:"number",value:"0"});
        s.appendChild(makeRow([makeField("Offset X", ox), makeField("Offset Y", oy)]));
        s.appendChild(makeRow([makeField("Sombra X", sx), makeField("Sombra Y", sy)]));
        content.appendChild(s);
        sections.offset = { el: s, read: () => ({
          x: parseInt(ox.value) || 0, y: parseInt(oy.value) || 0,
          shadowX: parseInt(sx.value) || 0, shadowY: parseInt(sy.value) || 0
        }) };
      })();

      // Custom
      (() => {
        const s = document.createElement("div");
        s.style.display = "none";
        const variant = makeSelect([
          {value:"custom",label:"Custom"},
          {value:"full",label:"Custom_full"},
          {value:"spritesheet",label:"Spritesheet"}
        ]);
        const path = makeInput({type:"text",placeholder:"Pictures/introBoy"});
        const frames = makeInput({type:"number",value:"4",min:1});
        const speed = makeInput({type:"number",value:"4",min:0});
        const ssFields = makeRow([makeField("Frames", frames), makeField("Velocidad", speed)]);
        ssFields.style.display = "none";
        variant.addEventListener("change", () => {
          ssFields.style.display = variant.value === "spritesheet" ? "" : "none";
        });
        s.appendChild(makeField("Variante", variant));
        s.appendChild(makeField("Ruta (desde Graphics/)", path));
        s.appendChild(ssFields);
        content.appendChild(s);
        sections.custom = { el: s, read: () => ({
          variant: variant.value,
          path: path.value.trim() || null,
          frames: parseInt(frames.value) || 4,
          speed: parseInt(speed.value) || null
        }) };
      })();

      // Doppelganger
      (() => {
        const s = document.createElement("div");
        s.style.display = "none";
        const dir = makeSelect([
          {value:"none",label:"(ninguna)"},
          {value:"up",label:"Arriba"},{value:"down",label:"Abajo"},
          {value:"left",label:"Izquierda"},{value:"right",label:"Derecha"}
        ]);
        s.appendChild(makeField("Dirección", dir));
        content.appendChild(s);
        sections.doppelganger = { el: s, read: () => ({ dir: dir.value }) };
      })();

      // Tab activation
      function activateTab(id) {
        for (const t of tabs) {
          sections[t].el.style.display = t === id ? "" : "none";
          tabBtns[t].style.background = t === id ? "var(--accent)" : "var(--bg-secondary)";
          tabBtns[t].style.color = t === id ? "var(--text-on-accent)" : "var(--text-primary)";
          tabBtns[t].style.borderColor = t === id ? "var(--accent)" : "var(--border)";
        }
        S.activeTab = id;
      }

      for (const id of tabs) {
        tabBtns[id].addEventListener("click", () => activateTab(id));
      }

      // Preview box
      S.previewEl = document.createElement("div");
      S.previewEl.style.cssText = "margin-top:8px;padding:6px;background:var(--bg-secondary);border:1px solid var(--border);border-radius:3px;font-family:monospace;font-size:11px;color:var(--text-primary);white-space:pre-wrap;word-break:break-all;min-height:20px;";
      S.previewEl.textContent = "(sin comandos)";
      content.appendChild(S.previewEl);

      // Copy button
      const copyBtn = document.createElement("button");
      copyBtn.textContent = "📋 Copiar comando(s)";
      copyBtn.style.cssText = "display:block;width:100%;padding:6px;margin-top:8px;border:none;border-radius:3px;cursor:pointer;font-size:12px;background:var(--accent);color:var(--text-on-accent);";
      content.appendChild(copyBtn);

      // Read form → S.preview + update
      function readForm() {
        S.preview.hitbox = sections.hitbox.read();
        S.preview.float = sections.float.read();
        S.preview.pokemon = sections.pokemon.read();
        S.preview.offset = sections.offset.read();
        S.preview.custom = sections.custom.read();
        S.preview.doppelganger = sections.doppelganger.read();
      }

      function updateUI() {
        readForm();
        const text = cmd.all() || "(sin comandos)";
        S.previewEl.textContent = text;
      }

      // Live-update on any input
      for (const sec of Object.values(sections)) {
        if (sec.refs) {
          for (const el of Object.values(sec.refs)) {
            el.addEventListener("input", updateUI);
            el.addEventListener("change", updateUI);
          }
        } else if (sec.el) {
          sec.el.querySelectorAll("input, select").forEach(el => {
            el.addEventListener("input", updateUI);
            el.addEventListener("change", updateUI);
          });
        }
      }

      copyBtn.addEventListener("click", () => {
        readForm();
        const text = cmd.all();
        if (text) copy(text);
        else ctx.ui.showToast({ message: "Completa algún campo primero", level: "warn" });
      });

      activateTab("hitbox");
      updateUI();

      return () => { /* DOM auto-limpiado por el panel */ };
    }
  });

  // ── Bus ──
  ctx.bus.on("map.loaded", (e) => {
    S.mapId = e?.mapId ?? null;
    S.selectedEventPos = null;
    S.existingCommands = [];
    updateStatus();
  });

  ctx.bus.on("selection.changed", (e) => {
    if (e?.type === "event" && e?.id != null && S.mapId != null) {
      readEvent(S.mapId, e.id).then(updateStatus);
    } else {
      tryReadSelected();
      updateStatus();
    }
  });
}
