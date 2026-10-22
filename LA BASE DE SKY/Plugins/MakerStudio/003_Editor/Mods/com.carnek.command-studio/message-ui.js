import {DIRECTIVES,GROUPS,codeFor} from "./messages-catalog.js";
import {checkText,applyCorrection,autocorrectText,lintMessage,buildMessageEventCommands} from "./text-tools.js";
import {createSkinPreview} from "./skin-preview.js";
import {COLOR_PRESETS,colorTag,renderMessagePreview,normalizedHex,setMessagePosition,messagePosition,colorType,WINDOW_COLOR_HINTS} from "./visual-message.js";

const el=(tag,text,cls)=>{
 const node=document.createElement(tag);if(text!==undefined&&text!==null)node.textContent=String(text);
 if(cls)node.className=cls;return node;
};
const button=(text,click,cls="btn")=>{
 const node=el("button",text,cls);node.type="button";node.onclick=click;return node;
};
const TAB_OPTIONS=[
 ["color","🎨 Color"],["window","▣ Ventana"],["timing","⏱ Pausas"],["all","⋯ Más efectos"]
];
export function mountVisualMessageEditor({host,initialText,onTextChange,onInsert,renderTarget,initialDirective=null,ctx=null,initialSpeaker="",onSpeakerChange=()=>{}}){
 host.replaceChildren();
 host.append(el("h3","Mensajes sin complicaciones"),
   el("p","Escribe, personaliza con botones y comprueba el resultado. Las opciones técnicas están en «Más efectos».","sub"));
 const columns=el("div",null,"widegrid"),left=el("section"),right=el("aside");
 columns.append(left,right);host.append(columns);
 left.append(el("h4","Tu mensaje"));
 const editor=el("textarea");editor.style.width="100%";editor.style.minHeight="165px";
 editor.value=String(initialText||"");editor.spellcheck=true;editor.lang="es";
 editor.setAttribute("aria-label","Texto que verá el jugador");left.append(editor);
 let speaker=String(initialSpeaker||"");
 const nameBox=el("div",null,"csb-name-editor");
 const nameIntro=el("div",null,"csb-name-head");
 nameIntro.append(el("span","🏷️","csb-name-icon"));
 const description=el("div",null,"csb-name-title");
 description.append(el("strong","¿Quién está hablando?"),
                    el("small","NameBox · nombre sobre la ventana"));
 nameIntro.append(description);nameBox.append(nameIntro);
 const nameControls=el("div",null,"csb-name-controls");
 const nameInput=el("input");
 nameInput.placeholder="Nombre del personaje (opcional)";
 nameInput.value=speaker;nameInput.setAttribute("aria-label","Nombre del hablante (NameBox)");
 const player=button("Usar jugador",()=>{
   nameInput.value="\\PN";speaker=nameInput.value;onSpeakerChange(speaker);update();
 },"btn");
 const clear=button("Sin nombre",()=>{
   nameInput.value="";speaker="";onSpeakerChange("");update();
 },"btn csb-quiet");
 nameInput.oninput=()=>{speaker=nameInput.value;onSpeakerChange(speaker);update();};
 nameControls.append(nameInput,player,clear);nameBox.append(nameControls);
 nameBox.append(el("p","Vacío = sin NameBox. Admite \\PN y \\v[n] para nombres dinámicos.","sub"));
 left.append(nameBox);
 const quick=el("div",null,"chips");
 for(const [name,token]of [["Nombre jugador","\\PN"],["Nueva línea","\\n"],["Esperar clic","\\!"],["Dinero","\\PM"],["Sonido","\\se[Door exit]"]])
   quick.append(button(name,()=>paste(token),"chip"));
 left.append(quick);
 const examples=el("details",null,"csb-details");
 examples.append(el("summary","¿No sabes qué escribir? Ver ejemplos"));
 const exampleButtons=el("div",null,"csb-shortcuts");
 for(const [name,template]of [
  ["Saludo","¡Hola, \\PN! ¿Cómo estás?"],
  ["Aviso","\\b¡Atención!\\! Sigue con cuidado."],
  ["Narración","Todo parecía tranquilo…\\| hasta que se escuchó un ruido."]
 ]){
  const b=button(name,()=>paste(template),"chip");
  b.title="Añadir este ejemplo en la posición del cursor";
  exampleButtons.append(b);
 }
 examples.append(el("p","Se añade al cursor: tu mensaje actual no se borra.","sub"),exampleButtons);
 left.append(examples);
 const previewHeading=el("div",null,"csb-section-head");
 previewHeading.append(el("h4","Vista previa"),el("span","Orientativa · No ejecuta el juego","sub"));left.append(previewHeading);
 const previewArea=el("div",null,"csb-preview-area");
 const preview=el("div",null,"csb-preview-canvas");previewArea.append(preview);left.append(previewArea);
 const outputNote=el("p","Los colores RGB y la ubicación son aproximados; las ventanas, fuentes, rostros y sonidos dependen de Vermeil.","csb-visual-hint");left.append(outputNote);
 const submit=button("✓ Añadir mensaje al evento",()=>{
  onInsert(buildMessageEventCommands(editor.value,{speaker}));
 },"btn primary");
 if(typeof renderTarget==="function")renderTarget(left,submit);
 left.append(submit);
 const skin=ctx?createSkinPreview(ctx,previewArea):null;
 function update(){
  onTextChange(editor.value);
  renderMessagePreview(preview,editor.value);
  if(speaker.trim()){
   const stage=preview.querySelector(".csb-dialog-stage");
   if(stage){const box=el("div",speaker.replace(/\\PN/gi,"NOMBRE").replace(/\\v\\[\\d+\\]/gi,"VARIABLE"),"csb-namebox");stage.append(box);}
  }
  skin?.apply?.();
 }
 editor.addEventListener("input",update);update();
 function paste(value){
  editor.setRangeText(String(value),editor.selectionStart,editor.selectionEnd,"end");
  editor.dispatchEvent(new Event("input"));editor.focus();
 }
 function applyColor(color,shadow=null){
  try{paste(colorTag(color,editor.value.slice(editor.selectionStart,editor.selectionEnd)||"texto",shadow));}
  catch(e){message.textContent=e.message;}
 }

 const corrections=el("details",null,"csb-details");
 corrections.append(el("summary","Revisar ortografía y posibles errores"));
 const correctionPanel=el("div",null,"csb-correction-list");
 const checkButton=button("Buscar sugerencias",()=>reviewSpelling(),"btn");
 const applyAll=button("Aplicar correcciones sugeridas",()=>{
  const changed=autocorrectText(editor.value);
  if(!changed.changes.length){spellingStatus.textContent="No hay sugerencias pendientes.";return;}
  editor.value=changed.result;
  editor.dispatchEvent(new Event("input"));reviewSpelling();
 },"btn");
 const spellingStatus=el("p","","sub");
 corrections.append(el("p","El navegador también subraya palabras según el diccionario del sistema. Los códigos Essentials no se modifican.","sub"),
  checkButton,applyAll,spellingStatus,correctionPanel);
 left.append(corrections);
 function reviewSpelling(){
  correctionPanel.replaceChildren();
  const findings=checkText(editor.value);
  for(const issue of findings.slice(0,20)){
   const b=button(issue.original+" → "+issue.suggestion,()=>{
    try{
      editor.value=applyCorrection(editor.value,issue);
      editor.dispatchEvent(new Event("input"));reviewSpelling();
    }catch(e){spellingStatus.textContent=e.message;}
   },"btn");
   correctionPanel.append(b);
  }
  const syntax=lintMessage(editor.value);
  for(const message of syntax)correctionPanel.append(el("p",message,"csb-warning"));
  spellingStatus.textContent=findings.length+" sugerencia(s) y "+syntax.length+" advertencia(s) de formato.";
 }

 const row=el("div",null,"csb-section-head");
 row.append(el("h4","Personalizar el mensaje"),el("span","Elige solo lo que necesitas","sub"));right.append(row);
 const tabs=el("div",null,"csb-tools-tabs");right.append(tabs);
 const panel=el("div",null,"csb-tool-panel");right.append(panel);
 const message=el("p","","csb-tool-note");right.append(message);
 let currentTab=initialDirective?"all":"color",selected=initialDirective,category=initialDirective?.category||"Todas",query="",limit=10;
 function tabTo(value){
  currentTab=value;message.textContent="";draw();
 }
 function controls(){
  tabs.replaceChildren();
  for(const [id,name]of TAB_OPTIONS){
   const b=button(name,()=>tabTo(id),"csb-tool-tab"+(id===currentTab?" active":""));
   b.setAttribute("aria-pressed",String(id===currentTab));tabs.append(b);
  }
 }
 function draw(){
  controls();panel.replaceChildren();
  if(currentTab==="color")drawColors();
  else if(currentTab==="window")drawWindow();
  else if(currentTab==="timing")drawTiming();
  else drawAdvanced();
 }
 function sectionTitle(title,desc){
  panel.append(el("h4",title),el("p",desc,"sub"));
 }
 function drawColors(){
  sectionTitle("Color de las palabras","Selecciona primero un fragmento. El color se insertará en el texto automáticamente.");
  const swatches=el("div",null,"color-swatches");
  COLOR_PRESETS.slice(0,8).forEach(shade=>swatches.append(swatchButton(shade)));
  panel.append(swatches);
  const more=el("details",null,"csb-details");
  more.append(el("summary","Mostrar los demás colores"));
  const extra=el("div",null,"color-swatches");
  COLOR_PRESETS.slice(8).forEach(shade=>extra.append(swatchButton(shade)));
  more.append(extra);panel.append(more);
  function swatchButton(shade){
   const b=button("",()=>applyColor(shade.value),"color-swatch");
   b.title="Color "+shade.name+" ("+shade.value+")";
   const dot=el("span",null,"swatch-dot");dot.style.background=shade.value;
   b.append(dot,el("span",shade.name));return b;
  }
  const custom=el("details",null,"csb-details");
  custom.append(el("summary","Crear un color personalizado"));
  const tools=el("div",null,"csb-color-tools"),picker=el("input"),label=el("span","#FFCF59","sub");
  picker.type="color";picker.value="#FFCF59";picker.title="Elegir color de texto";
  picker.oninput=()=>label.textContent=picker.value.toUpperCase();
  tools.append(picker,label,button("Aplicar",()=>applyColor(picker.value),"btn primary"));
  custom.append(tools);
  const withShadow=el("div",null,"csb-color-tools"),shadow=el("input");
  shadow.type="color";shadow.value="#283858";shadow.title="Elegir sombra de las letras";
  withShadow.append(el("span","Sombra","sub"),shadow,button("Texto + sombra",()=>applyColor(picker.value,shadow.value),"btn"));
  custom.append(withShadow);panel.append(custom);
  panel.append(el("p","Si el color se inserta alrededor de «texto», reemplaza esa palabra por tu frase.","csb-visual-hint"));
 }
 function drawWindow(){
  sectionTitle("Ubicación del diálogo","Pulsa una miniatura para colocar la ventana. El resultado aparece en la vista previa.");
  const boxes=el("div",null,"csb-position-controls");
  for(const [id,name]of [["wu","Arriba"],["wm","Centro"],["wd","Abajo"]]){
   const b=button(" ",()=>{
    const oldPrefix=(editor.value.match(/^\\(?:wu|wm|wd)/i)||[""])[0];
    const oldStart=editor.selectionStart,oldEnd=editor.selectionEnd;
    editor.value=setMessagePosition(editor.value,id);
    const delta=3-oldPrefix.length;
    const start=Math.max(3,oldStart+delta),end=Math.max(3,oldEnd+delta);
    if(typeof editor.setSelectionRange==="function")editor.setSelectionRange(start,end);
    else{editor.selectionStart=start;editor.selectionEnd=end;}
    editor.dispatchEvent(new Event("input"));drawWindowOnly(boxes);
   },"csb-pos"+(messagePosition(editor.value)===id?" active":""));
   b.dataset.pos=id;b.title="Colocar la ventana "+name.toLowerCase();
   b.append(el("span",null,"mini-screen"),el("small",name));boxes.append(b);
  }
  panel.append(boxes);
  const theme=el("details",null,"csb-details");
  theme.append(el("summary","Elegir otro marco (opcional)"));
  const skin=el("input");skin.value="narration";skin.placeholder="Nombre del Windowskin";
  skin.setAttribute("aria-label","Nombre del marco en Graphics/Windowskins");
  const apply=button("Insertar cambio de marco",()=>{
   const v=skin.value.trim();
   if(!v||/[\[\]\r\n]/.test(v)){message.textContent="Escribe un nombre de Windowskin válido.";return;}
   paste("\\w["+v+"]");message.textContent="";
  },"btn");
  theme.append(el("p","Escribe el nombre de un archivo de Graphics/Windowskins, sin la extensión. Esta vista no puede reproducir su imagen.","sub"),skin,apply);
  panel.append(theme);
  function drawWindowOnly(holder){
   for(const b of holder.querySelectorAll("button"))b.classList.toggle("active",b.dataset.pos===messagePosition(editor.value));
  }
 }
 function drawTiming(){
  sectionTitle("Pausas y ritmo","Utiliza botones para controlar la conversación. No necesitas recordar los códigos.");
  const presets=el("div",null,"csb-quick-grid");
  for(const [name,token,note]of [
   ["Esperar confirmación","\\!","El jugador pulsa un botón."],
   ["Pausa breve","\\.","Aproximadamente 0,25 s."],
   ["Pausa larga","\\|","Aproximadamente 1 s."],
   ["Continuar solo","\\^","No espera al terminar."]
  ]){
   const b=button("",()=>paste(token),"csb-effect-card");
   b.append(el("strong",name),el("small",note));presets.append(b);
  }
  panel.append(presets);
  function rangeField(label,min,max,init,build,describe){
   const card=el("div",null,"csb-range-card");
   card.append(el("strong",label));
   const r=el("input");r.type="range";r.min=String(min);r.max=String(max);r.step="1";r.value=String(init);r.style.width="100%";
   const value=el("div","","sub");
   function update(){value.textContent=describe(Number(r.value));}
   r.oninput=update;update();
   card.append(r,value,button("Insertar ajuste",()=>paste(build(Number(r.value))),"btn"));
   panel.append(card);
  }
  rangeField("Esperar un tiempo",0,200,20,n=>"\\wt["+n+"]",n=>"Unidades: "+n+" · aprox. "+(n/20).toFixed(2)+" segundos");
  rangeField("Velocidad del texto",0,20,3,n=>"\\ts["+n+"]",n=>"Velocidad "+n+" (un número mayor hace el texto más lento)");
 }
 function drawAdvanced(){
  sectionTitle("Explorador de efectos","Busca un efecto específico o elige una categoría. Se muestran pocos resultados cada vez.");
  const input=el("input");input.className="search";input.placeholder="Ej.: rostro, sonido, marco, variable…";
  input.value=query;panel.append(input);
  const filters=el("select");filters.setAttribute("aria-label","Tipo de efecto");
  for(const g of ["Todas",...GROUPS]){
   const o=el("option",g);o.value=g;filters.append(o);
  }
  filters.value=category;panel.append(filters);
  const list=el("div",null,"csb-effects-list");panel.append(list);
  const inspector=el("div",null,"csb-effect-detail");panel.append(inspector);
  function listItems(){
   list.replaceChildren();
   const found=DIRECTIVES.filter(d=>(category==="Todas"||d.category===category)&&[d.title,d.description,d.token].join(" ").toLowerCase().includes(query.toLowerCase()));
   for(const d of found.slice(0,limit)){
    const row=button("",()=>{selected=d;showDetail();},"csb-effect-row");
    row.append(el("strong",d.title),el("small",d.description));list.append(row);
   }
   if(found.length>limit)list.append(button("Mostrar "+Math.min(10,found.length-limit)+" efectos más",()=>{limit+=10;listItems();},"btn"));
   if(!found.length)list.append(el("p","Ningún efecto coincide con la búsqueda.","sub"));
   showDetail();
  }
  input.oninput=()=>{query=input.value;limit=10;listItems();};
  filters.onchange=()=>{category=filters.value;limit=10;listItems();};
  function showDetail(){
   inspector.replaceChildren();
   if(!selected){inspector.append(el("p","Selecciona un efecto para ver sus opciones.","sub"));return;}
   inspector.append(el("strong",selected.title),el("p",selected.description,"sub"));
   let parameter=(()=>{
    const match=selected.token.match(/\[([^\]]*)\]/)||selected.token.match(/=([^<>]+)/);
    return match?.[1]||"1";
   })();
   let textInput=null;
   const type=colorType(selected);
   if(selected.parameter){
    const field=el("div",null,"field");
    field.append(el("label",selected.parameter));textInput=el("input");textInput.value=parameter;
    textInput.oninput=()=>{parameter=textInput.value;refresh();};
    field.append(textInput);inspector.append(field);
   }
   if(type==="rgb"||type==="rgb-shadow"){
    const chooser=el("div",null,"csb-color-tools");
    const colors=type==="rgb"?["Color"]:["Texto","Sombra"];
    const parts=parameter.split(",");
    colors.forEach((label,i)=>{
     const picker=el("input");picker.type="color";
     try{picker.value="#"+normalizedHex(parts[i]);}catch(_){picker.value=i===0?"#FFB700":"#405070";}
     picker.title="Seleccionar "+label.toLowerCase();
     picker.oninput=()=>{parts[i]=picker.value.slice(1).toUpperCase();parameter=parts.join(",");if(textInput)textInput.value=parameter;refresh();};
     chooser.append(el("span",label,"sub"),picker);
    });
    inspector.append(chooser);
   }
   if(type==="index"){
    inspector.append(el("p","Los índices dependen del marco del mensaje. Las muestras son aproximadas.","csb-visual-hint"));
    const colors=el("div",null,"color-swatches");
    WINDOW_COLOR_HINTS.forEach((hex,i)=>{
     const b=button("",()=>{parameter=String(i);if(textInput)textInput.value=parameter;refresh();},"color-swatch");
     const dot=el("span",null,"swatch-dot");dot.style.background=hex;
     b.append(dot,el("span",String(i)));colors.append(b);
    });
    inspector.append(colors);
   }
   const snippet=el("pre","","preview");snippet.style.minHeight="30px";inspector.append(snippet);
   const error=el("div","","sub");inspector.append(error);
   const add=button("Insertar este efecto",()=>{
    try{
     paste(codeFor(selected,selected.parameter?parameter:null,editor.value.slice(editor.selectionStart,editor.selectionEnd)||"texto"));
     error.textContent="";
    }catch(e){error.textContent=e.message;}
   },"btn primary");inspector.append(add);
   function refresh(){
    try{snippet.textContent=codeFor(selected,selected.parameter?parameter:null);add.disabled=false;error.textContent="";}
    catch(e){snippet.textContent="";error.textContent=e.message;add.disabled=true;}
   }
   refresh();
  }
  listItems();
 }
 draw();
 host.append(el("p","La vista previa compone los marcos de Essentials cuando están disponibles; comprueba el resultado final ejecutando el evento.","csb-visual-hint"));
 return()=>skin?.dispose?.();
}
