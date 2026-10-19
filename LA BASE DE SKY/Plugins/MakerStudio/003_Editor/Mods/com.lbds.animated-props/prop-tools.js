// Native-style Prop operations without writing ordinary map tile IDs.
// All coordinates are map cells; each operation is bounded for editor responsiveness.
import {cropFor} from './core.js';
export function occupiedPropCells(data,mapId,layer,width,height){
 const defs=new Map((data.definitions||[]).map(d=>[d.id,d]));
 const cells=new Map();
 for(const p of data.placements?.[String(mapId)]||[]){
  if(p.layer!==layer)continue;
  const d=defs.get(p.defId);if(!d)continue;
  const c=cropFor(d,p.crop);
  for(let dy=0;dy<c.h;dy++)for(let dx=0;dx<c.w;dx++){
   const x=p.x+dx,y=p.y+dy;
   if(x>=0&&x<width&&y>=0&&y<height)cells.set(`${x},${y}`,p.defId);
  }
 }
 return cells;
}
export function matchPropCells(grid,start,width,height,{continuous=true,limit=1800,empty=false}={}){
 const key=(x,y)=>`${x},${y}`;
 if(start.x<0||start.y<0||start.x>=width||start.y>=height)return [];
 const expected=grid.get(key(start.x,start.y));
 if(expected===undefined&&!empty)return [];
 const matches=(x,y)=>grid.get(key(x,y))===expected;
 const out=[];
 if(!continuous){
  for(let y=0;y<height&&out.length<limit;y++)for(let x=0;x<width&&out.length<limit;x++){
   if(matches(x,y))out.push({x,y});
  }
  return out;
 }
 const queue=[start],seen=new Set();
 for(let i=0;i<queue.length&&out.length<limit;i++){
  const {x,y}=queue[i],k=key(x,y);
  if(seen.has(k))continue;seen.add(k);
  if(x<0||y<0||x>=width||y>=height||!matches(x,y))continue;
  out.push({x,y});
  queue.push({x:x+1,y},{x:x-1,y},{x,y:y+1},{x,y:y-1});
 }
 return out;
}
export function changeSelection(current,cells,{add=false,subtract=false,layer,mapId}={}){
 const selected=current?.layer===layer&&current?.mapId===mapId?new Set(current.keys):new Set();
 if(!add&&!subtract)selected.clear();
 for(const c of cells){const key=`${c.x},${c.y}`;if(subtract)selected.delete(key);else selected.add(key);}
 return {keys:selected,layer,mapId};
}
