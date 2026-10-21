// Command Studio workspace fullscreen – matches BAS/BSS document overlay.
// Does not invoke Browser Fullscreen API; restores original panel node on exit.
export function installWorkspaceFullscreen(ctx,host,root,toggleButton) {
  if (!root || !host) return () => {};
  const cls="csb-fullscreen-active",lock="csb-fullscreen-lock";
  let expanded=false,placeholder=null,scrollX=0,scrollY=0;
  const update=()=>{
    if(toggleButton){
      toggleButton.textContent=expanded?"↙ Salir de pantalla completa":"⛶ Pantalla completa";
      toggleButton.setAttribute("aria-pressed",String(expanded));
      toggleButton.title=expanded?"Volver al panel (F11 o Esc)":"Ampliar área de trabajo (F11)";
    }
    const controls=root.querySelector(".csb-fullscreen-controls");
    if(controls)controls.hidden=!expanded;
  };
  function enter(){
    if(expanded||!document.body)return false;
    scrollX=Number(window.scrollX||0);scrollY=Number(window.scrollY||0);
    placeholder=document.createComment("Command Studio fullscreen placeholder");
    if(root.parentNode)root.parentNode.insertBefore(placeholder,root);
    document.body.appendChild(root);
    root.classList.add(cls);
    document.body.classList.add(lock);
    expanded=true;
    update();
    try{root.focus({preventScroll:true});}catch(_){}
    return true;
  }
  function exit(){
    if(!expanded)return false;
    root.classList.remove(cls);document.body.classList.remove(lock);
    if(placeholder?.parentNode)placeholder.parentNode.replaceChild(root,placeholder);
    else host.appendChild(root);
    placeholder=null;expanded=false;
    update();
    try{window.scrollTo(scrollX,scrollY);}catch(_){}
    return true;
  }
  const toggle=()=>expanded?exit():enter();
  const escape=e=>{
    if(!expanded)return;
    if(e.key==="Escape"||e.key==="F11"){
      e.preventDefault();e.stopPropagation();e.stopImmediatePropagation?.();
      if(e.key==="Escape")exit();else toggle();
    }
  };
  const onRootKey=e=>{
    if(!expanded&&e.key==="F11"){
      e.preventDefault();e.stopPropagation();e.stopImmediatePropagation?.();
      enter();
    }
  };
  const controls=document.createElement("div");
  controls.className="csb-fullscreen-controls";
  const exitButton=document.createElement("button");
  exitButton.type="button";exitButton.className="btn";
  exitButton.textContent="↙ Restaurar ventana";
  exitButton.onclick=exit;
  const closeButton=document.createElement("button");
  closeButton.type="button";closeButton.className="btn";
  closeButton.textContent="✕ Cerrar Command Studio";
  closeButton.onclick=()=>{
    exit();
    const ui=ctx?.ui;
    try{
      if(typeof ui?.closePanel==="function"){ui.closePanel("com.carnek.command-studio.panel");return;}
      if(typeof ui?.hidePanel==="function"){ui.hidePanel("com.carnek.command-studio.panel");return;}
    }catch(_){}
  };
  controls.append(exitButton,closeButton);
  controls.hidden=true;root.append(controls);
  const onToggle=()=>toggle();
  if(toggleButton)toggleButton.addEventListener("click",onToggle);
  document.addEventListener("keydown",escape,true);
  root.addEventListener("keydown",onRootKey);
  update();
  return()=>{
    if(toggleButton)toggleButton.removeEventListener("click",onToggle);
    document.removeEventListener("keydown",escape,true);
    root.removeEventListener("keydown",onRootKey);
    exit();
    root.querySelector(".csb-fullscreen-controls")?.remove();
  };
}
