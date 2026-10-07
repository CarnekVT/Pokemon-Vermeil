export const CHANGE_FIELDS = [
  'Types','BaseStats','Abilities','HiddenAbilities','Moves','TutorMoves','EggMoves','Evolutions',
  'EVs','BaseExp','CatchRate','Happiness','GenderRatio','GrowthRate','EggGroups','HatchSteps','Height','Weight','Flags'
];

export const FIELD_GROUPS = {
  stats: ['BaseStats','EVs','BaseExp','CatchRate','Happiness'],
  identity: ['Types','GenderRatio','GrowthRate'],
  abilities: ['Abilities','HiddenAbilities'],
  moves: ['Moves','TutorMoves','EggMoves'],
  evolution: ['Evolutions','EggGroups','HatchSteps'],
  advanced: ['Height','Weight','Flags']
};

export const STAT_KEYS = ['HP','Atk','Def','Spe','SpA','SpD'];

export function parsePbsSections(text, fileName='') {
  const out=[];
  let cur=null;
  for (const raw of String(text ?? '').split(/\r?\n/)) {
    const t=raw.trim();
    if (!t || t.startsWith('#')) continue;
    const hm=t.match(/^\[([^\]]+)\](?:!exclude)?$/);
    if (hm) {
      cur={_header:hm[1].trim(),_file:fileName,_order:[]};
      out.push(cur);
      continue;
    }
    if (!cur) continue;
    const clean=t.split('#',1)[0].trim();
    const eq=clean.indexOf('=');
    if (eq<0) continue;
    const k=clean.slice(0,eq).trim();
    const v=clean.slice(eq+1).trim();
    if (k==='Evolution') {
      const ep=String(v??'').split(',').map(x=>x.trim());
      const normalized=[ep[0]||'',ep[1]||'None',ep.length>2?(ep[2]||''):''].join(',');
      cur.Evolutions = cur.Evolutions ? `${cur.Evolutions},${normalized}` : normalized;
      if (!cur._order.includes('Evolutions')) cur._order.push('Evolutions');
    } else {
      // Keep explicit empty values in the source entry. Forms commonly use an
      // empty field to mean “inherit base”; resolvePbsEntry handles that later.
      cur[k]=v;
      if (!cur._order.includes(k)) cur._order.push(k);
    }
  }
  return out;
}

export function mergeSpeciesFiles(fileEntries) {
  const map=new Map();
  for (const [file, entries] of fileEntries) {
    for (const e of entries) {
      const h=String(e?._header ?? '').trim();
      if (!h) continue;
      const prev=map.get(h)||{_header:h,_files:[],_explicitFields:new Set()};
      if (!prev._files.includes(file)) prev._files.push(file);
      if (!(prev._explicitFields instanceof Set)) prev._explicitFields=new Set(prev._explicitFields||[]);
      for (const [k,v] of Object.entries(e||{})) {
        if (k.startsWith('_')) continue;
        prev._explicitFields.add(k);
        // Empty values are intentionally retained. They are treated as an
        // inheritance marker by resolvePbsEntry for non-base forms.
        prev[k]=v;
      }
      map.set(h,prev);
    }
  }
  return [...map.values()];
}

export function splitHeader(header) {
  const [speciesRaw, formRaw] = String(header ?? '').split(',');
  const species=String(speciesRaw ?? '').trim();
  const form=Number(String(formRaw ?? '0').trim())||0;
  return {species,form};
}

export function isFormEntry(entry) {
  return splitHeader(entry?._header).form>0;
}

export function resolvePbsEntry(entry, basesBySpecies) {
  if (!entry) return null;
  const {species,form}=splitHeader(entry._header);
  const base=basesBySpecies?.get(species);
  if (!form || !base || base===entry) return {...entry};
  const resolved={...base,...entry,_header:entry._header,_files:entry._files||[],_sourceEntry:entry};
  // In Pokémon forms PBS, an explicitly blank property means “inherit the
  // base form”. Do not let the blank overwrite the base value in the visual
  // baseline used by the editor/comparator.
  for (const k of Object.keys(entry)) {
    if (k.startsWith('_')) continue;
    if (String(entry[k] ?? '').trim()==='' && base[k]!==undefined) resolved[k]=base[k];
  }
  return resolved;
}

export function fieldProvenance(entry, field, basesBySpecies) {
  if (!entry) return {inherited:false,source:'none'};
  const {species,form}=splitHeader(entry._header);
  if (!form) return {inherited:false,source:'base'};
  const base=basesBySpecies?.get(species);
  const own=Object.prototype.hasOwnProperty.call(entry,field) && String(entry[field] ?? '').trim()!=='';
  if (!own && base && base[field]!==undefined) return {inherited:true,source:'base'};
  return {inherited:false,source:'form'};
}

export function normalizeDoc(doc) {
  if (!doc || typeof doc!=='object' || Array.isArray(doc)) doc={};
  if (!doc.species || typeof doc.species!=='object' || Array.isArray(doc.species)) doc.species={};
  if (!doc.moves || typeof doc.moves!=='object' || Array.isArray(doc.moves)) doc.moves={};
  if (!doc.abilities || typeof doc.abilities!=='object' || Array.isArray(doc.abilities)) doc.abilities={};
  if (!doc.meta || typeof doc.meta!=='object' || Array.isArray(doc.meta)) doc.meta={};
  if (!doc.localization || typeof doc.localization!=='object' || Array.isArray(doc.localization)) doc.localization={};
  for (const lang of ['es','en']) {
    if (!doc.localization[lang] || typeof doc.localization[lang]!=='object' || Array.isArray(doc.localization[lang])) doc.localization[lang]={};
    for (const bucket of ['species','moves','abilities','items','types','strings']) if (!doc.localization[lang][bucket] || typeof doc.localization[lang][bucket]!=='object' || Array.isArray(doc.localization[lang][bucket])) doc.localization[lang][bucket]={};
  }
  for (const row of Object.values(doc.species||{})) {
    if (row && Object.prototype.hasOwnProperty.call(row,'Evolutions')) {
      row.Evolutions=evosToCsv(parseEvos(row.Evolutions));
    }
  }
  doc.schema=5;
  if (!doc.generatedBy) doc.generatedBy='ChangeDex Studio';
  return doc;
}

export function effectiveEntry(base, changes) {
  return {...(base||{}),...(changes||{})};
}

export function normalizeCsv(v) {
  return String(v ?? '').split(',').map(x=>String(x ?? '').trim()).filter(Boolean).join(',');
}

export function sameField(a,b) {
  return normalizeCsv(a)===normalizeCsv(b);
}

export function setOverride(doc, header, field, value, baseline) {
  doc=normalizeDoc(doc);
  const h=String(header ?? '').trim();
  const f=String(field ?? '').trim();
  if (!h || !f) return doc;
  const v=String(value ?? '').trim();
  if (sameField(v, baseline?.[f] ?? '')) {
    if (doc.species[h]) {
      delete doc.species[h][f];
      if (!Object.keys(doc.species[h]).length) delete doc.species[h];
    }
  } else {
    (doc.species[h] ||= {})[f]=v;
  }
  return doc;
}

export function changedFields(doc, header) {
  return Object.keys(doc?.species?.[String(header ?? '')]||{});
}

export function parseMoves(v) {
  const p=String(v ?? '').split(',').map(x=>x.trim());
  const out=[];
  for (let i=0;i<p.length;i+=2) {
    const level=String(p[i] ?? '').trim();
    const move=String(p[i+1] ?? '').trim();
    if (level || move) out.push([level||'1',move]);
  }
  return out;
}

export function movesToCsv(rows) {
  return (Array.isArray(rows)?rows:[])
    .filter(r=>String(r?.[1] ?? '').trim()!=='')
    .map(r=>`${String(r?.[0] ?? '1').trim()||'1'},${String(r?.[1] ?? '').trim().toUpperCase()}`)
    .join(',');
}

export function parseList(v) {
  return String(v ?? '').split(',').map(x=>x.trim()).filter(Boolean);
}

export function listToCsv(rows) {
  return (Array.isArray(rows)?rows:[]).map(x=>String(x ?? '').trim().toUpperCase()).filter(Boolean).join(',');
}

const EVO_NO_PARAM_METHODS=new Set([
  'TRADE','HAPPINESS','HAPPINESSMALE','HAPPINESSFEMALE','HAPPINESSDAY','HAPPINESSNIGHT',
  'HAPPINESSMOVE','HAPPINESSMOVETYPE','BEAUTY','SHEDINJA'
]);

export function parseEvos(v) {
  const p=String(v ?? '').split(',').map(x=>x.trim());
  const out=[];
  let i=0;
  while(i<p.length){
    const species=String(p[i++]??'').trim();
    if(!species){if(i>=p.length)break;continue;}
    const method=String(p[i++]??'None').trim()||'None';
    let param='';
    if(EVO_NO_PARAM_METHODS.has(method.toUpperCase())){
      // Consume the explicit blank third slot when present, but also accept
      // legacy ChangeDex strings where that placeholder was accidentally lost.
      if(i<p.length && String(p[i]??'')==='')i++;
    }else{
      param=String(p[i++]??'').trim();
    }
    out.push([species,method,param]);
  }
  return out;
}

export function evosToCsv(rows) {
  return (Array.isArray(rows)?rows:[])
    .filter(r=>String(r?.[0] ?? '').trim()!=='')
    .map(r=>[
      String(r?.[0] ?? '').trim().toUpperCase(),
      String(r?.[1] ?? 'None').trim()||'None',
      String(r?.[2] ?? '').trim()
    ].join(','))
    .join(',');
}

export function displayName(entry, basesBySpecies) {
  if (!entry) return '';
  const {species,form}=splitHeader(entry._header);
  const base=basesBySpecies?.get(species);
  const name=String(entry.Name || base?.Name || species || '').trim();
  if (!form) return name;
  const formName=String(entry.FormName || `Form ${form}`).trim();
  return `${name} — ${formName}`;
}

export function setEntityOverride(doc, bucket, id, field, value, baseline={}) {
  doc=normalizeDoc(doc);
  const b=String(bucket??'').trim();
  const key=String(id??'').trim().toUpperCase();
  const f=String(field??'').trim();
  if (!['moves','abilities'].includes(b) || !key || !f) return doc;
  const v=String(value??'').trim();
  if (sameField(v, baseline?.[f] ?? '')) {
    if (doc[b][key]) {
      delete doc[b][key][f];
      if (!Object.keys(doc[b][key]).length) delete doc[b][key];
    }
  } else {
    (doc[b][key] ||= {})[f]=v;
  }
  return doc;
}

export function changedEntityFields(doc,bucket,id) {
  return Object.keys(doc?.[String(bucket??'')]?.[String(id??'').toUpperCase()]||{});
}

export function normalizeSearch(value) {
  return String(value ?? '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g,'')
    .toLowerCase();
}

export function setLocalizationOverride(doc,lang,bucket,id,field,value,baseline='') {
  doc=normalizeDoc(doc);
  const l=String(lang||'').toLowerCase();
  const b=String(bucket||'').trim();
  const key=String(id||'').trim().toUpperCase();
  const f=String(field||'').trim();
  if(!['es','en'].includes(l)||!['species','moves','abilities','items','types'].includes(b)||!key||!f)return doc;
  const v=String(value??'').trim();
  if(v===String(baseline??'').trim()){
    const row=doc.localization?.[l]?.[b]?.[key];
    if(row){delete row[f];if(!Object.keys(row).length)delete doc.localization[l][b][key];}
  }else{((doc.localization[l][b][key] ||= {}))[f]=v;}
  return doc;
}

export function localizationFields(doc,lang,bucket,id){
  return Object.keys(doc?.localization?.[String(lang||'').toLowerCase()]?.[String(bucket||'')]?.[String(id||'').toUpperCase()]||{});
}
