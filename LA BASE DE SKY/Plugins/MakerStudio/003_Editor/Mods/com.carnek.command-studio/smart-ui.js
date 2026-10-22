import {ACTIONS,BY_ID,CATEGORIES,defaults,buildAction,validate,smartSearch,SOURCES,ruby} from "./smart-core.js";
import {isCompatible,activeMapId,eventChoices,pageChoices,previewInsertion,applyInsertion} from "./event-writer.js";
import {WIKI,buildWiki} from "./wiki-catalog.js";
import {scanProject,buildMethodCode,defaultParameterValue} from "./source-index.js";
import {loadPBS,classifySymbolHint} from "./pbs-index.js";
let pendingFocus=null;
let focusHandler=null;
export function focusEvent(mapId,eventId){pendingFocus={mapId:Number(mapId),eventId:Number(eventId)};if(focusHandler)focusHandler();}
const CSS=String.raw`
.cs4{--cs4-border:var(--border,#354153);--cs4-bg:var(--bg-primary,#121b29);--cs4-panel:var(--bg-secondary,#1c2a3c);--cs4-soft:var(--text-secondary,#a0b1c7);--cs4-accent:var(--accent,#448cda);height:100%;min-height:0;display:flex;flex-direction:column;background:var(--cs4-bg);color:var(--text-primary,#e7edf5);font:13px/1.45 system-ui,sans-serif}
.cs4 *{box-sizing:border-box}.cs4 h2,.cs4 h3,.cs4 h4,.cs4 p{margin:0}.cs4 h2{font-size:18px}.cs4 h3{font-size:16px}.cs4 h4{font-size:13px}
.cs4 button,.cs4 input,.cs4 select,.cs4 textarea{font:inherit;color:inherit}
.cs4 button{cursor:pointer}.cs4 button:disabled{opacity:.45;cursor:not-allowed}.cs4 .btn,.cs4 input,.cs4 select,.cs4 textarea{background:var(--cs4-panel);border:1px solid var(--cs4-border);border-radius:7px;padding:8px 10px;outline:none}
.cs4 .btn:hover,.cs4 input:focus,.cs4 select:focus,.cs4 textarea:focus{border-color:var(--cs4-accent)}
.cs4 .btn.primary,.cs4 .navbtn.active{background:var(--cs4-accent);color:var(--text-on-accent,#fff);border-color:var(--cs4-accent);font-weight:700}
.cs4 .btn.ghost{background:transparent}.cs4 .btn.small{padding:5px 9px;font-size:11px}
.cs4 .toolbar{display:flex;align-items:center;gap:10px;padding:12px 18px;border-bottom:1px solid var(--cs4-border);flex-wrap:wrap}
.cs4 .mark{background:var(--cs4-accent);border-radius:8px;display:grid;place-items:center;width:36px;height:36px;color:white;font-size:22px;font-weight:700}
.cs4 .crumb{font-size:10px;color:var(--cs4-soft);letter-spacing:1.2px;font-weight:700}.cs4 .subtitle{font-size:11px;color:var(--cs4-soft)}
.cs4 .spacer{flex:1}.cs4 .tabs{display:flex;gap:5px;padding:9px 18px;border-bottom:1px solid var(--cs4-border);align-items:center}
.cs4 .navbtn{border:1px solid transparent;border-radius:6px;padding:7px 14px;background:transparent;color:inherit;font-size:12px}
.cs4 .context{padding:9px 18px;border-bottom:1px solid var(--cs4-border);display:flex;gap:9px;align-items:center;flex-wrap:wrap}
.cs4 .context select{max-width:265px;min-width:130px}.cs4 .context .page{min-width:125px;max-width:165px}
.cs4 .context label{font-size:11px;color:var(--cs4-soft)}.cs4 .context small{font-size:10px;color:var(--cs4-soft)}
.cs4 .grid{display:grid;grid-template-columns:minmax(270px,31%) minmax(390px,45%) minmax(230px,24%);flex:1;min-height:0}
.cs4 .left,.cs4 .center,.cs4 .right{min-width:0;min-height:0;overflow:auto;padding:15px}
.cs4 .left,.cs4 .center{border-right:1px solid var(--cs4-border)}.cs4 .search{width:100%;font-size:12px}
.cs4 .section-title{display:flex;justify-content:space-between;gap:8px;align-items:center;margin:12px 0 9px}
.cs4 .muted{font-size:11px;color:var(--cs4-soft)}.cs4 .pill{font-size:10px;border:1px solid var(--cs4-border);padding:2px 7px;border-radius:30px;color:var(--cs4-soft)}
.cs4 .chips{display:flex;flex-wrap:wrap;gap:5px}.cs4 .chip{border:1px solid var(--cs4-border);border-radius:6px;background:transparent;font-size:11px;padding:5px 8px}
.cs4 .chip.active{border-color:var(--cs4-accent);color:var(--cs4-accent)}
.cs4 .result{display:block;text-align:left;color:inherit;background:var(--cs4-panel);width:100%;border:1px solid transparent;border-radius:8px;margin:5px 0;padding:11px}
.cs4 .result.current{border-color:var(--cs4-accent)}.cs4 .result:hover{border-color:var(--cs4-accent)}
.cs4 .result strong{font-size:12px}.cs4 .result small{display:block;font-size:10px;margin-top:4px;color:var(--cs4-soft)}
.cs4 .head{display:flex;gap:9px;align-items:start;justify-content:space-between}.cs4 .card{border:1px solid var(--cs4-border);border-radius:9px;padding:12px;background:var(--cs4-panel)}
.cs4 .infobar{background:var(--cs4-panel);padding:12px;border:1px solid var(--cs4-border);border-radius:8px;margin:11px 0;font-size:11px;color:var(--cs4-soft)}
.cs4 .form{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:11px;margin:14px 0}
.cs4 .field-wrap{min-width:0}.cs4 .field-wrap.wide{grid-column:1/-1}.cs4 .field-wrap label{display:block;font-size:11px;color:var(--cs4-soft);margin:0 0 4px}
.cs4 .field-wrap input,.cs4 .field-wrap select,.cs4 .field-wrap textarea{width:100%;min-width:0}.cs4 textarea{font:12px/1.5 ui-monospace,Consolas,monospace;min-height:100px;resize:vertical}
.cs4 .preview{white-space:pre-wrap;word-break:break-word;border:1px solid var(--cs4-border);border-radius:8px;padding:11px;min-height:115px;max-height:230px;overflow:auto;background:rgba(0,0,0,.17);font:11px/1.5 ui-monospace,Consolas,monospace}
.cs4 .actions{display:flex;flex-wrap:wrap;gap:6px;margin:12px 0}.cs4 .warn{color:#f0ba7c}.cs4 .error{color:#ffa3a1}
.cs4 .step{border:1px solid var(--cs4-border);border-radius:8px;padding:10px;margin:8px 0;background:var(--cs4-panel)}
.cs4 .step .row{display:flex;justify-content:space-between;align-items:center;gap:5px}.cs4 .step .row strong{font-size:12px}.cs4 .steps-list{padding:0;list-style:none;margin:0}
.cs4 .tip{padding:7px 9px;border-radius:7px;border:1px dashed var(--cs4-border);font-size:11px;color:var(--cs4-soft);margin:7px 0}
.cs4 .foot{border-top:1px solid var(--cs4-border);font-size:11px;color:var(--cs4-soft);padding:8px 18px;display:flex;justify-content:space-between;gap:15px}
.cs4 .report{white-space:pre-wrap;font:11px/1.5 ui-monospace,Consolas,monospace}.cs4 .adv-result{margin:6px 0}
.cs4 .line{border-bottom:1px solid var(--cs4-border);margin:11px 0}.cs4 .badge{font-size:10px;padding:2px 6px;border-radius:5px;border:1px solid var(--cs4-border);color:var(--cs4-soft)}
@media(max-width:1180px){.cs4 .grid{grid-template-columns:minmax(230px,35%) minmax(340px,65%)}.cs4 .right{grid-column:1/-1;border-top:1px solid var(--cs4-border);max-height:220px}.cs4 .center{border-right:0}}
@media(max-width:720px){.cs4 .grid{grid-template-columns:1fr}.cs4 .left{max-height:240px;border-right:0;border-bottom:1px solid var(--cs4-border)}.cs4 .center{border-right:0}.cs4 .right{max-height:none}}
`;
const el=(tag,txt,cls)=>{const x=document.createElement(tag);if(txt!==undefined&&txt!==null)x.textContent=String(txt);if(cls)x.className=cls;return x;};
function btn(label,callback,kind="btn"){const b=el("button",label,kind);b.type="button";b.onclick=callback;return b;}
function field(parent,def,value,change,choices){
 const box=el("div",null,"field-wrap"+(["text","code"].includes(def.type)&&String(value??"").length>55?" wide":""));
 const l=el("label",def.label),type=def.type;
 let input;
 if(type==="code"){input=el("textarea");input.rows=5;input.spellcheck=false;}
 else if(type==="boolean"){input=el("select");for(const [v,t] of [[true,"Sí"],[false,"No"]]){const opt=el("option",t);opt.value=String(v);input.append(opt);}}
 else if(type==="select"){input=el("select");for(const option of (choices||def.options||[])){
  const pair=Array.isArray(option)?option:[option,option],o=el("option",pair[1]);o.value=String(pair[0]);input.append(o);
 }}
 else{input=el("input");input.type=type==="number"?"number":"text";if(type==="number"){if(def.min!=null)input.min=def.min;if(def.max!=null)input.max=def.max;}}
 input.value=String(value??"");input.oninput=()=>change(type==="boolean"?input.value==="true":input.value);
 box.append(l,input);parent.append(box);return input;
}
function cmdText(commands){
 return commands.map(c=>{
  const name={101:"Mostrar texto",401:"Continuar",102:"Elegir",402:"Respuesta",404:"Fin elecciones",111:"Condición",411:"Si no",412:"Fin condición",106:"Esperar",121:"Switch",122:"Variable",123:"Switch local",201:"Transferir",223:"Tono de pantalla",241:"BGM",250:"SE",355:"Ruby",655:"Ruby (continúa)"}[c.code]||"RMXP #"+c.code;
  return"  ".repeat(Math.max(0,c.indent))+name+": "+(c.code===355||c.code===655?String(c.parameters?.[0]||""):JSON.stringify(c.parameters||[]));
 }).join("\n");
}
const parseKind=label=>classifySymbolHint(label);
function mkLibraryName(){return "Secuencia "+new Date().toLocaleDateString("es-PE");}
const ROOTS=["Crear evento","Explorar comandos","Biblioteca"];
function mount(ctx,host){
 host.replaceChildren();
 const style=el("style",CSS);host.append(style);
 const root=el("div",null,"cs4");host.append(root);
 const header=el("header",null,"toolbar");
 header.append(el("span","⌘","mark"));
 const title=el("div");title.append(el("div","COMMAND STUDIO","crumb"),el("h2","Construye eventos, no líneas de código"));header.append(title);
 header.append(el("span",null,"spacer"),el("span","v0.4 · Maker Studio","badge"));root.append(header);
 const tabs=el("nav",null,"tabs");root.append(tabs);
 const context=el("div",null,"context");
 const mapLabel=el("span","Mapa sin seleccionar","badge");
 const eventSel=el("select"),pageSel=el("select");pageSel.className="page";
 const posSel=el("select");for(const [v,t]of [["end","Al final"],["start","Al principio"]]){const opt=el("option",t);opt.value=v;posSel.append(opt);}
 context.append(mapLabel,el("label","Evento"),eventSel,el("label","Página"),pageSel,el("label","Insertar"),posSel);
 const reload=btn("↻ Actualizar eventos",refreshTarget,"btn small ghost");context.append(reload);
 root.append(context);
 const grid=el("div",null,"grid");
 const left=el("aside",null,"left"),center=el("main",null,"center"),right=el("aside",null,"right");grid.append(left,center,right);root.append(grid);
 const foot=el("footer",null,"foot"),status=el("span","Sin cambios en mapas."),stats=el("span","");foot.append(status,stats);root.append(foot);
 const datasets={};for(const kind of ["pokemon","items","moves","abilities","trainer_types"]){const list=el("datalist");list.id="cs4-pbs-"+kind;root.append(list);datasets[kind]=list;}
 let mode="Crear evento",category="Todo",search="",action=ACTIONS[0],values=defaults(ACTIONS[0]),editing=-1;
 let steps=[],favorites=new Set(),library=[],recent=[],projectIndex=null,pbs=null,disposed=false,scanBusy=false;
 let mapId=null,eventId=null,pageIndex=0,scanStatus="Sin explorar";let sourceItems=[],advancedSearch="";
 const toast=(msg,level="info")=>{try{ctx.ui.showToast({message:msg,level});}catch(_){status.textContent=msg;}};
 const storedKey=()=>{let rootName="project";try{rootName=String(ctx.editor?.gameRoot?.()||"project");}catch(_){}return"cs4:"+rootName;};
 const saveState=async()=>{
  try{await ctx.storage?.set(storedKey(),{favorites:[...favorites],library,recent:recent.slice(0,15)});}catch(_){}
 };
 async function restore(){
  try{const d=await ctx.storage?.get(storedKey(),{});if(disposed)return;
   if(d&&typeof d==="object"){favorites=new Set(d.favorites||[]);library=Array.isArray(d.library)?d.library:[];recent=Array.isArray(d.recent)?d.recent:[];render();}
  }catch(_){}
 }
 function addRecent(id){recent=[id,...recent.filter(x=>x!==id)].slice(0,15);saveState();}
 function selectedEvent(){
  const id=Number(eventSel.value);
  return Number.isInteger(id)&&id>0?id:null;
 }
 function targetData(){return{mapId,eventId:selectedEvent(),pageIndex:Number(pageSel.value||0),position:posSel.value};}
 function refreshTarget(){
  const prevMap=mapId,prevId=eventId;
  mapId=activeMapId(ctx);
  mapLabel.textContent=mapId==null?"Abre un mapa":"Mapa #"+mapId;
  eventSel.replaceChildren();pageSel.replaceChildren();
  if(mapId==null||!isCompatible(ctx)){const opt=el("option",isCompatible(ctx)?"Abre un mapa":"API de eventos antigua");opt.value="";eventSel.append(opt);return;}
  let evs=[];try{evs=eventChoices(ctx,mapId);}catch(e){status.textContent=e.message;return;}
  const option=el("option","Seleccionar evento…");option.value="";eventSel.append(option);
  for(const e of evs){const opt=el("option","#"+e.id+" · "+e.name+" ("+e.x+","+e.y+")");opt.value=String(e.id);eventSel.append(opt);}
  if(pendingFocus&&mapId===pendingFocus.mapId&&evs.some(e=>e.id===pendingFocus.eventId)){
    eventSel.value=String(pendingFocus.eventId);pendingFocus=null;
  }else if(mapId===prevMap&&evs.some(e=>e.id===prevId))eventSel.value=String(prevId);
  else eventSel.value="";
  onEventChange();
 }
 function onEventChange(){
  eventId=selectedEvent();
  pageSel.replaceChildren();
  if(eventId&&mapId!=null)try{
   const p=pageChoices(ctx,mapId,eventId);for(const x of p){const option=el("option","Página "+(x.index+1)+" · "+x.count+" comandos");option.value=x.index;pageSel.append(option);}
   pageSel.value=p.some(x=>x.index===pageIndex)?pageIndex:"0";
  }catch(e){status.textContent=e.message;}
  renderRight();
 }
 eventSel.addEventListener("change",onEventChange);
 pageSel.addEventListener("change",()=>{pageIndex=Number(pageSel.value||0);renderRight();});
 const subs=[];
 try{subs.push(ctx.bus.on("map.loaded",refreshTarget));subs.push(ctx.bus.on("map.unloaded",refreshTarget));subs.push(ctx.bus.on("event.changed",refreshTarget));}catch(_){}
 function setMode(next){mode=next;render();}
 function renderTabs(){tabs.replaceChildren();for(const label of ROOTS){tabs.append(btn(label,()=>setMode(label),"navbtn"+(mode===label?" active":"")));}}
 function render(){
  renderTabs();refreshTargetPreserving();left.replaceChildren();center.replaceChildren();right.replaceChildren();
  if(mode==="Crear evento"){renderLeft();renderEditor();renderRight();}
  else if(mode==="Explorar comandos"){renderExplorer();renderRight();}
  else {renderLibrary();renderRight();}
 }
 function refreshTargetPreserving(){
  // Do not reset target while switching sections; external change bus reloads it.
  if(mapId==null&&activeMapId(ctx)!=null)refreshTarget();
 }
 function persistFav(){saveState();renderLeft();}
 function sourceCatalog(){
  const methods=(projectIndex?.methods||[]).filter(x=>!/^[_=]/.test(x.name));
  return methods;
 }
 function allSmart(){
  const array=ACTIONS.slice();
  if(category!=="Todo")return array.filter(x=>x.category===category);
  return array;
 }
 function resultCards(parent,actions){
  for(const a of actions.slice(0,100)){
   const b=btn("",()=>pick(a),"result"+(action.id===a.id?" current":""));
   const head=el("div",null,"head");
   head.append(el("strong",(a.icon||"⌘")+" "+a.title),el("span",favorites.has(a.id)?"★":"›","muted"));
   b.append(head,el("small",a.description));parent.append(b);
  }
 }
 function renderLeft(){
  left.append(el("div","QUÉ QUIERES HACER","crumb"));
  const input=el("input");input.className="search";input.placeholder="Ej.: NPC que regale un Pokémon una vez";input.value=search;left.append(input);
  const chips=el("div",null,"chips");chips.style.marginTop="10px";left.append(chips);
  function drawCategories(){
   chips.replaceChildren();
   for(const c of ["Todo",...CATEGORIES]){
    const b=btn(c,()=>{category=c;drawCategories();drawResults();},"chip"+(c===category?" active":""));chips.append(b);
   }
  }
  const results=el("div");left.append(results);
  function drawResults(){
   results.replaceChildren();let data=allSmart();
   const q=search.trim();if(q)data=smartSearch(q,data).map(x=>x.action);
   else if(category==="Todo"){
    data.sort((a,b)=>Number(favorites.has(b.id))-Number(favorites.has(a.id))||Number(recent.indexOf(a.id)===-1)-Number(recent.indexOf(b.id)===-1));
   }
   const head=el("div",null,"section-title");head.append(el("strong",q?"Resultados de búsqueda":"Acciones de uso cotidiano"),el("span",data.length+"","pill"));results.append(head);
   resultCards(results,data);
   if(!data.length)results.append(el("p","Prueba describir tu objetivo de otra forma.","tip"));
  }
  input.oninput=()=>{search=input.value;drawResults();};drawCategories();drawResults();
 }
 function pick(a,editAt=-1,savedValues=null){
  action=a;values=savedValues?{...savedValues}:defaults(a);editing=editAt;addRecent(a.id);
  if(mode!=="Crear evento")mode="Crear evento";
  render();
 }
 function readCommands(a=action,v=values){
  return buildAction(a.id,v);
 }
 function renderEditor(){
  if(!action){center.append(el("p","Selecciona una acción.","tip"));return;}
  center.append(el("div",action.category.toUpperCase(),"crumb"));
  const heading=el("div",null,"head"),title=el("div");title.append(el("h3",(action.icon||"⌘")+" "+action.title),el("p",action.description,"muted"));heading.append(title);
  heading.append(btn(favorites.has(action.id)?"★ Favorito":"☆ Favorito",()=>{
   if(favorites.has(action.id))favorites.delete(action.id);else favorites.add(action.id);persistFav();renderEditorOnly();
  },"btn small ghost"));
  center.append(heading);
  const tip=el("div",null,"infobar");
  tip.textContent=editing>=0?"Editando el paso "+(editing+1)+" de la secuencia. Guarda los cambios al terminar.":"Completa los campos. La vista previa se recalcula al instante. Puedes crear un evento completo combinando varias acciones.";
  center.append(tip);
  const form=el("div",null,"form");center.append(form);
  const previewTitle=el("div",null,"section-title");previewTitle.append(el("h4","Vista previa de comandos"),el("span","No se ejecuta al editar","badge"));center.append(previewTitle);
  const output=el("pre",null,"preview"),feedback=el("div","","muted");
  center.append(output,feedback);
  const buttons=el("div",null,"actions");center.append(buttons);
  const add=btn(editing>=0?"Guardar cambios del paso":"+ Añadir a secuencia",()=>{
    try{
     const commands=readCommands();
     const entry={id:action.id,title:action.title,values:{...values},commands,description:action.description};
     if(editing>=0)steps[editing]=entry;else steps.push(entry);
     editing=-1;toast("Acción añadida a la secuencia");render();
    }catch(e){feedback.textContent=e.message;}
  },"btn primary");
  const direct=btn("Insertar esta acción en el evento",async()=>{try{await insertCommands(readCommands());}catch(e){toast("Revisa los parámetros: "+e.message,"error");}},"btn");
  const copy=btn("Copiar código (opcional)",async()=>{
    let cmd;try{cmd=readCommands();}catch(e){toast(e.message,"error");return;}const text=cmd.filter(x=>x.code===355||x.code===655||x.code===101||x.code===401).map(x=>x.parameters[0]).join("\n")||cmdText(cmd);
    try{await ctx.clipboard.writeText(text);toast("Código copiado");}catch(_){toast("El portapapeles no está disponible","warn");}
  },"btn ghost");
  buttons.append(add,direct,copy);
  const recommendation=el("div",null,"section-title");recommendation.append(el("h4","Pasos que suelen acompañarlo"));center.append(recommendation);
  const suggestions=el("div",null,"chips");center.append(suggestions);
  for(const id of action.next||[]){
   const next=BY_ID.get(id);if(next)suggestions.append(btn(next.title,()=>pick(next),"chip"));
  }
  if(action.source){const src=el("a","Guía relacionada de LA BASE DE SKY ↗");src.href=SOURCES+action.source+".html";src.target="_blank";src.rel="noopener noreferrer";center.append(src);}
  const renderForm=()=>{
   form.replaceChildren();
   for(const f of action.fields){const control=field(form,f,values[f.key],v=>{values[f.key]=v;preview();});
    const kind=parseKind(f.label);
    if(kind&&f.type==="symbol")control.setAttribute("list","cs4-pbs-"+kind);
    if(f.type==="code")control.rows=6;
   }
  };
  const preview=()=>{
   try{
    const check=validate(action,values);
    if(check.errors.length)throw Error(check.errors.join(" · "));
    const commands=readCommands();
    output.textContent=cmdText(commands);
    feedback.textContent=check.warnings.length?check.warnings.join(" · "):commands.length+" comando(s) generados; estructura lista para insertar.";
    direct.disabled=!isCompatible(ctx)||!selectedEvent();
   }catch(e){output.textContent="";feedback.textContent=e.message;direct.disabled=true;}
  };
  renderForm();preview();
 }
 function renderEditorOnly(){center.replaceChildren();renderEditor();}
 async function insertCommands(cmds){
  if(!isCompatible(ctx)){toast("Maker Studio debe tener API de eventos 1.0.1 o superior.","error");return;}
  const target=targetData();
  try{
   const info=previewInsertion(ctx,{...target,commands:cmds});
   applyInsertion(ctx,{...target,commands:cmds});
   toast("Insertados "+info.added+" comandos en evento #"+target.eventId+" · página "+(target.pageIndex+1));
   status.textContent="Insertados "+info.added+" comandos. Se pueden deshacer desde Maker Studio.";
   refreshTarget();
  }catch(e){toast("No se insertó: "+e.message,"error");status.textContent="Sin cambios: "+e.message;}
 }
 function compiledSteps(){return steps.flatMap(s=>s.commands);}
 function renderRight(){
  right.replaceChildren();
  const title=el("div",null,"section-title");
  title.append(el("h4","SECUENCIA DEL EVENTO"),el("span",steps.length+" pasos","pill"));right.append(title);
  if(!steps.length)right.append(el("p","Agrega varias acciones y aplícalas de una vez. Puedes reordenarlas y reutilizar la secuencia.","tip"));
  for(let i=0;i<steps.length;i++){
   const s=steps[i],box=el("div",null,"step"),heading=el("div",null,"row");
   heading.append(el("strong",(i+1)+". "+s.title));
   const edits=el("div",null,"chips");
   edits.append(btn("↑",()=>moveStep(i,-1),"btn small"),btn("↓",()=>moveStep(i,1),"btn small"),
    btn("Editar",()=>{const a=BY_ID.get(s.id);if(a)pick(a,i,s.values);else editAdvancedStep(i);},"btn small"),
    btn("×",()=>{steps.splice(i,1);renderRight();},"btn small"));
   heading.append(edits);box.append(heading,el("p",s.commands.length+" comandos","muted"));right.append(box);
  }
  const size=steps.reduce((a,s)=>a+s.commands.length,0);right.append(el("p",size+" comandos preparados para insertar","muted"));
  const actions=el("div",null,"actions");right.append(actions);
  const apply=btn("Insertar secuencia completa",()=>insertCommands(compiledSteps()),"btn primary");
  apply.disabled=!steps.length||!selectedEvent()||!isCompatible(ctx);
  actions.append(apply);
  actions.append(btn("Guardar plantilla",saveTemplate,"btn"));
  actions.append(btn("Vaciar",()=>{steps=[];renderRight();},"btn ghost"));
  const note=el("div","Solo se añade al principio o al final de la página elegida. Los comandos existentes se conservan; Maker Studio ofrece Deshacer.","tip");right.append(note);
  if(selectedEvent()&&isCompatible(ctx))try{
    const t=targetData(),detail=previewInsertion(ctx,{...t,commands:steps.length?compiledSteps():[{code:106,indent:0,parameters:[1]}]});
    right.append(el("p","Destino: evento #"+t.eventId+" · página "+(t.pageIndex+1)+" · actualmente "+detail.oldCount+" comandos.","muted"));
  }catch(e){right.append(el("p","Revisa destino: "+e.message,"warn"));}
 }
 function editAdvancedStep(i){
  const step=steps[i];center.replaceChildren();center.append(el("h3","Editar script / secuencia avanzada"));
  const area=el("textarea");area.style.width="100%";area.rows=12;area.value=step.commands.filter(x=>x.code===355||x.code===655).map(x=>x.parameters[0]).join("\n");center.append(area);
  center.append(btn("Guardar como Ruby",()=>{step.commands=ruby(area.value);render();},"btn primary"));
 }
 function moveStep(i,dir){const j=i+dir;if(j<0||j>=steps.length)return;[steps[i],steps[j]]=[steps[j],steps[i]];renderRight();}
 async function saveTemplate(){
  if(!steps.length){toast("Añade acciones antes de guardar.","warn");return;}
  const result=await ctx.ui?.showInputDialog?.({title:"Guardar receta de evento",message:"Nombre para reutilizarla",defaultValue:mkLibraryName()}).catch(()=>null);
  const name=typeof result==="string"?result:(result?.value||result?.text||"");
  if(!String(name).trim())return;
  library.unshift({id:"c"+Date.now(),name:String(name).trim(),steps:JSON.parse(JSON.stringify(steps)),createdAt:Date.now()});
  await saveState();toast("Plantilla guardada en Biblioteca");renderRight();
 }
 function renderLibrary(){
  left.append(el("h3","Biblioteca reutilizable"),el("p","Tus secuencias guardadas por proyecto.","tip"));
  if(!library.length)left.append(el("p","Todavía no hay secuencias guardadas.","muted"));
  for(const item of library){
   const box=el("div",null,"step");box.append(el("strong",item.name),el("p",item.steps.length+" pasos","muted"));
   box.append(btn("Cargar en secuencia",()=>{steps=JSON.parse(JSON.stringify(item.steps));toast("Secuencia cargada");setMode("Crear evento");},"btn small primary"));
   box.append(btn("Eliminar",async()=>{const yes=await ctx.ui.showConfirmDialog?.({title:"Eliminar plantilla",message:"¿Eliminar "+item.name+"?"});if(!yes)return;library=library.filter(x=>x.id!==item.id);await saveState();render();},"btn small ghost"));
   left.append(box);
  }
  center.append(el("h3","Explora recetas desde la Wiki"),el("p","Además de las acciones de construcción, Command Studio conserva recetas de la wiki como referencia avanzada.","tip"));
  const q=el("input");q.className="search";q.placeholder="Buscar en las recetas técnicas";center.append(q);
  const list=el("div");center.append(list);
  function draw(){
   list.replaceChildren();const matches=WIKI.filter(x=>!q.value||[x.title,x.group].join(" ").toLowerCase().includes(String(q.value??"").toLowerCase())).slice(0,80);
   for(const w of matches)list.append(btn(w.title+" · "+w.group,()=>pickWiki(w),"result"));
  }
  q.oninput=draw;draw();
 }
 function pickWiki(w){
  const fields=w.args.map(([key,label,type,value])=>({key,label,type:type==="integer"?"number":type==="string"?"text":type==="expression"?"code":"symbol",value}));
  const a={id:"wiki:"+w.id,title:w.title,icon:"▤",category:w.group,description:w.note||"Plantilla técnica de la Wiki; verifica su compatibilidad en el proyecto.",fields,next:[],source:w.source.split("/").pop().replace(".html",""),
   build:v=>ruby(buildWiki(w,v))};
  pick(a);
 }
 function renderExplorer(){
  left.append(el("h3","Explorador real de código"));
  left.append(el("p","Busca funciones en Data/Scripts y Plugins. Los métodos internos no son comandos listos para usar.","tip"));
  const scan=btn(scanBusy?"Indexando…":"Indexar proyecto ahora",scanProjectCode,"btn primary");scan.disabled=scanBusy;left.append(scan);
  left.append(el("p",scanStatus,"muted"));
  const input=el("input");input.className="search";input.placeholder="Buscar pbAddPokemon, métodos, clases…";input.value=advancedSearch;input.style.marginTop="12px";left.append(input);
  const matches=el("div");left.append(matches);
  function draw(){
   matches.replaceChildren();const normalized=String(advancedSearch??"").toLowerCase();
   const data=sourceCatalog().filter(x=>!normalized||[x.title,x.sourcePath,x.signature].join(" ").toLowerCase().includes(normalized)).slice(0,150);
   for(const entry of data){
    const box=btn(entry.title+"("+entry.signature+")",()=>selectMethod(entry),"result");
    box.append(el("small",entry.sourcePath+" · "+entry.scope));matches.append(box);
   }
   if(projectIndex&&!data.length)matches.append(el("p","No se encontraron métodos.","tip"));
  }
  input.oninput=()=>{advancedSearch=input.value;draw();};draw();
  center.append(el("h3","Encyclopedia: métodos del proyecto"));
  center.append(el("div","La exploración lee .rb recursivamente, muestra origen y firma y permite crear acciones avanzadas. No ejecuta Ruby durante el análisis. Para eventos normales utiliza primero los asistentes de la sección Crear evento.","infobar"));
  if(projectIndex){
   center.append(el("h4","Estado de la exploración"));
   const report=projectIndex.report;
   center.append(el("pre","Métodos encontrados: "+report.found+"\nArchivos Ruby leídos: "+report.read+"\nArchivos con error: "+report.errors.length+"\nEstado de lectura: "+(report.complete?"Completado":"Parcial")+"\n"+report.errors.slice(0,20).map(x=>x.path+": "+x.error).join("\n"),"preview"));
  }
 }
 async function scanProjectCode(){
  if(scanBusy)return;scanBusy=true;scanStatus="Explorando scripts…";render();
  try{
   const result=await scanProject(ctx,info=>{scanStatus=info.read+" archivos · "+info.found+" métodos · "+info.errors+" errores";},{cancelled:false});
   projectIndex=result;scanStatus=result.report.found+" métodos encontrados en "+result.report.read+" archivos. "+result.report.errors.length+" errores.";
   render();
  }catch(e){scanStatus=e.message;toast("Falló la indexación: "+e.message,"error");}
  finally{scanBusy=false;render();}
 }
 function selectMethod(m){
  const params=m.parameters||[],fields=params.filter(x=>x.kind!=="block").map(p=>({key:p.name,label:p.name+(p.optional?" (opcional)":""),type:p.type==="integer"?"number":p.type==="boolean"?"boolean":p.type==="symbol"?"symbol":"code",value:defaultParameterValue(p)}));
  if(m.scope!=="global")fields.unshift({key:"__receiver",label:"Receptor Ruby",type:"text",value:m.owner||"mi_objeto"});
  const a={id:"method:"+m.id,title:m.title,icon:"⌘",category:"Script del proyecto",description:"Detectado en "+m.sourcePath+" · línea "+m.line+". "+m.note,fields,source:"secciones-scripts",next:[],
   build:v=>{const args={};for(const p of params)if(p.kind!=="block")args[p.name]={value:v[p.name],type:p.type,enabled:!p.optional||Boolean(v[p.name])};return ruby(buildMethodCode(m,args,v.__receiver));}};
  pick(a);
 }
 async function initPBS(){
  try{pbs=await loadPBS(ctx);if(disposed)return;
   for(const [kind,list] of Object.entries(datasets)){list.replaceChildren();for(const id of (pbs?.ids?.[kind]||[])){const option=el("option");option.value=id;list.append(option);}}
  }catch(_){}
 }
 focusHandler=refreshTarget;
 refreshTarget();
 render();
 restore();initPBS();
 return()=>{disposed=true;if(focusHandler===refreshTarget)focusHandler=null;for(const s of subs)try{s?.dispose?.();}catch(_){}};
}
export {mount};
