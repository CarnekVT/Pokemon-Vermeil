import {AURA_PROFILES} from "./scene-fx.js";
import {timelineGroups} from "./timing.js";
export const FORMAT_VERSION = 1;
export const SAVE_DIR = "Data/SceneDirector";
export const SAVE_FILE = `${SAVE_DIR}/scenes.json`;

export function uid(prefix="id") { return `${prefix}_${Date.now().toString(36)}_${Math.random().toString(36).slice(2,8)}`; }
export function clone(v){ return JSON.parse(JSON.stringify(v)); }

export function createProject(){
  return { formatVersion: FORMAT_VERSION, settings:{ previewAutoAdvance:false, previewZoom:1 }, editor:{lastSceneId:null}, scenes:[] };
}
export function createScene(name="Nueva escena", template="blank"){
  const s={id:uid("scene"), key:slug(name)||`scene_${Date.now().toString(36)}`, name, author:"", notes:"", commands:[]};
  if(template==="dialogue") s.commands=[
    cmd("fade_from_black",{duration:20}),
    cmd("text_inline",{text:"Este es un diálogo de ejemplo.",speaker:"Narrador",speed:"normal"}),
    cmd("hide_textbox",{duration:10})
  ];
  if(template==="cinematic") s.commands=[
    cmd("bgm",{name:""}),cmd("wait",{frames:15}),cmd("show",{filename:"",x:0,y:0,fade:25,origin:"top_left",zoom:1}),
    cmd("fade_from_black",{duration:25}),cmd("text_inline",{text:"Una escena cinematográfica sencilla.",speaker:"???",speed:"slow"}),cmd("fade_to_black",{duration:20})
  ];
  return s;
}
export function cmd(type, data={}){ return {id:uid("cmd"),type,...defaultsFor(type),...data}; }
export function defaultsFor(type){
  switch(type){
    case "section": return {label:"Nueva sección"};
    case "image_transform": return {targetId:"",filename:"",duration:36,transition:"flash",sheetColumns:1,sheetRows:1,sheetFps:8};
    case "scene_fx": {const a=AURA_PROFILES[0];return {targetId:"",profile:a.id,pattern:a.pattern,color:a.color,blend:a.blend,count:a.count,cycle:a.cycle,rangeX:a.rangeX,rangeY:a.rangeY,scale:a.scale,sway:a.sway,opacity:a.opacity,outline:a.outline,outlineColor:a.outlineColor,graphics:a.graphics.slice(),filename:"",x:320,y:240,z:450,life:0};}
    case "scene_fx_stop": return {targetId:"",fade:18};
    case "scene_backdrop": return {color:"#000000",opacity:255,z:190};
    case "scene_player_form": return {playerId:1};
    case "parallel_anchor": return {};
    case "wait": return {frames:20};
    case "bgm": case "bgs": case "se": return {name:""};
    case "stop_bgm": return {fadeSeconds:0};
    case "fade_bgm": return {fadeSeconds:1.5};
    case "stop_bgs": return {};
    case "fade_from_black": case "fade_to_black": case "to_white": return {duration:20};
    case "from_white": return {duration:20,se:""};
    case "image_clip": return {filename:"",x:320,y:240,origin:"center",zoom:1,angle:0,opacity:255,z:null,duration:120,enter:"fade",inFrames:24,exit:"none",outFrames:24,keep:true,motion:"none",distance:64,easing:"smooth",endX:320,endY:240,endZoom:1,endAngle:0,endOpacity:255,keys:[],resourceType:"static",columns:1,rows:1,sheetFps:8,sheetMode:"loop",sheetStart:1,sheetEnd:0,sheetFrame:1,sheetPersistent:false};
    case "show": return {filename:"",x:0,y:0,fade:20,origin:"top_left",zoom:1,z:null,store:""};
    case "hide": return {filename:"",fade:0,targetId:""};
    case "hide_all": return {fade:0};
    case "textbox_style": return {skin:""};
    case "text_inline": return {text:"",speaker:"",speed:"normal",formatArgs:[],skin:"",skinReset:false,nameSkin:"",speakerColor:"",speakerShadow:""};
    case "show_centered_text": return {text:"",speed:"normal",color:[0,0,0]};
    case "hide_centered_text": return {};
    case "show_textbox": case "hide_textbox": return {duration:10};
    case "end_scene": return {endStyle:"fade",fadeFrames:24,holdFrames:12,breathFrames:18};
    case "wait_confirm": return {};
    case "next_scene": return {sceneKey:""};
    case "common_event": return {eventId:1};
    case "set_switch": return {switchId:1,value:true};
    case "set_variable": return {variableId:1,value:0};
    case "transfer_player": return {mapId:1,x:0,y:0,direction:2};
    case "name_input": case "custom_name_input": return {default:"Solen",min:1,max:12,store:"player_name"};
    case "treatment_input": return {default:"neutro",store:"treatment"};
    case "treatment_text": return {masculino:"",femenino:"",neutro:"",speaker:"",speed:"normal"};
    case "show_floating": return {filename:"",x:0,y:0,amplitude:8,speed:0.05,z:null,zoom:1,opacity:255,fade:0,store:""};
    case "hide_floating": return {};
    case "float_sprite": return {filename:"",frameWidth:96,frameHeight:96,frames:6,x:0,y:0,endY:160,speed:0.7,fps:6,ghostInterval:1,bg:false,glow:false,fade:20};
    case "stop_float": return {fade:0};
    case "change_float_bitmap": return {filename:""};
    case "start_aura": return {filename:"",frameWidth:12,frameHeight:12,count:8,rangeX:30,rangeY:60,duration:120};
    case "stop_aura": return {};
    case "start_scrolling": return {filename:"",x:0,y:0,speed:1,z:null,mirror:false,horizontal:false};
    case "stop_scrolling": return {};
    case "fade_out_images": return {duration:20,filenames:[]};
    case "fade_out_floating": case "fade_out_scrolling": case "fade_in_scrolling": return {duration:20};
    case "fade_out_sprites": return {targetsRuby:"[]",duration:20};
    case "script": return {code:"# Ruby avanzado conservado por Scene Director\n"};
    default: return {};
  }
}
export function slug(s){return String(s||"").trim().toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g,"").replace(/[^a-z0-9]+/g,"_").replace(/^_+|_+$/g,"");}
export function normalizeProject(p){
  const out=p&&typeof p==="object"?p:createProject(); out.formatVersion=FORMAT_VERSION; out.settings={...createProject().settings,...(out.settings||{})}; out.editor=out.editor||{};
  out.scenes=Array.isArray(out.scenes)?out.scenes:[];
  out.scenes.forEach(s=>{s.id=s.id||uid("scene");s.key=s.key||slug(s.name)||uid("scene");s.name=s.name||s.key;s.commands=Array.isArray(s.commands)?s.commands:[];s.commands.forEach(c=>{c.id=c.id||uid("cmd");});});
  return out;
}

export function commandStateSignature(c){
  const clean={};
  for(const [k,v] of Object.entries(c||{})){
    if(k==="afterId"||k.startsWith("condition")||k==="overlapParent"||k==="offsetFrames"||k==="id"||k==="sourceRuby"||k==="sourceState"||k==="sourceLine"||k==="sourceFile")continue;
    clean[k]=v;
  }
  return JSON.stringify(clean);
}

const q=s=>JSON.stringify(String(s??""));
const sym=s=>`:${String(s||"normal").replace(/^:/,"")}`;
const n=v=>v&&typeof v==="object"&&v.kind==="ruby"?String(v.value||"0"):Number.isFinite(Number(v))?String(Number(v)):"0";
const rubyColor=a=>`Color.new(${(a||[0,0,0]).map(x=>Math.round(Number(x)||0)).slice(0,3).join(", ")})`;
const kw=(obj,keys)=>keys.filter(k=>obj[k]!==undefined&&obj[k]!==null&&obj[k]!=="").map(k=>`${k.replace(/[A-Z]/g,m=>"_"+m.toLowerCase())}: ${rubyLiteral(obj[k])}`).join(", ");
function rubyLiteral(v){
  if(v&&typeof v==="object"&&v.kind==="ruby")return String(v.value||"nil");
  if(v===null||v===undefined)return "nil"; if(typeof v==="boolean")return v?"true":"false"; if(typeof v==="number")return n(v); if(Array.isArray(v))return `[${v.map(rubyLiteral).join(", ")}]`; return q(v);
}
function formatArgRuby(v){ if(v&&typeof v==="object"&&v.kind==="var")return String(v.value||"nil"); return rubyLiteral(v&&typeof v==="object"&&"value" in v?v.value:v); }
export function commandToRuby(c){const code=commandBody(c);if(!c.conditionKind||c.conditionKind==="none")return code;const id=Math.max(1,Math.round(Number(c.conditionId)||1));const test=c.conditionKind==="switch"?`$game_switches[${id}] == ${c.conditionSwitch!==false}`:`$game_variables[${id}] ${["==","!=","<",">","<=",">="].includes(c.conditionOp)?c.conditionOp:"=="} ${Number(c.conditionValue)||0}`;return `if ${test}\n${code.split("\n").map(s=>"  "+s).join("\n")}\nend`;}
function commandBody(c){
  if(c?.sourceRuby && c?.sourceState && c.sourceState===commandStateSignature(c)) return String(c.sourceRuby);
  const pre=c.store&&/^[a-z_]\w*$/i.test(c.store)?`${c.store} = `:"";
  switch(c.type){
    case "section": return `# ══════════ ${String(c.label||"SECCIÓN").toUpperCase()} ══════════`;
    case "image_transform": return `scene_transform ${q(c.targetId)}, ${q(c.filename)}, duration: ${n(c.duration)}, transition: ${q(c.transition)}, columns: ${n(c.sheetColumns)}, rows: ${n(c.sheetRows)}, fps: ${n(c.sheetFps)}`;
    case "scene_fx": return `scene_fx ${q(c.id)}, ${q(c.targetId)}, ${rubyLiteral(c.filename?[c.filename]:c.graphics||[])}, ${["pattern","color","blend","count","cycle","rangeX","rangeY","scale","sway","opacity","outline","outlineColor","x","y","z","life"].map(k=>k.replace(/[A-Z]/g,m=>"_"+m.toLowerCase())+": "+rubyLiteral(c[k])).join(", ")}`;
    case "scene_fx_stop": return `scene_fx_stop ${q(c.targetId||"")}, fade: ${n(c.fade)}`;
    case "scene_backdrop": return `scene_backdrop ${q(c.color)}, ${n(c.opacity)}, ${n(c.z)}`;
    case "scene_player_form": return `pbChangePlayer(${n(c.playerId)})`;
    case "parallel_anchor": return `wait ${Math.max(0,Number(c.frames)||0)}`;
    case "wait": return `wait ${n(c.frames)}`;
    case "bgm": return `bgm ${q(c.name)}`; case "bgs": return `bgs ${q(c.name)}`; case "se": return `se ${q(c.name)}`;
    case "fade_bgm": return `scene_fade_bgm ${n(c.fadeSeconds)}`;
    case "stop_bgm": return `stop_bgm ${n(c.fadeSeconds)}`; case "stop_bgs": return `stop_bgs`;
    case "fade_from_black": case "fade_to_black": case "to_white": return `${c.type} ${n(c.duration)}`;
    case "from_white": return `from_white ${n(c.duration)}${c.se?`, se: ${q(c.se)}`:""}`;
    case "show_textbox": case "hide_textbox": return `${c.type} ${n(c.duration)}`;
    case "image_clip": {const keys=["origin","zoom","angle","opacity","z","duration","enter","inFrames","exit","outFrames","keep","motion","distance","easing","endX","endY","endZoom","endAngle","endOpacity","keys","resourceType","columns","rows","sheetFps","sheetMode","sheetStart","sheetEnd","sheetFrame","sheetPersistent"];return `image_clip ${q(c.filename)}, ${n(c.x)}, ${n(c.y)}, ${kw(c,keys)}, instance_id: ${q(c.id)}`;}
    case "show": { const opts=[]; if(c.fade!==undefined)opts.push(`fade: ${n(c.fade)}`); if(c.origin)opts.push(`origin: ${sym(c.origin)}`); if(c.zoom!==undefined)opts.push(`zoom: ${n(c.zoom)}`); if(c.z!==null&&c.z!==undefined&&c.z!=="")opts.push(`z: ${n(c.z)}`); return `${pre}show ${q(c.filename)}, ${n(c.x)}, ${n(c.y)}${opts.length?`, ${opts.join(", ")}`:""}`; }
    case "hide": return `hide ${c.filename?q(c.filename):"nil"}, fade: ${n(c.fade)}${c.targetId?`, instance_id: ${q(c.targetId)}`:""}`;
    case "hide_all": return `hide_all fade: ${n(c.fade)}`;
    case "textbox_style": return `set_scene_textbox ${q(c.skin||"")}`;
    case "text_inline": { const opts=[]; if(c.skin||c.skinReset)opts.push(`skin: ${q(c.skin||"")}`); if(c.nameSkin)opts.push(`name_skin: ${q(c.nameSkin)}`); if(/^#[0-9a-f]{6}$/i.test(c.speakerColor||""))opts.push(`speaker_color: ${q(c.speakerColor)}`); if(/^#[0-9a-f]{6}$/i.test(c.speakerShadow||""))opts.push(`speaker_shadow: ${q(c.speakerShadow)}`); if(c.speaker)opts.push(`speaker: ${q(c.speaker)}`); opts.push(`speed: ${sym(c.speed)}`); if(c.formatArgs&&c.formatArgs.length)opts.push(`format_args: [${c.formatArgs.map(formatArgRuby).join(", ")}]`); return `text_inline ${q(c.text)}${opts.length?`, ${opts.join(", ")}`:""}`; }
    case "show_centered_text": return `show_centered_text ${q(c.text)}, speed: ${sym(c.speed)}, color: ${rubyColor(c.color)}`;
    case "hide_centered_text": return `hide_centered_text`;
    case "end_scene": return `end_scene style: ${q(c.endStyle||"cut")}, fade_frames: ${n(c.fadeFrames||0)}, hold_frames: ${n(c.holdFrames||0)}, breath_frames: ${n(c.breathFrames||0)}`;
    case "next_scene": return `next_scene ${q(c.sceneKey)}`;
    case "common_event": return `scene_common_event ${n(c.eventId)}`;
    case "set_switch": return `$game_switches[${n(c.switchId)}] = ${!!c.value}`;
    case "set_variable": return `$game_variables[${n(c.variableId)}] = ${n(c.value)}`;
    case "wait_confirm": return "scene_wait_confirm";
    case "transfer_player": return `transfer_player ${n(c.mapId)}, ${n(c.x)}, ${n(c.y)}, ${n(c.direction)}`;
    case "treatment_input": return `treatment_input(default: ${sym(c.default||"neutro")})`;
    case "treatment_text": return `treatment_text(masculino: ${q(c.masculino||"")}, femenino: ${q(c.femenino||"")}, neutro: ${q(c.neutro||"")}, speaker: ${q(c.speaker||"")}, speed: ${sym(c.speed||"normal")})`;
    case "name_input": case "custom_name_input": return `${pre||((c.store&&/^[a-z_]\w*$/i.test(c.store))?`${c.store} = `:"")}${c.type}(default: ${q(c.default)}, min: ${n(c.min)}, max: ${n(c.max)})`;
    case "show_floating": {const o=[`amplitude: ${n(c.amplitude)}`,`speed: ${n(c.speed)}`,`zoom: ${n(c.zoom)}`,`opacity: ${n(c.opacity)}`,`fade: ${n(c.fade)}`];if(c.z!==null&&c.z!==undefined&&c.z!=="")o.push(`z: ${n(c.z)}`);return `${pre}show_floating ${q(c.filename)}, ${n(c.x)}, ${n(c.y)}, ${o.join(", ")}`;}
    case "hide_floating": return `hide_floating`;
    case "float_sprite": return `float_sprite ${q(c.filename)}, ${n(c.frameWidth)}, ${n(c.frameHeight)}, ${n(c.frames)}, ${n(c.x)}, ${n(c.y)}, end_y: ${n(c.endY)}, speed: ${n(c.speed)}, fps: ${n(c.fps)}, ghost_interval: ${n(c.ghostInterval)}, bg: ${!!c.bg}, glow: ${!!c.glow}, fade: ${n(c.fade)}`;
    case "stop_float": return `stop_float fade: ${n(c.fade)}`;
    case "change_float_bitmap": return `change_float_bitmap ${q(c.filename)}`;
    case "start_aura": return `start_aura ${q(c.filename)}, ${n(c.frameWidth)}, ${n(c.frameHeight)}, count: ${n(c.count)}, range_x: ${n(c.rangeX)}, range_y: ${n(c.rangeY)}, duration: ${n(c.duration)}`;
    case "stop_aura": return `stop_aura`;
    case "start_scrolling": {const o=[`speed: ${n(c.speed)}`];if(c.z!==null&&c.z!==undefined&&c.z!=="")o.push(`z: ${n(c.z)}`);if(c.mirror)o.push(`mirror: true`);if(c.horizontal)o.push(`horizontal: true`);return `start_scrolling ${q(c.filename)}, ${n(c.x)}, ${n(c.y)}, ${o.join(", ")}`;}
    case "stop_scrolling": return `stop_scrolling`;
    case "fade_out_images": return `fade_out_images ${n(c.duration)}${c.filenames&&c.filenames.length?`, ${rubyLiteral(c.filenames)}`:""}`;
    case "fade_out_floating": case "fade_out_scrolling": case "fade_in_scrolling": return `${c.type} ${n(c.duration)}`;
    case "fade_out_sprites": return `fade_out_sprites(${String(c.targetsRuby||"[]")}, ${n(c.duration)})`;
    case "script": return String(c.code||"");
    default: return `# Unsupported command: ${c.type}`;
  }
}
export function compileScene(scene){return timelineGroups(scene).map(g=>{
 if(!g.events.length)return (g.root.afterId&&g.root.afterDelay?`wait ${Math.max(0,Math.round(Number(g.root.afterDelay)||0))}\n`:"")+commandToRuby(g.root);
 const rows=[{c:g.root,offset:0,lane:"main"},...g.events.map(e=>({c:e.c,offset:e.requested,lane:e.lane,after:e.after,delay:e.delay}))];
 return "parallel_scene([\n"+rows.map(e=>"  ["+e.offset+", "+q(e.lane)+", proc {\n"+commandToRuby(e.c).split("\n").map(s=>"    "+s).join("\n")+"\n  }, "+q(e.c.id)+", "+(e.after?q(e.after):"nil")+", "+(e.delay||0)+"]").join(",\n")+"\n])";
 }).join("\n\n")}
export function compileProject(project){ const p=clone(project); p.scenes.forEach(s=>s.compiledRuby=compileScene(s)); return p; }

export const COMMAND_GROUPS=[
  {id:"control",label:"Control de escena",items:[["end_scene","■ Finalizar escena"],["next_scene","▶ Reproducir otra escena"],["common_event","↪ Evento común al salir"],["wait_confirm","◇ Esperar confirmación"],["set_switch","✓ Cambiar interruptor"],["set_variable","= Cambiar variable"],["hide_textbox","▭ Cerrar diálogo"],["transfer_player","↪ Transferir jugador"]]},
  {id:"basic",label:"Flujo",items:[["section","§ Sección"],["wait","⏱ Esperar"],["script","</> Ruby avanzado"],["name_input","⌨ Nombre vanilla"],["custom_name_input","✦ Nombre Vermeil"],["treatment_input","◀ Seleccionar tratamiento"],["transfer_player","↪ Transferir jugador"]]},
  {id:"visual",label:"Imágenes",items:[["image_clip","▣ Clip de imagen"],["show","▣ Mostrar imagen (instantánea)"],["hide","◫ Ocultar imagen"],["hide_all","◫ Ocultar todas"],["show_floating","↕ Imagen flotante"],["hide_floating","↕ Detener flotantes"],["float_sprite","▤ Spritesheet flotante"],["change_float_bitmap","▤ Cambiar spritesheet"]]},
  {id:"screen",label:"Pantalla",items:[["fade_from_black","◐ Desde negro"],["fade_to_black","◑ A negro"],["to_white","◻ A blanco"],["from_white","◻ Desde blanco"]]},
  {id:"dialog",label:"Texto",items:[["text_inline","💬 Diálogo"],["treatment_text","💬 Diálogo por tratamiento"],["show_centered_text","T Texto centrado"],["hide_centered_text","T Ocultar centrado"],["textbox_style","▭ Estilo de cuadro"],["show_textbox","▭ Reaparecer cuadro de texto"],["hide_textbox","▭ Desaparecer cuadro de texto"]]},
  {id:"cinematicfx",label:"Transformación y efectos",items:[["image_transform","✧ Transformar imagen"],["scene_fx","✦ Aura / partículas (BSS)"],["scene_fx_stop","■ Detener efecto"],["scene_backdrop","▣ Fondo de color"],["scene_player_form","Cambiar personaje jugador"]]},
  {id:"motion",label:"FX",items:[["start_scrolling","⇢ Scroll"],["stop_scrolling","■ Detener scroll"],["start_aura","✦ Aura"],["stop_aura","✦ Detener aura"],["fade_in_scrolling","⇢ Fade in scroll"],["fade_out_scrolling","⇢ Fade out scroll"],["fade_out_floating","↕ Fade out flotantes"],["fade_out_images","▣ Fade out imágenes"],["fade_out_sprites","◫ Fade refs Ruby"]]},
  {id:"audio",label:"Audio",items:[["bgm","♫ BGM"],["bgs","≈ BGS"],["se","♪ SE"],["fade_bgm","♫ Desvanecer música"],["stop_bgm","♫ Detener BGM"],["stop_bgs","≈ Detener BGS"]]}
];
