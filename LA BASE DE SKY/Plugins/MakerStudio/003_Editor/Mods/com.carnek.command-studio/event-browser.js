import {activeMapId,eventChoices,pageChoices,availableInsertionPoints,describeCommand,isCompatible} from "./event-writer.js";
const el=(tag,text,cls)=>{const n=document.createElement(tag);if(text!==undefined&&text!==null)n.textContent=String(text);if(cls)n.className=cls;return n};
const b=(name,fn,cls="btn")=>{const n=el("button",name,cls);n.type="button";n.onclick=fn;return n};
export function getGraphic(page) {
  const g=page?.graphic||{};
  return {name:String(g.character_name??g.characterName??page?.character_name??"").trim(),tile:Number(g.tile_id??g.tileId??0),hue:Number(g.character_hue??g.characterHue??0)};
}
export function createEventBrowser(ctx,host,options={}){
 let disposed=false,mid=activeMapId(ctx),id=options.eventId||null,pid=Number(options.pageIndex||0),pos=options.position??"end";
 let activeSignature="",cache=[],query="",urls=new Map(),pending=new Set(),lastSelected="";
 const subs=[];host.replaceChildren();
 const root=el("div",null,"csb-events-workspace");
 const head=el("div",null,"csb-event-header");root.append(head);
 const createPanel=el("details",null,"csb-details");
 createPanel.append(el("summary","＋ Crear evento en este mapa"));
 const form=el("div",null,"csb-event-crud");
 const newName=el("input");newName.placeholder="Nombre del evento";newName.value="Nuevo evento";
 const newX=el("input"),newY=el("input");
 newX.type="number";newY.type="number";newX.min="0";newY.min="0";
 newX.value="0";newY.value="0";
 const create=b("Crear",()=>{
  if(mid==null)return options.onError?.(new Error("Abre primero un mapa."));
  const x=Number(newX.value),y=Number(newY.value);
  if(!Number.isSafeInteger(x)||!Number.isSafeInteger(y)||x<0||y<0)
   return options.onError?.(new Error("Las coordenadas deben ser números enteros positivos."));
  try{
   const made=ctx.events.create(mid,x,y,newName.value.trim()||"Nuevo evento");
   if(made==null)throw Error("Maker Studio rechazó la creación del evento");
   id=Number(made);pid=0;pos="end";refresh(true);createPanel.open=false;
  }catch(e){options.onError?.(e);}
 },"btn primary");
 form.append(newName,newX,newY,create);createPanel.append(form);root.append(createPanel);
 const filter=el("input");filter.className="search";filter.placeholder="Buscar evento por nombre o ID…";
 filter.oninput=()=>{query=filter.value;drawList();};root.append(filter);
 const columns=el("div",null,"csb-events-layout");
 const listing=el("section",null,"csb-event-list"),details=el("section",null,"csb-event-details");
 columns.append(listing,details);root.append(columns);host.append(root);
 const notify=()=>{const key=[mid,id,pid,pos].join(":");if(key!==lastSelected){lastSelected=key;options.onSelection?.({mapId:mid,eventId:id,pageIndex:pid,position:pos});}};
 const gameRoot=()=>ctx.editor?.gameRoot?.()||null;
 const imageApi=()=>typeof window!=="undefined"?window.__TAURI__?.core?.invoke:null;
 const getImage=async name=>{
  if(urls.has(name))return urls.get(name);
  if(pending.has(name)||!gameRoot()||!imageApi())return null;
  pending.add(name);
  try{
   const bytes=await imageApi()("get_graphic_image",{gameRoot:gameRoot(),folder:"Characters",name});
   if(disposed)return null;
   if(!Array.isArray(bytes)||!bytes.length)return null;
   const blob=new Blob([new Uint8Array(bytes)],{type:"image/png"});
   const url=URL.createObjectURL(blob);urls.set(name,url);return url;
  }catch(_){return null;}finally{pending.delete(name);}
 };
 function thumbnail(parent,page){
   const wrap=el("div","?","csb-sprite");
   const g=getGraphic(page);
   if(g.tile)wrap.textContent="▦";
   if(g.name){
     wrap.textContent="♟";wrap.title=g.name;
     getImage(g.name).then(url=>{
       if(disposed||!url||!wrap.isConnected)return;
       const img=new Image();
       img.onload=()=>{
        if(disposed||!wrap.isConnected)return;
        const canvas=document.createElement("canvas");canvas.width=40;canvas.height=40;
        const p=canvas.getContext("2d");if(!p)return;
        p.imageSmoothingEnabled=false;
        // RMXP and Essentials character sheets: 4 frames × 4 directions;
        // isolate one down-facing frame rather than showing the entire sheet.
        const cols=4,rows=4,w=img.width/cols,h=img.height/rows;
        p.clearRect(0,0,40,40);
        p.drawImage(img,w*1,h*0,w,h,0,0,40,40);
        wrap.replaceChildren(canvas);wrap.classList.add("has-image");
       };
       img.src=url;
     });
   }
   parent.append(wrap);
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
  listing.replaceChildren();
  if(mid==null){listing.append(el("p","Abre un mapa desde Maker Studio.","sub"));return;}
  const found=cache.filter(x=>[x.id,x.name].join(" ").toLowerCase().includes(query.trim().toLowerCase()));
  for(const ev of found){
   const row=b("",()=>{id=Number(ev.id);pid=0;pos="end";drawList();drawDetails();notify();},
     "csb-event-entry"+(Number(id)===Number(ev.id)?" active":""));
   let graphic=null;
   try{graphic=ctx.events.getFull(mid,ev.id)?.pages?.[0];}catch(_){}
   thumbnail(row,graphic);
   const info=el("span",null,"csb-event-entry-details");
   info.append(el("strong","#"+ev.id+" · "+ev.name),
               el("small","("+ev.x+", "+ev.y+") · "+ev.pages+" pág."));
   row.append(info);listing.append(row);
  }
  if(!found.length)listing.append(el("p","No hay eventos con ese nombre o ID.","sub"));
 }
 function drawDetails(){
  details.replaceChildren();
  if(mid==null||id==null){details.append(el("p","Selecciona un evento de la lista para ver sus páginas y comandos.","sub"));return;}
  let full;
  try{full=ctx.events.getFull(mid,Number(id));}catch(e){options.onError?.(e);}
  if(!full?.pages?.length){details.append(el("p","El evento dejó de existir. Actualiza el mapa.","sub"));return;}
  if(pid>=full.pages.length){pid=0;pos="end";}
  const heading=el("div",null,"csb-event-detail-head");
  heading.append(el("strong",full.name+" · Evento #"+id));
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
  const info=el("p",graphic.name?"Gráfico: "+graphic.name:graphic.tile?"Gráfico: tile #"+graphic.tile:"Sin gráfico · evento invisible","sub");
  details.append(info);
  const commands=(page.list||[]).filter(c=>c.code!==0);
  const points=availableInsertionPoints(commands);
  const choices=new Map(points.map(x=>[x.index,x]));
  details.append(el("p","Elige una línea con ＋ para insertar antes del siguiente comando.","sub"));
  const stack=el("div",null,"csb-command-list");
  for(let i=0;i<=commands.length;i++){
   const point=choices.get(i);
   if(point){
     const add=b((pos===i||((pos==="end")&&i===commands.length))?"✓ Insertar aquí":"＋ Insertar aquí",()=>{
       pos=i;drawDetails();notify();
     },"csb-command-slot"+((pos===i||(pos==="end"&&i===commands.length))?" active":""));
     add.style.marginLeft=Math.min(point.indent*14,72)+"px";
     stack.append(add);
   }
   if(i<commands.length){
     const cmd=commands[i];
     const line=el("div",describeCommand(cmd),"csb-command-entry");
     line.style.marginLeft=Math.min((cmd.indent||0)*14,72)+"px";
     stack.append(line);
   }
  }
  details.append(stack);
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
    subs.forEach(x=>{try{x?.dispose?.()}catch(_){}});
    document.removeEventListener("visibilitychange",onFocus);
    window.removeEventListener("focus",onFocus);
    root.removeEventListener("pointerdown",onPointer);
    urls.forEach(u=>URL.revokeObjectURL(u));urls.clear();host.replaceChildren();
   }
 };
}
