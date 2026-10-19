// Fingerprint project PNG data to detect same-name edits, including same-dimension files.
export function pngFingerprint(bytes){
  const data=bytes instanceof Uint8Array?bytes:Uint8Array.from(bytes||[]);
  let h=2166136261;
  for(let i=0;i<data.length;i++)h=Math.imul((h^data[i])>>>0,16777619)>>>0;
  return `${data.length}:${h.toString(16)}`;
}
export function projectPngAbsolute(root,folder,name){
  const sep=root.includes('\\')?'\\':'/';
  return `${root.replace(/[\\/]+$/,'')}${sep}${folder.replaceAll('/',sep)}${sep}${name}`;
}
export async function checkPngUpdates({names,read,stamps,onChanged}){
  const modified=[];
  for(const name of [...new Set(names.filter(Boolean))]){
    try{
      const fingerprint=pngFingerprint(await read(name));
      if(stamps.has(name)&&stamps.get(name)!==fingerprint){await onChanged(name);modified.push(name);}
      stamps.set(name,fingerprint);
    }catch{/* Temporarily locked PNGs keep their previous fingerprint. */}
  }
  return modified;
}
