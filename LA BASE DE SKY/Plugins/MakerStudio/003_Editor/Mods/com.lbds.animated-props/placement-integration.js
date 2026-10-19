import {cropFor} from './core.js';

// Divide a previously placed rectangular prop when a normal tile-like stroke
// replaces just one part of it. Preserve the source coordinates for animation.
export function subtractPlacementArea(p,def,area,newId=()=>`split_${Math.random().toString(36).slice(2)}`){
  if(!p||!def)return p?[p]:[];
  const src=cropFor(def,p.crop),ex=p.x,ey=p.y,er=ex+src.w,eb=ey+src.h;
  const ix=Math.max(ex,area.x),iy=Math.max(ey,area.y);
  const ir=Math.min(er,area.x+area.w),ib=Math.min(eb,area.y+area.h);
  if(ix>=ir||iy>=ib)return [p];
  const patches=[
    {x:ex,y:ey,w:ix-ex,h:src.h}, // left full height
    {x:ir,y:ey,w:er-ir,h:src.h}, // right full height
    {x:ix,y:ey,w:ir-ix,h:iy-ey}, // top middle
    {x:ix,y:ib,w:ir-ix,h:eb-ib}, // bottom middle
  ];
  return patches.filter(r=>r.w>0&&r.h>0).map(r=>({
    ...p,id:newId(),x:r.x,y:r.y,
    crop:{x:src.x+(r.x-ex),y:src.y+(r.y-ey),w:r.w,h:r.h}
  }));
}
export function activeLayerPlacementAt(data,mapId,x,y,layer){
  const list=data?.placements?.[String(mapId)]||[],defs=new Map((data?.definitions||[]).map(d=>[d.id,d]));
  for(let i=list.length-1;i>=0;i--){
    const p=list[i];if(p.layer!==layer)continue;
    const def=defs.get(p.defId);if(!def)continue;
    const c=cropFor(def,p.crop);
    if(x>=p.x&&y>=p.y&&x<p.x+c.w&&y<p.y+c.h)return p;
  }
  return null;
}
export function parseNativeName(name){
  const match=/^LBDSAP_(.+)_x(\d+)_y(\d+)$/.exec(name||'');
  if(!match)return null;
  return {defId:match[1],sx:Number(match[2]),sy:Number(match[3])};
}
// Opt-in migration from 0.4.x: read old named autotiles but do NOT generate any.
export function scanNativeRefs(map,mapId,info,layers=[]){
  if(!info)return [];
  const maxLayer=Math.max(16,Number(info.layerCount)||0, ...layers.filter(l=>['native','extended'].includes(l.kind)).map(l=>l.index+1));
  if(!Number.isInteger(info.width)||!Number.isInteger(info.height)||info.width*info.height*maxLayer>2500000)
    throw new Error('Mapa demasiado grande para recuperar automáticamente; no se ha modificado.');
  const refs=[];
  for(let layer=0;layer<maxLayer;layer++){
    if(layers.some(l=>l.index===layer&&['shadow','event','events'].includes(l.kind))&&
       !layers.some(l=>l.index===layer&&['native','extended'].includes(l.kind)))continue;
    for(let y=0;y<info.height;y++)for(let x=0;x<info.width;x++){
      let raw=null;
      try{raw=layer<3?map.getNativeTileProperties?.(mapId,layer,x,y)?.autotileName:
                            map.readTileData?.(mapId,layer,x,y)?.autotileName;}
      catch{continue;}
      const parsed=parseNativeName(raw);
      if(parsed)refs.push({layer,x,y,name:raw,...parsed});
    }
  }
  return refs;
}
export function nativeRefsAsPlacements(refs,definitions,mapId){
  const defs=new Map(definitions.map(d=>[d.id,d]));
  const placements=[],invalid=[];
  for(const r of refs){
    const def=defs.get(r.defId);
    if(!def||r.sx<0||r.sy<0||r.sx>=def.width||r.sy>=def.height){invalid.push(r);continue;}
    placements.push({id:`recovered_${mapId}_${r.layer}_${r.x}_${r.y}_${r.sx}_${r.sy}`,
      defId:def.id,layer:r.layer,x:r.x,y:r.y,
      crop:{x:r.sx,y:r.sy,w:1,h:1}});
  }
  return {placements,invalid};
}
