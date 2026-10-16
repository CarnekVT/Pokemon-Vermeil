import {
  FILE, ART_DIR, defaultData, makeDefinition, normalizeData, cleanSheet,
  validatePosition, placementAt, getPlacedCell, slug
} from './core.js';

const TOOL = 'lbds-animated-props.brush';
const PANEL = 'lbds-animated-props.library';
const CSS = `
.ap-root {display:flex;flex-direction:column;gap:12px;height:100%;box-sizing:border-box;overflow:auto;padding:12px;color:var(--text-primary);font:13px inherit;}
.ap-header {display:flex;gap:6px;align-items:center;flex-wrap:wrap;}
.ap-row {display:flex;align-items:center;gap:8px;flex-wrap:wrap;}
.ap-btn {cursor:pointer;background:var(--bg-tertiary);color:var(--text-primary);border:1px solid var(--border);border-radius:6px;padding:6px 10px;font:inherit;}
.ap-btn.primary {background:var(--accent);color:var(--accent-text);border-color:var(--accent)}
.ap-btn:disabled {opacity:.5;cursor:default}
.ap-cols {display:grid;grid-template-columns:minmax(140px,1fr) minmax(280px,2.2fr);gap:14px;min-height:0}
.ap-list {display:flex;flex-direction:column;gap:3px;max-height:460px;overflow:auto}
.ap-list button {text-align:left;white-space:normal;}
.ap-list button.active {border-color:var(--accent);background:var(--bg-hover)}
.ap-card {background:var(--bg-secondary);border:1px solid var(--border);border-radius:8px;padding:10px;min-width:0}
.ap-note {color:var(--text-secondary);line-height:1.4;font-size:12px}
.ap-fields {display:grid;grid-template-columns:repeat(2,minmax(100px,1fr));gap:8px}
.ap-label {display:flex;flex-direction:column;gap:3px;font-size:12px;color:var(--text-secondary)}
.ap-input {box-sizing:border-box;max-width:100%;width:100%;padding:6px;background:var(--input-bg);color:var(--text-primary);border:1px solid var(--border);border-radius:5px;font:inherit}
.ap-grid {display:grid;gap:1px;width:max-content;border:1px solid var(--border);background:var(--border);max-width:100%;}
.ap-cell {display:grid;place-items:center;width:32px;height:32px;background:var(--bg-tertiary);color:var(--text-primary);font:10px monospace;border:none;cursor:pointer}
.ap-cell.block {background:#ad4d4d;color:#fff}.ap-cell.partial {background:#c3944b;color:#171717}.ap-cell.active {box-shadow:inset 0 0 0 2px var(--accent)}
.ap-preview {image-rendering:pixelated;max-height:230px;max-width:100%;object-fit:contain;background:repeating-conic-gradient(#7772 0% 25%,#fff1 0% 50%) 0 / 24px 24px}
@media(max-width:650px){.ap-cols{grid-template-columns:1fr}}
`;
let state = null;

const el = (tag, text, attrs={}) => {
  const e = document.createElement(tag);
  if (text != null) e.textContent = text;
  for (const [k,v] of Object.entries(attrs)) e[k] = v;
  return e;
};
const btn = (label, cb, primary=false) => {
  const b = el('button',label,{type:'button',className:`ap-btn${primary?' primary':''}`});
  b.addEventListener('click', async () => { try { await cb(); } catch(e) { problem(e); } });
  return b;
};
function problem(e) {
  const msg=String(e?.message||e);
  state?.ctx.log.error(msg);
  state?.ctx.ui.showToast({message:msg,level:'error',durationMs:5500});
}
function toast(msg) { state.ctx.ui.showToast({message:msg,level:'info'}); }
function getDef() { return state?.data.definitions.find(d=>d.id===state.selected) || null; }
const clone=(v)=>JSON.parse(JSON.stringify(v));
function checkpoint() {
  state.undo.push(clone(state.data));
  if (state.undo.length>40) state.undo.shift();
  state.redo.length=0;
}
function undo() {
  if (!state.undo.length) return;
  state.redo.push(clone(state.data)); state.data=state.undo.pop();
  if (!getDef()) state.selected=state.data.definitions[0]?.id || '';
  refresh(); void persist().catch(problem);
}
function redo() {
  if (!state.redo.length) return;
  state.undo.push(clone(state.data)); state.data=state.redo.pop();
  if (!getDef()) state.selected=state.data.definitions[0]?.id || '';
  refresh(); void persist().catch(problem);
}
async function persist() {
  if (state.readError) throw new Error('El archivo JSON está dañado. No se sobrescribirá automáticamente.');
  const snapshot=clone(normalizeData(state.data));
  const content=JSON.stringify(snapshot,null,2)+'\n';
  // Serialize writes: two paint operations cannot race and overwrite each other.
  state.writer=state.writer.catch(()=>{}).then(async()=>{
    await state.ctx.fs.projectMkdir('Data/AnimatedProps');
    await state.ctx.fs.writeProjectFile(FILE,content);
  });
  await state.writer;
}
async function loadData() {
  const fs=state.ctx.fs;
  if (!(await fs.projectExists(FILE))) return defaultData();
  const raw=await fs.readProjectFile(FILE);
  return normalizeData(JSON.parse(raw));
}
function pathFor(sheet) { return `${ART_DIR}/${cleanSheet(sheet)}`; }
function imageUrl(sheet) {
  const c=state.images.get(sheet);
  return c && c.ok ? c.url : null;
}
async function preloadImage(sheet, force=false) {
  cleanSheet(sheet);
  if (state.images.has(sheet) && !force) return state.images.get(sheet)?.promise;
  const existing=state.images.get(sheet);
  if (existing?.url) URL.revokeObjectURL(existing.url);
  const c={img:null,url:null,ok:false,promise:null}; state.images.set(sheet,c);
  c.promise=(async()=>{
    try {
      const invoke=window.__TAURI__?.core?.invoke;
      if (!invoke) throw new Error('Esta versión no expone la API de lectura binaria de Tauri.');
      const root=state.ctx.editor.gameRoot().replace(/[\\/]+$/,'');
      const sep=root.includes('\\')?'\\':'/';
      const bytes=await invoke('read_binary_file',{path:`${root}${sep}${ART_DIR.replaceAll('/',sep)}${sep}${sheet}`});
      const url=URL.createObjectURL(new Blob([Uint8Array.from(bytes)],{type:'image/png'}));
      const image=new Image();
      await new Promise((resolve,reject)=>{image.onload=resolve;image.onerror=()=>reject(new Error('PNG no legible'));image.src=url;});
      c.img=image;c.url=url;c.ok=true;
    } catch(e){c.error=String(e.message||e);}
    refreshPreview();
    return c;
  })();
  return c.promise;
}
function refreshPreview() {
  if (!state?.host) return;
  const preview=state.host.querySelector('.ap-preview');
  if (!preview) return;
  const d=getDef(), url=d && imageUrl(d.sheet);
  preview.hidden=!url;
  if (url) { preview.src=url; preview.title='Sprite sheet completo: fotogramas horizontales'; }
}
async function importPNG() {
  const ctx=state.ctx;
  const picks=await ctx.ui.showFilePicker?.({filters:[{name:'PNG',extensions:['png']}]});
  if (!picks?.length) return;
  const src=picks[0];
  const sheet=cleanSheet(src.replaceAll('\\','/').split('/').pop());
  const dest=pathFor(sheet);
  if (await ctx.fs.projectExists(dest)) {
    const ok=await ctx.ui.showConfirmDialog({title:'Sobrescribir gráfico',message:`Ya existe ${sheet}. ¿Reemplazarlo?`});
    if (!ok) return;
  }
  const invoke=window.__TAURI__?.core?.invoke;
  if (!invoke) throw new Error('La importación requiere la API nativa de Maker Studio.');
  await ctx.fs.projectMkdir(ART_DIR);
  const root=ctx.editor.gameRoot().replace(/[\\/]+$/,'');
  const sep=root.includes('\\')?'\\':'/';
  await invoke('copy_file',{src,dst:`${root}${sep}${ART_DIR.replaceAll('/',sep)}${sep}${sheet}`});
  if (getDef()) { checkpoint(); getDef().sheet=sheet; await persist(); }
  await preloadImage(sheet,true);
  refresh(); toast(`Gráfico importado: ${sheet}`);
}
async function place(mapId,x,y,remove=false) {
  if (!Number.isInteger(mapId)||!Number.isInteger(x)||!Number.isInteger(y)) return;
  if (state.readError) return;
  const key=String(mapId);
  const list=state.data.placements[key] ||= [];
  if (remove) {
    const found=placementAt(state.data,mapId,x,y);
    if (!found) return;
    checkpoint(); const ix=list.indexOf(found); if(ix!==-1) list.splice(ix,1);
  } else {
    const d=getDef(); if (!d) {toast('Selecciona un objeto en la biblioteca.');return;}
    const info=state.ctx.map.info(mapId);
    if (!info||!validatePosition(d,x,y,info)) {toast('El objeto se sale de los límites del mapa.');return;}
    if (list.some(p=>p.defId===d.id&&p.x===x&&p.y===y)) return;
    checkpoint();
    list.push({id:`${Date.now().toString(36)}_${(++state.serial).toString(36)}`,
      defId:d.id,x,y,layer:state.ctx.editor.activeLayerIndex()||0});
  }
  refreshCounts(); await persist();
}
function attachLabel(parent,name,value,callback,type='text', min, max){
  const label=el('label',name,{className:'ap-label'});
  const input=el('input',null,{className:'ap-input',type,value:String(value)});
  if (min!=null) input.min=String(min);
  if (max!=null) input.max=String(max);
  input.addEventListener('change',async()=>{try{await callback(type==='number'?Number(input.value):input.value);}catch(e){problem(e);refresh();}});
  label.appendChild(input);parent.appendChild(label);return input;
}
async function newDefinition() {
  const name=await state.ctx.ui.showInputDialog({title:'Nuevo objeto animado',message:'Nombre (p. ej., Molino de viento)',defaultValue:'Molino de viento'});
  if (name===null)return;
  const id=slug(name);
  if (!id)throw Error('Escribe un nombre válido.');
  if (state.data.definitions.some(d=>d.id===id))throw Error(`Ya existe ${id}.`);
  const d=makeDefinition({id,name,sheet:`${id}.png`,width:4,height:4,frames:4,fps:6});
  checkpoint();state.data.definitions.push(d);state.selected=d.id;
  await persist();refresh();
}
async function deleteDefinition(){
  const d=getDef();if(!d)return;
  const affected=Object.values(state.data.placements).reduce((n,p)=>n+p.filter(x=>x.defId===d.id).length,0);
  const ok=await state.ctx.ui.showConfirmDialog({title:'Eliminar objeto',message:`Eliminar ${d.name} y sus ${affected} colocaciones en los mapas?`});
  if(!ok)return;
  checkpoint();state.data.definitions=state.data.definitions.filter(x=>x!==d);
  for(const key of Object.keys(state.data.placements))state.data.placements[key]=state.data.placements[key].filter(p=>p.defId!==d.id);
  state.selected=state.data.definitions[0]?.id||'';
  await persist();refresh();
}
async function editDefinition(patch){
  const d=getDef();if(!d)return;
  checkpoint();
  const width=patch.width??d.width,height=patch.height??d.height;
  const cells=[];
  for(let y=0;y<height;y++)for(let x=0;x<width;x++)
    cells.push(x<d.width&&y<d.height?d.cells[y*d.width+x]:{passage:0,priority:0,terrainTag:0});
  const next=makeDefinition({...d,...patch,cells});
  if(next.id!==d.id) throw Error('El ID de un objeto existente no se puede cambiar.');
  Object.assign(d,next);
  await persist();
  await preloadImage(d.sheet);
  refresh();
}
function refreshCounts() {
  const counter=state.host?.querySelector('.ap-count');
  if(!counter)return;
  const active=state.ctx.editor.activeMapId();
  counter.textContent=`Mapa ${active??'—'} · ${(state.data.placements[String(active)]||[]).length} objetos colocados`;
}
function gridCellLabel(cell,mode){
  if(mode==='passage')return (cell.passage&15)===15?'✕':(cell.passage&15)?`0x${(cell.passage&15).toString(16)}`:'○';
  if(mode==='priority')return `P${cell.priority}`;
  if(mode==='terrainTag')return `T${cell.terrainTag}`;
  if(mode==='bush')return cell.passage&0x40?'B':'·';
  return cell.passage&0x80?'C':'·';
}
function renderGrid(host,d){
  const choices=el('div',null,{className:'ap-row'});
  const mode=el('select',null,{className:'ap-input'});mode.style.width='auto';
  for(const [id,label] of [['passage','Pasabilidad'],['priority','Prioridad'],['terrainTag','Terrain Tag'],['bush','Arbusto'],['counter','Mostrador']])
    mode.appendChild(el('option',label,{value:id}));
  mode.value=state.mode;
  mode.onchange=()=>{state.mode=mode.value;refresh();};
  choices.append('Editar:',mode);host.append(choices);
  const dir=el('div',null,{className:'ap-note'});
  dir.textContent='Pasabilidad: ○ libre, ✕ bloqueado; clic alterna. Shift+clic recorre máscaras direccionales 0–15 (abajo=1, izquierda=2, derecha=4, arriba=8).';
  host.append(dir);
  const grid=el('div',null,{className:'ap-grid'});grid.style.gridTemplateColumns=`repeat(${d.width},32px)`;
  for(let i=0;i<d.cells.length;i++){
    const cell=d.cells[i];const button=el('button',gridCellLabel(cell,state.mode),{type:'button',className:'ap-cell'});
    if((cell.passage&15)===15)button.classList.add('block');
    else if(cell.passage&15)button.classList.add('partial');
    button.title=`(${i%d.width}, ${Math.floor(i/d.width)}) · paso ${cell.passage&15} · prioridad ${cell.priority} · terreno ${cell.terrainTag}`;
    button.onclick=async(ev)=>{try{
      checkpoint();
      if(state.mode==='passage'){
        const raw=cell.passage&15;
        cell.passage=(cell.passage&~15) | (ev.shiftKey?((raw+1)&15):(raw===0?15:0));
      } else if(state.mode==='priority')cell.priority=(cell.priority+1)%6;
      else if(state.mode==='terrainTag'){
        const raw=await state.ctx.ui.showInputDialog({title:'Terrain Tag',message:'Número de terreno de la Base de Sky (0–999)',defaultValue:String(cell.terrainTag)});
        if(raw===null){state.undo.pop();return;}
        const n=Number(raw);if(!Number.isInteger(n)||n<0||n>999)throw Error('Terrain Tag debe ser un entero 0–999.');cell.terrainTag=n;
      } else if(state.mode==='bush')cell.passage^=0x40;
      else cell.passage^=0x80;
      await persist();refresh();
    }catch(e){problem(e);}};
    grid.appendChild(button);
  }
  const wrap=el('div');wrap.style.overflow='auto';wrap.appendChild(grid);host.append(wrap);
}
function refresh(){
  if(!state?.host)return;
  const host=state.host;host.replaceChildren();
  const root=el('div',null,{className:'ap-root'});host.append(root);
  const st=el('style');st.textContent=CSS;root.append(st);
  const top=el('div',null,{className:'ap-header'});root.append(top);
  top.append(btn('＋ Nuevo',newDefinition,true),btn('Importar PNG',importPNG),btn('↶ Deshacer',undo),btn('↷ Rehacer',redo),btn('Guardar',persist));
  const note=el('div',null,{className:'ap-note'});
  note.textContent=`Archivo: ${FILE} · spritesheets horizontales con frames de ancho×alto tiles (32 px/tile).`;
  root.append(note);
  if(state.readError){root.append(el('div',`ERROR AL LEER: ${state.readError}. No se permitirá guardar hasta corregir el archivo manualmente.`,{className:'ap-note'}));return;}
  const cols=el('div',null,{className:'ap-cols'});root.append(cols);
  const sidebar=el('div',null,{className:'ap-card'}),detail=el('div',null,{className:'ap-card'});
  cols.append(sidebar,detail);
  sidebar.append(el('strong','Biblioteca de objetos'));
  const list=el('div',null,{className:'ap-list'});sidebar.append(list);
  for(const d of state.data.definitions){
    const b=btn(`${d.name}\n${d.width}×${d.height} · ${d.frames} frames`,()=>{state.selected=d.id;refresh();});
    if(d.id===state.selected)b.classList.add('active');list.append(b);
  }
  if(!state.data.definitions.length)list.append(el('p','Crea tu primer objeto animado.',{className:'ap-note'}));
  sidebar.append(el('p','Ctrl+clic con el pincel: eliminar el objeto bajo el cursor.',{className:'ap-note'}));
  sidebar.append(el('p','Cada objeto ocupa una región entera. No modifica los tiles nativos.',{className:'ap-note'}));
  const count=el('div',null,{className:'ap-note ap-count'});sidebar.append(count);
  sidebar.append(btn('🖌 Activar pincel',()=>{
    if(!getDef())throw Error('Selecciona un objeto.');
    state.ctx.editor.setTool(TOOL);toast('Clic para colocar; Ctrl+clic para borrar.');
  },true));
  refreshCounts();
  const d=getDef();if(!d){detail.append(el('p','Selecciona un objeto para editar sus fotogramas y cuadrícula.',{className:'ap-note'}));return;}
  const heading=el('div',null,{className:'ap-row'});detail.append(heading);
  heading.append(el('strong',d.name),btn('Eliminar objeto',deleteDefinition));
  const fields=el('div',null,{className:'ap-fields'});detail.append(fields);
  attachLabel(fields,'Nombre',d.name,v=>editDefinition({name:v}));
  attachLabel(fields,'PNG (en Graphics/AnimatedProps)',d.sheet,v=>editDefinition({sheet:cleanSheet(v)}));
  attachLabel(fields,'Ancho (tiles)',d.width,v=>editDefinition({width:v}),'number',1,32);
  attachLabel(fields,'Alto (tiles)',d.height,v=>editDefinition({height:v}),'number',1,32);
  attachLabel(fields,'Fotogramas horizontales',d.frames,v=>editDefinition({frames:v}),'number',1,64);
  attachLabel(fields,'FPS',d.fps,v=>editDefinition({fps:v}),'number',1,60);
  fields.append(btn(d.loop?'Animación: repetir ↻':'Animación: una vez →',()=>editDefinition({loop:!d.loop})));
  detail.append(el('p',`ID inmutable: ${d.id} · PNG esperado: ${d.width*32*d.frames} × ${d.height*32} px`,{className:'ap-note'}));
  const preview=el('img',null,{className:'ap-preview',alt:'Sprite sheet'});detail.append(preview);
  const pic=state.images.get(d.sheet);
  if(!pic)void preloadImage(d.sheet).then(()=>{if(state.host)refreshPreview();});
  else if(pic.error)detail.append(el('p',`Vista previa no disponible: ${pic.error}`,{className:'ap-note'}));
  refreshPreview();
  detail.append(el('h4','Propiedades por celda'));
  renderGrid(detail,d);
  detail.append(el('p','Los terrenos distintos de 0 deben existir en el motor. La prioridad funciona por celda y el bloqueo se aplica también a NPCs.',{className:'ap-note'}));
}
function drawOverlay(draw,info){
  if(!state||state.readError)return;
  const list=state.data.placements[String(info.mapId)]||[];
  for(const p of list){
    const d=state.data.definitions.find(x=>x.id===p.defId);if(!d)continue;
    const x=(p.x*info.tileSize-info.viewportX)*info.zoom;
    const y=(p.y*info.tileSize-info.viewportY)*info.zoom;
    const w=d.width*info.tileSize*info.zoom,h=d.height*info.tileSize*info.zoom;
    if(x+w<0||y+h<0||x>info.canvasWidth||y>info.canvasHeight)continue;
    const c=state.images.get(d.sheet);
    if(c?.ok&&c.img){
      const frames=Math.max(1,d.frames),t=performance.now()/1000;
      const elapsed=Math.floor(t*d.fps);
      const frame=d.loop?elapsed%frames:Math.min(elapsed,frames-1);
      draw.drawImage(c.img,frame*d.width*32,0,d.width*32,d.height*32,x,y,w,h);
    } else {
      if(!c)void preloadImage(d.sheet);
      draw.fillStyle='rgba(86,178,205,0.25)';draw.fillRect(x,y,w,h);
    }
    draw.strokeStyle='rgba(64,210,255,.8)';draw.lineWidth=1;draw.strokeRect(x+.5,y+.5,w-1,h-1);
  }
  if(state.hover&&state.hover.mapId===info.mapId&&state.ctx.editor.activeTool()===TOOL){
    const d=getDef();if(!d)return;
    const x=(state.hover.x*info.tileSize-info.viewportX)*info.zoom;
    const y=(state.hover.y*info.tileSize-info.viewportY)*info.zoom;
    draw.fillStyle='rgba(110,200,255,.26)';draw.fillRect(x,y,d.width*info.tileSize*info.zoom,d.height*info.tileSize*info.zoom);
  }
}
export async function activate(ctx){
  state={ctx,data:defaultData(),selected:'',mode:'passage',host:null,readError:null,
    images:new Map(),writer:Promise.resolve(),undo:[],redo:[],serial:0,hover:null};
  try{state.data=await loadData();}catch(e){state.readError=String(e?.message||e);problem(e);}
  state.selected=state.data.definitions[0]?.id||'';
  ctx.ui.registerPanel({id:PANEL,title:'Objetos animados',defaultPosition:'right',defaultSize:{width:800,height:620},
    render(host){state.host=host;refresh();return()=>{if(state?.host===host)state.host=null;};}});
  ctx.menu.registerMenuItem({menu:'Mods',label:'Biblioteca de objetos animados',icon:'layers',
    handler:()=>ctx.ui.openPanel(PANEL)});
  ctx.tools.registerTool({id:TOOL,label:'Objeto animado',icon:'🎞',
    onActivate(){ctx.ui.openPanel(PANEL);},
    onDeactivate(){if(state)state.hover=null;},
    onPointerMove(e){if(state)state.hover={mapId:e.mapId,x:e.tileX,y:e.tileY};},
    onPointerDown(e){if(e.buttons&&!(e.buttons&1))return;
      void place(e.mapId,e.tileX,e.tileY,e.ctrlKey||e.altKey).catch(problem);}});
  const previewOverlay={id:'lbds-animated-props.preview',zOrder:12,render:drawOverlay};
  // The advanced overlay receives the editor's animation ticks when supported.
  if (ctx.ui.registerAdvancedOverlay) ctx.ui.registerAdvancedOverlay(previewOverlay);
  else ctx.ui.registerOverlay(previewOverlay);
  ctx.ui.registerContextMenuItem({context:'map-tile',label:'Borrar objeto animado aquí',
    handler:({mapId,tileX,tileY})=>void place(mapId,tileX,tileY,true).catch(problem),
    isEnabled:({mapId,tileX,tileY})=>!!placementAt(state.data,mapId,tileX,tileY)});
  ctx.bus.on('map.loaded',()=>refreshCounts());
}
export function deactivate(){
  if(!state)return;
  for(const c of state.images.values())if(c.url)URL.revokeObjectURL(c.url);
  state=null;
}
