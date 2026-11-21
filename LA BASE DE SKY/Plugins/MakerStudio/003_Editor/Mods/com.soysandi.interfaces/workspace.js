// Mejoras no destructivas del espacio de trabajo. Mantiene el modelo, el
// inspector, las animaciones y el formato UI/*.json originales de SoySandi.
export function montarEspacio(editor, M) {
  const root = editor.raiz;
  const disposers = [];
  const state = { focus:false, layers:true, inspector:true, timeline:false };
  const sceneGroups=[
    {name:"Libreta",pages:[["Libreta/Catalogo","Catálogo"],["Libreta/Ficha","Ficha"]]},
    {name:"Pokédex",pages:[["Pokedex/Lista","Listado"],["Pokedex/Ficha","Ficha"],
                           ["Pokedex/Area","Área"],["Pokedex/Formas","Formas"]]}
  ];
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
    body.addEventListener("click",ev=>{if(ev.target.closest("button"))d.open=false;});
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
  const background=action("▧ Fondo de pantalla",()=>{editor.anadirFondo();palette.d.open=false;},"Crear una imagen detrás de todos los elementos, ajustada al lienzo");
  choices.append(background);
  const palette=menu("＋ Elemento ▾",[search,choices,empty]);
  const addLabel=editor.barraAnadir.querySelector(".ui-capa-tipo");
  editor.barraAnadir.classList.add("ui-add-toolbar");
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
  // Un solo encabezado: el toolbar original se conserva a nivel de handlers,
  // pero sus acciones pasan a la barra principal.
  editor.barra.insertBefore(palette.d,fileMenu.d.nextSibling);
  const editButtons=Array.from(editor.barraAnadir.querySelectorAll("button"))
    .filter(b=>!choices.contains(b));
  const editMenu=menu("Editar ▾",editButtons);
  editor.barra.insertBefore(editMenu.d,palette.d.nextSibling);
  editor.barraAnadir.remove();
  // El bloque de resolución sigue siendo el componente original (instancia
  // Resolucion); se muestra como panel emergente en vez de ocho filas.
  const res=editor.resolucion;
  const layout=res.el;
  const group=(title,children)=>{
    const section=node("section","ui-resolution-group");
    section.append(node("h4",null,title));
    children.forEach(n=>section.append(n));
    return section;
  };
  const sizeInputs=node("div","ui-resolution-sizes");
  res.ancho.setAttribute("aria-label","Ancho del lienzo en píxeles");
  res.alto.setAttribute("aria-label","Alto del lienzo en píxeles");
  res.estrategia.setAttribute("aria-label","Cómo adaptar los elementos al cambiar la resolución");
  res.modo.setAttribute("aria-label","Modo de escalado del lienzo");
  sizeInputs.append(res.ancho,node("span",null,"×"),res.alto,res.info);
  const strategyRow=node("div","ui-resolution-action");
  strategyRow.append(res.estrategia,res.btnAplicar);
  const checkRow=node("div","ui-resolution-checks");
  checkRow.append(res.pixel,res.entera,res.segura,res.bloqueo);
  layout.replaceChildren(
    group("Tamaño lógico del juego",[res.preset,sizeInputs]),
    group("Al cambiar el tamaño",[strategyRow,
      node("p","ui-resolution-note","El tamaño solo cambia al pulsar Aplicar; la vista previa mantiene sus píxeles lógicos.")]),
    group("Presentación",[node("span","ui-resolution-label","Modo de escalado"),res.modo,checkRow])
  );
  const canvasMenu=menu("▣ Lienzo ▾",[layout]);
  canvasMenu.d.classList.add("ui-canvas-menu");
  editor.barra.insertBefore(canvasMenu.d,editMenu.d.nextSibling);
  editor.barra.insertBefore(copy,editor.btnGuardar);
  const copyLabel=copy.textContent;
  copy.textContent="⎘ Llamada";
  copy.title=copyLabel+" · "+copy.title;
  const canvasTitle=canvasMenu.d.querySelector("summary");
  const resLabel=()=>{
    const l=editor.diseno?.lienzo;
    canvasTitle.textContent=l?"▣ Lienzo "+l.ancho+"×"+l.alto+" ▾":"▣ Lienzo ▾";
  };

  // Herramientas para el workspace estilo BAS/BSS. No superpone una ventana a
  // los diálogos del editor: maximizar aquí es concentrar el espacio útil.
  const bar=node("div","ui-workspace-bar");
  const section=node("div","ui-workspace-caption");
  section.append(node("b",null,"VISTA"),node("span",null,"Ajusta el espacio"));
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
    // Ajustar después del reflow, no antes de cambiar las dimensiones reales.
    // Preserve canvas position and zoom when opening/closing tool panes.
  };
  for(const [key,label,title] of [
    ["layers","Capas","Mostrar u ocultar la lista de capas"],
    ["inspector","Propiedades","Mostrar u ocultar las propiedades"],
    ["timeline","Línea de tiempo","Mostrar u ocultar el editor de animaciones · F7"],
    ["focus","Solo lienzo","Concentrarse en el dibujo sin cerrar cuadros de diálogo · F6"]
  ]){
    const b=action(label,()=>toggle(key),title);toggles[key]=b;bar.append(b);
  }
  bar.append(node("span","ui-barra-hueco"));
  // Reubicar el control real de zoom y el botón original "Encajar" evita
  // duplicados entre el pie de canvas y la barra de vista.
  const zoomLabel=editor.selZoom.previousElementSibling;
  if(zoomLabel?.textContent?.trim()==="Zoom")zoomLabel.remove();
  const fit=Array.from(editor.pie.querySelectorAll("button"))
    .find(b=>b.textContent.trim()==="Encajar");
  bar.append(node("span","ui-workspace-zoom-label","Zoom"),editor.selZoom);
  if(fit){fit.classList.add("ui-workspace-btn");bar.append(fit);}
  else bar.append(action("⤢ Encajar",()=>editor.lienzo.encajar(),
    "Ajustar el canvas sin modificar su resolución"));
  const help=action("Atajos ?",async()=>{
    const content=[
      "Alt+← / Alt+→: navegar entre pantallas.  Ctrl+J: buscar pantalla.",
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
  // Persistent, low-motion navigation between the REAL in-game screens.
  const nav=node("nav","ui-native-navigation");
  const navTop=node("div","ui-native-navigation-top");
  const searchScreens=node("input","ui-txt ui-native-screen-search");
  searchScreens.type="search";
  searchScreens.placeholder="Buscar pantalla…";
  searchScreens.setAttribute("aria-label","Buscar pantalla por nombre");
  const datalist=document.createElement("datalist");
  datalist.id="ui-vermeil-screen-options";
  searchScreens.setAttribute("list",datalist.id);
  const goScreen=async id=>{
    if(!id||id===editor.nombre)return;
    await editor.abrir(id);
    if(editor.nombre===id)searchScreens.value="";
    navUpdate();
  };
  const currentGroup=()=>sceneGroups.find(g=>g.pages.some(([id])=>id===editor.nombre));
  const pageOptions=()=>{
    const g=currentGroup();
    return g?g.pages.map(([id])=>id).filter(id=>editor.disponibles.includes(id)):
             [...editor.disponibles];
  };
  const goRelative=delta=>{
    const pages=pageOptions(),idx=pages.indexOf(editor.nombre);
    if(idx+delta>=0 && idx+delta<pages.length)goScreen(pages[idx+delta]);
  };
  const prev=action("← Anterior",()=>goRelative(-1),"Pantalla anterior");
  const next=action("Siguiente →",()=>goRelative(1),"Pantalla siguiente");
  const groupsRow=node("div","ui-native-page-groups");
  const helpLabel=node("span","ui-native-navigation-help");
  const groupButtons=[];
  for(const group of sceneGroups){
    const block=node("div","ui-native-page-group");
    block.append(node("span","ui-native-page-caption",group.name));
    for(const [id,label] of group.pages){
      const b=action(label,()=>goScreen(id),"Abrir "+group.name+" · "+label);
      b.classList.add("ui-native-page");
      b.dataset.screen=id;
      block.append(b);
      groupButtons.push(b);
    }
    groupsRow.append(block);
  }
  navTop.append(node("strong",null,"PANTALLAS"),searchScreens,datalist,prev,next);
  nav.append(navTop,groupsRow,helpLabel);
  root.insertBefore(nav,bar);

  // Full library in the left sidebar: physical UI/<folder>/<screen>.json.
  // Each folder is one interface, containing all the screens required.
  const library=node("section","ui-interface-library");
  const libraryTitle=node("div","ui-library-title");
  const newFolder=action("+ Carpeta",()=>editor.nuevaCarpeta(),"Crear una nueva interfaz y su carpeta UI/");
  libraryTitle.append(node("strong",null,"BIBLIOTECA"),newFolder);
  const tree=node("div","ui-library-tree");
  library.append(libraryTitle,tree);
  editor.capas.el.insertBefore(library,editor.capas.buscar);
  let treeSignature="";
  const openedFolders=new Set(["Libreta","Pokedex"]);
  const syncLibrary=names=>{
    const signature=names.join("|");
    if(signature!==treeSignature){
      treeSignature=signature;
      tree.replaceChildren();
      const byFolder=new Map();
      for(const full of names){
        const slash=full.indexOf("/");
        const folder=slash<0?(full.startsWith("vermeil_")?"Compatibilidad":"Sin carpeta"):
          full.slice(0,slash);
        const page=slash<0?full:full.slice(slash+1);
        if(!byFolder.has(folder))byFolder.set(folder,[]);
        byFolder.get(folder).push({id:full,label:page});
      }
      for(const [folder,entries] of [...byFolder.entries()].sort((a,b)=>a[0].localeCompare(b[0],"es"))){
        const group=node("details","ui-library-folder");
        const current=entries.some(x=>x.id===editor.nombre);
        group.open=openedFolders.has(folder)||current;
        const title=node("summary","ui-library-folder-title");
        title.append(node("span",null,folder==="Pokedex"?"Pokédex":folder),
                     node("small",null,String(entries.length)));
        group.append(title);
        const body=node("div","ui-library-folder-content");
        for(const item of entries){
          const button=action(item.label,()=>goScreen(item.id),"Abrir "+item.id);
          button.classList.add("ui-library-screen");
          button.dataset.screen=item.id;
          body.append(button);
        }
        if(folder!=="Compatibilidad"&&folder!=="Sin carpeta"){
          const add=action("+ Pantalla",()=>editor.nuevoEnCarpeta(folder),
                           "Crear otra pantalla en UI/"+folder);
          add.classList.add("ui-library-add-page");
          body.append(add);
        }
        group.append(body);
        group.addEventListener("toggle",()=>{
          if(group.open)openedFolders.add(folder);else openedFolders.delete(folder);
        });
        tree.append(group);
      }
    }
    tree.querySelectorAll(".ui-library-screen").forEach(b=>{
      const active=b.dataset.screen===editor.nombre;
      b.classList.toggle("ui-native-active",active);
      b.setAttribute("aria-current",active?"page":"false");
    });
  };
  let lastNames="";
  const navUpdate=()=>{
    const names=editor.disponibles||[],signature=names.join("|");
    syncLibrary(names);
    if(signature!==lastNames){
      lastNames=signature;
      datalist.replaceChildren(...names.map(name=>{
        const option=document.createElement("option");option.value=name;return option;
      }));
    }
    const pages=pageOptions(),index=pages.indexOf(editor.nombre);
    prev.disabled=index<=0;
    next.disabled=index<0||index>=pages.length-1;
    groupButtons.forEach(b=>{
      b.hidden=!names.includes(b.dataset.screen);
      const active=b.dataset.screen===editor.nombre;
      b.classList.toggle("ui-native-active",active);
      b.setAttribute("aria-current",active?"page":"false");
    });
    groupsRow.hidden=!names.some(n=>n.startsWith("Libreta/")||n.startsWith("Pokedex/"));
    helpLabel.textContent=currentGroup()?
      "Interfaz nativa conectada: los cambios del JSON se aplican al reabrir el juego.":
      "Selecciona una capa, edítala en Propiedades y guarda con Ctrl+S.";
    copy.hidden=!!currentGroup();
  };
  searchScreens.addEventListener("keydown",ev=>{
    if(ev.key==="Escape"){searchScreens.value="";searchScreens.blur();ev.preventDefault();}
    if(ev.key!=="Enter")return;
    const term=searchScreens.value.trim().toLocaleLowerCase("es");
    const matches=(editor.disponibles||[]).filter(n=>n.toLocaleLowerCase("es").includes(term));
    if(matches.length){goScreen(matches[0]);ev.preventDefault();}
  });
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
    resLabel();
    navUpdate();
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
        // Keep the current zoom after resizing the side panels.
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
  // El timeline permanece disponible como transporte compacto mientras
  // sus pistas de animación están cerradas. Sus controles avanzados no ocupan
  // una segunda o tercera fila hasta que el usuario quiera animar.
  editor.tiempo.selPropiedad.classList.add("ui-timeline-advanced");
  editor.tiempo.btnAnadir.classList.add("ui-timeline-advanced");
  drawState();update();
  let hasFitted=false;
  const fitOnOpen=()=>requestAnimationFrame(()=>{
    if(root.isConnected&&editor.diseno&&!hasFitted){
      hasFitted=true;
      editor.lienzo.encajar();
    }
  });
  return {
    update,fitOnOpen,
    openPalette(){palette.d.open=true;search.focus();},
    nextScreen(){goRelative(1);},
    previousScreen(){goRelative(-1);},
    focusScreenSearch(){searchScreens.focus();searchScreens.select();},
    toggleFocus(){toggle("focus");},
    toggleTimeline(){toggle("timeline");},
    showTimeline(){
      if(!state.timeline){state.timeline=true;drawState();
        // The user keeps their current zoom/scroll while editing animation.}
    },
    destroy(){disposers.forEach(fn=>fn());closeMenus();}
  };
}
