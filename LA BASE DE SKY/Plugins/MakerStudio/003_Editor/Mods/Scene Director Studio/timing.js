import {clipLength} from "./animation.js";
export function duration(c){
  if(c.type==="parallel_anchor")return 0;
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
const lanes={end_scene:"control",next_scene:"control",common_event:"control",wait_confirm:"dialog",set_switch:"control",set_variable:"control",text_inline:"dialog",treatment_text:"dialog",show_centered_text:"dialog",hide_centered_text:"dialog",show_textbox:"dialog",hide_textbox:"dialog",textbox_style:"dialog",bgm:"audio",bgs:"audio",se:"audio",stop_bgm:"audio",stop_bgs:"audio",fade_from_black:"screen",fade_to_black:"screen",to_white:"screen",from_white:"screen",show:"visual",hide:"visual",show_floating:"visual",start_scrolling:"visual",stop_scrolling:"visual",start_aura:"visual",stop_aura:"visual"};
export const overlapLane=c=>!c?.sourceRuby&&!c?.store?(c?.type==="image_clip"?"image:"+(c.id||"new"):lanes[c?.type]||null):null;
export const frameValue=v=>Math.max(0,Math.round((Number(String(v).trim().replace(",","."))||0)*60));
export function timelineGroups(scene){
 const commands=scene.commands||[],byId=new Map(commands.map(c=>[c.id,c])),children=new Map(),attached=new Set();
 for(const c of commands){const root=byId.get(c.overlapParent);if(root&&root!==c&&overlapRoots.has(root.type)&&!root.overlapParent&&overlapLane(c)){if(!children.has(root.id))children.set(root.id,[]);children.get(root.id).push(c);attached.add(c.id)}}
 let start=0;const groups=[];
 for(const root of commands){if(attached.has(root.id))continue;const length=Math.max(1,duration(root)),events=(children.get(root.id)||[]).map(c=>({c,offset:Math.max(0,Math.min(360000,Math.round(Number(c.offsetFrames)||0))),lane:overlapLane(c),length:Math.max(1,duration(c))})).sort((a,b)=>a.offset-b.offset||Number(!!a.c.afterId)-Number(!!b.c.afterId));
 const free={},ends=new Map(),pending=events.slice(),ordered=[];while(pending.length){let i=pending.findIndex(e=>!e.c.afterId||!events.some(x=>x!==e&&x.c.id===e.c.afterId)||ends.has(e.c.afterId));if(i<0)i=0;const e=pending.splice(i,1)[0];e.after=ends.has(e.c.afterId)?e.c.afterId:null;e.requested=e.offset;e.offset=Math.max(e.offset,free[e.lane]||0,ends.get(e.after)||0);free[e.lane]=e.offset+e.length;ends.set(e.c.id,e.offset+e.length);ordered.push(e)}events.splice(0,events.length,...ordered);
 const total=Math.max(length,...events.map(e=>e.offset+e.length));groups.push({root,start,length,events,total});start+=total}
 return groups;
}
export function layoutTimeline(scene){const groups=timelineGroups(scene),entries=[];for(const g of groups){entries.push({c:g.root,start:g.start,length:g.length,group:g});for(const e of g.events)entries.push({c:e.c,start:g.start+e.offset,length:e.length,group:g,parallel:true,requested:g.start+e.requested})}return {groups,entries,total:groups.length?groups.at(-1).start+groups.at(-1).total:0}}
export function anchorAt(scene,frame){return timelineGroups(scene).find(g=>overlapRoots.has(g.root.type)&&frame>=g.start&&frame<g.start+g.total)||null}

export function linkAfterDialogue(scene,action,dialogue,makeAnchor){
 const commands=scene.commands;
 if(!commands.includes(action)||!commands.includes(dialogue)||action===dialogue||!["text_inline","treatment_text"].includes(dialogue.type))return false;
 // Do not introduce a dependency cycle (including existing chained dialogues).
 const seen=new Set([action.id]);let dep=dialogue;
 while(dep){if(seen.has(dep.id))return false;seen.add(dep.id);dep=commands.find(c=>c.id===dep.afterId)}
 const children=commands.filter(c=>c.overlapParent===action.id);
 if(children.length){
   const anchor=makeAnchor();
   commands.splice(commands.indexOf(action),0,anchor);
   for(const child of children)child.overlapParent=anchor.id;
 }
 delete action.overlapParent;delete action.offsetFrames;delete action.afterId;
 // Resolve the dialogue's group after moving the old root's children.
 const entry=layoutTimeline(scene).entries.find(e=>e.c.id===dialogue.id);
 if(!entry)return false;
 commands.splice(commands.indexOf(action),1);
 if(entry.parallel&&overlapLane(action)){
   action.overlapParent=entry.group.root.id;
   action.offsetFrames=Math.max(0,entry.requested-entry.group.start);
   commands.splice(commands.indexOf(dialogue)+1,0,action);
 }else{
   const root=entry.group.root;
   commands.splice(commands.indexOf(root)+1,0,action);
 }
 action.afterId=dialogue.id;
 return true;
}
