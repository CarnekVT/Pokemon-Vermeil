// Environment Design Studio 0.1.0 — planificacion no destructiva.
// Los archivos JSON son auxiliares: no modifican MapXXX.rxdata.
const DIR = "Data/WorldDesign/Environment";
let app = null;
const FIELDS = [
 ["nombre","Nombre del lugar","text"],
 ["tipo","Tipo de escenario (interior, ruta, aldea, cueva...)","text"],
 ["bioma","Bioma y geografia","text"],
 ["clima","Clima y estacion","text"],
 ["sociedad","Habitantes, oficios y economia","textarea"],
 ["arquitectura","Arquitectura, materiales y tecnologias","textarea"],
 ["historia","Historia local y huellas del pasado","textarea"],
 ["ambiente","Sensaciones, sonidos y atmosfera","textarea"],
 ["paleta","Paleta de colores (texto o codigos hex)","text"],
 ["iluminacion","Iluminacion por horario y condiciones","textarea"],
 ["ecologia","Flora, fauna y habitats Pokemon","textarea"],
 ["jugabilidad","Recorrido, encuentros, interacciones y secretos","textarea"],
 ["hito","Punto de referencia visual memorable","text"],
 ["narrativa","Detalles de narrativa ambiental","textarea"],
 ["restricciones","Restricciones de arte, tileset y 2.5D","textarea"]
];
function el(tag,text,cls){const n=document.createElement(tag);if(text!==undefined)n.textContent=String(text);if(cls)n.className=cls;return n;}
function empty(id){return {schema:1,mapId:id,fields:{},references:[],ideas:[],updatedAt:null};}
function path(id){return DIR+"/map_"+String(id).padStart(4,"0")+".json";}
function show(msg,level="info"){try{app?.ctx.ui.showToast({message:msg,level,durationMs:3500});}catch(_){}}
function safeUrl(url){try{const u=new URL(url);return (u.protocol==="https:"||u.protocol==="http:")?u.href:null;}catch(_){return null;}}
async function read(ctx,id){const p=path(id);if(!await ctx.fs.projectExists(p))return empty(id);const d=JSON.parse(await ctx.fs.readProjectFile(p));return { ...empty(id), ...d, fields:{...(d.fields||{})},references:Array.isArray(d.references)?d.references:[],ideas:Array.isArray(d.ideas)?d.ideas:[]};}
async function save(){const s=app;if(!s||s.saving)return;try{s.saving=true;await s.ctx.fs.projectMkdir("Data/WorldDesign");await s.ctx.fs.projectMkdir(DIR);s.data.updatedAt=new Date().toISOString();await s.ctx.fs.writeProjectFile(path(s.id),JSON.stringify(s.data,null,2)+"\n");s.dirty=false;setStatus();show("Ficha ambiental guardada.");}catch(e){show("No se pudo guardar: "+e.message,"error");}finally{s.saving=false;}}
function setStatus(){if(!app?.status)return;app.status.textContent="Mapa "+app.id+" · "+(app.dirty?"Cambios sin guardar":"Guardado")+" · archivo externo JSON";}
function mark(){app.dirty=true;setStatus();}
function btn(label,fn,cls){const b=el("button",label,"eds-btn "+(cls||""));b.type="button";b.onclick=()=>{try{const r=fn();if(r&&r.catch)r.catch(e=>show(String(e.message||e),"error"));}catch(e){show(String(e.message||e),"error");}};return b;}
function input(value,fn,multi=false){const n=el(multi?"textarea":"input");n.className="eds-input";if(!multi)n.type="text";else n.rows=3;n.value=value||"";n.oninput=()=>{fn(n.value);mark();};return n;}
function section(host,title,desc){host.append(el("h2",title));if(desc)host.append(el("p",desc,"eds-muted"));}
function field(host,label,value,onChange,multi=false){const w=el("label",undefined,"eds-field");w.append(el("span",label));w.append(input(value,onChange,multi));host.append(w);}
function recommendations(d){
 const f=d.fields||{},txt=Object.values(f).join(" ").toLowerCase(),out=[];
 function add(topic,detail){out.push({topic,detail});}
 if(/nieve|nevado|frio|hielo|montaña|montana|winter|snow/.test(txt)){
  add("Clima y asentamiento","Piensa en refugios, almacenaje de provisiones, drenaje y caminos utilizables durante el invierno.");
  add("Composicion","Alterna superficies nevadas, puntos de abrigo y hitos visibles desde rutas principales.");
 }
 if(/desierto|arido|arena|calor|duna/.test(txt)){
  add("Recursos","Relaciona la poblacion con el acceso al agua, sombra, comercio y rutas entre refugios.");
  add("Atmósfera","Diferencia la luz de mediodia, el anochecer y las zonas protegidas del viento.");
 }
 if(/costa|mar|puerto|playa|rio|río|lago/.test(txt)){
  add("Actividad","Considera muelles, transporte, oficios, crecidas y limites seguros de acceso al agua.");
 }
 if(/interior|casa|vivienda|taller|laboratorio|edificio/.test(txt)){
  add("Interior coherente","Situa puertas, almacenamiento, iluminacion, zonas de trabajo y mobiliario segun las tareas de sus ocupantes.");
 }
 if(/templo|ruina|sagrado|historia|ceremonia/.test(txt)){
  add("Narrativa ambiental","Define que partes se conservaron, que zonas se reutilizaron y que huellas dejo cada epoca.");
 }
 if(/bosque|selva|pradera|rural|granja|agric/.test(txt)){
  add("Ecologia","Agrupa vegetacion por humedad y uso del suelo; distingue cultivos humanos de flora silvestre.");
 }
 add("Legibilidad del recorrido","Elige un hito visual, una entrada reconocible y un detalle secundario que invite a explorar.");
 add("Pokemon en contexto","Asigna al menos dos microhabitats y explica por que las especies estarian alli.");
 add("Camara 2.5D","Comprueba si copas, paredes y voladizos ocultarian caminos, eventos o al protagonista.");
 if(!f.sociedad)add("Contexto pendiente","Describe quien vive o trabaja aqui y como obtiene recursos.");
 if(!f.hito)add("Identidad visual pendiente","Elige un punto de referencia que el jugador recuerde sin consultar el mapa.");
 return out;
}
const SEARCH = [
 ["Wikimedia Commons","https://commons.wikimedia.org/w/index.php?search="],
 ["Wikipedia (ES)","https://es.wikipedia.org/w/index.php?search="],
 ["OpenStreetMap","https://www.openstreetmap.org/search?query="],
 ["Google Imagenes","https://www.google.com/search?tbm=isch&q="]
];
async function searchWeb(kind,phrase){const def=SEARCH.find(x=>x[0]===kind);if(!def||!phrase.trim())return show("Escribe un tema que quieras investigar.","warn");await app.ctx.ui.openUrl(def[1]+encodeURIComponent(phrase.trim()));}
function makeContextPage(host){section(host,"Identidad y contexto","Construye una ficha del lugar antes de distribuir los tiles. Todos los campos son editables.");
 for(const [key,label,kind] of FIELDS)field(host,label,app.data.fields[key],v=>app.data.fields[key]=v,kind==="textarea");
 host.append(btn("Guardar ficha",save,"primary"));
}
function makeIdeasPage(host){
 section(host,"Asistente local por reglas","No usa un modelo generativo ni inventa datos historicos: propone preguntas y consideraciones de diseno a partir de la ficha.");
 const proposals=recommendations(app.data);
 for(const item of proposals){const card=el("div",undefined,"eds-card");card.append(el("strong",item.topic),el("p",item.detail));card.append(btn("Guardar como idea",()=>{app.data.ideas.push(item.topic+": "+item.detail);mark();renderPage();}));host.append(card);}
 section(host,"Ideas guardadas");
 if(!app.data.ideas.length)host.append(el("p","Aun no hay ideas guardadas.","eds-muted"));
 app.data.ideas.forEach((idea,i)=>{const w=el("div",undefined,"eds-line");w.append(el("span",idea),btn("Quitar",()=>{app.data.ideas.splice(i,1);mark();renderPage();}));host.append(w);});
}
function makeSourcesPage(host){
 section(host,"Investigacion con fuentes","Las busquedas se abren en tu navegador, con confirmacion de Maker Studio. No se descargan ni verifican automaticamente.");
 let query=app.data.fields.bioma||app.data.fields.tipo||"",engine=SEARCH[0][0];
 const q=input(query,v=>query=v);q.placeholder="Ej.: viviendas campesinas de montaña y almacenaje";host.append(q);
 const select=el("select",undefined,"eds-input");SEARCH.forEach(s=>{const o=el("option",s[0]);o.value=s[0];select.append(o);});select.onchange=()=>engine=select.value;host.append(select);
 host.append(btn("Buscar referencias en la web",()=>searchWeb(engine,query),"primary"));
 section(host,"Fuentes documentadas","Añade la URL y una nota sobre su relevancia; no guardes imagenes ajenas como propias.");
 let title="",url="",note="";
 field(host,"Nombre o tema de la fuente","",v=>title=v);
 field(host,"URL de la fuente","",v=>url=v);
 field(host,"Observacion / que demuestra","",v=>note=v,true);
 host.append(btn("Agregar referencia",()=>{const clean=safeUrl(url);if(!clean)return show("URL http(s) invalida.","warn");app.data.references.push({title:title.trim()||clean,url:clean,note:note.trim()});mark();renderPage();}));
 app.data.references.forEach((r,i)=>{const w=el("div",undefined,"eds-card");w.append(el("strong",r.title||r.url),el("p",r.note||"Sin nota"));const actions=el("div",undefined,"eds-actions");actions.append(btn("Abrir",()=>app.ctx.ui.openUrl(r.url)),btn("Quitar",()=>{app.data.references.splice(i,1);mark();renderPage();}));w.append(actions);host.append(w);});
}
function makeOverview(host){
 section(host,"Mapa "+app.id+": "+(app.data.fields.nombre||app.mapName||"sin nombre"),"Vista general antes de abrir el constructor de mapas.");
 const keys=["tipo","bioma","clima","sociedad","arquitectura","historia","ambiente","jugabilidad","hito"];
 keys.forEach(k=>{const f=FIELDS.find(x=>x[0]===k);const w=el("div",undefined,"eds-line");w.append(el("strong",f[1]),el("span",app.data.fields[k]||"Sin definir"));host.append(w);});
 section(host,"Comprobacion rapida");
 const missing=keys.filter(k=>!(app.data.fields[k]||"").trim());host.append(el("p",missing.length?"Campos que puedes desarrollar: "+missing.map(k=>FIELDS.find(x=>x[0]===k)[1]).join(", "):"Todos los apartados basicos tienen contenido.","eds-muted"));
 host.append(btn("Abrir asistente de ideas",()=>{app.tab="ideas";renderPage();}));
}
function renderPage(){
 const s=app;if(!s||!s.content)return;s.content.replaceChildren();
 s.tabs.forEach(([key,,button])=>button.classList.toggle("active",key===s.tab));
 if(s.tab==="overview")makeOverview(s.content);
 if(s.tab==="context")makeContextPage(s.content);
 if(s.tab==="ideas")makeIdeasPage(s.content);
 if(s.tab==="sources")makeSourcesPage(s.content);
}
function build(host){
 const s=app;host.replaceChildren();const style=el("style");style.textContent=[
 ".eds-root{color:var(--text-primary);background:var(--bg-primary);font:13px inherit;display:flex;flex-direction:column;min-height:100%;gap:10px;padding:14px}",
 ".eds-row{display:flex;gap:10px;align-items:flex-start;min-height:0;flex:1}",
 ".eds-nav{width:190px;flex-shrink:0;display:flex;flex-direction:column;gap:7px}",
 ".eds-page{flex:1;min-width:0;padding:4px 12px 12px;max-height:68vh;overflow:auto}",
 ".eds-btn{cursor:pointer;padding:8px 10px;border:1px solid var(--border);border-radius:6px;background:var(--bg-secondary);color:var(--text-primary);text-align:left}",
 ".eds-btn:hover,.eds-btn.active{background:var(--accent-muted)}",
 ".eds-btn.primary{background:var(--accent);color:var(--accent-text)}",
 ".eds-muted{color:var(--text-secondary);line-height:1.5}",
 ".eds-field{display:flex;flex-direction:column;gap:5px;margin:11px 0}",
 ".eds-input{width:100%;box-sizing:border-box;padding:9px;color:var(--text-primary);border:1px solid var(--border);border-radius:6px;background:var(--input-bg);font:inherit}",
 ".eds-card{border:1px solid var(--border);border-radius:8px;padding:12px;margin:8px 0;background:var(--bg-secondary)}",
 ".eds-card p{white-space:pre-wrap;line-height:1.5}",
 ".eds-line{display:flex;justify-content:space-between;gap:18px;padding:10px;border-bottom:1px solid var(--border)}",
 ".eds-line span{white-space:pre-wrap;max-width:65%}",
 ".eds-actions{display:flex;gap:8px}",
 ".eds-header{display:flex;align-items:center;justify-content:space-between;gap:16px}",
 ".eds-page h2{font-size:17px;margin:15px 0 5px}"
 ].join("\n");host.append(style);
 const root=el("div",undefined,"eds-root");host.append(root);
 const header=el("div",undefined,"eds-header");const heading=el("div");heading.append(el("h2","Environment Design Studio"),el("small","Identidad · cultura · ecologia · atmosfera · fuentes"));header.append(heading,btn("Guardar",save,"primary"));root.append(header);
 const row=el("div",undefined,"eds-row"),nav=el("aside",undefined,"eds-nav"),main=el("main",undefined,"eds-page");
 s.tabs=[["overview","Resumen"],["context","Ficha del entorno"],["ideas","Asistente local"],["sources","Fuentes en linea"]].map(([k,label])=>{const b=btn(label,()=>{s.tab=k;renderPage();});nav.append(b);return [k,label,b];});
 row.append(nav,main);root.append(row);s.content=main;s.status=el("small",undefined,"eds-muted");root.append(s.status);setStatus();renderPage();
}
async function open(ctx){
 if(app){show("El editor ambiental ya esta abierto.");return;}
 const id=ctx.editor.activeMapId();if(id==null)return ctx.ui.showToast({message:"Abre un mapa antes de iniciar Environment Design Studio.",level:"warn"});
 let data;try{data=await read(ctx,id);}catch(e){return ctx.ui.showToast({message:"No se pudo leer el contexto: "+e.message,level:"error"});}
 const info=ctx.map.info(id)||{};
 app={ctx,id,data,mapName:info.name||"",dirty:false,tab:"overview",saving:false,tabs:[]};
 const dlg=ctx.ui.showCustomDialog({title:"Environment Design Studio · Mapa "+id,width:"94vw",height:"90vh",
 render(host){build(host);return()=>{app=null;};},
 onCloseRequest:async()=>{if(!app)return dlg.close();if(!app.dirty)return dlg.close();
  const choice=await ctx.ui.showUnsavedChangesDialog({message:"Hay cambios sin guardar en la ficha ambiental."});
  if(choice==="save"){await save();if(app&&!app.dirty)dlg.close();}
  else if(choice==="discard")dlg.close();
 }});
 app.dialog=dlg;
}
export function activate(ctx){
 ctx.menu.registerMenuItem({menu:"Mods",label:"Environment Design Studio",icon:"leaf",handler:()=>open(ctx)});
}
export function deactivate(){if(app){try{app.dialog?.close();}catch(_){}app=null;}}
