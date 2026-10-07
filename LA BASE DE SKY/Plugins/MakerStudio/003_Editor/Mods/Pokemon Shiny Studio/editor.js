import { installStyles } from "./styles.js";
import {
  ProjectFS,
  canonicalSpritePath,
  loadVariantsConfig,
  saveVariantsConfig,
  loadPokemonCatalog,
  loadImageElement
} from "./assets.js";
import {
  extractPalette,
  applyColorSwap,
  applyHslAdjustment,
  extractColorMapBetween,
  cloneCanvas,
  canvasToBlob,
  rgbToHex,
  hexToRgb
} from "./palette.js";

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

export async function mountPokemonShinyStudio(ctx, host) {
  installStyles();
  host.innerHTML = "";

  const fs = new ProjectFS(ctx);
  let catalog = [];
  let variants = [];
  let currentSpecies = null;
  let currentGender = 0; // 0 = male, 1 = female
  let currentVariant = "supershiny"; // 'normal', 'shiny', 'supershiny', or custom ID
  let currentMode = "palette"; // 'palette' | 'hsl'
  let zoom = 2;

  // Transformaciones actuales
  let paletteTarget = "battler"; // 'battler' | 'icon'
  let colorMap = new Map(); // oldHex => newHex para Battler
  let iconColorMap = new Map(); // oldHex => newHex para Icono
  let hslSettings = { hueShift: 0, satMult: 1, lightShift: 0 };
  let syncIcon = true;
  let syncBack = true;

  // Estado en memoria de ambas versiones (♂ Estándar y ♀ Hembra) para herencia bidireccional
  let maleState = {
    speciesId: null,
    form: 0,
    variant: "supershiny",
    mode: "palette",
    colorMap: new Map(),
    iconColorMap: new Map(),
    hslSettings: { hueShift: 0, satMult: 1, lightShift: 0 }
  };

  let femaleState = {
    speciesId: null,
    form: 0,
    variant: "supershiny",
    mode: "palette",
    colorMap: new Map(),
    iconColorMap: new Map(),
    hslSettings: { hueShift: 0, satMult: 1, lightShift: 0 }
  };

  function recordGenderState() {
    if (!currentSpecies) return;
    const target = currentGender === 0 ? maleState : femaleState;
    target.speciesId = currentSpecies.id;
    target.form = currentSpecies.form;
    target.variant = currentVariant;
    target.mode = currentMode;
    target.colorMap = new Map(colorMap);
    target.iconColorMap = new Map(iconColorMap);
    target.hslSettings = { ...hslSettings };
  }

  const recordMaleState = recordGenderState;

  // Canvases base cargados desde archivo
  let baseFront = null;
  let baseBack = null;
  let baseIcon = null;

  // Canvases de trabajo resultantes
  const frontCanvas = h("canvas", { class: "pss-canvas" });
  const backCanvas = h("canvas", { class: "pss-canvas" });
  const iconCanvas = h("canvas", { class: "pss-canvas" });

  let iconAnimInterval = null;
  let iconAnimFrame = 0;

  // Root UI
  const root = h("div", { class: "pss-root" });
  host.appendChild(root);

  // Mensaje de carga inicial
  const loadingNotice = h("div", {
    style: "display:flex; justify-content:center; align-items:center; height:100%; font-size:16px; color:#94a3b8;"
  }, "Cargando catálogo de especies y variantes...");
  root.appendChild(loadingNotice);

  try {
    catalog = await loadPokemonCatalog(fs);
    variants = await loadVariantsConfig(fs);
  } catch (err) {
    console.error("Error al cargar datos:", err);
  }

  root.innerHTML = "";

  // -------------------------------------------------------------
  // UI Builders
  // -------------------------------------------------------------

  // Top bar
  const tabsContainer = h("div", { class: "pss-tabs" });
  const actionsContainer = h("div", { class: "pss-actions" });

  const topBar = h("div", { class: "pss-topbar" },
    h("div", { class: "pss-title" },
      h("span", { style: "font-size:18px;" }, "✦"),
      "Pokémon Shiny Studio"
    ),
    tabsContainer,
    actionsContainer
  );
  root.appendChild(topBar);

  // Main body
  const body = h("div", { class: "pss-body" });
  root.appendChild(body);

  // 1. Sidebar (Especies)
  const searchInput = h("input", {
    class: "pss-input",
    placeholder: "Buscar Pokémon...",
    oninput: () => renderSpeciesList()
  });
  const speciesListEl = h("div", { class: "pss-species-list" });
  const sidebar = h("div", { class: "pss-sidebar" },
    h("div", { class: "pss-sidebar-search" }, searchInput),
    speciesListEl
  );
  body.appendChild(sidebar);

  // 2. Center Area (Canvases)
  const zoomSelect = h("select", {
    class: "pss-input",
    style: "width:80px; padding:3px 6px;",
    onchange: (e) => {
      zoom = Number(e.target.value);
      updateCanvasZoom();
    }
  },
    h("option", { value: "1" }, "1x"),
    h("option", { value: "2", selected: true }, "2x"),
    h("option", { value: "3" }, "3x"),
    h("option", { value: "4" }, "4x")
  );

  const genderSelect = h("select", {
    class: "pss-input",
    style: "width:110px; padding:3px 6px;",
    onchange: (e) => {
      recordMaleState();
      currentGender = Number(e.target.value);
      loadSpeciesSprites();
    }
  },
    h("option", { value: "0" }, "♂ / Estándar"),
    h("option", { value: "1" }, "♀ Hembra")
  );

  const centerToolbar = h("div", { class: "pss-center-toolbar" },
    h("span", { style: "color:#94a3b8; font-size:11px;" }, "Zoom:"),
    zoomSelect,
    h("span", { style: "color:#94a3b8; font-size:11px; margin-left:12px;" }, "Género:"),
    genderSelect
  );

  const frontCard = h("div", { class: "pss-preview-card" },
    h("div", { class: "pss-preview-title" }, "Front Battler"),
    h("div", { class: "pss-canvas-wrapper" }, frontCanvas)
  );
  const backCard = h("div", { class: "pss-preview-card" },
    h("div", { class: "pss-preview-title" }, "Back Battler"),
    h("div", { class: "pss-canvas-wrapper" }, backCanvas)
  );
  const iconCard = h("div", { class: "pss-preview-card" },
    h("div", { class: "pss-preview-title" }, "Icono Animado"),
    h("div", { class: "pss-canvas-wrapper canvas-icon" }, iconCanvas)
  );

  const canvasGrid = h("div", { class: "pss-canvas-grid" }, frontCard, backCard, iconCard);
  const centerArea = h("div", { class: "pss-center" }, centerToolbar, canvasGrid);
  body.appendChild(centerArea);

  // 3. Right Panel (Tools)
  const toolsPanel = h("div", { class: "pss-tools-panel" });
  body.appendChild(toolsPanel);

  // -------------------------------------------------------------
  // Helpers de Canvases y Transformaciones
  // -------------------------------------------------------------

  function updateCanvasZoom() {
    frontCanvas.style.transform = `scale(${zoom})`;
    frontCanvas.style.transformOrigin = "center center";
    backCanvas.style.transform = `scale(${zoom})`;
    backCanvas.style.transformOrigin = "center center";
    iconCanvas.style.transform = `scale(${zoom})`;
    iconCanvas.style.transformOrigin = "center center";
  }

  // Renderiza un frame o el spritesheet completo del icono según los ajustes activos
  function renderIconToCanvas(srcCanvas, destCanvas) {
    if (!srcCanvas || !destCanvas) return;
    if (currentMode === "palette") {
      const mergedMap = new Map();
      if (syncIcon) {
        for (const [k, v] of colorMap.entries()) mergedMap.set(k, v);
      }
      // Las modificaciones manuales del icono tienen prioridad
      for (const [k, v] of iconColorMap.entries()) mergedMap.set(k, v);
      applyColorSwap(srcCanvas, destCanvas, mergedMap);
    } else {
      if (syncIcon || paletteTarget === "icon") {
        applyHslAdjustment(srcCanvas, destCanvas, hslSettings);
      } else {
        const dctx = destCanvas.getContext("2d");
        dctx.clearRect(0, 0, destCanvas.width, destCanvas.height);
        dctx.drawImage(srcCanvas, 0, 0);
      }
    }
  }

  function updateCurrentIconFrame() {
    if (!baseIcon || iconCanvas.width === 0) return;
    const frameWidth = Math.round(baseIcon.width / 2) || 64;
    const frameHeight = baseIcon.height || 64;

    const frameCanvas = document.createElement("canvas");
    frameCanvas.width = frameWidth;
    frameCanvas.height = frameHeight;
    const fctx = frameCanvas.getContext("2d");
    fctx.drawImage(baseIcon, iconAnimFrame * frameWidth, 0, frameWidth, frameHeight, 0, 0, frameWidth, frameHeight);

    renderIconToCanvas(frameCanvas, iconCanvas);
  }

  // Dibuja en los canvases de preview aplicando los filtros actuales
  function refreshPreviews() {
    if (!baseFront) return;

    if (currentMode === "palette") {
      applyColorSwap(baseFront, frontCanvas, colorMap);
      if (baseBack && syncBack) applyColorSwap(baseBack, backCanvas, colorMap);
      else if (baseBack) applyColorSwap(baseBack, backCanvas, new Map());
    } else {
      applyHslAdjustment(baseFront, frontCanvas, hslSettings);
      if (baseBack && syncBack) applyHslAdjustment(baseBack, backCanvas, hslSettings);
      else if (baseBack) applyHslAdjustment(baseBack, backCanvas, {});
    }

    updateCurrentIconFrame();
  }

  // Carga un PNG a un canvas
  async function loadPathToCanvas(path) {
    try {
      if (!(await fs.exists(path))) return null;
      const url = await fs.assetUrl(path);
      const img = await loadImageElement(url);
      const cvs = document.createElement("canvas");
      cvs.width = img.naturalWidth || img.width;
      cvs.height = img.naturalHeight || img.height;
      const c = cvs.getContext("2d");
      c.drawImage(img, 0, 0);
      return cvs;
    } catch (_) {
      return null;
    }
  }

  // Carga los sprites para la especie, género y variante seleccionada
  async function loadSpeciesSprites() {
    if (!currentSpecies) return;

    colorMap.clear();
    iconColorMap.clear();
    hslSettings = { hueShift: 0, satMult: 1, lightShift: 0 };

    const spId = currentSpecies.id;
    const form = currentSpecies.form;

    // Helper para resolver sprite con fallbacks automáticos:
    // 1. Variante actual para este género
    // 2. Shiny para este género
    // 3. Normal para este género
    // 4. Si es hembra (1) y la especie no tiene sprites hembra dedicados:
    //    Caer a variante macho (0), luego shiny macho (0), luego normal macho (0)
    async function resolveSprite(type) {
      // 1. Variante actual para este género
      let cvs = await loadPathToCanvas(canonicalSpritePath({ type, variant: currentVariant, speciesId: spId, form, gender: currentGender }));
      if (cvs) return cvs;

      // 2. Shiny para este género
      if (currentVariant !== "normal" && currentVariant !== "shiny") {
        cvs = await loadPathToCanvas(canonicalSpritePath({ type, variant: "shiny", speciesId: spId, form, gender: currentGender }));
        if (cvs) return cvs;
      }

      // 3. Normal para este género
      cvs = await loadPathToCanvas(canonicalSpritePath({ type, variant: "normal", speciesId: spId, form, gender: currentGender }));
      if (cvs) return cvs;

      // 4. Fallback si es hembra y no tiene sprite hembra
      if (currentGender === 1) {
        cvs = await loadPathToCanvas(canonicalSpritePath({ type, variant: currentVariant, speciesId: spId, form, gender: 0 }));
        if (cvs) return cvs;

        if (currentVariant !== "normal" && currentVariant !== "shiny") {
          cvs = await loadPathToCanvas(canonicalSpritePath({ type, variant: "shiny", speciesId: spId, form, gender: 0 }));
          if (cvs) return cvs;
        }

        cvs = await loadPathToCanvas(canonicalSpritePath({ type, variant: "normal", speciesId: spId, form, gender: 0 }));
        if (cvs) return cvs;
      }

      return null;
    }

    baseFront = await resolveSprite("Front");
    baseBack = await resolveSprite("Back");
    baseIcon = await resolveSprite("Icons");

    // Inicializar tamaños
    if (baseFront) {
      frontCanvas.width = baseFront.width;
      frontCanvas.height = baseFront.height;
    }
    if (baseBack) {
      backCanvas.width = baseBack.width;
      backCanvas.height = baseBack.height;
    }
    if (baseIcon) {
      // Un icon normal mide (width = frameWidth * 2, height = frameHeight)
      // Para la animación se muestra un solo frame
      iconCanvas.width = Math.round(baseIcon.width / 2) || 64;
      iconCanvas.height = baseIcon.height || 64;
    }

    startIconAnimation();
    updateCanvasZoom();
    refreshPreviews();
    renderToolsPanel();
  }

  // Hereda la paleta configurada en el otro género (0 = ♂ Estándar, 1 = ♀ Hembra)
  async function inheritPaletteFromGender(sourceGender) {
    if (!currentSpecies) return;
    let applied = false;
    const spId = currentSpecies.id;
    const form = currentSpecies.form;
    const sourceState = sourceGender === 0 ? maleState : femaleState;
    const gLabel = sourceGender === 0 ? "♂ Estándar" : "♀ Hembra";

    // 1. Revisar estado en memoria de la sesión actual (si se editó el género de origen)
    if (sourceState.speciesId === spId && sourceState.form === form) {
      if (sourceState.colorMap.size > 0) {
        for (const [k, v] of sourceState.colorMap.entries()) colorMap.set(k, v);
        applied = true;
      }
      if (sourceState.iconColorMap.size > 0) {
        for (const [k, v] of sourceState.iconColorMap.entries()) iconColorMap.set(k, v);
        applied = true;
      }
      if (sourceState.mode === "hsl" || (sourceState.hslSettings.hueShift !== 0 || sourceState.hslSettings.satMult !== 1 || sourceState.hslSettings.lightShift !== 0)) {
        hslSettings = { ...sourceState.hslSettings };
        currentMode = sourceState.mode;
        applied = true;
      }
    }

    // 2. Extraer cambios de paleta desde los archivos guardados en disco del género de origen
    const srcVarFrontPath = canonicalSpritePath({ type: "Front", variant: currentVariant, speciesId: spId, form, gender: sourceGender });
    const srcNormFrontPath = canonicalSpritePath({ type: "Front", variant: "normal", speciesId: spId, form, gender: sourceGender });

    if (await fs.exists(srcVarFrontPath) && await fs.exists(srcNormFrontPath)) {
      const srcVarCvs = await loadPathToCanvas(srcVarFrontPath);
      const srcNormCvs = await loadPathToCanvas(srcNormFrontPath);
      if (srcVarCvs && srcNormCvs) {
        const extracted = extractColorMapBetween(srcNormCvs, srcVarCvs);
        if (extracted.size > 0) {
          for (const [k, v] of extracted.entries()) {
            if (!colorMap.has(k)) colorMap.set(k, v);
          }
          applied = true;
        }
      }
    }

    // 3. Extraer cambios de paleta del icono del género de origen guardado en disco
    const srcVarIconPath = canonicalSpritePath({ type: "Icons", variant: currentVariant, speciesId: spId, form, gender: sourceGender });
    const srcNormIconPath = canonicalSpritePath({ type: "Icons", variant: "normal", speciesId: spId, form, gender: sourceGender });

    if (await fs.exists(srcVarIconPath) && await fs.exists(srcNormIconPath)) {
      const srcVarIconCvs = await loadPathToCanvas(srcVarIconPath);
      const srcNormIconCvs = await loadPathToCanvas(srcNormIconPath);
      if (srcVarIconCvs && srcNormIconCvs) {
        const extractedIcon = extractColorMapBetween(srcNormIconCvs, srcVarIconCvs);
        if (extractedIcon.size > 0) {
          for (const [k, v] of extractedIcon.entries()) {
            if (!iconColorMap.has(k)) iconColorMap.set(k, v);
          }
          applied = true;
        }
      }
    }

    if (applied) {
      refreshPreviews();
      renderToolsPanel();
      const msg = `Paleta de ${gLabel} heredada con éxito para ${currentSpecies.name}.`;
      if (ctx.ui?.showToast) ctx.ui.showToast(msg);
      else alert(msg);
    } else {
      alert(`No se encontró paleta modificada en memoria ni guardada en disco para la versión ${gLabel} de esta variante.`);
    }
  }

  const inheritMalePalette = () => inheritPaletteFromGender(0);
  const inheritFemalePalette = () => inheritPaletteFromGender(1);

  // Copia el icono desde una variante (y opcionalmente género específico)
  async function copyIconFrom({ variant, gender = currentGender }) {
    if (!currentSpecies) return;
    const spId = currentSpecies.id;
    const form = currentSpecies.form;

    let path = canonicalSpritePath({ type: "Icons", variant, speciesId: spId, form, gender });
    let cvs = await loadPathToCanvas(path);

    if (!cvs && gender === 1 && currentGender === 1) {
      path = canonicalSpritePath({ type: "Icons", variant, speciesId: spId, form, gender: 0 });
      cvs = await loadPathToCanvas(path);
    }

    if (cvs) {
      baseIcon = cvs;
      iconColorMap.clear();
      refreshPreviews();
      renderToolsPanel();
      const vObj = variants.find(v => v.id === variant);
      const vName = variant === "normal" ? "Normal" : variant === "shiny" ? "Shiny" : variant === "supershiny" ? "Super Shiny" : (vObj?.name || variant);
      const gLabel = gender !== currentGender ? (gender === 1 ? " (♀)" : " (♂)") : "";
      const msg = `Icono copiado de ${vName}${gLabel}.`;
      if (ctx.ui?.showToast) ctx.ui.showToast(msg);
      else alert(msg);
    } else {
      const gLabel = gender === 1 ? " en su versión hembra (♀)" : "";
      alert(`No se encontró el icono de "${variant}"${gLabel} para esta especie.`);
    }
  }

  // Copia los battlers (Front y Back) desde una variante (y opcionalmente género específico)
  async function copyBattlersFrom({ variant, gender = currentGender }) {
    if (!currentSpecies) return;
    const spId = currentSpecies.id;
    const form = currentSpecies.form;

    let fPath = canonicalSpritePath({ type: "Front", variant, speciesId: spId, form, gender });
    let fCvs = await loadPathToCanvas(fPath);
    if (!fCvs && gender === 1 && currentGender === 1) {
      fPath = canonicalSpritePath({ type: "Front", variant, speciesId: spId, form, gender: 0 });
      fCvs = await loadPathToCanvas(fPath);
    }

    let bPath = canonicalSpritePath({ type: "Back", variant, speciesId: spId, form, gender });
    let bCvs = await loadPathToCanvas(bPath);
    if (!bCvs && gender === 1 && currentGender === 1) {
      bPath = canonicalSpritePath({ type: "Back", variant, speciesId: spId, form, gender: 0 });
      bCvs = await loadPathToCanvas(bPath);
    }

    if (fCvs) {
      baseFront = fCvs;
      if (bCvs) baseBack = bCvs;
      colorMap.clear();
      hslSettings = { hueShift: 0, satMult: 1, lightShift: 0 };
      refreshPreviews();
      renderToolsPanel();
      const vObj = variants.find(v => v.id === variant);
      const vName = variant === "normal" ? "Normal" : variant === "shiny" ? "Shiny" : variant === "supershiny" ? "Super Shiny" : (vObj?.name || variant);
      const gLabel = gender !== currentGender ? (gender === 1 ? " (♀)" : " (♂)") : "";
      const msg = `Battlers copiados de ${vName}${gLabel}.`;
      if (ctx.ui?.showToast) ctx.ui.showToast(msg);
      else alert(msg);
    } else {
      const gLabel = gender === 1 ? " en su versión hembra (♀)" : "";
      alert(`No se encontraron battlers de "${variant}"${gLabel} para esta especie.`);
    }
  }

  function startIconAnimation() {
    if (iconAnimInterval) clearInterval(iconAnimInterval);
    iconAnimInterval = setInterval(() => {
      iconAnimFrame = (iconAnimFrame + 1) % 2;
      updateCurrentIconFrame();
    }, 250);
  }

  // -------------------------------------------------------------
  // Renderizado de la lista de especies
  // -------------------------------------------------------------
  function renderSpeciesList() {
    speciesListEl.innerHTML = "";
    const filter = (searchInput.value || "").trim().toLowerCase();

    const filtered = catalog.filter((sp) => {
      if (!filter) return true;
      return sp.id.toLowerCase().includes(filter) || sp.name.toLowerCase().includes(filter);
    });

    for (const sp of filtered) {
      const isSelected = currentSpecies && currentSpecies.id === sp.id && currentSpecies.form === sp.form;
      const item = h("div", {
        class: `pss-species-item ${isSelected ? "selected" : ""}`,
        onclick: () => {
          recordMaleState();
          currentSpecies = sp;
          renderSpeciesList();
          loadSpeciesSprites();
        }
      });

      const iconPath = canonicalSpritePath({ type: "Icons", variant: "normal", speciesId: sp.id, form: sp.form, gender: 0 });
      const img = h("img", { class: "pss-species-icon" });
      fs.assetUrl(iconPath).then((url) => { img.src = url; }).catch(() => {});

      const info = h("div", { class: "pss-species-info" },
        h("div", { class: "pss-species-name" }, sp.name + (sp.formName ? ` (${sp.formName})` : sp.form > 0 ? ` [${sp.form}]` : "")),
        h("div", { class: "pss-species-id" }, sp.id)
      );

      item.appendChild(img);
      item.appendChild(info);
      speciesListEl.appendChild(item);
    }
  }

  // -------------------------------------------------------------
  // Renderizado de pestañas de variantes
  // -------------------------------------------------------------
  function renderTabs() {
    tabsContainer.innerHTML = "";

    // Pestaña Normal
    const tabNormal = h("button", {
      class: `pss-tab ${currentVariant === "normal" ? "active" : ""}`,
      onclick: () => switchVariant("normal")
    }, "Normal");
    tabsContainer.appendChild(tabNormal);

    // Pestaña Shiny
    const tabShiny = h("button", {
      class: `pss-tab tab-shiny ${currentVariant === "shiny" ? "active" : ""}`,
      onclick: () => switchVariant("shiny")
    }, "★ Shiny");
    tabsContainer.appendChild(tabShiny);

    // Pestaña Super Shiny
    const tabSuperShiny = h("button", {
      class: `pss-tab tab-supershiny ${currentVariant === "supershiny" ? "active" : ""}`,
      onclick: () => switchVariant("supershiny")
    }, "✦ Super Shiny");
    tabsContainer.appendChild(tabSuperShiny);

    // Variantes custom registradas
    for (const v of variants) {
      if (v.id === "shiny" || v.id === "supershiny") continue;
      const tabCustom = h("button", {
        class: `pss-tab tab-custom ${currentVariant === v.id ? "active" : ""}`,
        style: currentVariant === v.id ? `background:${v.color || "#06b6d4"};` : "",
        onclick: () => switchVariant(v.id)
      }, `❖ ${v.name}`);
      tabsContainer.appendChild(tabCustom);
    }

    // Botón para crear nueva variante
    const btnAdd = h("button", {
      class: "pss-btn-add-variant",
      title: "Crear nueva variante de Shiny",
      onclick: () => showNewVariantModal()
    }, "+ Nueva Variante");
    tabsContainer.appendChild(btnAdd);
  }

  function switchVariant(variantId) {
    recordMaleState();
    currentVariant = variantId;
    renderTabs();
    loadSpeciesSprites();
  }

  // -------------------------------------------------------------
  // Modal para Crear Nueva Variante
  // -------------------------------------------------------------
  function showNewVariantModal() {
    const idInput = h("input", { class: "pss-input", placeholder: "Ej: cosmic, albino, radiant..." });
    const nameInput = h("input", { class: "pss-input", placeholder: "Ej: Variante Cósmica" });
    const colorInput = h("input", { type: "color", value: "#06b6d4", style: "width:100%; height:32px; cursor:pointer;" });

    const modal = h("div", { class: "pss-modal" },
      h("div", { class: "pss-modal-title" }, "Crear Nueva Variante de Shiny"),
      h("div", { class: "pss-modal-field" },
        h("label", {}, "ID de la variante (solo letras y números, minúsculas):"),
        idInput
      ),
      h("div", { class: "pss-modal-field" },
        h("label", {}, "Nombre para mostrar:"),
        nameInput
      ),
      h("div", { class: "pss-modal-field" },
        h("label", {}, "Color distintivo de la variante:"),
        colorInput
      ),
      h("div", { class: "pss-modal-footer" },
        h("button", {
          class: "pss-btn-secondary",
          onclick: () => backdrop.remove()
        }, "Cancelar"),
        h("button", {
          class: "pss-btn-primary",
          onclick: async () => {
            const id = idInput.value.trim().toLowerCase().replace(/[^a-z0-9_]/g, "");
            const name = nameInput.value.trim() || id;
            if (!id) {
              alert("Por favor ingresa un ID válido para la variante.");
              return;
            }
            if (variants.some(v => v.id === id) || id === "normal") {
              alert("Ya existe una variante con ese ID.");
              return;
            }

            const newVar = {
              id,
              name,
              folder: id,
              color: colorInput.value,
              rate: 655360
            };
            variants.push(newVar);
            await saveVariantsConfig(fs, variants);
            backdrop.remove();
            switchVariant(id);
            if (ctx.ui?.showToast) ctx.ui.showToast(`Variante "${name}" creada con éxito.`);
          }
        }, "Crear Variante")
      )
    );

    const backdrop = h("div", { class: "pss-modal-backdrop" }, modal);
    document.body.appendChild(backdrop);
    idInput.focus();
  }

  // -------------------------------------------------------------
  // Panel de Herramientas y Edición
  // -------------------------------------------------------------
  function renderToolsPanel() {
    toolsPanel.innerHTML = "";

    // Selector de modo (Paleta vs HSL)
    const modeSelector = h("div", { class: "pss-mode-selector" },
      h("button", {
        class: `pss-mode-btn ${currentMode === "palette" ? "active" : ""}`,
        onclick: () => { currentMode = "palette"; renderToolsPanel(); refreshPreviews(); }
      }, "Paleta de Colores"),
      h("button", {
        class: `pss-mode-btn ${currentMode === "hsl" ? "active" : ""}`,
        onclick: () => { currentMode = "hsl"; renderToolsPanel(); refreshPreviews(); }
      }, "Ajuste HSL (Hue)")
    );

    // Selector de objetivo de edición: Battler vs Icono
    const targetSelector = h("div", { class: "pss-mode-selector", style: "margin-top:8px;" },
      h("button", {
        class: `pss-mode-btn ${paletteTarget === "battler" ? "active" : ""}`,
        onclick: () => { paletteTarget = "battler"; renderToolsPanel(); }
      }, "⚔️ Paleta Battlers"),
      h("button", {
        class: `pss-mode-btn ${paletteTarget === "icon" ? "active" : ""}`,
        onclick: () => { paletteTarget = "icon"; renderToolsPanel(); }
      }, "👾 Paleta Icono")
    );

    // Opciones de sincronización
    const syncOptions = h("div", { style: "display:flex; flex-direction:column; gap:6px; margin-top:10px;" },
      h("label", { style: "display:flex; align-items:center; gap:8px; font-size:11px; cursor:pointer;" },
        h("input", {
          type: "checkbox",
          checked: syncIcon,
          onchange: (e) => { syncIcon = e.target.checked; refreshPreviews(); }
        }),
        "Vincular paleta Battler al Icono"
      ),
      h("label", { style: "display:flex; align-items:center; gap:8px; font-size:11px; cursor:pointer;" },
        h("input", {
          type: "checkbox",
          checked: syncBack,
          onchange: (e) => { syncBack = e.target.checked; refreshPreviews(); }
        }),
        "Sincronizar con Sprite Trasero (Back)"
      )
    );

    const sectionHeader = h("div", { class: "pss-panel-section" },
      h("div", { class: "pss-section-title" }, "Modo de Transformación"),
      modeSelector,
      targetSelector,
      syncOptions
    );
    toolsPanel.appendChild(sectionHeader);

    // Contenido según modo
    if (currentMode === "palette") {
      const isIcon = (paletteTarget === "icon");
      const targetCanvas = isIcon ? baseIcon : baseFront;
      const targetMap = isIcon ? iconColorMap : colorMap;
      const targetTitle = isIcon ? "Paleta de Icono (Frames 1 & 2)" : "Paleta Battlers (Front/Back)";

      const paletteGrid = h("div", { class: "pss-palette-grid" });
      const palette = extractPalette(targetCanvas);

      for (const item of palette) {
        const activeHex = targetMap.get(item.hex) || item.hex;
        const hexLabel = h("div", { class: "pss-color-hex" }, activeHex.toUpperCase());

        const colorBox = h("div", {
          class: "pss-color-box",
          style: `background: ${activeHex};`
        });

        const colorInput = h("input", {
          type: "color",
          class: "pss-color-input",
          value: activeHex,
          oninput: (e) => {
            const newColor = e.target.value;
            targetMap.set(item.hex, newColor);
            colorBox.style.background = newColor;
            hexLabel.textContent = newColor.toUpperCase();
            recordMaleState();
            refreshPreviews();
          }
        });

        colorBox.appendChild(colorInput);

        const swatch = h("div", { class: "pss-palette-item" },
          colorBox,
          hexLabel
        );
        paletteGrid.appendChild(swatch);
      }

      const paletteSection = h("div", { class: "pss-panel-section" },
        h("div", { class: "pss-section-title" },
          targetTitle,
          h("button", {
            class: "pss-btn-sm",
            onclick: () => {
              targetMap.clear();
              refreshPreviews();
              renderToolsPanel();
            }
          }, isIcon ? "Resetear Icono" : "Resetear Battlers")
        ),
        paletteGrid
      );
      toolsPanel.appendChild(paletteSection);

      if (isIcon) {
        const iconBtnList = h("div", { style: "display:flex; flex-direction:column; gap:8px;" },
          h("button", {
            class: "pss-btn-secondary",
            onclick: () => copyIconFrom({ variant: "normal" })
          }, "Copiar Icono de Normal"),
          h("button", {
            class: "pss-btn-secondary",
            onclick: () => copyIconFrom({ variant: "shiny" })
          }, "Copiar Icono de Shiny"),
          h("button", {
            class: "pss-btn-secondary",
            onclick: () => copyIconFrom({ variant: "supershiny" })
          }, "Copiar Icono de Super Shiny")
        );

        for (const v of variants) {
          if (v.id === "shiny" || v.id === "supershiny") continue;
          iconBtnList.appendChild(
            h("button", {
              class: "pss-btn-secondary",
              onclick: () => copyIconFrom({ variant: v.id })
            }, `Copiar Icono de ${v.name}`)
          );
        }

        if (currentGender === 1) {
          iconBtnList.appendChild(
            h("button", {
              class: "pss-btn-secondary",
              onclick: () => copyIconFrom({ variant: currentVariant, gender: 0 })
            }, "Copiar Icono de ♂ Estándar")
          );
        } else {
          iconBtnList.appendChild(
            h("button", {
              class: "pss-btn-secondary",
              onclick: () => copyIconFrom({ variant: currentVariant, gender: 1 })
            }, "Copiar Icono de ♀ Hembra")
          );
        }

        const iconActionsSection = h("div", { class: "pss-panel-section" },
          h("div", { class: "pss-section-title" }, "Opciones de Icono"),
          iconBtnList
        );
        toolsPanel.appendChild(iconActionsSection);
      }

    } else {
      // Sliders HSL
      const hueValueLabel = h("span", {}, `${hslSettings.hueShift}°`);
      const hueSlider = h("input", {
        type: "range",
        class: "pss-slider",
        min: "0",
        max: "360",
        value: String(hslSettings.hueShift),
        oninput: (e) => {
          hslSettings.hueShift = Number(e.target.value);
          hueValueLabel.textContent = `${hslSettings.hueShift}°`;
          recordMaleState();
          refreshPreviews();
        }
      });

      const satValueLabel = h("span", {}, `${Math.round(hslSettings.satMult * 100)}%`);
      const satSlider = h("input", {
        type: "range",
        class: "pss-slider",
        min: "0",
        max: "200",
        value: String(Math.round(hslSettings.satMult * 100)),
        oninput: (e) => {
          hslSettings.satMult = Number(e.target.value) / 100;
          satValueLabel.textContent = `${e.target.value}%`;
          recordMaleState();
          refreshPreviews();
        }
      });

      const lightValueLabel = h("span", {}, `${hslSettings.lightShift > 0 ? "+" : ""}${hslSettings.lightShift}%`);
      const lightSlider = h("input", {
        type: "range",
        class: "pss-slider",
        min: "-50",
        max: "50",
        value: String(hslSettings.lightShift),
        oninput: (e) => {
          hslSettings.lightShift = Number(e.target.value);
          lightValueLabel.textContent = `${hslSettings.lightShift > 0 ? "+" : ""}${hslSettings.lightShift}%`;
          recordMaleState();
          refreshPreviews();
        }
      });

      const hslSection = h("div", { class: "pss-panel-section" },
        h("div", { class: "pss-section-title" },
          "Ajustes de Tono y Color",
          h("button", {
            class: "pss-btn-sm",
            onclick: () => {
              hslSettings = { hueShift: 0, satMult: 1, lightShift: 0 };
              refreshPreviews();
              renderToolsPanel();
            }
          }, "Resetear HSL")
        ),
        h("div", { class: "pss-slider-group" },
          h("div", { class: "pss-slider-label" }, h("span", {}, "Tono (Hue):"), hueValueLabel),
          hueSlider
        ),
        h("div", { class: "pss-slider-group" },
          h("div", { class: "pss-slider-label" }, h("span", {}, "Saturación:"), satValueLabel),
          satSlider
        ),
        h("div", { class: "pss-slider-group" },
          h("div", { class: "pss-slider-label" }, h("span", {}, "Brillo (Luminosidad):"), lightValueLabel),
          lightSlider
        )
      );
      toolsPanel.appendChild(hslSection);
    }

    // Acciones de utilidad
    const battlerBtnList = h("div", { style: "display:flex; flex-direction:column; gap:8px;" },
      h("button", {
        class: "pss-btn-secondary",
        onclick: () => copyBattlersFrom({ variant: "normal" })
      }, "Copiar Battlers de Normal"),
      h("button", {
        class: "pss-btn-secondary",
        onclick: () => copyBattlersFrom({ variant: "shiny" })
      }, "Copiar Battlers de Shiny"),
      h("button", {
        class: "pss-btn-secondary",
        onclick: () => copyBattlersFrom({ variant: "supershiny" })
      }, "Copiar Battlers de Super Shiny")
    );

    for (const v of variants) {
      if (v.id === "shiny" || v.id === "supershiny") continue;
      battlerBtnList.appendChild(
        h("button", {
          class: "pss-btn-secondary",
          onclick: () => copyBattlersFrom({ variant: v.id })
        }, `Copiar Battlers de ${v.name}`)
      );
    }

    if (currentGender === 1) {
      battlerBtnList.appendChild(
        h("button", {
          class: "pss-btn-secondary",
          onclick: () => inheritMalePalette()
        }, "Heredar paleta de ♂ Estándar")
      );
      battlerBtnList.appendChild(
        h("button", {
          class: "pss-btn-secondary",
          onclick: () => copyBattlersFrom({ variant: currentVariant, gender: 0 })
        }, "Copiar Battlers de ♂ Estándar")
      );
    } else {
      battlerBtnList.appendChild(
        h("button", {
          class: "pss-btn-secondary",
          onclick: () => inheritFemalePalette()
        }, "Heredar paleta de ♀ Hembra")
      );
      battlerBtnList.appendChild(
        h("button", {
          class: "pss-btn-secondary",
          onclick: () => copyBattlersFrom({ variant: currentVariant, gender: 1 })
        }, "Copiar Battlers de ♀ Hembra")
      );
    }

    const quickActionsSection = h("div", { class: "pss-panel-section" },
      h("div", { class: "pss-section-title" }, "Atajos Rápidos Battler"),
      battlerBtnList
    );
    toolsPanel.appendChild(quickActionsSection);
  }

  // -------------------------------------------------------------
  // Guardado de la variante a archivos del proyecto
  // -------------------------------------------------------------
  async function saveCurrentVariant() {
    if (!currentSpecies || !baseFront) {
      alert("Por favor selecciona un Pokémon primero.");
      return;
    }

    recordMaleState();

    const spId = currentSpecies.id;
    const form = currentSpecies.form;
    const variant = currentVariant;

    // Rutas de destino
    const frontDest = canonicalSpritePath({ type: "Front", variant, speciesId: spId, form, gender: currentGender });
    const backDest = canonicalSpritePath({ type: "Back", variant, speciesId: spId, form, gender: currentGender });
    const iconDest = canonicalSpritePath({ type: "Icons", variant, speciesId: spId, form, gender: currentGender });

    try {
      // 1. Guardar Front Battler
      const frontBlob = await canvasToBlob(frontCanvas);
      if (frontBlob) {
        const bytes = new Uint8Array(await frontBlob.arrayBuffer());
        await fs.writeBytes(frontDest, bytes);
      }

      // 2. Guardar Back Battler
      if (baseBack) {
        const backBlob = await canvasToBlob(backCanvas);
        if (backBlob) {
          const bytes = new Uint8Array(await backBlob.arrayBuffer());
          await fs.writeBytes(backDest, bytes);
        }
      }

      // 3. Guardar Icono (los dos frames completos transformados)
      if (baseIcon) {
        const fullIconCanvas = document.createElement("canvas");
        fullIconCanvas.width = baseIcon.width;
        fullIconCanvas.height = baseIcon.height;

        renderIconToCanvas(baseIcon, fullIconCanvas);

        const iconBlob = await canvasToBlob(fullIconCanvas);
        if (iconBlob) {
          const bytes = new Uint8Array(await iconBlob.arrayBuffer());
          await fs.writeBytes(iconDest, bytes);
        }
      }

      const msg = `¡Variante "${variant}" guardada para ${currentSpecies.name}!`;
      if (ctx.ui?.showToast) ctx.ui.showToast(msg);
      else alert(msg);

      // Recargar para refrescar cachés
      await loadSpeciesSprites();
    } catch (err) {
      console.error("Error al guardar variante:", err);
      const detail = err?.message || (typeof err === "string" ? err : JSON.stringify(err)) || "Error desconocido";
      alert(`Error al guardar: ${detail}`);
    }
  }

  // -------------------------------------------------------------
  // Inicialización de la barra de acciones
  // -------------------------------------------------------------
  const btnSave = h("button", {
    class: "pss-btn-primary",
    onclick: () => saveCurrentVariant()
  },
    h("span", {}, "💾"),
    "Guardar Variante"
  );
  actionsContainer.appendChild(btnSave);

  // Inicializar UI completa
  renderTabs();
  renderSpeciesList();

  if (catalog.length > 0) {
    currentSpecies = catalog[0];
    renderSpeciesList();
    loadSpeciesSprites();
  }
}
