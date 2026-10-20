// Lighting Studio Mask Painter — PNG-based light authoring for caves and windows.
// No external dependencies. All drawing takes place on a transparent RGBA canvas;
// the game applies luminance * alpha exactly as with imported masks.
const clamp=(x,a,b)=>Math.max(a,Math.min(b,x));
export function caveTemplate(width=256,height=128,direction='right'){
 const c=document.createElement('canvas');c.width=width;c.height=height;
 const ctx=c.getContext('2d'),img=ctx.createImageData(width,height),pixels=img.data;
 const smooth=(x)=>{x=clamp(x,0,1);return x*x*(3-2*x);};
 for(let y=0;y<height;y++)for(let x=0;x<width;x++){
  const u=direction==='left'?1-(x+.5)/width:(x+.5)/width;
  const v=(y+.5)/height;
  // A cave mouth is narrow at the source, then its projected light fans out.
  // The irregular outline gives an organic cave-exit shape without hard edges.
  const mouth=.055,opening=.18+u*.25;
  const wobble=.018*Math.sin(u*16.8+1)+.009*Math.sin(u*41.0+v*6);
  const deviation=Math.abs(v-.50+wobble);
  const edge=1-smooth((deviation-(opening-.07))/.09);
  const front=smooth((u-.02)/.065);
  const tail=1-smooth((u-.71)/.29);
  const light=clamp(edge*front*tail*(.96-.22*u),0,1);
  const i=(y*width+x)*4;
  pixels[i]=255;pixels[i+1]=255;pixels[i+2]=255;
  pixels[i+3]=Math.round(light*255);
 }
 ctx.putImageData(img,0,0);
 return c;
}
export function blankMask(width=256,height=128){
 const c=document.createElement('canvas');c.width=width;c.height=height;return c;
}
export function cloneImage(image){
 const c=blankMask(image.width,image.height);
 c.getContext('2d').drawImage(image,0,0);
 return c;
}
function dataUrlToBytes(dataUrl){
 const encoded=dataUrl.substring(dataUrl.indexOf(',')+1),binary=atob(encoded);
 const bytes=new Uint8Array(binary.length);
 for(let i=0;i<binary.length;i++)bytes[i]=binary.charCodeAt(i);
 return bytes;
}
export async function saveMaskPng(ctx,name,canvas,folder){
 // We only allow a simple filename provided by maskFilename() upstream.
 if(!/^[a-zA-Z0-9_-]{1,70}\.png$/i.test(name))throw Error('El nombre de la máscara debe ser un PNG válido.');
 if(canvas.width>512||canvas.height>512)throw Error('La máscara no puede superar 512×512.');
 const rel=folder+'/'+name;
 const bytes=dataUrlToBytes(canvas.toDataURL('image/png'));
 try{await ctx.fs.projectMkdir(folder);}catch(_err){
  // Read-only projects can still export a reusable PNG.
 }
 const fs=ctx.fs;
 // Some Maker Studio builds expose binary project writes through the mod FS.
 if(typeof fs.writeProjectBinaryFile==='function'){
  try{await fs.writeProjectBinaryFile(rel,bytes);return {saved:true,path:rel};}
  catch(_err){/* Try alternate API or portable PNG export. */}
 }
 if(typeof fs.writeProjectBytes==='function'){
  try{await fs.writeProjectBytes(rel,bytes);return {saved:true,path:rel};}
  catch(_err){/* Try alternate API or portable PNG export. */}
 }
 // Maker Studio Tauri builds may expose the same binary API used by the PNG
 // reader. If the write command is unavailable, use safe export below.
 const invoke=window.__TAURI__?.core?.invoke,root=ctx.editor?.gameRoot?.();
 if(typeof invoke==='function'&&root){
  const sep=root.includes('\\')?'\\':'/';
  const full=root.replace(/[\\/]+$/,'')+sep+rel.replaceAll('/',sep);
  for(const payload of [{path:full,bytes:Array.from(bytes)},{path:full,data:Array.from(bytes)}]){
   try{await invoke('write_binary_file',payload);return {saved:true,path:rel};}
   catch(_err){/* unsupported or signature differs: use export fallback */}
  }
 }
 // Always preserve the drawn work, even on older versions of Maker Studio.
 const link=document.createElement('a'),url=URL.createObjectURL(new Blob([bytes],{type:'image/png'}));
 try{
  link.href=url;link.download=name;document.body.append(link);link.click();link.remove();
 }finally{setTimeout(()=>URL.revokeObjectURL(url),5000);}
 return {saved:false,path:rel};
}
export function mountMaskPainter(host,opts){
 const {filename,getSource,onPreview,onSave,onCreate,notify}=opts;
 const el=(tag,cls,text)=>{const e=document.createElement(tag);if(cls)e.className=cls;if(text!==undefined)e.textContent=text;return e;};
 const root=el('div','ls-mask-workbench');host.append(root);
 root.append(el('div','ls-group-label','DIBUJAR LA ZONA ILUMINADA'));
 root.append(el('p','ls-inline-note','Pinta la luz en blanco. Borra las zonas bloqueadas por las paredes. Lo transparente NO ilumina. La plantilla crea un haz irregular que sale de la cueva.'));
 const toolbar=el('div','ls-mask-tools'),canvasFrame=el('div','ls-mask-canvas-frame');
 root.append(toolbar,canvasFrame);
 const src=getSource();
 let draft=src?cloneImage(src):caveTemplate();
 if(!src)onCreate(draft);
 const stage=el('div','ls-mask-canvas-stage');canvasFrame.append(stage);
 const canvas=el('canvas','ls-mask-canvas');canvas.width=draft.width;canvas.height=draft.height;
 stage.style.aspectRatio=draft.width+'/'+draft.height;
 stage.append(canvas);
 const guide=el('img','ls-mask-reference');guide.alt='Gráfico de la cueva (referencia no exportada)';
 guide.hidden=true;stage.prepend(guide);
 const polyLayer=el('canvas','ls-mask-poly-preview');
 polyLayer.width=canvas.width;polyLayer.height=canvas.height;
 stage.append(polyLayer);
 const polyCtx=polyLayer.getContext('2d');
 const brush=canvas.getContext('2d');brush.drawImage(draft,0,0);
 const status=el('div','ls-mask-status','Pinta con el ratón y observa la forma encima del mapa.');root.append(status);
 const group=(label,callback)=>{const b=el('button','ls-btn ls-small',label);b.type='button';b.onclick=callback;toolbar.append(b);return b;};
 let mode='paint',radius=10,drag=false,last=null;
 let polygon=[];
 const renderPolygon=()=>{
  polyCtx.clearRect(0,0,polyLayer.width,polyLayer.height);
  if(!polygon.length)return;
  polyCtx.lineWidth=2;polyCtx.strokeStyle='#F8D78A';polyCtx.setLineDash([5,4]);
  polyCtx.beginPath();polygon.forEach((p,i)=>{if(i)polyCtx.lineTo(p.x,p.y);else polyCtx.moveTo(p.x,p.y);});
  polyCtx.stroke();polyCtx.setLineDash([]);
 };
 const completePolygon=()=>{
  if(polygon.length<3)return;
  snapshot();
  brush.save();brush.globalCompositeOperation='source-over';brush.fillStyle='rgba(255,255,255,1)';
  brush.beginPath();polygon.forEach((p,i)=>{if(i)brush.lineTo(p.x,p.y);else brush.moveTo(p.x,p.y);});
  brush.closePath();brush.fill();brush.restore();polygon=[];renderPolygon();signal();
 };
 const history=[],future=[];
 const snapshot=()=>{history.push(brush.getImageData(0,0,canvas.width,canvas.height));if(history.length>15)history.shift();future.length=0;};
 const signal=()=>{onPreview(canvas);status.textContent='Vista previa actualizada · pulsa «Guardar PNG» para usarla ingame.';};
 const toolButtons=[];
 for(const [id,label] of [['paint','✎ Añadir luz'],['dim','◐ Luz tenue'],['erase','⌫ Borrar'],['polygon','⬡ Delimitar forma']]){
  const b=group(label,()=>{mode=id;polygon=[];renderPolygon();toolButtons.forEach(([x,v])=>v.classList.toggle('active',x===id));status.textContent=id==='polygon'?'Marca el contorno por puntos. Doble clic para rellenarlo.':'Arrastra sobre la imagen para modificar la luz.';});
  toolButtons.push([id,b]);
 }
 toolButtons[0][1].classList.add('active');
 const slider=el('label','ls-mask-brush');slider.textContent='Pincel ';
 const range=el('input');range.type='range';range.min='2';range.max='48';range.value='10';range.oninput=()=>{radius=Number(range.value);};
 slider.append(range);toolbar.append(slider);
 // The bitmap remains at its native resolution: zoom changes only CSS
 // presentation, like zooming Maker Studio's tile canvas.
 const zoomControl=el('label','ls-mask-zoom');zoomControl.textContent='Zoom de máscara ';
 const zoomSelect=el('select','ls-input');
 for(const [value,label] of [['fit','Ajustar'],['1','1×'],['2','2×'],['4','4×']]){
  const option=el('option',null,label);option.value=value;zoomSelect.append(option);
 }
 zoomSelect.value='fit';
 const applyZoom=()=>{
  const scale=Number(zoomSelect.value);
  stage.style.width=zoomSelect.value==='fit'?'100%':Math.round(canvas.width*scale)+'px';
  stage.style.aspectRatio=canvas.width+'/'+canvas.height;
 };
 zoomSelect.addEventListener('change',applyZoom);
 zoomControl.append(zoomSelect);toolbar.append(zoomControl);
 applyZoom();
 const point=ev=>{const rect=canvas.getBoundingClientRect();return{x:(ev.clientX-rect.left)*canvas.width/rect.width,y:(ev.clientY-rect.top)*canvas.height/rect.height};};
 const stroke=(to,from)=>{
  brush.save();
  brush.globalCompositeOperation=mode==='erase'?'destination-out':'source-over';
  brush.strokeStyle=mode==='erase'?'rgba(0,0,0,1)':mode==='dim'?'rgba(255,255,255,0.32)':'rgba(255,255,255,1)';
  brush.lineWidth=radius*2;brush.lineCap='round';brush.lineJoin='round';
  brush.beginPath();brush.moveTo(from.x,from.y);brush.lineTo(to.x,to.y);brush.stroke();brush.restore();
 };
 canvas.addEventListener('pointerdown',ev=>{if(ev.button!==0)return;ev.preventDefault();
  if(mode==='polygon'){if(ev.detail>=2){completePolygon();return;}polygon.push(point(ev));renderPolygon();return;}
  snapshot();drag=true;last=point(ev);canvas.setPointerCapture?.(ev.pointerId);stroke(last,last);});
 canvas.addEventListener('pointermove',ev=>{if(!drag)return;ev.preventDefault();const p=point(ev);stroke(p,last);last=p;});
 const release=()=>{if(!drag)return;drag=false;last=null;signal();};
 canvas.addEventListener('pointerup',release);canvas.addEventListener('pointercancel',release);
 const actions=el('div','ls-mask-actions');root.append(actions);
 const action=(label,callback)=>{const b=el('button','ls-btn ls-small',label);b.type='button';b.onclick=callback;actions.append(b);return b;};
 const replaceWith=created=>{snapshot();draft=created;canvas.width=created.width;canvas.height=created.height;polyLayer.width=created.width;polyLayer.height=created.height;polygon=[];stage.style.aspectRatio=created.width+'/'+created.height;applyZoom();canvas.getContext('2d').drawImage(created,0,0);signal();};
 action('➜ Salida de cueva',()=>replaceWith(caveTemplate(256,128,'right')));
 action('⬅ Cueva hacia izquierda',()=>replaceWith(caveTemplate(256,128,'left')));
 action('Lienzo vacío',()=>replaceWith(blankMask(canvas.width,canvas.height)));
 const guideInput=el('input');guideInput.type='file';guideInput.accept='image/png,image/jpeg,image/webp';guideInput.hidden=true;root.append(guideInput);
 action('▣ Calcar sobre imagen de cueva',()=>guideInput.click());
 guideInput.onchange=()=>{
  const file=guideInput.files?.[0];if(!file)return;
  if(!file.type.startsWith('image/'))return notify('Elige PNG, JPG o WEBP.','warn');
  const url=URL.createObjectURL(file);
  guide.onload=()=>{URL.revokeObjectURL(url);guide.hidden=false;status.textContent='Guía cargada. Pinta o delimita la zona luminosa encima; la imagen de referencia no se exportará.';};
  guide.onerror=()=>{URL.revokeObjectURL(url);notify('No se pudo cargar la imagen de referencia.','warn');};
  guide.src=url;
 };
 action('Mostrar / ocultar guía',()=>{if(guide.src)guide.hidden=!guide.hidden;});
 action('Deshacer trazo',()=>{if(!history.length)return;future.push(brush.getImageData(0,0,canvas.width,canvas.height));brush.putImageData(history.pop(),0,0);signal();});
 action('Rehacer trazo',()=>{if(!future.length)return;history.push(brush.getImageData(0,0,canvas.width,canvas.height));brush.putImageData(future.pop(),0,0);signal();});
 const save=action('Guardar PNG',async()=>{save.disabled=true;try{const result=await onSave(filename,canvas);status.textContent=result.saved?'Guardado en '+result.path:'PNG exportado: cópialo a '+result.path;notify(status.textContent,result.saved?'info':'warn');}catch(e){status.textContent='Error: '+e.message;notify(status.textContent,'error');}finally{save.disabled=false;}});
 return canvas;
}
