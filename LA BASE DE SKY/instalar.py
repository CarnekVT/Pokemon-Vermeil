import os

print("Extrayendo e instalando Save Inspector Studio...")

archivos = {
    # 1. Manifiesto del Mod (Maker Studio)
    "Mods/Save Inspector/manifest.json": """{
  "id": "save-inspector-studio",
  "name": "Save Inspector Studio",
  "version": "1.0.0",
  "authors": [{ "name": "CarnekVT" }],
  "description": "Inspector bidireccional para depurar Objetos y Movimientos externamente.",
  "apiVersion": "1.0.0",
  "main": "index.js",
  "permissions": ["fs.project", "fs.write.project", "ui.dialogs", "ui.toasts"]
}""",

    # 2. Inicializador del Panel
    "Mods/Save Inspector/index.js": """import { renderSaveInspector } from "./app.js";
const PANEL_ID = "save-inspector-studio.main";

export function activate(ctx) {
  ctx.log.info("Save Inspector Studio activado");
  ctx.ui.registerPanel({
    id: PANEL_ID, title: "Save Inspector", icon: "database",
    defaultPosition: "right", defaultSize: { width: 450, height: 800 },
    showInMenu: false, render: (host) => renderSaveInspector(ctx, host)
  });
  ctx.menu.registerMenuItem({
    menu: "Mods", label: "Save Inspector", icon: "database",
    shortcut: "Ctrl+Shift+I", handler: () => ctx.ui.openPanel(PANEL_ID)
  });
}""",

    # 3. Interfaz del Mod (App.js)
    "Mods/Save Inspector/app.js": """export async function renderSaveInspector(ctx, host) {
  host.innerHTML = `
    <style>
      .si-container { font-family: sans-serif; padding: 12px; color: #ccc; background: #1e1e1e; height: 100%; overflow-y: auto; }
      .si-btn { background: #007acc; color: white; border: none; padding: 8px; border-radius: 4px; cursor: pointer; width: 100%; margin-bottom: 10px; font-weight: bold;}
      .si-btn:hover { background: #0098ff; }
      .si-btn-save { background: #238636; display: none; }
      .si-card { background: #252526; border: 1px solid #3c3c3c; padding: 12px; margin-bottom: 12px; border-radius: 6px; }
      .si-input { width: 100%; background: #3c3c3c; border: 1px solid #555; color: #fff; padding: 6px; margin-bottom: 5px; font-family: monospace; box-sizing: border-box;}
      .si-title { font-size: 14px; color: #fff; border-bottom: 1px solid #333; padding-bottom: 6px; margin-top:0;}
      .si-label { font-size: 11px; color: #999; text-transform: uppercase; }
    </style>
    <div class="si-container">
      <button id="si-load" class="si-btn">⬇ Cargar (party_debug.json)</button>
      <button id="si-save" class="si-btn si-btn-save">⬆ Inyectar Cambios</button>
      <div id="si-content"><p style="text-align:center; color:#666;">Exporta el equipo desde Essentials para comenzar.</p></div>
    </div>
  `;

  const FILE_PATH = "Data/party_debug.json";
  let partyData = [];

  host.querySelector("#si-load").onclick = async () => {
    try {
      partyData = JSON.parse(await ctx.fs.project.readFile(FILE_PATH, "utf-8"));
      let html = "";
      partyData.forEach((p, i) => {
        html += `<div class="si-card"><h3 class="si-title">Lv.${p.level} ${p.name}</h3>
          <label class="si-label">Item ID:</label><input class="si-input item-in" data-idx="${i}" value="${p.item}">
          <label class="si-label">Moves IDs:</label>`;
        for(let m=0; m<4; m++) html += `<input class="si-input move-in" data-idx="${i}" value="${p.moves[m]||""}">`;
        html += `</div>`;
      });
      host.querySelector("#si-content").innerHTML = html;
      host.querySelector("#si-save").style.display = "block";
      ctx.ui.toasts.success("Equipo cargado correctamente.");
    } catch { ctx.ui.toasts.error("No se encontró el archivo JSON. Exórtalo primero."); }
  };

  host.querySelector("#si-save").onclick = async () => {
    host.querySelectorAll(".item-in").forEach(inpt => partyData[inpt.dataset.idx].item = inpt.value);
    partyData.forEach(p => p.moves = []);
    host.querySelectorAll(".move-in").forEach(inpt => { if(inpt.value) partyData[inpt.dataset.idx].moves.push(inpt.value); });
    await ctx.fs.project.writeFile(FILE_PATH, JSON.stringify(partyData, null, 2));
    ctx.ui.toasts.success("Cambios inyectados. Ya puedes cargarlos en el juego.");
  };
}""",

    # 4. Metadata del Plugin de Essentials
    "Plugins/[CARNEK] Save Inspector Runtime/meta.txt": """Name = [CARNEK] Save Inspector Runtime
Version = 1.0.0
Essentials = 21.1
Credits = CarnekVT""",

    # 5. Lógica puente de Ruby
    "Plugins/[CARNEK] Save Inspector Runtime/SaveInspectorBridge.rb": """module Carnek_SaveInspector
  FILE_PATH = "Data/party_debug.json"
  
  def self.dump_party
    return false if !$Trainer || !$Trainer.party
    data = $Trainer.party.map do |p|
      { "name" => p.name, "level" => p.level, "item" => p.item_id ? p.item_id.to_s : "NONE", "moves" => p.moves.map { |m| m.id.to_s } }
    end
    File.open(FILE_PATH, "wb") { |f| f.write(pbToJSON(data)) }
    pbMessage(_INTL("Equipo exportado a JSON."))
  end
  
  def self.load_party
    return false if !File.exist?(FILE_PATH)
    json_data = pbParseJSON(File.read(FILE_PATH))
    json_data.each_with_index do |d, i|
      p = $Trainer.party[i]
      next if !p
      p.item = (d["item"] != "NONE" && !d["item"].empty?) ? d["item"].to_sym : nil
      p.forget_all_moves
      d["moves"].each { |m| p.learn_move(m.to_sym) if !m.empty? }
    end
    pbMessage(_INTL("Nuevos items y ataques aplicados."))
  end
end

MenuHandlers.add(:debug_menu, :carnek_inspector, {
  "name" => "Save Inspector", "parent" => :main,
  "effect" => proc {
    cmd = pbMessage("¿Qué deseas hacer?", ["Exportar a Studio", "Importar de Studio", "Cancelar"], -1)
    Carnek_SaveInspector.dump_party if cmd == 0
    Carnek_SaveInspector.load_party if cmd == 1
  }
})"""
}

# Crear carpetas y escribir los archivos
for ruta, contenido in archivos.items():
    os.makedirs(os.path.dirname(ruta), exist_ok=True)
    with open(ruta, "w", encoding="utf-8") as f:
        f.write(contenido.strip())

print("¡Listo! El mod de Maker Studio y el script de Essentials se instalaron al toque.")