import {nativeScreenRect} from './overlay-transform.js';
// Mod-only presentation profiles. They NEVER change saved prop FPS or ingame playback.
export const PERF_MODES = Object.freeze({
  full: { label: 'Calidad', mapFps: 24, previewFps: 24, description: 'Animación fluida en el mapa y visor.' },
  balanced: { label: 'Equilibrado', mapFps: 10, previewFps: 15, description: 'Prioriza la edición con menos repintados.' },
  saver: { label: 'Ahorro', mapFps: 4, previewFps: 8, description: 'Menos animación para mapas con muchos props.' },
  static: { label: 'Estático', mapFps: 0, previewFps: 0, description: 'Detiene animaciones; conserva pincel, zoom y edición.' },
});
export function getProfile(mode){return PERF_MODES[mode]||PERF_MODES.balanced;}
export function dueTick(now,last,fps){return fps>0 && (!Number.isFinite(last)||now-last>=1000/fps-0.01);}
export function frameAt(def,now,epoch,mode='full'){
  const fps=Number(def?.fps)||1, frames=Math.max(1,Math.floor(Number(def?.frames)||1));
  const cap=getProfile(mode).mapFps;
  if(cap===0)return 0;
  const quantized=Math.floor(Math.max(0,now-epoch)/(1000/cap))*(1000/cap);
  const elapsed=Math.max(0,Math.floor(quantized*fps/1000));
  return def?.loop ? elapsed%frames : Math.min(frames-1,elapsed);
}
export function visibleMapRect(p,def,info){
  if(!info || !def || !Number.isFinite(info.zoom) || info.zoom<=0)return true;
  const crop=p?.crop||{w:def.width,h:def.height};
  const r=nativeScreenRect(p.x,p.y,crop.w,crop.h,info);
  return r.x+r.w>0&&r.y+r.h>0&&r.x<info.canvasWidth&&r.y<info.canvasHeight;
}

