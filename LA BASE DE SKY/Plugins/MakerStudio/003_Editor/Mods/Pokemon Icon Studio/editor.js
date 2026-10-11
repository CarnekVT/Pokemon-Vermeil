import { ProjectFS, loadPokemonIconCatalog, canonicalIconPath, canonicalBattlerPath, basename, stem, lower } from "./assets.js";
import { IconDocument, detectLayout, detectBattlerLayout, decodeBlob, makeCanvas } from "./model.js";
import { installStyles } from "./styles.js";

let currentStudio = null;

const h = (tag, attrs = {}, ...children) => {
  const el = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs || {})) {
    if (k === "class") el.className = v;
    else if (k === "text") el.textContent = v;
    else if (k === "html") el.innerHTML = v;
    else if (k.startsWith("on") && typeof v === "function") el.addEventListener(k.slice(2).toLowerCase(), v);
    else if (v === true) el.setAttribute(k, "");
    else if (v !== false && v != null) el.setAttribute(k, String(v));
  }
  for (const child of children.flat()) {
    if (child == null) continue;
    el.append(child.nodeType ? child : document.createTextNode(String(child)));
  }
  return el;
};

const blobToBytes = async (blob) => new Uint8Array(await blob.arrayBuffer());

function downloadBlob(blob, name) {
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = name;
  a.style.display = "none";
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

async function clipboardWrite(blob) {
  if (navigator.clipboard?.write && globalThis.ClipboardItem) {
    await navigator.clipboard.write([new ClipboardItem({ "image/png": blob })]);
    return true;
  }
  return false;
}

async function clipboardReadImage() {
  if (!navigator.clipboard?.read) return null;
  const items = await navigator.clipboard.read();
  for (const item of items) {
    const type = item.types.find((t) => t.startsWith("image/"));
    if (type) return item.getType(type);
  }
  return null;
}

function imageInfo(blob) {
  return new Promise((resolve, reject) => {
    const url = URL.createObjectURL(blob);
    const img = new Image();
    img.onload = () => { const out = { width: img.naturalWidth, height: img.naturalHeight }; URL.revokeObjectURL(url); resolve(out); };
    img.onerror = () => { URL.revokeObjectURL(url); reject(new Error("La imagen no pudo abrirse.")); };
    img.src = url;
  });
}

class PokemonIconStudio {
  constructor(ctx) {
    this.ctx = ctx || {};
    this.fs = new ProjectFS(ctx);
    this.catalog = null;
    this.root = null;
    this.host = null;
    this.disposed = false;
    this.selectedSpecies = null;
    this.selectedForm = 0;
    this.selectedGender = 0;
    this.selectedShiny = false;
    this.targetPath = "";
    this.loadedPath = "";
    this.doc = null;
    this.activeFrame = 0;
    this.previewFrame = 0;
    this.playing = false;
    this.playTimer = null;
    this.onion = true;
    this.onionAlpha = 0.28;
    this.moveBoth = false;
    this.grid = true;
    this.canvasBackground = "light";
    this.customCanvasBackground = "#cfd3d8";
    this.incomingMode = "auto";
    this.autoExpandIncoming = true;
    this.search = "";
    this.filter = "all";
    this.internalClipboard = null;
    this.thumbObserver = null;
    this.drag = null;
    this.busy = false;
    // pintura + shiny + escalado
    this.tool = "move";
    this.fillColor = "#ff3b7f";
    this.tolerance = 10;
    this.bucketBoth = false;
    this.bucketMode = "contiguous";
    this.battlerUrlNormal = "";
    this.battlerUrlShiny = "";
    this.battlerPalette = [];
    this.battlerBytesNormal = null;
    this.battlerBytesShiny = null;
    this.fullscreenActive = false;
    this.fullscreenPlaceholder = null;
    this.fullscreenPreviousScroll = { x: 0, y: 0 };
    this.boundKeydown = (e) => this.onKeyDown(e);
    this.boundPaste = (e) => this.onPasteEvent(e);
  }

  async open(host = null) {
    installStyles();
    this.host = host || null;
    this.buildShell();
    document.addEventListener("keydown", this.boundKeydown, true);
    document.addEventListener("paste", this.boundPaste, true);
    await this.reloadCatalog();
  }

  async confirmAction(message, confirmLabel = "Descartar", cancelLabel = "Cancelar") {
    if (!this.root?.isConnected) return false;
    return new Promise((resolve) => {
      const overlay = h("div", { class: "pis-modal-overlay" });
      const card = h("div", { class: "pis-modal" },
        h("div", { class: "pis-modal-title", text: "Cambios sin guardar" }),
        h("div", { class: "pis-modal-text", text: message })
      );
      const finish = (value) => { overlay.remove(); resolve(value); };
      const cancel = this.button(cancelLabel, () => finish(false), "pis-btn");
      const confirm = this.button(confirmLabel, () => finish(true), "pis-btn danger");
      card.append(h("div", { class: "pis-modal-actions" }, cancel, confirm));
      overlay.append(card);
      overlay.addEventListener("pointerdown", (e) => { if (e.target === overlay) finish(false); });
      this.root.append(overlay);
      cancel.focus();
    });
  }

  async requestClose() {
    if (this.doc?.dirty && !(await this.confirmAction("Hay cambios sin guardar. ¿Cerrar Pokémon Icon Studio y descartarlos?", "Cerrar sin guardar"))) return false;
    const ui = this.ctx?.ui;
    if (this.host && typeof ui?.closePanel === "function") {
      Promise.resolve(ui.closePanel("pokemon-icon-studio")).catch(() => this.dispose());
      return true;
    }
    if (this.host && typeof ui?.hidePanel === "function") {
      Promise.resolve(ui.hidePanel("pokemon-icon-studio")).catch(() => this.dispose());
      return true;
    }
    this.dispose();
    return true;
  }

  close() { return this.requestClose(); }

  dispose() {
    if (this.disposed) return;
    this.disposed = true;
    this.stopPlay();
    if (this.fullscreenActive) this.exitFullscreen();
    document.removeEventListener("keydown", this.boundKeydown, true);
    document.removeEventListener("paste", this.boundPaste, true);
    this.thumbObserver?.disconnect();
    this.fs.dispose();
    this.root?.remove();
    if (currentStudio === this) currentStudio = null;
  }

  updateFullscreenUI() {
    if (!this.fullscreenBtn) return;
    this.fullscreenBtn.classList.toggle("active", this.fullscreenActive);
    this.fullscreenBtn.textContent = this.fullscreenActive ? "↙ Salir" : "⛶ Pantalla completa";
    this.fullscreenBtn.title = this.fullscreenActive ? "Salir de pantalla completa · F11 / Esc" : "Pantalla completa · F11";
  }

  enterFullscreen() {
    if (this.fullscreenActive || !this.root || !document.body) return false;
    try {
      this.fullscreenPlaceholder = document.createComment("pis-fullscreen");
      if (this.root.parentNode) this.root.parentNode.insertBefore(this.fullscreenPlaceholder, this.root);
      document.body.appendChild(this.root);
    } catch (_) {}
    this.fullscreenActive = true;
    this.root.classList.add("pis-fullscreen-active");
    try { document.body.classList.add("pis-fullscreen-lock"); document.documentElement.classList.add("pis-fullscreen-lock"); } catch (_) {}
    this.updateFullscreenUI();
    this.toast("Pantalla completa · F11 o Esc para salir", "ok");
    requestAnimationFrame(() => {
      requestAnimationFrame(() => { try { this.renderCanvas(); } catch (_) {} });
    });
    return true;
  }

  exitFullscreen() {
    if (!this.fullscreenActive) return false;
    this.fullscreenActive = false;
    this.root.classList.remove("pis-fullscreen-active");
    try { document.body.classList.remove("pis-fullscreen-lock"); document.documentElement.classList.remove("pis-fullscreen-lock"); } catch (_) {}
    try {
      if (this.fullscreenPlaceholder && this.fullscreenPlaceholder.parentNode) {
        this.fullscreenPlaceholder.parentNode.replaceChild(this.root, this.fullscreenPlaceholder);
      } else if (this.host && this.host !== document.body) {
        this.host.appendChild(this.root);
      } else {
        document.body.appendChild(this.root);
      }
    } catch (_) {}
    this.fullscreenPlaceholder = null;
    this.updateFullscreenUI();
    requestAnimationFrame(() => {
      requestAnimationFrame(() => { try { this.renderCanvas(); } catch (_) {} });
    });
    return true;
  }

  toggleFullscreen() { return this.fullscreenActive ? this.exitFullscreen() : this.enterFullscreen(); }

  buildShell() {
    this.root = h("div", { id: "pis-root", tabindex: "0" });
    const brand = h("div", { class: "pis-brand" },
      h("div", { class: "pis-brand-mark", text: "◫" }),
      h("div", {}, h("div", { class: "pis-brand-title", text: "Pokémon Icon Studio" }), h("div", { class: "pis-brand-sub", text: "Maker Studio · Frame 1 / Frame 2" }))
    );
    this.statusEl = h("div", { class: "pis-status", text: "Cargando proyecto…" });
    this.saveBtn = this.button("Guardar", () => this.save(), "pis-btn primary");
    this.undoBtn = this.button("↶", () => this.undo(), "pis-btn icon", "Deshacer (Ctrl+Z)");
    this.redoBtn = this.button("↷", () => this.redo(), "pis-btn icon", "Rehacer (Ctrl+Y)");
    this.fullscreenBtn = this.button("⛶ Pantalla completa", () => this.toggleFullscreen(), "pis-btn", "Pantalla completa · F11");
    const top = h("div", { class: "pis-top" }, brand, h("div", { class: "pis-top-spacer" }), this.statusEl,
      this.fullscreenBtn, this.button("Recargar", () => this.reloadCatalog(), "pis-btn"), this.undoBtn, this.redoBtn, this.saveBtn,
      this.button("Cerrar", () => this.requestClose(), "pis-btn danger")
    );
    this.left = h("aside", { class: "pis-left" });
    this.center = h("main", { class: "pis-center" });
    this.right = h("aside", { class: "pis-right" });
    this.main = h("div", { class: "pis-main" }, this.left, this.center, this.right);
    this.toastStack = h("div", { class: "pis-toast-stack" });
    this.root.append(top, this.main, this.toastStack);
    if (this.host) {
      this.host.innerHTML = "";
      this.host.style.minHeight = "0";
      this.host.style.height = "100%";
      this.host.appendChild(this.root);
    } else {
      this.root.classList.add("pis-standalone");
      document.body.appendChild(this.root);
    }
    this.buildLeft();
    this.buildCenter();
    this.buildRight();
    this.root.focus();
  }

  button(text, fn, cls = "pis-btn", title = "") {
    return h("button", { class: cls, type: "button", title, onclick: (e) => { e.preventDefault(); fn(e); } }, text);
  }

  buildLeft() {
    this.searchInput = h("input", { class: "pis-input", placeholder: "Buscar nombre, ID o Nº…", type: "search", oninput: (e) => { this.search = e.target.value; this.renderSpeciesList(); } });
    this.countEl = h("span", { class: "pis-count", text: "0" });
    this.allFilter = this.button("Todos", () => { this.filter = "all"; this.updateFilterButtons(); this.renderSpeciesList(); }, "pis-btn small active");
    this.missingFilter = this.button("Sin icon", () => { this.filter = "missing"; this.updateFilterButtons(); this.renderSpeciesList(); }, "pis-btn small");
    this.assetFilter = this.button("Assets", () => { this.filter = "assets"; this.updateFilterButtons(); this.renderSpeciesList(); }, "pis-btn small");
    this.jumpSelectedBtn = this.button("↳ Seleccionado", () => this.jumpToSelected(), "pis-btn small", "Volver rápidamente al Pokémon seleccionado");
    this.listEl = h("div", { class: "pis-list" });
    this.left.replaceChildren(
      h("div", { class: "pis-section-head" }, h("span", { class: "pis-section-title", text: "Especies" }), this.countEl),
      h("div", { class: "pis-search-wrap" }, this.searchInput),
      h("div", { class: "pis-filter-row pis-filter-wrap" }, this.allFilter, this.missingFilter, this.assetFilter, this.jumpSelectedBtn),
      this.listEl
    );
  }

  updateFilterButtons() {
    for (const [key, btn] of [["all", this.allFilter], ["missing", this.missingFilter], ["assets", this.assetFilter]]) btn.classList.toggle("active", this.filter === key);
  }

  buildCenter() {
    this.titleEl = h("span", { class: "pis-center-title", text: "Selecciona un Pokémon" });
    this.frame1Btn = this.button("Frame 1", () => this.selectFrame(0), "pis-btn small active");
    this.frame2Btn = this.button("Frame 2", () => this.selectFrame(1), "pis-btn small");
    this.playBtn = this.button("▶ Preview", () => this.togglePlay(), "pis-btn small");
    this.centerHead = h("div", { class: "pis-center-head" }, this.titleEl, h("div", { class: "pis-tabs" }, this.frame1Btn, this.frame2Btn), h("div", { class: "pis-top-spacer" }), this.playBtn);
    this.stageWrap = h("div", { class: "pis-stage-wrap" });
    this.canvas = h("canvas", { tabindex: "0" });
    this.canvas.addEventListener("pointerdown", (e) => this.pointerDown(e));
    this.canvas.addEventListener("pointermove", (e) => this.pointerMove(e));
    this.canvas.addEventListener("pointerup", (e) => this.pointerUp(e));
    this.canvas.addEventListener("pointercancel", (e) => this.pointerUp(e));
    this.stage = h("div", { class: "pis-stage" }, this.canvas);
    this.stageInfo = h("div", { class: "pis-stage-info" });
    this.stageCard = h("div", { class: "pis-stage-card" }, this.stage, this.stageInfo);
    this.emptyStage = h("div", { class: "pis-stage-empty" }, h("div", {}, h("strong", { text: "No hay icon cargado" }), "Selecciona una especie con icon o importa un PNG para crear uno."));
    this.stageWrap.append(this.emptyStage);

    this.importInput = h("input", { type: "file", accept: "image/png,image/*", class: "pis-hidden", onchange: (e) => this.importFile(e.target.files?.[0]) });
    this.toolMoveBtn = this.button("✋ Mover", () => this.setTool("move"), "pis-btn small active", "Mover icon (arrastrar)");
    this.toolPickerBtn = this.button("◉ Cuentagotas", () => this.setTool("picker"), "pis-btn small", "Clic en el icon para tomar color (I)");
    this.toolBucketBtn = this.button("🪣 Cubo", () => this.setTool("bucket"), "pis-btn small", "Clic para inundar color contiguo (B)");
    this.toolbar = h("div", { class: "pis-toolbar" },
      h("span", { class: "pis-toolbar-label", text: "Edición" }),
      this.toolMoveBtn, this.toolPickerBtn, this.toolBucketBtn,
      h("span", { class: "sep" }),
      this.button("Centrar", () => this.centerFrame(), "pis-btn small"),
      this.button("←", () => this.nudge(-1, 0), "pis-btn small icon"), this.button("↑", () => this.nudge(0, -1), "pis-btn small icon"),
      this.button("↓", () => this.nudge(0, 1), "pis-btn small icon"), this.button("→", () => this.nudge(1, 0), "pis-btn small icon"),
      h("span", { class: "sep" }),
      this.button("Copiar frame", () => this.copyFrame(), "pis-btn small"), this.button("Copiar icon", () => this.copyIcon(), "pis-btn small"), this.button("Pegar", () => this.pasteFromClipboard(), "pis-btn small"),
      h("span", { class: "sep" }),
      this.button("Importar PNG", () => { this.importInput.value = ""; this.importInput.click(); }, "pis-btn small"),
      this.button("Exportar", () => this.exportCurrent(), "pis-btn small"),
      this.button("Guardar como ID", () => this.saveAsId(), "pis-btn small good"),
      this.importInput
    );
    this.center.replaceChildren(this.centerHead, this.stageWrap, this.toolbar);

    for (const type of ["dragenter", "dragover"]) this.stageWrap.addEventListener(type, (e) => { e.preventDefault(); this.stageWrap.classList.add("pis-drop"); });
    for (const type of ["dragleave", "drop"]) this.stageWrap.addEventListener(type, (e) => { e.preventDefault(); this.stageWrap.classList.remove("pis-drop"); });
    this.stageWrap.addEventListener("drop", (e) => {
      const file = [...(e.dataTransfer?.files || [])].find((f) => f.type.startsWith("image/") || /\.png$/i.test(f.name));
      if (file) this.importFile(file);
    });
  }

  buildRight() {
    this.speciesNameEl = h("div", { class: "pis-mono", text: "—" });
    this.formSelect = h("select", { class: "pis-select", onchange: (e) => this.changeForm(Number(e.target.value)) });
    this.genderSelect = h("select", { class: "pis-select", onchange: (e) => this.changeVariant({ gender: Number(e.target.value) || 0 }) },
      h("option", { value: "0", text: "Normal / Male" }), h("option", { value: "1", text: "Female" })
    );
    this.shinyCheck = h("input", { type: "checkbox", onchange: (e) => this.changeVariant({ shiny: !!e.target.checked }) });
    this.pathEl = h("div", { class: "pis-mono", text: "—" });
    this.sourceEl = h("div", { class: "pis-mono", text: "—" });
    this.sizeEl = h("div", { class: "pis-mono", text: "—" });
    this.xInput = h("input", { class: "pis-input", type: "number", value: "0", onchange: () => this.applyOffsetInputs() });
    this.yInput = h("input", { class: "pis-input", type: "number", value: "0", onchange: () => this.applyOffsetInputs() });
    this.canvasWInput = h("input", { class: "pis-input", type: "number", min: "1", max: "4096", value: "64" });
    this.canvasHInput = h("input", { class: "pis-input", type: "number", min: "1", max: "4096", value: "64" });
    this.resizeCanvasBtn = this.button("Aplicar tamaño", () => this.applyCanvasSize(), "pis-btn small good");
    this.autoExpandCheck = h("input", { type: "checkbox", checked: true, onchange: (e) => { this.autoExpandIncoming = !!e.target.checked; } });
    this.incomingModeSelect = h("select", { class: "pis-select", onchange: (e) => { this.incomingMode = e.target.value || "auto"; } },
      h("option", { value: "auto", text: "Automático" }),
      h("option", { value: "frame", text: "Frame actual" }),
      h("option", { value: "sheet", text: "Icon completo" })
    );
    this.onionCheck = h("input", { type: "checkbox", checked: true, onchange: (e) => { this.onion = e.target.checked; this.renderCanvas(); } });
    this.onionRange = h("input", { class: "pis-range", type: "range", min: "5", max: "80", value: "28", oninput: (e) => { this.onionAlpha = Number(e.target.value) / 100; this.renderCanvas(); } });
    this.moveBothCheck = h("input", { type: "checkbox", onchange: (e) => { this.moveBoth = e.target.checked; } });
    this.gridCheck = h("input", { type: "checkbox", checked: true, onchange: (e) => { this.grid = e.target.checked; this.renderCanvas(); } });
    this.backgroundSelect = h("select", { class: "pis-select", onchange: (e) => { this.canvasBackground = e.target.value; this.syncBackgroundControls(); this.renderCanvas(); } },
      h("option", { value: "light", text: "Claro · gris medio" }),
      h("option", { value: "dark", text: "Negro" }),
      h("option", { value: "custom", text: "Custom" })
    );
    this.backgroundColor = h("input", { class: "pis-color", type: "color", value: this.customCanvasBackground, oninput: (e) => { this.customCanvasBackground = e.target.value; this.renderCanvas(); } });
    this.diagEl = h("div", { class: "pis-diagnostic", text: "Sin icon cargado." });
    this.createBaseBtn = this.button("Crear desde base", () => this.createFromBase(), "pis-btn small");
    this.createBlankBtn = this.button("Crear vacío", () => this.createBlank(), "pis-btn small");
    this.copy12Btn = this.button("Posición 1 → 2", () => this.copyPosition(0, 1), "pis-btn small");
    this.copy21Btn = this.button("Posición 2 → 1", () => this.copyPosition(1, 0), "pis-btn small");
    this.copyGraphic12Btn = this.button("Gráfico 1 → 2", () => this.copyFrameGraphic(0, 1), "pis-btn small");
    this.copyGraphic21Btn = this.button("Gráfico 2 → 1", () => this.copyFrameGraphic(1, 0), "pis-btn small");
    // --- Escalado
    this.scaleX1Btn = this.button("×1 (64)", () => this.applyScaleFactor(1), "pis-btn small");
    this.scaleX2Btn = this.button("×2 duplica", () => this.applyScaleFactor(2), "pis-btn small good", "Duplica tamaño con vecino más cercano");
    this.scaleHalfBtn = this.button("×½ mitad", () => this.applyScaleFactor(0.5), "pis-btn small");
    this.scalePresetsEl = h("div", { class: "pis-btn-grid pis-scale-presets" },
      this.button("32×32", () => this.applyScaleTo(32, 32), "pis-btn small"),
      this.button("42×42", () => this.applyScaleTo(42, 42), "pis-btn small"),
      this.button("64×64", () => this.applyScaleTo(64, 64), "pis-btn small"),
      this.button("84×84", () => this.applyScaleTo(84, 84), "pis-btn small")
    );
    // --- Pintura
    this.fillColorInput = h("input", { class: "pis-color", type: "color", value: this.fillColor, oninput: (e) => { this.fillColor = e.target.value; this.syncFillPreview(); } });
    this.fillHexInput = h("input", { class: "pis-input pis-mono", type: "text", value: this.fillColor, onchange: (e) => { const v = this.normalizeHex(e.target.value); if (v) { this.fillColor = v; this.fillColorInput.value = v; this.syncFillPreview(); } } });
    this.toleranceRange = h("input", { class: "pis-range", type: "range", min: "0", max: "60", value: String(this.tolerance), oninput: (e) => { this.tolerance = Number(e.target.value); if (this.toleranceLabel) this.toleranceLabel.textContent = String(this.tolerance); } });
    this.toleranceLabel = h("span", { class: "pis-mono", text: String(this.tolerance) });
    this.bucketBothCheck = h("input", { type: "checkbox", onchange: (e) => { this.bucketBoth = !!e.target.checked; } });
    this.bucketModeSelect = h("select", { class: "pis-select", onchange: (e) => { this.bucketMode = e.target.value === "global" ? "global" : "contiguous"; } },
      h("option", { value: "contiguous", text: "Contigua (inundar)" }),
      h("option", { value: "global", text: "Global (todo el color)" })
    );
    this.fillPreview = h("span", { class: "pis-color-preview", style: `background:${this.fillColor}` });
    this.replaceAllBtn = this.button("Reemplazar color similar", () => this.replaceColorGlobal(), "pis-btn small", "Reemplaza todas las coincidencias del color origen por el de relleno");
    // --- Shiny + Battler paleta
    this.battlerNormalWrap = h("div", { class: "pis-battler-thumb", text: "—" });
    this.battlerShinyWrap = h("div", { class: "pis-battler-thumb", text: "—" });
    this.battlerInfoEl = h("div", { class: "pis-mono pis-battler-info", text: "Sin battler" });
    this.battlerPaletteEl = h("div", { class: "pis-palette" });
    this.shinyFromNormalBtn = this.button("Crear shiny desde normal", () => this.createShinyFromNormal(), "pis-btn small good");
    this.duplicateToShinyBtn = this.button("Duplicar icon → shiny", () => this.duplicateToShiny(), "pis-btn small");
    this.saveShinyBtn = this.button("Guardar en Icons shiny", () => this.saveShinyDirect(), "pis-btn small good");

    const scroll = h("div", { class: "pis-right-scroll" },
      h("section", { class: "pis-inspector-block" }, h("h3", { text: "Pokémon" }),
        h("div", { class: "pis-kv" }, h("label", { text: "Especie" }), this.speciesNameEl),
        h("div", { class: "pis-kv" }, h("label", { text: "Forma" }), this.formSelect),
        h("div", { class: "pis-kv" }, h("label", { text: "Sexo" }), this.genderSelect),
        h("label", { class: "pis-check" }, this.shinyCheck, "Editar variante Shiny"),
        h("div", { class: "pis-kv" }, h("label", { text: "Destino" }), this.pathEl),
        h("div", { class: "pis-kv" }, h("label", { text: "Cargado" }), this.sourceEl),
        h("div", { class: "pis-btn-grid" }, this.createBaseBtn, this.createBlankBtn),
        h("div", { class: "pis-btn-grid" }, this.shinyFromNormalBtn, this.duplicateToShinyBtn)
      ),
      h("section", { class: "pis-inspector-block" }, h("h3", { text: "Frame seleccionado" }),
        h("div", { class: "pis-offset-grid" },
          h("div", { class: "pis-offset-cell" }, h("label", { text: "Offset X" }), this.xInput),
          h("div", { class: "pis-offset-cell" }, h("label", { text: "Offset Y" }), this.yInput)
        ),
        h("div", { class: "pis-btn-grid" }, this.copy12Btn, this.copy21Btn),
        h("div", { class: "pis-btn-grid" }, this.copyGraphic12Btn, this.copyGraphic21Btn),
        h("label", { class: "pis-check" }, this.moveBothCheck, "Mover Frame 1 y 2 juntos")
      ),
      h("section", { class: "pis-inspector-block" }, h("h3", { text: "Escalado" }),
        h("div", { class: "pis-offset-grid" },
          h("div", { class: "pis-offset-cell" }, h("label", { text: "Ancho frame" }), this.canvasWInput),
          h("div", { class: "pis-offset-cell" }, h("label", { text: "Alto frame" }), this.canvasHInput)
        ),
        this.resizeCanvasBtn,
        h("div", { class: "pis-btn-grid" }, this.scaleX1Btn, this.scaleHalfBtn),
        h("div", { class: "pis-btn-grid" }, this.scaleX2Btn, this.button("Ajustar original", () => this.resetScaleFromBattler(), "pis-btn small")),
        h("div", { text: "Presets:" , style: "color:var(--pis-muted);font-size:11px;margin:6px 0 4px" }),
        this.scalePresetsEl,
        h("div", { class: "pis-mono", text: "×2 y ×½ usan vecino más cercano (pixel art nítido) + undo/redo." , style: "margin-top:6px;font-size:11px;opacity:.8" })
      ),
       h("section", { class: "pis-inspector-block" }, h("h3", { text: "Pintura · Cuentagotas & Cubo" }),
        h("div", { class: "pis-tool-row" }, this.toolMoveBtn, this.toolPickerBtn, this.toolBucketBtn),
        h("div", { class: "pis-kv" }, h("label", { text: "Relleno" }), h("div", { style: "display:flex;gap:6px;align-items:center" }, this.fillColorInput, this.fillPreview, this.fillHexInput)),
        h("div", { class: "pis-kv" }, h("label", { text: "Tolerancia" }), h("div", { style: "display:flex;gap:6px;align-items:center;flex:1" }, this.toleranceRange, this.toleranceLabel)),
        h("div", { class: "pis-kv" }, h("label", { text: "Modo cubo" }), this.bucketModeSelect),
        h("label", { class: "pis-check" }, this.bucketBothCheck, "Cubo afecta a ambos frames"),
        this.replaceAllBtn,
        h("div", { class: "pis-mono", text: "I = cuentagotas, B = cubo, clic sobre el icon aplica. Doble undo para deshacer." , style: "margin-top:6px;font-size:11px;opacity:.8" })
      ),
      h("section", { class: "pis-inspector-block" }, h("h3", { text: "Shiny + battler referencia" }),
        h("div", { class: "pis-battler-grid" },
          h("div", {}, h("label", { text: "Battler normal" }), this.battlerNormalWrap),
          h("div", {}, h("label", { text: "Shiny" }), this.battlerShinyWrap)
        ),
        this.battlerInfoEl,
        h("div", { text: "Paleta battler (clic = relleno):" , style: "color:var(--pis-muted);font-size:11px;margin:6px 0 4px" }),
        this.battlerPaletteEl,
        h("div", { class: "pis-btn-grid" }, this.saveShinyBtn, this.button("Recargar battler", () => this.refreshBattlerReference(), "pis-btn small"))
      ),
      h("section", { class: "pis-inspector-block" }, h("h3", { text: "Lienzo e importación" }),
        h("div", { class: "pis-kv pis-kv-stack" }, h("label", { text: "Pegar/importar" }), this.incomingModeSelect),
        h("label", { class: "pis-check" }, this.autoExpandCheck, "Expandir lienzo si la imagen no cabe")
      ),
      h("section", { class: "pis-inspector-block" }, h("h3", { text: "Preview" }),
        h("label", { class: "pis-check" }, this.onionCheck, "Onion Skin del otro frame"),
        h("div", { class: "pis-kv" }, h("label", { text: "Opacidad" }), this.onionRange),
        h("div", { class: "pis-kv" }, h("label", { text: "Fondo" }), this.backgroundSelect),
        h("div", { class: "pis-kv" }, h("label", { text: "Color custom" }), this.backgroundColor),
        h("label", { class: "pis-check" }, this.gridCheck, "Centro y guías"),
        h("div", { class: "pis-kv" }, h("label", { text: "Tamaño" }), this.sizeEl)
      ),
      h("section", { class: "pis-inspector-block" }, h("h3", { text: "Diagnóstico" }), this.diagEl)
    );
    this.right.replaceChildren(h("div", { class: "pis-section-head" }, h("span", { class: "pis-section-title", text: "Inspector" })), scroll);
    this.syncBackgroundControls();
    this.refreshInspector();
  }

  setBusy(on, message = "") {
    this.busy = !!on;
    this.root?.classList.toggle("pis-loading", this.busy);
    if (message) this.setStatus(message);
  }

  setStatus(text, kind = "") {
    if (!this.statusEl) return;
    this.statusEl.textContent = text;
    this.statusEl.dataset.kind = kind;
  }

  toast(text, kind = "") {
    const node = h("div", { class: `pis-toast ${kind}`, text });
    this.toastStack.append(node);
    setTimeout(() => node.remove(), 3200);
  }

  canvasBackgroundColor() {
    if (this.canvasBackground === "dark") return "#11151b";
    if (this.canvasBackground === "custom") return this.customCanvasBackground || "#cfd3d8";
    return "#cfd3d8";
  }

  syncBackgroundControls() {
    if (this.backgroundColor) this.backgroundColor.disabled = this.canvasBackground !== "custom";
  }

  jumpToSelected() {
    if (!this.selectedSpecies) return this.toast("Todavía no hay un Pokémon seleccionado.", "error");
    const visible = this.filteredSpecies().some((sp) => lower(sp.id) === lower(this.selectedSpecies.id));
    if (!visible) {
      this.search = "";
      this.filter = "all";
      if (this.searchInput) this.searchInput.value = "";
      this.updateFilterButtons();
      this.renderSpeciesList();
    }
    requestAnimationFrame(() => {
      const list = this.listEl;
      if (!list) return;
      const rows = [...(list.querySelectorAll?.(".pis-row") || [])];
      const row = rows.find((r) => lower(r.dataset.speciesId) === lower(this.selectedSpecies.id));
      if (row) {
        // IMPORTANT: never use Element#scrollIntoView here. In Maker Studio that can
        // scroll the panel/window ancestors too, shifting the whole editor and canvas.
        // Only the species browser is allowed to move.
        const listRect = list.getBoundingClientRect();
        const rowRect = row.getBoundingClientRect();
        const rowTopInList = list.scrollTop + (rowRect.top - listRect.top);
        const targetTop = Math.max(0, rowTopInList - ((list.clientHeight - row.offsetHeight) / 2));
        if (typeof list.scrollTo === "function") list.scrollTo({ top: targetTop, behavior: "smooth" });
        else list.scrollTop = targetTop;
        row.classList.add("pis-jump-flash");
        setTimeout(() => row.classList.remove("pis-jump-flash"), 700);
      }
    });
  }

  async reloadCatalog() {
    if (this.busy) return;
    this.setBusy(true, "Leyendo PBS e icons del proyecto…");
    try {
      this.catalog = await loadPokemonIconCatalog(this.fs);
      this.setStatus(`${this.catalog.species.length} especies · ${this.catalog.normalIconPaths.length} normales · ${this.catalog.shinyIconPaths.length} shiny`, "ok");
      this.renderSpeciesList();
      if (!this.selectedSpecies && this.catalog.species.length) {
        this.setBusy(false);
        await this.selectSpecies(this.catalog.species[0]);
      } else if (this.selectedSpecies) {
        const fresh = this.catalog.species.find((s) => lower(s.id) === lower(this.selectedSpecies.id));
        if (fresh) this.selectedSpecies = fresh;
        this.renderSpeciesList();
        this.refreshInspector();
      }
    } catch (e) {
      console.error("[Pokémon Icon Studio] catalog", e);
      this.setStatus(e.message || String(e), "error");
      this.toast(e.message || String(e), "error");
    } finally { this.setBusy(false); }
  }

  filteredSpecies() {
    if (!this.catalog) return [];
    const q = lower(this.search.trim());
    return this.catalog.species.filter((sp) => {
      if (this.filter === "missing" && this.catalog.hasAnyIcon(sp)) return false;
      if (this.filter === "assets" && !sp.assetOnly) return false;
      if (!q) return true;
      const hay = `${sp.dex || ""} ${sp.id} ${sp.name} ${sp.forms.map((f) => f.name).join(" ")} ${sp.iconPaths.join(" ")}`.toLowerCase();
      return hay.includes(q);
    });
  }

  renderSpeciesList() {
    if (!this.listEl) return;
    this.thumbObserver?.disconnect();
    this.thumbObserver = typeof IntersectionObserver === "function" ? new IntersectionObserver((entries) => {
      for (const entry of entries) if (entry.isIntersecting) { this.loadThumb(entry.target); this.thumbObserver.unobserve(entry.target); }
    }, { root: this.listEl, rootMargin: "160px" }) : null;
    const list = this.filteredSpecies();
    this.countEl.textContent = String(list.length);
    const frag = document.createDocumentFragment();
    for (const sp of list) {
      const previewPath = this.catalog.defaultPreviewPath(sp);
      const thumb = h("div", { class: "pis-thumb" }, previewPath ? "" : "—");
      if (previewPath) { thumb.dataset.path = previewPath; if (this.thumbObserver) this.thumbObserver.observe(thumb); else this.loadThumb(thumb); }
      const row = h("div", { "data-species-id": sp.id, class: `pis-row ${this.catalog.hasAnyIcon(sp) ? "" : "missing"} ${this.selectedSpecies && lower(this.selectedSpecies.id) === lower(sp.id) ? "selected" : ""}`, onclick: () => this.selectSpecies(sp) },
        thumb,
        h("div", {}, h("div", { class: "pis-row-name", text: sp.name || sp.id }), h("div", { class: "pis-row-meta", text: sp.iconAssets.length ? `${sp.iconAssets.length} asset${sp.iconAssets.length === 1 ? "" : "s"}${previewPath ? "" : " · forma 0 sin icon"}` : "Icon faltante" })),
        h("div", { class: "pis-row-id", text: sp.dex ? String(sp.dex).padStart(3, "0") : sp.id.slice(0, 8) })
      );
      frag.append(row);
    }
    this.listEl.replaceChildren(frag);
  }

  async loadThumb(node) {
    const path = node.dataset.path;
    if (!path || !node.isConnected) return;
    try {
      const url = await this.fs.assetUrl(path);
      if (!node.isConnected) return;
      const img = h("img", { alt: "" });
      img.onload = () => {
        const hgt = 36;
        if (img.naturalWidth >= img.naturalHeight * 1.5) {
          img.style.height = `${hgt}px`;
          img.style.width = `${Math.round(hgt * img.naturalWidth / img.naturalHeight)}px`;
        } else {
          const scale = Math.min(36 / img.naturalWidth, 36 / img.naturalHeight);
          img.style.width = `${Math.round(img.naturalWidth * scale)}px`;
          img.style.height = `${Math.round(img.naturalHeight * scale)}px`;
        }
      };
      img.src = url;
      node.textContent = "";
      node.append(img);
    } catch (_) { node.textContent = "!"; }
  }

  async selectSpecies(sp) {
    if (this.busy) return;
    if (this.doc?.dirty && this.selectedSpecies && lower(this.selectedSpecies.id) !== lower(sp.id)) {
      if (!(await this.confirmAction("Hay cambios sin guardar en el icon actual. ¿Cambiar de especie y descartarlos?"))) return;
    }
    this.selectedSpecies = sp;
    this.selectedForm = 0;
    this.selectedGender = 0;
    this.selectedShiny = false;
    if (this.genderSelect) this.genderSelect.value = "0";
    if (this.shinyCheck) this.shinyCheck.checked = false;
    this.renderSpeciesList();
    this.populateForms();
    await this.loadSelectedForm();
  }

  populateForms() {
    if (!this.selectedSpecies) { this.formSelect.replaceChildren(); return; }
    const frag = document.createDocumentFragment();
    const forms = this.selectedSpecies.forms?.length ? this.selectedSpecies.forms : [{ form: 0, name: "Normal" }];
    const normalized = forms.some((f) => Number(f.form) === 0) ? forms : [{ form: 0, name: "Normal" }, ...forms];
    for (const f of normalized) {
      const existing = this.catalog.findExactVariant(this.selectedSpecies, f.form, this.selectedGender, this.selectedShiny);
      const label = `${f.form} · ${f.name || (f.form ? `Forma ${f.form}` : "Normal")}${existing ? "" : " · sin icon"}`;
      frag.append(h("option", { value: f.form, text: label }));
    }
    this.formSelect.replaceChildren(frag);
    if (![...this.formSelect.options].some((o) => Number(o.value) === Number(this.selectedForm))) this.selectedForm = 0;
    this.formSelect.value = String(this.selectedForm);
  }

  async changeForm(form) {
    const next = Number(form) || 0;
    if (next === this.selectedForm) return;
    if (this.doc?.dirty && !(await this.confirmAction("Hay cambios sin guardar. ¿Cambiar de forma y descartarlos?"))) {
      this.formSelect.value = String(this.selectedForm);
      return;
    }
    this.selectedForm = next;
    await this.loadSelectedForm();
  }

  async changeVariant({ gender = this.selectedGender, shiny = this.selectedShiny } = {}) {
    gender = Number(gender) === 1 ? 1 : 0;
    shiny = !!shiny;
    if (gender === this.selectedGender && shiny === this.selectedShiny) return;
    if (this.doc?.dirty && !(await this.confirmAction("Hay cambios sin guardar. ¿Cambiar de variante y descartarlos?"))) {
      if (this.genderSelect) this.genderSelect.value = String(this.selectedGender);
      if (this.shinyCheck) this.shinyCheck.checked = this.selectedShiny;
      return;
    }
    this.selectedGender = gender;
    this.selectedShiny = shiny;
    if (this.genderSelect) this.genderSelect.value = String(gender);
    if (this.shinyCheck) this.shinyCheck.checked = shiny;
    this.populateForms();
    await this.loadSelectedForm();
  }

  async loadSelectedForm() {
    if (!this.selectedSpecies) return;
    this.stopPlay();
    const exact = this.catalog.findExactVariant(this.selectedSpecies, this.selectedForm, this.selectedGender, this.selectedShiny);
    this.targetPath = canonicalIconPath(this.selectedSpecies.id, this.selectedForm, this.selectedGender, this.selectedShiny);
    this.loadedPath = exact || "";
    if (!exact) {
      this.doc = null;
      this.activeFrame = 0;
      this.previewFrame = 0;
      this.renderCanvas();
      this.refreshInspector();
      this.refreshBattlerReference();
      const variant = `${this.selectedShiny ? "Shiny · " : ""}${this.selectedGender === 1 ? "Female · " : ""}Forma ${this.selectedForm}`;
      this.setStatus(`Sin icon exacto: ${variant}`, "warn");
      return;
    }
    this.setBusy(true, `Cargando ${basename(exact)}…`);
    try {
      const bytes = await this.fs.readBytes(exact);
      this.doc = await IconDocument.fromBytes(bytes, exact);
      this.doc.ensureTwoFrames(false);
      this.doc.dirty = false;
      this.activeFrame = 0;
      this.previewFrame = 0;
      this.setStatus(exact, "ok");
      this.renderCanvas();
      this.refreshInspector();
      this.refreshBattlerReference();
    } catch (e) {
      console.error("[Pokémon Icon Studio] load", e);
      this.doc = null;
      this.setStatus(e.message || String(e), "error");
      this.toast(e.message || String(e), "error");
      this.renderCanvas();
      this.refreshInspector();
      this.refreshBattlerReference();
    } finally { this.setBusy(false); }
  }

  selectFrame(index) {
    if (index === 1 && this.doc) this.doc.ensureTwoFrames();
    this.activeFrame = index;
    if (!this.playing) this.previewFrame = index;
    this.frame1Btn.classList.toggle("active", index === 0);
    this.frame2Btn.classList.toggle("active", index === 1);
    this.renderCanvas();
    this.refreshInspector();
  }

  renderCanvas() {
    if (!this.doc) {
      this.stageWrap.replaceChildren(this.emptyStage);
      this.stageInfo.textContent = "";
      this.refreshTopState();
      return;
    }
    if (!this.stageCard.isConnected) this.stageWrap.replaceChildren(this.stageCard);
    const c = this.canvas;
    c.width = this.doc.frameW;
    c.height = this.doc.frameH;
    const maxW = Math.min(620, Math.max(280, this.stageWrap.clientWidth - 70 || 520));
    const maxH = Math.min(540, Math.max(260, this.stageWrap.clientHeight - 90 || 440));
    const scale = Math.max(1, Math.min(8, Math.floor(Math.min(maxW / this.doc.frameW, maxH / this.doc.frameH))));
    c.style.width = `${this.doc.frameW * scale}px`;
    c.style.height = `${this.doc.frameH * scale}px`;
    const g = c.getContext("2d");
    g.clearRect(0, 0, c.width, c.height);
    g.imageSmoothingEnabled = false;
    const bg = this.canvasBackgroundColor();
    g.fillStyle = bg;
    g.fillRect(0, 0, c.width, c.height);
    this.stage.style.background = bg;
    const shown = this.playing ? this.previewFrame : this.activeFrame;
    if (this.onion && this.doc.frameCount > 1 && !this.playing) {
      const other = shown === 0 ? 1 : 0;
      this.doc.drawFrame(g, other, { alpha: this.onionAlpha });
    }
    this.doc.drawFrame(g, shown, { alpha: 1 });
    if (this.grid) {
      g.save();
      g.globalAlpha = .65;
      g.strokeStyle = this.canvasBackground === "dark" ? "#86bfff" : "#376d9f";
      g.lineWidth = 1 / Math.max(1, scale);
      g.setLineDash([3 / Math.max(1, scale), 3 / Math.max(1, scale)]);
      g.beginPath(); g.moveTo(this.doc.frameW / 2, 0); g.lineTo(this.doc.frameW / 2, this.doc.frameH); g.moveTo(0, this.doc.frameH / 2); g.lineTo(this.doc.frameW, this.doc.frameH / 2); g.stroke();
      g.restore();
    }
    const d = this.doc.diagnostics(this.activeFrame);
    const parts = [`${this.doc.frameW}×${this.doc.frameH}`, `${this.doc.frameCount} frame${this.doc.frameCount === 1 ? "" : "s"}`];
    if (d.empty) parts.push(`<span class="warn">Frame vacío</span>`);
    else if (d.clipped) parts.push(`<span class="bad">Parte del gráfico queda fuera del frame</span>`);
    else parts.push(`<span class="good">Dentro del canvas</span>`);
    this.stageInfo.innerHTML = parts.join(" · ");
    this.refreshTopState();
  }

  refreshTopState() {
    if (!this.titleEl) return;
    const sp = this.selectedSpecies;
    this.titleEl.innerHTML = "";
    if (!sp) { this.titleEl.textContent = "Selecciona un Pokémon"; return; }
    const variantBits = [`Forma ${this.selectedForm}`];
    if (this.selectedGender === 1) variantBits.push("Female");
    if (this.selectedShiny) variantBits.push("Shiny");
    this.titleEl.append(document.createTextNode(`${sp.name} · ${sp.id} · ${variantBits.join(" · ")}`));
    if (this.doc?.dirty) this.titleEl.append(h("span", { class: "pis-unsaved", text: "  ●" }));
    this.undoBtn.disabled = !this.doc?.undoStack?.length;
    this.redoBtn.disabled = !this.doc?.redoStack?.length;
    this.saveBtn.disabled = !this.doc;
  }

  refreshInspector() {
    const sp = this.selectedSpecies;
    this.speciesNameEl.textContent = sp ? `${sp.name}  [${sp.id}]` : "—";
    this.pathEl.textContent = this.targetPath || "—";
    if (this.sourceEl) {
      const fallback = sp && !this.doc ? this.catalog?.findFallbackVariant(sp, this.selectedForm, this.selectedGender, this.selectedShiny) : "";
      this.sourceEl.textContent = this.loadedPath || (fallback ? `Base disponible: ${fallback}` : "—");
    }
    this.formSelect.disabled = !sp;
    this.genderSelect.disabled = !sp;
    this.shinyCheck.disabled = !sp;
    this.genderSelect.value = String(this.selectedGender);
    this.shinyCheck.checked = !!this.selectedShiny;
    const baseCandidate = sp ? this.catalog?.findFallbackVariant(sp, this.selectedForm, this.selectedGender, this.selectedShiny) : "";
    this.createBaseBtn.disabled = !sp || !!this.doc || !baseCandidate;
    this.createBaseBtn.textContent = this.selectedShiny ? "Crear desde normal/base" : "Crear desde base";
    this.createBlankBtn.disabled = !sp || !!this.doc;
    this.resizeCanvasBtn.disabled = !this.doc;
    // shiny helpers — permitir crear shiny desde normal aunque el icon ya exista (sobrescribir)
    const normalBase = sp ? this.catalog?.findFallbackVariant(sp, this.selectedForm, this.selectedGender, false) : "";
    const shinyExists = sp ? !!this.catalog.findExactVariant(sp, this.selectedForm, this.selectedGender, true) : false;
    if (this.shinyFromNormalBtn) {
      this.shinyFromNormalBtn.disabled = !sp || !normalBase;
      this.shinyFromNormalBtn.textContent = shinyExists ? "Sobrescribir shiny desde normal" : "Crear shiny desde normal";
      this.shinyFromNormalBtn.title = shinyExists ? "Ya existe shiny — se sobrescribirá" : "Crea shiny usando el normal como base";
    }
    if (this.duplicateToShinyBtn) {
      this.duplicateToShinyBtn.disabled = !this.doc;
      this.duplicateToShinyBtn.textContent = shinyExists ? "Duplicar → sobrescribir shiny" : "Duplicar icon → shiny";
    }
    if (this.saveShinyBtn) this.saveShinyBtn.disabled = !this.doc;
    // escalado
    const hasDoc = !!this.doc;
    if (this.scaleX1Btn) this.scaleX1Btn.disabled = !hasDoc;
    if (this.scaleX2Btn) this.scaleX2Btn.disabled = !hasDoc;
    if (this.scaleHalfBtn) this.scaleHalfBtn.disabled = !hasDoc;
    if (this.scalePresetsEl) [...this.scalePresetsEl.querySelectorAll("button")].forEach((b) => b.disabled = !hasDoc);
    // pintura
    if (this.toolMoveBtn) { this.toolMoveBtn.disabled = !hasDoc; this.toolPickerBtn.disabled = !hasDoc; this.toolBucketBtn.disabled = !hasDoc; }
    if (this.fillColorInput) this.fillColorInput.disabled = !hasDoc;
    if (this.fillHexInput) this.fillHexInput.disabled = !hasDoc;
    if (this.toleranceRange) this.toleranceRange.disabled = !hasDoc;
    if (this.bucketModeSelect) this.bucketModeSelect.disabled = !hasDoc;
    if (this.bucketBothCheck) this.bucketBothCheck.disabled = !hasDoc;
    if (this.replaceAllBtn) this.replaceAllBtn.disabled = !hasDoc;
    this.syncFillPreview();
    if (!hasDoc) {
      this.setTool("move");
    } else {
      this.setTool(this.tool);
    }
    if (!this.doc) {
      this.xInput.value = "0"; this.yInput.value = "0";
      this.xInput.disabled = this.yInput.disabled = true;
      this.canvasWInput.disabled = this.canvasHInput.disabled = true;
      this.sizeEl.textContent = "—";
      this.diagEl.className = "pis-diagnostic";
      const variant = `${this.selectedShiny ? "shiny " : ""}${this.selectedGender === 1 ? "female " : ""}forma ${this.selectedForm}`;
      this.diagEl.textContent = sp ? `No existe un PNG exacto para ${variant}. Puedes crearlo desde el fallback del juego, importar uno o crear un icon vacío.` : "Sin icon cargado.";
      this.refreshTopState();
      return;
    }
    this.xInput.disabled = this.yInput.disabled = false;
    this.canvasWInput.disabled = this.canvasHInput.disabled = false;
    const o = this.doc.offsets[this.activeFrame] || { x: 0, y: 0 };
    this.xInput.value = String(o.x); this.yInput.value = String(o.y);
    this.canvasWInput.value = String(this.doc.frameW); this.canvasHInput.value = String(this.doc.frameH);
    this.sizeEl.textContent = `${this.doc.sheetW}×${this.doc.sheetH} · frame ${this.doc.frameW}×${this.doc.frameH}`;
    const d = this.doc.diagnostics(this.activeFrame);
    if (d.empty) {
      this.diagEl.className = "pis-diagnostic";
      this.diagEl.textContent = `Frame ${this.activeFrame + 1} vacío.`;
    } else if (d.clipped) {
      this.diagEl.className = "pis-diagnostic bad";
      this.diagEl.textContent = `Frame ${this.activeFrame + 1}: el offset (${o.x}, ${o.y}) recorta píxeles fuera del canvas. Puedes recolocarlo o ampliar el lienzo.`;
    } else {
      this.diagEl.className = "pis-diagnostic good";
      this.diagEl.textContent = `Frame ${this.activeFrame + 1}: gráfico completo dentro del canvas. Centro visual ΔX ${Math.round(d.shiftedCenterX)} / ΔY ${Math.round(d.shiftedCenterY)}.`;
    }
    this.refreshTopState();
  }

  setTool(tool) {
    this.tool = ["move", "picker", "bucket"].includes(tool) ? tool : "move";
    this.toolMoveBtn?.classList.toggle("active", this.tool === "move");
    this.toolPickerBtn?.classList.toggle("active", this.tool === "picker");
    this.toolBucketBtn?.classList.toggle("active", this.tool === "bucket");
    if (this.canvas) {
      this.canvas.style.cursor = this.tool === "picker" ? "crosshair" : this.tool === "bucket" ? "cell" : "grab";
      this.canvas.title = this.tool === "picker" ? "Cuentagotas: clic para tomar color" : this.tool === "bucket" ? "Cubo: clic para inundar" : "Arrastrar para mover";
    }
  }

  syncFillPreview() {
    if (this.fillPreview) this.fillPreview.style.background = this.fillColor;
    if (this.fillHexInput) this.fillHexInput.value = this.fillColor;
    if (this.fillColorInput && this.fillColorInput.value !== this.fillColor) this.fillColorInput.value = this.fillColor;
  }

  normalizeHex(v) {
    let s = String(v || "").trim();
    if (!s.startsWith("#")) s = "#" + s;
    if (/^#[0-9a-fA-F]{6}$/.test(s)) return s.toLowerCase();
    if (/^#[0-9a-fA-F]{3}$/.test(s)) return "#" + s.slice(1).split("").map((c) => c + c).join("").toLowerCase();
    return null;
  }

  pointerDown(e) {
    if (!this.doc || this.playing || e.button !== 0) return;
    const p = this.pointerCoords(e);
    // picker / bucket interceptan antes de drag — compensan offsets virtuales
    if (this.tool === "picker") {
      e.preventDefault();
      const off = this.doc.offsets[this.activeFrame] || { x: 0, y: 0 };
      const col = this.doc.pickColor(this.activeFrame, Math.floor(p.x - off.x), Math.floor(p.y - off.y));
      if (col) {
        this.fillColor = col;
        this.syncFillPreview();
        this.toast(`Color tomado: ${col}`, "ok");
      } else {
        this.toast("Pixel transparente — sin color.", "error");
      }
      return;
    }
    if (this.tool === "bucket") {
      e.preventDefault();
      const targets = this.bucketBoth ? [0, 1].filter((i) => this.doc.frames[i]) : [this.activeFrame];
      if (!targets.length) return;
      this.doc.checkpoint();
      let changed = 0;
      for (const idx of targets) {
        const off = this.doc.offsets[idx] || { x: 0, y: 0 };
        const ix = Math.floor(p.x - off.x), iy = Math.floor(p.y - off.y);
        if (this.bucketMode === "global") {
          const targetHex = this.doc.pickColor(idx, ix, iy);
          if (!targetHex) continue;
          if (lower(targetHex) === lower(this.fillColor)) continue;
          const cnt = this.doc.replaceColor(idx, targetHex, this.fillColor, this.tolerance);
          if (cnt) changed++;
        } else {
          if (this.doc.floodFill(idx, ix, iy, this.fillColor, this.tolerance)) changed++;
        }
      }
      if (changed) {
        this.toast(`Cubo aplicado en ${changed} frame(s) con ${this.fillColor} (tol ${this.tolerance}).`, "ok");
        this.renderCanvas(); this.refreshInspector();
      } else {
        // sin cambio, deshace checkpoint vacío
        this.doc.undoStack.pop();
        this.toast("Cubo sin cambios (mismo color o tolerancia baja).", "error");
      }
      return;
    }
    // move
    e.preventDefault();
    this.canvas.setPointerCapture(e.pointerId);
    this.doc.checkpoint();
    this.drag = { pointerId: e.pointerId, startX: p.x, startY: p.y, offsets: this.doc.offsets.map((o) => ({ ...o })) };
  }

  pointerMove(e) {
    if (!this.drag || !this.doc || e.pointerId !== this.drag.pointerId) return;
    if (this.tool !== "move") return;
    const p = this.pointerCoords(e);
    const dx = Math.round(p.x - this.drag.startX), dy = Math.round(p.y - this.drag.startY);
    const indices = this.moveBoth ? [0, 1].filter((i) => this.doc.offsets[i]) : [this.activeFrame];
    for (const i of indices) this.doc.setOffset(i, this.drag.offsets[i].x + dx, this.drag.offsets[i].y + dy);
    this.renderCanvas(); this.refreshInspector();
  }

  pointerUp(e) {
    if (!this.drag || e.pointerId !== this.drag.pointerId) return;
    try { this.canvas.releasePointerCapture(e.pointerId); } catch (_) {}
    this.drag = null;
    this.renderCanvas(); this.refreshInspector();
  }

  pointerCoords(e) {
    const r = this.canvas.getBoundingClientRect();
    return { x: (e.clientX - r.left) * this.canvas.width / r.width, y: (e.clientY - r.top) * this.canvas.height / r.height };
  }

  nudge(dx, dy, amount = 1) {
    if (!this.doc) return;
    this.doc.checkpoint();
    this.doc.nudge(this.activeFrame, dx * amount, dy * amount, this.moveBoth);
    this.renderCanvas(); this.refreshInspector();
  }

  centerFrame() {
    if (!this.doc) return;
    this.doc.checkpoint(); this.doc.centerFrame(this.activeFrame);
    if (this.moveBoth && this.doc.offsets[1]) this.doc.centerFrame(this.activeFrame === 0 ? 1 : 0);
    this.renderCanvas(); this.refreshInspector();
  }

  copyPosition(from, to) {
    if (!this.doc || !this.doc.offsets[to]) return;
    this.doc.checkpoint(); this.doc.copyOffset(from, to);
    this.renderCanvas(); this.refreshInspector();
  }

  copyFrameGraphic(from, to) {
    if (!this.doc || !this.doc.frames[to]) return;
    this.doc.checkpoint(); this.doc.copyFrameGraphic(from, to);
    this.renderCanvas(); this.refreshInspector();
  }

  applyOffsetInputs() {
    if (!this.doc) return;
    this.doc.checkpoint();
    const x = Number(this.xInput.value) || 0, y = Number(this.yInput.value) || 0;
    if (this.moveBoth) {
      const old = this.doc.offsets[this.activeFrame];
      const dx = x - old.x, dy = y - old.y;
      this.doc.nudge(this.activeFrame, dx, dy, true);
    } else this.doc.setOffset(this.activeFrame, x, y);
    this.renderCanvas(); this.refreshInspector();
  }

  applyCanvasSize() {
    if (!this.doc) return;
    const w = Math.max(1, Math.min(4096, Math.round(Number(this.canvasWInput.value) || this.doc.frameW)));
    const hgt = Math.max(1, Math.min(4096, Math.round(Number(this.canvasHInput.value) || this.doc.frameH)));
    if (w === this.doc.frameW && hgt === this.doc.frameH) return;
    this.doc.checkpoint();
    this.doc.resizeCanvas(w, hgt, { anchor: "center" });
    this.toast(`Lienzo ajustado a ${w}×${hgt} por frame.`, "ok");
    this.renderCanvas(); this.refreshInspector();
  }

  // --- Escalado pixel-art ------------------------------------------------
  applyScaleFactor(factor) {
    if (!this.doc) return;
    factor = Number(factor);
    if (!factor || factor === 1) {
      // x1 no escala, solo informa tamaño actual
      this.toast(`Escala ×1: ${this.doc.frameW}×${this.doc.frameH}`, "ok");
      return;
    }
    const old = `${this.doc.frameW}×${this.doc.frameH}`;
    this.doc.checkpoint();
    if (!this.doc.scaleContent(factor)) {
      this.doc.undoStack.pop();
      this.toast("Escalado no aplicado (límite 4096 o factor inválido).", "error");
      return;
    }
    this.toast(`Escalado ${old} → ${this.doc.frameW}×${this.doc.frameH} (×${factor}).`, "ok");
    this.renderCanvas(); this.refreshInspector();
  }

  applyScaleTo(w, h) {
    if (!this.doc) return;
    w = Math.max(1, Math.min(4096, Math.round(Number(w))));
    h = Math.max(1, Math.min(4096, Math.round(Number(h))));
    if (w === this.doc.frameW && h === this.doc.frameH) return;
    this.doc.checkpoint();
    const old = `${this.doc.frameW}×${this.doc.frameH}`;
    if (!this.doc.scaleTo(w, h)) { this.doc.undoStack.pop(); return; }
    this.toast(`Escalado ${old} → ${w}×${h}.`, "ok");
    this.renderCanvas(); this.refreshInspector();
  }

  resetScaleFromBattler() {
    if (!this.doc) return;
    // heurística: si battler existe, sugiere tamaño nativo del icon medio del proyecto (64), sino 64
    this.applyScaleTo(64, 64);
  }

  // --- Shiny helpers -----------------------------------------------------
  async createShinyFromNormal() {
    if (!this.selectedSpecies) return;
    const normalPath = this.catalog.findExactVariant(this.selectedSpecies, this.selectedForm, this.selectedGender, false)
      || this.catalog.findFallbackVariant(this.selectedSpecies, this.selectedForm, this.selectedGender, false);
    if (!normalPath) return this.toast("No hay icon normal para usar como base.", "error");
    const shinyExists = !!this.catalog.findExactVariant(this.selectedSpecies, this.selectedForm, this.selectedGender, true);
    if (shinyExists && !(await this.confirmAction(`Ya existe shiny en ${canonicalIconPath(this.selectedSpecies.id, this.selectedForm, this.selectedGender, true)}. ¿Sobrescribir con el normal?`, "Sobrescribir", "Cancelar"))) return;
    if (this.doc?.dirty && !(await this.confirmAction("Hay cambios sin guardar. ¿Crear shiny desde normal y descartarlos?"))) return;
    try {
      const bytes = await this.fs.readBytes(normalPath);
      this.selectedShiny = true;
      if (this.shinyCheck) this.shinyCheck.checked = true;
      this.targetPath = canonicalIconPath(this.selectedSpecies.id, this.selectedForm, this.selectedGender, true);
      this.doc = await IconDocument.fromBytes(bytes, this.targetPath);
      this.doc.ensureTwoFrames(false);
      this.doc.dirty = true;
      this.loadedPath = normalPath;
      this.populateForms();
      this.toast(`Shiny ${shinyExists ? "sobrescrito" : "creado"} desde normal: ${basename(normalPath)}`, "ok");
      this.renderCanvas(); this.refreshInspector(); this.refreshBattlerReference();
    } catch (e) { this.toast(e.message || String(e), "error"); }
  }

  async duplicateToShiny() {
    if (!this.doc || !this.selectedSpecies) return this.toast("Carga primero un icon.", "error");
    const shinyPath = canonicalIconPath(this.selectedSpecies.id, this.selectedForm, this.selectedGender, true);
    const shinyExists = !!this.catalog.findExactVariant(this.selectedSpecies, this.selectedForm, this.selectedGender, true);
    if (shinyExists && !(await this.confirmAction(`Ya existe shiny en ${shinyPath}. ¿Sobrescribir con el icon actual?`, "Sobrescribir", "Cancelar"))) return;
    try {
      const clone = await this.doc.cloneAs(shinyPath);
      // guarda directamente en Icons shiny
      const blob = await clone.renderSheetBlob();
      await this.fs.writeBytes(shinyPath, await blobToBytes(blob));
      // registra en catálogo
      if (!this.catalog.shinyIconPaths.some((p) => lower(p) === lower(shinyPath))) this.catalog.shinyIconPaths.push(shinyPath);
      if (!this.catalog.iconPaths.some((p) => lower(p) === lower(shinyPath))) this.catalog.iconPaths.push(shinyPath);
      this.catalog.assetSet.add(lower(shinyPath));
      let a = this.selectedSpecies.iconAssets.find((x) => lower(x.path) === lower(shinyPath));
      if (!a) { a = { path: shinyPath, form: this.selectedForm, gender: this.selectedGender, shiny: true, shadow: false }; this.selectedSpecies.iconAssets.push(a); }
      if (!this.selectedSpecies.iconPaths.some((p) => lower(p) === lower(shinyPath))) this.selectedSpecies.iconPaths.push(shinyPath);
      this.toast(`Duplicado a shiny: ${shinyPath}`, "ok");
      this.renderSpeciesList();
      // cambia a variante shiny para seguir editando
      if (!this.selectedShiny) {
        this.selectedShiny = true;
        if (this.shinyCheck) this.shinyCheck.checked = true;
        this.populateForms();
        this.targetPath = shinyPath;
        this.loadedPath = shinyPath;
        this.doc.sourcePath = shinyPath;
        this.doc.dirty = false;
        this.refreshInspector(); this.refreshBattlerReference();
      }
    } catch (e) { this.toast(e.message || String(e), "error"); }
  }

  async saveShinyDirect() {
    if (!this.doc || !this.selectedSpecies) return;
    const p = canonicalIconPath(this.selectedSpecies.id, this.selectedForm, this.selectedGender, true);
    await this.save(p);
  }

  replaceColorGlobal() {
    if (!this.doc) return;
    const hex = this.normalizeHex(this.fillColor) || this.fillColor;
    // necesita color origen: toma del pixel central o del último pick implícito
    // usamos cuentagotas sobre centro si no hay origen previo, sino pide al usuario
    const src = this.doc.pickColor(this.activeFrame, Math.floor(this.doc.frameW / 2), Math.floor(this.doc.frameH / 2));
    // si src es null, no hay color central visible; probamos primer pixel no transparente
    let target = src;
    if (!target) {
      // fallback: busca primer pixel opaco
      for (let y = 0; y < this.doc.frameH && !target; y++) for (let x = 0; x < this.doc.frameW && !target; x++) target = this.doc.pickColor(this.activeFrame, x, y);
    }
    if (!target) return this.toast("No hay color origen visible para reemplazar.", "error");
    if (lower(target) === lower(hex)) return this.toast("Origen y destino iguales.", "error");
    const indices = this.bucketBoth ? [0, 1].filter((i) => this.doc.frames[i]) : [this.activeFrame];
    this.doc.checkpoint();
    let total = 0;
    for (const idx of indices) total += this.doc.replaceColor(idx, target, hex, this.tolerance);
    if (total) { this.toast(`Reemplazados ${total} px ${target} → ${hex} (tol ${this.tolerance}).`, "ok"); this.renderCanvas(); this.refreshInspector(); }
    else { this.doc.undoStack.pop(); this.toast("Ningún pixel coincidió con la tolerancia.", "error"); }
  }

  // --- Battler paleta ----------------------------------------------------
  async refreshBattlerReference() {
    if (!this.selectedSpecies || !this.catalog) return;
    const sp = this.selectedSpecies;
    const form = this.selectedForm, gender = this.selectedGender;
    const normalPath = this.catalog.findBattlerFallback(sp, form, gender, false) || this.catalog.findBattlerExact(sp, form, gender, false) || canonicalBattlerPath(sp.id, form, gender, false, false);
    const shinyPath = this.catalog.findBattlerFallback(sp, form, gender, true) || this.catalog.findBattlerExact(sp, form, gender, true) || canonicalBattlerPath(sp.id, form, gender, true, false);
    this.battlerInfoEl.textContent = `—`;
    this.battlerNormalWrap.textContent = "—"; this.battlerShinyWrap.textContent = "—";
    this.battlerPalette = [];
    this.battlerBytesNormal = null; this.battlerBytesShiny = null;
    this.battlerPaletteEl.replaceChildren();
    let normalBytes = null, shinyBytes = null;
    const loadOne = async (path, wrap, isShiny) => {
      if (!path) { wrap.textContent = "—"; return; }
      try {
        const exists = await this.fs.exists(path);
        if (!exists) { wrap.textContent = "—"; wrap.title = `${path} no existe`; return; }
        const bytes = await this.fs.readBytes(path);
        wrap.textContent = "";
        // genera preview de un solo frame (no tira) — battlers vienen en strip horizontal 2800x50 etc
        let preview = null;
        try {
          const blob = new Blob([bytes], { type: "image/png" });
          const bmp = await decodeBlob(blob);
          const layout = detectBattlerLayout(bmp.width, bmp.height);
          const fw = layout.frameW, fh = layout.frameH;
          // limita preview a 64 pero mantiene ratio, si sheet tiene 1 frame usa tamaño original
          const c = makeCanvas(fw, fh);
          const cc = c.getContext("2d", { willReadFrequently: true });
          cc.imageSmoothingEnabled = false;
          cc.drawImage(bmp, 0, 0, fw, fh, 0, 0, fw, fh);
          if (typeof bmp.close === "function") try { bmp.close(); } catch (_) {}
          // escala visual para thumb 64
          const scale = Math.min(64 / fw, 64 / fh, 4);
          c.style.width = `${Math.round(fw * scale)}px`;
          c.style.height = `${Math.round(fh * scale)}px`;
          c.style.imageRendering = "pixelated";
          c.title = `${basename(path)} · ${bmp.width}×${bmp.height} → frame ${fw}×${fh}${layout.frameCount > 1 ? ` ×${layout.frameCount}` : ""}`;
          c.classList.add("pis-battler-canvas");
          preview = c;
        } catch (_) {
          // fallback a img completa si decode falla
          const url = await this.fs.assetUrl(path);
          const img = h("img", { alt: basename(path), title: path });
          img.src = url;
          img.style.imageRendering = "pixelated";
          img.style.maxWidth = "64px"; img.style.maxHeight = "64px";
          preview = img;
        }
        const localBytes = bytes.slice ? bytes.slice() : bytes;
        preview.addEventListener("click", (ev) => {
          // cuentagotas directo desde battler: toma color exacto donde clicas
          if (this.tool === "picker" && preview.tagName === "CANVAS") {
            try {
              const rect = preview.getBoundingClientRect();
              const px = Math.floor((ev.clientX - rect.left) * preview.width / rect.width);
              const py = Math.floor((ev.clientY - rect.top) * preview.height / rect.height);
              const cc2 = preview.getContext("2d", { willReadFrequently: true });
              const d = cc2.getImageData(Math.max(0, Math.min(preview.width - 1, px)), Math.max(0, Math.min(preview.height - 1, py)), 1, 1).data;
              if (d[3] >= 16) {
                const col = `#${[d[0], d[1], d[2]].map((v) => v.toString(16).padStart(2, "0")).join("")}`;
                this.fillColor = col;
                this.syncFillPreview();
                this.toast(`Battler color: ${col}`, "ok");
                return;
              }
            } catch (_) {}
            this.toast("Pixel battler transparente.", "error");
            return;
          }
          this.handleBattlerPick(localBytes);
        });
        preview.style.cursor = "pointer";
        wrap.append(preview);
        if (isShiny) { this.battlerBytesShiny = bytes; shinyBytes = bytes; }
        else { this.battlerBytesNormal = bytes; normalBytes = bytes; }
      } catch (_) { wrap.textContent = "!"; }
    };
    await Promise.all([loadOne(normalPath, this.battlerNormalWrap, false), loadOne(shinyPath, this.battlerShinyWrap, true)]);
    // prioriza paleta shiny para crear shiny; si no hay shiny, usa normal
    const paletteSource = shinyBytes || normalBytes;
    if (paletteSource) await this.extractPaletteFromBytes(paletteSource);
    if (this.battlerPalette.length) {
      this.battlerInfoEl.textContent = `${this.battlerPalette.length} colores battler${shinyBytes ? " shiny" : " normal"}`;
      this.renderBattlerPalette();
    } else {
      this.battlerInfoEl.textContent = normalPath ? `Battler: ${basename(normalPath)} (sin paleta)` : "Sin battler";
    }
  }

  async extractPaletteFromBytes(bytes) {
    try {
      const blob = new Blob([bytes], { type: "image/png" });
      const img = await decodeBlob(blob);
      const w = img.width, h = img.height;
      if (!w || !h) return;
      const layout = detectBattlerLayout(w, h);
      const fw = layout.frameW, fh = layout.frameH;
      // ponytail: solo frame 1 para paleta, evita contar toda la tira animada
      const cw = layout.frameCount > 1 ? fw : w;
      const ch = layout.frameCount > 1 ? fh : h;
      const c = makeCanvas(cw, ch);
      const cc = c.getContext("2d", { willReadFrequently: true });
      cc.imageSmoothingEnabled = false;
      if (layout.frameCount > 1) cc.drawImage(img, 0, 0, fw, fh, 0, 0, fw, fh);
      else cc.drawImage(img, 0, 0);
      if (typeof img.close === "function") try { img.close(); } catch (_) {}
      const data = cc.getImageData(0, 0, cw, ch).data;
      const map = new Map();
      for (let i = 0; i < data.length; i += 4) {
        const a = data[i + 3]; if (a < 16) continue;
        const r = data[i], g = data[i + 1], b = data[i + 2];
        const key = `${r},${g},${b}`;
        map.set(key, (map.get(key) || 0) + 1);
      }
      const sorted = [...map.entries()].sort((a, b) => b[1] - a[1]).slice(0, 36).map(([k]) => {
        const [r, g, b] = k.split(",").map(Number);
        return `#${[r, g, b].map((v) => v.toString(16).padStart(2, "0")).join("")}`;
      });
      this.battlerPalette = sorted;
      this.renderBattlerPalette();
    } catch (_) {}
  }

  handleBattlerPick(bytes) {
    // extrae paleta y deja que el usuario elija color clicando swatch (ya hace set fillColor)
    this.extractPaletteFromBytes(bytes);
  }

  renderBattlerPalette() {
    if (!this.battlerPaletteEl) return;
    this.battlerPaletteEl.replaceChildren();
    if (!this.battlerPalette.length) { this.battlerPaletteEl.textContent = "—"; return; }
    for (const col of this.battlerPalette) {
      const sw = h("span", { class: "pis-swatch", title: col, style: `background:${col}` });
      sw.addEventListener("click", () => { this.fillColor = col; this.syncFillPreview(); this.toast(`Relleno: ${col}`, "ok"); });
      this.battlerPaletteEl.append(sw);
    }
  }

  undo() { if (this.doc?.undo()) { this.renderCanvas(); this.refreshInspector(); } }
  redo() { if (this.doc?.redo()) { this.renderCanvas(); this.refreshInspector(); } }

  togglePlay() {
    if (!this.doc) return;
    if (this.playing) { this.stopPlay(); this.renderCanvas(); return; }
    this.playing = true;
    this.previewFrame = 0;
    this.playBtn.textContent = "■ Detener";
    this.playBtn.classList.add("active");
    this.playTimer = setInterval(() => {
      if (!this.doc) return this.stopPlay();
      this.previewFrame = this.previewFrame === 0 ? Math.min(1, this.doc.frameCount - 1) : 0;
      this.renderCanvas();
    }, 280);
    this.renderCanvas();
  }

  stopPlay() {
    this.playing = false;
    if (this.playTimer) clearInterval(this.playTimer);
    this.playTimer = null;
    if (this.playBtn) { this.playBtn.textContent = "▶ Preview"; this.playBtn.classList.remove("active"); }
    this.previewFrame = this.activeFrame;
  }

  async copyFrame() {
    if (!this.doc) return;
    try {
      const blob = await this.doc.renderFrameBlob(this.activeFrame);
      this.internalClipboard = blob;
      const system = await clipboardWrite(blob).catch(() => false);
      this.toast(system ? `Frame ${this.activeFrame + 1} copiado al portapapeles.` : `Frame ${this.activeFrame + 1} copiado dentro de Icon Studio.`, "ok");
    } catch (e) { this.toast(e.message || String(e), "error"); }
  }

  async copyIcon() {
    if (!this.doc) return;
    try {
      const blob = await this.doc.renderSheetBlob();
      this.internalClipboard = blob;
      const system = await clipboardWrite(blob).catch(() => false);
      this.toast(system ? "Icon completo copiado al portapapeles." : "Icon completo copiado dentro de Icon Studio.", "ok");
    } catch (e) { this.toast(e.message || String(e), "error"); }
  }

  async pasteFromClipboard(mode = this.incomingMode) {
    try {
      const blob = await clipboardReadImage().catch(() => null) || this.internalClipboard;
      if (!blob) return this.toast("No hay una imagen disponible en el portapapeles.", "error");
      await this.applyIncomingImage(blob, "portapapeles", mode);
    } catch (e) { this.toast(e.message || String(e), "error"); }
  }

  async onPasteEvent(e) {
    if (!this.root?.isConnected) return;
    const tag = String(e.target?.tagName || "").toLowerCase();
    if (tag === "input" || tag === "textarea") return;
    const item = [...(e.clipboardData?.items || [])].find((x) => x.type.startsWith("image/"));
    if (!item) return;
    e.preventDefault();
    const file = item.getAsFile();
    if (file) await this.applyIncomingImage(file, "portapapeles", this.incomingMode);
  }

  async importFile(file) {
    if (!file) return;
    try { await this.applyIncomingImage(file, file.name || "archivo", this.incomingMode); }
    catch (e) { this.toast(e.message || String(e), "error"); }
  }

  async applyIncomingImage(blob, sourceLabel, mode = "auto") {
    if (!this.selectedSpecies) return this.toast("Selecciona primero una especie.", "error");
    const info = await imageInfo(blob);
    mode = ["auto", "frame", "sheet"].includes(mode) ? mode : "auto";
    if (!this.doc) {
      if (mode === "frame") {
        this.doc = IconDocument.blank(info.width, info.height, 2, this.targetPath);
        this.doc.checkpoint();
        await this.doc.replaceFrameFromBlob(blob, this.activeFrame, { expandToFit: this.autoExpandIncoming });
        this.toast(`Frame ${this.activeFrame + 1} creado desde ${sourceLabel} con lienzo ${this.doc.frameW}×${this.doc.frameH}.`, "ok");
      } else {
        this.doc = await IconDocument.fromBlob(blob, this.targetPath);
        this.doc.ensureTwoFrames(false);
        this.toast(`Icon creado desde ${sourceLabel}.`, "ok");
      }
      this.doc.dirty = true;
      this.loadedPath = "";
    } else {
      this.doc.checkpoint();
      const layout = detectLayout(info.width, info.height);
      const looksLikeSheet = mode === "sheet" || (mode === "auto" && ((info.width === this.doc.sheetW && info.height === this.doc.sheetH) || layout.frameCount >= 2));
      if (looksLikeSheet) {
        await this.doc.replaceSheetFromBlob(blob);
        this.toast(`Icon completo reemplazado desde ${sourceLabel}.`, "ok");
      } else {
        const before = `${this.doc.frameW}×${this.doc.frameH}`;
        await this.doc.replaceFrameFromBlob(blob, this.activeFrame, { expandToFit: this.autoExpandIncoming });
        const after = `${this.doc.frameW}×${this.doc.frameH}`;
        this.toast(before === after ? `Frame ${this.activeFrame + 1} reemplazado desde ${sourceLabel}.` : `Frame importado y lienzo ampliado ${before} → ${after}.`, "ok");
      }
    }
    this.renderCanvas(); this.refreshInspector();
  }

  async createFromBase() {
    if (!this.selectedSpecies || this.doc) return;
    const basePath = this.catalog.findFallbackVariant(this.selectedSpecies, this.selectedForm, this.selectedGender, this.selectedShiny);
    if (!basePath) return this.toast("Esta especie no tiene un icon compatible para usar como base.", "error");
    try {
      const bytes = await this.fs.readBytes(basePath);
      this.doc = await IconDocument.fromBytes(bytes, this.targetPath);
      this.doc.ensureTwoFrames(false);
      this.doc.dirty = true;
      this.loadedPath = basePath;
      this.toast(`Nueva variante preparada desde ${basename(basePath)}.`, "ok");
      this.renderCanvas(); this.refreshInspector(); this.refreshBattlerReference();
    } catch (e) { this.toast(e.message || String(e), "error"); }
  }

  async createBlank() {
    if (!this.selectedSpecies || this.doc) return;
    let w = 64, hh = 64;
    const sample = this.catalog.normalIconPaths[0] || this.catalog.iconPaths[0];
    if (sample) {
      try {
        const bytes = await this.fs.readBytes(sample);
        const sampleDoc = await IconDocument.fromBytes(bytes, sample);
        w = sampleDoc.frameW; hh = sampleDoc.frameH;
      } catch (_) {}
    }
    this.doc = IconDocument.blank(w, hh, 2, this.targetPath);
    this.toast(`Icon vacío ${w}×${hh} × 2 creado.`, "ok");
    this.renderCanvas(); this.refreshInspector(); this.refreshBattlerReference();
  }

  async save(path = this.targetPath) {
    if (!this.doc || !path || this.busy) return;
    this.setBusy(true, `Guardando ${basename(path)}…`);
    try {
      const blob = await this.doc.renderSheetBlob();
      await this.fs.writeBytes(path, await blobToBytes(blob));
      this.doc.bakeOffsets();
      this.doc.sourcePath = path;
      this.doc.dirty = false;
      this.targetPath = path;
      this.loadedPath = path;
      if (!this.selectedSpecies.iconPaths.some((p) => lower(p) === lower(path))) this.selectedSpecies.iconPaths.push(path);
      this.catalog.assetSet.add(lower(path));
      const globalList = this.selectedShiny ? this.catalog.shinyIconPaths : this.catalog.normalIconPaths;
      if (!globalList.some((p) => lower(p) === lower(path))) globalList.push(path);
      if (!this.catalog.iconPaths.some((p) => lower(p) === lower(path))) this.catalog.iconPaths.push(path);
      let asset = this.selectedSpecies.iconAssets.find((a) => lower(a.path) === lower(path));
      if (!asset) {
        asset = { path, form: this.selectedForm, gender: this.selectedGender, shiny: this.selectedShiny, shadow: false };
        this.selectedSpecies.iconAssets.push(asset);
      } else Object.assign(asset, { form: this.selectedForm, gender: this.selectedGender, shiny: this.selectedShiny, shadow: false });
      this.populateForms();
      this.toast(`Guardado: ${path}`, "ok");
      this.setStatus(path, "ok");
      this.renderCanvas(); this.refreshInspector(); this.renderSpeciesList();
    } catch (e) {
      console.error("[Pokémon Icon Studio] save", e);
      this.setStatus(e.message || String(e), "error");
      this.toast(e.message || String(e), "error");
    } finally { this.setBusy(false); }
  }

  async saveAsId() {
    if (!this.selectedSpecies || !this.doc) return;
    const path = canonicalIconPath(this.selectedSpecies.id, this.selectedForm, this.selectedGender, this.selectedShiny);
    await this.save(path);
  }

  async exportCurrent() {
    if (!this.selectedSpecies || !this.doc) return;
    try {
      const blob = await this.doc.renderSheetBlob();
      const name = basename(canonicalIconPath(this.selectedSpecies.id, this.selectedForm, this.selectedGender, this.selectedShiny));
      downloadBlob(blob, name);
      this.toast(`Exportado como ${name}.`, "ok");
    } catch (e) { this.toast(e.message || String(e), "error"); }
  }

  onKeyDown(e) {
    if (!this.root?.isConnected) return;
    if (e.key === "F11") { e.preventDefault(); this.toggleFullscreen(); return; }
    if (e.key === "Escape" && this.fullscreenActive) { e.preventDefault(); this.exitFullscreen(); return; }
    const tag = String(e.target?.tagName || "").toLowerCase();
    const editing = tag === "input" || tag === "textarea" || tag === "select";
    if ((e.ctrlKey || e.metaKey) && lower(e.key) === "s") { e.preventDefault(); this.save(); return; }
    if ((e.ctrlKey || e.metaKey) && lower(e.key) === "z") { e.preventDefault(); e.shiftKey ? this.redo() : this.undo(); return; }
    if ((e.ctrlKey || e.metaKey) && lower(e.key) === "y") { e.preventDefault(); this.redo(); return; }
    if (editing) {
      if (!e.ctrlKey && !e.metaKey && lower(e.key) === "i" && this.doc) { /* permitir i/b incluso editando si es select */ }
      else return;
    }
    if (!editing && this.doc) {
      if ((e.ctrlKey || e.metaKey) && lower(e.key) === "c") { e.preventDefault(); this.copyFrame(); return; }
      if ((e.ctrlKey || e.metaKey) && lower(e.key) === "v") { e.preventDefault(); this.pasteFromClipboard(); return; }
    }
    if (!editing && this.doc) {
      const k = lower(e.key);
      if (k === "i" && !e.ctrlKey && !e.metaKey) { e.preventDefault(); this.setTool(this.tool === "picker" ? "move" : "picker"); return; }
      if (k === "b" && !e.ctrlKey && !e.metaKey) { e.preventDefault(); this.setTool(this.tool === "bucket" ? "move" : "bucket"); return; }
      if (k === "m" && !e.ctrlKey && !e.metaKey) { e.preventDefault(); this.setTool("move"); return; }
    }
    if (editing || !this.doc) return;
    const amount = e.shiftKey ? 5 : 1;
    const dirs = { ArrowLeft: [-1, 0], ArrowRight: [1, 0], ArrowUp: [0, -1], ArrowDown: [0, 1] };
    if (dirs[e.key]) { e.preventDefault(); this.nudge(dirs[e.key][0], dirs[e.key][1], amount); }
    if (e.key === "1") this.selectFrame(0);
    if (e.key === "2") this.selectFrame(1);
    if (e.code === "Space") { e.preventDefault(); this.togglePlay(); }
  }
}

export function mountPokemonIconStudio(ctx, host) {
  if (currentStudio) currentStudio.dispose();
  const studio = new PokemonIconStudio(ctx);
  currentStudio = studio;
  studio.open(host).catch((e) => {
    try { ctx?.log?.error?.(e); } catch (_) {}
    studio.setStatus(e?.message || String(e), "error");
    studio.toast(e?.message || String(e), "error");
  });
  return () => studio.dispose();
}

export async function openPokemonIconStudio(ctx) {
  if (currentStudio?.root?.isConnected) {
    currentStudio.root.focus();
    return currentStudio;
  }
  currentStudio = new PokemonIconStudio(ctx);
  await currentStudio.open(null);
  return currentStudio;
}

export function closePokemonIconStudio(force = false) {
  if (!currentStudio) return;
  if (force) currentStudio.dispose();
  else currentStudio.requestClose();
}
export { PokemonIconStudio };
