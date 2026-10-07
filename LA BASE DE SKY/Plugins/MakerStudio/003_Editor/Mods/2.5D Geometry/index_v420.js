/**
 * 2.5D Geometry v4.0.0 — Clean 3D Studio
 * Maker Studio Mod API 1.0.0
 *
 * Hybrid goals:
 * - keep the map tile-first and author slopes/height as sparse parametric terrain
 * - compile coplanar terrain into the minimum practical number of runtime quads
 * - reserve true low-poly modeling for special props/buildings
 * - import linked Blockbench cuboid models and reload pixel textures from Graphics/Models
 * - compile editor authoring data away from the gameplay load path
 *
 * Legacy/V2 goals retained:
 * - exact cross-tileset source resolution via readTileData().tilesetId
 * - map-first beginner workflow inspired by Luka's visual editor philosophy
 * - visual Used Graphics browser + native graphic picker
 * - large 2.5D and SPLIT viewports
 * - direct elevation cues and source-driven Geometry compilation
 * - one runtime material identity for editor preview and MKXP-Z
 * - reusable models compiled into connected top/perimeter region meshes
 * - collision proxies separated from render meshes
 * - keep-last-mesh behaviour while edits are rebuilt on the next animation frame
 */

import { parseMapRxdata, parseTilesetsRxdata } from "./rxdata_reader.js";

const MOD_ID = "com.carnek.geometry-2p5d";
const TOOL_ID = "geometry-2p5d.height";
const PANEL_ID = "geometry-2p5d.panel";
const PREVIEW_PANEL_ID = "geometry-2p5d.preview";
const FORMAT = 5;
const SCENE_COMPILER_VERSION = 1;
const COMPILED_OBJECT_ID_BASE = 100000;
const DEFAULT_STEP = 32;
const TILE_SIZE = 32;
const RUNTIME_SETTINGS_PATH = "Plugins/[VERMEIL] Visual 2.5D/001_Settings.rb";

// RPG Maker XP 48-pattern autotile quarter table. Each value indexes a 16x16
// quarter in the first 96x128 frame of an autotile sheet.
const AUTOTILE_PARTS = [
  [27,28,33,34],[5,28,33,34],[27,6,33,34],[5,6,33,34],
  [27,28,33,12],[5,28,33,12],[27,6,33,12],[5,6,33,12],
  [27,28,11,34],[5,28,11,34],[27,6,11,34],[5,6,11,34],
  [27,28,11,12],[5,28,11,12],[27,6,11,12],[5,6,11,12],
  [25,26,31,32],[25,6,31,32],[25,26,31,12],[25,6,31,12],
  [15,16,21,22],[15,16,21,12],[15,16,11,22],[15,16,11,12],
  [29,30,35,36],[29,30,11,36],[5,30,35,36],[5,30,11,36],
  [39,40,45,46],[5,40,45,46],[39,6,45,46],[5,6,45,46],
  [25,30,31,36],[15,16,31,32],[15,16,35,36],[25,30,11,36],
  [37,38,43,44],[37,6,43,44],[13,14,19,20],[13,14,19,12],
  [25,26,43,44],[37,38,31,32],[13,14,43,44],[37,6,31,32],
  [13,14,19,44],[13,14,43,20],[13,38,43,44],[37,14,43,44],
];

const TAG = {
  FLOOR: 19,
  WALL: 20,
  ROOF: 21,
  BILLBOARD: 22,
  VOLUME: 23,
  STRUCTURE: 24,
  INDOOR_WALL: 25,
  INDOOR_PROP: 26,
  INDOOR_BORDER: 27,
  INDOOR_BLACK: 28,
  MOUNTAIN_TOP: 29,
  MOUNTAIN_WALL: 30,
  ROOF_HIGH: 31,
  VOLUME_HIGH: 32,
  OVERLAY: 33,
  ROOF_PLANE: 34,
  WALL_PLANE: 35,
  MOUNTAIN_WALL_PLANE: 36,
  STAIR: 37,
};

const BILLBOARD_TAGS = new Set([TAG.BILLBOARD, TAG.STRUCTURE, TAG.INDOOR_PROP, TAG.OVERLAY]);
const WALL_ART_TAGS = new Set([TAG.WALL, TAG.INDOOR_WALL, TAG.MOUNTAIN_WALL, TAG.WALL_PLANE, TAG.MOUNTAIN_WALL_PLANE]);
const TOP_SURFACE_TAGS = new Set([TAG.FLOOR, TAG.VOLUME, TAG.MOUNTAIN_TOP, TAG.VOLUME_HIGH, TAG.STAIR, TAG.ROOF_PLANE, TAG.INDOOR_BORDER, TAG.INDOOR_BLACK]);
const ROOF_BILLBOARD_TAGS = new Set([TAG.ROOF, TAG.ROOF_HIGH]);
const PLANE_WALL_TAGS = new Set([TAG.WALL_PLANE]);
const MOUNTAIN_MATERIAL_TAGS = new Set([TAG.MOUNTAIN_WALL, TAG.MOUNTAIN_WALL_PLANE]);

const TAG_NAMES = new Map([
  [19, "NDSFloor"], [20, "NDSWall"], [21, "NDSRoof"], [22, "NDSBillboard"],
  [23, "NDSVolume"], [24, "NDSStructure"], [25, "NDSIndoorWall"], [26, "NDSIndoorProp"],
  [27, "NDSIndoorBorder"], [28, "NDSIndoorBlack"], [29, "NDSMountainTop"],
  [30, "NDSMountainWall"], [31, "NDSRoofHigh"], [32, "NDSVolumeHigh"], [33, "NDSOverlay"],
  [34, "NDSRoofPlane"], [35, "NDSWallPlane"], [36, "NDSMountainWallPlane"], [37, "NDSStair"],
]);

const runtimeConfig = {
  outdoorDefaultAlpha: 25,
  indoorDefaultAlpha: 24,
  distanceH: 640,
  roofHeight: 48,
  roofHighHeight: 72,
  mountainHeight: 32,
  volumeDefaultHeight: 8,
  volumeHighHeight: 24,
  stairHeight: 32,
  surfaceGeometryHeightStep: 32,
};

function numberConst(text, name, fallback) {
  const re = new RegExp(`${name}\\s*=\\s*([0-9.]+)`);
  const m = String(text || "").match(re);
  return m ? Number(m[1]) || fallback : fallback;
}

function tilesetInfo(ctx, tilesetId) {
  const id = Number(tilesetId) || 0;
  let out = null;
  try { out = ctx.tileset.info?.(id) || null; } catch (_) {}
  const lists = [];
  try { lists.push(ctx.tileset.list?.()); } catch (_) {}
  try { lists.push(ctx.projectData?.tilesets); } catch (_) {}
  try { lists.push(ctx.projectData?.tilesets?.()); } catch (_) {}
  try { lists.push(ctx.projectData?.getTilesets?.()); } catch (_) {}
  try { lists.push(ctx.projectData?.listTilesets?.()); } catch (_) {}
  for (const list of lists) {
    if (!Array.isArray(list)) continue;
    const hit = list.find((t, i) => Number(firstDefined(t?.id, t?.ID, t?.index, i)) === id);
    if (hit) out = { ...(out || {}), ...hit };
  }
  return out;
}

function tilesetGraphicName(info) {
  return String(firstDefined(
    info?.tilesetName,
    info?.tileset_name,
    info?.graphicName,
    info?.graphic_name,
    info?.imageName,
    info?.image_name,
    info?.filename,
    info?.fileName,
    info?.graphic,
    info?.image,
    ""
  )).replace(/\.[^.]+$/, "").trim();
}

async function loadRuntimeConfig(ctx) {
  try {
    const text = await ctx.fs.readProjectFile(RUNTIME_SETTINGS_PATH);
    runtimeConfig.outdoorDefaultAlpha = numberConst(text, "OUTDOOR_DEFAULT_ALPHA", runtimeConfig.outdoorDefaultAlpha);
    runtimeConfig.indoorDefaultAlpha = numberConst(text, "INDOOR_DEFAULT_ALPHA", runtimeConfig.indoorDefaultAlpha);
    runtimeConfig.distanceH = numberConst(text, "DISTANCE_H", runtimeConfig.distanceH);
    runtimeConfig.roofHeight = numberConst(text, "NDS_ROOF_HEIGHT", runtimeConfig.roofHeight);
    runtimeConfig.roofHighHeight = numberConst(text, "NDS_ROOF_HIGH_HEIGHT", runtimeConfig.roofHighHeight);
    runtimeConfig.mountainHeight = numberConst(text, "NDS_MOUNTAIN_HEIGHT", runtimeConfig.mountainHeight);
    runtimeConfig.volumeDefaultHeight = numberConst(text, "NDS_VOLUME_DEFAULT_HEIGHT", runtimeConfig.volumeDefaultHeight);
    runtimeConfig.volumeHighHeight = numberConst(text, "NDS_VOLUME_HIGH_HEIGHT", runtimeConfig.volumeHighHeight);
    runtimeConfig.stairHeight = numberConst(text, "NDS_STAIR_HEIGHT", runtimeConfig.stairHeight);
    runtimeConfig.surfaceGeometryHeightStep = numberConst(text, "SURFACE_GEOMETRY_HEIGHT_STEP", runtimeConfig.surfaceGeometryHeightStep);
  } catch (err) {
    ctx.log.warn("2.5D Geometry: runtime settings not readable; using built-in defaults", err);
  }
}

function tagName(tag) {
  return TAG_NAMES.get(Number(tag) || 0) || (Number(tag) ? `Terrain ${Number(tag)}` : "Normal");
}

function tagHeightOffset(tag) {
  tag = Number(tag) || 0;
  if (tag === TAG.ROOF) return runtimeConfig.roofHeight;
  if (tag === TAG.ROOF_HIGH) return runtimeConfig.roofHighHeight;
  if (tag === TAG.ROOF_PLANE) return runtimeConfig.roofHeight;
  return 0;
}

const OBJECT_COLLISIONS = ["none", "solid", "climb", "one-way"];
const FOOTPRINT_MODES = ["inherit", "solid", "none", "climb", "one-way", "void"];
const OBJECT_CATEGORIES = [
  ["floor", "Floor"], ["wall", "Wall"], ["border", "Border"],
  ["mountain", "Mountain"], ["prop", "Prop"], ["roof", "Roof"], ["custom", "Custom"],
];

// Luka/Kyanite philosophy: each category owns its defaults (geometry + gameplay),
// so picking a category stamps independent properties without touching other
// objects. The runtime reads only per-object values, never these presets.
const OBJECT_CATEGORY_PRESETS = {
  floor:    { type: "plane", height: 0, anchor_z: 0, collision: "none" },
  wall:     { type: "cube",  height: 2, anchor_z: 0, collision: "solid" },
  border:   { type: "cube",  height: 2, anchor_z: 0, collision: "solid" },
  mountain: { type: "cube",  height: 3, anchor_z: 0, collision: "climb" },
  prop:     { type: "cube",  height: 1, anchor_z: 0, collision: "none" },
  roof:     { type: "plane", height: 0, anchor_z: 2, collision: "one-way" },
  custom:   { type: "cube",  height: 1, anchor_z: 0, collision: "solid" },
};

// Scene Compiler presets are source-driven rather than object-driven. A definition
// is analogous to a lightweight prefab: it describes how every placed occurrence
// of one real tile source should become 2.5D geometry. Individual occurrences can
// then override these values through instance_overrides.
const SCENE_GEOMETRY_PRESETS = {
  floor: { category: "floor", type: "plane", height: 0, anchor_z: 0, collision: "none", enabled: true,
           components: { extrude: false, cap: true, connect_neighbors: true, slope: false, billboard: false, occlusion: "auto" } },
  wall: { category: "wall", type: "cube", height: 2, anchor_z: 0, collision: "solid", enabled: true,
          components: { extrude: true, cap: true, connect_neighbors: true, slope: false, billboard: false, occlusion: "auto" } },
  border: { category: "border", type: "cube", height: 1, anchor_z: 0, collision: "solid", enabled: true,
            components: { extrude: true, cap: true, connect_neighbors: true, slope: false, billboard: false, occlusion: "auto" } },
  mountain: { category: "mountain", type: "cube", height: 3, anchor_z: 0, collision: "climb", enabled: true,
              components: { extrude: true, cap: true, connect_neighbors: true, slope: false, billboard: false, occlusion: "auto" } },
  prop: { category: "prop", type: "cube", height: 1, anchor_z: 0, collision: "none", enabled: true,
          components: { extrude: true, cap: true, connect_neighbors: false, slope: false, billboard: false, occlusion: "auto" } },
  roof: { category: "roof", type: "plane", height: 0, anchor_z: 2, collision: "one-way", enabled: true,
          components: { extrude: false, cap: true, connect_neighbors: true, slope: false, billboard: false, occlusion: "auto" } },
  custom: { category: "custom", type: "cube", height: 1, anchor_z: 0, collision: "solid", enabled: true,
            components: { extrude: true, cap: true, connect_neighbors: false, slope: false, billboard: false, occlusion: "auto" } },
  ignore: { category: "custom", type: "plane", height: 0, anchor_z: 0, collision: "none", enabled: false,
            components: { extrude: false, cap: false, connect_neighbors: false, slope: false, billboard: false, occlusion: "auto" } },
};

// Matches the runtime fallback for objects without material
// (026_NDSGeometryObjects.rb -> nds_object_category_color).
const CATEGORY_FALLBACK_COLORS = {
  wall: "rgba(96,78,58,0.92)",
  border: "rgba(108,100,92,0.92)",
  mountain: "rgba(92,63,42,0.92)",
  roof: "rgba(120,105,125,0.92)",
  custom: "rgba(128,96,128,0.92)",
  plane: "rgba(108,96,120,0.92)",
  floor: "rgba(148,128,186,0.92)",
  prop: "rgba(148,128,186,0.92)",
};

function collisionColor(collision) {
  switch (collision) {
    case "solid": return "rgba(255,74,74,0.92)";
    case "climb": return "rgba(255,190,75,0.92)";
    case "one-way": return "rgba(80,220,255,0.92)";
    default: return "rgba(120,220,120,0.85)";
  }
}

function nextObjectId(geo) {
  let max = 0;
  for (const o of geo?.objects || []) if (Number(o.id) > max) max = Number(o.id);
  return max + 1;
}

function escapeHtml(value) {
  return String(value ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function normalizeRotation(value) {
  const n = Math.round((Number(value) || 0) / 90) * 90;
  return ((n % 360) + 360) % 360;
}

function normalizeModelPlacementRotation(value) {
  let n = Number(value) || 0;
  n = ((n % 360) + 360) % 360;
  return Math.round(n * 10) / 10;
}

function normalizeFootprint(raw, w, h) {
  const out = {};
  if (!raw || typeof raw !== "object") return out;
  for (const [key, value] of Object.entries(raw)) {
    const m = /^(\d+),(\d+)$/.exec(String(key));
    if (!m) continue;
    const dx = Number(m[1]), dy = Number(m[2]);
    if (dx < 0 || dy < 0 || dx >= w || dy >= h) continue;
    const mode = typeof value === "string" ? value : value?.collision;
    if (FOOTPRINT_MODES.includes(mode) && mode !== "inherit") out[`${dx},${dy}`] = mode;
  }
  return out;
}

function footprintMode(obj, dx, dy) {
  return obj?.footprint?.[`${dx},${dy}`] || "inherit";
}

function objectCoversCell(obj, x, y) {
  const dx = x - Number(obj.x || 0), dy = y - Number(obj.y || 0);
  if (dx < 0 || dy < 0 || dx >= Number(obj.w || 1) || dy >= Number(obj.h || 1)) return false;
  return footprintMode(obj, dx, dy) !== "void";
}

function rotateFootprint90(obj) {
  const oldW = Math.max(1, Number(obj.w) || 1);
  const oldH = Math.max(1, Number(obj.h) || 1);
  const next = {};
  for (let dy = 0; dy < oldH; dy++) {
    for (let dx = 0; dx < oldW; dx++) {
      const mode = footprintMode(obj, dx, dy);
      if (mode === "inherit") continue;
      const nx = oldH - 1 - dy;
      const ny = dx;
      next[`${nx},${ny}`] = mode;
    }
  }
  obj.w = oldH;
  obj.h = oldW;
  obj.footprint = next;
  obj.rotation = normalizeRotation((obj.rotation || 0) + 90);
  obj.anchor_row = Math.min(obj.h - 1, Math.max(0, Number(obj.anchor_row) || 0));
}

function normalizeObject(raw, fallbackId) {
  const w = Math.max(1, Math.round(Number(raw?.w) || 1));
  const h = Math.max(1, Math.round(Number(raw?.h) || 1));
  const obj = {
    id: Number(raw?.id) || fallbackId,
    name: String(raw?.name || `Object ${Number(raw?.id) || fallbackId}`),
    type: raw?.type === "plane" ? "plane" : "cube",
    x: Math.max(0, Math.round(Number(raw?.x) || 0)),
    y: Math.max(0, Math.round(Number(raw?.y) || 0)),
    w,
    h,
    height: Math.max(0, Number(raw?.height) || 0),
    anchor_z: Math.max(0, Number(raw?.anchor_z) || 0),
    anchor_row: Math.min(h - 1, Math.max(0, Math.round(raw?.anchor_row == null ? h - 1 : Number(raw.anchor_row) || 0))),
    rotation: normalizeRotation(raw?.rotation),
    collision: OBJECT_COLLISIONS.includes(raw?.collision) ? raw.collision : "solid",
    category: OBJECT_CATEGORIES.some(([id]) => id === raw?.category) ? raw.category : "prop",
    characters_in_front: raw?.characters_in_front === true,
    footprint: normalizeFootprint(raw?.footprint, w, h),
  };
  if (raw?.material && typeof raw.material === "object") obj.material = raw.material;
  // Preserve canonical Scene Compiler metadata. These fields are deliberately
  // ignored by the manual-object inspector but consumed by preview/runtime.
  if (raw?.compiled === true) obj.compiled = true;
  if (raw?.source_key != null) obj.source_key = String(raw.source_key);
  if (raw?.instance_key != null) obj.instance_key = String(raw.instance_key);
  if (raw?.source && typeof raw.source === "object") obj.source = { ...raw.source };
  if (raw?.components && typeof raw.components === "object") obj.components = { ...raw.components };
  if (raw?.face_materials && typeof raw.face_materials === "object") obj.face_materials = normalizeFaceMaterialMap(raw.face_materials);
  if (raw?.model_id != null) obj.model_id = String(raw.model_id);
  if (raw?.model_instance_id != null) obj.model_instance_id = Number(raw.model_instance_id) || 0;
  if (raw?.render === false) obj.render = false;
  return obj;
}

function normalizeObjects(rawList) {
  const out = [];
  for (const raw of rawList || []) {
    if (!raw || typeof raw !== "object") continue;
    out.push(normalizeObject(raw, out.length ? nextObjectId({ objects: out }) : 1));
  }
  return out;
}

function objectRect(obj) {
  return { x0: obj.x, y0: obj.y, x1: obj.x + obj.w - 1, y1: obj.y + obj.h - 1 };
}

function objectsOverlappingCell(geo, x, y) {
  const found = [];
  for (const obj of geo?.objects || []) {
    if (objectCoversCell(obj, x, y)) found.push(obj);
  }
  return found;
}

function sceneObjects(geo) {
  // Manual Luka-style objects and source-compiled instances share one canonical
  // renderer path. Hierarchy editing still targets only geo.objects.
  return [...(geo?.objects || []), ...(geo?.compiled_objects || []), ...(geo?.model_objects || [])];
}

// Topmost object covering a cell (last in array wins), for click-to-select.
function findObjectAt(geo, x, y) {
  const found = objectsOverlappingCell(geo, x, y);
  return found.length ? found[found.length - 1] : null;
}

function objFieldTarget(geo) {
  if (state.objSelected == null || !geo) return null;
  return (geo.objects || []).find((o) => Number(o.id) === Number(state.objSelected)) || null;
}

function currentGeo(ctx) {
  const id = ctx?.editor?.activeMapId?.();
  if (id == null) return null;
  return state.maps.get(id) || null;
}

const state = {
  level: 1,
  mode: "set", // set | raise | lower | erase | inherit
  objTool: false,
  objType: "cube", // cube | plane
  objHeight: 2,
  objAnchorZ: 0,
  objCollision: "solid",
  objCategory: "prop",
  objMaterial: null,
  objFootprintMode: "solid",
  objSelected: null, // object id being edited in the panel, or null for brush mode
  workspaceMode: "scene", // backend compatibility; amateur UI stays in scene mode
  sceneTool: "select", // select | paint | raise | lower | eyedropper | erase | terrain-slope | terrain-flat | terrain-clear
  sceneScope: "this", // this | connected | all
  // DS-style parametric terrain tools. Angles are authored as sparse corner
  // heights and compiled into the fewest coplanar quads possible at save time.
  terrainAngle: 25,
  terrainYaw: 0,       // 0=N, 90=E, 180=S, 270=W
  terrainStep: 0.25,
  terrainTargetHeight: 0,
  terrainSelection: null,   // { mapId, x0, y0, x1, y1 } inclusive
  terrainSelectStart: null,
  terrainSelectCurrent: null,
  terrainFlatTarget: null,
  mapHover: null,
  viewMode: "2d", // Maker Studio map is always the primary editor
  // Preview is intentionally snapshot-first. It does no work while closed and
  // does not redraw after every map edit unless Live is explicitly enabled.
  previewLive: false,
  previewDirty: true,
  previewPanelOpen: false,
  legacyDataBlocked: false,
  legacyCheckDone: false,
  studioTool: "select", // select | height | corners | delete | models
  studioDrag: null,
  studioOverlayCanvas: null,
  studioHost: null,
  studioSelectionStart: null,
  studioDraftDirty: false,
  brushPreset: "wall",
  brushHeight: 2,
  sourceSelection: null,
  // V2 visual workflow state. These are intentionally human-facing concepts;
  // source/instance compiler details remain internal.
  visualSource: null,       // graphic explicitly picked from the Tilesets selector
  visualSourcePreviewUrl: null,
  visualSourceFootprint: { w: 1, h: 1 },
  // V2.5 Model Workshop: reusable geometry models made from arbitrary grid cells.
  modelTool: false,
  modelSelectedId: null,
  modelBrushId: null,
  modelScaleX: 1,
  modelScaleY: 1,
  modelHeightScale: 1,
  modelRotation: 0,
  modelEraseMode: false,
  modelPlacementMode: false,
  modelInstanceSelectedId: null,
  modelHoverCell: null,
  panelMode: "edit",       // edit | browser
  uiSection: "terrain",    // terrain | models
  uiAdvanced: false,       // advanced tile/source controls are hidden by default
  largeViewOpen: false,
  largeViewKind: "2.5d",   // 2.5d | split
  topDownCanvas: null,
  sourcePreset: "wall",
  sourceUsage: null,
  sourceUsageByMap: new Map(),
  legacyReadyByMap: new Set(),
  compilerBusy: false,
  compilerTimer: 0,
  simpleEditTimer: 0,
  compilerReason: "",
  panelRaf: 0,
  previewPanelRefresh: null,
  assetRefreshTimer: 0,
  sourceRefreshTimer: 0,
  modelSaveTimer: 0,
  modelCompileRaf: 0,
  modelCompilePending: null,
  objStart: null,
  objCurrent: null,
  showOverlay: true,
  showLabels: true,
  show2DRefs: false,
  dragging: false,
  visited: new Set(),
  terrainStrokeCells: new Set(),
  maps: new Map(),
  legacyHeights: new Map(),
  panelRefresh: null,
  preview: {
    canvas: null,
    status: null,
    angle: runtimeConfig.outdoorDefaultAlpha || 25,
    yaw: 0,
    zoom: 1.0,
    radius: 6,
    focusX: null,
    focusY: null,
    followHover: false,
    showCollision: false,
    showWire: false,
    showPlayer: true,
    showEvents: false,
    showTags: false,
    fullMap: false,
    hovered: null,
    hitCells: [],
    dragging: false,
    objJustDown: false,
    visited: new Set(),
    raf: 0,
    topDownRaf: 0,
    tilesetLoading: new Map(),
    rendering: false,
    rerender: false,
    interactionTimer: 0,
    lastRenderAt: 0,
    interactionFrameMs: 33,
    tilesetId: null,
    tilesetImage: null,
    tilesetImages: new Map(),
    autotileImages: [],
    autotileImagesByTileset: new Map(),
    autotileImagesByName: new Map(),
    autotileUrls: [],
    autotileCache: new Map(),
    tileProps: new Map(),
    transformedSourceCache: new Map(),
    characterImages: new Map(),
    characterUrls: [],
    modelImages: new Map(),
    modelImageUrls: [],
    orbiting: false,
    orbitStartX: 0,
    orbitStartY: 0,
    orbitStartYaw: 0,
    orbitStartPitch: 25,
    cliffSource: null,
    lastMapId: null,
    warning: "",
    assetStats: { standardAutotiles: 0, extraAutotiles: 0, missingSources: 0, groundCells: 0, groundTextured: 0, groundMissing: 0, regularTilesets: 0 },
    layerStats: { native: 3, extended: 0 },
    usedAssetsByMap: new Map(),
    colorModel: "auto",
    ignoreColorTransforms: true,
    cellEntryCache: new Map(),
    legacyHeightTimer: 0,
    canvasPool: [],
    extendedDataByMap: new Map(),
    rxMaps: new Map(),
    rxTilesets: null,
  },
};

function pad3(value) {
  return String(Number(value) || 0).padStart(3, "0");
}

const GEO4_DIR = "Data/VERMEIL_GEOMETRY_V4";
const LEGACY_GEO_DIR = "Data/VERMEIL2_5D";
function geometryPath(mapId) {
  return `${GEO4_DIR}/Map${pad3(mapId)}.v25d`;
}
function geometryCollisionPath(mapId) {
  return `${GEO4_DIR}/Map${pad3(mapId)}.v25c`;
}
function geometryRuntimePath(mapId) {
  return `${GEO4_DIR}/Map${pad3(mapId)}.v25r`;
}
function geometryModelStreamPath(mapId) {
  return `${GEO4_DIR}/Map${pad3(mapId)}.v25m`;
}
function legacyGeometryPaths(mapId) {
  return [
    `${LEGACY_GEO_DIR}/Map${pad3(mapId)}.json`,
    `${LEGACY_GEO_DIR}/Map${pad3(mapId)}_runtime.json`,
    `${LEGACY_GEO_DIR}/Map${pad3(mapId)}_collision.json`,
    `${LEGACY_GEO_DIR}/Map${pad3(mapId)}_models.jsonl`,
  ];
}

function rxdataPath(mapId) {
  return `Data/Map${pad3(mapId)}.rxdata`;
}

// V4 clean storage -----------------------------------------------------------
// Deliberately NOT JSON. The old JSON authoring/runtime files accumulated
// compiler products and legacy state across revisions. V4 uses a tiny tagged
// value format with strict files and a new directory. Old VERMEIL2_5D data is
// never read by this editor.
function v25EncodeString(value) {
  const encoded = encodeURIComponent(String(value));
  return `S${encoded.length}:${encoded}`;
}
function v25Encode(value) {
  if (value == null) return 'Z';
  if (value === true) return 'T';
  if (value === false) return 'F';
  if (typeof value === 'number') {
    const n = Number.isFinite(value) ? String(value) : '0';
    return `N${n.length}:${n}`;
  }
  if (typeof value === 'string') return v25EncodeString(value);
  if (Array.isArray(value)) return `A${value.length}:` + value.map(v25Encode).join('');
  if (typeof value === 'object') {
    const entries = Object.entries(value).filter(([,v]) => typeof v !== 'undefined');
    return `O${entries.length}:` + entries.map(([k,v]) => v25EncodeString(k) + v25Encode(v)).join('');
  }
  return 'Z';
}
function v25Decode(text) {
  let i = 0;
  const lenToken = () => {
    const start = i;
    while (i < text.length && text[i] !== ':') i++;
    if (i >= text.length) throw new Error('V25 malformed length');
    const n = Number(text.slice(start, i)); i++;
    if (!Number.isInteger(n) || n < 0) throw new Error('V25 invalid length');
    return n;
  };
  const read = () => {
    const t = text[i++];
    if (t === 'Z') return null;
    if (t === 'T') return true;
    if (t === 'F') return false;
    if (t === 'N') { const n=lenToken(), raw=text.slice(i,i+n); i+=n; return Number(raw)||0; }
    if (t === 'S') { const n=lenToken(), raw=text.slice(i,i+n); i+=n; return decodeURIComponent(raw); }
    if (t === 'A') { const n=lenToken(), out=[]; for(let k=0;k<n;k++) out.push(read()); return out; }
    if (t === 'O') { const n=lenToken(), out={}; for(let k=0;k<n;k++){ const key=read(); out[String(key)]=read(); } return out; }
    throw new Error(`V25 unknown token ${t || '<eof>'}`);
  };
  const value = read();
  return value;
}
function v25Pack(kind, value) { return `${kind}\n${v25Encode(value)}\n`; }
function v25Unpack(text, kind) {
  const raw=String(text||'').replace(/^\uFEFF/,'');
  const nl=raw.indexOf('\n');
  if(nl<0 || raw.slice(0,nl).trim()!==kind) throw new Error(`Expected ${kind}`);
  return v25Decode(raw.slice(nl+1).trim());
}

// V4.2 runtime files are line-based. The editor authoring file remains V25D1,
// but gameplay never decodes one giant object. Each small runtime record can be
// parsed independently and model faces remain in the lazy V25M stream.
function v25RuntimePackFast(runtimeGeo) {
  const header = {
    format: "vermeil-runtime-fast-2",
    map_id: runtimeGeo.map_id, width: runtimeGeo.width, height: runtimeGeo.height,
    height_step: runtimeGeo.height_step, inherit_legacy: false,
    model_stream: runtimeGeo.model_stream || "", model_face_count: runtimeGeo.model_face_count || 0
  };
  const lines = ["V25R2", `H${v25Encode(header)}`];
  for (const [key,value] of Object.entries(runtimeGeo.cells || {})) lines.push(`C${v25Encode([key,value])}`);
  for (const row of runtimeGeo.ramps || []) lines.push(`R${v25Encode(row)}`);
  for (const row of runtimeGeo.terrain_planes || []) lines.push(`P${v25Encode(row)}`);
  for (const mat of runtimeGeo.materials || []) lines.push(`M${v25Encode(mat)}`);
  for (const face of runtimeGeo.mesh_faces_compact || []) lines.push(`F${v25Encode(face)}`);
  for (const obj of runtimeGeo.objects || []) lines.push(`O${v25Encode(obj)}`);
  for (const obj of runtimeGeo.compiled_objects || []) lines.push(`O${v25Encode(obj)}`);
  return `${lines.join("\n")}\n`;
}
function v25CollisionPackFast(sidecar) {
  const header = {
    format: "vermeil-collision-fast-2", map_id: sidecar.map_id,
    width: sidecar.width, height: sidecar.height, height_step: sidecar.height_step
  };
  const lines = ["V25C2", `H${v25Encode(header)}`];
  for (const row of sidecar.model_collision_cells_compact || []) lines.push(`C${v25Encode(row)}`);
  return `${lines.join("\n")}\n`;
}
async function legacyDataPresent(ctx,mapId) {
  try { if (await ctx.fs.projectExists(LEGACY_GEO_DIR)) return true; } catch (_) {}
  for (const p of legacyGeometryPaths(mapId)) {
    try { if (await ctx.fs.projectExists(p)) return true; } catch (_) {}
  }
  return false;
}

function absoluteProjectPath(ctx, relPath) {
  const root = ctx.editor.gameRoot?.();
  if (!root) return null;
  const sep = root.includes("\\") ? "\\" : "/";
  return `${root}${root.endsWith("\\") || root.endsWith("/") ? "" : sep}${String(relPath).replaceAll("/", sep)}`;
}

async function readProjectBinary(ctx, relPath) {
  const invoke = window.__TAURI__?.core?.invoke;
  const abs = absoluteProjectPath(ctx, relPath);
  if (!invoke || !abs) return null;
  const bytes = await invoke("read_binary_file", { path: abs });
  return bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes || []);
}

async function ensureRxTilesets(ctx, force = false) {
  if (!force && state.preview.rxTilesets) return state.preview.rxTilesets;
  try {
    state.preview.rxTilesets = parseTilesetsRxdata(await readProjectBinary(ctx, "Data/Tilesets.rxdata"));
  } catch (err) {
    ctx.log.warn("2.5D Geometry: no se pudo leer Data/Tilesets.rxdata", err);
    state.preview.rxTilesets = [];
  }
  return state.preview.rxTilesets;
}

async function ensureRxMap(ctx, mapId, force = false) {
  if (!force && state.preview.rxMaps.has(mapId)) return state.preview.rxMaps.get(mapId);
  try {
    const parsed = parseMapRxdata(await readProjectBinary(ctx, rxdataPath(mapId)));
    state.preview.rxMaps.set(mapId, parsed);
    return parsed;
  } catch (err) {
    ctx.log.warn(`2.5D Geometry: no se pudo parsear ${rxdataPath(mapId)}`, err);
    state.preview.rxMaps.set(mapId, null);
    return null;
  }
}

function mapTilesetId(info, mapId = null) {
  const rx = mapId == null ? null : state.preview.rxMaps.get(mapId);
  return Number(firstDefined(rx?.tilesetId, info?.tilesetId, info?.tileset_id, info?.tileset?.id, info?.tileset)) || 0;
}

function normalizeExtendedData(raw) {
  if (!raw) return null;
  if (typeof raw === "string") {
    try { raw = JSON.parse(raw); } catch (_) { return null; }
  }
  if (Array.isArray(raw)) return { layers: raw };
  if (raw.extendedData) return normalizeExtendedData(raw.extendedData);
  if (raw.extended_data) return normalizeExtendedData(raw.extended_data);
  if (raw.extendedLayers) return { ...(raw || {}), layers: raw.extendedLayers };
  if (raw.extended_layers) return normalizeExtendedData(raw.extended_layers);
  if (raw.layers || raw.nativeProperties || raw.native_properties) {
    return {
      ...raw,
      layers: raw.layers || [],
      nativeProperties: raw.nativeProperties || raw.native_properties || null,
    };
  }
  return null;
}

function extractJsonObjectAt(text, start) {
  let depth = 0;
  let inString = false;
  let escaped = false;
  for (let i = start; i < text.length; i++) {
    const ch = text[i];
    if (inString) {
      if (escaped) escaped = false;
      else if (ch === "\\") escaped = true;
      else if (ch === "\"") inString = false;
      continue;
    }
    if (ch === "\"") inString = true;
    else if (ch === "{") depth++;
    else if (ch === "}") {
      depth--;
      if (depth === 0) return text.slice(start, i + 1);
    }
  }
  return null;
}

function findEmbeddedExtendedData(text) {
  const markers = ["\"nativeProperties\"", "\"native_properties\"", "\"layers\""];
  for (const marker of markers) {
    let pos = text.indexOf(marker);
    while (pos >= 0) {
      const start = text.lastIndexOf("{", pos);
      if (start >= 0) {
        const json = extractJsonObjectAt(text, start);
        const data = normalizeExtendedData(json);
        if (data && (data.nativeProperties || (data.layers || []).length)) return data;
      }
      pos = text.indexOf(marker, pos + marker.length);
    }
  }
  return null;
}

async function loadEmbeddedExtendedData(ctx, mapId) {
  if (state.preview.extendedDataByMap.has(mapId)) return state.preview.extendedDataByMap.get(mapId);
  let data = null;
  // Preferred: the JSON is already decoded by the Marshal parser (rxMaps fills
  // this from RPG::Map#@extended_layers). Avoids a fragile text-scan of binary.
  const rxRow = state.preview.rxMaps.get(mapId);
  const rawJson = rxRow?.extendedLayers;
  if (rawJson) data = normalizeExtendedData(rawJson);
  if (!data) {
    // Fallback: text-scan the raw rxdata for an embedded object.
    const invoke = window.__TAURI__?.core?.invoke;
    const root = ctx.editor.gameRoot?.();
    try {
      if (invoke && root) {
        const sep = root.includes("\\") ? "\\" : "/";
        const path = `${root}${root.endsWith("\\") || root.endsWith("/") ? "" : sep}${rxdataPath(mapId).replaceAll("/", sep)}`;
        const bytes = await invoke("read_binary_file", { path });
        const text = new TextDecoder("utf-8", { fatal: false }).decode(new Uint8Array(bytes || []));
        data = findEmbeddedExtendedData(text);
      }
    } catch (err) {
      ctx.log.warn(`2.5D Geometry: no se pudo leer ${rxdataPath(mapId)} para @extended_layers`, err);
    }
  }
  state.preview.extendedDataByMap.set(mapId, data || null);
  return data || null;
}

function mapExtendedData(ctx, mapId) {
  try {
    const direct = firstDefined(
      ctx.map.extendedData?.(mapId),
      ctx.map.getExtendedData?.(mapId),
      ctx.map.getExtendedLayers?.(mapId),
      ctx.map.extendedLayers?.(mapId)
    );
    const normalized = normalizeExtendedData(direct);
    if (normalized) return normalized;
  } catch (_) {}
  try {
    const info = ctx.map.info(mapId);
    const normalized = normalizeExtendedData(firstDefined(
      info?.extendedData,
      info?.extended_data,
      info?.extendedLayers,
      info?.extended_layers,
      info?.makerStudio,
      info?.maker_studio
    ));
    if (normalized) return normalized;
  } catch (_) {
  }
  if (state.preview.extendedDataByMap.has(mapId)) return state.preview.extendedDataByMap.get(mapId);
  return null;
}

function normalizeComponentSet(raw) {
  const base = { extrude: true, cap: true, connect_neighbors: false, slope: false, billboard: false, occlusion: "auto" };
  if (!raw || typeof raw !== "object") return base;
  return {
    extrude: raw.extrude !== false,
    cap: raw.cap !== false,
    connect_neighbors: raw.connect_neighbors === true,
    slope: raw.slope === true,
    billboard: raw.billboard === true,
    occlusion: ["auto", "front", "behind", "none"].includes(raw.occlusion) ? raw.occlusion : "auto",
  };
}

function normalizeSourceDefinition(raw, sourceKey = "") {
  const preset = SCENE_GEOMETRY_PRESETS[raw?.category] || SCENE_GEOMETRY_PRESETS.custom;
  return {
    source_key: String(raw?.source_key || sourceKey),
    label: String(raw?.label || sourceKey || "Source"),
    enabled: raw?.enabled !== false,
    category: OBJECT_CATEGORIES.some(([id]) => id === raw?.category) ? raw.category : preset.category,
    type: raw?.type === "plane" ? "plane" : "cube",
    height: Math.max(0, Number(raw?.height ?? preset.height) || 0),
    anchor_z: Math.max(0, Number(raw?.anchor_z ?? preset.anchor_z) || 0),
    collision: OBJECT_COLLISIONS.includes(raw?.collision) ? raw.collision : preset.collision,
    characters_in_front: raw?.characters_in_front === true,
    components: normalizeComponentSet(raw?.components || preset.components),
  };
}

function normalizeSourceDefinitions(raw) {
  const out = {};
  if (!raw || typeof raw !== "object") return out;
  for (const [key, value] of Object.entries(raw)) {
    if (!key || !value || typeof value !== "object") continue;
    out[key] = normalizeSourceDefinition(value, key);
  }
  return out;
}

function normalizeInstanceOverrides(raw) {
  const out = {};
  if (!raw || typeof raw !== "object") return out;
  for (const [key, value] of Object.entries(raw)) {
    if (!key || !value || typeof value !== "object") continue;
    const row = {};
    if (value.disabled != null) row.disabled = !!value.disabled;
    if (value.category && OBJECT_CATEGORIES.some(([id]) => id === value.category)) row.category = value.category;
    if (value.type === "cube" || value.type === "plane") row.type = value.type;
    if (value.height != null) row.height = Math.max(0, Number(value.height) || 0);
    if (value.anchor_z != null) row.anchor_z = Math.max(0, Number(value.anchor_z) || 0);
    if (OBJECT_COLLISIONS.includes(value.collision)) row.collision = value.collision;
    if (value.characters_in_front != null) row.characters_in_front = !!value.characters_in_front;
    if (value.components && typeof value.components === "object") row.components = normalizeComponentSet(value.components);
    out[key] = row;
  }
  return out;
}

function normalizeCompilerMeta(raw, geo) {
  const stats = raw?.stats && typeof raw.stats === "object" ? raw.stats : {};
  return {
    version: SCENE_COMPILER_VERSION,
    auto_compile: raw?.auto_compile !== false,
    last_compile: raw?.last_compile || null,
    stats: {
      placed_tiles: Number(stats.placed_tiles) || 0,
      unique_sources: Number(stats.unique_sources) || Object.keys(geo?.definitions || {}).length,
      defined_sources: Number(stats.defined_sources) || Object.keys(geo?.definitions || {}).length,
      compiled_objects: Number(stats.compiled_objects) || (geo?.compiled_objects || []).length,
    },
  };
}

function newGeometry(mapId, info) {
  return {
    format: FORMAT,
    map_id: mapId,
    width: info?.width ?? 0,
    height: info?.height ?? 0,
    height_step: runtimeConfig.surfaceGeometryHeightStep || DEFAULT_STEP,
    inherit_legacy: false,
    cells: {},
    ramps: [],
    // Sparse DS-style terrain authoring. Each entry stores four corner heights
    // in height-step units: [NW, NE, SE, SW]. Runtime receives merged planes.
    terrain_cells: {},
    objects: [],
    // Source-driven scene compiler. Definitions are prefab-like rules keyed by
    // the REAL tile source, instance_overrides are per placed occurrence, and
    // compiled_objects is the canonical runtime/preview output.
    definitions: {},
    instance_overrides: {},
    compiled_objects: [],
    // Reusable visual models (mountains/buildings/etc.) and their map instances.
    models: {},
    model_instances: [],
    model_objects: [],
    // Canonical grid collision compiled from model/part collision volumes.
    // This is consumed directly by MKXP-Z passability; render meshes are never
    // used as the source of truth for movement collision.
    model_collision_cells: [],
    // Region-meshed render output shared by editor preview and MKXP-Z runtime.
    // model_objects remain lightweight collision proxies; mesh_faces are the
    // visible top/perimeter surfaces and are kept while a dirty rebuild runs.
    mesh_faces: [],
    mesh_compiler: { version: 1, last_build: null, stats: { cells: 0, faces: 0, top_faces: 0, side_faces: 0 } },
    compiler: {
      version: SCENE_COMPILER_VERSION,
      auto_compile: true,
      last_compile: null,
      stats: { placed_tiles: 0, unique_sources: 0, defined_sources: 0, compiled_objects: 0 },
    },
    editor_preview: {
      angle: runtimeConfig.outdoorDefaultAlpha || 25,
      yaw: 0,
      zoom: 1.0,
      radius: 10,
    },
  };
}


function normalizeFaceMaterialMap(raw) {
  const out = { top: null, north: null, south: null, east: null, west: null };
  if (!raw || typeof raw !== "object") return out;
  for (const key of Object.keys(out)) out[key] = raw[key] && typeof raw[key] === "object" ? raw[key] : null;
  return out;
}


// Model Builder v2.9 ---------------------------------------------------------
// Models are authored as editable primitive parts (similar to the reference
// workflow) and compiled to generic textured quads. Legacy cell models remain
// supported and are still used as collision proxies where appropriate.
const MODEL_PART_TYPES = ["box","billboard","sphere","relief","cylinder","prism","dome","wedge"];

function normalizeLegacyGeometryCell(raw, fallbackHeight = 1) {
  const value = raw && typeof raw === "object" ? raw : {};
  return {
    enabled: value.enabled !== false,
    height: Math.max(.25, Number(value.height ?? fallbackHeight) || fallbackHeight || 1),
    anchor_z: Math.max(0, Number(value.anchor_z) || 0),
    face_materials: normalizeFaceMaterialMap(value.face_materials),
  };
}

function normalizeVec3(raw, fallback = {x:0,y:0,z:0}) {
  const v = raw && typeof raw === "object" ? raw : {};
  return {
    x: Number(v.x ?? fallback.x) || 0,
    y: Number(v.y ?? fallback.y) || 0,
    z: Number(v.z ?? fallback.z) || 0,
  };
}

function normalizeVertexOffsets(raw) {
  const out = {};
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) return out;
  for (const [key, value] of Object.entries(raw)) {
    if (!value || typeof value !== "object") continue;
    const v = normalizeVec3(value, {x:0,y:0,z:0});
    if (Math.abs(v.x) + Math.abs(v.y) + Math.abs(v.z) > 0.000001) out[String(key)] = v;
  }
  return out;
}

function normalizeCollisionShape(raw, visualSize) {
  const vsize = visualSize && typeof visualSize === "object" ? visualSize : {x:1,y:1,z:1};
  const value = raw && typeof raw === "object" ? raw : {};
  const size = normalizeVec3(value.size, vsize);
  size.x = Math.max(.05, Math.abs(size.x) || Math.abs(vsize.x) || 1);
  size.y = Math.max(.05, Math.abs(size.y) || Math.abs(vsize.y) || 1);
  size.z = Math.max(.05, Math.abs(size.z) || Math.abs(vsize.z) || 1);
  return {
    mode: value.mode === "manual" || value.custom === true ? "manual" : "auto",
    size,
    offset: normalizeVec3(value.offset, {x:0,y:0,z:0}),
  };
}

function vertexCoord(v) { return Math.round(Number(v || 0) * 10000) / 10000; }
function partVertexKeyFromNorm(nx, ny, nz) { return `${vertexCoord(nx)},${vertexCoord(ny)},${vertexCoord(nz)}`; }
function partVertexNormFromLocal(part, x, y, z) {
  const pos = part?.position || {x:.5,y:.5,z:0}, sz = part?.size || {x:1,y:1,z:1};
  const x0 = pos.x - sz.x / 2, y0 = pos.y - sz.y / 2, z0 = pos.z;
  return [
    sz.x ? (x - x0) / sz.x : 0,
    sz.y ? (y - y0) / sz.y : 0,
    sz.z ? (z - z0) / sz.z : 0,
  ];
}
function partVertexOffset(part, key) {
  const v = part?.vertex_offsets?.[key];
  return v && typeof v === "object" ? normalizeVec3(v, {x:0,y:0,z:0}) : {x:0,y:0,z:0};
}
function partVertexPoint(part, x, y, z, pivot) {
  const norm = partVertexNormFromLocal(part, x, y, z);
  const key = partVertexKeyFromNorm(norm[0], norm[1], norm[2]);
  const off = partVertexOffset(part, key);
  return {
    key, norm,
    position: rotateXYZPoint([x + off.x, y + off.y, z + off.z], part.angle, pivot),
  };
}


function normalizeCustomModelFaces(raw) {
  if (!Array.isArray(raw)) return null;
  const out = [];
  for (let i = 0; i < raw.length; i++) {
    const f = raw[i];
    if (!f || !Array.isArray(f.norms) || f.norms.length !== 4) continue;
    const norms = f.norms.map(v => {
      const a = Array.isArray(v) ? v : [0,0,0];
      return [Number(a[0])||0, Number(a[1])||0, Number(a[2])||0];
    });
    out.push({
      id: String(f.id || `cf_${i}`),
      edge: String(f.edge || "south"),
      surface: String(f.surface || (f.edge === "top" ? "top" : "side")),
      norms,
      uv_rect: Array.isArray(f.uv_rect) && f.uv_rect.length === 4
        ? f.uv_rect.map(Number) : null,
      uv_points: Array.isArray(f.uv_points) && f.uv_points.length === 4
        ? f.uv_points.map(v => Array.isArray(v) ? [Number(v[0])||0, Number(v[1])||0] : [0,0]) : null,
      material_repeat: f.material_repeat !== false,
      material: f.material && typeof f.material === "object" ? deepClone(f.material) : null,
    });
  }
  return out.length ? out : null;
}

function partVertexPointFromNorm(part, norm, pivot) {
  const pos = part?.position || {x:.5,y:.5,z:0}, sz = part?.size || {x:1,y:1,z:1};
  const x0 = pos.x - sz.x / 2, y0 = pos.y - sz.y / 2, z0 = pos.z;
  const nx=Number(norm?.[0])||0, ny=Number(norm?.[1])||0, nz=Number(norm?.[2])||0;
  const key = partVertexKeyFromNorm(nx,ny,nz);
  const off = partVertexOffset(part,key);
  const local = [x0 + nx*sz.x + off.x, y0 + ny*sz.y + off.y, z0 + nz*sz.z + off.z];
  return {key, norm:[nx,ny,nz], position:rotateXYZPoint(local, part.angle, pivot)};
}

function customFacesFromCurrentPart(part) {
  const saved = part.custom_faces;
  part.custom_faces = null;
  const primitive = partLocalQuads(part);
  part.custom_faces = saved;
  return primitive.map((f,i)=>({
    id:`cf_${i}`,
    edge:f.edge||"south",
    surface:f.surface||(f.edge==="top"?"top":"side"),
    norms:(f.vertex_norms||[]).map(v=>Array.isArray(v)?v.slice():[0,0,0]),
    uv_rect:Array.isArray(f.uv_rect)?f.uv_rect.slice():[0,0,1,1],
    material_repeat:f.material_repeat!==false,
    material: cloneMaterial(f.material),
  })).filter(f=>f.norms.length===4);
}

function ensureCustomFaces(part) {
  if (!part) return [];
  if (!Array.isArray(part.custom_faces) || !part.custom_faces.length) {
    part.custom_faces = customFacesFromCurrentPart(part);
  }
  return part.custom_faces;
}

function mixNorm(a,b,t=.5){return[
  (Number(a?.[0])||0)+((Number(b?.[0])||0)-(Number(a?.[0])||0))*t,
  (Number(a?.[1])||0)+((Number(b?.[1])||0)-(Number(a?.[1])||0))*t,
  (Number(a?.[2])||0)+((Number(b?.[2])||0)-(Number(a?.[2])||0))*t
];}

function normalizeModelPart(raw, index = 0) {
  const type = MODEL_PART_TYPES.includes(String(raw?.type || "").toLowerCase()) ? String(raw.type).toLowerCase() : "box";
  const size = normalizeVec3(raw?.size, {x:1,y:1,z:1});
  size.x = Math.max(.05, Math.abs(size.x) || 1);
  size.y = Math.max(.05, Math.abs(size.y) || 1);
  size.z = Math.max(.05, Math.abs(size.z) || 1);
  const angle = normalizeVec3(raw?.angle, {x:0,y:0,z:0});
  return {
    id: String(raw?.id || `part_${index+1}`),
    name: String(raw?.name || `${type.toUpperCase()} ${index+1}`),
    type,
    position: normalizeVec3(raw?.position, {x:.5,y:.5,z:0}),
    size,
    angle,
    axis: ["x","y","z"].includes(String(raw?.axis)) ? String(raw.axis) : "x",
    segments: Math.max(4, Math.min(24, Math.round(Number(raw?.segments) || 8))),
    subdivisions: Math.max(1, Math.min(8, Math.round(Number(raw?.subdivisions) || 1))),
    visible: raw?.visible !== false,
    collision: raw?.collision === false ? false : true,
    collision_shape: normalizeCollisionShape(raw?.collision_shape, size),
    vertex_offsets: normalizeVertexOffsets(raw?.vertex_offsets),
    custom_faces: normalizeCustomModelFaces(raw?.custom_faces),
    texture_mode: raw?.texture_mode === "stretch" ? "stretch" : (raw?.repeat === false ? "stretch" : "repeat"),
    repeat: raw?.texture_mode === "stretch" ? false : (raw?.repeat !== false),
    material: raw?.material && typeof raw.material === "object" ? raw.material : null,
    face_materials: normalizeFaceMaterialMap(raw?.face_materials),
  };
}

function normalizeModelParts(raw) {
  if (!Array.isArray(raw)) return [];
  const used = new Set();
  return raw.filter(Boolean).map((part, i) => {
    const p = normalizeModelPart(part, i);
    let id = p.id, n = 2;
    while (used.has(id)) id = `${p.id}_${n++}`;
    p.id = id; used.add(id); return p;
  });
}

function nextModelPartId(model, type = "part") {
  const used = new Set((model?.parts || []).map(p => String(p.id)));
  let n = 1, id = `${type}_${n}`;
  while (used.has(id)) id = `${type}_${++n}`;
  return id;
}

function modelPartFaceMaterial(part, edge) {
  return cloneMaterial(part?.face_materials?.[edge] || part?.material || part?.face_materials?.top || null);
}

function rotateXYZPoint(p, angle, pivot) {
  let x=p[0]-pivot[0], y=p[1]-pivot[1], z=p[2]-pivot[2];
  const ax=(Number(angle?.x)||0)*Math.PI/180, ay=(Number(angle?.y)||0)*Math.PI/180, az=(Number(angle?.z)||0)*Math.PI/180;
  let c=Math.cos(ax), sn=Math.sin(ax); let y1=y*c-z*sn, z1=y*sn+z*c; y=y1;z=z1;
  c=Math.cos(ay);sn=Math.sin(ay); let x1=x*c+z*sn;z1=-x*sn+z*c;x=x1;z=z1;
  c=Math.cos(az);sn=Math.sin(az);x1=x*c-y*sn;y1=x*sn+y*c;x=x1;y=y1;
  return [x+pivot[0],y+pivot[1],z+pivot[2]];
}

function partLocalQuads(part) {
  if (!part || part.visible === false) return [];
  const pos=part.position||{x:.5,y:.5,z:0}, sz=part.size||{x:1,y:1,z:1};
  const hx=sz.x/2, hy=sz.y/2, z0=pos.z, z1=pos.z+sz.z;
  const cx=pos.x, cy=pos.y, pivot=[cx,cy,z0];
  const q=[];
  const add=(edge,verts,surface=edge==="top"?"top":"side",uvRect=null)=>{
    const points=verts.map(v=>partVertexPoint(part,v[0],v[1],v[2],pivot));
    const repeatMode=(part.texture_mode||((part.repeat===false)?"stretch":"repeat"))!=="stretch";
    q.push({edge,surface,vertices:points.map(p=>p.position),vertex_keys:points.map(p=>p.key),vertex_norms:points.map(p=>p.norm),uv_rect:Array.isArray(uvRect)?uvRect.slice():null,material:modelPartFaceMaterial(part,edge),part_id:part.id,material_repeat:repeatMode});
  };
  if(Array.isArray(part.custom_faces) && part.custom_faces.length){
    for(let fi=0;fi<part.custom_faces.length;fi++){
      const cf=part.custom_faces[fi];
      if(!cf || !Array.isArray(cf.norms) || cf.norms.length!==4) continue;
      const points=cf.norms.map(n=>partVertexPointFromNorm(part,n,pivot));
      q.push({
        edge:cf.edge||"south",surface:cf.surface||"side",
        vertices:points.map(p=>p.position),vertex_keys:points.map(p=>p.key),
        vertex_norms:points.map(p=>p.norm),
        uv_rect:Array.isArray(cf.uv_rect)?cf.uv_rect.slice():null,
        uv_points:Array.isArray(cf.uv_points)?cf.uv_points.map(v=>Array.isArray(v)?v.slice():v):null,
        material:cloneMaterial(cf.material) || modelPartFaceMaterial(part,cf.edge||"south"),
        part_id:part.id,material_repeat:((part.texture_mode||((part.repeat===false)?"stretch":"repeat"))!=="stretch") && cf.material_repeat!==false,
        custom_face_index:fi,custom_face_id:cf.id||`cf_${fi}`
      });
    }
    return q;
  }
  const x0=cx-hx,x1=cx+hx,y0=cy-hy,y1=cy+hy;
  if(part.type==="box" || part.type==="relief"){
    const sub=Math.max(1,Math.min(8,Math.round(Number(part.subdivisions)||1)));
    const L=(a,b,t)=>a+(b-a)*t;
    for(let iy=0;iy<sub;iy++)for(let ix=0;ix<sub;ix++){
      const xa=L(x0,x1,ix/sub),xb=L(x0,x1,(ix+1)/sub),ya=L(y0,y1,iy/sub),yb=L(y0,y1,(iy+1)/sub);
      add("top",[[xa,ya,z1],[xb,ya,z1],[xb,yb,z1],[xa,yb,z1]],"top",[ix/sub,iy/sub,(ix+1)/sub,(iy+1)/sub]);
    }
    for(let iz=0;iz<sub;iz++)for(let ix=0;ix<sub;ix++){
      const xa=L(x0,x1,ix/sub),xb=L(x0,x1,(ix+1)/sub),za=L(z0,z1,iz/sub),zb=L(z0,z1,(iz+1)/sub);
      add("north",[[xa,y0,zb],[xb,y0,zb],[xb,y0,za],[xa,y0,za]],"side",[ix/sub,1-(iz+1)/sub,(ix+1)/sub,1-iz/sub]);
      add("south",[[xb,y1,zb],[xa,y1,zb],[xa,y1,za],[xb,y1,za]],"side",[ix/sub,1-(iz+1)/sub,(ix+1)/sub,1-iz/sub]);
    }
    for(let iz=0;iz<sub;iz++)for(let iy=0;iy<sub;iy++){
      const ya=L(y0,y1,iy/sub),yb=L(y0,y1,(iy+1)/sub),za=L(z0,z1,iz/sub),zb=L(z0,z1,(iz+1)/sub);
      add("west",[[x0,yb,zb],[x0,ya,zb],[x0,ya,za],[x0,yb,za]],"side",[iy/sub,1-(iz+1)/sub,(iy+1)/sub,1-iz/sub]);
      add("east",[[x1,ya,zb],[x1,yb,zb],[x1,yb,za],[x1,ya,za]],"side",[iy/sub,1-(iz+1)/sub,(iy+1)/sub,1-iz/sub]);
    }
  } else if(part.type==="billboard"){
    if(part.axis==="y") add("south",[[cx,y0,z1],[cx,y1,z1],[cx,y1,z0],[cx,y0,z0]],"billboard");
    else add("south",[[x0,cy,z1],[x1,cy,z1],[x1,cy,z0],[x0,cy,z0]],"billboard");
  } else if(part.type==="wedge"){
    if(part.axis==="y"){
      add("top",[[x0,y0,z0],[x1,y0,z0],[x1,y1,z1],[x0,y1,z1]],"top");
      add("south",[[x1,y1,z1],[x0,y1,z1],[x0,y1,z0],[x1,y1,z0]]);
      add("west",[[x0,y1,z1],[x0,y0,z0],[x0,y0,z0],[x0,y1,z0]]);
      add("east",[[x1,y0,z0],[x1,y1,z1],[x1,y1,z0],[x1,y0,z0]]);
    }else{
      add("top",[[x0,y0,z0],[x1,y0,z1],[x1,y1,z1],[x0,y1,z0]],"top");
      add("east",[[x1,y0,z1],[x1,y1,z1],[x1,y1,z0],[x1,y0,z0]]);
      add("north",[[x0,y0,z0],[x1,y0,z1],[x1,y0,z0],[x0,y0,z0]]);
      add("south",[[x1,y1,z1],[x0,y1,z0],[x0,y1,z0],[x1,y1,z0]]);
    }
  } else if(part.type==="prism"){
    if(part.axis==="y"){
      const a=[x0,cy,z0],b=[x1,cy,z0],t=[cx,cy,z1];
      add("north",[[a[0],y0,a[2]],[b[0],y0,b[2]],[t[0],y0,t[2]],[t[0],y0,t[2]]]);
      add("south",[[b[0],y1,b[2]],[a[0],y1,a[2]],[t[0],y1,t[2]],[t[0],y1,t[2]]]);
      add("west",[[a[0],y1,a[2]],[a[0],y0,a[2]],[t[0],y0,t[2]],[t[0],y1,t[2]]]);
      add("east",[[b[0],y0,b[2]],[b[0],y1,b[2]],[t[0],y1,t[2]],[t[0],y0,t[2]]]);
    } else {
      const a=[cx,y0,z0],b=[cx,y1,z0],t=[cx,cy,z1];
      add("west",[[x0,a[1],a[2]],[x0,b[1],b[2]],[x0,t[1],t[2]],[x0,t[1],t[2]]]);
      add("east",[[x1,b[1],b[2]],[x1,a[1],a[2]],[x1,t[1],t[2]],[x1,t[1],t[2]]]);
      add("north",[[x1,a[1],a[2]],[x0,a[1],a[2]],[x0,t[1],t[2]],[x1,t[1],t[2]]]);
      add("south",[[x0,b[1],b[2]],[x1,b[1],b[2]],[x1,t[1],t[2]],[x0,t[1],t[2]]]);
    }
  } else if(part.type==="cylinder" || part.type==="sphere" || part.type==="dome"){
    const seg=Math.max(4,Number(part.segments)||8), rings=part.type==="cylinder"?1:Math.max(3,Math.round(seg/2));
    if(part.type==="cylinder"){
      for(let i=0;i<seg;i++){
        const a=i*Math.PI*2/seg,b=(i+1)*Math.PI*2/seg;
        const p0=[cx+Math.cos(a)*hx,cy+Math.sin(a)*hy,z0],p1=[cx+Math.cos(b)*hx,cy+Math.sin(b)*hy,z0],p2=[p1[0],p1[1],z1],p3=[p0[0],p0[1],z1];
        add(i<seg/4?"east":i<seg/2?"south":i<seg*3/4?"west":"north",[p3,p2,p1,p0]);
      }
      for(let i=0;i<seg;i++){const a=i*Math.PI*2/seg,b=(i+1)*Math.PI*2/seg;add("top",[[cx,cy,z1],[cx+Math.cos(a)*hx,cy+Math.sin(a)*hy,z1],[cx+Math.cos(b)*hx,cy+Math.sin(b)*hy,z1],[cx,cy,z1]],"top");}
    }else{
      const start=part.type==="dome"?0:-Math.PI/2, end=Math.PI/2;
      const rr=part.type==="dome"?rings:Math.max(4,rings*2);
      for(let j=0;j<rr;j++){
        const v0=start+(end-start)*j/rr,v1=start+(end-start)*(j+1)/rr;
        for(let i=0;i<seg;i++){
          const u0=i*Math.PI*2/seg,u1=(i+1)*Math.PI*2/seg;
          const vv=(u,v)=>[cx+Math.cos(v)*Math.cos(u)*hx,cy+Math.cos(v)*Math.sin(u)*hy,z0+sz.z*(part.type==="dome"?Math.sin(v):(.5+.5*Math.sin(v)))];
          const verts=[vv(u0,v1),vv(u1,v1),vv(u1,v0),vv(u0,v0)];
          const mid=(u0+u1)/2,edge=Math.cos(mid)>.5?"east":Math.cos(mid)<-.5?"west":Math.sin(mid)>.0?"south":"north";
          add(v1>1.2?"top":edge,verts,v1>1.2?"top":"side");
        }
      }
    }
  }
  return q;
}

function modelPartBounds(model) {
  const pts=[];
  for(const p of model?.parts||[]) for(const f of partLocalQuads(p)) pts.push(...f.vertices);
  if(!pts.length)return{x0:0,y0:0,z0:0,x1:Math.max(1,Number(model?.width)||1),y1:Math.max(1,Number(model?.height)||1),z1:1};
  return{x0:Math.min(...pts.map(p=>p[0])),y0:Math.min(...pts.map(p=>p[1])),z0:Math.min(...pts.map(p=>p[2])),x1:Math.max(...pts.map(p=>p[0])),y1:Math.max(...pts.map(p=>p[1])),z1:Math.max(...pts.map(p=>p[2]))};
}

function transformModelVertexForInstance(v, inst, model) {
  const sx=Math.max(.01,Number(inst?.scale_x)||1),sy=Math.max(.01,Number(inst?.scale_y)||1),hs=Math.max(.01,Number(inst?.height_scale)||1),rot=normalizeModelPlacementRotation(inst?.rotation);
  const b=modelPartBounds(model), w=(b.x1-b.x0)*sx, h=(b.y1-b.y0)*sy;
  const x=(v[0]-b.x0)*sx,y=(v[1]-b.y0)*sy,z=v[2]*hs;
  if(Math.abs(rot)<.0001)return[(Number(inst?.x)||0)+x,(Number(inst?.y)||0)+y,z];
  const a=rot*Math.PI/180,c=Math.cos(a),sn=Math.sin(a);
  const corners=[[0,0],[w,0],[w,h],[0,h]].map(([cx,cy])=>[cx*c-cy*sn,cx*sn+cy*c]);
  const minx=Math.min(...corners.map(q=>q[0])),miny=Math.min(...corners.map(q=>q[1]));
  const rx=x*c-y*sn-minx,ry=x*sn+y*c-miny;
  return[(Number(inst?.x)||0)+rx,(Number(inst?.y)||0)+ry,z];
}

function modelPartMeshFacesForInstance(inst, model, startId=400000) {
  const faces=[];let id=startId;
  for(const part of model?.parts||[]){
    if(part.visible===false)continue;
    const localFaces=partLocalQuads(part);
    for(let part_face_index=0;part_face_index<localFaces.length;part_face_index++){
      const f=localFaces[part_face_index];
      const vertices=f.vertices.map(v=>transformModelVertexForInstance(v,inst,model));
      const xs=vertices.map(v=>v[0]),ys=vertices.map(v=>v[1]),zs=vertices.map(v=>v[2]);
      let pattern_uv=null;
      if(f.material_repeat!==false && vertices.length===4){
        const d3=(a,b)=>Math.hypot((a?.[0]||0)-(b?.[0]||0),(a?.[1]||0)-(b?.[1]||0),(a?.[2]||0)-(b?.[2]||0));
        const faceU=Math.max(0,d3(vertices[0],vertices[1])), faceV=Math.max(0,d3(vertices[0],vertices[3]));
        if(Array.isArray(f.uv_rect)&&f.uv_rect.length===4){
          const u0=Number(f.uv_rect[0])||0,v0=Number(f.uv_rect[1])||0,u1=Number(f.uv_rect[2])||0,v1=Number(f.uv_rect[3])||0;
          const du=Math.abs(u1-u0),dv=Math.abs(v1-v0);
          const totalU=du>1e-6?faceU/du:faceU,totalV=dv>1e-6?faceV/dv:faceV;
          pattern_uv=[u0*totalU,v0*totalV,u1*totalU,v1*totalV];
        }else pattern_uv=[0,0,faceU,faceV];
      }
      faces.push({id:id++,kind:"quad",surface:f.surface||"side",edge:f.edge||null,vertices,vertex_keys:Array.isArray(f.vertex_keys)?f.vertex_keys.slice():null,vertex_norms:Array.isArray(f.vertex_norms)?f.vertex_norms.map(v=>Array.isArray(v)?v.slice():v):null,uv_rect:Array.isArray(f.uv_rect)?f.uv_rect.slice():null,pattern_uv,x0:Math.min(...xs),y0:Math.min(...ys),x1:Math.max(...xs),y1:Math.max(...ys),z0:Math.min(...zs),z1:Math.max(...zs),material:f.material,material_repeat:f.material_repeat!==false,category:model.category||"mountain",model_id:model.id,model_instance_id:inst.id,part_id:part.id,part_face_index,custom_face_index:Number.isInteger(f.custom_face_index)?f.custom_face_index:null,chunk_key:`${Math.floor(Math.min(...xs)/8)},${Math.floor(Math.min(...ys)/8)}`});
    }
  }
  const cells=expandedPartCollisionCells(inst,model);
  return{faces,nextId:id,cells};
}

function partManualCollisionVertices(part) {
  const shape = normalizeCollisionShape(part?.collision_shape, part?.size || {x:1,y:1,z:1});
  const pos=part?.position||{x:.5,y:.5,z:0}, off=shape.offset||{x:0,y:0,z:0}, sz=shape.size||{x:1,y:1,z:1};
  const cx=pos.x+off.x, cy=pos.y+off.y, z0=pos.z+off.z, z1=z0+sz.z, hx=sz.x/2, hy=sz.y/2;
  const x0=cx-hx,x1=cx+hx,y0=cy-hy,y1=cy+hy,pivot=[pos.x,pos.y,pos.z];
  return [[x0,y0,z0],[x1,y0,z0],[x1,y1,z0],[x0,y1,z0],[x0,y0,z1],[x1,y0,z1],[x1,y1,z1],[x0,y1,z1]].map(v=>rotateXYZPoint(v,part.angle,pivot));
}
function partCollisionLocalVertices(part) {
  if (!part || part.collision === false) return [];
  const shape=normalizeCollisionShape(part.collision_shape,part.size||{x:1,y:1,z:1});
  if(shape.mode==="manual")return partManualCollisionVertices(part);
  return partLocalQuads(part).flatMap(f=>f.vertices||[]);
}
function partCollisionWireVertices(part) {
  const shape=normalizeCollisionShape(part?.collision_shape,part?.size||{x:1,y:1,z:1});
  if(shape.mode==="manual")return partManualCollisionVertices(part);
  const verts=partCollisionLocalVertices(part);if(!verts.length)return[];
  const x0=Math.min(...verts.map(v=>v[0])),x1=Math.max(...verts.map(v=>v[0])),y0=Math.min(...verts.map(v=>v[1])),y1=Math.max(...verts.map(v=>v[1])),z0=Math.min(...verts.map(v=>v[2])),z1=Math.max(...verts.map(v=>v[2]));
  return [[x0,y0,z0],[x1,y0,z0],[x1,y1,z0],[x0,y1,z0],[x0,y0,z1],[x1,y0,z1],[x1,y1,z1],[x0,y1,z1]];
}
function fitPartCollisionToVisual(part) {
  if(!part)return {mode:"manual",size:{x:1,y:1,z:1},offset:{x:0,y:0,z:0}};
  const verts=partLocalQuads(part).flatMap(f=>Array.isArray(f.vertices)?f.vertices:[]);
  const pos=part.position||{x:.5,y:.5,z:0};
  if(!verts.length)return {mode:"manual",size:{...(part.size||{x:1,y:1,z:1})},offset:{x:0,y:0,z:0}};
  const x0=Math.min(...verts.map(v=>Number(v[0])||0)),x1=Math.max(...verts.map(v=>Number(v[0])||0));
  const y0=Math.min(...verts.map(v=>Number(v[1])||0)),y1=Math.max(...verts.map(v=>Number(v[1])||0));
  const z0=Math.min(...verts.map(v=>Number(v[2])||0)),z1=Math.max(...verts.map(v=>Number(v[2])||0));
  return {
    mode:"manual",
    size:{x:Math.max(.05,x1-x0),y:Math.max(.05,y1-y0),z:Math.max(.05,z1-z0)},
    offset:{x:(x0+x1)/2-(Number(pos.x)||0),y:(y0+y1)/2-(Number(pos.y)||0),z:z0-(Number(pos.z)||0)}
  };
}
function convexHull2D(points){
  const pts=[...new Map((points||[]).map(p=>[`${vertexCoord(p[0])},${vertexCoord(p[1])}`,[p[0],p[1]]])).values()].sort((a,b)=>a[0]-b[0]||a[1]-b[1]);
  if(pts.length<=2)return pts;const cross=(o,a,b)=>(a[0]-o[0])*(b[1]-o[1])-(a[1]-o[1])*(b[0]-o[0]);const lo=[];for(const p of pts){while(lo.length>=2&&cross(lo[lo.length-2],lo[lo.length-1],p)<=0)lo.pop();lo.push(p);}const hi=[];for(let i=pts.length-1;i>=0;i--){const p=pts[i];while(hi.length>=2&&cross(hi[hi.length-2],hi[hi.length-1],p)<=0)hi.pop();hi.push(p);}lo.pop();hi.pop();return lo.concat(hi);
}
function pointInPolygon2D(p,poly){let inside=false;for(let i=0,j=poly.length-1;i<poly.length;j=i++){const a=poly[i],b=poly[j];const hit=((a[1]>p[1])!==(b[1]>p[1]))&&(p[0]<(b[0]-a[0])*(p[1]-a[1])/((b[1]-a[1])||1e-9)+a[0]);if(hit)inside=!inside;}return inside;}
function clipPolygonAxis(poly, axis, bound, keepGreater){
  if(!poly?.length)return[];const out=[];
  const inside=p=>keepGreater?p[axis]>=bound-1e-9:p[axis]<=bound+1e-9;
  const intersect=(a,b)=>{const d=b[axis]-a[axis];if(Math.abs(d)<1e-12)return a.slice();const t=(bound-a[axis])/d;return[a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t];};
  for(let i=0;i<poly.length;i++){const a=poly[i],b=poly[(i+1)%poly.length],ia=inside(a),ib=inside(b);if(ia&&ib)out.push(b.slice());else if(ia&&!ib)out.push(intersect(a,b));else if(!ia&&ib){out.push(intersect(a,b));out.push(b.slice());}}
  return out;
}
function polygonArea2D(poly){let a=0;for(let i=0;i<(poly?.length||0);i++){const p=poly[i],q=poly[(i+1)%poly.length];a+=p[0]*q[1]-q[0]*p[1];}return Math.abs(a)*.5;}
function polygonOverlapsCellArea(poly,x,y){
  if(!poly?.length)return false;let c=poly.map(p=>[Number(p[0])||0,Number(p[1])||0]);
  c=clipPolygonAxis(c,0,x,true);c=clipPolygonAxis(c,0,x+1,false);c=clipPolygonAxis(c,1,y,true);c=clipPolygonAxis(c,1,y+1,false);
  return c.length>=3&&polygonArea2D(c)>1e-5;
}
function polygonIntersectsCell(poly,x,y){return polygonOverlapsCellArea(poly,x,y);}
function expandedPartCollisionCells(inst, model) {
  const out=new Map();
  for(const part of model?.parts||[]){
    if(part.visible===false || part.collision===false || part.type==="billboard")continue;
    const local=partCollisionLocalVertices(part);
    const verts=local.map(v=>transformModelVertexForInstance(v,inst,model));
    if(!verts.length)continue;
    const hull=convexHull2D(verts.map(v=>[v[0],v[1]]));
    const x0=Math.floor(Math.min(...verts.map(v=>v[0]))),x1=Math.ceil(Math.max(...verts.map(v=>v[0])))-1;
    const y0=Math.floor(Math.min(...verts.map(v=>v[1]))),y1=Math.ceil(Math.max(...verts.map(v=>v[1])))-1;
    const z0=Math.max(0,Math.min(...verts.map(v=>v[2]))),z1=Math.max(...verts.map(v=>v[2]));
    const mats={top:modelPartFaceMaterial(part,"top"),north:modelPartFaceMaterial(part,"north"),south:modelPartFaceMaterial(part,"south"),east:modelPartFaceMaterial(part,"east"),west:modelPartFaceMaterial(part,"west")};
    for(let y=y0;y<=y1;y++)for(let x=x0;x<=x1;x++){
      if(hull.length>=3&&!polygonIntersectsCell(hull,x,y))continue;
      const key=`${x-(Number(inst?.x)||0)},${y-(Number(inst?.y)||0)}`;
      const prev=out.get(key);const h=Math.max(.05,z1-z0);
      if(!prev||prev.base+prev.height<z1)out.set(key,{x,y,lx:x-(Number(inst?.x)||0),ly:y-(Number(inst?.y)||0),height:h,base:z0,materials:mats,part_id:part.id});
    }
  }
  return out;
}

function normalizeModelCollisionCells(raw){
  if(!Array.isArray(raw))return[];
  return raw.filter(Boolean).map((c,i)=>({
    id:Number(c.id)||(500000+i),x:Math.floor(Number(c.x)||0),y:Math.floor(Number(c.y)||0),
    base:Math.max(0,Number(c.base)||0),height:Math.max(.05,Number(c.height)||.05),
    collision:OBJECT_COLLISIONS.includes(c.collision)?c.collision:"solid",
    model_id:c.model_id!=null?String(c.model_id):"",model_instance_id:Number(c.model_instance_id)||0,part_id:c.part_id!=null?String(c.part_id):""
  })).filter(c=>c.collision!=="none");
}
function compileModelCollisionCells(geo){
  const out=[];let id=500000;
  for(const inst of geo?.model_instances||[]){
    const model=geo?.models?.[inst.model_id];if(!model)continue;
    const collision=OBJECT_COLLISIONS.includes(model.collision)?model.collision:"solid";if(collision==="none")continue;
    for(const c of expandedModelCells(inst,model).values()){
      out.push({id:id++,x:Math.floor(Number(c.x)||0),y:Math.floor(Number(c.y)||0),base:Math.max(0,Number(c.base)||0),height:Math.max(.05,Number(c.height)||.05),collision,model_id:String(model.id||inst.model_id||""),model_instance_id:Number(inst.id)||0,part_id:String(c.part_id||"")});
    }
  }
  geo.model_collision_cells=out;return out;
}

function normalizeMeshFaces(raw) {
  if (!Array.isArray(raw)) return [];
  return raw.filter(Boolean).map((f, i) => ({
    id: Number(f.id) || (400000 + i),
    kind: f.kind === "top" ? "top" : (f.kind === "quad" ? "quad" : "side"),
    surface: ["top","side","billboard"].includes(f.surface) ? f.surface : null,
    edge: ["north","south","east","west"].includes(f.edge) ? f.edge : null,
    vertices: Array.isArray(f.vertices) && f.vertices.length === 4 ? f.vertices.map(v => [Number(v?.[0])||0, Number(v?.[1])||0, Math.max(0,Number(v?.[2])||0)]) : null,
    uv_rect: Array.isArray(f.uv_rect) && f.uv_rect.length === 4 ? f.uv_rect.map(v=>Math.max(0,Math.min(1,Number(v)||0))) : null,
    pattern_uv: Array.isArray(f.pattern_uv) && f.pattern_uv.length === 4 ? f.pattern_uv.map(v=>Number(v)||0) : null,
    x0: Number(f.x0) || 0, y0: Number(f.y0) || 0,
    x1: Number(f.x1) || 0, y1: Number(f.y1) || 0,
    z0: Math.max(0, Number(f.z0) || 0),
    z1: Math.max(0, Number(f.z1) || 0),
    material: f.material && typeof f.material === "object" ? f.material : null,
    material_repeat: f.material_repeat !== false,
    category: String(f.category || "mountain"),
    model_id: f.model_id != null ? String(f.model_id) : "",
    model_instance_id: Number(f.model_instance_id) || 0,
    part_id: f.part_id != null ? String(f.part_id) : "",
    chunk_key: String(f.chunk_key || ""),
  })).filter(f => f.kind === "quad" ? !!f.vertices : (f.kind === "top" ? (f.x1 > f.x0 && f.y1 > f.y0) : (f.z1 > f.z0 && (Math.abs(f.x1-f.x0) > 0 || Math.abs(f.y1-f.y0) > 0))));
}

function materialSignature(mat) {
  if (!mat) return "none";
  const r = mat.src_rect || {};
  return [mat.kind||"", Number(mat.tileset_id)||0, mat.graphic||"", Number(mat.tile_id)||0,
    Number(mat.autotile_tid)||0, Number(mat.autotile_pattern)||0,
    Number(r.x)||0, Number(r.y)||0, Number(r.w)||0, Number(r.h)||0,
    normalizeRotation(mat.rotation), mat.flip_h?1:0, mat.flip_v?1:0,
    Number(mat.hue)||0, mat.saturation==null?100:Number(mat.saturation), Number(mat.lighting)||0].join("|");
}

function deepClone(value) { return value == null ? value : JSON.parse(JSON.stringify(value)); }
function cloneMaterial(mat) { return mat ? deepClone(mat) : null; }

function rotatedEdge(edge, rotation) {
  const order = ["north","east","south","west"];
  const i = order.indexOf(edge); if (i < 0) return edge;
  return order[(i + Math.round(normalizeRotation(rotation)/90)) % 4];
}

function expandedModelCells(inst, model) {
  if (Array.isArray(model?.parts) && model.parts.length) return expandedPartCollisionCells(inst, model);
  const sx = Math.max(1, Math.round(Number(inst.scale_x)||1));
  const sy = Math.max(1, Math.round(Number(inst.scale_y)||1));
  const hs = Math.max(.25, Number(inst.height_scale)||1);
  const rot = normalizeRotation(inst.rotation);
  const baseW = Math.max(1, model.width * sx), baseH = Math.max(1, model.height * sy);
  const out = new Map();
  for (const [key, cell] of Object.entries(model.cells || {})) {
    if (!cell || cell.enabled === false) continue;
    const [cx,cy] = key.split(',').map(Number);
    const localMats = {};
    for (const edge of ["top","north","south","east","west"]) localMats[edge] = modelMaterialForCell(model, cell, edge);
    const worldMats = { top: cloneMaterial(localMats.top), north:null, south:null, east:null, west:null };
    for (const edge of ["north","south","east","west"]) worldMats[rotatedEdge(edge, rot)] = cloneMaterial(localMats[edge]);
    for (let yy=0; yy<sy; yy++) for (let xx=0; xx<sx; xx++) {
      const lx = cx*sx+xx, ly = cy*sy+yy;
      let rx=lx, ry=ly;
      if (rot===90) { rx=baseH-1-ly; ry=lx; }
      else if (rot===180) { rx=baseW-1-lx; ry=baseH-1-ly; }
      else if (rot===270) { rx=ly; ry=baseW-1-lx; }
      out.set(`${rx},${ry}`, {
        x: (Number(inst.x)||0) + rx, y: (Number(inst.y)||0) + ry,
        lx:rx, ly:ry,
        height: Math.max(.25, Number(cell.height || model.default_height || 2) * hs),
        base: Math.max(0, Number(cell.anchor_z)||0) * hs,
        materials: worldMats,
      });
    }
  }
  return out;
}

function greedyTopRects(cells) {
  const remaining = new Set(cells.keys()), out=[];
  while (remaining.size) {
    const first=[...remaining][0], c0=cells.get(first); if(!c0){remaining.delete(first);continue;}
    const sig = `${c0.base}|${c0.height}|${materialSignature(c0.materials.top)}`;
    let w=1;
    while (true) {
      const c=cells.get(`${c0.lx+w},${c0.ly}`);
      if (!c || !remaining.has(`${c0.lx+w},${c0.ly}`) || `${c.base}|${c.height}|${materialSignature(c.materials.top)}`!==sig) break;
      w++;
    }
    let h=1;
    outer: while (true) {
      for(let xx=0;xx<w;xx++){
        const k=`${c0.lx+xx},${c0.ly+h}`, c=cells.get(k);
        if(!c || !remaining.has(k) || `${c.base}|${c.height}|${materialSignature(c.materials.top)}`!==sig) break outer;
      }
      h++;
    }
    for(let yy=0;yy<h;yy++)for(let xx=0;xx<w;xx++)remaining.delete(`${c0.lx+xx},${c0.ly+yy}`);
    out.push({x0:c0.x,y0:c0.y,x1:c0.x+w,y1:c0.y+h,z:c0.base+c0.height,material:cloneMaterial(c0.materials.top)});
  }
  return out;
}

function modelMeshFacesForInstance(inst, model, startId=400000) {
  if (Array.isArray(model?.parts) && model.parts.length) return modelPartMeshFacesForInstance(inst, model, startId);
  const cells=expandedModelCells(inst,model), faces=[], tops=greedyTopRects(cells); let id=startId;
  for(const r of tops) faces.push({id:id++,kind:"top",x0:r.x0,y0:r.y0,x1:r.x1,y1:r.y1,z0:r.z,z1:r.z,material:r.material,material_repeat:true,category:model.category||"mountain",model_id:model.id,model_instance_id:inst.id,chunk_key:`${Math.floor(r.x0/8)},${Math.floor(r.y0/8)}`});
  const segments=[];
  const dirs={north:[0,-1],south:[0,1],east:[1,0],west:[-1,0]};
  for(const c of cells.values()){
    const top=c.base+c.height;
    for(const [edge,[dx,dy]] of Object.entries(dirs)){
      const n=cells.get(`${c.lx+dx},${c.ly+dy}`);
      const nTop=n ? n.base+n.height : -Infinity;
      if(n && nTop>=top-1e-6) continue;
      const z0=Math.max(c.base, n ? nTop : c.base), z1=top;
      if(z1<=z0+1e-6) continue;
      let x0=c.x,y0=c.y,x1=c.x+1,y1=c.y+1;
      if(edge==="north") y1=y0;
      else if(edge==="south") y0=y1;
      else if(edge==="west") x1=x0;
      else if(edge==="east") x0=x1;
      segments.push({edge,x0,y0,x1,y1,z0,z1,material:cloneMaterial(c.materials[edge]),sig:`${edge}|${z0}|${z1}|${materialSignature(c.materials[edge])}`});
    }
  }
  // Merge collinear neighbouring side segments with identical height/material.
  const used=new Set();
  for(let i=0;i<segments.length;i++){
    if(used.has(i))continue; const a={...segments[i]}; used.add(i);
    let changed=true;
    while(changed){changed=false;for(let j=0;j<segments.length;j++){
      if(used.has(j))continue;const b=segments[j];if(b.sig!==a.sig)continue;
      if((a.edge==="north"||a.edge==="south") && Math.abs(a.y0-b.y0)<1e-6 && Math.abs(a.y1-b.y1)<1e-6){
        if(Math.abs(a.x1-b.x0)<1e-6){a.x1=b.x1;used.add(j);changed=true;break;}
        if(Math.abs(b.x1-a.x0)<1e-6){a.x0=b.x0;used.add(j);changed=true;break;}
      } else if((a.edge==="east"||a.edge==="west") && Math.abs(a.x0-b.x0)<1e-6 && Math.abs(a.x1-b.x1)<1e-6){
        if(Math.abs(a.y1-b.y0)<1e-6){a.y1=b.y1;used.add(j);changed=true;break;}
        if(Math.abs(b.y1-a.y0)<1e-6){a.y0=b.y0;used.add(j);changed=true;break;}
      }
    }}
    faces.push({id:id++,kind:"side",edge:a.edge,x0:a.x0,y0:a.y0,x1:a.x1,y1:a.y1,z0:a.z0,z1:a.z1,material:a.material,material_repeat:true,category:model.category||"mountain",model_id:model.id,model_instance_id:inst.id,chunk_key:`${Math.floor(Math.min(a.x0,a.x1)/8)},${Math.floor(Math.min(a.y0,a.y1)/8)}`});
  }
  return {faces,nextId:id,cells};
}

function normalizeModelTemplate(raw, id = "model") {
  const w = Math.max(1, Math.min(64, Math.round(Number(raw?.width) || 4)));
  const h = Math.max(1, Math.min(64, Math.round(Number(raw?.height) || 4)));
  const cells = {};
  const input = raw?.cells && typeof raw.cells === "object" ? raw.cells : {};
  for (const [key, val] of Object.entries(input)) {
    const m = /^(\d+),(\d+)$/.exec(key); if (!m) continue;
    const x = Number(m[1]), y = Number(m[2]);
    if (x < 0 || y < 0 || x >= w || y >= h) continue;
    const cell=normalizeLegacyGeometryCell(val, raw?.default_height ?? 2);
    if(cell.enabled!==false)cells[key]=cell;
  }
  const parts=normalizeModelParts(raw?.parts);
  const explicitEmpty = raw?.allow_empty === true || Number(raw?.builder_version) >= 3 || Array.isArray(raw?.parts);
  if (!Object.keys(cells).length && !parts.length && !explicitEmpty) {
    for (let y=0;y<h;y++) for(let x=0;x<w;x++) cells[`${x},${y}`] = normalizeLegacyGeometryCell({enabled:true,height:Math.max(.25,Number(raw?.default_height)||2)}, Number(raw?.default_height)||2);
  }
  return {
    id: String(raw?.id || id),
    name: String(raw?.name || "Modelo"),
    category: String(raw?.category || "mountain"),
    width: w, height: h,
    default_height: Math.max(.25, Number(raw?.default_height) || 2),
    collision: OBJECT_COLLISIONS.includes(raw?.collision) ? raw.collision : "solid",
    connect_neighbors: raw?.connect_neighbors !== false,
    face_materials: normalizeFaceMaterialMap(raw?.face_materials),
    builder_version: Math.max(3, Number(raw?.builder_version)||0),
    runtime_quality: raw?.runtime_quality === "original" ? "original" : "pixel-low",
    external_link: raw?.external_link && typeof raw.external_link === "object" ? deepClone(raw.external_link) : null,
    parts,
    cells,
  };
}

function normalizeModels(raw) {
  const out = {};
  if (!raw || typeof raw !== "object") return out;
  for (const [id, model] of Object.entries(raw)) out[id] = normalizeModelTemplate(model, id);
  return out;
}

function normalizeModelInstances(raw) {
  if (!Array.isArray(raw)) return [];
  return raw.filter(Boolean).map((r, i) => ({
    id: Number(r.id) || (i + 1),
    model_id: String(r.model_id || r.modelId || ""),
    x: Math.round(Number(r.x) || 0), y: Math.round(Number(r.y) || 0),
    scale_x: Math.max(1, Math.min(8, Math.round(Number(r.scale_x) || 1))),
    scale_y: Math.max(1, Math.min(8, Math.round(Number(r.scale_y) || 1))),
    height_scale: Math.max(.25, Math.min(8, Number(r.height_scale) || 1)),
    rotation: normalizeModelPlacementRotation(r.rotation),
  })).filter(r => r.model_id);
}

function modelMaterialForCell(model, cell, edge) {
  const local = cell?.face_materials?.[edge];
  if (local) return JSON.parse(JSON.stringify(local));
  const shared = model?.face_materials?.[edge];
  if (shared) return JSON.parse(JSON.stringify(shared));
  if (edge !== "top") {
    const fallback = model?.face_materials?.south || model?.face_materials?.north || model?.face_materials?.east || model?.face_materials?.west;
    if (fallback) return JSON.parse(JSON.stringify(fallback));
  }
  return model?.face_materials?.top ? JSON.parse(JSON.stringify(model.face_materials.top)) : null;
}

function buildModelInstanceObjects(geo, inst, model, startId = 300000) {
  // One lightweight editor proxy per placed model. Exact gameplay collision is
  // compiled separately into model_collision_cells and visual rendering uses
  // mesh_faces. The old per-collision-cell proxy array was extremely costly on
  // large maps/models and was rebuilt every time the editor opened.
  let x0=Number(inst?.x)||0, y0=Number(inst?.y)||0, x1=x0+1, y1=y0+1, z0=0, z1=1;
  let faceMaterials=normalizeFaceMaterialMap(null), material=null;
  const hasParts=Array.isArray(model?.parts)&&model.parts.length>0;
  if(hasParts){
    const b=modelPartBounds(model);
    const corners=[
      [b.x0,b.y0,b.z0],[b.x1,b.y0,b.z0],[b.x1,b.y1,b.z0],[b.x0,b.y1,b.z0],
      [b.x0,b.y0,b.z1],[b.x1,b.y0,b.z1],[b.x1,b.y1,b.z1],[b.x0,b.y1,b.z1],
    ].map(v=>transformModelVertexForInstance(v,inst,model));
    x0=Math.min(...corners.map(v=>v[0])); y0=Math.min(...corners.map(v=>v[1]));
    x1=Math.max(...corners.map(v=>v[0])); y1=Math.max(...corners.map(v=>v[1]));
    z0=Math.min(...corners.map(v=>v[2])); z1=Math.max(...corners.map(v=>v[2]));
    const first=(model.parts||[]).find(p=>p&&p.visible!==false);
    if(first){
      faceMaterials=normalizeFaceMaterialMap({
        top:modelPartFaceMaterial(first,'top'),north:modelPartFaceMaterial(first,'north'),
        south:modelPartFaceMaterial(first,'south'),east:modelPartFaceMaterial(first,'east'),west:modelPartFaceMaterial(first,'west')
      });
      material=faceMaterials.top||faceMaterials.south||faceMaterials.north||first.material||null;
    }
  }else{
    const cells=expandedModelCells(inst,model);
    if(cells.size){
      const arr=[...cells.values()];
      x0=Math.min(...arr.map(c=>c.x)); y0=Math.min(...arr.map(c=>c.y));
      x1=Math.max(...arr.map(c=>c.x+1)); y1=Math.max(...arr.map(c=>c.y+1));
      z0=Math.min(...arr.map(c=>c.base)); z1=Math.max(...arr.map(c=>c.base+c.height));
      const c=arr[0]; faceMaterials=normalizeFaceMaterialMap(c.materials||null);
      material=faceMaterials.top||faceMaterials.south||null;
    }
  }
  const gx=Math.floor(x0), gy=Math.floor(y0), gw=Math.max(1,Math.ceil(x1)-gx), gh=Math.max(1,Math.ceil(y1)-gy);
  const obj=normalizeObject({id:startId,name:`${model.name} ${inst.id}`,model_instance_id:inst.id,model_id:model.id,compiled:true,render:false,
    type:'cube',x:gx,y:gy,w:gw,h:gh,height:Math.max(.01,z1-z0),anchor_z:Math.max(0,z0),anchor_row:0,rotation:0,
    collision:'none',category:model.category||'mountain',characters_in_front:false,footprint:{},
    components:{extrude:false,cap:false,connect_neighbors:false,slope:false,billboard:false,occlusion:'auto'},
    material,face_materials:faceMaterials},startId);
  return {objects:[obj],nextId:startId+1,cells:null};
}

function rebuildModelMeshFaces(geo, onlyModelId=null) {
  if(!geo)return [];
  // Terrain planes are a separate compiler product and must never be erased by
  // rebuilding Model Studio instances. Older builds used mesh_faces as one bag.
  const keep = (geo.mesh_faces||[]).filter(f => {
    if (f?.terrain_generated === true || String(f?.part_id||"") === "__terrain__") return true;
    return onlyModelId ? String(f.model_id)!==String(onlyModelId) : false;
  });
  let id=Math.max(400000,...keep.map(f=>Number(f.id)||0))+1, fresh=[], cellCount=0;
  for(const inst of geo.model_instances||[]){
    if(onlyModelId && String(inst.model_id)!==String(onlyModelId))continue;
    const model=geo.models?.[inst.model_id];if(!model)continue;
    const built=modelMeshFacesForInstance(inst,model,id);fresh.push(...built.faces);id=built.nextId;cellCount+=built.cells.size;
  }
  geo.mesh_faces=[...keep,...fresh];
  const faces=geo.mesh_faces||[];
  geo.mesh_compiler={version:1,last_build:new Date().toISOString(),stats:{cells:cellCount,faces:faces.length,top_faces:faces.filter(f=>f.kind==="top").length,side_faces:faces.filter(f=>f.kind==="side").length}};
  return fresh;
}


function modelFaceGeometryKey(f) {
  if(!Array.isArray(f?.vertices)||f.vertices.length!==4)return null;
  const pts=f.vertices.map(v=>(v||[]).map(n=>Math.round((Number(n)||0)*10000)/10000).join(',')).sort();
  return pts.join('|');
}

function modelFaceNormal(f){
  const v=f?.vertices;if(!Array.isArray(v)||v.length!==4)return[0,0,0];
  const a=v[0],b=v[1],c=v[2],ux=(b[0]-a[0]),uy=(b[1]-a[1]),uz=(b[2]-a[2]),vx=(c[0]-a[0]),vy=(c[1]-a[1]),vz=(c[2]-a[2]);
  return[uy*vz-uz*vy,uz*vx-ux*vz,ux*vy-uy*vx];
}
function axisAlignedModelFaceRect(f){
  if(!Array.isArray(f?.vertices)||f.vertices.length!==4||f.material_repeat===false)return null;
  // UV-authored/custom faces stay untouched. This optimizer is for generated
  // pixel-repeat surfaces where joining rectangles cannot destroy a UV layout.
  if(Number.isInteger(f.custom_face_index))return null;
  const eps=1e-5,vs=f.vertices.map(v=>v.map(n=>Number(n)||0)),same=(axis)=>Math.max(...vs.map(v=>v[axis]))-Math.min(...vs.map(v=>v[axis]))<eps;
  let axis,uAxis,vAxis;
  if(same(2)){axis='z';uAxis=0;vAxis=1;}else if(same(0)){axis='x';uAxis=1;vAxis=2;}else if(same(1)){axis='y';uAxis=0;vAxis=2;}else return null;
  const n=modelFaceNormal(f),normalSign=axis==='x'?Math.sign(n[0]):axis==='y'?Math.sign(n[1]):Math.sign(n[2]);
  const plane=axis==='x'?vs[0][0]:axis==='y'?vs[0][1]:vs[0][2],us=vs.map(v=>v[uAxis]),vv=vs.map(v=>v[vAxis]);
  const u0=Math.min(...us),u1=Math.max(...us),v0=Math.min(...vv),v1=Math.max(...vv);if(u1-u0<eps||v1-v0<eps)return null;
  return{axis,plane,u0,u1,v0,v1,normalSign:normalSign||1,face:f};
}
function mergedModelFaceFromRect(r,id){
  const {axis,plane,u0,u1,v0,v1,normalSign}=r;let verts;
  if(axis==='z')verts=[[u0,v0,plane],[u1,v0,plane],[u1,v1,plane],[u0,v1,plane]];
  else if(axis==='x')verts=[[plane,u0,v0],[plane,u1,v0],[plane,u1,v1],[plane,u0,v1]];
  else verts=[[u0,plane,v0],[u1,plane,v0],[u1,plane,v1],[u0,plane,v1]]; // base normal = -Y
  const baseSign=axis==='y'?-1:1;if(normalSign!==baseSign)verts=[verts[0],verts[3],verts[2],verts[1]];
  const xs=verts.map(v=>v[0]),ys=verts.map(v=>v[1]),zs=verts.map(v=>v[2]),f=r.face;
  return{...f,id,vertices:verts,uv_rect:null,pattern_uv:[0,0,u1-u0,v1-v0],x0:Math.min(...xs),y0:Math.min(...ys),x1:Math.max(...xs),y1:Math.max(...ys),z0:Math.min(...zs),z1:Math.max(...zs),chunk_key:`${Math.floor(Math.min(...xs)/8)},${Math.floor(Math.min(...ys)/8)}`};
}
function mergeCoplanarModelFaces(faces,startId){
  const passthrough=[],groups=new Map();let id=startId,mergedAway=0;
  for(const f of faces){const r=axisAlignedModelFaceRect(f);if(!r){passthrough.push(f);continue;}const k=[f.model_instance_id,r.axis,Math.round(r.plane*100000),r.normalSign,materialSignature(f.material),f.category||'',f.surface||'',f.edge||''].join('|');if(!groups.has(k))groups.set(k,[]);groups.get(k).push(r);}
  const out=[...passthrough];
  const eq=(a,b)=>Math.abs(a-b)<1e-5;
  for(const list0 of groups.values()){
    const list=list0.map(r=>({...r}));let changed=true;
    // Repeated full-edge joining. Model Studio props are deliberately tiny, so
    // this O(n²) authoring-time pass is preferable to carrying extra quads at runtime.
    while(changed){changed=false;outer:for(let i=0;i<list.length;i++)for(let j=i+1;j<list.length;j++){const a=list[i],b=list[j];let n=null;
      if(eq(a.v0,b.v0)&&eq(a.v1,b.v1)&&(eq(a.u1,b.u0)||eq(b.u1,a.u0)))n={...a,u0:Math.min(a.u0,b.u0),u1:Math.max(a.u1,b.u1)};
      else if(eq(a.u0,b.u0)&&eq(a.u1,b.u1)&&(eq(a.v1,b.v0)||eq(b.v1,a.v0)))n={...a,v0:Math.min(a.v0,b.v0),v1:Math.max(a.v1,b.v1)};
      if(n){list.splice(j,1);list.splice(i,1,n);mergedAway++;changed=true;break outer;}
    }}
    for(const r of list)out.push(mergedModelFaceFromRect(r,id++));
  }
  return{faces:out,mergedAway,nextId:id};
}

function optimizeModelMeshFaces(geo) {
  if(!geo?.mesh_faces)return {removed:0,merged:0};
  const terrain=[], candidates=[];
  for(const f of geo.mesh_faces){if(f?.terrain_generated===true||String(f?.part_id||'')==='__terrain__')terrain.push(f);else candidates.push(f);}
  const groups=new Map(); const keep=[]; let removed=0;
  for(const f of candidates){
    const model=geo.models?.[f.model_id];
    if(model?.runtime_quality==='original'){keep.push(f);continue;}
    const key=modelFaceGeometryKey(f);
    if(!key){keep.push(f);continue;}
    const gkey=`${f.model_instance_id}|${key}`;
    if(!groups.has(gkey))groups.set(gkey,[]);groups.get(gkey).push(f);
  }
  for(const arr of groups.values()){
    // Exact coincident quads from two different parts are internal seams.
    const partIds=new Set(arr.map(f=>String(f.part_id||'')));
    if(arr.length>=2&&partIds.size>=2){removed+=arr.length;continue;}
    keep.push(...arr);
  }
  const original=[],pixel=[];for(const f of keep){const model=geo.models?.[f.model_id];(model?.runtime_quality==='original'?original:pixel).push(f);}
  const maxId=Math.max(450000,...terrain.map(f=>Number(f.id)||0),...original.map(f=>Number(f.id)||0));
  const merged=mergeCoplanarModelFaces(pixel,maxId+1);
  geo.mesh_faces=[...terrain,...original,...merged.faces];
  geo.mesh_compiler ||= {version:1,stats:{}};
  geo.mesh_compiler.optimizer={mode:'pixel-low',removed_internal_faces:removed,merged_coplanar_faces:merged.mergedAway,faces_after:geo.mesh_faces.length};
  return {removed,merged:merged.mergedAway};
}

function compileModelObjects(geo) {
  if (!geo) return [];
  const out=[]; let oid=300000;
  for(const inst of geo.model_instances||[]){const model=geo.models?.[inst.model_id];if(!model)continue;const built=buildModelInstanceObjects(geo,inst,model,oid);out.push(...built.objects);oid=built.nextId;}
  geo.model_objects=out;
  compileModelCollisionCells(geo);
  rebuildModelMeshFaces(geo);
  optimizeModelMeshFaces(geo);
  return out;
}

function compileModelTemplateInstances(geo, modelId) {
  if (!geo || !modelId) return [];
  const keep=(geo.model_objects||[]).filter(o=>String(o?.model_id)!==String(modelId));
  let oid=Math.max(300000,...keep.map(o=>Number(o.id)||0))+1;const fresh=[];const model=geo.models?.[modelId];
  if(model){for(const inst of geo.model_instances||[]){if(String(inst.model_id)!==String(modelId))continue;const built=buildModelInstanceObjects(geo,inst,model,oid);fresh.push(...built.objects);oid=built.nextId;}}
  geo.model_objects=[...keep,...fresh];
  compileModelCollisionCells(geo);
  rebuildModelMeshFaces(geo,modelId);
  return fresh;
}

function normalizeGeometry(mapId, info, raw) {
  const out = newGeometry(mapId, info);
  if (raw && typeof raw === "object") {
    out.format = Number(raw.format) || FORMAT;
    out.map_id = mapId;
    out.width = info?.width ?? Number(raw.width) ?? 0;
    out.height = info?.height ?? Number(raw.height) ?? 0;
    out.height_step = Number(raw.height_step) || DEFAULT_STEP;
    out.inherit_legacy = raw.inherit_legacy !== false;
    out.cells = raw.cells && typeof raw.cells === "object" ? raw.cells : {};
    out.ramps = Array.isArray(raw.ramps) ? raw.ramps : [];
    out.terrain_cells = normalizeTerrainCells(raw.terrain_cells);
    out.objects = normalizeObjects(raw.objects);
    out.definitions = normalizeSourceDefinitions(raw.definitions);
    out.instance_overrides = normalizeInstanceOverrides(raw.instance_overrides);
    out.compiled_objects = normalizeObjects(raw.compiled_objects).map((o) => ({ ...o, compiled: true }));
    out.models = normalizeModels(raw.models);
    out.model_instances = normalizeModelInstances(raw.model_instances);
    out.model_objects = normalizeObjects(raw.model_objects).map((o) => ({ ...o, compiled: true }));
    out.model_collision_cells = normalizeModelCollisionCells(raw.model_collision_cells);
    out.mesh_faces = normalizeMeshFaces(raw.mesh_faces);
    out.mesh_compiler = raw.mesh_compiler && typeof raw.mesh_compiler === "object" ? raw.mesh_compiler : out.mesh_compiler;
    compileModelObjects(out);
    out.compiler = normalizeCompilerMeta(raw.compiler, out);
    out.editor_preview = raw.editor_preview && typeof raw.editor_preview === "object"
      ? raw.editor_preview
      : out.editor_preview;
    // Keep future fields so this alpha does not destroy later metadata.
    for (const [k, v] of Object.entries(raw)) {
      if (!(k in out)) out[k] = v;
    }
  }
  return out;
}

function applyPreviewPrefsFromGeometry(geo) {
  const p = geo?.editor_preview || {};
  if (Number.isFinite(Number(p.angle))) state.preview.angle = Math.max(5, Math.min(70, Number(p.angle)));
  if (Number.isFinite(Number(p.yaw))) state.preview.yaw = ((Number(p.yaw) % 360) + 360) % 360;
  if (Number.isFinite(Number(p.zoom))) state.preview.zoom = Math.max(0.45, Math.min(2.5, Number(p.zoom)));
  if (Number.isFinite(Number(p.radius))) state.preview.radius = Math.max(5, Math.min(30, Math.round(Number(p.radius))));
  if (Number.isFinite(Number(p.focus_x))) state.preview.focusX = Number(p.focus_x);
  if (Number.isFinite(Number(p.focus_y))) state.preview.focusY = Number(p.focus_y);
  if (p.cliff_source && typeof p.cliff_source === "object") state.preview.cliffSource = p.cliff_source;
  if (p.full_map != null) state.preview.fullMap = !!p.full_map;
  if (p.show_events != null) state.preview.showEvents = !!p.show_events;
  if (p.show_tags != null) state.preview.showTags = !!p.show_tags;
}

function persistPreviewPrefs(geo) {
  if (!geo) return;
  geo.editor_preview = {
    ...(geo.editor_preview || {}),
    angle: state.preview.angle,
    yaw: state.preview.yaw,
    zoom: state.preview.zoom,
    radius: state.preview.radius,
    focus_x: state.preview.focusX,
    focus_y: state.preview.focusY,
    cliff_source: state.preview.cliffSource || null,
    full_map: !!state.preview.fullMap,
    show_events: !!state.preview.showEvents,
    show_tags: !!state.preview.showTags,
  };
}

function cellKey(x, y) {
  return `${x},${y}`;
}

function cellCacheKey(mapId, x, y) {
  return `${mapId}:${x},${y}`;
}

// Canvas pool for composeGroundSource – avoids per-cell createElement overhead.
function getCanvas(w, h) {
  const c = state.preview.canvasPool.pop() || document.createElement("canvas");
  c.width = w; c.height = h; return c;
}
function releaseCanvas(c) {
  if (state.preview.canvasPool.length < 50) state.preview.canvasPool.push(c);
}

// Incremental legacy height update: only recalculate (x,y) and its 4 neighbours.
function updateLegacyHeightForCell(ctx, mapId, x, y) {
  const info = ctx.map.info(mapId);
  if (!info) return;
  const height = state.legacyHeights.get(mapId);
  if (!height) return;
  const storedLayers = state.legacyHeightLayers?.get(mapId);
  const layers = storedLayers || visibleLayers(ctx, mapId);
  const tagAt = (tx, ty) => {
    if (tx < 0 || ty < 0 || tx >= info.width || ty >= info.height) return [];
    return mapCellTags(ctx, mapId, tx, ty, layers, mapTilesetId(info, mapId));
  };
  const hasTag = (tx, ty, tag) => tagAt(tx, ty).includes(tag);
  // Recalculate the cell and its 4 neighbours.
  const cells = [[x, y], [x - 1, y], [x + 1, y], [x, y - 1], [x, y + 1]];
  for (const [cx, cy] of cells) {
    if (cx < 0 || cy < 0 || cx >= info.width || cy >= info.height) continue;
    const key = cellKey(cx, cy);
    const ts = tagAt(cx, cy);
    let h = 0;
    if (ts.includes(TAG.VOLUME)) h = Math.max(h, runtimeConfig.volumeDefaultHeight);
    if (ts.includes(TAG.VOLUME_HIGH)) h = Math.max(h, runtimeConfig.volumeHighHeight);
    // MountainTop component: check if this cell is part of a connected top.
    if (hasTag(cx, cy, TAG.MOUNTAIN_TOP)) {
      let levels = 0;
      let wy = cy + 1;
      while (wy < info.height && (hasTag(cx, wy, TAG.MOUNTAIN_WALL) || hasTag(cx, wy, TAG.MOUNTAIN_WALL_PLANE))) {
        levels++; wy++;
      }
      levels = Math.max(1, levels);
      h = Math.max(h, levels * runtimeConfig.mountainHeight);
    }
    if (h > 0) height.set(key, h); else height.delete(key);
  }
}

// Invalidate cellEntryCache for a cell and its 4 neighbours.
function invalidateCellCache(mapId, x, y) {
  const cache = state.preview.cellEntryCache;
  if (!cache || cache.size === 0) return;
  for (const [cx, cy] of [[x, y], [x - 1, y], [x + 1, y], [x, y - 1], [x, y + 1]]) {
    cache.delete(cellCacheKey(mapId, cx, cy));
  }
}

// Trim cellEntryCache to max 5000 entries (simple FIFO eviction).
function trimCellEntryCache() {
  const cache = state.preview.cellEntryCache;
  if (cache.size <= 5000) return;
  const keys = cache.keys();
  let toDelete = cache.size - 5000;
  for (let i = 0; i < toDelete; i++) {
    const next = keys.next();
    if (next.done) break;
    cache.delete(next.value);
  }
}

function cellLevel(geo, x, y) {
  const cell = geo?.cells?.[cellKey(x, y)];
  if (cell == null) return 0;
  if (typeof cell === "number") return Number(cell) || 0;
  if (typeof cell === "object") {
    if (cell.height != null) {
      const step = Number(geo.height_step) || DEFAULT_STEP;
      return Math.round((Number(cell.height) || 0) / step);
    }
    return Number(cell.level) || 0;
  }
  return 0;
}

function cellHeight(geo, x, y) {
  return cellLevel(geo, x, y) * (Number(geo?.height_step) || DEFAULT_STEP);
}


function normalizeTerrainCells(raw) {
  const out = {};
  if (!raw || typeof raw !== "object") return out;
  for (const [key, value] of Object.entries(raw)) {
    if (!/^\-?\d+,\-?\d+$/.test(String(key))) continue;
    const src = Array.isArray(value) ? value : value?.corners;
    if (!Array.isArray(src) || src.length !== 4) continue;
    const corners = src.map(v => Math.max(0, Number(v) || 0));
    out[key] = { corners, material: value?.material && typeof value.material === "object" ? deepClone(value.material) : null };
  }
  return out;
}

function terrainCellAt(geo, x, y) {
  return geo?.terrain_cells?.[cellKey(x, y)] || null;
}

function terrainCellCenterLevel(geo, x, y) {
  const tc = terrainCellAt(geo, x, y);
  if (!tc || !Array.isArray(tc.corners) || tc.corners.length !== 4) return null;
  return tc.corners.reduce((a,b)=>a+(Number(b)||0),0) / 4;
}

function terrainPlaneCoefficients(x, y, corners) {
  const [nw, ne, se, sw] = (corners || [0,0,0,0]).map(v => Number(v) || 0);
  const ax = ne - nw;
  const by = sw - nw;
  // A legal planar cell satisfies SE = NW + ax + by. Snap tiny authoring noise.
  const expected = nw + ax + by;
  const planar = Math.abs(expected - se) <= 0.002;
  const c = nw - ax * x - by * y;
  return { a: ax, b: by, c, planar, nw, ne, se, sw };
}

function terrainLevelAtPoint(plane, x, y) {
  return Math.max(0, plane.a * x + plane.b * y + plane.c);
}

function terrainBrushRect(ctx, geo, cx, cy) {
  const brush = Math.max(1, Math.round(Number(ctx.editor.brushSize?.()) || 1));
  const half = Math.floor((brush - 1) / 2);
  const x0 = Math.max(0, cx - half), y0 = Math.max(0, cy - half);
  const x1 = Math.min(Number(geo.width)||0, x0 + brush), y1 = Math.min(Number(geo.height)||0, y0 + brush);
  return { x0, y0, x1, y1, w: Math.max(0,x1-x0), h: Math.max(0,y1-y0) };
}

function clampTerrainSelection(geo, sel) {
  if (!geo || !sel) return null;
  const x0=Math.max(0,Math.min(Number(geo.width)-1,Math.min(Number(sel.x0),Number(sel.x1))));
  const y0=Math.max(0,Math.min(Number(geo.height)-1,Math.min(Number(sel.y0),Number(sel.y1))));
  const x1=Math.max(0,Math.min(Number(geo.width)-1,Math.max(Number(sel.x0),Number(sel.x1))));
  const y1=Math.max(0,Math.min(Number(geo.height)-1,Math.max(Number(sel.y0),Number(sel.y1))));
  return { mapId:Number(sel.mapId), x0, y0, x1, y1, w:x1-x0+1, h:y1-y0+1 };
}

function currentTerrainSelection(ctx, geo=currentGeo(ctx)) {
  const mapId=ctx?.editor?.activeMapId?.();
  if (mapId==null || !geo || !state.terrainSelection || Number(state.terrainSelection.mapId)!==Number(mapId)) return null;
  return clampTerrainSelection(geo,state.terrainSelection);
}

function setTerrainSelection(ctx,mapId,x0,y0,x1=x0,y1=y0) {
  const geo=state.maps.get(mapId); if(!geo)return null;
  const sel=clampTerrainSelection(geo,{mapId,x0,y0,x1,y1});
  state.terrainSelection=sel;
  if(sel){
    const step=Math.max(.001,Number(geo.height_step)||DEFAULT_STEP);
    const c=terrainCellCenterLevel(geo,sel.x0,sel.y0);
    state.terrainTargetHeight=c==null?Math.max(0,effectiveHeight(geo,mapId,sel.x0,sel.y0)/step):c;
    state.preview.focusX=Math.round((sel.x0+sel.x1)/2);
    state.preview.focusY=Math.round((sel.y0+sel.y1)/2);
  }
  schedulePanelRefresh();
  ctx.editor.requestRedraw();
  return sel;
}

function terrainSelectionCells(ctx,geo=currentGeo(ctx)) {
  const sel=currentTerrainSelection(ctx,geo); if(!sel)return [];
  const out=[]; for(let y=sel.y0;y<=sel.y1;y++)for(let x=sel.x0;x<=sel.x1;x++)out.push([x,y]);
  return out;
}

function terrainSelectionStats(ctx,geo=currentGeo(ctx)) {
  const mapId=ctx?.editor?.activeMapId?.(); const sel=currentTerrainSelection(ctx,geo);
  if(mapId==null||!geo||!sel)return null;
  const step=Math.max(.001,Number(geo.height_step)||DEFAULT_STEP);
  const values=[];
  for(const [x,y] of terrainSelectionCells(ctx,geo)){
    const c=terrainCellCenterLevel(geo,x,y);
    values.push(c==null?Math.max(0,effectiveHeight(geo,mapId,x,y)/step):c);
  }
  const avg=values.length?values.reduce((a,b)=>a+b,0)/values.length:0;
  return { ...sel, count:values.length, avg, min:values.length?Math.min(...values):0, max:values.length?Math.max(...values):0 };
}

function setTerrainHeightInBounds(ctx,mapId,sel,height) {
  const geo=state.maps.get(mapId); if(!geo||!sel)return false; geo.terrain_cells||={};
  const h=Math.max(0,Number(height)||0); let changed=false;
  for(let y=sel.y0;y<=sel.y1;y++)for(let x=sel.x0;x<=sel.x1;x++){
    const tc=terrainCellAt(geo,x,y); const next={...(tc||{}),corners:[h,h,h,h]};
    geo.terrain_cells[cellKey(x,y)]=next; changed=true;
  }
  if(changed){geo._terrain_dirty=true;state.terrainTargetHeight=h;void finishSimpleSceneEdit(ctx,mapId,'terrain-set-height');}
  return changed;
}

function setTerrainCornersAt(ctx,mapId,x,y,corners) {
  const geo=state.maps.get(mapId); if(!geo)return false; geo.terrain_cells||={};
  const c=(corners||[]).map(v=>Math.max(0,Number(v)||0)); if(c.length!==4)return false;
  const tc=terrainCellAt(geo,x,y); geo.terrain_cells[cellKey(x,y)]={...(tc||{}),corners:c};
  geo._terrain_dirty=true; state.terrainTargetHeight=c.reduce((a,b)=>a+b,0)/4;
  void finishSimpleSceneEdit(ctx,mapId,'terrain-corners'); return true;
}

function eraseTerrainBounds(ctx,mapId,sel) {
  const geo=state.maps.get(mapId); if(!geo||!sel)return false; let changed=false;
  geo.terrain_cells ||= {}; geo.cells ||= {};
  for(let y=sel.y0;y<=sel.y1;y++)for(let x=sel.x0;x<=sel.x1;x++){
    const k=cellKey(x,y);
    if(k in geo.terrain_cells){delete geo.terrain_cells[k];changed=true;}
    // V4 clean erase also removes the obsolete explicit-cell channel. This is
    // why a deleted tile can never reveal a second hidden Geometry height.
    if(k in geo.cells){delete geo.cells[k];changed=true;}
  }
  const overlaps=(o)=>{const x=Number(o?.x)||0,y=Number(o?.y)||0,w=Math.max(1,Number(o?.width||o?.w)||1),h=Math.max(1,Number(o?.height||o?.h)||1);return !(x+w-1<sel.x0||x>sel.x1||y+h-1<sel.y0||y>sel.y1);};
  if(Array.isArray(geo.ramps)){const n=geo.ramps.filter(r=>!overlaps(r));if(n.length!==geo.ramps.length){geo.ramps=n;changed=true;}}
  if(Array.isArray(geo.terrain_planes)){const n=geo.terrain_planes.filter(r=>!overlaps(r));if(n.length!==geo.terrain_planes.length){geo.terrain_planes=n;changed=true;}}
  if(Array.isArray(geo.mesh_faces)){const n=geo.mesh_faces.filter(f=>!(f?.terrain_generated===true||String(f?.part_id||'')==='__terrain__'));if(n.length!==geo.mesh_faces.length){geo.mesh_faces=n;changed=true;}}
  if(changed){geo._terrain_dirty=true;void finishSimpleSceneEdit(ctx,mapId,'terrain-erase-v4');}
  return changed;
}

function nudgeTerrainBounds(ctx,mapId,sel,delta) {
  const geo=state.maps.get(mapId); if(!geo||!sel)return false; geo.terrain_cells||={};
  const step=Math.max(.001,Number(geo.height_step)||DEFAULT_STEP); let changed=false;
  for(let y=sel.y0;y<=sel.y1;y++)for(let x=sel.x0;x<=sel.x1;x++){
    const tc=terrainCellAt(geo,x,y);
    const base=tc?.corners?.length===4?tc.corners.map(v=>Number(v)||0):(()=>{const z=Math.max(0,effectiveHeight(geo,mapId,x,y)/step);return[z,z,z,z]})();
    const corners=base.map(v=>Math.max(0,Math.round((v+delta)*10000)/10000));
    geo.terrain_cells[cellKey(x,y)]={...(tc||{}),corners}; changed=true;
  }
  if(changed){geo._terrain_dirty=true;void finishSimpleSceneEdit(ctx,mapId,delta>=0?'terrain-raise':'terrain-lower');}
  return changed;
}

function applyTerrainSlopeRect(ctx,mapId,r,baseHint=null) {
  const geo=state.maps.get(mapId); if(!geo||!r)return false; geo.terrain_cells||={};
  const step=Math.max(.001,Number(geo.height_step)||DEFAULT_STEP);
  const cx=Math.floor((r.x0+r.x1)/2), cy=Math.floor((r.y0+r.y1)/2);
  const centerBase=baseHint==null?terrainCellCenterLevel(geo,cx,cy):Number(baseHint);
  const base=centerBase==null?Math.max(0,effectiveHeight(geo,mapId,cx,cy)/step):centerBase;
  const angle=Math.max(-75,Math.min(75,Number(state.terrainAngle)||0));
  const yaw=(((Number(state.terrainYaw)||0)%360)+360)%360*Math.PI/180;
  const rise=Math.tan(angle*Math.PI/180)*(TILE_SIZE/step); const a=Math.sin(yaw)*rise; const b=-Math.cos(yaw)*rise;
  const px=(r.x0+r.x1+1)/2,py=(r.y0+r.y1+1)/2; let c=base-a*px-b*py;
  const zs=[[r.x0,r.y0],[r.x1+1,r.y0],[r.x1+1,r.y1+1],[r.x0,r.y1+1]].map(([x,y])=>a*x+b*y+c);
  const minZ=Math.min(...zs); if(minZ<0)c+=-minZ;
  for(let y=r.y0;y<=r.y1;y++)for(let x=r.x0;x<=r.x1;x++){
    const corners=[terrainLevelAtPoint({a,b,c},x,y),terrainLevelAtPoint({a,b,c},x+1,y),terrainLevelAtPoint({a,b,c},x+1,y+1),terrainLevelAtPoint({a,b,c},x,y+1)].map(v=>Math.round(v*10000)/10000);
    const tc=terrainCellAt(geo,x,y); geo.terrain_cells[cellKey(x,y)]={...(tc||{}),corners};
  }
  geo._terrain_dirty=true; void finishSimpleSceneEdit(ctx,mapId,'terrain-slope'); return true;
}

function applyCurrentTerrainToolToSelection(ctx) {
  const mapId=ctx.editor.activeMapId?.(); const geo=currentGeo(ctx); const sel=currentTerrainSelection(ctx,geo);
  if(mapId==null||!geo||!sel)return false;
  if(state.sceneTool==='raise')return nudgeTerrainBounds(ctx,mapId,sel,Math.abs(Number(state.terrainStep)||.25));
  if(state.sceneTool==='lower')return nudgeTerrainBounds(ctx,mapId,sel,-Math.abs(Number(state.terrainStep)||.25));
  if(state.sceneTool==='terrain-slope')return applyTerrainSlopeRect(ctx,mapId,sel,state.terrainTargetHeight);
  if(state.sceneTool==='terrain-flat')return setTerrainHeightInBounds(ctx,mapId,sel,state.terrainTargetHeight);
  if(state.sceneTool==='erase')return eraseTerrainBounds(ctx,mapId,sel);
  return false;
}

function applyTerrainSlopeBrush(ctx, mapId, cx, cy) {
  const geo=state.maps.get(mapId); if(!geo)return false;
  const br=terrainBrushRect(ctx,geo,cx,cy); if(!br.w||!br.h)return false;
  const r={x0:br.x0,y0:br.y0,x1:br.x1-1,y1:br.y1-1};
  return applyTerrainSlopeRect(ctx,mapId,r,null);
}

function flattenTerrainBrush(ctx, mapId, cx, cy) {
  const geo=state.maps.get(mapId); if(!geo)return false; geo.terrain_cells||={};
  const r=terrainBrushRect(ctx,geo,cx,cy); if(!r.w||!r.h)return false;
  const step=Math.max(.001,Number(geo.height_step)||DEFAULT_STEP);
  const sampled=Math.max(0,effectiveHeight(geo,mapId,cx,cy)/step);
  const base=state.terrainFlatTarget==null?sampled:Number(state.terrainFlatTarget);
  let changed=false;
  for(let y=r.y0;y<r.y1;y++)for(let x=r.x0;x<r.x1;x++){const tc=terrainCellAt(geo,x,y);geo.terrain_cells[cellKey(x,y)]={...(tc||{}),corners:[base,base,base,base]};changed=true;}
  if(changed){geo._terrain_dirty=true;state.terrainTargetHeight=base;void finishSimpleSceneEdit(ctx,mapId,'terrain-flat');}
  return changed;
}

function clearTerrainBrush(ctx, mapId, cx, cy) {
  const geo=state.maps.get(mapId); if(!geo?.terrain_cells)return false;
  const r=terrainBrushRect(ctx,geo,cx,cy); let changed=false;
  for(let y=r.y0;y<r.y1;y++)for(let x=r.x0;x<r.x1;x++){const k=cellKey(x,y);if(k in geo.terrain_cells){delete geo.terrain_cells[k];changed=true;}}
  if(changed){geo._terrain_dirty = true;void finishSimpleSceneEdit(ctx,mapId,"terrain-clear");}
  return changed;
}

function nudgeTerrainBrush(ctx, mapId, cx, cy, delta) {
  const geo = state.maps.get(mapId); if (!geo) return false;
  geo.terrain_cells ||= {};
  const r = terrainBrushRect(ctx, geo, cx, cy); if (!r.w || !r.h) return false;
  const step = Math.max(.001, Number(geo.height_step) || DEFAULT_STEP);
  let changed = false;
  for (let y = r.y0; y < r.y1; y++) for (let x = r.x0; x < r.x1; x++) {
    const k = cellKey(x,y);
    // A cell is nudged only once per mouse stroke. This avoids the old
    // overlap problem where a 3x3 brush could raise its centre repeatedly
    // just because the pointer crossed neighbouring cells.
    if (state.dragging && state.terrainStrokeCells.has(k)) continue;
    if (state.dragging) state.terrainStrokeCells.add(k);
    const tc = terrainCellAt(geo,x,y);
    const base = tc?.corners?.length === 4
      ? tc.corners.map(v => Number(v) || 0)
      : (() => { const z = Math.max(0, effectiveHeight(geo,mapId,x,y) / step); return [z,z,z,z]; })();
    const corners = base.map(v => Math.max(0, Math.round((v + delta) * 10000) / 10000));
    if (corners.some((v,i) => Math.abs(v-base[i]) > 0.00001)) { geo.terrain_cells[k] = { ...(tc || {}), corners }; changed = true; }
  }
  if (changed) { geo._terrain_dirty = true; void finishSimpleSceneEdit(ctx,mapId,delta > 0 ? "terrain-raise" : "terrain-lower"); }
  return changed;
}

function eraseTerrainBrush(ctx, mapId, cx, cy) {
  const geo=state.maps.get(mapId); if(!geo)return false;
  const br=terrainBrushRect(ctx,geo,cx,cy); if(!br.w||!br.h)return false;
  return eraseTerrainBounds(ctx,mapId,{x0:br.x0,y0:br.y0,x1:br.x1-1,y1:br.y1-1});
}

function eraseModelAtCell(ctx,mapId,x,y) {
  const geo=state.maps.get(mapId); if(!geo)return false;
  const ids=new Set((geo.model_instances||[]).filter(inst=>modelInstanceCoversCell(geo,inst,x,y)).map(inst=>Number(inst.id)));
  if(!ids.size)return false;
  geo.model_instances=(geo.model_instances||[]).filter(inst=>!ids.has(Number(inst.id)));
  geo.model_objects=(geo.model_objects||[]).filter(obj=>!ids.has(Number(obj.model_instance_id)));
  compileModelObjects(geo);
  void finishSimpleSceneEdit(ctx,mapId,"model-erase");
  return true;
}

function terrainFaceMaterialAt(ctx,mapId,x,y) {
  try { const d=sourceDescriptorAt(ctx,mapId,x,y,null); return materialFromSourceDescriptor(d); } catch (_) { return null; }
}

function compileTerrainMeshFaces(ctx,mapId,geo) {
  if(!geo)return [];
  const cells=normalizeTerrainCells(geo.terrain_cells); geo.terrain_cells=cells;
  const old=(geo.mesh_faces||[]).filter(f=>!(f?.terrain_generated===true || String(f?.part_id||"")==="__terrain__"));
  const buckets=new Map();
  for(const [key,cell] of Object.entries(cells)){
    const [x,y]=key.split(',').map(Number); const pc=terrainPlaneCoefficients(x,y,cell.corners); if(!pc.planar)continue;
    const mat=cell.material || terrainFaceMaterialAt(ctx,mapId,x,y); const ms=materialSignature(mat)||"none";
    const sig=[pc.a,pc.b,pc.c].map(v=>Math.round(v*10000)/10000).join(',')+'|'+ms;
    if(!buckets.has(sig))buckets.set(sig,{a:pc.a,b:pc.b,c:pc.c,mat,cells:new Set()}); buckets.get(sig).cells.add(key);
  }
  const faces=[]; let id=200000;
  for(const bucket of buckets.values()){
    const remain=new Set(bucket.cells);
    const sorted=()=>[...remain].map(k=>k.split(',').map(Number)).sort((a,b)=>a[1]-b[1]||a[0]-b[0]);
    while(remain.size){
      const [x0,y0]=sorted()[0]; let w=1;
      while(remain.has(`${x0+w},${y0}`))w++;
      let h=1,more=true;
      while(more){for(let x=x0;x<x0+w;x++)if(!remain.has(`${x},${y0+h}`)){more=false;break;}if(more)h++;}
      for(let y=y0;y<y0+h;y++)for(let x=x0;x<x0+w;x++)remain.delete(`${x},${y}`);
      const x1=x0+w,y1=y0+h,z=(x,y)=>Math.max(0,bucket.a*x+bucket.b*y+bucket.c);
      const verts=[[x0,y0,z(x0,y0)],[x1,y0,z(x1,y0)],[x1,y1,z(x1,y1)],[x0,y1,z(x0,y1)]];
      const zs=verts.map(v=>v[2]);
      faces.push({id:id++,kind:'quad',surface:'top',edge:'top',vertices:verts,uv_rect:null,pattern_uv:[x0,y0,x1,y1],
        x0,y0,x1,y1,z0:Math.min(...zs),z1:Math.max(...zs),material:bucket.mat,material_repeat:true,category:'terrain-angle',
        model_id:'',model_instance_id:0,part_id:'__terrain__',terrain_generated:true,chunk_key:`${Math.floor(x0/8)},${Math.floor(y0/8)}`});
    }
  }
  geo.mesh_faces=[...old,...faces];
  geo.terrain_planes=faces.map(f=>({x:f.x0,y:f.y0,width:f.x1-f.x0,height:f.y1-f.y0,corners:[f.vertices[0][2],f.vertices[1][2],f.vertices[2][2],f.vertices[3][2]]}));
  return faces;
}

function hasExplicitCell(geo, x, y) {
  return !!geo?.cells && Object.prototype.hasOwnProperty.call(geo.cells, cellKey(x, y));
}

function legacyHeightAt(mapId, x, y) {
  return Number(state.legacyHeights.get(mapId)?.get(cellKey(x, y))) || 0;
}

function effectiveHeight(geo, mapId, x, y) {
  const tl = terrainCellCenterLevel(geo, x, y);
  if (tl != null) return tl * (Number(geo?.height_step) || DEFAULT_STEP);
  if (hasExplicitCell(geo, x, y)) return cellHeight(geo, x, y);
  if (geo?.inherit_legacy !== false) return legacyHeightAt(mapId, x, y);
  return 0;
}

function effectiveLevel(geo, mapId, x, y) {
  const step = Number(geo?.height_step) || DEFAULT_STEP;
  return Math.max(0, Math.round(effectiveHeight(geo, mapId, x, y) / step));
}

function mapCellTags(ctx, mapId, x, y, layers, tilesetId) {
  const tags = [];
  for (const layer of layers) {
    const data = readTileVisualData(ctx, mapId, layer, x, y);
    const tileId = Number(data?.tileId) || 0;
    if (!tileId) continue;
    const sourceTilesetId = Number(data?.tilesetId) || Number(tilesetId) || 0;
    const tag = Number(tileProps(ctx, sourceTilesetId, tileId)?.terrainTag) || 0;
    if (tag) tags.push(tag);
  }
  return tags;
}

function rebuildLegacyHeights(ctx, mapId) {
  const info = ctx.map.info(mapId);
  if (!info) return;
  const layers = ctx.map.layers(mapId).filter((l) => l.kind !== "shadow");
  // Store layers reference for incremental updates.
  if (!state.legacyHeightLayers) state.legacyHeightLayers = new Map();
  state.legacyHeightLayers.set(mapId, layers);
  const tags = new Map();
  const height = new Map();
  const tagAt = (x, y) => {
    if (x < 0 || y < 0 || x >= info.width || y >= info.height) return [];
    const key = cellKey(x, y);
    if (!tags.has(key)) tags.set(key, mapCellTags(ctx, mapId, x, y, layers, mapTilesetId(info, mapId)));
    return tags.get(key);
  };
  const hasTag = (x, y, tag) => tagAt(x, y).includes(tag);

  // NDSVolume / NDSVolumeHigh physical fallback.
  for (let y = 0; y < info.height; y++) {
    for (let x = 0; x < info.width; x++) {
      const ts = tagAt(x, y);
      let h = 0;
      if (ts.includes(TAG.VOLUME)) h = Math.max(h, runtimeConfig.volumeDefaultHeight);
      if (ts.includes(TAG.VOLUME_HIGH)) h = Math.max(h, runtimeConfig.volumeHighHeight);
      if (h > 0) height.set(cellKey(x, y), h);
    }
  }

    // Mirror the runtime legacy mountain rule: connected MountainTop
  // cells share the maximum number of MountainWall rows on their south edge.
  const top = new Set();
  for (let y = 0; y < info.height; y++) {
    for (let x = 0; x < info.width; x++) if (hasTag(x, y, TAG.MOUNTAIN_TOP)) top.add(cellKey(x, y));
  }
  const visited = new Set();
  for (const start of top) {
    if (visited.has(start)) continue;
    const [sx, sy] = start.split(",").map(Number);
    const queue = [[sx, sy]];
    const component = [];
    visited.add(start);
    while (queue.length) {
      const [cx, cy] = queue.shift();
      component.push([cx, cy]);
      for (const [nx, ny] of [[cx-1,cy],[cx+1,cy],[cx,cy-1],[cx,cy+1]]) {
        const k = cellKey(nx, ny);
        if (!top.has(k) || visited.has(k)) continue;
        visited.add(k); queue.push([nx, ny]);
      }
    }
    const compSet = new Set(component.map(([x,y]) => cellKey(x,y)));
    let levels = 0;
    for (const [cx, cy] of component) {
      if (compSet.has(cellKey(cx, cy + 1))) continue;
      let count = 0;
      let wy = cy + 1;
      while (wy < info.height && (hasTag(cx, wy, TAG.MOUNTAIN_WALL) || hasTag(cx, wy, TAG.MOUNTAIN_WALL_PLANE))) {
        count++; wy++;
      }
      levels = Math.max(levels, count);
    }
    levels = Math.max(1, levels);
    for (const [cx, cy] of component) height.set(cellKey(cx, cy), levels * runtimeConfig.mountainHeight);
  }
  state.legacyHeights.set(mapId, height);
}

function setCellLevel(geo, x, y, level) {
  const infoWidth = Number(geo.width) || 0;
  const infoHeight = Number(geo.height) || 0;
  if (x < 0 || y < 0 || x >= infoWidth || y >= infoHeight) return;
  const key = cellKey(x, y);
  const next = Math.max(0, Math.round(Number(level) || 0));
  const old = geo.cells[key];
  if (next <= 0) {
    // Explicit zero overrides legacy height. Use the Inherit mode to remove the
    // override and return this cell to Terrain Tag fallback.
    geo.cells[key] = { level: 0 };
    return;
  }
  const material = old && typeof old === "object" ? old.material : undefined;
  geo.cells[key] = material ? { level: next, material } : { level: next };
}

async function ensureLegacyAuthoringData(ctx, mapId, forceReload = false) {
  if (mapId == null) return;
  if (!forceReload && state.legacyReadyByMap.has(mapId)) return;
  await ensureRxTilesets(ctx, forceReload);
  await ensureRxMap(ctx, mapId, forceReload);
  await loadEmbeddedExtendedData(ctx, mapId);
  rebuildLegacyHeights(ctx, mapId);
  await scanGeometrySources(ctx, mapId, forceReload);
  state.legacyReadyByMap.add(mapId);
}

async function ensureMap(ctx, mapId, forceReload = false) {
  if (mapId == null) return null;
  if (!forceReload && state.maps.has(mapId)) return state.maps.get(mapId);
  const info = ctx.map.info(mapId);
  if (!info) return null;

  // Clean-break migration guard. V4 never reads the old folder. If it still
  // exists we deliberately block editing so stale JSON cannot leak back into
  // the project through an older runtime/editor copy.
  state.legacyDataBlocked = await legacyDataPresent(ctx, mapId);
  state.legacyCheckDone = true;
  if (state.legacyDataBlocked) {
    state.maps.delete(mapId);
    state.panelRefresh?.();
    state.previewPanelRefresh?.();
    return null;
  }

  const path = geometryPath(mapId);
  let geo = newGeometry(mapId, info);
  geo.inherit_legacy = false;
  try {
    if (await ctx.fs.projectExists(path)) {
      const text = await ctx.fs.readProjectFile(path);
      geo = normalizeGeometry(mapId, info, v25Unpack(text, 'V25D1'));
      geo.inherit_legacy = false;
    }
  } catch (err) {
    ctx.log.error(err);
    ctx.ui.showToast({ message: `2.5D Geometry v4: no se pudo leer ${path}`, level: "error" });
  }
  geo._models_preview_ready = false;
  state.maps.set(mapId, geo);
  if (geo.terrain_cells && Object.keys(geo.terrain_cells).length) geo._terrain_dirty = true;
  // V4 intentionally does not bootstrap legacy height/source data. Terrain is
  // explicit and therefore always erasable.
  state.legacyReadyByMap.delete(mapId);
  state.legacyHeights.delete(mapId);
  if (mapId === ctx.editor.activeMapId()) {
    applyPreviewPrefsFromGeometry(geo);
    ensurePreviewFocus(ctx, mapId);
  }
  ctx.editor.requestRedraw();
  state.panelRefresh?.();
  state.previewDirty = true;
  return geo;
}

function compactCollisionRows(rows) {
  const code = (v) => { const s=String(v||"solid"); return s==="climb"?1:(s==="one-way"?2:(s==="none"?3:0)); };
  return (Array.isArray(rows) ? rows : []).map(r => [
    Number(r?.x)||0, Number(r?.y)||0, code(r?.collision), Number(r?.base)||0, Number(r?.height)||0,
    String(r?.model_id||""), Number(r?.model_instance_id)||0, String(r?.part_id||"")
  ]);
}

function authoringDiskGeometry(geo) {
  // Keep editable sources, not compiler products. This makes MapXXX.json much
  // smaller and prevents editor startup from parsing thousands of runtime faces.
  const keepFaces = (Array.isArray(geo?.mesh_faces) ? geo.mesh_faces : []).filter(f =>
    !f?.terrain_generated && !f?.model_id && !Number(f?.model_instance_id || 0) && String(f?.part_id || '') !== '__terrain__'
  );
  const { _terrain_dirty, ...clean } = geo || {};
  return {
    ...clean,
    mesh_faces: keepFaces,
    terrain_planes: [],
    model_objects: [],
    model_collision_cells: [],
    compiled_objects: [],
  };
}

async function saveMap(ctx, mapId, options = {}) {
  const geo = state.maps.get(mapId);
  if (!geo) return;
  const infoEarly = ctx.map.info(mapId);
  if (infoEarly) { geo.map_id = mapId; geo.width = infoEarly.width; geo.height = infoEarly.height; }
  if (mapId === ctx.editor.activeMapId()) persistPreviewPrefs(geo);
  // During brush gestures only persist authoring data. Runtime compilation and
  // the three sidecar writes happen on the real Maker Studio save, not after
  // every click. This is the main editor-latency reduction in 3.3.
  if (options.authoringOnly) {
    try { await ctx.fs.projectMkdir(GEO4_DIR); } catch (_) {}
    try {
      const diskGeo = authoringDiskGeometry(geo);
      await ctx.fs.writeProjectFile(geometryPath(mapId), v25Pack("V25D1", diskGeo));
    } catch (err) { ctx.log.error(err); }
    return;
  }
  // DS terrain is always a cheap sparse compile and must happen before Model
  // Studio rebuilds so its coplanar faces survive into the runtime package.
  compileTerrainMeshFaces(ctx,mapId,geo);
  if (!options.skipModelCompile) compileModelObjects(geo);
  if (!options.skipCompile && geo.compiler?.auto_compile !== false && Object.keys(geo.definitions || {}).length) {
    await compileGeometryScene(ctx, mapId, geo, { forceScan: false, reason: "save" });
  }

  try {
    await ctx.fs.projectMkdir(GEO4_DIR);
  } catch (_) {
    // Existing directory is fine.
  }
  try {
    // model_objects are editor-only collision proxies. v2.9.5+ runtime uses
    // model_collision_cells + mesh_faces, so serializing thousands of proxy
    // objects only increases load time and JSON size. They are rebuilt in
    // memory from models/model_instances whenever the editor loads the map.
    geo._terrain_dirty = false;
    const diskGeo = authoringDiskGeometry(geo);
    await ctx.fs.writeProjectFile(geometryPath(mapId), v25Pack("V25D1", diskGeo));
    // Compact collision sidecar: runtime physics can preload this without parsing
    // the much larger visual mesh/model JSON. It contains no textures or faces.
    const collisionSidecar = {
      format: 2, map_id: mapId, width: geo.width, height: geo.height,
      height_step: geo.height_step || DEFAULT_STEP,
      model_collision_cells_compact: compactCollisionRows(geo.model_collision_cells)
    };
    await ctx.fs.writeProjectFile(geometryCollisionPath(mapId), v25CollisionPackFast(collisionSidecar));
    // Runtime-only sidecar. The game never needs authoring models, source
    // definitions, editor state or template instances. Keeping those out of
    // the load path avoids the multi-second JSON/model hitch on save-load.
    const compactFaceFactory=(materials, materialIndex)=>(f)=>[
      Number(f.id)||0, f.kind||"quad", f.surface||null, f.edge||null,
      Array.isArray(f.vertices)?f.vertices:null, Array.isArray(f.uv_rect)?f.uv_rect:null, Array.isArray(f.pattern_uv)?f.pattern_uv:null,
      (()=>{const mat=f.material;if(!mat)return -1;const key=JSON.stringify(mat);if(materialIndex.has(key))return materialIndex.get(key);const i=materials.length;materials.push(mat);materialIndex.set(key,i);return i;})(),
      f.material_repeat!==false?1:0, f.category||"mountain", f.model_id||"", Number(f.model_instance_id)||0, f.part_id||"", f.chunk_key||"",
      Number(f.x0)||0,Number(f.y0)||0,Number(f.x1)||0,Number(f.y1)||0,Number(f.z0)||0,Number(f.z1)||0
    ];
    const terrainFaces=(geo.mesh_faces||[]).filter(f=>f?.terrain_generated===true || String(f?.part_id||"")==="__terrain__");
    const streamedFaces=(geo.mesh_faces||[]).filter(f=>!(f?.terrain_generated===true || String(f?.part_id||"")==="__terrain__"));
    const terrainMaterials=[], terrainMaterialIndex=new Map();
    const terrainCompact=terrainFaces.map(compactFaceFactory(terrainMaterials,terrainMaterialIndex));
    const modelMaterials=[], modelMaterialIndex=new Map();
    const compactFaces=streamedFaces.map(compactFaceFactory(modelMaterials,modelMaterialIndex));
    // V3.1: first-frame file contains only sparse height/collision data and a
    // handful of merged terrain planes. Custom models remain streamed/lazy.
    const modelStreamName = `Map${pad3(mapId)}.v25m`;
    const runtimeGeo = {
      format: "vermeil-runtime-5", map_id: mapId, width: geo.width, height: geo.height,
      height_step: geo.height_step || DEFAULT_STEP, inherit_legacy: false,
      cells: geo.cells || {}, ramps: Array.isArray(geo.ramps) ? geo.ramps : [],
      terrain_planes: Array.isArray(geo.terrain_planes) ? geo.terrain_planes : [],
      materials: terrainMaterials, mesh_faces_compact: terrainCompact,
      objects: Array.isArray(geo.objects) ? geo.objects : [],
      compiled_objects: Array.isArray(geo.compiled_objects) ? geo.compiled_objects : [],
      model_objects: [], model_collision_cells: [],
      model_stream: modelStreamName,
      model_face_count: compactFaces.length
    };
    await ctx.fs.writeProjectFile(geometryRuntimePath(mapId), v25RuntimePackFast(runtimeGeo));
    const modelLines = ["V25M1", `H${v25Encode({ format: "vermeil-model-stream-4", materials: modelMaterials, count: compactFaces.length })}`];
    for (const face of compactFaces) modelLines.push(`F${v25Encode(face)}`);
    await ctx.fs.writeProjectFile(geometryModelStreamPath(mapId), `${modelLines.join("\n")}\n`);
    ctx.editor.setStatusBarText?.(`2.5D Geometry: Map${pad3(mapId)} guardado + runtime compilado`);
  } catch (err) {
    ctx.log.error(err);
    ctx.ui.showToast({ message: `2.5D Geometry: error al guardar Map${pad3(mapId)}`, level: "error" });
  }
}

function resolvePaintMode(ev) {
  if (ev.altKey) return "erase";
  if (ev.shiftKey) return "raise";
  if (ev.ctrlKey) return "lower";
  return state.mode;
}

function applyBrushToCell(ctx, geo, mapId, x0, y0, mode) {
  const brush = Math.max(1, Number(ctx.editor.brushSize()) || 1);
  const half = Math.floor((brush - 1) / 2);
  for (let oy = 0; oy < brush; oy++) {
    for (let ox = 0; ox < brush; ox++) {
      const x = x0 + ox - half;
      const y = y0 + oy - half;
      if (x < 0 || y < 0 || x >= geo.width || y >= geo.height) continue;
      const old = effectiveLevel(geo, mapId, x, y);
      let next = old;
      if (mode === "set") next = state.level;
      else if (mode === "raise") next = old + 1;
      else if (mode === "lower") next = Math.max(0, old - 1);
      else if (mode === "erase") next = 0;
      else if (mode === "inherit") {
        delete geo.cells[cellKey(x, y)];
        continue;
      }
      setCellLevel(geo, x, y, next);
    }
  }
}

async function paintAt(ctx, ev) {
  const geo = await ensureMap(ctx, ev.mapId);
  if (!geo) return;
  const mode = resolvePaintMode(ev);
  const strokeKey = `${ev.mapId}:${ev.tileX},${ev.tileY}:${mode}`;
  if (state.visited.has(strokeKey)) return;
  state.visited.add(strokeKey);
  applyBrushToCell(ctx, geo, ev.mapId, ev.tileX, ev.tileY, mode);
  ctx.editor.requestRedraw();
  state.panelRefresh?.();
  schedulePreview(ctx);
}

function commitObjectFromRect(ctx, geo, mapId, x0, y0, x1, y1) {
  const ax = Math.min(x0, x1), ay = Math.min(y0, y1);
  const bx = Math.max(x0, x1), by = Math.max(y0, y1);
  const w = bx - ax + 1;
  const h = by - ay + 1;
  if (ax < 0 || ay < 0 || bx >= geo.width || by >= geo.height) return null;
  const id = nextObjectId(geo);
  const obj = {
    id,
    name: `Object ${id}`,
    type: state.objType,
    x: ax, y: ay, w, h,
    height: Math.max(0, Math.round(Number(state.objHeight) || 0)),
    anchor_z: Math.max(0, Math.round(Number(state.objAnchorZ) || 0)),
    anchor_row: h - 1,
    rotation: 0,
    collision: state.objCollision,
    category: state.objCategory,
    characters_in_front: false,
    footprint: {},
  };
  if (state.objMaterial && typeof state.objMaterial === "object") obj.material = state.objMaterial;
  geo.objects.push(obj);
  state.objSelected = Number(obj.id);
  state.objStart = null;
  state.objCurrent = null;
  ctx.editor.requestRedraw();
  state.panelRefresh?.();
  schedulePreview(ctx);
  return obj;
}

function selectObject(ctx, geo, obj, mapId) {
  state.objSelected = Number(obj.id);
  state.objStart = null;
  state.objCurrent = null;
  if (mapId != null) {
    const mid = Number(obj?.material?.tileset_id);
    if (mid) void ensureSceneTilesetResources(ctx, mapId, false);
  }
  ctx.editor.requestRedraw();
  state.panelRefresh?.();
  schedulePreview(ctx);
}

function objEditChanged(ctx) {
  const id = ctx.editor.activeMapId?.();
  if (id != null) void saveMap(ctx, id);
  ctx.editor.requestRedraw();
  state.panelRefresh?.();
  schedulePreview(ctx);
}

function moveSelectedObject(ctx, dx, dy) {
  const geo = currentGeo(ctx), obj = objFieldTarget(geo);
  if (!geo || !obj) return;
  obj.x = Math.max(0, Math.min(geo.width - obj.w, obj.x + dx));
  obj.y = Math.max(0, Math.min(geo.height - obj.h, obj.y + dy));
  objEditChanged(ctx);
}

function rotateSelectedObject(ctx, clockwise = true) {
  const geo = currentGeo(ctx), obj = objFieldTarget(geo);
  if (!geo || !obj) return;
  if (clockwise) rotateFootprint90(obj);
  else { rotateFootprint90(obj); rotateFootprint90(obj); rotateFootprint90(obj); }
  obj.x = Math.max(0, Math.min(geo.width - obj.w, obj.x));
  obj.y = Math.max(0, Math.min(geo.height - obj.h, obj.y));
  objEditChanged(ctx);
}

function duplicateSelectedObject(ctx) {
  const geo = currentGeo(ctx), obj = objFieldTarget(geo);
  if (!geo || !obj) return;
  const copy = JSON.parse(JSON.stringify(obj));
  copy.id = nextObjectId(geo);
  copy.name = `${obj.name || `Object ${obj.id}`} Copy`;
  copy.x = Math.min(Math.max(0, geo.width - copy.w), obj.x + 1);
  copy.y = Math.min(Math.max(0, geo.height - copy.h), obj.y + 1);
  geo.objects.push(copy);
  state.objSelected = copy.id;
  objEditChanged(ctx);
}

function deleteSelectedObject(ctx) {
  const geo = currentGeo(ctx), obj = objFieldTarget(geo);
  if (!geo || !obj) return;
  geo.objects = geo.objects.filter((o) => Number(o.id) !== Number(obj.id));
  state.objSelected = null;
  objEditChanged(ctx);
}

function fitSelectedObjectToMaterial(ctx) {
  const geo = currentGeo(ctx), obj = objFieldTarget(geo);
  if (!geo || !obj?.material?.src_rect) return;
  const r = obj.material.src_rect;
  const w = Math.max(1, Math.round((Number(r.w) || TILE_SIZE) / TILE_SIZE));
  const h = Math.max(1, Math.round((Number(r.h) || TILE_SIZE) / TILE_SIZE));
  obj.w = Math.min(w, geo.width - obj.x);
  obj.h = Math.min(h, geo.height - obj.y);
  obj.anchor_row = Math.min(obj.h - 1, Math.max(0, obj.anchor_row ?? obj.h - 1));
  obj.footprint = normalizeFootprint(obj.footprint, obj.w, obj.h);
  objEditChanged(ctx);
}

function setFootprintCell(ctx, obj, dx, dy, mode) {
  if (!obj || dx < 0 || dy < 0 || dx >= obj.w || dy >= obj.h) return;
  obj.footprint ||= {};
  const key = `${dx},${dy}`;
  if (!mode || mode === "inherit") delete obj.footprint[key];
  else obj.footprint[key] = mode;
  objEditChanged(ctx);
}

function removeObjectsAt(ctx, geo, mapId, x, y) {
  const before = (geo.objects || []).length;
  geo.objects = (geo.objects || []).filter((o) => {
    return !objectCoversCell(o, x, y);
  });
  if (state.objSelected != null &&
      !(geo.objects || []).some((o) => Number(o.id) === Number(state.objSelected))) {
    state.objSelected = null;
  }
  if (geo.objects.length !== before) {
    ctx.editor.requestRedraw();
    state.panelRefresh?.();
    schedulePreview(ctx);
    return true;
  }
  return false;
}

async function objectEraseAt(ctx, ev) {
  const geo = await ensureMap(ctx, ev.mapId);
  if (!geo) return;
  const key = `${ev.mapId}:${ev.tileX},${ev.tileY}`;
  if (state.visited.has(key)) return;
  state.visited.add(key);
  removeObjectsAt(ctx, geo, ev.mapId, ev.tileX, ev.tileY);
  schedulePreview(ctx);
}

function levelColor(level, alpha = 0.28) {
  if (level <= 0) return "rgba(0,0,0,0)";
  const hue = (205 + level * 37) % 360;
  return `hsla(${hue}, 88%, 58%, ${alpha})`;
}

function overlayMarkerForTags(tags, explicit, level) {
  const set = new Set(tags || []);
  if (set.has(TAG.MOUNTAIN_TOP)) return { role: "mountain", text: `MT${level > 0 ? ` L${level}` : ""}`, icon: "▲" };
  if (set.has(TAG.STAIR)) return { role: "stair", text: "STAIR", icon: "↗" };
  if (set.has(TAG.STRUCTURE)) return { role: "structure", text: "STRUCT", icon: "◆" };
  if (set.has(TAG.BILLBOARD) || set.has(TAG.INDOOR_PROP)) return { role: "billboard", text: "BILL", icon: "◆" };
  if (set.has(TAG.WALL_PLANE) || set.has(TAG.MOUNTAIN_WALL_PLANE)) return { role: "wall3d", text: "WALL3D", icon: "▥" };
  if (set.has(TAG.MOUNTAIN_WALL)) return { role: "cliff", text: "CLIFF", icon: "▥" };
  if (set.has(TAG.WALL) || set.has(TAG.INDOOR_WALL)) return { role: "wall", text: "WALL", icon: "▥" };
  if (set.has(TAG.ROOF_PLANE)) return { role: "roof3d", text: "ROOF3D", icon: "▱" };
  if (set.has(TAG.ROOF) || set.has(TAG.ROOF_HIGH)) return { role: "roof", text: "ROOF", icon: "⌂" };
  if (set.has(TAG.VOLUME) || set.has(TAG.VOLUME_HIGH)) return { role: "volume", text: `VOL${level > 0 ? ` L${level}` : ""}`, icon: "▣" };
  if (set.has(TAG.OVERLAY)) return { role: "overlay", text: "OVER", icon: "◇" };
  if (explicit && level > 0) return { role: `geometry-${level}`, text: `L${level}*`, icon: "▦" };
  return null;
}


function renderOverlay(ctx, c2d, info) {
  if (!state.showOverlay || ctx.editor.activeTool?.() !== TOOL_ID) return;
  const geo = state.maps.get(info.mapId);
  if (!geo) { void ensureMap(ctx, info.mapId); return; }
  const mapInfo = ctx.map.info(info.mapId);
  if (!mapInfo) return;
  const layers = visibleLayers(ctx, info.mapId);
  const tile = info.tileSize * info.zoom;
  const minX = Math.max(0, Math.floor(info.viewportX / info.tileSize) - 1);
  const minY = Math.max(0, Math.floor(info.viewportY / info.tileSize) - 1);
  const maxX = Math.min(geo.width - 1, Math.ceil((info.viewportX + info.canvasWidth / info.zoom) / info.tileSize) + 1);
  const maxY = Math.min(geo.height - 1, Math.ceil((info.viewportY + info.canvasHeight / info.zoom) / info.tileSize) + 1);

  const refs = new Map();
  for (let y = minY; y <= maxY; y++) {
    for (let x = minX; x <= maxX; x++) {
      const legacyVisible = state.workspaceMode !== "scene";
      const level = legacyVisible ? effectiveLevel(geo, info.mapId, x, y) : 0;
      const explicit = legacyVisible && hasExplicitCell(geo, x, y);
      const tags = legacyVisible ? mapCellTags(ctx, info.mapId, x, y, layers, mapTilesetId(mapInfo, info.mapId)) : [];
      refs.set(cellKey(x, y), { x, y, level, explicit, marker: legacyVisible && state.show2DRefs ? overlayMarkerForTags(tags, explicit, level) : null });
    }
  }
  const sameRole = (a, b) => !!a?.marker && !!b?.marker && a.marker.role === b.marker.role && a.level === b.level;

  c2d.save();
  c2d.textBaseline = "middle";
  for (const ref of refs.values()) {
    const { x, y, level, explicit, marker } = ref;
    if (level <= 0 && !marker) continue;
    const px = (x * info.tileSize - info.viewportX) * info.zoom;
    const py = (y * info.tileSize - info.viewportY) * info.zoom;

    if (level > 0) {
      c2d.fillStyle = levelColor(level, explicit ? 0.17 : 0.09);
      c2d.fillRect(px, py, tile, tile);
      const left = refs.get(cellKey(x - 1, y));
      const up = refs.get(cellKey(x, y - 1));
      if (state.showLabels && tile >= 26 && (!left || left.level !== level) && (!up || up.level !== level)) {
        const label = `L${level}${explicit ? "*" : ""}`;
        const h = Math.max(11, Math.min(14, tile * 0.27));
        c2d.font = `${Math.max(8, Math.min(10, h * 0.75))}px sans-serif`;
        const w = Math.max(20, c2d.measureText(label).width + 7);
        c2d.fillStyle = "rgba(8,12,18,0.72)"; c2d.fillRect(px + 2, py + 2, w, h);
        c2d.fillStyle = "rgba(225,250,255,0.94)"; c2d.textAlign = "left"; c2d.fillText(label, px + 5, py + 2 + h / 2);
      }
    }

    if (marker) {
      const cyan = marker.role === "billboard" || marker.role === "structure";
      c2d.strokeStyle = cyan ? "rgba(80,220,255,0.62)" : "rgba(255,190,75,0.58)";
      c2d.lineWidth = Math.max(1, info.zoom * 0.8);
      c2d.strokeRect(px + 1, py + 1, Math.max(1, tile - 2), Math.max(1, tile - 2));
      if (cyan) {
        const ax = px + tile / 2, ay = py + tile - Math.max(4, tile * 0.10);
        const r = Math.max(2, Math.min(4, tile * 0.09));
        c2d.save(); c2d.translate(ax, ay); c2d.rotate(Math.PI / 4);
        c2d.fillStyle = "rgba(80,220,255,0.90)"; c2d.fillRect(-r, -r, r * 2, r * 2); c2d.restore();
      }
      const left = refs.get(cellKey(x - 1, y));
      const up = refs.get(cellKey(x, y - 1));
      if (tile >= 24 && !sameRole(ref, left) && !sameRole(ref, up)) {
        const text = marker.text;
        const h = Math.max(11, Math.min(14, tile * 0.27));
        c2d.font = `${Math.max(8, Math.min(10, h * 0.75))}px sans-serif`;
        const w = Math.min(tile * 1.45, Math.max(20, c2d.measureText(text).width + 7));
        c2d.fillStyle = "rgba(8,12,18,0.72)"; c2d.fillRect(px + 2, py + 2, w, h);
        c2d.fillStyle = "rgba(225,250,255,0.94)"; c2d.textAlign = "left"; c2d.fillText(text, px + 5, py + 2 + h / 2);
      }
    }
  }

  // Height transitions = physical collision/cliff border.
  c2d.strokeStyle = "rgba(255,74,74,0.76)";
  c2d.lineWidth = Math.max(1, 1.25 * info.zoom);
  c2d.beginPath();
  for (const ref of refs.values()) {
    const { x, y, level } = ref;
    const right = refs.get(cellKey(x + 1, y));
    const down = refs.get(cellKey(x, y + 1));
    if (right && right.level !== level) {
      const sx = ((x + 1) * info.tileSize - info.viewportX) * info.zoom;
      const sy = (y * info.tileSize - info.viewportY) * info.zoom;
      c2d.moveTo(sx, sy); c2d.lineTo(sx, sy + tile);
    }
    if (down && down.level !== level) {
      const sx = (x * info.tileSize - info.viewportX) * info.zoom;
      const sy = ((y + 1) * info.tileSize - info.viewportY) * info.zoom;
      c2d.moveTo(sx, sy); c2d.lineTo(sx + tile, sy);
    }
  }
  c2d.stroke();

  // Parametric terrain is the primary 3.4 authoring surface. Show it directly
  // on Maker Studio's map so edits never feel invisible or disconnected from
  // the native 2D workflow.
  for (let y=minY;y<=maxY;y++) for (let x=minX;x<=maxX;x++) {
    const tc=terrainCellAt(geo,x,y); if(!tc?.corners?.length)continue;
    const px=(x*info.tileSize-info.viewportX)*info.zoom,py=(y*info.tileSize-info.viewportY)*info.zoom;
    const vals=tc.corners.map(v=>Number(v)||0),avg=vals.reduce((a,b)=>a+b,0)/4,range=Math.max(...vals)-Math.min(...vals);
    c2d.fillStyle=range>.01?'rgba(95,205,255,.14)':'rgba(100,235,170,.11)'; c2d.fillRect(px+1,py+1,Math.max(1,tile-2),Math.max(1,tile-2));
    c2d.strokeStyle=range>.01?'rgba(95,205,255,.78)':'rgba(100,235,170,.55)'; c2d.lineWidth=Math.max(1,info.zoom*.8); c2d.strokeRect(px+1,py+1,Math.max(1,tile-2),Math.max(1,tile-2));
    if(tile>=24){
      c2d.font=`${Math.max(8,Math.min(10,tile*.25))}px sans-serif`; c2d.textAlign='center'; c2d.textBaseline='middle';
      const txt=range>.01?`↗ ${avg.toFixed(2)}`:`H ${avg.toFixed(2)}`;
      const tw=c2d.measureText(txt).width+6;c2d.fillStyle='rgba(8,12,18,.72)';c2d.fillRect(px+tile/2-tw/2,py+tile/2-7,tw,14);c2d.fillStyle='rgba(225,250,255,.96)';c2d.fillText(txt,px+tile/2,py+tile/2);
    }
    if(range>.01){
      const [nw,ne,se,sw]=vals; const gx=((ne+se)-(nw+sw))/2, gy=((sw+se)-(nw+ne))/2;
      const len=Math.hypot(gx,gy)||1,ux=gx/len,uy=gy/len,cx=px+tile/2,cy=py+tile/2,L=Math.min(tile*.28,10*info.zoom);
      c2d.strokeStyle='rgba(255,238,115,.96)';c2d.lineWidth=Math.max(1.2,1.5*info.zoom);c2d.beginPath();c2d.moveTo(cx-ux*L*.45,cy-uy*L*.45);c2d.lineTo(cx+ux*L,cy+uy*L);c2d.stroke();
    }
  }

  // Brush footprint follows the native Maker Studio hover and makes painting
  // predictable before mouse-down.
  if(state.mapHover && Number(state.mapHover.mapId)===Number(info.mapId) && state.workspaceMode==='scene'){
    const br=terrainBrushRect(ctx,geo,state.mapHover.x,state.mapHover.y);
    if(br.w&&br.h){
      const px=(br.x0*info.tileSize-info.viewportX)*info.zoom,py=(br.y0*info.tileSize-info.viewportY)*info.zoom,w=br.w*tile,h=br.h*tile;
      c2d.save();c2d.setLineDash([5,3]);c2d.lineWidth=Math.max(1.5,1.6*info.zoom);c2d.strokeStyle=state.sceneTool==='erase'?'rgba(255,105,105,.96)':'rgba(255,225,95,.96)';c2d.strokeRect(px+1,py+1,Math.max(1,w-2),Math.max(1,h-2));c2d.restore();
    }
  }

  const tsel=currentTerrainSelection(ctx,geo);
  if(tsel){
    const px=(tsel.x0*info.tileSize-info.viewportX)*info.zoom,py=(tsel.y0*info.tileSize-info.viewportY)*info.zoom,w=tsel.w*tile,h=tsel.h*tile;
    c2d.save();c2d.fillStyle='rgba(255,210,70,.08)';c2d.fillRect(px,py,w,h);c2d.strokeStyle='rgba(255,220,80,.98)';c2d.lineWidth=Math.max(2,2*info.zoom);c2d.strokeRect(px+1,py+1,Math.max(1,w-2),Math.max(1,h-2));c2d.restore();
  }

  // Geometry objects (cubes/planes): footprint + collision outline.
  for (const obj of sceneObjects(geo)) {
    const r = objectRect(obj);
    if (r.x1 < minX || r.x0 > maxX || r.y1 < minY || r.y0 > maxY) continue;
    const px = (r.x0 * info.tileSize - info.viewportX) * info.zoom;
    const py = (r.y0 * info.tileSize - info.viewportY) * info.zoom;
    const w = (r.x1 - r.x0 + 1) * tile;
    const h = (r.y1 - r.y0 + 1) * tile;
    c2d.save();
    const manualSelected = state.objSelected != null && Number(obj.id) === Number(state.objSelected);
    const sourceSelected = state.workspaceMode === "scene" && !!obj.compiled &&
      state.sourceSelection?.instance_key === obj.instance_key;
    const selected = manualSelected || sourceSelected;
    for (let dy = 0; dy < obj.h; dy++) {
      for (let dx = 0; dx < obj.w; dx++) {
        const mode = footprintMode(obj, dx, dy);
        if (mode === "void") continue;
        const collision = mode === "inherit" ? obj.collision : mode;
        c2d.fillStyle = collisionColor(collision).replace(/[\d.]+\)$/, "0.10)");
        c2d.fillRect(px + dx * tile, py + dy * tile, tile, tile);
      }
    }
    // Model Workshop objects also paint a translucent version of their TOP
    // material onto Maker Studio's normal map. This keeps the model's chosen
    // cross-tileset texture visible without replacing the underlying map tile.
    if (obj.model_id) {
      const topSource = objectMaterialSource(ctx, obj, obj.face_materials?.top || obj.material || null);
      if (topSource?.img) {
        c2d.save();
        c2d.globalAlpha = 0.46;
        c2d.imageSmoothingEnabled = false;
        c2d.drawImage(topSource.img, topSource.sx, topSource.sy, topSource.sw, topSource.sh, px, py, w, h);
        c2d.restore();
      }
    }
    // Region-meshed model cells are collision proxies. Keep only their top
    // material overlay on the normal Maker Studio map; the model outline below
    // communicates the group without drawing hundreds of per-cell boxes.
    if (obj.render === false && obj.model_id) { c2d.restore(); continue; }
    c2d.strokeStyle = collisionColor(obj.collision);
    c2d.lineWidth = Math.max(1.5, 2 * info.zoom);
    c2d.strokeRect(px, py, w, h);
    // V2 elevation cue: show a lightweight pseudo-extrusion directly on the
    // normal Maker Studio map. A maker should see at a glance that H3 is not a
    // flat tile, without opening Debug or reading numeric source ids.
    const visualHeight = Number(obj.height) || 0;
    if (visualHeight > 0 && ["mountain", "wall", "border"].includes(String(obj.category || ""))) {
      const lift = Math.min(tile * 0.38, Math.max(3, visualHeight * 2.3 * info.zoom));
      c2d.save();
      c2d.strokeStyle = "rgba(90,225,255,0.66)";
      c2d.lineWidth = Math.max(1, 1.2 * info.zoom);
      c2d.strokeRect(px - lift, py - lift, w, h);
      c2d.beginPath();
      c2d.moveTo(px, py); c2d.lineTo(px - lift, py - lift);
      c2d.moveTo(px + w, py); c2d.lineTo(px + w - lift, py - lift);
      c2d.moveTo(px, py + h); c2d.lineTo(px - lift, py + h - lift);
      c2d.moveTo(px + w, py + h); c2d.lineTo(px + w - lift, py + h - lift);
      c2d.stroke();
      c2d.restore();
    }
    const anchorY = py + (Math.min(obj.h - 1, Math.max(0, Number(obj.anchor_row) || 0)) + 1) * tile;
    c2d.save();
    c2d.setLineDash([3, 3]);
    c2d.strokeStyle = "rgba(255,210,80,0.9)";
    c2d.beginPath(); c2d.moveTo(px, anchorY); c2d.lineTo(px + w, anchorY); c2d.stroke();
    c2d.restore();
    if (selected) {
      c2d.setLineDash([6, 3]);
      c2d.strokeStyle = "rgba(80,220,255,0.95)";
      c2d.lineWidth = Math.max(2, 3 * info.zoom);
      c2d.strokeRect(px - 1, py - 1, w + 2, h + 2);
      c2d.setLineDash([]);
    }
    const label = obj.compiled
      ? `${selected ? "▸ " : ""}${simplePresetLabel(obj.category)} · ${Number(obj.height) || 0} tiles`
      : `${selected ? "▸ " : ""}${obj.name || `#${obj.id}`} · ${obj.type.toUpperCase()} · H${obj.height}`;
    if (tile >= 22 && (!obj.compiled || selected)) {
      c2d.font = `${Math.max(8, Math.min(10, tile * 0.30))}px sans-serif`;
      c2d.fillStyle = "rgba(8,12,18,0.75)";
      const lw = Math.min(w - 2, Math.max(20, c2d.measureText(label).width + 7));
      c2d.fillRect(px + 2, py + 2, lw, 14);
      c2d.fillStyle = "rgba(235,225,255,0.96)";
      c2d.textAlign = "left";
      c2d.fillText(label, px + 5, py + 9);
    }
    c2d.restore();
  }


  // Model Workshop instances: one readable outline per reusable model, on top of
  // the per-cell compiled geometry. This is what makes the normal Maker Studio
  // map itself reflect the model's shape/height instead of requiring preview.
  for (const inst of geo.model_instances || []) {
    const model = geo.models?.[inst.model_id]; if (!model) continue;
    const worldCells=[...expandedModelCells(inst,model).values()]; if(!worldCells.length)continue;
    const x0=Math.min(...worldCells.map(c=>c.x)),y0=Math.min(...worldCells.map(c=>c.y)),x1=Math.max(...worldCells.map(c=>c.x))+1,y1=Math.max(...worldCells.map(c=>c.y))+1;
    if(x1<minX||x0>maxX||y1<minY||y0>maxY)continue;
    const px=(x0*info.tileSize-info.viewportX)*info.zoom,py=(y0*info.tileSize-info.viewportY)*info.zoom,w=(x1-x0)*tile,h=(y1-y0)*tile;
    c2d.save();c2d.setLineDash([7,3]);c2d.strokeStyle='rgba(120,245,170,.95)';c2d.lineWidth=Math.max(2,2.5*info.zoom);c2d.strokeRect(px,py,w,h);c2d.setLineDash([]);
    if(tile>=20){c2d.font=`${Math.max(9,Math.min(11,tile*.32))}px sans-serif`;const txt=`▣ ${model.name}`;const lw=Math.min(w,Math.max(40,c2d.measureText(txt).width+8));c2d.fillStyle='rgba(8,18,14,.82)';c2d.fillRect(px+2,py+2,lw,15);c2d.fillStyle='rgba(165,255,205,.98)';c2d.textAlign='left';c2d.fillText(txt,px+5,py+10);}
    c2d.restore();
  }

  // Scene source selection must remain visible even before the user assigns a
  // definition (there may be no compiled object to outline yet).
  if (state.workspaceMode === "scene" && state.sourceSelection && Number(state.sourceSelection.map_id) === Number(info.mapId)) {
    const sx = Number(state.sourceSelection.x), sy = Number(state.sourceSelection.y);
    if (sx >= minX && sx <= maxX && sy >= minY && sy <= maxY) {
      const px = (sx * info.tileSize - info.viewportX) * info.zoom;
      const py = (sy * info.tileSize - info.viewportY) * info.zoom;
      c2d.save();
      c2d.setLineDash([5, 3]);
      c2d.strokeStyle = "rgba(80,220,255,0.98)";
      c2d.lineWidth = Math.max(2, 3 * info.zoom);
      c2d.strokeRect(px + 1, py + 1, Math.max(2, tile - 2), Math.max(2, tile - 2));
      c2d.setLineDash([]);
      if (tile >= 24) {
        const geoDef = geo.definitions?.[state.sourceSelection.key];
        const geoRule = geoDef ? effectiveSourceRule(geoDef, geo.instance_overrides?.[state.sourceSelection.instance_key]) : null;
        const txt = geoRule && geoRule.enabled !== false ? `${simplePresetLabel(geoRule.category)} · H${Number(geoRule.height) || 0}` : "Seleccionado";
        c2d.font = `${Math.max(8, Math.min(10, tile * 0.30))}px sans-serif`;
        const lw = Math.min(tile * 2.2, c2d.measureText(txt).width + 8);
        c2d.fillStyle = "rgba(8,12,18,0.82)"; c2d.fillRect(px + 2, py + tile - 15, lw, 13);
        c2d.fillStyle = "rgba(150,245,255,0.98)"; c2d.textAlign = "left"; c2d.fillText(txt, px + 5, py + tile - 8);
      }
      c2d.restore();
    }
  }

  // Object placement draft rectangle.
  if (state.objTool && state.objStart && state.objCurrent) {
    const ax = Math.min(state.objStart.x, state.objCurrent.x);
    const ay = Math.min(state.objStart.y, state.objCurrent.y);
    const bx = Math.max(state.objStart.x, state.objCurrent.x);
    const by = Math.max(state.objStart.y, state.objCurrent.y);
    const px = (ax * info.tileSize - info.viewportX) * info.zoom;
    const py = (ay * info.tileSize - info.viewportY) * info.zoom;
    const w = (bx - ax + 1) * tile;
    const h = (by - ay + 1) * tile;
    c2d.save();
    c2d.setLineDash([6, 4]);
    c2d.strokeStyle = "rgba(235,235,120,0.95)";
    c2d.lineWidth = Math.max(1.5, 2 * info.zoom);
    c2d.strokeRect(px, py, w, h);
    c2d.restore();
  }
  c2d.restore();
}


// -----------------------------------------------------------------------------
// 2.5D preview renderer
// -----------------------------------------------------------------------------

function ensurePreviewFocus(ctx, mapId) {
  const info = ctx.map.info(mapId);
  if (!info) return;
  if (!Number.isFinite(state.preview.focusX)) state.preview.focusX = Math.floor(info.width / 2);
  if (!Number.isFinite(state.preview.focusY)) state.preview.focusY = Math.floor(info.height / 2);
  state.preview.focusX = Math.max(0, Math.min(info.width - 1, Math.round(state.preview.focusX)));
  state.preview.focusY = Math.max(0, Math.min(info.height - 1, Math.round(state.preview.focusY)));
}

function disposeAutotileUrls() {
  for (const url of state.preview.autotileUrls) {
    try { URL.revokeObjectURL(url); } catch (_) {}
  }
  for (const url of state.preview.characterUrls || []) {
    try { URL.revokeObjectURL(url); } catch (_) {}
  }
  state.preview.autotileUrls = [];
  state.preview.autotileImages = [];
  state.preview.autotileImagesByTileset.clear();
  state.preview.autotileImagesByName.clear();
  state.preview.tilesetImages.clear();
  state.preview.tilesetImage = null;
  state.preview.autotileCache.clear();
  state.preview.transformedSourceCache.clear();
  state.preview.characterUrls = [];
  state.preview.characterImages.clear();
}

function loadImage(url) {
  return new Promise((resolve) => {
    if (!url) { resolve(null); return; }
    const img = new Image();
    img.onload = () => resolve(img);
    img.onerror = () => resolve(null);
    img.src = url;
  });
}

function mimeForName(name) {
  const lower = String(name || "").toLowerCase();
  if (lower.endsWith(".jpg") || lower.endsWith(".jpeg")) return "image/jpeg";
  if (lower.endsWith(".webp")) return "image/webp";
  if (lower.endsWith(".gif")) return "image/gif";
  if (lower.endsWith(".bmp")) return "image/bmp";
  return "image/png";
}

async function imageFromBytes(bytes, mime = "image/png", urlBucket = state.preview.autotileUrls) {
  if (!bytes || !bytes.length) return null;
  const blob = new Blob([new Uint8Array(bytes)], { type: mime });
  const url = URL.createObjectURL(blob);
  urlBucket.push(url);
  return await loadImage(url);
}

function autotileCacheName(name) {
  return String(name || "").replace(/\.[^.]+$/, "").trim().toLowerCase();
}

function firstDefined(...values) {
  for (const value of values) if (value !== undefined && value !== null) return value;
  return undefined;
}

function layerRef(layer) {
  return firstDefined(layer?.index, layer?.id, layer);
}

function layerSortValue(layer) {
  return Number(firstDefined(layer?.index, layer?.order, layer?.z, layer?.id, 0)) || 0;
}

function normalizedTileData(raw, fallbackTileId = 0, layer = null) {
  const out = raw && typeof raw === "object" ? { ...raw } : {};
  const tileId = Number(firstDefined(out.tileId, out.tile_id, fallbackTileId)) || 0;
  const tilesetId = Number(firstDefined(
    out.tilesetId, out.tileset_id, out.sourceTilesetId, out.source_tileset_id,
    layer?.tilesetId, layer?.tileset_id, layer?.sourceTilesetId, layer?.source_tileset_id
  )) || 0;
  const autotileName = String(firstDefined(out.autotileName, out.autotile_name, "")).trim();
  const autotilePattern = firstDefined(out.autotilePattern, out.autotile_pattern);
  const terrainTag = firstDefined(out.terrainTag, out.terrain_tag);

  out.tileId = tileId;
  if (tilesetId) out.tilesetId = tilesetId;
  if (autotileName) out.autotileName = autotileName;
  if (autotilePattern !== undefined) out.autotilePattern = Number(autotilePattern) || 0;
  if (terrainTag !== undefined) out.terrainTag = Number(terrainTag) || 0;
  out.flipH = !!firstDefined(out.flipH, out.flip_h, false);
  out.flipV = !!firstDefined(out.flipV, out.flip_v, false);
  return out;
}

async function loadAutotileByName(ctx, rawName) {
  const name = String(rawName || "").replace(/\.[^.]+$/, "").trim();
  if (!name) return null;
  const key = autotileCacheName(name);
  if (state.preview.autotileImagesByName.has(key)) return state.preview.autotileImagesByName.get(key);
  // Mark as pending so repeated scans don't issue duplicate backend reads.
  state.preview.autotileImagesByName.set(key, null);
  const root = ctx.editor.gameRoot?.();
  const invoke = window.__TAURI__?.core?.invoke;
  if (!root || !invoke) return null;
  try {
    const bytes = await invoke("get_graphic_image", { gameRoot: root, folder: "Autotiles", name });
    const img = await imageFromBytes(bytes, "image/png");
    state.preview.autotileImagesByName.set(key, img || null);
    return img || null;
  } catch (err) {
    // Case/extension-safe fallback through the public general file commands.
    try {
      const files = await invoke("list_autotile_files", { gameRoot: root });
      const wanted = key;
      const hit = (files || []).find((f) => autotileCacheName(f) === wanted);
      if (hit) {
        const imgName = String(hit).replace(/\.[^.]+$/, "");
        const bytes = await invoke("get_graphic_image", { gameRoot: root, folder: "Autotiles", name: imgName });
        const img = await imageFromBytes(bytes, "image/png");
        state.preview.autotileImagesByName.set(key, img || null);
        return img || null;
      }
    } catch (_) {}
    ctx.log.warn(`2.5D Geometry: autotile '${name}' unavailable`, err);
    state.preview.autotileImagesByName.set(key, null);
    return null;
  }
}

async function loadAutotilesViaTauri(ctx, names) {
  if (!Array.isArray(names)) return [];
  const out = [];
  for (const rawName of names.slice(0, 7)) {
    const name = String(rawName || "").replace(/\.[^.]+$/, "").trim();
    if (!name) { out.push(null); continue; }
    out.push(await loadAutotileByName(ctx, name));
  }
  return out;
}

async function loadTilesetFallback(ctx, tilesetId) {
  const root = ctx.editor.gameRoot?.();
  const invoke = window.__TAURI__?.core?.invoke;
  const ts = tilesetInfo(ctx, tilesetId) || null;
  let tilesetName = tilesetGraphicName(ts);
  // Editor may not report the cross-tileset this map references (e.g. tileset 5
  // used only by MapXXX while 1 is open). Read the name straight from Tilesets.rxdata.
  if (!tilesetName) tilesetName = state.preview.rxTilesets?.[Number(tilesetId)]?.tilesetName || "";
  if (!root || !invoke || !tilesetName) return null;
  try {
    const bytes = await invoke("get_tileset_image", { gameRoot: root, tilesetName });
    return await imageFromBytes(bytes, "image/png");
  } catch (_) {}
  try {
    const bytes = await invoke("get_graphic_image", { gameRoot: root, folder: "Tilesets", name: tilesetName });
    return await imageFromBytes(bytes, "image/png");
  } catch (_) {}
  return null;
}

async function loadCharacterImage(ctx, name) {
  name = String(name || "");
  if (!name) return null;
  if (state.preview.characterImages.has(name)) return state.preview.characterImages.get(name);
  state.preview.characterImages.set(name, null); // prevent duplicate loads
  const root = ctx.editor.gameRoot?.();
  const invoke = window.__TAURI__?.core?.invoke;
  if (!root || !invoke) return null;
  try {
    const bytes = await invoke("get_graphic_image", { gameRoot: root, folder: "Characters", name });
    const img = await imageFromBytes(bytes, "image/png", state.preview.characterUrls);
    state.preview.characterImages.set(name, img);
    schedulePreview(ctx);
    return img;
  } catch (_) {
    return null;
  }
}


async function loadModelTextureImage(ctx, rawName, force = false) {
  let name=String(rawName||'').replace(/\\/g,'/').replace(/^Graphics\/Models\//i,'').replace(/^\/+/, '');
  if(!name)return null;
  const key=name.toLowerCase();
  if(!force && state.preview.modelImages.has(key)) return state.preview.modelImages.get(key);
  state.preview.modelImages.set(key,null);
  const root=String(ctx.editor.gameRoot?.()||'').replace(/[\\/]+$/,'');
  const invoke=window.__TAURI__?.core?.invoke; if(!root||!invoke)return null;
  const full=`${root}/Graphics/Models/${name}${/\.[a-z0-9]+$/i.test(name)?'':'.png'}`;
  try{
    const bytes=await invoke('read_binary_file',{path:full});
    const img=await imageFromBytes(bytes,'image/png',state.preview.modelImageUrls);
    state.preview.modelImages.set(key,img); schedulePreview(ctx); return img;
  }catch(_){state.preview.modelImages.set(key,null);return null;}
}

async function ensureExternalModelTextures(ctx, geo, force=false) {
  const names=new Set();
  const add=m=>{if(m?.kind==='image'&&m.graphic)names.add(String(m.graphic));};
  for(const model of Object.values(geo?.models||{}))for(const part of model?.parts||[]){add(part.material);for(const m of Object.values(part.face_materials||{}))add(m);for(const f of part.custom_faces||[])add(f?.material);}
  for(const f of geo?.mesh_faces||[])add(f?.material);
  await Promise.allSettled([...names].map(n=>loadModelTextureImage(ctx,n,force)));
}

async function preloadEventGraphics(ctx, mapId) {
  if (!state.preview.showEvents || !ctx.events?.list || !ctx.events?.getFull) return;
  const events = ctx.events.list(mapId) || [];
  const jobs = [];
  for (const ev of events) {
    try {
      const full = ctx.events.getFull(mapId, ev.id);
      const page = full?.pages?.[0];
      const name = page?.graphic?.character_name;
      if (name && !state.preview.characterImages.has(name)) jobs.push(loadCharacterImage(ctx, name));
    } catch (_) {}
  }
  if (jobs.length) await Promise.allSettled(jobs);
}

async function ensureTilesetResourceSet(ctx, tilesetId) {
  tilesetId = Number(tilesetId) || 0;
  if (!tilesetId) return null;
  if (state.preview.tilesetImages.has(tilesetId)) {
    return {
      image: state.preview.tilesetImages.get(tilesetId),
      autotiles: state.preview.autotileImagesByTileset.get(tilesetId) || [],
    };
  }
  if (state.preview.tilesetLoading.has(tilesetId)) return state.preview.tilesetLoading.get(tilesetId);

  const job = (async () => {
  // Source of truth: the editor tileset API. Maker Studio can paint cross-tileset
  // tiles on extended layers, so load by source tileset id, not the open palette.
  let image = null;
  try {
    const url = await ctx.tileset.getImageBlobUrl?.(tilesetId);
    if (url) image = await loadImage(url);
  } catch (err) {
    ctx.log.warn(`2.5D Geometry: getImageBlobUrl failed for tileset ${tilesetId}`, err);
  }
  if (!image) {
    image = await loadTilesetFallback(ctx, tilesetId);
  }
  if (!image) {
    const ts = tilesetInfo(ctx, tilesetId);
    ctx.log.warn(`2.5D Geometry: tileset ${tilesetId} unavailable (${tilesetGraphicName(ts) || ts?.name || "sin nombre"})`);
  }

  let autotiles = [];
  try {
    const ts = tilesetInfo(ctx, tilesetId);
    let names = firstDefined(ts?.autotileNames, ts?.autotile_names, ts?.autotiles, []);
    if (!names?.length) names = state.preview.rxTilesets?.[tilesetId]?.autotileNames || [];
    autotiles = await loadAutotilesViaTauri(ctx, names);
  } catch (err) {
    ctx.log.warn(`2.5D Geometry: autotiles ${tilesetId} unavailable`, err);
  }
  state.preview.tilesetImages.set(tilesetId, image || null);
  state.preview.autotileImagesByTileset.set(tilesetId, autotiles || []);
  return { image, autotiles };
  })();
  state.preview.tilesetLoading.set(tilesetId, job);
  try { return await job; }
  finally { state.preview.tilesetLoading.delete(tilesetId); }
}

function previewBounds(ctx, mapId) {
  const info = ctx.map.info(mapId);
  if (!info) return null;
  const fx = Math.round(state.preview.focusX ?? info.width / 2);
  const fy = Math.round(state.preview.focusY ?? info.height / 2);
  const radius = state.preview.orbiting ? Math.min(state.preview.radius, 4) : state.preview.radius;
  return {
    minX: state.preview.fullMap ? 0 : Math.max(0, fx - radius),
    maxX: state.preview.fullMap ? info.width - 1 : Math.min(info.width - 1, fx + radius),
    minY: state.preview.fullMap ? 0 : Math.max(0, fy - radius),
    maxY: state.preview.fullMap ? info.height - 1 : Math.min(info.height - 1, fy + radius),
  };
}

async function scanMapUsedAssets(ctx, mapId, force = false) {
  const info = ctx.map.info(mapId);
  if (!info) return { tilesetIds: new Set(), extraAutotiles: new Set() };
  if (!force && state.preview.usedAssetsByMap.has(mapId)) return state.preview.usedAssetsByMap.get(mapId);

  const result = {
    tilesetIds: new Set([mapTilesetId(info, mapId)]),
    extraAutotiles: new Set(),
  };
  const layers = visibleLayers(ctx, mapId);

  // Cross-tileset source information lives on each extended tile. Native layers
  // still use the map tileset, but may contain extra autotiles, so scan both.
  for (let y = 0; y < info.height; y++) {
    for (let x = 0; x < info.width; x++) {
      for (const layer of layers) {
        const data = readTileVisualData(ctx, mapId, layer, x, y);
        if (!data) continue;
        const sourceId = Number(data.tilesetId) || 0;
        if (sourceId) result.tilesetIds.add(sourceId);
        const extra = String(data.autotileName || "").trim();
        if (extra) result.extraAutotiles.add(extra);
      }
    }
  }
  result.tilesetIds.delete(0);
  state.preview.usedAssetsByMap.set(mapId, result);
  return result;
}

async function ensureSceneTilesetResources(ctx, mapId, force = false) {
  const info = ctx.map.info(mapId);
  const bounds = previewBounds(ctx, mapId);
  if (!info || !bounds) return;

  // Load every source tileset actually referenced anywhere in the map. This is
  // what makes a tile painted from another Maker Studio palette render with its
  // own atlas instead of the map's native tileset.
  const used = await scanMapUsedAssets(ctx, mapId, force);
  const ids = new Set(used.tilesetIds || []);
  const extraAutotiles = new Set(used.extraAutotiles || []);

  // Small local safety pass: catches an edit immediately before the global asset
  // inventory is invalidated/rebuilt.
  const layers = visibleLayers(ctx, mapId);
  for (let y = bounds.minY; y <= bounds.maxY; y++) {
    for (let x = bounds.minX; x <= bounds.maxX; x++) {
      for (const layer of layers) {
        const data = readTileVisualData(ctx, mapId, layer, x, y);
        if (!data) continue;
        const sourceId = Number(data.tilesetId) || mapTilesetId(info, mapId);
        if (sourceId) ids.add(sourceId);
        const extra = String(data.autotileName || "").trim();
        if (extra) extraAutotiles.add(extra);
      }
    }
  }

  await Promise.allSettled([...ids].map((id) => ensureTilesetResourceSet(ctx, id)));
  if (extraAutotiles.size) await Promise.allSettled([...extraAutotiles].map((name) => loadAutotileByName(ctx, name)));
  // Object material textures may reference tilesets that are not painted on the map.
  const geo = state.maps.get(mapId);
  for (const obj of sceneObjects(geo)) {
    const mats=[obj?.material,...Object.values(obj?.face_materials||{})].filter(Boolean);
    for(const mat of mats){
      const mid=Number(mat?.tileset_id);
      if(mid&&!ids.has(mid)){ids.add(mid);await ensureTilesetResourceSet(ctx,mid);}
    }
  }
  // Mesh faces are the canonical material source for Part Modeler models.
  for (const face of geo?.mesh_faces || []) {
    const mid=Number(face?.material?.tileset_id)||0;
    if(mid&&!ids.has(mid)){ids.add(mid);await ensureTilesetResourceSet(ctx,mid);}
  }
  const active = state.preview.tilesetImages.get(mapTilesetId(info, mapId));
  if (active !== undefined) state.preview.tilesetImage = active;
  state.preview.autotileImages = state.preview.autotileImagesByTileset.get(mapTilesetId(info, mapId)) || [];
  state.preview.assetStats.usedTilesets = ids.size;
  state.preview.assetStats.usedTilesetIds = [...ids].sort((a, b) => Number(a) - Number(b)).join(",");
}

async function ensureVisiblePreviewResources(ctx, mapId) {
  const info = ctx.map.info(mapId);
  const bounds = previewBounds(ctx, mapId);
  if (!info || !bounds) return;
  const ids = new Set([mapTilesetId(info, mapId)]);
  const extras = new Set();
  const layers = visibleLayers(ctx, mapId);
  for (let y = bounds.minY; y <= bounds.maxY; y++) {
    for (let x = bounds.minX; x <= bounds.maxX; x++) {
      for (const layer of layers) {
        const data = readTileVisualData(ctx, mapId, layer, x, y);
        if (!data) continue;
        const sid = Number(data.tilesetId) || (layer?.kind === "native" ? mapTilesetId(info, mapId) : 0);
        if (sid) ids.add(sid);
        const extra = String(data.autotileName || "").trim();
        if (extra) extras.add(extra);
      }
    }
  }
  const geo = state.maps.get(mapId);
  for (const obj of sceneObjects(geo)) {
    for (const mat of [obj?.material, ...Object.values(obj?.face_materials || {})].filter(Boolean)) {
      const sid = Number(mat?.tileset_id) || 0;
      if (sid) ids.add(sid);
    }
  }
  for (const face of geo?.mesh_faces || []) {
    const sid=Number(face?.material?.tileset_id)||0;
    if(sid) ids.add(sid);
  }
  ids.delete(0);
  await Promise.allSettled([...ids].map(id => ensureTilesetResourceSet(ctx, id)));
  if (extras.size) await Promise.allSettled([...extras].map(name => loadAutotileByName(ctx, name)));
  state.preview.assetStats.usedTilesets = ids.size;
  state.preview.assetStats.usedTilesetIds = [...ids].sort((a,b)=>a-b).join(",");
}

async function ensureChangedCellResources(ctx, mapId, x, y, preferredLayer = null) {
  const info = ctx.map.info(mapId);
  if (!info) return;
  const layers = authoritativeLayers(ctx, mapId, false);
  const ordered = [...layers].sort((a,b)=>layerSortValue(b)-layerSortValue(a));
  if (preferredLayer != null) {
    const idx = ordered.findIndex(l => Number(layerRef(l)) === Number(preferredLayer));
    if (idx > 0) ordered.unshift(...ordered.splice(idx, 1));
  }
  const jobs = [];
  for (const layer of ordered) {
    const data = readTileVisualData(ctx, mapId, layer, x, y);
    if (!data) continue;
    const sid = Number(data.tilesetId) || (layer?.kind === "native" ? mapTilesetId(info, mapId) : 0);
    if (sid && !state.preview.tilesetImages.has(sid)) jobs.push(ensureTilesetResourceSet(ctx, sid));
    const extra = String(data.autotileName || "").trim();
    if (extra && !state.preview.autotileImagesByName.has(extra.toLowerCase())) jobs.push(loadAutotileByName(ctx, extra));
  }
  if (jobs.length) await Promise.allSettled(jobs);
}

function scheduleBackgroundMapRefresh(ctx, mapId, delay = 700) {
  // Full source inventory is legacy/Advanced functionality. The normal Terrain
  // workflow never scans the whole map in the background.
  const geo = state.maps.get(mapId);
  const needsLegacy = !!state.uiAdvanced || !!(geo?.definitions && Object.keys(geo.definitions).length);
  if (!needsLegacy) return;
  clearTimeout(state.sourceRefreshTimer);
  state.sourceRefreshTimer = setTimeout(async () => {
    state.sourceRefreshTimer = 0;
    if (!state.maps.has(mapId)) return;
    try {
      await ensureLegacyAuthoringData(ctx, mapId, true);
      schedulePanelRefresh();
      markPreviewDirty(ctx);
    } catch (err) { ctx.log.warn("2.5D Geometry: lazy source refresh failed", err); }
  }, Math.max(400, delay));
}

async function ensurePreviewResources(ctx, mapId, force = false) {
  const info = ctx.map.info(mapId);
  if (!info) return;
  if (force) {
    state.preview.tileProps.clear();
    state.preview.autotileCache.clear();
    state.preview.transformedSourceCache.clear();
    state.preview.usedAssetsByMap.delete(mapId);
    state.preview.cellEntryCache.clear();
    state.preview.extendedDataByMap.delete(mapId);
    state.preview.rxMaps.delete(mapId);
    disposeAutotileUrls();
  }
  await ensureRxTilesets(ctx);
  await ensureRxMap(ctx, mapId);
  await loadEmbeddedExtendedData(ctx, mapId);
  const tilesetId = mapTilesetId(info, mapId);
  state.preview.tilesetId = tilesetId;
  await ensureTilesetResourceSet(ctx, tilesetId);
  state.preview.tilesetImage = state.preview.tilesetImages.get(tilesetId) || null;
  state.preview.autotileImages = state.preview.autotileImagesByTileset.get(tilesetId) || [];
  await ensureSceneTilesetResources(ctx, mapId, force);
  await ensureExternalModelTextures(ctx, state.maps.get(mapId), force);
  if (state.preview.showEvents) void preloadEventGraphics(ctx, mapId);
  schedulePreview(ctx);
}

function tileProps(ctx, tilesetId, tileId) {
  const key = `${tilesetId}:${tileId}`;
  if (state.preview.tileProps.has(key)) return state.preview.tileProps.get(key);
  let value = null;
  try { value = ctx.tileset.resolveTileProperties?.(tileId, tilesetId) || null; } catch (_) {}
  if (!value) { try { value = ctx.tileset.getTileProperties(tilesetId, tileId); } catch (_) {} }
  value ||= rxTilesetProps(ctx, tilesetId, tileId);
  value ||= { passage: 0, priority: 0, terrainTag: 0 };
  state.preview.tileProps.set(key, value);
  return value;
}

// Fallback tile properties straight from RPG::Tileset (terrain_tags/passages/
// priorities). Used when the editor cannot resolve a cross-tileset tile id.
function rxTilesetProps(ctx, tilesetId, tileId) {
  const ts = state.preview.rxTilesets?.[Number(tilesetId) || 0];
  if (!ts) return null;
  tileId = Number(tileId) || 0;
  if (tileId >= 384) {
    const index = tileId - 384;
    const tx = index % 8;
    const ty = Math.floor(index / 8);
    return {
      passage: Number(ts.passages?.get(tx, ty)) || 0,
      priority: Number(ts.priorities?.get(tx, ty)) || 0,
      terrainTag: Number(ts.terrainTags?.get(tx, ty)) || 0,
    };
  }
  return { passage: 0, priority: 0, terrainTag: 0 };
}

function autotileCanvasFromImage(img, pattern, keyPrefix) {
  if (!img) return null;
  pattern = Math.max(0, Math.min(47, Number(pattern) || 0));
  const key = `${keyPrefix}:${pattern}`;
  if (state.preview.autotileCache.has(key)) return state.preview.autotileCache.get(key);
  const parts = AUTOTILE_PARTS[pattern] || AUTOTILE_PARTS[0];
  const canvas = document.createElement("canvas");
  canvas.width = 32;
  canvas.height = 32;
  const c = canvas.getContext("2d");
  c.imageSmoothingEnabled = false;
  // RMXP autotiles are 96x128 per animation frame. Use the first frame for the
  // geometry preview; the editor's animation counter can be wired later.
  for (let i = 0; i < 4; i++) {
    const part = parts[i];
    const sx = (part % 6) * 16;
    const sy = Math.floor(part / 6) * 16;
    const dx = (i % 2) * 16;
    const dy = Math.floor(i / 2) * 16;
    c.drawImage(img, sx, sy, 16, 16, dx, dy, 16, 16);
  }
  state.preview.autotileCache.set(key, canvas);
  return canvas;
}

function autotileCanvas(tilesetId, index, pattern) {
  const images = state.preview.autotileImagesByTileset.get(Number(tilesetId)) || [];
  return autotileCanvasFromImage(images[index], pattern, `std:${tilesetId}:${index}`);
}

function extraAutotileCanvas(name, pattern) {
  const key = autotileCacheName(name);
  const img = state.preview.autotileImagesByName.get(key) || null;
  return autotileCanvasFromImage(img, pattern, `extra:${key}`);
}

function sourceForTile(tileId, tilesetId = state.preview.tilesetId) {
  const id = Number(tileId) || 0;
  const tsId = Number(tilesetId) || Number(state.preview.tilesetId) || 0;
  if (id <= 0 || !tsId) return null;
  if (id >= 384) {
    const img = state.preview.tilesetImages.get(tsId) || (tsId === Number(state.preview.tilesetId) ? state.preview.tilesetImage : null);
    if (!img) return null;
    const index = id - 384;
    return {
      img,
      sx: (index % 8) * 32,
      sy: Math.floor(index / 8) * 32,
      sw: 32,
      sh: 32,
    };
  }
  if (id >= 48 && id < 384) {
    const autotileIndex = Math.floor(id / 48) - 1;
    const pattern = id % 48;
    const img = autotileCanvas(tsId, autotileIndex, pattern);
    if (!img) return null;
    return { img, sx: 0, sy: 0, sw: 32, sh: 32 };
  }
  return null;
}



function embeddedTileVisualData(ctx, mapId, layer, x, y) {
  const ext = mapExtendedData(ctx, mapId);
  if (!ext) return null;
  const ref = Number(layerRef(layer));
  const key = cellKey(x,y);
  if (layer?.kind === "extended" || ref >= 3) {
    const row = (ext.layers || []).find(l => Number(firstDefined(l?.id,l?.index)) === ref);
    const td = row?.tiles?.[key];
    return td && typeof td === "object" ? td : null;
  }
  const np = ext.nativeProperties || ext.native_properties;
  const td = np?.[ref]?.[key] || np?.[String(ref)]?.[key];
  return td && typeof td === "object" ? td : null;
}

function readTileVisualData(ctx, mapId, layer, x, y) {
  const ref = Number(layerRef(layer));
  const xyKey = cellKey(x, y);

  // V2 SOURCE RESOLVER RULE:
  // Extended layers are authoritative through map.readTileData().  Maker Studio
  // stores the real cross-tileset source in PublicTileData.tilesetId there.
  // The old editor sometimes consumed layer.tiles first; those cached rows can
  // contain tileId without tilesetId, which made the preview sample the same atlas
  // position from the map's default tileset.  Always read the public API and let
  // it win over internal/cached layer data.
  let cachedRaw = null;
  if (layer?.tiles && typeof layer.tiles === "object") {
    cachedRaw = firstDefined(layer.tiles[xyKey], layer.tiles[y * (ctx.map.info(mapId)?.width || 0) + x]);
  }
  let apiRaw = null;
  try { apiRaw = ctx.map.readTileData?.(mapId, ref, x, y) || null; } catch (_) {}
  // The embedded @extended_layers JSON is the exact data used by MakerStudio's
  // in-game renderer. Merge it as a second authoritative source so the preview
  // still gets tileset_id when a Studio build returns a reduced PublicTileData.
  const embeddedRaw = embeddedTileVisualData(ctx, mapId, layer, x, y);

  const isExtended = layer?.kind === "extended" || ref >= 3;
  let raw = null;
  if (isExtended) {
    raw = {};
    if (cachedRaw && typeof cachedRaw === "object") Object.assign(raw, cachedRaw);
    if (embeddedRaw && typeof embeddedRaw === "object") Object.assign(raw, embeddedRaw);
    if (apiRaw && typeof apiRaw === "object") Object.assign(raw, apiRaw);
    if (!Object.keys(raw).length) raw = null;
  } else {
    raw = {};
    if (embeddedRaw && typeof embeddedRaw === "object") Object.assign(raw, embeddedRaw);
    if (cachedRaw && typeof cachedRaw === "object") Object.assign(raw, cachedRaw);
    if (apiRaw && typeof apiRaw === "object") Object.assign(raw, apiRaw);
    if (!Object.keys(raw).length) raw = null;
  }

  let data = normalizedTileData(raw, 0, layer);
  let tileId = Number(data?.tileId) || 0;
  if (!tileId) {
    try { tileId = Number(ctx.map.readTile(mapId, ref, x, y)) || 0; } catch (_) {}
    data = normalizedTileData(raw, tileId, layer);
  }
  if (layer.kind === "native") {
    // Source of truth for the base RMB/RMXP tile id is the raw RPG::Map table;
    // the editor API can report 0 or remapped ids for cross-tileset builds.
    const rxMapRow = mapId != null ? state.preview.rxMaps.get(mapId) : null;
    if (rxMapRow?.data) {
      let rxTile = 0;
      try { rxTile = Number(rxMapRow.data.get(x, y, ref)) || 0; } catch (_) {}
      if (rxTile) {
        tileId = rxTile;
        // Force the raw table value over whatever the editor reported; native
        // tiles must match the in-game RPG::Map table exactly.
        data = normalizedTileData({ ...(data || {}), tileId: rxTile }, rxTile, layer);
      }
    }
    let native = null;
    const extData = mapExtendedData(ctx, mapId);
    const nativeProps = extData?.nativeProperties;
    if (nativeProps) native = nativeProps[ref]?.[xyKey] || nativeProps[String(ref)]?.[xyKey] || null;
    let apiNative = null;
    try { apiNative = ctx.map.getNativeTileProperties?.(mapId, ref, x, y) || null; } catch (_) {}
    data = normalizedTileData({ ...(native || {}), ...(apiNative || {}), ...(data || {}) }, tileId, layer);
  } else {
    data = normalizedTileData(data, tileId, layer);
  }
  // Maker Studio extra autotiles can live on native/extended layers with an
  // autotileName even when the normal RMXP tile id is 0/reserved. Do not drop
  // those cells before the preview has a chance to resolve their graphic.
  if (!tileId && !String(data?.autotileName || "").trim()) return null;
  return data;
}


function detectColorModel(ctx) {
  if (state.preview.colorModel && state.preview.colorModel !== "auto") return state.preview.colorModel;
  try {
    const brush = ctx?.editor?.brushTileProperties?.() || {};
    const sat = Number(brush.saturation);
    const light = Number(brush.lighting);
    // Maker Studio builds that expose colour controls as deltas use 0 as the
    // neutral point. Older/alternate builds can expose percentages (100 neutral).
    if (Number.isFinite(sat) && Number.isFinite(light)) {
      if (Math.abs(sat) <= 1 && Math.abs(light) <= 1) return "delta";
      if (sat >= 50 || light >= 50) return "percent";
    }
  } catch (_) {}
  return "delta";
}

function normalizedColorProps(ctx, data) {
  if (state.preview.ignoreColorTransforms) return { hue: 0, saturation: 100, lighting: 100 };
  const model = detectColorModel(ctx);
  const hue = Number(data?.hue) || 0;
  const rawSat = data?.saturation == null ? (model === "delta" ? 0 : 100) : Number(data.saturation);
  const rawLight = data?.lighting == null ? (model === "delta" ? 0 : 100) : Number(data.lighting);
  if (model === "delta") {
    return {
      hue,
      saturation: Math.max(0, Math.min(300, 100 + (Number.isFinite(rawSat) ? rawSat : 0))),
      lighting: Math.max(5, Math.min(300, 100 + (Number.isFinite(rawLight) ? rawLight : 0))),
    };
  }
  return {
    hue,
    saturation: Math.max(0, Math.min(300, Number.isFinite(rawSat) ? rawSat : 100)),
    lighting: Math.max(5, Math.min(300, Number.isFinite(rawLight) ? rawLight : 100)),
  };
}

function transformedSource(ctx, source, data, cacheKey) {
  if (!source) return null;
  const rotation = ((Number(data?.rotation) || 0) % 360 + 360) % 360;
  const flipH = !!data?.flipH;
  const flipV = !!data?.flipV;
  const color = normalizedColorProps(ctx, data);
  const hue = color.hue;
  const saturation = color.saturation;
  const lighting = color.lighting;
  if (!rotation && !flipH && !flipV && !hue && saturation === 100 && lighting === 100) return source;
  const key = `${cacheKey}|r${rotation}|h${flipH?1:0}|v${flipV?1:0}|u${hue}|s${saturation}|l${lighting}`;
  if (state.preview.transformedSourceCache.has(key)) return state.preview.transformedSourceCache.get(key);
  const canvas = document.createElement("canvas");
  canvas.width = 32;
  canvas.height = 32;
  const c = canvas.getContext("2d");
  c.imageSmoothingEnabled = false;
  c.save();
  c.translate(16, 16);
  c.rotate(rotation * Math.PI / 180);
  c.scale(flipH ? -1 : 1, flipV ? -1 : 1);
  c.filter = `hue-rotate(${hue}deg) saturate(${Math.max(0, saturation)}%) brightness(${Math.max(0, lighting)}%)`;
  c.drawImage(source.img, source.sx, source.sy, source.sw, source.sh, -16, -16, 32, 32);
  c.restore();
  const out = { img: canvas, sx: 0, sy: 0, sw: 32, sh: 32 };
  state.preview.transformedSourceCache.set(key, out);
  return out;
}

function sourceForTileData(ctx, tileId, data, layer, tilesetId) {
  let source = null;
  const extraName = String(data?.autotileName || "").trim();
  if (extraName) {
    const pattern = Number.isFinite(Number(data?.autotilePattern))
      ? Number(data.autotilePattern)
      : ((Number(tileId) || 0) % 48);
    const img = extraAutotileCanvas(extraName, pattern);
    if (img) source = { img, sx: 0, sy: 0, sw: 32, sh: 32 };
  }
  if (!source) {
    const extended = layer?.kind === "extended" || Number(layerRef(layer)) >= 3;
    // Never sample a regular extended-layer tile from the map's base atlas when
    // its source tileset is unknown. Wrong graphics are worse than an explicit
    // unresolved cell; current Maker Studio exposes the real id via readTileData.
    if (extended && Number(tileId) >= 384 && !Number(tilesetId)) return null;
    source = sourceForTile(tileId, tilesetId);
  }
  return transformedSource(ctx, source, data, `${tilesetId}:${tileId}:${layerRef(layer)}:${extraName}`);
}


// -----------------------------------------------------------------------------
// Geometry Scene Compiler
// -----------------------------------------------------------------------------

function authoritativeLayers(ctx, mapId, includeHidden = false) {
  let layers = [];
  try { layers = (ctx.map.layers(mapId) || []).filter((l) => l && l.kind !== "shadow"); } catch (_) {}
  const byRef = new Map(layers.map((l) => [Number(layerRef(l)), l]));
  // Also union the embedded @extended_layers list used by MakerStudio runtime.
  // This covers projects/builds where a deferred layer exists in the map data
  // but is not fully surfaced by map.layers() yet.
  const ext = mapExtendedData(ctx, mapId);
  for (const row of ext?.layers || []) {
    const ref = Number(firstDefined(row?.id,row?.index));
    if (!Number.isFinite(ref) || byRef.has(ref)) continue;
    const layer = { ...row, id: ref, index: ref, kind: ref >= 3 ? "extended" : "native", visible: row.visible !== false, opacity: row.opacity ?? 1 };
    layers.push(layer); byRef.set(ref, layer);
  }
  for (let i = 0; i < 3; i++) if (!byRef.has(i)) layers.push({ index: i, id: i, kind: "native", name: `Layer ${i + 1}`, visible: true, opacity: 1 });
  return layers.filter((l) => includeHidden || l.visible !== false).sort((a, b) => layerSortValue(a) - layerSortValue(b));
}

function standardAutotileName(ctx, tilesetId, tileId) {
  const index = Math.floor((Number(tileId) || 0) / 48) - 1;
  if (index < 0) return "";
  const info = tilesetInfo(ctx, tilesetId);
  const names = info?.autotileNames || info?.autotile_names || state.preview.rxTilesets?.[Number(tilesetId)]?.autotileNames || [];
  return String(names?.[index] || "").trim();
}

function sourceDescriptor(ctx, mapId, layer, x, y, data = null) {
  const info = ctx.map.info(mapId);
  if (!info) return null;
  data ||= readTileVisualData(ctx, mapId, layer, x, y);
  if (!data) return null;
  const tileId = Number(data.tileId) || 0;
  const extended = layer?.kind === "extended" || Number(layerRef(layer)) >= 3;
  const sourceTilesetId = Number(data.tilesetId) || (extended ? 0 : mapTilesetId(info, mapId));
  const extraName = String(data.autotileName || "").trim();
  let kind = "tile", key = "", graphic = "", pattern = 0, autotileIndex = -1;
  if (extraName) {
    kind = "autotile";
    graphic = extraName;
    pattern = Number.isFinite(Number(data.autotilePattern)) ? Number(data.autotilePattern) : (tileId % 48);
    key = `extra:${extraName.toLowerCase()}`;
  } else if (tileId > 0 && tileId < 384) {
    kind = "autotile";
    autotileIndex = Math.floor(tileId / 48) - 1;
    pattern = tileId % 48;
    graphic = standardAutotileName(ctx, sourceTilesetId, tileId);
    key = `ts:${sourceTilesetId}:autotile:${autotileIndex}`;
  } else if (tileId >= 384) {
    if (!sourceTilesetId) return null;
    kind = "tile";
    graphic = tilesetGraphicName(tilesetInfo(ctx, sourceTilesetId));
    key = `ts:${sourceTilesetId}:tile:${tileId}`;
  } else {
    return null;
  }
  const ref = Number(layerRef(layer));
  const instanceKey = `L${ref}@${x},${y}|${key}`;
  const transform = {
    rotation: normalizeRotation(data.rotation),
    flip_h: !!data.flipH,
    flip_v: !!data.flipV,
    opacity: data.opacity == null ? 255 : Number(data.opacity),
    hue: Number(data.hue) || 0,
    saturation: data.saturation == null ? 100 : Number(data.saturation),
    lighting: data.lighting == null ? 0 : Number(data.lighting),
  };
  const descriptor = {
    key,
    instance_key: instanceKey,
    kind,
    map_id: mapId,
    layer: ref,
    layer_name: String(layer.name || `Layer ${ref}`),
    layer_kind: layer.kind || (ref < 3 ? "native" : "extended"),
    x, y,
    tile_id: tileId,
    tileset_id: sourceTilesetId,
    graphic,
    autotile_index: autotileIndex,
    autotile_pattern: pattern,
    transform,
  };
  descriptor.label = kind === "autotile"
    ? `${graphic || `Autotile ${autotileIndex}`} · TS ${sourceTilesetId || "extra"}`
    : `${graphic || `Tileset ${sourceTilesetId}`} · tile ${tileId}`;
  return descriptor;
}

function materialFromSourceDescriptor(desc) {
  if (!desc) return null;
  const t = desc.transform || {};
  if (desc.kind === "autotile") {
    // Runtime uses its expanded autotile strip. Standard RMXP autotiles keep
    // their real tile id; Maker Studio named/extra autotiles use the virtual
    // slot 8 (same convention as 012_MakerStudioBridge.rb).
    const tid = desc.graphic && String(desc.key).startsWith("extra:")
      ? 8 * 48 + (Number(desc.autotile_pattern) || 0)
      : Number(desc.tile_id) || (Number(desc.autotile_pattern) || 0);
    return {
      kind: "autotile",
      source_key: String(desc.key || ""),
      tileset_id: Number(desc.tileset_id) || 0,
      graphic: String(desc.graphic || ""),
      tile_id: Number(desc.tile_id) || 0,
      autotile_tid: tid,
      autotile_pattern: Number(desc.autotile_pattern) || 0,
      rotation: Number(t.rotation) || 0,
      flip_h: !!t.flip_h,
      flip_v: !!t.flip_v,
      opacity: Number.isFinite(Number(t.opacity)) ? Number(t.opacity) : 255,
      hue: Number(t.hue) || 0,
      saturation: Number.isFinite(Number(t.saturation)) ? Number(t.saturation) : 100,
      lighting: Number(t.lighting) || 0,
    };
  }
  const index = Math.max(0, (Number(desc.tile_id) || 384) - 384);
  return {
    kind: "tileset",
    source_key: String(desc.key || ""),
    tileset_id: Number(desc.tileset_id) || 0,
    graphic: String(desc.graphic || ""),
    tile_id: Number(desc.tile_id) || 0,
    src_rect: { x: (index % 8) * TILE_SIZE, y: Math.floor(index / 8) * TILE_SIZE, w: TILE_SIZE, h: TILE_SIZE },
    rotation: Number(t.rotation) || 0,
    flip_h: !!t.flip_h,
    flip_v: !!t.flip_v,
    opacity: Number.isFinite(Number(t.opacity)) ? Number(t.opacity) : 255,
    hue: Number(t.hue) || 0,
    saturation: Number.isFinite(Number(t.saturation)) ? Number(t.saturation) : 100,
    lighting: Number(t.lighting) || 0,
  };
}

function definitionFromPreset(sourceKey, label, presetName = "wall") {
  const preset = SCENE_GEOMETRY_PRESETS[presetName] || SCENE_GEOMETRY_PRESETS.wall;
  return normalizeSourceDefinition({ ...preset, source_key: sourceKey, label, components: { ...preset.components } }, sourceKey);
}

function effectiveSourceRule(def, override) {
  if (!def) return null;
  const out = { ...def, components: { ...(def.components || {}) } };
  if (override && typeof override === "object") {
    for (const key of ["category", "type", "height", "anchor_z", "collision", "characters_in_front"]) {
      if (override[key] != null) out[key] = override[key];
    }
    if (override.components) out.components = { ...out.components, ...override.components };
    if (override.disabled === true) out.enabled = false;
    if (override.disabled === false) out.enabled = true;
  }
  return out;
}

function compiledObjectFromDescriptor(desc, rule, id) {
  const material = materialFromSourceDescriptor(desc);
  return {
    id,
    name: `${rule.label || desc.label} @ ${desc.x},${desc.y} L${desc.layer}`,
    compiled: true,
    source_key: desc.key,
    instance_key: desc.instance_key,
    source: {
      map_id: desc.map_id, layer: desc.layer, x: desc.x, y: desc.y,
      tileset_id: desc.tileset_id, tile_id: desc.tile_id,
      autotile_name: desc.kind === "autotile" ? desc.graphic : undefined,
      autotile_pattern: desc.kind === "autotile" ? desc.autotile_pattern : undefined,
    },
    type: rule.type === "plane" ? "plane" : "cube",
    x: desc.x, y: desc.y, w: 1, h: 1,
    height: Math.max(0, Number(rule.height) || 0),
    anchor_z: Math.max(0, Number(rule.anchor_z) || 0),
    anchor_row: 0,
    rotation: 0,
    collision: OBJECT_COLLISIONS.includes(rule.collision) ? rule.collision : "solid",
    category: rule.category || "custom",
    characters_in_front: rule.characters_in_front === true || rule.components?.occlusion === "behind",
    footprint: {},
    components: { ...(rule.components || {}) },
    material,
  };
}

async function scanGeometrySources(ctx, mapId, force = false) {
  if (!force && state.sourceUsageByMap.has(mapId)) return state.sourceUsageByMap.get(mapId);
  const info = ctx.map.info(mapId);
  if (!info) return null;
  const layers = authoritativeLayers(ctx, mapId, false);
  const sources = new Map();
  const placements = [];
  const usedTilesetIds = new Set([mapTilesetId(info, mapId)]);
  const usedExtraAutotiles = new Set();
  let placed = 0;
  for (let y = 0; y < info.height; y++) {
    for (let x = 0; x < info.width; x++) {
      for (const layer of layers) {
        const data = readTileVisualData(ctx, mapId, layer, x, y);
        if (!data) continue;
        const desc = sourceDescriptor(ctx, mapId, layer, x, y, data);
        if (!desc) continue;
        placed++;
        placements.push(desc);
        if (desc.tileset_id) usedTilesetIds.add(Number(desc.tileset_id));
        if (desc.kind === "autotile" && String(desc.key).startsWith("extra:") && desc.graphic) usedExtraAutotiles.add(desc.graphic);
        let row = sources.get(desc.key);
        if (!row) {
          row = { key: desc.key, label: desc.label, kind: desc.kind, tileset_id: desc.tileset_id, graphic: desc.graphic, count: 0, examples: [] };
          sources.set(desc.key, row);
        }
        row.count++;
        if (row.examples.length < 6) row.examples.push({ map_id: mapId, layer: desc.layer, x, y, tile_id: desc.tile_id, instance_key: desc.instance_key });
      }
    }
  }
  const usage = { map_id: mapId, placed_tiles: placed, sources, placements, scanned_at: new Date().toISOString() };
  state.sourceUsageByMap.set(mapId, usage);
  usedTilesetIds.delete(0);
  state.preview.usedAssetsByMap.set(mapId, { tilesetIds: usedTilesetIds, extraAutotiles: usedExtraAutotiles });
  if (mapId === ctx.editor.activeMapId()) {
    state.sourceUsage = usage;
    schedulePanelRefresh();
  }
  return usage;
}

async function compileGeometryScene(ctx, mapId, geo, { forceScan = false, reason = "manual" } = {}) {
  if (!geo || state.compilerBusy) return geo?.compiled_objects || [];
  state.compilerBusy = true;
  state.compilerReason = reason;
  try {
    const info = ctx.map.info(mapId);
    if (!info) return [];
    await ensureRxTilesets(ctx, false);
    await ensureRxMap(ctx, mapId, false);

    // One scanner, one source of truth. Geometry editing reuses this placement
    // cache; map.tile.changed/map.batch.changed invalidate it. This prevents a
    // full width×height×layers walk for every inspector tweak.
    const usage = await scanGeometrySources(ctx, mapId, forceScan);
    const placements = usage?.placements || [];
    const definitions = geo.definitions || {};
    const overrides = geo.instance_overrides || {};
    const compiled = [];
    let nextId = COMPILED_OBJECT_ID_BASE;
    for (const desc of placements) {
      const def = definitions[desc.key];
      if (!def) continue;
      const rule = effectiveSourceRule(def, overrides[desc.instance_key]);
      if (!rule || rule.enabled === false) continue;
      compiled.push(compiledObjectFromDescriptor(desc, rule, nextId++));
    }
    geo.compiled_objects = compiled;
    geo.compiler ||= {};
    geo.compiler.version = SCENE_COMPILER_VERSION;
    geo.compiler.auto_compile = geo.compiler.auto_compile !== false;
    geo.compiler.last_compile = new Date().toISOString();
    geo.compiler.stats = {
      placed_tiles: Number(usage?.placed_tiles) || placements.length,
      unique_sources: Number(usage?.sources?.size) || 0,
      defined_sources: Object.keys(definitions).length,
      compiled_objects: compiled.length,
    };
    if (mapId === ctx.editor.activeMapId()) {
      state.sourceUsage = usage;
      await ensureSceneTilesetResources(ctx, mapId, false);
      ctx.editor.requestRedraw();
      schedulePanelRefresh();
      schedulePreview(ctx);
    }
    return compiled;
  } finally {
    state.compilerBusy = false;
    state.compilerReason = "";
  }
}


function scheduleSceneCompile(ctx, mapId, reason = "map-change", delay = 120) {
  const geo = state.maps.get(mapId);
  if (!geo || geo.compiler?.auto_compile === false || !Object.keys(geo.definitions || {}).length) return;
  clearTimeout(state.compilerTimer);
  state.compilerTimer = setTimeout(() => {
    state.compilerTimer = 0;
    void compileGeometryScene(ctx, mapId, geo, { forceScan: false, reason }).then(() => saveMap(ctx, mapId, { skipCompile: true }));
  }, delay);
}

function sourceDescriptorAt(ctx, mapId, x, y, preferredLayer = null) {
  const layers = authoritativeLayers(ctx, mapId, false);
  const ordered = [...layers].sort((a, b) => layerSortValue(b) - layerSortValue(a));
  if (preferredLayer != null) {
    const idx = ordered.findIndex((l) => Number(layerRef(l)) === Number(preferredLayer));
    if (idx > 0) ordered.unshift(...ordered.splice(idx, 1));
  }
  for (const layer of ordered) {
    const data = readTileVisualData(ctx, mapId, layer, x, y);
    if (!data) continue;
    const desc = sourceDescriptor(ctx, mapId, layer, x, y, data);
    if (desc) return desc;
  }
  return null;
}

function sourceDescriptorsAtAllLayers(ctx, mapId, x, y) {
  const out = [];
  for (const layer of authoritativeLayers(ctx, mapId, false)) {
    const data = readTileVisualData(ctx, mapId, layer, x, y);
    if (!data) continue;
    const desc = sourceDescriptor(ctx, mapId, layer, x, y, data);
    if (desc) out.push(desc);
  }
  return out;
}

function refreshCompiledDescriptors(geo, descriptors) {
  if (!geo || !Array.isArray(descriptors) || !descriptors.length) return;
  geo.compiled_objects ||= [];
  const keys = new Set(descriptors.map(d => d?.instance_key).filter(Boolean));
  geo.compiled_objects = geo.compiled_objects.filter(o => !keys.has(o?.instance_key));
  let nextId = Math.max(COMPILED_OBJECT_ID_BASE, ...geo.compiled_objects.map(o => Number(o.id) || 0)) + 1;
  for (const desc of descriptors) {
    if (!desc?.instance_key) continue;
    const def = geo.definitions?.[desc.key];
    if (!def) continue;
    const rule = effectiveSourceRule(def, geo.instance_overrides?.[desc.instance_key]);
    if (!rule || rule.enabled === false) continue;
    geo.compiled_objects.push(compiledObjectFromDescriptor(desc, rule, nextId++));
  }
}

function refreshCompiledCell(ctx, mapId, x, y) {
  const geo = state.maps.get(mapId);
  if (!geo) return;
  const live = sourceDescriptorsAtAllLayers(ctx, mapId, x, y);
  const liveKeys = new Set(live.map(d => d.instance_key));
  geo.compiled_objects = (geo.compiled_objects || []).filter(o => {
    if (Number(o?.source?.map_id) !== Number(mapId)) return true;
    if (Number(o?.source?.x) !== Number(x) || Number(o?.source?.y) !== Number(y)) return true;
    return liveKeys.has(o?.instance_key);
  });
  refreshCompiledDescriptors(geo, live);
}

function selectSourceAt(ctx, mapId, x, y, preferredLayer = null) {
  const desc = sourceDescriptorAt(ctx, mapId, x, y, preferredLayer);
  if (desc) {
    state.sourceSelection = desc;
    const geo = state.maps.get(mapId);
    if (geo?.definitions?.[desc.key]) state.sourcePreset = geo.definitions[desc.key].enabled === false ? "ignore" : geo.definitions[desc.key].category;
    state.objSelected = null;
    state.preview.focusX = x;
    state.preview.focusY = y;
    schedulePanelRefresh();
    if (desc.tileset_id) void ensureTilesetResourceSet(ctx, desc.tileset_id).then(() => { schedulePanelRefresh(); schedulePreview(ctx); });
    ctx.editor.requestRedraw();
    schedulePreview(ctx);
    return desc;
  }
  state.sourceSelection = null;
  schedulePanelRefresh();
  ctx.editor.requestRedraw();
  return null;
}

function applyPresetToSelectedSource(ctx, presetName) {
  const geo = currentGeo(ctx);
  const sel = state.sourceSelection;
  if (!geo || !sel) return;
  state.sourcePreset = presetName;
  geo.definitions ||= {};
  const existing = geo.definitions[sel.key];
  const fresh = definitionFromPreset(sel.key, sel.label, presetName);
  geo.definitions[sel.key] = existing ? { ...fresh, label: existing.label || fresh.label } : fresh;
  void compileGeometryScene(ctx, sel.map_id, geo, { reason: `preset:${presetName}` }).then(() => saveMap(ctx, sel.map_id, { skipCompile: true }));
  state.panelRefresh?.();
}

function updateSelectedSourceDefinition(ctx, patch) {
  const geo = currentGeo(ctx), sel = state.sourceSelection;
  if (!geo || !sel) return;
  geo.definitions ||= {};
  const base = geo.definitions[sel.key] || definitionFromPreset(sel.key, sel.label, state.sourcePreset || "wall");
  geo.definitions[sel.key] = normalizeSourceDefinition({ ...base, ...patch, source_key: sel.key, label: base.label || sel.label,
    components: patch?.components ? { ...(base.components || {}), ...patch.components } : base.components }, sel.key);
  scheduleSceneCompile(ctx, sel.map_id, "definition", 80);
  state.panelRefresh?.();
}

function updateSelectedInstanceOverride(ctx, patch) {
  const geo = currentGeo(ctx), sel = state.sourceSelection;
  if (!geo || !sel) return;
  geo.instance_overrides ||= {};
  const old = geo.instance_overrides[sel.instance_key] || {};
  geo.instance_overrides[sel.instance_key] = { ...old, ...patch };
  scheduleSceneCompile(ctx, sel.map_id, "instance-override", 80);
  state.panelRefresh?.();
}

function clearSelectedInstanceOverride(ctx) {
  const geo = currentGeo(ctx), sel = state.sourceSelection;
  if (!geo || !sel) return;
  delete geo.instance_overrides?.[sel.instance_key];
  scheduleSceneCompile(ctx, sel.map_id, "instance-clear", 80);
  state.panelRefresh?.();
}

const SIMPLE_PRESET_LABELS = {
  floor: "Suelo",
  wall: "Pared",
  mountain: "Montaña",
  prop: "Prop",
  roof: "Techo",
  border: "Borde",
  custom: "Personalizado",
  ignore: "Sin Geometry",
};

function simplePresetLabel(name) {
  return SIMPLE_PRESET_LABELS[name] || name || "Geometry";
}

function simplePresetIcon(name) {
  return ({ floor: "▱", wall: "▥", mountain: "▰", prop: "♟", roof: "⌂", border: "▤", custom: "◆", ignore: "∅" })[name] || "◆";
}

function simplePresetRule(presetName, height = null) {
  const preset = SCENE_GEOMETRY_PRESETS[presetName] || SCENE_GEOMETRY_PRESETS.wall;
  const out = {
    category: preset.category,
    type: preset.type,
    height: height == null ? Number(preset.height) || 0 : Math.max(0, Number(height) || 0),
    anchor_z: Number(preset.anchor_z) || 0,
    collision: preset.collision,
    characters_in_front: !!preset.characters_in_front,
    components: { ...(preset.components || {}) },
  };
  return out;
}

function forgetOverridesForSource(geo, sourceKey) {
  if (!geo?.instance_overrides) return;
  for (const key of Object.keys(geo.instance_overrides)) {
    if (key.endsWith(`|${sourceKey}`)) delete geo.instance_overrides[key];
  }
}

function connectedSourceDescriptors(ctx, sel, limit = 4096) {
  if (!sel) return [];
  const info = ctx.map.info(sel.map_id);
  if (!info) return [sel];
  const layer = authoritativeLayers(ctx, sel.map_id, true).find((l) => Number(layerRef(l)) === Number(sel.layer));
  if (!layer) return [sel];
  const geo = state.maps.get(sel.map_id);
  const seedDef = geo?.definitions?.[sel.key] || null;
  const seedRule = seedDef ? effectiveSourceRule(seedDef, geo?.instance_overrides?.[sel.instance_key]) : null;
  const out = [];
  const seen = new Set();
  const queue = [[sel.x, sel.y]];
  while (queue.length && out.length < limit) {
    const [x, y] = queue.shift();
    if (x < 0 || y < 0 || x >= info.width || y >= info.height) continue;
    const k = `${x},${y}`;
    if (seen.has(k)) continue;
    seen.add(k);
    const data = readTileVisualData(ctx, sel.map_id, layer, x, y);
    if (!data) continue;
    const desc = sourceDescriptor(ctx, sel.map_id, layer, x, y, data);
    if (!desc) continue;

    // V2 smart connected scope. Before Geometry exists we retain the safe
    // same-source behavior. Once the seed has Geometry, adjacent tiles may use
    // different cliff/mountain graphics and still belong to the same connected
    // elevation if their effective category and height match.
    let compatible = desc.key === sel.key;
    if (seedRule && seedRule.enabled !== false) {
      const d = geo?.definitions?.[desc.key];
      const r = d ? effectiveSourceRule(d, geo?.instance_overrides?.[desc.instance_key]) : null;
      compatible = !!r && r.enabled !== false &&
        String(r.category || '') === String(seedRule.category || '') &&
        Math.abs((Number(r.height) || 0) - (Number(seedRule.height) || 0)) < 0.001;
    }
    if (!compatible) continue;
    out.push(desc);
    queue.push([x + 1, y], [x - 1, y], [x, y + 1], [x, y - 1]);
  }
  return out.length ? out : [sel];
}

function scopedSourceDescriptors(ctx, sel) {
  if (state.sceneScope === "connected") return connectedSourceDescriptors(ctx, sel);
  return [sel];
}

function affectedSourceDescriptors(ctx, sel) {
  if (!sel) return [];
  if (state.sceneScope === "all") {
    const usage = state.sourceUsageByMap.get(sel.map_id) || state.sourceUsage;
    const rows = (usage?.placements || []).filter(d => d.key === sel.key);
    return rows.length ? rows : [sel];
  }
  return scopedSourceDescriptors(ctx, sel);
}

async function finishSimpleSceneEdit(ctx, mapId, reason) {
  const geo = state.maps.get(mapId);
  if (!geo) return;
  schedulePanelRefresh();
  ctx.editor.requestRedraw();
  markPreviewDirty(ctx);
  if (state.dragging || state.preview.dragging) return;
  clearTimeout(state.simpleEditTimer);
  state.simpleEditTimer = setTimeout(async () => {
    state.simpleEditTimer = 0;
    await saveMap(ctx, mapId, { authoringOnly: true, skipCompile: true, skipModelCompile: true });
    // Legacy source-rule compilation is kept lazy; DS terrain itself compiles
    // only when Preview is refreshed or the project is explicitly saved.
    if (!String(reason || '').startsWith('terrain-')) scheduleSceneCompile(ctx, mapId, reason, 900);
  }, 900);
}

function applySimpleGeometry(ctx, sel, presetName = state.brushPreset, height = state.brushHeight) {
  const geo = state.maps.get(sel?.map_id);
  if (!geo || !sel) return;
  presetName = SCENE_GEOMETRY_PRESETS[presetName] ? presetName : "wall";
  state.brushPreset = presetName;
  state.sourcePreset = presetName;
  const patch = simplePresetRule(presetName, height);
  geo.definitions ||= {};
  geo.instance_overrides ||= {};

  const affected = affectedSourceDescriptors(ctx, sel);
  if (state.sceneScope === "all") {
    const fresh = definitionFromPreset(sel.key, sel.label, presetName);
    geo.definitions[sel.key] = normalizeSourceDefinition({
      ...fresh,
      ...patch,
      enabled: true,
      source_key: sel.key,
      label: geo.definitions[sel.key]?.label || sel.label,
      components: { ...patch.components },
    }, sel.key);
    forgetOverridesForSource(geo, sel.key);
  } else {
    if (!geo.definitions[sel.key]) {
      const fresh = definitionFromPreset(sel.key, sel.label, presetName);
      geo.definitions[sel.key] = normalizeSourceDefinition({ ...fresh, ...patch, enabled: false, components: { ...patch.components } }, sel.key);
    }
    for (const desc of affected) {
      const old = geo.instance_overrides[desc.instance_key] || {};
      geo.instance_overrides[desc.instance_key] = {
        ...old,
        ...patch,
        disabled: false,
        components: { ...(old.components || {}), ...patch.components },
      };
    }
  }
  refreshCompiledDescriptors(geo, affected);
  void finishSimpleSceneEdit(ctx, sel.map_id, `simple-paint:${presetName}`);
}

function eraseSimpleGeometry(ctx, sel) {
  const geo = state.maps.get(sel?.map_id);
  if (!geo || !sel) return;
  // One eraser for everything Geometry owns. Never touches Maker Studio tiles.
  geo.objects = (geo.objects || []).filter(o => !objectCoversCell(o, sel.x, sel.y));
  geo.model_instances = (geo.model_instances || []).filter(inst => !modelInstanceCoversCell(geo, inst, sel.x, sel.y));
  compileModelObjects(geo);
  geo.definitions ||= {};
  geo.instance_overrides ||= {};
  if (state.sceneScope === "all") {
    if (geo.definitions[sel.key]) geo.definitions[sel.key].enabled = false;
    forgetOverridesForSource(geo, sel.key);
  } else {
    if (geo.definitions[sel.key]) for (const desc of scopedSourceDescriptors(ctx, sel)) {
      geo.instance_overrides[desc.instance_key] = { ...(geo.instance_overrides[desc.instance_key] || {}), disabled: true };
    }
  }
  void finishSimpleSceneEdit(ctx, sel.map_id, "simple-erase");
}

function eraseGeometryAtCell(ctx, mapId, x, y, preferredLayer = null) {
  const geo = state.maps.get(mapId);
  if (!geo) return false;
  let changed = false;

  // Models: erase the whole placed instance when any occupied cell is touched.
  const modelIds = new Set((geo.model_instances || []).filter(inst => modelInstanceCoversCell(geo, inst, x, y)).map(inst => Number(inst.id)));
  if (modelIds.size) {
    geo.model_instances = (geo.model_instances || []).filter(inst => !modelIds.has(Number(inst.id)));
    geo.model_objects = (geo.model_objects || []).filter(obj => !modelIds.has(Number(obj.model_instance_id)));
    changed = true;
  }

  // Manually placed Geometry objects.
  const beforeObjects = (geo.objects || []).length;
  geo.objects = (geo.objects || []).filter(obj => !objectCoversCell(obj, x, y));
  if ((geo.objects || []).length !== beforeObjects) changed = true;

  // Source-driven Geometry is erased locally, independent of the current scope.
  // This makes the eraser behave like Maker Studio's normal eraser: drag over
  // exactly what you want gone, without unexpectedly disabling every matching tile.
  geo.instance_overrides ||= {};
  const descriptors = sourceDescriptorsAtAllLayers(ctx, mapId, x, y);
  const affected = [];
  for (const desc of descriptors) {
    if (!geo.definitions?.[desc.key]) continue;
    geo.instance_overrides[desc.instance_key] = {
      ...(geo.instance_overrides[desc.instance_key] || {}),
      disabled: true,
    };
    affected.push(desc);
    changed = true;
  }
  if (affected.length) refreshCompiledDescriptors(geo, affected);

  if (state.sourceSelection && Number(state.sourceSelection.map_id) === Number(mapId) &&
      Number(state.sourceSelection.x) === Number(x) && Number(state.sourceSelection.y) === Number(y)) {
    state.sourceSelection = null;
  }
  if (changed) {
    ctx.editor.requestRedraw();
    schedulePreview(ctx);
    schedulePanelRefresh();
  }
  return changed;
}

function adjustSimpleGeometryHeight(ctx, sel, delta) {
  const geo = state.maps.get(sel?.map_id);
  if (!geo || !sel) return;
  geo.definitions ||= {};
  geo.instance_overrides ||= {};
  let def = geo.definitions[sel.key];
  if (!def) {
    const preset = state.brushPreset || "wall";
    const fresh = definitionFromPreset(sel.key, sel.label, preset);
    fresh.height = Math.max(0, Number(state.brushHeight) || Number(fresh.height) || 0);
    fresh.enabled = state.sceneScope === "all";
    geo.definitions[sel.key] = def = normalizeSourceDefinition(fresh, sel.key);
  }
  const affected = affectedSourceDescriptors(ctx, sel);
  if (state.sceneScope === "all") {
    def.enabled = true;
    def.height = Math.max(0, (Number(def.height) || 0) + delta);
    state.brushHeight = def.height;
  } else {
    for (const desc of affected) {
      const old = geo.instance_overrides[desc.instance_key] || {};
      const effective = effectiveSourceRule(def, old) || def;
      const next = Math.max(0, (Number(effective.height) || 0) + delta);
      geo.instance_overrides[desc.instance_key] = { ...old, height: next, disabled: false };
      if (desc.instance_key === sel.instance_key) state.brushHeight = next;
    }
  }
  refreshCompiledDescriptors(geo, affected);
  void finishSimpleSceneEdit(ctx, sel.map_id, `simple-height:${delta}`);
}

function patchSimpleGeometry(ctx, sel, patch) {
  const geo = state.maps.get(sel?.map_id);
  if (!geo || !sel) return;
  geo.definitions ||= {};
  geo.instance_overrides ||= {};
  let def = geo.definitions[sel.key];
  if (!def) {
    const fresh = definitionFromPreset(sel.key, sel.label, state.brushPreset || "wall");
    fresh.height = Math.max(0, Number(state.brushHeight) || Number(fresh.height) || 0);
    fresh.enabled = state.sceneScope === "all";
    geo.definitions[sel.key] = def = normalizeSourceDefinition(fresh, sel.key);
  }
  const affected = affectedSourceDescriptors(ctx, sel);
  if (state.sceneScope === "all") {
    const merged = { ...def, ...patch };
    if (patch.components) merged.components = { ...(def.components || {}), ...patch.components };
    merged.enabled = true;
    geo.definitions[sel.key] = normalizeSourceDefinition(merged, sel.key);
  } else {
    for (const desc of affected) {
      const old = geo.instance_overrides[desc.instance_key] || {};
      geo.instance_overrides[desc.instance_key] = {
        ...old,
        ...patch,
        disabled: false,
        components: patch.components ? { ...(old.components || {}), ...patch.components } : old.components,
      };
    }
  }
  refreshCompiledDescriptors(geo, affected);
  void finishSimpleSceneEdit(ctx, sel.map_id, "simple-patch");
}

function setSimpleGeometryHeight(ctx, sel, height) {
  const next = Math.max(0, Number(height) || 0);
  state.brushHeight = next;
  patchSimpleGeometry(ctx, sel, { height: next });
}

function eyedropSimpleGeometry(ctx, sel) {
  const geo = state.maps.get(sel?.map_id);
  const def = geo?.definitions?.[sel?.key];
  if (!geo || !sel || !def) {
    try { ctx.ui.showToast?.({ message: "Ese tile todavía no tiene Geometry para copiar.", level: "info" }); } catch (_) {}
    return;
  }
  const rule = effectiveSourceRule(def, geo.instance_overrides?.[sel.instance_key]);
  if (!rule || rule.enabled === false) {
    try { ctx.ui.showToast?.({ message: "Ese tile tiene Geometry desactivado.", level: "info" }); } catch (_) {}
    return;
  }
  state.brushPreset = rule.category || "custom";
  state.sourcePreset = state.brushPreset;
  state.brushHeight = Number(rule.height) || 0;
  state.sceneTool = "paint";
  state.panelRefresh?.();
  try { ctx.ui.showToast?.({ message: `Copiado: ${simplePresetLabel(state.brushPreset)}, altura ${state.brushHeight}.`, level: "info" }); } catch (_) {}
}

function runSimpleSceneTool(ctx, mapId, x, y, preferredLayer = null) {
  if (state.sceneTool === "terrain-slope") { applyTerrainSlopeBrush(ctx,mapId,x,y); return; }
  if (state.sceneTool === "terrain-flat") { flattenTerrainBrush(ctx,mapId,x,y); return; }
  if (state.sceneTool === "terrain-clear") { clearTerrainBrush(ctx,mapId,x,y); return; }
  if (state.sceneTool === "model-place") { placeModelInstance(ctx, mapId, x, y); return; }
  if (state.sceneTool === "model-erase") { eraseModelAtCell(ctx, mapId, x, y); return; }
  if (state.sceneTool === "place") { v2PlacePickedGraphic(ctx, mapId, x, y); return; }
  if (state.sceneTool === "erase") {
    if (state.uiSection === "models") eraseModelAtCell(ctx,mapId,x,y);
    else eraseTerrainBrush(ctx,mapId,x,y);
    return;
  }
  if (state.sceneTool === "raise") { nudgeTerrainBrush(ctx,mapId,x,y,Math.abs(Number(state.terrainStep)||0.25)); return; }
  if (state.sceneTool === "lower") { nudgeTerrainBrush(ctx,mapId,x,y,-Math.abs(Number(state.terrainStep)||0.25)); return; }

  if (state.sceneTool === "select") {
    setTerrainSelection(ctx,mapId,x,y,x,y);
    return;
  }

  const desc = state.sceneTool === "eyedropper"
    ? selectSourceAt(ctx, mapId, x, y, preferredLayer)
    : sourceDescriptorAt(ctx, mapId, x, y, preferredLayer);
  if (!desc) return;
  switch (state.sceneTool) {
    case "paint": applySimpleGeometry(ctx, desc); break;
    case "eyedropper": eyedropSimpleGeometry(ctx, desc); break;
    default: break;
  }
}

function cameraFor(ctx, geo, width = 640, height = 480) {
  const angle = state.preview.angle * Math.PI / 180;
  const yaw = state.preview.yaw * Math.PI / 180;
  const cosRaw = Math.cos(angle);
  const cosSafe = Math.max(0.10, Math.abs(cosRaw));
  const sin = Math.sin(angle);
  const cosYaw = Math.cos(yaw);
  const sinYaw = Math.sin(yaw);
  const distance = runtimeConfig.distanceH;
  const focal = distance * (state.preview.zoom / cosSafe);
  const pivotY = height * 0.52;
  const centerX = width / 2;
  const fx = Math.max(0, Math.min(geo.width - 1, Math.round(state.preview.focusX ?? geo.width / 2)));
  const fy = Math.max(0, Math.min(geo.height - 1, Math.round(state.preview.focusY ?? geo.height / 2)));
  const focusFootX = (fx + 0.5) * TILE_SIZE;
  const focusFootY = (fy + 1.0) * TILE_SIZE;
  const mapId = ctx.editor.activeMapId();
  const camElev = effectiveHeight(geo, mapId, fx, fy);
  // At yaw=0 this is exactly the runtime camera. Yaw rotates the
  // world around the focus point before applying the same pitch perspective.
  const camX = focusFootX;
  const camY = focusFootY - pivotY;
  return { width, height, angle, yaw, sin, cosRaw, cosYaw, sinYaw, distance, focal, pivotY, centerX, camX, camY, camElev, focusFootX, focusFootY };
}

function project(cam, wx, wy, elevation = 0) {
  const pivotWorldY = cam.camY + cam.pivotY;
  const rx = wx - cam.camX;
  const ry = wy - pivotWorldY;
  // Camera-space right/forward axes. Positive yaw orbits clockwise when viewed
  // from above. At yaw 0: right=world X, forward=world Y.
  const right = rx * cam.cosYaw - ry * cam.sinYaw;
  const forward = rx * cam.sinYaw + ry * cam.cosYaw;
  const relElev = elevation - cam.camElev;
  const depth = cam.distance - forward * cam.sin - relElev * cam.cosRaw;
  if (depth <= 24) return null;
  const sx = cam.centerX + cam.focal * right / depth;
  const vertical = forward * cam.cosRaw - relElev * cam.sin;
  const sy = cam.pivotY + cam.focal * vertical / depth;
  return { x: sx, y: sy, depth, scale: cam.focal / depth };
}

function polyDepth(points) {
  let sum = 0;
  let count = 0;
  for (const p of points) {
    if (!p) continue;
    sum += p.depth;
    count++;
  }
  return count ? sum / count : -Infinity;
}

function validPoly(points) {
  return points.length >= 3 && points.every(Boolean) && points.every((p) => Number.isFinite(p.x) && Number.isFinite(p.y));
}

function drawImageTriangle(c, img, s0, s1, s2, d0, d1, d2) {
  const den = s0.x * (s1.y - s2.y) + s1.x * (s2.y - s0.y) + s2.x * (s0.y - s1.y);
  if (Math.abs(den) < 1e-8) return;
  const a = (d0.x * (s1.y - s2.y) + d1.x * (s2.y - s0.y) + d2.x * (s0.y - s1.y)) / den;
  const cM = (d0.x * (s2.x - s1.x) + d1.x * (s0.x - s2.x) + d2.x * (s1.x - s0.x)) / den;
  const e = (d0.x * (s1.x * s2.y - s2.x * s1.y) + d1.x * (s2.x * s0.y - s0.x * s2.y) + d2.x * (s0.x * s1.y - s1.x * s0.y)) / den;
  const b = (d0.y * (s1.y - s2.y) + d1.y * (s2.y - s0.y) + d2.y * (s0.y - s1.y)) / den;
  const d = (d0.y * (s2.x - s1.x) + d1.y * (s0.x - s2.x) + d2.y * (s1.x - s0.x)) / den;
  const f = (d0.y * (s1.x * s2.y - s2.x * s1.y) + d1.y * (s2.x * s0.y - s0.x * s2.y) + d2.y * (s0.x * s1.y - s1.x * s0.y)) / den;
  c.save();
  c.beginPath();
  c.moveTo(d0.x, d0.y);
  c.lineTo(d1.x, d1.y);
  c.lineTo(d2.x, d2.y);
  c.closePath();
  c.clip();
  c.setTransform(a, b, cM, d, e, f);
  c.drawImage(img, 0, 0);
  c.restore();
}

function drawTexturedQuad(c, source, points, alpha = 1) {
  if (!source || !validPoly(points)) return false;
  const { img, sx, sy, sw, sh } = source;
  if (!img) return false;
  const [tl, tr, br, bl] = points;
  c.save();
  c.globalAlpha *= alpha;
  c.imageSmoothingEnabled = false;
  drawImageTriangle(c, img,
    { x: sx, y: sy }, { x: sx + sw, y: sy }, { x: sx + sw, y: sy + sh },
    tl, tr, br);
  drawImageTriangle(c, img,
    { x: sx, y: sy }, { x: sx + sw, y: sy + sh }, { x: sx, y: sy + sh },
    tl, br, bl);
  c.restore();
  return true;
}

function fillPoly(c, points, fill, stroke = null, lineWidth = 1) {
  if (!validPoly(points)) return;
  c.beginPath();
  c.moveTo(points[0].x, points[0].y);
  for (let i = 1; i < points.length; i++) c.lineTo(points[i].x, points[i].y);
  c.closePath();
  if (fill) { c.fillStyle = fill; c.fill(); }
  if (stroke) { c.strokeStyle = stroke; c.lineWidth = lineWidth; c.stroke(); }
}

function pointInPoly(px, py, poly) {
  let inside = false;
  for (let i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    const xi = poly[i].x, yi = poly[i].y;
    const xj = poly[j].x, yj = poly[j].y;
    const hit = ((yi > py) !== (yj > py)) && (px < (xj - xi) * (py - yi) / ((yj - yi) || 1e-9) + xi);
    if (hit) inside = !inside;
  }
  return inside;
}

function visualKind(props) {
  const tag = Number(props?.terrainTag) || 0;
  const priority = Number(props?.priority) || 0;
  if (MOUNTAIN_MATERIAL_TAGS.has(tag)) return "mountainMaterial";
  if (PLANE_WALL_TAGS.has(tag)) return "wallPlane";
  if (tag === TAG.WALL || tag === TAG.INDOOR_WALL) return "wallFacade";
  if (tag === TAG.STAIR) return "stair";
  if (tag === TAG.ROOF_PLANE) return "roofPlane";
  if (ROOF_BILLBOARD_TAGS.has(tag)) return "billboard";
  if (BILLBOARD_TAGS.has(tag)) return "billboard";
  if (priority > 0 && !TOP_SURFACE_TAGS.has(tag) && !WALL_ART_TAGS.has(tag)) return "billboard";
  return "ground";
}

function isBillboard(props) { return visualKind(props) === "billboard"; }
function isWallArt(props) {
  const k = visualKind(props);
  return k === "mountainMaterial" || k === "wallPlane" || k === "wallFacade";
}

function visibleLayers(ctx, mapId) {
  const native = [0, 1, 2].map((index) => ({ index, id: index, visible: true, opacity: 1, kind: "native" }));
  try {
    const extData = mapExtendedData(ctx, mapId);
    const extLayers = (extData?.layers || [])
      .filter((l) => l && l.visible !== false)
      .map((l) => ({ ...l, kind: "extended", index: firstDefined(l.index, l.id), id: firstDefined(l.id, l.index) }))
      .filter((l) => ![0, 1, 2].includes(Number(layerRef(l))))
      .sort((a, b) => layerSortValue(a) - layerSortValue(b));
    if (extLayers.length) {
      state.preview.layerStats = { native: native.length, extended: extLayers.length };
      return native.concat(extLayers);
    }
    const apiLayers = ctx.map.layers(mapId) || [];
    const extra = apiLayers
      .filter((l) => l && l.visible !== false && l.kind !== "shadow")
      .filter((l) => l.kind !== "native" && ![0, 1, 2].includes(Number(layerRef(l))))
      .sort((a, b) => layerSortValue(a) - layerSortValue(b));
    state.preview.layerStats = { native: native.length, extended: extra.length };
    return native.concat(extra);
  } catch (_) {
    state.preview.layerStats = { native: native.length, extended: 0 };
    return native;
  }
}

// Maker Studio builds have exposed map-layer opacity using 0..1, 0..100 and
// 0..255 conventions. A value of 100 must be fully opaque, not 100/255.
function normalizedLayerOpacity(value) {
  const n = Number(value);
  if (!Number.isFinite(n)) return 1;
  if (n <= 0) return 0;
  if (n <= 1.0001) return Math.max(0, Math.min(1, n));
  if (n <= 100.0001) return Math.max(0, Math.min(1, n / 100));
  return Math.max(0, Math.min(1, n / 255));
}

function normalizedTileOpacity(value) {
  if (value == null) return 1;
  const n = Number(value);
  if (!Number.isFinite(n)) return 1;
  if (n <= 1.0001) return Math.max(0, Math.min(1, n));
  return Math.max(0, Math.min(1, n / 255));
}

function cellTileEntries(ctx, mapId, x, y, layers, tilesetId) {
  const ground = [];
  const billboards = [];
  const walls = [];          // art/material usable by generated cliffs
  const wallPlanes = [];     // explicit NDSWallPlane geometry
  const stairs = [];
  const roofPlanes = [];
  const all = [];
  // Early exit: quickly check if any layer has a tile at this position.
  let hasAnyTile = false;
  for (const layer of layers) {
    const data = readTileVisualData(ctx, mapId, layer, x, y);
    if (data) { hasAnyTile = true; break; }
  }
  if (!hasAnyTile) return { ground, billboards, walls, wallPlanes, stairs, roofPlanes, all };
  for (const layer of layers) {
    const data = readTileVisualData(ctx, mapId, layer, x, y);
    const tileId = Number(data?.tileId) || 0;
    if (!data || (!tileId && !String(data?.autotileName || "").trim())) continue;
    const sourceTilesetId = Number(data?.tilesetId) || tilesetId;
    const props = tileId ? { ...tileProps(ctx, sourceTilesetId, tileId) } : { passage: 0, priority: 0, terrainTag: 0 };
    if (data?.terrainTag !== undefined) props.terrainTag = Number(data.terrainTag) || 0;
    const kind = visualKind(props);
    const source = sourceForTileData(ctx, tileId, data, layer, sourceTilesetId);
    const tileOpacity = normalizedTileOpacity(data?.opacity);
    const layerOpacity = normalizedLayerOpacity(layer.opacity ?? 1);
    const entry = {
      tileId, props, layer, data, kind, source, sourceTilesetId,
      alpha: Math.max(0, Math.min(1, tileOpacity * layerOpacity)),
      tag: Number(props?.terrainTag) || 0,
    };
    all.push(entry);
    if (kind === "mountainMaterial") walls.push(entry);
    else if (kind === "wallPlane") { walls.push(entry); wallPlanes.push(entry); }
    else if (kind === "wallFacade") { walls.push(entry); billboards.push({ ...entry, facade: true }); }
    else if (kind === "stair") stairs.push(entry);
    else if (kind === "roofPlane") roofPlanes.push(entry);
    else if (kind === "billboard") billboards.push(entry);
    else ground.push(entry);
  }
  return { ground, billboards, walls, wallPlanes, stairs, roofPlanes, all };
}

function surfaceGroundEntries(entries, elev, explicitGeometry = false) {
  const ground = entries?.ground || [];
  if (elev <= 0.001 || !ground.length) return ground;

  // A legacy elevated cell usually has a real surface-defining tile (MountainTop,
  // Volume, Floor). Lower native layers are underlay and must stay at Z=0 instead
  // of being lifted and blended into the plateau texture. Keep the surface layer
  // and any untagged decoration painted above it.
  const defining = ground.filter((e) => [
    TAG.FLOOR, TAG.VOLUME, TAG.MOUNTAIN_TOP, TAG.VOLUME_HIGH,
    TAG.ROOF_PLANE, TAG.INDOOR_BORDER, TAG.INDOOR_BLACK
  ].includes(Number(e.tag) || 0));
  if (defining.length) {
    const firstLayer = Math.min(...defining.map((e) => layerSortValue(e.layer)));
    return ground.filter((e) => {
      const layerIndex = layerSortValue(e.layer);
      const tag = Number(e.tag) || 0;
      if (layerIndex < firstLayer) return false;
      return tag === 0 || defining.includes(e);
    });
  }

  // Explicit Geometry Editor height without a semantic top tag intentionally
  // lifts the visible horizontal stack chosen by the mapper.
  if (explicitGeometry) return ground;
  return ground.slice(-1);
}

function composeGroundSource(entries) {
  if (!entries || !entries.length) return null;
  const drawable = entries.filter((e) => e?.source && Number(e.alpha ?? 1) > 0.001);
  if (!drawable.length) return null;
  const canvas = getCanvas(TILE_SIZE, TILE_SIZE);
  const c = canvas.getContext("2d");
  c.imageSmoothingEnabled = false;
  // Compose the same per-cell layer stack first, then perspective-project the
  // result once. This avoids dark seams caused by independently warped alpha
  // layers and is closer to the RMXP/Maker Studio tile stack.
  for (const entry of drawable) {
    const src = entry.source;
    c.save();
    c.globalAlpha = Math.max(0, Math.min(1, Number(entry.alpha ?? 1)));
    c.drawImage(src.img, src.sx, src.sy, src.sw, src.sh, 0, 0, TILE_SIZE, TILE_SIZE);
    c.restore();
  }
  return { img: canvas, sx: 0, sy: 0, sw: TILE_SIZE, sh: TILE_SIZE };
}

function previewCliffSource(ctx, mapId, highX, highY, edge, layers, tilesetId, cellCache) {
  const custom = state.preview.cliffSource;
  if (custom && Number(custom.tileset_id) === Number(tilesetId) && custom.src_rect) {
    const r = custom.src_rect;
    const customImg = state.preview.tilesetImages.get(Number(custom.tileset_id)) || null;
    if (customImg) return { img: customImg, sx: r.x, sy: r.y, sw: r.w || 32, sh: r.h || 32 };
  }
  let nx = highX, ny = highY;
  if (edge === "south") ny++;
  else if (edge === "north") ny--;
  else if (edge === "east") nx++;
  else if (edge === "west") nx--;
  const key = cellCacheKey(mapId, nx, ny);
  let entries = cellCache.get(key);
  if (!entries) {
    entries = cellTileEntries(ctx, mapId, nx, ny, layers, tilesetId);
    cellCache.set(key, entries);
  }
  const wall = entries.walls.find((e) => e.source);
  if (wall?.source) return wall.source;
  const localKey = cellCacheKey(mapId, highX, highY);
  let local = cellCache.get(localKey);
  if (!local) {
    local = cellTileEntries(ctx, mapId, highX, highY, layers, tilesetId);
    cellCache.set(localKey, local);
  }
  return local.walls.find((e) => e.source)?.source || null;
}

function makeTopPoly(cam, x, y, elev) {
  return [
    project(cam, x * TILE_SIZE, y * TILE_SIZE, elev),
    project(cam, (x + 1) * TILE_SIZE, y * TILE_SIZE, elev),
    project(cam, (x + 1) * TILE_SIZE, (y + 1) * TILE_SIZE, elev),
    project(cam, x * TILE_SIZE, (y + 1) * TILE_SIZE, elev),
  ];
}

function makeTerrainTopPoly(cam, geo, mapId, x, y) {
  const tc = terrainCellAt(geo,x,y);
  if (tc?.corners?.length === 4) {
    const step=Math.max(.001,Number(geo.height_step)||DEFAULT_STEP);
    const [nw,ne,se,sw]=tc.corners.map(v=>Math.max(0,Number(v)||0)*step);
    return [
      project(cam, x*TILE_SIZE, y*TILE_SIZE, nw),
      project(cam, (x+1)*TILE_SIZE, y*TILE_SIZE, ne),
      project(cam, (x+1)*TILE_SIZE, (y+1)*TILE_SIZE, se),
      project(cam, x*TILE_SIZE, (y+1)*TILE_SIZE, sw),
    ];
  }
  return makeTopPoly(cam,x,y,effectiveHeight(geo,mapId,x,y));
}

function makeRectTopPoly(cam, x0, y0, x1, y1, elev) {
  return [
    project(cam, x0 * TILE_SIZE, y0 * TILE_SIZE, elev),
    project(cam, (x1 + 1) * TILE_SIZE, y0 * TILE_SIZE, elev),
    project(cam, (x1 + 1) * TILE_SIZE, (y1 + 1) * TILE_SIZE, elev),
    project(cam, x0 * TILE_SIZE, (y1 + 1) * TILE_SIZE, elev),
  ];
}

function makeRectFacePoly(cam, x0, y0, x1, y1, edge, z0, z1) {
  let a, b;
  if (edge === "south") { a = [x0 * TILE_SIZE, (y1 + 1) * TILE_SIZE]; b = [(x1 + 1) * TILE_SIZE, (y1 + 1) * TILE_SIZE]; }
  else if (edge === "north") { a = [(x1 + 1) * TILE_SIZE, y0 * TILE_SIZE]; b = [x0 * TILE_SIZE, y0 * TILE_SIZE]; }
  else if (edge === "east") { a = [(x1 + 1) * TILE_SIZE, (y1 + 1) * TILE_SIZE]; b = [(x1 + 1) * TILE_SIZE, y0 * TILE_SIZE]; }
  else { a = [x0 * TILE_SIZE, y0 * TILE_SIZE]; b = [x0 * TILE_SIZE, (y1 + 1) * TILE_SIZE]; }
  return [
    project(cam, a[0], a[1], z1),
    project(cam, b[0], b[1], z1),
    project(cam, b[0], b[1], z0),
    project(cam, a[0], a[1], z0),
  ];
}

function makeFacePoly(cam, x, y, edge, z0, z1) {
  let a, b;
  if (edge === "south") { a = [x * TILE_SIZE, (y + 1) * TILE_SIZE]; b = [(x + 1) * TILE_SIZE, (y + 1) * TILE_SIZE]; }
  else if (edge === "north") { a = [(x + 1) * TILE_SIZE, y * TILE_SIZE]; b = [x * TILE_SIZE, y * TILE_SIZE]; }
  else if (edge === "east") { a = [(x + 1) * TILE_SIZE, (y + 1) * TILE_SIZE]; b = [(x + 1) * TILE_SIZE, y * TILE_SIZE]; }
  else { a = [x * TILE_SIZE, y * TILE_SIZE]; b = [x * TILE_SIZE, (y + 1) * TILE_SIZE]; }
  return [
    project(cam, a[0], a[1], z1),
    project(cam, b[0], b[1], z1),
    project(cam, b[0], b[1], z0),
    project(cam, a[0], a[1], z0),
  ];
}


function makeRampPoly(cam, x, y, southZ, northZ) {
  return [
    project(cam, x * TILE_SIZE, y * TILE_SIZE, northZ),
    project(cam, (x + 1) * TILE_SIZE, y * TILE_SIZE, northZ),
    project(cam, (x + 1) * TILE_SIZE, (y + 1) * TILE_SIZE, southZ),
    project(cam, x * TILE_SIZE, (y + 1) * TILE_SIZE, southZ),
  ];
}

function eventCharacterSource(graphic) {
  const name = String(graphic?.character_name || "");
  const img = state.preview.characterImages.get(name);
  if (!img) return null;
  // RPG Maker XP character sheets are normally 4 columns x 4 directions.
  const cols = 4, rows = 4;
  const fw = Math.max(1, Math.floor(img.width / cols));
  const fh = Math.max(1, Math.floor(img.height / rows));
  const dir = Number(graphic?.direction) || 2;
  const row = dir === 4 ? 1 : dir === 6 ? 2 : dir === 8 ? 3 : 0;
  const col = Math.max(0, Math.min(3, Number(graphic?.pattern) || 0));
  return { img, sx: col * fw, sy: row * fh, sw: fw, sh: fh };
}

function appendEventItems(ctx, mapId, geo, cam, items, minX, maxX, minY, maxY) {
  if (!state.preview.showEvents || !ctx.events?.list || !ctx.events?.getFull) return;
  for (const ev of ctx.events.list(mapId) || []) {
    if (ev.x < minX || ev.x > maxX || ev.y < minY || ev.y > maxY) continue;
    try {
      const full = ctx.events.getFull(mapId, ev.id);
      const page = full?.pages?.[0];
      const graphic = page?.graphic;
      if (!graphic?.character_name) continue;
      const elev = effectiveHeight(geo, mapId, ev.x, ev.y);
      const anchor = project(cam, (ev.x + 0.5) * TILE_SIZE, (ev.y + 1) * TILE_SIZE, elev);
      if (!anchor) continue;
      const source = eventCharacterSource(graphic);
      items.push({
        type: "event", x: ev.x, y: ev.y, elev, anchor, source,
        alpha: Math.max(0, Math.min(1, Number(graphic.opacity ?? 255) / 255)),
        depth: anchor.depth + (page?.always_on_bottom ? 0.25 : page?.always_on_top ? -0.25 : 0),
        name: ev.name || `Event ${ev.id}`,
      });
    } catch (_) {}
  }
}

function buildStructureBillboards(cam, structureCells, items) {
  const pending = new Set(structureCells.keys());
  while (pending.size) {
    const firstKey = pending.values().next().value;
    pending.delete(firstKey);
    const first = structureCells.get(firstKey);
    if (!first) continue;
    const component = [first];
    const queue = [first];
    while (queue.length) {
      const cur = queue.shift();
      const neighbours = [[cur.x - 1, cur.y], [cur.x + 1, cur.y], [cur.x, cur.y - 1], [cur.x, cur.y + 1]];
      for (const [nx, ny] of neighbours) {
        const key = `${nx},${ny}`;
        if (!pending.has(key)) continue;
        const next = structureCells.get(key);
        if (!next || Math.abs(next.elev - first.elev) > 0.001) continue;
        pending.delete(key);
        component.push(next);
        queue.push(next);
      }
    }
    const minX = Math.min(...component.map((v) => v.x));
    const maxX = Math.max(...component.map((v) => v.x));
    const minY = Math.min(...component.map((v) => v.y));
    const maxY = Math.max(...component.map((v) => v.y));
    const canvas = document.createElement("canvas");
    canvas.width = Math.max(1, (maxX - minX + 1) * TILE_SIZE);
    canvas.height = Math.max(1, (maxY - minY + 1) * TILE_SIZE);
    const cc = canvas.getContext("2d");
    cc.imageSmoothingEnabled = false;
    for (const cell of component) {
      for (const entry of cell.entries) {
        const src = entry.source;
        if (!src) continue;
        cc.save();
        cc.globalAlpha = Number(entry.alpha ?? 1);
        cc.drawImage(src.img, src.sx, src.sy, src.sw, src.sh,
          (cell.x - minX) * TILE_SIZE, (cell.y - minY) * TILE_SIZE, TILE_SIZE, TILE_SIZE);
        cc.restore();
      }
    }
    const wx = ((minX + maxX + 1) / 2) * TILE_SIZE;
    const wy = (maxY + 1) * TILE_SIZE;
    const anchor = project(cam, wx, wy, first.elev);
    if (!anchor) continue;
    items.push({
      type: "billboard", x: minX, y: maxY, elev: first.elev, anchor,
      entry: { source: { img: canvas, sx: 0, sy: 0, sw: canvas.width, sh: canvas.height }, alpha: 1, tag: TAG.STRUCTURE },
      depth: anchor.depth, tags: [TAG.STRUCTURE], structureBounds: { minX, minY, maxX, maxY },
    });
  }
}

function objectMaterialSource(ctx, obj, explicitMaterial = null) {
  const m = explicitMaterial || obj?.material;
  if (!m) return null;
  let source = null;
  if (m.kind === "image") {
    const name=String(m.graphic||'').replace(/\\/g,'/').replace(/^Graphics\/Models\//i,'').replace(/^\/+/, '');
    const img=state.preview.modelImages.get(name.toLowerCase());
    if(img){const r=m.src_rect||{};source={img,sx:Number(r.x)||0,sy:Number(r.y)||0,sw:Math.max(1,Number(r.w)||img.width||TILE_SIZE),sh:Math.max(1,Number(r.h)||img.height||TILE_SIZE)};}
  } else if (m.kind === "autotile") {
    const name = String(m.graphic || "").trim();
    const pattern = Number(m.autotile_pattern) || 0;
    let img = null;
    if (name && String(obj?.source_key || m?.source_key || "").startsWith("extra:")) img = extraAutotileCanvas(name, pattern);
    if (!img && Number(m.tileset_id)) {
      const idx = Math.floor((Number(m.tile_id) || 0) / 48) - 1;
      img = autotileCanvas(Number(m.tileset_id), Math.max(0, idx), pattern);
    }
    if (img) source = { img, sx: 0, sy: 0, sw: TILE_SIZE, sh: TILE_SIZE };
  } else {
    const img = state.preview.tilesetImages.get(Number(m.tileset_id));
    if (img) {
      const r = m.src_rect || {};
      source = {
        img, sx: Number(r.x) || 0, sy: Number(r.y) || 0,
        sw: Math.max(1, Number(r.w) || TILE_SIZE),
        sh: Math.max(1, Number(r.h) || TILE_SIZE),
      };
    }
  }
  if (!source) return null;

  // Canonical compiled materials store Maker Studio runtime semantics:
  // saturation=100 and lighting=0 are neutral. Keep the preview on that exact
  // convention instead of re-detecting the editor colour model here.
  const rotation = normalizeRotation(m.rotation);
  const flipH = !!m.flip_h, flipV = !!m.flip_v;
  const hue = Number(m.hue) || 0;
  const saturation = m.saturation == null ? 100 : Number(m.saturation);
  const brightness = 100 + (Number(m.lighting) || 0);
  if (!rotation && !flipH && !flipV && !hue && saturation === 100 && brightness === 100) return source;

  // IMPORTANT: a material can be a multi-tile rectangle (for example 32x64).
  // Never collapse it to a single 32x32 tile while baking transforms, because
  // that makes a 1x2 cliff texture become one squashed tile that is then tiled
  // twice on a 2-tile-high face. Preserve the complete selected source region.
  const srcW = Math.max(1, Number(source.sw) || TILE_SIZE);
  const srcH = Math.max(1, Number(source.sh) || TILE_SIZE);
  const swapAxes = rotation === 90 || rotation === 270;
  const outW = swapAxes ? srcH : srcW;
  const outH = swapAxes ? srcW : srcH;
  const r = m.src_rect || {};
  const key = `compiled:${m.kind}:${m.tileset_id}:${m.graphic}:${m.tile_id}:${m.autotile_tid}:${Number(r.x)||0}:${Number(r.y)||0}:${Number(r.w)||srcW}:${Number(r.h)||srcH}:${rotation}:${flipH?1:0}:${flipV?1:0}:${hue}:${saturation}:${brightness}`;
  if (state.preview.transformedSourceCache.has(key)) return state.preview.transformedSourceCache.get(key);
  const canvas = document.createElement("canvas");
  canvas.width = outW; canvas.height = outH;
  const c = canvas.getContext("2d");
  c.imageSmoothingEnabled = false;
  c.save();
  c.translate(outW / 2, outH / 2);
  c.rotate(rotation * Math.PI / 180);
  c.scale(flipH ? -1 : 1, flipV ? -1 : 1);
  c.filter = `hue-rotate(${hue}deg) saturate(${Math.max(0, saturation)}%) brightness(${Math.max(5, brightness)}%)`;
  c.drawImage(source.img, source.sx, source.sy, source.sw, source.sh, -srcW / 2, -srcH / 2, srcW, srcH);
  c.restore();
  const out = { img: canvas, sx: 0, sy: 0, sw: outW, sh: outH };
  state.preview.transformedSourceCache.set(key, out);
  return out;
}


function meshFaceMaterialSource(ctx, face) {
  const base=objectMaterialSource(ctx,{source_key:face?.source_key||"",material:face?.material||null},face?.material||null);
  if(!base || face?.material_repeat===false)return base;
  let tilesWide=1,tilesHigh=1;
  if(Array.isArray(face?.vertices)&&face.vertices.length===4){
    const dist=(a,b)=>Math.hypot((a?.[0]||0)-(b?.[0]||0),(a?.[1]||0)-(b?.[1]||0),(a?.[2]||0)-(b?.[2]||0));
    tilesWide=Math.max(.01,dist(face.vertices[0],face.vertices[1]));
    tilesHigh=Math.max(.01,dist(face.vertices[0],face.vertices[3]));
  }else{
    const dx=Math.abs((Number(face.x1)||0)-(Number(face.x0)||0)),dy=Math.abs((Number(face.y1)||0)-(Number(face.y0)||0));
    tilesWide=face.kind==="top" ? Math.max(.01,dx) : Math.max(.01,Math.max(dx,dy));
    tilesHigh=face.kind==="top" ? Math.max(.01,dy) : Math.max(.01,Math.abs((Number(face.z1)||0)-(Number(face.z0)||0)));
  }
  const facePxW=Math.max(1,Math.round(tilesWide*TILE_SIZE)), facePxH=Math.max(1,Math.round(tilesHigh*TILE_SIZE));
  const unitW=Math.max(1,Number(base.sw)||TILE_SIZE), unitH=Math.max(1,Number(base.sh)||TILE_SIZE);
  const pu=Array.isArray(face?.pattern_uv)&&face.pattern_uv.length===4?face.pattern_uv:null;
  const startX=pu?Math.round((Number(pu[0])||0)*TILE_SIZE):0;
  const startY=pu?Math.round((Number(pu[1])||0)*TILE_SIZE):0;
  const phaseX=((startX%unitW)+unitW)%unitW, phaseY=((startY%unitH)+unitH)%unitH;
  if(facePxW===unitW && facePxH===unitH && phaseX===0 && phaseY===0)return base;
  const key=`meshrepeat:${materialSignature(face.material)}:${facePxW}x${facePxH}:unit${unitW}x${unitH}:phase${phaseX},${phaseY}`;
  if(state.preview.transformedSourceCache.has(key))return state.preview.transformedSourceCache.get(key);
  const cv=document.createElement("canvas");cv.width=facePxW;cv.height=facePxH;const cc=cv.getContext("2d");cc.imageSmoothingEnabled=false;
  let y=0;
  while(y<facePxH){
    const sy=(phaseY+y)%unitH, dh=Math.min(unitH-sy,facePxH-y);
    let x=0;
    while(x<facePxW){
      const sx=(phaseX+x)%unitW, dw=Math.min(unitW-sx,facePxW-x);
      cc.drawImage(base.img,base.sx+sx,base.sy+sy,dw,dh,x,y,dw,dh);
      x+=dw;
    }
    y+=dh;
  }
  const out={img:cv,sx:0,sy:0,sw:cv.width,sh:cv.height};state.preview.transformedSourceCache.set(key,out);return out;
}

function appendMeshFaceItems(ctx, geo, cam, items, collisionEdges, minX,maxX,minY,maxY){
  const step=Number(geo?.height_step)||DEFAULT_STEP;
  for(const face of geo?.mesh_faces||[]){
    let poly=null,fx0=0,fx1=0,fy0=0,fy1=0;
    if(Array.isArray(face?.vertices)&&face.vertices.length===4){
      const vs=face.vertices;fx0=Math.min(...vs.map(v=>Number(v?.[0])||0));fx1=Math.max(...vs.map(v=>Number(v?.[0])||0));fy0=Math.min(...vs.map(v=>Number(v?.[1])||0));fy1=Math.max(...vs.map(v=>Number(v?.[1])||0));
      if(fx1<minX||fx0>maxX+1||fy1<minY||fy0>maxY+1)continue;
      poly=vs.map(v=>project(cam,(Number(v?.[0])||0)*TILE_SIZE,(Number(v?.[1])||0)*TILE_SIZE,(Number(v?.[2])||0)*step));
    }else{
      fx0=Math.min(Number(face.x0)||0,Number(face.x1)||0);fx1=Math.max(Number(face.x0)||0,Number(face.x1)||0);fy0=Math.min(Number(face.y0)||0,Number(face.y1)||0);fy1=Math.max(Number(face.y0)||0,Number(face.y1)||0);
      if(fx1<minX||fx0>maxX+1||fy1<minY||fy0>maxY+1)continue;
      if(face.kind==="top") poly=makeRectTopPoly(cam,face.x0,face.y0,face.x1-1,face.y1-1,(Number(face.z1)||0)*step);
      else {const z0=(Number(face.z0)||0)*step,z1=(Number(face.z1)||0)*step;const ax=(Number(face.x0)||0)*TILE_SIZE,ay=(Number(face.y0)||0)*TILE_SIZE;const bx=(Number(face.x1)||0)*TILE_SIZE,by=(Number(face.y1)||0)*TILE_SIZE;poly=[project(cam,ax,ay,z1),project(cam,bx,by,z1),project(cam,bx,by,z0),project(cam,ax,ay,z0)];}
    }
    if(!validPoly(poly))continue;
    const isTop=face.kind==="top"||face.surface==="top";
    const item={type:isTop?"meshTop":"meshFace",meshFace:face,edge:face.edge,points:poly,source:meshFaceMaterialSource(ctx,face),depth:polyDepth(poly),tags:[]};items.push(item);
  }
}

function appendObjectItems(ctx, mapId, geo, cam, items, collisionEdges, minX, maxX, minY, maxY) {
  const step = Number(geo?.height_step) || DEFAULT_STEP;
  const objects = sceneObjects(geo);
  const connectIndex = new Map();
  for (const obj of objects) {
    if (obj?.type !== "cube" || obj?.components?.connect_neighbors !== true) continue;
    const r = objectRect(obj);
    for (let y = r.y0; y <= r.y1; y++) for (let x = r.x0; x <= r.x1; x++) {
      const k = `${x},${y}`;
      if (!connectIndex.has(k)) connectIndex.set(k, []);
      connectIndex.get(k).push(obj);
    }
  }
  const connected = (obj, x, y, baseZ, topZ) => (connectIndex.get(`${x},${y}`) || []).some((other) => {
    if (other === obj || other.category !== obj.category) return false;
    const otherBase = (Number(other.anchor_z) || 0) * step;
    const otherTop = otherBase + (Number(other.height) || 0) * step;
    return Math.abs(otherBase - baseZ) < 0.01 && Math.abs(otherTop - topZ) < 0.01;
  });

  for (const obj of objects) {
    if (obj?.render === false) continue;
    const r = objectRect(obj);
    if (r.x1 < minX || r.x0 > maxX || r.y1 < minY || r.y0 > maxY) continue;
    const baseZ = (Number(obj.anchor_z) || 0) * step;
    const source = objectMaterialSource(ctx, obj);
    const faceSource = (edge) => objectMaterialSource(ctx, obj, obj?.face_materials?.[edge]) || source;
    const isCube = obj.type === "cube";
    const topZ = isCube ? baseZ + (Number(obj.height) || 0) * step : baseZ;
    const comps = obj.components || {};

    if (!isCube || comps.cap !== false) {
      const top = makeRectTopPoly(cam, r.x0, r.y0, r.x1, r.y1, topZ);
      if (validPoly(top)) {
        items.push({
          type: "objectTop", obj, points: top, source: faceSource("top"),
          depth: polyDepth(top), tags: [], anchor: { x: top[0].x, y: top[0].y },
        });
      }
    }

    if (isCube && topZ > baseZ) {
      for (const edge of ["south", "north", "east", "west"]) {
        if (comps.connect_neighbors === true) {
          let nx = r.x0, ny = r.y0;
          if (edge === "south") ny = r.y1 + 1;
          if (edge === "north") ny = r.y0 - 1;
          if (edge === "east") nx = r.x1 + 1;
          if (edge === "west") nx = r.x0 - 1;
          if (connected(obj, nx, ny, baseZ, topZ)) continue;
        }
        const face = makeRectFacePoly(cam, r.x0, r.y0, r.x1, r.y1, edge, baseZ, topZ);
        if (validPoly(face)) items.push({ type: "objectFace", obj, edge, points: face, source: faceSource(edge), depth: polyDepth(face), tags: [] });
      }
      if (obj.collision !== "none") {
        const topEdge = makeRectFacePoly(cam, r.x0, r.y0, r.x1, r.y1, "south", topZ, topZ);
        if (validPoly(topEdge)) collisionEdges.push({ x: r.x0, y: r.y1, edge: "south", points: [topEdge[0], topEdge[1]] });
      }
    } else if (!isCube && obj.collision !== "none") {
      const topEdge = makeRectFacePoly(cam, r.x0, r.y0, r.x1, r.y1, "south", topZ, topZ);
      if (validPoly(topEdge)) collisionEdges.push({ x: r.x0, y: r.y1, edge: "south", points: [topEdge[0], topEdge[1]] });
    }
  }
}


function buildPreviewScene(ctx, mapId, geo, cam) {
  const info = ctx.map.info(mapId);
  if (!info) return { items: [], tops: [], collisionEdges: [] };
  const layers = visibleLayers(ctx, mapId);
  const tilesetId = mapTilesetId(info, mapId);
  const radius = state.preview.radius;
  const fx = Math.round(state.preview.focusX ?? info.width / 2);
  const fy = Math.round(state.preview.focusY ?? info.height / 2);
  const minX = state.preview.fullMap ? 0 : Math.max(0, fx - radius);
  const maxX = state.preview.fullMap ? info.width - 1 : Math.min(info.width - 1, fx + radius);
  const minY = state.preview.fullMap ? 0 : Math.max(0, fy - radius);
  const maxY = state.preview.fullMap ? info.height - 1 : Math.min(info.height - 1, fy + radius);
  const items = [];
  const tops = [];
  const collisionEdges = [];
  const cellCache = state.preview.cellEntryCache;
  const structureCells = new Map();

  for (let y = minY; y <= maxY; y++) {
    for (let x = minX; x <= maxX; x++) {
      const elev = effectiveHeight(geo, mapId, x, y);
      const top = makeTerrainTopPoly(cam, geo, mapId, x, y);
      if (!validPoly(top)) continue;
      const key = cellCacheKey(mapId, x, y);
      let entries = cellCache.get(key);
      if (!entries) {
        entries = cellTileEntries(ctx, mapId, x, y, layers, tilesetId);
        cellCache.set(key, entries);
      }
      const tags = [...new Set(entries.all.map((e) => e.tag).filter(Boolean))];
      const topItem = {
        type: "top",
        x, y, elev,
        points: top,
        depth: polyDepth(top),
        source: composeGroundSource(surfaceGroundEntries(entries, elev, hasExplicitCell(geo, x, y))),
        hasGroundEntries: surfaceGroundEntries(entries, elev, hasExplicitCell(geo, x, y)).length > 0,
        hasAnyEntries: entries.all.length > 0,
        tags,
      };
      items.push(topItem);
      tops.push(topItem);

      // Physical height field -> automatically generated cliff faces.
      const neighbours = [
        ["north", x, y - 1], ["east", x + 1, y], ["south", x, y + 1], ["west", x - 1, y],
      ];
      for (const [edge, nx, ny] of neighbours) {
        const low = (nx < 0 || ny < 0 || nx >= geo.width || ny >= geo.height) ? 0 : effectiveHeight(geo, mapId, nx, ny);
        if (elev <= low + 0.001) continue;
        const source = previewCliffSource(ctx, mapId, x, y, edge, layers, tilesetId, cellCache);
        const steps = Math.max(1, Math.ceil((elev - low) / DEFAULT_STEP));
        for (let i = 0; i < steps; i++) {
          const z0 = low + (elev - low) * (i / steps);
          const z1 = low + (elev - low) * ((i + 1) / steps);
          const face = makeFacePoly(cam, x, y, edge, z0, z1);
          if (!validPoly(face)) continue;
          items.push({ type: "face", x, y, edge, points: face, depth: polyDepth(face), source, step: i });
        }
        const edgeTop = makeFacePoly(cam, x, y, edge, elev - 0.01, elev);
        if (validPoly(edgeTop)) collisionEdges.push({ x, y, edge, points: [edgeTop[0], edgeTop[1]] });
      }

      // NDSStair: true inclined top face. Connect to north/south physical levels.
      for (const entry of entries.stairs) {
        const southZ = (y + 1 < geo.height) ? effectiveHeight(geo, mapId, x, y + 1) : elev;
        let northZ = (y - 1 >= 0) ? effectiveHeight(geo, mapId, x, y - 1) : elev + runtimeConfig.stairHeight;
        if (Math.abs(northZ - southZ) < 0.01) northZ = southZ + runtimeConfig.stairHeight;
        const ramp = makeRampPoly(cam, x, y, southZ, northZ);
        if (validPoly(ramp)) {
          const item = { type: "stair", x, y, points: ramp, source: entry.source, alpha: entry.alpha, depth: polyDepth(ramp), tags: [TAG.STAIR] };
          items.push(item);
          // A stair is also an editable/hittable physical surface.
          tops.push({ ...item, elev: Math.max(southZ, northZ) });
        }
      }

      // NDSRoofPlane: horizontal geometry at explicit roof elevation.
      for (const entry of entries.roofPlanes) {
        const z = elev + tagHeightOffset(entry.tag);
        const poly = makeTopPoly(cam, x, y, z);
        if (validPoly(poly)) items.push({ type: "roofPlane", x, y, points: poly, source: entry.source, alpha: entry.alpha, depth: polyDepth(poly), tags: [entry.tag] });
      }

      // NDSWallPlane: world-fixed north-edge quad, unlike a camera billboard.
      for (const entry of entries.wallPlanes) {
        const wallH = runtimeConfig.stairHeight;
        const poly = makeFacePoly(cam, x, y, "north", elev, elev + wallH);
        if (validPoly(poly)) items.push({ type: "wallPlane", x, y, points: poly, source: entry.source, alpha: entry.alpha, depth: polyDepth(poly), tags: [entry.tag] });
      }

      // Camera-facing categories: NDSBillboard / Structure / Overlay / protected
      // Roofs. This is deliberately different from WallPlane so rotating the
      // preview shows which assets are true geometry and which remain 2D art.
      for (const entry of entries.billboards) {
        const objectElev = elev + tagHeightOffset(entry.tag);
        if (entry.tag === TAG.STRUCTURE) {
          const key = `${x},${y}`;
          let cell = structureCells.get(key);
          if (!cell) { cell = { x, y, elev: objectElev, entries: [] }; structureCells.set(key, cell); }
          cell.entries.push(entry);
          continue;
        }
        const anchor = project(cam, (x + 0.5) * TILE_SIZE, (y + 1) * TILE_SIZE, objectElev);
        if (!anchor) continue;
        items.push({ type: "billboard", x, y, elev: objectElev, entry, anchor, depth: anchor.depth, tags: [entry.tag] });
      }
    }
  }

  buildStructureBillboards(cam, structureCells, items);
  appendMeshFaceItems(ctx, geo, cam, items, collisionEdges, minX, maxX, minY, maxY);
  appendObjectItems(ctx, mapId, geo, cam, items, collisionEdges, minX, maxX, minY, maxY);
  appendEventItems(ctx, mapId, geo, cam, items, minX, maxX, minY, maxY);

  if (state.preview.showPlayer) {
    const px = Math.round(state.preview.focusX);
    const py = Math.round(state.preview.focusY);
    const pe = effectiveHeight(geo, mapId, px, py);
    const anchor = project(cam, (px + 0.5) * TILE_SIZE, (py + 1) * TILE_SIZE, pe);
    if (anchor) items.push({ type: "player", x: px, y: py, elev: pe, anchor, depth: anchor.depth });
  }
  items.sort((a, b) => b.depth - a.depth);
  // Hit test near to far.
  tops.sort((a, b) => a.depth - b.depth);
  return { items, tops, collisionEdges };
}

function drawTagBadge(c, item) {
  if (!state.preview.showTags || !item?.tags?.length) return;
  const tags = [...new Set(item.tags.filter((t) => Number(t) > 0))];
  if (!tags.length) return;
  let x = null, y = null;
  if (item.anchor) { x = item.anchor.x; y = item.anchor.y - 8; }
  else if (item.points?.length) {
    x = item.points.reduce((a, p) => a + p.x, 0) / item.points.length;
    y = item.points.reduce((a, p) => a + p.y, 0) / item.points.length;
  }
  if (!Number.isFinite(x) || !Number.isFinite(y)) return;
  const text = tags.map((t) => `${t}:${tagName(t).replace(/^NDS/, "")}`).join("/");
  c.save();
  c.font = "9px system-ui,sans-serif";
  c.textAlign = "center";
  c.textBaseline = "middle";
  const w = Math.min(190, c.measureText(text).width + 8);
  c.fillStyle = "rgba(12,14,19,0.82)";
  c.fillRect(x - w / 2, y - 7, w, 14);
  c.fillStyle = "rgba(255,255,255,0.94)";
  c.fillText(text, x, y, w - 4);
  c.restore();
}

function drawPreviewItem(c, item) {
  if (item.type === "meshTop" || item.type === "meshFace") {
    const ok = drawTexturedQuad(c, item.source, item.points, item.type === "meshTop" ? 1 : 0.96);
    if (!ok) fillPoly(c, item.points, item.type === "meshTop" ? "rgba(92,125,78,0.96)" : "rgba(92,63,42,0.96)");
    if (state.preview.showWire) fillPoly(c, item.points, null, "rgba(255,255,255,0.18)", 0.75);
    return;
  }
  if (item.type === "top") {
    state.preview.assetStats.groundCells++;
    const drew = item.source ? drawTexturedQuad(c, item.source, item.points, 1) : false;
    if (drew) state.preview.assetStats.groundTextured++;
    if (!drew) {
      if (item.hasGroundEntries) {
        state.preview.assetStats.missingSources++;
        state.preview.assetStats.groundMissing++;
        fillPoly(c, item.points, item.elev > 0 ? "rgba(136,104,62,0.42)" : "rgba(86,145,72,0.28)");
        const cx = item.points.reduce((a,p)=>a+p.x,0)/item.points.length;
        const cy = item.points.reduce((a,p)=>a+p.y,0)/item.points.length;
        c.save(); c.fillStyle = "rgba(255,210,95,0.92)"; c.font = "9px system-ui,sans-serif"; c.textAlign = "center";
        c.fillText("tile?", cx, cy); c.restore();
      } else if (item.elev > 0.001) {
        // Keep editable physical geometry visible without inventing fake tile art.
        fillPoly(c, item.points, "rgba(90,150,100,0.12)");
      }
    }
    if (state.preview.showWire) fillPoly(c, item.points, null, "rgba(255,255,255,0.18)", 0.75);
    drawTagBadge(c, item);
    return;
  }
  if (item.type === "face") {
    const ok = drawTexturedQuad(c, item.source, item.points, 0.96);
    if (!ok) {
      const side = item.edge === "north" ? "rgba(72,52,40,0.94)" :
        item.edge === "east" || item.edge === "west" ? "rgba(92,63,42,0.94)" : "rgba(112,76,48,0.96)";
      fillPoly(c, item.points, side);
    }
    if (state.preview.showWire) fillPoly(c, item.points, null, "rgba(255,255,255,0.16)", 0.75);
    drawTagBadge(c, item);
    return;
  }
  if (item.type === "stair" || item.type === "roofPlane" || item.type === "wallPlane") {
    const ok = drawTexturedQuad(c, item.source, item.points, Number(item.alpha ?? 1));
    if (!ok) {
      const fallback = item.type === "stair" ? "rgba(168,148,125,0.92)" :
        item.type === "roofPlane" ? "rgba(120,105,125,0.90)" : "rgba(108,78,58,0.94)";
      fillPoly(c, item.points, fallback);
    }
    if (state.preview.showWire) fillPoly(c, item.points, null, "rgba(255,255,255,0.24)", 0.9);
    drawTagBadge(c, item);
    return;
  }
  if (item.type === "objectTop" || item.type === "objectFace") {
    const ok = drawTexturedQuad(c, item.source, item.points, 1);
    if (!ok) {
      const cat = item.obj?.category || "prop";
      const base = (CATEGORY_FALLBACK_COLORS[cat] || CATEGORY_FALLBACK_COLORS.prop);
      fillPoly(c, item.points, base);
    }
    if (item.type === "objectFace") {
      // Same shading as the runtime plugin (NDS_OBJECT_FRONT_SIDE/SIDE_SHADE).
      const shade = item.edge === "south" ? 0.094 : (item.edge === "east" || item.edge === "west") ? 0.18 : 0;
      if (shade) fillPoly(c, item.points, `rgba(0,0,0,${shade})`);
    }
    const isSelected = item.obj && state.objSelected != null && Number(item.obj.id) === Number(state.objSelected);
    if (state.preview.showWire) fillPoly(c, item.points, null, "rgba(200,180,255,0.30)", 0.9);
    if (isSelected) fillPoly(c, item.points, null, "rgba(80,220,255,0.95)", 2.5);
    if (item.type === "objectTop" && item.obj) {
      const label = `${isSelected ? "▸ " : ""}${item.obj.type.toUpperCase()}·H${item.obj.height}·A${item.obj.anchor_z}·${item.obj.collision}`;
      c.save();
      c.font = "9px system-ui,sans-serif";
      c.textAlign = "center";
      const cx = item.points.reduce((a, p) => a + p.x, 0) / item.points.length;
      const cy = item.points.reduce((a, p) => a + p.y, 0) / item.points.length;
      const w = Math.min(160, c.measureText(label).width + 8);
      c.fillStyle = "rgba(12,14,19,0.82)";
      c.fillRect(cx - w / 2, cy - 7, w, 14);
      c.fillStyle = "rgba(235,225,255,0.95)";
      c.fillText(label, cx, cy, w - 4);
      c.restore();
    }
    return;
  }
  if (item.type === "billboard") {
    const src = item.entry.source;
    if (!src) return;
    const scale = Math.max(0.2, Math.min(2.5, item.anchor.scale));
    const w = src.sw * scale;
    const h = src.sh * scale;
    c.save();
    c.imageSmoothingEnabled = false;
    c.globalAlpha *= Number(item.entry.alpha ?? 1);
    c.drawImage(src.img, src.sx, src.sy, src.sw, src.sh, item.anchor.x - w / 2, item.anchor.y - h, w, h);
    c.restore();
    drawTagBadge(c, item);
    return;
  }
  if (item.type === "event") {
    const p = item.anchor;
    const src = item.source;
    const scale = Math.max(0.25, Math.min(2.4, p.scale));
    c.save();
    c.imageSmoothingEnabled = false;
    c.globalAlpha *= Number(item.alpha ?? 1);
    if (src) {
      const w = src.sw * scale, h = src.sh * scale;
      c.drawImage(src.img, src.sx, src.sy, src.sw, src.sh, p.x - w / 2, p.y - h, w, h);
    } else {
      c.fillStyle = "rgba(100,205,255,0.9)";
      c.fillRect(p.x - 4, p.y - 12, 8, 12);
    }
    c.restore();
    if (state.preview.showTags && item.name) {
      c.save(); c.font = "9px system-ui,sans-serif"; c.textAlign = "center";
      c.fillStyle = "rgba(255,255,255,0.88)"; c.fillText(item.name, p.x, p.y + 10); c.restore();
    }
    return;
  }
  if (item.type === "player") {
    const p = item.anchor;
    const scale = Math.max(0.55, Math.min(1.65, p.scale));
    c.save();
    c.strokeStyle = "rgba(0,0,0,0.7)";
    c.fillStyle = "rgba(255,240,220,0.96)";
    c.lineWidth = 2;
    c.beginPath();
    c.arc(p.x, p.y - 23 * scale, 7 * scale, 0, Math.PI * 2);
    c.fill(); c.stroke();
    c.fillStyle = "rgba(232,118,132,0.96)";
    c.fillRect(p.x - 6 * scale, p.y - 17 * scale, 12 * scale, 16 * scale);
    c.strokeRect(p.x - 6 * scale, p.y - 17 * scale, 12 * scale, 16 * scale);
    c.restore();
  }
}
function drawPreviewHighlight(c, cell, kind = "hover") {
  if (!cell?.points) return;
  const stroke = kind === "hover" ? "rgba(255,235,80,0.98)" : "rgba(80,220,255,0.98)";
  fillPoly(c, cell.points, kind === "hover" ? "rgba(255,235,80,0.12)" : null, stroke, 2.2);
}

function schedulePanelRefresh() {
  if (state.dragging || state.preview.dragging) return;
  if (state.panelRaf || !state.panelRefresh) return;
  state.panelRaf = requestAnimationFrame(() => {
    state.panelRaf = 0;
    try { state.panelRefresh?.(); } catch (_) {}
  });
}

function scheduleTopDownPreview(ctx) {
  if (!state.topDownCanvas || state.preview.topDownRaf) return;
  state.preview.topDownRaf = requestAnimationFrame(() => {
    state.preview.topDownRaf = 0;
    try { v2RenderTopDown(ctx, state.topDownCanvas); } catch (err) { ctx.log.warn("2.5D Geometry: top-down refresh failed", err); }
  });
}

function updatePreviewDirtyStatus() {
  if (!state.preview.status || !state.previewDirty) return;
  state.preview.status.textContent = "Preview outdated — press Refresh. Live preview is off to keep editing fast.";
}

function markPreviewDirty(ctx) {
  state.previewDirty = true;
  updatePreviewDirtyStatus();
  if (state.previewLive && state.preview.canvas) schedulePreview(ctx, true);
}

function schedulePreview(ctx, force = false) {
  if (!state.preview.canvas) return;
  if (!force && !state.previewLive) { markPreviewDirty(ctx); return; }
  state.preview.rerender = true;
  // Camera interaction used to request a complete scene rebuild for every
  // pointer event. Cap it to ~24 fps and coalesce all intermediate events.
  if (state.preview.orbiting) {
    const now = performance.now();
    const wait = Math.max(0, state.preview.interactionFrameMs - (now - (state.preview.lastRenderAt || 0)));
    if (wait > 1) {
      if (!state.preview.interactionTimer) state.preview.interactionTimer = setTimeout(() => {
        state.preview.interactionTimer = 0; schedulePreview(ctx,true);
      }, wait);
      return;
    }
  }
  if (state.preview.raf) return;
  state.preview.raf = requestAnimationFrame(() => {
    state.preview.raf = 0;
    if (!state.preview.rerender) return;
    state.preview.rerender = false;
    state.preview.lastRenderAt = performance.now();
    void renderPreview(ctx);
  });
}

async function refreshPreviewNow(ctx) {
  const mapId = ctx.editor.activeMapId?.();
  if (mapId == null || !state.preview.canvas) return;
  const geo = await ensureMap(ctx, mapId);
  if (geo?._terrain_dirty) { compileTerrainMeshFaces(ctx, mapId, geo); geo._terrain_dirty = false; }
  // Authoring data omits generated model faces. Build them once after a map
  // opens; terrain edits never rebuild models.
  if (!geo._models_preview_ready) { compileModelObjects(geo); geo._models_preview_ready = true; }
  await ensurePreviewResources(ctx, mapId, false);
  await ensureVisiblePreviewResources(ctx, mapId);
  schedulePreview(ctx, true);
}

async function renderPreview(ctx) {
  if (state.preview.rendering) { state.preview.rerender = true; return; }
  const canvas = state.preview.canvas;
  if (!canvas) return;
  const mapId = ctx.editor.activeMapId();
  if (mapId == null) return;
  const geo = await ensureMap(ctx, mapId);
  if (!geo) return;
  state.preview.rendering = true;
  try {
    ensurePreviewFocus(ctx, mapId);
    const infoNow = ctx.map.info(mapId);
    if (!state.preview.orbiting) {
      if ((infoNow && mapTilesetId(infoNow, mapId) !== state.preview.tilesetId) || !state.preview.tilesetImage)
        await ensurePreviewResources(ctx, mapId);
      await ensureVisiblePreviewResources(ctx, mapId);
    }
    const c = canvas.getContext("2d");
    // V2: render at the actual viewport size instead of stretching a 640x480
    // thumbnail. Large/Split views therefore keep crisp pixels and readable
    // elevation geometry.
    const cssW = Math.round(canvas.clientWidth || 640);
    const cssH = Math.round(canvas.clientHeight || 480);
    const iq = state.preview.orbiting ? 0.45 : 1;
    const W = canvas.width = Math.max(state.preview.orbiting ? 320 : 640, Math.min(state.preview.orbiting ? 720 : 1400, Math.round(cssW * iq)));
    const H = canvas.height = Math.max(state.preview.orbiting ? 220 : 480, Math.min(state.preview.orbiting ? 460 : 900, Math.round(cssH * iq)));
    c.setTransform(1, 0, 0, 1, 0, 0);
    c.imageSmoothingEnabled = false;
    c.clearRect(0, 0, W, H);
    c.fillStyle = getComputedStyle(document.documentElement).getPropertyValue("--canvas-bg").trim() || "#1d2027";
    c.fillRect(0, 0, W, H);

    const cam = cameraFor(ctx, geo, W, H);
    state.preview.assetStats.standardAutotiles = [...state.preview.autotileImagesByTileset.values()].reduce((n, arr) => n + (arr || []).filter(Boolean).length, 0);
    state.preview.assetStats.extraAutotiles = [...state.preview.autotileImagesByName.values()].filter(Boolean).length;
    state.preview.assetStats.regularTilesets = [...state.preview.tilesetImages.values()].filter(Boolean).length;
    state.preview.assetStats.missingSources = 0;
    state.preview.assetStats.groundCells = 0;
    state.preview.assetStats.groundTextured = 0;
    state.preview.assetStats.groundMissing = 0;
    const scene = buildPreviewScene(ctx, mapId, geo, cam);
    trimCellEntryCache();
    for (const item of scene.items) drawPreviewItem(c, item);
    v2DrawPreviewHeightMarkers(c, scene);

    if (state.preview.showCollision) {
      c.save();
      c.strokeStyle = "rgba(255,70,70,0.92)";
      c.lineWidth = 1.5;
      c.beginPath();
      for (const edge of scene.collisionEdges) {
        const [a, b] = edge.points;
        c.moveTo(a.x, a.y); c.lineTo(b.x, b.y);
      }
      c.stroke();
      c.restore();
    }

    const focusCell = scene.tops.find((t) => t.x === Math.round(state.preview.focusX) && t.y === Math.round(state.preview.focusY));
    if (focusCell) drawPreviewHighlight(c, focusCell, "focus");
    if (state.preview.hovered) {
      const hoverCell = scene.tops.find((t) => t.x === state.preview.hovered.x && t.y === state.preview.hovered.y);
      if (hoverCell) drawPreviewHighlight(c, hoverCell, "hover");
    }
    state.preview.hitCells = scene.tops;
    state.preview.lastMapId = mapId;
    if (state.studioOverlayCanvas) studioDrawOverlay(ctx);
    state.previewDirty = false;
    updatePreviewStatus(ctx, geo);
  } catch (err) {
    ctx.log.error(err);
    const c = canvas.getContext("2d");
    c.setTransform(1, 0, 0, 1, 0, 0);
    c.fillStyle = "#2a1f23"; c.fillRect(0, 0, canvas.width, canvas.height);
    c.fillStyle = "#ffb9c2"; c.font = "14px sans-serif";
    c.fillText(`2.5D preview error: ${err?.message || err}`, 16, 28);
  } finally {
    state.preview.rendering = false;
    if (state.preview.rerender) schedulePreview(ctx);
  }
}

function updatePreviewStatus(ctx, geo) {
  if (!state.preview.status) return;
  const hover = state.preview.hovered;
  const fx = Math.round(state.preview.focusX);
  const fy = Math.round(state.preview.focusY);
  const mapId = ctx.editor.activeMapId();
  const focusLevel = effectiveLevel(geo, mapId, fx, fy);
  let hoverText = "";
  if (hover) {
    const info = ctx.map.info(mapId);
    const layers = visibleLayers(ctx, mapId);
    const entries = info ? cellTileEntries(ctx, mapId, hover.x, hover.y, layers, mapTilesetId(info, mapId)) : null;
    const tags = entries ? [...new Set(entries.all.map((e) => e.tag).filter(Boolean))] : [];
    const tagText = tags.length ? ` · ${tags.map((t) => tagName(t)).join("+")}` : "";
    hoverText = ` · Cursor ${hover.x},${hover.y} L${effectiveLevel(geo, mapId, hover.x, hover.y)}${tagText}`;
  }
  const ast = state.preview.assetStats || {};
  const ls = state.preview.layerStats || { native: 3, extended: 0 };
  const ms=geo?.mesh_compiler?.stats||{};
  const gfx = ` · GFX TS:${ast.regularTilesets || 0}(${ast.usedTilesetIds || "?"}) AT:${ast.standardAutotiles || 0} +EX:${ast.extraAutotiles || 0} · Layers ${ls.native || 0}+${ls.extended || 0} · Ground ${ast.groundTextured || 0}/${ast.groundCells || 0} miss:${ast.groundMissing || 0} · Mesh ${ms.faces||0} faces/${ms.cells||0} cells · Color:${detectColorModel(ctx)}${state.preview.ignoreColorTransforms ? "/RAW" : ""} · Layerα:auto`;
  state.preview.status.textContent = `Map${pad3(mapId)} · Cam ${fx},${fy} · Z ${focusLevel * (geo.height_step || DEFAULT_STEP)}px · Pitch ${state.preview.angle.toFixed(0)}° · Yaw ${state.preview.yaw.toFixed(0)}°${gfx}${hoverText}`;
}

function hitPreviewCell(canvas, clientX, clientY) {
  const rect = canvas.getBoundingClientRect();
  const px = (clientX - rect.left) * (canvas.width / Math.max(1, rect.width));
  const py = (clientY - rect.top) * (canvas.height / Math.max(1, rect.height));
  for (const cell of state.preview.hitCells) {
    if (pointInPoly(px, py, cell.points)) return cell;
  }
  return null;
}

function previewPaint(ctx, cell, ev) {
  if (!cell) return;
  const mapId = ctx.editor.activeMapId();
  if (mapId == null) return;
  const geo = state.maps.get(mapId);
  if (!geo) return;
  if (state.workspaceMode === "scene") {
    const activeTool = ev?.altKey ? "erase" : state.sceneTool;
    const key = `${cell.x},${cell.y}:${activeTool}`;
    if (state.preview.visited.has(key)) return;
    state.preview.visited.add(key);
    if (activeTool === "erase") eraseGeometryAtCell(ctx, mapId, cell.x, cell.y, null);
    else runSimpleSceneTool(ctx, mapId, cell.x, cell.y, null);
    return;
  }
  if (state.objTool || state.workspaceMode === "object") {
    if (ev.altKey) {
      const key = `${cell.x},${cell.y}`;
      if (!state.preview.visited.has(key)) {
        state.preview.visited.add(key);
        removeObjectsAt(ctx, geo, mapId, cell.x, cell.y);
      }
    } else {
      const hit = findObjectAt(geo, cell.x, cell.y);
      if (hit && state.preview.objJustDown) { selectObject(ctx, geo, hit, mapId); return; }
      if (state.preview.objJustDown) state.objSelected = null;
      if (!state.objStart) state.objStart = { x: cell.x, y: cell.y };
      state.objCurrent = { x: cell.x, y: cell.y };
    }
    ctx.editor.requestRedraw();
    schedulePreview(ctx);
    return;
  }
  const mode = resolvePaintMode(ev);
  const key = `${cell.x},${cell.y}:${mode}`;
  if (state.preview.visited.has(key)) return;
  state.preview.visited.add(key);
  applyBrushToCell(ctx, geo, mapId, cell.x, cell.y, mode);
  ctx.editor.requestRedraw();
  schedulePreview(ctx);
}

function movePreviewFocus(ctx, dx, dy) {
  const mapId = ctx.editor.activeMapId();
  const info = mapId == null ? null : ctx.map.info(mapId);
  if (!info) return;
  state.preview.focusX = Math.max(0, Math.min(info.width - 1, Math.round((state.preview.focusX ?? 0) + dx)));
  state.preview.focusY = Math.max(0, Math.min(info.height - 1, Math.round((state.preview.focusY ?? 0) + dy)));
  const geo = state.maps.get(mapId); if (geo) persistPreviewPrefs(geo);
  schedulePreview(ctx);
}

async function chooseCliffTexture(ctx) {
  if (!ctx.selectors?.pickGraphic) {
    ctx.ui.showToast({ message: "Tu Maker Studio no expone el selector gráfico requerido.", level: "warn" });
    return;
  }
  const picked = await ctx.selectors.pickGraphic("Tilesets", {
    allowTileSelect: true,
    fields: ["sheetCols", "sheetRows"],
    title: "2.5D Geometry · textura de cliff",
  });
  if (!picked?.srcRect?.w) return;
  const list = ctx.tileset.list();
  const match = list.find((t) => String(t.tilesetName || "").toLowerCase() === String(picked.name || "").toLowerCase());
  if (!match) {
    ctx.ui.showToast({ message: "No pude resolver el tileset seleccionado.", level: "warn" });
    return;
  }
  await ensureTilesetResourceSet(ctx, match.id);
  state.preview.cliffSource = {
    tileset_id: match.id,
    graphic: picked.name,
    src_rect: { x: picked.srcRect.x, y: picked.srcRect.y, w: 32, h: 32 },
  };
  const mapId = ctx.editor.activeMapId();
  const geo = mapId == null ? null : state.maps.get(mapId);
  if (geo) persistPreviewPrefs(geo);
  schedulePreview(ctx);
}

async function chooseObjectTexture(ctx, render) {
  if (!ctx.selectors?.pickGraphic) {
    ctx.ui.showToast({ message: "Tu Maker Studio no expone el selector gráfico requerido.", level: "warn" });
    return;
  }
  const picked = await ctx.selectors.pickGraphic("Tilesets", {
    allowTileSelect: true,
    fields: ["sheetCols", "sheetRows"],
    title: "2.5D Geometry · textura de objeto",
  });
  if (!picked?.srcRect?.w) return;
  const list = ctx.tileset.list();
  const match = list.find((t) => String(t.tilesetName || "").toLowerCase() === String(picked.name || "").toLowerCase());
  if (!match) {
    ctx.ui.showToast({ message: "No pude resolver el tileset seleccionado.", level: "warn" });
    return;
  }
  await ensureTilesetResourceSet(ctx, match.id);
  const material = {
    tileset_id: match.id,
    graphic: picked.name,
    src_rect: { x: picked.srcRect.x, y: picked.srcRect.y, w: picked.srcRect.w, h: picked.srcRect.h },
  };
  const geo = currentGeo(ctx);
  const target = objFieldTarget(geo);
  if (target) {
    target.material = material;
    objEditChanged(ctx);
  } else {
    state.objMaterial = material;
  }
  const mapId = ctx.editor.activeMapId();
  if (mapId != null) void ensureSceneTilesetResources(ctx, mapId, false);
  render?.();
  schedulePreview(ctx);
}

function buttonStyle(active = false) {
  return `padding:4px 7px;border:1px solid ${active ? "var(--accent)" : "var(--border)"};border-radius:4px;background:${active ? "var(--accent-muted)" : "var(--bg-tertiary)"};color:var(--text-primary);cursor:pointer;`;
}

function selectStyle() {
  return `padding:3px 4px;background:var(--input-bg);color:var(--text-primary);border:1px solid var(--border);border-radius:4px;`;
}

function inputStyle(width = 52) {
  return `padding:3px 4px;background:var(--input-bg);color:var(--text-primary);border:1px solid var(--border);border-radius:4px;width:${width}px;`;
}

function panelHtml(geo) {
  const sel = state.sourceSelection && Number(state.sourceSelection.map_id) === Number(geo?.map_id) ? state.sourceSelection : null;
  const sourceDef = sel ? geo?.definitions?.[sel.key] || null : null;
  const sourceOverride = sel ? geo?.instance_overrides?.[sel.instance_key] || null : null;
  const sourceRule = sourceDef ? effectiveSourceRule(sourceDef, sourceOverride) : null;
  const activePreset = sourceRule?.enabled === false ? "ignore" : (sourceRule?.category || null);
  const activeHeight = sourceRule ? Number(sourceRule.height) || 0 : Number(state.brushHeight) || 0;
  const usage = state.sourceUsage && Number(state.sourceUsage.map_id) === Number(geo?.map_id) ? state.sourceUsage : null;
  const compilerStats = geo?.compiler?.stats || {};
  const selectedScopeText = state.sceneScope === "this" ? "solo este tile" : state.sceneScope === "connected" ? "iguales conectados" : "todos los iguales";
  const toolHelp = {
    select: "Haz clic en algo del mapa para editarlo.",
    paint: `Haz clic o arrastra para aplicar ${simplePresetLabel(state.brushPreset)}.`,
    raise: "Haz clic o arrastra para subir la geometría 0.25 tiles.",
    lower: "Haz clic o arrastra para bajar la geometría 0.25 tiles.",
    eyedropper: "Haz clic en algo configurado para copiar su Geometry.",
    erase: "Haz clic o arrastra para quitar Geometry sin borrar el tile.",
  }[state.sceneTool] || "";

  const sourceButtons = ["floor", "wall", "mountain", "prop", "roof", "border"].map((p) => {
    const active = state.brushPreset === p;
    return `<button data-brush-preset="${p}" style="${buttonStyle(active)}min-width:82px;height:48px;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:2px;">
      <span style="font-size:18px;line-height:16px;">${simplePresetIcon(p)}</span><span>${simplePresetLabel(p)}</span>
    </button>`;
  }).join("");

  const detectedRows = usage?.sources instanceof Map
    ? [...usage.sources.values()].sort((a,b) => b.count-a.count).slice(0,50).map((row) =>
      `<button data-source-jump="${escapeHtml(row.key)}" style="${buttonStyle(sel?.key === row.key)}max-width:220px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">${escapeHtml(row.label || row.key)} · ×${row.count}${geo?.definitions?.[row.key] ? " · ✓" : ""}</button>`
    ).join("")
    : `<span style="color:var(--text-tertiary);">Aún no se ha indexado el mapa.</span>`;

  const simpleInspector = sel ? `
    <div style="border:1px solid var(--border);border-radius:8px;background:var(--bg-secondary);padding:10px;display:flex;flex-direction:column;gap:9px;">
      <div style="display:flex;gap:10px;align-items:center;min-width:0;">
        <canvas data-id="source-thumb" width="64" height="64" style="width:64px;height:64px;flex:0 0 auto;border:1px solid var(--border);border-radius:5px;image-rendering:pixelated;background:var(--canvas-bg);"></canvas>
        <div style="min-width:0;flex:1;">
          <div style="font-size:11px;color:var(--text-tertiary);text-transform:uppercase;letter-spacing:.04em;">Seleccionado</div>
          <strong style="font-size:14px;display:block;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">${escapeHtml(sel.label)}</strong>
          <div style="font-size:11px;color:var(--text-secondary);margin-top:2px;">${sourceDef ? `${simplePresetLabel(activePreset)} · ${activeHeight} tiles` : "Sin Geometry todavía"}</div>
        </div>
      </div>

      <div>
        <div style="font-size:11px;color:var(--text-tertiary);margin-bottom:5px;">¿QUÉ ES?</div>
        <div style="display:flex;flex-wrap:wrap;gap:5px;">
          ${["floor","wall","mountain","prop","roof","border"].map((p) => `<button data-quick-preset="${p}" style="${buttonStyle(activePreset === p)}">${simplePresetIcon(p)} ${simplePresetLabel(p)}</button>`).join("")}
        </div>
      </div>

      <div style="display:flex;flex-wrap:wrap;gap:8px;align-items:center;">
        <strong>Altura</strong>
        <button data-act="simple-height-minus" style="${buttonStyle()}">−</button>
        <input data-id="simple-height" type="number" min="0" step="0.25" value="${activeHeight}" style="${inputStyle(64)}" />
        <span style="color:var(--text-secondary);">tiles</span>
        <button data-act="simple-height-plus" style="${buttonStyle()}">+</button>
      </div>

      ${sourceDef ? `<div style="display:flex;flex-wrap:wrap;gap:12px;align-items:center;font-size:12px;">
        <label><input data-id="simple-connect" type="checkbox" ${sourceRule?.components?.connect_neighbors ? "checked" : ""}/> Unir piezas vecinas</label>
        <label><input data-id="simple-cap" type="checkbox" ${sourceRule?.components?.cap !== false ? "checked" : ""}/> Superficie arriba</label>
        <label>Colisión <select data-id="simple-collision" style="${selectStyle()}">
          <option value="none" ${sourceRule?.collision === "none" ? "selected" : ""}>Atravesable</option>
          <option value="solid" ${sourceRule?.collision === "solid" ? "selected" : ""}>Sólida</option>
          <option value="climb" ${sourceRule?.collision === "climb" ? "selected" : ""}>Escalable</option>
          <option value="one-way" ${sourceRule?.collision === "one-way" ? "selected" : ""}>Solo desde arriba</option>
        </select></label>
      </div>` : `<div style="font-size:12px;color:var(--text-secondary);">Elige un tipo arriba o usa <strong>Pintar</strong> para crear Geometry.</div>`}

      <div style="display:flex;gap:6px;flex-wrap:wrap;">
        <button data-act="simple-copy" style="${buttonStyle()}">Copiar Geometry</button>
        <button data-act="simple-remove" style="${buttonStyle()}">Quitar Geometry</button>
      </div>
    </div>` : `
    <div style="border:1px dashed var(--border);border-radius:8px;padding:18px;text-align:center;color:var(--text-secondary);background:var(--bg-secondary);">
      <div style="font-size:28px;margin-bottom:5px;">⬉</div>
      <strong>Haz clic en el mapa</strong>
      <div style="font-size:12px;margin-top:4px;">Geometry detectará automáticamente el tile real y su tileset, incluso en capas extendidas.</div>
    </div>`;

  const previewBlock = state.viewMode === "2.5d" ? `
    <div style="padding:7px 8px;border-bottom:1px solid var(--border);display:flex;flex-wrap:wrap;gap:8px;align-items:center;background:var(--bg-secondary);">
      <button data-act="gameView" style="${buttonStyle()}">Vista juego</button>
      <button data-yaw="0" style="${buttonStyle()}">Frente</button>
      <button data-yaw="90" style="${buttonStyle()}">Derecha</button>
      <button data-yaw="180" style="${buttonStyle()}">Atrás</button>
      <button data-yaw="270" style="${buttonStyle()}">Izquierda</button>
      <label>Zoom <input data-id="pzoom" type="range" min="0.35" max="2.2" step="0.05" value="${state.preview.zoom}" /></label>
      <label><input data-id="collision" type="checkbox" ${state.preview.showCollision ? "checked" : ""}/> colisión</label>
      <label><input data-id="wire" type="checkbox" ${state.preview.showWire ? "checked" : ""}/> wire</label>
      <label><input data-id="player" type="checkbox" ${state.preview.showPlayer ? "checked" : ""}/> jugador</label>
    </div>
    <div style="flex:1;min-height:360px;padding:8px;display:flex;align-items:center;justify-content:center;background:var(--canvas-bg);overflow:hidden;">
      <canvas data-id="preview" width="640" height="480" style="display:block;width:min(100%,1040px);height:auto;max-height:100%;aspect-ratio:4/3;border:1px solid var(--border);background:var(--canvas-bg);image-rendering:pixelated;cursor:crosshair;touch-action:none;"></canvas>
    </div>
    <div style="padding:6px 8px;border-top:1px solid var(--border);display:flex;justify-content:space-between;gap:8px;color:var(--text-tertiary);font-size:11px;">
      <span data-id="status">Vista 2.5D</span><span>Clic = editar · arrastre derecho = mover cámara · rueda = zoom</span>
    </div>` : `
    <div style="flex:1;min-height:220px;display:flex;align-items:center;justify-content:center;padding:24px;background:var(--canvas-bg);">
      <div style="max-width:520px;text-align:center;color:var(--text-secondary);line-height:1.5;">
        <div style="font-size:34px;margin-bottom:8px;">🗺️</div>
        <strong style="color:var(--text-primary);font-size:15px;">Edita directamente sobre el mapa de Maker Studio</strong>
        <div style="margin-top:5px;">No necesitas importar el gráfico ni buscar su tileset. Selecciona una herramienta arriba y haz clic sobre los tiles ya colocados.</div>
        <div style="margin-top:10px;font-size:12px;">${escapeHtml(toolHelp)} Alcance actual: <strong>${selectedScopeText}</strong>.</div>
        <button data-view="2.5d" style="${buttonStyle()}margin-top:14px;">Abrir vista 2.5D</button>
      </div>
    </div>`;

  return `
  <div style="height:100%;min-height:420px;display:flex;flex-direction:column;color:var(--text-primary);font:13px system-ui,sans-serif;background:var(--bg-primary);">
    <div style="padding:8px;border-bottom:1px solid var(--border);display:flex;gap:6px;align-items:center;flex-wrap:wrap;background:var(--bg-tertiary);">
      <strong style="font-size:14px;margin-right:4px;">⬢ Geometry</strong>
      <button data-view="2d" style="${buttonStyle(state.viewMode === "2d")}">Mapa 2D</button>
      <button data-view="2.5d" style="${buttonStyle(state.viewMode === "2.5d")}">Vista 2.5D</button>
      <span style="font-size:11px;color:var(--text-tertiary);">Edita lo que ya está colocado. Geometry resuelve el recurso automáticamente.</span>
      <button data-act="save" style="${buttonStyle()}margin-left:auto;">Guardar</button>
    </div>

    <div style="padding:8px;border-bottom:1px solid var(--border);background:var(--bg-secondary);">
      <div style="display:flex;gap:5px;flex-wrap:wrap;align-items:center;">
        <button data-scene-tool="select" style="${buttonStyle(state.sceneTool === "select")}">⬉ Seleccionar</button>
        <button data-scene-tool="paint" style="${buttonStyle(state.sceneTool === "paint")}">🖌 Pintar</button>
        <button data-scene-tool="raise" style="${buttonStyle(state.sceneTool === "raise")}">↥ Altura +</button>
        <button data-scene-tool="lower" style="${buttonStyle(state.sceneTool === "lower")}">↧ Altura −</button>
        <button data-scene-tool="eyedropper" style="${buttonStyle(state.sceneTool === "eyedropper")}">◉ Copiar</button>
        <button data-scene-tool="erase" style="${buttonStyle(state.sceneTool === "erase")}">⌫ Borrar Geometry</button>
        <span style="font-size:11px;color:var(--text-secondary);margin-left:4px;">${escapeHtml(toolHelp)}</span>
      </div>

      <div style="display:flex;flex-wrap:wrap;gap:6px;align-items:center;margin-top:8px;">
        <span style="font-size:11px;color:var(--text-tertiary);text-transform:uppercase;">Aplicar a</span>
        <button data-scope="this" style="${buttonStyle(state.sceneScope === "this")}">Este tile</button>
        <button data-scope="connected" style="${buttonStyle(state.sceneScope === "connected")}">Iguales conectados</button>
        <button data-scope="all" style="${buttonStyle(state.sceneScope === "all")}">Todos los iguales</button>
      </div>

      <div style="display:flex;gap:6px;align-items:center;flex-wrap:wrap;margin-top:9px;">
        <span style="font-size:11px;color:var(--text-tertiary);text-transform:uppercase;">Pincel</span>
        ${sourceButtons}
        <label style="display:flex;gap:4px;align-items:center;margin-left:4px;">Altura
          <input data-id="brush-height" type="number" min="0" step="0.25" value="${Number(state.brushHeight) || 0}" style="${inputStyle(60)}" />
        </label>
      </div>
    </div>

    <div style="padding:8px;border-bottom:1px solid var(--border);">${simpleInspector}</div>

    <details style="border-bottom:1px solid var(--border);background:var(--bg-secondary);">
      <summary style="padding:7px 9px;cursor:pointer;color:var(--text-secondary);">Avanzado</summary>
      <div style="padding:8px;display:flex;flex-direction:column;gap:8px;font-size:11px;">
        <div style="display:flex;flex-wrap:wrap;gap:6px;align-items:center;">
          <button data-act="source-scan" style="${buttonStyle()}">Reescanear mapa</button>
          <button data-act="source-compile" style="${buttonStyle()}">Recompilar</button>
          <label><input data-id="compiler-auto" type="checkbox" ${geo?.compiler?.auto_compile !== false ? "checked" : ""}/> recompilar automáticamente</label>
          <span style="color:var(--text-tertiary);">Tiles ${compilerStats.placed_tiles || 0} · recursos ${compilerStats.unique_sources || 0} · Geometry ${(geo?.compiled_objects || []).length}</span>
        </div>
        ${sel ? `<div style="font-family:monospace;color:var(--text-tertiary);overflow-wrap:anywhere;">Origen: ${escapeHtml(sel.key)} · Map ${sel.map_id} · Layer ${sel.layer} · ${sel.x},${sel.y} · tileId ${sel.tile_id} · tilesetId ${sel.tileset_id || "extra"}</div>` : ""}
        ${sourceDef ? `<div style="display:flex;flex-wrap:wrap;gap:7px;align-items:center;">
          <label><input data-id="src-enabled" type="checkbox" ${sourceDef.enabled !== false ? "checked" : ""}/> activo</label>
          <label>Tipo <select data-id="src-category" style="${selectStyle()}">${OBJECT_CATEGORIES.map(([id,name]) => `<option value="${id}" ${(sourceRule?.category || "wall") === id ? "selected" : ""}>${name}</option>`).join("")}</select></label>
          <label>Mesh <select data-id="src-type" style="${selectStyle()}"><option value="cube" ${sourceRule?.type === "cube" ? "selected" : ""}>Extruded</option><option value="plane" ${sourceRule?.type === "plane" ? "selected" : ""}>Plane</option></select></label>
          <label>H <input data-id="src-height" type="number" min="0" step="0.25" value="${sourceRule?.height ?? 0}" style="${inputStyle(52)}" /></label>
          <label>Z <input data-id="src-z" type="number" min="0" step="0.25" value="${sourceRule?.anchor_z ?? 0}" style="${inputStyle(52)}" /></label>
          <label>Collision <select data-id="src-collision" style="${selectStyle()}">${OBJECT_COLLISIONS.map((c) => `<option value="${c}" ${(sourceRule?.collision || "none") === c ? "selected" : ""}>${c}</option>`).join("")}</select></label>
          <label><input data-id="src-connect" type="checkbox" ${sourceRule?.components?.connect_neighbors ? "checked" : ""}/> connect</label>
          <label><input data-id="src-cap" type="checkbox" ${sourceRule?.components?.cap !== false ? "checked" : ""}/> cap</label>
          <label><input data-id="src-charfront" type="checkbox" ${sourceRule?.characters_in_front ? "checked" : ""}/> character front</label>
        </div>` : ""}
        <div style="display:flex;gap:5px;align-items:center;overflow-x:auto;">${detectedRows}</div>
      </div>
    </details>

    ${previewBlock}
  </div>`;
}
function bindPanel(ctx, host, render) {
  const q = (s) => host.querySelector(s);

  for (const btn of host.querySelectorAll("[data-view]")) {
    btn.addEventListener("click", () => {
      const view = btn.getAttribute("data-view");
      if (!['2d','2.5d'].includes(view)) return;
      state.viewMode = view;
      render();
      if (view === '2.5d') schedulePreview(ctx);
    });
  }
  for (const btn of host.querySelectorAll("[data-scene-tool]")) {
    btn.addEventListener("click", () => {
      state.workspaceMode = "scene";
      state.objTool = false;
      state.sceneTool = btn.getAttribute("data-scene-tool") || "select";
      try { ctx.editor.setTool(TOOL_ID); } catch (_) {}
      render();
      ctx.editor.requestRedraw();
    });
  }
  for (const btn of host.querySelectorAll("[data-scope]")) {
    btn.addEventListener("click", () => {
      const scope = btn.getAttribute("data-scope");
      if (!["this", "connected", "all"].includes(scope)) return;
      state.sceneScope = scope;
      render();
    });
  }
  for (const btn of host.querySelectorAll("[data-brush-preset]")) {
    btn.addEventListener("click", () => {
      state.brushPreset = btn.getAttribute("data-brush-preset") || "wall";
      state.sourcePreset = state.brushPreset;
      const preset = SCENE_GEOMETRY_PRESETS[state.brushPreset];
      if (preset) state.brushHeight = Number(preset.height) || 0;
      state.sceneTool = "paint";
      render();
    });
  }
  for (const btn of host.querySelectorAll("[data-quick-preset]")) {
    btn.addEventListener("click", () => {
      const preset = btn.getAttribute("data-quick-preset") || "wall";
      const sel = state.sourceSelection;
      if (!sel) return;
      state.brushPreset = preset;
      state.sourcePreset = preset;
      const p = SCENE_GEOMETRY_PRESETS[preset];
      if (p) state.brushHeight = Number(p.height) || 0;
      applySimpleGeometry(ctx, sel, preset, state.brushHeight);
      render();
    });
  }
  q('[data-id="brush-height"]')?.addEventListener("change", (e) => {
    state.brushHeight = Math.max(0, Number(e.target.value) || 0);
    render();
  });
  q('[data-act="simple-height-minus"]')?.addEventListener("click", () => {
    const sel = state.sourceSelection; if (!sel) return;
    const geo = currentGeo(ctx); const def = geo?.definitions?.[sel.key];
    const rule = def ? effectiveSourceRule(def, geo.instance_overrides?.[sel.instance_key]) : null;
    setSimpleGeometryHeight(ctx, sel, Math.max(0, (Number(rule?.height) || Number(state.brushHeight) || 0) - 0.25));
  });
  q('[data-act="simple-height-plus"]')?.addEventListener("click", () => {
    const sel = state.sourceSelection; if (!sel) return;
    const geo = currentGeo(ctx); const def = geo?.definitions?.[sel.key];
    const rule = def ? effectiveSourceRule(def, geo.instance_overrides?.[sel.instance_key]) : null;
    setSimpleGeometryHeight(ctx, sel, (Number(rule?.height) || Number(state.brushHeight) || 0) + 0.25);
  });
  q('[data-id="simple-height"]')?.addEventListener("change", (e) => {
    const sel = state.sourceSelection; if (!sel) return;
    setSimpleGeometryHeight(ctx, sel, e.target.value);
  });
  q('[data-id="simple-connect"]')?.addEventListener("change", (e) => {
    const sel = state.sourceSelection; if (sel) patchSimpleGeometry(ctx, sel, { components: { connect_neighbors: !!e.target.checked } });
  });
  q('[data-id="simple-cap"]')?.addEventListener("change", (e) => {
    const sel = state.sourceSelection; if (sel) patchSimpleGeometry(ctx, sel, { components: { cap: !!e.target.checked } });
  });
  q('[data-id="simple-collision"]')?.addEventListener("change", (e) => {
    const sel = state.sourceSelection; if (sel) patchSimpleGeometry(ctx, sel, { collision: e.target.value });
  });
  q('[data-act="simple-copy"]')?.addEventListener("click", () => {
    const sel = state.sourceSelection; if (sel) eyedropSimpleGeometry(ctx, sel);
  });
  q('[data-act="simple-remove"]')?.addEventListener("click", () => {
    const sel = state.sourceSelection; if (sel) eraseSimpleGeometry(ctx, sel);
  });

  // Workspace switcher: Geometry is one Maker Studio tool, while Scene/Height/
  // Objects are editor sub-modes. Scene is the default source-driven workflow.
  for (const btn of host.querySelectorAll("[data-workspace]")) {
    btn.addEventListener("click", () => {
      const mode = btn.getAttribute("data-workspace");
      if (!["scene", "height", "object"].includes(mode)) return;
      state.workspaceMode = mode;
      state.objTool = mode === "object";
      try { ctx.editor.setTool(TOOL_ID); } catch (_) {}
      render();
      ctx.editor.requestRedraw();
      schedulePreview(ctx);
    });
  }

  // Scene Compiler controls --------------------------------------------------
  q('[data-act="source-scan"]')?.addEventListener("click", async () => {
    const mapId = ctx.editor.activeMapId();
    if (mapId == null) return;
    await scanGeometrySources(ctx, mapId, true);
    render();
  });
  q('[data-act="source-compile"]')?.addEventListener("click", async () => {
    const mapId = ctx.editor.activeMapId();
    const geo = mapId == null ? null : state.maps.get(mapId);
    if (!geo) return;
    await compileGeometryScene(ctx, mapId, geo, { forceScan: true, reason: "manual-panel" });
    await saveMap(ctx, mapId, { skipCompile: true });
    render();
  });
  q('[data-id="compiler-auto"]')?.addEventListener("change", async (e) => {
    const mapId = ctx.editor.activeMapId();
    const geo = mapId == null ? null : state.maps.get(mapId);
    if (!geo) return;
    geo.compiler ||= {};
    geo.compiler.auto_compile = !!e.target.checked;
    if (geo.compiler.auto_compile && Object.keys(geo.definitions || {}).length) {
      await compileGeometryScene(ctx, mapId, geo, { reason: "auto-enabled" });
    }
    await saveMap(ctx, mapId, { skipCompile: true });
    render();
  });
  for (const btn of host.querySelectorAll("[data-source-preset]")) {
    btn.addEventListener("click", () => applyPresetToSelectedSource(ctx, btn.getAttribute("data-source-preset")));
  }
  const bindSource = (selector, eventName, patcher) => {
    q(selector)?.addEventListener(eventName, (e) => updateSelectedSourceDefinition(ctx, patcher(e.target)));
  };
  bindSource('[data-id="src-enabled"]', "change", (el) => ({ enabled: !!el.checked }));
  bindSource('[data-id="src-category"]', "change", (el) => ({ category: el.value }));
  bindSource('[data-id="src-type"]', "change", (el) => ({ type: el.value === "plane" ? "plane" : "cube" }));
  bindSource('[data-id="src-height"]', "change", (el) => ({ height: Math.max(0, Number(el.value) || 0) }));
  bindSource('[data-id="src-z"]', "change", (el) => ({ anchor_z: Math.max(0, Number(el.value) || 0) }));
  bindSource('[data-id="src-collision"]', "change", (el) => ({ collision: el.value }));
  bindSource('[data-id="src-connect"]', "change", (el) => ({ components: { connect_neighbors: !!el.checked } }));
  bindSource('[data-id="src-cap"]', "change", (el) => ({ components: { cap: !!el.checked } }));
  bindSource('[data-id="src-charfront"]', "change", (el) => ({ characters_in_front: !!el.checked }));

  q('[data-id="inst-height"]')?.addEventListener("change", (e) => updateSelectedInstanceOverride(ctx, { height: Math.max(0, Number(e.target.value) || 0) }));
  q('[data-id="inst-z"]')?.addEventListener("change", (e) => updateSelectedInstanceOverride(ctx, { anchor_z: Math.max(0, Number(e.target.value) || 0) }));

  q('[data-act="instance-disable"]')?.addEventListener("click", () => {
    const geo = currentGeo(ctx), sel = state.sourceSelection;
    if (!geo || !sel) return;
    const old = geo.instance_overrides?.[sel.instance_key];
    updateSelectedInstanceOverride(ctx, { disabled: old?.disabled !== true });
  });
  q('[data-act="instance-clear"]')?.addEventListener("click", () => clearSelectedInstanceOverride(ctx));
  q('[data-act="source-delete"]')?.addEventListener("click", async () => {
    const geo = currentGeo(ctx), sel = state.sourceSelection;
    if (!geo || !sel) return;
    delete geo.definitions?.[sel.key];
    if (geo.instance_overrides) {
      for (const key of Object.keys(geo.instance_overrides)) {
        if (key.endsWith(`|${sel.key}`)) delete geo.instance_overrides[key];
      }
    }
    await compileGeometryScene(ctx, sel.map_id, geo, { reason: "definition-delete" });
    await saveMap(ctx, sel.map_id, { skipCompile: true });
    render();
  });
  for (const btn of host.querySelectorAll("[data-source-jump]")) {
    btn.addEventListener("click", async () => {
      const mapId = ctx.editor.activeMapId();
      if (mapId == null) return;
      const key = btn.getAttribute("data-source-jump");
      let usage = state.sourceUsageByMap.get(mapId);
      if (!usage) usage = await scanGeometrySources(ctx, mapId, true);
      const ex = usage?.sources?.get?.(key)?.examples?.[0];
      if (ex) selectSourceAt(ctx, mapId, ex.x, ex.y, ex.layer);
    });
  }

  // Paint the selected source from the exact tile occurrence. This is not a
  // tileset-base lookup: readTileVisualData retains the extended layer's own
  // tilesetId/autotile source before sourceForTileData resolves the pixels.
  const paintSourceThumb = async () => {
    const canvas = q('[data-id="source-thumb"]');
    const sel = state.sourceSelection;
    if (!canvas || !sel || Number(sel.map_id) !== Number(ctx.editor.activeMapId())) return;
    try {
      await ensureSceneTilesetResources(ctx, sel.map_id, false);
      const layer = authoritativeLayers(ctx, sel.map_id, true).find((l) => Number(layerRef(l)) === Number(sel.layer));
      if (!layer || !host.isConnected) return;
      const data = readTileVisualData(ctx, sel.map_id, layer, sel.x, sel.y);
      if (!data) return;
      const src = sourceForTileData(ctx, Number(data.tileId) || 0, data, layer, Number(data.tilesetId) || sel.tileset_id);
      if (!src) return;
      const c = canvas.getContext("2d");
      c.clearRect(0, 0, canvas.width, canvas.height);
      c.imageSmoothingEnabled = false;
      const scale = Math.min(canvas.width / src.sw, canvas.height / src.sh);
      const dw = src.sw * scale, dh = src.sh * scale;
      c.drawImage(src.img, src.sx, src.sy, src.sw, src.sh, (canvas.width - dw) / 2, (canvas.height - dh) / 2, dw, dh);
    } catch (err) { ctx.log.warn("2.5D Geometry: source thumbnail failed", err); }
  };
  void paintSourceThumb();
  const levelInput = q('[data-id="level"]');
  levelInput?.addEventListener("change", () => {
    state.level = Math.max(0, Math.round(Number(levelInput.value) || 0));
    render();
  });
  q('[data-act="minus"]')?.addEventListener("click", () => { state.level = Math.max(0, state.level - 1); render(); });
  q('[data-act="plus"]')?.addEventListener("click", () => { state.level += 1; render(); });
  for (const btn of host.querySelectorAll("[data-mode]")) {
    const mode = btn.getAttribute("data-mode");
    btn.addEventListener("click", () => { state.mode = mode; render(); });
  }
  q('[data-act="tool"]')?.addEventListener("click", () => ctx.editor.setTool(TOOL_ID));
  q('[data-act="save"]')?.addEventListener("click", () => { const id = ctx.editor.activeMapId(); if (id != null) void saveMap(ctx, id); });

  q('[data-act="objtool"]')?.addEventListener("click", () => { state.workspaceMode = "object"; state.objTool = true; ctx.editor.setTool(TOOL_ID); render(); });
  for (const btn of host.querySelectorAll("[data-select-object]")) {
    btn.addEventListener("click", () => {
      const geo = currentGeo(ctx);
      const obj = (geo?.objects || []).find((o) => Number(o.id) === Number(btn.getAttribute("data-select-object")));
      if (obj) selectObject(ctx, geo, obj, ctx.editor.activeMapId());
    });
  }
  const objTarget = () => objFieldTarget(currentGeo(ctx));
  q('[data-id="objtype"]')?.addEventListener("change", (e) => {
    const t = objTarget();
    if (t) { t.type = e.target.value === "plane" ? "plane" : "cube"; objEditChanged(ctx); }
    else { state.objType = e.target.value; render(); }
  });
  q('[data-id="objheight"]')?.addEventListener("change", (e) => {
    const v = Math.max(0, Math.round(Number(e.target.value) || 0));
    const t = objTarget();
    if (t) { t.height = v; objEditChanged(ctx); }
    else { state.objHeight = v; }
  });
  q('[data-id="objz"]')?.addEventListener("change", (e) => {
    const v = Math.max(0, Math.round(Number(e.target.value) || 0));
    const t = objTarget();
    if (t) { t.anchor_z = v; objEditChanged(ctx); }
    else { state.objAnchorZ = v; }
  });
  q('[data-id="objcollision"]')?.addEventListener("change", (e) => {
    const t = objTarget();
    if (t) { t.collision = e.target.value; objEditChanged(ctx); }
    else { state.objCollision = e.target.value; render(); }
  });
  q('[data-id="objcategory"]')?.addEventListener("change", (e) => {
    const cat = e.target.value;
    const preset = OBJECT_CATEGORY_PRESETS[cat];
    const t = objTarget();
    if (t) {
      t.category = cat;
      if (preset) Object.assign(t, { type: preset.type, height: preset.height, anchor_z: preset.anchor_z, collision: preset.collision });
      objEditChanged(ctx);
    } else {
      state.objCategory = cat;
      if (preset) Object.assign(state, { objType: preset.type, objHeight: preset.height, objAnchorZ: preset.anchor_z, objCollision: preset.collision });
      render();
    }
  });
  q('[data-act="objmaterial"]')?.addEventListener("click", () => void chooseObjectTexture(ctx, render));

  q('[data-id="objname"]')?.addEventListener("change", (e) => {
    const t = objTarget(); if (!t) return; t.name = String(e.target.value || `Object ${t.id}`).trim() || `Object ${t.id}`; objEditChanged(ctx);
  });
  q('[data-id="objanchorrow"]')?.addEventListener("change", (e) => {
    const t = objTarget(); if (!t) return; t.anchor_row = Math.min(t.h - 1, Math.max(0, Math.round(Number(e.target.value) || 0))); objEditChanged(ctx);
  });
  q('[data-id="objcharfront"]')?.addEventListener("change", (e) => {
    const t = objTarget(); if (!t) return; t.characters_in_front = !!e.target.checked; objEditChanged(ctx);
  });
  q('[data-id="fpmode"]')?.addEventListener("change", (e) => { state.objFootprintMode = e.target.value; });
  for (const cell of host.querySelectorAll("[data-fp-cell]")) {
    cell.addEventListener("click", () => {
      const t = objTarget(); if (!t) return;
      const [dx, dy] = cell.getAttribute("data-fp-cell").split(",").map(Number);
      setFootprintCell(ctx, t, dx, dy, state.objFootprintMode);
    });
  }
  q('[data-act="objmoveleft"]')?.addEventListener("click", () => moveSelectedObject(ctx, -1, 0));
  q('[data-act="objmoveright"]')?.addEventListener("click", () => moveSelectedObject(ctx, 1, 0));
  q('[data-act="objmoveup"]')?.addEventListener("click", () => moveSelectedObject(ctx, 0, -1));
  q('[data-act="objmovedown"]')?.addEventListener("click", () => moveSelectedObject(ctx, 0, 1));
  q('[data-act="objrotleft"]')?.addEventListener("click", () => rotateSelectedObject(ctx, false));
  q('[data-act="objrotright"]')?.addEventListener("click", () => rotateSelectedObject(ctx, true));
  q('[data-act="objheightminus"]')?.addEventListener("click", () => { const t=objTarget(); if(t){t.height=Math.max(0,(Number(t.height)||0)-1);objEditChanged(ctx);} });
  q('[data-act="objheightplus"]')?.addEventListener("click", () => { const t=objTarget(); if(t){t.height=(Number(t.height)||0)+1;objEditChanged(ctx);} });
  q('[data-act="objfit"]')?.addEventListener("click", () => fitSelectedObjectToMaterial(ctx));
  q('[data-act="objduplicate"]')?.addEventListener("click", () => duplicateSelectedObject(ctx));
  q('[data-act="objdelete"]')?.addEventListener("click", () => deleteSelectedObject(ctx));

  q('[data-id="objx"]')?.addEventListener("change", (e) => {
    const geo = currentGeo(ctx); const t = objFieldTarget(geo);
    if (!t || !geo) return;
    const v = Math.max(0, Math.round(Number(e.target.value) || 0));
    if (v + t.w <= geo.width) { t.x = v; objEditChanged(ctx); } else e.target.value = t.x;
  });
  q('[data-id="objy"]')?.addEventListener("change", (e) => {
    const geo = currentGeo(ctx); const t = objFieldTarget(geo);
    if (!t || !geo) return;
    const v = Math.max(0, Math.round(Number(e.target.value) || 0));
    if (v + t.h <= geo.height) { t.y = v; objEditChanged(ctx); } else e.target.value = t.y;
  });
  q('[data-id="objw"]')?.addEventListener("change", (e) => {
    const geo = currentGeo(ctx); const t = objFieldTarget(geo);
    if (!t || !geo) return;
    const v = Math.max(1, Math.round(Number(e.target.value) || 1));
    if (t.x + v <= geo.width) { t.w = v; t.footprint = normalizeFootprint(t.footprint, t.w, t.h); objEditChanged(ctx); } else e.target.value = t.w;
  });
  q('[data-id="objh"]')?.addEventListener("change", (e) => {
    const geo = currentGeo(ctx); const t = objFieldTarget(geo);
    if (!t || !geo) return;
    const v = Math.max(1, Math.round(Number(e.target.value) || 1));
    if (t.y + v <= geo.height) { t.h = v; t.anchor_row = Math.min(t.h - 1, t.anchor_row ?? t.h - 1); t.footprint = normalizeFootprint(t.footprint, t.w, t.h); objEditChanged(ctx); } else e.target.value = t.h;
  });
  q('[data-act="objnew"]')?.addEventListener("click", () => { state.objSelected = null; render(); });

  const angle = q('[data-id="angle"]');
  angle?.addEventListener("input", () => {
    state.preview.angle = Number(angle.value) || 25;
    const t = q('[data-id="angleText"]'); if (t) t.textContent = `${Math.round(state.preview.angle)}°`;
    schedulePreview(ctx);
  });
  angle?.addEventListener("change", () => { const id = ctx.editor.activeMapId(); const geo = id == null ? null : state.maps.get(id); if (geo) persistPreviewPrefs(geo); });

  const yaw = q('[data-id="yaw"]');
  const setYaw = (value, persist = false) => {
    state.preview.yaw = ((Number(value) % 360) + 360) % 360;
    if (yaw) yaw.value = String(Math.round(state.preview.yaw));
    const t = q('[data-id="yawText"]'); if (t) t.textContent = `${Math.round(state.preview.yaw)}°`;
    if (persist) { const id = ctx.editor.activeMapId(); const geo = id == null ? null : state.maps.get(id); if (geo) persistPreviewPrefs(geo); }
    schedulePreview(ctx);
  };
  yaw?.addEventListener("input", () => setYaw(yaw.value, false));
  yaw?.addEventListener("change", () => setYaw(yaw.value, true));
  q('[data-act="yawLeft"]')?.addEventListener("click", () => setYaw(state.preview.yaw - 15, true));
  q('[data-act="yawRight"]')?.addEventListener("click", () => setYaw(state.preview.yaw + 15, true));
  for (const btn of host.querySelectorAll("[data-yaw]")) {
    btn.addEventListener("click", () => setYaw(Number(btn.getAttribute("data-yaw")) || 0, true));
  }

  const pzoom = q('[data-id="pzoom"]');
  pzoom?.addEventListener("input", () => {
    state.preview.zoom = Number(pzoom.value) || 1;
    const t = q('[data-id="zoomText"]'); if (t) t.textContent = state.preview.zoom.toFixed(2);
    schedulePreview(ctx);
  });
  pzoom?.addEventListener("change", () => { const id = ctx.editor.activeMapId(); const geo = id == null ? null : state.maps.get(id); if (geo) persistPreviewPrefs(geo); });

  q('[data-act="left"]')?.addEventListener("click", () => movePreviewFocus(ctx, -1, 0));
  q('[data-act="right"]')?.addEventListener("click", () => movePreviewFocus(ctx, 1, 0));
  q('[data-act="up"]')?.addEventListener("click", () => movePreviewFocus(ctx, 0, -1));
  q('[data-act="down"]')?.addEventListener("click", () => movePreviewFocus(ctx, 0, 1));
  q('[data-act="center2d"]')?.addEventListener("click", () => {
    const mapId = ctx.editor.activeMapId();
    const hover = ctx.editor.hoverTile?.();
    const sel = mapId == null ? null : ctx.map.selection(mapId)?.bounds;
    if (hover) { state.preview.focusX = hover.x; state.preview.focusY = hover.y; }
    else if (sel) { state.preview.focusX = sel.x + (sel.w - 1) / 2; state.preview.focusY = sel.y + (sel.h - 1) / 2; }
    ensurePreviewFocus(ctx, mapId);
    schedulePreview(ctx);
  });
  q('[data-act="cliff"]')?.addEventListener("click", () => void chooseCliffTexture(ctx));
  q('[data-act="gameView"]')?.addEventListener("click", () => {
    state.preview.angle = 25;
    state.preview.yaw = 0;
    state.preview.zoom = 1.0;
    if (angle) angle.value = "25";
    const angleText = q('[data-id="angleText"]'); if (angleText) angleText.textContent = "25°";
    if (yaw) yaw.value = "0";
    const yawText = q('[data-id="yawText"]'); if (yawText) yawText.textContent = "0°";
    if (pzoom) pzoom.value = "1";
    const zoomText = q('[data-id="zoomText"]'); if (zoomText) zoomText.textContent = "1.00";
    const id = ctx.editor.activeMapId(); const geo = id == null ? null : state.maps.get(id); if (geo) persistPreviewPrefs(geo);
    schedulePreview(ctx);
  });

  const persistSceneToggle = () => { const id = ctx.editor.activeMapId(); const geo = id == null ? null : state.maps.get(id); if (geo) persistPreviewPrefs(geo); };
  q('[data-id="collision"]')?.addEventListener("change", (e) => { state.preview.showCollision = e.target.checked; schedulePreview(ctx); });
  q('[data-id="wire"]')?.addEventListener("change", (e) => { state.preview.showWire = e.target.checked; schedulePreview(ctx); });
  q('[data-id="player"]')?.addEventListener("change", (e) => { state.preview.showPlayer = e.target.checked; schedulePreview(ctx); });
  q('[data-id="events"]')?.addEventListener("change", (e) => { state.preview.showEvents = e.target.checked; persistSceneToggle(); const id = ctx.editor.activeMapId(); if (id != null && state.preview.showEvents) void ensurePreviewResources(ctx, id, true); schedulePreview(ctx); });
  q('[data-id="tags"]')?.addEventListener("change", (e) => { state.preview.showTags = e.target.checked; persistSceneToggle(); schedulePreview(ctx); });
  q('[data-id="fullmap"]')?.addEventListener("change", (e) => { state.preview.fullMap = e.target.checked; persistSceneToggle(); schedulePreview(ctx); });
  q('[data-id="follow"]')?.addEventListener("change", (e) => { state.preview.followHover = e.target.checked; });
  q('[data-id="overlay"]')?.addEventListener("change", (e) => { state.showOverlay = e.target.checked; ctx.editor.requestRedraw(); });
  q('[data-id="refs2d"]')?.addEventListener("change", (e) => { state.show2DRefs = e.target.checked; ctx.editor.requestRedraw(); });
  q('[data-id="ignoreColor"]')?.addEventListener("change", (e) => {
    state.preview.ignoreColorTransforms = e.target.checked;
    state.preview.transformedSourceCache.clear();
    schedulePreview(ctx);
  });

  const canvas = q('[data-id="preview"]');
  state.preview.canvas = canvas;
  state.preview.status = q('[data-id="status"]');
  if (canvas) {
    canvas.addEventListener("contextmenu", (ev) => ev.preventDefault());
    canvas.addEventListener("pointerdown", (ev) => {
      if (ev.button === 2) {
        ev.preventDefault();
        canvas.setPointerCapture?.(ev.pointerId);
        state.preview.orbiting = true;
        state.preview.orbitStartX = ev.clientX;
        state.preview.orbitStartY = ev.clientY;
        state.preview.orbitStartYaw = state.preview.yaw;
        state.preview.orbitStartPitch = state.preview.angle;
        canvas.style.cursor = "grabbing";
        return;
      }
      if (ev.button !== 0) return;
      canvas.setPointerCapture?.(ev.pointerId);
      state.preview.dragging = true;
      state.preview.objJustDown = (state.objTool || state.workspaceMode === "object") && !ev.altKey;
      state.preview.visited.clear();
      if ((state.objTool || state.workspaceMode === "object") && !ev.altKey) { state.objStart = null; state.objCurrent = null; }
      const cell = hitPreviewCell(canvas, ev.clientX, ev.clientY);
      if (cell) previewPaint(ctx, cell, ev);
    });
    canvas.addEventListener("pointermove", (ev) => {
      if (state.preview.orbiting) {
        const dx = ev.clientX - state.preview.orbitStartX;
        const dy = ev.clientY - state.preview.orbitStartY;
        state.preview.yaw = ((state.preview.orbitStartYaw + dx * 0.45) % 360 + 360) % 360;
        state.preview.angle = Math.max(5, Math.min(70, state.preview.orbitStartPitch - dy * 0.28));
        const yawInput = q('[data-id="yaw"]'); if (yawInput) yawInput.value = String(Math.round(state.preview.yaw));
        const yawText = q('[data-id="yawText"]'); if (yawText) yawText.textContent = `${Math.round(state.preview.yaw)}°`;
        const pitchInput = q('[data-id="angle"]'); if (pitchInput) pitchInput.value = String(Math.round(state.preview.angle));
        const pitchText = q('[data-id="angleText"]'); if (pitchText) pitchText.textContent = `${Math.round(state.preview.angle)}°`;
        schedulePreview(ctx);
        return;
      }
      state.preview.objJustDown = false;
      const cell = hitPreviewCell(canvas, ev.clientX, ev.clientY);
      const next = cell ? { x: cell.x, y: cell.y } : null;
      if (!state.preview.hovered || !next || state.preview.hovered.x !== next.x || state.preview.hovered.y !== next.y) {
        state.preview.hovered = next;
        schedulePreview(ctx);
      }
      if (state.preview.dragging && (ev.buttons & 1) && cell) previewPaint(ctx, cell, ev);
    });
    const endPointer = () => {
      state.preview.objJustDown = false;
      if (state.preview.orbiting) {
        state.preview.orbiting = false;
        canvas.style.cursor = "crosshair";
        const id = ctx.editor.activeMapId(); const geo = id == null ? null : state.maps.get(id); if (geo) persistPreviewPrefs(geo);
      }
      if (state.preview.dragging) {
        state.preview.dragging = false;
        state.preview.visited.clear();
        const id = ctx.editor.activeMapId();
        const geo = id == null ? null : state.maps.get(id);
        if ((state.objTool || state.workspaceMode === "object") && geo && state.objStart && state.objCurrent) {
          commitObjectFromRect(ctx, geo, id,
            state.objStart.x, state.objStart.y, state.objCurrent.x, state.objCurrent.y);
          state.objStart = null;
          state.objCurrent = null;
        }
        if (id != null) void saveMap(ctx, id);
      }
    };
    canvas.addEventListener("pointerup", endPointer);
    canvas.addEventListener("pointercancel", endPointer);
    canvas.addEventListener("pointerleave", () => {
      if (!state.preview.dragging && !state.preview.orbiting) { state.preview.hovered = null; schedulePreview(ctx); }
    });
    canvas.addEventListener("dblclick", (ev) => {
      const cell = hitPreviewCell(canvas, ev.clientX, ev.clientY);
      if (!cell) return;
      state.preview.focusX = cell.x;
      state.preview.focusY = cell.y;
      const id = ctx.editor.activeMapId(); const geo = id == null ? null : state.maps.get(id); if (geo) persistPreviewPrefs(geo);
      schedulePreview(ctx);
    });
    canvas.addEventListener("wheel", (ev) => {
      ev.preventDefault();
      if (ev.shiftKey) {
        const step = ev.deltaY > 0 ? 7.5 : -7.5;
        setYaw(state.preview.yaw + step, false);
        return;
      }
      const dir = ev.deltaY > 0 ? -0.05 : 0.05;
      state.preview.zoom = Math.max(0.35, Math.min(2.2, Math.round((state.preview.zoom + dir) * 20) / 20));
      const z = q('[data-id="pzoom"]'); if (z) z.value = String(state.preview.zoom);
      const t = q('[data-id="zoomText"]'); if (t) t.textContent = state.preview.zoom.toFixed(2);
      schedulePreview(ctx);
    }, { passive: false });
  }  schedulePreview(ctx);
}


// =============================================================================
// V2.5 MODEL WORKSHOP
// =============================================================================

function nextModelId(geo) {
  let n = 1; while (geo?.models?.[`model_${n}`]) n++; return `model_${n}`;
}
function nextModelInstanceId(geo) {
  return Math.max(0, ...(geo?.model_instances || []).map(i=>Number(i.id)||0)) + 1;
}
function modelInstanceCoversCell(geo, inst, x, y) {
  const model = geo?.models?.[inst?.model_id]; if (!model) return false;
  if (Array.isArray(model.parts) && model.parts.length) {
    const built=modelPartMeshFacesForInstance(inst,model,1);
    for(const face of built.faces||[]){
      const verts=Array.isArray(face.vertices)?face.vertices:[];if(!verts.length)continue;
      const hull=convexHull2D(verts.map(v=>[v[0],v[1]]));
      if(hull.length>=3&&polygonIntersectsCell(hull,Number(x),Number(y)))return true;
    }
    return false;
  }
  for (const c of expandedModelCells(inst, model).values()) if (Math.round(c.x)===Math.round(x) && Math.round(c.y)===Math.round(y)) return true;
  return false;
}
function modelInstanceAt(geo,x,y){ return [...(geo?.model_instances||[])].reverse().find(i=>modelInstanceCoversCell(geo,i,x,y))||null; }
function selectedModelInstance(geo){
  const id=Number(state.modelInstanceSelectedId)||0;
  return (geo?.model_instances||[]).find(i=>Number(i.id)===id)||null;
}
function selectModelInstance(ctx,inst){
  state.modelInstanceSelectedId=inst?Number(inst.id)||null:null;
  if(inst?.model_id){state.modelSelectedId=String(inst.model_id);state.modelBrushId=String(inst.model_id);}
  state.modelPlacementMode=false;
  state.modelHoverCell=null;
  state.panelRefresh?.();
  if(state.studioHost)studioUpdateInspector(ctx,state.studioHost);
  studioDrawOverlay(ctx);
}
function placeModelInstance(ctx,mapId,x,y,options={}){
  const geo=state.maps.get(mapId); const id=state.modelBrushId||state.modelSelectedId; const model=geo?.models?.[id];
  if(!geo||!model){ctx.ui.showToast?.({message:"Crea o selecciona un modelo primero.",level:"info"});return null;}
  geo.model_instances ||= [];
  const inst={id:nextModelInstanceId(geo),model_id:model.id,x:Math.round(x),y:Math.round(y),scale_x:Math.max(.05,Number(state.modelScaleX)||1),scale_y:Math.max(.05,Number(state.modelScaleY)||1),height_scale:Math.max(.05,Number(state.modelHeightScale)||1),rotation:normalizeModelPlacementRotation(state.modelRotation)};
  geo.model_instances.push(inst);
  state.modelInstanceSelectedId=inst.id;
  state.modelSelectedId=model.id;
  state.modelBrushId=model.id;
  compileModelObjects(geo);
  ctx.editor.requestRedraw();
  markPreviewDirty(ctx);
  if(!options.deferPreview)void refreshPreviewNow(ctx).then(()=>studioDrawOverlay(ctx));
  if(!options.deferSave)void saveMap(ctx,mapId,{skipCompile:true});
  state.panelRefresh?.();
  return inst;
}
function deleteModelInstance(ctx,mapId,instanceId){
  const geo=state.maps.get(mapId);if(!geo)return false;
  const before=(geo.model_instances||[]).length;
  geo.model_instances=(geo.model_instances||[]).filter(i=>Number(i.id)!==Number(instanceId));
  if(geo.model_instances.length===before)return false;
  if(Number(state.modelInstanceSelectedId)===Number(instanceId))state.modelInstanceSelectedId=null;
  compileModelObjects(geo);ctx.editor.requestRedraw();markPreviewDirty(ctx);
  void saveMap(ctx,mapId,{skipCompile:true});void refreshPreviewNow(ctx).then(()=>studioDrawOverlay(ctx));
  return true;
}
function updateModelInstance(ctx,mapId,instanceId,patch,options={}){
  const geo=state.maps.get(mapId);if(!geo)return null;
  const inst=(geo.model_instances||[]).find(i=>Number(i.id)===Number(instanceId));if(!inst)return null;
  Object.assign(inst,patch||{});
  inst.x=Number(inst.x)||0;inst.y=Number(inst.y)||0;
  inst.scale_x=Math.max(.05,Number(inst.scale_x)||1);inst.scale_y=Math.max(.05,Number(inst.scale_y)||1);
  inst.height_scale=Math.max(.05,Number(inst.height_scale)||1);inst.rotation=normalizeModelPlacementRotation(inst.rotation);
  if(!options.draft)compileModelObjects(geo);
  ctx.editor.requestRedraw();markPreviewDirty(ctx);
  if(!options.deferSave&&!options.draft)void saveMap(ctx,mapId,{skipCompile:true});
  if(!options.deferPreview&&!options.draft)void refreshPreviewNow(ctx).then(()=>studioDrawOverlay(ctx));
  return inst;
}
function eraseModelAt(ctx,mapId,x,y){
  const geo=state.maps.get(mapId); if(!geo)return;
  const hit=modelInstanceAt(geo,x,y); if(!hit)return;
  geo.model_instances=(geo.model_instances||[]).filter(i=>Number(i.id)!==Number(hit.id));
  compileModelObjects(geo);ctx.editor.requestRedraw();schedulePreview(ctx);void saveMap(ctx,mapId,{skipCompile:true});state.panelRefresh?.();
}
function resolvePickedTileset(ctx,picked){
  const list=ctx.tileset.list?.()||[];
  const ids=[picked?.tilesetId,picked?.tileset_id,picked?.resourceId,picked?.resource_id].map(Number).filter(Number.isFinite);
  for(const id of ids){const hit=list.find(t=>Number(t.id)===id);if(hit)return hit;}
  const candidates=[picked?.name,picked?.fileName,picked?.filename,picked?.path,picked?.graphic].filter(Boolean).map(v=>String(v).replaceAll('\\','/').split('/').pop().replace(/\.[^.]+$/,'').toLowerCase());
  return list.find(t=>{const names=[t.tilesetName,t.name,t.fileName,t.filename,t.path].filter(Boolean).map(v=>String(v).replaceAll('\\','/').split('/').pop().replace(/\.[^.]+$/,'').toLowerCase());return names.some(n=>candidates.includes(n));})||null;
}
async function pickModelFaceMaterial(ctx){
  const picked=await openGeometryGraphicPicker(ctx,{title:"Geometry Model · textura de cara"});
  if(!picked?.srcRect?.w)return null;
  const match=picked.tileset||tilesetInfo(ctx,picked.tilesetId)||{id:picked.tilesetId};
  await ensureTilesetResourceSet(ctx,picked.tilesetId);
  return {kind:"tileset",tileset_id:Number(picked.tilesetId),graphic:String(match.tilesetName||match.name||""),src_rect:{x:Number(picked.srcRect.x)||0,y:Number(picked.srcRect.y)||0,w:Math.max(32,Number(picked.srcRect.w)||32),h:Math.max(32,Number(picked.srcRect.h)||32)},rotation:0,flip_h:false,flip_v:false,opacity:255,hue:0,saturation:100,lighting:0};
}

function resizeModel(model,newW,newH){
  newW=Math.max(1,Math.min(32,Math.round(newW)));newH=Math.max(1,Math.min(32,Math.round(newH)));
  const next={}; for(const [key,val] of Object.entries(model.cells||{})){const [x,y]=key.split(',').map(Number);if(x<newW&&y<newH)next[key]=val;}
  model.width=newW;model.height=newH;model.cells=next;
}
function createModel(ctx){
  const geo=currentGeo(ctx);if(!geo)return null;geo.models||={};const id=nextModelId(geo);
  geo.models[id]=normalizeModelTemplate({id,name:`Modelo ${Object.keys(geo.models).length+1}`,category:"mountain",width:1,height:1,default_height:1,collision:"solid",connect_neighbors:true,builder_version:3,allow_empty:true,parts:[],cells:{}},id);
  state.modelSelectedId=id;state.modelBrushId=id;compileModelObjects(geo);void saveMap(ctx,geo.map_id,{skipCompile:true});state.panelRefresh?.();return geo.models[id];
}

async function createModelFromMapSelection(ctx) {
  const geo=currentGeo(ctx);const mapId=ctx.editor.activeMapId?.();if(!geo||mapId==null)return null;
  let selected=null;try{selected=ctx.map.selectionTiles?.(mapId)||null;}catch(_){ }
  if(!selected?.length){ctx.ui.showToast?.({message:"Selecciona primero uno o varios tiles en el mapa con Select de Maker Studio.",level:"info"});return null;}
  const rows=[...selected].sort((a,b)=>(Number(a.layerIndex)||0)-(Number(b.layerIndex)||0));
  const minX=Math.min(...rows.map(r=>r.x)),maxX=Math.max(...rows.map(r=>r.x)),minY=Math.min(...rows.map(r=>r.y)),maxY=Math.max(...rows.map(r=>r.y));
  const id=nextModelId(geo),parts=[];const layers=authoritativeLayers(ctx,mapId,true);
  let n=1;
  for(const r of rows){
    const layer=layers.find(l=>Number(layerRef(l))===Number(r.layerIndex))||{index:r.layerIndex,id:r.layerIndex,kind:Number(r.layerIndex)>=3?'extended':'native'};
    const data=readTileVisualData(ctx,mapId,layer,r.x,r.y);const desc=data?sourceDescriptor(ctx,mapId,layer,r.x,r.y,data):null;const mat=desc?materialFromSourceDescriptor(desc):null;
    parts.push(normalizeModelPart({id:`box_${n}`,name:`Tile ${n++}`,type:"box",position:{x:r.x-minX+.5,y:r.y-minY+.5,z:0},size:{x:1,y:1,z:1},material:mat,face_materials:{top:mat,north:null,south:null,east:null,west:null}},parts.length));
    if(desc?.tileset_id)await ensureTilesetResourceSet(ctx,desc.tileset_id);
  }
  geo.models||={};geo.models[id]=normalizeModelTemplate({id,name:`Modelo selección ${Object.keys(geo.models).length+1}`,category:"mountain",width:maxX-minX+1,height:maxY-minY+1,default_height:1,collision:"solid",connect_neighbors:true,builder_version:3,allow_empty:true,parts,cells:{}},id);
  state.modelSelectedId=id;state.modelBrushId=id;compileModelObjects(geo);await saveMap(ctx,mapId,{skipCompile:true});state.panelRefresh?.();ctx.editor.requestRedraw();schedulePreview(ctx);ctx.ui.showToast?.({message:`Modelo creado desde ${rows.length} tiles como partes editables.`,level:"success"});return geo.models[id];
}

function deleteModel(ctx,id){
  const geo=currentGeo(ctx);if(!geo?.models?.[id])return;delete geo.models[id];geo.model_instances=(geo.model_instances||[]).filter(i=>i.model_id!==id);if(state.modelSelectedId===id)state.modelSelectedId=null;if(state.modelBrushId===id)state.modelBrushId=null;compileModelObjects(geo);void saveMap(ctx,geo.map_id,{skipCompile:true});ctx.editor.requestRedraw();schedulePreview(ctx);state.panelRefresh?.();
}
function drawModelPreview(ctx,canvas,model,previewRotation=0){
  if(!canvas||!model)return;
  const c=canvas.getContext('2d'),W=canvas.width,H=canvas.height;c.clearRect(0,0,W,H);c.fillStyle='#151922';c.fillRect(0,0,W,H);c.imageSmoothingEnabled=false;
  const built=modelMeshFacesForInstance({id:0,model_id:model.id,x:0,y:0,scale_x:1,scale_y:1,height_scale:1,rotation:normalizeModelPlacementRotation(previewRotation)},model,1);
  const allVerts=built.faces.flatMap(f=>Array.isArray(f.vertices)?f.vertices:[[f.x0,f.y0,f.z0],[f.x1,f.y0,f.z1],[f.x1,f.y1,f.z1],[f.x0,f.y1,f.z0]]);
  const bx=allVerts.length?{x0:Math.min(...allVerts.map(v=>v[0])),x1:Math.max(...allVerts.map(v=>v[0])),y0:Math.min(...allVerts.map(v=>v[1])),y1:Math.max(...allVerts.map(v=>v[1])),z0:Math.min(...allVerts.map(v=>v[2])),z1:Math.max(...allVerts.map(v=>v[2]))}:{x0:0,x1:1,y0:0,y1:1,z0:0,z1:1};
  const cx=(bx.x0+bx.x1)/2,cy=(bx.y0+bx.y1)/2,cz=(bx.z0+bx.z1)/2,span=Math.max(1,bx.x1-bx.x0,bx.y1-bx.y0,bx.z1-bx.z0);const scale=Math.min(W,H)*.62/span;
  const yaw=Math.PI/4,pitch=Math.PI/5;
  const proj=v=>{let x=v[0]-cx,y=v[1]-cy,z=v[2]-cz;const ca=Math.cos(yaw),sa=Math.sin(yaw);let rx=x*ca-y*sa,ry=x*sa+y*ca;const cp=Math.cos(pitch),sp=Math.sin(pitch);let sy=ry*cp-z*sp,depth=ry*sp+z*cp;return{x:W/2+rx*scale,y:H*.52+sy*scale,depth};};
  const faces=built.faces.map(f=>{let verts;if(Array.isArray(f.vertices))verts=f.vertices;else if(f.kind==='top')verts=[[f.x0,f.y0,f.z1],[f.x1,f.y0,f.z1],[f.x1,f.y1,f.z1],[f.x0,f.y1,f.z1]];else verts=[[f.x0,f.y0,f.z1],[f.x1,f.y1,f.z1],[f.x1,f.y1,f.z0],[f.x0,f.y0,f.z0]];const pts=verts.map(proj);return{f,pts,depth:pts.reduce((a,p)=>a+p.depth,0)/pts.length};}).sort((a,b)=>a.depth-b.depth);
  for(const it of faces){const pts=it.pts;c.save();c.beginPath();c.moveTo(pts[0].x,pts[0].y);for(let i=1;i<pts.length;i++)c.lineTo(pts[i].x,pts[i].y);c.closePath();const src=meshFaceMaterialSource(ctx,it.f);if(src?.img){c.save();c.clip();const xs=pts.map(p=>p.x),ys=pts.map(p=>p.y),x0=Math.min(...xs),y0=Math.min(...ys),x1=Math.max(...xs),y1=Math.max(...ys);const uv=it.f.material_repeat===false&&Array.isArray(it.f.uv_rect)?it.f.uv_rect:[0,0,1,1],sx=src.sx+src.sw*uv[0],sy=src.sy+src.sh*uv[1],sw=Math.max(1,src.sw*(uv[2]-uv[0])),sh=Math.max(1,src.sh*(uv[3]-uv[1]));c.drawImage(src.img,sx,sy,sw,sh,x0,y0,Math.max(1,x1-x0),Math.max(1,y1-y0));c.restore();}else{c.fillStyle=(it.f.surface==='top'||it.f.kind==='top')?'#6c7d55':'#6b5040';c.fill();}c.strokeStyle='rgba(255,255,255,.18)';c.stroke();c.restore();}
  c.fillStyle='rgba(8,12,18,.82)';c.fillRect(10,H-34,Math.min(W-20,360),24);c.fillStyle='#dffcff';c.font='12px sans-serif';c.fillText(`${model.parts?.length||0} partes · ${built.faces.length} caras · ${built.cells.size} celdas de colisión`,18,H-18);
}

function scheduleModelSave(ctx, mapId, delay = 700) {
  clearTimeout(state.modelSaveTimer);
  state.modelSaveTimer = setTimeout(() => {
    state.modelSaveTimer = 0;
    void saveMap(ctx, mapId, { authoringOnly: true, skipCompile: true, skipModelCompile: true });
  }, delay);
}

function scheduleModelTemplateRefresh(ctx, geo, modelId) {
  state.modelCompilePending = { ctx, geo, modelId };
  if (state.modelCompileRaf) return;
  state.modelCompileRaf = requestAnimationFrame(() => {
    state.modelCompileRaf = 0;
    const job = state.modelCompilePending;
    state.modelCompilePending = null;
    if (!job?.geo || !job?.modelId) return;
    compileModelTemplateInstances(job.geo, job.modelId);
    job.ctx.editor.requestRedraw();
    schedulePreview(job.ctx);
  });
}


async function geometryReadAbsoluteText(path){
  const invoke=window.__TAURI__?.core?.invoke;if(!invoke)throw new Error('Tauri invoke unavailable');
  return await invoke('read_text_file',{path});
}
async function geometryPickExternalFile(ctx,title,extensions){
  const picked=await ctx.ui.showFilePicker?.({multiple:false,directory:false,filters:[{name:title,extensions}]});
  return Array.isArray(picked)?(picked[0]||null):picked;
}
function pathBaseName(path){return String(path||'').replace(/\\/g,'/').split('/').pop()||'';}
function bbTextureDescriptor(raw, fallbackW=16, fallbackH=16){
  const name=pathBaseName(raw?.relative_path||raw?.path||raw?.name||raw?.id||'texture.png');
  return {name,width:Math.max(1,Number(raw?.width)||fallbackW),height:Math.max(1,Number(raw?.height)||fallbackH),id:String(raw?.id??'')};
}
function bbElementRotation(e){
  if(Array.isArray(e?.rotation))return {x:Number(e.rotation[0])||0,y:Number(e.rotation[1])||0,z:Number(e.rotation[2])||0};
  if(e?.rotation&&typeof e.rotation==='object'&&Number(e.rotation.angle)){
    const a=Number(e.rotation.angle)||0,axis=String(e.rotation.axis||'y').toLowerCase();
    return {x:axis==='x'?a:0,y:axis==='y'?a:0,z:axis==='z'?a:0};
  }
  return {x:0,y:0,z:0};
}
function bbRotatePoint(v,e){
  const p=[Number(v?.[0])||0,Number(v?.[1])||0,Number(v?.[2])||0],o=Array.isArray(e?.origin)?e.origin.map(Number):[0,0,0],r=bbElementRotation(e);
  let x=p[0]-(o[0]||0),y=p[1]-(o[1]||0),z=p[2]-(o[2]||0),c,s,t;
  if(r.x){c=Math.cos(r.x*Math.PI/180);s=Math.sin(r.x*Math.PI/180);t=y*c-z*s;z=y*s+z*c;y=t;}
  if(r.y){c=Math.cos(r.y*Math.PI/180);s=Math.sin(r.y*Math.PI/180);t=x*c+z*s;z=-x*s+z*c;x=t;}
  if(r.z){c=Math.cos(r.z*Math.PI/180);s=Math.sin(r.z*Math.PI/180);t=x*c-y*s;y=x*s+y*c;x=t;}
  return [x+(o[0]||0),y+(o[1]||0),z+(o[2]||0)];
}
function bbFaceTextureInfo(face,tex,texById,vertexIds=null){
  if(!face)return {material:null,uv_rect:null,uv_points:null};
  const ref=String(face.texture??'0').replace(/^#/,'');const t=texById.get(ref)||tex[Number(ref)||0]||tex[0];if(!t)return {material:null,uv_rect:null,uv_points:null};
  const material={kind:'image',graphic:t.name,src_rect:{x:0,y:0,w:t.width,h:t.height},rotation:0,flip_h:false,flip_v:false,opacity:255,hue:0,saturation:100,lighting:0};
  let uvPoints=null;
  if(vertexIds&&face.uv&&typeof face.uv==='object'&&!Array.isArray(face.uv)){
    uvPoints=vertexIds.map(id=>{const q=face.uv[id];return Array.isArray(q)?[(Number(q[0])||0)/t.width,(Number(q[1])||0)/t.height]:[0,0];});
  }
  let uvRect=null;
  if(uvPoints?.length){const us=uvPoints.map(q=>q[0]),vs=uvPoints.map(q=>q[1]);uvRect=[Math.min(...us),Math.min(...vs),Math.max(...us),Math.max(...vs)];}
  else if(Array.isArray(face.uv)&&face.uv.length===4){const uv=face.uv.map(Number);uvRect=[Math.min(uv[0],uv[2])/t.width,Math.min(uv[1],uv[3])/t.height,Math.max(uv[0],uv[2])/t.width,Math.max(uv[1],uv[3])/t.height];}
  else uvRect=[0,0,1,1];
  return {material,uv_rect:uvRect,uv_points:uvPoints};
}
function bbFaceSurface(norms){
  if(!Array.isArray(norms)||norms.length<3)return 'side';
  const a=norms[0],b=norms[1],c=norms[2],u=[b[0]-a[0],b[1]-a[1],b[2]-a[2]],v=[c[0]-a[0],c[1]-a[1],c[2]-a[2]],n=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]];
  return Math.abs(n[2])>=Math.max(Math.abs(n[0]),Math.abs(n[1]))?'top':'side';
}
function blockbenchModelFromJson(raw,path,modelId){
  if(!raw||typeof raw!=='object')throw new Error('Invalid Blockbench model');
  const sourceElements=(raw.elements||[]).filter(Boolean),cuboids=sourceElements.filter(e=>Array.isArray(e.from)&&Array.isArray(e.to)),meshes=sourceElements.filter(e=>String(e.type||'').toLowerCase()==='mesh'&&e.vertices&&e.faces);
  if(!cuboids.length&&!meshes.length)throw new Error('No supported cuboid or mesh elements found in .bbmodel');
  const rw=Math.max(1,Number(raw?.resolution?.width||raw?.texture_width)||16),rh=Math.max(1,Number(raw?.resolution?.height||raw?.texture_height)||16);
  const tex=(raw.textures||[]).map(t=>bbTextureDescriptor(t,rw,rh));const texById=new Map();tex.forEach((t,i)=>{texById.set(String(i),t);if(t.id)texById.set(t.id,t);});
  const points=[];for(const e of cuboids){points.push(e.from.map(Number),e.to.map(Number));}for(const e of meshes)for(const v of Object.values(e.vertices||{}))points.push(bbRotatePoint(v,e));
  const minX=Math.min(...points.map(v=>Number(v[0])||0)),minY=Math.min(...points.map(v=>Number(v[1])||0)),minZ=Math.min(...points.map(v=>Number(v[2])||0));
  const parts=[];let importedFaces=0;
  cuboids.forEach((e,i)=>{
    const f=e.from.map(Number),t=e.to.map(Number),sx=Math.max(.01,Math.abs(t[0]-f[0])/16),sy=Math.max(.01,Math.abs(t[2]-f[2])/16),sz=Math.max(.01,Math.abs(t[1]-f[1])/16);
    const pos={x:((f[0]+t[0])/2-minX)/16,y:((f[2]+t[2])/2-minZ)/16,z:(Math.min(f[1],t[1])-minY)/16};
    const rr=bbElementRotation(e),part=normalizeModelPart({id:`bb_cube_${i+1}`,name:String(e.name||`Cube ${i+1}`),type:'box',position:pos,size:{x:sx,y:sy,z:sz},angle:{x:rr.x,y:rr.z,z:rr.y},subdivisions:1,texture_mode:'stretch',repeat:false,collision:true},parts.length);
    const edgeToBb={top:'up',north:'north',south:'south',west:'west',east:'east'};const cfaces=customFacesFromCurrentPart(part);
    for(const cf of cfaces){const info=bbFaceTextureInfo(e.faces?.[edgeToBb[cf.edge]],tex,texById);if(info.material){cf.material=info.material;cf.uv_rect=info.uv_rect;cf.material_repeat=false;}}
    part.custom_faces=cfaces;part.material=cfaces.find(x=>x.material)?.material||null;parts.push(part);importedFaces+=cfaces.length;
  });
  meshes.forEach((e,mi)=>{
    const verts={};for(const [id,v] of Object.entries(e.vertices||{}))verts[id]=bbRotatePoint(v,e);
    const vv=Object.values(verts);if(!vv.length)return;const x0=Math.min(...vv.map(v=>v[0])),x1=Math.max(...vv.map(v=>v[0])),y0=Math.min(...vv.map(v=>v[1])),y1=Math.max(...vv.map(v=>v[1])),z0=Math.min(...vv.map(v=>v[2])),z1=Math.max(...vv.map(v=>v[2]));
    const sx=Math.max(.01,(x1-x0)/16),sy=Math.max(.01,(z1-z0)/16),sz=Math.max(.01,(y1-y0)/16),pos={x:((x0+x1)/2-minX)/16,y:((z0+z1)/2-minZ)/16,z:(y0-minY)/16};
    const nx=v=>(x1-x0)>1e-8?(v-x0)/(x1-x0):.5,ny=v=>(z1-z0)>1e-8?(v-z0)/(z1-z0):.5,nz=v=>(y1-y0)>1e-8?(v-y0)/(y1-y0):.5;
    const faces=[];let fi=0;for(const [fid,face] of Object.entries(e.faces||{})){
      const ids=(face?.vertices||[]).filter(id=>verts[id]);if(ids.length<3)continue;
      const polys=[];if(ids.length<=4)polys.push(ids.slice());else for(let k=1;k<ids.length-1;k++)polys.push([ids[0],ids[k],ids[k+1]]);
      for(const poly0 of polys){const poly=poly0.length===3?[poly0[0],poly0[1],poly0[2],poly0[2]]:poly0.slice(0,4),norms=poly.map(id=>{const v=verts[id];return[nx(v[0]),ny(v[2]),nz(v[1])];}),info=bbFaceTextureInfo(face,tex,texById,poly0);let uvp=info.uv_points;if(uvp?.length===3)uvp=[uvp[0],uvp[1],uvp[2],uvp[2]];
        faces.push({id:`bb_mesh_${mi+1}_${fid}_${fi++}`,edge:'custom',surface:bbFaceSurface(norms),norms,uv_rect:info.uv_rect||[0,0,1,1],uv_points:uvp||null,material_repeat:false,material:info.material});importedFaces++;
      }
    }
    const part=normalizeModelPart({id:`bb_mesh_${mi+1}`,name:String(e.name||`Mesh ${mi+1}`),type:'box',position:pos,size:{x:sx,y:sy,z:sz},angle:{x:0,y:0,z:0},subdivisions:1,texture_mode:'stretch',repeat:false,collision:true,custom_faces:faces},parts.length);
    part.custom_faces=normalizeCustomModelFaces(faces)||faces;part.material=faces.find(x=>x.material)?.material||null;parts.push(part);
  });
  if(!parts.length)throw new Error('Blockbench file contains no importable geometry');
  const maxX=Math.max(...parts.map(p=>p.position.x+p.size.x/2)),maxY=Math.max(...parts.map(p=>p.position.y+p.size.y/2));
  return normalizeModelTemplate({id:modelId,name:String(raw.name||pathBaseName(path).replace(/\.bbmodel$/i,'')||'Blockbench Model'),category:'prop',width:Math.max(1,Math.ceil(maxX)),height:Math.max(1,Math.ceil(maxY)),collision:'solid',builder_version:4,runtime_quality:'pixel-low',parts,cells:{},allow_empty:true,external_link:{type:'blockbench',path:String(path),textures:tex.map(t=>t.name),cuboids:cuboids.length,meshes:meshes.length,faces:importedFaces,imported_at:new Date().toISOString()}},modelId);
}
async function extractEmbeddedBlockbenchTextures(ctx,raw){
  const root=String(ctx.editor.gameRoot?.()||'').replace(/[\\/]+$/,'');const invoke=window.__TAURI__?.core?.invoke;if(!root||!invoke)return 0;
  try{await ctx.fs.projectMkdir('Graphics/Models');}catch(_){}
  let written=0;for(const t of raw?.textures||[]){const src=String(t?.source||''),m=src.match(/^data:image\/(?:png|x-png);base64,(.+)$/i);if(!m)continue;const name=pathBaseName(t?.relative_path||t?.name||`bb_texture_${written+1}.png`);try{const bin=atob(m[1]),bytes=new Uint8Array(bin.length);for(let i=0;i<bin.length;i++)bytes[i]=bin.charCodeAt(i);await invoke('write_binary_file',{path:`${root}/Graphics/Models/${name}`,data:Array.from(bytes)});written++;}catch(_){}
  }return written;
}
async function importBlockbenchModel(ctx, replaceModelId=null){
  const path=await geometryPickExternalFile(ctx,'Blockbench model',['bbmodel']);if(!path)return null;
  try{const raw=JSON.parse(await geometryReadAbsoluteText(path));const geo=currentGeo(ctx);if(!geo)return null;const id=replaceModelId||nextModelId(geo);const model=blockbenchModelFromJson(raw,path,id);geo.models[id]=model;state.modelSelectedId=id;state.modelBrushId=id;compileModelObjects(geo);const embedded=await extractEmbeddedBlockbenchTextures(ctx,raw);await ensureExternalModelTextures(ctx,geo,true);await saveMap(ctx,geo.map_id,{skipCompile:true});const l=model.external_link||{};ctx.ui.showToast?.({message:`${model.name}: ${l.cuboids||0} cuboid(s), ${l.meshes||0} mesh(es), ${l.faces||0} faces${embedded?` · ${embedded} embedded texture(s) copied`:''}.`,level:'info'});return model;}catch(err){ctx.log.error(err);ctx.ui.showToast?.({message:`Blockbench: ${err.message||'no se pudo importar'}`,level:'error'});return null;}
}
async function reloadLinkedBlockbenchModel(ctx,modelId){
  const geo=currentGeo(ctx),old=geo?.models?.[modelId],path=old?.external_link?.path;if(!geo||!old||!path){ctx.ui.showToast?.({message:'Este modelo no tiene un .bbmodel vinculado.',level:'info'});return null;}
  try{const raw=JSON.parse(await geometryReadAbsoluteText(path));const model=blockbenchModelFromJson(raw,path,modelId);model.name=old.name||model.name;model.runtime_quality=old.runtime_quality||'pixel-low';geo.models[modelId]=model;compileModelObjects(geo);state.preview.modelImages.clear();await extractEmbeddedBlockbenchTextures(ctx,raw);await ensureExternalModelTextures(ctx,geo,true);await saveMap(ctx,geo.map_id,{skipCompile:true});const l=model.external_link||{};ctx.ui.showToast?.({message:`Blockbench recargado: ${l.cuboids||0} cuboid(s), ${l.meshes||0} mesh(es), ${l.faces||0} faces.`,level:'info'});return model;}catch(err){ctx.log.error(err);ctx.ui.showToast?.({message:`Reload link: ${err.message}`,level:'error'});return null;}
}

function openModelWorkshop(ctx){
  const geo=currentGeo(ctx);if(!geo)return;if(!Object.keys(geo.models||{}).length)createModel(ctx);
  const tsList=()=>{try{return(ctx.tileset.list?.()||[]).filter(t=>Number(t?.id));}catch(_){return[];}};
  const initialTs=()=>Number(ctx.tileset.currentId?.()||ctx.tileset.mapTilesetId?.(ctx.editor.activeMapId?.())||tsList()[0]?.id||1);
  const dialog=ctx.ui.showCustomDialog({title:"2.5D Geometry · Model Studio",width:"99vw",height:"97vh",render(body){
    body.style.padding='0';body.style.overflow='hidden';
    let selectedPartId=null,atlasTilesetId=initialTs(),atlasImage=null,atlasSelection=null,atlasDrag=null,atlasZoom=1,renderToken=0,previewRaf=0;
    const cam={yaw:45,pitch:28,zoom:1,mode:'iso'};let previewDrag=null,previewHits=[],previewProjection=null,previewVertices=[],vertexDrag=null;
    let editMode='object',vertexAxis='view',softRadius=0,componentTool='move',selectedVertexKeys=new Set(),selectedFaceIndices=new Set(),selectedEdgeKeys=new Set();
    let inspectorTab='transform',uvOpen=false,uvTab='layout',uvImage=null,uvImageKey='',uvDrag=null,uvHoverFace=-1;
    let cutSnap=.01,cutMode='cross',transformSnap=.025,cutHover=null,extrudeArmed=false,extrudeDrag=null,displayMode='shaded';
    cam.panX=0;cam.panY=0;
    let cameraDrag=null,modelGizmo=null,meshCache={modelId:null,faces:null,dirty:true};
    const history={modelId:null,last:null,undo:[],redo:[],suspend:false,label:'Edit'};
    const getGeo=()=>currentGeo(ctx),getModels=()=>getGeo()?.models||{},getModel=()=>{const ms=getModels();if(!state.modelSelectedId||!ms[state.modelSelectedId])state.modelSelectedId=Object.keys(ms)[0]||null;return ms[state.modelSelectedId]||null;};
    const getPart=()=>{const m=getModel();if(!m)return null;if(!selectedPartId||!(m.parts||[]).some(p=>p.id===selectedPartId))selectedPartId=m.parts?.[0]?.id||null;return(m.parts||[]).find(p=>p.id===selectedPartId)||null;};
    const materialFromAtlas=()=>atlasSelection?{kind:'tileset',tileset_id:Number(atlasTilesetId),graphic:String(tilesetGraphicName(tilesetInfo(ctx,atlasTilesetId))||tilesetInfo(ctx,atlasTilesetId)?.name||''),src_rect:{x:atlasSelection.x,y:atlasSelection.y,w:Math.max(TILE_SIZE,atlasSelection.w),h:Math.max(TILE_SIZE,atlasSelection.h)},rotation:0,flip_h:false,flip_v:false,opacity:255,hue:0,saturation:100,lighting:0}:null;
    const atlasFootprint=()=>({w:Math.max(1,Math.round((Number(atlasSelection?.w)||TILE_SIZE)/TILE_SIZE)),h:Math.max(1,Math.round((Number(atlasSelection?.h)||TILE_SIZE)/TILE_SIZE))});
    const basePartSizeFromAtlas=(type)=>{const fp=atlasFootprint(),w=fp.w,h=fp.h;switch(type){case 'billboard':return{x:w,y:.05,z:h};case 'relief':return{x:w,y:.15,z:h};case 'sphere':case 'cylinder':case 'dome':return{x:w,y:Math.max(1,w),z:h};case 'prism':case 'wedge':case 'box':default:return{x:w,y:1,z:h};}};
    const fitPartToAtlas=(part)=>{if(!part||!atlasSelection)return false;const next=basePartSizeFromAtlas(part.type);part.size={...part.size,...next};return true;};
    const normalizeRect=(a,b)=>{const x0=Math.min(a.x,b.x),y0=Math.min(a.y,b.y),x1=Math.max(a.x,b.x),y1=Math.max(a.y,b.y);return{x:x0*TILE_SIZE,y:y0*TILE_SIZE,w:(x1-x0+1)*TILE_SIZE,h:(y1-y0+1)*TILE_SIZE};};
    const snapshotModel=()=>{const m=getModel();return m?deepClone(m):null;};
    const snapshotSig=v=>{try{return JSON.stringify(v);}catch(_){return String(Date.now());}};
    const syncHistory=()=>{const m=getModel();if(!m)return;if(history.modelId!==m.id){history.modelId=m.id;history.last=snapshotModel();history.undo=[];history.redo=[];}else if(!history.last)history.last=snapshotModel();};
    const commitHistory=(label='Edit')=>{if(history.suspend)return;syncHistory();const now=snapshotModel();if(!now||!history.last)return;const a=snapshotSig(history.last),b=snapshotSig(now);if(a===b)return;history.undo.push({model:history.last,label});if(history.undo.length>80)history.undo.shift();history.redo=[];history.last=now;};
    const restoreHistory=(entry)=>{const g=getGeo(),m=getModel();if(!g||!m||!entry?.model)return;history.suspend=true;g.models[m.id]=normalizeModelTemplate(deepClone(entry.model),m.id);selectedPartId=g.models[m.id].parts?.some(p=>p.id===selectedPartId)?selectedPartId:(g.models[m.id].parts?.[0]?.id||null);selectedVertexKeys.clear();selectedFaceIndices.clear();selectedEdgeKeys.clear();meshCache.dirty=true;history.last=snapshotModel();history.suspend=false;const mapId=ctx.editor.activeMapId?.();if(mapId!=null){scheduleModelTemplateRefresh(ctx,g,m.id);scheduleModelSave(ctx,mapId,120);}ctx.editor.requestRedraw();schedulePreview(ctx);state.panelRefresh?.();render();};
    const undoModel=()=>{syncHistory();if(!history.undo.length)return;const current=snapshotModel(),entry=history.undo.pop();history.redo.push({model:current,label:entry.label});restoreHistory(entry);};
    const redoModel=()=>{syncHistory();if(!history.redo.length)return;const current=snapshotModel(),entry=history.redo.pop();history.undo.push({model:current,label:entry.label});restoreHistory(entry);};
    const invalidateModelMesh=()=>{meshCache.dirty=true;cutHover=null;};
    const persist=(rerender=false,live=false,label='Edit')=>{const g=getGeo(),m=getModel(),mapId=ctx.editor.activeMapId?.();if(!g||!m||mapId==null)return;const b=modelPartBounds(m);m.width=Math.max(1,Math.ceil(b.x1-b.x0));m.height=Math.max(1,Math.ceil(b.y1-b.y0));invalidateModelMesh();scheduleModelSave(ctx,mapId,live?500:180);if(live){queuePreview();return;}commitHistory(label);scheduleModelTemplateRefresh(ctx,g,m.id);ctx.editor.requestRedraw();schedulePreview(ctx);state.panelRefresh?.();queuePreview();if(rerender)render();};
    const addPart=(type)=>{const m=getModel();if(!m)return;m.parts||=[];const id=nextModelPartId(m,type),b=modelPartBounds(m),mat=materialFromAtlas(),defaults=basePartSizeFromAtlas(type);const empty=m.parts.length===0,cx=empty?defaults.x/2:Math.max(defaults.x/2,(b.x0+b.x1)/2||defaults.x/2),cy=empty?defaults.y/2:Math.max(defaults.y/2,(b.y0+b.y1)/2||defaults.y/2);const p=normalizeModelPart({id,name:`${type.toUpperCase()} ${m.parts.length+1}`,type,position:{x:cx,y:cy,z:0},size:defaults,material:mat,face_materials:mat?{top:mat,north:mat,south:mat,east:mat,west:mat}:null},m.parts.length);m.parts.push(p);selectedPartId=id;persist(true);};
    const duplicatePart=()=>{const m=getModel(),p=getPart();if(!m||!p)return;const cp=deepClone(p);cp.id=nextModelPartId(m,p.type);cp.name=`${p.name} copy`;cp.position.x+=.25;cp.position.y+=.25;m.parts.push(normalizeModelPart(cp,m.parts.length));selectedPartId=cp.id;persist(true);};
    const deletePart=()=>{const m=getModel(),p=getPart();if(!m||!p)return;m.parts=m.parts.filter(x=>x.id!==p.id);selectedPartId=m.parts[0]?.id||null;persist(true);};
    const applyMaterial=(edge='all')=>{const p=getPart(),mat=materialFromAtlas();if(!p||!mat){ctx.ui.showToast?.({message:'Selecciona primero una textura en el tileset.',level:'info'});return;}const hadMaterial=!!p.material||Object.values(p.face_materials||{}).some(Boolean);if(edge==='all'){p.material=deepClone(mat);p.face_materials=normalizeFaceMaterialMap({top:mat,north:mat,south:mat,east:mat,west:mat});if(!hadMaterial)fitPartToAtlas(p);}else{p.face_materials||=normalizeFaceMaterialMap(null);p.face_materials[edge]=deepClone(mat);}persist();drawMaterialButtons();};
    const clearMaterial=(edge)=>{const p=getPart();if(!p)return;if(edge==='all'){p.material=null;p.face_materials=normalizeFaceMaterialMap(null);}else{p.face_materials||=normalizeFaceMaterialMap(null);p.face_materials[edge]=null;}persist();drawMaterialButtons();};

    const atlasPos=(canvas,ev)=>{const r=canvas.getBoundingClientRect();if(!atlasImage||!r.width||!r.height)return null;const px=(ev.clientX-r.left)*(canvas.width/r.width),py=(ev.clientY-r.top)*(canvas.height/r.height);return{x:Math.max(0,Math.min(Math.floor((atlasImage.width-1)/TILE_SIZE),Math.floor(px/TILE_SIZE))),y:Math.max(0,Math.min(Math.floor((atlasImage.height-1)/TILE_SIZE),Math.floor(py/TILE_SIZE)))};};
    const drawAtlas=()=>{const cv=body.querySelector('[data-ms-atlas]');if(!cv)return;const c=cv.getContext('2d');c.imageSmoothingEnabled=false;if(!atlasImage){cv.width=512;cv.height=512;cv.style.width='512px';cv.style.height='512px';c.fillStyle='#0f131a';c.fillRect(0,0,512,512);c.fillStyle='#b7c0cc';c.fillText('Loading tileset…',18,28);return;}cv.width=atlasImage.width;cv.height=atlasImage.height;cv.style.width=`${Math.round(atlasImage.width*atlasZoom)}px`;cv.style.height=`${Math.round(atlasImage.height*atlasZoom)}px`;c.clearRect(0,0,cv.width,cv.height);c.drawImage(atlasImage,0,0);c.strokeStyle='rgba(255,255,255,.10)';for(let x=0;x<=cv.width;x+=TILE_SIZE){c.beginPath();c.moveTo(x+.5,0);c.lineTo(x+.5,cv.height);c.stroke();}for(let y=0;y<=cv.height;y+=TILE_SIZE){c.beginPath();c.moveTo(0,y+.5);c.lineTo(cv.width,y+.5);c.stroke();}if(atlasSelection){c.fillStyle='rgba(255,85,24,.20)';c.fillRect(atlasSelection.x,atlasSelection.y,atlasSelection.w,atlasSelection.h);c.strokeStyle='#ff4b18';c.lineWidth=2/atlasZoom;c.strokeRect(atlasSelection.x+.5,atlasSelection.y+.5,atlasSelection.w-1,atlasSelection.h-1);}const info=body.querySelector('[data-ms-atlas-info]');if(info)info.textContent=atlasSelection?`${atlasSelection.w/TILE_SIZE}×${atlasSelection.h/TILE_SIZE} · ${atlasSelection.x}, ${atlasSelection.y}`:'Drag over the tileset to pick a texture';};
    const loadAtlas=async(id)=>{atlasTilesetId=Number(id)||initialTs();atlasImage=null;atlasSelection=null;drawAtlas();const token=++renderToken;const res=await ensureTilesetResourceSet(ctx,atlasTilesetId);if(token!==renderToken)return;atlasImage=res?.image||state.preview.tilesetImages.get(atlasTilesetId)||null;drawAtlas();};

    const partFacesLocal=()=>{const m=getModel();if(!m)return[];if(!meshCache.dirty&&meshCache.modelId===m.id&&Array.isArray(meshCache.faces))return meshCache.faces;const inst={id:0,model_id:m.id,x:0,y:0,scale_x:1,scale_y:1,height_scale:1,rotation:0};meshCache={modelId:m.id,faces:modelPartMeshFacesForInstance(inst,m,1).faces,dirty:false};return meshCache.faces;};
    const allPartVertexKeys=(part)=>{const out=new Map();for(const f of partLocalQuads(part)){const keys=f.vertex_keys||[],norms=f.vertex_norms||[];for(let i=0;i<keys.length;i++)if(keys[i]&&!out.has(keys[i]))out.set(keys[i],Array.isArray(norms[i])?norms[i]:keys[i].split(',').map(Number));}return out;};
    const screenDeltaToWorld=(dx,dy,axis)=>{const pr=previewProjection;if(!pr||!pr.scale)return{x:0,y:0,z:0};const ca=Math.cos(pr.yaw),sa=Math.sin(pr.yaw),cp=Math.cos(pr.pitch),sp=Math.sin(pr.pitch),scale=pr.scale;const axisAmount=(bx,by)=>{const den=bx*bx+by*by;return den<1e-5?0:(dx*bx+dy*by)/(den*scale);};if(axis==='x'){return{x:axisAmount(ca,sa*cp),y:0,z:0};}if(axis==='y'){return{x:0,y:axisAmount(-sa,ca*cp),z:0};}if(axis==='z'){const by=Math.abs(sp)<.08?-1:-sp;return{x:0,y:0,z:axisAmount(0,by)};}return{x:(dx*ca+dy*sa*cp)/scale,y:(-dx*sa+dy*ca*cp)/scale,z:(-dy*sp)/scale};};
    const softWeightForKey=(part,key,selected,radius)=>{if(selected.has(key))return 1;if(!(radius>0))return 0;const all=allPartVertexKeys(part),n=all.get(key);if(!n)return 0;let best=Infinity;for(const sk of selected){const sn=all.get(sk);if(!sn)continue;const dx=(n[0]-sn[0])*part.size.x,dy=(n[1]-sn[1])*part.size.y,dz=(n[2]-sn[2])*part.size.z;best=Math.min(best,Math.hypot(dx,dy,dz));}if(!Number.isFinite(best)||best>=radius)return 0;const t=1-best/radius;return t*t*(3-2*t);};
    const applyVertexDrag=(dx,dy)=>{const p=getPart();if(!p||!vertexDrag)return;const delta=vertexAxis==='normal'?normalDeltaFromDrag(dx,dy):screenDeltaToWorld(dx,dy,vertexAxis);const all=allPartVertexKeys(p),base=vertexDrag.base||{};p.vertex_offsets={...base};for(const key of all.keys()){const w=softWeightForKey(p,key,selectedVertexKeys,softRadius);if(w<=0)continue;const b=base[key]||{x:0,y:0,z:0};const snap=vertexDrag.snap||.025;const nv={x:b.x+delta.x*w,y:b.y+delta.y*w,z:b.z+delta.z*w};nv.x=Math.round(nv.x/snap)*snap;nv.y=Math.round(nv.y/snap)*snap;nv.z=Math.round(nv.z/snap)*snap;if(Math.abs(nv.x)+Math.abs(nv.y)+Math.abs(nv.z)<1e-6)delete p.vertex_offsets[key];else p.vertex_offsets[key]=nv;}persist(false,true);};
    const baseVertexLocal=(part,norm)=>{const pos=part?.position||{x:.5,y:.5,z:0},sz=part?.size||{x:1,y:1,z:1};return [pos.x-sz.x/2+(Number(norm?.[0])||0)*sz.x,pos.y-sz.y/2+(Number(norm?.[1])||0)*sz.y,pos.z+(Number(norm?.[2])||0)*sz.z];};
    const currentVertexLocal=(part,key,norm,offsets)=>{const b=baseVertexLocal(part,norm),o=offsets?.[key]||partVertexOffset(part,key);return[b[0]+(Number(o?.x)||0),b[1]+(Number(o?.y)||0),b[2]+(Number(o?.z)||0)];};
    const applyComponentDrag=(dx,dy)=>{const p=getPart();if(!p||!vertexDrag||!selectedVertexKeys.size)return;if(componentTool==='move'){applyVertexDrag(dx,dy);return;}const all=allPartVertexKeys(p),base=vertexDrag.base||{},keys=[...selectedVertexKeys].filter(k=>all.has(k));if(!keys.length)return;const pts=keys.map(k=>currentVertexLocal(p,k,all.get(k),base)),cent=[0,0,0];for(const q of pts){cent[0]+=q[0];cent[1]+=q[1];cent[2]+=q[2];}cent[0]/=pts.length;cent[1]/=pts.length;cent[2]/=pts.length;p.vertex_offsets={...base};if(componentTool==='scale'){const f=Math.max(.05,Math.min(20,Math.exp((dx-dy)*.006)));for(let i=0;i<keys.length;i++){const k=keys[i],norm=all.get(k),q=pts[i],nq=q.slice();if(vertexAxis==='x')nq[0]=cent[0]+(q[0]-cent[0])*f;else if(vertexAxis==='y')nq[1]=cent[1]+(q[1]-cent[1])*f;else if(vertexAxis==='z')nq[2]=cent[2]+(q[2]-cent[2])*f;else for(let a=0;a<3;a++)nq[a]=cent[a]+(q[a]-cent[a])*f;const bb=baseVertexLocal(p,norm);p.vertex_offsets[k]={x:nq[0]-bb[0],y:nq[1]-bb[1],z:nq[2]-bb[2]};}}else if(componentTool==='rotate'){const a=dx*.01,c=Math.cos(a),sn=Math.sin(a),axis=vertexAxis==='view'?'z':vertexAxis;for(let i=0;i<keys.length;i++){const k=keys[i],norm=all.get(k),q=pts[i],x=q[0]-cent[0],y=q[1]-cent[1],z=q[2]-cent[2];let nx=x,ny=y,nz=z;if(axis==='x'){ny=y*c-z*sn;nz=y*sn+z*c;}else if(axis==='y'){nx=x*c+z*sn;nz=-x*sn+z*c;}else{nx=x*c-y*sn;ny=x*sn+y*c;}const nq=[cent[0]+nx,cent[1]+ny,cent[2]+nz],bb=baseVertexLocal(p,norm);p.vertex_offsets[k]={x:nq[0]-bb[0],y:nq[1]-bb[1],z:nq[2]-bb[2]};}}persist(false,true);};
    const faceNormalNorm=(part,f)=>{const ns=f?.norms||[];if(ns.length<3)return[0,0,1];const sz=part?.size||{x:1,y:1,z:1},a=[ns[0][0]*sz.x,ns[0][1]*sz.y,ns[0][2]*sz.z],b=[ns[1][0]*sz.x,ns[1][1]*sz.y,ns[1][2]*sz.z],c=[ns[2][0]*sz.x,ns[2][1]*sz.y,ns[2][2]*sz.z],u=[b[0]-a[0],b[1]-a[1],b[2]-a[2]],v=[c[0]-a[0],c[1]-a[1],c[2]-a[2]],n=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]],l=Math.hypot(...n)||1;return[n[0]/l,n[1]/l,n[2]/l];};
    const rebuildSelectedFaceVertices=()=>{const p=getPart();selectedVertexKeys.clear();if(!p)return;const fs=ensureCustomFaces(p);for(const i of selectedFaceIndices){const f=fs[i];for(const n of f?.norms||[])selectedVertexKeys.add(partVertexKeyFromNorm(n[0],n[1],n[2]));}};
    const applyMaterialToSelectedFaces=()=>{const p=getPart(),mat=materialFromAtlas();if(!p||!mat||!selectedFaceIndices.size){ctx.ui.showToast?.({message:'FACE mode: selecciona una o más caras y una textura.',level:'info'});return;}const fs=ensureCustomFaces(p);for(const i of selectedFaceIndices)if(fs[i]){fs[i].material=deepClone(mat);fs[i].uv_rect=[0,0,1,1];fs[i].material_repeat=p.texture_mode!=='stretch';}p.custom_faces=fs;persist(false,false,'Assign face material');queuePreview();if(uvOpen)ensureUvEditor();};
    const clearSelectedFaceMaterials=()=>{const p=getPart();if(!p||!selectedFaceIndices.size)return;const fs=ensureCustomFaces(p);for(const i of selectedFaceIndices)if(fs[i])fs[i].material=null;p.custom_faces=fs;persist();queuePreview();};
    const extrudeSelectedFaces=(amount=.25)=>{const p=getPart();if(!p||!selectedFaceIndices.size)return;const fs=ensureCustomFaces(p),ids=[];for(const idx of [...selectedFaceIndices].sort((a,b)=>b-a)){const f=fs[idx];if(!f?.norms?.length)continue;const n=faceNormalNorm(p,f),sz=p.size||{x:1,y:1,z:1},dn=[n[0]*amount/Math.max(.001,sz.x),n[1]*amount/Math.max(.001,sz.y),n[2]*amount/Math.max(.001,sz.z)],old=f.norms.map(q=>q.slice()),neo=old.map(q=>[q[0]+dn[0],q[1]+dn[1],q[2]+dn[2]]),base=`${f.id||`cf_${idx}`}_ex${Date.now()%100000}`,cap={...deepClone(f),id:`${base}_cap`,norms:neo,material:cloneMaterial(f.material)},sides=[];for(let e=0;e<4;e++){const j=(e+1)%4;sides.push({id:`${base}_s${e}`,edge:'custom',surface:'side',norms:[old[e],old[j],neo[j],neo[e]],uv_rect:[0,0,1,1],material_repeat:f.material_repeat!==false,material:cloneMaterial(f.material)});}fs.splice(idx,1,cap,...sides);ids.push(cap.id);}p.custom_faces=fs;selectedFaceIndices.clear();for(let i=0;i<fs.length;i++)if(ids.includes(fs[i].id))selectedFaceIndices.add(i);rebuildSelectedFaceVertices();persist(true);};
    const insetSelectedFaces=(factor=.75)=>{const p=getPart();if(!p||!selectedFaceIndices.size)return;const fs=ensureCustomFaces(p),ids=[];for(const idx of [...selectedFaceIndices].sort((a,b)=>b-a)){const f=fs[idx];if(!f?.norms?.length)continue;const old=f.norms.map(q=>q.slice()),cent=[0,0,0];for(const q of old)for(let a=0;a<3;a++)cent[a]+=q[a]/4;const inn=old.map(q=>[cent[0]+(q[0]-cent[0])*factor,cent[1]+(q[1]-cent[1])*factor,cent[2]+(q[2]-cent[2])*factor]),base=`${f.id||`cf_${idx}`}_in${Date.now()%100000}`,inner={...deepClone(f),id:`${base}_inner`,norms:inn,material:cloneMaterial(f.material)},ring=[];for(let e=0;e<4;e++){const j=(e+1)%4;ring.push({id:`${base}_r${e}`,edge:f.edge,surface:f.surface,norms:[old[e],old[j],inn[j],inn[e]],uv_rect:[0,0,1,1],material_repeat:f.material_repeat!==false,material:cloneMaterial(f.material)});}fs.splice(idx,1,inner,...ring);ids.push(inner.id);}p.custom_faces=fs;selectedFaceIndices.clear();for(let i=0;i<fs.length;i++)if(ids.includes(fs[i].id))selectedFaceIndices.add(i);rebuildSelectedFaceVertices();persist(true);};
    const deleteSelectedFaces=()=>{const p=getPart();if(!p||!selectedFaceIndices.size)return;const fs=ensureCustomFaces(p).filter((_,i)=>!selectedFaceIndices.has(i));p.custom_faces=fs;selectedFaceIndices.clear();selectedVertexKeys.clear();persist(true);};

    const pointInTri=(px,py,a,b,c)=>{
      const v0=[c.x-a.x,c.y-a.y],v1=[b.x-a.x,b.y-a.y],v2=[px-a.x,py-a.y];
      const d00=v0[0]*v0[0]+v0[1]*v0[1],d01=v0[0]*v1[0]+v0[1]*v1[1],d02=v0[0]*v2[0]+v0[1]*v2[1],d11=v1[0]*v1[0]+v1[1]*v1[1],d12=v1[0]*v2[0]+v1[1]*v2[1];
      const den=d00*d11-d01*d01;if(Math.abs(den)<1e-9)return null;
      const u=(d11*d02-d01*d12)/den,v=(d00*d12-d01*d02)/den,w=1-u-v;
      return u>=-.02&&v>=-.02&&w>=-.02?[w,v,u]:null;
    };
    const clickedNormOnFace=(hit,x,y)=>{
      const pts=hit?.pts||[], norms=hit?.f?.vertex_norms||[];
      if(pts.length!==4||norms.length!==4)return null;
      let bc=pointInTri(x,y,pts[0],pts[1],pts[2]),ids=[0,1,2];
      if(!bc){bc=pointInTri(x,y,pts[0],pts[2],pts[3]);ids=[0,2,3];}
      if(!bc)return null;
      const n=[0,0,0];for(let k=0;k<3;k++)for(let a=0;a<3;a++)n[a]+=(Number(norms[ids[k]]?.[a])||0)*bc[k];
      return n.map(vertexCoord);
    };
    const clickedQuadUV=(hit,x,y)=>{
      const pts=hit?.pts||[];if(pts.length!==4)return null;
      let bc=pointInTri(x,y,pts[0],pts[1],pts[2]);
      let u=0,v=0;
      if(bc){u=bc[1]+bc[2];v=bc[2];}
      else{bc=pointInTri(x,y,pts[0],pts[2],pts[3]);if(!bc)return null;u=bc[1];v=bc[1]+bc[2];}
      const snap=Math.max(0,Number(cutSnap)||0),sn=q=>snap>0?Math.round(q/snap)*snap:q;
      u=Math.max(.015,Math.min(.985,sn(u)));v=Math.max(.015,Math.min(.985,sn(v)));
      return{u,v};
    };
    const splitFaceAtVertex=(hit,x,y)=>{
      const p=getPart();if(!p||!hit||hit.f.part_id!==p.id)return false;
      const q=clickedQuadUV(hit,x,y);if(!q)return false;
      const faces=ensureCustomFaces(p),rawIndex=Number.isInteger(hit?.f?.custom_face_index)?hit.f.custom_face_index:(Number(hit?.f?.part_face_index)||0),idx=Math.max(0,Math.min(faces.length-1,rawIndex)),f=faces[idx];
      if(!f||!Array.isArray(f.norms)||f.norms.length!==4)return false;
      const [a,b,c,d]=f.norms.map(n=>n.slice()),u=q.u,v=q.v;
      const top=mixNorm(a,b,u),right=mixNorm(b,c,v),bottom=mixNorm(d,c,u),left=mixNorm(a,d,v),center=mixNorm(top,bottom,v);
      const uv=Array.isArray(f.uv_rect)?f.uv_rect:[0,0,1,1],u0=uv[0],v0=uv[1],u1=uv[2],v1=uv[3],um=u0+(u1-u0)*u,vm=v0+(v1-v0)*v;
      const make=(suffix,norms,uvr)=>({id:`${f.id||`cf_${idx}`}_${suffix}_${Date.now()%100000}`,edge:f.edge,surface:f.surface,norms,uv_rect:uvr,material_repeat:f.material_repeat!==false,material:cloneMaterial(f.material)});
      let made=[];
      if(cutMode==='u')made=[make('u0',[a,top,bottom,d],[u0,v0,um,v1]),make('u1',[top,b,c,bottom],[um,v0,u1,v1])];
      else if(cutMode==='v')made=[make('v0',[a,b,right,left],[u0,v0,u1,vm]),make('v1',[left,right,c,d],[u0,vm,u1,v1])];
      else made=[make('nw',[a,top,center,left],[u0,v0,um,vm]),make('ne',[top,b,right,center],[um,v0,u1,vm]),make('se',[center,right,c,bottom],[um,vm,u1,v1]),make('sw',[left,center,bottom,d],[u0,vm,um,v1])];
      faces.splice(idx,1,...made);p.custom_faces=faces;
      selectedVertexKeys.clear();selectedFaceIndices.clear();selectedEdgeKeys.clear();
      const picked=cutMode==='u'?top:cutMode==='v'?left:center;selectedVertexKeys.add(partVertexKeyFromNorm(picked[0],picked[1],picked[2]));
      editMode='vertex';persist(true,false,`Multi-Cut ${cutMode.toUpperCase()} U${u.toFixed(3)} V${v.toFixed(3)}`);return true;
    };
    const faceAbsUvRect=(f,img)=>{
      if(!f||!img)return null;const mat=f.material||getPart()?.material;if(!mat)return null;const sr=mat.src_rect||{x:0,y:0,w:img.width,h:img.height},uv=Array.isArray(f.uv_rect)?f.uv_rect:[0,0,1,1];
      return{x:sr.x+sr.w*uv[0],y:sr.y+sr.h*uv[1],w:sr.w*(uv[2]-uv[0]),h:sr.h*(uv[3]-uv[1])};
    };
    const setFaceAbsUvRect=(f,img,rect)=>{
      if(!f||!img||!rect)return;let mat=cloneMaterial(f.material||getPart()?.material||materialFromAtlas());if(!mat)return;const x=Math.max(0,Math.min(img.width-1,rect.x)),y=Math.max(0,Math.min(img.height-1,rect.y)),w=Math.max(1,Math.min(img.width-x,rect.w)),h=Math.max(1,Math.min(img.height-y,rect.h));mat.src_rect={x:Math.round(x),y:Math.round(y),w:Math.round(w),h:Math.round(h)};f.material=mat;f.uv_rect=[0,0,1,1];f.material_repeat=false;
    };
    const uvMaterialImage=async()=>{
      const p=getPart(),fs=p?ensureCustomFaces(p):[],idx=[...selectedFaceIndices][0],f=Number.isInteger(idx)?fs[idx]:null,mat=f?.material||p?.material;
      if(mat?.kind==='image'&&mat.graphic){const key=`img:${String(mat.graphic).toLowerCase()}`;if(uvImageKey===key&&uvImage)return uvImage;uvImage=await loadModelTextureImage(ctx,mat.graphic);uvImageKey=key;return uvImage;}
      const tid=Number(mat?.tileset_id)||Number(atlasTilesetId)||initialTs(),key=`ts:${tid}`;if(uvImageKey===key&&uvImage)return uvImage;const res=await ensureTilesetResourceSet(ctx,tid);uvImage=res?.image||state.preview.tilesetImages.get(tid)||null;uvImageKey=key;return uvImage;
    };
    const faceUvImageKey=f=>{const mat=f?.material||getPart()?.material;if(mat?.kind==='image'&&mat.graphic)return`img:${String(mat.graphic).toLowerCase()}`;return`ts:${Number(mat?.tileset_id)||Number(atlasTilesetId)||initialTs()}`;};
    const drawUvEditor=()=>{
      const cv=body.querySelector('[data-ms-uv-layout]');if(!cv)return;const c=cv.getContext('2d'),p=getPart();if(!uvImage||!p){cv.width=512;cv.height=320;c.fillStyle='#0c1219';c.fillRect(0,0,cv.width,cv.height);c.fillStyle='#8d99a8';c.fillText('Select a textured face to edit UVs',18,28);return;}
      cv.width=uvImage.width;cv.height=uvImage.height;cv.style.width=`${Math.max(320,Math.round(uvImage.width*Math.min(2,Math.max(.5,atlasZoom))))}px`;cv.style.height='auto';c.imageSmoothingEnabled=false;c.clearRect(0,0,cv.width,cv.height);c.drawImage(uvImage,0,0);const fs=ensureCustomFaces(p);for(let i=0;i<fs.length;i++){if(faceUvImageKey(fs[i])!==uvImageKey)continue;const r=faceAbsUvRect(fs[i],uvImage);if(!r)continue;const sel=selectedFaceIndices.has(i);c.fillStyle=sel?'rgba(53,217,255,.18)':'rgba(255,106,42,.08)';c.fillRect(r.x,r.y,r.w,r.h);c.strokeStyle=sel?'#35d9ff':'rgba(255,106,42,.55)';c.lineWidth=sel?2:1;c.strokeRect(r.x+.5,r.y+.5,r.w-1,r.h-1);if(sel){c.fillStyle='#061014';for(const [hx,hy] of [[r.x,r.y],[r.x+r.w,r.y],[r.x+r.w,r.y+r.h],[r.x,r.y+r.h]]){c.fillRect(hx-4,hy-4,8,8);c.strokeStyle='#35d9ff';c.strokeRect(hx-4.5,hy-4.5,9,9);}}c.fillStyle=sel?'#dffaff':'rgba(255,255,255,.7)';c.font='10px monospace';c.fillText(String(i+1),r.x+4,r.y+12);}
    };
    const ensureUvEditor=()=>{void uvMaterialImage().then(()=>drawUvEditor());};
    const selectionNormal=()=>{const p=getPart();if(!p||!selectedFaceIndices.size)return null;const f=ensureCustomFaces(p)[[...selectedFaceIndices][0]];return f?faceNormalNorm(p,f):null;};
    const selectedCenterWorld=()=>{const p=getPart();if(!p)return[0,0,0];const all=allPartVertexKeys(p),keys=[...selectedVertexKeys].filter(k=>all.has(k));if(keys.length){const c=[0,0,0];for(const k of keys){const q=currentVertexLocal(p,k,all.get(k),p.vertex_offsets||{});c[0]+=q[0];c[1]+=q[1];c[2]+=q[2];}return c.map(v=>v/keys.length);}return[Number(p.position?.x)||0,Number(p.position?.y)||0,(Number(p.position?.z)||0)+(Number(p.size?.z)||1)/2];};
    const pickGizmoAt=(x,y)=>{if(!modelGizmo?.handles)return null;const dist=(a,b)=>{const vx=b.x-a.x,vy=b.y-a.y,den=vx*vx+vy*vy||1,t=Math.max(0,Math.min(1,((x-a.x)*vx+(y-a.y)*vy)/den)),qx=a.x+vx*t,qy=a.y+vy*t;return Math.hypot(x-qx,y-qy);};let best=null,bd=10;for(const [axis,h] of Object.entries(modelGizmo.handles)){const d=dist(h.a,h.b);if(d<bd){bd=d;best=axis;}}return best;};
    const applyObjectDrag=(dx,dy)=>{const p=getPart();if(!p||!vertexDrag?.objectBase)return;const base=vertexDrag.objectBase,axis=vertexAxis==='view'?'z':vertexAxis;if(componentTool==='move'){const d=screenDeltaToWorld(dx,dy,axis),sn=v=>Math.round(v/transformSnap)*transformSnap;p.position={...base.position,x:sn(base.position.x+d.x),y:sn(base.position.y+d.y),z:sn(base.position.z+d.z)};}else if(componentTool==='scale'){const f=Math.max(.02,Math.min(30,Math.exp((dx-dy)*.006)));p.size={...base.size};if(vertexAxis==='view'){p.size.x=Math.max(.02,base.size.x*f);p.size.y=Math.max(.02,base.size.y*f);p.size.z=Math.max(.02,base.size.z*f);}else p.size[axis]=Math.max(.02,base.size[axis]*f);}else if(componentTool==='rotate'){p.angle={...base.angle};p.angle[axis]=(Number(base.angle?.[axis])||0)+dx*.45;}persist(false,true);};
    const normalDeltaFromDrag=(dx,dy)=>{const p=getPart(),n=selectionNormal();if(!p||!n||!previewProjection?.scale)return{x:0,y:0,z:0};const amount=(dx-dy)*.75/previewProjection.scale;return{x:n[0]*amount,y:n[1]*amount,z:n[2]*amount};};
    const splitSelectedFacesUV=(u=.5,v=.5,label='Subdivide')=>{
      const p=getPart();if(!p||!selectedFaceIndices.size)return;
      u=Math.max(.01,Math.min(.99,Number(u)||.5));v=Math.max(.01,Math.min(.99,Number(v)||.5));
      const fs=ensureCustomFaces(p),newIds=[];
      for(const idx of [...selectedFaceIndices].sort((a,b)=>b-a)){
        const f=fs[idx];if(!f?.norms||f.norms.length!==4)continue;
        const [a,b,c,d]=f.norms.map(n=>n.slice()),top=mixNorm(a,b,u),right=mixNorm(b,c,v),bottom=mixNorm(d,c,u),left=mixNorm(a,d,v),center=mixNorm(top,bottom,v);
        const uv=Array.isArray(f.uv_rect)?f.uv_rect:[0,0,1,1],u0=uv[0],v0=uv[1],u1=uv[2],v1=uv[3],um=u0+(u1-u0)*u,vm=v0+(v1-v0)*v,base=`${f.id||`cf_${idx}`}_sub${Date.now()%100000}`;
        const make=(suffix,norms,uvr)=>({id:`${base}_${suffix}`,edge:f.edge,surface:f.surface,norms,uv_rect:uvr,material_repeat:f.material_repeat!==false,material:cloneMaterial(f.material)});
        const made=[make('nw',[a,top,center,left],[u0,v0,um,vm]),make('ne',[top,b,right,center],[um,v0,u1,vm]),make('se',[center,right,c,bottom],[um,vm,u1,v1]),make('sw',[left,center,bottom,d],[u0,vm,um,v1])];
        fs.splice(idx,1,...made);newIds.push(...made.map(x=>x.id));
      }
      p.custom_faces=fs;selectedFaceIndices.clear();for(let j=0;j<fs.length;j++)if(newIds.includes(fs[j].id))selectedFaceIndices.add(j);rebuildSelectedFaceVertices();persist(true,false,label);
    };
    const splitSelectedFacesAxis=(axis='u',t=.5)=>{
      const p=getPart();if(!p||!selectedFaceIndices.size)return;t=Math.max(.01,Math.min(.99,Number(t)||.5));const fs=ensureCustomFaces(p),newIds=[];
      for(const idx of [...selectedFaceIndices].sort((a,b)=>b-a)){
        const f=fs[idx];if(!f?.norms||f.norms.length!==4)continue;const [a,b,c,d]=f.norms.map(n=>n.slice()),uv=Array.isArray(f.uv_rect)?f.uv_rect:[0,0,1,1],u0=uv[0],v0=uv[1],u1=uv[2],v1=uv[3],base=`${f.id||`cf_${idx}`}_${axis}${Date.now()%100000}`;let made=[];
        const make=(suffix,norms,uvr)=>({id:`${base}_${suffix}`,edge:f.edge,surface:f.surface,norms,uv_rect:uvr,material_repeat:f.material_repeat!==false,material:cloneMaterial(f.material)});
        if(axis==='v'){const l=mixNorm(a,d,t),r=mixNorm(b,c,t),vm=v0+(v1-v0)*t;made=[make('a',[a,b,r,l],[u0,v0,u1,vm]),make('b',[l,r,c,d],[u0,vm,u1,v1])];}
        else{const top=mixNorm(a,b,t),bot=mixNorm(d,c,t),um=u0+(u1-u0)*t;made=[make('a',[a,top,bot,d],[u0,v0,um,v1]),make('b',[top,b,c,bot],[um,v0,u1,v1])];}
        fs.splice(idx,1,...made);newIds.push(...made.map(x=>x.id));
      }
      p.custom_faces=fs;selectedFaceIndices.clear();for(let j=0;j<fs.length;j++)if(newIds.includes(fs[j].id))selectedFaceIndices.add(j);rebuildSelectedFaceVertices();persist(true,false,`Loop cut ${axis.toUpperCase()}`);
    };
    const weldSelectedVertices=()=>{
      const p=getPart();if(!p||selectedVertexKeys.size<2){ctx.ui.showToast?.({message:'Selecciona 2 o más vértices para Weld.',level:'info'});return;}
      const fs=ensureCustomFaces(p),all=allPartVertexKeys(p),keys=[...selectedVertexKeys].filter(k=>all.has(k));if(keys.length<2)return;
      const pts=keys.map(k=>currentVertexLocal(p,k,all.get(k),p.vertex_offsets||{})),avg=[0,0,0];for(const q of pts){avg[0]+=q[0];avg[1]+=q[1];avg[2]+=q[2];}avg[0]/=pts.length;avg[1]/=pts.length;avg[2]/=pts.length;const nn=partVertexNormFromLocal(p,avg[0],avg[1],avg[2]),keySet=new Set(keys);
      for(const f of fs)for(let j=0;j<(f.norms?.length||0);j++){const n=f.norms[j],k=partVertexKeyFromNorm(n[0],n[1],n[2]);if(keySet.has(k))f.norms[j]=nn.slice();}
      const vo={...(p.vertex_offsets||{})};for(const k of keys)delete vo[k];p.vertex_offsets=vo;p.custom_faces=fs;selectedVertexKeys.clear();selectedVertexKeys.add(partVertexKeyFromNorm(nn[0],nn[1],nn[2]));selectedEdgeKeys.clear();selectedFaceIndices.clear();persist(true,false,'Weld vertices');
    };
    const duplicateSelectedFaces=()=>{const p=getPart();if(!p||!selectedFaceIndices.size)return;const fs=ensureCustomFaces(p),ids=[];for(const idx of [...selectedFaceIndices]){const f=fs[idx];if(!f)continue;const cp=deepClone(f);cp.id=`${f.id||`face_${idx}`}_copy_${Date.now()%100000}_${idx}`;fs.push(cp);ids.push(cp.id);}p.custom_faces=fs;selectedFaceIndices.clear();for(let i=0;i<fs.length;i++)if(ids.includes(fs[i].id))selectedFaceIndices.add(i);rebuildSelectedFaceVertices();persist(true,false,'Duplicate faces');};
    const flipSelectedFaces=()=>{const p=getPart();if(!p||!selectedFaceIndices.size)return;const fs=ensureCustomFaces(p);for(const idx of selectedFaceIndices){const f=fs[idx];if(!f?.norms)return;f.norms=[f.norms[0],f.norms[3],f.norms[2],f.norms[1]].map(q=>q.slice());if(Array.isArray(f.uv_rect)){const [u0,v0,u1,v1]=f.uv_rect;f.uv_rect=[u1,v0,u0,v1];}}p.custom_faces=fs;rebuildSelectedFaceVertices();persist(true,false,'Flip faces');};
    const mirrorPart=(axis)=>{const p=getPart();if(!p)return;ensureCustomFaces(p);const ai=axis==='x'?0:axis==='y'?1:2;for(const f of p.custom_faces||[]){if(Array.isArray(f.norms)){for(const n of f.norms)n[ai]=1-(Number(n[ai])||0);f.norms.reverse();}}p.vertex_offsets={};selectedVertexKeys.clear();selectedFaceIndices.clear();selectedEdgeKeys.clear();persist(true,false,`Mirror ${axis.toUpperCase()}`);};
    const bevelSelectedFaces=()=>{if(!selectedFaceIndices.size)return;insetSelectedFaces(.86);extrudeSelectedFaces(.06);vertexAxis='normal';componentTool='move';};
    const drawPreview=()=>{
      const cv=body.querySelector('[data-ms-preview]'),m=getModel();if(!cv||!m)return;
      const dpr=(previewDrag||cameraDrag)?1:Math.max(1,Math.min(2,window.devicePixelRatio||1)),r=cv.getBoundingClientRect();const w=Math.max(640,Math.round(r.width*dpr)),h=Math.max(360,Math.round(r.height*dpr));if(cv.width!==w||cv.height!==h){cv.width=w;cv.height=h;}
      const c=cv.getContext('2d');c.setTransform(dpr,0,0,dpr,0,0);const W=w/dpr,H=h/dpr;c.clearRect(0,0,W,H);c.fillStyle='#11161e';c.fillRect(0,0,W,H);c.imageSmoothingEnabled=false;
      const faces=partFacesLocal(),verts=faces.flatMap(f=>f.vertices||[]);const b=verts.length?{x0:Math.min(...verts.map(v=>v[0])),x1:Math.max(...verts.map(v=>v[0])),y0:Math.min(...verts.map(v=>v[1])),y1:Math.max(...verts.map(v=>v[1])),z0:Math.min(...verts.map(v=>v[2])),z1:Math.max(...verts.map(v=>v[2]))}:{x0:0,x1:4,y0:0,y1:4,z0:0,z1:2};
      const center=[(b.x0+b.x1)/2,(b.y0+b.y1)/2,(b.z0+b.z1)/2],span=Math.max(2,b.x1-b.x0,b.y1-b.y0,b.z1-b.z0),scale=Math.min(W,H)*.55/span*cam.zoom;const yaw=cam.yaw*Math.PI/180,pitch=cam.pitch*Math.PI/180;
      const projectP=v=>{let x=v[0]-center[0],y=v[1]-center[1],z=v[2]-center[2];const ca=Math.cos(yaw),sa=Math.sin(yaw);let rx=x*ca-y*sa,ry=x*sa+y*ca;const cp=Math.cos(pitch),sp=Math.sin(pitch);let sy=ry*cp-z*sp,depth=ry*sp+z*cp;return{x:W/2+(cam.panX||0)+rx*scale,y:H*.54+(cam.panY||0)+sy*scale,depth};};previewProjection={center,scale,yaw,pitch,projectP,W,H};
      c.strokeStyle='rgba(165,180,198,.18)';c.lineWidth=1;const grid=8;for(let i=-grid;i<=grid;i++){let a=projectP([center[0]+i,center[1]-grid,0]),bb=projectP([center[0]+i,center[1]+grid,0]);c.beginPath();c.moveTo(a.x,a.y);c.lineTo(bb.x,bb.y);c.stroke();a=projectP([center[0]-grid,center[1]+i,0]);bb=projectP([center[0]+grid,center[1]+i,0]);c.beginPath();c.moveTo(a.x,a.y);c.lineTo(bb.x,bb.y);c.stroke();}
      previewHits=[];const items=faces.map((f,face_index)=>{const pts=(f.vertices||[]).map(projectP);return{f,face_index,pts,depth:pts.reduce((a,p)=>a+p.depth,0)/Math.max(1,pts.length)};}).sort((a,b)=>a.depth-b.depth);
      for(const it of items){const pts=it.pts;if(pts.length!==4)continue;c.save();c.beginPath();c.moveTo(pts[0].x,pts[0].y);for(let i=1;i<4;i++)c.lineTo(pts[i].x,pts[i].y);c.closePath();if(displayMode==='wire'||cameraDrag){c.fillStyle=cameraDrag?'rgba(75,88,102,.42)':'rgba(17,23,31,.28)';c.fill();}else{const src=meshFaceMaterialSource(ctx,it.f);if(src?.img){c.save();c.clip();const xs=pts.map(p=>p.x),ys=pts.map(p=>p.y),x0=Math.min(...xs),y0=Math.min(...ys),x1=Math.max(...xs),y1=Math.max(...ys);const uv=it.f.material_repeat===false&&Array.isArray(it.f.uv_rect)?it.f.uv_rect:[0,0,1,1],usx=src.sx+src.sw*uv[0],usy=src.sy+src.sh*uv[1],usw=Math.max(1,src.sw*(uv[2]-uv[0])),ush=Math.max(1,src.sh*(uv[3]-uv[1]));c.drawImage(src.img,usx,usy,usw,ush,x0,y0,Math.max(1,x1-x0),Math.max(1,y1-y0));c.restore();}else{c.fillStyle=it.f.surface==='top'?'#9da77b':'#6f6257';c.fill();}}const rawFaceIndex=Number.isInteger(it.f.custom_face_index)?it.f.custom_face_index:(Number(it.f.part_face_index)||0),faceSelected=it.f.part_id===selectedPartId&&editMode==='face'&&selectedFaceIndices.has(rawFaceIndex);c.strokeStyle=faceSelected?'#3ee6ff':(it.f.part_id===selectedPartId?'#ff6a2a':'rgba(220,230,242,.35)');c.lineWidth=faceSelected?3:(it.f.part_id===selectedPartId?2:1);c.stroke();c.restore();const xs=pts.map(p=>p.x),ys=pts.map(p=>p.y);previewHits.push({part_id:it.f.part_id,face_index:it.face_index,f:it.f,pts:it.pts,depth:it.depth,x0:Math.min(...xs),x1:Math.max(...xs),y0:Math.min(...ys),y1:Math.max(...ys)});}
      const selectedPart=getPart();
      if(selectedPart?.collision!==false){const cvv=partCollisionWireVertices(selectedPart);if(cvv.length===8){const pp=cvv.map(projectP),edges=[[0,1],[1,2],[2,3],[3,0],[4,5],[5,6],[6,7],[7,4],[0,4],[1,5],[2,6],[3,7]];c.save();c.strokeStyle='#20d9ff';c.lineWidth=1.5;c.setLineDash([5,4]);for(const [a,b] of edges){c.beginPath();c.moveTo(pp[a].x,pp[a].y);c.lineTo(pp[b].x,pp[b].y);c.stroke();}c.restore();}}
      previewVertices=[];
      if(selectedPartId){const seen=new Set();for(const it of items){if(it.f.part_id!==selectedPartId)continue;const keys=it.f.vertex_keys||[],norms=it.f.vertex_norms||[];for(let i=0;i<it.pts.length;i++){const key=keys[i];if(!key||seen.has(key))continue;seen.add(key);previewVertices.push({part_id:selectedPartId,key,norm:norms[i],x:it.pts[i].x,y:it.pts[i].y,depth:it.pts[i].depth});}}previewVertices.sort((a,b)=>a.depth-b.depth);if(editMode==='vertex'||editMode==='edge'||editMode==='face'){for(const v of previewVertices){const sel=selectedVertexKeys.has(v.key);c.beginPath();c.arc(v.x,v.y,sel?5:3.5,0,Math.PI*2);c.fillStyle=sel?'#ff6a2a':'#f3f6fa';c.fill();c.strokeStyle=sel?'#ffd2c2':'#11161e';c.lineWidth=1;c.stroke();}}else{c.fillStyle='#ff4b18';for(const v of previewVertices.slice(0,32))c.fillRect(v.x-2.5,v.y-2.5,5,5);}}
      // Precise Multi-Cut hover: the click position defines exact U/V cut lines.
      if(editMode==='addvertex'&&cutHover){const h=previewHits.find(x=>x.part_id===cutHover.part_id&&((Number.isInteger(x.f.custom_face_index)?x.f.custom_face_index:(Number(x.f.part_face_index)||0))===cutHover.faceIndex));if(h?.pts?.length===4){const [a,b,cc,d]=h.pts,u=cutHover.u,v=cutHover.v,lerp=(p0,p1,t)=>({x:p0.x+(p1.x-p0.x)*t,y:p0.y+(p1.y-p0.y)*t}),t0=lerp(a,b,u),t1=lerp(d,cc,u),l0=lerp(a,d,v),l1=lerp(b,cc,v);c.save();c.strokeStyle='#ffd34f';c.lineWidth=1.5;c.setLineDash([6,4]);c.beginPath();if(cutMode!=='v'){c.moveTo(t0.x,t0.y);c.lineTo(t1.x,t1.y);}if(cutMode!=='u'){c.moveTo(l0.x,l0.y);c.lineTo(l1.x,l1.y);}c.stroke();c.setLineDash([]);c.fillStyle='rgba(8,12,18,.88)';c.fillRect((t0.x+t1.x+l0.x+l1.x)/4-46,(t0.y+t1.y+l0.y+l1.y)/4-12,92,20);c.fillStyle='#ffe88e';c.font='10px monospace';c.textAlign='center';c.fillText(`U ${u.toFixed(3)} · V ${v.toFixed(3)}`,(t0.x+t1.x+l0.x+l1.x)/4,(t0.y+t1.y+l0.y+l1.y)/4+2);c.restore();}}
      // Unity-like transform gizmo. Object and component transforms are dragged by axis handles.
      modelGizmo=null;if(selectedPartId&&editMode!=='addvertex'){const wc=selectedCenterWorld(),sp=projectP(wc),len=Math.max(.35,span*.11),axes={x:[len,0,0],y:[0,len,0],z:[0,0,len]},colors={x:'#ff5c5c',y:'#62dc73',z:'#5ba7ff'},handles={};c.save();c.lineWidth=3;for(const [axis,dv] of Object.entries(axes)){const ep=projectP([wc[0]+dv[0],wc[1]+dv[1],wc[2]+dv[2]]);handles[axis]={a:sp,b:ep};c.strokeStyle=colors[axis];c.beginPath();c.moveTo(sp.x,sp.y);c.lineTo(ep.x,ep.y);c.stroke();c.fillStyle=colors[axis];c.beginPath();c.arc(ep.x,ep.y,4.5,0,Math.PI*2);c.fill();}const n=selectionNormal();if(n&&selectedFaceIndices.size){const ep=projectP([wc[0]+n[0]*len,wc[1]+n[1]*len,wc[2]+n[2]*len]);handles.normal={a:sp,b:ep};c.strokeStyle='#d779ff';c.setLineDash([4,3]);c.beginPath();c.moveTo(sp.x,sp.y);c.lineTo(ep.x,ep.y);c.stroke();c.setLineDash([]);c.fillStyle='#d779ff';c.beginPath();c.arc(ep.x,ep.y,4.5,0,Math.PI*2);c.fill();}c.restore();modelGizmo={center:sp,handles};}
      c.fillStyle='rgba(8,12,18,.88)';c.fillRect(8,H-26,Math.min(W-16,760),20);c.fillStyle='#dfe7f1';c.font='11px monospace';const modeText=editMode==='vertex'?`VERTEX · ${selectedVertexKeys.size} · ${componentTool.toUpperCase()} · ${vertexAxis.toUpperCase()} · soft ${Number(softRadius).toFixed(2)}`:editMode==='edge'?`EDGE · ${selectedEdgeKeys.size} · ${componentTool.toUpperCase()} · ${vertexAxis.toUpperCase()}`:editMode==='face'?`FACE · ${selectedFaceIndices.size} · ${componentTool.toUpperCase()} · ${vertexAxis.toUpperCase()}`:editMode==='addvertex'?`MULTI-CUT ${cutMode.toUpperCase()} · exact U/V · snap ${cutSnap||'OFF'}`:'OBJECT';c.fillText(`ALT+LMB/RMB ORBIT · MMB PAN · WHEEL ZOOM · F FRAME · W/E/R GIZMO · Ctrl+Z/Y · ${modeText} · ${faces.length} FACES`,14,H-12);
    };
    const queuePreview=()=>{if(previewRaf)cancelAnimationFrame(previewRaf);previewRaf=requestAnimationFrame(()=>{previewRaf=0;drawPreview();});};
    const drawPartThumb=()=>{const p=getPart(),cv=body.querySelector('[data-ms-picked]');if(cv)v2DrawMaterialThumb(ctx,cv,materialFromAtlas(),atlasSelection?`ms:${atlasTilesetId}:${atlasSelection.x}:${atlasSelection.y}`:'');const txt=body.querySelector('[data-ms-picked-text]');if(txt)txt.textContent=atlasSelection?`Tileset ${atlasTilesetId} · ${atlasSelection.w/TILE_SIZE}×${atlasSelection.h/TILE_SIZE}`:'No texture selected';};
    const drawMaterialButtons=()=>{const p=getPart();for(const cv of body.querySelectorAll('canvas[data-ms-face-thumb]')){const edge=cv.getAttribute('data-ms-face-thumb'),mat=edge==='all'?(p?.material||p?.face_materials?.top):p?.face_materials?.[edge];v2DrawMaterialThumb(ctx,cv,mat||null,`part:${p?.id||''}:${edge}`);}};

    const render=()=>{const models=getModels(),m=getModel();if(!m)return;syncHistory();const p=getPart(),mb=modelPartBounds(m),modelHeight=Math.max(0,mb.z1-mb.z0);const modelList=Object.values(models).map(x=>`<button data-ms-model="${escapeHtml(x.id)}" style="${buttonStyle(x.id===state.modelSelectedId)}width:100%;text-align:left;margin-bottom:4px;">${escapeHtml(x.name)} <span style="opacity:.55;float:right">${x.parts?.length||0}</span></button>`).join('');const tsOpts=tsList().map(t=>`<option value="${Number(t.id)}" ${Number(t.id)===Number(atlasTilesetId)?'selected':''}>${escapeHtml(t.name||t.tilesetName||`Tileset ${t.id}`)}</option>`).join('');const parts=(m.parts||[]).map((x,i)=>`<button data-ms-part="${escapeHtml(x.id)}" style="${buttonStyle(x.id===selectedPartId)}width:100%;text-align:left;margin:2px 0;">${String(i).padStart(2,'0')} ${escapeHtml(x.name)} <span style="float:right;opacity:.6">${x.type.toUpperCase()}</span></button>`).join('')||`<div style="padding:8px;color:var(--text-tertiary)">No parts yet. Add a primitive.</div>`;
      const val=(obj,k)=>Number(obj?.[k])||0;
      const customFaces=p?ensureCustomFaces(p):[],faceRows=customFaces.map((f,i)=>`<button data-ms-face-row="${i}" class="${selectedFaceIndices.has(i)?'active':''}"><span>Face ${String(i+1).padStart(3,'0')}</span><small>${escapeHtml(String(f.surface||f.edge||'custom'))}</small></button>`).join('');
      const transformPanel = p ? `<div class="ms-card">
        <div class="ms-card-title">Part</div>
        <input data-ms-part-name value="${escapeHtml(p.name)}" class="ms-full" />
        <div class="ms-grid3 ms-gap"><label>X<input data-ms-pos="x" type="number" step=".25" value="${val(p.position,'x')}"></label><label>Y<input data-ms-pos="y" type="number" step=".25" value="${val(p.position,'y')}"></label><label>Z<input data-ms-pos="z" type="number" step=".25" value="${val(p.position,'z')}"></label></div>
        <div class="ms-row-title"><span>Size</span><button data-ms-fit-texture class="ms-mini">Fit texture</button></div>
        <div class="ms-grid3 ms-gap"><label>X<input data-ms-size="x" type="number" min=".05" step=".25" value="${val(p.size,'x')}"></label><label>Y<input data-ms-size="y" type="number" min=".05" step=".25" value="${val(p.size,'y')}"></label><label>Z<input data-ms-size="z" type="number" min=".05" step=".25" value="${val(p.size,'z')}"></label></div>
        <div class="ms-row-title"><span>Rotation</span></div>
        <div class="ms-grid3 ms-gap"><label>X<input data-ms-angle="x" type="number" step="5" value="${val(p.angle,'x')}"></label><label>Y<input data-ms-angle="y" type="number" step="5" value="${val(p.angle,'y')}"></label><label>Z<input data-ms-angle="z" type="number" step="5" value="${val(p.angle,'z')}"></label></div>
      </div>
      <div class="ms-card">
        <div class="ms-card-title">Mesh</div>
        <div class="ms-grid3 ms-gap"><label>Axis<select data-ms-axis><option value="x" ${p.axis==='x'?'selected':''}>X</option><option value="y" ${p.axis==='y'?'selected':''}>Y</option><option value="z" ${p.axis==='z'?'selected':''}>Z</option></select></label><label>Segments<input data-ms-segments type="number" min="4" max="24" value="${p.segments}"></label><label>Subdiv<input data-ms-subdiv type="number" min="1" max="8" value="${p.subdivisions||1}"></label></div>
        ${(editMode!=='object')?`<div class="ms-soft"><label>Soft radius<input data-ms-soft type="number" min="0" max="8" step=".25" value="${Number(softRadius)||0}"></label><div class="ms-actions"><button data-ms-reset-vertices>Reset move</button><button data-ms-reset-topology>Reset mesh</button></div></div>`:`<button data-ms-enter-vertex class="ms-wide">Edit vertices</button>`}
      </div>
      <div class="ms-row-title">Modeling helpers</div><div class="ms-grid3 ms-gap"><button data-ms-mirror="x">Mirror X</button><button data-ms-mirror="y">Mirror Y</button><button data-ms-mirror="z">Mirror Z</button></div>
      <div class="ms-actions"><button data-ms-dup-part>Duplicate part</button><button data-ms-del-part class="danger">Delete part</button></div>` : `<div class="ms-empty">Select or add a part.</div>`;

      const materialPanel = p ? `<div class="ms-card">
        <div class="ms-card-title">UV / Material</div>
        <div class="ms-actions"><button data-ms-uv-toggle class="${uvOpen?'active':''}">${uvOpen?'Close UV Editor':'Open UV Editor'}</button><button data-ms-apply-selected class="primary">Assign texture</button></div>
        <div class="ms-picked"><canvas data-ms-picked width="72" height="72"></canvas><div><b data-ms-picked-text>No texture selected</b><small>Pick pixels/tiles, select any polygon, then Assign texture.</small></div></div>
        <label>Mapping<select data-ms-texture-mode><option value="repeat" ${(p.texture_mode||((p.repeat===false)?'stretch':'repeat'))!=='stretch'?'selected':''}>Repeat pattern</option><option value="stretch" ${(p.texture_mode||((p.repeat===false)?'stretch':'repeat'))==='stretch'?'selected':''}>Stretch once</option></select></label>
      </div>
      <div class="ms-card">
        <div class="ms-card-title"><span>Polygon faces</span><span>${customFaces.length}</span></div>
        <div class="ms-face-list">${faceRows||'<small>No custom faces yet. Switch to FACE and use Multi-Cut/Extrude.</small>'}</div>
        <div class="ms-actions"><button data-ms-clear-selected-face>Clear selected material</button><button data-ms-clear-mat class="danger-soft">Clear part materials</button></div>
        <small>No face-count limit. TOP/NORTH/SOUTH/EAST/WEST are only primitive defaults and are hidden from the normal workflow.</small>
      </div>
      <details class="ms-card"><summary>Primitive material defaults</summary><div class="ms-face-grid" style="margin-top:8px">${['all','top','north','south','east','west'].map(edge=>`<button data-ms-apply="${edge}"><canvas data-ms-face-thumb="${edge}" width="46" height="34"></canvas><span>${edge.toUpperCase()}</span></button>`).join('')}</div></details>` : `<div class="ms-empty">Select a part to edit materials.</div>`;

      const collisionPanel = p ? `<div class="ms-card">
        <div class="ms-card-title">Model behavior</div>
        <label>Collision behavior<select data-ms-model-collision><option value="solid" ${m.collision==='solid'?'selected':''}>Solid</option><option value="climb" ${m.collision==='climb'?'selected':''}>Climb</option><option value="one-way" ${m.collision==='one-way'?'selected':''}>One-way</option><option value="none" ${m.collision==='none'?'selected':''}>None</option></select></label>
      </div>
      <div class="ms-card collision-card">
        <div class="ms-card-title"><span>Part collider</span><label class="ms-check"><input data-ms-collision type="checkbox" ${p.collision!==false?'checked':''}> Enabled</label></div>
        <label>Mode<select data-ms-collision-mode><option value="auto" ${p.collision_shape?.mode!=='manual'?'selected':''}>Auto · visual bounds</option><option value="manual" ${p.collision_shape?.mode==='manual'?'selected':''}>Custom box</option></select></label>
        <div class="ms-row-title">Size</div><div class="ms-grid3 ms-gap">${['x','y','z'].map(k=>`<label>${k.toUpperCase()}<input data-ms-col-size="${k}" type="number" min=".05" step=".1" value="${val(p.collision_shape?.size||p.size,k)}" ${p.collision_shape?.mode==='manual'?'':'disabled'}></label>`).join('')}</div>
        <div class="ms-row-title">Offset</div><div class="ms-grid3 ms-gap">${['x','y','z'].map(k=>`<label>${k.toUpperCase()}<input data-ms-col-off="${k}" type="number" step=".1" value="${val(p.collision_shape?.offset||{},k)}" ${p.collision_shape?.mode==='manual'?'':'disabled'}></label>`).join('')}</div>
        <button data-ms-fit-collision class="ms-wide">Fit collider to mesh</button>
        <small>Cyan wireframe in the viewport is the gameplay collider.</small>
      </div>` : `<div class="ms-empty">Select a part to edit collision.</div>`;

      const inspectorPanel = inspectorTab==='material' ? materialPanel : inspectorTab==='collision' ? collisionPanel : transformPanel;
      const editTools = `<span class="ms-divider"></span><button data-ms-ctool="move" class="${componentTool==='move'?'active':''}">W Move</button><button data-ms-ctool="rotate" class="${componentTool==='rotate'?'active':''}">E Rotate</button><button data-ms-ctool="scale" class="${componentTool==='scale'?'active':''}">R Scale</button><span class="ms-divider"></span><button data-ms-vaxis="view" class="${vertexAxis==='view'?'active':''}">Free</button><button data-ms-vaxis="x" class="${vertexAxis==='x'?'active':''}">X</button><button data-ms-vaxis="y" class="${vertexAxis==='y'?'active':''}">Y</button><button data-ms-vaxis="z" class="${vertexAxis==='z'?'active':''}">Z</button>${editMode==='face'&&selectedFaceIndices.size&&componentTool==='move'?`<button data-ms-vaxis="normal" class="${vertexAxis==='normal'?'active':''}">Normal</button>`:''}<label class="ms-inline-label">Snap<select data-ms-snap><option value=".005" ${transformSnap===.005?'selected':''}>.005</option><option value=".01" ${transformSnap===.01?'selected':''}>.01</option><option value=".025" ${transformSnap===.025?'selected':''}>.025</option><option value=".05" ${transformSnap===.05?'selected':''}>.05</option><option value=".1" ${transformSnap===.1?'selected':''}>.1</option><option value=".25" ${transformSnap===.25?'selected':''}>.25</option></select></label>${editMode==='face'?`<span class="ms-divider"></span><button data-ms-extrude title="Create cap + sides, then drag the purple Normal handle">Extrude</button><button data-ms-inset>Inset</button><button data-ms-bevel>Bevel</button><button data-ms-subdivide>Subdivide</button><button data-ms-loop-u>Cut U</button><button data-ms-loop-v>Cut V</button><button data-ms-dup-face>Duplicate</button><button data-ms-flip-face>Flip</button><button data-ms-delete-face class="danger">Delete</button>`:''}${editMode==='vertex'&&selectedVertexKeys.size>1?`<span class="ms-divider"></span><button data-ms-weld>Weld</button>`:''}${editMode==='addvertex'?`<span class="ms-divider"></span><label class="ms-inline-label">Cut<select data-ms-cut-mode><option value="cross" ${cutMode==='cross'?'selected':''}>Cross</option><option value="u" ${cutMode==='u'?'selected':''}>U line</option><option value="v" ${cutMode==='v'?'selected':''}>V line</option></select></label><label class="ms-inline-label">Snap<select data-ms-cut-snap><option value="0" ${cutSnap===0?'selected':''}>Off</option><option value=".005" ${cutSnap===.005?'selected':''}>0.5%</option><option value=".01" ${cutSnap===.01?'selected':''}>1%</option><option value=".025" ${cutSnap===.025?'selected':''}>2.5%</option><option value=".05" ${cutSnap===.05?'selected':''}>5%</option><option value=".1" ${cutSnap===.1?'selected':''}>10%</option></select></label>`:''}`;

      body.innerHTML=`<style>
      [data-ms-root]{--ms-bg:#0b0f14;--ms-panel:#111720;--ms-panel2:#151d27;--ms-line:#28313d;--ms-muted:#8d99a8;--ms-accent:#ff6a2a;--ms-cyan:#35d9ff;color:#e7edf4;font:12px Inter,system-ui,sans-serif;background:var(--ms-bg)}
      [data-ms-root] *{box-sizing:border-box}[data-ms-root] button,[data-ms-root] input,[data-ms-root] select{font:inherit;color:inherit}
      [data-ms-root] button{background:#18212c;border:1px solid #34404e;border-radius:7px;padding:7px 9px;cursor:pointer}[data-ms-root] button:hover{border-color:#59697c;background:#202c39}[data-ms-root] button.active{border-color:var(--ms-accent);background:#3a2018;color:#fff}[data-ms-root] button.primary{background:#bf4b20;border-color:#ff6a2a}[data-ms-root] button.danger{color:#ff9b94}[data-ms-root] button.danger-soft{color:#ffb0aa}
      [data-ms-root] input,[data-ms-root] select{width:100%;background:#0c1219;border:1px solid #354150;border-radius:6px;padding:6px 7px}[data-ms-root] label{display:grid;gap:4px;color:#aeb8c4;font-size:11px}[data-ms-root] small{display:block;color:var(--ms-muted);line-height:1.4;margin-top:5px}
      .ms-root{height:94vh;min-height:700px;display:grid;grid-template-rows:54px minmax(0,1fr)}.ms-header{display:flex;align-items:center;gap:8px;padding:7px 11px;border-bottom:1px solid var(--ms-line);background:#121922}.ms-title{font-weight:750;font-size:14px}.ms-badge{padding:4px 8px;border-radius:999px;background:#342117;color:#ff9d72;font-size:10px}.ms-spacer{flex:1}.ms-header-group{display:flex;align-items:center;gap:5px}.ms-header input{width:58px}.ms-main{min-height:0;display:grid;grid-template-columns:190px minmax(520px,1fr) 310px}.ms-outliner{min-height:0;border-right:1px solid var(--ms-line);background:#0f151d;display:grid;grid-template-rows:auto minmax(0,1fr)}.ms-out-scroll{overflow:auto;padding:8px}.ms-section-title{padding:10px 10px 6px;color:#9aa7b6;font-size:10px;text-transform:uppercase;letter-spacing:.08em}.ms-out-actions{padding:8px;border-top:1px solid var(--ms-line);display:grid;gap:6px}.ms-out-actions .row{display:grid;grid-template-columns:1fr 1fr;gap:5px}.ms-center{min-width:0;min-height:0;display:grid;grid-template-rows:48px minmax(0,1fr) ${uvOpen?'minmax(210px,34%)':'0px'};background:#0a0f15}.ms-toolbar{display:flex;align-items:center;gap:5px;padding:6px 8px;border-bottom:1px solid var(--ms-line);overflow-x:auto;white-space:nowrap}.ms-toolbar .ms-divider{width:1px;height:24px;background:var(--ms-line);margin:0 3px}.ms-viewport{min-height:0;position:relative}.ms-viewport canvas{display:block;width:100%;height:100%;background:#10161e}.ms-uv{min-height:0;border-top:1px solid var(--ms-line);display:${uvOpen?'grid':'none'};grid-template-rows:40px minmax(0,1fr);background:#0d131a}.ms-uv-head{display:flex;align-items:center;gap:7px;padding:5px 8px;border-bottom:1px solid var(--ms-line)}.ms-uv-head select:first-of-type{width:min(330px,45%)}.ms-uv-scroll{overflow:auto;padding:8px;background:#090d12}.ms-uv canvas{display:block;image-rendering:pixelated;cursor:crosshair}.ms-inspector{min-height:0;border-left:1px solid var(--ms-line);background:#101720;display:grid;grid-template-rows:auto minmax(0,1fr)}.ms-tabs{display:grid;grid-template-columns:repeat(3,1fr);gap:4px;padding:7px;border-bottom:1px solid var(--ms-line)}.ms-tabs button{padding:8px 4px}.ms-inspect-scroll{overflow:auto;padding:9px}.ms-card{background:#131b25;border:1px solid #293544;border-radius:9px;padding:9px;margin-bottom:8px}.ms-card-title{display:flex;justify-content:space-between;align-items:center;font-weight:700;margin-bottom:8px;color:#eef4fa}.ms-row-title{margin:9px 0 5px;color:#aeb8c4;font-weight:650}.ms-grid3{display:grid;grid-template-columns:repeat(3,1fr)}.ms-gap{gap:5px}.ms-actions{display:grid;grid-template-columns:1fr 1fr;gap:5px;margin-top:7px}.ms-wide{width:100%;margin-top:7px}.ms-mini{padding:3px 6px!important;font-size:10px!important}.ms-soft{margin-top:8px;padding-top:8px;border-top:1px solid var(--ms-line)}.ms-picked{display:grid;grid-template-columns:72px 1fr;gap:8px;align-items:center}.ms-picked canvas,.ms-face-grid canvas{image-rendering:pixelated;background:#0b1017;border:1px solid #334050;border-radius:4px}.ms-picked small{margin:3px 0}.ms-face-grid{display:grid;grid-template-columns:repeat(2,1fr);gap:5px}.ms-face-grid button{display:grid;grid-template-columns:52px 1fr;align-items:center;text-align:left;padding:5px}.ms-check{display:flex!important;align-items:center;gap:5px!important}.ms-check input{width:auto!important}.ms-empty{padding:20px 10px;text-align:center;color:var(--ms-muted)}.ms-model-meta{padding:0 10px 8px;color:var(--ms-muted);font-size:10px}.ms-full{width:100%}.ms-inline-label{display:flex!important;align-items:center;gap:5px!important;font-size:9px!important;color:var(--ms-muted)!important}.ms-inline-label select{width:68px!important;padding:5px!important}.ms-face-list{max-height:220px;overflow:auto;display:grid;gap:3px}.ms-face-list button{display:flex;align-items:center;justify-content:space-between;text-align:left;padding:6px 7px}.ms-face-list button small{margin:0}.ms-uv-body{min-height:0;display:grid;grid-template-columns:minmax(320px,1fr) minmax(320px,1fr)}.ms-uv-pane{min-width:0;min-height:0;display:grid;grid-template-rows:30px minmax(0,1fr);border-right:1px solid var(--ms-line)}.ms-uv-pane:last-child{border-right:0}.ms-uv-pane-head{display:flex;align-items:center;gap:5px;padding:4px 8px;color:#aeb8c4;font-size:10px;background:#101720}.ms-uv-pane-scroll{overflow:auto;padding:8px;background:#090d12}.ms-uv-pane canvas{display:block;image-rendering:pixelated}.ms-toolbar button[data-ms-undo],.ms-toolbar button[data-ms-redo]{min-width:34px}.ms-toolbar button:disabled{opacity:.35;cursor:default}
      </style><div data-ms-root class="ms-root">
        <header class="ms-header"><div class="ms-title">2.5D Model Studio</div><span class="ms-badge">LOW-POLY</span><div class="ms-spacer"></div><div class="ms-header-group"><span style="color:var(--ms-muted)">Place</span><button data-ms-place-rot="-15">↶</button><input data-ms-place-rot-input type="number" step="5" value="${normalizeModelPlacementRotation(state.modelRotation)}"><span>°</span><button data-ms-place-rot="15">↷</button></div><button data-ms-map>← Terrain</button><button data-ms-place class="primary">Place model</button></header>
        <div class="ms-main">
          <aside class="ms-outliner"><div style="min-height:0;display:grid;grid-template-rows:auto minmax(90px,.7fr) auto minmax(120px,1fr) auto;"><div class="ms-section-title">Models</div><div class="ms-out-scroll">${modelList}</div><div class="ms-section-title">Parts</div><div class="ms-out-scroll">${parts}</div><div class="ms-out-actions"><div class="row"><button data-ms-new>New model</button><button data-ms-from>From map</button></div><div class="row"><button data-ms-import-bb>Import .bbmodel</button><button data-ms-reload-bb ${m.external_link?'':'disabled'}>Reload link</button></div><details><summary style="cursor:pointer;color:var(--ms-muted);padding:5px 0">Add primitive</summary><div class="row" style="margin-top:5px">${[['box','Box'],['billboard','Billboard'],['relief','Relief'],['wedge','Wedge'],['cylinder','Cylinder'],['prism','Prism'],['sphere','Sphere'],['dome','Dome']].map(([t,l])=>`<button data-ms-add="${t}">+ ${l}</button>`).join('')}</div></details><details><summary style="cursor:pointer;color:var(--ms-muted);padding:5px 0">Model actions</summary><div class="row" style="margin-top:5px"><button data-ms-reload-tex>Reload textures</button><button data-ms-dup-model>Duplicate</button><button data-ms-del-model class="danger">Delete</button><label>Runtime<select data-ms-quality><option value="pixel-low" ${m.runtime_quality!=='original'?'selected':''}>Pixel / Ultra Low</option><option value="original" ${m.runtime_quality==='original'?'selected':''}>Original</option></select></label></div></details></div></div></aside>
          <main class="ms-center"><div class="ms-toolbar"><button data-ms-undo title="Ctrl+Z" ${history.undo.length?'':'disabled'}>↶</button><button data-ms-redo title="Ctrl+Y / Ctrl+Shift+Z" ${history.redo.length?'':'disabled'}>↷</button><span class="ms-divider"></span><button data-ms-edit="object" class="${editMode==='object'?'active':''}">Object</button><button data-ms-edit="vertex" class="${editMode==='vertex'?'active':''}">Vertex</button><button data-ms-edit="edge" class="${editMode==='edge'?'active':''}">Edge</button><button data-ms-edit="face" class="${editMode==='face'?'active':''}">Face</button><button data-ms-edit="addvertex" class="${editMode==='addvertex'?'active':''}">Multi-Cut</button>${editTools}<div class="ms-spacer"></div><button data-ms-focus title="Focus selection (F)">Focus</button><select data-ms-display style="width:88px"><option value="shaded" ${displayMode==='shaded'?'selected':''}>Shaded</option><option value="wire" ${displayMode==='wire'?'selected':''}>Wire</option></select><select data-ms-view-select style="width:92px"><option value="iso" ${cam.mode==='iso'?'selected':''}>Iso</option><option value="front" ${cam.mode==='front'?'selected':''}>Front</option><option value="back" ${cam.mode==='back'?'selected':''}>Back</option><option value="left" ${cam.mode==='left'?'selected':''}>Left</option><option value="right" ${cam.mode==='right'?'selected':''}>Right</option><option value="top" ${cam.mode==='top'?'selected':''}>Top</option><option value="free" ${cam.mode==='free'?'selected':''}>Free</option></select><button data-ms-uv-toggle class="${uvOpen?'active':''}">UV</button></div><div class="ms-viewport"><canvas data-ms-preview style="cursor:${editMode==='addvertex'?'crosshair':'default'}"></canvas></div><section class="ms-uv"><div class="ms-uv-head"><b>UV Workspace</b><select data-ms-ts>${tsOpts}</select><span data-ms-atlas-info style="color:var(--ms-muted);overflow:hidden;text-overflow:ellipsis;white-space:nowrap;flex:1"></span><label style="display:flex;align-items:center;gap:5px">Zoom<select data-ms-atlas-zoom style="width:72px"><option value=".5" ${atlasZoom===.5?'selected':''}>50%</option><option value="1" ${atlasZoom===1?'selected':''}>100%</option><option value="1.5" ${atlasZoom===1.5?'selected':''}>150%</option><option value="2" ${atlasZoom===2?'selected':''}>200%</option></select></label></div><div class="ms-uv-body"><div class="ms-uv-pane"><div class="ms-uv-pane-head">Texture source · drag to choose pixels/tiles</div><div class="ms-uv-pane-scroll"><canvas data-ms-atlas></canvas></div></div><div class="ms-uv-pane"><div class="ms-uv-pane-head"><span>UV Layout · drag island / corner</span><span style="flex:1"></span><button data-ms-uv-fit>Fit</button><button data-ms-uv-rot>90°</button><button data-ms-uv-flip-u>Flip U</button><button data-ms-uv-flip-v>Flip V</button></div><div class="ms-uv-pane-scroll"><canvas data-ms-uv-layout></canvas></div></div></div></section></main>
          <aside class="ms-inspector"><div><div style="padding:9px 9px 3px"><label>Model<input data-ms-name value="${escapeHtml(m.name)}"></label></div><div class="ms-model-meta">${m.width}×${m.height} tiles · ${modelHeight.toFixed(2)} high · ${m.parts?.length||0} parts</div><div class="ms-tabs"><button data-ms-inspector-tab="transform" class="${inspectorTab==='transform'?'active':''}">Transform</button><button data-ms-inspector-tab="material" class="${inspectorTab==='material'?'active':''}">Material</button><button data-ms-inspector-tab="collision" class="${inspectorTab==='collision'?'active':''}">Collision</button></div></div><div class="ms-inspect-scroll">${inspectorPanel}</div></aside>
        </div></div>`;
      // contextual UI controls
      for(const b of body.querySelectorAll('[data-ms-inspector-tab]')) b.addEventListener('click',()=>{inspectorTab=b.getAttribute('data-ms-inspector-tab')||'transform';render();});
      for(const b of body.querySelectorAll('[data-ms-uv-toggle]')) b.addEventListener('click',()=>{uvOpen=!uvOpen;if(uvOpen)inspectorTab='material';render();});
      body.querySelector('[data-ms-view-select]')?.addEventListener('change',e=>{const v=e.target.value;cam.mode=v;if(v==='iso'){cam.yaw=45;cam.pitch=28;}else if(v==='front'){cam.yaw=0;cam.pitch=0;}else if(v==='back'){cam.yaw=180;cam.pitch=0;}else if(v==='left'){cam.yaw=-90;cam.pitch=0;}else if(v==='right'){cam.yaw=90;cam.pitch=0;}else if(v==='top'){cam.yaw=0;cam.pitch=90;}queuePreview();});
      // model controls
      for(const b of body.querySelectorAll('[data-ms-model]'))b.onclick=()=>{state.modelSelectedId=b.getAttribute('data-ms-model');state.modelBrushId=state.modelSelectedId;selectedPartId=null;selectedVertexKeys.clear();render();};
      body.querySelector('[data-ms-new]')?.addEventListener('click',()=>{createModel(ctx);selectedPartId=null;render();});
      body.querySelector('[data-ms-from]')?.addEventListener('click',()=>void createModelFromMapSelection(ctx).then(()=>{selectedPartId=null;render();}));
      body.querySelector('[data-ms-del-model]')?.addEventListener('click',()=>{if(state.modelSelectedId)deleteModel(ctx,state.modelSelectedId);selectedPartId=null;render();});
      body.querySelector('[data-ms-dup-model]')?.addEventListener('click',()=>{const g=getGeo(),m=getModel();if(!g||!m)return;const id=nextModelId(g),cp=deepClone(m);cp.id=id;cp.name=`${m.name} copy`;g.models[id]=normalizeModelTemplate(cp,id);state.modelSelectedId=id;state.modelBrushId=id;selectedPartId=null;persist(true);});
      body.querySelector('[data-ms-import-bb]')?.addEventListener('click',()=>void importBlockbenchModel(ctx).then(mm=>{if(mm){selectedPartId=mm.parts?.[0]?.id||null;render();}}));
      body.querySelector('[data-ms-reload-bb]')?.addEventListener('click',()=>{const mm=getModel();if(mm)void reloadLinkedBlockbenchModel(ctx,mm.id).then(n=>{if(n){selectedPartId=n.parts?.[0]?.id||null;render();}});});body.querySelector('[data-ms-reload-tex]')?.addEventListener('click',()=>{state.preview.modelImages.clear();void ensureExternalModelTextures(ctx,currentGeo(ctx),true).then(()=>{queuePreview();ctx.ui.showToast?.({message:'Texturas de Graphics/Models recargadas.',level:'info'});});});
      body.querySelector('[data-ms-quality]')?.addEventListener('change',e=>{const mm=getModel();if(!mm)return;mm.runtime_quality=e.target.value==='original'?'original':'pixel-low';persist(true);});
      body.querySelector('[data-ms-name]')?.addEventListener('change',e=>{const mm=getModel();if(mm){mm.name=e.target.value||mm.name;persist(true);}});body.querySelector('[data-ms-model-collision]')?.addEventListener('change',e=>{const mm=getModel();if(mm){mm.collision=e.target.value;persist();}});
      for(const b of body.querySelectorAll('[data-ms-add]'))b.onclick=()=>addPart(b.getAttribute('data-ms-add'));
      for(const b of body.querySelectorAll('[data-ms-part]'))b.onclick=()=>{selectedPartId=b.getAttribute('data-ms-part');selectedVertexKeys.clear();selectedFaceIndices.clear();selectedEdgeKeys.clear();render();};
      body.querySelector('[data-ms-dup-part]')?.addEventListener('click',duplicatePart);body.querySelector('[data-ms-del-part]')?.addEventListener('click',deletePart);for(const b of body.querySelectorAll('[data-ms-mirror]'))b.addEventListener('click',()=>mirrorPart(b.getAttribute('data-ms-mirror')));
      body.querySelector('[data-ms-part-name]')?.addEventListener('change',e=>{const pp=getPart();if(pp){pp.name=e.target.value||pp.name;persist(true);}});
      for(const el of body.querySelectorAll('[data-ms-pos]'))el.addEventListener('change',e=>{const pp=getPart();if(!pp)return;pp.position[el.getAttribute('data-ms-pos')]=Number(e.target.value)||0;persist();});
      for(const el of body.querySelectorAll('[data-ms-size]'))el.addEventListener('change',e=>{const pp=getPart();if(!pp)return;pp.size[el.getAttribute('data-ms-size')]=Math.max(.05,Math.abs(Number(e.target.value)||.05));if(pp.collision_shape?.mode!=='manual')pp.collision_shape={mode:'auto',size:{...pp.size},offset:{x:0,y:0,z:0}};persist();});
      body.querySelector('[data-ms-fit-texture]')?.addEventListener('click',()=>{const pp=getPart();if(!pp)return;if(!atlasSelection){ctx.ui.showToast?.({message:'Selecciona primero uno o varios tiles en la paleta.',level:'info'});return;}fitPartToAtlas(pp);persist(true);});
      for(const el of body.querySelectorAll('[data-ms-angle]'))el.addEventListener('change',e=>{const pp=getPart();if(!pp)return;pp.angle[el.getAttribute('data-ms-angle')]=Number(e.target.value)||0;persist();});
      body.querySelector('[data-ms-axis]')?.addEventListener('change',e=>{const pp=getPart();if(pp){pp.axis=e.target.value;persist();}});body.querySelector('[data-ms-segments]')?.addEventListener('change',e=>{const pp=getPart();if(pp){pp.segments=Math.max(4,Math.min(24,Math.round(Number(e.target.value)||8)));persist();}});body.querySelector('[data-ms-subdiv]')?.addEventListener('change',e=>{const pp=getPart();if(pp){pp.subdivisions=Math.max(1,Math.min(8,Math.round(Number(e.target.value)||1)));selectedVertexKeys.clear();persist();}});body.querySelector('[data-ms-collision]')?.addEventListener('change',e=>{const pp=getPart();if(pp){pp.collision=!!e.target.checked;persist();}});body.querySelector('[data-ms-collision-mode]')?.addEventListener('change',e=>{const pp=getPart();if(!pp)return;const wasManual=pp.collision_shape?.mode==='manual';pp.collision_shape=normalizeCollisionShape(pp.collision_shape,pp.size);pp.collision_shape.mode=e.target.value==='manual'?'manual':'auto';if(pp.collision_shape.mode==='manual'&&!wasManual){pp.collision_shape.size={...pp.size};pp.collision_shape.offset={x:0,y:0,z:0};}persist(true);});for(const el of body.querySelectorAll('[data-ms-col-size]'))el.addEventListener('change',e=>{const pp=getPart();if(!pp)return;pp.collision_shape=normalizeCollisionShape(pp.collision_shape,pp.size);pp.collision_shape.mode='manual';pp.collision_shape.size[el.getAttribute('data-ms-col-size')]=Math.max(.05,Math.abs(Number(e.target.value)||.05));persist();});for(const el of body.querySelectorAll('[data-ms-col-off]'))el.addEventListener('change',e=>{const pp=getPart();if(!pp)return;pp.collision_shape=normalizeCollisionShape(pp.collision_shape,pp.size);pp.collision_shape.mode='manual';pp.collision_shape.offset[el.getAttribute('data-ms-col-off')]=Number(e.target.value)||0;persist();});body.querySelector('[data-ms-fit-collision]')?.addEventListener('click',()=>{const pp=getPart();if(!pp)return;pp.collision_shape=fitPartCollisionToVisual(pp);persist(true);});body.querySelector('[data-ms-reset-vertices]')?.addEventListener('click',()=>{const pp=getPart();if(!pp)return;pp.vertex_offsets={};selectedVertexKeys.clear();persist();});body.querySelector('[data-ms-reset-topology]')?.addEventListener('click',()=>{const pp=getPart();if(!pp)return;pp.custom_faces=null;pp.vertex_offsets={};selectedVertexKeys.clear();persist(true);});for(const rb of body.querySelectorAll('[data-ms-place-rot]'))rb.addEventListener('click',()=>{state.modelRotation=normalizeModelPlacementRotation((Number(state.modelRotation)||0)+(Number(rb.getAttribute('data-ms-place-rot'))||0));const inp=body.querySelector('[data-ms-place-rot-input]');if(inp)inp.value=String(state.modelRotation);state.panelRefresh?.();queuePreview();});body.querySelector('[data-ms-place-rot-input]')?.addEventListener('change',e=>{state.modelRotation=normalizeModelPlacementRotation(e.target.value);e.target.value=String(state.modelRotation);state.panelRefresh?.();queuePreview();});body.querySelector('[data-ms-enter-vertex]')?.addEventListener('click',()=>{editMode=editMode==='vertex'?'object':'vertex';selectedVertexKeys.clear();selectedFaceIndices.clear();selectedEdgeKeys.clear();render();});body.querySelector('[data-ms-soft]')?.addEventListener('change',e=>{softRadius=Math.max(0,Math.min(8,Number(e.target.value)||0));queuePreview();});
      body.querySelector('[data-ms-undo]')?.addEventListener('click',undoModel);body.querySelector('[data-ms-redo]')?.addEventListener('click',redoModel);
      for(const b of body.querySelectorAll('[data-ms-ctool]'))b.onclick=()=>{componentTool=b.getAttribute('data-ms-ctool')||'move';render();};
      body.querySelector('[data-ms-snap]')?.addEventListener('change',e=>{transformSnap=Math.max(.001,Number(e.target.value)||.025);});
      body.querySelector('[data-ms-cut-mode]')?.addEventListener('change',e=>{cutMode=['u','v'].includes(e.target.value)?e.target.value:'cross';cutHover=null;queuePreview();});body.querySelector('[data-ms-cut-snap]')?.addEventListener('change',e=>{cutSnap=Math.max(0,Number(e.target.value)||0);cutHover=null;queuePreview();});
      body.querySelector('[data-ms-extrude]')?.addEventListener('click',()=>{extrudeSelectedFaces(.08);vertexAxis='normal';componentTool='move';render();});body.querySelector('[data-ms-subdivide]')?.addEventListener('click',()=>splitSelectedFacesUV(.5,.5,'Subdivide faces'));body.querySelector('[data-ms-loop-u]')?.addEventListener('click',()=>splitSelectedFacesAxis('u',.5));body.querySelector('[data-ms-loop-v]')?.addEventListener('click',()=>splitSelectedFacesAxis('v',.5));body.querySelector('[data-ms-weld]')?.addEventListener('click',weldSelectedVertices);
      body.querySelector('[data-ms-inset]')?.addEventListener('click',()=>insetSelectedFaces(.75));body.querySelector('[data-ms-bevel]')?.addEventListener('click',bevelSelectedFaces);body.querySelector('[data-ms-dup-face]')?.addEventListener('click',duplicateSelectedFaces);body.querySelector('[data-ms-flip-face]')?.addEventListener('click',flipSelectedFaces);body.querySelector('[data-ms-delete-face]')?.addEventListener('click',deleteSelectedFaces);
      body.querySelector('[data-ms-apply-selected]')?.addEventListener('click',()=>{applyMaterialToSelectedFaces();if(uvOpen)ensureUvEditor();});body.querySelector('[data-ms-clear-selected-face]')?.addEventListener('click',()=>{clearSelectedFaceMaterials();if(uvOpen)ensureUvEditor();});for(const b of body.querySelectorAll('[data-ms-apply]'))b.onclick=()=>applyMaterial(b.getAttribute('data-ms-apply'));body.querySelector('[data-ms-texture-mode]')?.addEventListener('change',e=>{const pp=getPart();if(!pp)return;pp.texture_mode=e.target.value==='stretch'?'stretch':'repeat';pp.repeat=pp.texture_mode!=='stretch';persist(true);});body.querySelector('[data-ms-clear-mat]')?.addEventListener('click',()=>clearMaterial('all'));
      for(const b of body.querySelectorAll('[data-ms-face-row]'))b.addEventListener('click',e=>{const idx=Number(b.getAttribute('data-ms-face-row'));if(!Number.isInteger(idx))return;if(!(e.shiftKey||e.ctrlKey||e.metaKey))selectedFaceIndices.clear();if(selectedFaceIndices.has(idx)&&(e.shiftKey||e.ctrlKey||e.metaKey))selectedFaceIndices.delete(idx);else selectedFaceIndices.add(idx);editMode='face';selectedEdgeKeys.clear();rebuildSelectedFaceVertices();render();});
      body.querySelector('[data-ms-focus]')?.addEventListener('click',()=>{cam.panX=0;cam.panY=0;cam.zoom=1;queuePreview();});body.querySelector('[data-ms-display]')?.addEventListener('change',e=>{displayMode=e.target.value==='wire'?'wire':'shaded';queuePreview();});
      // atlas
      const atlas=body.querySelector('[data-ms-atlas]');atlas?.addEventListener('pointerdown',e=>{if(e.button!==0)return;const p0=atlasPos(atlas,e);if(!p0)return;e.preventDefault();atlasDrag=p0;atlasSelection=normalizeRect(p0,p0);drawAtlas();atlas.setPointerCapture?.(e.pointerId);});atlas?.addEventListener('pointermove',e=>{if(!atlasDrag||(e.buttons&1)===0)return;const p0=atlasPos(atlas,e);if(!p0)return;atlasSelection=normalizeRect(atlasDrag,p0);drawAtlas();drawPartThumb();});const endAtlas=()=>{atlasDrag=null;drawAtlas();drawPartThumb();};atlas?.addEventListener('pointerup',endAtlas);atlas?.addEventListener('pointercancel',endAtlas);atlas?.addEventListener('dblclick',()=>applyMaterial('all'));body.querySelector('[data-ms-ts]')?.addEventListener('change',e=>void loadAtlas(e.target.value));body.querySelector('[data-ms-atlas-zoom]')?.addEventListener('change',e=>{atlasZoom=Math.max(.5,Math.min(2,Number(e.target.value)||1));drawAtlas();});
      const uvCv=body.querySelector('[data-ms-uv-layout]');
      const uvPoint=e=>{if(!uvCv)return null;const r=uvCv.getBoundingClientRect();return{x:(e.clientX-r.left)*(uvCv.width/Math.max(1,r.width)),y:(e.clientY-r.top)*(uvCv.height/Math.max(1,r.height))};};
      const uvPick=(pt)=>{const p=getPart();if(!p||!uvImage||!pt)return null;const fs=ensureCustomFaces(p);let hit=null;for(let i=fs.length-1;i>=0;i--){if(faceUvImageKey(fs[i])!==uvImageKey)continue;const r=faceAbsUvRect(fs[i],uvImage);if(!r)continue;const handles=[[r.x,r.y,'nw'],[r.x+r.w,r.y,'ne'],[r.x+r.w,r.y+r.h,'se'],[r.x,r.y+r.h,'sw']];for(const [hx,hy,h] of handles)if(Math.hypot(pt.x-hx,pt.y-hy)<=8)return{idx:i,rect:r,handle:h};if(pt.x>=r.x&&pt.x<=r.x+r.w&&pt.y>=r.y&&pt.y<=r.y+r.h){hit={idx:i,rect:r,handle:'move'};break;}}return hit;};
      uvCv?.addEventListener('pointerdown',e=>{if(e.button!==0||!uvImage)return;const pt=uvPoint(e),hit=uvPick(pt);if(!hit)return;e.preventDefault();uvCv.setPointerCapture?.(e.pointerId);if(!(e.shiftKey||e.ctrlKey||e.metaKey)){selectedFaceIndices.clear();selectedFaceIndices.add(hit.idx);}else if(!selectedFaceIndices.has(hit.idx))selectedFaceIndices.add(hit.idx);const fs=ensureCustomFaces(getPart()),items=[];for(const idx of selectedFaceIndices){if(faceUvImageKey(fs[idx])!==uvImageKey)continue;const r=faceAbsUvRect(fs[idx],uvImage);if(r)items.push({idx,rect:{...r}});}syncHistory();uvDrag={start:pt,mode:hit.handle,picked:hit.idx,items};drawUvEditor();queuePreview();});
      uvCv?.addEventListener('pointermove',e=>{if(!uvDrag||!uvImage||(e.buttons&1)===0)return;const pt=uvPoint(e),dx=pt.x-uvDrag.start.x,dy=pt.y-uvDrag.start.y,fs=ensureCustomFaces(getPart());for(const item of uvDrag.items){let r={...item.rect};if(uvDrag.mode==='move'){r.x+=dx;r.y+=dy;}else if(item.idx===uvDrag.picked){if(uvDrag.mode.includes('w')){r.x+=dx;r.w-=dx;}if(uvDrag.mode.includes('e'))r.w+=dx;if(uvDrag.mode.includes('n')){r.y+=dy;r.h-=dy;}if(uvDrag.mode.includes('s'))r.h+=dy;}r.w=Math.max(1,r.w);r.h=Math.max(1,r.h);setFaceAbsUvRect(fs[item.idx],uvImage,r);}getPart().custom_faces=fs;meshCache.dirty=true;drawUvEditor();queuePreview();});
      const endUv=()=>{if(!uvDrag)return;uvDrag=null;persist(false,false,'Edit UV');drawUvEditor();};uvCv?.addEventListener('pointerup',endUv);uvCv?.addEventListener('pointercancel',endUv);
      body.querySelector('[data-ms-uv-fit]')?.addEventListener('click',()=>{const p=getPart(),fs=p?ensureCustomFaces(p):[];if(!p||!selectedFaceIndices.size)return;for(const idx of selectedFaceIndices){const f=fs[idx];if(!f)continue;if(atlasSelection){f.material=deepClone(materialFromAtlas());f.uv_rect=[0,0,1,1];f.material_repeat=false;}else f.uv_rect=[0,0,1,1];}p.custom_faces=fs;persist(false,false,'Fit UV');ensureUvEditor();});
      body.querySelector('[data-ms-uv-rot]')?.addEventListener('click',()=>{const p=getPart(),fs=p?ensureCustomFaces(p):[];for(const idx of selectedFaceIndices){const f=fs[idx];if(!f?.material)continue;f.material.rotation=((Number(f.material.rotation)||0)+90)%360;}if(p){p.custom_faces=fs;persist(false,false,'Rotate UV');ensureUvEditor();}});
      body.querySelector('[data-ms-uv-flip-u]')?.addEventListener('click',()=>{const p=getPart(),fs=p?ensureCustomFaces(p):[];for(const idx of selectedFaceIndices){const f=fs[idx];if(!f?.material)continue;f.material.flip_h=!f.material.flip_h;}if(p){p.custom_faces=fs;persist(false,false,'Flip UV U');ensureUvEditor();}});
      body.querySelector('[data-ms-uv-flip-v]')?.addEventListener('click',()=>{const p=getPart(),fs=p?ensureCustomFaces(p):[];for(const idx of selectedFaceIndices){const f=fs[idx];if(!f?.material)continue;f.material.flip_v=!f.material.flip_v;}if(p){p.custom_faces=fs;persist(false,false,'Flip UV V');ensureUvEditor();}});
      // Unity-like viewport: Alt+LMB or RMB orbit, MMB pan, wheel zoom.
      // Selection is separate from transforms; W/E/R gizmos perform edits.
      const pv=body.querySelector('[data-ms-preview]');
      const previewCoords=e=>{const r=pv.getBoundingClientRect();return{x:e.clientX-r.left,y:e.clientY-r.top};};
      const pickVertexAt=(x,y)=>{let hit=null,best=Infinity;for(const v of previewVertices){const d=Math.hypot(v.x-x,v.y-y);if(d<best&&d<=11){best=d;hit=v;}}return hit;};
      const pickFaceAt=(x,y)=>{const hits=previewHits.filter(h=>x>=h.x0&&x<=h.x1&&y>=h.y0&&y<=h.y1);if(!hits.length)return null;hits.sort((a,b)=>a.depth-b.depth);return hits[hits.length-1];};
      const pickPartAt=(x,y)=>pickFaceAt(x,y)?.part_id||null;
      const segDist=(px,py,a,b)=>{const vx=b.x-a.x,vy=b.y-a.y,den=vx*vx+vy*vy||1,t=Math.max(0,Math.min(1,((px-a.x)*vx+(py-a.y)*vy)/den)),qx=a.x+vx*t,qy=a.y+vy*t;return Math.hypot(px-qx,py-qy);};
      const edgeKey=(a,b)=>[String(a),String(b)].sort().join('|');
      const pickEdgeAt=(x,y)=>{let best=null,bd=9;for(const h of previewHits){if(h.part_id!==selectedPartId)continue;const ks=h.f.vertex_keys||[];for(let i=0;i<4;i++){const j=(i+1)%4;if(!ks[i]||!ks[j])continue;const d=segDist(x,y,h.pts[i],h.pts[j]);if(d<bd){bd=d;best={key:edgeKey(ks[i],ks[j]),a:ks[i],b:ks[j],hit:h};}}}return best;};
      const selectFaceHit=(fh,toggle)=>{if(!fh)return false;selectedPartId=fh.part_id;const pp=getPart();if(!pp)return false;ensureCustomFaces(pp);const idx=Number.isInteger(fh.f.custom_face_index)?fh.f.custom_face_index:(Number(fh.f.part_face_index)||0);if(!toggle)selectedFaceIndices.clear();if(toggle&&selectedFaceIndices.has(idx))selectedFaceIndices.delete(idx);else selectedFaceIndices.add(idx);selectedEdgeKeys.clear();rebuildSelectedFaceVertices();return true;};
      const beginGizmoDrag=(axis,e)=>{const pp=getPart();if(!pp)return;vertexAxis=axis;syncHistory();if(editMode==='object'){vertexDrag={kind:'object',x:e.clientX,y:e.clientY,objectBase:{position:deepClone(pp.position),size:deepClone(pp.size),angle:deepClone(pp.angle)},label:`${componentTool} ${axis}`};}else if(selectedVertexKeys.size){vertexDrag={kind:'component',x:e.clientX,y:e.clientY,base:deepClone(pp.vertex_offsets||{}),snap:transformSnap,label:`${componentTool} ${axis}`};}queuePreview();};
      pv?.addEventListener('pointerdown',e=>{if(![0,1,2].includes(e.button))return;e.preventDefault();pv.setPointerCapture?.(e.pointerId);const pos=previewCoords(e);
        if(e.button===2||(e.button===0&&e.altKey)){previewDrag={x:e.clientX,y:e.clientY,yaw:cam.yaw,pitch:cam.pitch,moved:false};return;}
        if(e.button===1){cameraDrag={x:e.clientX,y:e.clientY,panX:cam.panX||0,panY:cam.panY||0};return;}
        const ga=pickGizmoAt(pos.x,pos.y);if(ga){beginGizmoDrag(ga,e);return;}
        if(editMode==='addvertex'){const fh=pickFaceAt(pos.x,pos.y);if(fh){selectedPartId=fh.part_id;splitFaceAtVertex(fh,pos.x,pos.y);}return;}
        const toggle=e.shiftKey||e.ctrlKey||e.metaKey;
        if(editMode==='face'){const fh=pickFaceAt(pos.x,pos.y);if(fh&&selectFaceHit(fh,toggle)){vertexAxis=selectedFaceIndices.size?'normal':vertexAxis;render();}return;}
        if(editMode==='edge'){const eh=pickEdgeAt(pos.x,pos.y);if(eh){if(!toggle){selectedEdgeKeys.clear();selectedVertexKeys.clear();}if(toggle&&selectedEdgeKeys.has(eh.key)){selectedEdgeKeys.delete(eh.key);selectedVertexKeys.delete(eh.a);selectedVertexKeys.delete(eh.b);}else{selectedEdgeKeys.add(eh.key);selectedVertexKeys.add(eh.a);selectedVertexKeys.add(eh.b);}selectedFaceIndices.clear();render();}return;}
        if(editMode==='vertex'){const hit=pickVertexAt(pos.x,pos.y);if(hit){if(toggle){if(selectedVertexKeys.has(hit.key))selectedVertexKeys.delete(hit.key);else selectedVertexKeys.add(hit.key);}else if(!selectedVertexKeys.has(hit.key)){selectedVertexKeys.clear();selectedVertexKeys.add(hit.key);}selectedFaceIndices.clear();selectedEdgeKeys.clear();render();return;}if(!toggle)selectedVertexKeys.clear();render();return;}
        const pid=pickPartAt(pos.x,pos.y);if(pid){selectedPartId=pid;selectedVertexKeys.clear();selectedFaceIndices.clear();selectedEdgeKeys.clear();render();}
      });
      pv?.addEventListener('pointermove',e=>{
        if(previewDrag){const dx=e.clientX-previewDrag.x,dy=e.clientY-previewDrag.y;if(Math.abs(dx)+Math.abs(dy)>2)previewDrag.moved=true;if(previewDrag.moved){cam.mode='free';cam.yaw=previewDrag.yaw+dx*.42;cam.pitch=Math.max(-85,Math.min(85,previewDrag.pitch-dy*.32));queuePreview();}return;}
        if(cameraDrag){cam.panX=cameraDrag.panX+(e.clientX-cameraDrag.x);cam.panY=cameraDrag.panY+(e.clientY-cameraDrag.y);queuePreview();return;}
        if(vertexDrag&&(e.buttons&1)){if(vertexDrag.kind==='object')applyObjectDrag(e.clientX-vertexDrag.x,e.clientY-vertexDrag.y);else applyComponentDrag(e.clientX-vertexDrag.x,e.clientY-vertexDrag.y);return;}
        if(editMode==='addvertex'){const pos=previewCoords(e),fh=pickFaceAt(pos.x,pos.y),q=fh?clickedQuadUV(fh,pos.x,pos.y):null,next=q?{part_id:fh.part_id,faceIndex:Number.isInteger(fh.f.custom_face_index)?fh.f.custom_face_index:(Number(fh.f.part_face_index)||0),u:q.u,v:q.v}:null;if(JSON.stringify(next)!==JSON.stringify(cutHover)){cutHover=next;queuePreview();}}
      });
      const endPreviewDrag=()=>{if(vertexDrag){const label=vertexDrag.label||'Transform';vertexDrag=null;persist(false,false,label);}const hadCamera=!!(previewDrag||cameraDrag);previewDrag=null;cameraDrag=null;if(hadCamera)queuePreview();};
      pv?.addEventListener('pointerup',endPreviewDrag);pv?.addEventListener('pointercancel',endPreviewDrag);
      pv?.addEventListener('wheel',e=>{e.preventDefault();const factor=Math.exp(-e.deltaY*.0012);cam.zoom=Math.max(.2,Math.min(8,cam.zoom*factor));queuePreview();},{passive:false});pv?.addEventListener('contextmenu',e=>e.preventDefault());
      for(const b of body.querySelectorAll('[data-ms-edit]'))b.onclick=()=>{const v=b.getAttribute('data-ms-edit');editMode=['vertex','edge','face','addvertex'].includes(v)?v:'object';selectedVertexKeys.clear();selectedFaceIndices.clear();selectedEdgeKeys.clear();render();};for(const b of body.querySelectorAll('[data-ms-vaxis]'))b.onclick=()=>{vertexAxis=b.getAttribute('data-ms-vaxis')||'view';render();};
      for(const b of body.querySelectorAll('[data-ms-view]'))b.onclick=()=>{const v=b.getAttribute('data-ms-view');cam.mode=v;if(v==='iso'){cam.yaw=45;cam.pitch=28;}else if(v==='front'){cam.yaw=0;cam.pitch=0;}else if(v==='back'){cam.yaw=180;cam.pitch=0;}else if(v==='left'){cam.yaw=-90;cam.pitch=0;}else if(v==='right'){cam.yaw=90;cam.pitch=0;}else if(v==='top'){cam.yaw=0;cam.pitch=90;}queuePreview();render();};for(const b of body.querySelectorAll('[data-ms-zoom]'))b.onclick=()=>{cam.zoom=Number(b.getAttribute('data-ms-zoom'))||1;queuePreview();};
      const place=()=>{const mm=getModel();if(!mm)return;state.modelBrushId=mm.id;state.modelSelectedId=mm.id;state.modelTool=false;state.modelEraseMode=false;state.sceneTool='select';state.studioTool='models';state.modelPlacementMode=true;state.modelInstanceSelectedId=null;ctx.editor.setTool(TOOL_ID);dialog.close();ctx.ui.openPanel(PREVIEW_PANEL_ID);state.previewPanelRefresh?.();state.panelRefresh?.();ctx.ui.showToast?.({message:`${mm.name}: haz clic directamente en el viewport 3D para colocarlo.`,level:'info'});};body.querySelector('[data-ms-place]')?.addEventListener('click',place);body.querySelector('[data-ms-map]')?.addEventListener('click',()=>{state.sceneTool='select';state.modelTool=false;ctx.editor.setTool(TOOL_ID);dialog.close();ctx.ui.openPanel(PREVIEW_PANEL_ID);state.previewPanelRefresh?.();state.panelRefresh?.();});
      body.tabIndex=0;body.focus({preventScroll:true});body.onkeydown=(e)=>{const k=String(e.key||'').toLowerCase();if((e.ctrlKey||e.metaKey)&&k==='z'){if(e.shiftKey)redoModel();else undoModel();e.preventDefault();return;}if((e.ctrlKey||e.metaKey)&&k==='y'){redoModel();e.preventDefault();return;}const tag=e.target?.tagName;if(tag==='INPUT'||tag==='SELECT'||tag==='TEXTAREA')return;if(k==='q'){editMode='object';render();e.preventDefault();}else if(k==='w'){componentTool='move';render();e.preventDefault();}else if(k==='e'){componentTool='rotate';render();e.preventDefault();}else if(k==='r'){componentTool='scale';render();e.preventDefault();}else if(k==='f'){cam.panX=0;cam.panY=0;cam.zoom=1;queuePreview();e.preventDefault();}else if(k==='1'){editMode='vertex';selectedVertexKeys.clear();selectedFaceIndices.clear();selectedEdgeKeys.clear();render();e.preventDefault();}else if(k==='2'){editMode='edge';selectedVertexKeys.clear();selectedFaceIndices.clear();selectedEdgeKeys.clear();render();e.preventDefault();}else if(k==='3'){editMode='face';selectedVertexKeys.clear();selectedFaceIndices.clear();selectedEdgeKeys.clear();render();e.preventDefault();}else if(k==='k'){editMode='addvertex';selectedVertexKeys.clear();selectedFaceIndices.clear();selectedEdgeKeys.clear();render();e.preventDefault();}else if((e.key==='Delete'||e.key==='Backspace')&&editMode==='face'){deleteSelectedFaces();e.preventDefault();}else if(e.key==='F9'){editMode='vertex';render();e.preventDefault();}else if(e.key==='F10'){editMode='edge';render();e.preventDefault();}else if(e.key==='F11'){editMode='face';render();e.preventDefault();}};
      queuePreview();drawPartThumb();drawMaterialButtons();if(uvOpen){drawAtlas();if(!atlasImage)void loadAtlas(atlasTilesetId);ensureUvEditor();}
    };
    render();return()=>{if(previewRaf)cancelAnimationFrame(previewRaf);renderToken++;const g=getGeo();if(g){clearTimeout(state.modelSaveTimer);state.modelSaveTimer=0;void saveMap(ctx,g.map_id,{skipCompile:true,skipModelCompile:true});}};
  }});return dialog;
}

// =============================================================================
// V2 Visual Workspace
// =============================================================================

function v2RuleForSelection(ctx) {
  const geo = currentGeo(ctx);
  const sel = state.sourceSelection;
  if (!geo || !sel) return null;
  const def = geo.definitions?.[sel.key];
  return def ? effectiveSourceRule(def, geo.instance_overrides?.[sel.instance_key]) : null;
}

function v2PresetLabel(name) {
  return simplePresetLabel(name === "elevation" ? "mountain" : name);
}

function v2PresetInternal(name) {
  return name === "elevation" ? "mountain" : name;
}

function v2SourceMaterial(desc) {
  return desc ? materialFromSourceDescriptor(desc) : null;
}

function v2DrawMaterialThumb(ctx, canvas, material, sourceKey = "") {
  if (!canvas) return;
  const c = canvas.getContext("2d");
  const W = canvas.width || 96, H = canvas.height || 96;
  c.clearRect(0, 0, W, H);
  c.fillStyle = getComputedStyle(document.documentElement).getPropertyValue("--canvas-bg").trim() || "#1b1e25";
  c.fillRect(0, 0, W, H);
  c.imageSmoothingEnabled = false;
  if (!material) {
    c.fillStyle = "rgba(255,255,255,.45)";
    c.font = "12px sans-serif";
    c.textAlign = "center";
    c.fillText("Sin gráfico", W / 2, H / 2);
    return;
  }
  const src = objectMaterialSource(ctx, { material, source_key: sourceKey });
  if (!src?.img) {
    c.fillStyle = "rgba(255,190,75,.7)";
    c.font = "11px sans-serif";
    c.textAlign = "center";
    c.fillText("Cargando…", W / 2, H / 2);
    return;
  }
  const pad = 7;
  const scale = Math.min((W - pad * 2) / src.sw, (H - pad * 2) / src.sh);
  const dw = Math.max(1, Math.round(src.sw * scale));
  const dh = Math.max(1, Math.round(src.sh * scale));
  c.drawImage(src.img, src.sx, src.sy, src.sw, src.sh,
    Math.round((W - dw) / 2), Math.round((H - dh) / 2), dw, dh);
  c.strokeStyle = "rgba(120,220,255,.55)";
  c.strokeRect(.5, .5, W - 1, H - 1);
}

function v2DrawSelectedThumbnail(ctx, host) {
  const canvas = host?.querySelector?.('[data-id="v2-selected-thumb"]');
  if (!canvas) return;
  const sel = state.sourceSelection;
  v2DrawMaterialThumb(ctx, canvas, v2SourceMaterial(sel), sel?.key || "");
}

function v2DrawPickedThumbnail(ctx, host) {
  const canvas = host?.querySelector?.('[data-id="v2-picked-thumb"]');
  if (!canvas) return;
  v2DrawMaterialThumb(ctx, canvas, state.visualSource?.material || null, state.visualSource?.source_key || "");
}

function v2DrawBrowserThumbs(ctx, host) {
  if (!host) return;
  const usage = state.sourceUsage;
  for (const canvas of host.querySelectorAll('canvas[data-v2-source-thumb]')) {
    const key = canvas.getAttribute('data-v2-source-thumb');
    const desc = usage?.placements?.find?.((p) => p.key === key) || null;
    v2DrawMaterialThumb(ctx, canvas, v2SourceMaterial(desc), desc?.key || "");
  }
}

function openGeometryGraphicPicker(ctx, options = {}) {
  return new Promise((resolve) => {
    const list = (ctx.tileset.list?.() || []).filter(t => Number(t?.id));
    const mapId = ctx.editor.activeMapId?.();
    const initialId = Number(options.tilesetId || ctx.tileset.currentId?.() || (mapId != null ? ctx.tileset.mapTilesetId?.(mapId) : 0) || list[0]?.id || 0);
    let activeId = initialId;
    let image = null;
    let selection = null;
    let dragStart = null;
    let zoom = 1;
    let finished = false;
    let dialog = null;

    const finish = (value) => {
      if (finished) return;
      finished = true;
      resolve(value || null);
      try { dialog?.close?.(); } catch (_) {}
    };

    dialog = ctx.ui.showCustomDialog({
      title: options.title || "2.5D Geometry · Selector de gráficos",
      width: "98vw",
      height: "95vh",
      render(body) {
        body.style.padding = "0";
        body.style.overflow = "hidden";
        body.innerHTML = `<div style="height:91vh;min-height:700px;display:grid;grid-template-columns:240px minmax(0,1fr) 300px;background:var(--bg-primary);color:var(--text-primary);font:13px inherit;">
          <aside style="border-right:1px solid var(--border);display:flex;flex-direction:column;min-width:0;">
            <div style="padding:10px 12px;border-bottom:1px solid var(--border);font-weight:700;">Tilesets</div>
            <div data-gp-list style="flex:1;overflow:auto;padding:7px;display:flex;flex-direction:column;gap:4px;">
              ${list.map(t=>`<button data-gp-ts="${Number(t.id)}" style="${buttonStyle(Number(t.id)===activeId)}text-align:left;width:100%;padding:8px;">${escapeHtml(t.name || t.tilesetName || `Tileset ${t.id}`)}<br><small style="color:var(--text-tertiary);">${escapeHtml(t.tilesetName || '')}</small></button>`).join('')}
            </div>
          </aside>
          <main style="display:flex;flex-direction:column;min-width:0;min-height:0;">
            <div style="padding:8px 10px;border-bottom:1px solid var(--border);display:flex;align-items:center;gap:7px;">
              <strong style="flex:1;">Arrastra para seleccionar uno o varios tiles</strong>
              <label>Zoom <select data-gp-zoom style="${selectStyle()}"><option value="0.5">50%</option><option value="1" selected>100%</option><option value="1.5">150%</option><option value="2">200%</option></select></label>
            </div>
            <div data-gp-scroll style="flex:1;overflow:auto;background:var(--canvas-bg);padding:18px;">
              <canvas data-gp-canvas style="display:block;image-rendering:pixelated;touch-action:none;box-shadow:0 0 0 1px var(--border);"></canvas>
            </div>
          </main>
          <aside style="border-left:1px solid var(--border);padding:12px;display:flex;flex-direction:column;gap:10px;overflow:auto;">
            <div style="font-weight:700;font-size:14px;display:flex;align-items:center;gap:8px;">Selección <button data-gp-use-top disabled style="${buttonStyle(true)}margin-left:auto;padding:7px 10px;">✓ Seleccionar</button></div>
            <canvas data-gp-preview width="260" height="260" style="width:100%;aspect-ratio:1;border:1px solid var(--border);border-radius:7px;background:var(--canvas-bg);image-rendering:pixelated;"></canvas>
            <div data-gp-info style="color:var(--text-secondary);line-height:1.5;">Selecciona un tile.</div>
            <div style="flex:1;"></div>
            <button data-gp-use disabled style="${buttonStyle(true)}font-size:14px;padding:10px 12px;position:sticky;bottom:0;">✓ Seleccionar</button>
          </aside>
        </div>`;
        const canvas = body.querySelector('[data-gp-canvas]');
        const preview = body.querySelector('[data-gp-preview]');
        const info = body.querySelector('[data-gp-info]');
        const use = body.querySelector('[data-gp-use]');
        const useTop = body.querySelector('[data-gp-use-top]');
        const zoomSel = body.querySelector('[data-gp-zoom]');

        const normalizeRect = (a,b) => {
          const x0=Math.min(a.x,b.x), y0=Math.min(a.y,b.y), x1=Math.max(a.x,b.x), y1=Math.max(a.y,b.y);
          return {x:x0*TILE_SIZE,y:y0*TILE_SIZE,w:(x1-x0+1)*TILE_SIZE,h:(y1-y0+1)*TILE_SIZE};
        };
        const draw = () => {
          const c=canvas.getContext('2d');
          if(!image){canvas.width=512;canvas.height=512;c.fillStyle='#181b22';c.fillRect(0,0,512,512);return;}
          canvas.width=image.width;canvas.height=image.height;
          canvas.style.width=`${Math.round(image.width*zoom)}px`;canvas.style.height=`${Math.round(image.height*zoom)}px`;
          c.imageSmoothingEnabled=false;c.clearRect(0,0,canvas.width,canvas.height);c.drawImage(image,0,0);
          c.save();c.strokeStyle='rgba(255,255,255,.12)';c.lineWidth=1;
          if(zoom>=1){for(let x=0;x<=canvas.width;x+=TILE_SIZE){c.beginPath();c.moveTo(x+.5,0);c.lineTo(x+.5,canvas.height);c.stroke();}for(let y=0;y<=canvas.height;y+=TILE_SIZE){c.beginPath();c.moveTo(0,y+.5);c.lineTo(canvas.width,y+.5);c.stroke();}}
          if(selection){c.fillStyle='rgba(80,220,255,.18)';c.fillRect(selection.x,selection.y,selection.w,selection.h);c.strokeStyle='rgba(80,235,255,.98)';c.lineWidth=Math.max(1,2/zoom);c.strokeRect(selection.x+.5,selection.y+.5,selection.w-1,selection.h-1);}
          c.restore();
          const pc=preview.getContext('2d');pc.imageSmoothingEnabled=false;pc.clearRect(0,0,preview.width,preview.height);pc.fillStyle='#181b22';pc.fillRect(0,0,preview.width,preview.height);
          if(selection){const sc=Math.min((preview.width-16)/selection.w,(preview.height-16)/selection.h);const dw=selection.w*sc,dh=selection.h*sc;pc.drawImage(image,selection.x,selection.y,selection.w,selection.h,(preview.width-dw)/2,(preview.height-dh)/2,dw,dh);info.innerHTML=`<b>${selection.w/TILE_SIZE} × ${selection.h/TILE_SIZE} tiles</b><br>Origen: ${selection.x}, ${selection.y}<br>Tileset ID: ${activeId}`;use.disabled=false;if(useTop)useTop.disabled=false;}else{info.textContent='Selecciona un tile.';use.disabled=true;if(useTop)useTop.disabled=true;}
        };
        const loadActive = async (id) => {
          activeId=Number(id)||0;selection=null;dragStart=null;image=null;draw();
          for(const b of body.querySelectorAll('[data-gp-ts]')){const on=Number(b.getAttribute('data-gp-ts'))===activeId;b.style.background=on?'var(--accent)':'var(--bg-secondary)';b.style.color=on?'var(--accent-text)':'var(--text-primary)';}
          const res=await ensureTilesetResourceSet(ctx,activeId);image=res?.image||state.preview.tilesetImages.get(activeId)||null;draw();
        };
        const pos = (ev) => {const r=canvas.getBoundingClientRect();if(!image||!r.width||!r.height)return null;const px=(ev.clientX-r.left)*(canvas.width/r.width),py=(ev.clientY-r.top)*(canvas.height/r.height);return{x:Math.max(0,Math.min(Math.floor((image.width-1)/TILE_SIZE),Math.floor(px/TILE_SIZE))),y:Math.max(0,Math.min(Math.floor((image.height-1)/TILE_SIZE),Math.floor(py/TILE_SIZE)))};};
        canvas.addEventListener('pointerdown',ev=>{if(ev.button!==0)return;const p=pos(ev);if(!p)return;canvas.setPointerCapture?.(ev.pointerId);dragStart=p;selection=normalizeRect(p,p);draw();});
        canvas.addEventListener('pointermove',ev=>{if(!dragStart||(ev.buttons&1)===0)return;const p=pos(ev);if(!p)return;selection=normalizeRect(dragStart,p);draw();});
        const end=()=>{dragStart=null;draw();};canvas.addEventListener('pointerup',end);canvas.addEventListener('pointercancel',end);
        for(const b of body.querySelectorAll('[data-gp-ts]')) b.addEventListener('click',()=>void loadActive(b.getAttribute('data-gp-ts')));
        zoomSel.addEventListener('change',()=>{zoom=Math.max(.5,Math.min(2,Number(zoomSel.value)||1));draw();});
        const confirmSelection=()=>{if(!selection)return;const ts=list.find(t=>Number(t.id)===activeId)||tilesetInfo(ctx,activeId)||{id:activeId};finish({tilesetId:activeId,tileset:ts,srcRect:{...selection}});};
        use.addEventListener('click',confirmSelection);
        useTop?.addEventListener('click',confirmSelection);
        canvas.addEventListener('dblclick',confirmSelection);
        void loadActive(activeId);
        return () => { if (!finished) { finished=true; resolve(null); } };
      }
    });
  });
}

async function v2ChooseGraphic(ctx) {
  const picked = await openGeometryGraphicPicker(ctx, { title: "2.5D Geometry · Elegir gráfico" });
  if (!picked?.srcRect?.w || !picked?.srcRect?.h) return;
  const match = picked.tileset || tilesetInfo(ctx, picked.tilesetId) || { id:picked.tilesetId };
  await ensureTilesetResourceSet(ctx, picked.tilesetId);
  const rect = {
    x: Math.max(0, Number(picked.srcRect.x) || 0),
    y: Math.max(0, Number(picked.srcRect.y) || 0),
    w: Math.max(TILE_SIZE, Number(picked.srcRect.w) || TILE_SIZE),
    h: Math.max(TILE_SIZE, Number(picked.srcRect.h) || TILE_SIZE),
  };
  state.visualSource = {
    label: match.tilesetName || match.name || `Tileset ${picked.tilesetId}`,
    tileset_id: Number(picked.tilesetId),
    source_key: `picked:ts:${Number(picked.tilesetId)}:${rect.x},${rect.y},${rect.w},${rect.h}`,
    material: {
      kind: "tileset", tileset_id: Number(picked.tilesetId), graphic: String(match.tilesetName || match.name || ""),
      src_rect: rect, rotation: 0, flip_h: false, flip_v: false, opacity: 255, hue: 0, saturation: 100, lighting: 0,
    },
    footprint: { w: Math.max(1, Math.round(rect.w / TILE_SIZE)), h: Math.max(1, Math.round(rect.h / TILE_SIZE)) },
  };
  state.visualSourceFootprint = { ...state.visualSource.footprint };
  state.sceneTool = "place";
  schedulePanelRefresh();
  ctx.ui.showToast?.({ message: `${state.visualSource.label}: haz clic en el mapa para colocarlo como Geometry.`, level: "info" });
}

function v2PlacePickedGraphic(ctx, mapId, x, y) {
  const geo = state.maps.get(mapId);
  const src = state.visualSource;
  if (!geo || !src?.material) {
    ctx.ui.showToast?.({ message: "Primero elige un gráfico.", level: "info" });
    return null;
  }
  const presetName = v2PresetInternal(state.brushPreset || "wall");
  const scenePreset = SCENE_GEOMETRY_PRESETS[presetName] || SCENE_GEOMETRY_PRESETS.wall;
  const w = Math.max(1, Number(src.footprint?.w) || 1);
  const h = Math.max(1, Number(src.footprint?.h) || 1);
  const id = nextObjectId(geo);
  const obj = normalizeObject({
    id,
    name: src.label || `Geometry ${id}`,
    type: scenePreset.type === "plane" ? "plane" : "cube",
    x: Math.round(x), y: Math.round(y), w, h,
    height: Math.max(0, Number(state.brushHeight) || Number(scenePreset.height) || 0),
    anchor_z: Number(scenePreset.anchor_z) || 0,
    anchor_row: Math.max(0, h - 1),
    rotation: 0,
    collision: scenePreset.collision || "solid",
    category: scenePreset.category || presetName,
    characters_in_front: false,
    footprint: {},
    components: { ...(scenePreset.components || {}), connect_neighbors: false },
    material: JSON.parse(JSON.stringify(src.material)),
  }, id);
  geo.objects ||= [];
  geo.objects.push(obj);
  state.objSelected = obj.id;
  state.sourceSelection = null;
  ctx.editor.requestRedraw();
  schedulePreview(ctx);
  void saveMap(ctx, mapId);
  state.panelRefresh?.();
  return obj;
}

async function v2SelectBrowserSource(ctx, key) {
  const usage = state.sourceUsage;
  const desc = usage?.placements?.find?.((p) => p.key === key) || null;
  if (!desc) return;
  state.sourceSelection = desc;
  state.preview.focusX = desc.x;
  state.preview.focusY = desc.y;
  state.objSelected = null;
  const geo = currentGeo(ctx);
  if (geo?.definitions?.[desc.key]) {
    const rule = effectiveSourceRule(geo.definitions[desc.key], geo.instance_overrides?.[desc.instance_key]);
    if (rule) {
      state.brushPreset = rule.category || state.brushPreset;
      state.brushHeight = Number(rule.height) || 0;
    }
  }
  await ensureTilesetResourceSet(ctx, desc.tileset_id);
  state.panelRefresh?.();
  ctx.editor.requestRedraw();
  schedulePreview(ctx);
}

function v2ToolButton(tool, icon, label) {
  const active = state.sceneTool === tool;
  return `<button data-v2-tool="${tool}" title="${label}" style="${buttonStyle(active)}height:52px;min-width:68px;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:3px;font-size:11px;"><span style="font-size:18px;line-height:18px;">${icon}</span>${label}</button>`;
}

function v2PresetCard(name, icon, label) {
  const internal = v2PresetInternal(name);
  const active = v2PresetInternal(state.brushPreset) === internal;
  return `<button data-v2-preset="${name}" style="${buttonStyle(active)}min-width:82px;flex:1 1 82px;height:58px;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:4px;"><span style="font-size:21px;">${icon}</span><span>${label}</span></button>`;
}

function v3ToolButton(tool, icon, label, hint='') {
  const active=state.sceneTool===tool;
  return `<button data-v2-tool="${tool}" title="${escapeHtml(hint||label)}" class="g-tool ${active?'active':''}"><span>${icon}</span><b>${label}</b></button>`;
}

function panelHtmlV3(ctx, geo) {
  const sel=state.sourceSelection&&Number(state.sourceSelection.map_id)===Number(geo?.map_id)?state.sourceSelection:null;
  const rule=v2RuleForSelection(ctx);
  const usage=state.sourceUsage&&Number(state.sourceUsage.map_id)===Number(geo?.map_id)?state.sourceUsage:null;
  const picked=state.visualSource;
  const activeHeight=rule?Number(rule.height)||0:Number(state.brushHeight)||0;
  const section=state.uiSection==='models'?'models':'terrain';
  const models=Object.values(geo?.models||{});
  const modelButtons=models.slice(0,10).map(m=>`<button data-v3-model="${escapeHtml(m.id)}" class="g-model ${m.id===state.modelSelectedId?'active':''}"><span>${escapeHtml(m.name)}</span><small>${m.parts?.length||0} parts</small></button>`).join('');
  const browserRows=state.uiAdvanced&&usage?.sources instanceof Map?[...usage.sources.values()].sort((a,b)=>b.count-a.count).slice(0,12).map(row=>`<button data-v2-browser-source="${escapeHtml(row.key)}" class="g-source"><canvas data-v2-source-thumb="${escapeHtml(row.key)}" width="54" height="54"></canvas><span>${escapeHtml(row.graphic||row.label||'Tile')}</span><small>×${row.count}</small></button>`).join(''):'';
  const selectedInfo=sel?`<div class="g-selection"><canvas data-id="v2-selected-thumb" width="72" height="72"></canvas><div><small>Selected tile</small><b>${escapeHtml(sel.graphic||sel.label||'Tile')}</b><span>${escapeHtml(sel.layer_name||`Layer ${sel.layer}`)}${rule?` · ${v2PresetLabel(rule.category)} · H${Number(rule.height)||0}`:''}</span></div></div>`:`<div class="g-empty">Select a tile on the map to edit its 2.5D properties.</div>`;
  const terrainContext=state.sceneTool==='terrain-slope'?`<div class="g-context"><div class="g-context-title">Slope</div><div class="g-fields"><label>Angle<input data-v2-terrain-angle type="number" min="-75" max="75" step="1" value="${Number(state.terrainAngle)||0}"></label><label>Direction<input data-v2-terrain-yaw type="number" min="0" max="359" step="1" value="${((Number(state.terrainYaw)||0)%360+360)%360}"></label></div><div class="g-dir"><button data-v2-terrain-dir="0">N</button><button data-v2-terrain-dir="90">E</button><button data-v2-terrain-dir="180">S</button><button data-v2-terrain-dir="270">W</button></div><small>Paint the slope directly with Maker Studio's current brush size.</small></div>`:
    ['raise','lower','paint'].includes(state.sceneTool)?`<div class="g-context"><div class="g-context-title">Height</div><div class="g-height"><button data-v2-action="height-minus">−</button><input data-id="v2-height" type="number" min="0" step=".25" value="${activeHeight}"><button data-v2-action="height-plus">+</button></div></div>`:'';
  const advanced=state.uiAdvanced?`<div class="g-advanced"><div class="g-card"><div class="g-card-title">Tile rule</div><div class="g-presets">${[['floor','▱','Floor'],['wall','▥','Wall'],['mountain','⛰','Mountain'],['prop','♟','Prop'],['roof','⌂','Roof'],['border','▤','Border']].map(([n,i,l])=>`<button data-v2-preset="${n}" class="${v2PresetInternal(state.brushPreset)===v2PresetInternal(n)?'active':''}">${i} ${l}</button>`).join('')}</div><div class="g-fields"><label>Scope<select data-v3-scope-select><option value="this" ${state.sceneScope==='this'?'selected':''}>This tile</option><option value="connected" ${state.sceneScope==='connected'?'selected':''}>Connected</option><option value="all" ${state.sceneScope==='all'?'selected':''}>All identical</option></select></label><label>Collision<select data-id="v2-collision"><option value="solid" ${rule?.collision==='solid'?'selected':''}>Solid</option><option value="climb" ${rule?.collision==='climb'?'selected':''}>Climb</option><option value="one-way" ${rule?.collision==='one-way'?'selected':''}>One-way</option><option value="none" ${rule?.collision==='none'?'selected':''}>None</option></select></label></div><div class="g-checks"><label><input data-id="v2-connect" type="checkbox" ${rule?.components?.connect_neighbors!==false?'checked':''}> Connect neighbors</label><label><input data-id="v2-cap" type="checkbox" ${rule?.components?.cap!==false?'checked':''}> Cap top</label></div></div><div class="g-card"><div class="g-card-title">Graphics</div><div class="g-actions"><button data-v2-action="pick-graphic">Choose graphic…</button><button data-v2-action="rescan">Rescan</button></div>${picked?`<div class="g-selection small"><canvas data-id="v2-picked-thumb" width="64" height="64"></canvas><div><small>Placement graphic</small><b>${escapeHtml(picked.label)}</b><span>${picked.footprint.w}×${picked.footprint.h} tiles</span><button data-v2-action="place-picked">Place</button></div></div>`:''}<div class="g-source-grid">${browserRows||'<small>No source browser loaded.</small>'}</div></div></div>`:'';

  return `<style>
  .g-root{height:100%;display:grid;grid-template-rows:auto auto minmax(0,1fr) auto;background:var(--bg-primary);color:var(--text-primary);font:12px Inter,system-ui,sans-serif}.g-root *{box-sizing:border-box}.g-head{display:flex;align-items:center;gap:8px;padding:10px 11px;border-bottom:1px solid var(--border);background:var(--bg-secondary)}.g-title{font-size:14px;font-weight:750}.g-chip{font-size:9px;padding:3px 6px;border-radius:999px;border:1px solid var(--border);color:var(--text-tertiary)}.g-tabs{display:grid;grid-template-columns:1fr 1fr;gap:5px;padding:8px;border-bottom:1px solid var(--border)}.g-tabs button,.g-root button{border:1px solid var(--border);background:var(--bg-secondary);color:var(--text-primary);border-radius:7px;padding:7px;cursor:pointer}.g-tabs button.active,.g-root button.active,.g-tool.active{border-color:var(--accent);background:#34251f}.g-scroll{overflow:auto;padding:9px}.g-tools{display:grid;grid-template-columns:repeat(3,1fr);gap:6px}.g-tool{height:58px;display:grid;place-items:center;gap:2px}.g-tool span{font-size:18px}.g-tool b{font-size:10px}.g-card,.g-context{margin-top:9px;border:1px solid var(--border);border-radius:9px;padding:9px;background:var(--bg-secondary)}.g-context-title,.g-card-title{font-weight:700;margin-bottom:7px}.g-fields{display:grid;grid-template-columns:1fr 1fr;gap:7px}.g-fields label{display:grid;gap:4px;color:var(--text-secondary);font-size:10px}.g-root input,.g-root select{width:100%;background:var(--bg-primary);color:var(--text-primary);border:1px solid var(--border);border-radius:6px;padding:6px}.g-dir{display:grid;grid-template-columns:repeat(4,1fr);gap:5px;margin-top:7px}.g-height{display:grid;grid-template-columns:34px 1fr 34px;gap:5px}.g-selection{display:grid;grid-template-columns:72px 1fr;gap:9px;align-items:center;margin-top:9px}.g-selection.small{grid-template-columns:64px 1fr}.g-selection canvas,.g-source canvas{image-rendering:pixelated;border:1px solid var(--border);border-radius:6px;background:var(--canvas-bg)}.g-selection div{min-width:0}.g-selection small,.g-selection b,.g-selection span{display:block}.g-selection b{overflow:hidden;text-overflow:ellipsis;white-space:nowrap;margin:2px 0}.g-selection span,.g-root small{color:var(--text-tertiary);font-size:10px}.g-empty{padding:22px 10px;text-align:center;color:var(--text-tertiary)}.g-footer{display:flex;gap:5px;padding:7px 9px;border-top:1px solid var(--border);background:var(--bg-secondary)}.g-footer button:first-child{margin-left:auto}.g-actions{display:grid;grid-template-columns:1fr 1fr;gap:6px}.g-presets{display:grid;grid-template-columns:1fr 1fr;gap:5px}.g-checks{display:grid;gap:5px;margin-top:8px}.g-checks label{display:flex;gap:6px;align-items:center;color:var(--text-secondary)}.g-checks input{width:auto}.g-source-grid{display:grid;grid-template-columns:repeat(3,1fr);gap:5px;margin-top:8px}.g-source{min-width:0;display:grid;justify-items:center;gap:3px}.g-source span{max-width:70px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;font-size:9px}.g-model-list{display:grid;gap:5px;margin-top:9px}.g-model{display:flex!important;align-items:center;justify-content:space-between;text-align:left}.g-model small{margin-left:8px}.g-model-hero{border:1px solid var(--border);border-radius:10px;padding:13px;background:var(--bg-secondary);margin-bottom:9px}.g-model-hero h3{margin:0 0 5px;font-size:14px}.g-model-hero p{margin:0;color:var(--text-tertiary);line-height:1.4}.g-advanced{margin-top:8px}
  </style><div class="g-root"><div class="g-head"><span class="g-title">2.5D Geometry</span><span class="g-chip">HYBRID 3.2</span><span style="flex:1"></span><button data-v3-advanced class="${state.uiAdvanced?'active':''}">Advanced</button></div><div class="g-tabs"><button data-v3-section="terrain" class="${section==='terrain'?'active':''}">Terrain</button><button data-v3-section="models" class="${section==='models'?'active':''}">Models</button></div><div class="g-scroll">${section==='terrain'?`<div class="g-tools">${v3ToolButton('select','⬉','Select')}${v3ToolButton('raise','↥','Raise')}${v3ToolButton('lower','↧','Lower')}${v3ToolButton('terrain-slope','◩','Slope')}${v3ToolButton('terrain-flat','▱','Flatten')}${v3ToolButton('erase','⌫','Erase')}</div>${terrainContext}${selectedInfo}${advanced}`:`<div class="g-model-hero"><h3>Special models only</h3><p>Use Terrain for slopes, cliffs and large surfaces. Open Model Studio only for props, bridges, buildings or unique low-poly shapes.</p></div><div class="g-actions"><button data-v2-action="model-workshop" class="active">Open Model Studio</button><button data-v2-action="model-from-selection">Model from selection</button></div><div class="g-card"><div class="g-card-title">Placement</div><div class="g-actions"><button data-v2-action="model-place" class="${state.sceneTool==='model-place'?'active':''}">Place selected model</button><div style="display:grid;grid-template-columns:36px 1fr 36px;gap:5px"><button data-v2-model-rot="-15">↶</button><div style="display:grid;place-items:center;border:1px solid var(--border);border-radius:6px">${normalizeModelPlacementRotation(state.modelRotation)}°</div><button data-v2-model-rot="15">↷</button></div></div></div><div class="g-model-list">${modelButtons||'<div class="g-empty">No models yet.</div>'}</div>${advanced}`}</div><div class="g-footer"><span style="color:var(--text-tertiary);display:flex;align-items:center">${section==='terrain'?'Tile-first terrain':'Low-poly model workflow'}</span><button data-v2-view="map" class="${state.viewMode==='2d'?'active':''}">Map</button><button data-v2-view="2.5d">2.5D Preview</button><button data-v2-view="split">Split</button></div></div>`;
}


function panelHtmlV340(ctx, geo) {
  const section=state.uiSection==='models'?'models':'terrain';
  const mapId=ctx.editor.activeMapId?.();
  const sel=currentTerrainSelection(ctx,geo); const stats=terrainSelectionStats(ctx,geo);
  const bs=Math.max(1,Math.round(Number(ctx.editor.brushSize?.())||1));
  const models=Object.values(geo?.models||{});
  const tool=(id,icon,label,sub='')=>`<button data-v2-tool="${id}" class="w-tool ${state.sceneTool===id?'active':''}"><span class="w-icon">${icon}</span><span><b>${label}</b>${sub?`<small>${sub}</small>`:''}</span></button>`;
  const dir=(v,l)=>`<button data-v2-terrain-dir="${v}" class="${Number(state.terrainYaw)===Number(v)?'active':''}">${l}</button>`;
  let toolSettings='';
  if(state.sceneTool==='raise'||state.sceneTool==='lower'){
    toolSettings=`<div class="w-card"><div class="w-card-head"><b>${state.sceneTool==='raise'?'Raise':'Lower'} terrain</b><small>Paint or apply to selection</small></div><div class="w-row"><label>Step<input data-g4-step type="number" min="0.01" step="0.05" value="${Number(state.terrainStep)||.25}"></label><span class="w-unit">height units</span></div>${sel?'<button data-g4-apply-selection class="w-wide primary">Apply to selected area</button>':''}</div>`;
  } else if(state.sceneTool==='terrain-slope'){
    toolSettings=`<div class="w-card"><div class="w-card-head"><b>Slope</b><small>Continuous plane, not per-tile blocks</small></div><div class="w-two"><label>Angle<input data-v2-terrain-angle type="number" min="-75" max="75" step="1" value="${Number(state.terrainAngle)||0}"></label><label>Base height<input data-g4-target-height type="number" min="0" step=".25" value="${Number(state.terrainTargetHeight)||0}"></label></div><div class="w-compass">${dir(0,'N')}${dir(90,'E')}${dir(180,'S')}${dir(270,'W')}</div>${sel?'<button data-g4-apply-selection class="w-wide primary">Slope selected area</button>':''}</div>`;
  } else if(state.sceneTool==='terrain-flat'){
    toolSettings=`<div class="w-card"><div class="w-card-head"><b>Level / Flatten</b><small>Use one exact height across the area</small></div><div class="w-row"><label>Height<input data-g4-target-height type="number" min="0" step=".25" value="${Number(state.terrainTargetHeight)||0}"></label><button data-g4-sample-height>Use selected</button></div>${sel?'<button data-g4-apply-selection class="w-wide primary">Flatten selected area</button>':''}</div>`;
  } else if(state.sceneTool==='erase'){
    toolSettings=`<div class="w-card danger"><div class="w-card-head"><b>Erase 2.5D terrain</b><small>Does not delete map tiles or models</small></div><p>Drag on the map, or erase only the selected area.</p>${sel?'<button data-g4-apply-selection class="w-wide danger-btn">Erase selected terrain</button>':''}</div>`;
  } else if(state.sceneTool==='select'){
    toolSettings=`<div class="w-card"><div class="w-card-head"><b>Select area</b><small>Drag a rectangle on the map</small></div><p>Selection is independent from tile graphics. Use it to edit exact heights, corners or apply a tool to a whole region.</p></div>`;
  }
  let selectionCard='';
  if(sel&&stats){
    const one=stats.count===1; const tc=one?terrainCellAt(geo,sel.x0,sel.y0):null;
    const step=Math.max(.001,Number(geo?.height_step)||DEFAULT_STEP);
    const base=one?(tc?.corners?.length===4?tc.corners:[stats.avg,stats.avg,stats.avg,stats.avg]):null;
    selectionCard=`<div class="w-card selection"><div class="w-card-head"><b>${one?`Cell ${sel.x0}, ${sel.y0}`:`Selected ${stats.w}×${stats.h}`}</b><button data-g4-clear-selection>Clear</button></div><div class="w-metrics"><span><small>Tiles</small><b>${stats.count}</b></span><span><small>Avg height</small><b>${stats.avg.toFixed(2)}</b></span><span><small>Range</small><b>${stats.min.toFixed(2)}–${stats.max.toFixed(2)}</b></span></div><div class="w-row"><label>Set exact height<input data-g4-selection-height type="number" min="0" step=".25" value="${stats.avg.toFixed(2)}"></label><button data-g4-set-height>Set</button></div>${one?`<div class="w-corners"><label>NW<input data-g4-corner="0" type="number" min="0" step=".25" value="${Number(base[0]).toFixed(2)}"></label><label>NE<input data-g4-corner="1" type="number" min="0" step=".25" value="${Number(base[1]).toFixed(2)}"></label><label>SW<input data-g4-corner="3" type="number" min="0" step=".25" value="${Number(base[3]).toFixed(2)}"></label><label>SE<input data-g4-corner="2" type="number" min="0" step=".25" value="${Number(base[2]).toFixed(2)}"></label></div><button data-g4-apply-corners class="w-wide">Apply corner heights</button>`:''}</div>`;
  } else {
    selectionCard=`<div class="w-card empty"><b>No area selected</b><p>Choose <strong>Select</strong>, then click or drag on the map. Terrain editing no longer depends on selecting a source graphic.</p></div>`;
  }
  const terrain=`<div class="w-toolbar">${tool('select','⌖','Select','area')}${tool('raise','＋','Raise','sculpt')}${tool('lower','−','Lower','sculpt')}${tool('terrain-slope','◢','Slope','angle')}${tool('terrain-flat','▬','Level','exact')}${tool('erase','⌫','Erase','terrain')}</div><div class="w-brush"><span>Brush <b>${bs}×${bs}</b></span><span>Map overlay <b>ON</b></span><span>Alt = erase</span></div>${toolSettings}${selectionCard}<details class="w-legacy"><summary>Legacy tile rules</summary><p>Old source-based Wall / Mountain / Prop rules are kept for compatibility, but they are no longer required for terrain sculpting.</p><button data-g4-pick-legacy>Select tile rule at selection</button></details>`;
  const modelButtons=models.map(m=>`<button data-v3-model="${escapeHtml(m.id)}" class="w-model ${m.id===state.modelSelectedId?'active':''}"><span><b>${escapeHtml(m.name)}</b><small>${m.parts?.length||0} parts</small></span><span>›</span></button>`).join('');
  const modelsHtml=`<div class="w-card hero"><b>Custom Models</b><p>Use models only for unique props/buildings. Terrain remains lightweight and parametric.</p><div class="w-two-buttons"><button data-v2-action="model-workshop" class="primary">Open Model Studio</button><button data-v2-action="model-from-selection">From map selection</button></div></div><div class="w-model-list">${modelButtons||'<div class="w-card empty"><b>No models yet</b><p>Create one in Model Studio or import a Blockbench model.</p></div>'}</div>${state.modelSelectedId?`<div class="w-card"><div class="w-card-head"><b>Placement</b><small>${normalizeModelPlacementRotation(state.modelRotation)}°</small></div><div class="w-model-place"><button data-v2-action="model-place" class="primary">Place selected</button><button data-v2-model-rot="-15">↶ 15°</button><button data-v2-model-rot="15">15° ↷</button></div></div>`:''}`;
  return `<style>
  .w-root{height:100%;display:grid;grid-template-rows:auto auto minmax(0,1fr) auto;background:var(--bg-primary);color:var(--text-primary);font:12px Inter,system-ui,sans-serif}.w-root *{box-sizing:border-box}.w-head{height:46px;padding:0 12px;display:flex;align-items:center;gap:8px;border-bottom:1px solid var(--border);background:var(--bg-secondary)}.w-head b{font-size:14px}.w-chip{font-size:9px;padding:3px 6px;border:1px solid var(--border);border-radius:999px;color:var(--text-tertiary)}.w-head .spacer{flex:1}.w-root button{border:1px solid var(--border);background:var(--bg-secondary);color:var(--text-primary);border-radius:7px;padding:7px 9px;cursor:pointer}.w-root button:hover{border-color:color-mix(in srgb,var(--accent) 55%,var(--border))}.w-root button.active,.w-root button.primary{border-color:var(--accent);background:color-mix(in srgb,var(--accent) 14%,var(--bg-secondary))}.w-tabs{display:grid;grid-template-columns:1fr 1fr;padding:7px 9px;gap:6px;border-bottom:1px solid var(--border)}.w-body{overflow:auto;padding:10px}.w-toolbar{display:grid;grid-template-columns:repeat(3,1fr);gap:6px}.w-tool{height:58px!important;display:flex;align-items:center;gap:8px;text-align:left!important;padding:7px!important}.w-icon{font-size:21px;width:24px;text-align:center}.w-tool b,.w-tool small{display:block}.w-tool small{font-size:9px;color:var(--text-tertiary);margin-top:1px}.w-brush{display:flex;gap:10px;flex-wrap:wrap;padding:7px 2px 1px;color:var(--text-tertiary);font-size:10px}.w-brush b{color:var(--text-secondary)}.w-card{margin-top:9px;padding:10px;border:1px solid var(--border);border-radius:9px;background:var(--bg-secondary)}.w-card p{margin:6px 0;color:var(--text-tertiary);line-height:1.45;font-size:10px}.w-card-head{display:flex;align-items:center;gap:8px;margin-bottom:8px}.w-card-head>b{font-size:12px}.w-card-head small{color:var(--text-tertiary)}.w-card-head button{margin-left:auto;padding:4px 7px}.w-row{display:grid;grid-template-columns:minmax(0,1fr) auto;gap:7px;align-items:end}.w-row label,.w-two label,.w-corners label{display:grid;gap:4px;font-size:10px;color:var(--text-secondary)}.w-root input,.w-root select{width:100%;border:1px solid var(--border);background:var(--bg-primary);color:var(--text-primary);border-radius:6px;padding:6px}.w-unit{padding-bottom:7px;color:var(--text-tertiary);font-size:10px}.w-two{display:grid;grid-template-columns:1fr 1fr;gap:7px}.w-compass{display:grid;grid-template-columns:repeat(4,1fr);gap:5px;margin-top:7px}.w-wide{width:100%;margin-top:8px}.w-card.danger{border-color:rgba(255,95,95,.45)}.danger-btn{border-color:rgba(255,95,95,.65)!important;color:#ffb7b7!important}.w-metrics{display:grid;grid-template-columns:repeat(3,1fr);gap:5px;margin-bottom:8px}.w-metrics span{padding:7px;border:1px solid var(--border);border-radius:6px;background:var(--bg-primary)}.w-metrics small,.w-metrics b{display:block}.w-metrics small{font-size:9px;color:var(--text-tertiary)}.w-metrics b{margin-top:2px;font-size:11px}.w-corners{display:grid;grid-template-columns:1fr 1fr;gap:6px;margin-top:8px}.w-card.empty{text-align:center;padding:18px 12px}.w-card.empty p{max-width:300px;margin:6px auto}.w-legacy{margin-top:9px;border:1px dashed var(--border);border-radius:8px;padding:8px;color:var(--text-secondary)}.w-legacy summary{cursor:pointer;font-weight:600}.w-legacy p{font-size:10px;color:var(--text-tertiary)}.w-model-list{display:grid;gap:5px;margin-top:8px}.w-model{display:flex!important;align-items:center;justify-content:space-between;text-align:left!important}.w-model span:first-child{min-width:0}.w-model b,.w-model small{display:block;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}.w-model small{font-size:9px;color:var(--text-tertiary)}.w-two-buttons,.w-model-place{display:grid;grid-template-columns:1fr 1fr;gap:6px;margin-top:8px}.w-model-place{grid-template-columns:1fr auto auto}.w-foot{height:44px;display:flex;align-items:center;gap:6px;padding:6px 9px;border-top:1px solid var(--border);background:var(--bg-secondary)}.w-foot span{font-size:10px;color:var(--text-tertiary);flex:1}.w-foot button{padding:6px 10px}
  </style><div class="w-root"><div class="w-head"><b>2.5D Workspace</b><span class="w-chip">CLEAN 4.0</span><span class="spacer"></span><button data-v2-view="2.5d">3D Preview</button></div><div class="w-tabs"><button data-v3-section="terrain" class="${section==='terrain'?'active':''}">Terrain</button><button data-v3-section="models" class="${section==='models'?'active':''}">Models</button></div><div class="w-body">${section==='terrain'?terrain:modelsHtml}</div><div class="w-foot"><span>${state.previewDirty?'3D preview is stale — map editing stays live':'3D preview up to date'}</span><button data-g4-save-runtime>Build Runtime</button></div></div>`;
}


function v2RenderTopDown(ctx, canvas) {
  if (!canvas) return;
  const mapId = ctx.editor.activeMapId();
  const info = mapId == null ? null : ctx.map.info(mapId);
  const geo = mapId == null ? null : state.maps.get(mapId);
  if (!info || !geo) return;
  const cssW = Math.max(480, Math.round(canvas.clientWidth || 700));
  const cssH = Math.max(360, Math.round(canvas.clientHeight || 620));
  canvas.width = Math.min(1200, cssW);
  canvas.height = Math.min(900, cssH);
  const c = canvas.getContext('2d');
  c.imageSmoothingEnabled = false;
  c.fillStyle = getComputedStyle(document.documentElement).getPropertyValue('--canvas-bg').trim() || '#171a20';
  c.fillRect(0,0,canvas.width,canvas.height);
  const layers = authoritativeLayers(ctx, mapId, false);
  const radius = Math.max(5, state.preview.radius || 10);
  const fx = Math.round(state.preview.focusX ?? info.width / 2), fy = Math.round(state.preview.focusY ?? info.height / 2);
  const minX = state.preview.fullMap ? 0 : Math.max(0, fx-radius), maxX = state.preview.fullMap ? info.width-1 : Math.min(info.width-1,fx+radius);
  const minY = state.preview.fullMap ? 0 : Math.max(0, fy-radius), maxY = state.preview.fullMap ? info.height-1 : Math.min(info.height-1,fy+radius);
  const cols = maxX-minX+1, rows=maxY-minY+1;
  const tile = Math.max(8, Math.floor(Math.min(canvas.width/cols, canvas.height/rows)));
  const ox = Math.floor((canvas.width-cols*tile)/2), oy=Math.floor((canvas.height-rows*tile)/2);
  canvas.__v2MapView = { minX, minY, maxX, maxY, tile, ox, oy, cols, rows };
  for (let y=minY;y<=maxY;y++) for (let x=minX;x<=maxX;x++) {
    for (const layer of layers) {
      const data = readTileVisualData(ctx,mapId,layer,x,y); if(!data) continue;
      const ts = Number(data.tilesetId) || ((layer?.kind === "native" || Number(layerRef(layer)) < 3) ? mapTilesetId(info,mapId) : 0);
      const src = sourceForTileData(ctx, Number(data.tileId)||0, data, layer, ts);
      if (!src?.img) continue;
      c.globalAlpha = Math.max(0,Math.min(1,Number(data.opacity == null ? layer.opacity ?? 1 : data.opacity > 1 ? data.opacity/255 : data.opacity)));
      c.drawImage(src.img,src.sx,src.sy,src.sw,src.sh,ox+(x-minX)*tile,oy+(y-minY)*tile,tile,tile);
    }
    c.globalAlpha=1;
  }
  for (const obj of sceneObjects(geo)) {
    const r=objectRect(obj); if(r.x1<minX||r.x0>maxX||r.y1<minY||r.y0>maxY) continue;
    const px=ox+(r.x0-minX)*tile, py=oy+(r.y0-minY)*tile, w=(r.x1-r.x0+1)*tile,h=(r.y1-r.y0+1)*tile;
    const height=Number(obj.height)||0;
    if(height>0){
      const lift=Math.min(tile*.45,Math.max(3,height*2.4));
      c.strokeStyle='rgba(112,225,255,.75)'; c.lineWidth=1.5;
      c.strokeRect(px-lift,py-lift,w,h);
      c.beginPath(); c.moveTo(px,py);c.lineTo(px-lift,py-lift);c.moveTo(px+w,py);c.lineTo(px+w-lift,py-lift);c.moveTo(px,py+h);c.lineTo(px-lift,py+h-lift);c.moveTo(px+w,py+h);c.lineTo(px+w-lift,py+h-lift);c.stroke();
    }
    c.strokeStyle = state.sourceSelection?.instance_key===obj.instance_key ? 'rgba(80,240,255,.98)' : 'rgba(255,205,80,.75)';
    c.strokeRect(px+.5,py+.5,w-1,h-1);
    if(tile>=20 && height>0){c.fillStyle='rgba(8,12,18,.82)';c.fillRect(px+2,py+2,34,14);c.fillStyle='#e8fbff';c.font='10px sans-serif';c.fillText(`H ${height}`,px+5,py+12);}
  }
  c.strokeStyle='rgba(80,220,255,.8)';c.lineWidth=1;c.strokeRect(ox-.5,oy-.5,cols*tile+1,rows*tile+1);
}

function v2BindTopDownCanvas(ctx, canvas) {
  if (!canvas) return;
  const at = (ev) => {
    const v = canvas.__v2MapView; if (!v) return null;
    const r = canvas.getBoundingClientRect();
    const px = (ev.clientX-r.left)*(canvas.width/Math.max(1,r.width));
    const py = (ev.clientY-r.top)*(canvas.height/Math.max(1,r.height));
    const cx = Math.floor((px-v.ox)/v.tile), cy=Math.floor((py-v.oy)/v.tile);
    if (cx<0||cy<0||cx>=v.cols||cy>=v.rows) return null;
    return { x:v.minX+cx, y:v.minY+cy };
  };
  canvas.addEventListener('pointerdown',(ev)=>{
    if(ev.button!==0)return;
    const p=at(ev); if(!p)return;
    const id=ctx.editor.activeMapId(); if(id==null)return;
    state.preview.focusX=p.x;state.preview.focusY=p.y;
    runSimpleSceneTool(ctx,id,p.x,p.y,null);
    v2RenderTopDown(ctx,canvas);schedulePreview(ctx);
  });
}

function v2DrawPreviewHeightMarkers(c, scene) {
  if (!scene?.items) return;
  const seen = new Set();
  c.save();
  c.font = '11px sans-serif';
  c.textAlign = 'center';
  for (const item of scene.items) {
    if (item.type !== 'objectTop' || !item.obj || !item.points?.length) continue;
    const obj = item.obj;
    const h = Number(obj.height)||0;
    if (h <= 0 || seen.has(obj.id)) continue;
    seen.add(obj.id);
    const should = state.sourceSelection?.instance_key===obj.instance_key || ['mountain','wall','border'].includes(obj.category);
    if (!should) continue;
    const x=item.points.reduce((a,p)=>a+p.x,0)/item.points.length;
    const y=item.points.reduce((a,p)=>a+p.y,0)/item.points.length;
    const text=`H ${h}`;
    const w=c.measureText(text).width+10;
    c.fillStyle='rgba(8,12,18,.78)'; c.fillRect(x-w/2,y-18,w,15);
    c.fillStyle='rgba(210,250,255,.98)'; c.fillText(text,x,y-7);
  }
  c.restore();
}

function v2BindPreviewCanvas(ctx, canvas, topDownCanvas = null) {
  if (!canvas) return;
  canvas.addEventListener('contextmenu',(ev)=>ev.preventDefault());
  const resetDraft=()=>{canvas.style.transform='';canvas.style.transformOrigin='50% 50%';canvas.style.filter='';};
  canvas.addEventListener('pointerdown',(ev)=>{
    if(ev.button===2){
      ev.preventDefault(); canvas.setPointerCapture?.(ev.pointerId);
      state.preview.orbiting=true; state.preview.orbitStartX=ev.clientX; state.preview.orbitStartY=ev.clientY;
      state.preview.orbitStartYaw=state.preview.yaw; state.preview.orbitStartPitch=state.preview.angle;
      canvas.style.transformOrigin='50% 50%'; canvas.style.filter='brightness(.92)';
      return;
    }
    if(ev.button!==0)return;
    const cell=hitPreviewCell(canvas,ev.clientX,ev.clientY);
    if(cell){
      state.preview.focusX=cell.x; state.preview.focusY=cell.y; state.preview.hovered={x:cell.x,y:cell.y};
      const geo=currentGeo(ctx); if(geo)persistPreviewPrefs(geo);
      schedulePreview(ctx,true);
    }
  });
  canvas.addEventListener('pointermove',(ev)=>{
    if(state.preview.orbiting){
      const dx=ev.clientX-state.preview.orbitStartX,dy=ev.clientY-state.preview.orbitStartY;
      state.preview.yaw=((state.preview.orbitStartYaw+dx*.45)%360+360)%360;
      state.preview.angle=Math.max(5,Math.min(70,state.preview.orbitStartPitch-dy*.28));
      // Draft feedback is a cheap CSS transform. The expensive 3D scene is
      // rebuilt once on pointer-up, so camera dragging stays responsive even
      // on maps with many tiles/models.
      const tx=Math.max(-18,Math.min(18,dx*.035)), ty=Math.max(-14,Math.min(14,dy*.03));
      const sc=1+Math.min(.025,Math.hypot(dx,dy)*.00008);
      canvas.style.transform=`translate(${tx}px,${ty}px) scale(${sc})`;
      if(state.preview.status)state.preview.status.textContent=`Camera draft · Pitch ${state.preview.angle.toFixed(0)}° · Yaw ${state.preview.yaw.toFixed(0)}° · release RMB to rebuild`;
      return;
    }
    const cell=hitPreviewCell(canvas,ev.clientX,ev.clientY);
    const next=cell?{x:cell.x,y:cell.y}:null; const old=state.preview.hovered;
    if((old?.x)!==(next?.x)||(old?.y)!==(next?.y))state.preview.hovered=next;
  });
  const end=()=>{
    const wasOrbiting=state.preview.orbiting; state.preview.orbiting=false; resetDraft();
    if(state.preview.interactionTimer){clearTimeout(state.preview.interactionTimer);state.preview.interactionTimer=0;}
    if(wasOrbiting)schedulePreview(ctx,true);
    if(topDownCanvas)v2RenderTopDown(ctx,topDownCanvas);
  };
  canvas.addEventListener('pointerup',end); canvas.addEventListener('pointercancel',end);
  canvas.addEventListener('wheel',(ev)=>{
    ev.preventDefault();
    state.preview.zoom=Math.max(.35,Math.min(2.5,state.preview.zoom+(ev.deltaY>0?-.07:.07)));
    const draft=Math.max(.88,Math.min(1.12,1+(ev.deltaY>0?-.025:.025)));
    canvas.style.transform=`scale(${draft})`;
    clearTimeout(state.preview.wheelTimer);
    state.preview.wheelTimer=setTimeout(()=>{state.preview.wheelTimer=0;resetDraft();schedulePreview(ctx,true);},110);
  },{passive:false});
}


function studioSelectionCell(scene, sel) {
  if(!sel)return null;
  return scene?.tops?.find(t=>t.x===sel.x0&&t.y===sel.y0)||null;
}
function studioOverlaySize() {
  const main=state.preview.canvas, ov=state.studioOverlayCanvas;
  if(!main||!ov)return false;
  if(ov.width!==main.width)ov.width=main.width;
  if(ov.height!==main.height)ov.height=main.height;
  return true;
}
function studioDrawOverlay(ctx) {
  const ov=state.studioOverlayCanvas, main=state.preview.canvas;
  if(!ov||!main||!studioOverlaySize())return;
  const c=ov.getContext('2d');c.setTransform(1,0,0,1,0,0);c.clearRect(0,0,ov.width,ov.height);
  const geo=currentGeo(ctx),sel=currentTerrainSelection(ctx,geo);state.studioGizmo=null;
  if(!geo)return;
  if(state.studioTool==='models'){
    const inst=selectedModelInstance(geo);
    const hover=state.modelHoverCell;
    const cells=[];
    if(inst){
      for(const hit of state.preview.hitCells||[])if(modelInstanceCoversCell(geo,inst,hit.x,hit.y))cells.push(hit);
    }else if(state.modelPlacementMode&&hover){
      const hit=(state.preview.hitCells||[]).find(t=>t.x===hover.x&&t.y===hover.y);if(hit)cells.push(hit);
    }
    c.save();c.lineWidth=2.4;c.strokeStyle=state.modelPlacementMode?'rgba(167,112,255,.98)':'rgba(255,198,70,.98)';c.fillStyle=state.modelPlacementMode?'rgba(145,85,255,.16)':'rgba(255,190,55,.13)';
    for(const cell of cells){if(!cell.points?.length)continue;c.beginPath();c.moveTo(cell.points[0].x,cell.points[0].y);for(let i=1;i<cell.points.length;i++)c.lineTo(cell.points[i].x,cell.points[i].y);c.closePath();c.fill();c.stroke();}
    c.restore();
    const label=state.modelPlacementMode?`Place ${geo.models?.[state.modelBrushId||state.modelSelectedId]?.name||'model'} · LMB`:(inst?`Instance #${inst.id} · ${geo.models?.[inst.model_id]?.name||inst.model_id}`:'Models · select or place');
    c.save();c.font='11px system-ui,sans-serif';const w=c.measureText(label).width+14;c.fillStyle='rgba(8,12,18,.84)';c.fillRect(10,10,w,23);c.fillStyle='#f2e9ff';c.fillText(label,17,26);c.restore();
    return;
  }
  if(!sel)return;
  const cells=(state.preview.hitCells||[]).filter(t=>t.x>=sel.x0&&t.x<=sel.x1&&t.y>=sel.y0&&t.y<=sel.y1);
  const danger=state.studioTool==='delete';
  c.save();c.lineWidth=2.2;c.strokeStyle=danger?'rgba(255,85,95,.98)':'rgba(70,225,255,.98)';c.fillStyle=danger?'rgba(255,65,75,.13)':'rgba(60,215,255,.10)';
  for(const cell of cells){if(!cell.points?.length)continue;c.beginPath();c.moveTo(cell.points[0].x,cell.points[0].y);for(let i=1;i<cell.points.length;i++)c.lineTo(cell.points[i].x,cell.points[i].y);c.closePath();c.fill();c.stroke();}
  c.restore();
  if(cells.length===1){
    const cell=cells[0],pts=cell.points,center={x:pts.reduce((a,p)=>a+p.x,0)/pts.length,y:pts.reduce((a,p)=>a+p.y,0)/pts.length};
    const arrow={x:center.x,y0:center.y,y1:center.y-68};
    const corners=pts.map((p,i)=>({x:p.x,y:p.y,index:i}));
    state.studioGizmo={center,arrow,corners,cell};
    if(state.studioTool==='height'){
      c.save();c.strokeStyle='rgba(115,255,155,.98)';c.fillStyle='rgba(115,255,155,.98)';c.lineWidth=3;c.beginPath();c.moveTo(arrow.x,arrow.y0);c.lineTo(arrow.x,arrow.y1);c.stroke();c.beginPath();c.moveTo(arrow.x,arrow.y1);c.lineTo(arrow.x-7,arrow.y1+11);c.lineTo(arrow.x+7,arrow.y1+11);c.closePath();c.fill();c.restore();
    }
    if(state.studioTool==='corners'){
      c.save();for(const h of corners){c.beginPath();c.arc(h.x,h.y,7,0,Math.PI*2);c.fillStyle='rgba(255,218,75,.98)';c.fill();c.strokeStyle='rgba(30,25,10,.9)';c.lineWidth=2;c.stroke();c.fillStyle='#171717';c.font='9px sans-serif';c.textAlign='center';c.textBaseline='middle';c.fillText(String(h.index+1),h.x,h.y+.5);}c.restore();
    }
  }
  const stats=terrainSelectionStats(ctx,geo);
  if(stats){c.save();c.font='11px system-ui,sans-serif';c.fillStyle='rgba(8,12,18,.82)';const txt=`${stats.w}×${stats.h} · H ${stats.avg.toFixed(2)}`;const w=c.measureText(txt).width+12;c.fillRect(10,10,w,22);c.fillStyle='#e9fbff';c.fillText(txt,16,25);c.restore();}
}
function studioCanvasPoint(canvas,ev){const r=canvas.getBoundingClientRect();return{x:(ev.clientX-r.left)*(canvas.width/Math.max(1,r.width)),y:(ev.clientY-r.top)*(canvas.height/Math.max(1,r.height))};}
function studioFastSetHeight(geo,sel,h){if(!geo||!sel)return;geo.terrain_cells||={};h=Math.max(0,Number(h)||0);for(let y=sel.y0;y<=sel.y1;y++)for(let x=sel.x0;x<=sel.x1;x++){const tc=terrainCellAt(geo,x,y);geo.terrain_cells[cellKey(x,y)]={...(tc||{}),corners:[h,h,h,h]};}geo._terrain_dirty=true;state.terrainTargetHeight=h;}
function studioFastSetCorner(geo,x,y,index,h){geo.terrain_cells||={};const tc=terrainCellAt(geo,x,y);const step=Math.max(.001,Number(geo.height_step)||DEFAULT_STEP);const base=tc?.corners?.length===4?tc.corners.slice():(()=>{const z=Math.max(0,effectiveHeight(geo,geo.map_id,x,y)/step);return[z,z,z,z]})();base[index]=Math.max(0,Number(h)||0);geo.terrain_cells[cellKey(x,y)]={...(tc||{}),corners:base};geo._terrain_dirty=true;state.terrainTargetHeight=base.reduce((a,b)=>a+b,0)/4;}
function studioFastEraseCell(geo,x,y){if(!geo)return false;geo.terrain_cells||={};geo.cells||={};const k=cellKey(x,y);let changed=false;if(k in geo.terrain_cells){delete geo.terrain_cells[k];changed=true;}if(k in geo.cells){delete geo.cells[k];changed=true;}if(changed)geo._terrain_dirty=true;return changed;}
function studioHistorySnapshot(geo){
  if(!geo)return null;
  return {
    terrain_cells:deepClone(geo.terrain_cells||{}),
    cells:deepClone(geo.cells||{}),
    ramps:deepClone(geo.ramps||[]),
    terrain_planes:deepClone(geo.terrain_planes||[]),
    model_instances:deepClone(geo.model_instances||[])
  };
}
function studioHistorySignature(v){try{return JSON.stringify(v);}catch(_){return '';}}
function studioHistoryEnsure(ctx){
  const mapId=ctx.editor.activeMapId?.(),geo=currentGeo(ctx);if(mapId==null||!geo)return null;
  if(!state.studioHistory||state.studioHistory.mapId!==mapId){state.studioHistory={mapId,undo:[],redo:[],last:studioHistorySnapshot(geo),pending:null,label:'Edit'};}
  return state.studioHistory;
}
function studioHistoryBegin(ctx,label='Terrain edit'){
  const h=studioHistoryEnsure(ctx),geo=currentGeo(ctx);if(!h||!geo)return;
  h.pending=studioHistorySnapshot(geo);h.label=label;
}
function studioHistoryCommit(ctx,label=null){
  const h=studioHistoryEnsure(ctx),geo=currentGeo(ctx);if(!h||!geo)return;
  const now=studioHistorySnapshot(geo),before=h.pending||h.last;
  if(before&&studioHistorySignature(before)!==studioHistorySignature(now)){
    h.undo.push({data:before,label:label||h.label||'Terrain edit'});if(h.undo.length>80)h.undo.shift();h.redo.length=0;
  }
  h.last=now;h.pending=null;
  studioUpdateHistoryButtons();
}
function studioHistoryRestore(ctx,snap){
  const geo=currentGeo(ctx),mapId=ctx.editor.activeMapId?.();if(!geo||mapId==null||!snap)return;
  geo.terrain_cells=deepClone(snap.terrain_cells||{});geo.cells=deepClone(snap.cells||{});geo.ramps=deepClone(snap.ramps||[]);geo.terrain_planes=deepClone(snap.terrain_planes||[]);geo.model_instances=deepClone(snap.model_instances||[]);
  if(Array.isArray(geo.mesh_faces))geo.mesh_faces=geo.mesh_faces.filter(f=>!(f?.terrain_generated===true||String(f?.part_id||'')==='__terrain__'));
  compileModelObjects(geo);
  if(state.modelInstanceSelectedId&&!selectedModelInstance(geo))state.modelInstanceSelectedId=null;
  geo._terrain_dirty=true;state.studioDraftDirty=false;ctx.editor.requestRedraw();markPreviewDirty(ctx);
  void saveMap(ctx,mapId,{authoringOnly:true,skipCompile:true,skipModelCompile:true});
  void refreshPreviewNow(ctx).then(()=>studioDrawOverlay(ctx));
  if(state.studioHost)studioUpdateInspector(ctx,state.studioHost);
}
function studioUndo(ctx){
  const h=studioHistoryEnsure(ctx),geo=currentGeo(ctx);if(!h||!geo||!h.undo.length)return;
  const current=studioHistorySnapshot(geo),entry=h.undo.pop();h.redo.push({data:current,label:entry.label});h.last=deepClone(entry.data);h.pending=null;studioHistoryRestore(ctx,entry.data);studioUpdateHistoryButtons();
}
function studioRedo(ctx){
  const h=studioHistoryEnsure(ctx),geo=currentGeo(ctx);if(!h||!geo||!h.redo.length)return;
  const current=studioHistorySnapshot(geo),entry=h.redo.pop();h.undo.push({data:current,label:entry.label});h.last=deepClone(entry.data);h.pending=null;studioHistoryRestore(ctx,entry.data);studioUpdateHistoryButtons();
}
function studioUpdateHistoryButtons(){
  const h=state.studioHistory,host=state.studioHost;if(!host)return;
  const u=host.querySelector('[data-s-undo]'),r=host.querySelector('[data-s-redo]');if(u)u.disabled=!(h?.undo?.length);if(r)r.disabled=!(h?.redo?.length);
}
function studioCommitEdit(ctx,reason='studio-edit'){
  const mapId=ctx.editor.activeMapId?.(),geo=currentGeo(ctx);if(mapId==null||!geo)return;
  studioHistoryCommit(ctx,reason);state.studioDraftDirty=false;ctx.editor.requestRedraw();markPreviewDirty(ctx);void saveMap(ctx,mapId,{authoringOnly:true,skipCompile:true,skipModelCompile:true});void refreshPreviewNow(ctx).then(()=>studioDrawOverlay(ctx));if(state.studioHost)studioUpdateInspector(ctx,state.studioHost);
}
function studioPickCorner(ev){const ov=state.studioOverlayCanvas,g=state.studioGizmo;if(!ov||!g?.corners)return null;const p=studioCanvasPoint(ov,ev);let best=null,bd=16;for(const h of g.corners){const d=Math.hypot(p.x-h.x,p.y-h.y);if(d<bd){bd=d;best=h;}}return best;}
function bindStudioCanvas(ctx,canvas,overlay,rerender){
  if(!canvas||!overlay)return;canvas.addEventListener('contextmenu',e=>e.preventDefault());overlay.addEventListener('contextmenu',e=>e.preventDefault());
  const target=overlay; const resetDraft=()=>{canvas.style.transform='';overlay.style.transform='';canvas.style.filter='';};
  target.addEventListener('pointerdown',ev=>{
    const mapId=ctx.editor.activeMapId?.();if(mapId==null||state.legacyDataBlocked)return;
    if(ev.button===2){ev.preventDefault();target.setPointerCapture?.(ev.pointerId);state.preview.orbiting=true;state.preview.orbitStartX=ev.clientX;state.preview.orbitStartY=ev.clientY;state.preview.orbitStartYaw=state.preview.yaw;state.preview.orbitStartPitch=state.preview.angle;canvas.style.filter='brightness(.94)';schedulePreview(ctx,true);return;}
    if(ev.button!==0)return;const cell=hitPreviewCell(canvas,ev.clientX,ev.clientY);if(!cell)return;
    const geo=currentGeo(ctx);if(!geo)return;
    if(state.studioTool==='models'){
      if(state.modelPlacementMode){
        studioHistoryBegin(ctx,'Place model');
        const inst=placeModelInstance(ctx,mapId,cell.x,cell.y,{deferSave:true,deferPreview:true});
        if(inst){state.modelPlacementMode=false;state.modelHoverCell=null;studioHistoryCommit(ctx,'Place model');void saveMap(ctx,mapId,{skipCompile:true});void refreshPreviewNow(ctx).then(()=>{studioUpdateInspector(ctx,state.studioHost);studioDrawOverlay(ctx);});}
        return;
      }
      const hit=modelInstanceAt(geo,cell.x,cell.y);
      if(hit){selectModelInstance(ctx,hit);studioHistoryBegin(ctx,'Move model');state.studioDrag={kind:'model-move',instId:hit.id,lastX:Number(hit.x)||0,lastY:Number(hit.y)||0};target.setPointerCapture?.(ev.pointerId);studioDrawOverlay(ctx);}
      else{selectModelInstance(ctx,null);studioUpdateInspector(ctx,state.studioHost);}
      return;
    }
    if(state.studioTool==='delete'){
      studioHistoryBegin(ctx,'Delete terrain');studioFastEraseCell(geo,cell.x,cell.y);state.studioDrag={kind:'delete',visited:new Set([cellKey(cell.x,cell.y)])};target.setPointerCapture?.(ev.pointerId);state.studioDraftDirty=true;studioDrawOverlay(ctx);return;
    }
    if(state.studioTool==='select'||state.studioTool==='models'){
      state.studioSelectionStart={x:cell.x,y:cell.y};setTerrainSelection(ctx,mapId,cell.x,cell.y);state.studioDrag={kind:'select'};studioDrawOverlay(ctx);return;
    }
    let sel=currentTerrainSelection(ctx,geo);if(!sel||cell.x<sel.x0||cell.x>sel.x1||cell.y<sel.y0||cell.y>sel.y1){sel=setTerrainSelection(ctx,mapId,cell.x,cell.y);}
    if(state.studioTool==='height'){
      studioHistoryBegin(ctx,'Height');const st=terrainSelectionStats(ctx,geo);state.studioDrag={kind:'height',startY:ev.clientY,initial:st?.avg||0,last:st?.avg||0};target.setPointerCapture?.(ev.pointerId);return;
    }
    if(state.studioTool==='corners'){
      if(sel.w!==1||sel.h!==1){setTerrainSelection(ctx,mapId,cell.x,cell.y);sel=currentTerrainSelection(ctx,geo);studioDrawOverlay(ctx);}
      const handle=studioPickCorner(ev);if(!handle){studioDrawOverlay(ctx);return;}
      const tc=terrainCellAt(geo,sel.x0,sel.y0),step=Math.max(.001,Number(geo.height_step)||DEFAULT_STEP);const base=tc?.corners?.length===4?tc.corners[handle.index]:Math.max(0,effectiveHeight(geo,mapId,sel.x0,sel.y0)/step);
      studioHistoryBegin(ctx,'Corner');state.studioDrag={kind:'corner',index:handle.index,startY:ev.clientY,initial:Number(base)||0,last:Number(base)||0};target.setPointerCapture?.(ev.pointerId);return;
    }
  });
  target.addEventListener('pointermove',ev=>{
    if(state.preview.orbiting){const dx=ev.clientX-state.preview.orbitStartX,dy=ev.clientY-state.preview.orbitStartY;state.preview.yaw=((state.preview.orbitStartYaw+dx*.38)%360+360)%360;state.preview.angle=Math.max(5,Math.min(78,state.preview.orbitStartPitch-dy*.24));schedulePreview(ctx,true);return;}
    if(state.studioTool==='models'&&state.modelPlacementMode&&!state.studioDrag){const cell=hitPreviewCell(canvas,ev.clientX,ev.clientY);if(cell){state.modelHoverCell={x:cell.x,y:cell.y};studioDrawOverlay(ctx);}return;}
    const drag=state.studioDrag,mapId=ctx.editor.activeMapId?.(),geo=currentGeo(ctx);if(!drag||mapId==null||!geo)return;
    if(drag.kind==='model-move'){
      const cell=hitPreviewCell(canvas,ev.clientX,ev.clientY);if(!cell)return;
      const inst=(geo.model_instances||[]).find(i=>Number(i.id)===Number(drag.instId));if(!inst)return;
      if(Number(inst.x)!==Number(cell.x)||Number(inst.y)!==Number(cell.y)){inst.x=cell.x;inst.y=cell.y;drag.lastX=cell.x;drag.lastY=cell.y;state.modelHoverCell={x:cell.x,y:cell.y};studioDrawOverlay(ctx);if(state.preview.status)state.preview.status.textContent=`Move model draft · ${cell.x}, ${cell.y} · release LMB to apply`;}
      return;
    }
    if(drag.kind==='delete'){const cell=hitPreviewCell(canvas,ev.clientX,ev.clientY);if(cell){const k=cellKey(cell.x,cell.y);if(!drag.visited.has(k)){drag.visited.add(k);studioFastEraseCell(geo,cell.x,cell.y);state.preview.status.textContent=`Delete draft · ${drag.visited.size} tile(s) · release LMB to apply`;}}return;}
    if(drag.kind==='select'){
      const cell=hitPreviewCell(canvas,ev.clientX,ev.clientY);if(cell&&state.studioSelectionStart){setTerrainSelection(ctx,mapId,state.studioSelectionStart.x,state.studioSelectionStart.y,cell.x,cell.y);studioDrawOverlay(ctx);}return;
    }
    const sel=currentTerrainSelection(ctx,geo);if(!sel)return;const snap=Math.max(.01,Number(state.terrainStep)||.25);const delta=Math.round((drag.startY-ev.clientY)/18)*snap;const value=Math.max(0,Math.round((drag.initial+delta)*10000)/10000);if(Math.abs(value-drag.last)<.00001)return;drag.last=value;
    if(drag.kind==='height')studioFastSetHeight(geo,sel,value);else if(drag.kind==='corner')studioFastSetCorner(geo,sel.x0,sel.y0,drag.index,value);state.studioDraftDirty=true;studioDrawOverlay(ctx);if(drag.kind==='height')overlay.style.transform=`translateY(${ev.clientY-drag.startY}px)`;const status=state.preview.status;if(status)status.textContent=`Draft · ${drag.kind==='height'?'Height':`Corner ${drag.index+1}`} ${value.toFixed(2)} · release LMB to apply`;
  });
  const finish=ev=>{
    if(state.preview.orbiting){state.preview.orbiting=false;resetDraft();void refreshPreviewNow(ctx);return;}
    const drag=state.studioDrag;state.studioDrag=null;state.studioSelectionStart=null;resetDraft();if(!drag)return;
    if(drag.kind==='model-move'){const mapId=ctx.editor.activeMapId?.(),geo=currentGeo(ctx);if(mapId!=null&&geo){compileModelObjects(geo);studioHistoryCommit(ctx,'Move model');state.modelHoverCell=null;void saveMap(ctx,mapId,{skipCompile:true});void refreshPreviewNow(ctx).then(()=>{studioUpdateInspector(ctx,state.studioHost);studioDrawOverlay(ctx);});}return;}
    if(drag.kind==='height'||drag.kind==='corner'||drag.kind==='delete')studioCommitEdit(ctx,drag.kind);else{studioDrawOverlay(ctx);rerender();}
  };
  target.addEventListener('pointerup',finish);target.addEventListener('pointercancel',finish);
  target.addEventListener('wheel',ev=>{ev.preventDefault();state.preview.zoom=Math.max(.35,Math.min(2.5,state.preview.zoom+(ev.deltaY>0?-.08:.08)));clearTimeout(state.preview.wheelTimer);state.preview.wheelTimer=setTimeout(()=>void refreshPreviewNow(ctx),100);},{passive:false});
}
function studioModelsInspectorHtml(ctx,geo){
  const models=Object.values(geo?.models||{});
  if(!models.length)return `<div class="s-empty"><b>No models yet</b><span>Import a .bbmodel or create one in Model Studio.</span><button data-s-import-bb class="wide primary" style="margin-top:10px">Import .bbmodel</button><button data-s-modelstudio class="wide">Open Model Studio</button></div>`;
  if(!state.modelSelectedId||!geo.models?.[state.modelSelectedId])state.modelSelectedId=models[0].id;
  if(!state.modelBrushId||!geo.models?.[state.modelBrushId])state.modelBrushId=state.modelSelectedId;
  const inst=selectedModelInstance(geo);
  const list=models.map(m=>`<button data-s-model-def="${escapeHtml(m.id)}" class="wide ${m.id===state.modelSelectedId?'primary':''}" style="text-align:left;margin-top:5px">${escapeHtml(m.name)} <small style="float:right">${m.parts?.length||0} parts</small></button>`).join('');
  let out=`<div class="s-block"><div class="s-block-title">Model Library <span>${models.length}</span></div>${list}<div class="s-grid2"><button data-s-import-bb>Import .bbmodel</button><button data-s-modelstudio>Edit Model</button></div><button data-s-place-model class="wide ${state.modelPlacementMode?'primary':''}">${state.modelPlacementMode?'Cancel placement':'Place selected in viewport'}</button><small>${state.modelPlacementMode?'Click a tile directly in the 3D viewport.':'Placement no longer requires returning to the 2D map.'}</small></div>`;
  if(inst){
    out+=`<div class="s-block"><div class="s-block-title">Instance #${inst.id}<span>${escapeHtml(geo.models?.[inst.model_id]?.name||inst.model_id)}</span></div><div class="s-grid2"><label>X<input data-s-inst="x" type="number" step=".25" value="${Number(inst.x)||0}"></label><label>Y<input data-s-inst="y" type="number" step=".25" value="${Number(inst.y)||0}"></label></div><label>Rotation<input data-s-inst="rotation" type="number" step="5" value="${Number(inst.rotation)||0}"></label><div class="s-grid3"><label>Scale X<input data-s-inst="scale_x" type="number" min=".05" step=".05" value="${Number(inst.scale_x)||1}"></label><label>Scale Y<input data-s-inst="scale_y" type="number" min=".05" step=".05" value="${Number(inst.scale_y)||1}"></label><label>Height<input data-s-inst="height_scale" type="number" min=".05" step=".05" value="${Number(inst.height_scale)||1}"></label></div><div class="s-grid2"><button data-s-inst-duplicate>Duplicate</button><button data-s-inst-delete class="danger">Delete instance</button></div><small>Drag the selected model over the viewport to move it. Transform fields update the compiled runtime on change.</small></div>`;
  }else{
    const count=(geo.model_instances||[]).length;
    out+=`<div class="s-block"><div class="s-block-title">Placed instances <span>${count}</span></div><small>Click an existing model in the 3D viewport to select and move it.</small></div>`;
  }
  return out;
}
function studioInspectorHtml(ctx,geo){
  if(state.studioTool==='models')return studioModelsInspectorHtml(ctx,geo);
  const sel=currentTerrainSelection(ctx,geo),st=terrainSelectionStats(ctx,geo);let body='';
  if(!sel)body=`<div class="s-empty"><b>Select terrain in the viewport</b><span>LMB selects. Drag to select an area.</span></div>`;
  else{
    const tc=sel.w===1&&sel.h===1?terrainCellAt(geo,sel.x0,sel.y0):null;const corners=tc?.corners?.length===4?tc.corners:[st?.avg||0,st?.avg||0,st?.avg||0,st?.avg||0];
    body=`<div class="s-block"><div class="s-block-title">Selection <span>${sel.w}×${sel.h}</span></div><div class="s-metrics"><span>X <b>${sel.x0}</b></span><span>Y <b>${sel.y0}</b></span><span>Tiles <b>${st?.count||0}</b></span></div><label>Height<input data-s-height type="number" min="0" step=".25" value="${(st?.avg||0).toFixed(3)}"></label><div class="s-grid3"><button data-s-nudge="-${Math.abs(Number(state.terrainStep)||.25)}">− Step</button><button data-s-set-height class="primary">Set</button><button data-s-nudge="${Math.abs(Number(state.terrainStep)||.25)}">+ Step</button></div><div class="s-grid2"><button data-s-flat>Flatten</button><button data-s-delete class="danger">Delete terrain</button></div></div>`;
    body+=`<div class="s-block"><div class="s-block-title">Slope</div><div class="s-grid2"><label>Angle<input data-s-angle type="number" min="-75" max="75" value="${Number(state.terrainAngle)||25}"></label><label>Base<input data-s-base type="number" min="0" step=".25" value="${Number(state.terrainTargetHeight)||0}"></label></div><div class="s-grid4"><button data-s-slope="0">N</button><button data-s-slope="90">E</button><button data-s-slope="180">S</button><button data-s-slope="270">W</button></div></div>`;
    if(sel.w===1&&sel.h===1)body+=`<div class="s-block"><div class="s-block-title">Corners <span>drag yellow handles</span></div><div class="s-grid2">${corners.map((v,i)=>`<label>${['NW','NE','SE','SW'][i]}<input data-s-corner="${i}" type="number" min="0" step=".25" value="${Number(v).toFixed(3)}"></label>`).join('')}</div><button data-s-corners-apply class="wide">Apply corners</button></div>`;
  }
  return body+`<div class="s-block"><div class="s-block-title">Models</div><button data-s-modelstudio class="wide">Open Model Studio</button><small>Use low-poly models only for special props/buildings. Terrain stays parametric.</small></div>`;
}
function studioBindInspector(ctx,host){
  const aside=host.querySelector('.s-inspector');if(!aside)return;
  if(state.studioTool==='models'){
    for(const b of aside.querySelectorAll('[data-s-model-def]'))b.addEventListener('click',()=>{state.modelSelectedId=b.getAttribute('data-s-model-def');state.modelBrushId=state.modelSelectedId;state.modelInstanceSelectedId=null;state.modelPlacementMode=false;studioUpdateInspector(ctx,host);studioDrawOverlay(ctx);});
    aside.querySelector('[data-s-place-model]')?.addEventListener('click',()=>{const geo=currentGeo(ctx);if(!geo)return;state.modelBrushId=state.modelSelectedId||Object.keys(geo.models||{})[0]||null;if(!state.modelBrushId){ctx.ui.showToast?.({message:'Importa o crea un modelo primero.',level:'info'});return;}state.modelPlacementMode=!state.modelPlacementMode;state.modelInstanceSelectedId=null;state.modelHoverCell=null;studioUpdateInspector(ctx,host);studioDrawOverlay(ctx);if(state.modelPlacementMode)ctx.ui.showToast?.({message:'Placement activo: haz clic directamente en el viewport 3D.',level:'info'});});
    aside.querySelector('[data-s-import-bb]')?.addEventListener('click',()=>void importBlockbenchModel(ctx).then(m=>{if(m){state.studioTool='models';state.modelSelectedId=m.id;state.modelBrushId=m.id;state.modelPlacementMode=true;state.modelInstanceSelectedId=null;studioUpdateInspector(ctx,host);studioDrawOverlay(ctx);ctx.ui.showToast?.({message:`${m.name}: listo para colocar en el viewport 3D.`,level:'info'});}}));
    aside.querySelector('[data-s-modelstudio]')?.addEventListener('click',()=>openModelWorkshop(ctx));
    for(const e of aside.querySelectorAll('[data-s-inst]'))e.addEventListener('change',()=>{const mapId=ctx.editor.activeMapId?.(),geo=currentGeo(ctx),inst=selectedModelInstance(geo);if(mapId==null||!inst)return;const patch={};for(const f of aside.querySelectorAll('[data-s-inst]'))patch[f.getAttribute('data-s-inst')]=Number(f.value)||0;studioHistoryBegin(ctx,'Transform model');updateModelInstance(ctx,mapId,inst.id,patch,{deferSave:true,deferPreview:true});studioHistoryCommit(ctx,'Transform model');void saveMap(ctx,mapId,{skipCompile:true});void refreshPreviewNow(ctx).then(()=>studioDrawOverlay(ctx));});
    aside.querySelector('[data-s-inst-delete]')?.addEventListener('click',()=>{const mapId=ctx.editor.activeMapId?.(),inst=selectedModelInstance(currentGeo(ctx));if(mapId==null||!inst)return;studioHistoryBegin(ctx,'Delete model instance');deleteModelInstance(ctx,mapId,inst.id);studioHistoryCommit(ctx,'Delete model instance');studioUpdateInspector(ctx,host);});
    aside.querySelector('[data-s-inst-duplicate]')?.addEventListener('click',()=>{const mapId=ctx.editor.activeMapId?.(),geo=currentGeo(ctx),inst=selectedModelInstance(geo);if(mapId==null||!inst)return;studioHistoryBegin(ctx,'Duplicate model instance');const cp={...deepClone(inst),id:nextModelInstanceId(geo),x:Number(inst.x)+1};geo.model_instances.push(cp);state.modelInstanceSelectedId=cp.id;compileModelObjects(geo);studioHistoryCommit(ctx,'Duplicate model instance');void saveMap(ctx,mapId,{skipCompile:true});void refreshPreviewNow(ctx).then(()=>{studioUpdateInspector(ctx,host);studioDrawOverlay(ctx);});});
    return;
  }
  aside.querySelector('[data-s-height]')?.addEventListener('change',e=>{state.terrainTargetHeight=Math.max(0,Number(e.target.value)||0);});
  aside.querySelector('[data-s-set-height]')?.addEventListener('click',()=>{const id=ctx.editor.activeMapId?.(),sel=currentTerrainSelection(ctx);if(id!=null&&sel){studioHistoryBegin(ctx,'Set height');setTerrainHeightInBounds(ctx,id,sel,state.terrainTargetHeight);studioHistoryCommit(ctx,'Set height');void refreshPreviewNow(ctx).then(()=>studioDrawOverlay(ctx));studioUpdateInspector(ctx,host);}});
  for(const b of aside.querySelectorAll('[data-s-nudge]'))b.addEventListener('click',()=>{const id=ctx.editor.activeMapId?.(),sel=currentTerrainSelection(ctx);if(id!=null&&sel){studioHistoryBegin(ctx,'Nudge height');nudgeTerrainBounds(ctx,id,sel,Number(b.getAttribute('data-s-nudge'))||0);studioHistoryCommit(ctx,'Nudge height');void refreshPreviewNow(ctx).then(()=>studioDrawOverlay(ctx));studioUpdateInspector(ctx,host);}});
  aside.querySelector('[data-s-flat]')?.addEventListener('click',()=>{const id=ctx.editor.activeMapId?.(),sel=currentTerrainSelection(ctx);if(id!=null&&sel){studioHistoryBegin(ctx,'Set height');setTerrainHeightInBounds(ctx,id,sel,state.terrainTargetHeight);studioHistoryCommit(ctx,'Set height');void refreshPreviewNow(ctx).then(()=>studioDrawOverlay(ctx));studioUpdateInspector(ctx,host);}});
  aside.querySelector('[data-s-delete]')?.addEventListener('click',()=>{const id=ctx.editor.activeMapId?.(),sel=currentTerrainSelection(ctx);if(id!=null&&sel){studioHistoryBegin(ctx,'Delete terrain');eraseTerrainBounds(ctx,id,sel);studioHistoryCommit(ctx,'Delete terrain');state.terrainSelection=null;void refreshPreviewNow(ctx).then(()=>studioDrawOverlay(ctx));studioUpdateInspector(ctx,host);}});
  aside.querySelector('[data-s-angle]')?.addEventListener('change',e=>state.terrainAngle=Math.max(-75,Math.min(75,Number(e.target.value)||0)));
  aside.querySelector('[data-s-base]')?.addEventListener('change',e=>state.terrainTargetHeight=Math.max(0,Number(e.target.value)||0));
  for(const b of aside.querySelectorAll('[data-s-slope]'))b.addEventListener('click',()=>{const id=ctx.editor.activeMapId?.(),sel=currentTerrainSelection(ctx);if(id==null||!sel)return;studioHistoryBegin(ctx,'Slope');state.terrainYaw=Number(b.getAttribute('data-s-slope'))||0;applyTerrainSlopeRect(ctx,id,sel,state.terrainTargetHeight);studioHistoryCommit(ctx,'Slope');void refreshPreviewNow(ctx).then(()=>studioDrawOverlay(ctx));studioUpdateInspector(ctx,host);});
  aside.querySelector('[data-s-corners-apply]')?.addEventListener('click',()=>{const id=ctx.editor.activeMapId?.(),sel=currentTerrainSelection(ctx);if(id==null||!sel||sel.w!==1||sel.h!==1)return;const arr=[0,0,0,0];for(const e of aside.querySelectorAll('[data-s-corner]'))arr[Number(e.getAttribute('data-s-corner'))]=Math.max(0,Number(e.value)||0);studioHistoryBegin(ctx,'Set corners');setTerrainCornersAt(ctx,id,sel.x0,sel.y0,arr);studioHistoryCommit(ctx,'Set corners');void refreshPreviewNow(ctx).then(()=>studioDrawOverlay(ctx));studioUpdateInspector(ctx,host);});
  aside.querySelector('[data-s-modelstudio]')?.addEventListener('click',()=>openModelWorkshop(ctx));
}
function studioUpdateInspector(ctx,host){const aside=host?.querySelector?.('.s-inspector');if(!aside)return;aside.innerHTML=studioInspectorHtml(ctx,currentGeo(ctx));studioBindInspector(ctx,host);studioDrawOverlay(ctx);}
function renderGeometryStudioPanel(ctx,host){
  state.previewLive=false;state.previewPanelOpen=true;state.studioHost=host;
  if(state.legacyDataBlocked){host.innerHTML=`<style>.legacy-v4{height:100%;display:grid;place-items:center;background:var(--bg-primary);color:var(--text-primary);font:13px system-ui}.legacy-v4>div{max-width:620px;border:1px solid #8f4747;background:#2b1d20;padding:24px;border-radius:12px}.legacy-v4 code{display:block;margin:14px 0;padding:12px;background:#14161b;border-radius:7px;color:#ffdbb0}.legacy-v4 button{padding:9px 14px}</style><div class="legacy-v4"><div><h2>Clean Geometry v4 requires a reset</h2><p>Old Geometry JSON data is still present. V4 intentionally refuses to read it because it can reintroduce ghost terrain and stale compiled objects.</p><code>DELETE: Data/VERMEIL2_5D/</code><p>Delete that entire folder from the game project, then press Recheck. Your RPG Maker maps/tiles are not inside that folder.</p><button data-s-recheck>Recheck</button></div></div>`;host.querySelector('[data-s-recheck]')?.addEventListener('click',async()=>{const id=ctx.editor.activeMapId?.();state.legacyDataBlocked=await legacyDataPresent(ctx,id);if(!state.legacyDataBlocked){state.maps.clear();await ensureMap(ctx,id,true);renderGeometryStudioPanel(ctx,host);}else ctx.ui.showToast?.({message:'Data/VERMEIL2_5D still exists. Delete the whole folder first.',level:'error'});});return;}
  const geo=currentGeo(ctx);const toolbar=[['select','↖','Select'],['height','↕','Height'],['corners','◇','Corners'],['delete','⌫','Delete'],['models','◆','Models']].map(([id,ic,l])=>`<button data-s-tool="${id}" class="${state.studioTool===id?'active':''}"><b>${ic}</b><span>${l}</span></button>`).join('');
  host.innerHTML=`<style>
  .studio{height:100%;min-height:500px;display:grid;grid-template-rows:52px minmax(0,1fr) 28px;background:var(--bg-primary);color:var(--text-primary);font:12px Inter,system-ui,sans-serif}.studio *{box-sizing:border-box}.s-top{display:flex;align-items:center;gap:5px;padding:6px 8px;border-bottom:1px solid var(--border);background:var(--bg-secondary)}.s-brand{font-weight:800;margin-right:5px}.s-chip{font-size:9px;border:1px solid var(--border);border-radius:999px;padding:3px 6px;color:var(--text-tertiary);margin-right:7px}.s-top button,.s-inspector button{border:1px solid var(--border);background:var(--bg-secondary);color:var(--text-primary);border-radius:7px;cursor:pointer}.s-top button{height:38px;min-width:62px;display:grid;place-items:center;padding:3px 9px}.s-top button b{font-size:15px;line-height:15px}.s-top button span{font-size:9px}.s-top button:disabled{opacity:.35;cursor:default}.s-top button.active,.s-inspector button.primary{border-color:var(--accent);background:color-mix(in srgb,var(--accent) 16%,var(--bg-secondary))}.s-spacer{flex:1}.s-camera{display:flex;gap:4px}.s-camera button{min-width:44px}.s-main{min-height:0;display:grid;grid-template-columns:minmax(0,1fr) 280px}.s-view{position:relative;min-width:0;min-height:0;background:#111318;overflow:hidden}.s-view canvas{position:absolute;inset:0;width:100%;height:100%;image-rendering:pixelated;touch-action:none}.s-overlay{z-index:3}.s-hint{position:absolute;left:10px;bottom:10px;z-index:4;padding:6px 8px;border-radius:6px;background:rgba(8,10,14,.78);color:#c7d1dd;font-size:10px;pointer-events:none}.s-inspector{overflow:auto;border-left:1px solid var(--border);background:var(--bg-secondary);padding:9px}.s-inspector label{display:grid;gap:4px;color:var(--text-secondary);font-size:10px;margin-top:7px}.s-inspector input{width:100%;background:var(--bg-primary);color:var(--text-primary);border:1px solid var(--border);border-radius:6px;padding:7px}.s-block{border:1px solid var(--border);border-radius:9px;padding:9px;margin-bottom:8px;background:var(--bg-primary)}.s-block-title{font-weight:750;display:flex;justify-content:space-between;gap:8px}.s-block-title span,.s-block small{font-size:9px;color:var(--text-tertiary);font-weight:400}.s-metrics,.s-grid2,.s-grid3,.s-grid4{display:grid;gap:5px;margin-top:7px}.s-metrics{grid-template-columns:repeat(3,1fr)}.s-metrics span{padding:6px;background:var(--bg-secondary);border-radius:5px;font-size:9px}.s-metrics b{display:block;font-size:11px}.s-grid2{grid-template-columns:1fr 1fr}.s-grid3{grid-template-columns:repeat(3,1fr)}.s-grid4{grid-template-columns:repeat(4,1fr)}.s-inspector button{padding:7px}.s-inspector .wide{width:100%;margin-top:7px}.s-inspector button.danger{border-color:#8d444d;color:#ffb5bd}.s-empty{padding:28px 10px;text-align:center;color:var(--text-tertiary)}.s-empty b,.s-empty span{display:block}.s-empty b{color:var(--text-primary);margin-bottom:5px}.s-status{display:flex;align-items:center;padding:0 9px;border-top:1px solid var(--border);color:var(--text-tertiary);font-size:10px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
  </style><div class="studio"><div class="s-top"><span class="s-brand">2.5D Geometry Studio</span><span class="s-chip">UNITY 4.2</span><button data-s-undo title="Undo · Ctrl+Z" style="min-width:38px">↶</button><button data-s-redo title="Redo · Ctrl+Y / Ctrl+Shift+Z" style="min-width:38px">↷</button>${toolbar}<span class="s-spacer"></span><div class="s-camera"><button data-s-cam="game">Game</button><button data-s-cam="0">Front</button><button data-s-cam="90">Right</button><button data-s-cam="180">Back</button><button data-s-cam="270">Left</button></div><button data-s-refresh>Refresh</button></div><div class="s-main"><div class="s-view"><canvas data-pv-main width="1000" height="650"></canvas><canvas class="s-overlay" data-s-overlay width="1000" height="650"></canvas><div class="s-hint">LMB select/edit · Models: Place → click viewport · drag placed model to move · RMB orbit · Wheel zoom · Ctrl+Z/Y</div></div><aside class="s-inspector">${studioInspectorHtml(ctx,geo)}</aside></div><div class="s-status" data-pv-status>Ready</div></div>`;
  const main=host.querySelector('[data-pv-main]'),ov=host.querySelector('[data-s-overlay]');state.preview.canvas=main;state.studioOverlayCanvas=ov;state.preview.status=host.querySelector('[data-pv-status]');studioHistoryEnsure(ctx);bindStudioCanvas(ctx,main,ov,()=>studioUpdateInspector(ctx,host));studioBindInspector(ctx,host);host.querySelector('[data-s-undo]')?.addEventListener('click',()=>studioUndo(ctx));host.querySelector('[data-s-redo]')?.addEventListener('click',()=>studioRedo(ctx));studioUpdateHistoryButtons();host.tabIndex=0;host.addEventListener('keydown',e=>{const tag=e.target?.tagName,k=String(e.key||'').toLowerCase();if(tag==='INPUT'||tag==='SELECT'||tag==='TEXTAREA')return;if((e.ctrlKey||e.metaKey)&&k==='z'){e.preventDefault();if(e.shiftKey)studioRedo(ctx);else studioUndo(ctx);}else if((e.ctrlKey||e.metaKey)&&k==='y'){e.preventDefault();studioRedo(ctx);}});host.focus?.({preventScroll:true});
  for(const b of host.querySelectorAll('[data-s-tool]'))b.addEventListener('click',()=>{state.studioTool=b.getAttribute('data-s-tool');if(state.studioTool!=='models'){state.modelPlacementMode=false;state.modelHoverCell=null;state.modelInstanceSelectedId=null;}for(const el of host.querySelectorAll('[data-s-tool]'))el.classList.toggle('active',el===b);studioUpdateInspector(ctx,host);studioDrawOverlay(ctx);});
  for(const b of host.querySelectorAll('[data-s-cam]'))b.addEventListener('click',()=>{const v=b.getAttribute('data-s-cam');if(v==='game'){state.preview.angle=runtimeConfig.outdoorDefaultAlpha||25;state.preview.yaw=0;}else state.preview.yaw=Number(v)||0;void refreshPreviewNow(ctx);});
  host.querySelector('[data-s-refresh]')?.addEventListener('click',()=>void refreshPreviewNow(ctx));
  void refreshPreviewNow(ctx).then(()=>{studioUpdateInspector(ctx,host);studioDrawOverlay(ctx);});
}

function renderLivePreviewPanel(ctx, host) { renderGeometryStudioPanel(ctx, host); }

function bindPanelV2(ctx, host, rerender) {
  const q=(s)=>host.querySelector(s);
  q('[data-g4-step]')?.addEventListener('change',e=>{state.terrainStep=Math.max(.01,Math.abs(Number(e.target.value)||.25));rerender();});
  q('[data-g4-target-height]')?.addEventListener('change',e=>{state.terrainTargetHeight=Math.max(0,Number(e.target.value)||0);rerender();});
  q('[data-g4-clear-selection]')?.addEventListener('click',()=>{state.terrainSelection=null;state.terrainSelectStart=null;state.terrainSelectCurrent=null;ctx.editor.requestRedraw();rerender();});
  q('[data-g4-set-height]')?.addEventListener('click',()=>{const mapId=ctx.editor.activeMapId?.(),geo=currentGeo(ctx),sel=currentTerrainSelection(ctx,geo);const input=q('[data-g4-selection-height]');if(mapId==null||!sel||!input)return;setTerrainHeightInBounds(ctx,mapId,sel,Number(input.value)||0);ctx.editor.requestRedraw();rerender();});
  q('[data-g4-apply-corners]')?.addEventListener('click',()=>{const mapId=ctx.editor.activeMapId?.(),geo=currentGeo(ctx),sel=currentTerrainSelection(ctx,geo);if(mapId==null||!sel||sel.w!==1||sel.h!==1)return;const corners=[0,0,0,0];for(const el of host.querySelectorAll('[data-g4-corner]'))corners[Number(el.getAttribute('data-g4-corner'))]=Math.max(0,Number(el.value)||0);setTerrainCornersAt(ctx,mapId,sel.x0,sel.y0,corners);ctx.editor.requestRedraw();rerender();});
  q('[data-g4-apply-selection]')?.addEventListener('click',()=>{if(applyCurrentTerrainToolToSelection(ctx)){ctx.editor.requestRedraw();rerender();}});
  q('[data-g4-sample-height]')?.addEventListener('click',()=>{const st=terrainSelectionStats(ctx,currentGeo(ctx));if(st){state.terrainTargetHeight=st.avg;rerender();}});
  q('[data-g4-pick-legacy]')?.addEventListener('click',()=>{const sel=currentTerrainSelection(ctx,currentGeo(ctx));const mapId=ctx.editor.activeMapId?.();if(!sel||mapId==null)return;const d=selectSourceAt(ctx,mapId,sel.x0,sel.y0,null);if(d){state.uiAdvanced=true;ctx.ui.showToast?.({message:'Legacy tile rule selected. Terrain sculpting remains independent.',level:'info'});}else ctx.ui.showToast?.({message:'No tile source found at the selected cell.',level:'info'});rerender();});
  q('[data-g4-save-runtime]')?.addEventListener('click',()=>{const mapId=ctx.editor.activeMapId?.();if(mapId!=null)void saveMap(ctx,mapId).then(()=>{state.previewDirty=true;rerender();ctx.ui.showToast?.({message:'2.5D runtime rebuilt.',level:'info'});});});
  for(const b of host.querySelectorAll('[data-v3-section]')) b.addEventListener('click',()=>{state.uiSection=b.getAttribute('data-v3-section')==='models'?'models':'terrain';rerender();});
  q('[data-v3-advanced]')?.addEventListener('click',async()=>{state.uiAdvanced=!state.uiAdvanced;const id=ctx.editor.activeMapId?.();if(state.uiAdvanced&&id!=null)await ensureLegacyAuthoringData(ctx,id,false);rerender();});
  q('[data-v3-scope-select]')?.addEventListener('change',e=>{state.sceneScope=e.target.value||'this';rerender();});
  for(const b of host.querySelectorAll('[data-v3-model]')) b.addEventListener('click',()=>{state.modelSelectedId=b.getAttribute('data-v3-model');state.modelBrushId=state.modelSelectedId;rerender();});
  for(const b of host.querySelectorAll('[data-v2-tool]')) b.addEventListener('click',()=>{state.sceneTool=b.getAttribute('data-v2-tool');state.workspaceMode='scene';state.objTool=false;state.modelTool=false;state.modelEraseMode=false;ctx.editor.setTool(TOOL_ID);rerender();});
  q('[data-v2-terrain-angle]')?.addEventListener('change',e=>{state.terrainAngle=Math.max(-75,Math.min(75,Number(e.target.value)||0));rerender();});
  q('[data-v2-terrain-yaw]')?.addEventListener('change',e=>{state.terrainYaw=((Number(e.target.value)||0)%360+360)%360;rerender();});
  for(const b of host.querySelectorAll('[data-v2-terrain-dir]')) b.addEventListener('click',()=>{state.terrainYaw=Number(b.getAttribute('data-v2-terrain-dir'))||0;state.sceneTool='terrain-slope';ctx.editor.setTool(TOOL_ID);rerender();});
  for(const b of host.querySelectorAll('[data-v2-preset]')) b.addEventListener('click',()=>{
    const p=v2PresetInternal(b.getAttribute('data-v2-preset'));state.brushPreset=p;state.sourcePreset=p;
    const preset=SCENE_GEOMETRY_PRESETS[p]||SCENE_GEOMETRY_PRESETS.wall;if(!state.sourceSelection)state.brushHeight=Number(preset.height)||0;
    if(state.sourceSelection)applySimpleGeometry(ctx,state.sourceSelection,p,state.brushHeight||preset.height);
    rerender();
  });
  for(const b of host.querySelectorAll('[data-v2-scope]')) b.addEventListener('click',()=>{state.sceneScope=b.getAttribute('data-v2-scope');rerender();});
  for(const b of host.querySelectorAll('[data-v2-view]')) b.addEventListener('click',()=>{state.viewMode='2d';state.largeViewKind='2.5d';ctx.ui.openPanel(PREVIEW_PANEL_ID);state.previewPanelRefresh?.();});
  q('[data-v2-action="sample-map"]')?.addEventListener('click',()=>{state.sceneTool='select';ctx.editor.setTool(TOOL_ID);rerender();ctx.ui.showToast?.({message:'Haz clic en cualquier tile del mapa.',level:'info'});});
  q('[data-v2-action="pick-graphic"]')?.addEventListener('click',()=>void v2ChooseGraphic(ctx));
  q('[data-v2-action="place-picked"]')?.addEventListener('click',()=>{state.sceneTool='place';state.modelTool=false;ctx.editor.setTool(TOOL_ID);rerender();});
  q('[data-v2-action="model-workshop"]')?.addEventListener('click',()=>openModelWorkshop(ctx));
  q('[data-v2-action="model-from-selection"]')?.addEventListener('click',()=>void createModelFromMapSelection(ctx).then(m=>{if(m)openModelWorkshop(ctx);}));
  q('[data-v2-action="model-place"]')?.addEventListener('click',()=>{const g=currentGeo(ctx);if(!state.modelBrushId)state.modelBrushId=Object.keys(g?.models||{})[0]||null;if(!state.modelBrushId){createModel(ctx);openModelWorkshop(ctx);return;}state.modelTool=true;state.modelEraseMode=false;state.sceneTool='model-place';ctx.editor.setTool(TOOL_ID);rerender();});
  for(const b of host.querySelectorAll('[data-v2-model-rot]')) b.addEventListener('click',()=>{state.modelRotation=normalizeModelPlacementRotation((Number(state.modelRotation)||0)+(Number(b.getAttribute('data-v2-model-rot'))||0));rerender();});
  q('[data-v2-action="height-minus"]')?.addEventListener('click',()=>{if(state.sourceSelection)adjustSimpleGeometryHeight(ctx,state.sourceSelection,-.25);else state.brushHeight=Math.max(0,state.brushHeight-.25);rerender();});
  q('[data-v2-action="height-plus"]')?.addEventListener('click',()=>{if(state.sourceSelection)adjustSimpleGeometryHeight(ctx,state.sourceSelection,.25);else state.brushHeight+=.25;rerender();});
  q('[data-id="v2-height"]')?.addEventListener('change',(e)=>{const h=Math.max(0,Number(e.target.value)||0);state.brushHeight=h;if(state.sourceSelection)setSimpleGeometryHeight(ctx,state.sourceSelection,h);rerender();});
  q('[data-id="v2-connect"]')?.addEventListener('change',(e)=>{if(state.sourceSelection)patchSimpleGeometry(ctx,state.sourceSelection,{components:{connect_neighbors:!!e.target.checked}});rerender();});
  q('[data-id="v2-cap"]')?.addEventListener('change',(e)=>{if(state.sourceSelection)patchSimpleGeometry(ctx,state.sourceSelection,{components:{cap:!!e.target.checked}});rerender();});
  q('[data-id="v2-collision"]')?.addEventListener('change',(e)=>{if(state.sourceSelection)patchSimpleGeometry(ctx,state.sourceSelection,{collision:e.target.value});rerender();});
  q('[data-v2-action="rescan"]')?.addEventListener('click',()=>{const id=ctx.editor.activeMapId();if(id==null)return;state.sourceUsageByMap.delete(id);state.preview.usedAssetsByMap.delete(id);void scanGeometrySources(ctx,id,true).then(()=>ensureSceneTilesetResources(ctx,id,true)).then(()=>rerender());});
  for(const b of host.querySelectorAll('[data-v2-browser-source]'))b.addEventListener('click',()=>void v2SelectBrowserSource(ctx,b.getAttribute('data-v2-browser-source')));
  v2DrawSelectedThumbnail(ctx,host);v2DrawPickedThumbnail(ctx,host);v2DrawBrowserThumbs(ctx,host);
}


export async function activate(ctx) {
  ctx.log.info("2.5D Geometry v4.2.0 Unity Placement activated");
  await loadRuntimeConfig(ctx);
  state.preview.angle = runtimeConfig.outdoorDefaultAlpha || state.preview.angle;

  // Expose the same semantic Visual 2.5D categories inside Maker Studio's
  // Tileset Editor. The preview reads these exact ids at render time.
  for (const [id, name] of TAG_NAMES.entries()) {
    try { ctx.tileset.registerTerrainTag({ id, name }); } catch (_) {}
  }

  ctx.tools.registerTool({
    id: TOOL_ID,
    label: "Geometry",
    icon: "⬢",
    onPointerDown(ev) {
      if ((ev.buttons & 1) === 0) return;
      state.dragging = true;
      state.visited.clear();
      state.terrainStrokeCells.clear();
      state.terrainFlatTarget = null;
      if (state.workspaceMode === "scene") {
        if (state.sceneTool === "select") {
          state.terrainSelectStart = { mapId:ev.mapId, x:ev.tileX, y:ev.tileY };
          state.terrainSelectCurrent = { x:ev.tileX, y:ev.tileY };
          setTerrainSelection(ctx,ev.mapId,ev.tileX,ev.tileY,ev.tileX,ev.tileY);
          return;
        }
        if (state.sceneTool === "terrain-flat") {
          const geo=state.maps.get(ev.mapId);
          if(geo){const step=Math.max(.001,Number(geo.height_step)||DEFAULT_STEP);const c=terrainCellCenterLevel(geo,ev.tileX,ev.tileY);state.terrainFlatTarget=c==null?Math.max(0,effectiveHeight(geo,ev.mapId,ev.tileX,ev.tileY)/step):c;state.terrainTargetHeight=state.terrainFlatTarget;}
        }
        if (ev.altKey) {
          state.visited.add(`${ev.mapId}:${ev.tileX},${ev.tileY}:erase`);
          if (state.uiSection === "models") eraseModelAtCell(ctx,ev.mapId,ev.tileX,ev.tileY);
          else eraseTerrainBrush(ctx,ev.mapId,ev.tileX,ev.tileY);
          return;
        }
        if (state.sceneTool === "model-place") { placeModelInstance(ctx, ev.mapId, ev.tileX, ev.tileY); state.dragging=false; return; }
        const key = `${ev.mapId}:${ev.layerIndex}:${ev.tileX},${ev.tileY}:${state.sceneTool}`;
        state.visited.add(key);
        runSimpleSceneTool(ctx, ev.mapId, ev.tileX, ev.tileY, ev.layerIndex);
        if (["select", "eyedropper", "place"].includes(state.sceneTool)) { state.dragging = false; schedulePanelRefresh(); }
        return;
      }
      if (state.objTool || state.workspaceMode === "object") {
        if (ev.altKey) { void objectEraseAt(ctx, ev); return; }
        const geo = state.maps.get(ev.mapId);
        const hit = geo ? findObjectAt(geo, ev.tileX, ev.tileY) : null;
        if (hit) { selectObject(ctx, geo, hit, ev.mapId); return; }
        state.objSelected = null;
        state.objStart = { x: ev.tileX, y: ev.tileY };
        state.objCurrent = { x: ev.tileX, y: ev.tileY };
        ctx.editor.requestRedraw();
        schedulePreview(ctx);
        return;
      }
      void paintAt(ctx, ev);
    },
    onPointerMove(ev) {
      if (!state.dragging || (ev.buttons & 1) === 0) return;
      if (state.workspaceMode === "scene") {
        if (state.sceneTool === "select") {
          if(!state.terrainSelectStart)return;
          state.terrainSelectCurrent={x:ev.tileX,y:ev.tileY};
          setTerrainSelection(ctx,ev.mapId,state.terrainSelectStart.x,state.terrainSelectStart.y,ev.tileX,ev.tileY);
          return;
        }
        const activeTool = ev.altKey ? "erase" : state.sceneTool;
        if (!["paint", "raise", "lower", "erase", "terrain-slope", "terrain-flat", "terrain-clear"].includes(activeTool)) return;
        const key = `${ev.mapId}:${ev.layerIndex}:${ev.tileX},${ev.tileY}:${activeTool}`;
        if (state.visited.has(key)) return;
        state.visited.add(key);
        if (activeTool === "erase") {
          if (state.uiSection === "models") eraseModelAtCell(ctx,ev.mapId,ev.tileX,ev.tileY);
          else eraseTerrainBrush(ctx,ev.mapId,ev.tileX,ev.tileY);
        } else runSimpleSceneTool(ctx, ev.mapId, ev.tileX, ev.tileY, ev.layerIndex);
        return;
      }
      if (state.objTool || state.workspaceMode === "object") {
        if (ev.altKey) { void objectEraseAt(ctx, ev); return; }
        state.objCurrent = { x: ev.tileX, y: ev.tileY };
        ctx.editor.requestRedraw();
        schedulePreview(ctx);
        return;
      }
      void paintAt(ctx, ev);
    },
    onPointerUp(ev) {
      if (!state.dragging) return;
      state.dragging = false;
      state.visited.clear();
      state.terrainStrokeCells.clear();
      if (state.workspaceMode === "scene" && state.sceneTool === "select") {
        state.terrainSelectStart=null; state.terrainSelectCurrent=null; state.terrainFlatTarget=null;
        const st=terrainSelectionStats(ctx,state.maps.get(ev.mapId)); if(st)state.terrainTargetHeight=st.avg;
        schedulePanelRefresh(); ctx.editor.requestRedraw();
        return;
      }
      state.terrainFlatTarget=null;
      if (state.workspaceMode === "scene") {
        clearTimeout(state.simpleEditTimer);
        state.simpleEditTimer = 0;
        const geo = state.maps.get(ev.mapId);
        if (geo) {
          // Keep mouse-up instant. The visible scene is already updated locally;
          // write lightweight data now and reconcile the full compiler later.
          clearTimeout(state.simpleEditTimer);
          state.simpleEditTimer = setTimeout(() => {
            state.simpleEditTimer = 0;
            void saveMap(ctx, ev.mapId, { authoringOnly: true, skipCompile: true, skipModelCompile: true });
          }, 900);
          if (Object.keys(geo.definitions || {}).length) scheduleSceneCompile(ctx, ev.mapId, "gesture-end", 1200);
          schedulePanelRefresh();
          markPreviewDirty(ctx);
        }
        return;
      }
      if (state.objTool || state.workspaceMode === "object") {
        if (state.objStart && state.objCurrent) {
          const geo = state.maps.get(ev.mapId);
          if (geo) commitObjectFromRect(ctx, geo, ev.mapId,
            state.objStart.x, state.objStart.y, state.objCurrent.x, state.objCurrent.y);
        }
        state.objStart = null;
        state.objCurrent = null;
        void saveMap(ctx, ev.mapId);
        return;
      }
      void saveMap(ctx, ev.mapId);
    },
    onActivate() {
      ctx.ui.openPanel(PREVIEW_PANEL_ID);
      ctx.editor.setStatusBarText?.("2.5D Geometry 4.2: terrain + direct model placement in the 3D viewport");
      const mapId = ctx.editor.activeMapId?.();
      if (mapId != null) void ensureMap(ctx, mapId, false);
    },
    onDeactivate() {
      state.dragging = false;
      state.visited.clear();
      state.terrainStrokeCells.clear();
      state.terrainSelectStart = null;
      state.terrainSelectCurrent = null;
      state.terrainFlatTarget = null;
      state.objStart = null;
      state.objCurrent = null;
    },
  });

  ctx.ui.registerOverlay({
    id: `${MOD_ID}.overlay`,
    zOrder: 25,
    render(c2d, info) { renderOverlay(ctx, c2d, info); },
  });

  ctx.ui.registerPanel({
    id: PANEL_ID,
    title: "2.5D Geometry",
    defaultPosition: "right",
    defaultSize: { width: 420, height: 640 },
    icon: "⬢",
    render(host) {
      const render = () => {
        // V2 keeps the dock as a small human-facing inspector. The actual 2.5D
        // scene opens in a large viewport dialog instead of living in a tiny
        // legacy preview inside this panel.
        const blocked=state.legacyDataBlocked;
        host.innerHTML = `<div style="height:100%;padding:12px;background:var(--bg-primary);color:var(--text-primary);font:12px system-ui"><b>2.5D Geometry UNITY 4.2</b><p style="color:var(--text-tertiary);line-height:1.45">The editor now lives in the large 3D Studio workspace.</p>${blocked?`<div style="padding:9px;border:1px solid #8d444d;border-radius:7px;color:#ffb5bd">Delete <code>Data/VERMEIL2_5D/</code> before continuing.</div>`:''}<button data-open-studio style="width:100%;margin-top:10px;padding:9px">Open 3D Studio</button></div>`;
        host.querySelector('[data-open-studio]')?.addEventListener('click',()=>ctx.ui.openPanel(PREVIEW_PANEL_ID));
      };
      state.panelRefresh = render;
      render();
      return () => {
        if (state.panelRefresh === render) state.panelRefresh = null;
        if (!state.largeViewOpen && !ctx.ui.isPanelOpen?.(PREVIEW_PANEL_ID)) {
          state.preview.canvas = null;
          state.preview.status = null;
        }
      };
    },
  });

  ctx.ui.registerPanel({
    id: PREVIEW_PANEL_ID,
    title: "2.5D Geometry Studio",
    defaultPosition: "below",
    defaultSize: { width: 1180, height: 720 },
    icon: "◩",
    render(host) {
      const render = () => renderLivePreviewPanel(ctx, host);
      state.previewPanelRefresh = render;
      state.previewPanelOpen = true;
      render();
      return () => {
        if (state.previewPanelRefresh === render) state.previewPanelRefresh = null;
        state.previewPanelOpen = false;
        state.topDownCanvas = null;
        state.preview.canvas = null;
        state.preview.status = null;
      };
    },
  });

  // Native Maker Studio integration: Geometry behaves like a real installed mode.
  try {
    ctx.ui.registerShortcut("Alt+G", () => {
      ctx.editor.setTool(TOOL_ID);
      ctx.ui.openPanel(PREVIEW_PANEL_ID);
    });
  } catch (_) {}

  // Familiar delete path: select something and press Delete/Backspace. It only
  // removes Geometry metadata/models; Maker Studio map tiles are never touched.
  const eraseCurrentSelection = () => {
    if (ctx.editor.activeTool?.() !== TOOL_ID) return;
    const mapId = ctx.editor.activeMapId?.(); if(mapId==null)return;
    let changed=false;
    if(state.studioTool==='models'){
      const sel=currentTerrainSelection(ctx,currentGeo(ctx)); if(sel)changed=eraseModelAtCell(ctx,mapId,sel.x0,sel.y0);
    }else{
      const sel=currentTerrainSelection(ctx,currentGeo(ctx)); if(sel)changed=eraseTerrainBounds(ctx,mapId,sel);
    }
    if(changed)void saveMap(ctx,mapId,{authoringOnly:true,skipCompile:true,skipModelCompile:true});
  };
  try { ctx.ui.registerShortcut("Delete", eraseCurrentSelection); } catch (_) {}
  try { ctx.ui.registerShortcut("Backspace", eraseCurrentSelection); } catch (_) {}

  // Keep a visible panel entry as a fallback for Maker Studio builds where
  // project-mod tools are not inserted into the map toolbar until a reload.
  // The panel remains an inspector; selecting Geometry in the toolbar still
  // activates the actual map mode.
  try {
    ctx.ui.showToast?.({
      message: "2.5D Geometry 4.2 loaded: direct 3D model placement + fast non-JSON runtime.",
      level: "info"
    });
  } catch (_) {}

  try {
    ctx.ui.registerContextMenuItem({
      context: "map-tile",
      label: "2.5D Geometry: Seleccionar aquí",
      handler: (info) => {
        state.workspaceMode = "scene";
        state.objTool = false;
        state.sceneTool = "select";
        ctx.editor.setTool(TOOL_ID);
        ctx.ui.openPanel(PREVIEW_PANEL_ID);
        void ensureMap(ctx, info.mapId).then(() => {
          setTerrainSelection(ctx,info.mapId,info.tileX,info.tileY,info.tileX,info.tileY);
          state.panelRefresh?.();
        });
      },
    });
    ctx.ui.registerContextMenuItem({
      context: "map-tile",
      label: "2.5D Geometry: Borrar Geometry aquí",
      handler: (info) => {
        void ensureMap(ctx, info.mapId).then(() => {
          if (eraseTerrainBounds(ctx,info.mapId,{x0:info.tileX,y0:info.tileY,x1:info.tileX,y1:info.tileY}))
            void saveMap(ctx, info.mapId, { authoringOnly: true, skipCompile: true, skipModelCompile: true });
        });
      },
    });
  } catch (_) {}

  ctx.lifecycle.onMapLoad((mapId) => {
    state.previewDirty = true;
    state.legacyReadyByMap.delete(mapId);
    state.sourceUsageByMap.delete(mapId);
    state.preview.usedAssetsByMap.delete(mapId);
    if (ctx.editor.activeTool?.() === TOOL_ID) void ensureMap(ctx, mapId, true);
  });
  ctx.lifecycle.onSave((mapId) => { if (mapId != null) void saveMap(ctx, mapId); });
  ctx.bus.on("map.tile.changed", (e) => {
    state.preview.usedAssetsByMap.delete(e.mapId);
    state.sourceUsageByMap.delete(e.mapId);
    invalidateCellCache(e.mapId, e.x, e.y);
    refreshCompiledCell(ctx, e.mapId, e.x, e.y);
    if (state.legacyReadyByMap.has(e.mapId)) {
      clearTimeout(state.preview.legacyHeightTimer);
      state.preview.legacyHeightTimer = setTimeout(() => updateLegacyHeightForCell(ctx, e.mapId, e.x, e.y), 220);
    }
    if (e.mapId === ctx.editor.activeMapId()) {
      ctx.editor.requestRedraw();
      markPreviewDirty(ctx);
      if (state.previewLive && state.preview.canvas) void ensureChangedCellResources(ctx, e.mapId, e.x, e.y, e.layer).then(() => schedulePreview(ctx,true));
    }
    // Rebuild browser/source inventories only after the user pauses editing.
    scheduleBackgroundMapRefresh(ctx, e.mapId, 480);
  });
  ctx.bus.on("map.batch.changed", (e) => {
    state.preview.usedAssetsByMap.delete(e.mapId);
    state.sourceUsageByMap.delete(e.mapId);
    state.preview.cellEntryCache.clear();
    if (state.legacyReadyByMap.has(e.mapId)) {
      clearTimeout(state.preview.legacyHeightTimer);
      state.preview.legacyHeightTimer = setTimeout(() => rebuildLegacyHeights(ctx, e.mapId), 700);
    }
    if (e.mapId === ctx.editor.activeMapId()) {
      ctx.editor.requestRedraw();
      markPreviewDirty(ctx);
      if (state.previewLive && state.preview.canvas) void ensureVisiblePreviewResources(ctx, e.mapId).then(() => schedulePreview(ctx,true));
    }
    scheduleBackgroundMapRefresh(ctx, e.mapId, 520);
    scheduleSceneCompile(ctx, e.mapId, "batch-change", 650);
  });
  ctx.bus.on("tileset.changed", () => {
    const id = ctx.editor.activeMapId();
    if (id != null) {
      state.preview.usedAssetsByMap.delete(id);
      state.preview.transformedSourceCache.clear();
      ctx.editor.requestRedraw();
      markPreviewDirty(ctx);
      scheduleBackgroundMapRefresh(ctx, id, 500);
    }
  });
  ctx.bus.on("layer.changed", (e) => {
    state.sourceUsageByMap.delete(e.mapId);
    state.preview.cellEntryCache.clear();
    if (e.mapId === ctx.editor.activeMapId()) { ctx.editor.requestRedraw(); markPreviewDirty(ctx); }
    scheduleBackgroundMapRefresh(ctx, e.mapId, 420);
    scheduleSceneCompile(ctx, e.mapId, "layer-change", 560);
  });
  ctx.bus.on("undo", (e) => {
    state.sourceUsageByMap.delete(e.mapId);
    state.preview.usedAssetsByMap.delete(e.mapId);
    state.preview.cellEntryCache.clear();
    if (e.mapId === ctx.editor.activeMapId()) { ctx.editor.requestRedraw(); markPreviewDirty(ctx); }
    scheduleBackgroundMapRefresh(ctx, e.mapId, 360);
    scheduleSceneCompile(ctx, e.mapId, "undo", 480);
  });
  ctx.bus.on("redo", (e) => {
    state.sourceUsageByMap.delete(e.mapId);
    state.preview.usedAssetsByMap.delete(e.mapId);
    state.preview.cellEntryCache.clear();
    if (e.mapId === ctx.editor.activeMapId()) { ctx.editor.requestRedraw(); markPreviewDirty(ctx); }
    scheduleBackgroundMapRefresh(ctx, e.mapId, 360);
    scheduleSceneCompile(ctx, e.mapId, "redo", 480);
  });
  ctx.bus.on("hover.changed", (e) => {
    if(e.mapId===ctx.editor.activeMapId()&&e.x!=null&&e.y!=null){
      const old=state.mapHover; state.mapHover={mapId:e.mapId,x:e.x,y:e.y};
      if(ctx.editor.activeTool?.()===TOOL_ID&&((old?.x)!==e.x||(old?.y)!==e.y))ctx.editor.requestRedraw();
    }else if(state.mapHover){state.mapHover=null;if(ctx.editor.activeTool?.()===TOOL_ID)ctx.editor.requestRedraw();}
    if (!state.preview.followHover || e.mapId !== ctx.editor.activeMapId() || e.x == null || e.y == null) return;
    state.preview.focusX = e.x; state.preview.focusY = e.y;
    if (state.previewLive && state.preview.canvas) schedulePreview(ctx,true); else markPreviewDirty(ctx);
  });
  ctx.bus.on("selection.changed", (e) => {
    if (e.mapId !== ctx.editor.activeMapId()) return;
    if (!state.preview.followHover && e.bounds) {
      // Selection does not force the camera, but causes a redraw so the user can
      // hit "Centrar en cursor 2D" immediately after selecting.
      markPreviewDirty(ctx);
    }
  });

  const active = ctx.editor.activeMapId();
  if (active != null && ctx.editor.activeTool?.() === TOOL_ID) void ensureMap(ctx, active, false);
}

export function deactivate() {
  if (state.preview.raf) cancelAnimationFrame(state.preview.raf);
  if (state.preview.topDownRaf) cancelAnimationFrame(state.preview.topDownRaf);
  if (state.panelRaf) cancelAnimationFrame(state.panelRaf);
  if (state.modelCompileRaf) cancelAnimationFrame(state.modelCompileRaf);
  state.preview.raf = 0;
  state.preview.topDownRaf = 0;
  state.panelRaf = 0;
  state.modelCompileRaf = 0;
  state.modelCompilePending = null;
  disposeAutotileUrls();
  state.preview.cellEntryCache.clear();
  state.preview.canvasPool.length = 0;
  state.preview.tilesetLoading.clear();
  clearTimeout(state.preview.legacyHeightTimer);
  clearTimeout(state.compilerTimer);
  clearTimeout(state.simpleEditTimer);
  clearTimeout(state.assetRefreshTimer);
  clearTimeout(state.sourceRefreshTimer);
  clearTimeout(state.modelSaveTimer);
  state.compilerTimer = 0;
  state.simpleEditTimer = 0;
  state.sourceRefreshTimer = 0;
  state.modelSaveTimer = 0;
  state.preview.canvas = null;
  state.preview.status = null;
  state.topDownCanvas = null;
  state.previewPanelRefresh = null;
}
