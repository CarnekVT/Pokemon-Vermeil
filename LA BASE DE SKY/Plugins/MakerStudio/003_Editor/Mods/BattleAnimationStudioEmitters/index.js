const ANIMATIONS_PATH = 'PBS/AnimationStudio/animations.json';

const TYPES = ['None','NoMovement','Straight','Projectile','Dampened','Helix','Polar','RiseScatter','EnergyIn','EnergyOut','Orbit','Drain'];
const INITIAL_ANGLES = [
  ['None','none'],
  ['Particle → Focus','particle_to_focus'],
  ['Always Particle → Focus','always_particle_to_focus'],
  ['Emitter → Focus','emitter_to_focus'],
  ['Emitted Direction','emitted_direction'],
];

const LEGACY_COMMANDS = {
  emitX: 'spawnX',
  emitXRange: 'spawnXRange',
  emitY: 'spawnY',
  emitYRange: 'spawnYRange',
  emitR: 'spawnR',
  emitRRange: 'spawnRRange',
  emitTheta: 'spawnTheta',
  emitThetaRange: 'spawnThetaRange',
  emitAngle: 'emitDirection',
  emitAngleRange: 'emitDirectionRange',
  periodX: 'emitPeriodX',
  periodXRange: 'emitPeriodXRange',
  periodY: 'emitPeriodY',
  periodYRange: 'emitPeriodYRange',
  periodZ: 'emitPeriodZ',
  periodZRange: 'emitPeriodZRange',
  radiusXRange: 'emitRadiusXRange',
  radiusYRange: 'emitRadiusYRange',
  radiusZRange: 'emitRadiusZRange',
  clockwise: 'emitClockwise',
  zoomRange: 'emitZoomRange',
  zoomXRange: 'emitZoomXRange',
  zoomYRange: 'emitZoomYRange',
};

const LEGACY_ROOT = {
  emitX: 'spawnX', emitXRange: 'spawnXRange',
  emitY: 'spawnY', emitYRange: 'spawnYRange',
  emitR: 'spawnR', emitRRange: 'spawnRRange',
  emitTheta: 'spawnTheta', emitThetaRange: 'spawnThetaRange',
  emitAngle: 'emitDirection', emitAngleRange: 'emitDirectionRange',
};

const NUMERIC_FIELDS = {
  emitterX: 0, emitterY: 0, emitterR: 0, emitterTheta: 0,
  spawnX: 0, spawnXRange: 0, spawnY: 0, spawnYRange: 0,
  spawnR: 0, spawnRRange: 0, spawnTheta: 0, spawnThetaRange: 0,
  emitSpeed: 0, emitSpeedRange: 0, emitDirection: 0, emitDirectionRange: 0,
  emitGravity: 0, emitGravityRange: 0, emitDeceleration: 0, emitDecelerationRange: 0,
  emitRadiusXRange: 0, emitRadiusYRange: 0, emitRadiusZRange: 0,
  emitPeriodX: 100, emitPeriodXRange: 0, emitPeriodY: 100, emitPeriodYRange: 0,
  emitPeriodZ: 100, emitPeriodZRange: 0,
  emitXMultiplier: 100, emitYMultiplier: 100, emitZoomMultiplier: 100,
  emitZoomRange: 0, emitZoomXRange: 0, emitZoomYRange: 0, emitOpacityMultiplier: 100,
  spawnXOffset: 0, spawnXMultiplier: 100, spawnYOffset: 0, spawnYMultiplier: 100,
  spawnROffset: 0, spawnRMultiplier: 100, spawnThetaOffset: 0,
  randomAngleRange: 0, emitterRate: 8, emitterIntensity: 1,
};

const GROUPS = [
  { title:'Emitter', fields:[
    ['emitterRate','Rate'],['emitterIntensity','Intensity'],
    ['emitterX','X'],['emitterY','Y'],['emitterR','Radius'],['emitterTheta','Theta']
  ]},
  { title:'Emitted spawn location', fields:[
    ['spawnX','Spawn X'],['spawnXRange','X Range'],['spawnY','Spawn Y'],['spawnYRange','Y Range'],
    ['spawnR','Spawn R'],['spawnRRange','R Range'],['spawnTheta','Spawn Theta'],['spawnThetaRange','Theta Range']
  ]},
  { title:'Emitted auto-movement', fields:[
    ['emitSpeed','Speed'],['emitSpeedRange','Speed Range'],['emitDirection','Direction'],['emitDirectionRange','Direction Range'],
    ['emitGravity','Gravity'],['emitGravityRange','Gravity Range'],['emitDeceleration','Deceleration'],['emitDecelerationRange','Decel. Range'],
    ['emitRadiusXRange','Radius X Range'],['emitRadiusYRange','Radius Y Range'],['emitRadiusZRange','Radius Z Range'],
    ['emitPeriodX','Period X'],['emitPeriodXRange','Period X Range'],['emitPeriodY','Period Y'],['emitPeriodYRange','Period Y Range'],
    ['emitPeriodZ','Period Z'],['emitPeriodZRange','Period Z Range']
  ]},
  { title:'Emitted modifiers', fields:[
    ['emitXMultiplier','X Multiplier %'],['emitYMultiplier','Y Multiplier %'],
    ['emitZoomMultiplier','Zoom Multiplier %'],['emitZoomRange','Zoom Range %'],
    ['emitZoomXRange','Zoom X Range %'],['emitZoomYRange','Zoom Y Range %'],
    ['emitOpacityMultiplier','Opacity Multiplier %'],
    ['spawnXOffset','Spawn X Offset'],['spawnXMultiplier','Spawn X Multiplier %'],
    ['spawnYOffset','Spawn Y Offset'],['spawnYMultiplier','Spawn Y Multiplier %'],
    ['spawnROffset','Spawn R Offset'],['spawnRMultiplier','Spawn R Multiplier %'],
    ['spawnThetaOffset','Spawn Theta Offset']
  ]},
];

let state = { ctx:null, data:null, emitters:[], selected:null, dirty:false, dialog:null, host:null };

function el(tag, cls, text) {
  const n=document.createElement(tag);
  if(cls) n.className=cls;
  if(text!=null) n.textContent=text;
  return n;
}
function button(text, fn, cls='') {
  const b=el('button','bas-btn '+cls,text);
  b.addEventListener('click',fn);
  return b;
}
function setDirty(v=true) {
  state.dirty=v;
  const dot=state.host?.querySelector('.bas-dirty');
  if(dot) dot.textContent=v?'● Unsaved':'Saved';
}
function uid() {
  return 'ecmd_'+Date.now().toString(36)+'_'+Math.random().toString(36).slice(2,7);
}
function pbsOf(item) {
  item.clip.pbs ||= {};
  item.clip.pbs.emitterCommands ||= {};
  return item.clip.pbs;
}
function findEmitters(data) {
  const found=[], seen=new Set();
  function walk(v,path,names=[]) {
    if(!v || typeof v!=='object' || seen.has(v)) return;
    seen.add(v);
    if(Array.isArray(v)) {
      v.forEach((x,i)=>walk(x, path+'['+i+']', names));
      return;
    }
    const nextNames=names.slice();
    if(typeof v.name==='string' && v.name.trim()) nextNames.push(v.name.trim());
    if(v.pbs && typeof v.pbs==='object') {
      const p=v.pbs;
      const emitter=String(p.emitter||'');
      if((emitter && emitter.toLowerCase()!=='none') || (p.emitterCommands && typeof p.emitterCommands==='object')) {
        found.push({
          clip:v, path,
          title:v.name || v.id || 'Emitter',
          context:nextNames.slice(-4,-1).join(' › ')
        });
      }
    }
    for(const [k,x] of Object.entries(v)) {
      if(k==='pbs') continue;
      walk(x,path+'.'+k,nextNames);
    }
  }
  walk(data,'$');
  return found;
}
function normalizeInitialAngle(pbs) {
  let raw = pbs.initialAngle ?? pbs.angleOverride ?? 'none';
  raw=String(raw).trim().toLowerCase().replaceAll('-','_').replaceAll(' ','_');
  const map={
    initialangletotfocus:'particle_to_focus',
    initial_angle_to_focus:'particle_to_focus',
    particletofocus:'particle_to_focus',
    alwayspointatfocus:'always_particle_to_focus',
    always_point_at_focus:'always_particle_to_focus',
    alwaysparticletofocus:'always_particle_to_focus',
    emittertofocus:'emitter_to_focus',
    emitteddirection:'emitted_direction',
  };
  return map[raw] || raw || 'none';
}
function migratePbs(pbs) {
  let changed=0;
  pbs.emitterCommands ||= {};
  const cmds=pbs.emitterCommands;
  for(const [oldKey,newKey] of Object.entries(LEGACY_COMMANDS)) {
    if(Array.isArray(cmds[oldKey]) && cmds[oldKey].length) {
      if(!Array.isArray(cmds[newKey]) || !cmds[newKey].length) cmds[newKey]=cmds[oldKey];
      else cmds[newKey]=[...cmds[newKey],...cmds[oldKey]].sort((a,b)=>(+a.frame||0)-(+b.frame||0));
      delete cmds[oldKey]; changed++;
    }
  }
  for(const [oldKey,newKey] of Object.entries(LEGACY_ROOT)) {
    if(Object.prototype.hasOwnProperty.call(pbs,oldKey)) {
      if(!Object.prototype.hasOwnProperty.call(pbs,newKey)) pbs[newKey]=pbs[oldKey];
      delete pbs[oldKey]; changed++;
    }
  }
  if(Object.prototype.hasOwnProperty.call(pbs,'angleOverride')) {
    if(!Object.prototype.hasOwnProperty.call(pbs,'initialAngle')) pbs.initialAngle=normalizeInitialAngle(pbs);
    delete pbs.angleOverride; changed++;
  }
  return changed;
}
function valueAt(pbs,key) {
  if(Object.prototype.hasOwnProperty.call(pbs,key)) return pbs[key];
  for(const [oldKey,newKey] of Object.entries(LEGACY_ROOT)) if(newKey===key && Object.prototype.hasOwnProperty.call(pbs,oldKey)) return pbs[oldKey];
  if(key==='emitDirection' && Object.prototype.hasOwnProperty.call(pbs,'emitAngle')) return pbs.emitAngle;
  if(key==='emitDirectionRange' && Object.prototype.hasOwnProperty.call(pbs,'emitAngleRange')) return pbs.emitAngleRange;
  return NUMERIC_FIELDS[key] ?? 0;
}
function commandKeyCandidates(key) {
  const out=[key];
  for(const [oldKey,newKey] of Object.entries(LEGACY_COMMANDS)) if(newKey===key) out.push(oldKey);
  return out;
}
function commandsFor(pbs,key) {
  const map=pbs.emitterCommands||{};
  for(const k of commandKeyCandidates(key)) if(Array.isArray(map[k]) && map[k].length) return {key:k,list:map[k]};
  return {key,list:[]};
}
function writeBase(pbs,key,value) {
  pbs[key]=value;
  setDirty();
}
function renderNumberField(container,pbs,key,label) {
  const row=el('label','bas-field');
  row.append(el('span','bas-label',label));
  const input=el('input','bas-input');
  input.type='number'; input.step='any'; input.value=String(valueAt(pbs,key));
  const cmd=commandsFor(pbs,key);
  if(cmd.list.length) input.title=cmd.list.length+' keyframe(s) override this base value';
  input.addEventListener('change',()=>{ writeBase(pbs,key,Number(input.value)||0); });
  row.append(input);
  const badge=el('span','bas-kf',cmd.list.length?('◆ '+cmd.list.length):'');
  row.append(badge);
  row.addEventListener('dblclick',()=>openKeyframes(key,label));
  container.append(row);
}
function renderToggle(container,pbs,key,label) {
  const row=el('label','bas-check');
  const input=el('input'); input.type='checkbox'; input.checked=!!pbs[key];
  input.addEventListener('change',()=>{pbs[key]=input.checked;setDirty();renderDetail();});
  row.append(input,el('span','',label)); container.append(row);
}
function renderSelect(container,pbs,key,label,options) {
  const row=el('label','bas-field');
  row.append(el('span','bas-label',label));
  const sel=el('select','bas-input');
  for(const [name,val] of options) {
    const o=el('option','',name); o.value=val; sel.append(o);
  }
  sel.value=String(pbs[key]??'');
  sel.addEventListener('change',()=>{pbs[key]=sel.value;setDirty();});
  row.append(sel); container.append(row);
}
function showField(key,pbs) {
  const emitterPolar=!!pbs.emitterPositionPolarCoordinates;
  const spawnPolar=!!pbs.emitterSpawnPolarCoordinates;
  if(['emitterX','emitterY'].includes(key)) return !emitterPolar;
  if(['emitterR','emitterTheta'].includes(key)) return emitterPolar;
  if(['spawnX','spawnXRange','spawnY','spawnYRange','spawnXOffset','spawnXMultiplier','spawnYOffset','spawnYMultiplier'].includes(key)) return !spawnPolar;
  if(['spawnR','spawnRRange','spawnTheta','spawnThetaRange','spawnROffset','spawnRMultiplier','spawnThetaOffset'].includes(key)) return spawnPolar;
  return true;
}
function renderList(filter='') {
  const list=state.host.querySelector('.bas-list');
  list.innerHTML='';
  const q=filter.trim().toLowerCase();
  state.emitters.forEach((item,i)=>{
    const hay=(item.title+' '+item.context+' '+item.path).toLowerCase();
    if(q && !hay.includes(q)) return;
    const b=el('button','bas-item'+(item===state.selected?' active':''));
    b.append(el('strong','',item.title));
    if(item.context) b.append(el('small','',item.context));
    const p=item.clip.pbs||{};
    b.append(el('small','bas-type',String(p.emitter||'Emitter')));
    b.onclick=()=>{state.selected=item;renderList(q);renderDetail();};
    list.append(b);
  });
}
function renderDetail() {
  const detail=state.host.querySelector('.bas-detail');
  detail.innerHTML='';
  const item=state.selected;
  if(!item) {detail.append(el('div','bas-empty','Select an emitter.')); return;}
  const pbs=pbsOf(item);
  const head=el('div','bas-detail-head');
  const title=el('div'); title.append(el('h2','',item.title),el('small','',item.context||item.path));
  head.append(title,button('Migrate selected',()=>{
    const n=migratePbs(pbs); if(n){setDirty();renderDetail();renderList();toast(n+' legacy field(s) migrated.');} else toast('This emitter is already using the modern schema.');
  },'secondary'));
  detail.append(head);

  const core=el('section','bas-section');
  core.append(el('h3','','Emitter setup'));
  renderSelect(core,pbs,'emitter','Type',TYPES.map(x=>[x,x]));
  const initialRow=el('label','bas-field'); initialRow.append(el('span','bas-label','Initial angle'));
  const initial=el('select','bas-input');
  INITIAL_ANGLES.forEach(([name,val])=>{const o=el('option','',name);o.value=val;initial.append(o);});
  initial.value=normalizeInitialAngle(pbs);
  initial.onchange=()=>{pbs.initialAngle=initial.value; delete pbs.angleOverride; setDirty();};
  initialRow.append(initial); core.append(initialRow);
  renderToggle(core,pbs,'emitterPositionPolarCoordinates','Emitter position uses polar coordinates');
  renderToggle(core,pbs,'emitterSpawnPolarCoordinates','Spawn area uses polar coordinates');
  renderToggle(core,pbs,'randomInvertAngle','Randomly invert emitted direction');
  renderToggle(core,pbs,'randomInvertFlip','Randomly flip emitted particle');
  renderNumberField(core,pbs,'randomAngleRange','Random angle range');
  detail.append(core);

  for(const group of GROUPS) {
    const sec=el('section','bas-section');
    sec.append(el('h3','',group.title));
    const grid=el('div','bas-grid');
    for(const [key,label] of group.fields) if(showField(key,pbs)) renderNumberField(grid,pbs,key,label);
    if(group.title==='Emitted auto-movement') {
      const row=el('label','bas-check');
      const c=el('input'); c.type='checkbox'; c.checked=!!valueAt(pbs,'emitClockwise');
      c.onchange=()=>{pbs.emitClockwise=c.checked;setDirty();};
      row.append(c,el('span','','Clockwise')); grid.append(row);
    }
    sec.append(grid); detail.append(sec);
  }

  const hint=el('div','bas-hint','Tip: double-click any numeric property to edit its keyframes. Base values remain visible even when keyframes override them.');
  detail.append(hint);
}
function openKeyframes(key,label) {
  const item=state.selected; if(!item) return;
  const pbs=pbsOf(item); pbs.emitterCommands ||= {};
  migratePbs(pbs);
  pbs.emitterCommands[key] ||= [];
  const list=pbs.emitterCommands[key];
  const dlg=state.ctx.ui.showCustomDialog({
    title:'Emitter keyframes · '+label, width:'680px', height:'70vh',
    render(body) {
      body.className='bas-kf-dialog';
      const toolbar=el('div','bas-kf-toolbar');
      const frame=el('input','bas-input'); frame.type='number'; frame.min='0'; frame.step='1'; frame.value='0';
      const value=el('input','bas-input'); value.type='number'; value.step='any'; value.value=String(NUMERIC_FIELDS[key]??0);
      toolbar.append(el('span','','Frame'),frame,el('span','','Value'),value,button('Add',()=>{
        list.push({id:uid(),frame:Math.max(0,Number(frame.value)||0),duration:0,value:Number(value.value)||0});
        list.sort((a,b)=>(+a.frame||0)-(+b.frame||0)); setDirty(); draw();
      }));
      body.append(toolbar);
      const rows=el('div','bas-kf-rows'); body.append(rows);
      function draw() {
        rows.innerHTML='';
        if(!list.length) rows.append(el('div','bas-empty','No keyframes for this property.'));
        list.forEach((cmd,i)=>{
          const r=el('div','bas-kf-row');
          const f=el('input','bas-input');f.type='number';f.step='1';f.value=String(cmd.frame??0);
          const d=el('input','bas-input');d.type='number';d.step='1';d.value=String(cmd.duration??0);
          const v=el('input','bas-input');v.type='number';v.step='any';v.value=String(cmd.value??0);
          f.onchange=()=>{cmd.frame=Math.max(0,Number(f.value)||0);setDirty();};
          d.onchange=()=>{cmd.duration=Math.max(0,Number(d.value)||0);setDirty();};
          v.onchange=()=>{cmd.value=Number(v.value)||0;setDirty();};
          r.append(el('span','','F'),f,el('span','','Dur'),d,el('span','','Value'),v,button('Delete',()=>{list.splice(i,1);setDirty();draw();},'danger'));
          rows.append(r);
        });
      }
      draw();
    },
    onCloseRequest:()=>{dlg.close();renderDetail();}
  });
}
function toast(message) {
  try { state.ctx.ui.showToast({message}); } catch { /* older Maker Studio */ }
}
async function save() {
  if(!state.data) return;
  await state.ctx.fs.writeProjectFile(ANIMATIONS_PATH, JSON.stringify(state.data,null,2)+'\n');
  setDirty(false); toast('Battle Animation Studio animations saved.');
}
async function migrateAll() {
  let n=0, emitters=0;
  for(const item of state.emitters) {
    const c=migratePbs(pbsOf(item));
    if(c){n+=c;emitters++;}
  }
  if(n){setDirty();renderList();renderDetail();}
  toast(n?('Migrated '+n+' field(s) in '+emitters+' emitter(s).'):'All emitters already use the modern schema.');
}
function injectStyles() {
  if(document.getElementById('bas-modern-emitter-style')) return;
  const style=el('style'); style.id='bas-modern-emitter-style';
  style.textContent=`
.bas-app{height:100%;display:grid;grid-template-rows:auto 1fr;font:13px/1.35 system-ui,sans-serif;color:var(--text-color,#ddd);background:var(--background-color,#202124)}
.bas-top{display:flex;gap:8px;align-items:center;padding:10px;border-bottom:1px solid #555}.bas-top input{flex:1}
.bas-dirty{min-width:80px;opacity:.8}.bas-main{min-height:0;display:grid;grid-template-columns:minmax(230px,28%) 1fr}
.bas-left{min-height:0;border-right:1px solid #555;overflow:auto;padding:8px}.bas-list{display:flex;flex-direction:column;gap:5px}
.bas-item{display:flex;flex-direction:column;align-items:flex-start;text-align:left;padding:8px;border:1px solid #555;border-radius:7px;background:#292a2d;color:inherit;cursor:pointer}
.bas-item.active{outline:2px solid #7aa2ff}.bas-item small{opacity:.7}.bas-type{margin-top:3px}
.bas-detail{min-height:0;overflow:auto;padding:14px}.bas-detail-head{display:flex;justify-content:space-between;gap:12px;align-items:start}.bas-detail-head h2{margin:0 0 3px}
.bas-section{border:1px solid #555;border-radius:8px;padding:12px;margin:12px 0;background:#26272a}.bas-section h3{margin:0 0 10px;font-size:14px}
.bas-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(210px,1fr));gap:8px 12px}.bas-field{display:grid;grid-template-columns:minmax(90px,1fr) minmax(75px,110px) 38px;gap:6px;align-items:center}
.bas-label{opacity:.9}.bas-input{box-sizing:border-box;width:100%;padding:6px;border:1px solid #666;border-radius:5px;background:#17181a;color:inherit}
.bas-check{display:flex;align-items:center;gap:7px;padding:5px 0}.bas-kf{font-size:11px;opacity:.7}.bas-btn{padding:6px 10px;border:1px solid #667;border-radius:6px;background:#3b65a7;color:white;cursor:pointer}
.bas-btn.secondary{background:#3c4043}.bas-btn.danger{background:#8b3d3d}.bas-empty,.bas-hint{padding:16px;opacity:.7}.bas-hint{border-left:3px solid #7aa2ff}
.bas-kf-dialog{padding:12px;color:var(--text-color,#ddd)}.bas-kf-toolbar,.bas-kf-row{display:grid;grid-template-columns:auto 90px auto 110px auto;gap:7px;align-items:center;margin-bottom:8px}
.bas-kf-row{grid-template-columns:auto 70px auto 70px auto 110px auto;border-bottom:1px solid #555;padding:7px 0}
`;
  document.head.append(style);
}
async function openEditor(ctx) {
  injectStyles();
  let raw;
  try { raw=await ctx.fs.readProjectFile(ANIMATIONS_PATH); }
  catch(e){ toast('Could not read '+ANIMATIONS_PATH); return; }
  try { state.data=JSON.parse(raw); }
  catch(e){ toast('animations.json is not valid JSON.'); return; }
  state.ctx=ctx; state.emitters=findEmitters(state.data); state.selected=state.emitters[0]||null; state.dirty=false;
  const dlg=ctx.ui.showCustomDialog({
    title:'Battle Animation Studio · Modern Emitters', width:'94vw', height:'90vh',
    render(body) {
      state.host=body; body.innerHTML=''; body.className='bas-app';
      const top=el('div','bas-top');
      const search=el('input','bas-input'); search.placeholder='Search emitter, clip or animation…';
      search.oninput=()=>renderList(search.value);
      top.append(search,el('span','bas-dirty','Saved'),button('Migrate all legacy emitters',migrateAll,'secondary'),button('Save',save));
      const main=el('div','bas-main'); const left=el('aside','bas-left'); left.append(el('div','bas-list'));
      const detail=el('main','bas-detail'); main.append(left,detail); body.append(top,main);
      renderList(); renderDetail();
      return ()=>{state.host=null;};
    },
    onCloseRequest:async()=>{
      if(!state.dirty){dlg.close();return;}
      const result=await ctx.ui.showUnsavedChangesDialog({message:'Battle Animation Studio emitter changes are not saved.'});
      if(result==='save'){try{await save();dlg.close();}catch{}}
      else if(result==='discard') dlg.close();
    }
  });
  state.dialog=dlg;
}
export function activate(ctx) {
  state.ctx=ctx;
  ctx.menu.registerMenuItem({
    menu:'Mods',
    label:'Battle Animation Studio · Emitters',
    shortcut:'Ctrl+Shift+A',
    handler:()=>openEditor(ctx)
  });
}
export function deactivate() {
  if(state.dialog) { try{state.dialog.close();}catch{} }
  state={ctx:null,data:null,emitters:[],selected:null,dirty:false,dialog:null,host:null};
}
