// Lighting Studio: world-space light chunks; zoom never changes chunk contents.
// Each source is merged using per-channel MAX, not additive stacking.
// World-to-screen projection is exactly the one used by LBDS Animated Props.
const MASK_LIMIT=16, MASK_MAX=64, CHUNK_WORLD=256, CHUNK_PX=64, CHUNK_LIMIT=48;
const masks=new Map(),chunks=new Map();
let cachedMapKey=null;
const clamp=(v,min,max)=>Math.min(max,Math.max(min,Number.isFinite(+v)?+v:min));
const rgb=(hex)=>/^#[0-9A-F]{6}$/i.test(String(hex||''))?[1,3,5].map(i=>parseInt(hex.slice(i,i+2),16)):[255,206,138];
export function evaluated(l,t){
  const p=l.pulse||{},wave=p.enabled?Math.sin(t*2*Math.PI*(p.speedHz||1)+(p.phase||0)*Math.PI/180):0;
  const factor=Math.max(.1,1+wave*(p.radius||0));
  return {radius:Math.max(8,(l.radiusPx||96)*factor),scale:factor,
    intensity:clamp((l.intensity??.8)*(1+wave*(p.intensity||0)),0,1)};
}
export function dimensions(l){
  return l.type==='ellipse'||l.type==='rectangle'
    ?{w:Math.max(8,Number(l.widthPx)||160),h:Math.max(8,Number(l.heightPx)||96)}
    :{w:Math.max(8,Number(l.radiusPx)||96)*2,h:Math.max(8,Number(l.radiusPx)||96)*2};
}
export function falloff(l,nx,ny){
  let d;const t=l.type||'radial',soft=clamp(l.softness??.75,.05,1);
  if(t==='rectangle')d=Math.max(Math.abs(nx),Math.abs(ny));
  else if(t==='cone')d=Math.max(Math.hypot(nx,ny),Math.abs(Math.atan2(ny,nx))/(clamp(l.angle??70,5,170)*Math.PI/360));
  else d=Math.hypot(nx,ny);
  if(d>=1)return 0;
  const mode=l.fadeMode||'center';
  let fadeDist=d;
  if(mode==='top')fadeDist=(ny+1)*.5;
  else if(mode==='bottom')fadeDist=(1-ny)*.5;
  else if(mode==='left')fadeDist=(nx+1)*.5;
  else if(mode==='right')fadeDist=(1-nx)*.5;
  else if(mode==='custom'){
    const ox=clamp(l.fadeX??0,-1,1),oy=clamp(l.fadeY??0,-1,1);
    fadeDist=Math.hypot(nx-ox,ny-oy)/(1+Math.hypot(ox,oy));
  }
  const main=Math.pow(Math.max(0,1-clamp(fadeDist,0,1)),1/soft);
  const edge=mode==='center'?1:clamp((1-d)/Math.max(.035,.18*soft),0,1);
  const center=clamp(l.centerStrength??.65,0,1);
  return main*edge*(center+(1-center)*Math.min(1,d*2));
}
function newCanvas(w,h){
  // Use an ordinary canvas, as Animated Props does with DOM-backed images.
  // OffscreenCanvas can be unsupported or incompatible with the map renderer
  // in some Tauri/WebView builds, resulting in entirely invisible lightmaps.
  const c=document.createElement('canvas');
  c.width=w;c.height=h;return c;
}
function maskKey(l){
  const p=l.pixel||{};
  return [l.type,l.radiusPx,l.widthPx,l.heightPx,l.angle,l.color,l.softness,l.centerStrength,
    l.fadeMode,l.fadeX,l.fadeY,p.enabled?1:0,p.size,p.steps].join('|');
}
function createMask(l){
  const dims=dimensions(l),factor=Math.min(1,MASK_MAX/Math.max(dims.w,dims.h));
  const w=Math.max(2,Math.round(dims.w*factor)),h=Math.max(2,Math.round(dims.h*factor));
  const c=newCanvas(w,h),ctx=c.getContext('2d');
  if(!ctx)return null;
  const [r,g,b]=rgb(l.color),p=l.pixel||{};
  if(p.enabled){
    const cell=Math.max(1,Math.round((p.size||6)*factor)),steps=Math.max(2,p.steps||6);
    for(let y=0;y<h;y+=cell)for(let x=0;x<w;x+=cell){
      const nx=((x+cell/2)/w-.5)*2,ny=((y+cell/2)/h-.5)*2;
      const a=Math.round(falloff(l,nx,ny)*steps)/steps;
      if(a<1/255)continue;
      ctx.fillStyle='rgba('+r+','+g+','+b+','+a+')';
      ctx.fillRect(x,y,Math.min(cell,w-x),Math.min(cell,h-y));
    }
  }else{
    const img=ctx.createImageData(w,h),buf=img.data;
    for(let y=0;y<h;y++)for(let x=0;x<w;x++){
      const alpha=Math.round(falloff(l,((x+.5)/w-.5)*2,((y+.5)/h-.5)*2)*255);
      const pos=(y*w+x)*4;
      buf[pos]=r;buf[pos+1]=g;buf[pos+2]=b;buf[pos+3]=alpha;
    }
    ctx.putImageData(img,0,0);
  }
  return c;
}
function getMask(l){
  const key=maskKey(l);
  if(masks.has(key)){const m=masks.get(key);masks.delete(key);masks.set(key,m);return m;}
  const m=createMask(l);if(!m)return null;
  masks.set(key,m);if(masks.size>MASK_LIMIT)masks.delete(masks.keys().next().value);
  return m;
}
function stamp(g,l,project,t,blend){
  const mask=getMask(l);if(!mask)return;
  const d=dimensions(l),a=evaluated(l,t),scale=a.scale*project.scale();
  const w=d.w*scale,h=d.h*scale;
  g.save();
  g.globalCompositeOperation=blend;
  g.globalAlpha=a.intensity;
  g.imageSmoothingEnabled=!l.pixel?.enabled;
  g.translate(project.x(l.x),project.y(l.y));
  g.rotate((Number(l.rotation)||0)*Math.PI/180);
  if(l.blendMode==='subtract')g.filter='brightness(0)';
  g.drawImage(mask,-w/2,-h/2,w,h);
  g.restore();
}
// Lighting union in WORLD coordinates. Static light overlap is max(R,G,B).
export function mergeColorMax(dst,pos,r,g,b,alpha){
  const a=alpha/255;
  dst[pos]=Math.max(dst[pos],Math.round(r*a));
  dst[pos+1]=Math.max(dst[pos+1],Math.round(g*a));
  dst[pos+2]=Math.max(dst[pos+2],Math.round(b*a));
  dst[pos+3]=255;
}
let scratch=null;
function bounds(l){
  const dims=dimensions(l),angle=(Number(l.rotation)||0)*Math.PI/180;
  const c=Math.abs(Math.cos(angle)),s=Math.abs(Math.sin(angle));
  return {x:l.x*32,y:l.y*32,w:dims.w*c+dims.h*s,h:dims.w*s+dims.h*c};
}
function makeChunk(cx,cy,lights){
  if(!scratch)scratch=newCanvas(CHUNK_PX,CHUNK_PX);
  const work=scratch.getContext('2d',{willReadFrequently:true});
  if(!work)return null;
  const result=newCanvas(CHUNK_PX,CHUNK_PX),destCtx=result.getContext('2d');
  if(!destCtx)return null;
  const img=destCtx.createImageData(CHUNK_PX,CHUNK_PX),dest=img.data;
  const worldX=cx*CHUNK_WORLD,worldY=cy*CHUNK_WORLD;
  let nonzero=false;
  const scale=CHUNK_PX/CHUNK_WORLD;
  for(const l of lights){
    const b=bounds(l),halfW=b.w/2,halfH=b.h/2;
    if(b.x+halfW<=worldX||b.x-halfW>=worldX+CHUNK_WORLD||
       b.y+halfH<=worldY||b.y-halfH>=worldY+CHUNK_WORLD)continue;
    const mask=getMask(l);if(!mask)continue;
    const d=dimensions(l);
    work.clearRect(0,0,CHUNK_PX,CHUNK_PX);
    work.save();
    work.globalCompositeOperation='source-over';
    work.globalAlpha=clamp(l.intensity??.8,0,1);
    work.translate((b.x-worldX)*scale,(b.y-worldY)*scale);
    work.rotate((Number(l.rotation)||0)*Math.PI/180);
    work.imageSmoothingEnabled=!l.pixel?.enabled;
    work.drawImage(mask,-d.w*scale/2,-d.h*scale/2,d.w*scale,d.h*scale);
    work.restore();
    const src=work.getImageData(0,0,CHUNK_PX,CHUNK_PX).data;
    for(let pos=0;pos<src.length;pos+=4){
      if(src[pos+3]<1)continue;
      mergeColorMax(dest,pos,src[pos],src[pos+1],src[pos+2],src[pos+3]);
      nonzero=true;
    }
  }
  if(!nonzero)return null;
  destCtx.putImageData(img,0,0);
  return result;
}
function cachedChunk(cx,cy,lights){
  const key=cx+':'+cy;
  if(chunks.has(key)){
    const value=chunks.get(key);chunks.delete(key);chunks.set(key,value);
    return value;
  }
  const result=makeChunk(cx,cy,lights);
  chunks.set(key,result);
  while(chunks.size>CHUNK_LIMIT)chunks.delete(chunks.keys().next().value);
  return result;
}
export function clearLightCache(){masks.clear();chunks.clear();scratch=null;cachedMapKey=null;}
export function cacheSize(){return {masks:masks.size,views:chunks.size};}
function drawUnionChunks(g,lights,project,width,height){
  const scale=project.scale();if(!(scale>0))return;
  const worldLeft=Math.max(0,-project.x(0)/scale);
  const worldRight=Math.max(0,(width-project.x(0))/scale);
  const worldTop=Math.max(0,-project.y(0)/scale);
  const worldBottom=Math.max(0,(height-project.y(0))/scale);
  const left=Math.floor(worldLeft/CHUNK_WORLD),right=Math.floor(worldRight/CHUNK_WORLD);
  const top=Math.floor(worldTop/CHUNK_WORLD),bottom=Math.floor(worldBottom/CHUNK_WORLD);
  g.save();g.globalCompositeOperation='screen';g.globalAlpha=1;g.imageSmoothingEnabled=true;
  for(let cy=top;cy<=bottom;cy++)for(let cx=left;cx<=right;cx++){
    const bitmap=cachedChunk(cx,cy,lights);if(!bitmap)continue;
    // Exact Animated Props transform; no viewport-sized image or double zoom.
    const x=project.x(cx*CHUNK_WORLD/32),y=project.y(cy*CHUNK_WORLD/32);
    const d=CHUNK_WORLD*scale;
    g.drawImage(bitmap,x,y,d,d);
  }
  g.restore();
}
export function drawLights(g,lights,project,width,height,t=0,overlapMode='union'){
  const visible=(lights||[]).filter(l=>l.enabled!==false);
  if(!visible.length)return;
  const key=String(project.mapId??'map')+':'+String(project.revision??0);
  if(key!==cachedMapKey){chunks.clear();cachedMapKey=key;}
  const union=visible.filter(l=>['union','add',''].includes(l.blendMode||'union'));
  const sums=visible.filter(l=>l.blendMode==='sum');
  const merged=overlapMode==='sum'?[]:union;
  const summed=overlapMode==='sum'?[...union,...sums]:sums;
  const staticLights=merged.filter(l=>!l.pulse?.enabled);
  const pulsing=merged.filter(l=>l.pulse?.enabled);
  if(staticLights.length===1)stamp(g,staticLights[0],project,t,'screen');
  else if(staticLights.length>1)drawUnionChunks(g,staticLights,project,width,height);
  // Animated lights are sprites; rebuilding world chunks every pulse frame would
  // cause spikes. In this prototype animated overlaps use screen blending.
  for(const l of pulsing)stamp(g,l,project,t,'screen');
  for(const l of summed)stamp(g,l,project,t,'lighter');
  for(const l of visible){
    const mode=l.blendMode||'union';
    if(['union','add','sum'].includes(mode))continue;
    stamp(g,l,project,t,mode==='subtract'?'multiply':'source-over');
  }
}
