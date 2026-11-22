// BAS performance preflight v1 — deterministic, allocation-bounded, read-only.
// Estimates demands BEFORE playback. These are not measured FPS, GPU memory or a
// promise that a device can display a given number of particles.
export const BAS_PERFORMANCE_LIMITS=Object.freeze({playingPreview:240,pausedPreview:500,runtime:240,analysisFrames:6000});
const num=(x,f=0)=>Number.isFinite(Number(x))?Number(x):f;
const list=x=>Array.isArray(x)?x:[];
const safe=(x,min,max)=>Math.max(min,Math.min(max,x));
const clampFrame=(x,max)=>safe(Math.floor(num(x)),0,max);
const emitter=clip=>!!clip?.pbs && !!clip.pbs.emitter && String(clip.pbs.emitter).toLowerCase()!=="none";
const frame=x=>num(x?.frame);
const sorted=a=>list(a).slice().sort((a,b)=>frame(a)-frame(b));
function scalar(pbs,commands,name,at,fallback) {
  const keys=commands[name]||[];
  let v=num(pbs[name],fallback),prev=v;
  for (const k of keys) {
    const start=frame(k),duration=Math.max(0,num(k.duration));
    if (start>at)break;
    const target=num(k.value,v);
    if (duration>0 && at<start+duration) {
      // The runtime can apply other easing modes. Linear here is a model,
      // not a claim of exact reproduction.
      return prev+(target-prev)*safe((at-start)/duration,0,1);
    }
    v=target;prev=v;
  }
  return v;
}
function lifetime(clip) {
  const p=clip.pbs||{},t=String(p.emitter||"").toLowerCase().replace(/[^a-z]/g,"");
  const life=p.simpleParticleLife;
  if(life && typeof life==="object")return {frames:safe(num(life.duration,12),1,6000),confidence:"high"};
  if(t==="risescatter")return {frames:safe(num(p.riseFrames,6)+num(p.scatterFrames,6),1,6000),confidence:"medium"};
  if(t==="energyin"||t==="energyout")return {frames:safe(num(p.energyTravelFrames,16)+4,1,6000),confidence:"medium"};
  if(t==="drain")return {frames:safe(num(p.drainTravelFrames,14)+4,1,6000),confidence:"medium"};
  const commands=p.commands||{};
  let maxKey=0;
  for(const seq of Object.values(commands)) for(const c of list(seq))maxKey=Math.max(maxKey,frame(c)+num(c.duration));
  // When the particle remains visible the Ruby runtime keeps it until disposal.
  const span=Math.max(1,num(clip.endFrame)-num(clip.startFrame));
  return {frames:safe(Math.max(span,maxKey),1,6000),confidence:"low"};
}
function emissionWindows(clip,duration) {
  const events=sorted((clip.pbs?.emitterCommands||{}).emitting);
  let begin=null;const windows=[];
  for(const e of events) {
    const f=frame(e);
    if(begin!==null){windows.push([begin,Math.min(duration,f-1e-7)]);begin=null;}
    if(e.value)begin=f;
  }
  if(begin!==null)windows.push([begin,duration]);
  return windows.filter(([a,b])=>a<=b && b>=0 && a<=duration);
}
function targetLocal(clip) {
  const keys=list(clip.positionKeys);
  return keys.some(k=>["target_battler","target_sprite","target"].includes(String(k?.point?.anchor||"").toLowerCase())) ||
    /target/i.test(String(clip.pbs?.focus||""));
}
function replicaCount(clip,source,party) {
  const forced=String(clip.replicateTo||"none").toLowerCase();
  const scope=String(source.targetScope||"single_foe").toLowerCase();
  const enabled=forced!=="none" || (source.autoReplicateAffected===true && targetLocal(clip));
  if(!enabled)return 1;
  if(["all_battlers","both_sides","everyone"].includes(forced) || scope==="all_battlers")return party*2;
  if(["multiple_foes","multiple_users","all_foes","all_allies","adjacent_others"].includes(scope) || forced!=="none")return party;
  return 1;
}
function analyzeScenario(animation,party,maxFrames) {
  const duration=Math.max(1,num(animation.duration,30)),fps=Math.max(1,num(animation.fps,20));
  const frames=Math.min(Math.ceil(duration),maxFrames);
  const source=animation.source||{},clips=list(animation.tracks).flatMap(t=>list(t?.clips));
  const active=new Float64Array(frames+2),birthsByFrame=new Float64Array(frames+2);
  let totalSpawns=0,emitterCount=0,estimatedKeyframes=0,uncertain=0,activeElements=0;
  const costly=[];
  for(const clip of clips) {
    if(!clip)continue;
    estimatedKeyframes+=list(clip.positionKeys).length+list(clip.visibleKeys).length+
      Object.values(clip.valueKeys||{}).reduce((s,v)=>s+list(v).length,0);
    if(!emitter(clip)) {
      activeElements+=Math.max(0,Math.min(frames,num(clip.endFrame,frames))-Math.max(0,num(clip.startFrame)))/frames;
      continue;
    }
    emitterCount++;
    const p=clip.pbs||{},commands={};
    for(const [key,sequence] of Object.entries(p.emitterCommands||{}))commands[key]=sorted(sequence);
    const life=lifetime(clip);
    if(life.confidence==="low")uncertain++;
    const copies=replicaCount(clip,source,party),windows=emissionWindows(clip,Math.min(num(clip.endFrame,duration),duration));
    let own=0,ownPeak=0,ownLive=0;
    const ownDelta=new Float64Array(frames+2);
    for(const [start,stop] of windows) {
      // Preserve each SetEmitting restart; no per-particle objects or huge loops.
      let due=1;
      for(let f=Math.max(0,Math.ceil(start));f<=Math.min(frames,Math.floor(stop));f++){
        const rate=safe(scalar(p,commands,"emitterRate",f,1),.01,1000000);
        const intensity=safe(Math.round(scalar(p,commands,"emitterIntensity",f,1)),1,100);
        const count=Math.floor(due+1e-8);
        due=Math.max(0,due-count)+rate/fps;
        if(!count)continue;
        const spawned=count*intensity*copies;
        const exit=Math.min(frames+1,f+Math.ceil(life.frames));
        own+=spawned;totalSpawns+=spawned;
        birthsByFrame[f]+=spawned;
        active[f]+=spawned;active[exit]-=spawned;
        ownDelta[f]+=spawned;ownDelta[exit]-=spawned;
      }
    }
    for(let f=0;f<=frames;f++){ownLive+=ownDelta[f];ownPeak=Math.max(ownPeak,ownLive);}
    if(own>0)costly.push({id:clip.id||null,name:clip.name||"Emitter",spawns:Math.round(own),peak:Math.round(ownPeak),copies,life:life.frames,confidence:life.confidence});
  }
  let live=0,peak=0,peakFrame=0,maxBirth=0;const density=[];
  for(let f=0;f<=frames;f++) {
    live=Math.max(0,live+active[f]);
    if(live>peak){peak=live;peakFrame=f;}
    maxBirth=Math.max(maxBirth,birthsByFrame[f]);
    if(f%Math.max(1,Math.ceil(frames/120))===0)density.push(Math.round(live));
  }
  costly.sort((a,b)=>b.peak-a.peak);
  const budget=BAS_PERFORMANCE_LIMITS.runtime;
  return {party,format:party+"v"+party,analyzedFrames:frames,partial:duration>frames,
    totalSpawns:Math.round(totalSpawns),peak:Math.round(peak),peakFrame,
    maxBirthPerFrame:Math.round(maxBirth),emitterCount,keyframes:estimatedKeyframes,
    estimatedStaticElements:Number(activeElements.toFixed(1)),
    overBudget:peak>budget,overBy:Math.max(0,Math.round(peak-budget)),
    uncertainty:uncertain,topEmitters:costly.slice(0,8),density};
}
export function preflightBasAnimation(animation,options={}) {
  const a=animation||{},maxFrames=safe(Math.round(num(options.maxFrames,BAS_PERFORMANCE_LIMITS.analysisFrames)),1,BAS_PERFORMANCE_LIMITS.analysisFrames);
  const scenarios=[1,2,3].map(p=>analyzeScenario(a,p,maxFrames));
  const worst=scenarios.reduce((w,c)=>c.peak>w.peak?c:w,scenarios[0]);
  const issues=[],recommendations=[];
  if(worst.peak>BAS_PERFORMANCE_LIMITS.runtime) {
    issues.push({severity:"warning",code:"PARTICLE_OVER_BUDGET",message:"El peor escenario estimado ("+worst.format+") alcanza "+worst.peak+" partículas simultáneas; el runtime limita la visualización a "+BAS_PERFORMANCE_LIMITS.runtime+" por emitter, no globalmente."});
    recommendations.push("Repartir impactos y emisiones entre frames o escalonar los emitters simultáneos; no basta con aumentar el límite.");
  }
  if(worst.maxBirthPerFrame>120)recommendations.push("Pico de "+worst.maxBirthPerFrame+" partículas nuevas en un frame: bajar intensidad o escalonar spawns reduce trabajo inmediato.");
  if(worst.totalSpawns>10000)recommendations.push("Más de 10.000 nacimientos estimados: reducir tasa y duración o reutilizar efectos similares; revisar CPU/GC en el juego.");
  if(worst.uncertainty)issues.push({severity:"info",code:"LIFETIME_MODEL",message:"La vida útil de "+worst.uncertainty+" emitters se ha estimado sin la curva final de visibilidad/opacidad. El pico es orientativo."});
  if(worst.partial)issues.push({severity:"info",code:"ANALYSIS_TRUNCATED",message:"Timeline demasiado extensa: se analizaron sólo "+worst.analyzedFrames+" frames."});
  if(!recommendations.length)recommendations.push("Sin excesos evidentes por número de partículas; la prueba en mkxp sigue siendo necesaria para medir FPS, memoria y GPU.");
  return {name:String(a.name||"Animación"),scenarios,worst,issues,recommendations,
    limits:BAS_PERFORMANCE_LIMITS,method:"Modelado por frame de nacimientos y vida útil, sin crear partículas. Estimación; no benchmark."};
}
export function preflightBasProject(project,options={}) {
  const animations=list(project?.animations).map(a=>({id:a.id,name:a.name,report:preflightBasAnimation(a,options)}));
  return {animations,warnings:animations.reduce((s,x)=>s+x.report.issues.filter(i=>i.severity==="warning").length,0)};
}
