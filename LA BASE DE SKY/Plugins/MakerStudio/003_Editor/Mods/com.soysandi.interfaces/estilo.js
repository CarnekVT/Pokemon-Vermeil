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
`;
