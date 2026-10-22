// Lighting Studio: world-space light chunks; zoom never changes chunk contents.
// Each source is merged using per-channel MAX, not additive stacking.
// World-to-screen projection is exactly the one used by LBDS Animated Props.
const MASK_LIMIT=16, MASK_MAX=128, SMOOTH_SHAPE_MAX=192, CHUNK_WORLD=256, CHUNK_PX=96, CHUNK_LIMIT=24;
const CHUNKS_PER_PASS=2;
const masks=new Map(),chunks=new Map(),maskSources=new Map();
// Static preview textures are reused across repaints requested by Animated Props.
// The cache contains light RGB only, not underlying map pixels or UI handles.
const staticPreviewViews=new Map(), STATIC_PREVIEW_LIMIT=3;
// Keep separate texture caches, as native animated autotiles do: a mask
// brush edit should not discard all static illumination chunks.
function evictMask(name){
 for(const key of masks.keys())if(key.startsWith('mask|')&&key.endsWith('|'+name))masks.delete(key);
}
export function setMaskImage(filename,img){
 if(!filename||!img)return;
 maskSources.set(filename,img);
 evictMask(filename);masks.clear();staticPreviewViews.clear();chunks.clear();
}
export function getMaskImage(filename){return maskSources.get(filename)||null;}
export function removeMaskImage(filename){
 if(maskSources.delete(filename)){evictMask(filename);masks.clear();staticPreviewViews.clear();chunks.clear();}
}
export function forgetMaskImages(){maskSources.clear();clearLightCache();}
let pendingChunks=false;
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
  return l.type==='ellipse'||l.type==='rectangle'||l.type==='mask'
    ?{w:Math.max(8,Number(l.widthPx)||160),h:Math.max(8,Number(l.heightPx)||96)}
    :{w:Math.max(8,Number(l.radiusPx)||96)*2,h:Math.max(8,Number(l.radiusPx)||96)*2};
}
// Shape defines the illuminated area; fade direction is a separate gradient.
// 'bottom' means darkening TOWARDS the bottom (bright plateau on top).
const smoothstep=(lo,hi,x)=>{
  const q=clamp((x-lo)/(hi-lo),0,1);
  return q*q*(3-2*q);
};
// The cone source stays at nx=0,ny=0. The beam projects toward +nx,
// within a circular reach of 1. Do NOT move it to nx=-1: that would shift
// lights already positioned over lamps on existing game maps.
export function falloff(l,nx,ny){
  const t=l.type||'radial',soft=clamp(l.softness??.75,.05,1);
  const mode=l.fadeMode||'center',center=clamp(l.centerStrength??.65,0,1);
  let d;
  if(t==='cone'){
    d=Math.hypot(nx,ny);
    if(nx<0||d>=1)return 0;
    const halfAngle=clamp(l.angle??70,5,170)*Math.PI/360;
    const relativeAngle=Math.abs(Math.atan2(ny,nx))/halfAngle;
    if(relativeAngle>=1)return 0;
    const feather=clamp(l.coneFeather??.28,.03,.9);
    const side=1-smoothstep(1-feather,1,relativeAngle);
    if(mode==='center'){
      // A readable spotlight: evenly lit core, smooth distance falloff,
      // and a separate feather around the lateral cone edges.
      const reachStart=clamp(l.fadeStart??.58,0,.95);
      return side*(1-smoothstep(reachStart,1,d))*center;
    }
    // For directional fades the distance mask only feathers the very tip;
    // a full second radial falloff used to produce a cloudy triangle.
    const tip=1-smoothstep(.88,1,d);
    return side*tip*directionalFade(l,nx,ny)*center;
  }
  d=t==='rectangle'?Math.max(Math.abs(nx),Math.abs(ny)):Math.hypot(nx,ny);
  if(d>=1)return 0;
  if(mode==='center'){
    const radial=Math.pow(Math.max(0,1-d),1/soft);
    return radial*(center+(1-center)*Math.min(1,d*2));
  }
  const boundary=clamp((1-d)/.045,0,1);
  return directionalFade(l,nx,ny)*boundary*center;
}
function directionalFade(l,nx,ny){
  const mode=l.fadeMode||'center';
  let direction;
  if(mode==='bottom')direction=(ny+1)*.5;
  else if(mode==='top')direction=(1-ny)*.5;
  else if(mode==='left')direction=(1-nx)*.5;
  else if(mode==='right')direction=(nx+1)*.5;
  else {
    const ox=clamp(l.fadeX??0,-1,1),oy=clamp(l.fadeY??0,-1,1);
    direction=Math.hypot(nx-ox,ny-oy)/(1+Math.hypot(ox,oy));
  }
  const start=clamp(l.fadeStart??.58,0,.95);
  return 1-smoothstep(start,1,direction);
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
  return [l.type,l.radiusPx,l.widthPx,l.heightPx,l.angle,l.coneFeather,l.color,l.softness,l.centerStrength,
    l.fadeMode,l.fadeStart,l.fadeX,l.fadeY,p.enabled?1:0,p.size,p.steps,l.maskFile,l.maskEnabled?1:0,l.maskMode].join('|');
}
// A pixel-art light uses one texel per logical block. Never downscale
// the whole shape to MASK_MAX and then quantize again: cones and ellipses lose
// their silhouette when both reductions are applied.
export function pixelGridDimensions(l){
  const d=dimensions(l),block=clamp(l.pixel?.size??6,2,32);
  const limit=128;
  return {w:Math.max(2,Math.min(limit,Math.ceil(d.w/block))),
          h:Math.max(2,Math.min(limit,Math.ceil(d.h/block)))};
}
function applyOcclusionStencil(canvas,l){
  if(!l.maskEnabled || l.type==='mask' || !l.maskFile)return canvas;
  const source=maskSources.get(l.maskFile);
  if(!source)return canvas;
  const ctx=canvas.getContext('2d');
  if(!ctx)return canvas;
  // A mask is a geometric alpha stencil. Do not repeatedly read back canvas
  // pixels or multiply luminance into alpha; that makes dark PNG walls behave
  // unpredictably and stalls the WebView/GPU with getImageData().
  ctx.save();
  ctx.globalCompositeOperation=l.maskMode==='block'?'destination-out':'destination-in';
  ctx.imageSmoothingEnabled=false;
  ctx.drawImage(source,0,0,canvas.width,canvas.height);
  ctx.restore();
  return canvas;
}
function createMask(l){
  if(l.type==='mask'){
    const src=maskSources.get(l.maskFile);
    if(!src)return null;
    const scale=Math.min(1,256/Math.max(src.width,src.height));
    const w=Math.max(1,Math.round(src.width*scale)),h=Math.max(1,Math.round(src.height*scale));
    const output=newCanvas(w,h),ctx=output.getContext('2d');
    if(!ctx)return null;
    const [r,g,b]=rgb(l.color);
    // Pure alpha stencil. No getImageData(), grayscale sampling or per-pixel
    // JavaScript: masking happens on the Canvas compositor (GPU/WebView).
    ctx.save();
    if(l.maskMode==='block'){
      ctx.fillStyle=`rgb(${r},${g},${b})`;
      ctx.fillRect(0,0,w,h);
      ctx.globalCompositeOperation='destination-out';
      ctx.drawImage(src,0,0,w,h);
    }else{
      ctx.drawImage(src,0,0,w,h);
      ctx.globalCompositeOperation='source-in';
      ctx.fillStyle=`rgb(${r},${g},${b})`;
      ctx.fillRect(0,0,w,h);
    }
    ctx.restore();
    return output;
  }
  const dims=dimensions(l),p=l.pixel||{},pixelated=p.enabled===true;
  const maxSmooth=(l.type==='cone'||l.type==='ellipse')?SMOOTH_SHAPE_MAX:MASK_MAX;
  const factor=Math.min(1,maxSmooth/Math.max(dims.w,dims.h));
  const size=pixelated?pixelGridDimensions(l):{
    w:Math.max(2,Math.round(dims.w*factor)),
    h:Math.max(2,Math.round(dims.h*factor))
  };
  const w=size.w,h=size.h,canvas=newCanvas(w,h),ctx=canvas.getContext('2d');
  if(!ctx)return null;
  const [r,g,b]=rgb(l.color),img=ctx.createImageData(w,h),data=img.data;
  const levels=clamp(p.steps??6,2,24);
  for(let y=0;y<h;y++)for(let x=0;x<w;x++){
    const nx=((x+.5)/w-.5)*2,ny=((y+.5)/h-.5)*2;
    let alpha=falloff(l,nx,ny);
    if(pixelated)alpha=Math.round(alpha*levels)/levels;
    const pos=(y*w+x)*4;
    data[pos]=r;data[pos+1]=g;data[pos+2]=b;
    data[pos+3]=Math.round(alpha*255);
  }
  ctx.putImageData(img,0,0);
  return applyOcclusionStencil(canvas,l);
}
function getMask(l){
  const key=maskKey(l);
  if(masks.has(key)){const m=masks.get(key);masks.delete(key);masks.set(key,m);return m;}
  const m=createMask(l);if(!m)return null;
  masks.set(key,m);if(masks.size>MASK_LIMIT)masks.delete(masks.keys().next().value);
  return m;
}
function stamp(g,l,project,t,blend){
  const d=dimensions(l),a=evaluated(l,t),scale=a.scale*project.scale();
  const w=d.w*scale,h=d.h*scale;
  const x=project.x(l.x),y=project.y(l.y);
  const theta=(Number(l.rotation)||0)*Math.PI/180;
  const extentX=(Math.abs(Math.cos(theta))*w+Math.abs(Math.sin(theta))*h)/2;
  const extentY=(Math.abs(Math.sin(theta))*w+Math.abs(Math.cos(theta))*h)/2;
  if(project.viewWidth!=null && project.viewHeight!=null &&
    (x+extentX<0||x-extentX>project.viewWidth||y+extentY<0||y-extentY>project.viewHeight))return;
  const mask=getMask(l);if(!mask)return;
  g.save();
  g.globalCompositeOperation=blend;
  g.globalAlpha=a.intensity;
  g.imageSmoothingEnabled=!l.pixel?.enabled;
  g.translate(x,y);
  g.rotate(theta);
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
// A static world chunk is calculated directly into one ImageData buffer.
// Avoid drawing each light to an auxiliary canvas and reading it back via
// getImageData on every parameter change (a large WebView/GPU sync stall).
function bounds(l){
  const d=dimensions(l),theta=(Number(l.rotation)||0)*Math.PI/180;
  const c=Math.abs(Math.cos(theta)),si=Math.abs(Math.sin(theta));
  return {x:l.x*32,y:l.y*32,w:d.w*c+d.h*si,h:d.w*si+d.h*c};
}
function makeChunk(cx,cy,lights){
  const c=newCanvas(CHUNK_PX,CHUNK_PX),ctx=c.getContext('2d');
  if(!ctx)return null;
  const image=ctx.createImageData(CHUNK_PX,CHUNK_PX),dst=image.data;
  const chunkX=cx*CHUNK_WORLD,chunkY=cy*CHUNK_WORLD;
  const scale=CHUNK_WORLD/CHUNK_PX;
  let lit=false;
  for(const l of lights){
    const a=clamp(l.intensity??.8,0,1);
    if(a<=0)continue;
    const d=dimensions(l),b=bounds(l);
    const bw=b.w/2,bh=b.h/2;
    if(b.x+bw<=chunkX||b.x-bw>=chunkX+CHUNK_WORLD||
       b.y+bh<=chunkY||b.y-bh>=chunkY+CHUNK_WORLD)continue;
    const x0=Math.max(0,Math.floor((b.x-bw-chunkX)/scale)-1);
    const x1=Math.min(CHUNK_PX,Math.ceil((b.x+bw-chunkX)/scale)+1);
    const y0=Math.max(0,Math.floor((b.y-bh-chunkY)/scale)-1);
    const y1=Math.min(CHUNK_PX,Math.ceil((b.y+bh-chunkY)/scale)+1);
    const theta=(Number(l.rotation)||0)*Math.PI/180;
    const cos=Math.cos(theta),sin=Math.sin(theta);
    const normal=rgb(l.color),px=l.pixel||{},pixel=px.enabled===true;
    const block=clamp(px.size??6,2,32);
    const levels=clamp(px.steps??6,2,24);
    const halfW=d.w/2,halfH=d.h/2;
    for(let y=y0;y<y1;y++){
      const wy=chunkY+(y+.5)*scale-b.y,row=y*CHUNK_PX*4;
      for(let x=x0;x<x1;x++){
        const wx=chunkX+(x+.5)*scale-b.x;
        let lx=cos*wx+sin*wy,ly=-sin*wx+cos*wy;
        if(pixel){
          lx=Math.floor((lx+halfW)/block)*block+block*.5-halfW;
          ly=Math.floor((ly+halfH)/block)*block+block*.5-halfH;
        }
        let power=falloff(l,lx/halfW,ly/halfH);
        if(pixel)power=Math.round(power*levels)/levels;
        const alpha=power*a;
        if(alpha<=0)continue;
        lit=true;
        const i=row+x*4;
        const nr=Math.round(normal[0]*alpha),ng=Math.round(normal[1]*alpha),nb=Math.round(normal[2]*alpha);
        if(nr>dst[i])dst[i]=nr;
        if(ng>dst[i+1])dst[i+1]=ng;
        if(nb>dst[i+2])dst[i+2]=nb;
        dst[i+3]=255;
      }
    }
  }
  if(!lit)return null;
  ctx.putImageData(image,0,0);
  return c;
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
export function clearLightCache(){masks.clear();chunks.clear();staticPreviewViews.clear();cachedMapKey=null;pendingChunks=false;}
// Targeted invalidation: editing one light must not throw away the entire
// scene's baked illumination. Keep all chunks unaffected by its old/new bounds.
export function invalidateLightRegions(before,after){
  if(!cachedMapKey||!chunks.size)return 0;
  const regions=[before,after].filter(Boolean).map(bounds).map(b=>({
    left:b.x-b.w/2,right:b.x+b.w/2,top:b.y-b.h/2,bottom:b.y+b.h/2
  }));
  let count=0;
  for(const key of [...chunks.keys()]){
    const [x,y]=key.split(':').map(Number),left=x*CHUNK_WORLD,top=y*CHUNK_WORLD;
    if(regions.some(b=>b.right>left&&b.left<left+CHUNK_WORLD&&b.bottom>top&&b.top<top+CHUNK_WORLD)){
      chunks.delete(key);count++;
    }
  }
  if(count)pendingChunks=true;
  // Light drag/resize changes sprites even when the map revision stays stable.
  if(before||after)staticPreviewViews.clear();
  return count;
}
export function hasPendingChunks(){return pendingChunks;}
export function cacheSize(){return {masks:masks.size,views:chunks.size};}
function drawUnionChunks(g,lights,project,width,height){
  const scale=project.scale();if(!(scale>0))return;
  const worldLeft=Math.max(0,-project.x(0)/scale);
  const worldRight=Math.max(0,(width-project.x(0))/scale);
  const worldTop=Math.max(0,-project.y(0)/scale);
  const worldBottom=Math.max(0,(height-project.y(0))/scale);
  const left=Math.floor(worldLeft/CHUNK_WORLD),right=Math.floor(worldRight/CHUNK_WORLD);
  const top=Math.floor(worldTop/CHUNK_WORLD),bottom=Math.floor(worldBottom/CHUNK_WORLD);
  let built=0;
  pendingChunks=false;
  g.save();g.globalCompositeOperation='screen';g.globalAlpha=1;
  // Preserve hard logical-pixel edges when union chunks contain pixel-art lights.
  g.imageSmoothingEnabled=!lights.some(l=>l.pixel?.enabled);
  for(let cy=top;cy<=bottom;cy++)for(let cx=left;cx<=right;cx++){
    const key=cx+':'+cy;
    // Avoid building empty regions; native autotiles do the same kind of
    // visibility/cell culling rather than resampling blank map pixels.
    const worldX=cx*CHUNK_WORLD,worldY=cy*CHUNK_WORLD;
    const intersects=lights.some(l=>{
      const b=bounds(l);
      return b.x+b.w/2>worldX&&b.x-b.w/2<worldX+CHUNK_WORLD&&
        b.y+b.h/2>worldY&&b.y-b.h/2<worldY+CHUNK_WORLD;
    });
    if(!intersects)continue;
    if(!chunks.has(key)){
      if(built>=CHUNKS_PER_PASS){pendingChunks=true;continue;}
      built++;
    }
    const bitmap=cachedChunk(cx,cy,lights);if(!bitmap)continue;
    const x=project.x(cx*CHUNK_WORLD/32),y=project.y(cy*CHUNK_WORLD/32);
    const d=CHUNK_WORLD*scale;
    g.drawImage(bitmap,x,y,d,d);
  }
  g.restore();
}
function drawCachedStaticPreview(g,lights,project,width,height,t,group='all'){
  // Tile/autotile-style world viewport cache: bucket camera scroll so a
  // single composited texture survives many pan frames (instead of a new
  // multi-megabyte canvas at every scroll pixel).
  const scrollX=Number(project.scrollX)||0,scrollY=Number(project.scrollY)||0;
  const bucket=128,anchorX=Math.floor(scrollX/bucket)*bucket,anchorY=Math.floor(scrollY/bucket)*bucket;
  const offX=scrollX-anchorX,offY=scrollY-anchorY;
  const useBucket=project.scrollX!=null && project.scrollY!=null;
  const pad=useBucket?bucket:0;
  const w=width+pad,h=height+pad;
  if(w<=0||h<=0||w*h>3200000){for(const l of lights)stamp(g,l,project,t,'screen');return;}
  const key=useBucket ?
    [group,project.mapId,project.revision,anchorX,anchorY,project.tileSize,project.previewHour,width,height].join('|'):
    [group,project.mapId,project.revision,project.viewportKey,width,height].join('|');
  let surface=staticPreviewViews.get(key);
  if(surface){staticPreviewViews.delete(key);staticPreviewViews.set(key,surface);}
  else{
    surface=newCanvas(w,h);
    const sg=surface.getContext('2d');
    if(!sg){for(const l of lights)stamp(g,l,project,t,'screen');return;}
    const shifted=useBucket?{
      ...project,x:x=>project.x(x)+offX,y:y=>project.y(y)+offY,
      viewWidth:w,viewHeight:h
    }:project;
    for(const l of lights)stamp(sg,l,shifted,t,'screen');
    staticPreviewViews.set(key,surface);
    while(staticPreviewViews.size>STATIC_PREVIEW_LIMIT)staticPreviewViews.delete(staticPreviewViews.keys().next().value);
  }
  g.save();g.globalCompositeOperation='screen';
  if(useBucket)g.drawImage(surface,-offX,-offY);
  else g.drawImage(surface,0,0);
  g.restore();
}
export function drawLights(g,lights,project,width,height,t=0,overlapMode='union'){
  const visible=(lights||[]).filter(l=>l.enabled!==false);
  if(!visible.length)return;
  const key=String(project.mapId??'map')+':'+String(project.revision??0);
  if(key!==cachedMapKey){chunks.clear();cachedMapKey=key;pendingChunks=false;}
  const union=visible.filter(l=>['union','add',''].includes(l.blendMode||'union'));
  const sums=visible.filter(l=>l.blendMode==='sum');
  const merged=overlapMode==='sum'?[]:union;
  const summed=overlapMode==='sum'?[...union,...sums]:sums;
  const staticLights=merged.filter(l=>!l.pulse?.enabled);
  const pulsing=merged.filter(l=>l.pulse?.enabled);
  const chunkable=staticLights.filter(l=>l.type!=='mask'&&l.maskEnabled!==true);
  const masked=staticLights.filter(l=>l.type==='mask'||l.maskEnabled===true);
  if(overlapMode==='fast'){
    if(staticLights.length)drawCachedStaticPreview(g,staticLights,project,width,height,t,'fast');
  }else{
    if(chunkable.length===1)stamp(g,chunkable[0],project,t,'screen');
    else if(chunkable.length>1)drawUnionChunks(g,chunkable,project,width,height);
    // Already-masked textures are cached in their own layer; world-chunk
    // baking would otherwise ignore their alpha stencil entirely.
    if(masked.length)drawCachedStaticPreview(g,masked,project,width,height,t,'masked');
  }
  for(const l of pulsing)stamp(g,l,project,t,'screen');
  for(const l of summed)stamp(g,l,project,t,'lighter');
  for(const l of visible){
    const mode=l.blendMode||'union';
    if(['union','add','sum'].includes(mode))continue;
    stamp(g,l,project,t,mode==='subtract'?'multiply':'source-over');
  }
}
