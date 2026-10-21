import {DIRECTIVES,GROUPS,codeFor} from "./messages-catalog.js";
import {COLOR_PRESETS,colorTag,renderMessagePreview,normalizedHex,setMessagePosition,messagePosition,colorType,WINDOW_COLOR_HINTS} from "./visual-message.js";
const el=(tag,text,cls)=>{
  const node=document.createElement(tag);
  if(text!==undefined&&text!==null)node.textContent=String(text);
  if(cls)node.className=cls;
  return node;
};
const button=(text,click,cls="btn")=>{
  const item=el("button",text,cls);item.type="button";item.onclick=click;return item;
};
const COMMAND_ICONS={Colores:"🎨",Ventana:"▣",Velocidad:"⏱",Sonido:"♫",Formato:"T",Variables:"ƒ",Extras:"✦",Alineación:"≡",Avanzado:"⌘"};
const SWATCHES={Azul:"#4298EF",Rojo:"#F04E5B"};
export function mountVisualMessageEditor(options){
 const {host,initialText,onTextChange,onInsert,renderTarget}=options;
 host.replaceChildren();
 const title=el("h3","Editor visual de diálogos");
 const intro=el("p","Escribe el diálogo, elige los efectos con botones y comprueba cómo quedará la ventana.","sub");
 host.append(title,intro);
 const columns=el("div",null,"widegrid"),left=el("section"),right=el("aside");
 host.append(columns);columns.append(left,right);
 left.append(el("h4","1 · Escribe el texto"));
 const editor=el("textarea");editor.value=String(initialText||"");
 editor.style.minHeight="156px";editor.style.width="100%";
 editor.setAttribute("aria-label","Contenido del diálogo");
 left.append(editor);
 function update(){onTextChange(editor.value);renderMessagePreview(preview,editor.value);const pos=messagePosition(editor.value);positionButtons.forEach(b=>b.classList.toggle("selected",b.dataset.pos===pos));}
 function paste(value){
   editor.setRangeText(String(value),editor.selectionStart,editor.selectionEnd,"end");
   editor.dispatchEvent(new Event("input"));editor.focus();
 }
 function colored(hex,shadow=null){
   try{paste(colorTag(hex,editor.value.slice(editor.selectionStart,editor.selectionEnd)||"texto",shadow));}
   catch(e){status.textContent="Error: "+e.message;}
 }
 const actions=el("div",null,"chips");
 for(const [name,token]of [["Jugador","\\PN"],["Otra línea","\\n"],["Pausa","\\!"],["Dinero","\\PM"],["Sonido SE","\\se[Door exit]"]]){
   actions.append(button(name,()=>paste(token),"chip"));
 }
 left.append(actions);
 left.append(el("h4","2 · Elige el color"));
 left.append(el("p","Selecciona una palabra y pulsa un color. Se insertará una etiqueta RGB que no depende del windowskin.","sub"));
 const palette=el("div",null,"color-swatches");left.append(palette);
 for(const sw of COLOR_PRESETS){
  const b=button("",()=>colored(sw.value),"color-swatch");
  b.title="Texto "+sw.name+" · "+sw.value;
  const dot=el("span",null,"swatch-dot");dot.style.background=sw.value;
  b.append(dot,el("span",sw.name));palette.append(b);
 }
 const rgb=el("div",null,"csb-color-tools"),rgbPicker=el("input"),rgbReadout=el("span","#FFCF59","sub");
 rgbPicker.type="color";rgbPicker.value="#FFCF59";rgbPicker.title="Elegir un color RGB";
 rgbPicker.oninput=()=>rgbReadout.textContent=rgbPicker.value.toUpperCase();
 rgb.append(rgbPicker,rgbReadout,button("Aplicar mi color",()=>colored(rgbPicker.value),"btn primary"));
 rgb.append(button("Color y sombra",()=>{
   current=DIRECTIVES.find(x=>x.kind==="hex-pair");
   parameter="FFCF59,404040";group="Colores";draw();
 },"btn"));
 left.append(rgb);
 left.append(el("h4","3 · ¿Dónde aparece el cuadro?"));
 const positionRow=el("div",null,"csb-position-controls"),positionButtons=[];
 for(const [id,label]of [["wu","Arriba"],["wm","Centro"],["wd","Abajo"]]){
  const b=button("",()=>{
   editor.value=setMessagePosition(editor.value,id);
   editor.dispatchEvent(new Event("input"));editor.focus();
  },"csb-pos");
  b.dataset.pos=id;b.title="Colocar el diálogo "+label.toLowerCase();
  b.append(el("span",null,"mini-screen"),el("small",label));
  positionRow.append(b);positionButtons.push(b);
 }
 left.append(positionRow);
 left.append(el("h4","4 · Vista previa"));
 const preview=el("div",null,"csb-preview-canvas");left.append(preview);
 left.append(el("p","Esta representación permite comprobar el texto RGB y la posición. Los colores numerados, las fuentes, las imágenes y los sonidos dependen del juego.","csb-visual-hint"));
 const insert=button("✓ Añadir mensaje al evento",()=>onInsert(editor.value.replace(/\r/g,"").split("\n").map((line,i)=>({code:i?401:101,parameters:[line],indent:0}))),"btn primary");
 if(typeof renderTarget==="function")renderTarget(left,insert);
 left.append(insert);
 const status=el("div","","sub");left.append(status);
 editor.addEventListener("input",update);update();

 right.append(el("h4","Más efectos visuales y de texto"));
 right.append(el("p","Elige el efecto por su nombre; no necesitas conocer la sintaxis.","sub"));
 const search=el("input");search.className="search";search.placeholder="Color, ventana, sonido, pausa…";right.append(search);
 const categories=el("div",null,"chips");right.append(categories);
 const results=el("div",null,"resultlist");right.append(results);
 const inspector=el("div",null,"card");right.append(inspector);
 let group="Todas",current=null,parameter="";
 function selectDirective(d){
   current=d;
   const m=d.token.match(/\[([^\]]*)\]/)||d.token.match(/=([^<>]+)/);
   parameter=m?.[1]||"1";showInspector();
 }
 function draw(){
  categories.replaceChildren();
  for(const category of ["Todas",...GROUPS])
   categories.append(button(category,()=>{group=category;draw();},"chip"+(group===category?" selected":"")));
  results.replaceChildren();
  const query=search.value.trim().toLowerCase();
  const found=DIRECTIVES.filter(d=>(group==="Todas"||group===d.category)&&[d.title,d.description,d.token].join(" ").toLowerCase().includes(query));
  for(const item of found){
   const b=button("",()=>selectDirective(item));
   const row=el("span",null,"csb-token-row");
   let sample=SWATCHES[item.title]||((item.kind==="hex-color"||item.kind==="hex-pair")?"#FFB700":item.kind==="color-index"?"#94A9D9":null);
   if(sample){const dot=el("span",null,"swatch-dot");dot.style.background=sample;row.append(dot);}
   else row.append(el("span",COMMAND_ICONS[item.category]||"·"));
   const label=el("span",null,"token-title");
   label.append(el("strong",item.title),el("small",item.token+" · "+item.description));
   row.append(label);b.append(row);results.append(b);
  }
  if(!found.length)results.append(el("div","Sin efectos coincidentes.","sub"));
  showInspector();
 }
 function showInspector(){
  inspector.replaceChildren();
  if(!current){
   inspector.append(el("p","Selecciona un efecto para configurar sus opciones y añadirlo al diálogo.","sub"));return;
  }
  inspector.append(el("strong",current.title),el("p",current.description,"sub"));
  const type=colorType(current);
  let input=null;
  if(current.parameter){
    const wrapper=el("div",null,"field");
    wrapper.append(el("label",current.parameter));
    input=el("input");input.value=parameter;input.style.width="100%";
    input.oninput=()=>{parameter=input.value;refresh();};
    wrapper.append(input);inspector.append(wrapper);
  }

  if(current.category==="Velocidad"&&current.parameter&&["nonnegative-integer","positive-integer"].includes(current.kind)){
    const speedBox=el("div",null,"card");
    speedBox.append(el("label","Ajuste visual de tiempo / velocidad","sub"));
    const slider=el("input");slider.type="range";slider.min="0";slider.max=current.token.toLowerCase().startsWith("\\ts")?"20":"200";slider.step="1";
    slider.value=String(Math.max(0,Math.min(Number(slider.max),Number(parameter)||0)));
    slider.style.width="100%";
    const readout=el("div",null,"sub");
    function sliderLabel(){
      const count=Number(parameter)||0;
      readout.textContent=current.token.toLowerCase().startsWith("\\ts")
       ?"Velocidad del texto: "+count+" (mayor número = más lento)"
       :"Duración aproximada: "+(count/20).toFixed(2)+" segundos ("+count+" unidades)";
    }
    slider.oninput=()=>{parameter=slider.value;if(input)input.value=parameter;sliderLabel();refresh();};
    if(input)input.addEventListener("input",()=>{
      slider.value=String(Math.max(0,Math.min(Number(slider.max),Number(parameter)||0)));
      sliderLabel();
    });
    speedBox.append(slider,readout);inspector.append(speedBox);sliderLabel();
  }
  const controls=el("div",null,"csb-color-tools");
  if(type==="rgb"){
    const pick=el("input");pick.type="color";
    try{pick.value="#"+normalizedHex(parameter);}catch(_){pick.value="#FFB700";}
    pick.oninput=()=>{parameter=pick.value.slice(1).toUpperCase();if(input)input.value=parameter;refresh();};
    controls.append(pick,el("span","Color RGB exacto","sub"));
  }else if(type==="rgb-shadow"){
    const parts=String(parameter).split(",");
    for(const [name,idx]of [["Texto",0],["Sombra",1]]){
      const pick=el("input");pick.type="color";
      try{pick.value="#"+normalizedHex(parts[idx]);}catch(_){pick.value=idx===0?"#FFB700":"#404040";}
      pick.title="Color "+name;
      pick.oninput=()=>{
       parts[idx]=pick.value.slice(1).toUpperCase();parameter=parts.join(",");
       if(input)input.value=parameter;refresh();
      };
      controls.append(el("span",name,"sub"),pick);
    }
  }else if(type==="index"){
    controls.append(el("p","Atención: los colores numerados dependen de la ventana elegida. Estos tonos son solo una referencia.","csb-visual-hint"));
    const swatches=el("div",null,"color-swatches");
    WINDOW_COLOR_HINTS.forEach((hex,i)=>{
      const b=button("",()=>{parameter=String(i);if(input)input.value=parameter;refresh();},"color-swatch");
      const dot=el("span",null,"swatch-dot");dot.style.background=hex;b.append(dot,el("span",String(i)));
      b.title="Índice "+i+", depende del windowskin";swatches.append(b);
    });
    controls.append(swatches);
  }
  if(controls.childNodes.length)inspector.append(controls);
  const example=el("div","Ejemplo de texto","csb-color-example");
  if(["rgb","rgb-shadow","index"].includes(type))inspector.append(example);
  const code=el("pre","","preview");code.style.minHeight="28px";inspector.append(code);
  const error=el("div","","sub");inspector.append(error);
  const add=button("Insertar en mi mensaje",()=>{
    try{
      const selection=editor.value.slice(editor.selectionStart,editor.selectionEnd)||"texto";
      paste(codeFor(current,current.parameter?parameter:null,selection));
      error.textContent="";
    }catch(e){error.textContent=e.message;}
  },"btn primary");inspector.append(add);
  function refresh(){
    try{
      code.textContent=codeFor(current,current.parameter?parameter:null);
      add.disabled=false;error.textContent="";
      let color="#FFFFFF",shadow="";
      if(type==="rgb")color="#"+normalizedHex(parameter);
      else if(type==="rgb-shadow"){const pair=parameter.split(",");color="#"+normalizedHex(pair[0]);shadow="#"+normalizedHex(pair[1]);}
      else if(type==="index")color=WINDOW_COLOR_HINTS[Number(parameter)]||"#FFFFFF";
      example.style.color=color;example.style.textShadow=shadow?"1px 1px 0 "+shadow:"none";
    }catch(e){code.textContent="";error.textContent=e.message;add.disabled=true;}
  }
  refresh();
 }
 search.oninput=draw;draw();
 host.append(el("div","Referencia: Essentials Docs, LA BASE DE SKY y el motor de mensajes de Vermeil. Los controles no se ejecutan en la vista previa.","hint"));
}
