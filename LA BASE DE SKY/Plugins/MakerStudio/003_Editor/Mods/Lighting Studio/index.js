import {DATA_PATH,defaultProject,normalizeProject,getMap,makeLight,deepCopy,parseCoordinate,LIGHT_TYPES,TYPE_NAMES,FADE_MODES,FADE_NAMES} from './model.js';
import {STYLES,LIGHTING_EXTRA_CSS,LIGHTING_LAYER_DIAGNOSTIC_CSS,LIGHTING_WORKSPACE_CSS} from './styles.js';
import {point as pointerPoint, hitTest, paint} from './map_overlay.js';
import {cacheSize,clearLightCache} from './render.js';
const PANEL='lighting-studio.main', TOOL='lighting-studio.place';
let state=null;
const node=(tag,text)=>{const e=document.createElement(tag);if(text!==undefined)e.textContent=String(text);return e;};
const css=STYLES+LIGHTING_EXTRA_CSS+LIGHTING_LAYER_DIAGNOSTIC_CSS+LIGHTING_WORKSPACE_CSS;
function notify(message,level='info'){state?.ctx.ui.showToast({message,level,durationMs:4000});}
function fail(e){const msg=String(e?.message||e);state?.ctx.log.error(msg);notify(msg,'error');}
function current(){return getMap(state.data,state.mapId,false);}
function active(){return current()?.lights.find(l=>l.id===state.selected)||null;}
function record(){state.undo.push(deepCopy(state.data));if(state.undo.length>60)state.undo.shift();state.redo=[];}
function invalidate(){if(state)state.revision=(state.revision||0)+1;}
function redraw(){
 const owner=state;if(!owner?.ctx)return;
 owner.redrawDirty=true;
 if(owner.redrawPending||owner.awaitingOverlay)return;
 owner.redrawPending=true;
 const elapsed=performance.now()-(owner.lastRedraw||0);
 setTimeout(()=>{
  if(state!==owner)return;
  owner.redrawPending=false;
  if(!owner.redrawDirty||owner.awaitingOverlay)return;
  owner.redrawDirty=false;
  owner.lastRedraw=performance.now();
  owner.lastRequestAt=owner.lastRedraw;
  owner.awaitingOverlay=true;
  owner.ctx.editor.requestRedraw?.();
  // Fail-safe if this Maker Studio build does not signal completion.
  setTimeout(()=>{
   if(state!==owner||!owner.awaitingOverlay)return;
   owner.awaitingOverlay=false;
   if(owner.redrawDirty)redraw();
  },700);
 },Math.max(0,110-elapsed));
}
function updateDiagnosticStatus(){if(!state?.statusNode)return;const stats=state.overlayStats,age=stats.lastAt?Date.now()-stats.lastAt:Infinity;state.statusNode.textContent=stats.errors?'Error al dibujar: '+stats.lastError:age<2500?'Mapa '+stats.lastMap+' · '+(stats.lastMs||0).toFixed(1)+' ms · espera '+Math.round(stats.requestDelayMs||0)+' ms · caché '+cacheSize().masks+'/'+cacheSize().views:'Sin respuesta del overlay · usa «Prueba visual»';state.statusNode.style.color=stats.errors?'#ff8e80':age<2500?'#82e2ae':'#f0c784';}
function change(fn){if(state.readError)throw Error('Archivo dañado: edición bloqueada.');record();fn();invalidate();redraw();refresh();void persist().catch(fail);}
function undo(){if(!state.undo.length)return;state.redo.push(deepCopy(state.data));state.data=state.undo.pop();invalidate();redraw();refresh();void persist().catch(fail);}
function redo(){if(!state.redo.length)return;state.undo.push(deepCopy(state.data));state.data=state.redo.pop();invalidate();redraw();refresh();void persist().catch(fail);}
function persist(){if(!state)return Promise.resolve();state.saveRequested=true;if(state.saving)return state.writer;state.saving=true;
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
function refresh(){if(!state?.host)return;const root=state.host;const oldScroll=root.querySelector('.ls-root')?.scrollTop||0;root.replaceChildren();const style=node('style',css);root.append(style);const shell=element('div','ls-root');root.append(shell);
const head=element('div','ls-head');shell.append(head);const brand=element('div','ls-brand');head.append(brand);brand.append(element('div','ls-logo','☀'));const info=node('div');brand.append(info);info.append(element('div','ls-title','Lighting Studio'),element('div','ls-sub','Iluminación del mapa · edición directa'));
const toolbar=element('div','ls-toolbar');shell.append(toolbar);
for(const [id,label] of [['select','↖ Seleccionar'],['place','✦ Añadir luz'],['erase','⌫ Borrar']])toolbar.append(mini(label,()=>setMode(id),state.mode===id));
const layerStatus=element('div','ls-layer-status');shell.append(layerStatus);const status=element('span','ls-layer-live','Comprobando overlay del mapa…');layerStatus.append(status);state.statusNode=status;const diagnostic=mini('Prueba visual',()=>{state.diagnostic=!state.diagnostic;redraw();refresh();});layerStatus.append(diagnostic);diagnostic.classList.toggle('active',!!state.diagnostic);updateDiagnosticStatus();
const actions=element('div','ls-actions');shell.append(actions);actions.append(mini('↶ Deshacer',undo),mini('↷ Rehacer',redo),mini('Duplicar',()=>{const l=active();if(!l)return;change(()=>{const copy=deepCopy(l);copy.id='light_'+Date.now().toString(36)+Math.random().toString(36).slice(2,5);copy.x+=.5;copy.y+=.5;copy.name+=' copia';current().lights.push(copy);state.selected=copy.id;});}));
const mapId=state.ctx.editor.activeMapId?.();if(Number(mapId)>0)state.mapId=Number(mapId);
const title=element('div','ls-hint','Mapa #'+state.mapId+' · '+(state.mode==='select'?'Clic en luz: seleccionar · arrastra para mover · Shift+arrastra: radio':state.mode==='place'?'Clic y arrastra para crear una luz del tamaño deseado':'Clic en una luz para eliminarla')+' · Ctrl + rueda: zoom del editor');shell.append(title);
if(state.readError){shell.append(element('div','ls-hint','ERROR al leer los datos: '+state.readError+' · Edición bloqueada.'));return;}
const m=current();const scene=getMap(state.data,state.mapId,true);const section=element('section','ls-section');shell.append(section);const heading=element('div','ls-section-heading');section.append(heading);heading.append(node('span','Fuentes luminosas'),element('span','ls-count',String(m?.lights.length||0)));const library=element('div','ls-inline');section.append(library);library.append(mini('＋ Nueva',()=>{const cx=state.lastCursor?.x??8,cy=state.lastCursor?.y??6;change(()=>{const d=getMap(state.data,state.mapId,true),l=makeLight(cx,cy,state.newType);d.lights.push(l);state.selected=l.id;});}),mini('▤ Presets',()=>{const light=active();if(!light)return notify('Selecciona primero una luz','warn');change(()=>{Object.assign(active(),{color:'#FFAD51',intensity:.85,radiusPx:112,softness:.8,name:'Farola cálida'});});}));
const typePicker=node('select');typePicker.className='ls-input';for(const t of LIGHT_TYPES){const o=node('option',TYPE_NAMES[t]);o.value=t;typePicker.append(o);}typePicker.value=state.newType;typePicker.onchange=()=>{state.newType=typePicker.value;redraw();};labeled(section,'Tipo para luces nuevas',typePicker);
const list=element('div','ls-list');section.append(list);
if(!m?.lights.length)list.append(element('div','ls-empty','Todavía no hay luces. Usa «Añadir luz» sobre el mapa.'));
for(const l of m?.lights||[]){const row=element('div','ls-item'+(l.id===state.selected?' selected':''));list.append(row);const sw=element('span','ls-swatch');sw.style.background=l.color;sw.style.color=l.color;row.append(sw);const main=element('button','ls-item-main');main.type='button';main.append(element('div','ls-item-name',l.name),element('div','ls-item-meta',Math.round(l.radiusPx)+' px · '+Math.round(l.intensity*100)+'%'));main.onclick=()=>{state.selected=l.id;state.mode='select';state.ctx.editor.setTool(TOOL);redraw();refresh();};row.append(main);const eye=element('button','ls-ghost',l.enabled?'◉':'◌');eye.title=l.enabled?'Ocultar':'Mostrar';eye.onclick=()=>change(()=>{l.enabled=!l.enabled;});row.append(eye);}
const ambient=element('section','ls-section');shell.append(ambient);ambient.append(element('div','ls-section-heading','Ambiente y control general'));
const previewOptions=element('div','ls-inline');ambient.append(previewOptions);
const night=mini(state.previewNight?'◐ Vista nocturna activa':'◐ Vista nocturna (solo editor)',()=>{
 state.previewNight=!state.previewNight;invalidate();redraw();refresh();
},state.previewNight);
previewOptions.append(night);
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
const insp=element('section','ls-section ls-inspector');shell.append(insp);
const insHead=element('div','ls-section-heading');insHead.append(node('span','INSPECTOR DE LUZ'),element('span','ls-count',active()?.name||'Sin selección'));insp.append(insHead);
const nav=element('div','ls-inspector-tabs');insp.append(nav);
for(const [key,label] of [['shape','◈ Forma'],['fade','◑ Difuminado'],['pulse','◷ Pulsación'],['pixel','▦ Pixel art']]){
 nav.append(mini(label,()=>{state.inspectorTab=key;refresh();},state.inspectorTab===key));
}
const selected=active();
if(!selected)insp.append(element('div','ls-empty','Selecciona una luz en el mapa o en la biblioteca.'));
else{
const tabs={};
for(const id of ['shape','fade','pulse','pixel']){const panel=element('div','ls-tab-body');panel.hidden=state.inspectorTab!==id;insp.append(panel);tabs[id]=panel;}
const shapePanel=tabs.shape,fadePanel=tabs.fade,pulsePanel=tabs.pulse,pixelPanel=tabs.pixel;
shapePanel.append(element('div','ls-group-label','PROPIEDADES GENERALES'));
fadePanel.append(element('p','ls-inline-note','Elige dónde comienza el brillo y hacia qué dirección se atenúa. Las geometrías conservan su contorno.'));
const typeSelect=node('select');typeSelect.className='ls-input';for(const t of LIGHT_TYPES){const o=node('option',TYPE_NAMES[t]);o.value=t;typeSelect.append(o);}typeSelect.value=selected.type;typeSelect.onchange=()=>change(()=>{selected.type=typeSelect.value;});labeled(shapePanel,'Geometría',typeSelect);
if(selected.type==='cone'){slider(shapePanel,'Apertura (grados)',selected.angle,5,170,1,(v,final)=>editValue(()=>selected.angle=v,final));}
if(selected.type==='ellipse'||selected.type==='rectangle'){slider(shapePanel,'Anchura (px)',selected.widthPx,8,1024,1,(v,final)=>editValue(()=>selected.widthPx=v,final));slider(shapePanel,'Altura (px)',selected.heightPx,8,1024,1,(v,final)=>editValue(()=>selected.heightPx=v,final));}
if(selected.type!=='radial')slider(shapePanel,'Rotación',selected.rotation,-360,360,1,(v,final)=>editValue(()=>selected.rotation=v,final));
const name=node('input');name.type='text';name.className='ls-input';name.value=selected.name;name.onchange=()=>change(()=>selected.name=name.value.slice(0,80));labeled(shapePanel,'Nombre',name);
const c=node('input');c.type='color';c.className='ls-color';c.value=selected.color;c.oninput=()=>editValue(()=>selected.color=c.value,false);c.onchange=()=>editValue(()=>selected.color=c.value,true);labeled(shapePanel,'Color',c);
slider(shapePanel,'Intensidad',selected.intensity,0,1,.01,(v,final)=>editValue(()=>selected.intensity=clamp(v,0,1),final));
slider(fadePanel,'Brillo del centro',selected.centerStrength??.65,0,1,.01,(v,final)=>editValue(()=>selected.centerStrength=clamp(v,0,1),final));
slider(shapePanel,'Radio · píxeles',selected.radiusPx,8,512,1,(v,final)=>editValue(()=>selected.radiusPx=clamp(v,8,512),final));
slider(fadePanel,'Suavidad',selected.softness,.05,1,.01,(v,final)=>editValue(()=>selected.softness=clamp(v,.05,1),final));
const blend=node('select');blend.className='ls-input';for(const [value,label] of [['union','Unir con otras luces'],['sum','Sumar brillo (independiente)'],['normal','Normal'],['subtract','Oscurecer']]){const opt=node('option',label);opt.value=value;blend.append(opt);}blend.value=selected.blendMode==='add'?'union':(selected.blendMode||'union');blend.onchange=()=>change(()=>selected.blendMode=blend.value);labeled(shapePanel,'Modo de mezcla',blend);
const fadeSelect=node('select');fadeSelect.className='ls-input';
for(const id of FADE_MODES){const o=node('option',FADE_NAMES[id]);o.value=id;fadeSelect.append(o);}
fadeSelect.value=selected.fadeMode||'center';
fadeSelect.onchange=()=>change(()=>selected.fadeMode=fadeSelect.value);
labeled(fadePanel,'Origen del difuminado',fadeSelect);
if(selected.fadeMode==='custom'){
 slider(fadePanel,'Origen horizontal',selected.fadeX??0,-1,1,.05,(v,final)=>editValue(()=>selected.fadeX=v,final));
 slider(fadePanel,'Origen vertical',selected.fadeY??0,-1,1,.05,(v,final)=>editValue(()=>selected.fadeY=v,final));
}
const pulse=element('div','ls-effect-group');pulsePanel.append(pulse);pulse.append(element('b',null,'Pulsación'));const on=node('input');on.type='checkbox';on.checked=selected.pulse.enabled;on.onchange=()=>change(()=>selected.pulse.enabled=on.checked);labeled(pulse,'Activar pulsación',on);slider(pulse,'Velocidad (Hz)',selected.pulse.speedHz,.05,12,.05,(v,final)=>editValue(()=>selected.pulse.speedHz=v,final));slider(pulse,'Oscilación intensidad',selected.pulse.intensity,0,1,.01,(v,final)=>editValue(()=>selected.pulse.intensity=v,final));slider(pulse,'Oscilación tamaño',selected.pulse.radius,0,.9,.01,(v,final)=>editValue(()=>selected.pulse.radius=v,final));
const pixel=element('div','ls-effect-group');pixelPanel.append(pixel);pixel.append(element('b',null,'Pixel Art'));const pixelOn=node('input');pixelOn.type='checkbox';pixelOn.checked=selected.pixel.enabled;pixelOn.onchange=()=>change(()=>selected.pixel.enabled=pixelOn.checked);labeled(pixel,'Pixelar luz',pixelOn);slider(pixel,'Tamaño de píxel',selected.pixel.size,2,32,1,(v,final)=>editValue(()=>selected.pixel.size=Math.round(v),final));slider(pixel,'Niveles de degradado',selected.pixel.steps,2,24,1,(v,final)=>editValue(()=>selected.pixel.steps=Math.round(v),final));
const coords=element('div','ls-two');shapePanel.append(coords);for(const axis of ['x','y']){const input=node('input');input.type='text';input.inputMode='decimal';input.className='ls-input';input.placeholder='Ej. 25.30';input.value=String(selected[axis]);input.onchange=()=>{const n=parseCoordinate(input.value);if(n===null){input.value=String(selected[axis]);notify('Introduce una coordenada entre -2048 y 2048, con decimales libres.','warn');return;}change(()=>selected[axis]=n);};labeled(coords,axis.toUpperCase()+' (tiles)',input);}
const buttons=element('div','ls-inline');shapePanel.append(buttons);buttons.append(mini('⌫ Eliminar',()=>change(()=>{const map=current();map.lights=map.lights.filter(l=>l.id!==selected.id);state.selected=null;})));
}
const wipe=element('div','ls-inline');ambient.append(wipe);wipe.append(mini('Restablecer iluminación del mapa',()=>{const n=(current()?.lights?.length||0);const message='Se eliminarán '+n+' luces y se restaurará el ambiente de este mapa. ¿Continuar?';const confirm=state.ctx.ui.showConfirmDialog({title:'Restablecer iluminación',message,confirmLabel:'Restablecer',cancelLabel:'Cancelar'});Promise.resolve(confirm).then(ok=>{if(ok)change(()=>{state.data.maps[String(state.mapId)]={enabled:true,overlapMode:'union',ambient:{color:'#142439',darkness:0},lights:[]};state.selected=null;});}).catch(fail);}));
const hint=element('div','ls-preview-legend','La iluminación se dibuja sobre el mapa mediante un overlay independiente de Fog, Panorama y Sombras. Prueba visual muestra una marca amarilla para comprobar si Maker Studio lo está renderizando.');shell.append(hint);
const footer=element('div','ls-bottom');shell.append(footer);const visible=node('input');visible.type='checkbox';visible.checked=state.showOverlay;visible.onchange=()=>{state.showOverlay=visible.checked;state.ctx.editor.requestRedraw?.();};const lbl=element('label','ls-checkbox');lbl.append(visible,node('span','Ver luces en mapa'));footer.append(lbl);const guides=node('input');guides.type='checkbox';guides.checked=state.showGuides;guides.onchange=()=>{state.showGuides=guides.checked;redraw();};const guidesLabel=element('label','ls-checkbox');guidesLabel.append(guides,node('span','Ver marcadores'));footer.append(guidesLabel);footer.append(element('span','ls-grow'));footer.append(mini('Guardar',()=>void persist().then(()=>notify('Iluminación guardada')).catch(fail)));shell.scrollTop=oldScroll;
}
const clamp=(v,a,b)=>Math.min(b,Math.max(a,Number.isFinite(v)?v:a));
function editValue(fn,final){if(!state.editSnapshot){state.editSnapshot=deepCopy(state.data);state.redo=[];}fn();invalidate();redraw();if(final){state.undo.push(state.editSnapshot);state.editSnapshot=null;void persist().catch(fail);}}

function overlay(draw,info){if(!state||!draw||!info)return;
const stats=state.overlayStats;stats.calls++;stats.lastAt=Date.now();stats.lastMap=info.mapId;const renderStarted=performance.now();if(state.awaitingOverlay){stats.requestDelayMs=Math.max(0,renderStarted-state.lastRequestAt);state.awaitingOverlay=false;state.redrawDirty=false;}
try{
 const map=getMap(state.data,info.mapId,false);
 paint(draw,info,{map:map||{enabled:true,ambient:{darkness:0,color:'#142439'},lights:[]},showPreview:!state.readError&&state.showOverlay,previewNight:state.previewNight,showGuides:state.showGuides,editing:state.ctx.editor.activeTool?.()===TOOL&&Number(info.mapId)===Number(state.mapId),selectedId:state.selected,hover:state.hover,hoverHit:state.hoverHit,mode:state.mode,drag:state.drag,brushRadius:state.brushRadius,brush:{type:state.newType},revision:state.revision,time:performance.now()/1000});
 if(state.diagnostic){draw.save();try{
  draw.globalAlpha=1;draw.globalCompositeOperation='source-over';draw.fillStyle='#FFDE3B';draw.fillRect(10,10,190,34);draw.strokeStyle='#121826';draw.lineWidth=2;draw.strokeRect(10,10,190,34);draw.fillStyle='#111821';draw.font='bold 13px sans-serif';draw.fillText('LIGHTING · MAPA '+info.mapId,18,32);
 }finally{draw.restore();}}
 stats.lastMs=performance.now()-renderStarted;stats.errors=0;stats.lastError='';
}catch(error){stats.errors++;stats.lastError=String(error?.message||error);if(stats.errors===1){state.ctx.log.error('[Lighting Studio] Error en overlay',error);notify('Error en preview: '+stats.lastError,'error');}}
}
function selectMap(id){const n=Number(id);if(n>0&&state.mapId!==n){state.mapId=n;state.selected=null;state.hover=null;state.hoverHit=null;redraw();refresh();}}

function pointerDown(e){if(!state||state.readError||e.buttons&&!(e.buttons&1))return;selectMap(e.mapId);const pt=pointerPoint(e);state.hover=pt;state.lastCursor=pt;const found=hitTest(current()?.lights,pt,state.selected,!!e.shiftKey);state.hoverHit=found;
if(state.mode==='erase'){if(found)change(()=>{const m=current();m.lights=m.lights.filter(l=>l.id!==found.light.id);if(state.selected===found.light.id)state.selected=null;});redraw();return;}
if(state.mode==='select'){state.selected=found?.light.id||null;if(found){state.drag={id:found.light.id,part:found.part,start:pt,origin:{x:found.light.x,y:found.light.y,radius:found.light.radiusPx},before:deepCopy(state.data)};}redraw();refresh();return;}
if(state.mode==='place'){const l=makeLight(pt.x,pt.y,state.newType);record();const m=getMap(state.data,state.mapId,true);m.lights.push(l);state.selected=l.id;state.drag={id:l.id,part:'radius',start:pt,origin:{x:pt.x,y:pt.y,radius:state.brushRadius},before:null};l.radiusPx=state.brushRadius;invalidate();redraw();refresh();}}
function pointerMove(e){if(!state||Number(e.mapId)!==Number(state.mapId))return;const pt=pointerPoint(e);const previous=state.hover;const d=state.drag;
if(!d&&previous?.x===pt.x&&previous?.y===pt.y)return;
state.lastCursor=pt;state.hover=pt;state.hoverHit=hitTest(current()?.lights,pt,state.selected,!!e.shiftKey);
if(d){const l=current()?.lights.find(x=>x.id===d.id);if(l){if(d.part==='move'){l.x=d.origin.x+pt.x-d.start.x;l.y=d.origin.y+pt.y-d.start.y;}else{const distance=Math.hypot(pt.x-l.x,pt.y-l.y)*32;l.radiusPx=clamp(distance||state.brushRadius,8,512);}}}
if(d)invalidate();redraw();}
function pointerUp(){if(!state?.drag)return;const d=state.drag;state.drag=null;if(d.before){state.undo.push(d.before);if(state.undo.length>60)state.undo.shift();state.redo=[];}redraw();refresh();void persist().catch(fail);}
export async function activate(ctx){state={ctx,data:defaultProject(),mapId:Number(ctx.editor.activeMapId?.())||1,diagnostic:false,overlayStats:{calls:0,lastAt:0,lastMap:null,errors:0,lastError:'',lastMs:0,requestDelayMs:0},statusNode:null,selected:null,mode:'select',inspectorTab:'shape',previewNight:false,revision:0,lastRedraw:0,lastRequestAt:0,awaitingOverlay:false,saving:false,saveRequested:false,showOverlay:true,showGuides:true,newType:'radial',brushRadius:96,hover:null,hoverHit:null,drag:null,clock:0,redrawPending:false,redrawDirty:false,lastCursor:null,viewport:null,host:null,writer:Promise.resolve(),undo:[],redo:[],editSnapshot:null,readError:null};try{state.data=await load();}catch(e){state.readError=String(e.message||e);fail(e);}
ctx.ui.registerPanel({id:PANEL,title:'Lighting Studio',defaultPosition:'right',defaultSize:{width:390,height:850},render(host){state.host=host;refresh();return()=>{if(state?.host===host)state.host=null;};}});
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
redraw();state.ticker=setInterval(()=>{if(!state)return;updateDiagnosticStatus();if(!state.advancedOverlay&&current()?.lights?.some(l=>l.enabled&&l.pulse?.enabled))redraw();},250);
}
export function deactivate(){if(state?.ticker)clearInterval(state.ticker);clearLightCache();state=null;}
