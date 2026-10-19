// Asset ownership and safe filesystem operations for Animated Props Studio.
// No asset may be deleted while referenced by a definition.
export function imageUsage(data,filename){
  const hits=[];
  for(const d of data?.definitions||[]){
    if(d.sheet===filename)hits.push({id:d.id,name:d.name,track:'A'});
    // Disabled secondary tracks may still retain a filename and need protection.
    if(d.parallel?.sheet===filename)hits.push({id:d.id,name:d.name,track:'B'});
  }
  return hits;
}
export function safePngFilename(raw){
  if(typeof raw!=='string'||!/^[\p{L}\p{N}_ .()\-]+\.png$/iu.test(raw)||raw==='.'||raw==='..')
    throw new Error('El gráfico debe ser un archivo PNG directo dentro de Graphics/AnimatedProps.');
  return raw;
}
export function projectGraphicPath(root,file){
  const name=safePngFilename(file);
  if(typeof root!=='string'||!root.trim())throw new Error('No hay proyecto abierto.');
  const trimmed=root.replace(/[\\/]+$/,'');
  const sep=trimmed.includes('\\')?'\\':'/';
  return [trimmed,'Graphics','AnimatedProps',name].join(sep);
}
export function graphicEntries(entries){
  return [...new Set((entries||[]).map(e=>typeof e==='string'?e:(e?.name||'')).filter(name=>{
    try{safePngFilename(name);return true;}catch{return false;}
  }))].sort((a,b)=>a.localeCompare(b,'es'));
}
