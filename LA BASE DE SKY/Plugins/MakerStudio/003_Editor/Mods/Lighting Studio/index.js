import {DATA_PATH,defaultProject,normalizeProject,getMap,makeLight,deepCopy} from './model.js';
import {STYLES} from './styles.js';
const PANEL='lighting-studio.main', TOOL='lighting-studio.place';
let state=null;
const node=(tag,text)=>{const e=document.createElement(tag);if(text!==undefined)e.textContent=String(text);return e;};
const css=STYLES;
function notify(message,level='info'){state?.ctx.ui.showToast({message,level,durationMs:4000});}
function fail(e){const msg=String(e?.message||e);state?.ctx.log.error(msg);notify(msg,'error');}
function current(){return getMap(state.data,state.mapId,false);}
function active(){return current()?.lights.find(l=>l.id===state.selected)||null;}
function record(){state.undo.push(deepCopy(state.data));if(state.undo.length>60)state.undo.shift();state.redo=[];}
function change(fn){if(state.readError)throw Error('Archivo dañado: edición bloqueada.');record();fn();refresh();void persist().catch(fail);}
function undo(){if(!state.undo.length)return;state.redo.push(deepCopy(state.data));state.data=state.undo.pop();refresh();void persist().catch(fail);}
function redo(){if(!state.redo.length)return;state.undo.push(deepCopy(state.data));state.data=state.redo.pop();refresh();void persist().catch(fail);}
async function persist(){const data=JSON.stringify(state.data,null,2)+'\n';state.writer=state.writer.catch(()=>{}).then(async()=>{await state.ctx.fs.projectMkdir('Data/LightingStudio');await state.ctx.fs.writeProjectFile(DATA_PATH,data);});return state.writer;}
async function load(){if(!(await state.ctx.fs.projectExists(DATA_PATH)))return defaultProject();return normalizeProject(JSON.parse(await state.ctx.fs.readProjectFile(DATA_PATH)));}
function btn(text,run){const b=node('button',text);b.className='ls-btn';b.type='button';b.addEventListener('click',()=>{try{run();}catch(e){fail(e);}});return b;}
function field(host,label,type,value,onChange,settings={}){const row=node('label');row.className='ls-field';row.append(node('span',label));const input=node('input');input.type=type;input.value=String(value);if(settings.min!==undefined)input.min=settings.min;if(settings.max!==undefined)input.max=settings.max;if(settings.step!==undefined)input.step=settings.step;input.addEventListener('change',()=>{try{onChange(type==='number'?Number(input.value):input.value);}catch(e){fail(e);}});row.append(input);host.append(row);}
function drawCanvas(canvas,map){const rect=canvas.getBoundingClientRect();canvas.width=Math.max(200,Math.floor(rect.width*devicePixelRatio));canvas.height=Math.floor(170*devicePixelRatio);const g=canvas.getContext('2d');const w=canvas.width,h=canvas.height;g.fillStyle='#1D2D40';g.fillRect(0,0,w,h);const a=map?.ambient||{color:'#142439',darkness:0.42};g.fillStyle=a.color;g.globalAlpha=a.darkness;g.fillRect(0,0,w,h);g.globalAlpha=1;for(const l of map?.lights||[]){if(!l.enabled)continue;const x=w/2+(l.x-8)*14*devicePixelRatio,y=h/2+(l.y-6)*14*devicePixelRatio,r=Math.max(1,l.radiusPx*devicePixelRatio*.5);const grad=g.createRadialGradient(x,y,0,x,y,r);grad.addColorStop(0,l.color);grad.addColorStop(1,'transparent');g.globalAlpha=l.intensity;g.fillStyle=grad;g.fillRect(x-r,y-r,r*2,r*2);}g.globalAlpha=1;}

function element(tag,cls,text){const n=node(tag,text);if(cls)n.className=cls;return n;}
function labeled(parent,name,control){const r=element('label','ls-field');r.append(element('span','ls-field-label',name),control);parent.append(r);return r;}
function slider(parent,name,value,min,max,step,cb){const wrap=element('div','ls-field');wrap.append(element('span','ls-field-label',name),element('span','ls-field-val',Math.round(value*100)/100));const row=element('div','ls-range-row');const range=element('input','ls-range'),num=element('input','ls-input ls-number');range.type='range';num.type='number';for(const v of [range,num]){v.min=min;v.max=max;v.step=step;v.value=value;}const valueEl=wrap.children[1];range.addEventListener('input',()=>{num.value=range.value;valueEl.textContent=range.value;cb(Number(range.value),false);});range.addEventListener('change',()=>cb(Number(range.value),true));num.addEventListener('change',()=>{range.value=num.value;cb(Number(num.value),true);});row.append(range,num);wrap.append(row);parent.append(wrap);}
function mini(label,fn,selected=false){const b=btn(label,fn);b.className='ls-btn ls-small'+(selected?' active':'');return b;}
function setMode(mode){state.mode=mode;state.ctx.editor.setTool(TOOL);refresh();}
function refresh(){if(!state?.host)return;const root=state.host;root.replaceChildren();const style=node('style',css);root.append(style);const shell=element('div','ls-root');root.append(shell);
const head=element('div','ls-head');shell.append(head);const brand=element('div','ls-brand');head.append(brand);brand.append(element('div','ls-logo','☀'));const info=node('div');brand.append(info);info.append(element('div','ls-title','Lighting Studio'),element('div','ls-sub','Iluminación del mapa · edición directa'));
const toolbar=element('div','ls-toolbar');shell.append(toolbar);
for(const [id,label] of [['select','↖ Seleccionar'],['place','✦ Añadir luz'],['erase','⌫ Borrar']])toolbar.append(mini(label,()=>setMode(id),state.mode===id));
const actions=element('div','ls-actions');shell.append(actions);actions.append(mini('↶ Deshacer',undo),mini('↷ Rehacer',redo),mini('Duplicar',()=>{const l=active();if(!l)return;change(()=>{const copy=deepCopy(l);copy.id='light_'+Date.now().toString(36)+Math.random().toString(36).slice(2,5);copy.x+=.5;copy.y+=.5;copy.name+=' copia';current().lights.push(copy);state.selected=copy.id;});}));
const mapId=state.ctx.editor.activeMapId?.();if(Number(mapId)>0)state.mapId=Number(mapId);
const title=element('div','ls-hint','Mapa #'+state.mapId+' · '+(state.mode==='select'?'Clic: seleccionar · arrastrar: mover luz o radio':state.mode==='place'?'Clic y arrastra para crear una luz del tamaño deseado':'Clic en una luz para eliminarla')+' · Ctrl + rueda: zoom del editor');shell.append(title);
if(state.readError){shell.append(element('div','ls-hint','ERROR al leer los datos: '+state.readError+' · Edición bloqueada.'));return;}
const m=current();const section=element('section','ls-section');shell.append(section);const heading=element('div','ls-section-heading');section.append(heading);heading.append(node('span','Fuentes luminosas'),element('span','ls-count',String(m?.lights.length||0)));const library=element('div','ls-inline');section.append(library);library.append(mini('＋ Nueva',()=>{const cx=state.lastCursor?.x??8,cy=state.lastCursor?.y??6;change(()=>{const d=getMap(state.data,state.mapId,true),l=makeLight(cx,cy);d.lights.push(l);state.selected=l.id;});}),mini('▤ Presets',()=>{const light=active();if(!light)return notify('Selecciona primero una luz','warn');change(()=>{Object.assign(active(),{color:'#FFAD51',intensity:.85,radiusPx:112,softness:.8,name:'Farola cálida'});});}));
const list=element('div','ls-list');section.append(list);
if(!m?.lights.length)list.append(element('div','ls-empty','Todavía no hay luces. Usa «Añadir luz» sobre el mapa.'));
for(const l of m?.lights||[]){const row=element('div','ls-item'+(l.id===state.selected?' selected':''));list.append(row);const sw=element('span','ls-swatch');sw.style.background=l.color;sw.style.color=l.color;row.append(sw);const main=element('button','ls-item-main');main.type='button';main.append(element('div','ls-item-name',l.name),element('div','ls-item-meta',Math.round(l.radiusPx)+' px · '+Math.round(l.intensity*100)+'%'));main.onclick=()=>{state.selected=l.id;state.mode='select';refresh();};row.append(main);const eye=element('button','ls-ghost',l.enabled?'◉':'◌');eye.title=l.enabled?'Ocultar':'Mostrar';eye.onclick=()=>change(()=>{l.enabled=!l.enabled;});row.append(eye);}
const ambient=element('section','ls-section');shell.append(ambient);ambient.append(element('div','ls-section-heading','Ambiente'));const settings=getMap(state.data,state.mapId,true).ambient;
slider(ambient,'Oscuridad',settings.darkness,0,1,.01,(v,final)=>editValue(()=>settings.darkness=clamp(v,0,1),final));
const color=node('input');color.type='color';color.className='ls-color';color.value=settings.color;color.addEventListener('input',()=>editValue(()=>settings.color=color.value,false));color.addEventListener('change',()=>editValue(()=>settings.color=color.value,true));labeled(ambient,'Color ambiental',color);
const insp=element('section','ls-section');shell.append(insp);insp.append(element('div','ls-section-heading','Inspector de luz'));const selected=active();
if(!selected)insp.append(element('div','ls-empty','Selecciona una luz en el mapa o en la biblioteca.'));
else{
const name=node('input');name.type='text';name.className='ls-input';name.value=selected.name;name.onchange=()=>change(()=>selected.name=name.value.slice(0,80));labeled(insp,'Nombre',name);
const c=node('input');c.type='color';c.className='ls-color';c.value=selected.color;c.oninput=()=>editValue(()=>selected.color=c.value,false);c.onchange=()=>editValue(()=>selected.color=c.value,true);labeled(insp,'Color',c);
slider(insp,'Intensidad',selected.intensity,0,1,.01,(v,final)=>editValue(()=>selected.intensity=clamp(v,0,1),final));
slider(insp,'Radio · píxeles',selected.radiusPx,8,512,1,(v,final)=>editValue(()=>selected.radiusPx=clamp(v,8,512),final));
slider(insp,'Suavidad',selected.softness,.05,1,.01,(v,final)=>editValue(()=>selected.softness=clamp(v,.05,1),final));
const coords=element('div','ls-two');insp.append(coords);for(const axis of ['x','y']){const input=node('input');input.type='number';input.step=.25;input.className='ls-input';input.value=selected[axis];input.onchange=()=>change(()=>selected[axis]=clamp(Number(input.value),-2048,2048));labeled(coords,axis.toUpperCase()+' (tiles)',input);}
const buttons=element('div','ls-inline');insp.append(buttons);buttons.append(mini('⌫ Eliminar',()=>change(()=>{const map=current();map.lights=map.lights.filter(l=>l.id!==selected.id);state.selected=null;})));
}
const hint=element('div','ls-preview-legend','Vista real del mapa: activa la herramienta y utiliza los tiradores. El halo es aproximado; la fidelidad con el runtime será mejorada en otra fase.');shell.append(hint);
const footer=element('div','ls-bottom');shell.append(footer);const visible=node('input');visible.type='checkbox';visible.checked=state.showOverlay;visible.onchange=()=>{state.showOverlay=visible.checked;state.ctx.editor.requestRedraw?.();};const lbl=element('label','ls-checkbox');lbl.append(visible,node('span','Ver luces en mapa'));footer.append(lbl);footer.append(element('span','ls-grow'));footer.append(mini('Guardar',()=>void persist().then(()=>notify('Iluminación guardada')).catch(fail)));
}
const clamp=(v,a,b)=>Math.min(b,Math.max(a,Number.isFinite(v)?v:a));
function editValue(fn,final){if(!state.editSnapshot){state.editSnapshot=deepCopy(state.data);state.redo=[];}fn();state.ctx.editor.requestRedraw?.();if(final){state.undo.push(state.editSnapshot);state.editSnapshot=null;void persist().catch(fail);refresh();}}

function overlay(draw,info){if(!state||!state.showOverlay||state.readError||Number(info.mapId)!==Number(state.mapId))return;const m=current();if(!m)return;
const z=Number(info.zoom)||1,tile=Number(info.tileSize)||32,p=(x,y)=>[(x*tile-info.viewportX)*z,(y*tile-info.viewportY)*z];state.viewport=info;
for(const l of m.lights){if(!l.enabled)continue;const [x,y]=p(l.x,l.y),r=l.radiusPx*z;if(x+r<0||y+r<0||x-r>info.canvasWidth||y-r>info.canvasHeight)continue;
draw.save();const grad=draw.createRadialGradient(x,y,0,x,y,r);grad.addColorStop(0,l.color);grad.addColorStop(1,'rgba(0,0,0,0)');draw.globalAlpha=l.intensity*.65;draw.fillStyle=grad;draw.beginPath();draw.arc(x,y,r,0,Math.PI*2);draw.fill();draw.globalAlpha=1;
if(l.id===state.selected){draw.strokeStyle='#FFD078';draw.lineWidth=1.5;draw.setLineDash([5,4]);draw.beginPath();draw.arc(x,y,r,0,Math.PI*2);draw.stroke();draw.setLineDash([]);draw.beginPath();draw.moveTo(x,y);draw.lineTo(x+r,y);draw.stroke();draw.fillStyle='#F7BE5A';draw.fillRect(x+r-5,y-5,10,10);}
draw.beginPath();draw.arc(x,y,l.id===state.selected?6:4,0,Math.PI*2);draw.fillStyle=l.id===state.selected?'white':'#FFD078';draw.fill();draw.strokeStyle='#28222A';draw.lineWidth=1;draw.stroke();draw.restore();}
}
function selectMap(id){const n=Number(id);if(n>0&&state.mapId!==n){state.mapId=n;state.selected=null;refresh();}}

function pixel(e){return {x:Number(e.tileX)+.5,y:Number(e.tileY)+.5};}
function nearest(e){const m=current();if(!m)return null;const pt=pixel(e),tile=32;let best=null,score=Infinity,handle='move';for(const l of m.lights){const d=Math.hypot((l.x-pt.x)*tile,(l.y-pt.y)*tile);const edge=Math.abs(d-l.radiusPx);if(edge<12&&edge<score){best=l;score=edge;handle='radius';}if(d<18&&d<score){best=l;score=d;handle='move';}}return best?{light:best,handle}:null;}
function pointerDown(e){if(e.buttons&&!(e.buttons&1))return;selectMap(e.mapId);state.lastCursor=pixel(e);if(state.readError)return;
if(state.mode==='erase'){const match=nearest(e);if(match)change(()=>{const m=current();m.lights=m.lights.filter(l=>l.id!==match.light.id);if(state.selected===match.light.id)state.selected=null;});return;}
if(state.mode==='select'){const found=nearest(e);state.selected=found?.light.id||null;if(found){state.drag={id:found.light.id,kind:found.handle,start:pixel(e),origin:{x:found.light.x,y:found.light.y,radius:found.light.radiusPx},before:deepCopy(state.data)};}refresh();return;}
if(state.mode==='place'){const pt=pixel(e),l=makeLight(pt.x,pt.y);record();const m=getMap(state.data,state.mapId,true);m.lights.push(l);state.selected=l.id;state.drag={id:l.id,kind:'radius',start:pt,origin:{x:pt.x,y:pt.y,radius:8},before:null};l.radiusPx=8;refresh();}}
function pointerMove(e){if(!state)return;state.lastCursor=pixel(e);const d=state.drag;if(!d||Number(e.mapId)!==Number(state.mapId))return;const l=current()?.lights.find(x=>x.id===d.id);if(!l)return;const pt=pixel(e),tile=32;if(d.kind==='move'){l.x=d.origin.x+pt.x-d.start.x;l.y=d.origin.y+pt.y-d.start.y;}else{l.radiusPx=clamp(Math.hypot(pt.x-l.x,pt.y-l.y)*tile,8,512);}state.ctx.editor.requestRedraw?.();}
function pointerUp(){if(!state?.drag)return;const drag=state.drag;state.drag=null;if(drag.before){state.undo.push(drag.before);if(state.undo.length>60)state.undo.shift();state.redo=[];}refresh();void persist().catch(fail);}
export async function activate(ctx){state={ctx,data:defaultProject(),mapId:Number(ctx.editor.activeMapId?.())||1,selected:null,mode:'select',showOverlay:true,drag:null,lastCursor:null,viewport:null,host:null,writer:Promise.resolve(),undo:[],redo:[],editSnapshot:null,readError:null};try{state.data=await load();}catch(e){state.readError=String(e.message||e);fail(e);}
ctx.ui.registerPanel({id:PANEL,title:'Lighting Studio',defaultPosition:'right',defaultSize:{width:390,height:850},render(host){state.host=host;refresh();return()=>{if(state?.host===host)state.host=null;};}});
ctx.menu.registerMenuItem({menu:'Mods',label:'Lighting Studio',icon:'sun',handler:()=>ctx.ui.openPanel(PANEL)});
ctx.commands.register('lighting-studio.open',()=>ctx.ui.openPanel(PANEL));
ctx.tools.registerTool({id:TOOL,label:'Lighting Studio',icon:'☀',onActivate(){ctx.ui.openPanel(PANEL);},onPointerDown:pointerDown,onPointerMove:pointerMove,onPointerUp:pointerUp,onDeactivate(){pointerUp();}});
const item={id:'lighting-studio.overlay',zOrder:10,render:overlay};
if(ctx.ui.registerAdvancedOverlay)ctx.ui.registerAdvancedOverlay(item);else ctx.ui.registerOverlay(item);
ctx.bus.on('map.loaded',event=>{if(event?.mapId)selectMap(event.mapId);});
}
export function deactivate(){state=null;}
