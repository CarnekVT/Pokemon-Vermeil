import {fxDuration} from "./scene-fx.js";
import {clipLength} from "./animation.js";
export function duration(c){
  if(["image_transform","scene_fx","scene_fx_stop","scene_backdrop"].includes(c.type))return fxDuration(c);
  if(c.type==="parallel_anchor")return Math.max(0,Number(c.frames)||0);
  if(c.type==="fade_bgm")return Math.max(1,Math.round((Number(c.fadeSeconds)||0)*60));
  if(c.type==="end_scene")return Math.max(1,(Number(c.holdFrames)||0)+(c.endStyle==="fade"?(Number(c.fadeFrames)||0):0)+(Number(c.breathFrames)||0));
  if(c.type==="image_clip")return clipLength(c);
  if(c.type==="wait")return Math.max(0,Number(c.frames)||0);
  if(/fade|white|textbox/.test(c.type))return Math.max(1,Number(c.duration??c.fade)||10);
  if(["show","show_floating","float_sprite","hide","hide_all"].includes(c.type))return Math.max(1,Number(c.fade)||1);
  if(c.type==="treatment_input")return 68; // entrada/salida, sin contabilizar la espera del usuario
  if(c.type==="script"){const loops=[...String(c.code||"").matchAll(/(\d+)\.times\s+do/g)];return loops.length?loops.reduce((n,m)=>n+Number(m[1]),0):6;}
  if(["text_inline","treatment_text","show_centered_text"].includes(c.type)){
    const speed={instant:999,fast:4.4,normal:1.5,slow:.7,very_slow:.15,crawl:.20}[c.speed||"normal"]||1.5;
    const txt=c.type==="treatment_text"?(c.neutro||c.masculino||c.femenino||""):String(c.text||"");
    return Math.max(1,Math.ceil(txt.length/speed)+((txt.match(/\.\.\./g)||[]).length*42)+10);
  }
  return 6;
}
export const overlapRoots=new Set(["image_clip","wait","parallel_anchor"]);
const lanes={image_transform:"transform",scene_fx:"fx",scene_fx_stop:"fx_stop",scene_backdrop:"screen",end_scene:"control",next_scene:"control",common_event:"control",wait_confirm:"dialog",set_switch:"control",set_variable:"control",text_inline:"dialog",treatment_text:"dialog",show_centered_text:"dialog",hide_centered_text:"dialog",show_textbox:"textbox",hide_textbox:"textbox",textbox_style:"dialog",bgm:"audio",bgs:"audio",se:"audio",stop_bgm:"audio",fade_bgm:"audio",stop_bgs:"audio",fade_from_black:"screen",fade_to_black:"screen",to_white:"screen",from_white:"screen",show:"visual",hide:"visual",show_floating:"visual",start_scrolling:"visual",stop_scrolling:"visual",start_aura:"visual",stop_aura:"visual"};
export const overlapLane=c=>!c?.sourceRuby&&!c?.store?(c?.type==="image_clip"?"image:"+(c.id||"new"):c?.type==="scene_fx"?"fx:"+(c.id||"new"):c?.type==="scene_fx_stop"?"fx_stop:"+(c.targetId||"all"):c?.type==="image_transform"?"transform:"+(c.targetId||c.id):c?.type==="wait"?"wait:"+(c.id||"new"):lanes[c?.type]||null):null;
export const frameValue=v=>Math.max(0,Math.round((Number(String(v).trim().replace(",","."))||0)*60));
export function timelineGroups(scene){
 const commands=scene.commands||[],byId=new Map(commands.map(c=>[c.id,c])),children=new Map(),attached=new Set();
 for(const c of commands){const root=byId.get(c.overlapParent);if(root&&root!==c&&overlapRoots.has(root.type)&&!root.overlapParent&&overlapLane(c)){if(!children.has(root.id))children.set(root.id,[]);children.get(root.id).push(c);attached.add(c.id)}}
 let start=0;const groups=[];
 for(const root of commands){if(attached.has(root.id))continue;const length=Math.max(1,duration(root)),events=(children.get(root.id)||[]).map(c=>({c,offset:Math.max(0,Math.min(360000,Math.round(Number(c.offsetFrames)||0))),lane:overlapLane(c),length:Math.max(1,duration(c))})).sort((a,b)=>a.offset-b.offset||Number(!!a.c.afterId)-Number(!!b.c.afterId));
 const free={},ends=new Map([[root.id,length]]),pending=events.slice(),ordered=[];while(pending.length){let i=pending.findIndex(e=>!e.c.afterId||!events.some(x=>x!==e&&x.c.id===e.c.afterId)||ends.has(e.c.afterId));if(i<0)i=0;const e=pending.splice(i,1)[0];e.after=ends.has(e.c.afterId)?e.c.afterId:null;e.delay=e.after?Math.max(0,Math.round(Number(e.c.afterDelay)||0)):0;e.requested=e.offset;e.offset=Math.max(e.offset,free[e.lane]||0,(ends.get(e.after)||0)+e.delay);free[e.lane]=e.offset+e.length;ends.set(e.c.id,e.offset+e.length);ordered.push(e)}events.splice(0,events.length,...ordered);
 const total=Math.max(length,...events.map(e=>e.offset+e.length));groups.push({root,start,length,events,total});start+=total}
 return groups;
}
export function layoutTimeline(scene){const groups=timelineGroups(scene),entries=[];for(const g of groups){entries.push({c:g.root,start:g.start,length:g.length,group:g});for(const e of g.events)entries.push({c:e.c,start:g.start+e.offset,length:e.length,group:g,parallel:true,requested:g.start+e.requested})}return {groups,entries,total:groups.length?groups.at(-1).start+groups.at(-1).total:0}}
export function anchorAt(scene,frame){return timelineGroups(scene).find(g=>overlapRoots.has(g.root.type)&&frame>=g.start&&frame<g.start+g.total)||null}

export function ensureAnchorAt(scene,frame,makeAnchor){
 const g=timelineGroups(scene).find(g=>frame>=g.start&&frame<g.start+g.total);
 if(!g)return null;if(overlapRoots.has(g.root.type))return g;if(!overlapLane(g.root))return null;
 const old=g.root,anchor=makeAnchor();anchor.frames=0;
 scene.commands.splice(scene.commands.indexOf(old),0,anchor);
 for(const c of scene.commands)if(c.overlapParent===old.id)c.overlapParent=anchor.id;
 old.overlapParent=anchor.id;old.offsetFrames=0;
 return timelineGroups(scene).find(x=>x.root===anchor);
}
export function canLinkAction(scene,action,dependency){
 if(!action||!dependency||action===dependency||["parallel_anchor","section","end_scene","next_scene"].includes(dependency.type))return false;
 const seen=new Set([action.id]);let d=dependency;
 while(d){if(seen.has(d.id))return false;seen.add(d.id);d=scene.commands.find(x=>x.id===d.afterId)}
 return true;
}
export function linkAfterAction(scene,action,dependency,makeAnchor){
 if(!canLinkAction(scene,action,dependency))return false;
 const commands=scene.commands,moving=[action],ids=new Set([action.id]);
 for(let i=0;i<moving.length;i++)for(const c of commands)if(c.afterId===moving[i].id&&!ids.has(c.id)){ids.add(c.id);moving.push(c)}
 if(ids.has(dependency.id))return false;
 const depEntry=layoutTimeline(scene).entries.find(x=>x.c===dependency);if(!depEntry)return false;
 if(moving.some(c=>!overlapLane(c))&&(depEntry.parallel||depEntry.group.events.length))return false;
 for(const item of moving){
   const children=commands.filter(c=>c.overlapParent===item.id&&!ids.has(c.id));
   if(children.length){const anchor=makeAnchor();anchor.frames=0;commands.splice(commands.indexOf(item),0,anchor);for(const child of children)child.overlapParent=anchor.id}
   delete item.overlapParent;delete item.offsetFrames;
 }
 const entry=layoutTimeline(scene).entries.find(x=>x.c===dependency);if(!entry)return false;
 let group=entry.group;
 if(overlapLane(dependency)&&!overlapRoots.has(group.root.type))group=ensureAnchorAt(scene,entry.start,makeAnchor)||group;
 const concurrent=overlapRoots.has(group.root.type)&&moving.every(c=>overlapLane(c));
 for(const item of moving)commands.splice(commands.indexOf(item),1);
 action.afterId=dependency.id;
 let insert=commands.indexOf(concurrent?dependency:group.root)+1;
 const offset=entry.parallel?Math.max(0,(entry.requested??entry.start)-entry.group.start):0;
 for(const item of moving){if(concurrent){item.overlapParent=group.root.id;item.offsetFrames=offset}commands.splice(insert++,0,item)}
 return true;
}
export function linkAfterDialogue(scene,action,dialogue,makeAnchor){return ["text_inline","treatment_text"].includes(dialogue?.type)&&linkAfterAction(scene,action,dialogue,makeAnchor)}
export function moveTimed(scene,action,frame,makeAnchor){
 const commands=scene.commands,layout=layoutTimeline(scene),entry=layout.entries.find(e=>e.c.id===action.id);
 if(!entry||!overlapLane(action)||action.afterId)return false;
 frame=Math.max(0,Math.min(360000,Math.round(frame)));
 if(frame===entry.start)return true;
 let target=layout.groups.find(g=>frame>=g.start&&frame<g.start+g.total&&(overlapRoots.has(g.root.type)||overlapLane(g.root)))
   || (frame>=layout.total&&overlapRoots.has(layout.groups.at(-1)?.root.type)?layout.groups.at(-1):null);
 if(!target)return false;
 const source=entry.group;
 // Explicit confirmation links cannot span scheduler groups.
 if(target!==source&&(commands.some(c=>c.afterId===action.id)||action.afterId))return false;
 if(!overlapRoots.has(target.root.type)){if(target.root===action){const anchor=makeAnchor();anchor.frames=source.total;commands.splice(commands.indexOf(action),0,anchor);action.overlapParent=anchor.id;action.offsetFrames=frame-source.start;return true}target=ensureAnchorAt(scene,frame,makeAnchor);if(!target)return false}
 let root=target.root;
 if(source.root===action){
   const anchor=makeAnchor();anchor.frames=source.total;
   commands.splice(commands.indexOf(action),0,anchor);
   for(const child of commands)if(child.overlapParent===action.id)child.overlapParent=anchor.id;
   if(target===source)root=anchor;
 }
 action.overlapParent=root.id;
 action.offsetFrames=Math.max(0,frame-target.start);
 return true;
}
