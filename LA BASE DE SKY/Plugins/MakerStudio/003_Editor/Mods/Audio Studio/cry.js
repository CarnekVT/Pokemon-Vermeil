export const CRY_PRESETS = {
  small:{label:'Small creature',size:.15,organic:.75,aggression:.25,texture:.25,pitch:1.35,speed:1.15},
  bird:{label:'Bird / aerial',size:.22,organic:.8,aggression:.45,texture:.35,pitch:1.55,speed:1.25},
  dragon:{label:'Dragon / heavy',size:.95,organic:.85,aggression:.9,texture:.72,pitch:.58,speed:.82},
  ghost:{label:'Ghost / ethereal',size:.55,organic:.35,aggression:.5,texture:.68,pitch:.86,speed:.72},
  robot:{label:'Synthetic / robot',size:.5,organic:.05,aggression:.55,texture:.9,pitch:.95,speed:1.0},
  aquatic:{label:'Aquatic',size:.48,organic:.82,aggression:.3,texture:.32,pitch:.92,speed:.9},
  bug:{label:'Bug / insect',size:.25,organic:.6,aggression:.6,texture:.72,pitch:1.42,speed:1.18},
  ancient:{label:'Ancient / primal',size:.82,organic:.75,aggression:.65,texture:.48,pitch:.66,speed:.74},
  legendary:{label:'Legendary / imposing',size:.78,organic:.58,aggression:.78,texture:.5,pitch:.72,speed:.88},
  corrupted:{label:'Corrupted / unstable',size:.62,organic:.18,aggression:.86,texture:1,pitch:.82,speed:.92}
};

export const CRY_EFFECTS = {
  sub:{label:'Low Layer',description:'Adds a lower parallel voice for body and weight.',params:{ratio:{label:'Pitch ratio',min:.28,max:.9,step:.01,default:.52}}},
  upper:{label:'Upper / Shimmer',description:'Adds an upper parallel voice. Useful for crystalline or synthetic cries.',params:{ratio:{label:'Pitch ratio',min:1.05,max:2.4,step:.01,default:1.48}}},
  filter:{label:'Tone Filter',description:'Darkens the cry with a non-destructive low-pass stage.',params:{tone:{label:'Darkness',min:0,max:1,step:.01,default:.25}}},
  crush:{label:'Bit Crusher',description:'Reduces resolution and sample hold for digital / retro texture.',params:{bits:{label:'Bit depth',min:3,max:16,step:1,default:9},hold:{label:'Sample hold',min:1,max:10,step:1,default:3}}},
  chorus:{label:'Chorus / Width',description:'Creates a detuned, moving double without changing the original source.',params:{rate:{label:'Rate',min:.1,max:5,step:.05,default:.7},depth:{label:'Depth',min:.001,max:.014,step:.001,default:.005}}},
  ring:{label:'Ring Modulation',description:'Metallic inharmonic modulation for alien and future styles.',params:{freq:{label:'Frequency',min:20,max:700,step:1,default:173}}},
  grain:{label:'Reverse Grains',description:'Reverses short windows to create unstable or supernatural articulation.',params:{size:{label:'Grain size',min:.008,max:.12,step:.002,default:.035}}},
  glitch:{label:'Glitch Gate',description:'Rhythmic dropouts. Depth controls how hard the signal is gated.',params:{rate:{label:'Rate',min:6,max:80,step:1,default:28},depth:{label:'Depth',min:0,max:1,step:.01,default:.78}}},
  drive:{label:'Saturation',description:'Soft saturation for aggression and density.',params:{gain:{label:'Drive gain',min:1,max:14,step:.1,default:5}}},
  delay:{label:'Echo',description:'Short feedback echo. Kept as a separate wet/dry insert.',params:{time:{label:'Time',min:.012,max:.35,step:.002,default:.09},feedback:{label:'Feedback',min:0,max:.78,step:.01,default:.32}}},
  space:{label:'Space / Reverb',description:'Multi-tap ambience for legendary, Ultra Beast and transformation cries.',params:{size:{label:'Size',min:.02,max:.45,step:.01,default:.18},decay:{label:'Decay',min:.05,max:.85,step:.01,default:.34}}}
};

const FX_ORDER=['sub','upper','filter','crush','chorus','ring','grain','glitch','drive','delay','space'];
const fx=(id,mix=0,params={})=>({id,enabled:mix>.001,mix,params:{...params}});

export const SPECIAL_CRY_STYLES = {
  none:{label:'None / Natural',description:'No transformation chain. Creature body shaping remains editable.',chain:[]},
  paradoxPast:{label:'Paradox — Past',description:'Primal, rough, low-layered and aged.',chain:[fx('sub',.42,{ratio:.48}),fx('filter',.24,{tone:.42}),fx('crush',.16,{bits:11,hold:2}),fx('drive',.28,{gain:5.8}),fx('delay',.08,{time:.055,feedback:.2})]},
  paradoxFuture:{label:'Paradox — Future',description:'Digital, metallic, quantized and synthetic.',chain:[fx('upper',.31,{ratio:1.62}),fx('crush',.5,{bits:7,hold:4}),fx('ring',.43,{freq:241}),fx('glitch',.34,{rate:36,depth:.82}),fx('chorus',.1,{rate:1.8,depth:.003}),fx('delay',.12,{time:.045,feedback:.28})]},
  mega:{label:'Mega Evolution',description:'Expanded, doubled and explosive transformation.',chain:[fx('sub',.19,{ratio:.58}),fx('upper',.2,{ratio:1.42}),fx('chorus',.44,{rate:.62,depth:.008}),fx('drive',.34,{gain:6.5}),fx('space',.14,{size:.14,decay:.28})]},
  ultraBeast:{label:'Ultra Beast',description:'Alien, inharmonic, unstable and spatial.',chain:[fx('upper',.2,{ratio:1.73}),fx('ring',.55,{freq:173}),fx('grain',.31,{size:.026}),fx('crush',.24,{bits:9,hold:3}),fx('glitch',.2,{rate:22,depth:.58}),fx('space',.32,{size:.3,decay:.48})]},
  dynamax:{label:'Dynamax / Gigantamax',description:'Huge low body with long space and restrained digital artifacts.',chain:[fx('sub',.62,{ratio:.43}),fx('filter',.2,{tone:.32}),fx('drive',.29,{gain:5}),fx('chorus',.18,{rate:.4,depth:.006}),fx('delay',.32,{time:.16,feedback:.42}),fx('space',.48,{size:.38,decay:.58})]},
  terastal:{label:'Terastal',description:'Bright upper shimmer and crystalline reflections.',chain:[fx('upper',.55,{ratio:1.96}),fx('chorus',.31,{rate:1.1,depth:.004}),fx('ring',.13,{freq:322}),fx('delay',.24,{time:.11,feedback:.34}),fx('space',.34,{size:.23,decay:.4})]},
  shadow:{label:'Shadow / Corrupted',description:'Broken grains, distortion and unstable gating.',chain:[fx('sub',.14,{ratio:.57}),fx('crush',.41,{bits:6,hold:5}),fx('grain',.46,{size:.022}),fx('ring',.27,{freq:111}),fx('glitch',.5,{rate:31,depth:.9}),fx('drive',.6,{gain:9}),fx('space',.12,{size:.1,decay:.2})]}
};

const clamp=(v,a,b)=>Math.max(a,Math.min(b,v));
const lerp=(a,b,t)=>a+(b-a)*t;
function sampleAt(a,p){if(p<0||p>=a.length-1)return 0;const i=p|0,f=p-i;return a[i]*(1-f)+a[i+1]*f;}
function normalize(a,peak=.92){let m=1e-6;for(const v of a)m=Math.max(m,Math.abs(v));const g=Math.min(1.8,peak/m);for(let i=0;i<a.length;i++)a[i]*=g;return a;}
function cloneParams(id,p={}){const defs=CRY_EFFECTS[id]?.params||{},out={};for(const [k,d] of Object.entries(defs))out[k]=Number.isFinite(+p[k])?+p[k]:d.default;return out;}
export function chainForStyle(style='none'){const src=SPECIAL_CRY_STYLES[style]?.chain||[];return src.map(n=>({id:n.id,enabled:n.enabled!==false,mix:clamp(+n.mix||0,0,1),params:cloneParams(n.id,n.params)}));}
export function normalizeCryChain(chain,style='none',legacyFx=null){
  if(Array.isArray(chain))return chain.filter(n=>CRY_EFFECTS[n?.id]).map(n=>({id:n.id,enabled:n.enabled!==false,mix:clamp(+n.mix||0,0,1),params:cloneParams(n.id,n.params)}));
  if(legacyFx&&typeof legacyFx==='object'){const out=[];for(const id of FX_ORDER){const mix=clamp(+legacyFx[id]||0,0,1);if(mix>.001)out.push({id,enabled:true,mix,params:cloneParams(id,{})});}if(out.length)return out;}
  return chainForStyle(style);
}
function hashNoise(i,seed){let x=(i+1)^(seed*374761393);x=(x^(x>>>13))*1274126177;x^=x>>>16;return ((x>>>0)/4294967295)*2-1;}
function softClip(x,gain){return Math.tanh(x*Math.max(1,gain));}
function blend(dry,wet,mix){mix=clamp(mix,0,1);if(mix<=.001)return dry;const n=Math.min(dry.length,wet.length),out=new Float32Array(dry.length);for(let i=0;i<n;i++)out[i]=lerp(dry[i],wet[i],mix);for(let i=n;i<dry.length;i++)out[i]=dry[i];return out;}
function resample(a,ratio){ratio=clamp(ratio,.25,4);const n=Math.max(32,Math.floor(a.length/ratio)),out=new Float32Array(n);for(let i=0;i<n;i++)out[i]=sampleAt(a,i*ratio);return out;}
function hann(i,n){return .5-.5*Math.cos(2*Math.PI*i/Math.max(1,n-1));}
// Lightweight WSOLA. It is intentionally local/offline: cry editing stays deterministic,
// and pitch and duration no longer multiply together as they did in the old resampler.
function timeStretchWSOLA(a,factor,sr){
  factor=clamp(factor,.45,2.4);if(Math.abs(factor-1)<.012)return a.slice();
  const target=Math.max(64,Math.round(a.length*factor)),grain=Math.max(256,Math.min(2048,Math.round(sr*.032))),sHop=Math.max(64,Math.round(grain*.25)),overlap=grain-sHop,aHop=sHop/factor,search=Math.max(24,Math.round(sr*.0035));
  if(a.length<grain*2){const out=new Float32Array(target);for(let i=0;i<target;i++)out[i]=sampleAt(a,i/factor);return out;}
  const out=new Float32Array(target+grain),weights=new Float32Array(target+grain);let outPos=0,prevPos=0,expected=0,first=true;
  while(outPos<target){let pos=clamp(Math.round(expected),0,Math.max(0,a.length-grain-1));
    if(!first){let best=pos,bestC=-Infinity;const refStart=prevPos+sHop;
      for(let cand=Math.max(0,pos-search);cand<=Math.min(a.length-grain-1,pos+search);cand+=2){let c=0,aa=0,bb=0;const n=Math.min(overlap,512);for(let j=0;j<n;j+=2){const x=a[refStart+j]||0,y=a[cand+j]||0;c+=x*y;aa+=x*x;bb+=y*y;}const score=c/Math.sqrt(aa*bb+1e-12);if(score>bestC){bestC=score;best=cand;}}
      pos=best;
    }
    for(let j=0;j<grain&&outPos+j<out.length&&pos+j<a.length;j++){const w=hann(j,grain);out[outPos+j]+=a[pos+j]*w;weights[outPos+j]+=w;}
    prevPos=pos;outPos+=sHop;expected=pos+aHop;first=false;if(pos>=a.length-grain-2)break;
  }
  const cut=new Float32Array(target);for(let i=0;i<target;i++){const fallback=sampleAt(a,i/factor);if(weights[i]>.02)cut[i]=out[i]/weights[i];else if(weights[i]>.0001){const t=weights[i]/.02;cut[i]=lerp(fallback,out[i]/weights[i],t);}else cut[i]=fallback;}return cut;
}
function pitchShiftPreserveLength(a,ratio,sr){ratio=clamp(ratio,.3,2.8);if(Math.abs(ratio-1)<.008)return a.slice();const r=resample(a,ratio);return timeStretchWSOLA(r,ratio,sr).slice(0,a.length);}
function dcBlock(a){const out=new Float32Array(a.length);let xm1=0,ym1=0;for(let i=0;i<a.length;i++){const y=a[i]-xm1+.995*ym1;out[i]=y;xm1=a[i];ym1=y;}return out;}
function declick(a,sr,ms=7){const n=Math.min(Math.floor(a.length/2),Math.max(8,Math.round(sr*ms/1000)));for(let i=0;i<n;i++){const g=Math.sin((i/(n-1))*Math.PI/2);a[i]*=g;a[a.length-1-i]*=g;}return a;}
function pitchLayer(a,ratio,sr){return pitchShiftPreserveLength(a,ratio,sr);}
function lowpass(a,tone){const out=new Float32Array(a.length);let y=0;const alpha=.72-clamp(tone,0,1)*.68;for(let i=0;i<a.length;i++){y+=alpha*(a[i]-y);out[i]=y;}return out;}
function bitCrush(a,p){const bits=Math.round(clamp(p.bits||9,3,16)),levels=Math.pow(2,bits-1),hold=Math.round(clamp(p.hold||3,1,10)),out=new Float32Array(a.length);let held=0;for(let i=0;i<a.length;i++){if(i%hold===0)held=Math.round(a[i]*levels)/levels;out[i]=held;}return out;}
function chorus(a,sr,p){const rate=clamp(p.rate||.7,.1,5),depth=clamp(p.depth||.005,.001,.014),out=new Float32Array(a.length),base=sr*.007;for(let i=0;i<a.length;i++){const d=base+Math.sin(2*Math.PI*rate*i/sr)*sr*depth;out[i]=sampleAt(a,i-d);}return out;}
function ringMod(a,sr,p){const f=clamp(p.freq||173,20,700),out=new Float32Array(a.length);for(let i=0;i<a.length;i++)out[i]=a[i]*Math.sin(2*Math.PI*f*i/sr);return out;}
function reverseGrains(a,sr,p){const g=Math.max(16,Math.round(sr*clamp(p.size||.035,.008,.12))),out=a.slice();for(let s=0;s<a.length;s+=g){const len=Math.min(g,a.length-s);for(let j=0;j<len;j++)out[s+j]=a[s+len-1-j]||0;}/* Grain reversals can create hard sample discontinuities at every boundary. A tiny post-smoother keeps the supernatural articulation without digital clicks. */let y=out[0]||0;for(let i=1;i<out.length;i++){y+=.32*(out[i]-y);out[i]=y;}return out;}
function glitchGate(a,sr,p,seed){const rate=clamp(p.rate||28,6,80),depth=clamp(p.depth??.78,0,1),block=Math.max(16,Math.round(sr/rate)),out=new Float32Array(a.length),ramp=Math.max(8,Math.round(sr*.0015));let prevGate=1;for(let s=0;s<a.length;s+=block){const idx=(s/block)|0,target=hashNoise(idx,seed+31)>.35?1:1-depth,end=Math.min(a.length,s+block);for(let i=s;i<end;i++){const k=i-s,t=clamp(k/ramp,0,1),gate=lerp(prevGate,target,.5-.5*Math.cos(Math.PI*t));out[i]=a[i]*gate;}prevGate=target;}return out;}
function drive(a,p){const gain=clamp(p.gain||5,1,14),out=new Float32Array(a.length);let y=0;for(let i=0;i<a.length;i++){const v=softClip(a[i],gain);y+=.7*(v-y);out[i]=y;}return out;}
function echo(a,sr,p){const time=clamp(p.time||.09,.012,.35),fb=clamp(p.feedback||.32,0,.78),d=Math.max(1,Math.round(sr*time)),out=a.slice();for(let i=d;i<out.length;i++)out[i]=clamp(a[i]+out[i-d]*fb,-1.25,1.25);return out;}
function space(a,sr,p){const size=clamp(p.size||.18,.02,.45),dec=clamp(p.decay||.34,.05,.85),out=a.slice(),taps=[.037,.071,.113,.179].map(t=>Math.max(1,Math.round(sr*t*(.65+size*1.7))));for(let i=0;i<out.length;i++){let w=0;for(let k=0;k<taps.length;k++){const j=i-taps[k];if(j>=0)w+=a[j]*Math.pow(dec,k+1)*(.62/(k+1));}out[i]=clamp(a[i]+w,-1.25,1.25);}return out;}
function applyEffect(a,sr,node,seed){const p=cloneParams(node.id,node.params);let wet=a;switch(node.id){case'sub':wet=pitchLayer(a,p.ratio,sr);break;case'upper':wet=pitchLayer(a,p.ratio,sr);break;case'filter':wet=lowpass(a,p.tone);break;case'crush':wet=bitCrush(a,p);break;case'chorus':wet=chorus(a,sr,p);break;case'ring':wet=ringMod(a,sr,p);break;case'grain':wet=reverseGrains(a,sr,p);break;case'glitch':wet=glitchGate(a,sr,p,seed);break;case'drive':wet=drive(a,p);break;case'delay':wet=echo(a,sr,p);break;case'space':wet=space(a,sr,p);break;}return blend(a,wet,node.mix);}

export function processCrySamples(input,sampleRate,opts={}){
  const size=clamp(opts.size??.5,0,1),organic=clamp(opts.organic??.5,0,1),aggression=clamp(opts.aggression??.5,0,1),texture=clamp(opts.texture??.5,0,1),seed=(opts.variationSeed|0)||1;
  const pitch=clamp(opts.pitch??(1.15-size*.55),.3,2.8),speed=clamp(opts.speed??(1.08-size*.28),.4,1.8);
  // Clean body stage: pitch and time are independent. The previous implementation used
  // sourceIndex = pitch * speed and produced zero-filled/aliased tails for many presets.
  let base=pitchShiftPreserveLength(input,pitch,sampleRate);base=timeStretchWSOLA(base,1/speed,sampleRate);base=dcBlock(base);
  const dark=lowpass(base,.12+size*.36),body=new Float32Array(base.length),noiseAmt=Math.max(0,texture-.62)*.0045;
  for(let i=0;i<body.length;i++){
    let v=lerp(base[i],dark[i],.12+organic*.32+size*.14);
    if(noiseAmt>0)v+=hashNoise(i,seed)*noiseAmt;
    v=softClip(v,1+aggression*2.4+texture*.55);body[i]=v*.78;
  }
  declick(body,sampleRate,8);
  const chain=normalizeCryChain(opts.chain,opts.special||'none',opts.fx),specialAmount=clamp(opts.specialAmount??1,0,1);let out=body;
  for(let i=0;i<chain.length;i++){const n=chain[i];if(n.enabled===false||n.mix<=.001)continue;out=applyEffect(out,sampleRate,{...n,mix:n.mix*specialAmount},seed+i*97);}
  out=dcBlock(out);declick(out,sampleRate,7);normalize(out,.91);return {samples:out,sampleRate,style:opts.special||'none',chain};
}
