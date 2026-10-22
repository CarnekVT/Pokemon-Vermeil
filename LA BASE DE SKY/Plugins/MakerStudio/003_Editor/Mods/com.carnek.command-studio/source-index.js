// Completeness-first Ruby source index: scans ALL *.rb under Data/Scripts and Plugins.
// Files that cannot be read are surfaced in the report; never claim complete coverage.
const POSITIVE=/^pb[A-Z]|^get_self$|^get_character$|^setBattleRule$|^pbGet/;
const IGNORE_FOLDERS=new Set([".git","node_modules","__pycache__","vendor",".vscode"]);
const TYPES=["auto","string","symbol","integer","number","boolean","nil","expression"];

function normalizedEntry(e,parent){
 const raw=typeof e==="string"?e:String(e?.path||e?.name||"");
 const name=raw.replace(/\\/g,"/").replace(/\/$/,"").split("/").pop();
 if(!name||name==="."||name==="..")return null;
 const path=raw.startsWith(parent+"/")?raw:parent+"/"+name;
 const folder=typeof e==="object"?(e.isDirectory===true||e.type==="dir"||e.type==="directory"||e.kind==="directory") : !/\.(?:rb|js|mjs|cjs|json|txt|png|jpe?g|webp|bmp|gif|mp3|ogg|wav|flac|rxdata|py|bat|md|css|html|woff2?|ttf|exe|dll|ini|lock)$/i.test(name);
 return{path,name,folder};
}
export function splitRubyParameters(input){
 let out=[],token="",depth=0,quote="",escape=false;
 for(const ch of String(input||"")){
  if(quote){token+=ch;if(escape)escape=false;else if(ch==="\\")escape=true;else if(ch===quote)quote="";continue;}
  if(ch==='"'||ch==="'"){quote=ch;token+=ch;continue;}
  if("([{".includes(ch)){depth++;token+=ch;continue;}
  if(")]}".includes(ch)){depth=Math.max(0,depth-1);token+=ch;continue;}
  if(ch===","&&depth===0){if(token.trim())out.push(token.trim());token="";continue;}
  token+=ch;
 }
 if(token.trim())out.push(token.trim());
 return out;
}
export function parseSignature(text){
 return splitRubyParameters(text).map((part,index)=>{
  let value=part.trim(),kind="positional",optional=false,defaultValue="";
  if(value.startsWith("&")){return{name:value.slice(1),kind:"block",optional:true,defaultValue:"",type:"expression"};}
  if(value.startsWith("**")){return{name:value.slice(2),kind:"kwargs",optional:true,defaultValue:"",type:"expression"};}
  if(value.startsWith("*")){return{name:value.slice(1),kind:"rest",optional:true,defaultValue:"",type:"expression"};}
  const m=value.match(/^([a-zA-Z_]\w*[!?]?)\s*:\s*(.*)$/);
  if(m){kind="keyword";value=m[1];defaultValue=m[2].trim();optional=!!defaultValue;}
  else {
   const eq=value.indexOf("=");
   if(eq>=0){defaultValue=value.slice(eq+1).trim();value=value.slice(0,eq).trim();optional=true;}
  }
  if(!/^[a-zA-Z_]\w*[!?]?$/.test(value))return{name:"arg"+(index+1),kind:"positional",optional:true,defaultValue:part,type:"expression"};
  const type=inferType(value,defaultValue);
  return {name:value,kind,optional,defaultValue,type};
 });
}
function inferType(name,defaultValue){
 const d=String(defaultValue??"").trim(),n=String(name??"").toLowerCase();
 if(/^true$|^false$/.test(d))return"boolean";
 if(/^nil$/.test(d))return"expression";
 if(/^:-?[a-zA-Z_][a-zA-Z_0-9]*$/.test(d))return"symbol";
 if(/^["']/.test(d))return"string";
 if(/^-?\d+$/.test(d))return"integer";
 if(/^-?\d+\.\d+$/.test(d))return"number";
 if(/\b(species|item|move|ability|nature|trainer_type|weather|type_id)\b/.test(n))return"symbol";
 if(/(?:level|count|amount|index|quantity|num|frame|duration|map_id|event_id|slot|steps)/.test(n))return"integer";
 return"expression";
}
function inferPreset(type,defaultValue,name){
 const d=String(defaultValue||"").trim();
 if(d){
  if(type==="string"&&(/^["'].*["']$/s).test(d))return d.slice(1,-1);
  if(type==="symbol"&&d.startsWith(":"))return d.slice(1);
  if(!["nil","[]","{}"].includes(d))return d;
 }
 if(type==="symbol")return /item/i.test(name)?"POTION":/move/i.test(name)?"TACKLE":"PIKACHU";
 if(type==="integer"||type==="number")return"1";
 if(type==="boolean")return"false";
 if(type==="string")return"";
 return d||"nil";
}
export function defaultParameterValue(param){return inferPreset(param.type,param.defaultValue,param.name);}
export function renderValue(value,type){
 const raw=String(value??"").trim();
 if(type==="auto"||type==="expression"){if(!raw)throw Error("Falta una expresión Ruby.");return raw;}
 if(type==="nil")return"nil";
 if(type==="string")return JSON.stringify(String(value??""));
 if(type==="symbol"){const name=raw.replace(/^:/,"");if(!/^[A-Za-z_]\w*[!?=]?$/.test(name))throw Error("Símbolo Ruby no válido: "+name);return":"+name;}
 if(type==="integer"){if(!/^-?\d+$/.test(raw))throw Error("Debe ser un número entero: "+raw);return String(parseInt(raw,10));}
 if(type==="number"){if(!/^-?(?:\d+(?:\.\d*)?|\.\d+)$/.test(raw))throw Error("Número inválido: "+raw);return raw;}
 if(type==="boolean"){if(raw!=="true"&&raw!=="false")throw Error("Solo true o false");return raw;}
 throw Error("Tipo desconocido: "+type);
}
export function buildMethodCode(item,rows,receiver){
 // Without an instance the generated call is a draft; never pretend it is event-safe.
 const target=item.scope==="global"?item.name:(item.scope==="singleton"&&item.owner?item.owner+"."+item.name:(String(receiver||"").trim()||"mi_objeto")+"."+item.name);
 const args=[];
 let positionalGap=false;
 for(const p of item.parameters){
  if(p.kind==="block")continue;
  const row=rows[p.name]||{};
  const enabled=row.enabled!==false;
  if(!enabled){if(p.kind==="positional")positionalGap=true;continue;}
  if(positionalGap&&p.kind==="positional")throw Error("No puedes omitir un argumento posicional y activar otro posterior.");
  let v=renderValue(row.value??defaultParameterValue(p),row.type||p.type);
  if(p.kind==="keyword")args.push(p.name+": "+v);
  else if(p.kind==="rest"||p.kind==="kwargs")args.push(v);
  else args.push(v);
 }
 return target+"("+args.join(", ")+")";
}
function ownerFromLine(line){const m=line.match(/^\s*(?:class|module)\s+([A-Z]\w*(?:::[A-Z]\w*)*)/);return m?m[1]:null;}
function parseRubyFile(path,raw){
 const found=[],lines=String(raw).split(/\r?\n/);
 let lastOwner="",previousOwnerLine=-999;
 for(let i=0;i<lines.length;i++){
  const line=lines[i],owner=ownerFromLine(line);
  if(owner){lastOwner=owner;previousOwnerLine=i;}
  if(/^\s*#/.test(line))continue;
  const m=line.match(/^\s*def\s+(?:(self|[A-Z]\w*(?:::[A-Z]\w*)*)\.)?([a-zA-Z_]\w*[!?=]?)(?:\s*\((.*)|\s+([^#\n]*))?\s*$/);
  if(!m)continue;
  let sig=String(m[3]??m[4]??"").trim();
  if(m[3]!==undefined){
    // Capture up to 16 continuation lines for multiline argument lists.
    let tries=0,balance=(sig.match(/\(/g)||[]).length-(sig.match(/\)/g)||[]).length;
    while(!sig.includes(")")&&tries<16&&i+1<lines.length){const next=lines[i+1].trim();sig+=" "+next;i++;tries++;if(next.endsWith(")"))break;}
    sig=sig.slice(0,sig.lastIndexOf(")")>=0?sig.lastIndexOf(")"):sig.length);
  }else sig=sig.replace(/\s*#.*$/,"");
  const name=m[2];
  // Owner inference can only be approximate with a light parser; NEVER assign a
  // standalone global function to a class based only on a preceding class line.
  const singleton=!!m[1];
  const scope=singleton?"singleton":POSITIVE.test(name)?"global":"instance";
  const detectedOwner=singleton?(m[1]==="self"?lastOwner:m[1]):"";
  const params=parseSignature(sig);
  const lineNumber=i+1;
  found.push({kind:"source",id:"src:"+path+":"+lineNumber+":"+name,group:path.startsWith("Data/")?"Essentials / LBDS":"Plugins instalados",name,title:name,scope,owner:detectedOwner,
   signature:sig,parameters:params,sourcePath:path,line:lineNumber,
   note:scope==="instance"?"Método de instancia o contexto desconocido. Indica un receptor Ruby antes de usarlo.":scope==="singleton"?"Método de clase/módulo (propietario aproximado).":"Función global candidata; verifica si funciona desde eventos.",
   verified:false
  });
 }
 return found;
}
export async function scanProject(ctx,onProgress=()=>{},signal={cancelled:false}){
 const queues=["Data/Scripts","Plugins"],seen=new Set(),methods=[],errors=[],visited=[];
 let scanned=0,read=0,byteCount=0;
 const started=Date.now();
 while(queues.length&&!signal.cancelled){
  const dir=queues.shift();if(seen.has(dir))continue;seen.add(dir);
  let items;
  try{items=await ctx.fs.listProjectDir(dir);}catch(e){errors.push({path:dir,error:String(e?.message||e)});continue;}
  if(!Array.isArray(items))items=items?.entries||items?.files||items?.items||[];
  if(!Array.isArray(items)){errors.push({path:dir,error:"Formato de listado de carpetas no reconocido"});continue;}
  for(const obj of items){
   if(signal.cancelled)break;
   const e=normalizedEntry(obj,dir);if(!e||IGNORE_FOLDERS.has(e.name))continue;
   scanned++;
   if(e.folder){
    if(e.path.split("/").length<=15)queues.push(e.path);
    else errors.push({path:e.path,error:"Profundidad mayor a 15 carpetas"});
    continue;
   }
   if(!/\.rb$/i.test(e.name))continue;
   try{
    const s=await ctx.fs.readProjectFile(e.path);
    if(typeof s!=="string")throw Error("No se pudo leer texto Unicode");
    read++;byteCount+=s.length;visited.push(e.path);
    methods.push(...parseRubyFile(e.path,s));
   }catch(ex){errors.push({path:e.path,error:String(ex?.message||ex)});}
   if(read%15===0){onProgress({scanned,read,found:methods.length,errors:errors.length,dir:e.path});await new Promise(resolve=>setTimeout(resolve,0));}
  }
 }
 const unique=new Map();
 for(const m of methods)unique.set(m.id,m);
 const ordered=[...unique.values()].sort((a,b)=>a.title.localeCompare(b.title)||a.sourcePath.localeCompare(b.sourcePath));
 return{methods:ordered,report:{read,scanned,found:ordered.length,errors,byteCount,visitedCount:visited.length,
   elapsedMs:Date.now()-started,cancelled:!!signal.cancelled,complete:!signal.cancelled&&read>0&&errors.length===0&&queues.length===0}};
}
export const SUPPORTED_TYPES=TYPES;
