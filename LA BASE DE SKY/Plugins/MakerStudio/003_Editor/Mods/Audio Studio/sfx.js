const clamp=(v,a,b)=>Math.max(a,Math.min(b,v));
function mulberry32(seed){return function(){let t=seed+=0x6D2B79F5;t=Math.imul(t^t>>>15,t|1);t^=t+Math.imul(t^t>>>7,t|61);return ((t^t>>>14)>>>0)/4294967296;};}
function env(t,d,a,dec,sustain=.25){if(t<a)return t/Math.max(.001,a);const x=(t-a)/Math.max(.001,dec);return x<1?1-(1-sustain)*x:sustain*Math.max(0,1-(t-a-dec)/Math.max(.001,d-a-dec));}
function soft(x,drive){const k=1+drive*10;return Math.tanh(x*k)/Math.tanh(k);}
function lpFilter(data,cutoff,sr){if(cutoff>=.99)return data;const fc=80+Math.pow(cutoff,2)*18000,a=1-Math.exp(-2*Math.PI*fc/sr),out=new Float32Array(data.length);let y=0;for(let i=0;i<data.length;i++){y+=a*(data[i]-y);out[i]=y;}return out;}
function delay(data,sr,mix,time,feedback){if(mix<=.001)return data;const out=data.slice(),d=Math.max(1,Math.round(sr*time));for(let i=d;i<out.length;i++)out[i]=clamp(out[i]+out[i-d]*feedback*mix,-1.2,1.2);return out;}

export const SFX_TYPES={
  impact:{label:'Impact / Hit',tone:.65,noise:.35,sub:.45,sweep:-.65},explosion:{label:'Explosion',tone:.28,noise:.9,sub:.7,sweep:-.5},slash:{label:'Slash / Whoosh',tone:.22,noise:.75,sub:.05,sweep:.7},magic:{label:'Magic',tone:.85,noise:.15,sub:.08,sweep:.8},electric:{label:'Electricity',tone:.35,noise:.82,sub:.05,sweep:.15},water:{label:'Water',tone:.25,noise:.65,sub:.12,sweep:.1},wind:{label:'Wind',tone:.06,noise:.92,sub:0,sweep:.4},fire:{label:'Fire',tone:.05,noise:.95,sub:.08,sweep:.05},ice:{label:'Ice / Crystal',tone:.88,noise:.18,sub:.02,sweep:.72},earth:{label:'Earth / Rock',tone:.2,noise:.7,sub:.75,sweep:-.38},psychic:{label:'Psychic / Arcane',tone:.9,noise:.12,sub:.05,sweep:.4},ui:{label:'UI / Menu',tone:.95,noise:.05,sub:.02,sweep:.2},pickup:{label:'Pickup',tone:.96,noise:.02,sub:.03,sweep:.9},heal:{label:'Heal',tone:.95,noise:.08,sub:.03,sweep:.65},teleport:{label:'Teleport',tone:.6,noise:.35,sub:.1,sweep:-.85},laser:{label:'Laser / Beam',tone:.92,noise:.12,sub:.04,sweep:-.75},rumble:{label:'Rumble',tone:.22,noise:.5,sub:.9,sweep:-.15},footstep:{label:'Footstep',tone:.18,noise:.72,sub:.45,sweep:-.3},notification:{label:'Notification',tone:.96,noise:.02,sub:0,sweep:.25},door:{label:'Door / Mechanical',tone:.18,noise:.66,sub:.35,sweep:-.18},ambience:{label:'Ambient Loop Base',tone:.12,noise:.82,sub:.16,sweep:.05}
};

const P=(category,label,kind,patch,description='')=>({category,label,kind,patch,description});
export const SFX_BASE = {
  ui_cursor:P('UI','Cursor / Move','ui',{pitch:.62,length:.08,power:.38,wave:'sine',attack:.002,decay:.22,sustain:0,cutoff:.95,delayMix:0},'Short neutral cursor tick.'),
  ui_confirm:P('UI','Confirm','notification',{pitch:.74,length:.13,power:.5,wave:'sine',sweep:.5,attack:.002,decay:.28,sustain:.05,delayMix:.05},'Bright confirmation.'),
  ui_cancel:P('UI','Cancel / Back','ui',{pitch:.43,length:.13,power:.45,wave:'triangle',sweep:-.3,attack:.002,decay:.3,sustain:.03},'Descending back/cancel cue.'),
  ui_error:P('UI','Error','notification',{pitch:.31,length:.2,power:.58,wave:'square',sweep:-.12,crush:.08,drive:.08},'Low warning cue.'),
  ui_save:P('UI','Save / Success','heal',{pitch:.68,length:.28,power:.5,wave:'sine',sweep:.78,delayMix:.12,delayTime:.18},'Positive save/success flourish.'),
  battle_hit_light:P('Battle','Hit — Light','impact',{pitch:.64,length:.12,power:.55,texture:.34,attack:.001,decay:.3,toneMix:.54,noiseMix:.48,subMix:.16,drive:.14},'Fast contact hit.'),
  battle_hit_heavy:P('Battle','Hit — Heavy','impact',{pitch:.28,length:.25,power:.82,texture:.55,attack:.001,decay:.52,toneMix:.42,noiseMix:.48,subMix:.72,drive:.28},'Heavy body impact.'),
  battle_critical:P('Battle','Critical Hit','impact',{pitch:.43,length:.32,power:.95,texture:.7,toneMix:.7,noiseMix:.62,subMix:.75,drive:.42,crush:.12,delayMix:.08},'Layered high-impact critical.'),
  battle_slash:P('Battle','Slash','slash',{pitch:.67,length:.18,power:.66,texture:.62,attack:.001,decay:.28,noiseMix:.9,toneMix:.12,sweep:.88},'Fast blade / claw pass.'),
  battle_charge:P('Battle','Charge / Power Up','magic',{pitch:.4,length:.7,power:.58,texture:.28,attack:.08,decay:.72,sustain:.52,sweep:.75,delayMix:.16},'Rising energy charge.'),
  battle_beam:P('Battle','Beam','laser',{pitch:.62,length:.5,power:.72,texture:.32,attack:.008,decay:.5,sustain:.4,sweep:-.36,drive:.18,delayMix:.08},'Sustained beam core.'),
  battle_explosion:P('Battle','Explosion','explosion',{pitch:.24,length:.72,power:.92,texture:.88,attack:.001,decay:.78,toneMix:.18,noiseMix:1,subMix:.88,cutoff:.6,drive:.38},'Large explosion base.'),
  elem_fire:P('Elements','Fire Burst','fire',{pitch:.42,length:.42,power:.7,texture:.84,noiseMix:1,toneMix:.03,subMix:.12,cutoff:.68,drive:.18},'Crackle / burst fire bed.'),
  elem_water:P('Elements','Water Splash','water',{pitch:.57,length:.4,power:.66,texture:.72,noiseMix:.82,toneMix:.22,cutoff:.76,sweep:.22},'Splash and water motion.'),
  elem_electric:P('Elements','Electric Zap','electric',{pitch:.72,length:.22,power:.74,texture:.88,noiseMix:.95,toneMix:.35,crush:.22,drive:.12,sweep:.18},'Unstable electric snap.'),
  elem_ice:P('Elements','Ice / Crystal','ice',{pitch:.78,length:.35,power:.58,texture:.24,wave:'sine',toneMix:.95,noiseMix:.16,sweep:.86,delayMix:.2,delayTime:.3},'Bright crystalline ping.'),
  elem_wind:P('Elements','Wind / Whoosh','wind',{pitch:.48,length:.55,power:.58,texture:.78,noiseMix:1,toneMix:.02,cutoff:.72,sweep:.62},'Broad whoosh bed.'),
  elem_earth:P('Elements','Rock / Earth','earth',{pitch:.22,length:.46,power:.8,texture:.82,noiseMix:.86,toneMix:.12,subMix:.92,cutoff:.5,drive:.22},'Rock impact and low debris.'),
  elem_psychic:P('Elements','Psychic / Arcane','psychic',{pitch:.6,length:.6,power:.58,texture:.22,wave:'sine',toneMix:.94,noiseMix:.1,sweep:.42,delayMix:.26,feedback:.38},'Clean supernatural tone.'),
  move_step_grass:P('Movement','Footstep — Grass','footstep',{pitch:.52,length:.12,power:.4,texture:.72,noiseMix:.9,toneMix:.08,subMix:.18,cutoff:.55},'Soft textured footstep.'),
  move_step_stone:P('Movement','Footstep — Stone','footstep',{pitch:.47,length:.1,power:.5,texture:.42,noiseMix:.62,toneMix:.25,subMix:.4,cutoff:.8},'Hard stone contact.'),
  move_jump:P('Movement','Jump','wind',{pitch:.62,length:.18,power:.35,texture:.25,noiseMix:.45,toneMix:.28,sweep:.72,cutoff:.9},'Short upward motion.'),
  move_land:P('Movement','Landing','impact',{pitch:.36,length:.16,power:.55,texture:.5,noiseMix:.52,toneMix:.22,subMix:.62,sweep:-.45},'Landing thump.'),
  world_door:P('World','Door / Mechanism','door',{pitch:.35,length:.5,power:.56,texture:.7,noiseMix:.78,toneMix:.15,subMix:.35,sweep:-.18,drive:.12},'Door or mechanism movement.'),
  world_rumble:P('World','Rumble','rumble',{pitch:.13,length:1,power:.66,texture:.68,noiseMix:.56,toneMix:.12,subMix:1,cutoff:.36,drive:.14},'Low environmental rumble.'),
  world_wind:P('World','Ambient Wind','ambience',{pitch:.34,length:1,power:.4,texture:.75,noiseMix:1,toneMix:.02,subMix:.03,cutoff:.54,attack:.15,decay:.9,sustain:.7},'Long wind bed for looping/ambience.'),
  world_machine:P('World','Machine Hum','ambience',{pitch:.28,length:1,power:.38,texture:.16,wave:'sine',toneMix:.74,noiseMix:.2,subMix:.42,sustain:.82,attack:.12,decay:.9},'Steady machine / lab hum.'),
  creature_chirp:P('Creature','Chirp','notification',{pitch:.82,length:.16,power:.46,texture:.22,wave:'sine',sweep:.58,delayMix:.04},'Small creature chirp base.'),
  creature_growl:P('Creature','Growl Base','rumble',{pitch:.2,length:.52,power:.62,texture:.7,toneMix:.28,noiseMix:.5,subMix:.72,drive:.24,cutoff:.45},'Low synthetic growl bed.'),
  creature_roar:P('Creature','Roar Base','explosion',{pitch:.3,length:.7,power:.78,texture:.7,toneMix:.34,noiseMix:.64,subMix:.8,drive:.3,cutoff:.55},'Broad roar layer for further processing.')
};
export const SFX_CATEGORIES=['UI','Battle','Elements','Movement','World','Creature'];
export function sfxPresetsInCategory(category){return Object.entries(SFX_BASE).filter(([,p])=>p.category===category);}
export function patchFromSfxPreset(key){const p=SFX_BASE[key]||SFX_BASE.battle_hit_light;return {kind:p.kind,...p.patch,preset:key};}

export function generateSfx(kind='impact',opts={}){
  const sr=44100,k=SFX_TYPES[kind]||SFX_TYPES.impact,seed=(opts.seed|0)||1,rng=mulberry32(seed),rand=()=>rng()*2-1;
  const pitchRnd=clamp(opts.pitchRandom??0,0,1),gainRnd=clamp(opts.gainRandom??0,0,1),pitchOffset=rand()*pitchRnd*.18,gainOffset=1+rand()*gainRnd*.22;
  const power=clamp((opts.power??.65)*gainOffset,0,1.2),pitch=clamp((opts.pitch??.5)+pitchOffset,0,1),length=opts.length??.4,texture=opts.texture??.45;
  const attack=opts.attack??.015,decay=opts.decay??.45,sustain=opts.sustain??.15,cutoff=opts.filterEnabled===false?1:(opts.cutoff??.82),drive=opts.driveEnabled===false?0:(opts.drive??.1),crush=opts.crushEnabled===false?0:(opts.crush??.08),delayMix=opts.delayEnabled===false?0:(opts.delayMix??.05),delayTime=.02+(opts.delayTime??.25)*.22,feedback=.08+(opts.feedback??.25)*.55;
  const toneMix=opts.toneEnabled===false?0:(opts.toneMix??k.tone),noiseMix=opts.noiseEnabled===false?0:(opts.noiseMix??k.noise),subMix=opts.subEnabled===false?0:(opts.subMix??k.sub),transientMix=opts.transientEnabled===false?0:clamp(opts.transientMix??.18,0,1),transientPitch=clamp(opts.transientPitch??.55,0,1),sweepAmt=opts.sweep??k.sweep,vibrato=opts.vibrato??.03,wave=opts.wave||((kind==='ui'||kind==='pickup'||kind==='heal'||kind==='notification'||kind==='ice'||kind==='psychic')?'sine':kind==='electric'?'square':'triangle');
  const dur=Math.max(.05,.08+length*2.2),n=Math.max(64,Math.floor(sr*dur)),out=new Float32Array(n);let ph=0,subPh=0,held=0,hold=1;const base=45+Math.pow(pitch,1.7)*1550;
  for(let i=0;i<n;i++){
    const t=i/sr,p=t/dur,e=env(t,dur,attack,.02+decay*dur*.8,sustain),sweep=Math.pow(2,(sweepAmt*(1-p)*18)/12),vib=1+Math.sin(2*Math.PI*(3+vibrato*9)*t)*vibrato*.04,f=Math.max(20,base*sweep*vib);ph+=2*Math.PI*f/sr;subPh+=2*Math.PI*Math.max(24,f*.25)/sr;
    let osc=wave==='square'?(Math.sin(ph)>=0?1:-1):wave==='sawtooth'?2*((ph/(2*Math.PI))%1)-1:wave==='triangle'?2*Math.abs(2*((ph/(2*Math.PI))%1)-1)-1:Math.sin(ph);
    if(kind==='electric'&&rng()>.91)osc*=2.4;if(kind==='water')osc*=.5+.5*Math.sin(2*Math.PI*6.3*t);if(kind==='fire'&&rng()>.96)osc+=rand()*1.2;if(kind==='ice')osc+=Math.sin(ph*2.01)*.22;if(kind==='door')osc*=.7+.3*Math.sin(2*Math.PI*3.2*t);
    let noise=rand();if(kind==='wind'||kind==='ambience')noise*=.45+.55*Math.sin(Math.PI*Math.min(1,p));if(kind==='footstep')noise*=Math.exp(-p*12);if(kind==='explosion'||kind==='earth')noise*=Math.pow(1-p,1.6);
    const transientFreq=140+transientPitch*4200,transient=(Math.sin(2*Math.PI*transientFreq*t)*.62+noise*.38)*Math.exp(-t*(38+transientPitch*155))*transientMix;
    let v=(osc*toneMix+noise*noiseMix+Math.sin(subPh)*subMix)*e+transient;
    if(crush>.001){const bits=Math.max(3,Math.round(14-crush*10)),levels=1<<Math.min(15,bits);hold=Math.max(1,Math.round(1+crush*8));if(i%hold===0)held=Math.round(v*levels)/levels;v=(1-crush)*v+crush*held;}
    out[i]=soft(v,drive)*power*.72;
  }
  let filtered=lpFilter(out,cutoff,sr);filtered=delay(filtered,sr,delayMix,delayTime,feedback);let peak=1e-6;for(const v of filtered)peak=Math.max(peak,Math.abs(v));const g=Math.min(1,.96/peak);for(let i=0;i<filtered.length;i++)filtered[i]*=g;
  return {samples:filtered,sampleRate:sr,meta:{kind,duration:dur,toneMix,noiseMix,subMix,transientMix,wave,seed,pitchOffset,gainOffset}};
}
