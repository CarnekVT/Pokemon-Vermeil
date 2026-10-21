// Safe, undoable event authoring through the documented Maker Studio API 1.0.1+.
// Never manipulate Data/MapXXX.rxdata directly. Never replace pages by default.
function requireEvents(ctx){
 const e=ctx?.events;
 for(const name of ["list","getFull","update","validateEvent","createCommand"])
  if(typeof e?.[name]!=="function")throw Error("Tu versión de Maker Studio no admite events."+name+"; requiere API 1.0.1+.");
 return e;
}
export function isCompatible(ctx){
 try{requireEvents(ctx);return true;}catch(_){return false;}
}
export function activeMapId(ctx){
 try{const id=ctx.editor?.activeMapId?.();return id==null?null:Number(id);}catch(_){return null;}
}
export function eventChoices(ctx,mapId){
 if(mapId==null)return [];
 const e=requireEvents(ctx);
 return (e.list(mapId)||[]).map(x=>({id:Number(x.id),name:String(x.name||"Evento "+x.id),x:x.x,y:x.y,pages:x.pages}));
}
export function pageChoices(ctx,mapId,eventId){
 if(mapId==null||!Number.isFinite(Number(eventId)))return [];
 const event=requireEvents(ctx).getFull(mapId,Number(eventId));
 return (event?.pages||[]).map((p,i)=>({index:i,count:(p.list||[]).filter(x=>x.code!==0).length,trigger:p.trigger}));
}
function pack(ctx,list) {
 if(!Array.isArray(list)||!list.length)throw Error("No hay comandos para insertar.");
 const out=[];for(const item of list){
  if(!Number.isInteger(item.code)||!Array.isArray(item.parameters))throw Error("Comando inválido");
  if(item.code===0)throw Error("El terminador 0 es gestionado por Maker Studio.");
  if(!Number.isInteger(item.indent)||item.indent<0)throw Error("Indentación inválida");
  // Host event pages handle Script continuations and Ruby. Keep escaped text raw.
  const cmd=ctx.events.createCommand(item.code,item.parameters);
  if(!cmd)throw Error("Maker Studio no pudo crear comando "+item.code);
  cmd.indent=item.indent;
  out.push(cmd);
 }
 return out;
}
export function validateSequence(list) {
 if(!Array.isArray(list)||!list.length)throw Error("Secuencia vacía");
 let depth=0;let prev=null;
 for(const c of list){
  if(c.code===0)throw Error("No insertes código terminador.");
  if([401,408,655].includes(c.code)&&!prev)throw Error("Continuación huérfana");
  if(c.code===111||c.code===112)depth++;
  if(c.code===412||c.code===413)depth--;
  if(depth<0)throw Error("Bloque cerrado sin abrirlo");
  prev=c;
 }
 if(depth!==0)throw Error("Quedan condiciones o bucles sin cerrar.");
 return true;
}
function copyPageList(page){
 const list=page.list;
 if(!Array.isArray(list))throw Error("No se pudo leer la lista de comandos de la página");
 return list.slice(-1)[0]?.code===0?list.slice(0,-1):list.slice();
}
export function previewInsertion(ctx,{mapId,eventId,pageIndex=0,position="end",commands}){
 const e=requireEvents(ctx);
 if(mapId==null)throw Error("Abre un mapa.");
 if(!Number.isInteger(Number(eventId))||Number(eventId)<1)throw Error("Selecciona un evento.");
 const current=e.getFull(Number(mapId),Number(eventId));
 if(!current)throw Error("No se encuentra ese evento en el mapa actual");
 if(!Array.isArray(current.pages)||!current.pages[pageIndex])throw Error("Página no disponible");
 validateSequence(commands);
 // Current command list only changes on selected page.
 const original=copyPageList(current.pages[pageIndex]);
 const addition=pack(ctx,commands);
 // Explicit insertion at top-level boundaries only; never inside branches
 // or after a text/script continuation for an unrelated block.
 let at=position==="start"?0:original.length;
 if(typeof position==="number"&&Number.isInteger(position)){
  if(position<0||position>original.length)throw Error("Posición fuera de rango");
  const next=original[position];
  if(next&&next.indent!==0)throw Error("No se puede insertar dentro de un bloque sin conocer su indentación");
  if(next&&[401,408,655,402,403,404,411,412,413].includes(next.code))throw Error("No se puede cortar una estructura de eventos");
  at=position;
 }
 const merged=[...original.slice(0,at),...addition,...original.slice(at)];
 // No original terminator: ctx.events.update() re-adds code-0.
 current.pages[pageIndex].list=merged;
 const verdict=e.validateEvent(current);
 if(!verdict?.valid)throw Error("Validación fallida: "+(verdict?.errors||[]).join("; "));
 return{event:current,oldCount:original.length,added:addition.length,newCount:merged.length,at,pageIndex,mapId:Number(mapId),eventId:Number(eventId)};
}
export function applyInsertion(ctx,options){
 const preview=previewInsertion(ctx,options);
 ctx.events.update(preview.mapId,preview.event);
 return{mapId:preview.mapId,eventId:preview.eventId,pageIndex:preview.pageIndex,inserted:preview.added,after:preview.newCount};
}
export function eventSignature(page){
 const list=page?.list||[];
 return list.filter(c=>c.code!==0).map(c=>c.code+":"+String(c.indent)).join(",");
}
