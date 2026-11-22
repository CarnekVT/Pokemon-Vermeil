// Interface Studio 3 — a single visual workspace, not a stack of toolbars.
// The existing Lienzo/Capas/Inspector/Tiempo/Resolucion are the data editors.
// This module owns navigation, the visual UI library and component insertion.
import * as G from "./graficos.js";

export function montarEspacio(editor, M) {
  const root=editor.raiz;
  root.classList.add("ui-studio-v3");
  const unsub=[];
  const state={library:true,timeline:false,palette:false,preview:false,folder:"Todos"};
  const cached=new Map();
  let listSignature="",lastName="",lastGallerySignature="",lastZoomScreen="";
  const node=(tag,cls,text)=>{
    const el=document.createElement(tag);
    if(cls)el.className=cls;
    if(text!==undefined)el.textContent=text;
    return el;
  };
  const btn=(label,act,cls,title)=>{
    const el=node("button",cls||"ui-btn",label);
    el.type="button";
    if(title)el.title=title;
    el.addEventListener("click",act);
    return el;
  };
  const searchable=(placeholder)=>{
    const e=node("input","ui-txt ui-studio-search");
    e.type="search";e.placeholder=placeholder;
    e.setAttribute("aria-label",placeholder);
    return e;
  };
  const folderOf=name=>name.includes("/")?name.split("/")[0]:
      name.startsWith("vermeil_")?"Compatibilidad":"Otras pantallas";
  const pageOf=name=>name.includes("/")?name.slice(name.indexOf("/")+1):name;
  const readableFolder=name=>name==="Pokedex"?"Pokédex":name;
  const firstButton=tag=>Array.from(editor.barra.children).find(x=>x.tagName==="BUTTON"&&x.textContent.trim()===tag);
  const originalAdd=Array.from(editor.barraAnadir.children).filter(n=>n.tagName==="BUTTON"&&
    M.TIPOS.some(t=>M.NOMBRE_TIPO[t]===n.textContent.trim()));
  const originalAddMap=new Map();
  originalAdd.forEach((b,i)=>originalAddMap.set(M.TIPOS[i],b));

  // --- One app header: no supplementary navigation bars. -------------------
  const header=editor.barra;
  header.classList.add("ui-studio-header");
  const brand=node("div","ui-studio-brand");
  brand.append(node("strong",null,"INTERFACE STUDIO"),
               node("small",null,"Vermeil · Visual UI"));
  const libraryButton=btn("Biblioteca",()=>showLibrary(),"ui-btn ui-studio-nav","Ver todas las interfaces y sus pantallas");
  const editButton=btn("Editar pantalla",()=>showEditor(),"ui-btn ui-studio-nav");
  const crumb=node("span","ui-studio-breadcrumb","");
  const spacer=node("span","ui-barra-hueco");
  const paletteButton=btn("＋ Elemento",()=>setPalette(true),"ui-btn ui-studio-primary","Crear o reutilizar un componente");
  const undo=btn("↶",()=>editor.deshacer(),"ui-btn","Deshacer");
  const redo=btn("↷",()=>editor.rehacer(),"ui-btn","Rehacer");
  const canvasButton=btn("Lienzo",()=>togglePanel(canvasPanel),"ui-btn","Resolución, escala y guías");
  const timelineButton=btn("Animación",()=>setTimeline(!state.timeline),"ui-btn","Mostrar u ocultar línea de tiempo");
  const fileMenu=node("details","ui-studio-menu");
  fileMenu.append(node("summary",null,"Archivo"));
  const fileActions=node("div","ui-studio-menu-actions");
  fileActions.append(
    btn("Nueva interfaz",()=>{showEditor();editor.nuevo();fileMenu.open=false;}),
    btn("Nueva carpeta",()=>{editor.nuevaCarpeta();fileMenu.open=false;}),
    btn("Duplicar pantalla",()=>{editor.duplicar();fileMenu.open=false;}),
    btn("Borrar pantalla",()=>{editor.borrar();fileMenu.open=false;}),
    btn("Mapa de aperturas",()=>{editor.mostrarMapaAperturas();fileMenu.open=false;}),
    btn("Copiar llamada Ruby",async()=>{
      if(!editor.nombre)return;
      const cmd="pbInterfaz("+JSON.stringify(editor.nombre)+")";
      try{await navigator.clipboard.writeText(cmd);editor.toast("Copiado: "+cmd,"success");}
      catch{window.prompt("Copia la llamada Ruby:",cmd);}
      fileMenu.open=false;
    })
  );
  fileMenu.append(fileActions);
  const hidden=node("div","ui-studio-compat-controls");
  hidden.append(editor.selDiseno);
  header.replaceChildren(brand,libraryButton,editButton,crumb,spacer,
      undo,redo,canvasButton,timelineButton,paletteButton,
      fileMenu,editor.avisosBtn,editor.etiquetaSucio,editor.btnGuardar,hidden);

  const canvasPanel=node("div","ui-studio-canvas-popover");
  canvasPanel.hidden=true;
  const canvasTitle=node("div","ui-studio-modal-title","Opciones de lienzo");
  canvasPanel.append(canvasTitle,editor.resolucion.el);
  root.append(canvasPanel);
  const togglePanel=panel=>{
    panel.hidden=!panel.hidden;
    if(!panel.hidden)fileMenu.open=false;
  };
  const onOutside=e=>{
    if(!canvasPanel.hidden&&!canvasPanel.contains(e.target)&&e.target!==canvasButton)
      canvasPanel.hidden=true;
    if(fileMenu.open&&!fileMenu.contains(e.target))fileMenu.open=false;
  };
  document.addEventListener("pointerdown",onOutside,true);
  unsub.push(()=>document.removeEventListener("pointerdown",onOutside,true));

  // --- A single compact tool strip, present only while editing. -------------
  const toolbar=editor.barraAnadir;
  toolbar.classList.add("ui-studio-toolstrip");
  const screenLabel=node("strong","ui-studio-current","");
  const miniStatus=node("span","ui-studio-mini-status","");
  const selectLabel=node("span",null,"Elegido");
  const zoomLabel=node("span",null,"Zoom");
  const zoomReset=btn("100%",()=>editor.lienzo.fijarZoom(1),"ui-btn","Zoom real 1:1");
  const fit=btn("Encajar",()=>editor.lienzo.encajar(),"ui-btn","Mostrar el lienzo completo");
  const gridToggle=btn("Rejilla",()=>{
    editor.lienzo.fijarRejilla(!editor.lienzo.rejilla);update();
  },"ui-btn");
  const snapToggle=btn("Imán",()=>{
    editor.lienzo.fijarImantar(!editor.lienzo.imantar);update();
  },"ui-btn");
  const previewToggle=btn("Vista limpia",()=>{
    state.preview=!state.preview;
    editor.lienzo.capa.style.visibility=state.preview?"hidden":"visible";
    update();
  },"ui-btn");
  toolbar.replaceChildren(screenLabel,miniStatus,node("span","ui-barra-hueco"),
      selectLabel,editor.selElegido,zoomLabel,editor.selZoom,zoomReset,fit,
      gridToggle,snapToggle,previewToggle);
  const groupTools=node("details","ui-studio-group-tools");
  groupTools.append(node("summary",null,"Alinear y distribuir selección"));
  groupTools.append(editor.barraGrupo);
  toolbar.append(groupTools);

  // --- Left sidebar: choose between folder navigation and real layer tree. ---
  const aside=editor.capas.el;
  const layerNodes=Array.from(aside.children);
  const tabs=node("div","ui-studio-side-tabs");
  const folderTab=btn("Biblioteca",()=>showLibrary(),"ui-studio-side-tab");
  const layerTab=btn("Capas",()=>showEditor(),"ui-studio-side-tab");
  tabs.append(folderTab,layerTab);
  aside.prepend(tabs);
  const libraryAside=node("div","ui-studio-library-aside");
  const folderTitle=node("div","ui-studio-side-caption","INTERFACES");
  const newFolder=btn("＋ Carpeta",()=>editor.nuevaCarpeta(),"ui-btn ui-studio-new-folder");
  const folderMenu=node("div","ui-studio-folder-list");
  libraryAside.append(folderTitle,newFolder,folderMenu);
  aside.insertBefore(libraryAside,tabs.nextSibling);

  // --- Full-size visual gallery, rendered directly from the saved UI JSON. ---
  const gallery=node("div","ui-studio-gallery");
  const galleryHead=node("div","ui-studio-gallery-head");
  const galleryTitle=node("div","ui-studio-gallery-title");
  galleryTitle.append(node("strong",null,"Biblioteca de interfaces"),
                      node("p",null,"Cada carpeta es una interfaz. Sus pantallas se editan de forma independiente."));
  const gallerySearch=searchable("Buscar pantallas, carpetas o componentes...");
  const galleryNew=btn("＋ Nueva pantalla",async()=>{
    const folder=state.folder==="Todos"?null:state.folder;
    if(folder && folder!=="Compatibilidad" && folder!=="Otras pantallas")
      await editor.nuevoEnCarpeta(folder);
    else await editor.nuevo();
    if(editor.diseno)showEditor();
  },"ui-btn ui-studio-primary");
  galleryHead.append(galleryTitle,gallerySearch,galleryNew);
  const galleryBody=node("div","ui-studio-gallery-body");
  gallery.append(galleryHead,galleryBody);
  editor.centro.prepend(gallery);

  async function loadSaved(name) {
    if(name===editor.nombre && editor.diseno)return editor.diseno;
    if(cached.has(name))return cached.get(name);
    try{
      const raw=await editor.ctx.fs.readProjectFile("UI/"+name+".json");
      const design=JSON.parse(raw);
      cached.set(name,design);
      return design;
    }catch{
      return null;
    }
  }

  // Prepare image assets BEFORE touching the canvas; asynchronous paints
  // previously interleaved with subsequent refreshes and corrupted layers.
  async function renderThumb(canvas,design) {
    if(!canvas.isConnected)return;
    const token=(canvas._uiPreviewToken||0)+1;
    canvas._uiPreviewToken=token;
    const width=Number(design?.lienzo?.ancho)||640;
    const height=Number(design?.lienzo?.alto)||480;
    const previewHeight=Math.max(60,Math.round(canvas.width*height/width));
    if(canvas.height!==previewHeight)canvas.height=previewHeight;
    if(canvas.parentElement)canvas.parentElement.style.aspectRatio=width+" / "+height;
    const items=(Array.isArray(design?.elementos)?design.elementos:[])
      .filter(el=>el.visible!==false)
      .map((el,i)=>({el,i}))
      .sort((a,b)=>(Number(a.el.capa)||0)-(Number(b.el.capa)||0)||a.i-b.i)
      .map(v=>v.el);
    const imageRows=items.filter(el=>
      (el.tipo==="imagen"||el.tipo==="animado")&&el.imagen);
    const images=new Map();
    await Promise.all(imageRows.map(async el=>{
      try{const cached=G.imagenEnCache(el.imagen);images.set(el,cached?.img?cached:await G.imagenDibujable(el.imagen));}
      catch{images.set(el,null);}
    }));
    if(!canvas.isConnected||token!==canvas._uiPreviewToken)return;
    const context=canvas.getContext("2d");
    if(!context)return;
    const scaleX=canvas.width/width,scaleY=canvas.height/height;
    context.save();
    try{
      context.setTransform(1,0,0,1,0,0);
      context.imageSmoothingEnabled=false;
      context.clearRect(0,0,canvas.width,canvas.height);
      context.fillStyle="#151d2a";
      context.fillRect(0,0,canvas.width,canvas.height);
      context.scale(scaleX,scaleY);
      for(const el of items){
        const x=Number(el.x)||0,y=Number(el.y)||0;
        const w=Math.max(0,Number(el.ancho)||0);
        const h=Math.max(0,Number(el.alto)||0);
        const fill=el.color&&/^#(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(el.color)?
          el.color:"#27374c";
        if(el.tipo==="panel"&&w&&h){
          context.fillStyle=fill;
          context.fillRect(x,y,w,h);
          if(el.borde&&/^#(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(el.borde)){
            context.strokeStyle=el.borde;
            context.lineWidth=Math.max(1,Number(el.borde_grosor)||1);
            context.strokeRect(x,y,w,h);
          }
        }else if(el.tipo==="texto"&&el.texto){
          const size=Math.max(9,Number(el.tamano)||16);
          context.font=(el.negrita?"bold ":"")+G.fuenteSegunTamano(size);
          context.fillStyle=fill;
          context.textBaseline="middle";
          context.save();
          context.beginPath();context.rect(x,y,w||160,h||size+4);context.clip();
          context.fillText(String(el.texto),x+2,y+(h||size+4)/2,w||200);
          context.restore();
        }else if((el.tipo==="imagen"||el.tipo==="animado")&&el.imagen){
          const src=images.get(el);
          if(src?.img)context.drawImage(src.img,x,y,w||src.ancho,h||src.alto);
        }else if(el.tipo==="boton"&&w&&h){
          context.fillStyle=fill;context.fillRect(x,y,w,h);
        }
      }
    }finally{context.restore();}
  }

  const refreshFolders=()=>{
    folderMenu.replaceChildren();
    const names=editor.disponibles||[];
    const count=new Map();
    for(const name of names){
      const folder=folderOf(name);
      count.set(folder,(count.get(folder)||0)+1);
    }
    for(const folder of ["Todos",...[...count.keys()].sort((a,b)=>a.localeCompare(b,"es"))]){
      const amount=folder==="Todos"?names.length:count.get(folder);
      const b=btn("",()=>{state.folder=folder;refreshFolders();rebuildGallery();},
                  "ui-studio-folder"+(state.folder===folder?" active":""));
      b.append(node("span",null,folder==="Todos"?"▦":"▣"),
               node("strong",null,readableFolder(folder)),
               node("small",null,String(amount)));
      folderMenu.append(b);
    }
  };

  async function rebuildGallery() {
    const names=editor.disponibles||[];
    const query=gallerySearch.value.trim().toLocaleLowerCase("es");
    const selected=names.filter(n=>
      (state.folder==="Todos"||folderOf(n)===state.folder)&&
      (!query||n.toLocaleLowerCase("es").includes(query)||
      (cached.get(n)?.elementos||[]).some(e=>
        String(e.etiqueta||e.id||"").toLocaleLowerCase("es").includes(query))));
    galleryBody.replaceChildren();
    if(!selected.length){
      galleryBody.append(node("div","ui-studio-no-pages",
        "No hay pantallas con este filtro. Cambia de carpeta o crea una."));
      return;
    }
    const grouped=new Map();
    for(const name of selected){
      const f=folderOf(name);
      if(!grouped.has(f))grouped.set(f,[]);
      grouped.get(f).push(name);
    }
    for(const [folder,entries] of grouped) {
      const section=node("section","ui-studio-gallery-section");
      const title=node("div","ui-studio-gallery-section-title");
      title.append(node("strong",null,readableFolder(folder)),
                   node("span",null,entries.length+" pantallas"));
      section.append(title);
      const grid=node("div","ui-studio-card-grid");
      for(const name of entries) {
        const card=btn("",async()=>{
          await editor.abrir(name);
          if(editor.nombre===name)showEditor();
        },"ui-studio-screen-card");
        card.dataset.screen=name;
        const frame=node("div","ui-studio-thumb-frame");
        const canvas=node("canvas","ui-studio-screen-thumb");
        canvas.width=320;canvas.height=240;
        frame.append(canvas);
        const label=node("div","ui-studio-screen-label");
        label.append(node("strong",null,pageOf(name)),
                     node("small",null,"UI/"+name+".json"));
        card.append(frame,label);
        grid.append(card);
        loadSaved(name).then(d=>renderThumb(canvas,d));
      }
      section.append(grid);
      galleryBody.append(section);
    }
  }

  // --- Component palette: common elements and coherent reusable blocks. -----
  const palette=node("div","ui-studio-palette");
  palette.hidden=true;
  palette.setAttribute("role","dialog");
  palette.setAttribute("aria-label","Añadir componente");
  const shade=btn("",()=>setPalette(false),"ui-studio-palette-shade","Cerrar");
  const paletteContent=node("section","ui-studio-palette-content");
  const paletteTop=node("div","ui-studio-palette-top");
  const paletteSearch=searchable("Buscar texto, panel, imagen, ficha...");
  const paletteClose=btn("Cerrar",()=>setPalette(false),"ui-btn");
  paletteTop.append(node("strong",null,"Añadir componentes"),paletteSearch,paletteClose);
  const paletteItems=node("div","ui-studio-palette-items");
  paletteContent.append(paletteTop,paletteItems);
  palette.append(shade,paletteContent);
  root.append(palette);
  const componentPresets=[
    ["Cabecera",[
      ["panel",{x:0,y:0,ancho:640,alto:56,color:"#1d293aff",etiqueta:"Fondo de cabecera",grupo:"01 · Cabecera"}],
      ["texto",{x:18,y:10,ancho:420,alto:35,texto:"TÍTULO",tamano:24,color:"#f2f6ff",etiqueta:"Título",grupo:"01 · Cabecera"}]
    ]],
    ["Ficha de especie",[
      ["panel",{x:24,y:60,ancho:270,alto:330,color:"#233449ff",etiqueta:"Panel de ficha",grupo:"02 · Ficha"}],
      ["texto",{x:38,y:72,ancho:245,alto:30,texto:"ESPECIE",tamano:22,color:"#f2f6ff",etiqueta:"Nombre",grupo:"02 · Ficha"}],
      ["texto",{x:38,y:338,ancho:245,alto:32,texto:"Descripción",tamano:18,color:"#a8bad1",etiqueta:"Descripción",grupo:"02 · Ficha"}]
    ]],
    ["Fila de lista",[
      ["panel",{x:310,y:74,ancho:300,alto:38,color:"#34455cff",etiqueta:"Fila",grupo:"03 · Lista"}],
      ["texto",{x:328,y:82,ancho:270,alto:22,texto:"Elemento de lista",tamano:18,color:"#f2f6ff",etiqueta:"Nombre de fila",grupo:"03 · Lista"}]
    ]],
    ["Barra de controles",[
      ["panel",{x:0,y:442,ancho:640,alto:38,color:"#1d2a3cff",etiqueta:"Barra de controles",grupo:"90 · Controles"}],
      ["texto",{x:16,y:450,ancho:608,alto:24,texto:"ACEPTAR · Elegir    ATRÁS · Volver",tamano:16,color:"#d3dfef",etiqueta:"Instrucciones",grupo:"90 · Controles"}]
    ]]
  ];
  function addPreset(parts) {
    if(!editor.diseno)return;
    editor.apuntarDeshacer();
    let layer=editor.diseno.elementos.reduce((max,e)=>Math.max(max,Number(e.capa)||0),0);
    let last=null;
    for(const [type,props] of parts){
      const id=M.idLibre(editor.diseno,type);
      const el={...M.elementoNuevo(type,id,props.x,props.y),...props};
      el.capa=layer+=10;
      editor.diseno.elementos.push(el);last=id;
    }
    editor.seleccion=last;
    editor.marcarSucio();editor.refrescarTodo();setPalette(false);
  }
  for(const [name,parts] of componentPresets){
    const b=btn(name,()=>addPreset(parts),"ui-studio-preset-item");
    b.dataset.search=name.toLocaleLowerCase("es");
    paletteItems.append(b);
  }
  const emptyCategory=node("div","ui-studio-palette-caption","ELEMENTOS INDIVIDUALES");
  paletteItems.append(emptyCategory);
  originalAdd.forEach((button,i)=>{
    button.classList.add("ui-studio-preset-item");
    button.dataset.search=(M.NOMBRE_TIPO[M.TIPOS[i]]||button.textContent).toLocaleLowerCase("es");
    button.addEventListener("click",()=>setPalette(false));
    paletteItems.append(button);
  });
  paletteSearch.addEventListener("input",()=>{
    const q=paletteSearch.value.trim().toLocaleLowerCase("es");
    paletteItems.querySelectorAll(".ui-studio-preset-item").forEach(el=>{
      el.hidden=!el.dataset.search.includes(q);
    });
  });
  function setPalette(open){
    state.palette=!!open;
    palette.hidden=!state.palette;
    if(open){paletteSearch.value="";paletteSearch.dispatchEvent(new Event("input"));paletteSearch.focus();}
  }

  // --- View state and simple navigation. ------------------------------------
  gallerySearch.addEventListener("input",rebuildGallery);
  function showLibrary() {
    state.library=true;update();
    rebuildGallery();
  }
  function showEditor() {
    state.library=false;update();
    requestAnimationFrame(()=>{
      if(editor.diseno && lastZoomScreen!==editor.nombre){
        lastZoomScreen=editor.nombre;
        editor.lienzo.encajar();
      }
    });
  }
  function setTimeline(on) {
    state.timeline=!!on;
    editor.tiempo.el.hidden=!state.timeline;
    timelineButton.classList.toggle("active",state.timeline);
  }
  const helpStatus=node("div","ui-studio-status");
  root.insertBefore(helpStatus,editor.tiempo.el);
  const keyboard=e=>{
    if(!root.contains(e.target))return;
    if(e.ctrlKey&&e.key.toLowerCase()==="k"){
      e.preventDefault();showLibrary();gallerySearch.focus();gallerySearch.select();
    }
    if(e.key==="Escape"){
      if(state.palette){setPalette(false);e.preventDefault();}
      else if(!canvasPanel.hidden){canvasPanel.hidden=true;e.preventDefault();}
      else if(state.library){showEditor();e.preventDefault();}
    }
  };
  document.addEventListener("keydown",keyboard,true);
  unsub.push(()=>document.removeEventListener("keydown",keyboard,true));

  function update() {
    const names=editor.disponibles||[];
    const sig=names.join("|");
    if(sig!==listSignature){
      listSignature=sig;refreshFolders();
      if(state.library)rebuildGallery();
    }
    const n=editor.nombre||"Sin guardar";
    const folder=folderOf(n);
    crumb.textContent=editor.nombre?readableFolder(folder)+" / "+pageOf(n):"Nueva pantalla";
    screenLabel.textContent=pageOf(n);
    miniStatus.textContent=(editor.diseno?.elementos?.length||0)+" capas";
    editor.centro.style.minWidth="0";
    gallery.hidden=!state.library;
    editor.lienzo.el.hidden=state.library;
    editor.pie.hidden=state.library;
    editor.inspector.el.hidden=state.library;
    layerNodes.forEach(el=>{el.hidden=state.library;});
    libraryAside.hidden=!state.library;
    editButton.classList.toggle("active",!state.library);
    libraryButton.classList.toggle("active",state.library);
    folderTab.classList.toggle("active",state.library);
    layerTab.classList.toggle("active",!state.library);
    toolbar.hidden=state.library;
    editor.barraGrupo.hidden=state.library;
    gridToggle.classList.toggle("active",!!editor.lienzo.rejilla);
    snapToggle.classList.toggle("active",!!editor.lienzo.imantar);
    previewToggle.classList.toggle("active",!!state.preview);
    helpStatus.textContent=state.library?
      (names.length+" pantallas · selecciona una miniatura para editar") :
      (n+" · "+(editor.sucio?"CAMBIOS SIN GUARDAR":"Guardado")+" · doble clic en Capas para renombrar");
    if(!state.library&&lastName!==n){
      lastName=n;
      gallerySearch.value="";
    }
    if(state.library && editor.nombre && editor.diseno) {
      const canvas=galleryBody.querySelector('[data-screen="'+CSS.escape(editor.nombre)+'"] canvas');
      if(canvas)renderThumb(canvas,editor.diseno);
    }
  }

  setTimeline(false);update();
  return {
    update,
    saved(name){
      cached.delete(name);
      if(state.library)rebuildGallery();
      update();
    },
    fitOnOpen(){if(!state.library)requestAnimationFrame(()=>editor.lienzo.encajar());},
    openPalette(){setPalette(true);},
    nextScreen(){
      const names=editor.disponibles||[];
      const i=names.indexOf(editor.nombre);
      if(i>=0&&i<names.length-1)editor.abrir(names[i+1]).then(showEditor);
    },
    previousScreen(){
      const names=editor.disponibles||[];
      const i=names.indexOf(editor.nombre);
      if(i>0)editor.abrir(names[i-1]).then(showEditor);
    },
    focusScreenSearch(){showLibrary();gallerySearch.focus();gallerySearch.select();},
    toggleFocus(){state.preview=!state.preview;editor.lienzo.capa.style.visibility=state.preview?"hidden":"visible";update();},
    toggleTimeline(){setTimeline(!state.timeline);},
    showTimeline(){setTimeline(true);},
    destroy(){unsub.forEach(fn=>fn());}
  };
}
