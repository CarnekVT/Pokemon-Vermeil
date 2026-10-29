import { STYLES } from "./styles.js";

const CONFIG_PATH="Plugins/[VERMEIL] Bifrost Capture/config.ini";
const ROSTER_PATH="Plugins/[VERMEIL] Bifrost Capture/roster.ini";
const POKEDEX_FILES=["PBS/pokemon.txt","PBS/pokemon_Vermeil.txt"];
const OFFICIAL="RAIKOU SUICUNE ENTEI LATIAS LATIOS ARTICUNO ZAPDOS MOLTRES MESPRIT UXIE AZELF COBALION VIRIZION TERRAKION GENESECT LANDORUS THUNDURUS TORNADUS ETERNATUS TAPUKOKO TAPULELE TAPUBULU TAPUFINI".split(" ");
const DEFS={
 profile:"bifrost",enabled:"1",access_mode:"event",hotkey:"aux2",
 capture_enabled:"1",battle_enabled:"1",restricted_species:"1",
 range:"7",width:"7",optimal_range:"4",alert_distance:"3",
 hit_near:"96",hit_far:"60",capture_floor:"10",back_multiplier:"175",
 critical_front:"3",critical_back:"35",critical_multiplier:"250",
 line_of_sight:"1",reaction:"flee",consume_on_miss:"1",impact_frames:"3",
 encounter_mode:"classic",spawn_chance:"24",spawn_min_distance:"3",
 spawn_max_distance:"6",spawn_limit:"4",spawn_lifetime:"40",
 spawn_filter:"all",spawn_grass_only:"1",spawn_allow_fishing:"0",
 ow_form:"0",ow_min_level:"0",ow_max_level:"0",ow_spawn_probability:"100"
};
const PRESETS={
 bifrost:{...DEFS},
 classic:{...DEFS,profile:"classic",capture_enabled:"0"},
 adventure:{...DEFS,profile:"adventure",restricted_species:"0",reaction:"attack"},
 safari:{...DEFS,profile:"safari",restricted_species:"0",battle_enabled:"0"},
 full_ow:{...DEFS,profile:"full_ow",restricted_species:"0",access_mode:"always",encounter_mode:"overworld"},
 custom:{...DEFS,profile:"custom"}
};
const PROFILE_INFO={
 bifrost:["Configuración Bifröst","Captura OW exclusiva para su catálogo de legendarios. Hierba tradicional."],
 classic:["Clásico","Desactiva captura directa; mantiene combates OW voluntarios."],
 adventure:["Aventura","Permite especies adicionales marcadas como eventos y reacciones de ataque."],
 safari:["Safari","Lanzamiento directo y huida; sin opción de iniciar combate OW."],
 full_ow:["OW completo","Los encuentros naturales de terreno aparecen como Pokémon visibles. Sin combate aleatorio de hierba."],
 custom:["Personalizado","Parte de los valores iniciales y permite afinar cada parámetro."]
};
const FIELDS={
 profile:["Perfil activo","system","select",Object.keys(PRESETS),"La configuración Bifröst conserva sus reglas originales salvo cambios expresos."],
 enabled:["Motor de captura","system","bool",null,"Activa o desactiva completamente Bifröst."],
 access_mode:["Disponibilidad de lanzamiento","system","select",["event","always","nearby"],"Siempre disponible: R/L abre apuntado incluso sin Pokémon delante."],
 hotkey:["Atajo de apuntado","system","select",["aux2","aux1","none"],"Aux2 es R y Aux1 es L en Vermeil. No sobrescribe el menú Ready."],
 capture_enabled:["Captura en el mapa","system","bool",null,"Permite usar Balls fuera del combate."],
 battle_enabled:["Desafiar con Pokémon","system","bool",null,"Habilita enviar Pokémon para iniciar combate tradicional."],
 restricted_species:["Restringir a catálogo Bifröst","system","bool",null,"Si está activo, solo se aceptan especies marcadas en Catálogo."],
 encounter_mode:["Sistema de encuentros","spawns","select",["classic","hybrid","overworld"],"Clásico: encuentros al azar. Mixto: OW + clásicos. Completo: solo OW en terreno."],
 spawn_chance:["Probabilidad de aparición por paso (%)","spawns","int",[0,100],"Intentos de aparición por paso elegible, no tasa de captura."],
 spawn_min_distance:["Distancia mínima de aparición","spawns","int",[1,12],"Distancia Manhattan respecto al jugador."],
 spawn_max_distance:["Distancia máxima de aparición","spawns","int",[1,16],"El encuentro sale de una casilla de terreno permitida."],
 spawn_limit:["Límite de OW simultáneos","spawns","int",[1,20],"Evita poblar demasiados eventos nuevos."],
 spawn_lifetime:["Duración en pasos","spawns","int",[0,999],"Cero mantiene los OW hasta salir del mapa; otros valores los despueblan."],
 spawn_filter:["Filtro de especies para apariciones","spawns","select",["all","allowlist"],"Todas las especies de las tablas del mapa o solo las marcadas en Catálogo."],
 spawn_grass_only:["Solo casillas de hierba","spawns","bool",null,"Sin esta regla permite otros tiles transitables de encuentros terrestres."],
 spawn_allow_fishing:["Incluir encuentros de pesca","spawns","bool",null,"Reservado para fase posterior. Actualmente no modifica la pesca."],
 ow_form:["Forma OW (0 = normal)","species","int",[0,100],"Forma 1 de Articuno, Zapdos y Moltres: Galar. Solo afecta a spawns automáticos."],
 ow_min_level:["Nivel mínimo OW (0 = tabla PBS)","species","int",[0,100],"Nivel para generados en la hierba. Con 0 se utiliza el encuentro original."],
 ow_max_level:["Nivel máximo OW (0 = tabla PBS)","species","int",[0,100],"Permite escoger un nivel aleatorio en el rango definido."],
 ow_spawn_probability:["Probabilidad de spawn de especie (%)","species","int",[0,100],"Filtro individual después de elegir la especie de la tabla del mapa."],
 range:["Alcance de lanzamiento (filas)","aim","int",[1,20],"Máximo alcance en línea frontal; fuera de este rango la Ball falla."],
 width:["Anchura de lanzamiento (columnas)","aim","odd",[1,19],"Número impar de columnas centradas respecto a la dirección."],
 optimal_range:["Distancia óptima","aim","int",[1,20],"Máximo acierto antes de penalización por distancia."],
 hit_near:["Precisión cercana (%)","aim","int",[0,100],"Probabilidad de que la Ball acierte al Pokémon en distancia óptima."],
 hit_far:["Precisión lejana (%)","aim","int",[0,100],"Precisión en el extremo del alcance."],
 line_of_sight:["Obstáculos bloquean","aim","bool",null,"Comprobación parcial de eventos intermedios; faltan muros 2.5D."],
 capture_floor:["Captura base mínima (%)","capture","int",[0,100],"Valor de captura inicial mínimo; debe equilibrarse con las tasas de especie."],
 back_multiplier:["Multiplicador por espalda (%)","capture","int",[100,500],"175 significa un factor 1,75 sobre el cálculo básico."],
 critical_front:["Crítica frontal (%)","capture","int",[0,100],"Probabilidad de marcar una captura crítica al frente."],
 critical_back:["Crítica por espalda (%)","capture","int",[0,100],"Mayor cuando el objetivo mira hacia otro lado."],
 critical_multiplier:["Multiplicador crítico (%)","capture","int",[100,600],"Bonificación a la tasa cuando el resultado es crítico."],
 consume_on_miss:["Consumir Balls fallidas","capture","bool",null,"Se aplica al fallar un lanzamiento con la configuración inicial."],
 reaction:["Comportamiento de alerta","behavior","select",["flee","attack","ignore"],"Huir, atacar iniciando combate o ignorar."],
 alert_distance:["Radio de alarma (casillas)","behavior","int",[0,20],"A 3 casillas o menos el OW reacciona; 0 desactiva alarma."],
 impact_frames:["Flash de impacto (fotogramas)","behavior","int",[0,12],"Efecto básico de impacto por espalda; falta proyectil real."]
};
const SECTIONS=[
 ["overview","◈","Vista general","Motor, acceso y salud del sistema"],
 ["profiles","▤","Perfiles","Comparación antes de aplicar"],
 ["species","◇","Catálogo Pokémon","Elegibilidad y reglas por especie"],
 ["spawns","☷","Encuentros OW","Hierba alta, aparición y densidad"],
 ["aim","⊕","Lanzamiento","Alcance, puntería y colisiones"],
 ["capture","◉","Captura","Balls, críticos y bonificaciones"],
 ["behavior","⚑","Comportamiento","Huida, ataque e impacto"],
 ["scopes","▦","Ámbitos","Global, mapa, especie y evento"],
 ["tests","⌁","Diagnóstico","Pruebas pendientes y límites"]
];
const E=s=>String(s==null?"":s).replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
function parseConfig(text){
 const out={global:{...DEFS}};let scope="global";
 for(const raw of String(text||"").split(/\r?\n/)){
  const line=raw.replace(/[;#].*$/,"").trim();
  const h=/^\[(global|map:\d+|species:[a-z0-9_]+|event:\d+:\d+)\]$/i.exec(line);
  if(h){scope=h[1].toLowerCase();out[scope]??={};continue}
  const p=/^([a-z_]+)\s*=\s*([a-z0-9_]+)$/i.exec(line);
  if(p&&Object.hasOwn(DEFS,p[1].toLowerCase()))out[scope][p[1].toLowerCase()]=p[2].toLowerCase();
 }
 return out;
}
function serializeConfig(obj){
 const names=["global",...Object.keys(obj).filter(x=>x!=="global").sort()];
 const rows=["; Bifröst Capture Studio · configuracion verificada por ambitos",""];
 for(const scope of names){
  rows.push("["+scope+"]");
  const values=obj[scope]||{};
  for(const key of Object.keys(DEFS))if(Object.hasOwn(values,key))rows.push(key+"="+values[key]);
  rows.push("");
 }
 return rows.join("\n");
}
function parseRoster(text){
 const result={bifrost:{},spawn:{},blocked:{}};
 OFFICIAL.forEach(x=>result.bifrost[x]=true);
 if(!String(text||"").trim())return result;
 // Si el archivo existe, la lista es explicita, no una extension de la oficial.
 result.bifrost={};let section="bifrost";
 for(const raw of String(text).split(/\r?\n/)){
  const line=raw.replace(/[;#].*$/,"").trim();
  const head=/^\[(bifrost|spawn|blocked)\]$/i.exec(line);
  if(head){section=head[1].toLowerCase();continue;}
  const pair=/^([A-Z0-9_]+)\s*=\s*([01])$/i.exec(line);
  if(pair)result[section][pair[1].toUpperCase()]=pair[2]==="1";
 }
 return result;
}
function serializeRoster(obj){
 const lines=["; Bifröst Capture Studio · catálogo editable","; [bifrost] capturables en perfil restringido","; [spawn] candidatos al filtro allowlist","; [blocked] excluidos de la fauna generada",""];
 for(const s of ["bifrost","spawn","blocked"]){
  lines.push("["+s+"]");
  for(const name of Object.keys(obj[s]||{}).sort())lines.push(name+"="+(obj[s][name]?"1":"0"));
  lines.push("");
 }
 return lines.join("\n");
}
function parseSpeciesPBS(text){
 const ids=[];
 for(const line of String(text||"").split(/\r?\n/)){
  const m=/^\[([A-Z][A-Z0-9_]+)\]\s*$/.exec(line.trim());
  if(m)ids.push(m[1]);
 }
 return ids;
}
const LABELS={
 "1":"Activado","0":"Desactivado",event:"Solo desde evento",always:"En todo momento",nearby:"Con OW cercano",
 aux2:"R · Aux2",aux1:"L · Aux1",none:"Sin atajo",
 classic:"Encuentros clásicos",hybrid:"Mixto · aleatorio + OW",
 overworld:"OW completo · sin combate aleatorio",all:"Todas las especies del encuentro",
 allowlist:"Solo lista autorizada",flee:"Huir",attack:"Atacar",ignore:"Ignorar",
 bifrost:"Bifröst",full_ow:"OW completo",adventure:"Aventura",safari:"Safari",custom:"Personalizado"
};
const label=v=>LABELS[String(v)]||String(v);
class CaptureStudio{
 constructor(ctx,host){
  this.ctx=ctx;this.host=host;this.section="overview";this.scope="global";
  this.selectedProfile="bifrost";this.aimF=4;this.aimS=0;this.search="";
  this.newScope="";this.activeTab="bifrost";this.roster={bifrost:{},spawn:{},blocked:{}};
  this.config={global:{...DEFS}};this.species=[...OFFICIAL];this.ready=false;this.saving=false;
  this.status="Cargando configuración";this.baselineConfig="";this.baselineRoster="";
  this.resetConfirm=false;
  this.root=document.createElement("div");this.root.className="bf-root";
  this.style=document.createElement("style");this.style.textContent=STYLES;
  host.replaceChildren(this.style,this.root);
  this.root.addEventListener("click",e=>this.click(e));
  this.root.addEventListener("change",e=>this.change(e));
  this.root.addEventListener("input",e=>this.input(e));
  this.render();this.load();
 }
 async load(){
  try{
   const fs=this.ctx.fs;
   let cfg="",roster="";
   if(await fs.projectExists(CONFIG_PATH))cfg=await fs.readProjectFile(CONFIG_PATH);
   if(await fs.projectExists(ROSTER_PATH))roster=await fs.readProjectFile(ROSTER_PATH);
   this.config=parseConfig(cfg);this.roster=parseRoster(roster);
   this.selectedProfile=this.config.global.profile||"bifrost";
   this.species=[...OFFICIAL];
   for(const path of POKEDEX_FILES)try{
    if(await fs.projectExists(path)){
     const txt=await fs.readProjectFile(path);
     this.species.push(...parseSpeciesPBS(txt));
    }
   }catch(_){}
   this.species.push(...Object.keys(this.roster.bifrost),...Object.keys(this.roster.spawn),...Object.keys(this.roster.blocked));
   this.species=[...new Set(this.species)].sort();
   this.baselineConfig=serializeConfig(this.config);
   this.baselineRoster=serializeRoster(this.roster);
   this.ready=true;this.resetConfirm=false;this.status="Archivos cargados";
  }catch(err){this.ready=true;this.status="Error al leer: "+(err.message||err)}
  this.render();
 }
 dirty(){
  return serializeConfig(this.config)!==this.baselineConfig||serializeRoster(this.roster)!==this.baselineRoster;
 }
 values(){
  const g={...DEFS,...this.config.global};
  if(this.scope==="global")return g;
  return {...g,...(this.config[this.scope]||{})};
 }
 sectionInfo(){return SECTIONS.find(s=>s[0]===this.section)||SECTIONS[0]}
 panel(title,body,extra=""){
  return '<section class="bf-panel"><div class="bf-panelhead"><strong>'+E(title)+'</strong>'+extra+'</div><div class="bf-panelbody">'+body+'</div></section>';
 }
 field(key){
  const def=FIELDS[key],v=this.values()[key],local=this.config[this.scope]||{};
  if(!def)return "";
  let control="";
  if(def[2]==="select"||def[2]==="bool"){
   const opts=def[2]==="bool"?["1","0"]:def[3];
   control='<select class="bf-select" data-field="'+key+'">'+opts.map(id=>
    '<option value="'+E(id)+'"'+(id===v?' selected':'')+'>'+E(label(id))+'</option>').join("")+'</select>';
  }else{
   control='<input class="bf-input" data-field="'+key+'" type="number" min="'+def[3][0]+'" max="'+def[3][1]+'" step="'+(def[2]==="odd"?"2":"1")+'" value="'+E(v)+'">';
  }
  const own=Object.hasOwn(local,key);
  return '<label class="bf-field"><span class="bf-field-name">'+E(def[0])+
   (this.scope!=="global"?'<span class="local">'+(own?"Local":"Heredado")+'</span>':"")+
   '</span>'+control+'<small>'+E(def[4])+'</small></label>';
 }
 fieldsFor(section){
  const explicit={
   overview:["enabled","access_mode","hotkey","capture_enabled","battle_enabled"],
   profiles:["profile","access_mode","restricted_species"],
   species:["ow_form","ow_min_level","ow_max_level","ow_spawn_probability","reaction","alert_distance","capture_floor","restricted_species","spawn_filter"],
   spawns:["encounter_mode","spawn_chance","spawn_min_distance","spawn_max_distance","spawn_limit","spawn_lifetime","spawn_grass_only","spawn_filter"],
   aim:["range","width","optimal_range","hit_near","hit_far","line_of_sight"],
   capture:["capture_floor","back_multiplier","critical_front","critical_back","critical_multiplier","consume_on_miss"],
   behavior:["reaction","alert_distance","impact_frames"],
   scopes:["enabled","access_mode","encounter_mode","restricted_species"],
   tests:["access_mode","hotkey","encounter_mode"]
  };
  return explicit[section]||explicit.overview;
 }
 nav(){
  return '<aside class="bf-side"><div class="bf-sidehead"><div class="bf-overline">MÓDULOS</div><div class="bf-help" style="margin-top:5px">Editor de mecánicas OW</div></div>'+
   '<nav class="bf-nav">'+SECTIONS.map(s=>'<button data-section="'+s[0]+'" title="'+E(s[2])+'" class="'+(this.section===s[0]?"active":"")+'"><span class="ico">'+s[1]+'</span><span class="label">'+E(s[2])+'</span></button>').join("")+'</nav>'+
   '<div class="bf-sidefoot">Bifröst Capture Studio v0.2<br>Essentials 21.1 · Proyecto Vermeil</div></aside>';
 }
 render(){
  const v=this.values(), info=this.sectionInfo(),dirty=this.dirty();
  this.root.innerHTML='<header class="bf-top"><div class="bf-logo">⊕</div><div class="bf-brand"><strong>Bifröst Capture Studio</strong><small>Overworld · Mecánicas y comportamiento</small></div>'+
   '<span class="bf-pill on">Essentials 21.1</span><div class="bf-spacer"></div>'+
   '<select class="bf-scope" data-scope aria-label="Ámbito">'+Object.keys(this.config).sort((a,b)=>a==="global"?-1:b==="global"?1:a.localeCompare(b)).map(scope=>
    '<option value="'+E(scope)+'"'+(scope===this.scope?" selected":"")+'>'+E(scope)+'</option>').join("")+'</select>'+
   '<button class="bf-btn ghost" data-action="new-scope">+ Ámbito</button>'+
   '<span class="bf-pill '+(dirty?"dirty":"")+'">'+(dirty?"● Sin guardar":"✓ Guardado")+'</span>'+
   '<button class="bf-btn" data-action="reload">Recargar</button>'+
   '<button class="bf-btn primary" data-action="save"'+(this.saving?" disabled":"")+'>Guardar cambios</button></header>'+
   '<div class="bf-workspace">'+this.nav()+
   '<main class="bf-stage"><div class="bf-stagebar"><strong>'+E(info[2])+'</strong><span class="bf-tag">'+E(this.scope)+'</span><div class="bf-spacer"></div><span class="bf-help">'+E(info[3])+'</span></div>'+
   '<div class="bf-stagebody">'+this.stage(v)+'</div></main>'+
   '<aside class="bf-inspector"><div class="bf-inspector-head"><div class="bf-overline">INSPECTOR</div><strong>'+E(info[2])+'</strong><small>'+E(info[3])+' · Los cambios requieren pulsar Guardar.</small></div>'+
   '<div class="bf-inspector-body">'+this.inspector()+'</div></aside></div>'+
   '<footer class="bf-foot"><span class="'+(dirty?"bf-dirty":"")+'">'+E(this.status)+'</span>'+
   '<span class="bf-path">'+E(CONFIG_PATH)+(dirty?" · pendiente":"")+'</span></footer>';
 }
 stage(v){
  switch(this.section){
   case "profiles":return this.profiles();
   case "species":return this.speciesPanel();
   case "spawns":return this.spawnsPanel(v);
   case "aim":return this.aimPanel(v);
   case "capture":return this.capturePanel(v);
   case "behavior":return this.behaviorPanel(v);
   case "scopes":return this.scopesPanel();
   case "tests":return this.testsPanel();
   default:return this.overviewPanel(v);
  }
 }
 overviewPanel(v){
  const mode=label(v.encounter_mode),can=label(v.access_mode);
  return '<div class="bf-kicker">Proyecto · Bifröst</div><h1 class="bf-headline">Diseña los encuentros, no solo los números.</h1>'+
   '<p class="bf-sub">Controla cómo aparecen los Pokémon, cuáles se pueden capturar, cómo responde un objetivo y qué reglas cambian entre perfiles. El runtime y el editor comparten los mismos archivos.</p>'+
   '<div class="bf-cards">'+[
    ["PERFIL ACTIVO",label(v.profile),"Presets editables"],
    ["ACCESO AL APUNTADO",can,"Evento / R / L"],
    ["ENCUENTROS",mode,"Motor por mapa"],
    ["CATÁLOGO BIFRÖST",Object.keys(this.roster.bifrost).filter(x=>this.roster.bifrost[x]).length+" especies","Lista modificable"]
   ].map(x=>'<div class="bf-stat"><span>'+E(x[0])+'</span><strong>'+E(x[1])+'</strong><small>'+E(x[2])+'</small></div>').join("")+'</div>'+
   this.panel("Escenario de captura · representación de reglas",this.preview(v))+
   this.panel("Flujo de juego",'<div class="bf-cards">'+[
    ["01 · APARICIÓN",v.encounter_mode==="overworld"?"OW de hierba":"Encuentro original","Tablas PBS del mapa"],
    ["02 · INTERACCIÓN","Lanzar o desafiar","Respeta la lista de especies"],
    ["03 · REACCIÓN",label(v.reaction),"Alerta desde "+v.alert_distance+" casillas"]
   ].map(x=>'<div class="bf-stat"><span>'+E(x[0])+'</span><strong>'+E(x[1])+'</strong><small>'+E(x[2])+'</small></div>').join("")+'</div>');
 }
 preview(v){
  const rows=7,cols=7,half=3,range=Math.max(1,Number(v.range)||7),opt=Number(v.optimal_range)||4;
  let tiles="";
  for(let f=1;f<=rows;f++){
   for(let s=-half;s<=half;s++){
    const active=f===this.aimF&&s===this.aimS;
    const kind=f>range?"void":f<=opt?"opt":"far";
    tiles+='<button class="bf-tile '+kind+(active?" selected":"")+'" data-forward="'+f+'" data-side="'+s+'" title="Fila '+f+', lateral '+s+'">'+(active?"⊕":f>range?"×":"·")+'</button>';
   }
  }
  const dist=Math.min(this.aimF,range),near=Number(v.hit_near)||0,far=Number(v.hit_far)||0;
  const t=Math.max(0,dist-opt)/Math.max(1,range-opt);
  const hit=this.aimF>range?0:Math.round(near+(far-near)*t);
  return '<div class="bf-preview-wrap"><div class="bf-grid">'+tiles+'</div>'+
   '<div class="bf-preview-info"><strong>Simulación de apuntado</strong>'+
   '<div>Fila <b>'+this.aimF+'</b> · Desplazamiento <b>'+this.aimS+'</b></div>'+
   '<div><span class="bf-swatch" style="background:#6d977d"></span>Zona óptima</div>'+
   '<div><span class="bf-swatch" style="background:#526580"></span>Zona lejana</div>'+
   '<div><span class="bf-swatch" style="background:#7c5059"></span>Fuera de alcance</div>'+
   '<div class="bf-divider"></div><strong>'+hit+'% precisión</strong>'+
   '<span class="bf-help">Previsualización de cálculos. El juego comprueba además objetivo válido y obstáculos.</span>'+
   '<div class="bf-tag">Haz clic en una casilla</div></div></div>';
 }
 profiles(){
  const current=this.config.global, target=PRESETS[this.selectedProfile]||PRESETS.bifrost;
  const changes=Object.keys(DEFS).filter(k=>current[k]!==target[k]);
  return '<div class="bf-kicker">PERFILES DE PROYECTO</div><h1 class="bf-headline">Compara antes de aplicar</h1>'+
   '<p class="bf-sub">Seleccionar una tarjeta no cambia tu proyecto. Revisa abajo qué parámetros se modificarán y pulsa Aplicar perfil cuando lo decidas. Las sobrescrituras por mapa y especie se conservan.</p>'+
   '<div class="bf-cards">'+Object.keys(PRESETS).map(k=>'<button class="bf-prof-card '+(this.selectedProfile===k?"active":"")+'" data-profile="'+k+'"><strong>'+E(PROFILE_INFO[k][0])+'</strong><small>'+E(PROFILE_INFO[k][1])+'</small><small>'+E(k===this.selectedProfile?"SELECCIONADO · VER DIFERENCIAS":"VER DIFERENCIAS")+'</small></button>').join("")+'</div>'+
   this.panel("Comparativa · "+PROFILE_INFO[this.selectedProfile][0],
    '<div class="bf-help">Ajustes distintos respecto al perfil global actual: '+changes.length+'</div>'+
    (changes.length?'<table class="bf-diff"><thead><tr><th>PARÁMETRO</th><th>ACTUAL</th><th>PROPUESTO</th></tr></thead><tbody>'+
     changes.map(k=>'<tr><td>'+E(FIELDS[k]?.[0]||k)+'</td><td class="current">'+E(label(current[k]))+'</td><td class="proposed">'+E(label(target[k]))+'</td></tr>').join("")+'</tbody></table>':
     '<div class="bf-empty">Este perfil coincide con la configuración global actual.</div>')+
    '<div class="bf-actions"><button class="bf-btn primary" data-action="apply-profile">Aplicar perfil seleccionado</button><span class="bf-help">Requiere guardar después.</span></div>');
 }
 speciesPanel(){
  let all=this.species.filter(x=>x.includes(this.search.toUpperCase())).slice(0,150);
  const total=this.species.filter(x=>x.includes(this.search.toUpperCase())).length;
  return '<div class="bf-kicker">CATÁLOGO Y PERMISOS</div><h1 class="bf-headline">Configura tus Pokémon.</h1>'+
   '<p class="bf-sub">Marca qué especies admite el perfil Bifröst, cuáles pueden aparecer al utilizar una lista de fauna y cuáles quedan excluidas de las apariciones naturales. Haz clic en Editar para dar reglas propias a una especie.</p>'+
   '<div class="bf-roster-head"><input class="bf-search" data-search placeholder="Buscar especie o ID (ej.: RAIKOU, PIKACHU)" value="'+E(this.search)+'">'+
   '<input class="bf-input" data-add-species placeholder="Agregar ID Pokémon" style="width:155px"><button class="bf-btn" data-action="add-species">+ Agregar</button>'+
   '<span class="bf-tag">'+total+' resultados</span></div>'+
   this.panel("Especies del proyecto · "+all.length+" visibles",
    '<div class="bf-roster-row"><div class="bf-roster-col" style="text-align:left">ESPECIE</div><div class="bf-roster-col">BIFRÖST</div><div class="bf-roster-col">APARICIÓN</div><div class="bf-roster-col">REGLAS</div></div>'+
    '<div class="bf-roster">'+all.map(n=>
     '<div class="bf-roster-row"><div><b>'+E(n)+'</b><small>'+E(this.roster.blocked[n]?"Bloqueado para apariciones":"Especie del proyecto")+'</small></div>'+
     '<div class="bf-roster-col"><input type="checkbox" aria-label="Capturable '+E(n)+'" data-roster="bifrost" data-species="'+E(n)+'" '+(this.roster.bifrost[n]?"checked":"")+'></div>'+
     '<div class="bf-roster-col"><input type="checkbox" aria-label="Generar '+E(n)+'" data-roster="spawn" data-species="'+E(n)+'" '+(this.roster.spawn[n]?"checked":"")+'></div>'+
     '<button class="bf-mini-btn" title="Configuración específica de '+E(n)+'" data-edit-species="'+E(n)+'">↗</button></div>').join("")+'</div>'+
    (total>150?'<div class="bf-help" style="margin-top:10px">Se muestran los primeros 150 resultados. Filtra para localizar una especie concreta.</div>':"")+
    '<div class="bf-help" style="margin-top:12px">El perfil Full OW utiliza todas las especies de las tablas del mapa si spawn_filter=all. Si eliges allowlist, solo las marcadas en APARICIÓN. En el inspector puedes definir nivel, forma regional, frecuencia y reacción por especie. Para las aves de Galar, usa forma 1 en la especie base. Para bloquear una especie por completo, usa la opción de abajo.</div>'+
    '<div class="bf-actions"><input class="bf-input" data-block-species placeholder="ID que no debe aparecer" style="max-width:190px"><button class="bf-btn" data-action="toggle-block">Alternar bloqueo</button></div>');
 }
 spawnsPanel(v){
  const mode=v.encounter_mode;
  return '<div class="bf-kicker">FAUNA DEL MAPA</div><h1 class="bf-headline">De la hierba al mundo visible.</h1>'+
   '<p class="bf-sub">La fauna se toma de las tablas PBS de encuentros existentes. En modo OW completo no comienzan combates aleatorios de hierba: aparece un Pokémon en una casilla elegible y puedes lanzarle una Ball o iniciar un combate.</p>'+
   '<div class="bf-cards">'+[
    ["CLÁSICO","Combates de hierba","Sin spawn del mod"],
    ["MIXTO","Combates + OW","Ambas mecánicas activas"],
    ["OW COMPLETO","Solo Pokémon visibles","Suprime aleatorios terrestres"]
   ].map((x,i)=>{
    const key=["classic","hybrid","overworld"][i];
    return '<button class="bf-prof-card '+(mode===key?"active":"")+'" data-mode="'+key+'"><strong>'+x[0]+'</strong><small>'+x[1]+'</small><small>'+x[2]+'</small></button>';
   }).join("")+'</div>'+
   this.panel("Ejemplo de un mapa con hierba",this.mapPreview(v))+
   this.panel("Precauciones del motor",'<div class="bf-help">• Solo se reemplazan encuentros espontáneos de terreno terrestre y cuevas. Pesca, Surf y eventos por script siguen originales.<br>• Cada spawn requiere sprite de Graphics/Characters/Followers y un tile válido. Si falta, no aparece un evento invisible.<br>• Cantidad, distancia, probabilidad y duración se ajustan en el inspector.<br>• Es un runtime nuevo que debe probarse en mkxp, con mapas, guardado y plugins visuales.</div>');
 }
 mapPreview(v){
  let cells="";
  for(let y=0;y<8;y++){
   for(let x=0;x<12;x++){
    const player=x===5&&y===4;
    const mon=[[3,2],[9,3],[6,1]].some(p=>p[0]===x&&p[1]===y);
    const grass=(y%3!==0 && x%4!==0);
    cells+='<div style="height:30px;border:1px solid #364b5b;display:grid;place-items:center;background:'+(grass?"#344e41":"#293541")+';color:'+(player?"#f3d69c":mon?"#a3daf0":"#617c7a")+';font-size:15px">'+(player?"◆":mon?"●":grass?"╱":"")+'</div>';
   }
  }
  return '<div style="display:grid;grid-template-columns:repeat(12,minmax(0,1fr));gap:2px;max-width:615px;margin:auto">'+cells+'</div>'+
   '<div class="bf-help" style="margin-top:10px">◆ Jugador · ● OW de ejemplo · trazos = terreno. Vista esquemática, no lee el mapa abierto ni ejecuta spawns.</div>'+
   '<div class="bf-cards"><div class="bf-stat"><span>INTENTOS DE APARICIÓN</span><strong>'+E(v.spawn_chance)+'%</strong><small>Por paso elegible</small></div>'+
   '<div class="bf-stat"><span>OW SIMULTÁNEOS</span><strong>'+E(v.spawn_limit)+'</strong><small>Máximo de eventos generados</small></div></div>';
 }
 aimPanel(v){
  return '<div class="bf-kicker">APUNTADO Y DISTANCIA</div><h1 class="bf-headline">Zona de lanzamiento</h1><p class="bf-sub">Las filas están orientadas hacia delante del jugador y la anchura cubre los laterales. Distancia óptima y precisión cambian el resultado.</p>'+
    this.panel("Previsualización interactiva · 7×7",this.preview(v))+
    this.panel("Reglas espaciales",'<div class="bf-help">Alcance: '+E(v.range)+' filas · Anchura: '+E(v.width)+' columnas · Zona óptima: '+E(v.optimal_range)+' filas. En el perfil Bifröst, la octava fila falla. La vista anterior enseña las primeras 7 filas, aunque el alcance de otros proyectos puede ser mayor.</div>');
 }
 capturePanel(v){
  return '<div class="bf-kicker">PROBABILIDADES</div><h1 class="bf-headline">Balance de la captura</h1>'+
   '<p class="bf-sub">La bonificación desde atrás, la distancia y la captura crítica se combinan con una base de captura. Es una fórmula propia del mod, todavía no una réplica de todas las Poké Balls de Essentials.</p>'+
   this.panel("Escenario de cálculo",this.preview(v))+
   this.panel("Comparativa de multiplicadores",'<div class="bf-cards">'+[
    ["CAPTURA BASE","≥ "+v.capture_floor+"%","Mínimo inicial"],
    ["DESDE ATRÁS","×"+(Number(v.back_multiplier)/100).toFixed(2),"Bonificación"],
    ["CRÍTICA ESPALDA",v.critical_back+"%","Probabilidad de activación"],
    ["CAPTURA CRÍTICA","×"+(Number(v.critical_multiplier)/100).toFixed(2),"Multiplicador"]
   ].map(x=>'<div class="bf-stat"><span>'+E(x[0])+'</span><strong>'+E(x[1])+'</strong><small>'+E(x[2])+'</small></div>').join("")+'</div>');
 }
 behaviorPanel(v){
  return '<div class="bf-kicker">IA Y REACCIONES</div><h1 class="bf-headline">Respuesta ante el entrenador</h1>'+
   '<p class="bf-sub">Cada Pokémon marcado como OW puede reaccionar cuando el jugador invade su distancia de alerta. Por especie y evento puedes sobrescribir esta reacción.</p>'+
   this.panel("Diagrama de reacción",'<div class="bf-cards">'+[
    ["01 · DETECCIÓN","≤ "+v.alert_distance+" casillas","Jugador dentro de alarma"],
    ["02 · COMPORTAMIENTO",label(v.reaction),"Flee / Attack / Ignore"],
    ["03 · RESOLUCIÓN","Huir o combatir","El evento conserva sus reglas"]
   ].map(x=>'<div class="bf-stat"><span>'+E(x[0])+'</span><strong>'+E(x[1])+'</strong><small>'+E(x[2])+'</small></div>').join("")+'</div>'+
   '<div class="bf-help">El movimiento continuo de huida, persecución, visión de obstáculos, tipos de agresividad y reacciones visuales avanzadas siguen pendientes.</div>');
 }
 scopesPanel(){
  return '<div class="bf-kicker">CONFIGURACIÓN EN CAPAS</div><h1 class="bf-headline">Reglas donde las necesitas.</h1>'+
   '<p class="bf-sub">Configura un proyecto completo o sobrescribe solo determinados mapas, especies y eventos. Los ajustes locales no modifican los demás ámbitos.</p>'+
   this.panel("Ámbitos existentes",'<div class="bf-compare">'+Object.keys(this.config).sort().map(scope=>
     '<div class="bf-roster-row" style="grid-template-columns:1fr auto auto"><div><b>'+E(scope)+'</b><small>'+Object.keys(this.config[scope]||{}).length+' propiedades explícitas</small></div>'+
     '<button class="bf-btn" data-scope-button="'+E(scope)+'">Editar</button>'+
     (scope==="global"?"":'<button class="bf-btn" data-remove-scope="'+E(scope)+'">Eliminar</button>')+'</div>').join("")+'</div>'+
   '<div class="bf-actions"><input class="bf-input" data-scope-name placeholder="map:12 / species:RAIKOU / event:12:4" style="flex:1"><button class="bf-btn" data-action="create-scope">Crear ámbito</button></div>');
 }
 testsPanel(){
  return '<div class="bf-kicker">ESTADO DE INTEGRACIÓN</div><h1 class="bf-headline">Lo integrado no equivale a probado.</h1>'+
    this.panel("Pruebas prioritarias",'<div class="bf-help">'+[
     "Cargar el editor sin errores y guardar/releer config.ini + roster.ini.",
     "Habilitar always y confirmar apertura R/L sin conflicto con menús.",
     "Probar modo overworld en un mapa con hierba y tablas PBS.",
     "Comprobar sprite, colisión, caducidad y límite de OW temporales.",
     "Captura correcta: Ball, Pokédex, caja/PC, guardado y recarga.",
     "Validar formas regionales, eventos de roaming y encuentros especiales.",
     "Probar Turbo, 2.5D y no alterar combate BSS/BAS."
    ].map((x,i)=>'<div style="padding:9px;border-bottom:1px solid #344159">'+(i+1)+'. '+E(x)+'</div>').join("")+'</div>')+
    this.panel("API rápida",'<div class="bf-help"><code>pbBifrostAim</code> · Inicia el apuntado desde un evento.<br><code>pbBifrostRulesMenu</code> · Abre preferencias ingame.<br><code>[OWCAP:RAIKOU:50]</code> · Nombre de OW capturable.<br><code>[OWDECOR]</code> · Decorativo.</div>');
 }
 inspector(){
  let out='<div class="bf-section-title">AJUSTES DEL MÓDULO</div>';
  const keys=this.fieldsFor(this.section);
  out+=keys.map(k=>this.field(k)).join("");
  if(this.section==="species")out+='<div class="bf-divider"></div><div class="bf-help">Catálogo Bifröst: '+Object.keys(this.roster.bifrost).filter(x=>this.roster.bifrost[x]).length+
   ' especies. Con spawn_filter=allowlist, los marcados en “Aparición” forman la lista de fauna; con “all” se usan las tablas PBS.</div>';
  if(this.section==="profiles")out+='<div class="bf-divider"></div><div class="bf-help">Para comparar todos los cambios de un perfil selecciona su tarjeta en la vista central. El botón Aplicar reemplaza el ajuste global, sin borrar reglas locales.</div>';
  if(this.scope!=="global")out+='<div class="bf-divider"></div><button class="bf-btn" data-action="inherit-scope">Quitar ajustes de este ámbito</button>';
  out+='<div class="bf-divider"></div><div class="bf-help">Los valores del inspector afectan al ámbito <b>'+E(this.scope)+'</b>. Se aplican al juego al guardar archivos en el proyecto. No se modifican sistemas BSS/BAS.</div>';
  return out;
 }
 set(key,value){
  const f=FIELDS[key];if(!f)return;
  if(f[2]==="int"||f[2]==="odd"){
   const n=Number(value),[min,max]=f[3];
   if(!Number.isInteger(n)||n<min||n>max||(f[2]==="odd"&&n%2===0)){
    this.status="Valor inválido: "+f[0];this.render();return;
   }
   value=String(n);
  }else if(f[2]==="bool"){if(!["0","1"].includes(value))return}
  else if(!f[3].includes(value))return;
  this.config[this.scope]??={};
  this.config[this.scope][key]=value;
  this.status="Cambios preparados en "+this.scope;
  this.resetConfirm=false;
  this.render();
 }
 change(e){
  const node=e.target;
  if(node.matches("[data-scope]")){
   this.scope=node.value;this.render();return;
  }
  const field=node.getAttribute("data-field");
  if(field){this.set(field,node.value);return;}
  const type=node.getAttribute("data-roster");
  const species=node.getAttribute("data-species");
  if(type&&species&&this.roster[type]){
   this.roster[type][species]=!!node.checked;
   this.status="Catálogo modificado · "+species;
   this.resetConfirm=false;
   this.render();
  }
 }
 input(e){
  if(e.target.hasAttribute("data-search")){
   this.search=e.target.value.toUpperCase();
   const start=e.target.selectionStart;
   this.render();
   const el=this.root.querySelector("[data-search]");
   if(el){el.focus();el.setSelectionRange(start,start)}
  }
 }
 addSpecies(name){
  name=String(name||"").toUpperCase().trim();
  if(!/^[A-Z][A-Z0-9_]{1,36}$/.test(name)){this.status="ID de especie inválido";this.render();return}
  if(!this.species.includes(name))this.species.push(name);
  this.species.sort();this.search=name;
  this.status="Especie "+name+" visible en catálogo. Marca la columna Bifröst o Aparición y guarda.";
  this.render();
 }
 async save(){
  if(this.saving)return;
  this.saving=true;this.render();
  try{
   const fs=this.ctx.fs;
   const cfg=serializeConfig(this.config),ros=serializeRoster(this.roster);
   await fs.writeProjectFile(CONFIG_PATH,cfg);
   await fs.writeProjectFile(ROSTER_PATH,ros);
   const a=await fs.readProjectFile(CONFIG_PATH),b=await fs.readProjectFile(ROSTER_PATH);
   if(a!==cfg||b!==ros)throw Error("Los archivos leídos no coinciden con lo guardado");
   this.baselineConfig=cfg;this.baselineRoster=ros;this.status="Configuración y catálogo guardados y verificados";
   this.ctx.ui?.showToast?.({message:"Bifröst: configuración y catálogo guardados",level:"info"});
  }catch(err){this.status="Error al guardar: "+(err.message||err)}
  finally{this.saving=false;this.render()}
 }
 async click(e){
  const t=e.target.closest("button");if(!t||!this.root.contains(t))return;
  const section=t.getAttribute("data-section");
  if(section){this.section=section;this.render();return;}
  const prof=t.getAttribute("data-profile");
  if(prof){this.selectedProfile=prof;this.render();return;}
  const mode=t.getAttribute("data-mode");
  if(mode){this.set("encounter_mode",mode);return;}
  const species=t.getAttribute("data-edit-species");
  if(species){this.scope="species:"+species.toLowerCase();this.config[this.scope]??={};this.section="species";this.search=species;this.status="Editando ajustes de "+species;this.render();return;}
  const scope=t.getAttribute("data-scope-button");
  if(scope){this.scope=scope;this.render();return;}
  const remove=t.getAttribute("data-remove-scope");
  if(remove&&remove!=="global"){delete this.config[remove];if(this.scope===remove)this.scope="global";this.status="Ámbito eliminado sin guardar";this.render();return;}
  const fw=t.getAttribute("data-forward");
  if(fw){this.aimF=Number(fw);this.aimS=Number(t.getAttribute("data-side"));this.render();return;}
  const action=t.getAttribute("data-action");
  if(action==="save"){await this.save();return;}
  if(action==="reload"){
   if(this.dirty()&&!this.resetConfirm){this.resetConfirm=true;this.status="Pulsa Recargar nuevamente para descartar los cambios.";this.render();return;}
   this.resetConfirm=false;await this.load();return;
  }
  if(action==="apply-profile"){
   this.config.global={...PRESETS[this.selectedProfile]};
   this.scope="global";this.status="Perfil "+PROFILE_INFO[this.selectedProfile][0]+" aplicado localmente. Guarda para usarlo.";this.render();return;
  }
  if(action==="inherit-scope"){
   if(this.scope!=="global")delete this.config[this.scope];
   this.scope="global";this.status="El ámbito heredará la configuración global";this.render();return;
  }
  if(action==="create-scope"||action==="new-scope"){
   const entry=this.root.querySelector("[data-scope-name]");
   const input=entry?entry.value:(this.ctx.editor&&this.ctx.editor.activeMapId?("map:"+this.ctx.editor.activeMapId()):"map:");
   const name=String(input||"").trim().toLowerCase();
   if(!/^(map:\d+|species:[a-z0-9_]+|event:\d+:\d+)$/.test(name)){
    this.section="scopes";this.status="Escribe un ámbito válido en Ámbitos: map:12, species:RAIKOU o event:12:4";this.render();return;
   }
   this.config[name]??={};this.scope=name;this.section="scopes";this.status="Nuevo ámbito "+name;this.render();return;
  }
  if(action==="add-species"){this.addSpecies(this.root.querySelector("[data-add-species]")?.value);return;}
  if(action==="toggle-block"){
   const name=String(this.root.querySelector("[data-block-species]")?.value||"").trim().toUpperCase();
   if(!/^[A-Z][A-Z0-9_]{1,36}$/.test(name)){this.status="ID inválido para bloquear";this.render();return;}
   this.roster.blocked[name]=!this.roster.blocked[name];this.addSpecies(name);
   this.status=(this.roster.blocked[name]?"Bloqueado: ":"Desbloqueado: ")+name;this.render();
  }
 }
}
export function activate(ctx){
 const id="vermeil.bifrost-capture";
 ctx.ui.registerPanel({
  id,title:"Bifröst Capture Studio",icon:"target",defaultPosition:"right",
  defaultSize:{width:1530,height:920},showInMenu:!(ctx.menu&&ctx.menu.registerMenuItem),
  render(host){return new CaptureStudio(ctx,host)}
 });
 if(ctx.menu?.registerMenuItem)
  ctx.menu.registerMenuItem({menu:"Mods",label:"Bifröst Capture Studio",icon:"target",handler(){return ctx.ui.openPanel(id)}});
 if(ctx.commands?.register)
  ctx.commands.register("vermeil.bifrost-capture.open",()=>ctx.ui.openPanel(id));
}
