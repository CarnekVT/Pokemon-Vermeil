import { midiToFreq } from './pitch.js';
import { monoFloatToAudioBuffer } from './wav.js';

const clamp=(v,a,b)=>Math.max(a,Math.min(b,v));
const TRACKS=['melody','harmony','bass','drums'];
const DRUM_MIDI={kick:36,snare:38,hat:42};

export class AudioEngine {
  constructor(){ this.ctx=null; this.nodes=[]; this.soundfonts=new Map(); this.sampleBufferCache=new WeakMap(); this.playToken=0; }
  ensure(){ if(!this.ctx) this.ctx=new (window.AudioContext||window.webkitAudioContext)(); if(this.ctx.state==='suspended')this.ctx.resume(); return this.ctx; }
  setSoundFont(id,bank){ if(!id)return; if(bank)this.soundfonts.set(id,bank); else this.soundfonts.delete(id); this.sampleBufferCache=new WeakMap(); }
  removeSoundFont(id){this.soundfonts.delete(id);this.sampleBufferCache=new WeakMap();}
  clearSoundFonts(){this.soundfonts.clear();this.sampleBufferCache=new WeakMap();}
  soundFont(id){return this.soundfonts.get(id)||null;}
  stop(){ this.playToken++; for(const n of this.nodes.splice(0)){ try{n.stop?.();}catch{} try{n.disconnect?.();}catch{} } }
  async decode(arrayBuffer){ return await this.ensure().decodeAudioData(arrayBuffer.slice(0)); }
  playBuffer(buffer, opts={}){
    const ctx=this.ensure(); this.stop(); const src=ctx.createBufferSource(); src.buffer=buffer; src.playbackRate.value=opts.rate||1;
    const gain=ctx.createGain(); gain.gain.value=opts.gain??1; src.connect(gain).connect(ctx.destination); src.start(); this.nodes.push(src,gain); return src;
  }
  playSamples(samples,sr=44100){ const ctx=this.ensure(); return this.playBuffer(monoFloatToAudioBuffer(ctx,samples,sr)); }
  activeTracks(song){
    const st=song.trackState||{}; const solos=TRACKS.filter(t=>st[t]?.solo); return new Set(TRACKS.filter(t=>!st[t]?.mute&&(!solos.length||st[t]?.solo)));
  }
  _trackBus(ctx,dst,song,track){
    const st=song.trackState?.[track]||{},g=ctx.createGain();g.gain.value=clamp(Number.isFinite(+st.gain)?+st.gain:1,0,2);
    if(ctx.createStereoPanner){const p=ctx.createStereoPanner();p.pan.value=clamp(Number.isFinite(+st.pan)?+st.pan:0,-1,1);g.connect(p).connect(dst);this.nodes.push(g,p);}else{g.connect(dst);this.nodes.push(g);}return g;
  }
  instrumentFor(song,track){
    const inst=song.trackInstruments?.[track]; if(inst&&(!inst.ownerTrack||inst.ownerTrack===track))return inst;
    if(track==='drums')return {kind:'proceduralDrums'};
    const wave=track==='melody'?(song.melodyWave||'triangle'):track==='harmony'?(song.harmonyWave||'sine'):(song.bassWave||'square');
    return {kind:'osc',wave};
  }
  layersFor(song,track){
    let arr=song.trackLayers?.[track];if(Array.isArray(arr))arr=arr.filter(x=>x&&(!x.ownerTrack||x.ownerTrack===track));if(!Array.isArray(arr)||!arr.length)arr=[this.instrumentFor(song,track)];const solos=arr.filter(x=>x?.solo&&!x?.mute);return arr.filter(x=>x&&!x.mute&&(!solos.length||x.solo));
  }
  _bufferForSample(ctx,bank,sampleID){
    let per=this.sampleBufferCache.get(ctx); if(!per){per=new Map();this.sampleBufferCache.set(ctx,per);} const key=`${bank?.name||'sf'}:${sampleID}`;if(per.has(key))return per.get(key);
    const data=bank.sampleData(sampleID),info=bank.shdr[sampleID]; if(!data||!info)return null; const b=ctx.createBuffer(1,data.length,Math.max(8000,info.sampleRate||44100)); b.getChannelData(0).set(data); per.set(key,b); return b;
  }
  _scheduleSf2(ctx,dst,bank,preset,n,s,playDur,level=1,layerPan=0){
    const reg=bank?.regionFor(preset,n.midi,Math.round((n.velocity??.75)*127)); if(!reg)return false; const info=bank.sampleInfo(reg),buf=this._bufferForSample(ctx,bank,reg.sampleID); if(!info||!buf)return false;
    const src=ctx.createBufferSource(),g=ctx.createGain(); src.buffer=buf; src.playbackRate.value=bank.playbackRate(reg,n.midi);
    const smp=bank.shdr[reg.sampleID]; const relStart=Math.max(0,info.start-smp.start),relEnd=Math.max(relStart+1,info.end-smp.start);
    const offset=relStart/(smp.sampleRate||44100), maxDur=(relEnd-relStart)/(smp.sampleRate||44100)/Math.max(.01,src.playbackRate.value);
    const loop=(reg.sampleModes&1)!==0 || (reg.sampleModes&3)===3; if(loop){src.loop=true;src.loopStart=Math.max(0,(info.loopStart-smp.start)/(smp.sampleRate||44100));src.loopEnd=Math.max(src.loopStart+.001,(info.loopEnd-smp.start)/(smp.sampleRate||44100));}
    const env=reg.env||{}, attack=Math.min(playDur*.7,Math.max(.002,env.attack||.008)), release=Math.min(Math.max(.015,env.release||.08),playDur*.8), sustain=Math.pow(10,-Math.max(0,env.sustainCb||0)/200);
    const atten=Math.pow(10,-Math.max(0,reg.attenuation||0)/200); const peak=Math.max(.0001,(n.velocity??.75)*level*atten);
    g.gain.setValueAtTime(.0001,s); g.gain.exponentialRampToValueAtTime(peak,s+attack); if(playDur>attack+release)g.gain.setValueAtTime(Math.max(.0001,peak*sustain),s+playDur-release); g.gain.exponentialRampToValueAtTime(.0001,s+playDur);
    const finalPan=clamp((reg.pan||0)+(layerPan||0),-1,1);if(ctx.createStereoPanner&&Math.abs(finalPan)>.01){const p=ctx.createStereoPanner();p.pan.value=finalPan;src.connect(g).connect(p).connect(dst);this.nodes.push(p);} else src.connect(g).connect(dst);
    if(loop) src.start(s,offset); else src.start(s,offset,Math.max(.01,Math.min(maxDur,playDur+.1))); src.stop(s+playDur+.08); this.nodes.push(src,g); return true;
  }
  _scheduleOsc(ctx,dst,n,s,playDur,wave='triangle',level=.2,layerPan=0){
    const o=ctx.createOscillator(),g=ctx.createGain();o.type=wave||'triangle';o.frequency.value=midiToFreq(n.midi);const vel=n.velocity??.72;
    g.gain.setValueAtTime(.0001,s);g.gain.exponentialRampToValueAtTime(Math.max(.001,vel*level),s+.012);g.gain.exponentialRampToValueAtTime(.0001,s+playDur);if(ctx.createStereoPanner&&Math.abs(layerPan||0)>.01){const p=ctx.createStereoPanner();p.pan.value=clamp(layerPan,-1,1);o.connect(g).connect(p).connect(dst);this.nodes.push(p);}else o.connect(g).connect(dst);o.start(s);o.stop(s+playDur+.03);this.nodes.push(o,g);
  }
  _scheduleNote(ctx,dst,song,track,n,startBase,startAt,level){
    const originalEnd=n.start+n.duration;if(originalEnd<=startAt)return;const localStart=Math.max(0,n.start-startAt),trimmed=Math.max(.025,originalEnd-Math.max(n.start,startAt)),s=startBase+localStart,layers=this.layersFor(song,track),stackScale=1/Math.sqrt(Math.max(1,layers.length));for(const inst of layers){const gain=clamp(Number.isFinite(+inst.gain)?+inst.gain:1,0,2),pan=clamp(Number.isFinite(+inst.pan)?+inst.pan:0,-1,1),transpose=clamp(Math.round(+inst.transpose||0),-48,48),nn={...n,midi:clamp((n.midi||60)+transpose,0,127)};if(inst.kind==='sf2'&&Number.isFinite(+inst.preset)){const bank=this.soundFont(inst.bankId);if(bank&&this._scheduleSf2(ctx,dst,bank,+inst.preset,nn,s,trimmed,level*gain*stackScale,pan))continue;}this._scheduleOsc(ctx,dst,nn,s,trimmed,inst.wave||(track==='bass'?'square':'triangle'),level*gain*stackScale,pan);}
  }
  _scheduleDrumHit(ctx,dst,song,h,time){
    const layers=this.layersFor(song,'drums'),stackScale=1/Math.sqrt(Math.max(1,layers.length));for(const inst of layers){const gain=clamp(Number.isFinite(+inst.gain)?+inst.gain:1,0,2),pan=clamp(Number.isFinite(+inst.pan)?+inst.pan:0,-1,1),transpose=clamp(Math.round(+inst.transpose||0),-48,48);if(inst.kind==='sf2'&&Number.isFinite(+inst.preset)){const bank=this.soundFont(inst.bankId),midi=clamp((DRUM_MIDI[h.type]||36)+transpose,0,127);if(bank&&this._scheduleSf2(ctx,dst,bank,+inst.preset,{midi,velocity:clamp((h.gain||.3)*2.3,.2,1)},time,.24,.8*gain*stackScale,pan))continue;}this._scheduleDrum(ctx,dst,time,h.type,(h.gain||.3)*gain*stackScale,pan);}
  }
  _scheduleClick(ctx,dst,t,accent=false){
    const o=ctx.createOscillator(),g=ctx.createGain();o.type='square';o.frequency.value=accent?1320:920;
    g.gain.setValueAtTime(.0001,t);g.gain.exponentialRampToValueAtTime(accent?.13:.085,t+.002);g.gain.exponentialRampToValueAtTime(.0001,t+.055);
    o.connect(g).connect(dst);o.start(t);o.stop(t+.06);this.nodes.push(o,g);
  }
  playSong(song,opts={}){
    const ctx=this.ensure();this.stop();const startAt=Math.max(0,opts.startAt||0),now=ctx.currentTime+.035,songEnd=this.songDuration(song),refOffset=Number.isFinite(+opts.referenceOffset)?+opts.referenceOffset:0,refEnd=opts.referenceBuffer?refOffset+opts.referenceBuffer.duration:0,end=Math.max(songEnd,refEnd),active=opts.reference===false?new Set():this.activeTracks(song);const master=ctx.createGain();master.gain.value=.72*clamp(Number.isFinite(+song.masterGain)?+song.masterGain:.92,0,1.5)*clamp(Number.isFinite(+opts.referenceGain)?+opts.referenceGain:1,.05,1.5);master.connect(ctx.destination);this.nodes.push(master);
    const levels={melody:.32,harmony:.19,bass:.15}; for(const track of ['melody','harmony','bass'])if(active.has(track)){const bus=this._trackBus(ctx,master,song,track),arr=track==='melody'?song.notes:(song[track]||[]);for(const n of arr)this._scheduleNote(ctx,bus,song,track,n,now,startAt,levels[track]);}
    if(active.has('drums')){const bus=this._trackBus(ctx,master,song,'drums');for(const h of song.drums||[])if(h.t>=startAt)this._scheduleDrumHit(ctx,bus,song,h,now+h.t-startAt);}
    if(opts.referenceBuffer&&!opts.referenceMuted){const src=ctx.createBufferSource(),g=ctx.createGain();src.buffer=opts.referenceBuffer;g.gain.value=clamp(Number.isFinite(+opts.referenceAudioGain)?+opts.referenceAudioGain:.55,0,1.5);src.connect(g).connect(master);const sourceOffset=Math.max(0,startAt-refOffset),when=now+Math.max(0,refOffset-startAt);if(sourceOffset<src.buffer.duration){src.start(when,sourceOffset);this.nodes.push(src,g);}}
    if(opts.metronome){const beat=60/(song.bpm||120),first=Math.ceil(startAt/beat),clickEnd=Math.max(end,startAt+(opts.metronomeDuration||120));for(let bi=first;bi*beat<=clickEnd;bi++){const bt=bi*beat,t=now+bt-startAt;this._scheduleClick(ctx,master,t,bi%4===0);}}
    return {duration:Math.max(0,end-startAt),startContextTime:now,startAt,end};
  }
  auditionNote(song,track,midi,velocity=.8,duration=.5){const ctx=this.ensure();this.stop();const master=ctx.createGain();master.gain.value=.8;master.connect(ctx.destination);this.nodes.push(master);const bus=this._trackBus(ctx,master,song,track);this._scheduleNote(ctx,bus,song,track,{start:0,duration,midi,velocity},ctx.currentTime+.025,0,track==='bass'?.18:.3);return true;}
  auditionSf2(bankId,preset,{drums=false,midi=60}={}){
    const bank=this.soundFont(bankId);if(!bank)return false;const ctx=this.ensure();this.stop();const master=ctx.createGain();master.gain.value=.8;master.connect(ctx.destination);this.nodes.push(master);const now=ctx.currentTime+.03;
    if(drums){for(const [i,n] of [36,38,42].entries())this._scheduleSf2(ctx,master,bank,+preset,{midi:n,velocity:.9},now+i*.28,.22,.8);}
    else {this._scheduleSf2(ctx,master,bank,+preset,{midi,velocity:.88},now,1.05,.7);}
    return true;
  }
  _scheduleDrum(ctx,dst,t,type,gain,layerPan=0){
    if(type==='hat'){
      const len=Math.floor(ctx.sampleRate*.045),b=ctx.createBuffer(1,len,ctx.sampleRate),a=b.getChannelData(0);for(let i=0;i<len;i++)a[i]=(Math.random()*2-1)*(1-i/len);
      const s=ctx.createBufferSource(),f=ctx.createBiquadFilter(),g=ctx.createGain();s.buffer=b;f.type='highpass';f.frequency.value=6000;g.gain.value=gain;if(ctx.createStereoPanner&&Math.abs(layerPan||0)>.01){const p=ctx.createStereoPanner();p.pan.value=clamp(layerPan,-1,1);s.connect(f).connect(g).connect(p).connect(dst);this.nodes.push(p);}else s.connect(f).connect(g).connect(dst);s.start(t);this.nodes.push(s,f,g);return;
    }
    const o=ctx.createOscillator(),g=ctx.createGain();o.type=type==='snare'?'triangle':'sine';o.frequency.setValueAtTime(type==='snare'?180:110,t);o.frequency.exponentialRampToValueAtTime(type==='snare'?95:48,t+.12);g.gain.setValueAtTime(gain,t);g.gain.exponentialRampToValueAtTime(.0001,t+(type==='snare'?.11:.18));if(ctx.createStereoPanner&&Math.abs(layerPan||0)>.01){const p=ctx.createStereoPanner();p.pan.value=clamp(layerPan,-1,1);o.connect(g).connect(p).connect(dst);this.nodes.push(p);}else o.connect(g).connect(dst);o.start(t);o.stop(t+.2);this.nodes.push(o,g);
  }
  songDuration(song){const sets=[song.notes||[],song.harmony||[],song.bass||[]].flat();const n=sets.length?Math.max(...sets.map(x=>x.start+x.duration)):0;const d=song.drums?.length?Math.max(...song.drums.map(x=>x.t))+.3:0;const content=Math.max(n,d);const bars=(song.timeline?.bars||4)*4*(60/(song.bpm||120));return content>0?Math.max(content,.25):Math.max(1,bars);}
  async renderSong(song,sampleRate=44100){
    const duration=Math.max(.5,this.songDuration(song)+.25),offline=new OfflineAudioContext(2,Math.ceil(duration*sampleRate),sampleRate),master=offline.createGain();master.gain.value=.78*clamp(Number.isFinite(+song.masterGain)?+song.masterGain:.92,0,1.5);master.connect(offline.destination);const active=this.activeTracks(song);
    const oldNodes=this.nodes;this.nodes=[];try{
      const levels={melody:.32,harmony:.19,bass:.15};for(const track of ['melody','harmony','bass'])if(active.has(track)){const bus=this._trackBus(offline,master,song,track),arr=track==='melody'?song.notes:(song[track]||[]);for(const n of arr)this._scheduleNote(offline,bus,song,track,n,0,0,levels[track]);}
      if(active.has('drums')){const bus=this._trackBus(offline,master,song,'drums');for(const h of song.drums||[])this._scheduleDrumHit(offline,bus,song,h.t);}return await offline.startRendering();
    } finally {this.nodes=oldNodes;}
  }
}
