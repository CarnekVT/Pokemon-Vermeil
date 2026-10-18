import {DATA_PATH,defaultProject,normalizeProject,getMap,makeLight,deepCopy} from './model.js';
const PANEL='lighting-studio.main', TOOL='lighting-studio.place';
let state=null;
const node=(tag,text)=>{const e=document.createElement(tag);if(text!==undefined)e.textContent=String(text);return e;};
const css=`
.ls-root{display:flex;flex-direction:column;gap:10px;padding:12px;color:var(--text-primary);height:100%;box-sizing:border-box;overflow:auto;font:13px inherit}
.ls-bar{display:flex;gap:6px;align-items:center;flex-wrap:wrap}.ls-layout{display:grid;grid-template-columns:minmax(200px,1fr) minmax(260px,1.4fr);gap:12px}
.ls-card{background:var(--bg-secondary);border:1px solid var(--border);border-radius:8px;padding:12px;min-width:0}
.ls-btn{background:var(--bg-tertiary);color:var(--text-primary);border:1px solid var(--border);border-radius:5px;padding:7px;cursor:pointer;font:inherit}
.ls-btn.selected{border-color:var(--accent)}.ls-list{display:flex;flex-direction:column;gap:5px;max-height:360px;overflow:auto}
.ls-field{display:flex;gap:8px;align-items:center;justify-content:space-between;margin:9px 0}.ls-field input{max-width:128px;width:50%;box-sizing:border-box}
.ls-note{color:var(--text-secondary);font-size:12px;line-height:1.5}.ls-preview{width:100%;height:170px;background:#182538;display:block;border-radius:6px}
@media(max-width:650px){.ls-layout{grid-template-columns:1fr}}
`;
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
function refresh(){if(!state?.host)return;const root=state.host;root.replaceChildren();if(!root.querySelector('style')){const style=node('style',css);root.append(style);}
const shell=node('div');shell.className='ls-root';root.append(shell);const bar=node('div');bar.className='ls-bar';shell.append(bar);
bar.append(node('strong','Lighting Studio · MVP'),node('span','Mapa ID:'));
const mapInput=node('input');mapInput.type='number';mapInput.min='1';mapInput.value=String(state.mapId);mapInput.style.width='70px';mapInput.addEventListener('change',()=>{state.mapId=Math.max(1,Number(mapInput.value)||1);state.selected=null;refresh();});bar.append(mapInput);
bar.append(btn('↶ Deshacer',undo),btn('↷ Rehacer',redo),btn('Guardar',()=>{void persist().then(()=>notify('Luces guardadas.')).catch(fail);}));
if(state.readError){shell.append(node('p','ERROR al cargar: '+state.readError+'. No se guardarán cambios.'));return;}
const map=current();const layout=node('div');layout.className='ls-layout';shell.append(layout);
const left=node('div');left.className='ls-card';layout.append(left);left.append(node('h3','Fuentes de luz'));const actions=node('div');actions.className='ls-bar';left.append(actions);
actions.append(btn('Activar herramienta sobre mapa',()=>{state.ctx.editor.setTool(TOOL);notify('Clic en el mapa para insertar una luz. Ctrl + clic para borrar.');}));
actions.append(btn('+ Luz (8,6)',()=>change(()=>{const m=getMap(state.data,state.mapId,true);const light=makeLight(8,6);m.lights.push(light);state.selected=light.id;})));
const list=node('div');list.className='ls-list';left.append(list);
for(const l of map?.lights||[]){const b=btn(l.name+' · ('+l.x+', '+l.y+')',()=>{state.selected=l.id;refresh();});if(l.id===state.selected)b.classList.add('selected');list.append(b);}
left.append(node('h3','Ambiente global'));
field(left,'Oscuridad', 'number',map?.ambient.darkness??0.42,v=>change(()=>getMap(state.data,state.mapId,true).ambient.darkness=Math.max(0,Math.min(1,v))),{min:0,max:1,step:.05});
field(left,'Color ambiental','color',map?.ambient.color??'#142439',v=>change(()=>getMap(state.data,state.mapId,true).ambient.color=v));
const right=node('div');right.className='ls-card';layout.append(right);right.append(node('h3','Inspector y preview'));
const selected=active();if(!selected)right.append(node('p','Selecciona una luz o insértala haciendo clic en el mapa.'));
else {field(right,'Nombre','text',selected.name,v=>change(()=>active().name=String(v).slice(0,80)));
for(const [label,key,min,max,step] of [['X (tiles)','x',-2048,2048,.25],['Y (tiles)','y',-2048,2048,.25],['Radio (px)','radiusPx',8,512,1],['Intensidad','intensity',0,1,.05],['Suavidad','softness',.05,1,.05]])field(right,label,'number',selected[key],v=>change(()=>active()[key]=Math.max(min,Math.min(max,v))),{min,max,step});
field(right,'Color','color',selected.color,v=>change(()=>active().color=v));
right.append(btn(selected.enabled?'Desactivar luz':'Activar luz',()=>change(()=>active().enabled=!active().enabled)));
right.append(btn('Eliminar luz',()=>change(()=>{const m=current();m.lights=m.lights.filter(l=>l.id!==state.selected);state.selected=null;})));
}
const canvas=node('canvas');canvas.className='ls-preview';right.append(canvas);right.append(node('p','Preview esquemático; la vista real se proyecta sobre el mapa abierto de Maker Studio.'));right.lastChild.className='ls-note';drawCanvas(canvas,current());
const note=node('p','Fase 0/1: luces radiales y ambiente. Sombras, shaders, formas y timeline permanecen fuera de este MVP.');note.className='ls-note';shell.append(note);
}
function overlay(draw,info){if(!state||state.readError||Number(info.mapId)!==Number(state.mapId))return;const m=current();if(!m)return;
const zoom=Number(info.zoom)||1,tile=Number(info.tileSize)||32;
const p=(x,y)=>[(x*tile-info.viewportX)*zoom,(y*tile-info.viewportY)*zoom];
for(const l of m.lights){if(!l.enabled)continue;const [x,y]=p(l.x,l.y),r=l.radiusPx*zoom;if(x+r<0||y+r<0||x-r>info.canvasWidth||y-r>info.canvasHeight)continue;const grad=draw.createRadialGradient(x,y,0,x,y,r);grad.addColorStop(0,l.color);grad.addColorStop(1,'rgba(0,0,0,0)');draw.save();draw.globalAlpha=l.intensity*.65;draw.fillStyle=grad;draw.beginPath();draw.arc(x,y,r,0,Math.PI*2);draw.fill();draw.globalAlpha=1;draw.lineWidth=l.id===state.selected?2:1;draw.strokeStyle=l.id===state.selected?'#FFFFFF':'#FFC870';draw.beginPath();draw.arc(x,y,6,0,Math.PI*2);draw.stroke();draw.restore();}
}
function selectMap(id){const n=Number(id);if(n>0&&state.mapId!==n){state.mapId=n;state.selected=null;refresh();}}
export async function activate(ctx){state={ctx,data:defaultProject(),mapId:1,selected:null,host:null,writer:Promise.resolve(),undo:[],redo:[],readError:null};
try{state.data=await load();}catch(e){state.readError=String(e.message||e);fail(e);}
ctx.ui.registerPanel({id:PANEL,title:'Lighting Studio',defaultPosition:'right',defaultSize:{width:1080,height:780},render(host){state.host=host;refresh();return()=>{if(state?.host===host)state.host=null;};}});
ctx.menu.registerMenuItem({menu:'Mods',label:'Lighting Studio',icon:'sun',handler:()=>ctx.ui.openPanel(PANEL)});
ctx.commands.register('lighting-studio.open',()=>ctx.ui.openPanel(PANEL));
ctx.tools.registerTool({id:TOOL,label:'Luz radial',icon:'💡',onActivate(){ctx.ui.openPanel(PANEL);},onPointerMove(e){if(state)selectMap(e.mapId);},onPointerDown(e){if(e.buttons&&!(e.buttons&1))return;try{selectMap(e.mapId);const x=Number(e.tileX)+.5,y=Number(e.tileY)+.5;if(e.ctrlKey||e.altKey){const m=current();if(!m)return;let best=null,d=Infinity;for(const l of m.lights){const v=(l.x-x)**2+(l.y-y)**2;if(v<d){d=v;best=l;}}if(!best||d>2)return;change(()=>{m.lights=m.lights.filter(l=>l.id!==best.id);state.selected=null;});}else change(()=>{const m=getMap(state.data,state.mapId,true),l=makeLight(x,y);m.lights.push(l);state.selected=l.id;});}catch(err){fail(err);}}});
const item={id:'lighting-studio.overlay',zOrder:10,render:overlay};
if(ctx.ui.registerAdvancedOverlay)ctx.ui.registerAdvancedOverlay(item);else ctx.ui.registerOverlay(item);
ctx.bus.on('map.loaded',event=>{if(event?.mapId)selectMap(event.mapId);});
}
export function deactivate(){state=null;}
