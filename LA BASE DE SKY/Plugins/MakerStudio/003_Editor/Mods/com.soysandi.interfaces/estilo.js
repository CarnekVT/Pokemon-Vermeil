//=============================================================================
// El CSS del editor.
//
// Usa las variables de tema del propio MakerStudio (--bg-primary, --border,
// --accent...) para heredar el modo claro y el oscuro sin hacer nada.
//=============================================================================

export const CSS = `
.ui-raiz {
  display: flex; flex-direction: column;
  width: 100%; height: 100%;
  font-size: 12px; color: var(--text-primary);
  overflow: hidden;
}

/* ---- Barra de herramientas ---- */
.ui-barra {
  display: flex; align-items: center; gap: 6px;
  padding: 6px 8px; border-bottom: 1px solid var(--border);
  background: var(--bg-secondary); flex-shrink: 0; flex-wrap: wrap;
}
.ui-barra-hueco { flex: 1; }
.ui-nombre-diseno {
  font-weight: 600; padding: 3px 8px; border-radius: 3px;
  background: var(--bg-primary); border: 1px solid var(--border);
}
.ui-sucio { color: var(--accent); font-weight: 600; }

.ui-btn {
  padding: 4px 10px; border: 1px solid var(--border); border-radius: 3px;
  background: var(--bg-primary); color: var(--text-primary);
  font-size: 12px; font-family: inherit; cursor: pointer; white-space: nowrap;
}
.ui-btn:hover { background: var(--bg-hover, var(--bg-secondary)); }
.ui-btn.primario { background: var(--accent); border-color: var(--accent); color: #fff; }
.ui-btn.peligro:hover { background: #b3402f; border-color: #b3402f; color: #fff; }
.ui-btn:disabled { opacity: .45; cursor: default; }
.ui-btn-icono { padding: 4px 7px; line-height: 1; }

/* ---- Resolution / canvas toolbar ---- */
.ui-resolucion {
  display: flex; align-items: center; gap: 6px; padding: 5px 8px;
  border-bottom: 1px solid var(--border); background: var(--bg-primary);
  flex-shrink: 0; flex-wrap: wrap;
}
.ui-res-preset { width: auto; min-width: 170px; }
.ui-res-num { width: 74px; }
.ui-res-estrategia { width: auto; min-width: 145px; }
.ui-res-modo { width: auto; min-width: 110px; }
.ui-res-x { opacity: .65; font-weight: 600; }
.ui-res-info { min-width: 42px; text-align: center; font-family: ui-monospace, monospace; color: var(--text-tertiary); }
.ui-res-sep { width: 1px; align-self: stretch; background: var(--border); margin: 0 2px; }

/* ---- Cuerpo: capas | lienzo | inspector ---- */
.ui-cuerpo { display: flex; flex: 1; min-height: 0; }

.ui-panel-izq {
  width: 220px; min-width: 170px; max-width: 420px; flex-shrink: 0; border-right: 1px solid var(--border);
  display: flex; flex-direction: column; background: var(--bg-secondary);
}
.ui-panel-der {
  width: 300px; min-width: 240px; max-width: 520px; flex-shrink: 0; border-left: 1px solid var(--border);
  display: flex; flex-direction: column; background: var(--bg-secondary);
  overflow-y: auto;
}
.ui-centro {
  flex: 1; min-width: 0; display: flex; flex-direction: column;
  background: var(--bg-primary);
}

.ui-cabecera-panel {
  padding: 6px 8px; font-weight: 600; font-size: 11px;
  text-transform: uppercase; letter-spacing: .04em;
  color: var(--text-tertiary); border-bottom: 1px solid var(--border);
  display: flex; align-items: center; gap: 6px;
}
.ui-cabecera-panel .ui-barra-hueco { flex: 1; }

/* ---- Lista de capas ---- */
.ui-capas { flex: 1; overflow-y: auto; }
.ui-capa {
  display: flex; align-items: center; gap: 6px;
  padding: 5px 8px; cursor: pointer; border-bottom: 1px solid var(--border);
  user-select: none;
}
.ui-capa:hover { background: var(--bg-hover, var(--bg-primary)); }
.ui-capa.elegida { background: var(--accent); color: #fff; }
.ui-capa.elegida .ui-capa-tipo { color: rgba(255,255,255,.75); }
/* Los demas del grupo: se ve que van juntos sin competir con el principal. Se
   usa rgba y no color-mix por si la version del editor lleva un motor viejo. */
.ui-capa.en-grupo { background: rgba(75,159,234,.20); box-shadow: inset 2px 0 0 var(--accent); }
.ui-capa.arrastrando { opacity: .4; }
.ui-capa.destino { border-top: 2px solid var(--accent); }
.ui-capa-id { flex: 1; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.ui-capa-tipo { font-size: 10px; color: var(--text-tertiary); }
.ui-ojo {
  background: none; border: none; cursor: pointer; padding: 0 2px;
  color: inherit; opacity: .7; font-size: 12px; line-height: 1;
}
.ui-ojo:hover { opacity: 1; }
.ui-ojo.apagado { opacity: .3; }

/* ---- Lienzo ---- */
/* EL CENTRADO VA CON margin:auto EN EL HIJO, NO CON justify-content, y no es un
   capricho de estilo: es el arreglo de "si amplio la pantalla no me deja subir
   la barra, por lo que media pantalla queda inutilizada".

   Con overflow:auto mas align-items/justify-content:center, cuando el
   contenido es mas grande que el hueco el navegador reparte lo que sobra a los
   DOS lados, pero la barra de scroll solo llega al lado final: la mitad que
   queda hacia arriba y hacia la izquierda no hay forma de alcanzarla. Es un
   comportamiento conocido de flex con overflow, no un fallo del editor.

   Con margin:auto en el hijo se centra igual cuando cabe, y cuando no cabe el
   desbordamiento SI es alcanzable por los cuatro lados. */
.ui-lienzo-zona {
  flex: 1; overflow: auto; display: flex;
  padding: 16px;
  background:
    repeating-conic-gradient(var(--bg-secondary) 0% 25%, var(--bg-primary) 0% 50%) 50% / 16px 16px;
}
.ui-lienzo-zona.ui-paneando,
.ui-lienzo-zona.ui-paneando canvas.ui-lienzo { cursor: grabbing; }
.ui-lienzo-marco {
  position: relative; margin: auto;
  box-shadow: 0 0 0 1px var(--border), 0 6px 24px rgba(0,0,0,.35);
}
/* El diseño se dibuja a su resolucion LOGICA real y el navegador aplica el zoom de vista. */
canvas.ui-lienzo { display: block; image-rendering: pixelated; cursor: default; }
/* Los adornos del editor van encima y finos. pointer-events a none para que el
   raton siga llegando al lienzo de abajo, que es quien lleva los eventos. */
canvas.ui-lienzo-capa { position: absolute; left: 0; top: 0; pointer-events: none; }

.ui-pie-lienzo {
  display: flex; align-items: center; gap: 10px;
  padding: 4px 8px; border-top: 1px solid var(--border);
  background: var(--bg-secondary); color: var(--text-tertiary);
  font-size: 11px; flex-shrink: 0; flex-wrap: wrap;
}

/* ---- Inspector ---- */
.ui-inspector { padding: 8px; }
.ui-titulillo {
  font-weight: 600; font-size: 11px; text-transform: uppercase;
  letter-spacing: .04em; color: var(--text-tertiary);
  margin: 12px 0 5px; padding-bottom: 3px; border-bottom: 1px solid var(--border);
}
.ui-titulillo:first-child { margin-top: 0; }
.ui-fila { display: flex; align-items: center; gap: 6px; margin-bottom: 5px; }
.ui-etiqueta { width: 92px; flex-shrink: 0; color: var(--text-secondary, var(--text-tertiary)); }
.ui-controles { flex: 1; display: flex; align-items: center; gap: 4px; min-width: 0; }
.ui-num, .ui-txt, .ui-sel {
  padding: 3px 6px; border: 1px solid var(--border); border-radius: 3px;
  background: var(--input-bg, var(--bg-primary)); color: var(--text-primary);
  font-size: 12px; font-family: inherit; outline: none; min-width: 0; width: 100%;
}
.ui-num { width: 68px; flex: 0 0 auto; }
.ui-sep { height: 1px; background: var(--border); margin: 8px 0; }
.ui-casilla { display: flex; align-items: center; gap: 5px; cursor: pointer; }
.ui-pista-vacia { color: var(--text-tertiary); font-style: italic; padding: 4px 0; }

.ui-color-fila { display: flex; align-items: center; gap: 4px; width: 100%; }
.ui-color { width: 30px; height: 22px; padding: 0; border: 1px solid var(--border); border-radius: 3px; background: none; cursor: pointer; }
.ui-alfa { width: 54px; flex: 0 0 auto; }
.ui-color-txt { width: 84px; flex: 0 0 auto; font-family: ui-monospace, monospace; font-size: 11px; }

.ui-ayuda {
  color: var(--text-tertiary); font-size: 11px; line-height: 1.45;
  margin: 4px 0 8px;
}

/* ---- Linea de tiempo ---- */
.ui-tiempo {
  height: 168px; flex-shrink: 0; border-top: 1px solid var(--border);
  background: var(--bg-secondary); display: flex; flex-direction: column;
}
.ui-tiempo-barra {
  display: flex; align-items: center; gap: 8px;
  padding: 5px 8px; border-bottom: 1px solid var(--border); flex-wrap: wrap;
}
.ui-tiempo-reloj { font-family: ui-monospace, monospace; color: var(--text-tertiary); }
.ui-pistas { flex: 1; overflow-y: auto; }
.ui-pista {
  display: flex; align-items: center; gap: 6px; height: 26px;
  border-bottom: 1px solid var(--border); padding: 0 8px;
}
.ui-pista-nombre { width: 96px; flex-shrink: 0; color: var(--text-secondary, var(--text-tertiary)); }
.ui-pista-carril {
  flex: 1; height: 18px; position: relative; border-radius: 3px;
  background: var(--bg-primary); border: 1px solid var(--border); cursor: crosshair;
}
.ui-clave {
  position: absolute; top: 50%; width: 9px; height: 9px;
  margin: -5px 0 0 -5px; background: var(--accent);
  border: 1px solid #fff; border-radius: 2px; transform: rotate(45deg);
  cursor: grab;
}
.ui-clave.elegida { background: #fff; border-color: var(--accent); }
.ui-aguja {
  position: absolute; top: 0; bottom: 0; width: 1px;
  background: #e8574a; pointer-events: none;
}

/* ---- Aviso de que falta el plugin ----
   Va arriba del todo y no se va solo: si el plugin falta, los diseños no se ven
   en el juego, y eso no se puede decir con un toast que desaparece en tres
   segundos. Lleva su boton de cerrar para quien ya lo sepa. */
.ui-aviso-plugin {
  display: flex; align-items: center; gap: 10px;
  padding: 8px 12px; font-size: 12px; flex-shrink: 0;
  border-bottom: 1px solid var(--border);
}
.ui-aviso-plugin.falta { background: #5c2a24; color: #ffd9d2; }
.ui-aviso-plugin.aviso { background: #5c4a1e; color: #ffeec2; }
.ui-aviso-enlace {
  color: inherit; font-weight: 600; text-decoration: underline;
  white-space: nowrap; flex-shrink: 0;
}
.ui-aviso-cerrar {
  background: none; border: none; color: inherit; cursor: pointer;
  font-size: 18px; line-height: 1; padding: 0 4px; opacity: .7; flex-shrink: 0;
}
.ui-aviso-cerrar:hover { opacity: 1; }

/* ---- Cartel de "no hay nada" ---- */
.ui-vacio {
  flex: 1; display: flex; flex-direction: column; align-items: center;
  justify-content: center; gap: 10px; color: var(--text-tertiary);
  text-align: center; padding: 24px;
}


/* Interface Studio 3 · consolidated visual workspace.
   Native editor components remain. There is ONE navigation hierarchy. */
.ui-studio-v3{
  --studio-line:var(--border,#354153);
  --studio-bg:var(--bg-primary,#111822);
  --studio-panel:var(--bg-secondary,#1c2532);
  font:12px/1.42 system-ui,"Segoe UI",sans-serif;
  position:relative;min-width:0;background:var(--studio-bg);
}
.ui-studio-v3 [hidden]{display:none!important}
.ui-studio-v3 button,.ui-studio-v3 input,.ui-studio-v3 select{
  font-family:inherit;font-size:12px;
}
.ui-studio-v3 button:focus-visible,.ui-studio-v3 input:focus-visible,
.ui-studio-v3 select:focus-visible,.ui-studio-v3 summary:focus-visible{
  outline:2px solid var(--accent,#619fee);outline-offset:2px;
}
.ui-studio-v3 .ui-btn{border-radius:5px;min-height:32px;padding:6px 10px;line-height:1.2}
.ui-studio-v3 .ui-btn.active,.ui-studio-v3 .ui-studio-nav.active{
  background:var(--accent,#567dc6);border-color:var(--accent,#567dc6);color:#fff
}
.ui-studio-v3 .ui-studio-primary{
  background:var(--accent,#567dc6);border-color:var(--accent,#567dc6);
  color:#fff!important;font-weight:650;
}
.ui-studio-v3 .ui-sel,.ui-studio-v3 .ui-num,.ui-studio-v3 .ui-txt{
  border-radius:5px;min-height:30px;
}
/* One-line project header */
.ui-studio-v3 .ui-studio-header{
  padding:8px 13px;gap:7px;min-height:59px;flex-wrap:nowrap;
  background:var(--studio-panel);border-bottom:1px solid var(--studio-line);
}
.ui-studio-brand{display:flex;flex-direction:column;gap:0;min-width:125px;
  padding-right:14px;margin-right:3px;border-right:1px solid var(--studio-line);line-height:1.26}
.ui-studio-brand strong{letter-spacing:.05em;font-size:13px;font-weight:770}
.ui-studio-brand small{font-size:10px;opacity:.68;letter-spacing:.015em}
.ui-studio-breadcrumb{min-width:0;flex:0 1 260px;overflow:hidden;text-overflow:ellipsis;
  white-space:nowrap;color:var(--text-secondary,var(--text-tertiary));font-size:11px}
.ui-studio-compat-controls{position:absolute;left:-10000px;width:1px;height:1px;overflow:hidden}
.ui-studio-v3 .ui-studio-header .ui-sucio{font-size:11px;white-space:nowrap}
.ui-studio-menu{position:relative}
.ui-studio-menu summary{display:block;list-style:none;cursor:pointer;
  border:1px solid var(--studio-line);padding:8px 11px;border-radius:5px}
.ui-studio-menu summary::-webkit-details-marker{display:none}
.ui-studio-menu-actions{position:absolute;z-index:100;right:0;top:100%;width:225px;
  padding:8px;background:var(--studio-panel);border:1px solid var(--studio-line);
  box-shadow:0 12px 30px #0008;border-radius:6px;display:flex;flex-direction:column;gap:3px}
.ui-studio-menu-actions button{display:block;width:100%;text-align:left;
  border:0;background:transparent;color:var(--text-primary);padding:10px 11px;
  border-radius:4px;cursor:pointer}
.ui-studio-menu-actions button:hover{background:var(--bg-hover,var(--studio-bg))}
/* One-line design bar; editor shortcuts do not occupy extra ribbons. */
.ui-studio-v3 .ui-studio-toolstrip{
  flex-shrink:0;min-height:47px;padding:7px 12px;gap:8px;
  background:var(--studio-bg);border-bottom:1px solid var(--studio-line);
  flex-wrap:nowrap;overflow:visible;
}
.ui-studio-current{font-size:12px;white-space:nowrap;max-width:175px;
  overflow:hidden;text-overflow:ellipsis}
.ui-studio-mini-status{font-size:11px;white-space:nowrap;opacity:.65}
.ui-studio-toolstrip>span:not(.ui-barra-hueco){font-size:11px;opacity:.76}
.ui-studio-toolstrip .ui-sel{width:auto;min-width:75px;max-width:145px}
.ui-studio-toolstrip .ui-btn{padding:6px 8px;white-space:nowrap}
.ui-studio-group-tools{position:relative;font-size:11px}
.ui-studio-group-tools summary{cursor:pointer;padding:9px 4px;color:var(--text-secondary)}
.ui-studio-group-tools .ui-barra{
  position:absolute;right:0;top:100%;z-index:35;width:510px;
  padding:10px;display:flex!important;flex-wrap:wrap;
  border:1px solid var(--studio-line);border-radius:6px;
  background:var(--studio-panel);box-shadow:0 12px 24px #0006
}
.ui-studio-group-tools:not([open]) .ui-barra{display:none!important}
.ui-studio-group-tools .ui-barra[style*="display: none"]{display:none!important}
/* Clean workspace */
.ui-studio-v3 .ui-cuerpo{flex:1;min-height:0;overflow:hidden}
.ui-studio-v3 .ui-panel-izq{
  width:255px;min-width:195px;max-width:400px;
  background:var(--studio-panel);border-right:1px solid var(--studio-line)
}
.ui-studio-v3 .ui-panel-der{
  width:330px;min-width:250px;max-width:510px;
  background:var(--studio-panel);border-left:1px solid var(--studio-line)
}
.ui-studio-v3 .ui-centro{flex:1;min-width:0;min-height:0;background:var(--studio-bg)}
.ui-studio-v3 .ui-lienzo-zona{
  padding:24px;min-height:0;
  background:repeating-conic-gradient(var(--studio-panel) 0 25%,var(--studio-bg) 0 50%) 50% / 20px 20px
}
.ui-studio-v3 .ui-lienzo-marco{box-shadow:0 0 0 1px #7c91aa,0 10px 26px #0006}
.ui-studio-v3 .ui-lienzo{image-rendering:pixelated}
.ui-studio-v3 .ui-pie-lienzo{min-height:39px;padding:6px 12px}
.ui-studio-v3 .ui-studio-status{flex:0 0 25px;padding:4px 12px;
  background:var(--studio-bg);color:var(--text-tertiary);
  border-top:1px solid var(--studio-line);font:11px ui-monospace,monospace;
  overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.ui-studio-v3 .ui-panel-izq>.ui-cabecera-panel{padding:11px 12px}
.ui-studio-v3 .ui-capa{padding:8px 9px;min-height:35px}
.ui-studio-v3 .ui-capa.elegida{background:rgba(85,131,198,.26);
  color:var(--text-primary);box-shadow:inset 3px 0 0 var(--accent,#619fee)}
.ui-studio-v3 .ui-layer-search{margin:8px 9px 5px;width:calc(100% - 18px)}
.ui-layer-counter{font-size:10px;opacity:.7;padding:5px 10px 8px}
.ui-layer-filters{display:flex;gap:5px;flex-wrap:wrap;padding:5px 9px}
.ui-layer-filter{font:inherit;font-size:11px!important;border:1px solid var(--studio-line);
  background:transparent;color:var(--text-primary);padding:6px 9px;border-radius:5px;cursor:pointer}
.ui-layer-filter.activo{background:var(--accent,#567dc6);border-color:var(--accent,#567dc6);color:#fff}
.ui-layer-group{margin:5px 7px 8px;border:1px solid var(--studio-line);border-radius:5px;overflow:hidden}
.ui-layer-group-head{display:block;width:100%;font:inherit;font-size:11px;
  font-weight:650;text-align:left;color:var(--text-primary);background:var(--studio-bg);
  border:0;padding:9px 10px;cursor:pointer}
.ui-layer-group-head:hover{background:var(--bg-hover,var(--studio-bg))}
.ui-layer-group .ui-capa{padding-left:8px}
/* Sidebar has no stacked libraries: choose folders OR layers. */
.ui-studio-side-tabs{display:grid;grid-template-columns:1fr 1fr;gap:3px;
  border-bottom:1px solid var(--studio-line);padding:8px}
.ui-studio-side-tab{background:transparent;border:0;border-radius:5px;
  color:var(--text-secondary);padding:10px;cursor:pointer;font-weight:600}
.ui-studio-side-tab.active{color:var(--text-primary);background:var(--studio-bg);
  box-shadow:inset 0 -2px 0 var(--accent,#619fee)}
.ui-studio-library-aside{display:flex;flex-direction:column;gap:8px;
  flex:1;min-height:0;padding:14px 10px}
.ui-studio-side-caption{font-size:10px;font-weight:800;letter-spacing:.1em;
  color:var(--text-tertiary)}
.ui-studio-new-folder{width:100%;text-align:left}
.ui-studio-folder-list{display:flex;flex-direction:column;gap:3px;overflow-y:auto;flex:1}
.ui-studio-folder{width:100%;display:flex;gap:10px;align-items:center;
  border:1px solid transparent;background:transparent;color:var(--text-primary);
  text-align:left;border-radius:6px;padding:11px 9px;cursor:pointer}
.ui-studio-folder:hover{background:var(--bg-hover,var(--studio-bg))}
.ui-studio-folder.active{background:var(--studio-bg);
  border-color:var(--accent,#619fee)}
.ui-studio-folder strong{flex:1;font-size:12px;overflow:hidden;text-overflow:ellipsis}
.ui-studio-folder small{opacity:.6;font-size:11px}
/* Visual library = large, legible cards with true aspect ratio thumbnails. */
.ui-studio-gallery{display:flex;flex-direction:column;flex:1;overflow:hidden;
  min-width:0;background:var(--studio-bg)}
.ui-studio-gallery-head{display:flex;align-items:center;gap:14px;
  padding:22px 25px 17px;border-bottom:1px solid var(--studio-line)}
.ui-studio-gallery-title{min-width:190px;flex:1}
.ui-studio-gallery-title strong{font-size:19px;font-weight:740;letter-spacing:-.02em}
.ui-studio-gallery-title p{margin:6px 0 0;font-size:12px;color:var(--text-secondary);
  line-height:1.5}
.ui-studio-search{width:250px;max-width:33%;padding:8px 10px}
.ui-studio-gallery-body{flex:1;min-height:0;overflow:auto;padding:20px 26px 40px}
.ui-studio-gallery-section{margin:0 0 32px}
.ui-studio-gallery-section-title{display:flex;gap:14px;align-items:baseline;
  margin-bottom:13px;padding-bottom:10px;border-bottom:1px solid var(--studio-line)}
.ui-studio-gallery-section-title strong{font-size:15px}
.ui-studio-gallery-section-title span{font-size:11px;opacity:.62}
.ui-studio-card-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(222px,1fr));
  gap:16px}
.ui-studio-screen-card{width:100%;display:flex;flex-direction:column;
  padding:0;border:1px solid var(--studio-line);background:var(--studio-panel);
  color:var(--text-primary);text-align:left;cursor:pointer;border-radius:7px;
  overflow:hidden;min-width:0}
.ui-studio-screen-card:hover,.ui-studio-screen-card:focus-visible{
  border-color:var(--accent,#619fee);box-shadow:0 0 0 2px rgba(96,148,220,.15)}
.ui-studio-thumb-frame{width:100%;aspect-ratio:4/3;display:flex;
  background:#111c28;overflow:hidden}
.ui-studio-screen-thumb{width:100%;height:100%;display:block;
  image-rendering:pixelated;object-fit:fill}
.ui-studio-screen-label{padding:12px;display:flex;flex-direction:column;gap:5px;
  min-width:0}
.ui-studio-screen-label strong{font-size:14px;font-weight:650}
.ui-studio-screen-label small{font-size:10px;white-space:nowrap;overflow:hidden;
  text-overflow:ellipsis;opacity:.63;font-family:ui-monospace,monospace}
.ui-studio-no-pages{padding:35px;color:var(--text-secondary);border:1px dashed var(--studio-line);
  border-radius:8px;text-align:center}
/* Native inspector with only Design / Logic / Animation tabs. */
.ui-studio-v3 .ui-inspector{padding:13px 15px 20px}
.ui-studio-v3 .ui-inspector-context{display:flex;align-items:center;
  justify-content:space-between;gap:8px;min-width:0;margin-bottom:11px}
.ui-studio-v3 .ui-inspector-context strong{overflow:hidden;text-overflow:ellipsis}
.ui-inspector-back{background:transparent;color:var(--accent);border:0;
  font-size:11px;cursor:pointer}
.ui-inspector-tabs{display:grid;grid-template-columns:repeat(3,1fr);gap:4px;
  margin-bottom:15px;padding-bottom:10px;border-bottom:1px solid var(--studio-line)}
.ui-inspector-tab{padding:10px 4px;background:transparent;color:var(--text-secondary);
  border:1px solid transparent;border-radius:5px;cursor:pointer}
.ui-inspector-tab.activo{background:var(--studio-bg);
  border-color:var(--accent,#619fee);color:var(--text-primary)}
.ui-inspector-note{padding:11px 12px;margin-bottom:15px;background:var(--studio-bg);
  color:var(--text-secondary);font-size:11px;line-height:1.5}
.ui-inspector-open-timeline{width:100%;margin-top:12px}
.ui-studio-v3 .ui-fila{align-items:flex-start;gap:9px;margin-bottom:9px}
.ui-studio-v3 .ui-etiqueta{width:110px;font-size:11px;padding-top:5px}
.ui-studio-v3 .ui-titulillo{font-size:11px;font-weight:650;letter-spacing:.02em;
  margin-top:17px;margin-bottom:8px;padding-bottom:6px}
.ui-studio-v3 .ui-tiempo{min-height:150px;height:188px}
/* Reusable components: a single modal with explicit categories. */
.ui-studio-palette{position:absolute;inset:0;z-index:99;display:flex;
  align-items:center;justify-content:center}
.ui-studio-palette-shade{position:absolute;inset:0;background:rgba(6,10,16,.68);
  border:0;cursor:default}
.ui-studio-palette-content{position:relative;z-index:1;width:min(620px,92vw);
  max-height:min(650px,85vh);display:flex;flex-direction:column;
  background:var(--studio-panel);border:1px solid var(--studio-line);
  border-radius:8px;box-shadow:0 20px 50px #0009;overflow:hidden}
.ui-studio-palette-top{display:flex;align-items:center;gap:13px;
  padding:17px;border-bottom:1px solid var(--studio-line)}
.ui-studio-palette-top strong{font-size:15px;white-space:nowrap}
.ui-studio-palette-top input{flex:1;max-width:none}
.ui-studio-palette-items{padding:16px;overflow-y:auto;display:grid;
  grid-template-columns:repeat(3,minmax(0,1fr));gap:9px;align-content:start}
.ui-studio-palette-caption{grid-column:1/-1;font-size:10px;font-weight:750;
  color:var(--text-tertiary);letter-spacing:.07em;margin-top:12px}
.ui-studio-preset-item{width:100%;min-height:68px;display:flex;
  align-items:center;justify-content:center;padding:13px 10px;
  border:1px solid var(--studio-line);border-radius:7px;
  background:var(--studio-bg);color:var(--text-primary);font-size:12px;
  line-height:1.3;text-align:center;cursor:pointer;white-space:normal}
.ui-studio-preset-item:hover{border-color:var(--accent,#619fee);
  background:var(--bg-hover,var(--studio-panel))}
/* Resolution in one small popover. */
.ui-studio-canvas-popover{position:absolute;top:57px;right:135px;
  z-index:90;width:min(430px,92vw);max-height:calc(100% - 70px);overflow:auto;
  border:1px solid var(--studio-line);background:var(--studio-panel);
  box-shadow:0 13px 32px #0009;border-radius:7px}
.ui-studio-modal-title{padding:13px 15px;font-size:14px;font-weight:650;
  border-bottom:1px solid var(--studio-line)}
.ui-studio-canvas-popover .ui-resolucion{display:flex;flex-direction:column;
  align-items:stretch;gap:10px;padding:15px}
.ui-studio-canvas-popover .ui-resolucion .ui-sel,
.ui-studio-canvas-popover .ui-resolucion .ui-num{max-width:100%}
@media(max-width:1150px){
  .ui-studio-v3 .ui-studio-header{gap:5px}
  .ui-studio-v3 .ui-studio-breadcrumb{display:none}
  .ui-studio-v3 .ui-studio-header .ui-btn{padding:6px 8px}
  .ui-studio-v3 .ui-panel-izq{width:205px;min-width:170px}
  .ui-studio-v3 .ui-panel-der{width:270px;min-width:220px}
  .ui-studio-gallery-head{flex-wrap:wrap}
  .ui-studio-search{max-width:none;width:100%;flex:1}
}

`;
