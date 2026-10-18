// Lighting Studio data contract: schema 1, backward compatible with v0.1-v0.3.
// x/y are tile coordinates; radii are game pixels at a 32px reference tile.
export const DATA_PATH = 'Data/LightingStudio/maps.json';
export const SCHEMA = 1;
export const BLEND_MODES = ['normal','add','subtract'];
export const LIGHT_TYPES = ['radial','cone','ellipse','rectangle'];
export const TYPE_NAMES = {radial:'Radial',cone:'Cono / foco',ellipse:'Elíptica',rectangle:'Rectangular'};
export const parseCoordinate = v => { const str=String(v).trim().replace(',', '.'); if(!/^[+-]?(?:\d+(?:\.\d*)?|\.\d+)$/.test(str))return null; const n=Number(str);return Number.isFinite(n)&&n>=-2048&&n<=2048?Math.round(n*1000)/1000:null; };
export const deepCopy = v => JSON.parse(JSON.stringify(v));
export const newId = () => 'light_'+Date.now().toString(36)+'_'+Math.random().toString(36).slice(2,8);
const num = (v,lo,hi,def) => Number.isFinite(Number(v)) ? Math.min(hi,Math.max(lo,Number(v))) : def;
export const clamp = (v,lo,hi) => num(v,lo,hi,lo);
export const hex = (v,def='#FFCE8A') => /^#[a-fA-F0-9]{6}$/.test(String(v)) ? String(v).toUpperCase() : def;
export const defaultMap = () => ({enabled:true,ambient:{color:'#142439',darkness:0},lights:[]});
export const defaultProject = () => ({schema:SCHEMA,maps:{}});
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
    rotation:num(s.rotation,-360,360,0),angle:num(s.angle,5,170,70),
    widthPx:num(s.widthPx,8,1024,160),heightPx:num(s.heightPx,8,1024,96),
    enabled:s.enabled!==false,
    blendMode:BLEND_MODES.includes(s.blendMode)?s.blendMode:'add',
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
  for(const [id,value] of Object.entries(src.maps)){
    if(!/^\d+$/.test(id)||!value||typeof value!=='object')continue;
    const ambient=value.ambient||{},seen=new Set();
    res.maps[String(Number(id))]={enabled:value.enabled!==false,
      ambient:{color:hex(ambient.color,'#142439'),darkness:num(ambient.darkness,0,1,0)},
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
