import {nativeScreenToTile,nativeScreenRect} from './overlay-transform.js';
// Canvas bridge for Maker Studio's documented [data-ms-part="canvas"] surface.
// No reliance on private React internals or undocumented renderer commands.
export function normalizedViewport(source={}){
  const zoom=Number(source?.zoom);
  const tileSize=Number(source?.tileSize)||32;
  const viewportX=Number.isFinite(Number(source?.viewportX)) ? Number(source.viewportX) : (Number(source?.x)||0);
  const viewportY=Number.isFinite(Number(source?.viewportY)) ? Number(source.viewportY) : (Number(source?.y)||0);
  return {
    mapId:Number.isInteger(source?.mapId)?source.mapId:undefined,
    zoom:Number.isFinite(zoom)&&zoom>0 ? zoom : 1,
    tileSize:tileSize>0 ? tileSize : 32,
    viewportX,
    viewportY,
    canvasWidth:Number(source?.canvasWidth)||0,
    canvasHeight:Number(source?.canvasHeight)||0
  };
}
// Screen-space helpers follow the native tilemap; the overlay draw helpers
// deliberately use a different (pre-zoom) coordinate space.
export function screenToTile(px,py,viewport,tileSize=undefined){
  return nativeScreenToTile(px,py,{...viewport,tileSize:tileSize??viewport?.tileSize});
}
export function tileToScreen(x,y,viewport,tileSize=undefined){
  const r=nativeScreenRect(x,y,1,1,{...viewport,tileSize:tileSize??viewport?.tileSize});
  return {x:r.x,y:r.y};
}
export function tileRectToScreen(x,y,w,h,viewport,tileSize=undefined){
  return nativeScreenRect(x,y,w,h,{...viewport,tileSize:tileSize??viewport?.tileSize});
}
export function validTile(pos,map){
  return !!pos&&Number.isInteger(pos.x)&&Number.isInteger(pos.y)&&
    !!map&&pos.x>=0&&pos.y>=0&&pos.x<map.width&&pos.y<map.height;
}
export function pointerTile(event,rect,viewport,map,hover){
  // Native tile tracking is preferable where available; screenToTile is a fallback.
  const fallback=screenToTile(event.clientX-rect.left,event.clientY-rect.top,viewport);
  if(validTile(hover,map))return {x:hover.x,y:hover.y};
  return validTile(fallback,map)?fallback:null;
}
export function isMapPointer(event){
  // No painting over a UI control sitting on top of the map.
  if(event.target?.closest?.('button,input,textarea,select,[role="dialog"],[role="menu"],[contenteditable="true"]'))return false;
  return true;
}
export function frameSource(def,nowMs,epochMs){
  const frames=Math.max(1,def.frames|0), fps=Math.max(1,Number(def.fps)||1);
  const elapsed=Math.max(0,(nowMs-epochMs)/1000);
  const current=Math.floor(elapsed*fps);
  return def.loop?current%frames:Math.min(frames-1,current);
}
