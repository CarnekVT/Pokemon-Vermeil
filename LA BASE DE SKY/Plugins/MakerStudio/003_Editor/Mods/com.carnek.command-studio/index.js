import { NATIVE } from "./catalog.js";
import { WIKI, WIKI_REFERENCES, buildWiki } from "./wiki-catalog.js";
import { scanProject, buildMethodCode, defaultParameterValue, SUPPORTED_TYPES } from "./source-index.js";
import { NATIVE_FIELDS, NATIVE_SIMPLE, compileNative } from "./native-builder.js";
import {loadPBS,classifySymbolHint} from "./pbs-index.js";

const PANEL="com.carnek.command-studio.panel";
const CSS=String.raw`
.cs3{height:100%;min-height:0;display:flex;flex-direction:column;background:var(--bg-primary,#101723);color:var(--text-primary,#dae3ee);font:12px/1.45 system-ui,sans-serif}
.cs3 *{box-sizing:border-box}.cs3 header{padding:14px 18px;display:flex;align-items:center;gap:10px;border-bottom:1px solid var(--border,#324359)}
.cs3 h2{margin:0;font-size:18px}.cs3 small,.cs3 .subtle{color:var(--text-secondary,#9caec2);font-size:11px}
.cs3 .brand{height:35px;width:35px;border-radius:9px;background:#334d68;display:grid;place-items:center;font-size:19px}
.cs3 button,.cs3 select,.cs3 input,.cs3 textarea{font:inherit;color:inherit}
.cs3 button{cursor:pointer}.cs3 button:disabled{opacity:.45;cursor:not-allowed}
.cs3 .btn,.cs3 .field,.cs3 .select,.cs3 .textarea{border:1px solid var(--border,#334357);border-radius:7px;background:var(--bg-secondary,#1d2a3b);padding:8px 10px;outline:none}
.cs3 .btn:hover,.cs3 .field:focus,.cs3 .select:focus,.cs3 .textarea:focus{border-color:var(--accent,#5a9ed9)}
.cs3 .btn.primary,.cs3 .tab.active{background:var(--accent,#3b88d4);border-color:var(--accent,#3b88d4);color:var(--text-on-accent,#fff);font-weight:700}
.cs3 .tabs{display:flex;gap:6px;align-items:center;flex-wrap:wrap;padding:10px 18px;border-bottom:1px solid var(--border,#324359)}
.cs3 .tab{padding:7px 12px;border-radius:7px;border:1px solid var(--border,#334357);background:transparent}
.cs3 .toolbar{display:grid;grid-template-columns:minmax(240px,1fr) minmax(155px,250px) auto;gap:8px;padding:10px 18px;border-bottom:1px solid var(--border,#324359)}
.cs3 .field,.cs3 .select,.cs3 .textarea{width:100%;min-width:0}.cs3 .textarea{resize:vertical;min-height:95px;font:12px/1.5 ui-monospace,Consolas,monospace;tab-size:2}
.cs3 .layout{display:grid;grid-template-columns:minmax(275px,35%) minmax(400px,65%);min-height:0;flex:1}
.cs3 .results{overflow:auto;padding:12px;min-height:0;border-right:1px solid var(--border,#324359)}
.cs3 .result{display:block;width:100%;text-align:left;color:inherit;border-radius:8px;padding:10px;margin-bottom:6px;border:1px solid var(--border,#334357);background:var(--bg-secondary,#1b2736)}
.cs3 .result:hover{border-color:var(--accent,#3b88d4)}
.cs3 .result.current{border-color:var(--accent,#3b88d4);background:color-mix(in srgb,var(--accent,#3b88d4) 15%,var(--bg-secondary,#1b2736))}
.cs3 .resulttop,.cs3 .row{display:flex;gap:8px;align-items:center;justify-content:space-between}
.cs3 .tag{font-size:10px;border:1px solid var(--border,#334357);padding:2px 6px;border-radius:5px;white-space:nowrap}
.cs3 .inspector{overflow:auto;padding:18px 22px;min-height:0}
.cs3 h3{font-size:17px;margin:0 0 6px}.cs3 h4{font-size:12px;margin:14px 0 7px}
.cs3 .note{font-size:11px;padding:10px 12px;border:1px solid var(--border,#334357);background:var(--bg-secondary,#1b2736);border-radius:8px;margin:8px 0;color:var(--text-secondary,#a7b5c6)}
.cs3 .warning{color:#eeb56f}.cs3 .error{color:#fd8989}
.cs3 .form{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:10px;padding:12px 0}
.cs3 .entry{min-width:0}.cs3 .entry.wide{grid-column:1/-1}.cs3 .entry label{display:block;font-size:11px;color:var(--text-secondary,#a7b5c6);margin-bottom:4px}
.cs3 .argtop{display:flex;align-items:center;gap:6px;justify-content:space-between;margin-bottom:5px}
.cs3 .argcontrols{display:grid;grid-template-columns:minmax(0,1fr) 115px;gap:6px}
.cs3 .copyrow{display:flex;align-items:center;gap:8px;flex-wrap:wrap;margin-top:9px}
.cs3 .footer{font-size:11px;color:var(--text-secondary,#9caec2);border-top:1px solid var(--border,#324359);padding:9px 16px;display:flex;gap:14px;justify-content:space-between}
.cs3 .code{min-height:115px}.cs3 .refgrid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:7px}
.cs3 a{color:var(--accent,#68a8fa)}.cs3 .metric{font:11px/1.35 ui-monospace,Consolas,monospace;white-space:pre-wrap}
.cs3 .mini{padding:4px 7px;font-size:11px}
.cs3 .notice{padding:10px 18px;font-size:11px;border-bottom:1px solid var(--border,#324359)}
.cs3 .fixed{flex-shrink:0}
@media(max-width:850px){.cs3 .layout{grid-template-columns:1fr}.cs3 .results{max-height:230px;border-right:0;border-bottom:1px solid var(--border,#324359)}.cs3 .toolbar{grid-template-columns:minmax(160px,1fr) minmax(100px,160px)}.cs3 .toolbar .scan{grid-column:1/-1}}
`;
const mk=(tag,text,cls)=>{const n=document.createElement(tag);if(text!==undefined&&text!==null)n.textContent=String(text);if(cls)n.className=cls;return n;};
const esc=s=>String(s??"").replace(/[&<>"]/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;"}[c]));
const prefix=(item)=>item.kind==="native"?"RMXP":item.kind==="wiki"?"WIKI":item.scope==="global"?"GLOBAL":item.scope==="singleton"?"MÓDULO":"INTERNO";
let CACHED=null;
let PBS_CACHED=null;
function toast(ctx,msg,level="info"){try{ctx.ui.showToast({message:msg,level});}catch(_){}}
async function clipboard(ctx,content){
 try{
  if(ctx.clipboard?.writeText){await ctx.clipboard.writeText(content);return true;}
  if(ctx.clipboard?.write){await ctx.clipboard.write(content);return true;}
  if(navigator.clipboard?.writeText){await navigator.clipboard.writeText(content);return true;}
 }catch(_){}
 return false;
}
function miniButton(text,click){const b=mk("button",text,"btn mini");b.type="button";b.onclick=click;return b;}
function mkField(label,value,type="text",choices=null){
 const box=mk("div",null,"entry"),l=mk("label",label),n=mk(type==="textarea"?"textarea":choices?"select":"input",null,type==="textarea"?"textarea":choices?"select":"field");
 if(type==="textarea"){n.value=String(value??"");n.rows=3;n.spellcheck=false;}
 else if(choices){for(const [val,title] of choices){const o=mk("option",title);o.value=val;n.append(o);}n.value=String(value??"");}
 else{n.type=type;n.value=String(value??"");}
 box.append(l,n);return{box,input:n};
}
function getNativeTitle(item){return item.title+" · "+item.code;}
function getGroup(item){return item.group||item.category||"Sin categoría";}
function makeScriptCommands(text){
 return String(text).replace(/\r/g,"").split("\n").map((line,i)=>({code:i?655:355,indent:0,parameters:[line]}));
}
function makeTextCommands(text,comment=false){
 return String(text).replace(/\r/g,"").split("\n").map((line,i)=>({code:comment?(i?408:108):(i?401:101),indent:0,parameters:[line]}));
}
const NATIVE_TIPS={101:"Texto multilinea y códigos como \\\\PN, \\\\v[1].",102:"Las ramas resultantes requieren indentación al insertarse en un evento real.",111:"Rama condicional de prueba Ruby.",112:"Bucle con código de cierre; inserta sus operaciones dentro.",355:"Script Ruby, continuaciones con 655.",209:"Ruta de movimiento contiene objetos de clases RMXP; revisa su serialización."};
const TOKEN=[["Nombre jugador","\\PN"],["Jugador minúsculas","\\pn"],["Pokémon","\\Pokemon"],["Variable","\\v[1]"],["Azul","\\b"],["Rojo","\\r"],["Salto de línea","\\n"],["Cara","\\f[NAME]"],["Ventana de oro","\\G"],["Velocidad","\\ts[]"]];
function mount(ctx,host){
 host.innerHTML=`<style>${CSS}</style><div class="cs3">
 <header><div class="brand">⌘</div><div><h2>Command Studio</h2><small>Enciclopedia maestra · Pokémon Essentials 21.1 / LA BASE DE SKY</small></div>
 <div style="flex:1"></div><span class="tag">v0.3.0</span></header>
 <div class="tabs" data-tabs>
 <button class="tab active" data-tab="all">Todo</button><button class="tab" data-tab="wiki">Wiki LBDS</button>
 <button class="tab" data-tab="source">Código del proyecto</button><button class="tab" data-tab="native">Comandos RMXP</button><button class="tab" data-tab="docs">Documentación</button></div>
 <div class="toolbar"><input data-search class="field" placeholder="Buscar por nombre, función, script, categoría o palabra clave..." aria-label="Buscar comandos"/>
 <select data-filter class="select" aria-label="Filtrar categoría"><option value="">Todas las categorías</option></select>
 <button class="btn scan" data-index>Reindexar scripts</button></div>
 <div class="notice" data-progress>Catálogo base disponible. Preparando indexación del proyecto…</div>
 <div class="layout"><aside class="results" data-results></aside><main class="inspector" data-inspector></main></div>
 <footer class="footer"><span data-counts>—</span><span data-status>Sin cambios en los archivos del proyecto.</span></footer>
 </div>`;
 const dom={root:host.querySelector(".cs3"),tabs:host.querySelector("[data-tabs]"),search:host.querySelector("[data-search]"),
 filter:host.querySelector("[data-filter]"),results:host.querySelector("[data-results]"),inspector:host.querySelector("[data-inspector]"),
 progress:host.querySelector("[data-progress]"),index:host.querySelector("[data-index]"),counts:host.querySelector("[data-counts]"),
 status:host.querySelector("[data-status]")};
 let tab="all",selected=null,index=CACHED,scanJob=null,destroyed=false;
 let pbs=PBS_CACHED;
 const suggestionLists={};
 for(const name of ["pokemon","items","moves","abilities","trainer_types"]){
   const list=mk("datalist");list.id="cs3-pbs-"+name;dom.root.append(list);suggestionLists[name]=list;
 }
 function populatePBS(){
   if(!pbs)return;
   for(const [kind,list]of Object.entries(suggestionLists)){
     list.replaceChildren();
     for(const id of pbs.ids[kind]||[]){
       const option=mk("option");option.value=id;list.append(option);
     }
   }
 }
 populatePBS();
 let renderCount=0,selectedCode="",selectedJSON="";
 const catalog=()=>[...WIKI,...NATIVE,...(index?.methods||[])];
 const shown=()=>catalog().filter(item=>(tab==="all"||(tab==="wiki"&&item.kind==="wiki")||(tab==="source"&&item.kind==="source")||(tab==="native"&&item.kind==="native")));
 function updateCounts(){
  dom.counts.textContent=WIKI.length+" plantillas Wiki · "+NATIVE.length+" códigos RMXP · "+(index?.methods.length||0)+" métodos locales";
 }
 function refreshFilters(){
  const old=dom.filter.value;dom.filter.replaceChildren();
  const z=mk("option","Todas las categorías");z.value="";dom.filter.append(z);
  const groups=[...new Set(shown().map(getGroup))].sort((a,b)=>a.localeCompare(b));
  for(const item of groups){const o=mk("option",item);o.value=item;dom.filter.append(o);}
  dom.filter.value=groups.includes(old)?old:"";
 }
 function refreshList(){
  updateCounts();
  if(tab==="docs"){renderDocs();return;}
  const q=dom.search.value.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g,""),category=dom.filter.value;
  const match=item=>getGroup(item)===category||!category;
  const entries=shown().filter(x=>match(x)&&[x.title,x.name,getGroup(x),x.code,x.note,x.signature,x.sourcePath,x.aliases]
    .map(x=>String(x??"")).join(" ").toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g,"").includes(q));
  dom.results.replaceChildren();
  const info=mk("div",entries.length+" coincidencia(s)","subtle");info.style.margin="0 0 10px";dom.results.append(info);
  const items=entries.slice(0,250);
  for(const item of items){
   const button=mk("button",null,"result"+(selected?.id===item.id?" current":""));button.type="button";
   const row=mk("div",null,"resulttop");row.append(mk("strong",item.title),mk("span",prefix(item),"tag"));button.append(row);
   let subtitle=getGroup(item);
   if(item.kind==="source")subtitle+=" · "+item.sourcePath.split("/").pop()+":"+item.line;
   if(item.kind==="native")subtitle+=" · #"+item.code;
   button.append(mk("small",subtitle));
   button.onclick=()=>open(item);dom.results.append(button);
  }
  if(entries.length>250)dom.results.append(mk("p","Se muestran 250 de "+entries.length+". Escribe para acotar sin limitar la indexación.","note"));
  if(!entries.length)dom.results.append(mk("p",tab==="source"&&!index?"Indexa el proyecto para obtener los métodos Ruby.":"No hay resultados para este filtro.","note"));
 }
 function status(message){dom.status.textContent=message;}
 function formField(parent,label,value,type="text",choices){
  const item=mkField(label,value,type,choices);
  if(!choices&&type!=="textarea"){
    const kind=classifySymbolHint(label);
    if(kind)item.input.setAttribute("list","cs3-pbs-"+kind);
  }
  parent.append(item.box);return item.input;
 }
 function codeArea(parent){
  const l=mk("div","Vista previa editable de código","subtle");l.style.marginTop="12px";
  const area=mk("textarea",null,"textarea code");area.rows=8;area.spellcheck=false;
  parent.append(l,area);return area;
 }
 function copyActions(parent,area,jsonFn){
  const row=mk("div",null,"copyrow"),copy=mk("button","Copiar código Ruby / texto","btn primary"),copyJSON=mk("button","Copiar comandos RMXP (JSON)","btn");
  row.append(copy,copyJSON);parent.append(row);
  copy.onclick=async()=>{
   const value=area.value;
   if(!value.trim()){toast(ctx,"No hay texto que copiar","warn");return;}
   const ok=await clipboard(ctx,value);toast(ctx,ok?"Código copiado al portapapeles":"Error al copiar",ok?"info":"error");
  };
  copyJSON.onclick=async()=>{
   try{const value=jsonFn();const ok=await clipboard(ctx,JSON.stringify(value,null,2));toast(ctx,ok?"Comandos en JSON copiados":"No se pudo copiar",ok?"info":"error");}
   catch(e){toast(ctx,"Comando incompleto: "+e.message,"error");}
  };
  const note=mk("p","El JSON de RPG::EventCommand no se pega en el campo Script: requiere un importador de eventos. Este panel no sobrescribe mapas.","note");
  parent.append(note);
  return{copy,copyJSON};
 }
 function renderWiki(item,parent){
  parent.append(mk("h3",item.title),mk("div",item.group+" · Plantilla documentada","subtle"));
  const a=mk("a","Abrir documentación original ↗");a.href=item.source;a.target="_blank";a.rel="noopener noreferrer";parent.append(a);
  if(item.note)parent.append(mk("div",item.note,"note"));
  const fields=mk("div",null,"form");parent.append(fields);
  const inputs={};for(const def of item.args){const [name,label,type,value]=def;
    inputs[name]=formField(fields,label,value,type==="integer"?"number":"text");
    if(type==="boolean"){inputs[name].type="text";inputs[name].setAttribute("list","cs3-boolean");}
    if(type==="symbol"){inputs[name].placeholder="ID interno, por ejemplo PIKACHU";inputs[name].dataset.symbol="1";}
  }
  const area=codeArea(parent);const error=mk("div","","error");parent.append(error);
  function build(){try{error.textContent="";area.value=buildWiki(item,Object.fromEntries(Object.entries(inputs).map(([k,v])=>[k,v.value])));status("Vista previa lista; nada se ejecuta automáticamente.");}
   catch(e){error.textContent=e.message;area.value="";}}
  for(const v of Object.values(inputs))v.addEventListener("input",build);
  build();
  copyActions(parent,area,()=>makeScriptCommands(area.value));
 }
 function renderSource(item,parent){
  parent.append(mk("h3",item.title),mk("div",item.group+" · "+item.scope+" · Firma detectada","subtle"));
  parent.append(mk("div",item.sourcePath+" · línea "+item.line+" · def "+item.name+"("+item.signature+")","note"));
  parent.append(mk("div",item.note+"\nLa exploración indexa funciones, pero no determina automáticamente si son seguras como comandos de evento.","note"));
  const form=mk("div",null,"form");
  parent.append(form);
  let receiverInput=null;
  if(item.scope==="instance"||item.scope==="singleton"&&!item.owner){
   receiverInput=formField(form,"Receptor Ruby (instancia / objeto)",item.scope==="instance"?"mi_objeto":"MiModulo","text");
  }
  const rows={};
  for(const p of item.parameters){
   if(p.kind==="block"){parent.append(mk("p","&"+p.name+" es un bloque Ruby; modifícalo manualmente en la vista previa.","subtle"));continue;}
   const wrap=mk("div",null,"entry wide"),top=mk("div",null,"argtop"),lab=mk("label",p.name+(p.kind==="keyword"?" (clave)":p.kind==="rest"?" (*args)":""));
   top.append(lab);const use=mk("input");use.type="checkbox";use.checked=!p.optional;use.title="Incluir parámetro";
   if(p.optional){top.append(mk("small","Incluir","subtle"),use);}
   wrap.append(top);
   const controls=mk("div",null,"argcontrols"),value=mk("input",null,"field");value.value=defaultParameterValue(p);
   const kind=mk("select",null,"select");
   for(const type of SUPPORTED_TYPES){const option=mk("option",type);option.value=type;kind.append(option);}
   kind.value=p.type;controls.append(value,kind);wrap.append(controls);form.append(wrap);
   rows[p.name]={use,value,kind};
  }
  const area=codeArea(parent),error=mk("p","","error");parent.append(error);
  function update(){
   try{
    const pRows={};
    for(const [name,row] of Object.entries(rows))pRows[name]={enabled:row.use.checked,value:row.value.value,type:row.kind.value};
    area.value=buildMethodCode(item,pRows,receiverInput?.value||"");
    error.textContent="";
    status("Método indexado. Revisa el receptor, los valores y su contexto.");
   }catch(e){area.value="";error.textContent=e.message;}
  }
  for(const row of Object.values(rows))for(const el of [row.use,row.value,row.kind])el.addEventListener("input",update);
  if(receiverInput)receiverInput.addEventListener("input",update);
  update();copyActions(parent,area,()=>makeScriptCommands(area.value));
 }
 function renderNative(item,parent){
  parent.append(mk("h3",getNativeTitle(item)),mk("div",getGroup(item)+" · Registro original RPG Maker XP","subtle"));
  if(item.internal)parent.append(mk("p","Comando estructural o de continuación: no se debe insertar por separado.","note warning"));
  if(NATIVE_TIPS[item.code])parent.append(mk("p",NATIVE_TIPS[item.code],"note"));
  const form=mk("div",null,"form");parent.append(form);
  let values={},custom=null;
  if(item.code===101||item.code===108||item.code===355){
   const isScript=item.code===355;values[isScript?"script":"text"]=formField(form,isScript?"Código Ruby":"Texto editable",
    isScript?'pbMessage(_INTL("¡Hola!"))':"¡Hola, \\\\PN!","textarea");
   values[isScript?"script":"text"].rows=8;
   if(item.code===101){
    const tools=mk("div",null,"copyrow");
    for(const [label,tok] of TOKEN){
     const b=miniButton(label,()=>{const f=values.text;f.setRangeText(tok,f.selectionStart,f.selectionEnd,"end");f.dispatchEvent(new Event("input"));f.focus();});
     tools.append(b);
    }
    parent.append(tools);
   }
  }else if(Object.prototype.hasOwnProperty.call(NATIVE_FIELDS,item.code)){
   for(const [name,label,type,value,choices] of NATIVE_FIELDS[item.code]){
    const control=formField(form,label,value,type==="textarea"?"textarea":type==="select"?"text":type==="number"?"number":"text",type==="select"?choices:null);
    values[name]=control;
   }
  }else if(!NATIVE_SIMPLE.has(item.code)){
   const header=mk("div","Parámetros RMXP no normalizados para este código. Puedes utilizar el constructor avanzado JSON.","note");parent.append(header);
   custom=formField(form,"Array JSON de parámetros RMXP","[]","textarea");custom.rows=5;
  }
  const error=mk("p","","error"),area=codeArea(parent);parent.append(error);
  let compiled=[];
  function update(){
   try{
    const v=Object.fromEntries(Object.entries(values).map(([name,el])=>[name,el.value]));
    compiled=compileNative(item.code,v,custom?.value||"");
    area.value=[101,108].includes(item.code)?String(v.text||""):item.code===355?String(v.script||""):JSON.stringify(compiled,null,2);
    area.dataset.pasteable=[101,108,355].includes(item.code)?"true":"false";
    error.textContent="";
   }catch(e){compiled=[];area.value="";error.textContent=e.message;}
  }
  for(const v of Object.values(values))v.addEventListener("input",update);
  custom?.addEventListener("input",update);update();
  const actions=copyActions(parent,area,()=>{
    if(area.dataset.pasteable==="true"){
      return item.code===355?makeScriptCommands(area.value):makeTextCommands(area.value,item.code===108);
    }
    return compiled;
  });
  if(![101,108,355].includes(item.code)){
   actions.copy.disabled=true;actions.copy.title="El comando RMXP no es código Ruby; utiliza Exportar EventCommand JSON.";
   parent.append(mk("div","Este comando es nativo RMXP. Exporta JSON: no lo pegues en el cuadro de Ruby.","note"));
  }
 }
 function renderDocs(){
  dom.inspector.replaceChildren();dom.results.replaceChildren();dom.results.append(mk("h3","Manual de LA BASE DE SKY"));
  dom.inspector.append(mk("h3","Documentación y cobertura"),mk("p","La wiki es una guía de referencia; el índice de código procede del proyecto que tengas abierto. La indexación enumera métodos, no certifica su disponibilidad en eventos.","note"));
  const metrics=mk("div",null,"metric");metrics.textContent=index?
    "Métodos: "+index.report.found+"\nArchivos .rb leídos: "+index.report.read+"\nRutas exploradas: "+index.report.scanned+"\nErrores: "+index.report.errors.length+
    "\nCompleto sin errores: "+(index.report.complete?"Sí":"NO · revisar informe")+
    "\nTiempo de indexación: "+(index.report.elapsedMs/1000).toFixed(1)+" s":
    "Todavía no se han explorado todos los scripts del proyecto.";
  dom.inspector.append(metrics,mk("h4","Wiki oficial: categorías"));
  const grid=mk("div",null,"refgrid");
  for(const ref of WIKI_REFERENCES){const a=mk("a",ref.title+" ↗");a.href=ref.url;a.target="_blank";a.rel="noopener noreferrer";grid.append(a);}
  dom.inspector.append(grid);
  dom.inspector.append(mk("h4","Archivos no leídos / errores"));
  const log=mk("textarea",null,"textarea");log.readOnly=true;log.rows=6;log.value=index?.report.errors.length?index.report.errors.map(e=>e.path+" — "+e.error).join("\n"):"Sin incidencias registradas.";
  dom.inspector.append(log);
 }
 function open(item){
  selected=item;refreshList();dom.inspector.replaceChildren();
  if(item.kind==="wiki")renderWiki(item,dom.inspector);
  else if(item.kind==="source")renderSource(item,dom.inspector);
  else renderNative(item,dom.inspector);
 }
 function tabClick(next){
  tab=next;selected=null;dom.search.value="";dom.filter.value="";
  dom.tabs.querySelectorAll("[data-tab]").forEach(b=>b.classList.toggle("active",b.dataset.tab===tab));
  refreshFilters();refreshList();
  dom.inspector.replaceChildren();
  if(next==="docs")return;
  dom.inspector.append(mk("h3",next==="wiki"?"Plantillas de LA BASE DE SKY":next==="source"?"Funciones Ruby del proyecto":next==="native"?"Comandos RMXP":"Enciclopedia maestra"),
   mk("div",next==="source"?"Los métodos son detectados del código instalado, con argumentos editables. Esto incluye funciones internas que necesitan receptor/objeto correcto.":"Selecciona una entrada a la izquierda. Todas las salidas se generan como vista previa, sin ejecutar ni modificar archivos.","note"));
 }
 async function startScan(force){
  if(scanJob){scanJob.cancelled=true;dom.progress.textContent="Cancelando y preparando nueva exploración…";return;}
  if(index&&!force)return;
  scanJob={cancelled:false};const current=scanJob;
  dom.index.textContent="Cancelar indexación";dom.progress.textContent="Leyendo Data/Scripts y Plugins, incluyendo subcarpetas…";
  try{
   const res=await scanProject(ctx,summary=>{
    if(destroyed)return;dom.progress.textContent="Indexando "+summary.dir+" · "+summary.read+" archivos · "+summary.found+" métodos · "+summary.errors+" errores";
   },current);
   if(destroyed)return;
   if(!res.report.cancelled){index=res;CACHED=res;}
   dom.progress.textContent=res.report.cancelled?"Indexación cancelada.":
    "Índice: "+res.report.found+" métodos / "+res.report.read+" archivos Ruby · "+res.report.errors.length+" errores"+(res.report.complete?" · Lectura finalizada":" · Cobertura parcial");
   refreshFilters();refreshList();if(tab==="docs")renderDocs();
  }catch(e){dom.progress.textContent="Fallo al indexar: "+(e?.message||e);toast(ctx,"Error al indexar scripts","error");}
  finally{if(scanJob===current)scanJob=null;if(!destroyed)dom.index.textContent="Reindexar scripts";}
 }
 async function initPBS(){
    if(!pbs){
      try{
        pbs=await loadPBS(ctx);
        if(destroyed)return;
        PBS_CACHED=pbs;
        populatePBS();
      }catch(_){}
    }
 }
 dom.tabs.querySelectorAll("[data-tab]").forEach(b=>b.onclick=()=>tabClick(b.dataset.tab));
 dom.search.addEventListener("input",refreshList);dom.filter.addEventListener("change",refreshList);
 dom.index.onclick=()=>startScan(true);
 tabClick("all");
 initPBS();
 if(index){dom.progress.textContent="Índice cargado: "+index.report.found+" métodos de "+index.report.read+" archivos Ruby; "+index.report.errors.length+" errores.";}
 else startScan(false);
 return()=>{destroyed=true;if(scanJob)scanJob.cancelled=true;};
}
export function activate(ctx){
 ctx.ui.registerPanel({id:PANEL,title:"Command Studio",icon:"terminal",defaultPosition:"right",defaultSize:{width:1520,height:900},
  showInMenu:!(ctx.menu&&typeof ctx.menu.registerMenuItem==="function"),
  render(host){try{return mount(ctx,host);}catch(e){ctx.log?.error?.(e);host.textContent="Command Studio: "+(e?.message||e);return()=>{};}}
 });
 if(ctx.menu?.registerMenuItem){
  ctx.menu.registerMenuItem({menu:"Mods",label:"Command Studio",icon:"terminal",handler:()=>ctx.ui.openPanel(PANEL)});
  ctx.menu.registerMenuItem({menu:"Tools",label:"Command Studio",icon:"terminal",handler:()=>ctx.ui.openPanel(PANEL)});
 }
 if(ctx.commands?.register)ctx.commands.register("com.carnek.command-studio.open",()=>ctx.ui.openPanel(PANEL));
 ctx.log?.info?.("Command Studio v0.3.0: wiki, RMXP, Data/Scripts + Plugins");
}
