import {nativeScreenToTile} from './overlay-transform.js';
import {cropFor} from './core.js';

// Use the active layer if possible; otherwise select the uppermost placed prop.
export function pickProp(data,mapId,x,y,layer){
 const defs=new Map((data.definitions||[]).map(d=>[d.id,d]));
 const entries=(data.placements[String(mapId)]||[]).map((p,index)=>({p,index}));
 const hits=entries.filter(({p})=>{
  const d=defs.get(p.defId); if(!d)return false;
  const c=cropFor(d,p.crop);
  return x>=p.x&&y>=p.y&&x<p.x+c.w&&y<p.y+c.h;
 });
 hits.sort((a,b)=>(b.p.layer===layer)-(a.p.layer===layer) || b.p.layer-a.p.layer || b.index-a.index);
 return hits[0]?.p||null;
}
export function movable(data,mapInfo,mapId,id,x,y){
 if(!Number.isInteger(x)||!Number.isInteger(y)||x<0||y<0)return false;
 const p=(data.placements[String(mapId)]||[]).find(p=>p.id===id);
 const d=data.definitions.find(d=>d.id===p?.defId);
 if(!p||!d||!mapInfo)return false;
 const c=cropFor(d,p.crop);
 return x+c.w<=mapInfo.width&&y+c.h<=mapInfo.height;
}
// Convert pointer coordinates using the ACTUAL overlay render metadata.
export function tileFromRenderedCanvas(clientX,clientY,rect,info,map){
 if(!rect||!info||!map||rect.width<=0||rect.height<=0||!info.canvasWidth||!info.canvasHeight||!info.zoom)return null;
 const px=(clientX-rect.left)*info.canvasWidth/rect.width;
 const py=(clientY-rect.top)*info.canvasHeight/rect.height;
 const {x,y}=nativeScreenToTile(px,py,info);
 if(!Number.isInteger(x)||!Number.isInteger(y)||x<0||y<0||x>=map.width||y>=map.height)return null;
 return {x,y};
}
