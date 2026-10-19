// Native tile bridge: write named extra autotiles through Maker Studio's PUBLIC map API.
// These tiles take part in native z-order, visibility, dim mode, map undo, and collision display.
// No overlay participates in persistent native rendering.
export const NATIVE_PREFIX = 'LBDSAP_';
export const NATIVE_TILE_ID = 48; // first RMXP autotile pattern (not 0, the empty tile)

export function safeId(id) {
  const result = String(id || '').normalize('NFKD').replace(/[^a-zA-Z0-9_-]+/g, '_').slice(0, 54);
  if (!result || result === '.' || result === '..') throw new Error('ID de prop inválido');
  return result;
}
export function nativeName(id, x, y) {
  if (!Number.isInteger(x) || x < 0 || !Number.isInteger(y) || y < 0) throw new Error('Celda inválida');
  return `${NATIVE_PREFIX}${safeId(id)}_x${x}_y${y}`;
}
export function nativeFrames(frames) {
  const n = Math.max(1, Math.floor(Number(frames) || 1));
  // Legacy RMXP-compatible single-cell autotile has exactly 3 frames (96×32).
  // Sample source 1/4/5+ frame sequences explicitly; never claim lossless export.
  return [0, Math.round((n-1)/2), n-1];
}
export function nativeCellNames(def, crop) {
  if (!def || !crop || crop.w < 1 || crop.h < 1) throw new Error('Selección inválida');
  const cells=[];
  for(let dy=0;dy<crop.h;dy++) for(let dx=0;dx<crop.w;dx++) {
    const sx=crop.x+dx,sy=crop.y+dy;
    if(sx<0||sy<0||sx>=def.width||sy>=def.height) throw new Error('Fuera del spritesheet');
    cells.push({dx,dy,sx,sy,name:nativeName(def.id,sx,sy)});
  }
  return cells;
}
export function nativeStoredName(map, mapId, layer, x, y) {
  if(layer<3) return map.getNativeTileProperties?.(mapId, layer,x,y)?.autotileName||null;
  return map.readTileData?.(mapId,layer,x,y)?.autotileName||null;
}
export function verifyNativeAPI(ctx, layer) {
  if (!ctx?.map?.writeTile || !ctx?.map?.readTile) throw new Error('Esta versión de Maker Studio no permite escribir tiles desde mods.');
  if(layer<3 && typeof ctx.map.setNativeTileProperties !== 'function') throw new Error('Hace falta la API setNativeTileProperties para las capas 1–3.');
  if(layer<3 && typeof ctx.map.getNativeTileProperties !== 'function') throw new Error('Hace falta la API getNativeTileProperties antes de pintar: impide datos huérfanos.');
  if(layer>=3 && typeof ctx.map.writeTileData !== 'function') throw new Error('Hace falta la API writeTileData para capas extendidas.');
  if(layer>=3 && typeof ctx.map.readTileData !== 'function') throw new Error('Hace falta la API readTileData antes de pintar: impide datos huérfanos.');
}
export function paintNativeCell(map,mapId,layer,x,y,name) {
  if(layer<3) {
    map.writeTile(mapId,layer,x,y,NATIVE_TILE_ID,'Animated Props · tile');
    map.setNativeTileProperties(mapId,layer,x,y,{autotileName:name,autotilePattern:0});
  }else {
    map.writeTileData(mapId,layer,x,y,{tileId:NATIVE_TILE_ID,autotileName:name,opacity:255},'Animated Props · tile');
  }
}
export function clearNativeCell(map,mapId,layer,x,y) {
  if(layer<3) {
    map.writeTile(mapId,layer,x,y,0,'Animated Props · borrar');
    // Remove dangling autotile metadata; a subsequent normal tile must not resurrect it.
    map.setNativeTileProperties(mapId,layer,x,y,{autotileName:'',autotilePattern:0});
  }else map.writeTileData(mapId,layer,x,y,{tileId:0,autotileName:''},'Animated Props · borrar');
}
export function isOwnNativeName(name) {return typeof name === 'string' && name.startsWith(NATIVE_PREFIX);}
// The public map layer list is authoritative when populated, but a few
// studio builds omit extended rows while still exposing them in map.info.
// Never reject an available tile layer only because the Layers panel includes
// custom fog/shadow rows that use another index space.
export function assertNativeLayer(layers, layer, mapInfo = null) {
  if(!Number.isInteger(layer) || layer < 0) throw new Error('Índice de capa inválido.');
  const found=layers.find(v=>v.index===layer && (v.kind==='native'||v.kind==='extended')) || layers.find(v=>v.index===layer);
  if(found?.kind==='shadow' || found?.kind==='event' || found?.kind==='events')
    throw new Error(`Selecciona una capa de tiles: la capa ${layer+1} está identificada como sombras/eventos.`);
  if(found?.visible===false) throw new Error(`La capa ${layer+1} está oculta; actívala antes de pintar.`);
  if(found && (found.kind==='native'||found.kind==='extended')) return true;
  // Fall back ONLY for extended indices proven to exist by the map metadata.
  // Avoid writing to arbitrary shadow/fog rows or phantom layer indices.
  if(layer>=3 && Number.isInteger(mapInfo?.layerCount) && layer<mapInfo.layerCount && !found) return true;
  const available=layers.filter(v=>v.kind==='native'||v.kind==='extended').map(v=>v.index+1).join(', ')||'ninguna';
  throw new Error(`Capa ${layer+1} no disponible para tiles. Capas de tiles detectadas: ${available}; layerCount=${mapInfo?.layerCount??'desconocido'}.`);
}

export function stampNative(map,mapId,layer,x,y,cells,erase=false) {
  // This intentionally follows tile rules: overwrites only the chosen layer;
  // lower and higher layers remain untouched. Eraser removes only our tiles.
  const changed=[];
  for(const c of cells){
    const px=x+c.dx,py=y+c.dy;
    const oldName=nativeStoredName(map,mapId,layer,px,py);
    if(erase){
      if(isOwnNativeName(oldName)) {clearNativeCell(map,mapId,layer,px,py);changed.push({x:px,y:py});}
    } else {paintNativeCell(map,mapId,layer,px,py,c.name);changed.push({x:px,y:py});}
  }
  return changed;
}
