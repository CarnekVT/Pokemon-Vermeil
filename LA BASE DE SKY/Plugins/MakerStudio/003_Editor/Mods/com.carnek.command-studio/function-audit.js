import {scanProject} from "./source-index.js";
export function classifyReference(reference,index){
 const note=String(reference?.note||"");
 const template=String(reference?.template||"");
 const methods=new Set((index?.methods||[]).map(m=>String(m.name||m.title||"").replace(/\(.*/,"")));
 const match=[...template.matchAll(/\b(?:pb[A-Z][A-Za-z0-9_!?]*|setBattleRule|hide_choice|rename_choice)\b/g)].map(m=>m[0]);
 const requires=/opcional|requiere.*plugin|no verificado|verifica.*módulo|módulo.+instalado/i.test(note);
 if(!index)return{state:requires?"plugin":"pending",label:requires?"Depende de otro sistema":"Sin verificar",reason:"Indexa el proyecto para comprobar la función."};
 if(match.length&&match.every(m=>methods.has(m)))return{state:"verified",label:"Método localizado",reason:"La firma existe en los scripts; la ejecución aún depende del contexto."};
 if(requires)return{state:"plugin",label:"Requiere comprobar complemento",reason:"La documentación indica una función opcional."};
 if(!index.report?.complete)return{state:"pending",label:"Análisis parcial",reason:"Algunos scripts no pudieron leerse."};
 if(match.length)return{state:"missing",label:"No localizado",reason:"No figura en los archivos indexados; podría generarse dinámicamente."};
 return{state:"pending",label:"Expresión avanzada",reason:"No equivale a un método directo: requiere validación contextual."};
}
export async function auditProject(ctx,onProgress=()=>{}){
 const indexed=await scanProject(ctx,onProgress,{cancelled:false});
 return{indexed,plugins:ctx.plugins?.list?.()||[]};
}
