import { ACTIONS, BY_ID, defaults, buildAction, validate, smartSearch } from "./smart-core.js";
import { DIRECTIVES, GROUPS, codeFor, previewPlain, SOURCES } from "./messages-catalog.js";
import { WIKI, buildWiki } from "./wiki-catalog.js";
import { mount as mountAdvanced } from "./smart-ui.js";
import { loadPBS, classifySymbolHint } from "./pbs-index.js";
import { activeMapId, eventChoices, pageChoices, applyInsertion, isCompatible } from "./event-writer.js";

const CSS = [
".csb{height:100%;min-height:0;display:flex;flex-direction:column;background:var(--bg-primary,#142033);color:var(--text-primary,#ebf2fa);font:13px/1.45 system-ui,sans-serif}",
".csb *{box-sizing:border-box}.csb button,.csb input,.csb select,.csb textarea{font:inherit;color:inherit}.csb button{cursor:pointer}",
".csb button:disabled{opacity:.5;cursor:not-allowed}.csb .btn,.csb input,.csb select,.csb textarea{padding:9px 11px;border:1px solid var(--border,#38465a);background:var(--bg-secondary,#203249);border-radius:8px;outline:none}",
".csb .btn:hover,.csb input:focus,.csb select:focus,.csb textarea:focus,.csb .tile:hover{border-color:var(--accent,#5398df)}",
".csb .primary,.csb .selected{background:var(--accent,#498bd1);color:var(--text-on-accent,#fff);border-color:var(--accent,#498bd1);font-weight:bold}",
".csb header{display:flex;align-items:center;gap:12px;padding:13px 20px;border-bottom:1px solid var(--border,#38465a)}.csb h2{margin:0;font-size:17px}.csb h3{margin:0 0 8px;font-size:18px}",
".csb .sub{color:var(--text-secondary,#b1becc);font-size:11px}.csb .grow{flex:1}.csb .tabs{display:flex;gap:7px;flex-wrap:wrap;padding:9px 20px;border-bottom:1px solid var(--border,#38465a)}",
".csb .stage{overflow:auto;min-height:0;flex:1;padding:22px}.csb .content{max-width:1050px;margin:0 auto}.csb .narrow{max-width:780px;margin:0 auto}",
".csb .tiles{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:12px;margin:16px 0}.csb .tile{text-align:left;border:1px solid var(--border,#38465a);border-radius:10px;background:var(--bg-secondary,#203249);padding:17px;min-height:125px}",
".csb .tile strong{display:block;font-size:14px;margin:8px 0 5px}.csb .tile .emoji{font-size:24px}.csb .tile .sub{display:block}",
".csb .card{border:1px solid var(--border,#38465a);border-radius:10px;background:var(--bg-secondary,#203249);padding:16px;margin:14px 0}",
".csb .grid{display:grid;grid-template-columns:1fr 1fr;gap:12px}.csb .field{margin:9px 0}.csb .field label{display:block;color:var(--text-secondary,#b1becc);font-size:11px;margin-bottom:4px}",
".csb .field input,.csb .field select,.csb .field textarea{width:100%}.csb textarea{min-height:100px;resize:vertical;font:12px/1.5 ui-monospace,Consolas,monospace}",
".csb .list{display:flex;flex-direction:column;gap:7px;margin:10px 0}.csb .list button{text-align:left}.csb .search{width:100%}.csb .row{display:flex;gap:9px;align-items:center;flex-wrap:wrap}",
".csb .chips{display:flex;gap:6px;flex-wrap:wrap;margin:10px 0}.csb .chip{border:1px solid var(--border,#38465a);border-radius:20px;background:transparent;font-size:11px;padding:6px 10px}",
".csb .hint{padding:11px;border:1px solid var(--border,#38465a);border-radius:8px;margin:10px 0;font-size:12px;color:var(--text-secondary,#b1becc)}",
".csb .preview{white-space:pre-wrap;overflow-wrap:anywhere;max-height:230px;overflow:auto;border:1px solid var(--border,#38465a);border-radius:8px;padding:12px;background:rgba(0,0,0,.17);font:12px/1.5 ui-monospace,Consolas,monospace}",
".csb .dialog{border:5px double #829ac4;background:#fff;color:#253146;border-radius:12px;padding:16px;white-space:pre-wrap;min-height:100px;overflow-wrap:anywhere}",
".csb .widegrid{display:grid;grid-template-columns:1fr 1fr;gap:20px}.csb .resultlist{max-height:420px;overflow:auto;margin:10px 0}",
".csb a{color:var(--accent,#80bafb)}.csb footer{border-top:1px solid var(--border,#38465a);padding:9px 18px;font-size:11px;color:var(--text-secondary,#b1becc)}",
"@media(max-width:850px){.csb .tiles{grid-template-columns:repeat(2,minmax(0,1fr))}.csb .widegrid{grid-template-columns:1fr}}",
"@media(max-width:520px){.csb .tiles,.csb .grid{grid-template-columns:1fr}.csb .stage{padding:12px}}"
].join("\n");
const el=(tag,txt,cls)=>{const o=document.createElement(tag);if(txt!==undefined&&txt!==null)o.textContent=String(txt);if(cls)o.className=cls;return o;};
const button=(title,onClick,cls="btn")=>{const b=el("button",title,cls);b.type="button";b.onclick=onClick;return b;};
let requestedEvent=null;
export function focusEvent(mapId,eventId){requestedEvent={mapId:Number(mapId),eventId:Number(eventId)};}
const TOP=[
 ["talk","💬","Hablar con un personaje"],
 ["choices","❓","Hacer una pregunta"],
 ["give_item","🎁","Entregar un objeto"],
 ["gift_pokemon_once","🐣","Regalar un Pokémon"],
 ["trainer_once","⚔️","Crear un entrenador"],
 ["transfer","🗺️","Enviar a otro mapa"]
];
function commandsForMessage(text){
 return String(text).replace(/\r/g,"").split("\n").map((line,i)=>({code:i?401:101,parameters:[line],indent:0}));
}
function rubyCommands(code){
 return String(code).replace(/\r/g,"").split("\n").map((line,i)=>({code:i?655:355,parameters:[line],indent:0}));
}
export function mountFriendly(ctx,host){
 const root=el("div",null,"csb");root.append(el("style",CSS));
 const head=el("header");head.append(el("div","✦","emoji"));
 const brand=el("div");brand.append(el("h2","Command Studio"),el("div","Tu asistente para crear eventos Pokémon","sub"));head.append(brand);
 head.append(el("span",null,"grow"));head.append(el("span","Modo sencillo","sub"));root.append(head);
 const tabs=el("nav",null,"tabs");root.append(tabs);
 const stage=el("div",null,"stage"),foot=el("footer","Listo para crear.");root.append(stage,foot);
 host.replaceChildren(root);
 let mode="home",step=1,action=null,values={},query="",messageText="¡Hola, \\PN! ¿Qué tal?",group="Todas",tokenQuery="",token=null,tokenValue="";
 let catalogTab="wiki",catalogQuery="",mapId=activeMapId(ctx),eventId="",pageId=0,advCleanup=null,disposed=false,pbs=null;
 if(requestedEvent&&requestedEvent.mapId===mapId){eventId=String(requestedEvent.eventId);requestedEvent=null;}
 function notice(s){foot.textContent=s;try{ctx.ui.showToast({message:s,level:"info"});}catch(_){}}
 function menu(){
  tabs.replaceChildren();for(const [id,title]of [["home","Crear evento"],["message","Editor de mensajes"],["catalog","Enciclopedia"],["advanced","Avanzado"]]){
   tabs.append(button(title,()=>go(id),"btn"+(mode===id?" selected":"")));
  }
 }
 function go(next){
  if(advCleanup){advCleanup();advCleanup=null;}
  mode=next;menu();render();
 }
 function addField(target,label,value,onChange,config={}){
  const wrap=el("div",null,"field");wrap.append(el("label",label));
  let input=config.options?el("select"):config.multiline?el("textarea"):el("input");
  if(config.options){for(const opt of config.options){const [v,t]=Array.isArray(opt)?opt:[opt,opt];const o=el("option",t);o.value=String(v);input.append(o);}}
  else if(!config.multiline)input.type=config.number?"number":"text";
  input.value=String(value??"");input.oninput=()=>onChange(config.boolean?input.value==="true":input.value);
  wrap.append(input);target.append(wrap);return input;
 }
 function destination(target,post){
  mapId=activeMapId(ctx);
  const block=el("div",null,"card");
  block.append(el("strong","¿Dónde lo añadimos?"),el("div",mapId?"Mapa #"+mapId:"Abre primero un mapa","sub"));
  const row=el("div",null,"row"),evt=el("select"),pg=el("select");
  let events=[];if(mapId&&isCompatible(ctx))try{events=eventChoices(ctx,mapId);}catch(e){notice(e.message);}
  const none=el("option","Selecciona un evento");none.value="";evt.append(none);
  for(const e of events){const option=el("option",e.name+" (#"+e.id+")");option.value=e.id;evt.append(option);}
  if(events.some(e=>String(e.id)===eventId))evt.value=eventId;else eventId="";
  function pages(){
   eventId=evt.value;pg.replaceChildren();
   if(eventId&&mapId)try{
    for(const p of pageChoices(ctx,mapId,Number(eventId))){
     const opt=el("option","Página "+(p.index+1));opt.value=p.index;pg.append(opt);
    }
    pg.value=String(pageId);if(pg.selectedIndex<0)pg.selectedIndex=0;
    pageId=Number(pg.value||0);
   }catch(e){notice(e.message);}
   post.disabled=!eventId||!isCompatible(ctx);
  }
  evt.onchange=pages;pg.onchange=()=>pageId=Number(pg.value||0);
  row.append(evt,pg);block.append(row);
  block.append(el("p","Se añade al final de la página sin borrar tus comandos anteriores.","sub"));
  target.append(block);pages();
 }
 function insert(commands,after){
  if(!mapId||!eventId){notice("Primero abre un mapa y selecciona un evento.");return;}
  try{
   const options={mapId,eventId:Number(eventId),pageIndex:pageId,position:"end",commands};
   const result=applyInsertion(ctx,options);
   notice("¡Añadido! "+result.inserted+" comandos. Puedes usar Deshacer en Maker Studio.");
   if(after)after();
  }catch(e){notice("No se insertó: "+e.message);}
 }
 function render(){
  stage.replaceChildren();
  if(mode==="advanced"){
   const bar=el("div",null,"row");bar.append(button("← Volver al modo sencillo",()=>go("home")));stage.append(bar);
   const area=el("div");area.style.height="calc(100% - 44px)";area.style.minHeight="580px";stage.append(area);
   try{advCleanup=mountAdvanced(ctx,area);}catch(e){notice(e.message);}
   return;
  }
  const area=el("div",null,"content");stage.append(area);
  if(mode==="home")step===1?home(area):step===2?configure(area):review(area);
  if(mode==="message")messages(area);
  if(mode==="catalog")catalog(area);
 }
 function home(area){
  area.append(el("h3","¿Qué quieres que pase en tu juego?"));
  area.append(el("p","Elige una tarea. Te preguntaré lo necesario. No necesitas escribir código.","sub"));
  const search=el("input");search.placeholder="Ej. entregar objeto, entrenador, curar Pokémon, hablar…";search.className="search";search.value=query;area.append(search);
  const results=el("div");area.append(results);
  const pick=a=>{action=a;values=defaults(a);step=2;render();};
  function draw(){
   results.replaceChildren();
   if(!query.trim()){
    const cards=el("div",null,"tiles");for(const [id,icon,title]of TOP){
     const a=BY_ID.get(id),b=button("",()=>pick(a),"tile");b.append(el("div",icon,"emoji"),el("strong",title),el("span",a.description,"sub"));cards.append(b);
    }results.append(cards,el("h3","Otras tareas disponibles"));
   }
   const found=query.trim()?smartSearch(query).slice(0,35).map(x=>x.action):ACTIONS.filter(a=>!TOP.some(x=>x[0]===a.id));
   const list=el("div",null,"grid");
   for(const a of found){const b=button(a.icon+" "+a.title,()=>pick(a));list.append(b);}
   results.append(list);
   if(!found.length)results.append(el("div","No encontré esa tarea. Prueba términos más sencillos o abre Enciclopedia.","card"));
  }
  search.oninput=()=>{query=search.value;draw();};draw();
 }
 function configure(area){
  area.className="narrow";
  if(!action){step=1;return home(area);}
  area.append(el("div","PASO 2 DE 3 · CONFIGURA","sub"),el("h3",action.icon+" "+action.title),el("p",action.description,"sub"));
  const form=el("div",null,"card"),grid=el("div",null,"grid");form.append(grid);
  for(const f of action.fields){
   const options=f.type==="boolean"?[["true","Sí"],["false","No"]]:f.type==="select"?f.options:null;
   const input=addField(grid,f.label,values[f.key],v=>values[f.key]=v,{options,boolean:f.type==="boolean",number:f.type==="number",multiline:f.type==="code"});
   const kind=classifySymbolHint(f.label);
   if(kind&&pbs?.ids?.[kind]?.length){
    const list=el("datalist");list.id="csb-pbs-"+f.key;for(const id of pbs.ids[kind]){const opt=el("option");opt.value=id;list.append(opt);}
    grid.append(list);input.setAttribute("list",list.id);
   }
  }
  area.append(form);
  area.append(el("div","Los términos como Especie y Objeto corresponden a IDs del proyecto. Verás el resultado antes de insertarlo.","hint"));
  const row=el("div",null,"row");
  row.append(button("← Atrás",()=>{step=1;render();}),button("Ver resultado →",()=>{
   const c=validate(action,values);if(c.errors.length)return notice(c.errors[0]);step=3;render();
  },"btn primary"));area.append(row);
 }
 function review(area){
  area.className="narrow";area.append(el("div","PASO 3 DE 3 · AÑADE","sub"),el("h3","Así quedará tu evento"));
  let cmds=[];try{cmds=buildAction(action.id,values);}catch(e){notice(e.message);step=2;render();return;}
  const preview=el("pre",null,"preview");
  preview.textContent=cmds.map(c=>({101:"Hablar",401:"Continuación",355:"Acción Pokémon",655:"Continuación",111:"Condición",411:"Si no",412:"Fin de condición",102:"Preguntar",402:"Respuesta",404:"Fin",121:"Interruptor",122:"Variable",123:"Interruptor local",201:"Cambiar mapa",106:"Esperar"}[c.code]||"Comando")+"  "+String(c.parameters?.[0]??"")).join("\n");
  area.append(preview);
  const send=button("✓ Añadir al evento",()=>insert(cmds,()=>{step=1;render();}),"btn primary");
  destination(area,send);
  const row=el("div",null,"row");row.append(send,button("← Editar opciones",()=>{step=2;render();}));area.append(row);
 }
 function messages(area){
  area.append(el("h3","Haz que tus personajes hablen"),el("p","Escribe el texto y pulsa los botones para añadir efectos. No necesitas conocer los códigos.","sub"));
  const columns=el("div",null,"widegrid"),left=el("div"),right=el("div");columns.append(left,right);area.append(columns);
  const editor=el("textarea");editor.style.width="100%";editor.style.minHeight="185px";editor.value=messageText;left.append(editor);
  function paste(value){
   editor.setRangeText(value,editor.selectionStart,editor.selectionEnd,"end");editor.dispatchEvent(new Event("input"));editor.focus();
  }
  const quick=el("div",null,"chips");for(const [label,v]of [["Nombre del jugador","\\PN"],["Salto de línea","\\n"],["Azul","\\b"],["Rojo","\\r"],["Esperar clic","\\!"],["Dinero","\\PM"]]){
   quick.append(button(label,()=>paste(v),"chip"));
  }left.append(quick);
  left.append(el("h4","Vista previa orientativa"));const preview=el("div",null,"dialog");left.append(preview);
  left.append(el("div","Esta vista no ejecuta los comandos: la posición, efectos y animaciones se ven al jugar.","sub"));
  editor.oninput=()=>{messageText=editor.value;preview.textContent=previewPlain(messageText);};editor.oninput();
  const post=button("✓ Añadir este mensaje al evento",()=>insert(commandsForMessage(messageText)),"btn primary");
  destination(left,post);left.append(post);
  right.append(el("h4","Todos los controles de texto"));
  const search=el("input");search.placeholder="Buscar: color, ventana, sonido…";search.className="search";search.value=tokenQuery;right.append(search);
  const chips=el("div",null,"chips");right.append(chips);const list=el("div",null,"resultlist");right.append(list);
  const panel=el("div",null,"card");right.append(panel);
  function draw(){
   chips.replaceChildren();for(const g of ["Todas",...GROUPS])chips.append(button(g,()=>{group=g;draw();},"chip"+(group===g?" selected":"")));
   list.replaceChildren();
   for(const d of DIRECTIVES.filter(x=>(group==="Todas"||x.category===group)&&[x.title,x.description,x.token].join(" ").toLowerCase().includes(tokenQuery.toLowerCase()))){
    const b=button(d.title+"  ·  "+d.token,()=>choose(d));list.append(b);
   }
   displayToken();
  }
  function choose(d){
   token=d;const match=d.token.match(/\[([^\]]*)\]/)||d.token.match(/=([^<>]+)/);
   tokenValue=match?.[1]||"1";displayToken();
  }
  function displayToken(){
   panel.replaceChildren();
   if(!token){panel.append(el("span","Selecciona un control para añadirlo.","sub"));return;}
   panel.append(el("strong",token.title),el("p",token.description,"sub"));
   if(token.parameter){
    addField(panel,token.parameter,tokenValue,v=>tokenValue=v);
   }
   const err=el("div","","sub"),insertButton=button("Insertar código en mensaje",()=>{
    try{paste(codeFor(token,token.parameter?tokenValue:null,editor.value.substring(editor.selectionStart,editor.selectionEnd)||"texto"));err.textContent="";}
    catch(e){err.textContent=e.message;}
   },"btn primary");panel.append(insertButton,err);
  }
  search.oninput=()=>{tokenQuery=search.value;draw();};draw();
  area.append(el("div","Referencia: Essentials Docs / Messages, Wiki de LA BASE DE SKY y scripts de mensajes del proyecto. La documentación inglesa antigua no recibe nuevas actualizaciones.","hint"));
 }
 function catalog(area){
  area.append(el("h3","Enciclopedia"),el("p","Cuando no encuentres una tarea en Crear evento, busca aquí su función concreta.","sub"));
  const switches=el("div",null,"chips");area.append(switches);
  for(const [key,label]of [["wiki","Funciones Essentials y Sky"],["messages","Controles de mensaje"]]){
   switches.append(button(label,()=>{catalogTab=key;render();},"chip"+(catalogTab===key?" selected":"")));
  }
  const search=el("input");search.className="search";search.placeholder="Buscar funciones o palabras…";search.value=catalogQuery;area.append(search);
  const entries=el("div",null,"list");area.append(entries);
  function draw(){
   entries.replaceChildren();
   if(catalogTab==="wiki"){
    for(const w of WIKI.filter(x=>[x.title,x.group,x.template].join(" ").toLowerCase().includes(catalogQuery.toLowerCase()))){
     entries.append(button(w.title+" · "+w.group,()=>{
      const data=Object.fromEntries(w.args.map(p=>[p[0],p[3]]));
      action=BY_ID.get("custom_ruby");values={code:buildWiki(w,data)};step=2;go("home");
     }));
    }
   }else for(const d of DIRECTIVES.filter(x=>[x.title,x.category,x.token,x.description].join(" ").toLowerCase().includes(catalogQuery.toLowerCase()))){
    entries.append(button(d.title+" · "+d.token,()=>{token=d;group=d.category;go("message");}));
   }
  }
  search.oninput=()=>{catalogQuery=search.value;draw();};draw();
  const docs=el("div",null,"hint");
  for(const [name,url]of [["Essentials Docs / Messages",SOURCES.essentials],["LA BASE DE SKY / Mensajes",SOURCES.lbds]]){
   const a=el("a",name+" ↗");a.href=url;a.target="_blank";a.rel="noopener noreferrer";docs.append(a,el("span","   "));
  }area.append(docs);
 }
 (async()=>{try{pbs=await loadPBS(ctx);}catch(_){} })();
 menu();render();
 return()=>{disposed=true;if(advCleanup)advCleanup();};
}
