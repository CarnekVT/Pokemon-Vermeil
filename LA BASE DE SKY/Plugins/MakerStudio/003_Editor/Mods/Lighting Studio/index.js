import {DATA_PATH,defaultProject,normalizeProject,getMap,makeLight,deepCopy,parseCoordinate,LIGHT_TYPES,TYPE_NAMES,FADE_MODES,FADE_NAMES,NORMAL_CATEGORIES,NORMAL_DIR,MASK_DIR,maskFilename,assetName,normalCandidate,evaluateTimeOfDay} from './model.js';
import {STYLES,LIGHTING_EXTRA_CSS,LIGHTING_LAYER_DIAGNOSTIC_CSS,LIGHTING_WORKSPACE_CSS,LIGHTING_WIDE_WORKSPACE_CSS} from './styles.js';
import {point as pointerPoint, hitTest, paint} from './map_overlay.js';
import {cacheSize,clearLightCache,hasPendingChunks,invalidateLightRegions,setMaskImage,getMaskImage,removeMaskImage,forgetMaskImages} from './render.js';
import {mountMaskPainter,saveMaskPng,caveTemplate} from './mask_editor.js';
const PANEL='lighting-studio.main', TOOL='lighting-studio.place';
let state=null;
const node=(tag,text)=>{const e=document.createElement(tag);if(text!==undefined)e.textContent=String(text);return e;};
const css=STYLES+LIGHTING_EXTRA_CSS+LIGHTING_LAYER_DIAGNOSTIC_CSS+LIGHTING_WORKSPACE_CSS+LIGHTING_WIDE_WORKSPACE_CSS;
function notify(message,level='info'){state?.ctx.ui.showToast({message,level,durationMs:4000});}
function fail(e){const msg=String(e?.message||e);state?.ctx.log.error(msg);notify(msg,'error');}
function current(){return getMap(state.data,state.mapId,false);}
function active(){return current()?.lights.find(l=>l.id===state.selected)||null;}
function record(){state.undo.push(deepCopy(state.data));if(state.undo.length>60)state.undo.shift();state.redo=[];}
function invalidate(){if(state)state.revision=(state.revision||0)+1;}
function redraw(){
 const owner=state;if(!owner?.ctx)return;
 owner.redrawDirty=true;
 if(owner.redrawPending)return;
 owner.redrawPending=true;
 // Do not wait for an overlay acknowledgement: Maker Studio can coalesce
 // callback invocations while a different pane/tool is active.
 const elapsed=performance.now()-(owner.lastRedraw||0);
 setTimeout(()=>{
  if(state!==owner)return;
  owner.redrawPending=false;
  if(!owner.redrawDirty)return;
  owner.redrawDirty=false;
  owner.lastRedraw=performance.now();
  owner.lastRequestAt=owner.lastRedraw;
  owner.awaitingOverlay=true; // diagnostics only, never blocks redraw
  owner.ctx.editor.requestRedraw?.();
 },Math.max(0,(owner.previewQuality==='full'?85:owner.previewQuality==='fast'?110:65)-elapsed));
}
function settleFastPreview(){
 const owner=state;if(!owner)return;
 owner.fastPreviewUntil=performance.now()+350;
 if(owner.settleTimer!=null)clearTimeout(owner.settleTimer);
 owner.settleTimer=setTimeout(()=>{
   if(state!==owner)return;
   owner.fastPreviewUntil=0;
   owner.settleTimer=null;
   // Rebuild the exact merged illumination only after editing has stopped.
   redraw();
 },370);
}
function updateDiagnosticStatus(){if(!state?.statusNode)return;const stats=state.overlayStats,age=stats.lastAt?Date.now()-stats.lastAt:Infinity;state.statusNode.textContent=stats.errors?'Error al dibujar: '+stats.lastError:age<2500?'Mapa '+stats.lastMap+' · '+(stats.lastMs||0).toFixed(1)+' ms · espera '+Math.round(stats.requestDelayMs||0)+' ms · caché '+cacheSize().masks+'/'+cacheSize().views:'Sin respuesta del overlay · usa «Prueba visual»';state.statusNode.style.color=stats.errors?'#ff8e80':age<2500?'#82e2ae':'#f0c784';}
function change(fn){if(state.readError)throw Error('Archivo dañado: edición bloqueada.');record();fn();invalidate();redraw();refresh();schedulePersist();void preloadMasks().catch(fail);}
function undo(){if(!state.undo.length)return;state.redo.push(deepCopy(state.data));state.data=state.undo.pop();invalidate();redraw();refresh();void persist().catch(fail);}
function redo(){if(!state.redo.length)return;state.undo.push(deepCopy(state.data));state.data=state.redo.pop();invalidate();redraw();refresh();void persist().catch(fail);}
function schedulePersist(){
 const owner=state;if(!owner)return;
 if(owner.autosaveTimer!=null)clearTimeout(owner.autosaveTimer);
 owner.autosaveTimer=setTimeout(()=>{
  if(state!==owner)return;
  owner.autosaveTimer=null;
  void persist().catch(fail);
 },700);
}
function persist(){
 if(state?.autosaveTimer!=null){clearTimeout(state.autosaveTimer);state.autosaveTimer=null;}
 if(!state)return Promise.resolve();state.saveRequested=true;if(state.saving)return state.writer;state.saving=true;
 const owner=state;
 owner.writer=(async()=>{try{
 await owner.ctx.fs.projectMkdir('Data/LightingStudio');
 while(owner.saveRequested){owner.saveRequested=false;const data=JSON.stringify(owner.data,null,2)+'\n';await owner.ctx.fs.writeProjectFile(DATA_PATH,data);}
 }finally{owner.saving=false;}})();return owner.writer;}
async function load(){if(!(await state.ctx.fs.projectExists(DATA_PATH)))return defaultProject();return normalizeProject(JSON.parse(await state.ctx.fs.readProjectFile(DATA_PATH)));}
function btn(text,run){const b=node('button',text);b.className='ls-btn';b.type='button';b.addEventListener('click',()=>{try{run();}catch(e){fail(e);}});return b;}
function field(host,label,type,value,onChange,settings={}){const row=node('label');row.className='ls-field';row.append(node('span',label));const input=node('input');input.type=type;input.value=String(value);if(settings.min!==undefined)input.min=settings.min;if(settings.max!==undefined)input.max=settings.max;if(settings.step!==undefined)input.step=settings.step;input.addEventListener('change',()=>{try{onChange(type==='number'?Number(input.value):input.value);}catch(e){fail(e);}});row.append(input);host.append(row);}
function drawCanvas(canvas,map){const rect=canvas.getBoundingClientRect();canvas.width=Math.max(200,Math.floor(rect.width*devicePixelRatio));canvas.height=Math.floor(170*devicePixelRatio);const g=canvas.getContext('2d');const w=canvas.width,h=canvas.height;g.fillStyle='#1D2D40';g.fillRect(0,0,w,h);const a=map?.ambient||{color:'#142439',darkness:0.42};g.fillStyle=a.color;g.globalAlpha=a.darkness;g.fillRect(0,0,w,h);g.globalAlpha=1;for(const l of map?.lights||[]){if(!l.enabled)continue;const x=w/2+(l.x-8)*14*devicePixelRatio,y=h/2+(l.y-6)*14*devicePixelRatio,r=Math.max(1,l.radiusPx*devicePixelRatio*.5);const grad=g.createRadialGradient(x,y,0,x,y,r);grad.addColorStop(0,l.color);grad.addColorStop(1,'transparent');g.globalAlpha=l.intensity;g.fillStyle=grad;g.fillRect(x-r,y-r,r*2,r*2);}g.globalAlpha=1;}

function element(tag,cls,text){const n=node(tag,text);if(cls)n.className=cls;return n;}
function labeled(parent,name,control){const r=element('label','ls-field');r.append(element('span','ls-field-label',name),control);parent.append(r);return r;}
function slider(parent,name,value,min,max,step,cb){const wrap=element('div','ls-field');wrap.append(element('span','ls-field-label',name),element('span','ls-field-val',Math.round(value*100)/100));const row=element('div','ls-range-row');const range=element('input','ls-range'),num=element('input','ls-input ls-number');range.type='range';num.type='number';for(const v of [range,num]){v.min=min;v.max=max;v.step=step;v.value=value;}const valueEl=wrap.children[1];range.addEventListener('input',()=>{num.value=range.value;valueEl.textContent=range.value;cb(Number(range.value),false);});range.addEventListener('change',()=>cb(Number(range.value),true));num.addEventListener('change',()=>{range.value=num.value;valueEl.textContent=num.value;cb(Number(num.value),true);});row.append(range,num);wrap.append(row);parent.append(wrap);}
function mini(label,fn,selected=false){const b=btn(label,fn);b.className='ls-btn ls-small'+(selected?' active':'');return b;}
function setMode(mode){state.mode=mode;state.ctx.editor.setTool(TOOL);redraw();refresh();}
// Normal maps are resource bindings, not a renderer claim. The Ruby lightmap
// does not yet implement normal-vector illumination. Keep this clearly visible.
function normalBindingsUI(shell,scene){
 const section=element('section','ls-section ls-normal-maps');
 shell.append(section);
 section.append(element('div','ls-section-heading','NORMAL MAPS · Catálogo global'));
 section.append(element('p','ls-inline-note',
   'Regla automática global por nombre del gráfico, incluidos jugador y seguidores. Los vínculos manuales son excepciones. Las normales del jugador y followers están activas en el runtime RGSS (sin shader GPU).'));
 const normals=state.data.normalSettings; // One global automatic catalog, not a list per map.
 const toggle=node('input');toggle.type='checkbox';toggle.checked=normals.enabled;
 toggle.onchange=()=>change(()=>{normals.enabled=toggle.checked;});
 labeled(section,'Habilitar asignaciones de normales (experimental)',toggle);
 const cat=node('select');cat.className='ls-input';
 for(const [key,name] of Object.entries(NORMAL_CATEGORIES)){
   const option=node('option',name==='Characters'?'OWs / Characters':name);
   option.value=key;cat.append(option);
 }
 cat.value=state.normalCategory;
 cat.onchange=()=>{state.normalCategory=cat.value;refresh();};
 labeled(section,'Tipo de recurso',cat);
 const category=state.normalCategory,folder=NORMAL_CATEGORIES[category];
 const auto=node('input');auto.type='checkbox';auto.checked=normals.auto[category]!==false;
 auto.onchange=()=>change(()=>normals.auto[category]=auto.checked);
 labeled(section,'Detección automática por nombre de sprite',auto);
 section.append(element('p','ls-inline-note',
  'Jugador y follower: se usa el nombre del gráfico activo. Por ejemplo, Followers/VENUSAUR → Followers/VENUSAUR'+normals.suffix+'.png. No necesitas un vínculo por Pokémon.'));

 section.append(element('p','ls-inline-note',
  'Normal PNG: '+NORMAL_DIR+'/'+folder+'/Nombre'+normals.suffix+'.png. Los sprites del jugador/follower se resuelven por su gráfico actual.'));
 const list=element('div','ls-list');section.append(list);
 const entries=normals[category]||[];
 if(!entries.length)list.append(element('div','ls-empty','No hay normales vinculadas en esta categoría.'));
 for(const binding of entries){
   const line=element('div','ls-item');list.append(line);
   const text=element('div','ls-item-main');
   text.append(element('div','ls-item-name',binding.source),
               element('div','ls-item-meta',binding.normal+'.png'));
   line.append(text);
   line.append(mini(binding.enabled===false?'Activar':'Desactivar',()=>change(()=>{binding.enabled=binding.enabled===false;})));
   line.append(mini(binding.invertY?'Y invertida':'Invertir Y',()=>change(()=>{binding.invertY=!binding.invertY;})));
   line.append(mini('×',()=>change(()=>{normals[category]=normals[category].filter(x=>x!==binding);})));
 }
 const actions=element('div','ls-inline');section.append(actions);
 actions.append(mini('＋ Vincular normal map',()=>{void addNormalBinding(category).catch(fail);}));
 actions.append(mini('Comprobar archivos',()=>{void verifyNormalBindings(category).catch(fail);}));
 slider(section,'Intensidad visual de normales',normals.intensity??0.5,0,1.5,.05,(v,final)=>editValue(()=>normals.intensity=clamp(v,0,1.5),final));
  const warm=node('input');warm.type='checkbox';warm.checked=normals.warmup!==false;
  warm.onchange=()=>change(()=>normals.warmup=warm.checked);
  labeled(section,'Precargar normales del personaje/followers',warm);
}
async function addNormalBinding(category){
 const owner=state;if(!owner||owner.readError)return;
 const dir=NORMAL_CATEGORIES[category],picker=owner.ctx.selectors?.pickGraphic;
 if(typeof picker!=='function'){notify('Esta versión de Maker Studio no admite el selector de imágenes.','warn');return;}
 const diffuse=await owner.ctx.selectors.pickGraphic(dir,{title:'Selecciona el '+dir+' original',fields:[]});
 if(!diffuse||state!==owner)return;
 const normal=await owner.ctx.selectors.pickGraphic('LightingStudio/Normals/'+dir,
   {title:'Selecciona el PNG normal correspondiente',fields:[]});
 if(!normal||state!==owner)return;
 const source=assetName(diffuse.name),normalName=assetName(normal.name);
 if(!source||!normalName){notify('Nombre de recurso inválido.','error');return;}
 if(!(await owner.ctx.fs.projectExists(NORMAL_DIR+'/'+dir+'/'+normalName+'.png'))){
   notify('No existe el PNG de normales seleccionado en Graphics.','warn');return;
 }
 if(state!==owner)return;
 const entries=owner.data.normalSettings[category];
 change(()=>{
   const entry={source,normal:normalName,invertY:false,enabled:true};
   const existing=entries.findIndex(x=>x.source===source);
   if(existing>=0)entries[existing]=entry;else entries.push(entry);
 });
 notify('Normal map asociado: '+source+' → '+normalName);
}
async function verifyNormalBindings(category){
 const owner=state;if(!owner)return;
 const entries=[...owner.data.normalSettings[category]];
 const folder=NORMAL_CATEGORIES[category];
 const missing=[];
 for(const entry of entries){
   if(!(await owner.ctx.fs.projectExists(NORMAL_DIR+'/'+folder+'/'+entry.normal+'.png')))missing.push(entry.normal+'.png');
 }
 if(state!==owner)return;
 notify(missing.length?'Faltan PNG: '+missing.slice(0,4).join(', '):'Todos los PNG normales asociados están presentes.',missing.length?'warn':'info');
}

// Mask PNG source caching is independent of in-flight IO. The old maskLoading
// Set never released names after success, so editing a PNG could require
// closing/reopening the editor to refresh it.
async function loadMaskFile(name,{force=false}={}){
 const owner=state;
 if(!owner||!maskFilename(name))return false;
 if(owner.maskLoading.has(name))return owner.maskPromises.get(name)||false;
 if(owner.maskReady.has(name)&&!force)return true;
 owner.maskLoading.add(name);
 const task=(async()=>{
 try{
  const rel=MASK_DIR+'/'+name;
  if(!await owner.ctx.fs.projectExists(rel)){
    owner.maskReady.delete(name);
    // An unsaved mask drawn in the editor is valid for live preview even
    // before its PNG exists on disk. Do not replace it with a blank mask.
    if(!owner.maskDrafts.has(name))removeMaskImage(name);
    return false;
  }
  const invoke=window.__TAURI__?.core?.invoke,root=owner.ctx.editor.gameRoot?.();
  if(typeof invoke!=='function'||!root)throw Error('La edición actual de Maker Studio no expone el lector PNG. Usa la exportación PNG.');
  const sep=root.includes('\\')?'\\':'/';
  const abs=root.replace(/[\\/]+$/,'')+sep+rel.replaceAll('/',sep);
  const bytes=await invoke('read_binary_file',{path:abs});
  const url=URL.createObjectURL(new Blob([Uint8Array.from(bytes)],{type:'image/png'}));
  try{
   const img=new Image();
   await new Promise((resolve,reject)=>{img.onload=resolve;img.onerror=reject;img.src=url;});
   if(owner!==state)return false;
   if(img.width>512||img.height>512)throw Error('Máscara '+name+' supera 512×512.');
   owner.maskReady.add(name);
   if(force)owner.maskDrafts.delete(name);
   setMaskImage(name,img);
   redraw();
   if(owner.host && active()?.maskFile===name)refresh();
   return true;
  }finally{URL.revokeObjectURL(url);}
 }catch(error){
  owner.ctx.log.warn?.('[Lighting Studio] PNG mask '+name,error);
  if(force)notify('No se pudo actualizar '+name+': '+String(error.message||error),'warn');
  return false;
 }finally{
  owner.maskLoading.delete(name);
  owner.maskPromises.delete(name);
 }
 })();
 owner.maskPromises.set(name,task);
 return task;
}
async function preloadMasks(){
 const owner=state;if(!owner)return;
 // Load only the current map, rather than scanning every map on each slider
 // change. Other assets are loaded when switching to their map.
 const names=[...new Set((current()?.lights||[]).filter(l=>(l.type==='mask'||l.maskEnabled===true)&&
   maskFilename(l.maskFile)).map(l=>l.maskFile))];
 await Promise.all(names.map(name=>loadMaskFile(name)));
}
async function pickMaskGraphic(lightId){
 const owner=state;if(!owner)return;
 const picker=owner.ctx.selectors?.pickGraphic;
 if(typeof picker!=='function')return notify('El selector de gráficos no está disponible. Puedes escribir el nombre del PNG.','warn');
 const chosen=await picker('LightingStudio/Masks',{title:'Selecciona la silueta de luz PNG',fields:[]});
 if(!chosen||owner!==state)return;
 const raw=String(chosen.name||'').split(/[\\/]/).pop().replace(/\.png$/i,'');
 const name=maskFilename(raw+'.png');
 if(!name)return notify('Selecciona un PNG válido dentro de Graphics/LightingStudio/Masks.','warn');
 const light=owner.data.maps?.[String(owner.mapId)]?.lights?.find(l=>l.id===lightId);
 if(!light)return;
 change(()=>{light.maskFile=name;light.maskEnabled=true;});
 const found=await loadMaskFile(name,{force:true});
 notify(found?'Máscara '+name+' cargada en el mapa.':'PNG no disponible; puedes crear la forma con el editor.',found?'info':'warn');
}

// Medium-green tile color used only for showing the RGBG look in swatches.
function tonePreviewHex(tone){
 const source=[124,151,119],gray=Math.max(0,Math.min(1,(tone?.gray||0)/255));
 const lum=source[0]*.299+source[1]*.587+source[2]*.114;
 return '#'+['red','green','blue'].map((k,i)=>{
  const value=Math.round(source[i]*(1-gray)+lum*gray+(tone?.[k]||0));
  return Math.max(0,Math.min(255,value)).toString(16).padStart(2,'0');
 }).join('');
}
function refresh(){if(!state?.host)return;const root=state.host;const oldScroll=root.querySelector('.ls-root')?.scrollTop||0;root.replaceChildren();const style=node('style',css);root.append(style);const shell=element('div','ls-root');root.append(shell);
const head=element('div','ls-head');shell.append(head);const brand=element('div','ls-brand');head.append(brand);brand.append(element('div','ls-logo','☀'));const info=node('div');brand.append(info);info.append(element('div','ls-title','Lighting Studio'),element('div','ls-sub','Iluminación del mapa · edición directa'));
const toolbar=element('div','ls-toolbar');shell.append(toolbar);
for(const [id,label] of [['select','↖ Seleccionar'],['place','✦ Añadir luz'],['erase','⌫ Borrar']])toolbar.append(mini(label,()=>setMode(id),state.mode===id));
const layerStatus=element('div','ls-layer-status');shell.append(layerStatus);const status=element('span','ls-layer-live','Comprobando overlay del mapa…');layerStatus.append(status);state.statusNode=status;const diagnostic=mini('Prueba visual',()=>{state.diagnostic=!state.diagnostic;redraw();refresh();});layerStatus.append(diagnostic);diagnostic.classList.toggle('active',!!state.diagnostic);updateDiagnosticStatus();
const actions=element('div','ls-actions');shell.append(actions);actions.append(mini('↶ Deshacer',undo),mini('↷ Rehacer',redo),mini('Duplicar',()=>{const l=active();if(!l)return;change(()=>{const copy=deepCopy(l);copy.id='light_'+Date.now().toString(36)+Math.random().toString(36).slice(2,5);copy.x+=.5;copy.y+=.5;copy.name+=' copia';current().lights.push(copy);state.selected=copy.id;});}));
const mapId=state.ctx.editor.activeMapId?.();if(Number(mapId)>0)state.mapId=Number(mapId);
const title=element('div','ls-hint','Mapa #'+state.mapId+' · '+(state.mode==='select'?'Clic en luz: seleccionar · arrastra para mover · Shift+arrastra: radio':state.mode==='place'?'Clic y arrastra para crear una luz del tamaño deseado':'Clic en una luz para eliminarla')+' · Ctrl + rueda: zoom del editor');shell.append(title);
if(state.readError){shell.append(element('div','ls-hint','ERROR al leer los datos: '+state.readError+' · Edición bloqueada.'));return;}
const m=current();const scene=getMap(state.data,state.mapId,true);
if(!state.showOverlay){
 const warning=element('div','ls-hint','La previsualización está desactivada. Actívala para ver las luces sobre el mapa.');
 shell.append(warning);
 const restore=mini('Mostrar luces en el mapa',()=>{state.showOverlay=true;invalidate();redraw();refresh();});
 shell.append(restore);
}
if(scene.enabled===false){
 const warning=element('div','ls-hint','La iluminación está DESACTIVADA para este mapa.');
 shell.append(warning);shell.append(mini('Activar iluminación del mapa',()=>change(()=>scene.enabled=true)));
}
if(scene.lights.length && scene.lights.every(l=>l.enabled===false)){
 shell.append(element('div','ls-hint','Todas las fuentes están apagadas. Usa «Encender todas» para verlas.'));
}
const section=element('section','ls-section ls-light-library');shell.append(section);const heading=element('div','ls-section-heading');section.append(heading);heading.append(node('span','Fuentes luminosas'),element('span','ls-count',String(m?.lights.length||0)));const library=element('div','ls-inline');section.append(library);library.append(mini('＋ Nueva',()=>{const cx=state.lastCursor?.x??8,cy=state.lastCursor?.y??6;change(()=>{const d=getMap(state.data,state.mapId,true),l=makeLight(cx,cy,state.newType);d.lights.push(l);state.selected=l.id;state.inspectorTab=l.type==='mask'?'mask':'shape';});}),mini('▤ Presets',()=>{const light=active();if(!light)return notify('Selecciona primero una luz','warn');change(()=>{Object.assign(active(),{color:'#FFAD51',intensity:.85,radiusPx:112,softness:.8,name:'Farola cálida'});});}));
const typePicker=node('select');typePicker.className='ls-input';for(const t of LIGHT_TYPES){const o=node('option',TYPE_NAMES[t]);o.value=t;typePicker.append(o);}typePicker.value=state.newType;typePicker.onchange=()=>{state.newType=typePicker.value;redraw();};labeled(section,'Tipo para luces nuevas',typePicker);
const list=element('div','ls-list');section.append(list);
if(!m?.lights.length)list.append(element('div','ls-empty','Todavía no hay luces. Usa «Añadir luz» sobre el mapa.'));
for(const l of m?.lights||[]){const row=element('div','ls-item'+(l.id===state.selected?' selected':''));list.append(row);const sw=element('span','ls-swatch');sw.style.background=l.color;sw.style.color=l.color;row.append(sw);const main=element('button','ls-item-main');main.type='button';main.append(element('div','ls-item-name',l.name),element('div','ls-item-meta',Math.round(l.radiusPx)+' px · '+Math.round(l.intensity*100)+'%'));main.onclick=()=>{state.selected=l.id;state.inspectorTab=l.type==='mask'?'mask':'shape';state.mode='select';state.ctx.editor.setTool(TOOL);redraw();refresh();};row.append(main);const eye=element('button','ls-ghost',l.enabled?'◉':'◌');eye.title=l.enabled?'Ocultar':'Mostrar';eye.onclick=()=>change(()=>{l.enabled=!l.enabled;});row.append(eye);}
const ambient=element('section','ls-section');shell.append(ambient);ambient.append(element('div','ls-section-heading','Ambiente y control general'));
const previewOptions=element('div','ls-inline');ambient.append(previewOptions);
const quality=node('select');quality.className='ls-input';
 for(const [value,label] of [['fast','Rápida · menos repintados'],['balanced','Equilibrada'],['full','Completa']]){
  const opt=node('option',label);opt.value=value;quality.append(opt);
 }
 quality.value=state.previewQuality;
 quality.onchange=()=>{state.previewQuality=quality.value;redraw();};
 labeled(ambient,'Calidad de previsualización',quality);
 const night=mini(state.previewNight?'◐ Vista nocturna activa':'◐ Vista nocturna (solo editor)',()=>{
 state.previewNight=!state.previewNight;invalidate();redraw();refresh();
},state.previewNight);
previewOptions.append(night);
 const animate=node('input');animate.type='checkbox';animate.checked=state.previewAnimateLights;
 animate.onchange=()=>{state.previewAnimateLights=animate.checked;invalidate();redraw();refresh();};
 labeled(previewOptions,'Animar luces en la preview (apagado por defecto)',animate);
ambient.append(element('p','ls-inline-note','La vista nocturna oscurece el mapa solo en Maker Studio para distinguir las luces sobre tiles claros. No modifica los datos del juego.'));const enabled=node('input');enabled.type='checkbox';enabled.checked=scene.enabled!==false;enabled.onchange=()=>change(()=>scene.enabled=enabled.checked);labeled(ambient,'Iluminación activada para este mapa',enabled);
const zero=element('div','ls-inline');ambient.append(zero);zero.append(mini('Quitar oscuridad',()=>change(()=>scene.ambient.darkness=0)),mini('Apagar todas las luces',()=>change(()=>{scene.lights.forEach(l=>l.enabled=false);})),mini('Encender todas',()=>change(()=>{scene.lights.forEach(l=>l.enabled=true);})));const settings=scene.ambient;
const overlap=node('select');overlap.className='ls-input';
for(const [value,label] of [['union','Fusionar áreas · farolas (recomendado)'],['sum','Acumular brillo · suma']]){
 const option=node('option',label);option.value=value;overlap.append(option);
}
overlap.value=scene.overlapMode||'union';overlap.onchange=()=>change(()=>scene.overlapMode=overlap.value);
labeled(ambient,'Superposición de luces',overlap);
ambient.append(element('p','ls-inline-note','Fusionar amplía la zona iluminada sin duplicar la potencia en los cruces. Sumar aumenta el brillo donde coinciden.'));
slider(ambient,'Oscuridad',settings.darkness,0,1,.01,(v,final)=>editValue(()=>settings.darkness=clamp(v,0,1),final));
const color=node('input');color.type='color';color.className='ls-color';color.value=settings.color;color.addEventListener('input',()=>editValue(()=>settings.color=color.value,false));color.addEventListener('change',()=>editValue(()=>settings.color=color.value,true));labeled(ambient,'Color ambiental',color);
const daytime=element('section','ls-section');shell.append(daytime);
 daytime.append(element('div','ls-section-heading','Ciclo de día y noche · global'));
 const tod=state.data.timeOfDay;
 const clockEnabled=node('input');clockEnabled.type='checkbox';clockEnabled.checked=tod.enabled;
 clockEnabled.onchange=()=>change(()=>tod.enabled=clockEnabled.checked);
 labeled(daytime,'Habilitar hora y tinte ambiental',clockEnabled);
 const clockSelect=node('select');clockSelect.className='ls-input';
 for(const [value,label] of [['real','Hora real del sistema'],['internal','Reloj interno de la partida']]){
  const opt=node('option',label);opt.value=value;clockSelect.append(opt);
 }
 clockSelect.value=tod.source;clockSelect.onchange=()=>change(()=>tod.source=clockSelect.value);
 labeled(daytime,'Fuente horaria',clockSelect);
 const blendSelect=node('select');blendSelect.className='ls-input';
 for(const [value,label] of [['tone','Tono nativo Pokémon (RGB + gris)'],['overlay','Capa RGB antigua (compatibilidad)']]){
  const o=node('option',label);o.value=value;blendSelect.append(o);
 }
 blendSelect.value=tod.blendMode||'tone';
 blendSelect.onchange=()=>change(()=>tod.blendMode=blendSelect.value);
 labeled(daytime,'Cómo se mezcla el color',blendSelect);
 if(tod.source==='internal'){
  slider(daytime,'Hora inicial',tod.startHour,0,23.75,.25,(v,final)=>editValue(()=>tod.startHour=v,final));
  slider(daytime,'Minutos del juego por segundo real',tod.minutesPerSecond,.001,1,.01,(v,final)=>editValue(()=>tod.minutesPerSecond=clamp(v,.001,1),final));
 }
 const mapTimeSelect=node('select');mapTimeSelect.className='ls-input';
 for(const [value,label] of [['follow','Seguir ciclo global'],['ignore','Ignorar ciclo (cuevas / interiores)']]){
  const opt=node('option',label);opt.value=value;mapTimeSelect.append(opt);
 }
 mapTimeSelect.value=scene.dayNightMode||'follow';
 mapTimeSelect.onchange=()=>change(()=>scene.dayNightMode=mapTimeSelect.value);
 labeled(daytime,'Ciclo en este mapa',mapTimeSelect);
 const previewTime=node('input');previewTime.type='checkbox';previewTime.checked=state.previewDayNight;
 previewTime.onchange=()=>{state.previewDayNight=previewTime.checked;redraw();refresh();};
 labeled(daytime,'Previsualizar ciclo en Maker Studio',previewTime);
 if(state.previewDayNight)slider(daytime,'Hora de previsualización',state.previewHour,0,23.75,.25,(v,final)=>{state.previewHour=v;redraw();});
 daytime.append(element('p','ls-inline-note','El modo nativo ajusta los canales RGB y gris como Pokémon Essentials, sin una capa de color plano. El reloj se guarda con la partida.'));
 const timelineTitle=element('div','ls-section-heading','Paleta de iluminación por horas');daytime.append(timelineTitle);
 const clockStatus=element('div','ls-time-preview-status');daytime.append(clockStatus);
 function updateTimePreview(){
  const sample=evaluateTimeOfDay(tod,state.previewHour);
  clockStatus.textContent='Vista previa · '+Math.floor(state.previewHour).toString().padStart(2,'0')+':'+Math.round((state.previewHour%1)*60).toString().padStart(2,'0')+(tod.blendMode==='tone'?' · RGBG '+['red','green','blue','gray'].map(k=>Math.round(sample.tone[k])).join(' / '):' · oscuridad '+Math.round(sample.darkness*100)+' %');
  clockStatus.style.borderLeftColor=tod.blendMode==='tone'?tonePreviewHex(sample.tone):sample.color;
 }
 const track=element('div','ls-time-track');daytime.append(track);
 for(let index=0;index<24;index++){
  const sample=evaluateTimeOfDay(tod,index+0.5);
  const slot=element('button','ls-time-slot');slot.type='button';
  slot.title=String(index).padStart(2,'0')+':00 · clic para previsualizar';
  slot.style.backgroundColor=tod.blendMode==='tone'?tonePreviewHex(sample.tone):sample.color;
  slot.style.opacity=tod.blendMode==='tone'?'1':String(Math.max(.25,1-sample.darkness*.6));
  slot.onclick=()=>{state.previewDayNight=true;state.previewHour=index+0.5;state.workspaceTab='time';refresh();redraw();};
  if(Math.floor(state.previewHour)===index)slot.classList.add('active');
  track.append(slot);
 }
 const table=element('div','ls-time-table');if(tod.blendMode==='tone')table.classList.add('ls-tone-table');daytime.append(table);
 const header=element('div','ls-time-table-head');
 for(const name of (tod.blendMode==='tone'?['HORA','ROJO','VERDE','AZUL','GRIS','']:['HORA','COLOR','OSCURIDAD','']))header.append(element('span',null,name));
 table.append(header);
 for(const key of tod.keyframes){
  const row=element('div','ls-time-row');table.append(row);
  const clock=node('input');clock.type='time';clock.step=900;clock.className='ls-input ls-clock-input';
  const hour=Math.floor(key.hour),minute=Math.round((key.hour-hour)*60);
  clock.value=String(hour).padStart(2,'0')+':'+String(minute).padStart(2,'0');
  clock.title='Hora de este color';
  clock.onchange=()=>{const bits=clock.value.split(':').map(Number);
    if(bits.length!==2||bits.some(n=>!Number.isFinite(n)))return;
    change(()=>{key.hour=clamp(bits[0]+bits[1]/60,0,23.99);tod.keyframes.sort((x,y)=>x.hour-y.hour);});
  };
  row.append(clock);
  if(tod.blendMode==='tone'){
    if(!key.tone)key.tone={red:0,green:0,blue:0,gray:0};
    for(const channel of ['red','green','blue','gray']){
      const input=node('input');input.type='number';input.className='ls-input ls-tone-input';
      input.min=channel==='gray'?'0':'-255';input.max='255';input.step='1';
      input.value=String(Math.round(key.tone[channel]||0));
      input.title=channel==='gray'?'Gris: 0 conserva colores, 255 escala de grises':'Canal '+channel+' (−255 a +255)';
      input.onchange=()=>change(()=>{key.tone[channel]=clamp(Number(input.value),channel==='gray'?0:-255,255);});
      row.append(input);
    }
  }else{
  const colorCell=element('div','ls-time-color-cell');
  const colorInput=node('input');colorInput.type='color';colorInput.className='ls-color';
  colorInput.value=key.color;colorInput.title='Color del ambiente';
  const hexLabel=element('span','ls-hex-value',key.color);
  colorInput.oninput=()=>{hexLabel.textContent=colorInput.value;editValue(()=>key.color=colorInput.value,false);};
  colorInput.onchange=()=>{editValue(()=>key.color=colorInput.value,true);refresh();};
  colorCell.append(colorInput,hexLabel);row.append(colorCell);
  const opacityCell=element('div','ls-time-darkness-cell');
  const darknessInput=node('input');darknessInput.type='range';darknessInput.min=0;darknessInput.max=100;darknessInput.step=1;
  darknessInput.value=String(Math.round(key.darkness*100));darknessInput.className='ls-range';
  const darknessText=element('span','ls-time-percent',darknessInput.value+'%');
  darknessInput.oninput=()=>{const v=Number(darknessInput.value);darknessText.textContent=v+'%';editValue(()=>key.darkness=v/100,false);};
  darknessInput.onchange=()=>{editValue(()=>key.darkness=Number(darknessInput.value)/100,true);refresh();};
  opacityCell.append(darknessInput,darknessText);row.append(opacityCell);
  }
  const remove=mini('×',()=>{if(tod.keyframes.length<=2)return notify('Se necesitan al menos dos horarios.','warn');
    change(()=>{tod.keyframes=tod.keyframes.filter(k=>k!==key);});
  });remove.title='Quitar esta hora';remove.classList.add('ls-time-remove');row.append(remove);
 }
 const addTime=mini('＋ Añadir hora',()=>change(()=>{if(tod.keyframes.length>=48)return notify('Máximo 48 horarios.','warn');
  const hr=Number(state.previewHour)||12;let t=hr;
  while(tod.keyframes.some(k=>Math.abs(k.hour-t)<.01))t=(t+.25)%24;
  const v=evaluateTimeOfDay(tod,t);
  tod.keyframes.push({hour:t,color:v.color,darkness:Math.round(v.darkness*100)/100,tone:Object.fromEntries(Object.entries(v.tone).map(([k,val])=>[k,Math.round(val)]))});
  tod.keyframes.sort((x,y)=>x.hour-y.hour);
 }));
 addTime.classList.add('ls-add-keyframe');daytime.append(addTime);
 updateTimePreview();
 const timeChildren=[...daytime.children];
 const paletteIndex=timeChildren.indexOf(timelineTitle);
 const timeGroup=element('div','ls-time-editor-grid');
 const settingsGroup=element('div','ls-time-settings');
 const paletteGroup=element('div','ls-time-palette');
 for(const child of timeChildren.slice(1,paletteIndex))settingsGroup.append(child);
 for(const child of timeChildren.slice(paletteIndex))paletteGroup.append(child);
 timeGroup.append(settingsGroup,paletteGroup);
 daytime.append(timeGroup);
const insp=element('section','ls-section ls-inspector');shell.append(insp);
const insHead=element('div','ls-section-heading');insHead.append(node('span','INSPECTOR DE LUZ'),element('span','ls-count',active()?.name||'Sin selección'));insp.append(insHead);
const nav=element('div','ls-inspector-tabs');insp.append(nav);
const maskSelected=!!active()&&(active().type==='mask'||active().maskEnabled===true);
// Keep mask editing accessible even when disabled.
if(state.inspectorTab==='mask')insp.classList.add('ls-mask-editor-active');
const inspectorTabs=[['shape','◈ Forma'],['mask','✎ Máscara / obstáculos'],['fade','◑ Difuminado'],['pulse','◷ Pulsación'],['pixel','▦ Pixel art'],['schedule','◷ Horario']];
for(const [key,label] of inspectorTabs){
 nav.append(mini(label,()=>{state.inspectorTab=key;refresh();},state.inspectorTab===key));
}
const selected=active();
if(!selected)insp.append(element('div','ls-empty','Selecciona una luz en el mapa o en la biblioteca.'));
else{
const tabs={};
for(const [id] of inspectorTabs){const panel=element('div','ls-tab-body');panel.hidden=state.inspectorTab!==id;insp.append(panel);tabs[id]=panel;}
const shapePanel=tabs.shape,fadePanel=tabs.fade,pulsePanel=tabs.pulse,pixelPanel=tabs.pixel,schedulePanel=tabs.schedule,maskPanel=tabs.mask;
shapePanel.append(element('div','ls-group-label','PROPIEDADES GENERALES'));
fadePanel.append(element('p','ls-inline-note','Elige hacia qué borde se atenúa la luz. «Hacia abajo» conserva una zona luminosa arriba y la oscurece progresivamente hacia abajo.'));
const typeSelect=node('select');typeSelect.className='ls-input';for(const t of LIGHT_TYPES){const o=node('option',TYPE_NAMES[t]);o.value=t;typeSelect.append(o);}typeSelect.value=selected.type;typeSelect.onchange=()=>change(()=>{selected.type=typeSelect.value;state.inspectorTab=selected.type==='mask'?'mask':'shape';});labeled(shapePanel,'Geometría',typeSelect);
if(selected.type==='cone'){slider(shapePanel,'Apertura (grados)',selected.angle,5,170,1,(v,final)=>editLightValue(()=>selected.angle=v,final));}
if(selected.type==='ellipse'||selected.type==='rectangle'||selected.type==='mask'){
 // The raster is authored in local axes then rotated for display. At 90°
 // local width becomes SCREEN height. Map the controls to visible axes.
 const radians=(Number(selected.rotation)||0)*Math.PI/180;
 const quarterTurn=Math.abs(Math.sin(radians))>Math.abs(Math.cos(radians));
 const screenWidthKey=quarterTurn?'heightPx':'widthPx';
 const screenHeightKey=quarterTurn?'widthPx':'heightPx';
 slider(shapePanel,'Anchura horizontal visible (px)',selected[screenWidthKey],8,1024,1,
   (v,final)=>editLightValue(()=>selected[screenWidthKey]=v,final));
 slider(shapePanel,'Altura vertical visible (px)',selected[screenHeightKey],8,1024,1,
   (v,final)=>editLightValue(()=>selected[screenHeightKey]=v,final));
 if(Math.abs(Math.sin(radians))>.15&&Math.abs(Math.cos(radians))>.15)
   shapePanel.append(element('p','ls-inline-note','Con una luz girada en diagonal, ambas dimensiones visuales se relacionan. Puedes poner Rotación en 0° para ajustarlas sin inclinación.'));
}
const maskToggle=node('input');maskToggle.type='checkbox';maskToggle.checked=selected.maskEnabled===true || selected.type==='mask';maskToggle.disabled=selected.type==='mask';
maskToggle.onchange=()=>change(()=>{selected.maskEnabled=maskToggle.checked;state.inspectorTab=maskToggle.checked?'mask':'shape';});
labeled(shapePanel,'Recortar esta luz con una máscara',maskToggle);
shapePanel.append(element('p','ls-inline-note','La luz conserva su forma y tamaño. La máscara solo define dónde atraviesa o dónde queda bloqueada. Puedes usarla sobre cualquier tipo de luz.'));
{
 const maskMode=node('select');maskMode.className='ls-input';
 for(const [id,label] of [['block','Bloquear luz donde pinto (paredes)'],['reveal','Permitir luz donde pinto (ventanas)']]){const opt=node('option',label);opt.value=id;maskMode.append(opt);}
 maskMode.value=selected.maskMode||'reveal';
 maskMode.onchange=()=>change(()=>selected.maskMode=maskMode.value);
 labeled(shapePanel,'Qué significa lo pintado',maskMode);

  const maskTitle=element('div','ls-mask-inspector-title','DIBUJAR FORMA DE LA LUZ');
  maskPanel.append(maskTitle);
  maskPanel.append(element('p','ls-inline-note',selected.maskMode==='block'?'OBSTÁCULO: el trazo opaco impide que pase la luz. La zona transparente queda iluminada.':'ABERTURA: solo el trazo opaco permite el paso de luz. La zona transparente queda oscura.'));
  const maskQuick=element('div','ls-inline');maskPanel.append(maskQuick);
  const enabledToggle=mini(selected.maskEnabled?'● Máscara activa · apagar':'○ Máscara apagada · activar',()=>{
    change(()=>{selected.maskEnabled=!selected.maskEnabled;});state.inspectorTab='mask';
  });
  maskQuick.append(enabledToggle);
  maskQuick.append(mini('Usar como abertura',()=>{change(()=>{selected.maskMode='reveal';selected.maskEnabled=true;});state.inspectorTab='mask';}));
  maskQuick.append(mini('Usar como obstáculo',()=>{change(()=>{selected.maskMode='block';selected.maskEnabled=true;});state.inspectorTab='mask';}));
  maskPanel.append(element('p','ls-inline-note','Máscara = silueta por ALFA: píxeles opacos forman la región; transparencia = ausencia. El color negro cuenta como trazo, no como vacío.'));
  const maskInput=node('input');maskInput.type='text';maskInput.className='ls-input';
  maskInput.placeholder='cueva_salida.png';maskInput.value=selected.maskFile||'';
  const lightId=selected.id;
  maskInput.onchange=()=>{
    const name=maskFilename(maskInput.value.trim());
    if(!name){maskInput.value=selected.maskFile||'';return notify('Usa un nombre como cueva_salida.png','warn');}
    if(name===selected.maskFile)return;
    change(()=>{selected.maskFile=name;selected.maskEnabled=true;state.inspectorTab='mask';});
    void loadMaskFile(name,{force:true}).then(ok=>{
      notify(ok?'Máscara actualizada en el mapa':'Sin PNG todavía: usa «Crear salida de cueva».',ok?'info':'warn');
    }).catch(fail);
  };
  labeled(shapePanel,'Archivo PNG',maskInput);
  const maskTools=element('div','ls-mask-load-actions');
  maskPanel.append(maskTools);
  maskTools.append(mini('▣ Elegir gráfico',()=>{void pickMaskGraphic(lightId).catch(fail);}));
  maskTools.append(mini('↻ Recargar PNG',()=>{const name=selected.maskFile;
    if(!maskFilename(name))return notify('Elige primero un archivo PNG.','warn');
    void loadMaskFile(name,{force:true}).then(ok=>{
      notify(ok?'PNG recargado y actualizado en el mapa.':'No se pudo leer el PNG.','warn');
    }).catch(fail);
  }));
  maskTools.append(mini('＋ Nueva máscara y dibujar',()=>{
    const name=maskFilename(maskInput.value.trim())||maskFilename('mascara_'+String(lightId).replace(/[^a-z0-9_-]/gi,'_')+'.png')||'mascara_nueva.png';
    // Keep a separate canvas per graphic so edits are not lost when switching
    // between inspector tabs and lighting sources.
    const draft=(()=>{const c=document.createElement('canvas');c.width=256;c.height=128;return c;})();
    state.maskDrafts.set(name,draft);
    setMaskImage(name,draft);
    change(()=>{selected.maskFile=name;selected.maskEnabled=true;state.inspectorTab='mask';});
  }));
  maskTools.append(mini('◈ Plantilla de entrada de cueva',()=>{
    const name=maskFilename(maskInput.value.trim())||maskFilename('mascara_'+String(lightId).replace(/[^a-z0-9_-]/gi,'_')+'.png')||'mascara_nueva.png';
    const draft=caveTemplate(256,128,'right');state.maskDrafts.set(name,draft);setMaskImage(name,draft);
    change(()=>{selected.maskFile=name;selected.maskEnabled=true;selected.maskMode='reveal';state.inspectorTab='mask';});
  }));
  const name=selected.maskFile;
  const source=maskFilename(name)?(state.maskDrafts.get(name)||getMaskImage(name)):null;
  if(source && state.inspectorTab==='mask'){
    // Avoid cloning and re-rendering the PNG painter while browsing other
    // inspector sections. Only the active tab gets a costly canvas.
    mountMaskPainter(maskPanel,{
      filename:name,
      maskMode:selected.maskMode||'reveal',
      getSource:()=>state.maskDrafts.get(name)||getMaskImage(name),
      onCreate:canvas=>{state.maskDrafts.set(name,canvas);setMaskImage(name,canvas);redraw();},
      onPreview:canvas=>{state.maskDrafts.set(name,canvas);setMaskImage(name,canvas);redraw();},
      onSave:async(filename,canvas)=>{
        const owner=state;
        const result=await saveMaskPng(owner.ctx,filename,canvas,MASK_DIR);
        if(owner!==state)return result;
        if(result.saved){
          owner.maskReady.delete(filename);
          await loadMaskFile(filename,{force:true});
        }else{
          // In older Maker Studio versions the binary API is absent. The
          // export still previews instantly and remains editable in session.
          owner.maskDrafts.set(filename,canvas);
        }
        return result;
      },
      notify
    });
  }else if(!source){
    maskPanel.append(element('p','ls-mask-empty','Puedes seleccionar un PNG ya existente o usar «Crear salida de cueva» para empezar directamente con una forma lista para pintar.'));
  }
 }
 if(selected.type!=='radial')slider(shapePanel,'Rotación',selected.rotation,-360,360,1,(v,final)=>editLightValue(()=>selected.rotation=v,final));
const name=node('input');name.type='text';name.className='ls-input';name.value=selected.name;name.onchange=()=>change(()=>selected.name=name.value.slice(0,80));labeled(shapePanel,'Nombre',name);
const c=node('input');c.type='color';c.className='ls-color';c.value=selected.color;c.oninput=()=>editLightValue(()=>selected.color=c.value,false);c.onchange=()=>editLightValue(()=>selected.color=c.value,true);labeled(shapePanel,'Color',c);
slider(shapePanel,'Intensidad',selected.intensity,0,1,.01,(v,final)=>editLightValue(()=>selected.intensity=clamp(v,0,1),final));
slider(fadePanel,'Brillo del centro',selected.centerStrength??.65,0,1,.01,(v,final)=>editLightValue(()=>selected.centerStrength=clamp(v,0,1),final));
slider(shapePanel,'Radio · píxeles',selected.radiusPx,8,512,1,(v,final)=>editLightValue(()=>selected.radiusPx=clamp(v,8,512),final));
slider(fadePanel,'Suavidad',selected.softness,.05,1,.01,(v,final)=>editLightValue(()=>selected.softness=clamp(v,.05,1),final));
if(selected.type==='cone'){
 slider(fadePanel,'Suavidad lateral del cono',selected.coneFeather??.28,.03,.9,.01,(v,final)=>editLightValue(()=>selected.coneFeather=clamp(v,.03,.9),final));
 fadePanel.append(element('p','ls-inline-note','Bordes: un valor menor conserva el haz más definido; uno mayor difumina los laterales sin alterar su alcance.'));
}
const blend=node('select');blend.className='ls-input';for(const [value,label] of [['union','Unir con otras luces'],['sum','Sumar brillo (independiente)'],['normal','Normal'],['subtract','Oscurecer']]){const opt=node('option',label);opt.value=value;blend.append(opt);}blend.value=selected.blendMode==='add'?'union':(selected.blendMode||'union');blend.onchange=()=>change(()=>selected.blendMode=blend.value);labeled(shapePanel,'Modo de mezcla',blend);
const fadeSelect=node('select');fadeSelect.className='ls-input';
for(const id of FADE_MODES){const o=node('option',FADE_NAMES[id]);o.value=id;fadeSelect.append(o);}
fadeSelect.value=selected.fadeMode||'center';
fadeSelect.onchange=()=>change(()=>selected.fadeMode=fadeSelect.value);
labeled(fadePanel,'Dirección de atenuación',fadeSelect);
if(selected.fadeMode!=='center'){
 slider(fadePanel,'Inicio del difuminado',selected.fadeStart??.58,0,.95,.01,(v,final)=>editLightValue(()=>selected.fadeStart=v,final));
 fadePanel.append(element('p','ls-inline-note','Cuanto mayor sea el valor, más amplia será la zona iluminada antes de comenzar la transición.'));
}
if(selected.fadeMode==='custom'){
 slider(fadePanel,'Origen horizontal',selected.fadeX??0,-1,1,.05,(v,final)=>editLightValue(()=>selected.fadeX=v,final));
 slider(fadePanel,'Origen vertical',selected.fadeY??0,-1,1,.05,(v,final)=>editLightValue(()=>selected.fadeY=v,final));
}
const pulse=element('div','ls-effect-group');pulsePanel.append(pulse);pulse.append(element('b',null,'Pulsación'));const on=node('input');on.type='checkbox';on.checked=selected.pulse.enabled;on.onchange=()=>change(()=>selected.pulse.enabled=on.checked);labeled(pulse,'Activar pulsación',on);slider(pulse,'Velocidad (Hz)',selected.pulse.speedHz,.05,12,.05,(v,final)=>editLightValue(()=>selected.pulse.speedHz=v,final));slider(pulse,'Oscilación intensidad',selected.pulse.intensity,0,1,.01,(v,final)=>editLightValue(()=>selected.pulse.intensity=v,final));slider(pulse,'Oscilación tamaño',selected.pulse.radius,0,.9,.01,(v,final)=>editLightValue(()=>selected.pulse.radius=v,final));
const pixel=element('div','ls-effect-group');pixelPanel.append(pixel);pixel.append(element('b',null,'Pixel Art'));const pixelOn=node('input');pixelOn.type='checkbox';pixelOn.checked=selected.pixel.enabled;pixelOn.onchange=()=>change(()=>selected.pixel.enabled=pixelOn.checked);labeled(pixel,'Pixelar luz',pixelOn);slider(pixel,'Tamaño de píxel',selected.pixel.size,2,32,1,(v,final)=>editLightValue(()=>selected.pixel.size=Math.round(v),final));slider(pixel,'Niveles de degradado',selected.pixel.steps,2,24,1,(v,final)=>editLightValue(()=>selected.pixel.steps=Math.round(v),final));
// SCHEDULE — time-based lamp activation (incl. cross-midnight ranges).
schedulePanel.append(element('div','ls-group-label','HORARIO DE ACTIVACIÓN'));
const cfg=selected.schedule||{enabled:false,startHour:19,endHour:7,fadeMinutes:0};
const preset=node('select');preset.className='ls-input';
const isDay=cfg.enabled&&Math.abs(cfg.startHour-7)<.001&&Math.abs(cfg.endHour-19)<.001;
const isNight=cfg.enabled&&Math.abs(cfg.startHour-19)<.001&&Math.abs(cfg.endHour-7)<.001;
const presetMode=cfg.mode||(!cfg.enabled?'always':isDay?'day':isNight?'night':'custom');
for(const [value,label] of [['always','Siempre encendida'],['day','Solo día (07:00–19:00)'],['night','Solo noche (19:00–07:00)'],['custom','Personalizado']]){
 const opt=node('option',label);opt.value=value;preset.append(opt);
}
preset.value=presetMode;
preset.onchange=()=>change(()=>{
 if(!selected.schedule)selected.schedule={enabled:false,startHour:19,endHour:7,fadeMinutes:0};
 const v=preset.value;selected.schedule.enabled=v!=='always';selected.schedule.mode=v;
 if(v==='day'){selected.schedule.startHour=7;selected.schedule.endHour=19;}
 if(v==='night'){selected.schedule.startHour=19;selected.schedule.endHour=7;}
});
labeled(schedulePanel,'Cuándo aparece',preset);
schedulePanel.append(element('p','ls-inline-note','Se activa a la hora exacta con una transición visual breve. Puedes ampliar esa transición por minutos del juego. Admite horarios que cruzan medianoche.'));
if(cfg.enabled){
 const row=element('div','ls-two');schedulePanel.append(row);
 for(const [label,prop] of [['Hora de encendido','startHour'],['Hora de apagado','endHour']]){
  const input=node('input');input.type='time';input.step=900;input.className='ls-input';
  const hh=Math.floor(cfg[prop]),mm=Math.round((cfg[prop]-hh)*60);
  input.value=String(hh).padStart(2,'0')+':'+String(mm).padStart(2,'0');
  input.onchange=()=>{
   const [hour,min]=input.value.split(':').map(Number);
   if(!Number.isFinite(hour)||!Number.isFinite(min))return;
   change(()=>selected.schedule[prop]=clamp(hour+min/60,0,23.999));
  };
  labeled(row,label,input);
 }
 slider(schedulePanel,'Transición (minutos del juego)',cfg.fadeMinutes??0,0,120,5,
   (v,final)=>editLightValue(()=>selected.schedule.fadeMinutes=v,final));
}
schedulePanel.append(mini('Ver en ciclo día y noche',()=>{state.workspaceTab='time';state.previewDayNight=true;refresh();redraw();}));
const coords=element('div','ls-two');shapePanel.append(coords);for(const axis of ['x','y']){const input=node('input');input.type='text';input.inputMode='decimal';input.className='ls-input';input.placeholder='Ej. 25.30';input.value=String(selected[axis]);input.onchange=()=>{const n=parseCoordinate(input.value);if(n===null){input.value=String(selected[axis]);notify('Introduce una coordenada entre -2048 y 2048, con decimales libres.','warn');return;}change(()=>selected[axis]=n);};labeled(coords,axis.toUpperCase()+' (tiles)',input);}
const buttons=element('div','ls-inline');shapePanel.append(buttons);buttons.append(mini('⌫ Eliminar',()=>change(()=>{const map=current();map.lights=map.lights.filter(l=>l.id!==selected.id);state.selected=null;})));
}
const wipe=element('div','ls-inline');ambient.append(wipe);wipe.append(mini('Restablecer iluminación del mapa',()=>{const n=(current()?.lights?.length||0);const message='Se eliminarán '+n+' luces y se restaurará el ambiente de este mapa. ¿Continuar?';const confirm=state.ctx.ui.showConfirmDialog({title:'Restablecer iluminación',message,confirmLabel:'Restablecer',cancelLabel:'Cancelar'});Promise.resolve(confirm).then(ok=>{if(ok)change(()=>{state.data.maps[String(state.mapId)]=defaultMap();state.selected=null;});}).catch(fail);}));
normalBindingsUI(shell,scene);
// Wide workspace: separate library + active light inspector instead of
// stacking every control into one endless 390px sidebar.
const normalsSection=shell.querySelector('.ls-normal-maps');
const workspaceNav=element('div','ls-workspace-nav');
const workspace=element('div','ls-workspace');
const lightView=element('div','ls-workspace-view ls-workspace-lights');
const lightLayout=element('div','ls-wide-light-layout');
lightLayout.append(section,insp);
const quickTools=element('div','ls-light-quickbar');
quickTools.append(toolbar,actions);
const viewQuality=element('label','ls-light-quality');viewQuality.append(node('span','Vista del mapa'));
const viewSelect=node('select');viewSelect.className='ls-input';
for(const [value,label] of [['fast','Rápida'],['balanced','Equilibrada'],['full','Exacta (más lenta)']]){
 const option=node('option',label);option.value=value;viewSelect.append(option);
}
viewSelect.value=state.previewQuality;
viewSelect.onchange=()=>{state.previewQuality=viewSelect.value;redraw();refresh();};
viewQuality.append(viewSelect);quickTools.append(viewQuality);
title.classList.add('ls-context-hint');
lightView.append(quickTools,title,lightLayout);
const ambientView=element('div','ls-workspace-view');ambientView.append(ambient);
const timeView=element('div','ls-workspace-view');timeView.append(daytime);
const normalsView=element('div','ls-workspace-view');if(normalsSection)normalsView.append(normalsSection);
const views={lights:lightView,ambient:ambientView,time:timeView,normals:normalsView};
for(const [id,label] of [['lights','✦ Luces e inspector'],['ambient','◐ Ambiente'],['time','◷ Día y noche'],['normals','◇ Normal maps']]){
 const b=mini(label,()=>{state.workspaceTab=id;state.resetWorkspaceScroll=true;refresh();},state.workspaceTab===id);
 b.classList.add('ls-workspace-tab');workspaceNav.append(b);
}
for(const [id,view] of Object.entries(views)){view.hidden=state.workspaceTab!==id;workspace.append(view);}
shell.insertBefore(workspaceNav,head.nextSibling);
shell.append(workspace);
const diagnostics=element('details','ls-debug-details');
const diagnosticsHeading=node('summary','Diagnóstico de iluminación y vista previa');
diagnostics.append(diagnosticsHeading,layerStatus);
shell.append(diagnostics);
if(state.resetWorkspaceScroll){shell.scrollTop=0;state.resetWorkspaceScroll=false;}
const hint=element('div','ls-preview-legend','La iluminación se dibuja sobre el mapa mediante un overlay independiente de Fog, Panorama y Sombras. Prueba visual muestra una marca amarilla para comprobar si Maker Studio lo está renderizando.');shell.append(hint);
const footer=element('div','ls-bottom ls-save-bar');shell.append(footer);const visible=node('input');visible.type='checkbox';visible.checked=state.showOverlay;visible.onchange=()=>{state.showOverlay=visible.checked;state.ctx.editor.requestRedraw?.();};const lbl=element('label','ls-checkbox');lbl.append(visible,node('span','Ver luces en mapa'));footer.append(lbl);const guides=node('input');guides.type='checkbox';guides.checked=state.showGuides;guides.onchange=()=>{state.showGuides=guides.checked;redraw();};const guidesLabel=element('label','ls-checkbox');guidesLabel.append(guides,node('span','Ver marcadores'));footer.append(guidesLabel);footer.append(element('span','ls-grow'));const saveButton=mini('💾 Guardar iluminación',()=>void persist().then(()=>notify('Iluminación guardada')).catch(fail));saveButton.classList.add('ls-save-primary');footer.append(saveButton);if(!state.resetWorkspaceScroll && state.workspaceTab===state.lastRenderedTab)shell.scrollTop=oldScroll;
state.lastRenderedTab=state.workspaceTab;
}
const clamp=(v,a,b)=>Math.min(b,Math.max(a,Number.isFinite(v)?v:a));
// While dragging, cap costly full-map redraws to ~10 per second rather than
// queueing one per input event. The current value is still committed on release.
function schedulePreview(){
 const owner=state;if(!owner||owner.previewScheduled)return;
 owner.previewScheduled=true;
 owner.previewTimer=setTimeout(()=>{
  if(state!==owner)return;
  owner.previewScheduled=false;owner.previewTimer=null;
  redraw();
 },65);
}
function editLightValue(fn,final){return editValue(fn,final,true);}
function editValue(fn,final,lightOnly=false){
 if(!state)return;
 if(!state.editSnapshot){state.editSnapshot=deepCopy(state.data);state.redo=[];}
 const before=lightOnly&&active()?{...active()}:null;
 fn();
 if(lightOnly&&before)invalidateLightRegions(before,active());
 else invalidate();
 if(!final){schedulePreview();return;}
 if(state.previewTimer!=null){clearTimeout(state.previewTimer);state.previewTimer=null;state.previewScheduled=false;}
 settleFastPreview();redraw();
 state.undo.push(state.editSnapshot);
 if(state.undo.length>60)state.undo.shift();
 state.editSnapshot=null;
 schedulePersist();
}

function overlay(draw,info){if(!state||!draw||!info)return;
if(!state.showOverlay&&!state.diagnostic&&state.ctx.editor.activeTool?.()!==TOOL)return;
const editing=state.ctx.editor.activeTool?.()===TOOL&&Number(info.mapId)===Number(state.mapId);
const stats=state.overlayStats;stats.calls++;stats.lastAt=Date.now();stats.lastMap=info.mapId;const renderStarted=performance.now();if(state.awaitingOverlay){stats.requestDelayMs=Math.max(0,renderStarted-state.lastRequestAt);state.awaitingOverlay=false;state.redrawDirty=false;}
try{
 const map=getMap(state.data,info.mapId,false);
 paint(draw,info,{map:map||{enabled:true,ambient:{darkness:0,color:'#142439'},lights:[]},
  ambientOverride:state.previewDayNight&&state.data.timeOfDay.enabled&&map?.dayNightMode!=='ignore'?
    evaluateTimeOfDay(state.data.timeOfDay,state.previewHour):null,toneMode:state.data.timeOfDay.blendMode||'tone',showPreview:!state.readError&&state.showOverlay,previewNight:state.previewNight,previewHour:state.previewDayNight&&state.data.timeOfDay.enabled&&map?.dayNightMode!=='ignore'?state.previewHour:null,previewQuality:state.previewQuality,previewAnimateLights:state.previewAnimateLights,fastPreview:!!state.drag||!!state.editSnapshot||performance.now()<(state.fastPreviewUntil||0),showGuides:state.showGuides&&editing,editing:editing,selectedId:state.selected,hover:state.hover,hoverHit:state.hoverHit,mode:state.mode,drag:state.drag,brushRadius:state.brushRadius,brush:{type:state.newType},revision:state.revision,time:performance.now()/1000});
 if(state.diagnostic){draw.save();try{
  draw.globalAlpha=1;draw.globalCompositeOperation='source-over';draw.fillStyle='#FFDE3B';draw.fillRect(10,10,190,34);draw.strokeStyle='#121826';draw.lineWidth=2;draw.strokeRect(10,10,190,34);draw.fillStyle='#111821';draw.font='bold 13px sans-serif';draw.fillText('LIGHTING · MAPA '+info.mapId,18,32);
 }finally{draw.restore();}}
 stats.lastMs=performance.now()-renderStarted;stats.errors=0;stats.lastError='';
}catch(error){stats.errors++;stats.lastError=String(error?.message||error);if(stats.errors===1){state.ctx.log.error('[Lighting Studio] Error en overlay',error);notify('Error en preview: '+stats.lastError,'error');}}
}
function selectMap(id){const n=Number(id);if(n>0&&state.mapId!==n){state.mapId=n;state.selected=null;state.hover=null;state.hoverHit=null;redraw();refresh();}}

function pointerDown(e){if(!state||state.readError||e.buttons&&!(e.buttons&1))return;selectMap(e.mapId);const pt=pointerPoint(e);state.hover=pt;state.lastCursor=pt;const found=hitTest(current()?.lights,pt,state.selected,!!e.shiftKey);state.hoverHit=found;
if(state.mode==='erase'){if(found)change(()=>{const m=current();m.lights=m.lights.filter(l=>l.id!==found.light.id);if(state.selected===found.light.id)state.selected=null;});redraw();return;}
if(state.mode==='select'){state.selected=found?.light.id||null;state.inspectorTab=found?.light.type==='mask'?'mask':'shape';if(found){state.drag={id:found.light.id,part:found.part,start:pt,origin:{x:found.light.x,y:found.light.y,radius:found.light.radiusPx},before:deepCopy(state.data)};}redraw();refresh();return;}
if(state.mode==='place'){const l=makeLight(pt.x,pt.y,state.newType);record();const m=getMap(state.data,state.mapId,true);m.lights.push(l);state.selected=l.id;state.inspectorTab=l.type==='mask'?'mask':'shape';state.drag={id:l.id,part:'radius',start:pt,origin:{x:pt.x,y:pt.y,radius:state.brushRadius},before:null};l.radiusPx=state.brushRadius;invalidate();redraw();refresh();}}
function pointerMove(e){if(!state||Number(e.mapId)!==Number(state.mapId))return;const pt=pointerPoint(e);const previous=state.hover;const d=state.drag;
if(!d&&previous?.x===pt.x&&previous?.y===pt.y)return;
state.lastCursor=pt;state.hover=pt;state.hoverHit=hitTest(current()?.lights,pt,state.selected,!!e.shiftKey);
if(!d&&state.mode==='select'){
 const prior=state.lastHoverId||null,now=state.hoverHit?.light?.id||null;
 state.lastHoverId=now;
 // No visual change when moving between empty tiles: leave the native
 // canvas alone, just like the cached autotile renderer.
 if(prior===now)return;
}
if(d){const l=current()?.lights.find(x=>x.id===d.id);if(l){const before={...l};if(d.part==='move'){l.x=d.origin.x+pt.x-d.start.x;l.y=d.origin.y+pt.y-d.start.y;}else{const distance=Math.hypot(pt.x-l.x,pt.y-l.y)*32;l.radiusPx=clamp(distance||state.brushRadius,8,512);}invalidateLightRegions(before,l);}}
if(d)schedulePreview();else redraw();}
function pointerUp(){if(!state?.drag)return;const d=state.drag;state.drag=null;settleFastPreview();if(d.before){state.undo.push(d.before);if(state.undo.length>60)state.undo.shift();state.redo=[];}redraw();refresh();schedulePersist();}
export async function activate(ctx){state={ctx,data:defaultProject(),maskLoading:new Set(),maskPromises:new Map(),maskReady:new Set(),maskDrafts:new Map(),workspaceTab:'lights',previewDayNight:false,previewHour:12,previewQuality:'balanced',previewAnimateLights:false,mapId:Number(ctx.editor.activeMapId?.())||1,diagnostic:false,overlayStats:{calls:0,lastAt:0,lastMap:null,errors:0,lastError:'',lastMs:0,requestDelayMs:0},statusNode:null,selected:null,mode:'select',inspectorTab:'shape',normalCategory:'characters',previewNight:false,fastPreviewUntil:0,settleTimer:null,autosaveTimer:null,revision:0,lastRedraw:0,lastRequestAt:0,awaitingOverlay:false,saving:false,saveRequested:false,showOverlay:true,showGuides:true,newType:'radial',brushRadius:96,hover:null,hoverHit:null,drag:null,clock:0,redrawPending:false,redrawDirty:false,previewScheduled:false,previewTimer:null,lastCursor:null,viewport:null,host:null,writer:Promise.resolve(),undo:[],redo:[],editSnapshot:null,readError:null};try{state.data=await load();state.previewHour=state.data.timeOfDay.previewHour??12;}catch(e){state.readError=String(e.message||e);fail(e);}
void preloadMasks().catch(fail);
 ctx.ui.registerPanel({id:PANEL,title:'Lighting Studio',defaultPosition:'right',defaultSize:{width:1050,height:810},render(host){state.host=host;refresh();return()=>{if(state?.host===host)state.host=null;};}});
ctx.menu.registerMenuItem({menu:'Mods',label:'Lighting Studio',icon:'sun',handler:()=>{ctx.ui.openPanel(PANEL);ctx.editor.setTool(TOOL);redraw();}});
ctx.commands.register('lighting-studio.open',()=>ctx.ui.openPanel(PANEL));
ctx.tools.registerTool({id:TOOL,label:'Lighting Studio',icon:'☀',onActivate(){ctx.ui.openPanel(PANEL);redraw();},onPointerDown:pointerDown,onPointerMove:pointerMove,onPointerUp:pointerUp,onDeactivate(){pointerUp();if(state){state.hover=null;state.hoverHit=null;redraw();}}});
// The baseline Overlay API is used deliberately: it is the most compatible canvas
// drawing hook and, unlike advanced overlays, does not depend on animation metadata.
const item={id:'lighting-studio.overlay',zOrder:500,render:overlay};
// The basic overlay was the version known to draw reliably in this project.
if(ctx.ui.registerOverlay){ctx.ui.registerOverlay(item);state.advancedOverlay=false;}
else if(ctx.ui.registerAdvancedOverlay){ctx.ui.registerAdvancedOverlay(item);state.advancedOverlay=true;}
else notify('Esta versión de Maker Studio no admite overlays de mods.','error');
ctx.bus.on('map.loaded',event=>{if(event?.mapId)selectMap(event.mapId);redraw();});
redraw();state.ticker=setInterval(()=>{
 if(!state || (typeof document!=='undefined' && document.hidden))return;
 const now=performance.now();
 if(now-(state.lastStatusAt||0)>650){state.lastStatusAt=now;updateDiagnosticStatus();}
 // Keep editor responsiveness ahead of high-quality background baking.
// Full preview is explicitly requested; normal work should never exceed
// the balanced cadence merely because another overlay repaints.
const wait=state.previewQuality==='full'?420:state.previewQuality==='fast'?800:650;
 if(now-(state.lastTickRedraw||0)<wait)return;
 if(state.editSnapshot || state.drag)return; // no background repaint competes with pointer input
 if((state.previewQuality==='full'&&!state.drag&&!state.editSnapshot&&hasPendingChunks())||
    (state.previewAnimateLights&&!state.advancedOverlay&&state.showOverlay&&current()?.lights?.some(l=>l.enabled&&l.pulse?.enabled))){
   state.lastTickRedraw=now;redraw();
 }
},120);
}
export function deactivate(){if(state?.autosaveTimer!=null){clearTimeout(state.autosaveTimer);state.autosaveTimer=null;void persist().catch(fail);}if(state?.ticker)clearInterval(state.ticker);if(state?.previewTimer!=null)clearTimeout(state.previewTimer);if(state?.settleTimer!=null)clearTimeout(state.settleTimer);forgetMaskImages();state=null;}
