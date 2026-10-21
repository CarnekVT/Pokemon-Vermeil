// Read-only PBS IDs for editable symbol autocompletion.
// No writes, no compilation and no execution of Ruby from the project.
const CONFIG=[
 ["pokemon",/^pokemon(?:_.*)?\.txt$/i],
 ["items",/^items(?:_.*)?\.txt$/i],
 ["moves",/^moves(?:_.*)?\.txt$/i],
 ["abilities",/^abilities(?:_.*)?\.txt$/i],
 ["trainer_types",/^trainer_types(?:_.*)?\.txt$/i]
];
export function classifySymbolHint(label){
 const l=String(label).toLowerCase();
 if(/entrenador|trainer_type/.test(l))return "trainer_types";
 if(/habilidad|ability/.test(l))return "abilities";
 if(/movimiento|move/.test(l))return "moves";
 if(/objeto|item|mt\b/.test(l))return "items";
 if(/especie|pok[eé]mon|species/.test(l))return "pokemon";
 return "";
}
function rowsFromPBS(text){
 const out=new Set();
 for(const raw of String(text||"").replace(/\r/g,"").split("\n")){
  let line=raw.trim();
  if(!line||line.startsWith("#"))continue;
  let m=line.match(/^\[([^\]]+)\]/);
  if(m){
   const token=m[1].trim().split(",")[0];
   if(/^[A-Za-z][A-Za-z_0-9]*$/.test(token))out.add(token);
   continue;
  }
  m=line.match(/^\d+,\s*([A-Za-z][A-Za-z0-9_]*)\s*(?:,|$)/);
  if(m)out.add(m[1]);
 }
 return out;
}
export async function loadPBS(ctx){
 let paths=[];
 try{const items=await ctx.fs.listProjectDir("PBS");
  if(Array.isArray(items))paths=items.map(e=>String(typeof e==="string"?e:(e?.name||e?.path||"")).replace(/\\/g,"/").split("/").pop()).filter(Boolean);
 }catch(_){}
 const sets={};for(const [name]of CONFIG)sets[name]=new Set();
 const issues=[];let files=0;
 for(const file of paths){
  const kind=CONFIG.find(([,re])=>re.test(file))?.[0];if(!kind)continue;
  try{
   const data=await ctx.fs.readProjectFile("PBS/"+file);
   for(const id of rowsFromPBS(data))sets[kind].add(id);
   files++;
  }catch(e){issues.push(file+": "+(e?.message||e));}
 }
 const out={files,issues,ids:{}};
 for(const [kind]of CONFIG)out.ids[kind]=[...sets[kind]].sort();
 return out;
}
