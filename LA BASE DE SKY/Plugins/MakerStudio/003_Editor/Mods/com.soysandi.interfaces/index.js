//=============================================================================
// Editor de Interfaces: punto de entrada del mod.
//
// Abre una ventana propia dentro de MakerStudio (ctx.ui.showCustomDialog) donde
// se montan las pantallas del juego. Lo que guarda son ficheros UI/<nombre>.json,
// que es lo que lee el plugin [LBDS] Interfaces dentro del juego.
//
// Se usa showCustomDialog y no registerPanel a proposito: el dialogo es la via
// que ya esta probada en este editor (la usa el mod pbs-editor), mientras que los
// paneles acoplados no los usa ningun mod instalado y no puedo comprobarlos.
//=============================================================================

import { EditorInterfaces } from "./editor.js";

let _dialogo = null;
let _editor = null;

const ICONO = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.3" stroke-linecap="round" stroke-linejoin="round"><rect x="1.5" y="2.5" width="13" height="11" rx="1"/><line x1="1.5" y1="5.5" x2="14.5" y2="5.5"/><rect x="3.5" y="7.5" width="4" height="4" rx="0.5"/><line x1="9.5" y1="8" x2="12.5" y2="8"/><line x1="9.5" y1="10" x2="12.5" y2="10"/></svg>`;

function abrirEditor(ctx) {
  if (_dialogo) return;

  _dialogo = ctx.ui.showCustomDialog({
    title: "Editor de Interfaces",
    width: "94vw",
    height: "92vh",
    render(cuerpo) {
      _editor = new EditorInterfaces(ctx, cuerpo);
      return () => {
        _editor?.destruir();
        _editor = null;
        _dialogo = null;
      };
    },
    onCloseRequest: async () => {
      if (!_editor || !_editor.sucio) { _dialogo.close(); return; }

      // Cerrar con cambios sin guardar pierde trabajo, asi que se pregunta. Si
      // el editor no expone este dialogo, se pregunta con el de confirmar, y si
      // tampoco, se guarda antes de cerrar: perder trabajo no es una opcion.
      try {
        const r = await ctx.ui.showUnsavedChangesDialog({
          message: "Hay cambios sin guardar en el Editor de Interfaces."
        });
        if (r === "save") {
          if (await _editor.guardar()) _dialogo.close();
        } else if (r === "discard") {
          _dialogo.close();
        }
        // "cancel": no se hace nada y la ventana se queda abierta.
      } catch {
        await _editor.guardar();
        _dialogo.close();
      }
    }
  });
}

export function activate(ctx) {
  ctx.menu.registerMenuItem({
    menu: "Mods",
    label: "Abrir el Editor de Interfaces",
    shortcut: "Ctrl+Shift+U",
    icon: ICONO,
    handler: () => abrirEditor(ctx)
  });
}

export function deactivate() {
  if (_editor) { _editor.destruir(); _editor = null; }
  if (_dialogo) { _dialogo.close(); _dialogo = null; }
}
