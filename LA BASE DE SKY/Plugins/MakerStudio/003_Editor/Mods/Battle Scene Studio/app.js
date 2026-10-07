import { STYLES } from "./styles.js";
import { BSS_VERSION, DATA_DIR, DATA_FILE, EBDX_DATA_DIR, EBDX_MAP_METADATA_FILE, EBDX_SCENES_FILE, SOS_GLOBAL_FILE, SOS_CATALOG_DIR, SOS_DATASETS, CONTROL_FILE, STATUS_FILE, makeStudio, makeSOSGlobal, makeBlueprint, makePokemon, normalizeBlueprint, normalizeStudio, normalizeSOSGlobal, slug, eventCommand, initialFormation, visibleFormation } from "./model.js";
import { scanProjectSource, scanProjectCoreSource, scanProjectGraphicsSource, findSpecies, findPokemonIcon, findBattlerSprite, findTrainerSprite, findBattlebackGroup, imageUrl } from "./project_source.js";
import { BattlePreview } from "./bas_core/preview.js";
import { fallbackBattleContext, readRuntimeContext, effectiveBattleContext } from "./bas_core/context.js";
import { createAnimation, setPositionKey } from "./bas_core/model.js";
import { detectProjectBattleContext, loadBattlerRenderingInfo, clearBattlerRenderingCache } from "./bas_core/project_tools.js";

const E=s=>String(s==null?"":s).replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
const S=v=>String(v==null?"":v), U=v=>S(v).toUpperCase(), L=v=>S(v).toLowerCase();
const A=v=>Array.isArray(v)?v:[];
const N=(v,d=0)=>Number.isFinite(Number(v))?Number(v):d;
const C=v=>U(v).replace(/[^A-Z0-9]/g,"");
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
const audioMime=path=>{const parts=S(path).split("."),e=L(parts.length?parts[parts.length-1]:"");if(e==="ogg"||e==="oga")return"audio/ogg";if(e==="mp3")return"audio/mpeg";if(e==="wav")return"audio/wav";if(e==="m4a")return"audio/mp4";if(e==="flac")return"audio/flac";if(e==="opus")return"audio/ogg";return"application/octet-stream";};
async function projectBlobUrl(ctx,path,mime="application/octet-stream"){try{const root=S(ctx&&ctx.editor&&typeof ctx.editor.gameRoot==="function"?ctx.editor.gameRoot():"").replace(/\\/g,"/").replace(/\/$/,"");const rel=S(path).replace(/\\/g,"/").replace(/^\/+/,"");if(!root||!rel)return null;const tauri=(typeof window!=="undefined"&&window.__TAURI__)?window.__TAURI__:null;const invoke=tauri&&tauri.core&&typeof tauri.core.invoke==="function"?tauri.core.invoke:(tauri&&tauri.tauri&&typeof tauri.tauri.invoke==="function"?tauri.tauri.invoke:null);if(typeof invoke!=="function")return null;const raw=await invoke("read_binary_file",{path:`${root}/${rel}`});const bytes=raw instanceof Uint8Array?raw:new Uint8Array(raw||[]);return URL.createObjectURL(new Blob([bytes],{type:mime}));}catch(_){return null;}}
const SOS_RESTRICTED_SPECIES=new Set(`
ARTICUNO ZAPDOS MOLTRES MEWTWO MEW
RAIKOU ENTEI SUICUNE LUGIA HOOH CELEBI
REGIROCK REGICE REGISTEEL LATIAS LATIOS KYOGRE GROUDON RAYQUAZA JIRACHI DEOXYS
UXIE MESPRIT AZELF DIALGA PALKIA HEATRAN REGIGIGAS GIRATINA CRESSELIA PHIONE MANAPHY DARKRAI SHAYMIN ARCEUS
VICTINI COBALION TERRAKION VIRIZION TORNADUS THUNDURUS RESHIRAM ZEKROM LANDORUS KYUREM KELDEO MELOETTA GENESECT
XERNEAS YVELTAL ZYGARDE DIANCIE HOOPA VOLCANION
TYPENULL SILVALLY TAPUKOKO TAPULELE TAPUBULU TAPUFINI COSMOG COSMOEM SOLGALEO LUNALA NECROZMA MAGEARNA MARSHADOW ZERAORA MELTAN MELMETAL
NIHILEGO BUZZWOLE PHEROMOSA XURKITREE CELESTEELA KARTANA GUZZLORD POIPOLE NAGANADEL STAKATAKA BLACEPHALON
ZACIAN ZAMAZENTA ETERNATUS KUBFU URSHIFU ZARUDE REGIELEKI REGIDRAGO GLASTRIER SPECTRIER CALYREX ENAMORUS
WOCHIEN CHIENPAO TINGLU CHIYU KORAIDON MIRAIDON OKIDOGI MUNKIDORI FEZANDIPITI OGERPON TERAPAGOS PECHARUNT
`.trim().split(/\s+/));
async function mapLimit(items,limit,fn){let at=0;const workers=Array.from({length:Math.min(limit,items.length)},async()=>{while(at<items.length){const i=at++;try{await fn(items[i],i);}catch(_){}}});await Promise.all(workers);}
const POKEMON_STATS=[["HP","HP"],["ATTACK","Ataque"],["DEFENSE","Defensa"],["SPECIAL_ATTACK","Ataque Esp."],["SPECIAL_DEFENSE","Defensa Esp."],["SPEED","Velocidad"]];
const NATURES=["HARDY","LONELY","BRAVE","ADAMANT","NAUGHTY","BOLD","DOCILE","RELAXED","IMPISH","LAX","TIMID","HASTY","SERIOUS","JOLLY","NAIVE","MODEST","MILD","QUIET","BASHFUL","RASH","CALM","GENTLE","SASSY","CAREFUL","QUIRKY"];
const NATURE_EFFECTS={
HARDY:["",""],LONELY:["Ataque","Defensa"],BRAVE:["Ataque","Velocidad"],ADAMANT:["Ataque","Ataque Esp."],NAUGHTY:["Ataque","Defensa Esp."],
BOLD:["Defensa","Ataque"],DOCILE:["",""],RELAXED:["Defensa","Velocidad"],IMPISH:["Defensa","Ataque Esp."],LAX:["Defensa","Defensa Esp."],
TIMID:["Velocidad","Ataque"],HASTY:["Velocidad","Defensa"],SERIOUS:["",""],JOLLY:["Velocidad","Ataque Esp."],NAIVE:["Velocidad","Defensa Esp."],
MODEST:["Ataque Esp.","Ataque"],MILD:["Ataque Esp.","Defensa"],QUIET:["Ataque Esp.","Velocidad"],BASHFUL:["",""],RASH:["Ataque Esp.","Defensa Esp."],
CALM:["Defensa Esp.","Ataque"],GENTLE:["Defensa Esp.","Defensa"],SASSY:["Defensa Esp.","Velocidad"],CAREFUL:["Defensa Esp.","Ataque Esp."],QUIRKY:["",""]
};
const natureLabel=id=>{id=U(id);const fx=NATURE_EFFECTS[id]||["",""];return fx[0]?`${id} · ↑ ${fx[0]} · ↓ ${fx[1]}`:`${id} · Neutra`;};
function normalizeSourceRows(source){
  const src=source&&typeof source==="object"?source:{};
  const norm=(rows,fn)=>A(rows).filter(Boolean).map(x=>{try{return fn(Object.assign({},x));}catch(_){return null;}}).filter(Boolean);
  const asset=x=>{if(!x||typeof x!=="object")return null;const y=Object.assign({},x);["name","key","label","projectPath","relativePath","filename","value","rootProjectPath","extension"].forEach(k=>{if(k in y)y[k]=S(y[k]);});y.name=S(y.name||y.filename||y.key||y.value||y.projectPath);y.projectPath=S(y.projectPath||y.path||"");y.relativePath=S(y.relativePath||y.filename||y.name||"");return y;};
  src.species=norm(src.species,x=>{x.species=U(x.species||x.id);x.id=U(x.id||x.species);x.name=S(x.name||x.species||x.id);x.form=N(x.form,0);x.formName=S(x.formName);x.flags=A(x.flags).map(U).filter(Boolean);x.abilities=A(x.abilities).map(U).filter(Boolean);x.hiddenAbilities=A(x.hiddenAbilities).map(U).filter(Boolean);return x.species?x:null;});
  src.moves=norm(src.moves,x=>{x.id=U(x.id);x.name=S(x.name||x.id);return x.id?x:null;});
  src.items=norm(src.items,x=>{x.id=U(x.id);x.name=S(x.name||x.id);x.plural=S(x.plural||x.name||x.id);return x.id?x:null;});
  src.trainers=norm(src.trainers,x=>{x.trainerType=U(x.trainerType||x.type);x.name=S(x.name||x.trainerType);x.key=S(x.key);return x.trainerType?x:null;});
  ["battlebacks","pokemonIcons","foeSprites","userSprites","trainerSprites","auraGraphics","allGraphics","bgmFiles","seFiles"].forEach(k=>{src[k]=A(src[k]).map(asset).filter(Boolean);});
  src.battlebackGroups=norm(src.battlebackGroups,x=>{x.key=S(x.key||x.name);x.name=S(x.name||x.key);["background","playerBase","enemyBase","messageBar"].forEach(k=>{if(x[k])x[k]=asset(x[k]);});return x.key?x:null;});
  return src;
}

class App{
  constructor(ctx,host){
    this.ctx=ctx;this.host=host;this.studio=makeStudio();this.sosGlobal=makeSOSGlobal();this.sosCatalog={profiles:[],groups:[],examples:[]};this.source={species:[],moves:[],items:[],battlebackGroups:[],pokemonIcons:[],foeSprites:[],userSprites:[],trainerSprites:[],auraGraphics:[],allGraphics:[],bgmFiles:[],seFiles:[]};this.runtimeContext=null;this.projectScriptContext=null;
    this.activeId=null;this.activeGroup="wild_main";this.screen="library";this.section="setup";this.search="";this.sosSearch="";this.sosExampleSearch="";this.sosExampleGroup="all";this.sosSelected=new Set();this.sosImportOpen=false;this.sosImportSource="sm_usum";this.sosImportGroup="all";this.sosImportSearch="";this.sosPoolExpanded=new Set();this.sosPoolModalKey="";this.sosCatalogRaw=null;this.renderTimer=null;this.picker=null;this.assetPicker=null;this.pokemonEditor=null;this.preview=null;this.previewAnimation=null;this.frameCache=new Map();this.framePending=new Map();this.assetUrlCache=new Map();this.assetUrlPending=new Map();this.renderMetaCache=new Map();this.renderMetaPending=new Map();this.renderCompatWarmPromise=null;this.toastTimer=null;this.status={state:"offline"};this.lastTestKey="";this.lastResumeToken="";this.left=180;this.right=470;this.dragResize=null;this.graphicsLoadPromise=null;this.graphicsLoading=false;
    this.fullscreenActive=false;this.fullscreenPlaceholder=null;this.fullscreenPreviousScroll={x:0,y:0};this.previewCollapsed=false;this.auraStudioProfile="ebdx_default";this.auraStudioTab="appearance";this.auraReturnScreen="library";this.auraReturnSection="boss";this.auraTestSpecies="PIKACHU";this.auraTestForm=0;this.auraRuntimeAssetCache=new Map();this.auraTintCache=new Map();this.auraOutlineTintCache=new Map();this.auraPreviewRAF=0;this.auraPreviewFrame=0;this.auraPreviewLast=0;this.auraParticleLayer="main";this.sectionScroll={};this.globalSettingsOpen=false;this.assetAudio=null;this.assetAudioUrl="";this.assetAudioKey="";this._savePromise=null;this._saveQueued=false;this._saveSilent=true;this.inspectorPanelState={};this._bss654SwitchingSection=false;this.librarySelected=new Set();this.libraryExportGroupsOpen=false;this.libraryExportSelectedGroups=new Set();this.ebdxStudioSelected="";this.ebdxStudioBuiltin="Field";this.ebdxStudioJson="";
    this.build();this.bind();this.init().catch(err=>this.reportError("init",err));
  }
  build(){
    const style=document.createElement("style");style.textContent=STYLES;this.host.innerHTML="";this.host.appendChild(style);this.root=document.createElement("div");this.root.className="bss-root";
    this.root.innerHTML=`<div class="bss-fullscreen-session-controls"><button class="bss-btn" data-act="fullscreen">↙ Exit fullscreen</button><button class="bss-btn danger" data-act="close-editor-fullscreen">✕ Close editor</button></div><header class="bss-top"><div class="bss-brand"><div class="bss-mark">⚔</div><div><strong>Battle Scene Studio</strong><small>v${BSS_VERSION} · Phase 1 · SOS + Boss/Totem</small></div></div><button class="bss-nav active" data-nav="library">Battles</button><button class="bss-nav" data-nav="sos">SOS Studio</button><button class="bss-nav" data-nav="aura">Aura Studio</button><button class="bss-nav" data-nav="ebdx">EBDX Studio</button><div class="bss-spacer"></div><span class="bss-pill">SOS JSON</span><span class="bss-pill off" data-game>Game offline</span><button class="bss-btn" data-act="open-global-settings">⚙ Ajustes globales</button><button class="bss-btn" data-act="save">Save</button><button class="bss-btn" data-act="rescan">Reload data</button><button class="bss-btn" data-act="fullscreen" aria-pressed="false">⛶ Fullscreen</button></header><div class="bss-body" data-body></div>`;
    this.host.appendChild(this.root);this.body=this.root.querySelector("[data-body]");this.host.tabIndex=0;
    // Window sizing/moving is owned by Maker Studio, exactly like BAS; BSS never forces OS window geometry.
  }
  bind(){
    const guarded=(where,fn,e)=>{try{const out=fn.call(this,e);if(out&&typeof out.then==="function")out.catch(err=>this.reportError(where,err));return out;}catch(err){this.reportError(where,err);return null;}};
    this.onClickBound=e=>{try{e&&e.stopPropagation&&e.stopPropagation();}catch(_){}return guarded("click",this.onClick,e);};this.onInputBound=e=>{try{e&&e.stopPropagation&&e.stopPropagation();}catch(_){}return guarded("input",this.onInput,e);};this.onPointerMoveBound=e=>guarded("pointer",this.onPointerMove,e);this.onPointerUpBound=e=>guarded("pointerup",this.onPointerUp,e);this.onKeyDownBound=e=>{try{e&&e.stopPropagation&&e.stopPropagation();}catch(_){}return guarded("keydown",this.onKeyDown,e);};
    this.onWindowErrorBound=e=>{const err=e&&e.error;if(!err)return;this.persistEditorError("window",err);};
    this.onUnhandledBound=e=>{const err=e&&e.reason;if(!err)return;this.persistEditorError("promise",err);};
    this.root.addEventListener("click",this.onClickBound);this.root.addEventListener("input",this.onInputBound);this.root.addEventListener("change",this.onInputBound);this.root.addEventListener("keydown",this.onKeyDownBound);
    window.addEventListener("pointermove",this.onPointerMoveBound);window.addEventListener("pointerup",this.onPointerUpBound);window.addEventListener("error",this.onWindowErrorBound);window.addEventListener("unhandledrejection",this.onUnhandledBound);
  }
  destroy(){
    if(this.fullscreenActive)this.exitFullscreenMode({skipRefresh:true});this.stopAssetAudioPreview(true);this.disposePreview();this.stopAuraPreviewLoop();this.auraTintCache.clear();clearTimeout(this.toastTimer);clearInterval(this.statusTimer);clearTimeout(this.saveDelay);clearTimeout(this.sosSaveDelay);
    window.removeEventListener("pointermove",this.onPointerMoveBound);window.removeEventListener("pointerup",this.onPointerUpBound);window.removeEventListener("error",this.onWindowErrorBound);window.removeEventListener("unhandledrejection",this.onUnhandledBound);if(this.root)this.root.removeEventListener("keydown",this.onKeyDownBound);
    for(const u of this.assetUrlCache.values())try{URL.revokeObjectURL(u)}catch(_){}this.assetUrlCache.clear();this.assetUrlPending.clear();this.frameCache.clear();this.framePending.clear();this.renderMetaCache.clear();this.renderMetaPending.clear();this.renderCompatWarmPromise=null;this.host.innerHTML="";
  }
  async init(){await this.load();await this.loadSOSConfig();if(this.body)this.body.innerHTML=`<div class="bss-empty padded">Cargando PBS del proyecto…</div>`;await this.rescanFast();this.pollStatus();this.statusTimer=setInterval(()=>this.pollStatus(),1200);this.loadSOSCatalog().then(()=>{if(this.screen==="sos")this.renderSOSStudio();}).catch(()=>{});this.loadGraphicsInBackground();}
  battle(){return this.studio.blueprints.find(b=>b.id===this.activeId)||null;}
  async load(){try{let main=null,recovery=null;if(await this.ctx.fs.projectExists(DATA_FILE))main=JSON.parse(S(await this.ctx.fs.readProjectFile(DATA_FILE)||"{}"));const recoveryPath=DATA_DIR+"/battles.recovery.json";if(await this.ctx.fs.projectExists(recoveryPath))recovery=JSON.parse(S(await this.ctx.fs.readProjectFile(recoveryPath)||"{}"));const mainAt=N(main&&main._bssSavedAt,0),recoveryAt=N(recovery&&recovery._bssSavedAt,0),chosen=recovery&&recoveryAt>mainAt?recovery:main;if(chosen)this.studio=normalizeStudio(chosen);if(chosen===recovery&&recoveryAt>mainAt)setTimeout(()=>this.toast("BSS recuperó el guardado alterno más reciente; battles.json estaba bloqueado."),50);}catch(e){this.toast("Could not load battles.json: "+S(e&&e.message||e),true);}this.studio.global=this.studio.global||{};if(this.studio.global.ebdxBackdropForceGlobal===true){this.studio.global.ebdxBackdropForceGlobal=false;setTimeout(()=>this.toast("Se desactivó el antiguo test global de EBDX. Las pruebas ahora afectan solo al próximo combate."),80);}this.activeGroup=this.studio.global&&this.studio.global.mainGroupId||"wild_main";this.activeId=this.studio.blueprints[0]&&this.studio.blueprints[0].id||null;}
  saveRetryable(err){const msg=L(err&&err.message||err);return msg.includes("acceso denegado")||msg.includes("access denied")||msg.includes("permission denied")||msg.includes("eacces")||msg.includes("os error 5")||msg.includes("being used by another process");}
  async writeStudioFileWithRetry(text){const delays=[0,100,220,450,850,1400];let last=null;for(let i=0;i<delays.length;i++){if(delays[i])await sleep(delays[i]);try{await this.ctx.fs.projectMkdir(DATA_DIR);await this.ctx.fs.writeProjectFile(DATA_FILE,text);return true;}catch(e){last=e;if(!this.saveRetryable(e))throw e;}}throw last||new Error("Could not write battles.json");}
  async save(silent=false){this._saveQueued=true;this._saveSilent=this._saveSilent&&silent;if(this._savePromise)return this._savePromise;this._savePromise=(async()=>{let ok=true;try{while(this._saveQueued){this._saveQueued=false;this.studio._bssSavedAt=Date.now();const text=JSON.stringify(this.studio,null,2);await this.writeStudioFileWithRetry(text);}if(!this._saveSilent)this.toast("Saved");}catch(e){ok=false;try{await this.ctx.fs.projectMkdir(DATA_DIR);this.studio._bssSavedAt=Date.now();await this.ctx.fs.writeProjectFile(DATA_DIR+"/battles.recovery.json",JSON.stringify(this.studio,null,2));this.toast("battles.json está bloqueado por Windows/OneDrive. Guardé battles.recovery.json y BSS volverá a intentar en el próximo guardado.",true);}catch(_){this.toast("Save failed: "+S(e&&e.message||e),true);}}finally{this._savePromise=null;this._saveSilent=true;}return ok;})();return this._savePromise;}
  async loadSOSConfig(){try{if(await this.ctx.fs.projectExists(SOS_GLOBAL_FILE))this.sosGlobal=normalizeSOSGlobal(JSON.parse(S(await this.ctx.fs.readProjectFile(SOS_GLOBAL_FILE)||"{}")));else this.sosGlobal=makeSOSGlobal();}catch(e){this.sosGlobal=makeSOSGlobal();this.toast("Could not load sos_global.json: "+S(e&&e.message||e),true);}}
  async loadSOSCatalog(){const ds=SOS_DATASETS.find(x=>x.id===this.sosGlobal.activeDataset)||SOS_DATASETS[0];const path=SOS_CATALOG_DIR+"/"+ds.file;try{const raw=JSON.parse(S(await this.ctx.fs.readProjectFile(path)||"{}"));this.sosCatalogRaw=raw;this.sosCatalog=this.expandSOSCatalog(raw);if(!this.sosCatalog||typeof this.sosCatalog!=="object")this.sosCatalog={profiles:[],groups:[],examples:[]};}catch(e){this.sosCatalogRaw=null;this.sosCatalog={id:ds.id,name:ds.name,profiles:[],groups:[],examples:[],runtimeUsable:false,description:"Catalog could not be loaded."};this.toast("SOS catalog load failed: "+S(e&&e.message||e),true);}}
  isSOSRestrictedSpecies(species,form=0){const sp=U(species);if(!sp)return false;const regional=sp.replace(/^(ALOLA|GALAR|HISUI|PALDEA)[_ -]+/,"");const compact=C(regional);if(SOS_RESTRICTED_SPECIES.has(compact))return true;const resolved=this.resolveCatalogEntity({species:sp,form:N(form)}),rid=resolved?C(resolved.species):C(sp);if(SOS_RESTRICTED_SPECIES.has(rid))return true;const rec=resolved?findSpecies(this.source,resolved.species,resolved.form):findSpecies(this.source,sp,form),flags=A(rec&&rec.flags).map(C);return flags.some(x=>x==="LEGENDARY"||x==="MYTHICAL"||x==="ULTRABEAST");}
  expandSOSCatalog(raw){
    const c=raw&&typeof raw==="object"?Object.assign({},raw):{},handRaw=A(c.examples).map(x=>Object.assign({},x)),hand=["legends_arceus","legends_za","pokerogue"].includes(S(c.id))?[]:handRaw,generated=[];
    const push=x=>{if(x&&x.id)generated.push(x);};
    const formTagForArceus=sp=>({GOODRA:"hisui",SLIGGOO:"hisui",TYPHLOSION:"hisui",LILLIGANT:"hisui",ARCANINE:"hisui",GROWLITHE:"hisui",QWILFISH:"hisui",SAMUROTT:"hisui",DECIDUEYE:"hisui",BRAVIARY:"hisui",AVALUGG:"hisui",SNEASEL:"hisui",ZORUA:"hisui",ZOROARK:"hisui",VOLTORB:"hisui",ELECTRODE:"hisui"}[U(sp)]||"");
    const entity=(sp,w,tag)=>{const x={species:U(sp),form:0,weight:w==null?100:w,requirements:[]};if(tag)x.formTag=tag;return x;};
    const arceusFamilies={
      RAICHU:["PIKACHU","PICHU"],PIKACHU:["PICHU"],CROBAT:["GOLBAT","ZUBAT"],GOLBAT:["ZUBAT"],PARASECT:["PARAS"],ALAKAZAM:["KADABRA","ABRA"],KADABRA:["ABRA"],GOLEM:["GRAVELER","GEODUDE"],GRAVELER:["GEODUDE"],RAPIDASH:["PONYTA"],MRMIME:["MIMEJR"],KLEAVOR:["SCYTHER"],SNORLAX:["MUNCHLAX"],WYRDEER:["STANTLER"],BEAUTIFLY:["SILCOON","WURMPLE"],DUSTOX:["CASCOON","WURMPLE"],WALREIN:["SEALEO","SPHEAL"],SEALEO:["SPHEAL"],INFERNAPE:["MONFERNO","CHIMCHAR"],MONFERNO:["CHIMCHAR"],STARAPTOR:["STARAVIA","STARLY"],STARAVIA:["STARLY"],BIBAREL:["BIDOOF"],KRICKETUNE:["KRICKETOT"],LUXRAY:["LUXIO","SHINX"],LUXIO:["SHINX"],FLOATZEL:["BUIZEL"],GASTRODON:["SHELLOS"],DRIFBLIM:["DRIFLOON"],LOPUNNY:["BUNEARY"],ZOROARK:["ZORUA"],GOLDUCK:["PSYDUCK"],GENGAR:["HAUNTER","GASTLY"],HAUNTER:["GASTLY"],STEELIX:["ONIX"],LICKILICKY:["LICKITUNG"],RHYPERIOR:["RHYDON","RHYHORN"],RHYDON:["RHYHORN"],TANGROWTH:["TANGELA"],TYPHLOSION:["QUILAVA","CYNDAQUIL"],QUILAVA:["CYNDAQUIL"],SUDOWOODO:["BONSLY"],YANMEGA:["YANMA"],HONCHKROW:["MURKROW"],URSALUNA:["URSARING","TEDDIURSA"],URSARING:["TEDDIURSA"],MAMOSWINE:["PILOSWINE","SWINUB"],PILOSWINE:["SWINUB"],ROSERADE:["ROSELIA","BUDEW"],ROSELIA:["BUDEW"],TORTERRA:["GROTLE","TURTWIG"],GROTLE:["TURTWIG"],SKUNTANK:["STUNKY"],BRONZONG:["BRONZOR"],HIPPOWDON:["HIPPOPOTAS"],DRAPION:["SKORUPI"],TOXICROAK:["CROAGUNK"],LILLIGANT:["PETILIL"],GOODRA:["SLIGGOO","GOOMY"],SLIGGOO:["GOOMY"],NINETALES:["VULPIX"],ARCANINE:["GROWLITHE"],MACHAMP:["MACHOKE","MACHOP"],MACHOKE:["MACHOP"],TENTACRUEL:["TENTACOOL"],BLISSEY:["CHANSEY","HAPPINY"],CHANSEY:["HAPPINY"],MAGMORTAR:["MAGMAR","MAGBY"],MAGMAR:["MAGBY"],GYARADOS:["MAGIKARP"],CLEFABLE:["CLEFAIRY","CLEFFA"],CLEFAIRY:["CLEFFA"],TOGEKISS:["TOGETIC","TOGEPI"],TOGETIC:["TOGEPI"],AMBIPOM:["AIPOM"],OVERQWIL:["QWILFISH"],MANTINE:["MANTYKE"],EMPOLEON:["PRINPLUP","PIPLUP"],PRINPLUP:["PIPLUP"],PURUGLY:["GLAMEOW"],LUCARIO:["RIOLU"],LUMINEON:["FINNEON"],BASCULEGION:["BASCULIN"],ELECTRODE:["VOLTORB"],ELECTIVIRE:["ELECTABUZZ","ELEKID"],ELECTABUZZ:["ELEKID"],MISMAGIUS:["MISDREAVUS"],GLISCOR:["GLIGAR"],SNEASLER:["SNEASEL"],PROBOPASS:["NOSEPASS"],DUSKNOIR:["DUSCLOPS","DUSKULL"],DUSCLOPS:["DUSKULL"],CHIMECHO:["CHINGLING"],GARCHOMP:["GABITE","GIBLE"],GABITE:["GIBLE"],ABOMASNOW:["SNOVER"],DECIDUEYE:["DARTRIX","ROWLET"],DARTRIX:["ROWLET"],GARDEVOIR:["KIRLIA","RALTS"],GALLADE:["KIRLIA","RALTS"],KIRLIA:["RALTS"],GLALIE:["SNORUNT"],FROSLASS:["SNORUNT"],SAMUROTT:["DEWOTT","OSHAWOTT"],DEWOTT:["OSHAWOTT"],BRAVIARY:["RUFFLET"],AVALUGG:["BERGMITE"]
    };
    const zaFamilies={PIDGEOTTO:["PIDGEY"],WHIRLIPEDE:["VENIPEDE"],FLETCHINDER:["FLETCHLING"],HOUNDOOM:["HOUNDOUR"],CAMERUPT:["NUMEL"],KROKOROK:["SANDILE"],MEOWSTIC:["ESPURR"],SHARPEDO:["CARVANHA"],SLOWBRO:["SLOWPOKE"],CLAWITZER:["CLAUNCHER"],ABOMASNOW:["SNOVER"],AVALUGG:["BERGMITE"],MACHOKE:["MACHOP"],TREVENANT:["PHANTUMP"],LAIRON:["ARON"],EXCADRILL:["DRILBUR"],SCOLIPEDE:["WHIRLIPEDE"],GOURGEIST:["PUMPKABOO"],BANETTE:["SHUPPET"],AMPHAROS:["FLAAFFY"],ALTARIA:["SWABLU"],SALAMENCE:["BAGON"],NOIVERN:["NOIBAT"],CLEFAIRY:["CLEFFA"]};
    if(c.id==="sm_usum"){
      // The project SOS PBS contains later-generation compatibility rows. The importer
      // intentionally uses only the curated Alola master examples, so Gen 8/9 species
      // (Cyclizar, etc.) can never leak into the SM/USUM library.
    }else if(c.id==="legends_arceus"||c.id==="legends_za"){
      const fam=c.id==="legends_arceus"?arceusFamilies:zaFamilies;
      A(c.groups).forEach(g=>{const legal=A(g.species).map(U).filter(sp=>!!sp&&!this.isSOSRestrictedSpecies(sp,0));legal.forEach(sp=>{const direct=A(fam[sp]).map(U).filter(x=>legal.includes(x)&&x!==sp),reverse=[];Object.keys(fam).forEach(parent=>{if(legal.includes(U(parent))&&A(fam[parent]).map(U).includes(sp)&&U(parent)!==sp)reverse.push(U(parent));});const rel=[...new Set(direct.concat(reverse))].slice(0,6);if(!rel.length)return;const tag=c.id==="legends_arceus"?formTagForArceus(sp):"",pool=rel.map((x,i)=>entity(x,i===0?65:Math.max(10,35/Math.max(1,rel.length-1)),c.id==="legends_arceus"?formTagForArceus(x):"")),direction=direct.length?"líder/familia":"refuerzo evolutivo";push({id:`${slug(c.id)}_${slug(g.id)}_${slug(sp)}_family`,name:`${S(c.name||c.id)} · ${S(g.name||g.id)} · ${sp} → ${rel.join(" / ")}`,sourceGroup:S(g.id),caller:Object.assign({species:sp,form:0,level:30},tag?{formTag:tag}:{}),callRate:30,answerRate:80,initialCall:true,pool,canonLevel:"CANON_SAFE",relationType:c.id==="legends_za"?"WILD_ZONE_PACK":"PACK",derived:true,note:c.id==="legends_za"?`Familia presente en ${S(g.name||g.id)} (${direction}); no es SOS literal de Alola.`:`Manada/oleada evolutiva coherente con Legends: Arceus (${direction}).`});});});
    }else if(c.id==="pokerogue"){
      // PokéRogue does not expose one canonical caller→ally table. Keep self-calls as
      // a legal option, but restore the variety of the earlier importer by also
      // offering nearby species from the same encounter pool plus evolution family.
      // Nearby entries are intentionally limited to a short window so a common slot
      // does not jump across the biome list into an unrelated legendary/rare tier.
      A(c.groups).forEach(g=>{const legalEntities=A(g.species).map(raw=>{const r=this.resolveCatalogEntity({species:raw,form:0});return r?{species:U(r.species),form:N(r.form),sourceId:U(raw)}:null;}).filter(x=>x&&x.species&&!this.isSOSRestrictedSpecies(x.species,x.form)),dedup=[];const seen=new Set();legalEntities.forEach(x=>{const k=`${x.species}:${x.form}`;if(!seen.has(k)){seen.add(k);dedup.push(x);}});const legal=dedup.map(x=>x.species);dedup.forEach((callerEnt,idx)=>{const sp=callerEnt.species;let family=this.evolutionFamilyMembers(sp,legal).filter(x=>x!==sp);const explicit=A(arceusFamilies[sp]).concat(A(zaFamilies[sp])).map(U).filter(x=>legal.includes(x)&&x!==sp);family=[...new Set(family.concat(explicit))];const nearby=[];[1,-1,2,-2].forEach(delta=>{const x=dedup[idx+delta];if(x&&x.species!==sp&&!nearby.some(y=>y.species===x.species&&y.form===x.form))nearby.push(x);});const allyEntities=[];family.forEach(x=>{const hit=dedup.find(y=>y.species===x);if(hit&&!allyEntities.some(y=>y.species===hit.species&&y.form===hit.form))allyEntities.push(hit);});nearby.forEach(x=>{if(!allyEntities.some(y=>y.species===x.species&&y.form===x.form))allyEntities.push(x);});const allies=allyEntities.slice(0,5),otherWeight=allies.length?65/allies.length:0,pool=[{species:sp,form:callerEnt.form,weight:allies.length?35:100,requirements:[]}].concat(allies.map(x=>({species:x.species,form:x.form,weight:otherWeight,requirements:[]})));push({id:`pokerogue_${slug(g.id)}_${slug(sp)}_${callerEnt.form}`,name:`PokéRogue · ${S(g.name||g.id)} · ${this.catalogEntityLabel(callerEnt)}`,sourceGroup:S(g.id),caller:{species:sp,form:callerEnt.form,level:30},callRate:30,answerRate:75,initialCall:true,pool,canonLevel:"CANON_SYSTEM",relationType:"DOUBLE_ENCOUNTER",derived:true,note:allies.length?`Pool variado: misma especie + familia y vecinos legales del encounter pool de ${S(g.name||g.id)}. El runtime real sigue validando el CURRENT_ENCOUNTER_POOL.`:`Sin pareja fija demostrable: se mantiene la misma especie como preset seguro.`});});});
    }
    // One caller = one import card. If source data has Eevee→Umbreon and Eevee→Espeon
    // as separate rows, both allies are merged into the same pool. Legendary, Mythical
    // and Ultra Beast species are excluded as callers and as recruitable allies.
    const merged=new Map();
    for(const src of hand.concat(generated)){
      if(!src)continue;const caller=Object.assign({},src.caller||{}),callerResolved=this.resolveCatalogEntity(caller),callerSpecies=callerResolved?U(callerResolved.species):U(caller.species),callerForm=callerResolved?N(callerResolved.form):N(caller.form),callerTag=S(caller.formTag);
      if(!callerSpecies||!callerResolved||this.isSOSRestrictedSpecies(callerSpecies,callerForm))continue;
      const cleanPool=[];A(src.pool).forEach((raw,i)=>{const p=typeof raw==="string"?{species:U(raw),form:0,weight:N(A(src.weights)[i],100),requirements:[]}:Object.assign({},raw||{}),resolved=this.resolveCatalogEntity(p);if(!resolved)return;p.species=U(resolved.species);p.form=N(resolved.form);p.weight=N(p.weight,100);p.requirements=A(p.requirements).map(r=>Object.assign({},r));const time=L(src.conditions&&src.conditions.time);if((p.species!==callerSpecies||p.form!==callerForm)&&(time==="day"||time==="night")&&!p.requirements.some(r=>S(r&&r.type)===time))p.requirements.push({type:time});if(!p.species||this.isSOSRestrictedSpecies(p.species,p.form))return;cleanPool.push(p);});
      if(!cleanPool.length)continue;
      const key=`${callerSpecies}:${callerForm}:${callerTag}`;let dst=merged.get(key);
      if(!dst){dst=Object.assign({},src,{id:S(src.id)||`${slug(c.id)}_${slug(callerSpecies)}_${callerForm}`,caller:Object.assign({},caller,{species:callerSpecies,form:callerForm}),pool:[],sourceGroups:[],sourceConditions:[],_notes:[],_relations:[],_canon:[]});merged.set(key,dst);}
      const sg=S(src.sourceGroup);if(sg&&!dst.sourceGroups.includes(sg))dst.sourceGroups.push(sg);if(src.conditions&&Object.keys(src.conditions).length)dst.sourceConditions.push({sourceGroup:sg,conditions:Object.assign({},src.conditions),pool:cleanPool.map(p=>p.species)});const note=S(src.note);if(note&&!dst._notes.includes(note))dst._notes.push(note);const rel=S(src.relationType);if(rel&&!dst._relations.includes(rel))dst._relations.push(rel);const canon=S(src.canonLevel);if(canon&&!dst._canon.includes(canon))dst._canon.push(canon);dst.callRate=Math.max(N(dst.callRate,0),N(src.callRate,0));dst.answerRate=Math.max(N(dst.answerRate,0),N(src.answerRate,0));dst.initialCall=!!(dst.initialCall||src.initialCall);
      cleanPool.forEach(p=>{const pk=`${p.species}:${N(p.form)}:${S(p.formTag)}`,prev=dst.pool.find(x=>`${U(x.species)}:${N(x.form)}:${S(x.formTag)}`===pk);if(!prev)dst.pool.push(p);else{prev.weight=Math.max(N(prev.weight,0),N(p.weight,0));if(!A(prev.requirements).length&&A(p.requirements).length)prev.requirements=A(p.requirements);}});
    }
    c.examples=[...merged.values()].map(x=>{x.sourceGroup=x.sourceGroups.length===1?x.sourceGroups[0]:(x.sourceGroup||x.sourceGroups[0]||"all");x.note=x._notes.join(" · ")||S(x.note);x.relationType=x._relations.join(" + ")||S(x.relationType);x.canonLevel=x._canon[0]||S(x.canonLevel);const allies=x.pool.map(p=>this.catalogEntityLabel(p)||U(p.species)).join(" / ");x.name=`${S(c.name||c.id)} · ${this.catalogEntityLabel(x.caller)||U(x.caller.species)} → ${allies}`;delete x._notes;delete x._relations;delete x._canon;return x;});return c;
  }
  evolutionFamilyMembers(species,legal){const wanted=U(species),allowed=new Set(A(legal).map(U)),graph=new Map();A(this.source&&this.source.species).forEach(x=>{const a=U(x.species);if(!graph.has(a))graph.set(a,new Set());A(x.evolutions).map(U).forEach(b=>{if(!b)return;if(!graph.has(b))graph.set(b,new Set());graph.get(a).add(b);graph.get(b).add(a);});});const seen=new Set([wanted]),queue=[wanted];while(queue.length){const a=queue.shift(),edges=graph.get(a);if(!edges)continue;edges.forEach(b=>{if(!seen.has(b)){seen.add(b);queue.push(b);}});}return [...seen].filter(x=>allowed.has(x));
  }
  async saveSOSConfig(silent=false){try{await this.ctx.fs.projectMkdir(DATA_DIR);await this.ctx.fs.writeProjectFile(SOS_GLOBAL_FILE,JSON.stringify(this.sosGlobal,null,2));if(!silent)this.toast("SOS JSON saved");return true;}catch(e){this.toast("SOS save failed: "+S(e&&e.message||e),true);return false;}}
  saveSOSConfigSoon(){clearTimeout(this.sosSaveDelay);this.sosSaveDelay=setTimeout(()=>this.saveSOSConfig(true),350);}

  touch(){const b=this.battle();if(b)b.updatedAt=Date.now();this.saveSoon();}
  saveSoon(){clearTimeout(this.saveDelay);this.saveDelay=setTimeout(()=>this.save(true),300);}
  safeRemove(node){if(!node)return false;try{const active=document.activeElement;if(active&&node.contains&&node.contains(active)){try{this.root.focus({preventScroll:true})}catch(_){try{active.blur()}catch(__){}}}}catch(_){}const parent=node.parentNode;if(!parent)return false;try{if(node.parentNode===parent)parent.removeChild(node);return true;}catch(_){try{if(node.parentNode)node.parentNode.removeChild(node)}catch(__){try{node.style.display="none"}catch(___){} }return false;}}
  persistEditorError(where,err){try{const payload={version:BSS_VERSION,where:S(where),message:S(err&&err.message||err||"Unknown error"),stack:S(err&&err.stack||""),at:new Date().toISOString()};this.ctx.fs.projectMkdir(DATA_DIR).then(()=>this.ctx.fs.writeProjectFile(DATA_DIR+"/editor_last_error.json",JSON.stringify(payload,null,2))).catch(()=>{});}catch(_){}}
  reportError(where,err){const msg=S(err&&err.message||err||"Unknown error"),stack=S(err&&err.stack||"");this.persistEditorError(where,err);try{this.ctx&&this.ctx.log&&this.ctx.log.error&&this.ctx.log.error(`[BSS ${where}] ${msg}${stack?`\n${stack}`:""}`);}catch(_){}try{this.toast(`BSS ${where}: ${msg}`,true);}catch(_){}}
  toast(msg,bad=false){let old=this.root.querySelector(".bss-toast");if(old)this.safeRemove(old);const x=document.createElement("div");x.className="bss-toast"+(bad?" bss-error":"");x.textContent=msg;this.root.appendChild(x);clearTimeout(this.toastTimer);this.toastTimer=setTimeout(()=>{if(x&&x.isConnected)this.safeRemove(x)},3600);}
  clearGraphicCaches(){for(const u of this.assetUrlCache.values())try{URL.revokeObjectURL(u)}catch(_){}this.assetUrlCache.clear();this.assetUrlPending.clear();this.frameCache.clear();this.framePending.clear();this.renderMetaCache.clear();this.renderMetaPending.clear();this.renderCompatWarmPromise=null;this.auraRuntimeAssetCache.clear();this.auraTintCache.clear();try{clearBattlerRenderingCache()}catch(_){}}
  async rescanFast(){try{const source=await scanProjectCoreSource(this.ctx);this.source=normalizeSourceRows(source||{species:[],moves:[],items:[],trainers:[],battlebacks:[],battlebackGroups:[],foeSprites:[],userSprites:[],pokemonIcons:[],trainerSprites:[],bgmFiles:[],seFiles:[],graphicsReady:false});if(this.sosCatalogRaw)this.sosCatalog=this.expandSOSCatalog(this.sosCatalogRaw);this.render();}catch(e){this.toast("Project PBS scan failed: "+S(e&&e.message||e),true);}}
  async loadGraphicsInBackground(){if(this.graphicsLoading||this.graphicsLoadPromise)return this.graphicsLoadPromise;this.graphicsLoading=true;this.graphicsLoadPromise=(async()=>{try{const [graphics,runtimeContext,projectScriptContext]=await Promise.all([scanProjectGraphicsSource(this.ctx),readRuntimeContext(this.ctx).catch(()=>null),detectProjectBattleContext(this.ctx).catch(()=>null)]);Object.assign(this.source,graphics||{}, {graphicsReady:true});this.source=normalizeSourceRows(this.source);this.runtimeContext=runtimeContext||null;this.projectScriptContext=projectScriptContext||null;const warmAsset=A(this.source.userSprites)[0]||A(this.source.foeSprites)[0]||null;if(warmAsset){const warmSide=A(this.source.userSprites).includes(warmAsset)?"user":"target",warmCfg={name:S(warmAsset&&warmAsset.name),projectPath:S(warmAsset&&warmAsset.projectPath)};this.renderCompatWarmPromise=loadBattlerRenderingInfo(this.ctx,warmCfg,warmSide).catch(()=>null);}if(this.screen==="library")this.hydrateLibraryArt();else if(this.screen==="editor"){this.remountPreviewOnly();this.hydrateInspectorIcons();if(["boss","aura"].includes(this.section)){this.hydrateAuraTestBattler();this.hydrateAuraRuntimePreview();this.startAuraPreviewLoop();}}else if(this.screen==="sos")this.hydrateSOSIcons();else if(this.screen==="aura")this.hydrateAuraTestBattler();}catch(e){this.toast("Graphics scan failed: "+S(e&&e.message||e),true);}finally{this.graphicsLoading=false;this.graphicsLoadPromise=null;}})();return this.graphicsLoadPromise;}
  async rescan(silent=false){try{this.clearGraphicCaches();const [source,runtimeContext,projectScriptContext]=await Promise.all([scanProjectSource(this.ctx),readRuntimeContext(this.ctx).catch(()=>null),detectProjectBattleContext(this.ctx).catch(()=>null)]);this.source=normalizeSourceRows(source);this.runtimeContext=runtimeContext||null;this.projectScriptContext=projectScriptContext||null;const warmAsset=A(this.source.userSprites)[0]||A(this.source.foeSprites)[0]||null;if(warmAsset){const warmSide=A(this.source.userSprites).includes(warmAsset)?"user":"target",warmCfg={name:S(warmAsset&&warmAsset.name),projectPath:S(warmAsset&&warmAsset.projectPath)};this.renderCompatWarmPromise=loadBattlerRenderingInfo(this.ctx,warmCfg,warmSide).catch(()=>null);}if(this.sosCatalogRaw)this.sosCatalog=this.expandSOSCatalog(this.sosCatalogRaw);if(!silent)this.toast(`Data reloaded · ${this.source.species.length} species/forms · ${A(this.source.items).length} items · ${this.source.battlebackGroups.length} battlebacks · ${A(this.source.bgmFiles).length} BGM${this.runtimeContext?" · BAS runtime context":this.projectScriptContext?" · BAS script context":""}`);this.render();}catch(e){this.toast("Project scan failed: "+S(e&&e.message||e),true);}}
  async pollStatus(){
    try{if(await this.ctx.fs.projectExists(STATUS_FILE)){this.status=JSON.parse(S(await this.ctx.fs.readProjectFile(STATUS_FILE)||"{}"));}else this.status={state:"offline"};}catch(_){this.status={state:"offline"};}
    const st=S(this.status&&this.status.state),el=this.root.querySelector("[data-game]");if(el){const on=["ready","running","finished","f12_resuming","resume_needed"].includes(st);el.textContent=(st==="f12_resuming"||st==="resume_needed")?"Game F12 · restoring test":on?`Game ${st}`:"Game offline";el.classList.toggle("off",!on);}
  }
  render(){
    this.disposePreview();if(this.screen!=="aura")this.stopAuraPreviewLoop();
    if(this.screen!=="editor"&&this.pokemonEditor)this.closePokemonEditor();
    if(!this.picker){const pm=this.root.querySelector("[data-bss-picker-modal]");if(pm)this.safeRemove(pm);}
    if(!this.assetPicker){const am=this.root.querySelector("[data-bss-asset-picker]");if(am)this.safeRemove(am);}
    this.root.querySelectorAll("[data-nav]").forEach(x=>x.classList.toggle("active",x.dataset.nav===this.screen||(this.screen==="editor"&&x.dataset.nav==="library")));
    if(this.screen==="sos")this.renderSOSStudio();
    else if(this.screen==="aura")this.renderAuraStudio();
    else if(this.screen==="ebdx")this.renderEBDXStudio();
    else if(this.screen==="editor")this.renderEditor();
    else this.renderLibrary();
    if(this.sosPoolModalKey&&this.screen==="sos"&&!this.picker&&!this.assetPicker)this.renderSOSPoolModal();
    if(this.picker)this.renderPicker();
    if(this.assetPicker)this.renderAssetPicker();
    if(this.sosImportOpen&&this.screen==="sos")this.renderSOSImporter();
    if(this.globalSettingsOpen)this.renderGlobalSettingsModal();
  }
  renderLibrary(){
    const groups=A(this.studio.groups),active=groups.find(g=>g.id===this.activeGroup)||groups.find(g=>g.id===(this.studio.global&&this.studio.global.mainGroupId))||groups[0];if(active)this.activeGroup=active.id;
    const q=L(this.search),rows=this.studio.blueprints.filter(b=>(!active||b.groupId===active.id)&&(!q||L(`${b.name} ${b.key} ${b.category||""}`).includes(q)));
    this.body.innerHTML=`<section class="bss-library"><div class="bss-libhead"><select class="bss-select bss-groupselect" data-group-filter>${groups.map(g=>`<option value="${E(g.id)}" ${g.id===this.activeGroup?"selected":""}>${E(g.name)}${g.system?" · principal":""}</option>`).join("")}</select><button class="bss-btn" data-act="group-new">＋ Librería</button><button class="bss-btn" data-act="group-rename">Renombrar</button>${active&&!active.system?`<button class="bss-btn danger" data-act="group-delete">Eliminar librería</button>`:""}<input class="bss-search" data-search placeholder="Buscar combates/categorías…" value="${E(this.search)}"><button class="bss-btn primary" data-act="new">＋ Nuevo combate</button><span class="bss-note">${rows.length} combate${rows.length===1?"":"s"}</span></div>${active&&active.system?`<div class="bss-mainlib-note"><b>${E(active.name)}</b> es la librería principal. Aquí quedan los blueprints de encuentros salvajes normales; las demás librerías sirven para organizar rutas, zonas, eventos o pruebas.</div>`:""}<div class="bss-grid">${rows.map(b=>`<article class="bss-card" data-card="${E(b.id)}"><div class="bss-card-art"><span class="kind">${E(this.battleTypeLabel(b))} · ${E(b.setup.formation)}</span><div class="bss-icon ph" data-card-art="${E(b.id)}">?</div></div><div class="bss-card-body"><input class="bss-input" data-name="${E(b.id)}" value="${E(b.name)}"><small>${E(b.category?`${b.category} · `:"")}${E(b.setup.kind==="trainer"?`${b.setup.trainer.name||"Trainer"} · ${b.teams.foes.length} Pokémon`:`${b.teams.foes[0]&&b.teams.foes[0].species||"Wild"} · Lv.${b.teams.foes[0]&&b.teams.foes[0].level||50}`)}</small><select class="bss-select bss-card-group" data-move-group="${E(b.id)}">${groups.map(g=>`<option value="${E(g.id)}" ${b.groupId===g.id?"selected":""}>${E(g.name)}</option>`).join("")}</select><div class="bss-card-actions"><button class="bss-btn primary" data-open="${E(b.id)}">Abrir</button><button class="bss-btn" data-test="${E(b.id)}">Probar</button><button class="bss-btn" data-event="${E(b.id)}">Comando</button></div></div></article>`).join("")||`<div class="bss-empty">No hay combates en esta librería.</div>`}</div></section>`;this.hydrateLibraryArt();
  }
  async hydrateLibraryArt(){const els=[...this.body.querySelectorAll("[data-card-art]")];await mapLimit(els,5,async el=>{const b=this.studio.blueprints.find(x=>x.id===el.dataset.cardArt);if(!b)return;let asset=null;if(b.setup.kind==="trainer")asset=findTrainerSprite(this.source,b.setup.trainer.trainerType||b.setup.trainer.type);else asset=findBattlerSprite(this.source,b.teams.foes[0]&&b.teams.foes[0].species,"target");const url=await this.frameUrl(asset,"card:"+(asset&&asset.projectPath||""));if(url&&el.isConnected)el.outerHTML=`<img data-card-art="${E(b.id)}" src="${E(url)}">`;});}
  uniqueKey(base,except){let key=slug(base),i=2;while(this.studio.blueprints.some(b=>b.id!==except&&b.key===key))key=slug(base)+"_"+(i++);return key;}
  battleTypeLabel(b){const kind=S(b&&b.setup&&b.setup.kind)==="trainer"?"Trainer":"Wild";return b&&b.boss&&b.boss.enabled?`${kind} (Totem)`:kind;}
  refreshInspector(preserveScroll=true){const b=this.battle(),inner=this.body&&this.body.querySelector(".bss-inspector-inner"),scroller=this.body&&this.body.querySelector(".bss-inspector");if(!b||!inner)return;const oldTop=preserveScroll&&scroller?scroller.scrollTop:0;inner.innerHTML=this.inspectorHTML(b);this.body.querySelectorAll("[data-section]").forEach(x=>x.classList.toggle("active",x.dataset.section===this.section));if(scroller)requestAnimationFrame(()=>{if(scroller.isConnected)scroller.scrollTop=preserveScroll?oldTop:0;});this.hydrateInspectorIcons();if(["boss","aura"].includes(this.section)){this.hydrateAuraTestBattler();this.hydrateAuraRuntimePreview();this.startAuraPreviewLoop();}if(this.pokemonEditor)this.renderPokemonEditor();}
  switchSection(section){const next=S(section||"setup"),scroller=this.body&&this.body.querySelector(".bss-inspector");if(scroller)this.sectionScroll[this.section]=scroller.scrollTop;this.section=next;if(this.screen==="editor"&&this.body&&this.body.querySelector(".bss-editor")){this.refreshInspector(false);const target=this.body.querySelector(".bss-inspector"),saved=N(this.sectionScroll[next],0);if(target)requestAnimationFrame(()=>{if(target.isConnected)target.scrollTop=saved;});return;}this.render();}
  remountPreviewOnly(){if(this.screen!=="editor"||this.previewCollapsed)return;const b=this.battle(),canvas=this.body&&this.body.querySelector("[data-preview]");if(!b||!canvas)return;this.disposePreview();this.mountPreview(b);const state=this.body.querySelector("[data-graphics-state]");if(state)state.textContent=this.source&&this.source.graphicsReady?"Preview BAS":"Cargando gráficos…";}
  refreshStageSummary(){const b=this.battle(),el=this.body&&this.body.querySelector("[data-battle-summary]");if(b&&el)el.textContent=`${this.battleTypeLabel(b)} · ${S(b.setup&&b.setup.formation||"1v1")} · ${b.sos&&b.sos.enabled?"SOS native":"normal"}`;}
  pokemonEditorRecord(){const token=S(this.pokemonEditor&&this.pokemonEditor.target),b=this.battle();if(!b||!token)return null;if(token.startsWith("team:")){const parts=token.split(":"),key=S(parts[1]),idx=N(parts[2]);return b.teams&&A(b.teams[key])[idx]||null;}if(token.startsWith("sos:"))return A(b.sos&&b.sos.pool)[N(token.slice(4))]||null;return null;}
  openPokemonEditor(target){this.pokemonEditor={target:S(target)};this.renderPokemonEditor();}
  closePokemonEditor(){this.pokemonEditor=null;const old=this.root.querySelector("[data-pokemon-editor]");if(old)this.safeRemove(old);}
  pokemonCustomActive(p){return !!(p&&(p.ability||p.nature||p.item||p.gender&&p.gender!=="auto"||p.happiness!=null||p.shiny===true||S(p.moveMode)==="custom"||Object.values(p.ivs||{}).some(v=>v!=null)||Object.values(p.evs||{}).some(v=>v!=null)));}
  moveCatalogRows(){return A(this.source&&this.source.moves).map((m,order)=>({id:U(m&&m.id),name:S(m&&m.name||m&&m.id),order})).filter(m=>m.id).sort((a,b)=>a.order-b.order||a.name.localeCompare(b.name,undefined,{numeric:true,sensitivity:"base"})||a.id.localeCompare(b.id));}
  findTypedMove(value,rows=this.moveCatalogRows()){const q=L(S(value).trim());if(!q)return null;const exact=rows.find(m=>L(m&&m.id)===q||L(m&&m.name)===q);if(exact)return exact;return rows.find(m=>L(m&&m.name).startsWith(q)||L(m&&m.id).startsWith(q))||rows.find(m=>L(m&&m.name).includes(q)||L(m&&m.id).includes(q))||null;}
  commitPokemonMove(p,slot,value){if(!p||slot<0||slot>3)return;p.moves=A(p.moves).slice(0,4);while(p.moves.length<4)p.moves.push("");p.moves[slot]=U(S(value).trim());p.moveMode="custom";this.touch();}
  wirePokemonMovePickers(modal,p,rows){if(!modal||!p)return;const stop=e=>{try{e.stopPropagation();if(typeof e.stopImmediatePropagation==="function")e.stopImmediatePropagation();}catch(_){}};modal.querySelectorAll("[data-mon-move-query]").forEach(query=>{const slot=N(query.dataset.monMoveQuery,-1),list=modal.querySelector(`[data-mon-move-list="${slot}"]`),help=modal.querySelector(`[data-mon-move-help="${slot}"]`);if(slot<0||!list)return;const preview=()=>{const match=this.findTypedMove(query.value,rows);if(match){list.value=match.id;if(help)help.textContent=`${match.name} · ${match.id}`;}else{list.value="";if(help)help.textContent=S(query.value).trim()?"No está en el catálogo: se guardará como ID custom al confirmar.":"Escribe nombre o ID, o elige una coincidencia del catálogo.";}return match;};const commit=()=>{const match=this.findTypedMove(query.value,rows),raw=S(query.value).trim();this.commitPokemonMove(p,slot,match?match.id:raw);if(match)query.value=match.name||match.id;preview();};query.oninput=e=>{stop(e);preview();};query.onchange=e=>{stop(e);commit();};query.onkeydown=e=>{if(e.key!=="Enter")return;stop(e);e.preventDefault();commit();};list.onchange=e=>{stop(e);const match=rows.find(m=>m.id===U(list.value));if(match){query.value=match.name||match.id;this.commitPokemonMove(p,slot,match.id);}else{query.value="";this.commitPokemonMove(p,slot,"");}preview();};preview();});}
  renderPokemonEditor(){const old=this.root.querySelector("[data-pokemon-editor]");if(old)this.safeRemove(old);const p=this.pokemonEditorRecord();if(!p){this.pokemonEditor=null;return;}const target=S(this.pokemonEditor.target),isSOS=target.startsWith("sos:"),rec=findSpecies(this.source,p.species,p.form)||{},abilities=[...new Set([...A(rec.abilities),...A(rec.hiddenAbilities)].map(U).filter(Boolean))],stamp=Date.now().toString(36),abilityList=`bss-ability-${stamp}`,itemList=`bss-mon-items-${stamp}`,moveMode=S(p.moveMode)==="custom"?"custom":"default",moves=A(p.moves).slice(0,4),moveRows=this.moveCatalogRows();while(moves.length<4)moves.push("");const moveOptions=(slot)=>`<option value="">— Vacío —</option>${moveRows.map(m=>`<option value="${E(m.id)}" ${U(moves[slot])===m.id?"selected":""}>${E(m.name)} · ${E(m.id)}</option>`).join("")}`;const moveChooser=(i)=>{const current=moveRows.find(m=>m.id===U(moves[i])),shown=current?(current.name||current.id):S(moves[i]);return `<div class="bss-movechoice"><label><span>Movimiento ${i+1}</span><input class="bss-input" data-mon-move-query="${i}" placeholder="Nombre o ID del movimiento…" value="${E(shown)}"></label><select class="bss-select" data-mon-move-list="${i}">${moveOptions(i)}</select><small class="bss-note" data-mon-move-help="${i}">Escribe nombre o ID, o elige una coincidencia del catálogo.</small></div>`;};const modal=document.createElement("div");modal.className="bss-modalback bss-mon-modalback";modal.dataset.pokemonEditor="1";modal.innerHTML=`<div class="bss-modal bss-mon-modal"><div class="bss-modalhead"><div><b>${isSOS?"SOS guionizado":"Pokémon del equipo"} · ${E(p.species)}${N(p.form)?` · F${N(p.form)}`:""}</b><small class="bss-note">Configura solo lo que quieras sobrescribir. Vacío/Auto conserva el comportamiento normal del proyecto.</small></div><div class="bss-spacer"></div><button class="bss-btn" data-act="reset-pokemon-custom">Restablecer custom</button><button class="bss-btn" data-act="close-pokemon-editor">✕</button></div><div class="bss-modalbody"><div class="bss-mon-sections"><details open class="bss-optiongroup"><summary>Identidad y combate</summary><div class="bss-mon-grid">${this.field("Habilidad",`<input class="bss-input" list="${abilityList}" data-mon-field="ability" placeholder="Auto" value="${E(p.ability||"")}"><datalist id="${abilityList}">${abilities.map(id=>`<option value="${E(id)}"></option>`).join("")}</datalist><span class="bss-note">${abilities.length?`Disponibles para esta especie: ${E(abilities.join(", "))}`:"Puedes escribir cualquier Ability ID válido del proyecto."}</span>`)}${this.field("Naturaleza",`<select class="bss-select" data-mon-field="nature"><option value="">Auto</option>${NATURES.map(id=>`<option value="${id}" ${U(p.nature)===id?"selected":""}>${E(natureLabel(id))}</option>`).join("")}</select><span class="bss-note">${p.nature?E(natureLabel(p.nature)):"Auto = naturaleza normal del Pokémon."}</span>`)}${this.field("Objeto",`<input class="bss-input" list="${itemList}" data-mon-field="item" placeholder="Sin override / Item ID" value="${E(p.item||"")}"><datalist id="${itemList}">${A(this.source.items).map(it=>`<option value="${E(it.id)}">${E(it.name||it.id)}</option>`).join("")}</datalist><span class="bss-note">${A(this.source.items).length?`${A(this.source.items).length} objetos leídos desde PBS/items*.txt.`:"No se encontraron objetos en PBS; puedes escribir un Item ID manualmente."}</span>`)}${this.field("Género",`<select class="bss-select" data-mon-field="gender"><option value="auto" ${S(p.gender)==="auto"?"selected":""}>Auto</option><option value="male" ${S(p.gender)==="male"?"selected":""}>Male</option><option value="female" ${S(p.gender)==="female"?"selected":""}>Female</option></select>`)}${this.field("Felicidad",`<input class="bss-input" type="number" min="0" max="255" data-mon-field="happiness" placeholder="Normal" value="${p.happiness==null?"":E(p.happiness)}">`)}<label class="bss-check"><input type="checkbox" data-mon-field="shiny" ${p.shiny?"checked":""}> Shiny</label></div></details><details class="bss-optiongroup"><summary>IVs / EVs</summary><p class="bss-note">Deja una casilla vacía para no forzar ese stat.</p><div class="bss-stat-editor"><b>IVs</b>${POKEMON_STATS.map(([id,label])=>`<label><span>${E(label)}</span><input class="bss-input" type="number" min="0" max="31" data-mon-iv="${id}" placeholder="Auto" value="${p.ivs&&p.ivs[id]!=null?E(p.ivs[id]):""}"></label>`).join("")}</div><div class="bss-stat-editor"><b>EVs</b>${POKEMON_STATS.map(([id,label])=>`<label><span>${E(label)}</span><input class="bss-input" type="number" min="0" max="252" data-mon-ev="${id}" placeholder="Auto" value="${p.evs&&p.evs[id]!=null?E(p.evs[id]):""}"></label>`).join("")}</div></details><details class="bss-optiongroup" ${moveMode==="custom"?"open":""}><summary>Movepool</summary>${this.field("Modo",`<select class="bss-select" data-mon-move-mode><option value="default" ${moveMode==="default"?"selected":""}>Por nivel / normal</option><option value="custom" ${moveMode==="custom"?"selected":""}>Custom</option></select>`)}${moveMode==="custom"?`<div class="bss-movegrid">${[0,1,2,3].map(moveChooser).join("")}</div><p class="bss-note">Selector basado en New Move de BAS: búsqueda segura por nombre/ID + coincidencia explícita del catálogo. También admite un ID custom.</p>`:`<p class="bss-note">Usa el movepool que tendría normalmente al nivel configurado.</p>`}</details></div></div></div>`;this.root.appendChild(modal);if(moveMode==="custom")this.wirePokemonMovePickers(modal,p,moveRows);}
  renderEditor(){const b=this.battle();if(!b){this.screen="library";return this.renderLibrary();}const collapsed=!!this.previewCollapsed,sections=[["setup","Setup"],["foes","Foe team"],["test","Test team"],["scene","Scene / Audio"],["boss","Boss / Totem"],["aura","Aura"],["sos","SOS"],["dialogues","Guionización"]];const sectionButtons=(cls="bss-section")=>sections.map(([k,n])=>`<button class="${cls} ${this.section===k?"active":""}" data-section="${k}">${cls==="bss-section"?`<i class="bss-dot"></i>`:""}${n}</button>`).join("");this.body.innerHTML=`<section class="bss-editor ${collapsed?"preview-collapsed":""}" style="--left:${this.left}px;--right:${this.right}px"><aside class="bss-side"><div class="bss-side-head"><button class="bss-btn small" data-act="back">← Library</button></div><div class="bss-sections">${sectionButtons()}</div></aside><div class="bss-resizer" data-resize="left"></div><main class="bss-stagewrap"><div class="bss-stagebar"><b>${E(b.name)}</b><span class="bss-note" data-battle-summary>${E(this.battleTypeLabel(b))} · ${E(b.setup.formation)} · ${b.sos.enabled?"SOS native":"normal"}</span><div class="bss-spacer"></div><span class="bss-note" data-graphics-state>${this.source&&this.source.graphicsReady?"Preview BAS":"Cargando gráficos…"}</span><button class="bss-btn small" data-act="toggle-preview">${collapsed?"Mostrar preview":"Ocultar preview"}</button>${collapsed?"":`<button class="bss-btn small" data-act="reset-pos">Reset positions</button>`}<button class="bss-btn small" data-test="${E(b.id)}">Test game</button></div><div class="bss-stage">${collapsed?`<div class="bss-preview-collapsed-note"><b>Preview oculta</b><small>El inspector gana espacio y BSS no renderiza la preview hasta que vuelvas a mostrarla.</small><button class="bss-btn small" data-act="toggle-preview">Mostrar preview BAS</button></div>`:`<div class="bss-canvasbox"><canvas data-preview></canvas><span class="bss-hint">Preview compacta BAS · drag USER/TARGET · rueda = escala</span></div>`}</div></main><div class="bss-resizer" data-resize="right"></div><aside class="bss-inspector"><div class="bss-inspector-jumpbar">${sectionButtons("bss-jump")}</div><div class="bss-inspector-subnav" data-inspector-subnav></div><div class="bss-inspector-inner">${this.inspectorHTML(b)}</div></aside></section>`;if(!collapsed)this.mountPreview(b);if(["boss","aura"].includes(this.section)){this.hydrateAuraTestBattler();this.hydrateAuraRuntimePreview();this.startAuraPreviewLoop();}if(this.pokemonEditor)this.renderPokemonEditor();}
  inspectorHTML(b){if(this.section==="foes")return this.panel("Foe team",this.teamHTML(b,"foes"));if(this.section==="test")return this.panel("Test team",this.teamHTML(b,"testPlayer"));if(this.section==="scene")return this.sceneHTML(b);if(this.section==="boss")return this.bossHTML(b);if(this.section==="aura")return this.auraSectionHTML(b);if(this.section==="sos")return this.sosHTML(b);if(this.section==="dialogues")return this.dialoguesHTML(b);return this.setupHTML(b);}
  panel(title,body){return `<section class="bss-panel"><h3>${E(title)}</h3><div class="bss-panel-body">${body}</div></section>`;}
  setupHTML(b){
    const groups=A(this.studio.groups),totem=!!(b.boss&&b.boss.enabled),trainer=b.setup.kind==="trainer";
    return this.panel("Setup",`<details open class="bss-optiongroup"><summary>Identidad del combate</summary>${this.field("Battle name",`<input class="bss-input" data-bind="name" value="${E(b.name)}">`)}${this.field("Event key",`<input class="bss-input" data-bind="key" value="${E(b.key)}"><span class="bss-note">${E(eventCommand(b))}</span>`)}${this.field("Librería",`<select class="bss-select" data-bind="groupId">${groups.map(g=>`<option value="${E(g.id)}" ${b.groupId===g.id?"selected":""}>${E(g.name)}</option>`).join("")}</select>`)}${this.field("Categoría",`<input class="bss-input" data-bind="category" placeholder="Ej. hierba, noche, raro…" value="${E(b.category||"")}">`)}</details><details open class="bss-optiongroup"><summary>Formato del combate</summary>${this.field("Type",`<select class="bss-select" data-bind="setup.kind"><option value="wild" ${b.setup.kind==="wild"?"selected":""}>Wild${totem?" (Totem)":""}</option><option value="trainer" ${b.setup.kind==="trainer"?"selected":""}>Trainer${totem?" (Totem)":""}</option></select>`)}${this.field("Formation",`<select class="bss-select" data-bind="setup.formation">${["1v1","1v2","2v1","2v2","3v3"].map(x=>`<option ${b.setup.formation===x?"selected":""}>${x}</option>`).join("")}</select>`)}${this.field("Nivel de IA del oponente",`<div class="bss-row" style="gap:6px;"><input class="bss-input" type="number" min="0" max="100" data-bind="setup.aiSkill" placeholder="Auto" value="${b.setup.aiSkill==null?"":E(b.setup.aiSkill)}" style="max-width:90px;"><div class="bss-row" style="gap:4px;"><button type="button" class="bss-btn small" data-act="setup-ai-preset" data-val="0">0</button><button type="button" class="bss-btn small" data-act="setup-ai-preset" data-val="32">32</button><button type="button" class="bss-btn small" data-act="setup-ai-preset" data-val="48">48</button><button type="button" class="bss-btn small primary" data-act="setup-ai-preset" data-val="100">100</button></div></div><span class="bss-note">0-100. Vacío = toma la habilidad por defecto del Trainer o salvaje. 100 = máxima inteligencia y predicción táctica.</span>`)}<label class="bss-check"><input type="checkbox" data-bind="setup.canLose" ${b.setup.canLose?"checked":""}> Can lose</label><label class="bss-check"><input type="checkbox" data-bind="setup.noExp" ${b.setup.noExp?"checked":""}> No ganar EXP en este combate</label><span class="bss-note">Desactiva EXP y EVs usando la regla nativa <b>no_exp_gain</b> de Essentials. No altera la captura, la victoria ni el resto del final del combate.</span></details>${trainer?`<details open class="bss-optiongroup"><summary>Trainer</summary>${this.field("Trainer type",`<input class="bss-input" data-bind="setup.trainer.type" value="${E(b.setup.trainer.type||"")}">`)}${this.field("Trainer name",`<input class="bss-input" data-bind="setup.trainer.name" value="${E(b.setup.trainer.name||"")}">`)}${this.field("Mensaje de derrota del trainer",`<input class="bss-input" data-bind="setup.trainer.defeatMessage" placeholder="Usar mensaje por defecto" value="${E(b.setup.trainer.defeatMessage||"")}">`)}</details>`:""}<details open class="bss-optiongroup"><summary>Final del combate guionizado</summary>${this.field("Mensaje de victoria",`<input class="bss-input" data-bind="setup.victoryMessage" placeholder="¡Has derrotado al {1} Dominante!" value="${E(b.setup.victoryMessage||"")}"><span class="bss-note">{1} = nombre del Pokémon Boss. Vacío no añade mensaje extra.</span>`)}<label class="bss-check"><input type="checkbox" data-bind="setup.victoryCelebration" ${b.setup.victoryCelebration!==false?"checked":""}> El Pokémon del jugador celebra con dos brincos + cry</label></details>`);
  }
  field(name,html){return `<label class="bss-field"><span>${E(name)}</span>${html}</label>`;}
  teamHTML(b,key){const team=A(b.teams[key]);return `${team.map((p,i)=>{const custom=this.pokemonCustomActive(p);return `<div class="bss-teamrow"><button class="bss-btn bss-specbtn" data-pick-spec="${E(key)}:${i}"><span class="bss-icon ph" data-inline-icon="${E(key)}:${i}">?</span><span>${E(p.species)}</span></button><input class="bss-input" type="number" min="1" max="100" data-team-level="${E(key)}:${i}" value="${N(p.level,50)}"><button class="bss-btn small ${custom?"active":""}" data-pokemon-edit="team:${E(key)}:${i}" title="Ability, Nature, IVs, EVs, item, moves…">⚙</button><button class="bss-btn small danger" data-team-remove="${E(key)}:${i}">×</button></div>`;}).join("")}<button class="bss-btn" data-team-add="${E(key)}">＋ Pokémon</button><p class="bss-note">La lista queda compacta. Usa ⚙ para Habilidad, Naturaleza, IVs, EVs, objeto, Shiny, género, felicidad y movepool.</p>`;}
  sceneHTML(b){
    const groups=A(this.source.battlebackGroups),env=b.environment||{},globalBases=this.studio.global&&this.studio.global.battleBasesEnabled!==false,basesMode=["inherit","on","off"].includes(S(env.basesMode))?S(env.basesMode):"inherit";
    const assetRow=(value,target,kind,label)=>`<div class="bss-asset-field"><input class="bss-input" value="${E(value||"")}" readonly placeholder="${E(label)}"><button class="bss-btn small" type="button" data-asset-browse="${E(target)}" data-asset-kind="${E(kind)}">Buscar…</button>${value?`<button class="bss-btn small" type="button" data-asset-clear="${E(target)}">Quitar</button>`:""}</div>`;
    return this.panel("Scene / Audio",`${this.field("Battleback nativo",`<select class="bss-select" data-bind="environment.battleback"><option value="">Contextual del mapa</option>${groups.map(g=>`<option value="${E(g.key)}" ${S(env.battleback)===S(g.key)?"selected":""}>${E(g.label||g.key)}</option>`).join("")}</select><span class="bss-note">Usa el grupo _bg / _base0 / _base1 / _message de Essentials.</span>`)}${this.field("Background gráfico libre",`${assetRow(env.backgroundGraphic,"environment.backgroundGraphic","graphic","Ningún override")}<span class="bss-note">Busca en cualquier carpeta de Graphics sin escribir rutas a mano.</span>`)}${this.field("BGM del combate",`${assetRow(env.bgm,"environment.bgm","audio","BGM por defecto")}<span class="bss-note">Vacío = música normal del mapa/trainer.</span>`)}${this.field("Tema de victoria",`${assetRow(env.victoryBgm,"environment.victoryBgm","audio","Victoria por defecto")}<span class="bss-note">Solo este combate guionizado.</span>`)}${this.field("Tema de derrota",`${assetRow(env.defeatBgm,"environment.defeatBgm","audio","Derrota por defecto")}<span class="bss-note">Suena al perder/empatar este combate, antes de los mensajes de derrota.</span>`)}<details open class="bss-optiongroup"><summary>Fondo EBDX</summary>${this.field("Escenario EBDX",`<select class="bss-select" data-bind="environment.ebdxBackdrop">${this.ebdxBackdropChoices(true).map(x=>`<option value="${E(x.id)}" ${S(env.ebdxBackdrop||"inherit")===x.id?"selected":""}>${E(x.label)}</option>`).join("")}</select><span class="bss-note">Auto resuelve terreno/ambiente de forma similar al esquema de EBDX.</span>`)}${this.field("Elementos EBDX",`<div class="bss-mini-grid">${["sky","clouds","trees","grass","water","lights","decor","particles"].map(k=>`<label class="bss-mini-field"><span>${E({sky:"Cielo",clouds:"Nubes",trees:"Árboles",grass:"Hierba",water:"Agua",lights:"Luces",decor:"Decoración",particles:"Partículas"}[k])}</span><select class="bss-select" data-bind="environment.ebdxElements.${k}"><option value="inherit" ${S((env.ebdxElements||{})[k]||"inherit")==="inherit"?"selected":""}>Global</option><option value="on" ${S((env.ebdxElements||{})[k])==="on"?"selected":""}>On</option><option value="off" ${S((env.ebdxElements||{})[k])==="off"?"selected":""}>Off</option></select></label>`).join("")}</div><span class="bss-note">Controla las familias del compositor EBDX real: no son un battleback plano.</span>`)}</details><details open class="bss-optiongroup"><summary>Bases de battleback</summary><div class="bss-global-inline-status"><span>Global: <b>${globalBases?"activadas":"desactivadas"}</b></span><button class="bss-btn small" type="button" data-act="open-global-settings">Abrir ajustes globales</button></div>${this.field("Este blueprint",`<select class="bss-select" data-bind="environment.basesMode"><option value="inherit" ${basesMode==="inherit"?"selected":""}>Usar ajuste global</option><option value="on" ${basesMode==="on"?"selected":""}>Forzar bases</option><option value="off" ${basesMode==="off"?"selected":""}>Ocultar bases</option></select><span class="bss-note">El ajuste global ya no se edita mezclado con este combate.</span>`)}</details>`);
  }
  bossHTML(b){
    const c=b.boss||{},foes=A(b.teams&&b.teams.foes),stats=c.stats||{},statRows=[["ATTACK","Ataque"],["DEFENSE","Defensa"],["SPECIAL_ATTACK","Ataque Especial"],["SPECIAL_DEFENSE","Defensa Especial"],["SPEED","Velocidad"],["ACCURACY","Precisión"],["EVASION","Evasión"]];
    const foeIndex=Math.max(0,Math.min(Math.max(0,foes.length-1),N(c.foeIndex,0)));
    const autoAuraText=b.setup&&b.setup.kind==="trainer"?"¡El {1} rival está rodeado por un aura!":"¡El {1} salvaje está rodeado por un aura!";
    return this.panel("Boss / Totem",`<div class="bss-bossbanner"><b>${E(this.battleTypeLabel(b))}</b><div class="bss-note">Aquí defines qué Pokémon es el Boss y sus boosts. Aura y SOS son secciones independientes del Blueprint.</div></div><div class="bss-aura-studio-launch bss-aura-studio-prominent"><button class="bss-btn primary" data-section="aura">✦ Aura</button><button class="bss-btn" data-section="sos">SOS</button><button class="bss-btn" data-act="open-aura-studio">Abrir Aura Studio</button></div><label class="bss-check"><input type="checkbox" data-bind="boss.enabled" ${c.enabled?"checked":""}> Activar Boss / Totem en este combate</label>${this.field("Pokémon Boss",`<select class="bss-select" data-bind="boss.foeIndex">${foes.map((p,i)=>`<option value="${i}" ${foeIndex===i?"selected":""}>Slot ${i+1} · ${E(p.species||"Pokémon")} · Lv.${N(p.level,50)}</option>`).join("")}</select><span class="bss-note">Este Battler es el centro de la invocación y del mensaje {1}.</span>`)}${this.field("Etiqueta",`<input class="bss-input" data-bind="boss.title" value="${E(c.title||"Totem")}" placeholder="Totem / Dominante">`)}<details open class="bss-optiongroup"><summary>Mensajes del Totem</summary>${this.field("Mensaje de entrada",`<input class="bss-input" data-bind="boss.encounterMessage" value="${E(c.encounterMessage||"")}" placeholder="¡El Pokémon dominante {1} te ataca!"><span class="bss-note">{1} = nombre del Pokémon.</span>`)}${this.field("Mensaje del aura",`<input class="bss-input" data-bind="boss.auraMessage" value="${E(c.auraMessage||"")}" placeholder="${E(autoAuraText)}"><span class="bss-note">{1} = nombre del Pokémon. “dominante”, “rival”, etc. lo escribes tú.</span>`)}</details><details class="bss-optiongroup"><summary>Boosts del Boss</summary><p class="bss-note">Etapas de -6 a +6. Si hay boosts y el Blueprint tiene Aura activa, se ejecuta su perfil.</p><div class="bss-boss-stats">${statRows.map(([id,label])=>`<label class="bss-boss-stat"><span>${E(label)}</span><input class="bss-input" type="number" min="-6" max="6" data-bind="boss.stats.${id}" value="${N(stats[id],0)}"></label>`).join("")}</div></details>`);
  }
  auraPreviewHTML(a,extraClass=""){
    a=a&&typeof a==="object"?a:{};const count=Math.max(4,Math.min(24,N(a.particleCount,12))),color=/^#[0-9A-Fa-f]{6}$/.test(S(a.color))?S(a.color):"#DD445B",outline=/^#[0-9A-Fa-f]{6}$/.test(S(a.outlineColor))?S(a.outlineColor):color,parallel=A(a.parallelLayers).filter(x=>x&&x.enabled!==false).slice(0,8);
    const attrs={auraParticleCount:N(a.particleCount,12),auraPattern:S(a.pattern||"rise"),auraRiseSpeed:N(a.riseSpeed,135),auraCycleFrames:N(a.cycleFrames,30),auraRiseHeight:N(a.riseHeight,100),auraSpreadX:N(a.spreadX,100),auraSpreadY:N(a.spreadY,80),auraLaneWidth:N(a.laneWidth,100),auraSwayAmount:N(a.swayAmount,100),auraOffsetX:N(a.offsetX,0),auraOffsetY:N(a.offsetY,0),auraParticleScale:N(a.particleScale,100),auraStretchStart:N(a.stretchStart,62),auraStretchEnd:N(a.stretchEnd,132),auraOpacity:N(a.opacity,100),auraOpacityStart:N(a.opacityStart,0),auraOpacityMid:N(a.opacityMid,100),auraOpacityEnd:N(a.opacityEnd,0),auraSpawnMode:S(a.spawnMode||"async"),auraAsyncAmount:N(a.asyncAmount,100),auraGraphicMode:S(a.graphicMode||"sequence"),auraParticleGraphic:S(a.particleGraphic||""),auraParticleGraphics:A(a.particleGraphics).map(S).filter(Boolean).join("|"),auraGraphicFrameFrames:N(a.graphicFrameFrames,6),auraGraphicTransitionFrames:N(a.graphicTransitionFrames,2),auraDepthMode:S(a.depthMode||"alternate"),auraBlendMode:S(a.blendMode||"normal"),auraOutlineEnabled:a.outlineEnabled===false?"0":"1",auraOutlineOpacity:N(a.outlineOpacity,46),auraOutlineSize:N(a.outlineSize,2),auraOutlineEffect:S(a.outlineEffect||"standard"),auraOutlineCopies:N(a.outlineCopies,6),auraOutlineCopySpacing:N(a.outlineCopySpacing,100),auraRoaringStrength:N(a.roaringStrength,100),auraRoaringSpeed:N(a.roaringSpeed,100),auraPulseStrength:N(a.pulseStrength,100),auraPulseSpeed:N(a.pulseSpeed,100),auraParallelLayers:encodeURIComponent(JSON.stringify(parallel))};
    const data=Object.entries(attrs).map(([k,v])=>` data-${S(k).replace(/[A-Z]/g,m=>"-"+S(m).toLowerCase())}="${E(v)}"`).join("");
    const particles=Array.from({length:count},(_,i)=>{const main=`<img class="bss-aura-runtime-particle" data-aura-particle="${i}" data-aura-slot="a" alt=""><img class="bss-aura-runtime-particle" data-aura-particle-b="${i}" data-aura-slot="b" alt="">`;const extra=parallel.map((_,li)=>`<img class="bss-aura-runtime-particle bss-aura-parallel-particle" data-aura-parallel-particle="${li}:${i}" data-aura-slot="a" alt=""><img class="bss-aura-runtime-particle bss-aura-parallel-particle" data-aura-parallel-particle-b="${li}:${i}" data-aura-slot="b" alt="">`).join("");return main+extra;}).join("");
    return `<div class="bss-aura-live-preview ${E(extraClass)}" data-aura-preview${data} style="--aura:${E(color)};--outline:${E(outline)};--outline-opacity:${Math.max(0,Math.min(100,N(a.outlineOpacity,46)))/100}"><div class="bss-aura-demo-mon"><div class="bss-aura-outline-stack" data-aura-outline-stack></div><span data-aura-test-battler>${E(this.auraTestSpecies||"PIKACHU")}</span></div>${particles}</div>`;
  }
  auraSectionHTML(b,nested=false){
    const profiles=this.auraProfiles(),pid=S(b&&b.boss&&b.boss.aura&&b.boss.aura.profileId||"ebdx_default"),p=profiles.find(x=>S(x&&x.id)===pid)||profiles[0]||{id:"ebdx_default",name:"EBDX Default",aura:{}},a=p.aura||{};
    const body=`<div class="bss-aura-section-head"><div><b>${E(p.name||"EBDX Default")}</b><small>El blueprint solo elige el perfil y si se usa. La edición visual vive en Aura Studio.</small></div><button class="bss-btn primary" data-act="open-aura-studio" data-aura-open-profile="${E(p.id)}">✦ Aura Studio</button></div><div class="bss-aura-blueprint-preview-card"><div class="bss-aura-blueprint-preview-head"><div><b>Preview del aura seleccionada</b><small>Usa el Battler real del dominante de este blueprint y el perfil activo.</small></div><span>${E(p.name||p.id)}</span></div>${this.auraPreviewHTML(a,"bss-aura-inline-preview")}</div><div class="bss-aura-profile-summary">${profiles.map(x=>`<button class="bss-aura-profile ${S(x.id)===S(p.id)?"active":""}" data-apply-aura-profile="${E(x.id)}"><b>${E(x.name||x.id)}</b><small>${x.builtin?"Preset base":"Custom"}</small></button>`).join("")}</div>`;
    return nested?body:this.panel("Aura",body);
  }
  auraProfiles(){
    this.studio.global=this.studio.global||{};
    let rows=A(this.studio.global.auraProfiles);
    if(!rows.length){rows=[{id:"ebdx_default",name:"EBDX Default",builtin:true,aura:{enabled:true,introEnabled:true,profileId:"ebdx_default",color:"#DD445B",outlineEnabled:true,outlineColor:"#DD445B",outlineOpacity:46,outlineSize:2,particleCount:12,riseSpeed:135,cycleFrames:30,riseHeight:100,spreadX:100,spreadY:80,laneWidth:100,swayAmount:100,offsetX:0,offsetY:0,particleScale:100,stretchStart:62,stretchEnd:132,opacity:100,opacityStart:0,opacityMid:100,opacityEnd:0,spawnMode:"async",asyncAmount:100,graphicMode:"sequence",particleGraphic:"Graphics/BattleSceneStudio/Auras/TotemCharged001.png",particleGraphics:["Graphics/BattleSceneStudio/Auras/TotemCharged001.png","Graphics/BattleSceneStudio/Auras/TotemCharged002.png","Graphics/BattleSceneStudio/Auras/TotemCharged003.png","Graphics/BattleSceneStudio/Auras/TotemCharged004.png"],graphicFrameFrames:6,depthMode:"alternate",blendMode:"normal",introDuration:104,impactHold:56,fadeOutFrames:18,introSpotlight:true,introReturnFrames:24,basZoomEnabled:true,basZoom:150,basZoomBounds:"screen"}}];this.studio.global.auraProfiles=rows;}
    return rows;
  }
  currentAuraProfile(){return this.auraProfiles().find(x=>S(x&&x.id)===S(this.auraStudioProfile))||this.auraProfiles()[0]||null;}
  auraTestPokemon(){
    const rec=findSpecies(this.source,this.auraTestSpecies,this.auraTestForm)||A(this.source.species)[0]||null;
    if(rec){this.auraTestSpecies=U(rec.species);this.auraTestForm=N(rec.form);}
    return rec;
  }
  auraDefaultGraphics(){return [1,2,3,4].map(i=>`Graphics/BattleSceneStudio/Auras/TotemCharged00${i}.png`);}
  auraGraphicPaths(a){
    a=a&&typeof a==="object"?a:{};const fallback=this.auraDefaultGraphics(),mode=S(a.graphicMode||"sequence")==="single"?"single":"sequence";
    if(mode==="single")return [S(a.particleGraphic||fallback[0]).trim()||fallback[0]];
    const rows=A(a.particleGraphics).map(x=>S(x).trim()).filter(Boolean).slice(0,12);return rows.length?rows:fallback;
  }
  auraGraphicOptions(current=""){
    const rows=A(this.source&&this.source.auraGraphics),seen=new Set(),all=[];for(const x of rows){const path=S(x&&x.projectPath).trim();if(!path||seen.has(path))continue;seen.add(path);all.push({path,label:S(x&&x.relativePath||x&&x.name||path)});}for(const path of this.auraDefaultGraphics()){if(!seen.has(path)){seen.add(path);all.push({path,label:path.replace(/^Graphics\/BattleSceneStudio\/Auras\//i,"")});}}current=S(current).trim();if(current&&!seen.has(current))all.unshift({path:current,label:current});return all.map(x=>`<option value="${E(x.path)}" ${x.path===current?"selected":""}>${E(x.label)}</option>`).join("");
  }
  auraSequenceEditorHTML(a,targetPrefix="main"){
    const seq=this.auraGraphicPaths(Object.assign({},a,{graphicMode:"sequence"}));return `<div class="bss-aura-sequence-editor"><div class="bss-aura-sequence-head"><div><b>Secuencia de gráficos</b><small>Una vida de partícula: 1 → 2 → 3 → 4 → se desvanece. No vuelve al 1 hasta que nace otra partícula.</small></div><button class="bss-btn small" type="button" data-act="${targetPrefix==="main"?"aura-sequence-add":"aura-parallel-sequence-add"}" ${targetPrefix==="main"?"":`data-aura-layer-index="${E(targetPrefix)}"`}>＋ Añadir</button></div>${seq.map((path,i)=>`<div class="bss-aura-sequence-row"><span>${i+1}</span><select class="bss-select" ${targetPrefix==="main"?`data-aura-sequence-index="${i}"`:`data-aura-parallel-sequence="${E(targetPrefix)}:${i}"`}>${this.auraGraphicOptions(path)}</select><button class="bss-btn small" type="button" data-asset-browse="${targetPrefix==="main"?`aura:sequence:${i}`:`aura:parallelseq:${targetPrefix}:${i}`}" data-asset-kind="graphic">Explorar…</button>${targetPrefix==="main"?`<button class="bss-btn small" type="button" data-act="aura-sequence-up" data-aura-seq-index="${i}" ${i===0?"disabled":""}>↑</button><button class="bss-btn small" type="button" data-act="aura-sequence-down" data-aura-seq-index="${i}" ${i===seq.length-1?"disabled":""}>↓</button><button class="bss-btn small danger" type="button" data-act="aura-sequence-remove" data-aura-seq-index="${i}" ${seq.length<=1?"disabled":""}>×</button>`:`<button class="bss-btn small danger" type="button" data-act="aura-parallel-sequence-remove" data-aura-layer-index="${E(targetPrefix)}" data-aura-seq-index="${i}" ${seq.length<=1?"disabled":""}>×</button>`}</div>`).join("")}</div>`;
  }
  syncAuraProfileBlueprints(p){
    if(!p)return;A(this.studio.blueprints).forEach(b=>{if(!b||!b.boss||!b.boss.aura||S(b.boss.aura.profileId)!==S(p.id))return;const enabled=b.boss.aura.enabled!==false;b.boss.aura=Object.assign({},JSON.parse(JSON.stringify(p.aura||{})),{profileId:S(p.id),enabled});});
  }
  auraParallelLayerHTML(layer,li){
    layer=layer&&typeof layer==="object"?layer:{};const mode=S(layer.graphicMode||"single")==="sequence"?"sequence":"single",single=S(layer.particleGraphic||this.auraDefaultGraphics()[0]),spawn=S(layer.spawnMode||"async")==="simultaneous"?"simultaneous":"async";
    const graphicUI=mode==="single"?this.field("Gráfico",`<div class="bss-asset-field"><select class="bss-select" data-aura-parallel-field="${li}:particleGraphic">${this.auraGraphicOptions(single)}</select><button class="bss-btn small" type="button" data-asset-browse="aura:parallel:${li}:particleGraphic" data-asset-kind="graphic">Buscar…</button></div>`):`<div class="bss-aura-settings-wide">${this.auraSequenceEditorHTML(layer,S(li))}</div>`;
    return `<div class="bss-aura-layer-editor"><div class="bss-aura-layer-head"><div><b>${E(layer.name||`Capa paralela ${li+1}`)}</b><small>Ritmo, movimiento y secuencia independientes de la partícula principal.</small></div><label class="bss-check compact"><input type="checkbox" data-aura-parallel-field="${li}:enabled" ${layer.enabled!==false?"checked":""}> Activa</label><button class="bss-btn small danger" type="button" data-act="aura-parallel-remove" data-aura-layer-index="${li}">Eliminar</button></div><div class="bss-aura-settings-grid">${this.field("Nombre",`<input class="bss-input" data-aura-parallel-field="${li}:name" value="${E(layer.name||`Capa paralela ${li+1}`)}">`)}${this.field("Modo gráfico",`<select class="bss-select" data-aura-parallel-field="${li}:graphicMode"><option value="single" ${mode==="single"?"selected":""}>Un gráfico</option><option value="sequence" ${mode==="sequence"?"selected":""}>Secuencia one-shot</option></select>`)}${graphicUI}${this.field("Tiempo por gráfico",`<input class="bss-input" type="number" min="1" max="60" data-aura-parallel-field="${li}:graphicFrameFrames" value="${N(layer.graphicFrameFrames,6)}"><span class="bss-note">Cuánto permanece cada frame/gráfico.</span>`)}${this.field("Transición",`<input class="bss-input" type="number" min="0" max="30" data-aura-parallel-field="${li}:graphicTransitionFrames" value="${N(layer.graphicTransitionFrames,2)}"><span class="bss-note">0 = corte; mayor = crossfade más lento.</span>`)}${this.field("Nacimiento",`<select class="bss-select" data-aura-parallel-field="${li}:spawnMode"><option value="async" ${spawn==="async"?"selected":""}>Desfasadas</option><option value="simultaneous" ${spawn==="simultaneous"?"selected":""}>Simultáneas</option></select>`)}${this.field("Cantidad de partículas",`<input class="bss-input" type="number" min="4" max="24" data-aura-parallel-field="${li}:particleCount" value="${N(layer.particleCount,12)}"><span class="bss-note">Independiente de la cantidad de la capa principal.</span>`)}${this.field("Asincronía (%)",`<input class="bss-input" type="number" min="0" max="500" data-aura-parallel-field="${li}:asyncAmount" value="${N(layer.asyncAmount,100)}" ${spawn==="simultaneous"?"disabled":""}><span class="bss-note">Controla cuánto se separan entre sí las partículas de esta capa.</span>`)}${this.field("Desfase de capa (%)",`<input class="bss-input" type="number" min="0" max="100" data-aura-parallel-field="${li}:phaseOffset" value="${N(layer.phaseOffset,(li+1)*23%100)}"><span class="bss-note">Desplaza todo el ritmo para que capas asíncronas no nazcan a la vez.</span>`)}${this.field("Duración de vida",`<input class="bss-input" type="number" min="10" max="120" data-aura-parallel-field="${li}:cycleFrames" value="${N(layer.cycleFrames,30)}">`)}${this.field("Velocidad de subida (%)",`<input class="bss-input" type="number" min="10" max="400" data-aura-parallel-field="${li}:riseSpeed" value="${N(layer.riseSpeed,135)}">`)}${this.field("Altura de ascenso (%)",`<input class="bss-input" type="number" min="20" max="300" data-aura-parallel-field="${li}:riseHeight" value="${N(layer.riseHeight,100)}">`)}${this.field("Dispersión X (%)",`<input class="bss-input" type="number" min="25" max="200" data-aura-parallel-field="${li}:spreadX" value="${N(layer.spreadX,100)}">`)}${this.field("Dispersión Y (%)",`<input class="bss-input" type="number" min="25" max="180" data-aura-parallel-field="${li}:spreadY" value="${N(layer.spreadY,80)}">`)}${this.field("Ancho de carriles (%)",`<input class="bss-input" type="number" min="25" max="200" data-aura-parallel-field="${li}:laneWidth" value="${N(layer.laneWidth,100)}">`)}${this.field("Ondulación (%)",`<input class="bss-input" type="number" min="0" max="300" data-aura-parallel-field="${li}:swayAmount" value="${N(layer.swayAmount,100)}">`)}${this.field("Escala (%)",`<input class="bss-input" type="number" min="10" max="300" data-aura-parallel-field="${li}:scale" value="${N(layer.scale,100)}">`)}${this.field("Estirar al nacer (%)",`<input class="bss-input" type="number" min="10" max="250" data-aura-parallel-field="${li}:stretchStart" value="${N(layer.stretchStart,62)}">`)}${this.field("Estirar al final (%)",`<input class="bss-input" type="number" min="10" max="300" data-aura-parallel-field="${li}:stretchEnd" value="${N(layer.stretchEnd,132)}">`)}${this.field("Opacidad general (%)",`<input class="bss-input" type="number" min="0" max="100" data-aura-parallel-field="${li}:opacity" value="${N(layer.opacity,100)}">`)}${this.field("Opacidad inicial (%)",`<input class="bss-input" type="number" min="0" max="100" data-aura-parallel-field="${li}:opacityStart" value="${N(layer.opacityStart,0)}">`)}${this.field("Opacidad media (%)",`<input class="bss-input" type="number" min="0" max="100" data-aura-parallel-field="${li}:opacityMid" value="${N(layer.opacityMid,100)}">`)}${this.field("Opacidad final (%)",`<input class="bss-input" type="number" min="0" max="100" data-aura-parallel-field="${li}:opacityEnd" value="${N(layer.opacityEnd,0)}">`)}${this.field("Offset X (%)",`<input class="bss-input" type="number" min="-100" max="100" data-aura-parallel-field="${li}:offsetX" value="${N(layer.offsetX,0)}">`)}${this.field("Offset Y (%)",`<input class="bss-input" type="number" min="-100" max="100" data-aura-parallel-field="${li}:offsetY" value="${N(layer.offsetY,0)}">`)}${this.field("Profundidad",`<select class="bss-select" data-aura-parallel-field="${li}:depthMode"><option value="alternate" ${S(layer.depthMode||"alternate")==="alternate"?"selected":""}>Delante/detrás</option><option value="front" ${S(layer.depthMode)==="front"?"selected":""}>Delante</option><option value="back" ${S(layer.depthMode)==="back"?"selected":""}>Detrás</option></select>`)}${this.field("Blend",`<select class="bss-select" data-aura-parallel-field="${li}:blendMode"><option value="normal" ${S(layer.blendMode)==="normal"?"selected":""}>Normal</option><option value="additive" ${S(layer.blendMode||"additive")==="additive"?"selected":""}>Aditivo</option></select>`)}</div></div>`;
  }

  auraSettingsHTML(p){
    const a=p.aura||{},tab=S(this.auraStudioTab||"appearance"),bounds=["screen","extended"].includes(S(a.basZoomBounds))?S(a.basZoomBounds):"screen";
    if(tab==="particles"){
      const mode=S(a.graphicMode||"sequence")==="single"?"single":"sequence",single=S(a.particleGraphic||this.auraDefaultGraphics()[0]),layers=A(a.parallelLayers).slice(0,3),active=S(this.auraParticleLayer||"main");
      const layerTabs=`<div class="bss-aura-layer-tabs"><button class="bss-aura-layer-tab ${active==="main"?"active":""}" data-aura-layer-tab="main">Principal</button>${layers.map((x,i)=>`<button class="bss-aura-layer-tab ${active===S(i)?"active":""}" data-aura-layer-tab="${i}">${E(x.name||`Capa ${i+1}`)}</button>`).join("")}<button class="bss-aura-layer-tab add" data-act="aura-parallel-add" ${layers.length>=3?"disabled":""}>＋ Capa</button></div>`;
      if(active!=="main"&&layers[N(active,-1)])return `${layerTabs}<div class="bss-aura-explain"><b>Capa paralela ${N(active)+1}</b><span>Esta capa tiene su propio ritmo, asincronía, desplazamiento, secuencia y movimiento. El “Desfase de capa” evita que dos capas asíncronas arranquen juntas.</span></div>${this.auraParallelLayerHTML(layers[N(active)],N(active))}`;
      const graphicUI=mode==="single"?this.field("Gráfico principal",`<div class="bss-asset-field"><select class="bss-select" data-aura-profile-field="particleGraphic">${this.auraGraphicOptions(single)}</select><button class="bss-btn small" type="button" data-asset-browse="aura:particleGraphic" data-asset-kind="graphic">Buscar…</button></div><span class="bss-note">Permanece durante toda la vida de la partícula.</span>`):`<div class="bss-aura-settings-wide">${this.auraSequenceEditorHTML(a)}</div>`;
      return `${layerTabs}<div class="bss-aura-explain"><b>Partícula principal</b><span>Secuencia = 1 → 2 → 3 → último gráfico → fade. No vuelve al gráfico 1 hasta que esa partícula nace otra vez.</span></div><div class="bss-aura-settings-grid">${this.field("Modo gráfico",`<select class="bss-select" data-aura-profile-field="graphicMode"><option value="single" ${mode==="single"?"selected":""}>Un solo gráfico</option><option value="sequence" ${mode==="sequence"?"selected":""}>Secuencia one-shot</option></select>`)}${this.field("Tiempo por gráfico",`<input class="bss-input" type="number" min="1" max="60" data-aura-profile-field="graphicFrameFrames" value="${N(a.graphicFrameFrames,6)}"><span class="bss-note">Duración visible antes de avanzar.</span>`)}${this.field("Velocidad de transición",`<input class="bss-input" type="number" min="0" max="30" data-aura-profile-field="graphicTransitionFrames" value="${N(a.graphicTransitionFrames,2)}"><span class="bss-note">0 = corte; más frames = transición más lenta.</span>`)}${graphicUI}${this.field("Cantidad de partículas",`<input class="bss-input" type="number" min="4" max="24" data-aura-profile-field="particleCount" value="${N(a.particleCount,12)}">`)}${this.field("Nacimiento",`<select class="bss-select" data-aura-profile-field="spawnMode"><option value="async" ${S(a.spawnMode||"async")==="async"?"selected":""}>Desfasadas</option><option value="simultaneous" ${S(a.spawnMode)==="simultaneous"?"selected":""}>Todas a la vez</option></select>`)}${this.field("Asincronía (%)",`<input class="bss-input" type="number" min="0" max="500" data-aura-profile-field="asyncAmount" value="${N(a.asyncAmount,100)}" ${S(a.spawnMode)==="simultaneous"?"disabled":""}><span class="bss-note">0 = juntas · 100 = separación base · 300 = muy separadas.</span>`)}${this.field("Velocidad de subida (%)",`<input class="bss-input" type="number" min="10" max="400" data-aura-profile-field="riseSpeed" value="${N(a.riseSpeed,135)}">`)}${this.field("Dispersión horizontal (%)",`<input class="bss-input" type="number" min="25" max="200" data-aura-profile-field="spreadX" value="${N(a.spreadX,100)}">`)}${this.field("Dispersión vertical (%)",`<input class="bss-input" type="number" min="25" max="180" data-aura-profile-field="spreadY" value="${N(a.spreadY,80)}">`)}${this.field("Tamaño de partícula (%)",`<input class="bss-input" type="number" min="25" max="250" data-aura-profile-field="particleScale" value="${N(a.particleScale,100)}">`)}</div>`;
    }
    if(tab==="motion")return `<div class="bss-aura-explain"><b>Movimiento</b><span>El patrón cambia la geometría del aura, no solo sus números. Órbita, Vórtice, Lluvia, Burst, Halo y Suelo son familias separadas del ascenso EBDX.</span></div><div class="bss-aura-settings-grid">${this.field("Patrón",`<select class="bss-select" data-aura-profile-field="pattern"><option value="rise" ${S(a.pattern||"rise")==="rise"?"selected":""}>Ascenso EBDX</option><option value="orbit" ${S(a.pattern)==="orbit"?"selected":""}>Órbita</option><option value="vortex" ${S(a.pattern)==="vortex"?"selected":""}>Vórtice</option><option value="rain" ${S(a.pattern)==="rain"?"selected":""}>Lluvia descendente</option><option value="burst" ${S(a.pattern)==="burst"?"selected":""}>Explosión radial</option><option value="halo" ${S(a.pattern)==="halo"?"selected":""}>Halo</option><option value="ground" ${S(a.pattern)==="ground"?"selected":""}>Anillo de suelo</option></select>`)}${this.field("Duración de vida",`<input class="bss-input" type="number" min="10" max="120" data-aura-profile-field="cycleFrames" value="${N(a.cycleFrames,30)}">`)}${this.field("Altura de ascenso (%)",`<input class="bss-input" type="number" min="20" max="300" data-aura-profile-field="riseHeight" value="${N(a.riseHeight,100)}">`)}${this.field("Ancho de carriles (%)",`<input class="bss-input" type="number" min="25" max="200" data-aura-profile-field="laneWidth" value="${N(a.laneWidth,100)}">`)}${this.field("Ondulación lateral (%)",`<input class="bss-input" type="number" min="0" max="300" data-aura-profile-field="swayAmount" value="${N(a.swayAmount,100)}">`)}${this.field("Offset X (%)",`<input class="bss-input" type="number" min="-100" max="100" data-aura-profile-field="offsetX" value="${N(a.offsetX,0)}">`)}${this.field("Offset Y (%)",`<input class="bss-input" type="number" min="-100" max="100" data-aura-profile-field="offsetY" value="${N(a.offsetY,0)}">`)}${this.field("Estiramiento al nacer (%)",`<input class="bss-input" type="number" min="10" max="250" data-aura-profile-field="stretchStart" value="${N(a.stretchStart,62)}">`)}${this.field("Estiramiento al final (%)",`<input class="bss-input" type="number" min="10" max="300" data-aura-profile-field="stretchEnd" value="${N(a.stretchEnd,132)}">`)}${this.field("Profundidad",`<select class="bss-select" data-aura-profile-field="depthMode"><option value="alternate" ${S(a.depthMode||"alternate")==="alternate"?"selected":""}>Mezclar delante/detrás</option><option value="front" ${S(a.depthMode)==="front"?"selected":""}>Solo delante</option><option value="back" ${S(a.depthMode)==="back"?"selected":""}>Solo detrás</option></select>`)}</div>`;
    if(tab==="outline")return `<div class="bss-aura-explain"><b>Contorno</b><span>Roaring Knight genera copias de arrastre direccional como el efecto de referencia. Pulse genera copias que se expanden desde el Battler con ritmo de latido.</span></div><div class="bss-aura-settings-grid"><label class="bss-check"><input type="checkbox" data-aura-profile-field="outlineEnabled" ${a.outlineEnabled!==false?"checked":""}> Mostrar contorno</label>${this.field("Color",`<input type="color" data-aura-profile-field="outlineColor" value="${E(a.outlineColor||a.color||"#DD445B")}">`)}${this.field("Opacidad (%)",`<input class="bss-input" type="number" min="0" max="100" data-aura-profile-field="outlineOpacity" value="${N(a.outlineOpacity,46)}">`)}${this.field("Grosor base (px)",`<input class="bss-input" type="number" min="1" max="8" data-aura-profile-field="outlineSize" value="${N(a.outlineSize,2)}">`)}${this.field("Efecto",`<select class="bss-select" data-aura-profile-field="outlineEffect"><option value="standard" ${S(a.outlineEffect||"standard")==="standard"?"selected":""}>Standard</option><option value="roaring_knight" ${S(a.outlineEffect)==="roaring_knight"?"selected":""}>Roaring Knight</option><option value="pulse" ${S(a.outlineEffect)==="pulse"?"selected":""}>Pulse / latido</option></select>`)}${this.field("Copias del contorno",`<input class="bss-input" type="number" min="1" max="12" data-aura-profile-field="outlineCopies" value="${N(a.outlineCopies,6)}"><span class="bss-note">Roaring: estela. Pulse: anillos/siluetas expansivas.</span>`)}${this.field("Separación de copias (%)",`<input class="bss-input" type="number" min="25" max="300" data-aura-profile-field="outlineCopySpacing" value="${N(a.outlineCopySpacing,100)}">`)}${this.field("Fuerza Roaring (%)",`<input class="bss-input" type="number" min="0" max="250" data-aura-profile-field="roaringStrength" value="${N(a.roaringStrength,100)}">`)}${this.field("Velocidad Roaring (%)",`<input class="bss-input" type="number" min="10" max="300" data-aura-profile-field="roaringSpeed" value="${N(a.roaringSpeed,100)}">`)}${this.field("Fuerza Pulse (%)",`<input class="bss-input" type="number" min="0" max="250" data-aura-profile-field="pulseStrength" value="${N(a.pulseStrength,100)}">`)}${this.field("Velocidad Pulse (%)",`<input class="bss-input" type="number" min="10" max="300" data-aura-profile-field="pulseSpeed" value="${N(a.pulseSpeed,100)}">`)}</div>`;
    if(tab==="intro")return `<div class="bss-aura-explain"><b>Invocación</b><span>Durante esta secuencia BSS bloquea el Turbo y fuerza x1. Al terminar restaura la velocidad y permiso que tenía el jugador.</span></div><div class="bss-aura-settings-grid"><label class="bss-check"><input type="checkbox" data-aura-profile-field="introEnabled" ${a.introEnabled!==false?"checked":""}> Reproducir secuencia de carga</label><label class="bss-check"><input type="checkbox" data-aura-profile-field="introSpotlight" ${a.introSpotlight!==false?"checked":""}> Ocultar temporalmente aliados y otros Battlers</label>${this.field("Duración de carga",`<input class="bss-input" type="number" min="48" max="180" data-aura-profile-field="introDuration" value="${N(a.introDuration,104)}">`)}${this.field("Pausa tras impacto",`<input class="bss-input" type="number" min="0" max="120" data-aura-profile-field="impactHold" value="${N(a.impactHold,56)}">`)}${this.field("Reaparición de los demás",`<input class="bss-input" type="number" min="8" max="60" data-aura-profile-field="introReturnFrames" value="${N(a.introReturnFrames,24)}">`)}${this.field("Fade al debilitarse",`<input class="bss-input" type="number" min="1" max="90" data-aura-profile-field="fadeOutFrames" value="${N(a.fadeOutFrames,18)}">`)}</div>`;
    if(tab==="camera")return `<div class="bss-aura-explain"><b>Cámara BAS + EBDX</b><span>En EBDX puedes tratar todo el room como una escena y llevar al Dominante al centro real de pantalla durante Aura Charge. El fondo, battler, sombra y aura reciben el mismo contexto.</span></div><div class="bss-aura-settings-grid"><label class="bss-check"><input type="checkbox" data-aura-profile-field="basZoomEnabled" ${a.basZoomEnabled!==false?"checked":""}> Usar cámara BAS durante la carga</label><label class="bss-check"><input type="checkbox" data-aura-profile-field="ebdxCenterMon" ${a.ebdxCenterMon===true?"checked":""}> Ver mon al centro (EBDX)</label>${this.field("Zoom (%)",`<input class="bss-input" type="number" min="100" max="220" data-aura-profile-field="basZoom" value="${N(a.basZoom,150)}">`)}${this.field("Límites Vanilla",`<select class="bss-select" data-aura-profile-field="basZoomBounds"><option value="screen" ${bounds==="screen"?"selected":""}>Respetar BG</option><option value="extended" ${bounds==="extended"?"selected":""}>Extendido</option></select><span class="bss-note">Con “Mon al centro (EBDX)” se usa room extendido automáticamente.</span>`)}${this.field("Centro EBDX · offset X",`<input class="bss-input" type="number" min="-320" max="320" data-aura-profile-field="ebdxCenterOffsetX" value="${N(a.ebdxCenterOffsetX,0)}">`)}${this.field("Centro EBDX · offset Y",`<input class="bss-input" type="number" min="-240" max="240" data-aura-profile-field="ebdxCenterOffsetY" value="${N(a.ebdxCenterOffsetY,0)}">`)}</div>`;
    return `<div class="bss-aura-explain"><b>Apariencia general</b><span>La curva inicial/media/final controla cómo entra y desaparece cada partícula sin alterar la secuencia gráfica.</span></div><div class="bss-aura-settings-grid">${this.field("Nombre",`<input class="bss-input" data-aura-profile-name value="${E(p.name)}" ${p.builtin?"disabled":""}>`)}${this.field("Color del aura",`<input type="color" data-aura-profile-field="color" value="${E(a.color||"#DD445B")}">`)}${this.field("Opacidad general (%)",`<input class="bss-input" type="number" min="0" max="100" data-aura-profile-field="opacity" value="${N(a.opacity,100)}">`)}${this.field("Al nacer (%)",`<input class="bss-input" type="number" min="0" max="100" data-aura-profile-field="opacityStart" value="${N(a.opacityStart,0)}">`)}${this.field("A mitad de vida (%)",`<input class="bss-input" type="number" min="0" max="100" data-aura-profile-field="opacityMid" value="${N(a.opacityMid,100)}">`)}${this.field("Al terminar (%)",`<input class="bss-input" type="number" min="0" max="100" data-aura-profile-field="opacityEnd" value="${N(a.opacityEnd,0)}">`)}</div>`;
  }
  renderAuraStudio(preserveScroll=false){
    const oldControls=this.body&&this.body.querySelector(".bss-aura-tabbody"),oldProfiles=this.body&&this.body.querySelector(".bss-aura-profile-list"),controlScroll=preserveScroll&&oldControls?oldControls.scrollTop:0,profileScroll=preserveScroll&&oldProfiles?oldProfiles.scrollTop:0;
    const p=this.currentAuraProfile();if(!p){this.screen="library";return this.renderLibrary();}
    const tabs=[["appearance","Apariencia"],["particles","Partículas"],["motion","Movimiento"],["outline","Contorno"],["intro","Invocación"],["camera","Cámara BAS"]],profiles=this.auraProfiles(),rec=this.auraTestPokemon(),display=rec?`${rec.name||rec.species}${N(rec.form)?` · F${N(rec.form)}`:""}`:`${this.auraTestSpecies||"PIKACHU"}`;
    this.body.innerHTML=`<section class="bss-aura-studio-screen"><div class="bss-libhead"><button class="bss-btn" data-act="close-aura-studio">← Volver</button><div class="bss-aura-title"><b>Aura Studio</b><small>Perfiles independientes · usa pestañas y capas en vez de recorrer una lista interminable.</small></div><div class="bss-spacer"></div><button class="bss-btn" data-act="open-global-settings">⚙ Global</button><button class="bss-btn" data-act="aura-profile-new">＋ Duplicar perfil</button><button class="bss-btn danger" data-act="aura-profile-delete" ${p.builtin?"disabled":""}>Eliminar</button></div><div class="bss-aura-workspace"><aside class="bss-aura-profile-list">${profiles.map(x=>`<button class="bss-aura-profile ${S(x.id)===S(p.id)?"active":""}" data-aura-profile="${E(x.id)}"><b>${E(x.name)}</b><small>${x.builtin?"Preset base":"Custom"}</small></button>`).join("")}</aside><main class="bss-aura-main"><div class="bss-aura-preview-column"><div class="bss-aura-testbar"><div><b>Sujeto de prueba</b><small>${E(display)} · Battler real del proyecto</small></div><button class="bss-btn" data-pick-special="aura:test">Cambiar battler</button></div>${this.auraPreviewHTML(p.aura||{},"bss-aura-studio-preview")}<div class="bss-aura-preview-note"><b>Preview del perfil.</b> Partícula principal y capas paralelas usan relojes independientes. Roaring/Pulse se dibujan con copias reales del Battler.</div></div><div class="bss-aura-controls"><div class="bss-aura-tabs">${tabs.map(([id,label],i)=>`<button class="bss-aura-tab ${S(this.auraStudioTab)===id?"active":""}" data-aura-tab="${id}" title="Ctrl+${i+1}">${E(label)}</button>`).join("")}</div><div class="bss-aura-tabbody">${this.auraSettingsHTML(p)}</div><div class="bss-aura-shortcuts"><b>Navegación rápida</b><span>Ctrl+1–6 cambia de pestaña. En Partículas usa Principal / Capa 1 / Capa 2 / Capa 3 sin perder la posición de scroll.</span></div></div></main></div></section>`;
    const controls=this.body.querySelector(".bss-aura-tabbody"),profilesNode=this.body.querySelector(".bss-aura-profile-list");if(controls)controls.scrollTop=controlScroll;if(profilesNode)profilesNode.scrollTop=profileScroll;
    this.hydrateAuraTestBattler();this.hydrateAuraRuntimePreview();this.startAuraPreviewLoop();if(this.globalSettingsOpen)this.renderGlobalSettingsModal();
  }
  async hydrateAuraTestBattler(){
    const nodes=[...this.root.querySelectorAll("[data-aura-test-battler]")];if(!nodes.length)return;
    for(const el of nodes){
      if(!el||!el.isConnected)continue;
      try{
        let species=this.auraTestSpecies,form=this.auraTestForm,poke={species,form};
        if(el.closest(".bss-aura-inline-preview")){const b=this.battle(),idx=Math.max(0,N(b&&b.boss&&b.boss.foeIndex,0)),foe=A(b&&b.teams&&b.teams.foes)[idx];if(foe){species=U(foe.species)||species;form=N(foe.form,0);poke=foe;}}
        const asset=findBattlerSprite(this.source,species,"target",form)||findBattlerSprite(this.source,species,"target");
        if(!asset){if(el.tagName!=="IMG")el.textContent=species||"Battler";continue;}
        const [url,renderInfo]=await Promise.all([this.frameUrl(asset,`aura-preview:${S(asset&&asset.projectPath)}:${species}:${form}`),this.battlerRenderInfo(asset,poke||{species,form},"target").catch(()=>({}))]);
        if(!url||!el.isConnected)continue;
        const img=document.createElement("img");img.className="bss-aura-test-img";img.dataset.auraTestBattler="";img.src=url;img.alt=species||"Battler";
        if(el.parentNode)el.parentNode.replaceChild(img,el);
        const scale=Math.max(.05,N(renderInfo&&renderInfo.editorViewScale||renderInfo&&renderInfo.scale,1));img.dataset.runtimeBattlerScale=S(scale);
        const apply=()=>{if(!img.isConnected)return;const box=img.closest(".bss-aura-demo-mon"),mw=Math.max(1,(box&&box.clientWidth||300)*.96),mh=Math.max(1,(box&&box.clientHeight||260)*.96),dw=Math.max(1,(img.naturalWidth||1)*scale),dh=Math.max(1,(img.naturalHeight||1)*scale),fit=Math.min(1,mw/dw,mh/dh);img.style.width=`${Math.max(1,dw*fit)}px`;img.style.height=`${Math.max(1,dh*fit)}px`;img.dataset.previewFit=S(fit);const preview=img.closest(".bss-aura-live-preview");if(preview)this.syncAuraOutlineCopies(preview,img);};
        if(img.complete&&img.naturalWidth)apply();else img.addEventListener("load",apply,{once:true});
      }catch(err){this.persistEditorError("aura-preview-battler",err);}
    }
  }
  auraHexRGB(value){const s=/^#[0-9A-Fa-f]{6}$/.test(S(value))?S(value):"#DD445B";return [parseInt(s.slice(1,3),16),parseInt(s.slice(3,5),16),parseInt(s.slice(5,7),16)];}
  auraConfigFromPreview(preview){const d=preview&&preview.dataset||{};return {graphicMode:S(d.auraGraphicMode||"sequence"),particleGraphic:S(d.auraParticleGraphic||""),particleGraphics:S(d.auraParticleGraphics||"").split("|").map(x=>S(x).trim()).filter(Boolean),graphicFrameFrames:N(d.auraGraphicFrameFrames,6),graphicTransitionFrames:N(d.auraGraphicTransitionFrames,2)};}
  async auraBaseFrames(a){
    const paths=this.auraGraphicPaths(a),key=paths.join("\n");if(this.auraRuntimeAssetCache.has(key))return this.auraRuntimeAssetCache.get(key);const task=Promise.all(paths.map(projectPath=>this.assetUrl({projectPath}).catch(()=>null)));this.auraRuntimeAssetCache.set(key,task);return task;
  }
  async auraTintedFrames(color,a){
    color=/^#[0-9A-Fa-f]{6}$/.test(S(color))?S(color).toUpperCase():"#DD445B";const paths=this.auraGraphicPaths(a),key=`${color}|${paths.join("|")}`;if(this.auraTintCache.has(key))return this.auraTintCache.get(key);
    const task=(async()=>{const raws=await this.auraBaseFrames(a),rgb=this.auraHexRGB(color),base=[221,68,91],delta=[rgb[0]-base[0],rgb[1]-base[1],rgb[2]-base[2]];return Promise.all(raws.map(raw=>new Promise(resolve=>{if(!raw)return resolve(null);const im=new Image();im.onload=()=>{try{const c=document.createElement("canvas");c.width=im.naturalWidth;c.height=im.naturalHeight;const g=c.getContext("2d",{willReadFrequently:true});g.drawImage(im,0,0);const px=g.getImageData(0,0,c.width,c.height),d=px.data;for(let i=0;i<d.length;i+=4){if(!d[i+3])continue;d[i]=Math.max(0,Math.min(255,d[i]+delta[0]));d[i+1]=Math.max(0,Math.min(255,d[i+1]+delta[1]));d[i+2]=Math.max(0,Math.min(255,d[i+2]+delta[2]));}g.putImageData(px,0,0);resolve(c.toDataURL("image/png"));}catch(_){resolve(raw)}};im.onerror=()=>resolve(raw);im.src=raw;})));})();this.auraTintCache.set(key,task);return task;
  }
  applyAuraPreviewConfig(preview,a){
    if(!preview)return;const set=(k,v)=>{preview.dataset[k]=S(v)};set("auraParticleCount",N(a.particleCount,12));set("auraPattern",S(a.pattern||"rise"));set("auraRiseSpeed",N(a.riseSpeed,135));set("auraCycleFrames",N(a.cycleFrames,30));set("auraRiseHeight",N(a.riseHeight,100));set("auraSpreadX",N(a.spreadX,100));set("auraSpreadY",N(a.spreadY,80));set("auraLaneWidth",N(a.laneWidth,100));set("auraSwayAmount",N(a.swayAmount,100));set("auraOffsetX",N(a.offsetX,0));set("auraOffsetY",N(a.offsetY,0));set("auraParticleScale",N(a.particleScale,100));set("auraStretchStart",N(a.stretchStart,62));set("auraStretchEnd",N(a.stretchEnd,132));set("auraOpacity",N(a.opacity,100));set("auraOpacityStart",N(a.opacityStart,0));set("auraOpacityMid",N(a.opacityMid,100));set("auraOpacityEnd",N(a.opacityEnd,0));set("auraSpawnMode",S(a.spawnMode||"async"));set("auraAsyncAmount",N(a.asyncAmount,100));set("auraGraphicMode",S(a.graphicMode||"sequence"));set("auraParticleGraphic",S(a.particleGraphic||""));set("auraParticleGraphics",A(a.particleGraphics).map(S).filter(Boolean).join("|"));set("auraGraphicFrameFrames",N(a.graphicFrameFrames,6));set("auraGraphicTransitionFrames",N(a.graphicTransitionFrames,2));set("auraDepthMode",S(a.depthMode||"alternate"));set("auraBlendMode",S(a.blendMode||"normal"));set("auraOutlineEnabled",a.outlineEnabled===false?"0":"1");set("auraOutlineOpacity",N(a.outlineOpacity,46));set("auraOutlineSize",N(a.outlineSize,2));set("auraOutlineEffect",S(a.outlineEffect||"standard"));set("auraOutlineCopies",N(a.outlineCopies,6));set("auraOutlineCopySpacing",N(a.outlineCopySpacing,100));set("auraRoaringStrength",N(a.roaringStrength,100));set("auraRoaringSpeed",N(a.roaringSpeed,100));set("auraPulseStrength",N(a.pulseStrength,100));set("auraPulseSpeed",N(a.pulseSpeed,100));set("auraParallelLayers",encodeURIComponent(JSON.stringify(A(a.parallelLayers).filter(x=>x&&x.enabled!==false).slice(0,8))));preview.style.setProperty("--aura",/^#[0-9A-Fa-f]{6}$/.test(S(a.color))?S(a.color):"#DD445B");preview.style.setProperty("--outline",/^#[0-9A-Fa-f]{6}$/.test(S(a.outlineColor))?S(a.outlineColor):(S(a.color)||"#DD445B"));
  }
  syncAuraParticleCount(preview,count){
    count=Math.max(4,Math.min(24,N(count,12)));const ensure=(attr,cls="bss-aura-runtime-particle")=>{let rows=[...preview.querySelectorAll(`[${attr}]`)];while(rows.length>count){const x=rows.pop();if(x)x.remove();}while(rows.length<count){const el=document.createElement("img");el.className=cls;el.setAttribute(attr,S(rows.length));el.alt="";preview.appendChild(el);rows.push(el);}return rows;};
    const a=ensure("data-aura-particle"),b=ensure("data-aura-particle-b");let layers=[];try{layers=JSON.parse(decodeURIComponent(S(preview.dataset.auraParallelLayers||"%5B%5D")));}catch(_){layers=[];}layers=A(layers).filter(x=>x&&x.enabled!==false).slice(0,8);for(let li=0;li<8;li++){for(const suffix of ["","-b"]){const attr=`data-aura-parallel-particle${suffix}`,sel=`[${attr}^="${li}:"]`,want=li<layers.length?Math.max(4,Math.min(24,N(layers[li].particleCount,count))):0;let rows=[...preview.querySelectorAll(sel)];while(rows.length>want){const x=rows.pop();if(x)x.remove();}while(rows.length<want){const el=document.createElement("img");el.className="bss-aura-runtime-particle bss-aura-parallel-particle";el.setAttribute(attr,`${li}:${rows.length}`);el.alt="";preview.appendChild(el);rows.push(el);}}}return a.concat(b);
  }
  async hydrateAuraRuntimePreview(){
    const previews=[...this.root.querySelectorAll(".bss-aura-live-preview")];if(!previews.length)return;for(const preview of previews){let color=S(getComputedStyle(preview).getPropertyValue("--aura")).trim()||"#DD445B";const cfg=this.auraConfigFromPreview(preview),frames=(await this.auraTintedFrames(color,cfg)).filter(Boolean);if(!preview.isConnected)continue;preview._bssAuraFrames=frames;let layers=[];try{layers=JSON.parse(decodeURIComponent(S(preview.dataset.auraParallelLayers||"%5B%5D")));}catch(_){layers=[];}layers=A(layers).filter(x=>x&&x.enabled!==false).slice(0,8);preview._bssAuraParallelLayers=layers;preview._bssAuraParallelFrames=await Promise.all(layers.map(layer=>this.auraTintedFrames(color,layer).then(x=>x.filter(Boolean)).catch(()=>[])));this.syncAuraParticleCount(preview,N(preview.dataset.auraParticleCount,12));const first=frames[0];if(first){[...preview.querySelectorAll("[data-aura-particle],[data-aura-particle-b]")].forEach(el=>{if(el.src!==first)el.src=first;});}for(let li=0;li<layers.length;li++){const f=A(preview._bssAuraParallelFrames[li])[0];if(!f)continue;[...preview.querySelectorAll(`[data-aura-parallel-particle^="${li}:"],[data-aura-parallel-particle-b^="${li}:"]`)].forEach(el=>{if(el.src!==f)el.src=f;});}}this.startAuraPreviewLoop();
  }
  auraOutlineTintUrl(img,color){try{const key=`edge2|${S(img&&img.src)}|${S(color)}`;if(this.auraOutlineTintCache.has(key))return this.auraOutlineTintCache.get(key);if(!img||!img.naturalWidth||!img.naturalHeight)return S(img&&img.src);const c=document.createElement("canvas");c.width=img.naturalWidth;c.height=img.naturalHeight;const g=c.getContext("2d",{willReadFrequently:true});g.drawImage(img,0,0);const src=g.getImageData(0,0,c.width,c.height),out=g.createImageData(c.width,c.height),rgb=this.auraHexRGB(/^#[0-9A-Fa-f]{6}$/.test(S(color))?S(color):"#FFFFFF"),w=c.width,h=c.height;for(let y=0;y<h;y++){for(let x=0;x<w;x++){const i=(y*w+x)*4,a=src.data[i+3];if(a<18)continue;let edge=false;for(let oy=-2;oy<=2&&!edge;oy++){for(let ox=-2;ox<=2;ox++){if(!ox&&!oy)continue;const xx=x+ox,yy=y+oy;if(xx<0||yy<0||xx>=w||yy>=h||src.data[(yy*w+xx)*4+3]<18){edge=true;break;}}}if(edge){out.data[i]=rgb[0];out.data[i+1]=rgb[1];out.data[i+2]=rgb[2];out.data[i+3]=a;}}}g.clearRect(0,0,w,h);g.putImageData(out,0,0);const url=c.toDataURL("image/png");this.auraOutlineTintCache.set(key,url);return url;}catch(_){return S(img&&img.src);}}
  syncAuraOutlineCopies(preview,img){if(!preview||!img)return;const stack=preview.querySelector("[data-aura-outline-stack]");if(!stack)return;const count=Math.max(1,Math.min(12,N(preview.dataset.auraOutlineCopies,6)));let rows=[...stack.querySelectorAll(".bss-aura-outline-copy")];while(rows.length>count){const x=rows.pop();x.remove();}while(rows.length<count){const x=document.createElement("img");x.className="bss-aura-outline-copy";x.alt="";stack.appendChild(x);rows.push(x);}const color=getComputedStyle(preview).getPropertyValue("--outline").trim()||"#FFFFFF",src=this.auraOutlineTintUrl(img,color);rows.forEach(x=>{if(src&&x.src!==src)x.src=src;x.style.width=img.style.width||`${img.offsetWidth}px`;x.style.height=img.style.height||`${img.offsetHeight}px`;});}
  auraOpacityCurveConfig(cfg,t){const start=N(cfg&&cfg.opacityStart,0)/100,mid=N(cfg&&cfg.opacityMid,100)/100,end=N(cfg&&cfg.opacityEnd,0)/100;if(t<=.5){const q=this.auraSmoothstep(t*2);return start+(mid-start)*q;}const q=this.auraSmoothstep((t-.5)*2);return mid+(end-mid)*q;}
  auraSmoothstep(x){x=Math.max(0,Math.min(1,N(x)));return x*x*(3-2*x);}
  auraOpacityCurve(preview,t){const d=preview.dataset,start=N(d.auraOpacityStart,0)/100,mid=N(d.auraOpacityMid,100)/100,end=N(d.auraOpacityEnd,0)/100;if(t<=.5){const q=this.auraSmoothstep(t*2);return start+(mid-start)*q;}const q=this.auraSmoothstep((t-.5)*2);return mid+(end-mid)*q;}
  auraSequenceState(frameCount,ageFrames,holdFrames,transitionFrames){
    frameCount=Math.max(1,N(frameCount,1));holdFrames=Math.max(1,N(holdFrames,6));transitionFrames=Math.max(0,Math.min(30,N(transitionFrames,2)));if(frameCount<=1)return {a:0,b:-1,mix:0,done:false};const slot=holdFrames+transitionFrames,total=(frameCount-1)*slot+holdFrames;if(ageFrames>=total)return {a:frameCount-1,b:-1,mix:0,done:true};const step=Math.min(frameCount-1,Math.floor(ageFrames/slot)),within=ageFrames-step*slot;if(step>=frameCount-1)return {a:frameCount-1,b:-1,mix:0,done:false};if(transitionFrames>0&&within>=holdFrames){return {a:step,b:step+1,mix:Math.max(0,Math.min(1,(within-holdFrames)/transitionFrames)),done:false};}return {a:step,b:-1,mix:0,done:false};
  }
  applyAuraParticlePair(aEl,bEl,frames,state,geom,alpha,blend,z){
    if(!aEl)return;frames=A(frames);const set=(el,url,op)=>{if(!el)return;if(url&&el.src!==url)el.src=url;el.style.left=`${geom.x}px`;el.style.top=`${geom.y}px`;el.style.width=`${Math.max(1,geom.w)}px`;el.style.height=`${Math.max(1,geom.h)}px`;el.style.opacity=S(Math.max(0,Math.min(1,alpha*op)));el.style.visibility=alpha*op>.005?"visible":"hidden";el.style.zIndex=S(z);el.style.mixBlendMode=blend==="additive"?"plus-lighter":"normal";el.style.transform=`translate(-50%,-100%) scaleX(${geom.flip})`;};const ua=frames[state.a]||frames[frames.length-1],ub=state.b>=0?(frames[state.b]||ua):null;set(aEl,ua,state.b>=0?1-state.mix:1);set(bEl,ub||ua,state.b>=0?state.mix:0);
  }
  drawAuraPreview(preview,frame){
    if(!preview||!preview.isConnected)return;const mon=preview.querySelector(".bss-aura-demo-mon"),img=preview.querySelector(".bss-aura-test-img"),target=img||mon;if(!target)return;const pr=preview.getBoundingClientRect(),tr=target.getBoundingClientRect(),w=Math.max(1,tr.width),h=Math.max(1,tr.height),left=tr.left-pr.left,top=tr.top-pr.top,d=preview.dataset,targetScale=img&&img.naturalWidth?Math.max(.05,w/img.naturalWidth):1;
    const main={pattern:S(d.auraPattern||"rise"),riseSpeed:N(d.auraRiseSpeed,135),cycleFrames:N(d.auraCycleFrames,30),riseHeight:N(d.auraRiseHeight,100),spreadX:N(d.auraSpreadX,100),spreadY:N(d.auraSpreadY,80),laneWidth:N(d.auraLaneWidth,100),swayAmount:N(d.auraSwayAmount,100),offsetX:N(d.auraOffsetX,0),offsetY:N(d.auraOffsetY,0),particleScale:N(d.auraParticleScale,100),stretchStart:N(d.auraStretchStart,62),stretchEnd:N(d.auraStretchEnd,132),opacity:N(d.auraOpacity,100),opacityStart:N(d.auraOpacityStart,0),opacityMid:N(d.auraOpacityMid,100),opacityEnd:N(d.auraOpacityEnd,0),spawnMode:S(d.auraSpawnMode||"async"),asyncAmount:N(d.auraAsyncAmount,100),phaseOffset:0,graphicFrameFrames:N(d.auraGraphicFrameFrames,6),graphicTransitionFrames:N(d.auraGraphicTransitionFrames,2),depthMode:S(d.auraDepthMode||"alternate"),blendMode:S(d.auraBlendMode||"normal")};
    const drawSet=(cfg,frames,count,getPair,layerZ=0)=>{cfg=cfg||{};const speed=Math.max(.25,N(cfg.riseSpeed,135)/100),cycle=Math.max(10,N(cfg.cycleFrames,30)),life=Math.max(cycle/speed,14),riseHeight=N(cfg.riseHeight,100)/100,spreadX=N(cfg.spreadX,100)/100,spreadY=N(cfg.spreadY,80)/100,laneWidth=N(cfg.laneWidth,100)/100,sway=N(cfg.swayAmount,100)/100,offX=N(cfg.offsetX,0)/100,offY=N(cfg.offsetY,0)/100,scaleCfg=N(cfg.particleScale==null?cfg.scale:cfg.particleScale,100)/100,stretchStart=N(cfg.stretchStart,62)/100,stretchEnd=N(cfg.stretchEnd,132)/100,general=N(cfg.opacity,100)/100,spawn=S(cfg.spawnMode||"async"),asyncAmount=Math.max(0,Math.min(300,N(cfg.asyncAmount,100)))/100,phaseOffset=Math.max(0,Math.min(100,N(cfg.phaseOffset,0)))/100,hold=Math.max(1,Math.min(60,N(cfg.graphicFrameFrames,6))),trans=Math.max(0,Math.min(30,N(cfg.graphicTransitionFrames,2))),depth=S(cfg.depthMode||"alternate"),blend=S(cfg.blendMode||"normal");for(let i=0;i<count;i++){const [el,elB]=getPair(i);if(!el)continue;const lane=count>1?i/(count-1):.5,row=i%3,phase=life*phaseOffset+(spawn==="simultaneous"?0:i*7*asyncAmount),raw=((frame+phase)%life)/life,start=.075,end=.925;if(raw<=start||raw>=end){for(const x of [el,elB])if(x){x.style.opacity="0";x.style.visibility="hidden";}continue;}let t=(raw-start)/(end-start);t=Math.max(0,Math.min(1,t));const age=t*life,pattern=S(cfg.pattern||"rise");let nx=.5,ny=.68,rise=0,angle=t*Math.PI*2+i*.73+phaseOffset*6.28;if(pattern==="orbit"){nx=.5+Math.cos(angle*1.35)*.30*spreadX;ny=.55+Math.sin(angle*1.35)*.20*spreadY;}else if(pattern==="vortex"){const radius=(.36-.24*t)*spreadX;nx=.5+Math.cos(angle*2.4)*radius;ny=.66-.24*t+Math.sin(angle*2.4)*.09*spreadY;}else if(pattern==="rain"){const baseLane=.5+.72*(lane-.5)*laneWidth;nx=.5+(baseLane-.5)*spreadX+Math.sin(angle)*.010*sway;ny=.16+.72*t;}else if(pattern==="burst"){const theta=(i/Math.max(1,count))*Math.PI*2+phaseOffset*6.28,radius=.06+.36*t;nx=.5+Math.cos(theta)*radius*spreadX;ny=.57+Math.sin(theta)*radius*.72*spreadY;}else if(pattern==="halo"){const theta=angle*1.15;nx=.5+Math.cos(theta)*.29*spreadX;ny=.32+Math.sin(theta)*.085*spreadY;}else if(pattern==="ground"){const theta=angle;nx=.5+Math.cos(theta)*.34*spreadX;ny=.79+Math.sin(theta)*.065*spreadY;}else{const baseLane=.5+(.68*(lane-.5)*laneWidth);nx=.5+(baseLane-.5)*spreadX;nx+=Math.sin(angle)*.012*spreadX*sway;const baseY=[.68,.54,.78][row];ny=.5+(baseY-.5)*spreadY;rise=h*.12*t*speed*riseHeight;}nx=Math.max(.04,Math.min(.96,nx+offX));ny=Math.max(.08,Math.min(.94,ny+offY));const x=left+nx*w,y=top+ny*h-rise,stretch=stretchStart+(stretchEnd-stretchStart)*t,alpha=Math.max(0,Math.min(1,this.auraOpacityCurveConfig(cfg,t)*general)),nativeW=Math.max(1,el.naturalWidth||70),nativeH=Math.max(1,el.naturalHeight||70),pw=nativeW*targetScale*scaleCfg,ph=nativeH*targetScale*scaleCfg*stretch,z=depth==="front"?4:depth==="back"?2:(i%2===0?4:2),state=this.auraSequenceState(A(frames).length,age,hold,trans);this.applyAuraParticlePair(el,elB,frames,state,{x,y,w:pw,h:ph,flip:nx>=.5?-1:1},alpha,blend,z+layerZ);}};
    const mainRows=[...preview.querySelectorAll("[data-aura-particle]")];drawSet(main,preview._bssAuraFrames||[],mainRows.length,i=>[preview.querySelector(`[data-aura-particle="${i}"]`),preview.querySelector(`[data-aura-particle-b="${i}"]`)],0);
    const layers=A(preview._bssAuraParallelLayers),layerFrames=A(preview._bssAuraParallelFrames);layers.forEach((layer,li)=>{const count=Math.max(4,Math.min(24,N(layer.particleCount,mainRows.length)));drawSet(Object.assign({phaseOffset:(li+1)*23},layer),A(layerFrames[li]),count,i=>[preview.querySelector(`[data-aura-parallel-particle="${li}:${i}"]`),preview.querySelector(`[data-aura-parallel-particle-b="${li}:${i}"]`)],li+1);});
    if(img){this.syncAuraOutlineCopies(preview,img);const enabled=S(d.auraOutlineEnabled)!=="0",baseOp=Math.max(0,Math.min(1,N(d.auraOutlineOpacity,46)/100)),size=Math.max(1,Math.min(8,N(d.auraOutlineSize,2))),rgb=this.auraHexRGB(getComputedStyle(preview).getPropertyValue("--outline").trim()||"#DD445B"),effect=S(d.auraOutlineEffect||"standard"),copies=Math.max(1,Math.min(12,N(d.auraOutlineCopies,6))),spacing=Math.max(.25,Math.min(3,N(d.auraOutlineCopySpacing,100)/100)),strength=Math.max(0,Math.min(2.5,N(d.auraRoaringStrength,100)/100)),rspeed=Math.max(.1,N(d.auraRoaringSpeed,100)/100),pstrength=Math.max(0,Math.min(2.5,N(d.auraPulseStrength,100)/100)),pspeed=Math.max(.1,N(d.auraPulseSpeed,100)/100),c=`rgba(${rgb[0]},${rgb[1]},${rgb[2]},${baseOp})`;img.style.filter=enabled?`drop-shadow(${-size}px 0 0 ${c}) drop-shadow(${size}px 0 0 ${c}) drop-shadow(0 ${-size}px 0 ${c}) drop-shadow(0 ${size}px 0 ${c})`:`none`;const ghosts=[...preview.querySelectorAll(".bss-aura-outline-copy")];const pulsePhase=((frame*.032*pspeed)%1+1)%1,pulseBeat=ph=>{const g1=Math.exp(-Math.pow((ph-.10)/.10,2)),g2=.76*Math.exp(-Math.pow((ph-.33)/.115,2));return Math.min(1,g1+g2)};const beat=pulseBeat(pulsePhase),pulseBody=.10+.90*beat;ghosts.forEach((ghost,i)=>{if(!enabled||effect==="standard"||i>=copies){ghost.style.opacity="0";ghost.style.visibility="hidden";return;}const fall=1-i/Math.max(1,copies),n=i+1;if(effect==="roaring_knight"){const dist=n*size*2.3*spacing*strength,wave=Math.sin(frame*.22*rspeed+i*1.7),jy=Math.cos(frame*.31*rspeed+i*2.1)*size*1.2*strength,dx=dist*(.72+.28*Math.sin(frame*.11*rspeed+i)),dy=-dist*.18+jy;ghost.style.transform=`translate(-50%,-50%) translate(${dx}px,${dy}px) scale(${1+n*.008*strength})`;ghost.style.opacity=S(Math.max(0,Math.min(.8,baseOp*fall*(.22+.28*(wave*.5+.5))*strength)));}else{const ph=((pulsePhase-i*.075*spacing)%1+1)%1,localBeat=pulseBeat(ph),body=.10+.90*localBeat,grow=1+n*.022*spacing*pstrength*(.48+body*1.38);ghost.style.transform=`translate(-50%,-50%) scale(${grow})`;ghost.style.opacity=S(Math.max(0,Math.min(.75,baseOp*fall*body*pstrength)));}ghost.style.visibility=Number(ghost.style.opacity)>.005?"visible":"hidden";});}
  }
  startAuraPreviewLoop(){
    if(this.auraPreviewRAF)return;if(!this.root.querySelector(".bss-aura-live-preview"))return;this.auraPreviewLast=performance.now();const tick=now=>{if(!this.root||!this.root.isConnected||!this.root.querySelector(".bss-aura-live-preview")){this.auraPreviewRAF=0;return;}let dt=(now-this.auraPreviewLast)/1000;this.auraPreviewLast=now;if(!Number.isFinite(dt)||dt<0)dt=0;dt=Math.min(dt,.05);this.auraPreviewFrame+=dt*40;this.root.querySelectorAll(".bss-aura-live-preview").forEach(x=>this.drawAuraPreview(x,this.auraPreviewFrame));this.auraPreviewRAF=requestAnimationFrame(tick);};this.auraPreviewRAF=requestAnimationFrame(tick);
  }
  stopAuraPreviewLoop(){if(this.auraPreviewRAF){cancelAnimationFrame(this.auraPreviewRAF);this.auraPreviewRAF=0;}this.auraPreviewLast=0;}
  refreshAuraStudioPreview(){
    const p=this.currentAuraProfile(),root=this.body&&this.body.querySelector(".bss-aura-studio-screen");if(this.screen!=="aura"||!p||!root)return;const a=p.aura||{},preview=root.querySelector(".bss-aura-live-preview");if(preview){this.applyAuraPreviewConfig(preview,a);this.syncAuraParticleCount(preview,a.particleCount);const img=preview.querySelector(".bss-aura-test-img");if(img)this.syncAuraOutlineCopies(preview,img);preview._bssAuraFrames=null;this.hydrateAuraRuntimePreview();}const active=root.querySelector(".bss-aura-profile.active b");if(active)active.textContent=S(p.name||p.id);this.startAuraPreviewLoop();
  }
  sosHTML(b){
    const s=b.sos,pool=A(s.pool),sum=pool.reduce((n,p)=>n+Math.max(0,N(typeof p==="string"?100:p.weight,100)),0)||1,isTrainer=b.setup&&b.setup.kind==="trainer",levelMode=S(s.levelMode||"range"),allyMode=S(s.allySelectionMode||"random"),messages=s.messages||{};
    const maxSOS=Math.max(1,Math.min(2,N(s.maxSimultaneousSOS,1))),perCall=Math.max(1,Math.min(maxSOS,N(s.summonsPerCall,1)));
    const poolRows=pool.map((raw,i)=>{const p=typeof raw==="string"?{species:raw,form:0,weight:100}:raw,pc=(Math.max(0,N(p.weight,100))*100/sum).toFixed(1),custom=this.pokemonCustomActive(p);return `<div class="bss-poolentry"><div class="bss-poolrow bss-scripted-poolrow"><span class="bss-icon ph" data-battle-pool-icon="${i}">?</span><b>${E(p.species)}${N(p.form)?` · F${N(p.form)}`:""}</b>${allyMode==="fixed"?`<span class="bss-fixed-slot">Slot ${i+1}</span><small></small>`:`<label>Peso <input class="bss-input mini" type="number" min="0" data-battle-pool-weight="${i}" value="${N(p.weight,100)}"></label><small data-battle-pool-percent="${i}">${pc}%</small>`}<button class="bss-btn small ${custom?"active":""}" data-pokemon-edit="sos:${i}" title="Configurar Habilidad, IVs, EVs, objeto, movepool…">⚙</button><button class="bss-btn small" data-pick-special="sos:replace:${i}">Cambiar</button><button class="bss-btn small danger" data-battle-pool-remove="${i}" title="Eliminar este SOS">×</button></div></div>`}).join("")||`<small>Vacío: usa el perfil SOS global de la especie que llama.</small>`;
    const levelControl=this.field("Nivel del refuerzo SOS",`<select class="bss-select" data-bind="sos.levelMode"><option value="zone" ${levelMode==="zone"?"selected":""}>Salvajes de la zona actual</option><option value="range" ${levelMode==="range"?"selected":""}>Custom · intervalo</option><option value="fixed" ${levelMode==="fixed"?"selected":""}>Custom · nivel fijo</option></select><span class="bss-note">${levelMode==="zone"?"Usa los niveles del encounter table del mapa; prioriza la especie llamada si aparece en la zona.":levelMode==="fixed"?"Todos los SOS de este combate usan el nivel fijo indicado.":"Elige un intervalo propio; si dejas un límite vacío, ese límite usa el nivel del caller."}</span>`)+(levelMode==="range"?this.field("Intervalo custom",`<div class="bss-level-range"><input class="bss-input" type="number" min="1" max="100" data-bind="sos.levelMin" placeholder="Caller" value="${s.levelMin==null?"":E(s.levelMin)}"><span>–</span><input class="bss-input" type="number" min="1" max="100" data-bind="sos.levelMax" placeholder="Caller" value="${s.levelMax==null?"":E(s.levelMax)}"></div>`):levelMode==="fixed"?this.field("Nivel fijo custom",`<input class="bss-input" type="number" min="1" max="100" data-bind="sos.levelFixed" placeholder="Caller" value="${s.levelFixed==null?"":E(s.levelFixed)}">`):"");
    const messageFields=`<div class="bss-subpanel"><b>Mensajes SOS guionizados</b><p class="bss-note">Vacío = mensaje normal. Llamada/fallo: {1} = caller. Éxito: {1} = SOS y {2} = caller.</p>${this.field("Mensaje al pedir ayuda",`<input class="bss-input" data-bind="sos.messages.call" placeholder="¡{1} pidió ayuda!" value="${E(messages.call||"")}">`)}${this.field("Mensaje de espera",`<input class="bss-input" data-bind="sos.messages.wait" placeholder="... ... ..." value="${E(messages.wait||"")}">`)}${this.field("Mensaje cuando llega",`<input class="bss-input" data-bind="sos.messages.success" placeholder="¡Apareció {1}!" value="${E(messages.success||"")}">`)}${this.field("Mensaje cuando falla",`<input class="bss-input" data-bind="sos.messages.fail" placeholder="¡La ayuda no apareció!" value="${E(messages.fail||"")}">`)}</div>`;
    return this.panel("SOS nativo",`<div class="bss-sosbanner">${isTrainer?"SOS guionizado de entrenador: el Pokémon activo del trainer puede pedir refuerzos externos a su party. Los SOS Globales nunca activan trainers por sí solos.":"El combate empieza físicamente 1v1. La llamada inicial forzada tiene 100% de respuesta salvo que cambies Answer rate."}</div><label class="bss-check"><input type="checkbox" data-bind="sos.enabled" ${s.enabled?"checked":""}> Activar SOS en este combate</label><label class="bss-check"><input type="checkbox" data-bind="sos.automaticCalls" ${s.automaticCalls?"checked":""}> Llamadas automáticas</label><label class="bss-check"><input type="checkbox" data-bind="sos.allowAdditionalCalls" ${s.allowAdditionalCalls?"checked":""}> Autorizar más llamadas después del primer refuerzo</label><label class="bss-check"><input type="checkbox" data-bind="sos.allowRecursiveCalls" ${s.allowRecursiveCalls?"checked":""}> Permitir que un Pokémon llamado haga SOS</label>${this.field("Máximo de refuerzos SOS simultáneos",`<input class="bss-input" type="number" min="1" max="2" data-bind="sos.maxSimultaneousSOS" value="${maxSOS}"><span class="bss-note">1 = caller + 1 SOS · 2 = caller + hasta 2 SOS a la vez.</span>`)}${this.field("SOS que aparecen por llamada guionizada",`<input class="bss-input" type="number" min="1" max="${maxSOS}" data-bind="sos.summonsPerCall" value="${perCall}"><span class="bss-note">Con 2, una misma llamada puede traer dos refuerzos, siempre respetando el máximo simultáneo.</span>`)}<label class="bss-check"><input type="checkbox" data-bind="sos.initialCall" ${s.initialCall?"checked":""}> Forzar llamada inicial</label>${this.field("Ronda de llamada inicial",`<input class="bss-input" type="number" min="1" data-bind="sos.callRound" value="${N(s.callRound,1)}">`)}${this.field("Probabilidad de intentar llamar (%)",`<input class="bss-input" type="number" min="0" max="100" data-bind="sos.callRate" placeholder="Perfil global" value="${s.callRate==null?"":E(s.callRate)}"><span class="bss-note">En un SOS guionizado, 100% de llamada + 100% de respuesta significa llamada garantizada en cada momento automático elegible. “Forzar llamada inicial” sigue siendo independiente y decide si ocurre antes del primer turno.</span>`)}${this.field("Probabilidad de que llegue ayuda (%)",`<input class="bss-input" type="number" min="0" max="100" data-bind="sos.answerRate" placeholder="100" value="${s.answerRate==null?"":E(s.answerRate)}">`)}${levelControl}${this.field("Selección de aliados",`<select class="bss-select" data-bind="sos.allySelectionMode"><option value="random" ${allyMode==="random"?"selected":""}>Random ponderado</option><option value="fixed" ${allyMode==="fixed"?"selected":""}>Aliados fijos / ordenados</option></select><span class="bss-note">${allyMode==="fixed"?"Los slots se consumen en orden. Ej.: Pikachu + Pichu garantiza esos dos; puedes repetir especie en varios slots.":"Cada llegada sortea la pool con reemplazo. Pikachu + Pichu puede dar Pika/Pichu, 2 Pika o 2 Pichu."}</span>`)}<div class="bss-field"><span>${allyMode==="fixed"?"Slots SOS fijos":"Pool SOS ponderada"}</span><div class="bss-poollist">${poolRows}</div><button class="bss-btn" data-pick-special="sos:pool">＋ Añadir Pokémon</button><small class="bss-note">Puedes eliminar o cambiar cualquier slot. Usa ⚙ para definir Habilidad, Naturaleza, IVs, EVs, objeto, Shiny, género, felicidad y movepool de cada SOS.</small></div><button class="bss-btn" data-act="clear-sos-pool">Usar perfil SOS global</button>${messageFields}`);
  }
  refreshBattlePoolPercentages(){const b=this.battle(),pool=b?A(b.sos&&b.sos.pool):[],sum=pool.reduce((n,p)=>n+Math.max(0,N(typeof p==="string"?100:p&&p.weight,100)),0)||1;this.root.querySelectorAll("[data-battle-pool-percent]").forEach(el=>{const i=N(el.dataset.battlePoolPercent,-1),p=pool[i];if(i<0||!p)return;const w=Math.max(0,N(typeof p==="string"?100:p&&p.weight,100));el.textContent=`${(w*100/sum).toFixed(1)}%`;});}
  refreshProfilePoolPercentages(key){key=S(key);const cut=key.lastIndexOf(":"),p=this.profile(key.slice(0,cut),N(key.slice(cut+1))),pool=p?A(p.pool):[],sum=pool.reduce((n,x)=>n+Math.max(0,N(typeof x==="string"?100:x&&x.weight,100)),0)||1;this.root.querySelectorAll("[data-profile-pool-percent]").forEach(el=>{const raw=S(el.dataset.profilePoolPercent),bar=raw.lastIndexOf("|");if(raw.slice(0,bar)!==key)return;const i=N(raw.slice(bar+1),-1),x=pool[i];if(i<0||!x)return;const w=Math.max(0,N(typeof x==="string"?100:x&&x.weight,100));el.textContent=`${(w*100/sum).toFixed(1)}%`;});}
  specButton(spec,target){return `<button class="bss-btn bss-specbtn" data-pick-special="${E(target)}"><span class="bss-icon ph" data-special-icon="${E(target)}">?</span><span>${E(spec||"Use JSON/default")}</span></button>`;}
  async mountPreview(b){
    const canvas=this.body.querySelector("[data-preview]");if(!canvas)return;
    const anim=createAnimation("BSS Battle Preview",{targetMode:"foe",catalogType:"custom"});anim.duration=1;anim.battlers.user.locked=false;anim.battlers.target.locked=false;
    const userLayout=b.layout&&b.layout.battlers&&b.layout.battlers.user||{},targetLayout=b.layout&&b.layout.battlers&&b.layout.battlers.target||{};
    anim.battlers.user.visual.size=N(userLayout.scale,100);anim.battlers.target.visual.size=N(targetLayout.scale,100);
    const ctx=this.previewContext(b),up=ctx.user,tp=ctx.target;
    setPositionKey(anim.battlers.user,0,{anchor:"screen",x:up.x,y:up.y,offsetX:0,offsetY:0},"linear","screen");setPositionKey(anim.battlers.target,0,{anchor:"screen",x:tp.x,y:tp.y,offsetX:0,offsetY:0},"linear","screen");
    this.previewAnimation=anim;this.preview=new BattlePreview(canvas,{onSelectObject:id=>{this.preview.selectedObjectId=id;this.preview.draw();},onMove:p=>{const side=p.objectId==="battler_user"?"user":p.objectId==="battler_target"?"target":null;if(!side)return;setPositionKey(anim.battlers[side],0,{anchor:"screen",x:p.x,y:p.y,offsetX:0,offsetY:0},"linear","screen");b.layout.battlers[side]=Object.assign({},b.layout.battlers[side]||{},{x:Math.round(p.x),y:Math.round(p.y)});const info=side==="user"?ctx.user:ctx.target;info.x=p.x;info.y=p.y;info.focusX=p.x;info.focusY=p.y-40;this.preview.draw();this.touch();},onScale:(id,delta)=>{const side=id==="battler_user"?"user":id==="battler_target"?"target":null;if(!side)return;const o=anim.battlers[side];o.visual.size=Math.max(20,Math.min(300,N(o.visual.size,100)+delta));b.layout.battlers[side]=Object.assign({},b.layout.battlers[side]||{},{scale:o.visual.size});this.preview.draw();this.touch();}});
    this.preview.setContext(ctx);this.preview.setState(anim,"battler_target",0,{playing:false});
    const userP=b.teams.testPlayer[0]||{},targetP=b.teams.foes[0]||{},us=findBattlerSprite(this.source,userP.species,"user",userP.form),ts=findBattlerSprite(this.source,targetP.species,"target",targetP.form);
    const [uu,tu]=await Promise.all([this.assetUrl(us),this.assetUrl(ts)]);if(!this.preview)return;this.preview.setBattlers(uu,tu,{userBack:uu,targetFront:tu},{user:{},target:{},userBack:{},targetFront:{}});
    const primaryMetaPromise=(async()=>{const uMeta=await this.battlerRenderInfo(us,userP,"user"),tMeta=await this.battlerRenderInfo(ts,targetP,"target");return [uMeta,tMeta];})();
    const env=b.environment||{},globalVisual=this.studio.global||{},cameraStyle=S(env.cameraStyle||"inherit")==="inherit"?S(globalVisual.cameraStyle||"project"):S(env.cameraStyle),ebdxName=(()=>{let x=S(env.ebdxBackdrop||"inherit");if(!x||x==="inherit")x=S(globalVisual.ebdxBackdrop||"Auto");return x==="Auto"?"Field":x;})(),ebdxPreviewName=this.ebdxPreviewBackdropName(ebdxName);
    let g=findBattlebackGroup(this.source,b.environment.battleback);if(!g){const gs=A(this.source.battlebackGroups),complete=gs.filter(x=>x&&x.background&&x.playerBase&&x.enemyBase);g=complete.find(x=>/^(indoor1|grass|field|route|forest)$/i.test(S(x.key)))||complete.find(x=>/(grass|field|route|forest|outdoor|indoor)/i.test(S(x.key)))||complete[0]||null;}
    const scenePromise=cameraStyle==="ebdx"?Promise.all([this.assetUrl({projectPath:`Graphics/BattleSceneStudio/EBDX/preview/${ebdxPreviewName}.png`}),Promise.resolve(""),Promise.resolve("")]):(g?Promise.all([this.assetUrl(g.background),this.assetUrl(g.playerBase),this.assetUrl(g.enemyBase)]):Promise.resolve(null));
    const valid=[],[uc,fc]=initialFormation(b);
    for(let i=0;i<uc;i++){const idx=i*2,p=b.teams.testPlayer[i];if(!p)continue;valid.push(idx);if(idx===0)continue;const a=findBattlerSprite(this.source,p.species,"user",p.form),u=await this.assetUrl(a);if(this.preview)this.preview.setContextBattler(idx,u,{});const meta=await this.battlerRenderInfo(a,p,"user");if(this.preview){this.preview.contextBattlerMeta.set(idx,meta||{});this.preview.draw();}}
    for(let i=0;i<fc;i++){const idx=i*2+1,p=b.teams.foes[i];if(!p)continue;valid.push(idx);if(idx===1)continue;const a=findBattlerSprite(this.source,p.species,"target",p.form),u=await this.assetUrl(a);if(this.preview)this.preview.setContextBattler(idx,u,{});const meta=await this.battlerRenderInfo(a,p,"target");if(this.preview){this.preview.contextBattlerMeta.set(idx,meta||{});this.preview.draw();}}
    if(this.preview)this.preview.clearContextBattlers(valid);const sceneUrls=await scenePromise;if(sceneUrls&&this.preview)this.preview.setSceneImages(sceneUrls[0],sceneUrls[1],sceneUrls[2]);const [uMeta,tMeta]=await primaryMetaPromise;if(this.preview){this.preview.battlerMeta=Object.assign({},this.preview.battlerMeta,{user:uMeta||{},target:tMeta||{},userBack:uMeta||{},targetFront:tMeta||{}});this.preview.draw();}
    this.hydrateInspectorIcons();
  }
  previewContext(b){
    const formation=S(b&&b.setup&&b.setup.formation||"1v1");let ctx=effectiveBattleContext({contextMode:"script",battleFormat:formation,activeUserSlot:0,activeTargetSlot:0},this.runtimeContext,this.projectScriptContext);if(!ctx)ctx=fallbackBattleContext(N(this.runtimeContext&&this.runtimeContext.width||this.projectScriptContext&&this.projectScriptContext.width,640),N(this.runtimeContext&&this.runtimeContext.height||this.projectScriptContext&&this.projectScriptContext.height,480),"bss");
    const [uc,fc]=initialFormation(b),bw=N(ctx.width,640),bh=N(ctx.height,480),baseRows=A(ctx.raw&&ctx.raw.battlers);ctx.source=this.runtimeContext?"BAS runtime context":this.projectScriptContext?"BAS script context":"BAS project context";ctx.captureKind=`${S(ctx.captureKind||"pbBattlerPosition")} · ${formation}`;ctx.sideSizes={user:uc,target:fc};
    const rowFor=idx=>baseRows.find(v=>N(v&&v.index,-1)===idx)||null,makeRow=(idx,side,i,count,pokemon)=>{const def=this.slotPos(idx,count,bw,bh),base=rowFor(idx)||((i===0&&side==="user"&&ctx.scriptUser)?ctx.scriptUser:(i===0&&side==="target"&&ctx.scriptTarget)?ctx.scriptTarget:def),key=idx===0?"user":idx===1?"target":String(idx),ov=b.layout.battlers[key]||{},x=N(ov.x,N(base.x,def.x)),y=N(ov.y,N(base.y,def.y));return Object.assign({},base||{},{index:idx,x,y,focusX:N(base&&base.focusX,x),focusY:N(base&&base.focusY,y-40),zoomX:N(base&&base.zoomX,1),zoomY:N(base&&base.zoomY,1),z:N(base&&base.z,side==="user"?1100-idx*5:900-idx*5),bitmapWidth:N(base&&base.bitmapWidth,0),bitmapHeight:N(base&&base.bitmapHeight,0),bitmapReal:!!(base&&base.bitmapReal),visible:true,species:pokemon&&pokemon.species||"",side_size:count});};
    const users=[],foes=[];for(let i=0;i<uc;i++)users.push(makeRow(i*2,"user",i,uc,b.teams.testPlayer[i]));for(let i=0;i<fc;i++)foes.push(makeRow(i*2+1,"target",i,fc,b.teams.foes[i]));
    ctx.user=users[0]||ctx.user;ctx.target=foes[0]||ctx.target;ctx.scriptUser=users[0]?{x:users[0].x,y:users[0].y}:ctx.scriptUser;ctx.scriptTarget=foes[0]?{x:foes[0].x,y:foes[0].y}:ctx.scriptTarget;ctx.raw=Object.assign({},ctx.raw||{},{battlers:[...users,...foes],user_index:0,target_index:1,user_side_size:uc,target_side_size:fc,user_battler_position:ctx.scriptUser?[ctx.scriptUser.x,ctx.scriptUser.y]:null,target_battler_position:ctx.scriptTarget?[ctx.scriptTarget.x,ctx.scriptTarget.y]:null});return ctx;
  }
  slotPos(index,count,w,h){const foe=(index&1)===1;let x=foe?w-128:128,y=foe?h*3/4-112:h-80;if(count===2){const ox=[-48,48,32,-32],oy=[0,0,16,-16];x+=N(ox[index],0);y+=N(oy[index],0)}else if(count===3){const ox=[-80,80,0,0,80,-80],oy=[0,0,8,-8,16,-16];x+=N(ox[index],0);y+=N(oy[index],0)}return{x,y};}
  disposePreview(){if(this.preview){try{this.preview.destroy()}catch(_){ }this.preview=null;}this.previewAnimation=null;}
  catalogProfile(species,form){const list=A(this.sosCatalog&&this.sosCatalog.profiles),sp=U(species),f=N(form);return list.find(x=>U(x.species)===sp&&N(x.form)===f)||list.find(x=>U(x.species)===sp&&N(x.form)===0)||null;}
  effectiveProfile(species,form){return this.profile(species,form);}
  renderSOSStudio(){
    const g=this.sosGlobal,q=L(this.sosSearch),assigned=A(g.overrides),filtered=assigned.filter(p=>!q||L(`${p.species} ${p.form||0}`).includes(q));
    const reqTypes=[["badge_min","Medallas mínimas"],["badge_max","Medallas máximas"],["switch_on","Switch ON"],["switch_off","Switch OFF"],["variable_min","Variable ≥"],["variable_max","Variable ≤"],["variable_equals","Variable ="],["caller_level_min","Nivel caller ≥"],["caller_level_max","Nivel caller ≤"],["player_level_min","Nivel equipo jugador ≥"],["player_level_max","Nivel equipo jugador ≤"],["map_id","Mapa ID"],["chain_min","Cadena SOS ≥"],["chain_max","Cadena SOS ≤"],["day","De día"],["night","De noche"]];
    const globalReqTypes=[["badge_min","Medallas mínimas"],["badge_max","Medallas máximas"],["switch_on","Switch ON"],["switch_off","Switch OFF"],["variable_min","Variable ≥"],["variable_max","Variable ≤"],["variable_equals","Variable ="],["player_level_min","Nivel equipo jugador ≥"],["player_level_max","Nivel equipo jugador ≤"],["map_id","Mapa ID"],["day","De día"],["night","De noche"]];
    const globalPanel=this.panel("SOS Global del juego",`<div class="bss-dataset-meta"><b>Asignaciones activas = lo que usa el juego</b><p>Las bibliotecas SM/USUM, Arceus, Z-A, Mega Dimensions y PokéRogue solo entran aquí al pulsar Importar.</p></div><label class="bss-check"><input type="checkbox" data-global="enabled" ${g.enabled?"checked":""}> Activar SOS global</label>${this.field("Modo",`<select class="bss-select" data-global="mode"><option value="battle_only" ${g.mode==="battle_only"?"selected":""}>Solo combates BSS</option><option value="always" ${g.mode==="always"?"selected":""}>Todos los salvajes</option><option value="switch" ${g.mode==="switch"?"selected":""}>Todos los salvajes con Switch</option></select>`)}${g.mode==="switch"?this.field("Switch global",`<input class="bss-input" type="number" min="1" data-global="switchId" value="${N(g.switchId,62)}">`):""}<label class="bss-check"><input type="checkbox" data-global="allowChainCalls" ${g.allowChainCalls?"checked":""}> Permitir cadenas SOS en salvajes globales</label><label class="bss-check"><input type="checkbox" data-global="allowSOSContinuation" ${g.allowSOSContinuation?"checked":""}> Permitir que un SOS continúe la cadena si el caller cae</label><span class="bss-note">Al continuar la cadena, el SOS superviviente usa la pool/perfil del caller original para que una pool mixta no corte el shiny hunt.</span>${this.field("Máximo de refuerzos SOS simultáneos",`<input class="bss-input" type="number" min="1" max="2" data-global="maxSimultaneousSOS" value="${Math.max(1,Math.min(2,N(g.maxSimultaneousSOS,1)))}"><span class="bss-note">1 = caller + 1 SOS · 2 = caller + hasta 2 SOS simultáneos.</span>`)}${this.field("Nivel de los SOS globales",`<select class="bss-select" data-global="levelMode"><option value="zone" ${S(g.levelMode||"zone")==="zone"?"selected":""}>Salvajes de la zona actual</option><option value="range" ${S(g.levelMode||"zone")==="range"?"selected":""}>Custom · intervalo</option><option value="fixed" ${S(g.levelMode||"zone")==="fixed"?"selected":""}>Custom · nivel fijo</option></select><span class="bss-note">${S(g.levelMode||"zone")==="zone"?"Toma el rango real del encounter table del mapa actual.":S(g.levelMode||"zone")==="fixed"?"Todos los SOS globales usan el nivel fijo indicado.":"Usa el intervalo definido abajo para cualquier SOS global."}</span>`)}${S(g.levelMode||"zone")==="range"?this.field("Intervalo custom global",`<div class="bss-level-range"><input class="bss-input" type="number" min="1" max="100" data-global="levelMin" placeholder="Caller" value="${g.levelMin==null?"":E(g.levelMin)}"><span>–</span><input class="bss-input" type="number" min="1" max="100" data-global="levelMax" placeholder="Caller" value="${g.levelMax==null?"":E(g.levelMax)}"></div>`):S(g.levelMode||"zone")==="fixed"?this.field("Nivel fijo custom global",`<input class="bss-input" type="number" min="1" max="100" data-global="levelFixed" placeholder="Caller" value="${g.levelFixed==null?"":E(g.levelFixed)}">`):""}${this.field("Multiplicador shiny",`<input class="bss-input" type="number" min="1" max="99" data-global="shinyMultiplier" value="${N(g.shinyMultiplier,1)}">`)}<div class="bss-reqbox"><div class="bss-reqhead"><b>Requisitos globales</b><button class="bss-btn small" data-act="add-global-requirement">＋ Requisito</button></div>${A(g.requirements).map((r,i)=>`<div class="bss-reqrow"><select class="bss-select" data-global-req-type="${i}">${globalReqTypes.map(([id,n])=>`<option value="${id}" ${r.type===id?"selected":""}>${E(n)}</option>`).join("")}</select>${["switch_on","switch_off","variable_min","variable_max","variable_equals"].includes(r.type)?`<input class="bss-input mini" type="number" min="1" data-global-req-id="${i}" value="${N(r.id,1)}" title="ID">`:""}${!["day","night"].includes(r.type)?`<input class="bss-input mini" type="number" data-global-req-value="${i}" value="${N(r.value,0)}" title="Valor">`:""}<button class="bss-btn small danger" data-global-req-remove="${i}">×</button></div>`).join("")||`<small class="bss-note">Sin requisitos globales.</small>`}</div>`);
    const cards=filtered.map(p=>{const key=`${p.species}:${N(p.form)}`,checked=this.sosSelected.has(key),pool=A(p.pool),req=A(p.requirements),preview=pool.slice(0,4);return `<div class="bss-sosprofile-tile ${checked?"selected":""}"><div class="bss-prof"><input type="checkbox" data-sos-select="${E(key)}" ${checked?"checked":""}><span class="bss-icon ph" data-sos-icon="${E(key)}">?</span><div class="grow"><b>${E(p.species)}${N(p.form)?` · Form ${N(p.form)}`:""}</b><small>${pool.length} aliado${pool.length===1?"":"s"}</small></div></div><div class="bss-tile-rates"><label class="bss-mini-field">Llama % <b data-profile-rate-view="${E(key)}">${N(p.callRate,0)}%</b><input class="bss-input mini" type="number" min="0" max="100" data-profile-rate="${E(key)}" value="${N(p.callRate,0)}"></label><label class="bss-mini-field">Ayuda % <b data-profile-answer-view="${E(key)}">${N(p.answerRate,100)}%</b><input class="bss-input mini" type="number" min="0" max="100" data-profile-answer="${E(key)}" value="${N(p.answerRate,100)}"></label></div><div class="bss-pool-preview compact"><div class="bss-pool-preview-icons">${preview.map((x,i)=>`<span class="bss-icon ph" data-global-pool-icon="${E(key)}|${i}" title="${E(typeof x==="string"?x:x.species)}">?</span>`).join("")}${pool.length>preview.length?`<span class="bss-pool-more">+${pool.length-preview.length}</span>`:""}</div><button class="bss-btn small" data-open-sos-pool="${E(key)}">Pool (${pool.length})</button></div><details class="bss-tile-req"><summary>Requisitos (${req.length})</summary><div class="bss-reqbox"><div class="bss-reqhead"><small class="bss-note">Condiciones de este caller</small><button class="bss-btn small" data-add-requirement="${E(key)}">＋ Requisito</button></div>${req.map((r,i)=>`<div class="bss-reqrow"><select class="bss-select" data-req-type="${E(key)}|${i}">${reqTypes.map(([id,n])=>`<option value="${id}" ${r.type===id?"selected":""}>${E(n)}</option>`).join("")}</select>${["switch_on","switch_off","variable_min","variable_max","variable_equals"].includes(r.type)?`<input class="bss-input mini" type="number" min="1" data-req-id="${E(key)}|${i}" value="${N(r.id,1)}" title="ID">`:""}${!["day","night"].includes(r.type)?`<input class="bss-input mini" type="number" data-req-value="${E(key)}|${i}" value="${N(r.value,0)}" title="Valor">`:""}<button class="bss-btn small danger" data-remove-requirement="${E(key)}|${i}">×</button></div>`).join("")||`<small class="bss-note">Sin requisitos.</small>`}</div></details></div>`}).join("")||`<div class="bss-empty">No hay perfiles SOS asignados. Usa “Asignar especie” o “Importar”.</div>`;
    this.body.innerHTML=`<section class="bss-sosstudio"><div class="bss-libhead"><input class="bss-search" data-sos-search placeholder="Buscar asignaciones activas…" value="${E(this.sosSearch)}"><button class="bss-btn primary" data-act="add-sos-profile">＋ Asignar especie</button><button class="bss-btn primary" data-act="import-sos-library">⇩ Importar</button><button class="bss-btn" data-act="select-visible-sos">Seleccionar visibles</button><button class="bss-btn" data-act="clear-sos-selection" ${this.sosSelected.size?"":"disabled"}>Limpiar selección</button><button class="bss-btn danger" data-act="delete-selected-sos" ${this.sosSelected.size?"":"disabled"}>Eliminar seleccionados</button><button class="bss-btn" data-act="back-library">← Battles</button></div><div class="bss-sosgrid"><div>${globalPanel}</div><div class="bss-profiles"><div class="bss-profile-title"><div><b>Asignaciones SOS usadas por el juego</b><p class="bss-note">${assigned.length} perfiles activos · vista compacta en grid. Abre cada Pool en su propia ventana.</p></div></div><div class="bss-profile-grid">${cards}</div></div></div></section>`;this.hydrateSOSIcons();
  }
  profile(species,form){return A(this.sosGlobal.overrides).find(p=>p.species===U(species)&&N(p.form)===N(form))||null;}
  ensureProfile(species,form){let p=this.profile(species,form);if(!p){p={species:U(species),form:N(form),callRate:9,answerRate:100,requirements:[],pool:[{species:U(species),form:N(form),weight:100,requirements:[]}]};this.sosGlobal.overrides.push(p);}return p;}
  deferRender(fn){if(this.renderTimer)clearTimeout(this.renderTimer);this.renderTimer=setTimeout(()=>{this.renderTimer=null;try{fn();}catch(e){this.toast(S(e&&e.message||e),true);}},80);}
  async setSOSImportSource(id){this.sosImportSource=S(id||"sm_usum");this.sosGlobal.activeDataset=this.sosImportSource;this.sosImportGroup="all";this.sosImportSearch="";await this.loadSOSCatalog();this.renderSOSImporter();}
  sosImporterGroups(){const catalog=this.sosCatalog||{},counts=new Map();A(catalog.examples).forEach(ex=>{const ids=[S(ex&&ex.sourceGroup),...A(ex&&ex.sourceGroups).map(S)].filter(Boolean);[...new Set(ids)].forEach(id=>counts.set(id,(counts.get(id)||0)+1));});return A(catalog.groups).map(g=>Object.assign({},g,{resultCount:counts.get(S(g.id))||0})).filter(g=>g.resultCount>0);}
  sosImporterRows(){const catalog=this.sosCatalog||{},q=L(S(this.sosImportSearch).trim());let group=S(this.sosImportGroup||"all"),rows=A(catalog.examples);if(q)rows=rows.filter(x=>L(S(x.name)+" "+this.catalogEntityLabel(x.caller)+" "+S(x.caller&&x.caller.species)+" "+A(x.pool).map(y=>`${this.catalogEntityLabel(y)} ${S(y&&y.species||y)}`).join(" ")+" "+S(x.note)+" "+S(x.canonLevel)+" "+S(x.relationType)).includes(q));if(group!=="all"){const scoped=rows.filter(x=>S(x.sourceGroup)===group||A(x.sourceGroups).includes(group));if(scoped.length)rows=scoped;else{group="all";this.sosImportGroup="all";}}return rows;}
  refreshSOSImporterList(modal){modal=modal||this.root.querySelector('[data-sos-import-modal]');if(!modal)return;const beforeGroup=S(this.sosImportGroup||"all"),rows=this.sosImporterRows(),shown=rows.slice(0,300),summary=modal.querySelector('[data-sos-import-summary]'),list=modal.querySelector('[data-sos-import-list]');if(beforeGroup!==this.sosImportGroup){const sel=modal.querySelector('[data-sos-import-group]');if(sel)sel.value=this.sosImportGroup;}if(summary){const note=this.sosImportSource==="pokerogue"?"PokéRogue: cada caller conserva la misma especie como opción y recupera variedad con familia + vecinos legales de su mismo encounter pool; el encounter real sigue dependiendo del CURRENT_ENCOUNTER_POOL.":this.sosImportSource==="sm_usum"?"Solo SOS reales/curados de SM y USUM. No se leen perfiles de compatibilidad de generaciones posteriores.":this.sosImportSource==="legends_za_mega_dimension"?"Mega Dimension: Hyperspace distingue familia, cluster, relación canónica, Rogue Mega, rivalidad y lore.":"Se priorizan familias/manadas respaldadas por el juego; no se generan tarjetas de misma especie solo para rellenar.";summary.textContent=`${rows.length} callers únicos · ${note} Entradas repetidas del mismo caller se fusionan en una sola pool; legendarios, míticos y Ultraentes quedan fuera del importador.`;}if(!list)return;if(modal._bssSOSIconObserver){try{modal._bssSOSIconObserver.disconnect()}catch(_){}modal._bssSOSIconObserver=null;}list.innerHTML=shown.map(ex=>{const pool=A(ex.pool),more=Math.max(0,pool.length-6),callerLabel=this.catalogEntityLabel(ex.caller);return `<div class="bss-import-card"><span class="bss-import-caller bss-icon ph" data-import-caller-icon="${E(ex.id)}">?</span><div class="bss-import-info"><b>${E(callerLabel||ex.name)}</b><small>${E(ex.name)}</small><small>${E(ex.canonLevel||"")} · ${E(ex.relationType||"")}</small><div class="bss-import-allies">${pool.slice(0,6).map((p,i)=>`<span class="bss-import-ally bss-icon ph" data-import-ally-icon="${E(ex.id)}|${i}" title="${E(this.catalogEntityLabel(p))}">?</span>`).join("")}${more?`<small>+${more}</small>`:""}</div></div><button class="bss-btn small primary" data-assign-sos-example="${E(ex.id)}">Importar</button></div>`}).join("")||`<div class="bss-empty">No hay resultados.</div>`;this.hydrateSOSImporterIcons(modal,shown);}
  renderSOSPoolModal(){
    const key=S(this.sosPoolModalKey);if(!key)return;const cut=key.lastIndexOf(":"),p=this.profile(key.slice(0,cut),N(key.slice(cut+1)));if(!p){this.sosPoolModalKey="";return;}const old=this.root.querySelector("[data-sos-pool-modal]");if(old)this.safeRemove(old);const pool=A(p.pool),sum=pool.reduce((n,x)=>n+Math.max(0,N(typeof x==="string"?100:x.weight,100)),0)||1,modal=document.createElement("div");modal.className="bss-modalback";modal.dataset.sosPoolModal="1";modal.innerHTML=`<div class="bss-modal bss-pool-modal"><div class="bss-modalhead"><div><b>Pool SOS · ${E(p.species)}${N(p.form)?` · Form ${N(p.form)}`:""}</b><small class="bss-note">Edita aliados y pesos sin alargar la lista principal.</small></div><div class="bss-spacer"></div><button class="bss-btn primary" data-add-global-pool="${E(key)}">＋ Slot</button><button class="bss-btn" data-act="close-sos-pool">✕</button></div><div class="bss-modalbody"><div class="bss-poollist expanded">${pool.map((raw,i)=>{const x=typeof raw==="string"?{species:raw,form:0,weight:100}:raw,pc=(Math.max(0,N(x.weight,100))*100/sum).toFixed(1);return `<div class="bss-poolrow"><span class="bss-icon ph" data-global-pool-icon="${E(key)}|${i}">?</span><b>${E(x.species)}${N(x.form)?` · F${N(x.form)}`:""}</b><label>Peso <input class="bss-input mini" type="number" min="0" data-profile-pool-weight="${E(key)}|${i}" value="${N(x.weight,100)}"></label><small data-profile-pool-percent="${E(key)}|${i}">${pc}%</small><button class="bss-btn small danger" data-global-pool-remove="${E(key)}|${i}">×</button></div>`}).join("")||`<div class="bss-empty">Sin aliados. Pulsa “＋ Slot”.</div>`}</div></div></div>`;this.root.appendChild(modal);this.hydrateSOSIcons(modal);
  }
  renderSOSImporter(options){
    if(!this.sosImportOpen)return;options=options||{};const old=this.root.querySelector('[data-sos-import-modal]');if(old)this.safeRemove(old);const catalog=this.sosCatalog||{},groups=this.sosImporterGroups();let group=S(this.sosImportGroup||"all");if(group!=="all"&&!groups.some(g=>S(g.id)===group)){group="all";this.sosImportGroup="all";}const sourceName=(SOS_DATASETS.find(x=>x.id===this.sosImportSource)||{}).name||this.sosImportSource,tabName=id=>id==="sm_usum"?"SM / USUM":id==="legends_za"?"Z-A":id==="legends_arceus"?"Arceus":id==="legends_za_mega_dimension"?"Z-A Mega Dimensions":"PokéRogue";
    const modal=document.createElement('div');modal.className='bss-modalback';modal.dataset.sosImportModal='1';modal.innerHTML=`<div class="bss-modal bss-import-modal"><div class="bss-modalhead"><b>Importar SOS / refuerzos</b><span class="bss-note">${E(sourceName)}</span><div class="bss-spacer"></div><button class="bss-btn" data-act="close-sos-import">✕</button></div><div class="bss-import-tabs">${SOS_DATASETS.map(x=>`<button class="bss-btn ${this.sosImportSource===x.id?"active":""}" data-import-source="${E(x.id)}">${E(tabName(x.id))}</button>`).join("")}</div><div class="bss-import-tools"><input class="bss-search" data-sos-import-search placeholder="Buscar especie, aliado o relación…" value="${E(this.sosImportSearch)}">${groups.length?`<select class="bss-select" data-sos-import-group><option value="all">${this.sosImportSource==="pokerogue"?"Todos los biomas":this.sosImportSource==="legends_za_mega_dimension"?"Todas las categorías":"Todas las zonas"}</option>${groups.map(g=>`<option value="${E(g.id)}" ${group===S(g.id)?"selected":""}>${E(g.name||g.id)} · ${N(g.resultCount,0)}</option>`).join("")}</select>`:""}</div><div class="bss-import-summary" data-sos-import-summary></div><div class="bss-import-list" data-sos-import-list></div></div>`;this.root.appendChild(modal);this.refreshSOSImporterList(modal);if(options.focusSearch){setTimeout(()=>{const x=modal.querySelector('[data-sos-import-search]');if(x){x.focus();const p=Number(options.selectionStart);if(Number.isFinite(p)){try{x.setSelectionRange(p,p)}catch(_){}}}},0);}
  }
  async hydrateSOSImporterIcons(modal,rows){const byId=new Map(rows.map(x=>[S(x.id),x])),loadEl=async el=>{if(!el||!el.isConnected)return;let raw=null;if(el.dataset.importCallerIcon){const ex=byId.get(S(el.dataset.importCallerIcon));raw=ex&&ex.caller;}else{const code=S(el.dataset.importAllyIcon),cut=code.lastIndexOf('|'),ex=byId.get(code.slice(0,cut)),i=N(code.slice(cut+1));raw=ex&&A(ex.pool)[i];}if(!raw)return;const res=this.resolveCatalogEntity(raw);if(!res)return;const asset=findPokemonIcon(this.source,res.species,res.form),url=await this.frameUrl(asset,"import:"+res.species+":"+res.form);if(url&&el.isConnected){const img=document.createElement('img');img.className=el.className.replace(' ph','');img.src=url;for(const a of el.attributes){if(a.name==='title')img.setAttribute('title',a.value);}if(el.parentNode)el.parentNode.replaceChild(img,el);}};const els=[...modal.querySelectorAll('[data-import-caller-icon],[data-import-ally-icon]')];if(!els.length)return;const list=modal.querySelector('[data-sos-import-list]');if(typeof IntersectionObserver!=="undefined"&&list){const queue=[],queued=new Set();let running=false;const flush=async()=>{if(running)return;running=true;while(queue.length){const batch=queue.splice(0,32);await mapLimit(batch,10,loadEl);}running=false;};const observer=new IntersectionObserver(entries=>{entries.forEach(entry=>{if(!entry.isIntersecting)return;const el=entry.target;observer.unobserve(el);if(!queued.has(el)){queued.add(el);queue.push(el);}});flush();},{root:list,rootMargin:"360px 0px",threshold:0.01});modal._bssSOSIconObserver=observer;els.forEach(el=>observer.observe(el));return;}await mapLimit(els,10,loadEl);}
  async hydrateSOSIcons(scope){scope=scope||this.body;const els=[...scope.querySelectorAll("[data-sos-icon],[data-global-pool-icon]")],loadEl=async el=>{if(!el||!el.isConnected)return;let sp="",form=0;if(el.dataset.sosIcon){[sp,form]=S(el.dataset.sosIcon).split(":");}else{const raw=S(el.dataset.globalPoolIcon),cut=raw.lastIndexOf("|"),key=raw.slice(0,cut),i=N(raw.slice(cut+1)),kc=key.lastIndexOf(":"),p=this.profile(key.slice(0,kc),N(key.slice(kc+1))),x=p&&A(p.pool)[i];if(x){sp=typeof x==="string"?x:x.species;form=typeof x==="string"?0:N(x.form);}}if(!sp)return;const u=await this.frameUrl(findPokemonIcon(this.source,sp,N(form)),"icon:"+sp+":"+form);if(u&&el.isConnected)el.outerHTML=`<img class="bss-icon" src="${E(u)}">`;};if(!els.length)return;if(typeof IntersectionObserver!=="undefined"&&els.length>24){const queue=[],seen=new Set();let running=false;const flush=async()=>{if(running)return;running=true;while(queue.length){const batch=queue.splice(0,24);await mapLimit(batch,10,loadEl);}running=false;},observer=new IntersectionObserver(entries=>{for(const entry of entries){if(!entry.isIntersecting)continue;observer.unobserve(entry.target);if(!seen.has(entry.target)){seen.add(entry.target);queue.push(entry.target);}}flush();},{root:null,rootMargin:"420px 0px",threshold:0.01});els.forEach(el=>observer.observe(el));return;}await mapLimit(els,10,loadEl);}
  async hydrateInspectorIcons(){const els=[...this.body.querySelectorAll("[data-inline-icon],[data-special-icon],[data-battle-pool-icon]")];await mapLimit(els,6,async el=>{let spec="",form=0;if(el.dataset.inlineIcon){const [k,i]=el.dataset.inlineIcon.split(":"),p=this.battle()&&this.battle().teams[k]&&this.battle().teams[k][N(i)];spec=p&&p.species||"";form=p&&p.form||0;}else if(el.dataset.battlePoolIcon!=null){const x=this.battle()&&A(this.battle().sos.pool)[N(el.dataset.battlePoolIcon)];spec=x&&(typeof x==="string"?x:x.species)||"";form=x&&typeof x!=="string"?N(x.form):0;}else{const t=el.dataset.specialIcon,s=this.battle()&&this.battle().sos;spec=t==="sos:primary"?s.primary:s.secondary;}if(!spec)return;const u=await this.frameUrl(findPokemonIcon(this.source,spec,form),"icon:"+spec+":"+form);if(u&&el.isConnected)el.outerHTML=`<img class="bss-icon" src="${E(u)}">`;});}
  async assetUrl(asset){if(!asset||!asset.projectPath)return null;const key=S(asset.projectPath).replace(/\\/g,"/");if(this.assetUrlCache.has(key))return this.assetUrlCache.get(key);if(this.assetUrlPending.has(key))return this.assetUrlPending.get(key);const pending=(async()=>{const u=await imageUrl(this.ctx,asset);if(u)this.assetUrlCache.set(key,u);return u||null;})();this.assetUrlPending.set(key,pending);try{return await pending;}finally{this.assetUrlPending.delete(key);}}
  async battlerRenderInfo(asset,p,side){if(this.renderCompatWarmPromise)try{await this.renderCompatWarmPromise}catch(_){}const key=`${side}|${S(asset&&asset.projectPath)}|${S(p&&p.species)}|${N(p&&p.form)}`;if(this.renderMetaCache.has(key))return this.renderMetaCache.get(key);if(this.renderMetaPending.has(key))return this.renderMetaPending.get(key);const cfg={name:S(asset&&asset.name||p&&p.species||""),projectPath:S(asset&&asset.projectPath||"")},pending=loadBattlerRenderingInfo(this.ctx,cfg,side).catch(()=>({}));this.renderMetaPending.set(key,pending);try{const v=await pending;this.renderMetaCache.set(key,v||{});return v||{};}finally{this.renderMetaPending.delete(key);}}
  async frameUrl(asset,key){if(!asset)return null;const cacheKey=key||asset.projectPath;if(this.frameCache.has(cacheKey))return this.frameCache.get(cacheKey);if(this.framePending.has(cacheKey))return this.framePending.get(cacheKey);const pending=(async()=>{const raw=await this.assetUrl(asset);if(!raw)return null;const out=await new Promise(resolve=>{const im=new Image();im.onload=()=>{try{let sw=im.naturalWidth,sh=im.naturalHeight;if(sw>sh*1.15)sw=Math.min(sh,sw);else if(sh>sw*1.15)sh=Math.min(sw,sh);const c=document.createElement("canvas");c.width=Math.max(1,sw);c.height=Math.max(1,sh);c.getContext("2d").drawImage(im,0,0,sw,sh,0,0,sw,sh);resolve(c.toDataURL("image/png"));}catch(_){resolve(raw)}};im.onerror=()=>resolve(raw);im.src=raw;});this.frameCache.set(cacheKey,out);return out;})();this.framePending.set(cacheKey,pending);try{return await pending;}finally{this.framePending.delete(cacheKey);}}
  pickerResults(){const q=L(this.picker&&this.picker.search||""),all=A(this.source.species),filtered=all.filter(x=>!q||L(`${x.name} ${x.species} ${x.form}`).includes(q));return {all,filtered,rows:filtered.slice(0,320)};}
  pickerBodyHTML(rows,filteredCount,total){return `<div class="bss-pickgrid">${rows.map((x,i)=>`<button class="bss-pick" data-pick-value="${E(x.species)}:${x.form}"><span class="bss-icon ph" data-picker-icon="${i}">?</span><span><b>${E(x.name)}</b><small>${E(x.species)}${x.form?` · Form ${x.form}`:""}</small></span></button>`).join("")}</div>${filteredCount>rows.length?`<p class="bss-note">Showing ${rows.length}. Search filters the complete ${total}-entry project pool.</p>`:""}`;}
  renderPicker(){const {all,filtered,rows}=this.pickerResults();const old=this.root.querySelector("[data-bss-picker-modal]");if(old)this.safeRemove(old);const modal=document.createElement("div");modal.className="bss-modalback bss-picker-modalback";modal.dataset.bssPickerModal="1";modal.innerHTML=`<div class="bss-modal"><div class="bss-modalhead"><b>Select Pokémon</b><input class="bss-search" data-picker-search autofocus placeholder="Search species/form…" value="${E(this.picker.search||"")}"><span class="bss-note" data-picker-count>${all.length} project species/forms · ${filtered.length} matches</span><div class="bss-spacer"></div><button class="bss-btn" data-act="close-picker">Close</button></div><div class="bss-modalbody">${this.pickerBodyHTML(rows,filtered.length,all.length)}</div></div>`;this.root.appendChild(modal);this.hydratePickerIcons(rows,modal);}
  refreshPickerList(){if(!this.picker)return;const modal=this.root.querySelector("[data-bss-picker-modal]");if(!modal)return this.renderPicker();const {all,filtered,rows}=this.pickerResults(),count=modal.querySelector("[data-picker-count]"),body=modal.querySelector(".bss-modalbody");if(count)count.textContent=`${all.length} project species/forms · ${filtered.length} matches`;if(body)body.innerHTML=this.pickerBodyHTML(rows,filtered.length,all.length);this.hydratePickerIcons(rows,modal);}
  async hydratePickerIcons(rows,modal){const els=[...modal.querySelectorAll("[data-picker-icon]")],loadEl=async el=>{if(!el||!el.isConnected)return;const x=rows[N(el.dataset.pickerIcon)];if(!x)return;const u=await this.frameUrl(findPokemonIcon(this.source,x.species,x.form),"icon:"+x.species+":"+x.form);if(u&&el.isConnected)el.outerHTML=`<img class="bss-icon" src="${E(u)}">`;};if(!els.length)return;const root=modal.querySelector(".bss-modalbody");if(typeof IntersectionObserver!=="undefined"&&root){const queue=[],seen=new Set();let running=false;const flush=async()=>{if(running)return;running=true;while(queue.length){const batch=queue.splice(0,28);await mapLimit(batch,10,loadEl);}running=false;},observer=new IntersectionObserver(entries=>{for(const entry of entries){if(!entry.isIntersecting)continue;observer.unobserve(entry.target);if(!seen.has(entry.target)){seen.add(entry.target);queue.push(entry.target);}}flush();},{root,rootMargin:"420px 0px",threshold:0.01});els.forEach(el=>observer.observe(el));return;}await mapLimit(els,10,loadEl);}
  openPicker(target){this.picker={target,search:""};this.render();setTimeout(()=>{const x=this.root.querySelector("[data-picker-search]");if(x)x.focus()},10);}
  pickSpecies(value){if(!this.picker)return;const [species,formRaw]=S(value).split(":"),form=N(formRaw),t=this.picker.target,b=this.battle();if(t==="aura:test"){this.auraTestSpecies=U(species);this.auraTestForm=form;this.picker=null;return this.render();}if(t.startsWith("team:")){const [,key,idx]=t.split(":"),p=b&&b.teams[key]&&b.teams[key][N(idx)];if(p){p.species=U(species);p.form=form;}}else if(t==="sos:pool"){if(b){b.sos.pool=A(b.sos.pool);b.sos.pool.push({species:U(species),form,weight:100,requirements:[],moveMode:"default",moves:[]});}}else if(t.startsWith("sos:replace:")){if(b){const i=N(t.slice("sos:replace:".length)),old=A(b.sos.pool)[i]||{};b.sos.pool[i]={species:U(species),form,weight:Math.max(0,N(old.weight,100)),requirements:A(old.requirements),moveMode:"default",moves:[]};}}else if(t==="sosglobal:addprofile"){const p=this.ensureProfile(species,form),preset=A(this.sosCatalog&&this.sosCatalog.profiles).find(x=>U(x.species)===U(species)&&N(x.form)===form);if(preset){p.callRate=Math.max(0,Math.min(100,N(preset.callRate,9)));p.answerRate=Math.max(0,Math.min(100,N(preset.answerRate,100)));p.pool=A(preset.pool).map(x=>typeof x==="string"?{species:U(x),form:0,weight:100,requirements:[]}:{species:U(x.species),form:N(x.form),weight:N(x.weight,100),requirements:A(x.requirements)}).filter(x=>x.species);if(!p.pool.length)p.pool=[{species:U(species),form,weight:100,requirements:[]}];}this.saveSOSConfigSoon();}else if(t.startsWith("globalpool:")){const raw=t.slice("globalpool:".length),cut=raw.lastIndexOf(":"),sp=cut>=0?raw.slice(0,cut):raw,f=cut>=0?N(raw.slice(cut+1)):0,p=this.ensureProfile(sp,f);p.pool=A(p.pool);p.pool.push({species:U(species),form,weight:100,requirements:[],moveMode:"default",moves:[]});this.saveSOSConfigSoon();}this.picker=null;if(b)this.touch();this.render();}
  catalogEntityLabel(raw){if(typeof raw==="string")raw={species:raw,form:0};raw=raw&&typeof raw==="object"?raw:{};const resolved=this.resolveCatalogEntity(raw),sp=resolved?resolved.species:U(raw.species),form=resolved?N(resolved.form):N(raw.form),rec=findSpecies(this.source,sp,form),name=S(rec&&rec.name),base=name&&C(name)!==C(sp)?`${name} · ${sp}`:sp,tag=S(raw.formTag);return base+(tag?` · ${tag}`:(form?` · Forma ${form}`:""));}
  resolveCatalogEntity(raw){if(typeof raw==="string")raw={species:raw,form:0};raw=raw&&typeof raw==="object"?raw:{};const wanted=U(raw.species),source=A(this.source.species);if(!wanted)return null;let canonical=wanted,forms=source.filter(x=>U(x.species)===wanted);if(!forms.length){const compact=C(wanted),compactHit=source.find(x=>C(x.species)===compact);if(compactHit){canonical=U(compactHit.species);forms=source.filter(x=>U(x.species)===canonical);}}if(!forms.length){const alias=this.resolveCatalogSpecies(wanted);return alias;}canonical=U((forms[0]&&forms[0].species)||canonical);const explicit=N(raw.form);if(explicit>0){const hit=forms.find(x=>N(x.form)===explicit);if(hit)return {species:canonical,form:N(hit.form)};}const tag=L(raw.formTag);if(tag){const aliases={hisui:["hisui","hisuian"],alola:["alola","alolan"],galar:["galar","galarian"],paldea:["paldea","paldean"],unova:["unova","unovan"],"white-striped":["white striped","white-striped"]},terms=aliases[tag]||[tag];let hit=forms.find(x=>terms.some(t=>L(`${x.formName||""} ${x.name||""}`).includes(t)));if(!hit&&tag==="unova")hit=forms.find(x=>N(x.form)===0);if(!hit)hit=forms.find(x=>N(x.form)>0);if(hit)return {species:canonical,form:N(hit.form)};}const base=forms.find(x=>N(x.form)===0)||forms[0];return {species:canonical,form:N(base.form)};}
  resolveCatalogSpecies(raw){const wanted=U(raw),source=A(this.source.species);let exact=source.find(x=>U(x.species)===wanted&&N(x.form)===0)||source.find(x=>U(x.species)===wanted);if(!exact){const compact=C(wanted);exact=source.find(x=>C(x.species)===compact&&N(x.form)===0)||source.find(x=>C(x.species)===compact);}if(exact)return {species:U(exact.species),form:N(exact.form)};const regional=[["ALOLA_","alola"],["GALAR_","galar"],["HISUI_","hisui"],["PALDEA_","paldea"]];for(const pair of regional){const pre=pair[0],tag=pair[1];if(wanted.startsWith(pre))return this.resolveCatalogEntity({species:wanted.slice(pre.length),formTag:tag});}const aliases={NIDORAN_F:"NIDORANFE",NIDORAN_M:"NIDORANMA",BATTLE_BOND_GRENINJA:"GRENINJA",BLOODMOON_URSALUNA:"URSALUNA",ETERNAL_FLOETTE:"FLOETTE"};const alias=aliases[wanted];if(alias){exact=source.find(x=>U(x.species)===alias);if(exact)return {species:U(exact.species),form:N(exact.form)};}return null;}
  importSOSExampleToAssignments(id){const ex=A(this.sosCatalog&&this.sosCatalog.examples).find(x=>S(x.id)===S(id));if(!ex)return;const source=A(this.source.species),available=new Map(source.map(x=>[`${U(x.species)}:${N(x.form)}`,x])),speciesAvailable=new Set(source.map(x=>U(x.species))),callerRaw=U(ex.caller&&ex.caller.species),resolvedCaller=this.resolveCatalogEntity(ex.caller||{species:callerRaw});if(!resolvedCaller){this.toast(`No se puede asignar ${callerRaw}: la especie/forma no existe en este proyecto.`,true);return;}const callerSp=resolvedCaller.species,callerForm=resolvedCaller.form,p=this.ensureProfile(callerSp,callerForm);p.callRate=Math.max(0,Math.min(100,N(ex.callRate,100)));p.answerRate=Math.max(0,Math.min(100,N(ex.answerRate,100)));p.requirements=A(ex.requirements).map(r=>Object.assign({},r));p.pool=A(ex.pool).map((raw,i)=>{const x=typeof raw==="string"?{species:U(raw),form:0,weight:A(ex.weights)[i]||100,requirements:[]}:raw,res=this.resolveCatalogEntity(x);if(!res)return null;return {species:res.species,form:res.form,weight:Math.max(0,N(x.weight,100)),requirements:A(x.requirements).map(r=>Object.assign({},r))};}).filter(Boolean);if(!p.pool.length)p.pool=[{species:p.species,form:p.form,weight:100,requirements:[]}];this.sosSelected.clear();this.sosSelected.add(`${p.species}:${N(p.form)}`);this.saveSOSConfigSoon();this.renderSOSStudio();this.toast(`Asignado al juego: ${p.species}${p.form?` · Forma ${p.form}`:""} (${this.sosCatalog.name||"plantilla"})`);}
  importSOSExample(id){const ex=A(this.sosCatalog&&this.sosCatalog.examples).find(x=>S(x.id)===S(id));if(!ex)return;const sourceSpecies=A(this.source.species),available=new Set(sourceSpecies.map(x=>U(x.species))),fallback=sourceSpecies[0],resolvedCaller=this.resolveCatalogEntity(ex.caller);let caller=resolvedCaller?resolvedCaller.species:(fallback&&U(fallback.species)||"PIKACHU"),callerForm=resolvedCaller?resolvedCaller.form:0;let pool=A(ex.pool).map((x,i)=>{const raw=typeof x==="string"?{species:U(x),form:0,weight:A(ex.weights)[i]||100,requirements:[]}:x,res=this.resolveCatalogEntity(raw);if(!res)return null;return {species:res.species,form:res.form,weight:N(raw.weight,100),requirements:A(raw.requirements)};}).filter(Boolean);if(!pool.length)pool=[{species:caller,form:callerForm,weight:100,requirements:[]}];const b=makeBlueprint(ex.name||`${this.sosCatalog.name||"SOS"} Example`);b.key=this.uniqueKey(b.name,b.id);b.groupId=this.activeGroup||"wild_main";b.category="Ejemplo SOS";b.setup.kind="wild";b.setup.formation="1v1";b.teams.foes=[Object.assign(makePokemon(caller,N(ex.caller&&ex.caller.level,30)),{form:callerForm})];const test=available.has("EEVEE")?"EEVEE":(fallback&&U(fallback.species)||"PIKACHU");b.teams.testPlayer=[makePokemon(test,55)];b.sos.enabled=true;b.sos.initialCall=ex.initialCall!==false;b.sos.automaticCalls=false;b.sos.allowAdditionalCalls=false;b.sos.allowRecursiveCalls=false;b.sos.maxSimultaneousSOS=1;b.sos.summonsPerCall=1;b.sos.allySelectionMode="random";b.sos.callRound=1;b.sos.callRate=Math.max(1,Math.min(100,N(ex.callRate,100)));b.sos.answerRate=Math.max(0,Math.min(100,N(ex.answerRate,100)));b.sos.levelMode="fixed";b.sos.levelFixed=Math.max(1,Math.min(100,N(ex.caller&&ex.caller.level,30)));b.sos.levelMin=null;b.sos.levelMax=null;b.sos.pool=pool;this.studio.blueprints.push(b);this.activeId=b.id;this.screen="editor";this.section="sos";this.touch();this.render();this.toast(`Importado: ${b.name}`);}
  async testBattle(id){const b=this.studio.blueprints.find(x=>x.id===id);if(!b)return;this.lastTestKey=b.key;await this.save(true);try{await this.ctx.fs.projectMkdir(DATA_DIR);await this.ctx.fs.writeProjectFile(CONTROL_FILE,JSON.stringify({action:"test",key:b.key,requestedAt:Date.now()},null,2));this.toast("Test queued. Open the game if it is not running.");}catch(e){this.toast("Could not queue test: "+S(e&&e.message||e),true);}}
  updateFullscreenUi(){if(!this.root)return;this.root.querySelectorAll('[data-act="fullscreen"]').forEach(b=>{b.classList.toggle("active",this.fullscreenActive);b.setAttribute("aria-pressed",this.fullscreenActive?"true":"false");b.textContent=this.fullscreenActive?"↙ Exit fullscreen":"⛶ Fullscreen";b.title=this.fullscreenActive?"Exit fullscreen · F11 / Esc":"Fullscreen · F11";});}
  refreshAfterFullscreenChange(){requestAnimationFrame(()=>{this.render();requestAnimationFrame(()=>{try{this.preview&&this.preview.draw();}catch(_){}});});}
  enterFullscreenMode(){if(this.fullscreenActive||!this.root||!document.body)return false;this.fullscreenPreviousScroll={x:Number(window.scrollX||0),y:Number(window.scrollY||0)};this.fullscreenPlaceholder=document.createComment("Battle Scene Studio fullscreen home");if(this.root.parentNode)this.root.parentNode.insertBefore(this.fullscreenPlaceholder,this.root);document.body.appendChild(this.root);this.fullscreenActive=true;this.root.classList.add("bss-fullscreen-active");document.body.classList.add("bss-fullscreen-lock");this.updateFullscreenUi();this.refreshAfterFullscreenChange();try{this.root.focus({preventScroll:true});}catch(_){}this.toast("Vista ampliada estilo BAS · F11 o Esc para salir");return true;}
  exitFullscreenMode(options={}){if(!this.fullscreenActive)return false;this.root.classList.remove("bss-fullscreen-active");document.body.classList.remove("bss-fullscreen-lock");if(this.fullscreenPlaceholder&&this.fullscreenPlaceholder.parentNode)this.fullscreenPlaceholder.parentNode.replaceChild(this.root,this.fullscreenPlaceholder);else if(this.host)this.host.appendChild(this.root);this.fullscreenPlaceholder=null;this.fullscreenActive=false;this.updateFullscreenUi();if(!options.skipRefresh)this.refreshAfterFullscreenChange();try{window.scrollTo(this.fullscreenPreviousScroll.x||0,this.fullscreenPreviousScroll.y||0);}catch(_){}return true;}
  toggleFullscreenMode(){return this.fullscreenActive?this.exitFullscreenMode():this.enterFullscreenMode();}
  closeEditorFromFullscreen(){if(!this.fullscreenActive)return false;this.exitFullscreenMode({skipRefresh:true});try{const ui=this.ctx&&this.ctx.ui;if(ui&&typeof ui.closePanel==="function"){ui.closePanel("battle-scene-studio.main");return true;}if(ui&&typeof ui.hidePanel==="function"){ui.hidePanel("battle-scene-studio.main");return true;}}catch(_){}return false;}
  onKeyDown(e){if(e&&e.key==="F11"){e.preventDefault();e.stopPropagation();if(typeof e.stopImmediatePropagation==="function")e.stopImmediatePropagation();this.toggleFullscreenMode();return;}if(this.screen==="aura"&&e&&e.ctrlKey&&["1","2","3","4","5","6"].includes(e.key)){e.preventDefault();this.auraStudioTab=["appearance","particles","motion","outline","intro","camera"][Number(e.key)-1];this.renderAuraStudio();return;}if(this.fullscreenActive&&e&&e.key==="Escape"){e.preventDefault();e.stopPropagation();if(typeof e.stopImmediatePropagation==="function")e.stopImmediatePropagation();this.exitFullscreenMode();}}

  renderGlobalSettingsModal(){const old=this.root.querySelector("[data-global-settings-modal]");if(old)this.safeRemove(old);if(!this.globalSettingsOpen)return;const g=this.studio.global||{},groups=A(this.studio.groups),modal=document.createElement("div"),ebdxBackdrops=this.ebdxBackdropChoices(false);modal.className="bss-modal bss-global-settings-modal";modal.dataset.globalSettingsModal="1";modal.innerHTML=`<div class="bss-modal-card bss-global-settings-card"><div class="bss-modal-head"><div><b>Ajustes globales de BSS</b><small>Valores compartidos por todos los Blueprints. Los overrides específicos siguen dentro de cada combate.</small></div><button class="bss-btn" data-act="close-global-settings">Cerrar</button></div><section class="bss-global-settings-section"><h3>Bases de battleback</h3><label class="bss-check"><input type="checkbox" data-studio-global="battleBasesEnabled" ${g.battleBasesEnabled!==false?"checked":""}> Mostrar bases por defecto en todos los combates</label><p class="bss-note">Se aplica también a combates normales fuera de Boss/Custom. Un Blueprint puede heredarlo, forzar las bases o esconderlas desde Scene / Audio.</p></section><section class="bss-global-settings-section"><h3>BattleBox / Databox</h3>${this.field("Tipo de animación",`<select class="bss-select" data-studio-global="battleBoxAnimation"><option value="pop" ${S(g.battleBoxAnimation)==="pop"?"selected":""}>Popear</option><option value="slide" ${!["pop","fade"].includes(S(g.battleBoxAnimation))?"selected":""}>Slide</option><option value="fade" ${S(g.battleBoxAnimation)==="fade"?"selected":""}>Fade in/out</option></select>`)}<p class="bss-note">Slide se ejecuta en la capa de animación de la BattleBox, sin modificar PokemonDataBox. Se aplica por igual a Player y Foe.</p></section><section class="bss-global-settings-section"><h3>Cámara / fondos</h3>${this.field("Estilo global",`<select class="bss-select" data-studio-global="cameraStyle"><option value="project" ${S(g.cameraStyle)!=="ebdx"?"selected":""}>Proyecto / Essentials</option><option value="ebdx" ${S(g.cameraStyle)==="ebdx"?"selected":""}>EBDX</option></select>`)}${this.field("Escenario EBDX global",`<select class="bss-select" data-studio-global="ebdxBackdrop">${ebdxBackdrops.map(x=>`<option value="${E(x.id)}" ${S(g.ebdxBackdrop||"Auto")===x.id?"selected":""}>${E(x.label)}</option>`).join("")}</select>`)}<div class="bss-mini-grid">${["sky","clouds","trees","grass","water","lights","decor","particles"].map(k=>`<label class="bss-check"><input type="checkbox" data-studio-ebdx-element="${k}" ${(g.ebdxElements||{})[k]!==false?"checked":""}> ${E({sky:"Cielo",clouds:"Nubes",trees:"Árboles",grass:"Hierba",water:"Agua",lights:"Luces",decor:"Decoración",particles:"Partículas"}[k])}</label>`).join("")}</div><p class="bss-note">EBDX usa el room y las coordenadas de su compositor original, con movimiento ambiental de cámara Gen 5. BAS toma autoridad temporal durante sus acciones para evitar dobles transformaciones.</p><button class="bss-btn primary" type="button" data-act="open-ebdx-studio">Abrir EBDX Studio</button></section><section class="bss-global-settings-section"><h3>Organización</h3>${this.field("Librería principal",`<select class="bss-select" data-studio-global="mainGroupId">${groups.map(x=>`<option value="${E(x.id)}" ${S(x.id)===S(g.mainGroupId||"wild_main")?"selected":""}>${E(x.name)}</option>`).join("")}</select>`)}</section></div>`;this.root.appendChild(modal);}
  assetPickerRows(kind){if(S(kind)==="audio")return A(this.source&&this.source.bgmFiles);const rows=A(this.source&&this.source.allGraphics);if(rows.length)return rows;const fall=A(this.source&&this.source.battlebacks).concat(A(this.source&&this.source.auraGraphics)),seen=new Set();return fall.filter(x=>{const k=S(x&&x.projectPath||x&&x.relativePath||x&&x.name);if(!k||seen.has(k))return false;seen.add(k);return true;});}
  assetPickerFolder(row,kind){let path=S(S(kind)==="audio"?(row&&row.projectPath||row&&row.relativePath||row&&row.value||row&&row.name):(row&&row.projectPath||row&&row.relativePath||row&&row.name)).replace(/\\/g,"/");path=path.replace(/^Graphics\//i,"").replace(/^Audio\/BGM\//i,"");const parts=path.split("/").filter(Boolean);return parts.length>1?parts.slice(0,-1).join("/"):"Raíz";}
  assetPickerFolders(){if(!this.assetPicker)return [];const set=new Set(this.assetPickerRows(this.assetPicker.kind).map(x=>this.assetPickerFolder(x,this.assetPicker.kind)));return [...set].sort((a,b)=>a.localeCompare(b,undefined,{numeric:true,sensitivity:"base"}));}
  assetRowKey(row){return S(row&&row.projectPath||row&&row.relativePath||row&&row.value||row&&row.name).replace(/\\/g,"/");}
  currentAssetTargetValue(target){target=S(target);const b=this.battle();if(target.startsWith("environment.")&&b&&b.environment)return S(b.environment[target.slice(12)]);return "";}
  openAssetPicker(target,kind="graphic"){kind=S(kind)==="audio"?"audio":"graphic";const current=this.currentAssetTargetValue(target);let selectedKey="";if(kind==="audio"&&current){const row=this.assetPickerRows("audio").find(x=>this.assetTargetValue(x,"audio")===current);selectedKey=row?this.assetRowKey(row):"";}this.stopAssetAudioPreview(true);this.assetPicker={target:S(target),kind,search:"",folder:"all",selectedKey};this.renderAssetPicker();}
  assetPickerResults(){if(!this.assetPicker)return [];const q=L(this.assetPicker.search),folder=S(this.assetPicker.folder||"all"),kind=this.assetPicker.kind,rows=this.assetPickerRows(kind);return rows.filter(row=>(folder==="all"||this.assetPickerFolder(row,kind)===folder)&&(!q||L(`${S(row&&row.name)} ${S(row&&row.projectPath)} ${S(row&&row.relativePath)} ${S(row&&row.value)}`).includes(q))).slice(0,900);}
  assetPickerSelectedAudioRow(){if(!this.assetPicker||this.assetPicker.kind!=="audio"||!this.assetPicker.selectedKey)return null;const key=S(this.assetPicker.selectedKey);return this.assetPickerRows("audio").find(x=>this.assetRowKey(x)===key)||null;}
  assetPickerGridHTML(){const rows=this.assetPickerResults(),audio=this.assetPicker&&this.assetPicker.kind==="audio";if(audio){const selected=S(this.assetPicker.selectedKey);return `<div class="bss-audio-list">${rows.map((row,i)=>{const key=this.assetRowKey(row),path=S(row.projectPath||row.relativePath||row.value||row.name),name=S(row.name||path.split("/").pop()||row.value||"BGM");return `<button class="bss-audio-row ${selected===key?"active":""}" type="button" data-asset-audio-select="${i}"><span class="bss-audio-note">♪</span><span class="bss-audio-copy"><b>${E(name)}</b><small>${E(path.replace(/^Audio\/BGM\//i,""))}</small></span></button>`;}).join("")||`<div class="bss-empty">No hay BGM que coincidan con la búsqueda.</div>`}</div>`;}return rows.map((row,i)=>`<button class="bss-asset-tile" type="button" data-asset-pick="${i}"><span class="bss-asset-thumb"><img data-asset-thumb="${i}" alt=""></span><b>${E(row.name||row.value||row.projectPath||"Asset")}</b><small>${E(row.relativePath||row.projectPath||row.value||"")}</small></button>`).join("")||`<div class="bss-empty">No hay resultados en esta carpeta.</div>`;}
  async hydrateAssetPickerImages(){const modal=this.root.querySelector("[data-asset-picker-modal]");if(!modal||!this.assetPicker||this.assetPicker.kind!=="graphic")return;const rows=this.assetPickerResults();for(const img of modal.querySelectorAll("img[data-asset-thumb]")){const i=N(img.dataset.assetThumb,-1),row=rows[i];if(!row)continue;try{const url=await this.assetUrl({projectPath:S(row.projectPath||row.relativePath||row.name)});if(url&&img.isConnected)img.src=url;}catch(_){}}}
  refreshAssetPickerList(){const modal=this.root.querySelector("[data-asset-picker-modal]");if(!modal||!this.assetPicker)return;const grid=modal.querySelector("[data-asset-results]"),count=modal.querySelector("[data-asset-result-count]");if(grid)grid.innerHTML=this.assetPickerGridHTML();if(count)count.textContent=`${this.assetPickerResults().length} resultados`;if(this.assetPicker.kind==="graphic")this.hydrateAssetPickerImages();else this.updateAssetAudioControls();}
  renderAssetPicker(){const old=this.root.querySelector("[data-asset-picker-modal]");if(old)this.safeRemove(old);if(!this.assetPicker)return;const audio=this.assetPicker.kind==="audio",folders=this.assetPickerFolders(),modal=document.createElement("div");modal.className="bss-modal bss-asset-picker-modal";modal.dataset.assetPickerModal="1";const footer=audio?`<div class="bss-audio-preview-bar"><div class="bss-audio-selected"><b data-asset-audio-selected>Ninguna canción seleccionada</b><small data-asset-audio-status>Selecciona una pista para escucharla antes de usarla.</small></div><button class="bss-btn" type="button" data-act="asset-audio-play" disabled>▶ Play</button><button class="bss-btn" type="button" data-act="asset-audio-pause" disabled>⏸ Pause</button><button class="bss-btn" type="button" data-act="asset-audio-stop" disabled>■ Stop</button><button class="bss-btn primary" type="button" data-act="asset-audio-use" disabled>Usar canción</button></div>`:"";modal.innerHTML=`<div class="bss-modal-card bss-asset-picker-card"><div class="bss-modal-head"><div><b>${audio?"Seleccionar BGM":"Gráficos del proyecto"}</b><small>${audio?"Audio/BGM · selección + preview":"Graphics"} · <span data-asset-result-count>${this.assetPickerResults().length} resultados</span></small></div><button class="bss-btn" data-act="close-asset-picker">Cerrar</button></div><div class="bss-asset-picker-toolbar"><input class="bss-input" autofocus data-asset-search placeholder="${audio?"Buscar canción por nombre o carpeta…":"Buscar archivo…"}" value="${E(this.assetPicker.search)}"><select class="bss-select" data-asset-folder><option value="all">Todas las carpetas</option>${folders.map(f=>`<option value="${E(f)}" ${S(this.assetPicker.folder)===f?"selected":""}>${E(f)}</option>`).join("")}</select></div><div class="bss-asset-picker-layout"><aside class="bss-asset-folder-list"><button class="bss-asset-folder ${S(this.assetPicker.folder)==="all"?"active":""}" data-asset-folder-button="all">Todo</button>${folders.map(f=>`<button class="bss-asset-folder ${S(this.assetPicker.folder)===f?"active":""}" data-asset-folder-button="${E(f)}">${E(f)}</button>`).join("")}</aside><div class="bss-asset-picker-grid ${audio?"audio-mode":""}" data-asset-results>${this.assetPickerGridHTML()}</div></div>${footer}</div>`;this.root.appendChild(modal);if(audio)this.updateAssetAudioControls();else this.hydrateAssetPickerImages();}
  assetTargetValue(row,kind){if(S(kind)==="audio")return S(row&&row.value||row&&row.relativePath||row&&row.name).replace(/\\/g,"/").replace(/^Audio\/BGM\//i,"").replace(/\.(?:ogg|mp3|wav|mid|midi|flac|opus|m4a)$/i,"");return S(row&&row.projectPath||row&&row.relativePath||row&&row.name).replace(/\\/g,"/");}
  setAssetTarget(target,value){target=S(target);value=S(value);const b=this.battle(),p=this.currentAuraProfile();if(target.startsWith("environment.")){if(!b)return;b.environment=b.environment||{};b.environment[target.slice(12)]=value;this.touch();return this.refreshInspector();}if(!p)return;p.aura=p.aura||{};if(target==="aura:particleGraphic")p.aura.particleGraphic=value;else if(target.startsWith("aura:sequence:")){const i=N(target.split(":")[2],-1),seq=this.auraGraphicPaths(Object.assign({},p.aura,{graphicMode:"sequence"})).slice(0,24);if(i>=0&&i<seq.length)seq[i]=value;p.aura.particleGraphics=seq;}else if(target.startsWith("aura:parallelseq:")){const parts=target.split(":"),li=N(parts[2],-1),si=N(parts[3],-1),layer=A(p.aura.parallelLayers)[li];if(layer){let seq=this.auraGraphicPaths(Object.assign({},layer,{graphicMode:"sequence"})).slice(0,24);if(si>=0&&si<seq.length)seq[si]=value;layer.particleGraphics=seq;}}else if(target.startsWith("aura:parallel:")){const parts=target.split(":"),li=N(parts[2],-1),field=S(parts[3]),layer=A(p.aura.parallelLayers)[li];if(layer&&field)layer[field]=value;}this.syncAuraProfileBlueprints(p);this.saveSoon();this.renderAuraStudio(true);}
  pickAssetFromPicker(index){if(!this.assetPicker)return;const row=this.assetPickerResults()[N(index,-1)];if(!row)return;const target=this.assetPicker.target,value=this.assetTargetValue(row,this.assetPicker.kind);this.stopAssetAudioPreview(true);this.assetPicker=null;this.setAssetTarget(target,value);}
  selectAssetAudio(index){if(!this.assetPicker||this.assetPicker.kind!=="audio")return;const row=this.assetPickerResults()[N(index,-1)];if(!row)return;const key=this.assetRowKey(row);if(this.assetAudioKey&&this.assetAudioKey!==key)this.stopAssetAudioPreview(true);this.assetPicker.selectedKey=key;this.refreshAssetPickerList();}
  assetAudioProjectPath(row){let path=S(row&&row.projectPath||row&&row.relativePath||row&&row.filename||row&&row.name).replace(/\\/g,"/");if(!/^Audio\/BGM\//i.test(path))path=`Audio/BGM/${path}`;if(!/\.[A-Za-z0-9]+$/.test(path)&&row&&row.extension)path+=`.`+S(row.extension).replace(/^\./,"");return path;}
  async playAssetAudioPreview(){const row=this.assetPickerSelectedAudioRow();if(!row)return;if(this.assetAudio&&this.assetAudioKey===this.assetRowKey(row)){try{await this.assetAudio.play();this.updateAssetAudioControls();return;}catch(e){this.toast("No pude reproducir esta canción: "+S(e&&e.message||e),true);return;}}this.stopAssetAudioPreview(true);const path=this.assetAudioProjectPath(row),url=await projectBlobUrl(this.ctx,path,audioMime(path));if(!url){this.toast("No pude abrir el BGM para preview.",true);return;}try{const audio=new Audio(url);audio.loop=true;audio.preload="auto";audio.addEventListener("play",()=>this.updateAssetAudioControls());audio.addEventListener("pause",()=>this.updateAssetAudioControls());audio.addEventListener("error",()=>this.updateAssetAudioControls());this.assetAudio=audio;this.assetAudioUrl=url;this.assetAudioKey=this.assetRowKey(row);await audio.play();this.updateAssetAudioControls();}catch(e){this.stopAssetAudioPreview(true);this.toast("No pude reproducir esta canción: "+S(e&&e.message||e),true);}}
  pauseAssetAudioPreview(){try{if(this.assetAudio)this.assetAudio.pause();}catch(_){}this.updateAssetAudioControls();}
  stopAssetAudioPreview(reset=true){try{if(this.assetAudio){this.assetAudio.pause();if(reset)this.assetAudio.currentTime=0;}}catch(_){}if(this.assetAudioUrl){try{URL.revokeObjectURL(this.assetAudioUrl);}catch(_){}}this.assetAudio=null;this.assetAudioUrl="";this.assetAudioKey="";this.updateAssetAudioControls();}
  updateAssetAudioControls(){const modal=this.root&&this.root.querySelector("[data-asset-picker-modal]");if(!modal||!this.assetPicker||this.assetPicker.kind!=="audio")return;const row=this.assetPickerSelectedAudioRow(),key=row?this.assetRowKey(row):"",same=!!(this.assetAudio&&key&&this.assetAudioKey===key),playing=!!(same&&!this.assetAudio.paused),name=modal.querySelector("[data-asset-audio-selected]"),status=modal.querySelector("[data-asset-audio-status]"),play=modal.querySelector('[data-act="asset-audio-play"]'),pause=modal.querySelector('[data-act="asset-audio-pause"]'),stop=modal.querySelector('[data-act="asset-audio-stop"]'),use=modal.querySelector('[data-act="asset-audio-use"]');if(name)name.textContent=row?S(row.name||this.assetTargetValue(row,"audio")):"Ninguna canción seleccionada";if(status)status.textContent=!row?"Selecciona una pista para escucharla antes de usarla.":playing?"Reproduciendo preview…":same?"Preview pausada.":"Lista para reproducir.";if(play)play.disabled=!row||playing;if(pause)pause.disabled=!playing;if(stop)stop.disabled=!same;if(use)use.disabled=!row;}
  useSelectedAssetAudio(){if(!this.assetPicker||this.assetPicker.kind!=="audio")return;const row=this.assetPickerSelectedAudioRow();if(!row)return;const target=this.assetPicker.target,value=this.assetTargetValue(row,"audio");this.stopAssetAudioPreview(true);this.assetPicker=null;this.setAssetTarget(target,value);}
  clearAssetTarget(target){this.setAssetTarget(target,"");}
  onClick(e){const raw=e&&e.target,t=raw&&typeof raw.closest==="function"?raw.closest("button,[data-resize]"):null;if(!t)return;if(this.handleExtendedClick&&this.handleExtendedClick(t,e))return;if(t.dataset.assetBrowse!=null){this.openAssetPicker(t.dataset.assetBrowse,t.dataset.assetKind||"graphic");return;}if(t.dataset.assetPick!=null){this.pickAssetFromPicker(t.dataset.assetPick);return;}if(t.dataset.assetAudioSelect!=null){this.selectAssetAudio(t.dataset.assetAudioSelect);return;}if(t.dataset.assetFolderButton!=null){if(!this.assetPicker)return;this.assetPicker.folder=S(t.dataset.assetFolderButton)||"all";const modal=this.root.querySelector("[data-asset-picker-modal]");if(modal){modal.querySelectorAll("[data-asset-folder-button]").forEach(x=>x.classList.toggle("active",S(x.dataset.assetFolderButton)===this.assetPicker.folder));const sel=modal.querySelector("[data-asset-folder]");if(sel)sel.value=this.assetPicker.folder;}this.refreshAssetPickerList();return;}if(t.dataset.assetClear!=null){this.clearAssetTarget(t.dataset.assetClear);return;}if(t.dataset.resize){this.dragResize={side:t.dataset.resize,startX:e.clientX,left:this.left,right:this.right};e.preventDefault();return;}if(t.dataset.nav){
      this.closePokemonEditor();
      const nav=S(t.dataset.nav);
      if(nav==="aura"){
        const b=this.battle();
        this.auraReturnScreen=this.screen==="editor"?"editor":"library";
        this.auraReturnSection=this.section||"boss";
        this.auraStudioProfile=S(b&&b.boss&&b.boss.aura&&b.boss.aura.profileId)||this.auraStudioProfile||"ebdx_default";
        if(b&&b.boss){const foe=A(b.teams&&b.teams.foes)[Math.max(0,N(b.boss.foeIndex,0))];if(foe){this.auraTestSpecies=U(foe.species)||this.auraTestSpecies;this.auraTestForm=N(foe.form,0);}}
        this.screen="aura";
      }else if(nav==="ebdx"){this.screen="ebdx";}else this.screen=nav==="sos"?"sos":"library";
      this.picker=null;if(this.screen!=="sos")this.sosPoolModalKey="";return this.render();
    }if(t.dataset.section)return this.switchSection(t.dataset.section);if(t.dataset.pokemonEdit)return this.openPokemonEditor(t.dataset.pokemonEdit);if(t.dataset.open){this.activeId=t.dataset.open;this.screen="editor";this.pokemonEditor=null;return this.render();}if(t.dataset.test)return this.testBattle(t.dataset.test);if(t.dataset.event){const b=this.studio.blueprints.find(x=>x.id===t.dataset.event);if(!b)return;const cmd=eventCommand(b);navigator.clipboard&&navigator.clipboard.writeText(cmd).catch(()=>{});return this.toast(cmd);}if(t.dataset.teamAdd){const b=this.battle();b.teams[t.dataset.teamAdd].push(makePokemon("PIKACHU",50));this.touch();return this.refreshInspector();}if(t.dataset.teamRemove){const [k,i]=t.dataset.teamRemove.split(":"),b=this.battle();if(b.teams[k].length>1)b.teams[k].splice(N(i),1);if(this.pokemonEditor&&S(this.pokemonEditor.target)===`team:${k}:${i}`)this.closePokemonEditor();if(k==="foes"&&b.boss)b.boss.foeIndex=Math.max(0,Math.min(N(b.boss.foeIndex,0),b.teams.foes.length-1));this.touch();this.refreshInspector();if(N(i)===0)this.remountPreviewOnly();return;}if(t.dataset.pickSpec){const [k,i]=t.dataset.pickSpec.split(":");return this.openPicker(`team:${k}:${i}`);}if(t.dataset.pickSpecial)return this.openPicker(t.dataset.pickSpecial);if(t.dataset.pickValue)return this.pickSpecies(t.dataset.pickValue);if(t.dataset.battlePoolRemove!=null){const b=this.battle(),i=N(t.dataset.battlePoolRemove);if(b){b.sos.pool=A(b.sos.pool).filter((_,idx)=>idx!==i);if(this.pokemonEditor&&S(this.pokemonEditor.target)===`sos:${i}`)this.closePokemonEditor();this.touch();this.refreshInspector();}return;}if(t.dataset.addGlobalPool)return this.openPicker(`globalpool:${t.dataset.addGlobalPool}`);if(t.dataset.globalPoolRemove){const raw=S(t.dataset.globalPoolRemove),cut=raw.lastIndexOf("|"),key=raw.slice(0,cut),i=N(raw.slice(cut+1)),kc=key.lastIndexOf(":"),p=this.profile(key.slice(0,kc),N(key.slice(kc+1)));if(p)p.pool.splice(i,1);this.saveSOSConfigSoon();return this.render();}if(t.dataset.addRequirement){const key=S(t.dataset.addRequirement),kc=key.lastIndexOf(":"),p=this.ensureProfile(key.slice(0,kc),N(key.slice(kc+1)));p.requirements=A(p.requirements);p.requirements.push({type:"badge_min",id:0,value:1});this.saveSOSConfigSoon();return this.renderSOSStudio();}if(t.dataset.removeRequirement){const raw=S(t.dataset.removeRequirement),cut=raw.lastIndexOf("|"),key=raw.slice(0,cut),i=N(raw.slice(cut+1)),kc=key.lastIndexOf(":"),p=this.profile(key.slice(0,kc),N(key.slice(kc+1)));if(p)A(p.requirements).splice(i,1);this.saveSOSConfigSoon();return this.renderSOSStudio();}if(t.dataset.globalReqRemove!=null){A(this.sosGlobal.requirements).splice(N(t.dataset.globalReqRemove),1);this.saveSOSConfigSoon();return this.renderSOSStudio();}if(t.dataset.openSosPool){this.sosPoolModalKey=S(t.dataset.openSosPool);return this.render();}if(t.dataset.importSource){this.setSOSImportSource(t.dataset.importSource);return;}if(t.dataset.assignSosExample)return this.importSOSExampleToAssignments(t.dataset.assignSosExample);if(t.dataset.importSosExample)return this.importSOSExample(t.dataset.importSosExample);if(t.dataset.auraProfile){this.auraStudioProfile=S(t.dataset.auraProfile)||"ebdx_default";this.auraParticleLayer="main";return this.renderAuraStudio(true);}
    if(t.dataset.auraTab){this.auraStudioTab=S(t.dataset.auraTab)||"appearance";return this.renderAuraStudio(false);}if(t.dataset.auraLayerTab!=null){this.auraParticleLayer=S(t.dataset.auraLayerTab)||"main";return this.renderAuraStudio(false);}
    if(t.dataset.applyAuraProfile){
      const b=this.battle(),p=this.auraProfiles().find(x=>S(x.id)===S(t.dataset.applyAuraProfile));if(!b||!p)return;
      const wasEnabled=!(b.boss&&b.boss.aura&&b.boss.aura.enabled===false);
      b.boss=b.boss||{};b.boss.aura=Object.assign({},JSON.parse(JSON.stringify(p.aura||{})),{profileId:p.id,enabled:wasEnabled});
      this.auraStudioProfile=p.id;this.touch();return this.refreshInspector();
    }
    const act=t.dataset.act;if(!act)return;
    if(act==="open-global-settings"){this.globalSettingsOpen=true;this.renderGlobalSettingsModal();return;}if(act==="close-global-settings"){this.globalSettingsOpen=false;const gm=this.root.querySelector("[data-global-settings-modal]");if(gm)this.safeRemove(gm);return;}
    if(["aura-sequence-add","aura-sequence-remove","aura-sequence-up","aura-sequence-down"].includes(act)){
      const p=this.currentAuraProfile();if(!p)return;p.aura=p.aura||{};let seq=this.auraGraphicPaths(Object.assign({},p.aura,{graphicMode:"sequence"})).slice(0,24),i=N(t.dataset.auraSeqIndex,-1);
      if(act==="aura-sequence-add"&&seq.length<24)seq.push(seq[seq.length-1]||this.auraDefaultGraphics()[0]);
      else if(act==="aura-sequence-remove"&&i>=0&&i<seq.length&&seq.length>1)seq.splice(i,1);
      else if(act==="aura-sequence-up"&&i>0&&i<seq.length){const x=seq[i-1];seq[i-1]=seq[i];seq[i]=x;}
      else if(act==="aura-sequence-down"&&i>=0&&i<seq.length-1){const x=seq[i+1];seq[i+1]=seq[i];seq[i]=x;}
      p.aura.particleGraphics=seq;this.syncAuraProfileBlueprints(p);this.saveSoon();return this.renderAuraStudio(true);
    }
    if(act==="close-asset-picker"){this.stopAssetAudioPreview(true);this.assetPicker=null;const m=this.root.querySelector("[data-asset-picker-modal]");if(m)this.safeRemove(m);return;}if(act==="asset-audio-play"){this.playAssetAudioPreview();return;}if(act==="asset-audio-pause"){this.pauseAssetAudioPreview();return;}if(act==="asset-audio-stop"){this.stopAssetAudioPreview(true);return;}if(act==="asset-audio-use"){this.useSelectedAssetAudio();return;}
    if(act==="aura-parallel-add"){
      const p=this.currentAuraProfile();if(!p)return;p.aura=p.aura||{};p.aura.parallelLayers=A(p.aura.parallelLayers).slice(0,8);if(p.aura.parallelLayers.length>=8)return this.toast("Máximo 8 capas paralelas.",true);const li=p.aura.parallelLayers.length;p.aura.parallelLayers.push({enabled:true,name:`Capa paralela ${li+1}`,graphicMode:"single",particleGraphic:this.auraDefaultGraphics()[0],particleGraphics:[this.auraDefaultGraphics()[0]],sheetColumns:4,sheetRows:1,sheetFrameCount:4,sheetStartFrame:0,graphicFrameFrames:6,graphicTransitionFrames:2,opacity:100,opacityStart:0,opacityMid:100,opacityEnd:0,particleCount:12,pattern:"rise",scale:100,riseSpeed:135,cycleFrames:30,riseHeight:100,spreadX:100,spreadY:80,laneWidth:100,swayAmount:100,stretchStart:62,stretchEnd:132,spawnMode:"async",asyncAmount:100,phaseOffset:((li+1)*23)%100,offsetX:0,offsetY:0,depthMode:"alternate",blendMode:"additive"});this.auraParticleLayer=S(li);this.syncAuraProfileBlueprints(p);this.saveSoon();return this.renderAuraStudio(true);
    }
    if(act==="aura-parallel-remove"){
      const p=this.currentAuraProfile(),i=N(t.dataset.auraLayerIndex,-1);if(!p||i<0)return;A(p.aura.parallelLayers).splice(i,1);this.auraParticleLayer="main";this.syncAuraProfileBlueprints(p);this.saveSoon();return this.renderAuraStudio(true);
    }
    if(act==="aura-parallel-sequence-add"||act==="aura-parallel-sequence-remove"){
      const p=this.currentAuraProfile(),li=N(t.dataset.auraLayerIndex,-1),layer=p&&A(p.aura.parallelLayers)[li];if(!layer)return;let seq=this.auraGraphicPaths(Object.assign({},layer,{graphicMode:"sequence"})).slice(0,24),si=N(t.dataset.auraSeqIndex,-1);if(act==="aura-parallel-sequence-add"&&seq.length<24)seq.push(seq[seq.length-1]||this.auraDefaultGraphics()[0]);else if(act==="aura-parallel-sequence-remove"&&si>=0&&si<seq.length&&seq.length>1)seq.splice(si,1);layer.particleGraphics=seq;this.syncAuraProfileBlueprints(p);this.saveSoon();return this.renderAuraStudio(true);
    }
    if(act==="open-aura-studio"){
      const b=this.battle();this.auraReturnScreen=this.screen==="editor"?"editor":"library";this.auraReturnSection=this.section||"boss";
      this.auraStudioProfile=S(t.dataset.auraOpenProfile||(b&&b.boss&&b.boss.aura&&b.boss.aura.profileId)||this.auraStudioProfile||"ebdx_default");
      if(b&&b.boss){const foe=A(b.teams&&b.teams.foes)[Math.max(0,N(b.boss.foeIndex,0))];if(foe){this.auraTestSpecies=U(foe.species)||this.auraTestSpecies;this.auraTestForm=N(foe.form,0);}}
      this.screen="aura";this.picker=null;return this.render();
    }
    if(act==="close-aura-studio"){
      this.picker=null;
      if(this.auraReturnScreen==="editor"&&this.activeId){this.screen="editor";this.section=this.auraReturnSection||"boss";}else this.screen="library";
      return this.render();
    }
    if(act==="aura-profile-new"){
      const base=this.currentAuraProfile()||this.auraProfiles()[0]||{aura:{}};const name=prompt("Nombre del perfil de aura","Nueva aura");if(!name)return;
      const p={id:`aura_${Date.now().toString(36)}`,name:S(name),builtin:false,aura:JSON.parse(JSON.stringify(base.aura||{}))};this.auraProfiles().push(p);this.auraStudioProfile=p.id;this.saveSoon();return this.renderAuraStudio();
    }
    if(act==="aura-profile-delete"){
      const p=this.currentAuraProfile();if(!p||p.builtin)return this.toast("El perfil EBDX Default no se elimina.",true);
      const fallback=this.auraProfiles().find(x=>S(x.id)==="ebdx_default")||this.auraProfiles().find(x=>x!==p);this.studio.global.auraProfiles=this.auraProfiles().filter(x=>x.id!==p.id);
      A(this.studio.blueprints).forEach(b=>{if(b&&b.boss&&b.boss.aura&&S(b.boss.aura.profileId)===S(p.id)){const enabled=b.boss.aura.enabled!==false;b.boss.aura=Object.assign({},JSON.parse(JSON.stringify(fallback&&fallback.aura||{})),{profileId:S(fallback&&fallback.id)||"ebdx_default",enabled});}});
      this.auraStudioProfile=S(fallback&&fallback.id)||"ebdx_default";this.saveSoon();return this.renderAuraStudio();
    }if(act==="close-pokemon-editor"){this.closePokemonEditor();this.refreshInspector();return;}if(act==="reset-pokemon-custom"){const p=this.pokemonEditorRecord();if(p){p.item="";p.ability="";p.nature="";p.gender="auto";p.happiness=null;p.shiny=false;p.moveMode="default";p.moves=[];p.ivs={HP:null,ATTACK:null,DEFENSE:null,SPECIAL_ATTACK:null,SPECIAL_DEFENSE:null,SPEED:null};p.evs={HP:null,ATTACK:null,DEFENSE:null,SPECIAL_ATTACK:null,SPECIAL_DEFENSE:null,SPEED:null};this.touch();this.renderPokemonEditor();this.refreshInspector();}return;}if(act==="new"){const b=makeBlueprint("Nuevo combate");b.groupId=this.activeGroup||"wild_main";b.key=this.uniqueKey(b.name,b.id);this.studio.blueprints.push(b);this.activeId=b.id;this.screen="editor";this.touch();return this.render();}if(act==="group-new"){const name=prompt("Nombre de la nueva librería","Ruta 1");if(!name)return;const id="group_"+slug(name)+"_"+Date.now().toString(36);this.studio.groups.push({id,name:S(name),system:false});this.activeGroup=id;this.saveSoon();return this.renderLibrary();}if(act==="group-rename"){const g=A(this.studio.groups).find(x=>x.id===this.activeGroup);if(!g)return;const name=prompt("Nombre de la librería",g.name);if(!name)return;g.name=S(name);this.saveSoon();return this.renderLibrary();}if(act==="group-delete"){const g=A(this.studio.groups).find(x=>x.id===this.activeGroup);if(!g||g.system)return;const main=this.studio.global.mainGroupId||"wild_main";this.studio.blueprints.forEach(b=>{if(b.groupId===g.id)b.groupId=main;});this.studio.groups=this.studio.groups.filter(x=>x.id!==g.id);this.activeGroup=main;this.saveSoon();return this.renderLibrary();}if(act==="add-sos-profile")return this.openPicker("sosglobal:addprofile");if(act==="import-sos-library"){this.sosImportOpen=true;this.sosImportSource=S(this.sosGlobal.activeDataset||"sm_usum");this.sosImportGroup="all";this.sosImportSearch="";return this.setSOSImportSource(this.sosImportSource);}if(act==="close-sos-import"){this.sosImportOpen=false;(()=>{const oldImportModal=this.root.querySelector("[data-sos-import-modal]");if(oldImportModal)this.safeRemove(oldImportModal);})();return;}if(act==="close-sos-pool"){this.sosPoolModalKey="";const m=this.root.querySelector("[data-sos-pool-modal]");if(m)this.safeRemove(m);return;}if(act==="add-global-requirement"){this.sosGlobal.requirements=A(this.sosGlobal.requirements);this.sosGlobal.requirements.push({type:"badge_min",id:0,value:1});this.saveSOSConfigSoon();return this.renderSOSStudio();}if(act==="save")return this.save();if(act==="rescan")return this.rescan();if(act==="back"||act==="back-library"){this.screen="library";this.picker=null;this.pokemonEditor=null;this.sosPoolModalKey="";return this.render();}if(act==="close-picker"){const pm=this.root.querySelector("[data-bss-picker-modal]");this.picker=null;if(pm)this.safeRemove(pm);return;}if(act==="toggle-preview"){this.previewCollapsed=!this.previewCollapsed;this.disposePreview();return this.renderEditor();}if(act==="fullscreen"){this.toggleFullscreenMode();return;}if(act==="close-editor-fullscreen"){this.closeEditorFromFullscreen();return;}if(act==="reset-pos"){const b=this.battle();b.layout.battlers={};this.touch();return this.remountPreviewOnly();}if(act==="clear-sos-pool"){const b=this.battle();b.sos.pool=[];b.sos.primary="";b.sos.secondary="";b.sos.callRate=null;b.sos.answerRate=null;this.closePokemonEditor();this.touch();return this.refreshInspector();}if(act==="select-visible-sos"){this.body.querySelectorAll("[data-sos-select]").forEach(x=>this.sosSelected.add(S(x.dataset.sosSelect)));return this.renderSOSStudio();}if(act==="clear-sos-selection"){this.sosSelected.clear();return this.renderSOSStudio();}if(act==="delete-selected-sos"){const before=A(this.sosGlobal.overrides).length;this.sosGlobal.overrides=A(this.sosGlobal.overrides).filter(p=>!this.sosSelected.has(`${U(p.species)}:${N(p.form)}`));const removed=before-this.sosGlobal.overrides.length;this.sosSelected.clear();this.saveSOSConfigSoon();this.toast(`Eliminados ${removed} perfil(es) SOS`);return this.renderSOSStudio();}}
  onInput(e){
    const t=e&&e.target;if(!t||!t.dataset)return;if(this.handleExtendedInput&&this.handleExtendedInput(t,e))return;if(t.dataset.assetSearch!=null){if(!this.assetPicker)return;this.assetPicker.search=S(t.value);return this.refreshAssetPickerList();}if(t.dataset.assetFolder!=null){if(!this.assetPicker)return;this.assetPicker.folder=S(t.value)||"all";const modal=this.root.querySelector("[data-asset-picker-modal]");if(modal)modal.querySelectorAll("[data-asset-folder-button]").forEach(x=>x.classList.toggle("active",S(x.dataset.assetFolderButton)===this.assetPicker.folder));return this.refreshAssetPickerList();}if(t.dataset.studioEbdxElement!=null){const k=S(t.dataset.studioEbdxElement);this.studio.global=this.studio.global||{};this.studio.global.ebdxElements=this.studio.global.ebdxElements||{};this.studio.global.ebdxElements[k]=!!t.checked;this.saveSoon();this.remountPreviewOnly();return;}if(t.dataset.studioGlobal!=null){const k=S(t.dataset.studioGlobal);this.studio.global=this.studio.global||{};this.studio.global[k]=t.type==="checkbox"?!!t.checked:S(t.value);this.saveSoon();if(["cameraStyle","ebdxBackdrop"].includes(k))this.remountPreviewOnly();return;}if(t.dataset.auraParallelSequence!=null){const p=this.currentAuraProfile(),parts=S(t.dataset.auraParallelSequence).split(":"),li=N(parts[0],-1),si=N(parts[1],-1),layer=p&&A(p.aura.parallelLayers)[li];if(layer){let seq=this.auraGraphicPaths(Object.assign({},layer,{graphicMode:"sequence"})).slice(0,24);if(si>=0&&si<seq.length)seq[si]=S(t.value).trim()||seq[si];layer.particleGraphics=seq;this.syncAuraProfileBlueprints(p);this.saveSoon();this.refreshAuraStudioPreview();}return;}if(t.dataset.auraParallelField!=null){const p=this.currentAuraProfile(),parts=S(t.dataset.auraParallelField).split(":"),li=N(parts[0],-1),k=S(parts.slice(1).join(":")),layer=p&&A(p.aura.parallelLayers)[li];if(!layer)return;let v=t.type==="checkbox"?!!t.checked:(t.type==="number"?N(t.value):S(t.value));const lim={graphicFrameFrames:[1,60,6],graphicTransitionFrames:[0,30,2],particleCount:[1,48,12],opacity:[0,100,100],opacityStart:[0,100,0],opacityMid:[0,100,100],opacityEnd:[0,100,0],scale:[10,300,100],riseSpeed:[10,400,135],cycleFrames:[6,180,30],riseHeight:[10,400,100],spreadX:[10,300,100],spreadY:[10,300,80],laneWidth:[10,300,100],swayAmount:[0,400,100],stretchStart:[10,250,62],stretchEnd:[10,300,132],asyncAmount:[0,500,100],phaseOffset:[0,100,23],sheetColumns:[1,32,4],sheetRows:[1,32,1],sheetFrameCount:[1,256,4],sheetStartFrame:[0,255,0],offsetX:[-200,200,0],offsetY:[-200,200,0]}[k];if(lim)v=Math.max(lim[0],Math.min(lim[1],N(v,lim[2])));if(k==="graphicMode")v=["single","sequence","sheet"].includes(S(v))?S(v):"single";if(k==="spawnMode")v=["async","simultaneous"].includes(S(v))?S(v):"async";if(k==="depthMode")v=["alternate","front","back"].includes(S(v))?S(v):"alternate";if(k==="blendMode")v=["normal","additive"].includes(S(v))?S(v):"additive";if(k==="pattern")v=["rise","orbit","vortex","rain","burst","halo","ground"].includes(S(v))?S(v):"rise";layer[k]=v;this.syncAuraProfileBlueprints(p);this.saveSoon();if(k==="graphicMode"||k==="spawnMode")return this.renderAuraStudio(true);this.refreshAuraStudioPreview();return;}if(t.dataset.auraSequenceIndex!=null){
      const p=this.currentAuraProfile();if(!p)return;p.aura=p.aura||{};const seq=this.auraGraphicPaths(Object.assign({},p.aura,{graphicMode:"sequence"})).slice(0,24),i=N(t.dataset.auraSequenceIndex,-1);if(i>=0&&i<seq.length){seq[i]=S(t.value).trim()||seq[i];p.aura.particleGraphics=seq;this.syncAuraProfileBlueprints(p);this.saveSoon();this.refreshAuraStudioPreview();}return;
    }if(t.dataset.auraProfileField!=null||t.dataset.auraProfileName!=null){
      const p=this.currentAuraProfile();if(!p)return;
      if(t.dataset.auraProfileName!=null){if(!p.builtin)p.name=S(t.value).trim()||p.name;}
      else{
        const k=S(t.dataset.auraProfileField);p.aura=p.aura||{};let v=t.type==="checkbox"?t.checked:(t.type==="number"?N(t.value):S(t.value));
        const lim={riseSpeed:[10,400,135],cycleFrames:[6,180,30],riseHeight:[10,400,100],particleCount:[1,48,12],spreadX:[10,300,100],spreadY:[10,300,80],laneWidth:[10,300,100],swayAmount:[0,400,100],offsetX:[-200,200,0],offsetY:[-200,200,0],ebdxCenterOffsetX:[-320,320,0],ebdxCenterOffsetY:[-240,240,0],particleScale:[25,250,100],stretchStart:[10,250,62],stretchEnd:[10,300,132],opacity:[0,100,100],opacityStart:[0,100,0],opacityMid:[0,100,100],opacityEnd:[0,100,0],asyncAmount:[0,500,100],graphicFrameFrames:[1,60,6],graphicTransitionFrames:[0,30,2],sheetColumns:[1,32,4],sheetRows:[1,32,1],sheetFrameCount:[1,256,4],sheetStartFrame:[0,255,0],outlineCopies:[1,12,6],outlineCopySpacing:[25,300,100],roaringStrength:[0,250,100],roaringSpeed:[10,300,100],pulseStrength:[0,250,100],pulseSpeed:[10,300,100],outlineOpacity:[0,100,46],outlineSize:[1,8,2],introDuration:[48,180,104],impactHold:[0,120,56],introReturnFrames:[8,60,24],fadeOutFrames:[1,90,18],basZoom:[100,220,150]}[k];
        if(lim)v=Math.max(lim[0],Math.min(lim[1],N(v,lim[2])));
        if(k==="spawnMode")v=["async","simultaneous"].includes(S(v))?S(v):"async";
        if(k==="graphicMode")v=["single","sequence","sheet"].includes(S(v))?S(v):"sequence";if(k==="pattern")v=["rise","orbit","vortex","rain","burst","halo","ground"].includes(S(v))?S(v):"rise";
        if(k==="particleGraphic")v=S(v).trim()||this.auraDefaultGraphics()[0];
        if(k==="depthMode")v=["alternate","front","back"].includes(S(v))?S(v):"alternate";
        if(k==="blendMode")v=["normal","additive"].includes(S(v))?S(v):"normal";
        if(k==="basZoomBounds")v=["screen","extended"].includes(S(v))?S(v):"screen";
        if(k==="outlineEffect")v=["standard","roaring_knight","pulse"].includes(S(v))?S(v):"standard";
        p.aura[k]=v;
        this.syncAuraProfileBlueprints(p);
      }
      this.saveSoon();this.refreshAuraStudioPreview();if(t.dataset.auraProfileField==="graphicMode"||t.dataset.auraProfileField==="spawnMode")return this.renderAuraStudio(true);
      if(t.dataset.auraProfileName!=null){const active=this.root.querySelector('.bss-aura-profile.active b');if(active)active.textContent=p.name;}
      return;
    }if(t.matches("[data-search]")){this.search=S(t.value);return this.deferRender(()=>this.renderLibrary());}if(t.matches("[data-sos-search]")){this.sosSearch=S(t.value);return this.deferRender(()=>this.renderSOSStudio());}if(t.matches("[data-sos-example-search]")){this.sosExampleSearch=S(t.value);return this.deferRender(()=>this.renderSOSStudio());}if(t.matches("[data-sos-import-search]")){this.sosImportSearch=S(t.value);return this.refreshSOSImporterList();}if(t.dataset.sosImportGroup!=null){this.sosImportGroup=S(t.value);return this.refreshSOSImporterList();}if(t.dataset.sosExampleGroup!=null){this.sosExampleGroup=S(t.value);return this.renderSOSStudio();}if(t.dataset.groupFilter!=null){this.activeGroup=S(t.value);return this.renderLibrary();}if(t.dataset.moveGroup){const b=this.studio.blueprints.find(x=>x.id===t.dataset.moveGroup);if(b){b.groupId=S(t.value);this.saveSoon();}return;}if(t.dataset.sosSelect){if(t.checked)this.sosSelected.add(S(t.dataset.sosSelect));else this.sosSelected.delete(S(t.dataset.sosSelect));const disabled=this.sosSelected.size===0;this.root.querySelectorAll('[data-act="clear-sos-selection"],[data-act="delete-selected-sos"]').forEach(btn=>{btn.disabled=disabled;});const tile=t.closest(".bss-sosprofile-tile");if(tile)tile.classList.toggle("selected",t.checked);return;}
    if(t.matches("[data-picker-search]")){this.picker.search=S(t.value);return this.refreshPickerList();}
    if(t.dataset.name){const b=this.studio.blueprints.find(x=>x.id===t.dataset.name);if(!b)return;b.name=S(t.value)||"Battle";b.key=this.uniqueKey(b.name,b.id);this.touch();return;}
    if(t.dataset.monField!=null){const p=this.pokemonEditorRecord();if(!p)return;const k=S(t.dataset.monField);let v=t.type==="checkbox"?t.checked:t.value;if(["ability","nature","item"].includes(k))v=U(S(v).trim());if(k==="gender")v=["male","female"].includes(L(v))?L(v):"auto";if(k==="happiness")v=S(t.value).trim()===""?null:Math.max(0,Math.min(255,N(t.value,70)));p[k]=v;this.touch();return;}
    if(t.dataset.monIv!=null){const p=this.pokemonEditorRecord();if(!p)return;const k=U(t.dataset.monIv);p.ivs=p.ivs||{};p.ivs[k]=S(t.value).trim()===""?null:Math.max(0,Math.min(31,N(t.value,0)));this.touch();return;}
    if(t.dataset.monEv!=null){const p=this.pokemonEditorRecord();if(!p)return;const k=U(t.dataset.monEv);p.evs=p.evs||{};p.evs[k]=S(t.value).trim()===""?null:Math.max(0,Math.min(252,N(t.value,0)));this.touch();return;}
    if(t.dataset.monMoveMode!=null){const p=this.pokemonEditorRecord();if(!p)return;p.moveMode=S(t.value)==="custom"?"custom":"default";p.moves=A(p.moves).slice(0,4);while(p.moves.length<4)p.moves.push("");this.touch();return this.renderPokemonEditor();}
    if(t.dataset.monMove!=null){const p=this.pokemonEditorRecord();if(!p)return;const slot=N(t.dataset.monMove);p.moves=A(p.moves).slice(0,4);while(p.moves.length<4)p.moves.push("");p.moves[slot]=U(S(t.value).trim());p.moveMode="custom";this.touch();return;}
    if(t.dataset.bind){const b=this.battle();if(!b)return;const path=t.dataset.bind;let val=t.type==="checkbox"?t.checked:t.type==="number"?((["sos.callRate","sos.answerRate","sos.levelMin","sos.levelMax","sos.levelFixed","setup.aiSkill"].includes(path)&&S(t.value).trim()==="")?null:N(t.value)):t.value;if(path==="boss.aiSkill"||(path==="setup.aiSkill"&&val!=null))val=Math.max(0,Math.min(100,N(val,100)));if(path==="sos.maxSimultaneousSOS")val=Math.max(1,Math.min(2,N(val,1)));if(path==="sos.summonsPerCall")val=Math.max(1,Math.min(Math.max(1,Math.min(2,N(b.sos.maxSimultaneousSOS,1))),N(val,1)));if(path==="boss.foeIndex")val=Math.max(0,Math.min(Math.max(0,A(b.teams&&b.teams.foes).length-1),N(val,0)));if(path.indexOf("boss.stats.")===0)val=Math.max(-6,Math.min(6,N(val,0)));if(path==="boss.hud.shieldBreakStats.dropAll"||path==="boss.hud.shieldBreakStats.raiseAll")val=Math.max(1,Math.min(6,N(val,1)));if(path.indexOf("boss.hud.shieldBreakStats.drop.")===0||path.indexOf("boss.hud.shieldBreakStats.raise.")===0)val=Math.max(0,Math.min(6,N(val,0)));if(["boss.mechanics.residual.trappingPercent","boss.mechanics.residual.moveEffectPercent","boss.mechanics.residual.statusPercent","boss.mechanics.residual.weatherPercent"].includes(path))val=Math.max(0,Math.min(100,N(val,50)));if(path==="boss.attributes.hpMultiplier")val=Math.max(1,Math.round(N(val,1)));if(path==="boss.aura.color"||path==="boss.aura.outlineColor"){const raw=S(val).trim(),fallback=path==="boss.aura.outlineColor"?(S(b.boss&&b.boss.aura&&b.boss.aura.outlineColor)||S(b.boss&&b.boss.aura&&b.boss.aura.color)||"#DD445B"):(S(b.boss&&b.boss.aura&&b.boss.aura.color)||"#DD445B");val=/^#[0-9A-Fa-f]{6}$/.test(raw)?raw.toUpperCase():fallback;}const auraLimits={"boss.aura.particleCount":[4,24,12],"boss.aura.riseSpeed":[25,300,135],"boss.aura.spreadX":[25,200,100],"boss.aura.spreadY":[25,180,80],"boss.aura.particleScale":[25,250,100],"boss.aura.opacity":[0,100,100],"boss.aura.asyncAmount":[0,300,100],"boss.aura.graphicFrameFrames":[1,60,6],"boss.aura.introDuration":[48,180,104],"boss.aura.impactHold":[0,120,56],"boss.aura.basZoom":[100,220,150]};if(auraLimits[path]){const lim=auraLimits[path];val=Math.max(lim[0],Math.min(lim[1],N(val,lim[2])));}this.setPath(b,path,val);if(path==="boss.aura.color"||path==="boss.aura.outlineColor")this.root.querySelectorAll(`[data-bind="${path}"]`).forEach(el=>{if(el!==t)el.value=val;});if(path==="sos.maxSimultaneousSOS"&&N(b.sos.summonsPerCall,1)>val)b.sos.summonsPerCall=val;if(path==="name")b.key=this.uniqueKey(val,b.id);if(path==="key")b.key=this.uniqueKey(val,b.id);if(path==="groupId")this.activeGroup=S(val);this.touch();if(["setup.kind","boss.enabled","boss.foeIndex","boss.aura.enabled","boss.aura.introEnabled","boss.aura.outlineEnabled","boss.aura.basZoomEnabled","boss.aura.basZoomBounds","boss.hud.enabled","boss.hud.shieldEnabled","boss.hud.showTitle","boss.hud.showLevel","boss.hud.shieldBreakStats.enabled","boss.hud.shieldBreakStats.dropMode","boss.hud.shieldBreakStats.raiseMode","sos.enabled","sos.levelMode","sos.allySelectionMode","sos.maxSimultaneousSOS"].includes(path))this.refreshInspector();if(["setup.kind","setup.formation","environment.battleback","environment.cameraStyle","environment.ebdxBackdrop"].includes(path))this.remountPreviewOnly();if(["setup.kind","setup.formation","boss.enabled","sos.enabled"].includes(path))this.refreshStageSummary();return;}
    if(t.dataset.teamLevel){const [k,i]=t.dataset.teamLevel.split(":"),p=this.battle().teams[k][N(i)];if(p){p.level=Math.max(1,Math.min(100,N(t.value,50)));this.touch();}return;}
    if(t.dataset.battlePoolWeight!=null){const x=A(this.battle().sos.pool)[N(t.dataset.battlePoolWeight)];if(x&&typeof x!=="string")x.weight=Math.max(0,N(t.value,100));this.touch();this.refreshBattlePoolPercentages();return;}
    if(t.dataset.battlePoolMoveMode!=null){const b=this.battle(),x=b&&A(b.sos.pool)[N(t.dataset.battlePoolMoveMode)];if(x&&typeof x!=="string"){x.moveMode=S(t.value)==="custom"?"custom":"default";x.moves=A(x.moves).slice(0,4);while(x.moves.length<4)x.moves.push("");this.touch();this.refreshInspector();}return;}
    if(t.dataset.battlePoolMove!=null){const b=this.battle(),raw=S(t.dataset.battlePoolMove).split(":"),x=b&&A(b.sos.pool)[N(raw[0])],slot=N(raw[1]);if(x&&typeof x!=="string"&&slot>=0&&slot<4){x.moves=A(x.moves).slice(0,4);while(x.moves.length<4)x.moves.push("");x.moves[slot]=U(S(t.value).trim());x.moveMode="custom";this.touch();}return;}
    if(t.dataset.global){const k=t.dataset.global;let gv=t.type==="checkbox"?t.checked:t.type==="number"?((["levelMin","levelMax","levelFixed"].includes(k)&&S(t.value).trim()==="")?null:N(t.value)):t.value;if(k==="maxSimultaneousSOS")gv=Math.max(1,Math.min(2,N(gv,1)));if(["levelMin","levelMax","levelFixed"].includes(k)&&gv!=null)gv=Math.max(1,Math.min(100,N(gv,1)));this.sosGlobal[k]=gv;if(k==="allowChainCalls"){this.sosGlobal.limitCallsToOne=!gv;if(!gv)this.sosGlobal.allowSOSContinuation=false;}if(k==="allowSOSContinuation"&&gv){this.sosGlobal.allowChainCalls=true;this.sosGlobal.limitCallsToOne=false;}this.saveSOSConfigSoon();if(k==="activeDataset"){this.sosExampleSearch="";this.sosExampleGroup="all";this.loadSOSCatalog().then(()=>this.renderSOSStudio());return;}if(["mode","allowChainCalls","allowSOSContinuation","levelMode"].includes(k))this.renderSOSStudio();return;}
    if(t.dataset.globalReqType!=null){const r=A(this.sosGlobal.requirements)[N(t.dataset.globalReqType)];if(r){r.type=S(t.value);this.saveSOSConfigSoon();this.renderSOSStudio();}return;}if(t.dataset.globalReqId!=null){const r=A(this.sosGlobal.requirements)[N(t.dataset.globalReqId)];if(r){r.id=N(t.value);this.saveSOSConfigSoon();}return;}if(t.dataset.globalReqValue!=null){const r=A(this.sosGlobal.requirements)[N(t.dataset.globalReqValue)];if(r){r.value=N(t.value);this.saveSOSConfigSoon();}return;}const keyFrom=(raw)=>{raw=S(raw);const c=raw.lastIndexOf(":");return [raw.slice(0,c),N(raw.slice(c+1))]};
    if(t.dataset.profileRate){const key=S(t.dataset.profileRate),[sp,f]=keyFrom(key),p=this.ensureProfile(sp,f);p.callRate=Math.max(0,Math.min(100,N(t.value)));this.root.querySelectorAll(`[data-profile-rate-view="${CSS.escape(key)}"]`).forEach(x=>x.textContent=`${p.callRate}%`);this.saveSOSConfigSoon();return;}
    if(t.dataset.profileAnswer){const key=S(t.dataset.profileAnswer),[sp,f]=keyFrom(key),p=this.ensureProfile(sp,f);p.answerRate=Math.max(0,Math.min(100,N(t.value,100)));this.root.querySelectorAll(`[data-profile-answer-view="${CSS.escape(key)}"]`).forEach(x=>x.textContent=`${p.answerRate}%`);this.saveSOSConfigSoon();return;}
    if(t.dataset.profilePoolWeight){const raw=S(t.dataset.profilePoolWeight),cut=raw.lastIndexOf("|"),key=raw.slice(0,cut),i=N(raw.slice(cut+1)),[sp,f]=keyFrom(key),p=this.ensureProfile(sp,f),x=A(p.pool)[i];if(x&&typeof x!=="string")x.weight=Math.max(0,N(t.value,100));this.saveSOSConfigSoon();this.refreshProfilePoolPercentages(key);return;}
    const reqUpdate=(raw,field,val)=>{raw=S(raw);const cut=raw.lastIndexOf("|"),key=raw.slice(0,cut),i=N(raw.slice(cut+1)),[sp,f]=keyFrom(key),p=this.ensureProfile(sp,f),r=A(p.requirements)[i];if(r){r[field]=val;this.saveSOSConfigSoon();}};
    if(t.dataset.reqType)return reqUpdate(t.dataset.reqType,"type",S(t.value));if(t.dataset.reqId)return reqUpdate(t.dataset.reqId,"id",N(t.value));if(t.dataset.reqValue)return reqUpdate(t.dataset.reqValue,"value",N(t.value));
  }
  setPath(obj,path,val){const bits=S(path).split(".");let cur=obj;for(let i=0;i<bits.length-1;i++){if(!cur[bits[i]]||typeof cur[bits[i]]!=="object")cur[bits[i]]={};cur=cur[bits[i]];}cur[bits[bits.length-1]]=val;}
  onPointerMove(e){if(!this.dragResize)return;const dx=e.clientX-this.dragResize.startX;if(this.dragResize.side==="left")this.left=Math.max(180,Math.min(440,this.dragResize.left+dx));else this.right=Math.max(240,Math.min(560,this.dragResize.right-dx));const ed=this.body.querySelector(".bss-editor");if(ed){ed.style.setProperty("--left",this.left+"px");ed.style.setProperty("--right",this.right+"px");}}
  onPointerUp(){this.dragResize=null;}
}


//=============================================================================
// v0.6.49 extensions · aura variety/spritesheets, scoped assets, library I/O,
// and the first BSS-native Boss HUD + segmented shield pass.
//=============================================================================
const _bss644RenderLibrary=App.prototype.renderLibrary;
const _bss644AuraSettingsHTML=App.prototype.auraSettingsHTML;
const _bss644BossHTML=App.prototype.bossHTML;

App.prototype.auraGraphicPaths=function(a){
  a=a&&typeof a==="object"?a:{};const fallback=this.auraDefaultGraphics(),mode=S(a.graphicMode||"sequence");
  if(mode==="single"||mode==="sheet")return [S(a.particleGraphic||fallback[0]).trim()||fallback[0]];
  const rows=A(a.particleGraphics).map(x=>S(x).trim()).filter(Boolean).slice(0,24);return rows.length?rows:fallback;
};
App.prototype.auraGraphicOptions=function(current=""){
  const rows=this.assetPickerRowsForTarget?this.assetPickerRowsForTarget("aura:particleGraphic","graphic"):A(this.source&&this.source.auraGraphics),seen=new Set(),all=[];
  for(const x of rows){const path=S(x&&x.projectPath||x&&x.relativePath).trim();if(!path||seen.has(path))continue;seen.add(path);all.push({path,label:S(x&&x.relativePath||x&&x.name||path).replace(/^Graphics\//i,"")});}
  for(const path of this.auraDefaultGraphics()){if(!seen.has(path)){seen.add(path);all.push({path,label:path.replace(/^Graphics\/BattleSceneStudio\/Auras\//i,"")});}}
  current=S(current).trim();if(current&&!seen.has(current))all.unshift({path:current,label:current});return all.map(x=>`<option value="${E(x.path)}" ${x.path===current?"selected":""}>${E(x.label)}</option>`).join("");
};
App.prototype.auraSheetFieldsHTML=function(a,prefix){
  const attr=prefix==="main"?"data-aura-profile-field":"data-aura-parallel-field",pre=prefix==="main"?"":`${prefix}:`;
  return `<div class="bss-aura-sheet-grid"><div class="bss-aura-explain compact"><b>Recorte de spritesheet</b><span>Divide una sola imagen en una cuadrícula y reproduce los frames de izquierda a derecha, fila por fila. La vida sigue siendo one-shot: último frame → fade.</span></div>${this.field("Columnas",`<input class="bss-input" type="number" min="1" max="32" ${attr}="${pre}sheetColumns" value="${N(a.sheetColumns,4)}">`)}${this.field("Filas",`<input class="bss-input" type="number" min="1" max="32" ${attr}="${pre}sheetRows" value="${N(a.sheetRows,1)}">`)}${this.field("Frames usados",`<input class="bss-input" type="number" min="1" max="256" ${attr}="${pre}sheetFrameCount" value="${N(a.sheetFrameCount,4)}">`)}${this.field("Frame inicial",`<input class="bss-input" type="number" min="0" max="255" ${attr}="${pre}sheetStartFrame" value="${N(a.sheetStartFrame,0)}"><span class="bss-note">0 = primer frame de la hoja.</span>`)}</div>`;
};
App.prototype.auraSingleGraphicFieldHTML=function(a,target,fieldAttr){
  const current=S(a.particleGraphic||this.auraDefaultGraphics()[0]),bind=fieldAttr||'data-aura-profile-field="particleGraphic"';
  return this.field("Gráfico / spritesheet",`<div class="bss-asset-field"><select class="bss-select" ${bind}>${this.auraGraphicOptions(current)}</select><button class="bss-btn small" type="button" data-asset-browse="${E(target)}" data-asset-kind="graphic">Explorar…</button></div>`);
};
App.prototype.auraParallelLayerHTML=function(layer,li){
  layer=layer&&typeof layer==="object"?layer:{};let mode=S(layer.graphicMode||"single");if(!["single","sequence","sheet"].includes(mode))mode="single";const spawn=S(layer.spawnMode||"async")==="simultaneous"?"simultaneous":"async",blend=L(layer.blendMode)==="normal"?"normal":"additive";
  const graphicUI=mode==="sequence"?`<div class="bss-aura-settings-wide">${this.auraSequenceEditorHTML(layer,S(li))}</div>`:this.auraSingleGraphicFieldHTML(layer,`aura:parallel:${li}:particleGraphic`,`data-aura-parallel-field="${li}:particleGraphic"`);
  const sheetUI=mode==="sheet"?this.auraSheetFieldsHTML(layer,S(li)):"";
  return `<div class="bss-aura-layer-editor"><div class="bss-aura-layer-head"><div><b>${E(layer.name||`Capa paralela ${li+1}`)}</b><small>Esta capa es completamente independiente: gráfico, blend, ritmo, opacidad, movimiento y asincronía.</small></div><label class="bss-check compact"><input type="checkbox" data-aura-parallel-field="${li}:enabled" ${layer.enabled!==false?"checked":""}> Activa</label><button class="bss-btn small danger" type="button" data-act="aura-parallel-remove" data-aura-layer-index="${li}">Eliminar</button></div><div class="bss-aura-settings-grid">${this.field("Nombre",`<input class="bss-input" data-aura-parallel-field="${li}:name" value="${E(layer.name||`Capa paralela ${li+1}`)}">`)}${this.field("Modo gráfico",`<select class="bss-select" data-aura-parallel-field="${li}:graphicMode"><option value="single" ${mode==="single"?"selected":""}>Un gráfico</option><option value="sequence" ${mode==="sequence"?"selected":""}>Secuencia de archivos</option><option value="sheet" ${mode==="sheet"?"selected":""}>Spritesheet / recortar frames</option></select>`)}${graphicUI}${sheetUI}${this.field("Tiempo por frame/gráfico",`<input class="bss-input" type="number" min="1" max="60" data-aura-parallel-field="${li}:graphicFrameFrames" value="${N(layer.graphicFrameFrames,6)}">`)}${this.field("Transición / crossfade",`<input class="bss-input" type="number" min="0" max="30" data-aura-parallel-field="${li}:graphicTransitionFrames" value="${N(layer.graphicTransitionFrames,2)}">`)}${this.field("Blend de esta capa",`<select class="bss-select" data-aura-parallel-field="${li}:blendMode"><option value="normal" ${blend==="normal"?"selected":""}>Normal</option><option value="additive" ${blend==="additive"?"selected":""}>Additive</option></select><span class="bss-note">Se aplica a todos los sprites A/B usados por el crossfade.</span>`)}${this.field("Partículas",`<input class="bss-input" type="number" min="1" max="48" data-aura-parallel-field="${li}:particleCount" value="${N(layer.particleCount,12)}">`)}${this.field("Patrón de movimiento",`<select class="bss-select" data-aura-parallel-field="${li}:pattern"><option value="rise" ${S(layer.pattern||"rise")==="rise"?"selected":""}>Ascenso EBDX</option><option value="orbit" ${S(layer.pattern)==="orbit"?"selected":""}>Órbita</option><option value="vortex" ${S(layer.pattern)==="vortex"?"selected":""}>Vórtice</option><option value="rain" ${S(layer.pattern)==="rain"?"selected":""}>Lluvia descendente</option><option value="burst" ${S(layer.pattern)==="burst"?"selected":""}>Explosión radial</option><option value="halo" ${S(layer.pattern)==="halo"?"selected":""}>Halo</option><option value="ground" ${S(layer.pattern)==="ground"?"selected":""}>Anillo de suelo</option></select>`)}${this.field("Nacimiento",`<select class="bss-select" data-aura-parallel-field="${li}:spawnMode"><option value="async" ${spawn==="async"?"selected":""}>Asíncrono</option><option value="simultaneous" ${spawn==="simultaneous"?"selected":""}>Simultáneo</option></select>`)}${this.field("Asincronía (%)",`<input class="bss-input" type="number" min="0" max="500" data-aura-parallel-field="${li}:asyncAmount" value="${N(layer.asyncAmount,100)}" ${spawn==="simultaneous"?"disabled":""}>`)}${this.field("Desfase de capa (%)",`<input class="bss-input" type="number" min="0" max="100" data-aura-parallel-field="${li}:phaseOffset" value="${N(layer.phaseOffset,((li+1)*23)%100)}"><span class="bss-note">Hace que una capa paralela no nazca al mismo tiempo que la principal.</span>`)}${this.field("Vida",`<input class="bss-input" type="number" min="6" max="180" data-aura-parallel-field="${li}:cycleFrames" value="${N(layer.cycleFrames,30)}">`)}${this.field("Velocidad subida (%)",`<input class="bss-input" type="number" min="10" max="400" data-aura-parallel-field="${li}:riseSpeed" value="${N(layer.riseSpeed,135)}">`)}${this.field("Altura (%)",`<input class="bss-input" type="number" min="20" max="300" data-aura-parallel-field="${li}:riseHeight" value="${N(layer.riseHeight,100)}">`)}${this.field("Dispersión X (%)",`<input class="bss-input" type="number" min="25" max="250" data-aura-parallel-field="${li}:spreadX" value="${N(layer.spreadX,100)}">`)}${this.field("Dispersión Y (%)",`<input class="bss-input" type="number" min="25" max="220" data-aura-parallel-field="${li}:spreadY" value="${N(layer.spreadY,80)}">`)}${this.field("Carriles (%)",`<input class="bss-input" type="number" min="25" max="250" data-aura-parallel-field="${li}:laneWidth" value="${N(layer.laneWidth,100)}">`)}${this.field("Ondulación (%)",`<input class="bss-input" type="number" min="0" max="300" data-aura-parallel-field="${li}:swayAmount" value="${N(layer.swayAmount,100)}">`)}${this.field("Escala (%)",`<input class="bss-input" type="number" min="10" max="300" data-aura-parallel-field="${li}:scale" value="${N(layer.scale,100)}">`)}${this.field("Stretch inicio (%)",`<input class="bss-input" type="number" min="10" max="250" data-aura-parallel-field="${li}:stretchStart" value="${N(layer.stretchStart,62)}">`)}${this.field("Stretch final (%)",`<input class="bss-input" type="number" min="10" max="300" data-aura-parallel-field="${li}:stretchEnd" value="${N(layer.stretchEnd,132)}">`)}${this.field("Opacidad global (%)",`<input class="bss-input" type="number" min="0" max="100" data-aura-parallel-field="${li}:opacity" value="${N(layer.opacity,100)}">`)}${this.field("Opacidad inicial (%)",`<input class="bss-input" type="number" min="0" max="100" data-aura-parallel-field="${li}:opacityStart" value="${N(layer.opacityStart,0)}">`)}${this.field("Opacidad media (%)",`<input class="bss-input" type="number" min="0" max="100" data-aura-parallel-field="${li}:opacityMid" value="${N(layer.opacityMid,100)}">`)}${this.field("Opacidad final (%)",`<input class="bss-input" type="number" min="0" max="100" data-aura-parallel-field="${li}:opacityEnd" value="${N(layer.opacityEnd,0)}">`)}${this.field("Offset X (%)",`<input class="bss-input" type="number" min="-150" max="150" data-aura-parallel-field="${li}:offsetX" value="${N(layer.offsetX,0)}">`)}${this.field("Offset Y (%)",`<input class="bss-input" type="number" min="-150" max="150" data-aura-parallel-field="${li}:offsetY" value="${N(layer.offsetY,0)}">`)}${this.field("Profundidad",`<select class="bss-select" data-aura-parallel-field="${li}:depthMode"><option value="alternate" ${S(layer.depthMode||"alternate")==="alternate"?"selected":""}>Delante/detrás</option><option value="front" ${S(layer.depthMode)==="front"?"selected":""}>Delante</option><option value="back" ${S(layer.depthMode)==="back"?"selected":""}>Detrás</option></select>`)}</div></div>`;
};
App.prototype.auraSettingsHTML=function(p){
  if(S(this.auraStudioTab)!=="particles")return _bss644AuraSettingsHTML.call(this,p);
  const a=p.aura||{},layers=A(a.parallelLayers),active=S(this.auraParticleLayer||"main");
  const tabs=`<div class="bss-aura-layer-tabs"><button class="bss-aura-layer-tab ${active==="main"?"active":""}" data-aura-layer-tab="main">Principal</button>${layers.map((x,i)=>`<button class="bss-aura-layer-tab ${active===S(i)?"active":""}" data-aura-layer-tab="${i}">${E(x.name||`Capa ${i+1}`)}</button>`).join("")}<button class="bss-btn small" data-act="aura-parallel-add" ${layers.length>=8?"disabled":""}>＋ Capa</button><span class="bss-note">${layers.length}/8</span></div>`;
  if(active!=="main"&&layers[N(active,-1)])return `${tabs}<div class="bss-aura-explain"><b>Capa paralela ${N(active)+1}</b><span>Edita esta capa como si fuera la principal. Normal/Additive, spritesheet, secuencia, timing y asincronía son propios.</span></div>${this.auraParallelLayerHTML(layers[N(active)],N(active))}`;
  let mode=S(a.graphicMode||"sequence");if(!["single","sequence","sheet"].includes(mode))mode="sequence";const spawn=S(a.spawnMode||"async")==="simultaneous"?"simultaneous":"async",blend=L(a.blendMode)==="additive"?"additive":"normal";
  const graphicUI=mode==="sequence"?`<div class="bss-aura-settings-wide">${this.auraSequenceEditorHTML(a)}</div>`:this.auraSingleGraphicFieldHTML(a,"aura:particleGraphic");
  const sheetUI=mode==="sheet"?this.auraSheetFieldsHTML(a,"main"):"";
  return `${tabs}<div class="bss-aura-explain"><b>Partícula principal</b><span>Puedes usar un archivo fijo, varios archivos one-shot o una spritesheet recortada. El Blend se aplica realmente a los dos sprites del crossfade.</span></div><div class="bss-aura-settings-grid">${this.field("Modo gráfico",`<select class="bss-select" data-aura-profile-field="graphicMode"><option value="single" ${mode==="single"?"selected":""}>Un gráfico</option><option value="sequence" ${mode==="sequence"?"selected":""}>Secuencia de archivos</option><option value="sheet" ${mode==="sheet"?"selected":""}>Spritesheet / recortar frames</option></select>`)}${graphicUI}${sheetUI}${this.field("Tiempo por frame/gráfico",`<input class="bss-input" type="number" min="1" max="60" data-aura-profile-field="graphicFrameFrames" value="${N(a.graphicFrameFrames,6)}">`)}${this.field("Transición / crossfade",`<input class="bss-input" type="number" min="0" max="30" data-aura-profile-field="graphicTransitionFrames" value="${N(a.graphicTransitionFrames,2)}">`)}${this.field("Blend principal",`<select class="bss-select" data-aura-profile-field="blendMode"><option value="normal" ${blend==="normal"?"selected":""}>Normal</option><option value="additive" ${blend==="additive"?"selected":""}>Additive</option></select><span class="bss-note">Additive = suma luminosa; Normal = alpha estándar.</span>`)}${this.field("Cantidad",`<input class="bss-input" type="number" min="1" max="48" data-aura-profile-field="particleCount" value="${N(a.particleCount,12)}">`)}${this.field("Nacimiento",`<select class="bss-select" data-aura-profile-field="spawnMode"><option value="async" ${spawn==="async"?"selected":""}>Asíncrono</option><option value="simultaneous" ${spawn==="simultaneous"?"selected":""}>Simultáneo</option></select>`)}${this.field("Asincronía (%)",`<input class="bss-input" type="number" min="0" max="500" data-aura-profile-field="asyncAmount" value="${N(a.asyncAmount,100)}" ${spawn==="simultaneous"?"disabled":""}>`)}${this.field("Velocidad subida (%)",`<input class="bss-input" type="number" min="10" max="400" data-aura-profile-field="riseSpeed" value="${N(a.riseSpeed,135)}">`)}${this.field("Dispersión X (%)",`<input class="bss-input" type="number" min="25" max="250" data-aura-profile-field="spreadX" value="${N(a.spreadX,100)}">`)}${this.field("Dispersión Y (%)",`<input class="bss-input" type="number" min="25" max="220" data-aura-profile-field="spreadY" value="${N(a.spreadY,80)}">`)}${this.field("Escala (%)",`<input class="bss-input" type="number" min="25" max="250" data-aura-profile-field="particleScale" value="${N(a.particleScale,100)}">`)}</div>`;
};
App.prototype.auraConfigFromPreview=function(preview){const d=preview&&preview.dataset||{};return {graphicMode:S(d.auraGraphicMode||"sequence"),particleGraphic:S(d.auraParticleGraphic||""),particleGraphics:S(d.auraParticleGraphics||"").split("|").map(x=>S(x).trim()).filter(Boolean),sheetColumns:N(d.auraSheetColumns,4),sheetRows:N(d.auraSheetRows,1),sheetFrameCount:N(d.auraSheetFrameCount,4),sheetStartFrame:N(d.auraSheetStartFrame,0),graphicFrameFrames:N(d.auraGraphicFrameFrames,6),graphicTransitionFrames:N(d.auraGraphicTransitionFrames,2)};};
const _bss644ApplyAuraPreviewConfig=App.prototype.applyAuraPreviewConfig;
App.prototype.applyAuraPreviewConfig=function(preview,a){_bss644ApplyAuraPreviewConfig.call(this,preview,a);if(!preview)return;preview.dataset.auraPattern=S(a.pattern||"rise");preview.dataset.auraSheetColumns=S(N(a.sheetColumns,4));preview.dataset.auraSheetRows=S(N(a.sheetRows,1));preview.dataset.auraSheetFrameCount=S(N(a.sheetFrameCount,4));preview.dataset.auraSheetStartFrame=S(N(a.sheetStartFrame,0));};
App.prototype.splitAuraSheetUrl=async function(raw,a){return new Promise(resolve=>{if(!raw)return resolve([]);const im=new Image();im.onload=()=>{try{const cols=Math.max(1,Math.min(32,N(a.sheetColumns,4))),rows=Math.max(1,Math.min(32,N(a.sheetRows,1))),total=cols*rows,start=Math.max(0,Math.min(total-1,N(a.sheetStartFrame,0))),count=Math.max(1,Math.min(total-start,N(a.sheetFrameCount,4))),fw=Math.floor(im.naturalWidth/cols),fh=Math.floor(im.naturalHeight/rows),out=[];if(fw<1||fh<1)return resolve([raw]);for(let n=0;n<count;n++){const idx=start+n,x=(idx%cols)*fw,y=Math.floor(idx/cols)*fh,c=document.createElement("canvas");c.width=fw;c.height=fh;const g=c.getContext("2d");g.drawImage(im,x,y,fw,fh,0,0,fw,fh);out.push(c.toDataURL("image/png"));}resolve(out.length?out:[raw]);}catch(_){resolve([raw]);}};im.onerror=()=>resolve([raw]);im.src=raw;});};
App.prototype.auraBaseFrames=async function(a){a=a&&typeof a==="object"?a:{};const paths=this.auraGraphicPaths(a),key=[S(a.graphicMode),N(a.sheetColumns,4),N(a.sheetRows,1),N(a.sheetFrameCount,4),N(a.sheetStartFrame,0),...paths].join("|");if(this.auraRuntimeAssetCache.has(key))return this.auraRuntimeAssetCache.get(key);const task=(async()=>{const raws=(await Promise.all(paths.map(projectPath=>this.assetUrl({projectPath}).catch(()=>null)))).filter(Boolean);if(S(a.graphicMode)==="sheet"&&raws[0])return this.splitAuraSheetUrl(raws[0],a);return raws;})();this.auraRuntimeAssetCache.set(key,task);return task;};
App.prototype.auraTintedFrames=async function(color,a){color=/^#[0-9A-Fa-f]{6}$/.test(S(color))?S(color).toUpperCase():"#DD445B";const raws=await this.auraBaseFrames(a),key=`645|${color}|${S(a&&a.graphicMode)}|${N(a&&a.sheetColumns,4)}|${N(a&&a.sheetRows,1)}|${N(a&&a.sheetFrameCount,4)}|${N(a&&a.sheetStartFrame,0)}|${raws.join("|")}`;if(this.auraTintCache.has(key))return this.auraTintCache.get(key);const task=(async()=>{const rgb=this.auraHexRGB(color),base=[221,68,91],delta=[rgb[0]-base[0],rgb[1]-base[1],rgb[2]-base[2]];return Promise.all(raws.map(raw=>new Promise(resolve=>{const im=new Image();im.onload=()=>{try{const c=document.createElement("canvas");c.width=im.naturalWidth;c.height=im.naturalHeight;const g=c.getContext("2d",{willReadFrequently:true});g.drawImage(im,0,0);const px=g.getImageData(0,0,c.width,c.height),d=px.data;for(let i=0;i<d.length;i+=4){if(!d[i+3])continue;d[i]=Math.max(0,Math.min(255,d[i]+delta[0]));d[i+1]=Math.max(0,Math.min(255,d[i+1]+delta[1]));d[i+2]=Math.max(0,Math.min(255,d[i+2]+delta[2]));}g.putImageData(px,0,0);resolve(c.toDataURL("image/png"));}catch(_){resolve(raw);}};im.onerror=()=>resolve(raw);im.src=raw;})));})();this.auraTintCache.set(key,task);return task;};

App.prototype.assetPickerRowsForTarget=function(target,kind){if(S(kind)==="audio")return A(this.source&&this.source.bgmFiles);const all=A(this.source&&this.source.allGraphics),t=L(target);if(t.startsWith("environment.battleback")||t.startsWith("environment.backgroundgraphic"))return all.filter(x=>L(x&&x.projectPath).startsWith("graphics/battlebacks/"));if(t.startsWith("aura:")){const scoped=all.filter(x=>{const p=L(x&&x.projectPath);return p.startsWith("graphics/battlescenestudio/auras/")||p.startsWith("graphics/battleanimations/")||p.startsWith("graphics/animations/")||p.includes("battle animation studio")||p.includes("/particles/")||p.includes("/particle/");});return scoped.length?scoped:A(this.source&&this.source.auraGraphics);}return all;};
App.prototype.assetPickerRows=function(kind){return this.assetPickerRowsForTarget(this.assetPicker&&this.assetPicker.target||"",kind);};
App.prototype.assetScopeLabel=function(target,kind){if(S(kind)==="audio")return "Audio/BGM";const t=L(target);if(t.startsWith("environment."))return "Graphics/Battlebacks";if(t.startsWith("aura:"))return "Aura: BSS Auras · BAS Particles · BattleAnimations · Animations";return "Graphics";};
const _bss644RenderAssetPicker=App.prototype.renderAssetPicker;
App.prototype.renderAssetPicker=function(){_bss644RenderAssetPicker.call(this);const modal=this.root.querySelector("[data-asset-picker-modal]");if(!modal||!this.assetPicker)return;const small=modal.querySelector(".bss-modal-head small");if(small){const count=this.assetPickerResults().length;small.innerHTML=`${E(this.assetScopeLabel(this.assetPicker.target,this.assetPicker.kind))} · <span data-asset-result-count>${count} resultados</span>`;}};

App.prototype.libraryRows=function(){const groups=A(this.studio.groups),active=groups.find(g=>g.id===this.activeGroup)||groups[0],q=L(this.search);return A(this.studio.blueprints).filter(b=>(!active||b.groupId===active.id)&&(!q||L(`${b.name} ${b.key} ${b.category||""}`).includes(q)));};
App.prototype.renderLibrary=function(){
  const groups=A(this.studio.groups),active=groups.find(g=>g.id===this.activeGroup)||groups.find(g=>g.id===(this.studio.global&&this.studio.global.mainGroupId))||groups[0];if(active)this.activeGroup=active.id;const rows=this.libraryRows(),selected=this.librarySelected||new Set();
  this.body.innerHTML=`<section class="bss-library"><div class="bss-libhead"><select class="bss-select bss-groupselect" data-group-filter>${groups.map(g=>`<option value="${E(g.id)}" ${g.id===this.activeGroup?"selected":""}>${E(g.name)}${g.system?" · principal":""}</option>`).join("")}</select><button class="bss-btn" data-act="group-new">＋ Librería</button><button class="bss-btn" data-act="group-rename">Renombrar</button>${active&&!active.system?`<button class="bss-btn danger" data-act="group-delete">Eliminar librería</button>`:""}<input class="bss-search" data-search placeholder="Buscar combates/categorías…" value="${E(this.search)}"><button class="bss-btn primary" data-act="new">＋ Nuevo combate</button></div><div class="bss-library-batchbar"><button class="bss-btn" data-act="battle-import">Importar…</button><button class="bss-btn" data-act="battle-export-library">Exportar librería</button><button class="bss-btn" data-act="battle-export-libraries">Exportar librerías…</button><span class="bss-divider"></span><button class="bss-btn" data-act="battle-select-visible">Seleccionar visibles</button><button class="bss-btn" data-act="battle-clear-selection" ${selected.size?"":"disabled"}>Limpiar</button><button class="bss-btn" data-act="battle-export-selected" ${selected.size?"":"disabled"}>Exportar selección (${selected.size})</button><button class="bss-btn" data-act="battle-duplicate-selected" ${selected.size===1?"":"disabled"}>Duplicar</button><button class="bss-btn danger" data-act="battle-delete-selected" ${selected.size?"":"disabled"}>Eliminar selección</button><span class="bss-note">${rows.length} combate${rows.length===1?"":"s"}</span></div>${active&&active.system?`<div class="bss-mainlib-note"><b>${E(active.name)}</b> es la librería principal.</div>`:""}<div class="bss-grid">${rows.map(b=>`<article class="bss-card ${selected.has(S(b.id))?"selected":""}" data-card="${E(b.id)}"><label class="bss-card-select"><input type="checkbox" data-library-select="${E(b.id)}" ${selected.has(S(b.id))?"checked":""}><span>Seleccionar</span></label><div class="bss-card-art"><span class="kind">${E(this.battleTypeLabel(b))} · ${E(b.setup.formation)}</span><div class="bss-icon ph" data-card-art="${E(b.id)}">?</div></div><div class="bss-card-body"><input class="bss-input" data-name="${E(b.id)}" value="${E(b.name)}"><small>${E(b.category?`${b.category} · `:"")}${E(b.setup.kind==="trainer"?`${b.setup.trainer.name||"Trainer"} · ${b.teams.foes.length} Pokémon`:`${b.teams.foes[0]&&b.teams.foes[0].species||"Wild"} · Lv.${b.teams.foes[0]&&b.teams.foes[0].level||50}`)}</small><select class="bss-select bss-card-group" data-move-group="${E(b.id)}">${groups.map(g=>`<option value="${E(g.id)}" ${b.groupId===g.id?"selected":""}>${E(g.name)}</option>`).join("")}</select><div class="bss-card-actions"><button class="bss-btn primary" data-open="${E(b.id)}">Abrir</button><button class="bss-btn" data-test="${E(b.id)}">Probar</button><button class="bss-btn" data-event="${E(b.id)}">Comando</button><button class="bss-btn" data-act="battle-export-one" data-battle-id="${E(b.id)}">Exportar</button><button class="bss-btn" data-act="battle-duplicate-one" data-battle-id="${E(b.id)}">Duplicar</button><button class="bss-btn danger" data-act="battle-delete-one" data-battle-id="${E(b.id)}">Borrar</button></div></div></article>`).join("")||`<div class="bss-empty">No hay combates en esta librería.</div>`}</div></section>`;this.hydrateLibraryArt();
};
App.prototype.downloadJSON=function(filename,data){try{const blob=new Blob([JSON.stringify(data,null,2)],{type:"application/json"}),url=URL.createObjectURL(blob),a=document.createElement("a");a.href=url;a.download=S(filename||"bss_export.json");document.body.appendChild(a);a.click();a.remove();setTimeout(()=>URL.revokeObjectURL(url),1500);return true;}catch(e){this.toast("No pude exportar: "+S(e&&e.message||e),true);return false;}};
App.prototype.exportBattlePackage=function(kind,ids,groupIds){ids=A(ids).map(S);groupIds=A(groupIds).map(S);let bps=A(this.studio.blueprints);if(ids.length)bps=bps.filter(b=>ids.includes(S(b.id)));else if(groupIds.length)bps=bps.filter(b=>groupIds.includes(S(b.groupId)));const needed=new Set(groupIds.length?groupIds:bps.map(b=>S(b.groupId))),groups=A(this.studio.groups).filter(g=>needed.has(S(g.id)));const pkg={format:"battle-scene-studio-export",formatVersion:1,editorVersion:BSS_VERSION,kind:S(kind||"battles"),exportedAt:Date.now(),groups:JSON.parse(JSON.stringify(groups)),blueprints:JSON.parse(JSON.stringify(bps))};const label=kind==="library"?(groups[0]&&groups[0].name||"library"):kind==="libraries"?"libraries":bps.length===1?(bps[0].name||"battle"):"battles";this.downloadJSON(`BSS_${slug(label)}_${Date.now().toString(36)}.json`,pkg);this.toast(`Exportados ${bps.length} combate(s).`);};
App.prototype.duplicateBattle=function(id){const src=A(this.studio.blueprints).find(b=>S(b.id)===S(id));if(!src)return null;const raw=JSON.parse(JSON.stringify(src));raw.id=`battle_${Date.now().toString(36)}_${Math.random().toString(36).slice(2,7)}`;raw.name=`${src.name} Copy`;raw.key=this.uniqueKey(raw.name,raw.id);raw.updatedAt=Date.now();const bp=normalizeBlueprint(raw);bp.id=raw.id;bp.key=this.uniqueKey(bp.key,bp.id);this.studio.blueprints.push(bp);this.saveSoon();return bp;};
App.prototype.deleteBattleIds=function(ids){const set=new Set(A(ids).map(S));if(!set.size)return;this.studio.blueprints=A(this.studio.blueprints).filter(b=>!set.has(S(b.id)));if(set.has(S(this.activeId)))this.activeId=this.studio.blueprints[0]&&this.studio.blueprints[0].id||null;set.forEach(id=>this.librarySelected.delete(id));this.saveSoon();this.renderLibrary();};
App.prototype.openBattleImport=function(){const input=document.createElement("input");input.type="file";input.accept=".json,application/json";input.multiple=true;input.style.display="none";document.body.appendChild(input);input.addEventListener("change",async()=>{try{let count=0;for(const file of Array.from(input.files||[])){const text=await file.text(),raw=JSON.parse(text);count+=this.importBattlePayload(raw);}if(count){this.saveSoon();this.toast(`Importados ${count} combate(s).`);this.renderLibrary();}else this.toast("No encontré combates BSS válidos en esos archivos.",true);}catch(e){this.toast("Import failed: "+S(e&&e.message||e),true);}finally{input.remove();}},{once:true});input.click();};
App.prototype.importBattlePayload=function(raw){if(!raw||typeof raw!=="object")return 0;let groups=[],bps=[];if(Array.isArray(raw.blueprints)){groups=A(raw.groups);bps=A(raw.blueprints);}else if(raw.setup&&raw.teams)bps=[raw];else return 0;const groupMap=new Map();for(const g of groups){if(!g||!g.id)continue;const old=A(this.studio.groups).find(x=>S(x.id)===S(g.id));if(old){groupMap.set(S(g.id),S(old.id));continue;}const id=`group_${slug(g.name||g.id)}_${Math.random().toString(36).slice(2,6)}`;this.studio.groups.push({id,name:S(g.name||"Imported library"),system:false});groupMap.set(S(g.id),id);}let count=0;for(const source of bps){try{const clone=JSON.parse(JSON.stringify(source)),oldGroup=S(clone.groupId),bp=normalizeBlueprint(clone);bp.id=`battle_${Date.now().toString(36)}_${Math.random().toString(36).slice(2,8)}`;bp.groupId=groupMap.get(oldGroup)||(A(this.studio.groups).some(g=>S(g.id)===oldGroup)?oldGroup:this.activeGroup||this.studio.global.mainGroupId||"wild_main");bp.key=this.uniqueKey(bp.key||bp.name,bp.id);bp.updatedAt=Date.now();this.studio.blueprints.push(bp);count++;}catch(_){}}return count;};
App.prototype.renderLibraryExportGroups=function(){const old=this.root.querySelector("[data-bss-library-export-groups]");if(old)old.remove();const modal=document.createElement("div");modal.className="bss-modal";modal.dataset.bssLibraryExportGroups="1";modal.innerHTML=`<div class="bss-modal-card bss-library-export-card"><div class="bss-modal-head"><div><b>Exportar múltiples librerías</b><small>El JSON conserva librerías + combates seleccionados.</small></div><button class="bss-btn" data-act="battle-export-groups-close">Cerrar</button></div><div class="bss-library-group-list">${A(this.studio.groups).map(g=>`<label class="bss-check"><input type="checkbox" data-library-export-group="${E(g.id)}" ${this.libraryExportSelectedGroups.has(S(g.id))?"checked":""}> ${E(g.name)} <small>${A(this.studio.blueprints).filter(b=>b.groupId===g.id).length} combates</small></label>`).join("")}</div><div class="bss-modal-actions"><button class="bss-btn" data-act="battle-export-groups-all">Todas</button><button class="bss-btn primary" data-act="battle-export-groups-go" ${this.libraryExportSelectedGroups.size?"":"disabled"}>Exportar seleccionadas</button></div></div>`;this.root.appendChild(modal);};
App.prototype.handleExtendedInput=function(t){if(t.dataset.librarySelect!=null){const id=S(t.dataset.librarySelect);if(t.checked)this.librarySelected.add(id);else this.librarySelected.delete(id);this.renderLibrary();return true;}if(t.dataset.libraryExportGroup!=null){const id=S(t.dataset.libraryExportGroup);if(t.checked)this.libraryExportSelectedGroups.add(id);else this.libraryExportSelectedGroups.delete(id);this.renderLibraryExportGroups();return true;}return false;};
App.prototype.handleExtendedClick=function(t){const act=S(t.dataset.act);if(!act.startsWith("battle-"))return false;if(act==="battle-import"){this.openBattleImport();return true;}if(act==="battle-export-one"){this.exportBattlePackage("battle",[S(t.dataset.battleId)],[]);return true;}if(act==="battle-select-visible"){this.libraryRows().forEach(b=>this.librarySelected.add(S(b.id)));this.renderLibrary();return true;}if(act==="battle-clear-selection"){this.librarySelected.clear();this.renderLibrary();return true;}if(act==="battle-export-selected"){this.exportBattlePackage("battles",[...this.librarySelected],[]);return true;}if(act==="battle-export-library"){this.exportBattlePackage("library",[],[this.activeGroup]);return true;}if(act==="battle-export-libraries"){this.libraryExportSelectedGroups=new Set([S(this.activeGroup)]);this.renderLibraryExportGroups();return true;}if(act==="battle-export-groups-close"){const m=this.root.querySelector("[data-bss-library-export-groups]");if(m)m.remove();return true;}if(act==="battle-export-groups-all"){this.libraryExportSelectedGroups=new Set(A(this.studio.groups).map(g=>S(g.id)));this.renderLibraryExportGroups();return true;}if(act==="battle-export-groups-go"){this.exportBattlePackage("libraries",[],[...this.libraryExportSelectedGroups]);const m=this.root.querySelector("[data-bss-library-export-groups]");if(m)m.remove();return true;}if(act==="battle-duplicate-one"){const bp=this.duplicateBattle(t.dataset.battleId);if(bp){this.librarySelected=new Set([S(bp.id)]);this.renderLibrary();}return true;}if(act==="battle-duplicate-selected"){const id=[...this.librarySelected][0],bp=this.duplicateBattle(id);if(bp){this.librarySelected=new Set([S(bp.id)]);this.renderLibrary();}return true;}if(act==="battle-delete-one"){const id=S(t.dataset.battleId),b=A(this.studio.blueprints).find(x=>S(x.id)===id);if(b&&confirm(`¿Borrar “${b.name}”?`))this.deleteBattleIds([id]);return true;}if(act==="battle-delete-selected"){const ids=[...this.librarySelected];if(ids.length&&confirm(`¿Borrar ${ids.length} combate(s) seleccionados?`))this.deleteBattleIds(ids);return true;}return false;};

App.prototype.bossHTML=function(b){let html=_bss644BossHTML.call(this,b),c=b.boss||{},h=c.hud||{},foe=A(b.teams&&b.teams.foes)[Math.max(0,N(c.foeIndex,0))]||{},segments=Math.max(1,Math.min(24,N(h.shieldSegments,5))),shownName=S(h.displayName||"").trim()||S(foe.species||"Boss"),bossLabel=`${h.showTitle!==false&&S(c.title)?S(c.title)+" · ":""}${shownName.replaceAll?shownName.replaceAll("{1}",S(foe.species||"Boss")):shownName.split("{1}").join(S(foe.species||"Boss"))}${h.showLevel!==false?`  Lv. ${N(foe.level,50)}`:""}`,shieldPreview=h.shieldEnabled?`<div class="bss-boss-shield-preview">${Array.from({length:segments},(_,i)=>`<i title="Segmento ${i+1}"></i>`).join("")}</div>`:"";const block=`<details open class="bss-optiongroup bss-boss-hud-editor"><summary>Boss HUD / escudo</summary><p class="bss-note">Usa la barra Long de Deluxe Battle Kit y los gráficos de escudo de Raid Battles cuando están disponibles. El databox normal del Boss se oculta mientras esta barra está activa.</p><div class="bss-boss-hud-preview"><b data-boss-hud-preview-label>${E(bossLabel)}</b><div class="bss-boss-hp-preview"><i style="width:72%"></i></div>${shieldPreview}<small>Preview referencial · el HP y los segmentos reales se actualizan ingame.</small></div><label class="bss-check"><input type="checkbox" data-bind="boss.hud.enabled" ${h.enabled!==false?"checked":""}> Mostrar barra de Boss</label>${this.field("Posición",`<select class="bss-select" data-bind="boss.hud.position"><option value="top" ${S(h.position||"top")==="top"?"selected":""}>Barra superior BSS</option><option value="databox" ${S(h.position)==="databox"?"selected":""}>Junto al databox (compatibilidad)</option></select>`)}<label class="bss-check"><input type="checkbox" data-bind="boss.hud.showTitle" ${h.showTitle!==false?"checked":""}> Mostrar etiqueta del Boss</label><label class="bss-check"><input type="checkbox" data-bind="boss.hud.showLevel" ${h.showLevel!==false?"checked":""}> Mostrar nivel</label>${this.field("Nombre mostrado en la Boss Bar",`<input class="bss-input" data-bind="boss.hud.displayName" value="${E(h.displayName||"")}" placeholder="Vacío = nombre del Pokémon"><span class="bss-note">Puedes usar {1} para insertar el nombre real del Pokémon.</span>`)}<hr><label class="bss-check"><input type="checkbox" data-bind="boss.hud.shieldEnabled" ${h.shieldEnabled?"checked":""}> Activar escudo segmentado</label>${this.field("Segmentos",`<input class="bss-input" type="number" min="1" max="24" data-bind="boss.hud.shieldSegments" value="${N(h.shieldSegments,5)}">`)}${this.field("Inicio del escudo",`<select class="bss-select" data-bind="boss.hud.shieldStartMode"><option value="battle_start" ${S(h.shieldStartMode||"battle_start")==="battle_start"?"selected":""}>Desde el inicio del combate</option><option value="hp_threshold" ${S(h.shieldStartMode)==="hp_threshold"?"selected":""}>Al bajar a cierto HP</option></select><span class="bss-note">Desde el inicio hace aparecer los segmentos al presentar al Boss. El umbral permite reservarlos para una fase posterior.</span>`)}${this.field("Umbral de HP (%)",`<input class="bss-input" type="number" min="1" max="100" data-bind="boss.hud.shieldTriggerPercent" value="${N(h.shieldTriggerPercent,50)}">`)}${this.field("Daño que atraviesa (%)",`<input class="bss-input" type="number" min="1" max="100" data-bind="boss.hud.shieldDamagePercent" value="${N(h.shieldDamagePercent,5)}"><span class="bss-note">Como referencia, Raid Battles reduce el daño al 5% mientras hay barrera.</span>`)}${this.field("Daño al romper (% HP)",`<input class="bss-input" type="number" min="0" max="100" step="0.5" data-bind="boss.hud.shieldBreakDamagePercent" value="${N(h.shieldBreakDamagePercent,12.5)}">`)}${this.field("Mensaje de escudo",`<input class="bss-input" data-bind="boss.hud.shieldMessage" value="${E(h.shieldMessage||"¡Una barrera misteriosa protege a {1}!")}">`)}${this.field("Mensaje al romper",`<input class="bss-input" data-bind="boss.hud.shieldBreakMessage" value="${E(h.shieldBreakMessage||"¡La barrera de {1} se ha roto!")}">`)}</details>`;const i=html.lastIndexOf("</div>");return i>=0?html.slice(0,i)+block+html.slice(i):html+block;};

export function renderBattleSceneStudio(ctx,host){let app=null;try{app=new App(ctx,host);}catch(e){host.innerHTML=`<div style="padding:24px;background:#111;color:#fff;height:100%"><h2>Battle Scene Studio</h2><pre>${E(e&&e.stack||e)}</pre></div>`;}return()=>app&&app.destroy();}


/* v0.6.49 · Boss residual tuning + BSS-native boss attributes */
const BSS649_NATIVE_IMMUNITIES=[
  ["Estados",[["SLEEP","Sueño"],["POISON","Veneno"],["BURN","Quemadura"],["PARALYSIS","Parálisis"],["FROZEN","Congelación"],["FROSTBITE","Frostbite"],["DROWSY","Drowsy"],["CONFUSION","Confusión"],["ATTRACT","Enamoramiento"],["ALLSTATUS","Todos los estados"]]],
  ["Combate",[["FLINCH","Amedrentamiento / flinch (perder turno)"],["CRITICALHIT","Golpes críticos"],["STATDROPS","Bajadas de estadísticas"],["PPLOSS","Pérdida de PP"],["TYPECHANGE","Cambio de tipo"]]],
  ["Protecciones",[["ITEMREMOVAL","Quitar/cambiar objeto"],["ABILITYREMOVAL","Quitar/cambiar habilidad"],["INDIRECT","Daño indirecto / residual"],["RECOIL","Recoil / autodaño de ataques del Boss"],["DISABLE","Disable/Taunt/Encore/etc."],["OHKO","OHKO / KO instantáneo"],["SELFKO","Auto-KO"],["ESCAPE","Forzar huida/cambio"],["TRANSFORM","Transform/Imposter"]]]
];
const _bss648BossHTML=App.prototype.bossHTML;
App.prototype.bossHTML=function(b){
  let html=_bss648BossHTML.call(this,b),boss=b.boss||{},mech=boss.mechanics||{},res=mech.residual||{},attributes=boss.attributes||{};
  const selected=new Set(A(attributes.immunities).map(U));
  const residual=`<details class="bss-optiongroup bss-boss-mechanics-editor"><summary>Daño residual del Boss</summary>
    <p class="bss-note">Reduce únicamente el daño entre turnos recibido por el Boss. <b>100%</b> = daño normal, <b>50%</b> = la mitad, <b>0%</b> = no recibe daño de esa categoría. No cambia el daño directo de los ataques ni el <b>recoil/autodaño</b> de movimientos como Take Down, Brave Bird, Steel Beam o daño por fallar un salto.</p>
    <p class="bss-note"><b>Recoil se controla aparte:</b> Atributos nativos del Boss → inmunidad <code>:RECOIL</code>. La casilla de inmunidad es suficiente; no depende del multiplicador de PS.</p>
    <label class="bss-check"><input type="checkbox" data-bind="boss.mechanics.residual.enabled" ${res.enabled?"checked":""}> Usar reducción personalizada de daño residual</label>
    <div class="bss-boss-residual-grid">
      ${this.field("Trampas persistentes",`<input class="bss-input" type="number" min="0" max="100" step="1" data-bind="boss.mechanics.residual.trappingPercent" value="${N(res.trappingPercent,50)}"><label class="bss-check compact"><input type="checkbox" data-bind="boss.mechanics.residual.trappingApplyEffect" ${res.trappingApplyEffect!==false?"checked":""}> Mantener el atrapamiento</label><span class="bss-note">Si lo desactivas, Bind/Wrap/Fire Spin/Whirlpool y equivalentes hacen el golpe inicial pero no dejan el efecto persistente.</span>`)}
      ${this.field("Efectos de movimientos",`<input class="bss-input" type="number" min="0" max="100" step="1" data-bind="boss.mechanics.residual.moveEffectPercent" value="${N(res.moveEffectPercent,50)}"><label class="bss-check compact"><input type="checkbox" data-bind="boss.mechanics.residual.moveEffectApplyEffect" ${res.moveEffectApplyEffect!==false?"checked":""}> Mantener efecto persistente</label><span class="bss-note">Controla Leech Seed, Nightmare, Curse, Salt Cure y efectos persistentes equivalentes que BSS reconoce.</span>`)}
      ${this.field("Estados alterados",`<input class="bss-input" type="number" min="0" max="100" step="1" data-bind="boss.mechanics.residual.statusPercent" value="${N(res.statusPercent,50)}"><label class="bss-check compact"><input type="checkbox" data-bind="boss.mechanics.residual.statusApplyEffect" ${res.statusApplyEffect!==false?"checked":""}> Permitir aplicar el estado</label><span class="bss-note">Desactivado = el Boss no conserva Poison/Toxic, Burn, Frostbite ni otros estados externos.</span>`)}
      ${this.field("Clima",`<input class="bss-input" type="number" min="0" max="100" step="1" data-bind="boss.mechanics.residual.weatherPercent" value="${N(res.weatherPercent,50)}"><span class="bss-note">Sandstorm, Hail/Shadow Sky y demás daño que pase por el daño EOR de clima.</span>`)}
    </div>
  </details>`;
  const immunityGroups=BSS649_NATIVE_IMMUNITIES.map(([group,rows])=>`<div class="bss-dbk-immunity-group"><b>${E(group)}</b><div class="bss-dbk-immunity-grid">${rows.map(([id,label])=>`<label class="bss-dbk-immunity"><input type="checkbox" data-boss-native-immunity="${E(id)}" ${selected.has(id)?"checked":""}><span><strong>${E(label)}</strong><small>:${E(id)}</small></span></label>`).join("")}</div></div>`).join("");
  const dbkBlock=`<details class="bss-optiongroup bss-boss-dbk-editor"><summary>Atributos nativos del Boss</summary>
    <p class="bss-note">Estas propiedades pertenecen a BSS. No necesitan Deluxe Battle Kit. Si DBK está instalado puede coexistir, pero BSS es la autoridad de este combate.</p>
    <label class="bss-check"><input type="checkbox" data-bind="boss.attributes.enabled" ${attributes.enabled?"checked":""}> Activar multiplicador de PS del Boss</label>
    <div class="bss-aura-explain compact"><b>Inmunidades independientes</b><span>Cada inmunidad marcada abajo está activa por sí sola. Este interruptor sólo decide si se aplica el multiplicador de PS.</span></div>
    ${this.field("Multiplicador de PS",`<input class="bss-input" type="number" min="1" step="1" data-bind="boss.attributes.hpMultiplier" value="${N(attributes.hpMultiplier,1)}"><span class="bss-note">1 = PS normales · 3 = x3 PS · 10 = x10 PS. Sólo se aplica cuando el interruptor anterior está activo.</span>`)}
    <div class="bss-dbk-immunities"><div class="bss-aura-explain compact"><b>Inmunidades BSS</b><span><b>INDIRECT</b> bloquea daño indirecto/residual. <b>RECOIL</b> bloquea el autodaño causado por ataques usados por el propio Boss. <b>FLINCH</b> sólo evita perder el turno; no tiene relación con recoil.</span></div>${immunityGroups}</div>
  </details>`;
  const i=html.lastIndexOf("</div>");
  return i>=0?html.slice(0,i)+residual+dbkBlock+html.slice(i):html+residual+dbkBlock;
};
const _bss648ExtendedInput=App.prototype.handleExtendedInput;
App.prototype.handleExtendedInput=function(t,e){
  if(t&&t.dataset&&t.dataset.bossNativeImmunity!=null){
    const b=this.battle();if(!b)return true;
    b.boss=b.boss||{};b.boss.attributes=b.boss.attributes||{enabled:false,hpMultiplier:1,immunities:[]};
    const id=U(t.dataset.bossNativeImmunity),set=new Set(A(b.boss.attributes.immunities).map(U));
    if(t.checked)set.add(id);else set.delete(id);
    b.boss.attributes.immunities=Array.from(set);
    this.touch();this.refreshInspector();return true;
  }
  return _bss648ExtendedInput ? !!_bss648ExtendedInput.call(this,t,e) : false;
};


//=============================================================================
// v0.6.52 · input-safe inspector, live Boss label, Blueprint subnavigation.
//=============================================================================
const _bss650RenderEditor=App.prototype.renderEditor;
App.prototype.renderEditor=function(){
  const ret=_bss650RenderEditor.call(this);
  this.bss650HydrateInspectorSubnav();
  return ret;
};
App.prototype.bss650HydrateInspectorSubnav=function(){
  const host=this.body&&this.body.querySelector("[data-inspector-subnav]"),inner=this.body&&this.body.querySelector(".bss-inspector-inner");
  if(!host||!inner)return;
  const rows=[],seen=new Set();
  [...inner.querySelectorAll("details.bss-optiongroup, .bss-subpanel")].forEach((node,i)=>{
    const label=node.matches("details")?S(node.querySelector(":scope > summary")&&node.querySelector(":scope > summary").textContent):S(node.querySelector(":scope > b")&&node.querySelector(":scope > b").textContent);
    const clean=label.trim().replace(/\s+/g," ");
    if(!clean||seen.has(clean))return;seen.add(clean);
    const id=`bss-sub-${this.section}-${rows.length}`;node.dataset.bssSubsection=id;rows.push([id,clean,node]);
  });
  const tpl=document.createElement("template");
  tpl.innerHTML=rows.length?rows.map(([id,label])=>`<button class="bss-subjump" type="button" data-inspector-jump="${E(id)}">${E(label)}</button>`).join(""):`<span class="bss-subjump-empty">Sin subsecciones</span>`;
  host.replaceChildren(tpl.content.cloneNode(true));
};
App.prototype.bss650JumpInspector=function(id){
  const scroller=this.body&&this.body.querySelector(".bss-inspector"),node=this.body&&this.body.querySelector(`[data-bss-subsection="${CSS.escape(S(id))}"]`);
  if(!scroller||!node)return false;
  if(node.matches("details"))node.open=true;
  const sr=scroller.getBoundingClientRect(),nr=node.getBoundingClientRect(),top=scroller.scrollTop+(nr.top-sr.top)-76;
  try{scroller.scrollTo({top:Math.max(0,top),behavior:"smooth"});}catch(_){scroller.scrollTop=Math.max(0,top);}
  return true;
};
App.prototype.bss650BossHudLabel=function(){
  const b=this.battle();if(!b)return "";
  const c=b.boss||{},h=c.hud||{},foe=A(b.teams&&b.teams.foes)[Math.max(0,N(c.foeIndex,0))]||{},real=S(foe.species||"Boss"),shown=S(h.displayName||"").trim()||real;
  const name=shown.split("{1}").join(real);
  return `${h.showTitle!==false&&S(c.title)?S(c.title)+" · ":""}${name}${h.showLevel!==false?`  Lv. ${N(foe.level,50)}`:""}`;
};
App.prototype.bss650RefreshBossHudLabel=function(){
  const el=this.body&&this.body.querySelector("[data-boss-hud-preview-label]");if(el)el.textContent=this.bss650BossHudLabel();
};
const _bss650RefreshInspectorImmediate=App.prototype.refreshInspector;
App.prototype.refreshInspector=function(preserveScroll=true){
  if(this._bss650InputDispatch){
    clearTimeout(this._bss650InspectorTimer);
    const active=this.activeId,section=this.section,screen=this.screen;
    this._bss650InspectorTimer=setTimeout(()=>{this._bss650InspectorTimer=null;if(this.activeId===active&&this.section===section&&this.screen===screen)this.refreshInspector(preserveScroll);},24);
    return;
  }
  const b=this.battle(),inner=this.body&&this.body.querySelector(".bss-inspector-inner"),scroller=this.body&&this.body.querySelector(".bss-inspector");
  if(!b||!inner)return;
  const oldTop=preserveScroll&&scroller?scroller.scrollTop:0,tpl=document.createElement("template");
  tpl.innerHTML=this.inspectorHTML(b);
  inner.replaceChildren(tpl.content.cloneNode(true));
  this.body.querySelectorAll("[data-section]").forEach(x=>x.classList.toggle("active",x.dataset.section===this.section));
  this.bss650HydrateInspectorSubnav();
  if(scroller)requestAnimationFrame(()=>{if(scroller.isConnected)scroller.scrollTop=preserveScroll?oldTop:0;});
  this.hydrateInspectorIcons();
  if(["boss","aura"].includes(this.section)){this.hydrateAuraTestBattler();this.hydrateAuraRuntimePreview();this.startAuraPreviewLoop();}
  if(this.pokemonEditor)this.renderPokemonEditor();
};
const _bss650OnInput=App.prototype.onInput;
App.prototype.onInput=function(e){
  const t=e&&e.target;
  if(!t||t.nodeType!==1||!t.dataset||t.isConnected===false)return;
  // Selects/checkboxes commonly emit both input and change. Rebuilding a panel
  // from inside either native event can race the browser's own blur handler and
  // produce the "node is no longer a child" innerHTML exception. Process the
  // final value once, on the next task, after the native event is complete.
  if(!(e&&e._bss650Deferred)&&(t.tagName==="SELECT"||t.type==="checkbox")){
    const token=`${t.tagName}|${t.type}|${S(t.value)}|${t.checked?1:0}`;
    if(t._bss650QueuedToken===token)return;
    t._bss650QueuedToken=token;
    setTimeout(()=>{
      if(!t.isConnected)return;
      try{delete t._bss650QueuedToken;}catch(_){t._bss650QueuedToken="";}
      this.onInput({target:t,type:e&&e.type||"change",_bss650Deferred:true});
    },0);
    return;
  }
  this._bss650InputDispatch=true;
  try{
    const ret=_bss650OnInput.call(this,e);
    const path=S(t.dataset&&t.dataset.bind);
    if(path==="boss.hud.displayName"||path==="boss.hud.showTitle"||path==="boss.hud.showLevel"||path==="boss.title")this.bss650RefreshBossHudLabel();
    return ret;
  }catch(err){
    const msg=S(err&&err.message);
    if(msg.includes("toLowerCase")||msg.includes("innerHTML")){
      this.reportError("input",err);return;
    }
    throw err;
  }finally{this._bss650InputDispatch=false;}
};
const _bss650OnClick=App.prototype.onClick;
App.prototype.onClick=function(e){
  const raw=e&&e.target,t=raw&&raw.closest?raw.closest("button,[data-inspector-jump]"):null;
  if(t&&t.dataset&&t.dataset.inspectorJump)return this.bss650JumpInspector(t.dataset.inspectorJump);
  return _bss650OnClick.call(this,e);
};


//=============================================================================
// v0.6.52 · Boss/Totem Blueprint workspace revamp.
// The generic battle preview is removed from this section so the Boss controls
// can use the full editor width. BossHUD no longer wastes space on a fake inline
// preview; configuration is grouped by intent and navigable as compact cards.
//=============================================================================
const _bss652RenderEditor=App.prototype.renderEditor;
App.prototype.renderEditor=function(){
  const forceBoss=this.section==="boss",saved=this.previewCollapsed;
  if(forceBoss)this.previewCollapsed=true;
  const ret=_bss652RenderEditor.call(this);
  if(forceBoss)this.previewCollapsed=saved;
  this.bss652ApplyBossWorkspaceLayout();
  return ret;
};
const _bss652RefreshInspector=App.prototype.refreshInspector;
App.prototype.refreshInspector=function(...args){
  const ret=_bss652RefreshInspector.apply(this,args);
  this.bss652ApplyBossWorkspaceLayout();
  return ret;
};
App.prototype.bss652ApplyBossWorkspaceLayout=function(){
  const ed=this.body&&this.body.querySelector(".bss-editor");if(!ed)return;
  ed.classList.toggle("bss-boss-focus",this.section==="boss");
};

App.prototype.bossHTML=function(b){
  const boss=b.boss||{},foes=A(b.teams&&b.teams.foes),stats=boss.stats||{},h=boss.hud||{},mech=boss.mechanics||{},res=mech.residual||{},attributes=boss.attributes||{},capture=boss.capture||{},breakStats=h.shieldBreakStats||{},breakDrop=breakStats.drop||{},breakRaise=breakStats.raise||{};
  const shieldSeRows=A(this.source&&this.source.seFiles),shieldSeOptions=shieldSeRows.slice(0,1600).map(row=>{const v=S(row&& (row.value||row.relativePath||row.filename||row.name)).replace(/\\/g,"/").replace(/^Audio\/SE\//i,"").replace(/\.[^.]+$/g,"");return v?`<option value="${E(v)}"></option>`:"";}).join("");
  const foeIndex=Math.max(0,Math.min(Math.max(0,foes.length-1),N(boss.foeIndex,0))),selected=new Set(A(attributes.immunities).map(U));
  const foe=foes[foeIndex]||{},bossName=S(foe.species||"Pokémon"),wild=b.setup&&b.setup.kind!=="trainer";
  const statRows=[["ATTACK","Ataque"],["DEFENSE","Defensa"],["SPECIAL_ATTACK","At. Esp."],["SPECIAL_DEFENSE","Def. Esp."],["SPEED","Velocidad"],["ACCURACY","Precisión"],["EVASION","Evasión"]];
  const immunities=BSS649_NATIVE_IMMUNITIES.map(([group,rows])=>`<section class="bss-boss-immunity-card"><b>${E(group)}</b><div class="bss-dbk-immunity-grid">${rows.map(([id,label])=>`<label class="bss-dbk-immunity"><input type="checkbox" data-boss-native-immunity="${E(id)}" ${selected.has(id)?"checked":""}><span><strong>${E(label)}</strong><small>:${E(id)}</small></span></label>`).join("")}</div></section>`).join("");
  const status=[boss.enabled?"Boss activo":"Boss desactivado",h.enabled!==false?"Boss HUD":"HUD oculto",h.shieldEnabled?`${N(h.shieldSegments,5)} escudos`:"Sin escudo",selected.size?`${selected.size} inmunidad(es)`:"Sin inmunidades",capture.enabled&&wild?"Capturable al derrotarlo":"Sin captura especial"];
  const autoAuraText=b.setup&&b.setup.kind==="trainer"?"¡El {1} rival está rodeado por un aura!":"¡El {1} salvaje está rodeado por un aura!";
  return `<div class="bss-panel bss-boss-workspace"><div class="bss-boss-workspace-head"><div><span class="bss-boss-kicker">BOSS / TOTEM</span><h2>${E(bossName)}${boss.title?` · ${E(boss.title)}`:""}</h2><p>Configura el Boss por bloques. Aura y SOS siguen siendo sistemas separados y se abren desde los accesos directos.</p></div><label class="bss-boss-master"><input type="checkbox" data-bind="boss.enabled" ${boss.enabled?"checked":""}><span><b>${boss.enabled?"Activo":"Inactivo"}</b><small>Boss / Totem</small></span></label></div><div class="bss-boss-statusline">${status.map(x=>`<span>${E(x)}</span>`).join("")}</div><div class="bss-boss-shortcuts"><button class="bss-btn primary" data-section="aura">✦ Aura</button><button class="bss-btn" data-section="sos">SOS</button><button class="bss-btn" data-act="open-aura-studio">Abrir Aura Studio</button></div><div class="bss-boss-cardgrid">

  <details open class="bss-optiongroup bss-boss-card"><summary><span>01</span> Identidad y presentación</summary><div class="bss-boss-cardbody"><div class="bss-boss-two">${this.field("Pokémon Boss",`<select class="bss-select" data-bind="boss.foeIndex">${foes.map((p,i)=>`<option value="${i}" ${foeIndex===i?"selected":""}>Slot ${i+1} · ${E(p.species||"Pokémon")} · Lv.${N(p.level,50)}</option>`).join("")}</select><span class="bss-note">Este es el Battler que BSS trata como Boss.</span>`)}${this.field("Etiqueta",`<input class="bss-input" data-bind="boss.title" value="${E(boss.title||"Totem")}" placeholder="Dominante / Totem / Alpha">`)}</div>${this.field("Mensaje de entrada",`<input class="bss-input" data-bind="boss.encounterMessage" value="${E(boss.encounterMessage||"")}" placeholder="¡El Pokémon Dominante {1} te ataca!"><span class="bss-note">{1} = nombre real del Pokémon.</span>`)}${this.field("Mensaje del aura",`<input class="bss-input" data-bind="boss.auraMessage" value="${E(boss.auraMessage||"")}" placeholder="${E(autoAuraText)}"><span class="bss-note">El rol (“dominante”, “rival”, etc.) lo escribes tú.</span>`)}</div></details>

  <details class="bss-optiongroup bss-boss-card"><summary><span>02</span> Boosts iniciales</summary><div class="bss-boss-cardbody"><p class="bss-note">Etapas de -6 a +6. Si Aura está activa, estos boosts disparan la presentación del Boss.</p><div class="bss-boss-stats bss-boss-stats-clean">${statRows.map(([id,label])=>`<label class="bss-boss-stat"><span>${E(label)}</span><input class="bss-input" type="number" min="-6" max="6" data-bind="boss.stats.${id}" value="${N(stats[id],0)}"></label>`).join("")}</div></div></details>

  <details class="bss-optiongroup bss-boss-card"><summary><span>03</span> Resistencia e inmunidades</summary><div class="bss-boss-cardbody"><label class="bss-check bss-boss-switch"><input type="checkbox" data-bind="boss.attributes.enabled" ${attributes.enabled?"checked":""}><span><b>Activar atributos especiales</b><small>${attributes.enabled?"Multiplicador de PS activo.":"Multiplicador de PS desactivado. Las inmunidades seleccionadas siguen siendo independientes y sí se aplican."}</small></span></label>${this.field("Multiplicador de PS",`<input class="bss-input" type="number" min="1" step="1" data-bind="boss.attributes.hpMultiplier" value="${N(attributes.hpMultiplier,1)}"><span class="bss-note">1 = normal · 3 = x3 · 10 = x10.</span>`)}<div class="bss-boss-immunity-help"><b>RECOIL</b> bloquea el autodaño provocado por los ataques del Boss. <b>INDIRECT</b> es exclusivamente daño residual/indirecto; son opciones distintas. Las inmunidades funcionan aunque el multiplicador de PS esté desactivado.</div><div class="bss-boss-immunity-groups">${immunities}</div></div></details>

  <details class="bss-optiongroup bss-boss-card"><summary><span>04</span> Daño residual</summary><div class="bss-boss-cardbody"><label class="bss-check bss-boss-switch"><input type="checkbox" data-bind="boss.mechanics.residual.enabled" ${res.enabled?"checked":""}><span><b>Usar reducción personalizada</b><small>100% = normal · 0% = inmune a esa fuente. Esto no controla recoil.</small></span></label><div class="bss-boss-residual-grid">${this.field("Trampas persistentes (%)",`<input class="bss-input" type="number" min="0" max="100" data-bind="boss.mechanics.residual.trappingPercent" value="${N(res.trappingPercent,50)}"><label class="bss-check compact"><input type="checkbox" data-bind="boss.mechanics.residual.trappingApplyEffect" ${res.trappingApplyEffect!==false?"checked":""}> Mantener efecto</label>`)}${this.field("Efectos de movimientos (%)",`<input class="bss-input" type="number" min="0" max="100" data-bind="boss.mechanics.residual.moveEffectPercent" value="${N(res.moveEffectPercent,50)}"><label class="bss-check compact"><input type="checkbox" data-bind="boss.mechanics.residual.moveEffectApplyEffect" ${res.moveEffectApplyEffect!==false?"checked":""}> Mantener efecto</label>`)}${this.field("Estados (%)",`<input class="bss-input" type="number" min="0" max="100" data-bind="boss.mechanics.residual.statusPercent" value="${N(res.statusPercent,50)}"><label class="bss-check compact"><input type="checkbox" data-bind="boss.mechanics.residual.statusApplyEffect" ${res.statusApplyEffect!==false?"checked":""}> Permitir estado</label>`)}${this.field("Clima (%)",`<input class="bss-input" type="number" min="0" max="100" data-bind="boss.mechanics.residual.weatherPercent" value="${N(res.weatherPercent,50)}">`)}</div></div></details>

  <details class="bss-optiongroup bss-boss-card"><summary><span>05</span> Boss HUD y escudo</summary><div class="bss-boss-cardbody"><div class="bss-boss-two"><label class="bss-check bss-boss-switch"><input type="checkbox" data-bind="boss.hud.enabled" ${h.enabled!==false?"checked":""}><span><b>Mostrar Boss Bar</b><small>Oculta el databox normal del Boss.</small></span></label><label class="bss-check bss-boss-switch"><input type="checkbox" data-bind="boss.hud.shieldEnabled" ${h.shieldEnabled?"checked":""}><span><b>Escudo segmentado</b><small>Fases estilo Raid.</small></span></label></div><div class="bss-boss-two">${this.field("Posición",`<select class="bss-select" data-bind="boss.hud.position"><option value="top" ${S(h.position||"top")==="top"?"selected":""}>Barra superior</option><option value="databox" ${S(h.position)==="databox"?"selected":""}>Zona de databox</option></select>`)}${this.field("Nombre mostrado",`<input class="bss-input" data-bind="boss.hud.displayName" value="${E(h.displayName||"")}" placeholder="Vacío = nombre real">`)}</div><div class="bss-boss-two">${this.field("Estilo de databox DBK",`<select class="bss-select" data-bind="boss.hud.databoxStyle"><option value="inherit" ${S(h.databoxStyle||"inherit")==="inherit"?"selected":""}>Heredar proyecto / Vanilla</option><option value="basic" ${S(h.databoxStyle)==="basic"?"selected":""}>DBK · Basic</option><option value="long" ${S(h.databoxStyle)==="long"?"selected":""}>DBK · Long</option></select><span class="bss-note">Es independiente de la Boss Bar: se usa cuando el databox normal del Boss está visible. Sólo se aplica si DBK Databox Styles está instalado. Long vuelve a Basic automáticamente cuando el lado tiene más de un Pokémon, igual que DBK.</span>`)}${this.field("Título del Boss en databox DBK",`<input class="bss-input" data-bind="boss.hud.databoxTitle" value="${E(h.databoxTitle||"")}" placeholder="Ej. {1} el Dominante"><span class="bss-note">Opcional. {1} = nombre del Boss. No se copia a los SOS aunque el Boss cambie de slot.</span>`)}</div><div class="bss-boss-inline-checks"><label><input type="checkbox" data-bind="boss.hud.showTitle" ${h.showTitle!==false?"checked":""}> Etiqueta</label><label><input type="checkbox" data-bind="boss.hud.showLevel" ${h.showLevel!==false?"checked":""}> Nivel</label></div><div class="bss-boss-two">${this.field("Segmentos",`<input class="bss-input" type="number" min="1" max="24" data-bind="boss.hud.shieldSegments" value="${N(h.shieldSegments,5)}">`)}${this.field("Inicio",`<select class="bss-select" data-bind="boss.hud.shieldStartMode"><option value="battle_start" ${S(h.shieldStartMode||"battle_start")==="battle_start"?"selected":""}>Inicio del combate</option><option value="hp_threshold" ${S(h.shieldStartMode)==="hp_threshold"?"selected":""}>Umbral de HP</option></select>`)}</div>${this.field("Orden de presentación al inicio",`<select class="bss-select" data-bind="boss.introOrder"><option value="shield_first" ${S(boss.introOrder||"shield_first")==="shield_first"?"selected":""}>Escudo → Aura</option><option value="aura_first" ${S(boss.introOrder)==="aura_first"?"selected":""}>Aura → Escudo</option></select><span class="bss-note">Sólo cambia el orden cuando el escudo está configurado para aparecer al inicio y el Aura también tiene presentación inicial.</span>`) }<div class="bss-boss-three">${this.field("Umbral HP (%)",`<input class="bss-input" type="number" min="1" max="100" data-bind="boss.hud.shieldTriggerPercent" value="${N(h.shieldTriggerPercent,50)}">`)}${this.field("Daño atraviesa (%)",`<input class="bss-input" type="number" min="1" max="100" data-bind="boss.hud.shieldDamagePercent" value="${N(h.shieldDamagePercent,5)}">`)}${this.field("Daño al romper (%)",`<input class="bss-input" type="number" min="0" max="100" step="0.5" data-bind="boss.hud.shieldBreakDamagePercent" value="${N(h.shieldBreakDamagePercent,12.5)}">`)}</div>${this.field("Mensaje al aparecer",`<input class="bss-input" data-bind="boss.hud.shieldMessage" value="${E(h.shieldMessage||"¡Una barrera misteriosa protege a {1}!")}">`)}${this.field("Mensaje al romper",`<input class="bss-input" data-bind="boss.hud.shieldBreakMessage" value="${E(h.shieldBreakMessage||"¡La barrera de {1} se ha roto!")}">`)}${this.field("SE al romper el último escudo",`<div class="bss-asset-field"><input class="bss-input" value="${E(h.shieldBreakSE||"")}" readonly placeholder="Vacío = sin sonido"><button class="bss-btn small" type="button" data-asset-browse="boss.hud.shieldBreakSE" data-asset-kind="se">Buscar…</button>${h.shieldBreakSE?`<button class="bss-btn small" type="button" data-asset-clear="boss.hud.shieldBreakSE">Quitar</button>`:""}</div><span class="bss-note">Usa el mismo navegador que los BGM: busca en Audio/SE, permite escuchar el sonido y elegirlo sin escribir el nombre a mano. Vacío = sin sonido.</span>`)}<div class="bss-boss-immunity-help"><b>Stats al romper el último escudo</b> · Puedes bajar o subir todas las estadísticas del Boss por el mismo número de etapas, o definir cada estadística de forma independiente.</div><label class="bss-check bss-boss-switch"><input type="checkbox" data-bind="boss.hud.shieldBreakStats.enabled" ${breakStats.enabled?"checked":""}><span><b>Cambiar stats al romper el escudo</b><small>Se aplica una sola vez al destruir el último segmento.</small></span></label><div class="bss-boss-two">${this.field("Bajar stats",`<select class="bss-select" data-bind="boss.hud.shieldBreakStats.dropMode"><option value="none" ${S(breakStats.dropMode||"none")==="none"?"selected":""}>No bajar</option><option value="all" ${S(breakStats.dropMode)==="all"?"selected":""}>Bajar todas</option><option value="specific" ${S(breakStats.dropMode)==="specific"?"selected":""}>Elegir por stat</option></select>${S(breakStats.dropMode)==="all"?`<input class="bss-input" type="number" min="1" max="6" data-bind="boss.hud.shieldBreakStats.dropAll" value="${N(breakStats.dropAll,1)}"><span class="bss-note">Etapas que baja cada stat.</span>`:""}`)}${this.field("Subir stats",`<select class="bss-select" data-bind="boss.hud.shieldBreakStats.raiseMode"><option value="none" ${S(breakStats.raiseMode||"none")==="none"?"selected":""}>No subir</option><option value="all" ${S(breakStats.raiseMode)==="all"?"selected":""}>Subir todas</option><option value="specific" ${S(breakStats.raiseMode)==="specific"?"selected":""}>Elegir por stat</option></select>${S(breakStats.raiseMode)==="all"?`<input class="bss-input" type="number" min="1" max="6" data-bind="boss.hud.shieldBreakStats.raiseAll" value="${N(breakStats.raiseAll,1)}"><span class="bss-note">Etapas que sube cada stat.</span>`:""}`)}</div>${S(breakStats.dropMode)==="specific"?`<div class="bss-boss-stats bss-boss-stats-clean">${statRows.map(([id,label])=>`<label class="bss-boss-stat"><span>↓ ${E(label)}</span><input class="bss-input" type="number" min="0" max="6" data-bind="boss.hud.shieldBreakStats.drop.${id}" value="${N(breakDrop[id],0)}"></label>`).join("")}</div>`:""}${S(breakStats.raiseMode)==="specific"?`<div class="bss-boss-stats bss-boss-stats-clean">${statRows.map(([id,label])=>`<label class="bss-boss-stat"><span>↑ ${E(label)}</span><input class="bss-input" type="number" min="0" max="6" data-bind="boss.hud.shieldBreakStats.raise.${id}" value="${N(breakRaise[id],0)}"></label>`).join("")}</div>`:""}</div></details>

  <details class="bss-optiongroup bss-boss-card"><summary><span>06</span> Captura al derrotar</summary><div class="bss-boss-cardbody"><div class="bss-boss-capture-note ${wild?"":"disabled"}"><b>Escena de captura estilo Raid</b><span>${wild?"Al llevar al Boss a 0 HP, el destino de los SOS vivos depende de «Al derrotar al Boss». La captura sólo empieza cuando el campo enemigo queda en el estado elegido.":"La captura estilo Raid sólo aplica a Boss salvajes. En combates Trainer esta opción se ignora."}</span></div><label class="bss-check bss-boss-switch"><input type="checkbox" data-bind="boss.capture.enabled" ${capture.enabled?"checked":""} ${wild?"":"disabled"}><span><b>Boss capturable al derrotarlo</b><small>Bloquea Poké Balls normales durante el combate y ofrece la captura al llegar a 0 HP.</small></span></label><div class="bss-boss-two">${this.field("Probabilidad de captura (%)",`<input class="bss-input" type="number" min="0" max="100" data-bind="boss.capture.chance" value="${N(capture.chance,100)}" ${wild?"":"disabled"}>`)}${this.field("BGM DURANTE la captura (opcional)",`<div class="bss-asset-field"><input class="bss-input" value="${E(capture.bgm||"")}" readonly placeholder="Vacío = BGM actual / predeterminado"><button class="bss-btn small" type="button" data-asset-browse="boss.capture.bgm" data-asset-kind="audio" ${wild?"":"disabled"}>Buscar…</button>${capture.bgm?`<button class="bss-btn small" type="button" data-asset-clear="boss.capture.bgm" ${wild?"":"disabled"}>Quitar</button>`:""}</div><span class="bss-note">Empieza al entrar en la fase «¡está débil!» y se mantiene mientras eliges y lanzas la Ball. No es la música/fanfarria posterior a capturarlo.</span>`)}</div>${this.field("Al derrotar al Boss con SOS vivos",`<select class="bss-select" data-bind="boss.sosOnBossDefeat"><option value="faint" ${S(boss.sosOnBossDefeat||"faint")==="faint"?"selected":""}>Los SOS se debilitan automáticamente</option><option value="flee" ${S(boss.sosOnBossDefeat)==="flee"?"selected":""}>Los SOS escapan</option><option value="continue" ${S(boss.sosOnBossDefeat)==="continue"?"selected":""}>El combate continúa contra los SOS</option></select><span class="bss-note">Continuar: el Boss cae primero y la captura, si está activa, se pospone hasta que ya no queden SOS. Debilitar/Escapar resuelven a los aliados antes de la captura.</span>`)}${this.field("Si eliges «No capturar»",`<select class="bss-select" data-bind="boss.capture.declineMode" ${wild?"":"disabled"}><option value="flee" ${S(capture.declineMode||"flee")==="flee"?"selected":""}>El Boss escapa</option><option value="faint" ${S(capture.declineMode)==="faint"?"selected":""}>El Boss se debilita</option></select><span class="bss-note">Escapar termina como huida. Debilitar continúa con el faint normal y el resultado normal del combate.</span>`)}${this.field("Mensaje de escape",`<input class="bss-input" data-bind="boss.capture.fleeMessage" value="${E(capture.fleeMessage||"¡{1} escapó!")}" ${wild?"":"disabled"}><span class="bss-note">Se usa si «No capturar» está en modo Escapa y también cuando falla la captura. {1} = nombre del Boss.</span>`)}${this.field("Mensaje al entregar Ball de emergencia",`<input class="bss-input" data-bind="boss.capture.emergencyBallMessage" value="${E(capture.emergencyBallMessage||"No te quedaban Poké Balls. ¡Has recibido una {1} para intentar la captura!")}" ${wild?"":"disabled"}><span class="bss-note">Aparece sólo si eliges Capturar sin ninguna Ball disponible. {1} = nombre de la Ball entregada.</span>`)}</div></details>
  </div></div>`;
};

// Rebuild the editor shell when entering/leaving Boss focus. Otherwise a Boss
// opened with its preview suppressed would leave the collapsed preview DOM
// behind after switching back to another Blueprint section.
const _bss652SwitchSection=App.prototype.switchSection;
App.prototype.switchSection=function(section){
  const next=S(section||"setup"),crossing=(this.section==="boss")!==(next==="boss");
  if(crossing&&this.screen==="editor"&&this.body&&this.body.querySelector(".bss-editor")){
    const scroller=this.body.querySelector(".bss-inspector");if(scroller)this.sectionScroll[this.section]=scroller.scrollTop;
    this.section=next;this.renderEditor();
    const target=this.body.querySelector(".bss-inspector"),saved=N(this.sectionScroll[next],0);if(target)requestAnimationFrame(()=>{if(target.isConnected)target.scrollTop=saved;});
    return;
  }
  return _bss652SwitchSection.call(this,next);
};


//=============================================================================
// v0.6.53 · Blueprint workspace revamp for ALL sections.
// Blueprint editing is configuration-first: no permanent game preview column,
// one navigation rail, a contextual header and a wide clean work surface.
//=============================================================================
App.prototype.bss653BlueprintSections=function(){return [
  ["setup","General","Identidad, formato y final del combate"],
  ["foes","Rivales","Equipo enemigo y configuración individual"],
  ["test","Equipo de prueba","Pokémon usados al ejecutar Test game"],
  ["scene","Escena y audio","Battleback, bases y música"],
  ["boss","Boss / Totem","Jefe, resistencia, HUD, escudos y captura"],
  ["aura","Aura","Presentación y perfil de aura del Boss"],
  ["sos","SOS","Invocaciones, pool y reglas del combate"]
];};
App.prototype.bss653BlueprintMeta=function(section){return this.bss653BlueprintSections().find(x=>x[0]===S(section))||this.bss653BlueprintSections()[0];};
App.prototype.renderEditor=function(){
  const b=this.battle();if(!b){this.screen="library";return this.renderLibrary();}
  this.disposePreview();
  const sections=this.bss653BlueprintSections(),meta=this.bss653BlueprintMeta(this.section);
  const nav=sections.map(([k,n,d],i)=>`<button class="bss-blueprint-nav ${this.section===k?"active":""}" data-section="${E(k)}"><span>${String(i+1).padStart(2,"0")}</span><b>${E(n)}</b><small>${E(d)}</small></button>`).join("");
  this.body.innerHTML=`<section class="bss-editor bss-blueprint-focus">
    <aside class="bss-blueprint-rail">
      <div class="bss-blueprint-railhead"><button class="bss-btn small" data-act="back">← Librería</button><div><b>${E(b.name)}</b><small>${E(this.battleTypeLabel(b))} · ${E(b.setup&&b.setup.formation||"1v1")}</small></div></div>
      <nav class="bss-blueprint-navlist">${nav}</nav>
    </aside>
    <main class="bss-inspector bss-blueprint-main">
      <header class="bss-blueprint-head"><div><span>BLUEPRINT</span><h2>${E(meta[1])}</h2><p>${E(meta[2])}</p></div><div class="bss-blueprint-head-actions"><span class="bss-note" data-battle-summary>${E(this.battleTypeLabel(b))} · ${E(b.setup&&b.setup.formation||"1v1")} · ${b.sos&&b.sos.enabled?"SOS activo":"sin SOS"}</span><button class="bss-btn primary" data-test="${E(b.id)}">▶ Test game</button></div></header>
      <div class="bss-inspector-subnav bss-blueprint-subnav" data-inspector-subnav></div>
      <div class="bss-inspector-inner bss-blueprint-content">${this.inspectorHTML(b)}</div>
    </main>
  </section>`;
  this.bss650HydrateInspectorSubnav();
  this.hydrateInspectorIcons();
  if(["boss","aura"].includes(this.section)){this.hydrateAuraTestBattler();this.hydrateAuraRuntimePreview();this.startAuraPreviewLoop();}
  if(this.pokemonEditor)this.renderPokemonEditor();
};
App.prototype.switchSection=function(section){
  const next=S(section||"setup"),scroller=this.body&&this.body.querySelector(".bss-inspector");
  if(scroller)this.sectionScroll[this.section]=scroller.scrollTop;
  this.section=next;
  if(this.screen==="editor"){
    this.renderEditor();
    const target=this.body&&this.body.querySelector(".bss-inspector"),saved=N(this.sectionScroll[next],0);
    if(target)requestAnimationFrame(()=>{if(target.isConnected)target.scrollTop=saved;});
    return;
  }
  this.render();
};

// Capture BGM uses the same project Audio/BGM browser and preview as every
// other BGM field instead of a raw string input.
const _bss653CurrentAssetTargetValue=App.prototype.currentAssetTargetValue;
App.prototype.currentAssetTargetValue=function(target){
  target=S(target);const b=this.battle();
  if(target==="boss.capture.bgm"&&b){b.boss=b.boss||{};b.boss.capture=b.boss.capture||{};return S(b.boss.capture.bgm||"");}
  return _bss653CurrentAssetTargetValue.call(this,target);
};
const _bss653SetAssetTarget=App.prototype.setAssetTarget;
App.prototype.setAssetTarget=function(target,value){
  target=S(target);value=S(value);const b=this.battle();
  if(target==="boss.capture.bgm"&&b){b.boss=b.boss||{};b.boss.capture=b.boss.capture||{};b.boss.capture.bgm=value;this.touch();return this.refreshInspector();}
  return _bss653SetAssetTarget.call(this,target,value);
};


//=============================================================================
// v0.6.56 · native databox reflow + Boss/SOS finish policy.
// Rebuilding an inspector must not throw the creator back to the top or close
// every <details>. State is stored per battle + section and restored after any
// input-driven refresh or section round trip.
//=============================================================================
App.prototype.bss654InspectorStateKey=function(section=this.section){return `${S(this.activeId||"")}::${S(section||"setup")}`;};
App.prototype.bss654DetailIdentity=function(node,index){
  const summary=node&&node.querySelector&&node.querySelector(":scope > summary"),label=S(summary&&summary.textContent).trim().replace(/\s+/g," ");
  return label||`details:${index}`;
};
App.prototype.bss654CaptureInspectorState=function(section=this.section){
  const scroller=this.body&&this.body.querySelector(".bss-inspector"),inner=this.body&&this.body.querySelector(".bss-inspector-inner");
  if(!scroller||!inner)return null;
  const open={};[...inner.querySelectorAll("details")].forEach((node,i)=>{open[this.bss654DetailIdentity(node,i)]=!!node.open;});
  let focus=null;const active=document.activeElement;
  if(active&&inner.contains(active)){
    const ds=active.dataset||{};let selector="";
    if(ds.bind!=null)selector=`[data-bind="${CSS.escape(S(ds.bind))}"]`;
    else if(ds.bossNativeImmunity!=null)selector=`[data-boss-native-immunity="${CSS.escape(S(ds.bossNativeImmunity))}"]`;
    if(selector)focus={selector,start:Number.isFinite(active.selectionStart)?active.selectionStart:null,end:Number.isFinite(active.selectionEnd)?active.selectionEnd:null};
  }
  return {scrollTop:scroller.scrollTop,open,focus};
};
App.prototype.bss654RememberInspectorState=function(section=this.section){const state=this.bss654CaptureInspectorState(section);if(state)this.inspectorPanelState[this.bss654InspectorStateKey(section)]=state;return state;};
App.prototype.bss654RestoreInspectorState=function(section=this.section,state=null){
  state=state||this.inspectorPanelState[this.bss654InspectorStateKey(section)];if(!state)return;
  const scroller=this.body&&this.body.querySelector(".bss-inspector"),inner=this.body&&this.body.querySelector(".bss-inspector-inner");if(!inner)return;
  [...inner.querySelectorAll("details")].forEach((node,i)=>{const key=this.bss654DetailIdentity(node,i);if(Object.prototype.hasOwnProperty.call(state.open||{},key))node.open=!!state.open[key];});
  requestAnimationFrame(()=>{if(scroller&&scroller.isConnected)scroller.scrollTop=Math.max(0,N(state.scrollTop,0));if(state.focus&&state.focus.selector){const el=inner.querySelector(state.focus.selector);if(el&&el.isConnected){try{el.focus({preventScroll:true});}catch(_){try{el.focus();}catch(__){}}if(state.focus.start!=null&&typeof el.setSelectionRange==="function"){try{el.setSelectionRange(state.focus.start,state.focus.end==null?state.focus.start:state.focus.end);}catch(_){}}}}});
};
const _bss654RefreshInspector=App.prototype.refreshInspector;
App.prototype.refreshInspector=function(preserveScroll=true){
  const section=this.section,state=preserveScroll?this.bss654RememberInspectorState(section):null,ret=_bss654RefreshInspector.call(this,preserveScroll);
  // The v0.6.52 input guard may defer the actual rebuild. The saved state is
  // still retained and the deferred call will restore it on its own pass.
  if(!this._bss650InputDispatch&&state)this.bss654RestoreInspectorState(section,state);
  return ret;
};
const _bss654RenderEditor=App.prototype.renderEditor;
App.prototype.renderEditor=function(){
  if(!this._bss654SwitchingSection)this.bss654RememberInspectorState(this.section);
  const ret=_bss654RenderEditor.call(this);this.bss654RestoreInspectorState(this.section);return ret;
};
const _bss654SwitchSection=App.prototype.switchSection;
App.prototype.switchSection=function(section){
  const old=this.section;this.bss654RememberInspectorState(old);this._bss654SwitchingSection=true;
  try{return _bss654SwitchSection.call(this,section);}finally{this._bss654SwitchingSection=false;this.bss654RestoreInspectorState(this.section);}
};


//=============================================================================
// v0.6.60 · BAS-style Move picker isolation + Audio/SE browser.
//
// The Pokémon Move editor now follows BAS New Move's contract end-to-end:
// every catalog value is normalized before matching and every modal event is
// contained inside BSS so Maker Studio's outer delegated handlers never receive
// partial/foreign targets. The shield-break SE uses the same searchable browser
// and preview flow as BGM instead of a datalist/raw text field.
//=============================================================================
App.prototype.bss660NormalizeMoveRows=function(){
  return A(this.source&&this.source.moves).map((m,order)=>({
    id:S(m&&m.id).trim().toUpperCase(),
    name:S((m&&m.name)||(m&&m.id)).trim(),
    order:Number((m&&m.order)!=null?m.order:order)
  })).filter(m=>!!m.id).sort((a,b)=>a.order-b.order||a.name.localeCompare(b.name,undefined,{numeric:true,sensitivity:"base"})||a.id.localeCompare(b.id));
};
App.prototype.moveCatalogRows=function(){return this.bss660NormalizeMoveRows();};
App.prototype.findTypedMove=function(value,rows=this.moveCatalogRows()){
  const q=S(value).trim().toLowerCase();if(!q)return null;
  const safe=A(rows);
  let match=safe.find(m=>S(m&&m.id).toLowerCase()===q||S(m&&m.name).toLowerCase()===q);
  if(match)return match;
  match=safe.find(m=>S(m&&m.name).toLowerCase().startsWith(q)||S(m&&m.id).toLowerCase().startsWith(q));
  if(match)return match;
  return safe.find(m=>S(m&&m.name).toLowerCase().includes(q)||S(m&&m.id).toLowerCase().includes(q))||null;
};
App.prototype.bss660ContainPokemonEditorEvents=function(modal){
  if(!modal||modal._bss660Contained)return;modal._bss660Contained=true;
  const stop=e=>{try{e.stopPropagation();}catch(_){}};
  ["click","dblclick","pointerdown","pointerup","mousedown","mouseup","input","change","keydown","keyup","contextmenu"].forEach(type=>modal.addEventListener(type,stop,false));
};
const _bss660RenderPokemonEditor=App.prototype.renderPokemonEditor;
App.prototype.renderPokemonEditor=function(){
  const ret=_bss660RenderPokemonEditor.call(this),modal=this.root&&this.root.querySelector('[data-pokemon-editor]');
  this.bss660ContainPokemonEditorEvents(modal);return ret;
};

const _bss660AssetPickerRows=App.prototype.assetPickerRows;
App.prototype.assetPickerRows=function(kind){return S(kind)==="se"?A(this.source&&this.source.seFiles):_bss660AssetPickerRows.call(this,kind);};
const _bss660AssetPickerFolder=App.prototype.assetPickerFolder;
App.prototype.assetPickerFolder=function(row,kind){
  if(S(kind)!=="se")return _bss660AssetPickerFolder.call(this,row,kind);
  let path=S(row&&row.projectPath||row&&row.relativePath||row&&row.value||row&&row.name).replace(/\\/g,"/").replace(/^Audio\/SE\//i,"");
  const parts=path.split("/").filter(Boolean);return parts.length>1?parts.slice(0,-1).join("/"):"Raíz";
};
const _bss660CurrentAssetTargetValue=App.prototype.currentAssetTargetValue;
App.prototype.currentAssetTargetValue=function(target){
  target=S(target);const b=this.battle();
  if(target==="boss.hud.shieldBreakSE"&&b){b.boss=b.boss||{};b.boss.hud=b.boss.hud||{};return S(b.boss.hud.shieldBreakSE||"");}
  return _bss660CurrentAssetTargetValue.call(this,target);
};
const _bss660SetAssetTarget=App.prototype.setAssetTarget;
App.prototype.setAssetTarget=function(target,value){
  target=S(target);value=S(value);const b=this.battle();
  if(target==="boss.hud.shieldBreakSE"&&b){b.boss=b.boss||{};b.boss.hud=b.boss.hud||{};b.boss.hud.shieldBreakSE=value;this.touch();return this.refreshInspector();}
  return _bss660SetAssetTarget.call(this,target,value);
};
App.prototype.openAssetPicker=function(target,kind="graphic"){
  kind=S(kind);kind=kind==="audio"?"audio":kind==="se"?"se":"graphic";
  const current=this.currentAssetTargetValue(target);let selectedKey="";
  if((kind==="audio"||kind==="se")&&current){const row=this.assetPickerRows(kind).find(x=>this.assetTargetValue(x,kind)===current);selectedKey=row?this.assetRowKey(row):"";}
  this.stopAssetAudioPreview(true);this.assetPicker={target:S(target),kind,search:"",folder:"all",selectedKey};this.renderAssetPicker();
};
App.prototype.assetPickerSelectedAudioRow=function(){
  if(!this.assetPicker||!["audio","se"].includes(S(this.assetPicker.kind))||!this.assetPicker.selectedKey)return null;
  const key=S(this.assetPicker.selectedKey);return this.assetPickerRows(this.assetPicker.kind).find(x=>this.assetRowKey(x)===key)||null;
};
App.prototype.assetPickerGridHTML=function(){
  const rows=this.assetPickerResults(),kind=S(this.assetPicker&&this.assetPicker.kind),sound=kind==="audio"||kind==="se";
  if(sound){const selected=S(this.assetPicker.selectedKey),prefix=kind==="se"?/^Audio\/SE\//i:/^Audio\/BGM\//i,fallback=kind==="se"?"SE":"BGM";
    return `<div class="bss-audio-list">${rows.map((row,i)=>{const key=this.assetRowKey(row),path=S(row.projectPath||row.relativePath||row.value||row.name),name=S(row.name||path.split("/").pop()||row.value||fallback);return `<button class="bss-audio-row ${selected===key?"active":""}" type="button" data-asset-audio-select="${i}"><span class="bss-audio-note">♪</span><span class="bss-audio-copy"><b>${E(name)}</b><small>${E(path.replace(prefix,""))}</small></span></button>`;}).join("")||`<div class="bss-empty">No hay ${kind==="se"?"SE":"BGM"} que coincidan con la búsqueda.</div>`}</div>`;
  }
  return rows.map((row,i)=>`<button class="bss-asset-tile" type="button" data-asset-pick="${i}"><span class="bss-asset-thumb"><img data-asset-thumb="${i}" alt=""></span><b>${E(row.name||row.value||row.projectPath||"Asset")}</b><small>${E(row.relativePath||row.projectPath||row.value||"")}</small></button>`).join("")||`<div class="bss-empty">No hay resultados en esta carpeta.</div>`;
};
App.prototype.renderAssetPicker=function(){
  const old=this.root.querySelector("[data-asset-picker-modal]");if(old)this.safeRemove(old);if(!this.assetPicker)return;
  const kind=S(this.assetPicker.kind),sound=kind==="audio"||kind==="se",isSE=kind==="se",folders=this.assetPickerFolders(),modal=document.createElement("div");
  modal.className="bss-modal bss-asset-picker-modal";modal.dataset.assetPickerModal="1";
  const footer=sound?`<div class="bss-audio-preview-bar"><div class="bss-audio-selected"><b data-asset-audio-selected>Ningún ${isSE?"sonido":"tema"} seleccionado</b><small data-asset-audio-status>Selecciona ${isSE?"un SE":"una pista"} para escucharlo antes de usarlo.</small></div><button class="bss-btn" type="button" data-act="asset-audio-play" disabled>▶ Play</button><button class="bss-btn" type="button" data-act="asset-audio-pause" disabled>⏸ Pause</button><button class="bss-btn" type="button" data-act="asset-audio-stop" disabled>■ Stop</button><button class="bss-btn primary" type="button" data-act="asset-audio-use" disabled>Usar ${isSE?"SE":"canción"}</button></div>`:"";
  modal.innerHTML=`<div class="bss-modal-card bss-asset-picker-card"><div class="bss-modal-head"><div><b>${sound?(isSE?"Seleccionar SE":"Seleccionar BGM"):"Gráficos del proyecto"}</b><small>${sound?(isSE?"Audio/SE · selección + preview":"Audio/BGM · selección + preview"):"Graphics"} · <span data-asset-result-count>${this.assetPickerResults().length} resultados</span></small></div><button class="bss-btn" data-act="close-asset-picker">Cerrar</button></div><div class="bss-asset-picker-toolbar"><input class="bss-input" autofocus data-asset-search placeholder="${sound?(isSE?"Buscar SE por nombre o carpeta…":"Buscar canción por nombre o carpeta…"):"Buscar archivo…"}" value="${E(this.assetPicker.search)}"><select class="bss-select" data-asset-folder><option value="all">Todas las carpetas</option>${folders.map(f=>`<option value="${E(f)}" ${S(this.assetPicker.folder)===f?"selected":""}>${E(f)}</option>`).join("")}</select></div><div class="bss-asset-picker-layout"><aside class="bss-asset-folder-list"><button class="bss-asset-folder ${S(this.assetPicker.folder)==="all"?"active":""}" data-asset-folder-button="all">Todo</button>${folders.map(f=>`<button class="bss-asset-folder ${S(this.assetPicker.folder)===f?"active":""}" data-asset-folder-button="${E(f)}">${E(f)}</button>`).join("")}</aside><div class="bss-asset-picker-grid ${sound?"audio-mode":""}" data-asset-results>${this.assetPickerGridHTML()}</div></div>${footer}</div>`;
  this.root.appendChild(modal);if(sound)this.updateAssetAudioControls();else this.hydrateAssetPickerImages();
};
const _bss660AssetTargetValue=App.prototype.assetTargetValue;
App.prototype.assetTargetValue=function(row,kind){
  if(S(kind)==="se")return S(row&&row.value||row&&row.relativePath||row&&row.name).replace(/\\/g,"/").replace(/^Audio\/SE\//i,"").replace(/\.(?:ogg|mp3|wav|mid|midi|flac|opus|m4a)$/i,"");
  return _bss660AssetTargetValue.call(this,row,kind);
};
App.prototype.selectAssetAudio=function(index){
  if(!this.assetPicker||!["audio","se"].includes(S(this.assetPicker.kind)))return;const row=this.assetPickerResults()[N(index,-1)];if(!row)return;
  const key=this.assetRowKey(row);if(this.assetAudioKey&&this.assetAudioKey!==key)this.stopAssetAudioPreview(true);this.assetPicker.selectedKey=key;this.refreshAssetPickerList();
};
App.prototype.assetAudioProjectPath=function(row){
  const kind=S(this.assetPicker&&this.assetPicker.kind),isSE=kind==="se";let path=S(row&&row.projectPath||row&&row.relativePath||row&&row.filename||row&&row.name).replace(/\\/g,"/");
  const prefix=isSE?"Audio/SE/":"Audio/BGM/",re=isSE?/^Audio\/SE\//i:/^Audio\/BGM\//i;if(!re.test(path))path=prefix+path;if(!/\.[A-Za-z0-9]+$/.test(path)&&row&&row.extension)path+="."+S(row.extension).replace(/^\./,"");return path;
};
App.prototype.updateAssetAudioControls=function(){
  const modal=this.root&&this.root.querySelector("[data-asset-picker-modal]"),kind=S(this.assetPicker&&this.assetPicker.kind);if(!modal||!this.assetPicker||!["audio","se"].includes(kind))return;
  const isSE=kind==="se",row=this.assetPickerSelectedAudioRow(),key=row?this.assetRowKey(row):"",same=!!(this.assetAudio&&key&&this.assetAudioKey===key),playing=!!(same&&!this.assetAudio.paused),name=modal.querySelector("[data-asset-audio-selected]"),status=modal.querySelector("[data-asset-audio-status]"),play=modal.querySelector('[data-act="asset-audio-play"]'),pause=modal.querySelector('[data-act="asset-audio-pause"]'),stop=modal.querySelector('[data-act="asset-audio-stop"]'),use=modal.querySelector('[data-act="asset-audio-use"]');
  if(name)name.textContent=row?S(row.name||this.assetTargetValue(row,kind)):`Ningún ${isSE?"sonido":"tema"} seleccionado`;if(status)status.textContent=!row?`Selecciona ${isSE?"un SE":"una pista"} para escucharlo antes de usarlo.`:playing?"Reproduciendo preview…":same?"Preview pausada.":"Listo para reproducir.";if(play)play.disabled=!row||playing;if(pause)pause.disabled=!playing;if(stop)stop.disabled=!same;if(use)use.disabled=!row;
};
App.prototype.useSelectedAssetAudio=function(){
  if(!this.assetPicker||!["audio","se"].includes(S(this.assetPicker.kind)))return;const row=this.assetPickerSelectedAudioRow();if(!row)return;
  const target=this.assetPicker.target,value=this.assetTargetValue(row,this.assetPicker.kind);this.stopAssetAudioPreview(true);this.assetPicker=null;this.setAssetTarget(target,value);
};
const _bss660AssetScopeLabel=App.prototype.assetScopeLabel;
App.prototype.assetScopeLabel=function(target,kind){return S(kind)==="se"?"Audio/SE":_bss660AssetScopeLabel.call(this,target,kind);};

// ============================================================================
// BSS v0.6.86 - EBDX Studio
// Built-in preset data mirrors the EBDX Environments.rb supplied by the user.
// ============================================================================
const BSS079_EBDX_BUILTINS={"Field":{"backdrop":"Field","sky":true,"trees":{"elements":9,"x":[150,271,78,288,176,42,118,348,321],"y":[108,117,118,126,126,128,136,136,145],"zoom":[0.44,0.44,0.59,0.59,0.59,0.64,0.85,0.7,1],"mirror":[false,false,true,true,true,false,false,true,false]}},"Forest":{"backdrop":"Forest","lightsC":true,"img001":{"bitmap":"forestShade","z":1,"flat":true,"oy":0,"y":94,"sheet":true,"frames":2,"speed":16},"trees":{"bitmap":"treePine","colorize":false,"elements":8,"x":[92,248,300,40,138,216,274,318],"y":[132,132,144,118,112,118,110,110],"zoom":[1,1,1.1,0.9,0.8,0.85,0.75,0.75],"z":[2,2,2,1,1,1,1,1]},"outdoor":false},"Cave":{"backdrop":"Cave","img001":{"scrolling":true,"speed":2,"direction":-1,"bitmap":"decor006","oy":0,"z":3,"flat":true,"opacity":155},"img002":{"scrolling":true,"speed":1,"direction":1,"bitmap":"decor009","oy":0,"z":3,"flat":true,"opacity":96},"img003":{"scrolling":true,"speed":0.5,"direction":1,"bitmap":"fog","oy":0,"z":4,"flat":true}},"CaveDark":{"backdrop":"CaveDark","img003":{"scrolling":true,"speed":0.5,"direction":1,"bitmap":"fog","oy":0,"z":4,"flat":true},"bubbles":"bubbleDark"},"Water":{"backdrop":"Water","sky":true,"water":true},"Underwater":{"backdrop":"Underwater","lightsC":true,"img001":{"bitmap":"forestShade","z":1,"flat":true,"oy":0,"y":94,"sheet":true,"frames":2,"speed":16},"tallGrass":{"elements":5,"bitmap":"seaWeed","x":[124,274,62,248,275],"y":[160,140,185,246,174],"z":[2,1,17,27,17],"zoom":[0.5,0.15,0.6,1,0.5],"mirror":[false,true,true,false,true]},"bubbles":true,"outdoor":false,"underwater":true},"IndoorA":{"backdrop":"IndoorA","img001":{"bitmap":"decor007","oy":0,"z":1,"flat":true,"scrolling":true,"speed":0.5},"img002":{"bitmap":"decor008","oy":0,"z":1,"flat":true,"scrolling":true,"direction":-1},"lightsA":true,"outdoor":false},"DanceFloor":{"backdrop":"DanceFloor","img001":{"bitmap":"discoBg","ox":0,"flat":true,"rainbow":true,"speed":8},"lightsB":true,"img002":{"bitmap":"crowd","oy":32,"y":102,"z":2,"flat":false,"sheet":true,"vertical":true,"speed":8,"frames":2}},"Net":{"backdrop":"Net","img001":{"scrolling":true,"vertical":true,"speed":1,"bitmap":"decor003d","oy":180,"y":90,"flat":true},"img002":{"bitmap":"crowd_d","oy":32,"y":112,"z":2,"flat":false,"sheet":true,"vertical":true,"speed":8,"frames":2}},"Mountain":{"backdrop":"Mountain","sky":true,"trees":{"elements":8,"bitmap":"treeC","colorize":"slight","x":[271,78,288,176,42,118,348,321],"y":[117,118,122,122,127,127,128,132],"zoom":[0.44,0.59,0.59,0.59,0.64,0.85,0.7,1],"mirror":[false,true,true,true,false,false,true,false]},"img001":{"bitmap":"mountainC","x":192,"y":107}},"MountainLake":{"backdrop":"Field","sky":true,"trees":{"elements":9,"x":[150,271,78,288,176,42,118,348,321],"y":[108,117,118,122,122,127,127,128,132],"zoom":[0.44,0.44,0.59,0.59,0.59,0.64,0.85,0.7,1],"mirror":[false,false,true,true,true,false,false,true,false]},"img001":{"bitmap":"mountain","x":192,"y":107},"base":"Water","water":true},"Dimension":{"backdrop":"Sapphire","vacuum":"dark006","img001":{"scrolling":true,"vertical":true,"speed":1,"bitmap":"decor003a","oy":180,"y":90,"flat":true},"img002":{"bitmap":"shade","oy":100,"y":98,"flat":false},"img003":{"scrolling":true,"speed":16,"bitmap":"decor005","oy":0,"y":4,"z":4,"flat":true},"img004":{"scrolling":true,"speed":16,"direction":-1,"bitmap":"decor006","oy":0,"z":4,"flat":true},"img005":{"scrolling":true,"speed":0.5,"bitmap":"base001a","oy":0,"y":122,"z":1,"flat":true}},"Champion":{"backdrop":"Champion","lightsA":true,"img001":{"scrolling":true,"vertical":true,"speed":1,"bitmap":"decor003","oy":180,"y":90,"z":1,"flat":true},"img002":{"bitmap":"decor004","oy":100,"y":98,"z":2,"flat":false},"img003":{"scrolling":true,"speed":16,"bitmap":"decor005","oy":0,"y":4,"z":4,"flat":true},"img004":{"scrolling":true,"speed":16,"direction":-1,"bitmap":"decor006","oy":0,"z":4,"flat":true},"img005":{"scrolling":true,"speed":0.5,"bitmap":"base001","oy":0,"y":122,"z":1,"flat":true},"img006":{"bitmap":"pillars001","y":128,"x":144,"z":3},"img007":{"bitmap":"pillars002","y":192,"x":144,"z":18}},"Stage":{"backdrop":"IndoorB","spinLights":true,"lightsA":true,"img001":{"scrolling":true,"speed":1,"bitmap":"decor001","oy":0,"z":1,"flat":true},"img002":{"scrolling":true,"speed":1,"direction":-1,"bitmap":"decor002","oy":0,"z":1,"flat":true}},"Darkness":{"backdrop":"Darkness","img001":{"bitmap":"dark001","oy":70,"ox":70,"y":128,"x":248,"z":2,"effect":"rotate","zoom":0.75},"img002":{"bitmap":"dark002","oy":120,"ox":120,"y":128,"x":242,"z":3,"direction":-1,"effect":"rotate","zoom":0.75},"img003":{"bitmap":"dark003","oy":110,"ox":110,"y":128,"x":234,"z":4,"effect":"rotate"},"img004":{"scrolling":true,"speed":0.5,"bitmap":"darkFog","oy":0,"y":0,"z":5,"flat":true},"vacuum":true},"Magma":{"backdrop":"Cave","img001":{"scrolling":true,"speed":2,"direction":-1,"bitmap":"decor006","oy":0,"z":3,"flat":true,"opacity":155},"img002":{"scrolling":true,"speed":1,"direction":1,"bitmap":"decor009","oy":0,"z":3,"flat":true,"opacity":96},"img003":{"scrolling":true,"speed":0.5,"direction":1,"bitmap":"fog","oy":0,"z":4,"flat":true},"bubbles":"bubbleRed","img005":{"scrolling":true,"speed":0.5,"direction":-1,"bitmap":"base001","oy":0,"y":122,"z":1,"flat":true}},"Sky":{"backdrop":"sky","trees":{"bitmap":"cluster","colorize":false,"elements":12,"x":[26,6,44,4,136,104,372,342,236,180,214,282],"y":[184,210,216,258,188,278,212,284,234,238,258,170],"mirror":[false,false,true,true,false,false,true,false,false,false,false,false],"zoom":[1,1,1,1,1,1,1,1,1,1,1,0.7],"z":[2,2,2,2,2,2,2,2,2,2,2,2]},"sky":true,"noshadow":true,"img001":{"scrolling":true,"speed":0.5,"bitmap":"base001c","oy":0,"y":122,"z":3,"flat":true}},"Snow":{"backdrop":"Snow","sky":true,"trees":{"elements":9,"x":[150,271,78,288,176,42,118,348,321],"y":[108,117,118,126,126,128,136,136,145],"zoom":[0.44,0.44,0.59,0.59,0.59,0.64,0.85,0.7,1],"mirror":[false,false,true,true,true,false,false,true,false],"colorize":"slight","bitmap":"treeB"},"img001":{"bitmap":"mountainB","x":192,"y":107}},"City":{"backdrop":"City"},"Sand":{"backdrop":"Sand"},"IndoorB":{"backdrop":"IndoorB"},"Sapphire":{"backdrop":"Sapphire"}};
const BSS079_EBDX_BGS=['Cave', 'CaveDark', 'Champion', 'City', 'DanceFloor', 'Darkness', 'Field', 'Forest', 'IndoorA', 'IndoorB', 'Mountain', 'Net', 'Sand', 'Sapphire', 'Sky', 'Snow', 'Underwater', 'Water'];
const BSS079_EBDX_BASES=['', 'Concrete', 'Dirt', 'Puddle', 'Water'];
const BSS079_EBDX_ELEMENTS=['base001', 'base001a', 'base001c', 'bubble', 'bubbleDark', 'bubbleRed', 'cloud1', 'cloud2', 'cluster', 'crowd', 'crowd_d', 'dark001', 'dark002', 'dark003', 'dark004', 'dark005', 'dark006', 'darkFog', 'decor', 'decor001', 'decor002', 'decor003', 'decor003a', 'decor003d', 'decor004', 'decor005', 'decor006', 'decor007', 'decor008', 'decor009', 'discoBg', 'fog', 'forestShade', 'lightA', 'lightB', 'lightC1', 'lightC2', 'lightC3', 'lightDecor', 'mountain', 'mountainB', 'mountainC', 'pillars', 'pillars001', 'pillars002', 'rocks', 'seaWeed', 'shade', 'skyDawn', 'skyDay', 'skyNight', 'snow', 'star', 'sun', 'tallGrass', 'tree', 'treeB', 'treeC', 'treePine', 'water0', 'water1'];

App.prototype.ebdxCustomRows=function(){this.studio.global=this.studio.global||{};if(!Array.isArray(this.studio.global.ebdxCustomEnvironments))this.studio.global.ebdxCustomEnvironments=[];return this.studio.global.ebdxCustomEnvironments;};
App.prototype.ebdxBackdropChoices=function(includeInherit){const out=[];if(includeInherit)out.push({id:"inherit",label:"Usar ajuste global"});out.push({id:"Auto",label:"Auto · entorno/terreno"});Object.keys(BSS079_EBDX_BUILTINS).forEach(id=>out.push({id,label:id+" · EBDX"}));this.ebdxCustomRows().forEach(r=>out.push({id:S(r.id),label:S(r.name||r.id)+" · Custom"}));return out;};
App.prototype.ebdxPreviewBackdropName=function(name){const r=this.ebdxCustomRows().find(x=>S(x.id)===S(name)),raw=r&&r.data&&r.data.backdrop;let v=S(raw||name||"Field");if(v.indexOf("/")>=0||v.indexOf("\\")>=0)return "Field";v=v.replace(/^.*[\\/]/,"").replace(/\.[^.]+$/,"");return BSS079_EBDX_BGS.includes(v)?v:"Field";};
App.prototype.ebdxCurrentCustom=function(){const id=S(this.ebdxStudioSelected);if(!id)return null;const rows=this.ebdxCustomRows();return rows.find(x=>S(x.id)===id)||null;};
App.prototype.ebdxUniqueId=function(name,except){let base=slug(name||"ebdx_custom"),id=base,n=2;const rows=this.ebdxCustomRows();while(rows.some(x=>S(x.id)===id&&S(x.id)!==S(except)))id=base+"_"+(n++);return id;};
App.prototype.ebdxLayerRows=function(data){return Object.keys(data||{}).filter(k=>/^img\d+/i.test(k)&&data[k]&&typeof data[k]==="object").sort().map(k=>[k,data[k]]);};
App.prototype.ebdxNewLayerKey=function(data){let i=1,k="";do{k="img"+String(i++).padStart(3,"0");}while(data[k]);return k;};
App.prototype.ebdxRenderJson=function(r){try{return JSON.stringify(r&&r.data||{},null,2);}catch(_){return "{}";}};
App.prototype.ebdxStudioView=function(){
  const r=this.ebdxCurrentCustom();if(r)return {kind:"custom",id:S(r.id),name:S(r.name||r.id),data:r.data&&typeof r.data==="object"?r.data:{},row:r};
  const id=BSS079_EBDX_BUILTINS[S(this.ebdxStudioBuiltin)]?S(this.ebdxStudioBuiltin):"Field";
  return {kind:"builtin",id,name:id+" · Default EBDX",data:JSON.parse(JSON.stringify(BSS079_EBDX_BUILTINS[id]||BSS079_EBDX_BUILTINS.Field)),row:null};
};
App.prototype.ebdxFeatureBadges=function(data){const out=[];if(data.sky)out.push("Cielo dinámico");if(data.trees)out.push("Árboles");if(data.tallGrass)out.push("Hierba");if(data.water)out.push("Agua animada");if(data.lightsA||data.lightsB||data.lightsC||data.spinLights)out.push("Luces");if(data.bubbles)out.push("Burbujas");if(data.vacuum)out.push("Vacuum");const imgs=Object.keys(data||{}).filter(k=>/^img\d+/i.test(k)).length;if(imgs)out.push(imgs+" capas extra");return out;};
App.prototype.renderEBDXStudio=function(){
  const rows=this.ebdxCustomRows(),view=this.ebdxStudioView(),r=view.row,data=view.data,layers=this.ebdxLayerRows(data),builtin=view.kind==="builtin";
  const presetCards=Object.keys(BSS079_EBDX_BUILTINS).map(id=>`<button class="bss-ebdx-preset ${builtin&&view.id===id?"active":""}" data-ebdx-builtin="${E(id)}"><b>${E(id)}</b><small>${E(this.ebdxFeatureBadges(BSS079_EBDX_BUILTINS[id]).join(" · ")||"Backdrop EBDX")}</small></button>`).join("");
  const customList=rows.map(x=>`<button class="bss-ebdx-custom ${!builtin&&S(r&&r.id)===S(x.id)?"active":""}" data-ebdx-select="${E(x.id)}"><b>${E(x.name||x.id)}</b><small>${E(x.id)}</small></button>`).join("")||`<div class="bss-empty small">Todavía no creaste fondos propios.</div>`;
  const badges=this.ebdxFeatureBadges(data).map(x=>`<span class="bss-pill">${E(x)}</span>`).join("");
  const simpleToggle=(key,label,help)=>`<label class="bss-ebdx-friendly-toggle"><input type="checkbox" data-ebdx-top="${E(key)}" ${data[key]===true?"checked":""} ${builtin?"disabled":""}><span><b>${E(label)}</b><small>${E(help)}</small></span></label>`;
  const layerHtml=layers.map(([key,x])=>`<article class="bss-ebdx-layer"><header><b>${E(key)} · ${E(x.bitmap||"Capa")}</b>${builtin?"":`<div class="bss-row"><button class="bss-btn small" data-ebdx-layer-duplicate="${E(key)}">Duplicar</button><button class="bss-btn danger small" data-ebdx-layer-remove="${E(key)}">Eliminar</button></div>`}</header><div class="bss-mini-grid"><label class="bss-mini-field"><span>Imagen</span><input class="bss-input" list="bss079-ebdx-elements" data-ebdx-layer="${E(key)}:bitmap" value="${E(x.bitmap||"")}" ${builtin?"disabled":""}></label><label class="bss-mini-field"><span>Posición X</span><input class="bss-input" type="number" data-ebdx-layer="${E(key)}:x" value="${N(x.x,0)}" ${builtin?"disabled":""}></label><label class="bss-mini-field"><span>Posición Y</span><input class="bss-input" type="number" data-ebdx-layer="${E(key)}:y" value="${N(x.y,0)}" ${builtin?"disabled":""}></label><label class="bss-mini-field"><span>Profundidad</span><input class="bss-input" type="number" data-ebdx-layer="${E(key)}:z" value="${N(x.z,0)}" ${builtin?"disabled":""}></label><label class="bss-mini-field"><span>Velocidad</span><input class="bss-input" type="number" step="0.1" data-ebdx-layer="${E(key)}:speed" value="${N(x.speed,1)}" ${builtin?"disabled":""}></label></div><div class="bss-ebdx-layer-flags"><label class="bss-check"><input type="checkbox" data-ebdx-layer="${E(key)}:scrolling" ${x.scrolling===true?"checked":""} ${builtin?"disabled":""}> Loop continuo</label><label class="bss-check"><input type="checkbox" data-ebdx-layer="${E(key)}:vertical" ${x.vertical===true?"checked":""} ${builtin?"disabled":""}> Scroll vertical</label><label class="bss-check"><input type="checkbox" data-ebdx-layer="${E(key)}:flat" ${x.flat===true?"checked":""} ${builtin?"disabled":""}> Pegado al plano</label></div></article>`).join("");
  this.body.innerHTML=`<section class="bss-ebdx-studio-screen"><div class="bss-libhead"><button class="bss-btn" data-nav="library">← Battles</button><div class="bss-aura-title"><b>EBDX Studio</b><small>Primero mira cómo están construidos los fondos default. Sólo duplica uno cuando quieras editarlo.</small></div><div class="bss-spacer"></div>${builtin?`<button class="bss-btn primary" data-ebdx-clone="${E(view.id)}">Duplicar ${E(view.id)} y editar</button>`:`<button class="bss-btn danger" data-act="ebdx-delete">Eliminar custom</button>`}</div><div class="bss-ebdx-workspace"><aside class="bss-ebdx-sidebar"><h3>Fondos default EBDX</h3><p class="bss-note">Seleccionar sólo los muestra. No crea nada.</p><div class="bss-ebdx-preset-list">${presetCards}</div><h3>Mis fondos</h3>${customList}</aside><main class="bss-ebdx-main"><div class="bss-ebdx-head"><div>${builtin?`<b class="bss-ebdx-readonly-title">${E(view.name)}</b><small>Solo lectura · configuración original</small>`:`<input class="bss-input bss-ebdx-name" data-ebdx-name value="${E(view.name)}"><small>ID: ${E(view.id)}</small>`}<div class="bss-row">${badges}</div></div><div class="bss-ebdx-preview" data-ebdx-preview><span>Preview</span></div></div><section class="bss-panel"><h3>Construcción visual</h3><p class="bss-note">Estos son los bloques que EBDX combina para formar el escenario. En un custom puedes arrastrar capas, árboles y hierba directamente sobre la preview 384×308.</p><div class="bss-ebdx-friendly-grid">${simpleToggle("sky","Cielo","Día, amanecer, noche, nubes, sol y estrellas.")}${simpleToggle("water","Agua","Capas animadas en loop continuo.")}${simpleToggle("lightsA","Luces de escenario","Iluminación ambiental tipo arena.")}${simpleToggle("lightsB","Luces disco","Variación y pulsos de color.")}${simpleToggle("lightsC","Luces ambientales","Brillos dentro del escenario.")}${simpleToggle("spinLights","Luces giratorias","Elementos rotatorios de escenario.")}</div><div class="bss-mini-grid"><label class="bss-mini-field"><span>Imagen base</span><select class="bss-select" data-ebdx-field="backdrop" ${builtin?"disabled":""}>${(S(data.backdrop||"").includes("/")?[S(data.backdrop)]:[]).concat(BSS079_EBDX_BGS).map(x=>`<option value="${E(x)}" ${S(data.backdrop||"Field")===x?"selected":""}>${E(x.includes("/")?"Custom · "+x.split("/").slice(-2).join("/"):x)}</option>`).join("")}</select></label><label class="bss-mini-field"><span>Suelo/base</span><select class="bss-select" data-ebdx-field="base" ${builtin?"disabled":""}>${BSS079_EBDX_BASES.map(x=>`<option value="${E(x)}" ${S(data.base||"")===x?"selected":""}>${E(x||"Sin base extra")}</option>`).join("")}</select></label></div></section><details class="bss-panel" ${layers.length?"open":""}><summary><b>Capas y elementos (${layers.length})</b> · para ajustes finos</summary><p class="bss-note">Las capas con Loop continuo usan un bitmap cíclico real; no desaparecen ni vuelven al frame inicial al abrir menús.</p>${builtin?"":`<button class="bss-btn" data-act="ebdx-layer-add">＋ Añadir capa</button>`}${layerHtml||`<div class="bss-empty">Este preset no usa capas img adicionales.</div>`}</details><details class="bss-panel"><summary><b>Avanzado · JSON EBDX</b></summary><p class="bss-note">Sólo para quien necesite editar directamente trees, tallGrass, img001…, luces, vacuum o bubbles.</p><textarea class="bss-textarea bss-ebdx-json" data-ebdx-json ${builtin?"readonly":""}>${E(JSON.stringify(data||{},null,2))}</textarea>${builtin?"":`<div class="bss-row"><button class="bss-btn primary" data-act="ebdx-json-apply">Aplicar JSON</button></div>`}</details><datalist id="bss079-ebdx-elements">${BSS079_EBDX_ELEMENTS.map(x=>`<option value="${E(x)}"></option>`).join("")}</datalist></main></div></section>`;
  this.hydrateEBDXStudioPreview();
};
App.prototype.hydrateEBDXStudioPreview=async function(){const el=this.body&&this.body.querySelector("[data-ebdx-preview]"),view=this.ebdxStudioView();if(!el||!view)return;let bg=S(view.data&&view.data.backdrop||"Field"),path=bg.indexOf("/")>=0?bg:`Graphics/BattleSceneStudio/EBDX/Battlebacks/battlebg/${bg}.png`;try{const url=await this.assetUrl({projectPath:path});if(url&&el.isConnected)el.innerHTML=`<img src="${E(url)}" alt=""><span>${E(bg)} · room EBDX</span>`;}catch(_){} };

const _bss079Click=App.prototype.onClick;
App.prototype.onClick=function(e){const raw=e&&e.target,t=raw&&typeof raw.closest==="function"?raw.closest("button,[data-resize]"):null;if(t){
  const act=S(t.dataset.act);
  if(act==="open-ebdx-studio"){this.globalSettingsOpen=false;const m=this.root.querySelector("[data-global-settings-modal]");if(m)this.safeRemove(m);this.screen="ebdx";return this.render();}
  if(act==="ebdx-new"){const src=BSS079_EBDX_BUILTINS.Field,rows=this.ebdxCustomRows(),id=this.ebdxUniqueId("field_custom");rows.push({id,name:"Field Custom",data:JSON.parse(JSON.stringify(src))});this.ebdxStudioSelected=id;this.saveSoon();return this.renderEBDXStudio();}
  if(act==="ebdx-delete"){const r=this.ebdxCurrentCustom();if(!r)return;const rows=this.ebdxCustomRows(),i=rows.indexOf(r);if(i>=0)rows.splice(i,1);this.ebdxStudioSelected="";this.ebdxStudioBuiltin="Field";this.saveSoon();return this.renderEBDXStudio();}
  if(t.dataset.ebdxSelect!=null){this.ebdxStudioSelected=S(t.dataset.ebdxSelect);return this.renderEBDXStudio();}
  if(t.dataset.ebdxBuiltin!=null){this.ebdxStudioSelected="";this.ebdxStudioBuiltin=S(t.dataset.ebdxBuiltin)||"Field";return this.renderEBDXStudio();}
  if(t.dataset.ebdxClone!=null){const src=BSS079_EBDX_BUILTINS[S(t.dataset.ebdxClone)];if(!src)return;const rows=this.ebdxCustomRows(),base=S(t.dataset.ebdxClone)+" Custom",id=this.ebdxUniqueId(base);rows.push({id,name:base,data:JSON.parse(JSON.stringify(src))});this.ebdxStudioSelected=id;this.saveSoon();return this.renderEBDXStudio();}
  if(act==="ebdx-layer-add"){const r=this.ebdxCurrentCustom();if(!r)return;r.data=r.data&&typeof r.data==="object"?r.data:{};const k=this.ebdxNewLayerKey(r.data);r.data[k]={bitmap:"decor005",x:0,y:0,z:1,flat:true,scrolling:false,speed:1,direction:1};this.saveSoon();return this.renderEBDXStudio();}
  if(t.dataset.ebdxLayerDuplicate!=null){const r=this.ebdxCurrentCustom();if(!r||!r.data)return;const src=r.data[S(t.dataset.ebdxLayerDuplicate)];if(!src||typeof src!=="object")return;const k=this.ebdxNewLayerKey(r.data);r.data[k]=JSON.parse(JSON.stringify(src));r.data[k].x=N(r.data[k].x,0)+8;r.data[k].y=N(r.data[k].y,0)+8;this.saveSoon();return this.renderEBDXStudio();}
  if(t.dataset.ebdxLayerRemove!=null){const r=this.ebdxCurrentCustom();if(!r||!r.data)return;delete r.data[S(t.dataset.ebdxLayerRemove)];this.saveSoon();return this.renderEBDXStudio();}
  if(act==="ebdx-json-apply"){const r=this.ebdxCurrentCustom(),ta=this.body.querySelector("[data-ebdx-json]");if(!r||!ta)return;try{const v=JSON.parse(S(ta.value));if(!v||typeof v!=="object"||Array.isArray(v))throw new Error("El JSON debe ser un objeto");r.data=v;this.saveSoon();this.toast("Datos EBDX aplicados");return this.renderEBDXStudio();}catch(err){return this.toast("JSON EBDX inválido: "+S(err&&err.message||err),true);}}
}return _bss079Click.call(this,e);};

const _bss079Input=App.prototype.onInput;
App.prototype.onInput=function(e){const t=e&&e.target;if(t&&t.dataset){const r=this.ebdxCurrentCustom();
  if(t.dataset.ebdxName!=null&&r){r.name=S(t.value)||"EBDX Custom";this.saveSoon();return;}
  if(t.dataset.ebdxField!=null&&r){r.data=r.data&&typeof r.data==="object"?r.data:{};const k=S(t.dataset.ebdxField),v=S(t.value);if(k==="base"||k==="bubbles"||k==="vacuum"){if(v)r.data[k]=v;else delete r.data[k];}else r.data[k]=v;this.saveSoon();if(k==="backdrop")this.hydrateEBDXStudioPreview();return;}
  if(t.dataset.ebdxTop!=null&&r){r.data=r.data&&typeof r.data==="object"?r.data:{};const k=S(t.dataset.ebdxTop);if(t.checked)r.data[k]=true;else delete r.data[k];this.saveSoon();return;}
  if(t.dataset.ebdxLayer!=null&&r){const parts=S(t.dataset.ebdxLayer).split(":"),key=parts.shift(),field=parts.join(":"),x=r.data&&r.data[key];if(!x||typeof x!=="object")return;let v=t.type==="checkbox"?!!t.checked:(t.type==="number"?N(t.value):S(t.value));if(["x","y","z","zoom","opacity","speed","direction"].includes(field))v=N(v,field==="zoom"||field==="speed"||field==="direction"?1:0);if(t.type==="checkbox"&&!v)delete x[field];else if((field==="effect"||field==="bitmap")&&!S(v))delete x[field];else x[field]=v;this.saveSoon();return;}
}return _bss079Input.call(this,e);};

// ============================================================================
// BSS v0.6.86 - source-faithful EBDX Studio preview
// The preview is assembled from the same 384x308 authoring layers as runtime.
// ============================================================================
App.prototype.bss083EBDXAssetPath=function(kind,name){name=S(name);if(!name)return "";if(name.indexOf("Graphics/")===0)return name;return "Graphics/BattleSceneStudio/EBDX/Battlebacks/"+kind+"/"+name+".png";};
App.prototype.bss083LoadImage=async function(path){if(!path)return null;try{const url=await this.assetUrl({projectPath:path});if(!url)return null;return await new Promise(function(resolve){const im=new Image();im.onload=function(){resolve(im);};im.onerror=function(){resolve(null);};im.src=url;});}catch(_){return null;}};
App.prototype.bss083CanvasTint=function(img,color,amount){if(!img||!color)return img;const c=document.createElement("canvas");c.width=img.width;c.height=img.height;const x=c.getContext("2d");x.imageSmoothingEnabled=false;x.drawImage(img,0,0);x.globalCompositeOperation="source-atop";x.globalAlpha=Math.max(0,Math.min(1,N(amount,255)/255));x.fillStyle="rgb("+color[0]+","+color[1]+","+color[2]+")";x.fillRect(0,0,c.width,c.height);x.globalAlpha=1;x.globalCompositeOperation="source-over";return c;};
App.prototype.bss083SampleCanvas=function(ctx,x,y){try{const d=ctx.getImageData(Math.max(0,Math.min(383,Math.round(x))),Math.max(0,Math.min(307,Math.round(y))),1,1).data;return [d[0],d[1],d[2],d[3]];}catch(_){return [180,190,200,255];}};
App.prototype.bss083DrawAnchored=function(ctx,img,x,y,zoomX,mirror,ox,oy,angle=0,zoomY=null){if(!img)return;zoomX=N(zoomX,1);zoomY=zoomY==null?zoomX:N(zoomY,zoomX);x=N(x,0);y=N(y,0);const hasOx=ox!=null,hasOy=oy!=null;const ax=hasOx?N(ox,0):img.width/2,ay=hasOy?N(oy,0):img.height;ctx.save();ctx.translate(x,y);ctx.rotate(N(angle,0)*Math.PI/180);ctx.scale((mirror?-1:1)*zoomX,zoomY);ctx.drawImage(img,-ax,-ay);ctx.restore();ctx.imageSmoothingEnabled=false;ctx.filter="none";};
App.prototype.bss083EBDXComposite=async function(canvas,view){
  const data=view.data||{},ctx=canvas.getContext("2d");canvas.width=384;canvas.height=308;ctx.imageSmoothingEnabled=false;ctx.clearRect(0,0,384,308);
  const bgName=S(data.backdrop||"Field"),bg=await this.bss083LoadImage(this.bss083EBDXAssetPath("battlebg",bgName));
  let wideCrop=null;
  if(bg){
    if((data.wideWorld===true||bg.width>384||bg.height>308)&&(bg.width>384||bg.height>308)){
      const sx=Math.max(0,Math.floor((bg.width-384)/2)),sy=Math.max(0,Math.floor((bg.height-308)/2));
      const sw=Math.min(384,bg.width-sx),sh=Math.min(308,bg.height-sy);wideCrop={sx,sy,sw,sh};
      ctx.drawImage(bg,sx,sy,sw,sh,0,0,384,308);
    }else ctx.drawImage(bg,0,0,384,308);
  }else{ctx.fillStyle="#182331";ctx.fillRect(0,0,384,308);}
  const base=data.base?await this.bss083LoadImage(this.bss083EBDXAssetPath("base",data.base)):null;if(base){const sx=Math.max(0,Math.floor((base.width-384)/2)),sw=Math.min(384,base.width-sx);ctx.drawImage(base,sx,0,sw,base.height,0,308-base.height,384,base.height);}
  const sky=data.sky?await this.bss083LoadImage(this.bss083EBDXAssetPath("elements","skyDay")):null;if(sky){const sx=Math.max(0,Math.floor((sky.width-384)/2)),sw=Math.min(384,sky.width-sx);ctx.drawImage(sky,sx,0,sw,sky.height,0,0,384,sky.height);}
  if(data.sky&&sky){for(const row of [["cloud1",98,1],["cloud2",91,-1]]){const im=await this.bss083LoadImage(this.bss083EBDXAssetPath("elements",row[0]));if(!im)continue;const sample=this.bss083SampleCanvas(ctx,0,row[1]);const tint=this.bss083CanvasTint(im,sample,255),sx=Math.max(0,Math.floor((tint.width-384)/2)),sw=Math.min(384,tint.width-sx);ctx.drawImage(tint,sx,0,sw,tint.height,0,row[1]-tint.height,384,tint.height);}}
  const drawGroup=async(groupName,defaultBitmap)=>{const g=data[groupName];if(!g||typeof g!=="object")return;const im0=await this.bss083LoadImage(this.bss083EBDXAssetPath("elements",g.bitmap||defaultBitmap));if(!im0)return;const count=Math.max(0,N(g.elements,0));for(let i=0;i<count;i++){const x=Array.isArray(g.x)?N(g.x[i],0):0,y=Array.isArray(g.y)?N(g.y[i],0):0,z=Array.isArray(g.zoom)?N(g.zoom[i],1):1,mir=Array.isArray(g.mirror)?!!g.mirror[i]:false;let im=im0;const mode=Object.prototype.hasOwnProperty.call(g,"colorize")?g.colorize:true;if(mode!==false){const sample=this.bss083SampleCanvas(ctx,x,y);im=this.bss083CanvasTint(im0,sample,S(mode)==="slight"?128:255);}this.bss083DrawAnchored(ctx,im,x,y,z,mir,null,null);}};
  await drawGroup("trees","tree");await drawGroup("tallGrass","tallGrass");
  const imgKeys=Object.keys(data).filter(function(k){return /^img\d+/i.test(k)&&data[k]&&typeof data[k]==="object";}).sort(function(a,b){const za=N(data[a]&&data[a].z,0),zb=N(data[b]&&data[b].z,0);return za===zb?String(a).localeCompare(String(b)):za-zb;});
  for(const key of imgKeys){const d=data[key],im0=await this.bss083LoadImage(this.bss083EBDXAssetPath("elements",d.bitmap));if(!im0)continue;const x=N(d.x,0),y=N(d.y,0),zoom=N(d.zoom,1),zoomX=d.zoom_x!=null?N(d.zoom_x,zoom):zoom,zoomY=d.zoom_y!=null?N(d.zoom_y,zoom):zoom,ox=d.ox!=null?N(d.ox,0):null,oy=d.oy!=null?N(d.oy,0):null,angle=N(d.angle,0);let im=im0;if(d.colorize===true||S(d.colorize)==="slight"){const sample=this.bss083SampleCanvas(ctx,x,y);im=this.bss083CanvasTint(im0,sample,S(d.colorize)==="slight"?128:255);}ctx.save();ctx.globalAlpha=Math.max(0,Math.min(1,N(d.opacity,255)/255));ctx.filter=N(d.blur,0)>0?`blur(${Math.max(0,Math.min(12,N(d.blur,0)))}px)`:"none";if(d.canvasLayer===true&&wideCrop){const sx=Math.min(wideCrop.sx,Math.max(0,im.width-wideCrop.sw)),sy=Math.min(wideCrop.sy,Math.max(0,im.height-wideCrop.sh));ctx.drawImage(im,sx,sy,wideCrop.sw,wideCrop.sh,0,0,384,308);}else if(d.warp&&d.warp.enabled===true&&typeof this.bss093DrawWarped==="function"){this.bss093DrawWarped(ctx,im,d);}else if(d.scrolling&&angle===0){const tileW=Math.max(1,im.width*Math.abs(zoomX)),tileH=Math.max(1,im.height*Math.abs(zoomY)),anchorX=(ox!=null?ox:im.width/2)*Math.abs(zoomX),anchorY=(oy!=null?oy:im.height)*Math.abs(zoomY);if(d.vertical){const xx=x-anchorX,baseY=y-anchorY,startY=((baseY%tileH)+tileH)%tileH-tileH;for(let py=startY;py<308+tileH;py+=tileH)ctx.drawImage(im,xx,py,im.width*zoomX,im.height*zoomY);}else{const yy=y-anchorY,baseX=x-anchorX,startX=((baseX%tileW)+tileW)%tileW-tileW;for(let px=startX;px<384+tileW;px+=tileW)ctx.drawImage(im,px,yy,im.width*zoomX,im.height*zoomY);}}else this.bss083DrawAnchored(ctx,im,x,y,zoomX,false,ox,oy,angle,zoomY);ctx.restore();}
  if(data.water){for(const row of [["water0",146,false],["water1",146,true]]){const im=await this.bss083LoadImage(this.bss083EBDXAssetPath("elements",row[0]));if(!im)continue;ctx.save();if(row[2]){ctx.translate(384,0);ctx.scale(-1,1);}const sx=Math.max(0,Math.floor((im.width-384)/2)),sw=Math.min(384,im.width-sx);ctx.drawImage(im,sx,0,sw,im.height,0,row[1],384,im.height);ctx.restore();}}
  // Position handles use the exact EBDX 384x308 author grid. Built-ins are
  // intentionally read-only; custom img### layers can be dragged directly.
  const handles=[];
  if(view.kind==="custom"){for(const key of imgKeys){const d=data[key];if(d.canvasLayer===true)continue;handles.push({kind:"img",key:key,x:N(d.x,0),y:N(d.y,0),z:N(d.z,0)});}
    for(const groupName of ["trees","tallGrass"]){const g=data[groupName];if(!g||!Array.isArray(g.x)||!Array.isArray(g.y))continue;const n=Math.min(g.x.length,g.y.length);for(let i=0;i<n;i++)handles.push({kind:"group",key:groupName,index:i,x:N(g.x[i],0),y:N(g.y[i],0),z:Array.isArray(g.z)?N(g.z[i],3):3});}}
  return {ctx:ctx,imgKeys:imgKeys,handles:handles};
};
App.prototype.hydrateEBDXStudioPreview=async function(){
  const el=this.body&&this.body.querySelector("[data-ebdx-preview]"),view=this.ebdxStudioView();if(!el||!view)return;
  el.innerHTML='<canvas class="bss-ebdx-preview-canvas" width="384" height="308"></canvas><span>Compositor EBDX · 384×308</span>';
  const canvas=el.querySelector("canvas");if(!canvas)return;const stamp=(this._bss083PreviewStamp||0)+1;this._bss083PreviewStamp=stamp;const state=await this.bss083EBDXComposite(canvas,view);if(stamp!==this._bss083PreviewStamp||!canvas.isConnected)return;
  if(view.kind!=="custom")return;
  const self=this;let drag=null;
  function point(ev){const r=canvas.getBoundingClientRect();return {x:(ev.clientX-r.left)*384/Math.max(1,r.width),y:(ev.clientY-r.top)*308/Math.max(1,r.height)};}
  canvas.addEventListener("pointerdown",function(ev){const p=point(ev);let best=null,bestD=9999;for(const h of state.handles||[]){const dx=h.x-p.x,dy=h.y-p.y,dist=Math.sqrt(dx*dx+dy*dy);if(dist<bestD){bestD=dist;best=h;}}if(!best||bestD>28)return;drag=best;try{if(canvas.isConnected&&typeof canvas.setPointerCapture==="function"&&ev.pointerId!=null)canvas.setPointerCapture(ev.pointerId);}catch(_){}ev.preventDefault();});
  canvas.addEventListener("pointermove",function(ev){if(!drag)return;const p=point(ev),rawX=Math.max(-192,Math.min(576,p.x)),rawY=Math.max(-154,Math.min(462,p.y)),nx=ev.shiftKey?Math.round(rawX):self.bss072Snap(rawX),ny=ev.shiftKey?Math.round(rawY):self.bss072Snap(rawY);if(drag.kind==="img"){const row=view.data&&view.data[drag.key];if(!row)return;row.x=nx;row.y=ny;}else{const g=view.data&&view.data[drag.key];if(!g||!Array.isArray(g.x)||!Array.isArray(g.y))return;g.x[drag.index]=nx;g.y[drag.index]=ny;}drag.x=nx;drag.y=ny;self.saveSoon();self.bss083EBDXComposite(canvas,view);});
  canvas.addEventListener("pointerup",function(ev){if(!drag)return;drag=null;try{canvas.releasePointerCapture(ev.pointerId);}catch(_){}self.renderEBDXStudio();});
};

// Re-render the real composite immediately when a custom layer changes.
const _bss083Input=App.prototype.onInput;
App.prototype.onInput=function(e){const t=e&&e.target,was=!!(t&&t.dataset&&(t.dataset.ebdxField!=null||t.dataset.ebdxTop!=null||t.dataset.ebdxLayer!=null));const out=_bss083Input.call(this,e);if(was&&this.screen==="ebdx")this.hydrateEBDXStudioPreview();return out;};


// ============================================================================
// BSS v0.7.2 - Visual Map Metadata + EBDX Scene authoring precision
// ============================================================================
App.prototype.bss072MapRows=function(){this.studio.global=this.studio.global||{};if(!Array.isArray(this.studio.global.ebdxMapMetadata))this.studio.global.ebdxMapMetadata=[];return this.studio.global.ebdxMapMetadata;};
App.prototype.bss072ProjectMaps=function(){const rows=A(this.source&&this.source.maps);if(rows.length)return rows;return this.bss072MapRows().map(r=>({mapId:N(r.mapId),id:N(r.mapId),name:S(r.mapName||("Map "+N(r.mapId)))}));};
App.prototype.bss072MapMetadataPanel=function(){
  const rows=this.bss072MapRows(),maps=this.bss072ProjectMaps(),choices=this.ebdxBackdropChoices(false);
  const cards=rows.map((r,i)=>{const id=N(r.mapId),pm=maps.find(x=>N(x.mapId||x.id)===id),name=S(r.mapName||(pm&&pm.name)||("Map "+id)),bg=S(r.backdrop||"Auto"),preview=this.ebdxPreviewBackdropName(bg);return `<article class="bss-mapmeta-card"><div class="bss-mapmeta-thumb" data-mapmeta-preview="${E(preview)}"></div><div class="bss-mapmeta-main"><b>${E(name)}</b><small>Mapa ${id}</small><div class="bss-row"><select class="bss-select" data-mapmeta-bg="${i}">${choices.map(x=>`<option value="${E(x.id)}" ${bg===x.id?"selected":""}>${E(x.label)}</option>`).join("")}</select><button class="bss-btn danger small" data-mapmeta-remove="${i}">Quitar</button></div></div></article>`;}).join("");
  const opts=maps.map(m=>`<option value="${N(m.mapId||m.id)}">${E(S(m.name||("Map "+N(m.mapId||m.id))))} · ${N(m.mapId||m.id)}</option>`).join("");
  return `<section class="bss-global-settings-section bss-mapmeta-section"><h3>Metadata visual por mapa</h3><p class="bss-note">Equivale a asignar un BattleEnv por mapa, pero sin escribir IDs a mano. Auto hereda el contexto; cualquier escenario explícito es autoridad EBDX.</p><div class="bss-row"><select class="bss-select" data-mapmeta-new>${opts||'<option value="">No se pudo leer PBS/map_metadata.txt</option>'}</select><button class="bss-btn primary" data-act="mapmeta-add">＋ Asignar mapa</button></div><div class="bss-mapmeta-grid">${cards||'<div class="bss-empty">Sin overrides por mapa.</div>'}</div></section>`;
};
App.prototype.bss072InjectGlobalSettings=function(){const card=this.root.querySelector(".bss-global-settings-card");if(!card||card.querySelector(".bss-mapmeta-section"))return;const wrap=document.createElement("div");wrap.innerHTML=this.bss072MapMetadataPanel();const org=[...card.querySelectorAll(".bss-global-settings-section")].find(x=>x.querySelector("h3")&&x.querySelector("h3").textContent.includes("Organización"));card.insertBefore(wrap.firstElementChild,org||null);
  const camera=[...card.querySelectorAll(".bss-global-settings-section")].find(x=>x.querySelector("h3")&&x.querySelector("h3").textContent.includes("Cámara / fondos"));if(camera&&!camera.querySelector("[data-studio-global='battleSceneEngine']")){const box=document.createElement("div");box.className="bss-field";box.innerHTML=`<label>Motor de escena</label><select class="bss-select" data-studio-global="battleSceneEngine"><option value="blueprint">Por combate / Blueprint</option><option value="ebdx">EBDX Core · todos</option><option value="vanilla">Vanilla / Essentials · todos</option></select><span class="bss-note">Selector maestro A/B. No modifica los Blueprints.</span>`;const sel=box.querySelector("select");sel.value=S((this.studio.global||{}).battleSceneEngine||"blueprint");camera.insertBefore(box,camera.children[1]||null);}
};
const _bss072RenderGlobal=App.prototype.renderGlobalSettingsModal;App.prototype.renderGlobalSettingsModal=function(){const out=_bss072RenderGlobal.call(this);this.bss072InjectGlobalSettings();this.bss072HydrateMapPreviews();return out;};
App.prototype.bss072HydrateMapPreviews=async function(){for(const el of [...this.root.querySelectorAll("[data-mapmeta-preview]")]){const bg=S(el.dataset.mapmetaPreview||"Field"),path=`Graphics/BattleSceneStudio/EBDX/preview/${bg}.png`;try{const url=await this.assetUrl({projectPath:path});if(url&&el.isConnected)el.innerHTML=`<img src="${E(url)}" alt="${E(bg)}"><span>${E(bg)}</span>`;}catch(_){}}};
const _bss072Click=App.prototype.onClick;App.prototype.onClick=function(e){const t=e&&e.target,act=S(t&&t.dataset&&t.dataset.act);if(act==="mapmeta-add"){const sel=this.root.querySelector("[data-mapmeta-new]"),id=N(sel&&sel.value);if(!id)return;const maps=this.bss072ProjectMaps(),pm=maps.find(x=>N(x.mapId||x.id)===id),rows=this.bss072MapRows();if(!rows.some(x=>N(x.mapId)===id))rows.push({mapId:id,mapName:S(pm&&pm.name||("Map "+id)),backdrop:"Auto"});this.saveSoon();this.renderGlobalSettingsModal();return;}if(t&&t.dataset&&t.dataset.mapmetaRemove!=null){this.bss072MapRows().splice(N(t.dataset.mapmetaRemove),1);this.saveSoon();this.renderGlobalSettingsModal();return;}return _bss072Click.call(this,e);};
const _bss072Input=App.prototype.onInput;App.prototype.onInput=function(e){const t=e&&e.target;if(t&&t.dataset&&t.dataset.mapmetaBg!=null){const r=this.bss072MapRows()[N(t.dataset.mapmetaBg)];if(r){r.backdrop=S(t.value||"Auto");this.saveSoon();this.renderGlobalSettingsModal();}return;}return _bss072Input.call(this,e);};

// Precision controls for EBDX Scene Studio: grid/snap and direct nudging.
App.prototype.bss072SceneGrid=8;
App.prototype.bss072Snap=function(v){const g=Math.max(1,N(this.bss072SceneGrid,1));return Math.round(N(v)/g)*g;};
const _bss072RenderE=App.prototype.renderEBDXStudio;App.prototype.renderEBDXStudio=function(){const out=_bss072RenderE.call(this);const main=this.body&&this.body.querySelector(".bss-ebdx-main");if(main&&!main.querySelector(".bss072-scene-toolbar")){const bar=document.createElement("div");bar.className="bss072-scene-toolbar";bar.innerHTML=`<b>Colocación precisa</b><label>Grid <select class="bss-select" data-ebdx-grid><option>1</option><option>2</option><option>4</option><option selected>8</option><option>16</option><option>32</option></select></label><span class="bss-note">Arrastra en preview; Shift = 1 px. Los X/Y/Z del inspector siguen siendo editables.</span>`;main.insertBefore(bar,main.children[1]||null);const sel=bar.querySelector("select");sel.value=String(this.bss072SceneGrid||8);}return out;};
const _bss072Input2=App.prototype.onInput;App.prototype.onInput=function(e){const t=e&&e.target;if(t&&t.dataset&&t.dataset.ebdxGrid!=null){this.bss072SceneGrid=Math.max(1,N(t.value,8));return;}return _bss072Input2.call(this,e);};
// Override source-faithful preview drag with snapping after it mutates data: pointermove is
// already precise in author-space; numeric inspector remains the authoritative fine control.


// ============================================================================
// BSS v0.7.8 - EBDX scene-context, camera authoring and file-backed metadata
// ============================================================================
App.prototype.bss076EnsureEBDXGlobals=function(){
  this.studio.global=this.studio.global||{};
  const g=this.studio.global;
  g.ebdxCamera=Object.assign({preset:"gen5_plus",idleStrength:28,commandStrength:45,fightStrength:65,panX:100,panY:100,angle:100,perspective:100,zoom:100,idleSpeed:50,commandSpeed:64,fightSpeed:76,idleMinFrames:120,idleMaxFrames:220,commandMinFrames:70,commandMaxFrames:130,fightMinFrames:50,fightMaxFrames:105,battlerInfluence:100,shadowInfluence:100,overscan:24},g.ebdxCamera||{});
  if(!Array.isArray(g.ebdxSceneLibraries))g.ebdxSceneLibraries=[];
  if(!g.ebdxSceneLibraries.some(x=>S(x&&x.id)==="project"))g.ebdxSceneLibraries.unshift({id:"project",name:"Proyecto"});
  if(!Array.isArray(g.ebdxMapMetadata))g.ebdxMapMetadata=[];
  if(!Array.isArray(g.ebdxCustomEnvironments))g.ebdxCustomEnvironments=[];
  return g;
};
App.prototype.bss076MapFileObject=function(){const g=this.bss076EnsureEBDXGlobals(),maps={};A(g.ebdxMapMetadata).forEach(r=>{const id=N(r&&r.mapId);if(id>0)maps[String(id)]={name:S(r.mapName||("Map "+id)),scene:S(r.backdrop||"Auto")};});return {format:"battle-scene-studio-ebdx-map-metadata",version:1,maps};};
App.prototype.bss076ScenesFileObject=function(){const g=this.bss076EnsureEBDXGlobals();return {format:"battle-scene-studio-ebdx-scenes",version:1,libraries:A(g.ebdxSceneLibraries).map(x=>({id:S(x.id),name:S(x.name)})),scenes:A(g.ebdxCustomEnvironments).map(x=>({id:S(x.id),name:S(x.name||x.id),description:S(x.description||""),libraryId:S(x.libraryId||"project"),data:JSON.parse(JSON.stringify(x.data||{}))}))};};
App.prototype.bss076LoadEBDXFiles=async function(){const g=this.bss076EnsureEBDXGlobals();try{if(await this.ctx.fs.projectExists(EBDX_MAP_METADATA_FILE)){const raw=JSON.parse(S(await this.ctx.fs.readProjectFile(EBDX_MAP_METADATA_FILE)||"{}")),maps=raw&&raw.maps;if(maps&&typeof maps==="object"&&!Array.isArray(maps)){g.ebdxMapMetadata=Object.keys(maps).map(k=>{const v=maps[k],id=N(k);return {mapId:id,mapName:S(v&&typeof v==="object"?(v.name||("Map "+id)):("Map "+id)),backdrop:S(v&&typeof v==="object"?(v.scene||v.backdrop||"Auto"):v||"Auto")};}).filter(x=>x.mapId>0);}}}catch(e){this.toast("map_metadata.json inválido: "+S(e&&e.message||e),true);}try{if(await this.ctx.fs.projectExists(EBDX_SCENES_FILE)){const raw=JSON.parse(S(await this.ctx.fs.readProjectFile(EBDX_SCENES_FILE)||"{}"));if(Array.isArray(raw.libraries))g.ebdxSceneLibraries=raw.libraries.map((x,i)=>({id:slug(x&&x.id||x&&x.name||("library_"+i)),name:S(x&&x.name||x&&x.id||("Librería "+(i+1)))}));if(Array.isArray(raw.scenes))g.ebdxCustomEnvironments=raw.scenes.map((x,i)=>({id:slug(x&&x.id||x&&x.name||("scene_"+i)),name:S(x&&x.name||x&&x.id||("Escenario "+(i+1))),description:S(x&&x.description||""),libraryId:S(x&&x.libraryId||"project"),data:x&&x.data&&typeof x.data==="object"?x.data:{}}));this.bss076EnsureEBDXGlobals();}}catch(e){this.toast("scenes.json inválido: "+S(e&&e.message||e),true);}};
App.prototype.bss076WriteEBDXFiles=async function(){await this.ctx.fs.projectMkdir(DATA_DIR);await this.ctx.fs.projectMkdir(EBDX_DATA_DIR);await this.ctx.fs.writeProjectFile(EBDX_MAP_METADATA_FILE,JSON.stringify(this.bss076MapFileObject(),null,2));await this.ctx.fs.writeProjectFile(EBDX_SCENES_FILE,JSON.stringify(this.bss076ScenesFileObject(),null,2));};
const _bss076Load=App.prototype.load;App.prototype.load=async function(){const out=await _bss076Load.call(this);await this.bss076LoadEBDXFiles();return out;};
const _bss076Save=App.prototype.save;App.prototype.save=async function(silent=false){const ok=await _bss076Save.call(this,silent);if(ok){try{await this.bss076WriteEBDXFiles();}catch(e){this.toast("No se pudieron guardar los JSON EBDX: "+S(e&&e.message||e),true);}}return ok;};

App.prototype.bss076CameraPanel=function(){return "";};
App.prototype.bss076MapJSONPanel=function(){return `<details class="bss-panel bss076-map-json"><summary><b>JSON por mapa</b> · ${E(EBDX_MAP_METADATA_FILE)}</summary><p class="bss-note">Este archivo es la metadata EBDX de mapas. La vista visual y este JSON editan el mismo dato.</p><textarea class="bss-textarea" data-ebdx-map-json>${E(JSON.stringify(this.bss076MapFileObject(),null,2))}</textarea><button class="bss-btn primary" data-act="ebdx-map-json-apply">Aplicar JSON</button></details>`;};
const _bss076Global=App.prototype.renderGlobalSettingsModal;App.prototype.renderGlobalSettingsModal=function(){const out=_bss076Global.call(this),card=this.root.querySelector(".bss-global-settings-card");if(card&&!card.querySelector(".bss076-camera")){const w=document.createElement("div");w.innerHTML=this.bss076CameraPanel()+this.bss076MapJSONPanel();while(w.firstElementChild)card.appendChild(w.firstElementChild);const p=card.querySelector("[data-ebdx-camera-preset]");if(p)p.value=S(this.bss076EnsureEBDXGlobals().ebdxCamera.preset||"gen5_plus");}return out;};

App.prototype.bss076SceneLibraries=function(){return this.bss076EnsureEBDXGlobals().ebdxSceneLibraries;};
const _bss076RenderE=App.prototype.renderEBDXStudio;App.prototype.renderEBDXStudio=function(){const out=_bss076RenderE.call(this),main=this.body&&this.body.querySelector(".bss-ebdx-main"),side=this.body&&this.body.querySelector(".bss-ebdx-sidebar"),r=this.ebdxCurrentCustom(),libs=this.bss076SceneLibraries();if(side&&!side.querySelector(".bss076-libraries")){const box=document.createElement("div");box.className="bss076-libraries bss-panel";box.innerHTML=`<h3>Librerías</h3><div class="bss-row"><button class="bss-btn small" data-act="ebdx-library-add">＋ Librería</button><button class="bss-btn small" data-act="ebdx-new-blank">＋ Escenario vacío</button></div>${libs.map(x=>`<label class="bss-mini-field"><span>${E(x.id)}</span><input class="bss-input" data-ebdx-library-name="${E(x.id)}" value="${E(x.name)}"></label>`).join("")}`;side.appendChild(box);}if(main&&r&&!main.querySelector(".bss076-scene-meta")){const box=document.createElement("section");box.className="bss-panel bss076-scene-meta";box.innerHTML=`<h3>Ficha del escenario</h3><div class="bss-mini-grid"><label class="bss-mini-field"><span>Nombre</span><input class="bss-input" data-ebdx-name-076 value="${E(r.name||r.id)}"></label><label class="bss-mini-field"><span>Librería</span><select class="bss-select" data-ebdx-scene-library>${libs.map(x=>`<option value="${E(x.id)}" ${S(r.libraryId||"project")===S(x.id)?"selected":""}>${E(x.name)}</option>`).join("")}</select></label></div><label class="bss-mini-field"><span>Descripción</span><textarea class="bss-textarea" data-ebdx-scene-description>${E(r.description||"")}</textarea></label><div class="bss-row"><button class="bss-btn" data-act="ebdx-duplicate-current">Duplicar escenario</button><button class="bss-btn" data-act="ebdx-tree-add">＋ Árbol</button><button class="bss-btn" data-act="ebdx-grass-add">＋ Hierba</button></div><label class="bss-mini-field"><span>Backdrop custom / ruta Graphics</span><input class="bss-input" data-ebdx-backdrop-custom value="${E(S(r.data&&r.data.backdrop||""))}" placeholder="Graphics/.../mi_fondo.png o Field"></label><details><summary>scenes.json completo</summary><textarea class="bss-textarea" data-ebdx-scenes-json>${E(JSON.stringify(this.bss076ScenesFileObject(),null,2))}</textarea><button class="bss-btn primary" data-act="ebdx-scenes-json-apply">Aplicar scenes.json</button></details>`;main.insertBefore(box,main.children[1]||null);}return out;};

const _bss076Click=App.prototype.onClick;App.prototype.onClick=function(e){const raw=e&&e.target,t=raw&&typeof raw.closest==="function"?raw.closest("button,[data-act]"):raw,act=S(t&&t.dataset&&t.dataset.act);if(act==="ebdx-map-json-apply"){try{const raw=JSON.parse(S(this.root.querySelector("[data-ebdx-map-json]").value||"{}")),maps=raw.maps||{};this.studio.global.ebdxMapMetadata=Object.keys(maps).map(k=>{const v=maps[k],id=N(k);return {mapId:id,mapName:S(v&&typeof v==="object"?(v.name||("Map "+id)):("Map "+id)),backdrop:S(v&&typeof v==="object"?(v.scene||v.backdrop||"Auto"):v||"Auto")};}).filter(x=>x.mapId>0);this.saveSoon();this.renderGlobalSettingsModal();}catch(err){this.toast("JSON de mapas inválido: "+S(err&&err.message||err),true);}return;}if(act==="ebdx-library-add"){const name=prompt("Nombre de la librería EBDX","Nueva librería");if(!name)return;const libs=this.bss076SceneLibraries(),base=slug(name),id=(base||"library")+"_"+Date.now().toString(36);libs.push({id,name:S(name)});this.saveSoon();return this.renderEBDXStudio();}if(act==="ebdx-new-blank"){const rows=this.ebdxCustomRows(),id=this.ebdxUniqueId("scene_custom");rows.push({id,name:"Nuevo escenario",description:"",libraryId:"project",data:{backdrop:"Field"}});this.ebdxStudioSelected=id;this.saveSoon();return this.renderEBDXStudio();}if(act==="ebdx-duplicate-current"){const r=this.ebdxCurrentCustom();if(!r)return;const rows=this.ebdxCustomRows(),id=this.ebdxUniqueId(r.id+"_copy");rows.push({id,name:S(r.name)+" Copy",description:S(r.description||""),libraryId:S(r.libraryId||"project"),data:JSON.parse(JSON.stringify(r.data||{}))});this.ebdxStudioSelected=id;this.saveSoon();return this.renderEBDXStudio();}if(act==="ebdx-tree-add"||act==="ebdx-grass-add"){const r=this.ebdxCurrentCustom();if(!r)return;const key=act==="ebdx-tree-add"?"trees":"tallGrass",bitmap=key==="trees"?"tree":"grass",g=r.data[key]&&typeof r.data[key]==="object"?r.data[key]:{bitmap,elements:0,x:[],y:[],zoom:[],mirror:[],z:[]};g.x=A(g.x);g.y=A(g.y);g.zoom=A(g.zoom);g.mirror=A(g.mirror);g.z=A(g.z);g.x.push(192);g.y.push(key==="trees"?146:180);g.zoom.push(1);g.mirror.push(false);g.z.push(3);g.elements=g.x.length;r.data[key]=g;this.saveSoon();return this.renderEBDXStudio();}if(act==="ebdx-scenes-json-apply"){const r=this.root.querySelector("[data-ebdx-scenes-json]");try{const v=JSON.parse(S(r&&r.value||"{}"));if(Array.isArray(v.libraries))this.studio.global.ebdxSceneLibraries=v.libraries;if(Array.isArray(v.scenes))this.studio.global.ebdxCustomEnvironments=v.scenes;this.bss076EnsureEBDXGlobals();this.saveSoon();return this.renderEBDXStudio();}catch(err){this.toast("scenes.json inválido: "+S(err&&err.message||err),true);return;}}return _bss076Click.call(this,e);};
const _bss076Input=App.prototype.onInput;App.prototype.onInput=function(e){const t=e&&e.target;if(t&&t.dataset){const g=this.bss076EnsureEBDXGlobals(),r=this.ebdxCurrentCustom();if(t.dataset.ebdxCamera!=null){const k=S(t.dataset.ebdxCamera);g.ebdxCamera[k]=N(t.value,g.ebdxCamera[k]);g.ebdxCamera.preset="custom";this.saveSoon();return;}if(t.dataset.ebdxCameraPreset!=null){const p=S(t.value),presets={subtle:{idleStrength:10,commandStrength:18,fightStrength:28,idleSpeed:42,commandSpeed:52,fightSpeed:60},gen5_plus:{idleStrength:28,commandStrength:45,fightStrength:65,idleSpeed:50,commandSpeed:64,fightSpeed:76},ebdx_full:{idleStrength:100,commandStrength:100,fightStrength:100,idleSpeed:55,commandSpeed:72,fightSpeed:86}};if(presets[p])Object.assign(g.ebdxCamera,presets[p]);g.ebdxCamera.preset=p;this.saveSoon();return this.renderGlobalSettingsModal();}if(t.dataset.ebdxLibraryName!=null){const x=this.bss076SceneLibraries().find(q=>S(q.id)===S(t.dataset.ebdxLibraryName));if(x){x.name=S(t.value)||x.name;this.saveSoon();}return;}if(r&&t.dataset.ebdxSceneLibrary!=null){r.libraryId=S(t.value||"project");this.saveSoon();return;}if(r&&t.dataset.ebdxSceneDescription!=null){r.description=S(t.value);this.saveSoon();return;}if(r&&t.dataset.ebdxName076!=null){r.name=S(t.value)||r.name;this.saveSoon();return;}if(r&&t.dataset.ebdxBackdropCustom!=null){r.data=r.data||{};r.data.backdrop=S(t.value)||"Field";this.saveSoon();this.hydrateEBDXStudioPreview();return;}}return _bss076Input.call(this,e);};


// ============================================================================
// BSS v0.7.8 - visual EBDX authoring workflow
// Keeps the existing data model but turns Scene Studio into canvas + inspector.
// ============================================================================
const _bss078RenderEBDXStudio=App.prototype.renderEBDXStudio;
App.prototype.renderEBDXStudio=function(){
  _bss078RenderEBDXStudio.call(this);
  const main=this.body&&this.body.querySelector(".bss-ebdx-main"),preview=main&&main.querySelector("[data-ebdx-preview]");
  if(!main||!preview)return;
  const head=main.querySelector(".bss-ebdx-head");
  const flow=document.createElement("div");flow.className="bss078-ebdx-flow";
  flow.innerHTML=`<button type="button" data-ebdx-guide-step="base"><b>1 · Base</b><small>Horizonte + suelo</small></button><button type="button" data-ebdx-guide-step="environment"><b>2 · Entorno</b><small>Cielo, agua y bioma</small></button><button type="button" data-ebdx-guide-step="depth"><b>3 · Profundidad</b><small>Capas, Z y escala</small></button><button type="button" data-ebdx-guide-step="camera"><b>4 · Cámara</b><small>Prueba el encuadre</small></button>`;
  if(head)head.insertAdjacentElement("afterend",flow);else main.prepend(flow);
  const work=document.createElement("div");work.className="bss078-ebdx-authoring";
  const canvas=document.createElement("section");canvas.className="bss078-ebdx-canvas-column";
  const canvasTitle=document.createElement("div");canvasTitle.className="bss078-ebdx-canvas-title";canvasTitle.innerHTML=`<div><b>Escenario</b><small>Arrastra elementos · Shift = 1 px</small></div><span>384×308 authored · overscan runtime</span>`;
  canvas.appendChild(canvasTitle);canvas.appendChild(preview);
  const hint=document.createElement("div");hint.className="bss078-ebdx-safe-hint";hint.innerHTML=`<b>Área segura de cámara</b><span>El runtime extiende cielo/suelo fuera del lienzo; no necesitas dibujar franjas negras manualmente.</span>`;canvas.appendChild(hint);
  const inspector=document.createElement("section");inspector.className="bss078-ebdx-inspector-column";
  [...main.children].filter(x=>x!==head&&x!==flow&&x!==work&&x.tagName!=="DATALIST").forEach(x=>inspector.appendChild(x));
  work.appendChild(canvas);work.appendChild(inspector);main.appendChild(work);
  if(head)main.insertBefore(head,flow);
};
const _bss078Click=App.prototype.onClick;
App.prototype.onClick=function(e){
  const t=e&&e.target&&typeof e.target.closest==="function"?e.target.closest("[data-ebdx-guide-step]"):null;
  if(t){const step=S(t.dataset.ebdxGuideStep),main=this.body&&this.body.querySelector(".bss-ebdx-main");if(!main)return;
    const targets={base:".bss-ebdx-friendly-grid",environment:".bss-ebdx-friendly-grid",depth:".bss-ebdx-layer",camera:"[data-ebdx-preview]"};
    const el=main.querySelector(targets[step]||"[data-ebdx-preview]");if(el&&el.scrollIntoView)el.scrollIntoView({behavior:"smooth",block:"center"});return;
  }
  return _bss078Click.call(this,e);
};

// ============================================================================
// BSS v0.7.9 - EBDX Studio library UI + Intro Studio + central Config
// Final authority for the EBDX Studio screen. Keeps old readers/writers for
// backwards compatibility, but no longer exposes EBDX configuration in the
// generic BSS settings modal.
// ============================================================================
App.prototype.bss079EnsureEBDXConfig=function(){
  const g=this.bss076EnsureEBDXGlobals();
  g.ebdxIntro=Object.assign({style:"nds_biome",useInVanilla:false,holdFrames:16,moveFrames:28,revealFrames:12,fadeFrames:0,zoomStart:170,dim:72,flash:150,driftX:-7,driftY:3},g.ebdxIntro||{});
  if(!this.ebdxStudioTab)this.ebdxStudioTab="backgrounds";
  if(!this.ebdxStudioLibraryFilter)this.ebdxStudioLibraryFilter="all";
  return g;
};
App.prototype.bss079CameraPresets=function(){return {
  static_gen4:{label:"Estática · Gen 4 / XD",note:"Sin paneos ni zooms automáticos. Conserva el compositor EBDX y sus fondos animados.",values:{idleStrength:0,commandStrength:0,fightStrength:0,panX:0,panY:0,angle:0,perspective:100,zoom:100,idleSpeed:50,commandSpeed:50,fightSpeed:50}},
  subtle:{label:"Sutil",note:"Movimiento discreto para proyectos cercanos a Essentials.",values:{idleStrength:10,commandStrength:18,fightStrength:28,panX:75,panY:75,angle:70,perspective:90,zoom:92,idleSpeed:42,commandSpeed:52,fightSpeed:60}},
  gen5_plus:{label:"Gen 5+",note:"Preset recomendado: cámara visible sin sacrificar lectura de HUD/SOS.",values:{idleStrength:28,commandStrength:45,fightStrength:65,panX:100,panY:100,angle:100,perspective:100,zoom:100,idleSpeed:50,commandSpeed:64,fightSpeed:76}},
  ebdx_full:{label:"EBDX 100%",note:"Recorrido amplio y comportamiento más cercano al EBDX fuente.",values:{idleStrength:100,commandStrength:100,fightStrength:100,panX:100,panY:100,angle:100,perspective:100,zoom:100,idleSpeed:55,commandSpeed:72,fightSpeed:86}},
  custom:{label:"Custom",note:"Todos los parámetros quedan bajo control manual.",values:{}}
};};
App.prototype.bss079CameraConfigHTML=function(){
  const c=this.bss079EnsureEBDXConfig().ebdxCamera,presets=this.bss079CameraPresets();
  const field=(label,key,min,max,step=1,help="")=>`<label class="bss-mini-field"><span>${E(label)}</span><input class="bss-input" type="number" min="${min}" max="${max}" step="${step}" data-bss079-camera="${E(key)}" value="${N(c[key])}">${help?`<small>${E(help)}</small>`:""}</label>`;
  return `<section class="bss079-config-block"><div class="bss079-section-head"><div><b>Cámara EBDX</b><small>El escenario y los battlers comparten el mismo contexto; BAS toma autoridad temporal durante sus animaciones.</small></div></div><div class="bss079-preset-cards">${Object.entries(presets).map(([id,p])=>`<button type="button" class="bss079-mini-card ${S(c.preset)===id?"active":""}" data-bss079-camera-preset="${E(id)}"><b>${E(p.label)}</b><small>${E(p.note)}</small></button>`).join("")}</div><div class="bss-mini-grid bss079-camera-grid">${field("Idle · fuerza %","idleStrength",0,100)}${field("Comandos · fuerza %","commandStrength",0,100)}${field("Fight / Moves · fuerza %","fightStrength",0,100)}${field("Paneo horizontal %","panX",0,200)}${field("Paneo vertical %","panY",0,200)}${field("Rotación / ángulo %","angle",0,200)}${field("Perspectiva / profundidad %","perspective",0,200)}${field("Zoom global %","zoom",0,200)}${field("Velocidad idle %","idleSpeed",1,150)}${field("Velocidad comandos %","commandSpeed",1,150)}${field("Velocidad Fight %","fightSpeed",1,150)}${field("Battlers siguen cámara %","battlerInfluence",0,150)}${field("Sombras siguen cámara %","shadowInfluence",0,150)}${field("Overscan adicional px","overscan",0,256)}${field("Idle · mínimo frames","idleMinFrames",20,1200)}${field("Idle · máximo frames","idleMaxFrames",20,1200)}${field("Comandos · mínimo","commandMinFrames",20,1200)}${field("Comandos · máximo","commandMaxFrames",20,1200)}${field("Fight · mínimo","fightMinFrames",20,1200)}${field("Fight · máximo","fightMaxFrames",20,1200)}</div></section>`;
};
App.prototype.bss079MapConfigHTML=function(){
  const rows=this.bss072MapRows(),maps=this.bss072ProjectMaps(),choices=this.ebdxBackdropChoices(false);
  const mapOptions=maps.map(m=>{const id=N(m.mapId||m.id),name=S(m.name||("Map "+id));return `<option value="${id}">${E(name)} · ${id}</option>`;}).join("");
  const assigned=rows.slice().sort((a,b)=>N(a.mapId)-N(b.mapId)).map(r=>{const id=N(r.mapId),pm=maps.find(m=>N(m.mapId||m.id)===id),name=S(r.mapName||(pm&&pm.name)||("Map "+id)),bg=S(r.backdrop||"Auto");return `<article class="bss079-map-row"><div><b>${E(name)}</b><small>Map ${id}</small></div><select class="bss-select" data-bss079-map-scene="${id}">${choices.map(x=>`<option value="${E(x.id)}" ${S(x.id)===bg?"selected":""}>${E(x.label)}</option>`).join("")}</select><button type="button" class="bss-btn danger small" data-bss079-map-remove="${id}">Quitar</button></article>`;}).join("");
  return `<section class="bss079-config-block"><div class="bss079-section-head"><div><b>Fondos por mapa</b><small>Metadata EBDX visual. Se guarda en ${E(EBDX_MAP_METADATA_FILE)}.</small></div></div><div class="bss079-map-assign"><label class="bss-mini-field"><span>Mapa del proyecto</span><select class="bss-select" data-bss079-map-pick><option value="">Seleccionar…</option>${mapOptions}</select></label><label class="bss-mini-field"><span>o Map ID</span><input class="bss-input" type="number" min="1" data-bss079-map-id placeholder="79"></label><label class="bss-mini-field"><span>Escenario</span><select class="bss-select" data-bss079-map-new-scene>${choices.map(x=>`<option value="${E(x.id)}">${E(x.label)}</option>`).join("")}</select></label><button type="button" class="bss-btn primary" data-act="bss079-map-assign">Asignar</button></div><div class="bss079-map-list">${assigned||'<div class="bss-empty">Todavía no hay fondos EBDX asignados a mapas.</div>'}</div><details class="bss-panel bss079-json-details"><summary>JSON de metadata</summary><textarea class="bss-textarea" data-bss079-map-json>${E(JSON.stringify(this.bss076MapFileObject(),null,2))}</textarea><div class="bss-row"><button type="button" class="bss-btn primary" data-act="bss079-map-json-apply">Aplicar JSON</button></div></details></section>`;
};
App.prototype.bss079LibraryConfigHTML=function(){
  const libs=this.bss076SceneLibraries();
  return `<section class="bss079-config-block"><div class="bss079-section-head"><div><b>Librerías de fondos</b><small>Organiza escenarios como las librerías de Battles. Los presets EBDX originales permanecen en una librería de solo lectura.</small></div><button type="button" class="bss-btn" data-act="ebdx-library-add">＋ Librería</button></div><div class="bss079-library-config">${libs.map(x=>`<label class="bss-mini-field"><span>${E(x.id)}</span><input class="bss-input" data-ebdx-library-name="${E(x.id)}" value="${E(x.name)}"></label>`).join("")}</div><details class="bss-panel bss079-json-details"><summary>scenes.json completo</summary><textarea class="bss-textarea" data-ebdx-scenes-json>${E(JSON.stringify(this.bss076ScenesFileObject(),null,2))}</textarea><div class="bss-row"><button class="bss-btn primary" type="button" data-act="ebdx-scenes-json-apply">Aplicar scenes.json</button></div></details></section>`;
};
App.prototype.bss079IntroStyles=function(){return [
  ["nds_biome","NDS · Bioma","Grass / Water / Cave según el contexto, usando los assets NDS del proyecto."],
  ["focus_zoom","Focus Zoom","Entrada centrada con protagonismo de la cámara EBDX."],
  ["side_sweep","Barrido lateral","El bioma entra lateralmente y revela al Pokémon."],
  ["flash_focus","Flash Focus","Flash breve y reveal de alto contraste."],
  ["dark_reveal","Dark Reveal","Oscurecimiento y aparición progresiva del rival."],
  ["custom","Custom","Misma autoridad EBDX con tiempos, deriva, flash y zoom configurables."]
];};
App.prototype.bss079IntroStudioHTML=function(){
  const i=this.bss079EnsureEBDXConfig().ebdxIntro;
  const num=(label,key,min,max,step=1)=>`<label class="bss-mini-field"><span>${E(label)}</span><input class="bss-input" type="number" min="${min}" max="${max}" step="${step}" data-bss079-intro="${E(key)}" value="${N(i[key])}"></label>`;
  return `<div class="bss079-intro-page"><section class="bss079-config-block"><div class="bss079-section-head"><div><b>Intro Studio</b><small>En modo EBDX esta es la autoridad de la intro salvaje: no se mezcla con la slide Vanilla. También puede habilitarse opcionalmente en Vanilla.</small></div></div><div class="bss079-scene-grid bss079-intro-grid">${this.bss079IntroStyles().map(([id,name,desc])=>`<button type="button" class="bss079-scene-card ${S(i.style)===id?"active":""}" data-bss079-intro-style="${E(id)}"><div class="bss079-intro-art"><span>${E(id==="nds_biome"?"NDS":id==="focus_zoom"?"◎":id==="side_sweep"?"→":id==="flash_focus"?"✦":id==="dark_reveal"?"◐":"✎")}</span></div><b>${E(name)}</b><small>${E(desc)}</small></button>`).join("")}</div></section><section class="bss079-config-block"><div class="bss079-section-head"><div><b>Parámetros de la intro</b><small>Todos están alejados del sistema Vanilla; sólo la opción de compatibilidad permite usarlos en batallas Vanilla.</small></div></div><label class="bss-check bss079-wide-check"><input type="checkbox" data-bss079-intro-bool="useInVanilla" ${i.useInVanilla===true?"checked":""}> Permitir esta intro también en combates Vanilla</label><div class="bss-mini-grid">${num("Espera inicial · frames","holdFrames",0,120)}${num("Duración movimiento · frames","moveFrames",2,180)}${num("Zoom inicial %","zoomStart",100,240)}${num("Oscurecimiento","dim",0,255)}${num("Flash","flash",0,255)}${num("Deriva X","driftX",-64,64,0.5)}${num("Deriva Y","driftY",-64,64,0.5)}</div><p class="bss-note">EBDX siempre usa este sistema de intros en salvajes. Vanilla sólo lo usa si activas la casilla anterior.</p></section></div>`;
};
App.prototype.bss079SceneEntries=function(){
  const builtins=Object.keys(BSS079_EBDX_BUILTINS).map(id=>({kind:"builtin",id,name:id,description:this.ebdxFeatureBadges(BSS079_EBDX_BUILTINS[id]).join(" · ")||"Preset EBDX original",libraryId:"ebdx_original",data:BSS079_EBDX_BUILTINS[id]}));
  const custom=this.ebdxCustomRows().map(r=>({kind:"custom",id:S(r.id),name:S(r.name||r.id),description:S(r.description||"Escenario del proyecto"),libraryId:S(r.libraryId||"project"),data:r.data||{},row:r}));
  return builtins.concat(custom);
};
App.prototype.bss079SceneLibrariesForFilter=function(){return [{id:"all",name:"Todos"},{id:"ebdx_original",name:"EBDX Original"}].concat(this.bss076SceneLibraries().map(x=>({id:S(x.id),name:S(x.name)})));};
App.prototype.bss079SceneCardHTML=function(x){
  const selected=x.kind==="custom"?S(this.ebdxStudioSelected)===x.id:(!this.ebdxStudioSelected&&S(this.ebdxStudioBuiltin||"Field")===x.id);
  return `<button type="button" class="bss079-scene-card ${selected?"active":""}" data-bss079-scene-kind="${E(x.kind)}" data-bss079-scene-id="${E(x.id)}"><div class="bss079-card-preview"><canvas width="384" height="308" data-bss079-card-preview="${E(x.kind+":"+x.id)}"></canvas><span>${x.kind==="builtin"?"EBDX":"BSS"}</span></div><b>${E(x.name)}</b><small>${E(x.description)}</small></button>`;
};
App.prototype.bss079SelectedScene=function(){
  const r=this.ebdxCurrentCustom();if(r)return {kind:"custom",id:S(r.id),name:S(r.name||r.id),description:S(r.description||""),libraryId:S(r.libraryId||"project"),data:r.data||{},row:r};
  const id=BSS079_EBDX_BUILTINS[S(this.ebdxStudioBuiltin)]?S(this.ebdxStudioBuiltin):"Field";return {kind:"builtin",id,name:id,description:"Preset original EBDX · solo lectura",libraryId:"ebdx_original",data:BSS079_EBDX_BUILTINS[id]||BSS079_EBDX_BUILTINS.Field,row:null};
};
App.prototype.bss079LayerHTML=function(scene){
  const builtin=scene.kind==="builtin",layers=this.ebdxLayerRows(scene.data||{});
  const rows=layers.map(([key,x])=>`<article class="bss-ebdx-layer"><header><div><b>${E(key)}</b><small>${E(x.bitmap||"Capa")}</small></div>${builtin?"":`<div class="bss-row"><button class="bss-btn small" type="button" data-ebdx-layer-duplicate="${E(key)}">Duplicar</button><button class="bss-btn danger small" type="button" data-ebdx-layer-remove="${E(key)}">Eliminar</button></div>`}</header><div class="bss-mini-grid"><label class="bss-mini-field"><span>Imagen</span><input class="bss-input" list="bss079-ebdx-elements" data-ebdx-layer="${E(key)}:bitmap" value="${E(x.bitmap||"")}" ${builtin?"disabled":""}></label><label class="bss-mini-field"><span>X</span><input class="bss-input" type="number" data-ebdx-layer="${E(key)}:x" value="${N(x.x,0)}" ${builtin?"disabled":""}></label><label class="bss-mini-field"><span>Y</span><input class="bss-input" type="number" data-ebdx-layer="${E(key)}:y" value="${N(x.y,0)}" ${builtin?"disabled":""}></label><label class="bss-mini-field"><span>Z / profundidad</span><input class="bss-input" type="number" data-ebdx-layer="${E(key)}:z" value="${N(x.z,0)}" ${builtin?"disabled":""}></label><label class="bss-mini-field"><span>Escala</span><input class="bss-input" type="number" step="0.05" min="0.05" max="8" data-ebdx-layer="${E(key)}:zoom" value="${N(x.zoom,1)}" ${builtin?"disabled":""}></label><label class="bss-mini-field"><span>Ángulo °</span><input class="bss-input" type="number" step="1" data-ebdx-layer="${E(key)}:angle" value="${N(x.angle,0)}" ${builtin?"disabled":""}></label><label class="bss-mini-field"><span>Opacidad</span><input class="bss-input" type="number" min="0" max="255" data-ebdx-layer="${E(key)}:opacity" value="${N(x.opacity,255)}" ${builtin?"disabled":""}></label><label class="bss-mini-field"><span>Velocidad</span><input class="bss-input" type="number" step="0.1" data-ebdx-layer="${E(key)}:speed" value="${N(x.speed,1)}" ${builtin?"disabled":""}></label></div><div class="bss-ebdx-layer-flags"><label class="bss-check"><input type="checkbox" data-ebdx-layer="${E(key)}:scrolling" ${x.scrolling===true?"checked":""} ${builtin?"disabled":""}> Loop</label><label class="bss-check"><input type="checkbox" data-ebdx-layer="${E(key)}:vertical" ${x.vertical===true?"checked":""} ${builtin?"disabled":""}> Vertical</label><label class="bss-check"><input type="checkbox" data-ebdx-layer="${E(key)}:flat" ${x.flat===true?"checked":""} ${builtin?"disabled":""}> Plano</label><label class="bss-check"><input type="checkbox" data-ebdx-layer="${E(key)}:colorize" ${x.colorize===true?"checked":""} ${builtin?"disabled":""}> Teñir con escenario</label></div></article>`).join("");
  return rows||'<div class="bss-empty">Este escenario no usa capas img adicionales.</div>';
};
App.prototype.bss079SceneInspectorHTML=function(scene){
  const data=scene.data||{},builtin=scene.kind==="builtin",libs=this.bss076SceneLibraries();
  const toggle=(key,label)=>`<label class="bss-check"><input type="checkbox" data-ebdx-top="${E(key)}" ${data[key]===true?"checked":""} ${builtin?"disabled":""}> ${E(label)}</label>`;
  return `<aside class="bss079-scene-inspector"><div class="bss079-inspector-sticky"><div class="bss079-inspector-title"><div>${builtin?`<b>${E(scene.name)}</b><small>EBDX Original · solo lectura</small>`:`<input class="bss-input" data-ebdx-name-076 value="${E(scene.name)}"><small>${E(scene.id)}</small>`}</div>${builtin?`<button type="button" class="bss-btn primary" data-ebdx-clone="${E(scene.id)}">Duplicar y editar</button>`:`<button type="button" class="bss-btn danger small" data-act="ebdx-delete">Eliminar</button>`}</div><div class="bss-ebdx-preview bss079-main-preview" data-ebdx-preview></div></div>${builtin?"":`<section class="bss-panel"><div class="bss-mini-grid"><label class="bss-mini-field"><span>Librería</span><select class="bss-select" data-ebdx-scene-library>${libs.map(x=>`<option value="${E(x.id)}" ${scene.libraryId===S(x.id)?"selected":""}>${E(x.name)}</option>`).join("")}</select></label><label class="bss-mini-field"><span>Grid de arrastre</span><select class="bss-select" data-ebdx-grid>${[1,2,4,8,16,32].map(n=>`<option value="${n}" ${N(this.bss072SceneGrid,8)===n?"selected":""}>${n}px</option>`).join("")}</select></label></div><label class="bss-mini-field"><span>Descripción</span><textarea class="bss-textarea" data-ebdx-scene-description>${E(scene.description)}</textarea></label><div class="bss-row"><button class="bss-btn" type="button" data-act="ebdx-duplicate-current">Duplicar fondo</button><button class="bss-btn" type="button" data-act="ebdx-tree-add">＋ Árbol</button><button class="bss-btn" type="button" data-act="ebdx-grass-add">＋ Hierba</button></div></section>`}<section class="bss-panel"><h3>Base y entorno</h3><div class="bss-mini-grid"><label class="bss-mini-field"><span>Battleback base</span><select class="bss-select" data-ebdx-field="backdrop" ${builtin?"disabled":""}>${(S(data.backdrop||"").includes("/")?[S(data.backdrop)]:[]).concat(BSS079_EBDX_BGS).map(x=>`<option value="${E(x)}" ${S(data.backdrop||"Field")===x?"selected":""}>${E(x.includes("/")?"Custom · "+x.split("/").slice(-2).join("/"):x)}</option>`).join("")}</select></label><label class="bss-mini-field"><span>Suelo adicional</span><select class="bss-select" data-ebdx-field="base" ${builtin?"disabled":""}>${BSS079_EBDX_BASES.map(x=>`<option value="${E(x)}" ${S(data.base||"")===x?"selected":""}>${E(x||"Ninguno")}</option>`).join("")}</select></label></div><div class="bss079-toggle-grid">${toggle("sky","Cielo")}${toggle("water","Agua")}${toggle("lightsA","Luces A")}${toggle("lightsB","Luces B")}${toggle("lightsC","Luces C")}${toggle("spinLights","Luces giratorias")}</div></section><details class="bss-panel" open><summary><b>Capas visuales (${this.ebdxLayerRows(data).length})</b></summary>${builtin?"":'<div class="bss-row"><button class="bss-btn" type="button" data-act="ebdx-layer-add">＋ Añadir capa</button></div>'}${this.bss079LayerHTML(scene)}</details><details class="bss-panel"><summary>JSON del fondo</summary><textarea class="bss-textarea bss-ebdx-json" data-ebdx-json ${builtin?"readonly":""}>${E(JSON.stringify(data,null,2))}</textarea>${builtin?"":'<button class="bss-btn primary" type="button" data-act="ebdx-json-apply">Aplicar JSON</button>'}</details></aside>`;
};
App.prototype.bss079BackgroundsHTML=function(){
  const filter=S(this.ebdxStudioLibraryFilter||"all"),libs=this.bss079SceneLibrariesForFilter(),all=this.bss079SceneEntries(),visible=filter==="all"?all:all.filter(x=>x.libraryId===filter),scene=this.bss079SelectedScene();
  return `<div class="bss079-background-page"><div class="bss079-quick-guide"><b>Flujo rápido</b><span>1. Elige un fondo → 2. Duplica si es EBDX Original → 3. Edita Base/Entorno → 4. Añade capas y arrástralas en la preview → 5. Asigna el fondo a mapas desde Config.</span></div><div class="bss079-background-toolbar"><div class="bss079-library-chips">${libs.map(x=>`<button type="button" class="bss079-chip ${filter===x.id?"active":""}" data-bss079-library="${E(x.id)}">${E(x.name)}</button>`).join("")}</div><div class="bss-row"><button class="bss-btn" type="button" data-act="ebdx-new-blank">＋ Fondo vacío</button><button class="bss-btn" type="button" data-act="ebdx-library-add">＋ Librería</button></div></div><div class="bss079-scene-workspace"><section class="bss079-scene-browser"><div class="bss079-scene-grid-scroll"><div class="bss079-scene-grid">${visible.map(x=>this.bss079SceneCardHTML(x)).join("")||'<div class="bss-empty">Esta librería está vacía.</div>'}</div></div></section>${this.bss079SceneInspectorHTML(scene)}</div><datalist id="bss079-ebdx-elements">${BSS079_EBDX_ELEMENTS.map(x=>`<option value="${E(x)}"></option>`).join("")}</datalist></div>`;
};
App.prototype.bss079ConfigHTML=function(){
  const g=this.bss079EnsureEBDXConfig(),els=g.ebdxElements||{};
  return `<div class="bss079-config-page"><section class="bss079-config-block"><div class="bss079-section-head"><div><b>Motor EBDX</b><small>Todo lo relacionado al modo EBDX vive aquí.</small></div></div><div class="bss-mini-grid"><label class="bss-mini-field"><span>Motor global</span><select class="bss-select" data-studio-global="battleSceneEngine"><option value="blueprint" ${S(g.battleSceneEngine||"blueprint")==="blueprint"?"selected":""}>Por combate / Blueprint</option><option value="ebdx" ${S(g.battleSceneEngine)==="ebdx"?"selected":""}>EBDX · todos</option><option value="vanilla" ${S(g.battleSceneEngine)==="vanilla"?"selected":""}>Vanilla · todos</option></select></label><label class="bss-mini-field"><span>Fondo EBDX global</span><select class="bss-select" data-studio-global="ebdxBackdrop">${this.ebdxBackdropChoices(false).map(x=>`<option value="${E(x.id)}" ${S(g.ebdxBackdrop||"Auto")===x.id?"selected":""}>${E(x.label)}</option>`).join("")}</select></label></div><div class="bss079-toggle-grid">${["sky","clouds","trees","grass","water","lights","decor","particles"].map(k=>`<label class="bss-check"><input type="checkbox" data-studio-ebdx-element="${k}" ${els[k]!==false?"checked":""}> ${E({sky:"Cielo",clouds:"Nubes",trees:"Árboles",grass:"Hierba",water:"Agua",lights:"Luces",decor:"Decoración",particles:"Partículas"}[k])}</label>`).join("")}</div></section>${this.bss079MapConfigHTML()}${this.bss079LibraryConfigHTML()}</div>`;
};
const _bss0799RenderGlobal=App.prototype.renderGlobalSettingsModal;
App.prototype.renderGlobalSettingsModal=function(){
  const out=_bss0799RenderGlobal.call(this),card=this.root&&this.root.querySelector(".bss-global-settings-card");if(!card)return out;
  card.querySelectorAll(".bss-mapmeta-section,.bss076-map-json,.bss076-camera").forEach(x=>x.remove());
  const camera=[...card.querySelectorAll(".bss-global-settings-section")].find(x=>x.querySelector("h3")&&x.querySelector("h3").textContent.includes("Cámara / fondos"));
  if(camera){camera.querySelectorAll(".bss-field,.bss-mini-grid,.bss-note").forEach(x=>x.remove());let b=camera.querySelector('[data-act="open-ebdx-studio"]');if(!b){b=document.createElement("button");b.className="bss-btn primary";b.dataset.act="open-ebdx-studio";b.textContent="Abrir EBDX Studio";camera.appendChild(b);}const p=document.createElement("p");p.className="bss-note";p.textContent="Fondos, cámara, metadata por mapa, librerías e intros se administran en EBDX Studio → Config / Intros.";camera.insertBefore(p,b);}
  return out;
};
App.prototype.renderEBDXStudio=function(){
  this.bss079EnsureEBDXConfig();
  const tab=S(this.ebdxStudioTab||"backgrounds");
  this.body.innerHTML=`<section class="bss079-ebdx-studio"><header class="bss-libhead bss079-ebdx-header"><button class="bss-btn" type="button" data-nav="library">← Battles</button><div class="bss-aura-title"><b>EBDX Studio</b><small>Fondos, intros y configuración EBDX en un único editor visual.</small></div><div class="bss-spacer"></div></header><nav class="bss079-ebdx-tabs"><button type="button" class="${tab==="backgrounds"?"active":""}" data-bss079-tab="backgrounds">Fondos</button><button type="button" class="${tab==="intros"?"active":""}" data-bss079-tab="intros">Intros</button><button type="button" class="${tab==="config"?"active":""}" data-bss079-tab="config">Config</button></nav><main class="bss079-ebdx-content">${tab==="intros"?this.bss079IntroStudioHTML():tab==="config"?this.bss079ConfigHTML():this.bss079BackgroundsHTML()}</main></section>`;
  if(tab==="backgrounds"){this.hydrateEBDXStudioPreview();this.bss079HydrateSceneCards();requestAnimationFrame(()=>{const sc=this.body&&this.body.querySelector(".bss079-scene-grid-scroll");if(sc)sc.scrollTop=Math.max(0,N(this.ebdxStudioGridScroll,0));});}
};
App.prototype.bss079HydrateSceneCards=async function(){
  if(!this.body)return;const entries=this.bss079SceneEntries(),byKey=new Map(entries.map(x=>[x.kind+":"+x.id,x]));
  for(const canvas of [...this.body.querySelectorAll("[data-bss079-card-preview]")]){const row=byKey.get(S(canvas.dataset.bss079CardPreview));if(!row)continue;try{await this.bss083EBDXComposite(canvas,{kind:"builtin",id:row.id,name:row.name,data:JSON.parse(JSON.stringify(row.data||{})),row:null});}catch(_){}}
};
const _bss0799Click=App.prototype.onClick;
App.prototype.onClick=function(e){
  if(this.screen==="ebdx"){const _sc=this.body&&this.body.querySelector(".bss079-scene-grid-scroll");if(_sc)this.ebdxStudioGridScroll=_sc.scrollTop;}
  const raw=e&&e.target,t=raw&&typeof raw.closest==="function"?raw.closest("button,[data-bss079-tab],[data-bss079-library],[data-bss079-scene-id],[data-bss079-camera-preset],[data-bss079-intro-style],[data-bss079-map-remove]"):raw;
  if(t&&t.dataset){
    if(t.dataset.bss079Tab!=null){this.ebdxStudioTab=S(t.dataset.bss079Tab)||"backgrounds";this.renderEBDXStudio();return;}
    if(t.dataset.bss079Library!=null){const sc=this.body&&this.body.querySelector(".bss079-scene-grid-scroll");if(sc)this.ebdxStudioGridScroll=sc.scrollTop;this.ebdxStudioLibraryFilter=S(t.dataset.bss079Library)||"all";this.renderEBDXStudio();return;}
    if(t.dataset.bss079SceneId!=null){const sc=this.body&&this.body.querySelector(".bss079-scene-grid-scroll");if(sc)this.ebdxStudioGridScroll=sc.scrollTop;const id=S(t.dataset.bss079SceneId),kind=S(t.dataset.bss079SceneKind);if(kind==="custom"){this.ebdxStudioSelected=id;}else{this.ebdxStudioSelected="";this.ebdxStudioBuiltin=id||"Field";}this.renderEBDXStudio();return;}
    if(t.dataset.bss079CameraPreset!=null){const g=this.bss079EnsureEBDXConfig(),id=S(t.dataset.bss079CameraPreset),p=this.bss079CameraPresets()[id];if(p){Object.assign(g.ebdxCamera,p.values);g.ebdxCamera.preset=id;this.saveSoon();this.renderEBDXStudio();}return;}
    if(t.dataset.bss079IntroStyle!=null){const g=this.bss079EnsureEBDXConfig();g.ebdxIntro.style=S(t.dataset.bss079IntroStyle)||"nds_biome";this.saveSoon();this.renderEBDXStudio();return;}
    if(t.dataset.bss079MapRemove!=null){const id=N(t.dataset.bss079MapRemove),rows=this.bss072MapRows(),idx=rows.findIndex(r=>N(r.mapId)===id);if(idx>=0)rows.splice(idx,1);this.saveSoon();this.renderEBDXStudio();return;}
    const act=S(t.dataset.act);
    if(act==="bss079-map-assign"){const pick=this.body.querySelector("[data-bss079-map-pick]"),manual=this.body.querySelector("[data-bss079-map-id]"),sceneEl=this.body.querySelector("[data-bss079-map-new-scene]"),id=N((manual&&manual.value)|| (pick&&pick.value),0);if(id<=0){this.toast("Selecciona un mapa o escribe un Map ID válido.",true);return;}const maps=this.bss072ProjectMaps(),pm=maps.find(m=>N(m.mapId||m.id)===id),rows=this.bss072MapRows(),existing=rows.find(r=>N(r.mapId)===id),value={mapId:id,mapName:S(pm&&pm.name||("Map "+id)),backdrop:S(sceneEl&&sceneEl.value||"Auto")};if(existing)Object.assign(existing,value);else rows.push(value);this.saveSoon();this.renderEBDXStudio();return;}
    if(act==="bss079-map-json-apply"){const ta=this.body.querySelector("[data-bss079-map-json]");try{const raw=JSON.parse(S(ta&&ta.value||"{}")),maps=raw.maps||{};this.studio.global.ebdxMapMetadata=Object.keys(maps).map(k=>{const v=maps[k],id=N(k);return {mapId:id,mapName:S(v&&typeof v==="object"?(v.name||("Map "+id)):("Map "+id)),backdrop:S(v&&typeof v==="object"?(v.scene||v.backdrop||"Auto"):v||"Auto")};}).filter(x=>x.mapId>0);this.saveSoon();this.renderEBDXStudio();}catch(err){this.toast("JSON de mapas inválido: "+S(err&&err.message||err),true);}return;}
  }
  return _bss0799Click.call(this,e);
};
const _bss0799Input=App.prototype.onInput;
App.prototype.onInput=function(e){
  const t=e&&e.target;if(t&&t.dataset){const g=this.bss079EnsureEBDXConfig();
    if(t.dataset.bss079Camera!=null){const k=S(t.dataset.bss079Camera);g.ebdxCamera[k]=N(t.value,g.ebdxCamera[k]);g.ebdxCamera.preset="custom";this.saveSoon();return;}
    if(t.dataset.bss079Intro!=null){const k=S(t.dataset.bss079Intro);g.ebdxIntro[k]=N(t.value,g.ebdxIntro[k]);this.saveSoon();return;}
    if(t.dataset.bss079IntroBool!=null){g.ebdxIntro[S(t.dataset.bss079IntroBool)]=!!t.checked;this.saveSoon();return;}
    if(t.dataset.bss079MapScene!=null){const id=N(t.dataset.bss079MapScene),r=this.bss072MapRows().find(x=>N(x.mapId)===id);if(r){r.backdrop=S(t.value||"Auto");this.saveSoon();}return;}
    if(t.dataset.ebdxLayer!=null){const r=this.ebdxCurrentCustom();if(r){const parts=S(t.dataset.ebdxLayer).split(":"),key=parts.shift(),field=parts.join(":"),x=r.data&&r.data[key];if(x&&typeof x==="object"){let v=t.type==="checkbox"?!!t.checked:(t.type==="number"?N(t.value):S(t.value));if(["x","y","z","zoom","opacity","speed","direction","angle"].includes(field))v=N(v,field==="zoom"||field==="speed"||field==="direction"?1:0);if(t.type==="checkbox"&&!v)delete x[field];else x[field]=v;this.saveSoon();this.hydrateEBDXStudioPreview();return;}}}
  }
  return _bss0799Input.call(this,e);
};


// ============================================================================
// BSS v0.8.3 - Intro Studio context resolver
// ============================================================================
const _bss080EnsureIntro=App.prototype.bss079EnsureEBDXConfig;
App.prototype.bss079EnsureEBDXConfig=function(){
  const g=_bss080EnsureIntro.call(this),i=g.ebdxIntro||(g.ebdxIntro={});
  if(!["auto","encounter","map","ebdx"].includes(S(i.biomeSource)))i.biomeSource="auto";
  i.encounterMappings=Object.assign({Land:"Grass",Cave:"Cave",Water:"Water",Fishing:"Water"},i.encounterMappings||{});
  if(!i.mapOverrides||typeof i.mapOverrides!=="object"||Array.isArray(i.mapOverrides))i.mapOverrides={};
  return g;
};
const _bss080IntroHTML=App.prototype.bss079IntroStudioHTML;
App.prototype.bss079IntroStudioHTML=function(){
  const base=_bss080IntroHTML.call(this),i=this.bss079EnsureEBDXConfig().ebdxIntro;
  const kind=(key)=>`<select class="bss-select" data-bss080-intro-map="${E(key)}"><option value="Grass" ${S(i.encounterMappings[key])==="Grass"?"selected":""}>Grass</option><option value="Water" ${S(i.encounterMappings[key])==="Water"?"selected":""}>Water</option><option value="Cave" ${S(i.encounterMappings[key])==="Cave"?"selected":""}>Cave</option></select>`;
  const panel=`<section class="bss079-config-block bss080-intro-resolver"><div class="bss079-section-head"><div><b>Resolver Grass / Water / Cave</b><small>Usa el tipo real de encuentro de Essentials 21.1, Map ID o el escenario EBDX. Evening/Night se resuelven sobre el bioma elegido.</small></div></div><label class="bss-mini-field"><span>Fuente</span><select class="bss-select" data-bss080-intro-source><option value="auto" ${S(i.biomeSource)==="auto"?"selected":""}>Automático</option><option value="encounter" ${S(i.biomeSource)==="encounter"?"selected":""}>Tipo real de encounter</option><option value="map" ${S(i.biomeSource)==="map"?"selected":""}>Map ID</option><option value="ebdx" ${S(i.biomeSource)==="ebdx"?"selected":""}>Escenario EBDX</option></select></label><div class="bss-mini-grid"><label class="bss-mini-field"><span>Land</span>${kind("Land")}</label><label class="bss-mini-field"><span>Cave</span>${kind("Cave")}</label><label class="bss-mini-field"><span>Water</span>${kind("Water")}</label><label class="bss-mini-field"><span>Fishing</span>${kind("Fishing")}</label></div><details class="bss-panel bss079-json-details"><summary>Overrides JSON por Map ID</summary><textarea class="bss-textarea" data-bss080-intro-map-json>${E(JSON.stringify(i.mapOverrides||{},null,2))}</textarea><div class="bss-row"><button type="button" class="bss-btn primary" data-act="bss080-intro-map-json-apply">Aplicar overrides</button></div><p class="bss-note">Ejemplo: {"79":"Cave","104":"Water"}</p></details></section>`;
  return base.replace(/<\/div>\s*$/,panel+'</div>');
};
const _bss080OnInput=App.prototype.onInput;
App.prototype.onInput=function(e){
  const t=e&&e.target;if(t&&t.dataset){const i=this.bss079EnsureEBDXConfig().ebdxIntro;
    if(t.dataset.bss080IntroSource!=null){i.biomeSource=S(t.value)||"auto";this.saveSoon();return;}
    if(t.dataset.bss080IntroMap!=null){i.encounterMappings[S(t.dataset.bss080IntroMap)]=S(t.value)||"Grass";this.saveSoon();return;}
  }
  return _bss080OnInput.call(this,e);
};
const _bss080OnClick=App.prototype.onClick;
App.prototype.onClick=function(e){
  const raw=e&&e.target,t=raw&&typeof raw.closest==="function"?raw.closest("button,[data-act]"):raw;
  if(t&&S(t.dataset&&t.dataset.act)==="bss080-intro-map-json-apply"){
    const ta=this.body&&this.body.querySelector("[data-bss080-intro-map-json]");
    try{const v=JSON.parse(S(ta&&ta.value||"{}"));if(!v||typeof v!=="object"||Array.isArray(v))throw new Error("debe ser un objeto JSON");const clean={};Object.keys(v).forEach(k=>{const id=N(k,0),kind=S(v[k]);if(id>0&&["Grass","Water","Cave"].includes(kind))clean[String(id)]=kind;});this.bss079EnsureEBDXConfig().ebdxIntro.mapOverrides=clean;this.saveSoon();this.renderEBDXStudio();}catch(err){this.toast("Overrides de intro inválidos: "+S(err&&err.message||err),true);}return;
  }
  return _bss080OnClick.call(this,e);
};

//=============================================================================
// BSS v0.8.5 · stable EBDX camera/parallax/Enhanced UI authority.
//=============================================================================
const _bss084Ensure=App.prototype.bss079EnsureEBDXConfig;
App.prototype.bss079EnsureEBDXConfig=function(){
  const g=_bss084Ensure.call(this),c=g.ebdxCamera||(g.ebdxCamera={}),i=g.ebdxIntro||(g.ebdxIntro={});
  const defs={command:{enabled:false,mode:"hold",frames:0},fight:{enabled:false,mode:"hold",frames:0},move:{enabled:false,mode:"hold",frames:0},spread:{enabled:false,mode:"hold",frames:0},common:{enabled:false,mode:"hold",frames:0},sendout:{enabled:false,mode:"hold",frames:0},recall:{enabled:false,mode:"hold",frames:0},sos:{enabled:false,mode:"hold",frames:0},capture:{enabled:false,mode:"hold",frames:0},faint:{enabled:false,mode:"hold",frames:0},turn_end:{enabled:false,mode:"neutral",frames:10},idle:{enabled:true,mode:"drift",frames:0},bas:{enabled:true,mode:"authored",frames:0}};
  c.contexts=Object.assign({},defs,c.contexts||{});Object.keys(defs).forEach(k=>{c.contexts[k]=Object.assign({},defs[k],c.contexts[k]||{});});
  // Migrate only the exact old defaults; user-authored values remain untouched.
  if(N(i.holdFrames,8)===8&&N(i.moveFrames,12)===12){i.holdFrames=16;i.moveFrames=28;}
  if(N(i.zoomStart,145)===145)i.zoomStart=185;
  if(i.revealFrames==null||N(i.revealFrames,10)===10)i.revealFrames=12;
  if(i.fadeFrames==null||N(i.fadeFrames,14)===14)i.fadeFrames=0;
  return g;
};

const _bss084CameraHTML=App.prototype.bss079CameraConfigHTML;
App.prototype.bss079CameraConfigHTML=function(){
  let html=_bss084CameraHTML.call(this),c=this.bss079EnsureEBDXConfig().ebdxCamera,ctx=c.contexts||{};
  const labels={command:"Menú de comandos",fight:"Menú Luchar",move:"Movimiento 1 objetivo",spread:"Movimiento multiobjetivo",common:"Animación común / estado",sendout:"Sendout",recall:"Recall / cambio",sos:"Entrada SOS",capture:"Captura",faint:"Debilitado",turn_end:"Fin de turno",idle:"Idle",bas:"BAS"};
  const modes=[["hold","Mantener plano"],["focus","Enfocar actor/objetivo"],["wide","Plano abierto"],["neutral","Plano neutral"],["player","Jugador"],["enemy","Rival"],["impact","Impacto"],["drift","Deriva idle"],["authored","Cámara authored/BAS"]];
  const rows=Object.keys(labels).map(k=>{const r=ctx[k]||{};return `<article class="bss084-camera-context"><label class="bss-check"><input type="checkbox" data-bss084-camera-context="${E(k)}:enabled" ${r.enabled===true?"checked":""}> <b>${E(labels[k])}</b></label><select class="bss-select" data-bss084-camera-context="${E(k)}:mode">${modes.map(x=>`<option value="${x[0]}" ${S(r.mode)===x[0]?"selected":""}>${E(x[1])}</option>`).join("")}</select><label class="bss-mini-field"><span>Transición (frames)</span><input class="bss-input" type="number" min="0" max="60" data-bss084-camera-context="${E(k)}:frames" value="${N(r.frames,0)}"></label></article>`;}).join("");
  const block=`<div class="bss084-camera-contexts"><div class="bss079-section-head"><div><b>Comportamiento por contexto</b><small>Preset fuente EBDX: comandos, Vanilla/PBS, SOS, captura y faint mantienen el plano. Sólo BAS/authored y el idle tardío mueven cámara salvo que actives un contexto.</small></div></div>${rows}</div>`;
  const at=html.lastIndexOf("</section>");return at>=0?html.slice(0,at)+block+html.slice(at):html+block;
};

const _bss084IntroHTML=App.prototype.bss079IntroStudioHTML;
App.prototype.bss079IntroStudioHTML=function(){
  let html=_bss084IntroHTML.call(this),i=this.bss079EnsureEBDXConfig().ebdxIntro;
  const block=`<section class="bss079-config-block"><div class="bss079-section-head"><div><b>Timing del reveal standalone</b><small>Wild NDS usa el mundo EBDX ya construido desde el primer frame; Fade 0 evita cualquier placa negra.</small></div></div><div class="bss-mini-grid"><label class="bss-mini-field"><span>Reveal Pokémon</span><input class="bss-input" type="number" min="4" max="120" data-bss079-intro="revealFrames" value="${N(i.revealFrames,12)}"></label><label class="bss-mini-field"><span>Fade inicial</span><input class="bss-input" type="number" min="0" max="120" data-bss079-intro="fadeFrames" value="${N(i.fadeFrames,0)}"></label></div></section>`;
  const at=html.lastIndexOf("</div>");return at>=0?html.slice(0,at)+block+html.slice(at):html+block;
};

const BSS_DBK_TRIGGER_EVENTS = [
  ["BeforeMove_foe", "Antes de atacar con cualquier movimiento (Boss)"],
  ["BeforeDamagingMove_foe", "Antes de usar un ataque con daño (Boss)"],
  ["BeforePhysicalMove_foe", "Antes de usar un ataque físico (Boss)"],
  ["BeforeSpecialMove_foe", "Antes de usar un ataque especial (Boss)"],
  ["BeforeStatusMove_foe", "Antes de usar un movimiento de estado (Boss)"],
  ["AfterMove_foe", "Tras ejecutar un movimiento (Boss)"],
  ["TurnStart_foe", "Inicio de turno propio del Boss"],
  ["RoundStartCommand_foe", "Inicio de turno · comandos rival"],
  ["RoundStartAttack_foe", "Inicio de turno · fase de ataque"],
  ["TargetHPHalf_foe", "Vida del Boss cae al 50% o menos"],
  ["TargetHPLow_foe", "Vida crítica del Boss (25% o menos)"],
  ["BeforeLastSwitchIn_foe", "Antes de sacar al último Pokémon (Trainer)"],
  ["AfterLastSendOut_foe", "Tras enviar al último Pokémon (Trainer)"],
  ["BattlerFainted_foe", "Cuando el Boss es derrotado"],
  ["BattleEndWin", "Victoria del jugador"],
  ["BattleEndLoss", "Derrota del jugador"],
  ["TurnEnd_foe", "Al terminar cada turno"]
];

const _bss084BossHTML=App.prototype.bossHTML;
App.prototype.bossHTML=function(b){
  let html=_bss084BossHTML.call(this,b),boss=b.boss||(b.boss={});
  if(!boss.expMode)boss.expMode="normal";if(!boss.expSummaryMessage)boss.expSummaryMessage="¡{1} ganó un total de {2} Puntos de Experiencia!";
  if(boss.aiSkill==null)boss.aiSkill=100;
  if(!Array.isArray(boss.midbattleTriggers))boss.midbattleTriggers=[];
  const triggers=boss.midbattleTriggers;

  const card07=`<details class="bss-optiongroup bss-boss-card"><summary><span>07</span> EXP del Boss / SOS</summary><div class="bss-boss-cardbody"><p class="bss-note">El cálculo de EXP, EVs y level-up no cambia. Controla cómo se resume la experiencia para evitar retrasos innecesarios al finalizar el combate.</p>${this.field("Modo de EXP",`<select class="bss-select" data-bind="boss.expMode"><option value="normal" ${S(boss.expMode)==="normal"?"selected":""}>Normal · mensaje por enemigo</option><option value="single_team" ${S(boss.expMode)==="single_team"||S(boss.expMode)==="global"?"selected":""}>Equipo consolidado · Un único mensaje al final (rápido)</option><option value="participants" ${S(boss.expMode)==="participants"?"selected":""}>Solo participantes · Mensaje solo a Pokémon activos</option><option value="silent" ${S(boss.expMode)==="silent"?"selected":""}>Silencioso · Aplica EXP y niveles sin cuadros de texto</option></select>`)}${this.field("Mensaje consolidado",`<input class="bss-input" data-bind="boss.expSummaryMessage" value="${E(boss.expSummaryMessage)}"><span class="bss-note">{1} = Pokémon participante · {2} = Puntos de EXP acumulados en el combate.</span>`)}</div></details>`;

  const card08=`<details class="bss-optiongroup bss-boss-card"><summary><span>08</span> Nivel de IA del Boss</summary><div class="bss-boss-cardbody"><div class="bss-boss-two">${this.field("Habilidad de IA (0 - 100)",`<input class="bss-input" type="number" min="0" max="100" data-bind="boss.aiSkill" value="${N(boss.aiSkill,100)}">`)}<div class="bss-field"><span>Presets rápidos de IA</span><div class="bss-row" style="gap:4px;flex-wrap:wrap;margin-top:4px;"><button type="button" class="bss-btn small" data-act="boss-ai-preset" data-val="0">0 · Torpe</button><button type="button" class="bss-btn small" data-act="boss-ai-preset" data-val="32">32 · Básico</button><button type="button" class="bss-btn small" data-act="boss-ai-preset" data-val="48">48 · Líder</button><button type="button" class="bss-btn small primary" data-act="boss-ai-preset" data-val="100">100 · Máximo</button></div></div></div><p class="bss-note">Determina la inteligencia y táctica del Boss (cálculo de daño, efectividad, estados, cambios, coberturas y predicción). Recomendado 100 para combates de Boss.</p></div></details>`;

  const card09=`<div class="bss-bossbanner" style="display:flex;align-items:center;justify-content:space-between;padding:12px 14px;background:rgba(99,102,241,0.08);border:1px solid rgba(99,102,241,0.25);border-radius:8px;margin-top:12px;grid-column:1 / -1;"><div><b style="color:#a5b4fc;font-size:13px;">✦ Guionización & Diálogos Cinematográficos</b><div class="bss-note" style="margin:2px 0 0;">Configura diálogos precisos para el Boss, aliados SOS y fases cinemáticas en su panel dedicado.</div></div><button type="button" class="bss-btn primary" data-section="dialogues">Abrir Guionización →</button></div>`;

  const block=card07+card08+card09;
  const at=html.lastIndexOf("</div></div>");return at>=0?html.slice(0,at)+block+html.slice(at):html+block;
};

const BSS_RICH_TRIGGER_EVENTS = [
  ["RoundStartCommand", "Inicio de turno · Fase de comandos"],
  ["RoundStartAttack", "Inicio de turno · Fase de ataque"],
  ["BattleStart", "Al comenzar el combate (Turno 1)"],
  ["TargetHP75", "Vida cae al 75% o menos"],
  ["TargetHPHalf", "Vida cae al 50% o menos (Mitad)"],
  ["TargetHPLow", "Vida cae al 25% o menos (Crítico)"],
  ["BeforeMove", "Antes de usar cualquier movimiento"],
  ["BeforeDamagingMove", "Antes de usar un ataque con daño"],
  ["BeforePhysicalMove", "Antes de usar un ataque físico"],
  ["BeforeSpecialMove", "Antes de usar un ataque especial"],
  ["BeforeStatusMove", "Antes de usar un movimiento de estado"],
  ["AfterMove", "Tras ejecutar un movimiento"],
  ["ShieldBreak", "Al romperse la barrera / escudo (BSS)"],
  ["SOSSuccess", "Al invocar con éxito a un aliado SOS (BSS)"],
  ["BattlerFainted", "Al ser derrotado / debilitado"],
  ["TurnEnd", "Al finalizar cada turno"],
  ["BattleEndWin", "Victoria del jugador"],
  ["BattleEndLoss", "Derrota del jugador"]
];

App.prototype.dialoguesHTML = function(b) {
  b.dialogues = b.dialogues || { enabled: true, midbattleScript: "", triggers: [] };
  const d = b.dialogues;
  d.triggers = Array.isArray(d.triggers) ? d.triggers : [];
  
  if (!d.triggers.length && b.boss && Array.isArray(b.boss.midbattleTriggers) && b.boss.midbattleTriggers.length) {
    d.triggers = b.boss.midbattleTriggers.map(x => ({
      id: x.id || ("dia_" + Date.now().toString(36)),
      event: (x.event || "RoundStartCommand").replace(/_(foe\d*|player\d*|sos\d*)$/i, ""),
      target: (x.target || (x.event && x.event.includes("_sos") ? "sos" : (x.event && x.event.includes("_player") ? "player" : "boss"))),
      speaker: (x.speaker === "narrator" ? "narrator" : "boss"),
      speakerName: x.speakerName || "",
      text: x.text || "",
      style: x.style || "cinematic",
      textboxType: x.textboxType || (x.style === "narrative" ? "default" : "cinematic"),
      showNamebox: x.showNamebox !== false,
      choices: Array.isArray(x.choices) ? x.choices : (typeof x.choices === "string" ? x.choices.split(/[,\n]/).map(s=>s.trim()).filter(Boolean) : []),
      choiceResponses: Array.isArray(x.choiceResponses) ? x.choiceResponses : (typeof x.choiceResponses === "string" ? x.choiceResponses.split("\n").map(s=>s.trim()) : []),
      choiceEffects: Array.isArray(x.choiceEffects) ? x.choiceEffects : [],
      playCry: x.playCry === true,
      screenShake: x.screenShake === true,
      repeat: x.repeat === true,
      turn: N(x.turn, 0)
    }));
  }
  
  this.dialogueFilter = this.dialogueFilter || "all";
  const filter = this.dialogueFilter;
  const allTriggers = d.triggers;
  const bossCount = allTriggers.filter(t => t.target === "boss").length;
  const sosCount = allTriggers.filter(t => t.target === "sos").length;
  const playerCount = allTriggers.filter(t => t.target === "player").length;
  const globalCount = allTriggers.filter(t => t.target === "global").length;
  
  const displayed = allTriggers.map((t, origIdx) => ({ t, origIdx })).filter(({ t }) => {
    if (filter === "all") return true;
    return t.target === filter;
  });
  
  const targetMeta = {
    boss: { label: "Solo Boss / Dominante", color: "#6366f1", bg: "rgba(99,102,241,0.12)", border: "rgba(99,102,241,0.3)" },
    sos: { label: "Solo Ayudante SOS", color: "#a855f7", bg: "rgba(168,85,247,0.12)", border: "rgba(168,85,247,0.3)" },
    player: { label: "Solo Jugador", color: "#10b981", bg: "rgba(16,185,129,0.12)", border: "rgba(16,185,129,0.3)" },
    global: { label: "Global / Combate", color: "#f59e0b", bg: "rgba(245,158,11,0.12)", border: "rgba(245,158,11,0.3)" }
  };
  
  const filterTab = (key, label, count) => `
    <button type="button" class="bss-btn small ${filter === key ? 'primary active' : ''}" data-act="dialogue-filter" data-filter="${key}">
      ${label} <span style="opacity:0.8;font-size:10px;margin-left:2px;">(${count})</span>
    </button>
  `;
  
  return this.panel("Guionización & Diálogos Cinematográficos", `
    <div class="bss-bossbanner" style="margin-bottom:14px;background:linear-gradient(135deg, rgba(99,102,241,0.12), rgba(168,85,247,0.06));border:1px solid rgba(99,102,241,0.25);border-radius:8px;padding:12px 14px;">
      <div style="display:flex;align-items:center;justify-content:space-between;gap:8px;flex-wrap:wrap;">
        <div>
          <b style="color:#c7d2fe;font-size:14px;">✦ Sistema de Guionización y Diálogos BSS</b>
          <div class="bss-note" style="margin:2px 0 0;color:#94a3b8;">Control absoluto de diálogos para Bosses, aliados SOS y combate. Los eventos del Boss no son interferidos por el SOS.</div>
        </div>
        <label class="bss-check compact" style="margin:0;padding:4px 8px;background:rgba(0,0,0,0.25);border-radius:4px;">
          <input type="checkbox" data-dialogue-global="enabled" ${d.enabled !== false ? "checked" : ""}> Activo
        </label>
      </div>
    </div>
    
    <details class="bss-optiongroup" style="margin-bottom:14px;">
      <summary>Opciones globales y plantillas maestras</summary>
      <div class="bss-boss-two" style="margin-top:8px;">
        ${this.field("Script ID global (opcional DBK)", `<input class="bss-input" data-dialogue-global="midbattleScript" value="${E(d.midbattleScript||"")}" placeholder="Ej. BOSS_WILD_EXAMPLE">`)}
        <div class="bss-field">
          <span>Cargar plantilla maestra en disparadores</span>
          <div class="bss-row" style="gap:4px;flex-wrap:wrap;margin-top:4px;">
            <button type="button" class="bss-btn small" data-act="dialogue-tpl-wild">✦ Jefe Dominante</button>
            <button type="button" class="bss-btn small" data-act="dialogue-tpl-trainer">✦ Entrenador / Líder</button>
            <button type="button" class="bss-btn small" data-act="dialogue-tpl-sos">✦ Aliado SOS</button>
            <button type="button" class="bss-btn small danger" data-act="dialogue-clear">Vaciar</button>
          </div>
        </div>
      </div>
    </details>

    <div style="display:flex;align-items:center;justify-content:space-between;gap:8px;margin-bottom:12px;flex-wrap:wrap;padding-bottom:10px;border-bottom:1px solid rgba(255,255,255,0.08);">
      <div class="bss-row" style="gap:4px;flex-wrap:wrap;">
        ${filterTab("all", "Todos", allTriggers.length)}
        ${filterTab("boss", "Solo Boss", bossCount)}
        ${filterTab("sos", "Solo SOS", sosCount)}
        ${filterTab("player", "Solo Jugador", playerCount)}
        ${filterTab("global", "Global", globalCount)}
      </div>
      <button type="button" class="bss-btn primary small" data-act="dialogue-add">＋ Añadir diálogo</button>
    </div>

    <div class="bss-dialogue-list">
      ${displayed.length === 0 ? `
        <div class="bss-note" style="padding:24px;border:1px dashed rgba(255,255,255,0.15);border-radius:8px;text-align:center;">
          No hay diálogos en esta categoría. Pulsa <b>＋ Añadir diálogo</b> o carga una de las <b>plantillas maestras</b> de arriba.
        </div>
      ` : ""}
      ${displayed.map(({ t, origIdx }) => {
        const meta = targetMeta[t.target] || targetMeta.boss;
        return `
          <article class="bss-dialogue-card" style="background:rgba(18,24,38,0.7);border:1px solid ${meta.border};border-left:4px solid ${meta.color};border-radius:8px;padding:12px;margin-bottom:12px;box-shadow:0 2px 8px rgba(0,0,0,0.2);">
            <header style="display:flex;align-items:center;justify-content:space-between;margin-bottom:10px;padding-bottom:8px;border-bottom:1px solid rgba(255,255,255,0.06);">
              <div style="display:flex;align-items:center;gap:8px;">
                <span style="font-weight:700;font-size:12px;color:${meta.color};">#${origIdx + 1}</span>
                <span class="bss-badge" style="background:${meta.bg};color:${meta.color};border:1px solid ${meta.border};padding:2px 8px;border-radius:12px;font-size:11px;font-weight:600;">
                  ${meta.label}
                </span>
                <span style="font-size:12px;color:#94a3b8;font-weight:500;">
                  ${E(BSS_RICH_TRIGGER_EVENTS.find(e => e[0] === t.event)?.[1] || t.event)}
                </span>
              </div>
              <button type="button" class="bss-btn small danger" data-act="dialogue-remove" data-idx="${origIdx}" title="Eliminar este diálogo" style="padding:2px 8px;min-width:24px;">×</button>
            </header>

            <div style="display:grid;grid-template-columns:repeat(auto-fit, minmax(200px, 1fr));gap:10px;margin-bottom:10px;">
              <label class="bss-field">
                <span>Disparador / Evento</span>
                <select class="bss-select" data-dialogue-idx="${origIdx}" data-dialogue-field="event">
                  ${BSS_RICH_TRIGGER_EVENTS.map(([k, lbl]) => `
                    <option value="${k}" ${t.event === k ? "selected" : ""}>${lbl} (${k})</option>
                  `).join("")}
                  ${!BSS_RICH_TRIGGER_EVENTS.some(e => e[0] === t.event) ? `
                    <option value="${E(t.event)}" selected>${E(t.event)} (Personalizado)</option>
                  ` : ""}
                </select>
              </label>

              <label class="bss-field">
                <span>Objetivo estricto (Target)</span>
                <select class="bss-select" data-dialogue-idx="${origIdx}" data-dialogue-field="target">
                  <option value="boss" ${t.target === "boss" ? "selected" : ""}>Solo Boss / Dominante (Ignora al SOS)</option>
                  <option value="sos" ${t.target === "sos" ? "selected" : ""}>Solo Ayudante SOS</option>
                  <option value="player" ${t.target === "player" ? "selected" : ""}>Solo Pokémon del Jugador</option>
                  <option value="global" ${t.target === "global" ? "selected" : ""}>Global / Todo el combate</option>
                </select>
              </label>

              <label class="bss-field">
                <span>Orador (Speaker)</span>
                <select class="bss-select" data-dialogue-idx="${origIdx}" data-dialogue-field="speaker">
                  <option value="boss" ${t.speaker === "boss" ? "selected" : ""}>Boss / Dominante</option>
                  <option value="sos" ${t.speaker === "sos" ? "selected" : ""}>Ayudante SOS</option>
                  <option value="trainer" ${t.speaker === "trainer" ? "selected" : ""}>Rival / Entrenador</option>
                  <option value="narrator" ${t.speaker === "narrator" ? "selected" : ""}>Narrador (sin orador/retrato)</option>
                  <option value="custom" ${t.speaker === "custom" ? "selected" : ""}>Personalizado...</option>
                </select>
              </label>

              <label class="bss-field">
                <span>Tipo de Textbox / Estilo</span>
                <select class="bss-select" data-dialogue-idx="${origIdx}" data-dialogue-field="textboxType">
                  <option value="cinematic" ${t.textboxType === "cinematic" || (t.style !== "narrative" && !t.textboxType) ? "selected" : ""}>Cinemático (barras negras)</option>
                  <option value="default" ${t.textboxType === "default" || (t.style === "narrative" && !t.textboxType) ? "selected" : ""}>Estándar de combate</option>
                  <option value="speech" ${t.textboxType === "speech" ? "selected" : ""}>Bocadillo / Speech</option>
                  <option value="clean" ${t.textboxType === "clean" ? "selected" : ""}>Limpio / Sin marco</option>
                </select>
              </label>
            </div>

            <div style="display:flex;align-items:center;gap:14px;flex-wrap:wrap;margin-bottom:10px;padding:6px 10px;background:rgba(255,255,255,0.02);border:1px solid rgba(255,255,255,0.05);border-radius:6px;">
              <label class="bss-check compact" style="margin:0;">
                <input type="checkbox" data-dialogue-idx="${origIdx}" data-dialogue-field="showNamebox" ${t.showNamebox !== false ? "checked" : ""}>
                🏷️ Mostrar Namebox
              </label>
              <label class="bss-check compact" style="margin:0;">
                <input type="checkbox" data-dialogue-idx="${origIdx}" data-dialogue-field="playCry" ${t.playCry ? "checked" : ""}>
                🔊 Reproducir Cry
              </label>
              <label class="bss-check compact" style="margin:0;">
                <input type="checkbox" data-dialogue-idx="${origIdx}" data-dialogue-field="screenShake" ${t.screenShake ? "checked" : ""}>
                ⚡ Temblor de pantalla
              </label>
              <label class="bss-check compact" style="margin:0;">
                <input type="checkbox" data-dialogue-idx="${origIdx}" data-dialogue-field="repeat" ${t.repeat ? "checked" : ""}>
                🔁 Repetir (no consumir)
              </label>
              <label style="display:flex;align-items:center;gap:6px;margin:0;font-size:11px;color:#94a3b8;">
                <span>Turno:</span>
                <input class="bss-input" type="number" min="0" max="99" data-dialogue-idx="${origIdx}" data-dialogue-field="turn" value="${N(t.turn, 0)}" style="width:50px;padding:2px 4px;height:24px;text-align:center;">
                <small style="opacity:0.7;">(0 = cualquiera)</small>
              </label>
              ${t.speaker === "custom" ? `
                <label style="display:flex;align-items:center;gap:6px;margin:0;font-size:11px;color:#94a3b8;flex:1;">
                  <span>Nombre del orador:</span>
                  <input class="bss-input" data-dialogue-idx="${origIdx}" data-dialogue-field="speakerName" value="${E(t.speakerName || "")}" placeholder="Ej. Red, Profesor, etc." style="flex:1;padding:2px 6px;height:24px;">
                </label>
              ` : ""}
            </div>

            <label class="bss-field" style="margin:0 0 10px 0;">
              <span>Líneas de diálogo / Mensajes</span>
              <textarea class="bss-input" rows="3" data-dialogue-idx="${origIdx}" data-dialogue-field="text" placeholder="Escribe el diálogo... Líneas separadas con Enter se reproducirán secuencialmente. Usa {1} para insertar el nombre del Pokémon." style="width:100%;resize:vertical;font-family:inherit;line-height:1.4;">${E(t.text || "")}</textarea>
            </label>

            <details class="bss-optiongroup" style="padding:6px 10px;background:rgba(99,102,241,0.04);border:1px solid rgba(99,102,241,0.18);border-radius:6px;">
              <summary style="font-size:11px;font-weight:600;color:#c7d2fe;cursor:pointer;">🎮 Opciones interactivas del jugador (Choices) & Consecuencias mecánicas</summary>
              <div style="margin-top:8px;">
                <label class="bss-field" style="margin-bottom:8px;">
                  <span>Opciones de elección (separadas por coma o saltos de línea)</span>
                  <input class="bss-input" data-dialogue-idx="${origIdx}" data-dialogue-field="choices" value="${E(Array.isArray(t.choices) ? t.choices.join(", ") : (t.choices || ""))}" placeholder="Ej. ¡Luchar!, Rendirse, Pedir tregua">
                  <span class="bss-note">Si defines opciones, el juego pausará y mostrará una ventana interactiva de selección. Emitirá disparadores Choice_1, Choice_2, etc.</span>
                </label>
                <label class="bss-field" style="margin-bottom:8px;">
                  <span>Respuestas inline automáticas (1 línea por cada opción)</span>
                  <textarea class="bss-input" rows="2" data-dialogue-idx="${origIdx}" data-dialogue-field="choiceResponses" placeholder="Línea 1: Mensaje si el jugador elige opción 1&#10;Línea 2: Mensaje si el jugador elige opción 2" style="font-size:11px;font-family:inherit;">${E(Array.isArray(t.choiceResponses) ? t.choiceResponses.join("\n") : (t.choiceResponses || ""))}</textarea>
                </label>
                ${Array.isArray(t.choices) && t.choices.length > 0 ? `
                  <div style="margin-top:10px;padding:8px;background:rgba(0,0,0,0.25);border:1px solid rgba(255,255,255,0.08);border-radius:6px;">
                    <div style="font-size:11px;font-weight:600;color:#93c5fd;margin-bottom:8px;">⚖️ Consecuencias mecánicas en combate por opción:</div>
                    <div style="display:flex;flex-direction:column;gap:8px;">
                      ${t.choices.map((choiceText, cIdx) => {
                        const eff = (Array.isArray(t.choiceEffects) && t.choiceEffects[cIdx]) || { type: "none", target: "player", stat: "ATTACK", stages: 1, percent: 25, status: "" };
                        return `
                          <div style="display:flex;align-items:center;gap:8px;flex-wrap:wrap;padding:6px 8px;background:rgba(255,255,255,0.03);border-radius:4px;border-left:3px solid #6366f1;">
                            <span style="font-size:11px;font-weight:700;color:#e2e8f0;min-width:75px;">Opción ${cIdx + 1} ("${E(choiceText)}"):</span>
                            <label style="display:flex;align-items:center;gap:4px;margin:0;font-size:11px;">
                              <span style="color:#94a3b8;">Efecto:</span>
                              <select class="bss-select" style="width:auto;padding:2px 6px;height:24px;font-size:11px;" data-dialogue-choice-idx="${origIdx}" data-choice-idx="${cIdx}" data-choice-field="type">
                                <option value="none" ${eff.type === "none" ? "selected" : ""}>Ninguno</option>
                                <option value="stat_boost" ${eff.type === "stat_boost" ? "selected" : ""}>▲ Subir estadística (+Buff)</option>
                                <option value="stat_drop" ${eff.type === "stat_drop" ? "selected" : ""}>▼ Bajar estadística (-Debuff)</option>
                                <option value="heal" ${eff.type === "heal" ? "selected" : ""}>✚ Curar PS</option>
                                <option value="damage" ${eff.type === "damage" ? "selected" : ""}>⚡ Dañar PS</option>
                                <option value="status" ${eff.type === "status" ? "selected" : ""}>☣ Estado alterado</option>
                              </select>
                            </label>

                            ${eff.type !== "none" ? `
                              <label style="display:flex;align-items:center;gap:4px;margin:0;font-size:11px;">
                                <span style="color:#94a3b8;">Objetivo:</span>
                                <select class="bss-select" style="width:auto;padding:2px 6px;height:24px;font-size:11px;" data-dialogue-choice-idx="${origIdx}" data-choice-idx="${cIdx}" data-choice-field="target">
                                  <option value="player" ${eff.target === "player" ? "selected" : ""}>Jugador</option>
                                  <option value="boss" ${eff.target === "boss" ? "selected" : ""}>Boss / Dominante</option>
                                  <option value="both" ${eff.target === "both" ? "selected" : ""}>Ambos</option>
                                </select>
                              </label>
                            ` : ""}

                            ${(eff.type === "stat_boost" || eff.type === "stat_drop") ? `
                              <label style="display:flex;align-items:center;gap:4px;margin:0;font-size:11px;">
                                <span style="color:#94a3b8;">Stat:</span>
                                <select class="bss-select" style="width:auto;padding:2px 6px;height:24px;font-size:11px;" data-dialogue-choice-idx="${origIdx}" data-choice-idx="${cIdx}" data-choice-field="stat">
                                  <option value="ATTACK" ${eff.stat === "ATTACK" ? "selected" : ""}>Ataque</option>
                                  <option value="DEFENSE" ${eff.stat === "DEFENSE" ? "selected" : ""}>Defensa</option>
                                  <option value="SPECIAL_ATTACK" ${eff.stat === "SPECIAL_ATTACK" ? "selected" : ""}>At. Especial</option>
                                  <option value="SPECIAL_DEFENSE" ${eff.stat === "SPECIAL_DEFENSE" ? "selected" : ""}>Def. Especial</option>
                                  <option value="SPEED" ${eff.stat === "SPEED" ? "selected" : ""}>Velocidad</option>
                                  <option value="ALL" ${eff.stat === "ALL" ? "selected" : ""}>Todas las estadísticas</option>
                                </select>
                              </label>
                              <label style="display:flex;align-items:center;gap:4px;margin:0;font-size:11px;">
                                <span style="color:#94a3b8;">Niveles:</span>
                                <input class="bss-input" type="number" min="1" max="6" value="${eff.stages || 1}" data-dialogue-choice-idx="${origIdx}" data-choice-idx="${cIdx}" data-choice-field="stages" style="width:45px;padding:2px 4px;height:24px;text-align:center;">
                              </label>
                            ` : ""}

                            ${(eff.type === "heal" || eff.type === "damage") ? `
                              <label style="display:flex;align-items:center;gap:4px;margin:0;font-size:11px;">
                                <span style="color:#94a3b8;">Porcentaje:</span>
                                <input class="bss-input" type="number" min="1" max="100" value="${eff.percent || 25}" data-dialogue-choice-idx="${origIdx}" data-choice-idx="${cIdx}" data-choice-field="percent" style="width:50px;padding:2px 4px;height:24px;text-align:center;">
                                <span style="color:#94a3b8;">% PS</span>
                              </label>
                            ` : ""}

                            ${eff.type === "status" ? `
                              <label style="display:flex;align-items:center;gap:4px;margin:0;font-size:11px;">
                                <span style="color:#94a3b8;">Estado:</span>
                                <select class="bss-select" style="width:auto;padding:2px 6px;height:24px;font-size:11px;" data-dialogue-choice-idx="${origIdx}" data-choice-idx="${cIdx}" data-choice-field="status">
                                  <option value="PARALYSIS" ${eff.status === "PARALYSIS" ? "selected" : ""}>Parálisis</option>
                                  <option value="BURN" ${eff.status === "BURN" ? "selected" : ""}>Quemadura</option>
                                  <option value="POISON" ${eff.status === "POISON" ? "selected" : ""}>Veneno</option>
                                  <option value="SLEEP" ${eff.status === "SLEEP" ? "selected" : ""}>Sueño</option>
                                  <option value="FROZEN" ${eff.status === "FROZEN" ? "selected" : ""}>Congelación</option>
                                  <option value="CONFUSION" ${eff.status === "CONFUSION" ? "selected" : ""}>Confusión</option>
                                </select>
                              </label>
                            ` : ""}
                          </div>
                        `;
                      }).join("")}
                    </div>
                  </div>
                ` : ""}
              </div>
            </details>
          </article>
        `;
      }).join("")}
    </div>
  `);
};

// Extensionless runtime paths (Graphics/.../foo) are valid in Essentials but the
// MakerStudio browser needs a concrete file. Try the same path with common image
// extensions so custom/outside-EBDX assets appear in the reconstructed preview.
App.prototype.bss083LoadImage=async function(path){
  path=S(path);if(!path)return null;const has=/\.[a-z0-9]{2,5}$/i.test(path),tries=has?[path]:[path+".png",path+".jpg",path+".jpeg",path+".webp",path];
  for(const p of tries){try{const url=await this.assetUrl({projectPath:p});if(!url)continue;const im=await new Promise(resolve=>{const x=new Image();x.onload=()=>resolve(x);x.onerror=()=>resolve(null);x.src=url;});if(im)return im;}catch(_){}}
  return null;
};

// Every card is reconstructed from scenes.json just like the main preview. There
// is no preview.png/composite.png dependency.
App.prototype.bss079HydrateSceneCards=async function(){
  if(!this.body)return;const entries=this.bss079SceneEntries(),byKey=new Map(entries.map(x=>[x.kind+":"+x.id,x]));
  for(const canvas of [...this.body.querySelectorAll("[data-bss079-card-preview]")]){const row=byKey.get(S(canvas.dataset.bss079CardPreview));if(!row)continue;try{await this.bss083EBDXComposite(canvas,{kind:row.kind,id:row.id,name:row.name,data:JSON.parse(JSON.stringify(row.data||{})),row:row.row||null});}catch(_){}}
};

const _bss084Input=App.prototype.onInput;
App.prototype.onInput=function(e){
  const t=e&&e.target;if(t&&t.dataset&&t.dataset.bss084CameraContext!=null){const g=this.bss079EnsureEBDXConfig(),parts=S(t.dataset.bss084CameraContext).split(":"),key=parts[0],field=parts[1],r=g.ebdxCamera.contexts[key]||(g.ebdxCamera.contexts[key]={});r[field]=field==="enabled"?!!t.checked:(field==="frames"?Math.max(0,Math.min(60,N(t.value,0))):S(t.value));g.ebdxCamera.preset="custom";this.saveSoon();return;}
  return _bss084Input.call(this,e);
};

// ============================================================================
// BSS v0.8.7 - EBDX Studio library + separate Scene Editor, persistent user
// assignments/scenes and camera profiles.
// ============================================================================
const BSS087_BUNDLED_SCENES_FILE="Data/BattleSceneStudio/EBDX/bundled_scenes.json";
const BSS087_CAMERA_PROFILES={
  minimal:{label:"Minimal",note:"Sin movimientos automáticos. BAS conserva su cámara authored.",contexts:{command:{enabled:false,mode:"hold",frames:0,strength:0},fight:{enabled:false,mode:"hold",frames:0,strength:0},move:{enabled:false,mode:"hold",frames:0,strength:0},spread:{enabled:false,mode:"hold",frames:0,strength:0},common:{enabled:false,mode:"hold",frames:0,strength:0},sendout:{enabled:false,mode:"hold",frames:0,strength:0},recall:{enabled:false,mode:"hold",frames:0,strength:0},sos:{enabled:false,mode:"hold",frames:0,strength:0},capture:{enabled:false,mode:"hold",frames:0,strength:0},faint:{enabled:false,mode:"hold",frames:0,strength:0},turn_end:{enabled:false,mode:"hold",frames:0,strength:0},idle:{enabled:false,mode:"hold",frames:0,strength:0},bas:{enabled:true,mode:"authored",frames:0,strength:100}}},
  source_faithful:{label:"EBDX Source Faithful",note:"Plano persistente. Menús, SOS y Vanilla/PBS no fuerzan cortes; sólo deriva idle tardía.",contexts:{command:{enabled:false,mode:"hold",frames:0,strength:0},fight:{enabled:false,mode:"hold",frames:0,strength:0},move:{enabled:false,mode:"hold",frames:0,strength:0},spread:{enabled:false,mode:"hold",frames:0,strength:0},common:{enabled:false,mode:"hold",frames:0,strength:0},sendout:{enabled:false,mode:"hold",frames:0,strength:0},recall:{enabled:false,mode:"hold",frames:0,strength:0},sos:{enabled:false,mode:"hold",frames:0,strength:0},capture:{enabled:false,mode:"hold",frames:0,strength:0},faint:{enabled:false,mode:"hold",frames:0,strength:0},turn_end:{enabled:false,mode:"hold",frames:0,strength:0},idle:{enabled:true,mode:"drift",frames:0,strength:100},bas:{enabled:true,mode:"authored",frames:0,strength:100}}},
  smooth_dynamic:{label:"Dynamic Smooth",note:"Movimientos contextuales pequeños, lentos y continuos; no resetea el plano.",contexts:{command:{enabled:false,mode:"hold",frames:0,strength:0},fight:{enabled:false,mode:"hold",frames:0,strength:0},move:{enabled:true,mode:"focus",frames:32,strength:20},spread:{enabled:true,mode:"wide",frames:36,strength:18},common:{enabled:false,mode:"hold",frames:0,strength:0},sendout:{enabled:false,mode:"hold",frames:0,strength:0},recall:{enabled:false,mode:"hold",frames:0,strength:0},sos:{enabled:true,mode:"wide",frames:38,strength:16},capture:{enabled:true,mode:"enemy",frames:34,strength:18},faint:{enabled:true,mode:"focus",frames:30,strength:14},turn_end:{enabled:false,mode:"hold",frames:0,strength:0},idle:{enabled:true,mode:"drift",frames:0,strength:75},bas:{enabled:true,mode:"authored",frames:0,strength:100}}},
  cinematic:{label:"Cinematic",note:"Más encuadres por acción, pero con smoothstep y sin teleports ni retorno automático a MAIN.",contexts:{command:{enabled:true,mode:"player",frames:34,strength:14},fight:{enabled:true,mode:"player",frames:30,strength:18},move:{enabled:true,mode:"focus",frames:26,strength:34},spread:{enabled:true,mode:"wide",frames:30,strength:28},common:{enabled:false,mode:"hold",frames:0,strength:0},sendout:{enabled:true,mode:"focus",frames:30,strength:22},recall:{enabled:true,mode:"focus",frames:26,strength:18},sos:{enabled:true,mode:"wide",frames:34,strength:28},capture:{enabled:true,mode:"enemy",frames:30,strength:32},faint:{enabled:true,mode:"focus",frames:28,strength:26},turn_end:{enabled:true,mode:"neutral",frames:40,strength:12},idle:{enabled:true,mode:"drift",frames:0,strength:100},bas:{enabled:true,mode:"authored",frames:0,strength:100}}}
};

App.prototype.bss087LoadBundledScenes=async function(){
  this.ebdxBundledScenes={libraries:[],scenes:[]};
  try{
    if(await this.ctx.fs.projectExists(BSS087_BUNDLED_SCENES_FILE)){
      const raw=JSON.parse(S(await this.ctx.fs.readProjectFile(BSS087_BUNDLED_SCENES_FILE)||"{}"));
      this.ebdxBundledScenes={libraries:A(raw.libraries).map(x=>({id:S(x.id),name:S(x.name||x.id)})),scenes:A(raw.scenes).map(x=>({id:S(x.id),name:S(x.name||x.id),description:S(x.description||""),libraryId:S(x.libraryId||"bss_pack"),data:x.data&&typeof x.data==="object"?x.data:{}}))};
    }
  }catch(e){this.ebdxBundledScenes={libraries:[],scenes:[]};this.toast("bundled_scenes.json inválido: "+S(e&&e.message||e),true);}
};
const _bss087LoadFiles=App.prototype.bss076LoadEBDXFiles;
App.prototype.bss076LoadEBDXFiles=async function(){await _bss087LoadFiles.call(this);await this.bss087LoadBundledScenes();};

const _bss087Entries=App.prototype.bss079SceneEntries;
App.prototype.bss079SceneEntries=function(){
  const out=_bss087Entries.call(this),bundle=(this.ebdxBundledScenes&&A(this.ebdxBundledScenes.scenes)||[]).map(r=>({kind:"bundle",id:S(r.id),name:S(r.name||r.id),description:S(r.description||"Escenario BSS incluido"),libraryId:S(r.libraryId||"bss_pack"),data:r.data||{},row:r}));
  return out.concat(bundle);
};
const _bss087Libs=App.prototype.bss079SceneLibrariesForFilter;
App.prototype.bss079SceneLibrariesForFilter=function(){
  const out=_bss087Libs.call(this),seen=new Set(out.map(x=>S(x.id)));
  A(this.ebdxBundledScenes&&this.ebdxBundledScenes.libraries).forEach(x=>{if(!seen.has(S(x.id))){seen.add(S(x.id));out.push({id:S(x.id),name:S(x.name)});}});
  return out;
};
const _bss087Choices=App.prototype.ebdxBackdropChoices;
App.prototype.ebdxBackdropChoices=function(includeInherit){
  const out=_bss087Choices.call(this,includeInherit),seen=new Set(out.map(x=>S(x.id)));
  A(this.ebdxBundledScenes&&this.ebdxBundledScenes.scenes).forEach(r=>{if(!seen.has(S(r.id))){seen.add(S(r.id));out.push({id:S(r.id),label:S(r.name||r.id)+" · BSS"});}});
  return out;
};

App.prototype.bss087SceneByKindId=function(kind,id){return this.bss079SceneEntries().find(x=>S(x.kind)===S(kind)&&S(x.id)===S(id))||null;};
App.prototype.bss087OpenSceneEditor=function(kind,id){
  const row=this.bss087SceneByKindId(kind,id);if(!row)return;
  this.ebdxStudioEditorKind=S(kind);this.ebdxStudioEditorId=S(id);
  if(kind==="custom"){this.ebdxStudioSelected=S(id);this.ebdxStudioBundle="";}
  else if(kind==="builtin"){this.ebdxStudioSelected="";this.ebdxStudioBuiltin=S(id);this.ebdxStudioBundle="";}
  else {this.ebdxStudioSelected="";this.ebdxStudioBundle=S(id);}
  this.screen="ebdx_scene_editor";this.render();
};
App.prototype.bss087CurrentEditorScene=function(){return this.bss087SceneByKindId(this.ebdxStudioEditorKind,this.ebdxStudioEditorId)||this.bss079SceneEntries()[0]||null;};

// EBDX Studio Backgrounds is now a library. Editing lives on its own screen.
App.prototype.bss079BackgroundsHTML=function(){
  const filter=S(this.ebdxStudioLibraryFilter||"all"),libs=this.bss079SceneLibrariesForFilter(),all=this.bss079SceneEntries(),visible=filter==="all"?all:all.filter(x=>x.libraryId===filter);
  return `<div class="bss087-ebdx-library"><div class="bss079-quick-guide"><b>EBDX Studio · Fondos</b><span>La librería sólo gestiona escenarios. Abrir o crear un fondo lleva a un Scene Editor independiente con canvas, capas, assets y propiedades.</span></div><div class="bss079-background-toolbar"><div class="bss079-library-chips">${libs.map(x=>`<button type="button" class="bss079-chip ${filter===x.id?"active":""}" data-bss079-library="${E(x.id)}">${E(x.name)}</button>`).join("")}</div><div class="bss-row"><button class="bss-btn primary" type="button" data-act="ebdx-new-blank">＋ Nuevo escenario</button><button class="bss-btn" type="button" data-act="ebdx-library-add">＋ Librería</button></div></div><section class="bss079-scene-browser bss087-scene-browser-full"><div class="bss079-scene-grid-scroll"><div class="bss079-scene-grid">${visible.map(x=>this.bss079SceneCardHTML(x)).join("")||'<div class="bss-empty">Esta librería está vacía.</div>'}</div></div></section></div>`;
};

App.prototype.bss087SceneAssetRows=function(){return A(this.source&&this.source.allGraphics).filter(x=>L(x&&x.projectPath).includes("graphics/battlescenestudio/ebdx/sceneassets/"));};
App.prototype.bss087SceneAssetBrowserHTML=function(){
  const q=L(this.ebdx087AssetSearch||""),all=this.bss087SceneAssetRows(),rows=all.filter(x=>!q||L((x.name||"")+" "+(x.projectPath||"")).includes(q)).slice(0,48);
  return `<section class="bss-panel bss087-asset-browser"><div class="bss079-section-head"><div><b>Scene Assets</b><small>Piezas sueltas del pack parallax: añádelas al escenario, no como fondos copiados.</small></div><input class="bss-search" data-bss087-asset-search placeholder="Buscar cielo, montaña, ruina…" value="${E(this.ebdx087AssetSearch||"")}"></div><div class="bss087-asset-grid">${rows.map(x=>`<button type="button" class="bss087-asset-card" data-bss087-asset-add="${E(x.projectPath)}"><span class="bss087-asset-thumb" data-bss087-asset-thumb="${E(x.projectPath)}"></span><b>${E(x.name||x.projectPath.split('/').pop())}</b><small>${E(x.projectPath.replace(/^Graphics\//,""))}</small></button>`).join("")||'<div class="bss-empty">Sin resultados.</div>'}</div></section>`;
};
App.prototype.bss087HydrateAssetThumbs=async function(){
  if(!this.body)return;for(const el of [...this.body.querySelectorAll("[data-bss087-asset-thumb]")]){try{const p=S(el.dataset.bss087AssetThumb),url=await this.assetUrl({projectPath:p});if(url&&el.isConnected)el.innerHTML=`<img src="${E(url)}">`;}catch(_){}}
};
App.prototype.renderEBDXSceneEditor=function(){
  const scene=this.bss087CurrentEditorScene();if(!scene){this.screen="ebdx";return this.renderEBDXStudio();}
  let inspectScene=scene;
  if(scene.kind==="bundle")inspectScene={kind:"builtin",id:scene.id,name:scene.name,description:scene.description,libraryId:scene.libraryId,data:scene.data,row:null};
  let inspector=this.bss079SceneInspectorHTML(inspectScene);
  if(scene.kind==="bundle")inspector=inspector.replace(`data-ebdx-clone="${E(scene.id)}"`,`data-bss087-clone-bundle="${E(scene.id)}"`).replace("EBDX Original · solo lectura","BSS incluido · solo lectura");
  const readonly=scene.kind!=="custom";
  this.body.innerHTML=`<section class="bss087-scene-editor"><header class="bss-libhead bss087-scene-editor-head"><button class="bss-btn" type="button" data-bss087-back-library>← EBDX Studio</button><div class="bss-aura-title"><b>Scene Editor · ${E(scene.name)}</b><small>${readonly?"Solo lectura · duplica para editar":"Escenario del proyecto · guardado persistente"}</small></div><div class="bss-spacer"></div>${readonly?`<button class="bss-btn primary" type="button" ${scene.kind==="bundle"?`data-bss087-clone-bundle="${E(scene.id)}"`:`data-ebdx-clone="${E(scene.id)}"`}>Duplicar y editar</button>`:`<button class="bss-btn" type="button" data-act="ebdx-duplicate-current">Duplicar</button>`}</header><main class="bss087-scene-editor-workspace"><section class="bss087-scene-canvas-column"><div class="bss087-scene-canvas-head"><b>Preview reconstruida</b><small>384×308 lógico · los assets anchos sólo amplían cobertura del mundo.</small></div><div class="bss-ebdx-preview bss079-main-preview bss087-main-preview" data-ebdx-preview></div>${readonly?"":this.bss087SceneAssetBrowserHTML()}</section><section class="bss087-scene-inspector-column">${inspector}</section></main><datalist id="bss079-ebdx-elements">${BSS079_EBDX_ELEMENTS.map(x=>`<option value="${E(x)}"></option>`).join("")}</datalist></section>`;
  this.hydrateEBDXStudioPreview();this.bss087HydrateAssetThumbs();
};

// Render dispatcher for the separate scene editor.
const _bss087Render=App.prototype.render;
App.prototype.render=function(){if(this.screen==="ebdx_scene_editor"){this.disposePreview();this.renderEBDXSceneEditor();if(this.globalSettingsOpen)this.renderGlobalSettingsModal();return;}return _bss087Render.call(this);};

// Camera profiles sit above the per-context controls. Context strength is
// explicit so "context" does not imply a full cut.
const _bss087CameraHTML=App.prototype.bss079CameraConfigHTML;
App.prototype.bss079CameraConfigHTML=function(){
  let html=_bss087CameraHTML.call(this),c=this.bss079EnsureEBDXConfig().ebdxCamera;c.profile=S(c.profile||"source_faithful");
  const profiles=`<div class="bss087-camera-profiles"><div class="bss079-section-head"><div><b>Perfil de cámara</b><small>El perfil define qué contextos pueden mover cámara. Las transiciones usan smoothstep y mantienen continuidad.</small></div></div><div class="bss087-profile-card-grid">${Object.entries(BSS087_CAMERA_PROFILES).map(([id,p])=>`<button type="button" class="bss079-mini-card ${c.profile===id?"active":""}" data-bss087-camera-profile="${E(id)}"><b>${E(p.label)}</b><small>${E(p.note)}</small></button>`).join("")}</div></div>`;
  const strengths=`<div class="bss087-context-strengths"><div class="bss079-section-head"><div><b>Intensidad por contexto</b><small>0% mantiene el plano; 100% llega al encuadre completo del contexto.</small></div></div><div class="bss-mini-grid">${Object.keys(BSS087_CAMERA_PROFILES.source_faithful.contexts).filter(k=>k!=="bas").map(k=>{const r=c.contexts&&c.contexts[k]||{};return `<label class="bss-mini-field"><span>${E(k)}</span><input class="bss-input" type="number" min="0" max="100" data-bss087-context-strength="${E(k)}" value="${N(r.strength,0)}"></label>`;}).join("")}</div></div>`;
  const i=html.indexOf('<div class="bss079-preset-cards">');if(i>=0)html=html.slice(0,i)+profiles+html.slice(i);else html=profiles+html;
  const at=html.lastIndexOf("</section>");return at>=0?html.slice(0,at)+strengths+html.slice(at):html+strengths;
};

App.prototype.bss087CaptureScroll=function(){const c=this.body&&this.body.querySelector(".bss079-ebdx-content"),p=this.body&&this.body.querySelector(".bss079-config-page");return {content:c?c.scrollTop:0,page:p?p.scrollTop:0,body:this.body?this.body.scrollTop:0,win:window.scrollY||0};};
App.prototype.bss087RestoreScroll=function(s){requestAnimationFrame(()=>{const c=this.body&&this.body.querySelector(".bss079-ebdx-content"),p=this.body&&this.body.querySelector(".bss079-config-page");if(c)c.scrollTop=N(s&&s.content,0);if(p)p.scrollTop=N(s&&s.page,0);if(this.body)this.body.scrollTop=N(s&&s.body,0);try{window.scrollTo(0,N(s&&s.win,0));}catch(_){}});};
App.prototype.bss087RenderEBDXPreserveScroll=function(){const s=this.bss087CaptureScroll();this.renderEBDXStudio();this.bss087RestoreScroll(s);};

// User scene/map data is merged back after source refresh. The release itself no
// longer ships scenes.json/map_metadata.json, so installing an update cannot
// overwrite project-authored assignments.
const _bss087Rescan=App.prototype.rescan;
App.prototype.rescan=async function(silent=false){
  const maps=JSON.parse(JSON.stringify(A(this.studio.global&&this.studio.global.ebdxMapMetadata))),custom=JSON.parse(JSON.stringify(A(this.studio.global&&this.studio.global.ebdxCustomEnvironments))),libs=JSON.parse(JSON.stringify(A(this.studio.global&&this.studio.global.ebdxSceneLibraries)));
  const out=await _bss087Rescan.call(this,silent);
  const g=this.studio.global||(this.studio.global={});
  const merge=(now,old,key)=>{const m=new Map(A(now).map(x=>[S(x&&x[key]),x]));A(old).forEach(x=>m.set(S(x&&x[key]),x));return [...m.values()].filter(Boolean);};
  g.ebdxMapMetadata=merge(g.ebdxMapMetadata,maps,"mapId");g.ebdxCustomEnvironments=merge(g.ebdxCustomEnvironments,custom,"id");g.ebdxSceneLibraries=merge(g.ebdxSceneLibraries,libs,"id");
  this.saveSoon();return out;
};

const _bss087Click=App.prototype.onClick;
App.prototype.onClick=function(e){
  const raw=e&&e.target,t=raw&&typeof raw.closest==="function"?raw.closest("button,[data-bss079-scene-id],[data-bss087-camera-profile],[data-bss087-clone-bundle],[data-bss087-asset-add],[data-bss087-back-library],[data-act]"):raw;
  if(t&&t.dataset){
    if(t.dataset.bss087BackLibrary!=null){this.screen="ebdx";this.ebdxStudioTab="backgrounds";this.render();return;}
    if(t.dataset.bss079SceneId!=null&&this.screen==="ebdx"){const sc=this.body&&this.body.querySelector(".bss079-scene-grid-scroll");if(sc)this.ebdxStudioGridScroll=sc.scrollTop;this.bss087OpenSceneEditor(S(t.dataset.bss079SceneKind),S(t.dataset.bss079SceneId));return;}
    if(t.dataset.bss087CameraProfile!=null){const id=S(t.dataset.bss087CameraProfile),p=BSS087_CAMERA_PROFILES[id];if(p){const c=this.bss079EnsureEBDXConfig().ebdxCamera;c.profile=id;c.preset=id;c.contexts=JSON.parse(JSON.stringify(p.contexts));this.saveSoon();this.bss087RenderEBDXPreserveScroll();}return;}
    if(t.dataset.bss087CloneBundle!=null){const src=this.bss087SceneByKindId("bundle",S(t.dataset.bss087CloneBundle));if(!src)return;const rows=this.ebdxCustomRows(),id=this.ebdxUniqueId(src.id+"_custom");rows.push({id,name:S(src.name)+" Custom",description:S(src.description||""),libraryId:"project",data:JSON.parse(JSON.stringify(src.data||{}))});this.ebdxStudioSelected=id;this.saveSoon();this.bss087OpenSceneEditor("custom",id);return;}
    if(t.dataset.bss087AssetAdd!=null){const r=this.ebdxCurrentCustom();if(!r)return;let i=1,key="";do{key="img"+String(i++).padStart(3,"0");}while(r.data&&r.data[key]);const path=S(t.dataset.bss087AssetAdd),small=/\/Props\/|\/Tilesets\//i.test(path),scale=small?2:0.35;r.data=r.data||{};r.data[key]={bitmap:path,x:192,y:small?270:185,z:small?6:2,zoom:scale,zoom_x:scale,zoom_y:scale,opacity:255,flat:!small};this.saveSoon();this.renderEBDXSceneEditor();return;}
    const act=S(t.dataset.act);
    if(act==="ebdx-new-blank"){const rows=this.ebdxCustomRows(),id=this.ebdxUniqueId("scene_custom");rows.push({id,name:"Nuevo escenario",description:"",libraryId:"project",data:{backdrop:"Field"}});this.ebdxStudioSelected=id;this.saveSoon();this.bss087OpenSceneEditor("custom",id);return;}
    if(act==="ebdx-duplicate-current"&&this.screen==="ebdx_scene_editor"){const r=this.ebdxCurrentCustom();if(!r)return;const rows=this.ebdxCustomRows(),id=this.ebdxUniqueId(r.id+"_copy");rows.push({id,name:S(r.name)+" Copy",description:S(r.description||""),libraryId:S(r.libraryId||"project"),data:JSON.parse(JSON.stringify(r.data||{}))});this.ebdxStudioSelected=id;this.saveSoon();this.bss087OpenSceneEditor("custom",id);return;}
    if(act==="bss079-map-assign"){const s=this.bss087CaptureScroll(),pick=this.body.querySelector("[data-bss079-map-pick]"),manual=this.body.querySelector("[data-bss079-map-id]"),sceneEl=this.body.querySelector("[data-bss079-map-new-scene]"),id=N((manual&&manual.value)||(pick&&pick.value),0);if(id<=0){this.toast("Selecciona un mapa o escribe un Map ID válido.",true);return;}const maps=this.bss072ProjectMaps(),pm=maps.find(m=>N(m.mapId||m.id)===id),rows=this.bss072MapRows(),existing=rows.find(r=>N(r.mapId)===id),value={mapId:id,mapName:S(pm&&pm.name||("Map "+id)),backdrop:S(sceneEl&&sceneEl.value||"Auto")};if(existing)Object.assign(existing,value);else rows.push(value);this.saveSoon();this.renderEBDXStudio();this.bss087RestoreScroll(s);return;}
  }
  return _bss087Click.call(this,e);
};

const _bss087Input=App.prototype.onInput;
App.prototype.onInput=function(e){
  const t=e&&e.target;if(t&&t.dataset){
    if(t.dataset.bss087AssetSearch!=null){this.ebdx087AssetSearch=S(t.value);const box=this.body&&this.body.querySelector(".bss087-asset-browser");if(box){const tmp=document.createElement("div");tmp.innerHTML=this.bss087SceneAssetBrowserHTML();if(box.parentNode&&tmp.firstElementChild)box.parentNode.replaceChild(tmp.firstElementChild,box);this.bss087HydrateAssetThumbs();}return;}
    if(t.dataset.bss087ContextStrength!=null){const c=this.bss079EnsureEBDXConfig().ebdxCamera,k=S(t.dataset.bss087ContextStrength);c.contexts=c.contexts||{};c.contexts[k]=c.contexts[k]||{};c.contexts[k].strength=Math.max(0,Math.min(100,N(t.value,0)));c.profile="custom";this.saveSoon();return;}
    if(t.dataset.ebdxLayer!=null){const parts=S(t.dataset.ebdxLayer).split(":"),key=parts.shift(),field=parts.join(":"),r=this.ebdxCurrentCustom(),x=r&&r.data&&r.data[key];if(x&&field==="zoom"){const v=N(t.value,1);x.zoom=v;x.zoom_x=v;x.zoom_y=v;this.saveSoon();this.hydrateEBDXStudioPreview();return;}}
  }
  return _bss087Input.call(this,e);
};

// Card previews stay reconstructed from data in both library and editor.
const _bss087RenderEBDX=App.prototype.renderEBDXStudio;
App.prototype.renderEBDXStudio=function(){const out=_bss087RenderEBDX.call(this);if(S(this.ebdxStudioTab||"backgrounds")==="backgrounds")this.bss079HydrateSceneCards();return out;};

// v0.8.7 closeout: builtin clone stays in Scene Editor, map removal preserves
// scroll, and legacy camera preset cards are hidden in favor of the new profiles.
const _bss087CameraHTML2=App.prototype.bss079CameraConfigHTML;
App.prototype.bss079CameraConfigHTML=function(){
  let html=_bss087CameraHTML2.call(this);
  // The older Strength/Speed preset row is now redundant and could make the
  // active profile ambiguous. Keep the granular numeric controls, remove only
  // that legacy card row.
  const marker='<div class="bss087-camera-profiles">',start=html.indexOf(marker);
  if(start>=0){const after=html.indexOf('<div class="bss079-preset-cards">',start+marker.length);if(after>=0){const close=html.indexOf('</div>',after);if(close>=0)html=html.slice(0,after)+html.slice(close+6);}}
  return html;
};
const _bss087Click2=App.prototype.onClick;
App.prototype.onClick=function(e){
  const raw=e&&e.target,t=raw&&typeof raw.closest==="function"?raw.closest("button,[data-ebdx-clone],[data-bss079-map-remove]"):raw;
  if(t&&t.dataset){
    if(this.screen==="ebdx_scene_editor"&&t.dataset.ebdxClone!=null){const src=this.bss087CurrentEditorScene();if(!src)return;const rows=this.ebdxCustomRows(),id=this.ebdxUniqueId(S(src.id)+"_custom");rows.push({id,name:S(src.name)+" Custom",description:S(src.description||""),libraryId:"project",data:JSON.parse(JSON.stringify(src.data||{}))});this.ebdxStudioSelected=id;this.saveSoon();this.bss087OpenSceneEditor("custom",id);return;}
    if(t.dataset.bss079MapRemove!=null){const s=this.bss087CaptureScroll(),id=N(t.dataset.bss079MapRemove),rows=this.bss072MapRows(),idx=rows.findIndex(r=>N(r.mapId)===id);if(idx>=0)rows.splice(idx,1);this.saveSoon();this.renderEBDXStudio();this.bss087RestoreScroll(s);return;}
  }
  return _bss087Click2.call(this,e);
};

// ============================================================================
// BSS v0.8.8 - unified EBDX Background Composer
// Backgrounds stay in one workspace: Library -> Canvas -> contextual Inspector.
// No Simple/Advanced split: common intent is visible, fine controls are disclosed
// in-place, and the same underlying EBDX data remains available to experts.
// ============================================================================
App.prototype.ebdx088SelectedLayer="";
App.prototype.ebdx088AssetSearch="";
App.prototype.ebdx088AssetCategory="all";

App.prototype.bss088SceneFromState=function(){
  const entries=this.bss079SceneEntries();
  let kind=S(this.ebdxStudioEditorKind||""),id=S(this.ebdxStudioEditorId||"");
  let scene=entries.find(x=>S(x.kind)===kind&&S(x.id)===id);
  if(scene)return scene;
  const custom=this.ebdxCurrentCustom();
  if(custom){scene=entries.find(x=>x.kind==="custom"&&S(x.id)===S(custom.id));if(scene)return scene;}
  const bundleId=S(this.ebdxStudioBundle||"");
  if(bundleId){scene=entries.find(x=>x.kind==="bundle"&&S(x.id)===bundleId);if(scene)return scene;}
  const builtin=S(this.ebdxStudioBuiltin||"Field");
  return entries.find(x=>x.kind==="builtin"&&S(x.id)===builtin)||entries[0]||null;
};
App.prototype.bss088SelectScene=function(kind,id){
  const row=this.bss087SceneByKindId(kind,id);if(!row)return;
  this.ebdxStudioEditorKind=S(kind);this.ebdxStudioEditorId=S(id);this.ebdx088SelectedLayer="";
  if(kind==="custom"){this.ebdxStudioSelected=S(id);this.ebdxStudioBundle="";}
  else if(kind==="builtin"){this.ebdxStudioSelected="";this.ebdxStudioBuiltin=S(id);this.ebdxStudioBundle="";}
  else{this.ebdxStudioSelected="";this.ebdxStudioBundle=S(id);}
};

// Preview authority now understands BSS bundled scenes while keeping custom data
// live (not cloned), so direct manipulation writes to the current project scene.
const _bss088StudioView=App.prototype.ebdxStudioView;
App.prototype.ebdxStudioView=function(){
  const scene=this.bss088SceneFromState();
  if(!scene)return _bss088StudioView.call(this);
  return {kind:scene.kind==="custom"?"custom":"builtin",sourceKind:scene.kind,id:S(scene.id),name:S(scene.name||scene.id),data:scene.kind==="custom"?(scene.data||{}):JSON.parse(JSON.stringify(scene.data||{})),row:scene.row||null};
};

App.prototype.bss088LayerRows=function(scene){return this.ebdxLayerRows(scene&&scene.data||{});};
App.prototype.bss088LayerBehavior=function(x){
  x=x||{};
  if(S(x.effect)==="rotate")return N(x.direction,1)<0?"rotate_ccw":"rotate_cw";
  if(S(x.effect)==="wind")return "wind";
  if(x.scrolling===true){if(x.vertical===true)return N(x.direction,1)<0?"loop_up":"loop_down";return N(x.direction,1)<0?"loop_left":"loop_right";}
  return "static";
};
App.prototype.bss088BehaviorLabel=function(id){return ({static:"Estático",loop_right:"Loop →",loop_left:"Loop ←",loop_down:"Loop ↓",loop_up:"Loop ↑",rotate_cw:"Rotar ↻",rotate_ccw:"Rotar ↺",wind:"Viento / ondulación"})[id]||"Personalizado";};
App.prototype.bss088ColorizeMode=function(x){return S(x&&x.colorize)==="slight"?"slight":(x&&x.colorize===true?"full":"off");};
App.prototype.bss088CurrentLayer=function(scene){
  const rows=this.bss088LayerRows(scene);if(!rows.length){this.ebdx088SelectedLayer="";return null;}
  let key=S(this.ebdx088SelectedLayer);let row=rows.find(r=>r[0]===key);
  if(!row){row=rows[0];this.ebdx088SelectedLayer=row[0];}
  return row;
};

App.prototype.bss079SceneCardHTML=function(x){
  const active=this.bss088SceneFromState(),selected=!!(active&&S(active.kind)===S(x.kind)&&S(active.id)===S(x.id));
  return `<button type="button" class="bss079-scene-card bss088-scene-card ${selected?"active":""}" data-bss079-scene-kind="${E(x.kind)}" data-bss079-scene-id="${E(x.id)}"><div class="bss079-card-preview"><canvas width="384" height="308" data-bss079-card-preview="${E(x.kind+":"+x.id)}"></canvas><span>${x.kind==="builtin"?"EBDX":x.kind==="bundle"?"BSS PACK":"PROYECTO"}</span></div><div class="bss088-scene-card-copy"><b>${E(x.name)}</b><small>${E(x.description||"")}</small></div></button>`;
};

App.prototype.bss088SceneListHTML=function(entries){
  return `<div class="bss088-scene-list">${entries.map(x=>this.bss079SceneCardHTML(x)).join("")||'<div class="bss-empty">Esta librería está vacía.</div>'}</div>`;
};
App.prototype.bss088EnvironmentHTML=function(scene){
  const data=scene.data||{},ro=scene.kind!=="custom",dis=ro?"disabled":"",toggle=(k,label,help)=>`<label class="bss088-env-toggle ${data[k]===true?"on":""}"><input type="checkbox" data-ebdx-top="${E(k)}" ${data[k]===true?"checked":""} ${dis}><span><b>${E(label)}</b><small>${E(help)}</small></span></label>`;
  const backdrop=(S(data.backdrop||"").includes("/")?[S(data.backdrop)]:[]).concat(BSS079_EBDX_BGS);
  return `<section class="bss088-inspector-section"><div class="bss088-section-title"><div><b>Escenario base</b><small>Primero define el lienzo general. Luego construye encima con capas.</small></div></div><div class="bss-mini-grid"><label class="bss-mini-field"><span>Battleback</span><select class="bss-select" data-ebdx-field="backdrop" ${dis}>${backdrop.map(x=>`<option value="${E(x)}" ${S(data.backdrop||"Field")===x?"selected":""}>${E(x.includes("/")?"Custom · "+x.split("/").slice(-2).join("/"):x)}</option>`).join("")}</select></label><label class="bss-mini-field"><span>Suelo / base</span><select class="bss-select" data-ebdx-field="base" ${dis}>${BSS079_EBDX_BASES.map(x=>`<option value="${E(x)}" ${S(data.base||"")===x?"selected":""}>${E(x||"Ninguno")}</option>`).join("")}</select></label></div><div class="bss088-env-grid">${toggle("sky","Cielo EBDX","Sky + nubes automáticas")}${toggle("water","Agua","Dos capas animadas de agua")}${toggle("lightsA","Luces A","Iluminación de escenario")}${toggle("lightsB","Luces B","Pulsos / cambios de color")}${toggle("lightsC","Luces C","Brillos ambientales")}${toggle("spinLights","Luces giratorias","Focos rotatorios")}</div></section>`;
};

App.prototype.bss088LayerListHTML=function(scene){
  const rows=this.bss088LayerRows(scene),ro=scene.kind!=="custom",selected=S(this.ebdx088SelectedLayer);
  return `<section class="bss088-layer-stack"><div class="bss088-layer-stack-head"><div><b>Capas</b><small>${rows.length} elemento(s) · selecciona uno para editarlo</small></div>${ro?"":'<button class="bss-btn small" type="button" data-act="ebdx-layer-add">＋ Capa vacía</button>'}</div><div class="bss088-layer-list">${rows.map(([key,x])=>`<button type="button" class="bss088-layer-row ${selected===key?"active":""}" data-bss088-layer-select="${E(key)}"><span class="bss088-layer-order">${E(key.replace(/^img/i,""))}</span><span class="bss088-layer-main"><b>${E((S(x.bitmap||"Capa").split(/[\\/]/).pop()))}</b><small>${E(this.bss088BehaviorLabel(this.bss088LayerBehavior(x)))} · Z ${N(x.z,0)} · ${Math.round(N(x.opacity,255)/255*100)}%</small></span><span class="bss088-layer-kind">${x.flat===true?"PLANO":"PROF."}</span></button>`).join("")||'<div class="bss-empty small">Sin capas extra. Usa “＋ Capa vacía” o añade un asset desde la bandeja inferior.</div>'}</div></section>`;
};

App.prototype.bss088BehaviorCardsHTML=function(x,ro){
  const active=this.bss088LayerBehavior(x),dis=ro?"disabled":"";
  const rows=[
    ["static","Estático","No se mueve. Ideal para montañas, edificios o props."],
    ["loop_right","Loop →","Desplazamiento horizontal continuo hacia la derecha."],
    ["loop_left","Loop ←","Desplazamiento horizontal continuo hacia la izquierda."],
    ["loop_down","Loop ↓","Desplazamiento vertical continuo hacia abajo."],
    ["loop_up","Loop ↑","Desplazamiento vertical continuo hacia arriba."],
    ["rotate_cw","Rotar ↻","Rotación continua en sentido horario."],
    ["rotate_ccw","Rotar ↺","Rotación continua en sentido antihorario."],
    ["wind","Viento","Ondulación EBDX para vegetación o telas."]
  ];
  return `<div class="bss088-behavior-grid">${rows.map(([id,n,d])=>`<button type="button" class="bss088-behavior-card ${active===id?"active":""}" data-bss088-behavior="${E(id)}" ${dis}><b>${E(n)}</b><small>${E(d)}</small></button>`).join("")}</div>`;
};

App.prototype.bss088LayerInspectorHTML=function(scene){
  const row=this.bss088CurrentLayer(scene),ro=scene.kind!=="custom",dis=ro?"disabled":"";
  if(!row)return `<div class="bss088-inspector-empty"><b>Ninguna capa seleccionada</b><span>Añade un asset desde la bandeja inferior. BSS creará una capa y la dejará seleccionada para editarla sin salir de Fondos.</span></div>`;
  const key=row[0],x=row[1],color=this.bss088ColorizeMode(x),beh=this.bss088LayerBehavior(x);
  return `<div class="bss088-layer-inspector"><div class="bss088-context-head"><div><span>CAPA SELECCIONADA</span><b>${E(key)} · ${E(S(x.bitmap||"Capa").split(/[\\/]/).pop())}</b><small>Todo lo que cambies aquí se ve sobre el mismo canvas.</small></div>${ro?"":`<div class="bss-row"><button class="bss-btn small" type="button" data-ebdx-layer-duplicate="${E(key)}">Duplicar</button><button class="bss-btn danger small" type="button" data-ebdx-layer-remove="${E(key)}">Eliminar</button></div>`}</div><section class="bss088-inspector-section"><div class="bss088-section-title"><div><b>Imagen y posición</b><small>Arrastra el punto de la capa en el canvas o usa los valores exactos.</small></div></div><label class="bss-mini-field"><span>Gráfico / ruta</span><input class="bss-input" list="bss079-ebdx-elements" data-ebdx-layer="${E(key)}:bitmap" value="${E(x.bitmap||"")}" ${dis}></label><div class="bss088-transform-grid"><label class="bss-mini-field"><span>X</span><input class="bss-input" type="number" data-ebdx-layer="${E(key)}:x" value="${N(x.x,0)}" ${dis}></label><label class="bss-mini-field"><span>Y</span><input class="bss-input" type="number" data-ebdx-layer="${E(key)}:y" value="${N(x.y,0)}" ${dis}></label><label class="bss-mini-field"><span>Profundidad Z</span><input class="bss-input" type="number" data-ebdx-layer="${E(key)}:z" value="${N(x.z,0)}" ${dis}></label><label class="bss-mini-field"><span>Escala general</span><input class="bss-input" type="number" step="0.05" min="0.05" max="8" data-ebdx-layer="${E(key)}:zoom" value="${N(x.zoom,1)}" ${dis}><small>Cambia ancho y alto a la vez.</small></label><label class="bss-mini-field"><span>Estirar X · ancho</span><input class="bss-input" type="number" step="0.05" min="0.05" max="8" data-ebdx-layer="${E(key)}:zoom_x" value="${N(x.zoom_x,x.zoom||1)}" ${dis}><small>Escala horizontal independiente.</small></label><label class="bss-mini-field"><span>Estirar Y · alto</span><input class="bss-input" type="number" step="0.05" min="0.05" max="8" data-ebdx-layer="${E(key)}:zoom_y" value="${N(x.zoom_y,x.zoom||1)}" ${dis}><small>Escala vertical independiente.</small></label></div>${ro?"":`<div class="bss088-nudge-pad"><button type="button" data-bss088-nudge="0:-8">↑ 8</button><button type="button" data-bss088-nudge="-8:0">← 8</button><button type="button" data-bss088-center="xy">Centrar</button><button type="button" data-bss088-nudge="8:0">8 →</button><button type="button" data-bss088-nudge="0:8">8 ↓</button></div>`}</section><section class="bss088-inspector-section"><div class="bss088-section-title"><div><b>Comportamiento</b><small>Elige qué quieres que haga la capa. Luego afina velocidad y dirección si lo necesitas.</small></div><span class="bss088-current-behavior">${E(this.bss088BehaviorLabel(beh))}</span></div>${this.bss088BehaviorCardsHTML(x,ro)}<div class="bss-mini-grid bss088-behavior-tune"><label class="bss-mini-field"><span>Velocidad</span><input class="bss-input" type="number" step="0.1" data-ebdx-layer="${E(key)}:speed" value="${N(x.speed,1)}" ${dis}><small>0.5 suave · 1 normal · 16 rápida</small></label><label class="bss-mini-field"><span>Dirección</span><select class="bss-select" data-ebdx-layer="${E(key)}:direction" ${dis}><option value="1" ${N(x.direction,1)>=0?"selected":""}>Normal</option><option value="-1" ${N(x.direction,1)<0?"selected":""}>Invertida</option></select></label></div></section><section class="bss088-inspector-section"><div class="bss088-section-title"><div><b>Integración con la escena</b><small>Define cómo responde al plano EBDX y cuánto se mezcla visualmente.</small></div></div><div class="bss088-switch-list"><label><input type="checkbox" data-ebdx-layer="${E(key)}:flat" ${x.flat===true?"checked":""} ${dis}><span><b>Pegado al plano</b><small>Escala junto al battleback/cámara. Recomendado para fondos y niebla.</small></span></label><label><input type="checkbox" data-ebdx-layer="${E(key)}:canvasLayer" ${x.canvasLayer===true?"checked":""} ${dis}><span><b>Capa de mundo ancho</b><small>Usa el recorte del escenario ancho como parte del mundo, no como sprite suelto.</small></span></label></div><div class="bss-mini-grid"><label class="bss-mini-field"><span>Teñido por ambiente</span><select class="bss-select" data-bss088-colorize="${E(key)}" ${dis}><option value="off" ${color==="off"?"selected":""}>Sin teñido</option><option value="slight" ${color==="slight"?"selected":""}>Suave</option><option value="full" ${color==="full"?"selected":""}>Completo</option></select></label><label class="bss-mini-field"><span>Opacidad</span><input class="bss-input" type="number" min="0" max="255" data-ebdx-layer="${E(key)}:opacity" value="${N(x.opacity,255)}" ${dis}></label></div></section><details class="bss088-fine-controls"><summary>Ajuste fino de la misma capa</summary><div class="bss088-fine-grid"><label class="bss-mini-field"><span>Ángulo inicial °</span><input class="bss-input" type="number" step="1" data-ebdx-layer="${E(key)}:angle" value="${N(x.angle,0)}" ${dis}></label><label class="bss-mini-field"><span>Origen X (ox)</span><input class="bss-input" type="number" data-ebdx-layer="${E(key)}:ox" value="${N(x.ox,0)}" ${dis}></label><label class="bss-mini-field"><span>Origen Y (oy)</span><input class="bss-input" type="number" data-ebdx-layer="${E(key)}:oy" value="${N(x.oy,0)}" ${dis}></label><label class="bss-mini-field"><span>Efecto EBDX</span><select class="bss-select" data-ebdx-layer="${E(key)}:effect" ${dis}><option value="" ${!S(x.effect)?"selected":""}>Ninguno</option><option value="rotate" ${S(x.effect)==="rotate"?"selected":""}>rotate</option><option value="wind" ${S(x.effect)==="wind"?"selected":""}>wind</option></select></label></div><p class="bss-note">Estos campos no están escondidos por “nivel de usuario”: aparecen aquí porque son ajustes de precisión de la misma capa.</p></details></div>`;
};

App.prototype.bss088SceneInspectorHTML=function(scene){
  if(!scene)return '<aside class="bss088-inspector"><div class="bss-empty">Selecciona un escenario.</div></aside>';
  const ro=scene.kind!=="custom",libs=this.bss076SceneLibraries();
  const identity=ro?`<div class="bss088-readonly-banner"><div><b>${E(scene.name)}</b><small>${scene.kind==="bundle"?"Escenario incluido con BSS":"Preset original EBDX"} · solo lectura</small></div><button class="bss-btn primary" type="button" ${scene.kind==="bundle"?`data-bss087-clone-bundle="${E(scene.id)}"`:`data-ebdx-clone="${E(scene.id)}"`}>Duplicar y editar</button></div>`:`<div class="bss088-scene-meta"><label class="bss-mini-field"><span>Nombre</span><input class="bss-input" data-ebdx-name-076 value="${E(scene.name)}"></label><label class="bss-mini-field"><span>Librería</span><select class="bss-select" data-ebdx-scene-library>${libs.map(x=>`<option value="${E(x.id)}" ${S(scene.libraryId||"project")===S(x.id)?"selected":""}>${E(x.name)}</option>`).join("")}</select></label><label class="bss-mini-field bss088-meta-description"><span>Descripción</span><textarea class="bss-textarea" data-ebdx-scene-description>${E(scene.description||"")}</textarea></label><div class="bss-row"><button class="bss-btn" type="button" data-act="ebdx-duplicate-current">Duplicar escenario</button><button class="bss-btn danger" type="button" data-act="ebdx-delete">Eliminar</button></div></div>`;
  return `<aside class="bss088-inspector">${identity}${this.bss088LayerInspectorHTML(scene)}${this.bss088EnvironmentHTML(scene)}<details class="bss088-json"><summary>JSON EBDX del escenario</summary><textarea class="bss-textarea bss-ebdx-json" data-ebdx-json ${ro?"readonly":""}>${E(JSON.stringify(scene.data||{},null,2))}</textarea>${ro?"":'<button class="bss-btn primary" type="button" data-act="ebdx-json-apply">Aplicar JSON</button>'}</details></aside>`;
};

App.prototype.bss088AssetRows=function(){
  return this.bss087SceneAssetRows().filter(x=>!L(x&&x.projectPath).includes("/_licenses/")&&!/\/README\.txt$/i.test(S(x&&x.projectPath))&&!/AssetCatalog\.json$/i.test(S(x&&x.projectPath)));
};
App.prototype.bss088AssetCategoryOf=function(path){const m=S(path).replace(/\\/g,"/").match(/SceneAssets\/([^/]+)(?:\/([^/]+))?/i);if(!m)return "Otros";if(L(m[1])==="cutouts")return "Recortes · "+({clouds:"Nubes",space:"Espacio",lights:"Luces",tiles:"Piezas"}[L(m[2])]||S(m[2]||"Otros"));return m[1];};
App.prototype.bss088AssetTrayHTML=function(scene){
  const ro=!scene||scene.kind!=="custom",all=this.bss088AssetRows(),cats=[...new Set(all.map(x=>this.bss088AssetCategoryOf(x.projectPath)))].sort(),cat=S(this.ebdx088AssetCategory||"all"),q=L(this.ebdx088AssetSearch||"");
  let rows=all.filter(x=>(cat==="all"||this.bss088AssetCategoryOf(x.projectPath)===cat)&&(!q||L((x.name||"")+" "+(x.projectPath||"")).includes(q))).slice(0,80);
  const builtin=["fog","forestShade","mountain","rocks","pillars001","pillars002","shade","snow","star","sun","tree","treeB","treeC","treePine","tallGrass","seaWeed","decor005","decor006","decor009"];
  return `<section class="bss088-asset-tray ${ro?"readonly":""}"><div class="bss088-asset-tray-head"><div><b>＋ Añadir al escenario</b><small>Elige una pieza: BSS la coloca, selecciona y deja lista para mover o dar comportamiento.</small></div><input class="bss-search" data-bss088-asset-search placeholder="Buscar cielo, niebla, ruina, árbol…" value="${E(this.ebdx088AssetSearch||"")}" ${ro?"disabled":""}></div>${ro?'<div class="bss088-readonly-hint">Duplica este escenario para poder añadir elementos.</div>':`<div class="bss088-asset-cats"><button type="button" class="${cat==="all"?"active":""}" data-bss088-asset-cat="all">Todos</button>${cats.map(c=>`<button type="button" class="${cat===c?"active":""}" data-bss088-asset-cat="${E(c)}">${E(c)}</button>`).join("")}</div><div class="bss088-quick-elements"><span>EBDX clásicos</span>${builtin.map(n=>`<button type="button" data-bss088-element-add="${E(n)}">＋ ${E(n)}</button>`).join("")}</div><div class="bss088-asset-grid">${rows.map(x=>`<button type="button" class="bss087-asset-card" data-bss087-asset-add="${E(x.projectPath)}"><span class="bss087-asset-thumb" data-bss087-asset-thumb="${E(x.projectPath)}"></span><b>${E(x.name||x.projectPath.split('/').pop())}</b><small>${E(this.bss088AssetCategoryOf(x.projectPath))}</small></button>`).join("")||'<div class="bss-empty">Sin resultados.</div>'}</div>`}</section>`;
};

// Background tab: one persistent authoring workspace. No route to another editor.
App.prototype.bss079BackgroundsHTML=function(){
  const filter=S(this.ebdxStudioLibraryFilter||"all"),libs=this.bss079SceneLibrariesForFilter(),all=this.bss079SceneEntries(),visible=filter==="all"?all:all.filter(x=>x.libraryId===filter),scene=this.bss088SceneFromState();
  if(scene&&scene.kind==="custom"&&!this.ebdx088SelectedLayer){const first=this.bss088LayerRows(scene)[0];if(first)this.ebdx088SelectedLayer=first[0];}
  const ro=!scene||scene.kind!=="custom";
  return `<div class="bss088-composer"><aside class="bss088-library"><div class="bss088-pane-head"><div><b>Fondos</b><small>Biblioteca + edición sin cambiar de pantalla</small></div><button class="bss-btn primary small" type="button" data-act="ebdx-new-blank">＋ Nuevo</button></div><div class="bss079-library-chips bss088-library-chips">${libs.map(x=>`<button type="button" class="bss079-chip ${filter===x.id?"active":""}" data-bss079-library="${E(x.id)}">${E(x.name)}</button>`).join("")}</div><div class="bss088-library-scroll">${this.bss088SceneListHTML(visible)}</div><button class="bss-btn bss088-new-library" type="button" data-act="ebdx-library-add">＋ Nueva librería</button></aside><main class="bss088-canvas-zone"><div class="bss088-canvas-toolbar"><div><b>${E(scene&&scene.name||"Escenario")}</b><small>${ro?"Solo lectura · duplica para modificar":"Editando dentro de Fondos · autosave"}</small></div><div class="bss088-canvas-actions"><label>Grid <select class="bss-select" data-ebdx-grid ${ro?"disabled":""}>${[1,2,4,8,16,32].map(n=>`<option value="${n}" ${N(this.bss072SceneGrid,8)===n?"selected":""}>${n}px</option>`).join("")}</select></label>${ro?`<button class="bss-btn primary" type="button" ${scene&&scene.kind==="bundle"?`data-bss087-clone-bundle="${E(scene.id)}"`:`data-ebdx-clone="${E(scene&&scene.id||"Field")}"`}>Duplicar y editar</button>`:`<button class="bss-btn" type="button" data-act="ebdx-duplicate-current">Duplicar</button>`}</div></div><div class="bss088-canvas-help"><span><b>Arrastra</b> un punto para mover.</span><span><b>Shift</b> = precisión de 1 px.</span><span><b>Selecciona</b> una capa para ver sólo sus controles.</span></div><div class="bss-ebdx-preview bss079-main-preview bss088-main-preview" data-ebdx-preview></div>${this.bss088LayerListHTML(scene||{kind:"builtin",data:{}})}${this.bss088AssetTrayHTML(scene)}</main>${this.bss088SceneInspectorHTML(scene)}<datalist id="bss079-ebdx-elements">${BSS079_EBDX_ELEMENTS.map(x=>`<option value="${E(x)}"></option>`).join("")}</datalist></div>`;
};

App.prototype.bss088AddLayer=function(bitmap,opts){
  const r=this.ebdxCurrentCustom();if(!r)return null;r.data=r.data&&typeof r.data==="object"?r.data:{};
  const key=this.ebdxNewLayerKey(r.data),o=Object.assign({bitmap:bitmap||"decor005",x:192,y:154,z:3,zoom:1,opacity:255,direction:1},opts||{});r.data[key]=o;this.ebdx088SelectedLayer=key;this.saveSoon();return key;
};
App.prototype.bss088AssetDefaults=function(path){
  const c=this.bss088AssetCategoryOf(path),ps=S(path).replace(/\\/g,"/"),cutTiles=/\/Cutouts\/Tiles\//i.test(ps),cutCloud=/\/Cutouts\/Clouds\//i.test(ps),cutLight=/\/Cutouts\/Lights\//i.test(ps),cutSpace=/\/Cutouts\/Space\//i.test(ps),small=/^(Props|Tilesets)$/i.test(c)||cutTiles,atmo=/^Atmosphere$/i.test(c)||cutCloud,back=/^(Skies|Space)$/i.test(c)||cutSpace,terrain=/^(Terrain|Urban|Caves)$/i.test(c),veg=/^Vegetation$/i.test(c)||cutLight;
  const z=back?1:terrain?2:atmo?4:veg?5:small?7:3,y=back?154:terrain?200:atmo?115:veg?225:small?250:190,zoom=cutTiles?2:(cutSpace?0.7:(cutCloud||cutLight?0.55:(small?2:0.35)));
  const out={bitmap:path,x:192,y:y,z:z,zoom:zoom,zoom_x:zoom,zoom_y:zoom,opacity:255,direction:1,flat:back||terrain||atmo};
  // Cutouts are individual props, not panoramas: never auto-loop them.
  if(atmo&&!cutCloud){out.scrolling=true;out.speed=0.5;out.direction=1;}
  return out;
};
App.prototype.bss088ApplyBehavior=function(x,id){
  if(!x)return;const sheet=x.sheet===true;delete x.effect;delete x.scrolling;if(!sheet)delete x.vertical;
  if(id==="static"){if(x.speed==null)x.speed=1;return;}
  if(id==="wind"){x.effect="wind";if(x.speed==null)x.speed=1;return;}
  if(id==="rotate_cw"||id==="rotate_ccw"){x.effect="rotate";x.direction=id==="rotate_ccw"?-1:1;if(x.speed==null||N(x.speed,0)===0)x.speed=1;return;}
  // EBDX chooses the scrolling sprite class before sheet/animated/rainbow. A
  // displacement loop therefore becomes the graphic's animation authority.
  delete x.sheet;delete x.animated;delete x.rainbow;delete x.frames;delete x.vertical;
  x.scrolling=true;x.vertical=id==="loop_down"||id==="loop_up";x.direction=(id==="loop_left"||id==="loop_up")?-1:1;if(x.speed==null||N(x.speed,0)===0)x.speed=1;
};

// Direct manipulation selects the element as well as dragging it. Re-rendering
// after pointerup stays inside the Background Composer and preserves selection.
const _bss088HydratePreview=App.prototype.hydrateEBDXStudioPreview;
App.prototype.hydrateEBDXStudioPreview=async function(){
  if(!(this.screen==="ebdx"&&S(this.ebdxStudioTab||"backgrounds")==="backgrounds"))return _bss088HydratePreview.call(this);
  const el=this.body&&this.body.querySelector("[data-ebdx-preview]"),view=this.ebdxStudioView();if(!el||!view)return;
  el.innerHTML='<canvas class="bss-ebdx-preview-canvas" width="384" height="308"></canvas><span class="bss088-canvas-caption">EBDX author grid · 384×308</span>';
  const canvas=el.querySelector("canvas");if(!canvas)return;const stamp=(this._bss083PreviewStamp||0)+1;this._bss083PreviewStamp=stamp;const state=await this.bss083EBDXComposite(canvas,view);if(stamp!==this._bss083PreviewStamp||!canvas.isConnected)return;
  if(view.kind!=="custom")return;
  const self=this;let drag=null;
  function point(ev){const r=canvas.getBoundingClientRect();return {x:(ev.clientX-r.left)*384/Math.max(1,r.width),y:(ev.clientY-r.top)*308/Math.max(1,r.height)};}
  function nearest(p){let best=null,bestD=9999;for(const h of state.handles||[]){const dx=h.x-p.x,dy=h.y-p.y,dist=Math.sqrt(dx*dx+dy*dy);if(dist<bestD){bestD=dist;best=h;}}return bestD<=28?best:null;}
  canvas.addEventListener("pointerdown",function(ev){const hit=nearest(point(ev));if(!hit)return;drag=hit;const selectedId=hit.kind==="img"?hit.key:`group:${hit.key}:${hit.index}`;self.ebdx088SelectedLayer=selectedId;const rows=self.body&&self.body.querySelectorAll("[data-bss088-layer-select]");rows&&rows.forEach(n=>n.classList.toggle("active",S(n.dataset.bss088LayerSelect)===selectedId));try{if(canvas.isConnected&&typeof canvas.setPointerCapture==="function"&&ev.pointerId!=null)canvas.setPointerCapture(ev.pointerId);}catch(_){}ev.preventDefault();});
  canvas.addEventListener("pointermove",function(ev){if(!drag)return;const p=point(ev),rawX=Math.max(-192,Math.min(576,p.x)),rawY=Math.max(-154,Math.min(462,p.y)),nx=ev.shiftKey?Math.round(rawX):self.bss072Snap(rawX),ny=ev.shiftKey?Math.round(rawY):self.bss072Snap(rawY);if(drag.kind==="img"){const row=view.data&&view.data[drag.key];if(!row)return;row.x=nx;row.y=ny;}else{const g=view.data&&view.data[drag.key];if(!g||!Array.isArray(g.x)||!Array.isArray(g.y))return;g.x[drag.index]=nx;g.y[drag.index]=ny;}drag.x=nx;drag.y=ny;self.saveSoon();self.bss083EBDXComposite(canvas,view);});
  canvas.addEventListener("pointerup",function(ev){if(!drag)return;drag=null;try{canvas.releasePointerCapture(ev.pointerId);}catch(_){}self.bss088RefreshComposerPanels();});
};

const _bss088Click=App.prototype.onClick;
App.prototype.onClick=function(e){
  const raw=e&&e.target,t=raw&&typeof raw.closest==="function"?raw.closest("button,[data-bss079-scene-id],[data-bss088-layer-select],[data-bss088-behavior],[data-bss088-nudge],[data-bss088-center],[data-bss088-element-add],[data-bss088-asset-cat],[data-bss087-asset-add],[data-ebdx-clone],[data-bss087-clone-bundle],[data-act]"):raw;
  if(this.screen==="ebdx"&&S(this.ebdxStudioTab||"backgrounds")==="backgrounds"&&t&&t.dataset){
    if(t.dataset.bss079SceneId!=null){this.bss088SelectScene(S(t.dataset.bss079SceneKind),S(t.dataset.bss079SceneId));this.renderEBDXStudio();return;}
    if(t.dataset.bss088LayerSelect!=null){this.ebdx088SelectedLayer=S(t.dataset.bss088LayerSelect);this.renderEBDXStudio();return;}
    if(t.dataset.bss088AssetCat!=null){this.ebdx088AssetCategory=S(t.dataset.bss088AssetCat)||"all";this.renderEBDXStudio();return;}
    if(t.dataset.bss088Behavior!=null){const r=this.ebdxCurrentCustom(),x=r&&r.data&&r.data[S(this.ebdx088SelectedLayer)];if(x){this.bss088ApplyBehavior(x,S(t.dataset.bss088Behavior));this.saveSoon();this.renderEBDXStudio();}return;}
    if(t.dataset.bss088Nudge!=null){const r=this.ebdxCurrentCustom(),x=r&&r.data&&r.data[S(this.ebdx088SelectedLayer)];if(x){const p=S(t.dataset.bss088Nudge).split(":"),dx=N(p[0],0),dy=N(p[1],0);x.x=N(x.x,0)+dx;x.y=N(x.y,0)+dy;this.saveSoon();this.renderEBDXStudio();}return;}
    if(t.dataset.bss088Center!=null){const r=this.ebdxCurrentCustom(),x=r&&r.data&&r.data[S(this.ebdx088SelectedLayer)];if(x){x.x=192;x.y=154;this.saveSoon();this.renderEBDXStudio();}return;}
    if(t.dataset.bss088ElementAdd!=null){this.bss088AddLayer(S(t.dataset.bss088ElementAdd),{x:192,y:180,z:3,zoom:1,opacity:255,direction:1});this.renderEBDXStudio();return;}
    if(t.dataset.bss087AssetAdd!=null){const path=S(t.dataset.bss087AssetAdd);this.bss088AddLayer(path,this.bss088AssetDefaults(path));this.renderEBDXStudio();return;}
    if(t.dataset.ebdxClone!=null){const src=this.bss088SceneFromState();if(!src)return;const rows=this.ebdxCustomRows(),id=this.ebdxUniqueId(S(src.id)+"_custom");rows.push({id,name:S(src.name)+" Custom",description:S(src.description||""),libraryId:"project",data:JSON.parse(JSON.stringify(src.data||{}))});this.ebdxStudioSelected=id;this.bss088SelectScene("custom",id);this.saveSoon();this.renderEBDXStudio();return;}
    if(t.dataset.bss087CloneBundle!=null){const src=this.bss087SceneByKindId("bundle",S(t.dataset.bss087CloneBundle));if(!src)return;const rows=this.ebdxCustomRows(),id=this.ebdxUniqueId(src.id+"_custom");rows.push({id,name:S(src.name)+" Custom",description:S(src.description||""),libraryId:"project",data:JSON.parse(JSON.stringify(src.data||{}))});this.ebdxStudioSelected=id;this.bss088SelectScene("custom",id);this.saveSoon();this.renderEBDXStudio();return;}
    const act=S(t.dataset.act);
    if(act==="ebdx-new-blank"){const rows=this.ebdxCustomRows(),id=this.ebdxUniqueId("scene_custom");rows.push({id,name:"Nuevo escenario",description:"",libraryId:"project",data:{backdrop:"Field"}});this.ebdxStudioSelected=id;this.bss088SelectScene("custom",id);this.saveSoon();this.renderEBDXStudio();return;}
    if(act==="ebdx-duplicate-current"){const r=this.ebdxCurrentCustom();if(!r)return;const rows=this.ebdxCustomRows(),id=this.ebdxUniqueId(r.id+"_copy");rows.push({id,name:S(r.name)+" Copy",description:S(r.description||""),libraryId:S(r.libraryId||"project"),data:JSON.parse(JSON.stringify(r.data||{}))});this.ebdxStudioSelected=id;this.bss088SelectScene("custom",id);this.saveSoon();this.renderEBDXStudio();return;}
    if(act==="ebdx-layer-add"){const key=this.bss088AddLayer("decor005",{x:192,y:154,z:3,zoom:1,opacity:255,direction:1});if(key)this.ebdx088SelectedLayer=key;this.renderEBDXStudio();return;}
    if(t.dataset.ebdxLayerDuplicate!=null){const r=this.ebdxCurrentCustom(),src=r&&r.data&&r.data[S(t.dataset.ebdxLayerDuplicate)];if(src){const key=this.ebdxNewLayerKey(r.data);r.data[key]=JSON.parse(JSON.stringify(src));r.data[key].x=N(r.data[key].x,0)+8;r.data[key].y=N(r.data[key].y,0)+8;this.ebdx088SelectedLayer=key;this.saveSoon();this.renderEBDXStudio();}return;}
    if(t.dataset.ebdxLayerRemove!=null){const r=this.ebdxCurrentCustom(),key=S(t.dataset.ebdxLayerRemove);if(r&&r.data&&r.data[key]){delete r.data[key];this.ebdx088SelectedLayer="";const next=this.ebdxLayerRows(r.data)[0];if(next)this.ebdx088SelectedLayer=next[0];this.saveSoon();this.renderEBDXStudio();}return;}
  }
  return _bss088Click.call(this,e);
};

const _bss088Input=App.prototype.onInput;
App.prototype.onInput=function(e){
  const t=e&&e.target;
  if(this.screen==="ebdx"&&S(this.ebdxStudioTab||"backgrounds")==="backgrounds"&&t&&t.dataset){
    if(t.dataset.bss088AssetSearch!=null){this.ebdx088AssetSearch=S(t.value);const tray=this.body&&this.body.querySelector(".bss088-asset-tray");const scene=this.bss088SceneFromState();if(tray){const tmp=document.createElement("div");tmp.innerHTML=this.bss088AssetTrayHTML(scene);if(tray.parentNode&&tmp.firstElementChild)tray.parentNode.replaceChild(tmp.firstElementChild,tray);this.bss087HydrateAssetThumbs();}return;}
    if(t.dataset.bss088Colorize!=null){const r=this.ebdxCurrentCustom(),x=r&&r.data&&r.data[S(t.dataset.bss088Colorize)],v=S(t.value);if(x){if(v==="off")delete x.colorize;else x.colorize=v==="slight"?"slight":true;this.saveSoon();this.hydrateEBDXStudioPreview();}return;}
    if(t.dataset.ebdxLayer!=null){const parts=S(t.dataset.ebdxLayer).split(":"),key=parts.shift(),field=parts.join(":"),r=this.ebdxCurrentCustom(),x=r&&r.data&&r.data[key];if(x){let v=t.type==="checkbox"?!!t.checked:(t.type==="number"?N(t.value):S(t.value));if(["x","y","z","zoom","zoom_x","zoom_y","opacity","speed","direction","angle","ox","oy"].includes(field))v=N(v,field.indexOf("zoom")===0||field==="speed"||field==="direction"?1:0);if(t.type==="checkbox"&&!v)delete x[field];else if((field==="effect"||field==="bitmap")&&!S(v))delete x[field];else x[field]=v;if(field==="zoom"){x.zoom_x=v;x.zoom_y=v;}this.saveSoon();this.hydrateEBDXStudioPreview();return;}}
  }
  return _bss088Input.call(this,e);
};


// v0.8.8b - foliage/group authoring and complete top-level environment controls.
App.prototype.bss088GroupTargets=function(scene){
  const out=[],data=scene&&scene.data||{};
  for(const group of ["trees","tallGrass"]){const g=data[group];if(!g||typeof g!=="object")continue;const n=Math.max(N(g.elements,0),Array.isArray(g.x)?g.x.length:0,Array.isArray(g.y)?g.y.length:0);for(let i=0;i<n;i++)out.push({type:"group",group,index:i,id:`group:${group}:${i}`,data:g});}
  return out;
};
App.prototype.bss088SelectedTarget=function(scene){
  const id=S(this.ebdx088SelectedLayer),m=id.match(/^group:(trees|tallGrass):(\d+)$/);if(m){const g=scene&&scene.data&&scene.data[m[1]],i=N(m[2],0);if(g&&typeof g==="object")return {type:"group",group:m[1],index:i,id,data:g};}
  const row=this.bss088LayerRows(scene).find(r=>r[0]===id);if(row)return {type:"img",key:row[0],id:row[0],data:row[1]};
  const first=this.bss088LayerRows(scene)[0];if(first){this.ebdx088SelectedLayer=first[0];return {type:"img",key:first[0],id:first[0],data:first[1]};}
  const group=this.bss088GroupTargets(scene)[0];if(group){this.ebdx088SelectedLayer=group.id;return group;}
  this.ebdx088SelectedLayer="";return null;
};
App.prototype.bss088GroupValue=function(g,field,i,fallback){const a=g&&g[field];return Array.isArray(a)&&a[i]!=null?a[i]:fallback;};
App.prototype.bss088SetGroupValue=function(g,field,i,value){g[field]=A(g[field]);while(g[field].length<=i)g[field].push(field==="zoom"?1:field==="mirror"?false:0);g[field][i]=value;g.elements=Math.max(N(g.elements,0),i+1,g.x?g.x.length:0,g.y?g.y.length:0);};

App.prototype.bss088LayerListHTML=function(scene){
  const rows=this.bss088LayerRows(scene),groups=this.bss088GroupTargets(scene),ro=scene.kind!=="custom",selected=S(this.ebdx088SelectedLayer);
  const imgs=rows.map(([key,x])=>`<button type="button" class="bss088-layer-row ${selected===key?"active":""}" data-bss088-layer-select="${E(key)}"><span class="bss088-layer-order">${E(key.replace(/^img/i,""))}</span><span class="bss088-layer-main"><b>${E(S(x.bitmap||"Capa").split(/[\\/]/).pop())}</b><small>${E(this.bss088BehaviorLabel(this.bss088LayerBehavior(x)))} · Z ${N(x.z,0)} · ${Math.round(N(x.opacity,255)/255*100)}%</small></span><span class="bss088-layer-kind">${x.flat===true?"PLANO":"PROF."}</span></button>`).join("");
  const foliage=groups.map(t=>{const g=t.data,label=t.group==="trees"?"Árbol":"Hierba",zoom=N(this.bss088GroupValue(g,"zoom",t.index,1),1),z=N(this.bss088GroupValue(g,"z",t.index,3),3);return `<button type="button" class="bss088-layer-row bss088-group-row ${selected===t.id?"active":""}" data-bss088-layer-select="${E(t.id)}"><span class="bss088-layer-order">${t.group==="trees"?"🌲":"▥"}</span><span class="bss088-layer-main"><b>${E(label+" "+(t.index+1))}</b><small>${E(g.bitmap||label)} · viento EBDX · Z ${z} · ×${zoom}</small></span><span class="bss088-layer-kind">GRUPO</span></button>`;}).join("");
  return `<section class="bss088-layer-stack"><div class="bss088-layer-stack-head"><div><b>Capas y elementos</b><small>${rows.length} capa(s) · ${groups.length} elemento(s) de vegetación</small></div>${ro?"":'<div class="bss-row"><button class="bss-btn small" type="button" data-act="ebdx-layer-add">＋ Capa</button><button class="bss-btn small" type="button" data-act="ebdx-tree-add">＋ Árbol</button><button class="bss-btn small" type="button" data-act="ebdx-grass-add">＋ Hierba</button></div>'}</div><div class="bss088-layer-list">${imgs+foliage||'<div class="bss-empty small">Escenario limpio. Añade una capa, árbol, hierba o un asset.</div>'}</div></section>`;
};

App.prototype.bss088GroupInspectorHTML=function(scene,t){
  const ro=scene.kind!=="custom",dis=ro?"disabled":"",g=t.data,i=t.index,label=t.group==="trees"?"Árbol":"Hierba",x=N(this.bss088GroupValue(g,"x",i,192)),y=N(this.bss088GroupValue(g,"y",i,t.group==="trees"?146:180)),z=N(this.bss088GroupValue(g,"z",i,3)),zoom=N(this.bss088GroupValue(g,"zoom",i,1)),mirror=!!this.bss088GroupValue(g,"mirror",i,false),color=S(g.colorize)==="slight"?"slight":(g.colorize===false?"off":"full");
  return `<div class="bss088-layer-inspector"><div class="bss088-context-head"><div><span>ELEMENTO DE GRUPO</span><b>${E(label)} ${i+1}</b><small>Los árboles y la hierba tienen viento suave EBDX automático y comparten el gráfico del grupo.</small></div>${ro?"":`<button class="bss-btn danger small" type="button" data-bss088-group-remove="${E(t.id)}">Eliminar</button>`}</div><section class="bss088-inspector-section"><div class="bss088-section-title"><div><b>Posición y tamaño</b><small>También puedes arrastrar este elemento desde su punto en el canvas.</small></div></div><div class="bss088-transform-grid"><label class="bss-mini-field"><span>X</span><input class="bss-input" type="number" data-bss088-group-field="${E(t.id)}:x" value="${x}" ${dis}></label><label class="bss-mini-field"><span>Y</span><input class="bss-input" type="number" data-bss088-group-field="${E(t.id)}:y" value="${y}" ${dis}></label><label class="bss-mini-field"><span>Profundidad Z</span><input class="bss-input" type="number" data-bss088-group-field="${E(t.id)}:z" value="${z}" ${dis}></label><label class="bss-mini-field"><span>Escala</span><input class="bss-input" type="number" step="0.05" min="0.05" max="8" data-bss088-group-field="${E(t.id)}:zoom" value="${zoom}" ${dis}></label></div>${ro?"":`<div class="bss088-nudge-pad"><button type="button" data-bss088-nudge="0:-8">↑ 8</button><button type="button" data-bss088-nudge="-8:0">← 8</button><button type="button" data-bss088-center="xy">Centrar</button><button type="button" data-bss088-nudge="8:0">8 →</button><button type="button" data-bss088-nudge="0:8">8 ↓</button></div>`}</section><section class="bss088-inspector-section"><div class="bss088-section-title"><div><b>Apariencia del grupo</b><small>Estas opciones afectan a todos los ${t.group==="trees"?"árboles":"elementos de hierba"} de este grupo.</small></div></div><label class="bss-mini-field"><span>Gráfico compartido</span><input class="bss-input" list="bss079-ebdx-elements" data-bss088-group-shared="${E(t.group)}:bitmap" value="${E(g.bitmap|| (t.group==="trees"?"tree":"tallGrass"))}" ${dis}></label><div class="bss-mini-grid"><label class="bss-mini-field"><span>Teñido ambiental</span><select class="bss-select" data-bss088-group-shared="${E(t.group)}:colorize" ${dis}><option value="off" ${color==="off"?"selected":""}>Sin teñido</option><option value="slight" ${color==="slight"?"selected":""}>Suave</option><option value="full" ${color==="full"?"selected":""}>Completo</option></select></label><label class="bss-check bss088-mirror-check"><input type="checkbox" data-bss088-group-field="${E(t.id)}:mirror" ${mirror?"checked":""} ${dis}> Espejar este elemento</label></div></section><div class="bss088-learning-note"><b>Por qué se edita distinto</b><span>EBDX guarda árboles y hierba como grupos de instancias. BSS te deja tratarlos como elementos individuales sin romper ese formato fuente.</span></div></div>`;
};

const _bss088LayerInspectorBase=App.prototype.bss088LayerInspectorHTML;
App.prototype.bss088LayerInspectorHTML=function(scene){const t=this.bss088SelectedTarget(scene);if(t&&t.type==="group")return this.bss088GroupInspectorHTML(scene,t);return _bss088LayerInspectorBase.call(this,scene);};

App.prototype.bss088EnvironmentHTML=function(scene){
  const data=scene.data||{},ro=scene.kind!=="custom",dis=ro?"disabled":"",toggle=(k,label,help)=>`<label class="bss088-env-toggle ${data[k]===true?"on":""}"><input type="checkbox" data-ebdx-top="${E(k)}" ${data[k]===true?"checked":""} ${dis}><span><b>${E(label)}</b><small>${E(help)}</small></span></label>`;
  const backdrop=(S(data.backdrop||"").includes("/")?[S(data.backdrop)]:[]).concat(BSS079_EBDX_BGS);
  return `<section class="bss088-inspector-section"><div class="bss088-section-title"><div><b>Escenario base</b><small>Controles de entorno que EBDX entiende directamente, sin obligarte a tocar JSON.</small></div></div><div class="bss-mini-grid"><label class="bss-mini-field"><span>Battleback</span><select class="bss-select" data-ebdx-field="backdrop" ${dis}>${backdrop.map(x=>`<option value="${E(x)}" ${S(data.backdrop||"Field")===x?"selected":""}>${E(x.includes("/")?"Custom · "+x.split("/").slice(-2).join("/"):x)}</option>`).join("")}</select></label><label class="bss-mini-field"><span>Suelo / base</span><select class="bss-select" data-ebdx-field="base" ${dis}>${BSS079_EBDX_BASES.map(x=>`<option value="${E(x)}" ${S(data.base||"")===x?"selected":""}>${E(x||"Ninguno")}</option>`).join("")}</select></label><label class="bss-mini-field"><span>Burbujas / partículas EBDX</span><select class="bss-select" data-bss088-special="bubbles" ${dis}><option value="" ${!data.bubbles?"selected":""}>Desactivado</option><option value="__default__" ${data.bubbles===true?"selected":""}>Default EBDX · bubble</option>${["bubble","bubbleDark","bubbleRed"].map(v=>`<option value="${v}" ${S(data.bubbles)===v?"selected":""}>${v}</option>`).join("")}</select></label><label class="bss-mini-field"><span>Vacuum / overlay EBDX</span><select class="bss-select" data-bss088-special="vacuum" ${dis}><option value="" ${!data.vacuum?"selected":""}>Desactivado</option><option value="__default__" ${data.vacuum===true?"selected":""}>Default EBDX · dark004</option>${["dark004","dark005","dark006"].map(v=>`<option value="${v}" ${S(data.vacuum)===v?"selected":""}>${v}</option>`).join("")}</select></label></div><div class="bss088-env-grid">${toggle("sky","Cielo EBDX","Sky + nubes automáticas")}${toggle("water","Agua","Dos capas animadas de agua")}${toggle("lightsA","Luces A","Iluminación de escenario")}${toggle("lightsB","Luces B","Pulsos / cambios de color")}${toggle("lightsC","Luces C","Brillos ambientales")}${toggle("spinLights","Luces giratorias","Focos rotatorios")}${toggle("wideWorld","Mundo ancho","Permite cobertura lateral para cámara/parallax")}${toggle("outdoor","Exterior dinámico","Cielo, hora del día y teñido diurno/nocturno EBDX")}${toggle("noshadow","Sin sombras Pokémon","Desactiva las sombras de battlers para escenas que no las necesitan")}${toggle("underwater","Contexto submarino","Marca la escena como submarina para integraciones y tratamiento de agua")}</div></section>`;
};

const _bss088bClick=App.prototype.onClick;
App.prototype.onClick=function(e){
  const raw=e&&e.target,t=raw&&typeof raw.closest==="function"?raw.closest("button,[data-bss088-group-remove],[data-bss088-nudge],[data-bss088-center],[data-act]"):raw;
  if(this.screen==="ebdx"&&S(this.ebdxStudioTab||"backgrounds")==="backgrounds"&&t&&t.dataset){
    const scene=this.bss088SceneFromState(),target=this.bss088SelectedTarget(scene);
    if(target&&target.type==="group"&&t.dataset.bss088Nudge!=null){const p=S(t.dataset.bss088Nudge).split(":"),dx=N(p[0],0),dy=N(p[1],0),g=target.data,i=target.index;this.bss088SetGroupValue(g,"x",i,N(this.bss088GroupValue(g,"x",i,192))+dx);this.bss088SetGroupValue(g,"y",i,N(this.bss088GroupValue(g,"y",i,154))+dy);this.saveSoon();this.renderEBDXStudio();return;}
    if(target&&target.type==="group"&&t.dataset.bss088Center!=null){this.bss088SetGroupValue(target.data,"x",target.index,192);this.bss088SetGroupValue(target.data,"y",target.index,154);this.saveSoon();this.renderEBDXStudio();return;}
    if(t.dataset.bss088GroupRemove!=null){const m=S(t.dataset.bss088GroupRemove).match(/^group:(trees|tallGrass):(\d+)$/),r=this.ebdxCurrentCustom();if(m&&r&&r.data&&r.data[m[1]]){const g=r.data[m[1]],i=N(m[2],0);for(const f of ["x","y","zoom","mirror","z"]){if(Array.isArray(g[f]))g[f].splice(i,1);}g.elements=Math.max(0,(Array.isArray(g.x)?g.x.length:N(g.elements,1)-1));if(g.elements<=0)delete r.data[m[1]];this.ebdx088SelectedLayer="";this.saveSoon();this.renderEBDXStudio();}return;}
    const act=S(t.dataset.act);
    if(act==="ebdx-tree-add"||act==="ebdx-grass-add"){const r=this.ebdxCurrentCustom();if(!r)return;const group=act==="ebdx-tree-add"?"trees":"tallGrass",bitmap=group==="trees"?"tree":"tallGrass",g=r.data[group]&&typeof r.data[group]==="object"?r.data[group]:{bitmap:bitmap,elements:0,x:[],y:[],zoom:[],mirror:[],z:[],colorize:true};const i=Array.isArray(g.x)?g.x.length:0;this.bss088SetGroupValue(g,"x",i,192);this.bss088SetGroupValue(g,"y",i,group==="trees"?146:180);this.bss088SetGroupValue(g,"zoom",i,1);this.bss088SetGroupValue(g,"mirror",i,false);this.bss088SetGroupValue(g,"z",i,3);r.data[group]=g;this.ebdx088SelectedLayer=`group:${group}:${i}`;this.saveSoon();this.renderEBDXStudio();return;}
  }
  return _bss088bClick.call(this,e);
};

const _bss088bInput=App.prototype.onInput;
App.prototype.onInput=function(e){
  const t=e&&e.target;
  if(this.screen==="ebdx"&&S(this.ebdxStudioTab||"backgrounds")==="backgrounds"&&t&&t.dataset){
    if(t.dataset.bss088GroupField!=null){const parts=S(t.dataset.bss088GroupField).split(":"),group=parts[1],i=N(parts[2],0),field=parts[3],r=this.ebdxCurrentCustom(),g=r&&r.data&&r.data[group];if(g){let v=t.type==="checkbox"?!!t.checked:N(t.value,field==="zoom"?1:0);this.bss088SetGroupValue(g,field,i,v);this.saveSoon();this.hydrateEBDXStudioPreview();}return;}
    if(t.dataset.bss088GroupShared!=null){const parts=S(t.dataset.bss088GroupShared).split(":"),group=parts[0],field=parts[1],r=this.ebdxCurrentCustom(),g=r&&r.data&&r.data[group];if(g){const v=S(t.value);if(field==="colorize"){if(v==="off")g.colorize=false;else g.colorize=v==="slight"?"slight":true;}else g[field]=v;this.saveSoon();this.hydrateEBDXStudioPreview();}return;}
  }
  return _bss088bInput.call(this,e);
};

const _bss088SpecialInput=App.prototype.onInput;
App.prototype.onInput=function(e){
  const t=e&&e.target;
  if(this.screen==="ebdx"&&S(this.ebdxStudioTab||"backgrounds")==="backgrounds"&&t&&t.dataset&&t.dataset.bss088Special!=null){const r=this.ebdxCurrentCustom();if(!r)return;const k=S(t.dataset.bss088Special),v=S(t.value);r.data=r.data||{};if(!v)delete r.data[k];else r.data[k]=v==="__default__"?true:v;this.saveSoon();this.hydrateEBDXStudioPreview();return;}
  return _bss088SpecialInput.call(this,e);
};

// Keep ordinary property work light: selecting/moving/changing a behavior does
// not rebuild the whole scene library or reload every card thumbnail.
App.prototype.bss088RefreshComposerPanels=function(){
  if(!this.body||this.screen!=="ebdx"||S(this.ebdxStudioTab||"backgrounds")!=="backgrounds")return this.renderEBDXStudio();
  const scene=this.bss088SceneFromState();if(!scene)return this.renderEBDXStudio();
  const oldInspector=this.body.querySelector(".bss088-inspector"),oldStack=this.body.querySelector(".bss088-layer-stack");
  if(oldInspector){const tmp=document.createElement("div");tmp.innerHTML=this.bss088SceneInspectorHTML(scene);if(oldInspector.parentNode&&tmp.firstElementChild)oldInspector.parentNode.replaceChild(tmp.firstElementChild,oldInspector);}
  if(oldStack){const tmp=document.createElement("div");tmp.innerHTML=this.bss088LayerListHTML(scene);if(oldStack.parentNode&&tmp.firstElementChild)oldStack.parentNode.replaceChild(tmp.firstElementChild,oldStack);}
  this.hydrateEBDXStudioPreview();
};

const _bss088FastClick=App.prototype.onClick;
App.prototype.onClick=function(e){
  const raw=e&&e.target,t=raw&&typeof raw.closest==="function"?raw.closest("button,[data-bss088-layer-select],[data-bss088-behavior],[data-bss088-nudge],[data-bss088-center]"):raw;
  if(this.screen==="ebdx"&&S(this.ebdxStudioTab||"backgrounds")==="backgrounds"&&t&&t.dataset){
    if(t.dataset.bss088LayerSelect!=null){this.ebdx088SelectedLayer=S(t.dataset.bss088LayerSelect);this.bss088RefreshComposerPanels();return;}
    const scene=this.bss088SceneFromState(),target=this.bss088SelectedTarget(scene);
    if(t.dataset.bss088Behavior!=null&&target&&target.type==="img"){this.bss088ApplyBehavior(target.data,S(t.dataset.bss088Behavior));this.saveSoon();this.bss088RefreshComposerPanels();return;}
    if(t.dataset.bss088Nudge!=null&&target){const p=S(t.dataset.bss088Nudge).split(":"),dx=N(p[0],0),dy=N(p[1],0);if(target.type==="img"){target.data.x=N(target.data.x,0)+dx;target.data.y=N(target.data.y,0)+dy;}else{this.bss088SetGroupValue(target.data,"x",target.index,N(this.bss088GroupValue(target.data,"x",target.index,192))+dx);this.bss088SetGroupValue(target.data,"y",target.index,N(this.bss088GroupValue(target.data,"y",target.index,154))+dy);}this.saveSoon();this.bss088RefreshComposerPanels();return;}
    if(t.dataset.bss088Center!=null&&target){if(target.type==="img"){target.data.x=192;target.data.y=154;}else{this.bss088SetGroupValue(target.data,"x",target.index,192);this.bss088SetGroupValue(target.data,"y",target.index,154);}this.saveSoon();this.bss088RefreshComposerPanels();return;}
  }
  return _bss088FastClick.call(this,e);
};

const _bss088Composite=App.prototype.bss083EBDXComposite;
App.prototype.bss083EBDXComposite=async function(canvas,view){
  const state=await _bss088Composite.call(this,canvas,view);
  try{if(canvas&&canvas.closest&&canvas.closest(".bss088-main-preview")&&state&&state.ctx){const id=S(this.ebdx088SelectedLayer),m=id.match(/^group:(trees|tallGrass):(\d+)$/);let h=null;if(m)h=(state.handles||[]).find(x=>x.kind==="group"&&x.key===m[1]&&N(x.index)===N(m[2]));else h=(state.handles||[]).find(x=>x.kind==="img"&&x.key===id);if(h){const c=state.ctx;c.save();c.strokeStyle="rgba(255,255,255,.95)";c.lineWidth=1.5;c.beginPath();c.arc(h.x,h.y,8,0,Math.PI*2);c.stroke();c.strokeStyle="rgba(95,168,255,.95)";c.beginPath();c.arc(h.x,h.y,11,0,Math.PI*2);c.stroke();c.restore();}}}catch(_){}
  return state;
};

// Graphic animation is separate from movement behavior. It exposes native EBDX
// sheet/animated/rainbow sprite classes without requiring JSON editing.
App.prototype.bss088GraphicAnimationType=function(x){if(x&&x.sheet===true)return "sheet";if(x&&x.animated===true)return "animated";if(x&&x.rainbow===true)return "rainbow";return "none";};
const _bss088GraphicInspector=App.prototype.bss088LayerInspectorHTML;
App.prototype.bss088LayerInspectorHTML=function(scene){
  const target=this.bss088SelectedTarget(scene),html=_bss088GraphicInspector.call(this,scene);if(!target||target.type!=="img")return html;
  const x=target.data,key=target.key,ro=scene.kind!=="custom",dis=ro?"disabled":"",type=this.bss088GraphicAnimationType(x),conflict=x.scrolling===true&&type!=="none";
  const block=`<section class="bss088-inspector-section"><div class="bss088-section-title"><div><b>Animación del gráfico</b><small>Esto anima los frames o el color del propio asset; “Comportamiento” mueve o rota la capa completa.</small></div></div><div class="bss-mini-grid"><label class="bss-mini-field"><span>Tipo</span><select class="bss-select" data-bss088-anim-type="${E(key)}" ${dis}><option value="none" ${type==="none"?"selected":""}>Imagen fija</option><option value="sheet" ${type==="sheet"?"selected":""}>Spritesheet simple</option><option value="animated" ${type==="animated"?"selected":""}>Animated EBDX / EBS</option><option value="rainbow" ${type==="rainbow"?"selected":""}>Cambio de tono Rainbow</option></select></label><label class="bss-mini-field"><span>Frames</span><input class="bss-input" type="number" min="1" max="128" data-ebdx-layer="${E(key)}:frames" value="${Math.max(1,N(x.frames,2))}" ${dis}></label></div><div class="bss088-switch-list"><label><input type="checkbox" data-ebdx-layer="${E(key)}:vertical" ${x.vertical===true?"checked":""} ${dis}><span><b>Frames en vertical</b><small>Desactivado = frames distribuidos horizontalmente.</small></span></label><label><input type="checkbox" data-ebdx-layer="${E(key)}:mirror" ${x.mirror===true?"checked":""} ${dis}><span><b>Espejar gráfico</b><small>Invierte la capa sin modificar el archivo fuente.</small></span></label></div>${conflict?'<div class="bss088-conflict-note"><b>Conflicto EBDX</b><span>Esta capa también tiene desplazamiento Loop. EBDX prioriza el scrolling sobre sheet/animated/rainbow; elige uno de los dos comportamientos para que el resultado sea inequívoco.</span></div>':""}</section>`;
  const marker='<details class="bss088-fine-controls">',at=html.indexOf(marker);return at>=0?html.slice(0,at)+block+html.slice(at):html+block;
};

const _bss088GraphicInput=App.prototype.onInput;
App.prototype.onInput=function(e){
  const t=e&&e.target;if(this.screen==="ebdx"&&S(this.ebdxStudioTab||"backgrounds")==="backgrounds"&&t&&t.dataset&&t.dataset.bss088AnimType!=null){const r=this.ebdxCurrentCustom(),x=r&&r.data&&r.data[S(t.dataset.bss088AnimType)],v=S(t.value);if(x){delete x.sheet;delete x.animated;delete x.rainbow;if(v==="sheet"){x.sheet=true;x.frames=Math.max(1,N(x.frames,2));delete x.scrolling;}else if(v==="animated"){x.animated=true;delete x.scrolling;}else if(v==="rainbow"){x.rainbow=true;delete x.scrolling;}this.saveSoon();this.bss088RefreshComposerPanels();}return;}
  return _bss088GraphicInput.call(this,e);
};

// ============================================================================
// BSS v0.8.9 - Background Composer workflow / history / no-flicker drag
// Library is a drawer, Layers/Elements become a full-height authoring dock,
// scene identity uses the scene id as authority, and preview moves are buffered.
// ============================================================================
App.prototype.ebdx089LibraryOpen=false;
App.prototype.ebdx089DockTab="layers";
App.prototype._bss089HistoryByScene=null;
App.prototype._bss089EditKey="";

App.prototype.bss089CurrentCustomRow=function(){
  const id=S(this.ebdxStudioEditorKind)==="custom"?S(this.ebdxStudioEditorId):S(this.ebdxStudioSelected);
  if(id){const r=this.ebdxCustomRows().find(x=>S(x&&x.id)===id);if(r){this.ebdxStudioSelected=id;return r;}}
  return this.ebdxCurrentCustom();
};
App.prototype.bss089SceneHistory=function(){
  const r=this.bss089CurrentCustomRow();if(!r)return null;
  if(!this._bss089HistoryByScene)this._bss089HistoryByScene={};
  const id=S(r.id);if(!this._bss089HistoryByScene[id])this._bss089HistoryByScene[id]={undo:[],redo:[]};
  return this._bss089HistoryByScene[id];
};
App.prototype.bss089SceneSnapshot=function(){
  const r=this.bss089CurrentCustomRow();if(!r)return null;
  return {id:S(r.id),name:S(r.name||r.id),description:S(r.description||""),libraryId:S(r.libraryId||"project"),data:JSON.parse(JSON.stringify(r.data||{})),selectedLayer:S(this.ebdx088SelectedLayer||"")};
};
App.prototype.bss089HistoryCheckpoint=function(label){
  const h=this.bss089SceneHistory(),snap=this.bss089SceneSnapshot();if(!h||!snap)return;
  const text=JSON.stringify(snap),last=h.undo.length?JSON.stringify(h.undo[h.undo.length-1].snapshot):"";
  if(text!==last){h.undo.push({label:S(label||"Editar fondo"),snapshot:snap});if(h.undo.length>80)h.undo.shift();}
  h.redo=[];this.bss089UpdateHistoryButtons();
};
App.prototype.bss089BeginFieldHistory=function(key,eventType){
  key=S(key||"field");
  if(eventType==="input"){
    if(this._bss089EditKey!==key){this._bss089EditKey=key;this.bss089HistoryCheckpoint("Editar "+key);}
  }else if(eventType==="change"){
    if(this._bss089EditKey!==key)this.bss089HistoryCheckpoint("Editar "+key);
    this._bss089EditKey="";
  }
};
App.prototype.bss089RestoreSnapshot=function(snap){
  if(!snap)return false;const r=this.ebdxCustomRows().find(x=>S(x&&x.id)===S(snap.id));if(!r)return false;
  r.name=S(snap.name||r.id);r.description=S(snap.description||"");r.libraryId=S(snap.libraryId||"project");r.data=JSON.parse(JSON.stringify(snap.data||{}));
  this.ebdxStudioSelected=S(r.id);this.ebdxStudioEditorKind="custom";this.ebdxStudioEditorId=S(r.id);this.ebdx088SelectedLayer=S(snap.selectedLayer||"");
  this.saveSoon();return true;
};
App.prototype.bss089Undo=function(){
  this._bss089EditKey="";const h=this.bss089SceneHistory();if(!h||!h.undo.length)return;
  const current=this.bss089SceneSnapshot(),entry=h.undo.pop();if(current)h.redo.push({label:entry.label,snapshot:current});
  if(this.bss089RestoreSnapshot(entry.snapshot)){this.renderEBDXStudio();this.save(true);}
};
App.prototype.bss089Redo=function(){
  this._bss089EditKey="";const h=this.bss089SceneHistory();if(!h||!h.redo.length)return;
  const current=this.bss089SceneSnapshot(),entry=h.redo.pop();if(current)h.undo.push({label:entry.label,snapshot:current});
  if(this.bss089RestoreSnapshot(entry.snapshot)){this.renderEBDXStudio();this.save(true);}
};
App.prototype.bss089UpdateHistoryButtons=function(){
  const h=this.bss089SceneHistory(),canUndo=!!(h&&h.undo.length),canRedo=!!(h&&h.redo.length);
  const u=this.body&&this.body.querySelector("[data-bss089-undo]"),r=this.body&&this.body.querySelector("[data-bss089-redo]");if(u)u.disabled=!canUndo;if(r)r.disabled=!canRedo;
};

App.prototype.bss089LibraryDrawerHTML=function(scene){
  if(!this.ebdx089LibraryOpen)return "";
  const filter=S(this.ebdxStudioLibraryFilter||"all"),libs=this.bss079SceneLibrariesForFilter(),all=this.bss079SceneEntries(),visible=filter==="all"?all:all.filter(x=>x.libraryId===filter);
  return `<div class="bss089-library-overlay"><button class="bss089-library-shade" type="button" aria-label="Cerrar biblioteca" data-bss089-library-close></button><aside class="bss089-library-drawer"><div class="bss088-pane-head"><div><b>Biblioteca de fondos</b><small>Se abre sólo cuando la necesitas; no roba espacio al canvas.</small></div><button class="bss-btn small" type="button" data-bss089-library-close>✕</button></div><div class="bss089-library-actions"><button class="bss-btn primary" type="button" data-act="ebdx-new-blank">＋ Fondo nuevo</button><button class="bss-btn" type="button" data-act="ebdx-library-add">＋ Librería</button></div><div class="bss079-library-chips bss088-library-chips">${libs.map(x=>`<button type="button" class="bss079-chip ${filter===x.id?"active":""}" data-bss079-library="${E(x.id)}">${E(x.name)}</button>`).join("")}</div><div class="bss089-library-list">${this.bss088SceneListHTML(visible)}</div></aside></div>`;
};
App.prototype.bss089ElementsDockHTML=function(scene){
  const ro=!scene||scene.kind!=="custom",all=this.bss088AssetRows(),cats=[...new Set(all.map(x=>this.bss088AssetCategoryOf(x.projectPath)))].sort(),cat=S(this.ebdx088AssetCategory||"all"),q=L(this.ebdx088AssetSearch||"");
  const rows=all.filter(x=>(cat==="all"||this.bss088AssetCategoryOf(x.projectPath)===cat)&&(!q||L((x.name||"")+" "+(x.projectPath||"")).includes(q))).slice(0,140);
  const builtin=["fog","forestShade","mountain","rocks","pillars001","pillars002","shade","snow","star","sun","tree","treeB","treeC","treePine","tallGrass","seaWeed","decor005","decor006","decor009"];
  if(ro)return `<div class="bss089-elements-empty"><b>Escenario de solo lectura</b><span>Duplica el fondo para añadir elementos.</span></div>`;
  return `<section class="bss089-elements"><div class="bss089-element-search"><input class="bss-search" data-bss088-asset-search placeholder="Buscar elemento…" value="${E(this.ebdx088AssetSearch||"")}"></div><div class="bss088-asset-cats bss089-element-cats"><button type="button" class="${cat==="all"?"active":""}" data-bss088-asset-cat="all">Todos</button>${cats.map(c=>`<button type="button" class="${cat===c?"active":""}" data-bss088-asset-cat="${E(c)}">${E(c)}</button>`).join("")}</div><div class="bss089-quick-elements">${builtin.map(n=>`<button type="button" data-bss088-element-add="${E(n)}">＋ ${E(n)}</button>`).join("")}</div><div class="bss089-element-list">${rows.map(x=>`<button type="button" class="bss089-element-row" data-bss087-asset-add="${E(x.projectPath)}"><span class="bss087-asset-thumb" data-bss087-asset-thumb="${E(x.projectPath)}"></span><span><b>${E(x.name||x.projectPath.split('/').pop())}</b><small>${E(this.bss088AssetCategoryOf(x.projectPath))}</small></span><strong>＋</strong></button>`).join("")||'<div class="bss-empty">Sin resultados.</div>'}</div></section>`;
};
App.prototype.bss089AuthorDockHTML=function(scene){
  const tab=S(this.ebdx089DockTab||"layers");
  return `<aside class="bss089-author-dock"><div class="bss089-dock-tabs"><button type="button" class="${tab==="layers"?"active":""}" data-bss089-dock-tab="layers">Capas</button><button type="button" class="${tab==="elements"?"active":""}" data-bss089-dock-tab="elements">＋ Elementos</button></div><div class="bss089-dock-content">${tab==="elements"?this.bss089ElementsDockHTML(scene):this.bss088LayerListHTML(scene||{kind:"builtin",data:{}})}</div></aside>`;
};

// Scene identity is no longer bound to the legacy selection variable.
const _bss089SceneInspectorIdentity=App.prototype.bss088SceneInspectorHTML;
App.prototype.bss088SceneInspectorHTML=function(scene){
  let html=_bss089SceneInspectorIdentity.call(this,scene);
  if(scene&&scene.kind==="custom")html=html.replace(/data-ebdx-name-076/g,"data-bss089-scene-name").replace(/data-ebdx-scene-library/g,"data-bss089-scene-library").replace(/data-ebdx-scene-description/g,"data-bss089-scene-description");
  return html;
};

// Background Composer layout: Outliner | Canvas | Inspector. Library is overlay.
App.prototype.bss079BackgroundsHTML=function(){
  const scene=this.bss088SceneFromState();if(scene&&scene.kind==="custom"&&!this.ebdx088SelectedLayer){const first=this.bss088LayerRows(scene)[0],group=this.bss088GroupTargets(scene)[0];if(first)this.ebdx088SelectedLayer=first[0];else if(group)this.ebdx088SelectedLayer=group.id;}
  const ro=!scene||scene.kind!=="custom",h=this.bss089SceneHistory(),canUndo=!!(h&&h.undo.length),canRedo=!!(h&&h.redo.length);
  return `<div class="bss089-composer">${this.bss089AuthorDockHTML(scene)}<main class="bss089-canvas-zone"><div class="bss089-canvas-toolbar"><div class="bss089-scene-title"><button class="bss-btn" type="button" data-bss089-library-open>☰ Fondos</button><div><b data-bss089-scene-title>${E(scene&&scene.name||"Escenario")}</b><small>${ro?"Solo lectura · duplica para modificar":"Autosave · selecciona capas desde el panel izquierdo"}</small></div></div><div class="bss089-canvas-actions"><button class="bss-btn bss089-history-btn" type="button" data-bss089-undo ${canUndo?"":"disabled"} title="Deshacer · Ctrl+Z">↶ Undo</button><button class="bss-btn bss089-history-btn" type="button" data-bss089-redo ${canRedo?"":"disabled"} title="Rehacer · Ctrl+Y / Ctrl+Shift+Z">↷ Redo</button><label>Grid <select class="bss-select" data-ebdx-grid ${ro?"disabled":""}>${[1,2,4,8,16,32].map(n=>`<option value="${n}" ${N(this.bss072SceneGrid,8)===n?"selected":""}>${n}px</option>`).join("")}</select></label>${ro?`<button class="bss-btn primary" type="button" ${scene&&scene.kind==="bundle"?`data-bss087-clone-bundle="${E(scene.id)}"`:`data-ebdx-clone="${E(scene&&scene.id||"Field")}"`}>Duplicar y editar</button>`:`<button class="bss-btn" type="button" data-act="ebdx-duplicate-current">Duplicar</button>`}</div></div><div class="bss088-canvas-help bss089-canvas-help"><span><b>Capas</b>: selecciona cualquier imagen sin buscar su punto.</span><span><b>Canvas</b>: arrastra el punto; Shift = 1 px.</span><span><b>Elementos</b>: cambia la pestaña izquierda para añadir.</span></div><div class="bss-ebdx-preview bss079-main-preview bss088-main-preview bss089-main-preview" data-ebdx-preview></div></main>${this.bss088SceneInspectorHTML(scene)}${this.bss089LibraryDrawerHTML(scene)}<datalist id="bss079-ebdx-elements">${BSS079_EBDX_ELEMENTS.map(x=>`<option value="${E(x)}"></option>`).join("")}</datalist></div>`;
};

App.prototype.bss089RefreshDock=function(){
  const host=this.body&&this.body.querySelector(".bss089-dock-content"),scene=this.bss088SceneFromState();if(!host||!scene)return;
  host.innerHTML=S(this.ebdx089DockTab||"layers")==="elements"?this.bss089ElementsDockHTML(scene):this.bss088LayerListHTML(scene);if(S(this.ebdx089DockTab)==="elements")this.bss087HydrateAssetThumbs();
};
App.prototype.bss089RefreshInspectorOnly=function(){
  const old=this.body&&this.body.querySelector(".bss088-inspector"),scene=this.bss088SceneFromState();if(!old||!scene)return;
  const tmp=document.createElement("div");tmp.innerHTML=this.bss088SceneInspectorHTML(scene);if(old.parentNode&&tmp.firstElementChild)old.parentNode.replaceChild(tmp.firstElementChild,old);this.bss089UpdateHistoryButtons();
};
App.prototype.bss089RefreshSelectionPanels=function(){
  if(S(this.ebdx089DockTab||"layers")==="layers")this.bss089RefreshDock();this.bss089RefreshInspectorOnly();
};
App.prototype.bss089RefreshQuickBar=function(){
  const old=this.body&&this.body.querySelector(".bss092-quickbar"),scene=this.bss088SceneFromState();
  if(!old||!scene)return;
  const tmp=document.createElement("div");tmp.innerHTML=this.bss092QuickBarHTML(scene);
  const next=tmp.firstElementChild;if(next&&old.parentNode)old.parentNode.replaceChild(next,old);
};
App.prototype.bss089RedrawPreview=async function(){
  const canvas=this.body&&this.body.querySelector(".bss089-main-preview canvas"),view=this.ebdxStudioView();if(canvas&&view)await this.bss083EBDXComposite(canvas,view);
};

// Keep existing callers lightweight in the new layout.
const _bss089OldRefreshPanels=App.prototype.bss088RefreshComposerPanels;
App.prototype.bss088RefreshComposerPanels=function(){
  if(this.body&&this.body.querySelector(".bss089-composer")){this.bss089RefreshSelectionPanels();this.bss089RedrawPreview();return;}
  return _bss089OldRefreshPanels.call(this);
};

// Buffered composite: the visible canvas is never cleared while assets are being
// recomposed, which removes the white/black flash during drag.
const _bss089CompositeSource=App.prototype.bss083EBDXComposite;
App.prototype.bss083EBDXComposite=async function(canvas,view){
  if(!canvas)return null;const off=document.createElement("canvas");off.width=384;off.height=308;const state=await _bss089CompositeSource.call(this,off,view);if(!state)return state;
  if(canvas.width!==384)canvas.width=384;if(canvas.height!==308)canvas.height=308;const ctx=canvas.getContext("2d");ctx.imageSmoothingEnabled=false;ctx.drawImage(off,0,0);
  try{if(canvas.closest&&canvas.closest(".bss089-main-preview")){const id=S(this.ebdx088SelectedLayer),m=id.match(/^group:(trees|tallGrass):(\d+)$/);let h=null;if(m)h=(state.handles||[]).find(x=>x.kind==="group"&&x.key===m[1]&&N(x.index)===N(m[2]));else h=(state.handles||[]).find(x=>x.kind==="img"&&x.key===id);if(h){ctx.save();ctx.strokeStyle="rgba(255,255,255,.96)";ctx.lineWidth=1.5;ctx.beginPath();ctx.arc(h.x,h.y,8,0,Math.PI*2);ctx.stroke();ctx.strokeStyle="rgba(95,168,255,.98)";ctx.beginPath();ctx.arc(h.x,h.y,12,0,Math.PI*2);ctx.stroke();ctx.restore();}}}catch(_){}
  return Object.assign({},state,{ctx});
};

// Drag lifecycle uses one history checkpoint and a coalesced buffered redraw.
const _bss089HydrateFallback=App.prototype.hydrateEBDXStudioPreview;
App.prototype.hydrateEBDXStudioPreview=async function(){
  if(!(this.screen==="ebdx"&&S(this.ebdxStudioTab||"backgrounds")==="backgrounds")||!this.body||!this.body.querySelector(".bss089-composer"))return _bss089HydrateFallback.call(this);
  const el=this.body.querySelector("[data-ebdx-preview]"),view=this.ebdxStudioView();if(!el||!view)return;
  el.innerHTML='<canvas class="bss-ebdx-preview-canvas" width="384" height="308"></canvas><span class="bss088-canvas-caption">EBDX author grid · 384×308</span>';
  const canvas=el.querySelector("canvas");if(!canvas)return;let currentState=await this.bss083EBDXComposite(canvas,view);if(!canvas.isConnected||view.kind!=="custom")return;
  const self=this;let drag=null,dragMoved=false,rendering=false,dirty=false;
  function point(ev){const r=canvas.getBoundingClientRect();return {x:(ev.clientX-r.left)*384/Math.max(1,r.width),y:(ev.clientY-r.top)*308/Math.max(1,r.height)};}
  function nearest(p){let best=null,bestD=9999;for(const h of currentState&&currentState.handles||[]){const dx=h.x-p.x,dy=h.y-p.y,dist=Math.sqrt(dx*dx+dy*dy);if(dist<bestD){bestD=dist;best=h;}}return bestD<=34?best:null;}
  async function drawQueued(){if(rendering){dirty=true;return;}rendering=true;do{dirty=false;currentState=await self.bss083EBDXComposite(canvas,view);}while(dirty&&canvas.isConnected);rendering=false;}
  function queueDraw(){dirty=true;if(!rendering)requestAnimationFrame(()=>drawQueued());}
  canvas.addEventListener("pointerdown",function(ev){const hit=nearest(point(ev));if(!hit)return;drag=hit;dragMoved=false;const id=hit.kind==="img"?hit.key:`group:${hit.key}:${hit.index}`;self.ebdx088SelectedLayer=id;self._bss089EditKey="";self.bss089HistoryCheckpoint("Mover "+id);self.bss089RefreshSelectionPanels();try{if(canvas.isConnected&&typeof canvas.setPointerCapture==="function"&&ev.pointerId!=null)canvas.setPointerCapture(ev.pointerId);}catch(_){}ev.preventDefault();});
  canvas.addEventListener("pointermove",function(ev){if(!drag)return;const p=point(ev),rawX=Math.max(-192,Math.min(576,p.x)),rawY=Math.max(-154,Math.min(462,p.y)),nx=ev.shiftKey?Math.round(rawX):self.bss072Snap(rawX),ny=ev.shiftKey?Math.round(rawY):self.bss072Snap(rawY);if(drag.kind==="img"){const row=view.data&&view.data[drag.key];if(!row)return;row.x=nx;row.y=ny;}else{const g=view.data&&view.data[drag.key];if(!g)return;self.bss088SetGroupValue(g,"x",drag.index,nx);self.bss088SetGroupValue(g,"y",drag.index,ny);}drag.x=nx;drag.y=ny;dragMoved=true;self.saveSoon();queueDraw();ev.preventDefault();});
  function finish(ev){if(!drag)return;drag=null;try{canvas.releasePointerCapture(ev.pointerId);}catch(_){}if(dragMoved){self.bss089RefreshSelectionPanels();queueDraw();}self.bss089UpdateHistoryButtons();}
  canvas.addEventListener("pointerup",finish);canvas.addEventListener("pointercancel",finish);
};

// Outermost click authority for the 0.8.9 composer.
const _bss089ClickBase=App.prototype.onClick;
App.prototype.onClick=function(e){
  const raw=e&&e.target,t=raw&&typeof raw.closest==="function"?raw.closest("button,[data-bss079-scene-id],[data-bss079-library],[data-bss088-layer-select],[data-bss088-behavior],[data-bss088-nudge],[data-bss088-center],[data-bss088-element-add],[data-bss088-asset-cat],[data-bss087-asset-add],[data-ebdx-layer-duplicate],[data-ebdx-layer-remove],[data-bss088-group-remove],[data-bss089-library-open],[data-bss089-library-close],[data-bss089-dock-tab],[data-bss089-undo],[data-bss089-redo],[data-act]"):raw;
  if(this.screen==="ebdx"&&S(this.ebdxStudioTab||"backgrounds")==="backgrounds"&&t&&t.dataset){
    if(t.dataset.bss089LibraryOpen!=null){this.ebdx089LibraryOpen=true;this.renderEBDXStudio();return;}
    if(t.dataset.bss089LibraryClose!=null){this.ebdx089LibraryOpen=false;this.renderEBDXStudio();return;}
    if(t.dataset.bss089DockTab!=null){this.ebdx089DockTab=S(t.dataset.bss089DockTab)||"layers";this.bss089RefreshDock();const tabs=this.body&&this.body.querySelectorAll("[data-bss089-dock-tab]");tabs&&tabs.forEach(x=>x.classList.toggle("active",S(x.dataset.bss089DockTab)===this.ebdx089DockTab));return;}
    if(t.dataset.bss089Undo!=null){this.bss089Undo();return;}if(t.dataset.bss089Redo!=null){this.bss089Redo();return;}
    if(t.dataset.bss079Library!=null){this.ebdxStudioLibraryFilter=S(t.dataset.bss079Library)||"all";this.ebdx089LibraryOpen=true;this.renderEBDXStudio();return;}
    if(t.dataset.bss079SceneId!=null){this.bss088SelectScene(S(t.dataset.bss079SceneKind),S(t.dataset.bss079SceneId));this.ebdx089LibraryOpen=false;this.ebdx089DockTab="layers";this._bss089EditKey="";this.renderEBDXStudio();return;}
    if(t.dataset.bss088LayerSelect!=null){this.ebdx088SelectedLayer=S(t.dataset.bss088LayerSelect);this._bss089EditKey="";if(this.ebdx100CanvasTool==='blur')this.ebdx100CanvasTool='';this._bss099BlurPlacement=null;this.bss089RefreshQuickBar();this.bss089RefreshSelectionPanels();this.bss089RedrawPreview();return;}
    if(t.dataset.bss088AssetCat!=null){this.ebdx088AssetCategory=S(t.dataset.bss088AssetCat)||"all";this.bss089RefreshDock();return;}
    const scene=this.bss088SceneFromState(),target=this.bss088SelectedTarget(scene),row=this.bss089CurrentCustomRow();
    if(t.dataset.bss088Behavior!=null&&target&&target.type==="img"){this.bss089HistoryCheckpoint("Comportamiento de capa");this.bss088ApplyBehavior(target.data,S(t.dataset.bss088Behavior));this.saveSoon();this.bss089RefreshSelectionPanels();this.bss089RedrawPreview();return;}
    if(t.dataset.bss088Nudge!=null&&target){this.bss089HistoryCheckpoint("Mover capa");const p=S(t.dataset.bss088Nudge).split(":"),dx=N(p[0],0),dy=N(p[1],0);if(target.type==="img"){target.data.x=N(target.data.x,0)+dx;target.data.y=N(target.data.y,0)+dy;}else{this.bss088SetGroupValue(target.data,"x",target.index,N(this.bss088GroupValue(target.data,"x",target.index,192))+dx);this.bss088SetGroupValue(target.data,"y",target.index,N(this.bss088GroupValue(target.data,"y",target.index,154))+dy);}this.saveSoon();this.bss089RefreshSelectionPanels();this.bss089RedrawPreview();return;}
    if(t.dataset.bss088Center!=null&&target){this.bss089HistoryCheckpoint("Centrar capa");if(target.type==="img"){target.data.x=192;target.data.y=154;}else{this.bss088SetGroupValue(target.data,"x",target.index,192);this.bss088SetGroupValue(target.data,"y",target.index,154);}this.saveSoon();this.bss089RefreshSelectionPanels();this.bss089RedrawPreview();return;}
    if(t.dataset.bss088ElementAdd!=null){this.bss089HistoryCheckpoint("Añadir elemento");this.bss088AddLayer(S(t.dataset.bss088ElementAdd),{x:192,y:180,z:3,zoom:1,opacity:255,direction:1});this.ebdx089DockTab="layers";this.renderEBDXStudio();return;}
    if(t.dataset.bss087AssetAdd!=null){this.bss089HistoryCheckpoint("Añadir asset");const path=S(t.dataset.bss087AssetAdd);this.bss088AddLayer(path,this.bss088AssetDefaults(path));this.ebdx089DockTab="layers";this.renderEBDXStudio();return;}
    if(t.dataset.ebdxLayerDuplicate!=null&&row){const key=S(t.dataset.ebdxLayerDuplicate),src=row.data&&row.data[key];if(src){this.bss089HistoryCheckpoint("Duplicar capa");const nk=this.ebdxNewLayerKey(row.data);row.data[nk]=JSON.parse(JSON.stringify(src));row.data[nk].x=N(row.data[nk].x,0)+8;row.data[nk].y=N(row.data[nk].y,0)+8;this.ebdx088SelectedLayer=nk;this.saveSoon();this.renderEBDXStudio();}return;}
    if(t.dataset.ebdxLayerRemove!=null&&row){const key=S(t.dataset.ebdxLayerRemove);if(row.data&&row.data[key]){this.bss089HistoryCheckpoint("Eliminar capa");delete row.data[key];this.ebdx088SelectedLayer="";const next=this.bss088LayerRows(scene)[0]||this.bss088GroupTargets(scene)[0];if(next)this.ebdx088SelectedLayer=Array.isArray(next)?next[0]:next.id;this.saveSoon();this.renderEBDXStudio();}return;}
    if(t.dataset.bss088GroupRemove!=null&&row){const m=S(t.dataset.bss088GroupRemove).match(/^group:(trees|tallGrass):(\d+)$/);if(m&&row.data&&row.data[m[1]]){this.bss089HistoryCheckpoint("Eliminar elemento");const g=row.data[m[1]],i=N(m[2],0);for(const f of ["x","y","zoom","mirror","z"])if(Array.isArray(g[f]))g[f].splice(i,1);g.elements=Math.max(0,Array.isArray(g.x)?g.x.length:N(g.elements,1)-1);if(g.elements<=0)delete row.data[m[1]];this.ebdx088SelectedLayer="";this.saveSoon();this.renderEBDXStudio();}return;}
    const act=S(t.dataset.act);
    if(act==="ebdx-layer-add"&&row){this.bss089HistoryCheckpoint("Añadir capa");this.bss088AddLayer("decor005",{x:192,y:154,z:3,zoom:1,opacity:255,direction:1});this.ebdx089DockTab="layers";this.renderEBDXStudio();return;}
    if((act==="ebdx-tree-add"||act==="ebdx-grass-add")&&row){this.bss089HistoryCheckpoint("Añadir vegetación");const group=act==="ebdx-tree-add"?"trees":"tallGrass",bitmap=group==="trees"?"tree":"tallGrass",g=row.data[group]&&typeof row.data[group]==="object"?row.data[group]:{bitmap,elements:0,x:[],y:[],zoom:[],mirror:[],z:[],colorize:true},i=Array.isArray(g.x)?g.x.length:0;this.bss088SetGroupValue(g,"x",i,192);this.bss088SetGroupValue(g,"y",i,group==="trees"?146:180);this.bss088SetGroupValue(g,"zoom",i,1);this.bss088SetGroupValue(g,"mirror",i,false);this.bss088SetGroupValue(g,"z",i,3);row.data[group]=g;this.ebdx088SelectedLayer=`group:${group}:${i}`;this.ebdx089DockTab="layers";this.saveSoon();this.renderEBDXStudio();return;}
    if(act==="ebdx-json-apply")this.bss089HistoryCheckpoint("Aplicar JSON");
    if(["ebdx-new-blank","ebdx-duplicate-current","ebdx-library-add"].includes(act))this.ebdx089LibraryOpen=false;
  }
  return _bss089ClickBase.call(this,e);
};

// Outermost input authority. Identity fields are saved by scene id and committed
// immediately on change; all editable visual fields participate in undo history.
const _bss089InputBase=App.prototype.onInput;
App.prototype.onInput=function(e){
  const t=e&&e.target;if(this.screen==="ebdx"&&S(this.ebdxStudioTab||"backgrounds")==="backgrounds"&&t&&t.dataset){
    const row=this.bss089CurrentCustomRow();
    if(t.dataset.bss089SceneName!=null&&row){this.bss089BeginFieldHistory("nombre",e.type);const v=S(t.value).trim();row.name=v||row.id;const title=this.body&&this.body.querySelector("[data-bss089-scene-title]");if(title)title.textContent=row.name;if(e.type==="change")this.save(true);else this.saveSoon();return;}
    if(t.dataset.bss089SceneLibrary!=null&&row){this.bss089BeginFieldHistory("librería",e.type);row.libraryId=S(t.value||"project");if(e.type==="change")this.save(true);else this.saveSoon();return;}
    if(t.dataset.bss089SceneDescription!=null&&row){this.bss089BeginFieldHistory("descripción",e.type);row.description=S(t.value);if(e.type==="change")this.save(true);else this.saveSoon();return;}
    if(t.dataset.bss088AssetSearch!=null){this.ebdx088AssetSearch=S(t.value);this.bss089RefreshDock();return;}
    const mut=t.dataset.ebdxLayer!=null?"layer:"+S(t.dataset.ebdxLayer):t.dataset.ebdxField!=null?"scene:"+S(t.dataset.ebdxField):t.dataset.ebdxTop!=null?"scene:"+S(t.dataset.ebdxTop):t.dataset.bss088Colorize!=null?"color:"+S(t.dataset.bss088Colorize):t.dataset.bss088GroupField!=null?"group:"+S(t.dataset.bss088GroupField):t.dataset.bss088GroupShared!=null?"group:"+S(t.dataset.bss088GroupShared):t.dataset.bss088Special!=null?"scene:"+S(t.dataset.bss088Special):t.dataset.bss088AnimType!=null?"anim:"+S(t.dataset.bss088AnimType):"";
    if(mut){if(row)this.bss089BeginFieldHistory(mut,e.type);}
  }
  return _bss089InputBase.call(this,e);
};

const _bss089KeyBase=App.prototype.onKeyDown;
App.prototype.onKeyDown=function(e){
  if(this.screen==="ebdx"&&S(this.ebdxStudioTab||"backgrounds")==="backgrounds"&&e&&(e.ctrlKey||e.metaKey)){
    const tag=L(e.target&&e.target.tagName),typing=tag==="input"||tag==="textarea"||e.target&&e.target.isContentEditable;
    if(!typing&&L(e.key)==="z"){e.preventDefault();if(e.shiftKey)this.bss089Redo();else this.bss089Undo();return;}
    if(!typing&&L(e.key)==="y"){e.preventDefault();this.bss089Redo();return;}
  }
  return _bss089KeyBase.call(this,e);
};

const _bss089RenderEBDX=App.prototype.renderEBDXStudio;
App.prototype.renderEBDXStudio=function(){
  const out=_bss089RenderEBDX.call(this);
  if(S(this.ebdxStudioTab||"backgrounds")==="backgrounds"){
    if(S(this.ebdx089DockTab||"layers")==="elements")this.bss087HydrateAssetThumbs();
    this.bss089UpdateHistoryButtons();
  }
  return out;
};

// ============================================================================
// BSS v0.8.12 - Background Composer comfort pass
// - resizable/collapsible side panels
// - focused Inspector tabs (Capa / Escena)
// - unified front-to-back Outliner + depth actions + drag reorder
// - click/drag the visible image area, not only the origin handle
// - quick transform strip + keyboard nudging/depth shortcuts
// ============================================================================
App.prototype.ebdx092InspectorTab="layer";
App.prototype.ebdx092LeftWidth=285;
App.prototype.ebdx092RightWidth=390;
App.prototype.ebdx092LeftHidden=false;
App.prototype.ebdx092RightHidden=false;
App.prototype.ebdx092LayerSearch="";

App.prototype.bss092TargetId=function(t){return !t?"":(t.type==="img"?S(t.key):`group:${S(t.group)}:${N(t.index,0)}`);};
App.prototype.bss092TargetZ=function(t){if(!t)return 0;if(t.type==="img")return N(t.data&&t.data.z,0);return N(this.bss088GroupValue(t.data,"z",t.index,3),3);};
App.prototype.bss092SetTargetZ=function(t,z){if(!t)return;if(t.type==="img")t.data.z=N(z,0);else this.bss088SetGroupValue(t.data,"z",t.index,N(z,0));};
App.prototype.bss092LayerEntries=function(scene){
  const out=[];
  for(const [key,x] of this.bss088LayerRows(scene||{}))out.push({id:key,type:"img",key,data:x,z:N(x.z,0),name:S(x._bssName||x.bitmap||key).split(/[\\/]/).pop(),kind:x.flat===true?"PLANO":"PROF."});
  for(const t of this.bss088GroupTargets(scene||{})){const label=t.group==="trees"?"Árbol":"Hierba";out.push({id:t.id,type:"group",group:t.group,index:t.index,data:t.data,z:this.bss092TargetZ(t),name:`${label} ${t.index+1}`,kind:"GRUPO"});}
  out.sort((a,b)=>b.z-a.z||String(b.id).localeCompare(String(a.id)));
  return out;
};
App.prototype.bss092TargetById=function(scene,id){
  id=S(id);const m=id.match(/^group:(trees|tallGrass):(\d+)$/);if(m){const g=scene&&scene.data&&scene.data[m[1]],i=N(m[2],0);if(g)return {type:"group",group:m[1],index:i,id,data:g};return null;}
  const row=this.bss088LayerRows(scene||{}).find(x=>x[0]===id);return row?{type:"img",key:row[0],id:row[0],data:row[1]}:null;
};
App.prototype.bss092DepthAction=function(action,sourceId,targetId){
  const scene=this.bss088SceneFromState();if(!scene||scene.kind!=="custom")return;
  const entries=this.bss092LayerEntries(scene),source=this.bss092TargetById(scene,sourceId||this.ebdx088SelectedLayer);if(!source)return;
  this.bss089HistoryCheckpoint("Orden de capa");
  const z=this.bss092TargetZ(source),max=Math.max(0,...entries.map(e=>N(e.z,0))),min=Math.min(0,...entries.map(e=>N(e.z,0)));
  if(action==="front")this.bss092SetTargetZ(source,max+1);
  else if(action==="back")this.bss092SetTargetZ(source,min-1);
  else if(action==="up"||action==="down"){
    const idx=entries.findIndex(e=>e.id===this.bss092TargetId(source)),ni=action==="up"?idx-1:idx+1;if(idx<0||ni<0||ni>=entries.length)return;
    const other=this.bss092TargetById(scene,entries[ni].id),oz=this.bss092TargetZ(other);if(oz===z)this.bss092SetTargetZ(source,z+(action==="up"?1:-1));else{this.bss092SetTargetZ(source,oz);this.bss092SetTargetZ(other,z);}
  }else if(action==="drop"){
    const other=this.bss092TargetById(scene,targetId);if(!other||this.bss092TargetId(other)===this.bss092TargetId(source))return;
    const oz=this.bss092TargetZ(other),si=entries.findIndex(e=>e.id===this.bss092TargetId(source)),ti=entries.findIndex(e=>e.id===this.bss092TargetId(other));
    if(oz===z)this.bss092SetTargetZ(source,z+(si>ti?1:-1));else{this.bss092SetTargetZ(source,oz);this.bss092SetTargetZ(other,z);}
  }
  this.saveSoon();this.bss089RefreshDock();this.bss089RefreshInspectorOnly();this.bss089RedrawPreview();
};

App.prototype.bss088LayerListHTML=function(scene){
  scene=scene||{kind:"builtin",data:{}};const ro=scene.kind!=="custom",selected=S(this.ebdx088SelectedLayer),all=this.bss092LayerEntries(scene),q=L(this.ebdx092LayerSearch||"");
  const rows=all.filter(e=>!q||L(`${e.name} ${e.id} ${e.kind}`).includes(q));
  const selectedEntry=all.find(e=>e.id===selected);
  const controls=ro||!selectedEntry?"":`<div class="bss092-layer-actions"><span>Orden</span><button type="button" title="Mandar al frente" data-bss092-depth="front">⇑</button><button type="button" title="Subir una capa" data-bss092-depth="up">↑</button><button type="button" title="Bajar una capa" data-bss092-depth="down">↓</button><button type="button" title="Mandar al fondo" data-bss092-depth="back">⇓</button><em>Z ${E(String(selectedEntry.z))}</em></div>`;
  const html=rows.map(e=>{let sub="";if(e.type==="img")sub=`${E(this.bss088BehaviorLabel(this.bss088LayerBehavior(e.data)))} · Z ${E(String(e.z))} · ${Math.round(N(e.data.opacity,255)/255*100)}%`;else sub=`${E(e.data.bitmap||e.name)} · Z ${E(String(e.z))} · ×${E(String(N(this.bss088GroupValue(e.data,"zoom",e.index,1),1)))}`;return `<div role="button" tabindex="0" draggable="${ro?"false":"true"}" class="bss088-layer-row bss092-layer-row ${selected===e.id?"active":""}" data-bss088-layer-select="${E(e.id)}" data-bss092-drag-layer="${E(e.id)}"><span class="bss092-drag-grip" title="Arrastra para cambiar profundidad">⋮⋮</span><span class="bss088-layer-main"><b>${E(e.name)}</b><small>${sub}</small></span><span class="bss088-layer-kind">${E(e.kind)}</span></div>`;}).join("");
  return `<section class="bss088-layer-stack bss092-layer-stack"><div class="bss088-layer-stack-head bss092-layer-head"><div><b>Capas</b><small>De arriba hacia abajo = frente hacia fondo</small></div>${ro?"":'<button class="bss-btn small" type="button" data-bss089-dock-tab="elements">＋ Añadir</button>'}</div><div class="bss092-layer-search"><input class="bss-search" data-bss092-layer-search placeholder="Buscar capa…" value="${E(this.ebdx092LayerSearch||"")}"></div>${controls}<div class="bss088-layer-list">${html||'<div class="bss-empty small">No hay capas que coincidan.</div>'}</div><div class="bss092-layer-shortcuts"><span>Arrastra filas para profundidad.</span><span>↑↓ mueve · Ctrl+↑/↓ profundidad · Shift = 1 px</span></div></section>`;
};

App.prototype.bss092SceneIdentityHTML=function(scene){
  const ro=!scene||scene.kind!=="custom",libs=this.bss076SceneLibraries();if(!scene)return "";
  if(ro)return `<div class="bss088-readonly-banner"><div><b>${E(scene.name)}</b><small>${scene.kind==="bundle"?"Escenario incluido con BSS":"Preset original EBDX"} · solo lectura</small></div><button class="bss-btn primary" type="button" ${scene.kind==="bundle"?`data-bss087-clone-bundle="${E(scene.id)}"`:`data-ebdx-clone="${E(scene.id)}"`}>Duplicar y editar</button></div>`;
  return `<div class="bss088-scene-meta bss092-scene-meta"><label class="bss-mini-field"><span>Nombre</span><input class="bss-input" data-bss089-scene-name value="${E(scene.name)}"></label><label class="bss-mini-field"><span>Librería</span><select class="bss-select" data-bss089-scene-library>${libs.map(x=>`<option value="${E(x.id)}" ${S(scene.libraryId||"project")===S(x.id)?"selected":""}>${E(x.name)}</option>`).join("")}</select></label><label class="bss-mini-field bss088-meta-description"><span>Descripción</span><textarea class="bss-textarea" data-bss089-scene-description>${E(scene.description||"")}</textarea></label><div class="bss-row"><button class="bss-btn" type="button" data-act="ebdx-duplicate-current">Duplicar escenario</button><button class="bss-btn danger" type="button" data-act="ebdx-delete">Eliminar</button></div></div>`;
};
App.prototype.bss088SceneInspectorHTML=function(scene){
  if(!scene)return '<aside class="bss088-inspector"><div class="bss-empty">Selecciona un escenario.</div></aside>';
  const tab=S(this.ebdx092InspectorTab||"layer"),ro=scene.kind!=="custom";
  const tabs=`<div class="bss092-inspector-tabs"><button type="button" class="${tab==="layer"?"active":""}" data-bss092-inspector-tab="layer">Capa</button><button type="button" class="${tab==="scene"?"active":""}" data-bss092-inspector-tab="scene">Escena</button></div>`;
  const layer=this.bss088LayerInspectorHTML(scene);
  const sceneBody=`${this.bss092SceneIdentityHTML(scene)}${this.bss088EnvironmentHTML(scene)}<details class="bss088-json"><summary>JSON EBDX del escenario</summary><textarea class="bss-textarea bss-ebdx-json" data-ebdx-json ${ro?"readonly":""}>${E(JSON.stringify(scene.data||{},null,2))}</textarea>${ro?"":'<button class="bss-btn primary" type="button" data-act="ebdx-json-apply">Aplicar JSON</button>'}</details>`;
  return `<aside class="bss088-inspector bss092-inspector">${tabs}<div class="bss092-inspector-body">${tab==="scene"?sceneBody:layer}</div></aside>`;
};

App.prototype.bss092QuickBarHTML=function(scene){
  const t=this.bss088SelectedTarget(scene);if(!t)return '<div class="bss092-quickbar muted"><span>Selecciona una capa para transformarla.</span></div>';
  const ro=scene.kind!=="custom",dis=ro?"disabled":"",id=this.bss092TargetId(t),z=this.bss092TargetZ(t),label=t.type==="img"?S(t.data._bssName||t.data.bitmap||id).split(/[\\/]/).pop():(t.group==="trees"?`Árbol ${t.index+1}`:`Hierba ${t.index+1}`);
  let fields="";
  if(t.type==="img")fields=`<label>X <input type="number" data-ebdx-layer="${E(id)}:x" value="${N(t.data.x,0)}" ${dis}></label><label>Y <input type="number" data-ebdx-layer="${E(id)}:y" value="${N(t.data.y,0)}" ${dis}></label><label>Z <input type="number" data-ebdx-layer="${E(id)}:z" value="${z}" ${dis}></label><label>Ancho <input type="number" step="0.05" min="0.05" max="8" data-ebdx-layer="${E(id)}:zoom_x" value="${N(t.data.zoom_x,t.data.zoom||1)}" ${dis}></label><label>Alto <input type="number" step="0.05" min="0.05" max="8" data-ebdx-layer="${E(id)}:zoom_y" value="${N(t.data.zoom_y,t.data.zoom||1)}" ${dis}></label>`;
  else fields=`<label>X <input type="number" data-bss088-group-field="${E(id)}:x" value="${N(this.bss088GroupValue(t.data,"x",t.index,0))}" ${dis}></label><label>Y <input type="number" data-bss088-group-field="${E(id)}:y" value="${N(this.bss088GroupValue(t.data,"y",t.index,0))}" ${dis}></label><label>Z <input type="number" data-bss088-group-field="${E(id)}:z" value="${z}" ${dis}></label><label>Escala <input type="number" step="0.05" min="0.05" max="8" data-bss088-group-field="${E(id)}:zoom" value="${N(this.bss088GroupValue(t.data,"zoom",t.index,1))}" ${dis}></label>`;
  return `<div class="bss092-quickbar"><div class="bss092-quick-name"><small>SELECCIÓN</small><b>${E(label)}</b></div><div class="bss092-quick-fields">${fields}</div>${ro?"":`<div class="bss092-quick-depth"><button type="button" data-bss092-depth="front" title="Al frente">⇑</button><button type="button" data-bss092-depth="up" title="Una capa delante">↑</button><button type="button" data-bss092-depth="down" title="Una capa detrás">↓</button><button type="button" data-bss092-depth="back" title="Al fondo">⇓</button></div>`}</div>`;
};

App.prototype.bss079BackgroundsHTML=function(){
  const scene=this.bss088SceneFromState();if(scene&&scene.kind==="custom"&&!this.ebdx088SelectedLayer){const first=this.bss092LayerEntries(scene)[0];if(first)this.ebdx088SelectedLayer=first.id;}
  const ro=!scene||scene.kind!=="custom",h=this.bss089SceneHistory(),canUndo=!!(h&&h.undo.length),canRedo=!!(h&&h.redo.length),left=Math.max(220,Math.min(430,N(this.ebdx092LeftWidth,285))),right=Math.max(320,Math.min(520,N(this.ebdx092RightWidth,390))),cls=`bss089-composer bss092-composer ${this.ebdx092LeftHidden?"bss092-left-hidden":""} ${this.ebdx092RightHidden?"bss092-right-hidden":""}`;
  return `<div class="${cls}" style="--bss092-left:${left}px;--bss092-right:${right}px">${this.bss089AuthorDockHTML(scene)}<div class="bss092-splitter bss092-splitter-left" data-bss092-splitter="left" title="Arrastra para ajustar Capas"></div><main class="bss089-canvas-zone"><div class="bss089-canvas-toolbar"><div class="bss089-scene-title"><button class="bss-btn" type="button" data-bss089-library-open>☰ Fondos</button><div><b data-bss089-scene-title>${E(scene&&scene.name||"Escenario")}</b><small>${ro?"Solo lectura · duplica para modificar":"Canvas activo · autosave"}</small></div></div><div class="bss089-canvas-actions"><button class="bss-btn bss092-panel-toggle ${this.ebdx092LeftHidden?"off":""}" type="button" data-bss092-toggle-panel="left" title="Mostrar/ocultar capas">▤ Capas</button><button class="bss-btn bss092-panel-toggle ${this.ebdx092RightHidden?"off":""}" type="button" data-bss092-toggle-panel="right" title="Mostrar/ocultar inspector">⚙ Inspector</button><button class="bss-btn bss089-history-btn" type="button" data-bss089-undo ${canUndo?"":"disabled"} title="Deshacer · Ctrl+Z">↶</button><button class="bss-btn bss089-history-btn" type="button" data-bss089-redo ${canRedo?"":"disabled"} title="Rehacer · Ctrl+Y / Ctrl+Shift+Z">↷</button><label>Grid <select class="bss-select" data-ebdx-grid ${ro?"disabled":""}>${[1,2,4,8,16,32].map(n=>`<option value="${n}" ${N(this.bss072SceneGrid,8)===n?"selected":""}>${n}px</option>`).join("")}</select></label>${ro?`<button class="bss-btn primary" type="button" ${scene&&scene.kind==="bundle"?`data-bss087-clone-bundle="${E(scene.id)}"`:`data-ebdx-clone="${E(scene&&scene.id||"Field")}"`}>Duplicar y editar</button>`:`<button class="bss-btn" type="button" data-act="ebdx-duplicate-current">Duplicar</button>`}</div></div>${this.bss092QuickBarHTML(scene||{kind:"builtin",data:{}})}<div class="bss-ebdx-preview bss079-main-preview bss088-main-preview bss089-main-preview bss092-main-preview" data-ebdx-preview></div><div class="bss092-canvas-tip"><span>Clic/arrastra sobre la propia imagen.</span><span>Shift = 1 px · flechas = mover · Ctrl+↑/↓ = profundidad.</span><span>Alt+clic cambia entre capas superpuestas.</span></div></main><div class="bss092-splitter bss092-splitter-right" data-bss092-splitter="right" title="Arrastra para ajustar Inspector"></div>${this.bss088SceneInspectorHTML(scene)}${this.bss089LibraryDrawerHTML(scene)}<datalist id="bss079-ebdx-elements">${BSS079_EBDX_ELEMENTS.map(x=>`<option value="${E(x)}"></option>`).join("")}</datalist></div>`;
};

App.prototype.bss092ImageBounds=function(x,y,w,h,ox,oy,zx,zy,angle){
  zx=N(zx,1);zy=N(zy,1);const ax=ox==null?w/2:N(ox,0),ay=oy==null?h:N(oy,0),pts=[[-ax*zx,-ay*zy],[(w-ax)*zx,-ay*zy],[(w-ax)*zx,(h-ay)*zy],[-ax*zx,(h-ay)*zy]],r=N(angle,0)*Math.PI/180,c=Math.cos(r),s=Math.sin(r);let minX=1e9,minY=1e9,maxX=-1e9,maxY=-1e9;for(const p of pts){const px=x+p[0]*c-p[1]*s,py=y+p[0]*s+p[1]*c;minX=Math.min(minX,px);maxX=Math.max(maxX,px);minY=Math.min(minY,py);maxY=Math.max(maxY,py);}return {x0:minX,y0:minY,x1:maxX,y1:maxY};
};
App.prototype.bss092HitAreas=async function(view){
  const out=[],data=view&&view.data||{};
  for(const key of Object.keys(data).filter(k=>/^img\d+/i.test(k)&&data[k]&&typeof data[k]==="object")){const d=data[key],x=N(d.x,0),y=N(d.y,0),z=N(d.z,0);if(d.canvasLayer===true||d.scrolling===true){out.push({id:key,kind:"img",key,x,y,z,x0:0,y0:0,x1:384,y1:308});continue;}const im=await this.bss083LoadImage(this.bss083EBDXAssetPath("elements",d.bitmap));if(!im)continue;const base=N(d.zoom,1),zx=d.zoom_x!=null?N(d.zoom_x,base):base,zy=d.zoom_y!=null?N(d.zoom_y,base):base,b=this.bss092ImageBounds(x,y,im.width,im.height,d.ox,d.oy,zx,zy,d.angle);out.push(Object.assign({id:key,kind:"img",key,x,y,z},b));}
  for(const group of ["trees","tallGrass"]){const g=data[group];if(!g||!Array.isArray(g.x)||!Array.isArray(g.y))continue;const im=await this.bss083LoadImage(this.bss083EBDXAssetPath("elements",g.bitmap||(group==="trees"?"tree":"tallGrass")));if(!im)continue;for(let i=0;i<Math.min(g.x.length,g.y.length);i++){const x=N(g.x[i],0),y=N(g.y[i],0),zoom=N(Array.isArray(g.zoom)?g.zoom[i]:1,1),mir=!!(Array.isArray(g.mirror)&&g.mirror[i]),z=N(Array.isArray(g.z)?g.z[i]:3,3),b=this.bss092ImageBounds(x,y,im.width,im.height,null,null,mir?-zoom:zoom,zoom,0);out.push(Object.assign({id:`group:${group}:${i}`,kind:"group",key:group,index:i,x,y,z},b));}}
  out.sort((a,b)=>b.z-a.z||String(b.id).localeCompare(String(a.id)));return out;
};

const _bss092Composite=App.prototype.bss083EBDXComposite;
App.prototype.bss083EBDXComposite=async function(canvas,view){
  const state=await _bss092Composite.call(this,canvas,view);if(!state||!view||view.kind!=="custom")return state;
  try{state.hitAreas=await this.bss092HitAreas(view);if(canvas&&canvas.closest&&canvas.closest(".bss092-main-preview")){const sel=S(this.ebdx088SelectedLayer),a=state.hitAreas.find(x=>x.id===sel);if(a){const ctx=canvas.getContext("2d");ctx.save();ctx.strokeStyle="rgba(105,178,255,.98)";ctx.lineWidth=1.5;ctx.setLineDash([5,3]);ctx.strokeRect(Math.round(a.x0)+.5,Math.round(a.y0)+.5,Math.max(1,Math.round(a.x1-a.x0)),Math.max(1,Math.round(a.y1-a.y0)));ctx.setLineDash([]);ctx.fillStyle="rgba(10,18,28,.88)";ctx.strokeStyle="#fff";for(const [cx,cy] of [[a.x0,a.y0],[a.x1,a.y0],[a.x1,a.y1],[a.x0,a.y1]]){ctx.fillRect(cx-3,cy-3,6,6);ctx.strokeRect(cx-3.5,cy-3.5,7,7);}ctx.beginPath();ctx.arc(a.x,a.y,5,0,Math.PI*2);ctx.fill();ctx.stroke();ctx.restore();}}}catch(_){}
  return state;
};

const _bss092HydrateFallback=App.prototype.hydrateEBDXStudioPreview;
App.prototype.hydrateEBDXStudioPreview=async function(){
  if(!(this.screen==="ebdx"&&S(this.ebdxStudioTab||"backgrounds")==="backgrounds")||!this.body||!this.body.querySelector(".bss092-composer"))return _bss092HydrateFallback.call(this);
  const el=this.body.querySelector("[data-ebdx-preview]"),view=this.ebdxStudioView();if(!el||!view)return;el.innerHTML='<canvas class="bss-ebdx-preview-canvas" width="384" height="308"></canvas>';
  const canvas=el.querySelector("canvas");if(!canvas)return;let currentState=await this.bss083EBDXComposite(canvas,view);if(!canvas.isConnected||view.kind!=="custom")return;
  const self=this;let drag=null,dragMoved=false,rendering=false,dirty=false;
  function point(ev){const r=canvas.getBoundingClientRect();return {x:(ev.clientX-r.left)*384/Math.max(1,r.width),y:(ev.clientY-r.top)*308/Math.max(1,r.height)};}
  function hitsAt(p){return (currentState&&currentState.hitAreas||[]).filter(a=>p.x>=a.x0&&p.x<=a.x1&&p.y>=a.y0&&p.y<=a.y1);}
  async function drawQueued(){if(rendering){dirty=true;return;}rendering=true;do{dirty=false;currentState=await self.bss083EBDXComposite(canvas,view);}while(dirty&&canvas.isConnected);rendering=false;}
  function queueDraw(){dirty=true;if(!rendering)requestAnimationFrame(()=>drawQueued());}
  function move(ev){if(!drag)return;const p=point(ev),rawX=Math.max(-192,Math.min(576,p.x+drag.offX)),rawY=Math.max(-154,Math.min(462,p.y+drag.offY)),nx=ev.shiftKey?Math.round(rawX):self.bss072Snap(rawX),ny=ev.shiftKey?Math.round(rawY):self.bss072Snap(rawY);if(drag.kind==="img"){const row=view.data&&view.data[drag.key];if(!row)return;row.x=nx;row.y=ny;}else{const g=view.data&&view.data[drag.key];if(!g)return;self.bss088SetGroupValue(g,"x",drag.index,nx);self.bss088SetGroupValue(g,"y",drag.index,ny);}drag.x=nx;drag.y=ny;dragMoved=true;self.saveSoon();self.bss092SyncQuickBarValues();queueDraw();ev.preventDefault();}
  function finish(){if(!drag)return;drag=null;window.removeEventListener("pointermove",move);window.removeEventListener("pointerup",finish);window.removeEventListener("pointercancel",finish);if(dragMoved){self.bss089RefreshSelectionPanels();queueDraw();}self.bss089UpdateHistoryButtons();}
  canvas.addEventListener("pointerdown",function(ev){const p=point(ev),hits=hitsAt(p);let hit=null;const selected=S(self.ebdx088SelectedLayer),si=hits.findIndex(a=>a.id===selected);if(ev.altKey&&hits.length){hit=hits[(si>=0?si+1:0)%hits.length];}else hit=hits.find(a=>a.id===selected)||hits[0]||null;if(!hit){let best=null,bestD=9999;for(const h of currentState&&currentState.handles||[]){const dx=h.x-p.x,dy=h.y-p.y,d=Math.hypot(dx,dy);if(d<bestD){bestD=d;best=h;}}if(bestD<=18)hit=Object.assign({id:best.kind==="img"?best.key:`group:${best.key}:${best.index}`},best);}if(!hit)return;self.ebdx088SelectedLayer=hit.id;self._bss089EditKey="";self.bss089HistoryCheckpoint("Mover "+hit.id);self.bss089RefreshSelectionPanels();drag=Object.assign({},hit,{offX:N(hit.x,0)-p.x,offY:N(hit.y,0)-p.y});dragMoved=false;window.addEventListener("pointermove",move,{passive:false});window.addEventListener("pointerup",finish,{once:false});window.addEventListener("pointercancel",finish,{once:false});queueDraw();ev.preventDefault();});
};

App.prototype.bss092WireSplitters=function(){
  if(!this.body)return;
  const self=this;
  for(const el of this.body.querySelectorAll("[data-bss092-splitter]")){
    if(el.dataset.bss092Wired)continue;
    el.dataset.bss092Wired="1";
    el.addEventListener("pointerdown",function(ev){
      const side=S(el.dataset.bss092Splitter),startX=ev.clientX,start=side==="left"?N(self.ebdx092LeftWidth,285):N(self.ebdx092RightWidth,390);
      function move(e){const delta=e.clientX-startX;if(side==="left")self.ebdx092LeftWidth=Math.max(220,Math.min(430,start+delta));else self.ebdx092RightWidth=Math.max(320,Math.min(520,start-delta));const root=self.body&&self.body.querySelector(".bss092-composer");if(root)root.style.setProperty(side==="left"?"--bss092-left":"--bss092-right",(side==="left"?self.ebdx092LeftWidth:self.ebdx092RightWidth)+"px");}
      function up(){window.removeEventListener("pointermove",move);window.removeEventListener("pointerup",up);}
      window.addEventListener("pointermove",move);
      window.addEventListener("pointerup",up);
      ev.preventDefault();
    });
  }
};
App.prototype.bss092WireLayerDnD=function(){
  if(!this.body)return;
  const self=this;
  for(const row of this.body.querySelectorAll("[data-bss092-drag-layer]")){
    if(row.dataset.bss092Dnd)continue;
    row.dataset.bss092Dnd="1";
    row.addEventListener("pointerdown",e=>{
      const btn=e.target&&typeof e.target.closest==="function"?e.target.closest("button,.bss092-drag-grip"):null;
      if(btn)return;
      const id=S(row.dataset.bss088LayerSelect||row.dataset.bss092DragLayer);
      if(id&&self.ebdx088SelectedLayer!==id){
        self.ebdx088SelectedLayer=id;
        self._bss089EditKey="";
        self.bss089RefreshSelectionPanels();
        self.bss089RedrawPreview();
      }
    });
    const grip=row.querySelector(".bss092-drag-grip");
    if(grip){
      grip.setAttribute("draggable","true");
      grip.addEventListener("dragstart",e=>{self._bss092DragLayer=S(row.dataset.bss092DragLayer);row.classList.add("dragging");try{e.dataTransfer.effectAllowed="move";e.dataTransfer.setData("text/plain",self._bss092DragLayer);}catch(_){}});
      grip.addEventListener("dragend",()=>{row.classList.remove("dragging");self._bss092DragLayer="";for(const x of self.body.querySelectorAll(".bss092-drop-target"))x.classList.remove("bss092-drop-target");});
    }
    row.setAttribute("draggable","false");
    row.addEventListener("dragover",e=>{if(!self._bss092DragLayer||self._bss092DragLayer===S(row.dataset.bss092DragLayer))return;e.preventDefault();row.classList.add("bss092-drop-target");});
    row.addEventListener("dragleave",()=>row.classList.remove("bss092-drop-target"));
    row.addEventListener("drop",e=>{e.preventDefault();row.classList.remove("bss092-drop-target");const src=self._bss092DragLayer||S(e.dataTransfer&&e.dataTransfer.getData("text/plain")),dst=S(row.dataset.bss092DragLayer);self._bss092DragLayer="";if(src&&dst&&src!==dst)self.bss092DepthAction("drop",src,dst);});
  }
};
App.prototype.bss092WireComfort=function(){this.bss092WireSplitters();this.bss092WireLayerDnD();};

const _bss092ClickBase=App.prototype.onClick;
App.prototype.onClick=function(e){
  const raw=e&&e.target,t=raw&&typeof raw.closest==="function"?raw.closest("button,[data-bss092-depth],[data-bss092-inspector-tab],[data-bss092-toggle-panel]"):raw;
  if(this.screen==="ebdx"&&S(this.ebdxStudioTab||"backgrounds")==="backgrounds"&&t&&t.dataset){
    if(t.dataset.bss092Depth!=null){this.bss092DepthAction(S(t.dataset.bss092Depth));return;}
    if(t.dataset.bss092InspectorTab!=null){this.ebdx092InspectorTab=S(t.dataset.bss092InspectorTab)==="scene"?"scene":"layer";this.bss089RefreshInspectorOnly();this.bss092WireComfort();return;}
    if(t.dataset.bss092TogglePanel!=null){const side=S(t.dataset.bss092TogglePanel);if(side==="left")this.ebdx092LeftHidden=!this.ebdx092LeftHidden;else this.ebdx092RightHidden=!this.ebdx092RightHidden;this.renderEBDXStudio();return;}
  }
  const out=_bss092ClickBase.call(this,e);if(this.screen==="ebdx"&&S(this.ebdxStudioTab||"backgrounds")==="backgrounds")setTimeout(()=>this.bss092WireComfort(),0);return out;
};

const _bss092InputBase=App.prototype.onInput;
App.prototype.onInput=function(e){const t=e&&e.target;if(this.screen==="ebdx"&&S(this.ebdxStudioTab||"backgrounds")==="backgrounds"&&t&&t.dataset&&t.dataset.bss092LayerSearch!=null){this.ebdx092LayerSearch=S(t.value);this.bss089RefreshDock();this.bss092WireComfort();return;}return _bss092InputBase.call(this,e);};

App.prototype.bss092NudgeSelected=function(dx,dy){const scene=this.bss088SceneFromState(),t=this.bss088SelectedTarget(scene);if(!scene||scene.kind!=="custom"||!t)return;this.bss089HistoryCheckpoint("Mover capa");if(t.type==="img"){t.data.x=N(t.data.x,0)+dx;t.data.y=N(t.data.y,0)+dy;}else{this.bss088SetGroupValue(t.data,"x",t.index,N(this.bss088GroupValue(t.data,"x",t.index,0))+dx);this.bss088SetGroupValue(t.data,"y",t.index,N(this.bss088GroupValue(t.data,"y",t.index,0))+dy);}this.saveSoon();this.bss089RefreshSelectionPanels();this.bss089RedrawPreview();};
const _bss092KeyBase=App.prototype.onKeyDown;
App.prototype.onKeyDown=function(e){
  if(this.screen==="ebdx"&&S(this.ebdxStudioTab||"backgrounds")==="backgrounds"&&e){const tag=L(e.target&&e.target.tagName),typing=tag==="input"||tag==="textarea"||tag==="select"||e.target&&e.target.isContentEditable;if(!typing){const k=e.key,step=e.shiftKey?1:Math.max(1,N(this.bss072SceneGrid,8));if((e.ctrlKey||e.metaKey)&&(k==="ArrowUp"||k==="ArrowDown")){e.preventDefault();this.bss092DepthAction(e.shiftKey?(k==="ArrowUp"?"front":"back"):(k==="ArrowUp"?"up":"down"));return;}if(!e.ctrlKey&&!e.metaKey&&["ArrowLeft","ArrowRight","ArrowUp","ArrowDown"].includes(k)){e.preventDefault();this.bss092NudgeSelected(k==="ArrowLeft"?-step:k==="ArrowRight"?step:0,k==="ArrowUp"?-step:k==="ArrowDown"?step:0);return;}}}
  return _bss092KeyBase.call(this,e);
};

const _bss092RefreshDockBase=App.prototype.bss089RefreshDock;
App.prototype.bss089RefreshDock=function(){const out=_bss092RefreshDockBase.call(this);this.bss092WireLayerDnD();return out;};
const _bss092RenderBase=App.prototype.renderEBDXStudio;
App.prototype.renderEBDXStudio=function(){const out=_bss092RenderBase.call(this);if(S(this.ebdxStudioTab||"backgrounds")==="backgrounds")this.bss092WireComfort();return out;};

// Keep the compact transform strip synchronized without rebuilding the canvas.
App.prototype.bss092RefreshQuickBar=function(){
  const old=this.body&&this.body.querySelector(".bss092-quickbar"),scene=this.bss088SceneFromState();if(!old||!scene)return;const tmp=document.createElement("div");tmp.innerHTML=this.bss092QuickBarHTML(scene);if(old.parentNode&&tmp.firstElementChild)old.parentNode.replaceChild(tmp.firstElementChild,old);
};
App.prototype.bss092SyncQuickBarValues=function(){
  const bar=this.body&&this.body.querySelector(".bss092-quickbar"),scene=this.bss088SceneFromState(),t=this.bss088SelectedTarget(scene);if(!bar||!t)return;const id=this.bss092TargetId(t);if(t.type==="img"){const values={x:N(t.data.x,0),y:N(t.data.y,0),z:N(t.data.z,0),zoom_x:N(t.data.zoom_x,t.data.zoom||1),zoom_y:N(t.data.zoom_y,t.data.zoom||1)};for(const [f,v] of Object.entries(values)){const el=bar.querySelector(`[data-ebdx-layer="${id}:${f}"]`);if(el&&document.activeElement!==el)el.value=v;}}else{const values={x:N(this.bss088GroupValue(t.data,"x",t.index,0)),y:N(this.bss088GroupValue(t.data,"y",t.index,0)),z:this.bss092TargetZ(t),zoom:N(this.bss088GroupValue(t.data,"zoom",t.index,1))};for(const [f,v] of Object.entries(values)){const el=bar.querySelector(`[data-bss088-group-field="${id}:${f}"]`);if(el&&document.activeElement!==el)el.value=v;}}
};
const _bss092RefreshSelectionBase=App.prototype.bss089RefreshSelectionPanels;
App.prototype.bss089RefreshSelectionPanels=function(){const out=_bss092RefreshSelectionBase.call(this);this.bss092RefreshQuickBar();this.bss092WireComfort();return out;};
const _bss092DepthActionBase=App.prototype.bss092DepthAction;
App.prototype.bss092DepthAction=function(action,sourceId,targetId){const out=_bss092DepthActionBase.call(this,action,sourceId,targetId);this.bss092RefreshQuickBar();return out;};

// ============================================================================
// BSS v0.8.13 - Direct background deformation / curvature authoring
// Quad warp + editable 3x3/4x4/5x5 mesh with Editor -> JSON -> runtime parity.
// ============================================================================
App.prototype.ebdx093WarpEditKey="";

App.prototype.bss093WarpConfig=function(d){
  const w=d&&d.warp;if(!w||w.enabled!==true)return null;
  const cols=Math.max(2,Math.min(5,Math.round(N(w.cols,2)))),rows=Math.max(2,Math.min(5,Math.round(N(w.rows,2)))),quality=Math.max(1,Math.min(6,Math.round(N(w.quality,4))));
  if(!Array.isArray(w.points)||w.points.length<cols*rows)return null;
  const pts=[];for(let i=0;i<cols*rows;i++){const p=w.points[i];if(!Array.isArray(p)||p.length<2)return null;pts.push([N(p[0],0),N(p[1],0)]);}
  return {enabled:true,mode:S(w.mode||((cols===2&&rows===2)?"quad":"mesh")),cols,rows,quality,points:pts};
};
App.prototype.bss093WarpSample=function(cfg,u,v){
  if(!cfg)return [0,0];u=Math.max(0,Math.min(1,N(u,0)));v=Math.max(0,Math.min(1,N(v,0)));const gx=u*(cfg.cols-1),gy=v*(cfg.rows-1),x0=Math.min(cfg.cols-2,Math.floor(gx)),y0=Math.min(cfg.rows-2,Math.floor(gy)),tx=gx-x0,ty=gy-y0,at=(x,y)=>cfg.points[y*cfg.cols+x],p00=at(x0,y0),p10=at(x0+1,y0),p01=at(x0,y0+1),p11=at(x0+1,y0+1),ax=p00[0]+(p10[0]-p00[0])*tx,ay=p00[1]+(p10[1]-p00[1])*tx,bx=p01[0]+(p11[0]-p01[0])*tx,by=p01[1]+(p11[1]-p01[1])*tx;return [ax+(bx-ax)*ty,ay+(by-ay)*ty];
};
App.prototype.bss093DefaultWarpPoints=function(d,img,cols,rows){
  if(!img)return [];const ax=d.ox!=null?N(d.ox,0):img.width/2,ay=d.oy!=null?N(d.oy,0):img.height,pts=[];
  // Points live in the image's local, unscaled space. Global X/Y, rotation and
  // independent X/Y scale remain editable after deformation and are applied on
  // top of the mesh instead of becoming baked into it.
  for(let y=0;y<rows;y++)for(let x=0;x<cols;x++){const u=x/(cols-1),v=y/(rows-1);pts.push([u*img.width-ax,v*img.height-ay]);}return pts;
};
App.prototype.bss093WarpAuthorPoint=function(d,p){const base=N(d&&d.zoom,1),zx=d&&d.zoom_x!=null?N(d.zoom_x,base):base,zy=d&&d.zoom_y!=null?N(d.zoom_y,base):base,r=N(d&&d.angle,0)*Math.PI/180,c=Math.cos(r),s=Math.sin(r),lx=N(p&&p[0],0)*zx,ly=N(p&&p[1],0)*zy;return [N(d&&d.x,0)+lx*c-ly*s,N(d&&d.y,0)+lx*s+ly*c];};
App.prototype.bss093WarpLocalFromAuthor=function(d,x,y){const base=N(d&&d.zoom,1),zx=d&&d.zoom_x!=null?N(d.zoom_x,base):base,zy=d&&d.zoom_y!=null?N(d.zoom_y,base):base,r=-N(d&&d.angle,0)*Math.PI/180,c=Math.cos(r),s=Math.sin(r),dx=N(x,0)-N(d&&d.x,0),dy=N(y,0)-N(d&&d.y,0),rx=dx*c-dy*s,ry=dx*s+dy*c;return [rx/(Math.abs(zx)<1e-6?1:zx),ry/(Math.abs(zy)<1e-6?1:zy)];};
App.prototype.bss093ResampleWarp=function(cfg,cols,rows){
  const pts=[];for(let y=0;y<rows;y++)for(let x=0;x<cols;x++)pts.push(this.bss093WarpSample(cfg,x/(cols-1),y/(rows-1)));return pts;
};
App.prototype.bss093WarpActualPoints=function(d){const cfg=this.bss093WarpConfig(d);if(!cfg)return [];return cfg.points.map(p=>this.bss093WarpAuthorPoint(d,p));};
App.prototype.bss093DisableWarpConflicts=function(d){for(const k of ["scrolling","vertical","sheet","frames","animated","rainbow","effect","canvasLayer"])delete d[k];};

App.prototype.bss093DrawTexturedTriangle=function(ctx,img,s0,s1,s2,d0,d1,d2){
  const sx1=s1[0]-s0[0],sy1=s1[1]-s0[1],sx2=s2[0]-s0[0],sy2=s2[1]-s0[1],det=sx1*sy2-sx2*sy1;if(Math.abs(det)<1e-7)return;
  const dx1=d1[0]-d0[0],dy1=d1[1]-d0[1],dx2=d2[0]-d0[0],dy2=d2[1]-d0[1],a=(dx1*sy2-dx2*sy1)/det,c=(-dx1*sx2+dx2*sx1)/det,b=(dy1*sy2-dy2*sy1)/det,d=(-dy1*sx2+dy2*sx1)/det,e=d0[0]-a*s0[0]-c*s0[1],f=d0[1]-b*s0[0]-d*s0[1];
  const cx=(d0[0]+d1[0]+d2[0])/3, cy=(d0[1]+d1[1]+d2[1])/3;
  const dilate=p=>{
    const vx=p[0]-cx, vy=p[1]-cy, len=Math.hypot(vx,vy);
    return len<1e-4?p:[p[0]+(vx/len)*0.22, p[1]+(vy/len)*0.22];
  };
  const cd0=dilate(d0), cd1=dilate(d1), cd2=dilate(d2);
  ctx.save();
  ctx.imageSmoothingEnabled=true;
  if(ctx.imageSmoothingQuality)ctx.imageSmoothingQuality="high";
  ctx.beginPath();ctx.moveTo(cd0[0],cd0[1]);ctx.lineTo(cd1[0],cd1[1]);ctx.lineTo(cd2[0],cd2[1]);ctx.closePath();ctx.clip();
  ctx.transform(a,b,c,d,e,f);ctx.drawImage(img,0,0);
  ctx.restore();
};
App.prototype.bss093DrawWarped=function(ctx,img,d){
  const cfg=this.bss093WarpConfig(d);if(!cfg||!img){this.bss083DrawAnchored(ctx,img,N(d.x,0),N(d.y,0),N(d.zoom_x,d.zoom||1),false,d.ox,d.oy,d.angle,N(d.zoom_y,d.zoom||1));return;}
  let q=cfg.quality,segX=(cfg.cols-1)*q,segY=(cfg.rows-1)*q;while(segX*segY>256&&q>1){q--;segX=(cfg.cols-1)*q;segY=(cfg.rows-1)*q;}const dest=(u,v)=>this.bss093WarpAuthorPoint(d,this.bss093WarpSample(cfg,u,v)),src=(u,v)=>[u*img.width,v*img.height];
  for(let iy=0;iy<segY;iy++)for(let ix=0;ix<segX;ix++){const u0=ix/segX,u1=(ix+1)/segX,v0=iy/segY,v1=(iy+1)/segY,s00=src(u0,v0),s10=src(u1,v0),s11=src(u1,v1),s01=src(u0,v1),p00=dest(u0,v0),p10=dest(u1,v0),p11=dest(u1,v1),p01=dest(u0,v1);this.bss093DrawTexturedTriangle(ctx,img,s00,s10,s11,p00,p10,p11);this.bss093DrawTexturedTriangle(ctx,img,s00,s11,s01,p00,p11,p01);}
};

App.prototype.bss093SetWarpMode=async function(key,mode){
  const scene=this.bss088SceneFromState(),d=scene&&scene.kind==="custom"&&scene.data&&scene.data[key];if(!d||typeof d!=="object")return;mode=S(mode||"off");this.bss089HistoryCheckpoint("Cambiar deformación");
  if(mode==="off"){delete d.warp;if(S(this.ebdx093WarpEditKey)===S(key))this.ebdx093WarpEditKey="";this.saveSoon();this.bss089RefreshSelectionPanels();this.bss089RedrawPreview();return;}
  let cols=2,rows=2;if(/^mesh[3-5]$/.test(mode)){cols=rows=N(mode.slice(-1),3);}const old=this.bss093WarpConfig(d),im=await this.bss083LoadImage(this.bss083EBDXAssetPath("elements",d.bitmap));if(!im)return;const points=old?this.bss093ResampleWarp(old,cols,rows):this.bss093DefaultWarpPoints(d,im,cols,rows);d.warp={enabled:true,mode:cols===2&&rows===2?"quad":"mesh",cols,rows,quality:old?old.quality:3,points};this.bss093DisableWarpConflicts(d);this.ebdx093WarpEditKey=key;this.saveSoon();this.bss089RefreshSelectionPanels();this.bss089RedrawPreview();
};
App.prototype.bss093ResetWarp=async function(key){
  const scene=this.bss088SceneFromState(),d=scene&&scene.kind==="custom"&&scene.data&&scene.data[key],cfg=this.bss093WarpConfig(d);if(!d||!cfg)return;const im=await this.bss083LoadImage(this.bss083EBDXAssetPath("elements",d.bitmap));if(!im)return;this.bss089HistoryCheckpoint("Reconstruir malla");d.warp.points=this.bss093DefaultWarpPoints(d,im,cfg.cols,cfg.rows);this.saveSoon();this.bss089RefreshSelectionPanels();this.bss089RedrawPreview();
};
App.prototype.bss093WarpPreset=async function(key,preset){
  const scene=this.bss088SceneFromState(),d=scene&&scene.kind==="custom"&&scene.data&&scene.data[key];if(!d)return;let cfg=this.bss093WarpConfig(d);if(!cfg){await this.bss093SetWarpMode(key,"mesh3");cfg=this.bss093WarpConfig(d);}if(!cfg)return;
  if((preset==="curve_up"||preset==="curve_down"||preset==="wave")&&cfg.cols<3){const old=cfg;d.warp.cols=3;d.warp.rows=3;d.warp.mode="mesh";d.warp.points=this.bss093ResampleWarp(old,3,3);cfg=this.bss093WarpConfig(d);}
  this.bss089HistoryCheckpoint("Preset de deformación");const xs=cfg.points.map(p=>p[0]),ys=cfg.points.map(p=>p[1]),minX=Math.min(...xs),maxX=Math.max(...xs),minY=Math.min(...ys),maxY=Math.max(...ys),w=Math.max(1,maxX-minX),h=Math.max(1,maxY-minY),cy=(minY+maxY)/2,pts=cfg.points.map(p=>p.slice());
  if(preset==="curve_up"||preset==="curve_down"){const sign=preset==="curve_up"?-1:1;for(let j=0;j<cfg.rows;j++)for(let i=0;i<cfg.cols;i++){const k=j*cfg.cols+i,u=i/(cfg.cols-1);pts[k][1]+=sign*h*0.18*Math.sin(Math.PI*u);}}
  else if(preset==="wave"){for(let j=0;j<cfg.rows;j++)for(let i=0;i<cfg.cols;i++){const k=j*cfg.cols+i,u=i/(cfg.cols-1);pts[k][1]+=h*0.12*Math.sin(Math.PI*2*u);}}
  else if(preset==="persp_left"||preset==="persp_right"){for(let j=0;j<cfg.rows;j++)for(let i=0;i<cfg.cols;i++){const k=j*cfg.cols+i,u=i/(cfg.cols-1),factor=preset==="persp_left"?(0.62+0.38*u):(1-0.38*u);pts[k][1]=cy+(pts[k][1]-cy)*factor;}}
  else if(preset==="soften"&&cfg.cols>2&&cfg.rows>2){const src=pts.map(p=>p.slice());for(let j=1;j<cfg.rows-1;j++)for(let i=1;i<cfg.cols-1;i++){const k=j*cfg.cols+i,n=[src[k],src[k-1],src[k+1],src[k-cfg.cols],src[k+cfg.cols]];pts[k][0]=n.reduce((a,p)=>a+p[0],0)/n.length;pts[k][1]=n.reduce((a,p)=>a+p[1],0)/n.length;}}
  d.warp.points=pts;this.ebdx093WarpEditKey=key;this.saveSoon();this.bss089RefreshSelectionPanels();this.bss089RedrawPreview();
};

App.prototype.bss093WarpPanelHTML=function(scene,t){
  if(!t||t.type!=="img")return "";const key=this.bss092TargetId(t),d=t.data,ro=scene.kind!=="custom",dis=ro?"disabled":"",cfg=this.bss093WarpConfig(d),mode=!cfg?"off":(cfg.cols===2&&cfg.rows===2?"quad":"mesh"+cfg.cols),editing=cfg&&S(this.ebdx093WarpEditKey)===S(key);
  return `<section class="bss088-inspector-section bss093-warp-panel"><div class="bss088-section-title"><div><b>Deformación y curvatura</b><small>Dobla la imagen directamente con esquinas o una malla de puntos. Se guarda en el JSON y se reproduce ingame.</small></div>${cfg?`<span class="bss093-warp-badge">${cfg.cols}×${cfg.rows}</span>`:""}</div><label class="bss-mini-field"><span>Tipo de deformación</span><select class="bss-select" data-bss093-warp-mode="${E(key)}" ${dis}><option value="off" ${mode==="off"?"selected":""}>Sin deformación</option><option value="quad" ${mode==="quad"?"selected":""}>4 esquinas · perspectiva</option><option value="mesh3" ${mode==="mesh3"?"selected":""}>Malla 3×3 · curva simple</option><option value="mesh4" ${mode==="mesh4"?"selected":""}>Malla 4×4 · curva precisa</option><option value="mesh5" ${mode==="mesh5"?"selected":""}>Malla 5×5 · máxima libertad</option></select></label>${cfg?`<div class="bss093-warp-actions"><button class="bss-btn ${editing?"primary":""}" type="button" data-bss093-warp-action="edit" data-bss093-warp-key="${E(key)}" ${dis}>${editing?"◆ Editando puntos":"◇ Editar puntos"}</button><button class="bss-btn" type="button" data-bss093-warp-action="reset" data-bss093-warp-key="${E(key)}" ${dis}>Rehacer desde transform</button></div><div class="bss093-warp-presets"><button type="button" data-bss093-warp-preset="curve_up" data-bss093-warp-key="${E(key)}" ${dis}>Curva ↑</button><button type="button" data-bss093-warp-preset="curve_down" data-bss093-warp-key="${E(key)}" ${dis}>Curva ↓</button><button type="button" data-bss093-warp-preset="wave" data-bss093-warp-key="${E(key)}" ${dis}>Onda</button><button type="button" data-bss093-warp-preset="persp_left" data-bss093-warp-key="${E(key)}" ${dis}>Persp. ←</button><button type="button" data-bss093-warp-preset="persp_right" data-bss093-warp-key="${E(key)}" ${dis}>Persp. →</button><button type="button" data-bss093-warp-preset="soften" data-bss093-warp-key="${E(key)}" ${dis}>Suavizar</button></div><label class="bss-mini-field"><span>Calidad ingame</span><select class="bss-select" data-bss093-warp-quality="${E(key)}" ${dis}>${[[1,"Baja"],[2,"Media"],[3,"Alta"],[4,"Muy alta"],[5,"Ultra"],[6,"Preview parity"]].map(([n,l])=>`<option value="${n}" ${cfg.quality===n?"selected":""}>${l} · subdivisión ${n}×</option>`).join("")}</select><small>Más calidad = más micro-segmentos en runtime.</small></label><p class="bss093-warp-help">Activa <b>Editar puntos</b> y arrastra los nodos del canvas. Shift = 1 px. Cambiar de 3×3 a 4×4/5×5 conserva la forma actual. La deformación usa geometría estática, por eso desactiva Loop/Spritesheet/Efecto de esa misma capa.</p>`:"<p class=\"bss093-warp-help\">Usa 4 esquinas para perspectiva. Usa 3×3 o más cuando quieras tirar del centro y crear una curva real.</p>"}</section>`;
};

const _bss093InspectorBase=App.prototype.bss088LayerInspectorHTML;
App.prototype.bss088LayerInspectorHTML=function(scene){const html=_bss093InspectorBase.call(this,scene),t=this.bss088SelectedTarget(scene);if(!t||t.type!=="img")return html;const panel=this.bss093WarpPanelHTML(scene,t),i=html.lastIndexOf("</div>");return i>=0?html.slice(0,i)+panel+html.slice(i):html+panel;};

const _bss093QuickBase=App.prototype.bss092QuickBarHTML;
App.prototype.bss092QuickBarHTML=function(scene){let html=_bss093QuickBase.call(this,scene),t=this.bss088SelectedTarget(scene);if(!t||t.type!=="img"||scene.kind!=="custom")return html;const key=this.bss092TargetId(t),on=!!this.bss093WarpConfig(t.data),editing=on&&S(this.ebdx093WarpEditKey)===S(key),button=`<button class="bss093-warp-quick ${on?"active":""} ${editing?"editing":""}" type="button" data-bss093-warp-toggle="${E(key)}" title="${on?"Editar/dejar de editar puntos":"Activar malla 3×3"}">${on?(editing?"◆ Curvando":"◇ Deformar"):"◇ Deformar"}</button>`,i=html.lastIndexOf("</div>");return i>=0?html.slice(0,i)+button+html.slice(i):html+button;};

const _bss093HitBase=App.prototype.bss092HitAreas;
App.prototype.bss092HitAreas=async function(view){const out=await _bss093HitBase.call(this,view),data=view&&view.data||{};for(const a of out){if(a.kind!=="img")continue;const d=data[a.key],pts=this.bss093WarpActualPoints(d);if(!pts.length)continue;const xs=pts.map(p=>p[0]),ys=pts.map(p=>p[1]);a.x=N(d.x,0);a.y=N(d.y,0);a.x0=Math.min(...xs);a.x1=Math.max(...xs);a.y0=Math.min(...ys);a.y1=Math.max(...ys);}return out;};

const _bss093CompositeBase=App.prototype.bss083EBDXComposite;
App.prototype.bss083EBDXComposite=async function(canvas,view){const state=await _bss093CompositeBase.call(this,canvas,view);if(!state||!canvas||!view||view.kind!=="custom")return state;try{const key=S(this.ebdx088SelectedLayer),d=view.data&&view.data[key],cfg=this.bss093WarpConfig(d);state.warpHandles=[];if(cfg){const ctx=canvas.getContext("2d"),pts=cfg.points.map((p,i)=>{const q=this.bss093WarpAuthorPoint(d,p);return {key,index:i,row:Math.floor(i/cfg.cols),col:i%cfg.cols,x:q[0],y:q[1]};});state.warpHandles=pts;if(canvas.closest&&canvas.closest(".bss092-main-preview")){ctx.save();ctx.lineWidth=1;ctx.strokeStyle="rgba(108,194,255,.74)";ctx.setLineDash(S(this.ebdx093WarpEditKey)===key?[]:[4,3]);for(let r=0;r<cfg.rows;r++){ctx.beginPath();for(let c=0;c<cfg.cols;c++){const p=pts[r*cfg.cols+c];c?ctx.lineTo(p.x,p.y):ctx.moveTo(p.x,p.y);}ctx.stroke();}for(let c=0;c<cfg.cols;c++){ctx.beginPath();for(let r=0;r<cfg.rows;r++){const p=pts[r*cfg.cols+c];r?ctx.lineTo(p.x,p.y):ctx.moveTo(p.x,p.y);}ctx.stroke();}ctx.setLineDash([]);if(S(this.ebdx093WarpEditKey)===key){for(const p of pts){ctx.beginPath();ctx.fillStyle=(p.row===0||p.row===cfg.rows-1)&&(p.col===0||p.col===cfg.cols-1)?"#ffcf6d":"#69b2ff";ctx.strokeStyle="rgba(8,16,26,.95)";ctx.arc(p.x,p.y,4.5,0,Math.PI*2);ctx.fill();ctx.stroke();}}ctx.restore();}}}catch(_){}return state;};

// Final preview input authority. No pointer capture: all drags use temporary
// window listeners, so DOM rerenders cannot trigger InvalidStateError.
const _bss093HydrateFallback=App.prototype.hydrateEBDXStudioPreview;
App.prototype.hydrateEBDXStudioPreview=async function(){
  if(!(this.screen==="ebdx"&&S(this.ebdxStudioTab||"backgrounds")==="backgrounds")||!this.body||!this.body.querySelector(".bss092-composer"))return _bss093HydrateFallback.call(this);
  const el=this.body.querySelector("[data-ebdx-preview]"),view=this.ebdxStudioView();if(!el||!view)return;el.innerHTML='<canvas class="bss-ebdx-preview-canvas" width="384" height="308"></canvas>';const canvas=el.querySelector("canvas");if(!canvas)return;let currentState=await this.bss083EBDXComposite(canvas,view);if(!canvas.isConnected||view.kind!=="custom")return;
  const self=this;let drag=null,dragMoved=false,rendering=false,dirty=false;function point(ev){const r=canvas.getBoundingClientRect();return {x:(ev.clientX-r.left)*384/Math.max(1,r.width),y:(ev.clientY-r.top)*308/Math.max(1,r.height)};}function hitsAt(p){return (currentState&&currentState.hitAreas||[]).filter(a=>p.x>=a.x0&&p.x<=a.x1&&p.y>=a.y0&&p.y<=a.y1);}async function drawQueued(){if(rendering){dirty=true;return;}rendering=true;do{dirty=false;currentState=await self.bss083EBDXComposite(canvas,view);}while(dirty&&canvas.isConnected);rendering=false;}function queueDraw(){dirty=true;if(!rendering)requestAnimationFrame(()=>drawQueued());}
  function move(ev){if(!drag)return;const p=point(ev);if(drag.kind==="warp"){const row=view.data&&view.data[drag.key],cfg=self.bss093WarpConfig(row);if(!row||!cfg||!row.warp||!Array.isArray(row.warp.points))return;const px=ev.shiftKey?Math.round(p.x):self.bss072Snap(p.x),py=ev.shiftKey?Math.round(p.y):self.bss072Snap(p.y);row.warp.points[drag.index]=self.bss093WarpLocalFromAuthor(row,px,py);dragMoved=true;self.saveSoon();queueDraw();ev.preventDefault();return;}const rawX=Math.max(-192,Math.min(576,p.x+drag.offX)),rawY=Math.max(-154,Math.min(462,p.y+drag.offY)),nx=ev.shiftKey?Math.round(rawX):self.bss072Snap(rawX),ny=ev.shiftKey?Math.round(rawY):self.bss072Snap(rawY);if(drag.kind==="img"){const row=view.data&&view.data[drag.key];if(!row)return;row.x=nx;row.y=ny;}else{const g=view.data&&view.data[drag.key];if(!g)return;self.bss088SetGroupValue(g,"x",drag.index,nx);self.bss088SetGroupValue(g,"y",drag.index,ny);}drag.x=nx;drag.y=ny;dragMoved=true;self.saveSoon();self.bss092SyncQuickBarValues();queueDraw();ev.preventDefault();}
  function finish(){if(!drag)return;const wasWarp=drag.kind==="warp";drag=null;window.removeEventListener("pointermove",move);window.removeEventListener("pointerup",finish);window.removeEventListener("pointercancel",finish);if(dragMoved&&!wasWarp)self.bss089RefreshSelectionPanels();if(dragMoved)queueDraw();self.bss089UpdateHistoryButtons();}
  canvas.addEventListener("pointerdown",function(ev){const p=point(ev),selected=S(self.ebdx088SelectedLayer);if(S(self.ebdx093WarpEditKey)===selected){let wh=null,bd=1e9;for(const h of currentState&&currentState.warpHandles||[]){const dist=Math.hypot(h.x-p.x,h.y-p.y);if(dist<bd){bd=dist;wh=h;}}if(wh&&bd<=12){self.bss089HistoryCheckpoint("Deformar "+selected);drag={kind:"warp",key:selected,index:wh.index};dragMoved=false;window.addEventListener("pointermove",move,{passive:false});window.addEventListener("pointerup",finish);window.addEventListener("pointercancel",finish);ev.preventDefault();return;}}
    const hits=hitsAt(p);let hit=null,si=hits.findIndex(a=>a.id===selected);if(ev.altKey&&hits.length)hit=hits[(si>=0?si+1:0)%hits.length];else hit=hits.find(a=>a.id===selected)||hits[0]||null;if(!hit){let best=null,bestD=9999;for(const h of currentState&&currentState.handles||[]){const dist=Math.hypot(h.x-p.x,h.y-p.y);if(dist<bestD){bestD=dist;best=h;}}if(bestD<=18)hit=Object.assign({id:best.kind==="img"?best.key:`group:${best.key}:${best.index}`},best);}if(!hit)return;self.ebdx088SelectedLayer=hit.id;self._bss089EditKey="";self.bss089HistoryCheckpoint("Mover "+hit.id);self.bss089RefreshSelectionPanels();drag=Object.assign({},hit,{offX:N(hit.x,0)-p.x,offY:N(hit.y,0)-p.y});dragMoved=false;window.addEventListener("pointermove",move,{passive:false});window.addEventListener("pointerup",finish);window.addEventListener("pointercancel",finish);queueDraw();ev.preventDefault();
  });
};

const _bss093ClickBase=App.prototype.onClick;
App.prototype.onClick=function(e){const raw=e&&e.target,t=raw&&typeof raw.closest==="function"?raw.closest("[data-bss093-warp-action],[data-bss093-warp-preset],[data-bss093-warp-toggle]"):null;if(this.screen==="ebdx"&&S(this.ebdxStudioTab||"backgrounds")==="backgrounds"&&t&&t.dataset){const key=S(t.dataset.bss093WarpKey||t.dataset.bss093WarpToggle);if(t.dataset.bss093WarpToggle!=null){const scene=this.bss088SceneFromState(),d=scene&&scene.data&&scene.data[key];if(this.bss093WarpConfig(d)){this.ebdx093WarpEditKey=S(this.ebdx093WarpEditKey)===key?"":key;this.bss089RefreshSelectionPanels();this.bss089RedrawPreview();}else this.bss093SetWarpMode(key,"mesh3");return;}if(t.dataset.bss093WarpAction==="edit"){this.ebdx093WarpEditKey=S(this.ebdx093WarpEditKey)===key?"":key;this.bss089RefreshSelectionPanels();this.bss089RedrawPreview();return;}if(t.dataset.bss093WarpAction==="reset"){this.bss093ResetWarp(key);return;}if(t.dataset.bss093WarpPreset!=null){this.bss093WarpPreset(key,S(t.dataset.bss093WarpPreset));return;}}return _bss093ClickBase.call(this,e);};

const _bss093InputBase=App.prototype.onInput;
App.prototype.onInput=function(e){const t=e&&e.target;if(this.screen==="ebdx"&&S(this.ebdxStudioTab||"backgrounds")==="backgrounds"&&t&&t.dataset){if(t.dataset.bss093WarpMode!=null){this.bss093SetWarpMode(S(t.dataset.bss093WarpMode),S(t.value));return;}if(t.dataset.bss093WarpQuality!=null){const key=S(t.dataset.bss093WarpQuality),scene=this.bss088SceneFromState(),d=scene&&scene.kind==="custom"&&scene.data&&scene.data[key],cfg=this.bss093WarpConfig(d);if(d&&cfg){this.bss089HistoryCheckpoint("Calidad de deformación");d.warp.quality=Math.max(1,Math.min(6,Math.round(N(t.value,4))));this.saveSoon();this.bss089RedrawPreview();}return;}}return _bss093InputBase.call(this,e);};

// Deformation and sprite-motion are two geometry authorities. If the user
// explicitly chooses a moving EBDX behavior, that action wins and releases the
// mesh instead of leaving a visually contradictory half-enabled state.
const _bss093BehaviorBase=App.prototype.bss088ApplyBehavior;
App.prototype.bss088ApplyBehavior=function(x,id){if(x&&this.bss093WarpConfig(x)&&S(id)!=="static"){delete x.warp;this.ebdx093WarpEditKey="";}return _bss093BehaviorBase.call(this,x,id);};

// ============================================================================
// BSS v0.8.14 - Preview/runtime parity + comfortable deformation toolkit
// Adds region/row/column/edge/whole-image manipulation without hiding the
// point-level mesh, and keeps the editor's current backdrop key compatible with
// the runtime key used by older builds.
// ============================================================================
App.prototype.ebdx094WarpTool="point";
App.prototype.ebdx094WarpRadius=72;
App.prototype.ebdx094WarpStrength=1;

App.prototype.bss094WarpTool=function(){
  const v=S(this.ebdx094WarpTool||"point");
  return ["move","point","soft","row","column","edge","mesh_all"].includes(v)?v:"point";
};
App.prototype.bss094WarpRadiusValue=function(){return Math.max(12,Math.min(320,N(this.ebdx094WarpRadius,72)));};
App.prototype.bss094WarpStrengthValue=function(){return Math.max(.1,Math.min(2,N(this.ebdx094WarpStrength,1)));};
App.prototype.bss094LocalDelta=function(d,dx,dy){
  const x=N(d&&d.x,0),y=N(d&&d.y,0),a=this.bss093WarpLocalFromAuthor(d,x,y),b=this.bss093WarpLocalFromAuthor(d,x+N(dx,0),y+N(dy,0));
  return [b[0]-a[0],b[1]-a[1]];
};
App.prototype.bss094NearestWarpHandle=function(handles,p,maxDist=14){
  let best=null,dist=Infinity;for(const h of A(handles)){const d=Math.hypot(N(h.x)-N(p.x),N(h.y)-N(p.y));if(d<dist){dist=d;best=h;}}
  return best&&dist<=maxDist?Object.assign({distance:dist},best):null;
};
App.prototype.bss094SelectedWarpHit=function(state,key,p){
  return A(state&&state.hitAreas).find(a=>S(a.id)===S(key)&&p.x>=a.x0&&p.x<=a.x1&&p.y>=a.y0&&p.y<=a.y1)||null;
};
App.prototype.bss094EdgeIndexes=function(cfg,handle,p,hit){
  if(!cfg)return [];
  let edge="top";
  if(hit){const ds={left:Math.abs(p.x-hit.x0),right:Math.abs(hit.x1-p.x),top:Math.abs(p.y-hit.y0),bottom:Math.abs(hit.y1-p.y)};edge=Object.entries(ds).sort((a,b)=>a[1]-b[1])[0][0];}
  else if(handle){if(handle.row===0)edge="top";else if(handle.row===cfg.rows-1)edge="bottom";else if(handle.col===0)edge="left";else edge="right";}
  const out=[];for(let r=0;r<cfg.rows;r++)for(let c=0;c<cfg.cols;c++){if((edge==="top"&&r===0)||(edge==="bottom"&&r===cfg.rows-1)||(edge==="left"&&c===0)||(edge==="right"&&c===cfg.cols-1))out.push(r*cfg.cols+c);}return out;
};

const _bss094PresetBase=App.prototype.bss093WarpPreset;
App.prototype.bss093WarpPreset=async function(key,preset){
  const old=["curve_up","curve_down","wave","persp_left","persp_right","soften"];
  if(old.includes(S(preset)))return _bss094PresetBase.call(this,key,preset);
  const scene=this.bss088SceneFromState(),d=scene&&scene.kind==="custom"&&scene.data&&scene.data[key];if(!d)return;
  let cfg=this.bss093WarpConfig(d);if(!cfg){await this.bss093SetWarpMode(key,"mesh3");cfg=this.bss093WarpConfig(d);}if(!cfg)return;
  const need5=["bulge","pinch"].includes(S(preset)),need3=["curve_left","curve_right","s_vertical","top_arc","bottom_arc","fan_top","fan_bottom"].includes(S(preset));
  const want=need5?5:(need3&&cfg.cols<3?3:cfg.cols);
  if(want!==cfg.cols||want!==cfg.rows){const prev=cfg;d.warp.cols=want;d.warp.rows=want;d.warp.mode=want===2?"quad":"mesh";d.warp.points=this.bss093ResampleWarp(prev,want,want);cfg=this.bss093WarpConfig(d);}
  this.bss089HistoryCheckpoint("Preset de deformación");
  const pts=cfg.points.map(p=>p.slice()),xs=pts.map(p=>p[0]),ys=pts.map(p=>p[1]),minX=Math.min(...xs),maxX=Math.max(...xs),minY=Math.min(...ys),maxY=Math.max(...ys),w=Math.max(1,maxX-minX),h=Math.max(1,maxY-minY),cx=(minX+maxX)/2,cy=(minY+maxY)/2,p=S(preset);
  for(let r=0;r<cfg.rows;r++)for(let c=0;c<cfg.cols;c++){
    const i=r*cfg.cols+c,u=c/(cfg.cols-1),v=r/(cfg.rows-1),x=pts[i][0],y=pts[i][1];
    if(p==="curve_left")pts[i][0]-=w*.18*Math.sin(Math.PI*v);
    else if(p==="curve_right")pts[i][0]+=w*.18*Math.sin(Math.PI*v);
    else if(p==="s_vertical")pts[i][0]+=w*.12*Math.sin(Math.PI*2*v);
    else if(p==="top_arc"&&r===0)pts[i][1]-=h*.20*Math.sin(Math.PI*u);
    else if(p==="bottom_arc"&&r===cfg.rows-1)pts[i][1]+=h*.20*Math.sin(Math.PI*u);
    else if(p==="fan_top"){const f=.62+.38*v;pts[i][0]=cx+(x-cx)*f;}
    else if(p==="fan_bottom"){const f=1-.38*v;pts[i][0]=cx+(x-cx)*f;}
    else if(p==="bulge"||p==="pinch"){
      const nx=(x-cx)/(w*.5),ny=(y-cy)/(h*.5),rr=Math.min(1,Math.sqrt(nx*nx+ny*ny)),amount=(p==="bulge" ? .28 : -.24)*(1-rr)*(1-rr),f=1+amount;
      pts[i][0]=cx+(x-cx)*f;pts[i][1]=cy+(y-cy)*f;
    }
  }
  d.warp.points=pts;this.ebdx093WarpEditKey=key;this.saveSoon();this.bss089RefreshSelectionPanels();this.bss089RedrawPreview();
};

App.prototype.bss093WarpPanelHTML=function(scene,t){
  if(!t||t.type!=="img")return "";
  const key=this.bss092TargetId(t),d=t.data,ro=scene.kind!=="custom",dis=ro?"disabled":"",cfg=this.bss093WarpConfig(d),mode=!cfg?"off":(cfg.cols===2&&cfg.rows===2?"quad":"mesh"+cfg.cols),editing=cfg&&S(this.ebdx093WarpEditKey)===S(key),tool=this.bss094WarpTool(),radius=this.bss094WarpRadiusValue(),strength=this.bss094WarpStrengthValue();
  const toolOptions=[
    ["move","Mover imagen completa · X/Y"],["point","Punto individual"],["soft","Deformación suave · radio"],["row","Fila completa"],["column","Columna completa"],["edge","Borde completo"],["mesh_all","Toda la malla"]
  ].map(([v,l])=>`<option value="${v}" ${tool===v?"selected":""}>${l}</option>`).join("");
  const presetButtons=[
    ["curve_up","Curva ↑"],["curve_down","Curva ↓"],["curve_left","Curva ←"],["curve_right","Curva →"],["wave","Onda H"],["s_vertical","Onda V"],
    ["top_arc","Arco superior"],["bottom_arc","Arco inferior"],["bulge","Abombar"],["pinch","Hundir"],["fan_top","Persp. suelo"],["fan_bottom","Persp. techo"],
    ["persp_left","Persp. ←"],["persp_right","Persp. →"],["soften","Suavizar"]
  ].map(([v,l])=>`<button type="button" data-bss093-warp-preset="${v}" data-bss093-warp-key="${E(key)}" ${dis}>${l}</button>`).join("");
  return `<section class="bss088-inspector-section bss093-warp-panel"><div class="bss088-section-title"><div><b>Deformación y curvatura</b><small>Perspectiva, malla, bordes, filas/columnas y deformación suave por zona. El mismo JSON alimenta preview y runtime.</small></div>${cfg?`<span class="bss093-warp-badge">${cfg.cols}×${cfg.rows}</span>`:""}</div><label class="bss-mini-field"><span>Resolución de control</span><select class="bss-select" data-bss093-warp-mode="${E(key)}" ${dis}><option value="off" ${mode==="off"?"selected":""}>Sin deformación</option><option value="quad" ${mode==="quad"?"selected":""}>2×2 · 4 esquinas</option><option value="mesh3" ${mode==="mesh3"?"selected":""}>3×3 · curva simple</option><option value="mesh4" ${mode==="mesh4"?"selected":""}>4×4 · precisa</option><option value="mesh5" ${mode==="mesh5"?"selected":""}>5×5 · localizada</option></select></label>${cfg?`<div class="bss093-warp-actions"><button class="bss-btn ${editing?"primary":""}" type="button" data-bss093-warp-action="edit" data-bss093-warp-key="${E(key)}" ${dis}>${editing?"◆ Deformación activa":"◇ Editar deformación"}</button><button class="bss-btn" type="button" data-bss093-warp-action="reset" data-bss093-warp-key="${E(key)}" ${dis}>Reset malla</button></div><label class="bss-mini-field"><span>Qué arrastras</span><select class="bss-select" data-bss094-warp-tool>${toolOptions}</select><small>${tool==="soft"?"Arrastra en cualquier punto de la imagen: los nodos cercanos siguen el cursor según el radio.":tool==="move"?"Arrastra cualquier zona de la imagen y mueve X/Y sin alterar la curvatura.":tool==="edge"?"Arrastra cerca del borde que quieras desplazar completo.":"Elige cuánto de la malla debe responder a un solo arrastre."}</small></label><div class="bss-mini-grid"><label class="bss-mini-field"><span>Radio suave · ${Math.round(radius)} px</span><input type="range" min="12" max="320" step="4" value="${radius}" data-bss094-warp-radius ${tool==="soft"?"":"disabled"}></label><label class="bss-mini-field"><span>Fuerza · ${Math.round(strength*100)}%</span><input type="range" min="10" max="200" step="5" value="${Math.round(strength*100)}" data-bss094-warp-strength ${tool==="soft"?"":"disabled"}></label></div><div class="bss093-warp-presets">${presetButtons}</div><label class="bss-mini-field"><span>Calidad ingame</span><select class="bss-select" data-bss093-warp-quality="${E(key)}" ${dis}>${[[1,"Baja"],[2,"Media"],[3,"Alta"],[4,"Muy alta"],[5,"Ultra"],[6,"Preview parity"]].map(([n,l])=>`<option value="${n}" ${cfg.quality===n?"selected":""}>${l} · subdivisión ${n}×</option>`).join("")}</select><small>v0.8.15 permite una malla runtime más densa y la actualiza después de la transformación final EBDX.</small></label><p class="bss093-warp-help"><b>Punto</b> = un nodo. <b>Suave</b> = una zona orgánica. <b>Fila/Columna/Borde</b> = mueve conjuntos. <b>Toda la malla</b> = desplaza los puntos juntos. <b>Mover imagen</b> = cambia X/Y conservando la forma. Shift redondea a 1 px.</p>`:`<p class="bss093-warp-help">Activa 2×2 para perspectiva o 3×3–5×5 para curvatura localizada.</p>`}</section>`;
};

// The v0.8.13 canvas renderer and runtime used the same quality number but a
// 144-cell cap effectively collapsed some "Máxima" meshes. Match the new 256
// cell runtime ceiling in the editor as well.
const _bss094DrawWarpedBase=App.prototype.bss093DrawWarped;
App.prototype.bss093DrawWarped=function(ctx,img,d){
  const cfg=this.bss093WarpConfig(d);if(!cfg||!img)return _bss094DrawWarpedBase.call(this,ctx,img,d);
  let q=cfg.quality,segX=(cfg.cols-1)*q,segY=(cfg.rows-1)*q;while(segX*segY>256&&q>1){q--;segX=(cfg.cols-1)*q;segY=(cfg.rows-1)*q;}
  const dest=(u,v)=>this.bss093WarpAuthorPoint(d,this.bss093WarpSample(cfg,u,v)),src=(u,v)=>[u*img.width,v*img.height];
  for(let iy=0;iy<segY;iy++)for(let ix=0;ix<segX;ix++){const u0=ix/segX,u1=(ix+1)/segX,v0=iy/segY,v1=(iy+1)/segY,s00=src(u0,v0),s10=src(u1,v0),s11=src(u1,v1),s01=src(u0,v1),p00=dest(u0,v0),p10=dest(u1,v0),p11=dest(u1,v1),p01=dest(u0,v1);this.bss093DrawTexturedTriangle(ctx,img,s00,s10,s11,p00,p10,p11);this.bss093DrawTexturedTriangle(ctx,img,s00,s11,s01,p00,p11,p01);}
};

// Final canvas input authority for v0.8.14. It deliberately avoids
// setPointerCapture because Maker Studio can rerender the canvas during a drag.
const _bss094HydrateFallback=App.prototype.hydrateEBDXStudioPreview;
App.prototype.hydrateEBDXStudioPreview=async function(){
  if(!(this.screen==="ebdx"&&S(this.ebdxStudioTab||"backgrounds")==="backgrounds")||!this.body||!this.body.querySelector(".bss092-composer"))return _bss094HydrateFallback.call(this);
  const el=this.body.querySelector("[data-ebdx-preview]"),view=this.ebdxStudioView();if(!el||!view)return;el.innerHTML='<canvas class="bss-ebdx-preview-canvas" width="384" height="308"></canvas>';const canvas=el.querySelector("canvas");if(!canvas)return;
  let currentState=await this.bss083EBDXComposite(canvas,view);if(!canvas.isConnected||view.kind!=="custom")return;
  const self=this;let drag=null,dragMoved=false,rendering=false,dirty=false;
  function point(ev){const r=canvas.getBoundingClientRect();return {x:(ev.clientX-r.left)*384/Math.max(1,r.width),y:(ev.clientY-r.top)*308/Math.max(1,r.height)};}
  function hitsAt(p){return A(currentState&&currentState.hitAreas).filter(a=>p.x>=a.x0&&p.x<=a.x1&&p.y>=a.y0&&p.y<=a.y1);}
  async function drawQueued(){if(rendering){dirty=true;return;}rendering=true;do{dirty=false;currentState=await self.bss083EBDXComposite(canvas,view);}while(dirty&&canvas.isConnected);rendering=false;}
  function queueDraw(){dirty=true;if(!rendering)requestAnimationFrame(()=>drawQueued());}
  function beginListeners(){window.addEventListener("pointermove",move,{passive:false});window.addEventListener("pointerup",finish);window.addEventListener("pointercancel",finish);}
  function localDelta(row,dx,dy){return self.bss094LocalDelta(row,dx,dy);}
  function warpMove(ev,p){
    const row=view.data&&view.data[drag.key],cfg=self.bss093WarpConfig(row);if(!row||!cfg||!row.warp||!Array.isArray(row.warp.points))return;
    let dx=p.x-drag.startPointer.x,dy=p.y-drag.startPointer.y;if(ev.shiftKey){dx=Math.round(dx);dy=Math.round(dy);}const strength=drag.tool==="soft"?self.bss094WarpStrengthValue():1;
    if(drag.tool==="move"){
      row.x=Math.max(-192,Math.min(576,drag.startX+dx));row.y=Math.max(-154,Math.min(462,drag.startY+dy));self.bss092SyncQuickBarValues();
    }else{
      const dl=localDelta(row,dx,dy),src=drag.startPoints,author=drag.startAuthorPoints,radius=self.bss094WarpRadiusValue(),affected=drag.affected||[];
      row.warp.points=src.map((pt,i)=>{
        let w=affected.includes(i)?1:0;
        if(drag.tool==="soft"){const ap=author[i],dist=Math.hypot(ap[0]-drag.center.x,ap[1]-drag.center.y),t=Math.max(0,1-dist/Math.max(1,radius));w=t*t*(3-2*t)*strength;}
        return [pt[0]+dl[0]*w,pt[1]+dl[1]*w];
      });
    }
    dragMoved=true;self.saveSoon();queueDraw();ev.preventDefault();
  }
  function move(ev){
    if(!drag)return;const p=point(ev);if(drag.kind==="warp"){warpMove(ev,p);return;}
    const rawX=Math.max(-192,Math.min(576,p.x+drag.offX)),rawY=Math.max(-154,Math.min(462,p.y+drag.offY)),nx=ev.shiftKey?Math.round(rawX):self.bss072Snap(rawX),ny=ev.shiftKey?Math.round(rawY):self.bss072Snap(rawY);
    if(drag.kind==="img"){const row=view.data&&view.data[drag.key];if(!row)return;row.x=nx;row.y=ny;}else{const g=view.data&&view.data[drag.key];if(!g)return;self.bss088SetGroupValue(g,"x",drag.index,nx);self.bss088SetGroupValue(g,"y",drag.index,ny);}dragMoved=true;self.saveSoon();self.bss092SyncQuickBarValues();queueDraw();ev.preventDefault();
  }
  function finish(){
    if(!drag)return;const wasWarp=drag.kind==="warp";drag=null;window.removeEventListener("pointermove",move);window.removeEventListener("pointerup",finish);window.removeEventListener("pointercancel",finish);if(dragMoved&&!wasWarp)self.bss089RefreshSelectionPanels();if(dragMoved)queueDraw();self.bss089UpdateHistoryButtons();
  }
  canvas.addEventListener("pointerdown",function(ev){
    const p=point(ev),selected=S(self.ebdx088SelectedLayer),editing=S(self.ebdx093WarpEditKey)===selected;
    if(editing){
      const row=view.data&&view.data[selected],cfg=self.bss093WarpConfig(row),tool=self.bss094WarpTool(),hit=self.bss094SelectedWarpHit(currentState,selected,p),handle=self.bss094NearestWarpHandle(currentState&&currentState.warpHandles,p,14);
      if(row&&cfg){
        let can=false,affected=[];
        if(tool==="move"||tool==="soft"||tool==="mesh_all")can=!!hit;
        else if(tool==="edge")can=!!hit;
        else can=!!handle;
        if(can){
          if(tool==="point"&&handle)affected=[handle.index];
          else if(tool==="row"&&handle)for(let c=0;c<cfg.cols;c++)affected.push(handle.row*cfg.cols+c);
          else if(tool==="column"&&handle)for(let r=0;r<cfg.rows;r++)affected.push(r*cfg.cols+handle.col);
          else if(tool==="edge")affected=self.bss094EdgeIndexes(cfg,handle,p,hit);
          else if(tool==="mesh_all")affected=cfg.points.map((_,i)=>i);
          else if(tool==="soft")affected=cfg.points.map((_,i)=>i);
          self.bss089HistoryCheckpoint((tool==="move"?"Mover":"Deformar")+" "+selected);
          drag={kind:"warp",tool,key:selected,index:handle&&handle.index,affected,startPointer:{x:p.x,y:p.y},center:{x:p.x,y:p.y},startPoints:row.warp.points.map(q=>[N(q&&q[0],0),N(q&&q[1],0)]),startAuthorPoints:cfg.points.map(q=>self.bss093WarpAuthorPoint(row,q)),startX:N(row.x,0),startY:N(row.y,0)};
          dragMoved=false;beginListeners();ev.preventDefault();return;
        }
      }
    }
    const hits=hitsAt(p);let hit=null,si=hits.findIndex(a=>a.id===selected);if(ev.altKey&&hits.length)hit=hits[(si>=0?si+1:0)%hits.length];else hit=hits.find(a=>a.id===selected)||hits[0]||null;
    if(!hit){let best=null,bestD=9999;for(const h of A(currentState&&currentState.handles)){const dist=Math.hypot(h.x-p.x,h.y-p.y);if(dist<bestD){bestD=dist;best=h;}}if(best&&bestD<=18)hit=Object.assign({id:best.kind==="img"?best.key:`group:${best.key}:${best.index}`},best);}
    if(!hit)return;self.ebdx088SelectedLayer=hit.id;self._bss089EditKey="";self.bss089HistoryCheckpoint("Mover "+hit.id);self.bss089RefreshSelectionPanels();drag=Object.assign({},hit,{offX:N(hit.x,0)-p.x,offY:N(hit.y,0)-p.y});dragMoved=false;beginListeners();queueDraw();ev.preventDefault();
  });
};

const _bss094InputBase=App.prototype.onInput;
App.prototype.onInput=function(e){
  const t=e&&e.target;
  if(t&&t.dataset){
    if(t.dataset.bss094WarpTool!=null){this.ebdx094WarpTool=S(t.value||"point");this.bss089RefreshSelectionPanels();this.bss089RedrawPreview();return;}
    if(t.dataset.bss094WarpRadius!=null){this.ebdx094WarpRadius=Math.max(12,Math.min(320,N(t.value,72)));const label=t.closest&&t.closest("label")&&t.closest("label").querySelector("span");if(label)label.textContent=`Radio suave · ${Math.round(this.ebdx094WarpRadius)} px`;return;}
    if(t.dataset.bss094WarpStrength!=null){this.ebdx094WarpStrength=Math.max(.1,Math.min(2,N(t.value,100)/100));const label=t.closest&&t.closest("label")&&t.closest("label").querySelector("span");if(label)label.textContent=`Fuerza · ${Math.round(this.ebdx094WarpStrength*100)}%`;return;}
    // Write both names so projects authored with v0.8.14 remain compatible with
    // older BSS runtimes while the current runtime reads the canonical key.
    if(S(t.dataset.studioGlobal)==="ebdxBackdrop"){this.studio.global=this.studio.global||{};this.studio.global.ebdxDefaultBackdrop=S(t.value);if(L(t.value)==="auto")this.studio.global.ebdxBackdropForceGlobal=false;}
  }
  return _bss094InputBase.call(this,e);
};

const BSS_EBDX_TEST_OVERRIDE_FILE = EBDX_DATA_DIR + "/test_override.json";
App.prototype.bss094QueueSceneTest=async function(scene){
  if(!scene)return false;
  try{
    // Persist only the authored scene itself. Never mutate global engine/camera/
    // backdrop settings just to test a composition.
    await this.save(true);
    if(this.bss076WriteEBDXFiles)await this.bss076WriteEBDXFiles();
    await this.ctx.fs.projectMkdir(EBDX_DATA_DIR);
    await this.ctx.fs.writeProjectFile(BSS_EBDX_TEST_OVERRIDE_FILE,JSON.stringify({
      format:"battle-scene-studio-ebdx-test",version:1,enabled:true,oneShot:true,
      scene:S(scene.id),sceneName:S(scene.name||scene.id),requestedAt:Date.now()
    },null,2));
    this._bss094QueuedTestScene=S(scene.id);
    this.toast(`Prueba preparada: ${scene.name} · solo el próximo combate`);
    this.bss089RefreshQuickBar&&this.bss089RefreshQuickBar();
    return true;
  }catch(err){
    this.toast("No se pudo preparar la prueba EBDX: "+S(err&&err.message||err),true);
    return false;
  }
};

const _bss094ClickBase=App.prototype.onClick;
App.prototype.onClick=function(e){
  const raw=e&&e.target,t=raw&&typeof raw.closest==="function"?raw.closest("[data-bss094-use-global-scene]"):null;
  if(t&&t.dataset&&this.screen==="ebdx"&&S(this.ebdxStudioTab||"backgrounds")==="backgrounds"){
    const scene=this.bss088SceneFromState();
    if(scene)this.bss094QueueSceneTest(scene);
    return;
  }
  return _bss094ClickBase.call(this,e);
};

// Preview/test is deliberately isolated from saved global configuration.
const _bss094BackgroundsHTMLBase=App.prototype.bss079BackgroundsHTML;
App.prototype.bss079BackgroundsHTML=function(){
  let html=_bss094BackgroundsHTMLBase.call(this),scene=this.bss088SceneFromState();if(!scene)return html;
  const queued=S(this._bss094QueuedTestScene)===S(scene.id);
  const button=`<button class="bss-btn ${queued?"primary":""}" type="button" data-bss094-use-global-scene title="No modifica Motor global, Cámara, Metadata ni Fondo global. El runtime consume esta prueba una sola vez.">${queued?"✓ Próximo combate · "+E(scene.name):"▶ Probar en el próximo combate"}</button>`;
  return html.replace('<div class="bss089-canvas-actions">','<div class="bss089-canvas-actions">'+button);
};

// ============================================================================
// BSS v0.8.15 - Runtime framing parity, readable vegetation, blur and real intro
// selection. The composer keeps a full logical authoring view, but defaults to
// the exact EBDX MAIN crop used by the 640x480 battle viewport.
// ============================================================================
App.prototype.ebdx095PreviewMode="game";

const BSS095_MAIN={x:102,y:408,angle:32,depth:342,scale:2.25,width:640,height:480};
App.prototype.bss095MainProjection=function(){
  const v=BSS095_MAIN,rad=v.angle*Math.PI/180,x2=v.x+Math.cos(rad)*v.depth,y2=v.y-Math.sin(rad)*v.depth,ox=x2/1.5-16,oy=y2/1.5+16,tx=x2-ox*v.scale,ty=y2-oy*v.scale;
  return {scale:v.scale,tx,ty,width:v.width,height:v.height,sx:(0-tx)/v.scale,sy:(0-ty)/v.scale,sw:v.width/v.scale,sh:v.height/v.scale};
};
App.prototype.bss095LogicalToGame=function(p){const q=this.bss095MainProjection();return {x:N(p&&p.x,0)*q.scale+q.tx,y:N(p&&p.y,0)*q.scale+q.ty};};
App.prototype.bss095PointerLogical=function(canvas,ev){const r=canvas.getBoundingClientRect(),game=S(this.ebdx095PreviewMode||"game")==="game"&&canvas.width===640;if(game){const sx=(ev.clientX-r.left)*640/Math.max(1,r.width),sy=(ev.clientY-r.top)*480/Math.max(1,r.height),q=this.bss095MainProjection();return {x:(sx-q.tx)/q.scale,y:(sy-q.ty)/q.scale};}return {x:(ev.clientX-r.left)*384/Math.max(1,r.width),y:(ev.clientY-r.top)*308/Math.max(1,r.height)};};

// Actual MAIN framing. Scene cards remain 384x308; only the working canvas uses
// the runtime crop. This makes water/background reach comparable before testing.
const _bss095CompositeBase=App.prototype.bss083EBDXComposite;
App.prototype.bss083EBDXComposite=async function(canvas,view){
  const main=!!(canvas&&canvas.closest&&canvas.closest(".bss092-main-preview")),game=main&&S(this.ebdx095PreviewMode||"game")==="game";
  if(!game)return _bss095CompositeBase.call(this,canvas,view);
  const off=document.createElement("canvas");off.width=384;off.height=308;
  const state=await _bss095CompositeBase.call(this,off,view);if(!state)return state;
  const q=this.bss095MainProjection();canvas.width=640;canvas.height=480;const ctx=canvas.getContext("2d");ctx.imageSmoothingEnabled=false;ctx.clearRect(0,0,640,480);ctx.drawImage(off,q.sx,q.sy,q.sw,q.sh,0,0,640,480);
  state.logicalCtx=state.ctx;state.ctx=ctx;state.previewProjection=q;
  // Redraw the selected box/grid after projection so controls remain crisp.
  try{
    const sel=S(this.ebdx088SelectedLayer),area=A(state.hitAreas).find(x=>x.id===sel),map=(x,y)=>({x:x*q.scale+q.tx,y:y*q.scale+q.ty});
    if(area){const a=map(area.x0,area.y0),b=map(area.x1,area.y1),c=map(area.x,area.y);ctx.save();ctx.strokeStyle="rgba(105,178,255,.98)";ctx.lineWidth=2;ctx.setLineDash([7,4]);ctx.strokeRect(a.x,a.y,b.x-a.x,b.y-a.y);ctx.setLineDash([]);ctx.fillStyle="rgba(10,18,28,.9)";ctx.strokeStyle="#fff";for(const p of [a,{x:b.x,y:a.y},b,{x:a.x,y:b.y}]){ctx.fillRect(p.x-4,p.y-4,8,8);ctx.strokeRect(p.x-4.5,p.y-4.5,9,9);}ctx.beginPath();ctx.arc(c.x,c.y,6,0,Math.PI*2);ctx.fill();ctx.stroke();ctx.restore();}
    const key=S(this.ebdx088SelectedLayer),d=view&&view.data&&view.data[key],cfg=this.bss093WarpConfig(d);state.warpHandles=[];
    if(cfg){state.warpHandles=cfg.points.map((p,i)=>{const l=this.bss093WarpAuthorPoint(d,p),g=map(l[0],l[1]);return {key,index:i,row:Math.floor(i/cfg.cols),col:i%cfg.cols,x:l[0],y:l[1],gameX:g.x,gameY:g.y};});if(S(this.ebdx093WarpEditKey)===key){ctx.save();ctx.strokeStyle="rgba(108,194,255,.9)";ctx.lineWidth=1.5;for(let r=0;r<cfg.rows;r++){ctx.beginPath();for(let c=0;c<cfg.cols;c++){const p=state.warpHandles[r*cfg.cols+c];c?ctx.lineTo(p.gameX,p.gameY):ctx.moveTo(p.gameX,p.gameY);}ctx.stroke();}for(let c=0;c<cfg.cols;c++){ctx.beginPath();for(let r=0;r<cfg.rows;r++){const p=state.warpHandles[r*cfg.cols+c];r?ctx.lineTo(p.gameX,p.gameY):ctx.moveTo(p.gameX,p.gameY);}ctx.stroke();}for(const p of state.warpHandles){ctx.beginPath();ctx.fillStyle=(p.row===0||p.row===cfg.rows-1)&&(p.col===0||p.col===cfg.cols-1)?"#ffcf6d":"#69b2ff";ctx.strokeStyle="#08101a";ctx.arc(p.gameX,p.gameY,5.5,0,Math.PI*2);ctx.fill();ctx.stroke();}ctx.restore();}}
  }catch(_){}
  return state;
};

// Preview toggle lives in the quick transform strip, not in another modal.
const _bss095QuickBase=App.prototype.bss092QuickBarHTML;
App.prototype.bss092QuickBarHTML=function(scene){let html=_bss095QuickBase.call(this,scene),game=S(this.ebdx095PreviewMode||"game")==="game",button=`<button class="bss095-preview-mode ${game?"active":""}" type="button" data-bss095-preview-mode title="${game?"Cambiar al lienzo lógico completo":"Cambiar al encuadre MAIN real de EBDX"}">${game?"▣ Vista juego · MAIN":"□ Lienzo 384×308"}</button>`,i=html.lastIndexOf("</div>");return i>=0?html.slice(0,i)+button+html.slice(i):html+button;};

// Layer blur + stronger, obvious deformation tools.
const _bss095InspectorBase=App.prototype.bss088LayerInspectorHTML;
App.prototype.bss088LayerInspectorHTML=function(scene){
  let html=_bss095InspectorBase.call(this,scene),t=this.bss088SelectedTarget(scene);if(!t||t.type!=="img")return html;const key=this.bss092TargetId(t),x=t.data,ro=scene.kind!=="custom",dis=ro?"disabled":"";
  const blur=`<section class="bss088-inspector-section bss095-blur"><div class="bss088-section-title"><div><b>Difuminado</b><small>Suaviza el elemento sin editar el PNG. Se reproduce también ingame.</small></div><span>${Math.round(N(x.blur,0))} px</span></div><input type="range" min="0" max="6" step="1" value="${Math.max(0,Math.min(6,N(x.blur,0)))}" data-bss095-blur="${E(key)}" ${dis}><div class="bss095-blur-presets"><button type="button" data-bss095-blur-set="0" data-bss095-blur-key="${E(key)}" ${dis}>Nítido</button><button type="button" data-bss095-blur-set="1" data-bss095-blur-key="${E(key)}" ${dis}>Suave</button><button type="button" data-bss095-blur-set="3" data-bss095-blur-key="${E(key)}" ${dis}>Niebla</button><button type="button" data-bss095-blur-set="6" data-bss095-blur-key="${E(key)}" ${dis}>Fondo</button></div></section>`;
  const marker='<section class="bss093-warp-panel';const at=html.indexOf(marker);return at>=0?html.slice(0,at)+blur+html.slice(at):html+blur;
};

// Make the existing deformation modes discoverable as direct tools and add a
// pair of high-level curve presets. No separate "advanced mode" is required.
const _bss095WarpPanelBase=App.prototype.bss093WarpPanelHTML;
App.prototype.bss093WarpPanelHTML=function(scene,t){let html=_bss095WarpPanelBase.call(this,scene,t);const cfg=this.bss093WarpConfig(t&&t.data);if(!cfg)return html;const tool=this.bss094WarpTool(),cards=`<div class="bss095-warp-toolcards">${[["move","Mover capa","Mueve X/Y sin tocar la forma"],["point","Punto","Un nodo exacto"],["soft","Zona suave","Curva una región alrededor del cursor"],["row","Fila","Dobla una franja horizontal"],["column","Columna","Dobla una franja vertical"],["edge","Borde","Tira de un lateral completo"],["mesh_all","Toda malla","Desplaza la deformación entera"]].map(([id,n,d])=>`<button type="button" class="${tool===id?"active":""}" data-bss095-warp-tool="${id}"><b>${n}</b><small>${d}</small></button>`).join("")}</div>`;const mark='<label class="bss-mini-field"><span>Qué arrastras</span>';const pos=html.indexOf(mark);if(pos>=0)html=html.slice(0,pos)+cards+html.slice(pos);return html;};

// Visual tree/grass picker. EBDX groups still share one bitmap, but the user can
// see what that bitmap is before choosing it.
App.prototype.bss095VegetationChoices=function(group){return group==="trees"?["tree","treeB","treeC","treePine","cluster"]:["tallGrass","seaWeed"];};
const _bss095GroupInspectorBase=App.prototype.bss088GroupInspectorHTML;
App.prototype.bss088GroupInspectorHTML=function(scene,t){let html=_bss095GroupInspectorBase.call(this,scene,t);if(!t)return html;const current=S(t.data&&t.data.bitmap||(t.group==="trees"?"tree":"tallGrass")),cards=`<div class="bss095-veg-picker">${this.bss095VegetationChoices(t.group).map(id=>`<button type="button" class="${current===id?"active":""}" data-bss095-veg="${E(t.group)}:${E(id)}"><span class="bss095-veg-thumb"><img data-bss095-veg-thumb="${E(id)}" alt=""></span><b>${E(id)}</b></button>`).join("")}</div>`;const mark='<label class="bss-mini-field"><span>Gráfico compartido</span>';const pos=html.indexOf(mark);return pos>=0?html.slice(0,pos)+cards+html.slice(pos):html+cards;};
App.prototype.bss095HydrateVegetation=async function(){if(!this.body)return;for(const im of [...this.body.querySelectorAll("img[data-bss095-veg-thumb]")]){try{const id=S(im.dataset.bss095VegThumb),url=await this.assetUrl(`Graphics/BattleSceneStudio/EBDX/Battlebacks/elements/${id}.png`);if(url)im.src=url;}catch(_){}}};

// Intro Studio: explicit Vanilla is a first-class engine choice. Other BSS
// styles no longer get swallowed by the standalone NDS authority at runtime.
const _bss095IntroStylesBase=App.prototype.bss079IntroStyles;
App.prototype.bss079IntroStyles=function(){const rows=_bss095IntroStylesBase.call(this).filter(x=>x[0]!=="vanilla");return [["vanilla","Vanilla Essentials","Usa exactamente la intro salvaje nativa de Essentials/tu base, sin Wild NDS/BSS."],...rows];};

// Camera profile that restores the moving Gen-5 battle flow from early BSS.
BSS087_CAMERA_PROFILES.classic_gen5={label:"Gen 5 Classic",note:"Cámara viva durante comandos, Fight, movimientos, sendout, SOS y fin de turno; BAS conserva autoridad completa cuando anima.",contexts:{command:{enabled:true,mode:"player",frames:46,strength:16},fight:{enabled:true,mode:"player",frames:38,strength:22},move:{enabled:true,mode:"focus",frames:30,strength:26},spread:{enabled:true,mode:"wide",frames:34,strength:22},common:{enabled:true,mode:"neutral",frames:32,strength:10},sendout:{enabled:true,mode:"focus",frames:34,strength:18},recall:{enabled:true,mode:"focus",frames:30,strength:16},sos:{enabled:true,mode:"wide",frames:38,strength:20},capture:{enabled:true,mode:"enemy",frames:34,strength:20},faint:{enabled:true,mode:"focus",frames:30,strength:18},turn_end:{enabled:true,mode:"neutral",frames:46,strength:8},idle:{enabled:true,mode:"drift",frames:0,strength:72},bas:{enabled:true,mode:"authored",frames:0,strength:100}}};
const _bss095EnsureBase=App.prototype.bss079EnsureEBDXConfig;
App.prototype.bss079EnsureEBDXConfig=function(){const g=_bss095EnsureBase.call(this),c=g.ebdxCamera||(g.ebdxCamera={}),ctx=c.contexts||{},keys=["command","fight","move","spread","common","sendout","recall","sos","capture","faint","turn_end"],legacy=keys.every(k=>!ctx[k]||ctx[k].enabled!==true&&N(ctx[k].strength,0)<=0);if(N(c.cameraSchemaVersion,0)<2&&(S(c.profile||c.preset||"source_faithful")==="source_faithful")&&legacy){c.profile="classic_gen5";c.preset="classic_gen5";c.contexts=JSON.parse(JSON.stringify(BSS087_CAMERA_PROFILES.classic_gen5.contexts));}c.cameraSchemaVersion=2;return g;};

// Unified final events.
const _bss095InputBase=App.prototype.onInput;
App.prototype.onInput=function(e){const t=e&&e.target;if(t&&t.dataset){if(t.dataset.bss095Blur!=null){const scene=this.bss088SceneFromState(),d=scene&&scene.kind==="custom"&&scene.data&&scene.data[S(t.dataset.bss095Blur)];if(d){this.bss089BeginFieldHistory&&this.bss089BeginFieldHistory("blur","input");d.blur=Math.max(0,Math.min(6,Math.round(N(t.value,0))));this.saveSoon();this.bss089RedrawPreview();this.bss089RefreshInspectorOnly();}return;}if(t.dataset.bss095WarpTool!=null){this.ebdx094WarpTool=S(t.dataset.bss095WarpTool);this.bss089RefreshSelectionPanels();this.bss089RedrawPreview();return;}}return _bss095InputBase.call(this,e);};
const _bss095ClickBase=App.prototype.onClick;
App.prototype.onClick=function(e){const raw=e&&e.target,t=raw&&typeof raw.closest==="function"?raw.closest("[data-bss095-preview-mode],[data-bss095-blur-set],[data-bss095-veg],[data-bss095-warp-tool]"):null;if(t&&t.dataset){if(t.dataset.bss095PreviewMode!=null){this.ebdx095PreviewMode=S(this.ebdx095PreviewMode||"game")==="game"?"author":"game";this.bss089RefreshQuickBar();this.hydrateEBDXStudioPreview();return;}if(t.dataset.bss095BlurSet!=null){const scene=this.bss088SceneFromState(),d=scene&&scene.kind==="custom"&&scene.data&&scene.data[S(t.dataset.bss095BlurKey)];if(d){this.bss089HistoryCheckpoint("Difuminado");d.blur=Math.max(0,Math.min(6,N(t.dataset.bss095BlurSet,0)));this.saveSoon();this.bss089RefreshSelectionPanels();this.bss089RedrawPreview();}return;}if(t.dataset.bss095Veg!=null){const [group,id]=S(t.dataset.bss095Veg).split(":"),r=this.bss089CurrentCustomRow(),g=r&&r.data&&r.data[group];if(g){this.bss089HistoryCheckpoint("Cambiar vegetación");g.bitmap=id;this.saveSoon();this.bss089RefreshSelectionPanels();this.bss089RedrawPreview();setTimeout(()=>this.bss095HydrateVegetation(),0);}return;}if(t.dataset.bss095WarpTool!=null){this.ebdx094WarpTool=S(t.dataset.bss095WarpTool);this.bss089RefreshSelectionPanels();this.bss089RedrawPreview();return;}}const out=_bss095ClickBase.call(this,e);setTimeout(()=>this.bss095HydrateVegetation(),0);return out;};

// Final composer pointer authority: uses inverse MAIN projection in game view.
const _bss095HydrateFallback=App.prototype.hydrateEBDXStudioPreview;
App.prototype.hydrateEBDXStudioPreview=async function(){
  if(!(this.screen==="ebdx"&&S(this.ebdxStudioTab||"backgrounds")==="backgrounds")||!this.body||!this.body.querySelector(".bss092-composer"))return _bss095HydrateFallback.call(this);
  const el=this.body.querySelector("[data-ebdx-preview]"),view=this.ebdxStudioView();if(!el||!view)return;const game=S(this.ebdx095PreviewMode||"game")==="game";el.innerHTML=`<canvas class="bss-ebdx-preview-canvas" width="${game?640:384}" height="${game?480:308}"></canvas>`;const canvas=el.querySelector("canvas");if(!canvas)return;let currentState=await this.bss083EBDXComposite(canvas,view);if(!currentState&&game){this.ebdx095PreviewMode="author";el.innerHTML='<canvas class="bss-ebdx-preview-canvas" width="384" height="308"></canvas>';const fallbackCanvas=el.querySelector("canvas");if(!fallbackCanvas)return;return this.hydrateEBDXStudioPreview();}if(!canvas.isConnected||view.kind!=="custom"){this.bss095HydrateVegetation();return;}
  const self=this;let drag=null,dragMoved=false,rendering=false,dirty=false;function point(ev){return self.bss095PointerLogical(canvas,ev);}function hitsAt(p){return A(currentState&&currentState.hitAreas).filter(a=>p.x>=a.x0&&p.x<=a.x1&&p.y>=a.y0&&p.y<=a.y1);}async function drawQueued(){if(rendering){dirty=true;return;}rendering=true;do{dirty=false;currentState=await self.bss083EBDXComposite(canvas,view);}while(dirty&&canvas.isConnected);rendering=false;}function queueDraw(){dirty=true;if(!rendering)requestAnimationFrame(()=>drawQueued());}
  function localDelta(row,dx,dy){return self.bss094LocalDelta(row,dx,dy);}function warpMove(ev,p){const row=view.data&&view.data[drag.key],cfg=self.bss093WarpConfig(row);if(!row||!cfg||!row.warp||!Array.isArray(row.warp.points))return;let dx=p.x-drag.startPointer.x,dy=p.y-drag.startPointer.y;if(ev.shiftKey){dx=Math.round(dx);dy=Math.round(dy);}const strength=drag.tool==="soft"?self.bss094WarpStrengthValue():1;if(drag.tool==="move"){row.x=drag.startX+dx;row.y=drag.startY+dy;}else{const dl=localDelta(row,dx,dy),src=drag.startPoints,author=drag.startAuthorPoints,radius=self.bss094WarpRadiusValue(),affected=drag.affected||[];row.warp.points=src.map((pt,i)=>{let w=affected.includes(i)?1:0;if(drag.tool==="soft"){const ap=author[i],dist=Math.hypot(ap[0]-drag.center.x,ap[1]-drag.center.y);w=Math.exp(-2.3*Math.pow(dist/Math.max(1,radius),2));}return [pt[0]+dl[0]*w*strength,pt[1]+dl[1]*w*strength];});}dragMoved=true;self.saveSoon();self.bss092SyncQuickBarValues();queueDraw();ev.preventDefault();}
  function move(ev){if(!drag)return;const p=point(ev);if(drag.kind==="warp"){warpMove(ev,p);return;}const rawX=Math.max(-192,Math.min(576,p.x+drag.offX)),rawY=Math.max(-154,Math.min(462,p.y+drag.offY)),nx=ev.shiftKey?Math.round(rawX):self.bss072Snap(rawX),ny=ev.shiftKey?Math.round(rawY):self.bss072Snap(rawY);if(drag.kind==="img"){const row=view.data&&view.data[drag.key];if(!row)return;row.x=nx;row.y=ny;}else{const g=view.data&&view.data[drag.key];if(!g)return;self.bss088SetGroupValue(g,"x",drag.index,nx);self.bss088SetGroupValue(g,"y",drag.index,ny);}drag.x=nx;drag.y=ny;dragMoved=true;self.saveSoon();self.bss092SyncQuickBarValues();queueDraw();ev.preventDefault();}
  function finish(){if(!drag)return;const wasWarp=drag.kind==="warp";drag=null;window.removeEventListener("pointermove",move);window.removeEventListener("pointerup",finish);window.removeEventListener("pointercancel",finish);if(dragMoved&&!wasWarp)self.bss089RefreshSelectionPanels();if(dragMoved)queueDraw();self.bss089UpdateHistoryButtons();}
  canvas.addEventListener("pointerdown",function(ev){const p=point(ev),selected=S(self.ebdx088SelectedLayer),row=view.data&&view.data[selected],cfg=self.bss093WarpConfig(row),tool=self.bss094WarpTool();if(cfg&&S(self.ebdx093WarpEditKey)===selected){const handles=A(currentState&&currentState.warpHandles),handle=self.bss094NearestWarpHandle(handles,p,14),hit=self.bss094SelectedWarpHit(currentState,selected,p);if(tool==="move"||tool==="soft"||handle){let affected=[];if(tool==="point"&&handle)affected=[handle.index];else if(tool==="row"&&handle)affected=Array.from({length:cfg.cols},(_,c)=>handle.row*cfg.cols+c);else if(tool==="column"&&handle)affected=Array.from({length:cfg.rows},(_,r)=>r*cfg.cols+handle.col);else if(tool==="edge")affected=self.bss094EdgeIndexes(cfg,handle,p,hit);else if(tool==="mesh_all")affected=Array.from({length:cfg.cols*cfg.rows},(_,i)=>i);else if(tool==="soft")affected=Array.from({length:cfg.cols*cfg.rows},(_,i)=>i);if(tool!=="point"||handle){self.bss089HistoryCheckpoint("Deformar "+selected);drag={kind:"warp",tool,key:selected,index:handle&&handle.index,affected,startPointer:{x:p.x,y:p.y},center:{x:p.x,y:p.y},startPoints:row.warp.points.map(q=>[N(q&&q[0],0),N(q&&q[1],0)]),startAuthorPoints:cfg.points.map(q=>self.bss093WarpAuthorPoint(row,q)),startX:N(row.x,0),startY:N(row.y,0)};dragMoved=false;window.addEventListener("pointermove",move,{passive:false});window.addEventListener("pointerup",finish);window.addEventListener("pointercancel",finish);ev.preventDefault();return;}}}
    const hits=hitsAt(p);let hit=null,si=hits.findIndex(a=>a.id===selected);if(hits.length>0){if(ev.altKey||(si===0&&hits.length>1))hit=hits[(si>=0?si+1:0)%hits.length];else hit=hits[0];}if(!hit)return;self.ebdx088SelectedLayer=hit.id;self._bss089EditKey="";self.bss089HistoryCheckpoint("Mover "+hit.id);self.bss089RefreshSelectionPanels();drag=Object.assign({},hit,{offX:N(hit.x,0)-p.x,offY:N(hit.y,0)-p.y});dragMoved=false;window.addEventListener("pointermove",move,{passive:false});window.addEventListener("pointerup",finish);window.addEventListener("pointercancel",finish);queueDraw();ev.preventDefault();
  });
  this.bss095HydrateVegetation();
};

// BSS v0.8.16 - composer preview hotfix: detached-buffer rendering + quickbar refresh authority.


// ============================================================================
// BSS v0.8.18 - Requested parity/fidelity patch
// - icon/preview/ingame parity uses the game crop for library cards
// - Scene Assets browser shows recortes clearly, adds category filter, and can
//   pull project tilesets without copying them into Graphics/BattleSceneStudio
// - camera profiles simplified to EBDX + Estático
// - separate fondo metadata block for global/per-context assignments
// ============================================================================
(function(){
  // Keep the game crop as the default visual authority.
  if(typeof App!=="undefined"){
    const _ensureCfg=App.prototype.bss079EnsureEBDXConfig;
    App.prototype.bss079EnsureEBDXConfig=function(){
      const g=_ensureCfg.call(this);
      if(this.ebdx095PreviewMode==null)this.ebdx095PreviewMode="game";
      g.ebdxEncounterMetadata=A(g.ebdxEncounterMetadata);
      return g;
    };

    // Only expose the two requested camera modes in the editor.
    const clone=o=>JSON.parse(JSON.stringify(o||{}));
    const EBDX_PROFILE=clone((BSS087_CAMERA_PROFILES.classic_gen5||BSS087_CAMERA_PROFILES.source_faithful||{}).contexts||{});
    const STATIC_PROFILE={};
    ["command","fight","move","spread","common","sendout","recall","sos","capture","faint","turn_end","idle","bas"].forEach(k=>{
      STATIC_PROFILE[k]={enabled:false,mode:"neutral",frames:0,strength:0};
    });
    BSS087_CAMERA_PROFILES.ebdx={label:"EBDX",note:"Cámara viva tipo EBDX/Gen 5 para comandos, moves, SOS, sendout y flujo general.",contexts:EBDX_PROFILE};
    BSS087_CAMERA_PROFILES.static={label:"Estático",note:"Plano fijo. Sin paneos automáticos salvo la autoridad puntual de BAS cuando corresponda.",contexts:STATIC_PROFILE};
    App.prototype.bss087CameraProfileIds=function(){return ["ebdx","static"]};
    App.prototype.bss079CameraConfigHTML=function(){
      const c=this.bss079EnsureEBDXConfig().ebdxCamera||(this.bss079EnsureEBDXConfig().ebdxCamera={});
      c.profile=S(c.profile||c.preset||"ebdx");
      if(!["ebdx","static"].includes(c.profile))c.profile="ebdx";
      if(!c.contexts||typeof c.contexts!=="object")c.contexts=clone(BSS087_CAMERA_PROFILES[c.profile].contexts);
      const cards=this.bss087CameraProfileIds().map(id=>{const p=BSS087_CAMERA_PROFILES[id];return `<button type="button" class="bss079-mini-card ${c.profile===id?"active":""}" data-bss087-camera-profile="${E(id)}"><b>${E(p.label)}</b><small>${E(p.note)}</small></button>`;}).join("");
      return `<section class="bss079-config-block"><div class="bss079-section-head"><div><b>Cámara EBDX</b><small>Modos directos: EBDX o Estático. Sin perfiles extra.</small></div></div><div class="bss087-camera-profiles"><div class="bss087-profile-card-grid">${cards}</div></div></section>`;
    };
    const _clickProfiles=App.prototype.onClick;
    App.prototype.onClick=function(e){
      const raw=e&&e.target,t=raw&&typeof raw.closest==="function"?raw.closest("[data-bss087-camera-profile],[data-bss097-context-add],[data-bss097-context-remove],[data-bss095-preview-mode],[data-bss095-blur-set],[data-bss095-veg],[data-bss095-warp-tool],[data-bss087-asset-add],[data-act]"):raw;
      if(t&&t.dataset){
        if(t.dataset.bss087CameraProfile!=null){
          const id=S(t.dataset.bss087CameraProfile||"ebdx");
          const p=BSS087_CAMERA_PROFILES[id];
          if(p){
            const c=this.bss079EnsureEBDXConfig().ebdxCamera||(this.bss079EnsureEBDXConfig().ebdxCamera={});
            c.profile=id;c.preset=id;c.contexts=clone(p.contexts);
            this.saveSoon();
            if(this.screen==="ebdx")this.bss087RenderEBDXPreserveScroll?this.bss087RenderEBDXPreserveScroll():this.renderEBDXStudio();
            else this.renderGlobalSettingsModal&&this.renderGlobalSettingsModal();
          }
          return;
        }
        if(t.dataset.bss097ContextAdd!=null){
          const g=this.bss079EnsureEBDXConfig();
          g.ebdxEncounterMetadata=A(g.ebdxEncounterMetadata);
          const ctx=S((this.root&&this.root.querySelector('[data-bss097-context-new]')||{}).value||"");
          if(ctx&&!g.ebdxEncounterMetadata.some(r=>S(r&&r.context)===ctx))g.ebdxEncounterMetadata.push({context:ctx,backdrop:"Auto"});
          this.saveSoon();
          return this.renderEBDXStudio();
        }
        if(t.dataset.bss097ContextRemove!=null){
          const g=this.bss079EnsureEBDXConfig();
          g.ebdxEncounterMetadata=A(g.ebdxEncounterMetadata).filter(r=>S(r&&r.context)!==S(t.dataset.bss097ContextRemove));
          this.saveSoon();
          return this.renderEBDXStudio();
        }
      }
      return _clickProfiles.call(this,e);
    };
    const _inputProfiles=App.prototype.onInput;
    App.prototype.onInput=function(e){
      const t=e&&e.target;
      if(t&&t.dataset){
        if(t.dataset.bss097ContextBg!=null){
          const g=this.bss079EnsureEBDXConfig();
          const row=A(g.ebdxEncounterMetadata).find(r=>S(r&&r.context)===S(t.dataset.bss097ContextBg));
          if(row){row.backdrop=S(t.value||"Auto");this.saveSoon();}
          return;
        }
      }
      return _inputProfiles.call(this,e);
    };

    // Separate metadata section: global default + per encounter context rows.
    App.prototype.bss097ContextRows=function(){
      const g=this.bss079EnsureEBDXConfig();
      g.ebdxEncounterMetadata=A(g.ebdxEncounterMetadata);
      return g.ebdxEncounterMetadata;
    };
    App.prototype.bss097ContextMetaHTML=function(){
      const g=this.bss079EnsureEBDXConfig(),choices=this.ebdxBackdropChoices(false),rows=this.bss097ContextRows();
      const known=["Land","Cave","Water","Underwater","Indoor","Night","Grass","Sand","Rock","None"];
      const unused=known.filter(x=>!rows.some(r=>S(r&&r.context)===x));
      return `<section class="bss079-config-block"><div class="bss079-section-head"><div><b>Metadata de fondos</b><small>Define un fondo general y overrides por contexto/encounter type sin mezclarlo con la lista por mapa.</small></div></div><div class="bss-mini-grid"><label class="bss-mini-field"><span>Fondo general</span><select class="bss-select" data-studio-global="ebdxBackdrop">${choices.map(x=>`<option value="${E(x.id)}" ${S(g.ebdxBackdrop||"Auto")===S(x.id)?"selected":""}>${E(x.label)}</option>`).join("")}</select></label></div><div class="bss079-map-assign"><label class="bss-mini-field"><span>Contexto / Encounter type</span><select class="bss-select" data-bss097-context-new><option value="">Seleccionar…</option>${unused.map(x=>`<option value="${E(x)}">${E(x)}</option>`).join("")}</select></label><button type="button" class="bss-btn primary" data-bss097-context-add>＋ Añadir contexto</button></div><div class="bss079-map-list">${rows.map(r=>`<article class="bss079-map-row"><div><b>${E(S(r.context))}</b><small>Override por contexto</small></div><select class="bss-select" data-bss097-context-bg="${E(S(r.context))}">${choices.map(x=>`<option value="${E(x.id)}" ${S(r.backdrop||"Auto")===S(x.id)?"selected":""}>${E(x.label)}</option>`).join("")}</select><button type="button" class="bss-btn danger small" data-bss097-context-remove="${E(S(r.context))}">Quitar</button></article>`).join("")||'<div class="bss-empty">Sin overrides por contexto.</div>'}</div></section>`;
    };
    const _configHTML=App.prototype.bss079ConfigHTML;
    App.prototype.bss079ConfigHTML=function(){
      const base=_configHTML.call(this);
      const marker='</section>';
      const firstEnd=base.indexOf(marker);
      if(firstEnd<0)return base;
      return base.slice(0,firstEnd+marker.length)+this.bss097ContextMetaHTML()+base.slice(firstEnd+marker.length);
    };

    // Scene Assets: clearer categories + project tilesets, while excluding refs/licenses/txt.
    App.prototype.bss097SceneAssetCategory=function(path){
      const p=S(path).replace(/\\/g,'/');
      if(/^Graphics\/Tilesets\//i.test(p))return 'Proyecto · Tilesets';
      const m=p.match(/Graphics\/BattleSceneStudio\/EBDX\/SceneAssets\/(.+)$/i);
      if(!m)return 'Otros';
      const rel=m[1];
      const parts=rel.split('/').filter(Boolean);
      if(!parts.length)return 'Scene Assets';
      if(parts[0]==='Cutouts'&&parts[1])return 'Cutouts · '+parts[1];
      return parts[0];
    };
    App.prototype.bss087SceneAssetRows=function(){
      const all=A(this.source&&this.source.allGraphics);
      const out=[];
      all.forEach(x=>{
        const p=S(x&&x.projectPath).replace(/\\/g,'/');
        if(!p||/\.txt$/i.test(p)||/\/references\//i.test(p)||/\/licenses?\//i.test(p)||/\/tilesets\//i.test(p)&&/^Graphics\/BattleSceneStudio\/EBDX\/SceneAssets\//i.test(p))return;
        if(/^Graphics\/BattleSceneStudio\/EBDX\/SceneAssets\//i.test(p) || /^Graphics\/Tilesets\//i.test(p)){
          out.push(Object.assign({},x,{category:this.bss097SceneAssetCategory(p),projectPath:p,name:S(x&&x.name)||p.split('/').pop()}));
        }
      });
      return out.sort((a,b)=>S(a.category).localeCompare(S(b.category))||S(a.name).localeCompare(S(b.name)));
    };
    App.prototype.bss087SceneAssetBrowserHTML=function(){
      const q=L(this.ebdx087AssetSearch||""),all=this.bss087SceneAssetRows(),cats=["all",...new Set(all.map(x=>S(x.category)).filter(Boolean))],cat=S(this.ebdx087AssetCategory||"all"),rows=all.filter(x=>(cat==="all"||S(x.category)===cat)&&(!q||L((x.name||"")+" "+(x.projectPath||"")+" "+(x.category||"")).includes(q))).slice(0,120);
      return `<section class="bss-panel bss087-asset-browser"><div class="bss079-section-head"><div><b>Scene Assets</b><small>Incluye recortes, cielos y tilesets del proyecto. Los assets del proyecto se usan desde su ruta real, sin duplicarlos.</small></div><div class="bss-row"><select class="bss-select" data-bss087-asset-category>${cats.map(id=>`<option value="${E(id)}" ${cat===id?"selected":""}>${E(id==="all"?"Todas las categorías":id)}</option>`).join("")}</select><input class="bss-search" data-bss087-asset-search placeholder="Buscar cielo, cutout, tileset…" value="${E(this.ebdx087AssetSearch||"")}"></div></div><div class="bss087-asset-grid">${rows.map(x=>`<button type="button" class="bss087-asset-card" data-bss087-asset-add="${E(x.projectPath)}"><span class="bss087-asset-thumb" data-bss087-asset-thumb="${E(x.projectPath)}"></span><b>${E(x.name||x.projectPath.split('/').pop())}</b><small>${E(S(x.category)||'Scene Assets')}</small><small>${E(x.projectPath.replace(/^Graphics\//,""))}</small></button>`).join("")||'<div class="bss-empty">Sin resultados.</div>'}</div></section>`;
    };
    const _assetInput=App.prototype.onInput;
    App.prototype.onInput=function(e){
      const t=e&&e.target;
      if(t&&t.dataset&&t.dataset.bss087AssetCategory!=null){this.ebdx087AssetCategory=S(t.value||"all");return this.renderEBDXSceneEditor?this.renderEBDXSceneEditor():this.renderEBDXStudio();}
      return _assetInput.call(this,e);
    };

    // Library cards: render the same game crop used ingame/main preview.
    App.prototype.bss079HydrateSceneCards=async function(){
      if(!this.body)return;
      const entries=A(this.bss079SceneEntries()),byKey=new Map(entries.map(r=>[S(r.kind)+":"+S(r.id),r]));
      for(const canvas of [...this.body.querySelectorAll("[data-bss079-card-preview]")]){
        const row=byKey.get(S(canvas.dataset.bss079CardPreview));
        if(!row)continue;
        try{
          const holder=document.createElement('div');holder.className='bss092-main-preview';
          const off=document.createElement('canvas');off.width=640;off.height=480;holder.appendChild(off);
          const prevMode=this.ebdx095PreviewMode;this.ebdx095PreviewMode='game';
          await this.bss083EBDXComposite(off,{kind:row.kind,id:row.id,name:row.name,data:JSON.parse(JSON.stringify(row.data||{})),row:row.row||null});
          this.ebdx095PreviewMode=prevMode;
          const ctx=canvas.getContext('2d');ctx.imageSmoothingEnabled=false;ctx.clearRect(0,0,canvas.width,canvas.height);ctx.drawImage(off,0,0,640,480,0,0,canvas.width,canvas.height);
        }catch(_){ }
      }
    };
  }
})();

// ============================================================================
// BSS v0.8.19 - Fidelity architecture pass
// Exact authored static layer raster (warp + local blur), safe DOM refreshes,
// and ambient-only EBDX camera authoring.
// ============================================================================
(function(){
  if(typeof App==="undefined")return;

  // --------------------------------------------------------------------------
  // DOM: never use replaceWith on nodes that a blur/input handler may already
  // have moved/rebuilt. All composer refreshes go through a parent check.
  // --------------------------------------------------------------------------
  App.prototype.bss099SafeReplace=function(oldNode,newNode){
    if(!oldNode||!newNode)return false;
    const parent=oldNode.parentNode;
    if(!parent)return false;
    try{if(oldNode.parentNode===parent){parent.replaceChild(newNode,oldNode);return true;}}catch(_){ }
    return false;
  };
  App.prototype.bss089RefreshInspectorOnly=function(){
    const old=this.body&&this.body.querySelector(".bss088-inspector"),scene=this.bss088SceneFromState();if(!old||!scene)return;
    const tmp=document.createElement("div");tmp.innerHTML=this.bss088SceneInspectorHTML(scene);const next=tmp.firstElementChild;
    if(next)this.bss099SafeReplace(old,next);this.bss089UpdateHistoryButtons();
  };
  App.prototype.bss089RefreshQuickBar=function(){
    const old=this.body&&this.body.querySelector(".bss092-quickbar"),scene=this.bss088SceneFromState();if(!old||!scene)return;
    const tmp=document.createElement("div");tmp.innerHTML=this.bss092QuickBarHTML(scene);const next=tmp.firstElementChild;
    if(next)this.bss099SafeReplace(old,next);
  };

  // --------------------------------------------------------------------------
  // Camera authoring: only EBDX ambiental and Estático. Context-specific shots
  // are intentionally removed from BSS automatic camera behavior.
  // --------------------------------------------------------------------------
  const AMBIENT_CONTEXTS={
    command:{enabled:false,mode:"hold",frames:0,strength:0},fight:{enabled:false,mode:"hold",frames:0,strength:0},
    move:{enabled:false,mode:"hold",frames:0,strength:0},spread:{enabled:false,mode:"hold",frames:0,strength:0},
    common:{enabled:false,mode:"hold",frames:0,strength:0},sendout:{enabled:false,mode:"hold",frames:0,strength:0},
    recall:{enabled:false,mode:"hold",frames:0,strength:0},sos:{enabled:false,mode:"hold",frames:0,strength:0},
    capture:{enabled:false,mode:"hold",frames:0,strength:0},faint:{enabled:false,mode:"hold",frames:0,strength:0},
    turn_end:{enabled:false,mode:"hold",frames:0,strength:0},idle:{enabled:true,mode:"drift",frames:0,strength:100},
    bas:{enabled:true,mode:"authored",frames:0,strength:100}
  };
  const STATIC_CONTEXTS=JSON.parse(JSON.stringify(AMBIENT_CONTEXTS));STATIC_CONTEXTS.idle={enabled:false,mode:"hold",frames:0,strength:0};
  BSS087_CAMERA_PROFILES.ebdx={label:"EBDX ambiental",note:"Movimiento ambiental Gen 5 continuo. Menús, comandos, moves, SOS y sendout no cambian el encuadre.",contexts:AMBIENT_CONTEXTS};
  BSS087_CAMERA_PROFILES.static={label:"Estático",note:"Sin movimiento ambiental automático. BAS conserva solo la cámara que una animación haya autorado explícitamente.",contexts:STATIC_CONTEXTS};
  App.prototype.bss079CameraConfigHTML=function(){
    const g=this.bss079EnsureEBDXConfig(),c=g.ebdxCamera||(g.ebdxCamera={}),raw=S(c.profile||c.preset||"ebdx"),id=raw==="static"?"static":"ebdx";
    if(raw!==id||!c.contexts){c.profile=id;c.preset=id;c.contexts=JSON.parse(JSON.stringify(BSS087_CAMERA_PROFILES[id].contexts));}
    return `<section class="bss079-config-block"><div class="bss079-section-head"><div><b>Cámara</b><small>BSS ya no mueve la cámara al abrir comandos ni durante ataques. Elige únicamente ambiente EBDX o plano estático.</small></div></div><div class="bss087-profile-card-grid">${["ebdx","static"].map(k=>{const p=BSS087_CAMERA_PROFILES[k];return `<button type="button" class="bss079-mini-card ${id===k?"active":""}" data-bss087-camera-profile="${E(k)}"><b>${E(p.label)}</b><small>${E(p.note)}</small></button>`;}).join("")}</div></section>`;
  };

  // --------------------------------------------------------------------------
  // Local blur data and UI. Areas are stored in the same local coordinates as
  // warp points, so moving/scaling/rotating the layer never loses the mask.
  // --------------------------------------------------------------------------
  App.prototype.bss099BlurAreas=function(d){if(!d||typeof d!=="object")return [];if(!Array.isArray(d.blurAreas))d.blurAreas=[];return d.blurAreas;};
  App.prototype.bss099BlurPanelHTML=function(scene,t){
    if(!t||t.type!=="img")return "";const key=this.bss092TargetId(t),d=t.data,ro=scene.kind!=="custom",dis=ro?"disabled":"",rows=this.bss099BlurAreas(d);
    const hasAnyBlur=rows.length>0||N(d.blur,0)>0;
    const areaRows=rows.map((a,i)=>{
      const mode=a.mode||"radial",style=a.style||"high",isTotal=mode==="total",isBand=mode.startsWith("band"),isRadial=mode==="radial";
      return `<article class="bss099-blur-area ${this._bss099BlurPlacement&&this._bss099BlurPlacement.key===key&&this._bss099BlurPlacement.index===i?"active":""}"><header><div><b>Área ${i+1}</b><small>${isTotal?"Difuminado completo de la capa":"Coordenadas locales de la imagen"}</small></div><div class="bss-row">${!isTotal?`<button type="button" class="bss-btn small" data-bss099-blur-place="${E(key)}:${i}" ${dis}>◎ Colocar en canvas</button>`:""}<button type="button" class="bss-btn danger small" data-bss099-blur-remove="${E(key)}:${i}" ${dis}>Eliminar</button></div></header><div class="bss-mini-grid"><label class="bss-mini-field"><span>Tipo</span><select class="bss-select" data-bss099-blur-field="${E(key)}:${i}:mode" ${dis}><option value="total" ${mode==="total"?"selected":""}>Difuminación total de imagen</option><option value="band_bottom" ${mode==="band_bottom"?"selected":""}>Raya (Baja / Inf.)</option><option value="band_top" ${mode==="band_top"?"selected":""}>Raya (Alta / Sup.)</option><option value="radial" ${mode==="radial"?"selected":""}>Radio (Círculo)</option></select></label><label class="bss-mini-field"><span>Estilo</span><select class="bss-select" data-bss099-blur-field="${E(key)}:${i}:style" ${dis}><option value="high" ${style==="high"?"selected":""}>Difuminado alto (suave)</option><option value="few_tones" ${style==="few_tones"?"selected":""}>Pocos tonos (retro)</option><option value="jumble" ${style==="jumble"?"selected":""}>Revolver pixelado (Aseprite)</option></select></label><label class="bss-mini-field"><span>Difuminado px</span><input class="bss-input" type="number" min="1" max="24" step="1" data-bss099-blur-field="${E(key)}:${i}:strength" value="${N(a.strength,4)}" ${dis}></label>${isRadial?`<label class="bss-mini-field"><span>X local</span><input class="bss-input" type="number" step="1" data-bss099-blur-field="${E(key)}:${i}:x" value="${N(a.x,0)}" ${dis}></label>`:""}${!isTotal?`<label class="bss-mini-field"><span>Y local ${isBand?"(Raya)":""}</span><input class="bss-input" type="number" step="1" data-bss099-blur-field="${E(key)}:${i}:y" value="${N(a.y,0)}" ${dis}></label>`:""}${isRadial?`<label class="bss-mini-field"><span>Radio</span><input class="bss-input" type="number" min="4" max="512" step="1" data-bss099-blur-field="${E(key)}:${i}:radius" value="${N(a.radius,48)}" ${dis}></label>`:""}${!isTotal?`<label class="bss-mini-field"><span>Borde suave</span><input class="bss-input" type="number" min="0" max="256" step="1" data-bss099-blur-field="${E(key)}:${i}:feather" value="${N(a.feather,18)}" ${dis}></label>`:""}</div></article>`;
    }).join("");
    return `<section class="bss088-inspector-section bss099-local-blur"><div class="bss088-section-title"><div><b>Difuminado</b><small>Difumina zonas concretas o la imagen completa (radio circular, raya o total). Se rasteriza igual para Preview e ingame.</small></div><div class="bss-row">${hasAnyBlur?`<button type="button" class="bss-btn danger small" data-bss099-blur-clear-all="${E(key)}" ${dis} title="Elimina completamente todo el difuminado de esta capa">✕ Quitar difuminado</button>`:""}<button type="button" class="bss-btn small" data-bss099-blur-add="${E(key)}" ${dis}>＋ Área</button></div></div>${areaRows||'<div class="bss-empty">Sin áreas de difuminado.</div>'}</section>`;
  };
  const _bss099InspectorBase=App.prototype.bss088LayerInspectorHTML;
  App.prototype.bss088LayerInspectorHTML=function(scene){
    let html=_bss099InspectorBase.call(this,scene),t=this.bss088SelectedTarget(scene);if(!t||t.type!=="img")return html;
    // Remove the old whole-layer blur panel. It was not what the feature was meant to do.
    const start=html.indexOf('<section class="bss088-inspector-section bss095-blur"');
    if(start>=0){const end=html.indexOf('</section>',start);if(end>=0)html=html.slice(0,start)+html.slice(end+10);}
    const panel=this.bss099BlurPanelHTML(scene,t),warp=html.indexOf('<section class="bss088-inspector-section bss093-warp-panel');
    return warp>=0?html.slice(0,warp)+panel+html.slice(warp):html+panel;
  };

  // --------------------------------------------------------------------------
  // Exact static-layer raster. Canvas is the authoring authority for warp and
  // local blur; runtime consumes the generated PNG instead of approximating it
  // with dozens/hundreds of RGSS sprites.
  // --------------------------------------------------------------------------
  App.prototype._bss099RasterCache=new Map();
  App.prototype.bss099RasterFingerprint=function(sceneId,key,d,img){
    return ["104",S(sceneId),S(key),S(d&&d.bitmap),N(img&&img.width),N(img&&img.height),JSON.stringify(d&&d.warp||null),JSON.stringify(d&&d.blurAreas||[]),N(d&&d.ox,-999999),N(d&&d.oy,-999999)].join("|");
  };
  App.prototype.bss099BlurredSource=function(img,d){
    const areas=A(d&&d.blurAreas).filter(a=>a&&N(a.strength,0)>0&&(N(a.radius,0)>0||S(a.mode).startsWith("band")||S(a.mode)==="total"));if(!areas.length)return img;
    const w=img.width,h=img.height,base=document.createElement("canvas");base.width=w;base.height=h;const bg=base.getContext("2d");bg.imageSmoothingEnabled=true;bg.drawImage(img,0,0);
    const ax=d&&d.ox!=null?N(d.ox,0):w/2,ay=d&&d.oy!=null?N(d.oy,0):h;
    areas.forEach(a=>{
      const strength=Math.max(1,Math.min(24,N(a.strength,4))),mode=S(a.mode||"radial"),style=S(a.style||"high"),radius=Math.max(4,N(a.radius,48)),feather=Math.max(0,N(a.feather,18)),cx=ax+N(a.x,0),cy=ay+N(a.y,0);
      const blur=document.createElement("canvas");blur.width=w;blur.height=h;const bc=blur.getContext("2d");
      if(style==="jumble"){
        bc.imageSmoothingEnabled=false;
        bc.drawImage(img,0,0);
        try{
          const imgData=bc.getImageData(0,0,w,h),data=imgData.data;
          const rad=Math.max(1,Math.min(24,Math.round(strength)));
          const passes=Math.max(1,Math.min(4,Math.round(rad*0.75)));
          let rng=0x5a5a5a;
          for(let pass=0;pass<passes;pass++){
            for(let y=0;y<h;y++){
              for(let x=0;x<w;x++){
                const i1=(y*w+x)*4;
                if(data[i1+3]===0)continue;
                const wave=Math.sin(x*0.05+y*0.035)*Math.cos(x*0.03-y*0.06)+0.35*Math.sin((x+y)*0.09)+0.2*Math.cos((x-y)*0.14);
                const norm=(wave+1.55)/3.1;
                rng=(Math.imul(1664525,rng)+1013904223)|0;
                const chance=(rng>>>0)/4294967296;
                if(chance>norm*0.85+0.1)continue;
                const localRad=Math.max(1,Math.round(rad*(0.35+0.85*norm)));
                rng=(Math.imul(1664525,rng)+1013904223)|0;
                const ang=((rng>>>0)/4294967296)*Math.PI*2;
                rng=(Math.imul(1664525,rng)+1013904223)|0;
                const distRatio=(rng>>>0)/4294967296;
                const dist=Math.pow(distRatio,1.4)*localRad;
                const nx=Math.max(0,Math.min(w-1,Math.round(x+Math.cos(ang)*dist)));
                const ny=Math.max(0,Math.min(h-1,Math.round(y+Math.sin(ang)*dist)));
                const i2=(ny*w+nx)*4;
                if(data[i2+3]===0)continue;
                const r=data[i1],g=data[i1+1],b=data[i1+2],al=data[i1+3];
                data[i1]=data[i2];data[i1+1]=data[i2+1];data[i1+2]=data[i2+2];data[i1+3]=data[i2+3];
                data[i2]=r;data[i2+1]=g;data[i2+2]=b;data[i2+3]=al;
                if(norm>0.6&&x+1<w&&nx+1<w){
                  const i1n=(y*w+(x+1))*4,i2n=(ny*w+(nx+1))*4;
                  if(data[i1n+3]!==0&&data[i2n+3]!==0){
                    const rn=data[i1n],gn=data[i1n+1],bn=data[i1n+2],aln=data[i1n+3];
                    data[i1n]=data[i2n];data[i1n+1]=data[i2n+1];data[i1n+2]=data[i2n+2];data[i1n+3]=data[i2n+3];
                    data[i2n]=rn;data[i2n+1]=gn;data[i2n+2]=bn;data[i2n+3]=aln;
                  }
                }
              }
            }
          }
          bc.putImageData(imgData,0,0);
        }catch(_){}
      }else{
        bc.imageSmoothingEnabled=true;if(bc.imageSmoothingQuality)bc.imageSmoothingQuality="high";bc.filter=`blur(${strength}px)`;bc.drawImage(img,0,0);bc.filter="none";
        if(style==="few_tones"){
          try{
            const imgData=bc.getImageData(0,0,w,h),data=imgData.data,step=51;
            for(let i=0;i<data.length;i+=4){
              if(data[i+3]===0)continue;
              data[i]=Math.min(255,Math.round(data[i]/step)*step);
              data[i+1]=Math.min(255,Math.round(data[i+1]/step)*step);
              data[i+2]=Math.min(255,Math.round(data[i+2]/step)*step);
            }
            bc.putImageData(imgData,0,0);
          }catch(_){}
        }
      }
      if(mode==="total"){
        bg.clearRect(0,0,w,h);
        bg.drawImage(blur,0,0);
      }else{
        const mask=document.createElement("canvas");mask.width=w;mask.height=h;const mc=mask.getContext("2d");mc.imageSmoothingEnabled=true;mc.drawImage(blur,0,0);mc.globalCompositeOperation="destination-in";
        if(mode==="band_bottom"){
          const y0=Math.max(0,cy-feather),y1=Math.min(h,cy+feather);
          const gr=mc.createLinearGradient(0,y0,0,y1);
          gr.addColorStop(0,"rgba(255,255,255,0)");gr.addColorStop(1,"rgba(255,255,255,1)");
          mc.fillStyle=gr;mc.fillRect(0,y0,w,Math.max(1,y1-y0));
          if(y1<h){mc.fillStyle="rgba(255,255,255,1)";mc.fillRect(0,y1,w,h-y1);}
        }else if(mode==="band_top"){
          const y0=Math.max(0,cy-feather),y1=Math.min(h,cy+feather);
          const gr=mc.createLinearGradient(0,y1,0,y0);
          gr.addColorStop(0,"rgba(255,255,255,0)");gr.addColorStop(1,"rgba(255,255,255,1)");
          mc.fillStyle=gr;mc.fillRect(0,y0,w,Math.max(1,y1-y0));
          if(y0>0){mc.fillStyle="rgba(255,255,255,1)";mc.fillRect(0,0,w,y0);}
        }else{
          const gr=mc.createRadialGradient(cx,cy,Math.max(0,radius-feather),cx,cy,radius);
          gr.addColorStop(0,"rgba(255,255,255,1)");gr.addColorStop(1,"rgba(255,255,255,0)");mc.fillStyle=gr;mc.fillRect(0,0,w,h);
        }
        mc.globalCompositeOperation="source-over";bg.drawImage(mask,0,0);
      }
    });
    return base;
  };
  App.prototype.bss099RasterLayer=async function(sceneId,key,d){
    if(!d||typeof d!=="object")return null;const cfg=this.bss093WarpConfig(d),areas=A(d.blurAreas).filter(a=>a&&N(a.strength,0)>0&&(N(a.radius,0)>0||S(a.mode).startsWith("band")||S(a.mode)==="total"));if(!cfg&&!areas.length)return null;
    const im=await this.bss083LoadImage(this.bss083EBDXAssetPath("elements",d.bitmap));if(!im)return null;const fp=this.bss099RasterFingerprint(sceneId,key,d,im),old=this._bss099RasterCache.get(fp);if(old)return old;
    const src=this.bss099BlurredSource(im,d);let out,ox,oy;
    if(cfg){const xs=cfg.points.map(p=>N(p&&p[0],0)),ys=cfg.points.map(p=>N(p&&p[1],0)),pad=4+Math.max(0,...areas.map(a=>N(a.strength,0)*2)),minX=Math.floor(Math.min(...xs)-pad),maxX=Math.ceil(Math.max(...xs)+pad),minY=Math.floor(Math.min(...ys)-pad),maxY=Math.ceil(Math.max(...ys)+pad);out=document.createElement("canvas");out.width=Math.max(1,maxX-minX);out.height=Math.max(1,maxY-minY);const ctx=out.getContext("2d");ctx.imageSmoothingEnabled=true;if(ctx.imageSmoothingQuality)ctx.imageSmoothingQuality="high";let q=Math.max(2,Math.min(8,N(cfg.quality,4))),segX=Math.max(1,(cfg.cols-1)*q),segY=Math.max(1,(cfg.rows-1)*q);while(segX*segY>384&&q>2){q--;segX=(cfg.cols-1)*q;segY=(cfg.rows-1)*q;}const dest=(u,v)=>{const p=this.bss093WarpSample(cfg,u,v);return [p[0]-minX,p[1]-minY];},sp=(u,v)=>[u*src.width,v*src.height];for(let iy=0;iy<segY;iy++)for(let ix=0;ix<segX;ix++){const u0=ix/segX,u1=(ix+1)/segX,v0=iy/segY,v1=(iy+1)/segY,s00=sp(u0,v0),s10=sp(u1,v0),s11=sp(u1,v1),s01=sp(u0,v1),p00=dest(u0,v0),p10=dest(u1,v0),p11=dest(u1,v1),p01=dest(u0,v1);this.bss093DrawTexturedTriangle(ctx,src,s00,s10,s11,p00,p10,p11);this.bss093DrawTexturedTriangle(ctx,src,s00,s11,s01,p00,p11,p01);}ox=-minX;oy=-minY;
    }else{out=document.createElement("canvas");out.width=src.width;out.height=src.height;out.getContext("2d").drawImage(src,0,0);ox=d.ox!=null?N(d.ox,0):src.width/2;oy=d.oy!=null?N(d.oy,0):src.height;}
    const url=out.toDataURL("image/png"),result={canvas:out,url,ox,oy,fingerprint:fp};this._bss099RasterCache.set(fp,result);if(this._bss099RasterCache.size>80){const first=this._bss099RasterCache.keys().next().value;this._bss099RasterCache.delete(first);}return result;
  };
  const _bss099AssetPathBase=App.prototype.bss083EBDXAssetPath;
  App.prototype.bss083EBDXAssetPath=function(kind,name){name=S(name);if(/^data:image\//i.test(name)||/^blob:/i.test(name))return name;return _bss099AssetPathBase.call(this,kind,name);};
  const _bss099LoadBase=App.prototype.bss083LoadImage;
  App.prototype.bss083LoadImage=async function(path){if(/^data:image\//i.test(S(path))||/^blob:/i.test(S(path)))return await new Promise(resolve=>{const im=new Image();im.onload=()=>resolve(im);im.onerror=()=>resolve(null);im.src=path;});return _bss099LoadBase.call(this,path);};
  const _bss099CompositeBase=App.prototype.bss083EBDXComposite;
  App.prototype.bss083EBDXComposite=async function(canvas,view){
    let use=view;if(view&&view.data&&typeof view.data==="object"){
      const data=JSON.parse(JSON.stringify(view.data)),keys=Object.keys(data).filter(k=>/^img\d+/i.test(k)&&data[k]&&typeof data[k]==="object");
      for(const key of keys){
        const d0=view.data[key],editingWarp=S(this.ebdx093WarpEditKey)===S(key)&&S(this.ebdx088SelectedLayer)===S(key)&&!!this.bss093WarpConfig(d0);
        // Authoring must NEVER replace the selected warp layer with its baked
        // runtime PNG. Keep the live source + warp visible under the control
        // mesh. Runtime rasterization is a persistence/runtime concern only.
        if(editingWarp){
          // Preserve non-destructive source crops while editing the warp. The
          // temporary cropped bitmap is only for this preview clone; the scene
          // continues to reference the original project graphic.
          if(d0&&d0.crop&&typeof this.bss100CropCanvas==="function"){
            try{
              const path=this.bss083EBDXAssetPath("elements",d0.bitmap),cc=await this.bss100CropCanvas(path,d0.crop);
              if(cc){const d=data[key];d.bitmap=cc.url;d.ox=d0.ox!=null?N(d0.ox,cc.image.width/2)-cc.x:cc.w/2;d.oy=d0.oy!=null?N(d0.oy,cc.image.height)-cc.y:cc.h;delete d.crop;}
            }catch(_){ }
          }
          continue;
        }
        const r=await this.bss099RasterLayer(view.id||"scene",key,d0);if(!r)continue;const d=data[key];d.bitmap=r.url;d.ox=r.ox;d.oy=r.oy;delete d.warp;delete d.blurAreas;d.blur=0;
      }
      use=Object.assign({},view,{data});
    }
    const state=await _bss099CompositeBase.call(this,canvas,use);
    // Draw local blur area guides after the game/author projection has finished.
    try{if(state&&canvas&&view&&view.kind==="custom"){const key=S(this.ebdx088SelectedLayer),d=view.data&&view.data[key],areas=A(d&&d.blurAreas);if(d&&areas.length){const ctx=canvas.getContext("2d"),game=canvas.width===640&&typeof this.bss095MainProjection==="function",q=game?this.bss095MainProjection():null,base=N(d.zoom,1),zx=d.zoom_x!=null?N(d.zoom_x,base):base,zy=d.zoom_y!=null?N(d.zoom_y,base):base,scale=(Math.abs(zx)+Math.abs(zy))/2;ctx.save();ctx.lineWidth=1.5;      areas.forEach((a,i)=>{const mode=S(a.mode||"radial");if(mode==="total")return;const p=this.bss093WarpAuthorPoint(d,[N(a.x,0),N(a.y,0)]),gx=game?p[0]*q.scale+q.tx:p[0],gy=game?p[1]*q.scale+q.ty:p[1],isBand=mode.startsWith("band");ctx.strokeStyle=this._bss099BlurPlacement&&this._bss099BlurPlacement.key===key&&this._bss099BlurPlacement.index===i?"rgba(255,207,109,.95)":"rgba(122,196,255,.8)";ctx.setLineDash([5,4]);ctx.beginPath();if(isBand){ctx.moveTo(0,gy);ctx.lineTo(canvas.width,gy);ctx.stroke();const dir=mode==="band_bottom"?1:-1;for(let tx=40;tx<canvas.width;tx+=60){ctx.moveTo(tx,gy);ctx.lineTo(tx,gy+dir*8);ctx.lineTo(tx-3,gy+dir*5);ctx.moveTo(tx,gy+dir*8);ctx.lineTo(tx+3,gy+dir*5);}ctx.stroke();}else{const rr=Math.max(4,N(a.radius,48))*scale*(game?q.scale:1);ctx.arc(gx,gy,rr,0,Math.PI*2);ctx.stroke();}ctx.setLineDash([]);ctx.fillStyle="rgba(8,16,26,.9)";ctx.strokeStyle="#fff";ctx.fillRect(gx-4,gy-4,8,8);ctx.strokeRect(gx-4.5,gy-4.5,9,9);});ctx.restore();}}
    }catch(_){ }
    return state;
  };

  App.prototype.bss099ProjectRoot=function(){return S(this.ctx&&this.ctx.editor&&typeof this.ctx.editor.gameRoot==="function"?this.ctx.editor.gameRoot():"").replace(/\\/g,"/").replace(/\/$/,"");};
  App.prototype.bss099WriteBinary=async function(rel,bytes){const root=this.bss099ProjectRoot(),tauri=typeof window!=="undefined"&&window.__TAURI__?window.__TAURI__:null,invoke=tauri&&tauri.core&&typeof tauri.core.invoke==="function"?tauri.core.invoke:(tauri&&tauri.tauri&&typeof tauri.tauri.invoke==="function"?tauri.tauri.invoke:null);if(!root||typeof invoke!=="function")throw new Error("Maker Studio binary writer unavailable");const arr=bytes instanceof Uint8Array?bytes:new Uint8Array(bytes||[]);await invoke("write_binary_file",{path:`${root}/${S(rel).replace(/^\/+/,"")}`,data:Array.from(arr)});return true;};
  App.prototype.bss099CanvasBytes=async function(canvas){const blob=await new Promise(resolve=>canvas.toBlob(resolve,"image/png"));if(!blob)throw new Error("PNG encoder unavailable");return new Uint8Array(await blob.arrayBuffer());};
  App.prototype.bss099BakeRuntimeRasters=async function(){
    const rows=A(this.studio&&this.studio.global&&this.studio.global.ebdxCustomEnvironments);if(!rows.length)return;await this.ctx.fs.projectMkdir("Graphics/BattleSceneStudio/EBDX/Generated");
    for(const scene of rows){const data=scene&&scene.data;if(!data||typeof data!=="object")continue;for(const key of Object.keys(data).filter(k=>/^img\d+/i.test(k))){const d=data[key];if(!d||typeof d!=="object")continue;const r=await this.bss099RasterLayer(scene.id||"scene",key,d);if(!r){delete d.runtimeRaster;continue;}const safeScene=S(scene.id||"scene").replace(/[^A-Za-z0-9_-]+/g,"_"),safeKey=S(key).replace(/[^A-Za-z0-9_-]+/g,"_"),path=`Graphics/BattleSceneStudio/EBDX/Generated/${safeScene}_${safeKey}.png`,bytes=await this.bss099CanvasBytes(r.canvas);await this.bss099WriteBinary(path,bytes);d.runtimeRaster={bitmap:path,ox:r.ox,oy:r.oy,fingerprint:r.fingerprint};}}
  };
  const _bss099WriteFilesBase=App.prototype.bss076WriteEBDXFiles;
  App.prototype.bss076WriteEBDXFiles=async function(){try{await this.bss099BakeRuntimeRasters();}catch(e){this.toast("Raster runtime: "+S(e&&e.message||e),true);}return _bss099WriteFilesBase.call(this);};

  App.prototype.bss099ClearAllBlur=async function(key){
    const scene=this.bss088SceneFromState(),d=scene&&scene.kind==="custom"&&scene.data&&scene.data[key];
    if(!d)return;
    this.bss089HistoryCheckpoint("Quitar difuminado de "+key);
    d.blurAreas=[];
    d.blur=0;
    delete d.blur;
    this._bss099BlurPlacement=null;
    if(this.ebdx100CanvasTool==='blur'){this.ebdx100CanvasTool='';this.bss089RefreshQuickBar();}
    if(this._bss101VisualCache)this._bss101VisualCache.clear();
    if(this._bss099RasterCache)this._bss099RasterCache.clear();
    const cfg=this.bss093WarpConfig(d);
    if(!cfg){
      delete d.runtimeRaster;
    }else{
      delete d.runtimeRaster;
      const r=await this.bss099RasterLayer(scene.id||"scene",key,d);
      if(r){
        const safeScene=S(scene.id||"scene").replace(/[^A-Za-z0-9_-]+/g,"_"),safeKey=S(key).replace(/[^A-Za-z0-9_-]+/g,"_"),path=`Graphics/BattleSceneStudio/EBDX/Generated/${safeScene}_${safeKey}.png`,bytes=await this.bss099CanvasBytes(r.canvas);
        try{await this.bss099WriteBinary(path,bytes);d.runtimeRaster={bitmap:path,ox:r.ox,oy:r.oy,fingerprint:r.fingerprint};}catch(_){}
      }
    }
    try{await this.save(true);}catch(_){this.saveSoon();}
    this.bss089RefreshSelectionPanels();
    this.bss089RedrawPreview();
  };

  // --------------------------------------------------------------------------
  // Local blur events + safe input handling.
  // --------------------------------------------------------------------------
  const _bss099ClickBase=App.prototype.onClick;
  App.prototype.onClick=function(e){
    const raw=e&&e.target,t=raw&&typeof raw.closest==="function"?raw.closest("[data-bss099-blur-clear-all],[data-bss099-blur-add],[data-bss099-blur-remove],[data-bss099-blur-place],[data-bss087-camera-profile],[data-act]"):raw;
    if(t&&t.dataset){
      if(t.dataset.bss099BlurClearAll!=null){const key=S(t.dataset.bss099BlurClearAll);this.bss099ClearAllBlur(key);return;}
      if(t.dataset.bss099BlurAdd!=null){const scene=this.bss088SceneFromState(),key=S(t.dataset.bss099BlurAdd),d=scene&&scene.kind==="custom"&&scene.data&&scene.data[key];if(d){this.bss089HistoryCheckpoint("Añadir difuminado local");this.bss099BlurAreas(d).push({mode:"band_bottom",style:"high",x:0,y:-32,radius:48,strength:4,feather:18});d.blur=0;if(this._bss101VisualCache)this._bss101VisualCache.clear();if(this._bss099RasterCache)this._bss099RasterCache.clear();this.saveSoon();this.bss089RefreshSelectionPanels();this.bss089RedrawPreview();}return;}
      if(t.dataset.bss099BlurRemove!=null){
        const [key,idxRaw]=S(t.dataset.bss099BlurRemove).split(":"),scene=this.bss088SceneFromState(),d=scene&&scene.kind==="custom"&&scene.data&&scene.data[key],idx=N(idxRaw,-1);
        if(d&&idx>=0){
          this.bss089HistoryCheckpoint("Eliminar difuminado local");
          this.bss099BlurAreas(d).splice(idx,1);
          this._bss099BlurPlacement=null;
          if(this._bss101VisualCache)this._bss101VisualCache.clear();
          if(this._bss099RasterCache)this._bss099RasterCache.clear();
          if(this.bss099BlurAreas(d).length===0){
            d.blur=0;
            delete d.blur;
            if(this.ebdx100CanvasTool==='blur'){this.ebdx100CanvasTool='';this.bss089RefreshQuickBar();}
            const cfg=this.bss093WarpConfig(d);
            if(!cfg){delete d.runtimeRaster;}
            else{
              delete d.runtimeRaster;
              this.bss099RasterLayer(scene.id||"scene",key,d).then(async r=>{
                if(r){
                  const safeScene=S(scene.id||"scene").replace(/[^A-Za-z0-9_-]+/g,"_"),safeKey=S(key).replace(/[^A-Za-z0-9_-]+/g,"_"),path=`Graphics/BattleSceneStudio/EBDX/Generated/${safeScene}_${safeKey}.png`,bytes=await this.bss099CanvasBytes(r.canvas);
                  try{await this.bss099WriteBinary(path,bytes);d.runtimeRaster={bitmap:path,ox:r.ox,oy:r.oy,fingerprint:r.fingerprint};}catch(_){}
                }
              }).catch(_=>{});
            }
          }else{
            const cfg=this.bss093WarpConfig(d),hasBlur=this.bss099BlurAreas(d).some(a=>a&&N(a.strength,0)>0);
            if(cfg||hasBlur){
              delete d.runtimeRaster;
              this.bss099RasterLayer(scene.id||"scene",key,d).then(async r=>{
                if(r){
                  const safeScene=S(scene.id||"scene").replace(/[^A-Za-z0-9_-]+/g,"_"),safeKey=S(key).replace(/[^A-Za-z0-9_-]+/g,"_"),path=`Graphics/BattleSceneStudio/EBDX/Generated/${safeScene}_${safeKey}.png`,bytes=await this.bss099CanvasBytes(r.canvas);
                  try{await this.bss099WriteBinary(path,bytes);d.runtimeRaster={bitmap:path,ox:r.ox,oy:r.oy,fingerprint:r.fingerprint};}catch(_){}
                }
              }).catch(_=>{});
            }else delete d.runtimeRaster;
          }
          try{this.save(true);}catch(_){this.saveSoon();}
          this.bss089RefreshSelectionPanels();
          this.bss089RedrawPreview();
        }
        return;
      }
      if(t.dataset.bss099BlurPlace!=null){const parts=S(t.dataset.bss099BlurPlace).split(":"),key=parts[0],index=N(parts[1],0);this._bss099BlurPlacement={key,index};this.bss089RefreshInspectorOnly();this.bss089RedrawPreview();return;}
      if(t.dataset.bss087CameraProfile!=null){const id=S(t.dataset.bss087CameraProfile)==="static"?"static":"ebdx",p=BSS087_CAMERA_PROFILES[id],c=this.bss079EnsureEBDXConfig().ebdxCamera||(this.bss079EnsureEBDXConfig().ebdxCamera={});c.profile=id;c.preset=id;c.contexts=JSON.parse(JSON.stringify(p.contexts));this.saveSoon();this.renderEBDXStudio();return;}
    }
    return _bss099ClickBase.call(this,e);
  };
  const _bss099InputBase=App.prototype.onInput;
  App.prototype.onInput=function(e){
    const t=e&&e.target;
    try{
      if(t&&t.dataset){
        if(t.dataset.bss099BlurField!=null){const parts=S(t.dataset.bss099BlurField).split(":"),field=parts.pop(),idx=N(parts.pop(),-1),key=parts.join(":"),scene=this.bss088SceneFromState(),d=scene&&scene.kind==="custom"&&scene.data&&scene.data[key],a=d&&this.bss099BlurAreas(d)[idx];if(a){if(field==="mode"||field==="style"){a[field]=S(t.value);this.bss089RefreshInspectorOnly();}else{const limits={radius:[4,512],strength:[1,24],feather:[0,256]},v=N(t.value,0);a[field]=limits[field]?Math.max(limits[field][0],Math.min(limits[field][1],v)):v;}this.saveSoon();this.bss089RedrawPreview();}return;}
        // Search boxes used to replace their own node while blur/input could also
        // refresh the parent. Handle them here with a guarded replacement.
        if(t.dataset.bss087AssetSearch!=null){this.ebdx087AssetSearch=S(t.value);const box=this.body&&this.body.querySelector(".bss087-asset-browser");if(box){const tmp=document.createElement("div");tmp.innerHTML=this.bss087SceneAssetBrowserHTML();const next=tmp.firstElementChild;if(next)this.bss099SafeReplace(box,next);this.bss087HydrateAssetThumbs();}return;}
        if(t.dataset.bss088AssetSearch!=null){this.ebdx088AssetSearch=S(t.value);const tray=this.body&&this.body.querySelector(".bss088-asset-tray"),scene=this.bss088SceneFromState();if(tray&&scene){const tmp=document.createElement("div");tmp.innerHTML=this.bss088AssetTrayHTML(scene);const next=tmp.firstElementChild;if(next)this.bss099SafeReplace(tray,next);this.bss087HydrateAssetThumbs();}return;}
      }
      return _bss099InputBase.call(this,e);
    }catch(err){const msg=S(err&&err.message||err);if(/replaceWith|no longer a child|replaceChild/i.test(msg)){requestAnimationFrame(()=>{try{this.bss089RefreshSelectionPanels();this.bss089RedrawPreview();}catch(_){}});return;}throw err;}
  };

  const _bss099HydrateBase=App.prototype.hydrateEBDXStudioPreview;
  App.prototype.hydrateEBDXStudioPreview=async function(){
    const ret=await _bss099HydrateBase.call(this),canvas=this.body&&this.body.querySelector(".bss089-main-preview canvas");if(!canvas||canvas._bss099BlurPlacementListener)return ret;canvas._bss099BlurPlacementListener=true;
    canvas.addEventListener("pointerdown",ev=>{const arm=this._bss099BlurPlacement;if(!arm)return;const scene=this.bss088SceneFromState(),d=scene&&scene.kind==="custom"&&scene.data&&scene.data[arm.key],area=d&&this.bss099BlurAreas(d)[arm.index];if(!d||!area){this._bss099BlurPlacement=null;return;}const p=typeof this.bss095PointerLogical==="function"?this.bss095PointerLogical(canvas,ev):{x:0,y:0},local=this.bss093WarpLocalFromAuthor(d,p.x,p.y);this.bss089HistoryCheckpoint("Colocar difuminado local");area.x=Math.round(local[0]);area.y=Math.round(local[1]);this._bss099BlurPlacement=null;this.saveSoon();this.bss089RefreshInspectorOnly();this.bss089RedrawPreview();ev.preventDefault();ev.stopImmediatePropagation();},true);return ret;
  };
})();

// BSS v0.8.19 - sky selection for EBDX scenes.
(function(){
  if(typeof App==="undefined")return;
  App.prototype.bss099SkyChoices=function(){
    const base=[
      {id:"dynamic",label:"Dinámico EBDX · día/tarde/noche",path:""},
      {id:"day",label:"EBDX · Día",path:"Graphics/BattleSceneStudio/EBDX/Battlebacks/elements/skyDay.png"},
      {id:"dawn",label:"EBDX · Amanecer/Tarde",path:"Graphics/BattleSceneStudio/EBDX/Battlebacks/elements/skyDawn.png"},
      {id:"night",label:"EBDX · Noche",path:"Graphics/BattleSceneStudio/EBDX/Battlebacks/elements/skyNight.png"}
    ];
    const seen=new Set(base.map(x=>L(x.path)));
    A(this.source&&this.source.allGraphics).forEach(x=>{const p=S(x&&x.projectPath).replace(/\\/g,"/");if(!p||seen.has(L(p)))return;if(/^Graphics\/BattleSceneStudio\/EBDX\/SceneAssets\/Skies\//i.test(p)){seen.add(L(p));base.push({id:p,label:`Asset · ${S(x.name||p.split('/').pop())}`,path:p});}});
    return base;
  };
  App.prototype.bss099SkyPanelHTML=function(scene){
    if(!scene)return "";const ro=scene.kind!=="custom",dis=ro?"disabled":"",d=scene.data||{},mode=S(d.skyMode||"dynamic"),choices=this.bss099SkyChoices();
    const curSlot=this.bss106SceneTimeSlot?this.bss106SceneTimeSlot({data:d}):"day";
    const slotPreviewHtml=(mode==="dynamic"?`<div class="bss-row" style="margin-top:6px;gap:4px;align-items:center;">
      <span style="font-size:11px;color:#9cb3c9;">Preview:</span>
      <button type="button" class="bss-btn small ${this._bssPreviewTimeSlot==='day'?'active':(!this._bssPreviewTimeSlot&&curSlot==='day'?'active':'')}" data-bss106-preview-slot="day">Día</button>
      <button type="button" class="bss-btn small ${this._bssPreviewTimeSlot==='dawn'?'active':(!this._bssPreviewTimeSlot&&curSlot==='dawn'?'active':'')}" data-bss106-preview-slot="dawn">Tarde</button>
      <button type="button" class="bss-btn small ${this._bssPreviewTimeSlot==='night'?'active':(!this._bssPreviewTimeSlot&&curSlot==='night'?'active':'')}" data-bss106-preview-slot="night">Noche</button>
      <button type="button" class="bss-btn small ${!this._bssPreviewTimeSlot?'active':''}" data-bss106-preview-slot="auto" title="Usa la hora real del PC">Auto (${curSlot})</button>
    </div>`:"");
    return `<section class="bss088-inspector-section bss099-sky-panel"><div class="bss088-section-title"><div><b>Cielo</b><small>Elige el cielo EBDX o cualquiera de los cielos separados en Scene Assets.</small></div></div><label class="bss-check"><input type="checkbox" data-bss099-sky-enabled ${d.sky===true?"checked":""} ${dis}> Mostrar cielo</label><label class="bss-mini-field"><span>Tipo de cielo</span><select class="bss-select" data-bss099-sky-mode ${dis}>${choices.map(x=>`<option value="${E(x.id)}" ${mode===x.id?"selected":""}>${E(x.label)}</option>`).join("")}</select></label>${slotPreviewHtml}${mode!=="dynamic"&&!choices.some(x=>x.id===mode)?`<label class="bss-mini-field"><span>Ruta custom</span><input class="bss-input" data-bss099-sky-custom value="${E(mode)}" ${dis}></label>`:""}</section>`;
  };
  const _sceneInspector=App.prototype.bss088SceneInspectorHTML;
  App.prototype.bss088SceneInspectorHTML=function(scene){let html=_sceneInspector.call(this,scene);if(!scene)return html;const marker='<details class="bss088-json">',pos=html.indexOf(marker);if(pos>=0)html=html.slice(0,pos)+this.bss099SkyPanelHTML(scene)+html.slice(pos);return html;};

  App.prototype.bss099SkyOverridePath=function(view){
    const d=view&&view.data||{};
    const hasSky=d.sky===true||d.outdoor===true||!!d.skyMode;
    if(!hasSky)return "";
    const mode=S(d.skyMode||"dynamic");
    const slot = this.bss106SceneTimeSlot ? this.bss106SceneTimeSlot(view) : (mode==="dynamic"?"day":mode);
    if(slot==="day")return "Graphics/BattleSceneStudio/EBDX/Battlebacks/elements/skyDay.png";
    if(slot==="dawn")return "Graphics/BattleSceneStudio/EBDX/Battlebacks/elements/skyDawn.png";
    if(slot==="night")return "Graphics/BattleSceneStudio/EBDX/Battlebacks/elements/skyNight.png";
    return mode.startsWith("Graphics/")?mode:"";
  };
  const _skyLoadBase=App.prototype.bss083LoadImage;
  App.prototype.bss083LoadImage=async function(path){
    const o=S(this._bss099SkyOverride||"");
    if(o&&/\/skyDay(?:\.png)?$/i.test(S(path)))return _skyLoadBase.call(this,o);
    const im=await _skyLoadBase.call(this,path);
    if(im&&this._bss106AmbientBackground&&this._bss106CurrentSlot&&this._bss106CurrentSlot!=="day"&&this.bss106AmbientCanvas){
      const p=S(path).replace(/\\/g,"/");
      if(/\/Battlebacks\/(?:battlebg|base)\//i.test(p)){
        return this.bss106AmbientCanvas(im,this._bss106CurrentSlot);
      }
    }
    return im;
  };
  const _skyCompBase=App.prototype.bss083EBDXComposite;
  App.prototype.bss083EBDXComposite=async function(canvas,view){const prev=this._bss099SkyOverride;this._bss099SkyOverride=this.bss099SkyOverridePath(view);try{return await _skyCompBase.call(this,canvas,view);}finally{this._bss099SkyOverride=prev;}};

  const _skyInputBase=App.prototype.onInput;
  App.prototype.onInput=function(e){const t=e&&e.target;if(t&&t.dataset){const scene=this.bss088SceneFromState(),r=scene&&scene.kind==="custom"?this.bss089CurrentCustomRow():null;if(t.dataset.bss099SkyMode!=null&&r){this.bss089HistoryCheckpoint("Cambiar cielo");r.data=r.data||{};r.data.skyMode=S(t.value||"dynamic");r.data.sky=true;this._bss104ImageCache&&this._bss104ImageCache.clear();this.saveSoon();this.bss089RefreshInspectorOnly();this.bss089RedrawPreview();return;}if(t.dataset.bss099SkyCustom!=null&&r){r.data=r.data||{};r.data.skyMode=S(t.value||"dynamic");this._bss104ImageCache&&this._bss104ImageCache.clear();this.saveSoon();this.bss089RedrawPreview();return;}if(t.dataset.bss099SkyEnabled!=null&&r){r.data=r.data||{};r.data.sky=!!t.checked;this._bss104ImageCache&&this._bss104ImageCache.clear();this.saveSoon();this.bss089RedrawPreview();return;}}return _skyInputBase.call(this,e);};
})();

// ============================================================================
// BSS v0.8.20 - Composer usability + exact edit overlays + project tile crops
// ============================================================================
(function(){
  if(typeof App==="undefined")return;

  // ------------------------------------------------------------------------
  // Never lose the user's place in the inspector just because a parameter
  // changed. Rebuild only the inspector content and restore scroll/focus.
  // ------------------------------------------------------------------------
  App.prototype.bss100InspectorState=function(old){
    if(!old)return null;
    const scroller=old.querySelector('.bss092-inspector-body')||old,active=document.activeElement,inside=active&&old.contains(active),state={scroll:scroller.scrollTop||0,inside:false,selector:"",start:null,end:null};
    if(inside){
      state.inside=true;
      const ds=active.dataset||{},pairs=["ebdxLayer","bss099BlurField","bss093WarpMode","bss093WarpQuality","bss094WarpTool","bss095Blur","bss099SkyMode","bss100CropEdit"];
      for(const k of pairs){if(ds[k]!=null){state.selector=`[data-${k.replace(/[A-Z]/g,m=>"-"+m.toLowerCase())}="${CSS.escape(S(ds[k]))}"]`;break;}}
      if(!state.selector&&active.name)state.selector=`[name="${CSS.escape(active.name)}"]`;
      try{state.start=active.selectionStart;state.end=active.selectionEnd;}catch(_){ }
    }
    return state;
  };
  App.prototype.bss100RestoreInspectorState=function(next,state){
    if(!next||!state)return;const scroller=next.querySelector('.bss092-inspector-body')||next;scroller.scrollTop=state.scroll||0;
    if(state.inside&&state.selector){const el=next.querySelector(state.selector);if(el){try{el.focus({preventScroll:true});if(state.start!=null&&el.setSelectionRange)el.setSelectionRange(state.start,state.end==null?state.start:state.end);}catch(_){}}}
    scroller.scrollTop=state.scroll||0;
  };
  App.prototype.bss089RefreshInspectorOnly=function(){
    const old=this.body&&this.body.querySelector(".bss088-inspector"),scene=this.bss088SceneFromState();if(!old||!scene)return;
    const state=this.bss100InspectorState(old),tmp=document.createElement("div");tmp.innerHTML=this.bss088SceneInspectorHTML(scene);const next=tmp.firstElementChild;
    if(next&&this.bss099SafeReplace(old,next)){this.bss100RestoreInspectorState(next,state);this.bss092WireComfort&&this.bss092WireComfort();}
    this.bss089UpdateHistoryButtons();
  };

  // ------------------------------------------------------------------------
  // Asset inventory: native EBDX elements + curated SceneAssets + project
  // tilesets. No artificial 80/140-result ceiling in the full browser.
  // ------------------------------------------------------------------------
  App.prototype.bss087SceneAssetRows=function(){
    const all=A(this.source&&this.source.allGraphics),out=[],seen=new Set();
    for(const x of all){
      const p=S(x&&x.projectPath).replace(/\\/g,"/");if(!p||seen.has(L(p)))continue;
      if(/\.txt$/i.test(p)||/\/references\//i.test(p)||/\/_licenses\//i.test(p)||/\/licenses?\//i.test(p))continue;
      const scene=/^Graphics\/BattleSceneStudio\/EBDX\/SceneAssets\//i.test(p),native=/^Graphics\/BattleSceneStudio\/EBDX\/Battlebacks\/elements\//i.test(p),tiles=/^Graphics\/Tilesets\//i.test(p);
      if(!scene&&!native&&!tiles)continue;
      if(scene&&/\/SceneAssets\/Tilesets\//i.test(p))continue;
      seen.add(L(p));out.push(Object.assign({},x,{projectPath:p,name:S(x&&x.name)||p.split("/").pop()}));
    }
    return out.sort((a,b)=>this.bss088AssetCategoryOf(a.projectPath).localeCompare(this.bss088AssetCategoryOf(b.projectPath),undefined,{numeric:true,sensitivity:"base"})||S(a.name).localeCompare(S(b.name),undefined,{numeric:true,sensitivity:"base"}));
  };
  App.prototype.bss088AssetCategoryOf=function(path){
    const p=S(path).replace(/\\/g,"/");
    if(/^Graphics\/Tilesets\//i.test(p))return "Proyecto · Tilesets";
    if(/\/Battlebacks\/elements\//i.test(p))return "EBDX · Elementos";
    const m=p.match(/SceneAssets\/([^/]+)(?:\/([^/]+))?/i);if(!m)return "Otros";
    if(L(m[1])==="cutouts"){
      const sub=L(m[2]);return "Recortes · "+({vegetationclean:"Vegetación",clouds:"Nubes",space:"Espacio",lights:"Luces"}[sub]||S(m[2]||"Otros"));
    }
    return S(m[1]);
  };
  App.prototype.bss088AssetRows=function(){return this.bss087SceneAssetRows();};
  App.prototype.bss100AssetMatches=function(){
    const all=this.bss088AssetRows(),cat=S(this.ebdx088AssetCategory||"all"),q=L(this.ebdx088AssetSearch||"");
    return all.filter(x=>(cat==="all"||this.bss088AssetCategoryOf(x.projectPath)===cat)&&(!q||L(`${x.name||""} ${x.projectPath||""} ${this.bss088AssetCategoryOf(x.projectPath)}`).includes(q)));
  };
  App.prototype.bss089ElementsDockHTML=function(scene){
    if(!scene||scene.kind!=="custom")return `<div class="bss089-elements-empty"><b>Escenario de solo lectura</b><span>Duplica el fondo para añadir elementos.</span></div>`;
    const all=this.bss088AssetRows(),cats=[...new Set(all.map(x=>this.bss088AssetCategoryOf(x.projectPath)))].sort(),cat=S(this.ebdx088AssetCategory||"all"),rows=this.bss100AssetMatches(),shown=rows.slice(0,64);
    const builtin=["fog","forestShade","mountain","rocks","pillars001","pillars002","shade","snow","star","sun","tree","treeB","treeC","treePine","tallGrass","seaWeed","decor005","decor006","decor009"];
    return `<section class="bss089-elements bss100-elements-dock"><div class="bss100-elements-head"><div><b>Elementos</b><small>${rows.length} resultados · ${all.length} disponibles</small></div><button type="button" class="bss-btn primary small" data-bss100-open-assets>⛶ Navegador grande</button></div><div class="bss089-element-search"><input class="bss-search" data-bss088-asset-search placeholder="Buscar por nombre, carpeta o categoría…" value="${E(this.ebdx088AssetSearch||"")}"></div><select class="bss-select bss100-dock-category" data-bss100-asset-category><option value="all">Todas las categorías</option>${cats.map(c=>`<option value="${E(c)}" ${cat===c?"selected":""}>${E(c)}</option>`).join("")}</select><div class="bss089-quick-elements">${builtin.map(n=>`<button type="button" data-bss088-element-add="${E(n)}">＋ ${E(n)}</button>`).join("")}</div><div class="bss089-element-list">${shown.map(x=>`<button type="button" class="bss089-element-row" data-bss087-asset-add="${E(x.projectPath)}"><span class="bss087-asset-thumb" data-bss087-asset-thumb="${E(x.projectPath)}"></span><span><b>${E(x.name||x.projectPath.split('/').pop())}</b><small>${E(this.bss088AssetCategoryOf(x.projectPath))}</small></span><strong>${/^Graphics\/Tilesets\//i.test(x.projectPath)?"✂":"＋"}</strong></button>`).join("")||'<div class="bss-empty">Sin resultados.</div>'}${rows.length>shown.length?`<button class="bss-btn bss100-more-assets" type="button" data-bss100-open-assets>Ver los ${rows.length} resultados →</button>`:""}</div></section>`;
  };

  App.prototype.bss100AssetBrowserHTML=function(){
    const all=this.bss088AssetRows(),cats=[...new Set(all.map(x=>this.bss088AssetCategoryOf(x.projectPath)))].sort(),cat=S(this.ebdx088AssetCategory||"all"),rows=this.bss100AssetMatches();
    return `<div class="bss100-asset-modal" data-bss100-asset-modal><button class="bss100-modal-shade" data-bss100-close-assets aria-label="Cerrar"></button><section class="bss100-asset-card"><header><div><b>Navegador de elementos</b><small>${rows.length} resultados · Scene Assets, EBDX y Graphics/Tilesets</small></div><button type="button" class="bss-btn" data-bss100-close-assets>✕ Cerrar</button></header><div class="bss100-asset-search"><input class="bss-search" data-bss100-asset-search autofocus placeholder="Buscar árbol, cielo, ruina, agua, tileset…" value="${E(this.ebdx088AssetSearch||"")}"></div><div class="bss100-asset-layout"><aside>${['all',...cats].map(c=>`<button type="button" class="${cat===c?"active":""}" data-bss100-asset-cat="${E(c)}">${E(c==='all'?'Todos':c)} <span>${c==='all'?all.length:all.filter(x=>this.bss088AssetCategoryOf(x.projectPath)===c).length}</span></button>`).join("")}</aside><main class="bss100-asset-grid">${rows.map(x=>`<button type="button" class="bss100-asset-item" data-bss100-use-asset="${E(x.projectPath)}"><span class="bss087-asset-thumb"><img loading="lazy" data-bss100-asset-thumb="${E(x.projectPath)}" alt=""></span><b>${E(x.name||x.projectPath.split('/').pop())}</b><small>${E(this.bss088AssetCategoryOf(x.projectPath))}</small><em>${/^Graphics\/Tilesets\//i.test(x.projectPath)?"Seleccionar tile/área":"Añadir"}</em></button>`).join("")||'<div class="bss-empty">No hay resultados.</div>'}</main></div></section></div>`;
  };
  App.prototype.bss100OpenAssetBrowser=function(){
    let old=this.root&&this.root.querySelector('[data-bss100-asset-modal]');if(old)old.remove();const wrap=document.createElement('div');wrap.innerHTML=this.bss100AssetBrowserHTML();const node=wrap.firstElementChild;if(node)this.root.appendChild(node);this.bss100HydrateAssetThumbs();
  };
  App.prototype.bss100RefreshAssetBrowser=function(){const old=this.root&&this.root.querySelector('[data-bss100-asset-modal]');if(!old)return;const active=document.activeElement,wasSearch=active&&active.matches&&active.matches('[data-bss100-asset-search]'),tmp=document.createElement('div');tmp.innerHTML=this.bss100AssetBrowserHTML();const next=tmp.firstElementChild;if(next&&old.parentNode){old.parentNode.replaceChild(next,old);this.bss100HydrateAssetThumbs();if(wasSearch){const q=next.querySelector('[data-bss100-asset-search]');if(q){q.focus({preventScroll:true});q.setSelectionRange(q.value.length,q.value.length);}}}};
  App.prototype.bss100HydrateAssetThumbs=async function(){if(!this.root)return;for(const im of [...this.root.querySelectorAll('img[data-bss100-asset-thumb]')]){try{const url=await this.assetUrl({projectPath:S(im.dataset.bss100AssetThumb)});if(url&&im.isConnected)im.src=url;}catch(_){}}};

  // ------------------------------------------------------------------------
  // Non-destructive source crop. Project tilesets are referenced from their
  // original Graphics/Tilesets file; only crop coordinates are stored.
  // ------------------------------------------------------------------------
  App.prototype.bss100CropCanvas=async function(path,crop){
    const im=await this.bss083LoadImage(path);if(!im)return null;const x=Math.max(0,Math.min(im.width-1,N(crop&&crop.x,0))),y=Math.max(0,Math.min(im.height-1,N(crop&&crop.y,0))),w=Math.max(1,Math.min(im.width-x,N(crop&&crop.w,im.width))),h=Math.max(1,Math.min(im.height-y,N(crop&&crop.h,im.height))),c=document.createElement('canvas');c.width=w;c.height=h;c.getContext('2d').drawImage(im,x,y,w,h,0,0,w,h);return {canvas:c,url:c.toDataURL('image/png'),x,y,w,h,image:im};
  };
  const _rasterBase100=App.prototype.bss099RasterLayer;
  App.prototype.bss099RasterLayer=async function(sceneId,key,d){
    if(!d||typeof d!=="object")return null;const crop=d.crop&&typeof d.crop==="object"?d.crop:null;if(!crop)return _rasterBase100.call(this,sceneId,key,d);
    const path=this.bss083EBDXAssetPath("elements",d.bitmap),cc=await this.bss100CropCanvas(path,crop);if(!cc)return _rasterBase100.call(this,sceneId,key,d);
    const clone=JSON.parse(JSON.stringify(d));clone.bitmap=cc.url;clone.ox=d.ox!=null?N(d.ox,cc.image.width/2)-cc.x:cc.w/2;clone.oy=d.oy!=null?N(d.oy,cc.image.height)-cc.y:cc.h;delete clone.crop;
    const r=await _rasterBase100.call(this,sceneId,key,clone);if(r)return r;
    const fp=`crop|${sceneId}|${key}|${S(d.bitmap)}|${cc.x},${cc.y},${cc.w},${cc.h}`;return {canvas:cc.canvas,url:cc.url,ox:clone.ox,oy:clone.oy,fingerprint:fp};
  };
  App.prototype.bss100OpenCropper=async function(path,key=""){
    const scene=this.bss088SceneFromState(),d=key&&scene&&scene.data&&scene.data[key],resolved=/^Graphics\//i.test(S(path))?S(path):this.bss083EBDXAssetPath('elements',path),url=await this.assetUrl({projectPath:resolved}).catch(()=>null);if(!url){this.toast('No se pudo abrir el gráfico para recortar.',true);return;}
    const old=this.root.querySelector('[data-bss100-crop-modal]');if(old)old.remove();const modal=document.createElement('div');modal.className='bss100-crop-modal';modal.dataset.bss100CropModal='1';const isTile=/^Graphics\/Tilesets\//i.test(resolved),crop=d&&d.crop&&typeof d.crop==='object'?d.crop:null;
    modal.innerHTML=`<button class="bss100-modal-shade" data-bss100-crop-close></button><section class="bss100-crop-card"><header><div><b>${isTile?'Importar tile/área del proyecto':'Recortar elemento'}</b><small>${E(resolved.replace(/^Graphics\//,''))} · no se duplica el archivo fuente</small></div><button class="bss-btn" type="button" data-bss100-crop-close>✕</button></header><div class="bss100-crop-toolbar"><label>Grid <select class="bss-select" data-bss100-crop-grid><option value="0">Libre</option>${[8,16,24,32,48,64].map(n=>`<option value="${n}" ${n===(isTile?32:0)?'selected':''}>${n}px</option>`).join('')}</select></label><span data-bss100-crop-info>Arrastra sobre la imagen.</span></div><div class="bss100-crop-stage"><canvas data-bss100-crop-canvas></canvas></div><footer><button class="bss-btn" type="button" data-bss100-crop-full>Usar imagen completa</button><div class="bss-spacer"></div><button class="bss-btn primary" type="button" data-bss100-crop-apply>${key?'Aplicar recorte':'Añadir selección al escenario'}</button></footer></section>`;this.root.appendChild(modal);
    const canvas=modal.querySelector('[data-bss100-crop-canvas]'),img=new Image();img.onload=()=>{canvas.width=img.naturalWidth;canvas.height=img.naturalHeight;let sel=crop?{x:N(crop.x,0),y:N(crop.y,0),w:N(crop.w,32),h:N(crop.h,32)}:{x:0,y:0,w:Math.min(isTile?32:img.naturalWidth,img.naturalWidth),h:Math.min(isTile?32:img.naturalHeight,img.naturalHeight)},drag=null;modal._bss100Selection=()=>sel;modal._bss100Path=resolved;modal._bss100Key=key;
      const snap=(v,g)=>g>0?Math.floor(v/g)*g:Math.round(v),draw=()=>{const g=canvas.getContext('2d');g.imageSmoothingEnabled=false;g.clearRect(0,0,canvas.width,canvas.height);g.drawImage(img,0,0);const grid=N(modal.querySelector('[data-bss100-crop-grid]').value,0);if(grid>0){g.save();g.strokeStyle='rgba(120,190,255,.22)';g.lineWidth=1;for(let x=0;x<=canvas.width;x+=grid){g.beginPath();g.moveTo(x,0);g.lineTo(x,canvas.height);g.stroke();}for(let y=0;y<=canvas.height;y+=grid){g.beginPath();g.moveTo(0,y);g.lineTo(canvas.width,y);g.stroke();}g.restore();}g.save();g.fillStyle='rgba(20,35,55,.45)';g.fillRect(0,0,canvas.width,sel.y);g.fillRect(0,sel.y+sel.h,canvas.width,canvas.height-(sel.y+sel.h));g.fillRect(0,sel.y,sel.x,sel.h);g.fillRect(sel.x+sel.w,sel.y,canvas.width-(sel.x+sel.w),sel.h);g.strokeStyle='#69b2ff';g.lineWidth=2;g.strokeRect(sel.x+.5,sel.y+.5,sel.w,sel.h);g.restore();const info=modal.querySelector('[data-bss100-crop-info]');if(info)info.textContent=`X ${sel.x} · Y ${sel.y} · ${sel.w}×${sel.h}`;};
      const pt=ev=>{const r=canvas.getBoundingClientRect();return {x:(ev.clientX-r.left)*canvas.width/Math.max(1,r.width),y:(ev.clientY-r.top)*canvas.height/Math.max(1,r.height)}};
      const move=ev=>{if(!drag)return;const p=pt(ev),grid=N(modal.querySelector('[data-bss100-crop-grid]').value,0),x=snap(Math.min(drag.x,p.x),grid),y=snap(Math.min(drag.y,p.y),grid),x2=grid>0?Math.ceil(Math.max(drag.x,p.x)/grid)*grid:Math.round(Math.max(drag.x,p.x)),y2=grid>0?Math.ceil(Math.max(drag.y,p.y)/grid)*grid:Math.round(Math.max(drag.y,p.y));sel={x:Math.max(0,x),y:Math.max(0,y),w:Math.max(grid||1,Math.min(canvas.width,x2)-Math.max(0,x)),h:Math.max(grid||1,Math.min(canvas.height,y2)-Math.max(0,y))};draw();ev.preventDefault();};
      const up=()=>{drag=null;window.removeEventListener('pointermove',move);window.removeEventListener('pointerup',up);};canvas.addEventListener('pointerdown',ev=>{const p=pt(ev),grid=N(modal.querySelector('[data-bss100-crop-grid]').value,0);drag={x:snap(p.x,grid),y:snap(p.y,grid)};sel={x:drag.x,y:drag.y,w:grid||1,h:grid||1};draw();window.addEventListener('pointermove',move,{passive:false});window.addEventListener('pointerup',up);ev.preventDefault();});modal.querySelector('[data-bss100-crop-grid]').addEventListener('change',draw);draw();};img.src=url;
  };

  // Crop controls in the selected image inspector.
  const _layerInspector100=App.prototype.bss088LayerInspectorHTML;
  App.prototype.bss088LayerInspectorHTML=function(scene){let html=_layerInspector100.call(this,scene);html=html.replace(/<section class="bss088-inspector-section bss095-blur"[\s\S]*?<\/section>/,"");const t=this.bss088SelectedTarget(scene);if(!t||t.type!=="img")return html;const key=this.bss092TargetId(t),d=t.data,ro=scene.kind!=="custom",crop=d.crop,box=`<section class="bss088-inspector-section bss100-source-crop"><div class="bss088-section-title"><div><b>Fuente y recorte</b><small>Usa una parte del gráfico o de Graphics/Tilesets sin duplicar el PNG.</small></div></div><div class="bss-row"><button type="button" class="bss-btn" data-bss100-crop-layer="${E(key)}" ${ro?'disabled':''}>✂ ${crop?'Editar recorte':'Recortar gráfico'}</button>${crop?`<span class="bss-note">${N(crop.x,0)}, ${N(crop.y,0)} · ${N(crop.w,0)}×${N(crop.h,0)}</span>`:''}</div></section>`;const mark='<section class="bss088-inspector-section"><div class="bss088-section-title"><div><b>Comportamiento';const pos=html.indexOf(mark);return pos>=0?html.slice(0,pos)+box+html.slice(pos):html+box;};

  // ------------------------------------------------------------------------
  // Warp guides were hidden in v0.8.19 because the preview raster clone deleted
  // `warp`. Draw controls from the ORIGINAL scene after the exact raster render.
  // ------------------------------------------------------------------------
  const _composite100=App.prototype.bss083EBDXComposite;
  App.prototype.bss083EBDXComposite=async function(canvas,view){
    const state=await _composite100.call(this,canvas,view);if(!state||!canvas||!view||view.kind!=="custom")return state;
    try{
      const key=S(this.ebdx088SelectedLayer),d=view.data&&view.data[key],cfg=this.bss093WarpConfig(d);if(!cfg)return state;const game=canvas.width===640&&typeof this.bss095MainProjection==="function",q=game?this.bss095MainProjection():null,ctx=canvas.getContext('2d'),editing=S(this.ebdx093WarpEditKey)===key,map=p=>game?[p[0]*q.scale+q.tx,p[1]*q.scale+q.ty]:p;
      const pts=cfg.points.map((p,i)=>{const l=this.bss093WarpAuthorPoint(d,p),g=map(l);return {key,index:i,row:Math.floor(i/cfg.cols),col:i%cfg.cols,x:l[0],y:l[1],gameX:g[0],gameY:g[1]};});state.warpHandles=pts;
      ctx.save();ctx.lineWidth=editing?2:1.25;ctx.strokeStyle=editing?'rgba(105,178,255,.98)':'rgba(105,178,255,.58)';ctx.setLineDash(editing?[]:[5,4]);for(let r=0;r<cfg.rows;r++){ctx.beginPath();for(let c=0;c<cfg.cols;c++){const p=pts[r*cfg.cols+c];c?ctx.lineTo(p.gameX,p.gameY):ctx.moveTo(p.gameX,p.gameY);}ctx.stroke();}for(let c=0;c<cfg.cols;c++){ctx.beginPath();for(let r=0;r<cfg.rows;r++){const p=pts[r*cfg.cols+c];r?ctx.lineTo(p.gameX,p.gameY):ctx.moveTo(p.gameX,p.gameY);}ctx.stroke();}ctx.setLineDash([]);if(editing){for(const p of pts){ctx.beginPath();ctx.fillStyle=(p.row===0||p.row===cfg.rows-1)&&(p.col===0||p.col===cfg.cols-1)?'#ffcf6d':'#69b2ff';ctx.strokeStyle='#08101a';ctx.lineWidth=2;ctx.arc(p.gameX,p.gameY,7,0,Math.PI*2);ctx.fill();ctx.stroke();}}ctx.restore();
    }catch(_){ }
    return state;
  };

  // Make the two direct manipulation modes unmissable in the quick bar.
  const _quick100=App.prototype.bss092QuickBarHTML;
  App.prototype.bss092QuickBarHTML=function(scene){let html=_quick100.call(this,scene),t=this.bss088SelectedTarget(scene);if(!t||t.type!=="img"||scene.kind!=="custom")return html;const key=this.bss092TargetId(t),blur=this.ebdx100CanvasTool==='blur',buttons=`<button type="button" class="bss100-canvas-tool ${blur?'active':''}" data-bss100-blur-tool="${E(key)}">☁ Difuminar área</button>`;const i=html.lastIndexOf('</div>');return i>=0?html.slice(0,i)+buttons+html.slice(i):html+buttons;};

  // ------------------------------------------------------------------------
  // Local blur = draw the area directly on canvas. Click+drag defines center
  // and radius; exact values remain editable in the inspector afterwards.
  // ------------------------------------------------------------------------
  const _hydrate100=App.prototype.hydrateEBDXStudioPreview;
  App.prototype.hydrateEBDXStudioPreview=async function(){const ret=await _hydrate100.call(this),canvas=this.body&&this.body.querySelector('.bss089-main-preview canvas');if(!canvas||canvas._bss100Tools)return ret;canvas._bss100Tools=true;canvas.addEventListener('pointerdown',ev=>{if(this.ebdx100CanvasTool!=='blur')return;const scene=this.bss088SceneFromState(),key=S(this.ebdx088SelectedLayer),d=scene&&scene.kind==='custom'&&scene.data&&scene.data[key];if(!d)return;const p=this.bss095PointerLogical(canvas,ev),local=this.bss093WarpLocalFromAuthor(d,p.x,p.y),area={x:Math.round(local[0]),y:Math.round(local[1]),radius:8,strength:4,feather:6};this.bss089HistoryCheckpoint('Difuminar área');const arr=this.bss099BlurAreas(d);arr.push(area);const startLocal={x:local[0],y:local[1]},move=e2=>{const q=this.bss095PointerLogical(canvas,e2),ql=this.bss093WarpLocalFromAuthor(d,q.x,q.y),r=Math.max(8,Math.hypot(ql[0]-startLocal.x,ql[1]-startLocal.y));area.radius=Math.round(r);area.feather=Math.max(4,Math.round(r*.28));this.saveSoon();this.bss089RedrawPreview();e2.preventDefault();},up=()=>{window.removeEventListener('pointermove',move);window.removeEventListener('pointerup',up);this.ebdx100CanvasTool='';this.saveSoon();this.bss089RefreshInspectorOnly();this.bss089RefreshQuickBar();this.bss089RedrawPreview();};window.addEventListener('pointermove',move,{passive:false});window.addEventListener('pointerup',up);this.saveSoon();this.bss089RedrawPreview();ev.preventDefault();ev.stopImmediatePropagation();},true);return ret;};

  // ------------------------------------------------------------------------
  // Metadata is its own Studio tab: general -> encounter context -> map.
  // ------------------------------------------------------------------------
  App.prototype.bss100MetadataHTML=function(){
    const g=this.bss079EnsureEBDXConfig(),choices=this.ebdxBackdropChoices(false),rows=A(g.ebdxEncounterMetadata),known=['Land','Cave','Water','Fishing','Surf','OldRod','GoodRod','SuperRod','RockSmash','Headbutt','BugContest','Indoor','Underwater','Night'];
    const context=`<section class="bss079-config-block"><div class="bss079-section-head"><div><b>Contexto / Encounter Type</b><small>Un contexto explícito gana al fondo general. Puedes escribir el ID real de un EncounterType del proyecto.</small></div></div><div class="bss079-map-assign"><label class="bss-mini-field"><span>Encounter type / contexto</span><input class="bss-input" list="bss100-encounters" data-bss097-context-new placeholder="Land, Cave, Water, ..."></label><button type="button" class="bss-btn primary" data-bss097-context-add>＋ Añadir</button></div><datalist id="bss100-encounters">${known.map(x=>`<option value="${E(x)}"></option>`).join('')}</datalist><div class="bss079-map-list">${rows.map(r=>`<article class="bss079-map-row"><div><b>${E(S(r.context))}</b><small>Encounter/context override</small></div><select class="bss-select" data-bss097-context-bg="${E(S(r.context))}">${choices.map(x=>`<option value="${E(x.id)}" ${S(r.backdrop||'Auto')===S(x.id)?'selected':''}>${E(x.label)}</option>`).join('')}</select><button type="button" class="bss-btn danger small" data-bss097-context-remove="${E(S(r.context))}">Quitar</button></article>`).join('')||'<div class="bss-empty">Sin overrides por encounter type.</div>'}</div></section>`;
    return `<div class="bss079-config-page bss100-metadata"><section class="bss079-config-block"><div class="bss079-section-head"><div><b>Fondo general</b><small>Fallback EBDX del proyecto cuando no existe una regla más específica.</small></div></div><label class="bss-mini-field"><span>Escenario</span><select class="bss-select" data-studio-global="ebdxBackdrop">${choices.map(x=>`<option value="${E(x.id)}" ${S(g.ebdxBackdrop||'Auto')===S(x.id)?'selected':''}>${E(x.label)}</option>`).join('')}</select></label></section>${context}${this.bss079MapConfigHTML()}</div>`;
  };
  const _renderStudio100=App.prototype.renderEBDXStudio;
  App.prototype.renderEBDXStudio=function(){const out=_renderStudio100.call(this),nav=this.body&&this.body.querySelector('.bss079-ebdx-tabs'),content=this.body&&this.body.querySelector('.bss079-ebdx-content'),tab=S(this.ebdxStudioTab||'backgrounds');if(nav&&!nav.querySelector('[data-bss079-tab="metadata"]')){const b=document.createElement('button');b.type='button';b.dataset.bss079Tab='metadata';b.textContent='Metadata';nav.insertBefore(b,nav.querySelector('[data-bss079-tab="config"]')||null);}if(nav)[...nav.querySelectorAll('[data-bss079-tab]')].forEach(b=>b.classList.toggle('active',S(b.dataset.bss079Tab)===tab));if(tab==='metadata'&&content)content.innerHTML=this.bss100MetadataHTML();if(tab==='config'&&content){[...content.querySelectorAll('.bss079-config-block')].forEach(s=>{const h=s.querySelector('.bss079-section-head b');if(h&&['Metadata de fondos','Fondos por mapa'].includes(S(h.textContent).trim()))s.remove();});}return out;};

  // ------------------------------------------------------------------------
  // Unified final UI events.
  // ------------------------------------------------------------------------
  const _click100=App.prototype.onClick;
  App.prototype.onClick=function(e){
    const raw=e&&e.target,t=raw&&typeof raw.closest==='function'?raw.closest('[data-bss100-open-assets],[data-bss100-close-assets],[data-bss100-use-asset],[data-bss100-asset-cat],[data-bss100-crop-layer],[data-bss100-crop-close],[data-bss100-crop-full],[data-bss100-crop-apply],[data-bss100-blur-tool],[data-bss087-asset-add]'):null;
    if(t&&t.dataset){
      if(t.dataset.bss100OpenAssets!=null){this.bss100OpenAssetBrowser();return;}
      if(t.dataset.bss100CloseAssets!=null){const m=this.root.querySelector('[data-bss100-asset-modal]');if(m)m.remove();return;}
      if(t.dataset.bss100AssetCat!=null){this.ebdx088AssetCategory=S(t.dataset.bss100AssetCat||'all');this.bss100RefreshAssetBrowser();return;}
      if(t.dataset.bss100UseAsset!=null){const p=S(t.dataset.bss100UseAsset);if(/^Graphics\/Tilesets\//i.test(p)){this.bss100OpenCropper(p);return;}this.bss089HistoryCheckpoint('Añadir elemento');const key=this.bss088AddLayer(p,this.bss088AssetDefaults(p));this.ebdx089DockTab='layers';const m=this.root.querySelector('[data-bss100-asset-modal]');if(m)m.remove();this.renderEBDXStudio();return;}
      if(t.dataset.bss087AssetAdd!=null&&/^Graphics\/Tilesets\//i.test(S(t.dataset.bss087AssetAdd))){this.bss100OpenCropper(S(t.dataset.bss087AssetAdd));return;}
      if(t.dataset.bss100CropLayer!=null){const scene=this.bss088SceneFromState(),key=S(t.dataset.bss100CropLayer),d=scene&&scene.data&&scene.data[key];if(d)this.bss100OpenCropper(this.bss083EBDXAssetPath('elements',d.bitmap),key);return;}
      if(t.dataset.bss100CropClose!=null){const m=this.root.querySelector('[data-bss100-crop-modal]');if(m)m.remove();return;}
      if(t.dataset.bss100CropFull!=null){const m=this.root.querySelector('[data-bss100-crop-modal]'),key=m&&m._bss100Key,scene=this.bss088SceneFromState(),d=key&&scene&&scene.data&&scene.data[key];if(d){this.bss089HistoryCheckpoint('Quitar recorte');delete d.crop;delete d.runtimeRaster;this.saveSoon();m.remove();this.bss089RefreshSelectionPanels();this.bss089RedrawPreview();}else if(m){const c=m.querySelector('[data-bss100-crop-canvas]');if(c)m._bss100Selection=()=>({x:0,y:0,w:c.width,h:c.height});const apply=m.querySelector('[data-bss100-crop-apply]');if(apply)apply.click();}return;}
      if(t.dataset.bss100CropApply!=null){const m=this.root.querySelector('[data-bss100-crop-modal]');if(!m||typeof m._bss100Selection!=='function')return;const sel=m._bss100Selection(),crop={x:Math.round(sel.x),y:Math.round(sel.y),w:Math.max(1,Math.round(sel.w)),h:Math.max(1,Math.round(sel.h)),rebase:true},key=S(m._bss100Key||''),scene=this.bss088SceneFromState();if(key&&scene&&scene.data&&scene.data[key]){const d=scene.data[key];this.bss089HistoryCheckpoint('Recortar '+key);d.crop=crop;delete d.warp;delete d.runtimeRaster;this.ebdx093WarpEditKey='';}else{const p=S(m._bss100Path),opts=this.bss088AssetDefaults(p);opts.crop=crop;delete opts.scrolling;delete opts.effect;this.bss089HistoryCheckpoint('Añadir recorte de proyecto');this.bss088AddLayer(p,opts);this.ebdx089DockTab='layers';}this.saveSoon();m.remove();this.renderEBDXStudio();return;}
      if(t.dataset.bss100BlurTool!=null){const key=S(t.dataset.bss100BlurTool);this.ebdx088SelectedLayer=key;this.ebdx100CanvasTool=this.ebdx100CanvasTool==='blur'?'':'blur';this._bss099BlurPlacement=null;this.bss089RefreshQuickBar();this.bss089RedrawPreview();return;}
    }
    return _click100.call(this,e);
  };
  const _input100=App.prototype.onInput;
  App.prototype.onInput=function(e){const t=e&&e.target;if(t&&t.dataset){if(t.dataset.bss100AssetSearch!=null){this.ebdx088AssetSearch=S(t.value);this.bss100RefreshAssetBrowser();return;}if(t.dataset.bss100AssetCategory!=null){this.ebdx088AssetCategory=S(t.value||'all');this.bss089RefreshDock();return;}}return _input100.call(this,e);};

  const _key100=App.prototype.onKeyDown;
  App.prototype.onKeyDown=function(e){if(e&&e.key==='Escape'){if(this.ebdx100CanvasTool||this.ebdx093WarpEditKey||this._bss099BlurPlacement){this.ebdx100CanvasTool='';this.ebdx093WarpEditKey='';this._bss099BlurPlacement=null;this.bss089RefreshQuickBar();this.bss089RefreshInspectorOnly();this.bss089RedrawPreview();return;}}return _key100.call(this,e);};
})();

// BSS v0.8.20 - commit generated raster immediately after geometry/mask edits.
(function(){
  if(typeof App==="undefined")return;
  const _click=App.prototype.onClick;
  App.prototype.onClick=function(e){const raw=e&&e.target,t=raw&&typeof raw.closest==='function'?raw.closest('[data-bss093-warp-preset],[data-bss093-warp-action],[data-bss099-blur-add],[data-bss099-blur-remove],[data-bss099-blur-clear-all]'):null;const ret=_click.call(this,e);if(t)setTimeout(()=>{try{this.save(true);}catch(_){}},0);return ret;};
  const _input=App.prototype.onInput;
  App.prototype.onInput=function(e){const t=e&&e.target,commit=!!(t&&t.dataset&&(t.dataset.bss093WarpMode!=null||t.dataset.bss093WarpQuality!=null||t.dataset.bss099BlurField!=null)&&e.type==='change');const ret=_input.call(this,e);if(commit)setTimeout(()=>{try{this.save(true);}catch(_){}},0);return ret;};
  const _hydrate=App.prototype.hydrateEBDXStudioPreview;
  App.prototype.hydrateEBDXStudioPreview=async function(){const ret=await _hydrate.call(this),canvas=this.body&&this.body.querySelector('.bss089-main-preview canvas');if(canvas&&!canvas._bss100CommitListener){canvas._bss100CommitListener=true;canvas.addEventListener('pointerup',()=>{if(this.ebdx093WarpEditKey||this.ebdx100CanvasTool==='blur')setTimeout(()=>{try{this.save(true);}catch(_){}},0);});}return ret;};
})();


// BSS v0.8.20 - crop-only layers remain true references to the original project
// graphic. Generated PNGs are reserved for warp/local blur, where RGSS cannot
// reproduce the Canvas operation exactly from source coordinates alone.
(function(){
  if(typeof App==="undefined")return;
  App.prototype.bss099BakeRuntimeRasters=async function(){
    const rows=A(this.studio&&this.studio.global&&this.studio.global.ebdxCustomEnvironments);if(!rows.length)return;
    let madeDir=false;
    for(const scene of rows){const data=scene&&scene.data;if(!data||typeof data!=="object")continue;for(const key of Object.keys(data).filter(k=>/^img\d+/i.test(k))){const d=data[key];if(!d||typeof d!=="object")continue;const needsWarp=!!this.bss093WarpConfig(d),needsBlur=A(d.blurAreas).some(a=>a&&N(a.strength,0)>0&&(N(a.radius,0)>0||S(a.mode).startsWith("band")||S(a.mode)==="total"));if(!needsWarp&&!needsBlur){delete d.runtimeRaster;continue;}if(!madeDir){await this.ctx.fs.projectMkdir("Graphics/BattleSceneStudio/EBDX/Generated");madeDir=true;}const r=await this.bss099RasterLayer(scene.id||"scene",key,d);if(!r){delete d.runtimeRaster;continue;}const safeScene=S(scene.id||"scene").replace(/[^A-Za-z0-9_-]+/g,"_"),safeKey=S(key).replace(/[^A-Za-z0-9_-]+/g,"_"),path=`Graphics/BattleSceneStudio/EBDX/Generated/${safeScene}_${safeKey}.png`,bytes=await this.bss099CanvasBytes(r.canvas);await this.bss099WriteBinary(path,bytes);d.runtimeRaster={bitmap:path,ox:r.ox,oy:r.oy,fingerprint:r.fingerprint};}}
  };
})();

// BSS v0.8.20 - warp initialization respects a non-destructive source crop.
(function(){
  if(typeof App==="undefined")return;
  const _set=App.prototype.bss093SetWarpMode,_reset=App.prototype.bss093ResetWarp;
  App.prototype.bss100WithCropGeometry=async function(key,fn){const scene=this.bss088SceneFromState(),d=scene&&scene.kind==='custom'&&scene.data&&scene.data[key],crop=d&&d.crop;if(!d||!crop)return fn();const path=this.bss083EBDXAssetPath('elements',d.bitmap),cc=await this.bss100CropCanvas(path,crop);if(!cc)return fn();const old={bitmap:d.bitmap,hasOx:Object.prototype.hasOwnProperty.call(d,'ox'),ox:d.ox,hasOy:Object.prototype.hasOwnProperty.call(d,'oy'),oy:d.oy};d.bitmap=cc.url;d.ox=old.hasOx?N(old.ox,cc.image.width/2)-cc.x:cc.w/2;d.oy=old.hasOy?N(old.oy,cc.image.height)-cc.y:cc.h;try{return await fn();}finally{d.bitmap=old.bitmap;if(old.hasOx)d.ox=old.ox;else delete d.ox;if(old.hasOy)d.oy=old.oy;else delete d.oy;}};
  App.prototype.bss093SetWarpMode=async function(key,mode){const scene=this.bss088SceneFromState(),d=scene&&scene.data&&scene.data[key];if(!d||!d.crop||S(mode)==='off')return _set.call(this,key,mode);return this.bss100WithCropGeometry(key,()=>_set.call(this,key,mode));};
  App.prototype.bss093ResetWarp=async function(key){const scene=this.bss088SceneFromState(),d=scene&&scene.data&&scene.data[key];if(!d||!d.crop)return _reset.call(this,key);return this.bss100WithCropGeometry(key,()=>_reset.call(this,key));};
})();


// BSS v0.8.20.1 - warp authoring visibility hotfix.
// The selected layer remains live while its control mesh is active. Baked
// runtimeRaster is never the authoring source during point manipulation.
(function(){
  if(typeof App==="undefined")return;
  const _set=App.prototype.bss093SetWarpMode;
  App.prototype.bss093SetWarpMode=async function(key,mode){
    const ret=await _set.call(this,key,mode);
    if(S(mode)!=="off"){
      this.ebdx088SelectedLayer=S(key);
      this.ebdx093WarpEditKey=S(key);
      // Clear only transient raster cache entries. Do not touch runtimeRaster;
      // the game keeps its last valid baked result until geometry is committed.
      try{if(this._bss099RasterCache&&typeof this._bss099RasterCache.clear==="function")this._bss099RasterCache.clear();}catch(_){ }
      this.bss089RedrawPreview&&this.bss089RedrawPreview();
    }
    return ret;
  };
})();

// ============================================================================
// BSS v0.8.22 - Composer parity architecture
// One layer identity: Source -> Crop -> Local Blur -> Warp -> Transform.
// The preview renders the same composed geometry runtime receives and overlays
// editing controls separately. It also exposes battler screen guides and turns
// EBDX bases into optional movable/deformable layers without copying graphics.
// ============================================================================
(function(){
  if(typeof App==="undefined")return;

  const deep=v=>JSON.parse(JSON.stringify(v==null?{}:v));
  const imgKeys=data=>Object.keys(data||{}).filter(k=>/^img\d+/i.test(k)&&data[k]&&typeof data[k]==="object");

  // --------------------------------------------------------------------------
  // Single visual modifier pipeline. A layer never swaps identity when a tool
  // is enabled: the editor always composes from the original source reference.
  // --------------------------------------------------------------------------
  App.prototype.bss101LayerSource=async function(d){
    if(!d||typeof d!=="object")return null;
    const path=this.bss083EBDXAssetPath("elements",d.bitmap),im=await this.bss083LoadImage(path);if(!im)return null;
    let source=im,local=deep(d),sourceW=im.width,sourceH=im.height,cropInfo=null;
    const crop=d.crop&&typeof d.crop==="object"?d.crop:null;
    if(crop){
      const cc=await this.bss100CropCanvas(path,crop);if(!cc)return null;
      source=cc.canvas;sourceW=cc.w;sourceH=cc.h;cropInfo=cc;
      local.ox=d.ox!=null?N(d.ox,im.width/2)-cc.x:cc.w/2;
      local.oy=d.oy!=null?N(d.oy,im.height)-cc.y:cc.h;
      delete local.crop;
    }
    return {source,local,sourceW,sourceH,cropInfo,path};
  };

  App.prototype.bss101LayerVisual=async function(sceneId,key,d){
    if(!d||typeof d!=="object")return null;
    const hasCrop=!!(d.crop&&typeof d.crop==="object"),hasWarp=!!this.bss093WarpConfig(d),hasBlur=A(d.blurAreas).some(a=>a&&N(a.strength,0)>0&&(N(a.radius,0)>0||S(a.mode).startsWith("band")||S(a.mode)==="total"));
    if(!hasCrop&&!hasWarp&&!hasBlur)return null;
    const pack=await this.bss101LayerSource(d);if(!pack)return null;
    const local=pack.local,cfg=this.bss093WarpConfig(local),areas=A(local.blurAreas).filter(a=>a&&N(a.strength,0)>0&&(N(a.radius,0)>0||S(a.mode).startsWith("band")||S(a.mode)==="total"));
    const fingerprint=["104",S(sceneId),S(key),S(d.bitmap),JSON.stringify(d.crop||null),JSON.stringify(d.warp||null),JSON.stringify(d.blurAreas||[]),N(local.ox,-9999),N(local.oy,-9999)].join("|");
    this._bss101VisualCache=this._bss101VisualCache||new Map();const cached=this._bss101VisualCache.get(fingerprint);if(cached)return cached;
    let src=pack.source;
    if(areas.length)src=this.bss099BlurredSource(src,local);
    let out,ox,oy;
    if(cfg){
      const xs=cfg.points.map(p=>N(p&&p[0],0)),ys=cfg.points.map(p=>N(p&&p[1],0)),pad=4+Math.max(0,...areas.map(a=>N(a.strength,0)*2)),minX=Math.floor(Math.min(...xs)-pad),maxX=Math.ceil(Math.max(...xs)+pad),minY=Math.floor(Math.min(...ys)-pad),maxY=Math.ceil(Math.max(...ys)+pad);
      const destW=Math.max(1,maxX-minX),destH=Math.max(1,maxY-minY);
      out=document.createElement("canvas");out.width=destW;out.height=destH;const g=out.getContext("2d");
      try{
        const sCanvas=document.createElement("canvas");sCanvas.width=src.width;sCanvas.height=src.height;
        const sc=sCanvas.getContext("2d");sc.imageSmoothingEnabled=false;sc.drawImage(src,0,0);
        const sImg=sc.getImageData(0,0,src.width,src.height),sData=sImg.data;
        const dImg=g.createImageData(destW,destH),dData=dImg.data;
        const srcW=src.width,srcH=src.height;
        let q=Math.max(2,Math.min(6,N(cfg.quality,4))),segX=Math.max(1,(cfg.cols-1)*q),segY=Math.max(1,(cfg.rows-1)*q);
        while(segX*segY>256&&q>2){q--;segX=(cfg.cols-1)*q;segY=(cfg.rows-1)*q;}
        const dest=(u,v)=>{const p=this.bss093WarpSample(cfg,u,v);return [p[0]-minX,p[1]-minY];};
        const sp=(u,v)=>[u*srcW,v*srcH];
        const rasterTri=(d0,d1,d2,s0,s1,s2)=>{
          const bx0=Math.max(0,Math.floor(Math.min(d0[0],d1[0],d2[0]))),bx1=Math.min(destW-1,Math.ceil(Math.max(d0[0],d1[0],d2[0])));
          const by0=Math.max(0,Math.floor(Math.min(d0[1],d1[1],d2[1]))),by1=Math.min(destH-1,Math.ceil(Math.max(d0[1],d1[1],d2[1])));
          const denom=(d1[1]-d2[1])*(d0[0]-d2[0])+(d2[0]-d1[0])*(d0[1]-d2[1]);if(Math.abs(denom)<1e-6)return;
          for(let py=by0;py<=by1;py++){
            for(let px=bx0;px<=bx1;px++){
              const cx=px+0.5,cy=py+0.5;
              const w0=((d1[1]-d2[1])*(cx-d2[0])+(d2[0]-d1[0])*(cy-d2[1]))/denom;
              const w1=((d2[1]-d0[1])*(cx-d2[0])+(d0[0]-d2[0])*(cy-d2[1]))/denom;
              const w2=1-w0-w1;
              if(w0>=-0.001&&w1>=-0.001&&w2>=-0.001){
                const su=Math.max(0,Math.min(srcW-1,w0*s0[0]+w1*s1[0]+w2*s2[0])),sv=Math.max(0,Math.min(srcH-1,w0*s0[1]+w1*s1[1]+w2*s2[1]));
                const ix=Math.floor(su),iy=Math.floor(sv),sIdx=(iy*srcW+ix)*4,dIdx=(py*destW+px)*4;
                dData[dIdx]=sData[sIdx];dData[dIdx+1]=sData[sIdx+1];dData[dIdx+2]=sData[sIdx+2];dData[dIdx+3]=sData[sIdx+3];
              }
            }
          }
        };
        for(let iy=0;iy<segY;iy++)for(let ix=0;ix<segX;ix++){
          const u0=ix/segX,u1=(ix+1)/segX,v0=iy/segY,v1=(iy+1)/segY;
          const s00=sp(u0,v0),s10=sp(u1,v0),s11=sp(u1,v1),s01=sp(u0,v1);
          const p00=dest(u0,v0),p10=dest(u1,v0),p11=dest(u1,v1),p01=dest(u0,v1);
          rasterTri(p00,p10,p11,s00,s10,s11);
          rasterTri(p00,p11,p01,s00,s11,s01);
        }
        g.putImageData(dImg,0,0);
      }catch(_){
        g.imageSmoothingEnabled=true;
        let q=Math.max(2,Math.min(8,N(cfg.quality,4))),segX=Math.max(1,(cfg.cols-1)*q),segY=Math.max(1,(cfg.rows-1)*q);while(segX*segY>320&&q>2){q--;segX=(cfg.cols-1)*q;segY=(cfg.rows-1)*q;}
        const dest=(u,v)=>{const p=this.bss093WarpSample(cfg,u,v);return [p[0]-minX,p[1]-minY];},sp=(u,v)=>[u*src.width,v*src.height];
        for(let iy=0;iy<segY;iy++)for(let ix=0;ix<segX;ix++){
          const u0=ix/segX,u1=(ix+1)/segX,v0=iy/segY,v1=(iy+1)/segY,s00=sp(u0,v0),s10=sp(u1,v0),s11=sp(u1,v1),s01=sp(u0,v1),p00=dest(u0,v0),p10=dest(u1,v0),p11=dest(u1,v1),p01=dest(u0,v1);
          this.bss093DrawTexturedTriangle(g,src,s00,s10,s11,p00,p10,p11);this.bss093DrawTexturedTriangle(g,src,s00,s11,s01,p00,p11,p01);
        }
      }
      ox=-minX;oy=-minY;
    }else{
      out=document.createElement("canvas");out.width=src.width;out.height=src.height;const g=out.getContext("2d");g.imageSmoothingEnabled=false;g.drawImage(src,0,0);ox=local.ox!=null?N(local.ox,0):src.width/2;oy=local.oy!=null?N(local.oy,0):src.height;
    }
    const result={canvas:out,url:out.toDataURL("image/png"),ox,oy,fingerprint,local,source:pack.source};this._bss101VisualCache.set(fingerprint,result);
    if(this._bss101VisualCache.size>96)this._bss101VisualCache.delete(this._bss101VisualCache.keys().next().value);
    return result;
  };

  // Runtime baking uses the same pipeline as the editor. Crop-only remains a
  // source reference at runtime; warp/blur gets one generated exact PNG.
  App.prototype.bss099RasterLayer=async function(sceneId,key,d){
    if(!d||typeof d!=="object")return null;
    const needsWarp=!!this.bss093WarpConfig(d),needsBlur=A(d.blurAreas).some(a=>a&&N(a.strength,0)>0&&(N(a.radius,0)>0||S(a.mode).startsWith("band")||S(a.mode)==="total"));
    if(!needsWarp&&!needsBlur)return null;
    return this.bss101LayerVisual(sceneId,key,d);
  };

  // --------------------------------------------------------------------------
  // Logical EBDX compositor. Built-in water, vegetation and custom img layers
  // share one Z-sorted stack. Water is no longer unconditionally painted last.
  // --------------------------------------------------------------------------
  const _bss101OldComposite=App.prototype.bss083EBDXComposite;
  App.prototype.bss101LogicalComposite=async function(view){
    const data=view&&view.data||{},logical=document.createElement("canvas");logical.width=384;logical.height=308;const ctx=logical.getContext("2d");ctx.imageSmoothingEnabled=false;
    // Ask the existing source-faithful composer only for backdrop/base/sky.
    const baseData=deep(data);delete baseData.water;delete baseData.trees;delete baseData.tallGrass;imgKeys(baseData).forEach(k=>delete baseData[k]);
    const base=document.createElement("canvas");base.width=384;base.height=308;try{const suppress=!!(data.sky&&data.cloudsConfig&&typeof data.cloudsConfig==="object");this._bss102SuppressClouds=suppress;const baseState=await _bss101OldComposite.call(this,base,Object.assign({},view,{data:baseData,kind:"builtin"}));this._bss102SuppressClouds=false;if(base&&base.width&&base.height)ctx.drawImage(base,0,0);else if(baseState&&baseState.canvas)ctx.drawImage(baseState.canvas,0,0);}catch(_){this._bss102SuppressClouds=false;ctx.fillStyle="#182331";ctx.fillRect(0,0,384,308);}

    const ops=[],push=(z,order,draw,id)=>ops.push({z:N(z,0),order,id,draw});
    const groupOp=async(groupName,def,order)=>{const g=data[groupName];if(!g||typeof g!=="object")return;const im0=await this.bss083LoadImage(this.bss083EBDXAssetPath("elements",g.bitmap||def));if(!im0)return;const n=Math.max(0,N(g.elements,Array.isArray(g.x)?g.x.length:0));for(let i=0;i<n;i++){
      const x=Array.isArray(g.x)?N(g.x[i],0):0,y=Array.isArray(g.y)?N(g.y[i],0):0,zoom=Array.isArray(g.zoom)?N(g.zoom[i],1):1,mir=!!(Array.isArray(g.mirror)&&g.mirror[i]),z=Array.isArray(g.z)?N(g.z[i],groupName==="trees"?1:0):(groupName==="trees"?1:0);
      push(z,order+i/1000,()=>{ctx.save();ctx.imageSmoothingEnabled=false;ctx.filter="none";let im=im0;const mode=Object.prototype.hasOwnProperty.call(g,"colorize")?g.colorize:true;if(mode!==false){const sample=this.bss083SampleCanvas(ctx,x,y);im=this.bss083CanvasTint(im0,sample,S(mode)==="slight"?128:255);}this.bss083DrawAnchored(ctx,im,x,y,zoom,mir,null,null);ctx.restore();ctx.imageSmoothingEnabled=false;ctx.filter="none";},`group:${groupName}:${i}`);
    }};
    await groupOp("trees","tree",20);await groupOp("tallGrass","tallGrass",30);

    if(data.water){
      for(let i=0;i<2;i++){const im=await this.bss083LoadImage(this.bss083EBDXAssetPath("elements",`water${i}`));if(!im)continue;push(0,50+i,()=>{ctx.save();if(i>0){ctx.translate(384,0);ctx.scale(-1,1);}const sx=Math.max(0,Math.floor((im.width-384)/2)),sw=Math.min(384,im.width-sx);ctx.drawImage(im,sx,0,sw,im.height,0,146,384,im.height);ctx.restore();},`water${i}`);}
    }

    for(const key of imgKeys(data)){
      const d=data[key],visual=await this.bss101LayerVisual(view.id||"scene",key,d),im=visual?visual.canvas:await this.bss083LoadImage(this.bss083EBDXAssetPath("elements",d.bitmap));if(!im)continue;
      const x=N(d.x,0),y=N(d.y,0),baseZ=N(d.z,0),zoom=N(d.zoom,1),zx=d.zoom_x!=null?N(d.zoom_x,zoom):zoom,zy=d.zoom_y!=null?N(d.zoom_y,zoom):zoom,ox=visual?visual.ox:(d.ox!=null?N(d.ox,0):null),oy=visual?visual.oy:(d.oy!=null?N(d.oy,0):null),angle=N(d.angle,0),opacity=Math.max(0,Math.min(255,N(d.opacity,255)))/255;
      push(baseZ,60+baseZ/1000,()=>{let use=im;if(d.colorize===true||S(d.colorize)==="slight"){const sample=this.bss083SampleCanvas(ctx,x,y);use=this.bss083CanvasTint(im,sample,S(d.colorize)==="slight"?128:255);}ctx.save();ctx.imageSmoothingEnabled=false;ctx.filter="none";ctx.globalAlpha=opacity;if(d.scrolling&&!visual&&angle===0){const tileW=Math.max(1,use.width*Math.abs(zx)),tileH=Math.max(1,use.height*Math.abs(zy)),anchorX=(ox!=null?ox:use.width/2)*Math.abs(zx),anchorY=(oy!=null?oy:use.height)*Math.abs(zy);if(d.vertical){const xx=x-anchorX,baseY=y-anchorY,startY=((baseY%tileH)+tileH)%tileH-tileH;for(let py=startY;py<308+tileH;py+=tileH)ctx.drawImage(use,xx,py,use.width*zx,use.height*zy);}else{const yy=y-anchorY,baseX=x-anchorX,startX=((baseX%tileW)+tileW)%tileW-tileW;for(let px=startX;px<384+tileW;px+=tileW)ctx.drawImage(use,px,yy,use.width*zx,use.height*zy);}}else this.bss083DrawAnchored(ctx,use,x,y,zx,false,ox,oy,angle,zy);ctx.restore();ctx.imageSmoothingEnabled=false;ctx.filter="none";},key);
    }
    ops.sort((a,b)=>a.z-b.z||a.order-b.order);for(const op of ops)try{op.draw();}catch(_){ }
    return {canvas:logical,ctx,ops};
  };

  // Crop-aware hit geometry, matching the visual modifier output.
  const _bss101OldHits=App.prototype.bss092HitAreas;
  App.prototype.bss092HitAreas=async function(view){
    let out=[];try{out=await _bss101OldHits.call(this,view);}catch(_){out=[];}const data=view&&view.data||{};
    for(const key of imgKeys(data)){
      const d=data[key];let a=out.find(x=>x.id===key);if(!a){a={id:key,kind:"img",key,x:N(d.x,0),y:N(d.y,0),z:N(d.z,0)};out.push(a);}a.x=N(d.x,0);a.y=N(d.y,0);a.z=N(d.z,0);
      const pts=this.bss093WarpActualPoints(d);if(pts.length){const xs=pts.map(p=>p[0]),ys=pts.map(p=>p[1]);a.x0=Math.min(...xs);a.x1=Math.max(...xs);a.y0=Math.min(...ys);a.y1=Math.max(...ys);continue;}
      if(d.crop){const pack=await this.bss101LayerSource(d);if(pack){const base=N(d.zoom,1),zx=d.zoom_x!=null?N(d.zoom_x,base):base,zy=d.zoom_y!=null?N(d.zoom_y,base):base,b=this.bss092ImageBounds(a.x,a.y,pack.sourceW,pack.sourceH,pack.local.ox,pack.local.oy,zx,zy,d.angle);Object.assign(a,b);}}
    }
    out.sort((a,b)=>N(b.z,0)-N(a.z,0)||String(b.id).localeCompare(String(a.id)));return out;
  };

  App.prototype.bss101MapPoint=function(x,y,game){if(!game)return {x,y};const q=this.bss095MainProjection();return {x:x*q.scale+q.tx,y:y*q.scale+q.ty};};
  App.prototype.bss101DrawEditOverlay=function(canvas,view,state,game){
    if(!view||view.kind!=="custom")return;const ctx=canvas.getContext("2d"),sel=S(this.ebdx088SelectedLayer),d=view.data&&view.data[sel],area=A(state.hitAreas).find(x=>x.id===sel);ctx.save();
    if(view.data&&view.data.water){const l=this.bss101MapPoint(0,146,game),r=this.bss101MapPoint(384,146,game);ctx.strokeStyle="rgba(90,180,255,.62)";ctx.lineWidth=1;ctx.setLineDash([7,5]);ctx.beginPath();ctx.moveTo(l.x,l.y);ctx.lineTo(r.x,r.y);ctx.stroke();ctx.setLineDash([]);ctx.font="10px monospace";ctx.fillStyle="rgba(8,20,34,.82)";ctx.fillRect(l.x+5,l.y-17,112,14);ctx.fillStyle="#9ed7ff";ctx.textAlign="left";ctx.fillText("Agua EBDX · Y 146",l.x+9,l.y-7);}
    if(area){const a=this.bss101MapPoint(area.x0,area.y0,game),b=this.bss101MapPoint(area.x1,area.y1,game),c=this.bss101MapPoint(area.x,area.y,game);ctx.strokeStyle="rgba(105,178,255,.98)";ctx.lineWidth=2;ctx.setLineDash([6,4]);ctx.strokeRect(a.x,a.y,b.x-a.x,b.y-a.y);ctx.setLineDash([]);ctx.fillStyle="rgba(10,18,28,.9)";ctx.strokeStyle="#fff";for(const p of [a,{x:b.x,y:a.y},b,{x:a.x,y:b.y}]){ctx.fillRect(p.x-4,p.y-4,8,8);ctx.strokeRect(p.x-4.5,p.y-4.5,9,9);}ctx.beginPath();ctx.arc(c.x,c.y,6,0,Math.PI*2);ctx.fill();ctx.stroke();}
    const cfg=this.bss093WarpConfig(d),editing=cfg&&S(this.ebdx093WarpEditKey)===sel;if(cfg){const pts=cfg.points.map((p,i)=>{const q=this.bss093WarpAuthorPoint(d,p),g=this.bss101MapPoint(q[0],q[1],game);return {index:i,row:Math.floor(i/cfg.cols),col:i%cfg.cols,x:q[0],y:q[1],gameX:g.x,gameY:g.y};});state.warpHandles=pts;ctx.strokeStyle="rgba(108,194,255,.94)";ctx.lineWidth=1.5;for(let r=0;r<cfg.rows;r++){ctx.beginPath();for(let c=0;c<cfg.cols;c++){const p=pts[r*cfg.cols+c];c?ctx.lineTo(p.gameX,p.gameY):ctx.moveTo(p.gameX,p.gameY);}ctx.stroke();}for(let c=0;c<cfg.cols;c++){ctx.beginPath();for(let r=0;r<cfg.rows;r++){const p=pts[r*cfg.cols+c];r?ctx.lineTo(p.gameX,p.gameY):ctx.moveTo(p.gameX,p.gameY);}ctx.stroke();}if(editing)for(const p of pts){ctx.beginPath();ctx.fillStyle=(p.row===0||p.row===cfg.rows-1)&&(p.col===0||p.col===cfg.cols-1)?"#ffcf6d":"#69b2ff";ctx.strokeStyle="#08101a";ctx.lineWidth=2;ctx.arc(p.gameX,p.gameY,6.5,0,Math.PI*2);ctx.fill();ctx.stroke();}}
    if(d){const areas=A(d.blurAreas),base=N(d.zoom,1),zx=d.zoom_x!=null?N(d.zoom_x,base):base,zy=d.zoom_y!=null?N(d.zoom_y,base):base,scale=(Math.abs(zx)+Math.abs(zy))/2;for(let i=0;i<areas.length;i++){const ar=areas[i],mode=S(ar.mode||"radial");if(mode==="total")continue;const isBand=mode.startsWith("band"),p=this.bss093WarpAuthorPoint(d,[N(ar.x,0),N(ar.y,0)]),g=this.bss101MapPoint(p[0],p[1],game);ctx.strokeStyle=this._bss099BlurPlacement&&this._bss099BlurPlacement.key===sel&&this._bss099BlurPlacement.index===i?"#ffcf6d":"rgba(120,200,255,.9)";ctx.setLineDash([5,4]);ctx.beginPath();if(isBand){ctx.moveTo(0,g.y);ctx.lineTo(canvas.width,g.y);ctx.stroke();const dir=mode==="band_bottom"?1:-1;for(let tx=40;tx<canvas.width;tx+=60){ctx.moveTo(tx,g.y);ctx.lineTo(tx,g.y+dir*8);ctx.lineTo(tx-3,g.y+dir*5);ctx.moveTo(tx,g.y+dir*8);ctx.lineTo(tx+3,g.y+dir*5);}ctx.stroke();}else{const rr=Math.max(4,N(ar.radius,48))*scale*(game?this.bss095MainProjection().scale:1);ctx.arc(g.x,g.y,rr,0,Math.PI*2);ctx.stroke();}ctx.setLineDash([]);ctx.fillStyle="rgba(8,16,26,.9)";ctx.strokeStyle="#fff";ctx.fillRect(g.x-4,g.y-4,8,8);ctx.strokeRect(g.x-4.5,g.y-4.5,9,9);}}
    ctx.restore();
  };

  // --------------------------------------------------------------------------
  // Battler guides. They are screen-space because runtime battlers are screen-
  // anchored while the EBDX world moves behind them.
  // --------------------------------------------------------------------------
  if(App.prototype.ebdx101ShowBattlers==null)App.prototype.ebdx101ShowBattlers=true;
  App.prototype.bss101DrawBattlerGuides=async function(canvas){
    if(this.ebdx101ShowBattlers===false||canvas.width!==640||canvas.height!==480)return;const ctx=canvas.getContext("2d");let b=null;try{b=this.battle&&this.battle();}catch(_){b=null;}let rows=[];
    if(b){try{const pc=this.previewContext(b),list=A(pc&&pc.raw&&pc.raw.battlers);rows=list.map(r=>{const idx=N(r.index,0),side=(idx&1)?"target":"user",arr=side==="user"?A(b.teams&&b.teams.testPlayer):A(b.teams&&b.teams.foes),pk=arr[Math.floor(idx/2)]||{};return {idx,side,x:N(r.x,side==="user"?128:512),y:N(r.y,side==="user"?400:248),pk};});}catch(_){rows=[];}}
    if(!rows.length)rows=[{idx:0,side:"user",x:128,y:400,pk:{}},{idx:1,side:"target",x:512,y:248,pk:{}}];
    for(const row of rows){let im=null;if(row.pk&&row.pk.species){try{const asset=findBattlerSprite(this.source,row.pk.species,row.side,row.pk.form||0),url=await this.frameUrl(asset,`ebdx101:${row.side}:${row.pk.species}:${row.pk.form||0}`);if(url)im=await this.bss083LoadImage(url);}catch(_){}}
      ctx.save();ctx.strokeStyle=row.side==="user"?"rgba(108,194,255,.9)":"rgba(255,160,118,.9)";ctx.fillStyle="rgba(5,12,20,.52)";ctx.setLineDash([5,4]);ctx.beginPath();ctx.ellipse(row.x,row.y,44,12,0,0,Math.PI*2);ctx.fill();ctx.stroke();ctx.setLineDash([]);ctx.beginPath();ctx.moveTo(row.x-9,row.y);ctx.lineTo(row.x+9,row.y);ctx.moveTo(row.x,row.y-9);ctx.lineTo(row.x,row.y+9);ctx.stroke();if(im){const maxH=row.side==="user"?190:150,sc=Math.min(1,maxH/Math.max(1,im.height));ctx.imageSmoothingEnabled=false;ctx.globalAlpha=.88;ctx.drawImage(im,row.x-im.width*sc/2,row.y-im.height*sc,im.width*sc,im.height*sc);}ctx.globalAlpha=1;ctx.font="12px monospace";ctx.fillStyle="rgba(0,0,0,.74)";ctx.fillRect(row.x-42,row.y+9,84,18);ctx.fillStyle="#fff";ctx.textAlign="center";ctx.fillText(row.pk&&row.pk.species?S(row.pk.species):(row.side==="user"?"PLAYER":"FOE"),row.x,row.y+22);ctx.restore();
    }
  };

  // Final composite authority.
  App.prototype.bss083EBDXComposite=async function(canvas,view){
    const logical=await this.bss101LogicalComposite(view),main=!!(canvas&&canvas.closest&&canvas.closest(".bss092-main-preview")),game=main&&S(this.ebdx095PreviewMode||"game")==="game";let ctx;
    if(game){const q=this.bss095MainProjection();canvas.width=640;canvas.height=480;ctx=canvas.getContext("2d");ctx.imageSmoothingEnabled=false;ctx.clearRect(0,0,640,480);ctx.drawImage(logical.canvas,q.sx,q.sy,q.sw,q.sh,0,0,640,480);}else{canvas.width=384;canvas.height=308;ctx=canvas.getContext("2d");ctx.imageSmoothingEnabled=false;ctx.clearRect(0,0,384,308);ctx.drawImage(logical.canvas,0,0);}
    const hitAreas=view&&view.kind==="custom"?await this.bss092HitAreas(view):[],state={ctx,logicalCtx:logical.ctx,imgKeys:imgKeys(view&&view.data||{}),handles:hitAreas.map(a=>({kind:a.kind,key:a.key,index:a.index,x:a.x,y:a.y,z:a.z})),hitAreas,warpHandles:[],previewProjection:game?this.bss095MainProjection():null};
    this.bss101DrawEditOverlay(canvas,view,state,game);if(game)await this.bss101DrawBattlerGuides(canvas);return state;
  };

  // --------------------------------------------------------------------------
  // Clear editor ergonomics: visible pipeline, battlers toggle, project tile
  // shortcut, and editable EBDX floor/base conversion.
  // --------------------------------------------------------------------------
  const _quick101=App.prototype.bss092QuickBarHTML;
  App.prototype.bss092QuickBarHTML=function(scene){let html=_quick101.call(this,scene);if(!scene)return html;const b=`<button type="button" class="bss101-battlers ${this.ebdx101ShowBattlers!==false?'active':''}" data-bss101-battlers title="Muestra posiciones reales de battlers en Vista juego">👁 Pokémon</button><button type="button" data-bss101-project-tile title="Seleccionar un tile/área desde Graphics/Tilesets sin copiarlo">🧩 Tile proyecto</button>`;const i=html.lastIndexOf("</div>");return i>=0?html.slice(0,i)+b+html.slice(i):html+b;};

  App.prototype.bss101FloorPanelHTML=function(scene){if(!scene||scene.kind!=="custom")return "";const base=S(scene.data&&scene.data.base||"");return `<section class="bss088-inspector-section bss101-floors"><div class="bss088-section-title"><div><b>Suelos editables</b><small>Convierte Puddle/Concrete/Dirt/Water en una capa normal: mover, Z, escala, recorte, difuminado y deformación. No duplica el PNG.</small></div></div><div class="bss101-floor-grid">${["Puddle","Concrete","Dirt","Water"].map(x=>`<button type="button" data-bss101-floor="${E(x)}"><b>${E(x)}</b><small>${base===x?'Base actual · convertir':'Añadir como capa'}</small></button>`).join("")}</div>${base?`<button type="button" class="bss-btn" data-bss101-convert-base="${E(base)}">Convertir base actual “${E(base)}” a capa editable</button>`:""}</section>`;};
  const _sceneInspector101=App.prototype.bss088SceneInspectorHTML;
  App.prototype.bss088SceneInspectorHTML=function(scene){let html=_sceneInspector101.call(this,scene);if(!scene)return html;const panel=this.bss101FloorPanelHTML(scene),mark='<details class="bss088-json">',i=html.indexOf(mark);return panel?(i>=0?html.slice(0,i)+panel+html.slice(i):html+panel):html;};

  App.prototype.bss101AddFloor=function(name,removeBase=false){const r=this.bss089CurrentCustomRow&&this.bss089CurrentCustomRow();if(!r)return;const n=S(name||"Puddle").replace(/\.png$/i,""),path=`Graphics/BattleSceneStudio/EBDX/Battlebacks/base/${n}.png`;this.bss089HistoryCheckpoint&&this.bss089HistoryCheckpoint("Añadir suelo editable");if(removeBase&&S(r.data&&r.data.base).toLowerCase()===n.toLowerCase())delete r.data.base;const key=this.bss088AddLayer(path,{x:192,y:308,z:1,zoom:1,zoom_x:1,zoom_y:1,opacity:255,direction:1,flat:true,_bssName:`${n} · suelo editable`});this.ebdx088SelectedLayer=key;this.ebdx092InspectorTab="layer";this.saveSoon();this.bss089RefreshSelectionPanels&&this.bss089RefreshSelectionPanels();this.bss089RedrawPreview&&this.bss089RedrawPreview();};

  const _layerInspector101=App.prototype.bss088LayerInspectorHTML;
  App.prototype.bss088LayerInspectorHTML=function(scene){let html=_layerInspector101.call(this,scene),t=this.bss088SelectedTarget(scene);if(!t||t.type!=="img")return html;const d=t.data||{},mods=[['Fuente',true],['Recorte',!!d.crop],['Deformación',!!this.bss093WarpConfig(d)],['Difuminado',A(d.blurAreas).some(a=>a&&N(a.strength,0)>0&&(N(a.radius,0)>0||S(a.mode).startsWith("band")||S(a.mode)==="total"))],['Transformación',true]],bar=`<div class="bss101-pipeline"><small>FLUJO DE LA MISMA CAPA</small><div>${mods.map(([n,on])=>`<span class="${on?'active':''}">${E(n)}</span>`).join('<i>→</i>')}</div><em>Ninguna herramienta sustituye u oculta el gráfico: todas modifican esta misma capa.</em></div>`;const pos=html.indexOf('<section class="bss088-inspector-section');return pos>=0?html.slice(0,pos)+bar+html.slice(pos):bar+html;};

  // Preserve inspector scroll/focus no matter which legacy wrapper rebuilt it.
  const _input101=App.prototype.onInput;
  App.prototype.onInput=function(e){const pane=this.body&&this.body.querySelector('.bss092-inspector-body'),before=pane?pane.scrollTop:null,active=document.activeElement,selector=active&&active.dataset?Object.keys(active.dataset).map(k=>`[data-${k.replace(/[A-Z]/g,m=>'-'+m.toLowerCase())}="${CSS.escape(S(active.dataset[k]))}"]`).join(''):'';const ret=_input101.call(this,e);if(before!=null)requestAnimationFrame(()=>{const p=this.body&&this.body.querySelector('.bss092-inspector-body');if(p)p.scrollTop=before;if(selector){try{const n=this.body.querySelector(selector);if(n&&n!==document.activeElement)n.focus({preventScroll:true});}catch(_){}}});return ret;};

  const _click101=App.prototype.onClick;
  App.prototype.onClick=function(e){const raw=e&&e.target,t=raw&&typeof raw.closest==="function"?raw.closest('[data-bss101-battlers],[data-bss101-project-tile],[data-bss101-floor],[data-bss101-convert-base]'):null;if(t&&t.dataset){if(t.dataset.bss101Battlers!=null){this.ebdx101ShowBattlers=this.ebdx101ShowBattlers===false;this.bss089RefreshQuickBar&&this.bss089RefreshQuickBar();this.bss089RedrawPreview&&this.bss089RedrawPreview();return;}if(t.dataset.bss101ProjectTile!=null){this.ebdx088AssetCategory="Proyecto · Tilesets";this.ebdx088AssetSearch="";this.bss100OpenAssetBrowser();return;}if(t.dataset.bss101Floor!=null){this.bss101AddFloor(S(t.dataset.bss101Floor),false);return;}if(t.dataset.bss101ConvertBase!=null){this.bss101AddFloor(S(t.dataset.bss101ConvertBase),true);return;}}return _click101.call(this,e);};

  // Large asset browser starts with all results and keeps a useful minimum size.
  const _openAssets101=App.prototype.bss100OpenAssetBrowser;
  App.prototype.bss100OpenAssetBrowser=function(){const ret=_openAssets101.call(this);const modal=this.root&&this.root.querySelector('[data-bss100-asset-modal]');if(modal)modal.classList.add('bss101-assets-large');return ret;};

  // Warp setup for cropped tiles is now direct and non-destructive. It computes
  // points from crop dimensions without temporarily replacing the real bitmap.
  App.prototype.bss093SetWarpMode=async function(key,mode){const scene=this.bss088SceneFromState(),d=scene&&scene.kind==="custom"&&scene.data&&scene.data[key];if(!d||typeof d!=="object")return;mode=S(mode||"off");this.bss089HistoryCheckpoint("Cambiar deformación");if(mode==="off"){delete d.warp;if(S(this.ebdx093WarpEditKey)===S(key))this.ebdx093WarpEditKey="";delete d.runtimeRaster;this.saveSoon();this.bss089RefreshSelectionPanels();this.bss089RedrawPreview();return;}let cols=2,rows=2;if(/^mesh[3-5]$/.test(mode))cols=rows=N(mode.slice(-1),3);const old=this.bss093WarpConfig(d),pack=await this.bss101LayerSource(d);if(!pack)return;const temp=Object.assign({},d,{ox:pack.local.ox,oy:pack.local.oy}),fake={width:pack.sourceW,height:pack.sourceH},points=old?this.bss093ResampleWarp(old,cols,rows):this.bss093DefaultWarpPoints(temp,fake,cols,rows);d.warp={enabled:true,mode:cols===2&&rows===2?"quad":"mesh",cols,rows,quality:old?old.quality:3,points};this.bss093DisableWarpConflicts(d);this.ebdx093WarpEditKey=key;delete d.runtimeRaster;this._bss101VisualCache&&this._bss101VisualCache.clear();this.saveSoon();this.bss089RefreshSelectionPanels();this.bss089RedrawPreview();};
  App.prototype.bss093ResetWarp=async function(key){const scene=this.bss088SceneFromState(),d=scene&&scene.kind==="custom"&&scene.data&&scene.data[key],cfg=this.bss093WarpConfig(d);if(!d||!cfg)return;const pack=await this.bss101LayerSource(d);if(!pack)return;const temp=Object.assign({},d,{ox:pack.local.ox,oy:pack.local.oy}),fake={width:pack.sourceW,height:pack.sourceH};this.bss089HistoryCheckpoint("Reconstruir malla");d.warp.points=this.bss093DefaultWarpPoints(temp,fake,cfg.cols,cfg.rows);delete d.runtimeRaster;this._bss101VisualCache&&this._bss101VisualCache.clear();this.saveSoon();this.bss089RefreshSelectionPanels();this.bss089RedrawPreview();};
})();

// ============================================================================
// BSS v0.8.23 - Composer usability + runtime-parity authoring pass
// - real-size battler guides
// - lockable layers
// - compact floor tools
// - cloud placement
// - rigid projection for tiles/decor
// - asset-use filtering
// - custom flat tint
// - optional command overview camera
// - animated water/sheet preview clock
// - robust runtime-raster persistence
// ============================================================================
(function(){
  if(typeof App==="undefined")return;
  const deep102=v=>JSON.parse(JSON.stringify(v==null?{}:v));
  const imgKeys102=data=>Object.keys(data||{}).filter(k=>/^img\d+/i.test(k)&&data[k]&&typeof data[k]==="object");

  // ------------------------------------------------------------------------
  // 1. Locking. Locked layers remain selectable from the outliner but are not
  //    draggable/nudged/depth-reordered accidentally on the canvas.
  // ------------------------------------------------------------------------
  App.prototype.bss102TargetLocked=function(t){
    if(!t)return false;
    if(t.type==="img")return t.data&&t.data.locked===true;
    const arr=A(t.data&&t.data.locked);return arr[t.index]===true;
  };
  App.prototype.bss102SetTargetLocked=function(t,value){
    if(!t)return;
    if(t.type==="img")t.data.locked=!!value;
    else{t.data.locked=A(t.data.locked);while(t.data.locked.length<=t.index)t.data.locked.push(false);t.data.locked[t.index]=!!value;}
  };
  const _layers102=App.prototype.bss088LayerListHTML;
  App.prototype.bss088LayerListHTML=function(scene){
    if(!scene)return _layers102.call(this,scene);
    const ro=scene.kind!=="custom",selected=S(this.ebdx088SelectedLayer),all=this.bss092LayerEntries(scene),q=L(this.ebdx092LayerSearch||""),rows=all.filter(e=>!q||L(`${e.name} ${e.id} ${e.kind}`).includes(q)),selectedEntry=all.find(e=>e.id===selected),selectedTarget=selectedEntry&&this.bss092TargetById(scene,selectedEntry.id),selectedLocked=this.bss102TargetLocked(selectedTarget);
    const controls=ro||!selectedEntry?"":`<div class="bss092-layer-actions"><span>Orden</span><button type="button" title="Mandar al frente" data-bss092-depth="front" ${selectedLocked?"disabled":""}>⇑</button><button type="button" title="Subir una capa" data-bss092-depth="up" ${selectedLocked?"disabled":""}>↑</button><button type="button" title="Bajar una capa" data-bss092-depth="down" ${selectedLocked?"disabled":""}>↓</button><button type="button" title="Mandar al fondo" data-bss092-depth="back" ${selectedLocked?"disabled":""}>⇓</button><em>Z ${E(String(selectedEntry.z))}</em></div>`;
    const html=rows.map(e=>{const t=this.bss092TargetById(scene,e.id),locked=this.bss102TargetLocked(t);let sub="";if(e.type==="img")sub=`${E(this.bss088BehaviorLabel(this.bss088LayerBehavior(e.data)))} · Z ${E(String(e.z))} · ${Math.round(N(e.data.opacity,255)/255*100)}%`;else sub=`${E(e.data.bitmap||e.name)} · Z ${E(String(e.z))} · ×${E(String(N(this.bss088GroupValue(e.data,"zoom",e.index,1),1)))}`;return `<div role="button" tabindex="0" draggable="false" class="bss088-layer-row bss092-layer-row ${selected===e.id?"active":""} ${locked?"bss102-locked":""}" data-bss088-layer-select="${E(e.id)}" data-bss092-drag-layer="${E(e.id)}"><span class="bss092-drag-grip" draggable="${ro||locked?"false":"true"}" style="cursor:${locked?"default":"grab"};" title="${locked?"Capa bloqueada":"Arrastra para cambiar profundidad"}">${locked?"•":"⋮⋮"}</span><span class="bss088-layer-main"><b>${E(e.name)}</b><small>${sub}</small></span><span class="bss088-layer-kind">${E(e.kind)}</span>${ro?"":`<button type="button" class="bss102-lock ${locked?"active":""}" data-bss102-lock="${E(e.id)}" title="${locked?"Desbloquear capa":"Bloquear capa"}">${locked?"🔒":"🔓"}</button>`}</div>`;}).join("");
    return `<section class="bss088-layer-stack bss092-layer-stack"><div class="bss088-layer-stack-head bss092-layer-head"><div><b>Capas</b><small>De arriba hacia abajo = frente hacia fondo · 🔒 evita mover por accidente</small></div>${ro?"":'<button class="bss-btn small" type="button" data-bss089-dock-tab="elements">＋ Añadir</button>'}</div><div class="bss092-layer-search"><input class="bss-search" data-bss092-layer-search placeholder="Buscar capa…" value="${E(this.ebdx092LayerSearch||"")}"></div>${controls}<div class="bss088-layer-list">${html||'<div class="bss-empty small">No hay capas que coincidan.</div>'}</div><div class="bss092-layer-shortcuts"><span>Bloquea capas terminadas antes de colocar otras.</span><span>↑↓ mueve · Ctrl+↑/↓ profundidad · Shift = 1 px</span></div></section>`;
  };
  const _hits102=App.prototype.bss092HitAreas;
  App.prototype.bss092HitAreas=async function(view){
    const out=await _hits102.call(this,view);if(!view||view.kind!=="custom")return out;
    const scene=this.bss088SceneFromState();
    return out.filter(a=>{const t=scene&&this.bss092TargetById(scene,a.id);return !(t&&this.bss102TargetLocked(t));});
  };
  const _nudge102=App.prototype.bss092NudgeSelected;
  App.prototype.bss092NudgeSelected=function(dx,dy){const scene=this.bss088SceneFromState(),t=this.bss088SelectedTarget(scene);if(this.bss102TargetLocked(t)){this.toast("Capa bloqueada");return;}return _nudge102.call(this,dx,dy);};
  const _depth102=App.prototype.bss092DepthAction;
  App.prototype.bss092DepthAction=function(action,sourceId,targetId){const scene=this.bss088SceneFromState(),t=scene&&this.bss092TargetById(scene,sourceId||this.ebdx088SelectedLayer);if(this.bss102TargetLocked(t)){this.toast("Desbloquea la capa para cambiar su profundidad.");return;}return _depth102.call(this,action,sourceId,targetId);};

  // ------------------------------------------------------------------------
  // 2. Compact floor manager. It only lives in Escena, never under Capas.
  //    Floor/decor layers use rigid projection by default to avoid X/Y warp.
  // ------------------------------------------------------------------------
  App.prototype.bss101FloorPanelHTML=function(){return "";};
  App.prototype.bss102FloorPanelHTML=function(scene){
    if(!scene||scene.kind!=="custom")return "";const base=S(scene.data&&scene.data.base||"");
    return `<details class="bss088-inspector-section bss102-floor-panel"><summary><b>Suelos / bases editables</b><small>Convierte una base EBDX en capa solo cuando necesites reposicionarla.</small></summary><div class="bss101-floor-grid">${["Puddle","Concrete","Dirt","Water"].map(x=>`<button type="button" data-bss101-floor="${E(x)}"><b>${E(x)}</b><small>${base===x?"Base actual · convertir":"Añadir como capa"}</small></button>`).join("")}</div>${base?`<button type="button" class="bss-btn" data-bss101-convert-base="${E(base)}">Convertir base actual “${E(base)}”</button>`:""}<p class="bss-note">Las bases convertidas usan proyección rígida: siguen al mundo/cámara sin estirarse por perspectiva.</p></details>`;
  };
  const _scene102=App.prototype.bss088SceneInspectorHTML;
  App.prototype.bss088SceneInspectorHTML=function(scene){
    let html=_scene102.call(this,scene);if(!scene||S(this.ebdx092InspectorTab||"layer")!=="scene")return html;
    const panel=this.bss102FloorPanelHTML(scene),mark='<details class="bss088-json">',i=html.indexOf(mark);return panel?(i>=0?html.slice(0,i)+panel+html.slice(i):html+panel):html;
  };
  App.prototype.bss101AddFloor=function(name,removeBase=false){
    const r=this.bss089CurrentCustomRow&&this.bss089CurrentCustomRow();if(!r)return;const n=S(name||"Puddle").replace(/\.png$/i,""),path=`Graphics/BattleSceneStudio/EBDX/Battlebacks/base/${n}.png`;this.bss089HistoryCheckpoint&&this.bss089HistoryCheckpoint("Añadir suelo editable");if(removeBase&&S(r.data&&r.data.base).toLowerCase()===n.toLowerCase())delete r.data.base;const key=this.bss088AddLayer(path,{x:192,y:308,z:1,zoom:1,zoom_x:1,zoom_y:1,opacity:255,direction:1,flat:true,bssRigid:true,_bssFloor:true,_bssName:`${n} · suelo editable`});this.ebdx088SelectedLayer=key;this.ebdx092InspectorTab="layer";this.saveSoon();this.bss089RefreshSelectionPanels&&this.bss089RefreshSelectionPanels();this.bss089RedrawPreview&&this.bss089RedrawPreview();
  };

  // ------------------------------------------------------------------------
  // 3. Asset intent. Default browser = composable decor; parallax source sheets
  //    are separated instead of pretending they are ordinary props.
  // ------------------------------------------------------------------------
  App.prototype.bss102AssetUse=function(path){
    const p=S(path).replace(/\\/g,"/");
    if(/^Graphics\/Tilesets\//i.test(p)||/\/Battlebacks\/elements\//i.test(p)||/\/SceneAssets\/Cutouts\//i.test(p)||/\/SceneAssets\/Props\//i.test(p))return "decor";
    if(/\/SceneAssets\//i.test(p))return "parallax";
    return "decor";
  };
  if(!App.prototype.ebdx102AssetUse)App.prototype.ebdx102AssetUse="decor";
  App.prototype.bss100AssetMatches=function(){
    const all=this.bss088AssetRows(),cat=S(this.ebdx088AssetCategory||"all"),q=L(this.ebdx088AssetSearch||""),use=S(this.ebdx102AssetUse||"decor");
    return all.filter(x=>(use==="all"||this.bss102AssetUse(x.projectPath)===use)&&(cat==="all"||this.bss088AssetCategoryOf(x.projectPath)===cat)&&(!q||L(`${x.name||""} ${x.projectPath||""} ${this.bss088AssetCategoryOf(x.projectPath)}`).includes(q)));
  };
  App.prototype.bss100AssetBrowserHTML=function(){
    const all=this.bss088AssetRows(),use=S(this.ebdx102AssetUse||"decor"),usable=all.filter(x=>use==="all"||this.bss102AssetUse(x.projectPath)===use),cats=[...new Set(usable.map(x=>this.bss088AssetCategoryOf(x.projectPath)))].sort(),cat=S(this.ebdx088AssetCategory||"all"),rows=this.bss100AssetMatches();
    return `<div class="bss100-asset-modal" data-bss100-asset-modal><button class="bss100-modal-shade" data-bss100-close-assets aria-label="Cerrar"></button><section class="bss100-asset-card bss102-asset-card"><header><div><b>Navegador de elementos</b><small>${rows.length} resultados · los fondos fuente/parallax están separados del decorado combinable.</small></div><button type="button" class="bss-btn" data-bss100-close-assets>✕ Cerrar</button></header><div class="bss102-use-tabs"><button class="${use==="decor"?"active":""}" data-bss102-asset-use="decor">Elementos combinables</button><button class="${use==="parallax"?"active":""}" data-bss102-asset-use="parallax">Fondos / fuentes parallax</button><button class="${use==="all"?"active":""}" data-bss102-asset-use="all">Todo</button></div><div class="bss100-asset-search"><input class="bss-search" data-bss100-asset-search autofocus placeholder="Buscar por nombre, carpeta o uso…" value="${E(this.ebdx088AssetSearch||"")}"></div><div class="bss100-asset-layout"><aside>${['all',...cats].map(c=>`<button type="button" class="${cat===c?"active":""}" data-bss100-asset-cat="${E(c)}">${E(c==='all'?'Todos':c)} <span>${c==='all'?usable.length:usable.filter(x=>this.bss088AssetCategoryOf(x.projectPath)===c).length}</span></button>`).join("")}</aside><main class="bss100-asset-grid">${rows.map(x=>`<button type="button" class="bss100-asset-item" data-bss100-use-asset="${E(x.projectPath)}"><span class="bss087-asset-thumb"><img loading="lazy" data-bss100-asset-thumb="${E(x.projectPath)}" alt=""></span><b>${E(x.name||x.projectPath.split('/').pop())}</b><small>${E(this.bss088AssetCategoryOf(x.projectPath))}</small><em>${/^Graphics\/Tilesets\//i.test(x.projectPath)?"Seleccionar tile/área":this.bss102AssetUse(x.projectPath)==="parallax"?"Añadir como capa de fondo":"Añadir"}</em></button>`).join("")||'<div class="bss-empty">No hay resultados.</div>'}</main></div></section></div>`;
  };
  const _defaults102=App.prototype.bss088AssetDefaults;
  App.prototype.bss088AssetDefaults=function(path){
    const d=_defaults102.call(this,path),p=S(path).replace(/\\/g,"/");
    if(/^Graphics\/Tilesets\//i.test(p)||/\/SceneAssets\/Cutouts\//i.test(p)||/\/SceneAssets\/Props\//i.test(p)){d.flat=true;d.bssRigid=true;delete d.canvasLayer;}
    return d;
  };

  // ------------------------------------------------------------------------
  // 4. Cloud authoring. These values use EBDX author coordinates directly.
  // ------------------------------------------------------------------------
  App.prototype.bss102CloudConfig=function(scene){
    if(!scene)return {};scene.data=scene.data||{};const d=scene.data,c=d.cloudsConfig&&typeof d.cloudsConfig==="object"?d.cloudsConfig:(d.cloudsConfig={});
    const defs={enabled:true,cloud1X:0,cloud1Y:98,cloud1Speed:1,cloud1Direction:1,cloud1Opacity:255,cloud2X:0,cloud2Y:91,cloud2Speed:0.5,cloud2Direction:-1,cloud2Opacity:255};for(const k in defs)if(c[k]==null)c[k]=defs[k];return c;
  };
  App.prototype.bss102CloudPanelHTML=function(scene){
    if(!scene)return "";const ro=scene.kind!=="custom",dis=ro?"disabled":"",c=this.bss102CloudConfig(scene),field=(label,key,step=1)=>`<label class="bss-mini-field"><span>${E(label)}</span><input class="bss-input" type="number" step="${step}" data-bss102-cloud="${E(key)}" value="${N(c[key],0)}" ${dis}></label>`;
    return `<details class="bss088-inspector-section bss102-clouds"><summary><b>Nubes EBDX</b><small>Edita dónde nacen y cómo se desplazan las dos capas.</small></summary><label class="bss-check"><input type="checkbox" data-bss102-cloud-bool="enabled" ${c.enabled!==false?"checked":""} ${dis}> Mostrar nubes</label><div class="bss102-cloud-grid"><fieldset><legend>Nube 1</legend>${field("X","cloud1X")}${field("Y","cloud1Y")}${field("Velocidad","cloud1Speed",0.1)}${field("Dirección ±1","cloud1Direction")}${field("Opacidad","cloud1Opacity")}</fieldset><fieldset><legend>Nube 2</legend>${field("X","cloud2X")}${field("Y","cloud2Y")}${field("Velocidad","cloud2Speed",0.1)}${field("Dirección ±1","cloud2Direction")}${field("Opacidad","cloud2Opacity")}</fieldset></div></details>`;
  };
  const _env102=App.prototype.bss088EnvironmentHTML;
  App.prototype.bss088EnvironmentHTML=function(scene){let html=_env102.call(this,scene);return html+this.bss102CloudPanelHTML(scene);};

  // ------------------------------------------------------------------------
  // 5. Layer integration: depth / flat / rigid + manual flat tint.
  // ------------------------------------------------------------------------
  const _layer102=App.prototype.bss088LayerInspectorHTML;
  App.prototype.bss088LayerInspectorHTML=function(scene){
    let html=_layer102.call(this,scene),t=this.bss088SelectedTarget(scene);if(!t||t.type!=="img")return html;const d=t.data||{},key=this.bss092TargetId(t),ro=scene.kind!=="custom",dis=ro?"disabled":"",proj=d.bssRigid===true?"rigid":(d.flat===true?"flat":"depth"),tint=S(d.tintColor||"#FFFFFF"),alpha=Math.max(0,Math.min(255,N(d.tintAlpha,0)));
    const box=`<section class="bss088-inspector-section bss102-integration"><div class="bss088-section-title"><div><b>Proyección y color manual</b><small>Tiles/props pueden seguir a la cámara sin deformarse. El color manual es independiente del teñido automático.</small></div></div><label class="bss-mini-field"><span>Proyección</span><select class="bss-select" data-bss102-projection="${E(key)}" ${dis}><option value="depth" ${proj==="depth"?"selected":""}>Profundidad EBDX</option><option value="flat" ${proj==="flat"?"selected":""}>Plano EBDX</option><option value="rigid" ${proj==="rigid"?"selected":""}>Rígido · sin distorsión X/Y</option></select></label><div class="bss102-tint-row"><label class="bss-mini-field"><span>Color plano</span><input type="color" data-bss102-tint="${E(key)}" value="${/^#[0-9a-f]{6}$/i.test(tint)?E(tint):"#FFFFFF"}" ${dis}></label><label class="bss-mini-field"><span>Intensidad 0–255</span><input class="bss-input" type="number" min="0" max="255" data-bss102-tint-alpha="${E(key)}" value="${alpha}" ${dis}></label></div></section>`;
    const mark='<section class="bss088-inspector-section"><div class="bss088-section-title"><div><b>Comportamiento</b>';const i=html.indexOf(mark);return i>=0?html.slice(0,i)+box+html.slice(i):html+box;
  };

  // ------------------------------------------------------------------------
  // 6. Correct battler guides. Use the raw battler frame and the same rendering
  //    scale/anchor metadata used by the project, not a thumbnail-size cap.
  // ------------------------------------------------------------------------
  App.prototype.bss101DrawBattlerGuides=async function(canvas){
    if(this.ebdx101ShowBattlers===false||canvas.width!==640||canvas.height!==480)return;const ctx=canvas.getContext("2d");let b=null;try{b=this.battle&&this.battle();}catch(_){b=null;}let rows=[];
    if(b){try{const pc=this.previewContext(b),list=A(pc&&pc.raw&&pc.raw.battlers);rows=list.map(r=>{const idx=N(r.index,0),side=(idx&1)?"target":"user",arr=side==="user"?A(b.teams&&b.teams.testPlayer):A(b.teams&&b.teams.foes),pk=arr[Math.floor(idx/2)]||{};return {idx,side,x:N(r.x,side==="user"?128:512),y:N(r.y,side==="user"?400:248),pk};});}catch(_){rows=[];}}
    if(!rows.length)rows=[{idx:0,side:"user",x:128,y:400,pk:{}},{idx:1,side:"target",x:512,y:248,pk:{}}];
    for(const row of rows){let im=null,meta={};if(row.pk&&row.pk.species){try{const asset=findBattlerSprite(this.source,row.pk.species,row.side,row.pk.form||0),url=await this.assetUrl(asset);meta=await this.battlerRenderInfo(asset,row.pk,row.side)||{};if(url)im=await this.bss083LoadImage(url);}catch(_){} }
      ctx.save();ctx.strokeStyle=row.side==="user"?"rgba(108,194,255,.9)":"rgba(255,160,118,.9)";ctx.fillStyle="rgba(5,12,20,.48)";ctx.setLineDash([5,4]);ctx.beginPath();ctx.ellipse(row.x,row.y,44,12,0,0,Math.PI*2);ctx.fill();ctx.stroke();ctx.setLineDash([]);ctx.beginPath();ctx.moveTo(row.x-9,row.y);ctx.lineTo(row.x+9,row.y);ctx.moveTo(row.x,row.y-9);ctx.lineTo(row.x,row.y+9);ctx.stroke();
      if(im){let sw=im.width,sh=im.height;if(sw>sh*1.45)sw=Math.min(sw/2,sh);const sc=Math.max(.1,N(meta.editorViewScale,meta.scale||1));const ox=N(meta.metricX,0),oy=N(meta.metricY,0),dw=sw*sc,dh=sh*sc;ctx.imageSmoothingEnabled=false;ctx.globalAlpha=.84;ctx.drawImage(im,0,0,sw,sh,row.x-dw/2+ox,row.y-dh+oy,dw,dh);}
      ctx.globalAlpha=1;ctx.font="12px monospace";ctx.fillStyle="rgba(0,0,0,.72)";ctx.fillRect(row.x-48,row.y+9,96,18);ctx.fillStyle="#fff";ctx.textAlign="center";ctx.fillText(row.pk&&row.pk.species?S(row.pk.species):(row.side==="user"?"PLAYER":"FOE"),row.x,row.y+22);ctx.restore();
    }
  };

  const _loadCloud102=App.prototype.bss083LoadImage;
  App.prototype.bss083LoadImage=async function(path){
    if(this._bss102SuppressClouds&&/\/cloud[12](?:\.png)?$/i.test(S(path))){const c=document.createElement("canvas");c.width=1;c.height=1;return c;}
    return _loadCloud102.call(this,path);
  };

  // ------------------------------------------------------------------------
  // 7. Preview source clock. Water, scrolling layers and sheets animate at the
  //    same 40 Hz EBDX source speed while the editor is open.
  // ------------------------------------------------------------------------
  App.prototype.bss102PreviewSeconds=function(){if(!this._bss102PreviewStarted)this._bss102PreviewStarted=performance.now();return (performance.now()-this._bss102PreviewStarted)/1000;};
  App.prototype.bss102TintVisual=function(source,color,alpha){
    alpha=Math.max(0,Math.min(255,N(alpha,0)));if(!source||alpha<=0)return source;const c=document.createElement("canvas");c.width=source.width;c.height=source.height;const g=c.getContext("2d");g.drawImage(source,0,0);g.globalCompositeOperation="source-atop";g.globalAlpha=alpha/255;g.fillStyle=/^#[0-9a-f]{6}$/i.test(S(color))?S(color):"#FFFFFF";g.fillRect(0,0,c.width,c.height);g.globalAlpha=1;g.globalCompositeOperation="source-over";return c;
  };
  App.prototype.bss102SheetVisual=function(im,d,time){
    if(!im||!d||d.sheet!==true)return im;const frames=Math.max(1,N(d.frames,1)),vertical=d.vertical===true,fw=vertical?im.width:Math.max(1,Math.floor(im.width/frames)),fh=vertical?Math.max(1,Math.floor(im.height/frames)):im.height,wait=Math.max(1,N(d.speed,8)),idx=Math.floor(time*40/wait)%frames,c=document.createElement("canvas");c.width=fw;c.height=fh;c.getContext("2d").drawImage(im,vertical?0:idx*fw,vertical?idx*fh:0,fw,fh,0,0,fw,fh);return c;
  };
  const _logical102=App.prototype.bss101LogicalComposite;
  App.prototype.bss101LogicalComposite=async function(view){
    const data=view&&view.data||{},logical=document.createElement("canvas");logical.width=384;logical.height=308;const ctx=logical.getContext("2d");ctx.imageSmoothingEnabled=false;const time=this.bss102PreviewSeconds();
    const baseData=deep102(data);delete baseData.water;delete baseData.trees;delete baseData.tallGrass;imgKeys102(baseData).forEach(k=>delete baseData[k]);
    const base=document.createElement("canvas");base.width=384;base.height=308;try{const baseState=await _logical102.call(this,Object.assign({},view,{data:baseData,kind:"builtin"}));if(baseState&&baseState.canvas)ctx.drawImage(baseState.canvas,0,0);}catch(_){ctx.fillStyle="#182331";ctx.fillRect(0,0,384,308);}
    const ops=[],push=(z,order,draw,id)=>ops.push({z:N(z,0),order,id,draw});
    const groupOp=async(groupName,def,order)=>{const g=data[groupName];if(!g||typeof g!=="object")return;const im0=await this.bss083LoadImage(this.bss083EBDXAssetPath("elements",g.bitmap||def));if(!im0)return;const n=Math.max(0,N(g.elements,Array.isArray(g.x)?g.x.length:0));for(let i=0;i<n;i++){const x=Array.isArray(g.x)?N(g.x[i],0):0,y=Array.isArray(g.y)?N(g.y[i],0):0,zoom=Array.isArray(g.zoom)?N(g.zoom[i],1):1,mir=!!(Array.isArray(g.mirror)&&g.mirror[i]),z=Array.isArray(g.z)?N(g.z[i],groupName==="trees"?1:0):(groupName==="trees"?1:0);push(z,order+i/1000,()=>{ctx.save();ctx.imageSmoothingEnabled=false;ctx.filter="none";let im=im0,mode=Object.prototype.hasOwnProperty.call(g,"colorize")?g.colorize:true;if(mode!==false){const sample=this.bss083SampleCanvas(ctx,x,y);im=this.bss083CanvasTint(im0,sample,S(mode)==="slight"?128:255);}this.bss083DrawAnchored(ctx,im,x,y,zoom,mir,null,null);ctx.restore();ctx.imageSmoothingEnabled=false;ctx.filter="none";},`group:${groupName}:${i}`);}};
    await groupOp("trees","tree",20);await groupOp("tallGrass","tallGrass",30);
    if(data.water){for(let i=0;i<2;i++){const im=await this.bss083LoadImage(this.bss083EBDXAssetPath("elements",`water${i}`));if(!im)continue;push(0,50+i,()=>{const speed=i===0?1:.5,dir=i===0?1:-1,shift=(time*40*speed*dir)%Math.max(1,im.width),w=im.width;ctx.save();for(let n=-2;n<4;n++){let px=n*w-shift;if(i===0)ctx.drawImage(im,px,146);else{ctx.save();ctx.translate(px+w,0);ctx.scale(-1,1);ctx.drawImage(im,0,146);ctx.restore();}}ctx.restore();},`water${i}`);}}
    for(const key of imgKeys102(data)){const d=data[key],visual=await this.bss101LayerVisual(view.id||"scene",key,d);let im=visual?visual.canvas:await this.bss083LoadImage(this.bss083EBDXAssetPath("elements",d.bitmap));if(!im)continue;if(!visual)im=this.bss102SheetVisual(im,d,time);if(N(d.tintAlpha,0)>0)im=this.bss102TintVisual(im,d.tintColor,N(d.tintAlpha,0));const x=N(d.x,0),y=N(d.y,0),baseZ=N(d.z,0),zoom=N(d.zoom,1),zx=d.zoom_x!=null?N(d.zoom_x,zoom):zoom,zy=d.zoom_y!=null?N(d.zoom_y,zoom):zoom,ox=visual?visual.ox:(d.ox!=null?N(d.ox,0):null),oy=visual?visual.oy:(d.oy!=null?N(d.oy,0):null),angle=N(d.angle,0),opacity=Math.max(0,Math.min(255,N(d.opacity,255)))/255;push(baseZ,60+baseZ/1000,()=>{let use=im;if(d.colorize===true||S(d.colorize)==="slight"){const sample=this.bss083SampleCanvas(ctx,x,y);use=this.bss083CanvasTint(im,sample,S(d.colorize)==="slight"?128:255);}ctx.save();ctx.imageSmoothingEnabled=false;ctx.filter="none";ctx.globalAlpha=opacity;if(d.scrolling&&!visual&&angle===0){const tileW=Math.max(1,use.width*Math.abs(zx)),tileH=Math.max(1,use.height*Math.abs(zy)),anchorX=(ox!=null?ox:use.width/2)*Math.abs(zx),anchorY=(oy!=null?oy:use.height)*Math.abs(zy),phase=time*40*Math.abs(N(d.speed,1))*(N(d.direction,1)<0?-1:1);if(d.vertical){const xx=x-anchorX,baseY=y-anchorY-phase,startY=((baseY%tileH)+tileH)%tileH-tileH;for(let py=startY;py<308+tileH;py+=tileH)ctx.drawImage(use,xx,py,use.width*zx,use.height*zy);}else{const yy=y-anchorY,baseX=x-anchorX-phase,startX=((baseX%tileW)+tileW)%tileW-tileW;for(let px=startX;px<384+tileW;px+=tileW)ctx.drawImage(use,px,yy,use.width*zx,use.height*zy);}}else this.bss083DrawAnchored(ctx,use,x,y,zx,false,ox,oy,angle,zy);ctx.restore();ctx.imageSmoothingEnabled=false;ctx.filter="none";},key);}
    // Clouds participate in the same Z stack instead of being painted over decor.
    if(data.sky){const c=data.cloudsConfig&&typeof data.cloudsConfig==="object"?data.cloudsConfig:null;if(c&&c.enabled!==false){for(let i=1;i<=2;i++){const im=await this.bss083LoadImage(this.bss083EBDXAssetPath("elements",`cloud${i}`));if(!im)continue;const x=N(c[`cloud${i}X`],0),y=N(c[`cloud${i}Y`],i===1?98:91),speed=Math.abs(N(c[`cloud${i}Speed`],i===1?1:.5)),dir=N(c[`cloud${i}Direction`],i===1?1:-1)<0?-1:1,opacity=Math.max(0,Math.min(255,N(c[`cloud${i}Opacity`],255)))/255,phase=time*40*speed*dir;push(-8,5+i,()=>{ctx.save();ctx.globalAlpha=opacity;const start=((x-phase)%Math.max(1,im.width)+im.width)%im.width-im.width;for(let px=start;px<384+im.width;px+=im.width)ctx.drawImage(im,px,y-im.height);ctx.restore();},`cloud${i}`);}}}
    ops.sort((a,b)=>a.z-b.z||a.order-b.order);for(const op of ops)try{op.draw();}catch(_){ }
    return {canvas:logical,ctx,ops};
  };
  App.prototype.bss102EnsurePreviewAnimation=function(){
    if(this._bss102PreviewLoop)return;this._bss102PreviewLoop=true;let last=0;const tick=async now=>{if(!this._bss102PreviewLoop)return;if(this.screen!=="ebdx"||S(this.ebdxStudioTab||"backgrounds")!=="backgrounds"||!this.body||!this.body.isConnected){this._bss102PreviewLoop=false;return;}if(now-last>65&&!this._bss102PreviewDrawing){last=now;const canvas=this.body.querySelector(".bss092-main-preview canvas"),view=this.ebdxStudioView&&this.ebdxStudioView();if(canvas&&view){this._bss102PreviewDrawing=true;try{await this.bss083EBDXComposite(canvas,view);}catch(_){ }finally{this._bss102PreviewDrawing=false;}}}requestAnimationFrame(tick);};requestAnimationFrame(tick);
  };
  const _hydrate102=App.prototype.hydrateEBDXStudioPreview;
  App.prototype.hydrateEBDXStudioPreview=async function(){const ret=await _hydrate102.call(this);this.bss102EnsurePreviewAnimation();return ret;};

  // ------------------------------------------------------------------------
  // 8. Optional command overview. Camera stays ambient otherwise.
  // ------------------------------------------------------------------------
  App.prototype.bss102CameraPanelHTML=function(){const c=this.bss079EnsureEBDXConfig().ebdxCamera||(this.bss079EnsureEBDXConfig().ebdxCamera={});if(c.commandOverviewEnabled==null)c.commandOverviewEnabled=false;if(c.commandOverviewZoomOut==null)c.commandOverviewZoomOut=12;if(c.commandOverviewLift==null)c.commandOverviewLift=22;if(c.commandOverviewFrames==null)c.commandOverviewFrames=24;return `<div class="bss102-command-overview"><label class="bss-check"><input type="checkbox" data-bss102-camera-bool="commandOverviewEnabled" ${c.commandOverviewEnabled===true?"checked":""}> Vista amplia temporal al elegir comandos</label><p class="bss-note">Sirve para admirar montañas/escenarios altos. Sale una sola vez al abrir comandos y retorna suavemente al encuadre ambiental.</p><div class="bss-mini-grid"><label class="bss-mini-field"><span>Zoom out %</span><input type="number" min="0" max="30" data-bss102-camera="commandOverviewZoomOut" value="${N(c.commandOverviewZoomOut,12)}"></label><label class="bss-mini-field"><span>Subir encuadre</span><input type="number" min="0" max="80" data-bss102-camera="commandOverviewLift" value="${N(c.commandOverviewLift,22)}"></label><label class="bss-mini-field"><span>Transición frames</span><input type="number" min="8" max="80" data-bss102-camera="commandOverviewFrames" value="${N(c.commandOverviewFrames,24)}"></label></div></div>`;};
  const _camHTML102=App.prototype.bss079CameraConfigHTML;
  App.prototype.bss079CameraConfigHTML=function(){let html=_camHTML102.call(this);const end=html.lastIndexOf("</section>");return end>=0?html.slice(0,end)+this.bss102CameraPanelHTML()+html.slice(end):html+this.bss102CameraPanelHTML();};

  // ------------------------------------------------------------------------
  // 9. Runtime raster persistence: clear stale references before baking and do
  //    not save a path until the writer confirms the file exists.
  // ------------------------------------------------------------------------
  App.prototype.bss099BakeRuntimeRasters=async function(){
    const rows=A(this.studio&&this.studio.global&&this.studio.global.ebdxCustomEnvironments);if(!rows.length)return;await this.ctx.fs.projectMkdir("Graphics/BattleSceneStudio/EBDX/Generated");
    for(const scene of rows){const data=scene&&scene.data;if(!data||typeof data!=="object")continue;for(const key of imgKeys102(data)){const d=data[key];if(!d||typeof d!=="object")continue;delete d.runtimeRaster;const r=await this.bss099RasterLayer(scene.id||"scene",key,d);if(!r)continue;const safeScene=S(scene.id||"scene").replace(/[^A-Za-z0-9_-]+/g,"_"),safeKey=S(key).replace(/[^A-Za-z0-9_-]+/g,"_"),path=`Graphics/BattleSceneStudio/EBDX/Generated/${safeScene}_${safeKey}.png`,bytes=await this.bss099CanvasBytes(r.canvas);try{await this.bss099WriteBinary(path,bytes);let ok=true;try{if(this.ctx&&this.ctx.fs&&typeof this.ctx.fs.projectExists==="function")ok=await this.ctx.fs.projectExists(path);}catch(_){ok=true;}if(ok)d.runtimeRaster={bitmap:path,ox:r.ox,oy:r.oy,fingerprint:r.fingerprint};else this.toast(`No se pudo confirmar ${path}`,true);}catch(err){delete d.runtimeRaster;this.toast(`No se pudo generar ${safeScene}_${safeKey}.png: ${S(err&&err.message||err)}`,true);}}
    }
  };

  // ------------------------------------------------------------------------
  // Unified click/input handlers.
  // ------------------------------------------------------------------------
  const _click102=App.prototype.onClick;
  App.prototype.onClick=function(e){const raw=e&&e.target,t=raw&&typeof raw.closest==="function"?raw.closest('[data-bss102-lock],[data-bss102-asset-use],[data-bss101-project-tile]'):null;if(t&&t.dataset){if(t.dataset.bss102Lock!=null){const scene=this.bss088SceneFromState(),target=scene&&this.bss092TargetById(scene,S(t.dataset.bss102Lock));if(target){this.bss089HistoryCheckpoint("Bloquear capa");this.bss102SetTargetLocked(target,!this.bss102TargetLocked(target));this.saveSoon();this.bss089RefreshDock();this.bss089RefreshInspectorOnly();this.bss089RedrawPreview();}return;}if(t.dataset.bss102AssetUse!=null){this.ebdx102AssetUse=S(t.dataset.bss102AssetUse||"decor");this.ebdx088AssetCategory="all";this.bss100RefreshAssetBrowser();return;}if(t.dataset.bss101ProjectTile!=null){this.ebdx102AssetUse="decor";this.ebdx088AssetCategory="Proyecto · Tilesets";this.ebdx088AssetSearch="";this.bss100OpenAssetBrowser();return;}}return _click102.call(this,e);};
  const _input102=App.prototype.onInput;
  App.prototype.onInput=function(e){const t=e&&e.target;if(t&&t.dataset){const scene=this.bss088SceneFromState();if(t.dataset.bss102Projection!=null&&scene&&scene.kind==="custom"){const d=scene.data&&scene.data[S(t.dataset.bss102Projection)];if(d){const v=S(t.value);this.bss089HistoryCheckpoint("Cambiar proyección");d.projection=v;d.bssRigid=v==="rigid";d.flat=v!=="depth";this.saveSoon();this.bss089RedrawPreview();}return;}if(t.dataset.bss102Tint!=null&&scene&&scene.kind==="custom"){const d=scene.data&&scene.data[S(t.dataset.bss102Tint)];if(d){d.tintColor=S(t.value||"#FFFFFF");this.saveSoon();this.bss089RedrawPreview();}return;}if(t.dataset.bss102TintAlpha!=null&&scene&&scene.kind==="custom"){const d=scene.data&&scene.data[S(t.dataset.bss102TintAlpha)];if(d){d.tintAlpha=Math.max(0,Math.min(255,N(t.value,0)));this.saveSoon();this.bss089RedrawPreview();}return;}if(t.dataset.bss102Cloud!=null&&scene&&scene.kind==="custom"){const c=this.bss102CloudConfig(scene);c[S(t.dataset.bss102Cloud)]=N(t.value,0);this.saveSoon();this.bss089RedrawPreview();return;}if(t.dataset.bss102Camera!=null){const c=this.bss079EnsureEBDXConfig().ebdxCamera||(this.bss079EnsureEBDXConfig().ebdxCamera={});c[S(t.dataset.bss102Camera)]=N(t.value,0);this.saveSoon();return;}if(t.dataset.bss102CloudBool!=null&&scene&&scene.kind==="custom"){const c=this.bss102CloudConfig(scene);c[S(t.dataset.bss102CloudBool)]=!!t.checked;this.saveSoon();this.bss089RedrawPreview();return;}if(t.dataset.bss102CameraBool!=null){const c=this.bss079EnsureEBDXConfig().ebdxCamera||(this.bss079EnsureEBDXConfig().ebdxCamera={});c[S(t.dataset.bss102CameraBool)]=!!t.checked;this.saveSoon();return;}}
    return _input102.call(this,e);
  };
  const _change102=App.prototype.onChange;
  App.prototype.onChange=function(e){return typeof _change102==="function"?_change102.call(this,e):undefined;};
})();

// BSS v0.8.23 - direct cloud handles on the scene canvas.
(function(){
  if(typeof App==="undefined")return;
  const _compCloud102=App.prototype.bss083EBDXComposite;
  App.prototype.bss083EBDXComposite=async function(canvas,view){
    const state=await _compCloud102.call(this,canvas,view);state.cloudHandles=[];
    try{
      if(S(this.ebdx092InspectorTab||"layer")==="scene"&&view&&view.data&&view.data.sky&&view.data.cloudsConfig&&view.data.cloudsConfig.enabled!==false){const c=view.data.cloudsConfig,game=canvas.width===640&&canvas.height===480,q=game?this.bss095MainProjection():null,ctx=canvas.getContext("2d");for(let i=1;i<=2;i++){const x=N(c[`cloud${i}X`],0),y=N(c[`cloud${i}Y`],i===1?98:91),gx=game?x*q.scale+q.tx:x,gy=game?y*q.scale+q.ty:y;state.cloudHandles.push({index:i,x,y,gameX:gx,gameY:gy});ctx.save();ctx.fillStyle="rgba(20,31,44,.92)";ctx.strokeStyle=i===1?"#8acbff":"#d6efff";ctx.lineWidth=2;ctx.beginPath();ctx.arc(gx,gy,7,0,Math.PI*2);ctx.fill();ctx.stroke();ctx.font="bold 11px monospace";ctx.fillStyle="#fff";ctx.textAlign="center";ctx.fillText(`N${i}`,gx,gy-11);ctx.restore();}}
    }catch(_){ }
    this._bss102CloudHandles=state.cloudHandles;return state;
  };
  const _hydrateCloud102=App.prototype.hydrateEBDXStudioPreview;
  App.prototype.hydrateEBDXStudioPreview=async function(){const ret=await _hydrateCloud102.call(this),canvas=this.body&&this.body.querySelector(".bss092-main-preview canvas");if(!canvas||canvas._bss102CloudWired)return ret;canvas._bss102CloudWired=true;canvas.addEventListener("pointerdown",ev=>{if(S(this.ebdx092InspectorTab||"layer")!=="scene")return;const view=this.ebdxStudioView&&this.ebdxStudioView(),c=view&&view.kind==="custom"&&view.data&&view.data.cloudsConfig;if(!c)return;const p=this.bss095PointerLogical(canvas,ev),handles=A(this._bss102CloudHandles),hit=handles.map(h=>({h,d:Math.hypot(h.x-p.x,h.y-p.y)})).sort((a,b)=>a.d-b.d)[0];if(!hit||hit.d>10)return;this.bss089HistoryCheckpoint("Mover nube");const idx=hit.h.index,move=e=>{const q=this.bss095PointerLogical(canvas,e);c[`cloud${idx}X`]=Math.round(q.x);c[`cloud${idx}Y`]=Math.round(q.y);this.saveSoon();this.bss089RedrawPreview();e.preventDefault();},up=()=>{window.removeEventListener("pointermove",move);window.removeEventListener("pointerup",up);this.bss089RefreshInspectorOnly();};window.addEventListener("pointermove",move,{passive:false});window.addEventListener("pointerup",up);ev.preventDefault();ev.stopImmediatePropagation();},true);return ret;};
})();


// ============================================================================
// BSS v0.8.25 - visual background browser + temporary Wild Intro retirement
// ============================================================================
(function(){
  if(typeof App==="undefined")return;

  // Wild Intro is intentionally retired for now. Preserve its saved data, but
  // do not expose an editor that has no active runtime authority.
  const _render103=App.prototype.renderEBDXStudio;
  App.prototype.renderEBDXStudio=function(){
    if(S(this.ebdxStudioTab||"backgrounds")==="intros")this.ebdxStudioTab="backgrounds";
    const out=_render103.call(this);
    const nav=this.body&&this.body.querySelector('.bss079-ebdx-tabs');
    if(nav){const intro=nav.querySelector('[data-bss079-tab="intros"]');if(intro)intro.remove();}
    const title=this.body&&this.body.querySelector('.bss079-ebdx-header .bss-aura-title small');
    if(title)title.textContent='Fondos, metadata y configuración EBDX. Wild Intro temporalmente usa Essentials.';
    requestAnimationFrame(()=>this.bss103HydrateBackgroundPreviews());
    return out;
  };

  App.prototype.bss103SceneEntry=function(id){
    id=S(id||"Auto");if(!id||id==="Auto"||id==="inherit")return null;
    return A(this.bss079SceneEntries&&this.bss079SceneEntries()).find(x=>S(x&&x.id)===id)||null;
  };

  // Render a thumbnail from the SAME logical compositor and MAIN projection as
  // the main editor. This avoids name-only selectors and stale preview PNGs.
  App.prototype.bss103RenderSceneThumb=async function(canvas,entry){
    if(!canvas||!entry)return false;
    try{
      const view={kind:entry.kind,id:entry.id,name:entry.name,data:JSON.parse(JSON.stringify(entry.data||{})),row:entry.row||null};
      let state=null;
      if(typeof this.bss101LogicalComposite==="function")state=await this.bss101LogicalComposite(view);
      if(!state||!state.canvas){
        const off=document.createElement('canvas');off.width=384;off.height=308;
        state=await this.bss083EBDXComposite(off,view);
      }
      const src=state&&state.canvas;if(!src)return false;
      const ctx=canvas.getContext('2d');ctx.imageSmoothingEnabled=false;
      const w=canvas.width||384,h=canvas.height||216;ctx.clearRect(0,0,w,h);
      if(typeof this.bss095MainProjection==="function"){
        const q=this.bss095MainProjection();ctx.drawImage(src,q.sx,q.sy,q.sw,q.sh,0,0,w,h);
      }else ctx.drawImage(src,0,0,src.width,src.height,0,0,w,h);
      return true;
    }catch(_){return false;}
  };

  App.prototype.bss103HydrateBackgroundPreviews=async function(){
    if(!this.body)return;
    const entries=A(this.bss079SceneEntries&&this.bss079SceneEntries()),map=new Map(entries.map(x=>[S(x.kind)+':'+S(x.id),x]));
    // Library cards.
    for(const canvas of [...this.body.querySelectorAll('canvas[data-bss079-card-preview]')]){
      const entry=map.get(S(canvas.dataset.bss079CardPreview));if(!entry)continue;
      await this.bss103RenderSceneThumb(canvas,entry);
    }
    // Metadata/general/context/map visual previews.
    for(const canvas of [...this.body.querySelectorAll('canvas[data-bss103-scene-preview]')]){
      const entry=this.bss103SceneEntry(canvas.dataset.bss103ScenePreview);if(!entry){const g=canvas.getContext('2d');g.clearRect(0,0,canvas.width,canvas.height);g.fillStyle='#0b1017';g.fillRect(0,0,canvas.width,canvas.height);g.fillStyle='#8f99aa';g.font='12px monospace';g.textAlign='center';g.fillText('Auto / contextual',canvas.width/2,canvas.height/2);continue;}
      await this.bss103RenderSceneThumb(canvas,entry);
    }
  };

  // Bigger visual library: the thumbnail is the primary information, not a
  // tiny icon beside a filename.
  const _drawer103=App.prototype.bss089LibraryDrawerHTML;
  App.prototype.bss089LibraryDrawerHTML=function(scene){
    let html=_drawer103.call(this,scene);if(!html)return html;
    html=html.replace('bss089-library-drawer','bss089-library-drawer bss103-visual-library');
    return html;
  };

  // Metadata gets a real preview for the currently assigned background and for
  // each explicit override row.
  const _meta103=App.prototype.bss100MetadataHTML;
  App.prototype.bss100MetadataHTML=function(){
    let html=_meta103.call(this);
    const g=this.bss079EnsureEBDXConfig(),general=S(g.ebdxBackdrop||'Auto');
    const generalPreview=`<div class="bss103-metadata-preview"><canvas width="384" height="216" data-bss103-scene-preview="${E(general)}"></canvas><span>Vista MAIN</span></div>`;
    const firstClose=html.indexOf('</section>');if(firstClose>=0)html=html.slice(0,firstClose)+generalPreview+html.slice(firstClose);
    return html;
  };

  App.prototype.bss103AttachMetadataRowPreviews=function(){
    if(!this.body)return;
    const add=(sel)=>{const row=sel&&sel.closest('.bss079-map-row');if(!row)return;let box=row.querySelector('.bss103-row-preview');if(!box){box=document.createElement('div');box.className='bss103-row-preview';box.innerHTML='<canvas width="160" height="90"></canvas>';row.insertBefore(box,row.firstChild);}const c=box.querySelector('canvas');c.dataset.bss103ScenePreview=S(sel.value||'Auto');};
    this.body.querySelectorAll('[data-bss097-context-bg],[data-bss079-map-scene]').forEach(add);
  };

  const _renderFinal103=App.prototype.renderEBDXStudio;
  App.prototype.renderEBDXStudio=function(){
    const out=_renderFinal103.call(this);
    this.bss103AttachMetadataRowPreviews();
    requestAnimationFrame(()=>this.bss103HydrateBackgroundPreviews());
    return out;
  };

  const _input103=App.prototype.onInput;
  App.prototype.onInput=function(e){
    const ret=_input103.call(this,e),t=e&&e.target;
    if(t&&t.matches&&t.matches('[data-studio-global="ebdxBackdrop"],[data-bss097-context-bg],[data-bss079-map-scene]')){
      requestAnimationFrame(()=>{this.bss103AttachMetadataRowPreviews();this.bss103HydrateBackgroundPreviews();});
    }
    return ret;
  };
})();


// ============================================================================
// BSS v0.8.28 - stable compositor / complete-frame preview authority
// - fixes the base-compositor fallback that blanked backdrop/elements
// - never paints an incomplete async frame to the visible canvas
// - caches decoded project images while the composer is open
// - deformation mesh is an editing overlay only, never ordinary layer chrome
// ============================================================================
(function(){
  if(typeof App==="undefined")return;

  // A composer frame loads the same bitmaps repeatedly (water/clouds/custom
  // decor). Decode once and reuse them instead of creating a fresh Image on
  // every preview tick. URLs returned by assetUrl are accepted directly too.
  App.prototype.bss083LoadImage=async function(path){
    path=S(path||"");if(!path)return null;
    if(this._bss102SuppressClouds&&/\/cloud[12](?:\.png)?$/i.test(path)){
      const c=document.createElement("canvas");c.width=1;c.height=1;return c;
    }
    const o=S(this._bss099SkyOverride||"");
    if(o&&/\/skyDay(?:\.png)?$/i.test(path))path=o;

    const currentSlot=this._bss106CurrentSlot||(this.bss106SceneTimeSlot?this.bss106SceneTimeSlot():"day");
    const pNorm=path.replace(/\\/g,"/");
    const isBackdropOrBase=/\/Battlebacks\/(?:battlebg|base)\//i.test(pNorm);
    const shouldTone=isBackdropOrBase&&this._bss106AmbientBackground&&currentSlot&&currentSlot!=="day";

    this._bss104ImageCache=this._bss104ImageCache||new Map();
    let key=path+(shouldTone?"@tone:"+currentSlot:"");
    if(this._bss104ImageCache.has(key))return await this._bss104ImageCache.get(key);
    const job=(async()=>{
      try{
        let url=path;
        if(!/^(?:data:|blob:|https?:)/i.test(path))url=await this.assetUrl({projectPath:path});
        if(!url)return null;
        let im=await new Promise(resolve=>{const img=new Image();img.onload=()=>resolve(img);img.onerror=()=>resolve(null);img.src=url;});
        if(!im)return null;
        if(shouldTone&&typeof this.bss106AmbientCanvas==="function"){
          im=this.bss106AmbientCanvas(im,currentSlot);
        }
        return im;
      }catch(_){return null;}
    })();
    this._bss104ImageCache.set(key,job);
    const out=await job;
    if(!out)this._bss104ImageCache.delete(key);
    if(this._bss104ImageCache.size>256)this._bss104ImageCache.delete(this._bss104ImageCache.keys().next().value);
    return out;
  };

  // The mesh is a tool, not part of the asset. Keep selection bounds and blur
  // guides visible, but suppress warp lines unless this exact layer is being
  // edited with Deformar.
  const _overlay104=App.prototype.bss101DrawEditOverlay;
  App.prototype.bss101DrawEditOverlay=function(canvas,view,state,game){
    try{
      const sel=S(this.ebdx088SelectedLayer),d=view&&view.data&&view.data[sel];
      const hasWarp=!!this.bss093WarpConfig(d),editing=hasWarp&&S(this.ebdx093WarpEditKey)===sel;
      if(hasWarp&&!editing){
        const data=Object.assign({},view.data),copy=Object.assign({},d);delete copy.warp;data[sel]=copy;
        return _overlay104.call(this,canvas,Object.assign({},view,{data}),state,game);
      }
    }catch(_){ }
    return _overlay104.call(this,canvas,view,state,game);
  };

  App.prototype.bss104DrawCloudHandles=function(canvas,view,state,game){
    state.cloudHandles=[];
    try{
      if(S(this.ebdx092InspectorTab||"layer")!=="scene"||!view||!view.data||!view.data.sky)return;
      const c=view.data.cloudsConfig;if(!c||c.enabled===false)return;
      const q=game?this.bss095MainProjection():null,ctx=canvas.getContext("2d");
      for(let i=1;i<=2;i++){
        const x=N(c[`cloud${i}X`],0),y=N(c[`cloud${i}Y`],i===1?98:91),gx=game?x*q.scale+q.tx:x,gy=game?y*q.scale+q.ty:y;
        state.cloudHandles.push({index:i,x,y,gameX:gx,gameY:gy});
        ctx.save();ctx.fillStyle="rgba(20,31,44,.92)";ctx.strokeStyle=i===1?"#8acbff":"#d6efff";ctx.lineWidth=2;ctx.beginPath();ctx.arc(gx,gy,7,0,Math.PI*2);ctx.fill();ctx.stroke();ctx.font="bold 11px monospace";ctx.fillStyle="#fff";ctx.textAlign="center";ctx.fillText(`N${i}`,gx,gy-11);ctx.restore();
      }
    }catch(_){ }
    this._bss102CloudHandles=state.cloudHandles;
  };

  // Complete-frame rendering. All asynchronous work is performed on an
  // invisible backbuffer. The visible canvas is touched only after backdrop,
  // elements, water, overlays and battler guides are all ready. Per-canvas
  // generation tokens prevent an older slow frame from overwriting a newer one.
  App.prototype.bss083EBDXComposite=async function(canvas,view){
    if(!canvas||!view)return null;
    this._bss104CanvasGeneration=this._bss104CanvasGeneration||new WeakMap();
    const generation=(this._bss104CanvasGeneration.get(canvas)||0)+1;
    this._bss104CanvasGeneration.set(canvas,generation);

    let logical;
    try{logical=await this.bss101LogicalComposite(view);}catch(_){logical=null;}
    if(!logical||!logical.canvas)return null;

    const main=!!(canvas.closest&&canvas.closest(".bss092-main-preview,.bss089-main-preview"));
    const game=main&&S(this.ebdx095PreviewMode||"game")==="game";
    const w=game?640:384,h=game?480:308,off=document.createElement("canvas");off.width=w;off.height=h;
    const g=off.getContext("2d");g.imageSmoothingEnabled=false;
    if(game){const q=this.bss095MainProjection();g.drawImage(logical.canvas,q.sx,q.sy,q.sw,q.sh,0,0,w,h);}
    else g.drawImage(logical.canvas,0,0);

    let hitAreas=[];if(view.kind==="custom")try{hitAreas=await this.bss092HitAreas(view);}catch(_){hitAreas=[];}
    const state={ctx:g,logicalCtx:logical.ctx,imgKeys:Object.keys(view.data||{}).filter(k=>/^img\d+/i.test(k)),handles:hitAreas.map(a=>({kind:a.kind,key:a.key,index:a.index,x:a.x,y:a.y,z:a.z})),hitAreas,warpHandles:[],cloudHandles:[],previewProjection:game?this.bss095MainProjection():null,canvas:off};

    this.bss101DrawEditOverlay(off,view,state,game);
    if(game)try{await this.bss101DrawBattlerGuides(off);}catch(_){ }
    this.bss104DrawCloudHandles(off,view,state,game);

    // A newer request finished first: keep that frame and discard this stale
    // result instead of producing a visual flash/reversion.
    if(this._bss104CanvasGeneration.get(canvas)!==generation)return state;
    if(canvas.width!==w)canvas.width=w;if(canvas.height!==h)canvas.height=h;
    const ctx=canvas.getContext("2d");ctx.imageSmoothingEnabled=false;ctx.clearRect(0,0,w,h);ctx.drawImage(off,0,0);
    state.ctx=ctx;state.canvas=canvas;return state;
  };

  // Starting a new explicit deformation is the only thing that should make
  // the mesh appear. Merely selecting/importing a tile or external asset does
  // not inherit another layer's editing state.
  const _setWarp104=App.prototype.bss093SetWarpMode;
  App.prototype.bss093SetWarpMode=async function(key,mode){
    const out=await _setWarp104.call(this,key,mode);
    this.ebdx093WarpEditKey=S(mode)!=="off"?S(key):"";
    this.bss089RedrawPreview&&this.bss089RedrawPreview();return out;
  };

  const _addLayer104=App.prototype.bss088AddLayer;
  if(typeof _addLayer104==="function")App.prototype.bss088AddLayer=function(path,opts){
    const before=S(this.ebdx093WarpEditKey),key=_addLayer104.call(this,path,opts);
    if(S(key)!==before)this.ebdx093WarpEditKey="";
    return key;
  };
})();


// ============================================================================
// BSS v0.8.33 - layer visibility, wind/cloud presets, water FX overlay, and
// time-aware preview tinting.
// ============================================================================
(function(){
  if(typeof App==="undefined")return;

  App.prototype.bss106TargetHidden=function(t){
    if(!t)return false;
    if(t.type==="img")return !!(t.data&&t.data.hidden===true);
    const g=t.data&&t.data.hidden;return !!(Array.isArray(g)&&g[N(t.index,0)]===true);
  };
  App.prototype.bss106SetTargetHidden=function(t,value){
    if(!t)return;
    if(t.type==="img")t.data.hidden=!!value;
    else{t.data.hidden=A(t.data.hidden);while(t.data.hidden.length<=N(t.index,0))t.data.hidden.push(false);t.data.hidden[N(t.index,0)]=!!value;}
  };
  App.prototype.bss106CloudConfig=function(scene){
    if(!scene||!scene.data)return {};
    const c=scene.data.cloudsConfig&&typeof scene.data.cloudsConfig==="object"?scene.data.cloudsConfig:(scene.data.cloudsConfig={});
    if(c.enabled==null)c.enabled=true;
    if(!/^#[0-9a-f]{6}$/i.test(S(c.dayColor||"")))c.dayColor="#dfefff";
    if(!/^#[0-9a-f]{6}$/i.test(S(c.dawnColor||"")))c.dawnColor="#ffd4b3";
    if(!/^#[0-9a-f]{6}$/i.test(S(c.nightColor||"")))c.nightColor="#9ebcff";
    return c;
  };
  App.prototype.bss106WindConfig=function(scene){
    if(!scene||!scene.data)return {};
    const w=scene.data.windConfig&&typeof scene.data.windConfig==="object"?scene.data.windConfig:(scene.data.windConfig={});
    if(w.enabled==null)w.enabled=true;
    if(w.amplitude==null)w.amplitude=3;
    if(w.speed==null)w.speed=1;
    if(w.rotation==null)w.rotation=2;
    return w;
  };
  App.prototype.bss106SceneTimeSlot=function(view){
    const d=view&&view.data||{},m=S(d.skyMode||"").toLowerCase();
    if(m==="day"||m==="dawn"||m==="night")return m;
    if(this._bssPreviewTimeSlot)return this._bssPreviewTimeSlot;
    if(m==="dynamic"){
      const h=new Date().getHours();
      if(h<6||h>=20)return "night";
      if((h>=6&&h<8)||(h>=17&&h<20))return "dawn";
      return "day";
    }
    return "day";
  };
  App.prototype.bss102TintVisual=function(img,colorHex,alpha){
    if(!img||!colorHex||alpha<=0)return img;
    const s=S(colorHex).trim().replace(/^#/,"");
    if(s.length!==6)return img;
    const r=parseInt(s.substr(0,2),16),g=parseInt(s.substr(2,2),16),b=parseInt(s.substr(4,2),16);
    return this.bss083CanvasTint(img,[r,g,b],alpha);
  };
  App.prototype.bss106ToneForSlot=function(slot){
    if(slot==="night")return [-120,-100,-60,0];
    if(slot==="dawn")return [-16,-52,-56,0];
    return [0,0,0,0];
  };
  App.prototype.bss106ApplyTone=function(img,tr,tg,tb,gr){
    if(!img||(!tr&&!tg&&!tb&&!gr))return img;
    const w=img.width,h=img.height;
    if(w<=0||h<=0)return img;
    const c=document.createElement("canvas");c.width=w;c.height=h;
    const ctx=c.getContext("2d");ctx.imageSmoothingEnabled=false;
    ctx.drawImage(img,0,0);
    try{
      const imgData=ctx.getImageData(0,0,w,h);
      const data=imgData.data,len=data.length;
      const hasGray=(gr||0)>0,grFactor=(gr||0)/255;
      for(let i=0;i<len;i+=4){
        if(data[i+3]===0)continue;
        let r=data[i],g=data[i+1],b=data[i+2];
        if(hasGray){
          const grayVal=(38*r+75*g+15*b)>>7;
          r+=(grayVal-r)*grFactor;
          g+=(grayVal-g)*grFactor;
          b+=(grayVal-b)*grFactor;
        }
        data[i]  =r+tr<0?0:(r+tr>255?255:(r+tr));
        data[i+1]=g+tg<0?0:(g+tg>255?255:(g+tg));
        data[i+2]=b+tb<0?0:(b+tb>255?255:(b+tb));
      }
      ctx.putImageData(imgData,0,0);
    }catch(_){}
    return c;
  };
  App.prototype.bss106AmbientCanvas=function(img,slot){
    if(!img||slot==="day")return img;
    const tone=this.bss106ToneForSlot?this.bss106ToneForSlot(slot):(slot==="night"?[-120,-100,-60,0]:(slot==="dawn"?[-16,-52,-56,0]:[0,0,0,0]));
    if(!tone||(tone[0]===0&&tone[1]===0&&tone[2]===0&&tone[3]===0))return img;
    return this.bss106ApplyTone?this.bss106ApplyTone(img,tone[0],tone[1],tone[2],tone[3]):img;
  };
  App.prototype.bss106CloudTint=function(cfg,slot){
    const key=slot==="night"?"nightColor":(slot==="dawn"?"dawnColor":"dayColor"),v=S(cfg&&cfg[key]||"");
    return /^#[0-9a-f]{6}$/i.test(v)?v:"#dfefff";
  };
  App.prototype.bss106LayerTint=function(d,slot){
    const map={day:["tintDayColor","tintDayAlpha"],dawn:["tintDawnColor","tintDawnAlpha"],night:["tintNightColor","tintNightAlpha"]},pair=map[slot]||map.day;
    const c=S(d&&d[pair[0]]||d&&d.tintColor||"#FFFFFF"),a=d&&d[pair[1]]!=null?N(d[pair[1]],N(d.tintAlpha,0)):N(d&&d.tintAlpha,0);
    return {color:/^#[0-9a-f]{6}$/i.test(c)?c:"#FFFFFF",alpha:Math.max(0,Math.min(255,a))};
  };
  App.prototype.bss106SceneExtraHTML=function(scene){
    if(!scene)return "";
    const ro=scene.kind!=="custom",dis=ro?"disabled":"",c=this.bss106CloudConfig(scene),w=this.bss106WindConfig(scene),d=scene.data||{};
    return `<section class="bss088-inspector-section bss106-scene-tools"><div class="bss088-section-title"><div><b>Presets y preview</b><small>Atajos para viento/nubes y una capa superior para efectos de agua.</small></div></div><div class="bss-row"><button type="button" class="bss-btn small" data-bss106-preset="wind_off" ${dis}>Sin viento</button><button type="button" class="bss-btn small" data-bss106-preset="wind_soft" ${dis}>Brisa suave</button><button type="button" class="bss-btn small" data-bss106-preset="wind_strong" ${dis}>Viento fuerte</button><button type="button" class="bss-btn small" data-bss106-preset="clouds_soft" ${dis}>Nubes suaves</button><button type="button" class="bss-btn small" data-bss106-preset="clouds_off" ${dis}>Ocultar nubes</button></div><div class="bss-mini-grid"><label class="bss-check"><input type="checkbox" data-bss106-wind-bool="enabled" ${w.enabled!==false?"checked":""} ${dis}> Viento preview en árboles</label><label class="bss-mini-field"><span>Fuerza X</span><input class="bss-input" type="number" step="0.1" data-bss106-wind="amplitude" value="${N(w.amplitude,3)}" ${dis}></label><label class="bss-mini-field"><span>Velocidad</span><input class="bss-input" type="number" step="0.1" data-bss106-wind="speed" value="${N(w.speed,1)}" ${dis}></label><label class="bss-mini-field"><span>Rotación °</span><input class="bss-input" type="number" step="0.1" data-bss106-wind="rotation" value="${N(w.rotation,2)}" ${dis}></label></div><div class="bss-mini-grid"><label class="bss-check"><input type="checkbox" data-bss106-cloud-bool="enabled" ${c.enabled!==false?"checked":""} ${dis}> Mostrar nubes</label><label class="bss-mini-field"><span>Nube día</span><input type="color" data-bss106-cloud-color="dayColor" value="${E(this.bss106CloudTint(c,"day"))}" ${dis}></label><label class="bss-mini-field"><span>Nube tarde</span><input type="color" data-bss106-cloud-color="dawnColor" value="${E(this.bss106CloudTint(c,"dawn"))}" ${dis}></label><label class="bss-mini-field"><span>Nube noche</span><input type="color" data-bss106-cloud-color="nightColor" value="${E(this.bss106CloudTint(c,"night"))}" ${dis}></label><label class="bss-mini-field"><span>Z agua base</span><input class="bss-input" type="number" step="1" data-bss106-scene="waterBaseZ" value="${N(d.waterBaseZ,0)}" ${dis}></label><label class="bss-mini-field"><span>Z FX agua arriba</span><input class="bss-input" type="number" step="1" data-bss106-scene="waterFxZ" value="${N(d.waterFxZ,2)}" ${dis}></label></div><p class="bss-note">El agua usa dos pasos: base abajo y una capa superior para el brillo/overlay. El cambio de cielo ya puede convivir con colores de nubes por hora.</p></section>`;
  };

  const _env106=App.prototype.bss088EnvironmentHTML;
  App.prototype.bss088EnvironmentHTML=function(scene){return _env106.call(this,scene)+this.bss106SceneExtraHTML(scene);};

  const _layerHTML106=App.prototype.bss088LayerInspectorHTML;
  App.prototype.bss088LayerInspectorHTML=function(scene){
    let html=_layerHTML106.call(this,scene),t=this.bss088SelectedTarget(scene);if(!t||t.type!=="img")return html;const d=t.data||{},ro=scene.kind!=="custom",dis=ro?"disabled":"";
    const block=`<details class="bss088-inspector-section bss106-time-tint"><summary><b>Color por hora</b><small>Opcional para preview y runtime raster.</small></summary><div class="bss-mini-grid"><label class="bss-mini-field"><span>Día</span><input type="color" data-bss106-tint-color="day:${E(this.bss092TargetId(t))}" value="${E(/^#[0-9a-f]{6}$/i.test(S(d.tintDayColor||""))?S(d.tintDayColor):"#FFFFFF")}" ${dis}></label><label class="bss-mini-field"><span>Alpha día</span><input class="bss-input" type="number" min="0" max="255" data-bss106-tint-alpha="day:${E(this.bss092TargetId(t))}" value="${N(d.tintDayAlpha,N(d.tintAlpha,0))}" ${dis}></label><label class="bss-mini-field"><span>Tarde</span><input type="color" data-bss106-tint-color="dawn:${E(this.bss092TargetId(t))}" value="${E(/^#[0-9a-f]{6}$/i.test(S(d.tintDawnColor||""))?S(d.tintDawnColor):S(d.tintColor||"#FFFFFF"))}" ${dis}></label><label class="bss-mini-field"><span>Alpha tarde</span><input class="bss-input" type="number" min="0" max="255" data-bss106-tint-alpha="dawn:${E(this.bss092TargetId(t))}" value="${N(d.tintDawnAlpha,N(d.tintAlpha,0))}" ${dis}></label><label class="bss-mini-field"><span>Noche</span><input type="color" data-bss106-tint-color="night:${E(this.bss092TargetId(t))}" value="${E(/^#[0-9a-f]{6}$/i.test(S(d.tintNightColor||""))?S(d.tintNightColor):S(d.tintColor||"#FFFFFF"))}" ${dis}></label><label class="bss-mini-field"><span>Alpha noche</span><input class="bss-input" type="number" min="0" max="255" data-bss106-tint-alpha="night:${E(this.bss092TargetId(t))}" value="${N(d.tintNightAlpha,N(d.tintAlpha,0))}" ${dis}></label></div></details>`;
    const mark='<section class="bss088-inspector-section"><div class="bss088-section-title"><div><b>Comportamiento</b>';
    const i=html.indexOf(mark);return i>=0?html.slice(0,i)+block+html.slice(i):html+block;
  };

  const _layerList106=App.prototype.bss088LayerListHTML;
  App.prototype.bss088LayerListHTML=function(scene){
    if(!scene)return _layerList106.call(this,scene);
    const ro=scene.kind!=="custom",selected=S(this.ebdx088SelectedLayer),all=this.bss092LayerEntries(scene),q=L(this.ebdx092LayerSearch||""),rows=all.filter(e=>!q||L(`${e.name} ${e.id} ${e.kind}`).includes(q)),selectedEntry=all.find(e=>e.id===selected),selectedTarget=selectedEntry&&this.bss092TargetById(scene,selectedEntry.id),selectedLocked=this.bss102TargetLocked(selectedTarget);
    const controls=ro||!selectedEntry?"":`<div class="bss092-layer-actions"><span>Orden</span><button type="button" title="Mandar al frente" data-bss092-depth="front" ${selectedLocked?"disabled":""}>⇑</button><button type="button" title="Subir una capa" data-bss092-depth="up" ${selectedLocked?"disabled":""}>↑</button><button type="button" title="Bajar una capa" data-bss092-depth="down" ${selectedLocked?"disabled":""}>↓</button><button type="button" title="Mandar al fondo" data-bss092-depth="back" ${selectedLocked?"disabled":""}>⇓</button><em>Z ${E(String(selectedEntry.z))}</em></div>`;
    const html=rows.map(e=>{const t=this.bss092TargetById(scene,e.id),locked=this.bss102TargetLocked(t),hidden=this.bss106TargetHidden(t);let sub="";if(e.type==="img")sub=`${E(this.bss088BehaviorLabel(this.bss088LayerBehavior(e.data)))} · Z ${E(String(e.z))} · ${Math.round(N(e.data.opacity,255)/255*100)}%`;else sub=`${E(e.data.bitmap||e.name)} · Z ${E(String(e.z))} · ×${E(String(N(this.bss088GroupValue(e.data,"zoom",e.index,1),1)))}`;return `<div role="button" tabindex="0" draggable="false" class="bss088-layer-row bss092-layer-row ${selected===e.id?"active":""} ${locked?"bss102-locked":""} ${hidden?"bss106-hidden":""}" data-bss088-layer-select="${E(e.id)}" data-bss092-drag-layer="${E(e.id)}"><span class="bss092-drag-grip" draggable="${ro||locked?"false":"true"}" style="cursor:${locked?"default":"grab"};" title="${locked?"Capa bloqueada":"Arrastra para cambiar profundidad"}">${locked?"•":"⋮⋮"}</span><span class="bss088-layer-main"><b>${hidden?"🙈 ":""}${E(e.name)}</b><small>${sub}</small></span><span class="bss088-layer-kind">${E(e.kind)}</span>${ro?"":`<button type="button" class="bss-btn small" data-bss106-hide="${E(e.id)}" title="${hidden?"Mostrar capa":"Ocultar capa"}">${hidden?"🙈":"👁"}</button><button type="button" class="bss102-lock ${locked?"active":""}" data-bss102-lock="${E(e.id)}" title="${locked?"Desbloquear capa":"Bloquear capa"}">${locked?"🔒":"🔓"}</button>`}</div>`;}).join("");
    return `<section class="bss088-layer-stack bss092-layer-stack"><div class="bss088-layer-stack-head bss092-layer-head"><div><b>Capas</b><small>De arriba hacia abajo = frente hacia fondo · 🔒 bloquea · 👁/🙈 mostrar u ocultar</small></div>${ro?"":'<button class="bss-btn small" type="button" data-bss089-dock-tab="elements">＋ Añadir</button>'}</div><div class="bss092-layer-search"><input class="bss-search" data-bss092-layer-search placeholder="Buscar capa…" value="${E(this.ebdx092LayerSearch||"")}"></div>${controls}<div class="bss088-layer-list">${html||'<div class="bss-empty small">No hay capas que coincidan.</div>'}</div><div class="bss092-layer-shortcuts"><span>Oculta/bloquea capas terminadas antes de colocar otras.</span><span>↑↓ mueve · Ctrl+↑/↓ profundidad · Shift = 1 px</span></div></section>`;
  };

  const _hits106=App.prototype.bss092HitAreas;
  App.prototype.bss092HitAreas=async function(view){
    const out=await _hits106.call(this,view),scene=this.bss088SceneFromState();
    return A(out).filter(a=>{const t=scene&&this.bss092TargetById(scene,a.id);return !(t&&(this.bss102TargetLocked&&this.bss102TargetLocked(t)||this.bss106TargetHidden(t)));});
  };

  const _click106=App.prototype.onClick;
  App.prototype.onClick=function(e){
    const raw=e&&e.target,t=raw&&typeof raw.closest==="function"?raw.closest('[data-bss106-hide],[data-bss106-preset],[data-bss106-preview-slot]'):null;
    if(t&&t.dataset){
      if(t.dataset.bss106PreviewSlot!=null){
        const val=S(t.dataset.bss106PreviewSlot);
        this._bssPreviewTimeSlot=(val==="auto"?null:val);
        this._bss104ImageCache&&this._bss104ImageCache.clear();
        this.bss089RefreshInspectorOnly&&this.bss089RefreshInspectorOnly();
        this.bss089RedrawPreview&&this.bss089RedrawPreview();
        return;
      }
      if(t.dataset.bss106Hide!=null){const scene=this.bss088SceneFromState(),target=scene&&this.bss092TargetById(scene,S(t.dataset.bss106Hide));if(target){this.bss089HistoryCheckpoint("Mostrar/ocultar capa");this.bss106SetTargetHidden(target,!this.bss106TargetHidden(target));this.saveSoon();this.bss089RefreshDock();this.bss089RefreshInspectorOnly();this.bss089RedrawPreview();}return;}
      if(t.dataset.bss106Preset!=null){const scene=this.bss088SceneFromState();if(scene&&scene.kind==="custom"){
        this.bss089HistoryCheckpoint("Preset de preview");const c=this.bss106CloudConfig(scene),w=this.bss106WindConfig(scene),d=scene.data||{};
        switch(S(t.dataset.bss106Preset)){
          case "wind_off": w.enabled=false;w.amplitude=0;w.speed=0;w.rotation=0;break;
          case "wind_soft": w.enabled=true;w.amplitude=2.5;w.speed=0.8;w.rotation=1.5;break;
          case "wind_strong": w.enabled=true;w.amplitude=6;w.speed=1.6;w.rotation=4;break;
          case "clouds_soft": c.enabled=true;c.dayColor="#e8f5ff";c.dawnColor="#ffd4b3";c.nightColor="#b7caff";d.waterFxZ=N(d.waterFxZ,2);break;
          case "clouds_off": c.enabled=false;break;
        }
        this.saveSoon();this.bss089RefreshInspectorOnly();this.bss089RedrawPreview();
      }return;}
    }
    return _click106.call(this,e);
  };

  const _input106=App.prototype.onInput;
  App.prototype.onInput=function(e){
    const t=e&&e.target,scene=this.bss088SceneFromState();
    if(t&&t.dataset&&scene&&scene.kind==="custom"){
      if(t.dataset.bss106Wind!=null){const w=this.bss106WindConfig(scene);w[S(t.dataset.bss106Wind)]=N(t.value,0);this.saveSoon();this.bss089RedrawPreview();return;}
      if(t.dataset.bss106WindBool!=null){const w=this.bss106WindConfig(scene);w[S(t.dataset.bss106WindBool)]=!!t.checked;this.saveSoon();this.bss089RedrawPreview();return;}
      if(t.dataset.bss106CloudBool!=null){const c=this.bss106CloudConfig(scene);c[S(t.dataset.bss106CloudBool)]=!!t.checked;this.saveSoon();this.bss089RedrawPreview();return;}
      if(t.dataset.bss106CloudColor!=null){const c=this.bss106CloudConfig(scene);c[S(t.dataset.bss106CloudColor)]=S(t.value||"#FFFFFF");this.saveSoon();this.bss089RedrawPreview();return;}
      if(t.dataset.bss106Scene!=null){scene.data[S(t.dataset.bss106Scene)]=N(t.value,0);this.saveSoon();this.bss089RedrawPreview();return;}
      if(t.dataset.bss106TintColor!=null){const [slot,id]=S(t.dataset.bss106TintColor).split(":");const trg=this.bss092TargetById(scene,id);if(trg&&trg.type==="img"){const key=(slot==="night"?"tintNightColor":slot==="dawn"?"tintDawnColor":"tintDayColor");trg.data[key]=S(t.value||"#FFFFFF");this.saveSoon();this.bss089RedrawPreview();}return;}
      if(t.dataset.bss106TintAlpha!=null){const [slot,id]=S(t.dataset.bss106TintAlpha).split(":");const trg=this.bss092TargetById(scene,id);if(trg&&trg.type==="img"){const key=(slot==="night"?"tintNightAlpha":slot==="dawn"?"tintDawnAlpha":"tintDayAlpha");trg.data[key]=Math.max(0,Math.min(255,N(t.value,0)));this.saveSoon();this.bss089RedrawPreview();}return;}
    }
    return _input106.call(this,e);
  };

  const _logical106=App.prototype.bss101LogicalComposite;
  App.prototype.bss101LogicalComposite=async function(view){
    const data=view&&view.data||{},logical=document.createElement("canvas");logical.width=384;logical.height=308;const ctx=logical.getContext("2d");ctx.imageSmoothingEnabled=false;const time=this.bss102PreviewSeconds?this.bss102PreviewSeconds():0,slot=this.bss106SceneTimeSlot(view);
    const prevSlot=this._bss106CurrentSlot,prevSky=this._bss099SkyOverride,prevAmb=this._bss106AmbientBackground;
    this._bss106CurrentSlot=slot;
    this._bss106AmbientBackground=true;
    if(!this._bss099SkyOverride&&this.bss099SkyOverridePath)this._bss099SkyOverride=this.bss099SkyOverridePath(view);
    try{
      const baseData=typeof deep102==="function"?deep102(data):JSON.parse(JSON.stringify(data||{}));delete baseData.water;delete baseData.trees;delete baseData.tallGrass;delete baseData.cloudsConfig;if(typeof imgKeys102==="function")imgKeys102(baseData).forEach(k=>delete baseData[k]);
      try{const prevSuppress=this._bss102SuppressClouds;this._bss102SuppressClouds=true;const baseState=await _logical106.call(this,Object.assign({},view,{data:baseData,kind:"builtin"}));this._bss102SuppressClouds=prevSuppress;if(baseState&&baseState.canvas)ctx.drawImage(baseState.canvas,0,0);}catch(_){this._bss102SuppressClouds=false;ctx.fillStyle="#182331";ctx.fillRect(0,0,384,308);}
      const ops=[],push=(z,order,draw,id)=>ops.push({z:N(z,0),order,id,draw});
      const wind=data.windConfig&&typeof data.windConfig==="object"?data.windConfig:{};
      const groupHidden=(g,i)=>!!(Array.isArray(g&&g.hidden)&&g.hidden[i]===true);
      const groupOp=async(groupName,def,order)=>{
        const g=data[groupName];if(!g||typeof g!=="object")return;const im0=await this.bss083LoadImage(this.bss083EBDXAssetPath("elements",g.bitmap||def));if(!im0)return;const n=Math.max(0,N(g.elements,Array.isArray(g.x)?g.x.length:0));
        for(let i=0;i<n;i++){
          if(groupHidden(g,i))continue;
          const x=Array.isArray(g.x)?N(g.x[i],0):0,y=Array.isArray(g.y)?N(g.y[i],0):0,zoom=Array.isArray(g.zoom)?N(g.zoom[i],1):1,mir=!!(Array.isArray(g.mirror)&&g.mirror[i]),z=Array.isArray(g.z)?N(g.z[i],groupName==="trees"?1:0):(groupName==="trees"?1:0);
          push(z,order+i/1000,()=>{ctx.save();ctx.imageSmoothingEnabled=false;ctx.filter="none";let im=im0,mode=Object.prototype.hasOwnProperty.call(g,"colorize")?g.colorize:true;if(mode!==false){const sample=this.bss083SampleCanvas(ctx,x,y);im=this.bss083CanvasTint(im0,sample,S(mode)==="slight"?128:255);}if(slot!=="day"&&this.bss106AmbientCanvas)im=this.bss106AmbientCanvas(im,slot);let swayX=0,angle=0;if(groupName==="trees"&&wind.enabled!==false){const amp=Math.max(0,N(wind.amplitude,3)),speed=Math.max(0.05,N(wind.speed,1)),rot=Math.max(0,N(wind.rotation,2)),phase=i*.75;swayX=Math.sin(time*2.4*speed+phase)*amp*zoom*.5;angle=Math.sin(time*2.1*speed+phase)*rot;}this.bss083DrawAnchored(ctx,im,x+swayX,y,zoom,mir,null,null,angle);ctx.restore();ctx.imageSmoothingEnabled=false;ctx.filter="none";},`group:${groupName}:${i}`);
        }
      };
      await groupOp("trees","tree",20);await groupOp("tallGrass","tallGrass",30);
      if(data.water){for(let i=0;i<2;i++){const im=await this.bss083LoadImage(this.bss083EBDXAssetPath("elements",`water${i}`));if(!im)continue;const z=i===0?N(data.waterBaseZ,0):N(data.waterFxZ,2);push(z,50+i,()=>{const speed=i===0?1:.5,dir=i===0?1:-1,shift=(time*40*speed*dir)%Math.max(1,im.width),w=im.width;ctx.save();for(let n=-2;n<4;n++){let px=n*w-shift;if(i===0)ctx.drawImage(im,px,146);else{ctx.save();ctx.translate(px+w,0);ctx.scale(-1,1);ctx.drawImage(im,0,146);ctx.restore();}}ctx.restore();},`water${i}`);}}
      const keys=typeof imgKeys102==="function"?imgKeys102(data):Object.keys(data||{}).filter(k=>/^img\d+/i.test(k));
      for(const key of keys){const d=data[key];if(!d||d.hidden===true)continue;const visual=await this.bss101LayerVisual(view.id||"scene",key,d);let im=visual?visual.canvas:await this.bss083LoadImage(this.bss083EBDXAssetPath("elements",d.bitmap));if(!im)continue;if(!visual&&this.bss102SheetVisual)im=this.bss102SheetVisual(im,d,time);const tint=this.bss106LayerTint(d,slot);if(tint.alpha>0&&this.bss102TintVisual)im=this.bss102TintVisual(im,tint.color,tint.alpha);else if(d.shading!==false&&slot!=="day"&&this.bss106AmbientCanvas)im=this.bss106AmbientCanvas(im,slot);const x=N(d.x,0),y=N(d.y,0),baseZ=N(d.z,0),zoom=N(d.zoom,1),zx=d.zoom_x!=null?N(d.zoom_x,zoom):zoom,zy=d.zoom_y!=null?N(d.zoom_y,zoom):zoom,ox=visual?visual.ox:(d.ox!=null?N(d.ox,0):null),oy=visual?visual.oy:(d.oy!=null?N(d.oy,0):null),angle=N(d.angle,0),opacity=Math.max(0,Math.min(255,N(d.opacity,255)))/255;push(baseZ,60+baseZ/1000,()=>{let use=im;if(d.colorize===true||S(d.colorize)==="slight"){const sample=this.bss083SampleCanvas(ctx,x,y);use=this.bss083CanvasTint(im,sample,S(d.colorize)==="slight"?128:255);}ctx.save();ctx.imageSmoothingEnabled=false;ctx.filter="none";ctx.globalAlpha=opacity;if(d.scrolling&&!visual&&angle===0){const tileW=Math.max(1,use.width*Math.abs(zx)),tileH=Math.max(1,use.height*Math.abs(zy)),anchorX=(ox!=null?ox:use.width/2)*Math.abs(zx),anchorY=(oy!=null?oy:use.height)*Math.abs(zy),phase=time*40*Math.abs(N(d.speed,1))*(N(d.direction,1)<0?-1:1);if(d.vertical){const xx=x-anchorX,baseY=y-anchorY,startY=((baseY%tileH)+tileH)%tileH-tileH;for(let py=startY;py<308+tileH;py+=tileH)ctx.drawImage(use,xx,py,use.width*zx,use.height*zy);}else{const yy=y-anchorY,baseX=x-anchorX-phase,startX=((baseX%tileW)+tileW)%tileW-tileW;for(let px=startX;px<384+tileW;px+=tileW)ctx.drawImage(use,px,yy,use.width*zx,use.height*zy);}}else this.bss083DrawAnchored(ctx,use,x,y,zx,false,ox,oy,angle,zy);ctx.restore();ctx.imageSmoothingEnabled=false;ctx.filter="none";},key);}
      if(data.sky){const c=this.bss106CloudConfig({data});if(c&&c.enabled!==false){for(let i=1;i<=2;i++){let im=await this.bss083LoadImage(this.bss083EBDXAssetPath("elements",`cloud${i}`));if(!im)continue;if(this.bss102TintVisual)im=this.bss102TintVisual(im,this.bss106CloudTint(c,slot),255);const x=N(c[`cloud${i}X`],0),y=N(c[`cloud${i}Y`],i===1?98:91),speed=Math.abs(N(c[`cloud${i}Speed`],i===1?1:.5)),dir=N(c[`cloud${i}Direction`],i===1?1:-1)<0?-1:1,opacity=Math.max(0,Math.min(255,N(c[`cloud${i}Opacity`],255)))/255,phase=time*40*speed*dir;push(-8,5+i,()=>{ctx.save();ctx.globalAlpha=opacity;const start=((x-phase)%Math.max(1,im.width)+im.width)%im.width-im.width;for(let px=start;px<384+im.width;px+=im.width)ctx.drawImage(im,px,y-im.height);ctx.restore();},`cloud${i}`);}}}
      ops.sort((a,b)=>a.z-b.z||a.order-b.order);for(const op of ops)try{op.draw();}catch(_){ }
      return {canvas:logical,ctx,ops};
    }finally{
      this._bss106CurrentSlot=prevSlot;
      this._bss099SkyOverride=prevSky;
      this._bss106AmbientBackground=prevAmb;
    }
  };
})();

// ============================================================================
// BSS v0.8.34 - terminal editor authority / visible stability reset
// ============================================================================
(function(){
  if(typeof App==="undefined")return;

  // Make it obvious which build is actually loaded. This is intentionally in
  // the EBDX header because several previous builds looked identical even when
  // the user had successfully overwritten the mod.
  const _render107=App.prototype.renderEBDXStudio;
  App.prototype.renderEBDXStudio=function(){
    const out=_render107.call(this);
    try{
      const head=this.body&&this.body.querySelector('.bss079-ebdx-header,.bss079-head,.bss-stagebar');
      if(head&&!head.querySelector('[data-bss107-build]')){
        const badge=document.createElement('span');badge.dataset.bss107Build='1';badge.className='bss107-build';badge.textContent='BSS 0.8.35 · F12-safe update';head.appendChild(badge);
      }
    }catch(_){ }
    return out;
  };

  // Refresh Graphics without reopening MakerStudio. This is the explicit path
  // for newly imported tiles/props that were absent from source.allGraphics when
  // BSS was first opened.
  App.prototype.bss107RescanGraphics=async function(){
    if(this._bss107Rescanning)return;this._bss107Rescanning=true;
    try{
      this.toast('Reescaneando Graphics…');
      const g=await scanProjectGraphicsSource(this.ctx);
      this.source=Object.assign({},this.source||{},g||{});
      this._bss104ImageCache&&this._bss104ImageCache.clear();
      this.assetUrlCache&&this.assetUrlCache.clear();
      this.ebdx088AssetSearch='';this.ebdx088AssetCategory='all';
      this.bss089RefreshDock&&this.bss089RefreshDock();
      this.bss100RefreshAssetBrowser&&this.bss100RefreshAssetBrowser();
      this.toast(`Graphics actualizados · ${A(this.source&&this.source.allGraphics).length} imágenes`);
    }catch(err){this.toast('No se pudo reescanear Graphics: '+S(err&&err.message||err),true);}finally{this._bss107Rescanning=false;}
  };

  const _assetRows107=App.prototype.bss087SceneAssetRows;
  App.prototype.bss087SceneAssetRows=function(){
    const base=A(_assetRows107.call(this)),all=A(this.source&&this.source.allGraphics),out=base.slice(),seen=new Set(out.map(x=>L(S(x&&x.projectPath).replace(/\\/g,'/'))));
    for(const x of all){
      const p=S(x&&x.projectPath).replace(/\\/g,'/'),lp=L(p);if(!p||seen.has(lp))continue;
      if(!/\.(png|gif|jpe?g|webp|bmp)$/i.test(p))continue;
      // Extra user-authored EBDX folders are legitimate element sources too.
      const ebdx=/^Graphics\/BattleSceneStudio\/EBDX\//i.test(p),tiles=/^Graphics\/Tilesets\//i.test(p);
      if(!ebdx&&!tiles)continue;
      if(/\/(Generated|preview|battlebg|base)\//i.test(p))continue;
      if(/\/(references|_licenses|licenses?)\//i.test(p))continue;
      seen.add(lp);out.push(Object.assign({},x,{projectPath:p,name:S(x&&x.name)||p.split('/').pop()}));
    }
    return out.sort((a,b)=>this.bss088AssetCategoryOf(a.projectPath).localeCompare(this.bss088AssetCategoryOf(b.projectPath),undefined,{numeric:true,sensitivity:'base'})||S(a.name).localeCompare(S(b.name),undefined,{numeric:true,sensitivity:'base'}));
  };

  App.prototype.bss088AssetCategoryOf=(function(base){return function(path){
    const p=S(path).replace(/\\/g,'/');
    if(/^Graphics\/Tilesets\//i.test(p))return 'Proyecto · Tilesets';
    if(/\/Battlebacks\/elements\//i.test(p))return 'EBDX · Elementos';
    if(/^Graphics\/BattleSceneStudio\/EBDX\//i.test(p)&&!/\/SceneAssets\//i.test(p))return 'EBDX · Custom';
    return base.call(this,path);
  };})(App.prototype.bss088AssetCategoryOf);

  const _dock107=App.prototype.bss089ElementsDockHTML;
  App.prototype.bss089ElementsDockHTML=function(scene){
    let html=_dock107.call(this,scene);
    if(!scene||scene.kind!=="custom")return html;
    const marker='<div class="bss100-elements-head">';
    const i=html.indexOf(marker);
    if(i>=0){const end=html.indexOf('</div>',i+marker.length);if(end>=0)html=html.slice(0,end+6)+`<button type="button" class="bss-btn small bss107-rescan" data-bss107-rescan>↻ Reescanear Graphics</button>`+html.slice(end+6);}
    return html;
  };

  const _click107=App.prototype.onClick;
  App.prototype.onClick=function(e){
    const raw=e&&e.target,t=raw&&typeof raw.closest==="function"?raw.closest('[data-bss107-rescan]'):null;
    if(t){this.bss107RescanGraphics();return;}
    return _click107.call(this,e);
  };

  // Locked layers must remain selectable. Lock means "do not move", not
  // "become impossible to detect". Hidden layers alone leave the hit-test set.
  const _hits107=App.prototype.bss092HitAreas;
  App.prototype.bss092HitAreas=async function(view){
    let out=[];try{out=await _hits107.call(this,view);}catch(_){out=[];}
    const scene=this.bss088SceneFromState();
    // Re-add locked entries if an earlier wrapper filtered them out.
    if(view&&view.kind==='custom'&&scene){
      for(const e of this.bss092LayerEntries(scene)){
        const t=this.bss092TargetById(scene,e.id);if(!t||this.bss106TargetHidden&&this.bss106TargetHidden(t))continue;
        if(out.some(a=>a.id===e.id))continue;
        if(t.type==='img'){
          const d=t.data||{},visual=await this.bss101LayerVisual(view.id||'scene',t.key,d),im=visual?visual.canvas:await this.bss083LoadImage(this.bss083EBDXAssetPath('elements',d.bitmap));if(!im)continue;
          const zoom=N(d.zoom,1),zx=d.zoom_x!=null?N(d.zoom_x,zoom):zoom,zy=d.zoom_y!=null?N(d.zoom_y,zoom):zoom,ox=visual?visual.ox:(d.ox!=null?N(d.ox,0):im.width/2),oy=visual?visual.oy:(d.oy!=null?N(d.oy,0):im.height),b=this.bss092ImageBounds(N(d.x,0),N(d.y,0),im.width,im.height,ox,oy,zx,zy,N(d.angle,0));out.push(Object.assign({id:e.id,kind:'img',key:t.key,x:N(d.x,0),y:N(d.y,0),z:N(d.z,0)},b));
        }
      }
    }
    return out.filter(a=>{const t=scene&&this.bss092TargetById(scene,a.id);return !(t&&this.bss106TargetHidden&&this.bss106TargetHidden(t));}).sort((a,b)=>N(b.z,0)-N(a.z,0));
  };

  // Hidden means visually absent. Do not leave deformation/blur chrome behind
  // after the image itself was hidden. Also draw mesh ONLY in explicit edit.
  const _overlay107=App.prototype.bss101DrawEditOverlay;
  App.prototype.bss101DrawEditOverlay=function(canvas,view,state,game){
    const sel=S(this.ebdx088SelectedLayer),d=view&&view.data&&view.data[sel];
    if(d&&d.hidden===true)return;
    const cfg=this.bss093WarpConfig&&this.bss093WarpConfig(d),editing=cfg&&S(this.ebdx093WarpEditKey)===sel;
    if(cfg&&!editing){
      const v=Object.assign({},view,{data:Object.assign({},view.data)}),copy=Object.assign({},d);delete copy.warp;v.data[sel]=copy;return _overlay107.call(this,canvas,v,state,game);
    }
    return _overlay107.call(this,canvas,view,state,game);
  };

  // The sky override wrapper from v0.8.19 was later shadowed by complete
  // compositor replacements. Reinstate it at the terminal compositor boundary.
  const _composite107=App.prototype.bss083EBDXComposite;
  App.prototype.bss083EBDXComposite=async function(canvas,view){
    const prevSky=this._bss099SkyOverride;
    const prevSlot=this._bss106CurrentSlot;
    const prevAmb=this._bss106AmbientBackground;
    this._bss099SkyOverride=this.bss099SkyOverridePath?this.bss099SkyOverridePath(view):'';
    this._bss106CurrentSlot=this.bss106SceneTimeSlot?this.bss106SceneTimeSlot(view):'day';
    this._bss106AmbientBackground=true;
    try{return await _composite107.call(this,canvas,view);}
    finally{
      this._bss099SkyOverride=prevSky;
      this._bss106CurrentSlot=prevSlot;
      this._bss106AmbientBackground=prevAmb;
    }
  };
})();

// ============================================================================
// BSS v0.8.36 - element discovery + readable layer bands
// ============================================================================
(function(){
  if(typeof App==="undefined")return;

  App.prototype.bss108LayerBand=function(entry){
    if(!entry)return "ESCENA";
    const d=entry.data||{},z=N(entry.z,0),p=L(S(d.bitmap||""));
    if(d._bssFloor===true||p.includes('/battlebacks/base/'))return "SUELO";
    if(z<=0)return "FONDO";
    if(z<=3)return "ESCENA";
    if(z<=9)return "DECOR";
    return "FRENTE";
  };

  const _entries108=App.prototype.bss092LayerEntries;
  App.prototype.bss092LayerEntries=function(scene){
    const rows=A(_entries108.call(this,scene));
    for(const e of rows){const band=this.bss108LayerBand(e);e.kind=`${band} · ${e.type==='img'?(e.data&&e.data.bssRigid===true?'RÍGIDO':(e.data&&e.data.flat===true?'PLANO':'PROF.')):'GRUPO'}`;}
    return rows;
  };

  // A Graphics rescan must pass through the same normalizer as the initial scan;
  // otherwise allGraphics can be populated while the EBDX asset browser still
  // sees stale/partial rows.
  App.prototype.bss107RescanGraphics=async function(){
    if(this._bss107Rescanning)return;this._bss107Rescanning=true;
    try{
      this.toast('Reescaneando Graphics…');
      const g=await scanProjectGraphicsSource(this.ctx);
      this.source=normalizeSourceRows(Object.assign({},this.source||{},g||{}, {graphicsReady:true}));
      this._bss104ImageCache&&this._bss104ImageCache.clear();
      this.assetUrlCache&&this.assetUrlCache.clear();
      this.assetUrlPending&&this.assetUrlPending.clear();
      this.ebdx088AssetSearch='';this.ebdx088AssetCategory='all';
      this.bss089RefreshDock&&this.bss089RefreshDock();
      this.bss100RefreshAssetBrowser&&this.bss100RefreshAssetBrowser();
      this.toast(`Graphics actualizados · ${A(this.source&&this.source.allGraphics).length} imágenes detectadas`);
    }catch(err){this.toast('No se pudo reescanear Graphics: '+S(err&&err.message||err),true);}finally{this._bss107Rescanning=false;}
  };

  const _rows108=App.prototype.bss087SceneAssetRows;
  App.prototype.bss087SceneAssetRows=function(){
    const out=A(_rows108.call(this)).slice(),seen=new Set(out.map(x=>L(S(x&&x.projectPath).replace(/\\/g,'/'))));
    const add=(x,p)=>{p=S(p||'').replace(/\\/g,'/');const lp=L(p);if(!p||seen.has(lp)||!/\.(png|gif|jpe?g|webp|bmp)$/i.test(p))return;seen.add(lp);out.push(Object.assign({},x||{},{projectPath:p,name:S(x&&x.name)||p.split('/').pop()}));};
    for(const x of A(this.source&&this.source.allGraphics)){
      const p=S(x&&x.projectPath).replace(/\\/g,'/');
      if(!/^Graphics\//i.test(p))continue;
      const useful=/^Graphics\/(?:Tilesets|Battlebacks|Animations|Pictures)\//i.test(p)||/^Graphics\/BattleSceneStudio\/EBDX\//i.test(p);
      if(!useful)continue;
      if(/\/(?:Generated|preview|references|_licenses|licenses?)\//i.test(p))continue;
      add(x,p);
    }
    // Always expose paths already referenced by authored scenes, even if the
    // MakerStudio graphics scanner omitted that folder. This is especially
    // important for cropped Graphics/Tilesets assets.
    for(const s of A(this.studio&&this.studio.global&&this.studio.global.ebdxCustomEnvironments)){
      const d=s&&s.data||{};for(const k of Object.keys(d)){if(!/^img\d+/i.test(k)||!d[k]||typeof d[k]!=="object")continue;const p=S(d[k].bitmap);if(/^Graphics\//i.test(p))add(null,p);}
    }
    return out.sort((a,b)=>this.bss088AssetCategoryOf(a.projectPath).localeCompare(this.bss088AssetCategoryOf(b.projectPath),undefined,{numeric:true,sensitivity:'base'})||S(a.name).localeCompare(S(b.name),undefined,{numeric:true,sensitivity:'base'}));
  };

  const _cat108=App.prototype.bss088AssetCategoryOf;
  App.prototype.bss088AssetCategoryOf=function(path){
    const p=S(path).replace(/\\/g,'/');
    if(/^Graphics\/Animations\//i.test(p))return 'Proyecto · Animations';
    if(/^Graphics\/Battlebacks\//i.test(p))return 'Proyecto · Battlebacks';
    if(/^Graphics\/Pictures\//i.test(p))return 'Proyecto · Pictures';
    return _cat108.call(this,path);
  };

  const _sceneInspector108=App.prototype.bss088SceneInspectorHTML;
  App.prototype.bss088SceneInspectorHTML=function(scene){
    let html=_sceneInspector108.call(this,scene);if(!scene)return html;
    const legend='<section class="bss088-inspector-section bss108-layer-legend"><div class="bss088-section-title"><div><b>Prioridad de escenario</b><small>Todos siguen siendo FONDO frente a Pokémon/BAS. La banda solo ordena elementos entre sí.</small></div></div><div class="bss-row"><span class="bss108-band">FONDO · Z≤0</span><span class="bss108-band">ESCENA · Z1–3</span><span class="bss108-band">DECOR · Z4–9</span><span class="bss108-band">FRENTE · Z10–40</span></div><p class="bss-note">Agua base usa Z -2 y su brillo/FX Z 1 si no has definido valores custom.</p></section>';
    const mark='<details class="bss088-json">',i=html.indexOf(mark);return i>=0?html.slice(0,i)+legend+html.slice(i):html+legend;
  };

  const _render108=App.prototype.renderEBDXStudio;
  App.prototype.renderEBDXStudio=function(){
    const out=_render108.call(this);
    try{const badge=this.body&&this.body.querySelector('[data-bss107-build]');if(badge)badge.textContent='BSS 0.8.37 · fidelity lighting & visual parity';}catch(_){ }
    return out;
  };

  const _clickMidbattle = App.prototype.onClick;
  App.prototype.onClick = function(e) {
    const raw = e && e.target, t = raw && typeof raw.closest === "function" ? raw.closest("button,[data-act]") : null;
    if (t && t.dataset) {
      const act = S(t.dataset.act);
      if (act === "setup-ai-preset") {
        const b = this.battle();
        if (b) {
          b.setup.aiSkill = N(t.dataset.val, 100);
          this.touch();
          this.refreshInspector();
        }
        return;
      }
      if (act === "boss-ai-preset") {
        const b = this.battle();
        if (b) {
          b.boss = b.boss || {};
          b.boss.aiSkill = N(t.dataset.val, 100);
          this.touch();
          this.refreshInspector();
        }
        return;
      }
      if (act === "dialogue-filter") {
        this.dialogueFilter = S(t.dataset.filter || "all");
        this.refreshInspector();
        return;
      }
      if (act === "dialogue-add") {
        const b = this.battle();
        if (b) {
          b.dialogues = b.dialogues || { enabled: true, midbattleScript: "", triggers: [] };
          if (!Array.isArray(b.dialogues.triggers)) b.dialogues.triggers = [];
          const target = this.dialogueFilter !== "all" ? this.dialogueFilter : "boss";
          b.dialogues.triggers.push({
            id: "dia_" + Date.now().toString(36) + "_" + Math.random().toString(36).slice(2, 6),
            event: "RoundStartCommand",
            target: target,
            speaker: target === "sos" ? "sos" : "boss",
            speakerName: "",
            text: "¡No podrás derrotarme!",
            style: "cinematic",
            textboxType: "cinematic",
            showNamebox: true,
            choices: [],
            choiceResponses: [],
            choiceEffects: [],
            playCry: false,
            screenShake: false,
            repeat: false,
            turn: 0
          });
          this.syncDialogueTriggers(b);
          this.touch();
          this.refreshInspector();
        }
        return;
      }
      if (act === "dialogue-remove") {
        const b = this.battle();
        if (b && b.dialogues && Array.isArray(b.dialogues.triggers)) {
          const idx = N(t.dataset.idx, -1);
          if (idx >= 0) {
            b.dialogues.triggers.splice(idx, 1);
            this.syncDialogueTriggers(b);
            this.touch();
            this.refreshInspector();
          }
        }
        return;
      }
      if (act === "dialogue-clear") {
        const b = this.battle();
        if (b && b.dialogues) {
          b.dialogues.triggers = [];
          this.syncDialogueTriggers(b);
          this.touch();
          this.refreshInspector();
        }
        return;
      }
      if (act === "dialogue-tpl-wild") {
        const b = this.battle();
        if (b) {
          b.dialogues = b.dialogues || { enabled: true, midbattleScript: "", triggers: [] };
          b.dialogues.triggers = [
            { id: "dia_w1", event: "RoundStartAttack", target: "boss", speaker: "narrator", text: "¡El Pokémon dominante emite un rugido ensordecedor que hace temblar el terreno!", style: "cinematic", textboxType: "cinematic", showNamebox: false, choices: [], choiceResponses: [], playCry: true, screenShake: true, repeat: false, turn: 1 },
            { id: "dia_w2", event: "TargetHPHalf", target: "boss", speaker: "narrator", text: "¡El Pokémon dominante jadea furioso ante la presión del combate!\n¡Una intensa aura de furia comienza a emanar de su cuerpo!", style: "cinematic", textboxType: "cinematic", showNamebox: false, choices: [], choiceResponses: [], playCry: true, screenShake: false, repeat: false, turn: 0 },
            { id: "dia_w3", event: "TargetHPLow", target: "boss", speaker: "narrator", text: "¡El Pokémon dominante reúne sus últimas fuerzas para un contraataque desesperado!", style: "cinematic", textboxType: "cinematic", showNamebox: false, choices: [], choiceResponses: [], playCry: true, screenShake: true, repeat: false, turn: 0 },
            { id: "dia_w4", event: "ShieldBreak", target: "boss", speaker: "narrator", text: "¡La barrera protectora del Pokémon dominante se ha hecho añicos!", style: "cinematic", textboxType: "cinematic", showNamebox: false, choices: [], choiceResponses: [], playCry: false, screenShake: true, repeat: false, turn: 0 },
            { id: "dia_w5", event: "SOSSuccess", target: "boss", speaker: "narrator", text: "¡El Pokémon dominante pide ayuda y un aliado responde a su llamado!", style: "cinematic", textboxType: "cinematic", showNamebox: false, choices: [], choiceResponses: [], playCry: true, screenShake: false, repeat: false, turn: 0 },
            { id: "dia_w6", event: "BattlerFainted", target: "boss", speaker: "narrator", text: "¡El Pokémon dominante cae exhausto tras una feroz batalla!", style: "cinematic", textboxType: "cinematic", showNamebox: false, choices: [], choiceResponses: [], playCry: false, screenShake: false, repeat: false, turn: 0 }
          ];
          this.syncDialogueTriggers(b);
          this.touch();
          this.refreshInspector();
        }
        return;
      }
      if (act === "dialogue-tpl-trainer") {
        const b = this.battle();
        if (b) {
          b.dialogues = b.dialogues || { enabled: true, midbattleScript: "", triggers: [] };
          b.dialogues.triggers = [
            { id: "dia_t1", event: "RoundStartCommand", target: "boss", speaker: "trainer", text: "¡Espero que estés listo para un combate de verdad!\n¡Demuéstrame lo que tú y tus Pokémon son capaces de hacer!", style: "cinematic", textboxType: "cinematic", showNamebox: true, choices: [], choiceResponses: [], playCry: false, screenShake: false, repeat: false, turn: 1 },
            { id: "dia_t2", event: "TargetHPHalf", target: "boss", speaker: "trainer", text: "¡Nada mal! Tu técnica es más sólida de lo que imaginaba.\n¡Pero aún estamos muy lejos del final!", style: "cinematic", textboxType: "cinematic", showNamebox: true, choices: [], choiceResponses: [], playCry: false, screenShake: false, repeat: false, turn: 0 },
            { id: "dia_t3", event: "TargetHPLow", target: "boss", speaker: "trainer", text: "¡Increíble potencia! Nos tienes contra las cuerdas...\n¡Aún así, un verdadero entrenador nunca se rinde hasta el último aliento!", style: "cinematic", textboxType: "cinematic", showNamebox: true, choices: [], choiceResponses: [], playCry: false, screenShake: true, repeat: false, turn: 0 },
            { id: "dia_t4", event: "BattleEndWin", target: "global", speaker: "trainer", text: "Has peleado con maestría y corazón. Una victoria totalmente merecida.", style: "cinematic", textboxType: "cinematic", showNamebox: true, choices: [], choiceResponses: [], playCry: false, screenShake: false, repeat: false, turn: 0 },
            { id: "dia_t5", event: "BattleEndLoss", target: "global", speaker: "trainer", text: "Buen combate, pero aún te falta entrenar más si quieres superarme.", style: "cinematic", textboxType: "cinematic", showNamebox: true, choices: [], choiceResponses: [], playCry: false, screenShake: false, repeat: false, turn: 0 }
          ];
          this.syncDialogueTriggers(b);
          this.touch();
          this.refreshInspector();
        }
        return;
      }
      if (act === "dialogue-tpl-sos") {
        const b = this.battle();
        if (b) {
          b.dialogues = b.dialogues || { enabled: true, midbattleScript: "", triggers: [] };
          b.dialogues.triggers = [
            { id: "dia_s1", event: "BattleStart", target: "sos", speaker: "narrator", text: "¡El aliado acude velozmente a respaldar al dominante!", style: "cinematic", textboxType: "cinematic", showNamebox: false, choices: [], choiceResponses: [], playCry: true, screenShake: false, repeat: false, turn: 0 },
            { id: "dia_s2", event: "TargetHPHalf", target: "sos", speaker: "narrator", text: "¡El aliado SOS flaquea ante tus ataques coordinados!", style: "cinematic", textboxType: "cinematic", showNamebox: false, choices: [], choiceResponses: [], playCry: false, screenShake: false, repeat: false, turn: 0 },
            { id: "dia_s3", event: "BattlerFainted", target: "sos", speaker: "narrator", text: "¡El aliado SOS no puede continuar y huye del combate!", style: "cinematic", textboxType: "cinematic", showNamebox: false, choices: [], choiceResponses: [], playCry: false, screenShake: false, repeat: false, turn: 0 }
          ];
          this.syncDialogueTriggers(b);
          this.touch();
          this.refreshInspector();
        }
        return;
      }
      if (act === "boss-midbattle-add") {
        const b = this.battle();
        if (b) {
          b.boss = b.boss || {};
          if (!Array.isArray(b.boss.midbattleTriggers)) b.boss.midbattleTriggers = [];
          b.boss.midbattleTriggers.push({
            id: "mbt_" + Date.now().toString(36) + "_" + Math.random().toString(36).slice(2, 6),
            event: "RoundStartCommand_foe",
            text: "¡No podrás derrotarme!",
            speaker: "opponent"
          });
          this.touch();
          this.refreshInspector();
        }
        return;
      }
      if (act === "boss-midbattle-remove") {
        const b = this.battle();
        if (b && b.boss && Array.isArray(b.boss.midbattleTriggers)) {
          const idx = N(t.dataset.idx, -1);
          if (idx >= 0) {
            b.boss.midbattleTriggers.splice(idx, 1);
            this.touch();
            this.refreshInspector();
          }
        }
        return;
      }
      if (act === "boss-midbattle-load-template") {
        const b = this.battle();
        if (b) {
          b.boss = b.boss || {};
          const isTrainer = b.setup && b.setup.kind === "trainer";
          const chosen = S(b.boss.midbattleScript);
          let template = [];
          if (chosen === "BOSS_TRAINER_EXAMPLE" || (!chosen && isTrainer)) {
            template = [
              { event: "RoundStartCommand_foe", text: "¡Espero que estés listo para un combate de verdad!\n¡Demuéstrame lo que tú y tus Pokémon son capaces de hacer!", speaker: "opponent" },
              { event: "TargetHPHalf_foe", text: "¡Nada mal! Tu técnica es más sólida de lo que imaginaba.\n¡Pero aún estamos muy lejos del final!", speaker: "opponent" },
              { event: "TargetHPLow_foe", text: "¡Increíble potencia! Nos tienes contra las cuerdas...\n¡Aún así, un verdadero entrenador nunca se rinde hasta el último aliento!", speaker: "opponent" },
              { event: "BeforeLastSwitchIn_foe", text: "¡Llegó la hora! ¡Sal a escena, compañero!\n¡Mostremos nuestro verdadero poder!", speaker: "opponent" },
              { event: "BattleEndWin", text: "Has peleado con maestría y corazón. Una victoria totalmente merecida.", speaker: "opponent" }
            ];
          } else if (chosen === "BOSS_TACTICAL_EXAMPLE") {
            template = [
              { event: "RoundStartAttack_foe", text: "¡Prepárate! ¡Esta batalla apenas comienza!", speaker: "opponent" },
              { event: "TargetHPHalf_foe", text: "¡No creas que nos vencerás tan fácilmente!\n¡Observa cómo damos la vuelta a este combate!", speaker: "opponent" },
              { event: "TargetHPLow_foe", text: "¡Jamás cederemos la victoria!", speaker: "opponent" }
            ];
          } else {
            template = [
              { event: "RoundStartAttack_foe", text: "¡El Pokémon dominante emite un rugido ensordecedor que hace temblar el terreno!", speaker: "narrator" },
              { event: "TargetHPHalf_foe", text: "¡El Pokémon dominante jadea furioso ante la presión del combate!\n¡Una intensa aura de furia comienza a emanar de su cuerpo!", speaker: "narrator" },
              { event: "TargetHPLow_foe", text: "¡El Pokémon dominante reúne sus últimas fuerzas para un contraataque desesperado!", speaker: "narrator" },
              { event: "BattlerFainted_foe", text: "¡El Pokémon dominante cae exhausto tras una feroz batalla!", speaker: "narrator" }
            ];
          }
          b.boss.midbattleTriggers = template.map(item => ({
            id: "mbt_" + Date.now().toString(36) + "_" + Math.random().toString(36).slice(2, 6),
            event: item.event,
            text: item.text,
            speaker: item.speaker
          }));
          this.touch();
          this.refreshInspector();
        }
        return;
      }
    }
    return _clickMidbattle.call(this, e);
  };

  App.prototype.syncDialogueTriggers = function(b) {
    if (!b) return;
    b.dialogues = b.dialogues || { enabled: true, midbattleScript: "", triggers: [] };
    b.boss = b.boss || {};
    b.boss.midbattleScript = b.dialogues.midbattleScript;
    b.boss.midbattleTriggers = (b.dialogues.triggers || []).map(t => {
      const suffix = t.target === "player" ? "_player" : (t.target === "sos" ? "_sos" : "_foe");
      const ev = t.event.includes("_") ? t.event : (t.event + suffix);
      return {
        id: t.id,
        event: ev,
        text: t.text,
        speaker: t.speaker === "narrator" ? "narrator" : "opponent",
        target: t.target,
        style: t.style,
        textboxType: t.textboxType || "cinematic",
        showNamebox: t.showNamebox !== false,
        choices: Array.isArray(t.choices) ? t.choices : [],
        choiceResponses: Array.isArray(t.choiceResponses) ? t.choiceResponses : [],
        choiceEffects: Array.isArray(t.choiceEffects) ? t.choiceEffects : [],
        playCry: t.playCry,
        screenShake: t.screenShake,
        repeat: t.repeat,
        turn: t.turn
      };
    });
  };

  const _inputMidbattle = App.prototype.onInput;
  App.prototype.onInput = function(e) {
    const t = e && e.target;
    if (t && t.dataset) {
      if (t.dataset.dialogueGlobal != null) {
        const b = this.battle();
        if (b) {
          b.dialogues = b.dialogues || { enabled: true, midbattleScript: "", triggers: [] };
          const fld = S(t.dataset.dialogueGlobal);
          b.dialogues[fld] = t.type === "checkbox" ? t.checked : t.value;
          this.syncDialogueTriggers(b);
          this.touch();
        }
        return;
      }
      if (t.dataset.dialogueChoiceIdx != null) {
        const b = this.battle();
        if (b && b.dialogues && Array.isArray(b.dialogues.triggers)) {
          const trigIdx = N(t.dataset.dialogueChoiceIdx, -1);
          const choiceIdx = N(t.dataset.choiceIdx, -1);
          const fld = S(t.dataset.choiceField);
          if (trigIdx >= 0 && b.dialogues.triggers[trigIdx] && choiceIdx >= 0) {
            const trig = b.dialogues.triggers[trigIdx];
            trig.choiceEffects = Array.isArray(trig.choiceEffects) ? trig.choiceEffects : [];
            while (trig.choiceEffects.length <= choiceIdx) {
              trig.choiceEffects.push({ type: "none", target: "player", stat: "ATTACK", stages: 1, percent: 25, status: "" });
            }
            let val = t.type === "number" ? N(t.value, 1) : t.value;
            trig.choiceEffects[choiceIdx][fld] = val;
            this.syncDialogueTriggers(b);
            this.touch();
            if (fld === "type") this.refreshInspector();
          }
        }
        return;
      }
      if (t.dataset.dialogueField != null) {
        const b = this.battle();
        if (b && b.dialogues && Array.isArray(b.dialogues.triggers)) {
          const idx = N(t.dataset.dialogueIdx, -1);
          const fld = S(t.dataset.dialogueField);
          if (idx >= 0 && b.dialogues.triggers[idx]) {
            let val = t.type === "checkbox" ? t.checked : (t.type === "number" ? N(t.value, 0) : t.value);
            if (fld === "choices") {
              val = String(t.value || "").split(/[,\n]/).map(s => s.trim()).filter(Boolean);
              const trig = b.dialogues.triggers[idx];
              trig.choiceEffects = Array.isArray(trig.choiceEffects) ? trig.choiceEffects : [];
              while (trig.choiceEffects.length < val.length) {
                trig.choiceEffects.push({ type: "none", target: "player", stat: "ATTACK", stages: 1, percent: 25, status: "" });
              }
            } else if (fld === "choiceResponses") {
              val = String(t.value || "").split(/\r?\n/).map(s => s.trim());
            }
            b.dialogues.triggers[idx][fld] = val;
            if (fld === "textboxType") {
              b.dialogues.triggers[idx].style = val;
            }
            this.syncDialogueTriggers(b);
            this.touch();
            if (fld === "target" || fld === "speaker") this.refreshInspector();
          }
        }
        return;
      }
      if (t.dataset.midbattleField != null) {
        const b = this.battle();
        if (b && b.boss && Array.isArray(b.boss.midbattleTriggers)) {
          const idx = N(t.dataset.midbattleIdx, -1);
          const fld = S(t.dataset.midbattleField);
          if (idx >= 0 && b.boss.midbattleTriggers[idx]) {
            b.boss.midbattleTriggers[idx][fld] = t.value;
            this.touch();
          }
        }
        return;
      }
    }
    return _inputMidbattle.call(this, e);
  };
})();
