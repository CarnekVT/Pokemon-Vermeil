const PATH = "Plugins/[VERMEIL] Bifrost Capture/config.ini";
const FIELDS = {
  profile:["Perfil",["bifrost","classic","adventure","safari","custom"]],
  enabled:["Sistema activo",["1","0"]],
  access_mode:["Disponibilidad de lanzamiento",["event","always","nearby"]],
  hotkey:["Tecla de apuntado",["aux2","aux1","none"]],
  capture_enabled:["Captura OW",["1","0"]],
  battle_enabled:["Iniciar combate OW",["1","0"]],
  restricted_species:["Solo legendarios Bifröst",["1","0"]],
  range:["Alcance máximo",1,20],
  width:["Ancho del área",1,19],
  optimal_range:["Distancia óptima",1,20],
  alert_distance:["Distancia de alerta",0,20],
  hit_near:["Precisión cercana (%)",0,100],
  hit_far:["Precisión lejana (%)",0,100],
  capture_floor:["Probabilidad base mínima (%)",0,100],
  back_multiplier:["Bono desde atrás (%)",100,500],
  critical_front:["Crítica frontal (%)",0,100],
  critical_back:["Crítica por espalda (%)",0,100],
  critical_multiplier:["Potenciador de captura crítica (%)",100,600],
  line_of_sight:["Bloqueo por obstáculos",["1","0"]],
  reaction:["Reacción ante peligro",["flee","attack","ignore"]],
  consume_on_miss:["Consumir Ball al fallar",["1","0"]],
  impact_frames:["Fotogramas de impacto",0,12]
};
const DEFAULTS = {
 profile:"bifrost",enabled:"1",access_mode:"event",hotkey:"aux2",capture_enabled:"1",battle_enabled:"1",
 restricted_species:"1",range:"7",width:"7",optimal_range:"4",
 alert_distance:"3",hit_near:"96",hit_far:"60",capture_floor:"10",
 back_multiplier:"175",critical_front:"3",critical_back:"35",
 critical_multiplier:"250",line_of_sight:"1",reaction:"flee",
 consume_on_miss:"1",impact_frames:"3"
};
const PROFILES = {
 bifrost:{...DEFAULTS},classic:{...DEFAULTS,profile:"classic",capture_enabled:"0"},
 adventure:{...DEFAULTS,profile:"adventure",restricted_species:"0",reaction:"attack"},
 safari:{...DEFAULTS,profile:"safari",restricted_species:"0",battle_enabled:"0"},
 custom:{...DEFAULTS,profile:"custom"}
};
const esc=s=>String(s).replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
function parse(text){
 const sections={global:{...DEFAULTS}};let current="global";
 for(const row of String(text||"").split(/\r?\n/)){
  const line=row.replace(/[;#].*$/,"").trim();
  const h=/^\[(global|map:\d+|species:[a-z0-9_]+|event:\d+:\d+)\]$/i.exec(line);
  if(h){current=h[1].toLowerCase();sections[current]??={};continue;}
  const p=/^([a-z_]+)\s*=\s*([a-z0-9_]+)$/i.exec(line);
  if(p&&FIELDS[p[1].toLowerCase()])sections[current][p[1].toLowerCase()]=p[2].toLowerCase();
 }
 return sections;
}
function serialize(sections){
 const out=["; Bifrost Capture Studio v0.1 - configuracion por ambito",""];
 for(const [scope,settings] of Object.entries(sections)){
   out.push("["+scope+"]");
   for(const key of Object.keys(DEFAULTS))if(settings[key]!==undefined)out.push(key+"="+settings[key]);
   out.push("");
 }
 return out.join("\n");
}
const CSS=`
.bc{height:100%;background:#111924;color:#e6ecf6;font:12px "Segoe UI",sans-serif;display:flex;flex-direction:column;overflow:hidden}
.bc *{box-sizing:border-box}
.bc header{display:flex;align-items:center;gap:12px;border-bottom:1px solid #344256;background:#192433;padding:14px}
.bc header strong{font-size:16px}.bc header small{color:#abb9cb}.bc button,.bc select,.bc input{font:inherit}
.bc button{background:#2e4162;border:1px solid #607a9e;color:#eef2fa;padding:8px 12px;border-radius:7px;cursor:pointer}
.bc button:hover{background:#405a81}.bc button.primary{background:#5268b5}.bc button:disabled{opacity:.5}
.bc main{flex:1;overflow:auto;display:grid;grid-template-columns:minmax(280px,1fr) 330px;gap:18px;padding:18px}
.bc .panel{background:#1b2839;border:1px solid #354863;border-radius:10px;padding:16px}
.bc h2{margin:0 0 14px;font-size:14px}.bc label{display:grid;gap:5px;margin-bottom:13px;color:#dce8f6}
.bc label small{color:#93a9c5}.bc input,.bc select{background:#0e1826;color:white;padding:8px;border:1px solid #52627e;border-radius:5px;min-width:0}
.bc .grid{display:grid;grid-template-columns:1fr 1fr;gap:0 14px}.bc .status{padding:9px 15px;border-top:1px solid #3d4961;color:#a9bed8}
.bc .preview{display:grid;grid-template-columns:repeat(7,1fr);gap:3px;margin:16px 0}
.bc .cell{aspect-ratio:1;background:#293b54;border:1px solid #486484;border-radius:3px}
.bc .cell.opt{background:#547752;border-color:#9abb77}.bc .cell.out{background:#693737;border-color:#b86f6f}
.bc .notes{line-height:1.75;color:#a9bed6}.bc .spacer{flex:1}
@media(max-width:850px){.bc main{grid-template-columns:1fr}.bc header{flex-wrap:wrap}}
`;
class Studio {
 constructor(ctx,host){
  this.ctx=ctx;this.host=host;this.sections={global:{...DEFAULTS}};
  this.scope="global";this.baseline="";this.dirty=false;this.status="Cargando";
  this.root=document.createElement("div");this.root.className="bc";
  const style=document.createElement("style");style.textContent=CSS;
  host.replaceChildren(style,this.root);
  this.root.addEventListener("change",e=>this.changed(e));
  this.root.addEventListener("click",e=>this.clicked(e));
  this.render();this.load();
 }
 async load(){
  try{
   const text=await this.ctx.fs.projectExists(PATH)?await this.ctx.fs.readProjectFile(PATH):"";
   this.sections=parse(text);this.baseline=serialize(this.sections);
   this.dirty=false;this.status=text?"Configuración cargada":"Perfil Bifröst predeterminado";
  }catch(e){this.status="Error al cargar: "+e.message}
  this.render();
 }
 values(){return {...DEFAULTS,...this.sections.global,...(this.sections[this.scope]||{})};}
 scopes(){return ["global",...Object.keys(this.sections).filter(x=>x!=="global")];}
 render(){
  const v=this.values();const scope=this.scope;const ns=this.scopes();
  const fields=Object.keys(FIELDS).map(k=>{
   const f=FIELDS[k],options=f[1];
   let control;
   if(Array.isArray(options)){
    control='<select data-field="'+k+'">'+options.map(x=>'<option value="'+esc(x)+'"'+(v[k]===x?' selected':'')+'>'+esc(x==='1'?'Sí':x==='0'?'No':x)+'</option>').join("")+'</select>';
   }else control='<input data-field="'+k+'" type="number" min="'+f[1]+'" max="'+f[2]+'" value="'+esc(v[k])+'">';
   return '<label>'+esc(f[0])+control+'</label>';
  }).join("");
  const cols=7, max=Math.max(1,Number(v.range)),opt=Number(v.optimal_range);
  let cells="";
  for(let f=1;f<=8;f++)for(let c=0;c<cols;c++)
   cells+='<div class="cell '+(f>max?'out':f<=opt?'opt':'')+'" title="Fila '+f+' · Columna '+(c+1)+'"></div>';
  this.root.innerHTML='<header><div><strong>Bifröst Capture Studio</strong><div><small>Essentials 21.1 · perfiles reutilizables</small></div></div>'+
   '<span class="spacer"></span><select data-scope>'+ns.map(s=>'<option value="'+esc(s)+'"'+(s===scope?' selected':'')+'>'+esc(s)+'</option>').join("")+'</select>'+
   '<button data-action="scope">+ Ámbito</button><button data-action="reload">Recargar</button><button data-action="save" class="primary">Guardar</button></header>'+
   '<main><section class="panel"><h2>Reglas · '+esc(scope)+'</h2><div class="grid">'+fields+'</div>'+
   '<button data-action="preset">Aplicar perfil seleccionado</button> <button data-action="inherit">Restablecer ámbito</button></section>'+
   '<aside class="panel"><h2>Simulación de alcance</h2><p>7 columnas · fila 8 en rojo (fuera de alcance con Bifröst).</p>'+
   '<div class="preview">'+cells+'</div><p class="notes">Verde: dentro de distancia óptima.<br>Azul: lanzamiento más difícil.<br>Rojo: fuera de alcance.<br><br>'+
   'Bifröst: solo legendarios indicados. Classic: sin captura fuera de combate. Adventure: cualquier especie etiquetada. Safari: captura sin iniciar combates.</p>'+
   '<p class="notes"><b>Disponibilidad:</b> event = solo desde evento/objeto; always = abrir apuntado en todo mapa jugable, incluso sin Pokémon cercano; nearby = abrir solo si hay un OW elegible delante. Con la tecla Aux2 (R) o Aux1 (L). none desactiva el atajo sin bloquear pbBifrostAim.</p>'+
   '<p class="notes">El mapa y los eventos se configuran por etiquetas [OWCAP:ESPECIE:NIVEL]. Los Pokémon [OWDECOR] son decorativos.</p></aside></main>'+
   '<footer class="status">'+esc(this.dirty?"● Cambios sin guardar · ":"✓ ")+esc(this.status)+' · '+esc(PATH)+'</footer>';
 }
 changed(e){
  const t=e.target;
  if(t.matches("[data-scope]")){this.scope=t.value;this.render();return}
  const k=t.getAttribute("data-field");if(!FIELDS[k])return;
  const f=FIELDS[k];let val=t.value;
  if(!Array.isArray(f[1])){
   const n=Number(val);if(!Number.isInteger(n)||n<f[1]||n>f[2]){this.render();return}
   val=String(n);
  }
  if(k==="width"&&Number(val)%2===0){val=String(Math.max(1,Number(val)-1))}
  this.sections[this.scope]??={};this.sections[this.scope][k]=val;
  this.dirty=serialize(this.sections)!==this.baseline;
  this.status="Cambios preparados";this.render();
 }
 async clicked(e){
  const btn=e.target.closest("button");if(!btn)return;
  const action=btn.dataset.action;
  if(action==="reload"){
   if(this.dirty&&!window.confirm("¿Descartar los cambios sin guardar?"))return;
   await this.load();
  }
  if(action==="scope"){
   const scope=window.prompt("Nuevo ámbito: map:12, species:RAIKOU o event:12:4");
   if(!scope||! /^(map:\d+|species:[a-z0-9_]+|event:\d+:\d+)$/i.test(scope.trim()))return;
   this.scope=scope.trim().toLowerCase();this.sections[this.scope]??={};
   this.dirty=true;this.render();
  }
  if(action==="preset"){
   const profile=this.values().profile;
   this.sections[this.scope]={...PROFILES[profile]};
   this.dirty=true;this.status="Perfil aplicado; guarda para utilizarlo";this.render();
  }
  if(action==="inherit"){
   if(this.scope==="global")this.sections.global={...DEFAULTS};
   else delete this.sections[this.scope];
   if(!this.sections[this.scope])this.scope="global";
   this.dirty=true;this.render();
  }
  if(action==="save"){
   try{
    const content=serialize(this.sections);
    await this.ctx.fs.writeProjectFile(PATH,content);
    const check=await this.ctx.fs.readProjectFile(PATH);
    if(check!==content)throw new Error("Verificación del archivo fallida");
    this.baseline=content;this.dirty=false;this.status="Guardado y verificado";
    this.ctx.ui.showToast?.({message:"Bifröst: ajustes guardados",level:"info"});
   }catch(e){this.status="No se pudo guardar: "+e.message}
   this.render();
  }
 }
}
export function activate(ctx){
 const id="vermeil.bifrost-capture";
 ctx.ui.registerPanel({
  id,title:"Bifröst Capture Studio",icon:"target",defaultPosition:"right",
  defaultSize:{width:1250,height:850},showInMenu:!(ctx.menu&&ctx.menu.registerMenuItem),
  render(host){return new Studio(ctx,host)}
 });
 if(ctx.menu?.registerMenuItem)
  ctx.menu.registerMenuItem({menu:"Mods",label:"Bifröst Capture Studio",icon:"target",handler(){ctx.ui.openPanel(id)}});
 if(ctx.commands?.register)
  ctx.commands.register("vermeil.bifrost-capture.open",()=>ctx.ui.openPanel(id));
}
