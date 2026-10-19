// Lighting Studio Canvas preview. Native light masks are cached (LRU), not rasterized per frame.
// Radius pulsing reuses the same image, applying only a draw-time scale.
const CACHE_LIMIT=12, MASK_MAX=128;
const maskCache=new Map();
const clamp=(v,lo,hi)=>Math.min(hi,Math.max(lo,Number(v)||0));
const rgb=(hex)=>/^#[0-9A-F]{6}$/i.test(String(hex||''))?[1,3,5].map(i=>parseInt(hex.slice(i,i+2),16)):[255,206,138];
export function evaluated(light,t){
 const p=light.pulse||{},wave=p.enabled?Math.sin(t*Math.PI*2*(p.speedHz||1)+(p.phase||0)*Math.PI/180):0;
 const factor=1+wave*(p.radius||0);
 return {radius:Math.max(8,light.radiusPx*factor),scale:Math.max(.1,factor),
  intensity:clamp(light.intensity*(1+wave*(p.intensity||0)),0,1)};
}
export function dimensions(l){
 return (l.type==='ellipse'||l.type==='rectangle')
   ? {w:Math.max(8,Number(l.widthPx)||160),h:Math.max(8,Number(l.heightPx)||96)}
   : {w:Math.max(8,Number(l.radiusPx)||96)*2,h:Math.max(8,Number(l.radiusPx)||96)*2};
}
function strength(l,x,y){
 const soft=clamp(l.softness||.75,.05,1),type=l.type||'radial';
 let d;
 if(type==='rectangle'){d=Math.max(Math.abs(x),Math.abs(y));}
 else if(type==='ellipse'){d=Math.hypot(x,y);}
 else if(type==='cone'){
  const angle=clamp(l.angle||70,5,170)*Math.PI/360;
  const angular=Math.abs(Math.atan2(y,x))/angle;
  d=Math.max(Math.hypot(x,y),angular);
 }else{d=Math.hypot(x,y);}
 const shaped=d>=1?0:Math.pow(Math.max(0,1-d),1/soft);
 const center=Math.max(0,Math.min(1,l.centerStrength??0.65));
 return shaped*(center+(1-center)*Math.min(1,d*2));
}
function newCanvas(w,h){
 const c=typeof OffscreenCanvas!=='undefined'?new OffscreenCanvas(w,h):document.createElement('canvas');
 c.width=w;c.height=h;return c;
}
function maskKey(l){
 const p=l.pixel||{};
 return [l.type||'radial',l.radiusPx,l.widthPx,l.heightPx,l.angle,l.color,l.softness,l.centerStrength,p.enabled?1:0,p.size,p.steps].join('|');
}
function createMask(l){
 const dims=dimensions(l),factor=Math.min(1,MASK_MAX/Math.max(dims.w,dims.h));
 const w=Math.max(2,Math.round(dims.w*factor)),h=Math.max(2,Math.round(dims.h*factor));
 const c=newCanvas(w,h),ctx=c.getContext('2d');
 if(!ctx)return null;
 const [red,green,blue]=rgb(l.color),pixel=l.pixel||{};
 if(pixel.enabled){
   const cell=Math.max(1,Math.round((pixel.size||6)*factor)),steps=Math.max(2,Math.round(pixel.steps||6));
   ctx.fillStyle='transparent';ctx.clearRect(0,0,w,h);
   for(let py=0;py<h;py+=cell)for(let px=0;px<w;px+=cell){
     const normX=((px+cell*.5)/w-.5)*2,normY=((py+cell*.5)/h-.5)*2;
     const a=Math.round(strength(l,normX,normY)*steps)/steps;
     if(a<=0)continue;
     ctx.fillStyle='rgba('+red+','+green+','+blue+','+a+')';
     ctx.fillRect(px,py,Math.min(cell,w-px),Math.min(cell,h-py));
   }
 }else{
   const im=ctx.createImageData(w,h),a=im.data;
   for(let py=0;py<h;py++)for(let px=0;px<w;px++){
     const normX=((px+.5)/w-.5)*2,normY=((py+.5)/h-.5)*2;
     const alpha=Math.round(255*strength(l,normX,normY)),at=(py*w+px)*4;
     a[at]=red;a[at+1]=green;a[at+2]=blue;a[at+3]=alpha;
   }
   ctx.putImageData(im,0,0);
 }
 return c;
}
function cachedMask(l){
 const key=maskKey(l);
 if(maskCache.has(key)){
   const value=maskCache.get(key);maskCache.delete(key);maskCache.set(key,value);return value;
 }
 const value=createMask(l);
 if(!value)return null;
 maskCache.set(key,value);
 if(maskCache.size>CACHE_LIMIT)maskCache.delete(maskCache.keys().next().value);
 return value;
}
export function clearLightCache(){maskCache.clear();}
export function cacheSize(){return maskCache.size;}
export function drawLights(g,lights,project,width,height,t=0){
 for(const l of lights||[]){
  if(l.enabled===false)continue;
  const dims=dimensions(l),animated=evaluated(l,t),scale=animated.scale*project.scale();
  const x=project.x(l.x),y=project.y(l.y);
  const maxR=Math.hypot(dims.w,dims.h)*scale*.5;
  if(x+maxR<0||y+maxR<0||x-maxR>width||y-maxR>height)continue;
  const bitmap=cachedMask(l);if(!bitmap)continue;
  g.save();
  g.globalCompositeOperation=l.blendMode==='normal'?'source-over':l.blendMode==='subtract'?'multiply':'lighter';
  g.globalAlpha=animated.intensity;
  g.imageSmoothingEnabled=!l.pixel?.enabled;
  g.translate(x,y);
  g.rotate((Number(l.rotation)||0)*Math.PI/180);
  const w=dims.w*scale,h=dims.h*scale;
  // For multiply, an alpha-black mask darkens map pixels without covering whole screen.
  if(l.blendMode==='subtract')g.filter='brightness(0)';
  g.drawImage(bitmap,-w/2,-h/2,w,h);
  g.restore();
 }
}
