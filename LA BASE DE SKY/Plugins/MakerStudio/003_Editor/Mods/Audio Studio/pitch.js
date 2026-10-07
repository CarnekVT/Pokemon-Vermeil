const NOTE_NAMES = ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"];
export const SCALES = {
  major: [0,2,4,5,7,9,11], minor: [0,2,3,5,7,8,10], dorian: [0,2,3,5,7,9,10],
  pentatonic: [0,2,4,7,9], minorPentatonic: [0,3,5,7,10], chromatic: [0,1,2,3,4,5,6,7,8,9,10,11]
};
export function midiToName(m) { return `${NOTE_NAMES[((Math.round(m)%12)+12)%12]}${Math.floor(Math.round(m)/12)-1}`; }
export function midiToFreq(m) { return 440 * Math.pow(2, (m - 69) / 12); }
export function freqToMidiFloat(f) { return 69 + 12 * Math.log2(f / 440); }
export function freqToMidi(f) { return Math.round(freqToMidiFloat(f)); }

const clamp=(v,a,b)=>Math.max(a,Math.min(b,v));
function rms(frame) { let s=0; for (let i=0;i<frame.length;i++) s+=frame[i]*frame[i]; return Math.sqrt(s/Math.max(1,frame.length)); }
function percentile(values,p){if(!values.length)return 0;const a=[...values].sort((x,y)=>x-y),i=clamp(Math.floor((a.length-1)*p),0,a.length-1);return a[i];}
function median(values){if(!values.length)return null;const a=[...values].sort((x,y)=>x-y);const m=a.length>>1;return a.length%2?a[m]:(a[m-1]+a[m])*.5;}
function weightedMedian(items){
  if(!items.length)return null;const a=items.filter(x=>Number.isFinite(x.v)&&x.w>0).sort((x,y)=>x.v-y.v);if(!a.length)return null;
  const total=a.reduce((s,x)=>s+x.w,0);let run=0;for(const x of a){run+=x.w;if(run>=total*.5)return x.v;}return a[a.length-1].v;
}
function monoMix(buffer){
  const ch=Math.max(1,buffer.numberOfChannels||1),len=buffer.length||buffer.getChannelData(0).length,out=new Float32Array(len);
  for(let c=0;c<ch;c++){const a=buffer.getChannelData(c);for(let i=0;i<len;i++)out[i]+=a[i]/ch;}return out;
}
function downsample(data,srcRate,targetRate){
  if(srcRate<=targetRate*1.08)return {data:new Float32Array(data),sampleRate:srcRate};
  const ratio=srcRate/targetRate,n=Math.max(1,Math.floor(data.length/ratio)),out=new Float32Array(n);
  for(let i=0;i<n;i++){const a=Math.floor(i*ratio),b=Math.min(data.length,Math.max(a+1,Math.floor((i+1)*ratio)));let s=0;for(let j=a;j<b;j++)s+=data[j];out[i]=s/(b-a);}return {data:out,sampleRate:srcRate/ratio};
}
function highpass(data,sr,hz){if(hz<=0)return new Float32Array(data);const out=new Float32Array(data.length),dt=1/sr,rc=1/(2*Math.PI*hz),alpha=rc/(rc+dt);let y=0,prev=data[0]||0;for(let i=0;i<data.length;i++){const x=data[i];y=alpha*(y+x-prev);out[i]=y;prev=x;}return out;}
function lowpass(data,sr,hz){if(hz<=0||hz>=sr*.48)return new Float32Array(data);const out=new Float32Array(data.length),dt=1/sr,rc=1/(2*Math.PI*hz),alpha=dt/(rc+dt);let y=data[0]||0;for(let i=0;i<data.length;i++){y+=alpha*(data[i]-y);out[i]=y;}return out;}
function removeDc(data){const out=new Float32Array(data.length);let mean=0;for(const v of data)mean+=v;mean/=Math.max(1,data.length);for(let i=0;i<data.length;i++)out[i]=data[i]-mean;return out;}
function rangeFor(profile='voice',voiceRange='auto'){
  if(profile==='whistle')return [220,3600];
  if(profile==='hum'){
    if(voiceRange==='low')return [55,260];if(voiceRange==='mid')return [80,440];if(voiceRange==='high')return [130,720];return [55,720];
  }
  if(voiceRange==='low')return [60,330];if(voiceRange==='mid')return [95,620];if(voiceRange==='high')return [160,1050];return [65,1050];
}
function preprocess(data,sr,profile='voice',voiceRange='auto'){
  const [lo,hi]=rangeFor(profile,voiceRange),target=profile==='whistle'?22050:12000,d=downsample(data,sr,target);
  // Keep the fundamental while trimming rumble and excessive high-frequency consonant/noise energy.
  let x=highpass(d.data,d.sampleRate,Math.max(28,lo*.48));x=lowpass(x,d.sampleRate,Math.min(profile==='whistle'?hi*1.12:Math.max(1500,hi*1.75),d.sampleRate*.46));x=removeDc(x);
  return {data:x,sampleRate:d.sampleRate,minHz:lo,maxHz:Math.min(hi,d.sampleRate*.45)};
}
function frameCentered(data,start,size){
  const out=new Float32Array(size);let mean=0;for(let i=0;i<size;i++)mean+=data[start+i]||0;mean/=size;
  // A light Hann taper reduces edge discontinuities without destroying the periodicity cue.
  for(let i=0;i<size;i++){const w=.5-.5*Math.cos(2*Math.PI*i/(size-1));out[i]=((data[start+i]||0)-mean)*w;}return out;
}
function normalizedCorr(frame,tau,limit){
  let xy=0,x2=0,y2=0;for(let i=0;i<limit;i++){const a=frame[i],b=frame[i+tau];xy+=a*b;x2+=a*a;y2+=b*b;}return x2>1e-12&&y2>1e-12?xy/Math.sqrt(x2*y2):0;
}
function refineTau(cmnd,tau,maxTau){
  let refined=tau;if(tau>1&&tau<maxTau){const a=cmnd[tau-1],b=cmnd[tau],c=cmnd[tau+1],den=a-2*b+c;if(Math.abs(den)>1e-9)refined=tau+.5*(a-c)/den;}return refined;
}
// Multi-candidate YIN front end. Instead of committing to one trough per frame,
// it returns several plausible F0 candidates so temporal tracking can reject
// octave/harmonic mistakes using surrounding frames.
function yinCandidates(frame,sampleRate,minHz=65,maxHz=1200,threshold=.17,maxCandidates=5){
  const minTau=Math.max(2,Math.floor(sampleRate/maxHz)),maxTau=Math.min(frame.length-4,Math.ceil(sampleRate/minHz));
  if(maxTau<=minTau)return [];
  const diff=new Float32Array(maxTau+1),limit=Math.max(32,frame.length-maxTau-2);
  for(let tau=1;tau<=maxTau;tau++){let d=0;for(let i=0;i<limit;i++){const z=frame[i]-frame[i+tau];d+=z*z;}diff[tau]=d;}
  const cmnd=new Float32Array(maxTau+1);cmnd[0]=1;let run=0;for(let tau=1;tau<=maxTau;tau++){run+=diff[tau];cmnd[tau]=run>1e-12?diff[tau]*tau/run:1;}
  const taus=[];let firstThreshold=-1,firstReliable=-1;
  for(let t=minTau+1;t<maxTau;t++){
    if(firstThreshold<0&&cmnd[t]<threshold)firstThreshold=t;
    if(cmnd[t]<=cmnd[t-1]&&cmnd[t]<cmnd[t+1]&&cmnd[t]<.58)taus.push(t);
  }
  if(firstThreshold>=0){let t=firstThreshold;while(t+1<=maxTau&&cmnd[t+1]<cmnd[t])t++;firstReliable=t;if(!taus.includes(t))taus.push(t);}
  if(!taus.length){let best=minTau;for(let t=minTau+1;t<=maxTau;t++)if(cmnd[t]<cmnd[best])best=t;if(cmnd[best]<.62)taus.push(best);}
  const candidates=[];
  for(const tau of taus){
    const refined=refineTau(cmnd,tau,maxTau),freq=sampleRate/refined;if(!Number.isFinite(freq)||freq<minHz||freq>maxHz)continue;
    const corr=clamp(normalizedCorr(frame,tau,limit),-1,1),periodicity=clamp(1-cmnd[tau],0,1);
    let confidence=clamp(periodicity*.74+Math.max(0,corr)*.26+(tau===firstReliable?.105:0),0,1);
    // Prefer the lower F0 when an octave-up candidate is only marginally stronger.
    candidates.push({freq,midiFloat:freqToMidiFloat(freq),confidence,periodicity,corr,tau,cmnd:cmnd[tau]});
  }
  candidates.sort((a,b)=>b.confidence-a.confidence||a.freq-b.freq);
  const dedup=[];for(const c of candidates){if(dedup.some(x=>Math.abs(x.midiFloat-c.midiFloat)<.28))continue;dedup.push(c);if(dedup.length>=maxCandidates)break;}return dedup;
}
function transitionCost(a,b){
  const av=a?.midiFloat,bv=b?.midiFloat;if(av==null&&bv==null)return .015;if(av==null||bv==null)return .36;
  const d=Math.abs(av-bv);let c=d<.7?d*.018:d<2?(.02+d*.045):d<5?(.10+d*.085):(.30+d*.115);
  if(d>10.4&&d<13.6)c+=.95; // common octave-tracking error
  if(d>18)c+=.55;return c;
}
function viterbiTrack(frames,gateFactor,minConfidence){
  if(!frames.length)return [];
  const states=frames.map(f=>{
    const ratio=f.ratio,low=ratio<gateFactor||f.energy<f.energyGate,best=f.candidates[0]?.confidence||0;
    const uvConfidence=clamp(low?.92:(1-best)*.72+.12,.06,.96);
    const voiced=f.candidates.filter(c=>c.confidence>=Math.max(.28,minConfidence*.62)).map(c=>({...c,voiced:true}));
    return [{midiFloat:null,freq:0,confidence:uvConfidence,voiced:false},...voiced];
  });
  const costs=[],backs=[];
  for(let i=0;i<states.length;i++){
    const row=new Float64Array(states[i].length),back=new Int16Array(states[i].length);row.fill(Number.POSITIVE_INFINITY);back.fill(-1);
    for(let j=0;j<states[i].length;j++){
      const st=states[i][j],f=frames[i];
      let emission;
      if(st.voiced){const snrPenalty=f.ratio<gateFactor*1.08?.48:0;emission=-Math.log(clamp(st.confidence,.025,.999))+snrPenalty;}
      else{const strong=f.ratio>gateFactor*1.25&&(f.candidates[0]?.confidence||0)>minConfidence;emission=strong?.82:.10;}
      if(i===0){row[j]=emission;continue;}
      for(let k=0;k<states[i-1].length;k++){
        const c=costs[i-1][k]+transitionCost(states[i-1][k],st)+emission;if(c<row[j]){row[j]=c;back[j]=k;}
      }
    }
    costs.push(row);backs.push(back);
  }
  let idx=0,last=costs[costs.length-1];for(let j=1;j<last.length;j++)if(last[j]<last[idx])idx=j;
  const chosen=new Array(states.length);for(let i=states.length-1;i>=0;i--){chosen[i]=states[i][idx];idx=i>0?backs[i][idx]:0;if(idx<0)idx=0;}return chosen;
}
function cleanPitchTrack(points,minConfidence){
  const out=points.map(p=>({...p}));
  // Remove isolated voiced specks and fill only tiny unvoiced holes between nearly identical pitches.
  for(let i=1;i<out.length-1;i++){
    const p=out[i],a=out[i-1],b=out[i+1];
    if(p.voiced&&!a.voiced&&!b.voiced&&p.confidence<Math.max(.78,minConfidence+.1)){p.voiced=false;p.midiFloat=null;p.midi=null;p.freq=0;continue;}
    if(!p.voiced&&a.voiced&&b.voiced&&Math.abs(a.midiFloat-b.midiFloat)<1.2){p.voiced=true;p.midiFloat=(a.midiFloat+b.midiFloat)*.5;p.midi=Math.round(p.midiFloat);p.freq=midiToFreq(p.midiFloat);p.confidence=Math.min(a.confidence,b.confidence)*.88;}
  }
  // Robust median smoothing over the continuous F0 contour.
  for(let i=0;i<out.length;i++){
    const p=out[i];if(!p.voiced)continue;const vals=[];for(let j=Math.max(0,i-3);j<=Math.min(out.length-1,i+3);j++)if(out[j].voiced&&out[j].midiFloat!=null)vals.push({v:out[j].midiFloat,w:Math.max(.1,out[j].confidence)});
    const m=weightedMedian(vals);if(m!=null){p.midiFloat=m;p.midi=Math.round(m);p.freq=midiToFreq(m);}
  }
  // Correct single-frame octave jumps that survive candidate tracking.
  let octaveFixes=0;for(let i=1;i<out.length-1;i++){const p=out[i],a=out[i-1],b=out[i+1];if(!p.voiced||!a.voiced||!b.voiced)continue;const neighbor=(a.midiFloat+b.midiFloat)*.5,d=Math.abs(p.midiFloat-neighbor);if(d>10&&d<14&&Math.abs(a.midiFloat-b.midiFloat)<2){p.midiFloat=neighbor;p.midi=Math.round(neighbor);p.freq=midiToFreq(neighbor);octaveFixes++;}}
  return {points:out,octaveFixes};
}

export function snapMidiToScale(midi, root=0, scaleName="minor") {
  const scale = SCALES[scaleName] || SCALES.minor;let best=Math.round(midi), dist=99;
  for (let d=-12; d<=12; d++) {const c=Math.round(midi)+d, pc=((c-root)%12+12)%12;if (scale.includes(pc) && Math.abs(c-midi)<dist) { best=c; dist=Math.abs(c-midi); }}return best;
}

export function analyzePitch(buffer, opts={}) {
  const src=monoMix(buffer),profile=opts.profile||'voice',voiceRange=opts.voiceRange||'auto',pre=preprocess(src,buffer.sampleRate,profile,voiceRange),data=pre.data,sr=pre.sampleRate;
  const frameSize=opts.frameSize||(profile==='whistle'?2048:3072),hop=opts.hop||(profile==='whistle'?176:144),raw=[];
  for(let start=0;start+frameSize<data.length;start+=hop)raw.push({start,t:(start+frameSize*.25)/sr,energy:rms(data.subarray(start,start+frameSize))});
  const energies=raw.map(x=>x.energy),measuredFloor=percentile(energies,.16),provided=Number.isFinite(+opts.noiseFloor)?+opts.noiseFloor:0;
  // Calibration is useful, but do not let one noisy calibration lock the whole take out.
  const noiseFloor=provided>0?clamp(provided,.00025,.04):clamp(measuredFloor*.28,.00025,.008);
  const suppression=opts.suppression||'normal',gateFactor=suppression==='strong'?1.72:suppression==='off'?.92:1.18,minConfidence=opts.minConfidence??(suppression==='strong'?.58:suppression==='off'?.40:.48);
  const frames=[];
  for(const r of raw){
    const frame=frameCentered(data,r.start,frameSize),ratio=r.energy/Math.max(noiseFloor,1e-5),energyGate=Math.max(.00038,noiseFloor*gateFactor*.82),energyOk=r.energy>energyGate;
    const candidates=energyOk?yinCandidates(frame,sr,opts.minHz||pre.minHz,opts.maxHz||pre.maxHz,opts.yinThreshold??.17,6):[];
    frames.push({...r,ratio,energyGate,candidates});
  }
  const chosen=viterbiTrack(frames,gateFactor,minConfidence),points=[];
  for(let i=0;i<frames.length;i++){
    const r=frames[i],c=chosen[i],candidateConf=c?.voiced?c.confidence:0,voiced=!!c?.voiced&&candidateConf>=Math.max(.30,minConfidence*.66)&&r.ratio>Math.max(.88,gateFactor),mf=voiced?c.midiFloat:null;
    points.push({t:r.t,midi:voiced?Math.round(mf):null,midiFloat:mf,freq:voiced?c.freq:0,energy:r.energy,confidence:candidateConf,voiced,snrDb:20*Math.log10(Math.max(1e-5,r.ratio)),candidateCount:r.candidates.length});
  }
  const cleaned=cleanPitchTrack(points,minConfidence),smooth=cleaned.points;
  const voicedVals=smooth.filter(p=>p.voiced&&p.midiFloat!=null).map(p=>p.midiFloat),medianMidi=median(voicedVals);
  smooth.meta={profile,voiceRange,suppression,noiseFloor,analysisSampleRate:sr,hopSeconds:hop/sr,minConfidence,frameSeconds:frameSize/sr,medianMidi,octaveFixes:cleaned.octaveFixes,detector:'yin-multicandidate-viterbi'};return smooth;
}

export function pitchPointsToNotes(points, opts={}) {
  const bpm=opts.bpm||120,root=opts.root||0,scale=opts.scale||"minor",correction=clamp(opts.correction??0,0,1),pitchMode=opts.pitchMode||'chromatic',beat=60/bpm,division=opts.division||4,quantum=beat/division;
  const gapHold=opts.gapHold??.26,changeCents=opts.changeCents??78,changeFrames=opts.changeFrames??6,startCommitFrames=opts.startCommitFrames??8,minDuration=opts.minDuration??Math.min(.085,quantum*.5),hop=points.meta?.hopSeconds||.012,minSnrDb=points.meta?.suppression==='off'?-2:points.meta?.suppression==='strong'?3.5:1.0;
  const quant=t=>Math.round(t/quantum)*quantum,notes=[];let cur=null,pending=null;
  const targetMidi=f=>{const nearest=Math.round(f);if(pitchMode!=='scale')return nearest;const snapped=snapMidiToScale(f,root,scale);return Math.round(f+(snapped-f)*correction);};
  const finalize=(endOverride=null)=>{if(!cur)return;const rawEnd=Math.max(cur.start+hop,endOverride??cur.last+hop),rawDur=rawEnd-cur.start;if(rawDur>=minDuration&&cur.snrSum/Math.max(1,cur.frames)>=minSnrDb){const start=quant(cur.start),duration=Math.max(quantum,Math.round(rawDur/quantum)*quantum),finalMidi=targetMidi(median(cur.pitches)||cur.center);notes.push({start,duration,midi:finalMidi,velocity:clamp(.46+cur.confSum/Math.max(1,cur.frames)*.42,.34,.95)});}cur=null;pending=null;};
  // Use a wider weighted-median window for note segmentation than for F0 display.
  const tracked=points.map((p,i)=>{if(!p.voiced||p.midiFloat==null)return p;const vals=[];for(let j=Math.max(0,i-5);j<=Math.min(points.length-1,i+5);j++)if(points[j].voiced&&points[j].midiFloat!=null)vals.push({v:points[j].midiFloat,w:Math.max(.1,points[j].confidence||.5)});const m=weightedMedian(vals);return m==null?p:{...p,midiFloat:m,midi:Math.round(m)};});
  for(const p of tracked){
    if(!p.voiced||p.midiFloat==null){if(cur&&p.t-cur.last>gapHold)finalize(cur.last+hop);continue;}
    const midi=targetMidi(p.midiFloat);if(!cur){cur={start:p.t,last:p.t,midi,center:p.midiFloat,frames:1,confSum:p.confidence||.62,snrSum:p.snrDb||0,pitches:[p.midiFloat]};continue;}
    const robustCenter=median(cur.pitches.slice(-24))??cur.center,cents=Math.abs(p.midiFloat-robustCenter)*100;
    if(midi===cur.midi||cents<=changeCents){cur.last=p.t;cur.pitches.push(p.midiFloat);if(cur.pitches.length>40)cur.pitches.shift();cur.center=median(cur.pitches)??cur.center;cur.frames++;cur.confSum+=p.confidence||.62;cur.snrSum+=p.snrDb||0;pending=null;continue;}
    if(!pending||pending.midi!==midi){pending={midi,start:p.t,last:p.t,count:1,center:p.midiFloat,conf:p.confidence||.62,snr:p.snrDb||0,pitches:[p.midiFloat]};continue;}
    pending.last=p.t;pending.count++;pending.pitches.push(p.midiFloat);pending.center=median(pending.pitches)??pending.center;pending.conf+=p.confidence||.62;pending.snr+=p.snrDb||0;
    if(pending.count>=changeFrames){const next={...pending};if(cur.frames<startCommitFrames){cur={start:next.start,last:p.t,midi:next.midi,center:next.center,frames:next.count,confSum:next.conf,snrSum:next.snr,pitches:[...next.pitches]};pending=null;}else{finalize(next.start);cur={start:next.start,last:p.t,midi:next.midi,center:next.center,frames:next.count,confSum:next.conf,snrSum:next.snr,pitches:[...next.pitches]};pending=null;}}
  }
  finalize();
  // Merge repeated notes separated only by a tiny breath/gap; preserve genuine repeated attacks farther apart.
  const merged=[];for(const n of notes){const prev=merged[merged.length-1],gap=prev?n.start-(prev.start+prev.duration):99;if(prev&&prev.midi===n.midi&&gap<=Math.max(.22,quantum*.45)){prev.duration=Math.max(prev.duration,(n.start+n.duration)-prev.start);prev.velocity=(prev.velocity+n.velocity)*.5;}else merged.push({...n});}return merged;
}

export function detectOnsets(buffer, opts={}) {
  const data=monoMix(buffer), sr=buffer.sampleRate,frame=opts.frameSize||1024, hop=opts.hop||256,energies=[];
  for(let s=0;s+frame<data.length;s+=hop){let e=0,z=0,prev=data[s];for(let i=s;i<s+frame;i++){const v=data[i];e+=v*v;if((v>=0)!=(prev>=0))z++;prev=v;}energies.push({t:s/sr,e:Math.sqrt(e/frame),z:z/frame});}
  const out=[];for(let i=2;i<energies.length-1;i++){const a=energies[i],prev=(energies[i-1].e+energies[i-2].e)/2,rise=a.e-prev;if(a.e>(opts.threshold||.025)&&rise>Math.max(.008,prev*.35)){if(!out.length||a.t-out[out.length-1].t>(opts.minGap||.07)) out.push(a);}}return out;
}

export function onsetsToBeatboxDrums(onsets,bpm=120){const beat=60/bpm,quant=beat/4;return onsets.map(o=>{const type=o.z>.22?'hat':o.z>.09?'snare':'kick';return {t:Math.round(o.t/quant)*quant,type,gain:Math.max(.15,Math.min(.9,o.e*4.5))};});}
