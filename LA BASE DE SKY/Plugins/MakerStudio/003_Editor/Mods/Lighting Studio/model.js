// Shared Lighting Studio data schema. Coordinates are map tiles; radius is base game pixels.
export const DATA_PATH = 'Data/LightingStudio/maps.json';
export const SCHEMA = 1;
const clamp = (n,min,max,fallback=min) => Number.isFinite(Number(n)) ? Math.min(max,Math.max(min,Number(n))) : fallback;
export const deepCopy = v => JSON.parse(JSON.stringify(v));
export const newId = () => 'light_'+Date.now().toString(36)+'_'+Math.random().toString(36).slice(2,8);
export function defaultMap() { return { ambient:{ color:'#142439', darkness:0.42 }, lights:[] }; }
export function defaultProject() { return { schema:SCHEMA, maps:{} }; }
export function normalizeHex(v,fallback='#FFFFFF') {
  const s=String(v||'').toUpperCase(); return /^#[A-F0-9]{6}$/.test(s)?s:fallback;
}
export function normalizeLight(src={}) {
  const s=src&&typeof src==='object'?src:{};
  const id=String(s.id||newId()).replace(/[^a-zA-Z0-9_-]/g,'').slice(0,80)||newId();
  const anchor=s.anchor&&typeof s.anchor==='object'?s.anchor:{};
  return {
    id, name:String(s.name||'Luz radial').trim().slice(0,80), type:'radial',
    x:clamp(s.x,-2048,2048,0), y:clamp(s.y,-2048,2048,0),
    radiusPx:clamp(s.radiusPx,8,512,96), intensity:clamp(s.intensity,0,1,0.8),
    color:normalizeHex(s.color,'#FFCF86'), softness:clamp(s.softness,0.05,1,0.75),
    enabled:s.enabled!==false, anchor:{type:'static'},
  };
}
export function normalizeProject(raw) {
  if (!raw||typeof raw!=='object'||raw.schema!==SCHEMA||!raw.maps||typeof raw.maps!=='object'||Array.isArray(raw.maps))
    throw new Error('Formato Lighting Studio no reconocido; no se sobrescribirá el archivo.');
  const result=defaultProject();
  for (const [id,map] of Object.entries(raw.maps)) {
    if (!/^\d+$/.test(id)||!map||typeof map!=='object') continue;
    const ambient=map.ambient&&typeof map.ambient==='object'?map.ambient:{};
    const lights=Array.isArray(map.lights)?map.lights:[];
    const seen=new Set();
    result.maps[String(Number(id))]={
      ambient:{color:normalizeHex(ambient.color,'#142439'),darkness:clamp(ambient.darkness,0,1,0.42)},
      lights:lights.slice(0,500).map(normalizeLight).filter(light=>{if(seen.has(light.id))return false;seen.add(light.id);return true;}),
    };
  }
  return result;
}
export function getMap(project,mapId,create=false) {
  const key=String(Number(mapId)||0); if(key==='0')return null;
  if(!project.maps[key]&&create)project.maps[key]=defaultMap();
  return project.maps[key]||null;
}
export function makeLight(x=0,y=0) {
  return normalizeLight({id:newId(),name:'Luz '+(new Date()).toLocaleTimeString(),x,y});
}
