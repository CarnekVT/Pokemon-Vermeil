import { ACTIONS, BY_ID, defaults, buildAction, validate, smartSearch } from "./smart-core.js";
import { DIRECTIVES, GROUPS, codeFor, previewPlain, SOURCES } from "./messages-catalog.js";
import { WIKI, buildWiki } from "./wiki-catalog.js";
import { mount as mountAdvanced } from "./smart-ui.js";
import { loadPBS, classifySymbolHint } from "./pbs-index.js";
import { activeMapId, eventChoices, pageChoices, applyInsertion, isCompatible, availableInsertionPoints, describeCommand } from "./event-writer.js";
import { createEventBrowser } from "./event-browser.js";
import {armPlacement,cancelPlacement} from "./placement.js";
import { enhancePokemonActions, POKEMON_GROUPS, giftCheck } from "./pokemon-gift.js";
import { auditProject, classifyReference } from "./function-audit.js";
import { installWorkspaceFullscreen } from "./fullscreen.js";
import { mountVisualMessageEditor } from "./message-ui.js";
import { EXTRA_CSS } from "./visual-style.js";
import { UX_CSS } from "./ux-style.js";
import { NEXT_CSS } from "./next-style.js";
import { COLOR_PRESETS, colorTag, renderMessagePreview, normalizedHex, setMessagePosition, messagePosition, colorType, WINDOW_COLOR_HINTS } from "./visual-message.js";

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
 enhancePokemonActions(ACTIONS, code=>code.replace(/\r/g,"").split("\n").map((line,i)=>({code:i?655:355,indent:0,parameters:[line]})));
 const root=el("div",null,"csb");root.tabIndex=0;root.append(el("style",CSS),el("style",EXTRA_CSS),el("style",UX_CSS),el("style",NEXT_CSS));
 const head=el("header");head.append(el("div","✦","emoji"));
 const brand=el("div");brand.append(el("h2","Command Studio"),el("div","Tu asistente para crear eventos Pokémon","sub"));head.append(brand);
 head.append(el("span",null,"grow"));
 const fullscreenButton=el("button","⛶ Pantalla completa","btn");fullscreenButton.type="button";
 head.append(fullscreenButton,el("span","Modo sencillo","sub"));root.append(head);
 const tabs=el("nav",null,"tabs");root.append(tabs);
 const stage=el("div",null,"stage"),foot=el("footer","Listo para crear.");root.append(stage,foot);
 host.replaceChildren(root);
 const fullscreenDispose=installWorkspaceFullscreen(ctx,host,root,fullscreenButton);
 let mode="events",step=1,action=null,values={},query="",messageText="¡Hola, \\PN! ¿Qué tal?",group="Todas",tokenQuery="",token=null,tokenValue="";
 let insertionPosition="end",destinationRefresh=null,eventBrowser=null,messageCleanup=null,speakerName="",sourceAudit=null,scanning=false,subscriptions=[],catalogTab="wiki",catalogQuery="",catalogGroup="Todas",catalogLimit=12,selectedReference=null,moreTasks=false,taskGroup="Todas",taskLimit=10,sessionRecent=[],favorites=new Set(),mapId=activeMapId(ctx),eventId="",pageId=0,advCleanup=null,disposed=false,pbs=null;
 if(requestedEvent&&requestedEvent.mapId===mapId){eventId=String(requestedEvent.eventId);requestedEvent=null;}
 function notice(s){foot.textContent=s;try{ctx.ui.showToast({message:s,level:"info"});}catch(_){}}
 function menu(){
  tabs.replaceChildren();for(const [id,title]of [["home","Crear acción"],["events","Eventos y páginas"],["message","Diálogos"],["catalog","Enciclopedia"],["advanced","Avanzado"]]){
   tabs.append(button(title,()=>go(id),"btn"+(mode===id?" selected":"")+(id==="advanced"?" csb-quiet":"")));
  }
 }
 function go(next){
  cancelPlacement();
  if(advCleanup){advCleanup();advCleanup=null;}
  if(eventBrowser){eventBrowser.dispose();eventBrowser=null;}
  if(messageCleanup){messageCleanup();messageCleanup=null;}
  mode=next;menu();render();stage.scrollTop=0;
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
  const block=el("div",null,"card");const heading=el("div",null,"csb-section-head");
  heading.append(el("strong","Destino de la acción"),button("Explorar eventos y comandos ↗",()=>go("events"),"btn"));
  block.append(heading);
  const mapCaption=el("p","","sub"),row=el("div",null,"row"),evt=el("select"),pg=el("select"),positions=el("select");
  evt.setAttribute("aria-label","Seleccionar evento");pg.setAttribute("aria-label","Página del evento");
  positions.setAttribute("aria-label","Punto de inserción");
  row.append(evt,pg,positions);block.append(mapCaption,row);
  const guidance=el("p","La lista se sincroniza con el mapa. Solo se ofrecen puntos seguros de inserción.","sub");
  block.append(guidance);target.append(block);
   // Event creation is also available at the insertion step: users should not
   // have to leave the wizard, find their map again, and restart their action.
   const createBox=el("details",null,"csb-destination-create");createBox.open=!eventId;
   createBox.append(el("summary","＋ Crear evento nuevo en este mapa"));
   const newRow=el("div",null,"csb-destination-newrow");
   const newName=el("input");newName.placeholder="Nombre (ej.: Cofre)";newName.value="Nuevo evento";
   newName.setAttribute("aria-label","Nombre del evento");
   const newX=el("input"),newY=el("input");
   for(const [input,label] of [[newX,"X"],[newY,"Y"]]){input.type="number";input.min="0";input.value="0";input.placeholder=label;input.setAttribute("aria-label","Casilla "+label);}
   const newEvent=button("Crear y seleccionar",()=>{
     const currentMap=activeMapId(ctx),x=Number(newX.value),y=Number(newY.value);
     if(currentMap==null)return notice("Primero abre el mapa donde crearás el evento.");
     if(!Number.isSafeInteger(x)||!Number.isSafeInteger(y)||x<0||y<0)return notice("Introduce coordenadas X e Y válidas.");
     if(typeof ctx.events?.create!=="function")return notice("Esta versión de Maker Studio no admite la creación de eventos.");
     try{
       const made=ctx.events.create(currentMap,x,y,newName.value.trim()||"Nuevo evento");
       const fresh=Number(made?.id??made);
       if(!Number.isSafeInteger(fresh)||fresh<1)throw Error("No se recibió el ID del evento.");
       mapId=currentMap;eventId=String(fresh);pageId=0;insertionPosition="end";
       refill();createBox.open=false;
       notice("Evento #"+fresh+" creado y seleccionado. Ya puedes añadir la acción.");
     }catch(err){notice("No se creó el evento: "+String(err?.message||err));}
   },"btn primary");
   const chooseTile=button("📍 Marcar en el mapa",()=>{
    const callback=selection=>{
      if(disposed)return;
      newX.value=String(selection.x);newY.value=String(selection.y);
      if(selection.mapId!==mapId){mapId=selection.mapId;eventId="";refill();}
      notice("Casilla ("+selection.x+", "+selection.y+") elegida.");
    };
    if(!armPlacement(ctx,callback))notice("No se pudo abrir la herramienta para marcar la casilla.");
    else notice("Pulsa una casilla del mapa para elegir la posición del evento.");
   },"btn");
   newRow.append(newName,newX,newY,chooseTile,newEvent);createBox.append(newRow);
   block.append(createBox);
  function refill(){
    const active=activeMapId(ctx);
    if(mapId!==active){mapId=active;eventId="";pageId=0;insertionPosition="end";}
    mapCaption.textContent=mapId?"Mapa actual: #"+mapId:"Abre un mapa para elegir un evento";
    let events=[];try{events=mapId?eventChoices(ctx,mapId):[];}catch(e){notice(e.message);}
    evt.replaceChildren();
    const empty=el("option","Seleccionar evento…");empty.value="";evt.append(empty);
    for(const e of events){const option=el("option","#"+e.id+" · "+e.name+" ("+e.x+","+e.y+")");option.value=e.id;evt.append(option);}
    if(events.some(e=>String(e.id)===String(eventId)))evt.value=String(eventId);
    else{eventId="";evt.value="";}
    pages();
  }
  function pages(){
    pg.replaceChildren();positions.replaceChildren();
    if(!eventId||!mapId){post.disabled=true;return;}
    let pagesList=[];try{pagesList=pageChoices(ctx,mapId,Number(eventId));}catch(e){notice(e.message);}
    if(!pagesList.some(x=>Number(x.index)===Number(pageId)))pageId=0;
    for(const p of pagesList){const opt=el("option","Página "+(p.index+1)+" · "+p.count+" comandos");opt.value=p.index;pg.append(opt);}
    pg.value=String(pageId);if(pg.selectedIndex<0){pg.selectedIndex=0;pageId=Number(pg.value||0);}
    slots();post.disabled=false;
  }
  function slots(){
    positions.replaceChildren();
    let commandList=[];
    try{commandList=ctx.events.getFull(mapId,Number(eventId))?.pages?.[pageId]?.list||[];}
    catch(e){notice(e.message);}
    const slots=availableInsertionPoints(commandList);
    for(const slot of slots){
      const opt=el("option",(slot.index===0?"Inicio":slot.index===commandList.filter(x=>x.code!==0).length?"Final":"Tras "+describeCommand(commandList.filter(x=>x.code!==0)[slot.index-1]))+" · #"+slot.index);
      opt.value=slot.index;positions.append(opt);
    }
    const last=commandList.filter(x=>x.code!==0).length;
    const index=insertionPosition==="end"?last:insertionPosition;
    if(slots.some(p=>p.index===Number(index)))positions.value=String(index);
    else positions.value=String(last);
    insertionPosition=Number(positions.value||0);
    post.disabled=!slots.length;
  }
  evt.onchange=()=>{eventId=evt.value;pageId=0;insertionPosition="end";pages();};
  pg.onchange=()=>{pageId=Number(pg.value||0);insertionPosition="end";slots();};
  positions.onchange=()=>insertionPosition=Number(positions.value);
  destinationRefresh=refill;refill();
 }
 function insert(commands,after){
  if(!mapId||!eventId){notice("Primero abre un mapa y selecciona un evento.");return;}
  try{
   const options={mapId,eventId:Number(eventId),pageIndex:pageId,position:insertionPosition,commands};
   const result=applyInsertion(ctx,options);
   notice("¡Añadido! "+result.inserted+" comandos. Puedes usar Deshacer en Maker Studio.");
   if(after)after();
  }catch(e){notice("No se insertó: "+e.message);}
 }
 function render(){
  try{return renderContent();}
  catch(err){
    const diagnostic=String(err?.stack||err?.message||err).slice(0,1500);
    try{ctx.log?.error?.("[Command Studio] "+mode+" · "+diagnostic);}catch(_){}
    try{console.error("[Command Studio] "+mode,err);}catch(_){}
    stage.replaceChildren();
    const card=el("section",null,"card");
    card.append(el("h3","No se pudo abrir esta sección"),
      el("p","Ocurrió un error al preparar "+mode+". Las demás herramientas siguen disponibles.","sub"));
    const pre=el("pre",diagnostic,"preview");pre.style.whiteSpace="pre-wrap";pre.style.maxHeight="180px";pre.style.overflow="auto";
    card.append(pre);
    card.append(button("Volver al inicio",()=>{mode="home";step=1;menu();render();},"btn primary"));
    card.append(button("Copiar diagnóstico",()=>{
      try{navigator.clipboard?.writeText?.(diagnostic);}
      catch(_){}
    },"btn"));
    stage.append(card);notice("Error de Command Studio · consulta el diagnóstico.");
  }
 }
 function renderContent(){
  if(messageCleanup){messageCleanup();messageCleanup=null;}
  destinationRefresh=null;
  if(eventBrowser){eventBrowser.dispose();eventBrowser=null;}
  stage.replaceChildren();
  if(mode==="advanced"){
   const bar=el("div",null,"row");bar.append(button("← Volver al modo sencillo",()=>go("home")));stage.append(bar);
   const area=el("div");area.style.height="calc(100% - 44px)";area.style.minHeight="580px";stage.append(area);
   try{advCleanup=mountAdvanced(ctx,area);}catch(e){notice(e.message);}
   return;
  }
  const area=el("div",null,"content");stage.append(area);
  if(mode==="home")step===1?home(area):step===2?configure(area):review(area);
  if(mode==="events"){
    area.classList.add("csb-events-content");
    const top=el("div",null,"csb-section-head");
    top.append(el("h3","Eventos del mapa"),button("＋ Nueva acción",()=>{step=1;go("home");},"btn primary"));
    area.append(top);
    area.append(el("p","Selecciona un evento y marca dónde quieres colocar tu acción. El orden se conserva al volver a Crear.","sub"));
    const workspace=el("div",null,"csb-event-browser-host");area.append(workspace);
    eventBrowser=createEventBrowser(ctx,workspace,{
      eventId:eventId?Number(eventId):null,pageIndex:pageId,position:insertionPosition,
      onSelection:sel=>{
        if(sel.mapId!=null&&mapId!==sel.mapId){mapId=sel.mapId;}
        eventId=sel.eventId?String(sel.eventId):"";
        pageId=sel.pageIndex;
        insertionPosition=sel.position;
      },
      onError:e=>notice(e.message),
      onNotice:message=>notice(message),
      onCreate:()=>{step=1;go("home");}
    });
  }
  if(mode==="message")messages(area);
  if(mode==="catalog")catalog(area);
 }
 function home(area){
  const heading=el("div",null,"csb-intro");
  heading.append(el("h3","¿Qué quieres crear hoy?"),
    el("p","Elige una acción y Command Studio te guiará en 3 pasos. No necesitas conocer Ruby.","sub"));
  area.append(heading);
  const input=el("input");input.className="search";input.placeholder="Buscar: curar Pokémon, regalar objeto, entrenador, clima…";
  input.value=query;input.setAttribute("aria-label","Buscar una acción para el evento");area.append(input);
  const results=el("div");area.append(results);
  const pick=a=>{
    if(!a)return;
    action=a;values=defaults(a);step=2;
    sessionRecent=[a.id,...sessionRecent.filter(id=>id!==a.id)].slice(0,5);render();
  };
  function taskButton(a){
    const row=el("div",null,"csb-task-result");
    const select=button("",()=>pick(a),"csb-task-open");
    select.append(el("span",a.icon||"✦","csb-task-icon"));
    const content=el("span",null,"csb-task-copy");
    content.append(el("strong",a.title),el("small",a.description));select.append(content);
    const fav=button(favorites.has(a.id)?"★":"☆",()=>{
      if(favorites.has(a.id))favorites.delete(a.id);else favorites.add(a.id);
      draw();
    },"csb-favorite");
    fav.setAttribute("aria-label",(favorites.has(a.id)?"Quitar de":"Añadir a")+" favoritos: "+a.title);
    fav.title="Acceso rápido durante esta sesión";
    row.append(select,fav);return row;
  }
  function draw(){
    results.replaceChildren();
    if(query.trim()){
      const found=smartSearch(query).map(r=>r.action);
      const groupTitle=el("div",found.length+" coincidencias","sub");results.append(groupTitle);
      const list=el("div",null,"csb-result-grid");
      for(const a of found.slice(0,taskLimit))list.append(taskButton(a));
      results.append(list);
      if(found.length>taskLimit)results.append(button("Ver más resultados ("+(found.length-taskLimit)+")",()=>{taskLimit+=10;draw();},"btn"));
      if(!found.length)results.append(el("div","No encontré esa tarea. Prueba «hablar», «regalo», «combate», «clima» o consulta la Enciclopedia.","hint"));
      return;
    }
    const fastIds=[...favorites,...sessionRecent].filter((id,i,arr)=>arr.indexOf(id)===i).filter(id=>BY_ID.has(id));
    if(fastIds.length){
      results.append(el("h4","Tus accesos de esta sesión"));
      const quick=el("div",null,"csb-shortcuts");
      for(const id of fastIds.slice(0,5)){const a=BY_ID.get(id);quick.append(button((a.icon||"✦")+" "+a.title,()=>pick(a),"chip"));}
      results.append(quick);
    }
    results.append(el("h4","Tareas más habituales"));
    const tiles=el("div",null,"tiles");
    for(const [id,icon,title] of TOP){
      const a=BY_ID.get(id);if(!a)continue;
      const b=button("",()=>pick(a),"tile");
      b.append(el("div",icon,"emoji"),el("strong",title),el("span",a.description,"sub"));
      tiles.append(b);
    }
    results.append(tiles);
    const explore=el("div",null,"csb-explore");
    const row=el("div",null,"csb-explore-head");
    row.append(el("div",null,"csb-explore-title"));
    row.firstChild.append(el("strong","¿Buscas otra cosa?"),el("div","Accede a las demás tareas por tema, sin listas interminables.","sub"));
    const toggle=button(moreTasks?"− Ocultar tareas":"＋ Explorar más tareas",()=>{moreTasks=!moreTasks;draw();},"btn");
    toggle.setAttribute("aria-expanded",String(moreTasks));row.append(toggle);explore.append(row);
    if(moreTasks){
      const chips=el("div",null,"chips");explore.append(chips);
      const groups=["Todas",...new Set(ACTIONS.map(a=>a.category))];
      for(const group of groups){
        chips.append(button(group,()=>{taskGroup=group;taskLimit=10;draw();},"chip"+(group===taskGroup?" selected":"")));
      }
      const filtered=ACTIONS.filter(a=>taskGroup==="Todas"||a.category===taskGroup);
      explore.append(el("p",filtered.length+" tareas disponibles","sub"));
      const list=el("div",null,"csb-result-grid");
      for(const a of filtered.slice(0,taskLimit))list.append(taskButton(a));
      explore.append(list);
      if(filtered.length>taskLimit)explore.append(button("Mostrar "+Math.min(10,filtered.length-taskLimit)+" más",()=>{taskLimit+=10;draw();},"btn"));
    }
    results.append(explore);
    const help=el("details",null,"csb-help");
    help.append(el("summary","¿Es tu primera vez? Así funciona"));
    help.append(el("p","1. Selecciona una tarea.  2. Cambia los datos del evento.  3. Escoge un mapa, evento y página. Puedes deshacer la inserción desde Maker Studio.","sub"));
    results.append(help);
  }
  input.oninput=()=>{query=input.value;taskLimit=10;draw();};draw();
 }
 function configure(area){
  area.className="narrow";
  if(!action){step=1;return home(area);}
  const top=el("div",null,"csb-wizard-step");
  top.append(el("span","PASO 2 DE 3","csb-step-badge"),
    button("← Cambiar de tarea",()=>{step=1;render();},"btn csb-quiet"));
  area.append(top,el("h3",(action.icon||"✦")+" "+action.title),el("p",action.description,"sub"));
  const form=el("div",null,"card"),mainGrid=el("div",null,"grid");
  form.append(el("h4","Información principal"),mainGrid);
  function add(f,target){
    const options=f.type==="boolean"?[["true","Sí"],["false","No"]]:f.type==="select"?f.options:null;
    const input=addField(target,f.label,values[f.key],v=>values[f.key]=v,{
      options,boolean:f.type==="boolean",number:f.type==="number",multiline:f.type==="code"
    });
    if(f.type==="symbol"){
      const note=el("small","Usa el identificador interno de tu proyecto (PBS).","csb-field-note");
      input.parentNode.append(note);
    }
    const kind=classifySymbolHint(f.label);
    if(kind&&pbs?.ids?.[kind]?.length){
      const list=el("datalist");list.id="csb-pbs-"+f.key;
      for(const id of pbs.ids[kind]){const opt=el("option");opt.value=id;list.append(opt);}
      target.append(list);input.setAttribute("list",list.id);
    }
  }
  if(["give_pokemon","gift_pokemon_once"].includes(action.id)){
    for(const group of POKEMON_GROUPS){
      const relevant=action.fields.filter(f=>f.group===group);
      const details=el("details",null,"csb-more-settings");
      details.open=group==="Básico";
      details.append(el("summary",group+" · "+relevant.length+" opciones"));
      const grid=el("div",null,"grid");
      for(const field of relevant)add(field,grid);
      details.append(grid);form.append(details);
    }
  }else{
    const simplified=action.fields.length>4;
    const important=simplified?action.fields.slice(0,3):action.fields;
    for(const field of important)add(field,mainGrid);
    if(simplified){
      const secondary=action.fields.slice(3);
      const details=el("details",null,"csb-more-settings");
      details.append(el("summary","Personalizar otros "+secondary.length+" ajustes (opcional)"));
      const grid=el("div",null,"grid");
      for(const field of secondary)add(field,grid);
      details.append(grid);form.append(details);
    }
  }
  if(!action.fields.length)form.append(el("p","Esta tarea no necesita configuración. Puedes continuar directamente.","sub"));
  area.append(form);
  const nav=el("div",null,"row");
  nav.append(button("← Volver",()=>{step=1;render();}),
   button("Ver resultado →",()=>{
    const state=validate(action,values);
    const extra=["give_pokemon","gift_pokemon_once"].includes(action.id)?giftCheck(values):[];
    if(state.errors.length||extra.length)return notice("Revisa los datos: "+[...state.errors,...extra][0]);
    step=3;render();
   },"btn primary"));
  area.append(nav);
 }
 function review(area){
  area.className="narrow";
  area.append(el("span","PASO 3 DE 3","csb-step-badge"),el("h3","Comprueba y añade tu evento"));
  let commands=[];
  try{commands=buildAction(action.id,values);}
  catch(e){notice(e.message);step=2;render();return;}
  const card=el("div",null,"card");
  card.append(el("h4",(action.icon||"✦")+" "+action.title),el("p",action.description,"sub"));
  const summary=el("div",null,"csb-value-grid");
  for(const f of action.fields.slice(0,6)){
    const item=el("div",null,"csb-value");
    item.append(el("span",f.label),el("strong",String(values[f.key]??"")));
    summary.append(item);
  }
  if(summary.childNodes.length)card.append(summary);
  card.append(el("p","Se añadirán "+commands.length+" instrucciones al evento sin borrar las anteriores.","sub"));
  const detail=el("details",null,"csb-help");
  detail.append(el("summary","Ver comandos técnicos generados (opcional)"));
  const text=commands.map(c=>({101:"Mostrar mensaje",401:"Continuar mensaje",355:"Script",655:"Seguir script",111:"Condición",411:"Si no",412:"Fin",102:"Elegir",402:"Respuesta",404:"Fin",121:"Interruptor",122:"Variable",123:"Interruptor local",201:"Cambiar mapa",106:"Esperar"}[c.code]||"Instrucción")+" · "+String(c.parameters?.[0]??"")).join("\n");
  detail.append(el("pre",text,"preview"));card.append(detail);area.append(card);
  const send=button("✓ Añadir al evento",()=>insert(commands,()=>{step=1;render();}),"btn primary");
  destination(area,send);
  const nav=el("div",null,"row");
  nav.append(send,button("← Cambiar datos",()=>{step=2;render();}));
  area.append(nav);
 }
 function messages(area){
  messageCleanup=mountVisualMessageEditor({
    host:area,
    initialText:messageText,
    onTextChange:value=>{messageText=value;},
    onInsert:commands=>insert(commands),
    renderTarget:(target,submit)=>destination(target,submit),
    initialDirective:token,
    ctx,
    initialSpeaker:speakerName,
    onSpeakerChange:value=>speakerName=value
  });
  token=null;
 }
 function catalog(area){
  area.append(el("h3","Enciclopedia de Essentials"),el("p","Busca por lo que quieres hacer. Las funciones internas y los módulos opcionales se muestran como referencias, no como acciones garantizadas.","sub"));
  const toolbar=el("div",null,"csb-catalog-toolbar");
  const tabs=el("div",null,"chips");
  for(const [key,label]of [["wiki","Comandos y funciones"],["messages","Controles de texto"]]){
    tabs.append(button(label,()=>{catalogTab=key;catalogLimit=12;selectedReference=null;render();},
      "chip"+(catalogTab===key?" selected":"")));
  }
  toolbar.append(tabs);
  const search=el("input");search.className="search";search.placeholder="Buscar por nombre, efecto o ejemplo…";search.value=catalogQuery;
  search.setAttribute("aria-label","Buscar en la enciclopedia");
  toolbar.append(search);
  const groupSelector=el("select");groupSelector.setAttribute("aria-label","Filtrar categoría de comandos");
  const categories=catalogTab==="wiki"?["Todas",...new Set(WIKI.map(w=>w.group))]:["Todas",...GROUPS];
  for(const g of categories){const opt=el("option",g);opt.value=g;groupSelector.append(opt);}
  if(categories.includes(catalogGroup))groupSelector.value=catalogGroup;else{catalogGroup="Todas";groupSelector.value="Todas";}
  toolbar.append(groupSelector);
  const auditButton=button(scanning?"Analizando…":"Comprobar funciones instaladas",async()=>{
    if(scanning)return;
    scanning=true;auditButton.disabled=true;auditButton.textContent="Indexando scripts…";
    try{
      const data=await auditProject(ctx);
      sourceAudit=data.indexed;
      notice(data.indexed.report.found+" métodos indexados · "+data.indexed.report.errors.length+" errores de lectura.");
    }catch(e){notice("No se completó el análisis: "+e.message);}
    scanning=false;auditButton.disabled=false;auditButton.textContent="Volver a analizar";
    draw();
  },"btn");
  toolbar.append(auditButton);area.append(toolbar);
  const count=el("p","","sub");area.append(count);
  const two=el("div",null,"csb-catalog-layout"),list=el("div",null,"csb-catalog-list"),inspector=el("aside",null,"csb-catalog-details");
  two.append(list,inspector);area.append(two);
  function useReference(w){
    try{
      const data=Object.fromEntries(w.args.map(p=>[p[0],p[3]]));
      action=BY_ID.get("custom_ruby");values={code:buildWiki(w,data)};
      sessionRecent=[action.id,...sessionRecent.filter(id=>id!==action.id)].slice(0,5);
      step=2;go("home");
    }catch(e){notice("La plantilla necesita revisión: "+e.message);}
  }
  function showInfo(w){
    inspector.replaceChildren();
    if(!w){inspector.append(el("p","Elige una ficha para ver qué hace, de dónde viene y cómo utilizarla.","sub"));return;}
    if(catalogTab==="messages"){
      inspector.append(el("h4",w.title),el("p",w.description,"sub"));
      inspector.append(el("pre",w.token,"preview"));
      inspector.append(button("Abrir en el editor de mensajes →",()=>{
        token=w;group=w.category;go("message");
      },"btn primary"));
      return;
    }
    const verdict=classifyReference(w,sourceAudit);
    inspector.append(el("span",w.group,"csb-step-badge"),el("h4",w.title));
    const status=el("p",verdict.label+" · "+verdict.reason,"csb-audit-"+verdict.state);
    inspector.append(status);
    inspector.append(el("p",w.note||"Referencia técnica. Revisa los parámetros y el contexto de ejecución.","sub"));
    inspector.append(el("pre",w.template,"preview"));
    if(w.args?.length){
      const params=el("div",null,"csb-params");params.append(el("strong","Parámetros configurables"));
      for(const [,label,type]of w.args){params.append(el("div",label+" · "+type,"sub"));}
      inspector.append(params);
    }
    if(/opcional|verifica|no verificado|depende|plugin|código de plugin|requiere/i.test(w.note||"")){
      inspector.append(el("p","Atención: esta receta podría requerir un plugin o configuración previa.","csb-warning"));
    }
    const actions=el("div",null,"csb-catalog-actions");
    const configure=button("Configurar esta función →",()=>useReference(w),"btn primary");
    configure.disabled=verdict.state==="missing";
    configure.title=verdict.state==="missing"?"No localizada: comprueba primero los scripts y módulos del juego.":"Configurar receta";
    actions.append(configure);
    if(w.source){
      const link=el("a","Consultar documentación ↗");link.href=w.source;link.target="_blank";link.rel="noopener noreferrer";actions.append(link);
    }
    inspector.append(actions);
  }
  function draw(){
    list.replaceChildren();
    const term=catalogQuery.trim().toLocaleLowerCase();
    const items=(catalogTab==="wiki"?WIKI:DIRECTIVES).filter(w=>{
      if(catalogGroup!=="Todas"&&(catalogTab==="wiki"?w.group:w.category)!==catalogGroup)return false;
      return !term||[w.title,w.description,w.note,w.group,w.category,w.token,w.template].filter(Boolean).join(" ").toLocaleLowerCase().includes(term);
    });
    count.textContent=items.length+" fichas disponibles · "+Math.min(catalogLimit,items.length)+" visibles";
    for(const w of items.slice(0,catalogLimit)){
      const row=button("",()=>{selectedReference=w;showInfo(w);},"csb-ref-item"+(selectedReference?.id===w.id?" active":""));
      row.append(el("strong",w.title));
      row.append(el("small",catalogTab==="wiki"?w.group:w.category));
      list.append(row);
    }
    if(!items.length)list.append(el("p","No hay coincidencias. Prueba otro término o quita el filtro.","hint"));
    if(items.length>catalogLimit)list.append(button("Mostrar "+Math.min(12,items.length-catalogLimit)+" fichas más",()=>{catalogLimit+=12;draw();},"btn"));
    const selection=items.find(w=>w.id===selectedReference?.id);
    showInfo(selection||null);
  }
  search.oninput=()=>{catalogQuery=search.value;catalogLimit=12;draw();};
  groupSelector.onchange=()=>{catalogGroup=groupSelector.value;catalogLimit=12;selectedReference=null;draw();};
  draw();
  const sources=el("div",null,"csb-source-list");
  for(const [name,url]of [["Essentials Docs",SOURCES.essentials],["LA BASE DE SKY",SOURCES.lbds]]){
    const a=el("a",name+" ↗");a.href=url;a.target="_blank";a.rel="noopener noreferrer";sources.append(a);
  }
  area.append(sources);
 }
 (async()=>{try{pbs=await loadPBS(ctx);}catch(_){} })();
 function refreshActive(){
   if(disposed)return;
   const next=activeMapId(ctx);
   if(next!==mapId){mapId=next;eventId="";pageId=0;insertionPosition="end";}
   destinationRefresh?.();
   eventBrowser?.refresh?.();
 }
 for(const key of ["map.loaded","map.unloaded","event.changed","undo","redo"]){
   try{const sub=ctx.bus?.on?.(key,refreshActive);if(sub)subscriptions.push(sub);}catch(_){}
 }
 window.addEventListener("focus",refreshActive);
 document.addEventListener("visibilitychange",refreshActive);
 menu();render();
 return()=>{disposed=true;cancelPlacement();if(eventBrowser)eventBrowser.dispose();if(messageCleanup)messageCleanup();
  subscriptions.forEach(s=>{try{s.dispose?.();}catch(_){}});
  window.removeEventListener("focus",refreshActive);
  document.removeEventListener("visibilitychange",refreshActive);
  if(advCleanup)advCleanup();fullscreenDispose();};
}
