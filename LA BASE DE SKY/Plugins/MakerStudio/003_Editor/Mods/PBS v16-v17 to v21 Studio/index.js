const PANEL_ID = 'vermeil.pbs-v16-v17-to-v21';

const CSS = `
.pcv{height:100%;min-height:0;display:grid;grid-template-rows:auto auto minmax(0,1fr) auto;background:var(--bg-primary);color:var(--text-primary);font:13px/1.4 inherit}.pcv *{box-sizing:border-box}.pcv-head{display:flex;align-items:center;gap:12px;padding:14px 16px;border-bottom:1px solid var(--border)}.pcv-title{font-size:16px;font-weight:700}.pcv-sub{font-size:11px;color:var(--text-secondary);margin-top:2px}.pcv-sp{flex:1}.pcv-btn,.pcv-select{height:32px;border:1px solid var(--border);border-radius:5px;background:var(--bg-secondary);color:inherit;padding:0 10px;font:inherit;cursor:pointer}.pcv-btn:hover{border-color:var(--accent)}.pcv-btn.primary{background:var(--accent);color:var(--text-on-accent,#fff);border-color:var(--accent);font-weight:700}.pcv-controls{display:flex;gap:8px;align-items:center;flex-wrap:wrap;padding:10px 16px;border-bottom:1px solid var(--border)}.pcv-controls label{font-size:11px;color:var(--text-secondary)}.pcv-controls .pcv-select{min-width:130px}.pcv-work{display:grid;grid-template-columns:minmax(0,1fr) minmax(0,1fr);gap:12px;padding:12px 16px;min-height:0}.pcv-pane{display:grid;grid-template-rows:auto minmax(0,1fr);min-height:0}.pcv-pane-head{display:flex;align-items:center;justify-content:space-between;padding:0 0 7px;font-weight:700}.pcv-pane-head small{font-weight:400;color:var(--text-secondary)}.pcv-text{width:100%;height:100%;min-height:260px;resize:none;border:1px solid var(--border);border-radius:5px;background:var(--bg-secondary);color:var(--text-primary);padding:10px;font:12px/1.45 ui-monospace,SFMono-Regular,Consolas,monospace;tab-size:2}.pcv-text:focus{outline:1px solid var(--accent);border-color:var(--accent)}.pcv-status{display:grid;grid-template-columns:minmax(0,1fr) auto;gap:12px;align-items:start;padding:10px 16px;border-top:1px solid var(--border)}.pcv-msg{color:var(--text-secondary);font-size:12px}.pcv-warnings{color:var(--text-secondary);font-size:11px;max-height:88px;overflow:auto}.pcv-warnings b{color:var(--text-primary)}.pcv-warnings .warn{color:var(--warning,#d99b32)}@media(max-width:900px){.pcv-work{grid-template-columns:1fr}.pcv-text{min-height:220px}.pcv-status{grid-template-columns:1fr}}
`;

const TYPES = {
  moves: { label: 'Moves', file: 'moves.txt', aliases: { PP: 'TotalPP', MoveType: 'Type', Function: 'FunctionCode', Effect: 'FunctionCode' } },
  abilities: { label: 'Abilities', file: 'abilities.txt', aliases: {} },
  pokemon: { label: 'Pokemon', file: 'pokemon.txt', aliases: { Ability: 'Abilities', HiddenAbility: 'HiddenAbilities', BaseStat: 'BaseStats', EggGroup: 'EggGroups', MoveTutor: 'TutorMoves', DexEntry: 'Pokedex' } },
  items: { label: 'Items', file: 'items.txt', aliases: { Plural: 'NamePlural', BattleUse: 'BattleUse', UseInBattle: 'BattleUse' } },
  trainers: { label: 'Trainers', file: 'trainers.txt', aliases: { TrainerName: 'Name', DefeatText: 'LoseText', Party: 'Pokemon' } }
};

function esc(value) { return String(value ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c])); }
function clean(value) { return String(value ?? '').replace(/\r/g, ''); }
function notify(ctx, message, level = 'info') { try { ctx.ui.showToast({ message, level }); } catch (_) { try { ctx.ui.showToast(message, level); } catch (_) {} } }
function fileName(path) { return String(path).split(/[\\/]/).pop().toLowerCase(); }

function convert(text, type) {
  const cfg = TYPES[type];
  const lines = clean(text).split('\n');
  const warnings = [];
  const seen = new Set();
  const output = lines.map((line, index) => {
    if (!line.trim() || line.trim().startsWith('#') || !line.includes('=')) return line;
    const equals = line.indexOf('=');
    const rawKey = line.slice(0, equals).trim();
    const mapped = cfg.aliases[rawKey] || rawKey;
    if (mapped !== rawKey) warnings.push(`Línea ${index + 1}: ${rawKey} -> ${mapped}`);
    if (seen.has(mapped) && type !== 'trainers') warnings.push(`Línea ${index + 1}: clave repetida '${mapped}', se conserva porque puede ser válida en v21.`);
    seen.add(mapped);
    return `${line.slice(0, line.indexOf(rawKey))}${mapped}${line.slice(equals)}`;
  });
  if (type === 'trainers' && /(^|\n)\s*Pokemon\s*=.*,.+,/.test(clean(text))) {
    warnings.push('Trainers: revisa cada línea Pokemon con Moves/Item/AbilityIndex; los formatos antiguos de party no siempre son equivalentes.');
  }
  if (type === 'pokemon' && /(^|\n)\s*Abilities\s*=.*,.+/.test(clean(text))) {
    warnings.push('Pokemon: se conserva la lista de Abilities; comprueba HiddenAbilities y las formas regionales tras compilar.');
  }
  if (/\[[^\]]+\]\s*$/.test(clean(text))) {
    warnings.push('Los encabezados se conservaron literalmente. Esto permite copiar bloques y también archivos completos.');
  }
  return { text: output.join('\n'), warnings: [...new Set(warnings)] };
}

async function copyText(ctx, text) {
  try { if (ctx.clipboard?.writeText) { await ctx.clipboard.writeText(text); return true; } } catch (_) {}
  try { await navigator.clipboard.writeText(text); return true; } catch (_) { return false; }
}

export function activate(ctx) {
  ctx.ui.registerPanel({ id: PANEL_ID, title: 'PBS v16/v17 -> v21', icon: 'transfer', defaultPosition: 'right', defaultSize: { width: 1100, height: 760 }, showInMenu: false, render: host => render(ctx, host) });
  ctx.menu.registerMenuItem({ menu: 'Mods', label: 'PBS v16/v17 -> v21', icon: 'transfer', handler: () => ctx.ui.openPanel(PANEL_ID) });
  ctx.commands.register(`${PANEL_ID}.open`, () => ctx.ui.openPanel(PANEL_ID));
}

async function render(ctx, host) {
  host.innerHTML = `<style>${CSS}</style><div class="pcv"><header class="pcv-head"><div><div class="pcv-title">PBS v16/v17 -> v21</div><div class="pcv-sub">Editor de conversión para copiar, pegar o guardar datos de Essentials</div></div><div class="pcv-sp"></div><button class="pcv-btn" data-load>Leer archivo PBS</button><button class="pcv-btn" data-copy>Copiar resultado</button><button class="pcv-btn primary" data-save>Guardar en PBS</button></header><div class="pcv-controls"><label for="pcv-type">Formato</label><select id="pcv-type" class="pcv-select" data-type>${Object.entries(TYPES).map(([key, value]) => `<option value="${key}">${value.label}</option>`).join('')}</select><label for="pcv-source">Origen</label><select id="pcv-source" class="pcv-select" data-source><option>Auto / v16 / v17</option><option>v16</option><option>v17</option></select><button class="pcv-btn" data-convert>Convertir</button><span class="pcv-sub">Conserva campos desconocidos y muestra advertencias antes de usar el resultado.</span></div><main class="pcv-work"><section class="pcv-pane"><div class="pcv-pane-head"><span>Entrada PBS</span><small data-input-meta>pega un bloque o archivo completo</small></div><textarea class="pcv-text" data-input spellcheck="false" placeholder="[MOVE_ID]\nName = Nombre\nType = NORMAL\n..."></textarea></section><section class="pcv-pane"><div class="pcv-pane-head"><span>Salida v21</span><small data-output-meta>todavía no convertido</small></div><textarea class="pcv-text" data-output spellcheck="false" readonly></textarea></section></main><footer class="pcv-status"><div class="pcv-msg" data-message>Listo.</div><div class="pcv-warnings" data-warnings></div></footer></div>`;
  const input = host.querySelector('[data-input]');
  const output = host.querySelector('[data-output]');
  const type = host.querySelector('[data-type]');
  const inputMeta = host.querySelector('[data-input-meta]');
  const outputMeta = host.querySelector('[data-output-meta]');
  const message = host.querySelector('[data-message]');
  const warnings = host.querySelector('[data-warnings]');
  let converted = { text: '', warnings: [] };

  function run() {
    converted = convert(input.value, type.value);
    output.value = converted.text;
    outputMeta.textContent = `${converted.text.split('\n').length} líneas · formato v21`; 
    message.textContent = converted.warnings.length ? `Convertido con ${converted.warnings.length} aviso(s).` : 'Convertido sin avisos.';
    warnings.innerHTML = converted.warnings.length ? `<b>Revisión recomendada</b><ul>${converted.warnings.map(item => `<li class="warn">${esc(item)}</li>`).join('')}</ul>` : '<b>Sin avisos de conversión.</b>';
  }
  async function loadFile() {
    const path = `PBS/${TYPES[type.value].file}`;
    try { input.value = await ctx.fs.readProjectFile(path); inputMeta.textContent = path; run(); message.textContent = `Cargado ${path}.`; }
    catch (_) { notify(ctx, `No se encontró ${path}; pega el PBS manualmente.`, 'warn'); }
  }
  async function saveFile() {
    if (!converted.text.trim()) run();
    const path = `PBS/${TYPES[type.value].file}`;
    try { await ctx.fs.writeProjectFile(path, converted.text.endsWith('\n') ? converted.text : `${converted.text}\n`); notify(ctx, `Guardado en ${path}.`, 'info'); message.textContent = `Guardado en ${path}.`; }
    catch (_) { notify(ctx, `No se pudo guardar ${path}.`, 'error'); }
  }
  host.querySelector('[data-convert]').onclick = run;
  host.querySelector('[data-load]').onclick = loadFile;
  host.querySelector('[data-save]').onclick = saveFile;
  host.querySelector('[data-copy]').onclick = async () => {
    if (!converted.text.trim()) run();
    const copied = await copyText(ctx, converted.text);
    notify(ctx, copied ? 'Resultado copiado al portapapeles.' : 'No se pudo acceder al portapapeles.', copied ? 'info' : 'error');
  };
  type.onchange = () => { inputMeta.textContent = 'pega un bloque o archivo completo'; output.value = ''; converted = { text: '', warnings: [] }; outputMeta.textContent = 'todavía no convertido'; };
}
