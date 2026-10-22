// Optional graphics preview through Tauri's documented read-only image APIs.
// Object URLs are owned by the editor and revoked on dispose.
export function createSkinPreview(ctx,root){
 let disposed=false,mode="editor",name="",url=null,request=0;
 const container=document.createElement("div");container.className="csb-skin-selectors";
 const label=document.createElement("label");label.textContent="Estilo de previsualización";
 const select=document.createElement("select");select.setAttribute("aria-label","Elegir estilo de cuadro");
 for(const [key,caption]of [["editor","Marco del editor"],["game","Windowskin del juego"]]){
  const opt=document.createElement("option");opt.value=key;opt.textContent=caption;select.append(opt);
 }
 const skins=document.createElement("select");skins.hidden=true;skins.setAttribute("aria-label","Seleccionar Windowskin del juego");
 const info=document.createElement("span");info.className="sub";info.textContent="Vista esquemática";
 container.append(label,select,skins,info);root.append(container);
 const api=()=>typeof window!=="undefined"?window.__TAURI__?.core?.invoke:null;
 const rootPath=()=>ctx.editor?.gameRoot?.();
 const refresh=async()=>{
  const invoke=api(),gameRoot=rootPath();
  if(!invoke||!gameRoot){info.textContent="Recursos gráficos no disponibles en este entorno.";return;}
  let choices=[];
  try{choices=await invoke("list_graphic_files",{gameRoot,folder:"Windowskins"});}
  catch(_){
   try{choices=(await ctx.fs.listProjectDir("Graphics/Windowskins")).map(x=>x.name).filter(x=>/\.(png|jpg|bmp)$/i.test(x));}catch(_){}
  }
  if(disposed)return;
  skins.replaceChildren();
  for(const item of choices){
   const file=String(item).replace(/\.(png|jpg|bmp)$/i,"");
   const o=document.createElement("option");o.value=file;o.textContent=file;skins.append(o);
  }
  if(name&&choices.some(x=>String(x).replace(/\.(png|jpg|bmp)$/i,"")===name))skins.value=name;
  else name=skins.value||"";
  info.textContent=choices.length?choices.length+" marcos encontrados":"No se encontraron Windowskins";
  if(mode==="game")await paint();
 };
 const paint=async()=>{
  if(disposed)return;
  const stage=root.querySelector(".csb-dialog-stage");
  const box=root.querySelector(".csb-dialog-window");
  if(!stage||!box)return;
  if(mode==="editor"){box.style.borderImage="";box.style.backgroundImage="";return;}
  if(!name){info.textContent="Sin marcos instalados; usando representación del editor.";return;}
  const invoke=api(),gameRoot=rootPath(),stamp=++request;
  if(!invoke||!gameRoot)return;
  try{
   const buffer=await invoke("get_graphic_image",{gameRoot,folder:"Windowskins",name});
   if(disposed||mode!=="game"||stamp!==request||!Array.isArray(buffer)||!buffer.length)return;
   const next=URL.createObjectURL(new Blob([new Uint8Array(buffer)],{type:"image/png"}));
   if(url)URL.revokeObjectURL(url);
   url=next;
   const current=root.querySelector(".csb-dialog-window");
   if(current){
     current.style.borderStyle="solid";
     current.style.borderWidth="12px";
     current.style.borderImage="url("+JSON.stringify(url)+") 16 fill / 12px / 0 stretch";
   }
   info.textContent="Windowskin: "+name+" (vista aproximada)";
  }catch(e){info.textContent="No se pudo cargar este Windowskin: "+e.message;}
 };
 select.onchange=()=>{mode=select.value;skins.hidden=mode!=="game";paint();};
 skins.onchange=()=>{name=skins.value;paint();};
 refresh();
 return{apply:paint,dispose:()=>{disposed=true;request++;if(url)URL.revokeObjectURL(url);url=null;container.remove();}};
}
