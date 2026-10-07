import { CSS } from './styles.js';
import {
  CHANGE_FIELDS, STAT_KEYS, parsePbsSections, mergeSpeciesFiles, normalizeDoc,
  effectiveEntry, resolvePbsEntry, fieldProvenance, setOverride, changedFields,
  parseMoves, movesToCsv, parseList, listToCsv, parseEvos, evosToCsv,
  displayName, normalizeSearch, splitHeader, setEntityOverride, changedEntityFields, sameField
} from './model.js';

const PANEL_ID='changedex-studio.main';
const JSON_PATH='Data/ChangeDex/pokemon_changes.json';
const RECOVERY_PATH='Data/ChangeDex/pokemon_changes.recovery.json';
const BUILTIN_MIGRATION='migration/Vermeil First Branch - legacy pokemon changes.json';
const FIRST_BRANCH_MIGRATION='migration/First Branch vs PBS Base.json';
const CONFIG_PATH='Data/ChangeDex/config.json';

const STUDIO_ICON=`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M4 4.5A2.5 2.5 0 0 1 6.5 2H20v17H6.5A2.5 2.5 0 0 0 4 21.5z"/><path d="M4 4.5v17"/><circle cx="12" cy="10" r="3.2"/><path d="M8.8 10h6.4M12 6.8v6.4"/></svg>`;

const TYPE_COLORS={
  NORMAL:'#a8a878',FIRE:'#f08030',WATER:'#6890f0',GRASS:'#78c850',ELECTRIC:'#f8d030',ICE:'#98d8d8',
  FIGHTING:'#c03028',POISON:'#a040a0',GROUND:'#e0c068',FLYING:'#a890f0',PSYCHIC:'#f85888',BUG:'#a8b820',
  ROCK:'#b8a038',GHOST:'#705898',DRAGON:'#7038f8',DARK:'#705848',STEEL:'#b8b8d0',FAIRY:'#ee99ac'
};

// Shared for the lifetime of Maker Studio. Reopening the panel no longer
// rereads the entire PBS tree; use “↻ Recargar PBS” when the files changed.
const PBS_SESSION_CACHE={
  projectKey:null,
  names:null,
  text:new Map(),
  sections:new Map()
};


function el(tag, props={}, children=[]) {
  const n=document.createElement(tag);
  for (const [key,val] of Object.entries(props||{})) {
    const k=String(key||'');
    if (k==='class') n.className=String(val??'');
    else if (k==='text') n.textContent=String(val??'');
    else if (k==='html') n.innerHTML=String(val??'');
    else if (k==='dataset' && val && typeof val==='object') Object.assign(n.dataset,val);
    else if (k==='style' && val && typeof val==='object') { for (const [sk,sv] of Object.entries(val)) { if (String(sk).startsWith('--')) n.style.setProperty(String(sk),String(sv)); else n.style[sk]=sv; } }
    else if (k.startsWith('on') && typeof val==='function') n.addEventListener(k.slice(2).toLowerCase(),val);
    else if (val!==undefined && val!==null && val!==false) n.setAttribute(k,val===true?'':String(val));
  }
  for (const c of (Array.isArray(children)?children:[children])) {
    if (c===undefined || c===null || c===false) continue;
    n.append(c?.nodeType?c:document.createTextNode(String(c)));
  }
  return n;
}

function safeUpper(v){ return String(v??'').trim().toUpperCase(); }
function safeLower(v){ return String(v??'').toLowerCase(); }
function normalizePickerPath(value) {
  if (value==null) return '';
  if (Array.isArray(value)) return value.length?normalizePickerPath(value[0]):'';
  if (typeof value==='string') return value;
  if (typeof value==='object') {
    for (const k of ['path','filePath','filepath','selectedPath','selected','value','location']) {
      const v=value[k];
      if (typeof v==='string' && v) return v;
      if (v && typeof v==='object') { const nested=normalizePickerPath(v); if (nested) return nested; }
    }
  }
  return '';
}

export function activate(ctx) {
  ctx.log.info('ChangeDex Studio v0.11.28 activated');
  ctx.ui.registerPanel({
    id:PANEL_ID,
    title:'ChangeDex Studio',
    icon:STUDIO_ICON,
    defaultPosition:'right',
    defaultSize:{width:1320,height:860},
    showInMenu:false,
    render:(host)=>renderStudio(ctx,host)
  });
  ctx.menu.registerMenuItem({
    menu:'Mods',label:'ChangeDex Studio',icon:STUDIO_ICON,shortcut:'Ctrl+Shift+D',
    handler:()=>ctx.ui.openPanel(PANEL_ID)
  });
  ctx.commands.register('changedex-studio.open',()=>ctx.ui.openPanel(PANEL_ID));
}

function renderStudio(ctx, host) {
  const state={
    entries:[],byHeader:new Map(),basesBySpecies:new Map(),doc:normalizeDoc({}),selected:null,
    search:'',listMode:'all',onlyChanged:false,tab:'stats',dirty:false,gameRoot:'',moves:[],abilities:[],items:[],types:[],projectMoveIds:new Set(),projectAbilityIds:new Set(),
    assetUrls:new Map(),assetFailures:new Set(),listRenderToken:0,selectionToken:0,
    iconObserver:null,moveTab:'level',moveFilter:'',fullscreen:false,loadingPhase:'',ensureSelectionVisible:false,
    manageMode:false,selectedMany:new Set(),lastMultiHeader:null,generation:'all',typeFilter:'all',sortMode:'dex',viewMode:'medium',
    undoStack:[],redoStack:[],baselineMoves:new Map(),baselineAbilities:new Map(),config:{screenMode:'auto',width:640,height:480,iconSize:84,gameName:'',uiMode:'code',languageMode:'auto',gameLocalizationEnabled:true,gameLanguageMode:'auto',languagePickerInDebug:true,hiddenForms:[],hiddenMoves:[],hiddenAbilities:[],sectionDescriptions:{es:{pokemon_changes:'Stats · tipos · habilidades · movimientos · evoluciones',move_changes:'Datos del movimiento · efectos · usuarios añadidos/retirados',ability_changes:'Datos de la habilidad · reworks · usuarios añadidos/retirados',new_moves:'Movimientos que no existen en el balance original',new_abilities:'Habilidades que no existen en el balance original'},en:{pokemon_changes:'Stats · types · abilities · learnsets · evolutions',move_changes:'Move data · effects · added/removed users',ability_changes:'Ability data · reworks · added/removed users',new_moves:'Moves that do not exist in the original balance',new_abilities:'Abilities that do not exist in the original balance'}},colorBackground:'#141923',colorGridFill:'#1e2634',colorGridEdge:'#38465c',colorPanelFill:'#1c2432',colorPanelEdge:'#3e4e68',colorHighlight:'#dc3c3c',colorText:'#f5f5f5',colorMuted:'#b4b4b4',colorOriginal:'#50b4ff',colorResult:'#ff6464',colorDifference:'#ffd700',colorNew:'#64ff78',suppressPbsChangesLogs:true,debugLogging:false,specialKeyLabel:''}
  };

  host.innerHTML='';
  const style=el('style',{text:CSS});
  const root=el('div',{class:'cdx-root'});
  host.append(style,root);

  const toolbar=el('div',{class:'cdx-toolbar'});
  const brand=el('div',{class:'cdx-brand'});
  brand.append(el('div',{class:'cdx-brand-icon',html:STUDIO_ICON}),el('div',{class:'cdx-brand-copy'},[
    el('div',{class:'cdx-title',text:'ChangeDex Studio'}),
    el('div',{class:'cdx-sub',text:'PBS original  →  JSON overrides  →  ChangeDex'})
  ]));
  const reloadPbsBtn=el('button',{class:'cdx-btn cdx-btn-soft',text:'↻ Recargar PBS',title:'Fuerza una nueva lectura del PBS. Normalmente ChangeDex reutiliza la caché de esta sesión.'});
  const importBtn=el('button',{class:'cdx-btn cdx-btn-soft',text:'⇧ Importar edición'});
  const entitiesBtn=el('button',{class:'cdx-btn cdx-btn-soft',text:'✦ Moves / Abilities'});
    const configBtn=el('button',{class:'cdx-btn cdx-btn-soft',text:'⚙ ChangeDex'});
  const cleanBtn=el('button',{class:'cdx-btn cdx-btn-soft',text:'Eliminar cambios innecesarios'});
  const fullBtn=el('button',{class:'cdx-btn cdx-btn-soft cdx-fullscreen-btn',text:'⛶ Ampliar',title:'Pantalla completa · F11'});
  const closeFullBtn=el('button',{class:'cdx-btn cdx-btn-soft cdx-close-fullscreen',text:'✕ Cerrar editor',title:'Cerrar ChangeDex Studio'});
  const undoBtn=el('button',{class:'cdx-btn cdx-btn-soft',text:'↶',title:'Deshacer · Ctrl+Z'});
  const redoBtn=el('button',{class:'cdx-btn cdx-btn-soft',text:'↷',title:'Rehacer · Ctrl+Y'});
  const saveBtn=el('button',{class:'cdx-btn primary',text:'Guardar cambios'});
  const toolbarActions=el('div',{class:'cdx-toolbar-actions'});toolbarActions.append(undoBtn,redoBtn,entitiesBtn,importBtn,configBtn,reloadPbsBtn,cleanBtn,fullBtn,closeFullBtn,saveBtn);toolbar.append(brand,toolbarActions);
  root.append(toolbar);

  const main=el('div',{class:'cdx-main'});
  const library=el('div',{class:'cdx-library'});
  const leftResizer=el('div',{class:'cdx-resizer cdx-resizer-left',title:'Arrastra para cambiar el ancho de la biblioteca'});
  const center=el('div',{class:'cdx-center'});
  const rightResizer=el('div',{class:'cdx-resizer cdx-resizer-right',title:'Arrastra para cambiar el ancho del inspector'});
  const inspector=el('div',{class:'cdx-inspector'});
  main.append(library,leftResizer,center,rightResizer,inspector);
  root.append(main);
  const status=el('div',{class:'cdx-status',text:'Preparando ChangeDex…'});
  root.append(status);

  const libHead=el('div',{class:'cdx-lib-head'});
  const libTitle=el('div',{class:'cdx-lib-title'});
  const libCount=el('span',{class:'cdx-count',text:'0'});
  libTitle.append(el('b',{text:'Pokédex / Lista'}),libCount);
  const search=el('input',{class:'cdx-search',placeholder:'Buscar Pokémon, ID o forma…'});
  libHead.append(libTitle,search);
  const filterBar=el('div',{class:'cdx-filterbar'});
  const allChip=el('button',{class:'cdx-chip active',text:'Todos'});
  const changedChip=el('button',{class:'cdx-chip',text:'Sólo cambiados'});
  const baseChip=el('button',{class:'cdx-chip',text:'Base'});
  const formsChip=el('button',{class:'cdx-chip',text:'Formas'});
  const unchangedChip=el('button',{class:'cdx-chip',text:'Sin cambios'});
  const manageBtn=el('button',{class:'cdx-chip cdx-manage-toggle',text:'☑ Gestionar'});
  filterBar.append(allChip,changedChip,unchangedChip,baseChip,formsChip,manageBtn);
  const advancedFilters=el('div',{class:'cdx-list-tools'});
  const genSelect=el('select',{class:'cdx-mini-select',title:'Filtrar por generación'});
  [['all','Todas las generaciones'],['1','Gen 1'],['2','Gen 2'],['3','Gen 3'],['4','Gen 4'],['5','Gen 5'],['6','Gen 6'],['7','Gen 7'],['8','Gen 8'],['9','Gen 9']].forEach(([v,l])=>genSelect.append(el('option',{value:v,text:l})));
  const typeSelect=el('select',{class:'cdx-mini-select',title:'Filtrar por tipo'}); typeSelect.append(el('option',{value:'all',text:'Todos los tipos'}));
  const sortSelect=el('select',{class:'cdx-mini-select',title:'Orden'}); [['dex','Orden Pokédex'],['name','Nombre A-Z'],['changes','Más cambios']].forEach(([v,l])=>sortSelect.append(el('option',{value:v,text:l})));
  const viewSelect=el('select',{class:'cdx-mini-select',title:'Densidad de lista'}); [['compact','Compacta'],['medium','Media'],['detail','Detallada']].forEach(([v,l])=>viewSelect.append(el('option',{value:v,text:l}))); viewSelect.value='medium';
  advancedFilters.append(genSelect,typeSelect,sortSelect,viewSelect);
  const batchBar=el('div',{class:'cdx-batchbar hidden'});
  const batchCount=el('b',{text:'0 seleccionados'});
  const selectVisibleBtn=el('button',{class:'cdx-btn small',text:'Seleccionar visibles'});
  const selectChangedBtn=el('button',{class:'cdx-btn small',text:'Todos modificados'});
  const clearSelectionBtn=el('button',{class:'cdx-btn small',text:'Limpiar'});
  const hideManyBtn=el('button',{class:'cdx-btn small',text:'🙈 Ocultar formas',title:'Oculta en ChangeDex las formas seleccionadas sin tocar sus cambios ingame.'});
  const showManyBtn=el('button',{class:'cdx-btn small',text:'👁 Mostrar formas',title:'Vuelve a evidenciar en ChangeDex las formas seleccionadas.'});
  const revertManyBtn=el('button',{class:'cdx-btn small danger',text:'Restaurar seleccionados'});
  batchBar.append(batchCount,selectVisibleBtn,selectChangedBtn,clearSelectionBtn,hideManyBtn,showManyBtn,revertManyBtn);
  const list=el('div',{class:'cdx-list',tabindex:'0'});
  const libFoot=el('div',{class:'cdx-lib-foot',html:'<span>↑↓ navegar</span><span>Ctrl+F buscar</span>'});
  library.append(libHead,filterBar,advancedFilters,batchBar,list,libFoot);
  // Maker Studio can have a parent scroll handler; keep wheel navigation in
  // the library when the cursor is over the Pokémon list.
  list.addEventListener('wheel',(ev)=>ev.stopPropagation(),{passive:true});

  const centerHead=el('div',{class:'cdx-center-head'});
  const comparison=el('div',{class:'cdx-comparison'});
  center.append(comparison);

  const tabs=el('div',{class:'cdx-tabs'});
  const inspectBody=el('div',{class:'cdx-inspect-body'});
  // Identity + editing live together in the main workspace. The right side is
  // now contextual support (summary/differences), not the place where the
  // selected Pokémon identity is stranded.
  inspector.append(centerHead,tabs,inspectBody);
  comparison.addEventListener('wheel',(ev)=>ev.stopPropagation(),{passive:true});
  inspectBody.addEventListener('wheel',(ev)=>ev.stopPropagation(),{passive:true});
  const tabDefs=[
    ['stats','Stats'],['identity','Tipos'],['abilities','Habilidades'],['moves','Movimientos'],['evolution','Evolución'],['advanced','Otros']
  ];
  for (const [id,label] of tabDefs) {
    const b=el('button',{class:'cdx-tab'+(state.tab===id?' active':''),text:label,onClick:()=>{
      state.tab=id; renderTabs(); renderInspector();
    }});
    b.dataset.tab=id;
    tabs.append(b);
  }

  function toast(message,level='info') {
    try { ctx.ui.showToast({message:String(message??''),level}); }
    catch { try { ctx.log.info(String(message??'')); } catch {} }
  }

  // Maker Studio blocks browser confirm/prompt through its ACL in some hosts.
  // Keep confirmations/text requests entirely inside the mod DOM instead of
  // dispatching plugin:dialog|confirm / plugin:dialog|prompt commands.
  function inStudioQuestion({title='Confirmar',message='',confirmText='Aceptar',cancelText='Cancelar',input=false,defaultValue='',placeholder='' }={}) {
    return new Promise(resolve=>{
      let settled=false;
      const layer=el('div',{class:'cdx-acl-modal-layer'});
      const card=el('div',{class:'cdx-acl-modal'});
      const head=el('div',{class:'cdx-acl-modal-head'});
      head.append(el('b',{text:title}));
      const close=el('button',{class:'cdx-acl-modal-x',type:'button',text:'×',title:cancelText});
      head.append(close);
      const body=el('div',{class:'cdx-acl-modal-body'});
      if(message)body.append(el('p',{text:message}));
      let textInput=null;
      if(input){
        textInput=el('input',{class:'cdx-input cdx-acl-modal-input',type:'text',value:String(defaultValue??''),placeholder:String(placeholder||'')});
        textInput.value=String(defaultValue??'');
        body.append(textInput);
      }
      const actions=el('div',{class:'cdx-acl-modal-actions'});
      const cancel=el('button',{class:'cdx-btn cdx-btn-soft',type:'button',text:cancelText});
      const accept=el('button',{class:'cdx-btn primary',type:'button',text:confirmText});
      actions.append(cancel,accept);
      card.append(head,body,actions);layer.append(card);root.append(layer);
      const finish=(value)=>{
        if(settled)return;
        settled=true;
        try{layer.remove();}catch{}
        resolve(value);
      };
      close.onclick=()=>finish(input?null:false);
      cancel.onclick=()=>finish(input?null:false);
      layer.addEventListener('mousedown',(ev)=>{if(ev.target===layer)finish(input?null:false);});
      accept.onclick=()=>finish(input?String(textInput?.value??''):true);
      card.addEventListener('keydown',(ev)=>{
        if(ev.key==='Escape'){ev.preventDefault();finish(input?null:false);}
        else if(ev.key==='Enter'&&(!input||ev.target===textInput)){ev.preventDefault();accept.click();}
      });
      requestAnimationFrame(()=>{try{(textInput||accept).focus({preventScroll:true});if(textInput)textInput.select();}catch{}});
    });
  }
  function askConfirm(message,title='Confirmar',confirmText='Continuar'){
    return inStudioQuestion({title,message,confirmText,cancelText:'Cancelar'});
  }
  function askText(message,{title='Nuevo elemento',defaultValue='',placeholder='',confirmText='Crear'}={}){
    return inStudioQuestion({title,message,confirmText,cancelText:'Cancelar',input:true,defaultValue,placeholder});
  }

  function renderTabs(){
    tabs.querySelectorAll('.cdx-tab').forEach(b=>b.classList.toggle('active',b.dataset.tab===state.tab));
  }

  // Fullscreen follows BAS' proven workspace behavior: detach only the editor
  // root to document.body, preserve its home with a placeholder and restore it
  // exactly when leaving fullscreen. This makes the whole ChangeDex workspace
  // actually grow instead of only changing CSS inside a fixed Maker Studio pane.
  let fullscreenPlaceholder=null;
  let fullscreenPreviousScroll={x:0,y:0};
  let fullscreenTarget=null;
  let fullscreenStyleMirror=null;
  function updateFullscreenUi(){
    fullBtn.textContent=state.fullscreen?'↙ Vista normal':'⛶ Pantalla completa';
    fullBtn.classList.toggle('active',!!state.fullscreen);
    fullBtn.setAttribute('aria-pressed',state.fullscreen?'true':'false');
    fullBtn.title=state.fullscreen?'Salir de pantalla completa · F11 / Esc':'Pantalla completa · F11';
    closeFullBtn.classList.toggle('visible',!!state.fullscreen);
  }
  function refreshAfterFullscreenChange(){
    requestAnimationFrame(()=>{
      applyAdaptiveLayout();
      renderList();
      renderSelection();
      requestAnimationFrame(()=>applyAdaptiveLayout());
    });
  }
  function enterFullscreenMode(){
    if(state.fullscreen||!root||!document.body)return false;
    fullscreenPreviousScroll={x:Number(window.scrollX||0),y:Number(window.scrollY||0)};
    fullscreenPlaceholder=document.createComment('ChangeDex Studio fullscreen home');
    if(root.parentNode)root.parentNode.insertBefore(fullscreenPlaceholder,root);
    // Maker Studio may render panels inside a ShadowRoot. Moving a styled node
    // out of that root makes its panel-local CSS disappear, which was why
    // "Ampliar" sometimes looked like it did nothing. Stay in the same shadow
    // tree when possible; otherwise mirror the stylesheet globally like BAS.
    let ownerRoot=null;try{ownerRoot=host?.getRootNode?.()||null;}catch{}
    const isShadow=(typeof ShadowRoot!=='undefined'&&ownerRoot instanceof ShadowRoot);
    fullscreenTarget=isShadow?ownerRoot:document.body;
    if(!isShadow){
      fullscreenStyleMirror=document.createElement('style');
      fullscreenStyleMirror.dataset.changedexFullscreen='1';
      fullscreenStyleMirror.textContent=CSS;
      document.head.appendChild(fullscreenStyleMirror);
    }
    fullscreenTarget.appendChild(root);
    state.fullscreen=true;
    root.classList.add('cdx-fullscreen-active');
    document.body.classList.add('cdx-fullscreen-lock');
    updateFullscreenUi();
    refreshAfterFullscreenChange();
    try{root.focus({preventScroll:true});}catch{}
    return true;
  }
  function exitFullscreenMode(options={}){
    if(!state.fullscreen)return false;
    root.classList.remove('cdx-fullscreen-active');
    document.body.classList.remove('cdx-fullscreen-lock');
    try{fullscreenStyleMirror?.remove?.();}catch{}
    fullscreenStyleMirror=null;fullscreenTarget=null;
    if(fullscreenPlaceholder&&fullscreenPlaceholder.parentNode)fullscreenPlaceholder.parentNode.replaceChild(root,fullscreenPlaceholder);
    else if(host)host.appendChild(root);
    fullscreenPlaceholder=null;
    state.fullscreen=false;
    updateFullscreenUi();
    if(!options.skipRefresh)refreshAfterFullscreenChange();
    try{window.scrollTo(fullscreenPreviousScroll.x||0,fullscreenPreviousScroll.y||0);}catch{}
    return true;
  }
  function setFullscreen(active){return active?enterFullscreenMode():exitFullscreenMode();}
  async function closeEditorFromFullscreen(){
    if(!state.fullscreen)return false;
    if(state.dirty){
      const ok=await askConfirm('Hay cambios sin guardar. ¿Cerrar ChangeDex Studio sin guardarlos?','Cerrar editor','Cerrar sin guardar');
      if(!ok)return false;
    }
    exitFullscreenMode({skipRefresh:true});
    try{
      if(ctx?.ui&&typeof ctx.ui.closePanel==='function'){await ctx.ui.closePanel(PANEL_ID);return true;}
      if(ctx?.ui&&typeof ctx.ui.hidePanel==='function'){await ctx.ui.hidePanel(PANEL_ID);return true;}
    }catch{}
    try{
      const panel=host.closest?.('[data-panel-id],[data-panel],.maker-panel,.panel,.dockview-panel,.dv-panel');
      const btn=panel?.querySelector?.('[data-action="close-panel"],[data-panel-action="close"],.panel-close,.dockview-close-button,.dv-close-button,button[aria-label="Close panel"],button[title="Close panel"],button[aria-label="Cerrar panel"],button[title="Cerrar panel"]');
      if(btn&&!root.contains(btn)){btn.click();return true;}
    }catch{}
    return false;
  }

  function initResizer(handle,side){
    let startX=0,start=0;
    const onMove=(e)=>{
      const total=Math.max(900,main.clientWidth||900);
      if(side==='left'){
        const next=Math.max(220,Math.min(Math.round(total*.38),start+(e.clientX-startX)));
        root.style.setProperty('--left',next+'px');
      }else{
        const next=Math.max(330,Math.min(Math.round(total*.52),start+(startX-e.clientX)));
        root.style.setProperty('--right',next+'px');
      }
    };
    const onUp=()=>{
      handle.classList.remove('dragging');
      document.removeEventListener('mousemove',onMove);
      document.removeEventListener('mouseup',onUp);
    };
    handle.addEventListener('mousedown',(e)=>{
      e.preventDefault();
      startX=e.clientX;
      const raw=getComputedStyle(root).getPropertyValue(side==='left'?'--left':'--right');
      start=parseFloat(raw)||(side==='left'?310:430);
      handle.classList.add('dragging');
      document.addEventListener('mousemove',onMove);
      document.addEventListener('mouseup',onUp);
    });
  }
  initResizer(leftResizer,'left');
  initResizer(rightResizer,'right');
  updateFullscreenUi();

  function setListMode(mode){
    state.listMode=mode;
    state.onlyChanged=mode==='changed';
    [[allChip,'all'],[changedChip,'changed'],[unchangedChip,'unchanged'],[baseChip,'base'],[formsChip,'forms']].forEach(([b,m])=>b.classList.toggle('active',m===mode));
    renderList();updateStatus();
  }

  function selectRelative(dir){
    const rows=filtered();
    if(!rows.length)return;
    let idx=rows.findIndex(e=>String(e._header)===String(state.selected));
    if(idx<0)idx=0;
    idx=Math.max(0,Math.min(rows.length-1,idx+dir));
    const next=String(rows[idx]?._header||'');
    if(!next||next===state.selected)return;
    state.selected=next;state.ensureSelectionVisible=true;renderList();renderSelection();
  }

  function keyboard(ev){
    const t=ev.target;
    const typing=t&&(t.tagName==='INPUT'||t.tagName==='TEXTAREA'||t.tagName==='SELECT'||t.isContentEditable);
    if(ev.key==='F11'){ev.preventDefault();setFullscreen(!state.fullscreen);return;}
    if(ev.key==='Escape'&&state.fullscreen){ev.preventDefault();setFullscreen(false);return;}
    if((ev.ctrlKey||ev.metaKey)&&safeLower(ev.key)==='s'){ev.preventDefault();save();return;}
    if((ev.ctrlKey||ev.metaKey)&&safeLower(ev.key)==='z'&&!ev.shiftKey){ev.preventDefault();undo();return;}
    if((ev.ctrlKey||ev.metaKey)&&(safeLower(ev.key)==='y'||(safeLower(ev.key)==='z'&&ev.shiftKey))){ev.preventDefault();redo();return;}
    if((ev.ctrlKey||ev.metaKey)&&safeLower(ev.key)==='f'){ev.preventDefault();search.focus();search.select();return;}
    if(typing)return;
    if(ev.key==='ArrowDown'){ev.preventDefault();selectRelative(1);}
    else if(ev.key==='ArrowUp'){ev.preventDefault();selectRelative(-1);}
    else if(ev.key==='PageDown'){ev.preventDefault();selectRelative(10);}
    else if(ev.key==='PageUp'){ev.preventDefault();selectRelative(-10);}
    else if(ev.key==='Home'){ev.preventDefault();selectRelative(-999999);}
    else if(ev.key==='End'){ev.preventDefault();selectRelative(999999);}
  }
  root.tabIndex=0;
  root.addEventListener('keydown',keyboard,true);

  function snapshotDoc(){ return JSON.stringify(state.doc); }
  function pushUndo(){
    const snap=snapshotDoc();
    if(state.undoStack[state.undoStack.length-1]!==snap)state.undoStack.push(snap);
    if(state.undoStack.length>80)state.undoStack.shift();
    state.redoStack=[];updateUndoUi();
  }
  function updateUndoUi(){undoBtn.disabled=!state.undoStack.length;redoBtn.disabled=!state.redoStack.length;}
  function restoreSnapshot(raw){
    try{state.doc=normalizeDoc(JSON.parse(raw));setDirty(true);renderList();renderSelection();updateUndoUi();}
    catch{}
  }
  function undo(){if(!state.undoStack.length)return;state.redoStack.push(snapshotDoc());restoreSnapshot(state.undoStack.pop());}
  function redo(){if(!state.redoStack.length)return;state.undoStack.push(snapshotDoc());restoreSnapshot(state.redoStack.pop());}
  function currentGeneration(entry){
    const n=Number(entry?._dexIndex||0); if(n<=151)return 1;if(n<=251)return 2;if(n<=386)return 3;if(n<=493)return 4;if(n<=649)return 5;if(n<=721)return 6;if(n<=809)return 7;if(n<=905)return 8;return 9;
  }
  function updateBatchUi(){
    batchBar.classList.toggle('hidden',!state.manageMode);batchCount.textContent=`${state.selectedMany.size} seleccionados`;
    manageBtn.classList.toggle('active',state.manageMode);list.classList.toggle('manage-mode',state.manageMode);
  }
  function setDirty(v=true){
    state.dirty=!!v;
    saveBtn.textContent=state.dirty?'Guardar cambios •':'Guardar cambios';
    updateStatus();
  }

  function functionalEntityFields(bucket,id){
    const key=safeUpper(id), row=state.doc?.[bucket]?.[key]||{};
    const baselineMap=(bucket==='moves'?state.baselineMoves:state.baselineAbilities),base=baselineMap.get(key)||{};
    const isNew=row?._new===true || !baselineMap.has(key);
    const textOnly=new Set(['Name','Description']);
    const functional=Object.keys(row).filter(f=>!f.startsWith('_')&&!textOnly.has(f));
    const realFunctional=isNew?functional:functional.filter(f=>!sameField(row[f],base?.[f]??''));
    const behaviorExplicit=bucket==='moves'&&(row?._behaviorChanged===true||String(row?._behaviorChanged||'').toLowerCase()==='true');
    const behaviorOnly=bucket==='moves'&&!functional.length&&String(row?._notes||'').trim()!=='';
    return [...realFunctional,...((behaviorExplicit||behaviorOnly)?['_behavior']:[])];
  }
  function functionalEntityCount(bucket){
    return Object.keys(state.doc?.[bucket]||{}).filter(id=>functionalEntityFields(bucket,id).length>0).length;
  }
  function entityProvenance(bucket,id){
    const key=safeUpper(id);
    const baseline=bucket==='moves'?state.baselineMoves:state.baselineAbilities;
    const row=state.doc?.[bucket]?.[key]||{};
    const hasCanon=!!key&&baseline.has(key);
    const changed=!!key&&functionalEntityFields(bucket,key).length>0;
    const explicitNew=row?._new===true||String(row?._new||'').toLowerCase()==='true';
    if(!hasCanon||explicitNew)return {kind:'new',label:'JSON NUEVO',hasCanon:false,changed:true};
    if(changed)return {kind:'retouched',label:'JSON RETOCADO',hasCanon:true,changed:true};
    return {kind:'canon',label:'CANON',hasCanon:true,changed:false};
  }
  function provenanceBadge(label,kind='canon',title=''){
    return el('span',{class:`cdx-origin-badge ${kind}`,text:label,title});
  }
  function appendEntityProvenance(container,bucket,id){
    const key=safeUpper(id);if(!key)return;
    const p=entityProvenance(bucket,key);
    container.append(provenanceBadge(p.label,p.kind,p.kind==='canon'?'Existe en canon y no tiene override funcional en el JSON.':p.kind==='retouched'?'Existe en canon, pero sus datos/efecto están retocados por el JSON de ChangeDex.':'No existe en el canon/baseline: fue creado/importado mediante JSON.'));
  }
  function fieldOriginBadge(field,c){
    const isJson=!!c?.fields?.includes(field);
    return provenanceBadge(isJson?'JSON':'CANON',isJson?'json':'canon',isJson?'El resultado de este campo difiere del PBS/canon y está guardado en pokemon_changes.json.':'Este campo usa el valor del PBS/canon sin override JSON.');
  }
  function entityBucketForSpeciesField(field){
    if(['Moves','TutorMoves','EggMoves'].includes(field))return 'moves';
    if(['Abilities','HiddenAbilities'].includes(field))return 'abilities';
    return '';
  }
  function updateStatus(){
    const c=Object.keys(state.doc.species||{}).length,m=functionalEntityCount('moves'),a=functionalEntityCount('abilities');
    const origin=state.doc.migratedFrom?` · origen: ${String(state.doc.migratedFrom)}`:'';
    status.textContent=`${state.entries.length} especies/formas · ${c} Pokémon · ${m} Moves · ${a} Habilidades con cambios${state.dirty?' · sin guardar':''}${origin}${state.loadingPhase||''}`;
    libCount.textContent=String(filtered().length);
  }

  async function read(path){ return await ctx.fs.readProjectFile(path); }
  async function listDir(path){ try{return await ctx.fs.listProjectDir(path);}catch{return [];} }
  function sleep(ms){return new Promise(resolve=>setTimeout(resolve,Math.max(0,Number(ms)||0)));}
  function retryableWriteError(err){
    const msg=safeLower(err?.message||err);
    return msg.includes('acceso denegado')||msg.includes('access denied')||msg.includes('permission denied')||msg.includes('eacces')||msg.includes('os error 5')||msg.includes('being used by another process')||msg.includes('used by another process')||msg.includes('sharing violation')||msg.includes('one drive')||msg.includes('onedrive');
  }
  async function writeTextAbsolute(rel,text){
    const abs=projectAbs(rel);
    const invoke=window.__TAURI__?.core?.invoke||window.__TAURI__?.tauri?.invoke;
    if(!abs||typeof invoke!=='function')throw new Error('Maker Studio no expone escritura de texto absoluta.');
    await invoke('write_text_file',{path:abs,content:String(text??'')});
    return true;
  }
  async function writeProjectTextRobust(rel,text,{attempts=6,directFallback=true}={}){
    const delays=[0,90,200,420,820,1350];
    let last=null;
    try{
      const dir=String(rel||'').replace(/\\/g,'/').split('/').slice(0,-1).join('/');
      if(dir)await ctx.fs.projectMkdir?.(dir);
    }catch{}
    for(let i=0;i<Math.max(1,Math.min(attempts,delays.length));i++){
      if(delays[i])await sleep(delays[i]);
      try{await ctx.fs.writeProjectFile(rel,String(text??''));return {mode:'project',attempt:i+1};}
      catch(e){last=e;if(!retryableWriteError(e))throw e;}
    }
    if(directFallback){
      const directDelays=[0,120,320];
      for(let i=0;i<directDelays.length;i++){
        if(directDelays[i])await sleep(directDelays[i]);
        try{await writeTextAbsolute(rel,text);return {mode:'direct',attempt:i+1};}
        catch(e){last=e;if(!retryableWriteError(e)&&!safeLower(e?.message||e).includes('write_text_file'))throw e;}
      }
    }
    throw last||new Error('No se pudo escribir '+rel);
  }
  function parsedUpdatedAt(doc){
    const raw=String(doc?.updatedAt||doc?.meta?.updatedAt||'').trim();
    const t=raw?Date.parse(raw):NaN;
    return Number.isFinite(t)?t:0;
  }
  async function loadChangeDocument(){
    let main=null,recovery=null;
    try{main=normalizeDoc(JSON.parse(await read(JSON_PATH)));}catch{}
    try{recovery=normalizeDoc(JSON.parse(await read(RECOVERY_PATH)));}catch{}
    if(recovery&&(!main||parsedUpdatedAt(recovery)>parsedUpdatedAt(main))){
      toast('Se recuperó pokemon_changes.recovery.json porque es más reciente que el JSON principal. Puedes seguir editando sin perder cambios.','warning');
      return recovery;
    }
    return main||recovery||normalizeDoc({schema:5,generatedBy:'ChangeDex Studio',species:{},moves:{},abilities:{}});
  }
  function namesFromList(ls){
    return (ls||[]).map(e=>typeof e==='string'?e:(e?.name||e?.path||''))
      .map(x=>String(x||'').split(/[\\/]/).pop()).filter(Boolean);
  }

  function currentProjectKey(){
    return String(state.gameRoot||ctx.editor?.gameRoot?.()||'project');
  }

  function resetPbsSessionCache(){
    PBS_SESSION_CACHE.projectKey=currentProjectKey();
    PBS_SESSION_CACHE.names=null;
    PBS_SESSION_CACHE.text.clear();
    PBS_SESSION_CACHE.sections.clear();
  }

  function ensurePbsSessionScope(){
    const key=currentProjectKey();
    if(PBS_SESSION_CACHE.projectKey!==key)resetPbsSessionCache();
  }

  async function getPbsNames(force=false){
    ensurePbsSessionScope();
    if(force)resetPbsSessionCache();
    if(PBS_SESSION_CACHE.names)return PBS_SESSION_CACHE.names.slice();
    const names=namesFromList(await listDir('PBS/')).sort();
    PBS_SESSION_CACHE.names=names.slice();
    return names;
  }

  async function readPbsCached(rel,force=false){
    ensurePbsSessionScope();
    if(!force&&PBS_SESSION_CACHE.text.has(rel))return PBS_SESSION_CACHE.text.get(rel);
    const value=await read(rel);
    PBS_SESSION_CACHE.text.set(rel,value);
    PBS_SESSION_CACHE.sections.delete(rel);
    return value;
  }

  async function parsePbsCached(rel,force=false){
    ensurePbsSessionScope();
    if(!force&&PBS_SESSION_CACHE.sections.has(rel))return PBS_SESSION_CACHE.sections.get(rel);
    const name=String(rel||'').split(/[\\/]/).pop();
    const parsed=parsePbsSections(await readPbsCached(rel,force),name);
    PBS_SESSION_CACHE.sections.set(rel,parsed);
    return parsed;
  }

  async function loadCatalog(prefix,names,force=false){
    const wanted=(names||[]).filter(n=>new RegExp('^'+prefix+'.*\\.txt$','i').test(String(n||''))).sort();
    const chunks=await Promise.all(wanted.map(async n=>{
      try{return await parsePbsCached('PBS/'+n,force);}
      catch{return [];}
    }));
    const map=new Map();
    for(const chunk of chunks){
      for(const e of (chunk||[])){
        const id=String(e?._header??'').split(',')[0].trim();
        if(id)map.set(id,{id,name:String(e?.Name??id).trim()||id,entry:e});
      }
    }
    return [...map.values()].filter(v=>v&&String(v.id||'').trim()).sort((a,b)=>String(a.id||'').localeCompare(String(b.id||'')));
  }


  async function loadProject(force=false){
    try { state.gameRoot=String(ctx.editor?.gameRoot?.()||''); } catch { state.gameRoot=''; }
    if(force)resetPbsSessionCache();
    state.loadingPhase=' · leyendo especies…';updateStatus();
    const names=await getPbsNames(force);
    const pokemonNames=names
      .filter(n=>/^pokemon.*\.txt$/i.test(String(n||''))&&!/^pokemon_(metrics|regional_dexes)/i.test(String(n||''))).sort();

    // Read all species PBS files concurrently instead of serial file-by-file I/O.
    const parsed=await Promise.all(pokemonNames.map(async n=>{
      try{return [n,await parsePbsCached('PBS/'+n,force)];}
      catch(e){try{ctx.log.warn('ChangeDex Studio: no pude leer '+n,e);}catch{}return [n,[]];}
    }));
    state.entries=mergeSpeciesFiles(parsed).filter(e=>{
      const p=String(e?._header??'').split(',');
      return !!p[0] && (!p[1] || /^\d+$/.test(String(p[1]||'').trim()));
    });
    let dex=0;const dexBySpecies=new Map();for(const e of state.entries){const sp=splitHeader(e._header).species;if(!dexBySpecies.has(sp)){dex++;dexBySpecies.set(sp,dex);}e._dexIndex=dexBySpecies.get(sp);}
    state.byHeader=new Map(state.entries.map(e=>[String(e._header),e]));
    state.basesBySpecies.clear();
    for(const e of state.entries) {
      const {species,form}=splitHeader(e._header);
      if (species && !form) state.basesBySpecies.set(species,e);
    }
    state.doc=await loadChangeDocument();
    try{state.config={...state.config,...JSON.parse(await read(CONFIG_PATH))};}catch{}

    state.selected=state.entries[0]?._header||null;
    state.loadingPhase=' · catálogos cargando en segundo plano';
    renderList();
    await renderSelection();
    updateStatus();

    // The editor is already usable at this point. Moves/abilities/types and
    // runtime status finish in parallel without blocking the Pokémon library.
    const catalogs=Promise.all([
      loadCatalog('moves',names,force),
      loadCatalog('abilities',names,force),
      loadCatalog('types',names,force),
      loadCatalog('items',names,force)
    ]);
    [state.moves,state.abilities,state.types,state.items]=await catalogs;
    state.projectMoveIds=new Set((state.moves||[]).map(x=>safeUpper(x?.id)).filter(Boolean));
    state.projectAbilityIds=new Set((state.abilities||[]).map(x=>safeUpper(x?.id)).filter(Boolean));
    state.baselineMoves=new Map((state.moves||[]).map(m=>[safeUpper(m?.id),m?.entry||{}]));
    state.baselineAbilities=new Map((state.abilities||[]).map(a=>[safeUpper(a?.id),a?.entry||{}]));
    syncJsonEntityCatalogs();
    typeSelect.innerHTML='';typeSelect.append(el('option',{value:'all',text:'Todos los tipos'}));state.types.forEach(t=>typeSelect.append(el('option',{value:safeUpper(t.id),text:t.name||t.id})));typeSelect.value=state.typeFilter;
    state.loadingPhase='';
    renderInspector();
    updateStatus();
  }

  function projectAbs(rel){
    const rootPath=String(state.gameRoot||'').replace(/[\\/]+$/,'');
    return rootPath ? rootPath+'/'+String(rel||'').replace(/^[/\\]+/,'') : '';
  }

  async function loadAssetUrl(rel){
    const abs=projectAbs(rel);
    if (!abs || state.assetFailures.has(abs)) return null;
    if (state.assetUrls.has(abs)) return state.assetUrls.get(abs);
    const invoke=window.__TAURI__?.core?.invoke;
    if (!invoke) return null;
    try {
      const bytes=await invoke('read_binary_file',{path:abs});
      if (!bytes?.length) { state.assetFailures.add(abs); return null; }
      const arr=bytes instanceof Uint8Array?bytes:new Uint8Array(bytes||[]);
      const url=URL.createObjectURL(new Blob([arr],{type:'image/png'}));
      state.assetUrls.set(abs,url);
      return url;
    } catch {
      state.assetFailures.add(abs);
      return null;
    }
  }

  function assetCandidates(header,kind){
    const {species,form}=splitHeader(header);
    const stem=form?`${species}_${form}`:species;
    if (kind==='icon') return [
      `Graphics/Pokemon/Icons/${stem}.png`,
      `Graphics/Pokemon/Icons/${species}.png`
    ];
    return [
      `Graphics/Pokemon/Front/${stem}.png`,
      `Graphics/Pokemon/Front/${species}.png`
    ];
  }

  function alphaCellStats(ctx2d,x,y,w,h){
    try{
      const data=ctx2d.getImageData(x,y,w,h).data;
      const step=Math.max(1,Math.floor(Math.max(w,h)/128));
      let count=0,minX=w,minY=h,maxX=-1,maxY=-1,samples=0;
      for(let yy=0;yy<h;yy+=step)for(let xx=0;xx<w;xx+=step){
        samples++;
        if(data[(yy*w+xx)*4+3]<12)continue;
        count++; if(xx<minX)minX=xx;if(yy<minY)minY=yy;if(xx>maxX)maxX=xx;if(yy>maxY)maxY=yy;
      }
      if(!count)return {count:0,ratio:0,fill:0,edge:4,bounds:null};
      const bw=Math.max(1,maxX-minX+1),bh=Math.max(1,maxY-minY+1);
      const margin=Math.max(1,Math.round(Math.min(w,h)*.025));
      const edge=(minX<=margin?1:0)+(minY<=margin?1:0)+(maxX>=w-1-margin?1:0)+(maxY>=h-1-margin?1:0);
      return {count,ratio:count/Math.max(1,samples),fill:(bw*bh)/Math.max(1,w*h),edge,bounds:{x:minX,y:minY,w:bw,h:bh}};
    }catch{return {count:0,ratio:0,fill:1,edge:4,bounds:null};}
  }

  function detectFirstFrameRect(img,kind='sprite'){
    const W=Math.max(1,img.naturalWidth||img.width||1),H=Math.max(1,img.naturalHeight||img.height||1);
    // Match the actual Pokémon asset conventions instead of trying to infer
    // animation cells from the alpha silhouette. Essentials v21 party icons
    // are two horizontal frames; animated battlers are horizontal (or, in a
    // few packs, vertical) strips whose first frame is the leading square.
    // This is the same practical rule used by the supplied PBS Editor/BAS and
    // prevents an entire strip being scaled down into a thin line.
    if(kind==='icon' && W>=2){
      const fw=Math.max(1,Math.floor(W/2));
      return {rect:{x:0,y:0,w:fw,h:H},cells:2};
    }
    if(W>H*1.15){
      const side=H;
      return {rect:{x:0,y:0,w:side,h:side},cells:Math.max(1,Math.round(W/side))};
    }
    if(H>W*1.15){
      const side=W;
      return {rect:{x:0,y:0,w:side,h:side},cells:Math.max(1,Math.round(H/side))};
    }
    return {rect:{x:0,y:0,w:W,h:H},cells:1};
  }

  function opaqueBounds(ctx2d,w,h){
    try {
      const data=ctx2d.getImageData(0,0,w,h).data;
      let minX=w,minY=h,maxX=-1,maxY=-1;
      for (let y=0;y<h;y++) for (let x=0;x<w;x++) {
        if (data[(y*w+x)*4+3]===0) continue;
        if (x<minX) minX=x; if (y<minY) minY=y; if (x>maxX) maxX=x; if (y>maxY) maxY=y;
      }
      if (maxX<minX || maxY<minY) return {x:0,y:0,w,h};
      return {x:minX,y:minY,w:maxX-minX+1,h:maxY-minY+1};
    } catch { return {x:0,y:0,w,h}; }
  }

  function drawFirstFrameSmart(img,canvas,kind){
    const targetW=canvas.width||48,targetH=canvas.height||48;
    const detected=detectFirstFrameRect(img,kind),r=detected.rect;
    const frameW=Math.max(1,Math.round(r.w)),frameH=Math.max(1,Math.round(r.h));
    const temp=document.createElement('canvas');temp.width=frameW;temp.height=frameH;
    const t=temp.getContext('2d',{willReadFrequently:true});t.imageSmoothingEnabled=false;
    t.clearRect(0,0,frameW,frameH);
    t.drawImage(img,r.x,r.y,r.w,r.h,0,0,frameW,frameH);
    const b=opaqueBounds(t,frameW,frameH);
    const pad=kind==='icon'?2:6;
    const scale=Math.min((targetW-pad*2)/Math.max(1,b.w),(targetH-pad*2)/Math.max(1,b.h));
    const dw=Math.max(1,Math.round(b.w*scale)),dh=Math.max(1,Math.round(b.h*scale));
    const dx=Math.round((targetW-dw)/2),dy=Math.round((targetH-dh)/2);
    const out=canvas.getContext('2d');out.imageSmoothingEnabled=false;out.clearRect(0,0,targetW,targetH);
    out.drawImage(temp,b.x,b.y,b.w,b.h,dx,dy,dw,dh);
    canvas.dataset.frames=String(detected.cells);
    canvas.classList.add('loaded');
  }

  async function paintPokemonCanvas(header,canvas,kind='icon'){
    for (const rel of assetCandidates(header,kind)) {
      const url=await loadAssetUrl(rel);
      if (!url) continue;
      const ok=await new Promise(resolve=>{
        const img=new Image();
        img.onload=()=>{ try{drawFirstFrameSmart(img,canvas,kind);resolve(true);}catch(e){try{ctx.log.warn('ChangeDex sprite crop failed',e);}catch{}resolve(false);} };
        img.onerror=()=>resolve(false);
        img.src=url;
      });
      if (ok) return true;
    }
    canvas?.classList?.add('failed');
    return false;
  }

  function current(){
    const source=state.byHeader.get(state.selected);
    if (!source) return null;
    const base=resolvePbsEntry(source,state.basesBySpecies)||source;
    return {
      source,
      base,
      eff:effectiveEntry(base,state.doc.species[state.selected]),
      fields:changedFields(state.doc,state.selected)
    };
  }

  function filtered(){
    const q=normalizeSearch(state.search.trim());
    let rows=state.entries.filter(e=>{
      const header=String(e?._header??'');
      const {form}=splitHeader(header);
      const changed=!!state.doc.species[header];
      if(state.listMode==='changed'&&!changed)return false;
      if(state.listMode==='unchanged'&&changed)return false;
      if(state.listMode==='base'&&form>0)return false;
      if(state.listMode==='forms'&&form<=0)return false;
      if(state.generation!=='all'&&currentGeneration(e)!==Number(state.generation))return false;
      const resolved=effectiveEntry(resolvePbsEntry(e,state.basesBySpecies)||e,state.doc.species[header]);
      if(state.typeFilter!=='all'&&!parseList(resolved.Types).map(safeUpper).includes(state.typeFilter))return false;
      const name=normalizeSearch(displayName(e,state.basesBySpecies));
      const hay=normalizeSearch(header);
      return !q||name.includes(q)||hay.includes(q);
    });
    if(state.sortMode==='name')rows.sort((a,b)=>displayName(a,state.basesBySpecies).localeCompare(displayName(b,state.basesBySpecies)));
    else if(state.sortMode==='changes')rows.sort((a,b)=>Object.keys(state.doc.species?.[b._header]||{}).length-Object.keys(state.doc.species?.[a._header]||{}).length||Number(a._dexIndex)-Number(b._dexIndex));
    else rows.sort((a,b)=>Number(a._dexIndex)-Number(b._dexIndex)||splitHeader(a._header).form-splitHeader(b._header).form);
    return rows;
  }

  function renderList(){
    const token=++state.listRenderToken;
    const previousScroll=Number(list.scrollTop||0);
    const ensureSelectionVisible=!!state.ensureSelectionVisible;
    state.ensureSelectionVisible=false;
    try{state.iconObserver?.disconnect?.();}catch{}
    state.iconObserver=null;
    list.innerHTML='';
    const entries=filtered();
    libCount.textContent=String(entries.length);

    const loadRowIcon=(canvas,header)=>{
      if(!canvas?.isConnected||canvas.dataset.loading==='1'||canvas.dataset.loaded==='1')return;
      canvas.dataset.loading='1';
      paintPokemonCanvas(header,canvas,'icon').then(ok=>{
        if(token!==state.listRenderToken||!canvas.isConnected)return;
        canvas.dataset.loading='0';canvas.dataset.loaded=ok?'1':'0';
        const shell=canvas.closest('.cdx-icon-shell');
        if(shell)shell.classList.toggle('missing',!ok);
      });
    };
    if(typeof IntersectionObserver!=='undefined'){
      state.iconObserver=new IntersectionObserver((items)=>{
        for(const item of items){
          if(!item.isIntersecting)continue;
          const canvas=item.target,header=String(canvas?.dataset?.header||'');
          state.iconObserver?.unobserve?.(canvas);
          if(header)loadRowIcon(canvas,header);
        }
      },{root:list,rootMargin:'180px 0px'});
    }

    const frag=document.createDocumentFragment();
    for (const e of entries) {
      const header=String(e._header||'');
      const changeCount=Object.keys(state.doc.species?.[header]||{}).length;
      const row=el('div',{class:'cdx-row '+state.viewMode+(header===state.selected?' active':'')+(changeCount?' changed':'')+(state.selectedMany.has(header)?' multi-selected':''),dataset:{header}});
      const multi=el('input',{class:'cdx-multi-check',type:'checkbox'});multi.checked=state.selectedMany.has(header);
      const iconShell=el('div',{class:'cdx-icon-shell'});
      const canvas=el('canvas',{class:'cdx-icon',width:'42',height:'42',dataset:{header}});
      iconShell.append(canvas,el('span',{class:'cdx-icon-fallback',text:'◆'}));
      const text=el('div',{class:'cdx-row-copy'});
      const resolved=effectiveEntry(resolvePbsEntry(e,state.basesBySpecies)||e,state.doc.species[header]);
      const titleRow=el('div',{class:'cdx-row-title'});titleRow.append(el('b',{text:displayName(e,state.basesBySpecies)}));for(const t of parseList(resolved.Types).slice(0,2))titleRow.append(typeBadge(t));
      const hiddenInDex=splitHeader(header).form>0&&hiddenFormsSet().has(header.toUpperCase());
      text.append(titleRow,el('small',{text:`#${String(e._dexIndex||0).padStart(3,'0')} · ${header}${changeCount?` · Modificado (${changeCount})`:' · Base'}${hiddenInDex?' · Oculta en ChangeDex':''}`}));
      const tail=el('div',{class:'cdx-row-tail'});
      if(hiddenInDex)tail.append(el('span',{class:'cdx-hidden-mark',text:'🙈',title:'Oculta en ChangeDex ingame'}));
      if (changeCount) tail.append(el('span',{class:'cdx-row-count',text:String(changeCount)}));
      tail.append(el('span',{class:'cdx-dot'}));
      if(state.manageMode)row.append(multi);row.append(iconShell,text,tail);
      const toggleMulti=(ev)=>{
        if(ev?.shiftKey&&state.lastMultiHeader){const rows=filtered(),a=rows.findIndex(x=>x._header===state.lastMultiHeader),b=rows.findIndex(x=>x._header===header);if(a>=0&&b>=0){for(let i=Math.min(a,b);i<=Math.max(a,b);i++)state.selectedMany.add(rows[i]._header);}}
        else if(state.selectedMany.has(header))state.selectedMany.delete(header);else state.selectedMany.add(header);
        state.lastMultiHeader=header;updateBatchUi();renderList();
      };
      multi.onclick=(ev)=>{ev.stopPropagation();toggleMulti(ev);};
      row.onclick=(ev)=>{if(state.manageMode){toggleMulti(ev);return;}state.selected=header;renderList();renderSelection();};
      frag.append(row);
      if(state.iconObserver)state.iconObserver.observe(canvas);
      else setTimeout(()=>loadRowIcon(canvas,header),0);
    }
    list.append(frag);
    if (!list.children.length) list.append(el('div',{class:'cdx-empty',text:'No hay resultados.'}));
    // Mouse selection and multi-select must never throw the library back to the top.
    // Only keyboard/programmatic navigation asks us to reveal the active row.
    requestAnimationFrame(()=>{
      if(ensureSelectionVisible){
        const active=list.querySelector('.cdx-row.active');
        if(active)active.scrollIntoView({block:'nearest'});
      }else list.scrollTop=previousScroll;
    });
  }

  function typeBadge(type){
    const t=safeUpper(type);
    const color=TYPE_COLORS[t]||'#7d8297';
    return el('span',{class:'cdx-type-badge',text:t||'—',style:{background:color+'33',borderColor:color+'88'}});
  }

  async function saveConfigSilently(){
    try{await writeProjectTextRobust(CONFIG_PATH,JSON.stringify(state.config,null,2)+'\n',{attempts:4,directFallback:true});return true;}catch{return false;}
  }
  function hiddenFormsSet(){return new Set((Array.isArray(state.config.hiddenForms)?state.config.hiddenForms:[]).map(v=>String(v||'').trim().toUpperCase()).filter(Boolean));}
  function hiddenEntitySet(bucket){const key=bucket==='moves'?'hiddenMoves':'hiddenAbilities';return new Set((Array.isArray(state.config[key])?state.config[key]:[]).map(v=>String(v||'').trim().toUpperCase()).filter(Boolean));}
  async function setHiddenEntities(bucket,ids,hidden=true){const key=bucket==='moves'?'hiddenMoves':'hiddenAbilities',set=hiddenEntitySet(bucket);for(const raw of ids||[]){const id=safeUpper(raw);if(!id)continue;hidden?set.add(id):set.delete(id);}state.config[key]=[...set].sort();await saveConfigSilently();}
  async function toggleCurrentFormHidden(header){
    const key=String(header||'').trim().toUpperCase();if(!key||!key.includes(','))return;
    const set=hiddenFormsSet();const hiding=!set.has(key);hiding?set.add(key):set.delete(key);state.config.hiddenForms=[...set].sort();
    await saveConfigSilently();toast(hiding?'Forma oculta en ChangeDex ingame. El cambio seguirá aplicándose al gameplay.':'Forma visible otra vez en ChangeDex ingame.','info');renderSelection();
  }
  async function setSelectedFormsHidden(hidden){
    const selected=[...state.selectedMany];
    if(!selected.length){toast('Selecciona una o más formas desde Gestionar.','warning');return;}
    const set=hiddenFormsSet();let changed=0,ignored=0;
    for(const raw of selected){
      const key=String(raw||'').trim().toUpperCase();
      const {form}=splitHeader(key);
      if(form<=0){ignored++;continue;}
      if(hidden){if(!set.has(key)){set.add(key);changed++;}}
      else if(set.delete(key))changed++;
    }
    state.config.hiddenForms=[...set].sort();
    await saveConfigSilently();
    renderList();renderSelection();
    toast(`${changed} forma(s) ${hidden?'ocultadas':'mostradas'}${ignored?` · ${ignored} base(s) ignoradas`:''}.`,'info');
  }

  async function renderSelection(){
    const token=++state.selectionToken;
    const c=current();
    centerHead.innerHTML=''; comparison.innerHTML=''; inspectBody.innerHTML='';
    if (!c) { centerHead.append(el('div',{class:'cdx-empty',text:'Selecciona un Pokémon.'})); return; }

    const portrait=el('div',{class:'cdx-portrait'});
    const canvas=el('canvas',{width:'112',height:'112'});
    portrait.append(canvas);
    const nm=el('div',{class:'cdx-name'});
    const {form}=splitHeader(state.selected);
    const topLine=el('div',{class:'cdx-name-top'});
    topLine.append(el('h2',{text:displayName(c.source,state.basesBySpecies)}));
    if (form) topLine.append(el('span',{class:'cdx-form-pill',text:`Forma ${form}`}));
    const typeLine=el('div',{class:'cdx-type-line'});
    for (const t of parseList(c.eff.Types)) typeLine.append(typeBadge(t));
    const meta=el('p',{class:'cdx-selection-meta'});
    meta.append(el('code',{text:`[${state.selected}]`}),document.createTextNode(' · '),el('span',{class:'cdx-change-count',text:c.fields.length?`${c.fields.length} campos modificados`:'sin cambios'}));
    const navRows=filtered();
    const navIndex=Math.max(0,navRows.findIndex(e=>String(e?._header||'')===String(state.selected)));
    const quickNav=el('div',{class:'cdx-quick-nav'});
    quickNav.append(
      el('button',{class:'cdx-nav-btn',text:'‹',title:'Pokémon anterior · ↑',onClick:()=>selectRelative(-1)}),
      el('span',{text:`${navRows.length?navIndex+1:0} / ${navRows.length}`}),
      el('button',{class:'cdx-nav-btn',text:'›',title:'Pokémon siguiente · ↓',onClick:()=>selectRelative(1)})
    );
    nm.append(topLine,typeLine,meta);
    centerHead.append(portrait,nm,el('div',{class:'cdx-spacer'}),quickNav);
    centerHead.append(el('button',{class:'cdx-btn primary',text:'Guardar cambios',onClick:save}));
    if (c.fields.length) centerHead.append(el('button',{class:'cdx-btn danger',text:'↶ Restaurar original',onClick:()=>{pushUndo();delete state.doc.species[state.selected]; setDirty(); renderList(); renderSelection();}}));
    if (form>0){const hidden=hiddenFormsSet().has(String(state.selected).toUpperCase());centerHead.append(el('button',{class:'cdx-btn cdx-btn-soft'+(hidden?' active':''),text:hidden?'👁 Mostrar en ChangeDex':'🙈 Ocultar en ChangeDex',title:'Sólo afecta a la evidencia visual en ChangeDex; el override sigue activo ingame.',onClick:()=>toggleCurrentFormHidden(state.selected)}));}
    paintPokemonCanvas(state.selected,canvas,'sprite').then(ok=>{
      if(token!==state.selectionToken)return;
      portrait.classList.toggle('missing',!ok);
    });
    renderComparison(c);
    renderInspector();
  }

  function statVals(v){
    const a=String(v??'0,0,0,0,0,0').split(',').map(x=>Number(String(x||'').trim())||0);
    while(a.length<6)a.push(0);
    return a.slice(0,6);
  }

  function renderComparison(c){
    comparison.innerHTML='';
    const summary=el('div',{class:'cdx-summary-strip friendly'});
    const bstBefore=statVals(c.base.BaseStats).reduce((a,b)=>a+b,0),bstAfter=statVals(c.eff.BaseStats).reduce((a,b)=>a+b,0);
    summary.append(
      summaryMetric('Stats',`BST ${bstAfter}`,bstAfter===bstBefore?'CANON':`JSON · ${bstBefore} → ${bstAfter}`),
      summaryMetric('Tipos',parseList(c.eff.Types).join(' / ')||'—',c.fields.includes('Types')?'JSON':'CANON'),
      summaryMetric('Habilidades',`${parseList(c.eff.Abilities).length} + ${parseList(c.eff.HiddenAbilities).length} oculta(s)`,c.fields.includes('Abilities')||c.fields.includes('HiddenAbilities')?'JSON':'CANON'),
      summaryMetric('Movimientos',`${parseMoves(c.eff.Moves).length} nivel · ${parseList(c.eff.TutorMoves).length} tutor · ${parseList(c.eff.EggMoves).length} huevo`,c.fields.includes('Moves')||c.fields.includes('TutorMoves')||c.fields.includes('EggMoves')?'JSON':'CANON'),
      summaryMetric('Evolución',`${parseEvos(c.eff.Evolutions).length} método(s)`,c.fields.includes('Evolutions')?'JSON':'CANON'),
      summaryMetric('Cambios',String(c.fields.length),c.fields.length?'JSON activo':'CANON')
    );
    comparison.append(summary);
    if(c.fields.length){
      const changed=el('div',{class:'cdx-card cdx-changes-card friendly'});
      changed.append(el('div',{class:'cdx-card-title'},[el('h3',{text:'Cambios realizados'}),el('span',{class:'cdx-count accent',text:String(c.fields.length)})]));
      const chips=el('div',{class:'cdx-change-chips'});
      const labels={BaseStats:'Stats',Types:'Tipos',Abilities:'Habilidades',HiddenAbilities:'Habilidad oculta',Moves:'Movimientos por nivel',TutorMoves:'Movimientos tutor',EggMoves:'Movimientos huevo',Evolutions:'Evolución'};
      for(const f of c.fields){const b=el('button',{class:'cdx-change-nav',text:labels[f]||f,onClick:()=>{const map={BaseStats:'stats',Types:'identity',Abilities:'abilities',HiddenAbilities:'abilities',Moves:'moves',TutorMoves:'moves',EggMoves:'moves',Evolutions:'evolution'};state.tab=map[f]||'advanced';renderTabs();renderInspector();}});chips.append(b);}
      changed.append(chips);comparison.append(changed);
    }
    const details=el('details',{class:'cdx-compare-details'});
    const sum=el('summary',{text:'Ver comparativa CANON → JSON'});details.append(sum);
    const grid=el('div',{class:'cdx-compare-grid'});grid.append(compareCard('CANON / PBS',c.base,false,c),compareCard('RESULTADO JSON',c.eff,true,c));details.append(grid);comparison.append(details);
  }

  function summaryMetric(label,value,note){
    const m=el('div',{class:'cdx-summary-metric'});
    m.append(el('small',{text:label}),el('b',{text:value}),el('span',{text:note}));
    return m;
  }

  function compareCard(titleText,e,isAfter,c){
    const card=el('div',{class:'cdx-card'+(isAfter?' result':' baseline')});
    const head=el('div',{class:'cdx-card-title'});
    head.append(el('h3',{text:titleText}),el('span',{class:'cdx-card-kicker',text:isAfter?'CANON + JSON':'CANON'}));
    card.append(head);
    const stats=statVals(e.BaseStats),before=statVals(c.base.BaseStats),sg=el('div',{class:'cdx-stat-grid'});
    STAT_KEYS.forEach((k,i)=>{
      const s=el('div',{class:'cdx-stat'+(isAfter&&stats[i]!==before[i]?' changed':'')});
      s.append(el('small',{text:k}),el('b',{text:String(stats[i])}));
      if (isAfter&&stats[i]!==before[i]) s.append(el('em',{text:`${stats[i]>before[i]?'+':''}${stats[i]-before[i]}`}));
      sg.append(s);
    });
    card.append(sg);
    for (const f of ['Types','Abilities','HiddenAbilities','Evolutions']) {
      const line=el('div',{class:'cdx-fieldline'+(isAfter&&c.fields.includes(f)?' changed':'')});
      line.append(el('span',{text:f}),el('strong',{text:String(e[f]||'—')}));
      card.append(line);
    }
    return card;
  }

  function updateSelectionMeta(){
    const c=current();
    if (!c) return;
    const meta=centerHead.querySelector('.cdx-change-count');
    if (meta) meta.textContent=c.fields.length?`${c.fields.length} campos modificados`:'sin cambios';
    comparison.innerHTML=''; renderComparison(c);
    updateStatus();
  }

  function applyField(field,value,{rerender=true}={}){
    const c=current(); if(!c)return;
    pushUndo();
    setOverride(state.doc,state.selected,field,value,c.base);
    setDirty();
    if (rerender) { renderList(); renderSelection(); }
    else updateSelectionMeta();
  }

  function group(titleText,note=''){
    const g=el('div',{class:'cdx-group'});
    const head=el('div',{class:'cdx-group-title'});
    head.append(el('b',{text:titleText}));
    if (note) head.append(el('small',{text:note}));
    g.append(head);
    return g;
  }

  function sourceBadge(field,c){
    const p=fieldProvenance(c.source,field,state.basesBySpecies);
    if (p.inherited) return el('span',{class:'cdx-inherit',text:'HEREDA BASE',title:'Este campo está vacío/no definido en la forma y usa el valor de la forma base.'});
    return null;
  }
  function appendFieldOrigin(left,field,c){
    left.append(fieldOriginBadge(field,c));
    const inh=sourceBadge(field,c);if(inh)left.append(inh);
  }

  function fieldInput(g,label,field,type='text'){
    const c=current();
    const wrap=el('div',{class:'cdx-field'});
    const lab=el('div',{class:'cdx-label'});
    const left=el('span',{class:'cdx-label-left'}); left.append(document.createTextNode(label));
    appendFieldOrigin(left,field,c);
    lab.append(left,el('span',{class:'cdx-before',text:`PBS: ${String(c.base[field]||'—')}`}));
    const input=el(type==='textarea'?'textarea':'input',{class:type==='textarea'?'cdx-textarea':'cdx-input'});
    if(type!=='textarea')input.type=type;
    input.value=String(c.eff[field]??'');
    input.onchange=()=>applyField(field,input.value);
    wrap.append(lab,input);
    if(c.fields.includes(field)) wrap.append(el('button',{class:'cdx-reset',text:'↶ Volver al PBS',onClick:()=>applyField(field,c.base[field]||'')}));
    g.append(wrap);
    return input;
  }

  function createRefInput(value,suggestions,onLive,onCommit,placeholder='Buscar…'){
    const wrap=el('div',{class:'cdx-ref-wrap'});
    const input=el('input',{class:'cdx-input cdx-ref-input',type:'text',value:String(value??''),placeholder,autocomplete:'off'});
    input.value=String(value??'');
    const dropdown=el('div',{class:'cdx-ref-dropdown'});
    wrap.append(input,dropdown);
    let active=-1,filtered=[];
    const source=()=>Array.isArray(suggestions)?suggestions:[];
    const normalizeOption=(raw)=>{
      if(typeof raw==='string')return {id:String(raw),name:''};
      return {id:String(raw?.id??raw?.value??''),name:String(raw?.name??raw?.label??'')};
    };
    function filter(q){
      const needle=normalizeSearch(q);
      filtered=source().map(normalizeOption).filter(o=>{
        if(!o.id)return false;
        const hay=normalizeSearch(o.id+' '+o.name);
        return !needle||hay.includes(needle);
      }).slice(0,30);
    }
    function choose(item){
      const id=String(item?.id??'');
      if(!id)return;
      input.value=id;dropdown.classList.remove('open');active=-1;
      onLive?.(id);onCommit?.(id,{chosen:true});
    }
    function render(){
      dropdown.innerHTML='';
      if(!filtered.length){dropdown.classList.remove('open');active=-1;return;}
      dropdown.classList.add('open');
      filtered.forEach((item,i)=>{
        const o=el('button',{class:'cdx-ref-item'+(i===active?' active':''),type:'button'});
        o.append(el('strong',{text:item.id}));
        if(item.name&&safeUpper(item.name)!==safeUpper(item.id))o.append(el('small',{text:item.name}));
        o.onmousedown=(ev)=>{ev.preventDefault();choose(item);};
        dropdown.append(o);
      });
    }
    input.addEventListener('input',()=>{
      const v=String(input.value??'');
      filter(v.trim());active=-1;render();onLive?.(v);
    });
    input.addEventListener('focus',()=>{filter(String(input.value??'').trim());render();});
    input.addEventListener('blur',()=>{setTimeout(()=>dropdown.classList.remove('open'),120);onCommit?.(String(input.value??''),{blur:true});});
    input.addEventListener('keydown',(ev)=>{
      if(ev.key==='Escape'){dropdown.classList.remove('open');return;}
      if(dropdown.classList.contains('open')&&filtered.length){
        if(ev.key==='ArrowDown'){ev.preventDefault();ev.stopPropagation();active=Math.min(active+1,filtered.length-1);render();return;}
        if(ev.key==='ArrowUp'){ev.preventDefault();ev.stopPropagation();active=Math.max(active-1,0);render();return;}
        if((ev.key==='Enter'||ev.key==='Tab')&&active>=0&&active<filtered.length){ev.preventDefault();ev.stopPropagation();choose(filtered[active]);return;}
      }
      if(ev.key==='Enter'){ev.preventDefault();onCommit?.(String(input.value??''),{enter:true});dropdown.classList.remove('open');}
    });
    return {wrap,input};
  }

  function referenceListField(g,label,field,suggestions,{max=0,addLabel='+ Añadir',inlineToolbar=false,highlightNewMoves=false}={}){
    const c=current();
    let rows=parseList(c.eff[field]);
    const baseIds=new Set(parseList(c.base[field]).map(safeUpper).filter(Boolean));
    const entityBucket=entityBucketForSpeciesField(field);
    const box=el('div',{class:'cdx-field cdx-ref-list-field'});
    const lab=el('div',{class:'cdx-label'});
    const left=el('span',{class:'cdx-label-left'});left.append(document.createTextNode(label));appendFieldOrigin(left,field,c);
    lab.append(left,el('span',{class:'cdx-before',text:`CANON: ${String(c.base[field]||'—')}`}));
    box.append(lab);
    const legend=el('div',{class:'cdx-origin-legend compact'});
    legend.append(provenanceBadge('CANON','canon','Asignación presente en el PBS/canon del Pokémon.'),provenanceBadge('JSON','json','Asignación añadida/modificada por pokemon_changes.json.'));
    if(entityBucket)legend.append(provenanceBadge('JSON RETOCADO','retouched','El Move/Habilidad existe en canon pero su propia ficha está modificada globalmente.'),provenanceBadge('JSON NUEVO','new','Move/Habilidad global nuevo, inexistente en canon.'));
    box.append(legend);
    const holder=el('div',{class:'cdx-list-editor'});box.append(holder);
    const diffBox=el('div',{class:'cdx-assignment-diff'});box.append(diffBox);
    const validRows=()=>rows.map(v=>safeUpper(v)).filter(Boolean);
    function paintBadges(container,rawId){
      container.innerHTML='';
      const rid=safeUpper(rawId);if(!rid)return;
      const isCanon=baseIds.has(rid);
      container.append(provenanceBadge(isCanon?'CANON':'JSON',isCanon?'canon':'json',isCanon?'Esta asignación ya existe en el PBS/canon.':'Esta asignación no existe en el PBS/canon y viene del JSON.'));
      if(entityBucket){
        const p=entityProvenance(entityBucket,rid);
        if(p.kind!=='canon')container.append(provenanceBadge(p.label,p.kind,p.kind==='retouched'?'La entidad está retocada globalmente en el JSON.':'La entidad es nueva respecto al canon.'));
      }
    }
    function renderDiff(){
      diffBox.innerHTML='';
      const currentIds=new Set(validRows());
      const removed=[...baseIds].filter(id=>!currentIds.has(id));
      if(!removed.length){diffBox.classList.add('empty');return;}
      diffBox.classList.remove('empty');
      diffBox.append(el('b',{text:'Quitados del canon por JSON'}));
      const chips=el('div',{class:'cdx-assignment-diff-chips'});
      for(const id of removed){
        const name=catalogName(suggestions,id);
        const chip=el('span',{class:'cdx-assignment-diff-chip removed',text:name?`${name} · ${id}`:id,title:'Estaba asignado en el PBS/canon y ya no está en el resultado JSON.'});
        chips.append(chip);
      }
      diffBox.append(chips);
    }
    function commit(){
      rows=rows.map(v=>String(v??''));
      applyField(field,listToCsv(validRows()),{rerender:false});
      renderList();renderDiff();
    }
    function renderRows(){
      holder.innerHTML='';
      rows.forEach((value,i)=>{
        const rid=safeUpper(value),row=el('div',{class:'cdx-list-edit-row cdx-provenance-row'+(highlightNewMoves&&rid&&moveIsNew(rid)?' new-global-move':'')});
        const badges=el('span',{class:'cdx-origin-badges'});
        const ref=createRefInput(
          value,suggestions,
          (v)=>{rows[i]=String(v??'');paintBadges(badges,v);},
          (v,meta)=>{
            rows[i]=safeUpper(v);paintBadges(badges,rows[i]);
            // A freshly-added blank row is a draft. Do not delete it merely
            // because focus moved while the user is opening the picker.
            if(rows[i]||meta?.chosen||meta?.enter)commit();
          },
          `Buscar ${safeLower(label)}…`
        );
        paintBadges(badges,rid);
        const x=el('button',{class:'cdx-x',text:'×',title:'Eliminar'});
        x.onclick=()=>{rows.splice(i,1);commit();renderRows();};
        row.append(ref.wrap,badges,x);holder.append(row);
      });
      if(!max||rows.length<max){
        const add=el('button',{class:'cdx-add',text:addLabel,onClick:()=>{
          rows.push('');renderRows();
          requestAnimationFrame(()=>holder.querySelector('.cdx-list-edit-row:last-of-type input')?.focus());
        }});
        holder.append(add);
      }
      renderDiff();
    }
    renderRows();
    if(c.fields.includes(field)) box.append(el('button',{class:'cdx-reset',text:'↶ Volver al canon/PBS',onClick:()=>applyField(field,c.base[field]||'')}));
    g.append(box);
  }

  function studioLang(){return state.config.languageMode==='en'?'en':'es';}
  function sl(en,es){return studioLang()==='en'?en:es;}

  function renderInspector(){
    inspectBody.innerHTML='';
    const c=current(); if(!c)return;
    if(state.tab==='stats'){
      const g=group(sl('Base Stats','Stats base'),sl('Immediate CANON vs JSON comparison','Comparación inmediata CANON vs JSON'));
      const statsOrigin=el('div',{class:'cdx-origin-legend compact'});statsOrigin.append(fieldOriginBadge('BaseStats',c));g.append(statsOrigin);
      const vals=statVals(c.eff.BaseStats);
      const before=statVals(c.base.BaseStats);
      const sg=el('div',{class:'cdx-stats-edit'});
      STAT_KEYS.forEach((k,i)=>{
        const w=el('div',{class:'cdx-stat-input'+(vals[i]!==before[i]?' changed':'')});
        const top=el('div',{class:'cdx-stat-input-head'});top.append(el('label',{text:k}),el('small',{text:`PBS ${before[i]}`}));
        const n=el('input',{class:'cdx-input',type:'number',min:'1',max:'255',value:String(vals[i])});n.value=String(vals[i]);
        n.onchange=()=>{vals[i]=Math.max(1,Number(n.value)||1);applyField('BaseStats',vals.join(','));};
        w.append(top,n);sg.append(w);
      });
      g.append(sg);
      if(c.fields.includes('BaseStats'))g.append(el('button',{class:'cdx-reset',text:'↶ Stats originales',onClick:()=>applyField('BaseStats',c.base.BaseStats||'')}));
      inspectBody.append(g);
      const g2=group(sl('Battle values','Valores de combate'));
      fieldInput(g2,sl('EV Yield','EV otorgados'),'EVs');fieldInput(g2,sl('Base EXP','Exp. base'),'BaseExp','number');fieldInput(g2,sl('Catch Rate','Ratio de captura'),'CatchRate','number');fieldInput(g2,sl('Happiness','Felicidad'),'Happiness','number');
      inspectBody.append(g2);
    }
    else if(state.tab==='identity'){
      const g=group(sl('Typing and growth','Tipo y crecimiento'),sl('Forms automatically inherit empty fields from the base form','Las formas heredan automáticamente los campos vacíos de la forma base'));
      referenceListField(g,'Types','Types',state.types,{max:2,addLabel:'+ Añadir tipo'});
      fieldInput(g,sl('Gender Ratio','Ratio de género'),'GenderRatio');fieldInput(g,sl('Growth Rate','Ritmo de crecimiento'),'GrowthRate');
      inspectBody.append(g);
    }
    else if(state.tab==='abilities'){
      const g=group(sl('Abilities','Habilidades'),sl('An empty Abilities field inherits the base form abilities','Una forma con Abilities vacío usa las habilidades de la forma base'));
      referenceListField(g,'Abilities','Abilities',state.abilities,{addLabel:'+ Añadir ability'});
      referenceListField(g,'Hidden Abilities','HiddenAbilities',state.abilities,{addLabel:'+ Añadir hidden ability'});
      inspectBody.append(g);
    }
    else if(state.tab==='moves') renderMovesEditor(c);
    else if(state.tab==='evolution') renderEvoEditor(c);
    else {
      const g=group(sl('Other safe overrides','Otros datos'));
      fieldInput(g,sl('Egg Groups','Grupos Huevo'),'EggGroups');fieldInput(g,sl('Hatch Steps','Pasos de eclosión'),'HatchSteps','number');fieldInput(g,sl('Height','Altura'),'Height','number');fieldInput(g,sl('Weight','Peso'),'Weight','number');fieldInput(g,'Flags','Flags');
      inspectBody.append(g);
    }
  }

  function catalogName(catalog,id){
    const key=safeUpper(id);
    const hit=(Array.isArray(catalog)?catalog:[]).find(o=>safeUpper(typeof o==='string'?o:o?.id)===key);
    return typeof hit==='string'?'':String(hit?.name??'');
  }

  function renderMovesEditor(c){
    const levelCount=parseMoves(c.eff.Moves).length;
    const tutorCount=parseList(c.eff.TutorMoves).length;
    const eggCount=parseList(c.eff.EggMoves).length;

    const shell=el('div',{class:'cdx-moves-shell'});
    const nav=el('div',{class:'cdx-move-tabs'});
    const defs=[['level','Por nivel',levelCount],['tutor','Tutor',tutorCount],['egg','Egg',eggCount]];
    for(const [id,label,count] of defs){
      const b=el('button',{class:'cdx-move-tab'+(state.moveTab===id?' active':''),onClick:()=>{state.moveTab=id;renderInspector();}});
      b.append(el('span',{text:label}),el('b',{text:String(count)}));
      nav.append(b);
    }
    shell.append(nav);
    inspectBody.append(shell);

    if(state.moveTab==='tutor'){
      const g=group(sl('Tutor Moves','Movimientos tutor'),sl('Search by ID or name. Adding a row does not modify JSON until you choose/type a move.','Busca por ID o por nombre. Añadir una fila no modifica el JSON hasta elegir/escribir un movimiento.'));
      referenceListField(g,'Tutor Moves','TutorMoves',state.moves,{addLabel:'+ Añadir Tutor Move',highlightNewMoves:true});
      inspectBody.append(g);
      return;
    }
    if(state.moveTab==='egg'){
      const g=group(sl('Egg Moves','Movimientos huevo'),sl('Quick row editor; values come from the real PBS/moves*.txt catalog.','Editor rápido por filas; los valores vienen del catálogo real de PBS/moves*.txt.'));
      referenceListField(g,'Egg Moves','EggMoves',state.moves,{addLabel:'+ Añadir Egg Move',highlightNewMoves:true});
      inspectBody.append(g);
      return;
    }

    const g=group(sl('Level-up Moves','Movimientos por nivel'),sl('PBS Editor-style flow: add, search and confirm without losing the row.','Flujo estilo PBS Editor: añade, busca y confirma sin que la fila desaparezca.'));
    let rows=parseMoves(c.eff.Moves).map(r=>[String(r?.[0]??'1'),String(r?.[1]??'')]);
    const baseLevelRows=parseMoves(c.base.Moves).map(r=>[String(r?.[0]??'1'),safeUpper(r?.[1])]).filter(r=>r[1]);
    const levelPairKey=(lv,id)=>`${String(lv??'').trim()}:${safeUpper(id)}`;
    const baseLevelPairs=new Set(baseLevelRows.map(r=>levelPairKey(r[0],r[1])));
    const baseLevelsByMove=new Map();
    for(const [lv,id] of baseLevelRows){const a=baseLevelsByMove.get(id)||[];a.push(String(lv));baseLevelsByMove.set(id,a);}
    const top=el('div',{class:'cdx-move-toolbar'});
    const filter=el('input',{class:'cdx-search cdx-move-search',placeholder:'Filtrar learnset…',value:String(state.moveFilter||'')});
    filter.value=String(state.moveFilter||'');
    const add=el('button',{class:'cdx-btn primary small',text:'+ Move'});
    const sort=el('button',{class:'cdx-btn small',text:'Ordenar nivel'});
    top.append(filter,sort,add);g.append(top);
    const legend=el('div',{class:'cdx-origin-legend'});
    legend.append(provenanceBadge('CANON','canon','Move y nivel presentes exactamente en el PBS/canon.'),provenanceBadge('JSON','json','Asignación añadida por JSON.'),provenanceBadge('JSON NIVEL','level','El Move ya era canon, pero su nivel fue cambiado por JSON.'),provenanceBadge('JSON RETOCADO','retouched','El Move existe en canon pero sus datos/efecto están retocados globalmente.'),provenanceBadge('JSON NUEVO','new','Move nuevo inexistente en canon.'));
    g.append(legend);
    const holder=el('div',{class:'cdx-list-editor cdx-move-list'});g.append(holder);
    const diffBox=el('div',{class:'cdx-assignment-diff'});g.append(diffBox);

    function renderLevelDiff(){
      diffBox.innerHTML='';
      const currentRows=rows.map(r=>[String(r?.[0]??'1'),safeUpper(r?.[1])]).filter(r=>r[1]);
      const currentPairs=new Set(currentRows.map(r=>levelPairKey(r[0],r[1])));
      const currentLevelsByMove=new Map();
      for(const [lv,id] of currentRows){const a=currentLevelsByMove.get(id)||[];a.push(String(lv));currentLevelsByMove.set(id,a);}
      const moved=[],removed=[];
      for(const [lv,id] of baseLevelRows){
        if(currentPairs.has(levelPairKey(lv,id)))continue;
        const now=currentLevelsByMove.get(id)||[];
        if(now.length)moved.push({id,from:lv,to:now.join('/')});
        else removed.push({id,from:lv});
      }
      if(!moved.length&&!removed.length){diffBox.classList.add('empty');return;}
      diffBox.classList.remove('empty');
      diffBox.append(el('b',{text:'Diferencias de asignación · canon → JSON'}));
      const chips=el('div',{class:'cdx-assignment-diff-chips'});
      for(const x of moved)chips.append(el('span',{class:'cdx-assignment-diff-chip moved',text:`${catalogName(state.moves,x.id)||x.id}: Lv.${x.from} → Lv.${x.to}`,title:'Mismo Move canon, nivel modificado por JSON.'}));
      for(const x of removed)chips.append(el('span',{class:'cdx-assignment-diff-chip removed',text:`${catalogName(state.moves,x.id)||x.id} · Lv.${x.from} quitado`,title:'Asignación canon retirada por JSON.'}));
      diffBox.append(chips);
    }
    function commit(){
      applyField('Moves',movesToCsv(rows),{rerender:false});
      renderList();renderLevelDiff();
    }
    function visibleRow(r){
      const q=normalizeSearch(state.moveFilter||'');
      if(!q||!String(r?.[1]??'').trim())return true;
      const id=String(r?.[1]??'');
      return normalizeSearch(id+' '+catalogName(state.moves,id)+' '+String(r?.[0]??'')).includes(q);
    }
    function renderRows(focusIndex=-1){
      holder.innerHTML='';
      let shown=0;
      rows.forEach((r,i)=>{
        if(!visibleRow(r))return;
        shown++;
        const moveId=safeUpper(r?.[1]),isGlobalNew=!!moveId&&moveIsNew(moveId);
        const exactCanon=!!moveId&&baseLevelPairs.has(levelPairKey(r?.[0],moveId));
        const existedCanon=!!moveId&&baseLevelsByMove.has(moveId);
        const assignmentKind=exactCanon?'canon':(existedCanon?'level':'json');
        const isAdded=!!moveId&&!exactCanon;
        const row=el('div',{class:'cdx-move-row cdx-provenance-row'+(isGlobalNew?' new-global-move':'')+(isAdded?' added-move':''),dataset:{index:String(i)}});
        const drag=el('span',{class:'cdx-move-grip',text:'⋮⋮',title:'Orden visual'});
        const lvl=el('input',{class:'cdx-input cdx-level',type:'number',min:'0',max:'100',value:String(r?.[0]||'1')});
        lvl.value=String(r?.[0]||'1');
        const ref=createRefInput(
          r?.[1]||'',state.moves,
          (v)=>{rows[i][1]=String(v??'');},
          (v,meta)=>{
            rows[i][1]=safeUpper(v);
            if(rows[i][1]||meta?.chosen||meta?.enter)commit();
          },
          'Buscar Move ID o nombre…'
        );
        const md=state.moves.find(o=>safeUpper(o?.id)===safeUpper(r?.[1]))?.entry||{};const name=el('span',{class:'cdx-move-name'});
        const paintMoveName=(rawId,rawLevel=lvl.value)=>{
          const mid=safeUpper(rawId),mdata=state.moves.find(o=>safeUpper(o?.id)===mid)?.entry||{};
          name.innerHTML='';
          name.append(document.createTextNode(`${catalogName(state.moves,mid)||'—'} · ${mdata.Type||'—'} · ${mdata.Category||'—'} · Pwr ${mdata.Power||'—'} · Acc ${mdata.Accuracy||'—'}`));
          if(!mid)return;
          const exact=baseLevelPairs.has(levelPairKey(rawLevel,mid)),existed=baseLevelsByMove.has(mid);
          name.append(provenanceBadge(exact?'CANON':(existed?'JSON NIVEL':'JSON'),exact?'canon':(existed?'level':'json'),exact?'Asignación canon.':existed?`Canon en Lv.${(baseLevelsByMove.get(mid)||[]).join('/')}; este nivel viene del JSON.`:'Asignación añadida por JSON.'));
          const p=entityProvenance('moves',mid);
          if(p.kind!=='canon')name.append(provenanceBadge(p.label,p.kind,p.kind==='retouched'?'Los datos/efecto de este Move están retocados globalmente.':'Este Move no existe en el canon.'));
        };
        paintMoveName(r?.[1],r?.[0]);
        ref.input.addEventListener('input',()=>{paintMoveName(ref.input.value,lvl.value);});
        const x=el('button',{class:'cdx-x',text:'×',title:'Eliminar movimiento'});
        lvl.addEventListener('input',()=>{rows[i][0]=String(lvl.value||'1');paintMoveName(ref.input.value,lvl.value);});
        lvl.addEventListener('change',()=>{rows[i][0]=String(lvl.value||'1');paintMoveName(ref.input.value,lvl.value);commit();});
        x.onclick=()=>{rows.splice(i,1);commit();renderRows();};
        row.append(drag,el('span',{class:'cdx-level-prefix',text:'Lv.'}),lvl,ref.wrap,name,x);
        holder.append(row);
      });
      if(!shown)holder.append(el('div',{class:'cdx-empty compact',text:'No hay movimientos que coincidan con el filtro.'}));
      renderLevelDiff();
      if(focusIndex>=0){
        requestAnimationFrame(()=>holder.querySelector(`.cdx-move-row[data-index="${focusIndex}"] .cdx-ref-input`)?.focus());
      }
    }
    filter.oninput=()=>{state.moveFilter=String(filter.value||'');renderRows();};
    add.onclick=()=>{
      const idx=rows.length;rows.push(['1','']);
      state.moveFilter='';filter.value='';
      renderRows(idx);
    };
    sort.onclick=()=>{
      rows.sort((a,b)=>{
        const la=Number(a?.[0]??0)||0,lb=Number(b?.[0]??0)||0;
        if(la!==lb)return la-lb;
        return safeUpper(a?.[1]).localeCompare(safeUpper(b?.[1]));
      });
      commit();renderRows();
    };
    renderRows();
    if(c.fields.includes('Moves'))g.append(el('button',{class:'cdx-reset',text:'↶ Learnset canon/PBS',onClick:()=>applyField('Moves',c.base.Moves||'')}));
    inspectBody.append(g);
  }

  function renderEvoEditor(c){
    const g=group(sl('Evolutions','Evoluciones'),sl('Species + method + parameter · CANON vs JSON','Especie + método + parámetro · CANON vs JSON'));
    let rows=parseEvos(c.eff.Evolutions);
    const baseRows=parseEvos(c.base.Evolutions);
    const evoKey=(r)=>`${safeUpper(r?.[0])}|${String(r?.[1]??'').trim()}|${String(r?.[2]??'').trim()}`;
    const baseKeys=new Set(baseRows.map(evoKey));
    const holder=el('div',{class:'cdx-list-editor'});
    const diffBox=el('div',{class:'cdx-assignment-diff'});
    const speciesSuggestions=[...state.basesBySpecies.keys()].filter(v=>typeof v==='string'&&v).sort();
    function renderDiff(){
      diffBox.innerHTML='';
      const currentKeys=new Set(rows.map(evoKey));
      const removed=baseRows.filter(r=>!currentKeys.has(evoKey(r)));
      if(!removed.length){diffBox.classList.add('empty');return;}
      diffBox.classList.remove('empty');diffBox.append(el('b',{text:'Evoluciones canon quitadas/cambiadas por JSON'}));
      const chips=el('div',{class:'cdx-assignment-diff-chips'});
      for(const r of removed)chips.append(el('span',{class:'cdx-assignment-diff-chip removed',text:`${safeUpper(r?.[0])} · ${r?.[1]||'None'} · ${r?.[2]||'—'}`}));
      diffBox.append(chips);
    }
    function commit(){applyField('Evolutions',evosToCsv(rows),{rerender:false});renderDiff();}
    function finish(){renderList();}
    function renderRows(){
      holder.innerHTML='';
      rows.forEach((r,i)=>{
        const row=el('div',{class:'cdx-evo-row cdx-provenance-row'});
        const sp=createRefInput(r?.[0]||'',speciesSuggestions,(v)=>{rows[i][0]=safeUpper(v);commit();paintOrigin();},finish,'Especie…');
        const method=el('input',{class:'cdx-input',value:String(r?.[1]||'Level'),placeholder:'Método'});method.value=String(r?.[1]||'Level');
        const param=el('input',{class:'cdx-input',value:String(r?.[2]||''),placeholder:'Parámetro'});param.value=String(r?.[2]||'');
        const origin=el('span',{class:'cdx-origin-badges'});
        const paintOrigin=()=>{origin.innerHTML='';const canon=baseKeys.has(evoKey(rows[i]));origin.append(provenanceBadge(canon?'CANON':'JSON',canon?'canon':'json',canon?'Evolución idéntica al PBS/canon.':'Evolución añadida o modificada por JSON.'));};
        paintOrigin();
        const x=el('button',{class:'cdx-x',text:'×'});
        method.addEventListener('input',()=>{rows[i][1]=String(method.value||'None').trim();commit();paintOrigin();});
        param.addEventListener('input',()=>{rows[i][2]=String(param.value||'').trim();commit();paintOrigin();});
        method.addEventListener('blur',finish);param.addEventListener('blur',finish);
        x.onclick=()=>{rows.splice(i,1);commit();renderRows();finish();};
        row.append(sp.wrap,method,param,origin,x);holder.append(row);
      });
      holder.append(el('button',{class:'cdx-add',text:'+ Añadir evolución',onClick:()=>{rows.push(['','Level','']);renderRows();}}));
      renderDiff();
    }
    g.append(el('div',{class:'cdx-origin-legend compact'},[provenanceBadge('CANON','canon','Evolución idéntica al PBS/canon.'),provenanceBadge('JSON','json','Evolución añadida/modificada por JSON.')]));
    renderRows();g.append(holder,diffBox);
    if(c.fields.includes('Evolutions'))g.append(el('button',{class:'cdx-reset',text:'↶ Evoluciones canon/PBS',onClick:()=>applyField('Evolutions',c.base.Evolutions||'')}));
    inspectBody.append(g);
    const g2=group(sl('Breeding','Crianza'));fieldInput(g2,sl('Egg Groups','Grupos Huevo'),'EggGroups');fieldInput(g2,sl('Hatch Steps','Pasos de eclosión'),'HatchSteps','number');inspectBody.append(g2);
  }

  async function save(){
    state.doc.updatedAt=new Date().toISOString();
    const text=JSON.stringify(state.doc,null,2)+'\n';
    try {
      await ctx.fs.projectMkdir?.('Data/ChangeDex');
      try{
        const previous=await read(JSON_PATH);
        if(String(previous||'').trim()){
          await ctx.fs.projectMkdir?.('Data/ChangeDex/backups');
          const stamp=new Date().toISOString().replace(/[:.]/g,'-');
          await writeProjectTextRobust(`Data/ChangeDex/backups/pokemon_changes_${stamp}.json`,previous,{attempts:2,directFallback:true});
        }
      }catch{}
      const result=await writeProjectTextRobust(JSON_PATH,text,{attempts:6,directFallback:true});
      setDirty(false);
      toast(result.mode==='direct'?'Cambios guardados usando el escritor directo de Maker Studio.':'Cambios guardados. Se conserva una copia anterior en Data/ChangeDex/backups.','info');
    } catch(e){
      try{
        await writeProjectTextRobust(RECOVERY_PATH,text,{attempts:4,directFallback:true});
        setDirty(false);
        toast('pokemon_changes.json está bloqueado por Windows/OneDrive. Guardé pokemon_changes.recovery.json; ChangeDex v0.11.21 lo usa automáticamente mientras sea la copia más reciente.','warning');
      }catch(recoveryError){
        setDirty(true);
        toast('No se pudo guardar ni el JSON principal ni la recuperación: '+String(recoveryError?.message||recoveryError||e),'error');
      }
    }
  }

  async function cleanRedundant(){
    let n=0;
    for(const [h,fields] of Object.entries({...state.doc.species})){
      const source=state.byHeader.get(h);if(!source)continue;
      const baseline=resolvePbsEntry(source,state.basesBySpecies)||source;
      for(const [f,v] of Object.entries({...fields})){
        const before=String(baseline?.[f]??'').split(',').map(x=>x.trim()).filter(Boolean).join(',');
        const after=String(v??'').split(',').map(x=>x.trim()).filter(Boolean).join(',');
        if(before===after){delete fields[f];n++;}
      }
      if(!Object.keys(fields).length)delete state.doc.species[h];
    }
    for(const [bucket,map,baseMap] of [['moves',state.doc.moves,state.baselineMoves],['abilities',state.doc.abilities,state.baselineAbilities]]){
      for(const [id,fields] of Object.entries({...map||{}})){
        const base=baseMap.get(id)||{},isNew=fields?._new===true||!baseMap.has(id);
        const originalFunctional=Object.keys(fields||{}).filter(f=>!f.startsWith('_')&&!['Name','Description'].includes(f));
        for(const [f,v] of Object.entries({...fields})){
          if(f.startsWith('_')||isNew)continue;
          if(['Name','Description'].includes(f))continue;
          if(sameField(v,base?.[f]??'')){delete fields[f];n++;}
        }
        if(bucket==='moves'&&!isNew&&originalFunctional.length){
          const remainingFunctional=Object.keys(fields||{}).filter(f=>!f.startsWith('_')&&!['Name','Description'].includes(f));
          const explicit=fields?._behaviorChanged===true||String(fields?._behaviorChanged||'').toLowerCase()==='true';
          if(!remainingFunctional.length&&!explicit){
            for(const f of ['_beforeText','_afterText','_notes'])if(Object.prototype.hasOwnProperty.call(fields,f)){delete fields[f];n++;}
          }
        }
        if(!Object.keys(fields).length)delete state.doc[bucket][id];
      }
    }
    if(n){setDirty();renderList();renderSelection();}
    toast(`${n} cambio(s) innecesarios eliminados.`,'info');
  }

  async function readExternalText(path){
    const invoke=window.__TAURI__?.core?.invoke;
    if(!invoke)throw new Error('El selector externo no está disponible en este Maker Studio.');
    return await invoke('read_text_file',{path});
  }

  function importMigrationDocument(raw,label='migration'){
    const doc=normalizeDoc(raw);
    let speciesCount=0,fieldCount=0,unknownSpecies=0,unknownFields=0;
    for(const [header,fields] of Object.entries(doc.species||{})){
      if(!state.byHeader.has(header)){unknownSpecies++;continue;}
      if(!fields||typeof fields!=='object'||Array.isArray(fields))continue;
      let used=false;
      for(const [field,value] of Object.entries(fields)){
        if(!CHANGE_FIELDS.includes(field)){unknownFields++;continue;}
        (state.doc.species[header] ||= {})[field]=String(value??'').trim();
        fieldCount++;used=true;
      }
      if(used)speciesCount++;
    }
    for(const bucket of ['moves','abilities']){
      const baseline=bucket==='moves'?state.baselineMoves:state.baselineAbilities;
      for(const [rawId,fields] of Object.entries(doc[bucket]||{})){
        const id=safeUpper(rawId);if(!id||!fields||typeof fields!=='object')continue;
        const base=baseline.get(id)||{},isNew=fields._new===true || !baseline.has(id),target={};
        const sourceFunctional=Object.keys(fields).filter(f=>!f.startsWith('_')&&!['Name','Description'].includes(f));
        for(const [field,value] of Object.entries(fields)){
          if(field.startsWith('_'))continue;
          if(!isNew&&['Name','Description'].includes(field))continue;
          if(!isNew&&!['Name','Description'].includes(field)&&sameField(value,base?.[field]??''))continue;
          target[field]=value;
        }
        const realFunctional=Object.keys(target).filter(f=>!f.startsWith('_')&&!['Name','Description'].includes(f));
        const explicitBehavior=fields?._behaviorChanged===true||String(fields?._behaviorChanged||'').toLowerCase()==='true';
        const behaviorOnly=!sourceFunctional.length&&['_beforeText','_afterText','_notes'].some(f=>String(fields?.[f]||'').trim());
        if(isNew||realFunctional.length||explicitBehavior||behaviorOnly){
          for(const [field,value] of Object.entries(fields))if(field.startsWith('_'))target[field]=value;
          if(explicitBehavior)target._behaviorChanged=true;
          state.doc[bucket][id]={...(state.doc[bucket][id]||{}),...target};
        }
      }
    }
    state.doc.migratedFrom=String(label||'migration');
    syncJsonEntityCatalogs();
    setDirty();renderList();renderSelection();
    toast(`Migración importada: ${speciesCount} Pokémon/formas · ${fieldCount} campos${unknownSpecies?` · ${unknownSpecies} especies no encontradas`:''}${unknownFields?` · ${unknownFields} campos ignorados`:''}.`,'info');
  }

  async function importBuiltinMigration(){
    try{const text=await ctx.fs.readModFile(BUILTIN_MIGRATION);importMigrationDocument(JSON.parse(text),'Vermeil First Branch · legacy');}
    catch(e){toast('No se pudo importar la migración incluida: '+String(e?.message||e),'error');}
  }

  async function importFirstBranchVsBase(){
    try{
      const text=await ctx.fs.readModFile(FIRST_BRANCH_MIGRATION);
      const raw=JSON.parse(text);
      importMigrationDocument(raw,'First Branch vs PBS Base');
      state.doc.migrationStats=raw?.stats||{};
      state.doc.migrationBaseline=String(raw?.baseline||'PBS Base');
      state.doc.migrationSource=String(raw?.source||'PBS First Branch');
      setListMode('changed');
      if(!state.doc.species?.[state.selected]){
        const first=filtered()[0];
        if(first){state.selected=String(first._header||'');state.ensureSelectionVisible=true;renderList();renderSelection();}
      }
      const stats=raw?.stats||{};
      toast(`First Branch cargada contra PBS Base: ${Number(stats.changedEntries||0)} especies/formas · ${Number(stats.changedMoves||0)} Moves · ${Number(stats.changedAbilities||0)} Habilidades.`, 'info');
    }catch(e){toast('No se pudo importar First Branch vs PBS Base: '+String(e?.message||e),'error');}
  }

  async function importExternalMigration(){
    try{
      const picked=await ctx.ui.showFilePicker?.({multiple:false,directory:false,filters:[{name:'ChangeDex migration JSON',extensions:['json']}]});
      const path=normalizePickerPath(picked);if(!path)return;
      const text=await readExternalText(path);
      importMigrationDocument(JSON.parse(text),String(path).split(/[\\/]/).pop()||'migration.json');
    }catch(e){toast('No se pudo importar la migración: '+String(e?.message||e),'error');}
  }

  function openMigrationDialog(){
    if(!ctx.ui?.showCustomDialog){importExternalMigration();return;}
    let dialog=null;
    dialog=ctx.ui.showCustomDialog({
      title:'Importar cambios ChangeDex',width:'650px',height:'470px',
      render:(body)=>{
        body.innerHTML='';
        const wrap=el('div',{class:'cdx-migration-dialog'});
        wrap.append(
          el('h2',{text:'Importar / reconstruir cambios'}),
          el('p',{text:'El PBS del proyecto sigue siendo la base. Al importar, sólo se añaden overrides al JSON; no se modifica ningún PBS.'}),
          el('button',{class:'cdx-migration-option featured',onClick:()=>{dialog?.close?.();importFirstBranchVsBase();}},[
            el('b',{text:'First Branch → comparada con PBS Base'}),
            el('small',{text:'Preset generado de los dos PBS que adjuntaste. Compara datos efectivos de formas, ignora reordenamientos sin cambio real y aplica el resultado como JSON.'}),
            el('span',{class:'cdx-migration-stats',text:'Pokémon + Moves + Habilidades'})
          ]),
          el('button',{class:'cdx-migration-option',onClick:()=>{dialog?.close?.();importExternalMigration();}},[
            el('b',{text:'Elegir migration JSON…'}),el('small',{text:'Importa cualquier JSON de migración ChangeDex desde el disco.'})
          ]),
          el('button',{class:'cdx-migration-option',onClick:()=>{dialog?.close?.();importBuiltinMigration();}},[
            el('b',{text:'Migración legacy · PBS Changes antiguo'}),el('small',{text:'Conserva el preset pequeño generado del PBS Changes usado en la primera versión.'})
          ])
        );
        body.append(wrap);
      }
    });
  }


  function syncJsonEntityCatalogs(){
    for(const [bucket,list] of [['moves',state.moves],['abilities',state.abilities]]){
      const map=state.doc?.[bucket]||{};
      for(const [rawId,fields] of Object.entries(map)){
        const id=safeUpper(rawId);if(!id)continue;
        let item=list.find(x=>safeUpper(x?.id)===id);
        if(!item){item={id,name:String(fields?.Name||id),entry:{...(fields||{})}};list.push(item);}
        else if(fields&&typeof fields==='object'&&!Array.isArray(fields)){
          if(fields.Name)item.name=String(fields.Name);
          item.entry={...(item.entry||{}),...fields};
        }
      }
    }
  }

  function entityCatalog(bucket){
    const src=bucket==='moves'?state.moves:state.abilities;
    const out=[...src],seen=new Set(src.map(x=>safeUpper(x?.id)));
    for(const [id,fields] of Object.entries(state.doc[bucket]||{})){
      const key=safeUpper(id);if(!key||seen.has(key))continue;
      out.push({id:key,name:String(fields?.Name||key),entry:{...fields}});seen.add(key);
    }
    return out;
  }
  function entityBaseline(bucket,id){return (bucket==='moves'?state.baselineMoves:state.baselineAbilities).get(safeUpper(id))||{};}
  function entityIsNew(bucket,id){const key=safeUpper(id);const row=state.doc?.[bucket]?.[key]||{};const baseline=bucket==='moves'?state.baselineMoves:state.baselineAbilities;return !!key && (row._new===true || !baseline.has(key));}
  function moveIsNew(id){return entityIsNew('moves',id);}
  function entityCurrent(bucket,id){const base=entityBaseline(bucket,id);const project=(entityCatalog(bucket).find(x=>safeUpper(x.id)===safeUpper(id))?.entry)||{};return {...base,...project,...(state.doc[bucket]?.[safeUpper(id)]||{})};}
  function restoreEntityOverride(bucket,id){
    const key=safeUpper(id);if(!key)return false;
    const had=!!state.doc?.[bucket]?.[key];
    if(had)delete state.doc[bucket][key];
    const projectIds=bucket==='moves'?state.projectMoveIds:state.projectAbilityIds;
    const list=bucket==='moves'?state.moves:state.abilities;
    if(!projectIds?.has(key)){const idx=list.findIndex(x=>safeUpper(x?.id)===key);if(idx>=0)list.splice(idx,1);}
    return had;
  }
  function openEntityManager(){
    if(!ctx.ui?.showCustomDialog){toast('Este Maker Studio no expone el diálogo necesario.','error');return;}
    let bucket='moves',selectedId='',q='',manage=false,filterMode='all',sortMode='name';const selectedMany=new Set();let dialog=null;
    dialog=ctx.ui.showCustomDialog({title:'Cambios globales · Moves y Habilidades',width:'980px',height:'720px',render:(body)=>{
      const render=()=>{
        body.innerHTML='';const shell=el('div',{class:'cdx-entity-manager'});
        shell.append(el('div',{class:'cdx-dialog-head'},[el('div',{},[el('h2',{text:'Editor global de Moves / Habilidades'}),el('p',{text:'Compara el canon/baseline contra pokemon_changes.json. CANON = intacto; JSON RETOCADO = existe en canon pero lo modificaste; JSON NUEVO = no existe en canon.'})])]));
        const provLegend=el('div',{class:'cdx-origin-legend entity-manager'});
        provLegend.append(provenanceBadge('CANON','canon','Sin override funcional en JSON.'),provenanceBadge('JSON RETOCADO','retouched','Existe en canon y tiene cambios funcionales en JSON.'),provenanceBadge('JSON NUEVO','new','No existe en canon/baseline.'));
        shell.append(provLegend);
        const top=el('div',{class:'cdx-entity-top'});const tabs2=el('div',{class:'cdx-entity-tabs'});
        for(const [b,l] of [['moves','Movimientos'],['abilities','Habilidades']])tabs2.append(el('button',{class:'cdx-btn '+(bucket===b?'primary':''),text:l,onClick:()=>{bucket=b;selectedId='';selectedMany.clear();render();}}));
        const newEntity=el('button',{class:'cdx-btn cdx-btn-soft',text:bucket==='moves'?'+ Nuevo Move':'+ Nueva Habilidad',onClick:async()=>{
          const raw=await askText(bucket==='moves'?'ID del nuevo Move (ej. MYNEWMOVE)':'ID de la nueva Habilidad (ej. MYABILITY)',{title:bucket==='moves'?'Nuevo Move':'Nueva Habilidad',placeholder:bucket==='moves'?'MYNEWMOVE':'MYABILITY',confirmText:'Crear'});
          const id=safeUpper(raw);if(!id)return;
          if(!/^[A-Z0-9_]+$/.test(id)){toast('Usa un ID con A-Z, 0-9 y _.','error');return;}
          const exists=entityCatalog(bucket).some(x=>safeUpper(x?.id)===id)||(bucket==='moves'?state.baselineMoves:state.baselineAbilities).has(id);if(exists){toast('Ese ID ya existe.','error');return;}
          pushUndo();
          if(bucket==='moves')state.doc.moves[id]={_new:true,Name:id,Type:'NORMAL',Category:'Status',Power:'0',Accuracy:'100',TotalPP:'5',Target:'NearOther',Priority:'0',FunctionCode:'None',EffectChance:'0',Flags:'',Description:''};
          else state.doc.abilities[id]={_new:true,Name:id,Description:'',Flags:''};
          selectedId=id;syncJsonEntityCatalogs();setDirty();render();
        }});
        const manageBtn2=el('button',{class:'cdx-btn cdx-btn-soft'+(manage?' active':''),text:manage?`☑ Gestionar (${selectedMany.size})`:'☑ Gestionar',onClick:()=>{manage=!manage;if(!manage)selectedMany.clear();render();}});
        const hideMany=el('button',{class:'cdx-btn cdx-btn-soft',text:'🙈 Ocultar seleccionados',style:manage?'':'display:none',onClick:async()=>{if(!selectedMany.size){toast('Selecciona elementos.','warning');return;}await setHiddenEntities(bucket,[...selectedMany],true);toast(`${selectedMany.size} ocultados en ChangeDex.`,'info');render();}});
        const showMany=el('button',{class:'cdx-btn cdx-btn-soft',text:'👁 Mostrar seleccionados',style:manage?'':'display:none',onClick:async()=>{if(!selectedMany.size){toast('Selecciona elementos.','warning');return;}await setHiddenEntities(bucket,[...selectedMany],false);toast(`${selectedMany.size} visibles en ChangeDex.`,'info');render();}});
        const restoreMany=el('button',{class:'cdx-btn danger',text:'↶ Quitar cambios seleccionados',style:manage?'':'display:none',onClick:()=>{if(!selectedMany.size){toast('Selecciona elementos.','warning');return;}pushUndo();let n=0;for(const id of [...selectedMany])if(restoreEntityOverride(bucket,id))n++;selectedMany.clear();setDirty();render();toast(`${n} ${bucket==='moves'?'Move(s)':'Habilidad(es)'} quitados del JSON de cambios. El PBS no se toca.`,'info');}});
        const filterSel=el('select',{class:'cdx-mini-select',title:'Filtrar catálogo'});[['all','Todos'],['canon','Sólo CANON'],['retouched','JSON retocados'],['changed','Con cambios JSON'],['new','JSON nuevos / importados'],['duplicates','Nombres repetidos'],['existing','Existentes (canon + retocados)'],['hidden','Ocultos en ChangeDex']].forEach(([v,l])=>filterSel.append(el('option',{value:v,text:l})));filterSel.value=filterMode;filterSel.onchange=()=>{filterMode=filterSel.value;selectedId='';render();};
        const sortSel=el('select',{class:'cdx-mini-select',title:'Orden'});[['name','Nombre A-Z'],['id','ID A-Z'],['changes','Más cambios']].forEach(([v,l])=>sortSel.append(el('option',{value:v,text:l})));sortSel.value=sortMode;sortSel.onchange=()=>{sortMode=sortSel.value;render();};
        const sq=el('input',{class:'cdx-search',placeholder:`Buscar ${bucket==='moves'?'movimiento':'habilidad'}…`,value:q});sq.value=q;sq.oninput=()=>{q=sq.value;render();requestAnimationFrame(()=>{try{const next=body.querySelector('.cdx-search');if(next){next.focus({preventScroll:true});const n=next.value.length;next.setSelectionRange(n,n);}}catch{}});};top.append(tabs2,newEntity,manageBtn2,hideMany,showMany,restoreMany,filterSel,sortSel,sq);shell.append(top);
        const main2=el('div',{class:'cdx-entity-grid'}),left=el('div',{class:'cdx-entity-list'}),right=el('div',{class:'cdx-entity-editor'});
        const hiddenSetFilter=hiddenEntitySet(bucket);
        const fullEntityCatalog=entityCatalog(bucket);const duplicateNames=new Map();for(const x of fullEntityCatalog){const k=normalizeSearch(x?.name||'').trim();if(k)duplicateNames.set(k,(duplicateNames.get(k)||0)+1);}
        let cat=fullEntityCatalog.filter(x=>{const id=safeUpper(x.id),row=state.doc?.[bucket]?.[id]||{},changed=functionalEntityFields(bucket,id).length>0,isNew=row._new===true || !(bucket==='moves'?state.baselineMoves:state.baselineAbilities).has(id),hasCanon=(bucket==='moves'?state.baselineMoves:state.baselineAbilities).has(id),hidden=hiddenSetFilter.has(id),dup=(duplicateNames.get(normalizeSearch(x?.name||'').trim())||0)>1;if(filterMode==='canon'&&(!hasCanon||changed||isNew))return false;if(filterMode==='retouched'&&(!hasCanon||!changed||isNew))return false;if(filterMode==='changed'&&!changed)return false;if(filterMode==='new'&&!isNew)return false;if(filterMode==='duplicates'&&!dup)return false;if(filterMode==='existing'&&isNew)return false;if(filterMode==='hidden'&&!hidden)return false;return normalizeSearch(`${x.id} ${x.name}`).includes(normalizeSearch(q));});
        if(sortMode==='id')cat.sort((a,b)=>safeUpper(a.id).localeCompare(safeUpper(b.id)));else if(sortMode==='changes')cat.sort((a,b)=>functionalEntityFields(bucket,safeUpper(b.id)).length-functionalEntityFields(bucket,safeUpper(a.id)).length||String(a.name||a.id).localeCompare(String(b.name||b.id)));else cat.sort((a,b)=>String(a.name||a.id).localeCompare(String(b.name||b.id)));
        cat=cat.slice(0,900);
        const hiddenSetNow=hiddenEntitySet(bucket);
        for(const item of cat){const id=safeUpper(item.id),count=functionalEntityFields(bucket,id).length,isHidden=hiddenSetNow.has(id),isSel=selectedMany.has(id),prov=entityProvenance(bucket,id),isNew=prov.kind==='new';const children=[];if(manage)children.push(el('span',{class:'cdx-manage-check',text:isSel?'☑':'☐'}));const title=el('div',{class:'cdx-entity-titleline'});title.append(el('b',{text:item.name||id}),provenanceBadge(prov.label,prov.kind));children.push(title,el('small',{text:`${id}${count?` · ${count} cambio(s) JSON`:''}${isHidden?' · oculto':''}`}));left.append(el('button',{class:'cdx-entity-row'+(id===selectedId?' active':'')+(count?' changed':'')+(isNew?' new-entity':'')+(prov.kind==='retouched'?' retouched-entity':'')+(isHidden?' hidden-in-dex':'')+(isSel?' multi-selected':''),onClick:()=>{if(manage){isSel?selectedMany.delete(id):selectedMany.add(id);}else selectedId=id;render();}},children));}
        if(!selectedId&&cat[0])selectedId=safeUpper(cat[0].id);
        if(selectedId){
          const base=entityBaseline(bucket,selectedId),cur=entityCurrent(bucket,selectedId),changed=functionalEntityFields(bucket,selectedId);
          const item=entityCatalog(bucket).find(x=>safeUpper(x.id)===selectedId),hiddenNow=hiddenEntitySet(bucket).has(selectedId),prov=entityProvenance(bucket,selectedId);right.append(el('div',{class:'cdx-entity-head'},[el('div',{},[el('h2',{text:item?.name||selectedId}),el('div',{class:'cdx-entity-idline'},[el('code',{text:selectedId}),provenanceBadge(prov.label,prov.kind)])]),el('div',{class:'cdx-entity-head-actions'},[el('span',{class:'cdx-count accent',text:`${changed.length} cambios JSON`}),el('button',{class:'cdx-btn cdx-btn-soft'+(hiddenNow?' active':''),text:hiddenNow?'👁 Mostrar en ChangeDex':'🙈 Ocultar en ChangeDex',onClick:async()=>{await setHiddenEntities(bucket,[selectedId],!hiddenNow);render();}})])]));
          right.append(el('div',{class:`cdx-provenance-banner ${prov.kind}`,text:prov.kind==='canon'?'Esta ficha coincide con el CANON. No hay override funcional en pokemon_changes.json.':prov.kind==='retouched'?'Esta ficha existe en CANON, pero el resultado actual incluye tus retoques guardados en pokemon_changes.json.':'Esta ficha no existe en CANON: es contenido nuevo/importado desde pokemon_changes.json.'}));
          const meta=state.doc[bucket]?.[selectedId]||{};
          const isNewEntity=meta._new===true || !(bucket==='moves'?state.baselineMoves:state.baselineAbilities).has(selectedId);
          const fields=bucket==='moves'?(isNewEntity?['Name','Type','Category','Power','Accuracy','TotalPP','Target','Priority','FunctionCode','EffectChance','Flags','Description']:['Type','Category','Power','Accuracy','TotalPP','Target','Priority','FunctionCode','EffectChance','Flags']):(isNewEntity?['Name','Description','Flags']:['Flags']);
          if(!isNewEntity)right.append(el('div',{class:'cdx-config-note',text:'Name/Description ya no son cambios de balance. Edítalos desde Translate Studio, que vive separado de ChangeDex.'}));
          for(const fld of fields){const row=el('div',{class:'cdx-entity-field'+(changed.includes(fld)?' changed':'')});row.append(el('div',{class:'cdx-entity-label'},[el('b',{text:fld}),el('small',{text:`Canon: ${String(base[fld]??'—')}`})]));const input=fld==='Description'?el('textarea',{class:'cdx-input cdx-textarea'}):el('input',{class:'cdx-input'});input.value=String(cur[fld]??'');input.onchange=()=>{pushUndo();setEntityOverride(state.doc,bucket,selectedId,fld,input.value,base);setDirty();render();};row.append(input);right.append(row);}
          const notes=el('div',{class:'cdx-entity-notes'});notes.append(el('h3',{text:'Cambio de comportamiento / efecto'}),el('p',{text:'Úsalo cuando el cambio vive en scripts y no se puede expresar sólo con el PBS. ChangeDex ingame lo mostrará aunque ningún Pokémon nuevo gane esta Move/Habilidad.'}));
          for(const [fld,label] of [['_beforeText','Texto original'],['_afterText','Texto actual'],['_notes','Notas del cambio']]){const ta=el('textarea',{class:'cdx-input cdx-textarea',placeholder:label});ta.value=String(meta[fld]||'');ta.onchange=()=>{pushUndo();const v=String(ta.value||'').trim();if(v){(state.doc[bucket][selectedId] ||= {})[fld]=v;if(bucket==='moves')state.doc[bucket][selectedId]._behaviorChanged=true;}else if(state.doc[bucket]?.[selectedId]){delete state.doc[bucket][selectedId][fld];if(bucket==='moves'&&!['_beforeText','_afterText','_notes'].some(k=>String(state.doc[bucket][selectedId]?.[k]||'').trim()))delete state.doc[bucket][selectedId]._behaviorChanged;}setDirty();render();};notes.append(el('label',{text:label}),ta);}right.append(notes);
          if(state.doc?.[bucket]?.[selectedId])right.append(el('button',{class:'cdx-btn danger',text:isNewEntity?'Eliminar del JSON de cambios':'Restaurar Move/Habilidad original',onClick:()=>{pushUndo();restoreEntityOverride(bucket,selectedId);selectedId='';setDirty();render();}}));
        }
        main2.append(left,right);shell.append(main2);body.append(shell);
      };render();
    }});
  }


  function openConfigDialog(){
    if(!ctx.ui?.showCustomDialog)return;let dialog=null;dialog=ctx.ui.showCustomDialog({title:'Configurar ChangeDex ingame',width:'760px',height:'720px',render:(body)=>{
      body.innerHTML='';const g=el('div',{class:'cdx-config'});g.append(el('h2',{text:'Apariencia y juego resultante'}),el('p',{text:'Estos ajustes pertenecen al proyecto. Actualizar ChangeDex Studio/runtime no reemplaza Data/ChangeDex/config.json ni tus gráficos Custom.'}));
      const screenMode=el('select',{class:'cdx-input'});[['auto','Adaptarse a Graphics.width / Graphics.height'],['custom','Tamaño personalizado']].forEach(([v,l])=>screenMode.append(el('option',{value:v,text:l})));screenMode.value=state.config.screenMode||'auto';
      const uiMode=el('select',{class:'cdx-input'});[['code','UI por código · limpia y dinámica'],['custom','UI Custom · diseño gráfico alternativo']].forEach(([v,l])=>uiMode.append(el('option',{value:v,text:l})));uiMode.value=state.config.uiMode||'code';
      const width=el('input',{class:'cdx-input',type:'number',min:'320',value:String(state.config.width||640)}),height=el('input',{class:'cdx-input',type:'number',min:'240',value:String(state.config.height||480)}),icon=el('input',{class:'cdx-input',type:'number',min:'32',max:'128',value:String(state.config.iconSize||84)}),game=el('input',{class:'cdx-input',placeholder:'Vacío = Settings::GAME_NAME',value:String(state.config.gameName||'')}),specialKey=el('input',{class:'cdx-input',placeholder:'Vacío = detectar automáticamente / fallback D',value:String(state.config.specialKeyLabel||'')});
      const hiddenForms=el('textarea',{class:'cdx-input cdx-textarea',placeholder:'Una forma por línea, ej.\nRAICHU,1\nMAROWAK,1'});hiddenForms.value=(Array.isArray(state.config.hiddenForms)?state.config.hiddenForms:[]).join('\n');
      const hiddenMoves=el('textarea',{class:'cdx-input cdx-textarea',placeholder:'Un Move por línea, ej.\nSTALKCUTTER'});hiddenMoves.value=(Array.isArray(state.config.hiddenMoves)?state.config.hiddenMoves:[]).join('\n');
      const hiddenAbilities=el('textarea',{class:'cdx-input cdx-textarea',placeholder:'Una Habilidad por línea, ej.\nBLAZINGVANGUARD'});hiddenAbilities.value=(Array.isArray(state.config.hiddenAbilities)?state.config.hiddenAbilities:[]).join('\n');
      const quietLogs=el('input',{type:'checkbox'});quietLogs.checked=state.config.suppressPbsChangesLogs!==false;
      const allPbsMode=el('input',{type:'checkbox'});allPbsMode.checked=state.config.allPbsModeButton===true;
      const row=(l,x)=>{const r=el('label',{class:'cdx-config-row'});r.append(el('span',{text:l}),x);return r;};
      g.append(row('Tamaño de pantalla',screenMode),row('Ancho personalizado',width),row('Alto personalizado',height),row('Iconos ingame',icon),row('Nombre mostrado del juego',game),row('Estilo de UI',uiMode),row('Formas ocultas en ChangeDex',hiddenForms),row('Moves ocultos en ChangeDex',hiddenMoves),row('Habilidades ocultas en ChangeDex',hiddenAbilities),row('Etiqueta de la tecla Special',specialKey),row('Ocultar mensajes de progreso PBS Changes',quietLogs),row('Botón "Modo: Todas las especies" ingame (opción dev)',allPbsMode));
      g.append(el('div',{class:'cdx-config-note',text:'La UI Custom ya no replica la UI por código: usa un layout gráfico más limpio y sólo dibuja tarjetas donde existe contenido. Sus PNG viven en Graphics/UI/ChangeDex/ y nunca se reemplazan si ya los editaste.'}));
      const sectionDefaults={es:{pokemon_changes:'Stats · tipos · habilidades · movimientos · evoluciones',move_changes:'Datos del movimiento · efectos · usuarios añadidos/retirados',ability_changes:'Datos de la habilidad · reworks · usuarios añadidos/retirados',new_moves:'Movimientos que no existen en el balance original',new_abilities:'Habilidades que no existen en el balance original'},en:{pokemon_changes:'Stats · types · abilities · learnsets · evolutions',move_changes:'Move data · effects · added/removed users',ability_changes:'Ability data · reworks · added/removed users',new_moves:'Moves that do not exist in the original balance',new_abilities:'Abilities that do not exist in the original balance'}};
      const sectionInputs={es:{},en:{}};const sectionWrap=el('div',{class:'cdx-section-copy-editor'});
      for(const [lang,label] of [['es','Español'],['en','English']]){const col=el('div',{class:'cdx-section-copy-col'});col.append(el('h4',{text:label}));for(const [key,title] of [['pokemon_changes','Pokémon Changes'],['move_changes','Move Changes'],['ability_changes','Ability Changes'],['new_moves','New Moves'],['new_abilities','New Abilities']]){const ta=el('textarea',{class:'cdx-input cdx-section-copy',placeholder:sectionDefaults[lang][key]});ta.value=String(state.config.sectionDescriptions?.[lang]?.[key]||sectionDefaults[lang][key]);sectionInputs[lang][key]=ta;const box=el('label',{class:'cdx-section-copy-item'});box.append(el('span',{text:title}),ta);col.append(box);}sectionWrap.append(col);}g.append(el('h3',{class:'cdx-config-heading',text:'Descripciones de las secciones ingame · ES / EN'}),sectionWrap);
      const defaults={colorBackground:'#141923',colorGridFill:'#1e2634',colorGridEdge:'#38465c',colorPanelFill:'#1c2432',colorPanelEdge:'#3e4e68',colorHighlight:'#dc3c3c',colorText:'#f5f5f5',colorMuted:'#b4b4b4',colorOriginal:'#50b4ff',colorResult:'#ff6464',colorDifference:'#ffd700',colorNew:'#64ff78'};
      const labels={colorBackground:'Fondo',colorGridFill:'Celdas',colorGridEdge:'Borde de celdas',colorPanelFill:'Paneles',colorPanelEdge:'Borde de paneles',colorHighlight:'Acento',colorText:'Texto principal',colorMuted:'Texto secundario',colorOriginal:'Balance original',colorResult:'Juego resultante',colorDifference:'Diferencias',colorNew:'Contenido nuevo'};
      const colorWrap=el('div',{class:'cdx-color-grid'}),colorInputs={};
      for(const [key,def] of Object.entries(defaults)){const input=el('input',{type:'color',class:'cdx-color-input',value:String(state.config[key]||def)});colorInputs[key]=input;const item=el('label',{class:'cdx-color-item'});item.append(el('span',{text:labels[key]}),input,el('code',{text:String(state.config[key]||def)}));input.oninput=()=>item.querySelector('code').textContent=input.value;colorWrap.append(item);}
      g.append(el('h3',{class:'cdx-config-heading',text:'Colores · UI por código + textos/acentos compartidos'}),colorWrap);
      const actions=el('div',{class:'cdx-config-actions'});const reset=el('button',{class:'cdx-btn cdx-btn-soft',text:'Restaurar colores default'});reset.onclick=()=>{for(const [k,v] of Object.entries(defaults)){colorInputs[k].value=v;colorInputs[k].dispatchEvent(new Event('input'));}};
      const resetUi=el('button',{class:'cdx-btn cdx-btn-soft',text:'Restaurar ajustes UI'});resetUi.onclick=()=>{screenMode.value='auto';uiMode.value='code';width.value='640';height.value='480';icon.value='84';game.value='';specialKey.value='';allPbsMode.checked=false;};
      const saveCfg=el('button',{class:'cdx-btn primary',text:'Guardar configuración'});saveCfg.onclick=async()=>{const colors={};for(const [k,input] of Object.entries(colorInputs))colors[k]=String(input.value||defaults[k]);const sectionDescriptions={es:{},en:{}};for(const lang of ['es','en'])for(const key of Object.keys(sectionInputs[lang]))sectionDescriptions[lang][key]=String(sectionInputs[lang][key].value||sectionDefaults[lang][key]).trim();const hiddenFormList=String(hiddenForms.value||'').split(/\r?\n|;/).map(v=>String(v||'').trim().toUpperCase()).filter(v=>/^[A-Z0-9_]+,\d+$/.test(v));const hiddenMoveList=String(hiddenMoves.value||'').split(/\r?\n|;/).map(v=>safeUpper(v)).filter(v=>/^[A-Z0-9_]+$/.test(v));const hiddenAbilityList=String(hiddenAbilities.value||'').split(/\r?\n|;/).map(v=>safeUpper(v)).filter(v=>/^[A-Z0-9_]+$/.test(v));state.config={...state.config,...colors,screenMode:screenMode.value,width:Number(width.value)||640,height:Number(height.value)||480,iconSize:Number(icon.value)||84,gameName:String(game.value||'').trim(),uiMode:uiMode.value,hiddenForms:[...new Set(hiddenFormList)],hiddenMoves:[...new Set(hiddenMoveList)],hiddenAbilities:[...new Set(hiddenAbilityList)],sectionDescriptions,specialKeyLabel:String(specialKey.value||'').trim(),suppressPbsChangesLogs:!!quietLogs.checked,allPbsModeButton:!!allPbsMode.checked};try{await writeProjectTextRobust(CONFIG_PATH,JSON.stringify(state.config,null,2)+'\n',{attempts:4,directFallback:true});toast('Configuración de ChangeDex guardada.','info');dialog?.close?.();}catch(e){toast(String(e?.message||e),'error');}};actions.append(resetUi,reset,saveCfg);g.append(actions);body.append(g);
    }});
  }

  search.oninput=()=>{state.search=String(search.value||'');renderList();updateStatus();requestAnimationFrame(()=>{try{search.focus({preventScroll:true});const n=search.value.length;search.setSelectionRange(n,n);}catch{}});};
  ['keydown','keyup','keypress'].forEach(evt=>search.addEventListener(evt,e=>e.stopPropagation()));
  allChip.onclick=()=>setListMode('all');
  changedChip.onclick=()=>setListMode('changed');
  baseChip.onclick=()=>setListMode('base');
  formsChip.onclick=()=>setListMode('forms');
  saveBtn.onclick=save;
  cleanBtn.onclick=cleanRedundant;
  importBtn.onclick=openMigrationDialog;
  reloadPbsBtn.onclick=()=>{
    reloadPbsBtn.disabled=true;
    state.loadingPhase=' · recargando PBS…';updateStatus();
    loadProject(true).then(()=>toast('PBS recargado. La caché de sesión fue reconstruida.','info'))
      .catch(e=>{try{ctx.log.error('ChangeDex Studio PBS reload failed',e);}catch{}status.textContent='Error: '+String(e?.message||e);})
      .finally(()=>{reloadPbsBtn.disabled=false;});
  };
  fullBtn.onclick=()=>setFullscreen(!state.fullscreen);
  closeFullBtn.onclick=()=>closeEditorFromFullscreen();
  unchangedChip.onclick=()=>setListMode('unchanged');
  manageBtn.onclick=()=>{state.manageMode=!state.manageMode;if(!state.manageMode)state.selectedMany.clear();updateBatchUi();renderList();};
  genSelect.onchange=()=>{state.generation=genSelect.value;renderList();updateStatus();};
  typeSelect.onchange=()=>{state.typeFilter=typeSelect.value;renderList();updateStatus();};
  sortSelect.onchange=()=>{state.sortMode=sortSelect.value;renderList();};
  viewSelect.onchange=()=>{state.viewMode=viewSelect.value;renderList();};
  selectVisibleBtn.onclick=()=>{filtered().forEach(e=>state.selectedMany.add(e._header));updateBatchUi();renderList();};
  selectChangedBtn.onclick=()=>{Object.keys(state.doc.species||{}).forEach(h=>state.selectedMany.add(h));updateBatchUi();renderList();};
  clearSelectionBtn.onclick=()=>{state.selectedMany.clear();updateBatchUi();renderList();};
  hideManyBtn.onclick=()=>setSelectedFormsHidden(true);
  showManyBtn.onclick=()=>setSelectedFormsHidden(false);
  revertManyBtn.onclick=()=>{if(!state.selectedMany.size)return;pushUndo();let n=0;for(const h of state.selectedMany){if(state.doc.species[h]){delete state.doc.species[h];n++;}}state.selectedMany.clear();setDirty();updateBatchUi();renderList();renderSelection();toast(`${n} Pokémon/formas restaurados a sus datos originales.`,'info');};
  undoBtn.onclick=undo;redoBtn.onclick=redo;
  entitiesBtn.onclick=openEntityManager;
  configBtn.onclick=openConfigDialog;
  updateBatchUi();updateUndoUi();

  const applyAdaptiveLayout=()=>{
    const w=Math.max(0,Number(root.clientWidth||host.clientWidth||0));
    root.classList.toggle('cdx-layout-medium',w>0&&w<1200&&w>=880);
    root.classList.toggle('cdx-layout-narrow',w>0&&w<880);
    root.classList.toggle('cdx-layout-wide',w>=1200);
  };
  const layoutObserver=(typeof ResizeObserver!=='undefined')?new ResizeObserver(()=>applyAdaptiveLayout()):null;
  try{layoutObserver?.observe(root);}catch{}
  requestAnimationFrame(applyAdaptiveLayout);

  loadProject().catch(e=>{try{ctx.log.error('ChangeDex Studio load failed',e);}catch{}status.textContent='Error: '+String(e?.message||e);});

  return ()=>{
    try{state.iconObserver?.disconnect?.();}catch{}
    try{layoutObserver?.disconnect?.();}catch{}
    if(state.fullscreen)setFullscreen(false);
    try{root.removeEventListener('keydown',keyboard,true);}catch{}
    for(const u of state.assetUrls.values()){try{URL.revokeObjectURL(u);}catch{}}
    state.assetUrls.clear();
  };
}
