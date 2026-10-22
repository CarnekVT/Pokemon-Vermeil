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
// Index boundaries are positions between commands without the terminal 0.
// Conservative parsing: treat linked continuation/branch markers as indivisible.
export function availableInsertionPoints(commands) {
  const list=(commands||[]).filter(c=>c.code!==0);
  const out=[];
  const continuation=new Set([401,408,509,605,655]);
  const headers=new Set([101,108,209,302,355]);
  const marks=new Set([402,403,404,411,412,413]);
  for(let i=0;i<=list.length;i++){
    const prev=list[i-1],next=list[i];
    if(next&&continuation.has(next.code))continue;
    if(prev&&headers.has(prev.code)&&next&&continuation.has(next.code))continue;
    if(next&&[402,403,404,411,412,413].includes(next.code)){
      // If the current branch body ends here, new commands go INSIDE that branch.
      // Some end markers may represent empty branches. Empty branch insertion
      // is only offered if immediately preceded by its matching branch marker.
    }
    if(next&&next.code===509)continue;
    if(prev&&prev.code===209&&next&&next.code===509)continue;
    if(prev&&prev.code===102&&next&&next.code===402)continue;
    if(prev&&prev.code===102&&next&&next.code===403)continue;
    let indent=0;
    if(next&&marks.has(next.code)){
      if([404,412,413].includes(next.code))indent=Math.max(0,Number(next.indent||0)+1);
      else if([402,403,411].includes(next.code))indent=Math.max(0,Number(next.indent||0)+1);
    }else if(next)indent=Number(next.indent||0);
    else if(prev){
      indent=Number(prev.indent||0);
      if([404,412,413].includes(prev.code))indent=Math.max(0,indent);
    }
    // Prevent insertion after a branch opening but before its first branch label.
    if(prev&&[102].includes(prev.code)&&next?.code===402)continue;
    if(!Number.isInteger(indent)||indent<0||indent>40)continue;
    out.push({index:i,indent,after:prev?.code??null,before:next?.code??null,label:i===0?"Al principio":i===list.length?"Al final":"Tras "+describeCommand(prev)});
  }
  return out;
}
export function describeCommand(command) {
  if(!command)return "Inicio";
  const names={101:"Diálogo",401:"Línea de texto",102:"Opciones",402:"Respuesta",403:"Cancelar opciones",404:"Fin de opciones",111:"Condición",411:"Si no",412:"Fin de condición",112:"Bucle",413:"Fin de bucle",355:"Script",655:"Continuación de script",108:"Comentario",408:"Comentario largo",121:"Interruptor",122:"Variable",123:"Interruptor local",201:"Transferir",106:"Esperar",209:"Mover evento",509:"Movimiento"};
  const param=String(command.parameters?.[0]??"").replace(/\s+/g," ").slice(0,42);
  return(names[command.code]||"Comando "+command.code)+(param?" · "+param:"");
}
export function previewInsertion(ctx,{mapId,eventId,pageIndex=0,position="end",commands}){
 const api=requireEvents(ctx);
 const mid=Number(mapId),eid=Number(eventId),pid=Number(pageIndex);
 if(!Number.isInteger(mid)||mid<1)throw Error("Abre un mapa válido.");
 if(!Number.isInteger(eid)||eid<1)throw Error("Selecciona un evento válido.");
 if(!Number.isInteger(pid)||pid<0)throw Error("Página inválida.");
 const event=api.getFull(mid,eid);
 if(!event?.pages?.[pid])throw Error("El evento/página ya no existe: refresca la lista.");
 validateSequence(commands);
 const original=copyPageList(event.pages[pid]);
 const slots=availableInsertionPoints(original);
 const at=position==="start"?0:position==="end"?original.length:Number(position);
 const choice=slots.find(x=>x.index===at);
 if(!choice||!Number.isInteger(at))throw Error("Este punto separaría comandos unidos o dañaría la estructura. Elige una línea de inserción permitida.");
 const addition=pack(ctx,commands).map(cmd=>({...cmd,indent:cmd.indent+choice.indent}));
 const merged=[...original.slice(0,at),...addition,...original.slice(at)];
 event.pages[pid].list=merged;
 const validity=api.validateEvent(event);
 if(!validity?.valid)throw Error("Validación del editor: "+(validity?.errors||[]).join("; "));
 return{event,oldCount:original.length,added:addition.length,newCount:merged.length,at,indent:choice.indent,pageIndex:pid,mapId:mid,eventId:eid};
}
export function applyInsertion(ctx,options){
 const p=previewInsertion(ctx,options);
 ctx.events.update(p.mapId,p.event);
 return{mapId:p.mapId,eventId:p.eventId,pageIndex:p.pageIndex,inserted:p.added,after:p.newCount};
}
export function eventSignature(page) {
 return (page?.list||[]).filter(x=>x.code!==0).map(x=>x.code+":"+x.indent).join(",");
}
