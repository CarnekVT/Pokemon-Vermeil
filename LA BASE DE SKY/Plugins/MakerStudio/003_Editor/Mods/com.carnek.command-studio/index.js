import { NATIVE, RECIPES } from "./catalog.js";

const ID = "com.carnek.command-studio.panel";
const CSS = String.raw`
.cs{height:100%;min-height:0;display:flex;flex-direction:column;background:var(--bg-primary,#141b27);color:var(--text-primary,#e5edf7);font:12px/1.45 system-ui,sans-serif}
.cs *{box-sizing:border-box}.cs header{padding:14px 16px 10px;border-bottom:1px solid var(--border,#344357);display:flex;align-items:center;gap:12px}
.cs h2{font-size:18px;margin:0;letter-spacing:.2px}.cs-sub{font-size:11px;color:var(--text-secondary,#a4b3c8)}
.cs-tabs{display:flex;gap:5px;flex-wrap:wrap;padding:10px 16px;border-bottom:1px solid var(--border,#344357)}
.cs-btn,.cs-input,.cs-select,.cs-textarea{background:var(--bg-secondary,#1e293b);border:1px solid var(--border,#344357);color:var(--text-primary,#e5edf7);border-radius:6px;font:inherit;padding:7px 10px;outline:none}
.cs-btn{cursor:pointer;white-space:nowrap}.cs-btn:hover,.cs-result:hover{border-color:var(--accent,#5ba8f2)}
.cs-btn.active,.cs-btn.primary{background:var(--accent,#348bdd);border-color:var(--accent,#348bdd);color:var(--text-on-accent,#fff);font-weight:700}
.cs-input:focus,.cs-textarea:focus,.cs-select:focus{border-color:var(--accent,#348bdd)}
.cs-toolbar{display:flex;gap:8px;padding:10px 16px;border-bottom:1px solid var(--border,#344357);align-items:center}
.cs-toolbar .cs-input{min-width:0;flex:1}.cs-toolbar .cs-select{max-width:230px;min-width:120px}
.cs-body{display:grid;grid-template-columns:minmax(220px,35%) minmax(340px,65%);flex:1;min-height:0}
.cs-results{overflow:auto;min-height:0;padding:12px;border-right:1px solid var(--border,#344357)}
.cs-result{width:100%;display:block;border:1px solid transparent;background:var(--bg-secondary,#1e293b);margin-bottom:6px;text-align:left;cursor:pointer;padding:10px;border-radius:7px;color:inherit}
.cs-result.selected{border-color:var(--accent,#348bdd);background:color-mix(in srgb,var(--accent,#348bdd) 15%,var(--bg-secondary,#1e293b))}
.cs-row{display:flex;justify-content:space-between;gap:8px;align-items:start}.cs-small{font-size:10px;color:var(--text-secondary,#a4b3c8)}
.cs-inspector{overflow:auto;min-height:0;padding:17px 20px 20px}.cs-inspector h3{font-size:18px;margin:0 0 4px}
.cs-crumb{font-size:11px;color:var(--text-secondary,#a4b3c8);margin-bottom:12px}
.cs-fields{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:10px;margin:12px 0}.cs-field{min-width:0}
.cs-field.wide{grid-column:1/-1}.cs-label{display:block;font-size:11px;margin-bottom:5px;color:var(--text-secondary,#a4b3c8)}
.cs-input,.cs-select,.cs-textarea{width:100%}.cs-textarea{resize:vertical;min-height:120px;font:12px/1.5 ui-monospace,Consolas,monospace}
.cs-output{min-height:140px}.cs-actions{display:flex;gap:8px;flex-wrap:wrap;margin-top:8px}
.cs-note{border:1px solid var(--border,#344357);padding:10px 12px;border-radius:7px;margin:10px 0;color:var(--text-secondary,#a4b3c8);font-size:11px}
.cs-foot{border-top:1px solid var(--border,#344357);display:flex;justify-content:space-between;gap:8px;padding:8px 16px;font-size:11px;color:var(--text-secondary,#a4b3c8)}
.cs-inline{display:flex;gap:6px;flex-wrap:wrap;align-items:center}.cs-chip{border:1px solid var(--border,#344357);border-radius:5px;padding:4px 8px;cursor:pointer;background:var(--bg-secondary,#1e293b);color:inherit}
.cs-tag{font-size:10px;background:var(--bg-primary,#141b27);padding:2px 5px;border-radius:4px;color:var(--text-secondary,#a4b3c8)}
.cs-muted{opacity:.7}.cs-error{color:#ff9b93}
@media(max-width:780px){.cs-body{grid-template-columns:1fr}.cs-results{max-height:220px;border-right:0;border-bottom:1px solid var(--border,#344357)}}
`;

function node(tag, text, cls) {
  const n = document.createElement(tag);
  if (text !== undefined && text !== null) n.textContent = String(text);
  if (cls) n.className = cls;
  return n;
}
const integer=(v,min=0,max=999999)=>Math.max(min,Math.min(max,Number.isFinite(Number(v))?Math.trunc(Number(v)):min));
const escaped=(s)=>JSON.stringify(String(s??""));
const asCommands=(entries)=>entries.map(({code,parameters=[],indent=0})=>({code,indent,parameters}));
function ncmd(code,parameters=[],indent=0){return{code,parameters,indent};}
function scriptCommands(source){
  return String(source).replace(/\r/g,"").split("\n").map((line,i)=>ncmd(i?655:355,[line]));
}
function textCommands(source,first,other){
  return String(source).replace(/\r/g,"").split("\n").map((line,i)=>ncmd(i?other:first,[line]));
}
const FIELD_DEFS={
  103:[["variable","Variable","number",1],["digits","Cifras","number",2]],
  105:[["variable","Guardar tecla en variable","number",1]],
  106:[["frames","Fotogramas","number",20]],
  111:[["condition","Condición Ruby (debe devolver true/false)","textarea","$game_switches[1]"]],
  112:[],
  113:[],115:[],116:[],
  117:[["common","ID de evento común","number",1]],
  118:[["label","Nombre de etiqueta","text","INICIO"]],
  119:[["label","Etiqueta destino","text","INICIO"]],
  121:[["first","Interruptor inicial","number",1],["last","Interruptor final","number",1],["enabled","Valor","select","0",[["0","ON"],["1","OFF"]]]],
  122:[["first","Variable inicial","number",1],["last","Variable final","number",1],["op","Operación","select","0",[["0","Asignar"],["1","Sumar"],["2","Restar"],["3","Multiplicar"],["4","Dividir"],["5","Módulo"]]],["value","Constante","number",1]],
  123:[["letter","Interruptor local","select","A",[["A","A"],["B","B"],["C","C"],["D","D"]]],["enabled","Valor","select","0",[["0","ON"],["1","OFF"]]]],
  124:[["seconds","Segundos","number",60],["action","Temporizador","select","0",[["0","Iniciar"],["1","Detener"]]]],
  125:[["amount","Cantidad de oro","number",100]],
  126:[["id","ID objeto (BD RMXP)","number",1],["quantity","Cantidad","number",1]],
  201:[["map","ID del mapa","number",1],["x","Casilla X","number",10],["y","Casilla Y","number",10],["direction","Mirada","select","2",[["0","Conservar"],["2","Abajo"],["4","Izquierda"],["6","Derecha"],["8","Arriba"]]],["fade","Fundido","select","0",[["0","Normal"],["1","Sin fundido"]]]],
  207:[["target","Objetivo","number",-1],["animation","ID animación","number",1]],
  223:[["r","Rojo (-255 a 255)","number",0],["g","Verde (-255 a 255)","number",0],["b","Azul (-255 a 255)","number",0],["gray","Gris (0 a 255)","number",0],["frames","Duración (frames)","number",20]],
  225:[["power","Potencia","number",5],["speed","Velocidad","number",5],["frames","Duración","number",20]],
  231:[["id","ID de imagen","number",1],["file","Archivo de Graphics/Pictures","text","imagen"],["x","X","number",0],["y","Y","number",0],["opacity","Opacidad","number",255]],
  235:[["id","ID de imagen","number",1]],
  236:[["type","Clima","select","1",[["0","Ninguno"],["1","Lluvia"],["2","Tormenta"],["3","Nieve"]]],["strength","Intensidad (0 a 9)","number",5],["frames","Duración","number",20]],
  241:[["file","Nombre del archivo BGM","text",""],["volume","Volumen","number",100],["pitch","Tono","number",100]],
  245:[["file","Nombre del archivo BGS","text",""],["volume","Volumen","number",100],["pitch","Tono","number",100]],
  249:[["file","Nombre del archivo ME","text",""],["volume","Volumen","number",100],["pitch","Tono","number",100]],
  250:[["file","Nombre del archivo SE","text",""],["volume","Volumen","number",100],["pitch","Tono","number",100]],
  242:[["seconds","Segundos de fundido","number",5]],
  246:[["seconds","Segundos de fundido","number",5]],
  102:[["options","Opciones (una por línea; máximo cuatro)","textarea","Sí\nNo"]],
  104:[["position","Posición ventana","select","2",[["0","Arriba"],["1","Centro"],["2","Abajo"]]]]
};
const SIMPLE_NO_PARAMS=new Set([0,112,113,115,116,210,221,247,248,251,351,352,353,354]);
const audio=(v)=>({__class:"RPG::AudioFile",name:String(v.file||""),volume:integer(v.volume,0,100),pitch:integer(v.pitch,50,150)});
function compileNative(code,v,custom) {
  const num=(k,min=0,max=999999)=>integer(v[k],min,max);
  switch(code){
    case 101:return textCommands(v.text||"",101,401);
    case 108:return textCommands(v.text||"",108,408);
    case 355:return scriptCommands(v.script||"");
    case 102:{
      const choices=String(v.options||"Sí\nNo").split(/\r?\n/).map(x=>x.trim()).filter(Boolean).slice(0,4);
      if(!choices.length)throw new Error("Incluye al menos una elección.");
      return [ncmd(102,[choices,0]),...choices.map((x,i)=>ncmd(402,[i,x])),ncmd(404,[])];
    }
    case 111:return[ncmd(111,[12,String(v.condition||"true")]),ncmd(411),ncmd(412)];
    case 112:return[ncmd(112),ncmd(413)];
    case 103:return[ncmd(code,[num("variable",1),num("digits",1,8)])];
    case 104:return[ncmd(code,[num("position",0,2),0])];
    case 105:return[ncmd(code,[num("variable",1)])];
    case 106:return[ncmd(code,[num("frames",0,9999)])];
    case 117:return[ncmd(code,[num("common",1)])];
    case 118:case 119:return[ncmd(code,[String(v.label||"")])];
    case 121:return[ncmd(code,[num("first",1),num("last",1),num("enabled",0,1)])];
    case 122:return[ncmd(code,[num("first",1),num("last",1),num("op",0,5),0,Number(v.value)||0])];
    case 123:return[ncmd(code,[String(v.letter||"A"),num("enabled",0,1)])];
    case 124:return[ncmd(code,[num("action",0,1),num("seconds",0,9999)])];
    case 125:return[ncmd(code,[0,0,num("amount",0)])];
    case 126:return[ncmd(code,[num("id",1),0,0,num("quantity",0)])];
    case 201:return[ncmd(code,[0,num("map",1),num("x"),num("y"),num("direction",0,8),num("fade",0,1)])];
    case 207:return[ncmd(code,[num("target",-1,9999),num("animation",1)])];
    case 223:return[ncmd(code,[{__class:"Tone",values:[num("r",-255,255),num("g",-255,255),num("b",-255,255),num("gray",0,255)]},num("frames",0)])];
    case 225:return[ncmd(code,[num("power",1,9),num("speed",1,9),num("frames",0)])];
    case 231:return[ncmd(code,[num("id",1),String(v.file||""),0,0,num("x"),num("y"),100,100,num("opacity",0,255),0])];
    case 235:return[ncmd(code,[num("id",1)])];
    case 236:return[ncmd(code,[num("type",0,3),num("strength",0,9),num("frames",0)])];
    case 241:case 245:case 249:case 250:return[ncmd(code,[audio(v)])];
    case 242:case 246:return[ncmd(code,[num("seconds",0)])];
    default:
      if(SIMPLE_NO_PARAMS.has(code))return[ncmd(code)];
      if(!custom.trim())throw new Error("Este comando necesita parámetros JSON; revisa la estructura de RPG Maker XP.");
      const params=JSON.parse(custom);
      if(!Array.isArray(params))throw new Error("Los parámetros deben ser un arreglo JSON.");
      return[ncmd(code,params)];
  }
}
function descNative(item){
  if(item.internal)return "Código auxiliar o estructural del editor. No insertarlo suelto sin conocer la secuencia completa.";
  if(!FIELD_DEFS[item.code] && !SIMPLE_NO_PARAMS.has(item.code) && ![101,108,355].includes(item.code))
    return "Comando nativo sin formulario verificado: proporciona un arreglo de parámetros JSON válido. Algunos comandos originales de RMXP son reemplazados o ignorados por Pokémon Essentials.";
  return "Generador de estructura RPG::EventCommand. Comprueba los parámetros antes de importar: el panel no escribe en el mapa.";
}
function getList(ctx){
  const folders=["Plugins"];const results=[];let scanned=0,readFiles=0;
  async function process() {
    while(folders.length && scanned<700 && readFiles<220){
      const parent=folders.shift();let entries;
      try{entries=await ctx.fs.listProjectDir(parent);}catch(_){continue;}
      if(!Array.isArray(entries))entries=entries?.entries||entries?.files||[];
      for(const e of entries){
        const name=typeof e==="string"?e:String(e?.name||e?.path||"");
        if(!name || name==="." || name===".." || name.startsWith("."))continue;
        let path=name.replace(/\\/g,"/");
        if(!path.startsWith("Plugins/"))path=parent+"/"+path.split("/").pop();
        const isDir=typeof e==="object"?(e.type==="dir"||e.type==="directory"||e.isDirectory===true||e.kind==="directory"):false;
        scanned++;
        if(isDir){if(path.split("/").length<=6)folders.push(path);continue;}
        if(!/\.rb$/i.test(path))continue;
        if(readFiles>=220)break;
        readFiles++;
        let content;try{content=await ctx.fs.readProjectFile(path);}catch(_){continue;}
        if(typeof content!=="string"||content.length>300000)continue;
        const re=/^\s*def\s+(?:self\.)?([A-Za-z_]\w*[!?=]?)(?:\s*\(([^)\n]{0,100})\))?/gm;
        let m,perFile=0;
        while((m=re.exec(content))&&perFile++<200&&results.length<4000){
          results.push({kind:"method",id:"m"+results.length,title:m[1],category:path.split("/").slice(1,-1).join("/")||"Plugins",signature:m[2]||"",path,description:"Método encontrado en "+path,code:m[1]+(m[2]?"("+m[2]+")":"()")});
        }
      }
    }
    return{methods:results,scanned,readFiles,limited:folders.length>0};
  }
  return process();
}

async function copy(ctx,value){
  try{
    if(ctx.clipboard?.writeText){await ctx.clipboard.writeText(value);return true;}
    if(ctx.clipboard?.write){await ctx.clipboard.write(value);return true;}
    if(navigator.clipboard?.writeText){await navigator.clipboard.writeText(value);return true;}
  }catch(_){}
  return false;
}
function toast(ctx,message,level="info"){try{ctx.ui.showToast({message,level});}catch(_){}}

function mount(ctx,host){
  host.innerHTML=`<style>${CSS}</style>
  <div class="cs">
    <header><div style="font-size:28px">⌘</div><div><h2>Command Studio</h2><div class="cs-sub">Comandos RPG Maker XP · Essentials 21.1 · Ruby · Texto</div></div><div style="flex:1"></div><span class="cs-tag">v0.2.0 · Maker Studio</span></header>
    <div class="cs-tabs">
      <button class="cs-btn active" data-tab="native">Comandos nativos</button>
      <button class="cs-btn" data-tab="recipe">Pokémon Essentials</button>
      <button class="cs-btn" data-tab="method">Scripts de plugins</button>
      <button class="cs-btn" data-tab="text">Text Studio</button>
    </div>
    <div class="cs-toolbar">
      <input class="cs-input" data-search placeholder="Buscar por nombre, función, código o palabra clave" aria-label="Buscar comandos"/>
      <select class="cs-select" data-cat aria-label="Categoría"><option value="">Todas las categorías</option></select>
      <button class="cs-btn" data-scan style="display:none">Indexar plugins</button>
    </div>
    <div class="cs-body">
      <aside class="cs-results" data-results aria-label="Resultados"></aside>
      <main class="cs-inspector" data-inspector></main>
    </div>
    <div class="cs-foot"><span data-status>Selecciona un comando.</span><span>Las ediciones de mapas se realizan desde DevTools/CommandStudio.</span></div>
  </div>`;
  const root=host.querySelector(".cs"), results=root.querySelector("[data-results]"),
    inspect=root.querySelector("[data-inspector]"),search=root.querySelector("[data-search]"),
    category=root.querySelector("[data-cat]"), status=root.querySelector("[data-status]"),
    scanButton=root.querySelector("[data-scan]");
  let tab="native", selected=null, methods=[], scanBusy=false;
  let outputText="", outputJSON="", outputIsRuby=false;
  const key=(s)=>String(s??"").toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g,"");
  const all=()=>tab==="native"?NATIVE:tab==="recipe"?RECIPES:tab==="method"?methods:[NATIVE.find(x=>x.code===101),NATIVE.find(x=>x.code===108),NATIVE.find(x=>x.code===355)];
  function setStatus(v){status.textContent=v;}
  function refreshCategories(){
    const current=category.value;
    category.replaceChildren(node("option","Todas las categorías"));
    category.firstChild.value="";
    [...new Set(all().map(x=>x.category))].sort().forEach(x=>{const option=node("option",x);option.value=x;category.append(option);});
    category.value=[...category.options].some(x=>x.value===current)?current:"";
  }
  function list(){
    const q=key(search.value.trim()),c=category.value;
    const arr=all().filter(x=>(!c||x.category===c)&&(!q||key([x.title,x.category,x.aliases,x.description,x.code,x.path].join(" ")).includes(q)));
    results.replaceChildren();
    if(tab==="method"&&!methods.length){
      results.append(node("p","Pulsa «Indexar plugins» para buscar métodos .rb de los plugins del proyecto.","cs-note"));
    }
    if(!arr.length)results.append(node("p",tab==="method"?"Sin métodos indexados o coincidencias.":"No se encontraron comandos.","cs-small"));
    const slice=arr.slice(0,400);
    for(const item of slice){
      const b=node("button",null,"cs-result"+(selected?.id===item.id?" selected":""));b.type="button";
      const row=node("div",null,"cs-row");row.append(node("strong",item.title),node("span",item.kind==="native"?"#"+item.code:item.kind==="method"?"Ruby":"Script","cs-tag"));
      b.append(row,node("div",item.category+(item.internal?" · interno":""),"cs-small"));
      b.onclick=()=>select(item);
      results.append(b);
    }
    if(arr.length>400)results.append(node("p","Mostrando 400 resultados; precisa la búsqueda.","cs-note"));
    setStatus(arr.length+" resultado(s) · "+(tab==="method"?"Indexación parcial basada en código Ruby": "Catálogo consultable"));
  }
  function field(group,def){
    const [name,label,type,defaultValue,choices]=def;
    const wrap=node("div",null,"cs-field"+(type==="textarea"?" wide":""));
    const title=node("label",label,"cs-label");title.setAttribute("for","cs-field-"+name);
    let input;
    if(type==="textarea"){input=node("textarea",null,"cs-textarea");input.rows=4;input.value=String(defaultValue);input.spellcheck=false;}
    else if(type==="select"){input=node("select",null,"cs-select");for(const [v,t] of choices){const opt=node("option",t);opt.value=v;input.append(opt);}input.value=String(defaultValue);}
    else {input=node("input",null,"cs-input");input.type=type==="number"?"number":"text";input.value=String(defaultValue);if(type==="number")input.step="1";}
    input.id="cs-field-"+name;input.dataset.key=name;wrap.append(title,input);group.append(wrap);
    return input;
  }
  function select(item){
    selected=item;list();
    inspect.replaceChildren();
    inspect.append(node("h3",item.title),node("div",item.category+(item.code!==undefined?" / código "+item.code:""),"cs-crumb"));
    const description=node("div",item.description||descNative(item),"cs-note"); inspect.append(description);
    const fields=node("div",null,"cs-fields"),inputs={};
    let mode="native";let custom=null;
    if(item.kind==="recipe"||item.kind==="method"){
      mode="ruby";
      inputs.script=field(fields,["script","Código Ruby editable","textarea",item.code]);
      inputs.script.rows=7;
      if(item.kind==="method") inspect.append(node("p","Método indexado: "+item.path+". La firma se detecta de forma aproximada; confirma el contexto antes de ejecutarlo.","cs-small"));
    }else if(item.code===101||item.code===108){
      mode="text";inputs.text=field(fields,["text",item.code===101?"Texto (una línea por renglón de evento)":"Comentario","textarea",item.code===101?"¡Hola, \\PN!":"Comentario del evento"]);
      inputs.text.rows=6;
      if(item.code===101){
        const tools=node("div",null,"cs-inline");for(const [label,value] of [["Nombre jugador","\\PN"],["Variable","\\v[1]"],["Color","\\c[1]"],["Nombre Pokémon","\\pn"]]){
          const b=node("button",label,"cs-chip");b.onclick=()=>{const a=inputs.text;const at=a.selectionStart; a.setRangeText(value,at,a.selectionEnd,"end");a.focus();update();};tools.append(b);
        }
        inspect.append(tools);
      }
    }else if(item.code===355){
      mode="ruby";inputs.script=field(fields,["script","Ruby (una línea por comando Script / continuación)","textarea","pbMessage(_INTL(\"¡Hola!\"))"]);inputs.script.rows=8;
    }else if(Object.prototype.hasOwnProperty.call(FIELD_DEFS,item.code)){
      for(const def of FIELD_DEFS[item.code])inputs[def[0]]=field(fields,def);
    }else{
      custom=field(fields,["custom","Parámetros JSON (arreglo del comando)","textarea","[]"]);
      custom.rows=5;
    }
    inspect.append(fields);
    const errors=node("div",null,"cs-small cs-error");inspect.append(errors);
    const outputTitle=node("div","Código listo para copiar · Los comandos RMXP se exportan como JSON","cs-label");
    const out=node("textarea",null,"cs-textarea cs-output");out.spellcheck=false;out.readOnly=true;out.rows=9;
    const actions=node("div",null,"cs-actions");
    const primary=node("button","Copiar script / texto","cs-btn primary"),jsonBtn=node("button","Copiar EventCommand JSON","cs-btn"),clearBtn=node("button","Restablecer","cs-btn");
    actions.append(primary,jsonBtn,clearBtn);
    inspect.append(outputTitle,out,actions);
    const hint=node("div","El JSON representa comandos para el editor externo; no debes pegarlo en «Script» de RPG Maker XP.","cs-note");inspect.append(hint);
    function readFields(){const obj={};for(const [k,input] of Object.entries(inputs))obj[k]=input.value;return obj;}
    function update(){
      errors.textContent="";outputText="";outputJSON="";outputIsRuby=mode==="ruby";
      try{
        const v=readFields();
        let commands;
        if(item.kind!=="native"){
          outputText=String(v.script||"");
          commands=scriptCommands(outputText);
        }else{
          commands=compileNative(item.code,v,custom?.value||"");
          if(item.code===101||item.code===108)outputText=String(v.text||"");
          if(item.code===355)outputText=String(v.script||"");
        }
        outputJSON=JSON.stringify(asCommands(commands),null,2);
        out.value=outputText||outputJSON;
        outputTitle.textContent=outputText?"Texto / Ruby para pegar en el editor de eventos":"Comandos RMXP como JSON para editor externo";
        primary.disabled=!outputText.trim();
      }catch(e){errors.textContent="Error: "+(e?.message||e);out.value="";primary.disabled=true;jsonBtn.disabled=true;return;}
      jsonBtn.disabled=false;
    }
    const initialValues=readFields();
    for(const input of Object.values(inputs))input.addEventListener("input",update);
    if(custom)custom.addEventListener("input",update);
    primary.onclick=async()=>{if(!outputText)return;const done=await copy(ctx,outputText);toast(ctx,done?"Texto / script copiado":"No se pudo copiar el contenido.",done?"info":"error");};
    jsonBtn.onclick=async()=>{if(!outputJSON)return;const done=await copy(ctx,outputJSON);toast(ctx,done?"JSON de comandos copiado":"No se pudo copiar JSON.",done?"info":"error");};
    clearBtn.onclick=()=>{for(const [k,input] of Object.entries(inputs))input.value=initialValues[k];if(custom)custom.value="[]";update();};
    update();
  }
  function switchTab(next){
    tab=next;selected=null;search.value="";category.value="";
    root.querySelectorAll("[data-tab]").forEach(b=>b.classList.toggle("active",b.dataset.tab===next));
    scanButton.style.display=next==="method"?"":"none";
    refreshCategories();list();inspect.replaceChildren();
    const heading=next==="native"?"Enciclopedia de eventos":next==="recipe"?"Presets de Pokémon Essentials":next==="method"?"Explorador de scripts Ruby":"Editor de texto";
    inspect.append(node("h3",heading),node("div",next==="method"?"Indexa funciones .rb bajo Plugins sin ejecutar código del proyecto.":next==="text"?"Selecciona Mensaje, Comentario o Script para editar contenido y generar los códigos continuados.":"Selecciona un comando de la izquierda. Los parámetros no verificados se muestran en modo avanzado.","cs-note"));
    if(next==="text"){const first=all()[0];if(first)select(first);}
  }
  root.querySelectorAll("[data-tab]").forEach(b=>b.onclick=()=>switchTab(b.dataset.tab));
  search.addEventListener("input",list);category.addEventListener("change",list);
  scanButton.onclick=async()=>{
    if(scanBusy)return;scanBusy=true;scanButton.disabled=true;scanButton.textContent="Indexando…";
    setStatus("Buscando archivos de plugins .rb…");
    try{
      const result=await getList(ctx);
      methods=result.methods;
      toast(ctx,"Command Studio: "+methods.length+" métodos encontrados en "+result.readFiles+" archivos.");
      refreshCategories();list();
      if(result.limited)setStatus("Indexación limitada por seguridad · "+result.readFiles+" archivos leídos.");
    }catch(e){setStatus("Error de indexación: "+String(e.message||e));toast(ctx,"No se pudo indexar Plugins","error");}
    finally{scanBusy=false;scanButton.disabled=false;scanButton.textContent="Reindexar plugins";}
  };
  switchTab("native");
  return()=>{root.replaceChildren();};
}

export function activate(ctx){
  ctx.ui.registerPanel({id:ID,title:"Command Studio",icon:"terminal",defaultPosition:"right",
    defaultSize:{width:1430,height:860},
    showInMenu:!(ctx.menu&&typeof ctx.menu.registerMenuItem==="function"),
    render(host){try{return mount(ctx,host);}catch(err){ctx.log?.error?.(err);host.textContent="No se pudo iniciar Command Studio: "+(err.message||err);return()=>{};}}
  });
  if(ctx.menu?.registerMenuItem){
    ctx.menu.registerMenuItem({menu:"Mods",label:"Command Studio",icon:"terminal",handler:()=>ctx.ui.openPanel(ID)});
    ctx.menu.registerMenuItem({menu:"Tools",label:"Command Studio",icon:"terminal",handler:()=>ctx.ui.openPanel(ID)});
  }
  if(ctx.commands?.register)ctx.commands.register("com.carnek.command-studio.open",()=>ctx.ui.openPanel(ID));
  ctx.log?.info?.("Command Studio v0.2.0 integrado como panel de Maker Studio");
}
