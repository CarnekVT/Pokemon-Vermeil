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

/* Interface Studio 2.1 · Visual workspace inspirado en BAS/BSS.
   Mantiene todos los controles originales; cambia su composición visual. */
.ui-raiz {
  --ui-ux-panel: var(--bg-secondary, #192331);
  --ui-ux-line: var(--border, #344153);
  font-family: system-ui, "Segoe UI", sans-serif;
  font-size: 12px;
  background: var(--bg-primary, #101722);
  min-width: 0;
}
.ui-raiz button,.ui-raiz input,.ui-raiz select { font-family: inherit; }
.ui-raiz:focus {outline:none}
.ui-raiz button:focus-visible,
.ui-raiz input:focus-visible,
.ui-raiz select:focus-visible,
.ui-workspace-menu summary:focus-visible {
  outline: 2px solid var(--accent, #619fee);outline-offset: 2px;
}
.ui-barra {gap:8px;padding:8px 12px;min-height:44px}
.ui-barra:first-of-type {min-height:54px}
.ui-barra .ui-btn {min-height:29px}
.ui-workspace-brand {display:grid;gap:0;margin-right:10px;padding-right:15px;border-right:1px solid var(--ui-ux-line);line-height:1.3;white-space:nowrap}
.ui-workspace-brand strong {font-size:14px;letter-spacing:.2px;color:var(--text-primary)}
.ui-workspace-brand small {font-size:10px;letter-spacing:.2px;color:var(--text-tertiary)}
.ui-btn {border-radius:7px;min-height:27px;transition:background-color .12s,border-color .12s}
.ui-btn:hover {border-color:var(--accent,var(--border))}
.ui-sel,.ui-txt,.ui-num {border-radius:6px;min-height:28px}
.ui-sel:focus,.ui-txt:focus,.ui-num:focus {border-color:var(--accent)}
.ui-panel-izq,.ui-panel-der {background:var(--ui-ux-panel);min-height:0}
.ui-panel-izq {width:240px;max-width:480px}
.ui-panel-der {width:340px;max-width:640px}
.ui-cabecera-panel {min-height:35px;font-size:11px;letter-spacing:.07em}
.ui-capa {min-height:34px;padding:8px 9px;border-radius:4px;border-bottom-color:color-mix(in srgb,var(--ui-ux-line) 50%,transparent)}
.ui-capa.elegida {background:color-mix(in srgb,var(--accent) 28%,var(--bg-primary));color:var(--text-primary);box-shadow:inset 3px 0 0 var(--accent)}
.ui-capa.elegida .ui-capa-tipo {color:var(--text-secondary)}
.ui-capa-id {font-weight:500}
.ui-inspector {padding:12px}
.ui-titulillo {font-size:11px;margin-top:17px;margin-bottom:9px;padding-bottom:6px;letter-spacing:.05em}
.ui-fila {gap:10px;margin-bottom:9px;align-items:center}
.ui-etiqueta {width:102px;font-size:11px}
.ui-ayuda {line-height:1.55}
.ui-centro {min-width:0}
.ui-lienzo-zona {padding:28px;background:radial-gradient(ellipse at center,rgba(96,132,179,.10),transparent 72%),repeating-conic-gradient(var(--bg-secondary) 0% 25%,var(--bg-primary) 0% 50%) 50% / 16px 16px}
.ui-lienzo-marco {box-shadow:0 0 0 1px var(--border),0 14px 36px rgba(0,0,0,.35)}
.ui-pie-lienzo {padding:8px 12px;gap:9px}
.ui-resolucion {padding:7px 12px;gap:9px}
.ui-tiempo {height:176px}
.ui-tiempo-barra {padding:8px 11px;gap:9px}
.ui-workspace-menu {position:relative;flex:0 0 auto}
.ui-workspace-menu>summary {list-style:none;border:1px solid var(--border);border-radius:7px;padding:7px 12px;background:var(--bg-primary);color:var(--text-primary);cursor:pointer;white-space:nowrap}
.ui-workspace-menu>summary::-webkit-details-marker {display:none}
.ui-workspace-menu>summary:hover,.ui-workspace-menu[open]>summary {border-color:var(--accent);background:var(--bg-hover,var(--bg-secondary))}
.ui-workspace-dropdown {position:absolute;z-index:80;left:0;top:calc(100% + 6px);min-width:220px;max-height:min(460px,65vh);overflow-y:auto;display:grid;gap:5px;padding:10px;background:var(--bg-secondary);border:1px solid var(--border);border-radius:9px;box-shadow:0 12px 32px rgba(0,0,0,.37)}
.ui-workspace-dropdown .ui-btn {width:100%;text-align:left;padding:9px 10px}
.ui-workspace-dropdown .ui-btn.peligro {border-color:rgba(220,92,92,.4)}
.ui-workspace-dropdown .ui-txt {width:100%}
.ui-workspace-choices {display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:6px;min-width:300px}
.ui-workspace-choices .ui-btn {white-space:normal;min-height:40px}
.ui-workspace-option[hidden] {display:none!important}
.ui-workspace-bar {display:flex;align-items:center;gap:7px;padding:7px 12px;background:var(--bg-secondary);border-bottom:1px solid var(--border);flex-wrap:wrap;flex-shrink:0;min-height:43px}
.ui-workspace-caption {display:grid;line-height:1.2;margin-right:4px}
.ui-workspace-caption b {font-size:10px;letter-spacing:.08em}
.ui-workspace-caption span {font-size:10px;color:var(--text-tertiary)}
.ui-workspace-divider {width:1px;height:22px;background:var(--border);margin:0 4px}
.ui-workspace-btn {padding:6px 9px!important;font-size:11px;min-height:29px}
.ui-workspace-selected {background:color-mix(in srgb,var(--accent) 18%,var(--bg-primary));border-color:var(--accent)!important}
.ui-workspace-resizer {width:6px;flex:0 0 6px;cursor:col-resize;position:relative;background:var(--bg-primary);border-left:1px solid var(--border);border-right:1px solid var(--border)}
.ui-workspace-resizer:hover,.ui-workspace-resizer:active {background:var(--accent)}
.ui-workspace-status {height:26px;padding:5px 12px;display:flex;align-items:center;justify-content:space-between;gap:12px;flex-shrink:0;border-top:1px solid var(--border);color:var(--text-tertiary);font:11px/1.2 ui-monospace,Consolas,monospace}
.ui-workspace-status span {overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.ui-workspace-hide-layers .ui-panel-izq,.ui-workspace-hide-layers .ui-workspace-resizer.left {display:none!important}
.ui-workspace-hide-inspector .ui-panel-der,.ui-workspace-hide-inspector .ui-workspace-resizer.right {display:none!important}
.ui-workspace-hide-timeline .ui-tiempo {height:auto;min-height:42px}
.ui-workspace-hide-timeline .ui-tiempo .ui-pistas {display:none}
.ui-workspace-focus .ui-add-toolbar,.ui-workspace-focus .ui-resolucion {display:none}
.ui-workspace-focus .ui-lienzo-zona {padding:12px}
.ui-layer-search {margin:7px 8px 4px!important;width:calc(100% - 16px);min-height:30px}
.ui-layer-counter {font-size:10px;color:var(--text-tertiary);padding:4px 10px 6px;border-bottom:1px solid var(--border)}
.ui-layer-empty {padding:12px;color:var(--text-tertiary);font-size:11px}
@media(max-width:1080px){
  .ui-workspace-brand small,.ui-workspace-caption span {display:none}
  .ui-workspace-brand {padding-right:8px;margin-right:3px}
  .ui-panel-izq {width:200px}.ui-panel-der {width:280px}
  .ui-workspace-bar {gap:4px}
  .ui-workspace-btn {padding:5px 6px!important}
}
@media(max-width:800px){
  .ui-workspace-caption {display:none}
  .ui-barra {gap:5px}
  .ui-resolucion {max-height:98px;overflow-y:auto}
  .ui-panel-izq {width:170px;min-width:150px}
  .ui-panel-der {width:240px;min-width:210px}
}

/* 2.2 · Workspace despejado: la interfaz da prioridad al lienzo. */
.ui-raiz {
  font-family:system-ui,-apple-system,"Segoe UI",Arial,sans-serif!important;
  font-size:13px;line-height:1.45;
}
.ui-raiz .ui-btn,.ui-raiz .ui-sel,.ui-raiz .ui-num,.ui-raiz .ui-txt {font-family:inherit;font-size:12px}
.ui-raiz>.ui-barra {
  position:relative;z-index:25;
  min-height:54px;max-height:110px;
  padding:9px 14px;gap:9px;align-content:center;
}
.ui-barra .ui-workspace-brand{min-width:180px}
.ui-barra .ui-workspace-menu>summary{padding:8px 11px;min-height:32px}
.ui-barra .ui-btn.primario {padding:8px 15px}
.ui-raiz .ui-workspace-menu .ui-workspace-dropdown{z-index:100;box-shadow:0 18px 48px #0008}
.ui-canvas-menu .ui-workspace-dropdown{
  width:min(404px,calc(100vw - 48px));max-width:404px;
  max-height:min(570px,70vh);padding:0!important;
  overflow:auto;display:block;
}
.ui-canvas-menu .ui-resolucion{
  display:grid;grid-template-columns:minmax(0,1fr);
  gap:0;padding:0;background:var(--bg-secondary);
  border:none;max-height:none!important;overflow:visible!important;
}
.ui-resolution-group{min-width:0;padding:14px 16px;border-bottom:1px solid var(--border);display:grid;gap:9px}
.ui-resolution-group:last-child{border-bottom:0}
.ui-resolution-group h4{font-size:11px;letter-spacing:.06em;text-transform:uppercase;color:var(--text-tertiary);margin:0;font-weight:700}
.ui-resolution-note{font-size:11px;line-height:1.45;color:var(--text-tertiary);margin:0}
.ui-resolution-label{font-size:11px;color:var(--text-secondary,var(--text-tertiary))}
.ui-canvas-menu .ui-res-preset{width:100%;min-width:0;max-width:100%;flex:auto}
.ui-canvas-menu .ui-resolucion .ui-sel{height:34px;min-width:0;width:100%;max-width:none;padding:7px 9px;border-radius:6px}
.ui-resolution-sizes {display:flex;align-items:center;gap:9px;min-width:0}
.ui-resolution-sizes .ui-res-num{width:88px;min-width:0;max-width:110px;flex:1;height:34px}
.ui-resolution-sizes .ui-res-info{margin-left:auto;width:48px}
.ui-resolution-action {display:flex;align-items:center;gap:10px}
.ui-resolution-action .ui-res-estrategia {flex:1;min-width:0}
.ui-resolution-action .ui-btn{width:auto!important;flex:0 0 auto;min-height:34px}
.ui-resolution-checks {display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:10px 6px;padding:5px 0}
.ui-resolution-checks .ui-casilla {font-size:12px;white-space:normal;align-items:flex-start;line-height:1.35}
.ui-resolution-checks input {margin:2px 5px 0 0}
.ui-workspace-bar{position:relative;z-index:5;gap:8px;padding:7px 13px;min-height:46px}
.ui-workspace-caption{min-width:45px}
.ui-workspace-btn {border-radius:6px;padding:8px 11px!important;font-size:12px}
.ui-workspace-resizer{flex:0 0 5px;width:5px}
.ui-raiz .ui-cuerpo {min-height:160px;flex:1;overflow:hidden}
.ui-raiz .ui-panel-izq{width:235px;min-width:175px}
.ui-raiz .ui-panel-der{width:325px;min-width:245px}
.ui-raiz .ui-cabecera-panel{padding:11px 12px}
.ui-raiz .ui-capa{min-height:38px}
.ui-raiz .ui-inspector{padding:14px 15px}
.ui-raiz .ui-etiqueta{width:108px;line-height:1.35}
.ui-raiz .ui-fila{align-items:flex-start}
.ui-raiz .ui-fila>.ui-etiqueta{padding-top:6px}
.ui-raiz .ui-titulillo{padding-bottom:8px}
.ui-raiz .ui-lienzo-zona{
  padding:18px;min-height:0;flex:1;
  background:radial-gradient(ellipse at center,rgba(64,91,131,.12),transparent 76%),#101a28;
}
.ui-raiz .ui-pie-lienzo{
  display:flex;flex-wrap:nowrap;white-space:nowrap;overflow-x:auto;
  padding:8px 12px;min-height:43px;gap:9px;
}
.ui-raiz .ui-pie-lienzo .ui-sel{width:auto!important;min-width:67px;max-width:190px}
.ui-raiz .ui-tiempo {height:182px;min-height:0;overflow:hidden}
.ui-raiz .ui-tiempo-barra{
  display:flex;flex-wrap:nowrap;align-items:center;min-width:0;
  height:44px;min-height:44px;padding:6px 12px;gap:10px;
}
.ui-raiz .ui-tiempo-barra .ui-sel{width:180px;max-width:180px;flex:0 1 180px}
.ui-raiz .ui-tiempo-barra input[type="range"]{width:auto;min-width:80px;flex:1 1 auto}
.ui-workspace-hide-timeline .ui-tiempo{height:44px!important;min-height:44px!important}
.ui-workspace-hide-timeline .ui-tiempo-barra .ui-timeline-advanced {display:none!important}
.ui-workspace-hide-timeline .ui-tiempo-barra{border-bottom:0}
.ui-workspace-focus .ui-panel-izq,.ui-workspace-focus .ui-panel-der{display:none}
.ui-workspace-focus .ui-workspace-resizer{display:none}
.ui-workspace-focus .ui-lienzo-zona{padding:14px}
.ui-raiz .ui-workspace-status{min-height:25px;flex:0 0 25px}
.ui-workspace-dropdown .ui-workspace-choices {grid-template-columns:repeat(2,minmax(125px,1fr));min-width:300px}
.ui-workspace-dropdown .ui-workspace-search {height:36px}
@media(max-width:1200px){
  .ui-barra .ui-workspace-brand{min-width:128px}
  .ui-workspace-brand small{display:none}
  .ui-raiz .ui-panel-izq{width:200px}
  .ui-raiz .ui-panel-der{width:285px}
  .ui-workspace-btn{padding:7px 8px!important}
}
@media(max-width:900px){
  .ui-raiz>.ui-barra{max-height:none}
  .ui-workspace-caption,.ui-workspace-divider {display:none}
  .ui-raiz .ui-panel-izq{width:175px;min-width:150px}
  .ui-raiz .ui-panel-der{width:255px;min-width:200px}
}

/* Inspector contextual 2.2 · sin recortar propiedades originales. */
.ui-raiz .ui-inspector{padding:10px 13px 18px}
.ui-inspector-context{display:flex;align-items:center;justify-content:space-between;gap:10px;
  padding:6px 3px 11px;min-width:0;color:var(--text-primary)}
.ui-inspector-context strong{font-size:12px;font-weight:700;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.ui-inspector-back{font-size:11px;font-family:inherit;background:transparent;border:0;color:var(--accent);
  cursor:pointer;padding:6px 2px;white-space:nowrap}
.ui-inspector-back:hover{text-decoration:underline}
.ui-inspector-tabs{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:4px;
  position:sticky;top:-10px;background:var(--ui-ux-panel,var(--bg-secondary));
  padding:3px 0 11px;z-index:4;border-bottom:1px solid var(--border)}
.ui-inspector-tab{font-size:11px!important;line-height:1.25!important;min-width:0;
  padding:9px 2px;border-radius:6px;border:1px solid transparent;
  color:var(--text-secondary,var(--text-tertiary));background:transparent;cursor:pointer}
.ui-inspector-tab:hover{background:var(--bg-hover,var(--bg-primary))}
.ui-inspector-tab.activo{color:var(--text-primary);border-color:var(--accent);
  background:var(--bg-primary);font-weight:700}
.ui-inspector-note{padding:11px 12px;margin:10px 0 14px;
  border-radius:7px;background:var(--bg-primary);border:1px solid var(--border);
  color:var(--text-secondary,var(--text-tertiary));font-size:11px;line-height:1.5}
.ui-inspector-open-timeline{width:100%;padding:9px!important;margin-top:12px}
`;
