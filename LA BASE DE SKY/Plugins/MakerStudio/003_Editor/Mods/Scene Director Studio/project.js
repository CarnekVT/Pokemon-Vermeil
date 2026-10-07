const norm=p=>String(p||"").replace(/\\/g,"/").replace(/\/{2,}/g,"/").replace(/\/$/,"");
const ext=p=>{const m=String(p||"").match(/\.([^.]+)$/);return m?m[1].toLowerCase():""};
export function gameRoot(ctx){try{return norm(ctx.editor.gameRoot())}catch{return ""}}
async function invoke(name,args){const fn=window.__TAURI__?.core?.invoke;if(!fn)throw new Error("Tauri invoke no disponible");return await fn(name,args)}
export async function readBinaryAbsolute(path){const b=await invoke("read_binary_file",{path});return b instanceof Uint8Array?b:new Uint8Array(b||[])}
export async function writeBinaryAbsolute(path,bytes){const a=bytes instanceof Uint8Array?bytes:new Uint8Array(bytes||[]);await invoke("write_binary_file",{path,data:Array.from(a)});return true}
export async function loadProjectBlobUrl(ctx,path,mime="application/octet-stream"){
  const root=gameRoot(ctx); if(!root)return null; try{const b=await readBinaryAbsolute(`${root}/${norm(path)}`);return URL.createObjectURL(new Blob([b],{type:mime}))}catch{return null}
}
export function mimeFor(path){const e=ext(path);if(e==="png")return"image/png";if(e==="jpg"||e==="jpeg")return"image/jpeg";if(e==="webp")return"image/webp";if(e==="gif")return"image/gif";if(e==="ogg")return"audio/ogg";if(e==="wav")return"audio/wav";if(e==="mp3")return"audio/mpeg";if(e==="ttf")return"font/ttf";if(e==="otf")return"font/otf";if(e==="woff")return"font/woff";if(e==="woff2")return"font/woff2";return"application/octet-stream"}
export async function listRecursive(ctx,base,{extensions=null,max=6000}={}){
  const out=[]; const seen=new Set();
  async function walk(dir){if(out.length>=max||seen.has(dir.toLowerCase()))return;seen.add(dir.toLowerCase());let entries=[];try{entries=await ctx.fs.listProjectDir(dir)}catch{return}
    for(const e of entries||[]){if(out.length>=max)break;const name=typeof e==="string"?e:(e.name||e.path||"");if(!name)continue;let p=norm(name);if(!p.toLowerCase().startsWith(dir.toLowerCase()+"/")&&p.toLowerCase()!==dir.toLowerCase())p=norm(`${dir}/${p}`);let isDir=typeof e==="object"?(e.isDirectory===true||e.kind==="directory"||e.type==="directory"):null;const ex=ext(p);if(isDir===true){await walk(p);continue}if(isDir===false){if(!extensions||extensions.includes(ex))out.push(p);continue}if(extensions&&extensions.includes(ex)){out.push(p);continue}try{await ctx.fs.listProjectDir(p);await walk(p)}catch{if(!extensions||extensions.includes(ex))out.push(p)}}
  }
  await walk(norm(base)); return out.sort((a,b)=>a.localeCompare(b,undefined,{numeric:true,sensitivity:"base"}));
}
export async function copyExternalFileToProject(ctx,file,destDir){
  const root=gameRoot(ctx); if(!root)throw new Error("No pude resolver la raíz del proyecto"); const safe=String(file.name||"asset").replace(/[<>:\"|?*]/g,"_");
  const dest=norm(`${destDir}/${safe}`); const bytes=new Uint8Array(await file.arrayBuffer()); await writeBinaryAbsolute(`${root}/${dest}`,bytes); return dest;
}
export async function detectSceneEngine(ctx){
  const result={found:false,name:"Scene Engine",version:"?",folder:"",settings:{scenesDir:"Graphics/Scenes",textBoxFile:"txt",textBoxY:286,textBoxH:178,textPadX:48,textPadYTop:42,textLineH:32,textMaxLines:4,textColor:[248,248,248],textShadow:[72,72,72],speakerColor:[248,208,48],speakerShadow:[120,96,16],speakerColorMap:{},speeds:{instant:999,fast:4.4,normal:1.5,slow:.7,very_slow:.15},fontName:"Power Green",fontSize:29,fontFile:""},methods:[]};
  const metas=await listRecursive(ctx,"Plugins",{extensions:["txt"],max:2500});
  for(const p of metas.filter(x=>/meta\.txt$/i.test(x))){let t="";try{t=String(await ctx.fs.readProjectFile(p)||"")}catch{};if(/^Name\s*=\s*Scene Engine\s*$/mi.test(t)){result.found=true;result.folder=p.replace(/\/meta\.txt$/i,"");result.version=(t.match(/^Version\s*=\s*(.+)$/mi)||[])[1]?.trim()||"?";break}}
  if(!result.found)return result;
  try{const s=String(await ctx.fs.readProjectFile(`${result.folder}/000_Settings.rb`)||""); const take=(key,rx,conv=v=>v)=>{const m=s.match(rx);if(m)result.settings[key]=conv(m[1])};
    take("scenesDir",/SCENES_DIR\s*=\s*[\"']([^\"']+)/);take("textBoxFile",/TEXT_BOX_FILE\s*=\s*[\"']([^\"']+)/);take("textBoxY",/TEXT_BOX_Y\s*=\s*(\d+)/,Number);take("textBoxH",/TEXT_BOX_H\s*=\s*(\d+)/,Number);take("textPadX",/TEXT_PAD_X\s*=\s*(\d+)/,Number);take("textPadYTop",/TEXT_PAD_Y_TOP\s*=\s*(\d+)/,Number);take("textLineH",/TEXT_LINE_H\s*=\s*(\d+)/,Number);take("textMaxLines",/TEXT_MAX_LINES\s*=\s*(\d+)/,Number);
    const parseColor=(name,fallback)=>{const m=s.match(new RegExp(`${name}\\s*=\\s*Color\\.new\\(\\s*(\\d+)\\s*,\\s*(\\d+)\\s*,\\s*(\\d+)`));return m?[Number(m[1]),Number(m[2]),Number(m[3])]:fallback};
    result.settings.textColor=parseColor("TEXT_COLOR",result.settings.textColor);result.settings.textShadow=parseColor("TEXT_SHADOW",result.settings.textShadow);result.settings.speakerColor=parseColor("SPEAKER_COLOR",result.settings.speakerColor);result.settings.speakerShadow=parseColor("SPEAKER_SHADOW",result.settings.speakerShadow);
    const cmap={};for(const m of s.matchAll(/["']([^"']+)["']\s*=>\s*\[\s*Color\.new\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)\s*,\s*Color\.new\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)/g)){cmap[m[1]]=[[Number(m[2]),Number(m[3]),Number(m[4])],[Number(m[5]),Number(m[6]),Number(m[7])]]}result.settings.speakerColorMap=cmap;
    for(const [k,K] of [["instant","INSTANT"],["fast","FAST"],["normal","NORMAL"],["slow","SLOW"],["very_slow","VERY_SLOW"]]){const m=s.match(new RegExp(`SPEED_${K}\\s*=\\s*([0-9.]+)`));if(m)result.settings.speeds[k]=Number(m[1])}
  }catch{}
  try{const r=String(await ctx.fs.readProjectFile(`${result.folder}/003_ScenePlayer.rb`)||"");result.methods=[...r.matchAll(/^\s*def\s+([a-zA-Z_]\w*[!?=]?)/gm)].map(m=>m[1])}catch{}
  // pbSetSystemFont de Essentials suele usar Power Green. Si el proyecto incluye
  // su propio archivo de fuente, la preview lo carga directamente para que el
  // wrapping y las métricas se acerquen al gameplay real.
  try{
    const fonts=[];
    for(const dir of ["Fonts","Graphics/Fonts"]){for(const f of await listRecursive(ctx,dir,{extensions:["ttf","otf","woff","woff2"],max:250}))fonts.push(f)}
    const score=f=>/power[ _-]*green/i.test(f)?100:/pokemon|pok[eé]mon|pkmn/i.test(f)?80:/emerald|firered|leafgreen/i.test(f)?60:10;
    fonts.sort((a,b)=>score(b)-score(a)||a.localeCompare(b));
    if(fonts[0])result.settings.fontFile=fonts[0];
  }catch{}
  try{
    const candidates=await listRecursive(ctx,"Plugins",{extensions:["rb"],max:1200});
    for(const fp of candidates){let t="";try{t=String(await ctx.fs.readProjectFile(fp)||"")}catch{continue}
      const m=t.match(/(?:Font\.default_name|FONT_NAME)\s*=\s*(?:\[\s*)?["']([^"']+)/);
      if(m){result.settings.fontName=m[1];break}
    }
  }catch{}
  return result;
}
export async function detectResolution(ctx){
  // Conservador: busca SCREEN_WIDTH/HEIGHT en scripts del proyecto y usa el último par encontrado.
  let width=640,height=480; const files=await listRecursive(ctx,"Plugins",{extensions:["rb"],max:900});
  for(const p of files){let t="";try{t=String(await ctx.fs.readProjectFile(p)||"")}catch{continue};const mw=[...t.matchAll(/SCREEN_WIDTH\s*=\s*(\d+)/g)],mh=[...t.matchAll(/SCREEN_HEIGHT\s*=\s*(\d+)/g)];if(mw.length&&mh.length){width=Number(mw[mw.length-1][1]);height=Number(mh[mh.length-1][1]);}}
  return {width,height};
}
