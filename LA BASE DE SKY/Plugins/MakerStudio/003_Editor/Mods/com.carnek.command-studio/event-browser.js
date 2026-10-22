import {activeMapId,eventChoices,pageChoices,availableInsertionPoints,describeCommand,isCompatible} from "./event-writer.js";
import {drawEventSprite} from "./sprite-crop.js";
import {armPlacement,cancelPlacement} from "./placement.js";
const el=(tag,text,cls)=>{const n=document.createElement(tag);if(text!==undefined&&text!==null)n.textContent=String(text);if(cls)n.className=cls;return n};
const b=(name,fn,cls="btn")=>{const n=el("button",name,cls);n.type="button";n.onclick=fn;return n};
export function getGraphic(page) {
  const g=page?.graphic||{};
  return {name:String(g.character_name??g.characterName??page?.character_name??"").trim(),tile:Number(g.tile_id??g.tileId??0),hue:Number(g.character_hue??g.characterHue??0)};
}
export function createEventBrowser(ctx,host,options={}){
 let disposed=false,mid=activeMapId(ctx),id=options.eventId||null,pid=Number(options.pageIndex||0),pos=options.position??"end";
 let activeSignature="",cache=[],query="",urls=new Map(),pending=new Map(),lastSelected="";
 const subs=[];host.replaceChildren();
 const root=el("div",null,"csb-events-workspace");
 const head=el("div",null,"csb-event-header");root.append(head);
 const intro=el("div",null,"csb-event-intro");
 intro.append(el("strong","Organiza los eventos del mapa"),
   el("p","1. Crea o elige un evento · 2. Selecciona su página y posición · 3. Añade acciones.","sub"));
 root.append(intro);
 const createPanel=el("section",null,"csb-event-create");
 createPanel.append(el("strong","＋ Nuevo evento"),el("p","Dale un nombre y elige una casilla del mapa. Se seleccionará automáticamente para seguir editándolo.","sub"));
 const form=el("div",null,"csb-event-new-form");
 const newName=el("input");newName.placeholder="Ej.: Científico, Puerta, Cofre";newName.value="Nuevo evento";
 newName.setAttribute("aria-label","Nombre del nuevo evento");
 const newX=el("input"),newY=el("input");
 newX.type="number";newY.type="number";newX.min="0";newY.min="0";
 newX.value="0";newY.value="0";newX.setAttribute("aria-label","Coordenada X");
 newY.setAttribute("aria-label","Coordenada Y");
 const nameField=el("label",null,"csb-event-new-field");nameField.append(el("span","Nombre"),newName);
 const coords=el("div",null,"csb-event-new-coords");
 const xField=el("label",null,"csb-event-new-field"),yField=el("label",null,"csb-event-new-field");
 xField.append(el("span","Casilla X"),newX);yField.append(el("span","Casilla Y"),newY);
 coords.append(xField,yField);
 const buttons=el("div",null,"csb-event-new-actions");
 let placementCallback=null;
 function createEvent(addAction){
  if(mid==null)return options.onError?.(new Error("Abre primero un mapa."));
  const x=Number(newX.value),y=Number(newY.value);
  if(!Number.isSafeInteger(x)||!Number.isSafeInteger(y)||x<0||y<0)
   return options.onError?.(new Error("Las coordenadas X e Y deben ser enteros no negativos."));
  try{
   const made=ctx.events.create(mid,x,y,newName.value.trim()||"Nuevo evento");
   if(made==null)throw Error("Maker Studio rechazó la creación del evento");
   id=Number(made?.id??made);
   if(!Number.isSafeInteger(id)||id<1)throw Error("Maker Studio no devolvió un ID válido.");
   pid=0;pos="end";refresh(true);
   if(addAction)options.onCreate?.();
  }catch(e){options.onError?.(e);}
 }
 const create=b("＋ Crear evento",()=>createEvent(false),"btn");
 const createAndEdit=b("Crear y añadir acción →",()=>createEvent(true),"btn primary");
 const pick=b("📍 Elegir casilla en el mapa",()=>{
  if(placementCallback)cancelPlacement(placementCallback);
  placementCallback=selection=>{
    if(disposed)return;
    if(selection.mapId!==mid){options.onError?.(new Error("Elige una casilla del mapa activo y vuelve a intentarlo."));return;}
    newX.value=String(selection.x);newY.value=String(selection.y);
    options.onNotice?.("Casilla ("+selection.x+", "+selection.y+") seleccionada. Pulsa Crear evento.");
    newName.focus();
  };
  if(!armPlacement(ctx,placementCallback))
    options.onError?.(new Error("No se pudo activar la herramienta de selección del mapa."));
  else options.onNotice?.("Haz clic en una casilla del mapa para indicar dónde crear el evento.");
 },"btn csb-event-pick");
 buttons.append(pick,create,createAndEdit);
 newName.addEventListener("keydown",ev=>{if(ev.key==="Enter"){ev.preventDefault();createEvent(true);}});
 form.append(nameField,coords,buttons);createPanel.append(form);root.append(createPanel);
 const filter=el("input");filter.className="search";filter.placeholder="Buscar evento por nombre o ID…";
 filter.oninput=()=>{query=filter.value;drawList();};root.append(filter);
 const columns=el("div",null,"csb-events-layout");
 const listing=el("section",null,"csb-event-list"),details=el("section",null,"csb-event-details");
 columns.append(listing,details);root.append(columns);host.append(root);
 const listResults=el("div",null,"csb-event-results");listing.append(createPanel,filter,listResults);
 const notify=()=>{const key=[mid,id,pid,pos].join(":");if(key!==lastSelected){lastSelected=key;options.onSelection?.({mapId:mid,eventId:id,pageIndex:pid,position:pos});}};
 const gameRoot=()=>ctx.editor?.gameRoot?.()||null;
 const imageApi=()=>typeof window!=="undefined"?window.__TAURI__?.core?.invoke:null;
 const getImage=name=>{
  if(urls.has(name))return Promise.resolve(urls.get(name));
  if(pending.has(name))return pending.get(name);
  if(!gameRoot()||!imageApi())return Promise.resolve(null);
  const task=(async()=>{
   try{
    const data=await imageApi()("get_graphic_image",{gameRoot:gameRoot(),folder:"Characters",name});
    if(disposed||!Array.isArray(data)||!data.length)return null;
    const url=URL.createObjectURL(new Blob([new Uint8Array(data)],{type:"image/png"}));
    urls.set(name,url);return url;
   }catch(_){return null;}finally{pending.delete(name);}
  })();
  pending.set(name,task);return task;
 };
 function thumbnail(parent,page){
  const wrap=el("div","?","csb-sprite");
  const graphic=getGraphic(page);
  wrap.setAttribute("aria-label",graphic.name?"Gráfico "+graphic.name:graphic.tile?"Tile "+graphic.tile:"Evento sin gráfico");
  if(graphic.tile)wrap.textContent="▦";
  if(graphic.name){
   wrap.textContent="…";wrap.title=graphic.name;
   getImage(graphic.name).then(url=>{
    if(!url||disposed||!wrap.isConnected)return;
    const img=new Image();
    img.onload=()=>{
     if(disposed||!wrap.isConnected)return;
     const canvas=document.createElement("canvas");
     if(drawEventSprite(canvas,img,graphic.name,48)){
      wrap.replaceChildren(canvas);wrap.classList.add("has-image");
     }else wrap.textContent="?";
    };
    img.onerror=()=>wrap.textContent="?";img.src=url;
   });
  }
  parent.append(wrap);
 }
 function summarize(command){
   const code=Number(command.code),script=String(command.parameters?.[0]??"");
   const groups={
    101:["💬","Hablar","dialogue"],102:["❓","Presentar opciones","choice"],
    111:["🔀","Comprobar una condición","logic"],112:["🔁","Repetir acciones","logic"],
    121:["✅","Cambiar interruptor","state"],122:["🔢","Modificar variable","state"],
    123:["🔒","Cambiar interruptor local","state"],201:["🗺️","Cambiar de mapa","world"],
    205:["🚶","Mover personaje","world"],106:["⏳","Esperar","world"],
    250:["🔊","Reproducir sonido","audio"],241:["🎵","Reproducir música","audio"],
    411:["↪","Si no se cumple…","logic"],412:["✓","Termina la condición","logic"],
    402:["↳","Al elegir una respuesta","choice"],404:["✓","Finalizar elecciones","choice"],
    355:["⚙","Acción del juego (Ruby)","script"],
    108:["📝","Comentario para desarrolladores","note"]
   };
   const info=groups[code]||["◦","Acción #"+code,"generic"];
   let detail=script.replace(/\s+/g," ").slice(0,115);
   if(code===355){
    if(/pbAddPokemon|Pokemon\.new/.test(script))info[1]="Entregar o configurar Pokémon";
    else if(/pbReceiveItem/.test(script))info[1]="Entregar objeto";
    else if(/NameBox/.test(script))info[1]="Mostrar nombre del hablante";
    else if(/TrainerBattle|WildBattle/.test(script))info[1]="Iniciar combate";
    else if(/\$game_self_switches/.test(script))info[1]="Comprobar interruptor local";
   }
   if(code===101)detail=String(command.parameters?.[0]??"").replace(/\\[a-z]+\[[^\]]*\]/gi,"").slice(0,115);
   if(code===111)detail="El juego decidirá qué acciones ejecutar";
   return {icon:info[0],title:info[1],kind:info[2],detail};
 }
 // Continuations belong to their first command. Collapse together for readability.
 function groupCommands(commands){
  const result=[];
  const connected={101:401,108:408,355:655,209:509,302:605};
  for(let i=0;i<commands.length;){
   const first=i,cmd=commands[i],linked=connected[cmd.code];
   i++;
   while(linked&&i<commands.length&&commands[i].code===linked)i++;
   result.push({start:first,end:i,cmd,children:commands.slice(first,i),...summarize(cmd)});
  }
  return result;
 }
 function refresh(force=false){
  if(disposed)return;
  let current=null;try{current=activeMapId(ctx);}catch(_){}
  if(current!==mid){mid=current;id=null;pid=0;pos="end";activeSignature="";cache=[];}
  if(mid==null||!isCompatible(ctx)){cache=[];draw();notify();return;}
  try{
   const next=eventChoices(ctx,mid);
   const signature=JSON.stringify(next.map(x=>[x.id,x.name,x.x,x.y,x.pages]));
   if(force||signature!==activeSignature){
    activeSignature=signature;cache=next;
    if(id!=null&&!next.some(x=>x.id===Number(id))){id=null;pid=0;pos="end";}
    draw();
   }
  }catch(e){options.onError?.(e);cache=[];draw();}
  notify();
 }
 function draw(){head.replaceChildren();head.append(el("strong",mid==null?"Abre un mapa":"Mapa "+mid+" · "+cache.length+" eventos"));
  head.append(b("↻ Actualizar",()=>refresh(true),"btn"));
  drawList();drawDetails();
 }
 function drawList(){
  const previousTop=listResults.scrollTop||0;
  listResults.replaceChildren();
  if(mid==null){listResults.append(el("p","Abre un mapa desde Maker Studio.","sub"));return;}
  const found=cache.filter(x=>[x.id,x.name].join(" ").toLowerCase().includes(String(query??"").trim().toLowerCase()));
  const overview=el("div",null,"csb-list-intro");
  overview.append(el("strong","Personajes y objetos"),el("span",found.length+" de "+cache.length,"sub"));
  listResults.append(overview);
  for(const ev of found){
   const row=b("",()=>{id=Number(ev.id);pid=0;pos="end";drawList();drawDetails();notify();},
     "csb-event-entry"+(Number(id)===Number(ev.id)?" active":""));
   let graphic=null;
   try{graphic=ctx.events.getFull(mid,ev.id)?.pages?.[0];}catch(_){}
   thumbnail(row,graphic);
   const info=el("span",null,"csb-event-entry-details");
   info.append(el("strong",ev.name||"Evento sin nombre"),
               el("small","ID "+ev.id+" · "+ev.pages+" página"+(ev.pages!==1?"s":"")+" · ("+ev.x+", "+ev.y+")"));
   row.append(info);listResults.append(row);
  }
  if(!found.length)listResults.append(el("p","No hay eventos con ese nombre o ID.","sub"));
  listResults.scrollTop=previousTop;
 }
 function drawDetails(){
  details.replaceChildren();
  if(mid==null||id==null){const blank=el("div",null,"csb-event-empty");blank.append(el("strong","Comienza con un evento"),el("p","Selecciona un evento existente o crea uno nuevo usando el formulario de la izquierda.","sub"),b("＋ Crear nuevo evento",()=>{newName.focus();newName.select();},"btn primary"));details.append(blank);return;}
  let full;
  try{full=ctx.events.getFull(mid,Number(id));}catch(e){options.onError?.(e);}
  if(!full?.pages?.length){details.append(el("p","El evento dejó de existir. Actualiza el mapa.","sub"));return;}
  if(pid>=full.pages.length){pid=0;pos="end";}
  const heading=el("div",null,"csb-event-detail-head");
  heading.append(el("div",null,"csb-selected-name"));
  heading.firstChild.append(el("span","EVENTO SELECCIONADO","csb-eyebrow"),
    el("strong",full.name||"Sin nombre"),el("span","ID "+id+" · ("+full.x+", "+full.y+")","sub"));
  heading.append(b("＋ Añadir acción",()=>options.onCreate?.(),"btn primary"));
  details.append(heading);
  const tabs=el("div",null,"csb-page-tabs");
  for(let i=0;i<full.pages.length;i++){
   const button=b("Página "+(i+1),()=>{pid=i;pos="end";drawDetails();notify();},
     "csb-page-tab"+(pid===i?" selected":""));
   tabs.append(button);
  }
  details.append(tabs);
  const edit=el("details",null,"csb-details");edit.append(el("summary","Editar nombre, posición o eliminar este evento"));
 const editPanel=el("div",null,"csb-event-crud");
 const rename=el("input");rename.value=full.name;rename.setAttribute("aria-label","Nuevo nombre del evento");
 const x=el("input"),y=el("input");
 x.type="number";y.type="number";x.min="0";y.min="0";x.value=full.x;y.value=full.y;
 editPanel.append(rename,x,y);
 editPanel.append(b("Guardar nombre y posición",()=>{
  try{
   const xx=Number(x.value),yy=Number(y.value);
   if(!Number.isSafeInteger(xx)||!Number.isSafeInteger(yy)||xx<0||yy<0)throw Error("Coordenadas inválidas");
   if(rename.value.trim()&&rename.value!==full.name)ctx.events.rename(mid,id,rename.value.trim());
   if(xx!==full.x||yy!==full.y)ctx.events.move(mid,id,xx,yy);
   refresh(true);
  }catch(e){options.onError?.(e);}
 },"btn"));
 editPanel.append(b("Eliminar evento",async()=>{
   try{
    const approved=await ctx.ui.confirmDestructive?.({title:"Eliminar evento #"+id,message:"Se borrará "+full.name+" y todas sus páginas. Podrás usar Deshacer.",confirmLabel:"Eliminar evento"});
    if(!approved)return;
    ctx.events.delete(mid,id);id=null;pid=0;pos="end";refresh(true);
   }catch(e){options.onError?.(e);}
 },"btn"));
 edit.append(editPanel);details.append(edit);
 const page=full.pages[pid];
  const graphic=getGraphic(page);
  const info=el("p",graphic.name?"Gráfico: "+graphic.name:graphic.tile?"Gráfico: tile #"+graphic.tile:"Sin gráfico (invisible en el mapa)","sub");
  details.append(info);
  const commands=(page.list||[]).filter(c=>c.code!==0);
  const points=availableInsertionPoints(commands);
  const choices=new Map(points.map(x=>[x.index,x]));
  const tip=el("div",null,"csb-event-helper");
  tip.append(el("strong","¿Dónde quieres añadir la próxima acción?"),
    el("p","Pulsa un espacio entre acciones. Después elige «Crear acción».","sub"));
  details.append(tip);
  const stack=el("div",null,"csb-command-list");
  const sections=groupCommands(commands);
  let selectedSlot=null;
  function insertion(index,indent){
    const place=choices.get(index);
    if(!place)return;
    const selected=Number(pos=== "end"?commands.length:pos)===index;
    const btnSlot=b(selected?"✓ Aquí se insertará":"＋ Insertar aquí",()=>{
      pos=index;notify();
      stack.querySelectorAll(".csb-command-slot").forEach(node=>{
       node.classList.toggle("active",Number(node.dataset.index)===index);
       node.textContent=Number(node.dataset.index)===index?"✓ Aquí se insertará":"＋ Insertar aquí";
      });
      selectedSlotText.textContent="Posición elegida: "+(index===0?"Inicio":index===commands.length?"Final":"Después del paso "+index);
    },"csb-command-slot"+(selected?" active":""));
    btnSlot.dataset.index=String(index);
    btnSlot.style.marginLeft=Math.min(indent*12,64)+"px";
    stack.append(btnSlot);
  }
  const selectedSlotText=el("span","","csb-selected-insertion");
  for(const item of sections){
   const indent=Number(item.cmd.indent||0);
   insertion(item.start,indent);
   const card=el("div",null,"csb-event-command csb-kind-"+item.kind);
   card.style.marginLeft=Math.min(indent*12,64)+"px";
   const row=el("div",null,"csb-event-command-row");
   row.append(el("span",item.icon,"csb-command-icon"));
   const content=el("div",null,"csb-event-command-info");
   content.append(el("strong",item.title));
   if(item.detail)content.append(el("span",item.detail,"csb-command-snippet"));
   row.append(content);
   row.append(el("small","Paso "+(item.start+1),"csb-command-count"));
   card.append(row);
   if(item.kind==="script"||item.children.length>1){
    const full=el("details",null,"csb-command-code");
    full.append(el("summary","Ver "+item.children.length+" línea"+(item.children.length===1?"":"s")+" de detalle"));
    const raw=item.children.map(c=>String(c.parameters?.[0]??"")).join("\n");
    full.append(el("pre",raw,"csb-command-raw"));card.append(full);
   }
   stack.append(card);
  }
  insertion(commands.length,0);
  if(!sections.length)stack.append(el("p","Este evento aún no tiene acciones. Puedes insertar la primera aquí.","sub"));
  details.append(stack);
  const selectionBar=el("div",null,"csb-event-selection-bar");
  const chosen=Number(pos==="end"?commands.length:pos);
  selectedSlotText.textContent="Posición elegida: "+(chosen===0?"Inicio":chosen===commands.length?"Final":"Después del paso "+chosen);
  selectionBar.append(selectedSlotText,b("＋ Crear acción aquí",()=>options.onCreate?.(),"btn primary"));
  details.append(selectionBar);
  if(!points.some(x=>x.index===pos)&&pos!=="end"){pos="end";notify();}
  const last=el("p","La inserción se valida antes de guardar y es deshacible en Maker Studio.","sub");
  details.append(last);
 }
 const reactive=e=>{if(!e||e.mapId===undefined||Number(e.mapId)===mid)refresh(true)};
 const mapReactive=()=>refresh(true);
 for(const event of ["map.loaded","map.unloaded","event.changed","undo","redo"]){
  try{subs.push(ctx.bus?.on?.(event,event.startsWith("map.")?mapReactive:reactive));}catch(_){}
 }
 // Tab switches may not fire map.loaded: check on focus/pointer navigation.
 const onFocus=()=>refresh(false);
 const onPointer=()=>{if(activeMapId(ctx)!==mid)refresh(true)};
 document.addEventListener("visibilitychange",onFocus);
 window.addEventListener("focus",onFocus);
 root.addEventListener("pointerdown",onPointer);
 refresh(true);
 return {
   refresh:()=>refresh(true),
   selection:()=>({mapId:mid,eventId:id,pageIndex:pid,position:pos}),
   setSelection(value={}){
    refresh(false);
    if(value.mapId!=null&&Number(value.mapId)!==mid)return;
    if(value.eventId!=null&&cache.some(x=>Number(x.id)===Number(value.eventId)))id=Number(value.eventId);
    if(value.pageIndex!=null)pid=Number(value.pageIndex);
    if(value.position!==undefined)pos=value.position;
    drawDetails();drawList();notify();
   },
   dispose(){
    disposed=true;
    if(placementCallback)cancelPlacement(placementCallback);
    subs.forEach(x=>{try{x?.dispose?.()}catch(_){}});
    document.removeEventListener("visibilitychange",onFocus);
    window.removeEventListener("focus",onFocus);
    root.removeEventListener("pointerdown",onPointer);
    urls.forEach(u=>URL.revokeObjectURL(u));urls.clear();host.replaceChildren();
   }
 };
}
