// Lighting Studio data contract: schema 1, backward compatible with v0.1-v0.3.
// x/y are tile coordinates; radii are game pixels at a 32px reference tile.
export const DATA_PATH = 'Data/LightingStudio/maps.json';
export const SCHEMA = 1;
export const BLEND_MODES = ['normal','union','sum','subtract'];
export const BLEND_NAMES = {union:'Fusionar área iluminada',sum:'Sumar brillo',normal:'Normal',subtract:'Oscurecer'};
export const LIGHT_TYPES = ['radial','cone','ellipse','rectangle','mask'];
export const FADE_MODES = ['center','top','bottom','left','right','custom'];
export const FADE_NAMES = {center:'Desde el centro',top:'Hacia arriba (luz abajo)',bottom:'Hacia abajo (luz arriba)',left:'Hacia la izquierda (luz derecha)',right:'Hacia la derecha (luz izquierda)',custom:'Desde un origen personalizado'};
export const TYPE_NAMES = {radial:'Radial',cone:'Cono / foco',ellipse:'Elíptica',rectangle:'Rectangular',mask:'Máscara PNG (forma personalizada)'};
export const parseCoordinate = v => { const str=String(v).trim().replace(',', '.'); if(!/^[+-]?(?:\d+(?:\.\d*)?|\.\d+)$/.test(str))return null; const n=Number(str);return Number.isFinite(n)&&n>=-2048&&n<=2048?Math.round(n*1000)/1000:null; };
export const deepCopy = v => JSON.parse(JSON.stringify(v));
export const newId = () => 'light_'+Date.now().toString(36)+'_'+Math.random().toString(36).slice(2,8);
const num = (v,lo,hi,def) => Number.isFinite(Number(v)) ? Math.min(hi,Math.max(lo,Number(v))) : def;
export const clamp = (v,lo,hi) => num(v,lo,hi,lo);
export const hex = (v,def='#FFCE8A') => /^#[a-fA-F0-9]{6}$/.test(String(v)) ? String(v).toUpperCase() : def;
export const NORMAL_CATEGORIES = {tilesets:'Tilesets',autotiles:'Autotiles',characters:'Characters'};
export const NORMAL_DIR='Graphics/LightingStudio/Normals';
export const MASK_DIR='Graphics/LightingStudio/Masks';
export const maskFilename = v => /^[a-zA-Z0-9_-]{1,70}\.png$/i.test(String(v||'')) ? String(v) : '';
export const defaultNormals = () => ({
  enabled:false,strength:1,intensity:0.5,warmup:true,
  auto:{tilesets:true,autotiles:true,characters:true},
  suffix:'_n',tilesets:[],autotiles:[],characters:[]
});
// Source and normal filenames are relative game assets; reject path traversal.
export function assetName(v){
  const value=normalGraphicName(v);
  return value&&value.length<=150?value:'';
}
export function normalizeNormalBinding(raw,category){
  if(!NORMAL_CATEGORIES[category]||!raw||typeof raw!=='object')return null;
  const source=assetName(raw.source),normal=assetName(raw.normal);
  return source&&normal?{source,normal,invertY:raw.invertY===true,enabled:raw.enabled!==false}:null;
}
export function normalizeNormals(raw){
  const v=raw&&typeof raw==='object'?raw:{};
  const out=defaultNormals();out.enabled=v.enabled===true;out.strength=num(v.strength,0,2,1);out.intensity=num(v.intensity,0,1.5,0.5);out.warmup=v.warmup!==false;
  const auto=v.auto&&typeof v.auto==='object'?v.auto:{};
  for(const category of Object.keys(NORMAL_CATEGORIES))
    out.auto[category]=auto[category]!==false;
  out.suffix=/^_[a-z0-9]{1,12}$/i.test(String(v.suffix||'_n'))?String(v.suffix||'_n'):'_n';
  for(const category of Object.keys(NORMAL_CATEGORIES)){
    const seen=new Set();
    out[category]=(Array.isArray(v[category])?v[category]:[]).slice(0,300)
      .map(x=>normalizeNormalBinding(x,category))
      .filter(x=>{if(!x||seen.has(x.source))return false;seen.add(x.source);return true;});
  }
  return out;
}
// A data-driven 24-hour color timeline; values are saved globally in maps.json.
export const defaultTimeOfDay = () => ({
 enabled:false,source:'real',startHour:8,minutesPerSecond:0.1,
 previewHour:12,
 keyframes:[
  {hour:0,color:'#25334F',darkness:0.37},
  {hour:5,color:'#40516D',darkness:0.26},
  {hour:7,color:'#E7CBA4',darkness:0.025},
  {hour:11,color:'#FFFFFF',darkness:0},
  {hour:15,color:'#F4D6B2',darkness:0.025},
  {hour:17,color:'#D9B59C',darkness:0.055},
  {hour:19,color:'#53658D',darkness:0.18},
  {hour:23,color:'#263956',darkness:0.34}
 ]
});
export function normalizeTimeOfDay(raw){
 const cfg=raw&&typeof raw==='object'?raw:{};
 const def=defaultTimeOfDay();
 const source=['real','internal'].includes(cfg.source)?cfg.source:'real';
 const seen=new Set();
 const keys=(Array.isArray(cfg.keyframes)?cfg.keyframes:def.keyframes).slice(0,48)
  .map(k=>({hour:num(k?.hour,0,23.999,0),color:hex(k?.color,'#FFFFFF'),
    darkness:num(k?.darkness,0,1,0)}))
  .filter(k=>{const h=k.hour.toFixed(3);if(seen.has(h))return false;seen.add(h);return true;})
  .sort((a,b)=>a.hour-b.hour);
 return {enabled:cfg.enabled===true,source,startHour:num(cfg.startHour,0,23.999,8),
  minutesPerSecond:num(cfg.minutesPerSecond,0.001,5,0.1),
  previewHour:num(cfg.previewHour,0,23.999,12),keyframes:keys.length>=2?keys:def.keyframes};
}
export function evaluateTimeOfDay(config,hour){
 const keys=normalizeTimeOfDay(config).keyframes,h=((hour%24)+24)%24;
 let hi=keys.findIndex(k=>k.hour>h);
 if(hi<0)hi=0;
 const high=keys[hi],low=keys[(hi-1+keys.length)%keys.length];
 const start=low.hour,end=high.hour+(hi===0?24:0),value=h+(h<low.hour?24:0);
 const t=Math.min(1,Math.max(0,(value-start)/(end-start)));
 const cols=[1,3,5].map(i=>Math.round(parseInt(low.color.slice(i,i+2),16)*(1-t)+parseInt(high.color.slice(i,i+2),16)*t));
 return {color:'#'+cols.map(n=>n.toString(16).padStart(2,'0')).join('').toUpperCase(),
  darkness:low.darkness*(1-t)+high.darkness*t};
}

export const defaultMap = () => ({enabled:true,overlapMode:'union',ambient:{color:'#142439',darkness:0},normalMaps:defaultNormals(),dayNightMode:'follow',lights:[]});
export const defaultProject = () => ({schema:SCHEMA,normalSettings:defaultNormals(),timeOfDay:defaultTimeOfDay(),maps:{}});
// Hours follow the global day-night clock; unconfigured lights remain always on.
// fadeMinutes softens turn-on/turn-off on both sides (including overnight windows).
export const defaultSchedule = () => ({
 enabled:false,startHour:19,endHour:7,fadeMinutes:20
});
export function normalizeSchedule(raw){
 const s=raw&&typeof raw==='object'?raw:{};
 const enabled=s.enabled===true;
 const startHour=num(s.startHour,0,23.999,19),endHour=num(s.endHour,0,23.999,7);
 const derived=!enabled?'always':Math.abs(startHour-7)<.001&&Math.abs(endHour-19)<.001?'day':
   Math.abs(startHour-19)<.001&&Math.abs(endHour-7)<.001?'night':'custom';
 return {enabled,startHour,endHour,fadeMinutes:num(s.fadeMinutes,0,120,20),
  mode:['always','day','night','custom'].includes(s.mode)?s.mode:derived};
}
export function scheduleFactor(schedule,hour){
 const s=normalizeSchedule(schedule);
 if(!s.enabled)return 1;
 const start=s.startHour*60,duration=(s.endHour*60-start+1440)%1440;
 if(duration<.0001)return 1;
 const elapsed=(((hour%24+24)%24)*60-start+1440)%1440;
 if(elapsed>=duration)return 0;
 const fade=Math.min(s.fadeMinutes,duration/2);
 if(fade<=0)return 1;
 const k=Math.max(0,Math.min(1,elapsed/fade,(duration-elapsed)/fade));
 return k*k*(3-2*k);
}
export const defaultPulse = () => ({enabled:false,speedHz:1,intensity:0.25,radius:0.12,phase:0});
export const defaultPixel = () => ({enabled:false,size:6,steps:6});
export function normalizeLight(raw={}){
  const s=raw&&typeof raw==='object'?raw:{},p=s.pulse||{},px=s.pixel||{};
  return {
    id:String(s.id||newId()).replace(/[^a-zA-Z0-9_-]/g,'').slice(0,80)||newId(),
    name:String(s.name||'Luz radial').slice(0,80),type:LIGHT_TYPES.includes(s.type)?s.type:'radial',
    x:num(s.x,-2048,2048,0),y:num(s.y,-2048,2048,0),
    radiusPx:num(s.radiusPx,8,512,96),intensity:num(s.intensity,0,1,.8),
    color:hex(s.color),softness:num(s.softness,.05,1,.75),
    centerStrength:num(s.centerStrength,0,1,0.65),
    fadeMode:FADE_MODES.includes(s.fadeMode)?s.fadeMode:'center',
    fadeStart:num(s.fadeStart,0,0.95,0.58),
    fadeX:num(s.fadeX,-1,1,0),fadeY:num(s.fadeY,-1,1,0),
    rotation:num(s.rotation,-360,360,0),angle:num(s.angle,5,170,70),
    coneFeather:num(s.coneFeather,.03,.9,.28),
    maskFile:maskFilename(s.maskFile),
    widthPx:num(s.widthPx,8,1024,160),heightPx:num(s.heightPx,8,1024,96),
    enabled:s.enabled!==false,
    schedule:normalizeSchedule(s.schedule),
    blendMode:s.blendMode==='add'?'union':BLEND_MODES.includes(s.blendMode)?s.blendMode:'union',
    pulse:{enabled:p.enabled===true,speedHz:num(p.speedHz,.05,12,1),
      intensity:num(p.intensity,0,1,.25),radius:num(p.radius,0,.9,.12),phase:num(p.phase,0,360,0)},
    pixel:{enabled:px.enabled===true,size:Math.round(num(px.size,2,32,6)),steps:Math.round(num(px.steps,2,24,6))},
    anchor:{type:'static'}
  };
}
export function normalizeProject(src){
  if(!src||src.schema!==SCHEMA||typeof src.maps!=='object'||!src.maps||Array.isArray(src.maps))
    throw Error('Datos incompatibles: se bloqueó la escritura para evitar pérdida de datos.');
  const res=defaultProject();
  // Global rules work for every map and every player/follower graphic without
  // per-species switches or a manually maintained Pokemon list.
  res.normalSettings=normalizeNormals(src.normalSettings);
  res.timeOfDay=normalizeTimeOfDay(src.timeOfDay);
  if(!src.normalSettings){
    // Upgrade older per-map assignments to the one global catalog without
    // discarding any manual exceptions users already added.
    for(const map of Object.values(src.maps)){
      const legacy=map?.normalMaps;
      if(!legacy || legacy.enabled!==true)continue;
      res.normalSettings.enabled=true;
      const normalized=normalizeNormals(legacy);
      for(const category of Object.keys(NORMAL_CATEGORIES)){
        const seen=new Set(res.normalSettings[category].map(v=>v.source));
        for(const binding of normalized[category]){
          if(seen.has(binding.source))continue;
          res.normalSettings[category].push(binding);
          seen.add(binding.source);
        }
      }
    }
  }
  for(const [id,value] of Object.entries(src.maps)){
    if(!/^\d+$/.test(id)||!value||typeof value!=='object')continue;
    const ambient=value.ambient||{},seen=new Set();
    res.maps[String(Number(id))]={enabled:value.enabled!==false,
      overlapMode:value.overlapMode==='sum'?'sum':'union',
      ambient:{color:hex(ambient.color,'#142439'),darkness:num(ambient.darkness,0,1,0)},
      normalMaps:normalizeNormals(value.normalMaps),
      dayNightMode:['follow','ignore'].includes(value.dayNightMode)?value.dayNightMode:'follow',
      lights:(Array.isArray(value.lights)?value.lights:[]).slice(0,500).map(normalizeLight)
      .filter(l=>{if(seen.has(l.id))return false;seen.add(l.id);return true;})};
  }
  return res;
}
export function getMap(data,mapId,create=false){
  const k=String(Number(mapId)||0);if(k==='0')return null;
  if(!data.maps[k]&&create)data.maps[k]=defaultMap();
  return data.maps[k]||null;
}
export function makeLight(x=0,y=0,type='radial'){const t=LIGHT_TYPES.includes(type)?type:'radial';return normalizeLight({id:newId(),name:TYPE_NAMES[t],type:t,x,y});}

// Resolve by the actual graphic in use, not by a Pokémon species/form variable.
// This supports the player, followers, gender/forms, and arbitrary characters.
// Manual bindings are rare overrides; the default is "<graphic>_n.png".
export function normalGraphicName(name){
  let n=String(name||'').trim().replace(/\\/g,'/');
  n=n.replace(/^(?:Graphics\/)?(?:Characters|Tilesets|Autotiles)\//i,'');
  n=n.replace(/\.(?:png|gif|bmp|jpg|jpeg)$/i,'');
  if(n.length>180||!n||n.startsWith('/')||n.split('/').some(x=>x==='..'||x===''||x==='.')||/[^\p{L}\p{N}_ .()!+@$\-[\]/]/u.test(n))return '';
  return n;
}
export function normalCandidate(settings,category,graphic){
  const cfg=normalizeNormals(settings),name=normalGraphicName(graphic);
  if(!cfg.enabled||!NORMAL_CATEGORIES[category]||!name)return null;
  const manual=cfg[category].find(e=>e.source===name);
  if(manual)return manual.enabled!==false?NORMAL_DIR+'/'+NORMAL_CATEGORIES[category]+'/'+manual.normal+'.png':null;
  return cfg.auto[category]?
    NORMAL_DIR+'/'+NORMAL_CATEGORIES[category]+'/'+name+cfg.suffix+'.png':null;
}
