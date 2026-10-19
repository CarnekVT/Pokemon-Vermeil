// Herramienta no destructiva de diagnóstico: no modifica tiles, mapas ni archivos.
let ctxRef = null;
let enabled = false;
const T = 32;

export function probeRects(info, mapInfo, x, y) {
  const z = Number(info.zoom), ts = Number(info.tileSize) || T;
  const vx = Number(info.viewportX) || 0, vy = Number(info.viewportY) || 0;
  const canvasW = Number(info.canvasWidth)||0, canvasH = Number(info.canvasHeight)||0;
  const mapW = Number(mapInfo?.width)||0, mapH = Number(mapInfo?.height)||0;
  const tw = ts*z;
  const left = (x*ts-vx)*z, top = (y*ts-vy)*z;
  // Official documented overlay formula.
  const official = {x:left,y:top,w:tw,h:tw};
  // Alternative if the renderer already scales the camera offsets.
  const preScaledOffset = {x:x*ts*z-vx,y:y*ts*z-vy,w:tw,h:tw};
  // Alternative if the tile cache is centered in the viewport when it fits.
  const cx = mapW>0 ? Math.max(0,(canvasW-mapW*ts*z)/2) : 0;
  const cy = mapH>0 ? Math.max(0,(canvasH-mapH*ts*z)/2) : 0;
  const centered = {x:left+cx,y:top+cy,w:tw,h:tw};
  // Alternative if the drawing context has already applied zoom/viewport.
  const mapPixels = {x:x*ts,y:y*ts,w:ts,h:ts};
  return {official,preScaledOffset,centered,mapPixels,centering:{x:cx,y:cy}};
}
function fmt(n) {return Number.isFinite(n) ? (Math.round(n*100)/100).toString() : '?';}
function outlined(gc, r, color, label, reset=false) {
  gc.save();
  if(reset && typeof gc.setTransform === 'function')gc.setTransform(1,0,0,1,0,0);
  gc.globalAlpha=1;
  gc.strokeStyle=color;gc.lineWidth=2;gc.setLineDash([]);
  gc.strokeRect(r.x+1,r.y+1,Math.max(0,r.w-2),Math.max(0,r.h-2));
  gc.fillStyle=color;
  gc.fillRect(r.x+Math.max(0,r.w/2-2),r.y+Math.max(0,r.h/2-2),4,4);
  gc.font='bold 11px monospace';
  gc.fillText(label,Math.max(0,r.x+2),Math.max(10,r.y-4));
  gc.restore();
}
function hud(gc, info, matrix, mapInfo, hover, center){
  gc.save();
  if(typeof gc.setTransform === 'function')gc.setTransform(1,0,0,1,0,0);
  const lines=[
    'ZOOM INSPECTOR — solo lectura',
    `Mapa ${info.mapId} (${mapInfo?.width||'?'}x${mapInfo?.height||'?'})   tile ${hover.x},${hover.y}`,
    `zoom=${fmt(info.zoom)}  tileSize=${info.tileSize}  off=${fmt(info.viewportX)},${fmt(info.viewportY)}`,
    `canvas=${info.canvasWidth}x${info.canvasHeight}  center candidate=${fmt(center.x)},${fmt(center.y)}`,
    `Canvas CTM=${matrix?`${fmt(matrix.a)},${fmt(matrix.b)},${fmt(matrix.c)},${fmt(matrix.d)},${fmt(matrix.e)},${fmt(matrix.f)}`:'sin acceso'}`,
    'Azul: API | Rojo: API con CTM neutra | Verde: offset escalado',
    'Amarillo: centrado | Magenta: coordenadas sin escalar'
  ];
  const lineHeight=16;
  gc.font='12px monospace';
  const w=Math.min(Number(info.canvasWidth)||650,Math.max(...lines.map(s=>gc.measureText(s).width))+24);
  gc.fillStyle='rgba(6,13,27,0.85)';
  gc.fillRect(8,8,w,lines.length*lineHeight+12);
  gc.fillStyle='#fff';
  lines.forEach((s,i)=>gc.fillText(s,16,28+i*lineHeight));
  gc.restore();
}
function renderOverlay(gc, info){
  if(!enabled || !ctxRef || !info || !Number.isFinite(info.zoom) || info.zoom<=0)return;
  const hover=ctxRef.editor.hoverTile?.();
  if(!Number.isInteger(hover?.x)||!Number.isInteger(hover?.y))return;
  const mapInfo=ctxRef.map.info?.(info.mapId);
  const rects=probeRects(info,mapInfo,hover.x,hover.y);
  const ctm=typeof gc.getTransform==='function'?gc.getTransform():null;
  outlined(gc,rects.official,'#249bff','API');
  outlined(gc,rects.official,'#ff515f','CTM neutra',true);
  outlined(gc,rects.preScaledOffset,'#27ef8a','offset x zoom');
  outlined(gc,rects.centered,'#ffe54a','centrado');
  outlined(gc,rects.mapPixels,'#eb65e9','sin zoom');
  hud(gc,info,ctm,mapInfo,hover,rects.centering);
}
export function activate(ctx){
  ctxRef=ctx;
  ctx.menu.registerMenuItem({
    menu:'Mods',label:'Diagnóstico de zoom Animated Props (activar/desactivar)',
    handler:()=>{
      enabled=!enabled;
      ctx.ui.showToast?.({message:enabled?'Zoom Inspector activado: mueve el ratón a un tile y haz captura.':'Zoom Inspector desactivado.'});
      ctx.editor.requestRedraw?.();
    }
  });
  ctx.ui.registerOverlay({id:'lbds.ap-zoom-inspector',zOrder:200,render:renderOverlay});
  ctx.bus.on('hover.changed',()=>{if(enabled)ctx.editor.requestRedraw?.();});
  ctx.bus.on('viewport.changed',()=>{if(enabled)ctx.editor.requestRedraw?.();});
}
export function deactivate(){ctxRef=null;enabled=false;}
