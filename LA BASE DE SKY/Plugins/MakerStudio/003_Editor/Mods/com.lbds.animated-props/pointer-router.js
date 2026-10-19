import {tileFromRenderedCanvas} from './interaction.js';
// Prefer Maker Studio's own tile coordinates. HTML bounds are an emergency fallback.
export function validHover(hover,mapId,map,now,maxAge=600){
  return hover && hover.mapId===mapId && Number.isInteger(hover.x) && Number.isInteger(hover.y) &&
    hover.x>=0 && hover.y>=0 && hover.x<map.width && hover.y<map.height &&
    Number.isFinite(hover.at) && now-hover.at>=0 && now-hover.at<=maxAge;
}
export function resolveTile({mapId,map,hover,editorHover,now,clientX,clientY,rect,renderInfo,viewport}){
  if(!map||!Number.isInteger(mapId))return null;
  if(validHover(hover,mapId,map,now))return {mapId,x:hover.x,y:hover.y,source:'editor-hover'};
  if(editorHover && Number.isInteger(editorHover.x) && Number.isInteger(editorHover.y) &&
     editorHover.x>=0 && editorHover.y>=0 && editorHover.x<map.width && editorHover.y<map.height)
     return {mapId,x:editorHover.x,y:editorHover.y,source:'editor-query'};
  // Refuse STALE overlay transforms after zoom: painting in a wrong cell is worse
  // than not painting until the next native render publishes current metadata.
  if(!renderInfo||renderInfo.mapId!==mapId||!viewport||!Number.isFinite(renderInfo.zoom)||
     !Number.isFinite(viewport.zoom)||Math.abs(renderInfo.zoom-viewport.zoom)>1e-5)return null;
  const tile=tileFromRenderedCanvas(clientX,clientY,rect,renderInfo,map);
  return tile?{mapId,...tile,source:'canvas-fallback'}:null;
}
