// Frame clock shared by the two tracks. Visual FPS throttling belongs to the
// caller; it must never change how the actual sequence is timed.
export function phaseFromId(id, frames) {
  const count = Math.max(1,Math.trunc(Number(frames)||1));
  let hash=2166136261;
  for(const b of new TextEncoder().encode(String(id??''))){hash ^= b;hash=Math.imul(hash,16777619)>>>0;}
  return hash % count;
}
export function normalizeParallel(raw) {
  const p=raw&&typeof raw==='object'?raw:{};
  const numeric=(v,def,min,max)=>Math.min(max,Math.max(min,Number.isFinite(Number(v))?Math.round(Number(v)):def));
  return {
    enabled:p.enabled===true,
    sheet:String(p.sheet||'').trim(),
    frames:numeric(p.frames,4,1,64),
    fps:numeric(p.fps,6,1,60),
    opacity:numeric(p.opacity,100,0,100),
    loop:p.loop!==false,
    phase:numeric(p.phase,0,0,63)
  };
}
export function animationFrame(track,seconds,phase=0) {
  const frames=Math.max(1,Math.floor(Number(track?.frames)||1));
  const fps=Math.max(1,Number(track?.fps)||1);
  const elapsed=Math.max(0,Math.floor(Math.max(0,seconds)*fps));
  const step=elapsed+Math.trunc(phase);
  return track?.loop===false?Math.min(frames-1,step):((step%frames)+frames)%frames;
}
export function placementFrame(track,seconds,placement,mode='synchronized',offset=0) {
  const phase=Number(offset||0)+(mode==='independent'?phaseFromId(placement?.id||`${placement?.x}/${placement?.y}/${placement?.layer}`,track?.frames):0);
  return animationFrame(track,seconds,phase);
}
export function expectedTrackDimensions(def,track){
  return {width:def.width*32*track.frames,height:def.height*32};
}
