// Mejoras no destructivas del espacio de trabajo. Mantiene el modelo, el
// inspector, las animaciones y el formato UI/*.json originales de SoySandi.
export function montarEspacio(editor, M) {
  const root = editor.raiz;
  const disposers = [];
  const state = { focus:false, layers:true, inspector:true, timeline:true };
  const node = (tag, cls, text) => {
    const n = document.createElement(tag);
    if (cls) n.className = cls;
    if (text != null) n.textContent = text;
    return n;
  };
  const action = (label, callback, title) => {
    const b = node("button","ui-btn ui-workspace-btn",label);
    b.type="button";if(title)b.title=title;
    b.addEventListener("click",callback);
    return b;
  };
  const closeMenus = (except=null) => {
    root.querySelectorAll("details.ui-workspace-menu[open]").forEach(d=>{
      if (d!==except) d.open=false;
    });
  };
  const menu = (title, contents) => {
    const d=node("details","ui-workspace-menu");
    const summary=node("summary",null,title);
    const body=node("div","ui-workspace-dropdown");
    d.append(summary,body);
    contents.forEach(c=>body.append(c));
    summary.addEventListener("click",()=>closeMenus(d));
    d.addEventListener("toggle",()=>{if(d.open)closeMenus(d);});
    return { d, body };
  };
  const original = Array.from(editor.barra.children);
  const byText = t => original.find(x=>x.tagName==="BUTTON" && x.textContent.trim()===t);
  const newButton=byText("Nuevo..."),copyButton=byText("Duplicar..."),deleteButton=byText("Borrar...");
  const openingsButton=byText("Mapa de aperturas");
  const badge=node("div","ui-workspace-brand");
  badge.append(node("strong",null,"INTERFACE STUDIO"),node("small",null,"Editor de Interfaces · Essentials"));
  editor.barra.prepend(badge);
  const fileMenu=menu("Archivo ▾",[newButton,copyButton,deleteButton].filter(Boolean));
  editor.barra.insertBefore(fileMenu.d,editor.etiquetaSucio);
  if(openingsButton){
    const tools=menu("Herramientas ▾",[openingsButton]);
    editor.barra.insertBefore(tools.d,editor.avisosBtn);
  }
  const copy=action("⎘ Copiar llamada",async()=>{
    const name=editor.nombre;
    if(!name){editor.toast("Primero guarda este diseño para asignarle un nombre.","warning");return;}
    const command="pbInterfaz("+JSON.stringify(name)+")";
    try{
      if(!navigator?.clipboard?.writeText)throw new Error("Clipboard no disponible");
      await navigator.clipboard.writeText(command);
      editor.toast("Comando para evento copiado: "+command,"success");
    }catch(_){
      // Mostrar el texto sin inventar que se copió.
      try{
        const result=window.prompt("Copia la llamada y pégala en un comando Script del evento:",command);
        if(result!=null)editor.toast("Llamada mostrada: "+command,"info");
      }catch(_2){editor.toast("Comando: "+command,"info");}
    }
  },"Para eventos Ruby: pbInterfaz(\"nombre\")");
  editor.barra.insertBefore(copy,editor.avisosBtn);
  // Convertir los ocho botones de creación originales en una paleta buscable:
  // se MUEVEN los nodos (y sus handlers), nunca se recrea su funcionalidad.
  const originalAdd=Array.from(editor.barraAnadir.children).filter(n=>n.tagName==="BUTTON" &&
    M.TIPOS.some(t=>M.NOMBRE_TIPO[t]===n.textContent.trim()));
  const search=node("input","ui-txt ui-workspace-search");
  search.type="search";search.placeholder="Buscar elemento…";search.setAttribute("aria-label","Buscar tipo de elemento");
  const choices=node("div","ui-workspace-choices");
  originalAdd.forEach((button,i)=>{
    button.classList.add("ui-workspace-option");
    button.dataset.search=String(M.NOMBRE_TIPO[M.TIPOS[i]]||button.textContent).toLocaleLowerCase("es");
    choices.append(button);
    button.addEventListener("click",()=>{palette.d.open=false;search.value="";filter();});
  });
  const filter=()=>{
    const term=search.value.trim().toLocaleLowerCase("es");
    let count=0;
    originalAdd.forEach(b=>{const show=b.dataset.search.includes(term);b.hidden=!show;if(show)count++;});
    empty.hidden=count!==0;
  };
  const empty=node("p","ui-ayuda","No se encontraron componentes.");
  empty.hidden=true;
  const palette=menu("＋ Añadir elemento ▾",[search,choices,empty]);
  const addLabel=editor.barraAnadir.querySelector(".ui-capa-tipo");
  editor.barraAnadir.insertBefore(palette.d,addLabel||editor.barraAnadir.firstChild);
  if(addLabel)addLabel.remove();
  palette.d.addEventListener("toggle",()=>{if(palette.d.open){search.value="";filter();search.focus();}});
  search.addEventListener("input",filter);
  search.addEventListener("keydown",ev=>{
    if(ev.key==="Escape"){palette.d.open=false;editor.raiz.focus();ev.preventDefault();}
    if(ev.key==="Enter"){
      const first=originalAdd.find(b=>!b.hidden);
      if(first){first.click();ev.preventDefault();}
    }
  });
  editor.barraAnadir.insertBefore(action("▣ Fondo completo",()=>editor.anadirFondo()),palette.d.nextSibling);

  // Herramientas para el workspace estilo BAS/BSS. No superpone una ventana a
  // los diálogos del editor: maximizar aquí es concentrar el espacio útil.
  const bar=node("div","ui-workspace-bar");
  const section=node("div","ui-workspace-caption");
  section.append(node("b",null,"ESPACIO DE TRABAJO"),node("span",null,"Biblioteca · Canvas · Inspector"));
  bar.append(section);
  const divider=node("div","ui-workspace-divider");
  bar.append(divider);
  const toggles={};
  const drawState=()=>{
    root.classList.toggle("ui-workspace-focus",state.focus);
    root.classList.toggle("ui-workspace-hide-layers",!state.layers);
    root.classList.toggle("ui-workspace-hide-inspector",!state.inspector);
    root.classList.toggle("ui-workspace-hide-timeline",!state.timeline);
    for(const [key,b] of Object.entries(toggles)){
      const active=key==="focus"?state.focus:state[key];
      b.classList.toggle("ui-workspace-selected",active);
      b.setAttribute("aria-pressed",String(active));
    }
  };
  const toggle=(key)=>{
    state[key]=!state[key];
    if(key==="focus" && state.focus){state.layers=false;state.inspector=false;}
    else if(key==="focus" && !state.focus){state.layers=true;state.inspector=true;}
    if((key==="layers"||key==="inspector")&&state.focus&&state.layers&&state.inspector)state.focus=false;
    drawState();
  };
  for(const [key,label,title] of [
    ["layers","Capas","Mostrar u ocultar la lista de capas"],
    ["inspector","Inspector","Mostrar u ocultar el inspector de propiedades"],
    ["timeline","Animaciones","Mostrar u ocultar la línea de tiempo"],
    ["focus","Lienzo amplio","Más área para diseñar sin bloquear ventanas emergentes · F6"]
  ]){
    const b=action(label,()=>toggle(key),title);toggles[key]=b;bar.append(b);
  }
  bar.append(node("span","ui-barra-hueco"));
  const fit=action("⤢ Encajar",()=>editor.lienzo.encajar(),"Ajustar resolución lógica al espacio disponible");
  bar.append(fit);
  const help=action("Atajos ?",async()=>{
    const content=[
      "Ctrl+K: buscar y añadir elemento.  F6: lienzo amplio.  F7: mostrar/ocultar animaciones.",
      "Ctrl+S: guardar.  Ctrl+D: duplicar.  Ctrl+Z / Ctrl+Mayús+Z: deshacer / rehacer.",
      "Ctrl/Mayús+clic: selección múltiple.  Arrastrar hueco: selección rectangular.",
      "Flechas: mover 1 px; Mayús+flechas: 8 px.  Alt+arrastrar: sin imán.",
      "Ctrl+rueda: zoom al puntero.  Espacio+arrastrar o botón central: desplazar canvas.",
      "Mayús+esquina: conservar proporción.  Mayús+rotación: pasos de 15°.",
      "Los datos y condiciones siguen en el Inspector. El JSON se guarda en UI/."
    ].join("\n");
    try{await editor.ctx.ui.showConfirmDialog({title:"Atajos de Interface Studio",message:content});}
    catch(_){editor.toast("Ctrl+K paleta · F6 lienzo amplio · F7 animaciones · Ctrl+S guardar","info");}
  },"Ver guía rápida de manejo");
  bar.append(help);
  root.insertBefore(bar,editor.cuerpo);
  // Evitar robar las teclas a otros diálogos: el editor sólo debe
  // recibir atajos tras interactuar con SU propio lienzo.
  root.tabIndex=0;
  const focusCanvas=()=>root.focus({preventScroll:true});
  editor.lienzo.el.addEventListener("pointerdown",focusCanvas,true);
  disposers.push(()=>editor.lienzo.el.removeEventListener("pointerdown",focusCanvas,true));
  // La barra de estado resume la selección actual sin tocar el modelo.
  const status=node("div","ui-workspace-status");
  const statusLeft=node("span");
  const statusRight=node("span");
  status.append(statusLeft,statusRight);
  root.insertBefore(status,editor.tiempo.el);
  const update=()=>{
    const d=editor.diseno,els=d?.elementos||[],selected=editor.extra?.size||0;
    statusLeft.textContent=(editor.nombre||"Sin guardar")+" · "+els.length+" elementos"+(selected?" · "+selected+" seleccionados":"");
    statusRight.textContent=d?.lienzo?d.lienzo.ancho+"×"+d.lienzo.alto+" · "+(editor.sucio?"Cambios pendientes":"Guardado"):"Configura un diseño";
  };
  // Redimensionadores acoplados al mismo cuerpo; no alteran canvas ni JSON.
  const resizers=[];
  for(const [side,pane] of [["left",editor.capas.el],["right",editor.inspector.el]]){
    const handle=node("div","ui-workspace-resizer "+side);
    handle.setAttribute("role","separator");handle.setAttribute("aria-orientation","vertical");
    handle.title="Arrastrar para cambiar tamaño · doble clic para restablecer";
    if(side==="left")editor.cuerpo.insertBefore(handle,editor.centro);
    else editor.cuerpo.insertBefore(handle,editor.inspector.el);
    const defaultWidth=side==="left"?220:300;
    const down=ev=>{
      if(ev.button!==0)return;ev.preventDefault();
      const startX=ev.clientX,start=pane.getBoundingClientRect().width;
      const min=side==="left"?175:255,max=side==="left"?430:600;
      handle.setPointerCapture(ev.pointerId);
      const move=event=>{
        const delta=(event.clientX-startX)*(side==="left"?1:-1);
        pane.style.width=Math.max(min,Math.min(max,start+delta))+"px";
      };
      const up=()=>{
        handle.removeEventListener("pointermove",move);
        handle.removeEventListener("pointerup",up);
        handle.removeEventListener("pointercancel",up);
      };
      handle.addEventListener("pointermove",move);
      handle.addEventListener("pointerup",up);
      handle.addEventListener("pointercancel",up);
    };
    handle.addEventListener("pointerdown",down);
    const reset=()=>{pane.style.width=defaultWidth+"px";};
    handle.addEventListener("dblclick",reset);
    disposers.push(()=>{handle.removeEventListener("pointerdown",down);handle.removeEventListener("dblclick",reset);});
    resizers.push(handle);
  }
  const outside=ev=>{if(!root.contains(ev.target))closeMenus();};
  document.addEventListener("pointerdown",outside,true);
  disposers.push(()=>document.removeEventListener("pointerdown",outside,true));
  drawState();update();
  return {
    update,
    openPalette(){palette.d.open=true;search.focus();},
    toggleFocus(){toggle("focus");},
    toggleTimeline(){toggle("timeline");},
    destroy(){disposers.forEach(fn=>fn());closeMenus();}
  };
}
