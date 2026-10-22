import {animationFrame} from './animation-mixer.js';
import {frameAt, getProfile} from './performance.js';

// Native-autotile-style dirty detection: once per definition, not placement.
export function visibleFrameSignature(visible,now,{epoch=0,mode='balanced',paused=false,pausedParallelFrame=0}={}) {
  const definitions=new Map();
  for(const row of visible||[]){
    const d=row?.d;
    if(d && !definitions.has(d.id))definitions.set(d.id,d);
  }
  const ticks=[];
  for(const d of definitions.values()){
    const first=Math.max(1,Math.floor(Number(d.frames)||1));
    const second=d.parallel?.enabled && d.parallel?.sheet ?
      Math.max(1,Math.floor(Number(d.parallel.frames)||1)) : 1;
    if(first<=1 && second<=1)continue;
    const primary=first>1?frameAt(d,now,epoch,mode):-1;
    let parallel=-1;
    if(second>1){
      const track=d.parallel;
      if(mode==='static')parallel=0;
      else if(paused && d.timingMode!=='independent')
        parallel=Math.min(second-1,Math.max(0,pausedParallelFrame||0));
      else {
        const cap=getProfile(mode).mapFps;
        const elapsed=Math.max(0,now-epoch);
        const quantized=cap>0?Math.floor(elapsed*cap/1000)/cap:0;
        parallel=animationFrame(track,quantized,track.phase||0);
      }
    }
    ticks.push(d.id+':'+primary+':'+parallel);
  }
  return ticks.join('|');
}
