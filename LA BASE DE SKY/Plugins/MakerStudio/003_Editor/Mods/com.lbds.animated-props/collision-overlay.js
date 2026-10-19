// Animated Props collision visualizer for Maker Studio's native "Col" view.
// Draws only overlay information; never changes map tiles or terrain rules.
export function collisionCells(def, crop, placement) {
  if (!def || !Array.isArray(def.cells)) return [];
  const result=[];
  for(let y=0;y<crop.h;y++)for(let x=0;x<crop.w;x++){
    const cell=def.cells[(crop.y+y)*def.width+crop.x+x]||{};
    result.push({x:placement.x+x,y:placement.y+y,localX:x,localY:y,
      passage:(Number(cell.passage)||0)&0xcf,
      priority:Number(cell.priority)||0,terrainTag:Number(cell.terrainTag)||0});
  }
  return result;
}
export function drawCollisionCells(ctx, rect, info, entries) {
  if(!entries?.length || !ctx)return;
  const size=Number(info.tileSize);
  if(!(size>0))return;
  ctx.save();
  ctx.textAlign='center';ctx.textBaseline='middle';
  ctx.font=`bold ${Math.max(9,Math.min(15,size*.4))}px sans-serif`;
  ctx.lineWidth=Math.max(1,size/14);
  for(const c of entries){
    const x=rect.x+c.localX*size,y=rect.y+c.localY*size;
    const mask=c.passage&15;
    ctx.globalAlpha=.76;
    // An unblocked prop has a transparent green marker so the map remains readable.
    ctx.fillStyle=mask===15?'rgba(220,56,56,.42)':mask?'rgba(230,155,32,.38)':'rgba(42,172,89,.20)';
    ctx.fillRect(x+1,y+1,Math.max(0,size-2),Math.max(0,size-2));
    ctx.globalAlpha=1;
    ctx.strokeStyle=mask?'#ff6969':'#55d991';
    const midX=x+size/2,midY=y+size/2;
    if(mask===15){
      ctx.beginPath();ctx.moveTo(x+size*.26,y+size*.26);ctx.lineTo(x+size*.74,y+size*.74);
      ctx.moveTo(x+size*.74,y+size*.26);ctx.lineTo(x+size*.26,y+size*.74);ctx.stroke();
    }else if(mask){
      // RPG Maker XP directional bits: 1↓, 2←, 4→, 8↑.
      const arrows=[[1,'↓'],[2,'←'],[4,'→'],[8,'↑']];
      ctx.fillStyle='#ff6b66';ctx.font=`bold ${Math.max(8,Math.round(size*.28))}px sans-serif`;
      const offsets=[[0,.31],[-.29,0],[.29,0],[0,-.29]];
      arrows.forEach(([bit,glyph],i)=>{if(mask&bit)ctx.fillText(glyph,midX+offsets[i][0]*size,midY+offsets[i][1]*size);});
    }
    if(c.terrainTag>0 || c.priority>0){
      ctx.font=`bold ${Math.max(8,Math.round(size*.22))}px sans-serif`;
      const tag=[c.priority>0?`P${c.priority}`:'',c.terrainTag>0?`T${c.terrainTag}`:''].filter(Boolean).join(' ');
      ctx.fillStyle='rgba(0,0,0,.78)';ctx.fillRect(x,y+size*.68,size,size*.32);
      ctx.fillStyle='#fff';ctx.fillText(tag,midX,y+size*.84);
    }
  }
  ctx.restore();
}
