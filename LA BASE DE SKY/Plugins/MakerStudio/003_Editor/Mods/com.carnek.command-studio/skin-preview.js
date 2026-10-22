// Visual approximation of the RGSS/Essentials windowskin compositor.
// The 192px RGSS XP skin uses a 128x128 background and 64x64 frame at x=128.
// The 128px VX-compatible skin uses a 64x64 background and a frame at x=64.
// Source: Data/Scripts/018_Objects and windows/005_SpriteWindow.rb.
export function skinLayout(width,height){
 if(width===128 && height===128)return {format:"vx",back:[0,0,64,64],frameX:64,blinds:[0,64,64,64]};
 if(width===192 && height===128)return {format:"xp",back:[0,0,128,128],frameX:128,blinds:null};
 // Essentials SpriteWindow.skinformat=1 supports compact HGSS/DP custom windowskins.
 if((width===96||width===80)&&height===48)return {format:"custom",center:[32,16,16,16],margins:[32,16,width-48,16]};
 if(width===80&&height===80)return {format:"custom",center:[32,32,16,16],margins:[32,32,32,32]};
 if(width>=32&&height>=32){
  const x=Math.floor((width-16)/2),y=Math.floor((height-16)/2);
  return {format:"custom",center:[x,y,16,16],margins:[x,y,width-x-16,height-y-16]};
 }
 return null;
}
export function drawSkin(ctx,img,width,height,backgroundOpacity=1){
 const layout=skinLayout(img.width,img.height);
 if(!layout)throw Error("Windowskin no compatible con el formato XP/VX: "+img.width+"×"+img.height);
 const x=layout.frameX, W=Math.max(40,Math.floor(width)),H=Math.max(40,Math.floor(height));
 const piece=(sx,sy,sw,sh,dx,dy,dw,dh)=>{
  if(sw>0&&sh>0&&dw>0&&dh>0)ctx.drawImage(img,sx,sy,sw,sh,dx,dy,dw,dh);
 };
 ctx.clearRect(0,0,W,H);
 ctx.imageSmoothingEnabled=false;
 if(layout.format==="custom"){
  const [sx,sy,sw,sh]=layout.center;
  const [left,top,right,bottom]=layout.margins;
  const bw=Math.max(1,W-left-right),bh=Math.max(1,H-top-bottom);
  // SpriteWindow's nine segments for skinformat 1. 96×48 HGSS speech
  // frames use source center Rect(32,16,16,16) and asymmetric margins.
  piece(sx,sy,sw,sh,left,top,bw,bh);
  piece(0,0,left,top,0,0,left,top);
  piece(sx+sw,0,right,top,W-right,0,right,top);
  piece(0,sy+sh,left,bottom,0,H-bottom,left,bottom);
  piece(sx+sw,sy+sh,right,bottom,W-right,H-bottom,right,bottom);
  piece(sx,0,sw,top,left,0,bw,top);
  piece(sx,sy+sh,sw,bottom,left,H-bottom,bw,bottom);
  piece(0,sy,left,sh,0,top,left,bh);
  piece(sx+sw,sy,right,sh,W-right,top,right,bh);
  return "custom";
 }

 // SpriteWindow uses EXPAND_BACK (2px inset), background alpha can be overridden by host.
 ctx.save();ctx.globalAlpha=Math.max(0,Math.min(1,backgroundOpacity));
 piece(...layout.back,2,2,W-4,H-4);
 if(layout.blinds){ctx.globalAlpha*=0.3;piece(...layout.blinds,2,2,W-4,H-4);}
 ctx.restore();
 // Four corners: 16x16; stretch top/bottom by the engine's default STRETCH_SIDES.
 piece(x,0,16,16,0,0,16,16);
 piece(x+48,0,16,16,W-16,0,16,16);
 piece(x,48,16,16,0,H-16,16,16);
 piece(x+48,48,16,16,W-16,H-16,16,16);
 piece(x+16,0,32,16,16,0,W-32,16);
 piece(x+16,48,32,16,16,H-16,W-32,16);
 piece(x,16,16,32,0,16,16,H-32);
 piece(x+48,16,16,32,W-16,16,16,H-32);
 return layout.format;
}
export function createSkinPreview(ctx,root){
 let disposed=false,mode="editor",name="",request=0,url=null,image=null,frame=null;
 let choices=[];
 const container=document.createElement("div");container.className="csb-skin-selectors";
 const label=document.createElement("label");label.textContent="Aspecto de la ventana";
 const select=document.createElement("select");select.setAttribute("aria-label","Modo de vista previa");
 for(const [v,title] of [["editor","Editor"],["game","Como en el juego"]]){
  const opt=document.createElement("option");opt.value=v;opt.textContent=title;select.append(opt);
 }
 const skins=document.createElement("select");skins.hidden=true;skins.setAttribute("aria-label","Windowskin para el diálogo");
 const info=document.createElement("span");info.className="sub";info.textContent="Marco del editor";
 container.append(label,select,skins,info);root.prepend(container);
 const invoke=()=>typeof window!=="undefined"?window.__TAURI__?.core?.invoke:null;
 const projectRoot=()=>ctx.editor?.gameRoot?.()||null;
 const revoke=()=>{if(url){URL.revokeObjectURL(url);url=null;}};
 const reset=()=>{
  root.querySelectorAll(".csb-dialog-window").forEach(box=>{
   box.classList.remove("csb-windowskin-applied");
   box.querySelector(".csb-rendered-skin")?.remove();
   box.style.borderImage="";box.style.backgroundImage="";
  });
 };
 async function load(){
  const gameRoot=projectRoot();
  if(!gameRoot)return(info.textContent="No se ha seleccionado un proyecto.");
  try{
   const arr=await invoke()?.("list_graphic_files",{gameRoot,folder:"Windowskins"});
   if(Array.isArray(arr))choices=arr.map(x=>String(x).replace(/\.(png|bmp|jpe?g)$/i,""));
  }catch(_){}
  if(!choices.length)try{
   const found=await ctx.fs?.listProjectDir?.("Graphics/Windowskins");
   choices=(Array.isArray(found)?found:[]).map(x=>String(x.name||x).replace(/\.(png|bmp|jpe?g)$/i,""));
  }catch(_){}
  if(disposed)return;
  choices=[...new Set(choices)].filter(Boolean).sort((a,b)=>a.localeCompare(b,"es"));
  skins.replaceChildren();
  for(const skin of choices){const opt=document.createElement("option");opt.value=skin;opt.textContent=skin;skins.append(opt);}
  if(!choices.includes(name))name=choices.find(x=>/speech/i.test(x))||choices[0]||"";
  skins.value=name;
  info.textContent=choices.length?choices.length+" marcos disponibles":"No se encontraron Windowskins";
  if(mode==="game")await choose(name);
 }
 async function choose(chosen){
  name=chosen;const stamp=++request;
  if(mode!=="game"||!name||!invoke()||!projectRoot()){reset();return;}
  info.textContent="Cargando «"+name+"»…";
  try{
   const data=await invoke()("get_graphic_image",{gameRoot:projectRoot(),folder:"Windowskins",name});
   if(disposed||stamp!==request||!Array.isArray(data)||!data.length)return;
   revoke();url=URL.createObjectURL(new Blob([new Uint8Array(data)],{type:"image/png"}));
   const img=new Image();
   img.onload=()=>{
    if(disposed||stamp!==request)return;
    if(!skinLayout(img.width,img.height)){
      image=null;reset();info.textContent="Formato no compatible: "+img.width+" × "+img.height;return;
    }
    image=img;info.textContent="«"+name+"» · composición XP/VX";paint();
   };
   img.onerror=()=>{reset();info.textContent="No se pudo interpretar la imagen.";};
   img.src=url;
  }catch(e){reset();info.textContent="No se pudo cargar el marco: "+e.message;}
 }
 function paint(){
  if(disposed||mode!=="game"||!image){reset();return;}
  const target=root.querySelector(".csb-dialog-window");
  if(!target)return;
  target.classList.add("csb-windowskin-applied");
  const old=target.querySelector(".csb-rendered-skin");old?.remove();
  const canvas=document.createElement("canvas");canvas.className="csb-rendered-skin";
  // The game window uses pixel geometry; client geometry is sufficient for preview.
  const rect=target.getBoundingClientRect();
  const width=Math.max(120,Math.round(rect.width||400)),height=Math.max(70,Math.round(rect.height||90));
  canvas.width=width;canvas.height=height;
  const painting=canvas.getContext("2d");if(!painting)return;
  drawSkin(painting,image,width,height);
  // Vermeil chooses its default text color according to isDarkWindowskin().
  // Sample the actual composed backdrop; leave explicit <c=> colors untouched.
  let dark=true;
  try{
   const pixels=painting.getImageData(Math.floor(width/2),Math.floor(height/2),1,1).data;
   if(pixels[3]>20){
    const luminance=pixels[0]*0.299+pixels[1]*0.587+pixels[2]*0.114;
    dark=luminance<160;
   }
  }catch(_){}
  target.querySelectorAll('[data-csb-default="1"]').forEach(span=>{
   span.style.color=dark?"#F8F8F8":"#505058";
   span.style.textShadow=dark?"1px 1px 0 #485058":"1px 1px 0 #A0A0A8";
  });
  target.prepend(canvas);
 }
 select.onchange=()=>{mode=select.value;skins.hidden=mode!=="game";if(mode==="game")choose(name);else{request++;reset();info.textContent="Marco del editor";}};
 skins.onchange=()=>choose(skins.value);
 load();
 return {apply:paint,dispose(){
  disposed=true;request++;reset();revoke();container.remove();
 }};
}
