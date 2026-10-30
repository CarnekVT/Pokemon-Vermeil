// Bifröst Art Studio — asset-backed editing surface modeled on BAS/BSS workspaces.
// The preview uses the same PNGs that the RPG runtime loads; art can be
// replaced with any external bitmap editor and reloaded without touching Ruby.
export const ART_ASSETS=[
 {id:"panel",name:"Panel principal",path:"Graphics/UI/Bifrost/panel.png",size:"392 × 116",role:"Banda principal del HUD"},
 {id:"slot",name:"Slot de Poké Ball",path:"Graphics/UI/Bifrost/slot.png",size:"46 × 42",role:"Poké Ball no seleccionada"},
 {id:"slot_selected",name:"Slot seleccionado",path:"Graphics/UI/Bifrost/slot_selected.png",size:"46 × 42",role:"Selección activa"},
 {id:"target",name:"Tarjeta del objetivo",path:"Graphics/UI/Bifrost/target.png",size:"228 × 48",role:"Información del Pokémon"},
 {id:"keycap",name:"Tecla contextual",path:"Graphics/UI/Bifrost/keycap.png",size:"74 × 22",role:"Indicadores de keybinding"},
 {id:"pokeball",name:"Poké Ball de Vermeil",path:"Graphics/Items/POKEBALL.png",role:"Recurso original del juego",readOnly:true},
 {id:"pokemon",name:"Icono del Pokémon",path:"Graphics/Pokemon/Icons/PIKACHU.png",role:"Recurso original del juego",readOnly:true},
 {id:"party",name:"Panel del equipo",path:"Graphics/UI/Party/panel_round.png",role:"Recurso original para referencia",readOnly:true}
];
const esc=v=>String(v??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
const clamp=(n,a,b)=>Math.min(b,Math.max(a,n));
const BASE="Graphics/UI/Bifrost/";
export async function loadArtAssets(ctx){
 const output={};
 const tauri=typeof window!=="undefined"?window.__TAURI__:null;
 const invoke=tauri?.core?.invoke||tauri?.tauri?.invoke;
 const gameRoot=typeof ctx?.editor?.gameRoot==="function"?String(ctx.editor.gameRoot()||""):"";
 if(!invoke||!gameRoot)return output;
 for(const asset of ART_ASSETS){
  try{
   const path=gameRoot.replace(/\\/g,"/").replace(/\/$/,"")+"/"+asset.path;
   const raw=await invoke("read_binary_file",{path});
   const bytes=raw instanceof Uint8Array?raw:new Uint8Array(raw||[]);
   if(bytes.length>20)output[asset.id]=URL.createObjectURL(new Blob([bytes],{type:"image/png"}));
  }catch(_){}
 }
 return output;
}
export function releaseArtAssets(mapping){
 Object.values(mapping||{}).forEach(url=>{try{URL.revokeObjectURL(url);}catch(_){}});
}
const img=(s,id,cls)=>s.artUrls?.[id]?'<img class="'+(cls||"")+'" src="'+esc(s.artUrls[id])+'" alt="'+esc(id)+'">':"";
function panelPosition(cfg){
 const scale=clamp(Number(cfg.hud_scale)||100,70,140)/100;
 const w=392*scale,h=116*scale,where=cfg.hud_position||"bottom_right";
 const right=where.endsWith("_right"),bottom=where.startsWith("bottom_");
 const x=clamp((right?640-w-8:8)+(Number(cfg.hud_offset_x)||0),2,640-w-2);
 const y=clamp((bottom?480-h-8:8)+(Number(cfg.hud_offset_y)||0),2,480-h-2);
 return {left:x/640*100,top:y/480*100,width:w/640*100,height:h/480*100};
}
export function renderArtStudio(s){
 const c=s.value(),p=panelPosition(c);
 const pos=`left:${p.left}%;top:${p.top}%;width:${p.width}%;height:${p.height}%;opacity:${clamp(Number(c.hud_opacity)||100,30,100)/100}`;
 const team=s.artMode==="team";
 const three=team?'<div class="bf-sim-pokemon">'+(img(s,"pokemon","bf-art-pokemon")||'<span>◉</span>')+'<div><b>Pikachu</b><small>NV. 18 · 1/3</small></div></div>':
   '<div class="bf-sim-slots">'+[-1,0,1].map((k,i)=>'<div class="bf-sim-slot">'+
      (img(s,i===1?"slot_selected":"slot","bf-slot-bg"))+
      (img(s,"pokeball","bf-ball-icon")||'<span class="bf-fallback-ball">◉</span>')+
      '<small>x'+[12,8,5][i]+'</small></div>').join("")+'</div>';
 const opts=[["ball","BALL"],["team","EQUIPO"]].map(([id,label])=>
   '<button class="bf-segment '+(s.artMode===id?"active":"")+'" data-art-mode="'+id+'">'+label+'</button>').join("");
 const assets=ART_ASSETS.map(a=>'<button class="bf-asset-card '+(a.id===s.artSelected?"selected":"")+
   '" data-art-select="'+a.id+'"><span class="bf-asset-thumb">'+(img(s,a.id)||'<span>PNG</span>')+
   '</span><span><strong>'+esc(a.name)+'</strong><small>'+esc(a.role)+'</small></span></button>').join("");
 const selected=ART_ASSETS.find(a=>a.id===s.artSelected)||ART_ASSETS[0];
 return '<div class="bf-art-header"><div><div class="bf-kicker">BIFRÖST / ART STUDIO</div><h1 class="bf-headline">Interfaz de captura</h1>'+
   '<p class="bf-sub">Diseña con capas PNG reales. Arrastra el HUD sobre la vista previa y ajusta sus propiedades a la derecha. Los iconos proceden del juego.</p></div>'+
   '<div class="bf-art-toggles">'+opts+'</div></div>'+
   '<div class="bf-art-toolbar"><span class="bf-tag">Vista 640 × 480</span><span class="bf-tag">No sustituye la prueba en mkxp-z</span>'+
   '<button class="bf-btn" data-art-reload>Recargar PNG del juego</button></div>'+
   '<div class="bf-art-stage"><div class="bf-sim-board" data-art-board>'+
    '<div class="bf-sim-land"><div class="bf-sim-target-dot"></div><div class="bf-sim-grass"></div>'+
    '<div class="bf-sim-trainer">▲</div></div>'+
    '<div class="bf-sim-hud" data-art-hud style="'+pos+'">'+
    (img(s,"panel","bf-sim-panel-img")||'<div class="bf-sim-panel-fallback"></div>')+
    '<div class="bf-sim-hud-label">'+(team?"EQUIPO POKÉMON":"BALL EQUIPADA")+'</div>'+
    three+
    '<div class="bf-sim-target">'+(img(s,"target","bf-target-bg"))+'<span><b>NEUTRO</b><small>Pikachu · Nv.18</small></span></div>'+
    '<div class="bf-sim-cool"><div class="bf-sim-cool-track"><i style="width:'+
      clamp(Number(s.demoCharge??100),0,100)+'%"></i></div><b>'+
      (Number(s.demoCharge??100)<100?"RECARGANDO":"BALL LISTA")+'</b></div>'+
    '<div class="bf-sim-keys"><kbd>Tab</kbd> Obj. <kbd>E</kbd> Modo <kbd>S</kbd> Cambiar</div>'+
    '</div></div>'+
    '<div class="bf-art-caption">Vista de montaje. <strong>Arrastra el panel</strong> para ajustar su posición. La escala y la opacidad se reflejan al guardar.</div>'+
   '</div><div class="bf-art-shelf"><div class="bf-art-shelf-head"><strong>Biblioteca de arte</strong><small>5 capas Bifröst editables · 3 referencias originales de Vermeil</small></div>'+
    '<div class="bf-asset-grid">'+assets+'</div>'+
    '<div class="bf-art-file"><div><strong>'+esc(selected.name)+'</strong><p>'+esc(selected.path)+'</p>'+
    (selected.readOnly?'<small>Recurso del juego: se utiliza como referencia y no se modifica.</small>':
    '<small>Edítalo con Aseprite, Photoshop, Krita o GIMP. Fuente vectorial: '+esc(BASE+"_source/"+selected.id+".svg")+'</small>')+
    '</div><div class="bf-art-file-actions">'+
    (selected.readOnly?'':'<button class="bf-btn primary" data-art-import="'+esc(selected.id)+'">Importar PNG</button>')+
    '<button class="bf-btn" data-copy-path="'+esc(selected.path)+'">Copiar ruta</button></div>'+
    '<input type="file" accept=".png,image/png" data-art-file-input hidden></div></div>';
}
