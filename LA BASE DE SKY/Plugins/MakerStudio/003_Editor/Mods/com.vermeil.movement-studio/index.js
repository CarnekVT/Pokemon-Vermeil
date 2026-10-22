import { STYLES } from "./styles.js";

const PATH = "Plugins/[VERMEIL] Smooth Movement/config.ini";
const VERSION = "0.7.0";
const DEFAULTS = {
  directions: "4", mode: "grid", subtile_divisions: "4", instant_turn: "1",
  flow_motion: "0", camera_lookahead: "0", wall_slide: "0",
  smooth_movement: "1", camera_smoothing: "35",
  diagonal_facing: "keep", diagonal_speed: "quick", diagonal_live_turn: "1", wall_slide_priority: "horizontal",
  camera_deadzone: "0", camera_lead_response: "120", debug_hud: "0"
};
const SECTIONS = [
  { id:"overview", icon:"◈", title:"Vista general", hint:"Estado del movimiento y acceso a los sistemas" },
  { id:"control", icon:"✥", title:"Control", hint:"Direcciones, movimiento inmediato y Continuous Flow" },
  { id:"diagonal", icon:"⤢", title:"Diagonales", hint:"Orientación de sprites y deslizamiento por paredes" },
  { id:"camera", icon:"▣", title:"Cámara", hint:"Seguimiento, anticipación y zona muerta" },
  { id:"debug", icon:"⌁", title:"Diagnóstico", hint:"Herramientas de prueba, sin alterar la jugabilidad" }
];
const FIELDS = {
  directions:{ group:"control", label:"Direcciones", description:"Cuatro direcciones o diagonales opcionales en el control moderno.", options:[["4","4 direcciones"],["8","8 direcciones"]] },
  instant_turn:{ group:"control", label:"Tipo de control", description:"Clásico conserva íntegra la respuesta original de Essentials. Moderno utiliza la dirección pulsada sin retraso artificial.", options:[["1","Moderno · respuesta inmediata"],["0","Clásico · Essentials original"]] },
  flow_motion:{ group:"control", label:"Continuous Flow", description:"Encadena pasos consecutivos con el tiempo sobrante, respetando eventos. Solo funciona con el control moderno.", options:[["0","Desactivado"],["1","Activado"]] },
  diagonal_speed:{ group:"diagonal", label:"Ritmo de las diagonales", description:"Ágil: cada diagonal tarda lo mismo que una casilla recta (avanza más rápido en distancia). Uniforme: mantiene la misma velocidad física en todas las direcciones.", options:[["quick","Ágil · responde antes"],["uniform","Uniforme · velocidad constante"]] },
  diagonal_live_turn:{ group:"diagonal", label:"Orientación inmediata", description:"El sprite gira hacia la dirección pulsada aunque el paso actual siga terminándose. Nunca altera colisiones ni guarda teclas.", options:[["1","Sí, reflejar la tecla actual"],["0","No, esperar a terminar la casilla"]] },
  wall_slide:{ group:"diagonal", label:"Deslizamiento en paredes", description:"Si una diagonal está bloqueada, intenta moverse por un eje cardinal válido.", options:[["0","Desactivado"],["1","Activado"]] },
  wall_slide_priority:{ group:"diagonal", label:"Eje preferente", description:"Orden en que se comprueban los ejes cuando una diagonal está bloqueada.", options:[["horizontal","Horizontal"],["vertical","Vertical"],["facing","Según orientación"]] },
  diagonal_facing:{ group:"diagonal", label:"Sprite durante diagonales", description:"Fila gráfica elegida para sprites tradicionales de cuatro direcciones.", options:[["keep","Mantener orientación"],["horizontal","Priorizar horizontal"],["vertical","Priorizar vertical"]] },
  camera_smoothing:{ group:"camera", label:"Suavidad de cámara", description:"35 conserva la cámara anterior de Vermeil. No modifica el tiempo de respuesta de los botones.", min:0, max:100, step:5, unit:"%" },
  camera_lookahead:{ group:"camera", label:"Anticipación visual", description:"Cuánto mira la cámara hacia la dirección del movimiento.", options:[["0","Desactivada"],["8","8 píxeles"],["16","16 píxeles"],["24","24 píxeles"],["32","32 píxeles"]] },
  camera_deadzone:{ group:"camera", label:"Zona muerta", description:"Margen alrededor del jugador sin correcciones continuas del encuadre.", options:[["0","Desactivada"],["8","8 píxeles"],["16","16 píxeles"],["24","24 píxeles"],["32","32 píxeles"]] },
  camera_lead_response:{ group:"camera", label:"Respuesta del look-ahead", description:"Velocidad visual de la transición de cámara; no introduce retardo de movimiento.", options:[["60","Rápida · 60 ms"],["120","Normal · 120 ms"],["200","Suave · 200 ms"]] },
  debug_hud:{ group:"debug", label:"HUD de diagnóstico", description:"Muestra dirección, posición, Turbo, Flow, cámara y FPS únicamente en modo Debug.", options:[["0","Oculto"],["1","Mostrar en Debug"]] }
};
const E = value => String(value == null ? "" : value).replace(/[&<>"']/g, ch => ({ "&":"&amp;", "<":"&lt;", ">":"&gt;", '"':"&quot;", "'":"&#39;" })[ch]);
const KEYSETS = Object.keys(FIELDS);
const OPTIONS_BY_GROUP = id => KEYSETS.filter(key => FIELDS[key].group === id);
function parseConfig(text) {
  const sections = { global: { ...DEFAULTS } };
  let section = "global";
  for (const raw of String(text || "").split(/\r?\n/)) {
    const line = raw.replace(/[;#].*$/, "").trim();
    const header = /^\[(global|map:\d+)\]$/i.exec(line);
    if (header) {
      section = header[1].toLowerCase();
      sections[section] ||= {};
      continue;
    }
    const pair = /^([a-z_]+)\s*=\s*(.*?)\s*$/i.exec(line);
    if (pair && Object.prototype.hasOwnProperty.call(DEFAULTS, pair[1].toLowerCase())) {
      sections[section][pair[1].toLowerCase()] = pair[2];
    }
  }
  return sections;
}
function serializeConfig(config) {
  const rows = ["; Vermeil Movement Studio " + VERSION, "; Configuración global y por mapa.", ""];
  const sections = ["global", ...Object.keys(config).filter(key => /^map:\d+$/.test(key)).sort((a,b) => Number(a.slice(4))-Number(b.slice(4)))];
  for (const name of sections) {
    rows.push("[" + name + "]");
    const settings = config[name] || {};
    for (const key of Object.keys(DEFAULTS)) {
      if (Object.prototype.hasOwnProperty.call(settings,key)) rows.push(key + "=" + settings[key]);
    }
    rows.push("");
  }
  return rows.join("\n");
}
function mapId(ctx) {
  try {
    const n = Number(ctx.editor && ctx.editor.activeMapId && ctx.editor.activeMapId());
    return Number.isInteger(n) && n > 0 ? n : null;
  } catch (_) { return null; }
}
function optionMarkup(value,label,selected) {
  return '<option value="' + E(value) + '"' + (selected ? ' selected' : '') + '>' + E(label) + '</option>';
}
function svgPreview(values, dir) {
  const classic = values.instant_turn === "0";
  const dirs = classic ? 4 : Number(values.directions);
  const d = dir && (dirs === 8 || [2,4,6,8].includes(dir)) ? dir : 8;
  const vectors = {1:[-1,1],2:[0,1],3:[1,1],4:[-1,0],6:[1,0],7:[-1,-1],8:[0,-1],9:[1,-1]};
  const vec = vectors[d] || [0,-1];
  const norm = vec[0] && vec[1] ? Math.sqrt(2) : 1;
  const vx = vec[0]/norm, vy=vec[1]/norm;
  const lead = Number(values.camera_lookahead || 0), deadzone=Number(values.camera_deadzone || 0);
  const centerX = 360, centerY = 215, leadX = centerX + vx*lead*2.1, leadY = centerY + vy*lead*2.1;
  const angle = Math.atan2(vy,vx)*180/Math.PI + 90;
  const dz = deadzone*2.3;
  const diagonals = dirs === 8;
  const walls = '<g opacity=".58"><rect x="66" y="80" width="64" height="64" rx="6" fill="#283a43" stroke="#506476"/><rect x="66" y="153" width="64" height="64" rx="6" fill="#283a43" stroke="#506476"/><rect x="578" y="302" width="64" height="64" rx="6" fill="#283a43" stroke="#506476"/><rect x="508" y="302" width="64" height="64" rx="6" fill="#283a43" stroke="#506476"/></g>';
  const compass = dirs === 8 ? [1,2,3,4,6,7,8,9] : [2,4,6,8];
  const arrows = compass.map(n => {
    const p = vectors[n], nn=p[0]&&p[1]?Math.sqrt(2):1;
    const x1=centerX+p[0]/nn*65, y1=centerY+p[1]/nn*65;
    const x2=centerX+p[0]/nn*108, y2=centerY+p[1]/nn*108;
    const active=n===d;
    return '<line x1="'+x1+'" y1="'+y1+'" x2="'+x2+'" y2="'+y2+'" stroke="'+(active?'#92b6ff':'#536985')+'" stroke-width="'+(active?6:3)+'" stroke-linecap="round" marker-end="url(#'+(active?'vm-tip-on':'vm-tip-off')+')"/>';
  }).join("");
  return '<svg viewBox="0 0 720 430" role="img" aria-label="Vista conceptual del desplazamiento y de los márgenes de cámara" xmlns="http://www.w3.org/2000/svg">' +
    '<defs><pattern id="vm-floor" width="54" height="54" patternUnits="userSpaceOnUse"><rect width="54" height="54" fill="#162131"/><path d="M54 0H0V54" fill="none" stroke="#34465e" stroke-width="1"/></pattern><marker id="vm-tip-on" markerWidth="5" markerHeight="5" refX="4.5" refY="2.5" orient="auto"><path d="M0 0L5 2.5L0 5Z" fill="#92b6ff"/></marker><marker id="vm-tip-off" markerWidth="5" markerHeight="5" refX="4.5" refY="2.5" orient="auto"><path d="M0 0L5 2.5L0 5Z" fill="#536985"/></marker></defs>' +
    '<rect x="1" y="1" width="718" height="428" rx="12" fill="#0c1320" stroke="#31425d"/>' +
    '<rect x="22" y="22" width="676" height="386" rx="8" fill="url(#vm-floor)" stroke="#273751"/>' +
    walls +
    '<g opacity=".9"><circle cx="'+centerX+'" cy="'+centerY+'" r="148" fill="#1e3957" fill-opacity=".16" stroke="#476891" stroke-width="1.5" stroke-dasharray="7 6"/></g>' +
    (dz?'<rect x="'+(centerX-dz)+'" y="'+(centerY-dz)+'" width="'+(dz*2)+'" height="'+(dz*2)+'" fill="#5fd2ad" fill-opacity=".09" stroke="#61dfb5" stroke-width="2" stroke-dasharray="7 4" rx="10"/>':'') +
    (lead?'<line x1="'+centerX+'" y1="'+centerY+'" x2="'+leadX+'" y2="'+leadY+'" stroke="#eac579" stroke-width="3" stroke-dasharray="6 5"/><circle cx="'+leadX+'" cy="'+leadY+'" r="8" fill="#f7d58d" stroke="#1a2437" stroke-width="3"/>':'') +
    arrows +
    '<g transform="translate('+centerX+' '+centerY+')"><circle r="34" fill="#0d1a29" stroke="#7e9df8" stroke-width="2.5"/><rect x="-20" y="-19" width="40" height="39" rx="10" fill="#5678da" stroke="#9fb7ff" stroke-width="2"/><rect x="-13" y="-12" width="26" height="20" rx="6" fill="#94b3ff" opacity=".8"/><path d="M0 -20 L-12 -39 L12 -39Z" transform="rotate('+angle+')" fill="#fff1bf" stroke="#526998" stroke-width="2"/><circle cy="15" r="4" fill="#b7d4ff"/></g>' +
    '<rect x="39" y="36" width="135" height="23" rx="5" fill="#111b2c" stroke="#354b65"/><text x="50" y="52" font-size="11" fill="#b9cbed">'+(classic?'CONTROL CLÁSICO':(dirs===8?'MOVIMIENTO 8D':'MOVIMIENTO 4D'))+'</text>' +
    '<text x="37" y="393" font-size="10" fill="#8ea2bf">PREVISUALIZACIÓN DE CONFIGURACIÓN · NO EJECUTA EL JUEGO</text>' +
    (dz?'<text x="542" y="51" font-size="10" fill="#6cddb2">ZONA MUERTA '+deadzone+' px</text>':'') +
    (lead?'<text x="540" y="67" font-size="10" fill="#ffdc92">LOOK-AHEAD '+lead+' px</text>':'') +
    '</svg>';
}
class MovementStudio {
  constructor(ctx,host) {
    this.ctx=ctx;
    this.host=host;
    this.section="overview";
    this.experience="simple";
    this.config={global:{...DEFAULTS}};
    this.loaded=false;
    this.baseline="";
    this.scope="global";
    this.map=null;
    this.direction=8;
    this.saving=false;
    this.reloadConfirm=false;
    this.message="";
    this.messageType="";
    this.style=document.createElement("style");
    this.style.textContent=STYLES;
    this.root=document.createElement("div");
    this.root.className="vm-root";
    this.host.innerHTML="";
    this.host.appendChild(this.style);
    this.host.appendChild(this.root);
    this.root.addEventListener("click",e=>this.click(e));
    this.root.addEventListener("change",e=>this.change(e));
    this.root.addEventListener("input",e=>this.input(e));
    this.render();
    this.load();
  }
  toast(message,type="info"){
    this.message=message;
    this.messageType=type;
    if(type==="error") this.ctx.log?.error(message);
    this.drawStatus();
    if(this.ctx.ui && this.ctx.ui.showToast) this.ctx.ui.showToast({message,level:type==="error"?"error":"info"});
  }
  currentScope(){return this.scope==="global"?"global":"map:"+this.map;}
  values(){return {...DEFAULTS,...(this.config.global||{}),...(this.scope==="map"?(this.config[this.currentScope()]||{}):{})};}
  dirty(){return serializeConfig(this.config)!==this.baseline;}
  async load(){
    try{
      let content="";
      if(await this.ctx.fs.projectExists(PATH)) content=await this.ctx.fs.readProjectFile(PATH);
      this.config=parseConfig(content);
      this.baseline=serializeConfig(this.config);
      this.loaded=true;
      this.reloadConfirm=false;
      this.message=content?"Configuración cargada":"Sin configuración guardada; se utilizan los valores iniciales.";
      this.render();
    }catch(err){
      this.loaded=true;
      this.render();
      this.toast("No se pudo cargar Movement Studio: "+(err.message||err),"error");
    }
  }
  async save(){
    if(this.saving)return;
    this.saving=true;
    this.drawStatus();
    try{
      const data=serializeConfig(this.config);
      await this.ctx.fs.writeProjectFile(PATH,data);
      const read=await this.ctx.fs.readProjectFile(PATH);
      if(serializeConfig(parseConfig(read))!==data) throw new Error("La lectura de verificación no coincide con el archivo guardado.");
      this.baseline=data;
      this.toast("Configuración guardada y verificada · "+PATH,"success");
    }catch(err){
      this.toast("Error al guardar: "+(err.message||err),"error");
    }finally{
      this.saving=false;
      this.drawStatus();
      this.render();
    }
  }
  scopeControl(){
    const id=mapId(this.ctx);
    const current=this.scope==="map"?this.map:id;
    return '<select class="vm-select" style="max-width:200px" data-scope aria-label="Ámbito de configuración">' +
      optionMarkup("global","Global · Todo el proyecto",this.scope==="global")+
      (current ? optionMarkup("map","Mapa "+current,this.scope==="map"):"") + '</select>';
  }
  nav(){
    return '<div class="vm-overline">ÁREAS DE TRABAJO</div>'+
      SECTIONS.filter(s=>this.experience==="advanced"||s.id!=="debug").map(s=>'<button type="button" class="vm-nav-btn '+(this.section===s.id?'active':'')+'" data-section="'+s.id+'" title="'+E(s.title)+'" aria-label="'+E(s.title)+'"><span aria-hidden="true">'+s.icon+'</span><span class="vm-nav-caption">'+E(s.title)+'</span></button>').join("") +
      '<div class="vm-nav-meta"><strong>Movement Studio</strong>Los controles modernos utilizan la pulsación actual. Ningún ajuste visual retiene los botones.</div>';
  }
  sectionInfo(){
    return SECTIONS.find(s=>s.id===this.section)||SECTIONS[0];
  }
  render(){
    const v=this.values(),info=this.sectionInfo(),classic=v.instant_turn==="0";
    const dirCount=classic?4:v.directions, flow=classic?"No disponible":(v.flow_motion==="1"?"Activado":"Desactivado");
    const status=this.dirty()?'Sin guardar':'Guardado';
    this.root.innerHTML=
      '<header class="vm-top"><div class="vm-mark" aria-hidden="true">✥</div><div class="vm-brand"><strong>Movement Studio</strong><small>VERMEIL · v'+VERSION+' · Editor de movimiento</small></div>'+
      '<span class="vm-tag live">ESSENTIALS 21.1</span><div class="vm-top-spacer"></div>'+
      this.scopeControl()+
      '<div class="vm-experience" role="group" aria-label="Nivel del editor"><button type="button" data-experience="simple" class="'+(this.experience==="simple"?"active":"")+'">Sencillo</button><button type="button" data-experience="advanced" class="'+(this.experience==="advanced"?"active":"")+'">Avanzado</button></div>'+
      '<span class="vm-tag '+(this.dirty()?'warn':'')+'" data-dirty-head>'+(this.dirty()?'● Cambios sin guardar':'✓ Sin cambios')+'</span>'+
      '<button type="button" class="vm-btn ghost" data-act="reload">↻ Recargar</button>'+
      '<button type="button" class="vm-btn primary" data-act="save">▣ Guardar cambios</button></header>'+
      '<div class="vm-layout">'+
      '<nav class="vm-nav" aria-label="Áreas de Movement Studio">'+this.nav()+'</nav>'+
      '<main class="vm-stage-area"><div class="vm-stage-top"><strong>VISTA DEL MOVIMIENTO</strong><span class="vm-muted">Composición y respuesta</span><div class="vm-top-spacer"></div><span class="vm-tag" data-stage-mode>'+(classic?'CLÁSICO':dirCount+' DIRECCIONES')+'</span></div>'+
      '<div class="vm-stage-viewport"><div class="vm-stage-key"><span class="vm-chip good" data-stage-flow>FLOW '+E(flow)+'</span><span class="vm-chip" data-stage-cam>CÁMARA '+E(v.camera_smoothing)+'%</span></div><div class="vm-preview" data-preview-svg>'+svgPreview(v,this.direction)+'</div></div>'+
      '<div class="vm-stage-foot"><div><strong>Dirección de vista previa</strong><div class="vm-muted">Las flechas solo cambian el esquema. No mueven al jugador ingame.</div></div><div class="vm-dpad" role="group" aria-label="Dirección de vista previa">'+
      [7,8,9,4,5,6,1,2,3].map(n=>'<button type="button" class="vm-direction '+(n===5?'center':this.direction===n?'active':'')+'"'+(n===5?' disabled':(Number(dirCount)===4&&[1,3,7,9].includes(n))?' disabled':' data-direction="'+n+'"')+' aria-label="'+E(({7:"Arriba izquierda",8:"Arriba",9:"Arriba derecha",4:"Izquierda",5:"Centro",6:"Derecha",1:"Abajo izquierda",2:"Abajo",3:"Abajo derecha"})[n])+'">'+({7:"↖",8:"↑",9:"↗",4:"←",5:"●",6:"→",1:"↙",2:"↓",3:"↘"})[n]+'</button>').join("")+
      '</div></div>'+
      '<div class="vm-info-strip"><div class="vm-info"><span>TIPO DE CONTROL</span><strong data-info-control>'+(classic?'Clásico Essentials':'Moderno inmediato')+'</strong></div><div class="vm-info"><span>DIRECCIONES</span><strong data-info-directions>'+dirCount+'</strong></div><div class="vm-info"><span>FLOW</span><strong data-info-flow>'+E(flow)+'</strong></div></div></main>'+
      '<aside class="vm-inspector"><div class="vm-inspector-head"><div class="vm-overline">INSPECTOR</div><strong>'+E(info.title)+'</strong><small>'+E(info.hint)+'</small></div><div class="vm-inspector-body">'+this.inspector(v)+'</div></aside>'+
      '</div><footer class="vm-footer"><span class="vm-status-dot '+(this.dirty()?'dirty':'')+'" data-status-dot></span><span data-status>'+E(this.message||status)+'</span><span class="vm-push vm-path">'+E(PATH)+'</span></footer>';
  }
  sectionCard(title,subtitle,contents){
    return '<section class="vm-card"><div class="vm-card-head"><strong>'+E(title)+'</strong>'+(subtitle?'<span class="vm-muted" style="font-size:9px">'+E(subtitle)+'</span>':'')+'</div><div class="vm-card-body">'+contents+'</div></section>';
  }
  field(key){
    const def=FIELDS[key],settings=this.values(),current=settings[key],local=this.scope==="map"?this.config[this.currentScope()]||{}:this.config.global||{};
    const own=Object.prototype.hasOwnProperty.call(local,key);
    const inherited=this.scope==="map"&&!own;
    const classic=settings.instant_turn==="0";
    const diagonalDisabled=classic||settings.directions!=="8";
    const unavailable=(key==="directions"||key==="flow_motion")&&classic ||
      (["diagonal_speed","diagonal_live_turn","wall_slide","wall_slide_priority","diagonal_facing"].includes(key)&&diagonalDisabled) ||
      (key==="camera_lead_response"&&settings.camera_lookahead==="0") ||
      (key==="wall_slide_priority"&&settings.wall_slide==="0");
    const reason=classic&&key!=="instant_turn"&&
      (["directions","flow_motion","diagonal_speed","diagonal_live_turn","wall_slide","wall_slide_priority","diagonal_facing"].includes(key)) ?
      "El control Clásico utiliza el movimiento original. Cambia a Moderno para editar esto." :
      diagonalDisabled&&["diagonal_speed","diagonal_live_turn","wall_slide","wall_slide_priority","diagonal_facing"].includes(key) ?
      "Activa el control Moderno de 8 direcciones para usar este ajuste." :
      key==="wall_slide_priority"&&settings.wall_slide==="0"?"Primero activa el deslizamiento en paredes." :
      key==="camera_lead_response"&&settings.camera_lookahead==="0"?"Primero activa la anticipación visual.":"";
    const disabled=unavailable?' disabled aria-disabled="true"':'';
    const origin=inherited?'<span class="vm-saved inherited">GLOBAL</span>':this.scope==="map"?'<span class="vm-saved">MAPA</span>':'';
    const reset=inherited?'':'<button type="button" class="vm-btn ghost small" data-inherit="'+E(key)+'" title="'+(this.scope==="map"?'Heredar del perfil global':'Restaurar valor original')+'">↶</button>';
    let control;
    if(def.options){
      control='<select class="vm-select" data-key="'+E(key)+'" aria-label="'+E(def.label)+'"'+disabled+'>'+
        def.options.map(opt=>optionMarkup(opt[0],opt[1],current===opt[0])).join("")+'</select>';
    }else{
      control='<div class="vm-range-wrap"><input type="range" class="vm-range" data-key="'+E(key)+'" min="'+def.min+'" max="'+def.max+'" step="'+def.step+'" value="'+E(current)+'" aria-label="'+E(def.label)+'"/><output class="vm-range-readout" data-range-readout="'+E(key)+'">'+E(current)+(def.unit||"")+'</output></div>';
    }
    return '<div class="vm-field '+(unavailable?'vm-field-disabled':'')+'"><div class="vm-field-top"><span class="vm-label">'+E(def.label)+'</span><span style="display:flex;gap:4px;align-items:center">'+origin+reset+'</span></div>'+control+'<span class="vm-field-note">'+E(reason||def.description)+'</span></div>';
  }
  inspector(v){
    const classic=v.instant_turn==="0";
    if(this.section==="overview" && this.experience==="simple"){
      const steps=[
        ["1","Elige cómo quieres moverte","Control clásico, 4 direcciones modernas u 8 direcciones.","control"],
        ["2","Haz las diagonales más rápidas","Escoge ritmo ágil y orientación inmediata.","diagonal"],
        ["3","Ajusta la cámara a tu gusto","Seguimiento y anticipación sin retrasar los controles.","camera"]
      ];
      return this.sectionCard("Primeros pasos","GUÍA SENCILLA",
        '<div class="vm-stack">'+steps.map(s=>
          '<button type="button" class="vm-guide-step" data-section="'+s[3]+'">'+
          '<span class="vm-guide-number">'+s[0]+'</span><span><strong>'+E(s[1])+'</strong><small>'+E(s[2])+'</small></span><b>›</b></button>'
        ).join("")+'</div>')+
        this.sectionCard("¿Qué estilo quieres?","ELIGE UNO",
          '<div class="vm-stack">'+
          '<button type="button" class="vm-preset" data-preset="classic"><b>Clásico</b><small>Como Pokémon Essentials original. Cuatro direcciones.</small></button>'+
          '<button type="button" class="vm-preset" data-preset="modern4"><b>Moderno · 4 direcciones</b><small>Giros inmediatos y pasos continuos, sin diagonales.</small></button>'+
          '<button type="button" class="vm-preset" data-preset="modern"><b>Moderno · 8 direcciones</b><small>Diagonales ágiles y orientación instantánea.</small></button>'+
          '</div><div class="vm-field-note" style="margin-top:10px">Elige el estilo, cambia lo que quieras y pulsa Guardar arriba. Ningún cambio se aplica al juego antes de guardar.</div>')+
        '<div class="vm-alert good"><b>¿Global o mapa?</b> Global afecta todo el juego. Selecciona un mapa arriba para personalizar solamente esa zona.</div>';
    }
    if(this.section==="overview"){
      const links=[
        ["control","Control y fluidez",classic?"Clásico Essentials":v.directions+" direcciones · Moderno"],
        ["diagonal","Diagonales",v.wall_slide==="1"?"Deslizamiento activado":"Deslizamiento desactivado"],
        ["camera","Composición de cámara",v.camera_smoothing+"% · look-ahead "+v.camera_lookahead+" px"],
        ["debug","Diagnóstico",v.debug_hud==="1"?"HUD activo en Debug":"HUD oculto"]
      ];
      return this.sectionCard("Sistemas configurables","VISIÓN GENERAL",
        '<div class="vm-stack">'+links.map(x=>'<button type="button" class="vm-summary-card" data-section="'+x[0]+'"><span><strong>'+E(x[1])+'</strong><small>'+E(x[2])+'</small></span><b>›</b></button>').join("")+'</div>')+
        this.sectionCard("Perfiles rápidos","REQUIEREN GUARDAR",
          '<div class="vm-grid"><button type="button" class="vm-btn" data-preset="classic">↩ Clásico</button><button type="button" class="vm-btn" data-preset="modern">✦ Moderno</button></div><div class="vm-field-note" style="margin-top:8px">Se aplican al ámbito actual. Puedes editar cada ajuste antes de guardar.</div>')+
        '<div class="vm-alert">Se conservan los sistemas originales de eventos, escaleras y Turbo. Esta vista representa la configuración, no una simulación del juego.</div>';
    }
    if(this.section==="control")return this.sectionCard("Movimiento del jugador",this.experience==="simple"?"LO ESENCIAL":"INPUT EN TIEMPO REAL",
      (this.experience==="simple"?["instant_turn","directions","flow_motion"]:OPTIONS_BY_GROUP("control")).map(k=>this.field(k)).join(""))+
      '<div class="vm-alert '+(classic?'warn':'good')+'">'+(classic?'En Clásico se utiliza la lectura original de cuatro direcciones. Continuous Flow y los controles diagonales modernos no se aplican.':'Moderno no guarda pulsaciones antiguas ni añade retrasos. El modo de 4 direcciones también está disponible.')+'</div>';
    if(this.section==="diagonal")return this.sectionCard("Comportamiento diagonal",this.experience==="simple"?"DIAGONALES SIN ESPERAS":"COLISIONES Y ORIENTACIÓN",
      (this.experience==="simple"?["diagonal_speed","diagonal_live_turn","wall_slide"]:OPTIONS_BY_GROUP("diagonal")).map(k=>this.field(k)).join(""))+
      '<div class="vm-alert">Estos ajustes solo afectan las diagonales del control moderno de 8 direcciones. No modifican velocidad de entrada, Turbo ni eventos del juego.</div>';
    if(this.section==="camera")return this.sectionCard("Seguimiento de cámara",this.experience==="simple"?"AJUSTES BÁSICOS":"COMPOSICIÓN",
      (this.experience==="simple"?["camera_smoothing","camera_lookahead"]:["camera_smoothing","camera_deadzone","camera_lookahead","camera_lead_response"]).map(k=>this.field(k)).join(""))+
      '<div class="vm-alert">35% de suavidad, zona muerta 0 y anticipación 0 conservan el comportamiento anterior de Vermeil. Estos controles no modifican la respuesta del jugador.</div>';
    if(this.section==="debug")return this.sectionCard("Diagnóstico visual","SOLO EN MODO DEBUG",this.field("debug_hud"))+
      this.sectionCard("Pruebas recomendadas","CHECKLIST",
        '<div class="vm-stack">'+["Cambiar entre control Clásico y Moderno","Caminar y girar frente a paredes y eventos","Entrar y salir de combate con Turbo","Comprobar seguidores, hielo, escaleras y Surf","Comparar cámara y zona muerta por mapa"].map((s,i)=>'<div style="font-size:11px;color:#bfd0e9;padding:6px 3px;border-bottom:1px solid #273247">'+(i+1)+'. '+E(s)+'</div>').join("")+'</div>')+
      '<div class="vm-alert">El HUD funciona exclusivamente con la versión Debug; no se habilita en una versión publicada.</div>';
    return "";
  }
  updatePreview(){
    const v=this.values(),classic=v.instant_turn==="0",dirs=classic?4:v.directions;
    const el=this.root.querySelector("[data-preview-svg]");
    if(el)el.innerHTML=svgPreview(v,this.direction);
    const text=(selector,value)=>{const node=this.root.querySelector(selector);if(node)node.textContent=value;};
    text("[data-stage-mode]",classic?"CLÁSICO":dirs+" DIRECCIONES");
    text("[data-stage-flow]","FLOW "+(classic?"NO DISPONIBLE":v.flow_motion==="1"?"ACTIVO":"OFF"));
    text("[data-stage-cam]","CÁMARA "+v.camera_smoothing+"%");
    text("[data-info-control]",classic?"Clásico Essentials":"Moderno inmediato");
    text("[data-info-directions]",dirs);
    text("[data-info-flow]",classic?"No disponible":v.flow_motion==="1"?"Activado":"Desactivado");
  }
  drawStatus(){
    const dirty=this.dirty();
    const dot=this.root.querySelector("[data-status-dot]");
    if(dot)dot.classList.toggle("dirty",dirty);
    const status=this.root.querySelector("[data-status]");
    if(status)status.textContent=this.message||(this.saving?"Guardando…":dirty?"Cambios sin guardar":"Todo guardado");
    const head=this.root.querySelector("[data-dirty-head]");
    if(head)head.textContent=dirty?"● Cambios sin guardar":"✓ Sin cambios";
    if(head)head.classList.toggle("warn",dirty);
    const btn=this.root.querySelector('[data-act="save"]');
    if(btn)btn.disabled=this.saving;
  }
  edit(key,value,redraw){
    if(!Object.prototype.hasOwnProperty.call(FIELDS,key))return;
    const current=this.values(),isClassic=current.instant_turn==="0";
    if(isClassic && ["directions","flow_motion","diagonal_speed","diagonal_live_turn","wall_slide","wall_slide_priority","diagonal_facing"].includes(key))return;
    if((isClassic||current.directions!=="8")&&["diagonal_speed","diagonal_live_turn","wall_slide","wall_slide_priority","diagonal_facing"].includes(key))return;
    if(key==="wall_slide_priority"&&current.wall_slide==="0")return;
    if(key==="camera_lead_response"&&current.camera_lookahead==="0")return;
    if(FIELDS[key].options&&!FIELDS[key].options.some(row=>row[0]===value))return;
    if(!FIELDS[key].options && (!Number.isFinite(Number(value)) || Number(value)<FIELDS[key].min || Number(value)>FIELDS[key].max))return;
    const scope=this.currentScope();
    this.config[scope]||={};
    this.config[scope][key]=String(value);
    this.message="";
    this.reloadConfirm=false;
    if(redraw)this.render();
    else {
      const el=this.root.querySelector('[data-range-readout="'+key+'"]');
      if(el)el.textContent=value+(FIELDS[key].unit||"");
      this.updatePreview();
      this.drawStatus();
    }
  }
  async click(e){
    const t=e.target.closest("button");
    if(!t || !this.root.contains(t))return;
    const experience=t.getAttribute("data-experience");
    if(experience==="simple"||experience==="advanced"){
      this.experience=experience;
      if(experience==="simple"&&this.section==="debug")this.section="overview";
      this.render();return;
    }
    const section=t.getAttribute("data-section");
    if(section){this.section=section;this.reloadConfirm=false;this.render();return;}
    const direction=t.getAttribute("data-direction");
    if(direction){this.direction=Number(direction);this.updatePreview();this.root.querySelectorAll("[data-direction]").forEach(btn=>btn.classList.toggle("active",btn.getAttribute("data-direction")===direction));return;}
    const inherit=t.getAttribute("data-inherit");
    if(inherit){
      if(this.scope==="map"){
        const settings=this.config[this.currentScope()];
        if(settings)delete settings[inherit];
      }else{
        this.config.global||={};
        this.config.global[inherit]=DEFAULTS[inherit];
      }
      this.message="";this.render();return;
    }
    const preset=t.getAttribute("data-preset");
    if(preset){
      const classic={directions:"4",instant_turn:"0",flow_motion:"0",wall_slide:"0",diagonal_facing:"keep",wall_slide_priority:"horizontal",camera_lookahead:"0",camera_deadzone:"0",camera_lead_response:"120",camera_smoothing:"35"};
      const modern={directions:"8",instant_turn:"1",flow_motion:"1",wall_slide:"1",diagonal_facing:"keep",diagonal_speed:"quick",diagonal_live_turn:"1",wall_slide_priority:"facing",camera_lookahead:"16",camera_deadzone:"8",camera_lead_response:"120",camera_smoothing:"35"};
      const modern4={...modern,directions:"4",wall_slide:"0",camera_lookahead:"0",camera_deadzone:"0"};
      const k=this.currentScope();
      this.config[k]={...(this.config[k]||{}),...(preset==="classic"?classic:preset==="modern4"?modern4:modern)};
      this.message="Perfil "+(preset==="classic"?"Clásico":preset==="modern4"?"Moderno 4 direcciones":"Moderno 8 direcciones")+" preparado; pulsa Guardar.";
      this.render();return;
    }
    const action=t.getAttribute("data-act");
    if(action==="save"){await this.save();return;}
    if(action==="reload"){
      if(this.dirty()&&!this.reloadConfirm){
        this.reloadConfirm=true;
        t.textContent="Descartar cambios";
        this.message="Vuelve a pulsar Recargar para descartar los cambios sin guardar.";
        this.drawStatus();return;
      }
      this.reloadConfirm=false;
      await this.load();
      return;
    }
  }
  change(e){
    const input=e.target;
    if(!input||!this.root.contains(input))return;
    if(input.hasAttribute("data-scope")){
      const id=mapId(this.ctx);
      if(input.value==="map"){
        if(!id){this.toast("Abre primero un mapa para editar su perfil","error");this.render();return;}
        this.scope="map";this.map=id;
      }else{this.scope="global";this.map=null;}
      this.message="";this.render();return;
    }
    const key=input.getAttribute("data-key");
    if(key)this.edit(key,input.value,true);
  }
  input(e){
    const el=e.target;
    const key=el && el.getAttribute("data-key");
    if(key && FIELDS[key] && !FIELDS[key].options)this.edit(key,el.value,false);
  }
}
export function activate(ctx) {
  const PANEL_ID="vermeil.movement-studio";
  ctx.ui.registerPanel({
    id:PANEL_ID,
    title:"Movement Studio",
    icon:"move",
    defaultPosition:"right",
    defaultSize:{width:1400,height:860},
    showInMenu:!(ctx.menu && typeof ctx.menu.registerMenuItem==="function"),
    render(host){return new MovementStudio(ctx,host);}
  });
  if(ctx.menu && typeof ctx.menu.registerMenuItem==="function"){
    ctx.menu.registerMenuItem({menu:"Mods",label:"Movement Studio",icon:"move",handler(){return ctx.ui.openPanel(PANEL_ID);}});
  }
  if(ctx.commands && typeof ctx.commands.register==="function"){
    ctx.commands.register("vermeil.movement-studio.open",()=>ctx.ui.openPanel(PANEL_ID));
  }
}
