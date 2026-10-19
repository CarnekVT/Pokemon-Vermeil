// Keep map tile layers separate from virtual shadow/event rows. No private APIs.
const tileKind = kind => kind === 'native' || kind === 'extended' || kind == null;
export function paintableLayers(layers = [], info = null) {
  const byIndex = new Map();
  for (const row of layers || []) {
    if (!Number.isInteger(row?.index) || row.index < 0 || !tileKind(row.kind)) continue;
    const previous = byIndex.get(row.index);
    if (!previous || (previous.kind !== 'extended' && row.kind === 'extended')) byIndex.set(row.index, row);
  }
  // Older editor builds occasionally omit native layer descriptors.
  for (let index = 0; index < 3; index++) {
    if (!byIndex.has(index) && !(layers || []).some(l => l.index === index && l.kind === 'shadow'))
      byIndex.set(index, {index, kind:'native', name:`Capa ${index + 1}`, visible:true, opacity:1});
  }
  // If layerCount is larger than the enumerated tile layers, preserve unknown
  // valid indices, but never convert a shadow-only descriptor into a tile layer.
  const count = Math.min(100, Math.max(0, Number(info?.layerCount) || 0));
  for (let index = 3; index < count; index++) {
    if (!byIndex.has(index) && !(layers || []).some(l => l.index === index && !tileKind(l.kind)))
      byIndex.set(index, {index, kind:'extended', name:`Capa ${index + 1}`, visible:true, opacity:1});
  }
  return [...byIndex.values()].sort((a,b)=>a.index-b.index);
}
export function layerInfo(layers, index, info) {
  return paintableLayers(layers,info).find(l=>l.index===index) || null;
}
export function choosePaintLayer(layers, info, preferred, active) {
  const available=paintableLayers(layers,info);
  if (available.some(l=>l.index===preferred)) return preferred;
  if (available.some(l=>l.index===active)) return active;
  return available[0]?.index ?? null;
}
export function adjacentPaintLayer(layers, info, current, direction) {
  const available=paintableLayers(layers,info).map(l=>l.index);
  if (!available.length)return null;
  return direction > 0 ? (available.find(l=>l>current)??null) : ([...available].reverse().find(l=>l<current)??null);
}
