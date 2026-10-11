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
    case "wait": return {frames:20};
    case "bgm": case "bgs": case "se": return {name:""};
    case "stop_bgm": return {fadeSeconds:0};
    case "stop_bgs": return {};
    case "fade_from_black": case "fade_to_black": case "to_white": return {duration:20};
    case "from_white": return {duration:20,se:""};
    case "show": return {filename:"",x:0,y:0,fade:20,origin:"top_left",zoom:1,z:null,store:""};
    case "hide": return {filename:"",fade:0};
    case "hide_all": return {fade:0};
    case "text_inline": return {text:"",speaker:"",speed:"normal",formatArgs:[]};
    case "show_centered_text": return {text:"",speed:"normal",color:[0,0,0]};
    case "hide_centered_text": return {};
    case "show_textbox": case "hide_textbox": return {duration:10};
    case "transfer_player": return {mapId:1,x:0,y:0,direction:2};
    case "name_input": return {default:"Solen",min:1,max:12,store:"player_name"};
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
    if(k==="id"||k==="sourceRuby"||k==="sourceState"||k==="sourceLine"||k==="sourceFile")continue;
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
export function commandToRuby(c){
  if(c?.sourceRuby && c?.sourceState && c.sourceState===commandStateSignature(c)) return String(c.sourceRuby);
  const pre=c.store&&/^[a-z_]\w*$/i.test(c.store)?`${c.store} = `:"";
  switch(c.type){
    case "section": return `# ══════════ ${String(c.label||"SECCIÓN").toUpperCase()} ══════════`;
    case "wait": return `wait ${n(c.frames)}`;
    case "bgm": return `bgm ${q(c.name)}`; case "bgs": return `bgs ${q(c.name)}`; case "se": return `se ${q(c.name)}`;
    case "stop_bgm": return `stop_bgm ${n(c.fadeSeconds)}`; case "stop_bgs": return `stop_bgs`;
    case "fade_from_black": case "fade_to_black": case "to_white": return `${c.type} ${n(c.duration)}`;
    case "from_white": return `from_white ${n(c.duration)}${c.se?`, se: ${q(c.se)}`:""}`;
    case "show_textbox": case "hide_textbox": return `${c.type} ${n(c.duration)}`;
    case "show": { const opts=[]; if(c.fade!==undefined)opts.push(`fade: ${n(c.fade)}`); if(c.origin)opts.push(`origin: ${sym(c.origin)}`); if(c.zoom!==undefined)opts.push(`zoom: ${n(c.zoom)}`); if(c.z!==null&&c.z!==undefined&&c.z!=="")opts.push(`z: ${n(c.z)}`); return `${pre}show ${q(c.filename)}, ${n(c.x)}, ${n(c.y)}${opts.length?`, ${opts.join(", ")}`:""}`; }
    case "hide": return `hide ${c.filename?q(c.filename):"nil"}, fade: ${n(c.fade)}`;
    case "hide_all": return `hide_all fade: ${n(c.fade)}`;
    case "text_inline": { const opts=[]; if(c.speaker)opts.push(`speaker: ${q(c.speaker)}`); opts.push(`speed: ${sym(c.speed)}`); if(c.formatArgs&&c.formatArgs.length)opts.push(`format_args: [${c.formatArgs.map(formatArgRuby).join(", ")}]`); return `text_inline ${q(c.text)}${opts.length?`, ${opts.join(", ")}`:""}`; }
    case "show_centered_text": return `show_centered_text ${q(c.text)}, speed: ${sym(c.speed)}, color: ${rubyColor(c.color)}`;
    case "hide_centered_text": return `hide_centered_text`;
    case "transfer_player": return `transfer_player ${n(c.mapId)}, ${n(c.x)}, ${n(c.y)}, ${n(c.direction)}`;
    case "name_input": return `${pre||((c.store&&/^[a-z_]\w*$/i.test(c.store))?`${c.store} = `:"")}name_input(default: ${q(c.default)}, min: ${n(c.min)}, max: ${n(c.max)})`;
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
export function compileScene(scene){ return (scene.commands||[]).map(commandToRuby).join("\n\n"); }
export function compileProject(project){ const p=clone(project); p.scenes.forEach(s=>s.compiledRuby=compileScene(s)); return p; }

export const COMMAND_GROUPS=[
  {id:"basic",label:"Flujo",items:[["section","§ Sección"],["wait","⏱ Esperar"],["script","</> Ruby avanzado"],["name_input","⌨ Pedir nombre"],["transfer_player","↪ Transferir jugador"]]},
  {id:"visual",label:"Imágenes",items:[["show","▣ Mostrar imagen"],["hide","◫ Ocultar imagen"],["hide_all","◫ Ocultar todas"],["show_floating","↕ Imagen flotante"],["hide_floating","↕ Detener flotantes"],["float_sprite","▤ Spritesheet flotante"],["change_float_bitmap","▤ Cambiar spritesheet"]]},
  {id:"screen",label:"Pantalla",items:[["fade_from_black","◐ Desde negro"],["fade_to_black","◑ A negro"],["to_white","◻ A blanco"],["from_white","◻ Desde blanco"]]},
  {id:"dialog",label:"Texto",items:[["text_inline","💬 Diálogo"],["show_centered_text","T Texto centrado"],["hide_centered_text","T Ocultar centrado"],["show_textbox","▭ Mostrar caja"],["hide_textbox","▭ Ocultar caja"]]},
  {id:"motion",label:"FX",items:[["start_scrolling","⇢ Scroll"],["stop_scrolling","■ Detener scroll"],["start_aura","✦ Aura"],["stop_aura","✦ Detener aura"],["fade_in_scrolling","⇢ Fade in scroll"],["fade_out_scrolling","⇢ Fade out scroll"],["fade_out_floating","↕ Fade out flotantes"],["fade_out_images","▣ Fade out imágenes"],["fade_out_sprites","◫ Fade refs Ruby"]]},
  {id:"audio",label:"Audio",items:[["bgm","♫ BGM"],["bgs","≈ BGS"],["se","♪ SE"],["stop_bgm","♫ Detener BGM"],["stop_bgs","≈ Detener BGS"]]}
];
