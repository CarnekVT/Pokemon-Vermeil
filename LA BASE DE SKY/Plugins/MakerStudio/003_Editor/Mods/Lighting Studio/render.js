// Lighting Studio: cached source masks + one unified add-light canvas per map frame.
// Add lights are merged with MAX-like "lighten", then applied ONCE with "screen".
// Geometry and fading mirror the Ruby runtime; the 2D editor is an approximation.
const MASK_LIMIT=16, MASK_MAX=128, COMPOSITE_SCALE=0.5;
const masks=new Map();
let sharedView=null,sharedKey=null;
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
// Channel-wise maximum, not Canvas "lighten" (which still accumulates alpha).
// The output is opaque pre-multiplied RGB; black adds zero with screen blending.
export function mergeColorMax(dst,pos,r,g,b,alpha){
  const a=alpha/255;
  dst[pos]=Math.max(dst[pos],Math.round(r*a));
  dst[pos+1]=Math.max(dst[pos+1],Math.round(g*a));
  dst[pos+2]=Math.max(dst[pos+2],Math.round(b*a));
  dst[pos+3]=255;
}
let scratchView=null;
function fillUnified(buffer,ctx,lights,project,width,height,t){
  const p={x:x=>project.x(x)*COMPOSITE_SCALE,y:y=>project.y(y)*COMPOSITE_SCALE,
    scale:()=>project.scale()*COMPOSITE_SCALE};
  if(!scratchView||scratchView.width!==width||scratchView.height!==height)
    scratchView=newCanvas(width,height);
  const work=scratchView.getContext('2d');
  if(!work)return;
  const result=ctx.createImageData(width,height),dest=result.data;
  // Opaque black pixels are neutral in final screen blend.
  for(let i=3;i<dest.length;i+=4)dest[i]=255;
  for(const l of lights){
    const dims=dimensions(l),anim=evaluated(l,t),scale=anim.scale*p.scale();
    const w=dims.w*scale,h=dims.h*scale;
    const rotation=(Number(l.rotation)||0)*Math.PI/180;
    const c=Math.abs(Math.cos(rotation)),si=Math.abs(Math.sin(rotation));
    const bw=c*w+si*h,bh=si*w+c*h;
    const cx=p.x(l.x),cy=p.y(l.y);
    const left=Math.max(0,Math.floor(cx-bw*.5)-1);
    const top=Math.max(0,Math.floor(cy-bh*.5)-1);
    const right=Math.min(width,Math.ceil(cx+bw*.5)+1);
    const bottom=Math.min(height,Math.ceil(cy+bh*.5)+1);
    if(left>=right||top>=bottom)continue;
    work.save();work.globalCompositeOperation='source-over';work.clearRect(left,top,right-left,bottom-top);work.restore();
    stamp(work,l,p,t,'source-over');
    const area=work.getImageData(left,top,right-left,bottom-top).data;
    const stride=(right-left),rows=(bottom-top);
    for(let row=0;row<rows;row++){
      const outRow=((top+row)*width+left)*4,srcRow=row*stride*4;
      for(let col=0;col<stride;col++){
        const si=srcRow+col*4,a=area[si+3];
        if(a===0)continue;
        mergeColorMax(dest,outRow+col*4,area[si],area[si+1],area[si+2],a);
      }
    }
  }
  ctx.save();ctx.globalCompositeOperation='copy';ctx.putImageData(result,0,0);ctx.restore();
}
function getUnion(lights,project,width,height,t){
  const w=Math.max(1,Math.ceil(width*COMPOSITE_SCALE));
  const h=Math.max(1,Math.ceil(height*COMPOSITE_SCALE));
  const animated=lights.some(l=>l.pulse?.enabled);
  const stable=project.viewportKey!==undefined&&project.revision!==undefined;
  const key=stable?[project.viewportKey,project.revision,animated?Math.floor(t*8):0,w,h].join('~'):null;
  // A single viewport surface is reused across camera/zoom changes.
  // Reallocating a whole canvas at every wheel tick creates severe editor stalls.
  if(sharedView&&sharedView.width===w&&sharedView.height===h&&key&&key===sharedKey)return sharedView;
  if(!sharedView||sharedView.width!==w||sharedView.height!==h)sharedView=newCanvas(w,h);
  const ctx=sharedView.getContext('2d');
  if(!ctx)return null;
  ctx.save();ctx.globalAlpha=1;ctx.globalCompositeOperation='source-over';
  ctx.clearRect(0,0,w,h);
  ctx.restore();
  fillUnified(sharedView,ctx,lights,project,w,h,t);
  sharedKey=key;
  return sharedView;
}
export function clearLightCache(){masks.clear();sharedView=null;scratchView=null;sharedKey=null;}
export function cacheSize(){return {masks:masks.size,views:sharedView?1:0};}
export function drawLights(g,lights,project,width,height,t=0,overlapMode='union'){
  const visible=(lights||[]).filter(l=>l.enabled!==false);
  if(!visible.length)return;
  const union=visible.filter(l=>['union','add',''].includes(l.blendMode||'union'));
  const sums=visible.filter(l=>l.blendMode==='sum');
  // The map-level selector enables intentional accumulation where requested.
  const merged=overlapMode==='sum'?[]:union;
  const summed=overlapMode==='sum'?[...union,...sums]:sums;
  if(merged.length===1){
    // A single light does not need an offscreen compositor. This also
    // guarantees a visible fallback if the platform cannot make canvases.
    stamp(g,merged[0],project,t,'screen');
  }else if(merged.length>1){
    try{
      const surface=getUnion(merged,project,width,height,t);
      if(surface){
        g.save();g.globalAlpha=1;g.globalCompositeOperation='screen';g.imageSmoothingEnabled=true;
        g.drawImage(surface,0,0,surface.width/COMPOSITE_SCALE,surface.height/COMPOSITE_SCALE);
        g.restore();
      }else{
        // Never silently hide all sources if canvas allocation fails.
        for(const l of merged)stamp(g,l,project,t,'screen');
      }
    }catch(error){
      // Render fallback; the editor's overlay is responsible for logging errors.
      for(const l of merged)stamp(g,l,project,t,'screen');
    }
  }
  for(const l of summed)stamp(g,l,project,t,'lighter');
  for(const l of visible){
    const mode=l.blendMode||'union';
    if(mode==='union'||mode==='add'||mode==='sum')continue;
    stamp(g,l,project,t,mode==='subtract'?'multiply':'source-over');
  }
}
