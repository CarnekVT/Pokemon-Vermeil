import {visibleMapRect} from './performance.js';

// Spatial bins are indexed by the full prop footprint, not only the anchor.
export const BIN_SIZE = 16;
export function createSpatialIndex(ordered, binSize=BIN_SIZE){
  const buckets=new Map();
  ordered.forEach((entry,i)=>{
    const {p,d}=entry,crop=p?.crop||{};
    const w=Math.max(1,Number(crop.w)||Number(d?.width)||1);
    const h=Math.max(1,Number(crop.h)||Number(d?.height)||1);
    const minX=Math.floor(p.x/binSize),maxX=Math.floor((p.x+w-1)/binSize);
    const minY=Math.floor(p.y/binSize),maxY=Math.floor((p.y+h-1)/binSize);
    for(let by=minY;by<=maxY;by++)for(let bx=minX;bx<=maxX;bx++){
      const key=`${bx},${by}`,bin=buckets.get(key);
      if(bin)bin.push(i);else buckets.set(key,[i]);
    }
  });
  return {ordered,buckets,binSize};
}

export function queryVisible(index,info){
  if(!index)return [];
  const {ordered,buckets,binSize}=index;
  if(!info || !(info.tileSize>0) || !(info.canvasWidth>0) || !(info.canvasHeight>0))return ordered;
  const minX=Math.floor(info.viewportX/info.tileSize)-1;
  const minY=Math.floor(info.viewportY/info.tileSize)-1;
  const maxX=Math.ceil((info.viewportX+info.canvasWidth)/info.tileSize)+1;
  const maxY=Math.ceil((info.viewportY+info.canvasHeight)/info.tileSize)+1;
  const indices=new Set();
  for(let by=Math.floor(minY/binSize);by<=Math.floor(maxY/binSize);by++){
    for(let bx=Math.floor(minX/binSize);bx<=Math.floor(maxX/binSize);bx++){
      for(const i of buckets.get(`${bx},${by}`)||[])indices.add(i);
    }
  }
  return [...indices].sort((a,b)=>a-b).map(i=>ordered[i]).filter(({p,d})=>visibleMapRect(p,d,info));
}

export function viewportCacheKey(mapId,info){
  if(!info)return `${mapId}:unknown`;
  return [mapId,info.viewportX,info.viewportY,info.tileSize,info.zoom,
    info.canvasWidth,info.canvasHeight].join('/');
}
