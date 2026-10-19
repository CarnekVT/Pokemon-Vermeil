// Math and editor layer occlusion: no private Maker Studio APIs.
export function tileAtClientPoint(event, rect, width, height) {
  if(!event||!rect||rect.width<=0||rect.height<=0||width<=0||height<=0)return null;
  const px=(Number(event.clientX)-rect.left)/rect.width;
  const py=(Number(event.clientY)-rect.top)/rect.height;
  if(!Number.isFinite(px)||!Number.isFinite(py))return null;
  // Pointer capture intentionally permits dragging beyond the canvas.
  const x=Math.max(0,Math.min(width-1,Math.floor(px*width)));
  const y=Math.max(0,Math.min(height-1,Math.floor(py*height)));
  return {x,y};
}
export function regionFromPoints(a,b){
  const x=Math.min(a.x,b.x),y=Math.min(a.y,b.y);
  return {x,y,w:Math.abs(a.x-b.x)+1,h:Math.abs(a.y-b.y)+1};
}
function nonemptyTile(map,mapId,index,x,y) {
  try{
    const id=map.readTile?.(mapId,index,x,y);
    if(Number(id)>0)return true;
    const data=map.readTileData?.(mapId,index,x,y);
    if(data?.autotileName || Number(data?.tileId)>0)return true;
    if(index<3 && map.getNativeTileProperties?.(mapId,index,x,y)?.autotileName)return true;
  }catch { /* A missing/unloaded layer must not crash the editor. */ }
  return false;
}
export function upperTileMask(map,mapId,sourceLayer,x,y,width,height,layers){
  const higher=(layers||[]).filter(l=>l.index>sourceLayer&&l.visible!==false&&
    (l.kind==='native'||l.kind==='extended'||l.kind==null)).map(l=>l.index);
  const cells=[];
  if(!higher.length)return {all:true,count:width*height,cells:[]};
  for(let row=0;row<height;row++)for(let col=0;col<width;col++){
    const occluded=higher.some(index=>nonemptyTile(map,mapId,index,x+col,y+row));
    if(!occluded)cells.push({x:col,y:row});
  }
  return {all:cells.length===width*height,count:cells.length,cells};
}
