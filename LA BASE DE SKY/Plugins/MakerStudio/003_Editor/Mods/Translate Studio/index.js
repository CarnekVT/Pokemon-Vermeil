import { CSS } from './styles.js';
import { parseMapInfos, parseMapEventTexts, parseCommonEventTexts } from './rxdata_reader.js';

const VERSION='1.4.0';
const PANEL_ID='translate-studio.main';
const DATA_PATH='Data/TranslateStudio/translations.json';
const CONFIG_PATH='Data/TranslateStudio/config.json';
const DISCOVERY_PATH='Data/TranslateStudio/catalog.json';
const CHANGEDEX_PATH='Data/ChangeDex/pokemon_changes.json';
const RUNTIME_DIR='Plugins/[CARNKEVT] Translate Studio';
const MOD_RUNTIME='runtime/001_TranslateStudio.rb';
const MOD_META='runtime/meta.txt';
const MOD_CANON_EN='runtime/canon_localization_en.json';
const MOD_CANON_ITEMS='runtime/canon_items_localization.json';
const MOD_SEED='runtime/translations.seed.json';
const MOD_CONTEXT_SEED='runtime/context_catalog.seed.json';
const MOD_LANG_CODE='runtime/language_menu_custom.example.rb';
const MOD_PLUGIN_EN_REF='runtime/plugin_english_reference.json';
const MOD_BASE_EN_REF='runtime/base_english_reference.json';
const MOD_STRICT_CONTEXT_EN='runtime/strict_context_english.json';
const MOD_LANG_UI={
  'runtime/ui/language_bg.png.b64':'Graphics/UI/TranslateStudio/language_bg.png',
  'runtime/ui/language_header.png.b64':'Graphics/UI/TranslateStudio/language_header.png',
  'runtime/ui/language_footer.png.b64':'Graphics/UI/TranslateStudio/language_footer.png',
  'runtime/ui/language_es.png.b64':'Graphics/UI/TranslateStudio/language_es.png',
  'runtime/ui/language_en.png.b64':'Graphics/UI/TranslateStudio/language_en.png',
  'runtime/ui/language_cursor.png.b64':'Graphics/UI/TranslateStudio/language_cursor.png'
};
const PROJECT_CANON_EN='Data/TranslateStudio/canon_localization_en.json';
const PROJECT_CANON_ITEMS='Data/TranslateStudio/canon_items_localization.json';
const PROJECT_CONTEXT_SEED='Data/TranslateStudio/context_catalog.seed.json';
const PROJECT_PLUGIN_EN_REF='Data/TranslateStudio/plugin_english_reference.json';
const PROJECT_BASE_EN_REF='Data/TranslateStudio/base_english_reference.json';
const PROJECT_STRICT_CONTEXT_EN='Data/TranslateStudio/strict_context_english.json';

const ICON=`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M4 5h8M4 9h6M4 13h5"/><path d="M14 6h6M17 3v6"/><path d="M13 13c1.7 4.7 4.2 7 7 8"/><path d="M20 13c-1.2 3.7-3.6 6.2-7 8"/></svg>`;

const DATA_BUCKETS=[
  ['species','Pokémon / Formas'],['moves','Movimientos'],['abilities','Habilidades'],['items','Objetos'],['types','Tipos']
];
const TEXT_BUCKETS=[
  ['general','Textos generales'],['events','Eventos'],['scripts','Scripts base'],['plugins','Plugins']
];
const INTEGRATION_BUCKETS=[['bss','BSS'],['sds','SDS']];
const ALL_TEXT_BUCKETS=[...TEXT_BUCKETS,...INTEGRATION_BUCKETS];
const ALL_DOC_BUCKETS=[...DATA_BUCKETS,...ALL_TEXT_BUCKETS].map(x=>x[0]);
// Hidden storage bucket: full ZBox PBS reference, scoped by MessageTypes.
// It is intentionally not another navigation page, but must survive load/save/seed merge.
const HIDDEN_DOC_BUCKETS=['pbs'];
const ALL_STORAGE_BUCKETS=[...ALL_DOC_BUCKETS,...HIDDEN_DOC_BUCKETS];
const FIELDS={
  species:['Name','FormName','Category','Pokedex'],
  moves:['Name','Description','BeforeText','AfterText','Notes'],
  abilities:['Name','Description','BeforeText','AfterText','Notes'],
  items:['Name','NamePlural','Description'],
  types:['Name'],
  general:['Text'],events:['Text'],scripts:['Text'],plugins:['Text'],bss:['Text'],sds:['Text']
};
const FILE_PATTERNS={
  species:/^pokemon(?!_(metrics|regional_dexes)).*\.txt$/i,
  moves:/^moves.*\.txt$/i,
  abilities:/^abilities.*\.txt$/i,
  items:/^items.*\.txt$/i,
  types:/^types.*\.txt$/i
};
const TEXT_KIND_LABEL={general:'General',events:'Evento',scripts:'Script',plugins:'Plugin',bss:'BSS',sds:'SDS'};
const LOCALIZED_SUFFIX_RE=/(?:_(ESP|ES|SPANISH|ENG|EN|ENGLISH|USA))$/i;
const IMAGE_EXT_RE=/\.(png|jpg|jpeg|bmp|webp)$/i;
const SOURCE_SCAN_CACHE={projectKey:null,textCatalog:null,graphics:null,events:null};

function el(tag,props={},children=[]){
  const n=document.createElement(tag);
  for(const[k,v]of Object.entries(props)){
    if(k==='class')n.className=v;
    else if(k==='text')n.textContent=String(v??'');
    else if(k==='html')n.innerHTML=String(v??'');
    else if(k==='style'&&v&&typeof v==='object')Object.assign(n.style,v);
    else if(k.startsWith('on')&&typeof v==='function')n.addEventListener(k.slice(2).toLowerCase(),v);
    else if(v!==undefined&&v!==null&&v!==false)n.setAttribute(k,v===true?'':String(v));
  }
  for(const c of(Array.isArray(children)?children:[children]))if(c!==null&&c!==undefined)n.append(c?.nodeType?c:document.createTextNode(String(c)));
  return n;
}
const up=v=>String(v??'').trim().toUpperCase();
const low=v=>String(v??'').toLowerCase();
const norm=v=>low(v).normalize('NFD').replace(/[\u0300-\u036f]/g,'');
const isTextBucket=b=>ALL_TEXT_BUCKETS.some(x=>x[0]===b);
const truncate=(s,n=120)=>{s=String(s??'');return s.length>n?s.slice(0,n-1)+'…':s;};
function namesFromList(ls){return(ls||[]).map(e=>typeof e==='string'?e:(e?.name||e?.path||'')).map(x=>String(x||'').split(/[\\/]/).pop()).filter(Boolean);}
function parseSections(text){
  const out=[];let row=null;
  for(const raw of String(text||'').replace(/^\uFEFF/,'').split(/\r?\n/)){
    const line=raw.trim();if(!line||line.startsWith('#'))continue;
    const h=line.match(/^\[([^\]]+)\]$/);if(h){if(row)out.push(row);row={id:h[1].trim(),fields:{}};continue;}
    if(!row)continue;const eq=raw.indexOf('=');if(eq<0)continue;
    row.fields[raw.slice(0,eq).trim()]=raw.slice(eq+1).trim();
  }
  if(row)out.push(row);return out;
}
function emptyLanguage(){return{species:{},moves:{},abilities:{},items:{},types:{},general:{},events:{},scripts:{},plugins:{},bss:{},sds:{},pbs:{}};}
function defaultDoc(){return{schema:6,version:VERSION,generatedBy:`Translate Studio v${VERSION}`,languages:{es:emptyLanguage(),en:emptyLanguage()}};}
function defaultConfig(){return{
  schema:6,activeLanguage:'auto',baseLanguage:'es',applyToGame:true,
  showFirstBootLanguageMenu:true,showLanguageOption:true,showDebugTools:true,
  readDirectTextPacks:false,preferLocalizedGraphics:true,graphicRules:{},
  autoDiscoverDevelopmentTexts:true,discoveryOnlyInDebug:true,
  languageMenuMode:'graphics',
  languageMenuBackground:'Graphics/UI/TranslateStudio/language_bg.png',
  languageMenuHeader:'Graphics/UI/TranslateStudio/language_header.png',
  languageMenuFooter:'Graphics/UI/TranslateStudio/language_footer.png',
  languageMenuCardES:'Graphics/UI/TranslateStudio/language_es.png',
  languageMenuCardEN:'Graphics/UI/TranslateStudio/language_en.png',
  languageMenuCursor:'Graphics/UI/TranslateStudio/language_cursor.png',
  languageMenuCustomCode:'Data/TranslateStudio/language_menu_custom.rb'
};}
function normalizeRow(v){return typeof v==='string'?{Text:v}:(v&&typeof v==='object'?v:{});}
function fixKnownEnglishTypos(doc){
  let fixed=0;const lang=doc?.languages?.en;if(!lang)return 0;
  for(const bucket of ALL_DOC_BUCKETS)for(const row of Object.values(lang[bucket]||{}))if(row&&typeof row==='object')for(const field of Object.keys(row)){
    if(typeof row[field]!=='string')continue;const old=row[field],next=old.replace(/\bAtacks\b/g,'Attacks').replace(/\batacks\b/g,'attacks').replace(/\bAtack\b/g,'Attack').replace(/\batack\b/g,'attack');
    if(next!==old){row[field]=next;fixed++;}
  }
  const force=(bucket,source,target,oldValues=[])=>{const row=lang?.[bucket]?.[source];if(!row||typeof row!=='object')return;const old=String(row.Text??'');if(old===target)return;if(old===source||oldValues.includes(old)){row.Text=target;row.Reference='v1.2 English completion';fixed++;}};
  force('general','{1} Nv.{2} {3}','{1} Lv.{2} {3}',['{1}  Nv.{2}  {3}']);
  for(const bucket of ['scripts','plugins']){
    force(bucket,'en el {1}recuerda movimientos{2}','at the {1}Move Relearner{2}');
    force(bucket,'Método Ultraexplosión\n','Ultra Burst Method\n');
    force(bucket,'¡{1} aprendió {2}!','{1} learned {2}!',['¡{1} learned {2}!']);
  }
  force('scripts','¡{1} sacó a {2}!','{1} sent out {2}!',['¡{1} sent out {2}!']);
  force('scripts','¿Te gustaría ponerle un mote a {1}?','Would you like to give {1} a nickname?');
  const verifiedEnglish={
    scripts:{
      '¡{2} de {1} ha disminuido su {3}!':"{1}'s {2} lowered its {3}!",
      '¡{2} de {1} ha disminuido mucho su {3}!':"{1}'s {2} harshly lowered its {3}!",
      '¡{2} de {1} ha disminuido muchísimo su {3}!':"{1}'s {2} severely lowered its {3}!",
      'Los PS de {1} han sido restaurados':"{1}'s HP was restored.",
      '¡La {1} usada por {2} brilló fuertemente!':'The {1} worn by {2} shone brilliantly!',
      '¡El Entrenador bloqueó tu {1}! ¡Robar está mal!':"The Trainer blocked your {1}! Don't be a thief!",
      '¡La tormenta de arena zarandea a {1}!':'{1} is buffeted by the sandstorm!',
      '¡El granizo golpea a {1}!':'{1} is buffeted by the hail!',
      '¿Quieres cambiar la Habilidad de {1}? Su nueva habilidad será {2}.':"Do you want to change {1}'s Ability? Its new Ability will be {2}.",
      '¡Se han esparcido púas alrededor de los pies de {1}!':"Spikes were scattered all around {1}'s feet!",
      '¡Se han esparcido púas tóxicas alrededor de los pies de {1}!':"Poison spikes were scattered all around {1}'s feet!",
      '¡No se puede revivir un huevo!':"An Egg can't be revived!",
      '¡Este Pokémon no puede ser revivido!':"This Pokémon can't be revived!",
      '{1} quiere {2} {3}, pero ya conoce {4} movimientos.':'{1} wants to {2} {3}, but it already knows {4} moves.',
      '{1} <c3={2}>asestó un golpe crítico</c3> a {3} para impresionarte!':'{1} landed a <c3={2}>critical hit</c3> on {3}, wishing to be praised!',
      '¡<c3={1}>{2} recibió un golpe crítico!</c3>':'A <c3={1}>critical hit</c3> on {2}!',
      '{1}Obtenible cuando {2}{3}{4} activa la Teracristalización.':'{1}Available when {2}{3}{4} triggers Terastallization.'
    },
    plugins:{
      'Hab.':'Abil.','El Pokémon recupera unos PS al final de cada turno.':'The Pokémon restores some HP at the end of each turn.',
      'El Pokémon recupera unos PS cada turno, pero no puede ser cambiado.':'The Pokémon restores some HP every turn, but cannot be switched out.',
      'Los PS del oponente son absorbidos cada turno para curarse.':"The opponent's HP is drained each turn to heal the Pokémon.",
      'El Pokémon recibe daño al final de cada turno.':'The Pokémon takes damage at the end of each turn.',
      'El Pokémon recibe daño cada turno que esté dormido.':'The Pokémon takes damage each turn while asleep.',
      'El Pokémon en esta posición recuperará PS en el siguiente turno.':'The Pokémon in this position will recover HP next turn.',
      'El sustituto del Pokémon recibe cualquier daño al Pokémon.':"The Pokémon's substitute takes damage in its place.",
      'Cualquier movimiento contra un objetivo fijado es seguro de acertar.':'Any move against the locked-on target is guaranteed to hit.',
      'Debido a{1}, el Pokémon solo puede usar {2}.':'Because of {1}, the Pokémon can only use {2}.',
      'El Pokémon está atrapado y recibe daño cada turno.':'The Pokémon is trapped and takes damage each turn.',
      'El Pokémon no puede ser alcanzado por la mayoría de ataques.':'The Pokémon cannot be hit by most attacks.',
      'Los Pokémon no pueden dormirse durante un alboroto.':"Pokémon can't fall asleep during an uproar."
    }
  };
  for(const[bucket,rows]of Object.entries(verifiedEnglish))for(const[source,target]of Object.entries(rows)){
    const row=lang?.[bucket]?.[source];if(row&&typeof row==='object'&&String(row.Text??'')!==target){row.Text=target;row.Reference='v1.2 semantic audit';fixed++;}
  }
  const reversed=['Effort values for each of the Pokémon\'s stats.','Gender','Gender of the Pokémon.','Happiness','Happiness of the Pokémon (0-255).','If set to true, the Pokémon is a different-colored Pokémon.','If set to true, the Pokémon is a Shadow Pokémon.','Individual values for each of the Pokémon\'s stats.','Name','Nature','Nature of the Pokémon.','Nickname of the Pokémon.','Shadow','Shiny','SuperShiny','The kind of Poké Ball the Pokémon is kept in.','Species','Species of the Pokémon.','Level','Level of the Pokémon (1-{1}).','Form','Form of the Pokémon.','Whether the Pokémon is super shiny (shiny with a special shininess animation).','Move {1}','A move known by the Pokémon. Leave all moves blank (use Z key to delete) for a wild moveset.','Ability','Ability of the Pokémon. Overrides the ability index.','Ability index','Ability index. 0=first ability, 1=second ability, 2+=hidden ability.','Held item','Item held by the Pokémon.'];
  for(const source of reversed){const row=lang?.plugins?.[source];if(row&&typeof row==='object'&&String(row.Text??'')!==source){row.Text=source;row.Reference='Restored from English plugin source';fixed++;}}
  return fixed;
}
function sourceBucketsFromContextSeed(seed,source){
  const out=[];for(const b of ['events','scripts','plugins','bss','sds'])if(seed?.[b]?.[source])out.push(b);return out;
}
function normalizeDoc(doc,contextSeed={}){
  const raw=(doc&&typeof doc==='object')?doc:{};
  const d={schema:6,version:String(raw.version||VERSION),generatedBy:`Translate Studio v${VERSION}`,languages:{es:emptyLanguage(),en:emptyLanguage()}};
  if(raw.referenceImport&&typeof raw.referenceImport==='object')d.referenceImport=JSON.parse(JSON.stringify(raw.referenceImport));
  for(const lang of ['es','en']){
    const src=raw.languages?.[lang]||{};
    for(const b of ALL_DOC_BUCKETS){
      if(src[b]&&typeof src[b]==='object')for(const[id,v]of Object.entries(src[b]))d.languages[lang][b][isTextBucket(b)?String(id):up(id)]=normalizeRow(v);
    }
    // pbs is nested category -> original -> {Text}; copy it losslessly.
    if(src.pbs&&typeof src.pbs==='object')d.languages[lang].pbs=JSON.parse(JSON.stringify(src.pbs));

  }
  return d;
}
function mergeSeed(dst,seed){
  let copied=0;
  for(const lang of ['es','en'])for(const bucket of ALL_DOC_BUCKETS)for(const[id,rowRaw]of Object.entries(seed.languages?.[lang]?.[bucket]||{})){
    const key=isTextBucket(bucket)?String(id):up(id),row=normalizeRow(rowRaw),target=(dst.languages[lang][bucket][key]||={});
    for(const[field,value]of Object.entries(row)){
      const v=String(value??''),cur=String(target[field]??'');
      const staleEnglishIdentity=(lang==='en'&&isTextBucket(bucket)&&field==='Text'&&cur===String(id)&&v!==String(id));
      if(v.trim()!==''&&(cur.trim()===''||staleEnglishIdentity)){target[field]=value;copied++;}
    }
  }
  // Deep-merge hidden PBS reference without overwriting user edits.
  for(const lang of ['es','en']){
    const src=seed.languages?.[lang]?.pbs||{},dstPbs=(dst.languages[lang].pbs||={});
    for(const[category,rows]of Object.entries(src)){
      const targetCat=(dstPbs[category]||={});
      for(const[source,rowRaw]of Object.entries(rows||{})){
        const row=normalizeRow(rowRaw),target=(targetCat[source]||={});
        for(const[field,value]of Object.entries(row)){
          const v=String(value??'');if(v.trim()!==''&&String(target[field]??'').trim()===''){target[field]=value;copied++;}
        }
      }
    }
  }
  return copied;
}
function versionParts(v){return String(v||'0').split(/[^0-9]+/).filter(Boolean).slice(0,4).map(Number);}
function versionLt(a,b){const A=versionParts(a),B=versionParts(b);for(let i=0;i<Math.max(A.length,B.length);i++){const x=A[i]||0,y=B[i]||0;if(x!==y)return x<y;}return false;}
function manualEnglishRow(row){if(!row||typeof row!=='object')return false;return row.Manual===true||/manual/i.test(String(row.SourcePack||''))||/manual/i.test(String(row.Reference||''));}
function applyV13QualityMigration(dst,seed,canonEn,canonItems,rawVersion){
  if(!versionLt(rawVersion,'1.3.0')){dst.version=VERSION;return 0;}
  let changed=0,en=(dst.languages.en||={});
  if(en.plugins?.['¡{2} de {2} irradia energía!']){delete en.plugins['¡{2} de {2} irradia energía!'];changed++;}
  const repairStructured=(bucket,canon)=>{for(const[id,row]of Object.entries(en[bucket]||{})){const c=canon?.[id];if(!c||!row||typeof row!=='object')continue;for(const field of(FIELDS[bucket]||[])){if(c[field]===undefined||String(c[field]??'').trim()==='')continue;if(String(row[field]??'')!==String(c[field])){row[field]=c[field];changed++;}}if(changed)row._QualitySource='Supplied canonical English localization';}};
  repairStructured('species',canonEn?.species||{});repairStructured('moves',canonEn?.moves||{});repairStructured('abilities',canonEn?.abilities||{});repairStructured('items',canonItems?.en||{});
  for(const bucket of ['scripts','plugins','bss','sds'])for(const[source,seedRowRaw]of Object.entries(seed.languages?.en?.[bucket]||{})){
    const seedRow=normalizeRow(seedRowRaw);if(!/Curated/i.test(String(seedRow.SourcePack||''))&&!/v1\.3/i.test(String(seedRow.Reference||'')))continue;
    const target=(en[bucket][source]||={});if(manualEnglishRow(target))continue;
    for(const[field,value]of Object.entries(seedRow)){if(String(target[field]??'')!==String(value??'')){target[field]=value;changed++;}}
  }
  // v1.3 also repairs hidden PBS rows that older ZBox imports merged across unrelated
  // context categories (e.g. Move Name "Malicioso" accidentally inheriting the
  // species category "Devious").  Only ID-resolved v1.3 seed rows overwrite stale
  // imported rows; explicit manual rows remain untouched.
  const seedPbs=seed.languages?.en?.pbs||{},dstPbs=(en.pbs||={});
  for(const[category,rows]of Object.entries(seedPbs)){
    const targetCat=(dstPbs[category]||={});
    for(const[source,seedRowRaw]of Object.entries(rows||{})){
      const seedRow=normalizeRow(seedRowRaw);
      if(!/v1\.3\.0 PBS disambiguation/i.test(String(seedRow.SourcePack||'')))continue;
      const target=(targetCat[source]||={});if(manualEnglishRow(target))continue;
      for(const[field,value]of Object.entries(seedRow)){if(JSON.stringify(target[field])!==JSON.stringify(value)){target[field]=value;changed++;}}
    }
  }
  dst.version=VERSION;dst.generatedBy=`Translate Studio v${VERSION} · migrated quality sources`;
  return changed;
}
function applyV14ContextMigration(dst,rawVersion){
  if(!versionLt(rawVersion,'1.4.0'))return 0;
  let changed=0;const row=dst?.languages?.en?.scripts?.['Guardar'];
  if(row&&typeof row==='object'&&!manualEnglishRow(row)&&String(row.Text??'')!=='Save'){
    row.Text='Save';row.Reference='Clean English base + contextual call-site v1.4.0';row.SourcePack='Data(20260906-012634).zip · contextual base reference';row.VerifiedAutoRepair=true;changed++;
  }
  return changed;
}
function referenceCanonicalPath(path){let clean=String(path||'').replace(/\\/g,'/').replace(/^\.\//,'').replace(/^plugins\//i,'');const parts=clean.split('/').filter(Boolean).map(part=>String(part).replace(/^(?:\[[^\]]+\]\s*)+/,'').replace(/^\[?\d{3}\]?[_ -]*/,'').trim());return parts.join('/').toLowerCase();}
function referenceBasename(path){const base=String(path||'').replace(/\\/g,'/').split('/').pop()||'';return base.replace(/^\[?\d{3}\]?[_ -]*/,'').trim().toLowerCase();}
function buildReferenceIndex(doc){const exact=new Map(),canonical=new Map(),basename=new Map(),canonCollisions=new Set(),baseCollisions=new Set();for(const[key,row]of Object.entries(doc?.files||{})){if(!row||typeof row!=='object')continue;const path=String(row.path||key),norm=path.replace(/\\/g,'/').replace(/^\.\//,'').toLowerCase(),can=referenceCanonicalPath(path),base=String(row.basenameKey||referenceBasename(path)).toLowerCase();exact.set(norm,row);if(canonical.has(can)&&canonical.get(can)!==row)canonCollisions.add(can);else canonical.set(can,row);if(base){if(basename.has(base)&&basename.get(base)!==row)baseCollisions.add(base);else basename.set(base,row);}}for(const c of canonCollisions)canonical.delete(c);for(const c of baseCollisions)basename.delete(c);return{exact,canonical,basename};}
function referenceForPath(index,path){if(!index)return null;const norm=String(path||'').replace(/\\/g,'/').replace(/^\.\//,'').toLowerCase();return index.exact.get(norm)||index.canonical.get(referenceCanonicalPath(path))||index.basename?.get(referenceBasename(path))||null;}
function decodeCodeLiteral(text,quote){let s=String(text||'');if(quote==='"')return s.replace(/\\n/g,'\n').replace(/\\r/g,'\r').replace(/\\t/g,'\t').replace(/\\"/g,'"').replace(/\\\\/g,'\\');return s.replace(/\\'/g,"'").replace(/\\\\/g,'\\');}
function extractCodeEntries(code){const text=String(code||''),rows=[];const patterns=[['intl',/(?:_INTL|_ISPRINTF|pbEnter(?:Text|PlayerName|PokemonName|NPCName|BoxName))\s*\(\s*(["'])((?:\\.|(?!\1)[\s\S])*?)\1/g],['sds_text',/(?:text_inline|show_centered_text)\s*(?:\(\s*)?(["'])((?:\\.|(?!\1)[\s\S])*?)\1/g],['speaker',/speaker\s*:\s*(["'])((?:\\.|(?!\1)[\s\S])*?)\1/g]];for(const[kind,re]of patterns){let m;while((m=re.exec(text)))rows.push({index:m.index,kind,text:decodeCodeLiteral(m[2],m[1])});}rows.sort((a,b)=>a.index-b.index);return rows.map(({kind,text})=>({kind,text}));}
function mergeContexts(target,bucket,source,contexts=[],origin='Detectado'){
  if(!target[bucket])target[bucket]={};
  const row=(target[bucket][source]||={Contexts:[],Origins:[]});
  row.Contexts=Array.from(new Set([...(row.Contexts||[]),...contexts.filter(Boolean)]));
  row.Origins=Array.from(new Set([...(row.Origins||[]),origin].filter(Boolean)));
}
function normalizedContextCatalog(raw={}){
  const out={general:{},events:{},scripts:{},plugins:{},bss:{},sds:{}};
  for(const b of Object.keys(out))for(const[source,row]of Object.entries(raw?.[b]||{}))mergeContexts(out,b,source,Array.isArray(row?.Contexts)?row.Contexts:[],row?.Origin||raw?.generatedBy||'Catálogo');
  return out;
}

export function activate(ctx){
  ctx.log.info(`Translate Studio v${VERSION} activated`);
  ctx.ui.registerPanel({id:PANEL_ID,title:'Translate Studio',icon:ICON,defaultPosition:'right',defaultSize:{width:1500,height:960},showInMenu:false,render:host=>render(ctx,host)});
  ctx.menu.registerMenuItem({menu:'Mods',label:'Translate Studio',icon:ICON,shortcut:'Ctrl+Shift+T',handler:()=>ctx.ui.openPanel(PANEL_ID)});
  ctx.commands.register('translate-studio.open',()=>ctx.ui.openPanel(PANEL_ID));
}

function render(ctx,host){
  const state={
    doc:defaultDoc(),config:defaultConfig(),lang:'es',bucket:'species',
    catalogs:{species:[],moves:[],abilities:[],items:[],types:[],general:[],events:[],scripts:[],plugins:[],bss:[],sds:[],graphics:[]},
    contextCatalog:{general:{},events:{},scripts:{},plugins:{},bss:{},sds:{}},canonEn:{species:{},moves:{},abilities:{}},canonItems:{es:{},en:{}},
    selected:null,search:'',filter:'all',dirty:false,legacyCount:0,loading:true,seedCopied:0,autoInstalled:false,listLimit:450,
    graphicsLoaded:false,graphicsLoading:false,
    gameRoot:'',assetUrls:new Map(),assetFailures:new Set(),graphicsMode:'pairs',eventMap:'all',integrationMode:'all',integrationGroup:'all',sourceGroup:'all',typoFixes:0,
    pbsNames:[],dataLoaded:{species:false,moves:false,abilities:false,items:false,types:false},dataLoading:{},textLoaded:{general:true,events:false,scripts:false,plugins:false,bss:false,sds:false},textLoading:{},scanMessage:'',fullscreen:false,
    seedDoc:defaultDoc(),baseEnglishRef:null,pluginEnglishRef:null,baseReferenceIndex:null,pluginReferenceIndex:null,autoMemory:{scripts:{},plugins:{},bss:{},sds:{}},autoCollisions:{scripts:new Set(),plugins:new Set(),bss:new Set(),sds:new Set()},selectedRows:new Set(),autoRunning:false,qualityMigrations:0,machineCache:new Map(),machineProvider:'auto'
  };
  try{state.gameRoot=String(ctx.editor?.gameRoot?.()||'');}catch{}
  host.innerHTML='';host.append(el('style',{text:CSS}));
  const root=el('div',{class:'trs-root',tabindex:'0'});host.append(root);
  let fullscreenActive=false,fullscreenPlaceholder=null,fullscreenPreviousScroll={x:0,y:0};
  const toolbar=el('div',{class:'trs-toolbar'});
  const brand=el('div',{class:'trs-brand'},[el('div',{class:'trs-brand-icon',html:ICON}),el('div',{},[el('div',{class:'trs-title',text:'Translate Studio'}),el('div',{class:'trs-sub',text:'Localización contextual · runtime directo · sin compilar'})])]);
  const actions=el('div',{class:'trs-actions'});
  const langSel=el('select',{class:'trs-select trs-lang'});[['es','ESP · Editar Español'],['en','ENG · Edit English']].forEach(([v,l])=>langSel.append(el('option',{value:v,text:l})));
  const activeSel=el('select',{class:'trs-select'});[['auto','Jugador elige idioma'],['es','Forzar Español'],['en','Force English']].forEach(([v,l])=>activeSel.append(el('option',{value:v,text:l})));
  const scanBtn=el('button',{class:'trs-btn',text:'Detectar cambios'}),autoAllBtn=el('button',{class:'trs-btn trs-auto-main',text:'⚡ Auto todo ENG',title:'Completar/reparar English: primero usa fuentes verificadas y, si no existen, traducción automática es→en'}),langUiBtn=el('button',{class:'trs-btn',text:'UI de idioma'}),installBtn=el('button',{class:'trs-btn',text:'Reinstalar runtime'}),fullscreenBtn=el('button',{class:'trs-btn trs-fullscreen-btn',text:'⛶ Pantalla completa',title:'Pantalla completa · F11'}),saveBtn=el('button',{class:'trs-btn primary',text:'Guardar'});
  actions.append(langSel,activeSel,langUiBtn,autoAllBtn,scanBtn,installBtn,fullscreenBtn,saveBtn);toolbar.append(brand,actions);root.append(toolbar);
  const fullscreenControls=el('div',{class:'trs-fullscreen-session-controls'},[el('button',{class:'trs-btn',text:'↙ Salir',onClick:()=>exitFullscreenMode()}),el('button',{class:'trs-btn danger',text:'✕ Cerrar editor',onClick:()=>closeEditorFromFullscreen()})]);root.append(fullscreenControls);

  const main=el('div',{class:'trs-main'}),nav=el('div',{class:'trs-nav'}),listPane=el('div',{class:'trs-list'}),editor=el('div',{class:'trs-editor'});main.append(nav,listPane,editor);root.append(main);
  const status=el('div',{class:'trs-status',text:'Preparando Translate Studio…'});root.append(status);
  const navContent=el('div',{class:'trs-nav-content'});nav.append(navContent);

  const listHead=el('div',{class:'trs-list-head'}),search=el('input',{class:'trs-search',placeholder:'Buscar texto, contexto, archivo o ID…'}),libraryGroups=el('div',{class:'trs-library-groups'}),autoTools=el('div',{class:'trs-auto-tools'}),eventMapSel=el('select',{class:'trs-select trs-map-select',title:'Filtrar eventos por mapa'}),integrationModeSel=el('select',{class:'trs-select trs-map-select',title:'Sección de integración'}),integrationGroupSel=el('select',{class:'trs-select trs-map-select',title:'Combate o escena'});listHead.append(search,libraryGroups,autoTools);
  const filters=el('div',{class:'trs-filters'}),items=el('div',{class:'trs-items'}),foot=el('div',{class:'trs-list-foot',text:'0 entradas'});listPane.append(listHead,filters,items,foot);

  const toast=(m,level='info')=>{try{ctx.ui.showToast({message:String(m),level});}catch{}};
  const read=async p=>ctx.fs.readProjectFile(p);
  const exists=async p=>{try{return!!(await ctx.fs.projectExists?.(p));}catch{return false;}};
  const listDir=async p=>{try{return await ctx.fs.listProjectDir(p);}catch{return[];}};
  const setDirty=v=>{state.dirty=!!v;saveBtn.textContent=state.dirty?'Guardar •':'Guardar';updateStatus();};
  const projectKey=()=>String(state.gameRoot||ctx.editor?.gameRoot?.()||'project');

  function updateStatus(){
    const total=Object.values(state.doc.languages||{}).reduce((n,lang)=>n+ALL_DOC_BUCKETS.reduce((z,b)=>z+Object.keys(lang?.[b]||{}).length,0),0);
    const bits=[];if(state.loading)bits.push(state.scanMessage||'Cargando…');if(state.autoInstalled)bits.push('runtime listo');if(state.seedCopied)bits.push(`${state.seedCopied} campos recuperados`);
    bits.push(`${state.catalogs.events.length} textos de eventos reales`,`${state.catalogs.scripts.length} scripts`,`${state.catalogs.plugins.length} plugins`,`${state.catalogs.bss.length} BSS`,`${state.catalogs.sds.length} SDS`,`${state.catalogs.graphics.length} UI`,`${total} entradas`);if(state.typoFixes)bits.push(`${state.typoFixes} typo ENG corregido${state.typoFixes===1?'':'s'}`);if(state.qualityMigrations)bits.push(`${state.qualityMigrations} campos ENG reparados con fuente verificada`);
    if(state.dirty)bits.push('sin guardar');status.textContent=bits.join(' · ');
  }
  function rowKey(bucket,id){return isTextBucket(bucket)?String(id??''):up(id);}
  function baseline(bucket,id,lang=state.lang){
    const key=rowKey(bucket,id),entry=(state.catalogs[bucket]||[]).find(x=>x.id===key);
    if(isTextBucket(bucket))return{Text:key};
    if(bucket==='items'){const c=state.canonItems?.[lang]?.[key]||{};return{...(entry?.fields||{}),...c};}
    if(lang==='en'&&['species','moves','abilities'].includes(bucket)){const c=state.canonEn?.[bucket]?.[key]||{};return{...(entry?.fields||{}),...c};}
    return entry?.fields||{};
  }
  function currentRow(bucket,id){return state.doc.languages[state.lang]?.[bucket]?.[rowKey(bucket,id)]||{};}
  function hasTranslation(entry){
    if(!entry||state.bucket==='graphics')return false;
    const row=currentRow(state.bucket,entry.id);
    if(isTextBucket(state.bucket))return String(row.Text??'').trim()!=='';
    return (FIELDS[state.bucket]||[]).some(f=>String(row[f]??'').trim()!=='');
  }
  function isCustom(entry){
    if(!entry)return false;
    if(isTextBucket(state.bucket))return (entry.origins||[]).some(x=>/studio|manual/i.test(x));
    return String(entry.source||'').toLowerCase().includes('changedex');
  }
  function searchable(entry){return norm([entry.id,entry.name,entry.file,entry.source,...(entry.contexts||[])].filter(Boolean).join(' '));}

  function filterOptions(){
    if(state.bucket==='graphics')return[['all','Todas'],['pairs','Completas'],['es','ESP'],['en','ENG'],['missing','Falta par'],['disabled','Fuera de traducción']];
    return[['all','Todos'],['missing','Sin traducir'],['translated','Traducidos'],['custom','Custom / nuevos']];
  }
  function renderFilters(){
    filters.innerHTML='';const opts=filterOptions();
    if(!opts.some(x=>x[0]===state.filter))state.filter=opts[0][0];
    for(const[v,l]of opts)filters.append(el('button',{class:'trs-chip'+(state.filter===v?' active':''),text:l,'data-filter':v}));
  }
  function renderCats(){
    navContent.innerHTML='';
    const icons={species:'◉',moves:'✦',abilities:'◆',items:'▣',types:'⬢',general:'TXT',events:'EV',scripts:'RB',plugins:'PL',bss:'BS',sds:'SD',graphics:'UI'};
    const group=(title,rows)=>{
      const wrap=el('section',{class:'trs-nav-group'});wrap.append(el('div',{class:'trs-section-label',text:title}));
      const tabs=el('div',{class:'trs-cat-group'});
      for(const[b,label]of rows){
        const dataBucket=DATA_BUCKETS.some(x=>x[0]===b),textBucket=['events','scripts','plugins','bss','sds'].includes(b);
        const waiting=(dataBucket&&!state.dataLoaded[b])||(textBucket&&!state.textLoaded[b])||(b==='graphics'&&!state.graphicsLoaded);
        const count=waiting?'…':(state.catalogs[b]||[]).length;
        tabs.append(el('button',{class:'trs-cat'+(state.bucket===b?' active':''),onClick:()=>selectBucket(b)},[
          el('span',{class:'trs-cat-icon',text:icons[b]||'•'}),el('span',{class:'trs-cat-copy'},[el('b',{text:label}),el('small',{text:count})])
        ]));
      }
      wrap.append(tabs);navContent.append(wrap);
    };
    group('Datos',DATA_BUCKETS);group('Textos',TEXT_BUCKETS);group('Integraciones',INTEGRATION_BUCKETS);group('Recursos',[['graphics','Imágenes / UI']]);
  }
  function selectBucket(b){
    state.bucket=b;state.selected=null;state.selectedRows.clear();state.search='';search.value='';state.eventMap='all';state.integrationMode=b==='bss'?'battles':(b==='sds'?'scenes':'all');state.integrationGroup='all';state.sourceGroup='all';state.filter='all';state.listLimit=450;renderAll();
    if(DATA_BUCKETS.some(x=>x[0]===b))ensureDataBucketLoaded(b,false);
    else if(['events','scripts','plugins','bss','sds'].includes(b))ensureTextBucketLoaded(b,false);
    else if(b==='graphics')ensureGraphicsLoaded(false);
  }
  function eventMapLabelFromContext(context){
    const c=String(context||'');
    let m=c.match(/^Map(\d{3})\s+·\s+([^·]+?)\s+·\s+(?:Event|Evento)/i);if(m)return`Mapa ${Number(m[1])} · ${m[2].trim()}`;
    m=c.match(/^Map(\d+):/i);if(m)return`Mapa ${Number(m[1])}`;
    if(/^CommonEvent:/i.test(c)||/^Evento común/i.test(c))return'Eventos comunes';
    return'Otros';
  }
  function eventMaps(){
    const set=new Set();for(const e of(state.catalogs.events||[]))for(const c of(e.contexts||[]))set.add(eventMapLabelFromContext(c));
    return[...set].sort((a,b)=>a.localeCompare(b,'es',{numeric:true,sensitivity:'base'}));
  }
  function refreshEventMapSelector(){
    eventMapSel.innerHTML='';eventMapSel.append(el('option',{value:'all',text:'Todos los mapas'}));
    for(const m of eventMaps())eventMapSel.append(el('option',{value:m,text:m}));
    if(![...eventMapSel.options].some(o=>o.value===state.eventMap))state.eventMap='all';eventMapSel.value=state.eventMap;
    eventMapSel.style.display=state.bucket==='events'?'':'none';
  }
  function integrationContextInfo(context,bucket=state.bucket){
    const c=String(context||'');
    if(bucket==='bss'){
      if(/^BSS\s*(?:General|:)/i.test(c))return{mode:'general',group:'Textos generales'};
      let m=c.match(/^BSS\s*·\s*([^·]+)/i);if(m)return{mode:'battles',group:m[1].trim()};
      return{mode:'general',group:'Textos generales'};
    }
    if(bucket==='sds'){
      let m=c.match(/^SDS\s*·\s*([^·]+)/i);if(m)return{mode:'scenes',group:m[1].trim()};
      if(/^SDS:/i.test(c)){const body=c.replace(/^SDS:\s*/i,'');const path=body.split(':L')[0].split(' · ')[0].trim();let file=path.split(/[\/]/).pop().replace(/\.rb$/i,'');file=file.replace(/^\d+[ _.-]*/,'').trim();return{mode:'scenes',group:file||'Escena'};}
      return{mode:'general',group:'Textos generales SDS'};
    }
    return{mode:'all',group:'all'};
  }
  function integrationGroups(bucket,mode){
    const set=new Set();for(const e of(state.catalogs[bucket]||[]))for(const c of(e.contexts||[])){const info=integrationContextInfo(c,bucket);if(info.mode===mode&&info.group)set.add(info.group);}
    return[...set].sort((a,b)=>a.localeCompare(b,'es',{numeric:true,sensitivity:'base'}));
  }
  function refreshIntegrationSelectors(){
    const isBSS=state.bucket==='bss',isSDS=state.bucket==='sds',active=isBSS||isSDS;
    integrationModeSel.style.display=active?'':'none';integrationGroupSel.style.display=active?'':'none';
    if(!active)return;
    integrationModeSel.innerHTML='';
    const modes=isBSS?[['all','Todo BSS'],['general','Textos generales'],['battles','Combates']]:[['all','Todo SDS'],['scenes','Librería de escenas'],['general','Textos generales']];
    for(const [v,l] of modes)integrationModeSel.append(el('option',{value:v,text:l}));
    if(!modes.some(x=>x[0]===state.integrationMode))state.integrationMode=isBSS?'battles':'scenes';
    integrationModeSel.value=state.integrationMode;
    integrationGroupSel.innerHTML='';integrationGroupSel.append(el('option',{value:'all',text:isBSS?'Todos los combates':'Todas las escenas'}));
    if(state.integrationMode!=='all'&&state.integrationMode!=='general')for(const g of integrationGroups(state.bucket,state.integrationMode))integrationGroupSel.append(el('option',{value:g,text:g}));
    if(![...integrationGroupSel.options].some(o=>o.value===state.integrationGroup))state.integrationGroup='all';integrationGroupSel.value=state.integrationGroup;
    integrationGroupSel.style.display=(state.integrationMode==='battles'||state.integrationMode==='scenes')?'':'none';
  }
  function sourceGroupInfo(entry,bucket=state.bucket){
    const contexts=entry?.contexts||[];
    if(bucket==='events')return contexts.map(eventMapLabelFromContext);
    if(bucket==='scripts')return contexts.map(c=>{const body=String(c).replace(/^Script:\s*/i,'').split(':L')[0].trim();const clean=body.replace(/\\/g,'/');const parts=clean.split('/').filter(Boolean);let name=(parts[0]||clean||'Script').replace(/\.rb$/i,'');if(parts.length===1)name=(parts[0]||'Script').replace(/^\d+[ _.-]*/,'').replace(/\.rb$/i,'');return name||'Script';});
    if(bucket==='plugins')return contexts.map(c=>{const body=String(c).replace(/^Plugin:\s*/i,'').split(':L')[0].trim();if(body.includes(' - '))return body.split(' - ')[0].trim();const clean=body.replace(/\\/g,'/');return(clean.split('/')[0]||'Plugin').trim();});
    if(bucket==='bss'||bucket==='sds')return contexts.map(c=>integrationContextInfo(c,bucket).group).filter(Boolean);
    if(bucket==='graphics'){const p=String(entry?.id||'').replace(/^Graphics\/UI\/?/i,'');const parts=p.split('/');return[parts.length>1?parts[0]:'UI general'];}
    return[];
  }
  function sourceGroups(){
    const map=new Map();
    for(const e of(state.catalogs[state.bucket]||[]))for(const g of new Set(sourceGroupInfo(e))){if(!g)continue;map.set(g,(map.get(g)||0)+1);}
    return[...map.entries()].sort((a,b)=>a[0].localeCompare(b[0],'es',{numeric:true,sensitivity:'base'}));
  }
  function renderLibraryGroups(){
    libraryGroups.innerHTML='';
    const visual=['events','scripts','plugins','bss','sds','graphics'].includes(state.bucket);
    libraryGroups.style.display=visual?'grid':'none';if(!visual)return;
    const groups=sourceGroups(),icons={events:'▦',scripts:'RB',plugins:'◆',bss:'BS',sds:'SD',graphics:'▣'};
    const add=(value,title,count,subtitle='')=>libraryGroups.append(el('button',{class:'trs-library-card'+(state.sourceGroup===value?' active':''),onClick:()=>{state.sourceGroup=value;state.selected=null;state.listLimit=450;renderList();renderEditor();}},[
      el('span',{class:'trs-library-icon',text:value==='all'?'◎':(icons[state.bucket]||'•')}),
      el('span',{class:'trs-library-copy'},[el('b',{text:title}),subtitle?el('small',{text:subtitle}):null]),
      el('span',{class:'trs-library-count',text:count})
    ]));
    add('all',state.bucket==='events'?'Todos los mapas':state.bucket==='scripts'?'Todos los scripts':state.bucket==='plugins'?'Todos los plugins':state.bucket==='bss'?'Todo BSS':state.bucket==='sds'?'Toda la librería SDS':'Toda la UI',(state.catalogs[state.bucket]||[]).length);
    for(const[g,count]of groups)add(g,g,count,state.bucket==='bss'?(g==='Textos generales'?'General':'Combate'):state.bucket==='sds'?'Escena':state.bucket==='events'?'Mapa / eventos':state.bucket==='scripts'?'Script base':state.bucket==='plugins'?'Plugin':'Carpeta UI');
  }
  function selectionKey(bucket,id){return `${bucket}\u0000${String(id??'')}`;}
  function selectedIdsForBucket(bucket=state.bucket){const out=[];for(const key of state.selectedRows){const i=key.indexOf('\u0000');if(i>0&&key.slice(0,i)===bucket)out.push(key.slice(i+1));}return out;}
  function contextOrderTuple(entry,bucket=state.bucket){let fileNo=999999,lineNo=999999,jsonNo=999999;for(const raw of(entry?.contexts||[])){const c=String(raw||'').replace(/\\/g,'/');let m=c.match(/(?:^|\/)(\d{1,4})[ _.-][^/:]+\.rb/i);if(m)fileNo=Math.min(fileNo,Number(m[1]));m=c.match(/:L(\d+)/i);if(m)lineNo=Math.min(lineNo,Number(m[1]));const nums=[...c.matchAll(/\[(\d+)\]/g)].map(x=>Number(x[1]));if(nums.length)jsonNo=Math.min(jsonNo,nums.reduce((a,n)=>a*10000+n,0));}return[fileNo,lineNo,jsonNo,String(entry?.id||'')];}
  function compareContextOrder(a,b,bucket=state.bucket){const A=contextOrderTuple(a,bucket),B=contextOrderTuple(b,bucket);for(let i=0;i<3;i++)if(A[i]!==B[i])return A[i]-B[i];return A[3].localeCompare(B[3],'es',{numeric:true,sensitivity:'base'});}
  function findSeedTextCandidate(bucket,source){const key=String(source??''),seed=state.seedDoc?.languages?.en||{};let row=seed?.[bucket]?.[key];if(row&&String(row.Text??'').trim())return{value:String(row.Text),Reference:String(row.Reference||`Translate Studio v${VERSION} curated memory`),SourcePack:String(row.SourcePack||'Bundled verified translation memory'),verified:true};for(const b of ['general','scripts','plugins','bss','sds']){row=seed?.[b]?.[key];if(row&&String(row.Text??'').trim())return{value:String(row.Text),Reference:String(row.Reference||`Translation memory · ${b}`),SourcePack:String(row.SourcePack||'Bundled translation memory'),verified:/Reference|Curated|English|official|canonical/i.test(String(row.SourcePack||row.Reference||''))};}for(const rows of Object.values(seed?.pbs||{})){const p=rows?.[key];if(p&&String(p.Text??'').trim())return{value:String(p.Text),Reference:'Bundled PBS English reference',SourcePack:'ZBox PBS reference · events excluded',verified:true};}return null;}
  function autoCandidate(bucket,id,field='Text'){
    if(state.lang!=='en')return null;const key=rowKey(bucket,id);
    if(isTextBucket(bucket)){const seeded=findSeedTextCandidate(bucket,key);if(seeded)return seeded;const direct=state.autoMemory?.[bucket]?.[key];if(direct?.Safe===true&&String(direct.Text??'').trim())return{value:String(direct.Text),Reference:String(direct.Reference||'Verified English source'),SourcePack:String(direct.SourcePack||'User-supplied English source'),verified:true};return null;}
    const base=baseline(bucket,key,'en'),v=String(base?.[field]??'').trim();if(v)return{value:v,Reference:'Canonical English localization',SourcePack:'Bundled canonical English data',verified:true};return null;
  }
  function applyAutoEntry(entry,{overwrite=true,forceManual=false}={}){
    if(!entry||state.lang!=='en'||state.bucket==='graphics')return{changed:0,missing:0};const bucket=state.bucket,key=rowKey(bucket,entry.id),fields=FIELDS[bucket]||['Text'];let changed=0,missing=0,row=(state.doc.languages.en[bucket][key]||={});
    if(manualEnglishRow(row)&&!forceManual)return{changed:0,missing:0};
    for(const field of fields){const c=autoCandidate(bucket,key,field);if(!c||!String(c.value??'').trim()){missing++;continue;}if(!overwrite&&String(row[field]??'').trim())continue;if(String(row[field]??'')!==String(c.value)){row[field]=String(c.value);changed++;}if(isTextBucket(bucket)){row.Reference=c.Reference;row.SourcePack=c.SourcePack;row.AutoTranslated=true;row.MachineTranslated=false;delete row.NeedsReview;}}
    if(!Object.keys(row).length)delete state.doc.languages.en[bucket][key];return{changed,missing};
  }
  function autoSourceForField(bucket,key,field){
    if(isTextBucket(bucket))return String(key??'');
    return String(baseline(bucket,key,'es')?.[field]??'');
  }
  function protectMachineTokens(text){
    const tokens=[];
    const protectedText=String(text??'').replace(/(?:\\[A-Za-z]+(?:\[[^\]]*\])?|\\[A-Za-z]|\{\d+\}|<\/?c\d*(?:=[^>]+)?>|<[^>]+>|%\d*\$?[sdif]|\n|\r|\t)/g,m=>{const id=`ZXQTS${tokens.length}QXZ`;tokens.push(m);return id;});
    return{protectedText,tokens};
  }
  function restoreMachineTokens(text,tokens){
    let out=String(text??'');
    (tokens||[]).forEach((tok,i)=>{const id=`ZXQTS${i}QXZ`;out=out.replace(new RegExp(id,'g'),tok);});
    return out;
  }
  function localTitleFallback(source){
    let s=String(source??'').trim();if(!s)return'';
    const exact={
      'Indomable':'Indomitable','el Indomable':'the Indomitable','la Indomable':'the Indomitable',
      'Dominante':'Totem','el Dominante':'the Totem','la Dominante':'the Totem',
      'Implacable':'Relentless','el Implacable':'the Relentless','la Implacable':'the Relentless',
      'Invencible':'Invincible','el Invencible':'the Invincible','la Invencible':'the Invincible',
      'Feroz':'Fierce','el Feroz':'the Fierce','la Feroz':'the Fierce',
      'Salvaje':'Wild','el Salvaje':'the Wild','la Salvaje':'the Wild',
      'Ancestral':'Ancient','el Ancestral':'the Ancient','la Ancestral':'the Ancient',
      'Eterno':'Eternal','Eterna':'Eternal','el Eterno':'the Eternal','la Eterna':'the Eternal',
      'Despierta':'Wake up','Despierta...':'Wake up...','Gran Espíritu':'Elder Spirit'
    };
    if(exact[s])return exact[s];
    const reps=[
      [/\bel\s+Indomable\b/gi,'the Indomitable'],[/\bla\s+Indomable\b/gi,'the Indomitable'],
      [/\bel\s+Dominante\b/gi,'the Totem'],[/\bla\s+Dominante\b/gi,'the Totem'],
      [/\bel\s+Implacable\b/gi,'the Relentless'],[/\bla\s+Implacable\b/gi,'the Relentless'],
      [/\bel\s+Invencible\b/gi,'the Invincible'],[/\bla\s+Invencible\b/gi,'the Invincible'],
      [/\bel\s+Feroz\b/gi,'the Fierce'],[/\bla\s+Feroz\b/gi,'the Fierce'],
      [/\bel\s+Ancestral\b/gi,'the Ancient'],[/\bla\s+Ancestral\b/gi,'the Ancient'],
      [/\bGran Espíritu\b/g,'Elder Spirit'],[/\bDespierta\b/gi,'Wake up'],
      [/\bIndomable\b/gi,'Indomitable'],[/\bDominante\b/gi,'Totem'],[/\bImplacable\b/gi,'Relentless'],[/\bInvencible\b/gi,'Invincible'],[/\bFeroz\b/gi,'Fierce'],[/\bAncestral\b/gi,'Ancient'],[/\bEterno\b/gi,'Eternal'],[/\bEterna\b/gi,'Eternal']
    ];
    let out=s;for(const[r,v]of reps)out=out.replace(r,v);
    return out!==s?out:'';
  }
  async function fetchWithTimeout(url,ms=10000){
    if(typeof fetch!=='function')throw new Error('fetch unavailable');
    const ctrl=typeof AbortController!=='undefined'?new AbortController():null;const timer=ctrl?setTimeout(()=>ctrl.abort(),ms):null;
    try{const res=await fetch(url,{method:'GET',signal:ctrl?.signal,headers:{'Accept':'application/json'}});if(!res.ok)throw new Error(`HTTP ${res.status}`);return await res.json();}finally{if(timer)clearTimeout(timer);}
  }
  async function machineTranslateEsEn(source){
    const raw=String(source??'').trim();if(!raw)return{value:'',provider:''};
    const cacheKey='es>en\0'+raw;if(state.machineCache.has(cacheKey))return state.machineCache.get(cacheKey);
    const {protectedText,tokens}=protectMachineTokens(raw);let value='',provider='';
    try{
      const url='https://translate.googleapis.com/translate_a/single?client=gtx&sl=es&tl=en&dt=t&q='+encodeURIComponent(protectedText);
      const data=await fetchWithTimeout(url,10000);if(Array.isArray(data?.[0]))value=data[0].map(x=>Array.isArray(x)?String(x[0]??''):'').join('');
      if(value){value=restoreMachineTokens(value,tokens).trim();provider='Google Translate';}
    }catch{}
    if(!value||value===raw){
      try{
        const url='https://api.mymemory.translated.net/get?q='+encodeURIComponent(protectedText)+'&langpair=es|en';
        const data=await fetchWithTimeout(url,10000);value=String(data?.responseData?.translatedText??'').trim();if(value){value=restoreMachineTokens(value,tokens).trim();provider='MyMemory';}
      }catch{}
    }
    if(!value||value===raw){const local=localTitleFallback(raw);if(local){value=local;provider='Translate Studio local fallback';}}
    const result={value:String(value||''),provider};state.machineCache.set(cacheKey,result);return result;
  }
  async function applyAutoEntryAsync(entry,{overwrite=true,forceManual=false}={}){
    if(!entry||state.lang!=='en'||state.bucket==='graphics')return{changed:0,missing:0,machine:0};
    const bucket=state.bucket,key=rowKey(bucket,entry.id),fields=FIELDS[bucket]||['Text'],row=(state.doc.languages.en[bucket][key]||={});
    if(manualEnglishRow(row)&&!forceManual)return{changed:0,missing:0,machine:0};
    const exact=applyAutoEntry(entry,{overwrite,forceManual});let changed=exact.changed,machine=0,missing=0;
    for(const field of fields){
      if(autoCandidate(bucket,key,field))continue;
      if(!overwrite&&String(row[field]??'').trim())continue;
      const source=autoSourceForField(bucket,key,field);if(!source.trim()){missing++;continue;}
      const mt=await machineTranslateEsEn(source);if(!mt.value.trim()){missing++;continue;}
      if(String(row[field]??'')!==mt.value){row[field]=mt.value;changed++;machine++;}
      row.Reference=`Automatic es→en fallback · ${mt.provider||'Translate Studio'}`;row.SourcePack='Translate Studio automatic translation fallback';row.AutoTranslated=true;row.MachineTranslated=true;row.NeedsReview=false;
    }
    if(!Object.keys(row).length)delete state.doc.languages.en[bucket][key];return{changed,missing,machine};
  }
  async function autoTranslateSelection(){if(state.lang!=='en'){toast('Cambia a ENG para usar la traducción automática.','info');return;}const ids=selectedIdsForBucket();if(!ids.length){toast('Selecciona uno o más textos con las casillas.','info');return;}let changed=0,missing=0,machine=0;for(const id of ids){const e=(state.catalogs[state.bucket]||[]).find(x=>x.id===id);const r=await applyAutoEntryAsync(e,{overwrite:true,forceManual:true});changed+=r.changed;missing+=r.missing;machine+=r.machine;}if(changed)setDirty(true);renderList();renderEditor();toast(`${changed} campo${changed===1?'':'s'} completado${changed===1?'':'s'}${machine?` · ${machine} por traducción automática`:''}${missing?` · ${missing} sin resolver`:''}.`,missing?'warning':'info');}
  async function autoTranslateCurrent(entry){if(state.lang!=='en'){toast('Cambia a ENG para usar la traducción automática.','info');return;}toast('Buscando fuente inglesa o traduciendo automáticamente…','info');const r=await applyAutoEntryAsync(entry,{overwrite:true,forceManual:true});if(r.changed)setDirty(true);renderList();renderEditor();toast(r.changed?(r.machine?`Traducción automática aplicada y guardada.`:`Traducción aplicada desde una fuente inglesa verificada.`):`No se pudo traducir este texto automáticamente. Comprueba la conexión.`,r.changed?'info':'warning');}
  async function autoTranslateGlobal(){
    if(state.autoRunning)return;
    const previous={bucket:state.bucket,selected:state.selected,filter:state.filter,sourceGroup:state.sourceGroup,eventMap:state.eventMap,integrationMode:state.integrationMode,integrationGroup:state.integrationGroup};
    if(state.lang!=='en'){langSel.value='en';state.lang='en';}
    state.autoRunning=true;autoAllBtn.disabled=true;autoAllBtn.textContent='⚡ Revisando ENG…';state.scanMessage='Cargando bibliotecas para traducción automática…';updateStatus();let changed=0,missing=0;
    try{
      for(const b of DATA_BUCKETS.map(x=>x[0]))await ensureDataBucketLoaded(b,false);
      for(const b of ['scripts','plugins','bss','sds','events'])await ensureTextBucketLoaded(b,false);
      for(const bucket of [...DATA_BUCKETS.map(x=>x[0]),'general','events','scripts','plugins','bss','sds']){state.bucket=b;for(const e of(state.catalogs[bucket]||[])){const r=await applyAutoEntryAsync(e,{overwrite:true,forceManual:false});changed+=r.changed;missing+=r.missing;}}
      if(changed)setDirty(true);toast(`${changed} campos ENG completados/reparados${missing?` · ${missing} sin resolver`:''}.`,missing?'warning':'info');
    }finally{
      Object.assign(state,previous);state.autoRunning=false;autoAllBtn.disabled=false;autoAllBtn.textContent='⚡ Auto todo ENG';state.scanMessage='';renderAll();
    }
  }
  function renderAutoTools(){autoTools.innerHTML='';if(state.bucket==='graphics'){autoTools.style.display='none';return;}autoTools.style.display='flex';const n=selectedIdsForBucket().length;autoTools.append(el('span',{class:'trs-auto-label',text:'AUTO ENG · fuente verificada → traducción automática'}),el('button',{class:'trs-btn small',text:`⚡ Selección${n?` (${n})`:''}`,disabled:!n,onClick:()=>autoTranslateSelection()}),el('button',{class:'trs-btn small',text:'Limpiar selección',disabled:!n,onClick:()=>{state.selectedRows.clear();renderList();}}));}
  function filteredRows(){
    const q=norm(state.search.trim());let rows=[...(state.catalogs[state.bucket]||[])];
    if(state.sourceGroup!=='all')rows=rows.filter(e=>sourceGroupInfo(e).includes(state.sourceGroup));
    if(q)rows=rows.filter(e=>searchable(e).includes(q));
    if(state.bucket==='events'&&state.eventMap!=='all')rows=rows.filter(e=>(e.contexts||[]).some(c=>eventMapLabelFromContext(c)===state.eventMap));
    if((state.bucket==='bss'||state.bucket==='sds')&&state.integrationMode!=='all')rows=rows.filter(e=>(e.contexts||[]).some(c=>{const info=integrationContextInfo(c,state.bucket);if(info.mode!==state.integrationMode)return false;return state.integrationGroup==='all'||info.group===state.integrationGroup;}));
    if(state.bucket==='graphics'){
      if(state.filter==='pairs')rows=rows.filter(e=>!!(e.en&&(e.es||e.neutral)&&graphicEnabled(e,'es')&&graphicEnabled(e,'en')));
      else if(state.filter==='es')rows=rows.filter(e=>!!(e.es||e.neutral));
      else if(state.filter==='en')rows=rows.filter(e=>!!e.en);
      else if(state.filter==='missing')rows=rows.filter(e=>!(e.en&&(e.es||e.neutral)));
      else if(state.filter==='disabled')rows=rows.filter(e=>!graphicEnabled(e,'es')||!graphicEnabled(e,'en'));
      return rows;
    }
    if(state.filter==='missing')rows=rows.filter(e=>!hasTranslation(e));
    else if(state.filter==='translated')rows=rows.filter(e=>hasTranslation(e));
    else if(state.filter==='custom')rows=rows.filter(isCustom);
    if(state.bucket==='sds')rows.sort((a,b)=>compareContextOrder(a,b,'sds'));
    return rows;
  }
  function renderList(){
    renderFilters();renderLibraryGroups();renderAutoTools();items.innerHTML='';const rows=filteredRows(),shown=rows.slice(0,state.listLimit);
    for(const e of shown){
      if(state.bucket==='graphics'){
        const esOn=graphicEnabled(e,'es'),enOn=graphicEnabled(e,'en'),complete=!!((e.es||e.neutral)&&e.en&&esOn&&enOn);const sub=[!esOn?'ESP fuera':(e.es?'ESP explícito':(e.neutral?'ESP usa base':'ESP falta')),!enOn?'ENG fuera':(e.en?'ENG explícito':'ENG falta')].join(' · ');
        items.append(el('div',{class:'trs-row'+(state.selected===e.id?' active':''),onClick:()=>{state.selected=e.id;renderList();renderEditor();}},[el('div',{},[el('div',{class:'trs-row-title',text:e.name||e.id}),el('div',{class:'trs-row-sub',text:sub})]),el('span',{class:'trs-badge '+(complete?'good':'warn'),text:complete?'PAR':'FALTA'})]));
        continue;
      }
      const translated=hasTranslation(e),sub=isTextBucket(state.bucket)?truncate((e.contexts||[])[0]||TEXT_KIND_LABEL[state.bucket],120):(e.id+(e.file?' · '+e.file:'')),selKey=selectionKey(state.bucket,e.id),checked=state.selectedRows.has(selKey);
      const check=el('input',{class:'trs-row-check',type:'checkbox',title:'Seleccionar para Auto ENG'});check.checked=checked;check.addEventListener('click',ev=>ev.stopPropagation());check.addEventListener('change',ev=>{if(ev.target.checked)state.selectedRows.add(selKey);else state.selectedRows.delete(selKey);renderAutoTools();});
      items.append(el('div',{class:'trs-row has-check'+(state.selected===e.id?' active':''),onClick:()=>{state.selected=e.id;renderList();renderEditor();}},[check,el('div',{},[el('div',{class:'trs-row-title',text:truncate(e.name||e.id,90)}),el('div',{class:'trs-row-sub',text:sub})]),el('span',{class:'trs-badge '+(translated?'good':'warn'),text:translated?'OK':'BASE'})]));
    }
    foot.textContent=`${rows.length} entradas${rows.length>shown.length?` · mostrando ${shown.length}`:''}`;
    if(rows.length>shown.length)items.append(el('button',{class:'trs-load-more',text:`Mostrar ${Math.min(450,rows.length-shown.length)} más`,onClick:()=>{state.listLimit+=450;renderList();}}));
  }
  function setField(bucket,id,field,value){
    const key=rowKey(bucket,id),base=String(baseline(bucket,key)?.[field]??'').trim(),v=String(value??'').trim(),rows=state.doc.languages[state.lang][bucket];
    // For contextual text, an empty value means "use source/base". For structured
    // data, matching the canonical/base value also does not need an override.
    const redundant=!v||(!isTextBucket(bucket)&&v===base);
    if(redundant){if(rows[key]){delete rows[key][field];if(!Object.keys(rows[key]).length)delete rows[key];}}
    else {const row=(rows[key]||={});row[field]=String(value??'');if(state.lang==='en'&&isTextBucket(bucket)){row.Manual=true;row.Reference='Manual edit · Translate Studio';row.SourcePack='Manual';delete row.AutoTranslated;delete row.VerifiedAutoRepair;}}
    setDirty(true);
  }
  function addGeneral(){
    const source=prompt('Texto original exacto:');if(!source)return;
    if(!state.contextCatalog.general[source])mergeContexts(state.contextCatalog,'general',source,['Manual · Translate Studio'],'Manual');
    rebuildTextCatalogs();state.bucket='general';state.selected=source;setDirty(true);renderAll();
  }
  function renderContexts(e){
    const contexts=e.contexts||[];if(!contexts.length)return el('div',{class:'trs-context-empty',text:'Sin contexto detectado todavía.'});
    const box=el('div',{class:'trs-context-list'});for(const c of contexts)box.append(el('div',{class:'trs-context-row'},[el('span',{class:'trs-context-dot'}),el('span',{text:c})]));return box;
  }
  function projectAbs(rel){const rootPath=String(state.gameRoot||'').replace(/[\\/]+$/,'');return rootPath?rootPath+'/'+String(rel||'').replace(/^[/\\]+/,''):'';}
  async function readProjectBinary(rel){const abs=projectAbs(rel);if(!abs)throw new Error('No se pudo resolver la ruta del proyecto.');const invoke=window.__TAURI__?.core?.invoke||window.__TAURI__?.tauri?.invoke;if(typeof invoke!=='function')throw new Error('Maker Studio no expone lectura binaria.');const bytes=await invoke('read_binary_file',{path:abs});return bytes instanceof Uint8Array?bytes:new Uint8Array(bytes||[]);}
  async function loadAssetUrl(rel){
    const abs=projectAbs(rel);if(!abs||state.assetFailures.has(abs))return null;if(state.assetUrls.has(abs))return state.assetUrls.get(abs);
    const invoke=window.__TAURI__?.core?.invoke;if(!invoke)return null;
    try{const bytes=await invoke('read_binary_file',{path:abs});if(!bytes?.length){state.assetFailures.add(abs);return null;}const arr=bytes instanceof Uint8Array?bytes:new Uint8Array(bytes||[]);const ext=(rel.match(/\.([a-z0-9]+)$/i)?.[1]||'png').toLowerCase();const mime=ext==='jpg'||ext==='jpeg'?'image/jpeg':ext==='webp'?'image/webp':ext==='bmp'?'image/bmp':'image/png';const url=URL.createObjectURL(new Blob([arr],{type:mime}));state.assetUrls.set(abs,url);return url;}catch{state.assetFailures.add(abs);return null;}
  }
  function graphicRuleKey(e){return String(e?.baseNoExt||'').replace(/\\/g,'/').toLowerCase();}
  function graphicEnabled(e,lang){const row=state.config.graphicRules?.[graphicRuleKey(e)]?.[lang];return row?.enabled!==false;}
  function setGraphicEnabled(e,lang,enabled){state.config.graphicRules||={};const key=graphicRuleKey(e);const group=(state.config.graphicRules[key]||={});const row=(group[lang]||={});row.enabled=!!enabled;if(enabled&&Object.keys(row).length===1)delete group[lang];if(!Object.keys(group).length)delete state.config.graphicRules[key];setDirty(true);renderList();renderGraphicEditor(e);}
  function normalizePickerPath(value){if(value==null)return'';if(Array.isArray(value))return value.length?normalizePickerPath(value[0]):'';if(typeof value==='string')return value;if(typeof value==='object')for(const k of['path','filePath','filepath','selectedPath','selected','value','location']){const v=value[k];if(typeof v==='string'&&v)return v;if(v&&typeof v==='object'){const nested=normalizePickerPath(v);if(nested)return nested;}}return'';}
  async function copyExternalImageToProject(sourceAbs,targetRel){
    const invoke=window.__TAURI__?.core?.invoke||window.__TAURI__?.tauri?.invoke;if(typeof invoke!=='function')throw new Error('Maker Studio no expone lectura/escritura binaria.');
    const bytes=await invoke('read_binary_file',{path:sourceAbs});const targetAbs=projectAbs(targetRel);if(!targetAbs)throw new Error('No se pudo resolver la carpeta del proyecto.');
    await invoke('write_binary_file',{path:targetAbs,data:Array.from(bytes instanceof Uint8Array?bytes:new Uint8Array(bytes||[]))});
  }
  async function importGraphicVariant(e,lang){
    try{
      const picked=await ctx.ui.showFilePicker?.({multiple:false,directory:false,filters:[{name:'Imagen UI',extensions:['png','jpg','jpeg','bmp','webp']}]});const src=normalizePickerPath(picked);if(!src)return;
      const srcExt=(src.match(/(\.[^.\/]+)$/)?.[1]||'').toLowerCase(),ext=(e.ext||srcExt||'.png').toLowerCase();if(e.ext&&srcExt&&srcExt!==e.ext.toLowerCase())throw new Error(`Esta UI usa ${e.ext}. Importa una imagen ${e.ext} para que el runtime pueda resolver la pareja correctamente.`);const suffix=lang==='es'?'_ESP':'_ENG';const target=`${e.baseNoExt}${suffix}${ext}`;await copyExternalImageToProject(src,target);
      setGraphicEnabled(e,lang,true);SOURCE_SCAN_CACHE.graphics=null;state.graphicsLoaded=false;state.assetFailures.clear();for(const u of state.assetUrls.values())try{URL.revokeObjectURL(u);}catch{}state.assetUrls.clear();
      await ensureGraphicsLoaded(true);const fresh=(state.catalogs.graphics||[]).find(x=>x.baseNoExt.toLowerCase()===e.baseNoExt.toLowerCase())||null;if(fresh)state.selected=fresh.id;renderAll();toast(`${lang==='es'?'ESP':'ENG'}: imagen importada/reemplazada.`,'info');
    }catch(err){toast(String(err?.message||err),'error');}
  }
  function imageSide(e,title,code,lang,path,fallback=false){
    const enabled=graphicEnabled(e,lang),shown=enabled?path:(e.neutral||null);
    const card=el('div',{class:'trs-image-side'+(enabled?'':' disabled')});
    const head=el('div',{class:'trs-image-head'},[el('span',{class:'trs-lang-badge '+code.toLowerCase(),text:code}),el('b',{text:title}),!enabled?el('span',{class:'trs-fallback',text:'fuera de traducción'}):(fallback?el('span',{class:'trs-fallback',text:'usa base'}):null)]);
    const preview=el('div',{class:'trs-image-preview'}),pathEl=el('div',{class:'trs-image-path',text:enabled?(path||'No hay variante'):'Variante desactivada · el runtime usa la imagen base'});card.append(head,preview,pathEl);
    if(shown){const img=el('img',{alt:title});preview.append(img);loadAssetUrl(shown).then(url=>{if(url)img.src=url;else preview.append(el('span',{text:'Vista previa no disponible'}));});}else preview.append(el('div',{class:'trs-image-missing',text:'Sin archivo'}));
    const controls=el('div',{class:'trs-image-controls'});
    const toggle=el('label',{class:'trs-toggle'},[el('input',{type:'checkbox'}),el('span',{text:'Usar esta variante en la traducción'})]);toggle.querySelector('input').checked=enabled;toggle.querySelector('input').onchange=ev=>setGraphicEnabled(e,lang,ev.target.checked);
    const importBtn=el('button',{class:'trs-btn small',text:path?'Reemplazar imagen':'Importar imagen',onClick:()=>importGraphicVariant(e,lang)});
    const removeBtn=el('button',{class:'trs-btn small danger',text:'Quitar de traducción',disabled:!enabled,onClick:()=>setGraphicEnabled(e,lang,false)});
    controls.append(toggle,importBtn,removeBtn);card.append(controls);return card;
  }
  function renderGraphicEditor(e){
    editor.innerHTML='';if(!e){editor.append(el('div',{class:'trs-empty',html:state.graphicsLoading?'Cargando imágenes/UI…<br><small>Solo se escanean al entrar aquí.</small>':'Selecciona una imagen/UI.<br><small>Puedes importar, reemplazar o excluir cada variante ESP/ENG sin tocar la imagen base.</small>'}));return;}
    editor.append(el('div',{class:'trs-hero'},[el('div',{class:'trs-hero-copy'},[el('h2',{text:e.name||e.id}),el('div',{class:'trs-meta',text:e.id})]),el('span',{class:'trs-source',text:'Graphics/UI'})]));
    const pair=el('div',{class:'trs-image-pair'});pair.append(imageSide(e,'Español','ESP','es',e.es||e.neutral,!e.es&&!!e.neutral),imageSide(e,'English','ENG','en',e.en,false));editor.append(pair);
    editor.append(el('div',{class:'trs-card'},[el('div',{class:'trs-card-head',text:'Archivos por idioma'}),el('div',{class:'trs-help-block',html:`<b>ESP:</b> <code>${e.baseNoExt}_ESP${e.ext}</code><br><b>ENG:</b> <code>${e.baseNoExt}_ENG${e.ext}</code><br><span>La variante puede tener tamaño y composición distintos. “Quitar de traducción” no borra tu PNG: solo hace que el juego deje de usarlo, y puedes reactivarlo después.</span>`})]));
  }
  function renderEditor(){
    if(state.bucket==='graphics'){renderGraphicEditor((state.catalogs.graphics||[]).find(x=>x.id===state.selected));return;}
    editor.innerHTML='';
    if(state.bucket==='general')editor.append(el('div',{class:'trs-editor-tools'},[el('button',{class:'trs-btn small',text:'+ Añadir texto general',onClick:addGeneral}),el('span',{text:'Eventos, scripts, plugins, BSS y SDS se detectan desde el proyecto actual y aparecen en secciones separadas.'})]));
    const e=(state.catalogs[state.bucket]||[]).find(x=>x.id===state.selected);
    if(!e){editor.append(el('div',{class:'trs-empty',html:'Selecciona una entrada para traducir.<br><small>El juego lee el JSON directamente; no hay extracción/compilación para aplicar cambios.</small>'}));return;}
    const displayTitle=isTextBucket(state.bucket)?truncate(e.id,100):(e.name||e.id);
    editor.append(el('div',{class:'trs-hero'},[el('div',{class:'trs-hero-copy'},[el('h2',{text:displayTitle}),el('div',{class:'trs-meta',text:isTextBucket(state.bucket)?e.id:e.id})]),el('span',{class:'trs-source',text:isTextBucket(state.bucket)?TEXT_KIND_LABEL[state.bucket]:(e.source||e.file||'PBS')})]));
    if(isTextBucket(state.bucket))editor.append(el('div',{class:'trs-context-card'},[el('div',{class:'trs-card-head',text:`Contexto detectado · ${(e.contexts||[]).length}`}),renderContexts(e)]));
    if(state.bucket==='bss'&&(e.contexts||[]).some(c=>/(?:displayName|databoxTitle|boss\s*·\s*title|hud\s*·\s*(?:displayName|databoxTitle))/i.test(String(c))))editor.append(el('div',{class:'trs-note',text:'Nombre/título BSS editable: puedes dar una versión distinta por idioma (por ejemplo, “Dragonite el Indomable” → “Dragonite the Indomitable”). El BSS original no se modifica; Translate Studio cambia solo la presentación del idioma activo.'}));
    if(state.lang==='en')editor.append(el('div',{class:'trs-editor-tools trs-auto-editor'},[el('button',{class:'trs-btn small primary',text:'⚡ Auto-traducir este texto',onClick:()=>autoTranslateCurrent(e)}),el('span',{text:'Prioridad: fuente inglesa exacta → traducción curada/canónica → traducción automática es→en si no existe referencia.'})]));
    const card=el('div',{class:'trs-card'}),head=el('div',{class:'trs-card-head',text:state.lang==='es'?'ESP · Traducción / variante':'ENG · English translation'});card.append(head);
    for(const field of(FIELDS[state.bucket]||['Text'])){
      const baseObj=baseline(state.bucket,e.id),original=String(baseObj?.[field]??e.fields?.[field]??''),row=currentRow(state.bucket,e.id),value=String(row?.[field]??'');
      const fieldWrap=el('div',{class:'trs-field'+(value?' changed':'')}),lab=el('div',{},[el('div',{class:'trs-label',text:field}),el('div',{class:'trs-original',text:original?`Original/base: ${original}`:'Original/base: —'})]);
      const multiline=['Description','Pokedex','BeforeText','AfterText','Notes','Text'].includes(field),input=multiline?el('textarea',{class:'trs-textarea',placeholder:original||'Escribe la traducción…'}):el('input',{class:'trs-input',value,placeholder:original||'Escribe la traducción…'});if(multiline)input.value=value;input.addEventListener('input',()=>setField(state.bucket,e.id,field,input.value));fieldWrap.append(lab,input);card.append(fieldWrap);
    }
    editor.append(card);
    editor.append(el('div',{class:'trs-note',text:isTextBucket(state.bucket)?'El contexto indica de qué mapa, evento, script, plugin, BSS o SDS salió el texto. BSS y SDS tienen secciones propias y se detectan directamente del proyecto.':'En English se usa la localización canónica incluida cuando existe; un override solo se guarda si realmente cambia el texto base.'}));
  }
  function renderAll(){renderCats();renderList();renderEditor();updateStatus();}

  async function loadCatalog(bucket,names){
    const re=FILE_PATTERNS[bucket],files=names.filter(n=>re?.test(n)).sort(),map=new Map();
    for(const file of files){let txt='';try{txt=await read('PBS/'+file);}catch{continue;}for(const sec of parseSections(txt)){
      let id=up(sec.id);if(bucket==='species'){const parts=id.split(',');id=parts[0]+(parts[1]&&/^\d+$/.test(parts[1])?','+Number(parts[1]):'');}
      const prev=map.get(id)||{id,fields:{},file,source:'PBS'};prev.fields={...prev.fields,...sec.fields};prev.file=file;prev.name=sec.fields.Name||sec.fields.FormName||prev.name||id;map.set(id,prev);
    }}
    return[...map.values()].sort((a,b)=>String(a.name||a.id).localeCompare(String(b.name||b.id),'es',{sensitivity:'base'}));
  }
  function normalizeEntryPath(root,e){
    const raw=typeof e==='string'?e:(e?.path||e?.name||'');if(!raw)return'';const s=String(raw).replace(/\\/g,'/');if(s.startsWith(root.replace(/\\/g,'/')))return s;const name=s.split('/').pop();return root.replace(/[\\/]+$/,'')+'/'+name;
  }
  async function walkProject(root,{maxDepth=8,maxEntries=12000}={}){
    const out=[],seen=new Set();
    async function walk(dir,depth){if(depth>maxDepth||out.length>=maxEntries||seen.has(dir))return;seen.add(dir);const entries=await listDir(dir);for(const e of entries){if(out.length>=maxEntries)break;const full=normalizeEntryPath(dir,e);if(!full)continue;const hintedDir=(e&&typeof e==='object'&&(e.type==='directory'||e.isDirectory===true||e.kind==='directory'));const name=full.split('/').pop();if(hintedDir){await walk(full,depth+1);continue;}if(/\.[A-Za-z0-9]{1,6}$/.test(name)){out.push(full);continue;}const child=await listDir(full);if(child?.length){await walk(full,depth+1);}else if(e&&typeof e==='object'&&e.type==='file')out.push(full);}}
    await walk(root,0);return out;
  }
  function decodeRubyLiteral(text,quote){
    let s=String(text||'');if(quote==='"')s=s.replace(/\\n/g,'\n').replace(/\\r/g,'\r').replace(/\\t/g,'\t').replace(/\\"/g,'"').replace(/\\\\/g,'\\');else s=s.replace(/\\'/g,"'").replace(/\\\\/g,'\\');return s;
  }
  function scanCodeForIntl(code,contextPrefix,bucket,target){
    const text=String(code||'');
    const patterns=[
      {re:/(?:_INTL|_ISPRINTF|pbEnter(?:Text|PlayerName|PokemonName|NPCName|BoxName))\s*\(\s*(["'])((?:\\.|(?!\1)[\s\S])*?)\1/g,suffix:''},
      {re:/(?:text_inline|show_centered_text)\s*(?:\(\s*)?(["'])((?:\\.|(?!\1)[\s\S])*?)\1/g,suffix:'SDS texto'},
      {re:/speaker\s*:\s*(["'])((?:\\.|(?!\1)[\s\S])*?)\1/g,suffix:'SDS hablante'}
    ];
    for(const {re,suffix} of patterns){let m;while((m=re.exec(text))){const source=decodeRubyLiteral(m[2],m[1]);if(!source)continue;const line=text.slice(0,m.index).split('\n').length;const ctx=suffix?`${contextPrefix}:L${line} · ${suffix}`:`${contextPrefix}:L${line}`;mergeContexts(target,bucket,source,[ctx],'Proyecto');}}
  }
  function queueAutoReference(path,code,bucket){
    if(!['scripts','plugins','bss','sds'].includes(bucket))return 0;const idx=bucket==='scripts'?state.baseReferenceIndex:state.pluginReferenceIndex,ref=referenceForPath(idx,path);if(!ref||!Array.isArray(ref.entries)||!ref.entries.length)return 0;const current=extractCodeEntries(code),english=ref.entries;if(current.length!==english.length||current.some((r,i)=>String(r.kind)!==String(english[i]?.kind)))return 0;let added=0;const mem=state.autoMemory[bucket]||=( {} ),coll=state.autoCollisions[bucket]||new Set();for(let i=0;i<current.length;i++){const source=String(current[i].text||''),target=String(english[i]?.text||'');if(!source||!target||source===target)continue;const prev=mem[source];if(prev&&String(prev.Text)!==target){delete mem[source];coll.add(source);continue;}if(coll.has(source))continue;const seedTarget=String(state.seedDoc?.languages?.en?.[bucket]?.[source]?.Text??'');const safe=!!seedTarget&&seedTarget===target;mem[source]={Text:target,Reference:String(ref.path||path),SourcePack:String(ref.sourcePack||'User-supplied English reference'),Safe:safe};added++;}return added;
  }
  function applyVerifiedRepairs(bucket){if(state.lang!=='en'&&!state.doc?.languages?.en)return 0;let changed=0;for(const[source,candidate]of Object.entries(state.autoMemory?.[bucket]||{})){if(candidate?.Safe!==true)continue;const row=(state.doc.languages.en[bucket][source]||={});if(manualEnglishRow(row))continue;if(String(candidate.Text||'').trim()&&String(row.Text??'')!==String(candidate.Text)){row.Text=String(candidate.Text);row.Reference=String(candidate.Reference||'Verified English source');row.SourcePack=String(candidate.SourcePack||'User-supplied English source');row.VerifiedAutoRepair=true;changed++;}}if(changed){state.qualityMigrations+=changed;setDirty(true);}return changed;}
  function externalTextKey(key,system=''){
    const low=String(key??'').toLowerCase(),sys=String(system||'').toUpperCase();
    if(sys==='BSS'&&['ebdxmapbackdropstext'].includes(low))return false;
    // Custom BSS names/titles shown to the player are localizable.
    // displayName covers cases such as "Dragonite el Indomable" in the Boss HUD.
    if(sys==='BSS'&&['displayname','bossdisplayname','battlerdisplayname','nametitle','displaytitle','databoxtitle'].includes(low))return true;
    if(['text','speaker','title','subtitle','caption','label','prompt','description','dialogue','speech','choices','options','responses'].includes(low))return true;
    if(['message','title','subtitle','caption','prompt','dialogue','speech'].some(s=>low.endsWith(s)))return true;
    // In BSS, arbitrary *Text fields can contain serialized/technical configuration.
    // SDS can legitimately expose authored *Text fields, so keep that broader rule there.
    return sys!=='BSS'&&low.endsWith('text');
  }
  function scanExternalJsonValue(value,system,context,target,parentKey=null){
    const bucket=String(system||'').toUpperCase()==='BSS'?'bss':(String(system||'').toUpperCase()==='SDS'?'sds':'plugins');
    if(Array.isArray(value)){value.forEach((child,i)=>{if(typeof child==='string'&&externalTextKey(parentKey,system))mergeContexts(target,bucket,child,[`${context}[${i+1}]`],system);else scanExternalJsonValue(child,system,`${context}[${i+1}]`,target,parentKey);});return;}
    if(!value||typeof value!=='object')return;
    for(const [key,child] of Object.entries(value)){const childContext=`${context} · ${key}`;
      if(typeof child==='string'&&externalTextKey(key,system))mergeContexts(target,bucket,child,[childContext],system);
      else if(Array.isArray(child)&&externalTextKey(key,system)){child.forEach((entry,i)=>{if(typeof entry==='string')mergeContexts(target,bucket,entry,[`${childContext}[${i+1}]`],system);else scanExternalJsonValue(entry,system,`${childContext}[${i+1}]`,target,key);});}
      else scanExternalJsonValue(child,system,childContext,target,key);
    }
  }
  async function scanExternalJsonFile(path,system,target){
    if(!(await exists(path)))return;let doc;try{doc=JSON.parse(await read(path));}catch{return;}
    const label=String(system||'').toUpperCase();
    if(label==='BSS'&&Array.isArray(doc?.blueprints)){if(doc.global&&typeof doc.global==='object')scanExternalJsonValue(doc.global,'BSS','BSS General',target);doc.blueprints.forEach((bp,i)=>{if(!bp||typeof bp!=='object')return;const name=String(bp.name||bp.key||`Combate ${i+1}`).trim();scanExternalJsonValue(bp,'BSS',`BSS · ${name}`,target);});return;}
    if(label==='SDS'&&Array.isArray(doc?.scenes)){doc.scenes.forEach((scene,i)=>{if(!scene||typeof scene!=='object')return;const name=String(scene.name||scene.key||`Escena ${i+1}`).trim();scanExternalJsonValue(scene,'SDS',`SDS · ${name}`,target);if(scene.compiledRuby)scanCodeForIntl(String(scene.compiledRuby),`SDS · ${name} · Ruby`,'sds',target);});return;}
    scanExternalJsonValue(doc,label,label,target);
  }
  async function scanProjectEvents(force=false){
    const key=projectKey();if(!force&&SOURCE_SCAN_CACHE.projectKey===key&&SOURCE_SCAN_CACHE.events)return SOURCE_SCAN_CACHE.events;
    const out={general:{},events:{},scripts:{},plugins:{},bss:{},sds:{}};
    try{
      if(!(await exists('Data/MapInfos.rxdata')))return out;
      const infos=parseMapInfos(await readProjectBinary('Data/MapInfos.rxdata'));
      for(const [mapId,mapName] of [...infos.entries()].sort((a,b)=>a[0]-b[0])){
        const path=`Data/Map${String(mapId).padStart(3,'0')}.rxdata`;if(!(await exists(path)))continue;
        let rows=[];try{rows=parseMapEventTexts(await readProjectBinary(path),mapId,mapName);}catch{continue;}
        for(const row of rows)mergeContexts(out,'events',row.source,[row.context],'Proyecto RXDATA');
      }
      if(await exists('Data/CommonEvents.rxdata')){let rows=[];try{rows=parseCommonEventTexts(await readProjectBinary('Data/CommonEvents.rxdata'));}catch{}for(const row of rows)mergeContexts(out,'events',row.source,[row.context],'Proyecto RXDATA');}
    }catch{}
    SOURCE_SCAN_CACHE.projectKey=key;SOURCE_SCAN_CACHE.events=out;return out;
  }

  async function scanProjectSource(force=false){
    const key=projectKey();if(!force&&SOURCE_SCAN_CACHE.projectKey===key&&SOURCE_SCAN_CACHE.textCatalog)return SOURCE_SCAN_CACHE.textCatalog;
    const out={general:{},events:{},scripts:{},plugins:{},bss:{},sds:{}};
    for(const rootInfo of [['Data/Scripts','scripts'],['Scripts','scripts'],['Plugins','plugins']]){
      const[root,bucket]=rootInfo;if(!(await exists(root)))continue;const files=(await walkProject(root,{maxDepth:10,maxEntries:7000})).filter(p=>/\.rb$/i.test(p));
      for(const path of files){if(/\[CARNKEVT\]\s*Translate Studio|ZBox\s*(?:Translator|Traductor)|Translator[- _]?Helper/i.test(path))continue;let code='';try{code=await read(path);}catch{continue;}let context;
        let targetBucket=bucket;
        if(bucket==='plugins'){const rel=path.replace(/^Plugins\/?/i,''),parts=rel.split('/');
          if(/Battle[ _-]*Scene[ _-]*Studio/i.test(rel)){context=`BSS: ${rel}`;targetBucket='bss';}
          else if(/Scene[ _-]*Director|Scene[ _-]*Engine/i.test(rel)){context=`SDS: ${rel}`;targetBucket='sds';}
          else context=`Plugin: ${parts.length>1?parts[0]+' - ':''}${parts.slice(1).join('/')||parts[0]}`;
        }else context=`Script: ${path.replace(/^Data\/Scripts\/?/i,'').replace(/^Scripts\/?/i,'')}`;
        scanCodeForIntl(code,context,targetBucket,out);
      }
    }
    await scanExternalJsonFile('Data/BattleSceneStudio/battles.json','BSS',out);
    await scanExternalJsonFile('Data/BattleSceneStudio/battles.recovery.json','BSS',out);
    await scanExternalJsonFile('Data/SceneDirector/scenes.json','SDS',out);
    SOURCE_SCAN_CACHE.projectKey=key;SOURCE_SCAN_CACHE.textCatalog=out;return out;
  }

  async function scanKnownIntegrations(){
    const out={general:{},events:{},scripts:{},plugins:{},bss:{},sds:{}};
    const jsons=[
      ['Data/BattleSceneStudio/battles.json','BSS'],
      ['Data/BattleSceneStudio/battles.recovery.json','BSS'],
      ['Data/SceneDirector/scenes.json','SDS']
    ];
    for(const [path,system] of jsons)await scanExternalJsonFile(path,system,out);
    const roots=[
      ['Plugins/[CARNEK] Battle Scene Studio Runtime','bss','BSS'],
      ['Plugins/[CARNKEVT] Battle Scene Studio Runtime','bss','BSS'],
      ['Plugins/[CARNEK] Scene Director Runtime','sds','SDS'],
      ['Plugins/[LBDS_CUST] Scene Engine','sds','SDS']
    ];
    for(const [root,bucket,label] of roots){
      if(!(await exists(root)))continue;
      const files=(await walkProject(root,{maxDepth:5,maxEntries:400})).filter(p=>/\.rb$/i.test(p));
      for(const path of files){let code='';try{code=await read(path);}catch{continue;}scanCodeForIntl(code,`${label}: ${path.replace(/^Plugins\/?/i,'')}`,bucket,out);}
    }
    return out;
  }

  function stripLocalizedSuffix(path){
    const m=path.match(/^(.*)(\.[^.]+)$/);if(!m)return null;const noExt=m[1],ext=m[2],sm=noExt.match(LOCALIZED_SUFFIX_RE);if(!sm)return null;const token=sm[1].toUpperCase(),lang=['ESP','ES','SPANISH'].includes(token)?'es':'en';return{neutralNoExt:noExt.slice(0,-sm[0].length),ext,lang};
  }
  async function scanGraphics(force=false){
    const key=projectKey();if(!force&&SOURCE_SCAN_CACHE.projectKey===key&&SOURCE_SCAN_CACHE.graphics)return SOURCE_SCAN_CACHE.graphics;
    if(!(await exists('Graphics/UI')))return[];
    const files=(await walkProject('Graphics/UI',{maxDepth:9,maxEntries:9000})).filter(p=>IMAGE_EXT_RE.test(p)),groups=new Map();
    // Every neutral UI is listed too, not only files that already have _ESP/_ENG.
    // That makes untranslated artwork visible as “Falta par” instead of hiding it.
    for(const path of files){
      const info=stripLocalizedSuffix(path);
      const neutral=info?(info.neutralNoExt+info.ext):path;
      const baseNoExt=info?info.neutralNoExt:path.replace(/\.[^.]+$/,'');
      const ext=info?info.ext:(path.match(/(\.[^.]+)$/)?.[1]||'');
      const key2=neutral.toLowerCase();
      const g=groups.get(key2)||{id:neutral,name:neutral.split('/').pop(),baseNoExt,ext,neutral:null,es:null,en:null,source:'Graphics/UI'};
      if(info)g[info.lang]=path;else g.neutral=path;
      groups.set(key2,g);
    }
    const rows=[...groups.values()].sort((a,b)=>a.id.localeCompare(b.id,'es',{sensitivity:'base'}));SOURCE_SCAN_CACHE.projectKey=key;SOURCE_SCAN_CACHE.graphics=rows;return rows;
  }
  async function loadContextSources(force=false){
    const merged={general:{},events:{},scripts:{},plugins:{},bss:{},sds:{}};
    // The current project is authoritative. No ZBox/sample context is imported.
    if(await exists(DISCOVERY_PATH)){try{const dyn=JSON.parse(await read(DISCOVERY_PATH));const valid=Number(dyn?.schema||0)>=2&&String(dyn?.generatedBy||'')===`Translate Studio v${VERSION}`;if(valid)for(const b of Object.keys(merged))for(const[source,row]of Object.entries(dyn?.[b]||{}))mergeContexts(merged,b,source,row?.Contexts||[],'Proyecto actual');}catch{}}
    const directEvents=await scanProjectEvents(force);for(const[source,row]of Object.entries(directEvents?.events||{}))mergeContexts(merged,'events',source,row?.Contexts||[],'Proyecto RXDATA');
    const integrations=await scanKnownIntegrations();
    for(const b of ['bss','sds'])for(const[source,row]of Object.entries(integrations?.[b]||{}))mergeContexts(merged,b,source,row?.Contexts||[],b.toUpperCase());
    const project=await scanProjectSource(force);for(const b of ['scripts','plugins','bss','sds'])for(const[source,row]of Object.entries(project?.[b]||{}))mergeContexts(merged,b,source,row?.Contexts||[],'Proyecto actual');
    state.contextCatalog=merged;
  }
  function rebuildTextCatalogs(){
    for(const bucket of ['general','events','scripts','plugins','bss','sds']){
      let sources;
      if(bucket==='general')sources=new Set([...Object.keys(state.contextCatalog.general||{}),...Object.keys(state.doc.languages.es.general||{}),...Object.keys(state.doc.languages.en.general||{})]);
      else sources=new Set(Object.keys(state.contextCatalog[bucket]||{}));
      state.catalogs[bucket]=[...sources].map(source=>{const c=state.contextCatalog[bucket]?.[source]||{};return{id:source,name:source,fields:{Text:source},source:TEXT_KIND_LABEL[bucket],contexts:c.Contexts||[],origins:c.Origins||[]};}).sort((a,b)=>a.id.localeCompare(b.id,'es',{sensitivity:'base'}));
    }
  }
  async function saveContextCatalog(){
    try{const out={schema:2,generatedBy:`Translate Studio v${VERSION}`};for(const b of ['general','events','scripts','plugins','bss','sds'])out[b]=state.contextCatalog[b]||{};await ctx.fs.projectMkdir?.('Data/TranslateStudio');await ctx.fs.writeProjectFile(DISCOVERY_PATH,JSON.stringify(out,null,2)+'\n');}catch{}
  }
  async function loadCachedContextSources(){
    const merged={general:{},events:{},scripts:{},plugins:{},bss:{},sds:{}};
    if(await exists(DISCOVERY_PATH)){try{const dyn=JSON.parse(await read(DISCOVERY_PATH));const valid=Number(dyn?.schema||0)>=2&&/^Translate Studio/i.test(String(dyn?.generatedBy||''));if(valid)for(const b of Object.keys(merged))for(const[source,row]of Object.entries(dyn?.[b]||{})){const contexts=row?.Contexts||[];if(b==='bss'&&contexts.some(c=>/ebdxMapBackdropsText/i.test(String(c))))continue;mergeContexts(merged,b,source,contexts,row?.Origin||'Catálogo guardado');}}catch{}}
    state.contextCatalog=merged;rebuildTextCatalogs();
  }
  async function scanSingleTextBucket(bucket,force=false){
    const out={general:{},events:{},scripts:{},plugins:{},bss:{},sds:{}};
    if(bucket==='events')return await scanProjectEvents(force);
    if(bucket==='scripts'){
      for(const root of ['Data/Scripts','Scripts']){if(!(await exists(root)))continue;const files=(await walkProject(root,{maxDepth:10,maxEntries:7000})).filter(p=>/\.rb$/i.test(p));for(const path of files){let code='';try{code=await read(path);}catch{continue;}scanCodeForIntl(code,`Script: ${path.replace(/^Data\/Scripts\/?/i,'').replace(/^Scripts\/?/i,'')}`,'scripts',out);queueAutoReference(path,code,'scripts');}}
      return out;
    }
    if(bucket==='plugins'){
      if(await exists('Plugins')){const files=(await walkProject('Plugins',{maxDepth:10,maxEntries:7000})).filter(p=>/\.rb$/i.test(p));for(const path of files){const rel=path.replace(/^Plugins\/?/i,'');if(/\[CARNKEVT\]\s*Translate Studio|ZBox\s*(?:Translator|Traductor)|Translator[- _]?Helper|Battle[ _-]*Scene[ _-]*Studio|Scene[ _-]*(?:Director|Engine)/i.test(rel))continue;let code='';try{code=await read(path);}catch{continue;}const parts=rel.split('/');scanCodeForIntl(code,`Plugin: ${parts.length>1?parts[0]+' - ':''}${parts.slice(1).join('/')||parts[0]}`,'plugins',out);queueAutoReference(path,code,'plugins');}}
      return out;
    }
    if(bucket==='bss'){
      await scanExternalJsonFile('Data/BattleSceneStudio/battles.json','BSS',out);await scanExternalJsonFile('Data/BattleSceneStudio/battles.recovery.json','BSS',out);
      for(const root of ['Plugins/[CARNEK] Battle Scene Studio Runtime','Plugins/[CARNKEVT] Battle Scene Studio Runtime']){if(!(await exists(root)))continue;const files=(await walkProject(root,{maxDepth:6,maxEntries:800})).filter(p=>/\.rb$/i.test(p));for(const path of files){let code='';try{code=await read(path);}catch{continue;}scanCodeForIntl(code,`BSS: ${path.replace(/^Plugins\/?/i,'')}`,'bss',out);queueAutoReference(path,code,'bss');}}
      return out;
    }
    if(bucket==='sds'){
      await scanExternalJsonFile('Data/SceneDirector/scenes.json','SDS',out);
      for(const root of ['Plugins/[CARNEK] Scene Director Runtime','Plugins/[CARNKEVT] Scene Director Runtime','Plugins/[LBDS_CUST] Scene Engine']){if(!(await exists(root)))continue;const files=(await walkProject(root,{maxDepth:7,maxEntries:1200})).filter(p=>/\.rb$/i.test(p));for(const path of files){let code='';try{code=await read(path);}catch{continue;}scanCodeForIntl(code,`SDS: ${path.replace(/^Plugins\/?/i,'')}`,'sds',out);queueAutoReference(path,code,'sds');}}
      return out;
    }
    return out;
  }
  async function ensureTextBucketLoaded(bucket,force=false){
    if(!['events','scripts','plugins','bss','sds'].includes(bucket)||state.textLoading[bucket])return;
    if(state.textLoaded[bucket]&&!force)return;
    state.textLoading[bucket]=true;state.scanMessage=`Leyendo ${bucket==='events'?'eventos':bucket==='scripts'?'scripts base':bucket==='plugins'?'plugins':bucket.toUpperCase()}…`;updateStatus();renderCats();
    try{if(force&&state.autoMemory[bucket]){state.autoMemory[bucket]={};state.autoCollisions[bucket]=new Set();}const result=await scanSingleTextBucket(bucket,force);state.contextCatalog[bucket]={};for(const[source,row]of Object.entries(result?.[bucket]||{}))mergeContexts(state.contextCatalog,bucket,source,row?.Contexts||[],'Proyecto actual');state.textLoaded[bucket]=true;rebuildTextCatalogs();if(['scripts','plugins','bss','sds'].includes(bucket))applyVerifiedRepairs(bucket);await saveContextCatalog();}
    catch(e){toast(String(e?.message||e),'error');}
    finally{state.textLoading[bucket]=false;state.scanMessage='';if(state.bucket===bucket)renderAll();else{renderCats();updateStatus();}}
  }
  async function ensureDataBucketLoaded(bucket,force=false){
    if(!DATA_BUCKETS.some(x=>x[0]===bucket)||state.dataLoading[bucket])return;
    if(state.dataLoaded[bucket]&&!force)return;
    state.dataLoading[bucket]=true;state.scanMessage=`Leyendo ${DATA_BUCKETS.find(x=>x[0]===bucket)?.[1]||bucket}…`;updateStatus();renderCats();
    try{state.catalogs[bucket]=await loadCatalog(bucket,state.pbsNames||[]);state.dataLoaded[bucket]=true;await mergeChangeDex();state.catalogs[bucket].sort((a,b)=>String(a.name||a.id).localeCompare(String(b.name||b.id),'es',{sensitivity:'base'}));}
    catch(e){toast(String(e?.message||e),'error');}
    finally{state.dataLoading[bucket]=false;state.scanMessage='';if(state.bucket===bucket)renderAll();else{renderCats();updateStatus();}}
  }
  async function ensureGraphicsLoaded(force=false){
    if(state.graphicsLoading)return;
    if(state.graphicsLoaded&&!force)return;
    state.graphicsLoading=true;if(state.bucket==='graphics'){renderCats();renderList();renderEditor();updateStatus();}
    try{state.catalogs.graphics=await scanGraphics(force);state.graphicsLoaded=true;}
    catch(e){toast(String(e?.message||e),'error');}
    finally{state.graphicsLoading=false;if(state.bucket==='graphics')renderAll();else renderCats();}
  }
  async function mergeChangeDex(){
    if(!(await exists(CHANGEDEX_PATH)))return;let doc;try{doc=JSON.parse(await read(CHANGEDEX_PATH));}catch{return;}
    for(const bucket of['moves','abilities'])for(const[id,row]of Object.entries(doc?.[bucket]||{})){if(row?._new!==true)continue;const key=up(id);if(!(state.catalogs[bucket]||[]).some(x=>x.id===key))state.catalogs[bucket].push({id:key,name:row.Name||key,fields:{Name:row.Name||key,Description:row.Description||''},source:'ChangeDex'});}
    for(const[id,row]of Object.entries(doc?.species||{})){if(!row?._new)continue;const key=up(id);if(!state.catalogs.species.some(x=>x.id===key))state.catalogs.species.push({id:key,name:row.Name||key,fields:{Name:row.Name||key},source:'ChangeDex'});}
    let n=0;for(const l of['es','en'])for(const b of ALL_DOC_BUCKETS)n+=Object.keys(doc?.localization?.[l]?.[b]||{}).length;state.legacyCount=n;
  }

  async function openLanguageUiSettings(){
    const template=`# encoding: UTF-8
# Translate Studio custom language selector.
# Return "es", "en" or nil (only if allow_cancel is true).
module TranslateStudioLanguageUI
  def self.choose(initial_code = "es", allow_cancel = false)
    # Safe starting point: use the built-in visual scene.
    # Replace this line with your own Sprite/Bitmap/Viewport implementation if
    # you want a completely custom selector. Do not call pbShowCommands.
    CarnekTranslateStudio::LanguageScene.new(initial_code, allow_cancel).run
  end
end
`
    let code=template;const codePath=String(state.config.languageMenuCustomCode||'Data/TranslateStudio/language_menu_custom.rb');
    try{if(await exists(codePath))code=String(await read(codePath)||template);}catch{}
    let dlg=null;
    dlg=ctx.ui.showCustomDialog({title:'Selector de idioma · UI personalizada',width:'920px',height:'760px',render:body=>{
      const cfg=state.config;
      body.innerHTML=`<div class="trs-langui">
        <div class="trs-langui-grid">
          <label><b>Modo</b><select data-mode class="trs-select">
            <option value="default">UI visual integrada</option>
            <option value="graphics">UI con gráficos personalizados</option>
            <option value="code">Código Ruby + imágenes</option>
          </select></label>
          <div class="trs-help-block">El selector siempre es interfaz gráfica. En modo Ruby puedes combinar tu código con Fondo/Tarjetas/Cursor. <b>Atrás</b> solo vuelve/cancela; nunca abre un textbox de idiomas.</div>
        </div>
        <div data-graphics class="trs-card">
          <div class="trs-card-head">Gráficos del selector</div>
          <div class="trs-field"><div><div class="trs-label">Fondo completo</div><div class="trs-original">PNG opaco a pantalla completa. El paquete ya incluye uno editable.</div></div><input class="trs-input" data-bg></div>
          <div class="trs-field"><div><div class="trs-label">Cabecera</div><div class="trs-original">Título y subtítulo del selector como imagen editable.</div></div><input class="trs-input" data-header></div>
          <div class="trs-field"><div><div class="trs-label">Pie / controles</div><div class="trs-original">Ayuda inferior como imagen editable.</div></div><input class="trs-input" data-footer></div>
          <div class="trs-field"><div><div class="trs-label">Tarjeta Español</div></div><input class="trs-input" data-es></div>
          <div class="trs-field"><div><div class="trs-label">Tarjeta English</div></div><input class="trs-input" data-en></div>
          <div class="trs-field"><div><div class="trs-label">Cursor</div></div><input class="trs-input" data-cursor></div>
          <div class="trs-help-block">Si un gráfico no existe se usa el componente dibujado por defecto. Puedes reemplazar cada archivo directamente en <code>Graphics/UI/TranslateStudio/</code>.</div>
        </div>
        <div data-code class="trs-card">
          <div class="trs-card-head">Código del selector</div>
          <div class="trs-help-block">Archivo: <code>${codePath}</code>. Debe definir <code>TranslateStudioLanguageUI.choose(initial_code, allow_cancel)</code> y devolver <code>"es"</code>, <code>"en"</code> o <code>nil</code>.</div>
          <textarea class="trs-textarea trs-codearea" data-codearea></textarea>
          <div class="trs-image-controls"><button class="trs-btn small" data-template>Restaurar plantilla</button></div>
        </div>
        <div class="trs-langui-actions"><button class="trs-btn" data-cancel>Cerrar</button><button class="trs-btn primary" data-save>Guardar UI de idioma</button></div>
      </div>`;
      const mode=body.querySelector('[data-mode]'),bg=body.querySelector('[data-bg]'),header=body.querySelector('[data-header]'),footer=body.querySelector('[data-footer]'),es=body.querySelector('[data-es]'),en=body.querySelector('[data-en]'),cursor=body.querySelector('[data-cursor]'),codeArea=body.querySelector('[data-codearea]');
      mode.value=cfg.languageMenuMode||'graphics';bg.value=cfg.languageMenuBackground||'Graphics/UI/TranslateStudio/language_bg.png';header.value=cfg.languageMenuHeader||'Graphics/UI/TranslateStudio/language_header.png';footer.value=cfg.languageMenuFooter||'Graphics/UI/TranslateStudio/language_footer.png';es.value=cfg.languageMenuCardES||'Graphics/UI/TranslateStudio/language_es.png';en.value=cfg.languageMenuCardEN||'Graphics/UI/TranslateStudio/language_en.png';cursor.value=cfg.languageMenuCursor||'Graphics/UI/TranslateStudio/language_cursor.png';codeArea.value=code;
      const sync=()=>{body.querySelector('[data-graphics]').style.display=mode.value==='default'?'none':'';body.querySelector('[data-code]').style.display=mode.value==='code'?'':'none';};mode.onchange=sync;sync();
      body.querySelector('[data-template]').onclick=()=>{codeArea.value=template;};
      body.querySelector('[data-cancel]').onclick=()=>{try{dlg?.close?.();}catch{}};
      body.querySelector('[data-save]').onclick=async()=>{
        try{
          cfg.languageMenuMode=mode.value;cfg.languageMenuBackground=bg.value.trim();cfg.languageMenuHeader=header.value.trim();cfg.languageMenuFooter=footer.value.trim();cfg.languageMenuCardES=es.value.trim();cfg.languageMenuCardEN=en.value.trim();cfg.languageMenuCursor=cursor.value.trim();cfg.languageMenuCustomCode=codePath;
          await ctx.fs.projectMkdir?.('Data/TranslateStudio');await ctx.fs.writeProjectFile(codePath,codeArea.value.replace(/\r?\n/g,'\n'));
          setDirty(true);toast('UI de idioma guardada. Guarda Translate Studio para aplicar también la configuración.','info');
        }catch(e){toast(String(e?.message||e),'error');}
      };
    }});
  }

  function decodeBase64Bytes(text){const bin=atob(String(text||'').replace(/\s+/g,'')),out=new Uint8Array(bin.length);for(let i=0;i<bin.length;i++)out[i]=bin.charCodeAt(i);return out;}
  async function installLanguageUiAssets(){
    try{await ctx.fs.projectMkdir?.('Graphics/UI/TranslateStudio');}catch{}
    const invoke=window.__TAURI__?.core?.invoke||window.__TAURI__?.tauri?.invoke;
    if(typeof invoke!=='function')return false;
    for(const [modPath,targetRel] of Object.entries(MOD_LANG_UI)){
      try{
        if(await exists(targetRel))continue;
        const b64=await ctx.fs.readModFile(modPath),bytes=decodeBase64Bytes(b64),abs=projectAbs(targetRel);if(!abs)continue;
        await invoke('write_binary_file',{path:abs,data:Array.from(bytes)});
      }catch{}
    }
    return true;
  }

  async function runtimeIsCurrent(){
    try{if(!(await exists(RUNTIME_DIR+'/meta.txt')))return false;const t=await read(RUNTIME_DIR+'/meta.txt');const m=String(t||'').match(/^Version\s*=\s*([^\r\n]+)/mi);return String(m?.[1]||'').trim()===VERSION;}catch{return false;}
  }
  async function installRuntime({silent=false}={}){
    try{
      await ctx.fs.projectMkdir?.(RUNTIME_DIR);await ctx.fs.projectMkdir?.('Data/TranslateStudio');
      const [runtime,meta,canonEn,canonItems,contextSeed,langCode,pluginEnRef,baseEnRef,strictContextEn]=await Promise.all([ctx.fs.readModFile(MOD_RUNTIME),ctx.fs.readModFile(MOD_META),ctx.fs.readModFile(MOD_CANON_EN),ctx.fs.readModFile(MOD_CANON_ITEMS),ctx.fs.readModFile(MOD_CONTEXT_SEED),ctx.fs.readModFile(MOD_LANG_CODE),ctx.fs.readModFile(MOD_PLUGIN_EN_REF),ctx.fs.readModFile(MOD_BASE_EN_REF),ctx.fs.readModFile(MOD_STRICT_CONTEXT_EN)]);
      await ctx.fs.writeProjectFile(RUNTIME_DIR+'/001_TranslateStudio.rb',runtime);await ctx.fs.writeProjectFile(RUNTIME_DIR+'/meta.txt',meta);await ctx.fs.writeProjectFile(PROJECT_CANON_EN,canonEn);await ctx.fs.writeProjectFile(PROJECT_CANON_ITEMS,canonItems);await ctx.fs.writeProjectFile(PROJECT_CONTEXT_SEED,contextSeed);await ctx.fs.writeProjectFile(PROJECT_PLUGIN_EN_REF,pluginEnRef);await ctx.fs.writeProjectFile(PROJECT_BASE_EN_REF,baseEnRef);await ctx.fs.writeProjectFile(PROJECT_STRICT_CONTEXT_EN,strictContextEn);
      if(!(await exists('Data/TranslateStudio/language_menu_custom.rb')))await ctx.fs.writeProjectFile('Data/TranslateStudio/language_menu_custom.rb',langCode);
      await installLanguageUiAssets();
      state.autoInstalled=true;if(!silent)toast(`Runtime v${VERSION} instalado/actualizado.`,'info');return true;
    }catch(e){if(!silent)toast(String(e?.message||e),'error');return false;}
  }
  async function bootstrapData(){
    let contextSeed={};try{contextSeed=JSON.parse(await ctx.fs.readModFile(MOD_CONTEXT_SEED));}catch{}
    let raw=null,hadData=await exists(DATA_PATH);if(hadData){try{raw=JSON.parse(await read(DATA_PATH));}catch{hadData=false;}}
    const rawVersion=String(raw?.version||'0'),oldSchema=Number(raw?.schema||0),existing=normalizeDoc(raw||defaultDoc(),contextSeed);
    let canonEn={},canonItems={};try{canonEn=JSON.parse(await ctx.fs.readModFile(MOD_CANON_EN));}catch{}try{canonItems=JSON.parse(await ctx.fs.readModFile(MOD_CANON_ITEMS));}catch{}
    let baseRef={files:{}},pluginRef={files:{}};try{baseRef=JSON.parse(await ctx.fs.readModFile(MOD_BASE_EN_REF));}catch{}try{pluginRef=JSON.parse(await ctx.fs.readModFile(MOD_PLUGIN_EN_REF));}catch{}
    state.baseEnglishRef=baseRef;state.pluginEnglishRef=pluginRef;state.baseReferenceIndex=buildReferenceIndex(baseRef);state.pluginReferenceIndex=buildReferenceIndex(pluginRef);
    // v0.5 and older could contain reference-translator/ZBox text rows. They were never
    // authoritative project translations. Drop only those text buckets during the v0.6 -> v0.7
    // migration; structured Pokémon/move/ability/item/type overrides are preserved.
    if(oldSchema<5){for(const lang of ['es','en'])for(const bucket of ALL_TEXT_BUCKETS.map(x=>x[0]))existing.languages[lang][bucket]={};}
    state.typoFixes=fixKnownEnglishTypos(existing);
    let seed=defaultDoc();try{seed=normalizeDoc(JSON.parse(await ctx.fs.readModFile(MOD_SEED)),contextSeed);}catch{}state.seedDoc=seed;
    state.qualityMigrations=applyV13QualityMigration(existing,seed,canonEn,canonItems,rawVersion);state.qualityMigrations+=applyV14ContextMigration(existing,rawVersion);
    const copied=mergeSeed(existing,seed);existing.version=VERSION;existing.generatedBy=`Translate Studio v${VERSION}`;state.seedCopied=copied;state.doc=existing;
    if(!hadData||oldSchema<5||copied>0||state.typoFixes>0||state.qualityMigrations>0||rawVersion!==VERSION)await ctx.fs.writeProjectFile(DATA_PATH,JSON.stringify(existing,null,2)+'\n');
    let cfg=defaultConfig(),hadCfg=await exists(CONFIG_PATH),cfgOldSchema=0;
    if(hadCfg){try{const old=JSON.parse(await read(CONFIG_PATH));cfgOldSchema=Number(old?.schema||0);cfg={...defaultConfig(),...old};cfg.graphicRules=(old?.graphicRules&&typeof old.graphicRules==='object')?old.graphicRules:{};if(cfgOldSchema<6){cfg.schema=6;cfg.readDirectTextPacks=false;cfg.autoDiscoverDevelopmentTexts=true;cfg.discoveryOnlyInDebug=true;if(!old?.languageMenuMode||old.languageMenuMode==='default')cfg.languageMenuMode='graphics';}}catch{cfg=defaultConfig();hadCfg=false;}}
    state.config=cfg;if(!hadCfg||cfgOldSchema<6)await ctx.fs.writeProjectFile(CONFIG_PATH,JSON.stringify(cfg,null,2)+'\n');activeSel.value=cfg.activeLanguage||'auto';
  }
  async function save(){
    try{await ctx.fs.projectMkdir?.('Data/TranslateStudio');state.doc.version=VERSION;state.doc.generatedBy=`Translate Studio v${VERSION}`;await ctx.fs.writeProjectFile(DATA_PATH,JSON.stringify(state.doc,null,2)+'\n');state.config.schema=6;state.config.activeLanguage=activeSel.value;state.config.showFirstBootLanguageMenu=true;state.config.readDirectTextPacks=false;await ctx.fs.writeProjectFile(CONFIG_PATH,JSON.stringify(state.config,null,2)+'\n');setDirty(false);toast('Guardado. El juego toma los cambios directamente del JSON.','info');}catch(e){toast(String(e?.message||e),'error');}
  }
  async function loadProject(force=false){
    state.loading=true;state.scanMessage='Abriendo Translate Studio…';updateStatus();
    if(!(await runtimeIsCurrent()))await installRuntime({silent:true});
    await bootstrapData();
    try{state.pbsNames=namesFromList(await listDir('PBS/')).sort();}catch{state.pbsNames=[];}
    try{state.canonEn=JSON.parse(await ctx.fs.readModFile(MOD_CANON_EN));}catch{}try{state.canonItems=JSON.parse(await ctx.fs.readModFile(MOD_CANON_ITEMS));}catch{}
    await loadCachedContextSources();
    // Solo la biblioteca visible se carga al entrar. Scripts, plugins, RXDATA, BSS, SDS e imágenes ya no bloquean la apertura.
    await ensureDataBucketLoaded(state.bucket==='species'?state.bucket:'species',force);
    state.loading=false;state.scanMessage='';renderAll();
  }
  async function detectAllChanges(){
    if(state.loading)return;state.loading=true;state.scanMessage='Detectando cambios del proyecto…';updateStatus();
    try{
      for(const b of ['events','scripts','plugins','bss','sds'])await ensureTextBucketLoaded(b,true);
      if(state.graphicsLoaded||state.bucket==='graphics')await ensureGraphicsLoaded(true);
      await saveContextCatalog();toast('Catálogo actualizado: eventos, scripts, plugins, BSS y SDS.','info');
    }finally{state.loading=false;state.scanMessage='';renderAll();}
  }

  function updateFullscreenUi(){fullscreenBtn.textContent=fullscreenActive?'↙ Salir de pantalla completa':'⛶ Pantalla completa';fullscreenBtn.classList.toggle('active',fullscreenActive);fullscreenBtn.title=fullscreenActive?'Salir de pantalla completa · F11 / Esc':'Pantalla completa · F11';}
  function enterFullscreenMode(){if(fullscreenActive||!document.body)return false;fullscreenPreviousScroll={x:Number(window.scrollX||0),y:Number(window.scrollY||0)};fullscreenPlaceholder=document.createComment('Translate Studio fullscreen home');if(root.parentNode)root.parentNode.insertBefore(fullscreenPlaceholder,root);document.body.appendChild(root);fullscreenActive=true;state.fullscreen=true;root.classList.add('trs-fullscreen-active');document.body.classList.add('trs-fullscreen-lock');updateFullscreenUi();requestAnimationFrame(()=>root.focus({preventScroll:true}));return true;}
  function exitFullscreenMode(){if(!fullscreenActive)return false;root.classList.remove('trs-fullscreen-active');document.body.classList.remove('trs-fullscreen-lock');if(fullscreenPlaceholder?.parentNode)fullscreenPlaceholder.parentNode.replaceChild(root,fullscreenPlaceholder);else host.appendChild(root);fullscreenPlaceholder=null;fullscreenActive=false;state.fullscreen=false;updateFullscreenUi();try{window.scrollTo(fullscreenPreviousScroll.x||0,fullscreenPreviousScroll.y||0);}catch{}return true;}
  function toggleFullscreenMode(){return fullscreenActive?exitFullscreenMode():enterFullscreenMode();}
  async function closeEditorFromFullscreen(){exitFullscreenMode();try{if(typeof ctx.ui?.closePanel==='function')return await ctx.ui.closePanel(PANEL_ID);if(typeof ctx.ui?.hidePanel==='function')return await ctx.ui.hidePanel(PANEL_ID);}catch{}return false;}
  const fullscreenKeyboard=e=>{if(e.key==='F11'){e.preventDefault();e.stopPropagation();toggleFullscreenMode();return;}if(fullscreenActive&&e.key==='Escape'){e.preventDefault();e.stopPropagation();exitFullscreenMode();}};
  root.addEventListener('keydown',fullscreenKeyboard,true);window.addEventListener('keydown',fullscreenKeyboard,true);updateFullscreenUi();

  langSel.onchange=()=>{state.lang=langSel.value;state.selectedRows.clear();renderAll();};
  activeSel.onchange=()=>{state.config.activeLanguage=activeSel.value;setDirty(true);};
  search.oninput=()=>{state.search=search.value;state.listLimit=450;renderList();renderEditor();};
  filters.addEventListener('click',ev=>{const b=ev.target.closest('[data-filter]');if(!b)return;state.filter=b.dataset.filter;state.listLimit=450;renderList();renderEditor();});
  eventMapSel.onchange=()=>{state.eventMap=eventMapSel.value;state.selected=null;state.selectedRows.clear();state.listLimit=450;renderList();renderEditor();};
  integrationModeSel.onchange=()=>{state.integrationMode=integrationModeSel.value;state.integrationGroup='all';state.selected=null;state.selectedRows.clear();state.listLimit=450;renderList();renderEditor();};
  integrationGroupSel.onchange=()=>{state.integrationGroup=integrationGroupSel.value;state.selected=null;state.selectedRows.clear();state.listLimit=450;renderList();renderEditor();};
  langUiBtn.onclick=()=>openLanguageUiSettings();
  autoAllBtn.onclick=()=>autoTranslateGlobal().catch(e=>toast(String(e?.message||e),'error'));
  scanBtn.onclick=()=>detectAllChanges().catch(e=>toast(String(e?.message||e),'error'));
  fullscreenBtn.onclick=()=>toggleFullscreenMode();
  installBtn.onclick=()=>installRuntime();saveBtn.onclick=save;
  loadProject().catch(e=>{state.loading=false;status.textContent=String(e?.message||e);toast(String(e?.message||e),'error');});
}
