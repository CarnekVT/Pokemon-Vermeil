// Click-to-place event coordinates using Maker Studio's standard map tool API.
// No direct changes to MapXXX.rxdata or undocumented DOM access.
export const TOOL = 'com.carnek.command-studio.event-position';
let pending = null;
export function armPlacement(ctx, callback) {
  if(typeof ctx?.editor?.setTool !== 'function' ||
     typeof ctx?.tools?.registerTool !== 'function' ||
     typeof callback !== 'function')return false;
  pending = {callback,previous:readTool(ctx)};
  try {ctx.editor.setTool(TOOL);return true;}
  catch(_) {pending=null;return false;}
}
function readTool(ctx){
  for(const key of ['activeToolId','currentToolId','getActiveTool','getTool']){
    try{const v=ctx.editor?.[key]?.();if(typeof v==='string'&&v&&v!==TOOL)return v;}catch(_){}
  }
  return null;
}
export function cancelPlacement(callback){
  if(pending && (!callback||pending.callback===callback))pending=null;
}
export function registerPlacementTool(ctx){
  if(typeof ctx?.tools?.registerTool !== 'function')return;
  ctx.tools.registerTool({
    id:TOOL,label:'Command Studio · elegir casilla',icon:'📍',
    onPointerDown(e){
      if(!pending)return;
      if(e?.buttons && !(e.buttons&1))return;
      const x=Number(e?.tileX),y=Number(e?.tileY),mapId=Number(e?.mapId);
      if(!Number.isInteger(x)||!Number.isInteger(y)||x<0||y<0||
         !Number.isInteger(mapId)||mapId<1)return;
      const current=pending;pending=null;
      try{current.callback({mapId,x,y});}
      finally{
        const next=current.previous || 'select';
        if(next!==TOOL){try{ctx.editor?.setTool?.(next);}catch(_){}}
      }
    },
    onDeactivate(){pending=null;}
  });
}
