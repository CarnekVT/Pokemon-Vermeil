const invoke = window.__TAURI__.core.invoke;

// Guardamos referencias para poder limpiar (dispose) cuando el mod se desactive
let menuDisposable = null;
let i18nDisposable = null;
let registeredTags = new Map();
let customTags = [];

// Rutas en el proyecto
const DIR_PATH = "Plugins/MakerStudio/003_Editor";
const FILE_PATH = `${DIR_PATH}/.custom_terraintags`;

// Diccionario de traducciones al español
const esTranslations = {
  "Manage Terrain Tags...": "Gestionar Terrain Tags...",
  "Terrain Tag Manager": "Gestor de Terrain Tags",
  "Add New Tag": "Añadir Nueva Tag",
  "Tag ID": "ID de la Tag",
  "Name (e.g. Lava, Ice...)": "Nombre (ej. Lava, Hielo...)",
  "Add": "Añadir",
  "Registered Tags": "Tags Registradas",
  "No custom tags.": "No hay tags personalizadas.",
  "Rename": "Renombrar",
  "Delete": "Borrar",
  "Rename Tag [{id}]": "Renombrar Tag [{id}]",
  "Enter the new name:": "Introduce el nuevo nombre:",
  "Delete Tag": "Borrar Tag",
  "Are you sure you want to delete tag [{id}]?": "¿Estás seguro de que quieres borrar la tag [{id}]?",
  "ID must be 18 or higher.": "El ID debe ser 18 o superior.",
  "Name cannot be empty.": "El nombre no puede estar vacío.",
  "ID {id} is already in use.": "El ID {id} ya está en uso.",
  "Tag [{id}] added successfully.": "Tag [{id}] añadida correctamente.",
  "Tag [{id}] renamed to {name}.": "Tag [{id}] renombrada a {name}.",
  "Tag [{id}] deleted.": "Tag [{id}] eliminada.",
  // NUEVAS TRADUCCIONES
  "Import": "Importar",
  "Export": "Exportar",
  "Export Tags": "Exportar Tags",
  "Select tags to export:": "Selecciona las tags a exportar:",
  "Export Selected": "Exportar Seleccionadas",
  "Cancel": "Cancelar",
  "Invalid file format.": "Formato de archivo inválido.",
  "Conflict: Tag [{id}]": "Conflicto: Tag [{id}]",
  "Tag [{id}] already exists as '{oldName}'. Overwrite with '{newName}'?": "La tag [{id}] ya existe como '{oldName}'. ¿Sobrescribir con '{newName}'?",
  "Overwrite": "Sobrescribir",
  "Keep Old": "Mantener original",
  "Successfully exported to {path}": "Exportado con éxito a {path}",
  "Import completed.": "Importación completada."
};

export async function activate(ctx) {
  i18nDisposable = ctx.i18n.addTranslations("es", esTranslations);

  await loadTags(ctx);
  
  for (const tag of customTags) {
    const disp = ctx.tileset.registerTerrainTag({ id: tag.id, name: tag.name });
    registeredTags.set(tag.id, disp);
  }

  menuDisposable = ctx.menu.registerMenuItem({
    menu: "Mods",
    label: ctx.i18n.t("Manage Terrain Tags..."),
    icon: "layers",
    handler: () => openManagerDialog(ctx)
  });
}

export function deactivate() {
  if (menuDisposable) menuDisposable.dispose();
  if (i18nDisposable) i18nDisposable.dispose();
  for (const disp of registeredTags.values()) {
    disp.dispose();
  }
  registeredTags.clear();
}

// --- Lógica de Archivos (FS del Proyecto) ---

async function loadTags(ctx) {
  if (await ctx.fs.projectExists(FILE_PATH)) {
    try {
      const text = await ctx.fs.readProjectFile(FILE_PATH);
      customTags = JSON.parse(text);
    } catch (e) {
      ctx.log.error(`Error reading ${FILE_PATH}`, e);
      customTags = [];
    }
  } else {
    customTags = [];
  }
}

async function saveTags(ctx) {
  if (!(await ctx.fs.projectExists(DIR_PATH))) {
    await ctx.fs.projectMkdir(DIR_PATH);
  }
  await ctx.fs.writeProjectFile(FILE_PATH, JSON.stringify(customTags, null, 2));
}

// --- Lógica de la Interfaz (UI) ---

function getNextId() {
  const existingIds = new Set(customTags.map(t => t.id));
  let nextId = 18;
  while (existingIds.has(nextId)) {
    nextId++;
  }
  return nextId;
}

function openManagerDialog(ctx) {
  const { close } = ctx.ui.showCustomDialog({
    title: ctx.i18n.t("Terrain Tag Manager"),
    width: "520px",
    render(body) {
      body.innerHTML = `
        <div style="padding: 16px; color: var(--text-primary); font-family: inherit;">
          <div style="margin-bottom: 16px;">
            <h3 style="margin-top: 0; font-size: 14px; margin-bottom: 8px;">${ctx.i18n.t("Add New Tag")}</h3>
            <div style="display: flex; gap: 8px; align-items: center;">
              <input type="number" id="tt-id" min="18" title="${ctx.i18n.t("Tag ID")}" 
                     style="width: 70px; background: var(--input-bg); color: var(--text-primary); border: 1px solid var(--border); padding: 6px; border-radius: 4px;" />
              <input type="text" id="tt-name" placeholder="${ctx.i18n.t("Name (e.g. Lava, Ice...)")}" 
                     style="flex: 1; background: var(--input-bg); color: var(--text-primary); border: 1px solid var(--border); padding: 6px; border-radius: 4px;" />
              <button id="tt-add" style="background: var(--success); color: white; border: none; padding: 6px 12px; border-radius: 4px; cursor: pointer; font-weight: bold;">
                ${ctx.i18n.t("Add")}
              </button>
            </div>
          </div>
          
          <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px;">
            <h3 style="margin: 0; font-size: 14px;">${ctx.i18n.t("Registered Tags")}</h3>
            <div>
              <button id="tt-import" style="background: var(--bg-tertiary); color: var(--text-primary); border: 1px solid var(--border); border-radius: 4px; cursor: pointer; padding: 4px 8px; font-size: 12px; margin-right: 4px;">
                ${ctx.i18n.t("Import")}
              </button>
              <button id="tt-export" style="background: var(--bg-tertiary); color: var(--text-primary); border: 1px solid var(--border); border-radius: 4px; cursor: pointer; padding: 4px 8px; font-size: 12px;">
                ${ctx.i18n.t("Export")}
              </button>
            </div>
          </div>

          <div style="border: 1px solid var(--border); border-radius: 4px; background: var(--bg-secondary); max-height: 250px; overflow-y: auto;">
            <ul id="tt-list" style="list-style: none; padding: 0; margin: 0;"></ul>
          </div>
        </div>
      `;

      const listEl = body.querySelector("#tt-list");
      const idInput = body.querySelector("#tt-id");
      const nameInput = body.querySelector("#tt-name");
      const addBtn = body.querySelector("#tt-add");
      const importBtn = body.querySelector("#tt-import");
      const exportBtn = body.querySelector("#tt-export");

      const updateListUI = () => {
        listEl.innerHTML = "";
        idInput.value = getNextId();
        
        if (customTags.length === 0) {
          listEl.innerHTML = `<li style="padding: 8px; color: var(--text-tertiary); text-align: center;">${ctx.i18n.t("No custom tags.")}</li>`;
          return;
        }

        customTags.sort((a, b) => a.id - b.id).forEach(tag => {
          const li = document.createElement("li");
          li.style.cssText = "display: flex; justify-content: space-between; align-items: center; padding: 8px; border-bottom: 1px solid var(--border);";
          
          li.innerHTML = `
            <span><strong style="color: var(--accent);">[${tag.id}]</strong> ${tag.name}</span>
            <div>
              <button data-id="${tag.id}" class="tt-ren" style="background: var(--accent); color: var(--accent-text); border: none; border-radius: 4px; cursor: pointer; padding: 4px 8px; font-size: 12px; margin-right: 4px;">
                ${ctx.i18n.t("Rename")}
              </button>
              <button data-id="${tag.id}" class="tt-del" style="background: var(--danger); color: white; border: none; border-radius: 4px; cursor: pointer; padding: 4px 8px; font-size: 12px;">
                ${ctx.i18n.t("Delete")}
              </button>
            </div>
          `;
          listEl.appendChild(li);
        });

        body.querySelectorAll(".tt-ren").forEach(btn => {
          btn.addEventListener("click", async (e) => {
            const idToRename = parseInt(e.target.getAttribute("data-id"), 10);
            const tag = customTags.find(t => t.id === idToRename);
            if (!tag) return;

            const newName = await ctx.ui.showInputDialog({
              title: ctx.i18n.t("Rename Tag [{id}]", { id: idToRename }),
              message: ctx.i18n.t("Enter the new name:"),
              defaultValue: tag.name
            });

            if (newName && newName.trim() !== "" && newName !== tag.name) {
              await renameTag(ctx, idToRename, newName.trim());
              updateListUI();
            }
          });
        });

        body.querySelectorAll(".tt-del").forEach(btn => {
          btn.addEventListener("click", async (e) => {
            const idToDelete = parseInt(e.target.getAttribute("data-id"), 10);
            const confirm = await ctx.ui.confirmDestructive({
              title: ctx.i18n.t("Delete Tag"),
              message: ctx.i18n.t("Are you sure you want to delete tag [{id}]?", { id: idToDelete }),
              confirmLabel: ctx.i18n.t("Delete")
            });

            if (confirm) {
              await deleteTag(ctx, idToDelete);
              updateListUI();
            }
          });
        });
      };

      addBtn.addEventListener("click", async () => {
        const id = parseInt(idInput.value, 10);
        const name = nameInput.value.trim();

        if (isNaN(id) || id < 18) {
          ctx.ui.showToast({ message: ctx.i18n.t("ID must be 18 or higher."), level: "error" });
          return;
        }
        if (!name) {
          ctx.ui.showToast({ message: ctx.i18n.t("Name cannot be empty."), level: "error" });
          return;
        }
        if (customTags.some(t => t.id === id)) {
          ctx.ui.showToast({ message: ctx.i18n.t("ID {id} is already in use.", { id }), level: "error" });
          return;
        }

        await addTag(ctx, id, name);
        nameInput.value = "";
        nameInput.focus();
        updateListUI();
      });

      // Eventos de Importar y Exportar
      importBtn.addEventListener("click", () => handleImport(ctx, updateListUI));
      exportBtn.addEventListener("click", () => openExportDialog(ctx));

      updateListUI();
    }
  });
}

// --- Lógica de Importar / Exportar ---

async function handleImport(ctx, updateListUI) {
  // 1. Pedir archivo al usuario
  const paths = await ctx.ui.showFilePicker({
    filters: [{ name: "JSON", extensions: ["json"] }]
  });
  
  if (!paths || paths.length === 0) return;

  try {
    // 2. Leer el archivo usando Tauri (ya que puede estar en cualquier parte del PC)
    const content = await invoke("read_text_file", { path: paths[0] });
    const importedTags = JSON.parse(content);

    if (!Array.isArray(importedTags)) throw new Error("Not an array");

    // 3. Procesar cada tag importada
    for (const tag of importedTags) {
      if (typeof tag.id !== "number" || typeof tag.name !== "string") continue;

      const existing = customTags.find(t => t.id === tag.id);
      
      if (existing) {
        // Si existe y el nombre es distinto, preguntamos al usuario
        if (existing.name !== tag.name) {
          const overwrite = await ctx.ui.showConfirmDialog({
            title: ctx.i18n.t("Conflict: Tag [{id}]", { id: tag.id }),
            message: ctx.i18n.t("Tag [{id}] already exists as '{oldName}'. Overwrite with '{newName}'?", { 
              id: tag.id, oldName: existing.name, newName: tag.name 
            }),
            confirmLabel: ctx.i18n.t("Overwrite"),
            cancelLabel: ctx.i18n.t("Keep Old")
          });

          if (overwrite) {
            await renameTag(ctx, tag.id, tag.name);
          }
        }
      } else {
        // Si no existe, la añadimos directamente
        await addTag(ctx, tag.id, tag.name);
      }
    }

    ctx.ui.showToast({ message: ctx.i18n.t("Import completed."), level: "info" });
    updateListUI();

  } catch (e) {
    ctx.log.error("Import failed", e);
    ctx.ui.showToast({ message: ctx.i18n.t("Invalid file format."), level: "error" });
  }
}

function openExportDialog(ctx) {
  if (customTags.length === 0) {
    ctx.ui.showToast({ message: ctx.i18n.t("No custom tags."), level: "warn" });
    return;
  }

  const { close } = ctx.ui.showCustomDialog({
    title: ctx.i18n.t("Export Tags"),
    width: "400px",
    render(body) {
      body.innerHTML = `
        <div style="padding: 16px; color: var(--text-primary); font-family: inherit;">
          <p style="margin-top: 0; margin-bottom: 12px;">${ctx.i18n.t("Select tags to export:")}</p>
          <div style="border: 1px solid var(--border); border-radius: 4px; background: var(--bg-secondary); max-height: 200px; overflow-y: auto; margin-bottom: 16px; padding: 8px;">
            ${customTags.sort((a, b) => a.id - b.id).map(tag => `
              <label style="display: flex; align-items: center; gap: 8px; margin-bottom: 4px; cursor: pointer;">
                <input type="checkbox" class="export-cb" value="${tag.id}" checked />
                <span><strong style="color: var(--accent);">[${tag.id}]</strong> ${tag.name}</span>
              </label>
            `).join("")}
          </div>
          <div style="display: flex; justify-content: flex-end; gap: 8px;">
            <button id="btn-cancel" style="background: transparent; color: var(--text-primary); border: 1px solid var(--border); padding: 6px 12px; border-radius: 4px; cursor: pointer;">
              ${ctx.i18n.t("Cancel")}
            </button>
            <button id="btn-export" style="background: var(--accent); color: var(--accent-text); border: none; padding: 6px 12px; border-radius: 4px; cursor: pointer; font-weight: bold;">
              ${ctx.i18n.t("Export Selected")}
            </button>
          </div>
        </div>
      `;

      body.querySelector("#btn-cancel").addEventListener("click", () => close());
      
      body.querySelector("#btn-export").addEventListener("click", async () => {
        // Recoger los IDs seleccionados
        const checkboxes = body.querySelectorAll(".export-cb:checked");
        const selectedIds = Array.from(checkboxes).map(cb => parseInt(cb.value, 10));
        
        if (selectedIds.length === 0) return;

        const tagsToExport = customTags.filter(t => selectedIds.includes(t.id));

        // Pedir ruta para guardar
        const savePath = await ctx.ui.showSavePicker({
          defaultPath: "terraintags.json",
          filters: [{ name: "JSON", extensions: ["json"] }]
        });

        if (savePath) {
          try {
            // Escribir archivo en el PC del usuario
            await invoke("write_text_file", { 
              path: savePath, 
              content: JSON.stringify(tagsToExport, null, 2) 
            });
            ctx.ui.showToast({ message: ctx.i18n.t("Successfully exported to {path}", { path: savePath }), level: "info" });
            close();
          } catch (e) {
            ctx.log.error("Export failed", e);
            ctx.ui.showToast({ message: "Error exporting file.", level: "error" });
          }
        }
      });
    }
  });
}

// --- Funciones de Datos ---

async function addTag(ctx, id, name) {
  customTags.push({ id, name });
  await saveTags(ctx);
  
  const disp = ctx.tileset.registerTerrainTag({ id, name });
  registeredTags.set(id, disp);
}

async function renameTag(ctx, id, newName) {
  const tag = customTags.find(t => t.id === id);
  if (tag) {
    tag.name = newName;
    await saveTags(ctx);

    const oldDisp = registeredTags.get(id);
    if (oldDisp) oldDisp.dispose();

    const newDisp = ctx.tileset.registerTerrainTag({ id, name: newName });
    registeredTags.set(id, newDisp);
  }
}

async function deleteTag(ctx, id) {
  customTags = customTags.filter(t => t.id !== id);
  await saveTags(ctx);
  
  const disp = registeredTags.get(id);
  if (disp) {
    disp.dispose();
    registeredTags.delete(id);
  }
}