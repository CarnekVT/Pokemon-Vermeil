// Map Design Studio v0.1.0 — planificacion y operaciones basicas de construccion.
// Conserva las capas y propiedades originales de los mapas de RPG Maker XP.
const DIR="Data/WorldDesign/MapDesign",ENV="Data/WorldDesign/Environment";
let state=null;
const COLORS=["#5AB3D4","#E6AF68","#8CD5A0","#B9A3EA","#E38EAB"];
const ZONE_TYPES=["Recorrido","Punto de interes","Habitat Pokemon","Viviendas","Actividad economica","Narrativa ambiental","Interior","Secreto"];
function el(tag,txt,cls){const e=document.createElement(tag);if(txt!==undefined)e.textContent=String(txt);if(cls)e.className=cls;return e;}
function path(id,dir=DIR){return dir+"/map_"+String(id).padStart(4,"0")+".json";}
function initial(id){return {schema:1,mapId:id,zones:[],updatedAt:null};}
function toast(msg,level="info"){state?.ctx.ui.showToast({message:msg,level,durationMs:4000});}
async function readFile(ctx,filepath,fallback){if(!await ctx.fs.projectExists(filepath))return fallback;return JSON.parse(await ctx.fs.readProjectFile(filepath));}
async function load(ctx,id){const data=await readFile(ctx,path(id),initial(id)),env=await readFile(ctx,path(id,ENV),{fields:{}});return {data:{...initial(id),...data,zones:Array.isArray(data.zones)?data.zones:[]},env};}
function dirty(){state.dirty=true;status();state.ctx.editor.requestRedraw();}
function status(){if(state?.status)state.status.textContent="Mapa "+state.id+" · "+(state.dirty?"Cambios del plano pendientes de guardar":"Plano guardado")+" · el terreno se edita con deshacer nativo";}
async function save(){const s=state;if(!s||s.saving)return;try{s.saving=true;await s.ctx.fs.projectMkdir("Data/WorldDesign");await s.ctx.fs.projectMkdir(DIR);s.data.updatedAt=new Date().toISOString();await s.ctx.fs.writeProjectFile(path(s.id),JSON.stringify(s.data,null,2)+"\n");s.dirty=false;status();toast("Plano de zonas guardado.");}catch(e){toast("Error al guardar plano: "+e.message,"error");}finally{s.saving=false;}}
function button(label,fn,cls=""){const b=el("button",label,"mds-btn "+cls);b.type="button";b.onclick=()=>{try{const v=fn();if(v&&v.catch)v.catch(e=>toast(e.message||String(e),"error"));}catch(e){toast(e.message||String(e),"error");}};return b;}
function textField(host,label,value,cb,multi=false){const w=el("label",undefined,"mds-field");w.append(el("span",label));const inp=el(multi?"textarea":"input");inp.className="mds-input";if(!multi)inp.type="text";else inp.rows=3;inp.value=value==null?"":String(value);inp.onchange=()=>cb(inp.value);w.append(inp);host.append(w);return inp;}
function numeric(host,label,value,cb,min=0,max=99999){const w=el("label",undefined,"mds-field");w.append(el("span",label));const inp=el("input");inp.type="number";inp.className="mds-input";inp.min=min;inp.max=max;inp.step=1;inp.value=value;inp.onchange=()=>cb(Math.max(min,Math.min(max,Math.floor(Number(inp.value)||0))));w.append(inp);host.append(w);return inp;}
function heading(host,title,desc){host.append(el("h2",title));if(desc)host.append(el("p",desc,"mds-muted"));}
function refresh(){const s=state;if(!s||!s.content)return;s.content.replaceChildren();s.tabs.forEach(([key,,b])=>b.classList.toggle("active",s.tab===key));
 if(s.tab==="zones")renderZones(s.content);
 if(s.tab==="builder")renderBuilder(s.content);
 if(s.tab==="assistant")renderAssistant(s.content);
 if(s.tab==="sources")renderSources(s.content);
 status();
}
function mapInfo(){return state.ctx.map.info(state.id)||{};}
function size(){const info=mapInfo();return {w:Math.floor(Number(info.width)||0),h:Math.floor(Number(info.height)||0)};}
function addZone(){const s=state,m=size(),z={label:"Nueva zona",type:"Punto de interes",x:Math.min(s.seedX||0,Math.max(0,m.w-1)),y:Math.min(s.seedY||0,Math.max(0,m.h-1)),w:Math.min(8,Math.max(1,m.w)),h:Math.min(6,Math.max(1,m.h)),color:COLORS[s.data.zones.length%COLORS.length],note:""};s.data.zones.push(z);dirty();refresh();}
function renderZones(host){
 heading(host,"Zonas y composicion","Los rectangulos son anotaciones de diseno. No modifican los tiles ni generan colisiones.");
 const info=mapInfo();host.append(el("p","Mapa: "+(info.name||state.id)+" · "+(info.width||"?")+" × "+(info.height||"?")+" tiles","mds-muted"));
 host.append(button("＋ Añadir zona",addZone,"primary"));
 state.data.zones.forEach((z,i)=>{const w=el("section",undefined,"mds-card");const title=el("div",undefined,"mds-line");title.append(el("strong",z.label||"Zona "+(i+1)),button("Eliminar",()=>{state.data.zones.splice(i,1);dirty();refresh();}));w.append(title);
 textField(w,"Etiqueta",z.label,v=>{z.label=v;dirty();refresh();});
 const kind=el("select",undefined,"mds-input");ZONE_TYPES.forEach(k=>{const o=el("option",k);o.value=k;kind.append(o);});kind.value=z.type;kind.onchange=()=>{z.type=kind.value;dirty();};w.append(el("small","Categoria"));w.append(kind);
 const row=el("div",undefined,"mds-grid");
 for(const [key,label] of [["x","X"],["y","Y"],["w","Ancho"],["h","Alto"]])numeric(row,label,z[key],v=>{z[key]=v;dirty();},key==="w"||key==="h"?1:0,9999);
 w.append(row);textField(w,"Contexto, actividad o intencion",z.note,v=>{z.note=v;dirty();},true);
 host.append(w);});
 if(!state.data.zones.length)host.append(el("p","Define zonas para representar barrios, habitaciones, microhabitats o puntos narrativos.","mds-muted"));
 host.append(button("Guardar plano de zonas",save,"primary"));
}
function builderChanges(b){
 const s=state,sz=size(),err=[];
 if(!sz.w||!sz.h)err.push("Dimensiones del mapa no disponibles.");
 if(!Number.isInteger(b.layer)||b.layer<0||b.layer>=(Array.isArray(s.ctx.map.layers(s.id))?s.ctx.map.layers(s.id).length:Number(s.ctx.map.layers(s.id))))err.push("Capa inexistente.");
 if(!Number.isInteger(b.tile)||b.tile<=0)err.push("Elige un tile ID mayor que cero.");
 if(b.w<1||b.h<1||b.w*b.h>12000)err.push("Area invalida o superior a 12000 tiles.");
 if(b.x<0||b.y<0||b.x+b.w>sz.w||b.y+b.h>sz.h)err.push("El rectangulo supera los limites del mapa.");
 const tiles=new Map(),touched=[];
 if(err.length)return {tiles,touched,err};
 for(let y=b.y;y<b.y+b.h;y++)for(let x=b.x;x<b.x+b.w;x++){
  if(b.mode==="borde"&&y>b.y&&y<b.y+b.h-1&&x>b.x&&x<b.x+b.w-1)continue;
  const old=s.ctx.map.readTile(s.id,b.layer,x,y);
  if(b.protect&&old!==0&&old!==null)continue;
  if(old===b.tile)continue;
  tiles.set(x+","+y,b.tile);touched.push({x,y});
 }
 return {tiles,touched,err};
}
function renderBuilder(host){
 heading(host,"Constructor de regiones","Pinta rectangulos o contornos con tiles existentes del mapa. Usa la API nativa de deshacer; no modifica propiedades de prioridad.");
 const s=state,b=s.builder,info=mapInfo();
 host.append(el("p","Mapa "+s.id+" · "+(info.width||"?")+" × "+(info.height||"?")+", "+s.ctx.map.layers(s.id).length+" capas","mds-muted"));
 const cols=el("div",undefined,"mds-grid");for(const [key,label] of [["x","X inicial"],["y","Y inicial"],["w","Ancho"],["h","Alto"],["layer","Capa (0, 1, 2...)"],["tile","Tile ID"]])numeric(cols,label,b[key],v=>{b[key]=v;refresh();},(key==="w"||key==="h")?1:0,99999);host.append(cols);
 const mode=el("select",undefined,"mds-input");for(const [val,label] of [["relleno","Rellenar superficie"],["borde","Dibujar contorno"]]){const o=el("option",label);o.value=val;mode.append(o);}mode.value=b.mode;mode.onchange=()=>{b.mode=mode.value;refresh();};host.append(mode);
 const p=el("label",undefined,"mds-check");const cb=el("input");cb.type="checkbox";cb.checked=b.protect;cb.onchange=()=>{b.protect=cb.checked;refresh();};p.append(cb,el("span","Proteger tiles ya ocupados"));host.append(p);
 host.append(button("Tomar Tile ID de X,Y en esta capa",()=>{try{const id=s.ctx.map.readTile(s.id,b.layer,b.x,b.y);if(!Number.isInteger(id)||id<=0)return toast("La casilla elegida esta vacia.","warn");b.tile=id;refresh();}catch(e){toast(e.message||String(e),"error");}}));
 const planned=builderChanges(b);
 host.append(el("div",planned.err.length?planned.err.join(" "):"Vista previa numérica: "+planned.tiles.size+" tiles se modificaran; "+(b.protect?"sin sobrescribir ocupados.":"pueden sobrescribir ocupados."),planned.err.length?"mds-error":"mds-muted"));
 host.append(button("Aplicar tiles al mapa",async()=>{
  const r=builderChanges(b);if(r.err.length)return toast(r.err.join(" "),"warn");
  if(!r.tiles.size)return toast("No hay tiles nuevos para colocar.","warn");
  if(!b.protect){const ok=await s.ctx.ui.confirmDestructive({title:"Confirmar sobrescritura",message:"Se van a sobrescribir hasta "+r.tiles.size+" tiles existentes. Puedes deshacerlo en Maker Studio.",confirmLabel:"Aplicar"});if(!ok)return;}
  s.ctx.map.batchWrite(s.id,b.layer,r.tiles,"Map Design Studio: "+b.mode);
  s.ctx.editor.requestRedraw();
  toast("Aplicados "+r.tiles.size+" tiles. Puedes deshacer con Ctrl+Z.");
 },"primary"));
 host.append(el("p","Los caminos y paredes con esquinas variables siguen necesitando un perfil de tileset; esta version no inventa IDs ni une autotiles arbitrarios.","mds-muted"));
}
function heuristicSuggestions(){
 const f=state.env?.fields||{},text=Object.values(f).join(" ").toLowerCase(),zones=state.data.zones;
 const out=[];function suggest(type,label,why){if(!zones.some(z=>z.type===type))out.push([type,label,why]);}
 suggest("Recorrido","Recorrido principal","Conecta las entradas y los puntos de interes sin obligar a usar todos los desvíos.");
 suggest("Punto de interes","Hito visual","Reserva una silueta o estructura reconocible que oriente al jugador.");
 if(/agric|granja|rural|cultivo|mercado/.test(text))suggest("Actividad economica","Espacio productivo","El lugar necesita donde trabajar, transportar, almacenar o intercambiar recursos.");
 if(/templo|ruina|antigu|histori|ceremoni/.test(text))suggest("Narrativa ambiental","Rastro del pasado","Representa las transformaciones y usos anteriores de la zona.");
 if(/bosque|costa|rio|río|montaña|selva|habitat/.test(text))suggest("Habitat Pokemon","Microhabitat","Distribuye fauna y flora segun agua, terreno y refugio.");
 if(/interior|vivienda|casa|taller|edificio|laboratorio/.test(text))suggest("Interior","Funcionalidad interior","Separa trabajo, descanso, circulacion y almacenamiento.");
 if(!f.bioma)out.push(["Contexto","Bioma pendiente","Completa la ficha de Environment Design Studio para orientar las sugerencias."]);
 if(!f.arquitectura)out.push(["Contexto","Arquitectura pendiente","Define materiales y escala antes de repetir edificios."]);
 return out;
}
function renderAssistant(host){
 heading(host,"Asistente de mapeado por reglas","Lee la ficha de Environment Design Studio para detectar funciones espaciales ausentes. No es IA generativa.");
 const fields=state.env?.fields||{};
 for(const k of ["nombre","tipo","bioma","arquitectura","ambiente","jugabilidad"]){const w=el("div",undefined,"mds-line");w.append(el("strong",k),el("span",fields[k]||"Sin definir en la ficha ambiental"));host.append(w);}
 const ideas=heuristicSuggestions();
 if(!ideas.length)host.append(el("p","La estructura basica de zonas esta cubierta. Revisa variedad y conexiones.","mds-muted"));
 ideas.forEach(([type,label,why])=>{const card=el("div",undefined,"mds-card");card.append(el("strong",label),el("p",why,"mds-muted"));if(type!=="Contexto")card.append(button("Crear zona sugerida",()=>{state.data.zones.push({label,type,x:0,y:0,w:6,h:6,color:COLORS[state.data.zones.length%COLORS.length],note:why});dirty();state.tab="zones";refresh();}));host.append(card);});
 host.append(button("Actualizar ficha ambiental",async()=>{state.env=await readFile(state.ctx,path(state.id,ENV),{fields:{}});refresh();toast("Contexto actualizado.");}));
}
function renderSources(host){
 heading(host,"Referencias externas","Busquedas opcionales abiertas en el navegador predeterminado con autorizacion. No hay descarga ni analisis automatizado.");
 const f=state.env?.fields||{};let q=(f.bioma||"")+" "+(f.arquitectura||"");
 const inp=textField(host,"Investigacion para el escenario",q,v=>q=v);
 const searches=[["Arquitectura y fotografia (Wikimedia)","https://commons.wikimedia.org/w/index.php?search="],["Contexto historico (Wikipedia)","https://es.wikipedia.org/w/index.php?search="],["Localizacion y mapas reales (OpenStreetMap)","https://www.openstreetmap.org/search?query="]];
 searches.forEach(([name,url])=>host.append(button(name,async()=>{if(!q.trim())return toast("Introduce una busqueda.","warn");await state.ctx.ui.openUrl(url+encodeURIComponent(q.trim()));})));
 const refs=Array.isArray(state.env?.references)?state.env.references:[];
 heading(host,"Fuentes del editor ambiental");
 refs.forEach(r=>{const div=el("div",undefined,"mds-card");div.append(el("strong",r.title||"Referencia"),el("p",r.note||r.url,"mds-muted"));div.append(button("Abrir referencia",()=>state.ctx.ui.openUrl(r.url)));host.append(div);});
 if(!refs.length)host.append(el("p","Añade bibliografia y enlaces en Environment Design Studio para consultarlos aqui.","mds-muted"));
}
function overlay(g,info){
 const s=state;if(!s||Number(s.id)!==Number(info.mapId))return;
 const scale=info.tileSize*info.zoom;if(!Number.isFinite(scale)||scale<=0)return;
 for(const z of s.data.zones){
  const x=(z.x*info.tileSize-info.viewportX)*info.zoom,y=(z.y*info.tileSize-info.viewportY)*info.zoom;
  const w=z.w*scale,h=z.h*scale;if(x>info.canvasWidth||y>info.canvasHeight||x+w<0||y+h<0)continue;
  g.save();g.strokeStyle=z.color||"#5AB3D4";g.lineWidth=2;g.setLineDash([6,4]);g.fillStyle="rgba(50,140,160,0.08)";g.fillRect(x,y,w,h);g.strokeRect(x,y,w,h);g.setLineDash([]);
  g.font="12px sans-serif";g.fillStyle=z.color||"#5AB3D4";g.fillText(z.label||"Zona",Math.max(0,x+4),Math.max(12,y+14));g.restore();
 }
}
function build(host){
 const s=state;host.replaceChildren();const css=el("style");css.textContent=[
 ".mds-root{color:var(--text-primary);background:var(--bg-primary);font-family:inherit;font-size:13px;padding:14px;display:flex;flex-direction:column;gap:12px}",
 ".mds-head,.mds-line{display:flex;justify-content:space-between;align-items:center;gap:14px}",
 ".mds-body{display:flex;align-items:flex-start;gap:12px}",
 ".mds-menu{width:180px;flex-shrink:0;display:flex;flex-direction:column;gap:7px}",
 ".mds-content{flex:1;min-width:0;max-height:68vh;overflow:auto;padding:4px 10px}",
 ".mds-content h2{font-size:17px}",
 ".mds-btn{padding:8px 11px;background:var(--bg-secondary);border:1px solid var(--border);border-radius:6px;color:var(--text-primary);cursor:pointer;text-align:left}",
 ".mds-btn:hover,.mds-btn.active{background:var(--accent-muted)}",
 ".mds-btn.primary{background:var(--accent);color:var(--accent-text)}",
 ".mds-muted{color:var(--text-secondary);white-space:pre-wrap;line-height:1.5}",
 ".mds-card{padding:12px;border-radius:8px;background:var(--bg-secondary);border:1px solid var(--border);margin:8px 0}",
 ".mds-card p{line-height:1.5}",
 ".mds-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:8px}",
 ".mds-field{display:flex;flex-direction:column;gap:5px;margin:8px 0}",
 ".mds-input{width:100%;box-sizing:border-box;color:var(--text-primary);background:var(--input-bg);border:1px solid var(--border);border-radius:6px;padding:8px;font:inherit}",
 ".mds-line{padding:8px 0;border-bottom:1px solid var(--border)}",
 ".mds-line span{max-width:65%;white-space:pre-wrap}",
 ".mds-check{display:flex;align-items:center;gap:8px;padding:9px 0}",
 ".mds-error{color:var(--danger);padding:8px}"
 ].join("\n");host.append(css);
 const root=el("div",undefined,"mds-root");host.append(root);const head=el("header",undefined,"mds-head");const title=el("div");title.append(el("h2","Map Design Studio"),el("small","Planificacion espacial · construccion por tiles · contexto ambiental"));head.append(title,button("Guardar plano",save,"primary"));root.append(head);
 const row=el("div",undefined,"mds-body"),nav=el("aside",undefined,"mds-menu"),main=el("main",undefined,"mds-content");s.tabs=[["zones","Zonas del mapa"],["builder","Constructor"],["assistant","Asistente contextual"],["sources","Referencias"]].map(([k,label])=>{const b=button(label,()=>{s.tab=k;refresh();});nav.append(b);return [k,label,b];});
 row.append(nav,main);root.append(row);s.content=main;s.status=el("small",undefined,"mds-muted");root.append(s.status);refresh();
}
async function open(ctx,point){
 if(state){toast("Map Design Studio ya esta abierto.");return;}
 const id=ctx.editor.activeMapId();if(id==null)return ctx.ui.showToast({message:"Abre un mapa antes de usar Map Design Studio.",level:"warn"});
 let loaded;try{loaded=await load(ctx,id);}catch(e){return ctx.ui.showToast({message:"Error de lectura: "+e.message,level:"error"});}
 const info=ctx.map.info(id)||{};
 const x=Math.min(Number(point?.x||0),Math.max(0,(info.width||1)-1)),y=Math.min(Number(point?.y||0),Math.max(0,(info.height||1)-1));
 state={ctx,id,seedX:x,seedY:y,...loaded,tab:point?"zones":"assistant",dirty:false,builder:{x,y,w:6,h:4,layer:ctx.editor.activeLayerIndex(),tile:0,mode:"relleno",protect:true},tabs:[],saving:false};
 const dlg=ctx.ui.showCustomDialog({title:"Map Design Studio · Mapa "+id,width:"94vw",height:"91vh",render(host){build(host);return()=>{state=null;ctx.editor.requestRedraw();};},
 onCloseRequest:async()=>{if(!state||!state.dirty)return dlg.close();const choice=await ctx.ui.showUnsavedChangesDialog({message:"Hay zonas sin guardar en Map Design Studio."});if(choice==="save"){await save();if(state&&!state.dirty)dlg.close();}else if(choice==="discard")dlg.close();}});
 state.dialog=dlg;ctx.editor.requestRedraw();
}
export function activate(ctx){
 ctx.menu.registerMenuItem({menu:"Mods",label:"Map Design Studio",icon:"map",handler:()=>open(ctx)});
 if(typeof ctx.ui.registerContextMenuItem==="function")ctx.ui.registerContextMenuItem({context:"map-tile",label:"Map Design Studio: planificar aqui",handler:info=>open(ctx,{x:info.tileX,y:info.tileY})});
 if(typeof ctx.ui.registerOverlay==="function")ctx.ui.registerOverlay({id:"com.carnekvt.map-design-studio.zones",zOrder:21,render:overlay});
}
export function deactivate(){if(state){try{state.dialog?.close();}catch(_){}state=null;}}
