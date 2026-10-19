// World-coordinate brush geometry. No dependency on HTML pixels or zoom.
export function lineCells(a,b){
  let x=a.x|0,y=a.y|0;
  const tx=b.x|0,ty=b.y|0,dx=Math.abs(tx-x),dy=Math.abs(ty-y);
  const sx=x<tx?1:-1,sy=y<ty?1:-1;
  let err=dx-dy;
  const out=[];
  while(true){
    out.push({x,y});
    if(x===tx&&y===ty)break;
    const e=2*err;
    if(e>-dy){err-=dy;x+=sx;}
    if(e<dx){err+=dx;y+=sy;}
  }
  return out;
}
export function rectangleCells(a,b){
  const out=[];
  const left=Math.min(a.x,b.x),right=Math.max(a.x,b.x);
  const top=Math.min(a.y,b.y),bottom=Math.max(a.y,b.y);
  for(let y=top;y<=bottom;y++)for(let x=left;x<=right;x++)out.push({x,y});
  return out;
}
export function brushFootprint(points,size=1,shape='square'){
  const n=Math.max(1,Math.min(9,Math.round(size)||1)),off=Math.floor(n/2);
  const seen=new Set(),out=[];
  for(const p of points)for(let by=0;by<n;by++)for(let bx=0;bx<n;bx++){
    const dx=bx-off,dy=by-off;
    if(shape==='circle' && (dx*dx+dy*dy)>(n/2)*(n/2))continue;
    const x=p.x+dx,y=p.y+dy,key=`${x},${y}`;
    if(!seen.has(key)){seen.add(key);out.push({x,y});}
  }
  return out;
}
export function floodCells(start,inside,matching,limit=750){
  if(!inside(start.x,start.y))return [];
  const initial=matching(start.x,start.y),seen=new Set(),queue=[start],out=[];
  for(let at=0;at<queue.length&&out.length<limit;at++){
    const {x,y}=queue[at],key=`${x},${y}`;
    if(seen.has(key))continue;seen.add(key);
    if(!inside(x,y)||matching(x,y)!==initial)continue;
    out.push({x,y});
    for(const [dx,dy] of [[0,-1],[-1,0],[1,0],[0,1]]){
      const nx=x+dx,ny=y+dy;
      if(!seen.has(`${nx},${ny}`))queue.push({x:nx,y:ny});
    }
  }
  return out;
}
export function strokeCells(stroke){
  if(!stroke)return [];
  const points=stroke.path||[stroke.start];
  let base=[];
  if(stroke.mode==='rectangle')base=rectangleCells(stroke.start,stroke.end||stroke.start);
  else if(stroke.mode==='line')base=lineCells(stroke.start,stroke.end||stroke.start);
  else if(stroke.mode==='brush'||stroke.mode==='eraser'){
    for(let i=0;i<points.length;i++)base.push(...(i?lineCells(points[i-1],points[i]):[points[i]]));
  }else base=[stroke.start];
  return brushFootprint(base,stroke.size,stroke.shape);
}
