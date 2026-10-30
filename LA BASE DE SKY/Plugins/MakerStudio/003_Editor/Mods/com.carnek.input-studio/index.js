const PANEL = "com.carnek.input-studio.panel";
const PATH = "Plugins/[VERMEIL] Input Studio/actions.json";
const CONTEXTS = ["global","map","menu","battle","bifrost"];
const KB = new Set([
  ..."ABCDEFGHIJKLMNOPQRSTUVWXYZ",..."1234567890",
  "RETURN","ESCAPE","BACKSPACE","TAB","SPACE","MINUS","EQUALS","LEFTBRACKET","RIGHTBRACKET",
  "BACKSLASH","SEMICOLON","APOSTROPHE","GRAVE","COMMA","PERIOD","SLASH","CAPSLOCK",
  "RIGHT","LEFT","DOWN","UP","INSERT","HOME","PAGEUP","DELETE","END","PAGEDOWN",
  "LCTRL","LSHIFT","LALT","LGUI","RCTRL","RSHIFT","RALT","RGUI",
  ...Array.from({length:12},(_,i)=>"F"+(i+1))
]);
const RESERVED = new Set(["F1","F8","F9","F12"]);
const PAD = new Set(["A","B","X","Y","BACK","GUIDE","START","LEFTSTICK","RIGHTSTICK",
  "LEFTSHOULDER","RIGHTSHOULDER","DPAD_UP","DPAD_DOWN","DPAD_LEFT","DPAD_RIGHT"]);
const DEFAULT_ROWS = [
  ["move_up","Arriba","Movimiento","map","UP","DPAD_UP"],
  ["move_down","Abajo","Movimiento","map","DOWN","DPAD_DOWN"],
  ["move_left","Izquierda","Movimiento","map","LEFT","DPAD_LEFT"],
  ["move_right","Derecha","Movimiento","map","RIGHT","DPAD_RIGHT"],
  ["confirm","Aceptar / interactuar","General","global","C,RETURN","A"],
  ["back","Volver / menú","General","global","X,ESCAPE","B"],
  ["action","Acción adicional","Exploración","map","Z","X"],
  ["jump_up","Salto arriba","Exploración","map","A","LEFTSHOULDER"],
  ["jump_down","Salto abajo","Exploración","map","S","RIGHTSHOULDER"],
  ["special","Acceso rápido","Exploración","map","D","Y"],
  ["aux1","Auxiliar 1","Exploración","map","Q","LEFTSTICK"],
  ["aux2","Auxiliar 2","Exploración","map","W","RIGHTSTICK"],
  ["menu","Abrir menú","Exploración","map","","START"],
  ["bifrost_aim","Apuntar","Bifröst","bifrost","F","LEFTSHOULDER"],
  ["bifrost_ball_next","Siguiente Ball","Bifröst","bifrost","E","RIGHTSHOULDER"],
  ["bifrost_ball_prev","Anterior Ball","Bifröst","bifrost","Q","LEFTSHOULDER"],
  ["bifrost_team_next","Siguiente Pokémon","Bifröst","bifrost","TAB","DPAD_RIGHT"],
  ["bifrost_team_prev","Anterior Pokémon","Bifröst","bifrost","BACKSPACE","DPAD_LEFT"],
  ["bifrost_mode","Cambiar Ball / equipo","Bifröst","bifrost","R","Y"],
  ["bifrost_throw","Lanzar","Bifröst","bifrost","SPACE","X"]
];
const defaults = () => DEFAULT_ROWS.map(([id,label,category,context,kb,pad]) =>
  ({id,label,category,context,keyboard:kb?kb.split(","):[],gamepad:pad?pad.split(","):[]}));
const esc = x => String(x ?? "").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
const style = `
.is-root{height:100%;min-height:420px;box-sizing:border-box;color:#dce8f5;background:#101a28;font-family:Inter,Arial,sans-serif;font-size:13px;display:flex;flex-direction:column}
.is-root *{box-sizing:border-box}
.is-top{display:flex;align-items:center;gap:12px;padding:16px 18px;background:#19273b;border-bottom:1px solid #34465d;flex-wrap:wrap}
.is-title{font-size:18px;font-weight:800;letter-spacing:.02em}
.is-sub{color:#91a8c4;font-size:11px}
.is-spacer{flex:1}
.is-btn{border:1px solid #4a6180;border-radius:7px;background:#23364e;color:#dce8f5;padding:9px 13px;font:inherit;cursor:pointer}
.is-btn:hover{border-color:#9ac7ff;background:#324a67}
.is-btn.primary{background:#286d9e;border-color:#438dc4;color:white}
.is-btn.danger{border-color:#83434c;color:#ffc3c7}
.is-btn:disabled{opacity:.4;cursor:not-allowed}
.is-layout{display:grid;grid-template-columns:minmax(220px,280px) minmax(240px,1fr) minmax(265px,340px);min-height:0;flex:1}
.is-nav{background:#142133;border-right:1px solid #33445d;min-height:0;overflow:auto;padding:12px}
.is-stage{min-height:0;overflow:auto;padding:18px}
.is-inspector{background:#17263a;border-left:1px solid #33445d;padding:17px;min-height:0;overflow:auto}
.is-label{font-size:10px;color:#9cb1c9;text-transform:uppercase;letter-spacing:.13em;font-weight:700;margin:8px 0}
.is-input{width:100%;background:#101a2a;border:1px solid #405576;border-radius:6px;color:#ebf5ff;padding:10px;font:inherit;outline:0}
.is-input:focus{border-color:#77b6f4}
.is-item{display:block;width:100%;text-align:left;background:transparent;border:1px solid transparent;border-radius:7px;color:#acbfd6;padding:12px 11px;cursor:pointer;margin-top:3px}
.is-item:hover{background:#24354c}
.is-item.active{background:#294969;border-color:#4a83ad;color:white}
.is-item strong{display:block;font-size:12px}
.is-item small{display:block;color:#9eb5ca;margin-top:4px;font-size:10px}
.is-card{border:1px solid #334b66;background:#18293d;border-radius:11px;padding:17px;margin-bottom:15px}
.is-card h2{margin:0 0 6px;font-size:17px;font-weight:700}
.is-card p{color:#aec3db;font-size:12px;line-height:1.7}
.is-field{margin:15px 0}
.is-field label{display:block;color:#b7cbe3;margin-bottom:7px;font-weight:600;font-size:12px}
.is-hint{font-size:11px;color:#90a8c2;line-height:1.7;margin-top:5px}
.is-pill{display:inline-block;border:1px solid #42617f;border-radius:100px;color:#9bc8eb;padding:5px 9px;font-size:11px;margin:4px}
.is-status{display:flex;align-items:center;padding:10px 18px;background:#162337;border-top:1px solid #33445d;color:#abc3df;font-size:11px}
.is-actions{display:flex;flex-wrap:wrap;gap:8px;margin-top:14px}
.is-alert{padding:11px;background:#273c51;color:#c8e0fa;border-left:3px solid #7fb5e8;border-radius:5px;font-size:12px;line-height:1.6;margin-top:10px}
.is-alert.warn{background:#473b38;border-color:#e2b476;color:#f7dec4}
@media(max-width:970px){.is-layout{grid-template-columns:210px minmax(200px,1fr)}.is-inspector{grid-column:1/-1;border-top:1px solid #33445d}.is-root{overflow:auto}}
@media(max-width:610px){.is-layout{display:block}.is-nav{max-height:220px}.is-stage,.is-inspector{min-height:250px}.is-top{padding:11px}.is-sub{display:none}}
`;

class InputStudioEditor {
  constructor(ctx,host) {
    this.ctx=ctx; this.host=host;
    this.actions=defaults(); this.baseline=""; this.loaded=false;
    this.selected=this.actions[0].id; this.filter=""; this.category="Todos";
    this.message=""; this.saving=false; this.discard=false;
    this.root=document.createElement("div"); this.root.className="is-root";
    this.style=document.createElement("style"); this.style.textContent=style;
    host.innerHTML=""; host.append(this.style,this.root);
    this.root.addEventListener("click",e=>this.onClick(e));
    this.root.addEventListener("change",e=>this.onChange(e));
    this.root.addEventListener("input",e=>this.onInput(e));
    this.draw(); this.load();
  }
  encode(){return JSON.stringify({version:1,actions:this.actions},null,2)+"\n";}
  dirty(){return this.encode()!==this.baseline;}
  selectedAction(){return this.actions.find(x=>x.id===this.selected);}
  normalize(raw){
    if(!raw || !Array.isArray(raw.actions))throw new Error("actions.json no contiene actions[]");
    const existing=new Map(defaults().map(x=>[x.id,x]));
    for(const a of raw.actions){
      if(!a || typeof a.id!=="string" || !/^[a-z][a-z0-9_]{1,49}$/.test(a.id))continue;
      if(!CONTEXTS.includes(a.context))continue;
      const label=String(a.label||"").trim().slice(0,60);
      const category=String(a.category||"").trim().slice(0,30);
      if(!label||!category)continue;
      const list=(values,set)=>Array.isArray(values)?[...new Set(values.filter(v=>typeof v==="string"&&set.has(v)&&!RESERVED.has(v)))].slice(0,4):[];
      existing.set(a.id,{id:a.id,label,category,context:a.context,
        keyboard:list(a.keyboard,KB),gamepad:list(a.gamepad,PAD)});
    }
    return [...existing.values()];
  }
  async load(force=false){
    if(this.dirty()&&this.loaded&&!force){this.message="Pulsa Recargar otra vez para descartar los cambios.";this.discard=true;this.draw();return;}
    try{
      const found=await this.ctx.fs.projectExists(PATH);
      this.actions=found?this.normalize(JSON.parse(await this.ctx.fs.readProjectFile(PATH))):defaults();
      this.baseline=this.encode();this.loaded=true;this.discard=false;
      if(!this.actions.some(a=>a.id===this.selected))this.selected=this.actions[0].id;
      this.message=found?"Archivo de acciones leído.":"Valores predeterminados de Input Studio.";
      this.draw();
    }catch(e){this.loaded=true;this.message="Error al leer: "+(e?.message||e);this.draw();}
  }
  validate(){
    const ids=new Set();
    for(const a of this.actions){
      if(!/^[a-z][a-z0-9_]{1,49}$/.test(a.id)||ids.has(a.id))throw new Error("ID inválido o duplicado: "+a.id);
      ids.add(a.id);
      if(!a.label.trim()||!a.category.trim()||!CONTEXTS.includes(a.context))throw new Error("Definición incompleta: "+a.id);
      for(const device of ["keyboard","gamepad"]){
        const valid=device==="keyboard"?KB:PAD;
        if(a[device].length>4 || a[device].some(v=>!valid.has(v)||RESERVED.has(v)))throw new Error("Binding inválido en "+a.id);
      }
    }
    return true;
  }
  async save(){
    if(this.saving)return;
    try{
      this.validate(); this.saving=true;this.draw();
      const data=this.encode();
      await this.ctx.fs.writeProjectFile(PATH,data);
      const read=await this.ctx.fs.readProjectFile(PATH);
      if(JSON.stringify(JSON.parse(read))!==JSON.stringify(JSON.parse(data)))throw new Error("La verificación de lectura falló.");
      this.baseline=data;this.message="Guardado y verificado: "+PATH;
      this.ctx.ui.showToast?.({message:"Input Studio: configuración guardada",level:"info"});
    }catch(e){this.message="ERROR: "+(e?.message||e);this.ctx.log.error(e);}
    finally{this.saving=false;this.draw();}
  }
  conflicts(a,device){
    const out=[];
    for(const other of this.actions){
      if(a.id===other.id)continue;
      if(a.context!==other.context && a.context!=="global" && other.context!=="global")continue;
      const common=a[device].filter(x=>other[device].includes(x));
      if(common.length)out.push(other.label+" ("+common.join(", ")+")");
    }
    return out;
  }
  categories(){
    return ["Todos",...new Set(this.actions.map(a=>a.category))];
  }
  filtered(){
    return this.actions.filter(a=>(this.category==="Todos"||a.category===this.category) &&
      (a.label+" "+a.id).toLowerCase().includes(this.filter.toLowerCase()));
  }
  draw(){
    const a=this.selectedAction();
    const item=a?this.inspector(a):"<p>Selecciona una acción.</p>";
    const danger=this.dirty()?"● Sin guardar":"✓ Guardado";
    this.root.innerHTML=`
      <header class="is-top"><div><div class="is-title">⌨ INPUT STUDIO</div>
        <div class="is-sub">PERFILES Y ACCIONES · POKÉMON VERMEIL</div></div>
        <div class="is-spacer"></div><span class="is-pill">${esc(danger)}</span>
        <button class="is-btn" data-act="reload">${this.discard?"Confirmar recarga":"↻ Recargar"}</button>
        <button class="is-btn primary" data-act="save" ${this.saving?"disabled":""}>▣ Guardar cambios</button></header>
      <div class="is-layout"><nav class="is-nav">
        <div class="is-label">Buscar</div><input class="is-input" data-search placeholder="Buscar acción..." value="${esc(this.filter)}"/>
        <div class="is-label">Categoría</div>
        <select class="is-input" data-category>${this.categories().map(c=>`<option value="${esc(c)}" ${c===this.category?"selected":""}>${esc(c)}</option>`).join("")}</select>
        <div class="is-label">${this.filtered().length} acciones</div>
        ${this.filtered().map(v=>`<button class="is-item ${v.id===this.selected?"active":""}" data-id="${esc(v.id)}">
          <strong>${esc(v.label)}</strong><small>${esc(v.id)} · ${esc(v.context)}</small></button>`).join("")}
        <div class="is-actions"><button class="is-btn" data-act="add">+ Nueva acción</button></div>
      </nav>
      <main class="is-stage">
        <div class="is-card"><div class="is-label">Arquitectura</div><h2>Acciones, no botones heredados</h2>
          <p>El teclado y el mando cuentan con asignaciones separadas. Las acciones se registran por contexto y no ocupan obligatoriamente un botón de mando. El F1 del jugador utiliza el mismo catálogo.</p>
          <div><span class="is-pill">Teclado físico</span><span class="is-pill">Mando SDL</span><span class="is-pill">Overrides por jugador</span></div>
        </div>
        ${a?`<div class="is-card"><div class="is-label">Acción seleccionada</div><h2>${esc(a.label)}</h2>
          <p><b>ID:</b> ${esc(a.id)}<br><b>Ámbito:</b> ${esc(a.context)}</p>
          <div class="is-label">Teclado</div><div>${(a.keyboard.length?a.keyboard:["Sin asignar"]).map(v=>`<span class="is-pill">${esc(v)}</span>`).join("")}</div>
          <div class="is-label">Mando</div><div>${(a.gamepad.length?a.gamepad:["Sin asignar"]).map(v=>`<span class="is-pill">${esc(v)}</span>`).join("")}</div>
          ${this.conflicts(a,"keyboard").length || this.conflicts(a,"gamepad").length?
            `<div class="is-alert warn">Asignaciones que coinciden con otras acciones del mismo ámbito: ${esc([...this.conflicts(a,"keyboard"),...this.conflicts(a,"gamepad")].join(" · "))}. Revisa el uso previsto antes de publicar.</div>`:
            `<div class="is-alert">Sin solapamientos detectados para esta acción.</div>`}
        </div>`:""}
        <div class="is-card"><div class="is-label">Juego publicado</div>
          <p>F1 abre el editor integrado durante la ejecución. Los cambios del jugador se guardan aparte, en su carpeta de datos, sin tocar actions.json ni Essentials. Para modificar acciones que use un plugin, consulta <code>InputStudio.trigger?("id")</code>.</p>
        </div>
      </main>
      <aside class="is-inspector"><div class="is-label">Inspector de acción</div>${item}</aside></div>
      <footer class="is-status"><span>${esc(this.message||"Acciones predeterminadas del proyecto; no reemplaza los controles originales.")}</span><span class="is-spacer"></span><span>${esc(PATH)}</span></footer>
    `;
  }
  inspector(a){
    return `<div class="is-field"><label>Nombre visible</label><input class="is-input" data-field="label" maxlength="60" value="${esc(a.label)}"/></div>
      <div class="is-field"><label>Identificador de código</label><input class="is-input" value="${esc(a.id)}" disabled/>
        <p class="is-hint">El ID es estable y los scripts lo utilizan para solicitar la acción.</p></div>
      <div class="is-field"><label>Categoría</label><input class="is-input" data-field="category" maxlength="30" value="${esc(a.category)}"/></div>
      <div class="is-field"><label>Contexto</label><select class="is-input" data-field="context">
        ${CONTEXTS.map(c=>`<option value="${c}" ${a.context===c?"selected":""}>${c}</option>`).join("")}
        </select><p class="is-hint">global en todos los menús y escenas. map durante exploración. bifrost cuando su plugin active ese contexto.</p></div>
      <div class="is-field"><label>Teclas por defecto (separadas por coma)</label>
        <input class="is-input" data-field="keyboard" value="${esc(a.keyboard.join(", "))}"/>
        <p class="is-hint">Hasta 4 teclas físicas SDL, por ejemplo: C, RETURN, Q o TAB. F1, F8, F9 y F12 son reservadas.</p></div>
      <div class="is-field"><label>Botones del mando (separados por coma)</label>
        <input class="is-input" data-field="gamepad" value="${esc(a.gamepad.join(", "))}"/>
        <p class="is-hint">A, B, X, Y, START, BACK, LEFTSHOULDER, RIGHTSHOULDER, DPAD_UP, etc.</p></div>
      <div class="is-actions"><button class="is-btn" data-act="restore">Restaurar predeterminado</button>
        ${DEFAULT_ROWS.some(row=>row[0]===a.id)?"":'<button class="is-btn danger" data-act="remove">Eliminar acción</button>'}</div>
      <div class="is-alert">Los cambios de este panel se aplican al juego al guardar y reiniciar. El perfil del jugador tiene prioridad y no se sobrescribe.</div>`;
  }
  onInput(e){
    const target=e.target;
    if(target.hasAttribute("data-search")){this.filter=target.value;this.draw();return;}
    const field=target.getAttribute("data-field");
    const a=this.selectedAction();
    if(!a||!field)return;
    if(field==="label"||field==="category"){a[field]=target.value.slice(0,field==="label"?60:30);this.drawStatusOnly();return;}
  }
  drawStatusOnly(){
    const p=this.root.querySelector(".is-status span");
    if(p)p.textContent="● Cambios sin guardar";
  }
  onChange(e){
    const t=e.target;
    if(t.hasAttribute("data-category")){this.category=t.value;this.draw();return;}
    const f=t.getAttribute("data-field");
    const a=this.selectedAction();
    if(!a||!f)return;
    if(f==="context")a.context=t.value;
    if(f==="keyboard"||f==="gamepad"){
      const valid=f==="keyboard"?KB:PAD;
      const keys=[...new Set(t.value.toUpperCase().split(",").map(x=>x.trim()).filter(Boolean))];
      const bad=keys.filter(key=>!valid.has(key)||RESERVED.has(key));
      if(bad.length){this.message="No son entradas admitidas: "+bad.join(", ");this.draw();return;}
      a[f]=keys.slice(0,4);
    }
    this.message="Cambio pendiente de guardar";this.draw();
  }
  onClick(e){
    const b=e.target.closest("button");if(!b)return;
    const id=b.getAttribute("data-id");
    if(id){this.selected=id;this.draw();return;}
    const act=b.getAttribute("data-act");
    if(act==="save"){this.save();return;}
    if(act==="reload"){this.load(this.discard);return;}
    if(act==="add"){
      let n=1;while(this.actions.some(x=>x.id==="custom_action_"+n))n++;
      const item={id:"custom_action_"+n,label:"Nueva acción",category:"Personalizado",context:"map",keyboard:[],gamepad:[]};
      this.actions.push(item);this.selected=item.id;this.category="Todos";this.filter="";this.message="Acción nueva; configura su ID estable en los scripts.";this.draw();return;
    }
    const a=this.selectedAction();if(!a)return;
    if(act==="restore"){
      const initial=defaults().find(x=>x.id===a.id);
      if(initial)Object.assign(a,initial);
      else {a.keyboard=[];a.gamepad=[];}
      this.message="Acción restaurada; guarda para aplicar.";this.draw();
    }
    if(act==="remove"&&!DEFAULT_ROWS.some(row=>row[0]===a.id)){
      this.actions=this.actions.filter(x=>x.id!==a.id);this.selected=this.actions[0]?.id||"";
      this.message="Acción eliminada del borrador.";this.draw();
    }
  }
}

let ctxActive=null;
export function activate(ctx){
  ctxActive=ctx;
  ctx.ui.registerPanel({id:PANEL,title:"Input Studio",icon:"⌨",showInMenu:true,
    defaultPosition:"right",defaultSize:{width:1420,height:860},
    render(host){const editor=new InputStudioEditor(ctx,host);return ()=>{host.innerHTML="";};}});
  ctx.menu.registerMenuItem({menu:"Tools",label:"Input Studio",icon:"⌨",
    handler:()=>ctx.ui.openPanel(PANEL)});
  ctx.commands.register("com.carnek.input-studio.open",()=>{ctx.ui.openPanel(PANEL);return true;});
  ctx.log.info("Input Studio 1.0 registrado");
}
export function deactivate(){ctxActive=null;}
