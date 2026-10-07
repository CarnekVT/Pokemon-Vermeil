import { scanBattlebackAssets, scanBattlerAssets, scanProjectFiles, loadProjectImageUrl } from "./bas_core/assets.js";

const S=v=>String(v==null?"":v);
const L=v=>S(v).toLowerCase();
const U=v=>S(v).toUpperCase();
const arr=v=>Array.isArray(v)?v:[];

async function readMaybe(ctx,path){
  path=S(path).trim();
  if(!path||!ctx||!ctx.fs||typeof ctx.fs.projectExists!=="function"||typeof ctx.fs.readProjectFile!=="function")return "";
  try{ if(await ctx.fs.projectExists(path)) return S(await ctx.fs.readProjectFile(path)); }catch(_){ }
  return "";
}
function cleanLine(line){return S(line).replace(/\r/g,"").trim();}
function splitCsv(v){return S(v).split(",").map(x=>x.trim()).filter(Boolean);}

function parsePBSSections(text){
  const out=[]; let cur=null;
  for(const raw of S(text).split(/\n/)){
    const line=cleanLine(raw); if(!line||line.startsWith("#")) continue;
    const m=line.match(/^\[([^\]]+)\]$/); if(m){cur={id:m[1].trim(),fields:{}};out.push(cur);continue;}
    if(!cur)continue; const eq=line.indexOf("="); if(eq<0)continue;
    cur.fields[line.slice(0,eq).trim()]=line.slice(eq+1).trim();
  }
  return out;
}
function parseSpeciesTexts(texts){
  const map=new Map();
  for(const text of texts){
    for(const sec of parsePBSSections(text)){
      const header=splitCsv(sec.id); const species=U(header[0]); if(!species)continue;
      const form=Number(header[1]||0)||0; const key=species+":"+form;
      const old=map.get(key)||{id:species,species,form,name:species,formName:"",evolutions:[],abilities:[],hiddenAbilities:[],callRateSOS:0,sosSpecies:[],conditionalSOS:"",rivalSpecies:[],flags:[]};
      const f=sec.fields;
      old.id=species;old.species=species;old.name=S(f.Name||old.name||species);if(f.FormName!=null)old.formName=S(f.FormName);if(f.Abilities!=null)old.abilities=splitCsv(f.Abilities).map(U);if(f.HiddenAbilities!=null)old.hiddenAbilities=splitCsv(f.HiddenAbilities).map(U);
      if(f.CallRateSOS!=null)old.callRateSOS=Math.max(0,Number(f.CallRateSOS)||0);
      if(f.SpeciesSOS!=null)old.sosSpecies=splitCsv(f.SpeciesSOS).map(U);
      if(f.ConditionalSOS!=null)old.conditionalSOS=S(f.ConditionalSOS);
      if(f.RivalSpecies!=null)old.rivalSpecies=splitCsv(f.RivalSpecies).map(U);if(f.Flags!=null)old.flags=splitCsv(f.Flags).map(U);if(f.Evolutions!=null){const ev=splitCsv(f.Evolutions);old.evolutions=[];for(let i=0;i<ev.length;i+=3){const target=U(ev[i]);if(target)old.evolutions.push(target);}}
      map.set(key,old);
    }
  }
  return [...map.values()].sort((a,b)=>a.name.localeCompare(b.name,undefined,{numeric:true,sensitivity:"base"})||a.form-b.form);
}

function parseMapMetadata(text){
  const out=[];
  for(const sec of parsePBSSections(text)){
    const id=Number(String(sec.id||"").split(",")[0])||0;if(!id)continue;
    const f=sec.fields||{};out.push({id,mapId:id,name:S(f.Name||("Map "+id)),outdoor:S(f.Outdoor).toLowerCase()==="true"});
  }
  return out.sort((a,b)=>a.mapId-b.mapId);
}
function parseTrainers(text){
  const out=[];
  for(const sec of parsePBSSections(text)){
    const h=splitCsv(sec.id); if(!h.length)continue;
    out.push({trainerType:U(h[0]),name:S(h[1]||sec.fields.Name||h[0]),version:Number(h[2]||0)||0,key:sec.id});
  }
  return out;
}
function parseMovesTexts(texts){
  const map=new Map();
  for(const text of texts){
    for(const sec of parsePBSSections(text)){
      const id=U(sec.id);if(!id)continue;const f=sec.fields||{},old=map.get(id)||{id,name:id};old.id=id;old.name=S(f.Name||old.name||id);map.set(id,old);
    }
  }
  return [...map.values()].sort((a,b)=>a.name.localeCompare(b.name,undefined,{numeric:true,sensitivity:"base"})||a.id.localeCompare(b.id));
}
function parseItemsTexts(texts){
  const map=new Map();
  for(const text of texts){
    for(const sec of parsePBSSections(text)){
      const id=U(sec.id);if(!id)continue;const f=sec.fields||{},old=map.get(id)||{id,name:id,plural:id};
      old.id=id;old.name=S(f.Name||old.name||id);old.plural=S(f.NamePlural||old.plural||old.name||id);map.set(id,old);
    }
  }
  return [...map.values()].sort((a,b)=>S(a&&a.name).localeCompare(S(b&&b.name),undefined,{numeric:true,sensitivity:"base"})||S(a&&a.id).localeCompare(S(b&&b.id)));
}
const STEM_INDEX=new WeakMap();
function normalizedStem(v){return L(v).replace(/[^a-z0-9]/g,"");}
function getStemIndex(files){const list=arr(files);if(!list.length)return null;let idx=STEM_INDEX.get(list);if(idx)return idx;idx=new Map();for(const x of list){const key=normalizedStem(x&&x.name);if(key&&!idx.has(key))idx.set(key,x);}STEM_INDEX.set(list,idx);return idx;}
function findByStem(files,id){
  const list=arr(files),wanted=normalizedStem(id);
  if(!wanted)return null;
  const idx=getStemIndex(list),exact=idx&&idx.get(wanted);if(exact)return exact;
  return list.find(x=>normalizedStem(x&&x.name).startsWith(wanted))||null;
}
function iconStemCandidates(species,form){
  const s=U(species),f=Number(form)||0; return f>0?[`${s}_${f}`,`${s}_${f}_female`,s]:[s,`${s}_0`];
}
export async function scanProjectCoreSource(ctx){
  const pbsIndex=await scanProjectFiles(ctx,"PBS",["txt"],6);
  const pokemonPBS=arr(pbsIndex).filter(x=>{const n=L(x&&x.name);return n.startsWith("pokemon")&&!n.startsWith("pokemon_metrics")&&!n.startsWith("pokemon_regional_dexes")&&!n.startsWith("pokemon_shadow");});
  const known=["PBS/pokemon.txt","PBS/pokemon_forms.txt","PBS/pokemon_base_Gen_9_Pack.txt","PBS/pokemon_forms_Gen_9_Pack.txt"];
  const pokemonPaths=[...new Set([...known,...pokemonPBS.map(x=>x.projectPath).filter(Boolean)])];
  const pbs=await Promise.all(pokemonPaths.map(path=>readMaybe(ctx,path)));
  const movePBS=arr(pbsIndex).filter(x=>{const n=L(x&&x.name),pp=L(x&&x.projectPath);return (n==="moves.txt"||n.startsWith("moves_")||pp.endsWith("/moves.txt"))&&!n.includes("animation");});
  const itemPBS=arr(pbsIndex).filter(x=>{const n=L(x&&x.name),pp=L(x&&x.projectPath);return n==="items.txt"||n.startsWith("items_")||pp.endsWith("/items.txt");});
  const movePaths=[...new Set(["PBS/moves.txt",...movePBS.map(x=>x.projectPath).filter(Boolean)])];
  const itemPaths=[...new Set(["PBS/items.txt",...itemPBS.map(x=>x.projectPath).filter(Boolean)])];
  const [moveTexts,itemTexts,trainersText,mapMetadataText]=await Promise.all([Promise.all(movePaths.map(path=>readMaybe(ctx,path))),Promise.all(itemPaths.map(path=>readMaybe(ctx,path))),readMaybe(ctx,"PBS/trainers.txt"),readMaybe(ctx,"PBS/map_metadata.txt")]);
  return {maps:parseMapMetadata(mapMetadataText),species:parseSpeciesTexts(pbs.filter(Boolean)),moves:parseMovesTexts(moveTexts.filter(Boolean)),items:parseItemsTexts(itemTexts.filter(Boolean)),trainers:parseTrainers(trainersText),battlebacks:[],battlebackGroups:[],foeSprites:[],userSprites:[],pokemonIcons:[],trainerSprites:[],auraGraphics:[],allGraphics:[],bgmFiles:[],seFiles:[],graphicsReady:false};
}
export async function scanProjectGraphicsSource(ctx){
  const [battlebacksRaw,foeSprites,userSprites,pokemonIcons,trainerSprites,auraGraphics,allGraphics,bgmFiles,seFiles]=await Promise.all([
    scanBattlebackAssets(ctx),scanBattlerAssets(ctx,"target"),scanBattlerAssets(ctx,"user"),
    scanProjectFiles(ctx,"Graphics/Pokemon/Icons",["png","gif","jpg","jpeg","webp"],5),
    scanProjectFiles(ctx,"Graphics/Trainers",["png","gif","jpg","jpeg","webp"],5),
    scanProjectFiles(ctx,"Graphics/BattleSceneStudio/Auras",["png","gif","jpg","jpeg","webp"],8),
    scanProjectFiles(ctx,"Graphics",["png","gif","jpg","jpeg","webp","bmp"],24),
    scanProjectFiles(ctx,"Audio/BGM",["ogg","mp3","wav","mid","midi","flac","opus","m4a"],16),
    scanProjectFiles(ctx,"Audio/SE",["ogg","mp3","wav","mid","midi","flac","opus","m4a"],16)
  ]);
  const bbObj=(battlebacksRaw&&typeof battlebacksRaw==="object")?battlebacksRaw:{};
  const battlebacks=Array.isArray(battlebacksRaw)?battlebacksRaw:arr(bbObj.files);
  const battlebackGroups=arr(bbObj.groups);
  const bgm=arr(bgmFiles).map(x=>Object.assign({},x,{value:S(x&& (x.relativePath||x.filename||x.name)).replace(/\\/g,"/").replace(/\.[^.]+$/g,"")})).sort((a,b)=>S(a&&a.value).localeCompare(S(b&&b.value),undefined,{numeric:true,sensitivity:"base"}));
  const se=arr(seFiles).map(x=>Object.assign({},x,{value:S(x&& (x.relativePath||x.filename||x.name)).replace(/\\/g,"/").replace(/^Audio\/SE\//i,"").replace(/\.[^.]+$/g,"")})).sort((a,b)=>S(a&&a.value).localeCompare(S(b&&b.value),undefined,{numeric:true,sensitivity:"base"}));
  return {battlebacks,battlebackGroups,foeSprites:arr(foeSprites),userSprites:arr(userSprites),pokemonIcons:arr(pokemonIcons),trainerSprites:arr(trainerSprites),auraGraphics:arr(auraGraphics),allGraphics:arr(allGraphics),bgmFiles:bgm,seFiles:se,graphicsReady:true};
}
export async function scanProjectSource(ctx){
  const [core,graphics]=await Promise.all([scanProjectCoreSource(ctx),scanProjectGraphicsSource(ctx)]);
  return Object.assign({},core,graphics,{graphicsReady:true});
}
export function findSpecies(source,species,form){
  const s=U(species),f=Number(form)||0; return arr(source&&source.species).find(x=>x.species===s&&Number(x.form||0)===f)||arr(source&&source.species).find(x=>x.species===s&&Number(x.form||0)===0)||null;
}
export function findPokemonIcon(source,species,form){
  for(const stem of iconStemCandidates(species,form)){const x=findByStem(source&&source.pokemonIcons,stem);if(x)return x;} return null;
}
export function findBattlerSprite(source,species,side,form=0){
  const files=side==="user"?source&&source.userSprites:source&&source.foeSprites;for(const stem of iconStemCandidates(species,form)){const x=findByStem(files,stem);if(x)return x;}return null;
}
export function findTrainerSprite(source,trainerType){return findByStem(source&&source.trainerSprites,U(trainerType));}
export function findBattlebackGroup(source,key){return arr(source&&source.battlebackGroups).find(x=>L(x&&x.key)===L(key))||null;}
export async function imageUrl(ctx,asset){return asset&&asset.projectPath?loadProjectImageUrl(ctx,asset.projectPath):null;}
