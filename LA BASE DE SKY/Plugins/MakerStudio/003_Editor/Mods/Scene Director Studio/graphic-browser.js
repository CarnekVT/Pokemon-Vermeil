import {listGraphicsFolder,loadProjectBlobUrl,mimeFor,copyExternalFileToProject} from "./project.js";
const esc=s=>String(s??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
const name=p=>p.split("/").pop();
const parent=p=>p.split("/").slice(0,-1).join("/")||"Graphics";
export class GraphicBrowser{
  constructor(ctx,host,options={}){
    this.ctx=ctx;this.host=host;this.options=options;this.folder=options.folder||"Graphics";this.history=[];this.forward=[];this.expanded=new Set(["Graphics"]);this.cache=new Map();this.urls=[];this.generation=0;this.selection=null;this.page=0;this.closed=false;
    host.innerHTML='<div class="sd-gb"><div class="sd-gb-top"><div class="sd-gb-nav"><button data-back title="Atrás">‹</button><button data-forward title="Adelante">›</button><button data-up title="Carpeta superior">↑</button><button data-reload title="Actualizar">↻</button></div><div data-crumbs class="sd-gb-crumbs"></div><div class="sd-gb-search"><input class="sd-input" data-search placeholder="Buscar en carpeta"><button data-global title="Buscar en todo Graphics">Todo</button></div><button data-import class="sd-button">Importar imagen…</button><input data-file type="file" accept=".png,.jpg,.jpeg,.bmp,.gif,.webp" hidden></div><div class="sd-gb-body"><nav data-tree class="sd-gb-tree"></nav><section class="sd-gb-main"><div data-status class="sd-gb-status"></div><div data-grid class="sd-gb-grid"></div><div class="sd-gb-page"><button data-prev>‹</button><span data-page></span><button data-next>›</button></div></section></div><div class="sd-gb-selection"><div data-preview class="sd-gb-preview">Sin imagen</div><div class="sd-gb-info"><strong data-name>Selecciona una imagen</strong><small data-path></small><small data-size></small></div><button class="sd-button primary" data-use disabled></button></div></div>';
    this.$=s=>host.querySelector(s);this.$("[data-use]").textContent=options.label||"Añadir a escena";
    this.$("[data-back]").onclick=()=>{if(this.history.length){this.forward.push(this.folder);this.navigate(this.history.pop(),false)}};
    this.$("[data-forward]").onclick=()=>{if(this.forward.length){this.history.push(this.folder);this.navigate(this.forward.pop(),false)}};
    this.$("[data-up]").onclick=()=>this.navigate(parent(this.folder));
    this.$("[data-reload]").onclick=()=>{this.cache.clear();this.draw()};
    this.$("[data-search]").oninput=()=>{this.global=false;this.page=0;this.draw()};
    this.$("[data-global]").onclick=()=>{this.global=!this.global;this.page=0;this.draw()};
    this.$("[data-search]").onkeydown=e=>{if(e.key==="Enter"){e.preventDefault();this.global=true;this.page=0;this.draw()}};
    this.$("[data-prev]").onclick=()=>{this.page=Math.max(0,this.page-1);this.draw()};
    this.$("[data-next]").onclick=()=>{this.page++;this.draw()};
    this.$("[data-use]").onclick=()=>this.use();
    this.$("[data-import]").onclick=()=>this.$("[data-file]").click();
    this.$("[data-file]").onchange=async e=>{const f=e.target.files?.[0];if(!f)return;try{const p=await copyExternalFileToProject(ctx,f,(options.importDir||"Graphics/Scenes")+"/Imported");if(this.closed)return;this.cache.clear();options.onImport?.(p);await this.navigate(parent(p));this.select(p)}catch(err){if(!this.closed)this.$("[data-status]").textContent="No pude importar: "+(err.message||err)}finally{e.target.value=""}};
    this.navigate(this.folder,false);
  }
  async entries(folder){if(!this.cache.has(folder)){const p=listGraphicsFolder(this.ctx,folder);this.cache.set(folder,p);p.catch(()=>{if(this.cache.get(folder)===p)this.cache.delete(folder)})}return this.cache.get(folder)}
  async navigate(folder,record=true){if(folder!==this.folder&&record){this.history.push(this.folder);this.forward=[]}this.folder=folder;this.global=false;this.page=0;this.$("[data-search]").value="";let p=folder;while(p){this.expanded.add(p);if(p==="Graphics")break;p=parent(p)}this.options.onFolder?.(folder);await this.draw()}
  async searchAll(q,token){
    const files=[],queue=["Graphics"],seen=new Set();
    while(queue.length&&!this.closed&&token===this.generation){
      const dir=queue.shift();if(seen.has(dir))continue;seen.add(dir);
      try{const data=await this.entries(dir);if(token!==this.generation||this.closed)break;queue.push(...data.dirs);files.push(...data.files.filter(p=>p.toLowerCase().includes(q)));if(seen.size%10===0)this.$("[data-status]").textContent="Buscando… "+files.length+" imágenes encontradas"}catch{}
    }
    return {dirs:[],files:files.sort((a,b)=>a.localeCompare(b,undefined,{numeric:true}))};
  }
  async tree(token){
    const rows=[];
    const walk=async(path,depth)=>{if(this.closed||token!==this.generation)return;rows.push({path,depth,open:this.expanded.has(path)});if(!this.expanded.has(path))return;try{const d=await this.entries(path);for(const child of d.dirs)await walk(child,depth+1)}catch{}};
    await walk("Graphics",0);if(this.closed||token!==this.generation)return;
    const t=this.$("[data-tree]");t.innerHTML=rows.map((r,i)=>'<div class="sd-gb-tree-row '+(r.path===this.folder?"active":"")+'" style="padding-left:'+(r.depth*12)+'px"><button data-expand="'+i+'" title="Expandir o cerrar">'+(r.open?"▾":"▸")+'</button><button data-folder="'+i+'" title="'+esc(r.path)+'">📁 '+esc(name(r.path))+'</button></div>').join("");
    t.querySelectorAll("[data-expand]").forEach(b=>b.onclick=()=>{const p=rows[Number(b.dataset.expand)].path;if(this.expanded.has(p))this.expanded.delete(p);else this.expanded.add(p);this.tree(this.generation)});
    t.querySelectorAll("[data-folder]").forEach(b=>b.onclick=()=>this.navigate(rows[Number(b.dataset.folder)].path));
  }
  clearSelection(){this.selection=null;this.selectionToken=(this.selectionToken||0)+1;if(this.previewUrl)URL.revokeObjectURL(this.previewUrl);this.previewUrl=null;this.$("[data-preview]").textContent="Sin imagen";this.$("[data-name]").textContent="Selecciona una imagen";this.$("[data-path]").textContent="";this.$("[data-size]").textContent="";this.$("[data-use]").disabled=true}
  async select(path){
    if(this.closed)return;this.clearSelection();this.selection=path;const id=this.selectionToken;
    this.$("[data-name]").textContent=name(path);this.$("[data-path]").textContent=path;this.$("[data-preview]").textContent="Cargando…";
    this.host.querySelectorAll("[data-file-index]").forEach(b=>b.classList.toggle("active",b.dataset.path===path));
    const url=await loadProjectBlobUrl(this.ctx,path,mimeFor(path));if(this.closed||id!==this.selectionToken){if(url)URL.revokeObjectURL(url);return}if(!url){this.$("[data-preview]").textContent="No se pudo cargar";return}
    this.previewUrl=url;const img=document.createElement("img");img.alt=name(path);img.onload=()=>{if(this.closed||id!==this.selectionToken)return;this.$("[data-size]").textContent=img.naturalWidth+" × "+img.naturalHeight+" px";this.$("[data-use]").disabled=false};img.onerror=()=>{if(id===this.selectionToken)this.$("[data-preview]").textContent="Formato no compatible"};this.$("[data-preview]").replaceChildren(img);img.src=url;
  }
  use(){if(this.selection&&!this.$("[data-use]").disabled)this.options.onUse?.(this.selection)}
  async draw(){
    const token=++this.generation;this.urls.forEach(u=>URL.revokeObjectURL(u));this.urls=[];this.clearSelection();
    const grid=this.$("[data-grid]"),status=this.$("[data-status]"),q=this.$("[data-search]").value.trim().toLowerCase();
    this.$("[data-back]").disabled=!this.history.length;this.$("[data-forward]").disabled=!this.forward.length;this.$("[data-up]").disabled=this.folder==="Graphics";this.$("[data-global]").classList.toggle("active",!!this.global);
    const parts=this.folder.split("/");this.$("[data-crumbs]").innerHTML=parts.map((x,i)=>'<button data-crumb="'+i+'">'+esc(x)+'</button>').join('<span>›</span>');this.$("[data-crumbs]").querySelectorAll("[data-crumb]").forEach(b=>b.onclick=()=>this.navigate(parts.slice(0,Number(b.dataset.crumb)+1).join("/")));
    grid.innerHTML="";status.textContent="Cargando…";this.tree(token);
    try{
      const data=this.global&&q?await this.searchAll(q,token):await this.entries(this.folder);
      if(this.closed||token!==this.generation)return;
      const dirs=data.dirs.filter(p=>!q||name(p).toLowerCase().includes(q)),files=data.files.filter(p=>!q||(this.global?p:name(p)).toLowerCase().includes(q)),pages=Math.max(1,Math.ceil(files.length/36));
      this.page=Math.min(this.page,pages-1);const visible=files.slice(this.page*36,(this.page+1)*36);
      status.textContent=(this.global&&q?"Todo Graphics · ":"")+dirs.length+" carpetas · "+files.length+" imágenes";
      this.$("[data-page]").textContent=(this.page+1)+" / "+pages;this.$("[data-prev]").disabled=this.page===0;this.$("[data-next]").disabled=this.page===pages-1;
      grid.innerHTML=dirs.map((p,i)=>'<button class="sd-gb-tile folder" data-dir="'+i+'"><span class="sd-gb-thumb">📁</span><span>'+esc(name(p))+'</span></button>').join("")+visible.map((p,i)=>'<button class="sd-gb-tile" draggable="true" data-file-index="'+i+'" data-path="'+esc(p)+'" title="'+esc(p)+'"><span class="sd-gb-thumb">Imagen</span><span>'+esc(name(p))+'</span></button>').join("");
      if(!dirs.length&&!visible.length)grid.textContent="No hay imágenes o carpetas que coincidan.";
      grid.querySelectorAll("[data-dir]").forEach(b=>b.onclick=()=>this.navigate(dirs[Number(b.dataset.dir)]));
      const tiles=[...grid.querySelectorAll("[data-file-index]")];tiles.forEach((b,i)=>{const p=visible[i];b.onclick=()=>this.select(p);b.ondblclick=async()=>{if(this.selection!==p||this.$("[data-use]").disabled)await this.select(p);if(this.selection===p)this.options.onUse?.(p)};b.ondragstart=e=>{if(!this.options.onDrag){e.preventDefault();return}this.options.onDrag(p,e)};b.ondragend=()=>this.options.onDragEnd?.()});
      for(let i=0;i<visible.length&&token===this.generation&&!this.closed;i+=4)await Promise.all(visible.slice(i,i+4).map(async(p,j)=>{const u=await loadProjectBlobUrl(this.ctx,p,mimeFor(p));if(!u)return;if(this.closed||token!==this.generation){URL.revokeObjectURL(u);return}this.urls.push(u);const im=document.createElement("img");im.alt="";im.src=u;tiles[i+j]?.querySelector(".sd-gb-thumb")?.replaceChildren(im)}));
    }catch(e){if(!this.closed&&token===this.generation)status.textContent="No se pudo abrir "+this.folder+": "+(e.message||e)}
  }
  destroy(){this.closed=true;this.generation++;this.urls.forEach(u=>URL.revokeObjectURL(u));this.urls=[];if(this.previewUrl)URL.revokeObjectURL(this.previewUrl);this.previewUrl=null}
}
