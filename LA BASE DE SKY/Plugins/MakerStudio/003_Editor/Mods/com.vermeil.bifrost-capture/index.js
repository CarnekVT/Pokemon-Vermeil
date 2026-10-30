import { STYLES } from "./styles.js";
const CFG="Plugins/[VERMEIL] Bifrost Capture/config.ini";
const ROSTER="Plugins/[VERMEIL] Bifrost Capture/roster.ini";
const POKEMON_FILES=["PBS/pokemon.txt","PBS/pokemon_Vermeil.txt"];
const LEGEND="RAIKOU ENTEI SUICUNE LATIAS LATIOS ARTICUNO ZAPDOS MOLTRES UXIE MESPRIT AZELF COBALION TERRAKION VIRIZION GENESECT LANDORUS TORNADUS THUNDURUS ETERNATUS TAPUKOKO TAPULELE TAPUBULU TAPUFINI".split(" ");
const D={
 profile:"bifrost",enabled:"1",access_mode:"always",hotkey:"jumpup",control_mode:"hold",
 ball_key:"jumpdown",target_key:"action",mode_key:"special",debug_input_guard:"1",
 capture_enabled:"1",battle_enabled:"1",restricted_species:"1",encounter_mode:"classic",
 spawn_chance:"50",spawn_min_distance:"3",spawn_max_distance:"6",spawn_limit:"5",
 spawn_lifetime:"45",spawn_filter:"all",spawn_grass_only:"1",spawn_allow_fishing:"0",
 ow_extra_spawn_chance:"0",ow_extra_spawn_cooldown:"7",
 ow_form:"0",ow_min_level:"0",ow_max_level:"0",ow_spawn_probability:"100",
 range:"7",width:"7",optimal_range:"4",alert_distance:"3",hit_near:"100",hit_far:"60",
 capture_floor:"10",back_multiplier:"175",critical_front:"3",critical_back:"35",
 critical_multiplier:"250",line_of_sight:"1",reaction:"flee",consume_on_miss:"1",
 allow_empty_throw:"0",impact_frames:"3",capture_shakes:"3",capture_shake_frames:"10",
 aim_keyboard:"1",aim_speed:"5",aim_mouse:"1",aim_target_radius:"30",
 throw_frames:"18",throw_arc:"36",aim_chain:"0",flee_steps:"5",flee_speed:"4",
 flee_disappear_distance:"9",flee_stuck_frames:"90",alert_on_miss:"1",
 attempt_limit:"0",instant_modifier:"100",
 temperament:"mixed",neutral_weight:"50",timid_weight:"30",aggressive_weight:"20",
 timid_alert_distance:"4",aggressive_alert_distance:"5",aggressive_attack_distance:"1",
 aggressive_chase_speed:"4",aggressive_level_bonus:"2",
 feedback_enabled:"1",feedback_frames:"150",feedback_sfx:"1",capture_fx:"1",
 audio_profile:"vanilla",sfx_aim:"none",sfx_switch:"none",sfx_lock:"none",
 sfx_throw:"none",sfx_hit:"none",sfx_shake:"none",sfx_caught:"none",
 sfx_breakout:"none",sfx_flee:"none",sfx_alert:"none"
};
const PRESETS={
 bifrost:{...D},
 classic:{...D,profile:"classic",capture_enabled:"0"},
 adventure:{...D,profile:"adventure",restricted_species:"0",reaction:"attack"},
 safari:{...D,profile:"safari",restricted_species:"0",battle_enabled:"0"},
 full_ow:{...D,profile:"full_ow",restricted_species:"0",encounter_mode:"overworld"},
 custom:{...D,profile:"custom"}
};
const PRESET_HELP={
 bifrost:"Solo catálogo de legendarios en eventos OW; hierba tradicional.",
 classic:"Mantiene el sistema clásico y desactiva capturas directas.",
 adventure:"Amplía especies permitidas y activa reacciones de ataque.",
 safari:"Captura sin seleccionar un Pokémon para iniciar combates.",
 full_ow:"Convierte los encuentros naturales terrestres en OW capturables.",
 custom:"Copia inicial independiente para ajustar cada parámetro."
};
const CHOICES={
 profile:Object.keys(PRESETS),access_mode:["always","nearby","event"],
 hotkey:["jumpup","jumpdown","aux1","aux2","action","special","none"],
 ball_key:["jumpup","jumpdown","aux1","aux2","action","special","none"],
 target_key:["jumpup","jumpdown","aux1","aux2","action","special","none"],
 mode_key:["jumpup","jumpdown","aux1","aux2","action","special","none"],
 control_mode:["toggle","hold"],
 encounter_mode:["classic","hybrid","overworld"],spawn_filter:["all","allowlist"],
 reaction:["flee","attack","ignore"],temperament:["mixed","neutral","timid","aggressive"],
 audio_profile:["vanilla","original","muted"]
};
const V={ "1":"Sí","0":"No",aux1:"AUX1 (Q)",aux2:"AUX2 (W)",none:"Ninguno",jumpup:"JUMPUP (A)",jumpdown:"JUMPDOWN (S)",
 action:"ACTION (Shift/Z)",special:"SPECIAL (D)",
 event:"Solo evento",always:"Siempre",nearby:"Con OW cercano",
 toggle:"Pulsar / lanzar con USE",hold:"Mantener / soltar",
 classic:"Encuentros tradicionales",hybrid:"Mixto",overworld:"OW completo",
 flee:"Huir",attack:"Atacar",ignore:"Ignorar",all:"Todos",allowlist:"Solo catálogo",
 mixed:"Mixto (probabilidades)",neutral:"Neutro",timid:"Miedoso",aggressive:"Agresivo",
 vanilla:"Sonidos de Essentials",original:"Solo archivos propios",muted:"Silenciado" };
const T=(v)=>V[v]??v;
const F=[
 ["SISTEMA","general"],
 ["Perfil del proyecto","profile"],["Motor activo","enabled"],["Acceso al apuntado","access_mode"],
 ["Tecla de apertura","hotkey"],["Modalidad de control","control_mode"],
 ["Cambiar Poké Ball","ball_key"],["Cambiar objetivo","target_key"],
 ["Alternar lanzamiento/combate","mode_key"],["Proteger combos debug CTRL","debug_input_guard"],
 ["Captura directa","capture_enabled"],["Enviar Pokémon","battle_enabled"],
 ["Exclusividad del catálogo Bifröst","restricted_species"],
 ["ENCUENTROS NATURALES","spawns"],
 ["Modo de encuentros","encounter_mode"],["Porcentaje de OW en modo mixto","spawn_chance",0,100],
 ["Distancia mínima de aparición","spawn_min_distance",1,12],
 ["Distancia máxima de aparición","spawn_max_distance",1,16],
 ["OW simultáneos","spawn_limit",1,16],["Duración (pasos)","spawn_lifetime",0,999],
 ["Ratio OW independiente / paso (%)","ow_extra_spawn_chance",0,100],
 ["Espera tras aparición extra (pasos)","ow_extra_spawn_cooldown",0,250],
 ["Especies generadas","spawn_filter"],["Generar en hierba","spawn_grass_only"],
 ["Pesca: reservado, no activo","spawn_allow_fishing"],
 ["ESPECIE OW","species"],
 ["Forma regional","ow_form",0,100],["Nivel mínimo (0 = tabla)","ow_min_level",0,100],
 ["Nivel máximo (0 = tabla)","ow_max_level",0,100],
 ["Probabilidad individual (%)","ow_spawn_probability",0,100],
 ["APUNTADO","aim"],["Alcance en casillas","range",1,20],
 ["Ancho frontal","width",1,19],["Distancia óptima","optimal_range",1,20],
 ["Precisión cercana (%)","hit_near",0,100],["Precisión lejana (%)","hit_far",0,100],
 ["Obstáculos bloquean","line_of_sight"],["Teclado/mando","aim_keyboard"],
 ["Velocidad de puntero","aim_speed",1,16],["Ratón","aim_mouse"],
 ["Radio de selección visual","aim_target_radius",4,120],
 ["Permitir tiro a vacío","allow_empty_throw"],
 ["Duración del vuelo","throw_frames",8,48],["Altura del arco","throw_arc",0,110],
 ["Lanzamientos consecutivos","aim_chain"],
 ["Efectos de captura dinámicos","capture_fx"],
 ["CAPTURA","capture"],["Captura mínima (%)","capture_floor",0,100],
 ["Multiplicador espalda (%)","back_multiplier",100,500],
 ["Crítica frontal (%)","critical_front",0,100],["Crítica por espalda (%)","critical_back",0,100],
 ["Potenciador crítico (%)","critical_multiplier",100,600],
 ["Modificador instantáneo (%)","instant_modifier",1,300],
 ["Límite de intentos (0 = libre)","attempt_limit",0,20],
 ["Consumir Ball al desviarse","consume_on_miss"],
 ["Notificación persistente","feedback_enabled"],
 ["Duración del resultado (frames)","feedback_frames",45,300],
 ["Sonidos de lanzamiento/captura","feedback_sfx"],
 ["Sacudidas de Ball","capture_shakes",1,5],["Fotogramas por sacudida","capture_shake_frames",4,20],
 ["COMPORTAMIENTO","behavior"],["Reacción anterior (compatibilidad)","reaction"],
 ["Temperamento de esta especie","temperament"],
 ["Probabilidad: neutro","neutral_weight",0,100],
 ["Probabilidad: miedoso","timid_weight",0,100],
 ["Probabilidad: agresivo","aggressive_weight",0,100],
 ["Alerta miedoso (casillas)","timid_alert_distance",0,20],
 ["Alerta agresivo (casillas)","aggressive_alert_distance",1,20],
 ["Contacto agresivo (casillas)","aggressive_attack_distance",1,6],
 ["Velocidad de persecución","aggressive_chase_speed",1,6],
 ["Nivel extra en batalla agresiva","aggressive_level_bonus",0,10],
 ["Radio de alerta","alert_distance",0,20],["Huida en pasos","flee_steps",1,30],
 ["Velocidad de huida","flee_speed",1,6],
 ["Distancia para escapar","flee_disappear_distance",4,30],
 ["Máximo de bloqueo","flee_stuck_frames",15,600],
 ["Reaccionar ante Ball fallida","alert_on_miss"],
 ["Impact frame","impact_frames",0,12],
 ["AUDIO","audio"],
 ["Modo de audio","audio_profile"],
 ["Apuntar: SFX propio","sfx_aim"],["Cambiar Ball: SFX propio","sfx_switch"],
 ["Fijar objetivo: SFX propio","sfx_lock"],["Lanzar: SFX propio","sfx_throw"],
 ["Impacto: SFX propio","sfx_hit"],["Sacudida: SFX propio","sfx_shake"],
 ["Captura: SFX propio","sfx_caught"],["Liberación: SFX propio","sfx_breakout"],
 ["Huida: SFX propio","sfx_flee"],["Alerta: SFX propio","sfx_alert"]
];
const GROUPS={};let section="";
for(const row of F){if(row.length===2&&Object.values(D).indexOf(row[1])===-1&&
  ["general","spawns","species","aim","capture","behavior","audio"].includes(row[1])){
 section=row[1];GROUPS[section]??=[];continue;
}if(D[row[1]]!==undefined)GROUPS[section].push(row[1]);}
const META=Object.fromEntries(F.filter(r=>D[r[1]]!==undefined).map(r=>[r[1],r]));
const NAV=[
 ["overview","◈","Resumen"],["profiles","▤","Perfiles"],["spawns","☷","Encuentros OW"],
 ["species","◇","Catálogo"],["aim","⊕","Lanzamiento"],
 ["capture","◉","Captura"],["behavior","⚑","Comportamiento"],["audio","♫","Audio"],
 ["scopes","▦","Ámbitos"],["tests","⌁","Validación"]
];
const esc=(s)=>String(s??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
function parseCfg(raw){
 const out={global:{...D}};let section="global";
 for(const row of String(raw||"").split(/\r?\n/)){
  const line=row.replace(/[;#].*$/,"").trim();
  const h=/^\[(global|map:\d+|species:[a-z0-9_]+|event:\d+:\d+)\]$/i.exec(line);
  if(h){section=h[1].toLowerCase();out[section]??={};continue;}
  const kv=/^([a-z_]+)\s*=\s*([a-z0-9_]+)$/i.exec(line);
  if(kv&&D[kv[1].toLowerCase()]!==undefined)out[section][kv[1].toLowerCase()]=kv[2].toLowerCase();
 }
 return out;
}
function encodeCfg(data){
 const keys=["global",...Object.keys(data).filter(x=>x!=="global").sort()];
 return keys.map(key=>"["+key+"]\n"+Object.keys(D).
   filter(k=>Object.prototype.hasOwnProperty.call(data[key],k)).
   map(k=>k+"="+data[key][k]).join("\n")).join("\n\n")+"\n";
}
function parseRoster(raw){
 const out={bifrost:{},spawn:{},blocked:{}};
 if(!String(raw||"").trim()){LEGEND.forEach(x=>out.bifrost[x]=true);return out;}
 let group="bifrost";
 for(const text of String(raw).split(/\r?\n/)){
  const row=text.replace(/[;#].*$/,"").trim();
  const h=/^\[(bifrost|spawn|blocked)\]$/i.exec(row);
  if(h){group=h[1].toLowerCase();continue;}
  const pair=/^([a-z0-9_]+)\s*=\s*([01])$/i.exec(row);
  if(pair)out[group][pair[1].toUpperCase()]=pair[2]==="1";
 }
 return out;
}
function encodeRoster(data){
 return ["; Bifrost Capture Studio - roster\n",...["bifrost","spawn","blocked"].map(key=>
  "["+key+"]\n"+Object.keys(data[key]||{}).sort().map(x=>
    x+"="+(data[key][x]?"1":"0")).join("\n")+"\n")].join("\n");
}
class Studio{
 constructor(ctx,host){
  this.ctx=ctx;this.root=document.createElement("div");this.root.className="bf-root";
  const css=document.createElement("style");css.textContent=STYLES;
  host.replaceChildren(css,this.root);
  this.section="overview";this.scope="global";this.profile="bifrost";this.search="";
  this.cfg={global:{...D}};this.roster=parseRoster("");
  this.species=[...LEGEND];this.cleanConfig="";this.cleanRoster="";
  this.message="Leyendo configuración";this.saving=false;
  this.root.addEventListener("click",e=>this.click(e));
  this.root.addEventListener("change",e=>this.change(e));
  this.root.addEventListener("input",e=>this.input(e));
  this.render();this.load();
 }
 value(){return {...D,...this.cfg.global,...(this.cfg[this.scope]||{})};}
 dirty(){return encodeCfg(this.cfg)!==this.cleanConfig||
                       encodeRoster(this.roster)!==this.cleanRoster;}
 async load(){
  try{
   const fs=this.ctx.fs;
   const cfg=await fs.projectExists(CFG)?await fs.readProjectFile(CFG):"";
   const roster=await fs.projectExists(ROSTER)?await fs.readProjectFile(ROSTER):"";
   this.cfg=parseCfg(cfg);this.roster=parseRoster(roster);
   const species=new Set([...LEGEND,...Object.keys(this.roster.bifrost),
    ...Object.keys(this.roster.spawn),...Object.keys(this.roster.blocked)]);
   for(const path of POKEMON_FILES){
    try{
     if(!await fs.projectExists(path))continue;
     const text=await fs.readProjectFile(path);
     for(const match of String(text).matchAll(/^\[([A-Z][A-Z0-9_]+)\]\s*$/gm))species.add(match[1]);
    }catch(_){}
   }
   this.species=[...species].sort();
   this.profile=this.cfg.global.profile||"bifrost";
   this.cleanConfig=encodeCfg(this.cfg);this.cleanRoster=encodeRoster(this.roster);
   this.message="Archivos cargados. Cambios sin guardar: 0";
  }catch(e){this.message="Error de lectura: "+(e.message||e);}
  this.render();
 }
 async save(){
  if(this.saving)return;
  this.saving=true;this.render();
  try{
   const cfg=encodeCfg(this.cfg),roster=encodeRoster(this.roster),fs=this.ctx.fs;
   await fs.writeProjectFile(CFG,cfg);
   await fs.writeProjectFile(ROSTER,roster);
   if(await fs.readProjectFile(CFG)!==cfg||
      await fs.readProjectFile(ROSTER)!==roster)throw Error("Verificación de escritura fallida");
   this.cleanConfig=cfg;this.cleanRoster=roster;
   this.message="Guardado comprobado: config.ini y roster.ini";
  }catch(e){this.message="Fallo al guardar: "+(e.message||e);}
  this.saving=false;this.render();
 }
 panel(title,body){
  return '<section class="bf-panel"><div class="bf-panelhead"><strong>'+esc(title)+
   '</strong></div><div class="bf-panelbody">'+body+'</div></section>';
 }
 field(key){
  const meta=META[key];if(!meta)return "";
  const val=this.value()[key],label=meta[0],bool=["0","1"].includes(D[key]);
  let input="";
  if(CHOICES[key]||bool){
   const opts=CHOICES[key]||["1","0"];
   input='<select class="bf-select" data-field="'+key+'">'+opts.map(x=>
    '<option value="'+x+'"'+(val===x?' selected':'')+'>'+esc(T(x))+'</option>').join("")+'</select>';
  }else if(key.startsWith("sfx_")){
   input='<input class="bf-input" type="text" maxlength="60" data-field="'+key+'" placeholder="none / nombre_archivo" value="'+esc(val)+'">';
  }else{
   input='<input class="bf-input" type="number" data-field="'+key+'" min="'+(meta[2]??0)+
    '" max="'+(meta[3]??999)+'" value="'+esc(val)+'">';
  }
  return '<label class="bf-field"><span class="bf-field-name">'+esc(label)+
   (this.scope!=="global" ? '<span class="local">'+
   (this.cfg[this.scope]?.[key]!==undefined?"Local":"Heredado")+'</span>' : "")+
   '</span>'+input+'</label>';
 }
 inspector(){
  const section=this.section==="overview"?"general":this.section==="profiles"?"general":
    this.section==="tests"?"general":this.section==="scopes"?"general":this.section;
  return '<div class="bf-section-title">Parámetros de '+esc(section)+'</div>'+
   (GROUPS[section]||[]).map(key=>this.field(key)).join("")+
   '<div class="bf-divider"></div><p class="bf-help">Ámbito: '+esc(this.scope)+
   '. Los valores se guardan en el proyecto al pulsar Guardar, no automáticamente.</p>';
 }
 aimPreview(){
  const cfg=this.value();
  const range=Math.max(1,Number(cfg.range)||7),max=range+1;
  let html='<div class="bf-grid">';
  for(let y=1;y<=8;y++)for(let x=-3;x<=3;x++){
   const c=y>range?"void":y<=Number(cfg.optimal_range)?"opt":"far";
   html+='<div class="bf-tile '+c+'">'+(y===8?"×":"·")+'</div>';
  }
  return html+'</div><div class="bf-help">Simulación de las reglas internas 7×7. La cuadrícula no aparece durante el juego.</div>';
 }
 profiles(){
  const selected=PRESETS[this.profile]||PRESETS.bifrost;
  const changes=Object.keys(D).filter(k=>this.cfg.global[k]!==selected[k]);
  return '<h1 class="bf-headline">Perfiles comparables</h1><p class="bf-sub">Seleccionar no modifica el juego. Aplicar cambia solo el ámbito global; los ajustes específicos permanecen.</p>'+
   '<div class="bf-cards">'+Object.keys(PRESETS).map(p=>
    '<button class="bf-prof-card '+(p===this.profile?"active":"")+'" data-profile="'+p+'"><strong>'+
    esc(T(p))+'</strong><small>'+esc(PRESET_HELP[p])+'</small></button>').join("")+'</div>'+
   this.panel("Cambios propuestos: "+changes.length,
    '<table class="bf-diff"><thead><tr><th>Parámetro</th><th>Actual</th><th>Propuesto</th></tr></thead><tbody>'+
    changes.map(k=>'<tr><td>'+esc(META[k]?.[0]||k)+'</td><td>'+esc(T(this.cfg.global[k]))+
      '</td><td>'+esc(T(selected[k]))+'</td></tr>').join("")+'</tbody></table>'+
    '<button class="bf-btn primary" data-action="apply">Aplicar perfil</button>');
 }
 speciesPanel(){
  const species=this.species.filter(s=>s.includes(this.search.toUpperCase()));
  return '<h1 class="bf-headline">Catálogo de Pokémon</h1><p class="bf-sub">Bifröst restringe los OW manuales a su catálogo. En OW completo, los Pokémon naturales generados son capturables incluso con ese catálogo exclusivo. Los decorativos nunca se convierten automáticamente.</p>'+
   '<div class="bf-roster-head"><input class="bf-search" data-search placeholder="Buscar especie..." value="'+esc(this.search)+
   '"><input class="bf-input" data-species-new placeholder="ID de especie"><button class="bf-btn" data-action="add">Agregar</button></div>'+
   this.panel("Especies · "+species.length+' resultados',
    '<div class="bf-roster-row"><strong>Especie</strong><small>Bifröst</small><small>Aparecer</small><small>Editar</small></div>'+
    '<div class="bf-roster">'+species.slice(0,180).map(s=>
      '<div class="bf-roster-row"><div><b>'+esc(s)+'</b><small>'+
      (this.roster.blocked[s]?"Spawn bloqueado":"Registro")+'</small></div>'+
      '<div class="bf-roster-col"><input type="checkbox" data-roster="bifrost" data-species="'+s+'"'+
      (this.roster.bifrost[s]?" checked":"")+'></div>'+
      '<div class="bf-roster-col"><input type="checkbox" data-roster="spawn" data-species="'+s+'"'+
      (this.roster.spawn[s]?" checked":"")+'></div>'+
      '<button class="bf-mini-btn" data-edit="'+s+'">Editar</button></div>').join("")+'</div>'+
    '<div class="bf-actions"><input class="bf-input" data-block-name placeholder="Especie para bloquear"><button class="bf-btn" data-action="block">Bloquear/permitir spawn</button></div>');
 }
 scopesPanel(){
  return '<h1 class="bf-headline">Ámbitos de reglas</h1><p class="bf-sub">Puedes modificar el mapa, una especie o un evento sin alterar el resto del proyecto.</p>'+
   this.panel("Ámbitos existentes",Object.keys(this.cfg).sort().map(scope=>
    '<div class="bf-roster-row" style="grid-template-columns:1fr auto auto"><strong>'+
    esc(scope)+'</strong><button class="bf-mini-btn" data-scope-button="'+scope+
    '">Editar</button>'+(scope==="global"?"":'<button class="bf-mini-btn" data-del="'+scope+
    '">Eliminar</button>')+'</div>').join("")+
    '<div class="bf-actions"><input class="bf-input" data-new-scope placeholder="map:12 / species:RAIKOU / event:12:4"><button class="bf-btn" data-action="scope">Crear</button></div>');
 }
 stage(){
  const c=this.value();
  if(this.section==="profiles")return this.profiles();
  if(this.section==="species")return this.speciesPanel();
  if(this.section==="scopes")return this.scopesPanel();
  if(this.section==="aim")return '<h1 class="bf-headline">Apuntar sin detener la exploración</h1>'+
    '<p class="bf-sub">El jugador puede caminar durante la preparación, el vuelo y la captura. No existe una escena de apuntado que congele el mapa.</p>'+
    this.panel("Control dinámico",'<div class="bf-cards">'+[
    ["A / JUMPUP","Mantener para apuntar; soltar para lanzar"],
    ["Flechas / Pad","Caminar normalmente, también al apuntar"],
    ["Shift / Z (ACTION)","Cambiar Pokémon fijado"],
    ["Ratón","Apuntado libre sobre sprites en movimiento"],
    ["S / JUMPDOWN","Cambiar Poké Ball"],
    ["C / USE","Lanzar directamente"],
    ["D / SPECIAL","Cambiar Ball y Pokémon"],
    ["X / BACK","Cancelar sin lanzar"]].map(x=>'<div class="bf-stat"><span>'+
    esc(x[0])+'</span><strong>'+esc(x[1])+'</strong></div>').join("")+
    '</div><p class="bf-help">La retícula sigue a un OW válido y no consume las flechas; el modo toggle es opcional. La Ball y la captura se animan por fotograma, sin Graphics.update manuales.</p>')+
    this.panel("Rango y dirección",this.aimPreview());
  if(this.section==="spawns")return '<h1 class="bf-headline">Encuentros naturales OW</h1>'+
    '<p class="bf-sub">En modo completo, cada tirada natural terrestre intenta crear un Pokémon visible y capturable. El modo mixto convierte solo el porcentaje indicado.</p>'+
    '<div class="bf-cards">'+["classic","hybrid","overworld"].map(k=>
    '<button class="bf-prof-card '+(c.encounter_mode===k?"active":"")+
    '" data-mode="'+k+'"><strong>'+esc(T(k))+'</strong><small>'+
    (k==="overworld"?"Convierte la hierba en fauna visible":"Mantiene la ruta original")+
    '</small></button>').join("")+'</div>'+
    this.panel("Ritmo de apariciones",'<div class="bf-cards">'+[
      ["OW adicional / paso",c.ow_extra_spawn_chance+"%"],
      ["Enfriamiento",c.ow_extra_spawn_cooldown+" pasos"],
      ["Máximo en mapa",c.spawn_limit+" Pokémon"]
    ].map(x=>'<div class="bf-stat"><span>'+x[0]+'</span><strong>'+
      x[1]+'</strong></div>').join("")+'</div><p class="bf-help">El ratio adicional se evalúa aparte del encuentro tradicional. Usa las tablas PBS y solo genera OW con sprite, casilla libre y espacio en el mapa. En OW completo nunca fuerza un combate por falta de recursos.</p>');
  if(this.section==="behavior")return '<h1 class="bf-headline">Temperamentos OW</h1>'+
    '<p class="bf-sub">Cada individuo mantiene su temperamento desde que aparece. En Catálogo → Editar puedes definir una personalidad para toda una especie.</p>'+
    this.panel("Comportamiento y lectura visual",'<div class="bf-cards">'+[
      ["NEUTRO","Observa, puede alejarse brevemente después de una Ball fallida y vuelve a su rutina."],
      ["MIEDOSO","Detecta antes y huye por las casillas del mapa antes de desaparecer."],
      ["AGRESIVO","Persigue al entrenador y puede iniciar un combate con bonificación configurable."]
    ].map((item,i)=>'<div class="bf-stat bf-mood-'+i+'"><span>'+item[0]+
      '</span><strong>'+item[1]+'</strong></div>').join("")+'</div>'+
      '<p class="bf-help">Los pesos de cada temperamento se normalizan automáticamente; no necesitan sumar 100. Los ajustes locales de especie prevalecen sobre los del mapa y el perfil.</p>');
  if(this.section==="audio")return '<h1 class="bf-headline">Audio de captura y comportamiento</h1>'+
    '<p class="bf-sub">Cada evento dispone de un SFX propio y reemplazable, sin detener la exploración.</p>'+
    this.panel("Pistas de diseño",'<div class="bf-cards">'+[
      ["PREPARACIÓN","Apuntar, cambiar Ball, fijar objetivo"],
      ["LANZAMIENTO","Salida, impacto y sacudidas"],
      ["REACCIÓN","Captura, liberación, huida y alerta agresiva"]
    ].map(item=>'<div class="bf-stat"><span>'+item[0]+'</span><strong>'+
      item[1]+'</strong></div>').join("")+'</div><p class="bf-help">Coloca archivos .ogg o .wav autorizados en Audio/SE/Bifrost/ y escribe solo el nombre, sin extensión. «none» usa sonidos vanilla cuando el modo sea Essentials; en Original guarda silencio para ese evento. No se incluye audio extraído de otros juegos.</p>');
  if(this.section==="capture")return '<h1 class="bf-headline">Captura inmediata</h1>'+
    this.panel("Condiciones",'<p class="bf-help">El impacto y el resultado de captura son dos comprobaciones independientes. Puedes ajustar la distancia, los críticos por espalda, el multiplicador instantáneo y los intentos máximos.</p>');
  if(this.section==="tests")return '<h1 class="bf-headline">Validación e integración</h1>'+
   this.panel("Qué comprobar en el juego",'<div class="bf-help">1. Entrar en la hierba del mapa con OW completo.<p>2. Aparece un Pokémon visible y capturable.</p><p>3. A prepara, flechas mueven y C lanza.</p><p>4. Captura se guarda en equipo/caja.</p><p>5. Al fallar, la criatura huye visiblemente.</p><p>6. Vuelve a recorrer el mapa con Visual 2.5D y Turbo.</p><p>Los tests de Ruby/JavaScript no equivalen a ejecutar mkxp.</p></div>');
  return '<h1 class="bf-headline">Bifröst Capture Studio 1.0</h1>'+
   '<p class="bf-sub">Motor reconstruido: cada encuentro natural convertido a OW es la misma entidad utilizada para apuntar, lanzar, capturar y huir.</p>'+
   '<div class="bf-cards">'+[["Perfil",T(c.profile)],["Acceso",T(c.access_mode)],
    ["Encuentros",T(c.encounter_mode)],["Control",T(c.control_mode)]].map(x=>
    '<div class="bf-stat"><span>'+esc(x[0])+'</span><strong>'+esc(x[1])+
    '</strong></div>').join("")+'</div>'+
   this.panel("Siguiente paso",'<p class="bf-help">Configura OW completo desde Perfiles para permitir capturar fauna natural del mapa, o conserva Bifröst para los legendarios autorizados.</p>');
 }
 render(){
  const dirty=this.dirty();
  this.root.innerHTML='<header class="bf-top"><div class="bf-logo">◈</div>'+
   '<div class="bf-brand"><strong>Bifröst Capture Studio</strong><small>Essentials 21.1 · Bifröst 0.8</small></div>'+
   '<div class="bf-spacer"></div><select class="bf-scope" data-scope>'+
   Object.keys(this.cfg).sort().map(k=>'<option value="'+esc(k)+'"'+
   (k===this.scope?" selected":"")+'>'+esc(k)+'</option>').join("")+'</select>'+
   '<button class="bf-btn" data-action="scopes">+ Ámbito</button>'+
   '<span class="bf-pill '+(dirty?"dirty":"on")+'">'+
   (dirty?"● Sin guardar":"✓ Guardado")+'</span>'+
   '<button class="bf-btn" data-action="reload">Recargar</button>'+
   '<button class="bf-btn primary" data-action="save"'+
   (this.saving?" disabled":"")+'>Guardar cambios</button></header>'+
   '<div class="bf-workspace"><aside class="bf-side"><div class="bf-sidehead"><div class="bf-overline">MÓDULOS</div></div>'+
   '<nav class="bf-nav">'+NAV.map(x=>'<button class="'+
    (this.section===x[0]?"active":"")+'" data-section="'+x[0]+
    '"><span class="ico">'+x[1]+'</span><span class="label">'+x[2]+
    '</span></button>').join("")+'</nav></aside>'+
   '<main class="bf-stage"><div class="bf-stagebar"><strong>'+
   esc(NAV.find(x=>x[0]===this.section)?.[2]||"Resumen")+
   '</strong><span class="bf-tag">'+esc(this.scope)+'</span></div>'+
   '<div class="bf-stagebody">'+this.stage()+'</div></main>'+
   '<aside class="bf-inspector"><div class="bf-inspector-head"><div class="bf-overline">INSPECTOR</div>'+
   '<strong>Parámetros</strong><small>Edición contextual por ámbito</small></div>'+
   '<div class="bf-inspector-body">'+this.inspector()+'</div></aside></div>'+
   '<footer class="bf-foot"><span>'+esc(this.message)+'</span><span class="bf-path">'+
   esc(CFG)+'</span></footer>';
 }
 change(e){
  const n=e.target;
  if(n.matches("[data-scope]")){this.scope=n.value;this.render();return;}
  const key=n.getAttribute("data-field");
  if(key&&META[key]){
   if(key.startsWith("sfx_")&&!/^(none|[a-z0-9_]{1,60})$/i.test(n.value)){
    this.message="SFX inválido: solo letras, números y guion bajo, sin extensión.";
    this.render();return;
   }
   if(META[key].length>2){
    const x=Number(n.value),min=META[key][2],max=META[key][3];
    if(!Number.isInteger(x)||x<min||x>max){this.message="Valor fuera de rango: "+key;this.render();return;}
   }
   this.cfg[this.scope]??={};this.cfg[this.scope][key]=n.value;this.render();return;
  }
  const cat=n.getAttribute("data-roster"),species=n.getAttribute("data-species");
  if(cat&&species){this.roster[cat][species]=!!n.checked;this.render();}
 }
 input(e){
  if(!e.target.hasAttribute("data-search"))return;
  this.search=e.target.value.toUpperCase();
  const pos=e.target.selectionStart;
  this.render();
  const input=this.root.querySelector("[data-search]");
  if(input){input.focus();input.setSelectionRange(pos,pos);}
 }
 click(e){
  const node=e.target.closest("button");if(!node)return;
  const nav=node.getAttribute("data-section");
  if(nav){this.section=nav;this.render();return;}
  const profile=node.getAttribute("data-profile");
  if(profile){this.profile=profile;this.render();return;}
  const mode=node.getAttribute("data-mode");
  if(mode){this.cfg[this.scope]??={};this.cfg[this.scope].encounter_mode=mode;this.render();return;}
  const scope=node.getAttribute("data-scope-button");
  if(scope){this.scope=scope;this.render();return;}
  const remove=node.getAttribute("data-del");
  if(remove){delete this.cfg[remove];if(this.scope===remove)this.scope="global";this.render();return;}
  const edit=node.getAttribute("data-edit");
  if(edit){this.scope="species:"+edit.toLowerCase();this.cfg[this.scope]??={};this.section="spawns";this.render();return;}
  const action=node.getAttribute("data-action");
  if(action==="save"){this.save();return;}
  if(action==="reload"){if(this.dirty()&&!this.confirmReload){this.confirmReload=true;this.message="Pulsa Recargar otra vez para descartar cambios.";this.render();return;}this.confirmReload=false;this.load();return;}
  if(action==="apply"){this.cfg.global={...PRESETS[this.profile]};this.scope="global";this.message="Perfil aplicado localmente; guarda los cambios.";this.render();return;}
  if(action==="scopes"){this.section="scopes";this.render();return;}
  if(action==="scope"){
   const value=this.root.querySelector("[data-new-scope]")?.value.toLowerCase().trim();
   if(!/^(map:\d+|species:[a-z0-9_]+|event:\d+:\d+)$/.test(value||"")){this.message="Ámbito inválido.";this.render();return;}
   this.cfg[value]??={};this.scope=value;this.render();return;
  }
  if(action==="add"||action==="block"){
   const el=this.root.querySelector(action==="add"?"[data-species-new]":"[data-block-name]");
   const id=(el?.value||"").toUpperCase().trim();
   if(!/^[A-Z][A-Z0-9_]{1,40}$/.test(id)){this.message="ID Pokémon inválido";this.render();return;}
   if(!this.species.includes(id))this.species.push(id);
   this.species.sort();this.search=id;
   if(action==="block")this.roster.blocked[id]=!this.roster.blocked[id];
   this.render();
  }
 }
}
export function activate(ctx){
 const id="vermeil.bifrost-capture";
 ctx.ui.registerPanel({id,title:"Bifröst Capture Studio",icon:"target",
 defaultPosition:"right",defaultSize:{width:1450,height:860},
 showInMenu:!(ctx.menu&&ctx.menu.registerMenuItem),
 render(host){return new Studio(ctx,host)}});
 if(ctx.menu?.registerMenuItem)ctx.menu.registerMenuItem({
 menu:"Mods",label:"Bifröst Capture Studio",icon:"target",
 handler(){return ctx.ui.openPanel(id)}});
 if(ctx.commands?.register)ctx.commands.register(
 "vermeil.bifrost-capture.open",()=>ctx.ui.openPanel(id));
}
