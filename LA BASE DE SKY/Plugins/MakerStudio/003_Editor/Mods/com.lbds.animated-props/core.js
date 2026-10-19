import {normalizeParallel} from './animation-mixer.js';
export const FILE = 'Data/AnimatedProps/objects.json';
export const ART_DIR = 'Graphics/AnimatedProps';
export const DEFAULT_CELL = Object.freeze({ passage: 0, priority: 0, terrainTag: 0 });

export function slug(v) {
  return String(v || '').normalize('NFKD').replace(/[\u0300-\u036f]/g, '')
    .toLowerCase().replace(/[^a-z0-9_-]+/g, '_').replace(/^_+|_+$/g, '').slice(0, 64);
}
export function cleanSheet(value) {
  const s = String(value || '').trim();
  if (!/^[\p{L}\p{N}_() .-]+\.png$/iu.test(s) || s === '.' || s === '..')
    throw new Error('La imagen debe ser un nombre PNG, sin rutas. Ejemplo: Molino.png');
  return s;
}
export function positive(value, name, min, max) {
  const n = Number(value);
  if (!Number.isInteger(n) || n < min || n > max)
    throw new Error(`${name}: usa un entero entre ${min} y ${max}.`);
  return n;
}
export function cropFor(def, crop) {
  const w = def.width, h = def.height;
  const x = Math.max(0, Math.min(w - 1, Math.trunc(Number(crop?.x)||0)));
  const y = Math.max(0, Math.min(h - 1, Math.trunc(Number(crop?.y)||0)));
  const cw = Math.max(1, Math.min(w - x, Math.trunc(Number(crop?.w)||w)));
  const ch = Math.max(1, Math.min(h - y, Math.trunc(Number(crop?.h)||h)));
  return {x,y,w:cw,h:ch};
}
export function placementSize(def,placement) {
  const c=cropFor(def,placement?.crop);
  return {width:c.w,height:c.h};
}
export function defaultData() { return { schema: 1, definitions: [], placements: {} }; }
export function normalizeCell(cell) {
  const c = cell && typeof cell === 'object' ? cell : {};
  return {
    passage: (Number(c.passage) || 0) & 0xcf, // 0x0f direction; 0x40 bush; 0x80 counter
    priority: Math.max(0, Math.min(5, Number(c.priority) || 0)) | 0,
    terrainTag: Math.max(0, Math.min(999, Number(c.terrainTag) || 0)) | 0,
  };
}
export function makeDefinition(raw = {}) {
  const width = positive(raw.width ?? 4, 'Ancho', 1, 32);
  const height = positive(raw.height ?? 4, 'Alto', 1, 32);
  const frames = positive(raw.frames ?? 4, 'Fotogramas', 1, 64);
  const fps = positive(raw.fps ?? 6, 'FPS', 1, 60);
  const id = slug(raw.id || raw.name);
  if (!id) throw new Error('El ID del objeto no puede estar vacío.');
  const sheet = cleanSheet(raw.sheet);
  const cells = Array.from({length: width * height}, (_, i) => normalizeCell(raw.cells?.[i]));
  return { id, name: String(raw.name || id).trim().slice(0, 100), sheet,
    width, height, frames, fps, cells, loop: raw.loop !== false,
    timingMode:raw.timingMode==='independent'?'independent':'synchronized',
    parallel:normalizeParallel(raw.parallel) };
}
export function normalizeData(raw) {
  const input = raw && typeof raw === 'object' ? raw : defaultData();
  if (input.schema !== 1) throw new Error(`Formato de datos no reconocido: ${input.schema}`);
  const definitions = (Array.isArray(input.definitions) ? input.definitions : []).map(makeDefinition);
  const ids = new Set();
  for (const d of definitions) {
    if (ids.has(d.id)) throw new Error(`ID de objeto duplicado: ${d.id}`);
    ids.add(d.id);
  }
  const placements = {};
  for (const [key, list] of Object.entries(input.placements || {})) {
    if (!/^\d+$/.test(key) || !Array.isArray(list)) continue;
    placements[String(+key)] = list.filter(p => p && typeof p === 'object' && ids.has(String(p.defId)) &&
        Number.isInteger(p.x) && Number.isInteger(p.y) && p.x >= 0 && p.y >= 0)
      .map(p => ({id: String(p.id || ''), defId: String(p.defId), x: p.x, y: p.y,
        layer: Math.max(0, Math.min(99, Number(p.layer) || 0)) | 0,
        ...(p.crop ? {crop:cropFor(definitions.find(d=>d.id===p.defId),p.crop)} : {}) }));
  }
  return { schema: 1, definitions, placements };
}
export function validatePosition(def, x, y, info, crop=null) {
  const r=cropFor(def,crop);
  return x >= 0 && y >= 0 && x + r.w <= info.width && y + r.h <= info.height;
}
export function getPlacedCell(data, mapId, x, y) {
  const list = data.placements[String(mapId)] || [];
  for (const entry of list.map((p,i)=>({p,i})).sort((a,b)=>(b.p.layer||0)-(a.p.layer||0)||b.i-a.i)) {
    const p=entry.p;
    const d = data.definitions.find(v => v.id === p.defId);
    if (!d) continue;
    const r=cropFor(d,p.crop);
    if (x >= p.x && y >= p.y && x < p.x + r.w && y < p.y + r.h)
      return { placement: p, definition: d, cell: d.cells[(r.y+y-p.y)*d.width+r.x+x-p.x] };
  }
  return null;
}
export function placementAt(data, mapId, x, y) {
  return getPlacedCell(data, mapId, x, y)?.placement || null;
}
