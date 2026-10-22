// Fullscreen workspace compatible with the BAS/BSS design pattern.
// One visible button is enough; native panel close remains available.
export function installWorkspaceFullscreen(ctx,host,root,button){
 if(!root||!host)return()=>{};
 let active=false,placeholder=null,scrollX=0,scrollY=0;
 const flag="csb-fullscreen-active",lock="csb-fullscreen-lock";
 function label(){
  if(button){
   button.textContent=active?"↙ Restaurar ventana":"⛶ Pantalla completa";
   button.setAttribute("aria-pressed",String(active));
   button.title=active?"Salir de pantalla completa (Esc o F11)":"Abrir pantalla completa (F11)";
  }
 }
 function enter(){
  if(active||!document.body)return;
  placeholder=document.createComment("Command Studio original window position");
  if(root.parentNode)root.parentNode.insertBefore(placeholder,root);
  scrollX=Number(window.scrollX||0);scrollY=Number(window.scrollY||0);
  document.body.appendChild(root);
  root.classList.add(flag);document.body.classList.add(lock);active=true;label();
 }
 function exit(){
  if(!active)return;
  root.classList.remove(flag);document.body.classList.remove(lock);
  if(placeholder?.parentNode)placeholder.parentNode.replaceChild(root,placeholder);
  else host.appendChild(root);
  placeholder=null;active=false;label();
  try{window.scrollTo(scrollX,scrollY);}catch(_){}
 }
 const toggle=()=>active?exit():enter();
 const keydown=e=>{
  if(e.key!=="Escape"&&e.key!=="F11")return;
  if(e.key==="Escape"&&!active)return;
  if(e.key==="F11"&&!active&&!root.contains(document.activeElement))return;
  e.preventDefault();e.stopPropagation();
  e.stopImmediatePropagation?.();e.key==="Escape"?exit():toggle();
 };
 button?.addEventListener("click",toggle);
 document.addEventListener("keydown",keydown,true);
 label();
 return()=>{
  document.removeEventListener("keydown",keydown,true);
  button?.removeEventListener("click",toggle);
  exit();
 };
}
