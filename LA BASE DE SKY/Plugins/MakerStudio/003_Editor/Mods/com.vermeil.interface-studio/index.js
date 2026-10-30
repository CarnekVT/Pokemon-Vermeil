import {STYLES} from "./styles.js";
import {DATA_PATH,DATA_DIR,newProject,newScreen,newLayer,normalize,clone,uid,slug,validColor,makeRuby} from "./model.js";
const PANEL="com.vermeil.interface-studio.main";
const e=(tag,cls,text)=>{const n=document.createElement(tag);if(cls)n.className=cls;if(text!==undefined)n.textContent=String(text);return n;};
const esc=s=>String(s??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
const norm=s=>String(s||"").replace(/\\/g,"/").replace(/^\/+/,"");
const imageExt=p=>/\.(png|jpe?g|bmp|webp)$/i.test(p);
class InterfaceStudio {
  constructor(ctx,host){
    this.ctx=ctx;this.host=host;this.project=newProject();this.screenId=this.project.screens[0].id;
    this.selectedId=null;this.assets=[];this.assetQuery="";this.screenQuery="";this.libraryMode="screens";
    this.undoStack=[];this.redoStack=[];this.dirty=false;this.readOnly=false;
    this.zoom="fit";this.scale=1;this.grid=true;this.snap=true;this.pendingAssets=new Map();
    this.disposed=false;this.move=null;this.blobUrls=new Map();this.loadingImages=new Map();
    this.root=e("div","iv-root");this.root.tabIndex=0;this.root.append(e("style",null,STYLES));host.append(this.root);
    this.root.addEventListener("keydown",ev=>this.onKey(ev));
    this.render();
    this.resizeObserver=typeof ResizeObserver==="function"?new ResizeObserver(()=>this.sizeStage()):null;
    this.resizeObserver?.observe(this.root);
    this.load().catch(err=>this.error(err));
  }
  screen(){return this.project.screens.find(s=>s.id===this.screenId)||this.project.screens[0];}
  layer(){return this.screen()?.layers.find(l=>l.id===this.selectedId)||null;}
  toast(message,level="info"){try{this.ctx.ui.showToast({message:String(message),level,durationMs:3700});}catch(_){}}
  error(err){const msg=String(err?.message||err);this.toast(msg,"error");this.ctx.log?.error?.(msg);}
  status(text){const node=this.root.querySelector("[data-status]");if(node)node.textContent=text;}
  pushUndo(){
    this.undoStack.push(clone(this.project));if(this.undoStack.length>80)this.undoStack.shift();
    this.redoStack=[];this.dirty=true;
  }
  edit(fn){
    if(this.readOnly)return this.toast("La lectura ha fallado; no se permite guardar encima del archivo.","error");
    this.pushUndo();fn();this.render();
  }
  undo(){
    if(!this.undoStack.length)return;this.redoStack.push(clone(this.project));
    this.project=this.undoStack.pop();this.repairSelection();this.dirty=true;this.render();
  }
  redo(){
    if(!this.redoStack.length)return;this.undoStack.push(clone(this.project));
    this.project=this.redoStack.pop();this.repairSelection();this.dirty=true;this.render();
  }
  repairSelection(){
    if(!this.project.screens.some(s=>s.id===this.screenId))this.screenId=this.project.screens[0].id;
    if(!this.layer())this.selectedId=null;
  }
  async load(){
    try{
      if(await this.ctx.fs.projectExists(DATA_PATH)){
        const data=JSON.parse(await this.ctx.fs.readProjectFile(DATA_PATH));
        this.project=normalize(data);
      }
      this.screenId=this.project.screens[0].id;this.selectedId=null;this.dirty=false;
      this.render();this.loadAssets();
    }catch(err){this.readOnly=true;this.error(new Error("No se cargó "+DATA_PATH+": "+String(err.message||err)+". No se sobrescribirá."));this.render();}
  }
  async save(){
    if(this.readOnly)return this.toast("Guardado bloqueado: revisa el JSON existente.","error");
    try{
      const data=normalize(this.project);
      await this.ctx.fs.projectMkdir(DATA_DIR);
      await this.ctx.fs.writeProjectFile(DATA_PATH,JSON.stringify(data,null,2)+"\n");
      this.dirty=false;this.renderHeaderStatus();this.toast("Pantallas guardadas en "+DATA_PATH,"success");
    }catch(err){this.error(err);}
  }
  async scan(base="Graphics/UI",max=2000){
    const found=[],seen=new Set();
    const walk=async(dir,depth)=>{
      if(depth>8||found.length>=max||seen.has(dir))return;seen.add(dir);
      let items=[];try{items=await this.ctx.fs.listProjectDir(dir)||[];}catch(_){return;}
      for(const item of items){
        if(found.length>=max)break;
        const name=typeof item==="string"?item:(item.name||item.path||"");
        if(!name)continue;
        const n=norm(name),path=n.startsWith(dir+"/")?n:dir+"/"+n;
        if(imageExt(path)){found.push(path);continue;}
        const directory=typeof item==="object" && (item.isDirectory===true||item.type==="directory"||item.kind==="directory");
        if(directory || (!/\.[^/]+$/.test(path) && depth<8))await walk(path,depth+1);
      }
    };
    await walk(base,0);return [...new Set(found)].sort((a,b)=>a.localeCompare(b,"es",{numeric:true}));
  }
  async loadAssets(){
    try{this.assets=await this.scan();if(!this.disposed)this.renderLibrary();}
    catch(err){this.error(err);}
  }
  button(label,handler,kind=""){
    const b=e("button","iv-btn "+kind,label);b.type="button";b.addEventListener("click",handler);return b;
  }
  input(value,handler,type="text"){
    const inp=e("input","iv-input");inp.type=type;inp.value=String(value??"");
    inp.addEventListener("change",()=>handler(type==="number"?Number(inp.value):inp.value));
    return inp;
  }
  select(options,value,handler){
    const s=e("select","iv-input");
    options.forEach(o=>{const op=e("option",null,o[1]);op.value=String(o[0]);s.append(op);});
    s.value=String(value);s.addEventListener("change",()=>handler(s.value));return s;
  }
  field(parent,label,control){
    const f=e("label","iv-field");f.append(e("span","iv-label",label),control);parent.append(f);return f;
  }
  render(){
    if(this.disposed)return;
    this.root.replaceChildren(e("style",null,STYLES));
    const header=e("header","iv-header");this.root.append(header);
    const brand=e("div","iv-brand");brand.append(e("b",null,"Interface Studio"),e("small",null,"Diseña · previsualiza · exporta"));header.append(brand);
    header.append(this.button("＋ Pantalla",()=>this.addScreen()),this.button("＋ Capa",()=>this.addLayer("panel")));
    header.append(this.button("↶",()=>this.undo(),"icon"),this.button("↷",()=>this.redo(),"icon"));
    header.append(this.button("Guardar",()=>this.save(),"primary"));
    header.append(this.button("Ruby…",()=>this.openCode()));
    header.append(e("span","iv-spacer"));
    this.saveBadge=e("span","iv-tag");header.append(this.saveBadge);
    header.append(this.button(this.isFullscreen()?"Ventana normal":"Pantalla completa",()=>this.toggleFullscreen()));
    const main=e("div","iv-main");this.root.append(main);
    const left=e("aside","iv-sidebar left");this.right=e("aside","iv-sidebar right");this.center=e("main","iv-stagearea");
    main.append(left,this.center,this.right);
    this.renderLeft(left);this.renderCenter();this.renderInspector();
    const foot=e("footer","iv-status");foot.append(e("span",null,"Consejo: arrastra para mover · esquina inferior para redimensionar · Supr para eliminar"),e("span",null,"Datos: "+DATA_PATH));this.root.append(foot);
    this.renderHeaderStatus();requestAnimationFrame(()=>this.sizeStage());
  }
  renderHeaderStatus(){
    if(this.saveBadge)this.saveBadge.textContent=this.readOnly?"Solo lectura":(this.dirty?"Cambios sin guardar":"Guardado");
  }
  renderLeft(left){
    const head=e("div","iv-panel-head");head.append(e("b",null,"Biblioteca"));left.append(head);
    const tabs=e("div","iv-row");["screens","assets"].forEach((id)=>{
      const b=this.button(id==="screens"?"Pantallas":"Gráficos",()=>{this.libraryMode=id;this.renderLibrary();},this.libraryMode===id?"primary":"");b.style.flex="1";tabs.append(b);
    });
    const body=e("div","iv-panel-body");body.append(tabs);
    const search=this.input(this.libraryMode==="assets"?this.assetQuery:this.screenQuery,v=>{
      if(this.libraryMode==="assets")this.assetQuery=v;else this.screenQuery=v;this.renderLibraryItems();
    });
    search.placeholder="Buscar…";search.setAttribute("aria-label","Buscar en biblioteca");body.append(search);
    this.libraryItems=e("div","iv-list");body.append(this.libraryItems);left.append(body);
    this.renderLibraryItems();
  }
  renderLibrary(){const left=this.root.querySelector(".iv-sidebar.left");if(left){left.replaceChildren();this.renderLeft(left);}}
  renderLibraryItems(){
    if(!this.libraryItems)return;this.libraryItems.replaceChildren();
    if(this.libraryMode==="screens"){
      const query=this.screenQuery.toLowerCase();
      this.project.screens.filter(s=>(s.name+" "+s.key).toLowerCase().includes(query)).forEach(s=>{
        const row=e("button","iv-item"+(s.id===this.screenId?" active":""));row.type="button";
        row.append(e("span",null,s.name),e("small",null,s.width+"×"+s.height));
        row.onclick=()=>{this.screenId=s.id;this.selectedId=null;this.render();};this.libraryItems.append(row);
      });
      this.libraryItems.append(this.button("＋ Crear pantalla",()=>this.addScreen()));
    }else{
      const query=this.assetQuery.toLowerCase();
      const matches=this.assets.filter(p=>p.toLowerCase().includes(query)).slice(0,150);
      matches.forEach(path=>{
        const b=e("button","iv-assetrow");b.type="button";b.title=path;
        b.append(e("span",null,path.replace(/^Graphics\/UI\//,"")));
        b.onclick=()=>this.addLayer("image",path);this.libraryItems.append(b);
      });
      if(!matches.length)this.libraryItems.append(e("div","iv-empty","No hay imágenes. Revisa Graphics/UI."));
      this.libraryItems.append(this.button("↻ Recargar gráficos",()=>this.loadAssets()));
    }
  }
  renderCenter(){
    const bar=e("div","iv-stagebar");this.center.append(bar);
    bar.append(e("span","iv-tag",this.screen().width+" × "+this.screen().height));
    bar.append(this.button("−",()=>this.setZoom(this.scale/1.25),"icon"));
    bar.append(this.button("Ajustar",()=>this.setZoom("fit")));
    bar.append(this.button("+",()=>this.setZoom(this.scale*1.25),"icon"));
    bar.append(e("span","iv-tag",Math.round(this.scale*100)+"%"));
    const grid=e("label","iv-check");const g=e("input");g.type="checkbox";g.checked=this.grid;g.onchange=()=>{this.grid=g.checked;this.renderStage();};grid.append(g,e("span",null,"Cuadrícula"));bar.append(grid);
    const snap=e("label","iv-check");const sn=e("input");sn.type="checkbox";sn.checked=this.snap;sn.onchange=()=>this.snap=sn.checked;snap.append(sn,e("span",null,"Imán 8px"));bar.append(snap);
    const viewport=e("div","iv-viewport");this.center.append(viewport);this.viewport=viewport;
    const frame=e("div","iv-stageframe");viewport.append(frame);this.frame=frame;
    const stage=e("div","iv-stage");frame.append(stage);this.stage=stage;
    stage.onclick=ev=>{if(ev.target===stage){this.selectedId=null;this.renderStage();this.renderInspector();}};
    const hint=e("div","iv-stagehint");hint.append(e("span",null,"Vista previa de diseño · no ejecuta lógica de combate ni animaciones"),e("span","", "Zoom y selección independientes del juego"));this.center.append(hint);
    this.renderStage();
  }
  setZoom(value){
    this.zoom=value==="fit"?"fit":Math.max(.25,Math.min(4,Number(value)||1));
    this.sizeStage();
  }
  sizeStage(){
    if(!this.stage||!this.viewport||this.disposed)return;
    const s=this.screen();
    let ratio=this.zoom;
    if(ratio==="fit")ratio=Math.min(2.5,Math.max(.25,Math.min((this.viewport.clientWidth-65)/s.width,(this.viewport.clientHeight-65)/s.height)));
    this.scale=Number(ratio)||1;
    this.frame.style.width=(s.width*this.scale)+"px";this.frame.style.height=(s.height*this.scale)+"px";
    this.stage.style.width=s.width+"px";this.stage.style.height=s.height+"px";this.stage.style.transform="scale("+this.scale+")";
    const tag=this.center.querySelector(".iv-stagebar .iv-tag:last-of-type");if(tag)tag.textContent=Math.round(this.scale*100)+"%";
  }
  renderStage(){
    if(!this.stage)return;
    this.stage.classList.toggle("grid",this.grid);this.stage.replaceChildren();
    this.screen().layers.forEach((layer,i)=>{
      if(!layer.visible)return;
      const node=e("div","iv-node"+(this.selectedId===layer.id?" selected":"")+(layer.locked?" locked":""));
      node.dataset.layer=layer.id;this.applyNodeBounds(node,layer);
      node.style.zIndex=String(i+1);node.style.opacity=String(layer.opacity/255);
      if(layer.type==="panel")node.style.background=validColor(layer.color,"#33445b");
      if(layer.type==="text"){
        const inner=e("div","iv-text",layer.text);inner.style.color=validColor(layer.color);
        inner.style.fontSize=(layer.fontSize|0)+"px";inner.style.justifyContent={left:"flex-start",center:"center",right:"flex-end"}[layer.align]||"flex-start";
        inner.style.textAlign=layer.align;node.append(inner);
      }
      if(layer.type==="image"){
        const missing=e("div","iv-missing",layer.path?"Cargando imagen…":"Selecciona un gráfico");
        node.append(missing);
        if(layer.path)this.loadImage(layer.path).then(url=>{
          if(this.disposed||!node.isConnected)return;
          if(!url){missing.textContent="Sin vista previa: "+layer.path.split("/").pop();return;}
          const img=e("img","iv-preview-image");img.alt=layer.name;img.src=url;img.onerror=()=>{img.replaceWith(e("div","iv-missing","No se pudo dibujar la imagen"));};
          node.replaceChildren(img);
          if(this.selectedId===layer.id&&!layer.locked){const handle=e("div","iv-handle");handle.dataset.resize="1";node.append(handle);}
        });
      }
      if(this.selectedId===layer.id&&!layer.locked && layer.type!=="image"){const h=e("div","iv-handle");h.dataset.resize="1";node.append(h);}
      node.addEventListener("pointerdown",ev=>this.startPointer(ev,node,layer));
      this.stage.append(node);
    });
  }
  applyNodeBounds(node,l){
    node.style.left=l.x+"px";node.style.top=l.y+"px";node.style.width=l.w+"px";node.style.height=l.h+"px";
  }
  async loadImage(path){
    if(!/^Graphics\//.test(path)||path.split("/").includes(".."))return null;
    if(this.blobUrls.has(path))return this.blobUrls.get(path);
    if(this.loadingImages.has(path))return this.loadingImages.get(path);
    const promise=(async()=>{
      try{
        const root=String(this.ctx.editor?.gameRoot?.()||"").replace(/\\/g,"/").replace(/\/$/,"");
        const invoke=window.__TAURI__?.core?.invoke || window.__TAURI__?.tauri?.invoke;
        if(!root||typeof invoke!=="function")return null;
        const raw=await invoke("read_binary_file",{path:root+"/"+path});
        const bytes=raw instanceof Uint8Array?raw:new Uint8Array(raw||[]);
        if(!bytes.length)return null;
        const mime=/\.jpe?g$/i.test(path)?"image/jpeg":/\.webp$/i.test(path)?"image/webp":"image/png";
        const url=URL.createObjectURL(new Blob([bytes],{type:mime}));
        if(this.disposed){URL.revokeObjectURL(url);return null;}
        this.blobUrls.set(path,url);return url;
      }catch(err){return null;}
      finally{this.loadingImages.delete(path);}
    })();
    this.loadingImages.set(path,promise);return promise;
  }
  startPointer(ev,node,layer){
    if(ev.button!==0)return;ev.stopPropagation();
    this.selectedId=layer.id;
    if(layer.locked){this.renderStage();this.renderInspector();return;}
    const resize=ev.target?.dataset?.resize==="1";
    const start={x:layer.x,y:layer.y,w:layer.w,h:layer.h};
    this.pushUndo();
    this.move={id:layer.id,x:ev.clientX,y:ev.clientY,start,resize,moved:false};
    node.setPointerCapture(ev.pointerId);
    const moving=event=>{
      if(!this.move||this.move.id!==layer.id)return;
      const dx=Math.round((event.clientX-this.move.x)/this.scale),dy=Math.round((event.clientY-this.move.y)/this.scale);
      const clamp=(n,min,max)=>Math.max(min,Math.min(max,n));
      const v=n=>this.snap?Math.round(n/8)*8:n;
      if(resize){layer.w=clamp(v(start.w+dx),8,8192);layer.h=clamp(v(start.h+dy),8,8192);}
      else {layer.x=clamp(v(start.x+dx),-10000,10000);layer.y=clamp(v(start.y+dy),-10000,10000);}
      this.move.moved=this.move.moved||dx!==0||dy!==0;
      this.applyNodeBounds(node,layer);
    };
    const end=()=>{
      node.removeEventListener("pointermove",moving);node.removeEventListener("pointerup",end);node.removeEventListener("pointercancel",end);
      if(this.move&&!this.move.moved){
        this.undoStack.pop();this.dirty=this.undoStack.length>0||this.dirty;
      }
      this.move=null;this.renderStage();this.renderInspector();this.renderHeaderStatus();
    };
    node.addEventListener("pointermove",moving);node.addEventListener("pointerup",end);node.addEventListener("pointercancel",end);
    this.renderInspector();
  }
  renderInspector(){
    if(!this.right)return;this.right.replaceChildren();
    const heading=e("div","iv-panel-head");heading.append(e("b",null,"Inspector"),e("span","iv-caption",this.layer()?"Elemento":"Pantalla"));this.right.append(heading);
    const body=e("div","iv-panel-body");this.right.append(body);
    const screen=this.screen();
    const scene=e("section","iv-section");
    scene.append(e("b",null,"Pantalla activa"));
    this.field(scene,"Nombre",this.input(screen.name,v=>this.edit(()=>{screen.name=v;})));
    const sizes=e("div","iv-fields2");
    this.field(sizes,"Ancho",this.input(screen.width,v=>this.edit(()=>{screen.width=Math.max(160,Math.min(4096,v||640));}),"number"));
    this.field(sizes,"Alto",this.input(screen.height,v=>this.edit(()=>{screen.height=Math.max(120,Math.min(4096,v||480));}),"number"));
    scene.append(sizes);
    this.field(scene,"ID de exportación",this.input(screen.key,v=>this.edit(()=>screen.key=slug(v))));
    const preset=this.select([["","Tamaño personalizado"],["640x480","640 × 480 · Vermeil"],["512x384","512 × 384 · Essentials"],["1280x720","1280 × 720 · panorámica"]],"",v=>{
      const m=/^(\d+)x(\d+)$/.exec(v);if(m)this.edit(()=>{screen.width=+m[1];screen.height=+m[2];});
    });this.field(scene,"Resolución",preset);
    const actions=e("div","iv-row");
    actions.append(this.button("Duplicar",()=>this.duplicateScreen()),this.button("Eliminar",()=>this.deleteScreen(),"danger"));scene.append(actions);
    body.append(scene);
    const layers=e("section","iv-section");layers.append(e("b",null,"Capas · orden de dibujo"));
    const layerTools=e("div","iv-row");
    layerTools.append(this.button("▣ Panel",()=>this.addLayer("panel")),this.button("T Texto",()=>this.addLayer("text")),this.button("▧ Imagen",()=>{this.libraryMode="assets";this.renderLibrary();this.toast("Elige un gráfico en la biblioteca.");}));
    layers.append(layerTools);
    const layerList=e("div","iv-list");
    [...screen.layers].reverse().forEach(l=>{
      const row=e("div","iv-row");row.style.gap="4px";
      const b=e("button","iv-item"+(this.selectedId===l.id?" active":""));b.type="button";b.style.minWidth="0";
      b.append(e("span",null,(l.type==="image"?"▧ ":l.type==="text"?"T ":"▣ ")+l.name));b.onclick=()=>{this.selectedId=l.id;this.renderStage();this.renderInspector();};row.append(b);
      row.append(this.button(l.visible?"◉":"○",()=>this.edit(()=>l.visible=!l.visible),"icon"));
      row.append(this.button(l.locked?"▣":"◇",()=>this.edit(()=>l.locked=!l.locked),"icon"));
      layerList.append(row);
    });layers.append(layerList);
    if(!screen.layers.length)layers.append(e("div","iv-empty","Añade un elemento para empezar."));
    body.append(layers);
    const layer=this.layer();if(!layer)return;
    const detail=e("section","iv-section");detail.append(e("b",null,"Propiedades de "+layer.type));
    const update=(key,val)=>this.edit(()=>{layer[key]=val;});
    this.field(detail,"Nombre de capa",this.input(layer.name,v=>update("name",v.slice(0,120))));
    const grid=e("div","iv-fields2");
    [["X","x"],["Y","y"],["Ancho","w"],["Alto","h"]].forEach(([title,key])=>this.field(grid,title,this.input(layer[key],v=>update(key,key==="w"||key==="h"?Math.max(1,v|0):v|0),"number")));
    detail.append(grid);
    this.field(detail,"Opacidad (0–255)",this.input(layer.opacity,v=>update("opacity",Math.max(0,Math.min(255,v|0))),"number"));
    if(layer.type==="panel"||layer.type==="text"){
      const color=this.input(validColor(layer.color),v=>update("color",validColor(v)),"color");this.field(detail,"Color",color);
    }
    if(layer.type==="text"){
      const txt=e("textarea","iv-input");txt.rows=4;txt.value=layer.text;txt.onchange=()=>update("text",txt.value);this.field(detail,"Contenido",txt);
      this.field(detail,"Tamaño de fuente",this.input(layer.fontSize,v=>update("fontSize",Math.max(6,Math.min(200,v|0))),"number"));
      this.field(detail,"Alineación",this.select([["left","Izquierda"],["center","Centro"],["right","Derecha"]],layer.align,v=>update("align",v)));
    }
    if(layer.type==="image"){
      const path=this.input(layer.path,v=>update("path",norm(v)));this.field(detail,"Ruta relativa a proyecto",path);
      detail.append(e("span","iv-caption","Usa Graphics/UI/… y selecciona imágenes en la biblioteca. Las medidas son independientes de la imagen original."));
    }
    const move=e("div","iv-row");
    move.append(this.button("↑ Subir",()=>this.reorderLayer(1)),this.button("↓ Bajar",()=>this.reorderLayer(-1)));
    detail.append(move);
    const ops=e("div","iv-row");ops.append(this.button("Duplicar",()=>this.duplicateLayer()),this.button("Eliminar",()=>this.deleteLayer(),"danger"));detail.append(ops);
    body.append(detail);
  }
  addScreen(){
    const name="Pantalla "+(this.project.screens.length+1);
    this.edit(()=>{const s=newScreen(name);this.project.screens.push(s);this.screenId=s.id;this.selectedId=null;});
  }
  duplicateScreen(){
    this.edit(()=>{const o=this.screen(),s=clone(o);s.id=uid("screen");s.name=o.name+" (copia)";s.key=slug(s.name);
      s.layers.forEach(l=>l.id=uid("layer"));this.project.screens.push(s);this.screenId=s.id;this.selectedId=null;});
  }
  deleteScreen(){
    if(this.project.screens.length<=1)return this.toast("Debe existir al menos una pantalla.");
    if(!window.confirm("¿Eliminar esta pantalla del proyecto? Puedes deshacerlo."))return;
    this.edit(()=>{this.project.screens=this.project.screens.filter(s=>s.id!==this.screenId);this.screenId=this.project.screens[0].id;this.selectedId=null;});
  }
  addLayer(type,path=""){
    this.edit(()=>{const s=this.screen(),l=newLayer(type,s.layers.length);if(path){l.path=path;l.name=path.split("/").pop().replace(/\.[^.]+$/,"");}
      s.layers.push(l);this.selectedId=l.id;});
  }
  duplicateLayer(){
    if(!this.layer())return;
    this.edit(()=>{const s=this.screen(),i=s.layers.findIndex(l=>l.id===this.selectedId);
      const l=clone(s.layers[i]);l.id=uid("layer");l.name+=" (copia)";l.x+=12;l.y+=12;s.layers.splice(i+1,0,l);this.selectedId=l.id;});
  }
  deleteLayer(){
    if(!this.layer())return;
    this.edit(()=>{this.screen().layers=this.screen().layers.filter(l=>l.id!==this.selectedId);this.selectedId=null;});
  }
  reorderLayer(delta){
    const s=this.screen(),idx=s.layers.findIndex(l=>l.id===this.selectedId),next=idx+delta;
    if(idx<0||next<0||next>=s.layers.length)return;
    this.edit(()=>{const [l]=s.layers.splice(idx,1);s.layers.splice(next,0,l);});
  }
  openCode(){
    const overlay=e("div","iv-modal"),card=e("div","iv-modal-card");overlay.append(card);
    card.append(e("h2",null,"Exportar Ruby · "+this.screen().name));
    card.append(e("p",null,"Genera sprites y coordenadas para Pokémon Essentials. Requiere integrar la llamada en tu escena; no sustituye automáticamente clases Ruby existentes."));
    const code=e("textarea");code.readOnly=true;code.value=makeRuby(this.screen());card.append(code);
    const row=e("div","iv-row");row.style.marginTop="12px";
    row.append(this.button("Copiar código",async()=>{try{await navigator.clipboard.writeText(code.value);this.toast("Código copiado.");}catch(_){code.select();document.execCommand("copy");this.toast("Seleccionado para copiar.");}}));
    row.append(this.button("Cerrar",()=>overlay.remove()));card.append(row);this.root.append(overlay);code.focus();code.select();
    overlay.addEventListener("click",ev=>{if(ev.target===overlay)overlay.remove();});
  }
  isFullscreen(){return document.fullscreenElement===this.root||this.root.classList.contains("iv-fullscreen");}
  async toggleFullscreen(){
    if(document.fullscreenElement===this.root){await document.exitFullscreen();this.render();return;}
    if(this.root.classList.contains("iv-fullscreen")){this.root.classList.remove("iv-fullscreen");this.render();return;}
    try{if(this.root.requestFullscreen)await this.root.requestFullscreen();else throw Error("No compatible");}
    catch(_){this.root.classList.add("iv-fullscreen");}
    this.render();
  }
  onKey(ev){
    if(this.disposed||!this.root.contains(document.activeElement))return;
    const tag=document.activeElement?.tagName;const editing=["INPUT","TEXTAREA","SELECT"].includes(tag);
    const ctrl=ev.ctrlKey||ev.metaKey,k=String(ev.key||"").toLowerCase();
    if(ctrl&&k==="s"){ev.preventDefault();this.save();return;}
    if(editing)return;
    if(ctrl&&k==="z"){ev.preventDefault();this.undo();return;}
    if(ctrl&&(k==="y"||(ev.shiftKey&&k==="z"))){ev.preventDefault();this.redo();return;}
    if(ctrl&&k==="d"){ev.preventDefault();this.duplicateLayer();return;}
    if(k==="delete"||k==="backspace"){if(this.layer()){ev.preventDefault();this.deleteLayer();}return;}
    if(k==="escape"){this.selectedId=null;this.renderStage();this.renderInspector();return;}
    const dirs={arrowleft:[-1,0],arrowright:[1,0],arrowup:[0,-1],arrowdown:[0,1]};
    if(dirs[k]&&this.layer()&&!this.layer().locked){
      ev.preventDefault();const [dx,dy]=dirs[k],step=ev.shiftKey?8:1;
      this.edit(()=>{this.layer().x+=dx*step;this.layer().y+=dy*step;});
    }
  }
  destroy(){
    this.disposed=true;this.resizeObserver?.disconnect();
    this.root.classList.remove("iv-fullscreen");
    if(document.fullscreenElement===this.root)document.exitFullscreen().catch(()=>{});
    this.blobUrls.forEach(url=>URL.revokeObjectURL(url));this.blobUrls.clear();this.root.remove();
  }
}
export function activate(ctx){
  ctx.log.info("Interface Studio 1.0.0 activated");
  ctx.ui.registerPanel({id:PANEL,title:"Interface Studio",icon:"layout",defaultPosition:"right",
    defaultSize:{width:1550,height:930},showInMenu:false,
    render(host){const studio=new InterfaceStudio(ctx,host);return()=>studio.destroy();}
  });
  ctx.menu.registerMenuItem({menu:"Mods",label:"Interface Studio",icon:"layout",handler:()=>ctx.ui.openPanel(PANEL)});
  try{ctx.commands.register("com.vermeil.interface-studio.open",()=>ctx.ui.openPanel(PANEL));}catch(_){}
}
